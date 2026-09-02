"""Exact, budgeted canonical labeling for the typed incidence graph."""

struct CanonicalizationBudgetV1
    max_search_nodes::Int
    max_refinement_rounds::Int
    max_vertices::Int
    max_bytes::Int
    function CanonicalizationBudgetV1(max_search_nodes::Integer=100_000,
                                      max_refinement_rounds::Integer=10_000,
                                      max_vertices::Integer=512,
                                      max_bytes::Integer=8_000_000)
        values = ((max_search_nodes, "max_search_nodes"), (max_refinement_rounds, "max_refinement_rounds"),
            (max_vertices, "max_vertices"), (max_bytes, "max_bytes"))
        for (value, name) in values
            typeof(value) in _P0_SAFE_INTEGER_TYPES && !(value isa Bool) && typemin(Int) <= value <= typemax(Int) && value > 0 ||
                throw(ArgumentError("$name must be a positive safe integer"))
        end
        new(Int(max_search_nodes), Int(max_refinement_rounds), Int(max_vertices), Int(max_bytes))
    end
end

struct CanonicalizationProfileV1
    profile_id::String
    version::String
    budget::CanonicalizationBudgetV1
    function CanonicalizationProfileV1(profile_id::AbstractString="exact-incidence",
                                       version::AbstractString="1",
                                       budget::CanonicalizationBudgetV1=CanonicalizationBudgetV1())
        !isempty(profile_id) && isvalid(String(profile_id)) || throw(ArgumentError("canonicalization profile id is invalid"))
        !isempty(version) && isvalid(String(version)) || throw(ArgumentError("canonicalization profile version is invalid"))
        new(invoke(_validated_string, Tuple{AbstractString,AbstractString}, profile_id, "canonicalization profile id"),
            invoke(_validated_string, Tuple{AbstractString,AbstractString}, version, "canonicalization profile version"), budget)
    end
end

default_canonicalization_profile() = CanonicalizationProfileV1()

struct _IncidenceGraphV1
    kinds::Tuple{Vararg{Symbol}}
    local_colors::Tuple{Vararg{String}}
    arcs::Tuple{Vararg{Tuple{Int,Int,String}}}
end

function _incidence_add_arc!(arcs, source::Int, target::Int, label::String)
    push!(arcs, (source, target, label))
end

function _incidence_node_color(n::TypedNode)
    "node|" * invoke(_ast_program_canonical, Tuple{Any}, (kind=n.node_kind, physical_type=n.physical_type))
end

function _incidence_atomic_edge_color(e::AtomicMIMOHyperedgeV1)
    effects = join((invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, x) for x in e.account_effects), ",")
    pairs = join((invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, x) for x in e.interface_flux_pairs), ",")
    "edge|atomic|program=" * e.program_hash.value * "|role=" * String(Symbol(e.role)) *
        "|effects=[" * effects * "]|pairs=[" * pairs * "]"
end

function _incidence_legacy_ast_color(ast::TypedAST)
    nodes = Tuple((opcode=n.opcode, inputs=n.inputs, output_type=n.output_type, parameters=n.parameters) for n in ast.nodes)
    bindings = Tuple((operator_ref=b[1], manifest_hash=b[2]) for b in ast.manifest_bindings)
    invoke(_ast_program_canonical, Tuple{Any},
        (nodes=nodes, root=ast.root, input_ports=ast.input_ports, manifest_bindings=bindings))
end

function _incidence_graph(g::TypedOperatorHypergraphV1)
    kinds = Symbol[]
    colors = String[]
    arcs = Tuple{Int,Int,String}[]
    for n in g.nodes
        push!(kinds, :graph_node); push!(colors, _incidence_node_color(n))
    end
    node_count = length(g.nodes)
    for (edge_number, e) in enumerate(g.hyperedges)
        edge_vertex = length(kinds) + 1
        if typeof(e) === AtomicMIMOHyperedgeV1
            push!(kinds, :atomic_edge); push!(colors, _incidence_atomic_edge_color(e))
            for binding in e.input_bindings
                port_vertex = length(kinds) + 1
                push!(kinds, :input_port); push!(colors, "input_port|position=" * string(binding.program_position))
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, edge_vertex, port_vertex, "edge_to_input")
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, port_vertex, binding.graph_node_index, "input_to_node")
            end
            for binding in e.output_bindings
                port_vertex = length(kinds) + 1
                push!(kinds, :output_port); push!(colors, "output_port|position=" * string(binding.program_position))
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, binding.graph_node_index, port_vertex, "node_to_output")
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, port_vertex, edge_vertex, "output_to_edge")
            end
        elseif typeof(e) === TypedHyperedge
            push!(kinds, :legacy_edge); push!(colors, "edge|legacy|role=" * String(e.role) * "|ast=" * _incidence_legacy_ast_color(e.ast))
            for (position, graph_node) in enumerate(e.inputs)
                port_vertex = length(kinds) + 1
                push!(kinds, :input_port); push!(colors, "input_port|position=" * string(position))
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, edge_vertex, port_vertex, "edge_to_input")
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, port_vertex, graph_node, "input_to_node")
            end
            for (position, graph_node) in enumerate(e.outputs)
                port_vertex = length(kinds) + 1
                push!(kinds, :output_port); push!(colors, "output_port|position=" * string(position))
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, graph_node, port_vertex, "node_to_output")
                invoke(_incidence_add_arc!, Tuple{Any,Int,Int,String}, arcs, port_vertex, edge_vertex, "output_to_edge")
            end
        else
            throw(ArgumentError("incidence graph contains an unsealed edge"))
        end
    end
    invoke(_IncidenceGraphV1, Tuple{Any,Any,Any}, Tuple(kinds), Tuple(colors), Tuple(arcs))
