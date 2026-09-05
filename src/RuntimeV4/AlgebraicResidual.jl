"""Bounded zero-dimensional algebraic residual screening.

This file is deliberately standalone.  It consumes the frozen typed Genome
objects and RuntimeV4 contracts, and it only evaluates an explicitly closed
constraint subgraph.  Its result and evidence ceiling are always screen_only.
"""

using LinearAlgebra
using SHA
import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI

const _ALG_SCHEMA = "fusionconceptai:runtime-v4-algebraic-residual"
const _ALG_REVISION = "v1"
const _ALG_OPERATOR = "typed_ast_zero_dim_algebraic_constraint_newton"
const _ALG_SOURCE_HASH = Digest256(bytes2hex(SHA.sha256(read(joinpath(@__DIR__, "AlgebraicResidual.jl")))))
const _ALG_ALLOWED_OPERATORS = (("IDENTITY", "v1"), ("ADD", "v1"), ("SUB", "v1"),
    ("NEG", "v1"), ("SCALAR_MUL", "v1"), ("SCALAR_DIV", "v1"))

struct _AlgebraicPlanToken end
struct _AlgebraicResultToken end
const _ALG_PLAN_TOKEN = _AlgebraicPlanToken()
const _ALG_RESULT_TOKEN = _AlgebraicResultToken()

function _alg_text(x, field)
    x isa AbstractString || throw(ArgumentError("$field must be text"))
    s = strip(String(x)); !isempty(s) && isvalid(s) || throw(ArgumentError("$field cannot be empty")); s
end

function _alg_nonwild_text(x, field)
    s = _alg_text(x, field)
    lowercase(s) ∉ ("*", "any", "wildcard", "all") || throw(ArgumentError("$field cannot be wildcard"))
    s
end

function _alg_finite(x, field)
    y = try Float64(x) catch; throw(ArgumentError("$field must be numeric")) end
    isfinite(y) || throw(ArgumentError("$field must be finite")); y
end

function _alg_protocol(protocol)
    required = (:abs_tol, :rel_tol, :max_iterations, :fd_step, :min_line_search)
    all(k -> k in keys(protocol), required) || throw(ArgumentError("numerical protocol is incomplete"))
    a = _alg_finite(getfield(protocol, :abs_tol), "abs_tol")
    r = _alg_finite(getfield(protocol, :rel_tol), "rel_tol")
    d = _alg_finite(getfield(protocol, :fd_step), "fd_step")
    m = _alg_finite(getfield(protocol, :min_line_search), "min_line_search")
    n = Int(getfield(protocol, :max_iterations))
    a > 0 && r >= 0 && d > 0 && 0 < m < 1 && n > 0 ||
        throw(ArgumentError("invalid numerical protocol"))
    (abs_tol=a, rel_tol=r, max_iterations=n, fd_step=d, min_line_search=m)
end

const _ALG_DEFAULT_PROTOCOL = (abs_tol=1.0e-10, rel_tol=1.0e-10,
    max_iterations=64, fd_step=1.0e-7, min_line_search=1.0 / 1024.0)

struct StateValueV4
    state_ref::StateGeneRefV1
    value::Float64
    unit::UnitSignature
    function StateValueV4(state_ref::StateGeneRefV1, value, unit::UnitSignature)
        y = _alg_finite(value, "state value")
        new(state_ref, y, unit)
    end
end
semantic_view(x::StateValueV4) = (state_ref=x.state_ref, value=x.value, unit=x.unit)

struct AlgebraicScenarioV4
    name::String
    state_values::Tuple{Vararg{StateValueV4}}
    abs_tol::Float64
    rel_tol::Float64
    max_iterations::Int
    fd_step::Float64
    min_line_search::Float64
    scenario_hash::Digest256
    function AlgebraicScenarioV4(name::AbstractString, values;
                                 abs_tol=1.0e-10, rel_tol=1.0e-10,
                                 max_iterations=64, fd_step=1.0e-7,
                                 min_line_search=1.0 / 1024.0)
        vals = Tuple(values)
        all(v -> v isa StateValueV4, vals) || throw(ArgumentError("scenario values must be typed"))
        length(unique(v.state_ref.value for v in vals)) == length(vals) ||
            throw(ArgumentError("scenario state refs must be unique"))
        ordered = Tuple(sort(collect(vals), by=v -> v.state_ref.value))
        p = _alg_protocol((abs_tol=abs_tol, rel_tol=rel_tol, max_iterations=max_iterations,
            fd_step=fd_step, min_line_search=min_line_search))
        nm = _alg_nonwild_text(name, "scenario name")
        body = (name=nm, state_values=ordered, protocol=p)
        new(nm, ordered, p.abs_tol, p.rel_tol, p.max_iterations, p.fd_step,
            p.min_line_search, canonical_hash(body))
    end
