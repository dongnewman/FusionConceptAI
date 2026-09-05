# D1.1 compiler for candidate-bound typed constant-mass ODEs.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: semantic_view, canonical_hash

const _TTR_REVISION = "typed-time-residual-v1"
const _TTR_TOKEN = Val(:typed_time_residual_private)
_ttr_float(x, field) = begin
    y = try Float64(x) catch
        throw(ArgumentError("$field must be numeric"))
    end
    isfinite(y) || throw(ArgumentError("$field must be finite"))
    y
end

struct TimeResidualRowBindingV4
    state_ref::StateGeneRefV1
    governing_edge_hash::Digest256
    mass_root_position::Int
    rhs_edge_hash::Digest256
    rhs_root_position::Int
    function TimeResidualRowBindingV4(s, g, m, r, q)
        s isa StateGeneRefV1 || throw(ArgumentError("typed state ref required"))
        m isa Integer && q isa Integer && m > 0 && q > 0 ||
            throw(ArgumentError("root positions must be positive"))
        new(s, g, Int(m), r, Int(q))
    end
end
semantic_view(x::TimeResidualRowBindingV4) =
    (state_ref=x.state_ref, governing_edge_hash=x.governing_edge_hash,
     mass_root_position=x.mass_root_position, rhs_edge_hash=x.rhs_edge_hash,
     rhs_root_position=x.rhs_root_position)

struct TimeIntegrationProtocolV4
    method::Symbol
    step::Float64
    max_steps::Int
    residual_abs_tol::Float64
    residual_rel_tol::Float64
    protocol_hash::Digest256
    function TimeIntegrationProtocolV4(method::Symbol=:fixed_rk4, step=.01,
                                       max_steps=1000; residual_abs_tol=1e-10,
                                       residual_rel_tol=1e-10)
        method === :fixed_rk4 || throw(ArgumentError("only fixed_rk4 is admitted"))
        h = _ttr_float(step, "step")
        h > 0 && max_steps isa Integer && max_steps > 0 ||
            throw(ArgumentError("invalid step budget"))
        a = _ttr_float(residual_abs_tol, "residual_abs_tol")
        r = _ttr_float(residual_rel_tol, "residual_rel_tol")
        a > 0 && r >= 0 || throw(ArgumentError("invalid residual tolerances"))
        body = (revision=_TTR_REVISION, method=method, step=h,
                max_steps=Int(max_steps), residual_abs_tol=a,
                residual_rel_tol=r)
        new(method, h, Int(max_steps), a, r, canonical_hash(body))
    end
end
semantic_view(x::TimeIntegrationProtocolV4) =
    (method=x.method, step=x.step, max_steps=x.max_steps,
     residual_abs_tol=x.residual_abs_tol, residual_rel_tol=x.residual_rel_tol)

struct _TTRRow
    binding::TimeResidualRowBindingV4
    state_type::PhysicalType
    lower::Float64
    upper::Float64
    mass_coefficients::Vector{Float64}
    rhs_program::TypedASTProgramV1
    rhs_ports::Tuple
    rhs_root_position::Int
end

function _ttr_validate_program(program, registry)
    bindings = program.used_manifest_bindings
    for node in program.nodes
        node isa ASTApplyV1 || continue
        refs = Tuple(b for b in bindings if b[1] == node.operator_ref)
        length(refs) == 1 || throw(ArgumentError("AST operator lacks one exact manifest binding"))
        ref, digest = only(refs)
        ref == node.operator_ref || throw(ArgumentError("operator reference binding mismatch"))
        ref.qualified.version == "v1" || throw(ArgumentError("only v1 operator manifests are admitted"))
        manifest = try operator_manifest(registry, ref.qualified) catch
            throw(ArgumentError("operator manifest is absent from supplied registry"))
        end
        manifest.operator_ref == ref && manifest.manifest_hash == digest ||
            throw(ArgumentError("operator manifest hash/reference mismatch"))
        manifest.operator_ref.qualified.version == "v1" ||
            throw(ArgumentError("operator manifest version is not v1"))
    end
    nothing
end

_ttr_operator_id(node::ASTApplyV1, registry) = begin
    ref = node.operator_ref
    ref.qualified.version == "v1" || throw(ArgumentError("operator version is unsupported"))
    manifest = operator_manifest(registry, ref.qualified)
    manifest.operator_ref == ref || throw(ArgumentError("operator reference mismatch"))
    manifest
