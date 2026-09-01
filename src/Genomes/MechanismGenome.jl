struct MechanismGenomeV4
    seed::UInt64
    contract_ref::GenomeContractRef
    graph::TypedOperatorHypergraphV1
    invariants::Tuple
    observables::Tuple
end

function MechanismGenomeV4(seed::Integer, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1; invariants=(), observables=())
    deep_immutable((graph=graph, invariants=Tuple(invariants), observables=Tuple(observables))) || throw(ArgumentError("MechanismGenome payload must be deeply immutable"))
    MechanismGenomeV4(UInt64(seed), contract_ref, graph, Tuple(invariants), Tuple(observables))
end
semantic_view(x::MechanismGenomeV4) = (contract_ref=x.contract_ref, graph=x.graph, invariants=x.invariants, observables=x.observables)
