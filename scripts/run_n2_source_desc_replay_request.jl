# Emit a candidate-owned source-basis DESC replay request, not solver evidence.
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_n2_source_geometry_candidate.jl"))
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceDESCReplayRequestV4.jl"))

function run_n2_source_desc_replay_request(output_path::AbstractString)
    member_path = normpath(joinpath(@__DIR__, "..", "runs",
        "goal_recovery_20260913_012528_cst", "n2_source_member_join_r3",
        "result.json"))
    member_sha = Digest256(
        "e379fbe4ca6ee85a4aae59029dd3109ff9b20c04d2969480e7685412925bddbf")
    controls = TDNPRB.N2SourceDESCReplayControlsV4(3, 1e-8, 1e-8, 1e-8)
    request = TDNPRB.make_n2_source_desc_replay_request(
        n2g_context, n2g_candidate_geometry_binding, n2g_binding,
        n2g_reference_binding, n2g_bridge, n2g_source_path,
        n2g_interior_path, member_path, member_sha, controls)
    file_sha = TDNPRB.write_n2_source_desc_replay_request(request, output_path)
    println("N2_SOURCE_DESC_REQUEST_OUTPUT=", abspath(output_path))
    println("N2_SOURCE_DESC_REQUEST_SHA256=", file_sha.value)
    println("N2_SOURCE_DESC_REQUEST_HASH=", canonical_hash(request).value)
    println("N2_SOURCE_DESC_REQUEST_SCIENTIFIC_STATUS=request_only")
    println("N2_SOURCE_DESC_REQUEST_PHYSICAL_VALIDATION=unsupported")
    0
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("usage: run_n2_source_desc_replay_request.jl NEW_REQUEST_JSON")
    exit(run_n2_source_desc_replay_request(ARGS[1]))
end
