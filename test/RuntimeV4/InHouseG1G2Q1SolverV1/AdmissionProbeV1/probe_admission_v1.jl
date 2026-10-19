using SHA
using JSON3
using FusionConceptAI

const APV1_REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const APV1_Q1_DIR = joinpath(APV1_REPO_ROOT, "test", "RuntimeV4",
    "InHouseG1G2Q1SolverV1")
const APV1_FIXTURE_PATH = joinpath(APV1_Q1_DIR, "focused_fixture.jl")
const APV1_INTEGRATION_PATH = joinpath(APV1_REPO_ROOT, "src", "GenomeV5",
    "Integration", "VNextGenomeV5IntegrationV2.jl")
const APV1_PACKAGE_PATH = joinpath(APV1_REPO_ROOT, "src", "Contracts",
    "CandidateStatePackageV5NextV2.jl")

const APV1_EXPECTED_HASHES = Dict(
    "focused_fixture.jl" =>
        "C40322D190E3BB72AFC0882E755687C67D5AD0EC4EC580BC09DFF9AA8ACBDC9A",
    "VNextGenomeV5IntegrationV2.jl" =>
        "37FC25612CCCF94044F736984F7F4A730C7F6F078898C80849981ADD27F3BC86",
    "CandidateStatePackageV5NextV2.jl" =>
        "EFFAC2E603D2A1AF30605B70310A634E3659AC487634E164AB049851795C4F89",
)

function apv1_sha256(path::AbstractString)
    bytes2hex(SHA.sha256(read(path)))
end

function apv1_read_pinned(path::AbstractString, name::String)
    bytes = read(path)
    actual = uppercase(bytes2hex(SHA.sha256(bytes)))
    expected = APV1_EXPECTED_HASHES[name]
    actual == expected || error("AdmissionProbeV1 source pin mismatch: " *
        name * " expected=" * expected * " actual=" * actual)
    String(bytes)
end

module AdmissionProbeV1
using JSON3
using FusionConceptAI

struct DiagnosticOnlyStop <: Exception end

const EVENT_PATH = Ref{String}("")
const CURRENT_INPUT = Ref{Any}(nothing)
const PHASE_START_NS = Dict{Int,UInt64}()
const PHASE_LABELS = Dict{Int,String}()
const PHASE_LINES = Dict{Int,Int}()
const PHASE_LOCK = ReentrantLock()
const PHASES_STARTED = Ref(0)

function _event_base()
    input = CURRENT_INPUT[]
    input === nothing && return (
        schema="inhouse-q1-admission-probe-events-v1",
        diagnostic_only=true, acceptance_credit=false,
        compiler_or_solver_input=false)
    transport = input.transport
    recheck = input.t0_recheck
    (
        schema="inhouse-q1-admission-probe-events-v1",
        diagnostic_only=true,
        acceptance_credit=false,
        compiler_or_solver_input=false,
        candidate_id=String(input.candidate_ref.id),
        candidate_version=String(input.candidate_ref.version),
        transport_bundle_hash=string(transport.bundle_hash),
        recheck_bundle_hash=string(recheck.prior_bundle_sha256),
        recheck_wire_sha256=string(recheck.prior_bundle_bytes.sha256),
        parent_commitments=string.(collect(input.parent_commitments)),
        g3_expected_commitment=string(input.g3_expected_commitment),
    )
end

function _append_event(fields::NamedTuple)
    path = EVENT_PATH[]
    isempty(path) && error("AdmissionProbeV1 event path not configured")
    event = merge(_event_base(), fields)
    open(path, "a") do io
        JSON3.write(io, event)
        write(io, '\n')
        flush(io)
    end
    nothing
end

function configure!(path::AbstractString)
    EVENT_PATH[] = abspath(path)
    empty!(PHASE_START_NS)
    empty!(PHASE_LABELS)
    empty!(PHASE_LINES)
    PHASES_STARTED[] = 0
    isfile(EVENT_PATH[]) && error("event path must be a fresh file")
    _append_event((event="probe_started", monotonic_ns=time_ns(),
        scope="clone_only_zero_credit"))
    nothing
end

