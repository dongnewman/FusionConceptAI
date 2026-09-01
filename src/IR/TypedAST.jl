"""Immutable, locally typed ASTs used inside hyperedges."""

struct TypedASTNode
    opcode::Symbol
    inputs::Tuple{Vararg{Int}}
    output_type::PhysicalType
    parameters::NamedTuple
    function TypedASTNode(opcode::Symbol, inputs, output_type::PhysicalType, parameters::NamedTuple=(;))
        opcode in (:state, :parameter, :constant, :identity, :add, :sub, :neg, :mul, :div, :dot, :tensor_product, :contract,
                   :gradient, :divergence, :curl, :dt) || throw(ArgumentError("unsupported or unproven typed AST opcode"))
        all(i -> i isa Integer && !isa(i, Bool) && typemin(Int) <= i <= typemax(Int) && i >= 1, inputs) ||
            throw(ArgumentError("AST input indexes must be in-range one-based integers"))
        invoke(_ast_closed_value_valid, Tuple{Any}, parameters) ||
            throw(ArgumentError("AST parameters are not a closed immutable value"))
        new(opcode, Tuple(Int(i) for i in inputs), output_type, parameters)
    end
end

struct TypedAST
    nodes::Tuple{Vararg{TypedASTNode}}
    root::Int
    input_ports::Tuple{Vararg{Int}}
    manifest_bindings::Tuple{Vararg{Tuple{OperatorRefV1,Digest256}}}
    function TypedAST(nodes, root::Integer, input_ports=(); registry=nothing, manifest_bindings=nothing)
        manifest_bindings === nothing || throw(ArgumentError("AST manifest bindings are derived and cannot be caller-supplied"))
        registry_obj = registry === nothing ? invoke(default_operator_registry, Tuple{}) : registry
        registry_obj isa OperatorRegistryV1 || throw(ArgumentError("AST registry must be OperatorRegistryV1"))
        ns = Tuple(nodes)
        isempty(ns) && throw(ArgumentError("typed AST cannot be empty"))
        root isa Bool && throw(ArgumentError("AST root must be an integer"))
        typemin(Int) <= root <= typemax(Int) || throw(ArgumentError("AST root is out of range"))
        1 <= root <= length(ns) || throw(ArgumentError("AST root out of range"))
        all(i -> i isa Integer && !isa(i, Bool) && typemin(Int) <= i <= typemax(Int) && 1 <= i <= length(ns), input_ports) ||
            throw(ArgumentError("AST input port out of range"))
        length(unique(input_ports)) == length(input_ports) || throw(ArgumentError("AST input ports must be unique"))
        all(ns[i].opcode == :state && isempty(ns[i].inputs) for i in input_ports) ||
            throw(ArgumentError("AST input ports must identify external state leaves"))
        state_leaves = [i for i in eachindex(ns) if ns[i].opcode == :state]
        Set(state_leaves) == Set(input_ports) || throw(ArgumentError("every state leaf must be externally bound exactly once"))
        reachable = falses(length(ns))
        function mark(i)
            reachable[i] && return
            reachable[i] = true
            foreach(mark, ns[i].inputs)
        end
        mark(Int(root))
        all(reachable) || throw(ArgumentError("every AST node must be reachable from AST root"))
        invoke(_ast_closed_value_valid, Tuple{Any}, ns) ||
            throw(ArgumentError("typed AST payload is not a closed immutable value"))
        bindings = Tuple{OperatorRefV1,Digest256}[]
        for (j, n) in enumerate(ns)
            all(i -> i < j, n.inputs) || throw(ArgumentError("AST must be topologically ordered"))
            invoke(_validate_ast_node, Tuple{OperatorRegistryV1,TypedASTNode,Any,Int}, registry_obj, n, ns, j)
            if !(n.opcode in (:state, :parameter, :constant))
                id = invoke(_ast_operator_id, Tuple{Symbol}, n.opcode)
                manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}}, registry_obj, id, "v1")
                duplicate = any(b -> b[1].qualified.id === manifest.operator_ref.qualified.id &&
                    b[1].qualified.version === manifest.operator_ref.qualified.version, bindings)
                duplicate || push!(bindings, (manifest.operator_ref, manifest.manifest_hash))
            end
        end
        sort!(bindings, by=b -> (b[1].qualified.id, b[1].qualified.version))
        new(ns, Int(root), Tuple(Int(i) for i in input_ports), Tuple(bindings))
    end
