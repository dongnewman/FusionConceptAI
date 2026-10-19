using SHA
using Serialization
using FusionConceptAI

const V3_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const V3_G = FusionConceptAI

const V3_TRACE_ENABLED =
    get(ENV, "VNEXT_T2_SOURCE_WITNESS_TRACE", "0") == "1"
const V3_TRACE_EPOCH_NS = time_ns()

function v3_trace(stage::AbstractString; bytes=nothing)
    V3_TRACE_ENABLED || return nothing
    elapsed_ms = div(time_ns() - V3_TRACE_EPOCH_NS, 1_000_000)
    bytes_text = bytes === nothing ? "" : " bytes=$(bytes)"
    println("V3_STAGE stage=", stage, " elapsed_ms=", elapsed_ms, bytes_text)
    flush(stdout)
    nothing
end

v3_trace("fixture.includes.begin")

# Definition-only reuse of the real T0 source constructors.  Its guarded
# testsets do not run when included, and this V3 fixture starts no child Julia
# process to manufacture unrelated legacy Genome objects.
Base.include(Main, joinpath(V3_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV2.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "Integration",
    "VNextParentBaselineBindingLocalV1.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "G3",
    "G3RealizationChildEditabilityV1.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "G3",
    "G3ControlChildEditabilityV1.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "G3",
    "G3BindingChildEditabilityV1.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "G3",
    "G3BindingChildEditabilityV2.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "Integration",
    "VNextG3BindingAuthorityBridgeLocalV1.jl"))
Base.include(V3_G, joinpath(V3_ROOT, "src", "GenomeV5", "Integration",
    "VNextT2ConcreteSourceWitnessV3.jl"))

v3_trace("fixture.includes.complete")

const V3_CANDIDATE = V3_G.QualifiedRefV1(
    "fusionconceptai://candidate/vnext-t2-concrete-source-witness-v3", "v5")

function v3_realization_state(candidate, g3_record;
        source=100, field=70, returned=20, heat=10,
        unit=V3_G.UnitSignature())
    parent = g3_record.declaration_ref
    parent_hash = g3_record.declaration_identity_hash
    owner = "source-witness-owner"
    ports = (
        V3_G.G3RealizationSourcePortV1("source-port", :source, unit,
            :out, 1, owner),
        V3_G.G3RealizationSourcePortV1("field-port", :field, unit,
            :in, 1, owner),
        V3_G.G3RealizationSourcePortV1("return-port", :return, unit,
            :in, 1, owner),
        V3_G.G3RealizationSourcePortV1("heat-port", :heat, unit,
            :in, 1, owner))
    component = V3_G.G3RealizationComponentV1("source-witness-component",
        :source_component, Tuple(p.port_id for p in ports), 120, unit,
        "source-witness-material", "source-witness-process")
    material = V3_G.G3RealizationMaterialDomainV1(
        "source-witness-material", :strength, 0, 10, unit)
    process = V3_G.G3RealizationManufacturingDomainV1(
        "source-witness-process", :thickness, 1, 2, unit)
    account = V3_G.G3RealizationLedgerAccountV1(
        "energy", :energy, unit, owner)
    entries = (
        V3_G.G3RealizationLedgerEntryV1("source", "energy", "source-port",
            component.component_id, source, unit, :source),
        V3_G.G3RealizationLedgerEntryV1("field", "energy", "field-port",
            component.component_id, -field, unit, :load),
        V3_G.G3RealizationLedgerEntryV1("return", "energy", "return-port",
            component.component_id, -returned, unit, :return),
        V3_G.G3RealizationLedgerEntryV1("heat", "energy", "heat-port",
            component.component_id, -heat, unit, :heat_rejection))
    closure = V3_G.G3RealizationLedgerClosureV1(
        "energy-close", :energy, ("energy",), 0)
    body = V3_G.G3RealizationSourceBodyV1("realization-child", owner,
        ports, source, field, returned, heat, 120, unit, 0,
        (component,), (material,), (process,), (account,), entries, (closure,))
    record = V3_G.g3_realization_source_record_v1(candidate;
        schema_ref=V3_G.QualifiedRefV1("local://source-witness-v3/schema/real", "v1"),
        schema_hash=V3_G.digest256_text("source-witness-v3-schema-real"),
        canonicalization_ref=V3_G.QualifiedRefV1(
            "local://source-witness-v3/canonical/real", "v1"),
        canonicalization_hash=V3_G.digest256_text(
            "source-witness-v3-canonical-real"),
        profile_ref=V3_G.QualifiedRefV1(
            "local://source-witness-v3/profile/real", "v1"),
        profile_hash=V3_G.digest256_text("source-witness-v3-profile-real"),
        evidence_receipt_ref=V3_G.QualifiedRefV1(
            "local://source-witness-v3/receipt/real", "v1"),
        evidence_receipt_hash=V3_G.digest256_text(
            "source-witness-v3-receipt-real"))
    key = V3_G.G3RealizationChildKeyV1(candidate, parent_hash,
        :realization, body.source_id)
    payload = V3_G.g3_realization_source_payload_v1(key, parent, body, record)
    V3_G.g3_realization_initial_state_v1(key, payload)
