using Test
using SHA
using FusionConceptAI

const SPATIAL_ENTRYPOINT_REPO = normpath(joinpath(@__DIR__, ".."))
const SPATIAL_ENTRYPOINT_AGGREGATOR = joinpath(SPATIAL_ENTRYPOINT_REPO, "src", "RuntimeV4", "SpatialRuntimeV4.jl")

module SpatialLoadProbe
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "SpatialRuntimeV4.jl"))
end

module SpatialPartialLoadProbe
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "SpatialRuntimeV4.jl"))
end

@testset "RuntimeV4 spatial source aggregator" begin
    expected = (
        "SpatialExecutionTypesV4.jl",
        "SpatialMultiRegionV4.jl",
        "SpatialPickupEngineeringV4.jl",
        "SpatialVerificationUQV4.jl",
        "SpatialCandidateV4.jl",
        "SpatialWholeDeviceV4.jl",
    )
    @test SpatialLoadProbe.SPATIAL_RUNTIME_V4_LOAD_STATE[] === :unloaded
    @test SpatialLoadProbe.SPATIAL_RUNTIME_V4_SOURCE_ORDER_V1 == expected
    @test all(isfile(joinpath(SPATIAL_ENTRYPOINT_REPO, "src", "RuntimeV4", source)) for source in expected)
    expected_hashes = Tuple(
        (source, bytes2hex(SHA.sha256(read(joinpath(SPATIAL_ENTRYPOINT_REPO, "src", "RuntimeV4", source)))))
        for source in expected
    )
    @test SpatialLoadProbe.SPATIAL_RUNTIME_V4_SOURCE_HASHES_V1 == expected_hashes

    calls = String[]
    hashes = SpatialLoadProbe.load_spatial_runtime_v4!(;
        include_file=(mod, path)->push!(calls, basename(path)))
    @test Tuple(calls) == expected
    @test hashes == expected_hashes
    @test SpatialLoadProbe.SPATIAL_RUNTIME_V4_LOAD_STATE[] === :loaded
    @test_throws ErrorException SpatialLoadProbe.load_spatial_runtime_v4!(;
        include_file=(mod, path)->nothing)

    partial_calls = String[]
    @test_throws ErrorException SpatialPartialLoadProbe.load_spatial_runtime_v4!(;
        include_file=(mod, path)->begin
            push!(partial_calls, basename(path))
            length(partial_calls) == 3 && error("injected child include failure")
        end)
    @test partial_calls == collect(expected[1:3])
    @test SpatialPartialLoadProbe.SPATIAL_RUNTIME_V4_LOAD_STATE[] === :loading
    @test_throws ErrorException SpatialPartialLoadProbe.load_spatial_runtime_v4!(;
        include_file=(mod, path)->nothing)

    example_text = read(joinpath(SPATIAL_ENTRYPOINT_REPO, "examples", "runtime_v4_spatial_candidate.jl"), String)
    runner_text = read(joinpath(SPATIAL_ENTRYPOINT_REPO, "scripts", "run_v4_spatial_chain.jl"), String)
    @test occursin("SpatialRuntimeV4.jl", example_text)
    @test occursin("load_spatial_runtime_v4!", example_text)
    @test !occursin("Base.include(SCV,joinpath(SPATIAL_REPO,\"src\",\"RuntimeV4\",\"SpatialWholeDeviceV4.jl\"))", runner_text)
end