function set_input!(input)
    input isa FusionConceptAI.VNextT1AdmissionInputV2 ||
        error("diagnostic input type mismatch")
    CURRENT_INPUT[] = input
    _append_event((event="fresh_admission_input_bound",
        monotonic_ns=time_ns(), input_type=string(typeof(input))))
    nothing
end

function begin_phase!(index::Int, label::String, source_line::Int,
        final_return_expression::Bool)
    observed = time_ns()
    lock(PHASE_LOCK) do
        haskey(PHASE_START_NS, index) &&
            error("duplicate diagnostic phase index")
        PHASE_START_NS[index] = observed
        PHASE_LABELS[index] = label
        PHASE_LINES[index] = source_line
        PHASES_STARTED[] += 1
    end
    _append_event((event="phase_begin", phase_index=index,
        phase=label, source_line=source_line, monotonic_ns=observed,
        final_return_expression=final_return_expression))
    # The stored start is moved past append+flush so begin-event I/O does not
    # inflate the source-expression duration.
    body_started = time_ns()
    lock(PHASE_LOCK) do
        PHASE_START_NS[index] = body_started
    end
    body_started
end

function end_phase!(index::Int, label::String, source_line::Int)
    finished = time_ns()
    started = lock(PHASE_LOCK) do
        stored_label = get(PHASE_LABELS, index, nothing)
        stored_line = get(PHASE_LINES, index, nothing)
        stored_label == label && stored_line == source_line ||
            error("diagnostic phase identity mismatch")
        PHASE_START_NS[index]
    end
    _append_event((event="phase_end", phase_index=index,
        phase=label, source_line=source_line, monotonic_ns=finished,
        elapsed_ns=max(0, finished - started)))
    lock(PHASE_LOCK) do
        pop!(PHASE_LABELS, index)
        pop!(PHASE_LINES, index)
        pop!(PHASE_START_NS, index)
    end
    nothing
end

function diagnostic_admit_v1(input)
    set_input!(input)
    clone_started = time_ns()
    _append_event((event="clone_call_begin", monotonic_ns=clone_started))
    result = FusionConceptAI.vnext_t1_admit_v2_diagnostic_v1(input)
    _append_event((event="clone_result_discarded", monotonic_ns=time_ns(),
        clone_elapsed_ns=max(0, time_ns() - clone_started),
        status=string(result.status), resolution=string(result.resolution),
        accepted=result.accepted, claim_ceiling=string(result.claim_ceiling),
        error_codes=string.(collect(result.errors)),
        gap_codes=string.(collect(result.gaps)), result_discarded=true))
    throw(DiagnosticOnlyStop())
end

function finish!(outcome::AbstractString)
    _append_event((event="diagnostic_stop", monotonic_ns=time_ns(),
        outcome=String(outcome), clone_only=true,
        official_admission_called=false, compiler_called=false,
        solver_called=false, acceptance_credit=false))
    nothing
end

end # module AdmissionProbeV1

function apv1_parse_args(args)
    values = Dict{String,String}()
    i = 1
    while i <= length(args)
        key = args[i]
        key in ("--events-jsonl", "--summary-json") ||
            error("unknown argument: " * key)
        i < length(args) || error("missing value for " * key)
        haskey(values, key) && error("duplicate argument: " * key)
        values[key] = args[i + 1]
        i += 2
    end
    all(key -> haskey(values, key), ("--events-jsonl", "--summary-json")) ||
        error("both --events-jsonl and --summary-json are required")
    values
end

function apv1_find_function(expr, name::Symbol, found=Expr[])
    if expr isa Expr
        if expr.head === :function && !isempty(expr.args) &&
                apv1_signature_name(expr.args[1]) === name
            push!(found, expr)
        end
        for child in expr.args
            apv1_find_function(child, name, found)
        end
    end
    found
end

function apv1_signature_name(signature)
    signature isa Expr && signature.head === :call &&
        !isempty(signature.args) ? signature.args[1] : nothing
end

function apv1_contains_symbol(expr, target::Symbol)
    expr === target && return true
    expr isa Expr || return false
    any(child -> apv1_contains_symbol(child, target), expr.args)
end

