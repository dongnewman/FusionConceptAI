# D2.1 graph-derived consistent initialization and local index-1 screen.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: canonical_hash

struct _TDAENumericalFailure <: Exception
    code::Symbol
    message::String
end
Base.showerror(io::IO, err::_TDAENumericalFailure) = print(io, err.message)

_tdae_fail(code::Symbol, message::AbstractString) =
    throw(_TDAENumericalFailure(code, String(message)))

function _tdae_source_hash()
    canonical_hash(Tuple(begin
        path = joinpath(@__DIR__, name)
        isfile(path) || throw(ArgumentError("missing audited D2.1 source: $name"))
        (name=name, content_hash=digest256_text(read(path, String)))
    end for name in _TDAE_SOURCE_FILES))
end

function _tdae_scenario_check(s::ConsistentInitializationScenarioV4)
    expected = canonical_hash((revision=_TDAE_REVISION, name=s.name,
        initial_values=s.initial_values))
    expected == s.scenario_hash || throw(ArgumentError("D2.1 scenario tampered"))
    expected
end

function _tdae_state_scale(state)
    lower = Float64(state.physical_bounds.interval.lower)
    upper = Float64(state.physical_bounds.interval.upper)
    scale = max(abs(lower), abs(upper), upper - lower)
    isfinite(scale) && scale > 0 ||
        throw(ArgumentError("D2.1 state bounds do not define a finite positive scale"))
    scale
end

function _tdae_validate_scenario(scenario, states)
    _tdae_scenario_check(scenario)
    expected_refs = Tuple(s.state_ref for s in states)
    Tuple(v.state_ref for v in scenario.initial_values) == expected_refs ||
        throw(ArgumentError("D2.1 scenario exact coverage/order mismatch"))
    for (value, state) in zip(scenario.initial_values, states)
        value.unit == state.physical_type.units ||
            throw(ArgumentError("D2.1 scenario unit mismatch"))
        isfinite(value.value) || throw(ArgumentError("D2.1 scenario nonfinite"))
        lower = Float64(state.physical_bounds.interval.lower)
        upper = Float64(state.physical_bounds.interval.upper)
        lower <= value.value <= upper ||
            throw(ArgumentError("D2.1 scenario value outside state bounds"))
    end
    true
end

function _tdae_require_partition_ports(ports, allowed_refs, label)
    allowed = Set(ref.value for ref in allowed_refs)
    all(ref.value in allowed for ref in values(ports)) ||
        throw(ArgumentError("D2.1 $(label) ports cross the frozen temporal partition"))
    true
end

function _tdae_edge(graph, digest)
    hits = Tuple(e for e in graph.hyperedges
        if e isa AtomicMIMOHyperedgeV1 && canonical_hash(e) == digest)
    length(hits) == 1 || throw(ArgumentError("D2.1 edge hash missing or ambiguous"))
    only(hits)
end

function _tdae_output_binding(edge, root_position::Int)
    1 <= root_position <= length(edge.program.roots) ||
        throw(ArgumentError("D2.1 root position out of range"))
    hits = Tuple(b for b in edge.output_bindings
        if b.program_position == root_position)
    length(hits) == 1 || throw(ArgumentError("D2.1 root output ownership missing"))
    only(hits)
end

function _tdae_program_check(program; allow_dt::Bool)
    _ttr_validate_program(program, default_operator_registry())
    for node in program.nodes
        node isa ASTParameterV1 &&
            throw(ArgumentError("D2.1 parameter nodes are not bound"))
        node isa ASTApplyV1 || continue
        id = String(node.operator_ref.qualified.id)
        node.operator_ref.qualified.version == "v1" ||
            throw(ArgumentError("D2.1 admits only v1 operator manifests"))
        id in _TDAE_ALLOWED_ALGEBRAIC_OPS || (allow_dt && id == "DT") ||
            throw(ArgumentError("operator $id is outside D2.1"))
    end
    true
end

function _tdae_port_refs(edge, graph, state_refs)
    state_set = Set(r.value for r in state_refs)
    ports = Dict{Int,StateGeneRefV1}()
    for binding in edge.input_bindings
        node = graph.nodes[binding.graph_node_index]
        node.node_kind === :state || throw(ArgumentError("D2.1 edge input is not state"))
        node.node_id in state_set || throw(ArgumentError("D2.1 edge has foreign state input"))
        ast_index = edge.program.input_ports[binding.program_position]
        ast = edge.program.nodes[ast_index]
        ast isa ASTInputV1 || throw(ArgumentError("D2.1 input binding is not ASTInput"))
        haskey(ports, ast.port) && throw(ArgumentError("duplicate D2.1 AST input port"))
        ports[ast.port] = StateGeneRefV1(node.node_id)
    end
    ports
end

