if !isdefined(@__MODULE__, :ManagedExternalProcessV1)
    Base.include(@__MODULE__, joinpath(@__DIR__, "ManagedExternalProcessV1.jl"))
end

module NativeGitReadCompatibilityV1

using LibGit2
using SHA
using JSON3
using TOML
using Unicode
import ..ManagedExternalProcessV1

export capture_git, with_repo, open_repository, repository_root, head_oid, head_snapshot,
       head_blob, index_rows, git_text, git_bytes,
       FrozenSourceAuthorizationV1, FrozenSourceInputV1, FrozenSourceObservationV1,
       FrozenSourceContextV1, UP1FrozenSourceContextV1, register_frozen_source!, register_frozen_observation!,
       register_frozen_archive!, frozen_source, frozen_archive, frozen_observation,
       frozen_source_validation, frozen_source_identity, frozen_source_manifest_key,
       frozen_source_candidate_ref,
       activate_up1_frozen_runtime!, up1_frozen_runtime_active,
       up1_frozen_runtime_git_attempts, up1_frozen_runtime_git_audit,
       runtime_git_query_audit, write_frozen_query_audit,
       initialize_frozen_runtime!

const _FROZEN_SNAPSHOT_ENV = "FUSION_T2_FROZEN_SNAPSHOT_ID"
const _FROZEN_MANIFEST_ENV = "FUSION_T2_FROZEN_MANIFEST_SHA256"
const _FROZEN_PROTOCOL_ENV = "FUSION_T2_FROZEN_PROTOCOL_SHA256"
const _FROZEN_PROTOCOL_PATH_ENV = "FUSION_T2_FROZEN_PROTOCOL_PATH"
const _FROZEN_QUERY_AUDIT_ENV = "FUSION_T2_FROZEN_QUERY_AUDIT_PATH"
const _FROZEN_AUTH_ENV_KEYS = (_FROZEN_SNAPSHOT_ENV, _FROZEN_MANIFEST_ENV, _FROZEN_PROTOCOL_ENV)
const _RUNTIME_AUDIT_REGISTRY = Ref{Any}(nothing)
const _RUNTIME_AUDIT_LOCK = ReentrantLock()
const _RUNTIME_AUDIT = Dict{String,Any}(
    "module_id" => nothing,
    "process_id" => getpid(),
    "protocol_sha256" => nothing,
    "manifest_sha256" => nothing,
    "inventory_root_sha256" => nothing,
    "snapshot_id" => nothing,
    "source_root" => nothing,
    "verified_context_count" => 0,
    "denied_legacy_api_attempts" => String[],
    "actual_cli_launches" => 0,
    "actual_native_repository_reads" => 0,
)
const _RUNTIME_AUDIT_INSTANCE_ID = Ref{Union{Nothing,String}}(nothing)
const _RUNTIME_AUDIT_REGISTERED = Ref(false)
const _RUNTIME_AUDIT_ATEXIT_REGISTERED = Ref(false)
const _RUNTIME_BOOTSTRAP_CONTEXT = Ref{Any}(nothing)
const _RUNTIME_BOOTSTRAP_COMPLETED = Ref(false)
const _UP1_FROZEN_RUNTIME_ACTIVE = Ref(false)
const _UP1_FROZEN_RUNTIME_IDENTITY = Ref{Any}(nothing)
const _UP1_GIT_ATTEMPTS = Ref(0)
const _UP1_GIT_DENIALS = Vector{NamedTuple{(:api_name, :identity),Tuple{String,Any}}}()
const _UP1_GUARD_LOCK = ReentrantLock()

function _runtime_audit_registry!()
    if !isdefined(Main, :FUSION_T2_NATIVE_AUDIT_REGISTRY_V1)
        Core.eval(Main, :(const FUSION_T2_NATIVE_AUDIT_REGISTRY_V1 =
            (lock=ReentrantLock(), modules=Any[], next_id=Ref(0))))
    end
    registry = getfield(Main, :FUSION_T2_NATIVE_AUDIT_REGISTRY_V1)
    if !_RUNTIME_AUDIT_REGISTERED[] || _RUNTIME_AUDIT_REGISTRY[] !== registry
        lock(registry.lock) do
            registry.next_id[] += 1
            instance_id = string(@__MODULE__, "#", getpid(), "#", registry.next_id[])
            _RUNTIME_AUDIT_INSTANCE_ID[] = instance_id
            _RUNTIME_AUDIT["module_id"] = instance_id
            _RUNTIME_AUDIT["process_id"] = getpid()
            push!(registry.modules, (module_id=instance_id, process_id=getpid(),
                state=_RUNTIME_AUDIT, state_lock=_RUNTIME_AUDIT_LOCK))
        end
        _RUNTIME_AUDIT_REGISTRY[] = registry
        _RUNTIME_AUDIT_REGISTERED[] = true
    end
    registry
end

function _frozen_env_present()
    _frozen_formal_runtime_requested()
end

function _guard_legacy_git_access(api_name::AbstractString="unknown_legacy_api")
    if _UP1_FROZEN_RUNTIME_ACTIVE[]
        lock(_UP1_GUARD_LOCK) do
            _UP1_GIT_ATTEMPTS[] += 1
            push!(_UP1_GIT_DENIALS, (api_name=String(api_name),
                identity=_UP1_FROZEN_RUNTIME_IDENTITY[]))
        end
        throw(ArgumentError("Git access is forbidden while the UP1 frozen runtime is active"))
    end
    if _frozen_env_present()
        _runtime_audit_registry!()
        lock(_RUNTIME_AUDIT_LOCK) do
            push!(_RUNTIME_AUDIT["denied_legacy_api_attempts"], String(api_name))
        end
        throw(ArgumentError("Git access is forbidden while formal frozen source pins are present"))
    end
    nothing
end

function _record_native_repository_read!()
    _runtime_audit_registry!()
    lock(_RUNTIME_AUDIT_LOCK) do
        _RUNTIME_AUDIT["actual_native_repository_reads"] += 1
    end
    nothing
end

function _record_cli_launch!()
    _runtime_audit_registry!()
    lock(_RUNTIME_AUDIT_LOCK) do
        _RUNTIME_AUDIT["actual_cli_launches"] += 1
    end
    nothing
end

function _record_verified_context!(authorization)
    _runtime_audit_registry!()
    lock(_RUNTIME_AUDIT_LOCK) do
        identity = (authorization.protocol_sha256, authorization.manifest_sha256,
            authorization.inventory_root_sha256, authorization.snapshot_id,
            authorization.source_root)
        previous = (_RUNTIME_AUDIT["protocol_sha256"], _RUNTIME_AUDIT["manifest_sha256"],
            _RUNTIME_AUDIT["inventory_root_sha256"], _RUNTIME_AUDIT["snapshot_id"],
            _RUNTIME_AUDIT["source_root"])
        previous == (nothing, nothing, nothing, nothing, nothing) || previous == identity ||
            throw(ArgumentError("runtime query audit cannot combine different frozen authorities"))
        _RUNTIME_AUDIT["protocol_sha256"] = authorization.protocol_sha256
        _RUNTIME_AUDIT["manifest_sha256"] = authorization.manifest_sha256
        _RUNTIME_AUDIT["inventory_root_sha256"] = authorization.inventory_root_sha256
        _RUNTIME_AUDIT["snapshot_id"] = authorization.snapshot_id
        _RUNTIME_AUDIT["source_root"] = authorization.source_root
        _RUNTIME_AUDIT["verified_context_count"] += 1
    end
    nothing
end

function runtime_git_query_audit()
    registry = _runtime_audit_registry!()
    modules = lock(registry.lock) do
        copy(registry.modules)
    end
    rows = map(modules) do module_record
        lock(module_record.state_lock) do
            state = module_record.state
            Dict{String,Any}(
                "module_id" => module_record.module_id,
                "process_id" => module_record.process_id,
                "protocol_sha256" => state["protocol_sha256"],
                "manifest_sha256" => state["manifest_sha256"],
                "inventory_root_sha256" => state["inventory_root_sha256"],
                "snapshot_id" => state["snapshot_id"],
                "source_root" => state["source_root"],
                "verified_context_count" => state["verified_context_count"],
                "denied_legacy_api_attempts" => copy(state["denied_legacy_api_attempts"]),
                "actual_cli_launches" => state["actual_cli_launches"],
                "actual_native_repository_reads" => state["actual_native_repository_reads"],
            )
        end
    end
    _aggregate_runtime_audit(rows)
end

function _aggregate_runtime_audit(rows)
    identities = filter(row -> row["verified_context_count"] > 0, rows)
    pins = unique(collect((row["protocol_sha256"], row["manifest_sha256"],
        row["inventory_root_sha256"], row["snapshot_id"], row["source_root"]) for row in identities))
    length(pins) <= 1 || throw(ArgumentError("runtime query audit contains foreign frozen authorities"))
    identity = isempty(pins) ? (nothing, nothing, nothing, nothing, nothing) : first(pins)
    (protocol, manifest, inventory, snapshot, source_root) = identity
    Dict{String,Any}(
        "schema" => "fusion-t2-runtime-git-query-audit-v1",
        "protocol_sha256" => protocol,
        "manifest_sha256" => manifest,
        "inventory_root_sha256" => inventory,
        "snapshot_id" => snapshot,
        "verified_context_count" => sum(Int(row["verified_context_count"]) for row in rows; init=0),
        "denied_legacy_api_attempts" => reduce(vcat,
            (String.(row["denied_legacy_api_attempts"]) for row in rows); init=String[]),
        "actual_cli_launches" => sum(Int(row["actual_cli_launches"]) for row in rows; init=0),
        "actual_native_repository_reads" => sum(Int(row["actual_native_repository_reads"]) for row in rows; init=0),
        "source_root" => source_root,
        "modules" => rows,
    )
end

function _merge_runtime_audit_file(current, target)
    isfile(target) || return current
    prior = try JSON3.read(read(target), Dict{String,Any}) catch
        throw(ArgumentError("existing runtime query audit is unreadable or malformed"))
    end
    prior["schema"] == "fusion-t2-runtime-git-query-audit-v1" ||
        throw(ArgumentError("existing runtime query audit has a foreign schema"))
    for key in ("protocol_sha256", "manifest_sha256", "inventory_root_sha256", "snapshot_id", "source_root")
        prior[key] == current[key] || throw(ArgumentError("existing runtime query audit has foreign pins"))
    end
    rows = Dict{String,Any}()
    for row in prior["modules"]
        key = string(row["process_id"], "/", row["module_id"])
        rows[key] = Dict{String,Any}(String(k) => v for (k, v) in row)
    end
    for row in current["modules"]
        key = string(row["process_id"], "/", row["module_id"])
        rows[key] = row
    end
    merged = _aggregate_runtime_audit(collect(values(rows)))
    merged["protocol_sha256"] == current["protocol_sha256"] ||
        throw(ArgumentError("merged runtime query audit changed protocol pin"))
    merged
end

function _audit_is_within(path::AbstractString, root::AbstractString)
    relative = try relpath(normpath(path), normpath(root)) catch
        throw(ArgumentError("audit path must share the snapshot filesystem root"))
    end
    parts = splitpath(relative)
    isempty(parts) || first(parts) != ".."
end

function _audit_path_identity(path::AbstractString)
    value = normpath(String(path))
    Sys.iswindows() ? lowercase(value) : value
end

function _audit_path_outside_snapshot(path::AbstractString, source_root::AbstractString)
    absolute = normpath(abspath(String(path)))
    root = normpath(realpath(abspath(String(source_root))))
    _audit_is_within(absolute, root) &&
        throw(ArgumentError("runtime query audit path must be outside the frozen snapshot"))
    cursor = first(splitpath(absolute))
    for component in splitpath(absolute)[2:end]
        cursor = joinpath(cursor, component)
        (islink(cursor) || ispath(cursor)) || continue
        islink(cursor) && throw(ArgumentError("runtime query audit path contains a symlink or reparse point"))
        physical = realpath(cursor)
        _audit_path_identity(physical) == _audit_path_identity(cursor) ||
            throw(ArgumentError("runtime query audit path contains a non-canonical reparse component"))
        _audit_is_within(physical, root) &&
            throw(ArgumentError("runtime query audit path resolves inside the frozen snapshot"))
    end
    if islink(absolute) || ispath(absolute)
        islink(absolute) && throw(ArgumentError("runtime query audit target is a symlink or reparse point"))
        isfile(absolute) || throw(ArgumentError("runtime query audit target is not a regular file"))
        info = stat(absolute)
        hasproperty(info, :nlink) && getproperty(info, :nlink) == 1 ||
            throw(ArgumentError("runtime query audit target must have one hard link"))
        _audit_path_identity(realpath(absolute)) == _audit_path_identity(absolute) ||
            throw(ArgumentError("runtime query audit target has a non-canonical reparse path"))
        _audit_is_within(realpath(absolute), root) &&
            throw(ArgumentError("runtime query audit target resolves inside the frozen snapshot"))
    end
    absolute
end

