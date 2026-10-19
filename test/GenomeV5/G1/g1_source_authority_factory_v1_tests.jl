using Test
using Base64
using SHA
using JSON3
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))

const _ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
if !isdefined(Main, :T2FrozenSourceFixturePreparationV1)
    Base.include(Main, joinpath(_ROOT, "scripts", "prepare_t2_source_fixtures.jl"))
end
const _G1_T2_AUTH_CONTEXT = Main.T2FrozenSourceFixturePreparationV1.load_authorized_context_from_environment()
const _G1_T2_CONTEXTS = Dict{Tuple{String,String},Any}()
function _g1_formal_factory(locator, args...; frozen_context=nothing)
    source_locator = hasproperty(locator, :locator) ? locator.locator : locator
    context = frozen_context !== nothing ? frozen_context :
        hasproperty(locator, :context) ? locator.context : source_locator === nothing ?
        _G1_T2_AUTH_CONTEXT : get(_G1_T2_CONTEXTS,
            (String(source_locator.source_path), source_locator.source_sha256.value), nothing)
    context === nothing && throw(ArgumentError("formal G1 factory lacks the fixture-specific frozen context"))
    getfield(G, :g1_source_authority_factory_v1)(source_locator, args..., context)
end
const _G1_T2_FIXTURE_PREFIX = "test/fixtures/t2_source_authority/cases/"
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

function _g1_frozen_fixture(case_id, source_path; provenance=:isolated_test_fixture)
    native = G.NativeGitReadCompatibilityV1
    context = native.FrozenSourceContextV1(_G1_T2_AUTH_CONTEXT.authorization)
    fixture = Main.T2FrozenSourceFixturePreparationV1.frozen_fixture_case(
        context, case_id, source_path)
    context = fixture.context
    observation = fixture.observation
    _G1_T2_CONTEXTS[(fixture.source_path, fixture.source_sha256.value)] = context
    preparation = JSON3.read(String(fixture.preparation_receipt.bytes))
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
    head_digest = fixture.source_sha256
    locator = G.G1IndependentSourceLocatorV1(fixture.repository_root,
        something(observation.observed_head, ""), fixture.source_path,
        fixture.source_bytes, head_digest,
        observation.tree_entry_count == 0 ? :absent_untracked : :present,
        observation.working_tree_status === :clean ? :present : :absent_untracked,
        observation.working_tree_status, head_digest, provenance)
    merge(fixture, (locator=locator,))
end

function _tracked_fixture(source_path; autocrlf=false, clean_filter=false, case_id=nothing)
    clean_filter && autocrlf && error("clean-filter fixture is separate from the autocrlf fixture")
    selected = case_id === nothing ? clean_filter ? "g1_filter" : autocrlf ? "g1_autocrlf" : "g1_clean" : String(case_id)
    fixture = _g1_frozen_fixture(selected, source_path)
    if clean_filter
        native = G.NativeGitReadCompatibilityV1
        observation = fixture.observation
        context = fixture.context
        recipe = native.frozen_source(context, something(observation.filter_recipe_key, ""))
        attrs = native.frozen_source(context, something(observation.attributes_key, ""))
        document = recipe === nothing ? nothing : JSON3.read(String(recipe.bytes))
        script = document === nothing ? UInt8[] : Vector{UInt8}(codeunits(document.script_source))
        filter_meta = (script_bytes=script,
            script_sha256=isempty(script) ? "" : bytes2hex(SHA.sha256(script)),
            python_executable=document === nothing ? "" : String(document.python_executable),
            clean_argv=document === nothing ? String[] : String.(document.clean_argv),
            nonzero_argv=document === nothing ? String[] : String.(document.nonzero_argv),
            startup_failure_argv=document === nothing ? String[] : String.(document.startup_failure_argv),
            recipe_bytes=recipe === nothing ? UInt8[] : recipe.bytes,
            attributes_bytes=attrs === nothing ? UInt8[] : attrs.bytes)
        return merge(fixture, (; (name => getproperty(fixture.locator, name) for name in propertynames(fixture.locator))...,
            clean_filter=filter_meta))
    end
    merge(fixture, (; (name => getproperty(fixture.locator, name) for name in propertynames(fixture.locator))...))
end

function _current_locator()
    _g1_frozen_fixture("g1_clean", G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1;
        provenance=:isolated_test_fixture).locator
end

