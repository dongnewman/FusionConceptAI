"""Strict deterministic JSON encoding over explicit semantic projections."""

struct CanonicalizationDeferred <: Exception
    message::String
end
Base.showerror(io::IO, e::CanonicalizationDeferred) = print(io, e.message)

_jsonquote(s::AbstractString) = begin
    text = String(s)
    isvalid(text) || throw(ArgumentError("invalid UTF-8 or surrogate string is not canonical"))
    io = IOBuffer()
    print(io, '"')
    for c in text
        if c == '"'; print(io, "\\\"")
        elseif c == '\\'; print(io, "\\\\")
        elseif c == '\b'; print(io, "\\b")
        elseif c == '\f'; print(io, "\\f")
        elseif c == '\n'; print(io, "\\n")
        elseif c == '\r'; print(io, "\\r")
        elseif c == '\t'; print(io, "\\t")
        elseif UInt32(c) < 0x20; print(io, "\\u", lpad(string(UInt32(c), base=16), 4, '0'))
        else; print(io, c)
        end
    end
    print(io, '"'); String(take!(io))
end
_key(s) = _jsonquote(String(s))

function _canonical_float(x::AbstractFloat)
    value = Float64(x)
    isfinite(value) || throw(ArgumentError("non-finite values are not canonical"))
    value == 0.0 && return "0.0"
    invoke(Base.Ryu.writeshortest, Tuple{Float64}, value)
end

const _CANONICAL_JSON_MEMO_TLS_KEY = :fusion_canonical_json_memo

mutable struct _CanonicalJSONMemoV1
    target::Any
    encoded::Union{Nothing,String}
    payload_targets::Tuple
    payloads::Vector{Tuple{Any,Any}}
end

"""Reuse one deeply immutable canonical subtree inside a bounded task scope."""
function _with_canonical_json_memo(f::Function, target; payload_targets::Tuple=())
    # Only cache values whose complete object graph cannot change while its
    # canonical bytes are reused.  A failed eligibility check keeps the normal
    # serializer path and its behavior.
    deep_immutable(target) || return f()
    storage = task_local_storage()
    previous = get(storage, _CANONICAL_JSON_MEMO_TLS_KEY, nothing)
    # A nested operation on the identical immutable object belongs to the
    # existing bounded scope. Keep its already-encoded bytes and restoration
    # owner rather than replacing them with an empty nested memo.
    previous isa _CanonicalJSONMemoV1 && target === previous.target && return f()
    memo = _CanonicalJSONMemoV1(target, nothing, payload_targets, Tuple{Any,Any}[])
    task_local_storage(_CANONICAL_JSON_MEMO_TLS_KEY, memo)
    try
        f()
    finally
        empty!(memo.payloads)
        if previous === nothing
            delete!(task_local_storage(), _CANONICAL_JSON_MEMO_TLS_KEY)
        else
            task_local_storage(_CANONICAL_JSON_MEMO_TLS_KEY, previous)
        end
    end
end

"""Reuse a successful immutable projection of an explicitly registered object."""
function _canonical_payload_memoized(f::Function, target)
    Base.@nospecialize target
    memo = get(task_local_storage(), _CANONICAL_JSON_MEMO_TLS_KEY, nothing)
    memo isa _CanonicalJSONMemoV1 || return f()
    registered = false
    i = 1
    while i <= fieldcount(typeof(memo.payload_targets))
        if getfield(memo.payload_targets, i) === target
            registered = true
            break
        end
        i += 1
    end
    registered || return f()
    invoke(deep_immutable, Tuple{Any}, target) || return f()
    i = 1
    while i <= Core.arraysize(memo.payloads, 1)
        entry = Core.arrayref(true, memo.payloads, i)
        getfield(entry, 1) === target && return getfield(entry, 2)
        i += 1
    end
    payload = f()
    invoke(deep_immutable, Tuple{Any}, payload) && push!(memo.payloads, (target, payload))
    payload
end

function _canonical_json_memoized(f::Function, target)
    memo = get(task_local_storage(), _CANONICAL_JSON_MEMO_TLS_KEY, nothing)
    if memo isa _CanonicalJSONMemoV1 && target === memo.target
        memo.encoded === nothing || return memo.encoded
        encoded = f()
        memo.encoded = encoded
        return encoded
    end
    f()
end

