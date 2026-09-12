using FusionConceptAI,Test
include(joinpath(@__DIR__,"..","scripts","revised_run_checkpoint_v4.jl"))
@testset "resume preserves existing identity on rejection" begin
    mktempdir() do dir
        path=joinpath(dir,"candidate.json")
        original="{\"candidate\":\"original\"}\n"
        write(path,original)
        @test verify_revised_checkpoint_identity_v4(path,original)
        @test_throws ArgumentError verify_revised_checkpoint_identity_v4(path,"different revision\n")
        @test read(path,String)==original
        @test_throws ArgumentError verify_revised_checkpoint_identity_v4(joinpath(dir,"missing.json"),original)
    end
end
module RevisedGraphUnit
using FusionConceptAI
for file in ("CompleteMultiRegionV4.jl","MagneticEngineeringV4.jl","ExecutedVerificationUQV4.jl","RevisedCandidateV4.jl")
    include(joinpath(@__DIR__,"..","src","RuntimeV4",file))
end
end
@testset "revised G1 G3 exact operator declaration payloads" begin
    R=RevisedGraphUnit;p=R.multiregion_declaration_v4();e=R.engineering_declaration_v4()
    parent=(mechanism_genome_ref=(contract_ref=g1_occurrence_ownership_contract_ref("urn:fusion:runtime:mechanism"),),)
    mechanism=R.revised_mechanism_v4(parent,p,e)
    @test length(mechanism.payload.states)==7
    @test length(mechanism.payload.operator_graph.hyperedges)==5
    rg,cg=R.revised_engineering_graphs_v4(e)
    @test length(rg.hyperedges)==2
    @test length(cg.hyperedges)==1
    for edge in (rg.hyperedges...,cg.hyperedges...)
        value=only(n.value for n in edge.program.nodes if n isa ASTConstantV1)
        @test value==QualifiedRefV1(canonical_hash(e).value,"v1")
        @test isempty(last(edge.program.nodes).parameters)
    end
    @test length(default_operator_registry().operators)==20
end
