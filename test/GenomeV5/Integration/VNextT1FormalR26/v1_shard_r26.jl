using SHA, JSON3, Dates
using FusionConceptAI

include(joinpath(@__DIR__, "path_guard_r26.jl"))

const R26_ROOT = realpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_PROTOCOL_PATH = joinpath(@__DIR__, "protocol_r26_v9.json")
const R26_RUNTIME_IDS = String[]
const R26_SELECTED_IDS = Set{String}()
const R26_G = FusionConceptAI
const R26_V1_SOURCE_CARRIER_ENABLED = Ref(false)
const R26_V1_SOURCE_CARRIER_CALL_COUNT = Ref(0)
const R26_V1_SOURCE_CARRIER_SPEC = Ref{Any}(nothing)
const R26_V1_SOURCE_CARRIER_OBSERVATION = Ref{Any}(nothing)

r26_sha(bytes) = uppercase(bytes2hex(sha256(bytes)))
r26_expr_hash(x) = r26_sha(codeunits(sprint(show, x)))
function r26_semantic_ast(x)
    x isa LineNumberNode && return nothing
    x isa Expr || return x
    Expr(x.head, map(r26_semantic_ast, x.args)...)
end
r26_semantic_expr_hash(x) =
    r26_sha(codeunits(sprint(show, r26_semantic_ast(x))))
r26_test_macro(x) = x isa Expr && x.head === :macrocall &&
    string(x.args[1]) in ("@test", "@test_throws")
r26_testset_macro(x) = x isa Expr && x.head === :macrocall &&
    string(x.args[1]) == "@testset"
r26_target_id(index) = index <= 63 ?
    "r18v2-" * lpad(string(index), 3, '0') :
    "r26-extra-" * lpad(string(index - 63), 3, '0')

function r26_parse(path)
    expression = Meta.parseall(read(path, String))
    function check(x)
        x isa Expr || return
        x.head in (:error, :incomplete) && error("parse error in $path: $x")
        foreach(check, x.args)
    end
    check(expression)
    expression
end

function r26_collect(x, rows=Any[])
    if x isa Expr
        if r26_test_macro(x)
            line = x.args[2] isa LineNumberNode ? x.args[2].line : 0
            push!(rows, (id=r26_target_id(length(rows) + 1), line=line,
                macro_name=string(x.args[1]), expression_hash=r26_expr_hash(x),
                semantic_expression_hash=r26_semantic_expr_hash(x)))
        end
        foreach(child -> r26_collect(child, rows), x.args)
    end
    rows
end

function r26_contains_record(x)
    x isa Expr || return false
    x.head === :call && !isempty(x.args) && x.args[1] === :r26_record && return true
    any(r26_contains_record, x.args)
end

function r26_testset_title(x)
    r26_testset_macro(x) || return nothing
    for arg in x.args[3:end]
        arg isa String && return arg
    end
    nothing
end

function r26_transform(x, selected, cursor)
    if x isa Expr
        if r26_test_macro(x)
            cursor[] += 1
            id = r26_target_id(cursor[])
            id in selected || return nothing
            return Expr(:block, Expr(:call, :r26_record, QuoteNode(id)), x)
        end
        if x.head === :(=) && length(x.args) == 2 && x.args[1] === :fixture &&
                x.args[2] isa Expr && x.args[2].head === :call &&
                !isempty(x.args[2].args) && x.args[2].args[1] === :_t1_fixture
            transformed_fixture = r26_transform(x.args[2], selected, cursor)
            return Expr(:(=), :fixture,
                Expr(:call, :r26_v1_source_carrier_observe, transformed_fixture))
        end
        transformed = Expr(x.head, map(arg -> r26_transform(arg, selected, cursor), x.args)...)
        if r26_testset_macro(x)
            title = r26_testset_title(x)
            carrier_root = title == "T1 direct SHA dispatch and owned bytes"
            carrier_selected = any(id -> id in selected,
                (r26_target_id(i) for i in 1:6))
            (r26_contains_record(transformed) || (carrier_root && carrier_selected)) ||
                return nothing
        end
        return transformed
    end
    x
end

