# Candidate-owned G3 design input for local source admission only.
# All values below are authored assumptions. They are not measurements,
# material certifications, controller records, or physical/engineering results.
# Dimensions and limits below are locally selected design coordinates/assumptions.
# Coincidence with another candidate chart does not establish a physical mapping.
function up4_r2_g3_child_design_source_v1()
    owner = "local-authored-up4-r2-g3-design-only"
    candidate_id = "native-g1g2-diffusion-mms-current-source-v1"
    scenario_id = "scenario-native-g1g2-diffusion-mms-current-source-v1"
    # This newly authored source declares axes explicitly in kg,m,s,A,K,mol,cd
    # order. Historical child bytes without this header retain their old
    # software-contract interpretation and are never silently reinterpreted.
    unit_basis = (:kg, :m, :s, :A, :K, :mol, :cd)
    power_unit = UnitSignature((1, 2, -3, 0, 0, 0, 0)) # kg*m^2/s^3 = W
    voltage_unit = UnitSignature((1, 2, -3, -1, 0, 0, 0)) # V
    current_unit = UnitSignature((0, 0, 0, 1, 0, 0, 0)) # A
    temperature_unit = UnitSignature((0, 0, 0, 0, 1, 0, 0)) # K
    length_unit = UnitSignature((0, 1, 0, 0, 0, 0, 0)) # m
    conductivity_unit = UnitSignature((1, 1, -3, 0, -1, 0, 0)) # W/(m*K)
    command_unit = UnitSignature((0, 0, 0, 0, 0, 0, 0)) # dimensionless fraction

    ports = (
        G3RealizationSourcePortV1("source_bus", :source, power_unit, :out, 1, owner),
        G3RealizationSourcePortV1("diffusion_load", :field, power_unit, :in, 1, owner),
        G3RealizationSourcePortV1("return_bus", :return, power_unit, :in, 1, owner),
        G3RealizationSourcePortV1("heat_rejection", :heat, power_unit, :in, 1, owner),
    )
    components = (
        G3RealizationComponentV1("source_module", :source_component, ("source_bus",),
            1200, power_unit, "concept_source_alloy", "concept_joined_module_thickness"),
        G3RealizationComponentV1("diffusion_core", :passive_component, ("diffusion_load",),
            1000, power_unit, "concept_core_composite", "concept_laminated_core_thickness"),
        G3RealizationComponentV1("return_manifold", :return_component, ("return_bus",),
            600, power_unit, "concept_return_alloy", "concept_joined_module_thickness"),
        G3RealizationComponentV1("heat_sink", :heat_component, ("heat_rejection",),
            600, power_unit, "concept_sink_composite", "concept_laminated_core_thickness"),
    )
    materials = (
        G3RealizationMaterialDomainV1("concept_source_alloy", :conductivity, 15, 20, conductivity_unit),
        G3RealizationMaterialDomainV1("concept_core_composite", :conductivity, 2, 4, conductivity_unit),
        G3RealizationMaterialDomainV1("concept_return_alloy", :conductivity, 15, 20, conductivity_unit),
        G3RealizationMaterialDomainV1("concept_sink_composite", :conductivity, 1, 2, conductivity_unit),
    )
    manufacturing = (
        G3RealizationManufacturingDomainV1("concept_joined_module_thickness", :thickness, 1//100, 1//20, length_unit),
        G3RealizationManufacturingDomainV1("concept_laminated_core_thickness", :thickness, 1//100, 1//20, length_unit),
        G3RealizationManufacturingDomainV1("concept_joined_module_tolerance", :tolerance, 1//1000, 1//500, length_unit),
        G3RealizationManufacturingDomainV1("concept_laminated_core_tolerance", :tolerance, 1//1000, 1//500, length_unit),
        G3RealizationManufacturingDomainV1("concept_laminated_core_temperature", :temperature, 293, 400, temperature_unit),
    )
    accounts = (G3RealizationLedgerAccountV1("design_energy", :energy, power_unit, owner),)
    # Account ownership is an explicit candidate-authored design field. Keep it
    # separate from the ledger account's owner_scope; consumers must not infer
    # G3LedgerAccountV2.owner by renaming or copying owner_scope.
    account_owners = ((account_id="design_energy",
        owner="local-authored-design-energy-account-owner"),)
    owner_scope_account_membership = ((owner_scope=owner,
        account_ids=("design_energy",)),)
    entries = (
        G3RealizationLedgerEntryV1("source_input", "design_energy", "source_bus", "source_module", 1000, power_unit, :source),
        G3RealizationLedgerEntryV1("field_allocation", "design_energy", "diffusion_load", "diffusion_core", -500, power_unit, :load),
        G3RealizationLedgerEntryV1("return_allocation", "design_energy", "return_bus", "return_manifold", -250, power_unit, :return),
        G3RealizationLedgerEntryV1("heat_allocation", "design_energy", "heat_rejection", "heat_sink", -250, power_unit, :heat_rejection),
    )
    # Candidate-authored scalar heat-lift contract, joined to the exact G3
    # field-allocation row above. The basis permutation maps source SI exponents
    # (kg,m,s,...) into the native G1/G2 length-first order (m,kg,s,...).
    heat_budget = only(entry for entry in entries if entry.entry_id == "field_allocation")
    authored_heat_lift = (schema="g3-authored-scalar-heat-lift-v1",
        version="v1", candidate_id=candidate_id, scenario_id=scenario_id,
        reference_temperature_k=293//1, temperature_scale_k=1//1,
        conductivity_scale_w_m_k=1//1,
        source_unit_basis=unit_basis,
        native_unit_basis=(:m, :kg, :s, :A, :K, :mol, :cd),
        native_basis_permutation=(2, 1, 3, 4, 5, 6, 7),
        source_operator=:minus_div_k_grad,
        budget_join=(entry_id=heat_budget.entry_id,
            account_id=heat_budget.account_id, port_id=heat_budget.port_id,
            component_id=heat_budget.component_id,
            coefficient_w=heat_budget.coefficient,
            limit_w=abs(heat_budget.coefficient)))
    closures = (G3RealizationLedgerClosureV1("design_energy_balance", :energy,
        ("design_energy",), 0),)
    realization = G3RealizationSourceBodyV1("local-authored-realization-r3", owner,
        ports, 1000, 500, 250, 250, 1200, power_unit, 0,
        components, materials, manufacturing, accounts, entries, closures)

    # Candidate-design circuit model. The existing four W endpoints above
    # remain the power-allocation ledger view. This separate typed network
    # uses V/A resource ports and explicitly joins source_bus power to V*I.
    resource_network_accounts = (
        G3LedgerAccountV2("design_energy", :energy, power_unit,
            "local-authored-design-energy-account-owner"),
    )
    resource_network_ports = (
        G3ResourcePortV2("source_voltage", :effort, :out, voltage_unit, "design_energy"),
        G3ResourcePortV2("source_supply_current", :flow, :out, current_unit, "design_energy"),
        G3ResourcePortV2("diffusion_load", :load, :in, power_unit, "design_energy"),
        G3ResourcePortV2("return_current", :return, :in, current_unit, "design_energy"),
        G3ResourcePortV2("heat_rejection", :heat_sink, :in, power_unit, "design_energy"),
    )
    resource_network_components = (
        G3RealizationComponentV2("source_module", :source_component,
            ("source_voltage", "source_supply_current"), 1200, power_unit,
            "concept_source_alloy", "concept_joined_module_thickness", false),
        G3RealizationComponentV2("diffusion_core", :passive_component,
            ("diffusion_load",), 1000, power_unit,
            "concept_core_composite", "concept_laminated_core_thickness", true),
        G3RealizationComponentV2("return_manifold", :return_component,
            ("return_current",), 600, power_unit,
            "concept_return_alloy", "concept_joined_module_thickness", false),
        G3RealizationComponentV2("heat_sink", :heat_component,
            ("heat_rejection",), 600, power_unit,
            "concept_sink_composite", "concept_laminated_core_thickness", false),
    )
    resource_network_entries = (
        G3LedgerEntryV2("source_current_power", "design_energy", "source_supply_current",
            "source_module", 1000, power_unit, :source),
        G3LedgerEntryV2("field_power", "design_energy", "diffusion_load",
            "diffusion_core", -500, power_unit, :load),
        G3LedgerEntryV2("return_power", "design_energy", "return_current",
            "return_manifold", -250, power_unit, :return),
        G3LedgerEntryV2("heat_power", "design_energy", "heat_rejection",
            "heat_sink", -250, power_unit, :heat_rejection),
    )
    resource_network_closures = (
        G3LedgerClosureV2("design_energy_balance", :energy,
            ("design_energy",), 0),
    )
    resource_network = G3ResourceNetworkV2(resource_network_components,
        resource_network_ports, resource_network_accounts, resource_network_entries,
        resource_network_closures)
    authored_power_laws = (
        G3AuthoredPowerLawV1("source_bus_VI", "source_voltage",
            "source_supply_current", "source_bus", 500, 2, 1000,
            voltage_unit, current_unit, power_unit),
        G3AuthoredPowerLawV1("return_bus_VI", "source_voltage",
            "return_current", "return_bus", 500, 1//2, 250,
            voltage_unit, current_unit, power_unit),
    )

    control_signals = (
        G3ControlSignalV1("core_temperature", :sensor, :in, temperature_unit, "temperature_account"),
        G3ControlSignalV1("source_fraction_command", :command, :out, command_unit, "source_command_account"),
        G3ControlSignalV1("source_power_resource", :status, :out, power_unit, "design_energy"),
        # Candidate-design feedback endpoints preserve the two existing G3
        # declaration targets. They are typed signal references only: no
        # sampled residual value or upstream authority is supplied.
        G3ControlSignalV1("g1_residual_feedback", :sensor, :in,
            UnitSignature((0, -2, 0, 0, 0, 0, 0)), "candidate_feedback_g1"),
        G3ControlSignalV1("g2_residual_feedback", :sensor, :in,
            UnitSignature(), "candidate_feedback_g2"),
    )
    controller_id = "candidate_thermal_supervisor"
    fault_id = "core_overtemperature_trip"
    controller = G3ControlControllerV1(controller_id, ("core_temperature",),
        ("source_fraction_command",), ("source_power_resource",), (fault_id,),
        (G3ControlInitialStateV1("initial_core_temperature", temperature_unit, 293),),
        (G3ControlEventV1("initial_enable", :initial, 0, :enable),))
    fault = G3ControlFaultV1(fault_id, controller_id, :overtemperature, :trip,
        "core_temperature", 1//10)
    control = G3ControlSourceBodyV1("local-authored-control-r3", owner,
        control_signals, (controller,), (fault,),
        G3ControlPlanV1((controller_id,),
            ("core_temperature", "source_fraction_command", "source_power_resource",
             "g1_residual_feedback", "g2_residual_feedback"),
            (fault_id,)))
    feedback_source_maps = (
        (target_id="feedback_g1_r2", target_layer=:G1,
            target_path="design.residual", quantity=:residual,
            target_unit=UnitSignature((-2, 0, 0, 0, 0, 0, 0)),
            signal_unit=UnitSignature((0, -2, 0, 0, 0, 0, 0)),
            target_unit_basis=(:m, :kg, :s, :A, :K, :mol, :cd),
            signal_unit_basis=unit_basis,
            native_basis_permutation=(2, 1, 3, 4, 5, 6, 7),
            unit_scale=1//1,
            signal_port_id="g1_residual_feedback", channel=:residual,
            kind=:implementation_error, scope=:candidate_design_only,
            authority=:missing),
        (target_id="feedback_g2_r2", target_layer=:G2,
            target_path="design.boundary_residual", quantity=:residual,
            target_unit=UnitSignature(), signal_unit=UnitSignature(),
            target_unit_basis=(:m, :kg, :s, :A, :K, :mol, :cd),
            signal_unit_basis=unit_basis,
            native_basis_permutation=(2, 1, 3, 4, 5, 6, 7),
            unit_scale=1//1, signal_port_id="g2_residual_feedback",
            channel=:residual, kind=:implementation_error,
            scope=:candidate_design_only, authority=:missing),
    )
    control_resource_links = (G3ControlResourceLinkV2(
        "thermal_supervisor_source_supply_current", controller_id,
        "core_temperature", "source_fraction_command", "source_supply_current",
        fault_id),)

    provider_route_selection = (schema="g3-candidate-provider-selection-v1",
        version="v1", design_scope="candidate_design_only",
        candidate_id=candidate_id, scenario_id=scenario_id,
        source_path="test/fixtures/native_g1g2_mms_mesh_334_current_source_v1/g3_child_design_source.jl",
        selections=(
            (selection_id="N09-01", service=:native_g1g2_gridap_grad,
                provider_schema="native-g1g2-gridap-component-service-v1",
                provider_revision="v1", backend="Gridap-native-g1g2",
                backend_revision_source=:gridap_dependency_version,
                independence_group="gridap-native-g1g2-component-service-v1",
                provider_source_path="src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
                profile_id="native-g1g2-gridap-service-input-v1"),
            (selection_id="N09-02", service=:native_g1g2_gridap_chart_mesh,
                provider_schema="native-g1g2-gridap-component-service-v1",
                provider_revision="v1", backend="Gridap-native-g1g2",
                backend_revision_source=:gridap_dependency_version,
                independence_group="gridap-native-g1g2-component-service-v1",
                provider_source_path="src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
                profile_id="native-g1g2-gridap-service-input-v1"),
            (selection_id="N09-03", service=:native_g1g2_gridap_exterior_boundary,
                provider_schema="native-g1g2-gridap-component-service-v1",
                provider_revision="v1", backend="Gridap-native-g1g2",
                backend_revision_source=:gridap_dependency_version,
                independence_group="gridap-native-g1g2-component-service-v1",
                provider_source_path="src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
                profile_id="native-g1g2-gridap-service-input-v1"),
            (selection_id="N09-04", service=:native_g1g2_gridap_scalar_heat_lift,
                provider_schema="native-g1g2-gridap-scalar-heat-lift-v1",
                provider_revision="v1", backend="Gridap-native-g1g2",
                backend_revision_source=:fixed_scalar_heat_lift_v1,
                independence_group="gridap-native-g1g2-scalar-heat-lift-v1",
                provider_source_path="src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
                profile_id="native-g1g2-gridap-scalar-heat-lift-v1"),
            (selection_id="N09-05", service=:engineering_control_fault_operational_screen,
                provider_schema="fusionconceptai:runtime-v4-trusted-engineering-control-fault-provider",
                provider_revision="trusted-engineering-control-fault-provider-v2",
                backend="FusionConceptAI candidate G3 thermostat",
                backend_revision_source=:fixed_sampled_control_source,
                independence_group="candidate-source-control",
                provider_source_path="src/RuntimeV4/TrustedEngineeringControlFaultProviderV4.jl",
                profile_id="g3_candidate_sampled_thermostat")),
        ecf_compatibility=(schema="g3-candidate-ecf-compatibility-v1",
            version="v1", candidate_id=candidate_id, scenario_id=scenario_id,
            source_system="EngineeringControlFaultContractsV4",
            source_locator="EngineeringControlFaultDecisionV4.control_status",
            source_status=:unsupported,
            target_locator="candidate.UP1_04B.F4.provider_resolution",
            target_status=:deferred, target_code=:ecf_unsupported_provider_gap,
            reason="Required observation or actuation capability remains unsupported; preserve the ECF intermediate gap until an exact candidate-bound provider match exists.",
            scope=:candidate_design_only, mapping_version="unsupported-to-deferred-v1",
            claim_ceiling=:contract_only, emits_evidence=false,
            terminal_authority=false))

    return (schema="up4-r2-g3-child-design-source-v2",
        unit_basis=unit_basis,
        design_scope="candidate_design_only",
        candidate_id=candidate_id,
        scenario_id=scenario_id,
        source_path="test/fixtures/native_g1g2_mms_mesh_334_current_source_v1/g3_child_design_source.jl",
        applicability="unvalidated scalar-diffusion candidate design; no G1/G2 physical coupling or authority",
        source_origin="locally authored assumptions; no measurement, certified material data, or controller archive",
        material_status="conceptual property ranges only; no material is selected or certified",
        geometry=(coordinate_system="local G3 Cartesian design coordinates, metres",
            origin=(0//1, 0//1, 0//1), axes=("x", "y", "z"), orientation="right-handed",
            lower=(0//1, 0//1, 0//1), upper=(2//1, 3//1, 4//1),
            extent=(2//1, 3//1, 4//1), geometry_authority=:missing,
            cross_layer_mapping=:unsupported),
        control_design=(law="candidate thermostat with 10 K deadband",
            sample_period_seconds=1//20,
            # Candidate-owned assumption for initial_enable/:initial/0 only;
            # it supplies no measured controller-clock or event-timing authority.
            event_time_policy=(basis=:event, unit=:second,
                clock=:controller_elapsed, origin=:controller_initialization,
                initial_trigger=:initial, initial_time=0//1),
            setpoint_kelvin=330//1, full_source_at_or_below_kelvin=325//1,
            zero_source_at_or_above_kelvin=335//1, in_band_action=:hold_previous_fraction,
            command_fraction_bounds=(0//1, 1//1), overtemperature_trip_kelvin=350//1,
            trip_deadline_seconds=1//10,
            # Candidate-authored discrete test observations; no plant or clock claim.
            fault_event_basis=:sampled_observation,
            sampled_fault_trace_kelvin=(293//1, 325//1, 330//1, 335//1, 350//1),
            trip_command_fraction=0//1,
            command_to_power_map=(coefficient=1000//1,
                coefficient_unit=power_unit, command_unit=command_unit,
                output_unit=power_unit, offset=0//1),
            command_to_current_map=(target_resource_port_id="source_supply_current",
                law=:fraction_of_rated_current, rated_current=2//1,
                rated_current_unit=current_unit, command_unit=command_unit,
                output_unit=current_unit, offset=0//1),
            applicability="standalone candidate design only; no validated transfer function, plant model, or G1/G2 coupling"),
        realization=realization, control=control,
        resource_network=resource_network,
        effort_ports_without_ledger=("source_voltage",),
        authored_power_laws=authored_power_laws,
        feedback_source_maps=feedback_source_maps,
        authored_heat_lift=authored_heat_lift,
        control_resource_links=control_resource_links,
        provider_route_selection=provider_route_selection,
        account_owners=account_owners,
        owner_scope_account_membership=owner_scope_account_membership,
        physical_validation=false, engineering_validation=false,
        measurement_authority=false, upstream_G1_authority=:missing,
        upstream_G2_authority=:missing,
        claim_ceiling=:contract_only)
end
