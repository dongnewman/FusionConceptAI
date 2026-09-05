"""A deterministic, typed screen provider for the v4 vertical slice.

The provider performs a structural audit of the exact solver payload.  It is
deliberately limited to ``screen_only`` evidence and has no path to a higher
claim ceiling.  Its executor is a stable function (rather than a closure), so
recreating an identical manifest cannot accidentally bind a different backend
to the same manifest hash.
"""

const _SCREEN_EXECUTION_COUNT = Ref(0)

screen_execution_count() = _SCREEN_EXECUTION_COUNT[]
reset_screen_execution_count!() = (_SCREEN_EXECUTION_COUNT[] = 0)

function _screen_graph_counts(payload)
    is_canonical_value(payload) || throw(ArgumentError("screen payload must be immutable and canonicalizable"))
    payload isa NamedTuple && :materialized_payload in keys(payload) ||
        throw(ArgumentError("screen payload must contain materialized_payload"))
    subject = getfield(payload, :materialized_payload)
    subject isa NamedTuple || throw(ArgumentError("materialized_payload must be a named tuple"))
    names = (:mechanism_graph, :field_geometry_graph, :realization_graph, :control_graph)
    all(name in keys(subject) for name in names) ||
        throw(ArgumentError("materialized_payload has no complete typed Genome graph schema"))
    graphs = Any[getfield(subject, name) for name in names]
    node_count = 0
    edge_count = 0
    node_hashes = Set{Digest256}()
    edge_hashes = Set{Digest256}()
    graph_hashes = Set{Digest256}()
    for graph in graphs
        hasproperty(graph, :nodes) && hasproperty(graph, :hyperedges) ||
            throw(ArgumentError("screen payload contains a non-graph value"))
        nodes = getproperty(graph, :nodes)
        edges = getproperty(graph, :hyperedges)
        node_count += length(nodes)
        edge_count += length(edges)
        all(is_canonical_value, nodes) || throw(ArgumentError("screen graph contains an invalid node"))
        all(is_canonical_value, edges) || throw(ArgumentError("screen graph contains an invalid hyperedge"))
        push!(graph_hashes, canonical_hash(graph))
        union!(node_hashes, (canonical_hash(node) for node in nodes))
        union!(edge_hashes, (canonical_hash(edge) for edge in edges))
    end
    node_count > 0 || throw(ArgumentError("screen graph has no typed nodes"))
    edge_count > 0 || throw(ArgumentError("screen graph has no typed operators"))
    (node_occurrences=node_count, operator_occurrences=edge_count,
     graph_occurrences=length(graphs), unique_nodes=length(node_hashes),
     unique_operators=length(edge_hashes), unique_graphs=length(graph_hashes))
end

"""Execute the structural screen and return typed, screen-only components."""
function deterministic_screen_execute(input)
    _SCREEN_EXECUTION_COUNT[] += 1
    payload = input isa SolverInputV4 ? input.payload : input
    counts = _screen_graph_counts(payload)
    metrics = (MetricWithUnit(:typed_node_occurrences, counts.node_occurrences),
               MetricWithUnit(:typed_operator_occurrences, counts.operator_occurrences),
               MetricWithUnit(:typed_graph_occurrences, counts.graph_occurrences),
               MetricWithUnit(:typed_unique_nodes, counts.unique_nodes),
               MetricWithUnit(:typed_unique_operators, counts.unique_operators),
               MetricWithUnit(:typed_unique_graphs, counts.unique_graphs))
    (stage_outcome=pass, metrics=metrics, claim_ceiling=screen_only,
     independence_group="deterministic-screen",
     binding_provenance=(algorithm="typed-graph-structure-audit-v1",
                         graph_occurrences=counts.graph_occurrences,
                         node_occurrences=counts.node_occurrences,
                         operator_occurrences=counts.operator_occurrences,
                         unique_graphs=counts.unique_graphs,
                         unique_nodes=counts.unique_nodes,
                         unique_operators=counts.unique_operators))
end

"""Create a provider whose capability is exactly `obligation`.

The returned manifest is the object consumed by exact capability routing.
"""
function _screen_capability(bounds_hash::Digest256;
                            input_schema_hash=canonical_hash((schema="fusionconceptai:screen-input", revision="v1")))
    CapabilitySignatureV4("fusionconceptai:runtime-v4-screen", "v1", :structural_screen,
        "typed_structure_audit", ("typed_graph",), "typed_graph", "typed_graph", 1,
        ("lumped",), "none_declared", "none_declared", "static_time",
        ("typed_structure_audit",), screen_only, bounds_hash;
        input_schema_hash=input_schema_hash, coordinate_system="lumped")
end

screen_capability(bounds_hash::Digest256; kwargs...) = _screen_capability(bounds_hash; kwargs...)

function deterministic_screen_manifest(obligation::CapabilitySignatureV4)
    obligation.kind == :structural_screen && obligation.operator == "typed_structure_audit" &&
        obligation.required_output == ("typed_structure_audit",) ||
        throw(ArgumentError("deterministic screen provider only accepts the structural-audit capability"))
    ProviderManifestV4(obligation.schema, obligation.revision, obligation.kind, obligation,
        (bounds_hash=obligation.applicability_bounds, provider="deterministic_screen"),
        "deterministic_screen", "v4-screen-1",
        canonical_hash((algorithm="typed-graph-structure-audit-v1", version=1)),
        "deterministic-screen", screen_only;
        input_schema_hash=obligation.input_schema_hash,
        executor=deterministic_screen_execute)
end

deterministic_screen_provider(obligation::CapabilitySignatureV4) =
    deterministic_screen_manifest(obligation)

function deterministic_screen_manifest(bounds_hash::Digest256; kwargs...)
    deterministic_screen_manifest(_screen_capability(bounds_hash; kwargs...))
end

deterministic_screen_provider(bounds_hash::Digest256; kwargs...) =
    deterministic_screen_manifest(bounds_hash; kwargs...)
