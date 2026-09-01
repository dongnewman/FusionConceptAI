struct FieldGeometryGenomeV4
    seed::UInt64
    graph::TypedOperatorHypergraphV1
    fields::Tuple
end

FieldGeometryGenomeV4(seed::Integer, graph::TypedOperatorHypergraphV1; fields=()) =
    FieldGeometryGenomeV4(UInt64(seed), graph, Tuple(fields))