function _tdae_eval(program, ports, values, root_position; derivatives=Dict{String,Float64}())
    1 <= root_position <= length(program.roots) ||
        throw(ArgumentError("D2.1 evaluation root out of range"))
    cache = Dict{Int,Float64}()
    function eval_node(index::Int)
        haskey(cache, index) && return cache[index]
        node = program.nodes[index]
        value = if node isa ASTInputV1
            haskey(ports, node.port) || throw(ArgumentError("unbound D2.1 AST input"))
            ref = ports[node.port].value
            haskey(values, ref) || throw(ArgumentError("missing D2.1 state value"))
            Float64(values[ref])
        elseif node isa ASTConstantV1
            Float64(node.value)
        elseif node isa ASTParameterV1
            throw(ArgumentError("unbound D2.1 AST parameter"))
        elseif node isa ASTApplyV1
            id = String(node.operator_ref.qualified.id)
            if id == "DT"
                length(node.inputs) == 1 && program.nodes[only(node.inputs)] isa ASTInputV1 ||
                    throw(ArgumentError("DT must directly consume a D2.1 state"))
                input = program.nodes[only(node.inputs)]
                haskey(ports, input.port) || throw(ArgumentError("unbound DT state"))
                ref = ports[input.port].value
                haskey(derivatives, ref) || throw(ArgumentError("missing D2.1 derivative value"))
                Float64(derivatives[ref])
            else
                args = Tuple(eval_node(i) for i in node.inputs)
                id == "IDENTITY" ? only(args) :
                id == "NEG" ? -only(args) :
                id == "ADD" ? sum(args) :
                id == "SUB" ? args[1] - args[2] :
                id == "SCALAR_MUL" ? args[1] * args[2] :
                id == "SCALAR_DIV" ? args[1] / args[2] :
                throw(ArgumentError("operator $id is outside D2.1 evaluator"))
            end
        else
            throw(ArgumentError("unsealed D2.1 AST node"))
        end
        isfinite(value) || _tdae_fail(:nonfinite_evaluation, "nonfinite typed AST evaluation")
        cache[index] = value
        value
    end
    eval_node(program.roots[root_position])
end

function _tdae_owned_identity(edge, graph, state_ref)
    identity_positions = Int[]
    for (position, root_index) in enumerate(edge.program.roots)
        node = edge.program.nodes[root_index]
        if node isa ASTApplyV1 && node.operator_ref.qualified.id == "IDENTITY" &&
                node.operator_ref.qualified.version == "v1"
            length(node.inputs) == 1 && edge.program.nodes[only(node.inputs)] isa ASTInputV1 ||
                continue
            output = _tdae_output_binding(edge, position)
            graph.nodes[output.graph_node_index].node_id == state_ref.value || continue
            input = edge.program.nodes[only(node.inputs)]
            ports = _tdae_port_refs(edge, graph, (state_ref,))
            get(ports, input.port, nothing) == state_ref || continue
            push!(identity_positions, position)
        end
    end
    length(identity_positions) == 1 ||
        throw(ArgumentError("D2.1 governing identity ownership is not exact"))
    only(identity_positions)
end

