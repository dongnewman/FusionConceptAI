using Test
using JSON3
using FusionConceptAI

const _AR_ROOT = joinpath(@__DIR__, "..", "..", "..", "src")
const _G3_ROOT = joinpath(_AR_ROOT, "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3_ROOT, "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_AR_ROOT, "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckV1.jl"))
const G = FusionConceptAI
const _FIXTURE = JSON3.read(read(joinpath(@__DIR__,
    "vnext_declaration_authority_recheck_v1_fixture.json"), String))
const _A = G.Digest256(repeat("a", 64))
const _B = G.Digest256(repeat("b", 64))
const _CANDIDATE = G.QualifiedRefV1(String(_FIXTURE.candidate_ref.id),
    String(_FIXTURE.candidate_ref.version))
const _UNIT = G.UnitSignature((1, 2, -3, 0, 0, 0, 0))

function _authority(layer, status; candidate=_CANDIDATE, contract=nothing,
        hash=nothing, attestation=:unattested)
    G.G3SFAuthorityV1(layer, candidate, contract, hash, status;
        attestation=attestation)
end

function _g3_declaration(;candidate=_CANDIDATE, g1_status=:missing, g2_status=:missing,
        g1_target_authority=nothing, g2_target_authority=nothing,
        targets_override=nothing, upstream_override=nothing, g1_hash=nothing)
    owner = String(_FIXTURE.owner_scope)
    contract_g1 = GenomeContractRef("fusionconceptai://GenomeV5/G1/legacy",
        "v5", _A, _B, "legacy-profile")
    contract_g2 = GenomeContractRef("fusionconceptai://GenomeV5/G2/legacy",
        "v5", _A, _B, "legacy-profile")
    g1 = _authority(:G1, g1_status; candidate=candidate, contract=contract_g1,
        hash=g1_hash === nothing ? G.digest256_text("g1-legacy") : g1_hash,
        attestation=g1_status === :actual ? :trusted_receipt : :unattested)
    g2 = _authority(:G2, g2_status; candidate=candidate, contract=contract_g2,
        hash=G.digest256_text("g2-legacy"),
        attestation=g2_status === :actual ? :trusted_receipt : :unattested)
    upstream = upstream_override === nothing ? (g1, g2) : upstream_override
    auth1 = g1_target_authority === nothing ? g1 : g1_target_authority
    auth2 = g2_target_authority === nothing ? g2 : g2_target_authority
    targets = targets_override === nothing ? (
        G.G3SFFeedbackTargetV1("g1-target", :G1, "/g1/residual", :residual,
            _UNIT, :in, 1, "source-1", owner, auth1),
        G.G3SFFeedbackTargetV1("g2-target", :G2, "/g2/thermal", :thermal_load,
            _UNIT, :in, 1, "source-1", owner, auth2)) : targets_override
    split = G.G3SFConservativeSplitV1(1//2, 1//4, 1//4)
    heat = G.G3SFHeatRelationV1(:source, :heat, 1//4)
    ledger_relation = G.G3SFLedgerRelationV1((:source, :field, :return, :heat), 0)
    law = G.G3SFLawV1("law-1", "source-1", "field-1", "return-1", "heat-1",
        1//2, 1//4, split, heat, ledger_relation, owner)
    closure = G.G3SFLedgerClosureV1("closure-1", ("ledger-1",), 0, _UNIT, owner)
    G.g3_sf_declaration_v1(candidate, "source-1", owner, (), law, (),
        closure, targets, upstream)
end

function _fake_decl(;candidate=_CANDIDATE, upstream, targets)
    FakeDeclaration(candidate, targets, upstream)
end
struct FakeAuthority
    layer::Symbol
    candidate_ref::G.QualifiedRefV1
    contract_ref
    contract_hash
    status::Symbol
    attestation::Symbol
end
struct FakeTarget
    target_id::String
    target_layer::Symbol
    target_path::String
    quantity::Symbol
    unit::Symbol
    direction::Symbol
    sign::Int
    source_id::String
    owner_scope::String
    authority::FakeAuthority
end
struct FakeDeclaration
    candidate_ref::G.QualifiedRefV1
    feedback_targets::Tuple
    upstream_authority::Tuple
end
const FakeDecl = FakeDeclaration

function _fake_authority(layer, status=:missing; candidate=_CANDIDATE,
        contract=nothing, hash=nothing, attestation=:unattested)
    FakeAuthority(layer, candidate, contract, hash, status, attestation)
end
function _fake_target(id, layer, auth; path="/path", quantity=:residual,
        source="source-1")
    FakeTarget(id, layer, path, quantity, :unit, :in, 1, source, "owner", auth)
end
function _input(declaration; bytes=UInt8[0x74, 0x30, 0x2d, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65], fresh=nothing)
    bundle = G.VNextT0BundleSourceV1(bytes)
    G.VNextAuthorityRecheckInputV1(_CANDIDATE, bundle, declaration, fresh)
end
function _codes(result)
    Tuple(result.errors)
end

@testset "AD-34 T0 authority recheck typed-absent scaffold" begin
    declaration = _g3_declaration()
    input = _input(declaration)
    result = G.vnext_declaration_authority_recheck_v1(input)
    @test result.status === :typed_absent
    @test result.resolution === :terminal_deferred
    @test result.accepted === false
    @test result.claim_ceiling === :contract_only
    @test result.output isa G.VNextTypedAbsentAuthorityV1
    @test result.output.layers[1].reason === :legacy_missing_authority
    @test result.output.layers[2].reason === :legacy_missing_authority
    @test result.output.layers[1].resolution === :terminal_deferred
    @test result.output_hash isa G.Digest256
    @test result.prior_bundle_sha256 == input.t0_bundle.canonical_sha256
    @test result.prior_bundle_bytes == input.t0_bundle.canonical_bytes
    @test G.VNEXT_AR_REQUIRED_LAYERS == (:G1, :G2)
end

@testset "AD-34 frozen legacy status mapping" begin
    for (status, reason) in ((:actual, :legacy_actual_without_declaration_authority),
            (:missing, :legacy_missing_authority),
            (:historical_absent, :legacy_historical_absent_authority))
        result = G.vnext_declaration_authority_recheck_v1(
            _input(_g3_declaration(g1_status=status)))
        @test result.status === :typed_absent
        @test result.output.layers[1].reason === reason
        @test result.output.layers[1].resolution === :terminal_deferred
    end
    for status in (:stale, :contradictory)
        result = G.vnext_declaration_authority_recheck_v1(
            _input(_g3_declaration(g1_status=status)))
        @test result.status === :fail_closed
        @test result.output === nothing
        @test result.prior_bundle_bytes == _input(_g3_declaration()).t0_bundle.canonical_bytes
    end
end

@testset "AD-34 exact G1/G2 pairing and target key negatives" begin
    g1 = _fake_authority(:G1)
    g2 = _fake_authority(:G2)
    g3 = _fake_authority(:G3)
    cases = [
        (_fake_decl(upstream=(g1, g1, g2), targets=()), :duplicate_upstream_authority_layer),
        (_fake_decl(upstream=(g1,), targets=()), :missing_upstream_authority_layer),
        (_fake_decl(upstream=(g1, g2, g3), targets=()), :unknown_upstream_authority_layer),
        (_fake_decl(upstream=(g1, g2), targets=(_fake_target("bad", :G3, g3),)), :unknown_target_layer),
        (_fake_decl(upstream=(g1, g2), targets=(_fake_target("bad", :G1, g2),)), :legacy_target_authority_layer_or_candidate_mismatch)
    ]
    for (declaration, code) in cases
        result = G.vnext_declaration_authority_recheck_v1(_input(declaration))
        @test result.status === :fail_closed
        @test code in _codes(result)
    end
    mismatch = _fake_authority(:G1; hash=G.digest256_text("different"))
    result = G.vnext_declaration_authority_recheck_v1(_input(
        _fake_decl(upstream=(g1, g2), targets=(_fake_target("m", :G1, mismatch),))))
    @test result.status === :fail_closed
    @test :legacy_target_upstream_projection_mismatch in _codes(result)

    t1 = _fake_target("t1", :G1, g1; path="/same")
    t2 = _fake_target("t2", :G1, g1; path="/same")
    result = G.vnext_declaration_authority_recheck_v1(_input(
        _fake_decl(upstream=(g1, g2), targets=(t1, t2))))
    @test :duplicate_or_ambiguous_feedback_target in _codes(result)
    t2id = _fake_target("t1", :G1, g1; path="/different")
    result = G.vnext_declaration_authority_recheck_v1(_input(
        _fake_decl(upstream=(g1, g2), targets=(t1, t2id))))
    @test :duplicate_feedback_target_id in _codes(result)
end

@testset "AD-34 candidate and authority provenance negatives" begin
    foreign_candidate = G.QualifiedRefV1("fusionconceptai://candidate/foreign-declaration", "v5")
    foreign_declaration = _g3_declaration(candidate=foreign_candidate)
    foreign_result = G.vnext_declaration_authority_recheck_v1(_input(foreign_declaration))
    @test foreign_result.status === :fail_closed
    @test :declaration_candidate_mismatch in _codes(foreign_result)
    @test foreign_result.output === nothing
    @test foreign_result.prior_bundle_bytes == _input(_g3_declaration()).t0_bundle.canonical_bytes
    @test foreign_result.prior_bundle_sha256 == _input(_g3_declaration()).t0_bundle.canonical_sha256

    foreign = G.QualifiedRefV1("fusionconceptai://candidate/foreign", "v5")
    foreign_auth = _authority(:G1, :missing; candidate=foreign)
    target = G.G3SFFeedbackTargetV1("foreign", :G1, "/g1/residual", :residual,
        _UNIT, :in, 1, "source-1", String(_FIXTURE.owner_scope), foreign_auth)
    result = G.vnext_declaration_authority_recheck_v1(_input(_g3_declaration(
        g1_target_authority=target.authority)))
    @test :legacy_target_authority_layer_or_candidate_mismatch in _codes(result)

    for origin in (:synthetic, :ref_only, :fixture)
        record = G.VNextT0OwnedAuthorityRecordV1(:G1, _CANDIDATE, nothing, nothing,
            nothing, nothing, :actual, :trusted_receipt, origin)
        result = G.vnext_declaration_authority_recheck_v1(_input(_g3_declaration(); fresh=record))
        @test result.status === :fail_closed
        @test Symbol(string(origin, "_authority_rejected")) in _codes(result)
        @test result.output === nothing
    end
    missing = G.VNextT0OwnedAuthorityRecordV1(:G1, _CANDIDATE, nothing, nothing,
        nothing, nothing, :actual, :trusted_receipt, :fresh_t0_owned)
    result = G.vnext_declaration_authority_recheck_v1(_input(_g3_declaration(); fresh=missing))
    @test :fresh_authority_missing_field in _codes(result)
    @test !(result.output isa G.VNextCheckedPresentAuthorityV1)
end

@testset "AD-34 source bytes and failure byte stability" begin
    bytes = UInt8[0x01, 0x02, 0x03]
    bundle = G.VNextT0BundleSourceV1(bytes)
    before = Tuple(bundle.canonical_bytes)
    @test bundle.canonical_bytes == before
    @test_throws Exception (bundle.canonical_bytes[1] = 0x09)
    @test_throws ArgumentError G.VNextT0BundleSourceV1(bytes, G.digest256_text("tampered"))
    input = _input(_g3_declaration(); bytes=bytes)
    result = G.vnext_declaration_authority_recheck_v1(input)
    @test result.prior_bundle_bytes == before
    @test result.prior_bundle_sha256 == bundle.canonical_sha256
    @test result.output_hash isa G.Digest256
end

@testset "AD-34 present output type is sealed behind fresh T0 authority" begin
    @test :declaration_ref in fieldnames(G.VNextCheckedPresentAuthorityV1)
    @test :canonical_bytes_hash in fieldnames(G.VNextCheckedPresentAuthorityV1)
    @test :source_receipt_ref in fieldnames(G.VNextCheckedPresentAuthorityV1)
    @test :actual_binding_authority in (:actual_binding_authority,)
end

println("AD34_T0_AUTHORITY_RECHECK_STATUS=typed_absent_or_fail_closed")
println("AD34_T0_AUTHORITY_RECHECK_PRESENT=false")
println("AD34_T0_AUTHORITY_RECHECK_ACTUAL_CREDIT=false")
