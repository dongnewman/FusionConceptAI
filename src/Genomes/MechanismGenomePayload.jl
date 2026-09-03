"""Closed G1 mechanism payload bound to a typed operator hypergraph."""

const _G1_PAYLOAD_MAX_STATES = 8
const _G1_PAYLOAD_MAX_AST_NODES = 32

function _g1_payload_tuple(value::Any, T::Type, field::String)
    value isa Tuple || throw(ArgumentError("$field must be an immutable tuple"))
    all(item -> typeof(item) === T, value) || throw(ArgumentError("$field contains an invalid typed value"))
    value
end

function _g1_payload_edge_id(edge::Any)
    if typeof(edge) === AtomicMIMOHyperedgeV1 || typeof(edge) === TypedHyperedge
        id = edge.edge_id
        !isempty(id) && isvalid(id) || throw(ArgumentError("graph edge ids must be non-empty valid UTF-8"))
        return id
    end
    throw(ArgumentError("operator graph contains an unsupported edge type"))
end

function _g1_payload_edge_role(edge::Any)
    typeof(edge) === AtomicMIMOHyperedgeV1 && return edge.role
    typeof(edge) === TypedHyperedge && return edge.role === :governing ? governing :
        edge.role === :additive ? additive : edge.role === :constraint ? constraint :
        edge.role === :interface ? interface : throw(ArgumentError("legacy edge role is not representable"))
    throw(ArgumentError("operator graph contains an unsupported edge type"))
end

function _g1_payload_edge_program(edge::Any)
    typeof(edge) === AtomicMIMOHyperedgeV1 && return edge.program
    typeof(edge) === TypedHyperedge && return nothing
    throw(ArgumentError("operator graph contains an unsupported edge type"))
end

function _g1_payload_edge_outputs(edge::Any)
    if typeof(edge) === AtomicMIMOHyperedgeV1
        return Tuple(binding.graph_node_index for binding in edge.output_bindings)
    elseif typeof(edge) === TypedHyperedge
        return edge.outputs
    end
    throw(ArgumentError("operator graph contains an unsupported edge type"))
end

function _g1_payload_edge_inputs(edge::Any)
    if typeof(edge) === AtomicMIMOHyperedgeV1
        return Tuple(binding.graph_node_index for binding in edge.input_bindings)
    elseif typeof(edge) === TypedHyperedge
        return edge.inputs
    end
    throw(ArgumentError("operator graph contains an unsupported edge type"))
end

function _g1_payload_registry(graph::TypedOperatorHypergraphV1)
    isempty(graph.hyperedges) && throw(ArgumentError("strong mechanism payload requires atomic graph edges"))
    all(typeof(edge) === AtomicMIMOHyperedgeV1 for edge in graph.hyperedges) ||
        throw(ArgumentError("strong mechanism payload requires only atomic MIMO edges; legacy migration is a 4.6 boundary"))
    first_registry = first(graph.hyperedges).registry
    first_key = Tuple(sort(collect((manifest.operator_ref.qualified.id,
        manifest.operator_ref.qualified.version, manifest.manifest_hash.value)
        for manifest in first_registry.operators), by=x -> (x[1], x[2], x[3])))
    for edge in graph.hyperedges
        registry_key = Tuple(sort(collect((manifest.operator_ref.qualified.id,
            manifest.operator_ref.qualified.version, manifest.manifest_hash.value)
            for manifest in edge.registry.operators), by=x -> (x[1], x[2], x[3])))
        registry_key == first_key || throw(ArgumentError("all atomic graph edges must use one exact operator registry"))
    end
    first_registry
end

function _g1_payload_validate_registry(graph::TypedOperatorHypergraphV1, observables::Tuple,
                                       registry::OperatorRegistryV1)
    for edge in graph.hyperedges
        typeof(edge) === AtomicMIMOHyperedgeV1 || throw(ArgumentError("legacy edge cannot enter a strong payload"))
        for (ref, manifest_hash) in edge.program.used_manifest_bindings
            invoke(_mimo_exact_manifest, Tuple{OperatorRegistryV1,OperatorRefV1,Digest256},
                registry, ref, manifest_hash)
        end
    end
    for observable in observables
        for (ref, manifest_hash) in observable.sampling_program.used_manifest_bindings
            invoke(_mimo_exact_manifest, Tuple{OperatorRegistryV1,OperatorRefV1,Digest256},
                registry, ref, manifest_hash)
        end
    end
    nothing
end

