using SHA
using JSON3
using Dates

const _R12_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _R12_EVIDENCE_ENV = "VNEXT_T1_V1_ISOLATION_EVIDENCE_REL"
const _R12_ORIGINAL_REL = "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl"
const _R12_ORIGINAL = joinpath(_R12_ROOT, splitpath(_R12_ORIGINAL_REL)...)
const _R12_EXPECTED_BYTES = 12_975
const _R12_EXPECTED_SHA256 = "970976C4122FC6B4F5303D6763C286514B1C9DC653ABA36D46E1D003BCBF9669"
const _R12_LARGE_PAYLOAD = 8_269_445
const _R12_EXPECTED_MULTIPLICITY_STATUS = "typed_unknown"
const _R12_EXPECTED_MULTIPLICITY_REASON = "source helper invocation multiplicity is not statically bounded"
const _R12_MARKERS = (
    "UP1_04A_VNEXT_T1_LOCAL_STATUS=prepared_not_executed",
    "UP1_04A_VNEXT_T1_LOCAL_ACCEPTED=false",
    "UP1_04A_VNEXT_T1_LOCAL_CLAIM_CEILING=contract_only",
    "UP1_04A_VNEXT_T1_LOCAL_T2_UP2_R_CREDIT=false",
    "UP1_04A_VNEXT_T1_LOCAL_NEGATIVE_CASES=9",
)
const _R12_PROTECTED = (
    _R12_ORIGINAL_REL,
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "test/GenomeV5/Integration/vnext_t1_projection_diagnostic_v1.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
    "src/Contracts/CandidateStatePackageV5Next.jl",
    "src/GenomeV5/Integration/VNextGenomeV5Integration.jl",
    "src/Contracts/VNextT1PackageBindingAdapterV1.jl",
    "src/Contracts/VNextT1CandidateBindingV2.jl",
    "src/FusionConceptAI.jl",
    "src/Contracts/GenomeContractRegistry.jl",
    "src/IR/OperatorRegistry.jl",
)

_r12_hex(v) = uppercase(bytes2hex(v))
_r12_hash_bytes(v) = _r12_hex(sha256(v))
_r12_hash_text(s) = _r12_hash_bytes(Vector{UInt8}(codeunits(s)))

function _r12_write_json(path, value)
    open(path, "w") do io
        JSON3.write(io, value)
    end
end

function _r12_read_json(path)
    JSON3.read(read(path, String))
end

function _r12_validate_evidence_rel(rel)
    isempty(strip(rel)) && error("insufficient_evidence: evidence root environment value is empty")
    isabspath(rel) && error("insufficient_evidence: evidence root must be relative")
    parts = splitpath(rel)
    any(part -> part == "..", parts) &&
        error("insufficient_evidence: evidence root traversal is forbidden")
    candidate = normpath(joinpath(_R12_ROOT, parts...))
    relative = relpath(candidate, _R12_ROOT)
    (relative == ".." || startswith(relative, ".." * string('\\')) ||
        startswith(relative, ".." * string('/'))) &&
        error("insufficient_evidence: evidence root resolves outside repository")
    ispath(candidate) &&
        error("insufficient_evidence: evidence root already exists")
    candidate
end

function _r12_prepare_evidence_root()
    rel = get(ENV, _R12_EVIDENCE_ENV, "")
    candidate = _r12_validate_evidence_rel(rel)
    mkpath(candidate)
    candidate
end

function _r12_source()
    isfile(_R12_ORIGINAL) || error("insufficient_evidence: original test missing")
    bytes = read(_R12_ORIGINAL)
    length(bytes) == _R12_EXPECTED_BYTES ||
        error("insufficient_evidence: original byte length changed")
    digest = _r12_hash_bytes(bytes)
    digest == _R12_EXPECTED_SHA256 ||
        error("insufficient_evidence: original test SHA changed: $digest")
    bytes, String(copy(bytes))
end

function _r12_macro_name(x)
    x isa Expr && x.head === :macrocall && !isempty(x.args) ? string(x.args[1]) : ""
