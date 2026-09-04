"""Layer-aware exact canonical identities for a sealed mechanism payload."""

const _G1_LAYER_VERSION = "1"
const _G1_LAYER_DOMAINS = (
    contract="fusionconceptai:v4:g1-hash:contract:v1",
    profile="fusionconceptai:v4:g1-hash:canonicalization-profile:v1",
    registry="fusionconceptai:v4:g1-hash:operator-registry:v1",
    topology="fusionconceptai:v4:g1-hash:topology:v1",
    operator_program="fusionconceptai:v4:g1-hash:operator-program:v1",
    mechanism_structure="fusionconceptai:v4:g1-hash:mechanism-structure:v1",
    decorated="fusionconceptai:v4:g1-hash:decorated-mechanism:v1",
    candidate="fusionconceptai:v4:g1-hash:candidate-subject:v1")

function _g1_layer_domain(layer::Symbol)
    layer === :topology && return _G1_LAYER_DOMAINS.topology
    layer === :operator_program && return _G1_LAYER_DOMAINS.operator_program
    layer === :structure && return _G1_LAYER_DOMAINS.mechanism_structure
    layer === :decorated && return _G1_LAYER_DOMAINS.decorated
    layer === :candidate && return _G1_LAYER_DOMAINS.candidate
    throw(ArgumentError("unknown mechanism layer domain"))
end