end

function _incidence_initial_colors(local_colors::Tuple)
    unique_colors = sort!(collect(unique(local_colors)))
    ids = Dict{String,Int}(color => i for (i, color) in enumerate(unique_colors))
    [ids[color] for color in local_colors]
end

function _incidence_initial_colors_for_graph(ig::_IncidenceGraphV1)
    keys = Tuple(String(ig.kinds[i]) * "\u0000" * ig.local_colors[i] for i in eachindex(ig.kinds))
    unique_keys = sort!(collect(unique(keys)))
    ids = Dict{String,Int}(key => i for (i, key) in enumerate(unique_keys))
    [ids[key] for key in keys]
end

function _incidence_signature_key(previous::Int, outgoing, incoming)
    out = sort!(collect(outgoing), by=x -> (x[1], x[2]))
    inc = sort!(collect(incoming), by=x -> (x[1], x[2]))
    pad(value) = lpad(string(value), 12, '0')
    "p" * pad(previous) * "|out=" * join((x[1] * "=" * pad(x[2]) for x in out), ";") *
        "|in=" * join((x[1] * "=" * pad(x[2]) for x in inc), ";")
end

function _incidence_refine(ig::_IncidenceGraphV1, colors::Vector{Int}, budget::CanonicalizationBudgetV1, rounds::Base.RefValue{Int})
    current = copy(colors)
    while true
        rounds[] += 1
        rounds[] <= budget.max_refinement_rounds || throw(CanonicalizationDeferred("canonicalization refinement budget exhausted"))
        signatures = String[]
        for vertex in eachindex(current)
            outgoing = ((label, current[target]) for (source, target, label) in ig.arcs if source == vertex)
            incoming = ((label, current[source]) for (source, target, label) in ig.arcs if target == vertex)
            push!(signatures, invoke(_incidence_signature_key, Tuple{Int,Any,Any}, current[vertex], outgoing, incoming))
        end
        # Refinement is an ordered split: parent color blocks remain in their
        # lexicographic order, while complete signatures order subcells inside
        # each parent.  This is the byte grammar used by the exact search.
        refined = zeros(Int, length(current))
        next_color = 1
        for parent in sort!(collect(unique(current)))
            members = findall(==(parent), current)
            ordered = sort!(collect(unique(signatures[members])))
            ids = Dict{String,Int}(key => next_color + i - 1 for (i, key) in enumerate(ordered))
            for vertex in members
                refined[vertex] = ids[signatures[vertex]]
            end
            next_color += length(ordered)
        end
        _incidence_same_partition(refined, current) && return refined
        current = refined
    end
end

function _incidence_split_color(colors::Vector{Int}, selected::Int)
    parent = colors[selected]
    split = copy(colors)
    for vertex in eachindex(split)
        split[vertex] > parent && (split[vertex] += 1)
        split[vertex] == parent && vertex != selected && (split[vertex] += 1)
    end
    split
end

function _incidence_partition(colors::Vector{Int})
    classes = Dict{Int,Vector{Int}}()
    for (index, color) in enumerate(colors)
        push!(get!(classes, color, Int[]), index)
    end
    collect(values(classes))
end

function _incidence_same_partition(left::Vector{Int}, right::Vector{Int})
    length(left) == length(right) || return false
    for i in eachindex(left), j in eachindex(left)
        (left[i] == left[j]) == (right[i] == right[j]) || return false
    end
    true
end

function _incidence_leaf_bytes(ig::_IncidenceGraphV1, colors::Vector{Int}, profile::CanonicalizationProfileV1)
    length(unique(colors)) == length(colors) || throw(ArgumentError("canonical leaf is not discrete"))
    order = sortperm(colors)
    rank = zeros(Int, length(order))
    for (new, old) in enumerate(order); rank[old] = new; end
    vertices = "[" * join(("{\"kind\":" * invoke(_jsonquote, Tuple{AbstractString}, String(ig.kinds[old])) *
        ",\"local_color\":" * invoke(_jsonquote, Tuple{AbstractString}, ig.local_colors[old]) * "}" for old in order), ",") * "]"
    arcs = sort!([(rank[source], rank[target], label) for (source, target, label) in ig.arcs])
    arc_text = "[" * join(("{\"label\":" * invoke(_jsonquote, Tuple{AbstractString}, a[3]) *
        ",\"source\":" * string(a[1]) * ",\"target\":" * string(a[2]) * "}" for a in arcs), ",") * "]"
    "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:typed-incidence-graph:v1\",\"profile\":{\"profile_id\":" *
        invoke(_jsonquote, Tuple{AbstractString}, profile.profile_id) * ",\"version\":" * invoke(_jsonquote, Tuple{AbstractString}, profile.version) *
        ",\"vertices\":" * vertices * ",\"arcs\":" * arc_text * "}}"
