"""G3 V5 bundle and fail-closed cross-layer admission."""

struct G3AdmissionResultV2
    structural_status::Symbol
    provider_match::Symbol
    resolution::Symbol
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    realization_plan_hash::Digest256
    control_plan_hash::Digest256
    binding_hash::Digest256
    candidate_hash::Digest256
end

semantic_view(x::G3AdmissionResultV2) =
    (structural_status=x.structural_status, provider_match=x.provider_match,
     resolution=x.resolution, errors=x.errors, gaps=x.gaps,
     realization_plan_hash=x.realization_plan_hash,
     control_plan_hash=x.control_plan_hash, binding_hash=x.binding_hash,
     candidate_hash=x.candidate_hash)

function _g3_bundle_errors(contract_binding::G3ContractBindingV2,
        realization::RealizationGenomeV5, control::ControlGenomeV5,
        binding::CoupledRealizationControlBindingV2)
    errors = String[]; gaps = String[]
    candidate = contract_binding.candidate_ref
    canonical_hash(contract_binding.contract_ref) == canonical_hash(g3_contract_ref(:bundle)) ||
        push!(errors, "bundle_contract_ref_not_authoritative")
    canonical_hash(realization.contract_binding.contract_ref) == canonical_hash(g3_contract_ref(:realization)) ||
        push!(errors, "realization_contract_ref_not_authoritative")
    canonical_hash(control.contract_binding.contract_ref) == canonical_hash(g3_contract_ref(:control)) ||
        push!(errors, "control_contract_ref_not_authoritative")
    canonical_hash(binding.contract_binding.contract_ref) == canonical_hash(g3_contract_ref(:binding)) ||
        push!(errors, "binding_contract_ref_not_authoritative")
    realization.contract_binding.candidate_ref == candidate || push!(errors, "realization_candidate_binding_mismatch")
    control.contract_binding.candidate_ref == candidate || push!(errors, "control_candidate_binding_mismatch")
    binding.contract_binding.candidate_ref == candidate || push!(errors, "binding_candidate_binding_mismatch")
    child_refs = (realization.contract_binding.contract_ref,
                  control.contract_binding.contract_ref,
                  binding.contract_binding.contract_ref)
    length(unique(canonical_hash.(child_refs))) == length(child_refs) ||
        push!(errors, "G3 child contract refs must be independent")
    append!(errors, g3_validate_resource_network(realization.network))
    material_ids = Set(x.material_id for x in realization.material_domains)
    manufacturing_ids = Set(x.process_id for x in realization.manufacturing_domains)
    for component in realization.network.components
        component.material_id in material_ids || push!(errors, "component_material_domain_missing:" * component.component_id)
        component.manufacturing_process_id in manufacturing_ids ||
            push!(errors, "component_manufacturing_domain_missing:" * component.component_id)
    end
    append!(errors, g3_validate_control(control))
    binding_errors, binding_gaps = g3_validate_binding(binding, realization, control)
    append!(errors, binding_errors)
    append!(gaps, binding_gaps)
    isempty(binding.links) && push!(errors, "open_loop_control_binding")
    resource_ports = realization.network.resource_ports
    effort_ports = Tuple(p for p in resource_ports if p.kind === :effort)
    flow_ports = Tuple(p for p in resource_ports if p.kind === :flow)
    effort_ids = Set(p.port_id for p in effort_ports)
    flow_ids = Set(p.port_id for p in flow_ports)
    any(any(id in effort_ids for id in component.resource_port_ids) &&
        any(id in flow_ids for id in component.resource_port_ids)
        for component in realization.network.components) ||
        push!(errors, "source_effort_flow_are_not_paired")
    for child in (realization, control)
        child.provider_match === :unique_match ||
            push!(gaps, "provider_match=" * String(child.provider_match) * ":" * child.contract_binding.contract_ref.uri)
    end
    unique!(errors); unique!(gaps)
    errors, gaps
end

struct RealizationControlGenomeV5
    contract_binding::G3ContractBindingV2
    realization::RealizationGenomeV5
    control::ControlGenomeV5
    binding::CoupledRealizationControlBindingV2
    admission::G3AdmissionResultV2
    candidate_hash::Digest256
    function RealizationControlGenomeV5(contract_binding::Any,
            realization::Any, control::Any, binding::Any)
        contract_binding isa G3ContractBindingV2 || throw(ArgumentError("G3 bundle requires G3ContractBindingV2"))
        realization isa RealizationGenomeV5 || throw(ArgumentError("G3 bundle requires realization child"))
        control isa ControlGenomeV5 || throw(ArgumentError("G3 bundle requires control child"))
        binding isa CoupledRealizationControlBindingV2 || throw(ArgumentError("G3 bundle requires coupled binding child"))
        errors, gaps = _g3_bundle_errors(contract_binding, realization, control, binding)
        structural = isempty(errors) ? :valid : :fail_closed
        provider = isempty(gaps) ? :unique_match : :no_match
        resolution = isempty(errors) ? (isempty(gaps) ? :resolved : :terminal_deferred) : :fail_closed
        body = (contract_binding=contract_binding, realization=realization,
            control=control, binding=binding)
        candidate_hash = canonical_hash(body)
        admission = G3AdmissionResultV2(structural, provider, resolution,
            Tuple(errors), Tuple(gaps), realization.plan_hash, control.plan_hash,
            binding.binding_hash, candidate_hash)
        new(contract_binding, realization, control, binding, admission, candidate_hash)
    end
end

semantic_view(x::RealizationControlGenomeV5) =
    (contract_binding=x.contract_binding, realization=x.realization,
     control=x.control, binding=x.binding, admission=x.admission,
     candidate_hash=x.candidate_hash)

g3_admission(bundle::RealizationControlGenomeV5) = bundle.admission
g3_candidate_hash(bundle::RealizationControlGenomeV5) = bundle.candidate_hash
g3_provider_resolution(bundle::RealizationControlGenomeV5) = bundle.admission.resolution

function g3_edit_component_capacity(bundle::RealizationControlGenomeV5,
        component_id::AbstractString, capacity::Union{Integer,Rational})
    realization = g3_edit_component_capacity(bundle.realization, component_id, capacity)
    RealizationControlGenomeV5(bundle.contract_binding, realization,
        bundle.control, bundle.binding)
end

function g3_edit_fault(bundle::RealizationControlGenomeV5, fault_id::AbstractString,
        mode::Symbol)
    control = g3_edit_fault(bundle.control, fault_id, mode)
    RealizationControlGenomeV5(bundle.contract_binding, bundle.realization,
        control, bundle.binding)
end
