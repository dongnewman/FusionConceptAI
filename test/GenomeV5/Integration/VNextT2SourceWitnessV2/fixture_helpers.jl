using SHA
using Serialization
using FusionConceptAI

const SW_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const SW_G = FusionConceptAI

# This historical fixture file is definition-only when included.  It supplies
# the current real source-authority constructors without running its testsets.
Base.include(Main, joinpath(SW_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "Integration",
    "VNextParentBaselineBindingLocalV1.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "G3",
    "G3RealizationChildEditabilityV1.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "G3",
    "G3ControlChildEditabilityV1.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "G3",
    "G3BindingChildEditabilityV1.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "G3",
    "G3BindingChildEditabilityV2.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "Integration",
    "VNextG3BindingAuthorityBridgeLocalV1.jl"))
Base.include(SW_G, joinpath(SW_ROOT, "src", "GenomeV5", "Integration",
    "VNextT2SourceWitnessV2.jl"))

const SW_CANDIDATE = SW_G.QualifiedRefV1(
    "fusionconceptai://candidate/vnext-t2-source-witness-v2", "v5")
const SW_UNIT = SW_G.UnitSignature()
const SW_BASE_COMPONENTS = Ref{Any}(nothing)

function sw_child_fixture(layer::String)
    output = tempname()
    script = joinpath(SW_ROOT, "test", "GenomeV5", "UP1-04",
        "layer_fixture_child.jl")
    try
        run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
        open(output, "r") do io
            Serialization.deserialize(io)
        end
    finally
        isfile(output) && rm(output; force=true)
    end
end

function sw_base_components()
    SW_BASE_COMPONENTS[] === nothing || return SW_BASE_COMPONENTS[]
    SW_BASE_COMPONENTS[] = (g1=sw_child_fixture("G1"),
        g2=sw_child_fixture("G2"), g3=sw_child_fixture("G3"))
end

function sw_actual_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id,
        "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = SW_G.G1GenomeContractRefV2(uri, old.version, old.schema_hash,
        old.canonicalization_hash, old.compatibility_profile,
        old.version_axes, candidate.id;
        grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = SW_G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    outer = SW_G.g1_materialize_contract_ref(ref,
        base.payload.grammar_profile)
    SW_G.MechanismGenomeV5(outer, payload, base.version_axes)
end

function sw_actual_g2(base, candidate)
    uri = replace(candidate.id,
        "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = SW_G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash,
        base.contract_ref.compatibility_profile)
    SW_G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function sw_actual_g3(base, candidate, g1_ref, g2_ref)
    rb = SW_G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = SW_G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    coupled = SW_G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle = SW_G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = SW_G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=:no_match)
    control = SW_G.ControlGenomeV5(cb, base.control.signal_ports,
        base.control.controllers, base.control.faults, base.control.plan;
        provider_match=:no_match)
    feedback = Tuple(SW_G.G3FeedbackChannelV2(ch.feedback_id,
        ch.target_layer, ch.target_layer === :G1 ? g1_ref : g2_ref,
        ch.channel, ch.unit, ch.kind, ch.source_id)
        for ch in base.binding.feedback)
    binding = SW_G.CoupledRealizationControlBindingV2(coupled, rb, cb,
        base.binding.links, feedback)
    SW_G.RealizationControlGenomeV5(bundle, realization, control, binding)
end

