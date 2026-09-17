"""Typed admission request for a real external physical provider. No execution or evidence."""

struct _PhysicalProviderAdmissionToken end
const _PPA_TOKEN = _PhysicalProviderAdmissionToken()

struct PhysicalObservableRequirementV4
    name::String
    graph_binding_hash::Digest256
    subject_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    requirement_hash::Digest256
    function PhysicalObservableRequirementV4(::_PhysicalProviderAdmissionToken, a...)
        new(a...)
    end
end
PhysicalObservableRequirementV4(a...) = throw(ArgumentError("sealed physical requirement"))
semantic_view(x::PhysicalObservableRequirementV4) = (name=x.name,
    graph_binding_hash=x.graph_binding_hash, subject_hash=x.subject_hash,
    mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
    scenario_hash=x.scenario_hash)
canonical_hash(x::PhysicalObservableRequirementV4) = x.requirement_hash

struct PhysicalProviderAdmissionV4
    context_hash::Digest256
    contract_hash::Digest256
    provider::ProviderManifestV4
    requirements::Tuple
    independence_group::String
    status::Symbol
    gaps::Tuple
    admission_hash::Digest256
    function PhysicalProviderAdmissionV4(::_PhysicalProviderAdmissionToken, a...)
        new(a...)
    end
end
PhysicalProviderAdmissionV4(a...) = throw(ArgumentError("sealed provider admission"))
semantic_view(x::PhysicalProviderAdmissionV4) = (context_hash=x.context_hash,
    contract_hash=x.contract_hash, provider=x.provider,
    requirement_hashes=Tuple(canonical_hash(r) for r in x.requirements),
    independence_group=x.independence_group, status=x.status, gaps=x.gaps)
canonical_hash(x::PhysicalProviderAdmissionV4) = x.admission_hash

function _ppa_requirements(context, contract)
    graph = forward_graph_binding(context, :control)
    isempty(graph.node_identity_hashes) && throw(ArgumentError("control graph has no nodes"))
    req = PhysicalObservableRequirementV4[]
    for (i, h) in enumerate(graph.node_identity_hashes)
        push!(req, PhysicalObservableRequirementV4(_PPA_TOKEN,
            "control_node_$i", canonical_hash(graph), context.subject.physical_subject_hash,
            _runtime_decl_hash(context.mission_payload), _runtime_decl_hash(context.bounds_payload),
            context.scenario_hash, canonical_hash((role=:control, position=i, node_hash=h,
                subject=context.subject.physical_subject_hash,
                mission=_runtime_decl_hash(context.mission_payload),
                bounds=_runtime_decl_hash(context.bounds_payload), scenario=context.scenario_hash))))
    end
    Tuple(req)
end

function admit_physical_provider(context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4, provider::ProviderManifestV4)
    validate_forward_chain_context(context)
    validate_conservative_multiregion_contract(context, contract)
    provider.claim_ceiling === screen_only || throw(ArgumentError("physical admission is screen-only"))
    provider.backend_revision isa String && provider.code_hash isa Digest256 &&
        provider.input_schema_hash == provider.capability.input_schema_hash ||
        throw(ArgumentError("provider backend/code identity incomplete"))
    requirements = _ppa_requirements(context, contract)
    gaps = String[]
    provider.independence_group == "manufactured-control" &&
        push!(gaps, "provider cannot use manufactured-control independence group")
    status = isempty(gaps) ? :admitted : :recoverable_gap
    body = (context_hash=context.context_hash, contract_hash=canonical_hash(contract),
        provider=provider, requirement_hashes=Tuple(canonical_hash(r) for r in requirements),
        independence_group=provider.independence_group, status=status, gaps=Tuple(gaps))
    PhysicalProviderAdmissionV4(_PPA_TOKEN, context.context_hash, canonical_hash(contract),
        provider, requirements, provider.independence_group, status, Tuple(gaps), canonical_hash(body))
end

function validate_physical_provider_admission(admission::PhysicalProviderAdmissionV4,
        context::ForwardChainContextV4, contract::ConservativeMultiRegionContractV4,
        provider::ProviderManifestV4)
    validate_forward_chain_context(context)
    validate_conservative_multiregion_contract(context, contract)
    admission.context_hash == context.context_hash && admission.contract_hash == canonical_hash(contract) &&
        admission.provider === provider && admission.status in (:admitted, :recoverable_gap) || return false
    expected = admit_physical_provider(context, contract, provider)
    admission.admission_hash == expected.admission_hash && admission.gaps == expected.gaps
end
validate_physical_provider_admission(::PhysicalProviderAdmissionV4) = false