end
semantic_view(x::AlgebraicScenarioV4) = (name=x.name, state_values=x.state_values,
    abs_tol=x.abs_tol, rel_tol=x.rel_tol, max_iterations=x.max_iterations,
    fd_step=x.fd_step, min_line_search=x.min_line_search)

struct AlgebraicResidualRowV4
    state_ref::StateGeneRefV1
    edge_id::String
    program_hash::Digest256
    root_position::Int
    output_node_index::Int
    program::TypedASTProgramV1
    input_state_refs::Tuple
    function AlgebraicResidualRowV4(state_ref::StateGeneRefV1, edge_id::AbstractString,
                                   root_position::Integer, output_node_index::Integer,
                                   program::TypedASTProgramV1, input_state_refs)
        rp = Int(root_position); oi = Int(output_node_index)
        rp >= 1 && oi >= 1 || throw(ArgumentError("residual row positions must be positive"))
        refs = Tuple((Int(x[1]), x[2]) for x in input_state_refs)
        all(x -> length(x) == 2 && x[1] > 0 && x[2] isa StateGeneRefV1, refs) ||
            throw(ArgumentError("row input bindings must be positive port/ref pairs"))
        length(unique(x[1] for x in refs)) == length(refs) || throw(ArgumentError("row input ports must be unique"))
        eid = _alg_text(edge_id, "constraint edge id")
        new(state_ref, eid, canonical_hash(program), rp, oi, program, refs)
    end
end
semantic_view(x::AlgebraicResidualRowV4) = (state_ref=x.state_ref, edge_id=x.edge_id,
    program_hash=x.program_hash, root_position=x.root_position, output_node_index=x.output_node_index,
    program=x.program, input_state_refs=x.input_state_refs)

struct AlgebraicResidualPlanV4
    compiled_prefix_hash::Digest256
    mechanism_hash::Digest256
    state_refs::Tuple{Vararg{StateGeneRefV1}}
    state_types::Tuple{Vararg{PhysicalType}}
    lower_bounds::Tuple{Vararg{Float64}}
    upper_bounds::Tuple{Vararg{Float64}}
    scales::Tuple{Vararg{Float64}}
    rows::Tuple{Vararg{AlgebraicResidualRowV4}}
    allowed_operator_bindings::Tuple
    selected_constraint_hashes::Tuple{Vararg{Digest256}}
    ignored_edge_hashes::Tuple{Vararg{Digest256}}
    numerical_protocol::NamedTuple
    minimality_scope::MinimalityScopeV4
    capability::CapabilitySignatureV4
    plan_hash::Digest256
    function AlgebraicResidualPlanV4(::_AlgebraicPlanToken, compiled::CompiledCandidatePrefixV4,
            refs, types, lower, upper, scales, rows, allowed, selected, ignored,
            protocol, scope::MinimalityScopeV4, capability::CapabilitySignatureV4)
        rs = Tuple(refs); ts = Tuple(types); lo = Tuple(Float64.(lower)); hi = Tuple(Float64.(upper)); sc = Tuple(Float64.(scales))
        rr = Tuple(rows); aa = Tuple(allowed); ss = Tuple(selected); ii = Tuple(ignored); pp = _alg_protocol(protocol)
        length(rs) == length(ts) == length(lo) == length(hi) == length(sc) == length(rr) ||
            throw(ArgumentError("algebraic plan dimensions do not agree"))
        isempty(rs) && throw(ArgumentError("algebraic plan needs at least one state"))
        issorted(String[r.value for r in rs]) || throw(ArgumentError("state refs must be canonical order"))
        all(i -> isfinite(lo[i]) && isfinite(hi[i]) && lo[i] <= hi[i] && sc[i] > 0, eachindex(lo)) ||
            throw(ArgumentError("algebraic bounds/scales are invalid"))
        all(r -> r isa AlgebraicResidualRowV4, rr) || throw(ArgumentError("algebraic rows must be typed"))
        all(x -> x isa Digest256, ss) && all(x -> x isa Digest256, ii) || throw(ArgumentError("edge hashes must be digests"))
        body = (compiled_prefix_hash=compiled.prefix_hash,
            mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref), state_refs=rs,
            state_types=ts, lower_bounds=lo, upper_bounds=hi, scales=sc, rows=rr,
            allowed_operator_bindings=aa, selected_constraint_hashes=ss, ignored_edge_hashes=ii,
            numerical_protocol=pp, minimality_scope=scope, capability=capability)
        is_canonical_value(body) || throw(ArgumentError("algebraic plan is not canonicalizable"))
        new(compiled.prefix_hash, body.mechanism_hash, rs, ts, lo, hi, sc, rr, aa, ss, ii,
            pp, scope, capability, canonical_hash(body))
    end
