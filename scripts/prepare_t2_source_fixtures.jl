"""
One-time, pre-freeze preparation for the T2 G1/G2/G3 source-authority fixtures.

This is not included by any test file and is never part of a formal replay. It
uses the repository's managed Git launcher only when an operator explicitly
calls `prepare_frozen_source_fixtures!`. The emitted files are inputs to the
FrozenInputSnapshot and must be frozen before any T2 consumer starts.
"""

using SHA
using JSON3
using FusionConceptAI

module T2FrozenSourceFixturePreparationV1
using Base64
using SHA
using JSON3
using FusionConceptAI

export prepare_frozen_source_fixtures!, load_authorized_context,
       load_authorized_context_from_environment, register_frozen_fixture!,
       frozen_fixture_case

const _T2FS_G = FusionConceptAI
const _T2FS_GIT = _T2FS_G.NativeGitReadCompatibilityV1
const _T2FS_FORMAT = "frozen-source-observation-v1"
const _T2FS_FILTER_NAME = "fca_t2_frozen_clean_r1"
const _T2FS_FILTER_SOURCE = raw"""import sys
mode = sys.argv[1]
marker = b"\n# FCA-T2-PREFREEZE-CLEAN-MARKER\n"
data = sys.stdin.buffer.read()
if mode == "startup-failure":
    raise SystemExit(23)
if mode == "nonzero-failure":
    raise SystemExit(24)
if mode != "clean":
    raise SystemExit(25)
sys.stdout.buffer.write(data.replace(marker, b"", 1))
"""

_t2fs_sha(bytes) = bytes2hex(SHA.sha256(Vector{UInt8}(bytes)))
_t2fs_output_bytes(value) = value isa Vector{UInt8} ? value : Vector{UInt8}(codeunits(String(value)))
_t2fs_shell_quote(value::AbstractString) = "'" * replace(replace(String(value), '\\' => "/"), "'" => "'\"'\"'") * "'"

"Construct one explicit source context from the protocol authorized by the caller."
function load_authorized_context(protocol, protocol_sha256::AbstractString)
    native = _T2FS_G.NativeGitReadCompatibilityV1
    field(record, key) = record isa AbstractDict ? get(record, key, nothing) :
        hasproperty(record, Symbol(key)) ? getproperty(record, Symbol(key)) : nothing
    snapshots = Any[]
    top = field(protocol, "source_snapshot")
    top === nothing || push!(snapshots, top)
    consumer = field(protocol, "consumer")
    consumer_protocol = field(consumer, "protocol")
    nested = field(consumer_protocol, "source_snapshot")
    nested === nothing || push!(snapshots, nested)
    isempty(snapshots) &&
        throw(ArgumentError("authorized T2 protocol has no supported source_snapshot record"))
    authorizations = map(snapshot -> native.FrozenSourceAuthorizationV1(
        String(protocol_sha256), snapshot), snapshots)
    all(auth -> native._same_frozen_authorization(first(authorizations), auth),
        authorizations) ||
        throw(ArgumentError("authorized T2 protocol source_snapshot records disagree"))
    # FrozenSourceContextV1 independently reopens and hashes the pinned raw
    # protocol, manifest, and complete closure before admitting this context.
    native.FrozenSourceContextV1(first(authorizations))
end

function load_authorized_context_from_environment()
    _T2FS_G.NativeGitReadCompatibilityV1.initialize_frozen_runtime!(required=true)
end

function register_frozen_fixture!(context, source_key::AbstractString, observation_key::AbstractString)
    native = _T2FS_G.NativeGitReadCompatibilityV1
    observation = native.register_frozen_observation!(context,
        String(source_key), String(observation_key))
    source = native.register_frozen_source!(context, String(source_key))
    (source=source, observation=observation)
end

