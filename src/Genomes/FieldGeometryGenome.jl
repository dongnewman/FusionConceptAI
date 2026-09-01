struct FieldGeometryGenomeV4
    seed::UInt64
    contract_ref::GenomeContractRef
    graph::TypedOperatorHypergraphV1
    fields::Tuple
    function FieldGeometryGenomeV4(seed::UInt64, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1, fields::Tuple)
        deep_immutable((contract_ref=contract_ref, graph=graph, fields=fields)) ||
            throw(ArgumentError("FieldGeometryGenome payload must be deeply immutable"))
        new(seed, contract_ref, graph, fields)
    end
end

function FieldGeometryGenomeV4(seed::Integer, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1; fields=())
    FieldGeometryGenomeV4(UInt64(seed), contract_ref, graph, Tuple(fields))
end
semantic_view(x::FieldGeometryGenomeV4) = (contract_ref=x.contract_ref, graph=x.graph, fields=x.fields)