Base.@nospecializeinfer function _canonical(x)
    Base.@nospecialize x
    x === nothing && return "null"
    x isa Bool && return x ? "true" : "false"
    x isa Symbol && return _jsonquote(String(x))
    x isa AbstractString && return _jsonquote(x)
    typeof(x) in _P0_SAFE_INTEGER_TYPES && return string(x)
    typeof(x) in _P0_SAFE_FLOAT_TYPES && return _canonical_float(x)
    _p0_safe_rational(x) && return "{\"denominator\":" * string(denominator(x)) * ",\"numerator\":" * string(numerator(x)) * "}"
    if x isa Integer || x isa AbstractFloat || x isa Number
        hasmethod(semantic_view, Tuple{typeof(x)}) || throw(ArgumentError("untrusted numeric type requires explicit semantic_view"))
        return _canonical(semantic_view(x))
    end
    x isa Enum && return _jsonquote(String(Symbol(x)))
    x isa TypedOperatorHypergraphV1 && return _canonical_graph(x)
    if x isa NamedTuple
        return _canonical_native_tree_encode_v1(x)
    end
    x isa AbstractDict && return _canonical_dict(x)
    x isa AbstractSet && return "[" * join(sort(_canonical(v) for v in x), ",") * "]"
    if x isa Tuple
        return _canonical_native_tree_encode_v1(x)
    end
    if x isa AbstractArray
        vals = "[" * join((_canonical(v) for v in vec(x)), ",") * "]"
        return "{\"shape\":" * _canonical(Tuple(size(x))) * ",\"values\":" * vals * "}"
    end
    return _canonical(semantic_view(x))
end

_canonical(x::UInt8) = string(x)

Base.@nospecializeinfer function _canonical(value::Vector{UInt8})
    io = _ccbw_new()
    _ccbw_ascii!(io, "{\"shape\":[")
    _ccbw_integer!(io, length(value))
    _ccbw_ascii!(io, "],\"values\":[")
    for index in eachindex(value)
        index > firstindex(value) && _ccbw_byte!(io, UInt8(','))
        _ccbw_uint8!(io, Core.arrayref(true, value, index))
    end
    _ccbw_ascii!(io, "]}")
    _ccbw_finish(io)
end

Base.@nospecializeinfer function _canonical_pairs(pairs)
    Base.@nospecialize pairs
    names = String.(first.(pairs))
    length(unique(names)) == length(names) || throw(ArgumentError("canonical object has duplicate string keys"))
    order = sortperm(names)
    io = IOBuffer()
    print(io, '{')
    first_item = true
    for i in order
        first_item || print(io, ',')
        first_item = false
        print(io, _key(names[i]))
        print(io, ':')
        print(io, _canonical(last(pairs[i])))
    end
    print(io, '}')
    String(take!(io))
end

function _canonical_dict(d)
    pairs = [(string(k), v) for (k, v) in d]
    names = first.(pairs)
    length(unique(names)) == length(names) || throw(ArgumentError("dict keys collide after stringification"))
    order = sortperm(names)
    "{" * join((_key(names[i]) * ":" * _canonical(last(pairs[i])) for i in order), ",") * "}"
end

function _all_permutations(n::Int)
    n > 8 && return nothing
    out = Tuple{Vararg{Int}}[]; a = collect(1:n)
    function visit(k)
        k > n && (push!(out, Tuple(a)); return)
        for j in k:n
            a[k], a[j] = a[j], a[k]; visit(k + 1); a[k], a[j] = a[j], a[k]
        end
    end
    visit(1); out
end

function _mimo_closed_unit(unit::UnitSignature)
    "{\"exponents\":[" * join(("{\"denominator\":" * string(denominator(v)) * ",\"numerator\":" * string(numerator(v)) * "}" for v in unit.exponents), ",") * "]}"
end
_mimo_closed_account(ref::ConservationAccountRefV1) =
    "{\"direction\":" * invoke(_jsonquote, Tuple{AbstractString}, String(ref.direction)) *
    ",\"ledger_identity\":" * invoke(_ledger_identity_wire, Tuple{ConservationLedgerIdentityV1}, ref.ledger_identity) *
    ",\"port_index\":" * string(ref.port_index) * ",\"port_side\":" * invoke(_jsonquote, Tuple{AbstractString}, String(ref.port_side)) * "}"
_mimo_closed_effect(effect::PortAccountEffectV1) =
    "{\"account_ref\":" * _mimo_closed_account(effect.account_ref) * ",\"coefficient\":{\"denominator\":" *
    string(denominator(effect.coefficient)) * ",\"numerator\":" * string(numerator(effect.coefficient)) * "}}"
_mimo_closed_pair(pair::InterfaceFluxPairV1) =
    "{\"minus\":" * _mimo_closed_effect(pair.minus) * ",\"plus\":" * _mimo_closed_effect(pair.plus) * "}"