function frozen_fixture_case(context, case_id::AbstractString, source_path::AbstractString)
    native = _T2FS_G.NativeGitReadCompatibilityV1
    case_context = native.FrozenSourceContextV1(context.authorization;
        fixture_case_id=String(case_id))
    root = case_context.authorization.source_root
    prefix = "test/fixtures/t2_source_authority/cases/" * String(case_id)
    source_key = String(source_path)
    observation_key = prefix * "/frozen/observations/source.json"
    receipt_key = prefix * "/frozen/preparation_receipt.json"
    registered = register_frozen_fixture!(case_context, source_key, observation_key)
    registered.observation === nothing &&
        throw(ArgumentError("authorized frozen fixture observation is absent: $(observation_key)"))
    observation = registered.observation
    for key in (observation.head_bytes_key, observation.attributes_key,
            observation.filter_recipe_key, observation.filter_output_key,
            prefix * "/frozen/preparation_receipt.json")
        key === nothing && continue
        native.register_frozen_source!(case_context, key)
    end
    observation.ad45_envelope_path === nothing ||
        native.register_frozen_source!(case_context, observation.ad45_envelope_path)
    head = native.frozen_source(case_context, something(observation.head_bytes_key, ""))
    head === nothing && throw(ArgumentError("authorized frozen HEAD bytes are absent"))
    receipt = native.frozen_source(case_context, receipt_key)
    (repository_root=root, source_path=source_key, fixture_case_id=String(case_id),
        source=registered.source,
        head=head, observation=observation, observation_path=observation_key,
        context=case_context,
        preparation_receipt=receipt,
        head_blob_sha256=_t2fs_sha(head.bytes),
        source_bytes=head.byte_count,
        source_sha256=_T2FS_G.Digest256(_t2fs_sha(head.bytes)))
end

function _t2fs_capture(root, args...; as_bytes=false)
    captured = _T2FS_GIT.capture_git(root, args...; as_bytes=as_bytes)
    ack = captured.registration_ack
    ack isa _T2FS_G.ManagedExternalProcessV1.ManagedProcessAck ||
        error("pre-freeze fixture Git lacks a managed registration ACK")
    ack.child_pid == captured.pid && ack.child_creation_time_100ns == captured.creation_time_100ns ||
        error("pre-freeze fixture Git ACK does not bind the actual process generation")
    ack.handle_duplicated && ack.identity_registered && ack.job_bound &&
        ack.creation_sample_measured && ack.resume_permitted && !ack.full_run_resource_complete ||
        error("pre-freeze fixture Git ACK is incomplete")
    captured
end

function _t2fs_git(root, args...; as_bytes=false, allow_failure=false,
        command_log=nothing, environment_overrides=NamedTuple())
    # Every preparation command retains the exact captured stream bytes in its
    # receipt, including commands whose callers later interpret output as text.
    captured = _t2fs_capture(root, args...; as_bytes=true)
    if command_log !== nothing
        ack = captured.registration_ack
        stdout_bytes = _t2fs_output_bytes(captured.stdout)
        stderr_bytes = _t2fs_output_bytes(captured.stderr)
        push!(command_log, (argv=String.(args),
            command_argv=String["git", "-C", String(root), String.(args)...],
            working_directory=pwd(), environment_overrides=environment_overrides,
            exit_code=captured.exit_code, pid=captured.pid,
            creation_time_100ns=captured.creation_time_100ns,
            registration_ack=(schema=ack.schema, session_id=ack.session_id,
                scope_sha256=ack.scope_sha256, child_pid=ack.child_pid,
                child_creation_time_100ns=ack.child_creation_time_100ns,
                parent_pid=ack.parent_pid,
                parent_creation_time_100ns=ack.parent_creation_time_100ns,
                monitor_pid=ack.monitor_pid,
                monitor_creation_time_100ns=ack.monitor_creation_time_100ns,
                registration_sequence=ack.registration_sequence,
                handle_duplicated=ack.handle_duplicated,
                identity_registered=ack.identity_registered, job_bound=ack.job_bound,
                creation_sample_measured=ack.creation_sample_measured,
                resume_permitted=ack.resume_permitted,
                full_run_resource_complete=ack.full_run_resource_complete),
            stdout_bytes=length(stdout_bytes), stdout_base64=base64encode(stdout_bytes),
            stdout_sha256=_t2fs_sha(stdout_bytes),
            stderr_bytes=length(stderr_bytes), stderr_base64=base64encode(stderr_bytes),
            stderr_sha256=_t2fs_sha(stderr_bytes)))
    end
    if !allow_failure
        typeof(captured.exit_code) === Int && captured.exit_code == 0 ||
            error("pre-freeze fixture Git command failed: git -C $(root) $(join(String.(args), ' '))")
    end
    captured
end

function _t2fs_is_optional_symlink_capability_error(err)
    typeof(err) === Base.IOError || return false
    code = getproperty(err, :code)
    code isa Integer || return false
    code in (Base.UV_EPERM, Base.UV_EACCES, Base.UV_ENOSYS, Base.UV_ENOTSUP)
end

