using SHA
using Test
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "..", "..", "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))

const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const OUT = @__DIR__
const SCOPES = G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
const PATHS = Dict(
    :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
    :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
    :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
)
const HANDLE = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1,
    G.G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1)

function git(root, args...)
    readchomp(Cmd(vcat(String["git", "-C", String(root)], String.(args))))
end

gitcmd(root, args...) = Cmd(vcat(String["git", "-C", String(root)], String.(args)))

function fixture_locator(fixture, scope; head=git(fixture, "rev-parse", "HEAD"),
        source_path=PATHS[scope], source_bytes=nothing, source_sha=nothing,
        head_path=:present, work_path=:present, work_status=:clean, head_blob=nothing)
    bytes = read(joinpath(fixture, split(source_path, '/')...))
    source_bytes === nothing && (source_bytes = length(bytes))
    source_sha === nothing && (source_sha = G.Digest256(bytes2hex(SHA.sha256(bytes))))
    head_blob === nothing && (head_blob = source_sha)
    G.G3IndependentSourceLocatorV1(scope, fixture, head, source_path,
        source_bytes, source_sha, head_path, work_path, work_status, head_blob)
end

function expected_result(scope, locator; declaration_ref=nothing)
    declaration_ref === nothing && (declaration_ref = G.QualifiedRefV1(
        "fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/r2", "v1"))
    G.g3_source_authority_factory_v1(scope, locator, HANDLE,
        G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref)
end