function _write_runtime_audit_atomic(target::AbstractString, audit, source_root::AbstractString)
    result = merge(audit, Dict{String,Any}(
        "flush_succeeded" => true,
        "fsync_attempted" => false,
        "fsync_succeeded" => false,
        "close_succeeded" => true,
    ))
    temporary, io = mktemp(dirname(target); cleanup=false)
    try
        _audit_path_outside_snapshot(temporary, source_root)
        JSON3.write(io, result)
        flush(io)
        close(io)
        _audit_path_outside_snapshot(temporary, source_root)
        info = stat(temporary)
        hasproperty(info, :nlink) && getproperty(info, :nlink) == 1 ||
            throw(ArgumentError("runtime query audit temporary file is aliased"))
        _audit_path_outside_snapshot(target, source_root)
        mv(temporary, target; force=true)
        nothing
    catch
        isopen(io) && close(io)
        ispath(temporary) && rm(temporary; force=true)
        rethrow()
    end
    result
end

function write_frozen_query_audit(path::AbstractString=get(ENV, _FROZEN_QUERY_AUDIT_ENV, ""))
    isempty(path) && throw(ArgumentError("runtime query audit output path is not configured"))
    audit = runtime_git_query_audit()
    root = audit["source_root"]
    root isa String || throw(ArgumentError("runtime query audit has no verified frozen context"))
    target = _audit_path_outside_snapshot(path, root)
    mkpath(dirname(target))
    target = _audit_path_outside_snapshot(target, root)
    audit = _merge_runtime_audit_file(audit, target)
    _write_runtime_audit_atomic(target, audit, root)
end

function _register_runtime_audit_atexit!()
    if !_RUNTIME_AUDIT_ATEXIT_REGISTERED[]
        _RUNTIME_AUDIT_ATEXIT_REGISTERED[] = true
        atexit() do
            path = get(ENV, _FROZEN_QUERY_AUDIT_ENV, "")
            isempty(path) || write_frozen_query_audit(path)
        end
    end
    nothing
end

struct FrozenSourcePinV1
    role::String
    bytes::Int
    sha256::String
end

struct FrozenSourceAuthorizationV1
    protocol_sha256::String
    source_root::String
    manifest_path::String
    manifest_bytes::Int
    manifest_sha256::String
    inventory_root_sha256::String
    snapshot_id::String
    expected_entries::Dict{String,FrozenSourcePinV1}
    expected_external_archives::Dict{String,FrozenSourcePinV1}
end

function _validate_frozen_environment!(authorization::Union{Nothing,FrozenSourceAuthorizationV1}=nothing)
    present = map(key -> haskey(ENV, key), _FROZEN_AUTH_ENV_KEYS)
    any(present) || return false
    all(present) || throw(ArgumentError("formal frozen source environment pins are incomplete"))
    values = map(key -> String(ENV[key]), _FROZEN_AUTH_ENV_KEYS)
    all(value -> occursin(r"^[0-9a-f]{64}$", value), values) ||
        throw(ArgumentError("formal frozen source environment pins are malformed"))
    if authorization !== nothing
        values == [authorization.snapshot_id, authorization.manifest_sha256,
                   authorization.protocol_sha256] ||
            throw(ArgumentError("formal frozen source environment pins differ from authorization"))
    end
    true
end

function _frozen_hash_text(value, field)
    value isa AbstractString && occursin(r"^[0-9a-f]{64}$", value) ||
        throw(ArgumentError("$(field) must be lowercase SHA-256 hex"))
    String(value)
end

function _frozen_logical_path(value, field)
    value isa AbstractString || throw(ArgumentError("$(field) must be text"))
    path = String(value)
    (isempty(path) || isabspath(path) || occursin('\0', path) || occursin('\\', path) || occursin(':', path) ||
        any(part -> part in ("", ".", ".."), split(path, '/'))) &&
        throw(ArgumentError("$(field) must be a canonical root-relative path"))
    portable_invalid = Unicode.normalize(path; compat=true, compose=true) != path ||
        any(part -> endswith(part, " ") || endswith(part, ".") ||
            any(char -> char in "<>|?*" || UInt32(char) < 0x20 || UInt32(char) == 0x7f, part) ||
            uppercase(first(split(part, '.'; limit=2))) in
                ("CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"),
            split(path, '/'))
    portable_invalid && throw(ArgumentError("$(field) is not a portable canonical path"))
    path
end

_frozen_alias_key(path::AbstractString) = Unicode.normalize(String(path); compat=true, compose=true, casefold=true)

function _frozen_pin_map(value, field)
    value isa AbstractDict || throw(ArgumentError("$(field) must be a path-to-pin map"))
    result = Dict{String,FrozenSourcePinV1}()
    aliases = Set{String}()
    for (raw_path, raw_pin) in value
        path = _frozen_logical_path(raw_path, field)
        folded = _frozen_alias_key(path)
        folded in aliases && throw(ArgumentError("$(field) repeats an aliased logical path"))
        push!(aliases, folded)
        raw_pin isa AbstractDict || raw_pin isa NamedTuple ||
            throw(ArgumentError("$(field) pin must be a record"))
        role = raw_pin isa NamedTuple ? getproperty(raw_pin, :role) : raw_pin["role"]
        bytes = raw_pin isa NamedTuple ? getproperty(raw_pin, :bytes) : raw_pin["bytes"]
        sha = raw_pin isa NamedTuple ? getproperty(raw_pin, :sha256) : raw_pin["sha256"]
        role isa AbstractString && !isempty(role) || throw(ArgumentError("$(field) role is invalid"))
        bytes isa Integer && !(bytes isa Bool) && bytes >= 0 ||
            throw(ArgumentError("$(field) byte count is invalid"))
        result[path] = FrozenSourcePinV1(String(role), Int(bytes), _frozen_hash_text(sha, field))
    end
    result
end

function FrozenSourceAuthorizationV1(protocol_sha256, source_snapshot)
    snapshot = source_snapshot
    getter(key) = snapshot isa NamedTuple ? getproperty(snapshot, Symbol(key)) : snapshot[key]
    _frozen_hash_text(protocol_sha256, "protocol SHA-256")
    getter("schema") == "fusion-t2-frozen-input-snapshot-v1" ||
        throw(ArgumentError("unsupported frozen source snapshot schema"))
    root = getter("source_root")
    root isa AbstractString && isabspath(root) || throw(ArgumentError("snapshot source_root must be absolute"))
    manifest_path = getter("manifest_path")
    manifest_path == "manifest.toml" || throw(ArgumentError("snapshot manifest_path must be manifest.toml"))
    manifest_bytes = getter("manifest_bytes")
    manifest_bytes isa Integer && !(manifest_bytes isa Bool) && manifest_bytes > 0 ||
        throw(ArgumentError("snapshot manifest_bytes must be positive"))
    manifest_sha = _frozen_hash_text(getter("manifest_sha256"), "manifest SHA-256")
    inventory = _frozen_hash_text(getter("inventory_root_sha256"), "inventory root SHA-256")
    snapshot_id = getter("snapshot_id")
    snapshot_id == inventory || throw(ArgumentError("snapshot id differs from inventory root"))
    entries = _frozen_pin_map(getter("expected_entries"), "expected_entries")
    archives = _frozen_pin_map(getter("expected_external_archives"), "expected_external_archives")
    isempty(entries) && isempty(archives) &&
        throw(ArgumentError("frozen source snapshot closure is empty"))
    authorization = FrozenSourceAuthorizationV1(String(protocol_sha256), String(root), String(manifest_path),
        Int(manifest_bytes), manifest_sha, inventory, String(snapshot_id), entries, archives)
    _validate_frozen_environment!(authorization)
    authorization
end

function _same_frozen_pin_map(left, right)
    Set(keys(left)) == Set(keys(right)) || return false
    all(key -> left[key].role == right[key].role && left[key].bytes == right[key].bytes &&
        left[key].sha256 == right[key].sha256, keys(left))
end

function _same_frozen_authorization(left::FrozenSourceAuthorizationV1,
        right::FrozenSourceAuthorizationV1)
    left.protocol_sha256 == right.protocol_sha256 && left.source_root == right.source_root &&
        left.manifest_path == right.manifest_path && left.manifest_bytes == right.manifest_bytes &&
        left.manifest_sha256 == right.manifest_sha256 &&
        left.inventory_root_sha256 == right.inventory_root_sha256 &&
        left.snapshot_id == right.snapshot_id &&
        _same_frozen_pin_map(left.expected_entries, right.expected_entries) &&
        _same_frozen_pin_map(left.expected_external_archives, right.expected_external_archives)
end

function _authorization_from_protocol_bytes(raw::Vector{UInt8}, expected_protocol_sha256::AbstractString)
    actual_sha256 = bytes2hex(SHA.sha256(raw))
    actual_sha256 == expected_protocol_sha256 ||
        throw(ArgumentError("outer protocol raw-byte SHA-256 differs from authorization"))
    parsed = try JSON3.read(String(raw), Dict{String,Any}) catch err
        throw(ArgumentError("outer protocol is invalid JSON: $(typeof(err))"))
    end
    snapshots = Any[]
    haskey(parsed, "source_snapshot") && push!(snapshots, parsed["source_snapshot"])
    nested_snapshot = try parsed["consumer"]["protocol"]["source_snapshot"] catch; nothing end
    nested_snapshot === nothing || push!(snapshots, nested_snapshot)
    isempty(snapshots) && throw(ArgumentError("outer protocol lacks source_snapshot"))
    authorizations = map(snapshot -> FrozenSourceAuthorizationV1(actual_sha256, snapshot), snapshots)
    all(authorization -> _same_frozen_authorization(first(authorizations), authorization),
        authorizations) ||
        throw(ArgumentError("outer protocol source_snapshot locations disagree"))
    first(authorizations)
end

function _verify_frozen_protocol_record!(authorization::FrozenSourceAuthorizationV1,
        source_root::AbstractString)
    protocol_path = get(ENV, _FROZEN_PROTOCOL_PATH_ENV, "")
    isempty(protocol_path) && throw(ArgumentError("authorized outer protocol path is not configured"))
    isabspath(protocol_path) || throw(ArgumentError("authorized outer protocol path must be absolute"))
    absolute = _audit_path_outside_snapshot(protocol_path, source_root)
    isfile(absolute) || throw(ArgumentError("authorized outer protocol file is missing"))
    islink(absolute) && throw(ArgumentError("authorized outer protocol file is a symlink/reparse file"))
    realpath(absolute) == absolute || throw(ArgumentError("authorized outer protocol path is not canonical"))
    raw = read(absolute)
    actual_authorization = _authorization_from_protocol_bytes(raw, authorization.protocol_sha256)
    _same_frozen_authorization(authorization, actual_authorization) ||
        throw(ArgumentError("outer protocol source snapshot differs from context authorization"))
    nothing
end

struct FrozenSourceInputV1
    logical_path::String
    manifest_key::String
    fixture_case_id::Union{Nothing,String}
    role::String
    bytes::Vector{UInt8}
    byte_count::Int
    sha256::String
end

struct FrozenSourceObservationV1
    source_path::String
    fixture_case_id::Union{Nothing,String}
    worktree_bytes_key::Union{Nothing,String}
    worktree_raw_bytes::Union{Nothing,Int}
    worktree_raw_sha256::Union{Nothing,String}
    ad45_envelope_path::Union{Nothing,String}
    ad45_envelope_bytes_key::Union{Nothing,String}
    root_status::Symbol
    head_probe_status::Symbol
    observed_head::Union{Nothing,String}
    tree_status::Symbol
    tree_entry_count::Int
    tree_entry_path::Union{Nothing,String}
    head_path_status::Symbol
    tracked_entry_status::Symbol
    tracked_entry_count::Int
    tracked_entry_path::Union{Nothing,String}
    index_stage::Union{Nothing,Int}
    index_flags::UInt32
    verbose_flag_status::Symbol
    verbose_entry_count::Int
    debug_index_status::Symbol
    working_tree_status::Symbol
    worktree_path_kind::Symbol
    head_blob_status::Symbol
    head_blob_oid::Union{Nothing,String}
    head_bytes_key::Union{Nothing,String}
    head_bytes_bytes::Union{Nothing,Int}
    head_bytes_sha256::Union{Nothing,String}
    filter_status::Symbol
    filter_input_key::Union{Nothing,String}
    filter_input_sha256::Union{Nothing,String}
    attributes_status::Symbol
    attributes_key::Union{Nothing,String}
    filter_recipe_status::Symbol
    filter_recipe_key::Union{Nothing,String}
    filter_output_key::Union{Nothing,String}
    filter_output_bytes::Union{Nothing,Int}
    filter_output_sha256::Union{Nothing,String}
end

function _frozen_optional_text(value, field)
    value === nothing && return nothing
    value isa AbstractString || throw(ArgumentError("$(field) must be text or nothing"))
    String(value)
end