@noinline Base.@nospecializeinfer function r26_v1_source_carrier_observe(
        @nospecialize(fixture))
    R26_V1_SOURCE_CARRIER_ENABLED[] || return fixture
    R26_V1_SOURCE_CARRIER_CALL_COUNT[] += 1
    R26_V1_SOURCE_CARRIER_CALL_COUNT[] == 1 ||
        error("V1 source carrier observation repeated")
    R26_V1_SOURCE_CARRIER_OBSERVATION[] === nothing ||
        error("V1 source carrier observation already exists")

    spec = R26_V1_SOURCE_CARRIER_SPEC[]
    spec === nothing && error("V1 source carrier specification missing")
    canonical_started = time_ns()
    payload = Vector{UInt8}(codeunits(R26_G.canonical_json(fixture.transport)))
    canonical_seconds = (time_ns() - canonical_started) / 1.0e9
    raw_sha256 = lowercase(r26_sha(payload))

    # This is the first VNextT1CanonicalBytesV2 constructor call in the fresh
    # contract process.  The timed operation includes its owned copy and SHA.
    cold_started = time_ns()
    carrier = R26_G.VNextT1CanonicalBytesV2(payload)
    cold_seconds = (time_ns() - cold_started) / 1.0e9
    carrier_bytes = R26_G.byte_length(carrier)
    carrier_sha256 = carrier.sha256.value
    exact_byte_join = R26_G.copy_bytes(carrier) == payload
    expected_bytes = Int(spec.expected_bytes)
    expected_sha256 = String(spec.raw_sha256)
    limit_seconds = Float64(spec.limit_seconds)
    gate_pass = length(payload) == expected_bytes &&
        raw_sha256 == expected_sha256 && carrier_bytes == expected_bytes &&
        carrier_sha256 == expected_sha256 && exact_byte_join &&
        cold_seconds <= limit_seconds
    observation = (schema="vnext_t1_v1_source_carrier_resource_r26_v1",
        first_call_count=R26_V1_SOURCE_CARRIER_CALL_COUNT[],
        operation=String(spec.operation), fixture=String(spec.fixture),
        canonical_seconds=canonical_seconds, cold_seconds=cold_seconds,
        limit_seconds=limit_seconds, actual_bytes=length(payload),
        expected_bytes=expected_bytes, raw_sha256=raw_sha256,
        expected_raw_sha256=expected_sha256, carrier_bytes=carrier_bytes,
        carrier_sha256=carrier_sha256,
        carrier_type=string(typeof(carrier)), exact_byte_join=exact_byte_join,
        gate_pass=gate_pass)
    R26_V1_SOURCE_CARRIER_OBSERVATION[] = observation
    println("R26_V1_SOURCE_CARRIER_ACTUAL_BEFORE_GUARD=", JSON3.write(observation))
    flush(stdout)
    gate_pass || error("V1 source-backed carrier resource gate failed")
    fixture
end

function r26_record(id)
    id in R26_SELECTED_IDS || error("foreign runtime assertion ID: $id")
    push!(R26_RUNTIME_IDS, id)
    println("R26_V1_ASSERTION_HIT id=$id invocation=$(count(==(id), R26_RUNTIME_IDS))")
    flush(stdout)
    nothing
end

function r26_digest(path)
    bytes = read(path)
    (bytes=length(bytes), sha256=r26_sha(bytes))
end

function r26_verify_dependencies(protocol)
    actual = Dict{String,Any}()
    for row in protocol.dependencies
        rel = String(row.path)
        path = r26_guard_existing_repo_file(R26_ROOT, rel;
            label="frozen dependency")
        got = r26_digest(path)
        got.bytes == Int(row.bytes) && got.sha256 == String(row.sha256) ||
            error("frozen dependency drift: $rel")
        actual[rel] = got
    end
    actual
end

function r26_validate_inventory(protocol, successor_path)
    baseline = normpath(joinpath(R26_ROOT, String(protocol.v1.baseline.path)))
    baseline_rows = r26_collect(r26_parse(baseline))
    length(baseline_rows) == 63 || error("baseline target count drift")
    map_path = normpath(joinpath(R26_ROOT, String(protocol.v1.baseline.map_path)))
    frozen_map = JSON3.read(read(map_path, String))
    length(frozen_map.rows) == 63 || error("frozen map target count drift")
    for (parsed, mapped) in zip(baseline_rows, frozen_map.rows)
        parsed.id == String(mapped.baseline_target) || error("baseline target ID drift")
        parsed.line == Int(mapped.source_line) || error("baseline source line drift: $(parsed.id)")
        parsed.expression_hash == String(mapped.source_ast_sha256) ||
            error("baseline AST drift: $(parsed.id)")
    end

    successor_rows = r26_collect(r26_parse(successor_path))
    length(successor_rows) == 70 || error("successor target count drift")
    length(protocol.v1.targets) == 70 || error("protocol target count drift")
    changed = Set(String.(collect(protocol.v1.changed_target_ids)))
    for (parsed, frozen) in zip(successor_rows, protocol.v1.targets)
        parsed.id == String(frozen.id) || error("successor target ID drift")
        parsed.line == Int(frozen.successor_line) || error("successor line drift: $(parsed.id)")
        parsed.expression_hash == String(frozen.successor_ast_sha256) ||
            error("successor AST drift: $(parsed.id)")
        if parsed.id <= "r18v2-063" && !(parsed.id in changed)
            base = baseline_rows[parse(Int, last(split(parsed.id, "-")))]
            parsed.semantic_expression_hash == base.semantic_expression_hash ||
                error("unchanged target altered: $(parsed.id)")
        end
    end
    baseline_rows, successor_rows
end

