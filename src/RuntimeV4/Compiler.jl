"""Compilation of the three existing Genome objects into runtime obligations."""

function _runtime_decl_hash(x)
    is_canonical_value(x) || throw(ArgumentError("mission/bounds payload must be immutable and canonicalizable"))
    canonical_hash(x)
end

function _runtime_graph_node_descriptor(n::TypedNode)
    t = n.physical_type
    (kind=n.node_kind, value_kind=t.value_kind, tensor_rank=t.tensor_rank,
     spatial_dimension=t.spatial_dimension, temporal_kind=t.temporal_type.kind,
     derivative_order=t.temporal_type.derivative_order, units=t.units)
end

function _runtime_program(edge)
    if edge isa TypedHyperedge
        return TypedASTProgramV1(edge.ast)
    elseif edge isa AtomicMIMOHyperedgeV1
        return edge.program
    end
    nothing
end

function _runtime_edge_ports(edge)
    if edge isa TypedHyperedge
        return edge.inputs, edge.outputs, Symbol(edge.role)
    elseif edge isa AtomicMIMOHyperedgeV1
        return Tuple(b.graph_node_index for b in edge.input_bindings),
               Tuple(b.graph_node_index for b in edge.output_bindings), Symbol(edge.role)
    end
    throw(ArgumentError("unsupported hyperedge type"))
end

function _runtime_root_operator(program)
    program === nothing && return nothing
    length(program.roots) == 1 || return nothing
    n = program.nodes[first(program.roots)]
    n isa ASTApplyV1 ? string(n.operator_ref.qualified.id, "@", n.operator_ref.qualified.version) :
        n isa ASTInputV1 ? "state_input" : n isa ASTParameterV1 ? "parameter_input" :
        n isa ASTConstantV1 ? "constant_input" : nothing
end

function _runtime_type_token(t::PhysicalType)
    string(String(t.value_kind), ":rank=", t.tensor_rank, ":dim=", t.spatial_dimension,
           ":time=", String(Symbol(t.temporal_type.kind)), ":order=", t.temporal_type.derivative_order,
           ":units=", join(string.(t.units.exponents), ";"))
end

function _runtime_edge_obligation(graph::TypedOperatorHypergraphV1, edge, bounds_hash::Digest256)
    ins, outs, role = _runtime_edge_ports(edge)
    prog = _runtime_program(edge)
    op = _runtime_root_operator(prog)
    op === nothing && return nothing, "required_operator_declaration_or_single_root"
    all(i -> 1 <= i <= length(graph.nodes), ins) && all(i -> 1 <= i <= length(graph.nodes), outs) ||
        return nothing, "graph_port_reference"
    input_nodes = Tuple(graph.nodes[i] for i in ins)
    output_nodes = Tuple(graph.nodes[i] for i in outs)
    all_nodes = (input_nodes..., output_nodes...)
    dims = unique(n.physical_type.spatial_dimension for n in all_nodes)
    length(dims) == 1 || return nothing, "consistent_spatial_dimension"
    dim = first(dims)
    # Coordinates are an explicit contract axis.  A PhysicalType dimension is
    # not a declaration of coordinate names, so a nonzero dimension remains a
    # compilation gap until the field Genome exposes such a declaration.
    dim == 0 || return nothing, "required_coordinate_declaration"
    boundary_kinds = unique(String(n.node_kind) for n in all_nodes if n.node_kind in (:boundary, :interface))
    boundary = isempty(boundary_kinds) ? "none_declared" : join(sort(boundary_kinds), "+")
    interface = role == :interface || any(n.node_kind == :interface for n in all_nodes) ? "declared_interface" : "none_declared"
    temporal = unique(String(Symbol(n.physical_type.temporal_type.kind)) for n in all_nodes)
    length(temporal) == 1 || return nothing, "consistent_time_semantics"
    states = Tuple(sort(unique(_runtime_type_token(n.physical_type) for n in input_nodes)))
    outputs = Tuple(sort(unique(string(String(n.node_kind), ":", _runtime_type_token(n.physical_type)) for n in output_nodes)))
    src = isempty(input_nodes) ? "empty_input_space" : join(sort(unique(_runtime_type_token(n.physical_type) for n in input_nodes)), "|")
    dst = isempty(output_nodes) ? "empty_output_space" : join(sort(unique(_runtime_type_token(n.physical_type) for n in output_nodes)), "|")
    schema_hash = canonical_hash(prog)
    # Physical operator obligations are deliberately not emitted here: the
    # generic G2/G3 graph does not prove a solver ABI, coordinates, boundary
    # closure, or component/control mapping.  Keep this helper only for
    # validating declared axes and report the missing physical obligation.
    nothing, string("required_physical_capability:", op)
end