function _tdae_compile_authority(compiled, differential_refs, algebraic_refs, row_bindings)
    payload = compiled.candidate.mechanism_genome_ref.payload
    graph = payload.operator_graph
    states = Tuple(sort(collect(payload.states), by=s -> s.state_ref.value))
    differential_states = Tuple(s for s in states
        if s.physical_type.temporal_type.kind === differential_time)
    algebraic_states = Tuple(s for s in states
        if s.physical_type.temporal_type.kind === algebraic_time)
    length(differential_states) == 1 && length(algebraic_states) == 2 ||
        throw(ArgumentError("D2.1 requires exactly one differential and two algebraic states"))
    all(s -> s.physical_type.value_kind === :scalar_field &&
        s.physical_type.tensor_rank == 0 && s.physical_type.spatial_dimension == 0 &&
        s.physical_type.temporal_type.derivative_order == 0, states) ||
        throw(ArgumentError("D2.1 accepts only order-zero lumped scalar states"))
    expected_d = Tuple(s.state_ref for s in differential_states)
    expected_a = Tuple(s.state_ref for s in algebraic_states)
    Tuple(differential_refs) == expected_d && Tuple(algebraic_refs) == expected_a ||
        throw(ArgumentError("caller temporal reclassification or ordering"))

    rows = Tuple(row_bindings)
    length(rows) == 3 || throw(ArgumentError("D2.1 row coverage mismatch"))
    differential_rows = Tuple(r for r in rows if r isa TimeResidualRowBindingV4)
    algebraic_rows = Tuple(r for r in rows if r isa DAEAlgebraicRowBindingV4)
    length(differential_rows) == 1 && length(algebraic_rows) == 2 ||
        throw(ArgumentError("D2.1 row types are incomplete"))
    differential_row = only(differential_rows)
    differential_row.state_ref == only(expected_d) ||
        throw(ArgumentError("D2.1 differential row ownership mismatch"))
    algebraic_rows = Tuple(sort(collect(algebraic_rows), by=r -> r.state_ref.value))
    Tuple(r.state_ref for r in algebraic_rows) == expected_a ||
        throw(ArgumentError("D2.1 algebraic row ownership mismatch"))

    operator_registry = default_operator_registry()
    governing = _tdae_edge(graph, differential_row.governing_edge_hash)
    governing.role === FusionConceptAI.governing ||
        throw(ArgumentError("D2.1 differential governing role mismatch"))
    _tdae_program_check(governing.program; allow_dt=true)
    _tdae_owned_identity(governing, graph, differential_row.state_ref)
    mass_output = _tdae_output_binding(governing, differential_row.mass_root_position)
    mass_type = graph.nodes[mass_output.graph_node_index].physical_type
    mass_type.temporal_type.kind === differential_time &&
        mass_type.temporal_type.derivative_order == 1 ||
        throw(ArgumentError("D2.1 mass root must have derivative order one"))
    mass_ports = _ttr_ports(governing, graph, differential_states)
    mass = _ttr_mass(governing.program, mass_ports, 1,
        differential_row.mass_root_position, operator_registry)

    rhs_edge = _tdae_edge(graph, differential_row.rhs_edge_hash)
    rhs_edge.role === additive || throw(ArgumentError("D2.1 RHS role mismatch"))
    _tdae_program_check(rhs_edge.program; allow_dt=false)
    rhs_output = _tdae_output_binding(rhs_edge, differential_row.rhs_root_position)
    rhs_type = graph.nodes[rhs_output.graph_node_index].physical_type
    rhs_type.temporal_type.derivative_order == 0 &&
        rhs_type.value_kind == mass_type.value_kind &&
        rhs_type.tensor_rank == mass_type.tensor_rank &&
        rhs_type.spatial_dimension == mass_type.spatial_dimension &&
        rhs_type.units == mass_type.units ||
        throw(ArgumentError("D2.1 RHS/mass shape mismatch"))
    rhs_ports = _tdae_port_refs(rhs_edge, graph, Tuple(s.state_ref for s in states))
    _tdae_require_partition_ports(rhs_ports,
        Tuple(s.state_ref for s in differential_states), "RHS")

    genes = Dict(s.state_ref.value => s for s in states)
    algebraic_programs = NamedTuple[]
    for row in algebraic_rows
        state = genes[row.state_ref.value]
        governing_edge = _tdae_edge(graph, row.governing_edge_hash)
        governing_edge.role === FusionConceptAI.governing ||
            throw(ArgumentError("D2.1 algebraic governing role mismatch"))
        _tdae_program_check(governing_edge.program; allow_dt=false)
        _tdae_owned_identity(governing_edge, graph, row.state_ref)

        constraint_edge = _tdae_edge(graph, row.residual_edge_hash)
        constraint_edge.role === constraint ||
            throw(ArgumentError("D2.1 algebraic residual role mismatch"))
        _tdae_program_check(constraint_edge.program; allow_dt=false)
        Tuple(constraint_edge.program.used_manifest_bindings) ==
            row.operator_manifest_bindings ||
            throw(ArgumentError("D2.1 operator manifest binding mismatch"))
        output = _tdae_output_binding(constraint_edge, row.residual_root_position)
        graph.nodes[output.graph_node_index].node_id == row.state_ref.value ||
            throw(ArgumentError("D2.1 constraint root does not own state"))
        length(state.constraint_refs) == 1 &&
            only(state.constraint_refs).value == constraint_edge.edge_id ||
            throw(ArgumentError("D2.1 state constraint ownership mismatch"))
        ports = _tdae_port_refs(constraint_edge, graph,
            Tuple(s.state_ref for s in states))
        _tdae_require_partition_ports(ports,
            Tuple(s.state_ref for s in algebraic_states), "constraint")
        push!(algebraic_programs, (state_ref=row.state_ref,
            edge_hash=canonical_hash(constraint_edge),
            program_hash=constraint_edge.program_hash,
            root_position=row.residual_root_position,
            output_node=output.graph_node_index,
            manifest_bindings=constraint_edge.program.used_manifest_bindings,
            ports=Tuple((port=pair.first, state_ref=pair.second) for pair in
                sort(collect(ports), by=first))))
    end

    differential_scales = Tuple(_tdae_state_scale(s) for s in differential_states)
    algebraic_scales = Tuple(_tdae_state_scale(s) for s in algebraic_states)
    scaling = (basis=:typed_state_bounds_in_declared_base_units,
        differential_state_scales=differential_scales,
        algebraic_row_scales=algebraic_scales,
        algebraic_column_scales=algebraic_scales)
    row_authority = (differential=(binding=differential_row,
        governing_program=governing.program_hash, mass=Tuple(mass),
        mass_output=mass_output.graph_node_index,
        rhs_program=rhs_edge.program_hash,
        rhs_output=rhs_output.graph_node_index,
        rhs_ports=Tuple((port=pair.first, state_ref=pair.second) for pair in
            sort(collect(rhs_ports), by=first))),
        algebraic=Tuple(algebraic_programs), scaling=scaling)
    (states=states, differential_states=differential_states,
     algebraic_states=algebraic_states, differential_row=differential_row,
     algebraic_rows=algebraic_rows, mass=reshape(copy(mass), 1, 1),
     rhs_edge=rhs_edge, rhs_ports=rhs_ports,
     algebraic_programs=Tuple(algebraic_programs),
     differential_state_scales=differential_scales,
     algebraic_row_scales=algebraic_scales,
     algebraic_column_scales=algebraic_scales,
     row_authority=row_authority)
end

function _tdae_schema_hash(compiled, authority, scenario, protocol)
    canonical_hash((schema=_TDAE_SCHEMA, revision=_TDAE_REVISION,
        compiled_prefix=compiled.prefix_hash,
        mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mission_hash=compiled.minimality_scope.mission_hash,
        bounds_hash=compiled.minimality_scope.bounds_hash,
        minimality_scope=compiled.minimality_scope,
        differential_refs=Tuple(s.state_ref for s in authority.differential_states),
        algebraic_refs=Tuple(s.state_ref for s in authority.algebraic_states),
        row_authority=authority.row_authority,
        scenario=scenario.scenario_hash, protocol=canonical_hash(protocol),
        applicability=compiled.minimality_scope.bounds_hash))
end

function _tdae_capability(compiled, authority, scenario, protocol)
    CapabilitySignatureV4(_TDAE_SCHEMA, _TDAE_REVISION, _TDAE_KIND,
        _TDAE_OPERATOR,
        Tuple(s.state_ref.value for s in
            (authority.differential_states..., authority.algebraic_states...)),
        "mixed_lumped_state_guess_0d",
        "consistent_state_and_initial_derivative_0d", 0, (),
        "no_spatial_boundary_in_d2_1", "no_spatial_interface_in_d2_1",
        "initialization_at_single_time",
        ("consistent_state", "initial_derivative", "algebraic_residual",
         "differential_mass_residual", "local_algebraic_jacobian_audit"),
        screen_only, compiled.minimality_scope.bounds_hash;
        input_schema_hash=_tdae_schema_hash(compiled, authority, scenario, protocol),
        coordinate_system="lumped_0d")