end

function v3_control_material(candidate, g3_record; variant=false)
    parent = g3_record.declaration_ref
    parent_hash = g3_record.declaration_identity_hash
    unit = V3_G.UnitSignature()
    sensor = V3_G.G3ControlSignalV1("sensor", :sensor, :in, unit,
        "sensor-owner")
    actuator = V3_G.G3ControlSignalV1("actuator", :command, :out, unit,
        "actuator-owner")
    initial = V3_G.G3ControlInitialStateV1("initial", unit, 0 // 1)
    event = V3_G.G3ControlEventV1("event", :initial, 0 // 1, :enable)
    controller = V3_G.G3ControlControllerV1("controller", ("sensor",),
        ("actuator",), ("actuator",), ("fault",), (initial,), (event,))
    fault = V3_G.G3ControlFaultV1("fault", "controller", :open_circuit,
        :trip, "sensor", variant ? 2 // 1 : 1 // 1)
    plan = V3_G.G3ControlPlanV1(("controller",),
        ("sensor", "actuator"), ("fault",))
    body = V3_G.G3ControlSourceBodyV1("control-child",
        "source-witness-owner", (sensor, actuator), (controller,),
        (fault,), plan)
    slot(kind, label) = V3_G.G3ControlProvenanceSlotV1(kind, :present,
        V3_G.QualifiedRefV1("local://source-witness-v3/" * label, "v1"),
        "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/" * label,
        V3_G.digest256_text(label), candidate, nothing, nothing)
    slots = (slot(:payload_schema_version, "control-schema"),
        slot(:canonicalization_profile_version, "control-canonical"),
        slot(:applicability_profile_version, "control-profile"),
        slot(:evidence_receipt_version, "control-receipt"))
    record_body = (record_uri=V3_G.G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,
        record_version=V3_G.G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
        payload_schema_version=slots[1],
        canonicalization_profile_version=slots[2],
        applicability_profile_version=slots[3],
        evidence_receipt_version=slots[4])
    record = V3_G.G3ControlSourceRecordV1(record_body.record_uri,
        record_body.record_version, slots..., V3_G.canonical_hash(record_body))
    contract = V3_G.GenomeContractRef(
        V3_G.G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,
        V3_G.G3_CONTROL_CHILD_EDIT_VERSION_V1,
        V3_G.g3_control_child_edit_schema_hash_v1(),
        V3_G.g3_control_child_edit_canonicalization_hash_v1(),
        V3_G.G3_CONTROL_CHILD_EDIT_PROFILE_V1)
    key = V3_G.G3ControlChildKeyV1(candidate, parent_hash, :control,
        body.source_id)
    identity = V3_G.canonical_hash((child_contract_ref=contract,))
    record_ref = V3_G.G3ControlSourceRecordRefV1(record.record_uri,
        record.record_version, record.source_record_hash)
    content = V3_G.canonical_hash((key=key,
        parent_g3_declaration_ref=parent, child_contract_ref=contract,
        source_uri=record.record_uri, source_version=record.record_version,
        body=body, source_record_ref=record_ref))
    payload = V3_G.G3ControlSourcePayloadV1(key, parent, parent_hash,
        contract, identity, record.record_uri, record.record_version, body,
        record, content)
    state = V3_G.g3_control_initial_state_v1(key, payload)
    (payload=payload, state=state)
end

function v3_chain(; candidate=V3_CANDIDATE, g2_variant=false,
        coherent_g3_child=false, edited_realization=false)
    v3_trace("chain.begin")
    g1_declaration = Main._t0l_g1(candidate)
    g2_declaration = Main._t0l_g2(candidate; variant=g2_variant)
    g3_declaration = Main._t0l_g3(candidate)
    v3_trace("chain.native_declarations.complete")
    declarations = (
        Main._t0l_present(:G1, g1_declaration; candidate=candidate,
            case_id="g1_clean"),
        Main._t0l_present(:G2, g2_declaration; candidate=candidate,
            path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
            case_id="g2_clean"),
        Main._t0l_present(:G3, g3_declaration; candidate=candidate,
            path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl",
            case_id="g3_feedback_clean"))
    source_bytes = sum(length(record.source_bytes.bytes) +
        length(record.declaration_bytes.bytes) for record in declarations)
    v3_trace("chain.t0_records.complete"; bytes=source_bytes)
    children = (Main._t0l_child(:realization; candidate=candidate),
        Main._t0l_child(:control; candidate=candidate),
        Main._t0l_child(:binding; candidate=candidate))
    targets = declarations[3].semantic_body.body.feedback_targets
    feedback = Tuple(Main._t0l_feedback(target.target_id,
        declarations[target.target_layer === :G1 ? 1 : 2].declaration_ref;
        target_layer=target.target_layer, candidate=candidate)
        for target in targets)
    admission = V3_G.vnext_declaration_transport_local_v1(candidate,
        declarations, children, feedback;
        frozen_contexts=Main._T0L_CONTEXTS)
    transport = admission.transport
    v3_trace("chain.transport.complete"; bytes=source_bytes)
    recheck = V3_G.vnext_declaration_authority_recheck_local_v1(
        V3_G.VNextAuthorityRecheckLocalInputV1(candidate, transport,
            declarations))
    v3_trace("chain.recheck.complete"; bytes=source_bytes)
    parent = V3_G.bind_local_parent_baseline_from_t0_v1(
        V3_G.T0LocalParentBaselineInputV1(candidate,
            (declarations[1], declarations[2])))
    v3_trace("chain.parent.complete"; bytes=source_bytes)
    g3_record = recheck.output.g3
    realization_initial = if coherent_g3_child
        unit = only(endpoint.unit for endpoint in g3_declaration.endpoints
            if endpoint.role === :source)
        v3_realization_state(candidate, g3_record; source=100,
            field=75, returned=25 // 2, heat=25 // 2, unit=unit)
    else
        v3_realization_state(candidate, g3_record)
    end
    v3_trace("chain.realization_initial.complete")
    realization_edit_operation = nothing
    realization_edit_receipt = nothing
    realization = realization_initial
    if edited_realization
        replacement_state = v3_realization_state(candidate, g3_record;
            source=100, field=65, returned=20, heat=15,
            unit=realization_initial.payload.body.capacity_unit)
        replacement = replacement_state.payload
        record = replacement.source_record
        record_ref = V3_G.G3RealizationSourceRecordRefV1(record.source_uri,
            record.source_version, record.source_record_hash)
        realization_edit_operation = V3_G.g3_realization_replace_operation_v1(
            "v3-realization-edit", realization_initial.key,
            realization_initial.state_hash,
            realization_initial.source_content_hash, replacement, record_ref)
        edited = V3_G.g3_realization_replace_source_payload_v1(
            realization_initial, realization_edit_operation)
        edited.status === :applied || error((:realization_edit_failed,
            edited.status, edited.errors))
        realization = edited.state
        realization_edit_receipt = edited.receipt
        v3_trace("chain.realization_edit.complete")
    end
    control = v3_control_material(candidate, g3_record)
    v3_trace("chain.control.complete")
    projection = V3_G.vnext_t2_g3_current_state_projection_v3(candidate,
        g3_record.declaration_ref, g3_record.declaration_identity_hash,
        realization, control.payload, control.state)
    v3_trace("chain.projection.complete")
    expected = V3_G.vnext_g3_binding_expected_commitment_v1(candidate,
        recheck.output.bundle_hash, g3_record.declaration_ref,
        g3_record.declaration_identity_hash, projection.realization,
        projection.control)
    v3_trace("chain.expected.complete")
    binding_key = V3_G.G3BindingChildKeyV2(candidate,
        g3_record.declaration_ref, g3_record.declaration_identity_hash,
        :binding, "source-witness-binding-v3")
    links = Tuple(V3_G.G3BindingLinkV1(target.target_id,
        target.target_layer, target.target_path, target.quantity, target.unit,
        target.direction, target.sign, target.source_id, target.owner_scope,
        target.authority) for target in targets)
    bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(recheck,
        expected, realization, control.payload, control.state, binding_key;
        initial_links=links)
    v3_trace("chain.bridge.complete")
    v3_trace("chain.prepare.begin")
    built = V3_G.prepare_vnext_t2_concrete_source_witness_v3(transport,
        recheck, parent, expected, bridge, realization, control.payload,
        control.state, binding_key)
    v3_trace("chain.prepare.complete")
    (g1_declaration=g1_declaration, g2_declaration=g2_declaration,
     g3_declaration=g3_declaration, declarations=declarations,
     children=children, feedback=feedback, transport=transport,
      recheck=recheck, parent=parent,
      realization_initial_state=realization_initial,
      realization_edit_operation=realization_edit_operation,
      realization_edit_receipt=realization_edit_receipt,
      realization_state=realization,
      control_payload=control.payload, control_state=control.state,
      projection=projection, expected=expected, binding_key=binding_key,
      bridge=bridge,
     built=built, witness=built.witness)
end

function v3_validate(chain, witness=chain.witness)
    V3_G.validate_vnext_t2_concrete_source_witness_v3(witness,
        chain.transport, chain.recheck, chain.parent, chain.expected,
        chain.bridge, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key)
end

function v3_v2_present_source_precursor(chain)
    candidate = chain.transport.candidate_ref
    children = Tuple(Main._t0l_child_present(kind; candidate=candidate)
        for kind in (:realization, :control, :binding))
    admission = V3_G.vnext_declaration_transport_local_v1(candidate,
        chain.declarations, children, chain.feedback;
        frozen_contexts=Main._T0L_CONTEXTS)
    admission.status === :valid || error((:v2_present_fixture_transport_invalid,
        admission.status, admission.errors))
    transport = admission.transport
    recheck = V3_G.vnext_declaration_authority_recheck_local_v2(
        V3_G.VNextAuthorityRecheckLocalV2Input(candidate, transport))
    g3 = chain.recheck.output.g3
    expected = V3_G.vnext_g3_binding_expected_commitment_v1(candidate,
        transport.bundle_hash, g3.declaration_ref,
        g3.declaration_identity_hash, chain.projection.realization,
        chain.projection.control)
    links = V3_G._vnext_t2_v3_binding_links(chain.g3_declaration)
    bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(recheck, expected,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=links)
    (transport=transport, recheck=recheck, expected=expected, bridge=bridge)
end
