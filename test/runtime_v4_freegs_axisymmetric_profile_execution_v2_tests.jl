using Test
using FusionConceptAI

const _PROFILE_V2_ROOT = abspath(joinpath(@__DIR__, ".."))
const _PROFILE_V2_PINNED_PYTHON = raw"D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Scripts\python.exe"
const _PROFILE_V2_ADAPTER = joinpath(_PROFILE_V2_ROOT, "benchmarks",
    "reference_source_fields_v1", "native_axisymmetric_adapter.py")
const _PROFILE_V2_TEMP = mktempdir()
const _PROFILE_V2_SNAPSHOT = joinpath(_PROFILE_V2_TEMP, "shot30421-t80.json")

function _profile_v2_capture(command::Cmd)
    stdout = IOBuffer()
    stderr = IOBuffer()
    process = run(pipeline(ignorestatus(command), stdout=stdout, stderr=stderr))
    (exit_code=process.exitcode, stdout=String(take!(stdout)),
     stderr=String(take!(stderr)))
end

const _PROFILE_V2_MATERIALIZE = _profile_v2_capture(
    `$_PROFILE_V2_PINNED_PYTHON $_PROFILE_V2_ADAPTER materialize --efm-time-index 80 --amc-max-delta-s 0.000001 --output $_PROFILE_V2_SNAPSHOT`)
_PROFILE_V2_MATERIALIZE.exit_code == 0 || error(
    "native source materialization failed: $(_PROFILE_V2_MATERIALIZE.stderr)")

const _PROFILE_V2_SNAPSHOT_TEXT = read(_PROFILE_V2_SNAPSHOT, String)
const _PROFILE_V2_PAYLOAD_MATCH = match(
    r"\"snapshot_payload_sha256\"\s*:\s*\"([0-9a-f]{64})\"",
    _PROFILE_V2_SNAPSHOT_TEXT)
const _PROFILE_V2_BINDING_MATCH = match(
    r"\"source_binding_sha256\"\s*:\s*\"([0-9a-f]{64})\"",
    _PROFILE_V2_SNAPSHOT_TEXT)
_PROFILE_V2_PAYLOAD_MATCH === nothing && error("snapshot payload hash is absent")
_PROFILE_V2_BINDING_MATCH === nothing && error("snapshot source binding hash is absent")
const _PROFILE_V2_PAYLOAD_HASH = only(_PROFILE_V2_PAYLOAD_MATCH.captures)
const _PROFILE_V2_SOURCE_BINDING_HASH = only(_PROFILE_V2_BINDING_MATCH.captures)

include(joinpath(_PROFILE_V2_ROOT, "examples",
    "runtime_v4_freegs_axisymmetric_profile_execution_v2.jl"))
const _PROFILE_V2_FIXTURE = build_freegs_profile_fixture_v2(
    _PROFILE_V2_SNAPSHOT;
    snapshot_payload_sha256=_PROFILE_V2_PAYLOAD_HASH,
    source_binding_sha256=_PROFILE_V2_SOURCE_BINDING_HASH,
    shot_id=30421, efm_time_index=80, efm_time_s=0.375,
    rtol=1.0e-5, atol=1.0e-10, max_iterations=100, blend=0.0)
const F = _PROFILE_V2_FIXTURE.runtime

@testset "generic G2 profile source and COCOS-bounded declaration" begin
    fixture = _PROFILE_V2_FIXTURE
    observation = fixture.declaration_canonical_observation
    @test observation.input_declaration_id_type == "String"
    @test observation.stripped_declaration_id_type == "SubString{String}"
    @test observation.normalized_declaration_id_type == "String"
    @test observation.first_legacy_noncanonical_path == "\$.declaration_id"
    @test !observation.legacy_body_canonical
    @test observation.normalized_body_canonical
    @test all(item.canonical for item in
        observation.source_semantic_field_observations)
    @test all(item.canonical for item in
        observation.controls_semantic_field_observations)
    @test F.validate_forward_chain_context(fixture.context) == fixture.context.context_hash
    @test F.validate_generic_axisymmetric_source(fixture.source) == fixture.source.source_hash
    @test F.validate_generic_axisymmetric_profile_declaration(fixture.declaration) ==
        fixture.declaration.declaration_hash
    @test fixture.candidate.field_geometry_genome_ref.fields == (fixture.declaration,)
    @test fixture.subject.bindings == (fixture.binding,)
    @test fixture.source.coil_geometry_status ===
        :typed_absent_from_bound_source_protocol

    input = F.freegs_axisymmetric_profile_solver_input_v2(fixture.context)
    @test input.controls.machine == "explicit_empty_machine"
    @test input.controls.boundary == "observed_dirichlet_box_edges"
    @test input.controls.cocos_mapping == "identity_no_sign_or_2pi_transform"
    @test input.controls.cocos_scope == "gs_bp_subset_only_q_theta_not_consumed"
    @test !occursin("MAST", canonical_json(input))
    manifest = F.freegs_axisymmetric_profile_execution_manifest_v2()
    @test manifest.device_name_routing === false
    @test manifest.cocos_mapping === :identity_no_sign_or_2pi_transform
    @test manifest.cocos_scope === :gs_bp_subset_only_q_theta_not_consumed
    @test manifest.reference_inversion_G1_G2_G3 === false
    @test manifest.executable_source_scope === :G2_profile_fixed_boundary
    @test manifest.free_boundary_status === :typed_absent_unmapped_coil_geometry
end