end

function _tdae_subject(compiled, authority, scenario, capability)
    payload = (mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        compiled_prefix_hash=compiled.prefix_hash,
        mission_hash=compiled.minimality_scope.mission_hash,
        bounds_hash=compiled.minimality_scope.bounds_hash,
        minimality_scope=compiled.minimality_scope,
        row_authority=authority.row_authority,
        executed_scope="g1_lumped_mixed_state_initialization",
        unexecuted_scopes=("g2_field_geometry", "g3_realization_control",
            "dae_time_trajectory"))
    ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        compiled.candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash,
        (("mixed_state_row_authority", authority.row_authority),),
        ((name=scenario.name, initial_values=scenario.initial_values,
          scenario_hash=scenario.scenario_hash),), payload, (capability,))
end

function _tdae_provider(capability, source_hash)
    ProviderManifestV4(_TDAE_SCHEMA, _TDAE_REVISION, _TDAE_KIND,
        capability, (bounds_hash=capability.applicability_bounds,
            operation=:consistent_initialization,
            executed_scope="g1_lumped_mixed_state_initialization"),
        _TDAE_BACKEND, _TDAE_REVISION, source_hash,
        _TDAE_INDEPENDENCE_GROUP, screen_only;
        input_schema_hash=capability.input_schema_hash, executor=nothing)
end

function _tdae_authority_hash(compiled, authority, subject, scenario,
                              protocol, capability, provider, source_hash)
    canonical_hash((revision=_TDAE_REVISION, compiled_prefix=compiled.prefix_hash,
        mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mission_hash=compiled.minimality_scope.mission_hash,
        bounds_hash=compiled.minimality_scope.bounds_hash,
        minimality_scope=compiled.minimality_scope,
        row_authority=authority.row_authority,
        subject=subject.physical_subject_hash, scenario=scenario.scenario_hash,
        protocol=canonical_hash(protocol), capability=canonical_hash(capability),
        provider=provider.manifest_hash, source_hash=source_hash))
end

function _tdae_solver_input(subject, scenario, protocol, provider,
                            authority_hash, row_authority)
    payload = (revision=_TDAE_REVISION,
        operation=:consistent_initialization,
        execution_authority_hash=authority_hash,
        physical_subject_hash=subject.physical_subject_hash,
        scenario_hash=scenario.scenario_hash,
        initial_values=scenario.initial_values,
        protocol_hash=canonical_hash(protocol), row_authority=row_authority,
        provider_manifest_hash=provider.manifest_hash,
        source_hash=provider.code_hash,
        executed_scope="g1_lumped_mixed_state_initialization",
        unexecuted_scopes=("g2_field_geometry", "g3_realization_control",
            "dae_time_trajectory"))
    SolverInputV4(subject.physical_subject_hash, scenario.scenario_hash,
        provider.manifest_hash, provider.input_schema_hash, payload)
end

function compile_typed_dae_initialization_plan(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4; differential_refs,
        algebraic_refs, row_bindings,
        scenario::ConsistentInitializationScenarioV4,
        protocol=ConsistentInitializationProtocolV4())
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope,
        compiled.minimality_scope.scenario_scope)
    _tdae_scenario_check(scenario)
    canonical_hash(protocol)
    authority = _tdae_compile_authority(compiled, Tuple(differential_refs),
        Tuple(algebraic_refs), Tuple(row_bindings))
    _tdae_validate_scenario(scenario, authority.states)
    source_hash = _tdae_source_hash()
    capability = _tdae_capability(compiled, authority, scenario, protocol)
    subject = _tdae_subject(compiled, authority, scenario, capability)
    provider = _tdae_provider(capability, source_hash)
    authority_hash = _tdae_authority_hash(compiled, authority, subject,
        scenario, protocol, capability, provider, source_hash)
    input = _tdae_solver_input(subject, scenario, protocol, provider,
        authority_hash, authority.row_authority)
    plan_hash = canonical_hash((revision=_TDAE_REVISION,
        authority=authority_hash, solver_input=input.solver_input_hash))
    plan = TypedDAEInitializationPlanV4(_TDAE_TOKEN, compiled, registry,
        Tuple(differential_refs), Tuple(algebraic_refs), Tuple(row_bindings),
        scenario, protocol, capability, subject, input, provider, source_hash,
        authority_hash, plan_hash)
    canonical_hash(plan)
    plan
end

function _tdae_check_plan(plan::TypedDAEInitializationPlanV4)
    _runtime_validate_compiled_prefix(plan.compiled, plan.compiled.candidate,
        plan.registry, plan.compiled.mission_payload, plan.compiled.bounds_payload,
        plan.compiled.minimality_scope.comparison_scope,
        plan.compiled.minimality_scope.scenario_scope)
    _tdae_scenario_check(plan.scenario)
    canonical_hash(plan.protocol)
    authority = _tdae_compile_authority(plan.compiled, plan.differential_refs,
        plan.algebraic_refs, plan.row_bindings)
    _tdae_validate_scenario(plan.scenario, authority.states)
    source_hash = _tdae_source_hash()
    source_hash == plan.source_hash ||
        throw(ArgumentError("D2.1 source authority changed"))
    capability = _tdae_capability(plan.compiled, authority, plan.scenario,
        plan.protocol)
    subject = _tdae_subject(plan.compiled, authority, plan.scenario, capability)
    provider = _tdae_provider(capability, source_hash)
    authority_hash = _tdae_authority_hash(plan.compiled, authority, subject,
        plan.scenario, plan.protocol, capability, provider, source_hash)
    input = _tdae_solver_input(subject, plan.scenario, plan.protocol, provider,
        authority_hash, authority.row_authority)
    canonical_hash(plan.capability) == canonical_hash(capability) &&
        plan.subject.physical_subject_hash == subject.physical_subject_hash &&
        plan.provider.manifest_hash == provider.manifest_hash &&
        plan.provider.executor === nothing &&
        plan.input.solver_input_hash == input.solver_input_hash &&
        plan.authority_hash == authority_hash ||
        throw(ArgumentError("D2.1 plan authority mismatch"))
    expected = canonical_hash((revision=_TDAE_REVISION,
        authority=authority_hash, solver_input=input.solver_input_hash))
    expected == plan.plan_hash || throw(ArgumentError("D2.1 plan tampered"))
    authority
