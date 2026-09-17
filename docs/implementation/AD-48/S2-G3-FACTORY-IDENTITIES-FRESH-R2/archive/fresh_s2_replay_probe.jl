using Test
using SHA
using JSON3
using Dates
using FusionConceptAI
const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "..", "..", "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const OUT = joinpath(ROOT, "docs", "implementation", "AD-48", "S2-G3-FACTORY-IDENTITIES-FRESH-R2")
function locator(scope)
    p = joinpath(ROOT, "docs", "implementation", "AD-48", "S1-SOURCE-LOCATORS", String(scope), "source_locator_v1.json")
    j = JSON3.read(read(p, String)); b=j.semantic_body; role=scope===:bundle ? "g3_bundle_source" : "g3_main_source"; r=only(filter(x->String(x.role)==role,b.source_closure))
    G.G3IndependentSourceLocatorV1(scope,normpath(String(b.repository.root)),String(b.repository.observed_head),String(r.path),Int(r.bytes),G.Digest256(String(r.sha256)),Symbol(r.head_path_status),Symbol(r.working_tree_path_status),Symbol(r.working_tree_status),r.head_blob_sha256===nothing ? nothing : G.Digest256(String(r.head_blob_sha256)))
end
const H=G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1,G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1)
decl(s)=G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(s)/source-declaration/ad48-s2-fresh-r2","v1")
rows=Dict{String,Any}()
for s in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
    r=G.g3_source_authority_factory_v1(s,locator(s),H,G.g3_contract_ref(s),G.g3_version_axes(s),decl(s)); @test G.g3_factory_result_status(r)==:present
    id=JSON3.read(read(joinpath(OUT,String(s),"factory_identity_v1.json"),String)); rc=JSON3.read(read(joinpath(OUT,String(s),"construction_receipt.json"),String))
    @test String(id.semantic_hash)==string(G.canonical_hash(G.semantic_view(r.identity)))
    @test String(rc.semantic_hash)==string(G.canonical_hash(G.semantic_view(r.receipt)))
    @test String(id.g3_source_declaration_hash)==string(r.source_declaration.source_declaration_hash)
    @test String(rc.construction_digest)==string(r.receipt.construction_digest)
    rows[String(s)]=(identity_file_sha256=bytes2hex(SHA.sha256(read(joinpath(OUT,String(s),"factory_identity_v1.json")))),receipt_file_sha256=bytes2hex(SHA.sha256(read(joinpath(OUT,String(s),"construction_receipt.json")))),declaration=string(r.source_declaration.source_declaration_hash),construction=string(r.receipt.construction_digest))
end
println(JSON3.write((status="replay_pass",pid=getpid(),utc=string(Dates.now(Dates.UTC)),scopes=rows)))
