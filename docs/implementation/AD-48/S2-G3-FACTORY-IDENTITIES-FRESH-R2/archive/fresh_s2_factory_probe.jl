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
const F0_SOURCE = "1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4"
const F0_TEST = "02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f"
const ROOT_ACCEPTANCE = "docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/root_acceptance_r3/manifest.json"

function frozen_locator(scope::Symbol)
    p = joinpath(ROOT, "docs", "implementation", "AD-48", "S1-SOURCE-LOCATORS", String(scope), "source_locator_v1.json")
    j = JSON3.read(read(p, String)); body = j.semantic_body
    role = scope === :bundle ? "g3_bundle_source" : "g3_main_source"
    row = only(filter(x -> String(x.role) == role, body.source_closure))
    G.G3IndependentSourceLocatorV1(scope, normpath(String(body.repository.root)),
        String(body.repository.observed_head), String(row.path), Int(row.bytes),
        G.Digest256(String(row.sha256)), Symbol(row.head_path_status),
        Symbol(row.working_tree_path_status), Symbol(row.working_tree_status),
        row.head_blob_sha256 === nothing ? nothing : G.Digest256(String(row.head_blob_sha256)))
end

declaration_ref(scope) = G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad48-s2-fresh-r2", "v1")
const HANDLE = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1)

function emit_json(path, body)
    bytes = codeunits(G.canonical_json(body))
    write(path, bytes)
    length(bytes), bytes2hex(SHA.sha256(bytes))
end

function evidence_inputs(scope, locator)
    s1 = "docs/implementation/AD-48/S1-SOURCE-LOCATORS/$(scope)/source_locator_v1.json"
    (s1_locator=(path=s1, sha256=bytes2hex(SHA.sha256(read(joinpath(ROOT, s1))))),
     ad45=(handle_id=HANDLE.id, handle_version=HANDLE.version,
        envelope_path=G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1,
        envelope_sha256=string(G.G3_AD45_ENVELOPE_SHA256_V1)),
     f0=(source_factory_path="src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl", source_factory_sha256=F0_SOURCE,
         test_path="test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl", test_sha256=F0_TEST,
         root_acceptance_manifest=(path=ROOT_ACCEPTANCE, sha256=bytes2hex(SHA.sha256(read(joinpath(ROOT, split(ROOT_ACCEPTANCE, '/')...)))))))
end

results = Dict{Symbol,Any}()
for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
    locator = frozen_locator(scope)
    result = G.g3_source_authority_factory_v1(scope, locator, HANDLE,
        G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref(scope))
    @test G.g3_factory_result_status(result) == :present
    @test result.identity isa G.PresentG3FactoryIdentityV1
    @test result.receipt isa G.PresentG3FactoryConstructionReceiptV1
    @test result.binding isa G.G3SourceContractBindingV1
    @test result.source_declaration isa G.G3CandidateBoundSourceDeclarationV1
    @test result.receipt.trusted_attestation_created == false
    @test result.identity.candidate_identity_created == false
    @test result.identity.final_candidate_or_package_declaration_hash_created == false
    @test result.source_declaration.final_candidate_or_package_declaration_hash_created == false
    @test G.canonical_hash(result.binding) == result.binding.binding_digest
    @test G.canonical_hash(result.source_declaration.content) == result.source_declaration.content.source_content_digest
    @test G.canonical_hash(result.source_declaration) == result.source_declaration.source_declaration_hash
    id_body = (candidate_identity_created=false, declaration_hash_created=false,
        forbidden_derivations=("fixture","seed","URI","W2R1","bundle_hash","own_hash","candidate_hash","test_exit_code","runner_exit_code"),
        no_publish=true, record_kind="G3FactoryIdentityV1", result="PresentG3FactoryIdentityV1",
        schema_version="AD48-G3-factory-identity-v1", scope=String(scope), semantic_body=G.semantic_view(result.identity),
        semantic_hash=string(G.canonical_hash(G.semantic_view(result.identity))), semantic_hash_algorithm="sha256(canonical_json(semantic_body))",
        task_id="AD48-S2-G3-FACTORY-IDENTITY-FRESH-R2", inputs=evidence_inputs(scope, locator),
        g3_source_declaration_hash=string(result.source_declaration.source_declaration_hash),
        g3_source_declaration_hash_created=true, final_candidate_or_package_declaration_hash_created=false,
        trusted_attestation_created=false,
        factory_identity_digest=string(result.identity.factory_identity_digest),
        g3_source_contract_binding_digest=string(result.binding.binding_digest),
        source_declaration_ref=string(result.source_declaration.declaration_ref.id),
        source_content_digest=string(result.source_declaration.content.source_content_digest),
        git_freshness=(observed_head=locator.observed_head, head_path_status=String(locator.head_path_status),
            head_blob_sha256=locator.head_blob_sha256 === nothing ? nothing : string(locator.head_blob_sha256),
            working_tree_path_status=String(locator.working_tree_path_status), working_tree_status=String(locator.working_tree_status)))
    rec_body = (candidate_identity_created=false, declaration_hash_created=true,
        forbidden_derivations=id_body.forbidden_derivations, no_publish=true,
        record_kind="G3FactoryConstructionReceiptV1", result="PresentG3FactoryConstructionReceiptV1",
        schema_version="AD48-G3-factory-construction-receipt-v1", scope=String(scope), semantic_body=G.semantic_view(result.receipt),
        semantic_hash=string(G.canonical_hash(G.semantic_view(result.receipt))), semantic_hash_algorithm="sha256(canonical_json(semantic_body))",
        task_id="AD48-S2-G3-FACTORY-IDENTITY-FRESH-R2", inputs=evidence_inputs(scope, locator),
        source_declaration_ref=string(result.source_declaration.declaration_ref.id),
        g3_source_declaration_hash=string(result.source_declaration.source_declaration_hash),
        trusted_attestation_created=false, registry_not_used=true,
        factory_identity_digest=string(result.identity.factory_identity_digest),
        g3_source_contract_binding_digest=string(result.binding.binding_digest),
        source_content_digest=string(result.source_declaration.content.source_content_digest),
        construction_digest=string(result.receipt.construction_digest),
        git_freshness=(observed_head=locator.observed_head, head_path_status=String(locator.head_path_status),
            head_blob_sha256=locator.head_blob_sha256 === nothing ? nothing : string(locator.head_blob_sha256),
            working_tree_path_status=String(locator.working_tree_path_status), working_tree_status=String(locator.working_tree_status)))
    emit_json(joinpath(OUT, String(scope), "factory_identity_v1.json"), id_body)
    emit_json(joinpath(OUT, String(scope), "construction_receipt.json"), rec_body)
    results[scope] = (identity=string(result.identity.source_declaration_hash), declaration=string(result.source_declaration.source_declaration_hash), content=string(result.source_declaration.content.source_content_digest), construction=string(result.receipt.construction_digest))
end

println(JSON3.write((status="pass", scopes=results, pid=getpid(), utc=string(Dates.now(Dates.UTC)))))
