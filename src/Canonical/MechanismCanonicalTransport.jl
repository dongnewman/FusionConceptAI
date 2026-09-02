"""Exact decorated transport for a validated G1 mechanism payload.

The transport has one canonicalization subject: an extended incidence graph.
The graph contains the authoritative operator graph and all G1 records. Local
names are represented only by typed attachment arcs, so automorphisms are
resolved by the same exact labeling search as the operator graph.
"""

const _G1_TRANSPORT_DOMAIN = "fusionconceptai:v4:g1-canonical-transport:v1"

struct MechanismCanonicalizationContextV1
    contract_ref::GenomeContractRef
    profile::CanonicalizationProfileV1
    function MechanismCanonicalizationContextV1(contract_ref::GenomeContractRef,
                                                profile::CanonicalizationProfileV1=default_canonicalization_profile())
        new(contract_ref, profile)
    end
end

struct CanonicalMechanismTransportV1
    canonical_bytes::String
    context::MechanismCanonicalizationContextV1
    function CanonicalMechanismTransportV1(payload::MechanismGenomePayloadV1,
                                           context::MechanismCanonicalizationContextV1)
        bytes = invoke(_g1_transport_wire, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
        isvalid(bytes) && !isempty(bytes) || throw(ArgumentError("canonical mechanism transport bytes are invalid"))
        prefix = "{\"canonicalization_version\":\"1\",\"domain\":\"$_G1_TRANSPORT_DOMAIN\",\"contract\":"
        startswith(bytes, prefix) && endswith(bytes, "}") || throw(ArgumentError("canonical mechanism transport has an invalid domain or version"))
        occursin(_g1_transport_contract(context.contract_ref), bytes) || throw(ArgumentError("transport contract context does not match bytes"))
        occursin(_g1_transport_profile(context.profile), bytes) || throw(ArgumentError("transport profile context does not match bytes"))
        occursin(",\"vertices\":[", bytes) && occursin(",\"arcs\":[", bytes) || throw(ArgumentError("transport graph fields are missing"))
        new(bytes, context)
    end
end

function CanonicalMechanismTransportV1(::AbstractString, ::MechanismCanonicalizationContextV1)
    throw(ArgumentError("canonical mechanism transport cannot be constructed from raw bytes"))
end

_g1_transport_quote(x::String) = invoke(_g1_quote, Tuple{String}, x)
_g1_transport_qref(x::QualifiedRefV1) = "{\"id\":" * _g1_transport_quote(x.id) * ",\"version\":" * _g1_transport_quote(x.version) * "}"
_g1_transport_rational(x::Rational{Int64}) = invoke(_g1_rational, Tuple{Rational{Int64}}, x)
_g1_transport_unit(x::UnitSignature) = invoke(_g1_unit, Tuple{UnitSignature}, x)
_g1_transport_type(x::PhysicalType) = invoke(_g1_gene_physical_type_payload, Tuple{PhysicalType}, x)
_g1_transport_quantity(x::QuantityIntervalV1) = invoke(_g1_gene_quantity_payload, Tuple{QuantityIntervalV1}, x)
_g1_transport_matrix(x::ExactRationalMatrixV1) = invoke(_g1_matrix_payload, Tuple{ExactRationalMatrixV1}, x)

function _g1_transport_contract(c::GenomeContractRef)
    "{\"canonicalization_hash\":" * _g1_transport_quote(c.canonicalization_hash.value) *
        ",\"compatibility_profile\":" * _g1_transport_quote(c.compatibility_profile) *
        ",\"schema_hash\":" * _g1_transport_quote(c.schema_hash.value) *
        ",\"uri\":" * _g1_transport_quote(c.uri) * ",\"version\":" * _g1_transport_quote(c.version) * "}"
end

function _g1_transport_profile(p::CanonicalizationProfileV1)
    # Budgets govern execution and are intentionally not identity bytes.
    "{\"profile_id\":" * _g1_transport_quote(p.profile_id) * ",\"version\":" * _g1_transport_quote(p.version) * "}"
end

function _g1_transport_state_color(x::StateGeneV1)
    "state_gene|type=" * _g1_transport_type(x.physical_type) * "|bounds=" * _g1_transport_quantity(x.physical_bounds) *
        "|epistemic=" * invoke(_g1_gene_state_label, Tuple{StateEpistemicV1}, x.epistemic_state) *
        "|parity=" * join(sort(String[invoke(canonical_json, Tuple{ParityActionV1}, p) for p in x.parity_actions]), ",")
end

function _g1_transport_invariant_color(x::InvariantV1)
    "invariant_gene|account=" * _g1_transport_qref(x.account_kind_ref) * "|scope=" * invoke(_g1_gene_scope_label, Tuple{InvariantScopeV1}, x.scope) *
        "|tolerance=" * string(x.tolerance_log10) * "|entropy=" * invoke(_g1_gene_entropy_label, Tuple{EntropyDirectionV1}, x.entropy_direction)
end

function _g1_transport_parameter_color(x::ParameterGeneV1)
    "parameter_gene|unit=" * _g1_transport_unit(x.unit) * "|bounds=" * _g1_transport_quantity(x.bounds) *
        "|transform=" * invoke(_g1_parameter_transform_payload, Tuple{ParameterTransformSpecV1}, x.transform) * "|normalized=" * repr(x.normalized_gene)
end

function _g1_transport_symmetry_color(x::SymmetryGeneV1)
    order = x.group_order === nothing ? "null" : string(x.group_order)
    "symmetry_gene|group=" * invoke(_g1_gene_group_label, Tuple{SymmetryGroupKindV1}, x.group_kind) * "|coordinate=" * _g1_transport_matrix(x.coordinate_generator_matrix) *
        "|order=" * order * "|behavior=" * invoke(_g1_gene_behavior_label, Tuple{SymmetryBehaviorV1}, x.behavior) *
        "|tolerance=" * _g1_transport_rational(x.tolerance)
end

function _g1_transport_condition_color(x::IdentifiabilityConditionV1)
    "condition|intervention=" * _g1_transport_qref(x.intervention_ref) * "|minimum=" * _g1_transport_rational(x.minimum_effect.value) *
        "|floor=" * _g1_transport_rational(x.noise_and_numerical_floor.value) * "|unit=" * _g1_transport_unit(x.minimum_effect.unit)
end

function _g1_transport_observable_color(x::ObservableGeneV1)
    competitors = join(sort(String[_g1_transport_qref(r) for r in x.competing_prediction_refs]), ",")
    "observable_gene|intervention=" * _g1_transport_qref(x.intervention_ref) * "|noise_model=" * _g1_transport_qref(x.noise_model_ref) *
        "|effect=" * _g1_transport_quantity(x.expected_effect_interval) * "|noise=" * _g1_transport_rational(x.noise_floor.value) *
        "|numerical=" * _g1_transport_rational(x.numerical_floor.value) * "|minimum=" * _g1_transport_rational(x.minimum_effect_size.value) *
        "|competitors=[" * competitors * "]"
end

function _g1_transport_hole_color(x::TypedOperatorHoleV1)
    allowed = join(sort(String[String(Symbol(e)) for e in x.allowed_effects]), ",")
    forbidden = join(sort(String[String(Symbol(e)) for e in x.forbidden_effects]), ",")
    outputs = join(String[_g1_transport_type(t) for t in x.ordered_output_types], ",")
    b = x.complexity_budget
    "hole_gene|causal=" * _g1_transport_qref(x.causal_direction_ref) * "|allowed=[" * allowed * "]|forbidden=[" * forbidden *
        "]|budget=" * join(string.((b.max_ast_nodes, b.max_derivative_order, b.max_memory_length, b.max_free_parameters, b.max_free_functions, b.max_suboperators)), ",") *
        "|null=" * _g1_transport_qref(x.null_model_ref) * "|alternatives=[" * join(sort(String[_g1_transport_qref(r) for r in x.alternative_model_refs]), ",") *
        "]|outputs=[" * outputs * "]|oos=[" * join(sort(String[_g1_transport_qref(r) for r in x.out_of_sample_prediction_refs]), ",") * "]"
end

function _g1_transport_add_gene!(kinds::Vector{Symbol}, colors::Vector{String}, kind::Symbol, color::String)
    push!(kinds, kind); push!(colors, color); length(kinds)
end

function _g1_transport_add_arc!(arcs::Vector{Tuple{Int,Int,String}}, source::Int, target::Int, label::String)
    invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, source, target, label)