end

function _r12_line(x)
    if length(x.args) >= 2 && x.args[2] isa LineNumberNode
        return Int(x.args[2].line)
    end
    return 0
end

function _r12_collect(x, out)
    if x isa Expr
        name = _r12_macro_name(x)
        if name === "@test" || name === "@test_throws"
            push!(out, (id="r12-" * lpad(string(length(out) + 1), 3, '0'),
                macro_name=name, line=_r12_line(x),
                expression_hash=_r12_hash_text(sprint(show, x))))
        end
        for arg in x.args
            _r12_collect(arg, out)
        end
    end
    out
end

function _r12_marker_call(x)
    if !(x isa Expr && x.head === :call && !isempty(x.args) && x.args[1] === :println)
        return false
    end
    for marker in _R12_MARKERS
        if occursin(marker, sprint(show, x))
            return true
        end
    end
    false
end

function _r12_transform(x, target_id, cursor)
    if x isa Expr
        name = _r12_macro_name(x)
        if name === "@test" || name === "@test_throws"
            cursor[] += 1
            id = "r12-" * lpad(string(cursor[]), 3, '0')
            literal = QuoteNode(id)
            record = Expr(:call, :__r12_record, literal)
            condition = Expr(:call, :(==), :__R12_TARGET_ID, literal)
            # The original macrocall is inserted unchanged. Only the dispatch
            # guard is additive; assertion syntax and operands are untouched.
            return Expr(:if, condition, Expr(:block, record, x), nothing)
        elseif _r12_marker_call(x)
            return nothing
        end
        return Expr(x.head, map(arg -> _r12_transform(arg, target_id, cursor), x.args)...)
    end
    x
end

function _r12_ast_manifest(source)
    ast = Meta.parseall(source)
    rows = Any[]
    _r12_collect(ast, rows)
    isempty(rows) && error("insufficient_evidence: AST contains no assertions")
    rows
end

function _r12_git_status()
    try
        return readchomp(`git -C $(_R12_ROOT) status --porcelain=v1`)
    catch
        return "git_status_unavailable"
    end
end

function _r12_git_names()
    try
        return readchomp(`git -C $(_R12_ROOT) diff --name-only`)
    catch
        return "git_diff_names_unavailable"
    end
end

function _r12_protected_hashes()
    result = Dict{String, Any}()
    for rel in _R12_PROTECTED
        path = joinpath(_R12_ROOT, splitpath(rel)...)
        result[rel] = isfile(path) ?
            (bytes=length(read(path)), sha256=_r12_hash_bytes(read(path))) :
            (missing=true,)
    end
    result
end

function _r12_dry_transform_source(source, target_id, rows)
    ast = Meta.parseall(source)
    cursor = Ref(0)
    transformed = _r12_transform(ast, target_id, cursor)
    cursor[] == length(rows) || error("insufficient_evidence: AST traversal drift")
    # Verify the selected original node hash before any child execution.
    selected = rows[findfirst(row -> row.id == target_id, rows)]
    selected_hashes = Any[]
    _r12_collect(transformed, selected_hashes)
    selected_hash = selected_hashes[findfirst(row -> row.id == target_id, selected_hashes)].expression_hash
    selected_hash == selected.expression_hash ||
        error("insufficient_evidence: selected assertion expression hash drift")
    (transformed=transformed, cursor=cursor[])
end

global __R12_TARGET_ID = ""
global __R12_RUNTIME_IDS = String[]
function __r12_record(id)
    push!(__R12_RUNTIME_IDS, id)
    nothing
end

function _r12_validate_runtime_ids(target_id)
    ids = copy(__R12_RUNTIME_IDS)
    isempty(ids) && error("insufficient_evidence: child recorded zero runtime assertion hits")
    all(id -> id == target_id, ids) ||
        error("insufficient_evidence: child runtime assertion id differs from target")
    length(ids) >= 1 || error("insufficient_evidence: child runtime hit count is zero")
    ids
end