function FrozenSourceObservationV1(value::AbstractDict)
    required = Set(("schema", "source_path", "fixture_case_id", "worktree_bytes_key",
        "worktree_raw_bytes", "worktree_raw_sha256",
        "ad45_envelope_path", "ad45_envelope_bytes_key", "root_status", "head_probe_status", "observed_head",
        "tree_status", "tree_entry_count", "tree_entry_path", "head_path_status",
        "tracked_entry_status", "tracked_entry_count", "tracked_entry_path", "index_stage", "index_flags",
        "verbose_flag_status", "verbose_entry_count", "debug_index_status", "working_tree_status", "worktree_path_kind", "head_blob_status",
        "head_blob_oid", "head_bytes_key", "head_bytes_bytes", "head_bytes_sha256", "filter_status",
        "filter_input_key", "filter_input_sha256", "attributes_status", "attributes_key",
        "filter_recipe_status", "filter_recipe_key",
        "filter_output_key", "filter_output_bytes", "filter_output_sha256"))
    Set(String.(keys(value))) == required || throw(ArgumentError("frozen source observation fields differ"))
    value["schema"] == "frozen-source-observation-v1" ||
        throw(ArgumentError("unsupported frozen source observation schema"))
    sym(key, allowed) = begin
        item = value[key]
        item isa AbstractString || throw(ArgumentError("observation $(key) must be text"))
        result = Symbol(item)
        result in allowed || throw(ArgumentError("observation $(key) is unsupported"))
        result
    end
    integer_or_nothing(key) = begin
        item = value[key]
        item === nothing && return nothing
        item isa Integer && !(item isa Bool) && item >= 0 ||
            throw(ArgumentError("observation $(key) must be a nonnegative integer or nothing"))
        Int(item)
    end
    index_flags = value["index_flags"]
    index_flags isa Integer && !(index_flags isa Bool) && 0 <= index_flags <= typemax(UInt32) ||
        throw(ArgumentError("observation index_flags is invalid"))
    head_oid = _frozen_optional_text(value["observed_head"], "observed_head")
    head_blob_oid = _frozen_optional_text(value["head_blob_oid"], "head_blob_oid")
    head_sha = _frozen_optional_text(value["filter_output_sha256"], "filter_output_sha256")
    raw_sha = _frozen_optional_text(value["worktree_raw_sha256"], "worktree_raw_sha256")
    head_bytes_sha = _frozen_optional_text(value["head_bytes_sha256"], "head_bytes_sha256")
    head_bytes_count = integer_or_nothing("head_bytes_bytes")
    filter_output_count = integer_or_nothing("filter_output_bytes")
    filter_input_sha = _frozen_optional_text(value["filter_input_sha256"], "filter_input_sha256")
    head_oid === nothing || occursin(r"^[0-9a-f]{40}$", head_oid) ||
        throw(ArgumentError("observation observed_head must be a SHA-1 object id"))
    head_blob_oid === nothing || occursin(r"^[0-9a-f]{40}$", head_blob_oid) ||
        throw(ArgumentError("observation head_blob_oid must be a SHA-1 object id"))
    head_sha === nothing || _frozen_hash_text(head_sha, "filter output SHA-256")
    raw_sha === nothing || _frozen_hash_text(raw_sha, "worktree raw SHA-256")
    head_bytes_sha === nothing || _frozen_hash_text(head_bytes_sha, "HEAD byte SHA-256")
    filter_input_sha === nothing || _frozen_hash_text(filter_input_sha, "filter input SHA-256")
    tree_count = value["tree_entry_count"]
    tree_count isa Integer && !(tree_count isa Bool) && tree_count >= 0 ||
        throw(ArgumentError("observation tree_entry_count is invalid"))
    verbose_count = value["verbose_entry_count"]
    verbose_count isa Integer && !(verbose_count isa Bool) && verbose_count >= 0 ||
        throw(ArgumentError("observation verbose_entry_count is invalid"))
    tracked_count = value["tracked_entry_count"]
    tracked_count isa Integer && !(tracked_count isa Bool) && tracked_count >= 0 ||
        throw(ArgumentError("observation tracked_entry_count is invalid"))
    key_or_nothing(key) = begin
        item = _frozen_optional_text(value[key], key)
        item === nothing ? nothing : _frozen_logical_path(item, key)
    end
    fixture_case_id = _frozen_optional_text(value["fixture_case_id"], "fixture_case_id")
    fixture_case_id === nothing || (!isempty(fixture_case_id) && fixture_case_id == strip(fixture_case_id)) ||
        throw(ArgumentError("observation fixture_case_id must be nonempty canonical text"))
    FrozenSourceObservationV1(
        _frozen_logical_path(value["source_path"], "observation source_path"), fixture_case_id,
        key_or_nothing("worktree_bytes_key"), integer_or_nothing("worktree_raw_bytes"), raw_sha,
        key_or_nothing("ad45_envelope_path"),
        key_or_nothing("ad45_envelope_bytes_key"),
        sym("root_status", (:valid, :invalid, :mismatch, :unavailable)),
        sym("head_probe_status", (:valid, :failed, :malformed, :mismatch)), head_oid,
        sym("tree_status", (:valid, :probe_failed)), Int(tree_count),
        key_or_nothing("tree_entry_path"),
        sym("head_path_status", (:present, :absent)),
        sym("tracked_entry_status", (:stage0, :missing, :malformed, :unmerged, :path_mismatch, :probe_failed)),
        Int(tracked_count),
        key_or_nothing("tracked_entry_path"),
        integer_or_nothing("index_stage"), UInt32(index_flags),
        sym("verbose_flag_status", (:normal, :no_entry, :multiple, :assume_unchanged, :skip_worktree, :malformed, :probe_failed)),
        Int(verbose_count),
        sym("debug_index_status", (:valid, :probe_failed, :malformed)),
        sym("working_tree_status", (:clean, :dirty, :untracked, :probe_failed)),
        sym("worktree_path_kind", (:regular_file, :missing, :unreadable, :symlink, :directory, :other, :alias)),
        sym("head_blob_status", (:valid, :probe_failed, :read_failed, :bytes_mismatch, :size_mismatch, :sha_mismatch)),
        head_blob_oid, key_or_nothing("head_bytes_key"), head_bytes_count, head_bytes_sha,
        sym("filter_status", (:not_applicable, :matches, :mismatch, :startup_failure, :nonzero_failure)),
        key_or_nothing("filter_input_key"), filter_input_sha,
        sym("attributes_status", (:present, :absent, :probe_failed)),
        key_or_nothing("attributes_key"),
        sym("filter_recipe_status", (:present, :absent, :startup_failure, :nonzero_failure)),
        key_or_nothing("filter_recipe_key"),
        key_or_nothing("filter_output_key"), filter_output_count, head_sha)
end

mutable struct FrozenSourceContextV1
    authorization::FrozenSourceAuthorizationV1
    fixture_case_id::Union{Nothing,String}
    inputs::Dict{String,FrozenSourceInputV1}
    observations::Dict{String,FrozenSourceObservationV1}
    source_bindings::Base.ImmutableDict{String,String}
end

function FrozenSourceContextV1(authorization::FrozenSourceAuthorizationV1;
        fixture_case_id=nothing)
    _validate_frozen_environment!(authorization)
    case_id = fixture_case_id === nothing ? nothing : String(fixture_case_id)
    case_id === nothing || (!isempty(case_id) && case_id == strip(case_id)) ||
        throw(ArgumentError("fixture_case_id must be nonempty canonical text"))
    root = normpath(authorization.source_root)
    isdir(root) || throw(ArgumentError("frozen source root is unavailable"))
    realpath(root) == root || throw(ArgumentError("frozen source root is not canonical"))
    cursor = root
    while true
        islink(cursor) && throw(ArgumentError("frozen source root contains a reparse component"))
        parent = dirname(cursor)
        parent == cursor && break
        cursor = parent
    end
    manifest = joinpath(root, authorization.manifest_path)
    isfile(manifest) || throw(ArgumentError("frozen source manifest is missing"))
    islink(manifest) && throw(ArgumentError("frozen source manifest is a symlink/reparse file"))
    manifest_info = stat(manifest)
    hasproperty(manifest_info, :nlink) && getproperty(manifest_info, :nlink) != 1 &&
        throw(ArgumentError("frozen source manifest has hard-link aliases"))
    manifest_bytes = read(manifest)
    length(manifest_bytes) == authorization.manifest_bytes ||
        throw(ArgumentError("frozen source manifest byte count mismatch"))
    bytes2hex(SHA.sha256(manifest_bytes)) == authorization.manifest_sha256 ||
        throw(ArgumentError("frozen source manifest SHA-256 mismatch"))
    _verify_frozen_protocol_record!(authorization, root)
    _verify_frozen_manifest(authorization, root, manifest_bytes)
    context = FrozenSourceContextV1(authorization, case_id,
        Dict{String,FrozenSourceInputV1}(), Dict{String,FrozenSourceObservationV1}(),
        Base.ImmutableDict{String,String}())
    if _validate_frozen_environment!(authorization)
        audit_path = get(ENV, _FROZEN_QUERY_AUDIT_ENV, "")
        isempty(audit_path) && throw(ArgumentError("formal runtime query audit output path is not configured"))
        _audit_path_outside_snapshot(audit_path, root)
    end
    _record_verified_context!(authorization)
    isempty(get(ENV, _FROZEN_QUERY_AUDIT_ENV, "")) || _register_runtime_audit_atexit!()
    context
end

function _frozen_formal_runtime_requested()
    any(key -> haskey(ENV, key),
        (_FROZEN_AUTH_ENV_KEYS..., _FROZEN_PROTOCOL_PATH_ENV, _FROZEN_QUERY_AUDIT_ENV))
end

function _read_runtime_authorization()
    keys_required = (_FROZEN_AUTH_ENV_KEYS..., _FROZEN_PROTOCOL_PATH_ENV,
        _FROZEN_QUERY_AUDIT_ENV)
    all(key -> haskey(ENV, key) && !isempty(ENV[key]), keys_required) ||
        throw(ArgumentError("formal frozen runtime environment pins and paths are incomplete"))
    protocol_path = String(ENV[_FROZEN_PROTOCOL_PATH_ENV])
    isabspath(protocol_path) || throw(ArgumentError("formal protocol path must be absolute"))
    absolute = normpath(abspath(protocol_path))
    isfile(absolute) || throw(ArgumentError("formal protocol file is missing"))
    islink(absolute) && throw(ArgumentError("formal protocol file is a symlink or reparse point"))
    realpath(absolute) == absolute || throw(ArgumentError("formal protocol path is not canonical"))
    info = stat(absolute)
    hasproperty(info, :nlink) && getproperty(info, :nlink) == 1 ||
        throw(ArgumentError("formal protocol file must have one hard link"))
    raw = read(absolute)
    authorization = _authorization_from_protocol_bytes(raw,
        String(ENV[_FROZEN_PROTOCOL_ENV]))
    _audit_path_outside_snapshot(absolute, authorization.source_root)
    isabspath(ENV[_FROZEN_QUERY_AUDIT_ENV]) ||
        throw(ArgumentError("formal query audit path must be absolute"))
    _audit_path_outside_snapshot(String(ENV[_FROZEN_QUERY_AUDIT_ENV]),
        authorization.source_root)
    authorization
end

function _reverify_runtime_context!(context::FrozenSourceContextV1)
    authorization = context.authorization
    _validate_frozen_environment!(authorization) ||
        throw(ArgumentError("formal frozen runtime pins are absent"))
    _verify_frozen_protocol_record!(authorization, authorization.source_root)
    manifest = joinpath(authorization.source_root, authorization.manifest_path)
    isfile(manifest) || throw(ArgumentError("runtime frozen manifest is missing"))
    islink(manifest) && throw(ArgumentError("runtime frozen manifest is a symlink or reparse file"))
    realpath(manifest) == manifest ||
        throw(ArgumentError("runtime frozen manifest path is not canonical"))
    manifest_info = stat(manifest)
    hasproperty(manifest_info, :nlink) && getproperty(manifest_info, :nlink) == 1 ||
        throw(ArgumentError("runtime frozen manifest has hard-link aliases"))
    raw = read(manifest)
    length(raw) == authorization.manifest_bytes ||
        throw(ArgumentError("runtime frozen manifest byte count changed"))
    bytes2hex(SHA.sha256(raw)) == authorization.manifest_sha256 ||
        throw(ArgumentError("runtime frozen manifest hash changed"))
    _verify_frozen_manifest(authorization, authorization.source_root, raw)
    audit_path = get(ENV, _FROZEN_QUERY_AUDIT_ENV, "")
    isempty(audit_path) && throw(ArgumentError("formal runtime query audit path is absent"))
    _audit_path_outside_snapshot(audit_path, authorization.source_root)
    nothing
end

function _runtime_formal_bootstrap!(; required::Bool=false)
    if _RUNTIME_BOOTSTRAP_COMPLETED[]
        context = _RUNTIME_BOOTSTRAP_CONTEXT[]
        context isa FrozenSourceContextV1 ||
            throw(ArgumentError("formal runtime bootstrap state is inconsistent"))
        _reverify_runtime_context!(context)
        return context
    end
    if !_frozen_formal_runtime_requested()
        required && throw(ArgumentError("formal frozen runtime pins are required"))
        return nothing
    end
    authorization = _read_runtime_authorization()
    context = FrozenSourceContextV1(authorization)
    _RUNTIME_BOOTSTRAP_CONTEXT[] = context
    _RUNTIME_BOOTSTRAP_COMPLETED[] = true
    context