end


struct TypedTimeResidualFormV4
    prefix_hash::Digest256
    state_refs::Tuple
    state_types::Tuple
    rows::Tuple
    mass_matrix::Matrix{Float64}
    form_hash::Digest256
    function TypedTimeResidualFormV4(token::Val{:typed_time_residual_private}, prefix, refs, types,
                                     rows, matrix, form_hash)
        token === _TTR_TOKEN || throw(ArgumentError("private constructor"))
        new(prefix, refs, types, rows, matrix, form_hash)
    end
end
semantic_view(x::TypedTimeResidualFormV4) =
    (revision=_TTR_REVISION, prefix_hash=x.prefix_hash, state_refs=x.state_refs, state_types=x.state_types,
     rows=x.rows, mass_matrix=x.mass_matrix, form_hash=x.form_hash)
function _ttr_form_identity(x::TypedTimeResidualFormV4)
    row_hashes = Tuple((binding=r.binding, state_type=r.state_type,
        lower=r.lower, upper=r.upper, mass_coefficients=Tuple(r.mass_coefficients),
        rhs_program=r.rhs_program, rhs_ports=r.rhs_ports,
        rhs_root_position=r.rhs_root_position) for r in x.rows)
    canonical_hash((revision=_TTR_REVISION, prefix=x.prefix_hash,
        states=x.state_refs, state_types=x.state_types, rows=row_hashes, mass_matrix=x.mass_matrix))
end
function _ttr_validate_form(x::TypedTimeResidualFormV4)
    _ttr_form_identity(x) == x.form_hash || throw(ArgumentError("typed residual form identity mismatch"))
    nothing
end
canonical_hash(x::TypedTimeResidualFormV4) = (_ttr_validate_form(x); x.form_hash)

struct TypedTimeResidualPlanV4
    compiled_prefix_hash::Digest256
    form::TypedTimeResidualFormV4
    protocol::TimeIntegrationProtocolV4
    plan_hash::Digest256
    function TypedTimeResidualPlanV4(token::Val{:typed_time_residual_private}, prefix,
                                     form, protocol, plan_hash)
        token === _TTR_TOKEN || throw(ArgumentError("private constructor"))
        new(prefix, form, protocol, plan_hash)
    end
end
semantic_view(x::TypedTimeResidualPlanV4) =
    (revision=_TTR_REVISION, compiled_prefix_hash=x.compiled_prefix_hash,
     form=x.form, protocol=x.protocol, plan_hash=x.plan_hash)
function _ttr_validate_plan(x::TypedTimeResidualPlanV4)
    _ttr_validate_form(x.form)
    expected = canonical_hash((revision=_TTR_REVISION, prefix=x.compiled_prefix_hash,
        form_hash=x.form.form_hash, protocol=x.protocol))
    expected == x.plan_hash || throw(ArgumentError("typed residual plan identity mismatch"))
    nothing
end
canonical_hash(x::TypedTimeResidualPlanV4) = (_ttr_validate_plan(x); x.plan_hash)

function _ttr_edge(graph, digest)
    hits = [e for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1 &&
            canonical_hash(e) == digest]
    length(hits) == 1 || throw(ArgumentError("edge hash missing or ambiguous"))
    only(hits)
end

function _ttr_ports(edge, graph, states)
    state_index = Dict(s.state_ref.value => i for (i, s) in enumerate(states))
    ports = Dict{Int,Int}()
    for binding in edge.input_bindings
        node = graph.nodes[binding.graph_node_index]
        node.node_kind === :state || throw(ArgumentError("edge input is not state"))
        haskey(state_index, node.node_id) || throw(ArgumentError("foreign state input"))
        ast_index = edge.program.input_ports[binding.program_position]
        ast = edge.program.nodes[ast_index]
        ast isa ASTInputV1 || throw(ArgumentError("input binding is not ASTInput"))
        haskey(ports, ast.port) && throw(ArgumentError("duplicate input port"))
        ports[ast.port] = state_index[node.node_id]
    end
    ports
end