struct MechanismHashLayersV1
    contract_hash::Digest256
    canonicalization_profile_hash::Digest256
    operator_registry_hash::Digest256
    topology_hash::Digest256
    operator_program_hash::Digest256
    mechanism_structure_hash::Digest256
    decorated_mechanism_hash::Digest256
    candidate_subject_hash::Digest256
    function MechanismHashLayersV1(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
        wires = invoke(_g1_layer_wires, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
        hashes = ntuple(i -> invoke(_g1_layer_hash, Tuple{String}, wires[i]), 8)
        new(hashes...)
    end
end

struct CanonicalMechanismV1
    transport::CanonicalMechanismTransportV1
    hashes::MechanismHashLayersV1
    function CanonicalMechanismV1(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
        transport = invoke(canonicalize_mechanism_transport,
            Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
        hashes = invoke(MechanismHashLayersV1,
            Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
        new(transport, hashes)
    end
end

function CanonicalMechanismV1(::CanonicalMechanismTransportV1, ::MechanismHashLayersV1)
    throw(ArgumentError("canonical mechanism is sealed; use canonicalize_mechanism"))
end

_g1_layer_quote(x::String) = invoke(_g1_quote, Tuple{String}, x)
_g1_layer_digest(x::Digest256) = _g1_layer_quote(x.value)
_g1_layer_hash(x::String) = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(x)))))

function _g1_layer_dep(pairs::Vector{Tuple{String,Digest256}})
    keys = String[x[1] for x in pairs]
    length(unique(keys)) == length(keys) || throw(ArgumentError("duplicate layer dependency"))
    sort!(pairs, by=x -> x[1])
    "{" * join((_g1_layer_quote(x[1]) * ":" * _g1_layer_digest(x[2]) for x in pairs), ",") * "}"
end
function _g1_layer_wrap(domain::String, dependencies::String, payload::String)
    "{\"canonicalization_version\":\"1\",\"dependencies\":" * dependencies *
        ",\"domain\":" * _g1_layer_quote(domain) * ",\"payload\":" * payload * "}"
end

function _g1_layer_check_bytes(bytes::String, profile::CanonicalizationProfileV1)
    ncodeunits(bytes) <= profile.budget.max_bytes || throw(CanonicalizationDeferred("layer wire byte budget exhausted"))
    bytes
end

function _g1_layer_contract_wire(c::GenomeContractRef)
    invoke(_g1_layer_wrap, Tuple{String,String,String}, _G1_LAYER_DOMAINS.contract, "{}", invoke(_g1_transport_contract, Tuple{GenomeContractRef}, c))
end
function _g1_layer_profile_wire(p::CanonicalizationProfileV1)
    invoke(_g1_layer_wrap, Tuple{String,String,String}, _G1_LAYER_DOMAINS.profile, "{}", invoke(_g1_transport_profile, Tuple{CanonicalizationProfileV1}, p))
end

function _g1_layer_rule(r::OperatorTypeRuleV1)
    if typeof(r) === ExactTypeRuleV1
        return "{\"kind\":\"exact\",\"inputs\":[" * join((_g1_transport_type(x) for x in r.input_types), ",") *
            "],\"outputs\":[" * join((_g1_transport_type(x) for x in r.output_types), ",") * "]}"
    elseif typeof(r) === SameTypeVariadicRuleV1
        return "{\"kind\":\"same_type_variadic\",\"minimum\":" * string(r.minimum_arity) * ",\"maximum\":" * string(r.maximum_arity) * "}"
    elseif typeof(r) === ScalarProductRuleV1
        return "{\"kind\":\"scalar_product\",\"division\":" * (r.division ? "true" : "false") * "}"
    elseif typeof(r) === DotProductRuleV1
        return "{\"kind\":\"dot_product\"}"
    elseif typeof(r) === TensorProductRuleV1
        return "{\"kind\":\"tensor_product\"}"
    elseif typeof(r) === ContractRuleV1
        return "{\"kind\":\"contract\"}"
    elseif typeof(r) === SpatialDerivativeRuleV1
        return "{\"kind\":\"spatial_derivative\",\"opcode\":" * _g1_layer_quote(String(r.opcode)) * "}"
    elseif typeof(r) === TimeDerivativeRuleV1
        return "{\"kind\":\"time_derivative\"}"
    elseif typeof(r) === SamplingRuleV1
        return "{\"kind\":\"sampling\",\"hold\":" * (r.hold ? "true" : "false") * "}"
    elseif typeof(r) === DelayRuleV1
        return "{\"kind\":\"delay\"}"
    elseif typeof(r) === EventTransitionRuleV1
        return "{\"kind\":\"event_transition\",\"opcode\":" * _g1_layer_quote(String(r.opcode)) * "}"
    end
    throw(ArgumentError("layer registry contains an unsealed operator rule"))
end

function _g1_layer_manifest(m::OperatorManifestV1)
    schemas = String["{\"name\":" * _g1_layer_quote(String(x.name)) * ",\"required\":" * (x.required ? "true" : "false") *
        ",\"type_tag\":" * _g1_layer_quote(String(x.type_tag)) * "}" for x in m.parameter_schema]
    groups = String["[" * join(string.(x), ",") * "]" for x in m.commutative_input_groups]
    fields = ("allowed_conservation_effects", "[" * join((_g1_layer_quote(String(x)) for x in m.allowed_conservation_effects), ",") * "]",
        "allowed_roles", "[" * join((_g1_layer_quote(String(x)) for x in m.allowed_roles), ",") * "]",
        "commutative_input_groups", "[" * join(groups, ",") * "]", "cse_allowed", m.cse_allowed ? "true" : "false",
        "event", m.event ? "true" : "false", "forbidden_conservation_effects", "[" * join((_g1_layer_quote(String(x)) for x in m.forbidden_conservation_effects), ",") * "]",
        "input_arity", string(m.input_arity), "input_type_rule", invoke(_g1_layer_rule, Tuple{OperatorTypeRuleV1}, m.input_type_rule), "locality", _g1_layer_quote(String(m.locality)),
        "manifest_hash", _g1_layer_digest(m.manifest_hash), "max_derivative_contribution", string(m.max_derivative_contribution),
        "operator_ref", "{\"id\":" * _g1_layer_quote(m.operator_ref.qualified.id) * ",\"version\":" * _g1_layer_quote(m.operator_ref.qualified.version) * "}",
        "output_arity", string(m.output_arity), "output_type_rule", invoke(_g1_layer_rule, Tuple{OperatorTypeRuleV1}, m.output_type_rule),
        "parameter_schema", "[" * join(schemas, ",") * "]", "pure", m.pure ? "true" : "false",
        "stateful", m.stateful ? "true" : "false", "stochastic", m.stochastic ? "true" : "false")
    "{" * join((_g1_layer_quote(fields[i]) * ":" * fields[i+1] for i in 1:2:length(fields)), ",") * "}"
end

function _g1_layer_used_manifests(payload::MechanismGenomePayloadV1)
    registry = invoke(_g1_payload_registry, Tuple{TypedOperatorHypergraphV1}, payload.operator_graph)
    refs = Tuple{OperatorRefV1,Digest256}[]
    for edge in payload.operator_graph.hyperedges, binding in edge.program.used_manifest_bindings
        push!(refs, binding)
    end
    for observable in payload.observables, binding in observable.sampling_program.used_manifest_bindings
        push!(refs, binding)
    end
    # Deduplicate by explicit wire fields.  Do not use generic tuple hashing or
    # equality: a conflicting manifest digest for one qualified operator is a
    # hard closure error, not a second candidate.
    sort!(refs, by=x -> (x[1].qualified.id, x[1].qualified.version, x[2].value))
    unique_refs = Tuple{OperatorRefV1,Digest256}[]
    for item in refs
        if !isempty(unique_refs)
            previous = unique_refs[end]
            same_ref = previous[1].qualified.id == item[1].qualified.id && previous[1].qualified.version == item[1].qualified.version
            same_ref && previous[2].value != item[2].value && throw(ArgumentError("one operator reference has conflicting manifest hashes"))
            same_ref && continue
        end
        push!(unique_refs, item)
    end
    manifests = OperatorManifestV1[]
    for (ref, digest) in unique_refs
        manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,QualifiedRefV1}, registry, ref.qualified)
        manifest.manifest_hash == digest || throw(ArgumentError("used operator manifest hash is not exact"))
        push!(manifests, manifest)
    end
    registry, manifests
