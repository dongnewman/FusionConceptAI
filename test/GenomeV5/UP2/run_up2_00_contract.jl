using Test
using JSON3
using FusionConceptAI

FusionConceptAI.load_genome_v5_up2_components!()
FusionConceptAI.load_vnext_t2_components_v2!()
# The Windows default task stack is too small for nested native semantic views
# at -O0. Keep the complete consumer on one task within the existing memory cap.
if Sys.iswindows()
    let testfile = joinpath(@__DIR__, "up2_00_contract_tests.jl")
        task = Task(() -> Base.include(Main, testfile), 16 * 1024 * 1024)
        schedule(task)
        fetch(task)
    end
else
    include(joinpath(@__DIR__, "up2_00_contract_tests.jl"))
end