function make_fixture()
    fixture = mktempdir()
    run(Cmd(["git", "-C", fixture, "init", "-q"]))
    run(Cmd(["git", "-C", fixture, "config", "user.email", "ad52-r2@example.invalid"]))
    run(Cmd(["git", "-C", fixture, "config", "user.name", "AD52 R2"]))
    run(Cmd(["git", "-C", fixture, "config", "core.autocrlf", "false"]))
    for path in values(PATHS)
        target = joinpath(fixture, split(path, '/')...)
        mkpath(dirname(target))
        write(target, read(joinpath(ROOT, split(path, '/')...)))
    end
    envelope = joinpath(fixture, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
    mkpath(dirname(envelope))
    write(envelope, read(joinpath(ROOT, split(G.G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)))
    run(Cmd(["git", "-C", fixture, "add", "--all"]))
    run(Cmd(["git", "-C", fixture, "commit", "-q", "-m", "AD52 R2 tracked fixture"]))
    fixture
end

function result_label(result)
    (status=G.g3_factory_result_status(result), identity=string(typeof(result.identity)),
        reason=hasproperty(result.identity, :reason) ? string(result.identity.reason) : nothing,
        trusted=hasproperty(result.receipt, :trusted_attestation_created) ?
            result.receipt.trusted_attestation_created : false,
        candidate=hasproperty(result.receipt, :candidate_identity_created) ?
            result.receipt.candidate_identity_created : false,
        final=hasproperty(result.receipt, :final_candidate_or_package_declaration_hash_created) ?
            result.receipt.final_candidate_or_package_declaration_hash_created : false,
        declaration=(result.source_declaration !== nothing))
end

fixture = make_fixture()
registry_before = G.canonical_hash(G.default_operator_registry())
results = Dict{String,Any}()

try
    @testset "AD52 R2 independent adversarial probe" begin
        @test normpath(realpath(ROOT)) == normpath(realpath(readchomp(gitcmd(ROOT, "rev-parse", "--show-toplevel"))))
        @test all(git(fixture, "ls-tree", "-r", "--name-only", "HEAD", "--", PATHS[s]) == PATHS[s] for s in SCOPES)
        @test all(length(split(git(fixture, "ls-files", "--stage", "--", PATHS[s]), '\n')) == 1 for s in SCOPES)

        for scope in SCOPES
            path = PATHS[scope]
            locator = fixture_locator(fixture, scope)
            head = git(fixture, "rev-parse", "HEAD")
            blob = git(fixture, "rev-parse", "HEAD:$path")
            show_bytes = read(gitcmd(fixture, "show", "HEAD:$path"))
            cat_bytes = read(gitcmd(fixture, "cat-file", "blob", blob))
            working_bytes = read(joinpath(fixture, split(path, '/')...))
            @test occursin(r"^[0-9a-f]{40}$", head)
            @test occursin(r"^[0-9a-f]{40}$", blob)
            @test show_bytes == cat_bytes == working_bytes
            @test isempty(git(fixture, "status", "--porcelain=v1", "--untracked-files=all", "--", path))
            result = expected_result(scope, locator)
            results[string(scope, ":present")] = result_label(result)
            @test G.g3_factory_result_status(result) == :present
            @test result.receipt.trusted_attestation_created == false
            @test result.receipt.candidate_identity_created == false
            @test result.receipt.final_candidate_or_package_declaration_hash_created == false
            @test result.source_declaration !== nothing
        end

        # The current repository's four implementation sources are untracked and absent from HEAD.
        for scope in SCOPES
            path = PATHS[scope]
            bytes = read(joinpath(ROOT, split(path, '/')...))
            locator = G.G3IndependentSourceLocatorV1(scope, ROOT,
                git(ROOT, "rev-parse", "HEAD"), path, length(bytes),
                G.Digest256(bytes2hex(SHA.sha256(bytes))), :absent_untracked,
                :absent_untracked, :untracked, nothing)
            result = expected_result(scope, locator)
            results[string(scope, ":current_untracked")] = result_label(result)
            @test G.g3_factory_result_status(result) == :typed_absent
            @test result.identity.reason == :source_authority_missing
            @test result.source_declaration === nothing
            @test result.receipt.candidate_identity_created == false
        end

        scope = :realization
        locator = fixture_locator(fixture, scope)
        controls = Dict{String,Any}()
        function control(name, altered)
            result = expected_result(scope, altered)
            controls[name] = result_label(result)
            @test G.g3_factory_result_status(result) == :fail_closed
            @test result.source_declaration === nothing
            @test result.receipt.candidate_identity_created == false
        end
        control("repository_root_relabel", G.G3IndependentSourceLocatorV1(scope,
            joinpath(fixture, "nested"), locator.observed_head, locator.source_path,
            locator.source_bytes, locator.source_sha256, locator.head_path_status,
            locator.working_tree_path_status, locator.working_tree_status, locator.head_blob_sha256))
        control("head_relabel", fixture_locator(fixture, scope; head=repeat("0", 40)))
        control("path_relabel", fixture_locator(fixture, scope; source_path=PATHS[:control]))
        control("head_blob_relabel", fixture_locator(fixture, scope;
            head_blob=G.digest256_text("wrong-head-blob")))
        control("source_hash_relabel", fixture_locator(fixture, scope;
            source_sha=G.digest256_text("wrong-source")))
        control("source_bytes_relabel", fixture_locator(fixture, scope;
            source_bytes=locator.source_bytes + 1))
        control("head_path_status_relabel", fixture_locator(fixture, scope; head_path=:absent_untracked))
        control("work_path_status_relabel", fixture_locator(fixture, scope; work_path=:absent_untracked))
        control("work_status_relabel", fixture_locator(fixture, scope; work_status=:dirty))

        # Index trust flags must be observed from ls-files, regardless of clean porcelain.
        run(Cmd(["git", "-C", fixture, "update-index", "--assume-unchanged", "--", PATHS[:control]]))
        assumed = expected_result(:control, fixture_locator(fixture, :control))
        controls["assume_unchanged"] = result_label(assumed)
        @test G.g3_factory_result_status(assumed) == :fail_closed
        @test assumed.identity.reason == :index_assume_unchanged
        run(Cmd(["git", "-C", fixture, "update-index", "--no-assume-unchanged", "--", PATHS[:control]]))
        run(Cmd(["git", "-C", fixture, "update-index", "--skip-worktree", "--", PATHS[:control]]))
        skipped = expected_result(:control, fixture_locator(fixture, :control))
        controls["skip_worktree"] = result_label(skipped)
        @test G.g3_factory_result_status(skipped) == :fail_closed
        @test skipped.identity.reason == :index_skip_worktree
        run(Cmd(["git", "-C", fixture, "update-index", "--no-skip-worktree", "--", PATHS[:control]]))

        # Working-tree mutation must fail even if the caller relabels the locator as clean/present.
        open(joinpath(fixture, split(PATHS[:bundle], '/')...), "a") do io
            write(io, "\n# AD52 R2 mutation\n")
        end
        mutated = expected_result(:bundle, fixture_locator(fixture, :bundle))
        controls["working_bytes_mutated"] = result_label(mutated)
        @test G.g3_factory_result_status(mutated) == :fail_closed
        @test mutated.identity.reason in (:source_hash_mismatch, :working_tree_head_bytes_mismatch, :working_tree_dirty)

        # Registry must remain byte/semantic-identical around all calls.
        @test G.canonical_hash(G.default_operator_registry()) == registry_before
        results["controls"] = controls
    end
finally
    # The fixture is intentionally ephemeral; the outer runner records its final absence.
    rm(fixture; recursive=true, force=true)
end

@test G.canonical_hash(G.default_operator_registry()) == registry_before
println("AD52_R2_PROBE_PASS")
println("scopes=4 positive=4 current_untracked=4 controls=$(length(results[\"controls\"]))")