function _g1_payload_find_edge(graph::TypedOperatorHypergraphV1, id::String, field::String)
    found = nothing
    for edge in graph.hyperedges
        if invoke(_g1_payload_edge_id, Tuple{Any}, edge) == id
            found === nothing || throw(ArgumentError("graph edge ids must be unique"))
            found = edge
        end
    end
    found === nothing && throw(ArgumentError("$field does not bind a graph edge"))
    found
end

function _g1_payload_assert_edge_ref(graph::TypedOperatorHypergraphV1, ref::Any, roles, field::String)
    id = if ref isa OperatorSiteRefV1
        ref.value
    elseif ref isa ConstraintRefV1
        ref.value
    else
        throw(ArgumentError("$field contains an invalid graph reference"))
    end
    edge = invoke(_g1_payload_find_edge, Tuple{TypedOperatorHypergraphV1,String,String}, graph, id, field)
    invoke(_g1_payload_edge_role, Tuple{Any}, edge) in roles || throw(ArgumentError("$field binds an edge with the wrong role"))
    edge
end

function _g1_payload_root_type(graph::TypedOperatorHypergraphV1, ref::ProgramRootRefV1)
    edge = invoke(_g1_payload_find_edge, Tuple{TypedOperatorHypergraphV1,String,String}, graph,
        ref.operator_site_ref.value, "expression_root")
    if typeof(edge) === AtomicMIMOHyperedgeV1
        position = ref.root_position
        position <= length(edge.program.roots) || throw(ArgumentError("program root position is out of range"))
        root_index = edge.program.roots[position]
        output_binding = only(Tuple(binding for binding in edge.output_bindings if binding.program_position == position))
        graph_index = output_binding.graph_node_index
        graph_index <= length(graph.nodes) || throw(ArgumentError("graph output index is out of range"))
        edge.program.nodes[root_index].output_type == ref.declared_type ||
            throw(ArgumentError("declared root type differs from AST root type"))
        graph.nodes[graph_index].physical_type == ref.declared_type ||
            throw(ArgumentError("declared root type differs from graph output type"))
    elseif typeof(edge) === TypedHyperedge
        ref.root_position == 1 || throw(ArgumentError("legacy hyperedge has one root only"))
        graph_index = only(edge.outputs)
        graph_index <= length(graph.nodes) || throw(ArgumentError("graph output index is out of range"))
        edge.ast.nodes[edge.ast.root].output_type == ref.declared_type ||
            throw(ArgumentError("declared root type differs from AST root type"))
        graph.nodes[graph_index].physical_type == ref.declared_type ||
            throw(ArgumentError("declared root type differs from graph output type"))
    else
        throw(ArgumentError("unsupported expression-root edge"))
    end
    ref.declared_type
end

function _g1_payload_program_metrics(program::TypedASTProgramV1, registry::OperatorRegistryV1)
    depth = zeros(Int, length(program.nodes))
    derivative = zeros(Int, length(program.nodes))
    nonlocal = zeros(Int, length(program.nodes))
    memory = zeros(Int, length(program.nodes))
    events = zeros(Int, length(program.nodes))
    for (index, node_value) in enumerate(program.nodes)
        if typeof(node_value) === ASTApplyV1
            manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}},
                registry, node_value.operator_ref.qualified.id, node_value.operator_ref.qualified.version)
            children = Tuple(node_value.inputs)
            all(1 <= child < index for child in children) ||
                throw(ArgumentError("AST dependency is not a topologically ordered DAG"))
            depth[index] = isempty(children) ? 1 : 1 + maximum(depth[child] for child in children)
            derivative[index] = (isempty(children) ? 0 : maximum(derivative[child] for child in children)) +
                Int(manifest.max_derivative_contribution)
            nonlocal[index] = (isempty(children) ? 0 : maximum(nonlocal[child] for child in children)) +
                (manifest.locality == :local ? 0 : 1)
            memory[index] = (isempty(children) ? 0 : maximum(memory[child] for child in children)) +
                (manifest.stateful ? 1 : 0)
            events[index] = (isempty(children) ? 0 : maximum(events[child] for child in children)) +
                (manifest.event ? 1 : 0)
        else
            depth[index] = 1
        end
    end
    maximum(depth), maximum(derivative), maximum(nonlocal), maximum(memory), maximum(events)
end

function _g1_payload_validate_program(program::TypedASTProgramV1, registry::OperatorRegistryV1)
    invoke(_g1_payload_program_metrics, Tuple{TypedASTProgramV1,OperatorRegistryV1}, program, registry)