function _r12_source_record(bytes)
    n = length(bytes)
    digest = _r12_hash_bytes(bytes)
    (bytes=n, length=n, sha256=digest)
end

function _r12_stdout_field(text, prefix)
    for line in split(text, '\n')
        line = chomp(line)
        if startswith(line, prefix * "=")
            parts = split(line, '='; limit=2)
            return length(parts) == 2 ? parts[2] : ""
        end
    end
    nothing
end

function _r12_parse_child_ledger(row, child)
    text = isfile(child.stdout) ? read(child.stdout, String) : ""
    ids_raw = _r12_stdout_field(text, "R12_CHILD_RUNTIME_ASSERTION_IDS")
    runtime_ids = ids_raw === nothing || isempty(ids_raw) ? String[] : split(ids_raw, ',')
    hit_raw = _r12_stdout_field(text, "R12_CHILD_RUNTIME_HIT_COUNT")
    hit_count = hit_raw === nothing ? nothing : tryparse(Int, hit_raw)
    target_marker = _r12_stdout_field(text, "R12_CHILD_TARGET")
    unique_marker = _r12_stdout_field(text, "R12_CHILD_UNIQUE_ASSERTION_COUNT")
    multiplicity_marker = _r12_stdout_field(text, "R12_CHILD_EXPECTED_MULTIPLICITY_STATUS")
    source_bytes_marker = _r12_stdout_field(text, "R12_CHILD_SOURCE_BYTES")
    source_sha_marker = _r12_stdout_field(text, "R12_CHILD_SOURCE_SHA256")
    unique_ids = unique(runtime_ids)
    ids_ok = !isempty(runtime_ids) && all(id -> id == row.id, runtime_ids)
    hit_ok = hit_count !== nothing && hit_count >= 1 && hit_count == length(runtime_ids)
    coverage_status = ids_ok && hit_ok ? "pass" : "insufficient_evidence"
    success_stdout_marker = coverage_status == "pass" &&
        target_marker == row.id && unique_marker == "1" &&
        multiplicity_marker == _R12_EXPECTED_MULTIPLICITY_STATUS &&
        source_bytes_marker == string(_R12_EXPECTED_BYTES) &&
        source_sha_marker == _R12_EXPECTED_SHA256
    (target_id=row.id, runtime_assertion_ids=runtime_ids,
        unique_runtime_assertion_ids=unique_ids,
        hit_count=hit_count === nothing ? 0 : hit_count,
        expected_multiplicity=(status=_R12_EXPECTED_MULTIPLICITY_STATUS,
            reason=_R12_EXPECTED_MULTIPLICITY_REASON),
        coverage_status=coverage_status,
        success_stdout_marker=success_stdout_marker,
        marker_target=target_marker, marker_unique_count=unique_marker,
        marker_multiplicity=multiplicity_marker,
        source_bytes=source_bytes_marker, source_sha256=source_sha_marker,
        child_exit_code=child.exit_code, stop_reason=child.stop_reason)
end

function _r12_hash_maps_equal(a, b)
    sort!(collect(keys(a))) == sort!(collect(keys(b))) &&
        all(key -> a[key] == b[key], keys(a))
end

function _r12_run_child(target_id)
    bytes, source = _r12_source()
    rows = _r12_ast_manifest(source)
    any(row -> row.id == target_id, rows) || error("insufficient_evidence: unknown child $target_id")
    global __R12_TARGET_ID = target_id
    global __R12_RUNTIME_IDS = String[]
    dry = _r12_dry_transform_source(source, target_id, rows)
    dry.cursor == length(rows) || error("insufficient_evidence: dry AST cursor drift")
    runtime_cursor = Ref(0)
    mapexpr = expression -> _r12_transform(expression, target_id, runtime_cursor)
    Base.include(mapexpr, Main, _R12_ORIGINAL)
    runtime_cursor[] == length(rows) || error("insufficient_evidence: executable AST cursor drift")
    runtime_ids = _r12_validate_runtime_ids(target_id)
    unique_ids = unique(runtime_ids)
    println("R12_CHILD_TARGET=$target_id")
    println("R12_CHILD_UNIQUE_ASSERTION_COUNT=$(length(unique_ids))")
    println("R12_CHILD_RUNTIME_ASSERTION_IDS=$(join(runtime_ids, ','))")
    println("R12_CHILD_RUNTIME_HIT_COUNT=$(length(runtime_ids))")
    println("R12_CHILD_RUNTIME_INVOCATIONS=$(length(runtime_ids))")
    println("R12_CHILD_EXPECTED_MULTIPLICITY_STATUS=$(_R12_EXPECTED_MULTIPLICITY_STATUS)")
    println("R12_CHILD_SOURCE_BYTES=$(length(bytes))")
    println("R12_CHILD_SOURCE_SHA256=$(_R12_EXPECTED_SHA256)")
    0
