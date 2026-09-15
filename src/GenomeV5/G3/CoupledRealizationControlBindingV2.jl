"""Typed cross-layer and realization-control coupling for G3 V5."""

const _G3_V5_FEEDBACK_KINDS = (:implementation_error, :loss, :thermal_load,
                               :deformation)

struct G3ControlResourceLinkV2
    link_id::String
    controller_id::String
    sensor_port_id::String
    actuator_port_id::String
    resource_port_id::String
    fault_id::String
    function G3ControlResourceLinkV2(link_id::Any, controller_id::Any,
            sensor_port_id::Any, actuator_port_id::Any, resource_port_id::Any,
            fault_id::Any)
        new(_g3_text(link_id, "control link_id"), _g3_text(controller_id, "link controller_id"),
            _g3_text(sensor_port_id, "link sensor_port_id"), _g3_text(actuator_port_id, "link actuator_port_id"),
            _g3_text(resource_port_id, "link resource_port_id"), _g3_text(fault_id, "link fault_id"))
    end
end

struct G3FeedbackChannelV2
    feedback_id::String
    target_layer::Symbol
    target_contract_ref::GenomeContractRef
    channel::Symbol
    unit::UnitSignature
    kind::Symbol
    source_id::String
    function G3FeedbackChannelV2(feedback_id::Any, target_layer::Any,
            target_contract_ref::Any, channel::Any, unit::Any, kind::Any,
            source_id::Any)
        target_contract_ref isa GenomeContractRef ||
            throw(ArgumentError("feedback target requires GenomeContractRef"))
        unit isa UnitSignature || throw(ArgumentError("feedback unit must be UnitSignature"))
        layer = _g3_symbol(target_layer, (:G1, :G2), "feedback target_layer")
        k = _g3_symbol(kind, _G3_V5_FEEDBACK_KINDS, "feedback kind")
        new(_g3_text(feedback_id, "feedback_id"), layer, target_contract_ref,
            _g3_symbol(channel, (:residual, :loss, :heat, :shape), "feedback channel"),
            unit, k, _g3_text(source_id, "feedback source_id"))
    end
end

semantic_view(x::G3ControlResourceLinkV2) =
    (link_id=x.link_id, controller_id=x.controller_id, sensor_port_id=x.sensor_port_id,
     actuator_port_id=x.actuator_port_id, resource_port_id=x.resource_port_id,
     fault_id=x.fault_id)
semantic_view(x::G3FeedbackChannelV2) =
    (feedback_id=x.feedback_id, target_layer=x.target_layer,
     target_contract_ref=x.target_contract_ref, channel=x.channel, unit=x.unit,
     kind=x.kind, source_id=x.source_id)

"""Return structural feedback-target errors and unresolved external authority gaps.

`target_refs` is intentionally optional: G3 can check the target layer/URI/version
shape on its own, but only UP1-04, after loading the real public G1/G2 refs, may
close the schema/canonical/profile authority check.  A fixture or seed is never
treated as that authority.
"""
function _g3_validate_feedback_targets(feedback::Tuple; target_refs=nothing)
    errors = String[]
    gaps = String[]
    for item in feedback
        layer = item.target_layer
        expected_prefix = "fusionconceptai://GenomeV5/" * String(layer) * "/"
        startswith(item.target_contract_ref.uri, expected_prefix) ||
            push!(errors, "feedback_target_uri_layer_mismatch:" * item.feedback_id)
        item.target_contract_ref.version == "v5" ||
            push!(errors, "feedback_target_version_mismatch:" * item.feedback_id)
        item.target_contract_ref.compatibility_profile isa AbstractString &&
            !isempty(item.target_contract_ref.compatibility_profile) ||
            push!(errors, "feedback_target_profile_missing:" * item.feedback_id)

        expected = nothing
        if target_refs !== nothing
            expected = if target_refs isa NamedTuple && hasproperty(target_refs, layer)
                getproperty(target_refs, layer)
            elseif target_refs isa AbstractDict && (haskey(target_refs, layer) || haskey(target_refs, String(layer)))
                haskey(target_refs, layer) ? target_refs[layer] : target_refs[String(layer)]
            else
                nothing
            end
            expected isa GenomeContractRef ||
                push!(errors, "feedback_target_authority_missing:" * item.feedback_id)
            expected isa GenomeContractRef && item.target_contract_ref == expected ||
                push!(errors, "feedback_target_authority_mismatch:" * item.feedback_id)
        end
        # Equality of supplied values does not establish provenance, same-candidate
        # four-axis binding, or the UP1-04 integrated join.
        push!(gaps, "feedback_authority_gap:" * item.feedback_id * ":" * String(layer))
    end
    unique!(errors); unique!(gaps)
    errors, gaps
end