end

function _g1_payload_parameter_nodes(program::TypedASTProgramV1)
    Tuple(node_value for node_value in program.nodes if typeof(node_value) === ASTParameterV1)
end

function _g1_payload_all_programs(graph::TypedOperatorHypergraphV1, observables::Tuple)
    programs = TypedASTProgramV1[]
    for edge in graph.hyperedges
        program = invoke(_g1_payload_edge_program, Tuple{Any}, edge)
        program === nothing || push!(programs, program)
    end
    append!(programs, TypedASTProgramV1[value.sampling_program for value in observables])
    programs
end

function _g1_payload_validate_parameters(parameters::Tuple, programs::Vector{TypedASTProgramV1})
    genes = Dict{String,ParameterGeneV1}()
    for gene in parameters
        haskey(genes, gene.ref.value) && throw(ArgumentError("parameter references must be unique"))
        genes[gene.ref.value] = gene
    end
    consumed = Dict{String,Bool}(key => false for key in keys(genes))
    for program in programs
        for node_value in invoke(_g1_payload_parameter_nodes, Tuple{TypedASTProgramV1}, program)
            name = String(node_value.name)
            haskey(genes, name) || throw(ArgumentError("AST parameter has no matching ParameterGene"))
            gene = genes[name]
            expected_type = PhysicalType(:scalar_parameter, 0, 0,
                TemporalTypeV1(static_time), gene.unit)
            node_value.output_type == expected_type ||
                throw(ArgumentError("AST parameter type must be the exact scalar static parameter type"))
            consumed[name] = true
        end
    end
    all(values(consumed)) || throw(ArgumentError("every ParameterGene must have an AST consumer"))
    nothing
end

function _g1_payload_validate_governing(graph::TypedOperatorHypergraphV1)
    for (index, node_value) in enumerate(graph.nodes)
        node_value.node_kind === :state || continue
        kind = node_value.physical_type.temporal_type.kind
        kind in (differential_time, algebraic_time) || continue
        governing_outputs = Int[]
        constraint_outputs = Int[]
        for edge in graph.hyperedges
            outputs = invoke(_g1_payload_edge_outputs, Tuple{Any}, edge)
            role = invoke(_g1_payload_edge_role, Tuple{Any}, edge)
            index in outputs && role == governing && push!(governing_outputs, index)
            index in outputs && role == constraint && push!(constraint_outputs, index)
        end
        length(governing_outputs) == 1 || throw(ArgumentError("each differential/algebraic state needs exactly one governing residual"))
        kind == algebraic_time && length(constraint_outputs) == 1 ||
            kind != algebraic_time || throw(ArgumentError("each algebraic state needs exactly one constraint"))
    end
end