function _ttr_mass(program, ports, n, root_position, registry)
    function walk(index)
        node = program.nodes[index]
        if node isa ASTInputV1
            haskey(ports, node.port) || throw(ArgumentError("unbound mass input"))
            return (:state, ports[node.port], zeros(n))
        elseif node isa ASTConstantV1
            return (:constant, 0, [_ttr_float(node.value, "mass constant")])
        elseif node isa ASTParameterV1
            throw(ArgumentError("parameter node deferred in D1.1"))
        elseif node isa ASTApplyV1
            op = String(_ttr_operator_id(node, registry).operator_ref.qualified.id)
            args = [walk(i) for i in node.inputs]
            if op == "DT"
                length(args) == 1 && program.nodes[node.inputs[1]] isa ASTInputV1 &&
                    args[1][1] === :state ||
                    throw(ArgumentError("DT must directly act on state"))
                coeff = zeros(n)
                coeff[args[1][2]] = 1.0
                return (:mass, 0, coeff)
            elseif op == "IDENTITY"
                throw(ArgumentError("IDENTITY cannot wrap a mass term"))
            elseif op == "NEG"
                args[1][1] === :mass || throw(ArgumentError("invalid mass NEG"))
                return (:mass, 0, -args[1][3])
            elseif op in ("ADD", "SUB")
                all(a -> a[1] === :mass, args) ||
                    throw(ArgumentError("mass ADD/SUB requires derivative terms"))
                coeff = args[1][3] + args[2][3]
                op == "SUB" && (coeff = args[1][3] - args[2][3])
                return (:mass, 0, coeff)
            elseif op in ("SCALAR_MUL", "SCALAR_DIV")
                length(args) == 2 || throw(ArgumentError("binary scalar operator required"))
                a, b = args
                if a[1] === :mass && b[1] === :constant
                    c = only(b[3])
                    op == "SCALAR_DIV" && (c = 1 / c)
                    isfinite(c) && c != 0 || throw(ArgumentError("invalid mass scalar"))
                    return (:mass, 0, a[3] .* c)
                elseif op == "SCALAR_MUL" && b[1] === :mass && a[1] === :constant
                    return (:mass, 0, b[3] .* only(a[3]))
                end
                throw(ArgumentError("mass coefficient must be constant"))
            end
            throw(ArgumentError("unsupported mass operator $op"))
        end
        throw(ArgumentError("unsealed AST node"))
    end
    1 <= root_position <= length(program.roots) || throw(ArgumentError("mass root position out of range"))
    kind, _, coeff = walk(program.roots[root_position])
    kind === :mass || throw(ArgumentError("mass root contains no DT"))
    coeff
end

function _ttr_eval_rhs(program, ports, root_position, y)
    1 <= root_position <= length(program.roots) || throw(ArgumentError("RHS root position out of range"))
    portmap = Dict{Int,Int}(p.port => p.state for p in ports)
    function eval_node(index)
        node = program.nodes[index]
        node isa ASTInputV1 && return (haskey(portmap, node.port) ? y[portmap[node.port]] : throw(ArgumentError("unbound RHS input")))
        node isa ASTConstantV1 && return _ttr_float(node.value, "RHS constant")
        node isa ASTParameterV1 && throw(ArgumentError("parameter node deferred in D1.1"))
        node isa ASTApplyV1 || throw(ArgumentError("unsealed AST node"))
        op = node.operator_ref.qualified.id
        op == "DT" && throw(ArgumentError("RHS cannot contain DT"))
        args = Tuple(eval_node(i) for i in node.inputs)
        op == "IDENTITY" && return only(args)
        op == "NEG" && return -only(args)
        op == "ADD" && return sum(args)
        op == "SUB" && return args[1] - args[2]
        op == "SCALAR_MUL" && return args[1] * args[2]
        op == "SCALAR_DIV" && return args[1] / args[2]
        throw(ArgumentError("unsupported RHS operator $op"))
    end
    eval_node(program.roots[root_position])
end

