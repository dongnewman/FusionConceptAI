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
    n = fieldcount(typeof(nodes)); fieldcount(typeof(order)) == n || throw(ArgumentError("AST order length mismatch"))
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