function _t2fs_unavailable_symlink_receipt!(output_root, logical_prefix,
        case_id, destination, err)
    receipt = (schema="t2-frozen-source-preparation-receipt-v1",
        case_id=String(case_id), mode="symlink",
        availability_status="platform_unavailable",
        fixture_root="isolated_temporary_git_repository",
        operation="symlink", path=String(destination),
        exception_type=string(typeof(err)), exception_code=Int(getproperty(err, :code)),
        error_text=sprint(showerror, err), source_key=nothing,
        head_key=nothing, observation_key=nothing,
        commands=NamedTuple[], emitted=NamedTuple[])
    receipt_bytes = Vector{UInt8}(codeunits(JSON3.write(receipt) * "\n"))
    entry = _t2fs_emit(output_root,
        String(logical_prefix) * "/frozen/preparation_receipt.json",
        receipt_bytes, "t2_fixture_preparation_receipt_v1")
    entry
end

function _t2fs_git_text(root, args...; allow_failure=false)
    captured = _t2fs_git(root, args...; allow_failure=allow_failure)
    stdout = captured.stdout isa AbstractString ? String(captured.stdout) :
        captured.stdout isa AbstractVector{UInt8} ? String(captured.stdout) : ""
    stderr = captured.stderr isa AbstractString ? String(captured.stderr) :
        captured.stderr isa AbstractVector{UInt8} ? String(captured.stderr) : ""
    (captured=captured, stdout=stdout, stderr=stderr)
end

function _t2fs_emit(output_root, logical_path, bytes, role)
    occursin('\\', logical_path) && error("fixture logical paths use slash separators")
    isabspath(logical_path) && error("fixture logical path must be root-relative")
    any(part -> part in ("", ".", ".."), split(logical_path, '/'; keepempty=true)) &&
        error("fixture logical path is not canonical")
    path = joinpath(output_root, split(logical_path, '/')...)
    mkpath(dirname(path))
    write(path, bytes)
    (path=logical_path, role=String(role), bytes=length(bytes), sha256=_t2fs_sha(bytes))
end

function _t2fs_kind(path)
    islink(path) && return "symlink"
    isfile(path) && return "regular_file"
    isdir(path) && return "directory"
    ispath(path) && return "other"
    "missing"
end