function compile_typed_time_residual_plan(compiled::CompiledCandidatePrefixV4,
                                          registry::GenomeContractRegistryV4;
                                          row_bindings, protocol=TimeIntegrationProtocolV4())
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope,
        compiled.minimality_scope.scenario_scope)
    payload = compiled.candidate.mechanism_genome_ref.payload
    graph = payload.operator_graph
    states = Tuple(sort(collect(payload.states), by=s -> s.state_ref.value))
    isempty(states) && throw(ArgumentError("no state genes"))
    all(s -> s.physical_type.value_kind === :scalar_field &&
             s.physical_type.tensor_rank == 0 && s.physical_type.spatial_dimension == 0 &&
             s.physical_type.temporal_type.kind === differential_time &&
             s.physical_type.temporal_type.derivative_order == 0, states) ||
        throw(ArgumentError("D1 accepts only order-zero differential states"))
    bindings = Tuple(row_bindings)
    length(bindings) == length(states) || throw(ArgumentError("row count mismatch"))
    refs = Tuple(s.state_ref for s in states)
    Tuple(sort(collect(b.state_ref.value for b in bindings))) ==
        Tuple(r.value for r in refs) || throw(ArgumentError("row coverage mismatch"))
    n = length(states)
    matrix = zeros(n, n)
    rows = Vector{_TTRRow}(undef, n)
    for (row_number, state) in enumerate(states)
        binding = only(b for b in bindings if b.state_ref == state.state_ref)
        governing_edge = _ttr_edge(graph, binding.governing_edge_hash)
        _ttr_validate_program(governing_edge.program, default_operator_registry())
        governing_edge.role === governing || throw(ArgumentError("wrong governing role"))
        identity_index = governing_edge.program.roots[1]
        identity_node = governing_edge.program.nodes[identity_index]
        identity_node isa ASTApplyV1 || throw(ArgumentError("identity root must be apply"))
        String(identity_node.operator_ref.qualified.id) == "IDENTITY" &&
            String(identity_node.operator_ref.qualified.version) == "v1" ||
            throw(ArgumentError("identity root must be IDENTITY@v1"))
        length(identity_node.inputs) == 1 &&
            governing_edge.program.nodes[identity_node.inputs[1]] isa ASTInputV1 ||
            throw(ArgumentError("identity must directly consume ASTInput"))
        outputs = [o for o in governing_edge.output_bindings if o.program_position == 1]
        length(outputs) == 1 || throw(ArgumentError("identity root ownership missing"))
        graph.nodes[only(outputs).graph_node_index].node_id == state.state_ref.value ||
            throw(ArgumentError("identity root does not own state"))
        owned_binding = only(b for b in governing_edge.input_bindings
            if graph.nodes[b.graph_node_index].node_id == state.state_ref.value)
        identity_node.inputs[1] == governing_edge.program.input_ports[owned_binding.program_position] ||
            throw(ArgumentError("identity root input is not owned state"))
        mass_outputs = [o for o in governing_edge.output_bindings if
                        o.program_position == binding.mass_root_position]
        length(mass_outputs) == 1 || throw(ArgumentError("mass root output missing"))
        mass_node = graph.nodes[only(mass_outputs).graph_node_index]
        mass_node.physical_type.temporal_type.derivative_order == 1 ||
            throw(ArgumentError("mass root must have derivative order one"))
        coeff = _ttr_mass(governing_edge.program,
                          _ttr_ports(governing_edge, graph, states), n,
                          binding.mass_root_position, default_operator_registry())
        matrix[row_number, :] .= coeff
        rhs_edge = _ttr_edge(graph, binding.rhs_edge_hash)
        _ttr_validate_program(rhs_edge.program, default_operator_registry())
        rhs_edge.role === additive || throw(ArgumentError("wrong RHS role"))
        rhs_outputs = [o for o in rhs_edge.output_bindings if
                       o.program_position == binding.rhs_root_position]
        length(rhs_outputs) == 1 || throw(ArgumentError("RHS output missing"))
        rhs_node = graph.nodes[only(rhs_outputs).graph_node_index]
        rhs_node.physical_type.temporal_type.derivative_order == 0 ||
            throw(ArgumentError("RHS must be derivative free"))
        rhs_node.physical_type.value_kind == mass_node.physical_type.value_kind &&
            rhs_node.physical_type.tensor_rank == mass_node.physical_type.tensor_rank &&
            rhs_node.physical_type.spatial_dimension == mass_node.physical_type.spatial_dimension &&
            rhs_node.physical_type.units == mass_node.physical_type.units ||
            throw(ArgumentError("RHS/mass value shape mismatch"))
        lower = _ttr_float(state.physical_bounds.interval.lower, "lower bound")
        upper = _ttr_float(state.physical_bounds.interval.upper, "upper bound")
        lower <= upper && state.physical_bounds.unit == state.physical_type.units ||
            throw(ArgumentError("invalid state bounds"))
        rhs_ports = Tuple((port=p[1], state=p[2]) for p in
            sort(collect(_ttr_ports(rhs_edge, graph, states)), by=first))
        rows[row_number] = _TTRRow(binding, state.physical_type, lower, upper,
                                   coeff, rhs_edge.program, rhs_ports,
                                   binding.rhs_root_position)
    end
    all(isfinite, matrix) || throw(ArgumentError("nonfinite mass matrix"))
    rank(matrix) == n || throw(ArgumentError("singular mass matrix"))
    isfinite(cond(matrix)) && cond(matrix) < 1e12 || throw(ArgumentError("ill-conditioned mass matrix"))
    row_tuple = Tuple(rows)
    row_hashes = Tuple((binding=r.binding, state_type=r.state_type,
        lower=r.lower, upper=r.upper, mass_coefficients=Tuple(r.mass_coefficients),
        rhs_program=r.rhs_program, rhs_ports=r.rhs_ports,
        rhs_root_position=r.rhs_root_position)
        for r in rows)
    state_types = Tuple(s.physical_type for s in states)
    form_hash = canonical_hash((revision=_TTR_REVISION, prefix=compiled.prefix_hash,
        states=refs, state_types=state_types, rows=row_hashes, mass_matrix=matrix))
    form = TypedTimeResidualFormV4(_TTR_TOKEN, compiled.prefix_hash, refs, state_types,
        row_tuple, copy(matrix), form_hash)
    plan_hash = canonical_hash((revision=_TTR_REVISION, prefix=compiled.prefix_hash,
        form_hash=form_hash, protocol=protocol))
    TypedTimeResidualPlanV4(_TTR_TOKEN, compiled.prefix_hash, form, protocol, plan_hash)