end
semantic_view(x::AlgebraicResidualPlanV4) = (compiled_prefix_hash=x.compiled_prefix_hash,
    mechanism_hash=x.mechanism_hash, state_refs=x.state_refs, state_types=x.state_types,
    lower_bounds=x.lower_bounds, upper_bounds=x.upper_bounds, scales=x.scales, rows=x.rows,
    allowed_operator_bindings=x.allowed_operator_bindings, selected_constraint_hashes=x.selected_constraint_hashes,
    ignored_edge_hashes=x.ignored_edge_hashes, numerical_protocol=x.numerical_protocol,
    minimality_scope=x.minimality_scope, capability=x.capability)

struct AlgebraicResidualCompilationV4
    status::Symbol
    plan::Union{Nothing,AlgebraicResidualPlanV4}
    unresolved_gaps::Tuple{Vararg{String}}
    function AlgebraicResidualCompilationV4(status::Symbol, plan, gaps)
        status in (:ready, :deferred) || throw(ArgumentError("invalid algebraic compilation status"))
        (status == :ready) == (plan !== nothing) || throw(ArgumentError("algebraic plan/status mismatch"))
        gs = Tuple(sort(unique(_alg_text(g, "unresolved gap") for g in gaps)))
        status == :ready && !isempty(gs) && throw(ArgumentError("ready algebraic plan cannot have gaps"))
        new(status, plan, gs)
    end
end
semantic_view(x::AlgebraicResidualCompilationV4) = (status=x.status, plan=x.plan, unresolved_gaps=x.unresolved_gaps)

struct ExecutableAlgebraicSubjectV4
    plan_hash::Digest256
    scenario_hash::Digest256
    state_values::Tuple{Vararg{StateValueV4}}
    subject_hash::Digest256
    function ExecutableAlgebraicSubjectV4(plan::AlgebraicResidualPlanV4, scenario::AlgebraicScenarioV4)
        body = (plan_hash=plan.plan_hash, scenario_hash=scenario.scenario_hash, state_values=scenario.state_values,
            scope="constraint-subgraph-only")
        new(plan.plan_hash, scenario.scenario_hash, scenario.state_values, canonical_hash(body))
    end
end
semantic_view(x::ExecutableAlgebraicSubjectV4) = (plan_hash=x.plan_hash,
    scenario_hash=x.scenario_hash, state_values=x.state_values, subject_hash=x.subject_hash,
    scope="constraint-subgraph-only")

struct AlgebraicResidualResultV4
    plan_hash::Digest256
    scenario_hash::Digest256
    status::Symbol
    state_values::Tuple{Vararg{Float64}}
    residuals::Union{Nothing,Tuple{Vararg{Float64}}}
    residual_norm::Union{Nothing,Float64}
    iteration_history::Tuple
    bounds_audit::Tuple
    reference_norm::Float64
    protocol_hash::Digest256
    failure_reason::Union{Nothing,String}
    result_hash::Digest256
    function AlgebraicResidualResultV4(::_AlgebraicResultToken, plan::AlgebraicResidualPlanV4, scenario::AlgebraicScenarioV4,
            status::Symbol, values, residuals, residual_norm, history, audit, reference_norm, reason)
        status in (:converged, :numerical_fail) || throw(ArgumentError("invalid algebraic result status"))
        xs = Tuple(_alg_finite(v, "result state value") for v in values)
        rs = residuals === nothing ? nothing : Tuple(_alg_finite(v, "residual") for v in residuals)
        rn = residual_norm === nothing ? nothing : _alg_finite(residual_norm, "residual norm")
        refnorm = _alg_finite(reference_norm, "reference norm")
        refnorm >= 1.0 || throw(ArgumentError("reference norm must be at least one"))
        if status == :converged
            rs === nothing && throw(ArgumentError("converged result must contain residuals"))
            length(xs) == length(plan.state_refs) == length(rs) || throw(ArgumentError("converged result dimensions do not agree"))
            all(plan.lower_bounds[i] <= xs[i] <= plan.upper_bounds[i] for i in eachindex(xs)) ||
                throw(ArgumentError("converged result is outside bounds"))
            rn === nothing && throw(ArgumentError("converged result must contain residual norm"))
            expected_norm = _alg_norm(plan, rs)
            rn == expected_norm || throw(ArgumentError("result norm is not derived from residuals"))
            rn <= plan.numerical_protocol.abs_tol + plan.numerical_protocol.rel_tol * refnorm ||
                throw(ArgumentError("converged result does not meet frozen tolerance"))
            reason === nothing || throw(ArgumentError("converged result cannot have a failure reason"))
        end
        rr = reason === nothing ? nothing : _alg_text(reason, "failure reason")
        body = (plan_hash=plan.plan_hash, scenario_hash=scenario.scenario_hash, status=status,
            state_values=xs, residuals=rs, residual_norm=rn, iteration_history=Tuple(history),
            reference_norm=refnorm,
            bounds_audit=Tuple(audit), protocol_hash=canonical_hash(plan.numerical_protocol), failure_reason=rr)
        result_hash = try canonical_hash(body) catch e
            throw(ArgumentError("algebraic result is not canonicalizable: $(sprint(showerror, e))"))
        end
        new(plan.plan_hash, scenario.scenario_hash, status, xs, rs, rn, Tuple(history), Tuple(audit),
            refnorm, body.protocol_hash, rr, result_hash)
    end