end
canonical_hash(plan::TypedDAEInitializationPlanV4) = (_tdae_check_plan(plan); plan.plan_hash)

function _tdae_values(plan)
    Dict(v.state_ref.value => Float64(v.value) for v in plan.scenario.initial_values)
end

function _tdae_state_bounds(authority)
    Dict(s.state_ref.value => (Float64(s.physical_bounds.interval.lower),
        Float64(s.physical_bounds.interval.upper)) for s in authority.states)
end

function _tdae_residual_function(plan, authority, base_values)
    graph = plan.compiled.mechanism_graph
    programs = Tuple(begin
        edge = _tdae_edge(graph, row.residual_edge_hash)
        ports = _tdae_port_refs(edge, graph,
            Tuple(s.state_ref for s in authority.states))
        (edge=edge, ports=ports, root=row.residual_root_position)
    end for row in authority.algebraic_rows)
    function residual(z)
        values = copy(base_values)
        for (ref, value) in zip(plan.algebraic_refs, z)
            values[ref.value] = Float64(value)
        end
        [_tdae_eval(p.edge.program, p.ports, values, p.root) for p in programs]
    end
    residual
end

function _tdae_jacobian(residual, z, step, bounds, refs,
                        row_scales, column_scales)
    base = residual(z)
    n = length(z)
    J = zeros(length(base), n)
    for column in 1:n
        lower, upper = bounds[refs[column].value]
        requested = step * column_scales[column]
        forward_room = upper - z[column]
        backward_room = z[column] - lower
        usable = eps(Float64) * max(1.0, abs(z[column]), column_scales[column])
        if forward_room >= requested && backward_room >= requested
            forward = copy(z); forward[column] += requested
            backward = copy(z); backward[column] -= requested
            J[:, column] .= (residual(forward) .- residual(backward)) ./
                (2 * requested)
        elseif forward_room > usable
            h = min(requested, forward_room)
            forward = copy(z); forward[column] += h
            J[:, column] .= (residual(forward) .- base) ./ h
        elseif backward_room > usable
            h = min(requested, backward_room)
            backward = copy(z); backward[column] -= h
            J[:, column] .= (base .- residual(backward)) ./ h
        else
            _tdae_fail(:finite_difference_bound_exhausted,
                "state bounds admit no finite-difference perturbation")
        end
    end
    all(isfinite, J) || _tdae_fail(:nonfinite_jacobian, "nonfinite local algebraic Jacobian")
    normalized = J .* reshape(collect(column_scales), 1, :) ./
        reshape(collect(row_scales), :, 1)
    all(isfinite, normalized) ||
        _tdae_fail(:nonfinite_jacobian, "nonfinite scaled algebraic Jacobian")
    (raw=J, normalized=normalized)
end

function _tdae_matrix_condition(matrix, protocol, singular_code,
                                ill_conditioned_code, label)
    size(matrix, 1) == size(matrix, 2) ||
        _tdae_fail(singular_code, "$(label) is not square")
    singular_values = svdvals(matrix)
    isempty(singular_values) && _tdae_fail(singular_code, "$(label) is empty")
    largest = maximum(singular_values)
    threshold = protocol.rank_relative_tol * largest
    all(isfinite, singular_values) && largest > 0 &&
        count(value -> value > threshold, singular_values) == size(matrix, 1) ||
        _tdae_fail(singular_code, "$(label) is singular at the sealed SVD tolerance")
    condition = largest / minimum(singular_values)
    isfinite(condition) && condition <= protocol.max_condition ||
        _tdae_fail(ill_conditioned_code, "$(label) exceeds the sealed condition limit")
    condition
end

