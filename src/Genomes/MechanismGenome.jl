struct LegacyMechanismGenomeV4
    seed::UInt64
    contract_ref::GenomeContractRef
    graph::TypedOperatorHypergraphV1
    invariants::Tuple
    observables::Tuple
    function LegacyMechanismGenomeV4(seed::UInt64, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1,
                               invariants::Tuple, observables::Tuple)
        deep_immutable((contract_ref=contract_ref, graph=graph, invariants=invariants, observables=observables)) ||
            throw(ArgumentError("MechanismGenome payload must be deeply immutable"))
        is_canonical_value((contract_ref=contract_ref, graph=graph, invariants=invariants, observables=observables)) ||
            throw(ArgumentError("MechanismGenome payload is not canonicalizable"))
        new(seed, contract_ref, graph, invariants, observables)
    end
end

function LegacyMechanismGenomeV4(seed::Integer, contract_ref::GenomeContractRef, graph::TypedOperatorHypergraphV1; invariants=(), observables=())
    LegacyMechanismGenomeV4(UInt64(seed), contract_ref, graph, Tuple(invariants), Tuple(observables))
end
semantic_view(x::LegacyMechanismGenomeV4) = (contract_ref=x.contract_ref, graph=x.graph, invariants=x.invariants, observables=x.observables)

struct MechanismGenomeV4
    seed::UInt64
    contract_ref::GenomeContractRef
    payload::MechanismGenomePayloadV1
    canonical::CanonicalMechanismV1
    function MechanismGenomeV4(seed::UInt64, contract_ref::GenomeContractRef,
                                payload::MechanismGenomePayloadV1,
                                canonical::CanonicalMechanismV1, ::Val{:sealed})
        canonical.transport.context.contract_ref == contract_ref ||
            throw(ArgumentError("canonical mechanism contract does not match genome contract"))
        expected = canonicalize_mechanism(payload, canonical.transport.context)
        expected.transport.canonical_bytes == canonical.transport.canonical_bytes &&
            expected.hashes == canonical.hashes ||
            throw(ArgumentError("canonical mechanism does not exactly derive from payload and context"))
        new(seed, contract_ref, payload, canonical)
    end
end

function MechanismGenomeV4(seed::Integer, contract_ref::GenomeContractRef,
                           payload::MechanismGenomePayloadV1;
                           profile::CanonicalizationProfileV1=default_canonicalization_profile())
    canonical = canonicalize_mechanism(payload, contract_ref; profile=profile)
    MechanismGenomeV4(UInt64(seed), contract_ref, payload, canonical, Val(:sealed))
end

semantic_view(x::MechanismGenomeV4) =
    (contract_ref=x.contract_ref,
     canonicalization_profile_hash=x.canonical.hashes.canonicalization_profile_hash,
     operator_registry_hash=x.canonical.hashes.operator_registry_hash,
     decorated_mechanism_hash=x.canonical.hashes.decorated_mechanism_hash,
     candidate_subject_hash=x.canonical.hashes.candidate_subject_hash)