end
semantic_view(x::AlgebraicResidualResultV4) = (plan_hash=x.plan_hash, scenario_hash=x.scenario_hash,
    status=x.status, state_values=x.state_values, residuals=x.residuals, residual_norm=x.residual_norm,
    iteration_history=x.iteration_history, bounds_audit=x.bounds_audit, reference_norm=x.reference_norm,
    protocol_hash=x.protocol_hash,
    failure_reason=x.failure_reason, result_hash=x.result_hash)

struct AlgebraicSliceReportV4
    subject::ExecutableAlgebraicSubjectV4
    input::Union{Nothing,SolverInputV4}
    result::Union{Nothing,AlgebraicResidualResultV4}
    evidence::RuntimeEvidenceV4
end

function _alg_type_token(t::PhysicalType)
    string(String(t.value_kind), ":rank=", t.tensor_rank, ":dim=", t.spatial_dimension,
        ":time=", String(Symbol(t.temporal_type.kind)), ":units=", join(string.(t.units.exponents), ";"))
end

function _alg_node_state(graph, node_index)
    1 <= node_index <= length(graph.nodes) || return nothing
    n = graph.nodes[node_index]
    n.node_kind === :state || return nothing
    StateGeneRefV1(n.node_id)
end

function _alg_input_refs(edge, graph)
    refs = Dict{Int,StateGeneRefV1}()
    for b in edge.input_bindings
        ref = _alg_node_state(graph, b.graph_node_index)
        ref === nothing && throw(ArgumentError("constraint input is not a state node"))
        1 <= b.program_position <= length(edge.program.input_ports) ||
            throw(ArgumentError("constraint input program position is out of range"))
        input_node_index = edge.program.input_ports[b.program_position]
        input_node = edge.program.nodes[input_node_index]
        input_node isa ASTInputV1 || throw(ArgumentError("constraint input port is not ASTInput"))
        haskey(refs, input_node.port) && throw(ArgumentError("constraint input port is duplicated"))
        refs[input_node.port] = ref
    end
    Tuple((port, refs[port]) for port in sort(collect(keys(refs))))
end

function _alg_check_program(program, allowed)
    gaps = String[]
    for n in program.nodes
        if n isa ASTInputV1
            n.output_type.value_kind === :scalar_field && n.output_type.tensor_rank == 0 &&
                n.output_type.spatial_dimension == 0 && n.output_type.temporal_type.kind == algebraic_time ||
                push!(gaps, "constraint_input_type")
        elseif n isa ASTConstantV1
            try _alg_finite(n.value, "AST constant") catch; push!(gaps, "nonfinite_or_non_numeric_constant") end
        elseif n isa ASTApplyV1
            key = (String(n.operator_ref.qualified.id), String(n.operator_ref.qualified.version))
            key in _ALG_ALLOWED_OPERATORS || push!(gaps, "unsupported_operator:" * key[1] * "@" * key[2])
            push!(allowed, key)
            n.output_type.value_kind === :scalar_field && n.output_type.tensor_rank == 0 &&
                n.output_type.spatial_dimension == 0 && n.output_type.temporal_type.kind == algebraic_time ||
                push!(gaps, "constraint_output_type")
        else
            push!(gaps, "unsupported_ast_node")
        end
    end
    isempty(gaps) ? nothing : gaps
end

function _alg_capability(compiled, refs, types, lower, upper, rows, protocol)
    bounds = compiled.minimality_scope.bounds_hash
    tokens = Tuple(_alg_type_token(t) for t in types)
    ish = canonical_hash((schema=_ALG_SCHEMA, revision=_ALG_REVISION,
        compiled_prefix_hash=compiled.prefix_hash,
        mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        state_refs=Tuple(r.value for r in refs), state_types=tokens,
        lower_bounds=Tuple(lower), upper_bounds=Tuple(upper),
        selected_program_hashes=Tuple(r.program_hash for r in rows), protocol=protocol,
        scope=compiled.minimality_scope))
    CapabilitySignatureV4(_ALG_SCHEMA, _ALG_REVISION, :algebraic_constraint_screen, _ALG_OPERATOR,
        Tuple(r.value for r in refs), "state_vector_0d", "scalar_residual_vector_0d", 0, (),
        "outside_reduced_constraint_scope", "outside_reduced_constraint_scope", "algebraic_time",
        ("solution", "residual_norm", "iteration_history", "bounds_audit"), screen_only, bounds;
        input_schema_hash=ish, coordinate_system="lumped_0d")