end

function _g1_transport_apply_binding(program::TypedASTProgramV1, n::ASTApplyV1)
    matches = Tuple(b for b in program.used_manifest_bindings
        if b[1].qualified.id == n.operator_ref.qualified.id && b[1].qualified.version == n.operator_ref.qualified.version)
    length(matches) == 1 || throw(ArgumentError("AST apply has no exact manifest binding"))
    matches[1][2].value
end

function _g1_transport_ast_vertices!(kinds::Vector{Symbol}, colors::Vector{String},
                                     arcs::Vector{Tuple{Int,Int,String}}, program::TypedASTProgramV1,
                                     owner::Int, parameter_vertices::Vector{Int}, parameter_names::Vector{String},
                                     input_port_vertices::Vector{Int}=Int[], output_port_vertices::Vector{Int}=Int[])
    # The AST is expanded into the same incidence subject.  Node names are
    # never colors; parameter identity is supplied by the typed gene arc.
    vertices = Int[]
    for n in program.nodes
        kind, color = if typeof(n) === ASTInputV1
            (:ast_input, "ast_input|type=" * _g1_transport_type(n.output_type) * "|port=" * string(n.port) * "|metadata=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters))
        elseif typeof(n) === ASTParameterV1
            (:ast_parameter, "ast_parameter|type=" * _g1_transport_type(n.output_type) * "|metadata=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters))
        elseif typeof(n) === ASTConstantV1
            (:ast_constant, "ast_constant|type=" * _g1_transport_type(n.output_type) * "|value=" * invoke(_ast_program_canonical, Tuple{Any}, n.value) * "|metadata=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters))
        elseif typeof(n) === ASTApplyV1
            (:ast_apply, "ast_apply|operator=" * invoke(_ast_program_canonical, Tuple{Any}, n.operator_ref) * "|manifest=" * invoke(_g1_transport_apply_binding, Tuple{TypedASTProgramV1,ASTApplyV1}, program, n) * "|type=" * _g1_transport_type(n.output_type) * "|parameters=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters) * "|groups=" * invoke(_ast_program_canonical, Tuple{Any}, n.commutative_input_groups) * "|pure=" * string(n.pure) * "|cse=" * string(n.cse_allowed))
        else
            throw(ArgumentError("transport contains an unsealed AST node"))
        end
        push!(vertices, invoke(_g1_transport_add_gene!, Tuple{Vector{Symbol},Vector{String},Symbol,String}, kinds, colors, kind, color))
    end
    for (i, n) in enumerate(program.nodes)
        invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, owner, vertices[i], "program_node")
        if typeof(n) === ASTApplyV1
            for (p, child) in enumerate(n.inputs)
                1 <= child <= length(vertices) || throw(ArgumentError("AST dependency is out of range"))
                group = nothing
                for g in n.commutative_input_groups
                    p in g && (group = invoke(_ast_program_canonical, Tuple{Any}, g); break)
                end
                label = group === nothing ? "ast_input|$(p)" : "ast_input_commutative_group|" * group
                invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, vertices[i], vertices[child], label)
            end
        elseif typeof(n) === ASTInputV1
            invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, owner, vertices[i], "ast_input_port|$(n.port)")
        elseif typeof(n) === ASTParameterV1
            push!(parameter_vertices, vertices[i]); push!(parameter_names, String(n.name))
        end
    end
    for (p, root) in enumerate(program.roots)
        1 <= root <= length(vertices) || throw(ArgumentError("AST root is out of range"))
        invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, vertices[root], owner, "ast_root|$(p)")
    end
    if !isempty(input_port_vertices)
        length(input_port_vertices) == length(program.input_ports) || throw(ArgumentError("AST input binding arity is inconsistent"))
        for (p, node_index) in enumerate(program.input_ports)
            invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, vertices[node_index], input_port_vertices[p], "ast_to_input_port|$(p)")
        end
    end
    if !isempty(output_port_vertices)
        length(output_port_vertices) == length(program.roots) || throw(ArgumentError("AST output binding arity is inconsistent"))
        for (p, root) in enumerate(program.roots)
            invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, output_port_vertices[p], vertices[root], "output_port_to_ast|$(p)")
        end
    end
