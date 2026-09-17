using Test
using SHA
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))

const _ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _TEMP_FIXTURES = String[]
const _U = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
const _GU = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
const _FU = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
const _SC = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), _U)
const _GR = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), _GU)
const _TK = G.PhysicalType(:tensor_field, 2, 3, G.TemporalTypeV1(G.static_time), _U)
const _FF = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), _FU)
const _AXES = G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
    G.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
    G.QualifiedRefV1("fusion.g1.applicability", "v2"), G.QualifiedRefV1("fusion.g1.receipt", "v2"))
const _HANDLE = G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")

function _payload_and_constructor()
    source = G.QualifiedRefV1("fusionconceptai://source/ad49-g1-fixture", "v1")
    u = G.G1DiffusionScalarFieldV1("u", _SC, source; source_expression="u=x")
    ke = G.G1DiffusionDiagonalAffineKFieldV1("Kexpr"; base_diag=(2, 3, 4), slope_diag=(1//10, 1//20, 1//30))
    k = G.G1DiffusionCoefficientFieldV1("K", _TK, source; lower_bound=2, upper_bound=121//30, expression=ke)
    f = G.G1DiffusionScalarFieldV1("f", _FF, source; source_expression="f=1")
    grad = G.G1TypedGradV1(G.QualifiedRefV1("fusionconceptai://G1/GRAD", "v1"), "u", "grad_u", _SC, _GR)
    kap = G.G1TypedKApplyV1(G.QualifiedRefV1("fusionconceptai://G1/K_APPLY", "v1"), "grad_u", "flux_u", _GR, _GR, "K")
    div = G.G1TypedDivV1(G.QualifiedRefV1("fusionconceptai://G1/DIV", "v1"), "flux_u", "f", _GR, _FF)
    chain = G.G1DiffusionOperatorChainV1(grad, kap, div, "f")
    payload = G.G1DiffusionSourcePayloadV1(source, "ad49-g1-source-v1", u, k, f)
    ctor = G.G1SourceDeclarationConstructorV1(G.g1_diffusion_declaration_v1,
        G.QualifiedRefV1("fusionconceptai://source-stage-test/G1/declaration", "v5"), chain,
        G.QualifiedRefV1("fusionconceptai://G1/closure", "v1"),
        G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v1"),
        "bounded-test-domain", (:missing_authoritative_source,))
    payload, ctor
end

function _tracked_fixture(source_path; autocrlf=false)
    root = mktempdir(); push!(_TEMP_FIXTURES, root); dst = joinpath(root, split(source_path, '/')...); mkpath(dirname(dst)); cp(joinpath(_ROOT, split(source_path, '/')...), dst)
    envsrc = joinpath(_ROOT, split(G.G1_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...); envdst = joinpath(root, split(G.G1_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...); mkpath(dirname(envdst)); cp(envsrc, envdst)
    for args in (("init",), ("config", "user.email", "ad49@example.invalid"), ("config", "user.name", "AD49 test"), ("config", "core.autocrlf", autocrlf ? "true" : "false"), ("add", source_path, G.G1_AD45_ENVELOPE_RELATIVE_PATH_V1), ("commit", "-m", "synthetic test fixture"))
        run(Cmd(String["git", "-C", root, args...]))
    end
    if autocrlf
        rm(dst; force=true)
        run(Cmd(["git", "-C", root, "checkout", "--", source_path]))
    end
    head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"]))
    blob = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD:" * source_path]))
    bytes = read(Cmd(["git", "-C", root, "show", "HEAD:" * source_path]))
    G.G1IndependentSourceLocatorV1(root, head, source_path, length(bytes), G.Digest256(bytes2hex(SHA.sha256(bytes))), :present, :present, :clean, G.Digest256(bytes2hex(SHA.sha256(bytes))), :isolated_test_fixture)
end

function _current_locator()
    p = G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; bytes = read(joinpath(_ROOT, split(p, '/')...))
    head = readchomp(Cmd(["git", "-C", _ROOT, "rev-parse", "HEAD"]))
    digest = G.Digest256(bytes2hex(SHA.sha256(read(Cmd(["git", "-C", _ROOT, "show", "HEAD:" * p])))))
    G.G1IndependentSourceLocatorV1(_ROOT, head, p, length(read(Cmd(["git", "-C", _ROOT, "show", "HEAD:" * p]))), digest, :present, :present, :clean, digest, :repository_head)
end

@testset "AD49-F0 G1 source authority factory V1" begin
    payload, ctor = _payload_and_constructor(); contract = G._g1sf_expected_contract()
    @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(_current_locator(), _HANDLE, contract, payload, _AXES, ctor)) == :present
    fixture = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
    result = G.g1_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor)
    @test result isa G.G1SourceFactoryConstructionResultV1
    @test G.g1_source_factory_result_status(result) == :present
    @test result.identity isa G.PresentG1SourceFactoryIdentityV1
    @test result.source_declaration isa G.PresentG1SourceDeclarationV1
    @test result.receipt isa G.PresentG1SourceConstructionReceiptV1
    @test result.source_declaration.public_contract_ref == contract
    @test result.source_declaration.binding.common_binding_handle == _HANDLE
    @test result.source_declaration.binding.common_binding_envelope_sha256 == G.G1_AD45_ENVELOPE_SHA256_V1
    @test result.source_declaration.binding.binding_role == :temporary_common_candidate_binding_handle_only
    @test result.source_declaration.binding.binding_hash isa G.Digest256
    @test result.source_declaration.synthetic_test_only
    @test result.source_declaration.declaration.candidate_ref == ctor.candidate_ref
    @test result.source_declaration.declaration.source_payload == payload
    @test result.source_declaration.source_content_hash isa G.Digest256
    @test result.source_declaration.local_declaration_hash == G.g1_diffusion_declaration_hash_v1(result.source_declaration.declaration)
    @test result.source_declaration.declaration_hash == G.canonical_hash(G.semantic_view(result.source_declaration))
    @test result.receipt.trusted == false && result.receipt.candidate_identity_created == false && result.receipt.final_hash_created == false
    @test result.receipt.replayable && result.receipt.receipt_hash isa G.Digest256
    @test G.canonical_hash(result) == G.canonical_hash(G.g1_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor))
    @testset "core.autocrlf=true canonical HEAD locator" begin
        filtered = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; autocrlf=true)
        filtered_path = joinpath(filtered.repository_root, split(filtered.source_path, '/')...)
        canonical = read(Cmd(["git", "-C", filtered.repository_root, "show", "HEAD:" * filtered.source_path]))
        @test read(filtered_path) != canonical
        @test readchomp(Cmd(["git", "-C", filtered.repository_root, "hash-object", "--path", filtered.source_path, filtered_path])) ==
            readchomp(Cmd(["git", "-C", filtered.repository_root, "rev-parse", "HEAD:" * filtered.source_path]))
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(filtered, _HANDLE, contract, payload, _AXES, ctor)) == :present
        original = read(filtered_path)
        open(filtered_path, "w") do io; write(io, [original; UInt8('#')]); end
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(filtered, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        open(filtered_path, "w") do io; write(io, original); end
    end

    @testset "typed absence and fail closed" begin
        for value in (nothing,)
            x = G.g1_source_authority_factory_v1(value, _HANDLE, contract, payload, _AXES, ctor)
            @test G.g1_source_factory_result_status(x) == :typed_absent
            @test x.receipt isa G.AbsentG1SourceConstructionReceiptV1
        end
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(fixture, G.QualifiedRefV1("foreign", "v5"), contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(fixture, _HANDLE, G.GenomeContractRef("foreign", "v5", contract.schema_hash, contract.canonicalization_hash, contract.compatibility_profile), payload, _AXES, ctor)) == :fail_closed
        bad = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, G.digest256_text("changed"), fixture.head_path_status, fixture.working_tree_path_status, fixture.working_tree_status, fixture.head_blob_sha256)
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(bad, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, G.G1SourceDeclarationConstructorV1(x -> nothing, ctor.candidate_ref, ctor.operators, ctor.closure_ref, ctor.applicability_ref, ctor.applicability_domain, ctor.negative_controls))) == :fail_closed
        relabel = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, fixture.source_sha256, :present, :present, :clean, fixture.head_blob_sha256, :repository_head)
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(relabel, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        @test G._g1sf_repository_anchor(joinpath(fixture.repository_root, "missing-module-dir")) === nothing
        source_file = joinpath(fixture.repository_root, split(fixture.source_path, '/')...); original = read(source_file)
        open(source_file, "w") do io; write(io, [original; UInt8('#')]); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--assume-unchanged", fixture.source_path]))
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        open(source_file, "w") do io; write(io, original); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--no-assume-unchanged", fixture.source_path]))
        open(source_file, "w") do io; write(io, [original; UInt8('%')]); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--skip-worktree", fixture.source_path]))
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        open(source_file, "w") do io; write(io, original); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--no-skip-worktree", fixture.source_path]))
        bad_blob = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, fixture.source_sha256, fixture.head_path_status, fixture.working_tree_path_status, fixture.working_tree_status, G.digest256_text("head-blob-mismatch"), fixture.provenance)
        @test G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(bad_blob, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
    end
end

println("AD49_F0_G1_FACTORY_TESTS_DEFINED=true")
println("AD49_F0_G1_FACTORY_SYNTHETIC_FIXTURE_ONLY=true")
for root in _TEMP_FIXTURES
    for attempt in 1:5
        try
            rm(root; recursive=true, force=true)
            break
        catch
            attempt == 5 || sleep(0.1)
        end
    end
end
