struct RealizationControlGenomeV4
    seed::UInt64
    control_seed::Union{Nothing,UInt64}
    realization_graph::TypedOperatorHypergraphV1
    control_graph::TypedOperatorHypergraphV1
    realization::Tuple
    control::Tuple
end

function RealizationControlGenomeV4(seed::Integer, realization_graph::TypedOperatorHypergraphV1,
                                   control_graph::TypedOperatorHypergraphV1; realization=(), control=())
    RealizationControlGenomeV4(UInt64(seed), nothing, realization_graph, control_graph,
                               Tuple(realization), Tuple(control))
end

function RealizationControlGenomeV4(realization_seed::Integer, control_seed::Integer,
                                    realization_graph::TypedOperatorHypergraphV1,
                                    control_graph::TypedOperatorHypergraphV1; realization=(), control=())
    realization_seed == control_seed && throw(ArgumentError("realization and control require independent seeds"))
    RealizationControlGenomeV4(UInt64(realization_seed), UInt64(control_seed), realization_graph, control_graph,
                               Tuple(realization), Tuple(control))
end