function r26_ledger_path(value)
    allowed = joinpath(R26_ROOT,
        "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922")
    r26_guard_new_owned_file(R26_ROOT, allowed, value; label="ledger")
end

function r26_arg(name)
    index = findfirst(==(name), ARGS)
    index === nothing && error("missing argument $name")
    index < length(ARGS) || error("missing value for $name")
    ARGS[index + 1]
end

function r26_run()
    Threads.nthreads() == 1 || error("JULIA_NUM_THREADS must be 1")
    shard_name = r26_arg("--shard")
    ledger_path = r26_ledger_path(r26_arg("--ledger"))
    protocol = JSON3.read(read(R26_PROTOCOL_PATH, String))
    protocol.schema == "vnext_t1_independent_formal_r26_protocol_v9" ||
        error("protocol schema mismatch")
    dependency_before = r26_verify_dependencies(protocol)
    successor_path = normpath(joinpath(R26_ROOT, String(protocol.v1.successor.path)))
    _, successor_rows = r26_validate_inventory(protocol, successor_path)
    candidates = [row for row in protocol.v1.shards if String(row.name) == shard_name]
    length(candidates) == 1 || error("unknown or duplicate shard: $shard_name")
    shard = only(candidates)
    selected = String.(collect(shard.target_ids))
    isempty(selected) && error("empty shard")
    length(selected) == length(unique(selected)) || error("duplicate shard target")
    known = Set(row.id for row in successor_rows)
    all(id -> id in known, selected) || error("unknown shard target")
    empty!(R26_SELECTED_IDS); union!(R26_SELECTED_IDS, selected)
    empty!(R26_RUNTIME_IDS)
    R26_V1_SOURCE_CARRIER_ENABLED[] = shard_name == "contract"
    R26_V1_SOURCE_CARRIER_CALL_COUNT[] = 0
    R26_V1_SOURCE_CARRIER_SPEC[] = shard_name == "contract" ?
        protocol.v1.source_carrier_fixture : nothing
    R26_V1_SOURCE_CARRIER_OBSERVATION[] = nothing
    if shard_name == "contract"
        isdefined(R26_G, :VNextT1CanonicalBytesV2) &&
            error("V2 carrier was loaded before the cold resource gate")
        carrier_source = r26_guard_existing_repo_file(R26_ROOT,
            String(protocol.v1.source_carrier_fixture.carrier_source);
            label="V1 source carrier implementation")
        Base.include(R26_G, carrier_source)
    end

    cursor = Ref(0)
    started = time_ns()
    Base.include(x -> r26_transform(x, R26_SELECTED_IDS, cursor), Main, successor_path)
    elapsed = (time_ns() - started) / 1.0e9
    cursor[] == 70 || error("runtime traversal drift: $(cursor[])")
    observed = Set(R26_RUNTIME_IDS)
    observed == R26_SELECTED_IDS || error("missing or foreign runtime targets")
    if shard_name == "contract"
        R26_V1_SOURCE_CARRIER_CALL_COUNT[] == 1 ||
            error("V1 source carrier exact-once gate missing")
        R26_V1_SOURCE_CARRIER_OBSERVATION[] === nothing &&
            error("V1 source carrier receipt missing")
    else
        R26_V1_SOURCE_CARRIER_CALL_COUNT[] == 0 ||
            error("V1 source carrier ran in the wrong shard")
    end
    multiplicity = Dict(id => count(==(id), R26_RUNTIME_IDS) for id in selected)
    all(>(0), values(multiplicity)) || error("zero-hit selected target")
    dependency_after = r26_verify_dependencies(protocol)
    dependency_before == dependency_after || error("dependency changed during shard")
    limit = Float64(shard.max_wall_seconds)
    gate_pass = elapsed <= limit
    ledger = (schema="vnext_t1_v1_shard_r26_ledger_v2", shard=shard_name,
        selected_target_ids=selected, runtime_target_ids=copy(R26_RUNTIME_IDS),
        runtime_multiplicity=multiplicity, target_ownership_exact=observed == R26_SELECTED_IDS,
        include_wall_elapsed_seconds=elapsed, include_wall_limit_seconds=limit,
        include_wall_gate_pass=gate_pass, source=String(protocol.v1.successor.path),
        source_sha256=String(protocol.v1.successor.sha256),
        protocol_sha256=r26_digest(R26_PROTOCOL_PATH).sha256,
        source_carrier_resource=R26_V1_SOURCE_CARRIER_OBSERVATION[],
        dependencies_before=dependency_before, dependencies_after=dependency_after,
        dependencies_unchanged=true, pid=getpid(), utc=string(Dates.now(Dates.UTC)),
        formal_T1=false, scientific_acceptance=false,
        actual_model_attestation="unavailable")
    open(ledger_path, "w") do io
        JSON3.write(io, ledger)
        flush(io)
    end
    println("R26_V1_SHARD_LEDGER=", JSON3.write(ledger)); flush(stdout)
    gate_pass || error("shard include wall ceiling exceeded")
end

r26_run()
