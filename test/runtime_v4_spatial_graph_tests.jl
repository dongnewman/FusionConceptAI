using FusionConceptAI,Test
module SpatialGraphUnit
using FusionConceptAI
const root=isfile(joinpath(@__DIR__,"..","src","RuntimeV4","RevisedCandidateV4.jl")) ?
    normpath(joinpath(@__DIR__,"..")) : normpath(joinpath(@__DIR__,"..","..",".."))
include(joinpath(root,"src","RuntimeV4","RevisedCandidateV4.jl"))
for f in ("SpatialExecutionTypesV4.jl","SpatialMultiRegionV4.jl","SpatialPickupEngineeringV4.jl","SpatialVerificationUQV4.jl","SpatialCandidateV4.jl")
    include(joinpath(@__DIR__,"..","src","RuntimeV4",f))
end
end
@testset "spatial physical types and owned executable operators" begin
    M=SpatialGraphUnit;p=M.spatial_multiregion_declaration_v4(;flux_Wb=1.0);e=M.spatial_engineering_declaration_v4()
    parent=(mechanism_genome_ref=(contract_ref=g1_occurrence_ownership_contract_ref("urn:fusion:runtime:mechanism"),),)
    g=M.spatial_mechanism_v4(parent,p,e)
    @test length(g.payload.states)==7
    @test length(g.payload.operator_graph.hyperedges)==6
    rg,cg=M.spatial_engineering_graphs_v4(e)
    @test length(rg.hyperedges)==3 && length(cg.hyperedges)==1
    for edge in (rg.hyperedges...,cg.hyperedges...)
        @test only(n.value for n in edge.program.nodes if n isa ASTConstantV1)==QualifiedRefV1(canonical_hash(e).value,"v1")
        @test isempty(last(edge.program.nodes).parameters)
    end
    @test length(default_operator_registry().operators)==20
end
@testset "same candidate different upstream execution rejected" begin
    M=SpatialGraphUnit
    receipt=(output_path="bound.h5",output_sha256=digest256_text("actual bytes"))
    u=(request=(request_id="one",),result=(receipt=receipt,))
    execution=(upstream_request_hash=canonical_hash(u.request),upstream_result_hash=canonical_hash(u.result),
        upstream_receipt_hash=canonical_hash(receipt),hdf5=(path=receipt.output_path,sha256=receipt.output_sha256))
    @test M.validate_spatial_upstream_link_v4(u,(execution=execution,))
    @test_throws ErrorException M.validate_spatial_upstream_link_v4(merge(u,(request=(request_id="two",),)),(execution=execution,))
    bad=merge(execution,(hdf5=(path=receipt.output_path,sha256=digest256_text("other bytes")),))
    @test_throws ErrorException M.validate_spatial_upstream_link_v4(u,(execution=bad,))
end