function apv1_phase_label(expr, index::Int)
    apv1_contains_symbol(expr, :_vnext_ar_v2_carrier) &&
        return "wire_carrier_and_hash"
    apv1_contains_symbol(expr, :_vnext_t1_v2_recheck_envelope_error) &&
        return "recheck_envelope_and_deep_compare"
    apv1_contains_symbol(expr, :vnext_t1_parent_commitment_v2) &&
        return "parent_commitments"
    apv1_contains_symbol(expr, :_vnext_t1_v2_g3_check) &&
        return "g3_authority"
    apv1_contains_symbol(expr, :CandidateStatePackageV5NextV2) &&
        return "package_constructor"
    apv1_contains_symbol(expr, :_vnext_ar_v2_bundle_body) &&
        return "transport_bundle_hash"
    apv1_contains_symbol(expr, :copy_bytes) &&
        return "wire_bytes_validation"
    "admission_expr_" * lpad(string(index), 2, '0')
end

function apv1_end_call(index, label, source_line)
    Expr(:call, GlobalRef(AdmissionProbeV1, :end_phase!), index,
        label, source_line)
end

function apv1_instrument_body(body)
    body isa Expr && body.head === :block ||
        error("official admission body is not an expression block")
    expression_count = count(statement -> !(statement isa LineNumberNode),
        body.args)
    expression_count > 0 || error("official admission function body is empty")
    output = Any[]
    phase_index = 0
    source_line = 0
    for statement in body.args
        if statement isa LineNumberNode
            source_line = statement.line
            push!(output, statement)
            continue
        end
        phase_index += 1
        label = apv1_phase_label(statement, phase_index)
        final_return_expression = phase_index == expression_count
        # Keep the original expression literally in its original function
        # scope. Returns and throws naturally skip the end marker. The final
        # expression has a begin marker only, preserving the original return.
        push!(output, Expr(:call, GlobalRef(AdmissionProbeV1,
            :begin_phase!), phase_index, label, source_line,
            final_return_expression))
        push!(output, statement)
        final_return_expression || push!(output,
            apv1_end_call(phase_index, label, source_line))
    end
    Expr(:block, output...)
end

function apv1_marker(expr, name::Symbol)
    expr isa Expr && expr.head === :call &&
        length(expr.args) == (name === :begin_phase! ? 5 : 4) &&
        isequal(expr.args[1], GlobalRef(AdmissionProbeV1, name)) &&
        expr.args[2] isa Int && expr.args[3] isa String &&
        expr.args[4] isa Int &&
        (name !== :begin_phase! || expr.args[5] isa Bool) ?
            (index=expr.args[2], label=expr.args[3], line=expr.args[4],
                final_return=name === :begin_phase! ? expr.args[5] : false) :
            nothing
end

function apv1_strip_function_markers(expr::Expr, expected_expression_count::Int)
    expr.head === :function || error("expected function expression")
    body = expr.args[2]
    body isa Expr && body.head === :block ||
        error("instrumented function body is not a block")
    output = Any[]
    pending = nothing
    waiting_for_expression = false
    waiting_for_end = false
    original_expression_index = 0
    phase_index = 0
    source_line = 0
    for statement in body.args
        if statement isa LineNumberNode
            source_line = statement.line
            push!(output, statement)
            continue
        end
        begin_marker = apv1_marker(statement, :begin_phase!)
        end_marker = apv1_marker(statement, :end_phase!)
        if begin_marker !== nothing
            pending === nothing || error("nested/unclosed probe begin marker")
            phase_index += 1
            begin_marker.index == phase_index ||
                error("probe phase index is not the source order")
            begin_marker.line == source_line ||
                error("probe marker source line changed")
            begin_marker.final_return ==
                (phase_index == expected_expression_count) ||
                error("only the final source expression may be begin-only")
            pending = begin_marker
            waiting_for_expression = true
            waiting_for_end = false
        elseif end_marker !== nothing
            pending !== nothing && waiting_for_end ||
                error("probe end marker does not follow one source expression")
            pending.final_return &&
                error("final source expression must preserve implicit return")
            (pending.index == end_marker.index &&
                pending.label == end_marker.label &&
                pending.line == end_marker.line) ||
                error("probe marker identity mismatch")
            pending = nothing
            waiting_for_expression = false
            waiting_for_end = false
        elseif pending !== nothing && waiting_for_expression
            pending.label == apv1_phase_label(statement, pending.index) ||
                error("probe phase label does not match its source expression")
            push!(output, statement)
            original_expression_index += 1
            waiting_for_expression = false
            waiting_for_end = !pending.final_return
        else
            error("unmarked expression or duplicate source expression in probe body")
        end
    end
    if pending !== nothing
        pending.final_return && !waiting_for_expression && !waiting_for_end ||
            error("incomplete non-return probe marker pair in AST")
        pending.index == original_expression_index == phase_index ==
            expected_expression_count ||
            error("begin-only marker is not before the final expression")
    else
        error("final source expression must retain its begin-only marker")
    end
    phase_index == expected_expression_count ||
        error("not every source expression has an exact probe marker")
    original_expression_index == expected_expression_count ||
        error("not every source expression was preserved")
    stripped = deepcopy(expr)
    stripped.args[2] = Expr(:block, output...)
    stripped