end

function compile_algebraic_residual_plan(compiled::CompiledCandidatePrefixV4, registry::GenomeContractRegistryV4;
                                         protocol=_ALG_DEFAULT_PROTOCOL)
    p = _alg_protocol(protocol); gaps = String[]; allowed = Set{Tuple{String,String}}()
    try
        _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
            compiled.mission_payload, compiled.bounds_payload,
            compiled.minimality_scope.comparison_scope, compiled.minimality_scope.scenario_scope)
    catch e
        push!(gaps, "compiled_prefix_validation:" * sprint(showerror, e))
    end
    compiled.minimality_scope.evidence_level == screen_only || push!(gaps, "scope_evidence_must_be_screen_only")
    payload = compiled.candidate.mechanism_genome_ref.payload
    canonical_hash(compiled.mechanism_graph) == canonical_hash(payload.operator_graph) ||
        push!(gaps, "compiled_mechanism_graph_mismatch")
    isempty(payload.operator_holes) || push!(gaps, "operator_holes_not_supported")
    isempty(payload.parameters) || push!(gaps, "parameters_not_supported")
    states = Tuple(sort(collect(payload.states), by=s -> s.state_ref.value))
    isempty(states) && push!(gaps, "no_mechanism_states")
    refs = Tuple(s.state_ref for s in states); types = Tuple(s.physical_type for s in states)
    lower = Float64[]; upper = Float64[]; scales = Float64[]
    for s in states
        t = s.physical_type
        t.value_kind === :scalar_field && t.tensor_rank == 0 && t.spatial_dimension == 0 &&
            t.temporal_type.kind === algebraic_time || push!(gaps, "state_not_zero_dimensional_algebraic:" * s.state_ref.value)
        lo = try _alg_finite(s.physical_bounds.interval.lower, "lower bound") catch
            push!(gaps, "invalid_state_bounds:" * s.state_ref.value); 0.0
        end
        hi = try _alg_finite(s.physical_bounds.interval.upper, "upper bound") catch
            push!(gaps, "invalid_state_bounds:" * s.state_ref.value); 0.0
        end
        lo <= hi || push!(gaps, "invalid_state_bounds:" * s.state_ref.value)
        s.physical_bounds.unit == t.units || push!(gaps, "state_bound_unit_mismatch:" * s.state_ref.value)
        push!(lower, lo); push!(upper, hi); push!(scales, max(1.0, abs(lo), abs(hi)))
    end
    graph = payload.operator_graph
    state_index = Dict(n.node_id => i for (i, n) in enumerate(graph.nodes) if n.node_kind === :state)
    for r in refs
        haskey(state_index, r.value) || push!(gaps, "state_not_bound_to_graph:" * r.value)
    end
    rows = AlgebraicResidualRowV4[]; selected = Digest256[]; ignored = Digest256[]
    constraints = [e for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1 && e.role === constraint]
    for s in states
        idx = get(state_index, s.state_ref.value, 0)
        matches = [e for e in constraints if any(b.graph_node_index == idx for b in e.output_bindings)]
        length(matches) == 1 || (push!(gaps, "constraint_row_count:" * s.state_ref.value); continue)
        edge = only(matches)
        length(edge.output_bindings) == 1 || (push!(gaps, "constraint_edge_must_have_one_output:" * edge.edge_id); continue)
        ob = only(edge.output_bindings)
        ob.graph_node_index == idx || (push!(gaps, "constraint_output_binding_mismatch:" * edge.edge_id); continue)
        local row_gaps = _alg_check_program(edge.program, allowed)
        row_gaps === nothing || append!(gaps, row_gaps)
        input_refs = try _alg_input_refs(edge, graph) catch; push!(gaps, "constraint_input_binding"); StateGeneRefV1[] end
        push!(rows, AlgebraicResidualRowV4(s.state_ref, edge.edge_id, ob.program_position,
            ob.graph_node_index, edge.program, input_refs))
        push!(selected, canonical_hash(edge))
    end
    selected_ids = Set(e.edge_id for e in [r for r in rows])
    for e in graph.hyperedges
        e isa AtomicMIMOHyperedgeV1 || (push!(gaps, "untyped_mechanism_edge"); continue)
        e.role === constraint && e.edge_id in selected_ids || push!(ignored, canonical_hash(e))
    end
    length(rows) == length(states) || push!(gaps, "equation_count_mismatch")
    isempty(gaps) || return AlgebraicResidualCompilationV4(:deferred, nothing, gaps)
    rows = sort!(rows, by=r -> r.state_ref.value)
    cap = _alg_capability(compiled, refs, types, lower, upper, rows, p)
    plan = AlgebraicResidualPlanV4(_ALG_PLAN_TOKEN, compiled, refs, types, lower, upper, scales, rows,
        Tuple(sort(collect(allowed))), Tuple(sort(unique(selected), by=string)),
        Tuple(sort(unique(ignored), by=string)), p, compiled.minimality_scope, cap)
    AlgebraicResidualCompilationV4(:ready, plan, ())