function sw_concrete_package(candidate=SW_CANDIDATE)
    base = sw_base_components()
    g1 = sw_actual_g1(base.g1, candidate)
    g2 = sw_actual_g2(base.g2, candidate)
    g3 = sw_actual_g3(base.g3, candidate, g1.contract_ref, g2.contract_ref)
    SW_G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function sw_realization_state(candidate, g3;
        source=100, field=70, returned=20, heat=10)
    parent = g3.declaration_ref
    parent_hash = g3.declaration_identity_hash
    ports = (
        SW_G.G3RealizationSourcePortV1("source-port", :source, SW_UNIT,
            :out, 1, "source-witness-owner"),
        SW_G.G3RealizationSourcePortV1("field-port", :field, SW_UNIT,
            :in, 1, "source-witness-owner"),
        SW_G.G3RealizationSourcePortV1("return-port", :return, SW_UNIT,
            :in, 1, "source-witness-owner"),
        SW_G.G3RealizationSourcePortV1("heat-port", :heat, SW_UNIT,
            :in, 1, "source-witness-owner"))
    component = SW_G.G3RealizationComponentV1("source-witness-component",
        :source_component, Tuple(p.port_id for p in ports), 120, SW_UNIT,
        "source-witness-material", "source-witness-process")
    material = SW_G.G3RealizationMaterialDomainV1(
        "source-witness-material", :strength, 0, 10, SW_UNIT)
    process = SW_G.G3RealizationManufacturingDomainV1(
        "source-witness-process", :thickness, 1, 2, SW_UNIT)
    account = SW_G.G3RealizationLedgerAccountV1(
        "energy", :energy, SW_UNIT, "source-witness-owner")
    entries = (
        SW_G.G3RealizationLedgerEntryV1("source", "energy", "source-port",
            component.component_id, source, SW_UNIT, :source),
        SW_G.G3RealizationLedgerEntryV1("field", "energy", "field-port",
            component.component_id, -field, SW_UNIT, :load),
        SW_G.G3RealizationLedgerEntryV1("return", "energy", "return-port",
            component.component_id, -returned, SW_UNIT, :return),
        SW_G.G3RealizationLedgerEntryV1("heat", "energy", "heat-port",
            component.component_id, -heat, SW_UNIT, :heat_rejection))
    closure = SW_G.G3RealizationLedgerClosureV1("energy-close", :energy,
        ("energy",), 0)
    body = SW_G.G3RealizationSourceBodyV1("realization-child",
        "source-witness-owner", ports, source, field, returned, heat, 120,
        SW_UNIT, 0, (component,), (material,), (process,), (account,),
        entries, (closure,))
    record = SW_G.g3_realization_source_record_v1(candidate;
        schema_ref=SW_G.QualifiedRefV1("local://source-witness/schema/real", "v1"),
        schema_hash=SW_G.digest256_text("source-witness-schema-real"),
        canonicalization_ref=SW_G.QualifiedRefV1(
            "local://source-witness/canonical/real", "v1"),
        canonicalization_hash=SW_G.digest256_text(
            "source-witness-canonical-real"),
        profile_ref=SW_G.QualifiedRefV1(
            "local://source-witness/profile/real", "v1"),
        profile_hash=SW_G.digest256_text("source-witness-profile-real"),
        evidence_receipt_ref=SW_G.QualifiedRefV1(
            "local://source-witness/receipt/real", "v1"),
        evidence_receipt_hash=SW_G.digest256_text(
            "source-witness-receipt-real"))
    key = SW_G.G3RealizationChildKeyV1(candidate, parent_hash,
        :realization, body.source_id)
    payload = SW_G.g3_realization_source_payload_v1(key, parent, body, record)
    SW_G.g3_realization_initial_state_v1(key, payload)
end