end

"""AST-owned closed value checker; no package-wide trait or semantic dispatch is used."""
function _ast_closed_value_valid(x::Any)
    function visit(x)
        x === nothing && return true
        typeof(x) === String && return isvalid(x)
        Base.ismutabletype(typeof(x)) && !(typeof(x) === String || x isa Symbol) && return false
        x isa AbstractString && return false
        x isa Bool && return true
        x isa Symbol && return isvalid(String(x))
        typeof(x) in _P0_SAFE_INTEGER_TYPES && return true
        typeof(x) in _P0_SAFE_FLOAT_TYPES && return isfinite(Float64(x))
        if x isa Rational
            return typeof(numerator(x)) in _P0_SAFE_INTEGER_TYPES && typeof(denominator(x)) in _P0_SAFE_INTEGER_TYPES
        end
        x isa Enum && return true
        x isa Tuple && return all(visit, x)
        x isa NamedTuple && return all(visit, values(x))
        x isa QualifiedRefV1 && return visit(x.id) && visit(x.version)
        x isa OperatorRefV1 && return visit(x.qualified)
        x isa OperatorParameterSpecV1 && return visit(x.name) && visit(x.type_tag) && visit(x.required)
        x isa Digest256 && return visit(x.value)
        x isa UnitSignature && return visit(x.exponents)
        x isa TemporalTypeV1 && return visit(x.kind) && visit(x.derivative_order) && visit(x.clock_ref)
        x isa PhysicalType && return visit(x.value_kind) && visit(x.tensor_rank) && visit(x.spatial_dimension) &&
            visit(x.temporal_type) && visit(x.units)
        x isa TypedASTNode && return visit(x.opcode) && visit(x.inputs) && visit(x.output_type) && visit(x.parameters)
        false
    end
    visit(x)
end

_ast_operator_id(opcode::Symbol) = opcode == :identity ? "IDENTITY" : opcode == :add ? "ADD" :
    opcode == :sub ? "SUB" : opcode == :neg ? "NEG" : opcode == :mul ? "SCALAR_MUL" :
    opcode == :div ? "SCALAR_DIV" : opcode == :dot ? "DOT" : opcode == :tensor_product ? "TENSOR_PRODUCT" :
    opcode == :contract ? "CONTRACT" : opcode == :dt ? "DT" : opcode == :gradient ? "GRAD" :
    opcode == :divergence ? "DIV_OP" : opcode == :curl ? "CURL" : nothing

function _validate_ast_node(registry::OperatorRegistryV1, n::TypedASTNode, ns, j::Int)
    ins = Tuple(ns[i].output_type for i in n.inputs)
    if n.opcode in (:state, :parameter, :constant)
        isempty(ins) || throw(ArgumentError("$(n.opcode) is a leaf opcode"))
        return nothing
    end
    id = _ast_operator_id(n.opcode)
    id === nothing && throw(ArgumentError("unknown typed AST operator $(n.opcode)"))
    ref = OperatorRefV1(id, "v1")
    rule = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}}, registry, id, "v1").input_type_rule
    inferred = invoke(_sealed_infer_outputs, Tuple{OperatorTypeRuleV1,Any,Any}, rule, ins, n.parameters)
    inferred == (n.output_type,) || throw(ArgumentError("typed AST output does not match registry-derived output"))
    invoke(validate_operator_signature, Tuple{OperatorRegistryV1,OperatorRefV1,Any,Any}, registry, ref,
        ins, (n.output_type,); parameters=n.parameters)
    nothing
end