function _tdae_success_result(plan, authority)
    values = _tdae_values(plan)
    bounds = _tdae_state_bounds(authority)
    differential_initial = Tuple(values[r.value] for r in plan.differential_refs)
    algebraic_initial = [values[r.value] for r in plan.algebraic_refs]
    residual = _tdae_residual_function(plan, authority, values)
    row_scales = collect(authority.algebraic_row_scales)
    column_scales = collect(authority.algebraic_column_scales)
    normalized_residual(z) = residual(z) ./ row_scales
    initial_residual = normalized_residual(algebraic_initial)
    z = copy(algebraic_initial)
    converged = false
    for _ in 1:plan.protocol.max_iterations
        g = normalized_residual(z)
        tolerance = plan.protocol.residual_abs_tol +
            plan.protocol.residual_rel_tol *
                max(1.0, norm(z ./ column_scales, Inf))
        if norm(g, Inf) <= tolerance
            converged = true
            break
        end
        jacobian = _tdae_jacobian(residual, z,
            plan.protocol.finite_difference_step, bounds, plan.algebraic_refs,
            row_scales, column_scales)
        _tdae_matrix_condition(jacobian.normalized, plan.protocol,
            :singular_algebraic_jacobian, :ill_conditioned_algebraic_jacobian,
            "local scaled algebraic Jacobian")
        delta_scaled = jacobian.normalized \ g
        delta = column_scales .* delta_scaled
        all(isfinite, delta) || _tdae_fail(:nonfinite_newton_step, "nonfinite Newton step")
        norm(delta_scaled, Inf) > plan.protocol.correction_abs_tol ||
            _tdae_fail(:newton_stagnation,
                "Newton correction fell below tolerance before residual convergence")
        accepted = false
        damping = 1.0
        old_norm = norm(g, Inf)
        for _ in 0:plan.protocol.max_backtracks
            trial = z .- damping .* delta
            in_bounds = all(begin
                lower, upper = bounds[ref.value]
                lower <= value <= upper
            end for (ref, value) in zip(plan.algebraic_refs, trial))
            if in_bounds && all(isfinite, trial) &&
                    norm(normalized_residual(trial), Inf) < old_norm
                z = trial
                accepted = true
                post = normalized_residual(z)
                post_tol = plan.protocol.residual_abs_tol +
                    plan.protocol.residual_rel_tol *
                        max(1.0, norm(z ./ column_scales, Inf))
                if norm(post, Inf) <= post_tol
                    converged = true
                end
                break
            end
            damping /= 2
        end
        converged && break
        accepted || _tdae_fail(:newton_line_search_failed,
            "bounded Newton line search failed")
    end
    converged || _tdae_fail(:newton_nonconvergence,
        "consistent initialization did not converge")

    final_residual = normalized_residual(z)
    residual_tolerance = plan.protocol.residual_abs_tol +
        plan.protocol.residual_rel_tol *
            max(1.0, norm(z ./ column_scales, Inf))
    norm(final_residual, Inf) <= residual_tolerance ||
        _tdae_fail(:algebraic_residual_exceeded,
            "final algebraic residual exceeds tolerance")
    jacobian = _tdae_jacobian(residual, z,
        plan.protocol.finite_difference_step, bounds, plan.algebraic_refs,
        row_scales, column_scales)
    jacobian_condition = _tdae_matrix_condition(jacobian.normalized,
        plan.protocol, :singular_algebraic_jacobian,
        :ill_conditioned_algebraic_jacobian,
        "final scaled algebraic Jacobian")

    for (ref, value) in zip(plan.algebraic_refs, z)
        values[ref.value] = value
    end
    M = authority.mass
    differential_scales = collect(authority.differential_state_scales) ./
        plan.protocol.time_scale
    normalized_mass = M .* reshape(differential_scales, 1, :) ./
        reshape(differential_scales, :, 1)
    mass_condition = _tdae_matrix_condition(normalized_mass, plan.protocol,
        :singular_mass_matrix, :ill_conditioned_mass_matrix,
        "scaled differential mass block")
    rhs = _tdae_eval(authority.rhs_edge.program, authority.rhs_ports, values,
        authority.differential_row.rhs_root_position)
    derivative = M \ [rhs]
    all(isfinite, derivative) ||
        _tdae_fail(:nonfinite_initial_derivative, "nonfinite initial derivative")
    mass_residual = (M * derivative .- [rhs]) ./
        differential_scales
    norm(mass_residual, Inf) <= plan.protocol.mass_residual_tol ||
        _tdae_fail(:mass_residual_exceeded,
            "differential mass residual exceeds tolerance")

    final_values = Tuple(StateValueV4(state.state_ref,
        values[state.state_ref.value], state.physical_type.units)
        for state in authority.states)
    unchanged = all(values[ref.value] == initial for (ref, initial) in
        zip(plan.differential_refs, differential_initial))
    unchanged || _tdae_fail(:differential_state_changed,
        "consistent initializer changed a differential initial value")
    correction_norm = norm((z .- algebraic_initial) ./ column_scales)
    fields = (:pass, nothing, nothing, plan.differential_refs,
        plan.algebraic_refs,
        plan.scenario.initial_values, final_values,
        Tuple(initial_residual), Tuple(final_residual), Tuple(derivative),
        Tuple(mass_residual), Float64(correction_norm), unchanged,
        Tuple(Tuple(row) for row in eachrow(normalized_mass)),
        Tuple(Tuple(row) for row in eachrow(jacobian.normalized)), Float64(mass_condition),
        Float64(jacobian_condition))
    draft = TypedDAEInitializationResultV4(_TDAE_TOKEN, fields...,
        digest256_text("draft"))
    TypedDAEInitializationResultV4(_TDAE_TOKEN, fields...,
        canonical_hash(_tdae_result_identity(draft)))
end

function _tdae_failure_result(plan, status, code, reason)
    fields = (status, code, String(reason), plan.differential_refs,
        plan.algebraic_refs,
        plan.scenario.initial_values, nothing, nothing,
        nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
        nothing)
    draft = TypedDAEInitializationResultV4(_TDAE_TOKEN, fields...,
        digest256_text("draft"))
    TypedDAEInitializationResultV4(_TDAE_TOKEN, fields...,
        canonical_hash(_tdae_result_identity(draft)))
end

function _tdae_execute_artifact(plan)
    authority = _tdae_check_plan(plan)
    try
        _tdae_success_result(plan, authority)
    catch err
        err isa InterruptException && rethrow()
        if err isa _TDAENumericalFailure
            return _tdae_failure_result(plan, :numerical_fail, err.code, err.message)
        end
        _tdae_failure_result(plan, :unknown, :backend_exception,
            sprint(showerror, err))
    end
