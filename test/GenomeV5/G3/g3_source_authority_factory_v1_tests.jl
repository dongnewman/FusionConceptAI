using Test
using Base64
using SHA
using JSON3
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3",
    "G3SourceAuthorityFactoryV1.jl"))

const _REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
if !isdefined(Main, :T2FrozenSourceFixturePreparationV1)
    Base.include(Main, joinpath(_REPO_ROOT, "scripts", "prepare_t2_source_fixtures.jl"))
end
const _G3_T2_AUTH_CONTEXT = Main.T2FrozenSourceFixturePreparationV1.load_authorized_context_from_environment()
const _G3_T2_CONTEXTS = Dict{Tuple{String,String},Any}()
const _FIXTURE_ROOT = "frozen-clean"
const _FILTERED_FIXTURE_ROOT = "frozen-autocrlf"
const _CLEAN_FILTER_FIXTURE_ROOT = "frozen-filter"
const _G3_CLEAN_FILTER_DRIVER = "fca_t2_frozen_clean_r1"
const _G3_CLEAN_FILTER_MARKER_TEXT = "\n# FCA-T2-PREFREEZE-CLEAN-MARKER\n"
const _G3_CLEAN_FILTER_SOURCE = ""
const _FACTORY_HANDLE = G.QualifiedRefV1(
    G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1)