function ast_leaf(opcode::Symbol, ty::PhysicalType; parameters=(;), input_port=nothing)
    port_tuple = opcode == :state ? (input_port === nothing ? (1,) : (Int(input_port),)) : ()
    TypedAST((TypedASTNode(opcode, (), ty, parameters),), 1, port_tuple)
end

semantic_view(x::TypedASTNode) = (opcode=x.opcode, inputs=x.inputs, output_type=x.output_type, parameters=x.parameters)
semantic_view(x::TypedAST) = (nodes=x.nodes, root=x.root, input_ports=x.input_ports,
    manifest_bindings=x.manifest_bindings)

"""Strongly typed nodes for the registry-validated multi-root AST program IR."""
abstract type AbstractTypedASTNodeV1 end

struct ASTInputV1 <: AbstractTypedASTNodeV1
    port::Int
    output_type::PhysicalType
    parameters::NamedTuple
    function ASTInputV1(port::Integer, output_type::PhysicalType, parameters::NamedTuple=(;))
        typeof(port) in _P0_SAFE_INTEGER_TYPES && !(port isa Bool) ||
            throw(ArgumentError("AST input port must use a safe integer type"))
        typemin(Int) <= port <= typemax(Int) && port >= 1 ||
            throw(ArgumentError("AST input port is out of range"))
        invoke(_ast_closed_value_valid, Tuple{Any}, parameters) ||
            throw(ArgumentError("AST input parameters are not a closed immutable value"))
        new(Int(port), output_type, parameters)
    end
end

struct ASTParameterV1 <: AbstractTypedASTNodeV1
    name::Symbol
    output_type::PhysicalType
    parameters::NamedTuple
    function ASTParameterV1(name::Symbol, output_type::PhysicalType, parameters::NamedTuple=(;))
        !isempty(String(name)) && isvalid(String(name)) || throw(ArgumentError("AST parameter name is invalid"))
        invoke(_ast_closed_value_valid, Tuple{Any}, parameters) ||
            throw(ArgumentError("AST parameter metadata is not a closed immutable value"))
        new(name, output_type, parameters)
    end
end

struct ASTConstantV1 <: AbstractTypedASTNodeV1
    name::Symbol
    value::Any
    output_type::PhysicalType
    parameters::NamedTuple
    function ASTConstantV1(name::Symbol, value, output_type::PhysicalType, parameters::NamedTuple=(;))
        !isempty(String(name)) && isvalid(String(name)) || throw(ArgumentError("AST constant name is invalid"))
        invoke(_ast_closed_value_valid, Tuple{Any}, value) ||
            throw(ArgumentError("AST constant value is not a closed immutable value"))
        invoke(_ast_closed_value_valid, Tuple{Any}, parameters) ||
            throw(ArgumentError("AST constant metadata is not a closed immutable value"))
        new(name, value, output_type, parameters)
    end
end
ASTConstantV1(value, output_type::PhysicalType) = ASTConstantV1(:constant, value, output_type)

struct ASTApplyV1 <: AbstractTypedASTNodeV1
    operator_ref::OperatorRefV1
    inputs::Tuple{Vararg{Int}}
    parameters::NamedTuple
    output_type::PhysicalType
    commutative_input_groups::Tuple
    pure::Bool
    cse_allowed::Bool
    function ASTApplyV1(operator_ref::OperatorRefV1, inputs, parameters::NamedTuple,
                         registry::OperatorRegistryV1, input_types)
        ins = try Tuple(inputs) catch; throw(ArgumentError("AST apply input indexes must be tuple-like")) end
        all(i -> typeof(i) in _P0_SAFE_INTEGER_TYPES && !(i isa Bool) && typemin(Int) <= i <= typemax(Int) && i >= 1, ins) ||
            throw(ArgumentError("AST apply input indexes must be safe positive integers"))
        types = try Tuple(input_types) catch; throw(ArgumentError("AST apply input types must be tuple-like")) end
        length(types) == length(ins) && all(t -> typeof(t) === PhysicalType, types) ||
            throw(ArgumentError("AST apply input types must match input indexes"))
        manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}},
            registry, operator_ref.qualified.id, operator_ref.qualified.version)
        invoke(_sealed_validate_parameters, Tuple{OperatorManifestV1,NamedTuple}, manifest, parameters)
        inferred = invoke(_sealed_infer_outputs, Tuple{OperatorTypeRuleV1,Any,Any},
            manifest.input_type_rule, types, parameters)
        invoke(validate_operator_signature, Tuple{OperatorRegistryV1,OperatorRefV1,Any,Any},
            registry, operator_ref, types, inferred; parameters=parameters)
        new(operator_ref, Tuple(Int(i) for i in ins), parameters, inferred[1],
            manifest.commutative_input_groups, manifest.pure, manifest.cse_allowed)
    end
