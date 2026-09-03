"""Closed canonical identity for `TypedASTProgramV1`.

The semantic projection remains the AST-owned projection, but every identity
operation below writes directly to bytes and reads only sealed fields.  This
keeps AST canonicalization independent of package-level `string`, iteration,
ordering, and canonical-dispatch extensions.
"""

function _tac_text_less(a::String, b::String)
    na = Core.sizeof(a)
    nb = Core.sizeof(b)
    common = na < nb ? na : nb
    GC.@preserve a b begin
        pa = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), a)
        pb = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), b)
        i = 1
        while i <= common
            xa = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pa, i)
            xb = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pb, i)
            xa < xb && return true
            xa > xb && return false
            i += 1
        end
    end
    na < nb
end

function _tac_string_less(a::AbstractString, b::AbstractString)
    aa = typeof(a) === String ? a : invoke(String, Tuple{AbstractString}, a)
    bb = typeof(b) === String ? b : invoke(String, Tuple{AbstractString}, b)
    _tac_text_less(aa, bb)
end

function _tac_write_float!(io::Base.GenericIOBuffer, value::AbstractFloat)
    x = Float64(value)
    isfinite(x) || throw(ArgumentError("non-finite AST float is not canonical"))
    x == 0.0 && return _ccbw_ascii!(io, "0.0")
    text = invoke(Base.Ryu.writeshortest, Tuple{Float64}, x)
    text isa String || throw(ArgumentError("closed float formatter returned an unsealed value"))
    _ccbw_ascii!(io, text)
end

function _tac_write_raw!(io::Base.GenericIOBuffer, value::String)
    _ccbw_utf8!(io, value)
end

function _tac_write_key!(io::Base.GenericIOBuffer, value::Symbol)
    text = invoke(String, Tuple{Symbol}, value)
    _ccbw_quote!(io, text)
end

function _tac_write_enum!(io::Base.GenericIOBuffer, value::Enum)
    if typeof(value) === TimeKindV1
        if value === static_time
            _ccbw_quote!(io, "static_time")
        elseif value === algebraic_time
            _ccbw_quote!(io, "algebraic_time")
        elseif value === differential_time
            _ccbw_quote!(io, "differential_time")
        elseif value === discrete_time
            _ccbw_quote!(io, "discrete_time")
        elseif value === event_time
            _ccbw_quote!(io, "event_time")
        else
            throw(ArgumentError("unknown AST time kind"))
        end
    else
        symbol = invoke(Symbol, Tuple{Enum}, value)
        _ccbw_quote!(io, invoke(String, Tuple{Symbol}, symbol))
    end
end

function _tac_write_rational!(io::Base.GenericIOBuffer, value::Rational)
    num = getfield(value, :num)
    den = getfield(value, :den)
    _ccbw_ascii!(io, "{\"denominator\":")
    _tac_write_value!(io, den)
    _ccbw_ascii!(io, ",\"numerator\":")
    _tac_write_value!(io, num)
    _ccbw_byte!(io, UInt8('}'))
end

function _tac_write_namedtuple!(io::Base.GenericIOBuffer, value::NamedTuple)
    n = fieldcount(typeof(value))
    order = Vector{Int}(undef, n)
    i = 1
    while i <= n
        Core.arrayset(true, order, i, i)
        i += 1
    end
    i = 2
    while i <= n
        current = Core.arrayref(true, order, i)
        current_name = invoke(String, Tuple{Symbol}, fieldname(typeof(value), current))
        j = i - 1
        while j >= 1
            prior = Core.arrayref(true, order, j)
            prior_name = invoke(String, Tuple{Symbol}, fieldname(typeof(value), prior))
            _tac_text_less(current_name, prior_name) || break
            Core.arrayset(true, order, prior, j + 1)
            j -= 1
        end
        Core.arrayset(true, order, current, j + 1)
        i += 1
    end
    _ccbw_byte!(io, UInt8('{'))
    i = 1
    while i <= n
        i > 1 && _ccbw_byte!(io, UInt8(','))
        index = Core.arrayref(true, order, i)
        _ccbw_quote!(io, invoke(String, Tuple{Symbol}, fieldname(typeof(value), index)))
        _ccbw_byte!(io, UInt8(':'))
        _tac_write_value!(io, getfield(value, index))
        i += 1
    end
    _ccbw_byte!(io, UInt8('}'))