end

function initialize_frozen_runtime!(; required::Bool=true)
    context = _runtime_formal_bootstrap!(; required=required)
    required && !(context isa FrozenSourceContextV1) &&
        throw(ArgumentError("formal frozen runtime context was not initialized"))
    context
end

function _frozen_json_string(value::AbstractString)
    io = IOBuffer()
    write(io, '"')
    for char in String(value)
        code = UInt32(char)
        if char == '"'
            write(io, "\\\"")
        elseif char == '\\'
            write(io, "\\\\")
        elseif char == '\b'
            write(io, "\\b")
        elseif char == '\f'
            write(io, "\\f")
        elseif char == '\n'
            write(io, "\\n")
        elseif char == '\r'
            write(io, "\\r")
        elseif char == '\t'
            write(io, "\\t")
        elseif code < 0x20 || code > 0x7e
            if code <= 0xffff
                write(io, "\\u", lowercase(string(code; base=16, pad=4)))
            else
                adjusted = code - 0x10000
                high = 0xd800 + (adjusted >> 10)
                low = 0xdc00 + (adjusted & 0x3ff)
                write(io, "\\u", lowercase(string(high; base=16, pad=4)),
                    "\\u", lowercase(string(low; base=16, pad=4)))
            end
        else
            write(io, char)
        end
    end
    write(io, '"')
    String(take!(io))
end

function _frozen_inventory_root(entries, archives)
    rows = Vector{Tuple{String,Vector{Any}}}()
    for (kind, source_rows) in (("entry", entries), ("external_archive", archives))
        for row in source_rows
            record = Any[kind, row["logical_path"], row["role"], row["frozen_path"],
                row["bytes"], row["sha256"]]
            push!(rows, (_frozen_alias_key(row["logical_path"]) * "\0" * kind * "\0" *
                row["role"] * "\0" * row["frozen_path"], record))
        end
    end
    sort!(rows; by=first)
    encoded = "[" * join(("[" * join((x isa AbstractString ? _frozen_json_string(x) : string(x)
        for x in record), ",") * "]" for (_, record) in rows), ",") * "]"
    bytes2hex(SHA.sha256(codeunits(encoded)))
end

function _frozen_file_sha256(path::AbstractString)
    open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

function _verify_frozen_manifest(auth::FrozenSourceAuthorizationV1, root::String, raw::Vector{UInt8})
    parsed = try TOML.parse(String(copy(raw))) catch err
        throw(ArgumentError("frozen source manifest is invalid TOML: $(typeof(err))"))
    end
    Set(String.(keys(parsed))) ⊆ Set(("snapshot", "entries", "external_archives")) &&
        haskey(parsed, "snapshot") ||
        throw(ArgumentError("frozen source manifest has unexpected top-level fields"))
    header = parsed["snapshot"]
    header isa AbstractDict && Set(String.(keys(header))) ==
        Set(("schema", "entry_count", "external_archive_count", "inventory_root_sha256")) ||
        throw(ArgumentError("frozen source manifest header differs from schema"))
    header["schema"] == "fusion-t2-frozen-input-snapshot-v1" ||
        throw(ArgumentError("frozen source manifest schema mismatch"))
    entries = get(parsed, "entries", Any[])
    archives = get(parsed, "external_archives", Any[])
    entries isa AbstractVector && archives isa AbstractVector && (!isempty(entries) || !isempty(archives)) ||
        throw(ArgumentError("frozen source manifest closure is empty or malformed"))
    header["entry_count"] isa Integer && !(header["entry_count"] isa Bool) &&
        header["entry_count"] == length(entries) ||
        throw(ArgumentError("frozen source entry count mismatch"))
    header["external_archive_count"] isa Integer && !(header["external_archive_count"] isa Bool) &&
        header["external_archive_count"] == length(archives) ||
        throw(ArgumentError("frozen source external archive count mismatch"))
    Set(keys(auth.expected_entries)) == Set(String(row["logical_path"]) for row in entries) ||
        throw(ArgumentError("frozen source entry map differs from authorization"))
    Set(keys(auth.expected_external_archives)) == Set(String(row["logical_path"]) for row in archives) ||
        throw(ArgumentError("frozen external archive map differs from authorization"))
    expected_fields = Set(("logical_path", "role", "bytes", "sha256", "frozen_path", "origin_path"))
    seen_logical, seen_frozen = Set{String}(), Set{String}()
    all_rows = Vector{Dict{String,Any}}()
    for (kind, source_rows) in (("entry", entries), ("external_archive", archives))
        for row in source_rows
            row isa AbstractDict && Set(String.(keys(row))) == expected_fields ||
                throw(ArgumentError("frozen source row has unexpected fields"))
            logical = _frozen_logical_path(row["logical_path"], "manifest logical_path")
            frozen = _frozen_logical_path(row["frozen_path"], "manifest frozen_path")
            (frozen == "manifest.toml" || startswith(frozen, "manifest.toml/")) &&
                throw(ArgumentError("frozen source row collides with manifest.toml"))
            role = row["role"]
            role isa AbstractString && !isempty(role) && !any(c -> UInt32(c) < 0x20, role) ||
                throw(ArgumentError("frozen source role is invalid"))
            bytes = row["bytes"]
            bytes isa Integer && !(bytes isa Bool) && bytes >= 0 ||
                throw(ArgumentError("frozen source byte count is invalid"))
            digest = _frozen_hash_text(row["sha256"], "manifest SHA-256")
            origin = row["origin_path"]
            origin isa AbstractString && isabspath(origin) ||
                throw(ArgumentError("frozen source origin_path is invalid"))
            expected_frozen = kind == "entry" ? logical : "_archives/" * last(split(logical, '/'))
            frozen == expected_frozen || throw(ArgumentError("frozen source path differs from schema"))
            logical_alias, frozen_alias = _frozen_alias_key(logical), _frozen_alias_key(frozen)
            (logical_alias in seen_logical || frozen_alias in seen_frozen) &&
                throw(ArgumentError("frozen source manifest has path aliases"))
            push!(seen_logical, logical_alias); push!(seen_frozen, frozen_alias)
            pin_map = kind == "entry" ? auth.expected_entries : auth.expected_external_archives
            pin = pin_map[logical]
            (String(role), Int(bytes), digest) == (pin.role, pin.bytes, pin.sha256) ||
                throw(ArgumentError("frozen source row differs from authorization pin"))
            kind == "external_archive" && frozen != "_archives/" * last(split(logical, '/')) &&
                throw(ArgumentError("frozen archive path is not the authorized safe basename"))
            push!(all_rows, Dict{String,Any}("logical_path"=>logical, "role"=>String(role),
                "frozen_path"=>frozen, "bytes"=>Int(bytes), "sha256"=>digest))
        end
    end
    actual_inventory = _frozen_inventory_root(entries, archives)
    actual_inventory == auth.inventory_root_sha256 == header["inventory_root_sha256"] ||
        throw(ArgumentError("frozen source inventory root mismatch"))

    expected_files = Set(("manifest.toml",))
    expected_dirs = Set{String}()
    for row in all_rows
        frozen = row["frozen_path"]
        push!(expected_files, frozen)
        parts = split(frozen, '/')
        for index in 1:(length(parts)-1)
            push!(expected_dirs, join(parts[1:index], '/'))
        end
    end
    actual_files, actual_dirs = Set{String}(), Set{String}()
    for (directory, subdirectories, files) in walkdir(root; follow_symlinks=false)
        for name in (subdirectories..., files...)
            path = joinpath(directory, name)
            islink(path) && throw(ArgumentError("frozen snapshot contains a symlink/reparse member"))
            relative = replace(relpath(path, root), '\\' => '/')
            if isdir(path)
                push!(actual_dirs, relative)
            elseif isfile(path)
                push!(actual_files, relative)
            else
                throw(ArgumentError("frozen snapshot contains a non-file member"))
            end
        end
    end
    actual_files == expected_files && actual_dirs == expected_dirs ||
        throw(ArgumentError("frozen snapshot directory is not a closed tree"))
    for row in all_rows
        path = joinpath(root, split(row["frozen_path"], '/')...)
        islink(path) && throw(ArgumentError("frozen snapshot member is a symlink/reparse file"))
        isfile(path) || throw(ArgumentError("frozen snapshot member is not a regular file"))
        info = stat(path)
        hasproperty(info, :nlink) && getproperty(info, :nlink) != 1 &&
            throw(ArgumentError("frozen snapshot member has hard-link aliases"))
        filesize(path) == row["bytes"] || throw(ArgumentError("frozen snapshot member byte count mismatch"))
        _frozen_file_sha256(path) == row["sha256"] ||
            throw(ArgumentError("frozen snapshot member SHA-256 mismatch"))
    end
    nothing
end

function _load_frozen_source!(context::FrozenSourceContextV1, logical_path::String,
        manifest_key::String; expected_role=nothing)
    haskey(context.inputs, logical_path) && begin
        entry = context.inputs[logical_path]
        entry.manifest_key == manifest_key || throw(ArgumentError("frozen source key binding changed"))
        return entry
    end
    pin = get(context.authorization.expected_entries, manifest_key, nothing)
    pin === nothing && return nothing
    expected_role === nothing || pin.role == expected_role ||
        throw(ArgumentError("frozen source manifest role mismatch"))
    source = joinpath(context.authorization.source_root, split(manifest_key, '/')...)
    islink(source) && throw(ArgumentError("frozen source entry is a symlink"))
    isfile(source) || throw(ArgumentError("authorized frozen source entry is missing"))
    raw = read(source)
    length(raw) == pin.bytes || throw(ArgumentError("frozen source byte count mismatch"))
    digest = bytes2hex(SHA.sha256(raw))
    digest == pin.sha256 || throw(ArgumentError("frozen source SHA-256 mismatch"))
    entry = FrozenSourceInputV1(logical_path, manifest_key, context.fixture_case_id,
        pin.role, raw, length(raw), digest)
    context.inputs[logical_path] = entry
    entry
end

function register_frozen_source!(context::FrozenSourceContextV1, logical_path::AbstractString)
    path = _frozen_logical_path(logical_path, "frozen source key")
    manifest_key = if haskey(context.source_bindings, path)
        context.source_bindings[path]
    elseif context.fixture_case_id === nothing
        path
    else
        return nothing
    end
    _load_frozen_source!(context, path, manifest_key)
end

function frozen_source(context::FrozenSourceContextV1, logical_path::AbstractString)
    path = _frozen_logical_path(logical_path, "frozen source key")
    haskey(context.inputs, path) && return context.inputs[path]
    register_frozen_source!(context, path)
end

"""A protocol-neutral, immutable UP1 source view over a hash-pinned snapshot.

The caller supplies expected pins from the independently frozen handoff. The
constructor verifies the manifest and every entry against those pins; reads
recheck the selected file bytes. This path deliberately performs no Git query.
"""
struct UP1FrozenSourceContextV1
    source_root::String
    manifest_path::String
    manifest_bytes::Int
    manifest_sha256::String
    snapshot_id::String
    candidate_ref::String
    scenario_id::String
    expected_entries::Dict{String,FrozenSourcePinV1}
end

function _up1_manifest_entries(parsed)
    Set(String.(keys(parsed))) == Set(("snapshot", "entries")) ||
        throw(ArgumentError("UP1 frozen manifest has unexpected top-level fields"))
    header = parsed["snapshot"]
    header isa AbstractDict && Set(String.(keys(header))) ==
        Set(("schema", "snapshot_id", "candidate_ref", "scenario_id", "entry_count")) ||
        throw(ArgumentError("UP1 frozen manifest header differs from schema"))
    header["schema"] == "fusion-up1-04a-vnext-frozen-source-v1" ||
        throw(ArgumentError("UP1 frozen manifest schema mismatch"))
    rows = parsed["entries"]
    rows isa AbstractVector && !isempty(rows) ||
        throw(ArgumentError("UP1 frozen manifest entries are empty or malformed"))
    entries = Dict{String,Any}()
    aliases = Set{String}()
    for row in rows
        row isa AbstractDict && Set(String.(keys(row))) ==
            Set(("logical_path", "role", "bytes", "sha256")) ||
            throw(ArgumentError("UP1 frozen manifest entry differs from schema"))
        path = _frozen_logical_path(row["logical_path"], "UP1 logical_path")
        folded = _frozen_alias_key(path)
        folded in aliases && throw(ArgumentError("UP1 manifest repeats an aliased path"))
        push!(aliases, folded)
        entries[path] = (role=row["role"], bytes=row["bytes"],
            sha256=row["sha256"])
    end
    Int(header["entry_count"]) == length(entries) ||
        throw(ArgumentError("UP1 frozen manifest entry count mismatch"))
    header, entries
end