end

"""Construct the one decorated incidence graph for the complete payload."""
function _g1_transport_extended_incidence(payload::MechanismGenomePayloadV1)
    graph = payload.operator_graph
    all(typeof(e) === AtomicMIMOHyperedgeV1 for e in graph.hyperedges) || throw(ArgumentError("decorated transport requires only atomic MIMO edges"))
    base = invoke(_incidence_graph, Tuple{TypedOperatorHypergraphV1}, graph)
    kinds = Symbol[base.kinds...]; colors = String[base.local_colors...]; arcs = Tuple{Int,Int,String}[base.arcs...]
    node_ids = String[n.node_id for n in graph.nodes]; edge_ids = String[invoke(_g1_payload_edge_id, Tuple{Any}, e) for e in graph.hyperedges]
    length(unique(node_ids)) == length(node_ids) && length(unique(edge_ids)) == length(edge_ids) || throw(ArgumentError("graph identities are not unique"))
    node_index(id) = begin
        q = findall(==(id), node_ids); length(q) == 1 ? only(q) : throw(ArgumentError("graph node reference is not exact"))
    end
    edge_index(id) = begin
        q = findall(==(id), edge_ids); length(q) == 1 ? only(q) : throw(ArgumentError("graph edge reference is not exact"))
    end
    add(kind, color) = invoke(_g1_transport_add_gene!, Tuple{Vector{Symbol},Vector{String},Symbol,String}, kinds, colors, kind, color)
    add_arc(s, t, label) = invoke(_g1_transport_add_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, s, t, label)
    n_nodes = length(graph.nodes)
    edge_vertices = Int[]; edge_input_ports = Vector{Dict{Int,Int}}(); edge_output_ports = Vector{Dict{Int,Int}}(); edge_cursor = n_nodes + 1
    for edge in graph.hyperedges
        push!(edge_vertices, edge_cursor)
        input_map = Dict{Int,Int}(); output_map = Dict{Int,Int}()
        for binding in edge.input_bindings
            input_map[binding.program_position] = edge_cursor + 1
            edge_cursor += 1
        end
        for binding in edge.output_bindings
            output_map[binding.program_position] = edge_cursor + 1
            edge_cursor += 1
        end
        push!(edge_input_ports, input_map); push!(edge_output_ports, output_map)
        edge_cursor += 1
    end
    # The old graph color contains a derived program hash.  The decorated
    # subject carries the full AST below, so its edge vertex is a semantic
    # role/effect shell rather than an opaque hash or local name.
    for (i, e) in enumerate(graph.hyperedges)
        effects = join(sort(String[invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, v) for v in e.account_effects]), ",")
        pairs = join(sort(String[invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, v) for v in e.interface_flux_pairs]), ",")
        colors[edge_vertices[i]] = "edge|atomic|role=" * String(Symbol(e.role)) * "|effects=[" * effects * "]|pairs=[" * pairs * "]"
    end
    gene_vertices = Dict{Symbol,Vector{Int}}()
    for (kind, vals) in ((:state_gene, payload.states), (:invariant_gene, payload.invariants),
                         (:parameter_gene, payload.parameters), (:symmetry_gene, payload.symmetries),
                         (:observable_gene, payload.observables), (:hole_gene, payload.operator_holes))
        gene_vertices[kind] = Int[]
        for value in vals
            color = if kind === :state_gene
                invoke(_g1_transport_state_color, Tuple{StateGeneV1}, value)
            elseif kind === :invariant_gene
                invoke(_g1_transport_invariant_color, Tuple{InvariantV1}, value)
            elseif kind === :parameter_gene
                invoke(_g1_transport_parameter_color, Tuple{ParameterGeneV1}, value)
            elseif kind === :symmetry_gene
                invoke(_g1_transport_symmetry_color, Tuple{SymmetryGeneV1}, value)
            elseif kind === :observable_gene
                invoke(_g1_transport_observable_color, Tuple{ObservableGeneV1}, value)
            elseif kind === :hole_gene
                invoke(_g1_transport_hole_color, Tuple{TypedOperatorHoleV1}, value)
            else
                throw(ArgumentError("unknown transport gene kind"))
            end
            push!(gene_vertices[kind], add(kind, color))
        end
    end
    state_v = Dict(x.state_ref.value => gene_vertices[:state_gene][i] for (i, x) in enumerate(payload.states))
    invariant_v = Dict(x.invariant_ref.value => gene_vertices[:invariant_gene][i] for (i, x) in enumerate(payload.invariants))
    parameter_v = Dict(x.ref.value => gene_vertices[:parameter_gene][i] for (i, x) in enumerate(payload.parameters))
    symmetry_v = Dict(x.ref.value => gene_vertices[:symmetry_gene][i] for (i, x) in enumerate(payload.symmetries))
    observable_v = Dict(x.observable_ref.value => gene_vertices[:observable_gene][i] for (i, x) in enumerate(payload.observables))
    for (i, x) in enumerate(payload.states)
        v = gene_vertices[:state_gene][i]; add_arc(v, node_index(x.state_ref.value), "state_gene_to_state_node")
        for r in x.gauge_refs; add_arc(v, symmetry_v[r.value], "state_gene_to_symmetry"); end
        for r in x.constraint_refs; add_arc(v, edge_vertices[edge_index(r.value)], "state_gene_to_constraint_edge"); end
    end
    for (i, x) in enumerate(payload.invariants)
        v = gene_vertices[:invariant_gene][i]
        for t in x.terms
            tv = add(:invariant_term, "invariant_term|coefficient=" * _g1_transport_rational(t.coefficient))
            add_arc(v, tv, "invariant_term"); add_arc(tv, state_v[t.state_ref.value], "term_state")
        end
        for r in x.allowed_source_refs; add_arc(v, edge_vertices[edge_index(r.value)], "invariant_source"); end
        for r in x.allowed_sink_refs; add_arc(v, edge_vertices[edge_index(r.value)], "invariant_sink"); end
        for r in x.boundary_flux_refs; add_arc(v, edge_vertices[edge_index(r.value)], "invariant_boundary"); end
        if x.scope_ref !== nothing
            id = x.scope_ref.id; ns = findall(==(id), node_ids); es = findall(==(id), edge_ids)
            length(ns) + length(es) == 1 || throw(ArgumentError("invariant scope reference is not exact"))
            add_arc(v, isempty(ns) ? edge_vertices[edge_index(id)] : only(ns), "invariant_scope|version=" * _g1_transport_quote(x.scope_ref.version))
        end
    end
    for (i, x) in enumerate(payload.symmetries)
        v = gene_vertices[:symmetry_gene][i]
        for (p, act) in enumerate(x.state_actions)
            av = add(:symmetry_action, "symmetry_action|matrix=" * _g1_transport_matrix(act.matrix))
            add_arc(v, av, "symmetry_action"); add_arc(av, state_v[act.state_ref.value], "action_state")
        end
    end
    for (i, x) in enumerate(payload.observables)
        v = gene_vertices[:observable_gene][i]
        add_arc(v, edge_vertices[edge_index(x.expression_root.operator_site_ref.value)], "observable_expression_root|$(x.expression_root.root_position)")
    end
    for (i, x) in enumerate(payload.operator_holes)
        v = gene_vertices[:hole_gene][i]
        for (p, r) in enumerate(x.ordered_input_state_refs); add_arc(v, state_v[r.value], "hole_input_state|$(p)"); end
        for r in x.observable_refs; add_arc(v, observable_v[r.value], "hole_observable"); end
        for c in x.identifiability_conditions
            cv = add(:identifiability_condition, invoke(_g1_transport_condition_color, Tuple{IdentifiabilityConditionV1}, c))
            add_arc(v, cv, "hole_condition"); add_arc(cv, observable_v[c.observable_ref.value], "condition_observable")
        end
    end
    parameter_vertices = Int[]; parameter_names = String[]
    for (i, e) in enumerate(graph.hyperedges)
        input_positions = 1:length(e.program.input_ports)
        output_positions = 1:length(e.program.roots)
        all(haskey(edge_input_ports[i], p) for p in input_positions) || throw(ArgumentError("AST input binding position is not present in the edge"))
        all(haskey(edge_output_ports[i], p) for p in output_positions) || throw(ArgumentError("AST output binding position is not present in the edge"))
        input_ports = Int[edge_input_ports[i][p] for p in input_positions]
        output_ports = Int[edge_output_ports[i][p] for p in output_positions]
        invoke(_g1_transport_ast_vertices!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},TypedASTProgramV1,Int,Vector{Int},Vector{String},Vector{Int},Vector{Int}}, kinds, colors, arcs, e.program, edge_vertices[i], parameter_vertices, parameter_names, input_ports, output_ports)
    end
    for (i, x) in enumerate(payload.observables)
        invoke(_g1_transport_ast_vertices!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},TypedASTProgramV1,Int,Vector{Int},Vector{String},Vector{Int},Vector{Int}}, kinds, colors, arcs, x.sampling_program, gene_vertices[:observable_gene][i], parameter_vertices, parameter_names, Int[], Int[])
    end
    for (v, name) in zip(parameter_vertices, parameter_names)
        haskey(parameter_v, name) || throw(ArgumentError("AST parameter has no matching ParameterGene"))
        add_arc(parameter_v[name], v, "parameter_gene_to_ast_parameter")
    end
    invoke(_IncidenceGraphV1, Tuple{Any,Any,Any}, Tuple(kinds), Tuple(colors), Tuple(arcs))
