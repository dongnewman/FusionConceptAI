struct RealizationControlGenomeV4
    seed::UInt64
    control_seed::UInt64
    contract_ref::GenomeContractRef
    realization_graph::TypedOperatorHypergraphV1
    control_graph::TypedOperatorHypergraphV1
    realization::Tuple
    control::Tuple
    function RealizationControlGenomeV4(realization_seed::UInt64, control_seed::UInt64,
                                        contract_ref::GenomeContractRef, realization_graph::TypedOperatorHypergraphV1,
                                        control_graph::TypedOperatorHypergraphV1, realization::Tuple, control::Tuple)
        realization_seed == control_seed && throw(ArgumentError("realization and control require independent seeds"))
        deep_immutable((contract_ref=contract_ref, realization_graph=realization_graph, control_graph=control_graph,
                        realization=realization, control=control)) || throw(ArgumentError("G3 payload must be deeply immutable"))
        is_canonical_value((contract_ref=contract_ref, realization_graph=realization_graph, control_graph=control_graph,
                           realization=realization, control=control)) || throw(ArgumentError("G3 payload is not canonicalizable"))
        new(realization_seed, control_seed, contract_ref, realization_graph, control_graph, realization, control)
    end
end

function RealizationControlGenomeV4(realization_seed::Integer, control_seed::Integer,
                                    contract_ref::GenomeContractRef,
                                    realization_graph::TypedOperatorHypergraphV1,
                                    control_graph::TypedOperatorHypergraphV1; realization=(), control=())
    RealizationControlGenomeV4(UInt64(realization_seed), UInt64(control_seed), contract_ref, realization_graph, control_graph,
                               Tuple(realization), Tuple(control))
end
semantic_view(x::RealizationControlGenomeV4) = (contract_ref=x.contract_ref, realization_graph=x.realization_graph,
                                                control_graph=x.control_graph, realization=x.realization, control=x.control)