end

function _incidence_components(ig::_IncidenceGraphV1)
    adjacency = [Int[] for _ in eachindex(ig.kinds)]
    for (source, target, _) in ig.arcs
        push!(adjacency[source], target); push!(adjacency[target], source)
    end
    seen = falses(length(ig.kinds)); components = Vector{Vector{Int}}()
    for start in eachindex(ig.kinds)
        seen[start] && continue
        component = Int[]; stack = [start]; seen[start] = true
        while !isempty(stack)
            vertex = pop!(stack); push!(component, vertex)
            for next in adjacency[vertex]
                seen[next] || (seen[next] = true; push!(stack, next))
            end
        end
        push!(components, sort(component))
    end
    components
end

function _incidence_induced(ig::_IncidenceGraphV1, vertices::Vector{Int})
    remap = Dict(old => new for (new, old) in enumerate(vertices))
    arcs = Tuple{Int,Int,String}[]
    for (source, target, label) in ig.arcs
        haskey(remap, source) && haskey(remap, target) && push!(arcs, (remap[source], remap[target], label))
    end
    invoke(_IncidenceGraphV1, Tuple{Any,Any,Any},
        Tuple(ig.kinds[i] for i in vertices), Tuple(ig.local_colors[i] for i in vertices), Tuple(arcs))
end

function _incidence_search(ig::_IncidenceGraphV1, colors::Vector{Int}, profile::CanonicalizationProfileV1,
                           search_nodes::Base.RefValue{Int}, rounds::Base.RefValue{Int};
                           initial_partition_pending::Bool=false)
    search_nodes[] += 1
    search_nodes[] <= profile.budget.max_search_nodes || throw(CanonicalizationDeferred("canonicalization search budget exhausted"))
    if initial_partition_pending
        # The first split enumerates the full local-color block.  It is still
        # an ordered split (not a second index domain): the selected member is
        # first in its parent block and every branch is retained for min-byte
        # comparison before refinement is allowed to distinguish subcells.
        initial_cells = [cell for cell in _incidence_partition(colors) if length(cell) > 1]
        if !isempty(initial_cells)
            target = first(sort(initial_cells, by=cell ->
                (length(cell), minimum(colors[v] for v in cell))))
            best = nothing
            for vertex in target
                candidate = _incidence_search(ig, _incidence_split_color(colors, vertex), profile,
                    search_nodes, rounds; initial_partition_pending=false)
                best === nothing || candidate < best || continue
                best = candidate
            end
            return best
        end
    end
    refined = _incidence_refine(ig, colors, profile.budget, rounds)
    classes = [class for class in _incidence_partition(refined) if length(class) > 1]
    isempty(classes) && return _incidence_leaf_bytes(ig, refined, profile)
    # Refined color ids are assigned from complete sorted signatures.  Select
    # a target cell by its invariant color, never by input enumeration.
    class = first(sort(classes, by=x -> (length(x), minimum(refined[v] for v in x))))
    best = nothing
    # Every member is explored.  Traversal order is not part of the result;
    # the result is the lexicographic minimum of all complete leaves.
    for vertex in class
        individualized = _incidence_split_color(refined, vertex)
        candidate = _incidence_search(ig, individualized, profile, search_nodes, rounds;
            initial_partition_pending=false)
        best === nothing || candidate < best || continue
        best = candidate
    end
    best
end

function _exact_incidence_canonical_json(g::TypedOperatorHypergraphV1, profile::CanonicalizationProfileV1)
    ig = _incidence_graph(g)
    length(ig.kinds) <= profile.budget.max_vertices || throw(CanonicalizationDeferred("incidence graph vertex budget exhausted"))
    search_nodes = Ref(0); rounds = Ref(0)
    components = _incidence_components(ig)
    component_bytes = String[]
    for component in components
        induced = _incidence_induced(ig, component)
        initial_colors = invoke(_incidence_initial_colors_for_graph, Tuple{_IncidenceGraphV1}, induced)
        push!(component_bytes, _incidence_search(induced, initial_colors, profile, search_nodes, rounds;
            initial_partition_pending=true))
    end
    sort!(component_bytes)
    bytes = length(component_bytes) == 1 ? only(component_bytes) :
        "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:typed-incidence-graph:v1\",\"profile\":{\"profile_id\":" *
        invoke(_jsonquote, Tuple{AbstractString}, profile.profile_id) * ",\"version\":" * invoke(_jsonquote, Tuple{AbstractString}, profile.version) *
        ",\"components\":[" * join(component_bytes, ",") * "]}}"
    ncodeunits(bytes) <= profile.budget.max_bytes || throw(CanonicalizationDeferred("canonicalization byte budget exhausted"))
    bytes
end

function canonical_hash(g::TypedOperatorHypergraphV1, profile::CanonicalizationProfileV1)
    Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(_exact_incidence_canonical_json(g, profile))))))
end
