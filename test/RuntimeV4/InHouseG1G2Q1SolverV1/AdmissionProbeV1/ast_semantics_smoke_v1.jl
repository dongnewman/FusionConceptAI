using SHA

const SMOKE_REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const PROBE_SOURCE_PATH = joinpath(@__DIR__, "probe_admission_v1.jl")
const INTEGRATION_SOURCE_PATH = joinpath(SMOKE_REPO_ROOT, "src", "GenomeV5",
    "Integration", "VNextGenomeV5IntegrationV2.jl")
const EXPECTED_PROBE_SHA256 =
    "8CF92684C608A095D07C7CBA499CB4947C8C3ACFD059C2173D98F746E92D5E33"
const EXPECTED_INTEGRATION_SHA256 =
    "37FC25612CCCF94044F736984F7F4A730C7F6F078898C80849981ADD27F3BC86"

smoke_sha256(bytes::Vector{UInt8}) = uppercase(bytes2hex(sha256(bytes)))

function smoke_signature_name(signature)
    signature isa Expr && signature.head === :call &&
        !isempty(signature.args) ? signature.args[1] : nothing
end

function smoke_find_helper_definitions(expr, wanted::Set{Symbol},
        found=Dict{Symbol,Vector{Expr}}())
    if expr isa Expr
        if expr.head === :function && !isempty(expr.args)
            name = smoke_signature_name(expr.args[1])
            if name in wanted
                push!(get!(found, name, Expr[]), expr)
            end
        end
        for child in expr.args
            smoke_find_helper_definitions(child, wanted, found)
        end
    end
    found
end

module AdmissionProbeV1
const EVENTS = NamedTuple[]

function begin_phase!(index::Int, label::String, source_line::Int,
        final_return_expression::Bool)
    push!(EVENTS, (kind=:begin, index=index, label=label,
        source_line=source_line, final_return=final_return_expression))
    nothing
end

function end_phase!(index::Int, label::String, source_line::Int)
    push!(EVENTS, (kind=:end, index=index, label=label,
        source_line=source_line))
    nothing
end
end

const HELPER_NAMES = (
    :apv1_find_function,
    :apv1_signature_name,
    :apv1_contains_symbol,
    :apv1_phase_label,
    :apv1_end_call,
    :apv1_instrument_body,
    :apv1_marker,
    :apv1_strip_function_markers,
    :apv1_rename_function,
    :apv1_build_diagnostic_clone,
)

function smoke_load_frozen_helpers()
    # Hash and parse these exact bytes. No source file is included or executed.
    probe_bytes = read(PROBE_SOURCE_PATH)
    smoke_sha256(probe_bytes) == EXPECTED_PROBE_SHA256 ||
        error("frozen admission probe source hash mismatch")
    probe_ast = Meta.parseall(String(copy(probe_bytes)))
    definitions = smoke_find_helper_definitions(probe_ast, Set(HELPER_NAMES))
    for name in HELPER_NAMES
        matches = get(definitions, name, Expr[])
        length(matches) == 1 ||
            error("expected exactly one frozen helper definition: " * string(name))
        # Evaluate the untouched function Expr in an isolated module that
        # contains only the two marker stubs and these pure helpers.
        Core.eval(AdmissionProbeV1, only(matches))
    end
    nothing
end

try
    smoke_load_frozen_helpers()
catch err
    println(stderr, "AST_SEMANTICS_SMOKE=FAIL stage=helper_load")
    showerror(stderr, err, catch_backtrace())
    println(stderr)
    rethrow()
end

const apv1_find_function = AdmissionProbeV1.apv1_find_function
const apv1_signature_name = AdmissionProbeV1.apv1_signature_name
const apv1_contains_symbol = AdmissionProbeV1.apv1_contains_symbol
const apv1_phase_label = AdmissionProbeV1.apv1_phase_label
const apv1_end_call = AdmissionProbeV1.apv1_end_call
const apv1_instrument_body = AdmissionProbeV1.apv1_instrument_body
const apv1_marker = AdmissionProbeV1.apv1_marker
const apv1_strip_function_markers =
    AdmissionProbeV1.apv1_strip_function_markers