end

function _tac_write_value!(io::Base.GenericIOBuffer, value::Any)
    value === nothing && return _ccbw_ascii!(io, "null")
    typeof(value) === String && return _ccbw_quote!(io, value)
    value isa Bool && return _ccbw_ascii!(io, value ? "true" : "false")
    value isa Symbol && return _tac_write_key!(io, value)
    (typeof(value) === Int8 || typeof(value) === Int16 || typeof(value) === Int32 ||
        typeof(value) === Int64 || typeof(value) === Int128 || typeof(value) === UInt8 ||
        typeof(value) === UInt16 || typeof(value) === UInt32 || typeof(value) === UInt64 ||
        typeof(value) === UInt128) && return _ccbw_integer!(io, value)
    (typeof(value) === Float16 || typeof(value) === Float32 || typeof(value) === Float64) &&
        return _tac_write_float!(io, value)
    value isa Rational && return _tac_write_rational!(io, value)
    value isa Enum && return _tac_write_enum!(io, value)
    value isa NamedTuple && return _tac_write_namedtuple!(io, value)
    value isa Tuple && begin
        n = fieldcount(typeof(value))
        _ccbw_byte!(io, UInt8('['))
        i = 1
        while i <= n
            i > 1 && _ccbw_byte!(io, UInt8(','))
            _tac_write_value!(io, getfield(value, i))
            i += 1
        end
        _ccbw_byte!(io, UInt8(']'))
        return io
    end
    if typeof(value) === QualifiedRefV1
        return _tac_write_namedtuple!(io, (id=getfield(value, :id), version=getfield(value, :version)))
    elseif typeof(value) === OperatorRefV1
        return _tac_write_namedtuple!(io, (qualified=getfield(value, :qualified),))
    elseif typeof(value) === Digest256
        return _tac_write_namedtuple!(io, (value=getfield(value, :value),))
    elseif typeof(value) === UnitSignature
        return _tac_write_namedtuple!(io, (exponents=getfield(value, :exponents),))
    elseif typeof(value) === TemporalTypeV1
        return _tac_write_namedtuple!(io, (kind=getfield(value, :kind),
            derivative_order=getfield(value, :derivative_order), clock_ref=getfield(value, :clock_ref)))
    elseif typeof(value) === PhysicalType
        return _tac_write_namedtuple!(io, (value_kind=getfield(value, :value_kind),
            tensor_rank=getfield(value, :tensor_rank), spatial_dimension=getfield(value, :spatial_dimension),
            temporal_type=getfield(value, :temporal_type), units=getfield(value, :units)))
    elseif typeof(value) === OperatorParameterSpecV1
        return _tac_write_namedtuple!(io, (name=getfield(value, :name), type_tag=getfield(value, :type_tag),
            required=getfield(value, :required)))
    end
    throw(ArgumentError("AST canonical payload contains an unsealed value"))
end

function _tac_value_string(value::Any)
    io = _ccbw_new()
    _tac_write_value!(io, value)
    _ccbw_finish(io)
end

function _tac_node_at(nodes::Any, index::Int)
    if nodes isa Tuple
        return getfield(nodes, index)
    elseif nodes isa Vector{AbstractTypedASTNodeV1}
        return Core.arrayref(true, nodes, index)
    end
    throw(ArgumentError("AST node table is not sealed"))
end