function _t2fs_observe!(output_root, fixture_root, logical_prefix, fixture_case_id, source_path,
        captures;
        case_mode="unknown",
        binding_envelope=nothing, attributes=nothing, recipe=nothing, expected_filter="not_applicable",
        empty_git_dir_probe=false)
    record(args...; as_bytes=false, allow_failure=false) = begin
        item = if empty_git_dir_probe && String.(args) == ["rev-parse", "--verify", "HEAD"]
            withenv("GIT_DIR" => "") do
                _t2fs_git(fixture_root, args...; as_bytes=as_bytes,
                    allow_failure=allow_failure, command_log=captures,
                    environment_overrides=(GIT_DIR="",))
            end
        else
            _t2fs_git(fixture_root, args...; as_bytes=as_bytes,
                allow_failure=allow_failure, command_log=captures)
        end
        item
    end

    root_query = record("rev-parse", "--show-toplevel"; allow_failure=true)
    head_query = record("rev-parse", "--verify", "HEAD"; allow_failure=true)
    tree_query = record("rev-parse", "--verify", "HEAD^{tree}"; allow_failure=true)
    head_path_query = record("cat-file", "-e", "HEAD:" * source_path; allow_failure=true)
    tree_entry_query = record("ls-tree", "HEAD", "--", source_path; allow_failure=true)
    entry_query = record("ls-files", "--stage", "--", source_path; allow_failure=true)
    flags_query = record("ls-files", "--debug", "--", source_path; allow_failure=true)
    verbose_query = record("ls-files", "-v", "--", source_path; allow_failure=true)
    status_query = record("status", "--porcelain=v1", "--untracked-files=all", "--", source_path; allow_failure=true)
    head_oid = chomp(String(head_query.stdout))
    head_blob_query = record("rev-parse", "--verify", "HEAD:" * source_path; allow_failure=true)
    head_blob_oid = chomp(String(head_blob_query.stdout))
    canonical_query = record("show", "HEAD:" * source_path; as_bytes=true, allow_failure=true)
    raw_path = joinpath(fixture_root, split(source_path, '/')...)
    raw_bytes = _t2fs_kind(raw_path) == "regular_file" ? read(raw_path) : UInt8[]
    canonical_bytes = canonical_query.stdout isa Vector{UInt8} ? canonical_query.stdout : UInt8[]
    raw_key = logical_prefix * "/" * source_path
    head_key = logical_prefix * "/frozen/head/" * replace(source_path, '/' => "__")
    raw_entry = _t2fs_kind(raw_path) == "regular_file" ?
        _t2fs_emit(output_root, raw_key, raw_bytes, "worktree_raw") : nothing
    head_entry = _t2fs_emit(output_root, head_key, canonical_bytes, "head_canonical")
    envelope_entry = binding_envelope === nothing ? nothing : _t2fs_emit(output_root,
        logical_prefix * "/frozen/binding_envelope.json", binding_envelope, "binding_envelope")

    filter_query = record("hash-object", "-w", "--path", source_path, raw_path; allow_failure=true)
    filter_output_query = filter_query.exit_code == 0 ?
        record("cat-file", "blob", chomp(String(filter_query.stdout));
            as_bytes=true, allow_failure=true) : nothing
    filter_output_bytes = filter_output_query !== nothing &&
        filter_output_query.exit_code == 0 && filter_output_query.stdout isa Vector{UInt8} ?
        filter_output_query.stdout : nothing
    filter_status = if filter_output_bytes !== nothing
        filter_query.exit_code == 0 && chomp(String(filter_query.stdout)) == head_blob_oid &&
            filter_output_bytes == canonical_bytes ? "matches" : "mismatch"
    else
        expected_filter in ("startup_failure", "nonzero_failure") ? expected_filter : "mismatch"
    end
    attrs_entry = attributes === nothing ? nothing :
        _t2fs_emit(output_root, logical_prefix * "/frozen/attributes.txt", attributes, "git_attributes")
    recipe_entry = recipe === nothing ? nothing :
        _t2fs_emit(output_root, logical_prefix * "/frozen/filter_recipe.json", recipe, "clean_filter_recipe")
    output_entry = if filter_output_bytes !== nothing
        _t2fs_emit(output_root, logical_prefix * "/frozen/clean_output.bin", filter_output_bytes, "clean_filter_output")
    else
        nothing
    end

    stage_text = String(entry_query.stdout)
    entry_lines = filter(!isempty, split(chomp(stage_text), '\n'))
    exact_entry = findfirst(line -> endswith(line, "\t" * source_path), entry_lines)
    tracked_path = exact_entry === nothing ? nothing : source_path
    stage = exact_entry === nothing ? nothing : tryparse(Int, split(first(split(entry_lines[exact_entry], '\t')), ' ')[3])
    debug_text = String(flags_query.stdout)
    flags_match = match(r"flags: ([0-9a-fA-F]+)", debug_text)
    index_flags = flags_match === nothing ? 0 : tryparse(UInt32, flags_match.captures[1]; base=16)
    verbose_text = String(verbose_query.stdout)
    tree_entry_lines = filter(!isempty, split(chomp(String(tree_entry_query.stdout)), '\n'))
    verbose_entry_lines = filter(!isempty, split(chomp(verbose_text), '\n'))
    verbose_flag_status = occursin(r"(?m)^h\s", verbose_text) ? "assume_unchanged" :
        occursin(r"(?m)^S\s", verbose_text) ? "skip_worktree" :
        verbose_query.exit_code == 0 && !isempty(verbose_text) ? "normal" :
        verbose_query.exit_code == 0 ? "no_entry" : "probe_failed"
    status_text = String(status_query.stdout)
    working_tree_status = status_query.exit_code != 0 ? "probe_failed" : isempty(status_text) ? "clean" :
        occursin("??", status_text) ? "untracked" : "dirty"
    actual_head_oid = bytes2hex(SHA.sha1(vcat(collect(codeunits("blob $(length(canonical_bytes))\0")), canonical_bytes)))
    head_blob_status = head_path_query.exit_code != 0 ? "probe_failed" :
        !(canonical_query.stdout isa Vector{UInt8}) ? "read_failed" :
        length(canonical_bytes) != length(canonical_query.stdout) ? "size_mismatch" :
        actual_head_oid != head_blob_oid ? "bytes_mismatch" : "valid"
    observation_key = logical_prefix * "/frozen/observations/source.json"
    observation = (
        schema=_T2FS_FORMAT, source_path=source_path,
        fixture_case_id=String(fixture_case_id),
        worktree_bytes_key=raw_entry === nothing ? nothing : raw_entry.path,
        worktree_raw_bytes=_t2fs_kind(raw_path) == "regular_file" ? length(raw_bytes) : nothing,
        worktree_raw_sha256=_t2fs_kind(raw_path) == "regular_file" ? _t2fs_sha(raw_bytes) : nothing,
        ad45_envelope_path=binding_envelope === nothing ? nothing : "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json",
        ad45_envelope_bytes_key=binding_envelope === nothing ? nothing : envelope_entry.path,
        root_status=root_query.exit_code == 0 ? "valid" : "invalid",
        head_probe_status=head_query.exit_code == 0 ? "valid" : "failed",
        observed_head=head_query.exit_code == 0 ? head_oid : nothing,
        tree_status=tree_query.exit_code == 0 ? "valid" : "probe_failed",
        tree_entry_count=length(tree_entry_lines),
        tree_entry_path=length(tree_entry_lines) == 1 ? source_path : nothing,
        head_path_status=head_path_query.exit_code == 0 ? "present" : "absent",
        tracked_entry_status=exact_entry === nothing ? "missing" : "stage0",
        tracked_entry_count=length(entry_lines),
        tracked_entry_path=tracked_path, index_stage=stage,
        index_flags=index_flags === nothing ? UInt32(0) : index_flags,
        debug_index_status=flags_query.exit_code == 0 && flags_match !== nothing ? "valid" :
            flags_query.exit_code == 0 ? "malformed" : "probe_failed",
        verbose_flag_status=verbose_flag_status,
        verbose_entry_count=length(verbose_entry_lines),
        working_tree_status=working_tree_status,
        worktree_path_kind=_t2fs_kind(raw_path),
        head_blob_status=head_blob_status,
        head_blob_oid=head_blob_query.exit_code == 0 ? head_blob_oid : nothing,
        head_bytes_key=head_key, head_bytes_bytes=length(canonical_bytes),
        head_bytes_sha256=_t2fs_sha(canonical_bytes),
        filter_status=filter_status,
        filter_input_key=raw_entry === nothing ? nothing : raw_entry.path,
        filter_input_sha256=_t2fs_kind(raw_path) == "regular_file" ? _t2fs_sha(raw_bytes) : nothing,
        attributes_status=attributes === nothing ? "absent" : "present",
        filter_recipe_status=recipe === nothing ? "absent" :
            expected_filter == "startup_failure" ? "startup_failure" :
            expected_filter == "nonzero_failure" ? "nonzero_failure" : "present",
        attributes_key=attrs_entry === nothing ? nothing : attrs_entry.path,
        filter_recipe_key=recipe_entry === nothing ? nothing : recipe_entry.path,
        filter_output_key=output_entry === nothing ? nothing : output_entry.path,
        filter_output_bytes=filter_output_bytes === nothing ? nothing : length(filter_output_bytes),
        filter_output_sha256=output_entry === nothing ? nothing : output_entry.sha256)
    observation_bytes = Vector{UInt8}(codeunits(JSON3.write(observation) * "\n"))
    observation_entry = _t2fs_emit(output_root, observation_key, observation_bytes, "source_observation_v1")
    receipt_path = joinpath(output_root, split(logical_prefix * "/frozen/preparation_receipt.json", '/')...)
    mkpath(dirname(receipt_path))
    receipt_bytes = Vector{UInt8}(codeunits(JSON3.write((schema="t2-frozen-source-preparation-receipt-v1",
        case_id=String(fixture_case_id), mode=String(case_mode),
        availability_status="available", unavailable_reason=nothing,
        fixture_root="isolated_temporary_git_repository", source_key=raw_key,
        commands=captures, emitted=(raw_entry, head_entry, observation_entry,
        envelope_entry, attrs_entry, recipe_entry, output_entry))) * "\n"))
    receipt_entry = _t2fs_emit(output_root,
        logical_prefix * "/frozen/preparation_receipt.json", receipt_bytes,
        "t2_fixture_preparation_receipt_v1")
    (source_key=raw_key, observation_key=observation_key, head_key=head_key,
     receipt_key=receipt_entry.path, observation=observation,
     entries=(raw_entry, head_entry, observation_entry, envelope_entry,
     attrs_entry, recipe_entry, output_entry, receipt_entry))