end

function _alg_value_index(plan, scenario)
    refs = Tuple(v.state_ref.value for v in scenario.state_values)
    expected = Tuple(r.value for r in plan.state_refs)
    refs == expected || throw(ArgumentError("scenario state refs must exactly match algebraic plan"))
    xs = Float64[]
    for (i, value) in enumerate(scenario.state_values)
        value.unit == plan.state_types[i].units || throw(ArgumentError("scenario state unit mismatch"))
        push!(xs, value.value)
    end
    xs
end

function _alg_eval_row(plan, row, u)
    index = Dict(r.value => i for (i, r) in enumerate(plan.state_refs))
    env = Dict{Int,Float64}()
    for (port, ref) in row.input_state_refs
        haskey(index, ref.value) || throw(ArgumentError("constraint input state is not in plan"))
        env[port] = u[index[ref.value]]
    end
    values = Vector{Union{Nothing,Float64}}(undef, length(row.program.nodes)); fill!(values, nothing)
    for i in eachindex(row.program.nodes)
        n = row.program.nodes[i]
        if n isa ASTInputV1
            haskey(env, n.port) || throw(ArgumentError("unbound algebraic AST input"))
            values[i] = env[n.port]
        elseif n isa ASTConstantV1
            values[i] = _alg_finite(n.value, "AST constant")
        elseif n isa ASTApplyV1
            args = Float64[]
            for j in n.inputs
                values[j] === nothing && throw(ArgumentError("AST dependency is not evaluated"))
                push!(args, values[j]::Float64)
            end
            key = (String(n.operator_ref.qualified.id), String(n.operator_ref.qualified.version))
            key == ("IDENTITY", "v1") && length(args) == 1 ||
                key == ("ADD", "v1") && length(args) >= 2 ||
                key == ("SUB", "v1") && length(args) == 2 ||
                key == ("NEG", "v1") && length(args) == 1 ||
                key == ("SCALAR_MUL", "v1") && length(args) == 2 ||
                key == ("SCALAR_DIV", "v1") && length(args) == 2 || throw(ArgumentError("unsupported algebraic operator"))
            values[i] = key == ("IDENTITY", "v1") ? args[1] : key == ("ADD", "v1") ? sum(args) :
                key == ("SUB", "v1") ? args[1] - args[2] : key == ("NEG", "v1") ? -args[1] :
                key == ("SCALAR_MUL", "v1") ? args[1] * args[2] : args[2] == 0 ? throw(ArgumentError("division by zero")) : args[1] / args[2]
            isfinite(values[i]) || throw(ArgumentError("non-finite algebraic value"))
        else
            throw(ArgumentError("unsupported AST node"))
        end
    end
    root = row.program.roots[row.root_position]
    values[root] === nothing && throw(ArgumentError("constraint root is not evaluated"))
    value = values[root]::Float64
    isfinite(value) || throw(ArgumentError("non-finite residual")); value
end

function evaluate_algebraic_residual(plan::AlgebraicResidualPlanV4, u)
    xs = Float64[_alg_finite(v, "state vector") for v in u]
    length(xs) == length(plan.state_refs) || throw(ArgumentError("state vector length mismatch"))
    Tuple(_alg_eval_row(plan, row, xs) for row in plan.rows)
end

function _alg_norm(plan, residuals)
    maximum(abs(residuals[i]) / plan.scales[i] for i in eachindex(residuals))
end

function _alg_audit(plan, xs)
    Tuple((state_ref=plan.state_refs[i], lower=plan.lower_bounds[i], upper=plan.upper_bounds[i],
        value=xs[i], margin_lower=xs[i] - plan.lower_bounds[i], margin_upper=plan.upper_bounds[i] - xs[i])
        for i in eachindex(xs))
end

function _alg_result(plan, scenario, status, xs, residuals, norm, history, reason)
    reference_norm = isempty(history) ? 1.0 : max(1.0, Float64(getproperty(first(history), :normalized_residual)))
    AlgebraicResidualResultV4(_ALG_RESULT_TOKEN, plan, scenario, status, xs, residuals, norm, history,
        _alg_audit(plan, xs), reference_norm, reason)
end