end

function _r12_snapshot(pid)
    script = "\$p=Get-Process -Id $pid -ErrorAction SilentlyContinue; if(\$null -eq \$p){'{}'}else{[pscustomobject]@{pid=$pid;utc=[DateTime]::UtcNow.ToString('o');working_set_bytes=[int64]\$p.WorkingSet64;private_bytes=[int64]\$p.PrivateMemorySize64;cpu_seconds=[double]\$p.TotalProcessorTime.TotalSeconds;has_exited=\$p.HasExited}|ConvertTo-Json -Compress}"
    raw = try
        readchomp(`powershell -NoProfile -NonInteractive -Command $script`)
    catch _
        "{}"
    end
    isempty(strip(raw)) ? Dict{String, Any}() : Dict{String, Any}(_r12_read_json_string(raw))
end

function _r12_read_json_string(raw)
    obj = JSON3.read(raw)
    Dict{String, Any}(string(k) => v for (k, v) in pairs(obj))
end

function _r12_spawn_child(root, row)
    id = row.id
    out_path = joinpath(root, "children", id * ".stdout.raw")
    err_path = joinpath(root, "children", id * ".stderr.raw")
    mkpath(dirname(out_path))
    julia = Base.julia_cmd()
    runner = joinpath(@__DIR__, "vnext_t1_v1r12_isolated_regression.jl")
    open(out_path, "w") do out
        open(err_path, "w") do err
            cmd = setenv(`$julia --startup-file=no --history-file=no --project=$(_R12_ROOT) $runner --child $id`,
                "JULIA_NUM_THREADS" => "1")
            started = Dates.now(Dates.UTC)
            proc = run(pipeline(cmd, stdout=out, stderr=err), wait=false)
            pid = getpid(proc)
            samples = Any[]
            peak_ws = Int64(0)
            peak_private = Int64(0)
            stop_reason = "natural_exit"
            while process_running(proc)
                sleep(1.0)
                snap = _r12_snapshot(pid)
                push!(samples, snap)
                ws = haskey(snap, "working_set_bytes") ? Int64(snap["working_set_bytes"]) : Int64(0)
                priv = haskey(snap, "private_bytes") ? Int64(snap["private_bytes"]) : Int64(0)
                peak_ws = max(peak_ws, ws)
                peak_private = max(peak_private, priv)
                if ws >= 2_147_483_648
                    stop_reason = "working_set_hard_ceiling"
                    try kill(proc) catch end
                    break
                end
            end
            wait(proc)
            exit_code = proc.exitcode
            if stop_reason != "natural_exit"
                exit_code = nothing
            end
            _r12_write_json(joinpath(root, "children", id * ".process.json"),
                (id=id, pid=pid, started_utc=string(started), ended_utc=string(Dates.now(Dates.UTC)),
                    exit_code=exit_code, stop_reason=stop_reason, peak_working_set_bytes=peak_ws,
                    peak_private_bytes=peak_private, samples=samples,
                    stdout_bytes=filesize(out_path), stderr_bytes=filesize(err_path)))
            return (id=id, pid=pid, exit_code=exit_code, stop_reason=stop_reason,
                peak_working_set_bytes=peak_ws, peak_private_bytes=peak_private,
                stdout=out_path, stderr=err_path)
        end
    end