end

function ASTApplyV1(operator_ref::OperatorRefV1, inputs, parameters::NamedTuple=(;);
                    registry::OperatorRegistryV1, input_types)
    ASTApplyV1(operator_ref, inputs, parameters, registry, input_types)
end

struct TypedASTProgramV1
    nodes::Tuple{Vararg{AbstractTypedASTNodeV1}}
    roots::Tuple{Vararg{Int}}
    input_ports::Tuple{Vararg{Int}}
    used_manifest_bindings::Tuple{Vararg{Tuple{OperatorRefV1,Digest256}}}
    function TypedASTProgramV1(nodes, roots, input_ports, registry::OperatorRegistryV1)
        ns, rs, ps, bindings = invoke(_ast_program_components, Tuple{Any,Any,Any,OperatorRegistryV1},
            nodes, roots, input_ports, registry)
        new(ns, rs, ps, bindings)
    end
end

function _ast_program_output_type(n::AbstractTypedASTNodeV1)
    (typeof(n) === ASTInputV1 || typeof(n) === ASTParameterV1 || typeof(n) === ASTConstantV1 || typeof(n) === ASTApplyV1) ||
        throw(ArgumentError("AST program contains an unsealed node kind"))
    n.output_type
end

function _ast_program_binding_index(bindings, ref::OperatorRefV1)
    for b in bindings
        b[1].qualified.id === ref.qualified.id && b[1].qualified.version === ref.qualified.version && return b
    end
    nothing
end

function _ast_program_cse_key(n::ASTApplyV1, inputs::Tuple, nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    children = [invoke(_ast_program_node_key, Tuple{Any,Any}, nodes[i], Tuple(nodes)) for i in inputs]
    for group in n.commutative_input_groups
        positions = Tuple(Int(i) for i in group)
        values = sort([children[p] for p in positions])
        for (p, value) in zip(positions, values)
            children[p] = value
        end
    end
    _ast_program_canonical((operator_ref=n.operator_ref, manifest_hash=manifest_hash,
        inputs=Tuple(children), parameters=n.parameters, output_type=n.output_type))
end

"""Normalize only proven pure/CSE-safe subexpressions; stateful nodes retain identity."""
function _ast_program_cse_normalize(ns::Tuple, rs::Tuple, registry_obj::OperatorRegistryV1)
    kept = AbstractTypedASTNodeV1[]
    remap = zeros(Int, length(ns))
    seen = Dict{String,Int}()
    root_set = Set(rs)
    for i in eachindex(ns)
        n = ns[i]
        if typeof(n) === ASTApplyV1
            mapped_inputs = Tuple(remap[j] for j in n.inputs)
            candidate = invoke(ASTApplyV1, Tuple{OperatorRefV1,Any,NamedTuple,OperatorRegistryV1,Any},
                n.operator_ref, mapped_inputs, n.parameters, registry_obj,
                Tuple(invoke(_ast_program_output_type, Tuple{AbstractTypedASTNodeV1}, kept[j]) for j in mapped_inputs))
            if n.pure && n.cse_allowed
                manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}},
                    registry_obj, n.operator_ref.qualified.id, n.operator_ref.qualified.version)
                key = invoke(_ast_program_cse_key, Tuple{ASTApplyV1,Tuple,Vector{AbstractTypedASTNodeV1},Digest256},
                    candidate, mapped_inputs, kept, manifest.manifest_hash)
                existing = get(seen, key, 0)
                if existing != 0 && !(i in root_set && existing in root_set)
                    remap[i] = existing
                    continue
                end
                seen[key] = length(kept) + 1
            end
            push!(kept, candidate)
            remap[i] = length(kept)
        else
            push!(kept, n)
            remap[i] = length(kept)
        end
    end
    Tuple(kept), Tuple(remap[r] for r in rs)
