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
    repr(value)
end

function _canonical(x)
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
    x isa NamedTuple && return _canonical_pairs([(k, getfield(x, k)) for k in keys(x)])
    x isa AbstractDict && return _canonical_dict(x)
    x isa AbstractSet && return "[" * join(sort(_canonical(v) for v in x), ",") * "]"
    x isa Tuple && return "[" * join((_canonical(v) for v in x), ",") * "]"
    if x isa AbstractArray
        vals = "[" * join((_canonical(v) for v in vec(x)), ",") * "]"
        return "{\"shape\":" * _canonical(Tuple(size(x))) * ",\"values\":" * vals * "}"
    end
    return _canonical(semantic_view(x))
end

function _canonical_pairs(pairs)
    names = String.(first.(pairs))
    length(unique(names)) == length(names) || throw(ArgumentError("canonical object has duplicate string keys"))
    order = sortperm(names)
    "{" * join((_key(names[i]) * ":" * _canonical(last(pairs[i])) for i in order), ",") * "}"
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
    "{\"account\":" * invoke(_jsonquote, Tuple{AbstractString}, ref.account) * ",\"direction\":" * invoke(_jsonquote, Tuple{AbstractString}, String(ref.direction)) *
    ",\"port_index\":" * string(ref.port_index) * ",\"port_side\":" * invoke(_jsonquote, Tuple{AbstractString}, String(ref.port_side)) *
    ",\"unit\":" * _mimo_closed_unit(ref.unit) * "}"
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
    max_index = maximum((b.graph_node_index for b in (e.input_bindings..., e.output_bindings...)))
    body = _mimo_edge_encoding(e, collect(1:max_index))
    "{\"canonicalization_version\":\"1\",\"domain\":" * invoke(_jsonquote, Tuple{AbstractString}, _MIMO_EDGE_CANONICAL_DOMAIN) *
        ",\"edge\":" * body * "}"
end

canonical_json(e::AtomicMIMOHyperedgeV1) = _mimo_edge_canonical_bytes(e)

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
    colors = _refined_colors(g)
    length(unique(colors)) == length(colors) || throw(CanonicalizationDeferred("terminal_deferred: exact canonical labeling exceeds P0 proof boundary"))
    _graph_encoding(g, Tuple(sortperm(colors)))
end

canonical_json(x::TypedOperatorHypergraphV1) = _canonical_graph(x)
canonical_json(x) = _canonical(x)