end

function _g1_layer_registry_wire(payload::MechanismGenomePayloadV1)
    _, manifests = invoke(_g1_layer_used_manifests, Tuple{MechanismGenomePayloadV1}, payload)
    invoke(_g1_layer_wrap, Tuple{String,String,String}, _G1_LAYER_DOMAINS.registry, "{}", "{\"manifests\":[" * join((invoke(_g1_layer_manifest, Tuple{OperatorManifestV1}, m) for m in manifests), ",") * "]}")
end

function _g1_layer_add!(kinds::Vector{Symbol}, colors::Vector{String}, arcs::Vector{Tuple{Int,Int,String}}, kind::Symbol, color::String)
    push!(kinds, kind); push!(colors, color); length(kinds)
end
function _g1_layer_arc!(arcs::Vector{Tuple{Int,Int,String}}, s::Int, t::Int, label::String)
    push!(arcs, (s, t, label)); nothing
end

function _g1_layer_ast!(kinds::Vector{Symbol}, colors::Vector{String}, arcs::Vector{Tuple{Int,Int,String}},
                        program::TypedASTProgramV1, owner::Int, input_vertices::Vector{Int},
                        output_vertices::Vector{Int}, layer::Symbol, registry::OperatorRegistryV1)
    vertices = Int[]
    parameter_vertices = Int[]; parameter_names = String[]
    for n in program.nodes
        kind, color = if typeof(n) === ASTInputV1
            (:ast_input, "ast_input|type=" * _g1_transport_type(n.output_type) * "|metadata=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters))
        elseif typeof(n) === ASTParameterV1
            (:ast_parameter, "ast_parameter|type=" * _g1_transport_type(n.output_type) * "|metadata=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters))
        elseif typeof(n) === ASTConstantV1
            (:ast_constant, "ast_constant|type=" * _g1_transport_type(n.output_type) * "|value=" * invoke(_ast_program_canonical, Tuple{Any}, n.value) * "|metadata=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters))
        elseif typeof(n) === ASTApplyV1
            manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,QualifiedRefV1}, registry, n.operator_ref.qualified)
            (:ast_apply, "ast_apply|operator=" * invoke(_ast_program_canonical, Tuple{Any}, n.operator_ref) * "|manifest=" * invoke(_g1_transport_apply_binding, Tuple{TypedASTProgramV1,ASTApplyV1}, program, n) * "|type=" * _g1_transport_type(n.output_type) * "|parameters=" * invoke(_ast_program_canonical, Tuple{Any}, n.parameters) * "|groups=" * invoke(_ast_program_canonical, Tuple{Any}, n.commutative_input_groups) * "|pure=" * string(manifest.pure) * "|stateful=" * string(manifest.stateful) * "|stochastic=" * string(manifest.stochastic) * "|event=" * string(manifest.event) * "|locality=" * String(manifest.locality) * "|cse=" * string(manifest.cse_allowed))
        else
            throw(ArgumentError("layer AST contains an unsealed node"))
        end
        push!(vertices, invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, kind, color))
    end
    for (i, n) in enumerate(program.nodes)
        invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, owner, vertices[i], "program_node")
        if typeof(n) === ASTApplyV1
            for (p, child) in enumerate(n.inputs)
                1 <= child <= length(vertices) || throw(ArgumentError("layer AST dependency is out of range"))
                group = nothing
                for g in n.commutative_input_groups
                    p in g && (group = invoke(_ast_program_canonical, Tuple{Any}, g); break)
                end
                invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, vertices[i], vertices[child], group === nothing ? "ast_input|$(p)" : "ast_input_commutative_group|" * group)
            end
        elseif typeof(n) === ASTInputV1
            invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, owner, vertices[i], "ast_input_port|$(n.port)")
        elseif typeof(n) === ASTParameterV1
            push!(parameter_vertices, vertices[i]); push!(parameter_names, String(n.name))
        end
    end
    for (p, root) in enumerate(program.roots)
        invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, vertices[root], owner, "ast_root|$(p)")
        !isempty(output_vertices) && invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, output_vertices[p], vertices[root], "output_port_to_ast|$(p)")
    end
    if !isempty(input_vertices)
        length(input_vertices) == length(program.input_ports) || throw(ArgumentError("layer AST input arity mismatch"))
        for (p, node_index) in enumerate(program.input_ports)
            invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, vertices[node_index], input_vertices[p], "ast_to_input_port|$(p)")
        end
    end
    (vertices, parameter_vertices, parameter_names)
end