end

function _ast_program_components(nodes, roots, input_ports, registry_obj::OperatorRegistryV1)
    ns = Tuple(nodes)
    isempty(ns) && throw(ArgumentError("AST program must contain at least one node"))
    all(n -> typeof(n) === ASTInputV1 || typeof(n) === ASTParameterV1 ||
        typeof(n) === ASTConstantV1 || typeof(n) === ASTApplyV1, ns) ||
        throw(ArgumentError("AST program accepts only closed concrete node kinds"))

    rs = Tuple(roots)
    isempty(rs) && throw(ArgumentError("AST program requires at least one root"))
    all(i -> typeof(i) in _P0_SAFE_INTEGER_TYPES && !(i isa Bool) && typemin(Int) <= i <= typemax(Int) && 1 <= i <= length(ns), rs) ||
        throw(ArgumentError("AST program root is out of range"))
    length(unique(rs)) == length(rs) || throw(ArgumentError("AST program roots must be unique"))
    ps = Tuple(input_ports)
    all(i -> typeof(i) in _P0_SAFE_INTEGER_TYPES && !(i isa Bool) && typemin(Int) <= i <= typemax(Int) && 1 <= i <= length(ns), ps) ||
        throw(ArgumentError("AST program input port declaration is out of range"))
    length(unique(ps)) == length(ps) || throw(ArgumentError("AST program input declarations must be unique"))

    input_nodes = Tuple(i for i in eachindex(ns) if typeof(ns[i]) === ASTInputV1)
    Tuple(sort(collect(input_nodes))) == Tuple(sort(collect(ps))) ||
        throw(ArgumentError("every ASTInput must be declared exactly once in input_ports"))
    input_numbers = Tuple(ns[i].port for i in input_nodes)
    length(unique(input_numbers)) == length(input_numbers) ||
        throw(ArgumentError("AST input port numbers must be unique"))

    reachable = falses(length(ns))
    visiting = falses(length(ns))
    consumed_inputs = falses(length(ns))
    bindings = Tuple{OperatorRefV1,Digest256}[]
    function visit(i)
        1 <= i <= length(ns) || throw(ArgumentError("AST program dependency is out of range"))
        visiting[i] && throw(ArgumentError("AST program contains a cycle"))
        reachable[i] && return
        visiting[i] = true
        n = ns[i]
        if typeof(n) === ASTApplyV1
            all(j -> j < i, n.inputs) || throw(ArgumentError("AST program dependencies must be topologically ordered"))
            all(j -> 1 <= j <= length(ns), n.inputs) || throw(ArgumentError("AST apply dependency is out of range"))
            foreach(visit, n.inputs)
            ins = Tuple(invoke(_ast_program_output_type, Tuple{AbstractTypedASTNodeV1}, ns[j]) for j in n.inputs)
            manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}},
                registry_obj, n.operator_ref.qualified.id, n.operator_ref.qualified.version)
            invoke(_sealed_validate_parameters, Tuple{OperatorManifestV1,NamedTuple}, manifest, n.parameters)
            inferred = invoke(_sealed_infer_outputs, Tuple{OperatorTypeRuleV1,Any,Any}, manifest.input_type_rule, ins, n.parameters)
            inferred[1] == n.output_type || throw(ArgumentError("AST apply output is not registry-derived"))
            n.commutative_input_groups === manifest.commutative_input_groups &&
                n.pure === manifest.pure && n.cse_allowed === manifest.cse_allowed ||
                throw(ArgumentError("AST apply metadata is not manifest-derived"))
            invoke(validate_operator_signature, Tuple{OperatorRegistryV1,OperatorRefV1,Any,Any},
                registry_obj, n.operator_ref, ins, (n.output_type,); parameters=n.parameters)
            for j in n.inputs
                typeof(ns[j]) === ASTInputV1 && (consumed_inputs[j] = true)
            end
            duplicate = any(b -> b[1].qualified.id === manifest.operator_ref.qualified.id &&
                b[1].qualified.version === manifest.operator_ref.qualified.version, bindings)
            duplicate || push!(bindings, (manifest.operator_ref, manifest.manifest_hash))
        elseif typeof(n) === ASTInputV1 || typeof(n) === ASTParameterV1 || typeof(n) === ASTConstantV1
            typeof(n) === ASTInputV1 && any(r -> r == i, rs) && (consumed_inputs[i] = true)
            nothing
        end
        visiting[i] = false
        reachable[i] = true
    end
    foreach(visit, rs)
    all(reachable) || throw(ArgumentError("every AST program node must be reachable from a root"))
    all(i -> consumed_inputs[i], input_nodes) || throw(ArgumentError("every ASTInput must be consumed by an apply node"))
    sort!(bindings, by=b -> (b[1].qualified.id, b[1].qualified.version))
    normalized_nodes, normalized_roots = invoke(_ast_program_cse_normalize,
        Tuple{Tuple,Tuple,OperatorRegistryV1}, ns, Tuple(Int(i) for i in rs), registry_obj)
    (normalized_nodes, normalized_roots, Tuple(Int(i) for i in ps), Tuple(bindings))
