#!/usr/bin/env julia

# One fresh process handles one natural candidate scenario.  It reloads the
# exact real-parent checkpoint, validates the inherited context/registry and
# then calls the unchanged production builder, validator, declaration
# extractor, and assembler.

using JSON3, SHA

const _BCC_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
_bcc_sha(path) = bytes2hex(SHA.sha256(read(path)))

function _bcc_existing_repo_file(relative::AbstractString)
    isempty(relative) && error("frozen-input path must not be empty")
    isabspath(relative) && error("absolute frozen-input path refused")
    Sys.iswindows() && occursin(r"^[A-Za-z]:", relative) &&
        error("drive-qualified frozen-input path refused")
    any(==(".."), splitpath(relative)) &&
        error("frozen-input traversal refused")
    root = realpath(_BCC_REPO)
    lexical = normpath(joinpath(root, relative))
    isfile(lexical) || error("missing frozen input: $relative")
    path = realpath(lexical)
    inside = try
        relpath(path, root)
    catch
        error("frozen-input path is on a foreign root")
    end
    isabspath(inside) && error("frozen-input path is on a foreign root")
    parts = splitpath(normpath(inside))
    !isempty(parts) && all(!=(".."), parts) ||
        error("frozen-input path escapes repository")
    path
end

length(ARGS) == 7 || error(
    "usage: bounded_candidate_child_v1.jl PROTOCOL EXPECTED_PROTOCOL_SHA ARTIFACT PARENT_RECEIPT EXPECTED_PARENT_RECEIPT_SHA SCENARIO OUTPUT_RECEIPT")
const _BCC_PROTOCOL_PATH = abspath(ARGS[1])
const _BCC_EXPECTED_PROTOCOL_SHA = lowercase(ARGS[2])
_bcc_sha(_BCC_PROTOCOL_PATH) == _BCC_EXPECTED_PROTOCOL_SHA ||
    error("candidate-shard protocol hash mismatch")
const _BCC_PROTOCOL = JSON3.read(read(_BCC_PROTOCOL_PATH, String))
String(_BCC_PROTOCOL.status) == "frozen_ready" ||
    error("candidate-shard protocol is not frozen_ready")
String(ARGS[6]) in ("implicit_default", "explicit_legacy", "declared_load",
    "declared_load_bounded") || error("unknown candidate scenario")

for group in (_BCC_PROTOCOL.fusion_package_inputs,
        _BCC_PROTOCOL.production_inputs, _BCC_PROTOCOL.harness_inputs)
    for entry in group
        relative = String(entry.path)
        path = _bcc_existing_repo_file(relative)
        _bcc_sha(path) == String(entry.sha256) ||
            error("frozen input hash mismatch: $relative")
        filesize(path) == Int(entry.bytes) ||
            error("frozen input size mismatch: $relative")
    end
end

module UP2BoundedCandidateFixtureV1
using FusionConceptAI, Serialization, SHA, JSON3, LinearAlgebra, SparseArrays
import FusionConceptAI: canonical_hash, canonical_json

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
sha(path) = bytes2hex(SHA.sha256(read(path)))

# This is the lean half of the stable serialized type path.  The parent
# producer obtains the same module path by including the real DGPI example;
# this child loads only the defining production sources before deserialize.
module ThreeDPhysicalProviderInputRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4",
    "Contracts.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4",
    "Compiler.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4",
    "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4",
    "ThreeDPhysicalProviderInputV4.jl"))
end
const SCV = ThreeDPhysicalProviderInputRuntime
Base.include(SCV, joinpath(REPO, "src", "RuntimeV4",
    "ThreeDNormalizedPhysicalRootBridgeV4.jl"))
Base.include(SCV, joinpath(REPO, "src", "RuntimeV4",
    "DESCGeometryProgramInterpreterV4.jl"))
for source in ("DESCRequestProviderExecutionV4.jl",
               "CompleteMultiRegionV4.jl", "MagneticEngineeringV4.jl",
               "ExecutedVerificationUQV4.jl", "RevisedCandidateV4.jl")
    Base.include(SCV, joinpath(REPO, "src", "RuntimeV4", source))
end
Base.include(SCV, joinpath(REPO, "src", "RuntimeV4", "SpatialRuntimeV4.jl"))
Base.invokelatest(SCV.load_spatial_runtime_v4!)

include(joinpath(@__DIR__, "bounded_candidate_assembly_oracle_v1.jl"))

const SOURCE_VECTOR = (3.25, -2.5, 0.75)
const SOURCE_PROVENANCE =
    "independent manufactured force-density fixture; not measured"
const BOUNDARY_PROVENANCE =
    "independent closed-torus zero-normal-field fixture"