function _g1_layer_gene_color(layer::Symbol, kind::Symbol, value)
    if layer === :structure
        kind === :state_gene && return "state_gene|parity_actions=" * string(length(value.parity_actions)) *
            "|gauge_refs=" * string(length(value.gauge_refs)) * "|constraint_refs=" * string(length(value.constraint_refs))
        kind === :invariant_gene && return "invariant_gene|scope=" * String(Symbol(value.scope)) * "|terms=" * string(length(value.terms)) *
            "|source_refs=" * string(length(value.allowed_source_refs)) * "|sink_refs=" * string(length(value.allowed_sink_refs)) *
            "|boundary_refs=" * string(length(value.boundary_flux_refs))
        kind === :parameter_gene && return "parameter_gene"
        kind === :symmetry_gene && return "symmetry_gene|group=" * String(Symbol(value.group_kind)) *
            "|behavior=" * String(Symbol(value.behavior)) * "|shape=" * string(invoke(_g1_matrix_shape, Tuple{ExactRationalMatrixV1}, value.coordinate_generator_matrix)[1]) * "x" * string(invoke(_g1_matrix_shape, Tuple{ExactRationalMatrixV1}, value.coordinate_generator_matrix)[2]) *
            "|actions=" * string(length(value.state_actions))
        kind === :observable_gene && return "observable_gene|competitors=" * string(length(value.competing_prediction_refs))
        kind === :hole_gene && return "hole_gene|inputs=" * string(length(value.ordered_input_state_refs)) * "|outputs=" * string(length(value.ordered_output_types)) *
            "|allowed=" * string(length(value.allowed_effects)) * "|forbidden=" * string(length(value.forbidden_effects)) *
            "|conditions=" * string(length(value.identifiability_conditions)) * "|observables=" * string(length(value.observable_refs)) *
            "|oos=" * string(length(value.out_of_sample_prediction_refs)) * "|alternatives=" * string(length(value.alternative_model_refs))
    end
    kind === :state_gene && return invoke(_g1_transport_state_color, Tuple{StateGeneV1}, value)
    kind === :invariant_gene && return invoke(_g1_transport_invariant_color, Tuple{InvariantV1}, value)
    kind === :parameter_gene && begin
        base = "parameter_gene|unit=" * _g1_transport_unit(value.unit) * "|bounds=" * _g1_transport_quantity(value.bounds) *
            "|transform=" * invoke(_g1_parameter_transform_payload, Tuple{ParameterTransformSpecV1}, value.transform)
        return base
    end
    kind === :symmetry_gene && return invoke(_g1_transport_symmetry_color, Tuple{SymmetryGeneV1}, value)
    kind === :observable_gene && return invoke(_g1_transport_observable_color, Tuple{ObservableGeneV1}, value)
    kind === :hole_gene && return invoke(_g1_transport_hole_color, Tuple{TypedOperatorHoleV1}, value)
    throw(ArgumentError("unknown layer gene kind"))
end