function _mimo_edge_encoding(e::AtomicMIMOHyperedgeV1, rank::Vector{Int})
    ins = "[" * join(("{\"graph_node\":" * string(rank[b.graph_node_index]) * ",\"program_position\":" * string(b.program_position) * "}" for b in e.input_bindings), ",") * "]"
    outs = "[" * join(("{\"graph_node\":" * string(rank[b.graph_node_index]) * ",\"program_position\":" * string(b.program_position) * "}" for b in e.output_bindings), ",") * "]"
    effects = "[" * join((_mimo_closed_effect(x) for x in e.account_effects), ",") * "]"
    pairs = "[" * join((_mimo_closed_pair(x) for x in e.interface_flux_pairs), ",") * "]"
    "{\"account_effects\":" * effects * ",\"input_bindings\":" * ins * ",\"interface_flux_pairs\":" * pairs *
        ",\"output_bindings\":" * outs * ",\"program_hash\":" * invoke(_jsonquote, Tuple{AbstractString}, e.program_hash.value) *
        ",\"role\":" * invoke(_jsonquote, Tuple{AbstractString}, String(Symbol(e.role))) * "}"
end

const _MIMO_EDGE_CANONICAL_DOMAIN = "fusionconceptai:v4:atomic-mimo-hyperedge:v1"
const _MIMO_GRAPH_CANONICAL_DOMAIN = "fusionconceptai:v4:typed-operator-hypergraph:v1"

function _mimo_edge_canonical_bytes(e::AtomicMIMOHyperedgeV1)
    # Standalone edges have no graph node table.  Encode their validated raw
    # positive indices directly; never allocate a dense 1:max(index) map.
    ins = "[" * join(("{\"graph_node\":" * string(b.graph_node_index) * ",\"program_position\":" * string(b.program_position) * "}" for b in e.input_bindings), ",") * "]"
    outs = "[" * join(("{\"graph_node\":" * string(b.graph_node_index) * ",\"program_position\":" * string(b.program_position) * "}" for b in e.output_bindings), ",") * "]"
    effects = "[" * join((_mimo_closed_effect(x) for x in e.account_effects), ",") * "]"
    pairs = "[" * join((_mimo_closed_pair(x) for x in e.interface_flux_pairs), ",") * "]"
    body = "{\"account_effects\":" * effects * ",\"input_bindings\":" * ins * ",\"interface_flux_pairs\":" * pairs *
        ",\"output_bindings\":" * outs * ",\"program_hash\":" * invoke(_jsonquote, Tuple{AbstractString}, e.program_hash.value) *
        ",\"role\":" * invoke(_jsonquote, Tuple{AbstractString}, String(Symbol(e.role))) * "}"
    "{\"canonicalization_version\":\"1\",\"domain\":" * invoke(_jsonquote, Tuple{AbstractString}, _MIMO_EDGE_CANONICAL_DOMAIN) *
        ",\"edge\":" * body * "}"
end

canonical_json(e::AtomicMIMOHyperedgeV1) = _mimo_edge_canonical_bytes(e)
canonical_json(x::ConservationLedgerIdentityV1) =
    invoke(_ledger_identity_canonical_bytes, Tuple{ConservationLedgerIdentityV1}, x)
canonical_hash(x::ConservationLedgerIdentityV1) =
    invoke(_ledger_identity_hash, Tuple{ConservationLedgerIdentityV1}, x)

function _graph_encoding(g::TypedOperatorHypergraphV1, order::Tuple)
    rank = zeros(Int, length(g.nodes))
    for (j, old) in enumerate(order); rank[old] = j; end
    nodes = [_canonical(semantic_view(g.nodes[i])) for i in order]
    edges = String[]
    for e in g.hyperedges
        if typeof(e) === TypedHyperedge
            # Port order is retained: only node enumeration is renamed.
            ins = [rank[i] for i in e.inputs]; outs = [rank[i] for i in e.outputs]
            push!(edges, _canonical_pairs([(:inputs, ins), (:outputs, outs), (:ast, e.ast), (:role, e.role)]))
        elseif typeof(e) === AtomicMIMOHyperedgeV1
            push!(edges, _mimo_edge_encoding(e, rank))
        else
            throw(ArgumentError("canonical graph contains an unsealed edge"))
        end
    end
    sort!(edges)
    _canonical_pairs([(:canonicalization_version, "1"), (:domain, _MIMO_GRAPH_CANONICAL_DOMAIN),
        (:nodes, nodes), (:hyperedges, edges)])
end