const CHECKS = Ref(0)

function require(condition, message)
    condition || error(message)
    CHECKS[] += 1
    true
end

function timed(f, label)
    started = time_ns()
    println("UP2_BOUNDED_CHILD_STAGE_BEGIN=", label); flush(stdout)
    value = f()
    println("UP2_BOUNDED_CHILD_STAGE_END=", label,
        " elapsed_seconds=", (time_ns()-started)/1e9); flush(stdout)
    value
end

function source_pins(entries)
    Tuple((path=String(entry.path), sha256=String(entry.sha256),
        bytes=Int(entry.bytes)) for entry in entries)
end

function parent_identity(context, physical_input)
    SCV.validate_forward_chain_context(context)
    inherited = only(filter(x -> x isa SCV.ThreeDPhysicalProviderInputV4,
        context.candidate.field_geometry_genome_ref.fields))
    require(canonical_hash(inherited) == canonical_hash(physical_input),
        "reloaded parent physical input mismatch")
    (parent_candidate_hash=string(context.candidate_hash),
     parent_candidate_package_hash=string(canonical_hash(context.candidate)),
     parent_context_hash=string(context.context_hash),
     parent_context_canonical_hash=string(canonical_hash(context)),
     parent_subject_hash=string(context.subject.physical_subject_hash),
     physical_input_hash=string(canonical_hash(physical_input)),
     registry_hash=string(context.registry_hash),
     registry_canonical_hash=string(canonical_hash(context.registry)))
end

function json_identity(receipt)
    value = receipt.identity
    (parent_candidate_hash=String(value.parent_candidate_hash),
     parent_candidate_package_hash=String(value.parent_candidate_package_hash),
     parent_context_hash=String(value.parent_context_hash),
     parent_context_canonical_hash=String(value.parent_context_canonical_hash),
     parent_subject_hash=String(value.parent_subject_hash),
     physical_input_hash=String(value.physical_input_hash),
     registry_hash=String(value.registry_hash),
     registry_canonical_hash=String(value.registry_canonical_hash))
end

function declaration_set(physical_input)
    flux = physical_input.profiles_flux.toroidal_flux_wb
    legacy = SCV.spatial_multiregion_declaration_v4(flux_Wb=flux)
    loaded = SCV.spatial_multiregion_declared_loads_v1(legacy;
        source_xyz_N_m3=SOURCE_VECTOR, normal_B_T=0.0,
        source_provenance=SOURCE_PROVENANCE,
        boundary_provenance=BOUNDARY_PROVENANCE)
    combined = SCV.spatial_multiregion_bounded_step_v1(loaded)
    (legacy=legacy, loaded=loaded, combined=combined)
end

function build_scenario(parent_context, physical_input, declarations, scenario)
    if scenario == "implicit_default"
        SCV.build_spatial_candidate_v4(parent_context, physical_input)
    elseif scenario == "explicit_legacy"
        SCV.build_spatial_candidate_v4(parent_context, physical_input;
            physical_declaration=declarations.legacy)
    elseif scenario == "declared_load"
        SCV.build_spatial_candidate_v4(parent_context, physical_input;
            physical_declaration=declarations.loaded)
    elseif scenario == "declared_load_bounded"
        SCV.build_spatial_candidate_v4(parent_context, physical_input;
            physical_declaration=declarations.combined)
    else
        error("unsupported scenario")
    end
end

function expected_declaration(declarations, scenario)
    scenario in ("implicit_default", "explicit_legacy") ? declarations.legacy :
        scenario == "declared_load" ? declarations.loaded : declarations.combined
end

function expected_candidate_identity(scenario)
    scenario in ("implicit_default", "explicit_legacy") ?
        (id="spatial-coupled-20260912-r1",
         revision="spatial-coupled-candidate-v1") :
    scenario == "declared_load" ?
        (id="spatial-coupled-declared-loads-v1",
         revision="spatial-coupled-candidate-declared-loads-v1") :
        (id="spatial-coupled-declared-loads-bounded-step-v1",
         revision="spatial-coupled-candidate-declared-loads-bounded-step-v1")
end

function candidate_identity(result)
    context = result.context
    hashes = context.candidate.canonical_hashes
    (candidate_id=String(context.candidate.identity_ref),
     candidate_hash=string(context.candidate_hash),
     candidate_package_hash=string(canonical_hash(context.candidate)),
     context_hash=string(context.context_hash),
     context_canonical_hash=string(canonical_hash(context)),
     subject_hash=string(context.subject.physical_subject_hash),
     mechanism_hash=string(hashes.mechanism_hash),
     field_geometry_hash=string(hashes.field_geometry_hash),
     realization_control_hash=string(hashes.realization_control_hash),
     genome_bundle_hash=string(hashes.genome_bundle_hash),
     provenance_hash=string(canonical_hash(result.provenance)))
