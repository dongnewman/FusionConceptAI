# Consumer-only UP1 G3 receipt, bridge, and T1 helpers. Loaded from the frozen snapshot only.

function _up4_r2_read_pinned_json(path, expected_sha256, label)
    isempty(path) && throw(ArgumentError("$(label) path is required"))
    isfile(path) || throw(ArgumentError("$(label) file is missing"))
    raw = read(path)
    actual = bytes2hex(SHA.sha256(raw))
    lowercase(actual) == lowercase(String(expected_sha256)) ||
        throw(ArgumentError("$(label) SHA-256 mismatch"))
    JSON3.read(String(copy(raw))), actual
end

function _up4_r2_json_tamper(value, key, replacement)
    mutable_value = JSON3.read(JSON3.write(value), Dict{String,Any})
    mutable_value[String(key)] = replacement
    JSON3.read(JSON3.write(mutable_value))
end

_up4_r2_json_ref(value, label) = begin
    hasproperty(value, :id) && hasproperty(value, :version) ||
        throw(ArgumentError("$(label) ref is incomplete"))
    G.QualifiedRefV1(String(value.id), String(value.version))
end

function _up4_r2_expected_child(value, kind, candidate, g3_record)
    Symbol(String(value.child_kind)) === kind ||
        throw(ArgumentError("G3 expected child kind mismatch"))
    child_candidate = _up4_r2_json_ref(value.candidate_ref, "child candidate")
    child_candidate == candidate || throw(ArgumentError("G3 expected child candidate mismatch"))
    parent_ref = _up4_r2_json_ref(value.parent_g3_declaration_ref, "child parent")
    parent_ref == g3_record.declaration_ref ||
        throw(ArgumentError("G3 expected child parent declaration mismatch"))
    parent_hash = G.Digest256(String(value.parent_g3_declaration_hash))
    parent_hash == g3_record.declaration_identity_hash ||
        throw(ArgumentError("G3 expected child parent identity mismatch"))
    contract_data = value.contract_ref
    contract = G.GenomeContractRef(String(contract_data.uri),
        String(contract_data.version), G.Digest256(String(contract_data.schema_hash)),
        G.Digest256(String(contract_data.canonicalization_hash)),
        String(contract_data.compatibility_profile))
    source_ref = _up4_r2_json_ref(value.source_record_ref, "child source record")
    G.VNextG3BindingChildExpectedCommitmentV1(kind, child_candidate,
        parent_ref, parent_hash,
        _up4_r2_json_ref(value.child_ref, "child"), contract, source_ref,
        G.Digest256(String(value.source_record_hash)),
        G.Digest256(String(value.source_content_hash)),
        G.Digest256(String(value.child_identity_hash)),
        G.Digest256(String(value.state_hash)))
end