function _tac_node_key(n::AbstractTypedASTNodeV1, nodes::Any)
    io = _ccbw_new()
    if typeof(n) === ASTInputV1
        _ccbw_ascii!(io, "input|"); _ccbw_integer!(io, Int64(getfield(n, :port))); _ccbw_ascii!(io, "|")
        _tac_write_value!(io, getfield(n, :parameters)); _ccbw_ascii!(io, "|"); _tac_write_value!(io, getfield(n, :output_type))
    elseif typeof(n) === ASTParameterV1
        _ccbw_ascii!(io, "parameter|"); _tac_write_value!(io, getfield(n, :parameters)); _ccbw_ascii!(io, "|"); _tac_write_value!(io, getfield(n, :output_type))
    elseif typeof(n) === ASTConstantV1
        _ccbw_ascii!(io, "constant|"); _tac_write_value!(io, (value=getfield(n, :value), parameters=getfield(n, :parameters), output_type=getfield(n, :output_type)))
    elseif typeof(n) === ASTApplyV1
        _ccbw_ascii!(io, "apply|"); _tac_write_value!(io, getfield(n, :operator_ref)); _ccbw_ascii!(io, "|")
        inputs = getfield(n, :inputs); ni = fieldcount(typeof(inputs)); children = Vector{String}(undef, ni); i = 1
        while i <= ni
            child = getfield(inputs, i)
            Core.arrayset(true, children, invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any},
                invoke(_tac_node_at, Tuple{Any,Int}, nodes, child), nodes), i)
            i += 1
        end
        _tac_commutative_children!(children, ni, getfield(n, :commutative_input_groups))
        i = 1
        while i <= ni
            i > 1 && _ccbw_byte!(io, UInt8(',')); _ccbw_utf8!(io, Core.arrayref(true, children, i)); i += 1
        end
        _ccbw_ascii!(io, "|"); _tac_write_value!(io, getfield(n, :output_type)); _ccbw_ascii!(io, "|"); _tac_write_value!(io, getfield(n, :parameters))
    else
        throw(CanonicalizationDeferred("AST program node key is outside the P0 proof boundary"))
    end
    _ccbw_finish(io)
end

function _tac_commutative_children!(children::Vector{String}, child_count::Int, groups::Tuple)
    ng = fieldcount(typeof(groups)); g = 1
    while g <= ng
        positions = getfield(groups, g)
        np = fieldcount(typeof(positions)); sorted = Vector{String}(undef, np)
        p = 1
        while p <= np
            position = getfield(positions, p)
            Core.arrayset(true, sorted, Core.arrayref(true, children, position), p)
            p += 1
        end
        p = 2
        while p <= np
            current = Core.arrayref(true, sorted, p); j = p - 1
            while j >= 1 && _tac_text_less(current, Core.arrayref(true, sorted, j))
                Core.arrayset(true, sorted, Core.arrayref(true, sorted, j), j + 1); j -= 1
            end
            Core.arrayset(true, sorted, current, j + 1); p += 1
        end
        p = 1
        while p <= np
            position = getfield(positions, p); Core.arrayset(true, children, Core.arrayref(true, sorted, p), position); p += 1
        end
        g += 1
    end
    children
end

function _tac_node_payload(n::AbstractTypedASTNodeV1, refs::Vector{Int}, nodes::Tuple)
    if typeof(n) === ASTInputV1
        return (kind=:input, port=getfield(n, :port), parameters=getfield(n, :parameters), output_type=getfield(n, :output_type))
    elseif typeof(n) === ASTParameterV1
        return (kind=:parameter, parameters=getfield(n, :parameters), output_type=getfield(n, :output_type))
    elseif typeof(n) === ASTConstantV1
        return (kind=:constant, value=getfield(n, :value), parameters=getfield(n, :parameters), output_type=getfield(n, :output_type))
    elseif typeof(n) === ASTApplyV1
        inputs = getfield(n, :inputs); ni = fieldcount(typeof(inputs)); input_refs = Vector{Int}(undef, ni)
        i = 1
        while i <= ni
            Core.arrayset(true, input_refs, Core.arrayref(true, refs, getfield(inputs, i)), i); i += 1
        end
        groups = getfield(n, :commutative_input_groups); ng = fieldcount(typeof(groups)); g = 1
        while g <= ng
            positions = getfield(groups, g); np = fieldcount(typeof(positions)); values = Vector{Int}(undef, np); p = 1
            while p <= np
                Core.arrayset(true, values, getfield(inputs, getfield(positions, p)), p); p += 1
            end
            p = 2
            while p <= np
                current = Core.arrayref(true, values, p); j = p - 1
                while j >= 1 && _tac_text_less(invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any},
                    invoke(_tac_node_at, Tuple{Any,Int}, nodes, current), nodes), invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any},
                    invoke(_tac_node_at, Tuple{Any,Int}, nodes, Core.arrayref(true, values, j)), nodes))
                    Core.arrayset(true, values, Core.arrayref(true, values, j), j + 1); j -= 1
                end
                Core.arrayset(true, values, current, j + 1); p += 1
            end
            p = 1
            while p <= np
                position = getfield(positions, p); source = Core.arrayref(true, values, p)
                Core.arrayset(true, input_refs, Core.arrayref(true, refs, source), position); p += 1
            end
            g += 1
        end
        return (kind=:apply, operator_ref=getfield(n, :operator_ref), inputs=ntuple(i -> Core.arrayref(true, input_refs, i), ni),
            output_type=getfield(n, :output_type), parameters=getfield(n, :parameters))
    end
    throw(CanonicalizationDeferred("AST program node canonicalization is outside the P0 proof boundary"))