function _refined_colors(g)
    colors = [_color_digest(_canonical(semantic_view(n))) for n in g.nodes]
    for _ in 1:12
        nxt = String[]
        for i in eachindex(g.nodes)
            inc = String[]
            for e in g.hyperedges
                if i in e.inputs || i in e.outputs
                    push!(inc, _color_digest(string(e.role, '|', join((colors[j] for j in e.inputs), ','), '|', join((colors[j] for j in e.outputs), ','))))
                end
            end
            sort!(inc); push!(nxt, _color_digest(string(colors[i], '|', join(inc, ','))))
        end
        nxt == colors && break
        colors = nxt
    end
    colors
end

_color_digest(s) = bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(String(s)))))

function _canonical_graph(g::TypedOperatorHypergraphV1)
    perms = _all_permutations(length(g.nodes))
    perms !== nothing && return minimum(_graph_encoding(g, p) for p in perms)
    # Atomic MIMO graphs already have a closed, incidence-based canonical
    # encoding.  Use it for large graphs instead of the legacy color refiner,
    # whose edge adapter only understands TypedHyperedge's inputs/outputs.
    any(e -> e isa AtomicMIMOHyperedgeV1, g.hyperedges) &&
        return _exact_incidence_canonical_json(g, default_canonicalization_profile())
    colors = _refined_colors(g)
    length(unique(colors)) == length(colors) || throw(CanonicalizationDeferred("terminal_deferred: exact canonical labeling exceeds P0 proof boundary"))
    _graph_encoding(g, Tuple(sortperm(colors)))
end

function canonical_json(g::TypedOperatorHypergraphV1; profile=nothing)
    selected = profile === nothing ? default_canonicalization_profile() : profile
    _exact_incidence_canonical_json(g, selected)
end

# Stream only the closed native JSON tree used by parsed artifact readers.
# Everything outside this deliberately small subset keeps the legacy path.
function _canonical_native_tree_add_v1(a::Int, b::Int)
    b >= 0 && b <= typemax(Int) - a ? a + b : nothing
end

function _canonical_native_quote_size_v1(value::String)
    isvalid(value) || throw(ArgumentError("invalid UTF-8 or surrogate string is not canonical"))
    size = 2
    for byte in codeunits(value)
        extra = byte == 0x22 || byte == 0x5c ? 2 : byte < 0x20 ? (byte in (0x08, 0x09, 0x0a, 0x0c, 0x0d) ? 2 : 6) : 1
        size = _canonical_native_tree_add_v1(size, extra)
        size === nothing && return nothing
    end
    size
end

Base.@nospecializeinfer function _canonical_native_tree_size_v1(value)
    Base.@nospecialize value
    if value isa NamedTuple
        names = String[String(key) for key in keys(value)]
        length(unique(names)) == length(names) || throw(ArgumentError("canonical object has duplicate string keys"))
        order = sortperm(names)
        size = 2
        for position in eachindex(order)
            if position > 1
                size = _canonical_native_tree_add_v1(size, 1)
                size === nothing && return nothing
            end
            index = order[position]
            key_size = _canonical_native_quote_size_v1(names[index])
            key_size === nothing && return nothing
            size = _canonical_native_tree_add_v1(size, key_size)
            size === nothing && return nothing
            size = _canonical_native_tree_add_v1(size, 1) # colon
            size === nothing && return nothing
            child_size = _canonical_native_tree_size_v1(getfield(value, index))
            child_size === nothing && return nothing
            size = _canonical_native_tree_add_v1(size, child_size)
            size === nothing && return nothing
        end
        return size
    elseif value isa Tuple
        size = 2
        for index in eachindex(value)
            if index > 1
                size = _canonical_native_tree_add_v1(size, 1)
                size === nothing && return nothing
            end
            child_size = _canonical_native_tree_size_v1(getfield(value, index))
            child_size === nothing && return nothing
            size = _canonical_native_tree_add_v1(size, child_size)
            size === nothing && return nothing
        end
        return size
    elseif value isa Vector{UInt8}
        # Match the existing specialized Vector{UInt8} wire form without
        # forcing a nested byte vector back through `_canonical_pairs`.
        size = 10 # {"shape":[
        size = _canonical_native_tree_add_v1(size, ncodeunits(string(length(value))))
        size === nothing && return nothing
        size = _canonical_native_tree_add_v1(size, 12) # ],"values":[
        size === nothing && return nothing
        for index in eachindex(value)
            if index > firstindex(value)
                size = _canonical_native_tree_add_v1(size, 1) # comma
                size === nothing && return nothing
            end
            byte = Core.arrayref(true, value, index)
            digits = byte < 0x0a ? 1 : byte < 0x64 ? 2 : 3
            size = _canonical_native_tree_add_v1(size, digits)
            size === nothing && return nothing
        end
        size = _canonical_native_tree_add_v1(size, 2) # ]}
        return size
    elseif value === nothing
        return 4
    elseif value isa Bool
        return value ? 4 : 5
    elseif value isa String
        return _canonical_native_quote_size_v1(value)
    elseif value isa Symbol
        return _canonical_native_quote_size_v1(String(value))
    elseif typeof(value) in _P0_SAFE_INTEGER_TYPES
        return ncodeunits(string(value))
    elseif typeof(value) in _P0_SAFE_FLOAT_TYPES
        return ncodeunits(_canonical_float(value))
    end
    nothing