end

function _r12_aggregate()
    evidence = _r12_prepare_evidence_root()
    bytes, source = _r12_source()
    rows = _r12_ast_manifest(source)
    source_pre = _r12_source_record(bytes)
    protected_pre = _r12_protected_hashes()
    status_pre = _r12_git_status()
    _r12_write_json(joinpath(evidence, "preflight.json"),
        (task_id="UP1-04A-VNEXT-T1-R12", utc=string(Dates.now(Dates.UTC)),
            original_test=_R12_ORIGINAL_REL, original_bytes=filesize(_R12_ORIGINAL),
            original_sha256=_R12_EXPECTED_SHA256, direct_large_payload=_R12_LARGE_PAYLOAD,
            assertion_count=length(rows), test_count=count(row -> row.macro_name === "@test", rows),
            test_throws_count=count(row -> row.macro_name === "@test_throws", rows),
            markers=collect(_R12_MARKERS), git_status=_r12_git_status(), git_diff_names=_r12_git_names(),
            source_pre=source_pre, protected_hashes=protected_pre,
            actual_model_attestation="unavailable"))
    _r12_write_json(joinpath(evidence, "coverage.json"), rows)
    static_hashes = sort(unique(row.expression_hash for row in rows))
    runtime_ledger = Any[]
    success_markers = Any[]
    expected_multiplicity = Dict(row.id =>
        (status=_R12_EXPECTED_MULTIPLICITY_STATUS, reason=_R12_EXPECTED_MULTIPLICITY_REASON)
        for row in rows)
    _r12_write_json(joinpath(evidence, "coverage_ledger.json"),
        (schema="r13_v1_harness_repair",
            static_assertion_rows=rows,
            static_unique_expression_hashes=static_hashes,
            expected_multiplicity=expected_multiplicity,
            runtime_children=runtime_ledger,
            success_stdout_markers=success_markers,
            source_hashes=(pre=source_pre,),
            aggregate=(fail_fast=true, first_failure=nothing,
                ordered_unrun_target_ids=[row.id for row in rows])))
    results = Any[]
    first_failure = nothing
    unrun_target_ids = String[]
    for (index, row) in enumerate(rows)
        child = _r12_spawn_child(evidence, row)
        ledger = _r12_parse_child_ledger(row, child)
        push!(results, child)
        push!(runtime_ledger, ledger)
        push!(success_markers, (target_id=row.id, success=ledger.success_stdout_marker))
        child_ok = child.exit_code === 0 && child.stop_reason == "natural_exit"
        failure_reason = child_ok && ledger.coverage_status == "pass" &&
            ledger.success_stdout_marker ? nothing :
            (child_ok ? "missing_marker_or_coverage_conflict" : "child_nonzero_or_non_natural_exit")
        if failure_reason !== nothing
            first_failure = (target_id=row.id, index=index, reason=failure_reason,
                child_exit_code=child.exit_code, stop_reason=child.stop_reason,
                coverage_status=ledger.coverage_status)
            if index < length(rows)
                append!(unrun_target_ids, [rows[j].id for j in (index + 1):length(rows)])
            end
            break
        end
    end
    post_hashes = _r12_protected_hashes()
    source_after = read(_R12_ORIGINAL)
    source_post = _r12_source_record(source_after)
    source_unchanged = source_pre.bytes == source_post.bytes &&
        source_pre.length == source_post.length && source_pre.sha256 == source_post.sha256
    protected_hashes_unchanged = _r12_hash_maps_equal(protected_pre, post_hashes)
    status_post = _r12_git_status()
    status_unchanged = status_pre == status_post
    all_exit0 = all(x -> x.exit_code === 0 && x.stop_reason === "natural_exit", results)
    all_coverage = length(runtime_ledger) == length(rows) &&
        all(item -> item.coverage_status == "pass", runtime_ledger)
    all_markers = length(success_markers) == length(rows) &&
        all(item -> item.success, success_markers)
    pass = first_failure === nothing && length(results) == length(rows) &&
        all_exit0 && all_coverage && all_markers && source_unchanged &&
        protected_hashes_unchanged && status_unchanged
    _r12_write_json(joinpath(evidence, "coverage_ledger.json"),
        (schema="r13_v1_harness_repair",
            static_assertion_rows=rows,
            static_unique_expression_hashes=static_hashes,
            expected_multiplicity=expected_multiplicity,
            runtime_children=runtime_ledger,
            success_stdout_markers=success_markers,
            source_hashes=(pre=source_pre, post=source_post),
            aggregate=(fail_fast=true, first_failure=first_failure,
                launched_target_ids=length(results) == 0 ? String[] :
                    [rows[j].id for j in 1:length(results)],
                ordered_unrun_target_ids=unrun_target_ids)))
    _r12_write_json(joinpath(evidence, "postflight.json"),
        (task_id="UP1-04A-VNEXT-T1-R12", utc=string(Dates.now(Dates.UTC)),
            verdict=pass ? "pass" : "insufficient_evidence",
            all_children_natural_exit0=all_exit0, coverage_ledger_pass=all_coverage,
            success_stdout_markers_pass=all_markers,
            source_pre=source_pre, source_post=source_post,
            source_unchanged=source_unchanged,
            protected_hashes_unchanged=protected_hashes_unchanged,
            git_status_unchanged=status_unchanged, pre_protected_hashes=protected_pre,
            post_protected_hashes=post_hashes, child_count=length(rows),
            launched_child_count=length(results), first_failure=first_failure,
            ordered_unrun_target_ids=unrun_target_ids,
            no_monolithic_r10=true, actual_model_attestation="unavailable"))
    if !pass
        error("insufficient_evidence: R12 isolation aggregate failed fast or did not satisfy all gates")
    end
    println("R12 verdict=pass children=$(length(rows)) runtime_target_coverage=true")
    for marker in _R12_MARKERS
        println(marker)
    end