function _up4_r2_local_layer_binding(binding, layer, candidate, design,
        builder_entry, expression_entry)
    declaration = design.declaration
    source_ref = layer === :G1 ? declaration.source_ref : declaration.source.source_ref
    payload_hash = layer === :G1 ? declaration.source_hash : declaration.source.source_hash
    declaration_raw = Vector{UInt8}(codeunits(G.canonical_json(declaration)))
    declaration_sha = bytes2hex(SHA.sha256(declaration_raw))
    declaration_ref = "local://up4-r2/" * String(layer) * "/declaration/" * declaration_sha
    builder_path = String(builder_entry.logical_path)
    expression_path = String(expression_entry.logical_path)
    builder_sha = String(builder_entry.sha256)
    expression_sha = String(expression_entry.sha256)
    identity = G.canonical_hash((candidate_ref=candidate, layer=layer,
        source_path=builder_path, source_sha256=G.Digest256(builder_sha),
        expression_path=expression_path,
        expression_sha256=G.Digest256(expression_sha),
        declaration_ref=declaration_ref,
        declaration_bytes_sha256=G.Digest256(declaration_sha),
        declaration_hash=declaration.declaration_hash,
        source_ref=source_ref, payload_source_hash=payload_hash))
    String(binding.source_binding) == "local_source_and_declaration_bound" &&
        _up4_r2_json_ref(binding.candidate_ref, "G1/G2 local source candidate") == candidate &&
        String(binding.scenario_id) == String(design.scenario_id) &&
        String(binding.builder_source_path) == builder_path &&
        Int(binding.builder_source_bytes) == length(builder_entry.bytes) &&
        String(binding.builder_source_sha256) == builder_sha &&
        String(binding.expression_source_path) == expression_path &&
        Int(binding.expression_source_bytes) == length(expression_entry.bytes) &&
        String(binding.expression_source_sha256) == expression_sha &&
        _up4_r2_json_ref(binding.source_ref, "G1/G2 payload source") == source_ref &&
        _up4_r2_json_ref(binding.declaration_ref, "G1/G2 local declaration") ==
            G.QualifiedRefV1(declaration_ref, "v1") &&
        String(binding.declaration_bytes_sha256) == declaration_sha &&
        String(binding.payload_source_hash) == payload_hash.value &&
        String(binding.declaration_hash) == declaration.declaration_hash.value &&
        String(binding.local_binding_identity_hash) == identity.value &&
        String(binding.admission_status) == String(design.admission.status) &&
        String(binding.admission_reason) == String(design.admission.error_code) &&
        String(binding.physical_authority) == "missing" ||
        throw(ArgumentError("G1/G2 local source binding differs from frozen consumer declaration"))
    nothing
end

