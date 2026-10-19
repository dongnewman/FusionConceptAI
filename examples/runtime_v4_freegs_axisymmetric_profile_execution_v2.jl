#=
Fixture builder for the generic axisymmetric profile/observed-boundary bridge.

The caller must first materialize a verified source snapshot with
`native_axisymmetric_adapter.py`.  Keeping the path and hashes explicit avoids
silently generating or selecting experimental data while a candidate is built.
=#

using FusionConceptAI

module FreeGSProfileRuntimeV2
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "FreeGSAxisymmetricProfileExecutionV2.jl"))
end

include(joinpath(@__DIR__, "runtime_v4_declared_fixture.jl"))

function build_freegs_profile_fixture_v2(snapshot_path::AbstractString;
        snapshot_payload_sha256::AbstractString,
        source_binding_sha256::AbstractString,
        shot_id::Integer, efm_time_index::Integer, efm_time_s::Real,
        rtol::Real=1.0e-5, atol::Real=1.0e-10,
        max_iterations::Integer=100, blend::Real=0.0)
    F = FreeGSProfileRuntimeV2
    absolute_snapshot = abspath(normpath(String(snapshot_path)))
    source = F.GenericAxisymmetricSourceReferenceV1(
        "generic-axisymmetric-source-$(shot_id)-$(efm_time_index)",
        absolute_snapshot, F._gaf_sha256_file(absolute_snapshot),
        Digest256(snapshot_payload_sha256), Digest256(source_binding_sha256),
        shot_id, efm_time_index, efm_time_s)
    controls = F.ObservedDirichletProfileControlsV2(
        rtol, atol, max_iterations, blend)
    declaration_canonical_observation =
        F._gaf_declaration_canonical_observation(
            "generic-axisymmetric-observed-dirichlet-profile-v2", source,
            controls)
    println("NATIVE_GS_DECLARATION_CANONICAL_OBSERVATION=",
        F.canonical_json(declaration_canonical_observation))
    declaration_canonical_observation.normalized_body_canonical ||
        error("normalized declaration body is not canonicalizable")
    declaration = F.GenericAxisymmetricProfileDeclarationV2(
        "generic-axisymmetric-observed-dirichlet-profile-v2", source, controls)
    field_genome = FieldGeometryGenomeV4(2026092203, _fixture_refs[2],
        _fixture_graph(); fields=(declaration,))
    candidate = CandidateStatePackageV4(
        "runtime-v4-generic-axisymmetric-profile-v2", _fixture_mission,
        _fixture_mechanism, field_genome, _fixture_realization, registry)
    mission_payload = (
        mission_id="generic-axisymmetric-profile-observed-dirichlet-consistency",
        model_scope="static-axisymmetric-observed-dirichlet-grad-shafranov",
        contract=candidate.mission_contract_ref)
    bounds_payload = (
        declaration_hash=canonical_hash(declaration),
        source_snapshot_payload_hash=source.snapshot_payload_hash,
        model="FreeGS-0.8.2-tabulated-pprime-ffprime-explicit-empty-machine",
        grid_shape=(65, 65),
        free_boundary_status="typed_absent_unmapped_coil_geometry")
    comparison_scope = ("same-source-observed-dirichlet-solver-convergence-and-residual-measurement",)
    scenario = (name="explicit-source-time-slice",
        source_id=source.source_id, efm_time_index=source.efm_time_index)
    scenario_scope = (scenario.name,)
    compiled = F.compile_candidate(candidate, registry;
        mission_payload=mission_payload, bounds_payload=bounds_payload,
        comparison_scope=comparison_scope, scenario_scope=scenario_scope)
    binding = F.make_generic_axisymmetric_profile_binding(
        compiled, registry, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario, declaration)
    subject = F.ExecutablePhysicalSubjectV4(
        compiled.prefix_hash, candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash,
        (binding,), (scenario,),
        (materialization="verified-generic-axisymmetric-source-v1",
         source_hash=source.source_hash,
         snapshot_payload_hash=source.snapshot_payload_hash,
         independent_validation=false,
         free_boundary_status="typed_absent_unmapped_coil_geometry"),
        F.derive_capability_obligations(compiled))
    context = F.make_forward_chain_context(
        candidate, compiled, registry, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, subject, scenario)
    (runtime=F, source=source, controls=controls,
     declaration_canonical_observation=declaration_canonical_observation,
     declaration=declaration,
     candidate=candidate, mission_payload=mission_payload,
     bounds_payload=bounds_payload, comparison_scope=comparison_scope,
     scenario_scope=scenario_scope, scenario=scenario, compiled=compiled,
     binding=binding, subject=subject, context=context)
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("fixture_builder=build_freegs_profile_fixture_v2")
    println("requires=verified native_axisymmetric_adapter snapshot path and hashes")
    println("claim_ceiling=same_source_observed_dirichlet_solver_converged_residual_measured_only")
end
