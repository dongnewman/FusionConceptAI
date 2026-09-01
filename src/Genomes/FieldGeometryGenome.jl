struct FieldGeometryGenomeV4
    seed::UInt64
    contract_ref::GenomeContractRef
    graph::TypedOperatorHypergraphV1
    fields::Tuple
end

function FieldGeometryGenomeV4(seed::Integer, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1; fields=())
    FieldGeometryGenomeV4(UInt64(seed), contract_ref, graph, Tuple(fields))
end
semantic_view(x::FieldGeometryGenomeV4) = (contract_ref=x.contract_ref, graph=x.graph, fields=x.fields)