end

# Private graph-orbit payload projection.  Its commutative-group tie breaker
# includes the mapped position, so equal intrinsic child keys do not retain
# source-tuple order (the public AST v1 projection above remains untouched).
function _tac_graph_node_payload(n::AbstractTypedASTNodeV1, refs::Vector{Int}, nodes::Tuple)
    typeof(n) === ASTInputV1 && return (kind=:input, port=getfield(n, :port),
        parameters=getfield(n, :parameters), output_type=getfield(n, :output_type))
    typeof(n) === ASTParameterV1 && return (kind=:parameter,
        parameters=getfield(n, :parameters), output_type=getfield(n, :output_type))
    typeof(n) === ASTConstantV1 && return (kind=:constant, value=getfield(n, :value),
        parameters=getfield(n, :parameters), output_type=getfield(n, :output_type))
    typeof(n) === ASTApplyV1 || throw(CanonicalizationDeferred("AST graph orbit node is outside the closed boundary"))
    inputs = getfield(n, :inputs); ni = fieldcount(typeof(inputs)); input_refs = Vector{Int}(undef, ni)
    i = 1
    while i <= ni
        Core.arrayset(true, input_refs, Core.arrayref(true, refs, getfield(inputs, i)), i); i += 1
    end
    groups = getfield(n, :commutative_input_groups); ng = fieldcount(typeof(groups)); g = 1
    while g <= ng
        positions = getfield(groups, g); np = fieldcount(typeof(positions))
        values = Vector{Int}(undef, np); p = 1
        while p <= np
            position = getfield(positions, p)
            Core.arrayset(true, values, getfield(inputs, position), p); p += 1
        end
        p = 2
        while p <= np
            current = Core.arrayref(true, values, p); current_mapped = Core.arrayref(true, refs, current); j = p - 1
            while j >= 1
                prior = Core.arrayref(true, values, j); prior_mapped = Core.arrayref(true, refs, prior)
                current_key = invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any},
                    invoke(_tac_node_at, Tuple{Any,Int}, nodes, current), nodes)
                prior_key = invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any},
                    invoke(_tac_node_at, Tuple{Any,Int}, nodes, prior), nodes)
                move = invoke(_tac_text_less, Tuple{String,String}, current_key, prior_key)
                !move && invoke(_tac_text_equal, Tuple{String,String}, current_key, prior_key) &&
                    (move = invoke(isless, Tuple{Int,Int}, current_mapped, prior_mapped))
                move || break
                Core.arrayset(true, values, prior, j + 1); j -= 1
            end
            Core.arrayset(true, values, current, j + 1); p += 1
        end
        p = 1
        while p <= np
            position = getfield(positions, p); source = Core.arrayref(true, values, p)
            Core.arrayset(true, input_refs, Core.arrayref(true, refs, source), position); p += 1
        end
        g += 1
    end
    (kind=:apply, operator_ref=getfield(n, :operator_ref),
        inputs=ntuple(i -> Core.arrayref(true, input_refs, i), ni),
        output_type=getfield(n, :output_type), parameters=getfield(n, :parameters))
end