function _up1_read_verified_member(root::String, path::String, pin::FrozenSourcePinV1)
    source = joinpath(root, split(path, '/')...)
    islink(source) && throw(ArgumentError("UP1 frozen source is a symlink/reparse file"))
    isfile(source) || throw(ArgumentError("UP1 authorized frozen source is missing"))
    realpath(source) == source || throw(ArgumentError("UP1 frozen source path is noncanonical"))
    info = stat(source)
    hasproperty(info, :nlink) && getproperty(info, :nlink) == 1 ||
        throw(ArgumentError("UP1 frozen source must have one hard link"))
    raw = read(source)
    length(raw) == pin.bytes || throw(ArgumentError("UP1 frozen source byte count mismatch"))
    digest = bytes2hex(SHA.sha256(raw))
    digest == pin.sha256 || throw(ArgumentError("UP1 frozen source SHA-256 mismatch"))
    raw, digest
end

function _up1_verify_closed_tree(root::String, pins::Dict{String,FrozenSourcePinV1})
    expected = Set(keys(pins))
    actual = Set{String}()
    expected_dirs = Set{String}()
    for (directory, dirs, files) in walkdir(root; follow_symlinks=false)
        for name in dirs
            path = joinpath(directory, name)
            islink(path) && throw(ArgumentError("UP1 frozen snapshot contains a symlink/reparse directory"))
            isdir(path) || throw(ArgumentError("UP1 frozen snapshot contains a non-directory member"))
            relative = replace(relpath(path, root), '\\' => '/')
            _frozen_logical_path(relative, "UP1 snapshot directory")
            push!(expected_dirs, relative)
        end
        for name in files
            path = joinpath(directory, name)
            islink(path) && throw(ArgumentError("UP1 frozen snapshot contains a symlink/reparse file"))
            isfile(path) || throw(ArgumentError("UP1 frozen snapshot contains a non-file member"))
            relative = replace(relpath(path, root), '\\' => '/')
            relative == "manifest.toml" && continue
            push!(actual, _frozen_logical_path(relative, "UP1 snapshot member"))
        end
    end
    actual == expected || throw(ArgumentError("UP1 frozen snapshot membership differs from the manifest"))
    required_dirs = Set{String}()
    for path in expected
        parts = split(path, '/')
        for count in 1:(length(parts) - 1)
            push!(required_dirs, join(parts[1:count], '/'))
        end
    end
    expected_dirs == required_dirs ||
        throw(ArgumentError("UP1 frozen snapshot directory membership differs from the manifest"))
    for (path, pin) in pins
        _up1_read_verified_member(root, path, pin)
    end
    nothing
end

function UP1FrozenSourceContextV1(source_root::AbstractString, manifest_path::AbstractString;
        expected_snapshot_id::AbstractString, expected_manifest_sha256::AbstractString,
        expected_candidate_ref::AbstractString, expected_scenario_id::AbstractString,
        expected_entries)
    root = normpath(abspath(String(source_root)))
    isdir(root) && realpath(root) == root || throw(ArgumentError("UP1 frozen source root is unavailable or noncanonical"))
    cursor = root
    while true
        islink(cursor) && throw(ArgumentError("UP1 frozen source root contains a reparse component"))
        parent = dirname(cursor)
        parent == cursor && break
        cursor = parent
    end
    manifest = normpath(abspath(String(manifest_path)))
    manifest == joinpath(root, "manifest.toml") ||
        throw(ArgumentError("UP1 frozen manifest must be root/manifest.toml inside the source snapshot"))
    isfile(manifest) && !islink(manifest) && realpath(manifest) == manifest ||
        throw(ArgumentError("UP1 frozen manifest is missing or noncanonical"))
    cursor = manifest
    while true
        islink(cursor) && throw(ArgumentError("UP1 frozen manifest path contains a reparse component"))
        parent = dirname(cursor)
        parent == cursor && break
        cursor = parent
    end
    info = stat(manifest)
    hasproperty(info, :nlink) && getproperty(info, :nlink) == 1 ||
        throw(ArgumentError("UP1 frozen manifest must have one hard link"))
    raw = read(manifest)
    manifest_sha = bytes2hex(SHA.sha256(raw))
    manifest_sha == _frozen_hash_text(expected_manifest_sha256, "UP1 manifest SHA-256") ||
        throw(ArgumentError("UP1 frozen manifest SHA-256 mismatch"))
    parsed = try TOML.parse(String(copy(raw))) catch err
        throw(ArgumentError("UP1 frozen manifest is invalid TOML: $(typeof(err))"))
    end
    header, manifest_entries = _up1_manifest_entries(parsed)
    String(header["snapshot_id"]) == expected_snapshot_id ||
        throw(ArgumentError("UP1 snapshot identity mismatch"))
    String(header["candidate_ref"]) == expected_candidate_ref ||
        throw(ArgumentError("UP1 candidate identity mismatch"))
    String(header["scenario_id"]) == expected_scenario_id ||
        throw(ArgumentError("UP1 scenario identity mismatch"))
    for (value, label) in ((expected_snapshot_id, "snapshot_id"),
            (expected_candidate_ref, "candidate_ref"), (expected_scenario_id, "scenario_id"))
        !isempty(value) && value == strip(value) && !occursin('\0', value) ||
            throw(ArgumentError("UP1 $(label) is not canonical text"))
    end
    pins = _frozen_pin_map(expected_entries, "UP1 expected_entries")
    _same_frozen_pin_map(pins, _frozen_pin_map(manifest_entries, "UP1 manifest entries")) ||
        throw(ArgumentError("UP1 manifest entries differ from independently frozen pins"))
    isempty(pins) && throw(ArgumentError("UP1 frozen source closure is empty"))
    context = UP1FrozenSourceContextV1(root, manifest, length(raw), manifest_sha,
        String(expected_snapshot_id), String(expected_candidate_ref), String(expected_scenario_id), pins)
    _up1_verify_closed_tree(root, pins)
    context
end

function frozen_source(context::UP1FrozenSourceContextV1, logical_path::AbstractString)
    _up1_require_active_identity(context)
    _up1_frozen_source_unchecked(context, logical_path)
end

function _up1_frozen_source_unchecked(context::UP1FrozenSourceContextV1,
        logical_path::AbstractString)
    manifest = context.manifest_path
    isfile(manifest) && !islink(manifest) && realpath(manifest) == manifest ||
        throw(ArgumentError("UP1 frozen manifest disappeared or became noncanonical"))
    manifest_info = stat(manifest)
    hasproperty(manifest_info, :nlink) && getproperty(manifest_info, :nlink) == 1 ||
        throw(ArgumentError("UP1 frozen manifest hard-link count changed"))
    manifest_raw = read(manifest)
    length(manifest_raw) == context.manifest_bytes ||
        throw(ArgumentError("UP1 frozen manifest byte count changed"))
    bytes2hex(SHA.sha256(manifest_raw)) == context.manifest_sha256 ||
        throw(ArgumentError("UP1 frozen manifest SHA-256 changed"))
    header, manifest_entries = _up1_manifest_entries(try
        TOML.parse(String(copy(manifest_raw)))
    catch err
        throw(ArgumentError("UP1 frozen manifest became invalid TOML: $(typeof(err))"))
    end)
    String(header["snapshot_id"]) == context.snapshot_id &&
        String(header["candidate_ref"]) == context.candidate_ref &&
        String(header["scenario_id"]) == context.scenario_id &&
        _same_frozen_pin_map(context.expected_entries,
            _frozen_pin_map(manifest_entries, "UP1 runtime manifest entries")) ||
        throw(ArgumentError("UP1 frozen manifest identity or entries changed"))
    path = _frozen_logical_path(logical_path, "UP1 frozen source key")
    pin = get(context.expected_entries, path, nothing)
    pin === nothing && return nothing
    raw, digest = _up1_read_verified_member(context.source_root, path, pin)
    FrozenSourceInputV1(path, path, nothing, pin.role, raw, length(raw), digest)
end

"""Activate a process-wide Git deny guard after verifying the UP1 snapshot."""
function activate_up1_frozen_runtime!(context::UP1FrozenSourceContextV1)
    identity = _up1_context_identity(context)
    already_active = lock(_UP1_GUARD_LOCK) do
        current = _UP1_FROZEN_RUNTIME_IDENTITY[]
        current !== nothing && current != identity &&
            throw(ArgumentError("UP1 runtime is already bound to a different snapshot"))
        _UP1_FROZEN_RUNTIME_ACTIVE[]
    end
    first_path = first(keys(context.expected_entries))
    first_source = already_active ? frozen_source(context, first_path) :
        _up1_frozen_source_unchecked(context, first_path)
    first_source === nothing &&
        throw(ArgumentError("UP1 frozen snapshot failed activation verification"))
    _up1_verify_closed_tree(context.source_root, context.expected_entries)
    lock(_UP1_GUARD_LOCK) do
        current = _UP1_FROZEN_RUNTIME_IDENTITY[]
        (current !== nothing && current != identity) &&
            throw(ArgumentError("UP1 runtime is already bound to a different snapshot"))
        _UP1_FROZEN_RUNTIME_IDENTITY[] = identity
        _UP1_FROZEN_RUNTIME_ACTIVE[] = true
    end
    true
end
up1_frozen_runtime_active() = _UP1_FROZEN_RUNTIME_ACTIVE[]
up1_frozen_runtime_git_attempts() = lock(_UP1_GUARD_LOCK) do
    _UP1_GIT_ATTEMPTS[]
end
up1_frozen_runtime_git_audit() = lock(_UP1_GUARD_LOCK) do
    [(api_name=row.api_name, identity=row.identity) for row in _UP1_GIT_DENIALS]
end

function _up1_context_identity(context::UP1FrozenSourceContextV1)
    (context.snapshot_id, context.manifest_sha256, context.candidate_ref,
        context.scenario_id, context.source_root)
end

function _up1_require_active_identity(context::UP1FrozenSourceContextV1)
    lock(_UP1_GUARD_LOCK) do
        _UP1_FROZEN_RUNTIME_ACTIVE[] ||
            throw(ArgumentError("UP1 frozen runtime guard is inactive"))
        _UP1_FROZEN_RUNTIME_IDENTITY[] == _up1_context_identity(context) ||
            throw(ArgumentError("UP1 context is not the active frozen snapshot"))
    end
    nothing
end

function frozen_source_identity(context::FrozenSourceContextV1)
    auth = context.authorization
    (schema="fusion-t2-frozen-input-snapshot-v1", snapshot_id=auth.snapshot_id,
        protocol_sha256=auth.protocol_sha256, manifest_sha256=auth.manifest_sha256,
        inventory_root_sha256=auth.inventory_root_sha256,
        fixture_case_id=context.fixture_case_id)
end
function frozen_source_identity(context::UP1FrozenSourceContextV1)
    (schema="fusion-up1-04a-vnext-frozen-source-v1", snapshot_id=context.snapshot_id,
        manifest_sha256=context.manifest_sha256, candidate_ref=context.candidate_ref,
        scenario_id=context.scenario_id)
end
frozen_source_manifest_key(context::FrozenSourceContextV1, path::AbstractString) =
    get(context.source_bindings, String(path), String(path))
frozen_source_manifest_key(::UP1FrozenSourceContextV1, path::AbstractString) = String(path)
frozen_source_candidate_ref(context::UP1FrozenSourceContextV1) = context.candidate_ref

function register_frozen_archive!(context::FrozenSourceContextV1, logical_path::AbstractString)
    path = _frozen_logical_path(logical_path, "frozen archive key")
    haskey(context.inputs, path) && return context.inputs[path]
    pin = get(context.authorization.expected_external_archives, path, nothing)
    pin === nothing && return nothing
    basename = split(path, '/') |> last
    occursin(r"^[A-Za-z0-9._-]+$", basename) && basename ∉ (".", "..") ||
        throw(ArgumentError("frozen archive key has an unsafe basename"))
    source = joinpath(context.authorization.source_root, "_archives", basename)
    islink(source) && throw(ArgumentError("frozen external archive is a symlink"))
    isfile(source) || throw(ArgumentError("authorized frozen external archive is missing"))
    raw = read(source)
    length(raw) == pin.bytes || throw(ArgumentError("frozen external archive byte count mismatch"))
    digest = bytes2hex(SHA.sha256(raw))
    digest == pin.sha256 || throw(ArgumentError("frozen external archive SHA-256 mismatch"))
    entry = FrozenSourceInputV1(path, path, context.fixture_case_id, pin.role, raw, length(raw), digest)
    context.inputs[path] = entry
    entry
end

function frozen_archive(context::FrozenSourceContextV1, logical_path::AbstractString)
    path = _frozen_logical_path(logical_path, "frozen archive key")
    haskey(context.inputs, path) && return context.inputs[path]
    register_frozen_archive!(context, path)
end