end

struct StateValueV4
    state_ref::StateGeneRefV1
    value::Float64
    unit::UnitSignature
    function StateValueV4(ref, value, unit)
        ref isa StateGeneRefV1 || throw(ArgumentError("typed state ref required"))
        v = _ttr_float(value, "initial value")
        new(ref, v, unit)
    end
end

struct TimeIntegrationScenarioV4
    name::String
    t_start::Float64
    t_stop::Float64
    time_unit::UnitSignature
    initial_values::Tuple
    scenario_hash::Digest256
    function TimeIntegrationScenarioV4(name, a, b, unit, values)
        x, y = _ttr_float(a, "t_start"), _ttr_float(b, "t_stop")
        y > x || throw(ArgumentError("t_stop must exceed t_start"))
        unit == UnitSignature((0, 0, 1, 0, 0, 0, 0)) ||
            throw(ArgumentError("time_unit must be exactly the time dimension"))
        vals = Tuple(values)
        all(v -> v isa StateValueV4, vals) || throw(ArgumentError("typed initial values required"))
        ordered = Tuple(sort(collect(vals), by=v -> v.state_ref.value))
        length(unique(v.state_ref.value for v in ordered)) == length(ordered) ||
            throw(ArgumentError("duplicate initial state"))
        body = (revision=_TTR_REVISION, name=String(name), t_start=x, t_stop=y,
            time_unit=unit, initial_values=ordered)
        new(String(name), x, y, unit, ordered, canonical_hash(body))
    end
end

struct TypedTimeResidualResultV4
    status::Symbol
    times::Tuple
    states::Tuple
    rhs_evaluations::Int
    mass_solve_residual_norm::Union{Nothing,Float64}
    trajectory_defect_norm::Union{Nothing,Float64}
    residual_norm::Union{Nothing,Float64}
    failure_reason::Union{Nothing,String}
    trajectory_hash::Digest256
    result_hash::Digest256
    function TypedTimeResidualResultV4(token::Val{:typed_time_residual_private}, status, times,
                                       states, evaluations, mass_residual, trajectory_defect, residual, reason, trajectory_hash,
                                       result_hash)
        token === _TTR_TOKEN || throw(ArgumentError("private constructor"))
        new(status, times, states, evaluations, mass_residual, trajectory_defect, residual, reason, trajectory_hash, result_hash)
    end
