struct MechanismGenomeV4
    seed::UInt64
    contract_ref::GenomeContractRef
    graph::TypedOperatorHypergraphV1
    invariants::Tuple
    observables::Tuple
    function MechanismGenomeV4(seed::UInt64, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1,
                               invariants::Tuple, observables::Tuple)
        deep_immutable((contract_ref=contract_ref, graph=graph, invariants=invariants, observables=observables)) ||
            throw(ArgumentError("MechanismGenome payload must be deeply immutable"))
        new(seed, contract_ref, graph, invariants, observables)
    end
end

function MechanismGenomeV4(seed::Integer, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1; invariants=(), observables=())
    MechanismGenomeV4(UInt64(seed), contract_ref, graph, Tuple(invariants), Tuple(observables))
end
semantic_view(x::MechanismGenomeV4) = (contract_ref=x.contract_ref, graph=x.graph, invariants=x.invariants, observables=x.observables)