function register_frozen_observation!(context::FrozenSourceContextV1,
        source_path::AbstractString, observation_path::AbstractString)
    source = _frozen_logical_path(source_path, "observation source path")
    record_path = _frozen_logical_path(observation_path, "observation record path")
    record = _load_frozen_source!(context, record_path, record_path;
        expected_role="source_observation_v1")
    record === nothing && return nothing
    value = JSON3.read(String(record.bytes), Dict{String,Any})
    observation = FrozenSourceObservationV1(value)
    observation.source_path == source || throw(ArgumentError("frozen observation source path mismatch"))
    observation.fixture_case_id == context.fixture_case_id ||
        throw(ArgumentError("frozen observation case id differs from context"))
    (observation.ad45_envelope_path === nothing) ==
        (observation.ad45_envelope_bytes_key === nothing) ||
        throw(ArgumentError("AD45 envelope path and byte key must be paired"))
    observation.worktree_path_kind === :regular_file && context.fixture_case_id !== nothing &&
        observation.worktree_bytes_key === nothing &&
        throw(ArgumentError("regular frozen worktree observation lacks its byte key"))
    observation.worktree_path_kind !== :regular_file && observation.worktree_bytes_key !== nothing &&
        throw(ArgumentError("non-regular frozen worktree observation has unexpected bytes"))
    worktree_key = observation.worktree_bytes_key === nothing && context.fixture_case_id === nothing ?
        source : observation.worktree_bytes_key
    references = (
        (worktree_key, "worktree_raw", source),
        (observation.head_bytes_key, "head_canonical", observation.head_bytes_key),
        (observation.attributes_key, "git_attributes", observation.attributes_key),
        (observation.filter_recipe_key, "clean_filter_recipe", observation.filter_recipe_key),
        (observation.filter_output_key, "clean_filter_output", observation.filter_output_key),
        (observation.ad45_envelope_bytes_key, "binding_envelope", observation.ad45_envelope_path),
    )
    source_bindings = Dict{String,String}(record_path => record_path)
    for (key, role, logical_path) in references
        key === nothing && continue
        haskey(context.authorization.expected_entries, key) ||
            throw(ArgumentError("frozen observation references an unauthorized logical path"))
        context.authorization.expected_entries[key].role == role ||
            throw(ArgumentError("frozen observation input role mismatch"))
        logical_path isa String || throw(ArgumentError("frozen observation input lacks logical path"))
        previous = get(source_bindings, logical_path, key)
        previous == key || throw(ArgumentError("frozen observation logical key is ambiguously bound"))
        source_bindings[logical_path] = key
        logical_path == key || (source_bindings[key] = key)
    end
    pin(key) = key === nothing ? nothing : context.authorization.expected_entries[key]
    if observation.worktree_path_kind === :regular_file
        raw_pin = pin(worktree_key)
        raw_pin === nothing && throw(ArgumentError("regular worktree observation lacks a pinned byte row"))
        observation.worktree_raw_bytes == raw_pin.bytes ||
            throw(ArgumentError("worktree raw byte count differs from its pin"))
        observation.worktree_raw_sha256 == raw_pin.sha256 ||
            throw(ArgumentError("worktree raw SHA differs from its pin"))
    elseif observation.worktree_raw_bytes !== nothing || observation.worktree_raw_sha256 !== nothing
        throw(ArgumentError("non-regular worktree observation has raw byte claims"))
    end
    if observation.head_bytes_key !== nothing
        head_pin = pin(observation.head_bytes_key)
        observation.head_bytes_bytes == head_pin.bytes ||
            throw(ArgumentError("HEAD byte count differs from its pin"))
        observation.head_bytes_sha256 == head_pin.sha256 ||
            throw(ArgumentError("HEAD byte SHA differs from its pin"))
    elseif observation.head_bytes_bytes !== nothing || observation.head_bytes_sha256 !== nothing
        throw(ArgumentError("HEAD byte claims lack a pinned row"))
    end
    if observation.filter_input_key !== nothing
        observation.filter_input_key == worktree_key ||
            throw(ArgumentError("clean-filter input is not the observed worktree row"))
        observation.filter_input_sha256 == observation.worktree_raw_sha256 ||
            throw(ArgumentError("clean-filter input SHA differs from observed raw bytes"))
    elseif observation.filter_input_sha256 !== nothing
        throw(ArgumentError("clean-filter input SHA lacks a pinned input row"))
    end
    if observation.filter_status === :matches
        observation.worktree_path_kind === :regular_file && worktree_key !== nothing &&
            observation.worktree_raw_sha256 !== nothing &&
            observation.filter_input_key == worktree_key &&
            observation.filter_input_sha256 == observation.worktree_raw_sha256 ||
            throw(ArgumentError("matched clean-filter result lacks its actual raw input row"))
    end
    if observation.filter_output_key !== nothing
        output_pin = pin(observation.filter_output_key)
        observation.filter_output_bytes == output_pin.bytes ||
            throw(ArgumentError("clean-filter output byte count differs from its pin"))
        observation.filter_output_sha256 == output_pin.sha256 ||
            throw(ArgumentError("clean-filter output SHA differs from its pin"))
    elseif observation.filter_output_bytes !== nothing || observation.filter_output_sha256 !== nothing
        throw(ArgumentError("clean-filter output claims lack a pinned row"))
    end
    if worktree_key !== nothing
        previous = get(source_bindings, source, worktree_key)
        previous == worktree_key ||
            throw(ArgumentError("frozen worktree logical key is ambiguously bound"))
        source_bindings[source] = worktree_key
    end
    if observation.ad45_envelope_path !== nothing
        previous = get(source_bindings, observation.ad45_envelope_path,
            observation.ad45_envelope_bytes_key)
        previous == observation.ad45_envelope_bytes_key ||
            throw(ArgumentError("frozen AD45 envelope logical key is ambiguously bound"))
        source_bindings[observation.ad45_envelope_path] = observation.ad45_envelope_bytes_key
    end
    existing = get(context.observations, source, nothing)
    existing === nothing ||
        throw(ArgumentError("frozen source observation cannot be rebound"))
    for (logical_path, key) in source_bindings
        previous = get(context.source_bindings, logical_path, key)
        previous == key || throw(ArgumentError("frozen source logical binding cannot be rebound"))
    end
    immutable_bindings = context.source_bindings
    for (logical_path, key) in source_bindings
        immutable_bindings = Base.ImmutableDict(immutable_bindings, logical_path => key)
    end
    context.source_bindings = immutable_bindings
    context.observations[source] = observation
    observation
end

function frozen_observation(context::FrozenSourceContextV1, source_path::AbstractString)
    path = _frozen_logical_path(source_path, "observation source path")
    get(context.observations, path, nothing)
end

function frozen_root_matches(context::FrozenSourceContextV1, root::AbstractString)
    canonical(value) = lowercase(replace(normpath(String(value)), '\\' => '/'))
    canonical(root) == canonical(context.authorization.source_root)
end

function _frozen_digest_value(value)
    hasproperty(value, :value) ? String(getproperty(value, :value)) : string(value)
end

function _frozen_git_stage_anchor(context::FrozenSourceContextV1, locator, family::Symbol)
    reason(g1g2, g3) = family === :g3 ? g3 : g1g2
    isabspath(context.authorization.source_root) ||
        return (reason(:repository_root_invalid, :repository_root_invalid), nothing)
    if !frozen_root_matches(context, locator.repository_root)
        return (reason(:repository_root_mismatch, :repository_root_mismatch), nothing)
    end
    context.fixture_case_id === nothing && return (:source_authority_missing, nothing)
    observations = collect(values(context.observations))
    isempty(observations) && return (:source_authority_missing, nothing)
    all(item -> item.fixture_case_id == context.fixture_case_id, observations) ||
        return (:source_authority_missing, nothing)
    root_head_facts = Set((item.root_status, item.head_probe_status, item.observed_head)
        for item in observations)
    length(root_head_facts) == 1 || return (:source_authority_missing, nothing)
    anchor = first(observations)

    anchor.root_status === :invalid &&
        return (reason(:repository_root_invalid, :repository_root_invalid), nothing)
    anchor.root_status === :mismatch &&
        return (reason(:repository_root_mismatch, :repository_root_mismatch), nothing)
    anchor.root_status === :unavailable && return (:repository_root_not_git, nothing)
    anchor.head_probe_status in (:failed, :malformed) &&
        return (reason(:head_probe_failed, :head_probe_failed), nothing)
    anchor.head_probe_status === :mismatch && return (:locator_head_mismatch, nothing)
    anchor.observed_head == locator.observed_head ||
        return (:locator_head_mismatch, nothing)
    (nothing, anchor)
end

"""Validate one pre-frozen source observation without consulting Git or a checkout."""
function frozen_source_validation(context::FrozenSourceContextV1, locator;
        family::Symbol=:g1, stage::Symbol=:full)
    stage in (:full, :git_only) ||
        throw(ArgumentError("unsupported frozen source validation stage"))
    stage === :git_only && family === :g3 &&
        throw(ArgumentError("git_only frozen validation is limited to G1/G2 compatibility checks"))
    isabspath(context.authorization.source_root) || return :repository_root_invalid
    root_status = frozen_root_matches(context, locator.repository_root)
    reason(g1g2, g3) = family === :g3 ? g3 : g1g2
    observation = nothing
    if stage === :full
        observation = frozen_observation(context, locator.source_path)
        observation === nothing && return :source_authority_missing
        observation.worktree_path_kind in (:missing, :directory, :other) && return :source_file_missing
        observation.worktree_path_kind in (:unreadable, :symlink, :alias) && return :source_read_failed
        observation.worktree_path_kind === :regular_file || return :source_file_missing
        worktree = frozen_source(context, locator.source_path)
        worktree === nothing && return :source_file_missing
        worktree.role == "worktree_raw" || throw(ArgumentError("frozen source role must be worktree_raw"))
        observation.worktree_raw_bytes == worktree.byte_count || return :source_read_failed
        observation.worktree_raw_sha256 == worktree.sha256 || return :source_read_failed
        if observation.filter_status === :matches
            observation.filter_input_key == worktree.manifest_key ||
                return :working_tree_filtered_blob_mismatch
            observation.filter_input_sha256 == worktree.sha256 ||
                return :working_tree_filtered_blob_mismatch
        elseif observation.filter_input_key !== nothing
            observation.filter_input_key == worktree.manifest_key ||
                return :working_tree_filtered_blob_mismatch
            observation.filter_input_sha256 == worktree.sha256 ||
                return :working_tree_filtered_blob_mismatch
        end
    else
        anchor_error, anchor = _frozen_git_stage_anchor(context, locator, family)
        anchor_error === nothing || return anchor_error
        observation = frozen_observation(context, locator.source_path)
        observation === nothing && return :source_authority_missing
        observation.fixture_case_id == context.fixture_case_id || return :source_authority_missing
        (observation.root_status, observation.head_probe_status, observation.observed_head) ==
            (anchor.root_status, anchor.head_probe_status, anchor.observed_head) ||
            return :source_authority_missing
    end
    if stage === :full
        if !root_status
            return observation.root_status === :unavailable ? reason(:repository_root_not_git, :repository_root_invalid) :
                reason(:repository_root_mismatch, :repository_root_mismatch)
        end
        observation.root_status === :invalid && return reason(:repository_root_invalid, :repository_root_invalid)
        observation.root_status === :mismatch && return reason(:repository_root_mismatch, :repository_root_mismatch)
        observation.root_status === :unavailable && return :repository_root_not_git
        observation.head_probe_status in (:failed, :malformed) &&
            return reason(:head_probe_failed, :head_probe_failed)
        observation.head_probe_status === :mismatch && return :locator_head_mismatch
        observation.observed_head == locator.observed_head || return :locator_head_mismatch
    end

    observation.tree_status === :probe_failed &&
        return reason(:source_read_or_git_probe_failed, :head_tree_probe_failed)
    if family === :g3
        observation.tracked_entry_status === :probe_failed && return :tracked_path_probe_failed
        observation.verbose_flag_status === :probe_failed && return :index_flags_probe_failed
    else
        (observation.tracked_entry_status === :probe_failed ||
            observation.verbose_flag_status === :probe_failed) &&
            return :source_read_or_git_probe_failed
    end
    expected_head_path = observation.head_path_status === :present ? :present : :absent_untracked
    actual_head_path = observation.tree_entry_count == 0 ? :absent_untracked : :present
    expected_head_path == actual_head_path || return :head_path_status_mismatch
    family === :g3 || actual_head_path == locator.head_path_status ||
        return :head_path_status_mismatch
    actual_status = observation.working_tree_status
    actual_status === :probe_failed &&
        return reason(:source_read_or_git_probe_failed, :source_status_probe_failed)
    actual_work_path = actual_status === :clean ? :present : :absent_untracked
    actual_work_path == locator.working_tree_path_status || return :working_tree_path_status_mismatch
    actual_status == locator.working_tree_status || return :working_tree_status_mismatch

    observation.tree_entry_count > 1 && return :head_path_missing
    observation.tree_entry_count == 1 && observation.tree_entry_path != locator.source_path &&
        return :head_path_missing

    if observation.head_path_status === :absent
        family === :g3 && locator.head_path_status != :absent_untracked &&
            return :head_path_status_mismatch
        observation.tracked_entry_count == 0 && observation.tracked_entry_status === :missing ||
            return :tracked_path_mismatch
        observation.verbose_flag_status === :no_entry || return :index_flags_malformed
        locator.head_blob_sha256 === nothing || return :head_blob_sha256_mismatch
        actual_status === :untracked || return :source_authority_missing
        return :source_authority_missing
    end
    observation.tracked_entry_count != 1 && return :tracked_path_missing
    observation.tracked_entry_status === :missing && return :tracked_path_missing
    observation.tracked_entry_status === :malformed && return :tracked_entry_malformed
    observation.tracked_entry_status === :unmerged && return :tracked_entry_unmerged
    observation.tracked_entry_status === :path_mismatch && return :tracked_path_mismatch
    observation.tracked_entry_status === :stage0 || return :tracked_entry_malformed
    observation.tracked_entry_path == locator.source_path || return :tracked_path_mismatch
    observation.index_stage === 0 || return :tracked_entry_unmerged
    observation.verbose_entry_count != 1 && return :tracked_path_missing
    observation.verbose_flag_status === :assume_unchanged && return :index_assume_unchanged
    observation.verbose_flag_status === :skip_worktree && return :index_skip_worktree
    observation.verbose_flag_status === :malformed && return :index_flags_malformed
    observation.verbose_flag_status === :no_entry && return :tracked_path_missing
    observation.debug_index_status === :probe_failed && return :index_flags_probe_failed
    observation.debug_index_status === :malformed && return :index_flags_malformed
    (observation.index_flags & UInt32(0x8000)) != 0 && return :index_assume_unchanged
    (observation.index_flags & UInt32(0x4000)) != 0 && return :index_skip_worktree
    observation.index_flags == 0 || return :index_flags_malformed

    observation.head_blob_status === :probe_failed && return :head_blob_probe_failed
    observation.head_blob_status === :read_failed && return :head_blob_read_failed
    observation.head_blob_status === :bytes_mismatch && return :head_blob_bytes_mismatch
    observation.head_blob_status === :size_mismatch && return :head_blob_bytes_mismatch
    observation.head_blob_status === :sha_mismatch && return :head_blob_sha256_mismatch
    observation.head_blob_status === :valid || return :head_blob_read_failed
    head = observation.head_bytes_key === nothing ? nothing : frozen_source(context, observation.head_bytes_key)
    head === nothing && return :head_blob_read_failed
    head.role == "head_canonical" || throw(ArgumentError("frozen HEAD byte role must be head_canonical"))
    observation.head_bytes_bytes == head.byte_count || return :head_blob_bytes_mismatch
    observation.head_bytes_sha256 == head.sha256 || return :head_blob_sha256_mismatch
    observation.head_blob_oid === nothing && return :head_blob_probe_failed
    git_blob_header = codeunits("blob $(length(head.bytes))\0")
    git_blob_oid = bytes2hex(SHA.sha1(vcat(collect(git_blob_header), head.bytes)))
    git_blob_oid == observation.head_blob_oid || return :head_blob_bytes_mismatch
    length(head.bytes) == locator.source_bytes || return :head_blob_bytes_mismatch
    digest = bytes2hex(SHA.sha256(head.bytes))
    digest == _frozen_digest_value(locator.source_sha256) ==
        _frozen_digest_value(locator.head_blob_sha256) || return :head_blob_sha256_mismatch

    if observation.filter_status in (:startup_failure, :nonzero_failure) ||
            observation.attributes_status === :probe_failed ||
            observation.filter_recipe_status in (:startup_failure, :nonzero_failure)
        return :working_tree_filtered_blob_mismatch
    end
    observation.filter_status in (:matches, :mismatch) ||
        return :working_tree_filtered_blob_mismatch
    (observation.attributes_status === :present) == (observation.attributes_key !== nothing) ||
        return :working_tree_filtered_blob_mismatch
    (observation.filter_recipe_status === :present) == (observation.filter_recipe_key !== nothing) ||
        return :working_tree_filtered_blob_mismatch
    for (key, expected_role) in ((observation.attributes_key, "git_attributes"),
            (observation.filter_recipe_key, "clean_filter_recipe"),
            (observation.filter_output_key, "clean_filter_output"))
        key === nothing && expected_role == "clean_filter_output" &&
            return :working_tree_filtered_blob_mismatch
        key === nothing && continue
        input = frozen_source(context, key)
        input === nothing && return :working_tree_filtered_blob_mismatch
        input.role == expected_role || throw(ArgumentError("frozen clean-filter evidence role mismatch"))
    end
    output = frozen_source(context, observation.filter_output_key)
    output.byte_count == observation.filter_output_bytes ||
        return :working_tree_filtered_blob_mismatch
    output.sha256 == observation.filter_output_sha256 ||
        return :working_tree_filtered_blob_mismatch
    observation.filter_status === :matches && output.bytes == head.bytes ||
        return :working_tree_filtered_blob_mismatch
    bytes2hex(SHA.sha256(output.bytes)) == observation.filter_output_sha256 ||
        return :working_tree_filtered_blob_mismatch
    if stage === :git_only
        observation.worktree_path_kind in (:missing, :directory, :other) && return :source_file_missing
        observation.worktree_path_kind in (:unreadable, :symlink, :alias) && return :source_read_failed
        observation.worktree_path_kind === :regular_file || return :source_file_missing
    end
    actual_status === :clean || return :working_tree_dirty
    nothing
