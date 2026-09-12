# Loads only declarations and geometry; no DESC process is started here.
include(joinpath(@__DIR__,"runtime_v4_desc_geometry_compatibility_proof.jl"))
const RCV=DGPI
for source in ("DESCRequestProviderExecutionV4.jl","CompleteMultiRegionV4.jl",
               "MagneticEngineeringV4.jl","ExecutedVerificationUQV4.jl","RevisedCandidateV4.jl")
    Base.include(RCV,joinpath(@__DIR__,"..","src","RuntimeV4",source))
end
const revised = RCV.build_revised_candidate_v4(dgpi_context,dgpi_declaration)
const revised_context = revised.context
const revised_bridge=RCV.compile_three_d_normalized_physical_root_bridge(revised_context)
const revised_geometry=RCV.interpret_desc_geometry_program(revised_context,revised_bridge,(0.75,0.23,0.17))
const revised_proof=RCV.prove_desc_geometry_compatibility(revised_context,revised_bridge,revised_geometry)
if abspath(PROGRAM_FILE)==@__FILE__
    println("parent_hash=",revised.parent_hash)
    println("candidate_hash=",revised_context.candidate_hash)
    println("proof_status=",revised_proof.status)
    println("REVISED_CANDIDATE_DECLARATION_EXIT_CODE=0")
end