end

function validate_candidate_result(result, parent_context, physical_input,
        declaration, scenario)
    require(SCV.validate_spatial_candidate_v4(result.context),
        "production spatial candidate validator failed")
    require(result.parent_hash == canonical_hash(parent_context.candidate),
        "candidate parent package mismatch")
    require(result.provenance.parent_candidate_hash ==
        parent_context.candidate_hash, "candidate parent identity mismatch")
    require(result.provenance.parent_context_hash == parent_context.context_hash,
        "candidate parent context mismatch")
    require(result.provenance.parent_package_hash ==
        canonical_hash(parent_context.candidate),
        "candidate parent package provenance mismatch")
    inherited = only(filter(x -> x isa SCV.ThreeDPhysicalProviderInputV4,
        result.context.candidate.field_geometry_genome_ref.fields))
    require(canonical_hash(inherited) == canonical_hash(physical_input),
        "candidate inherited physical input mismatch")
    extracted = SCV._smr_declaration(result.context)
    require(extracted == declaration,
        "production candidate declaration extraction mismatch")
    require(result.changes.physical_hash == canonical_hash(declaration),
        "candidate physical declaration hash mismatch")
    expected = expected_candidate_identity(scenario)
    require(String(result.context.candidate.identity_ref) == expected.id,
        "candidate ID mismatch")
    require(String(result.provenance.revision) == expected.revision,
        "candidate provenance revision mismatch")
    if scenario in ("declared_load", "declared_load_bounded")
        require(result.provenance.declared_loads.declaration_hash ==
            canonical_hash(declaration), "declared-load provenance mismatch")
        require(result.provenance.declared_loads.exterior_current_closure ===
            :terminal_deferred, "external load closure was overclaimed")
    end
    if scenario == "declared_load_bounded"
        require(result.provenance.numerical_algorithm.declaration_hash ==
            canonical_hash(declaration), "bounded provenance declaration mismatch")
        require(result.provenance.numerical_algorithm.scope ===
            :linearized_subproblem_only, "bounded scope was broadened")
        require(result.provenance.numerical_algorithm.nonlinear_convergence ===
            :requires_full_residual_gate, "bounded nonlinear gate was overclaimed")
    end
    extracted
end

function assembly_receipt(declarations, extracted, scenario)
    data = bounded_candidate_fixture_v1(SCV)
    legacy = SCV.assemble_spatial_system_v4(declarations.legacy, data,
        data.initial_state)
    loaded = SCV.assemble_spatial_system_v4(declarations.loaded, data,
        data.initial_state)
    combined = SCV.assemble_spatial_system_v4(declarations.combined, data,
        data.initial_state)
    oracle = bounded_candidate_expected_source_delta_v1(data,
        collect(SOURCE_VECTOR), SCV)
    delta = loaded.residual - legacy.residual
    require(bounded_candidate_vector_close_v1(delta, oracle),
        "independent declared-source residual oracle failed")
    require(loaded.jacobian == legacy.jacobian,
        "state-independent declared source changed the Jacobian")
    require(combined.residual == loaded.residual,
        "bounded numerical declaration changed the assembled residual")
    require(combined.jacobian == loaded.jacobian,
        "bounded numerical declaration changed the assembled Jacobian")

    selected = SCV.assemble_spatial_system_v4(extracted, data,
        data.initial_state)
    selected_expected = scenario in ("implicit_default", "explicit_legacy") ?
        legacy : scenario == "declared_load" ? loaded : combined
    require(selected.residual == selected_expected.residual &&
        selected.jacobian == selected_expected.jacobian,
        "extracted candidate declaration was not consumed by the assembler")
    (selected=bounded_candidate_assembly_hashes_v1(selected, canonical_hash),
     legacy=bounded_candidate_assembly_hashes_v1(legacy, canonical_hash),
     declared_load=bounded_candidate_assembly_hashes_v1(loaded, canonical_hash),
     declared_load_bounded=
        bounded_candidate_assembly_hashes_v1(combined, canonical_hash),
     source_delta_hash=string(canonical_hash((
        kind=:independent_discrete_source_delta, values=Tuple(delta)))),
     source_oracle_hash=string(canonical_hash((
        kind=:independent_discrete_source_delta, values=Tuple(oracle)))),
     fixture_scope="independent_analytic_torus_assembly_not_DGPI_geometry_provider")
end

function write_new(path, text)
    ispath(path) && error("refusing to overwrite child receipt: $path")
    mkpath(dirname(path))
    write(path, text)
