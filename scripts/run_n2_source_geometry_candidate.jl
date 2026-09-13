# Candidate-owned source geometry AST/bridge runner; never a physics solver.
using FusionConceptAI
using JSON3
using SHA
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_n2_source_geometry_candidate.jl"))

function run_n2_source_geometry_candidate(output_path::AbstractString)
    isfile(output_path) && error("refusing to overwrite an existing run")
    TDNPRB.validate_forward_chain_context(n2g_context)
    TDNPRB.validate_three_d_normalized_physical_root_bridge(
        n2g_context, n2g_bridge)
    canonical_hash(n2g_candidate_geometry_binding)
    n2g_bridge.status === :bridge_ready ||
        error("candidate-owned source geometry bridge is not structurally ready")
    example_root = normpath(joinpath(@__DIR__, ".."))
    file_sha(path) = bytes2hex(SHA.sha256(read(path)))
    value = n2g_evaluation.source_geometry
    result = (
        schema_version="n2-source-geometry-candidate-run-v1",
        status="candidate_bound_source_geometry_AST_and_SI_root_bridge_only",
        source_program_sha256=file_sha(joinpath(example_root, "src", "RuntimeV4",
            "N2SourceGeometryProgramV4.jl")),
        candidate_binding_program_sha256=file_sha(joinpath(example_root,
            "src", "RuntimeV4", "N2SourceGeometryCandidateBindingV4.jl")),
        source_artifact_sha256=n2g_program.interior.source_artifact_sha256.value,
        source_interior_result_sha256=n2g_program.interior.result_sha256.value,
        source_interior_subject_sha256=n2g_program.interior.subject_sha256.value,
        normalized_reference_subject_sha256=
            n2g_reference_binding.normalized_result_subject_sha256.value,
        candidate_hash=n2g_context.candidate_hash.value,
        context_hash=n2g_context.context_hash.value,
        physical_subject_hash=n2g_context.subject.physical_subject_hash.value,
        field_graph_binding_hash=TDNPRB.forward_graph_binding(
            n2g_context, :field_geometry).binding_hash.value,
        reference_binding_hash=n2g_reference_binding.binding_hash.value,
        source_geometry_program_hash=canonical_hash(n2g_program).value,
        source_geometry_binding_hash=canonical_hash(n2g_binding).value,
        candidate_geometry_binding_hash=n2g_candidate_geometry_binding.binding_hash.value,
        root_bridge_hash=n2g_bridge.resolution_hash.value,
        bridge_status=String(n2g_bridge.status),
        evaluation=(input_unit_turns=value.input,
            normalized_coordinate=value.normalized_coordinate,
            normalized_metric=value.normalized_metric,
            coordinate_m=value.coordinate, metric_m2=value.metric),
        recoverable_gaps=n2g_candidate_geometry_binding.recoverable_gaps,
        authority=(claim_ceiling="screen_only", geometry_proved=false,
            provider_selected=false, provider_executed=false,
            solver_executed=false, independent_physical_solver=false,
            physical_validation="unsupported", credible_device_count=0))
    mkpath(dirname(output_path))
    isfile(output_path) && error("refusing to overwrite an existing run")
    open(output_path, "w") do stream
        JSON3.pretty(stream, result)
        println(stream)
    end
    println("N2_SOURCE_GEOMETRY_CANDIDATE_OUTPUT=", abspath(output_path))
    println("N2_SOURCE_GEOMETRY_CANDIDATE_BRIDGE=", result.bridge_status)
    println("N2_SOURCE_GEOMETRY_CANDIDATE_SCIENTIFIC_STATUS=structural_only")
    println("N2_SOURCE_GEOMETRY_CANDIDATE_PHYSICAL_VALIDATION=unsupported")
    0
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("usage: run_n2_source_geometry_candidate.jl NEW_RESULT_JSON")
    exit(run_n2_source_geometry_candidate(ARGS[1]))
end