struct CoupledRealizationControlBindingV2
    contract_binding::G3ContractBindingV2
    realization_binding::G3ContractBindingV2
    control_binding::G3ContractBindingV2
    links::Tuple{Vararg{G3ControlResourceLinkV2}}
    feedback::Tuple{Vararg{G3FeedbackChannelV2}}
    binding_hash::Digest256
    function CoupledRealizationControlBindingV2(contract_binding::Any,
            realization_binding::Any, control_binding::Any, links::Any, feedback::Any)
        contract_binding isa G3ContractBindingV2 || throw(ArgumentError("coupled binding requires its own contract ref"))
        realization_binding isa G3ContractBindingV2 || throw(ArgumentError("coupled binding requires realization child ref"))
        control_binding isa G3ContractBindingV2 || throw(ArgumentError("coupled binding requires control child ref"))
        _g3_validate_authoritative_ref(contract_binding.contract_ref, :binding)
        _g3_validate_authoritative_axes(contract_binding.version_axes, :binding)
        _g3_validate_authoritative_ref(realization_binding.contract_ref, :realization)
        _g3_validate_authoritative_axes(realization_binding.version_axes, :realization)
        _g3_validate_authoritative_ref(control_binding.contract_ref, :control)
        _g3_validate_authoritative_axes(control_binding.version_axes, :control)
        links_tuple = _g3_tuple(links, "coupled links")
        feedback_tuple = _g3_tuple(feedback, "coupled feedback")
        all(x -> x isa G3ControlResourceLinkV2, links_tuple) || throw(ArgumentError("invalid control-resource link"))
        all(x -> x isa G3FeedbackChannelV2, feedback_tuple) || throw(ArgumentError("invalid feedback channel"))
        candidate = contract_binding.candidate_ref
        realization_binding.candidate_ref == candidate && control_binding.candidate_ref == candidate ||
            throw(ArgumentError("G3 child candidate binding mismatch"))
        body = (contract_binding=contract_binding, realization_binding=realization_binding,
            control_binding=control_binding, links=Tuple(links_tuple), feedback=Tuple(feedback_tuple))
        new(contract_binding, realization_binding, control_binding, Tuple(links_tuple),
            Tuple(feedback_tuple), canonical_hash(body))
    end
end

semantic_view(x::CoupledRealizationControlBindingV2) =
    (contract_binding=x.contract_binding, realization_binding=x.realization_binding,
     control_binding=x.control_binding, links=x.links, feedback=x.feedback,
     binding_hash=x.binding_hash)

function g3_validate_binding(binding::CoupledRealizationControlBindingV2,
        realization::RealizationGenomeV5, control::ControlGenomeV5; target_refs=nothing)
    errors = String[]
    canonical_hash(binding.contract_binding.contract_ref) == canonical_hash(g3_contract_ref(:binding)) ||
        push!(errors, "binding_contract_ref_mismatch")
    canonical_hash(binding.realization_binding.contract_ref) == canonical_hash(g3_contract_ref(:realization)) ||
        push!(errors, "realization_contract_ref_not_authoritative")
    canonical_hash(binding.control_binding.contract_ref) == canonical_hash(g3_contract_ref(:control)) ||
        push!(errors, "control_contract_ref_not_authoritative")
    canonical_hash(binding.realization_binding) == canonical_hash(realization.contract_binding) ||
        push!(errors, "realization_child_ref_mismatch")
    canonical_hash(binding.control_binding) == canonical_hash(control.contract_binding) ||
        push!(errors, "control_child_ref_mismatch")
    ids = Tuple(x.link_id for x in binding.links)
    length(unique(ids)) == length(ids) || push!(errors, "duplicate_control_resource_link")
    feedback_ids = Tuple(x.feedback_id for x in binding.feedback)
    length(unique(feedback_ids)) == length(feedback_ids) || push!(errors, "duplicate_feedback_id")
    controller_ids = Set(x.controller_id for x in control.controllers)
    controller_map = Dict(x.controller_id => x for x in control.controllers)
    signal_ids = Set(x.port_id for x in control.signal_ports)
    fault_ids = Set(x.fault_id for x in control.faults)
    resource_map = Dict(x.port_id => x for x in realization.network.resource_ports)
    resource_ids = Set(keys(resource_map))
    for link in binding.links
        link.controller_id in controller_ids || push!(errors, "link_controller_missing:" * link.link_id)
        link.sensor_port_id in signal_ids || push!(errors, "link_sensor_missing:" * link.link_id)
        link.actuator_port_id in signal_ids || push!(errors, "link_actuator_missing:" * link.link_id)
        link.resource_port_id in resource_ids || push!(errors, "link_resource_port_missing:" * link.link_id)
        if haskey(resource_map, link.resource_port_id)
            resource_map[link.resource_port_id].direction in (:out, :bidirectional) ||
                push!(errors, "link_resource_direction_invalid:" * link.link_id)
        end
        link.fault_id in fault_ids || push!(errors, "link_fault_missing:" * link.link_id)
        if haskey(controller_map, link.controller_id)
            controller = controller_map[link.controller_id]
            link.sensor_port_id in controller.sensor_port_ids || push!(errors, "link_sensor_not_owned:" * link.link_id)
            link.actuator_port_id in controller.actuator_port_ids || push!(errors, "link_actuator_not_owned:" * link.link_id)
            link.resource_port_id in controller.actuator_resource_port_ids ||
                push!(errors, "link_resource_not_owned:" * link.link_id)
            link.fault_id in controller.fault_ids || push!(errors, "link_fault_not_owned:" * link.link_id)
        end
    end
    for feedback in binding.feedback
        feedback.source_id in resource_ids || feedback.source_id in signal_ids ||
            push!(errors, "feedback_source_missing:" * feedback.feedback_id)
    end
    feedback_errors, feedback_gaps = _g3_validate_feedback_targets(binding.feedback;
        target_refs=target_refs)
    append!(errors, feedback_errors)
    unique!(errors); unique!(feedback_gaps)
    errors, feedback_gaps
end

"""Compare supplied feedback refs by value; this never closes authority gaps."""
function g3_compare_feedback_target_refs(binding::CoupledRealizationControlBindingV2,
        g1_ref::GenomeContractRef, g2_ref::GenomeContractRef)
    _g3_validate_feedback_targets(binding.feedback;
        target_refs=(G1=g1_ref, G2=g2_ref))
end
