"""Immutable, locally typed ASTs used inside hyperedges."""

struct TypedASTNode
    opcode::Symbol
    inputs::Tuple{Vararg{Int}}
    output_type::PhysicalType
    parameters::NamedTuple
    function TypedASTNode(opcode::Symbol, inputs, output_type::PhysicalType, parameters::NamedTuple=(;))
        opcode in (:state, :parameter, :constant, :identity, :add, :sub, :neg, :mul, :div,
                   :gradient, :divergence, :curl, :dt, :operator_hole) || throw(ArgumentError("unsupported typed AST opcode"))
        all(i -> i >= 1, inputs) || throw(ArgumentError("AST input indexes are one-based"))
        new(opcode, Tuple(Int(i) for i in inputs), output_type, parameters)
    end
end

struct TypedAST
    nodes::Tuple{Vararg{TypedASTNode}}
    root::Int
    input_ports::Tuple{Vararg{Int}}
    function TypedAST(nodes, root::Integer, input_ports=())
        ns = Tuple(nodes)
        isempty(ns) && throw(ArgumentError("typed AST cannot be empty"))
        1 <= root <= length(ns) || throw(ArgumentError("AST root out of range"))
        all(i -> 1 <= i <= length(ns), input_ports) || throw(ArgumentError("AST input port out of range"))
        all(ns[i].opcode in (:state, :parameter, :constant) && isempty(ns[i].inputs) for i in input_ports) ||
            throw(ArgumentError("AST input ports must identify leaf nodes"))
        deep_immutable(ns) || throw(ArgumentError("typed AST payload must be deeply immutable"))
        for (j, n) in enumerate(ns)
            all(i -> i < j, n.inputs) || throw(ArgumentError("AST must be topologically ordered"))
            _validate_opcode(n, ns, j)
        end
        new(ns, Int(root), Tuple(Int(i) for i in input_ports))
    end
end

function _validate_opcode(n::TypedASTNode, ns, j::Int)
    known = (:state, :parameter, :constant, :identity, :add, :sub, :neg, :mul, :div,
             :gradient, :divergence, :curl, :dt, :operator_hole)
    n.opcode in known || throw(ArgumentError("unknown typed AST opcode $(n.opcode)"))
    ins = [ns[i].output_type for i in n.inputs]
    if n.opcode in (:state, :parameter, :constant)
        isempty(ins) || throw(ArgumentError("$(n.opcode) is a leaf opcode"))
    elseif n.opcode == :identity
        length(ins) == 1 && n.output_type == ins[1] || throw(ArgumentError("identity requires one input and unchanged type"))
    elseif n.opcode in (:add, :sub)
        length(ins) >= 2 && all(t -> t == n.output_type, ins) || throw(ArgumentError("ADD/SUB requires same typed inputs and output"))
    elseif n.opcode == :neg
        length(ins) == 1 && n.output_type == ins[1] || throw(ArgumentError("NEG requires one unchanged typed input"))
    elseif n.opcode == :mul
        length(ins) == 2 && all(t -> t.tensor_rank == 0, ins) && n.output_type.tensor_rank == 0 &&
            ins[1].spatial_dimension == ins[2].spatial_dimension && ins[1].time_kind == ins[2].time_kind &&
            n.output_type.spatial_dimension == ins[1].spatial_dimension && n.output_type.time_kind == ins[1].time_kind &&
            n.output_type.units == UnitSignature(ntuple(k -> ins[1].units.exponents[k] + ins[2].units.exponents[k], 7)) ||
            throw(ArgumentError("MUL signature/unit mismatch"))
    elseif n.opcode == :div
        length(ins) == 2 && all(t -> t.tensor_rank == 0, ins) && n.output_type.tensor_rank == 0 &&
            ins[1].spatial_dimension == ins[2].spatial_dimension && ins[1].time_kind == ins[2].time_kind &&
            n.output_type.spatial_dimension == ins[1].spatial_dimension && n.output_type.time_kind == ins[1].time_kind &&
            n.output_type.units == UnitSignature(ntuple(k -> ins[1].units.exponents[k] - ins[2].units.exponents[k], 7)) ||
            throw(ArgumentError("DIV signature/unit mismatch"))
    elseif n.opcode == :gradient
        length(ins) == 1 && ins[1].tensor_rank == 0 && n.output_type.tensor_rank == 1 &&
            n.output_type.units == UnitSignature(ntuple(k -> ins[1].units.exponents[k] - (k == 2 ? 1 : 0), 7)) ||
            throw(ArgumentError("GRADIENT signature/unit mismatch"))
    elseif n.opcode == :divergence
        length(ins) == 1 && ins[1].tensor_rank >= 1 && n.output_type.tensor_rank == ins[1].tensor_rank - 1 &&
            n.output_type.units == UnitSignature(ntuple(k -> ins[1].units.exponents[k] - (k == 2 ? 1 : 0), 7)) ||
            throw(ArgumentError("DIVERGENCE signature/unit mismatch"))
    elseif n.opcode == :curl
        length(ins) == 1 && ins[1].tensor_rank == 1 && n.output_type.tensor_rank == 1 &&
            n.output_type.units == UnitSignature(ntuple(k -> ins[1].units.exponents[k] - (k == 2 ? 1 : 0), 7)) ||
            throw(ArgumentError("CURL signature/unit mismatch"))
    elseif n.opcode == :dt
        length(ins) == 1 && n.output_type == PhysicalType(ins[1].value_kind, ins[1].tensor_rank, ins[1].spatial_dimension, ins[1].time_kind,
            UnitSignature(ntuple(k -> ins[1].units.exponents[k] - (k == 3 ? 1 : 0), 7))) || throw(ArgumentError("DT signature/unit mismatch"))
    end
    nothing
end

ast_leaf(opcode::Symbol, ty::PhysicalType; parameters=(;), input_port=1) = TypedAST((TypedASTNode(opcode, (), ty, parameters),), 1, (input_port,))

semantic_view(x::TypedASTNode) = (opcode=x.opcode, inputs=x.inputs, output_type=x.output_type, parameters=x.parameters)
semantic_view(x::TypedAST) = (nodes=x.nodes, root=x.root, input_ports=x.input_ports)
