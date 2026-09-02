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
    program_port::Int
    node_index::Int
    function MIMOInputBindingV1(program_port::Integer, node_index::Integer)
        for (value, field) in ((program_port, "program input port"), (node_index, "input node index"))
            value isa Bool || value isa Integer || throw(ArgumentError("$field must be an integer"))
            value isa Bool && throw(ArgumentError("$field must not be Bool"))
            typemin(Int) <= value <= typemax(Int) && value >= 1 || throw(ArgumentError("$field is out of range"))
        end
        new(Int(program_port), Int(node_index))
    end
end

struct MIMOOutputBindingV1
    root_position::Int
    node_index::Int
    function MIMOOutputBindingV1(root_position::Integer, node_index::Integer)
        for (value, field) in ((root_position, "program root position"), (node_index, "output node index"))
            value isa Bool || value isa Integer || throw(ArgumentError("$field must be an integer"))
            value isa Bool && throw(ArgumentError("$field must not be Bool"))
            typemin(Int) <= value <= typemax(Int) && value >= 1 || throw(ArgumentError("$field is out of range"))
        end
        new(Int(root_position), Int(node_index))
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
        new(account_ref, _exact_effect_coefficient(coefficient))
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
        minus.coefficient == -plus.coefficient || throw(ArgumentError("interface pair coefficients must be exact opposites"))
        new(minus, plus)
    end
end

semantic_view(x::MIMOInputBindingV1) = (program_port=x.program_port, node_index=x.node_index)
semantic_view(x::MIMOOutputBindingV1) = (root_position=x.root_position, node_index=x.node_index)
semantic_view(x::ConservationAccountRefV1) = (account=x.account, unit=x.unit, port_side=x.port_side,
    port_index=x.port_index, direction=x.direction)
semantic_view(x::PortAccountEffectV1) = (account_ref=x.account_ref, coefficient=x.coefficient)
semantic_view(x::InterfaceFluxPairV1) = (minus=x.minus, plus=x.plus)

struct AtomicMIMOHyperedgeV1 <: AbstractHyperedgeV1
    edge_id::String
    input_bindings::Tuple{Vararg{MIMOInputBindingV1}}
    output_bindings::Tuple{Vararg{MIMOOutputBindingV1}}
    program::TypedASTProgramV1
    program_hash::Digest256
    role::HyperedgeRoleV1
    account_effects::Tuple{Vararg{PortAccountEffectV1}}
    interface_flux_pairs::Tuple{Vararg{InterfaceFluxPairV1}}
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
        all(x -> 1 <= x.program_port <= length(program.input_ports) && 1 <= x.node_index <= length(program.nodes), ins) ||
            throw(ArgumentError("MIMO input binding is out of program range"))
        all(x -> 1 <= x.root_position <= length(program.roots) && 1 <= x.node_index <= length(program.nodes), outs) ||
            throw(ArgumentError("MIMO output binding is out of program range"))
        input_positions = Tuple(x.program_port for x in ins)
        output_positions = Tuple(x.root_position for x in outs)
        Tuple(sort(collect(input_positions))) == Tuple(1:length(ins)) || throw(ArgumentError("MIMO input bindings must be complete and unique"))
        Tuple(sort(collect(output_positions))) == Tuple(1:length(outs)) || throw(ArgumentError("MIMO output bindings must be complete and unique"))
        all(x -> x.node_index == program.input_ports[x.program_port], ins) || throw(ArgumentError("MIMO input binding does not match program input"))
        all(x -> x.node_index == program.roots[x.root_position], outs) || throw(ArgumentError("MIMO output binding does not match program root"))
        length(unique(x.node_index for x in ins)) == length(ins) || throw(ArgumentError("MIMO input node ports must be distinct"))
        length(unique(x.node_index for x in outs)) == length(outs) || throw(ArgumentError("MIMO output node ports must be distinct"))
        role in (governing, additive, constraint, interface, boundary, source, sink, control, event) ||
            throw(ArgumentError("invalid MIMO hyperedge role"))
        role_symbol = Symbol(role)
        for (operator_ref, _) in program.used_manifest_bindings
            manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}},
                registry_obj, operator_ref.qualified.id, operator_ref.qualified.version)
            role_symbol in manifest.allowed_roles || throw(ArgumentError("MIMO role is not allowed by operator manifest"))
        end
        role == interface && isempty(pairs) && throw(ArgumentError("interface MIMO edge requires flux pairs"))
        role in (source, sink) && isempty(effects) && throw(ArgumentError("source/sink MIMO edge requires account effects"))
        role != interface && !isempty(pairs) && throw(ArgumentError("interface flux pairs require interface role"))
        all(p -> p.minus.account_ref.port_index <= length(outs) && p.plus.account_ref.port_index <= length(outs), pairs) ||
            throw(ArgumentError("interface flux pair references an unknown output port"))
        new(invoke(_validated_string, Tuple{AbstractString,AbstractString}, edge_id, "MIMO edge id"), ins, outs,
            program, canonical_hash(program), role, effects, pairs)
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

struct TypedOperatorHypergraphV1
    nodes::Tuple{Vararg{TypedNode}}
    hyperedges::Tuple{Vararg{AbstractHyperedgeV1}}
    function TypedOperatorHypergraphV1(nodes, edges)
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
                all(x -> 1 <= x.node_index <= n, (e.input_bindings..., e.output_bindings...)) ||
                    throw(ArgumentError("MIMO hyperedge node reference out of range"))
                all(e.program.nodes[e.program.input_ports[x.program_port]].output_type == ns[x.node_index].physical_type for x in e.input_bindings) ||
                    throw(ArgumentError("MIMO input physical type mismatch"))
                all(e.program.nodes[e.program.roots[x.root_position]].output_type == ns[x.node_index].physical_type for x in e.output_bindings) ||
                    throw(ArgumentError("MIMO output physical type mismatch"))
            else
                throw(ArgumentError("hypergraph contains an unsealed edge kind"))
            end
        end
        new(ns, es)
    end
end
semantic_view(x::TypedOperatorHypergraphV1) = (nodes=x.nodes, hyperedges=x.hyperedges)

node(kind::Symbol, ty::PhysicalType; id="", label="") = TypedNode(String(id), kind, ty, String(label))
