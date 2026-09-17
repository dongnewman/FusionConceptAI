using Test
using SHA
using JSON3
using Dates
using FusionConceptAI

const G = FusionConceptAI
const START_UTC = Dates.now(Dates.UTC)
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "..", "..", "..", "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "..", ".."))
const SCOPES = (:realization, :control, :binding, :bundle)
const HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
const HANDLE_ID = "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7"
const HANDLE_VERSION = "v5"
const ENVELOPE_PATH = "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
const ENVELOPE_SHA = "17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc"
const FACTORY_SOURCE_SHA = "1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4"
const FACTORY_TEST_SHA = "02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f"
const ROOT_ACCEPTANCE_PATH = "docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/root_acceptance_r3/manifest.json"

function frozen_locator(scope::Symbol)
    p = joinpath(ROOT, "docs", "implementation", "AD-48", "S1-SOURCE-LOCATORS", String(scope), "source_locator_v1.json")
    j = JSON3.read(read(p, String))
    body = j.semantic_body
    role = scope === :bundle ? "g3_bundle_source" : "g3_main_source"
    row = only(filter(x -> String(x.role) == role, body.source_closure))
    G.G3IndependentSourceLocatorV1(scope, normpath(String(body.repository.root)), String(body.repository.observed_head), String(row.path), Int(row.bytes), G.Digest256(String(row.sha256)), Symbol(row.head_path_status), Symbol(row.working_tree_path_status), Symbol(row.working_tree_status), row.head_blob_sha256 === nothing ? nothing : G.Digest256(String(row.head_blob_sha256)))
end

declaration_ref(scope) = G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad48-s2-fresh-r2", "v1")
const HANDLE = G.QualifiedRefV1(HANDLE_ID, HANDLE_VERSION)

@testset "AD48 fresh S2 exact real input factory construction" begin
    env = joinpath(ROOT, split(ENVELOPE_PATH, '/')...)
    @test isfile(env)
    @test stat(env).size == 9612
    @test bytes2hex(SHA.sha256(read(env))) == ENVELOPE_SHA
    factory_path = joinpath(ROOT, "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl")
    test_path = joinpath(ROOT, "test", "GenomeV5", "G3", "g3_source_authority_factory_v1_tests.jl")
    @test bytes2hex(SHA.sha256(read(factory_path))) == FACTORY_SOURCE_SHA
    @test bytes2hex(SHA.sha256(read(test_path))) == FACTORY_TEST_SHA
    @test G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1 == HANDLE_ID
    @test G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1 == HANDLE_VERSION
    rows = Dict{String,Any}()
    for scope in SCOPES
        locator = frozen_locator(scope)
        @test locator.observed_head == HEAD
        @test locator.head_path_status == :absent_untracked
        @test locator.working_tree_path_status == :absent_untracked
        @test locator.working_tree_status == :untracked
        result = G.g3_source_authority_factory_v1(scope, locator, HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref(scope))
        @test G.g3_factory_result_status(result) == :present
        @test result.identity isa G.PresentG3FactoryIdentityV1
        @test result.receipt isa G.PresentG3FactoryConstructionReceiptV1
        @test result.binding isa G.G3SourceContractBindingV1
        @test result.source_declaration isa G.G3CandidateBoundSourceDeclarationV1
        @test result.binding.common_binding_handle == HANDLE
        @test result.binding.binding_role == :temporary_common_candidate_binding_handle_only
        @test result.binding.candidate_identity_created == false
        @test result.identity.scope == scope
        @test result.source_declaration.declaration_ref == declaration_ref(scope)
        @test result.identity.registry_not_used
        @test result.receipt.registry_not_used
        @test result.receipt.trusted_attestation_created == false
        @test result.identity.candidate_identity_created == false
        @test result.identity.final_candidate_or_package_declaration_hash_created == false
        @test result.receipt.candidate_identity_created == false
        @test result.receipt.final_candidate_or_package_declaration_hash_created == false
        @test G.canonical_hash(result.binding) == result.binding.binding_digest
        @test G.canonical_hash(result.source_declaration.content) == result.source_declaration.content.source_content_digest
        @test G.canonical_hash(result.source_declaration) == result.source_declaration.source_declaration_hash
        rows[String(scope)] = (status=String(G.g3_factory_result_status(result)), binding_digest=string(result.binding.binding_digest), source_content_digest=string(result.source_declaration.content.source_content_digest), source_declaration_hash=string(result.source_declaration.source_declaration_hash), construction_digest=string(result.receipt.construction_digest), source_path=String(result.source_declaration.content.source_path), source_sha256=string(result.source_declaration.content.source_sha256), contract_ref=G.semantic_view(result.binding).contract_ref, axes=G.semantic_view(result.binding).version_axes)
    end
    println(JSON3.write((status="pass", check="exact_ad45_s1_real_input", scopes=rows, pid=getpid(), utc_start=string(START_UTC), utc_end=string(Dates.now(Dates.UTC)))))
end