function _g1_layer_extended_incidence(payload::MechanismGenomePayloadV1, layer::Symbol)
    layer in (:topology, :operator_program, :structure, :decorated) || throw(ArgumentError("unknown mechanism hash layer"))
    graph = payload.operator_graph
    all(typeof(e) === AtomicMIMOHyperedgeV1 for e in graph.hyperedges) || throw(ArgumentError("layer projections require atomic MIMO edges"))
    registry = invoke(_g1_payload_registry, Tuple{TypedOperatorHypergraphV1}, graph)
    n = length(graph.nodes); kinds = Symbol[]; colors = String[]; arcs = Tuple{Int,Int,String}[]
    for node_value in graph.nodes
        push!(kinds, :graph_node)
        push!(colors, layer === :topology ? "node|kind=" * String(Symbol(node_value.node_kind)) : "node|kind=" * String(Symbol(node_value.node_kind)) * "|type=" * _g1_transport_type(node_value.physical_type))
    end
    edge_vertices = Int[]; input_maps = Vector{Dict{Int,Int}}(); output_maps = Vector{Dict{Int,Int}}(); cursor = n + 1
    for edge in graph.hyperedges
        ev = cursor; push!(edge_vertices, ev); push!(kinds, :atomic_edge)
        edge_color = layer === :topology ? "edge|atomic" :
            layer === :operator_program ? "edge|atomic|operator" :
            "edge|atomic|role=" * String(Symbol(edge.role))
        push!(colors, edge_color)
        im = Dict{Int,Int}(); om = Dict{Int,Int}()
        for b in edge.input_bindings
            pv = cursor + 1; cursor += 1; im[b.program_position] = pv; push!(kinds, :input_port); push!(colors, "input_port|position=" * string(b.program_position))
            invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, ev, pv, "edge_to_input"); invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, pv, b.graph_node_index, "input_to_node")
        end
        for b in edge.output_bindings
            pv = cursor + 1; cursor += 1; om[b.program_position] = pv; push!(kinds, :output_port); push!(colors, "output_port|position=" * string(b.program_position))
            invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, b.graph_node_index, pv, "node_to_output"); invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, pv, ev, "output_to_edge")
        end
        push!(input_maps, im); push!(output_maps, om); cursor += 1
    end
    if layer !== :topology
        gene_vertices = Dict{Symbol,Vector{Int}}()
        if layer in (:structure, :decorated)
            for (kind, values) in ((:state_gene, payload.states), (:invariant_gene, payload.invariants), (:parameter_gene, payload.parameters), (:symmetry_gene, payload.symmetries), (:observable_gene, payload.observables), (:hole_gene, payload.operator_holes))
                gene_vertices[kind] = Int[invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, kind,
                    invoke(_g1_layer_gene_color, Tuple{Symbol,Symbol,Any}, layer, kind, value)) for value in values]
            end
        end
        params = Int[]; names = String[]
        for (i, edge) in enumerate(graph.hyperedges)
            all(haskey(input_maps[i], p) for p in 1:length(edge.program.input_ports)) || throw(ArgumentError("layer edge input binding is incomplete"))
            all(haskey(output_maps[i], p) for p in 1:length(edge.program.roots)) || throw(ArgumentError("layer edge output binding is incomplete"))
            ins = Int[input_maps[i][p] for p in 1:length(edge.program.input_ports)]
            outs = Int[output_maps[i][p] for p in 1:length(edge.program.roots)]
            result = invoke(_g1_layer_ast!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},TypedASTProgramV1,Int,Vector{Int},Vector{Int},Symbol,OperatorRegistryV1},
                kinds, colors, arcs, edge.program, edge_vertices[i], ins, outs, layer, registry)
            append!(params, result[2]); append!(names, result[3])
        end
        for (i, observable) in enumerate(payload.observables)
            owner = layer in (:structure, :decorated) ? gene_vertices[:observable_gene][i] : invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :sampling_owner, "sampling_owner")
            result = invoke(_g1_layer_ast!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},TypedASTProgramV1,Int,Vector{Int},Vector{Int},Symbol,OperatorRegistryV1},
                kinds, colors, arcs, observable.sampling_program, owner, Int[], Int[], layer, registry)
            append!(params, result[2]); append!(names, result[3])
        end
        if layer in (:structure, :decorated)
            # Conservation is part of the local relation graph.  The structure
            # projection deliberately retains only endpoint shape/direction;
            # account identity, units and coefficients enter at decorated.
            ledger_keys = Tuple{String,String}[]
            for edge in graph.hyperedges
                for effect in edge.account_effects
                    key = (effect.account_ref.account, invoke(_g1_transport_unit, Tuple{UnitSignature}, effect.account_ref.unit))
                    any(existing -> existing[1] == key[1] && existing[2] == key[2], ledger_keys) || push!(ledger_keys, key)
                end
                for pair in edge.interface_flux_pairs
                    for effect in (pair.minus, pair.plus)
                        key = (effect.account_ref.account, invoke(_g1_transport_unit, Tuple{UnitSignature}, effect.account_ref.unit))
                        any(existing -> existing[1] == key[1] && existing[2] == key[2], ledger_keys) || push!(ledger_keys, key)
                    end
                end
            end
            sort!(ledger_keys, by=x -> (x[1], x[2]))
            ledger_vertices = Int[]
            for key in ledger_keys
                ledger_color = layer === :structure ? "ledger_account" :
                    "ledger_account|account=" * _g1_layer_quote(key[1]) * "|unit=" * key[2]
                push!(ledger_vertices, invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :ledger_account, ledger_color))
            end
            ledger_for(ref) = begin
                key = (ref.account, invoke(_g1_transport_unit, Tuple{UnitSignature}, ref.unit))
                found = findfirst(existing -> existing[1] == key[1] && existing[2] == key[2], ledger_keys)
                found === nothing && throw(ArgumentError("conservation ledger key is missing"))
                ledger_vertices[found]
            end
            for (i, edge) in enumerate(graph.hyperedges)
                ev = edge_vertices[i]
                for effect in edge.account_effects
                    ref = effect.account_ref
                    port_map = ref.port_side === :input ? input_maps[i] : output_maps[i]
                    haskey(port_map, ref.port_index) || throw(ArgumentError("effect endpoint is not present in layer incidence"))
                    ecolor = layer === :structure ?
                        "account_effect|side=" * String(ref.port_side) * "|direction=" * String(ref.direction) :
                        "account_effect|" * invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, effect)
                    av = invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :account_effect, ecolor)
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, ev, av, "edge_to_account_effect")
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, av, port_map[ref.port_index], "account_effect_to_" * String(ref.port_side))
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, av, ledger_for(ref), "account_effect_to_ledger")
                end
                for pair in edge.interface_flux_pairs
                    minus = pair.minus.account_ref; plus = pair.plus.account_ref
                    haskey(output_maps[i], minus.port_index) && haskey(output_maps[i], plus.port_index) ||
                        throw(ArgumentError("interface endpoint is not present in layer incidence"))
                    pcolor = layer === :structure ? "interface_pair" :
                        "interface_pair|" * invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, pair)
                    pv = invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :interface_pair, pcolor)
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, ev, pv, "edge_to_interface_pair")
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, pv, output_maps[i][minus.port_index], "interface_minus")
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, pv, output_maps[i][plus.port_index], "interface_plus")
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, pv, ledger_for(minus), "interface_minus_to_ledger")
                    invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, pv, ledger_for(plus), "interface_plus_to_ledger")
                end
            end
            node_ref = Dict(x.node_id => i for (i, x) in enumerate(graph.nodes)); edge_ref = Dict(invoke(_g1_payload_edge_id, Tuple{Any}, x) => i for (i, x) in enumerate(graph.hyperedges))
            state_ref = Dict(x.state_ref.value => gene_vertices[:state_gene][i] for (i, x) in enumerate(payload.states)); obs_ref = Dict(x.observable_ref.value => gene_vertices[:observable_gene][i] for (i, x) in enumerate(payload.observables))
            symmetry_generator_ref = Dict{Tuple{String,String},Int}()
            for (i, x) in enumerate(payload.symmetries)
                key = (x.generator_ref.id, x.generator_ref.version)
                haskey(symmetry_generator_ref, key) && throw(ArgumentError("symmetry generator reference is not exact"))
                symmetry_generator_ref[key] = gene_vertices[:symmetry_gene][i]
            end
            addref(v, target, label) = invoke(_g1_layer_arc!, Tuple{Vector{Tuple{Int,Int,String}},Int,Int,String}, arcs, v, target, label)
            parameter_ref = Dict(x.ref.value => gene_vertices[:parameter_gene][i] for (i, x) in enumerate(payload.parameters))
            for (ast_vertex, name) in zip(params, names)
                haskey(parameter_ref, name) || throw(ArgumentError("AST parameter has no exact ParameterGene consumer"))
                addref(parameter_ref[name], ast_vertex, "parameter_gene_to_ast_parameter")
            end
            for (i, x) in enumerate(payload.states)
                v = gene_vertices[:state_gene][i]; addref(v, node_ref[x.state_ref.value], "state_gene_to_state_node")
                for r in x.gauge_refs; addref(v, gene_vertices[:symmetry_gene][findfirst(y -> y.ref.value == r.value, payload.symmetries)], "state_gene_to_symmetry"); end
                for p in x.parity_actions
                    key = (p.generator_ref.id, p.generator_ref.version)
                    haskey(symmetry_generator_ref, key) || throw(ArgumentError("state parity action has no exact symmetry generator"))
                    label = layer === :structure ? "state_gene_to_symmetry_parity|cardinality" :
                        "state_gene_to_symmetry_parity|sign=" * (p.sign == even ? "even" : "odd")
                    addref(v, symmetry_generator_ref[key], label)
                end
                for r in x.constraint_refs; addref(v, edge_vertices[edge_ref[r.value]], "state_gene_to_constraint_edge"); end
            end
            for (i, x) in enumerate(payload.invariants)
                v = gene_vertices[:invariant_gene][i]
                if x.scope_ref !== nothing
                    scope_id = x.scope_ref.id
                    node_hits = findall(y -> y.node_id == scope_id, graph.nodes)
                    edge_hits = findall(y -> invoke(_g1_payload_edge_id, Tuple{Any}, y) == scope_id, graph.hyperedges)
                    length(node_hits) + length(edge_hits) == 1 || throw(ArgumentError("invariant scope target is ambiguous or dangling"))
                    target = !isempty(node_hits) ? node_hits[1] : edge_vertices[edge_hits[1]]
                    scope_label = layer === :structure ? "invariant_scope" : "invariant_scope|version=" * _g1_layer_quote(x.scope_ref.version)
                    addref(v, target, scope_label)
                end
                for term in x.terms; tv = invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :invariant_term, layer === :structure ? "invariant_term|cardinality" : "invariant_term|coefficient=" * _g1_transport_rational(term.coefficient)); addref(v, tv, "invariant_term"); addref(tv, state_ref[term.state_ref.value], "term_state"); end
                for r in x.allowed_source_refs; addref(v, edge_vertices[edge_ref[r.value]], "invariant_source"); end
                for r in x.allowed_sink_refs; addref(v, edge_vertices[edge_ref[r.value]], "invariant_sink"); end
                for r in x.boundary_flux_refs; addref(v, edge_vertices[edge_ref[r.value]], "invariant_boundary"); end
            end
            for (i, x) in enumerate(payload.symmetries)
                v = gene_vertices[:symmetry_gene][i]
                for action in x.state_actions; av = invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :symmetry_action, layer === :structure ? "symmetry_action|cardinality" : "symmetry_action|matrix=" * _g1_transport_matrix(action.matrix)); addref(v, av, "symmetry_action"); addref(av, state_ref[action.state_ref.value], "action_state"); end
            end
            for (i, x) in enumerate(payload.observables); addref(gene_vertices[:observable_gene][i], edge_vertices[edge_ref[x.expression_root.operator_site_ref.value]], "observable_expression_root|$(x.expression_root.root_position)"); end
            for (i, x) in enumerate(payload.operator_holes)
                v = gene_vertices[:hole_gene][i]
                for (p, r) in enumerate(x.ordered_input_state_refs); addref(v, state_ref[r.value], "hole_input_state|$(p)"); end
                for r in x.observable_refs; addref(v, obs_ref[r.value], "hole_observable"); end
                for c in x.identifiability_conditions; cv = invoke(_g1_layer_add!, Tuple{Vector{Symbol},Vector{String},Vector{Tuple{Int,Int,String}},Symbol,String}, kinds, colors, arcs, :identifiability_condition, layer === :structure ? "condition|cardinality" : invoke(_g1_transport_condition_color, Tuple{IdentifiabilityConditionV1}, c)); addref(v, cv, "hole_condition"); addref(cv, obs_ref[c.observable_ref.value], "condition_observable"); end
            end
        end
    end
    invoke(_IncidenceGraphV1, Tuple{Any,Any,Any}, Tuple(kinds), Tuple(colors), Tuple(arcs))