function solve_algebraic_residual(plan::AlgebraicResidualPlanV4, scenario::AlgebraicScenarioV4)
    p = plan.numerical_protocol
    scenario.abs_tol == p.abs_tol && scenario.rel_tol == p.rel_tol && scenario.max_iterations == p.max_iterations &&
        scenario.fd_step == p.fd_step && scenario.min_line_search == p.min_line_search ||
        throw(ArgumentError("scenario protocol does not match frozen plan protocol"))
    xs = try _alg_value_index(plan, scenario) catch e
        return _alg_result(plan, scenario, :numerical_fail, [v.value for v in scenario.state_values], nothing, nothing, (), sprint(showerror, e))
    end
    all(plan.lower_bounds[i] <= xs[i] <= plan.upper_bounds[i] for i in eachindex(xs)) ||
        return _alg_result(plan, scenario, :numerical_fail, xs, nothing, nothing, (), "scenario initial value is outside bounds")
    history = Any[]
    try
        residuals = collect(evaluate_algebraic_residual(plan, xs)); norm = _alg_norm(plan, residuals)
        reference_norm = max(1.0, norm)
        tolerance = p.abs_tol + p.rel_tol * reference_norm
        for iteration in 0:p.max_iterations
            push!(history, (iteration=iteration, state_values=Tuple(xs), residuals=Tuple(residuals), normalized_residual=norm, step_scale=1.0))
            norm <= tolerance && return _alg_result(plan, scenario, :converged, xs, residuals, norm, history, nothing)
            iteration == p.max_iterations && break
            n = length(xs); jac = Matrix{Float64}(undef, n, n)
            for j in 1:n
                delta = p.fd_step * max(1.0, abs(xs[j])); xp = copy(xs); xm = copy(xs)
                if xs[j] + delta <= plan.upper_bounds[j]
                    xp[j] += delta
                    rp = collect(evaluate_algebraic_residual(plan, xp))
                    for i in 1:n; jac[i, j] = (rp[i] - residuals[i]) / delta; end
                elseif xs[j] - delta >= plan.lower_bounds[j]
                    xm[j] -= delta
                    rm = collect(evaluate_algebraic_residual(plan, xm))
                    for i in 1:n; jac[i, j] = (residuals[i] - rm[i]) / delta; end
                else
                    throw(ArgumentError("finite-difference step is outside bounds"))
                end
            end
            step = try jac \ (-Float64.(residuals)) catch; throw(ArgumentError("singular Jacobian")) end
            all(isfinite, step) || throw(ArgumentError("non-finite Newton step"))
            alpha = 1.0; accepted = false
            while alpha >= p.min_line_search
                trial = xs .+ alpha .* step
                if all(plan.lower_bounds[i] <= trial[i] <= plan.upper_bounds[i] && isfinite(trial[i]) for i in eachindex(trial))
                    trial_residuals = collect(evaluate_algebraic_residual(plan, trial)); trial_norm = _alg_norm(plan, trial_residuals)
                    if isfinite(trial_norm) && trial_norm < norm
                        xs = trial; residuals = trial_residuals; norm = trial_norm; accepted = true; break
                    end
                end
                alpha /= 2
            end
            accepted || throw(ArgumentError("no bounded Newton descent"))
            history[end] = merge(history[end], (step_scale=alpha,))
        end
        _alg_result(plan, scenario, :numerical_fail, xs, residuals, norm, history, "maximum iterations exceeded")
    catch e
        residuals = try collect(evaluate_algebraic_residual(plan, xs)) catch; nothing end
        norm = residuals === nothing ? nothing : _alg_norm(plan, residuals)
        _alg_result(plan, scenario, :numerical_fail, xs, residuals, norm, history, sprint(showerror, e))
    end
end

const _ALG_EXECUTORS = Dict{Digest256,Function}()

function _alg_executor_for(plan::AlgebraicResidualPlanV4)
    get!(_ALG_EXECUTORS, plan.plan_hash) do
        input -> begin
            hasproperty(input.payload, :plan_hash) && input.payload.plan_hash == plan.plan_hash ||
                throw(ArgumentError("algebraic executor received a different plan"))
            values = input.payload.scenario_values
            scenario = AlgebraicScenarioV4(input.payload.scenario_name, values;
                abs_tol=input.payload.protocol.abs_tol, rel_tol=input.payload.protocol.rel_tol,
                max_iterations=input.payload.protocol.max_iterations, fd_step=input.payload.protocol.fd_step,
                min_line_search=input.payload.protocol.min_line_search)
            scenario.scenario_hash == input.payload.scenario_hash || throw(ArgumentError("algebraic executor scenario hash mismatch"))
            solve_algebraic_residual(plan, scenario)
        end
    end
end

function algebraic_residual_manifest(plan::AlgebraicResidualPlanV4)
    ProviderManifestV4(_ALG_SCHEMA, _ALG_REVISION, :algebraic_constraint_screen, plan.capability,
        (bounds_hash=plan.minimality_scope.bounds_hash, plan_hash=plan.plan_hash),
        "runtime-v4-algebraic-residual", _ALG_REVISION, _ALG_SOURCE_HASH,
        "algebraic-residual-screen", screen_only; input_schema_hash=plan.capability.input_schema_hash,
        executor=_alg_executor_for(plan))