end

function _ttr_result(plan, scenario, status, times, states, evaluations, mass_residual, trajectory_defect, reason)
    ts, ys = Tuple(times), Tuple(Tuple(y) for y in states)
    mr = isfinite(mass_residual) ? mass_residual : nothing
    td = isfinite(trajectory_defect) ? trajectory_defect : nothing
    finite_residual = (mr === nothing || td === nothing) ? nothing : max(mr, td)
    trajectory_hash = canonical_hash((times=ts, states=ys))
    result_hash = canonical_hash((revision=_TTR_REVISION, candidate_prefix=plan.compiled_prefix_hash,
        form_hash=plan.form.form_hash, scenario_hash=scenario.scenario_hash,
        protocol_hash=plan.protocol.protocol_hash, status=status,
        trajectory_hash=trajectory_hash, rhs_evaluations=evaluations,
        mass_solve_residual_norm=mr, trajectory_defect_norm=td, residual_norm=finite_residual, failure_reason=reason))
    TypedTimeResidualResultV4(_TTR_TOKEN, status, ts, ys, evaluations, mr, td, finite_residual, reason,
        trajectory_hash, result_hash)
end

"""Independent replayable defect for the accepted RK4 update."""
function rk4_update_defect_v4(y_old, y_new, h, k1, k2, k3, k4)
    h > 0 || throw(ArgumentError("RK4 step must be positive"))
    expected = y_old .+ (h / 6) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    norm(y_new .- expected, Inf)
end

function _ttr_replay_trajectory(form, times, states)
    _ttr_validate_form(form)
    length(times) == length(states) || throw(ArgumentError("trajectory length mismatch"))
    length(times) >= 1 || throw(ArgumentError("trajectory cannot be empty"))
    all(isfinite, times) || throw(ArgumentError("trajectory times must be finite"))
    all(times[i] < times[i + 1] for i in 1:(length(times) - 1)) ||
        throw(ArgumentError("trajectory times must be strictly increasing"))
    n = length(form.rows)
    all(length(s) == n && all(isfinite, s) &&
        all(form.rows[i].lower <= s[i] <= form.rows[i].upper for i in 1:n)
        for s in states) || throw(ArgumentError("trajectory state violates form bounds"))
    factor = lu(form.mass_matrix)
    defect = 0.0
    evaluations = 0
    slope(z) = begin
        evaluations += 1
        factor \ Float64[_ttr_eval_rhs(r.rhs_program, r.rhs_ports, r.rhs_root_position, z)
            for r in form.rows]
    end
    for i in 1:(length(times) - 1)
        y0 = Float64[states[i]...]
        yn = Float64[states[i + 1]...]
        h = times[i + 1] - times[i]
        k1 = slope(y0)
        k2 = slope(y0 .+ h .* k1 ./ 2)
        k3 = slope(y0 .+ h .* k2 ./ 2)
        k4 = slope(y0 .+ h .* k3)
        defect = max(defect, rk4_update_defect_v4(y0, yn, h, k1, k2, k3, k4))
    end
    (defect=defect, evaluations=evaluations)
end
replay_typed_time_trajectory(form, times, states) = _ttr_replay_trajectory(form, times, states)