end

function apv1_rename_function(expr::Expr, old_name::Symbol, new_name::Symbol)
    clone = deepcopy(expr)
    signature = clone.args[1]
    apv1_signature_name(signature) === old_name ||
        error("function signature name mismatch")
    signature.args[1] = new_name
    clone
end

function apv1_build_diagnostic_clone(integration_source::String)
    parsed = Meta.parseall(integration_source)
    matches = apv1_find_function(parsed, :vnext_t1_admit_v2)
    length(matches) == 1 || error("expected one official admission function")
    original = only(matches)
    signature = original.args[1]
    length(signature.args) == 2 || error("official admission signature changed")
    argument = signature.args[2]
    argument isa Expr && argument.head === :(::) &&
        argument.args[1] === :input &&
        argument.args[2] === :VNextT1AdmissionInputV2 ||
        error("official admission signature no longer matches run08 pin")

    clone = apv1_rename_function(original, :vnext_t1_admit_v2,
        :vnext_t1_admit_v2_diagnostic_v1)
    clone.args[2] = apv1_instrument_body(clone.args[2])
    source_expression_count = count(
        statement -> !(statement isa LineNumberNode), original.args[2].args)
    normalized_clone = apv1_rename_function(
        apv1_strip_function_markers(clone, source_expression_count),
        :vnext_t1_admit_v2_diagnostic_v1,
        :vnext_t1_admit_v2)
    isequal(normalized_clone, original) ||
        error("diagnostic clone AST differs from pinned official function")
    clone
end

function apv1_event_incomplete_phases(path::AbstractString)
    started = Dict{Int,NamedTuple}()
    ended = Set{Int}()
    clone_result_seen = false
    for line in eachline(path)
        record = JSON3.read(line, Dict{String,Any})
        event = get(record, "event", nothing)
        if event == "phase_begin"
            started[Int(record["phase_index"])] = (
                phase=String(record["phase"]),
                final_return_expression=Bool(record["final_return_expression"]))
        elseif event == "phase_end"
            push!(ended, Int(record["phase_index"]))
        elseif event == "clone_result_discarded"
            clone_result_seen = true
        end
    end
    unmatched = sort!([index for index in keys(started) if !(index in ended)])
    intentional_final = clone_result_seen ?
        only_or_nothing([index for index in unmatched
            if started[index].final_return_expression]) : nothing
    interrupted = [index for index in unmatched if index != intentional_final]
    (unmatched=unmatched, intentional_final_return=intentional_final,
        interrupted=interrupted, clone_result_seen=clone_result_seen)
end

only_or_nothing(items) = isempty(items) ? nothing :
    (length(items) == 1 ? only(items) :
        error("multiple begin-only final return phases in event stream"))

function apv1_make_diagnostic_fixture(fixture_source::String)
    needle = "admission = NG12_G.vnext_t1_admit_v2(admission_input)"
    replacement = "admission = Main.AdmissionProbeV1." *
        "diagnostic_admit_v1(admission_input)"
    occurrences = count(needle, fixture_source)
    occurrences == 1 || error("focused fixture admission call pin mismatch")
    replace(fixture_source, needle => replacement; count=1)