const apv1_rename_function = AdmissionProbeV1.apv1_rename_function
const apv1_build_diagnostic_clone =
    AdmissionProbeV1.apv1_build_diagnostic_clone

function smoke_must_throw(f, label::AbstractString)
    threw = false
    try
        f()
    catch
        threw = true
    end
    threw || error("malformed clone was accepted: " * label)
    nothing
end

function smoke_source_expression_count(function_expr::Expr)
    count(statement -> !(statement isa LineNumberNode), function_expr.args[2].args)
end

function smoke_normalize_clone(clone::Expr, expected_count::Int,
        clone_name::Symbol, source_name::Symbol)
    apv1_rename_function(apv1_strip_function_markers(clone, expected_count),
        clone_name, source_name)
end

function smoke_test_pinned_official_ast()
    integration_bytes = read(INTEGRATION_SOURCE_PATH)
    smoke_sha256(integration_bytes) == EXPECTED_INTEGRATION_SHA256 ||
        error("frozen official integration source hash mismatch")
    integration_source = String(copy(integration_bytes))
    parsed = Meta.parseall(integration_source)
    original = only(apv1_find_function(parsed, :vnext_t1_admit_v2))
    clone = apv1_build_diagnostic_clone(integration_source)
    expected_count = smoke_source_expression_count(original)
    normalized = smoke_normalize_clone(clone, expected_count,
        :vnext_t1_admit_v2_diagnostic_v1, :vnext_t1_admit_v2)
    isequal(normalized, original) ||
        error("stripped diagnostic clone differs from pinned official AST")
    clone, expected_count
end

function smoke_call_latest(name::Symbol, args...)
    Base.invokelatest(getfield(Main, name), args...)
end

function smoke_capture_latest(name::Symbol, args...)
    try
        (:value, smoke_call_latest(name, args...))
    catch err
        (:error, typeof(err), sprint(showerror, err))
    end
end

function smoke_event_signature()
    [(event.kind, event.index) for event in AdmissionProbeV1.EVENTS]
end

function smoke_test_control_flow_semantics()
    dummy = Meta.parse("""
        function apv1_smoke_fixture(input::Int)
            input < 0 && return :and_early
            input != 0 || return :or_early
            input == 2 && throw(ArgumentError("dummy throw"))
            (:final_result, input)
        end
        """)
    Core.eval(Main, dummy)

    clone_name = :apv1_smoke_fixture_clone
    clone = apv1_rename_function(dummy, :apv1_smoke_fixture, clone_name)
    clone.args[2] = apv1_instrument_body(clone.args[2])
    expected_count = smoke_source_expression_count(dummy)
    normalized = smoke_normalize_clone(clone, expected_count, clone_name,
        :apv1_smoke_fixture)
    isequal(normalized, dummy) ||
        error("dummy instrument/strip changed the original AST")
    Core.eval(Main, clone)

    # Eval creates fresh methods while this test function is already running;
    # invokelatest avoids Julia's world-age restriction on every dummy call.
    and_original = smoke_capture_latest(:apv1_smoke_fixture, -1)
    empty!(AdmissionProbeV1.EVENTS)
    and_clone = smoke_capture_latest(:apv1_smoke_fixture_clone, -1)
    @assert and_original == and_clone && and_clone == (:value, :and_early)
    @assert smoke_event_signature() == [(:begin, 1)]
    @assert count(event -> event.kind === :end, AdmissionProbeV1.EVENTS) == 0

    or_original = smoke_capture_latest(:apv1_smoke_fixture, 0)
    empty!(AdmissionProbeV1.EVENTS)
    or_clone = smoke_capture_latest(:apv1_smoke_fixture_clone, 0)
    @assert or_original == or_clone && or_clone == (:value, :or_early)
    @assert smoke_event_signature() ==
        [(:begin, 1), (:end, 1), (:begin, 2)]
    @assert AdmissionProbeV1.EVENTS[end].kind === :begin
    @assert count(event -> event.kind === :end, AdmissionProbeV1.EVENTS) == 1

    throw_original = smoke_capture_latest(:apv1_smoke_fixture, 2)
    empty!(AdmissionProbeV1.EVENTS)
    throw_clone = smoke_capture_latest(:apv1_smoke_fixture_clone, 2)
    @assert throw_original == throw_clone
    @assert throw_clone[1:2] == (:error, ArgumentError)
    @assert smoke_event_signature() ==
        [(:begin, 1), (:end, 1), (:begin, 2), (:end, 2), (:begin, 3)]
    @assert count(event -> event.kind === :end, AdmissionProbeV1.EVENTS) == 2

    final_original = smoke_capture_latest(:apv1_smoke_fixture, 3)
    empty!(AdmissionProbeV1.EVENTS)
    final_clone = smoke_capture_latest(:apv1_smoke_fixture_clone, 3)
    @assert final_original == final_clone &&
        final_clone == (:value, (:final_result, 3))
    @assert smoke_event_signature() ==
        [(:begin, 1), (:end, 1), (:begin, 2), (:end, 2),
            (:begin, 3), (:end, 3), (:begin, 4)]
    @assert AdmissionProbeV1.EVENTS[end].final_return
    @assert count(event -> event.kind === :end, AdmissionProbeV1.EVENTS) == 3
    nothing