function _g1_payload_validate_refs(states, invariants, graph, parameters, symmetries, observables, holes)
    node_ids = String[node.node_id for node in graph.nodes]
    isempty(node_ids) || all(!isempty(id) && isvalid(id) for id in node_ids) || throw(ArgumentError("graph node ids must be non-empty valid UTF-8"))
    length(unique(node_ids)) == length(node_ids) || throw(ArgumentError("graph node ids must be unique"))
    state_nodes = Tuple((index, node) for (index, node) in enumerate(graph.nodes) if node.node_kind === :state)
    length(state_nodes) == length(states) || throw(ArgumentError("each graph state node needs exactly one StateGene"))
    state_map = Dict(gene.state_ref.value => gene for gene in states)
    length(state_map) == length(states) || throw(ArgumentError("state references must be unique"))
    for (_, node_value) in state_nodes
        haskey(state_map, node_value.node_id) || throw(ArgumentError("graph state node has no matching StateGene"))
        state_map[node_value.node_id].physical_type == node_value.physical_type ||
            throw(ArgumentError("StateGene physical type differs from graph state node"))
    end
    edge_ids = String[invoke(_g1_payload_edge_id, Tuple{Any}, edge) for edge in graph.hyperedges]
    length(unique(edge_ids)) == length(edge_ids) || throw(ArgumentError("graph edge ids must be unique"))
    edge_id_set = Set(edge_ids)
    account_ids = Set{String}()
    for edge in graph.hyperedges
        typeof(edge) === AtomicMIMOHyperedgeV1 || throw(ArgumentError("legacy edge cannot enter a strong payload"))
        for effect in edge.account_effects
            push!(account_ids, effect.account_ref.account)
        end
    end
    symmetry_ids = String[symmetry.ref.value for symmetry in symmetries]
    length(unique(symmetry_ids)) == length(symmetry_ids) || throw(ArgumentError("symmetry references must be unique"))
    symmetry_map = Dict(symmetry.ref.value => symmetry for symmetry in symmetries)
    for gene in states
        for gauge_ref in gene.gauge_refs
            haskey(symmetry_map, gauge_ref.value) || throw(ArgumentError("StateGene gauge reference does not bind a SymmetryGene"))
        end
        for ref in gene.constraint_refs
            edge = invoke(_g1_payload_assert_edge_ref, Tuple{TypedOperatorHypergraphV1,Any,Any,String},
                graph, ref, (constraint,), "state constraint reference")
            state_index = only(Tuple(index for (index, node_value) in enumerate(graph.nodes)
                if node_value.node_kind === :state && node_value.node_id == gene.state_ref.value))
            state_index in invoke(_g1_payload_edge_outputs, Tuple{Any}, edge) ||
                throw(ArgumentError("state constraint reference is not structurally tied to its state"))
        end
    end
    for (state_index, node_value) in state_nodes
        node_value.physical_type.temporal_type.kind == algebraic_time || continue
        constraint_outputs = Tuple(invoke(_g1_payload_edge_id, Tuple{Any}, edge) for edge in graph.hyperedges
            if invoke(_g1_payload_edge_role, Tuple{Any}, edge) == constraint &&
                state_index in invoke(_g1_payload_edge_outputs, Tuple{Any}, edge))
        length(constraint_outputs) == 1 || throw(ArgumentError("algebraic state constraint ownership is not unique"))
        gene = state_map[node_value.node_id]
        length(gene.constraint_refs) == 1 && gene.constraint_refs[1].value == constraint_outputs[1] ||
            throw(ArgumentError("algebraic state must own its unique constraint output row"))
    end
    invariant_ids = String[invariant.invariant_ref.value for invariant in invariants]
    length(unique(invariant_ids)) == length(invariants) || throw(ArgumentError("invariant references must be unique"))
    for invariant in invariants
        invariant.account_kind_ref.id in account_ids ||
            throw(ArgumentError("invariant account_kind_ref does not bind a graph conservation ledger"))
        if invariant.scope !== scope_global
            invariant.scope_ref === nothing || invariant.scope_ref.id in union(node_ids, edge_id_set) ||
                throw(ArgumentError("invariant scope_ref does not bind a graph/incidence identity"))
        end
        all(haskey(state_map, term.state_ref.value) for term in invariant.terms) ||
            throw(ArgumentError("invariant term references an unknown state"))
        for ref in invariant.allowed_source_refs
            invoke(_g1_payload_assert_edge_ref, Tuple{TypedOperatorHypergraphV1,Any,Any,String},
                graph, ref, (source,), "invariant source reference")
        end
        for ref in invariant.allowed_sink_refs
            invoke(_g1_payload_assert_edge_ref, Tuple{TypedOperatorHypergraphV1,Any,Any,String},
                graph, ref, (sink,), "invariant sink reference")
        end
        for ref in invariant.boundary_flux_refs
            invoke(_g1_payload_assert_edge_ref, Tuple{TypedOperatorHypergraphV1,Any,Any,String},
                graph, ref, (boundary, interface), "invariant boundary reference")
        end
    end
    for symmetry in symmetries
        isempty(symmetry.state_actions) && throw(ArgumentError("symmetry must have at least one state action"))
        all(haskey(state_map, action.state_ref.value) for action in symmetry.state_actions) ||
            throw(ArgumentError("symmetry action references an unknown state"))
    end
    observable_ids = String[observable.observable_ref.value for observable in observables]
    length(unique(observable_ids)) == length(observables) || throw(ArgumentError("observable references must be unique"))
    observable_map = Set(observable_ids)
    for observable in observables
        invoke(_g1_payload_root_type, Tuple{TypedOperatorHypergraphV1,ProgramRootRefV1}, graph, observable.expression_root)
        all(invoke(_g1_payload_root_type, Tuple{TypedOperatorHypergraphV1,ProgramRootRefV1}, graph,
            observable.expression_root) == observable.expression_root.declared_type for _ in (1,)) ||
            throw(ArgumentError("observable expression root is not bound to the graph"))
    end
    hole_ids = String[hole.hole_ref.value for hole in holes]
    length(unique(hole_ids)) == length(holes) || throw(ArgumentError("hole references must be unique"))
    for hole in holes
        all(haskey(state_map, ref.value) for ref in hole.ordered_input_state_refs) ||
            throw(ArgumentError("operator hole references an unknown state"))
        all(ref.value in observable_map for ref in hole.observable_refs) ||
            throw(ArgumentError("operator hole references an unknown observable"))
    end
    nothing