function _tac_permutations(n::Int)
    n <= 8 || throw(CanonicalizationDeferred("AST program exact canonicalization exceeds the P0 proof boundary"))
    total = 1; i = 2
    while i <= n; total *= i; i += 1; end
    out = Vector{Tuple{Vararg{Int}}}(undef, total); work = Vector{Int}(undef, n)
    i = 1; while i <= n; Core.arrayset(true, work, i, i); i += 1; end
    counter = Ref(0)
    function visit(k)
        if k > n
            counter[] += 1
            Core.arrayset(true, out, ntuple(j -> Core.arrayref(true, work, j), n), counter[])
            return nothing
        end
        j = k
        while j <= n
            a = Core.arrayref(true, work, k); b = Core.arrayref(true, work, j)
            Core.arrayset(true, work, b, k); Core.arrayset(true, work, a, j)
            visit(k + 1)
            Core.arrayset(true, work, a, k)
            Core.arrayset(true, work, b, j)
            j += 1
        end
        nothing
    end
    visit(1)
    out
end

function _tac_program_payload(program::TypedASTProgramV1)
    nodes = getfield(program, :nodes); roots = getfield(program, :roots); ports = getfield(program, :input_ports)
    n = fieldcount(typeof(nodes)); perms = _tac_permutations(n); total = 1; factorial_i = 2
    while factorial_i <= n; total *= factorial_i; factorial_i += 1; end
    best = nothing; best_text = nothing
    pi = 1
    while pi <= total
        order = Core.arrayref(true, perms, pi)
        candidate, _ = invoke(_tac_candidate_for_order, Tuple{TypedASTProgramV1,Tuple{Vararg{Int}}}, program, order)
        text = invoke(_tac_value_string, Tuple{Any}, candidate)
        if best_text === nothing || invoke(_tac_string_less, Tuple{AbstractString,AbstractString}, text, best_text)
            best = candidate; best_text = text
        end
        pi += 1
    end
    best
end

function _tac_candidate_for_order(program::TypedASTProgramV1, order::Tuple{Vararg{Int}})
    nodes = getfield(program, :nodes); roots = getfield(program, :roots); ports = getfield(program, :input_ports)
    n = fieldcount(typeof(nodes)); fieldcount(typeof(order)) === n || throw(ArgumentError("AST order length mismatch"))
    refs = Vector{Int}(undef, n); new = 1
    while new <= n
        old = getfield(order, new)
        Core.arrayset(true, refs, new, old)
        new += 1
    end
    records = ntuple(k -> invoke(_tac_node_payload, Tuple{AbstractTypedASTNodeV1,Vector{Int},Tuple}, getfield(nodes, getfield(order, k)), refs, nodes), n)
    nr = fieldcount(typeof(roots)); mapped_roots = ntuple(k -> Core.arrayref(true, refs, getfield(roots, k)), nr)
    np = fieldcount(typeof(ports)); declarations = Vector{NamedTuple{(:port,:node),Tuple{Int,Int}}}(undef, np); k = 1
    while k <= np
        old = getfield(ports, k)
        Core.arrayset(true, declarations, (port=getfield(getfield(nodes, old), :port), node=Core.arrayref(true, refs, old)), k)
        k += 1
    end
    k = 2
    while k <= np
        current = Core.arrayref(true, declarations, k); j = k - 1
        while j >= 1 && current.port < Core.arrayref(true, declarations, j).port
            Core.arrayset(true, declarations, Core.arrayref(true, declarations, j), j + 1); j -= 1
        end
        Core.arrayset(true, declarations, current, j + 1); k += 1
    end
    ((nodes=records, roots=mapped_roots, input_ports=ntuple(k -> Core.arrayref(true, declarations, k), np),
        used_manifest_bindings=getfield(program, :used_manifest_bindings)), refs)
end

const _TAC_GRAPH_ORBIT_DOMAIN = "fusionconceptai:v4:typed_ast_graph_orbit:v1"

struct _TACGraphOrbitProjection{N,M}
    canonical_text::String
    mappings::NTuple{M,NTuple{N,Int}}
end

