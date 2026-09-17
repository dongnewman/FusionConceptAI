using Test
using SHA
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3",
    "G3SourceAuthorityFactoryV1.jl"))

const _REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _FIXTURE_ROOT = mktempdir()
const _FILTERED_FIXTURE_ROOT = mktempdir()

function _fixture_git(args...)
    run(Cmd(["git", "-C", _FIXTURE_ROOT, String.(args)...]))
end

function _prepare_fixture(root=_FIXTURE_ROOT; autocrlf=false)
    fixture_git(args...) = run(Cmd(["git", "-C", root, String.(args)...]))
    fixture_git("init", "-q")
    fixture_git("config", "user.email", "ad52@example.invalid")
    fixture_git("config", "user.name", "AD52 fixture")
    fixture_git("config", "core.autocrlf", autocrlf ? "true" : "false")
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        path = Dict(
            :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
            :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
            :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
            :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
        )[scope]
        target = joinpath(root, split(path, '/')...)
        mkpath(dirname(target))
        write(target, read(joinpath(_REPO_ROOT, split(path, '/')...)))
    end
    envelope = joinpath(root, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
    mkpath(dirname(envelope))
    write(envelope, read(joinpath(_REPO_ROOT, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)))
    fixture_git("add", "--all")
    fixture_git("commit", "-q", "-m", "AD52 tracked source fixture")
    if autocrlf
        for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
            path = Dict(
                :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
                :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
                :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
                :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl")[scope]
            rm(joinpath(root, split(path, '/')...); force=true)
        end
        fixture_git("checkout", "--", ".")
    end
    nothing
end

_prepare_fixture()
_prepare_fixture(_FILTERED_FIXTURE_ROOT; autocrlf=true)

const _FACTORY_HANDLE = G.QualifiedRefV1(
    G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1)
_factory_declaration_ref(scope) =
    G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad48-f0", "v1")

function _factory_locator(scope; root=_FIXTURE_ROOT)
    paths = Dict(
        :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
        :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
        :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
        :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
    )
    path = paths[scope]
    bytes = read(Cmd(["git", "-C", root, "show", "HEAD:" * path]))
    head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"]))
    digest = G.Digest256(bytes2hex(SHA.sha256(bytes)))
    G.G3IndependentSourceLocatorV1(scope, root, head, path, length(bytes),
        digest, :present, :present, :clean, digest)
end

function _current_repo_locator(scope)
    paths = Dict(
        :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
        :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
        :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
        :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
    )
    path = paths[scope]
    bytes = read(Cmd(["git", "-C", _REPO_ROOT, "show", "HEAD:" * path]))
    head = readchomp(Cmd(["git", "-C", _REPO_ROOT, "rev-parse", "HEAD"]))
    digest = G.Digest256(bytes2hex(SHA.sha256(bytes)))
    G.G3IndependentSourceLocatorV1(scope, _REPO_ROOT, head, path, length(bytes), digest,
        :present, :present, :clean, digest)
end

function _factory_result(scope; locator=_factory_locator(scope), handle=_FACTORY_HANDLE,
        contract=G.g3_contract_ref(scope), axes=G.g3_version_axes(scope),
        declaration_ref=_factory_declaration_ref(scope))
    G.g3_source_authority_factory_v1(scope, locator, handle, contract, axes, declaration_ref)
end

@testset "AD48-F0 G3 source-authority factory V1" begin
    before_registry = G.canonical_hash(G.default_operator_registry())

    @testset "four scope construction" begin
        envelope_path = joinpath(_FIXTURE_ROOT, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
        @test isfile(envelope_path)
        @test G.Digest256(bytes2hex(SHA.sha256(read(envelope_path)))) ==
            G.G3_AD45_ENVELOPE_SHA256_V1
        for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
            result = _factory_result(scope)
            @test result isa G.G3FactoryConstructionResultV1
            @test G.g3_factory_result_status(result) == :present
            @test result.identity isa G.PresentG3FactoryIdentityV1
            @test result.receipt isa G.PresentG3FactoryConstructionReceiptV1
            @test result.identity.scope == scope
            @test result.identity.registry_not_used
            @test !result.identity.candidate_identity_created
            @test result.identity.g3_source_declaration_hash_created
            @test !result.identity.final_candidate_or_package_declaration_hash_created
            @test result.binding isa G.G3SourceContractBindingV1
            @test result.binding.common_binding_handle == _FACTORY_HANDLE
            @test result.binding.binding_role == :temporary_common_candidate_binding_handle_only
            @test !result.binding.candidate_identity_created
            @test result.binding.binding_digest == result.receipt.constructed_binding_hash
            @test result.source_declaration isa G.G3CandidateBoundSourceDeclarationV1
            @test result.source_declaration.source_declaration_hash == result.receipt.source_declaration_hash
            @test result.source_declaration.content.source_sha256 == result.identity.source_sha256
            @test result.source_declaration.content.locator_digest == result.receipt.locator_digest
            @test result.source_declaration.content.common_binding_handle == _FACTORY_HANDLE
            @test result.source_declaration.content.common_binding_envelope_path ==
                G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1
            @test result.source_declaration.content.common_binding_envelope_sha256 ==
                G.G3_AD45_ENVELOPE_SHA256_V1
            @test result.source_declaration.declaration_ref == _factory_declaration_ref(scope)
            @test !result.receipt.trusted_attestation_created
            @test result.receipt.g3_source_declaration_hash_created
            @test !result.receipt.final_candidate_or_package_declaration_hash_created
            @test !result.receipt.candidate_identity_created
            @test result.receipt.constructed_binding_hash isa G.Digest256
            @test result.receipt.source_sha256 == result.identity.source_sha256
        end
    end

    @testset "core.autocrlf=true canonical HEAD locator" begin
        locator = _factory_locator(:realization; root=_FILTERED_FIXTURE_ROOT)
        source_file = joinpath(locator.repository_root, split(locator.source_path, '/')...)
        canonical = read(Cmd(["git", "-C", locator.repository_root, "show", "HEAD:" * locator.source_path]))
        head_blob = readchomp(Cmd(["git", "-C", locator.repository_root, "rev-parse", "HEAD:" * locator.source_path]))
        @test read(source_file) != canonical
        @test readchomp(Cmd(["git", "-C", locator.repository_root, "hash-object", "--path", locator.source_path, source_file])) == head_blob
        @test G.g3_factory_result_status(_factory_result(:realization; locator=locator)) == :present
        original = read(source_file)
        open(source_file, "w") do io; write(io, [original; UInt8('#')]); end
        @test G.g3_factory_result_status(_factory_result(:realization; locator=locator)) == :fail_closed
        open(source_file, "w") do io; write(io, original); end
    end

    @testset "missing inputs are typed absence" begin
        for scope in (:realization, :control, :binding, :bundle)
            for args in ((nothing, _FACTORY_HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                         (_factory_locator(scope), nothing, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                         (_factory_locator(scope), _FACTORY_HANDLE, nothing, G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                         (_factory_locator(scope), _FACTORY_HANDLE, G.g3_contract_ref(scope), nothing, _factory_declaration_ref(scope)),
                         (_factory_locator(scope), _FACTORY_HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), nothing))
                result = G.g3_source_authority_factory_v1(scope, args...)
                @test G.g3_factory_result_status(result) == :typed_absent
                @test result.identity isa G.AbsentG3FactoryIdentityV1
                @test result.receipt isa G.AbsentG3FactoryConstructionReceiptV1
                @test result.receipt.terminal_deferred
                @test !result.receipt.candidate_identity_created
            end
        end
    end

    @testset "mismatches fail closed" begin
        scope = :realization
        locator = _factory_locator(scope)
        wrong_scope = _factory_locator(:control)
        wrong_contract = G.g3_contract_ref(:control)
        wrong_axes = G.g3_version_axes(:control)
        old_synthetic_handle = G.QualifiedRefV1("fusionconceptai://candidate/ad48-f0-handle", "v5")
        foreign_handle = G.QualifiedRefV1("foreign://handle", "v5")
        wrong_version_handle = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v1")
        other_ad45_allocation = G.QualifiedRefV1(
            "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/00000000-0000-0000-0000-000000000000", "v5")
        aliased_ad45_handle = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1 * "/alias", "v5")
        cases = ((wrong_scope, _FACTORY_HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, old_synthetic_handle, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, foreign_handle, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, wrong_version_handle, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, other_ad45_allocation, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, aliased_ad45_handle, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, _FACTORY_HANDLE, wrong_contract, G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                 (locator, _FACTORY_HANDLE, G.g3_contract_ref(scope), wrong_axes, _factory_declaration_ref(scope)),
                 (locator, _FACTORY_HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), G.QualifiedRefV1("foreign://decl", "v1")))
        for args in cases
            result = G.g3_source_authority_factory_v1(scope, args...)
            @test G.g3_factory_result_status(result) == :fail_closed
            @test result.identity isa G.FailedG3FactoryIdentityV1
            @test result.receipt isa G.FailedG3FactoryConstructionReceiptV1
            @test result.receipt.fail_closed
            @test !result.receipt.candidate_identity_created
        end
        bad_hash = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            G.digest256_text("changed-source"), locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status, locator.head_blob_sha256)
        result = _factory_result(scope; locator=bad_hash)
        @test result.identity.reason == :head_blob_sha256_mismatch
        @test result.receipt.reason == :head_blob_sha256_mismatch
        @test G.g3_factory_result_status(result) == :fail_closed
    end

    @testset "final G3 constructor remains distinct" begin
        @test_throws ArgumentError G.G3ContractBindingV2(
            G.g3_contract_ref(:realization), _FACTORY_HANDLE, G.g3_version_axes(:realization))
    end

    @testset "determinism, registry and fail-atomic behavior" begin
        a = _factory_result(:bundle)
        b = _factory_result(:bundle)
        @test a.receipt.construction_digest == b.receipt.construction_digest
        @test a.receipt.semantic_digest == b.receipt.semantic_digest
        @test a.receipt.constructed_binding_hash == b.receipt.constructed_binding_hash
        @test G.canonical_hash(a.binding) == a.binding.binding_digest
        @test G.canonical_hash(a) == G.canonical_hash(b)
        @test G.canonical_hash(G.default_operator_registry()) == before_registry
        failed = G.g3_source_authority_factory_v1(:bundle, _factory_locator(:bundle),
            _FACTORY_HANDLE, G.g3_contract_ref(:realization), G.g3_version_axes(:bundle),
            _factory_declaration_ref(:bundle))
        @test failed.receipt isa G.FailedG3FactoryConstructionReceiptV1
        @test G.canonical_hash(G.default_operator_registry()) == before_registry
    end

    @testset "declaration replay, separation and wrappers" begin
        for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
            first = _factory_result(scope)
            second = _factory_result(scope)
            @test first.source_declaration.source_declaration_hash ==
                second.source_declaration.source_declaration_hash
            @test first.source_declaration.content.source_content_digest ==
                second.source_declaration.content.source_content_digest
            @test G.canonical_hash(first.source_declaration) ==
                first.source_declaration.source_declaration_hash
            @test G.canonical_hash(first.source_declaration.content) ==
                first.source_declaration.content.source_content_digest
            @test first.receipt.source_declaration_hash ==
                first.source_declaration.source_declaration_hash
            @test first.receipt.output_source_declaration == first.source_declaration
            @test !(first.receipt isa G.G3CandidateBoundSourceDeclarationV1)
            @test first.receipt.trusted_attestation_created == false
        end
        wrappers = (
            G.g3_realization_source_authority_factory_v1,
            G.g3_control_source_authority_factory_v1,
            G.g3_binding_source_authority_factory_v1,
            G.g3_bundle_source_authority_factory_v1)
        for (scope, wrapper) in zip(G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1, wrappers)
            result = wrapper(_factory_locator(scope), _FACTORY_HANDLE,
                G.g3_contract_ref(scope), G.g3_version_axes(scope),
                _factory_declaration_ref(scope))
            @test G.g3_factory_result_status(result) == :present
            @test result.identity.scope == scope
        end
        changed_ref = G.QualifiedRefV1(
            "fusionconceptai://GenomeV5/G3/realization/source-declaration/changed", "v1")
        changed = _factory_result(:realization; declaration_ref=changed_ref)
        @test changed.source_declaration.source_declaration_hash !=
            _factory_result(:realization).source_declaration.source_declaration_hash
        @test changed.source_declaration.content.source_content_digest ==
            _factory_result(:realization).source_declaration.content.source_content_digest
    end

    @testset "source change and path invalidation" begin
        locator = _factory_locator(:control)
        bad_path = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, "src/GenomeV5/G3/RealizationGenomeV5.jl", locator.source_bytes,
            locator.source_sha256, locator.head_path_status, locator.working_tree_path_status,
            locator.working_tree_status, locator.head_blob_sha256)
        result = _factory_result(:control; locator=bad_path)
        @test result.identity.reason == :source_path_mismatch
        @test result.receipt.reason == :source_path_mismatch
        missing = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status, locator.working_tree_path_status,
            :missing, locator.head_blob_sha256)
        result = _factory_result(:control; locator=missing)
        @test result.identity.reason == :working_tree_status_mismatch

        stale_head = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            "000000000000000000000000000000000000000000", locator.source_path,
            locator.source_bytes, locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status,
            locator.head_blob_sha256)
        @test _factory_result(:control; locator=stale_head).identity.reason == :locator_head_mismatch
        bad_head_path = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, :absent_untracked, locator.working_tree_path_status,
            locator.working_tree_status, locator.head_blob_sha256)
        @test _factory_result(:control; locator=bad_head_path).identity.reason == :head_path_status_mismatch
        bad_work_path = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status, :absent_untracked,
            locator.working_tree_status, locator.head_blob_sha256)
        @test _factory_result(:control; locator=bad_work_path).identity.reason == :working_tree_path_status_mismatch
        bad_work_status = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status, locator.working_tree_path_status,
            :dirty, locator.head_blob_sha256)
        @test _factory_result(:control; locator=bad_work_status).identity.reason == :working_tree_status_mismatch
    end

    @testset "current working-tree snapshots remain typed absence" begin
        for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
            result = _factory_result(scope; locator=_current_repo_locator(scope))
            @test G.g3_factory_result_status(result) == :present
            @test result.identity isa G.PresentG3FactoryIdentityV1
            @test result.receipt isa G.PresentG3FactoryConstructionReceiptV1
            @test result.receipt.candidate_identity_created == false
            @test result.receipt.g3_source_declaration_hash_created
        end
    end

    @testset "repository and Git object closure" begin
        scope = :realization
        locator = _factory_locator(scope)
        nested = joinpath(_FIXTURE_ROOT, "nested")
        nested_source = joinpath(nested, split(locator.source_path, '/')...)
        mkpath(dirname(nested_source))
        write(nested_source, read(joinpath(_FIXTURE_ROOT, split(locator.source_path, '/')...)))
        nested_envelope = joinpath(nested, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
        mkpath(dirname(nested_envelope))
        write(nested_envelope, read(joinpath(_FIXTURE_ROOT,
            split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)))
        wrong_root = G.G3IndependentSourceLocatorV1(scope, nested, locator.observed_head,
            locator.source_path, locator.source_bytes, locator.source_sha256,
            locator.head_path_status, locator.working_tree_path_status,
            locator.working_tree_status, locator.head_blob_sha256)
        @test G.g3_factory_result_status(_factory_result(scope; locator=wrong_root)) == :fail_closed
        @test _factory_result(scope; locator=wrong_root).identity.reason == :repository_root_mismatch

        stale_head = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            repeat("0", 40), locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status,
            locator.head_blob_sha256)
        @test _factory_result(scope; locator=stale_head).identity.reason == :locator_head_mismatch

        bad_blob = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status,
            G.digest256_text("wrong-head-blob"))
        @test _factory_result(scope; locator=bad_blob).identity.reason == :head_blob_sha256_mismatch

        bad_head_path = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, :absent_untracked,
            locator.working_tree_path_status, locator.working_tree_status,
            locator.head_blob_sha256)
        @test _factory_result(scope; locator=bad_head_path).identity.reason == :head_path_status_mismatch

        bad_work_path = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status,
            :absent_untracked, locator.working_tree_status,
            locator.head_blob_sha256)
        @test _factory_result(scope; locator=bad_work_path).identity.reason == :working_tree_path_status_mismatch

        bad_work_status = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, :dirty, locator.head_blob_sha256)
        @test _factory_result(scope; locator=bad_work_status).identity.reason == :working_tree_status_mismatch
    end

    @testset "index trust flags fail closed" begin
        scope = :control
        locator = _factory_locator(scope)
        path = locator.source_path
        _fixture_git("update-index", "--assume-unchanged", "--", path)
        assumed = _factory_result(scope; locator=locator)
        @test G.g3_factory_result_status(assumed) == :fail_closed
        @test assumed.identity.reason == :index_assume_unchanged
        _fixture_git("update-index", "--no-assume-unchanged", "--", path)
        _fixture_git("update-index", "--skip-worktree", "--", path)
        skipped = _factory_result(scope; locator=locator)
        @test G.g3_factory_result_status(skipped) == :fail_closed
        @test skipped.identity.reason == :index_skip_worktree
        _fixture_git("update-index", "--no-skip-worktree", "--", path)
        @test G.g3_factory_result_status(_factory_result(scope; locator=locator)) == :present
    end
end

function _cleanup_temp(path)
    for attempt in 1:5
        try
            rm(path; recursive=true, force=true)
            return true
        catch
            attempt == 5 || sleep(0.1)
        end
    end
    false
end
_cleanup_temp(_FIXTURE_ROOT)
_cleanup_temp(_FILTERED_FIXTURE_ROOT)