end

function _tdae_status(artifact)
    artifact.status === :pass && return (pass, :pass, nothing, nothing, ())
    artifact.status === :numerical_fail && return (
        numerical_fail, :numerical_fail, artifact.failure_code,
        artifact.failure_reason, ("local_numerical_failure",))
    (unknown, :unknown, artifact.failure_code, artifact.failure_reason,
     ("backend_exception",))
end

function _tdae_evidence(plan, artifact, stage_outcome; provider=plan.provider,
                        reason=nothing)
    artifact_hash = artifact === nothing ? nothing : canonical_hash(artifact)
    if provider === nothing
        status = StatusVectorV4(required, no_match, terminal_deferred,
            high_fidelity_pending, terminal_deferred_stage)
        return RuntimeEvidenceV4(plan.subject.physical_subject_hash,
            plan.scenario.scenario_hash, plan.input.solver_input_hash, nothing,
            (execution_plan_hash=plan.plan_hash,
             operation=:consistent_initialization,
             reason=reason === nothing ? "missing_provider" : String(reason)),
            status, (); claim_ceiling=none)
    end
    status = StatusVectorV4(required, unique_match, resolved,
        low_fidelity_evaluated, stage_outcome)
    metrics = artifact === nothing || artifact.status !== :pass ? () : (
        MetricWithUnit(:algebraic_correction_norm, artifact.correction_norm),
        MetricWithUnit(:algebraic_residual_norm,
            maximum(abs, artifact.final_algebraic_residual)),
        MetricWithUnit(:differential_mass_residual_norm,
            maximum(abs, artifact.differential_mass_residual)),
        MetricWithUnit(:mass_condition, artifact.mass_condition),
        MetricWithUnit(:local_algebraic_jacobian_condition,
            artifact.jacobian_condition))
    RuntimeEvidenceV4(plan.subject.physical_subject_hash,
        plan.scenario.scenario_hash, plan.input.solver_input_hash,
        provider.manifest_hash,
        (execution_plan_hash=plan.plan_hash,
         operation=:consistent_initialization,
         physical_subject_hash=plan.subject.physical_subject_hash,
         scenario_hash=plan.scenario.scenario_hash,
         solver_input_hash=plan.input.solver_input_hash,
         provider_manifest_hash=provider.manifest_hash,
         source_hash=plan.source_hash,
         differential_refs=plan.differential_refs,
         algebraic_refs=plan.algebraic_refs), status, metrics;
        claim_ceiling=screen_only, provider_manifest=provider,
        backend_revision=provider.backend_revision,
        numerical_configuration_hash=canonical_hash(plan.protocol),
        artifact_refs=artifact_hash === nothing ? () : (artifact_hash,))
end

function _tdae_build_report(plan, artifact, execution_count;
                            provider=plan.provider, forced_reason=nothing)
    stage, numerical_status, failure_code, failure_reason, gaps =
        artifact === nothing ?
        (terminal_deferred_stage, :terminal_deferred, :missing_provider,
         forced_reason === nothing ? "provider unavailable" : String(forced_reason),
         ("missing_provider",)) : _tdae_status(artifact)
    evidence = _tdae_evidence(plan, artifact, stage;
        provider=provider, reason=failure_reason)
    artifact_hash = artifact === nothing ? nothing : canonical_hash(artifact)
    invocation_hash = canonical_hash((revision=_TDAE_REVISION,
        solver_input=plan.input.solver_input_hash,
        provider=provider === nothing ? nothing : provider.manifest_hash,
        execution_plan=plan.plan_hash, artifact=artifact_hash))
    receipt_fields = (invocation_hash, plan.input.solver_input_hash,
        provider === nothing ? nothing : provider.manifest_hash,
        plan.plan_hash, plan.subject.physical_subject_hash,
        plan.scenario.scenario_hash, numerical_status, failure_code,
        failure_reason, artifact_hash, evidence.evidence_id, execution_count)
    receipt_draft = TypedDAEInitializationReceiptV4(_TDAE_TOKEN,
        receipt_fields..., digest256_text("draft"))
    receipt = TypedDAEInitializationReceiptV4(_TDAE_TOKEN,
        receipt_fields..., canonical_hash(_tdae_receipt_identity(receipt_draft)))
    report_fields = (artifact, evidence, receipt, numerical_status, gaps,
        "g1_lumped_mixed_state_initialization",
        ("g2_field_geometry", "g3_realization_control", "dae_time_trajectory"),
        screen_only, 0, false, false, nothing)
    report_draft = TypedDAEInitializationReportV4(_TDAE_TOKEN,
        report_fields..., digest256_text("draft"))
    TypedDAEInitializationReportV4(_TDAE_TOKEN, report_fields...,
        canonical_hash(_tdae_report_identity(report_draft)))
end