function _tac_correct_candidate_for_order(program::TypedASTProgramV1, order::Tuple{Vararg{Int}})
    nodes = getfield(program, :nodes); roots = getfield(program, :roots); ports = getfield(program, :input_ports)
    n = fieldcount(typeof(nodes)); fieldcount(typeof(order)) === n || throw(ArgumentError("AST order length mismatch"))
    inverse = Vector{Int}(undef, n); old = 1
    while old <= n
        new = 1
        while new <= n
            getfield(order, new) === old && (Core.arrayset(true, inverse, new, old); break)
            new += 1
        end
        old += 1
    end
    records = ntuple(k -> invoke(_tac_graph_node_payload, Tuple{AbstractTypedASTNodeV1,Vector{Int},Tuple}, getfield(nodes, getfield(order, k)), inverse, nodes), n)
    nr = fieldcount(typeof(roots)); mapped_roots = ntuple(k -> Core.arrayref(true, inverse, getfield(roots, k)), nr)
    np = fieldcount(typeof(ports)); declarations = Vector{NamedTuple{(:port,:node),Tuple{Int,Int}}}(undef, np); k = 1
    while k <= np
        old_port_node = getfield(ports, k)
        Core.arrayset(true, declarations, (port=getfield(getfield(nodes, old_port_node), :port), node=Core.arrayref(true, inverse, old_port_node)), k)
        k += 1
    end
    k = 2
    while k <= np
        current = Core.arrayref(true, declarations, k); j = k - 1
        while j >= 1 && current.port < Core.arrayref(true, declarations, j).port
            Core.arrayset(true, declarations, Core.arrayref(true, declarations, j), j + 1); j -= 1
        end
        Core.arrayset(true, declarations, current, j + 1); k += 1
    end
    ((nodes=records, roots=mapped_roots, input_ports=ntuple(k -> Core.arrayref(true, declarations, k), np),
        used_manifest_bindings=getfield(program, :used_manifest_bindings)), inverse)
end

function _tac_text_equal(a::String, b::String)::Bool
    na = Core.sizeof(a); nb = Core.sizeof(b); na === nb || return false
    GC.@preserve a b begin
        pa = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), a)
        pb = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), b)
        i = 1
        while i <= na
            invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pa, i) ===
                invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pb, i) || return false
            i += 1
        end
    end
    true
end

function _tac_mapping_equal(a::Vector{Int}, b::Vector{Int}, count::Int)::Bool
    i = 1
    while i <= count
        Core.arrayref(true, a, i) === Core.arrayref(true, b, i) || return false
        i += 1
    end
    true
end

function _tac_mapping_less(a::Vector{Int}, b::Vector{Int}, count::Int)::Bool
    i = 1
    while i <= count
        x = Core.arrayref(true, a, i); y = Core.arrayref(true, b, i)
        x < y && return true; x > y && return false; i += 1
    end
    false
end

function _tac_order_from_mapping(mapping::Vector{Int}, count::Int)
    order = Vector{Int}(undef, count)
    new = 1
    while new <= count
        old = 1
        while old <= count
            Core.arrayref(true, mapping, old) === new &&
                (Core.arrayset(true, order, old, new); break)
            old += 1
        end
        new += 1
    end
    ntuple(i -> Core.arrayref(true, order, i), count)
end

function _tac_orbit_value_equal(a::Any, b::Any)::Bool
    invoke(_tac_text_equal, Tuple{String,String}, invoke(_tac_value_string, Tuple{Any}, a),
        invoke(_tac_value_string, Tuple{Any}, b))
end

function _tac_orbit_node_equal(a::AbstractTypedASTNodeV1, b::AbstractTypedASTNodeV1)::Bool
    typeof(a) === typeof(b) || return false
    if typeof(a) === ASTInputV1
        return getfield(a, :port) === getfield(b, :port) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :parameters), getfield(b, :parameters)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :output_type), getfield(b, :output_type))
    elseif typeof(a) === ASTParameterV1
        return invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :parameters), getfield(b, :parameters)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :output_type), getfield(b, :output_type))
    elseif typeof(a) === ASTConstantV1
        return invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :value), getfield(b, :value)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :parameters), getfield(b, :parameters)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :output_type), getfield(b, :output_type))
    elseif typeof(a) === ASTApplyV1
        return invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :operator_ref), getfield(b, :operator_ref)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :parameters), getfield(b, :parameters)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :output_type), getfield(b, :output_type)) &&
            invoke(_tac_orbit_value_equal, Tuple{Any,Any}, getfield(a, :commutative_input_groups), getfield(b, :commutative_input_groups)) &&
            getfield(a, :pure) === getfield(b, :pure) && getfield(a, :cse_allowed) === getfield(b, :cse_allowed)
    end
    false