end

"""
Prepare actual Git fixture rows before creating the formal source snapshot.

`output_root` is a workspace directory whose files must be added to the root-
authorized FrozenInputSnapshot manifest after this function succeeds. The
returned rows are a preparation inventory, never T2 execution credit.
"""
function prepare_frozen_source_fixtures!(repository_root::AbstractString,
        output_root::AbstractString)
    inherited_git_keys = sort!(String[key for key in keys(ENV) if
        startswith(uppercase(String(key)), "GIT_")])
    isempty(inherited_git_keys) ||
        throw(ArgumentError("fixture preparation requires an environment without inherited GIT_* variables: $(join(inherited_git_keys, ", "))"))
    any(key -> haskey(ENV, key),
        ("FUSION_T2_FROZEN_SNAPSHOT_ID", "FUSION_T2_FROZEN_MANIFEST_SHA256",
         "FUSION_T2_FROZEN_PROTOCOL_SHA256", "FUSION_T2_FROZEN_PROTOCOL_PATH",
         "FUSION_T2_FROZEN_QUERY_AUDIT_PATH")) &&
        throw(ArgumentError("fixture Git preparation must finish before formal T2 freeze pins are set"))
    repo_root = realpath(String(repository_root))
    target_root = abspath(String(output_root))
    normpath(target_root) == normpath(repo_root) ||
        throw(ArgumentError("fixture output root must equal the source snapshot root"))
    mkpath(target_root)
    specifications = (
        ("g1_clean", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :none),
        ("g1_autocrlf", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :autocrlf),
        ("g1_autocrlf_dirty", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :autocrlf_dirty),
        ("g1_filter", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :clean_filter),
        ("g1_filter_dirty", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :filter_dirty),
        ("g1_dirty", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :dirty),
        ("g1_assume_unchanged", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :assume_unchanged),
        ("g1_skip_worktree", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :skip_worktree),
        ("g1_filter_startup_failure", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :filter_startup_failure),
        ("g1_filter_nonzero_failure", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :filter_nonzero_failure),
        ("g1_empty_git_dir", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :empty_git_dir),
        ("g1_head_absent", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :head_absent),
        ("g1_untracked", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :untracked),
        ("g1_missing", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :missing),
        ("g1_directory", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :directory),
        ("g1_symlink", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :symlink),
        ("g2_clean", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :none),
        ("g2_autocrlf", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :autocrlf),
        ("g2_autocrlf_dirty", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :autocrlf_dirty),
        ("g2_filter", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :clean_filter),
        ("g2_filter_dirty", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :filter_dirty),
        ("g2_dirty", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :dirty),
        ("g2_assume_unchanged", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :assume_unchanged),
        ("g2_skip_worktree", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :skip_worktree),
        ("g2_filter_startup_failure", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :filter_startup_failure),
        ("g2_filter_nonzero_failure", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :filter_nonzero_failure),
        ("g2_empty_git_dir", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :empty_git_dir),
        ("g2_head_absent", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :head_absent),
        ("g2_untracked", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :untracked),
        ("g2_missing", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :missing),
        ("g2_directory", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :directory),
        ("g3_realization_clean", "src/GenomeV5/G3/RealizationGenomeV5.jl", :none),
        ("g3_realization_autocrlf", "src/GenomeV5/G3/RealizationGenomeV5.jl", :autocrlf),
        ("g3_realization_autocrlf_dirty", "src/GenomeV5/G3/RealizationGenomeV5.jl", :autocrlf_dirty),
        ("g3_realization_filter", "src/GenomeV5/G3/RealizationGenomeV5.jl", :clean_filter),
        ("g3_realization_filter_dirty", "src/GenomeV5/G3/RealizationGenomeV5.jl", :filter_dirty),
        ("g3_realization_dirty", "src/GenomeV5/G3/RealizationGenomeV5.jl", :dirty),
        ("g3_realization_assume_unchanged", "src/GenomeV5/G3/RealizationGenomeV5.jl", :assume_unchanged),
        ("g3_realization_skip_worktree", "src/GenomeV5/G3/RealizationGenomeV5.jl", :skip_worktree),
        ("g3_realization_filter_startup_failure", "src/GenomeV5/G3/RealizationGenomeV5.jl", :filter_startup_failure),
        ("g3_realization_filter_nonzero_failure", "src/GenomeV5/G3/RealizationGenomeV5.jl", :filter_nonzero_failure),
        ("g3_realization_empty_git_dir", "src/GenomeV5/G3/RealizationGenomeV5.jl", :empty_git_dir),
        ("g3_realization_head_absent", "src/GenomeV5/G3/RealizationGenomeV5.jl", :head_absent),
        ("g3_realization_untracked", "src/GenomeV5/G3/RealizationGenomeV5.jl", :untracked),
        ("g3_realization_missing", "src/GenomeV5/G3/RealizationGenomeV5.jl", :missing),
        ("g3_realization_directory", "src/GenomeV5/G3/RealizationGenomeV5.jl", :directory),
        ("g3_control_clean", "src/GenomeV5/G3/ControlGenomeV5.jl", :none),
        ("g3_binding_clean", "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl", :none),
        ("g3_bundle_clean", "src/GenomeV5/G3/RealizationControlGenomeV5.jl", :none),
        ("g3_control_assume_unchanged", "src/GenomeV5/G3/ControlGenomeV5.jl", :assume_unchanged),
        ("g3_control_skip_worktree", "src/GenomeV5/G3/ControlGenomeV5.jl", :skip_worktree),
        ("g3_feedback_clean", "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl", :none),
        ("t0_source_edit", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", :source_edit),
    )
    rows = NamedTuple[]
    for (case_id, source_path, mode) in specifications
        captures = NamedTuple[]
        temp_root = mktempdir()
        case_root = joinpath(temp_root, "fixture")
        mkpath(case_root)
        bytes = read(joinpath(repo_root, split(source_path, '/')...))
        envelope_relative = "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
        envelope_bytes = read(joinpath(repo_root, split(envelope_relative, '/')...))
        attrs = nothing
        recipe = nothing
        filter_kind = "not_applicable"
        filter_mode = mode in (:clean_filter, :filter_dirty, :filter_startup_failure, :filter_nonzero_failure)
        if filter_mode
            marker = Vector{UInt8}(codeunits("\n# FCA-T2-PREFREEZE-CLEAN-MARKER\n"))
            append!(bytes, marker)
            attrs = Vector{UInt8}(codeunits(source_path * " filter=" * _T2FS_FILTER_NAME * "\n"))
            script = Vector{UInt8}(codeunits(_T2FS_FILTER_SOURCE))
            filter_path = joinpath(case_root, "clean_filter.py")
            write(filter_path, script)
            python = Sys.which("python")
            python isa AbstractString && !isempty(python) || error("Python is required for pre-freeze filter fixtures")
            python_executable = realpath(String(python))
            missing_filter = joinpath(case_root, "missing-fca-filter.exe")
            recipe = Vector{UInt8}(codeunits(JSON3.write((schema="t2-clean-filter-recipe-v1",
                script_source=String(script), script_sha256=_t2fs_sha(script),
                python_executable=python_executable,
                clean_argv=[python_executable, "-B", "clean_filter.py", "clean"],
                startup_failure_argv=[missing_filter, "-B", "clean_filter.py", "clean"],
                nonzero_argv=[python_executable, "-B", "clean_filter.py", "nonzero-failure"])) * "\n"))
            filter_kind = mode === :filter_startup_failure ? "startup_failure" :
                mode === :filter_nonzero_failure ? "nonzero_failure" : "matches"
        end
        logical_prefix = "test/fixtures/t2_source_authority/cases/" * case_id
        relative_fixture_path = logical_prefix * "/" * source_path
        destination = joinpath(case_root, split(source_path, '/')...)
        mkpath(dirname(destination))
        envelope_destination = joinpath(case_root, split(envelope_relative, '/')...)
        mkpath(dirname(envelope_destination))
        if mode === :symlink
            target = joinpath(case_root, "outside_source.txt")
            write(target, bytes)
            try
                symlink(target, destination)
            catch err
                _t2fs_is_optional_symlink_capability_error(err) || throw(err)
                receipt_entry = _t2fs_unavailable_symlink_receipt!(target_root,
                    logical_prefix, case_id, destination, err)
                rm(temp_root; recursive=true, force=true)
                push!(rows, (case_id=case_id, mode=String(mode),
                    availability_status="platform_unavailable",
                    unavailable_reason=(operation="symlink",
                        exception_type=string(typeof(err)),
                        exception_code=Int(getproperty(err, :code)),
                        error_text=sprint(showerror, err)),
                    source_key=nothing, observation_key=nothing, head_key=nothing,
                    receipt_key=receipt_entry.path, emitted=(receipt_entry,)))
                continue
            end
        elseif !(mode in (:missing, :directory))
            write(destination, bytes)
        elseif mode === :directory
            mkpath(destination)
            write(joinpath(destination, "child.txt"), "directory fixture\n")
        end
        write(envelope_destination, envelope_bytes)
        _t2fs_git(case_root, "init", "-q"; command_log=captures)
        _t2fs_git(case_root, "config", "user.email", "t2-frozen-fixture@example.invalid"; command_log=captures)
        _t2fs_git(case_root, "config", "user.name", "T2 frozen fixture preparation"; command_log=captures)
        _t2fs_git(case_root, "config", "core.autocrlf",
            mode in (:autocrlf, :autocrlf_dirty) ? "true" : "false"; command_log=captures)
        if filter_mode
            write(joinpath(case_root, ".gitattributes"), attrs)
            _t2fs_git(case_root, "config", "filter.$_T2FS_FILTER_NAME.clean",
                _t2fs_shell_quote(python_executable) * " -B clean_filter.py clean"; command_log=captures)
            _t2fs_git(case_root, "config", "filter.$_T2FS_FILTER_NAME.required", "true"; command_log=captures)
            _t2fs_git(case_root, "add", "--all"; command_log=captures)
        elseif mode in (:head_absent, :untracked, :missing, :directory)
            unrelated = joinpath(case_root, "fixture-control.txt")
            write(unrelated, "control row for $(case_id)\n")
            _t2fs_git(case_root, "add", "--", "fixture-control.txt"; command_log=captures)
        else
            _t2fs_git(case_root, "add", "--all"; command_log=captures)
        end
        _t2fs_git(case_root, "commit", "-m", "T2 pre-freeze fixture $case_id"; command_log=captures)
        mode in (:autocrlf, :autocrlf_dirty) &&
            _t2fs_git(case_root, "checkout", "--", source_path; command_log=captures)
        if mode === :source_edit
            open(destination, "a") do io
                write(io, UInt8[0x0a, 0x23, 0x20, 0x52, 0x38, 0x2d, 0x65, 0x64, 0x69, 0x74])
            end
        elseif mode in (:dirty, :autocrlf_dirty, :filter_dirty)
            open(destination, "a") do io
                write(io, "\n# FCA-T2-PREFREEZE-DIRTY\n")
            end
        elseif mode === :assume_unchanged || mode === :skip_worktree
            open(destination, "a") do io
                write(io, "\n# FCA-T2-PREFREEZE-INDEX-FLAG\n")
            end
            flag = mode === :assume_unchanged ? "--assume-unchanged" : "--skip-worktree"
            _t2fs_git(case_root, "update-index", flag, "--", source_path; command_log=captures)
        elseif mode === :filter_startup_failure
            missing_filter = joinpath(case_root, "missing-fca-filter.exe")
            _t2fs_git(case_root, "config", "filter.$_T2FS_FILTER_NAME.clean",
                _t2fs_shell_quote(missing_filter) * " -B clean_filter.py clean"; command_log=captures)
        elseif mode === :filter_nonzero_failure
            _t2fs_git(case_root, "config", "filter.$_T2FS_FILTER_NAME.clean",
                _t2fs_shell_quote(python_executable) * " -B clean_filter.py nonzero-failure"; command_log=captures)
        end
        observations = _t2fs_observe!(target_root, case_root, logical_prefix, case_id,
            source_path, captures; case_mode=String(mode),
            binding_envelope=envelope_bytes, attributes=attrs, recipe=recipe,
            expected_filter=filter_kind, empty_git_dir_probe=mode === :empty_git_dir)
        rm(temp_root; recursive=true, force=true)
        push!(rows, (case_id=case_id, mode=String(mode),
            availability_status="available", unavailable_reason=nothing,
            source_key=observations.source_key,
            observation_key=observations.observation_key, head_key=observations.head_key,
            receipt_key=observations.receipt_key, emitted=observations.entries))
    end
    case_ids = String[row.case_id for row in rows]
    length(unique(case_ids)) == length(case_ids) ||
        throw(ArgumentError("frozen fixture case ids are not unique"))
    entries = NamedTuple[]
    for row in rows, entry in row.emitted
        entry === nothing || push!(entries, entry)
    end
    sort!(entries; by=entry -> String(entry.path))
    logical_paths = String[String(entry.path) for entry in entries]
    length(unique(logical_paths)) == length(logical_paths) ||
        throw(ArgumentError("frozen fixture output logical paths collide"))
    preparer_path = abspath(String(@__FILE__))
    preparer_relative = replace(relpath(preparer_path, repo_root), '\\' => '/')
    preparer_bytes = read(preparer_path)
    inventory = (schema="t2-frozen-source-fixture-inventory-v1",
        logical_prefix="test/fixtures/t2_source_authority",
        source_input_root=repo_root, producer_script_key=preparer_relative,
        producer_script_bytes=length(preparer_bytes),
        producer_script_sha256=_t2fs_sha(preparer_bytes),
        producer_invocation_receipt_key=
            "runs/e/t2_frozen_source_fixtures_20260928_r1/producer_invocation_receipt.json",
        case_count=length(rows), case_ids=case_ids,
        cases=[(case_id=row.case_id, mode=row.mode,
            availability_status=row.availability_status,
            unavailable_reason=row.unavailable_reason,
            source_key=row.source_key,
            observation_key=row.observation_key, head_key=row.head_key,
            receipt_key=row.receipt_key) for row in rows],
        entry_count=length(entries), entries=entries)
    inventory_bytes = Vector{UInt8}(codeunits(JSON3.write(inventory) * "\n"))
    inventory_entry = _t2fs_emit(target_root,
        "test/fixtures/t2_source_authority/fixture_inventory.json",
        inventory_bytes, "t2_fixture_inventory_v1")
    (inventory=inventory, inventory_entry=inventory_entry, cases=rows,
        entries=entries)
end

end # module T2FrozenSourceFixturePreparationV1
