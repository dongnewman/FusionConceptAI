"""Authoritative typed multi-input/multi-output operator hypergraph."""

struct TypedNode
    node_id::String
    node_kind::Symbol
    physical_type::PhysicalType
    label::String
    function TypedNode(node_id::AbstractString, node_kind::Symbol, physical_type::PhysicalType, label::AbstractString)
        new(invoke(_validated_string, Tuple{AbstractString,AbstractString}, node_id, "node_id"), node_kind, physical_type,
            invoke(_validated_string, Tuple{AbstractString,AbstractString}, label, "node label"))
    end
end
semantic_view(x::TypedNode) = (node_kind=x.node_kind, physical_type=x.physical_type)

abstract type AbstractHyperedgeV1 end

struct TypedHyperedge <: AbstractHyperedgeV1
    edge_id::String
    inputs::Tuple{Vararg{Int}}
    outputs::Tuple{Vararg{Int}}
    ast::TypedAST
    role::Symbol
    function TypedHyperedge(id::AbstractString, inputs, outputs, ast::TypedAST, role::Symbol=:additive)
        isempty(inputs) && isempty(outputs) && throw(ArgumentError("hyperedge needs an input or output"))
        length(outputs) == 1 || throw(ArgumentError("P0 supports one AST root output per hyperedge; split multi-output operators"))
        role in (:governing, :additive, :constraint, :interface) || throw(ArgumentError("invalid hyperedge role"))
        new(invoke(_validated_string, Tuple{AbstractString,AbstractString}, id, "edge_id"),
            Tuple(Int(i) for i in inputs), Tuple(Int(i) for i in outputs), ast, role)
    end
end
semantic_view(x::TypedHyperedge) = (inputs=x.inputs, outputs=x.outputs, ast=x.ast, role=x.role)

@enum HyperedgeRoleV1 governing additive constraint interface boundary source sink control event

struct MIMOInputBindingV1
    program_position::Int
    graph_node_index::Int
    function MIMOInputBindingV1(program_position::Integer, graph_node_index::Integer)
        for (value, field) in ((program_position, "program input position"), (graph_node_index, "graph input node index"))
            value isa Bool || value isa Integer || throw(ArgumentError("$field must be an integer"))
            value isa Bool && throw(ArgumentError("$field must not be Bool"))
            typemin(Int) <= value <= typemax(Int) && value >= 1 || throw(ArgumentError("$field is out of range"))
        end
        new(Int(program_position), Int(graph_node_index))
    end
end

struct MIMOOutputBindingV1
    program_position::Int
    graph_node_index::Int
    function MIMOOutputBindingV1(program_position::Integer, graph_node_index::Integer)
        for (value, field) in ((program_position, "program root position"), (graph_node_index, "graph output node index"))
            value isa Bool || value isa Integer || throw(ArgumentError("$field must be an integer"))
            value isa Bool && throw(ArgumentError("$field must not be Bool"))
            typemin(Int) <= value <= typemax(Int) && value >= 1 || throw(ArgumentError("$field is out of range"))
        end
        new(Int(program_position), Int(graph_node_index))
    end
end

struct ConservationAccountRefV1
    account::String
    unit::UnitSignature
    port_side::Symbol
    port_index::Int
    direction::Symbol
    function ConservationAccountRefV1(account::AbstractString, unit::UnitSignature,
                                      port_side::Symbol, port_index::Integer, direction::Symbol)
        !isempty(account) && isvalid(String(account)) || throw(ArgumentError("conservation account is invalid"))
        port_side in (:input, :output) || throw(ArgumentError("account port side must be input or output"))
        direction in (:inflow, :outflow, :minus, :plus) || throw(ArgumentError("account direction is invalid"))
        port_index isa Bool || port_index isa Integer || throw(ArgumentError("account port index must be an integer"))
        port_index isa Bool && throw(ArgumentError("account port index must not be Bool"))
        typemin(Int) <= port_index <= typemax(Int) && port_index >= 1 || throw(ArgumentError("account port index is out of range"))
        new(invoke(_validated_string, Tuple{AbstractString,AbstractString}, account, "conservation account"),
            unit, port_side, Int(port_index), direction)
    end
end

function _exact_effect_coefficient(value)
    typeof(value) <: Rational || throw(ArgumentError("account effect coefficient must be an exact Rational"))
    num, den = getfield(value, :num), getfield(value, :den)
    typeof(num) in _P0_SAFE_INTEGER_TYPES && typeof(den) in _P0_SAFE_INTEGER_TYPES ||
        throw(ArgumentError("account effect coefficient uses an unsafe integer type"))
    value == 0 && throw(ArgumentError("account effect coefficient must be non-zero"))
    try Rational{Int64}(value) catch; throw(ArgumentError("account effect coefficient is out of range")) end