end

function _g1_transport_leaf_wire(payload::MechanismGenomePayloadV1,
                                 context::MechanismCanonicalizationContextV1,
                                 ig::_IncidenceGraphV1, witness::Tuple)
    # The complete decorated incidence leaf is the transport wire.  Since all
    # semantic values and attachments live in this subject, comparing these
    # bytes is the exact decorated tie-break (not a witness-then-decoration).
    rank = zeros(Int, length(witness))
    for (new, old) in enumerate(witness); rank[old] = new; end
    vertices = "[" * join(String["{\"kind\":" * _g1_transport_quote(String(ig.kinds[old])) * ",\"local_color\":" * _g1_transport_quote(ig.local_colors[old]) * "}" for old in witness], ",") * "]"
    arcs = sort!([(rank[s], rank[t], l) for (s, t, l) in ig.arcs])
    arc_wire = "[" * join(String["{\"label\":" * _g1_transport_quote(a[3]) * ",\"source\":" * string(a[1]) * ",\"target\":" * string(a[2]) * "}" for a in arcs], ",") * "]"
    "{\"canonicalization_version\":\"1\",\"domain\":" * _g1_transport_quote(_G1_TRANSPORT_DOMAIN) * ",\"contract\":" * _g1_transport_contract(context.contract_ref) *
        ",\"profile\":" * _g1_transport_profile(context.profile) * ",\"vertices\":" * vertices * ",\"arcs\":" * arc_wire * "}"