end

Base.@nospecializeinfer function _canonical_native_tree_write_v1!(io::Base.GenericIOBuffer, value)
    Base.@nospecialize value
    if value isa NamedTuple
        names = String[String(key) for key in keys(value)]
        length(unique(names)) == length(names) || throw(ArgumentError("canonical object has duplicate string keys"))
        order = sortperm(names)
        _ccbw_byte!(io, UInt8('{'))
        for position in eachindex(order)
            position > 1 && _ccbw_byte!(io, UInt8(','))
            index = order[position]
            isvalid(names[index]) || throw(ArgumentError("invalid UTF-8 or surrogate string is not canonical"))
            _ccbw_quote!(io, names[index])
            _ccbw_byte!(io, UInt8(':'))
            _canonical_native_tree_write_v1!(io, getfield(value, index))
        end
        return _ccbw_byte!(io, UInt8('}'))
    elseif value isa Tuple
        _ccbw_byte!(io, UInt8('['))
        for index in eachindex(value)
            index > 1 && _ccbw_byte!(io, UInt8(','))
            _canonical_native_tree_write_v1!(io, getfield(value, index))
        end
        return _ccbw_byte!(io, UInt8(']'))
    elseif value isa Vector{UInt8}
        _ccbw_ascii!(io, "{\"shape\":[")
        _ccbw_integer!(io, length(value))
        _ccbw_ascii!(io, "],\"values\":[")
        for index in eachindex(value)
            index > firstindex(value) && _ccbw_byte!(io, UInt8(','))
            _ccbw_uint8!(io, Core.arrayref(true, value, index))
        end
        _ccbw_ascii!(io, "]}")
        return nothing
    elseif value isa Array{Float64}
        # Keep the existing shape, column order and Ryu float representation.
        # One scratch buffer avoids a new formatter buffer for each element.
        _ccbw_ascii!(io, "{\"shape\":")
        _canonical_native_tree_write_v1!(io, Tuple(size(value)))
        _ccbw_ascii!(io, ",\"values\":[")
        scratch = Vector{UInt8}(undef, Base.Ryu.neededdigits(Float64))
        for index in eachindex(value)
            index > 1 && _ccbw_byte!(io, UInt8(','))
            number = Core.arrayref(true, value, index)::Float64
            isfinite(number) ||
                throw(ArgumentError("non-finite values are not canonical"))
            if number == 0.0
                _ccbw_ascii!(io, "0.0")
            else
                next = invoke(Base.Ryu.writeshortest,
                    Tuple{Vector{UInt8},Int,Float64}, scratch, 1, number)
                for position in 1:next-1
                    _ccbw_byte!(io, Core.arrayref(true, scratch, position))
                end
            end
        end
        _ccbw_ascii!(io, "]}")
        return nothing
    elseif value === nothing
        return _ccbw_ascii!(io, "null")
    elseif value isa Bool
        return _ccbw_ascii!(io, value ? "true" : "false")
    elseif value isa String
        isvalid(value) || throw(ArgumentError("invalid UTF-8 or surrogate string is not canonical"))
        return _ccbw_quote!(io, value)
    elseif value isa Symbol
        text = String(value)
        isvalid(text) || throw(ArgumentError("invalid UTF-8 or surrogate string is not canonical"))
        return _ccbw_quote!(io, text)
    end
    _ccbw_utf8!(io, _canonical(value))
end

Base.@nospecializeinfer function _canonical_native_tree_encode_v1(value)
    Base.@nospecialize value
    io = _ccbw_new()
    _canonical_native_tree_write_v1!(io, value)
    _ccbw_finish(io)
end

function canonical_json(x)
    Base.@nospecialize x
    if x isa NamedTuple || x isa Tuple
        size = _canonical_native_tree_size_v1(x)
        if size !== nothing
            io = IOBuffer(sizehint=size)
            _canonical_native_tree_write_v1!(io, x)
            return _ccbw_finish(io)
        end
    end
    _canonical(x)
end
