"""Strict deterministic JSON encoding over explicit semantic projections."""

struct CanonicalizationDeferred <: Exception
    message::String
end
Base.showerror(io::IO, e::CanonicalizationDeferred) = print(io, e.message)

_jsonquote(s::AbstractString) = begin
    io = IOBuffer()
    print(io, '"')
    for c in String(s)
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

function _canonical(x)
    x === nothing && return "null"
    x isa Bool && return x ? "true" : "false"
    x isa Symbol && return _jsonquote(String(x))
    x isa AbstractString && return _jsonquote(x)
    x isa Integer && return string(x)
    x isa AbstractFloat && (isfinite(x) || throw(ArgumentError("non-finite values are not canonical")); return repr(x))
    x isa Rational && return "{\"denominator\":" * string(denominator(x)) * ",\"numerator\":" * string(numerator(x)) * "}"
    x isa Enum && return _jsonquote(String(Symbol(x)))
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

function _graph_encoding(g::TypedOperatorHypergraphV1, order::Tuple)
    rank = zeros(Int, length(g.nodes))
    for (j, old) in enumerate(order); rank[old] = j; end
    nodes = [_canonical(semantic_view(g.nodes[i])) for i in order]
    edges = String[]
    for e in g.hyperedges
        # Port order is retained: only node enumeration is renamed.
        ins = [rank[i] for i in e.inputs]; outs = [rank[i] for i in e.outputs]
        push!(edges, _canonical_pairs([(:inputs, ins), (:outputs, outs), (:ast, e.ast), (:role, e.role)]))
    end
    sort!(edges)
    _canonical_pairs([(:nodes, nodes), (:hyperedges, edges)])
end

function _refined_colors(g)
    colors = [_canonical(semantic_view(n)) for n in g.nodes]
    for _ in 1:12
        nxt = String[]
        for i in eachindex(g.nodes)
            inc = String[]
            for e in g.hyperedges
                if i in e.inputs || i in e.outputs
                    push!(inc, _canonical_pairs([(:role, e.role), (:inputs, [colors[j] for j in e.inputs]),
                                                 (:outputs, [colors[j] for j in e.outputs])]))
                end
            end
            sort!(inc); push!(nxt, _canonical_pairs([(:self, colors[i]), (:incident, inc)]))
        end
        nxt == colors && break
        colors = nxt
    end
    colors
end

function _canonical_graph(g::TypedOperatorHypergraphV1)
    perms = _all_permutations(length(g.nodes))
    perms !== nothing && return minimum(_graph_encoding(g, p) for p in perms)
    colors = _refined_colors(g)
    length(unique(colors)) == length(colors) || throw(CanonicalizationDeferred("terminal_deferred: exact canonical labeling exceeds P0 proof boundary"))
    _graph_encoding(g, Tuple(sortperm(colors)))
end

canonical_json(x::TypedOperatorHypergraphV1) = _canonical_graph(x)
canonical_json(x) = _canonical(x)
