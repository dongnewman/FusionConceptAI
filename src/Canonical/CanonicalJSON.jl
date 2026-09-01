"""Deterministic canonical JSON-like encoding for content addressing.

The encoder intentionally excludes presentation and scheduling keys from every
canonical object. Genome seeds remain available as generation metadata, but do
not identify the semantic physical program.
"""

const _NON_SEMANTIC_KEYS = Set((:identity, :identity_ref, :name, :family, :parent, :parent_refs,
                                :request, :request_id, :shard, :shard_id, :label, :node_id, :edge_id,
                                :proposal_id, :benchmark, :benchmark_flag, :seed, :realization_seed,
                                :control_seed))

_jsonquote(s::AbstractString) = "\"" * replace(String(s), "\\"=>"\\\\", "\""=>"\\\"", "\n"=>"\\n", "\r"=>"\\r") * "\""
_key(s) = _jsonquote(String(s))

function _canonical(x)
    x === nothing && return "null"
    x isa Bool && return x ? "true" : "false"
    x isa Symbol && return _jsonquote(String(x))
    x isa AbstractString && return _jsonquote(x)
    x isa Integer && return string(x)
    x isa AbstractFloat && (isfinite(x) || throw(ArgumentError("non-finite values are not canonical")); return repr(x))
    x isa Rational && return "{\"denominator\":" * string(denominator(x)) * ",\"numerator\":" * string(numerator(x)) * "}"
    x isa UnitRange && return _canonical(collect(x))
    (x isa Tuple || x isa AbstractVector || x isa AbstractSet || x isa AbstractArray) && return "[" * join((_canonical(v) for v in x), ",") * "]"
    x isa NamedTuple && return _canonical_pairs([(k, getfield(x, k)) for k in keys(x)])
    x isa AbstractDict && return _canonical_pairs([(k, v) for (k, v) in x])
    x isa Enum && return _jsonquote(String(Symbol(x)))
    x isa TypedOperatorHypergraphV1 && return _canonical_graph(x)
    x isa MechanismGenomeV4 && return _canonical_pairs([(:graph, x.graph), (:invariants, x.invariants), (:observables, x.observables)])
    x isa FieldGeometryGenomeV4 && return _canonical_pairs([(:graph, x.graph), (:fields, x.fields)])
    x isa RealizationControlGenomeV4 && return _canonical_pairs([(:realization_graph, x.realization_graph), (:control_graph, x.control_graph), (:realization, x.realization), (:control, x.control)])
    T = typeof(x)
    isstructtype(T) || throw(ArgumentError("cannot canonicalize $(T)"))
    pairs = Tuple{Symbol,Any}[]
    for k in fieldnames(T)
        k in _NON_SEMANTIC_KEYS && continue
        push!(pairs, (k, getfield(x, k)))
    end
    _canonical_pairs(pairs)
end

function _canonical_pairs(pairs)
    keep = [(Symbol(k), v) for (k, v) in pairs if Symbol(k) ∉ _NON_SEMANTIC_KEYS]
    sort!(keep, by=p -> String(p[1]))
    "{" * join((_key(k) * ":" * _canonical(v) for (k, v) in keep), ",") * "}"
end

function _all_permutations(n::Int)
    n > 8 && return nothing
    result = Tuple{Vararg{Int}}[]
    work = collect(1:n)
    function visit(pos)
        if pos > n
            push!(result, Tuple(work)); return
        end
        for j in pos:n
            work[pos], work[j] = work[j], work[pos]
            visit(pos + 1)
            work[pos], work[j] = work[j], work[pos]
        end
    end
    visit(1); result
end

function _graph_encoding(g::TypedOperatorHypergraphV1, order::Tuple)
    rank = zeros(Int, length(g.nodes))
    for (j, old) in enumerate(order); rank[old] = j; end
    nodes = [_canonical_pairs([(:node_kind, g.nodes[i].node_kind), (:physical_type, g.nodes[i].physical_type)]) for i in order]
    edges = String[]
    for e in g.hyperedges
        ins = sort(collect(rank[i] for i in e.inputs))
        outs = sort(collect(rank[i] for i in e.outputs))
        push!(edges, _canonical_pairs([(:inputs, ins), (:outputs, outs), (:ast, e.ast), (:role, e.role)]))
    end
    sort!(edges)
    _canonical_pairs([(:nodes, nodes), (:hyperedges, edges)])
end

function _canonical_graph(g::TypedOperatorHypergraphV1)
    perms = _all_permutations(length(g.nodes))
    if perms === nothing
        # Weisfeiler-Lehman refinement gives a presentation-independent order
        # for large open-world graphs. Tied cells contain semantically
        # indistinguishable nodes, so their original IDs are never consulted.
        colors = [_canonical_pairs([(:node_kind, n.node_kind), (:physical_type, n.physical_type)]) for n in g.nodes]
        for _ in 1:8
            next = similar(colors)
            for i in eachindex(g.nodes)
                incident = String[]
                for e in g.hyperedges
                    if i in e.inputs || i in e.outputs
                        push!(incident, _canonical_pairs([(:role, e.role), (:inputs, length(e.inputs)),
                                                          (:outputs, length(e.outputs)), (:neighbors, sort(collect(colors[j] for j in (e.inputs..., e.outputs...) if j != i)))]))
                    end
                end
                sort!(incident)
                next[i] = _canonical_pairs([(:self, colors[i]), (:incident, incident)])
            end
            next == colors && break
            colors = next
        end
        order = sortperm(collect(eachindex(g.nodes)), by=i -> colors[i])
        return _graph_encoding(g, Tuple(order))
    end
    minimum(_graph_encoding(g, p) for p in perms)
end

canonical_json(x) = _canonical(x)