function _runtime_structural_obligation(graph::TypedOperatorHypergraphV1, bounds_hash::Digest256)
    CapabilitySignatureV4("fusionconceptai:runtime-v4-screen", "v1", :structural_screen,
        "typed_structure_audit", ("typed_graph",), "typed_graph", "typed_graph", 1, ("lumped",),
        "none_declared", "none_declared", "static_time", ("typed_structure_audit",),
        screen_only, bounds_hash; input_schema_hash=canonical_hash((schema="fusionconceptai:screen-input", revision="v1")),
        coordinate_system="lumped")
end

function _runtime_collect_declarations(graphs)
    regions = Any[]; interfaces = Any[]; boundaries = Any[]
    for graph in graphs, n in graph.nodes
        d = _runtime_graph_node_descriptor(n)
        n.node_kind == :region && push!(regions, d)
        n.node_kind == :interface && push!(interfaces, d)
        n.node_kind == :boundary && push!(boundaries, d)
    end
    Tuple(regions), Tuple(interfaces), Tuple(boundaries)
end

"""Compile a real CandidateStatePackageV4 and retain every unresolved obligation."""
function compile_candidate(candidate::CandidateStatePackageV4, registry::GenomeContractRegistryV4,
                           mission, bounds; kwargs...)
    return compile_candidate(candidate, registry; mission_payload=mission, bounds_payload=bounds, kwargs...)
end

function compile_candidate(candidate::CandidateStatePackageV4, registry::GenomeContractRegistryV4;
                           mission_payload=missing, bounds_payload=missing, mission=missing, bounds=missing,
                           grammar_payload=missing, comparison_scope=missing, scenario_scope=missing)
    mission_payload === missing && (mission_payload = mission === missing ? candidate.mission_contract_ref : mission)
    bounds_payload === missing && (bounds_payload = bounds === missing ? nothing : bounds)
    graphs = (candidate.mechanism_genome_ref.payload.operator_graph,
              candidate.field_geometry_genome_ref.graph,
              candidate.realization_control_genome_ref.realization_graph,
              candidate.realization_control_genome_ref.control_graph)
    mission_hash = _runtime_decl_hash(mission_payload)
    bounds_hash = _runtime_decl_hash(bounds_payload)
    grammar_hash = grammar_payload === missing ? canonical_hash((registry=registry, contracts=(candidate.mechanism_genome_ref.contract_ref,
        candidate.field_geometry_genome_ref.contract_ref, candidate.realization_control_genome_ref.contract_ref))) : _runtime_decl_hash(grammar_payload)
    comparison = comparison_scope === missing ? ("runtime-v4-structural",) : comparison_scope
    scenarios = scenario_scope === missing ? ("declared_scenarios",) : scenario_scope
    scope = MinimalityScopeV4(grammar_hash, bounds_hash, mission_hash, screen_only,
                              comparison, scenarios)
    unresolved = String[]
    comparison_scope === missing && push!(unresolved, "required_explicit_comparison_scope")
    scenario_scope === missing && push!(unresolved, "required_explicit_scenario_scope")
    resolve_contract(registry, candidate.mechanism_genome_ref.contract_ref, :mechanism) || push!(unresolved, "contract_incompatible:mechanism")
    resolve_contract(registry, candidate.field_geometry_genome_ref.contract_ref, :field_geometry) || push!(unresolved, "contract_incompatible:field_geometry")
    resolve_contract(registry, candidate.realization_control_genome_ref.contract_ref, :realization_control) || push!(unresolved, "contract_incompatible:realization_control")
    all(!isempty(g.nodes) for g in graphs) || push!(unresolved, "required_genome_graph")
    regions, interfaces, boundaries = _runtime_collect_declarations(graphs)
    isempty(regions) && push!(unresolved, "required_region_declaration")
    isempty(boundaries) && push!(unresolved, "required_boundary_declaration")
    obligations = CapabilitySignatureV4[]
    for graph in graphs
        push!(obligations, _runtime_structural_obligation(graph, bounds_hash))
        for edge in graph.hyperedges
            result, gap = _runtime_edge_obligation(graph, edge, bounds_hash)
            if result === nothing
                push!(unresolved, gap)
            else
                push!(obligations, result)
            end
        end
    end
    unresolved = unique(unresolved)
    byhash = Dict{Digest256,CapabilitySignatureV4}()
    for obligation in obligations
        byhash[canonical_hash(obligation)] = obligation
    end
    obligations = [byhash[h] for h in sort!(collect(keys(byhash)), by=string)]
    status = isempty(unresolved) ? :prefix_consistent : :prefix_incomplete
    CompiledCandidatePrefixV4(candidate, mission_payload, bounds_payload, scope,
        graphs[1], graphs[2], graphs[3], graphs[4], regions, interfaces, boundaries,
        Tuple(unresolved), Tuple(obligations), status)
end

derive_capability_obligations(compiled::CompiledCandidatePrefixV4) = compiled.capability_obligations
