# A G2 declaration descendant of the existing DESC-eligible spatial fixture.
# Construction and proof only; the production runner starts the provider process.
include(joinpath(@__DIR__, "runtime_v4_revised_candidate.jl"))
const SCV = RCV
Base.include(SCV, joinpath(@__DIR__, "..", "src", "RuntimeV4", "SpatialRuntimeV4.jl"))
Base.invokelatest(SCV.load_spatial_runtime_v4!)

const spatial_parent = Base.invokelatest(SCV.build_spatial_candidate_v4,
    revised_context, dgpi_declaration)
const spatial = Base.invokelatest(SCV.build_spatial_geometry_edit_v4,
    spatial_parent.context; coefficient_m=0.42)
const spatial_context = spatial.context
const spatial_bridge = SCV.compile_three_d_normalized_physical_root_bridge(spatial_context)
const spatial_geometry = SCV.interpret_desc_geometry_program(
    spatial_context, spatial_bridge, (0.75, 0.23, 0.17))
const spatial_proof = SCV.prove_desc_geometry_compatibility(
    spatial_context, spatial_bridge, spatial_geometry)

if abspath(PROGRAM_FILE) == @__FILE__
    Base.invokelatest(SCV.validate_spatial_candidate_v4, spatial_context)
    println("SPATIAL_G2_PARENT_CANDIDATE_HASH=", spatial_parent.context.candidate_hash)
    println("SPATIAL_G2_CHILD_CANDIDATE_HASH=", spatial_context.candidate_hash)
    println("SPATIAL_G2_CHILD_CONTEXT_HASH=", spatial_context.context_hash)
    println("SPATIAL_G2_CHILD_DECLARATION_EXIT_CODE=0")
end