end

function TypedASTProgramV1(nodes, roots, input_ports=(); registry=nothing, used_manifest_bindings=nothing)
    used_manifest_bindings === nothing ||
        throw(ArgumentError("AST program manifest bindings are derived and cannot be caller-supplied"))
    registry_obj = registry === nothing ? invoke(default_operator_registry, Tuple{}) : registry
    registry_obj isa OperatorRegistryV1 || throw(ArgumentError("AST program registry must be OperatorRegistryV1"))
    TypedASTProgramV1(nodes, roots, input_ports, registry_obj)
end

function _ast_program_node_payload(n, refs, nodes)
    if typeof(n) === ASTInputV1
        return (kind=:input, port=n.port, parameters=n.parameters, output_type=n.output_type)
    elseif typeof(n) === ASTParameterV1
        return (kind=:parameter, parameters=n.parameters, output_type=n.output_type)
    elseif typeof(n) === ASTConstantV1
        return (kind=:constant, value=n.value, parameters=n.parameters, output_type=n.output_type)
    elseif typeof(n) === ASTApplyV1
        input_refs = [refs[i] for i in n.inputs]
        if n.pure && n.cse_allowed
            for group in n.commutative_input_groups
                positions = Tuple(Int(i) for i in group)
                permutation = sortperm(collect(eachindex(positions)), by=k ->
                    invoke(_ast_program_node_key, Tuple{Any,Any}, nodes[n.inputs[positions[k]]], nodes))
                for (k, position) in enumerate(positions)
                    source_position = positions[permutation[k]]
                    input_refs[position] = refs[n.inputs[source_position]]
                end
            end
        end
        return (kind=:apply, operator_ref=n.operator_ref, inputs=Tuple(input_refs),
            output_type=n.output_type, parameters=n.parameters)
    end
    throw(CanonicalizationDeferred("AST program node canonicalization is outside the P0 proof boundary"))
end