end

function _g1_layer_leaf_bytes(ig::_IncidenceGraphV1, colors::Vector{Int}, layer::Symbol, dependencies::String, profile::CanonicalizationProfileV1)
    length(unique(colors)) == length(colors) || throw(ArgumentError("layer leaf is not discrete"))
    order = sortperm(colors); rank = zeros(Int, length(order)); for (new, old) in enumerate(order); rank[old] = new; end
    vertices = "[" * join(("{\"kind\":" * _g1_layer_quote(String(ig.kinds[i])) * ",\"color\":" * _g1_layer_quote(ig.local_colors[i]) * "}" for i in order), ",") * "]"
    arcs = sort!([(rank[s], rank[t], l) for (s, t, l) in ig.arcs])
    arc_text = "[" * join(("{\"label\":" * _g1_layer_quote(a[3]) * ",\"source\":" * string(a[1]) * ",\"target\":" * string(a[2]) * "}" for a in arcs), ",") * "]"
    invoke(_g1_layer_wrap, Tuple{String,String,String}, _g1_layer_domain(layer), dependencies, "{\"arcs\":" * arc_text * ",\"layer\":" * _g1_layer_quote(String(layer)) * ",\"vertices\":" * vertices * "}")
end

function _g1_layer_search(ig::_IncidenceGraphV1, colors::Vector{Int}, layer::Symbol, dependencies::String,
                          profile::CanonicalizationProfileV1, nodes::Base.RefValue{Int}, rounds::Base.RefValue{Int}; initial_partition_pending=false)
    nodes[] += 1; nodes[] <= profile.budget.max_search_nodes || throw(CanonicalizationDeferred("layer search budget exhausted"))
    if initial_partition_pending
        cells = [x for x in _incidence_partition(colors) if length(x) > 1]
        if !isempty(cells)
            sorted_cells = sort(cells, by=x -> (length(x), sort(collect(colors[v] for v in x))))
            target = sorted_cells[1]
            best = nothing
            for vertex in target
                candidate = invoke(_g1_layer_search, Tuple{_IncidenceGraphV1,Vector{Int},Symbol,String,CanonicalizationProfileV1,Base.RefValue{Int},Base.RefValue{Int}}, ig, _incidence_split_color(colors, vertex), layer, dependencies, profile, nodes, rounds; initial_partition_pending=false)
                best === nothing || candidate < best || continue; best = candidate
            end
            return best
        end
    end
    refined = invoke(_incidence_refine, Tuple{_IncidenceGraphV1,Vector{Int},CanonicalizationBudgetV1,Base.RefValue{Int}}, ig, colors, profile.budget, rounds)
    cells = [x for x in _incidence_partition(refined) if length(x) > 1]
    isempty(cells) && return invoke(_g1_layer_leaf_bytes, Tuple{_IncidenceGraphV1,Vector{Int},Symbol,String,CanonicalizationProfileV1}, ig, refined, layer, dependencies, profile)
    sorted_cells = sort(cells, by=x -> (length(x), sort(collect(refined[v] for v in x))))
    target = sorted_cells[1]
    best = nothing
    for vertex in target
        candidate = invoke(_g1_layer_search, Tuple{_IncidenceGraphV1,Vector{Int},Symbol,String,CanonicalizationProfileV1,Base.RefValue{Int},Base.RefValue{Int}}, ig, _incidence_split_color(refined, vertex), layer, dependencies, profile, nodes, rounds; initial_partition_pending=false)
        best === nothing || candidate < best || continue; best = candidate
    end
    best