end

function smoke_test_malformed_markers()
    dummy = Meta.parse("""
        function apv1_marker_fixture(input::Int)
            input < 0 && return :early
            input == 2 && throw(ArgumentError("dummy"))
            (:done, input)
        end
        """)
    clone_name = :apv1_marker_fixture_clone
    clone = apv1_rename_function(dummy, :apv1_marker_fixture, clone_name)
    clone.args[2] = apv1_instrument_body(clone.args[2])
    expected_count = smoke_source_expression_count(dummy)

    missing_end = deepcopy(clone)
    index = findfirst(statement ->
        apv1_marker(statement, :end_phase!) !== nothing,
        missing_end.args[2].args)
    index === nothing && error("dummy clone has no non-final end marker")
    deleteat!(missing_end.args[2].args, index)
    smoke_must_throw(() -> apv1_strip_function_markers(missing_end,
        expected_count), "missing non-final end")

    duplicate_begin = deepcopy(clone)
    index = findfirst(statement ->
        apv1_marker(statement, :begin_phase!) !== nothing,
        duplicate_begin.args[2].args)
    index === nothing && error("dummy clone has no begin marker")
    insert!(duplicate_begin.args[2].args, index,
        deepcopy(duplicate_begin.args[2].args[index]))
    smoke_must_throw(() -> apv1_strip_function_markers(duplicate_begin,
        expected_count), "duplicate begin")

    renamed_marker = deepcopy(clone)
    index = findfirst(statement ->
        apv1_marker(statement, :begin_phase!) !== nothing,
        renamed_marker.args[2].args)
    index === nothing && error("dummy clone has no begin marker to rename")
    renamed_marker.args[2].args[index].args[1] =
        GlobalRef(AdmissionProbeV1, :renamed_begin_phase!)
    smoke_must_throw(() -> apv1_strip_function_markers(renamed_marker,
        expected_count), "renamed begin marker")

    reordered_markers = deepcopy(clone)
    begin_index = findfirst(statement ->
        apv1_marker(statement, :begin_phase!) !== nothing,
        reordered_markers.args[2].args)
    begin_index === nothing && error("dummy clone has no begin marker to reorder")
    begin_marker = apv1_marker(reordered_markers.args[2].args[begin_index],
        :begin_phase!)
    end_index = findfirst(statement -> begin
        marker = apv1_marker(statement, :end_phase!)
        begin_marker !== nothing && marker !== nothing &&
            marker.index == begin_marker.index
    end, reordered_markers.args[2].args)
    end_index === nothing && error("dummy clone has no matching end marker")
    reordered_markers.args[2].args[begin_index],
        reordered_markers.args[2].args[end_index] =
        reordered_markers.args[2].args[end_index],
        reordered_markers.args[2].args[begin_index]
    smoke_must_throw(() -> apv1_strip_function_markers(reordered_markers,
        expected_count), "reordered begin/end markers")

    final_end = deepcopy(clone)
    push!(final_end.args[2].args, apv1_end_call(expected_count,
        "admission_expr_" * lpad(string(expected_count), 2, '0'), 0))
    smoke_must_throw(() -> apv1_strip_function_markers(final_end,
        expected_count), "end marker after final expression")

    source_expressions = filter(statement -> !(statement isa LineNumberNode),
        dummy.args[2].args)
    length(source_expressions) == 3 ||
        error("dummy marker fixture source expression count changed")
    expected_branch = first(source_expressions)
    expected_branch isa Expr && expected_branch.head === :&& &&
        length(expected_branch.args) == 2 ||
        error("dummy's first source expression is not the expected && branch")
    expected_return = expected_branch.args[2]
    expected_return isa Expr && expected_return.head === :return &&
        length(expected_return.args) == 1 &&
        expected_return.args[1] isa QuoteNode &&
        expected_return.args[1].value === :early ||
        error("dummy's first branch no longer returns :early")

    changed_branch = deepcopy(clone)
    branch_indices = findall(statement -> isequal(statement, expected_branch),
        changed_branch.args[2].args)
    length(branch_indices) == 1 ||
        error("dummy early-return AST does not occur exactly once in clone")
    changed_branch.args[2].args[only(branch_indices)] =
        Expr(:call, :identity, :tampered_branch)
    changed_normalized = smoke_normalize_clone(changed_branch, expected_count,
        clone_name, :apv1_marker_fixture)
    isequal(changed_normalized, dummy) &&
        error("stripped branch mutation compared equal to the original")

    reordered = deepcopy(clone)
    expression_indices = Int[]
    for index in eachindex(reordered.args[2].args)
        statement = reordered.args[2].args[index]
        if statement isa Expr &&
                apv1_marker(statement, :begin_phase!) === nothing &&
                apv1_marker(statement, :end_phase!) === nothing
            push!(expression_indices, index)
        end
    end
    length(expression_indices) >= 2 || error("dummy expressions not found")
    first_index, second_index = expression_indices[1:2]
    reordered.args[2].args[first_index], reordered.args[2].args[second_index] =
        reordered.args[2].args[second_index], reordered.args[2].args[first_index]
    reordered_normalized = smoke_normalize_clone(reordered, expected_count,
        clone_name, :apv1_marker_fixture)
    isequal(reordered_normalized, dummy) &&
        error("reordered source expressions compared equal to the original")
    nothing
end

function smoke_run()
    official_clone, official_expression_count = smoke_test_pinned_official_ast()
    @assert official_expression_count > 0
    official_clone isa Expr || error("official diagnostic clone is not an Expr")
    smoke_test_control_flow_semantics()
    smoke_test_malformed_markers()
    smoke_sha256(read(PROBE_SOURCE_PATH)) == EXPECTED_PROBE_SHA256 ||
        error("frozen admission probe source changed during selfcheck")
    smoke_sha256(read(INTEGRATION_SOURCE_PATH)) == EXPECTED_INTEGRATION_SHA256 ||
        error("frozen official integration source changed during selfcheck")
    nothing
end

try
    smoke_run()
    println("AST_SEMANTICS_SMOKE=PASS zero_credit=true numerical_work=false")
catch err
    println(stderr, "AST_SEMANTICS_SMOKE=FAIL")
    showerror(stderr, err, catch_backtrace())
    println(stderr)
    rethrow()
end