function _ast_program_node_key(n, nodes)
    if typeof(n) === ASTInputV1
        return "input|" * string(n.port) * "|" * _ast_program_canonical(n.parameters) * "|" * _ast_program_canonical(n.output_type)
    elseif typeof(n) === ASTParameterV1
        return "parameter|" * _ast_program_canonical(n.parameters) * "|" * _ast_program_canonical(n.output_type)
    elseif typeof(n) === ASTConstantV1
        return "constant|" * _ast_program_canonical((value=n.value, parameters=n.parameters, output_type=n.output_type))
    elseif typeof(n) === ASTApplyV1
        children = [invoke(_ast_program_node_key, Tuple{Any,Any}, nodes[i], nodes) for i in n.inputs]
        if n.pure && n.cse_allowed
            for group in n.commutative_input_groups
                positions = Tuple(Int(i) for i in group)
                vals = sort([children[p] for p in positions])
                for (p, v) in zip(positions, vals); children[p] = v; end
            end
        end
        return "apply|" * _ast_program_canonical(n.operator_ref) * "|" * join(children, ",") * "|" * _ast_program_canonical(n.output_type) * "|" * _ast_program_canonical(n.parameters)
    end
    throw(CanonicalizationDeferred("AST program node key is outside the P0 proof boundary"))
end

"""Closed encoder for program identity; it does not dispatch through package extensible canonical helpers."""
function _ast_program_canonical(x)
    function encode(value)
        value === nothing && return "null"
        typeof(value) === String && return invoke(_jsonquote, Tuple{AbstractString}, value)
        value isa Bool && return value ? "true" : "false"
        value isa Symbol && (isvalid(String(value)) || throw(ArgumentError("invalid AST symbol")); return invoke(_jsonquote, Tuple{AbstractString}, String(value)))
        typeof(value) in _P0_SAFE_INTEGER_TYPES && return string(value)
        if typeof(value) in _P0_SAFE_FLOAT_TYPES
            return invoke(_canonical_float, Tuple{AbstractFloat}, value)
        end
        if value isa Rational
            num, den = getfield(value, :num), getfield(value, :den)
            typeof(num) in _P0_SAFE_INTEGER_TYPES && typeof(den) in _P0_SAFE_INTEGER_TYPES ||
                throw(ArgumentError("AST rational is not a closed value"))
            return "{\"denominator\":" * encode(den) * ",\"numerator\":" * encode(num) * "}"
        end
        value isa Enum && return invoke(_jsonquote, Tuple{AbstractString}, String(Symbol(value)))
        if value isa NamedTuple
            names = [String(k) for k in keys(value)]
            length(unique(names)) == length(names) || throw(ArgumentError("AST object has duplicate keys"))
            order = sortperm(names)
            return "{" * join((invoke(_jsonquote, Tuple{AbstractString}, names[i]) * ":" * encode(getfield(value, keys(value)[i])) for i in order), ",") * "}"
        end
        value isa Tuple && return "[" * join((encode(v) for v in value), ",") * "]"
        if typeof(value) === QualifiedRefV1
            return encode((id=getfield(value, :id), version=getfield(value, :version)))
        elseif typeof(value) === OperatorRefV1
            return encode((qualified=getfield(value, :qualified),))
        elseif typeof(value) === Digest256
            return encode((value=getfield(value, :value),))
        elseif typeof(value) === UnitSignature
            return encode((exponents=getfield(value, :exponents),))
        elseif typeof(value) === TemporalTypeV1
            return encode((kind=getfield(value, :kind), derivative_order=getfield(value, :derivative_order), clock_ref=getfield(value, :clock_ref)))
        elseif typeof(value) === PhysicalType
            return encode((value_kind=getfield(value, :value_kind), tensor_rank=getfield(value, :tensor_rank),
                spatial_dimension=getfield(value, :spatial_dimension), temporal_type=getfield(value, :temporal_type),
                units=getfield(value, :units)))
        elseif typeof(value) === OperatorParameterSpecV1
            return encode((name=getfield(value, :name), type_tag=getfield(value, :type_tag), required=getfield(value, :required)))
        end
        throw(ArgumentError("AST canonical payload contains an unsealed value"))
    end
    encode(x)
end