end

function _g1_transport_search(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1,
                              ig::_IncidenceGraphV1, colors::Vector{Int}, search_nodes::Base.RefValue{Int},
                              rounds::Base.RefValue{Int};
                              initial_partition_pending::Bool=false)
    search_nodes[] += 1
    search_nodes[] <= context.profile.budget.max_search_nodes || throw(CanonicalizationDeferred("canonicalization search budget exhausted"))
    if initial_partition_pending
        cells = [cell for cell in _incidence_partition(colors) if length(cell) > 1]
        if !isempty(cells)
            target = first(sort(cells, by=cell -> (length(cell), sort(collect(colors[v] for v in cell)))))
            best = nothing
            for vertex in target
                candidate = invoke(_g1_transport_search, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1,_IncidenceGraphV1,Vector{Int},Base.RefValue{Int},Base.RefValue{Int}},
                    payload, context, ig, _incidence_split_color(colors, vertex), search_nodes, rounds; initial_partition_pending=false)
                best === nothing || candidate[1] < best[1] || continue
                best = candidate
            end
            return best
        end
    end
    refined = invoke(_incidence_refine, Tuple{_IncidenceGraphV1,Vector{Int},CanonicalizationBudgetV1,Base.RefValue{Int}}, ig, colors, context.profile.budget, rounds)
    cells = [cell for cell in _incidence_partition(refined) if length(cell) > 1]
    isempty(cells) && begin
        order = Tuple(sortperm(refined))
        return (invoke(_g1_transport_leaf_wire, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1,_IncidenceGraphV1,Tuple}, payload, context, ig, order), order)
    end
    target = first(sort(cells, by=cell -> (length(cell), sort(collect(refined[v] for v in cell)))))
    best = nothing
    for vertex in target
        candidate = invoke(_g1_transport_search, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1,_IncidenceGraphV1,Vector{Int},Base.RefValue{Int},Base.RefValue{Int}},
            payload, context, ig, _incidence_split_color(refined, vertex), search_nodes, rounds; initial_partition_pending=false)
        best === nothing || candidate[1] < best[1] || continue
        best = candidate
    end
    best