function integrate_typed_time_residual(plan::TypedTimeResidualPlanV4,
                                       scenario::TimeIntegrationScenarioV4;
                                       protocol=plan.protocol)
    protocol == plan.protocol || throw(ArgumentError("execution protocol must equal plan protocol"))
    _ttr_validate_plan(plan)
    form = plan.form
    refs = Tuple(v.state_ref.value for v in scenario.initial_values)
    refs == Tuple(r.value for r in form.state_refs) ||
        return _ttr_result(plan, scenario, :numerical_failure, (scenario.t_start,),
            (Float64[v.value for v in scenario.initial_values],), 0, Inf, Inf, "initial coverage")
    all(form.state_types[i].units == scenario.initial_values[i].unit &&
        form.rows[i].lower <= scenario.initial_values[i].value <= form.rows[i].upper
        for i in eachindex(form.rows)) ||
        return _ttr_result(plan, scenario, :numerical_failure, (scenario.t_start,),
            (Float64[v.value for v in scenario.initial_values],), 0, Inf, Inf, "initial units or bounds")
    y = Float64[v.value for v in scenario.initial_values]
    times = [scenario.t_start]
    states = [copy(y)]
    t = scenario.t_start
    evaluations = 0
    residual_norm = 0.0
    trajectory_defect = 0.0
    factor = try
        lu(form.mass_matrix)
    catch err
        return _ttr_result(plan, scenario, :numerical_failure, times, states, 0, Inf, Inf,
            sprint(showerror, err))
    end
    function slope(z)
        values = Float64[_ttr_eval_rhs(form.rows[i].rhs_program, form.rows[i].rhs_ports,
            form.rows[i].rhs_root_position, z) for i in eachindex(form.rows)]
        evaluations += 1
        all(isfinite, values) || throw(ArgumentError("nonfinite RHS"))
        k = factor \ values
        (k, values)
    end
    time_tolerance = 32 * eps(max(abs(scenario.t_start), abs(scenario.t_stop), 1.0))
    while t < scenario.t_stop
        length(times) - 1 < protocol.max_steps ||
            return _ttr_result(plan, scenario, :numerical_failure, times, states,
                evaluations, Inf, Inf, "step budget exhausted")
        h = min(protocol.step, scenario.t_stop - t)
        try
            k1, f1 = slope(y)
            y2 = y .+ h .* k1 ./ 2
            all(form.rows[i].lower <= y2[i] <= form.rows[i].upper for i in eachindex(y2)) || throw(ArgumentError("stage state bound exit"))
            k2, f2 = slope(y2)
            y3 = y .+ h .* k2 ./ 2
            all(form.rows[i].lower <= y3[i] <= form.rows[i].upper for i in eachindex(y3)) || throw(ArgumentError("stage state bound exit"))
            k3, f3 = slope(y3)
            y4 = y .+ h .* k3
            all(form.rows[i].lower <= y4[i] <= form.rows[i].upper for i in eachindex(y4)) || throw(ArgumentError("stage state bound exit"))
            k4, f4 = slope(y4)
            for (k, values) in ((k1, f1), (k2, f2), (k3, f3), (k4, f4))
                residual_norm = max(residual_norm, maximum(abs.(form.mass_matrix * k - values)))
            end
            y_old = copy(y)
            y_update = y .+ h .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4) ./ 6
            y = y_update
            all(isfinite, y) || throw(ArgumentError("nonfinite state"))
            all(form.rows[i].lower <= y[i] <= form.rows[i].upper for i in eachindex(y)) ||
                throw(ArgumentError("state bound exit"))
        catch err
            return _ttr_result(plan, scenario, :numerical_failure, times, states,
                evaluations, Inf, Inf, sprint(showerror, err))
        end
        t += h
        abs(scenario.t_stop - t) <= time_tolerance && (t = scenario.t_stop)
        push!(times, t)
        push!(states, copy(y))
    end
    replay = _ttr_replay_trajectory(form, times, states)
    trajectory_defect = replay.defect
    evaluations += replay.evaluations
    limit = protocol.residual_abs_tol + protocol.residual_rel_tol * max(1.0, maximum(abs, y))
    combined = max(residual_norm, trajectory_defect)
    combined <= limit || return _ttr_result(plan, scenario, :numerical_failure,
        times, states, evaluations, residual_norm, trajectory_defect, "residual tolerance failure")
    _ttr_result(plan, scenario, :integrated, times, states, evaluations, residual_norm, trajectory_defect, nothing)
end

function derive_typed_time_residual_plan(plan::TypedTimeResidualPlanV4,
                                         protocol::TimeIntegrationProtocolV4)
    _ttr_validate_plan(plan)
    hash = canonical_hash((revision=_TTR_REVISION,
        prefix=plan.compiled_prefix_hash, form_hash=plan.form.form_hash,
        protocol=protocol))
    TypedTimeResidualPlanV4(_TTR_TOKEN, plan.compiled_prefix_hash, plan.form,
        protocol, hash)
end

typed_time_residual_manifest() =
    (schema="fusionconceptai:runtime-v4-typed-time-residual", revision=_TTR_REVISION,
     kind=:typed_constant_mass_ode_integration,
     backend="julia-fixed-rk4-dense-lu", claim_ceiling=screen_only)