end

struct PortAccountEffectV1
    account_ref::ConservationAccountRefV1
    coefficient::Rational{Int64}
    function PortAccountEffectV1(account_ref::ConservationAccountRefV1, coefficient)
        new(account_ref, invoke(_exact_effect_coefficient, Tuple{Any}, coefficient))
    end
end

struct InterfaceFluxPairV1
    minus::PortAccountEffectV1
    plus::PortAccountEffectV1
    function InterfaceFluxPairV1(minus::PortAccountEffectV1, plus::PortAccountEffectV1)
        a, b = minus.account_ref, plus.account_ref
        a.account == b.account && a.unit == b.unit || throw(ArgumentError("interface pair account/unit mismatch"))
        a.port_side == :output && b.port_side == :output || throw(ArgumentError("interface pair must bind output ports"))
        a.port_index != b.port_index && a.direction != b.direction || throw(ArgumentError("interface pair ports/directions must differ"))
        a.direction === :minus && b.direction === :plus || throw(ArgumentError("interface pair directions must be minus and plus"))
        minus.coefficient < 0 && plus.coefficient > 0 || throw(ArgumentError("interface pair directions must match coefficient signs"))
        minus.coefficient == -plus.coefficient || throw(ArgumentError("interface pair coefficients must be exact opposites"))
        new(minus, plus)
    end
end

semantic_view(x::MIMOInputBindingV1) = (program_position=x.program_position, graph_node_index=x.graph_node_index)
semantic_view(x::MIMOOutputBindingV1) = (program_position=x.program_position, graph_node_index=x.graph_node_index)
semantic_view(x::ConservationAccountRefV1) = (account=x.account, unit=x.unit, port_side=x.port_side,
    port_index=x.port_index, direction=x.direction)
semantic_view(x::PortAccountEffectV1) = (account_ref=x.account_ref, coefficient=x.coefficient)
semantic_view(x::InterfaceFluxPairV1) = (minus=x.minus, plus=x.plus)

const _MIMO_EFFECT_CATEGORIES = (:none, :net_creation, :net_destruction, :redistribution, :interface_flux)

function _mimo_exact_manifest(registry::OperatorRegistryV1, ref::OperatorRefV1, expected_hash::Digest256)
    manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,QualifiedRefV1}, registry, ref.qualified)
    manifest.operator_ref.qualified.id == ref.qualified.id &&
        manifest.operator_ref.qualified.version == ref.qualified.version &&
        manifest.manifest_hash == expected_hash ||
        throw(ArgumentError("MIMO manifest binding does not match the supplied registry"))
    manifest
end

function _mimo_root_manifest(program::TypedASTProgramV1, position::Int, registry::OperatorRegistryV1)
    node = program.nodes[program.roots[position]]
    typeof(node) === ASTApplyV1 || return nothing
    for (ref, hash) in program.used_manifest_bindings
        if ref.qualified.id == node.operator_ref.qualified.id && ref.qualified.version == node.operator_ref.qualified.version
            return invoke(_mimo_exact_manifest, Tuple{OperatorRegistryV1,OperatorRefV1,Digest256}, registry, ref, hash)
        end
    end
    throw(ArgumentError("operator root has no exact manifest binding"))
end

