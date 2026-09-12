# Declaration construction only; no provider process is started by this example.
function _spatial_candidate_timed(f, label)
    started=time_ns()
    println("SPATIAL_PREFLIGHT_STAGE_BEGIN=",label);flush(stdout)
    value=f()
    println("SPATIAL_PREFLIGHT_STAGE_END=",label," elapsed_seconds=",(time_ns()-started)/1e9);flush(stdout)
    value
end
const SPATIAL_EXAMPLE_REPO=isfile(joinpath(@__DIR__,"runtime_v4_revised_candidate.jl")) ?
    dirname(@__DIR__) : normpath(joinpath(@__DIR__,"..","..",".."))
_spatial_candidate_timed("parent_candidate") do
    include(joinpath(SPATIAL_EXAMPLE_REPO,"examples","runtime_v4_revised_candidate.jl"))
end
const SCV=RCV
_spatial_candidate_timed("spatial_source_load") do
    Base.include(SCV,joinpath(@__DIR__,"..","src","RuntimeV4","SpatialRuntimeV4.jl"))
    SCV.load_spatial_runtime_v4!()
end
const spatial=_spatial_candidate_timed("spatial_candidate_build") do
    SCV.build_spatial_candidate_v4(revised_context,dgpi_declaration)
end
const spatial_context=spatial.context
const spatial_bridge=_spatial_candidate_timed("root_bridge") do
    SCV.compile_three_d_normalized_physical_root_bridge(spatial_context)
end
const spatial_geometry=_spatial_candidate_timed("geometry_interpretation") do
    SCV.interpret_desc_geometry_program(spatial_context,spatial_bridge,(0.75,0.23,0.17))
end
const spatial_proof=_spatial_candidate_timed("geometry_proof") do
    SCV.prove_desc_geometry_compatibility(spatial_context,spatial_bridge,spatial_geometry)
end
if abspath(PROGRAM_FILE)==@__FILE__
    _spatial_candidate_timed("identity_validation") do
        SCV.validate_spatial_candidate_v4(spatial_context)
    end
    println("SPATIAL_PARENT_CANDIDATE_HASH=",revised_context.candidate_hash)
    println("SPATIAL_CANDIDATE_HASH=",spatial_context.candidate_hash)
    println("SPATIAL_CONTEXT_HASH=",spatial_context.context_hash)
    println("SPATIAL_GEOMETRY_BOUND=",SCV.spatial_candidate_geometry_bound_v4(spatial_context))
    println("SPATIAL_DECLARATION_EXIT_CODE=0")
end
