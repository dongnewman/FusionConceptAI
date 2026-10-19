# Target: G3SourceAuthorityFactoryV1 -> T0 -> V1/V2 -> T1 V2 -> V3.
# Next gate: 240s / 2 GiB local software source admission only; candidate-owned
# realization/control design inputs remain non-physical and non-authoritative.
# The exact ledger split is a symbolic contract authored for software wiring. G1/G2 authority
# statuses remain :missing (no trusted receipt is fabricated); this carries no physical closure credit.
function up4_r2_build_g3_design(child_design_source=nothing; source_file_sha256=nothing)
    identity = UP4_R2_IDENTITY
    candidate = identity.candidate_ref
    source_id = "local-authored-power-ledger-thermal-slab"
    owner = "local-authored-up4-thermal-slab"
    source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/thermal-slab-up4-v5-20261003-wrong-f-expression", "v1")
    unit = UnitSignature()

    g1_authority = G3SFAuthorityV1(:G1, candidate, nothing, nothing, :missing)
    g2_authority = G3SFAuthorityV1(:G2, candidate, nothing, nothing, :missing)
    split = G3SFConservativeSplitV1(1//2, 1//4, 1//4)
    heat = G3SFHeatRelationV1(:source, :heat, 1//4)
    ledger_relation = G3SFLedgerRelationV1((:source,:field,:return,:heat), 0//1)
    law = G3SFLawV1("local-authored-split-thermal-slab", "src", "fld", "ret", "heat",
        1//2, 1//4, split, heat, ledger_relation, owner)
    endpoints = (
        G3SFEndpointV1("src", :source, unit, :out, 1, owner),
        G3SFEndpointV1("fld", :field, unit, :out, -1, owner),
        G3SFEndpointV1("ret", :return, unit, :out, -1, owner),
        G3SFEndpointV1("heat", :heat, unit, :out, -1, owner),
        G3SFEndpointV1("ledger", :ledger, unit, :out, 1, owner),
    )
    entries = (
        G3SFLedgerEntryV1("entry_source", "src", unit, :out, 1, :source, 1//1, owner),
        G3SFLedgerEntryV1("entry_field", "fld", unit, :out, -1, :field, -1//2, owner),
        G3SFLedgerEntryV1("entry_return", "ret", unit, :out, -1, :return, -1//4, owner),
        G3SFLedgerEntryV1("entry_heat", "heat", unit, :out, -1, :heat, -1//4, owner),
    )
    closure = G3SFLedgerClosureV1("local-ledger-closure-thermal-slab",
        ("entry_source","entry_field","entry_return","entry_heat"), 0//1, unit, owner)
    targets = (
        G3SFFeedbackTargetV1("feedback_g1_thermal-slab", :G1, "design.residual", :residual,
            UnitSignature((-2,0,0,0,0,0,0)), :in, 1, source_id, owner, g1_authority),
        G3SFFeedbackTargetV1("feedback_g2_thermal-slab", :G2, "design.boundary_residual", :residual,
            unit, :in, 1, source_id, owner, g2_authority),
    )
    declaration = g3_sf_declaration_v1(candidate, source_id, owner, endpoints, law,
        entries, closure, targets, (g1_authority,g2_authority))
    declaration_bytes = Vector{UInt8}(codeunits(canonical_json(declaration)))
    declaration_sha = Digest256(bytes2hex(SHA.sha256(declaration_bytes)))
    declaration_ref = QualifiedRefV1(
        "local://up4-thermal-slab/G3/declaration/" * declaration_sha.value, "v1")
    declaration_identity_hash = canonical_hash((kind=:declaration,
        ref=declaration_ref, bytes_sha256=declaration_sha))
    source_sha = nothing
    realization_payload = nothing
    control_source_record = nothing
    control_contract = nothing
    typed_ledger_source = nothing
    if child_design_source === nothing
        realization_key = G3RealizationChildKeyV1(candidate, declaration.declaration_hash,
            G3_REALIZATION_CHILD_EDIT_KIND_V1, "local-authored-realization-thermal-slab")
        realization_state = g3_realization_typed_absent_state_v1(realization_key,
            "No frozen G3 child design source was supplied";
            missing_slots=G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1)
        control_key = G3ControlChildKeyV1(candidate, declaration.declaration_hash,
            G3_CONTROL_CHILD_EDIT_KIND_V1, "local-authored-control-thermal-slab")
        control_state = g3_control_typed_absent_state_v1(control_key,
            "No frozen G3 child design source was supplied";
            missing_slots=G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1)
    else
        # The caller must obtain this digest from the exact UP1 frozen member
        # and verify SHA-256 over its raw bytes before calling this builder.
        child_design_source.schema in ("up4-r2-g3-child-design-source-v1",
            "up4-r2-g3-child-design-source-v2") &&
            (child_design_source.schema == "up4-r2-g3-child-design-source-v1" ||
                child_design_source.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd)) ||
            throw(ArgumentError("unexpected G3 child design source schema"))
        child_design_source.design_scope == "candidate_design_only" ||
            throw(ArgumentError("G3 child source is outside candidate design scope"))
        child_design_source.candidate_id == identity.candidate_id ||
            throw(ArgumentError("G3 child design candidate mismatch"))
        child_design_source.scenario_id == identity.scenario_id ||
            throw(ArgumentError("G3 child design scenario mismatch"))
        child_design_source.source_path ==
            "test/fixtures/thermal_slab/thermal-slab-up4-v5-20261003-wrong-f-expression/g3_child_design_source.jl" ||
            throw(ArgumentError("G3 child source path mismatch"))
        child_design_source.geometry.geometry_authority === :missing ||
            throw(ArgumentError("candidate G3 geometry cannot assert authority"))
        occursin("no validated transfer function, plant model, or G1/G2 coupling",
            child_design_source.control_design.applicability) ||
            throw(ArgumentError("candidate G3 control applicability exceeds declared scope"))
        child_design_source.physical_validation === false &&
            child_design_source.engineering_validation === false &&
            child_design_source.measurement_authority === false ||
            throw(ArgumentError("G3 candidate design source carries validation authority"))
        child_design_source.upstream_G1_authority === :missing &&
            child_design_source.upstream_G2_authority === :missing ||
            throw(ArgumentError("G3 candidate design source cannot promote upstream authority"))
        source_file_sha256 isa AbstractString &&
            occursin(r"^[0-9a-f]{64}$", String(source_file_sha256)) ||
            throw(ArgumentError("verified frozen G3 child source SHA-256 is required"))
        source_sha = Digest256(String(source_file_sha256))

        realization_body = child_design_source.realization
        realization_body isa G3RealizationSourceBodyV1 ||
            throw(ArgumentError("G3 realization source body has wrong type"))
        hasproperty(child_design_source, :account_owners) ||
            throw(ArgumentError("G3 child design source lacks explicit account owner records"))
        hasproperty(child_design_source, :owner_scope_account_membership) ||
            throw(ArgumentError("G3 child design source lacks explicit owner/account membership"))
        owner_records = Tuple(child_design_source.account_owners)
        all(record -> hasproperty(record, :account_id) && hasproperty(record, :owner),
            owner_records) ||
            throw(ArgumentError("G3 explicit account owner record shape is invalid"))
        account_ids = Tuple(account.account_id for account in realization_body.ledger_accounts)
        owner_record_ids = Tuple(String(record.account_id) for record in owner_records)
        isempty(account_ids) && throw(ArgumentError("G3 typed ledger source has no accounts"))
        length(unique(account_ids)) == length(account_ids) ||
            throw(ArgumentError("G3 typed ledger source has duplicate accounts"))
        length(owner_record_ids) == length(unique(owner_record_ids)) &&
            Set(owner_record_ids) == Set(account_ids) ||
            throw(ArgumentError("G3 explicit owner records must cover each typed account exactly once"))
        all(record -> hasproperty(record, :owner) &&
            record.owner isa AbstractString && !isempty(String(record.owner)), owner_records) ||
            throw(ArgumentError("G3 explicit account owner is missing"))
        memberships = Tuple(child_design_source.owner_scope_account_membership)
        length(memberships) == 1 ||
            throw(ArgumentError("G3 owner/account membership must be explicit and unambiguous"))
        membership = only(memberships)
        hasproperty(membership, :owner_scope) && hasproperty(membership, :account_ids) ||
            throw(ArgumentError("G3 owner/account membership record shape is invalid"))
        membership_ids = Tuple(String(x) for x in membership.account_ids)
        length(unique(membership_ids)) == length(membership_ids) &&
            all(id -> id in account_ids, membership_ids) ||
            throw(ArgumentError("G3 owner/account membership contains duplicate or unknown accounts"))
        membership.owner_scope == realization_body.owner_scope ||
            throw(ArgumentError("G3 owner/account membership scope differs from realization source"))
        expected_scope_accounts = Tuple(account.account_id
            for account in realization_body.ledger_accounts
            if account.owner_scope == membership.owner_scope)
        membership_ids == expected_scope_accounts ||
            throw(ArgumentError("G3 owner/account membership does not match typed account scopes"))
        entry_ids = Tuple(entry.entry_id for entry in realization_body.ledger_entries)
        length(unique(entry_ids)) == length(entry_ids) ||
            throw(ArgumentError("G3 typed ledger source has duplicate entries"))
        all(entry -> entry.account_id in account_ids, realization_body.ledger_entries) ||
            throw(ArgumentError("G3 typed ledger entry references an unknown account"))
        closure_ids = Tuple(closure.closure_id for closure in realization_body.ledger_closures)
        length(unique(closure_ids)) == length(closure_ids) ||
            throw(ArgumentError("G3 typed ledger source has duplicate closures"))
        closure_account_ids = Tuple(id for closure in realization_body.ledger_closures
            for id in closure.account_ids)
        all(id -> id in account_ids, closure_account_ids) ||
            throw(ArgumentError("G3 typed ledger closure references an unknown account"))
        ledger_balances = Tuple((closure_id=closure.closure_id,
            account_ids=closure.account_ids,
            actual_balance=sum(entry.coefficient for entry in realization_body.ledger_entries
                if entry.account_id in closure.account_ids),
            expected_balance=closure.expected_balance)
            for closure in realization_body.ledger_closures)
        all(balance.actual_balance == balance.expected_balance
            for balance in ledger_balances) ||
            throw(ArgumentError("G3 typed ledger source balance does not match its authored closure"))
        owner_by_id = Dict(String(record.account_id) => String(record.owner)
            for record in owner_records)
        g3_accounts = Tuple(G3LedgerAccountV2(account.account_id, account.domain,
            account.unit, owner_by_id[account.account_id])
            for account in realization_body.ledger_accounts)
        g3_entries = Tuple(G3LedgerEntryV2(entry.entry_id, entry.account_id,
            entry.port_id, entry.component_id, entry.coefficient, entry.unit,
            entry.effect) for entry in realization_body.ledger_entries)
        g3_closures = Tuple(G3LedgerClosureV2(closure.closure_id, closure.domain,
            closure.account_ids, closure.expected_balance)
            for closure in realization_body.ledger_closures)
        # This local, typed view is pinned by the exact candidate child-source
        # bytes. It records design values only and has no authority status.
        typed_ledger_body = (candidate_ref=candidate,
            candidate_id=identity.candidate_id, scenario_id=identity.scenario_id,
            source_path=String(child_design_source.source_path),
            design_scope=:candidate_design_only,
            source_sha256=Digest256(String(source_file_sha256)),
            source_accounts=realization_body.ledger_accounts,
            account_owners=owner_records,
            owner_scope_account_membership=memberships,
            accounts=g3_accounts, entries=g3_entries, closures=g3_closures,
            balances=ledger_balances,
            claim_ceiling=:contract_only, physical_validation=false,
            engineering_validation=false, measurement_authority=false,
            upstream_G1_authority=:missing, upstream_G2_authority=:missing)
        # New child sources declare their SI axis basis and typed circuit view.
        # The no-header branch preserves the historical software contract
        # byte-for-byte; old source unit exponents are never reinterpreted.
        if hasproperty(child_design_source, :unit_basis)
            child_design_source.schema == "up4-r2-g3-child-design-source-v2" ||
                throw(ArgumentError("G3 unit-basis branch requires child source schema v2"))
            child_design_source.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) ||
                throw(ArgumentError("G3 candidate source unit basis is not explicit SI kg,m,s,A,K,mol,cd"))
            correct_power = UnitSignature((1, 2, -3, 0, 0, 0, 0))
            correct_voltage = UnitSignature((1, 2, -3, -1, 0, 0, 0))
            correct_current = UnitSignature((0, 0, 0, 1, 0, 0, 0))
            realization_body.capacity_unit == correct_power &&
                all(port.unit == correct_power for port in realization_body.ports) ||
                throw(ArgumentError("G3 v2 power endpoints do not use W on the declared SI basis"))

            network = child_design_source.resource_network
            network isa G3ResourceNetworkV2 ||
                throw(ArgumentError("G3 v2 candidate source lacks typed G3ResourceNetworkV2"))
            effort_waivers = Tuple(child_design_source.effort_ports_without_ledger)
            effort_waivers == ("source_voltage",) ||
                throw(ArgumentError("G3 v2 candidate effort-ledger waiver is not the exact source_voltage input"))
            network_errors = g3_validate_resource_network(network;
                effort_ports_without_ledger=effort_waivers)
            isempty(network_errors) ||
                throw(ArgumentError("G3 v2 typed resource network fails closure: " * join(network_errors, ",")))
            effort = Tuple(port for port in network.resource_ports if port.kind === :effort)
            flow = Tuple(port for port in network.resource_ports if port.kind === :flow)
            length(effort) == 1 && only(effort).port_id == "source_voltage" &&
                only(effort).unit == correct_voltage ||
                throw(ArgumentError("G3 v2 candidate voltage effort source is absent or ambiguous"))
            length(flow) == 1 && only(flow).port_id == "source_supply_current" &&
                only(flow).unit == correct_current ||
                throw(ArgumentError("G3 v2 candidate source current flow is absent or ambiguous"))
            laws = Tuple(child_design_source.authored_power_laws)
            all(law -> law isa G3AuthoredPowerLawV1, laws) && length(laws) == 2 ||
                throw(ArgumentError("G3 v2 candidate source requires typed source and return V-I-P laws"))
            old_power_by_id = Dict(entry.port_id => entry for entry in realization_body.ledger_entries)
            network_entry_by_port = Dict(entry.port_id => entry for entry in network.entries)
            for law in laws
                haskey(old_power_by_id, law.power_endpoint_id) ||
                    throw(ArgumentError("G3 v2 power law does not join an existing authored power endpoint"))
                haskey(network_entry_by_port, law.current_port_id) ||
                    throw(ArgumentError("G3 v2 power law current port has no typed network ledger entry"))
                power_entry = old_power_by_id[law.power_endpoint_id]
                current_entry = network_entry_by_port[law.current_port_id]
                power_entry.unit == correct_power && abs(power_entry.coefficient) == law.power &&
                    power_entry.effect in (:source, :return) ||
                    throw(ArgumentError("G3 v2 V-I-P law does not exactly join authored power ledger"))
                current_entry.unit == correct_power && abs(current_entry.coefficient) == law.power &&
                    current_entry.account_id in Tuple(account.account_id for account in network.accounts) ||
                    throw(ArgumentError("G3 v2 V-I-P law does not exactly join its current-port accounting"))
                effort_port = only(Tuple(port for port in network.resource_ports
                    if port.port_id == law.effort_port_id))
                current_port = only(Tuple(port for port in network.resource_ports
                    if port.port_id == law.current_port_id))
                effort_port.kind === :effort && effort_port.unit == correct_voltage &&
                    current_port.kind in (:flow, :return) &&
                    current_port.unit == correct_current ||
                    throw(ArgumentError("G3 v2 V-I-P law resource kinds/units are inconsistent"))
            end
            source_law = only(Tuple(law for law in laws if law.law_id == "source_bus_VI"))
            source_law.effort_port_id == "source_voltage" &&
                source_law.current_port_id == "source_supply_current" &&
                source_law.power_endpoint_id == "source_bus" &&
                source_law.voltage == 500 && source_law.current == 2 &&
                source_law.power == realization_body.source_power ||
                throw(ArgumentError("G3 v2 source law does not join the authored 500V*2A=source_bus allocation"))
            links = Tuple(child_design_source.control_resource_links)
            all(link -> link isa G3ControlResourceLinkV2, links) && length(links) == 1 ||
                throw(ArgumentError("G3 v2 candidate control-resource link is absent or ambiguous"))
            link = only(links)
            control = child_design_source.control
            controller_ids = Tuple(item.controller_id for item in control.controllers)
            signal_ids = Tuple(item.port_id for item in control.signal_ports)
            fault_ids = Tuple(item.fault_id for item in control.faults)
            link.controller_id in controller_ids && link.sensor_port_id in signal_ids &&
                link.actuator_port_id in signal_ids && link.fault_id in fault_ids &&
                link.resource_port_id == "source_supply_current" &&
                link.resource_port_id in Tuple(port.port_id for port in flow) ||
                throw(ArgumentError("G3 v2 control link does not join the authored current-flow target"))
            linked_controller = only(Tuple(item for item in control.controllers
                if item.controller_id == link.controller_id))
            linked_fault = only(Tuple(item for item in control.faults
                if item.fault_id == link.fault_id))
            link.sensor_port_id in linked_controller.sensor_port_ids &&
                link.actuator_port_id in linked_controller.actuator_port_ids &&
                link.fault_id in linked_controller.fault_ids &&
                linked_fault.target_id == link.controller_id &&
                linked_fault.detection_signal_id == link.sensor_port_id ||
                throw(ArgumentError("G3 v2 control link controller/sensor/actuator/fault ownership differs"))
            sensor = only(Tuple(signal for signal in control.signal_ports
                if signal.port_id == link.sensor_port_id))
            actuator = only(Tuple(signal for signal in control.signal_ports
                if signal.port_id == link.actuator_port_id))
            status_signals = Tuple(signal for signal in control.signal_ports
                if signal.signal_kind === :status && signal.unit == correct_power)
            sensor.signal_kind === :sensor && sensor.direction === :in &&
                actuator.signal_kind === :command && actuator.direction === :out &&
                length(status_signals) == 1 &&
                only(status_signals).port_id == "source_power_resource" &&
                only(status_signals).port_id != link.resource_port_id ||
                throw(ArgumentError("G3 v2 control signal kinds/directions or distinct power status are invalid"))
            current_map = child_design_source.control_design.command_to_current_map
            current_map.target_resource_port_id == link.resource_port_id &&
                current_map.law === :fraction_of_rated_current &&
                current_map.rated_current == source_law.current &&
                current_map.rated_current_unit == correct_current &&
                current_map.output_unit == correct_current ||
                throw(ArgumentError("G3 v2 command/current map does not join the source current law"))
            power_map = child_design_source.control_design.command_to_power_map
            power_map.coefficient == source_law.power &&
                power_map.coefficient_unit == correct_power &&
                power_map.command_unit == actuator.unit &&
                power_map.output_unit == correct_power && power_map.offset == 0 ||
                throw(ArgumentError("G3 v2 command/power status map differs from the authored V-I-P law"))
            power_status = only(status_signals)
            power_status.account_id == "design_energy" &&
                power_status.port_id != link.resource_port_id ||
                throw(ArgumentError("G3 v2 power status signal/account aliases the current resource"))
            heat_lift = child_design_source.authored_heat_lift
            heat_lift.schema == "g3-authored-scalar-heat-lift-v1" &&
                heat_lift.version == "v1" &&
                heat_lift.candidate_id == identity.candidate_id &&
                heat_lift.scenario_id == identity.scenario_id &&
                heat_lift.reference_temperature_k == 293//1 &&
                heat_lift.temperature_scale_k == 1//1 &&
                heat_lift.conductivity_scale_w_m_k == 1//1 &&
                heat_lift.source_unit_basis == child_design_source.unit_basis &&
                heat_lift.native_unit_basis == (:m, :kg, :s, :A, :K, :mol, :cd) &&
                heat_lift.native_basis_permutation == (2, 1, 3, 4, 5, 6, 7) &&
                heat_lift.source_operator === :minus_div_k_grad ||
                throw(ArgumentError("G3 v2 authored heat-lift basis or candidate design is invalid"))
            heat_budget = only(Tuple(entry for entry in realization_body.ledger_entries
                if entry.entry_id == heat_lift.budget_join.entry_id))
            heat_lift.budget_join.entry_id == "field_allocation" &&
                heat_lift.budget_join.account_id == heat_budget.account_id == "design_energy" &&
                heat_lift.budget_join.port_id == heat_budget.port_id == "diffusion_load" &&
                heat_lift.budget_join.component_id == heat_budget.component_id == "diffusion_core" &&
                heat_budget.effect === :load && heat_budget.unit == correct_power &&
                heat_budget.coefficient == -500 &&
                heat_lift.budget_join.coefficient_w == heat_budget.coefficient &&
                heat_lift.budget_join.limit_w == abs(heat_budget.coefficient) == 500 ||
                throw(ArgumentError("G3 v2 authored heat-lift budget does not join the exact -500W field allocation"))
            typed_ledger_body = merge(typed_ledger_body,
                (unit_basis=child_design_source.unit_basis,
                 resource_network=network,
                 effort_ports_without_ledger=effort_waivers,
                 authored_power_laws=laws,
                 authored_heat_lift=heat_lift,
                 control_resource_links=links,
                 command_to_current_map=current_map,
                 command_to_power_map=power_map,
                 power_status_signal_id=power_status.port_id,
                 source_unit_contract=:declared_si_candidate_design_v2))
        end
        typed_ledger_source = merge(typed_ledger_body,
            (identity_hash=canonical_hash(typed_ledger_body),))
        realization_key = G3RealizationChildKeyV1(candidate, declaration_identity_hash,
            G3_REALIZATION_CHILD_EDIT_KIND_V1, realization_body.source_id)
        realization_record = g3_realization_source_record_v1(candidate;
            source_uri="fusionconceptai://GenomeV5/G3/local-authored-realization-source",
            source_version="candidate-design-v1",
            schema_ref=QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-schema", "v1"),
            schema_hash=g3_realization_child_edit_schema_hash_v1(),
            canonicalization_ref=QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-canonicalization", "v1"),
            canonicalization_hash=g3_realization_child_edit_canonicalization_hash_v1(),
            profile_ref=QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-profile", "v1"),
            profile_hash=g3_realization_child_edit_profile_hash_v1(),
            evidence_receipt_ref=QualifiedRefV1("fusionconceptai://candidate-design/thermal-slab-up4-v5-20261003-wrong-f-expression/g3-child-design-source", "v1"),
            evidence_receipt_hash=source_sha)
        realization_payload = g3_realization_source_payload_v1(realization_key,
            declaration_ref, realization_body, realization_record)
        realization_state = g3_realization_initial_state_v1(realization_key, realization_payload)

        control_body = child_design_source.control
        control_body isa G3ControlSourceBodyV1 ||
            throw(ArgumentError("G3 control source body has wrong type"))
        control_key = G3ControlChildKeyV1(candidate, declaration_identity_hash,
            G3_CONTROL_CHILD_EDIT_KIND_V1, control_body.source_id)
        control_contract = GenomeContractRef(G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,
            G3_CONTROL_CHILD_EDIT_VERSION_V1, g3_control_child_edit_schema_hash_v1(),
            g3_control_child_edit_canonicalization_hash_v1(), G3_CONTROL_CHILD_EDIT_PROFILE_V1)
        control_source_path = String(child_design_source.source_path)
        control_slot(kind, suffix, hash) = G3ControlProvenanceSlotV1(kind, :present,
            QualifiedRefV1("fusionconceptai://GenomeV5/G3/control-child/" * suffix, "v1"),
            control_source_path, hash, candidate, nothing, nothing)
        control_slots = (
            control_slot(:payload_schema_version, "schema", g3_control_child_edit_schema_hash_v1()),
            control_slot(:canonicalization_profile_version, "canonicalization", g3_control_child_edit_canonicalization_hash_v1()),
            control_slot(:applicability_profile_version, "profile", g3_control_child_edit_profile_hash_v1()),
            control_slot(:evidence_receipt_version, "candidate-source", source_sha),
        )
        control_record_body = (record_uri=G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,
            record_version=G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
            payload_schema_version=control_slots[1],
            canonicalization_profile_version=control_slots[2],
            applicability_profile_version=control_slots[3],
            evidence_receipt_version=control_slots[4])
        control_record = G3ControlSourceRecordV1(control_record_body.record_uri,
            control_record_body.record_version, control_slots[1], control_slots[2],
            control_slots[3], control_slots[4], canonical_hash(control_record_body))
        control_source_record = control_record
        control_state = g3_control_admit_source_v1(control_key, declaration_ref,
            control_body, control_contract, control_record)
    end
    binding_parent_ref = child_design_source === nothing ? source_ref : declaration_ref
    binding_parent_hash = child_design_source === nothing ?
        declaration.declaration_hash : declaration_identity_hash
    binding_key = G3BindingChildKeyV2(candidate, binding_parent_ref,
        binding_parent_hash, :binding, "local-authored-binding-thermal-slab")
    initial_links = Tuple(G3BindingLinkV1(target.target_id, target.target_layer,
        target.target_path, target.quantity, target.unit, target.direction,
        target.sign, target.source_id, target.owner_scope, target.authority)
        for target in declaration.feedback_targets)
    binding_absent = child_design_source === nothing ?
        (G3BindingChildAbsentV2(:realization, :missing_provenance),
         G3BindingChildAbsentV2(:control, :missing_provenance)) : nothing
    semantic_body = merge(_g3sf_body(declaration),
        (candidate_ref=candidate, source_ref=source_ref,
         authored_typed_ledger_source=typed_ledger_source))
    return (candidate_id=identity.candidate_id, scenario_id=identity.scenario_id,
        candidate_ref=candidate, source_ref=source_ref, source_id=source_id,
        declaration=declaration, validation=g3_sf_validate_v1(declaration),
        semantic_body=semantic_body, semantic_body_hash=canonical_hash(semantic_body),
        child_design_source=child_design_source, child_source_sha256=source_sha,
        realization_payload=realization_payload,
        control_source_record=control_source_record, control_contract_ref=control_contract,
        typed_ledger_source=typed_ledger_source,
        realization_state=realization_state, control_state=control_state,
        binding_key=binding_key, initial_links=initial_links,
        binding_absent=binding_absent,
        upstream_authority_status=(G1=:missing, G2=:missing), physical_resolution=:unknown)
end