function _mimo_effect_category(effects, pairs)
    !isempty(pairs) && return :interface_flux
    isempty(effects) && return :none
    total = sum((e.coefficient for e in effects); init=0//1)
    total > 0 ? :net_creation : total < 0 ? :net_destruction : :redistribution
end

function _mimo_validate_effects(program::TypedASTProgramV1, ins, outs, role,
                                effects, pairs, registry::OperatorRegistryV1)
    seen = Set{Tuple{Symbol,Int,String}}()
    for effect in effects
        ref = effect.account_ref
        limit = ref.port_side === :input ? length(ins) : ref.port_side === :output ? length(outs) : 0
        1 <= ref.port_index <= limit || throw(ArgumentError("account effect endpoint is outside the MIMO ports"))
        expected_unit = ref.port_side === :input ?
            program.nodes[program.input_ports[ref.port_index]].output_type.units :
            program.nodes[program.roots[ref.port_index]].output_type.units
        expected_unit == ref.unit || throw(ArgumentError("account effect unit does not match program endpoint units"))
        key = (ref.port_side, ref.port_index, ref.account)
        key in seen && throw(ArgumentError("duplicate account effect endpoint"))
        push!(seen, key)
        if ref.direction === :plus || ref.direction === :inflow
            effect.coefficient > 0 || throw(ArgumentError("positive account direction requires a positive coefficient"))
        elseif ref.direction === :minus || ref.direction === :outflow
            effect.coefficient < 0 || throw(ArgumentError("negative account direction requires a negative coefficient"))
        else
            throw(ArgumentError("account effect direction is not closed"))
        end
        if role === source || role === sink
            ref.port_side === :output || throw(ArgumentError("source/sink effects must bind output ports"))
            role === source && (ref.direction === :plus && effect.coefficient > 0 || throw(ArgumentError("source requires positive plus effects")))
            role === sink && (ref.direction === :minus && effect.coefficient < 0 || throw(ArgumentError("sink requires negative minus effects")))
        end
    end
    role === interface && isempty(pairs) && throw(ArgumentError("interface MIMO edge requires a flux pair"))
    role !== interface && !isempty(pairs) && throw(ArgumentError("interface flux pairs require interface role"))
    pair_seen = Set{Tuple{String,Int}}()
    for pair in pairs
        for effect in (pair.minus, pair.plus)
            ref = effect.account_ref
            ref.port_side === :output && 1 <= ref.port_index <= length(outs) ||
                throw(ArgumentError("interface pair endpoint is not an output port"))
            program.nodes[program.roots[ref.port_index]].output_type.units == ref.unit ||
                throw(ArgumentError("interface endpoint unit does not match program output units"))
            endpoint_key = (ref.account, ref.port_index)
            endpoint_key in pair_seen && throw(ArgumentError("interface pair endpoint is duplicated"))
            (:output, ref.port_index, ref.account) in seen && throw(ArgumentError("interface endpoint duplicates an account effect"))
            push!(pair_seen, endpoint_key)
        end
        pair.minus.account_ref.direction === :minus && pair.minus.coefficient < 0 ||
            throw(ArgumentError("interface minus endpoint must be negative"))
        pair.plus.account_ref.direction === :plus && pair.plus.coefficient > 0 ||
            throw(ArgumentError("interface plus endpoint must be positive"))
    end
    role in (source, sink) && isempty(effects) && throw(ArgumentError("source/sink MIMO edge requires account effects"))
    category = invoke(_mimo_effect_category, Tuple{Any,Any}, effects, pairs)
    category in _MIMO_EFFECT_CATEGORIES || throw(ArgumentError("unknown conservation effect category"))
    affected = Set{Int}(e.account_ref.port_index for e in effects if e.account_ref.port_side === :output)
    union!(affected, (p.minus.account_ref.port_index for p in pairs))
    union!(affected, (p.plus.account_ref.port_index for p in pairs))
    if category !== :none
        isempty(affected) && throw(ArgumentError("conservation effect has no output endpoint"))
        for position in sort!(collect(affected))
            manifest = invoke(_mimo_root_manifest, Tuple{TypedASTProgramV1,Int,OperatorRegistryV1}, program, position, registry)
            category in manifest.allowed_conservation_effects ||
                throw(ArgumentError("root manifest does not explicitly allow conservation effect category"))
            category in manifest.forbidden_conservation_effects &&
                throw(ArgumentError("root manifest forbids conservation effect category"))
        end
    end
    nothing
end

struct AtomicMIMOHyperedgeV1 <: AbstractHyperedgeV1
    edge_id::String
    input_bindings::Tuple{Vararg{MIMOInputBindingV1}}
    output_bindings::Tuple{Vararg{MIMOOutputBindingV1}}
    program::TypedASTProgramV1
    program_hash::Digest256
    role::HyperedgeRoleV1
    account_effects::Tuple{Vararg{PortAccountEffectV1}}
    interface_flux_pairs::Tuple{Vararg{InterfaceFluxPairV1}}
    registry::OperatorRegistryV1
    function AtomicMIMOHyperedgeV1(edge_id::AbstractString, input_bindings, output_bindings,
                                   program::TypedASTProgramV1, role::HyperedgeRoleV1;
                                   account_effects=(), interface_flux_pairs=(), registry=nothing)
        !isempty(edge_id) && isvalid(String(edge_id)) || throw(ArgumentError("MIMO edge id is invalid"))
        registry_obj = registry === nothing ? invoke(default_operator_registry, Tuple{}) : registry
        registry_obj isa OperatorRegistryV1 || throw(ArgumentError("MIMO edge registry must be OperatorRegistryV1"))
        ins = try Tuple(input_bindings) catch; throw(ArgumentError("MIMO input bindings must be tuple-like")) end
        outs = try Tuple(output_bindings) catch; throw(ArgumentError("MIMO output bindings must be tuple-like")) end
        effects = try Tuple(account_effects) catch; throw(ArgumentError("account effects must be tuple-like")) end
        pairs = try Tuple(interface_flux_pairs) catch; throw(ArgumentError("interface flux pairs must be tuple-like")) end
        all(typeof(x) === MIMOInputBindingV1 for x in ins) || throw(ArgumentError("MIMO inputs must be typed bindings"))
        all(typeof(x) === MIMOOutputBindingV1 for x in outs) || throw(ArgumentError("MIMO outputs must be typed bindings"))
        all(typeof(x) === PortAccountEffectV1 for x in effects) || throw(ArgumentError("account effects must be typed"))
        all(typeof(x) === InterfaceFluxPairV1 for x in pairs) || throw(ArgumentError("interface pairs must be typed"))
        length(ins) == length(program.input_ports) || throw(ArgumentError("MIMO input count must equal program input ports"))
        length(outs) == length(program.roots) || throw(ArgumentError("MIMO output count must equal program roots"))
        all(x -> 1 <= x.program_position <= length(program.input_ports), ins) ||
            throw(ArgumentError("MIMO input binding is out of program range"))
        all(x -> 1 <= x.program_position <= length(program.roots), outs) ||
            throw(ArgumentError("MIMO output binding is out of program range"))
        input_positions = Tuple(x.program_position for x in ins)
        output_positions = Tuple(x.program_position for x in outs)
        Tuple(sort(collect(input_positions))) == Tuple(1:length(ins)) || throw(ArgumentError("MIMO input bindings must be complete and unique"))
        Tuple(sort(collect(output_positions))) == Tuple(1:length(outs)) || throw(ArgumentError("MIMO output bindings must be complete and unique"))
        length(unique(x.graph_node_index for x in ins)) == length(ins) || throw(ArgumentError("MIMO input node ports must be distinct"))
        length(unique(x.graph_node_index for x in outs)) == length(outs) || throw(ArgumentError("MIMO output node ports must be distinct"))
        role in (governing, additive, constraint, interface, boundary, source, sink, control, event) ||
            throw(ArgumentError("invalid MIMO hyperedge role"))
        for (operator_ref, manifest_hash) in program.used_manifest_bindings
            invoke(_mimo_exact_manifest, Tuple{OperatorRegistryV1,OperatorRefV1,Digest256}, registry_obj, operator_ref, manifest_hash)
        end
        for position in 1:length(outs)
            manifest = invoke(_mimo_root_manifest, Tuple{TypedASTProgramV1,Int,OperatorRegistryV1}, program, position, registry_obj)
            manifest === nothing || (Symbol(role) in manifest.allowed_roles || throw(ArgumentError("MIMO role is not allowed by root operator manifest")))
        end
        invoke(_mimo_validate_effects, Tuple{TypedASTProgramV1,Any,Any,Any,Any,Any,OperatorRegistryV1},
            program, ins, outs, role, effects, pairs, registry_obj)
        new(invoke(_validated_string, Tuple{AbstractString,AbstractString}, edge_id, "MIMO edge id"), ins, outs,
            program, canonical_hash(program), role, effects, pairs, registry_obj)
    end
end

semantic_view(x::AtomicMIMOHyperedgeV1) = (input_bindings=x.input_bindings,
    output_bindings=x.output_bindings, program_hash=x.program_hash, role=x.role,
    account_effects=x.account_effects, interface_flux_pairs=x.interface_flux_pairs)

AtomicMIMOHyperedgeV1(edge::TypedHyperedge; registry=nothing) = begin
    program = TypedASTProgramV1(edge.ast; registry=registry)
    role = edge.role === :governing ? governing : edge.role === :additive ? additive :
        edge.role === :constraint ? constraint : edge.role === :interface ? interface :
        throw(ArgumentError("legacy hyperedge role is not representable"))
    ins = Tuple(MIMOInputBindingV1(i, node_ref) for (i, node_ref) in enumerate(edge.inputs))
    outs = (MIMOOutputBindingV1(1, edge.outputs[1]),)
    AtomicMIMOHyperedgeV1(edge.edge_id, ins, outs, program, role; registry=registry)
end

function _mimo_graph_binding_node(bindings, position::Int, ns, field::String)
    matches = Tuple(b.graph_node_index for b in bindings if b.program_position == position)
    length(matches) == 1 || throw(ArgumentError("$field binding is not complete"))
    index = matches[1]
    1 <= index <= length(ns) || throw(ArgumentError("$field graph node index is out of range"))
    index
end

function _mimo_validate_graph_contract(e::AtomicMIMOHyperedgeV1, ns, registry::OperatorRegistryV1)
    for (ref, manifest_hash) in e.program.used_manifest_bindings
        invoke(_mimo_exact_manifest, Tuple{OperatorRegistryV1,OperatorRefV1,Digest256}, registry, ref, manifest_hash)
    end
    all(b -> 1 <= b.graph_node_index <= length(ns), e.input_bindings) ||
        throw(ArgumentError("MIMO input graph node index is out of range"))
    all(b -> 1 <= b.graph_node_index <= length(ns), e.output_bindings) ||
        throw(ArgumentError("MIMO output graph node index is out of range"))
    all(b -> e.program.nodes[e.program.input_ports[b.program_position]].output_type == ns[b.graph_node_index].physical_type,
        e.input_bindings) || throw(ArgumentError("MIMO input physical type mismatch"))
    all(b -> e.program.nodes[e.program.roots[b.program_position]].output_type == ns[b.graph_node_index].physical_type,
        e.output_bindings) || throw(ArgumentError("MIMO output physical type mismatch"))
    invoke(_mimo_validate_effects, Tuple{TypedASTProgramV1,Any,Any,Any,Any,Any,OperatorRegistryV1},
        e.program, e.input_bindings, e.output_bindings, e.role,
        e.account_effects, e.interface_flux_pairs, registry)
    for effect in e.account_effects
        ref = effect.account_ref
        node_index = ref.port_side === :input ?
            invoke(_mimo_graph_binding_node, Tuple{Any,Int,Any,String}, e.input_bindings, ref.port_index, ns, "input") :
            invoke(_mimo_graph_binding_node, Tuple{Any,Int,Any,String}, e.output_bindings, ref.port_index, ns, "output")
        ns[node_index].physical_type.units == ref.unit ||
            throw(ArgumentError("account effect unit does not match endpoint physical units"))
    end
    for pair in e.interface_flux_pairs
        for effect in (pair.minus, pair.plus)
            ref = effect.account_ref
            node_index = invoke(_mimo_graph_binding_node, Tuple{Any,Int,Any,String}, e.output_bindings, ref.port_index, ns, "interface output")
            ns[node_index].physical_type.units == ref.unit ||
                throw(ArgumentError("interface endpoint unit does not match output physical units"))
        end
    end
    nothing
end

struct TypedOperatorHypergraphV1
    nodes::Tuple{Vararg{TypedNode}}
    hyperedges::Tuple{Vararg{AbstractHyperedgeV1}}
    function TypedOperatorHypergraphV1(nodes, edges; registry=nothing)
        ns, es = Tuple(nodes), Tuple(edges)
        isempty(ns) && throw(ArgumentError("hypergraph needs at least one typed node"))
        all(typeof(x) === TypedNode for x in ns) || throw(ArgumentError("hypergraph nodes must be typed"))
        n = length(ns)
        for e in es
            if typeof(e) === TypedHyperedge
                all(i -> 1 <= i <= n, e.inputs) && all(i -> 1 <= i <= n, e.outputs) || throw(ArgumentError("hyperedge node reference out of range"))
                length(e.ast.input_ports) == length(e.inputs) || throw(ArgumentError("hyperedge inputs must bind ordered AST input ports"))
                all(e.ast.nodes[p].output_type == ns[node_ref].physical_type for (p, node_ref) in zip(e.ast.input_ports, e.inputs)) ||
                    throw(ArgumentError("hyperedge AST input port type mismatch"))
                e.ast.nodes[e.ast.root].output_type == ns[e.outputs[1]].physical_type || throw(ArgumentError("hyperedge AST root/output type mismatch"))
            elseif typeof(e) === AtomicMIMOHyperedgeV1
                graph_registry = registry === nothing ? e.registry : registry
                graph_registry isa OperatorRegistryV1 || throw(ArgumentError("hypergraph registry must be OperatorRegistryV1"))
                _mimo_validate_graph_contract(e, ns, graph_registry)
            else
                throw(ArgumentError("hypergraph contains an unsealed edge kind"))
            end
        end
        new(ns, es)
    end
end
semantic_view(x::TypedOperatorHypergraphV1) = (nodes=x.nodes, hyperedges=x.hyperedges)

node(kind::Symbol, ty::PhysicalType; id="", label="") = TypedNode(String(id), kind, ty, String(label))