end

"""Validate source bytes from the protocol-neutral UP1 freeze; never query Git."""
function frozen_source_validation(context::UP1FrozenSourceContextV1, locator;
        family::Symbol=:g1, stage::Symbol=:full)
    up1_frozen_runtime_active() || return :up1_frozen_runtime_guard_inactive
    try _up1_require_active_identity(context) catch; return :up1_frozen_context_not_active end
    stage === :full || throw(ArgumentError("UP1 frozen source validation supports full byte validation only"))
    family in (:g1, :g2, :g3) || throw(ArgumentError("unsupported UP1 source family"))
    provenance = if family === :g3
        :up1_frozen_snapshot  # G3 locator has no provenance field; the UP1 context supplies it.
    else
        value = try getproperty(locator, :provenance) catch; return :locator_provenance_missing end
        value in (:up1_frozen_snapshot, :isolated_test_fixture) ||
            return :locator_provenance_mismatch
        value
    end
    if provenance === :up1_frozen_snapshot
        statuses = try (getproperty(locator, :head_path_status),
            getproperty(locator, :working_tree_path_status),
            getproperty(locator, :working_tree_status)) catch; return :locator_git_status_claim_invalid end
        statuses == (:not_observed, :not_observed, :not_observed) ||
            return :locator_git_status_claim_invalid
        blob = try getproperty(locator, :head_blob_sha256) catch; return :locator_git_blob_claim_invalid end
        blob === nothing || return :locator_git_blob_claim_invalid
    end
    observed_head = try String(getproperty(locator, :observed_head)) catch; return :snapshot_identity_mismatch end
    observed_head == "up1:" * context.snapshot_id || return :snapshot_identity_mismatch
    root = try String(getproperty(locator, :repository_root)) catch; return :repository_root_invalid end
    isabspath(root) || return :repository_root_invalid
    root = normpath(root)
    root == context.source_root || return :repository_root_mismatch
    path = try String(getproperty(locator, :source_path)) catch; return :source_path_mismatch end
    try _frozen_logical_path(path, "UP1 locator source_path") catch; return :source_path_mismatch end
    entry = try frozen_source(context, path) catch; return :source_read_failed end
    entry === nothing && return family === :g3 ? :source_authority_missing : :source_file_missing
    entry.role in ("fixture_data", "test_fixture", "synthetic_fixture") &&
        return :source_authority_missing
    locator_bytes = try Int(getproperty(locator, :source_bytes)) catch; return :source_read_failed end
    locator_sha = try lowercase(string(getproperty(locator, :source_sha256))) catch; return :source_read_failed end
    locator_bytes == entry.byte_count || return :source_bytes_mismatch
    locator_sha == entry.sha256 || return :source_sha256_mismatch
    nothing
end

"""Read bytes from the caller-supplied live source root using a repository-relative path."""
function current_source(source_root::AbstractString, logical_path::AbstractString)
    root = realpath(String(source_root))
    path = replace(String(logical_path), '\\' => '/')
    isempty(path) && throw(ArgumentError("current source path is empty"))
    isabspath(path) && throw(ArgumentError("current source path must be relative"))
    parts = split(path, '/'; keepempty=true)
    any(part -> isempty(part) || part in (".", ".."), parts) &&
        throw(ArgumentError("current source path is not canonical"))
    full = joinpath(root, split(path, '/')...)
    islink(full) && throw(ArgumentError("current source file cannot be a link"))
    isfile(full) || throw(ArgumentError("current source file is missing"))
    real = realpath(full)
    relative = relpath(real, root)
    (isabspath(relative) || first(splitpath(relative)) == "..") &&
        throw(ArgumentError("current source escapes its root"))
    raw = read(real)
    (logical_path=path, byte_count=length(raw), sha256=bytes2hex(SHA.sha256(raw)), bytes=raw)
end

"""Re-read the real current source path and compare locator byte claims."""
function current_source_validation(source_root::AbstractString, locator; family::Symbol=:g1)
    family in (:g1, :g2, :g3) || throw(ArgumentError("unsupported current source family"))
    root = try realpath(String(getproperty(locator, :repository_root))) catch; return :repository_root_invalid end
    root == realpath(String(source_root)) || return :repository_root_mismatch
    path = try String(getproperty(locator, :source_path)) catch; return :source_path_mismatch end
    entry = try current_source(source_root, path) catch; return :source_read_failed end
    try
        statuses = (getproperty(locator, :head_path_status),
            getproperty(locator, :working_tree_path_status), getproperty(locator, :working_tree_status))
        statuses == (:not_observed, :not_observed, :not_observed) || return :current_source_git_claim_invalid
        getproperty(locator, :head_blob_sha256) === nothing || return :current_source_git_claim_invalid
        Int(getproperty(locator, :source_bytes)) == entry.byte_count || return :source_bytes_mismatch
        lowercase(string(getproperty(locator, :source_sha256))) == entry.sha256 || return :source_sha256_mismatch
        family === :g3 || getproperty(locator, :provenance) === :current_source || return :locator_provenance_mismatch
    catch
        return :source_read_failed
    end
    nothing
end

function capture_git(root::AbstractString, args...; as_bytes::Bool=false)
    _guard_legacy_git_access("capture_git")
    argv = String["git", "-C", String(root), String.(args)...]
    _record_cli_launch!()
    ManagedExternalProcessV1.capture(Cmd(argv); as_bytes=as_bytes)
end

function _has_git_context_override()
    for key in keys(ENV)
        startswith(key, "GIT_") && key != "GIT_PAGER" && return true
    end
    false
end

function _relative_git_path(path::AbstractString)
    raw = String(path)
    occursin('\\', raw) && throw(ArgumentError("Git source path must use canonical slash separators"))
    isabspath(raw) && throw(ArgumentError("Git source path must be repository-relative"))
    parts = split(raw, '/'; keepempty=true)
    isempty(raw) && throw(ArgumentError("Git source path is empty"))
    any(part -> isempty(part) || part == "." || part == "..", parts) &&
        throw(ArgumentError("Git source path is not canonical"))
    raw
end

function _native_git_path_supported(path::AbstractString)
    occursin(r"^[A-Za-z0-9._/-]+$", path) && !startswith(path, "-")
end

function open_repository(root::AbstractString)
    _guard_legacy_git_access("open_repository")
    canonical_root = realpath(String(root))
    _record_native_repository_read!()
    LibGit2.GitRepo(canonical_root)
end

function _path_present_or_link(path::AbstractString)
    ispath(path) || islink(path)
end

function _native_config(repo::LibGit2.GitRepo)
    _guard_legacy_git_access("_native_config")
    _record_native_repository_read!()
    config = LibGit2.GitConfig(repo)
    iter = nothing
    entries = Dict{String,Vector{String}}()
    try
        iter = LibGit2.GitConfigIter(config)
        for entry in iter
            entry.include_depth == 0 || return nothing
            name = lowercase(unsafe_string(entry.name))
            value = strip(unsafe_string(entry.value))
            push!(get!(entries, name, String[]), value)
        end
        entries
    finally
        iter === nothing || close(iter)
        close(config)
    end
end

function _native_config_bool(values::Dict{String,Vector{String}}, key::String)
    found = get(values, key, String[])
    isempty(found) && return false
    normalized = lowercase.(strip.(found))
    all(value -> value in ("true", "yes", "on", "1"), normalized) && return true
    all(value -> value in ("false", "no", "off", "0"), normalized) && return false
    nothing
end

function _refs_tree_has_link(root::AbstractString)
    _path_present_or_link(root) || return false
    islink(root) && return true
    for (directory, subdirectories, files) in walkdir(root; follow_symlinks=false)
        for name in (subdirectories..., files...)
            islink(joinpath(directory, name)) && return true
        end
    end
    false
end