end

function _g1_payload_validate_limits(states, invariants, graph, parameters, symmetries, observables, holes,
                                     registry::OperatorRegistryV1)
    2 <= length(states) <= _G1_PAYLOAD_MAX_STATES || throw(ArgumentError("state count is outside v1 bounds"))
    1 <= length(invariants) <= 6 || throw(ArgumentError("invariant count is outside v1 bounds"))
    0 <= length(parameters) <= 16 || throw(ArgumentError("parameter count is outside v1 bounds"))
    1 <= length(observables) <= 8 || throw(ArgumentError("observable count is outside v1 bounds"))
    0 <= length(holes) <= 1 || throw(ArgumentError("operator-hole count is outside v1 bounds"))
    additive_count = count(edge -> invoke(_g1_payload_edge_role, Tuple{Any}, edge) == additive, graph.hyperedges)
    event_count = count(edge -> invoke(_g1_payload_edge_role, Tuple{Any}, edge) == event, graph.hyperedges)
    event_count <= 2 || throw(ArgumentError("event edge count is outside v1 bound"))
    additive_count <= 16 || throw(ArgumentError("additive edge count is outside v1 bounds"))
    programs = invoke(_g1_payload_all_programs, Tuple{TypedOperatorHypergraphV1,Tuple}, graph, observables)
    ast_nodes = sum(length(program.nodes) for program in programs)
    4 <= ast_nodes <= _G1_PAYLOAD_MAX_AST_NODES || throw(ArgumentError("total AST node count is outside v1 bounds"))
    metrics = [invoke(_g1_payload_validate_program, Tuple{TypedASTProgramV1,OperatorRegistryV1}, program, registry) for program in programs]
    isempty(metrics) || begin
        maximum(first(metric) for metric in metrics) <= 6 || throw(ArgumentError("AST depth exceeds v1 bound"))
        maximum(metric[2] for metric in metrics) <= 2 || throw(ArgumentError("derivative order exceeds v1 bound"))
        maximum(metric[3] for metric in metrics) <= 1 || throw(ArgumentError("nonlocal contribution exceeds v1 bound"))
        maximum(metric[4] for metric in metrics) <= 1 || throw(ArgumentError("memory length exceeds v1 bound"))
        maximum(metric[5] for metric in metrics) <= 2 || throw(ArgumentError("event contribution exceeds v1 bound"))
    end
end

struct MechanismGenomePayloadV1
    states::Tuple{Vararg{StateGeneV1}}
    invariants::Tuple{Vararg{InvariantV1}}
    operator_graph::TypedOperatorHypergraphV1
    parameters::Tuple{Vararg{ParameterGeneV1}}
    symmetries::Tuple{Vararg{SymmetryGeneV1}}
    observables::Tuple{Vararg{ObservableGeneV1}}
    operator_holes::Tuple{Vararg{TypedOperatorHoleV1}}
    function MechanismGenomePayloadV1(states, invariants, operator_graph, parameters, symmetries, observables, operator_holes)
        operator_graph isa TypedOperatorHypergraphV1 || throw(ArgumentError("operator_graph must be TypedOperatorHypergraphV1"))
        all(typeof(edge) === AtomicMIMOHyperedgeV1 for edge in operator_graph.hyperedges) ||
            throw(ArgumentError("strong mechanism payload admits only AtomicMIMOHyperedgeV1 edges"))
        state_tuple = invoke(_g1_payload_tuple, Tuple{Any,Type,String}, states, StateGeneV1, "states")
        invariant_tuple = invoke(_g1_payload_tuple, Tuple{Any,Type,String}, invariants, InvariantV1, "invariants")
        parameter_tuple = invoke(_g1_payload_tuple, Tuple{Any,Type,String}, parameters, ParameterGeneV1, "parameters")
        symmetry_tuple = invoke(_g1_payload_tuple, Tuple{Any,Type,String}, symmetries, SymmetryGeneV1, "symmetries")
        observable_tuple = invoke(_g1_payload_tuple, Tuple{Any,Type,String}, observables, ObservableGeneV1, "observables")
        hole_tuple = invoke(_g1_payload_tuple, Tuple{Any,Type,String}, operator_holes, TypedOperatorHoleV1, "operator_holes")
        registry = invoke(_g1_payload_registry, Tuple{TypedOperatorHypergraphV1}, operator_graph)
        invoke(_g1_payload_validate_registry, Tuple{TypedOperatorHypergraphV1,Tuple,OperatorRegistryV1},
            operator_graph, observable_tuple, registry)
        invoke(_g1_payload_validate_limits, Tuple{Tuple,Tuple,TypedOperatorHypergraphV1,Tuple,Tuple,Tuple,Tuple,OperatorRegistryV1},
            state_tuple, invariant_tuple, operator_graph, parameter_tuple, symmetry_tuple, observable_tuple, hole_tuple, registry)
        invoke(_g1_payload_validate_refs, Tuple{Tuple,Tuple,TypedOperatorHypergraphV1,Tuple,Tuple,Tuple,Tuple},
            state_tuple, invariant_tuple, operator_graph, parameter_tuple, symmetry_tuple, observable_tuple, hole_tuple)
        invoke(_g1_payload_validate_governing, Tuple{TypedOperatorHypergraphV1}, operator_graph)
        programs = invoke(_g1_payload_all_programs, Tuple{TypedOperatorHypergraphV1,Tuple}, operator_graph, observable_tuple)
        invoke(_g1_payload_validate_parameters, Tuple{Tuple,Vector{TypedASTProgramV1}}, parameter_tuple, programs)
        new(state_tuple, invariant_tuple, operator_graph, parameter_tuple, symmetry_tuple, observable_tuple, hole_tuple)
    end