function _up4_r2_expected_commitment(value, t0_receipt, context, candidate,
        admission, g3_record, frozen_receipt_sha256, source_entries)
    String(value.schema) == "up1-up4-r2-g3-expected-commitment-v1" ||
        throw(ArgumentError("G3 expected commitment schema mismatch"))
    String(value.t0_receipt_sha256) == frozen_receipt_sha256 ||
        throw(ArgumentError("G3 expected commitment is not bound to the pinned T0 receipt"))
    String(value.snapshot_id) == context.snapshot_id ||
        throw(ArgumentError("G3 expected commitment snapshot mismatch"))
    String(value.manifest_sha256) == context.manifest_sha256 ||
        throw(ArgumentError("G3 expected commitment manifest mismatch"))
    String(t0_receipt.snapshot_id) == context.snapshot_id ||
        throw(ArgumentError("pinned T0 receipt snapshot mismatch"))
    String(t0_receipt.manifest_sha256) == context.manifest_sha256 ||
        throw(ArgumentError("pinned T0 receipt manifest mismatch"))
    String(t0_receipt.schema) == "up1-up4-r2-t0-recheck-receipt-v1" &&
        String(t0_receipt.status) == "valid" &&
        String(t0_receipt.resolution) == "local_contract_ready" ||
        throw(ArgumentError("pinned T0 receipt is not a valid local contract admission"))
    receipt_candidate = _up4_r2_json_ref(t0_receipt.candidate_ref, "T0 candidate")
    receipt_candidate == candidate || throw(ArgumentError("pinned T0 receipt candidate mismatch"))
    _up4_r2_json_ref(value.candidate_ref, "expected candidate") == candidate ||
        throw(ArgumentError("G3 expected commitment candidate mismatch"))
    String(t0_receipt.bundle_hash) == admission.transport.bundle_hash.value ==
        String(value.bundle_hash) || throw(ArgumentError("G3 expected commitment bundle mismatch"))
    String(t0_receipt.g3_declaration_ref.id) == g3_record.declaration_ref.id ||
        throw(ArgumentError("T0 receipt G3 declaration ref mismatch"))
    String(t0_receipt.g3_declaration_ref.version) == g3_record.declaration_ref.version ||
        throw(ArgumentError("T0 receipt G3 declaration version mismatch"))
    String(t0_receipt.g3_declaration_identity_hash) == g3_record.declaration_identity_hash.value ||
        throw(ArgumentError("T0 receipt G3 identity mismatch"))
    _up4_r2_json_ref(value.g3_declaration_ref, "expected G3 declaration") ==
        g3_record.declaration_ref || throw(ArgumentError("G3 expected declaration ref mismatch"))
    String(value.g3_declaration_identity_hash) == g3_record.declaration_identity_hash.value ||
        throw(ArgumentError("G3 expected declaration identity mismatch"))
    value.scope.design_scope == "candidate_design_only" &&
        value.scope.physical_validation == false &&
        value.scope.engineering_validation == false &&
        value.scope.measurement_authority == false &&
        value.scope.upstream_G1_authority == "local_source_bound" &&
        value.scope.upstream_G2_authority == "local_source_bound" &&
        value.scope.upstream_G1_physical_authority == "missing" &&
        value.scope.upstream_G2_physical_authority == "missing" ||
        throw(ArgumentError("G3 expected commitment scope overclaims authority"))
    pins = value.source_pins
    String(pins.freeze_receipt_sha256) == lowercase(ENV["UP1_FROZEN_RECEIPT_SHA256"]) ||
        throw(ArgumentError("G3 expected freeze receipt pin mismatch"))
    String(pins.g3_child_design_source_path) == source_entries.child.logical_path &&
        String(pins.g3_child_design_source_sha256) == source_entries.child.sha256 ||
        throw(ArgumentError("G3 child source pin mismatch"))
    String(pins.g3_builder_source_path) == source_entries.builder.logical_path &&
        String(pins.g3_builder_source_sha256) == source_entries.builder.sha256 ||
        throw(ArgumentError("G3 builder source pin mismatch"))
    String(pins.realization_schema_source_path) == source_entries.realization.logical_path &&
        String(pins.realization_schema_source_sha256) == source_entries.realization.sha256 &&
        String(pins.control_schema_source_path) == source_entries.control.logical_path &&
        String(pins.control_schema_source_sha256) == source_entries.control.sha256 ||
        throw(ArgumentError("G3 schema source pin mismatch"))
    String(pins.producer_source_path) == source_entries.producer.logical_path &&
        String(pins.producer_source_sha256) == source_entries.producer.sha256 ||
        throw(ArgumentError("G3 producer source pin mismatch"))
    binding = value.scope.upstream_G1_G2_local_binding
    binding.physical_validation == false && binding.measurement_authority == false &&
        binding.engineering_validation == false ||
        throw(ArgumentError("G1/G2 local binding overclaims validation"))
    for (layer, builder, design) in ((:G1, source_entries.g1_builder, source_entries.g1),
            (:G2, source_entries.g2_builder, source_entries.g2))
        layer_binding = getproperty(binding, layer)
        _up4_r2_local_layer_binding(layer_binding, layer, candidate, design,
            builder, source_entries.expression)
        String(getproperty(pins, Symbol(lowercase(String(layer)) * "_builder_source_path"))) ==
            builder.logical_path &&
            String(getproperty(pins, Symbol(lowercase(String(layer)) * "_builder_source_sha256"))) ==
                builder.sha256 ||
            throw(ArgumentError("G1/G2 builder source pin mismatch"))
    end
    String(pins.g1g2_expression_source_path) == source_entries.expression.logical_path &&
        String(pins.g1g2_expression_source_sha256) == source_entries.expression.sha256 &&
        String(pins.g1_schema_source_path) == source_entries.g1_schema.logical_path &&
        String(pins.g1_schema_source_sha256) == source_entries.g1_schema.sha256 &&
        String(pins.g2_schema_source_path) == source_entries.g2_schema.logical_path &&
        String(pins.g2_schema_source_sha256) == source_entries.g2_schema.sha256 &&
        String(binding.schema_source_pins.G1.path) == source_entries.g1_schema.logical_path &&
        String(binding.schema_source_pins.G1.sha256) == source_entries.g1_schema.sha256 &&
        String(binding.schema_source_pins.G2.path) == source_entries.g2_schema.logical_path &&
        String(binding.schema_source_pins.G2.sha256) == source_entries.g2_schema.sha256 ||
        throw(ArgumentError("G1/G2 expression or declaration schema source pin mismatch"))
    realization = _up4_r2_expected_child(value.realization, :realization,
        candidate, g3_record)
    control = _up4_r2_expected_child(value.control, :control, candidate, g3_record)
    expected = G.vnext_g3_binding_expected_commitment_v1(candidate,
        admission.transport.bundle_hash, g3_record.declaration_ref,
        g3_record.declaration_identity_hash, realization, control)
    expected.commitment_hash.value == String(value.commitment_hash) ||
        throw(ArgumentError("G3 expected commitment hash mismatch"))
    expected