@testset "validated input is bound without claiming a solve" begin
    artifact_directory = get(ENV,
        "FUSION_FREEGS_PROFILE_V2_VALIDATE_ARTIFACT_DIR",
        joinpath(_PROFILE_V2_TEMP, "validate-only-artifacts"))
    artifacts = F.execute_freegs_axisymmetric_profile_v2(
        _PROFILE_V2_FIXTURE.context;
        artifact_directory=artifact_directory, validate_only=true)
    receipt = artifacts.receipt
    @test receipt.status === :validated_input_no_solve
    @test receipt.exit_code == 0
    @test receipt.summary === nothing
    @test receipt.gap_kind === :not_executed
    @test receipt.input_hash == receipt.backend_input_hash
    @test receipt.input_hash == F._gaf_sha256_text(artifacts.input_json)
    @test receipt.output_hash == F._gaf_sha256_text(artifacts.output_json)
    @test receipt.reference_inversion_G1_G2_G3 === false
    @test receipt.executable_source_scope === :G2_profile_fixed_boundary
    @test !receipt.independent_validation
    @test !receipt.likelihood_ready
    @test !receipt.formal_acceptance
    @test F.validate_freegs_axisymmetric_profile_receipt_v2(
        _PROFILE_V2_FIXTURE.context, receipt) == receipt.receipt_hash
    @test isfile(joinpath(artifact_directory, "solver_input.canonical.json"))
    @test isfile(joinpath(artifact_directory, "solver_output.json"))
    @test isfile(joinpath(artifact_directory, "execution_receipt.canonical.json"))
end

@testset "typed runner failures retain exact exit identities" begin
    context = _PROFILE_V2_FIXTURE.context
    binding = F._gaf_context_binding(context)
    interpreter_hash = F._gaf_sha256_file(F._GAF_PINNED_PYTHON)
    runner_hash = F._gaf_sha256_file(F._GAF_RUNNER)
    cases = (
        (:input_validation_failed, 2, :input_validation_failed),
        (:backend_unavailable, 3, :dependency_unavailable),
        (:numerical_fail_nonconvergence, 4, :numerical_fail),
        (:program_exception, 5, :program_exception),
    )
    for (status, exit_code, gap_kind) in cases
        receipt = F._gaf_make_receipt(context, binding;
            status=status, exit_code=exit_code, gap_kind=gap_kind,
            interpreter_hash=interpreter_hash, runner_hash=runner_hash)
        @test F.validate_freegs_axisymmetric_profile_receipt_v2(
            context, receipt) == receipt.receipt_hash
        forged = F._gaf_make_receipt(context, binding;
            status=status, exit_code=exit_code == 5 ? 4 : 5, gap_kind=gap_kind,
            interpreter_hash=interpreter_hash, runner_hash=runner_hash)
        @test_throws ArgumentError F.validate_freegs_axisymmetric_profile_receipt_v2(
            context, forged)
    end
end

@testset "live source and typed boundary forgeries fail closed" begin
    copied = joinpath(_PROFILE_V2_TEMP, "tampered-source.json")
    cp(_PROFILE_V2_SNAPSHOT, copied; force=true)
    fixture = build_freegs_profile_fixture_v2(copied;
        snapshot_payload_sha256=_PROFILE_V2_PAYLOAD_HASH,
        source_binding_sha256=_PROFILE_V2_SOURCE_BINDING_HASH,
        shot_id=30421, efm_time_index=80, efm_time_s=0.375)
    open(copied, "a") do stream
        write(stream, "\n")
    end
    @test_throws ArgumentError F.freegs_axisymmetric_profile_solver_input_v2(
        fixture.context)

    forged_state = F.GenericAxisymmetricForwardStateV1(
        :conditional_fixed_boundary_solution, digest256_text("forged-state"),
        _PROFILE_V2_FIXTURE.source.snapshot_payload_hash,
        :formal_inverse_acceptance, true, true)
    @test_throws ArgumentError F.validate_generic_axisymmetric_forward_state(
        forged_state, _PROFILE_V2_FIXTURE.source)
    @test_throws ArgumentError F.ObservedDirichletProfileControlsV2(
        1.0, 1.0e-10, 100, 0.0)
end

@testset "real conditional fixed-boundary FreeGS solve when explicitly enabled" begin
    if get(ENV, "FUSION_RUN_FREEGS_PROFILE_V2_SOLVE", "0") == "1"
        artifact_directory = get(ENV,
            "FUSION_FREEGS_PROFILE_V2_ARTIFACT_DIR",
            joinpath(_PROFILE_V2_TEMP, "solve-artifacts"))
        artifacts = F.execute_freegs_axisymmetric_profile_v2(
            _PROFILE_V2_FIXTURE.context;
            artifact_directory=artifact_directory, validate_only=false)
        receipt = artifacts.receipt
        @test receipt.status in (
            :conditional_fixed_boundary_solver_converged_residual_measured,
            :numerical_fail_nonconvergence,
            :program_exception)
        @test receipt.reference_inversion_G1_G2_G3 === false
        @test receipt.executable_source_scope === :G2_profile_fixed_boundary
        @test !receipt.independent_validation
        @test !receipt.physical_validation
        @test !receipt.likelihood_ready
        @test F.validate_freegs_axisymmetric_profile_receipt_v2(
            _PROFILE_V2_FIXTURE.context, receipt) == receipt.receipt_hash
        if receipt.status === :conditional_fixed_boundary_solver_converged_residual_measured
            @test receipt.exit_code == 0
            @test receipt.summary !== nothing
            @test receipt.summary.iterations > 0
            @test receipt.summary.observed_boundary_hash !=
                digest256_text("runtime-v4-freegs-profile-v2-unknown")
        elseif receipt.status === :numerical_fail_nonconvergence
            @test receipt.exit_code == 4
            @test receipt.gap_kind === :numerical_fail
            @test occursin("Picard iteration reached", receipt.reason)
        else
            @test receipt.exit_code != 0
            @test receipt.gap_kind in (:program_exception, :malformed_backend_output)
        end
    else
        @test true
    end
end
