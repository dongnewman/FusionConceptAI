"""Load-only smoke check for the additive UP2 cross-mesh transfer API.

This entry verifies module composition and public type/function presence. It
does not build the thermal fixture, continue T1, construct a transfer receipt,
dispatch a solver, or execute T2/Q1_8 work.
"""

using Test
using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
# The additive DCCE modules use the current-source G1/G2/G3 declaration types.
# Loading their definitions does not execute a T1/T2 admission or a solver.
FusionConceptAI.load_vnext_t2_components_v2!()
isdefined(Main, :FusionRuntimeV4) ||
    include(joinpath(@__DIR__, "../../../src/RuntimeV4/FusionRuntimeV4.jl"))
for source in (
        "DeclaredG123DiffusionExecutionV1.jl",
        "DeclaredSpatialCompositionExecutionV1.jl",
        "DeclaredDiffusionCompileExecuteV1.jl",
        "DeclaredCrossMeshConservativeTransferExecutionV1.jl")
    Base.include(FusionConceptAI,
        joinpath(@__DIR__, "../../../src/RuntimeV4", source))
end

@testset "UP2-03 cross-mesh module load only" begin
    @test isdefined(FusionConceptAI, :DeclaredCrossMeshTransferReceiptV1)
    @test isdefined(FusionConceptAI, :DeclaredCrossMeshAccountsV1)
    @test isdefined(FusionConceptAI, :declared_cross_mesh_transfer_v1)
    @test isdefined(FusionConceptAI, :execute_declared_cross_mesh_v1)
    @test isdefined(FusionConceptAI, :dcce_compile_execute_v1)
end

println("UP2_03_MODULE_LOAD_ONLY=true")
println("UP2_03_T1_CONTINUATION_EXECUTED=false")
println("UP2_03_TRANSFER_OR_SOLVER_EXECUTED=false")
println("UP2_03_T2_OR_Q1_8_EXECUTED=false")
