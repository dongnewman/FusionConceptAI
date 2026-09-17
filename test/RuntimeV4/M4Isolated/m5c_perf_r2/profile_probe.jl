"""M5-C manufactured conditional e-graph performance probe (screen_only).

This file is a test-only harness.  It deliberately includes the frozen
M5-C adapter without changing any production source and emits one compact
JSON object per budget.  Budget values are intentionally small and increase
monotonically; callers must enforce the external per-process timeout.
"""

using SHA

struct _RawJSON
    text::String
end

const PROBE_ROOT = normpath(joinpath(@__DIR__, "../../../.."))
const CEG_SOURCE = joinpath(PROBE_ROOT, "src", "RuntimeV4", "M4Isolated",
    "ManufacturedConditionalEGraphV1.jl")

function _json_quote(x)
    s = String(x)
    s = replace(s, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n",
        "\r" => "\\r", "\t" => "\\t")
    "\"" * s * "\""
end
_json_value(x::Bool) = x ? "true" : "false"
_json_value(x::Nothing) = "null"
_json_value(x::Integer) = string(x)
_json_value(x::AbstractFloat) = isfinite(x) ? string(x) : "null"
_json_value(x::Symbol) = _json_quote(String(x))
_json_value(x::AbstractString) = _json_quote(x)
_json_value(x::_RawJSON) = x.text
_json_value(x) = _json_quote(repr(x))
function _json_object(pairs::Pair...)
    "{" * join((_json_quote(k) * ":" * _json_value(v) for (k, v) in pairs), ",") * "}"
end

function _timed(f)
    GC.gc()
    t0 = time_ns()
    z = @timed f()
    elapsed = time_ns() - t0
    (value=z.value, elapsed_ns=Int(elapsed), timed_ns=Int(round(z.time * 1e9)),
        allocations=Int(z.bytes), gc_ns=Int(round(z.gctime * 1e9)))
end

function _upstream_fixture()
    a = manufactured_equation_ir_v1()
    b_result = lower_manufactured_residual(a)
    b_result.valid && b_result.declaration !== nothing || error("M5-B residual invalid")
    b = b_result.declaration::ManufacturedResidualDeclarationV1
    c_result = build_manufactured_discrete_control(b, 2, 2, 2)
    c_result.valid && c_result.control !== nothing || error("M5-B discrete invalid")
    c = c_result.control::ManufacturedDiscreteControlV1
    d_result = build_manufactured_coupled_solve_control(c, c)
    d_result.valid && d_result.control !== nothing || error("M5-B coupled invalid")
    a_result = build_manufactured_auto_composition(a, b, c, d_result.control)
    a_result.valid && a_result.composition !== nothing || error("M5-A composition invalid")
    i_result = build_inverse(d_result.control, a_result.composition)
    i_result.valid && i_result.inverse !== nothing || error("M5-B inverse invalid")
    (a=a_result.composition::ManufacturedAutoCompositionV1,
        b=i_result.inverse::ManufacturedInverseFeedbackV1)
end

function _prepare(a, b, registry)
    source = a.canonical_program
    source_hash = invoke(_ceg_program_hash, Tuple{TypedASTProgramV1}, source)
    catalog = _m5ceg_condition_catalog(a, b)
    rules = _m5ceg_rewrite_set(source, catalog; registry=registry)
    (source=source, source_hash=source_hash, catalog=catalog, rules=rules)
end

function _assemble(prep, a, b, registry, budget, profile, deriv)
    graph = deriv.artifact
    status = graph === nothing ? :terminal_deferred :
        (graph.complete ? :valid : :terminal_deferred)
    ManufacturedConditionalEGraphV1(M5CEG_SCHEMA_V1, prep.source,
        prep.source_hash, M5CEG_M5A_SOURCE_SHA256_V1,
        M5CEG_M5A_COMPOSITION_SHA256_V1, M5CEG_M5B_SOURCE_SHA256_V1,
        manufactured_inverse_feedback_hash(b), b.owner_bindings,
        b.provenance_bindings, prep.catalog, prep.rules, registry, budget,
        profile, deriv, graph, status, M5CEG_CLAIM_CEILING_V1,
        M5CEG_EVIDENCE_SCOPE_V1)
end

function _counts(graph)
    graph === nothing && return (nodes=0, edges=0, attempts=0, rounds=0,
        trace_steps=0, complete=false, stop_reason="none")
    u = graph.usage
    (nodes=u.programs, edges=u.trace_steps, attempts=u.rewrite_attempts,
        rounds=u.rounds, trace_steps=u.trace_steps, complete=graph.complete,
        stop_reason=String(graph.stop_reason))
end

function _stage_json(name, x)
    _json_object("stage"=>name, "elapsed_ns"=>x.elapsed_ns,
        "timed_ns"=>x.timed_ns, "allocations"=>x.allocations,
        "gc_ns"=>x.gc_ns)
end

_emit(s) = (println(s); flush(stdout))