end

function _r12_coverage_only()
    evidence = _r12_prepare_evidence_root()
    bytes, source = _r12_source()
    rows = _r12_ast_manifest(source)
    _r12_write_json(joinpath(evidence, "coverage_preflight.json"),
        (task_id="UP1-04A-VNEXT-T1-R12", utc=string(Dates.now(Dates.UTC)),
            original_test=_R12_ORIGINAL_REL, original_bytes=filesize(_R12_ORIGINAL),
            original_sha256=_R12_EXPECTED_SHA256, direct_large_payload=_R12_LARGE_PAYLOAD,
            assertion_count=length(rows), test_count=count(row -> row.macro_name === "@test", rows),
            test_throws_count=count(row -> row.macro_name === "@test_throws", rows),
            markers=collect(_R12_MARKERS), coverage=rows,
            actual_model_attestation="unavailable"))
    source_record = _r12_source_record(bytes)
    _r12_write_json(joinpath(evidence, "coverage_ledger.json"),
        (schema="r13_v1_harness_repair",
            static_assertion_rows=rows,
            static_unique_expression_hashes=sort(unique(row.expression_hash for row in rows)),
            expected_multiplicity=Dict(row.id =>
                (status=_R12_EXPECTED_MULTIPLICITY_STATUS,
                    reason=_R12_EXPECTED_MULTIPLICITY_REASON) for row in rows),
            runtime_children=Any[], success_stdout_markers=Any[],
            source_hashes=(pre=source_record,),
            aggregate=(fail_fast=true, first_failure=nothing,
                ordered_unrun_target_ids=[row.id for row in rows])))
    println("R12_COVERAGE_PASS assertions=$(length(rows)) test=62 test_throws=1 source_bytes=$(filesize(_R12_ORIGINAL))")
end

if length(ARGS) >= 2 && ARGS[1] == "--child"
    _r12_run_child(ARGS[2])
elseif length(ARGS) >= 1 && ARGS[1] == "--coverage-only"
    _r12_coverage_only()
else
    _r12_aggregate()
end