end

function _alg_deferred_report(subject, input, reason)
    sv = StatusVectorV4(required, no_match, terminal_deferred, low_fidelity_evaluated, terminal_deferred_stage)
    evidence = RuntimeEvidenceV4(subject.subject_hash, subject.scenario_hash,
        input === nothing ? subject.subject_hash : input.solver_input_hash, nothing,
        (subject_hash=subject.subject_hash, reason=reason), sv, (); claim_ceiling=none)
    AlgebraicSliceReportV4(subject, input, nothing, evidence)
end

function execute_algebraic_once!(store, plan::AlgebraicResidualPlanV4, scenario::AlgebraicScenarioV4;
                                provider=algebraic_residual_manifest(plan))
    subject = ExecutableAlgebraicSubjectV4(plan, scenario)
    provider === nothing && return _alg_deferred_report(subject, nothing, "algebraic residual provider is absent")
    provider isa ProviderManifestV4 || throw(ArgumentError("algebraic provider must be typed"))
    local_manifest = algebraic_residual_manifest(plan)
    provider.manifest_hash == local_manifest.manifest_hash && provider.code_hash == local_manifest.code_hash &&
        provider.backend_revision == local_manifest.backend_revision && provider.executor === local_manifest.executor ||
        throw(ArgumentError("provider is not the locally audited algebraic residual implementation"))
    match = match_provider(plan.capability, provider)
    match.status == unique_match || return _alg_deferred_report(subject, nothing, match.reason)
    payload = (plan_hash=plan.plan_hash, scenario_hash=scenario.scenario_hash,
        subject_hash=subject.subject_hash, constraint_subgraph_scope=true,
        requested_obligation=plan.capability,
        scenario_name=scenario.name, scenario_values=scenario.state_values,
        protocol=plan.numerical_protocol)
    input = SolverInputV4(subject.subject_hash, scenario.scenario_hash, provider.manifest_hash,
        provider.input_schema_hash, payload)
    if haskey(store, input.solver_input_hash)
        cached = store[input.solver_input_hash]
        cached isa AlgebraicSliceReportV4 || throw(ArgumentError("algebraic cache entry has wrong type"))
        cached.input !== nothing && cached.input.solver_input_hash == input.solver_input_hash ||
            throw(ArgumentError("algebraic cache input hash mismatch"))
        cached.subject.subject_hash == subject.subject_hash && cached.subject.plan_hash == plan.plan_hash &&
            cached.subject.scenario_hash == scenario.scenario_hash || throw(ArgumentError("algebraic cache subject mismatch"))
        cached.result !== nothing || throw(ArgumentError("algebraic cache has no result"))
        cached.result.plan_hash == plan.plan_hash && cached.result.scenario_hash == scenario.scenario_hash ||
            throw(ArgumentError("algebraic cache result mismatch"))
        cached.evidence.provider_manifest_hash == provider.manifest_hash &&
            cached.evidence.solver_input_hash == input.solver_input_hash || throw(ArgumentError("algebraic cache evidence mismatch"))
        return cached
    end
    result = provider.executor(input)
    result isa AlgebraicResidualResultV4 || throw(ArgumentError("algebraic provider returned an invalid result"))
    result.plan_hash == plan.plan_hash && result.scenario_hash == scenario.scenario_hash ||
        throw(ArgumentError("algebraic provider result identity mismatch"))
    outcome = result.status == :converged ? pass : numerical_fail
    status = StatusVectorV4(required, unique_match, resolved, low_fidelity_evaluated, outcome)
    metrics = result.residual_norm === nothing ? () :
        (MetricWithUnit(:normalized_residual, result.residual_norm),
         MetricWithUnit(:iterations, length(result.iteration_history)))
    evidence = RuntimeEvidenceV4(subject.subject_hash, scenario.scenario_hash, input.solver_input_hash,
        provider.manifest_hash,
        (subject_hash=subject.subject_hash, plan_hash=plan.plan_hash, scenario_hash=scenario.scenario_hash,
         provider_manifest_hash=provider.manifest_hash, backend_revision=provider.backend_revision,
         constraint_subgraph_scope=true), status, metrics; claim_ceiling=screen_only,
        provider_manifest=provider, backend_revision=provider.backend_revision,
        numerical_configuration_hash=canonical_hash((plan=plan.numerical_protocol,
            scenario=(scenario.abs_tol, scenario.rel_tol, scenario.max_iterations,
                      scenario.fd_step, scenario.min_line_search))), artifact_refs=(result.result_hash,))
    report = AlgebraicSliceReportV4(subject, input, result, evidence)
    store[input.solver_input_hash] = report
    report
end
