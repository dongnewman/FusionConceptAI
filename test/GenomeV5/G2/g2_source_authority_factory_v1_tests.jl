using Test
using SHA
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))

const _ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _TEMP_FIXTURES = String[]
const _AXES = G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema", "v5"),
    G.QualifiedRefV1("fusion.g2.canonicalization", "v5"), G.QualifiedRefV1("fusion.g2.applicability", "v5"),
    G.QualifiedRefV1("fusion.g2.receipt", "v5"))
const _HANDLE = G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
const _R(n, d=1) = Int64(n) // Int64(d)

function _source()
    chart_ref = G.QualifiedRefV1("fusion.g2.chart", "v1")
    mesh_ref = G.QualifiedRefV1("fusion.g2.mesh", "v1")
    chart = G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1), ((2, 0, 0), (0, 3, 0), (0, 0, 4)), (_R(1,2), _R(1,3), _R(1,4)))
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2, 3, 4), :Q1, ((_R(1,2), _R(1,2), _R(1,2)), (_R(1,4), _R(1,4), _R(1,4))), (1, _R(1,2)); execution_status=:not_executed)
    fu = G.UnitSignature((0, 0, 0, 0, 0, 0, 1)); xu = G.UnitSignature((1, 0, 0, 0, 0, 0, 0)); mu = G.UnitSignature((2, 0, 0, 0, 0, 0, 0)); vu = G.UnitSignature((3, 0, 0, 0, 0, 0, 0)); zu = G.UnitSignature((0, 0, 0, 0, 0, 0, 0)); fl = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))
    faces = (G.G2MBFaceOwnerV1("x0", :x_min, "domain", (-1,0,0), G.G2MBFaceValueV1(:dirichlet, 0, fu)), G.G2MBFaceOwnerV1("x1", :x_max, "domain", (1,0,0), G.G2MBFaceValueV1(:neumann, 1, fl)), G.G2MBFaceOwnerV1("y0", :y_min, "domain", (0,-1,0), G.G2MBFaceValueV1(:dirichlet, 0, fu)), G.G2MBFaceOwnerV1("y1", :y_max, "domain", (0,1,0), G.G2MBFaceValueV1(:neumann, 1, fl)), G.G2MBFaceOwnerV1("z0", :z_min, "domain", (0,0,-1), G.G2MBFaceValueV1(:dirichlet, 0, fu)), G.G2MBFaceOwnerV1("z1", :z_max, "domain", (0,0,1), G.G2MBFaceValueV1(:neumann, 1, fl)))
    profile = G.G2MBProfileV1("fusion.g2.metric-boundary.profile")
    units = G.G2MBUnitContractV1(zu, xu, xu, mu, mu, vu, fu, fl)
    contract = G._g2sf_expected_contract()
    G.g2mb_source_v1(G.QualifiedRefV1("fusionconceptai://source/ad49-g2-fixture", "v1"), "ad49-g2-source-v1", contract, chart, mesh, faces, profile, units, G.G2MBAuthorityV1(:unique_match, :no_match, :no_match)), contract
end

function _tracked_fixture(source_path; autocrlf=false)
    root = mktempdir(); push!(_TEMP_FIXTURES, root); dst = joinpath(root, split(source_path, '/')...); mkpath(dirname(dst)); cp(joinpath(_ROOT, split(source_path, '/')...), dst)
    envsrc = joinpath(_ROOT, split(G.G2_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...); envdst = joinpath(root, split(G.G2_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...); mkpath(dirname(envdst)); cp(envsrc, envdst)
    for args in (("init",), ("config", "user.email", "ad49@example.invalid"), ("config", "user.name", "AD49 test"), ("config", "core.autocrlf", autocrlf ? "true" : "false"), ("add", source_path, G.G2_AD45_ENVELOPE_RELATIVE_PATH_V1), ("commit", "-m", "synthetic test fixture"))
        run(Cmd(String["git", "-C", root, args...]))
    end
    if autocrlf
        rm(dst; force=true)
        run(Cmd(["git", "-C", root, "checkout", "--", source_path]))
    end
    head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"])); blob = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD:" * source_path])); bytes = read(Cmd(["git", "-C", root, "show", "HEAD:" * source_path]))
    G.G2IndependentSourceLocatorV1(root, head, source_path, length(bytes), G.Digest256(bytes2hex(SHA.sha256(bytes))), :present, :present, :clean, G.Digest256(bytes2hex(SHA.sha256(bytes))), :isolated_test_fixture)
end
function _current_locator()
    p=G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; head=readchomp(Cmd(["git", "-C", _ROOT, "rev-parse", "HEAD"])); bytes=read(Cmd(["git", "-C", _ROOT, "show", "HEAD:" * p])); digest=G.Digest256(bytes2hex(SHA.sha256(bytes))); G.G2IndependentSourceLocatorV1(_ROOT, head, p, length(bytes), digest, :present, :present, :clean, digest, :repository_head)