end

function _g1_transport_wire(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
    ext = invoke(_g1_transport_extended_incidence, Tuple{MechanismGenomePayloadV1}, payload)
    length(ext.kinds) <= context.profile.budget.max_vertices || throw(CanonicalizationDeferred("canonicalization vertex budget exhausted"))
    colors = invoke(_incidence_initial_colors_for_graph, Tuple{_IncidenceGraphV1}, ext)
    result = invoke(_g1_transport_search, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1,_IncidenceGraphV1,Vector{Int},Base.RefValue{Int},Base.RefValue{Int}},
        payload, context, ext, colors, Ref(0), Ref(0); initial_partition_pending=true)
    ncodeunits(result[1]) <= context.profile.budget.max_bytes || throw(CanonicalizationDeferred("canonicalization byte budget exhausted"))
    result[1]
end

function canonicalize_mechanism_transport(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
    invoke(CanonicalMechanismTransportV1, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
end

function canonicalize_mechanism_transport(payload::MechanismGenomePayloadV1, contract_ref::GenomeContractRef;
                                          profile::CanonicalizationProfileV1=default_canonicalization_profile())
    canonicalize_mechanism_transport(payload, MechanismCanonicalizationContextV1(contract_ref, profile))
end

canonical_mechanism_transport_json(transport::CanonicalMechanismTransportV1) = transport.canonical_bytes