@testset "AD49-F0 G1 source authority factory V1" begin
    payload, ctor = _payload_and_constructor(); contract = G._g1sf_expected_contract()
    @test G.g1_source_factory_result_status(_g1_formal_factory(_current_locator(), _HANDLE, contract, payload, _AXES, ctor)) == :present
    fixture = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
    result = _g1_formal_factory(fixture, _HANDLE, contract, payload, _AXES, ctor)
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
    @test G.canonical_hash(result) == G.canonical_hash(_g1_formal_factory(fixture, _HANDLE, contract, payload, _AXES, ctor))
    @testset "core.autocrlf=true canonical HEAD locator" begin
        filtered = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; autocrlf=true)
        context = filtered.context
        raw = G.NativeGitReadCompatibilityV1.frozen_source(context, filtered.source_path)
        canonical = G.NativeGitReadCompatibilityV1.frozen_source(context, filtered.observation.head_bytes_key)
        @test raw.bytes != canonical.bytes
        @test raw.byte_count == filtered.observation.worktree_raw_bytes
        @test raw.sha256 == filtered.observation.worktree_raw_sha256
        @test filtered.observation.filter_input_key == raw.manifest_key
        @test filtered.observation.filter_input_sha256 == raw.sha256
        @test canonical.byte_count == filtered.observation.head_bytes_bytes
        @test canonical.sha256 == filtered.observation.head_bytes_sha256
        @test filtered.observation.filter_status === :matches
        @test filtered.observation.filter_output_sha256 == bytes2hex(SHA.sha256(canonical.bytes))
        @test filtered.observation.filter_output_bytes == canonical.byte_count
        @test G.g1_source_factory_result_status(_g1_formal_factory(filtered, _HANDLE, contract, payload, _AXES, ctor)) == :present
        dirty = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_autocrlf_dirty")
        @test G.g1_source_factory_result_status(_g1_formal_factory(dirty, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
    end

    @testset "required custom clean filter preserves the real factory path" begin
        filtered = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; clean_filter=true)
        locator = filtered.locator
        filter = filtered.clean_filter
        native = G.NativeGitReadCompatibilityV1
        context = filtered.context
        recipe = native.frozen_source(context, filtered.observation.filter_recipe_key)
        attrs = native.frozen_source(context, filtered.observation.attributes_key)
        clean_output = native.frozen_source(context, filtered.observation.filter_output_key)
        @test !isempty(filter.script_bytes)
        recipe_json = JSON3.read(String(recipe.bytes))
        @test bytes2hex(SHA.sha256(filter.script_bytes)) == String(recipe_json.script_sha256)
        @test String.(recipe_json.clean_argv) == filter.clean_argv
        @test String.(recipe_json.startup_failure_argv) == filter.startup_failure_argv
        @test String.(recipe_json.nonzero_argv) == filter.nonzero_argv
        @test recipe !== nothing && attrs !== nothing && clean_output !== nothing
        @test filtered.observation.filter_status === :matches
        @test filtered.observation.filter_output_sha256 == bytes2hex(SHA.sha256(clean_output.bytes))
        @test clean_output.bytes == native.frozen_source(context, filtered.observation.head_bytes_key).bytes
        @test clean_output.byte_count == filtered.observation.filter_output_bytes
        @test filtered.observation.filter_input_key == filtered.source.manifest_key
        @test filtered.observation.filter_input_sha256 == filtered.source.sha256
        preparation = JSON3.read(String(filtered.preparation_receipt.bytes))
        @test any(row -> row.argv[1] == "hash-object" && "-w" in row.argv && row.exit_code == 0, preparation.commands)
        @test any(row -> row.argv[1] == "cat-file" && row.argv[2] == "blob" && row.exit_code == 0, preparation.commands)
        @test G.g1_source_factory_result_status(_g1_formal_factory(locator, _HANDLE, contract, payload, _AXES, ctor)) == :present

        startup = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_filter_startup_failure")
        nonzero = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_filter_nonzero_failure")
        @test startup.observation.filter_status === :startup_failure
        @test nonzero.observation.filter_status === :nonzero_failure
        @test startup.observation.filter_output_key === nothing
        @test nonzero.observation.filter_output_key === nothing
        @test any(row -> row.argv[1] == "hash-object" && row.exit_code != 0,
            JSON3.read(String(startup.preparation_receipt.bytes)).commands)
        @test any(row -> row.argv[1] == "hash-object" && row.exit_code != 0,
            JSON3.read(String(nonzero.preparation_receipt.bytes)).commands)
        @test G.g1_source_factory_result_status(_g1_formal_factory(startup, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g1_source_factory_result_status(_g1_formal_factory(nonzero, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        dirty = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_filter_dirty")
        @test G.g1_source_factory_result_status(_g1_formal_factory(dirty.locator, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
    end

    @testset "empty GIT_DIR is inherited by managed Git and fails closed" begin
        broken = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_empty_git_dir")
        @test broken.observation.head_probe_status === :failed
        @test any(row -> row.argv == ["rev-parse", "--verify", "HEAD"] && row.exit_code != 0 &&
            row.pid > 0 && row.creation_time_100ns > 0 && row.stderr_bytes > 0,
            JSON3.read(String(broken.preparation_receipt.bytes)).commands)
        @test G.g1_source_factory_result_status(_g1_formal_factory(broken, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
    end

    @testset "frozen missing and directory source precedence" begin
        missing = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_missing")
        directory = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_directory")
        @test missing.observation.worktree_path_kind === :missing
        @test directory.observation.worktree_path_kind === :directory
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(missing.context,
            missing.locator; family=:g1) === :source_file_missing
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(directory.context,
            directory.locator; family=:g1) === :source_file_missing
        @test G.g1_source_factory_result_status(_g1_formal_factory(missing, _HANDLE,
            contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g1_source_factory_result_status(_g1_formal_factory(directory, _HANDLE,
            contract, payload, _AXES, ctor)) == :fail_closed
    end
    @testset "R1 repository-root and HEAD rejection precedence" begin
        wrong_head = repeat("0", 40)
        nested_root = joinpath(fixture.repository_root, "src")
        wrong_root = G.G1IndependentSourceLocatorV1(nested_root, wrong_head,
            fixture.source_path, fixture.source_bytes, fixture.source_sha256,
            :absent_untracked, :absent_untracked, :dirty, fixture.head_blob_sha256,
            fixture.provenance)
        context = fixture.context
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(context, wrong_root;
            family=:g1, stage=:git_only) === :repository_root_mismatch

        wrong_head_locator = G.G1IndependentSourceLocatorV1(
            fixture.repository_root, wrong_head, fixture.source_path,
            fixture.source_bytes, fixture.source_sha256, :present, :present, :clean,
            fixture.head_blob_sha256, fixture.provenance)
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(context, wrong_head_locator;
            family=:g1, stage=:git_only) === :locator_head_mismatch

        wrong_head_and_missing_source = G.G1IndependentSourceLocatorV1(
            fixture.repository_root, wrong_head, fixture.source_path * ".not-in-head",
            fixture.source_bytes, fixture.source_sha256, :present, :present, :clean,
            fixture.head_blob_sha256, fixture.provenance)
        @test G.NativeGitReadCompatibilityV1.frozen_source_validation(context,
            wrong_head_and_missing_source; family=:g1, stage=:git_only) === :locator_head_mismatch
    end

    @testset "typed absence and fail closed" begin
        for value in (nothing,)
            x = _g1_formal_factory(value, _HANDLE, contract, payload, _AXES, ctor)
            @test G.g1_source_factory_result_status(x) == :typed_absent
            @test x.receipt isa G.AbsentG1SourceConstructionReceiptV1
        end
        @test G.g1_source_factory_result_status(_g1_formal_factory(fixture, G.QualifiedRefV1("foreign", "v5"), contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g1_source_factory_result_status(_g1_formal_factory(fixture, _HANDLE, G.GenomeContractRef("foreign", "v5", contract.schema_hash, contract.canonicalization_hash, contract.compatibility_profile), payload, _AXES, ctor)) == :fail_closed
        bad = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, G.digest256_text("changed"), fixture.head_path_status, fixture.working_tree_path_status, fixture.working_tree_status, fixture.head_blob_sha256)
        @test G.g1_source_factory_result_status(_g1_formal_factory(bad, _HANDLE, contract, payload, _AXES, ctor;
            frozen_context=fixture.context)) == :fail_closed
        @test G.g1_source_factory_result_status(_g1_formal_factory(fixture, _HANDLE, contract, payload, _AXES, G.G1SourceDeclarationConstructorV1(x -> nothing, ctor.candidate_ref, ctor.operators, ctor.closure_ref, ctor.applicability_ref, ctor.applicability_domain, ctor.negative_controls))) == :fail_closed
        relabel = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, fixture.source_sha256, :present, :present, :clean, fixture.head_blob_sha256, :repository_head)
        @test G.g1_source_factory_result_status(_g1_formal_factory(relabel, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        assume = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_assume_unchanged")
        skip = _tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; case_id="g1_skip_worktree")
        @test assume.observation.verbose_flag_status === :assume_unchanged
        @test skip.observation.verbose_flag_status === :skip_worktree
        @test G.g1_source_factory_result_status(_g1_formal_factory(assume, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        @test G.g1_source_factory_result_status(_g1_formal_factory(skip, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
        bad_blob = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path, fixture.source_bytes, fixture.source_sha256, fixture.head_path_status, fixture.working_tree_path_status, fixture.working_tree_status, G.digest256_text("head-blob-mismatch"), fixture.provenance)
        @test G.g1_source_factory_result_status(_g1_formal_factory(bad_blob, _HANDLE, contract, payload, _AXES, ctor)) == :fail_closed
    end
end

println("AD49_F0_G1_FACTORY_TESTS_DEFINED=true")
println("AD49_F0_G1_FACTORY_SYNTHETIC_FIXTURE_ONLY=true")