function sw_control_state(candidate, g3)
    parent = g3.declaration_ref
    parent_hash = g3.declaration_identity_hash
    sensor = SW_G.G3ControlSignalV1("sensor", :sensor, :in, SW_UNIT,
        "sensor-owner")
    actuator = SW_G.G3ControlSignalV1("actuator", :command, :out, SW_UNIT,
        "actuator-owner")
    initial = SW_G.G3ControlInitialStateV1("initial", SW_UNIT, 0 // 1)
    event = SW_G.G3ControlEventV1("event", :initial, 0 // 1, :enable)
    controller = SW_G.G3ControlControllerV1("controller", ("sensor",),
        ("actuator",), ("actuator",), ("fault",), (initial,), (event,))
    fault = SW_G.G3ControlFaultV1("fault", "controller", :open_circuit,
        :trip, "sensor", 1 // 1)
    plan = SW_G.G3ControlPlanV1(("controller",),
        ("sensor", "actuator"), ("fault",))
    body = SW_G.G3ControlSourceBodyV1("control-child",
        "source-witness-owner", (sensor, actuator), (controller,),
        (fault,), plan)
    slot(kind, label) = SW_G.G3ControlProvenanceSlotV1(kind, :present,
        SW_G.QualifiedRefV1("local://source-witness/" * label, "v1"),
        "test/GenomeV5/Integration/VNextT2SourceWitnessV2/" * label,
        SW_G.digest256_text(label), candidate, nothing, nothing)
    slots = (slot(:payload_schema_version, "control-schema"),
        slot(:canonicalization_profile_version, "control-canonical"),
        slot(:applicability_profile_version, "control-profile"),
        slot(:evidence_receipt_version, "control-receipt"))
    record_body = (record_uri=SW_G.G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,
        record_version=SW_G.G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
        payload_schema_version=slots[1],
        canonicalization_profile_version=slots[2],
        applicability_profile_version=slots[3],
        evidence_receipt_version=slots[4])
    record = SW_G.G3ControlSourceRecordV1(record_body.record_uri,
        record_body.record_version, slots..., SW_G.canonical_hash(record_body))
    contract = SW_G.GenomeContractRef(
        SW_G.G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,
        SW_G.G3_CONTROL_CHILD_EDIT_VERSION_V1,
        SW_G.g3_control_child_edit_schema_hash_v1(),
        SW_G.g3_control_child_edit_canonicalization_hash_v1(),
        SW_G.G3_CONTROL_CHILD_EDIT_PROFILE_V1)
    key = SW_G.G3ControlChildKeyV1(candidate, parent_hash, :control,
        body.source_id)
    identity = SW_G.canonical_hash((child_contract_ref=contract,))
    record_ref = SW_G.G3ControlSourceRecordRefV1(record.record_uri,
        record.record_version, record.source_record_hash)
    content = SW_G.canonical_hash((key=key,
        parent_g3_declaration_ref=parent, child_contract_ref=contract,
        source_uri=record.record_uri, source_version=record.record_version,
        body=body, source_record_ref=record_ref))
    payload = SW_G.G3ControlSourcePayloadV1(key, parent, parent_hash,
        contract, identity, record.record_uri, record.record_version, body,
        record, content)
    SW_G.g3_control_initial_state_v1(key, payload)
end

function sw_t0_and_authority(candidate=SW_CANDIDATE; g2_variant=false,
        realization_source=100, realization_field=70,
        realization_return=20, realization_heat=10)
    g1 = Main._t0l_g1(candidate)
    g2 = Main._t0l_g2(candidate; variant=g2_variant)
    g3 = Main._t0l_g3(candidate)
    declarations = (
        Main._t0l_present(:G1, g1; candidate=candidate),
        Main._t0l_present(:G2, g2; candidate=candidate,
            path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        Main._t0l_present(:G3, g3; candidate=candidate,
            path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (Main._t0l_child(:realization; candidate=candidate),
        Main._t0l_child(:control; candidate=candidate),
        Main._t0l_child(:binding; candidate=candidate))
    targets = declarations[3].semantic_body.body.feedback_targets
    feedback = Tuple(Main._t0l_feedback(target.target_id,
        declarations[target.target_layer === :G1 ? 1 : 2].declaration_ref;
        target_layer=target.target_layer, candidate=candidate)
        for target in targets)
    admission = SW_G.vnext_declaration_transport_local_v1(candidate,
        declarations, children, feedback)
    transport = admission.transport
    recheck = SW_G.vnext_declaration_authority_recheck_local_v1(
        SW_G.VNextAuthorityRecheckLocalInputV1(candidate, transport,
            declarations))
    parent = SW_G.bind_local_parent_baseline_from_t0_v1(
        SW_G.T0LocalParentBaselineInputV1(candidate,
            (declarations[1], declarations[2])))
    checked_g3 = recheck.output.g3
    realization_state = sw_realization_state(candidate, checked_g3;
        source=realization_source, field=realization_field,
        returned=realization_return, heat=realization_heat)
    control_state = sw_control_state(candidate, checked_g3)
    realization_info, realization_error = SW_G._vnext_g3_state_info(
        realization_state, :realization, candidate,
        checked_g3.declaration_ref, checked_g3.declaration_identity_hash)
    realization_error === nothing || error(realization_error)
    control_info, control_error = SW_G._vnext_g3_state_info(control_state,
        :control, candidate, checked_g3.declaration_ref,
        checked_g3.declaration_identity_hash)
    control_error === nothing || error(control_error)
    realization_commitment = SW_G.VNextG3BindingChildExpectedCommitmentV1(
        realization_info.child_kind, realization_info.candidate_ref,
        realization_info.parent_g3_declaration_ref,
        realization_info.parent_g3_declaration_hash,
        realization_info.child_ref, realization_info.contract_ref,
        realization_info.source_record_ref, realization_info.source_record_hash,
        realization_info.source_content_hash,
        realization_info.child_identity_hash, realization_info.state_hash)
    control_commitment = SW_G.VNextG3BindingChildExpectedCommitmentV1(
        control_info.child_kind, control_info.candidate_ref,
        control_info.parent_g3_declaration_ref,
        control_info.parent_g3_declaration_hash, control_info.child_ref,
        control_info.contract_ref, control_info.source_record_ref,
        control_info.source_record_hash, control_info.source_content_hash,
        control_info.child_identity_hash, control_info.state_hash)
    expected = SW_G.vnext_g3_binding_expected_commitment_v1(candidate,
        recheck.output.bundle_hash, checked_g3.declaration_ref,
        checked_g3.declaration_identity_hash, realization_commitment,
        control_commitment)
    key = SW_G.G3BindingChildKeyV2(candidate, checked_g3.declaration_ref,
        checked_g3.declaration_identity_hash, :binding,
        "source-witness-binding-v2")
    links = Tuple(SW_G.G3BindingLinkV1(target.target_id,
        target.target_layer, target.target_path, target.quantity, target.unit,
        target.direction, target.sign, target.source_id, target.owner_scope,
        target.authority) for target in targets)
    bridge = SW_G.vnext_g3_binding_authority_bridge_local_v1(recheck,
        expected, realization_state, control_state, key; initial_links=links)
    (declarations=declarations, children=children, feedback=feedback,
     transport=transport, recheck=recheck, parent=parent,
     realization_state=realization_state, control_state=control_state,
     expected=expected, bridge=bridge)
end

function sw_fixture(; candidate=SW_CANDIDATE, g2_variant=false,
        realization_source=100, realization_field=70,
        realization_return=20, realization_heat=10)
    package = sw_concrete_package(candidate)
    chain = sw_t0_and_authority(candidate; g2_variant=g2_variant,
        realization_source=realization_source,
        realization_field=realization_field,
        realization_return=realization_return,
        realization_heat=realization_heat)
    built = SW_G.prepare_vnext_t2_source_witness_v2(package,
        chain.transport, chain.recheck, chain.parent, chain.expected,
        chain.bridge)
    merge((package=package,), chain, (built=built, witness=built.witness))
end

function sw_rehash_witness(witness;
        g1=witness.g1, g2=witness.g2, g3=witness.g3,
        t0_recheck=witness.t0_recheck,
        parent_authority=witness.parent_authority,
        g3_authority=witness.g3_authority,
        child_links=witness.child_links,
        feedback_links=witness.feedback_links,
        source_bundle_hash=witness.source_bundle_hash,
        source_identity_hash=witness.source_identity_hash,
        formal_t1=witness.formal_t1,
        formal_consumer_counts=witness.formal_consumer_counts,
        source_status=witness.source_status,
        resolution=witness.resolution,
        formal_node_accepted=witness.formal_node_accepted,
        gaps=witness.gaps)
    body = SW_G._vnext_t2_sw_witness_body_v2(witness.candidate_ref,
        witness.concrete_package_hash, g1, g2, g3, t0_recheck,
        parent_authority, g3_authority, child_links, feedback_links,
        source_bundle_hash, source_identity_hash, formal_t1,
        formal_consumer_counts, source_status, resolution,
        formal_node_accepted, gaps)
    SW_G.VNextT2SourceWitnessV2(witness.schema_id,
        witness.schema_version, witness.profile, witness.candidate_ref,
        witness.concrete_package, g1, g2, g3, t0_recheck,
        parent_authority, g3_authority, child_links, feedback_links,
        source_bundle_hash, witness.concrete_package_hash,
        source_identity_hash, formal_t1, formal_consumer_counts,
        source_status, resolution, formal_node_accepted, gaps,
        SW_G.canonical_hash(body))
end