function _native_repository_supported(repo::LibGit2.GitRepo)
    _guard_legacy_git_access("_native_repository_supported")
    _record_native_repository_read!()
    try
        workdir = realpath(LibGit2.workdir(repo))
        gitdir = realpath(LibGit2.gitdir(repo))
        expected_gitdir = realpath(joinpath(workdir, ".git"))
        lowercase(normpath(gitdir)) == lowercase(normpath(expected_gitdir)) || return false
        islink(joinpath(workdir, ".git")) && return false
        isdir(gitdir) || return false

        # Git can resolve revisions through replacement refs, grafts, shallow
        # boundaries, linked-worktree common dirs, and alternate object stores.
        # LibGit2's direct tree/object reads do not prove the same view in those
        # repositories, so preserve the original managed CLI query sequence.
        for relative in ("commondir", "info/grafts", "shallow",
                         "objects/info/alternates", "objects/info/http-alternates",
                         "refs/replace")
            _path_present_or_link(joinpath(gitdir, relative)) && return false
        end
        for relative in ("HEAD", "objects", "objects/info")
            islink(joinpath(gitdir, relative)) && return false
        end
        _refs_tree_has_link(joinpath(gitdir, "refs")) && return false

        packed_refs = joinpath(gitdir, "packed-refs")
        if _path_present_or_link(packed_refs)
            isfile(packed_refs) && !islink(packed_refs) || return false
            any(line -> occursin(r"^[0-9a-fA-F]{40} refs/replace/", line), eachline(packed_refs)) &&
                return false
        end

        pack_dir = joinpath(gitdir, "objects", "pack")
        if _path_present_or_link(pack_dir)
            isdir(pack_dir) && !islink(pack_dir) || return false
            any(name -> endswith(lowercase(name), ".promisor"), readdir(pack_dir)) && return false
        end

        config_path = joinpath(gitdir, "config")
        _path_present_or_link(config_path) && (!isfile(config_path) || islink(config_path)) &&
            return false
        values = _native_config(repo)
        values isa Dict{String,Vector{String}} || return false

        haskey(values, "core.worktree") && return false
        bare = _native_config_bool(values, "core.bare")
        bare === nothing && return false
        bare && return false
        format_versions = get(values, "core.repositoryformatversion", String["0"])
        all(value -> strip(value) == "0", format_versions) || return false

        for (name, configured) in values
            startswith(name, "include.") && return false
            startswith(name, "includeif.") && return false
            name == "safe.directory" && return false
            if startswith(name, "extensions.")
                name == "extensions.objectformat" &&
                    all(value -> lowercase(strip(value)) == "sha1", configured) && continue
                return false
            end
        end
        true
    catch
        # Metadata uncertainty is not a new rejection. Keep the original CLI
        # path, whose result and failure ordering remain authoritative.
        false
    end
end

function _native_index_supported(repo::LibGit2.GitRepo)
    _guard_legacy_git_access("_native_index_supported")
    _record_native_repository_read!()
    try
        values = _native_config(repo)
        values isa Dict{String,Vector{String}} || return false
        for key in ("core.ignorecase", "core.sparsecheckout", "index.sparse", "core.splitindex")
            setting = _native_config_bool(values, key)
            setting === nothing && return false
            setting && return false
        end
        true
    catch
        false
    end
end

function with_repo(f::Function, root::AbstractString)
    repo = open_repository(root)
    try
        f(repo)
    finally
        close(repo)
    end
end

function repository_root(repo::LibGit2.GitRepo)
    _guard_legacy_git_access("repository_root")
    _record_native_repository_read!()
    realpath(LibGit2.workdir(repo))
end

function repository_root(root::AbstractString)
    with_repo(root) do repo
        repository_root(repo)
    end
end

function head_oid(repo::LibGit2.GitRepo)
    _guard_legacy_git_access("head_oid")
    _record_native_repository_read!()
    value = lowercase(string(LibGit2.head_oid(repo)))
    occursin(r"^[0-9a-f]{40}$", value) ||
        throw(ArgumentError("Repository HEAD is not a supported SHA-1 object id"))
    value
end

function head_oid(root::AbstractString)
    with_repo(root) do repo
        head_oid(repo)
    end
end

function _find_tree_entry(tree::LibGit2.GitTree, name::String)
    _guard_legacy_git_access("_find_tree_entry")
    _record_native_repository_read!()
    for i in 1:LibGit2.count(tree)
        entry = tree[i]
        LibGit2.filename(entry) == name && return entry
    end
    nothing
end

function head_snapshot(repo::LibGit2.GitRepo, source_path::AbstractString)
    _guard_legacy_git_access("head_snapshot")
    _record_native_repository_read!()
    path = _relative_git_path(source_path)
    oid = LibGit2.head_oid(repo)
    head = lowercase(string(oid))
    occursin(r"^[0-9a-f]{40}$", head) ||
        throw(ArgumentError("Repository HEAD is not a supported SHA-1 object id"))
    commit = LibGit2.GitCommit(repo, oid)
    tree = nothing
    trees = LibGit2.GitTree[]
    try
        tree = LibGit2.GitTree(commit)
        push!(trees, tree)
        current = tree
        parts = split(path, '/')
        for (position, part) in enumerate(parts)
            entry = _find_tree_entry(current, part)
            if entry === nothing
                return (head=head, path=path, path_status=:absent_untracked,
                        kind=:missing, mode=nothing, blob_oid=nothing, bytes=nothing)
            end
            mode = UInt32(LibGit2.filemode(entry))
            object_type = LibGit2.entrytype(entry)
            object_oid = lowercase(string(LibGit2.entryid(entry)))
            occursin(r"^[0-9a-f]{40}$", object_oid) ||
                throw(ArgumentError("Tree entry is not a supported SHA-1 object id"))
            if position < length(parts)
                object_type === LibGit2.GitTree ||
                    return (head=head, path=path, path_status=:absent_untracked,
                            kind=:missing, mode=nothing, blob_oid=nothing, bytes=nothing)
                current = LibGit2.GitTree(entry)
                push!(trees, current)
                continue
            end
            if object_type === LibGit2.GitBlob
                blob = LibGit2.GitBlob(entry)
                try
                    return (head=head, path=path, path_status=:present, kind=:blob,
                            mode=mode, blob_oid=lowercase(string(LibGit2.GitHash(blob))),
                            bytes=LibGit2.rawcontent(blob))
                finally
                    close(blob)
                end
            end
            kind = object_type === LibGit2.GitTree ? :tree : :other
            return (head=head, path=path, path_status=:present, kind=kind,
                    mode=mode, blob_oid=object_oid, bytes=nothing)
        end
        throw(ArgumentError("Git source path lookup did not produce a result"))
    finally
        for item in reverse(trees)
            close(item)
        end
        close(commit)
    end
end

function head_blob(root::AbstractString, source_path::AbstractString)
    _guard_legacy_git_access("head_blob")
    path = _relative_git_path(source_path)
    if !_has_git_context_override() && _native_git_path_supported(path)
        snapshot = try
            with_repo(root) do repo
                _native_repository_supported(repo) || return nothing
                head_snapshot(repo, path)
            end
        catch err
            err isa InterruptException && rethrow()
            nothing
        end
        snapshot === nothing || return snapshot
    end

    head = _managed_git_text(root, "rev-parse", "HEAD")
    head isa String || return (head=nothing, path=path, path_status=:absent_untracked,
        kind=:missing, mode=nothing, blob_oid=nothing, bytes=nothing)
    blob_oid = _managed_git_text(root, "rev-parse", "HEAD:" * path)
    blob_oid isa String && occursin(r"^[0-9a-f]{40}$", blob_oid) ||
        return (head=head, path=path, path_status=:absent_untracked,
            kind=:missing, mode=nothing, blob_oid=nothing, bytes=nothing)
    bytes = _managed_git_bytes(root, "show", "HEAD:" * path)
    bytes isa Vector{UInt8} || return (head=head, path=path, path_status=:present,
        kind=:blob, mode=nothing, blob_oid=blob_oid, bytes=nothing)
    return (head=head, path=path, path_status=:present, kind=:blob,
        mode=nothing, blob_oid=blob_oid, bytes=bytes)
end

function _native_git_text(repo::LibGit2.GitRepo, args::Vector{String})
    _guard_legacy_git_access("_native_git_text")
    if args == ["rev-parse", "--show-toplevel"]
        return repository_root(repo)
    elseif args == ["rev-parse", "HEAD"]
        return head_oid(repo)
    elseif length(args) == 2 && args[1] == "rev-parse" && startswith(args[2], "HEAD:")
        path = args[2][6:end]
        _native_git_path_supported(path) || return nothing
        snapshot = head_snapshot(repo, path)
        snapshot.path_status === :present || return nothing
        return snapshot.blob_oid
    elseif length(args) == 4 && args[1] == "ls-files" && args[2] == "--stage" && args[3] == "--"
        _native_git_path_supported(args[4]) || return nothing
        _native_index_supported(repo) || return nothing
        rows = index_rows(repo, args[4])
        all(row -> _native_git_path_supported(row.path), rows) || return nothing
        lines = String[]
        for row in rows
            mode = string(row.mode; base=8)
            mode = lpad(mode, 6, '0')
            push!(lines, mode * " " * row.oid * " " * string(row.stage) * "\t" * row.path)
        end
        return join(lines, "\n")
    end
    nothing
end

function index_rows(repo::LibGit2.GitRepo, source_path::AbstractString)
    _guard_legacy_git_access("index_rows")
    _record_native_repository_read!()
    path = _relative_git_path(source_path)
    prefix = path * "/"
    index = LibGit2.GitIndex(repo)
    try
        LibGit2.read!(index, true)
        rows = NamedTuple[]
        for i in 1:LibGit2.count(index)
            entry = index[i]
            entry === nothing && throw(ArgumentError("Git index returned an empty entry"))
            entry_path = unsafe_string(entry.path)
            if entry_path == path || startswith(entry_path, prefix)
                push!(rows, (path=entry_path, mode=UInt32(entry.mode),
                    oid=lowercase(string(entry.id)), stage=Int(LibGit2.stage(entry)),
                    flags=UInt16(entry.flags), flags_extended=UInt16(entry.flags_extended)))
            end
        end
        sort!(rows; by=row -> (row.path, row.stage))
        rows
    finally
        close(index)
    end
end

function _managed_git_text(root::AbstractString, args...)
    _guard_legacy_git_access("_managed_git_text")
    captured = capture_git(root, args...; as_bytes=false)
    typeof(captured.exit_code) === Int && captured.exit_code == 0 || return nothing
    captured.stdout isa AbstractString || return nothing
    chomp(String(captured.stdout))
end

function _managed_git_bytes(root::AbstractString, args...)
    _guard_legacy_git_access("_managed_git_bytes")
    captured = capture_git(root, args...; as_bytes=true)
    typeof(captured.exit_code) === Int && captured.exit_code == 0 || return nothing
    captured.stdout isa Vector{UInt8} || return nothing
    captured.stdout
end

function git_text(root::AbstractString, args...)
    _guard_legacy_git_access("git_text")
    parts = String.(args)
    if !_has_git_context_override()
        supported_query = parts == ["rev-parse", "--show-toplevel"] || parts == ["rev-parse", "HEAD"] ||
            (length(parts) == 2 && parts[1] == "rev-parse" && startswith(parts[2], "HEAD:")) ||
            (length(parts) == 4 && parts[1] == "ls-files" && parts[2] == "--stage" && parts[3] == "--")
        if supported_query
            result = try
                with_repo(root) do repo
                    _native_repository_supported(repo) || return nothing
                    _native_git_text(repo, parts)
                end
            catch err
                err isa InterruptException && rethrow()
                nothing
            end
            result === nothing || return result
        end
    end
    _managed_git_text(root, parts...)
end

function _native_git_bytes(repo::LibGit2.GitRepo, args::Vector{String})
    _guard_legacy_git_access("_native_git_bytes")
    if length(args) == 2 && args[1] == "show" && startswith(args[2], "HEAD:")
        path = args[2][6:end]
        _native_git_path_supported(path) || return nothing
        snapshot = head_snapshot(repo, path)
        snapshot.path_status === :present && snapshot.kind === :blob || return nothing
        snapshot.bytes isa Vector{UInt8} || return nothing
        return snapshot.bytes
    elseif length(args) == 3 && args[1] == "cat-file" && args[2] == "blob" &&
            occursin(r"^[0-9a-fA-F]{40}$", args[3])
        _record_native_repository_read!()
        blob = LibGit2.GitBlob(repo, LibGit2.GitHash(args[3]))
        try
            LibGit2.rawcontent(blob)
        finally
            close(blob)
        end
    end
    nothing
end

function git_bytes(root::AbstractString, args...)
    _guard_legacy_git_access("git_bytes")
    parts = String.(args)
    if !_has_git_context_override()
        supported_query = (length(parts) == 2 && parts[1] == "show" && startswith(parts[2], "HEAD:")) ||
            (length(parts) == 3 && parts[1] == "cat-file" && parts[2] == "blob" &&
             occursin(r"^[0-9a-fA-F]{40}$", parts[3]))
        if supported_query
            result = try
                with_repo(root) do repo
                    _native_repository_supported(repo) || return nothing
                    _native_git_bytes(repo, parts)
                end
            catch err
                err isa InterruptException && rethrow()
                nothing
            end
            result === nothing || return result
        end
    end
    _managed_git_bytes(root, parts...)
end

function __init__()
    _runtime_formal_bootstrap!()
    nothing
end

if ccall(:jl_generating_output, Cint, ()) == 0
    _runtime_formal_bootstrap!()
end

end # module NativeGitReadCompatibilityV1