_emit("M5C_PERF_PROBE_START schema=M5-C-PERFORMANCE-R2 scope=screen_only")
_emit("julia_version=" * string(VERSION) * " pid=" * string(getpid()) *
    " started_ns=" * string(time_ns()))
const FOCUS = lowercase(get(ARGS, 1, "all"))

inc = _timed(() -> include(CEG_SOURCE))
_emit("STAGE " * _stage_json("include", inc))
FOCUS == "include" && (_emit("M5C_PERF_PROBE_END status=completed"); exit(0))

first_upstream = _timed(_upstream_fixture)
up = first_upstream.value
_emit("STAGE " * _stage_json("upstream_first_compile_plus_build", first_upstream))
warm_upstream = _timed(_upstream_fixture)
_emit("STAGE " * _stage_json("upstream_warm_build", warm_upstream))
FOCUS == "upstream" && (_emit("M5C_PERF_PROBE_END status=completed"); exit(0))

registry = default_operator_registry()
profile = default_canonicalization_profile()
if FOCUS == "prepare_catalog"
    x = _timed(() -> _m5ceg_condition_catalog(up.a, up.b))
    _emit("STAGE " * _stage_json("prepare_condition_catalog", x))
    _emit("M5C_PERF_PROBE_END status=completed")
    exit(0)
elseif FOCUS == "prepare_rhs"
    x = _timed(() -> _m5ceg_rhs(up.a.canonical_program; registry=registry))
    _emit("STAGE " * _stage_json("prepare_rhs", x))
    _emit("M5C_PERF_PROBE_END status=completed")
    exit(0)
elseif FOCUS == "rules_parts"
    src_program = up.a.canonical_program
    catalog_timed = _timed(() -> _m5ceg_condition_catalog(up.a, up.b))
    catalog = catalog_timed.value
    _emit("STAGE " * _stage_json("prepare_condition_catalog", catalog_timed))
    rhs_timed = _timed(() -> _m5ceg_rhs(src_program; registry=registry))
    rhs = rhs_timed.value
    _emit("STAGE " * _stage_json("prepare_rhs", rhs_timed))
    req_timed = _timed(() -> _m5ceg_requirements(catalog))
    req = req_timed.value
    _emit("STAGE " * _stage_json("prepare_requirements", req_timed))
    checker = QualifiedRefV1("M5CEG.synthetic.condition.checker", "v1")
    checker_hash = digest256_text("M5CEG|typed-condition-checker|v1")
    rule1_timed = _timed(() -> WholeProgramConditionalRewriteV1(
        QualifiedRefV1("M5CEG.reassociate_add", "v1"), src_program, rhs, req,
        checker, checker_hash; registry=registry))
    rule1 = rule1_timed.value
    _emit("STAGE " * _stage_json("prepare_rule_reassociate", rule1_timed))
    reordered = TypedASTProgramV1(getfield(src_program, :nodes),
        reverse(getfield(src_program, :roots)), getfield(src_program, :input_ports), registry)
    rule2_timed = _timed(() -> WholeProgramConditionalRewriteV1(
        QualifiedRefV1("M5CEG.root_order", "v1"), src_program, reordered, req,
        checker, checker_hash; registry=registry))
    rule2 = rule2_timed.value
    _emit("STAGE " * _stage_json("prepare_rule_root_order", rule2_timed))
    set_timed = _timed(() -> ConditionalRewriteSetV1((rule1, rule2)))
    _emit("STAGE " * _stage_json("prepare_rewrite_set_constructor", set_timed))
    _emit("M5C_PERF_PROBE_END status=completed")
    exit(0)
end
prep_source_timed = _timed(() -> (source=up.a.canonical_program,
    # The fast saturation lane intentionally obtains this identity from the
    # derivation artifact, avoiding the very expensive cold canonical hash.
    source_hash=FOCUS in ("saturate_fast", "prepare_rules_fast") ? nothing :
        invoke(_ceg_program_hash, Tuple{TypedASTProgramV1},
            up.a.canonical_program)))
_emit("STAGE " * _stage_json("prepare_source", prep_source_timed))
prep_source = prep_source_timed.value
FOCUS == "prepare_source" && (_emit("M5C_PERF_PROBE_END status=completed"); exit(0))
prep_catalog_timed = _timed(() -> _m5ceg_condition_catalog(up.a, up.b))
_emit("STAGE " * _stage_json("prepare_condition_catalog", prep_catalog_timed))
prep_catalog = prep_catalog_timed.value
prep_rhs_timed = _timed(() -> _m5ceg_rhs(prep_source.source; registry=registry))
_emit("STAGE " * _stage_json("prepare_rhs", prep_rhs_timed))
prep_rhs = prep_rhs_timed.value
FOCUS == "prepare_rhs_after_catalog" && (_emit("M5C_PERF_PROBE_END status=completed"); exit(0))
prep_rules_timed = _timed(() -> _m5ceg_rewrite_set(prep_source.source,
    prep_catalog; registry=registry))