end

function _tac_orbit_multiset_equal(a::Vector{Int}, b::Vector{Int}, n::Int)::Bool
    used = Vector{Bool}(undef, n); i = 1
    while i <= n; Core.arrayset(true, used, false, i); i += 1; end
    i = 1
    while i <= n
        value = Core.arrayref(true, a, i); found = false; j = 1
        while j <= n
            if !Core.arrayref(true, used, j) && value === Core.arrayref(true, b, j)
                Core.arrayset(true, used, true, j); found = true; break
            end
            j += 1
        end
        found || return false; i += 1
    end
    true
end

function _tac_is_graph_automorphism(program::TypedASTProgramV1, mapping::Vector{Int})::Bool
    nodes = getfield(program, :nodes); n = fieldcount(typeof(nodes)); roots = getfield(program, :roots); i = 1
    while i <= fieldcount(typeof(roots)); old = getfield(roots, i); Core.arrayref(true, mapping, old) === old || return false; i += 1; end
    ports = getfield(program, :input_ports); i = 1
    while i <= fieldcount(typeof(ports)); old = getfield(ports, i); Core.arrayref(true, mapping, old) === old || return false; i += 1; end
    i = 1
    while i <= n
        source = getfield(nodes, i); target = getfield(nodes, Core.arrayref(true, mapping, i))
        invoke(_tac_orbit_node_equal, Tuple{AbstractTypedASTNodeV1,AbstractTypedASTNodeV1}, source, target) || return false
        if typeof(source) === ASTApplyV1
            source_inputs = getfield(source, :inputs); target_inputs = getfield(target, :inputs); ni = fieldcount(typeof(source_inputs)); ni === fieldcount(typeof(target_inputs)) || return false
            groups = getfield(source, :commutative_input_groups); grouped = Vector{Bool}(undef, ni); p = 1
            while p <= ni; Core.arrayset(true, grouped, false, p); p += 1; end
            g = 1
            while g <= fieldcount(typeof(groups))
                positions = getfield(groups, g); np = fieldcount(typeof(positions)); sv = Vector{Int}(undef, np); tv = Vector{Int}(undef, np); p = 1
                while p <= np
                    pos = getfield(positions, p); Core.arrayset(true, grouped, true, pos)
                    Core.arrayset(true, sv, Core.arrayref(true, mapping, getfield(source_inputs, pos)), p)
                    Core.arrayset(true, tv, getfield(target_inputs, pos), p); p += 1
                end
                invoke(_tac_orbit_multiset_equal, Tuple{Vector{Int},Vector{Int},Int}, sv, tv, np) || return false; g += 1
            end
            p = 1
            while p <= ni
                !Core.arrayref(true, grouped, p) && Core.arrayref(true, mapping, getfield(source_inputs, p)) !== getfield(target_inputs, p) && return false
                p += 1
            end
        end
        i += 1
    end
    true
end

