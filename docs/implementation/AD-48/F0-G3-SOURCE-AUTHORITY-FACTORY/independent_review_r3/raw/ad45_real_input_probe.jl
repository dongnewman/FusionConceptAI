using Test
using SHA
using JSON3
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "..", "..", "..", "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "..", ".."))

function frozen_locator(scope::Symbol)
    p = joinpath(ROOT, "docs", "implementation", "AD-48", "S1-SOURCE-LOCATORS",
        String(scope), "source_locator_v1.json")
    j = JSON3.read(read(p, String))
    body = j.semantic_body
    role = scope === :realization ? "g3_main_source" :
        scope === :control ? "g3_main_source" :
        scope === :binding ? "g3_main_source" : "g3_bundle_source"
    row = only(filter(x -> String(x.role) == role, body.source_closure))
    G.G3IndependentSourceLocatorV1(scope, normpath(String(body.repository.root)),
        String(body.repository.observed_head), String(row.path), Int(row.bytes),
        G.Digest256(String(row.sha256)), Symbol(row.head_path_status),
        Symbol(row.working_tree_path_status), Symbol(row.working_tree_status),
        row.head_blob_sha256 === nothing ? nothing : G.Digest256(String(row.head_blob_sha256)))
end

function declaration_ref(scope::Symbol)
    G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad48-f0", "v1")
end

const HANDLE = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1,
    G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1)
const ENV_PATH = joinpath(ROOT, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
const ENV_BYTES = read(ENV_PATH)

@testset "AD48 F0 R3 exact AD45 real inputs" begin
    @test isfile(ENV_PATH)
    @test length(ENV_BYTES) == 9612
    @test G.Digest256(bytes2hex(SHA.sha256(ENV_BYTES))) == G.G3_AD45_ENVELOPE_SHA256_V1
    @test HANDLE.id == "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7"
    @test HANDLE.version == "v5"
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        locator = frozen_locator(scope)
        result = G.g3_source_authority_factory_v1(scope, locator, HANDLE,
            G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref(scope))
        @test G.g3_factory_result_status(result) == :present
        @test result.identity isa G.PresentG3FactoryIdentityV1
        @test result.binding isa G.G3SourceContractBindingV1
        @test result.binding.common_binding_handle == HANDLE
        @test result.binding.binding_role == :temporary_common_candidate_binding_handle_only
        @test !result.binding.candidate_identity_created
        @test result.source_declaration isa G.G3CandidateBoundSourceDeclarationV1
        @test result.source_declaration.content.source_path == locator.source_path
        @test result.source_declaration.content.source_sha256 == locator.source_sha256
        @test result.source_declaration.content.common_binding_envelope_path == G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1
        @test result.source_declaration.content.common_binding_envelope_sha256 == G.G3_AD45_ENVELOPE_SHA256_V1
        @test G.canonical_hash(result.binding) == result.binding.binding_digest
        @test G.canonical_hash(result.source_declaration.content) == result.source_declaration.content.source_content_digest
        @test G.canonical_hash(result.source_declaration) == result.source_declaration.source_declaration_hash
        @test !result.identity.candidate_identity_created
        @test result.identity.g3_source_declaration_hash_created
        @test !result.identity.final_candidate_or_package_declaration_hash_created
        @test !result.receipt.trusted_attestation_created
    end

    scope = :realization
    locator = frozen_locator(scope)
    cases = (
        (G.QualifiedRefV1("fusionconceptai://candidate/ad48-f0-handle", "v5"), :foreign_common_handle),
        (G.QualifiedRefV1("foreign://handle", "v5"), :foreign_common_handle),
        (G.QualifiedRefV1(HANDLE.id, "v1"), :common_handle_version_mismatch),
        (G.QualifiedRefV1(replace(HANDLE.id, "3da169fa-2376-4b36-b794-ac5a32161aa7" => "00000000-0000-0000-0000-000000000000"), "v5"), :foreign_common_handle),
        (G.QualifiedRefV1(HANDLE.id * "/alias", "v5"), :foreign_common_handle))
    for (handle, reason) in cases
        result = G.g3_source_authority_factory_v1(scope, locator, handle,
            G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref(scope))
        @test G.g3_factory_result_status(result) == :fail_closed
        @test result.identity isa G.FailedG3FactoryIdentityV1
        @test result.identity.reason == reason
        @test result.receipt.fail_closed
    end
    @test G.g3_factory_result_status(G.g3_source_authority_factory_v1(scope, nothing,
        HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref(scope))) == :typed_absent
    bad_hash = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
        locator.observed_head, locator.source_path, locator.source_bytes,
        G.digest256_text("mutated"), locator.head_path_status,
        locator.working_tree_path_status, locator.working_tree_status,
        locator.head_blob_sha256)
    @test G.g3_source_authority_factory_v1(scope, bad_hash, HANDLE,
        G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref(scope)).identity.reason == :source_hash_mismatch
end

println("exact_ad45_real_input_probe=PASS")