_emit("STAGE " * _stage_json("prepare_rewrite_set", prep_rules_timed))
prep_rules = prep_rules_timed.value
FOCUS in ("prepare_rules", "prepare_rules_fast") &&
    (_emit("M5C_PERF_PROBE_END status=completed"); exit(0))
prep = (source=prep_source.source, source_hash=prep_source.source_hash,
    catalog=prep_catalog, rules=prep_rules)

# Increasing budgets are deliberately conservative.  The outer runner must
# terminate this process at 60 seconds and preserve the partial raw output.
budgets = FOCUS in ("saturate", "saturate_fast", "build", "query", "replay", "validate") ?
    (ConditionalEGraphBudgetV1(max_programs=2, max_rewrite_attempts=4,
        max_rounds=1, max_trace_steps=2),) : (
    ConditionalEGraphBudgetV1(max_programs=2, max_rewrite_attempts=4,
        max_rounds=1, max_trace_steps=2),
    ConditionalEGraphBudgetV1(max_programs=3, max_rewrite_attempts=8,
        max_rounds=2, max_trace_steps=3),
    ConditionalEGraphBudgetV1(max_programs=4, max_rewrite_attempts=16,
        max_rounds=3, max_trace_steps=4),
    ConditionalEGraphBudgetV1(max_programs=8, max_rewrite_attempts=32,
        max_rounds=4, max_trace_steps=8),
)

for (bi, budget) in enumerate(budgets)
    _emit("BUDGET_BEGIN index=$(bi) programs=$(budget.max_programs) attempts=$(budget.max_rewrite_attempts) rounds=$(budget.max_rounds) traces=$(budget.max_trace_steps)")
    sat_timed = _timed(() -> ConditionalEGraphDerivationResultV1(
        prep.source, prep.rules, registry, budget, profile))
    deriv = sat_timed.value
    graph = deriv.artifact
    counts = _counts(graph)
    _emit("STAGE " * _stage_json("saturate", sat_timed))

    if prep.source_hash === nothing && graph !== nothing
        prep = (source=prep.source, source_hash=graph.source_hash,
            catalog=prep.catalog, rules=prep.rules)
    end

    assemble_timed = _timed(() -> _assemble(prep, up.a, up.b, registry,
        budget, profile, deriv))
    product = assemble_timed.value
    _emit("STAGE " * _stage_json("build_assembly", assemble_timed))

    public_timed = _timed(() -> build_manufactured_conditional_egraph(
        up.a, up.b; budget=budget, profile=profile, registry=registry))
    _emit("STAGE " * _stage_json("public_build", public_timed))

    query_timed = nothing
    replay_timed = nothing
    target_kind = "none"
    if graph !== nothing
        members = graph.eclass.members
        target_member = findfirst(m -> m.provenance !== nothing, members)
        if target_member !== nothing
            target = members[target_member].program
            target_kind = "provenance_member"
            query_timed = _timed(() -> query_manufactured_conditional_equality(product, target))
            q = query_timed.value
            if q.provenance !== nothing
                replay_timed = _timed(() -> replay_manufactured_conditional_egraph(
                    product, target, q.provenance))
            end
        else
            target = product.source_program
            target_kind = "source_reflexive"
            query_timed = _timed(() -> query_manufactured_conditional_equality(product, target))
        end
    end
    query_json = query_timed === nothing ? "null" : _stage_json("query", query_timed)
    replay_json = replay_timed === nothing ? "null" : _stage_json("replay", replay_timed)
    _emit("STAGE " * query_json)
    _emit("STAGE " * replay_json)

    validate_timed = _timed(() -> validate_manufactured_conditional_egraph(product))
    _emit("STAGE " * _stage_json("validate", validate_timed))

    _emit("BUDGET_RESULT " * _json_object(
        "index"=>bi, "max_programs"=>budget.max_programs,
        "max_rewrite_attempts"=>budget.max_rewrite_attempts,
        "max_rounds"=>budget.max_rounds, "max_trace_steps"=>budget.max_trace_steps,
        "derivation_status"=>String(deriv.status),
        "derivation_reason"=>String(deriv.reason),
        "target_kind"=>target_kind, "nodes"=>counts.nodes, "edges"=>counts.edges,
        "attempts"=>counts.attempts, "rounds"=>counts.rounds,
        "trace_steps"=>counts.trace_steps, "complete"=>counts.complete,
        "stop_reason"=>counts.stop_reason,
        "query_stage"=>(query_timed === nothing ? nothing : _RawJSON(
            _json_object("elapsed_ns"=>query_timed.elapsed_ns,
                "allocations"=>query_timed.allocations))),
        "replay_stage"=>(replay_timed === nothing ? nothing : _RawJSON(
            _json_object("elapsed_ns"=>replay_timed.elapsed_ns,
                "allocations"=>replay_timed.allocations))))
    _emit("BUDGET_END index=$(bi)")
end

_emit("M5C_PERF_PROBE_END status=completed")