end

@testset "AD49-F0 G2 source authority factory V1" begin
    payload, contract = _source(); ctor = G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)
    @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(_current_locator(), _HANDLE, contract, payload, _AXES, ctor)) == :present
    fixture = _tracked_fixture(G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
    result = G.g2_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor)
    @test result isa G.G2SourceFactoryConstructionResultV1
    @test G.g2_source_factory_result_status(result) == :present
    @test result.identity isa G.PresentG2SourceFactoryIdentityV1
    @test result.source_declaration isa G.PresentG2SourceDeclarationV1
    @test result.receipt isa G.PresentG2SourceConstructionReceiptV1
    @test result.source_declaration.public_contract_ref == contract
    @test result.source_declaration.binding.common_binding_handle == _HANDLE
    @test result.source_declaration.binding.common_binding_envelope_sha256 == G.G2_AD45_ENVELOPE_SHA256_V1
    @test result.source_declaration.binding.binding_role == :temporary_common_candidate_binding_handle_only
    @test result.source_declaration.binding.binding_hash isa G.Digest256
    @test result.source_declaration.synthetic_test_only
    @test result.source_declaration.declaration.contract_ref == contract
    @test result.source_declaration.declaration.source.candidate_ref isa G.GenomeContractRef
    @test result.source_declaration.source_content_hash isa G.Digest256
    @test result.source_declaration.local_declaration_hash == G.g2mb_declaration_hash_v1(result.source_declaration.declaration)
    @test result.source_declaration.declaration_hash == G.canonical_hash(G.semantic_view(result.source_declaration))
    @test !result.receipt.trusted && !result.receipt.candidate_identity_created && !result.receipt.final_hash_created
    @test result.receipt.replayable
    @test G.canonical_hash(result) == G.canonical_hash(G.g2_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor))
    @testset "core.autocrlf=true canonical HEAD locator" begin
        filtered = _tracked_fixture(G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; autocrlf=true)
        filtered_path = joinpath(filtered.repository_root, split(filtered.source_path, '/')...)
        canonical = read(Cmd(["git", "-C", filtered.repository_root, "show", "HEAD:" * filtered.source_path]))
        @test read(filtered_path) != canonical
        @test readchomp(Cmd(["git", "-C", filtered.repository_root, "hash-object", "--path", filtered.source_path, filtered_path])) ==
            readchomp(Cmd(["git", "-C", filtered.repository_root, "rev-parse", "HEAD:" * filtered.source_path]))
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(filtered, _HANDLE, contract, payload, _AXES, ctor)) == :present
        original = read(filtered_path)
        open(filtered_path, "w") do io; write(io, [original; UInt8('#')]); end
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(filtered, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        open(filtered_path, "w") do io; write(io, original); end
    end
    @testset "typed absence and fail closed" begin
        b = G.g2_source_authority_factory_v1(nothing, _HANDLE, contract, payload, _AXES, ctor)
        @test G.g2_source_factory_result_status(b) == :typed_absent
        @test b.receipt isa G.AbsentG2SourceConstructionReceiptV1
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(fixture, G.QualifiedRefV1("foreign", "v5"), contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(fixture, _HANDLE, G.GenomeContractRef("foreign", "v5", contract.schema_hash, contract.canonicalization_hash, contract.compatibility_profile), payload, _AXES, ctor)) == :fail_closed
        bad = G.G2IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, G.digest256_text("changed"), fixture.head_path_status, fixture.working_tree_path_status, fixture.working_tree_status, fixture.head_blob_sha256)
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(bad, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, G.G2SourceDeclarationConstructorV1(x -> nothing))) == :fail_closed
        relabel = G.G2IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, fixture.source_sha256, :present, :present, :clean, fixture.head_blob_sha256, :repository_head)
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(relabel, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        @test G._g2sf_repository_anchor(joinpath(fixture.repository_root, "missing-module-dir")) === nothing
        source_file = joinpath(fixture.repository_root, split(fixture.source_path, '/')...); original = read(source_file)
        open(source_file, "w") do io; write(io, [original; UInt8('#')]); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--assume-unchanged", fixture.source_path]))
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        open(source_file, "w") do io; write(io, original); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--no-assume-unchanged", fixture.source_path]))
        open(source_file, "w") do io; write(io, [original; UInt8('%')]); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--skip-worktree", fixture.source_path]))
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(fixture, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        open(source_file, "w") do io; write(io, original); end
        run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--no-skip-worktree", fixture.source_path]))
        bad_blob = G.G2IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, fixture.source_sha256, fixture.head_path_status, fixture.working_tree_path_status, fixture.working_tree_status, G.digest256_text("head-blob-mismatch"), fixture.provenance)
        @test G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(bad_blob, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
    end
end

println("AD49_F0_G2_FACTORY_TESTS_DEFINED=true")
println("AD49_F0_G2_FACTORY_SYNTHETIC_FIXTURE_ONLY=true")
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
