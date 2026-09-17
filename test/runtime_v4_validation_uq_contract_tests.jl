using Test

module VUQTestModule
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "ValidationUQContracts.jl"))
end

const V = VUQTestModule.FusionRuntimeV4
const h(x) = VUQTestModule.FusionConceptAI.digest256_text(String(x))

@testset "Runtime V4 validation/UQ contract" begin
    @test_throws MethodError V.ValidationBindingV4(h("candidate"), h("subject"), h("scenario"), h("observable"), ())
    @test_throws ArgumentError V.ProvenanceV4("https://example.test/data", "dataset-1", h("record"), "calibration", "open", "synthetic")
    @test_throws ArgumentError V.ObservableDatumV4(:y, 1.0, 0.0)
    @test_throws ArgumentError V.ApplicabilityEnvelopeV4((temperature=(0.0,100.0),); within_domain=true)
    @test_throws ArgumentError V.ParameterDistributionV4("k", :normal, (mean=1.0,), (1.0,1.0))
    @test_throws ArgumentError V.UncertaintyBudgetV4((x=1,), (x=1,), (x=1,), (x=1,); correlations=((left=:a,right=:b,coefficient=2.0),))
end