end

function _g1_payload_hash_text(value)
    value isa StateGeneV1 && return String(invoke(canonical_hash, Tuple{StateGeneV1}, value).value)
    value isa InvariantV1 && return String(invoke(canonical_hash, Tuple{InvariantV1}, value).value)
    value isa ParameterGeneV1 && return String(invoke(canonical_hash, Tuple{ParameterGeneV1}, value).value)
    value isa SymmetryGeneV1 && return String(invoke(canonical_hash, Tuple{SymmetryGeneV1}, value).value)
    value isa ObservableGeneV1 && return getfield(invoke(_g1_observable_canonical_hash, Tuple{ObservableGeneV1}, value), :value)
    value isa TypedOperatorHoleV1 && return String(invoke(canonical_hash, Tuple{TypedOperatorHoleV1}, value).value)
    throw(ArgumentError("unsupported payload component"))
end

function _g1_payload_hash_list(values::Tuple)
    "[" * join((invoke(_g1_quote, Tuple{String}, invoke(_g1_payload_hash_text, Tuple{Any}, value)) for value in values), ",") * "]"
end

function _g1_payload_wire(value::MechanismGenomePayloadV1)
    graph_hash = invoke(canonical_hash, Tuple{TypedOperatorHypergraphV1,CanonicalizationProfileV1},
        value.operator_graph, default_canonicalization_profile())
    payload = "{\"invariants\":" * invoke(_g1_payload_hash_list, Tuple{Tuple}, value.invariants) *
        ",\"observables\":" * invoke(_g1_payload_hash_list, Tuple{Tuple}, value.observables) *
        ",\"operator_graph_hash\":" * invoke(_g1_quote, Tuple{String}, String(graph_hash.value)) *
        ",\"operator_holes\":" * invoke(_g1_payload_hash_list, Tuple{Tuple}, value.operator_holes) *
        ",\"parameters\":" * invoke(_g1_payload_hash_list, Tuple{Tuple}, value.parameters) *
        ",\"states\":" * invoke(_g1_payload_hash_list, Tuple{Tuple}, value.states) *
        ",\"symmetries\":" * invoke(_g1_payload_hash_list, Tuple{Tuple}, value.symmetries) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "mechanism_genome_payload", payload)
end

canonical_json(value::MechanismGenomePayloadV1) = invoke(_g1_payload_wire, Tuple{MechanismGenomePayloadV1}, value)
canonical_hash(value::MechanismGenomePayloadV1) = invoke(_g1_hash_bytes, Tuple{String}, invoke(_g1_payload_wire, Tuple{MechanismGenomePayloadV1}, value))
semantic_view(value::MechanismGenomePayloadV1) = (states=value.states, invariants=value.invariants,
    operator_graph=value.operator_graph, parameters=value.parameters, symmetries=value.symmetries,
    observables=value.observables, operator_holes=value.operator_holes)