end

function apv1_write_summary(path::AbstractString, outcome::String;
        result=nothing, error_text="")
    event_state = apv1_event_incomplete_phases(AdmissionProbeV1.EVENT_PATH[])
    summary = (
        schema="inhouse-q1-admission-probe-summary-v1",
        diagnostic_only=true,
        acceptance_credit=false,
        official_admission_called=false,
        compiler_called=false,
        solver_called=false,
        scipy_called=false,
        clone_result_discarded=event_state.clone_result_seen,
        outcome=outcome,
        unmatched_phase_indices=event_state.unmatched,
        intentional_final_return_phase=event_state.intentional_final_return,
        interrupted_phase_indices=event_state.interrupted,
        phase_count=AdmissionProbeV1.PHASES_STARTED[],
        result_status=result === nothing ? nothing : string(result.status),
        result_resolution=result === nothing ? nothing : string(result.resolution),
        error=error_text,
    )
    open(path, "w") do io
        JSON3.write(io, summary)
        write(io, '\n')
        flush(io)
    end
    summary
end

function apv1_main(args)
    options = apv1_parse_args(args)
    event_path = abspath(options["--events-jsonl"])
    summary_path = abspath(options["--summary-json"])
    AdmissionProbeV1.configure!(event_path)

    fixture_source = apv1_read_pinned(APV1_FIXTURE_PATH,
        "focused_fixture.jl")
    integration_source = apv1_read_pinned(APV1_INTEGRATION_PATH,
        "VNextGenomeV5IntegrationV2.jl")
    package_source = apv1_read_pinned(APV1_PACKAGE_PATH,
        "CandidateStatePackageV5NextV2.jl")
    clone = apv1_build_diagnostic_clone(integration_source)
    fixture_source = apv1_make_diagnostic_fixture(fixture_source)

    # The fixture defines the original fresh producer chain. The sole source
    # routing change above makes its original call site invoke this zero-credit
    # clone; it does not pre-run the chain or create a second admission input.
    Base.include_string(Main, fixture_source, APV1_FIXTURE_PATH)
    # The source files just included by the pinned fixture must still match the
    # exact bytes parsed above; this closes the fixture-include/read window.
    uppercase(apv1_sha256(APV1_INTEGRATION_PATH)) ==
        APV1_EXPECTED_HASHES["VNextGenomeV5IntegrationV2.jl"] ||
        error("admission source changed while loading the fresh fixture")
    uppercase(apv1_sha256(APV1_PACKAGE_PATH)) ==
        APV1_EXPECTED_HASHES["CandidateStatePackageV5NextV2.jl"] ||
        error("package source changed while loading the fresh fixture")
    isempty(package_source) && error("pinned package source unexpectedly empty")
    Core.eval(Main.NG12_G, clone)

    outcome = "diagnostic_only_stop_missing"
    failure = ""
    try
        Base.invokelatest(Main.ng12_source_chain)
    catch error
        if error isa AdmissionProbeV1.DiagnosticOnlyStop
            outcome = "diagnostic_clone_stopped_before_follow_on_fixture_work"
        else
            outcome = "diagnostic_exception"
            failure = sprint(showerror, error)
            AdmissionProbeV1._append_event((event="probe_exception",
                monotonic_ns=time_ns(), exception_type=string(typeof(error)),
                exception=failure))
        end
    end
    AdmissionProbeV1.finish!(outcome)
    for (name, path) in (("focused_fixture.jl", APV1_FIXTURE_PATH),
            ("VNextGenomeV5IntegrationV2.jl", APV1_INTEGRATION_PATH),
            ("CandidateStatePackageV5NextV2.jl", APV1_PACKAGE_PATH))
        apv1_sha256(path) == lowercase(APV1_EXPECTED_HASHES[name]) ||
            error("AdmissionProbeV1 postflight source hash changed: " * name)
    end
    apv1_write_summary(summary_path, outcome; error_text=failure)
    outcome == "diagnostic_clone_stopped_before_follow_on_fixture_work" ||
        error("AdmissionProbeV1 did not stop at the intended diagnostic boundary")
    nothing
end

apv1_main(ARGS)