end

function main()
    protocol_path = abspath(ARGS[1])
    expected_protocol_sha = lowercase(ARGS[2])
    artifact_path = abspath(ARGS[3])
    parent_receipt_path = abspath(ARGS[4])
    expected_parent_receipt_sha = lowercase(ARGS[5])
    scenario = String(ARGS[6])
    output_path = abspath(ARGS[7])
    protocol = JSON3.read(read(protocol_path, String))
    require(sha(protocol_path) == expected_protocol_sha,
        "protocol changed after child preflight")
    require(sha(parent_receipt_path) == expected_parent_receipt_sha,
        "parent receipt hash mismatch")
    parent_receipt = JSON3.read(read(parent_receipt_path, String))
    require(String(parent_receipt.schema) ==
        "up2-04-independent-parent-checkpoint-receipt-v1",
        "parent receipt schema mismatch")
    require(String(parent_receipt.protocol_sha256) == expected_protocol_sha,
        "parent receipt protocol binding mismatch")
    require(String(parent_receipt.artifact_sha256) == sha(artifact_path),
        "parent artifact hash mismatch")
    require(Int(parent_receipt.artifact_bytes) == filesize(artifact_path),
        "parent artifact size mismatch")
    require(String(parent_receipt.artifact_path) == basename(artifact_path),
        "parent artifact relative-name mismatch")
    require(canonical_json(source_pins(protocol.fusion_package_inputs)) ==
        canonical_json(Tuple((path=String(x.path), sha256=String(x.sha256),
            bytes=Int(x.bytes)) for x in parent_receipt.fusion_package_inputs)),
        "parent receipt FusionConceptAI source pins mismatch")
    require(canonical_json(source_pins(protocol.production_inputs)) ==
        canonical_json(Tuple((path=String(x.path), sha256=String(x.sha256),
            bytes=Int(x.bytes)) for x in parent_receipt.production_inputs)),
        "parent receipt production-source pins mismatch")

    payload = timed("fresh_process_parent_deserialize") do
        open(deserialize, artifact_path)
    end
    require(payload.schema == "up2-04-independent-real-dgpi-parent-v1",
        "parent artifact schema mismatch")
    require(payload.base_head == String(protocol.base_head),
        "parent artifact base HEAD mismatch")
    identity = timed("fresh_process_parent_validation") do
        parent_identity(payload.parent_context, payload.physical_input)
    end
    require(identity == payload.identity,
        "serialized parent identity payload mismatch")
    require(identity == json_identity(parent_receipt),
        "serialized parent identity differs from receipt")

    declarations = declaration_set(payload.physical_input)
    result = timed("candidate_build_$(scenario)") do
        build_scenario(payload.parent_context, payload.physical_input,
            declarations, scenario)
    end
    declaration = timed("candidate_validate_$(scenario)") do
        validate_candidate_result(result, payload.parent_context,
            payload.physical_input, expected_declaration(declarations, scenario),
            scenario)
    end
    assembly = timed("analytic_assembly_$(scenario)") do
        assembly_receipt(declarations, declaration, scenario)
    end
    candidate = candidate_identity(result)
    receipt = (schema="up2-04-independent-bounded-candidate-shard-v1",
        status="pass_candidate_identity_and_analytic_assembly_only",
        scenario=scenario, base_head=String(protocol.base_head),
        protocol_sha256=expected_protocol_sha,
        child_source_sha256=sha(@__FILE__),
        parent_receipt_sha256=expected_parent_receipt_sha,
        parent_artifact_sha256=sha(artifact_path),
        parent_identity=identity, candidate_identity=candidate,
        declaration=(revision=declaration.revision,
            hash=string(canonical_hash(declaration)),
            source_hash=string(canonical_hash(declaration.source)),
            boundary_hash=string(canonical_hash(declaration.boundary))),
        physical_input_hash=string(canonical_hash(payload.physical_input)),
        assembly=assembly, checks=CHECKS[],
        inherited_real_parent_and_registry_validated=true,
        dgpi_geometry_provider_executed=false,
        nonlinear_convergence="not_executed", physical_state="unknown",
        resolution="terminal_deferred", formal_up2_04="not_executed",
        scientific_credit=0)
    write_new(output_path, canonical_json(receipt) * "\n")
    println("UP2_BOUNDED_CHILD_SCENARIO=", scenario)
    println("UP2_BOUNDED_CHILD_CHECKS=", CHECKS[])
    println("UP2_BOUNDED_CHILD_RECEIPT_SHA256=", sha(output_path))
    println("UP2_BOUNDED_CHILD_EXIT_CODE=0")
end

end # module

UP2BoundedCandidateFixtureV1.main()