function _tac_graph_orbit(program::TypedASTProgramV1)
    nodes = getfield(program, :nodes); n = fieldcount(typeof(nodes)); n <= 8 || throw(CanonicalizationDeferred("AST graph orbit exceeds the eight-node boundary"))
    permutations = invoke(_tac_permutations, Tuple{Int}, n); total = 1; i = 2
    while i <= n; total *= i; i += 1; end
    best = nothing; best_inverse = nothing; pi = 1
    while pi <= total
        order = Core.arrayref(true, permutations, pi)
        candidate, inverse = invoke(_tac_correct_candidate_for_order, Tuple{TypedASTProgramV1,Tuple{Vararg{Int}}}, program, order)
        text = invoke(_tac_value_string, Tuple{Any}, candidate)
        if best === nothing || invoke(_tac_text_less, Tuple{String,String}, text, best); best = text; best_inverse = inverse; end
        pi += 1
    end
    mappings = Vector{Vector{Int}}(undef, total); mapping_count = 0; pi = 1
    while pi <= total
        order = Core.arrayref(true, permutations, pi)
        _, inverse = invoke(_tac_correct_candidate_for_order, Tuple{TypedASTProgramV1,Tuple{Vararg{Int}}}, program, order)
        invoke(_tac_is_graph_automorphism, Tuple{TypedASTProgramV1,Vector{Int}}, program, inverse) || begin pi += 1; continue; end
        composed = Vector{Int}(undef, n); old = 1
        while old <= n
            Core.arrayset(true, composed, Core.arrayref(true, best_inverse, Core.arrayref(true, inverse, old)), old)
            old += 1
        end
        candidate, _ = invoke(_tac_correct_candidate_for_order,
            Tuple{TypedASTProgramV1,Tuple{Vararg{Int}}}, program,
            invoke(_tac_order_from_mapping, Tuple{Vector{Int},Int}, composed, n))
        invoke(_tac_text_equal, Tuple{String,String},
            invoke(_tac_value_string, Tuple{Any}, candidate), best) || begin
                pi += 1
                continue
            end
        duplicate = false; j = 1
        while j <= mapping_count
            invoke(_tac_mapping_equal, Tuple{Vector{Int},Vector{Int},Int}, composed, Core.arrayref(true, mappings, j), n) && (duplicate = true; break)
            j += 1
        end
        if !duplicate
            spot = 1
            while spot <= mapping_count && invoke(_tac_mapping_less,
                Tuple{Vector{Int},Vector{Int},Int}, Core.arrayref(true, mappings, spot), composed, n)
                spot += 1
            end
            j = mapping_count
            while j >= spot
                Core.arrayset(true, mappings, Core.arrayref(true, mappings, j), j + 1)
                j -= 1
            end
            Core.arrayset(true, mappings, composed, spot); mapping_count += 1
        end
        pi += 1
    end
    frozen_mappings = ntuple(k -> begin
        mapping = Core.arrayref(true, mappings, k)
        ntuple(i -> Core.arrayref(true, mapping, i), n)
    end, mapping_count)
    _TACGraphOrbitProjection{n,mapping_count}(best::String, frozen_mappings)
end

function _typed_ast_program_json(program::TypedASTProgramV1)
    invoke(_tac_value_string, Tuple{Any}, invoke(_tac_program_payload, Tuple{TypedASTProgramV1}, program))
end

function _tac_hash_json(value::String)::Digest256
    count = Core.sizeof(value)
    bytes = Vector{UInt8}(undef, count)
    GC.@preserve value begin
        pointer = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), value)
        i = 1
        while i <= count
            Core.arrayset(true, bytes, invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pointer, i), i)
            i += 1
        end
    end
    digest = invoke(SHA.sha256, Tuple{SHA.AbstractBytes}, bytes)
    io = _ccbw_new()
    i = 1
    while i <= 32
        _ccbw_hex2!(io, Core.arrayref(true, digest, i))
        i += 1
    end
    hex = _ccbw_finish(io)
    invoke(Digest256, Tuple{AbstractString}, hex)
end

canonical_hash(value::TypedASTProgramV1) = invoke(_tac_hash_json, Tuple{String},
    invoke(_typed_ast_program_json, Tuple{TypedASTProgramV1}, value))

function _typed_ast_node_key(n::AbstractTypedASTNodeV1, nodes::Any)
    invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any}, n, nodes)
end

function _typed_ast_node_payload(n::AbstractTypedASTNodeV1, refs::Vector{Int}, nodes::Tuple)
    invoke(_tac_node_payload, Tuple{AbstractTypedASTNodeV1,Vector{Int},Tuple}, n, refs, nodes)
end

function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple, nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    nn = fieldcount(typeof(inputs)); children = Vector{String}(undef, nn); i = 1
    while i <= nn
        index = getfield(inputs, i)
        Core.arrayset(true, children, invoke(_tac_node_key, Tuple{AbstractTypedASTNodeV1,Any},
            Core.arrayref(true, nodes, index), nodes), i)
        i += 1
    end
    _tac_commutative_children!(children, nn, getfield(n, :commutative_input_groups))
    invoke(_tac_value_string, Tuple{Any}, (operator_ref=getfield(n, :operator_ref), manifest_hash=manifest_hash,
        inputs=ntuple(i -> Core.arrayref(true, children, i), nn), parameters=getfield(n, :parameters), output_type=getfield(n, :output_type)))
end