function validate_typed_dae_initialization_report(
        plan::TypedDAEInitializationPlanV4,
        report::TypedDAEInitializationReportV4)
    canonical_hash(plan)
    canonical_hash(report)
    receipt = report.receipt
    receipt.solver_input_hash == plan.input.solver_input_hash &&
        receipt.plan_hash == plan.plan_hash &&
        receipt.physical_subject_hash == plan.subject.physical_subject_hash &&
        receipt.scenario_hash == plan.scenario.scenario_hash ||
        throw(ArgumentError("D2.1 receipt authority mismatch"))
    expected_count = receipt.provider_manifest_hash === nothing ? 0 : 1
    receipt.execution_count == expected_count ||
        throw(ArgumentError("D2.1 execute-once count tampered"))
    expected_artifact = report.artifact === nothing ? nothing : canonical_hash(report.artifact)
    receipt.artifact_hash == expected_artifact ||
        throw(ArgumentError("D2.1 artifact ownership mismatch"))
    if receipt.provider_manifest_hash === nothing
        report.artifact === nothing && report.numerical_status === :terminal_deferred ||
            throw(ArgumentError("D2.1 deferred report shape mismatch"))
        provider = nothing
    else
        receipt.provider_manifest_hash == plan.provider.manifest_hash ||
            throw(ArgumentError("D2.1 receipt provider mismatch"))
        report.artifact !== nothing || throw(ArgumentError("D2.1 provider report lacks artifact"))
        fresh = _tdae_execute_artifact(plan)
        canonical_hash(fresh) == canonical_hash(report.artifact) ||
            throw(ArgumentError("D2.1 artifact was not derived from plan"))
        report.numerical_status == report.artifact.status ||
            throw(ArgumentError("D2.1 artifact/report status mismatch"))
        provider = plan.provider
    end
    rebuilt = _tdae_build_report(plan, report.artifact,
        receipt.execution_count; provider=provider)
    rebuilt.receipt.receipt_hash == receipt.receipt_hash &&
        rebuilt.evidence.evidence_id == report.evidence.evidence_id &&
        rebuilt.report_hash == report.report_hash ||
        throw(ArgumentError("D2.1 report was not derived from invocation"))
    true
end

function _tdae_validate_store_artifacts(store, key, report)
    artifact_hash = report.receipt.artifact_hash
    artifact_hash === nothing &&
        throw(ArgumentError("D2.1 cached provider report lacks artifact hash"))
    expected_key = (key, artifact_hash)
    matching_keys = Tuple(k for k in keys(store.artifacts) if k[1] == key)
    length(matching_keys) == 1 && only(matching_keys) == expected_key ||
        throw(ArgumentError("D2.1 cache contains foreign or duplicate artifact authority"))
    canonical_hash(store.artifacts[expected_key]) == canonical_hash(report.artifact) ||
        throw(ArgumentError("D2.1 cached artifact ownership mismatch"))
    true
end

function execute_once!(store::TypedDAEInitializationStoreV4,
                       input::SolverInputV4, provider::ProviderManifestV4,
                       plan::TypedDAEInitializationPlanV4)
    canonical_hash(plan)
    input.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("D2.1 execution input authority mismatch"))
    provider.manifest_hash == plan.provider.manifest_hash &&
        provider.code_hash == plan.source_hash && provider.executor === nothing ||
        throw(ArgumentError("D2.1 execution provider authority mismatch"))
    key = input.solver_input_hash
    if haskey(store.reports, key)
        report = store.reports[key]
        validate_typed_dae_initialization_report(plan, report)
        get(store.execution_counts, key, 0) == 1 ||
            throw(ArgumentError("D2.1 cached execution count incomplete"))
        _tdae_validate_store_artifacts(store, key, report)
        return report
    end
    get(store.execution_counts, key, 0) == 0 ||
        throw(ArgumentError("partial D2.1 state: count without report"))
    any(k -> k[1] == key, keys(store.artifacts)) &&
        throw(ArgumentError("partial D2.1 state: artifact without report"))
    artifact = _tdae_execute_artifact(plan)
    report = _tdae_build_report(plan, artifact, 1)
    validate_typed_dae_initialization_report(plan, report)
    artifact_hash = canonical_hash(artifact)
    store.artifacts[(key, artifact_hash)] = artifact
    store.reports[key] = report
    store.execution_counts[key] = 1
    report
end

function execute_once!(store::TypedDAEInitializationStoreV4,
                       input::SolverInputV4, ::Nothing,
                       plan::TypedDAEInitializationPlanV4)
    canonical_hash(plan)
    input.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("D2.1 execution input authority mismatch"))
    _tdae_build_report(plan, nothing, 0; provider=nothing,
        forced_reason="provider unavailable")
end

function cache_typed_dae_initialization(store::TypedDAEInitializationStoreV4,
                                        plan::TypedDAEInitializationPlanV4)
    canonical_hash(plan)
    key = plan.input.solver_input_hash
    haskey(store.reports, key) || throw(KeyError(key))
    report = store.reports[key]
    validate_typed_dae_initialization_report(plan, report)
    get(store.execution_counts, key, 0) == 1 ||
        throw(ArgumentError("D2.1 cached execution count incomplete"))
    _tdae_validate_store_artifacts(store, key, report)
    report
end

function replay_typed_dae_initialization(plan::TypedDAEInitializationPlanV4,
                                         report::TypedDAEInitializationReportV4)
    validate_typed_dae_initialization_report(plan, report)
    report.artifact === nothing &&
        return report.numerical_status === :terminal_deferred
    fresh = _tdae_execute_artifact(plan)
    canonical_hash(fresh) == canonical_hash(report.artifact) ||
        throw(ArgumentError("D2.1 replay artifact mismatch"))
    rebuilt = _tdae_build_report(plan, fresh, report.receipt.execution_count)
    canonical_hash(rebuilt) == canonical_hash(report) ||
        throw(ArgumentError("D2.1 replay report mismatch"))
    true
end

typed_dae_initialization_manifest() = (schema=_TDAE_SCHEMA,
    revision=_TDAE_REVISION, kind=_TDAE_KIND,
    operation=_TDAE_OPERATOR, claim_ceiling=screen_only,
    credible_physical_candidate_count=0, p5_ready=false,
    unsupported_emitted=false, trajectory=nothing)