end

function _g1_layer_canonical(payload::MechanismGenomePayloadV1, layer::Symbol, dependencies::String, profile::CanonicalizationProfileV1)
    ig = invoke(_g1_layer_extended_incidence, Tuple{MechanismGenomePayloadV1,Symbol}, payload, layer)
    length(ig.kinds) <= profile.budget.max_vertices || throw(CanonicalizationDeferred("layer vertex budget exhausted"))
    colors = invoke(_incidence_initial_colors_for_graph, Tuple{_IncidenceGraphV1}, ig)
    bytes = invoke(_g1_layer_search, Tuple{_IncidenceGraphV1,Vector{Int},Symbol,String,CanonicalizationProfileV1,Base.RefValue{Int},Base.RefValue{Int}}, ig, colors, layer, dependencies, profile, Ref(0), Ref(0); initial_partition_pending=true)
    ncodeunits(bytes) <= profile.budget.max_bytes || throw(CanonicalizationDeferred("layer byte budget exhausted"))
    bytes
end

function _g1_layer_wires(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
    contract = invoke(_g1_layer_check_bytes, Tuple{String,CanonicalizationProfileV1}, invoke(_g1_layer_contract_wire, Tuple{GenomeContractRef}, context.contract_ref), context.profile); contract_hash = invoke(_g1_layer_hash, Tuple{String}, contract)
    profile = invoke(_g1_layer_check_bytes, Tuple{String,CanonicalizationProfileV1}, invoke(_g1_layer_profile_wire, Tuple{CanonicalizationProfileV1}, context.profile), context.profile); profile_hash = invoke(_g1_layer_hash, Tuple{String}, profile)
    registry = invoke(_g1_layer_check_bytes, Tuple{String,CanonicalizationProfileV1}, invoke(_g1_layer_registry_wire, Tuple{MechanismGenomePayloadV1}, payload), context.profile); registry_hash = invoke(_g1_layer_hash, Tuple{String}, registry)
    topology = invoke(_g1_layer_canonical, Tuple{MechanismGenomePayloadV1,Symbol,String,CanonicalizationProfileV1}, payload, :topology,
        invoke(_g1_layer_dep, Tuple{Vector{Tuple{String,Digest256}}}, [("contract_hash", contract_hash), ("canonicalization_profile_hash", profile_hash)]), context.profile); topology_hash = invoke(_g1_layer_hash, Tuple{String}, topology)
    operator = invoke(_g1_layer_canonical, Tuple{MechanismGenomePayloadV1,Symbol,String,CanonicalizationProfileV1}, payload, :operator_program,
        invoke(_g1_layer_dep, Tuple{Vector{Tuple{String,Digest256}}}, [("topology_hash", topology_hash), ("operator_registry_hash", registry_hash)]), context.profile); operator_hash = invoke(_g1_layer_hash, Tuple{String}, operator)
    structure = invoke(_g1_layer_canonical, Tuple{MechanismGenomePayloadV1,Symbol,String,CanonicalizationProfileV1}, payload, :structure,
        invoke(_g1_layer_dep, Tuple{Vector{Tuple{String,Digest256}}}, [("operator_program_hash", operator_hash)]), context.profile); structure_hash = invoke(_g1_layer_hash, Tuple{String}, structure)
    decorated = invoke(_g1_layer_canonical, Tuple{MechanismGenomePayloadV1,Symbol,String,CanonicalizationProfileV1}, payload, :decorated,
        invoke(_g1_layer_dep, Tuple{Vector{Tuple{String,Digest256}}}, [("mechanism_structure_hash", structure_hash)]), context.profile); decorated_hash = invoke(_g1_layer_hash, Tuple{String}, decorated)
    # Candidate identity is the already-sealed 4.5a transport.  It is
    # intentionally not a second incidence projection.
    transport = invoke(canonicalize_mechanism_transport,
        Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
    candidate_dependencies = invoke(_g1_layer_dep, Tuple{Vector{Tuple{String,Digest256}}}, [("decorated_mechanism_hash", decorated_hash)])
    candidate_payload = "{\"transport\":" * transport.canonical_bytes * "}"
    candidate = invoke(_g1_layer_check_bytes, Tuple{String,CanonicalizationProfileV1},
        invoke(_g1_layer_wrap, Tuple{String,String,String}, _G1_LAYER_DOMAINS.candidate, candidate_dependencies, candidate_payload), context.profile)
    (contract, profile, registry, topology, operator, structure, decorated, candidate)
end

function mechanism_hash_layers(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
    invoke(MechanismHashLayersV1, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
end
function canonicalize_mechanism(payload::MechanismGenomePayloadV1, context::MechanismCanonicalizationContextV1)
    invoke(CanonicalMechanismV1, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context)
end
canonicalize_mechanism(payload::MechanismGenomePayloadV1, contract_ref::GenomeContractRef; profile::CanonicalizationProfileV1=default_canonicalization_profile()) =
    canonicalize_mechanism(payload, MechanismCanonicalizationContextV1(contract_ref, profile))
mechanism_hash(x::MechanismHashLayersV1) = x.decorated_mechanism_hash
mechanism_hash(x::CanonicalMechanismV1) = x.hashes.decorated_mechanism_hash