function _ast_program_semantic_payload(program::TypedASTProgramV1)
    n = length(program.nodes)
    perms = _all_permutations(n)
    perms === nothing && throw(CanonicalizationDeferred("AST program exact canonicalization exceeds the P0 proof boundary"))
    best = nothing
    best_text = nothing
    for order in perms
        refs = zeros(Int, n)
        for (new, old) in enumerate(order); refs[old] = new; end
        records = Tuple(invoke(_ast_program_node_payload, Tuple{Any,Any,Any}, program.nodes[old], refs, program.nodes) for old in order)
        roots = Tuple(refs[r] for r in program.roots)
        declarations = Tuple(sort([(port=program.nodes[i].port, node=refs[i]) for i in program.input_ports], by=x -> x.port))
        candidate = (nodes=records, roots=roots, input_ports=declarations,
            used_manifest_bindings=program.used_manifest_bindings)
        text = _ast_program_canonical(candidate)
        if best_text === nothing || text < best_text
            best, best_text = candidate, text
        end
    end
    best
end

semantic_view(x::ASTInputV1) = (port=x.port, parameters=x.parameters, output_type=x.output_type)
semantic_view(x::ASTParameterV1) = (parameters=x.parameters, output_type=x.output_type)
semantic_view(x::ASTConstantV1) = (value=x.value, parameters=x.parameters, output_type=x.output_type)
semantic_view(x::ASTApplyV1) = (operator_ref=x.operator_ref, inputs=x.inputs, parameters=x.parameters, output_type=x.output_type)
semantic_view(x::TypedASTProgramV1) = _ast_program_semantic_payload(x)

"""Lossless compatibility bridge from the validated single-root TypedAST."""
function TypedASTProgramV1(ast::TypedAST; registry=nothing)
    registry_obj = registry === nothing ? invoke(default_operator_registry, Tuple{}) : registry
    registry_obj isa OperatorRegistryV1 || throw(ArgumentError("AST registry must be OperatorRegistryV1"))
    old = ast.nodes
    converted = AbstractTypedASTNodeV1[]
    for (i, n) in enumerate(old)
        if n.opcode === :state
            push!(converted, ASTInputV1(i, n.output_type, n.parameters))
        elseif n.opcode === :parameter
            parameter_name = hasproperty(n.parameters, :name) ? getproperty(n.parameters, :name) : Symbol("parameter_", i)
            parameter_name isa Symbol || throw(ArgumentError("legacy parameter name is not representable"))
            push!(converted, ASTParameterV1(parameter_name, n.output_type, n.parameters))
        elseif n.opcode === :constant
            hasproperty(n.parameters, :value) || throw(ArgumentError("legacy constant has no losslessly representable value"))
            value = getproperty(n.parameters, :value)
            push!(converted, ASTConstantV1(Symbol("constant_", i), value, n.output_type, n.parameters))
        else
            ins = Tuple(invoke(_ast_program_output_type, Tuple{AbstractTypedASTNodeV1}, converted[j]) for j in n.inputs)
            ref = OperatorRefV1(invoke(_ast_operator_id, Tuple{Symbol}, n.opcode), "v1")
            push!(converted, ASTApplyV1(ref, n.inputs, n.parameters; registry=registry_obj, input_types=ins))
        end
    end
    program = TypedASTProgramV1(Tuple(converted), (ast.root,), ast.input_ports; registry=registry_obj)
    old_bindings, new_bindings = ast.manifest_bindings, program.used_manifest_bindings
    length(old_bindings) == length(new_bindings) || throw(ArgumentError("legacy AST manifest binding cannot be losslessly mapped"))
    for (old_binding, new_binding) in zip(old_bindings, new_bindings)
        old_binding[1].qualified.id == new_binding[1].qualified.id &&
            old_binding[1].qualified.version == new_binding[1].qualified.version &&
            old_binding[2].value == new_binding[2].value ||
            throw(ArgumentError("legacy AST manifest binding differs from target registry"))
    end
    program
end

typed_ast_program(ast::TypedAST; registry=nothing) = TypedASTProgramV1(ast; registry=registry)
