struct MechanismGenomeV4
    seed::UInt64
    graph::TypedOperatorHypergraphV1
    invariants::Tuple
    observables::Tuple
end

MechanismGenomeV4(seed::Integer, graph::TypedOperatorHypergraphV1; invariants=(), observables=()) =
    MechanismGenomeV4(UInt64(seed), graph, Tuple(invariants), Tuple(observables))