end

function _up4_r2_independent_g3_consumer(context, candidate, admission,
        g3_record, t0_receipt, t0_receipt_sha256, g3_child_entry,
        g3_builder_entry, g1, g2, v2_recheck, g3_design, g3_child_sha,
        parent_commitments)
    expected_record, expected_receipt_sha256 = _up4_r2_read_pinned_json(
        get(ENV, "UP1_G3_EXPECTED_RECEIPT_PATH", ""),
        get(ENV, "UP1_G3_EXPECTED_RECEIPT_SHA256", ""),
        "UP1 G3 expected commitment receipt")
    source_entries = (
        child=g3_child_entry,
        builder=g3_builder_entry,
        realization=N.frozen_source(context,
            "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl"),
        control=N.frozen_source(context,
            "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl"),
        g1_builder=N.frozen_source(context, _UP4_R2_DIR * "/g1_source.jl"),
        g2_builder=N.frozen_source(context, _UP4_R2_DIR * "/g2_source.jl"),
        expression=N.frozen_source(context,
            _UP4_R2_DIR * "/native_mms_source_expressions.json"),
        g1_schema=N.frozen_source(context,
            "src/GenomeV5/G1/DiffusionDeclarationV1.jl"),
        g2_schema=N.frozen_source(context,
            "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        g1=g1, g2=g2,
        producer=N.frozen_source(context,
            "scripts/up1_g3_expected_commitment_producer_v1.jl"))
    expected_commitment = _up4_r2_expected_commitment(expected_record,
        t0_receipt, context, candidate, admission, g3_record,
        t0_receipt_sha256, source_entries)
    expected_commitment.commitment_hash.value == String(expected_record.commitment_hash) ||
        error("independent G3 expected commitment reconstruction mismatch")

    stale_expected = _up4_r2_json_tamper(expected_record,
        "snapshot_id", "stale-snapshot")
    @test_throws ArgumentError _up4_r2_expected_commitment(stale_expected,
        t0_receipt, context, candidate, admission, g3_record,
        t0_receipt_sha256, source_entries)
    stale_t0_receipt = _up4_r2_json_tamper(t0_receipt,
        "snapshot_id", "stale-snapshot")
    @test_throws ArgumentError _up4_r2_expected_commitment(expected_record,
        stale_t0_receipt, context, candidate, admission, g3_record,
        t0_receipt_sha256, source_entries)
    tampered_expected = _up4_r2_json_tamper(expected_record,
        "commitment_hash", repeat("0", 64))
    @test_throws ArgumentError _up4_r2_expected_commitment(tampered_expected,
        t0_receipt, context, candidate, admission, g3_record,
        t0_receipt_sha256, source_entries)
    @test_throws ArgumentError _up4_r2_read_pinned_json(
        ENV["UP1_G3_EXPECTED_RECEIPT_PATH"], repeat("0", 64),
        "tampered G3 expected receipt")

    tampered_local = JSON3.read(JSON3.write(expected_record), Dict{String,Any})
    tampered_local["scope"]["upstream_G1_G2_local_binding"]["G1"]["declaration_hash"] =
        repeat("0", 64)
    @test_throws ArgumentError _up4_r2_expected_commitment(
        JSON3.read(JSON3.write(tampered_local)), t0_receipt, context,
        candidate, admission, g3_record, t0_receipt_sha256, source_entries)

    g3_bridge = G.vnext_g3_binding_authority_bridge_local_v1(v2_recheck,
        expected_commitment, g3_design.realization_state,
        g3_design.control_state, g3_design.binding_key;
        initial_links=g3_design.initial_links)
    println("UP1_G3_BRIDGE_OBSERVED\t", g3_bridge.status, "\t",
        g3_bridge.resolution, "\tself_consistency=", g3_bridge.self_consistency,
        "\tauthority_verified=", g3_bridge.authority_verified,
        "\terrors=", repr(g3_bridge.errors),
        "\thas_binding_state=", g3_bridge.binding_state !== nothing)
    flush(stdout)
    g3_bridge.status === :local_checked_present && g3_bridge.authority_verified &&
        g3_bridge.binding_state !== nothing ||
        error("G3 authority bridge did not verify independent commitment: " *
            "status=$(g3_bridge.status), errors=$(repr(g3_bridge.errors))")
    control_ref = g3_design.control_state.source_payload_ref
    control_record = g3_design.control_source_record
    control_payload = G.G3ControlSourcePayloadV1(
        g3_design.control_state.key, control_ref.parent_g3_declaration_ref,
        control_ref.parent_g3_declaration_hash, control_ref.child_contract_ref,
        control_ref.child_contract_identity_hash, control_record.record_uri,
        control_record.record_version, g3_design.control_state.editable_body,
        control_record, control_ref.source_content_hash)
    @test G.canonical_hash(G.g3_control_source_payload_ref_v1(control_payload)) ==
        G.canonical_hash(control_ref)
    parent = G.bind_local_parent_baseline_from_t0_v1(
        G.T0LocalParentBaselineInputV1(candidate,
            (admission.transport.declarations[1],
             admission.transport.declarations[2])); frozen_context=context)
    @test parent.status === :present
    source_bridge = G.vnext_concrete_source_witness_g3_bridge_v1(
        v2_recheck, expected_commitment, g3_bridge,
        g3_design.realization_state, control_payload, g3_design.control_state,
        g3_design.binding_key; initial_links=g3_design.initial_links)
    @test source_bridge.status === :local_checked_present
    source_witness = G.prepare_vnext_t2_concrete_source_witness_v3(
        admission.transport, v2_recheck, parent, expected_commitment,
        source_bridge, g3_design.realization_state, control_payload,
        g3_design.control_state, g3_design.binding_key;
        frozen_context=context)
    source_validation = source_witness.source_ready ?
        G.validate_vnext_t2_concrete_source_witness_v3(source_witness.witness,
            admission.transport, v2_recheck, parent, expected_commitment,
            source_bridge, g3_design.realization_state, control_payload,
            g3_design.control_state, g3_design.binding_key;
            frozen_context=context) : source_witness
    println("UP1_SOURCE_WITNESS_OBSERVED\t", source_validation.status,
        "\tresolution=", source_validation.resolution,
        "\terrors=", repr(source_validation.errors),
        "\tgaps=", repr(source_validation.gaps),
        "\thash=", source_validation.witness === nothing ? "absent" :
            source_validation.witness.witness_hash.value)
    flush(stdout)
    @test source_validation.source_ready
    @test source_validation.witness.candidate_ref == candidate
    @test source_validation.witness.formal_t1.formal_t1_accepted == false
    @test source_validation.witness.formal_node_accepted == false
    # A self-consistent ledger hash must not replace derivation from frozen source.
    if hasproperty(g3_record.semantic_body.body, :authored_typed_ledger_source)
        ledger = g3_record.semantic_body.body.authored_typed_ledger_source
        account = first(ledger.accounts)
        forged_owner = "__forged_frozen_source_owner__"
        forged_account = G.G3LedgerAccountV2(account.account_id, account.domain,
            account.unit, forged_owner)
        forged_payload = merge(Base.structdiff(ledger, (identity_hash=ledger.identity_hash,)),
            (account_owners=(merge(first(ledger.account_owners),
                (owner=forged_owner,)), Base.tail(ledger.account_owners)...),
             accounts=(forged_account, Base.tail(ledger.accounts)...)))
        forged_ledger = merge(forged_payload,
            (identity_hash=G.canonical_hash(forged_payload),))
        @test forged_ledger.accounts[1].owner == forged_ledger.account_owners[1].owner
        @test forged_ledger.identity_hash == G.canonical_hash(forged_payload)
        forged_body = merge(g3_record.semantic_body.body,
            (authored_typed_ledger_source=forged_ledger,))
        forged_raw = Vector{UInt8}(codeunits(G.canonical_json(forged_body)))
        forged_carrier = G.VNextT0LocalBytesV1(forged_raw,
            G.Digest256(bytes2hex(SHA.sha256(forged_raw))))
        record_fields = fieldnames(typeof(g3_record))
        forged_record = merge(NamedTuple{record_fields}(Tuple(
            getfield(g3_record, field) for field in record_fields)),
            (semantic_body=G.VNextT0LocalSemanticBodyV1(forged_body, forged_carrier,
                g3_record.semantic_body.labels),))
        forged_errors = Symbol[]
        G._vnext_t2_v3_materialize_g3(forged_record, forged_errors;
            frozen_context=context, children=admission.transport.children)
        @test :g3_authored_typed_ledger_reconstruction_failed in forged_errors
        @test :g3_semantic_bytes_mismatch ∉ forged_errors
        println("UP1_TYPED_LEDGER_FORGED_OWNER_OBSERVED\tfail_closed\t",
            repr(Tuple(forged_errors)), "\tcarrier_bytes_recomputed=true")
        flush(stdout)
    end
    g3_authority = (status=g3_bridge.status,
        resolution=g3_bridge.resolution,
        authority_verified=g3_bridge.authority_verified,
        commitment_hash=expected_commitment.commitment_hash,
        expected_commitment=expected_commitment,
        binding_state=g3_bridge.binding_state)
    expected_digest = expected_commitment.commitment_hash
    _up1_stage("r2_t1_v2_begin")
    t1_v2 = G.vnext_t1_admit_v2(G.VNextT1AdmissionInputV2(candidate,
        admission.transport, v2_recheck, parent_commitments,
        expected_digest, g3_authority))
    println("UP1_T1_V2_OBSERVED\t", t1_v2.status, "\t", t1_v2.resolution,
        "\terrors=", repr(t1_v2.errors), "\treasons=n/a",
        "\tgaps=", repr(t1_v2.gaps), "\thas_output=", t1_v2.package !== nothing)
    flush(stdout)
    t1_v2.status === :prepared_not_executed || error(
        "UP1 T1 V2 did not prepare the independently bound package: " *
        "status=$(t1_v2.status), resolution=$(t1_v2.resolution), " *
        "errors=$(repr(t1_v2.errors)), gaps=$(repr(t1_v2.gaps)), " *
        "has_package=$(t1_v2.package !== nothing)")
    _up1_stage("r2_t1_v2_complete")
    @test t1_v2.resolution === :terminal_deferred
    @test !t1_v2.accepted && t1_v2.claim_ceiling === :contract_only
    @test t1_v2.package isa G.CandidateStatePackageV5NextV2
    @test isempty(t1_v2.errors) && t1_v2.gaps == (:t1_runtime_unresolved,)
    @test G.vnext_t1_package_v2_validate(t1_v2.package) === nothing
    @test t1_v2.package.status === :prepared_not_executed
    @test t1_v2.package.resolution === :terminal_deferred
    @test t1_v2.package.g3_authority.binding_state_hash ==
        g3_bridge.binding_state.state_hash
    (expected_commitment=expected_commitment,
     expected_receipt_sha256=expected_receipt_sha256,
     g3_bridge=g3_bridge,g3_authority=g3_authority,t1_v2=t1_v2)
end