_g3_paths() = Dict(
    :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
    :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
    :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl")
_g3_case_id(scope, root=_FIXTURE_ROOT) = root == _FILTERED_FIXTURE_ROOT ?
    "g3_realization_autocrlf" : root == _CLEAN_FILTER_FIXTURE_ROOT ?
    "g3_realization_filter" : "g3_$(scope)_clean"
function _g3_frozen_fixture(scope, case_id)
    path = _g3_paths()[scope]
    context_source = Main.T2FrozenSourceFixturePreparationV1.frozen_fixture_case(
        _G3_T2_AUTH_CONTEXT, case_id, path)
    context = context_source.context
    observation = context_source.observation
    locator = G.G3IndependentSourceLocatorV1(scope, context_source.repository_root,
        something(observation.observed_head, ""), context_source.source_path,
        context_source.source_bytes, context_source.source_sha256,
        observation.tree_entry_count == 0 ? :absent_untracked : :present,
        observation.working_tree_status === :clean ? :present : :absent_untracked,
        observation.working_tree_status, context_source.source_sha256)
    _G3_T2_CONTEXTS[(locator.source_path, locator.source_sha256.value)] = context
    preparation = JSON3.read(String(context_source.preparation_receipt.bytes))
    @test preparation.schema == "t2-frozen-source-preparation-receipt-v1"
    @test preparation.availability_status == "available"
    @test !isempty(preparation.commands)
    @test all(row -> row.command_argv[1:2] == ["git", "-C"] &&
        isabspath(row.command_argv[3]) && !isempty(row.working_directory), preparation.commands)
    @test all(row -> row.pid > 0 && row.creation_time_100ns > 0 &&
        occursin(r"^[0-9a-f]{64}$", row.stdout_sha256) &&
        occursin(r"^[0-9a-f]{64}$", row.stderr_sha256) &&
        begin
            stdout = base64decode(row.stdout_base64)
            stderr = base64decode(row.stderr_base64)
            length(stdout) == row.stdout_bytes && bytes2hex(SHA.sha256(stdout)) == row.stdout_sha256 &&
                length(stderr) == row.stderr_bytes && bytes2hex(SHA.sha256(stderr)) == row.stderr_sha256
        end, preparation.commands)
    @test all(row -> row.registration_ack.schema == "fca-managed-process-ack-v1" &&
        row.registration_ack.child_pid == row.pid &&
        row.registration_ack.child_creation_time_100ns == row.creation_time_100ns &&
        row.registration_ack.handle_duplicated && row.registration_ack.identity_registered &&
        row.registration_ack.job_bound && row.registration_ack.creation_sample_measured &&
        row.registration_ack.resume_permitted && !row.registration_ack.full_run_resource_complete,
        preparation.commands)
    merge(context_source, (locator=locator,))
end
function _factory_locator(scope; root=_FIXTURE_ROOT)
    _g3_frozen_fixture(scope, _g3_case_id(scope, root)).locator
end
_current_repo_locator(scope) = _factory_locator(scope)
_g3_formal_factory(scope, locator, args...; frozen_context=nothing) = begin
    source_locator = hasproperty(locator, :locator) ? locator.locator : locator
    context = frozen_context !== nothing ? frozen_context :
        hasproperty(locator, :context) ? locator.context : source_locator === nothing ?
        _G3_T2_AUTH_CONTEXT : get(_G3_T2_CONTEXTS,
            (String(source_locator.source_path), source_locator.source_sha256.value), nothing)
    context === nothing && throw(ArgumentError("formal G3 factory lacks fixture-specific frozen context"))
    getfield(G, :g3_source_authority_factory_v1)(scope, source_locator, args..., context)
end
function _factory_result(scope; locator=_factory_locator(scope), handle=_FACTORY_HANDLE,
        contract=G.g3_contract_ref(scope), axes=G.g3_version_axes(scope),
        declaration_ref=_factory_declaration_ref(scope), frozen_context=nothing)
    _g3_formal_factory(scope, locator, handle, contract, axes, declaration_ref;
        frozen_context=frozen_context)
end
_factory_declaration_ref(scope) =
    G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad48-f0", "v1")
@testset "AD48-F0 G3 source-authority factory V1" begin
    before_registry = G.canonical_hash(G.default_operator_registry())

    @testset "four scope construction" begin
        for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
            context_source = _g3_frozen_fixture(scope, "g3_$(scope)_clean")
            envelope = G.NativeGitReadCompatibilityV1.frozen_source(
                context_source.context, G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1)
            @test envelope !== nothing
            @test G.Digest256(bytes2hex(SHA.sha256(envelope.bytes))) == G.G3_AD45_ENVELOPE_SHA256_V1
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
        fixture = _g3_frozen_fixture(:realization, "g3_realization_autocrlf")
        locator = fixture.locator
        native = G.NativeGitReadCompatibilityV1
        raw = native.frozen_source(fixture.context, locator.source_path)
        canonical = native.frozen_source(fixture.context, fixture.observation.head_bytes_key)
        @test raw.bytes != canonical.bytes
        @test raw.byte_count == fixture.observation.worktree_raw_bytes
        @test raw.sha256 == fixture.observation.worktree_raw_sha256
        @test fixture.observation.filter_input_key == raw.manifest_key
        @test fixture.observation.filter_input_sha256 == raw.sha256
        @test canonical.byte_count == fixture.observation.head_bytes_bytes
        @test canonical.sha256 == fixture.observation.head_bytes_sha256
        @test fixture.observation.filter_status === :matches
        @test fixture.observation.filter_output_sha256 == bytes2hex(SHA.sha256(canonical.bytes))
        @test fixture.observation.filter_output_bytes == canonical.byte_count
        @test G.g3_factory_result_status(_factory_result(:realization; locator=locator)) == :present
        dirty = _g3_frozen_fixture(:realization, "g3_realization_autocrlf_dirty")
        @test G.g3_factory_result_status(_factory_result(:realization; locator=dirty.locator)) == :fail_closed
    end

    @testset "required custom clean filter preserves the real factory path" begin
        fixture = _g3_frozen_fixture(:realization, "g3_realization_filter")
        locator = fixture.locator
        native = G.NativeGitReadCompatibilityV1
        recipe = native.frozen_source(fixture.context, fixture.observation.filter_recipe_key)
        attrs = native.frozen_source(fixture.context, fixture.observation.attributes_key)
        output = native.frozen_source(fixture.context, fixture.observation.filter_output_key)
        recipe_json = JSON3.read(String(recipe.bytes))
        @test !isempty(String(recipe_json.script_source))
        @test bytes2hex(SHA.sha256(codeunits(String(recipe_json.script_source)))) == String(recipe_json.script_sha256)
        @test attrs !== nothing && output !== nothing
        @test fixture.observation.filter_status === :matches
        @test output.bytes == native.frozen_source(fixture.context, fixture.observation.head_bytes_key).bytes
        @test output.byte_count == fixture.observation.filter_output_bytes
        @test fixture.observation.filter_output_sha256 == bytes2hex(SHA.sha256(output.bytes))
        @test fixture.observation.filter_input_key == fixture.source.manifest_key
        @test fixture.observation.filter_input_sha256 == fixture.source.sha256
        preparation = JSON3.read(String(fixture.preparation_receipt.bytes))
        @test any(row -> row.argv[1] == "hash-object" && "-w" in row.argv && row.exit_code == 0, preparation.commands)
        @test any(row -> row.argv[1] == "cat-file" && row.argv[2] == "blob" && row.exit_code == 0, preparation.commands)
        @test G.g3_factory_result_status(_factory_result(:realization; locator=locator)) == :present
        for (case_id, expected) in (("g3_realization_filter_startup_failure", :startup_failure),
                ("g3_realization_filter_nonzero_failure", :nonzero_failure))
            failed = _g3_frozen_fixture(:realization, case_id)
            @test failed.observation.filter_status === expected
            @test failed.observation.filter_output_key === nothing
            @test any(row -> row.argv[1] == "hash-object" && row.exit_code != 0,
                JSON3.read(String(failed.preparation_receipt.bytes)).commands)
            @test G.g3_factory_result_status(_factory_result(:realization; locator=failed.locator)) == :fail_closed
        end
        dirty = _g3_frozen_fixture(:realization, "g3_realization_filter_dirty")
        @test G.g3_factory_result_status(_factory_result(:realization; locator=dirty.locator)) == :fail_closed
    end

    @testset "empty GIT_DIR is inherited by managed Git and fails closed" begin
        broken = _g3_frozen_fixture(:realization, "g3_realization_empty_git_dir")
        @test broken.observation.head_probe_status === :failed
        @test any(row -> row.argv == ["rev-parse", "--verify", "HEAD"] && row.exit_code != 0 &&
            row.pid > 0 && row.creation_time_100ns > 0 && row.stderr_bytes > 0,
            JSON3.read(String(broken.preparation_receipt.bytes)).commands)
        @test G.g3_factory_result_status(_factory_result(:realization; locator=broken.locator)) == :fail_closed
    end
    @testset "R1 repository-root and HEAD rejection precedence" begin
        locator = _factory_locator(:realization)
        wrong_head = repeat("0", 40)
        nested_root = joinpath(locator.repository_root, "src")
        wrong_root = G.G3IndependentSourceLocatorV1(:realization, nested_root,
            wrong_head, locator.source_path, locator.source_bytes, locator.source_sha256,
            :absent_untracked, :absent_untracked, :dirty, locator.head_blob_sha256)
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(_G3_T2_CONTEXTS[(locator.source_path, locator.source_sha256.value)], wrong_root; family=:g3) === :repository_root_mismatch

        wrong_head_and_source_present = G.G3IndependentSourceLocatorV1(:realization,
            locator.repository_root, wrong_head, locator.source_path,
            locator.source_bytes, locator.source_sha256, :present, :present, :clean,
            locator.head_blob_sha256)
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(_G3_T2_CONTEXTS[(locator.source_path, locator.source_sha256.value)], wrong_head_and_source_present; family=:g3) === :locator_head_mismatch
    end

    @testset "missing inputs are typed absence" begin
        for scope in (:realization, :control, :binding, :bundle)
            for args in ((nothing, _FACTORY_HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                         (_factory_locator(scope), nothing, G.g3_contract_ref(scope), G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                         (_factory_locator(scope), _FACTORY_HANDLE, nothing, G.g3_version_axes(scope), _factory_declaration_ref(scope)),
                         (_factory_locator(scope), _FACTORY_HANDLE, G.g3_contract_ref(scope), nothing, _factory_declaration_ref(scope)),
                         (_factory_locator(scope), _FACTORY_HANDLE, G.g3_contract_ref(scope), G.g3_version_axes(scope), nothing))
                result = _g3_formal_factory(scope, args...)
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
        fixture = _g3_frozen_fixture(scope, "g3_realization_clean")
        locator = fixture.locator
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
            result = _g3_formal_factory(scope, args...)
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
        result = _factory_result(scope; locator=bad_hash,
            frozen_context=fixture.context)
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
        failed = _g3_formal_factory(:bundle, _factory_locator(:bundle),
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
            locator = _factory_locator(scope)
            context = _G3_T2_CONTEXTS[(locator.source_path, locator.source_sha256.value)]
            result = wrapper(locator, _FACTORY_HANDLE,
                G.g3_contract_ref(scope), G.g3_version_axes(scope),
                _factory_declaration_ref(scope), context)
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
        source_fixture = _g3_frozen_fixture(:control, "g3_control_clean")
        locator = source_fixture.locator
        bad_path = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, "src/GenomeV5/G3/RealizationGenomeV5.jl", locator.source_bytes,
            locator.source_sha256, locator.head_path_status, locator.working_tree_path_status,
            locator.working_tree_status, locator.head_blob_sha256)
        result = _factory_result(:control; locator=bad_path,
            frozen_context=source_fixture.context)
        @test result.identity.reason == :source_path_mismatch
        @test result.receipt.reason == :source_path_mismatch
        missing = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status, locator.working_tree_path_status,
            :missing, locator.head_blob_sha256)
        result = _factory_result(:control; locator=missing,
            frozen_context=source_fixture.context)
        @test result.identity.reason == :working_tree_status_mismatch

        stale_head = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            "000000000000000000000000000000000000000000", locator.source_path,
            locator.source_bytes, locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status,
            locator.head_blob_sha256)
        @test _factory_result(:control; locator=stale_head,
            frozen_context=source_fixture.context).identity.reason == :locator_head_mismatch
        bad_head_path = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, :absent_untracked, locator.working_tree_path_status,
            locator.working_tree_status, locator.head_blob_sha256)
        @test _factory_result(:control; locator=bad_head_path,
            frozen_context=source_fixture.context).identity.reason == :head_path_status_mismatch
        bad_work_path = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status, :absent_untracked,
            locator.working_tree_status, locator.head_blob_sha256)
        @test _factory_result(:control; locator=bad_work_path,
            frozen_context=source_fixture.context).identity.reason == :working_tree_path_status_mismatch
        bad_work_status = G.G3IndependentSourceLocatorV1(:control, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status, locator.working_tree_path_status,
            :dirty, locator.head_blob_sha256)
        @test _factory_result(:control; locator=bad_work_status,
            frozen_context=source_fixture.context).identity.reason == :working_tree_status_mismatch
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
        source_fixture = _g3_frozen_fixture(scope, "g3_realization_clean")
        locator = source_fixture.locator
        wrong_root = G.G3IndependentSourceLocatorV1(scope,
            joinpath(locator.repository_root, "nested"), locator.observed_head,
            locator.source_path, locator.source_bytes, locator.source_sha256,
            locator.head_path_status, locator.working_tree_path_status,
            locator.working_tree_status, locator.head_blob_sha256)
        @test G.g3_factory_result_status(_factory_result(scope; locator=wrong_root,
            frozen_context=source_fixture.context)) == :fail_closed
        @test _factory_result(scope; locator=wrong_root,
            frozen_context=source_fixture.context).identity.reason == :repository_root_mismatch
        stale_head = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            repeat("0", 40), locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status,
            locator.head_blob_sha256)
        @test _factory_result(scope; locator=stale_head,
            frozen_context=source_fixture.context).identity.reason == :locator_head_mismatch
        bad_blob = G.G3IndependentSourceLocatorV1(scope, locator.repository_root,
            locator.observed_head, locator.source_path, locator.source_bytes,
            locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status,
            G.digest256_text("wrong-head-blob"))
        @test _factory_result(scope; locator=bad_blob,
            frozen_context=source_fixture.context).identity.reason == :head_blob_sha256_mismatch
    end
    @testset "index trust flags fail closed" begin
        scope = :control
        for (case_id, expected) in (("g3_control_assume_unchanged", :index_assume_unchanged),
                ("g3_control_skip_worktree", :index_skip_worktree))
            flagged = _g3_frozen_fixture(scope, case_id)
            @test flagged.observation.verbose_flag_status === expected
            result = _factory_result(scope; locator=flagged.locator)
            @test G.g3_factory_result_status(result) == :fail_closed
            @test result.identity.reason === expected
        end
        @test G.g3_factory_result_status(_factory_result(scope; locator=_factory_locator(scope))) == :present
    end
end
