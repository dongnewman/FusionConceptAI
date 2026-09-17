using Test
using JSON3
using FusionConceptAI

const _G3_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3_ROOT, "RealizationGenomeV5.jl"))
Base.include(FusionConceptAI, joinpath(_G3_ROOT, "ControlGenomeV5.jl"))
Base.include(FusionConceptAI, joinpath(_G3_ROOT, "CoupledRealizationControlBindingV2.jl"))
Base.include(FusionConceptAI, joinpath(_G3_ROOT, "RealizationControlGenomeV5.jl"))

const G = FusionConceptAI
const _FIXTURE = JSON3.read(read(joinpath(@__DIR__, "fixtures.json"), String))
const _U = G.UnitSignature()
const _V = G.UnitSignature((1, 2, -3, -1, 0, 0, 0))
const _A = G.UnitSignature((0, 0, 0, 1, 0, 0, 0))
const _W = G.UnitSignature((1, 2, -3, 0, 0, 0, 0))
const _AMOUNT = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))
_fixture_negative(id::AbstractString) = any(String(x) == id for x in _FIXTURE.negative_cases)
_mutation(id::AbstractString) = first(x for x in _FIXTURE.negative_mutations if String(x.id) == id)

function _candidate_ref(layer)
    item = getproperty(_FIXTURE.candidate_refs, Symbol(layer))
    G.QualifiedRefV1(String(item.uri), String(item.version))
end

function _axis_ref(item)
    G.QualifiedRefV1(String(item.uri), String(item.version))
end

function _axes(tag)
    item = getproperty(_FIXTURE.version_axes, Symbol(tag))
    G.G3VersionAxesV2(_axis_ref(item.payload_schema),
        _axis_ref(item.canonicalization_profile), _axis_ref(item.applicability_profile),
        _axis_ref(item.evidence_receipt))
end

const _CANDIDATE = _candidate_ref("bundle")

function _target_ref(layer)
    item = first(x for x in _FIXTURE.construction.feedback if String(x.target_layer) == String(layer))
    target = item.target_contract
    zero = G.Digest256(repeat("0", 64))
    G.GenomeContractRef(String(target.uri), String(target.version), zero, zero,
        "pending-external-authority-" * lowercase(String(layer)))
end

_unit(v) = G.UnitSignature(Tuple(Int(x) for x in v))
function _rat(v)
    s = String(v); parts = split(s, "/")
    length(parts) == 1 ? parse(Int64, parts[1]) // 1 : parse(Int64, parts[1]) // parse(Int64, parts[2])
end
_ids(v) = Tuple(String(x) for x in v)
_state(x) = G.G3InitialStateV2(String(x.id), _unit(x.unit), _rat(x.value))
_event(x) = G.G3EventV2(String(x.id), Symbol(String(x.trigger)), _rat(x.time), Symbol(String(x.action)))

function _make_fixture(; provider_match=:no_match)
    realization_binding = G.G3ContractBindingV2(G.g3_contract_ref(:realization), _candidate_ref("realization"), _axes("realization"))
    control_binding = G.G3ContractBindingV2(G.g3_contract_ref(:control), _candidate_ref("control"), _axes("control"))
    binding_contract = G.G3ContractBindingV2(G.g3_contract_ref(:binding), _candidate_ref("binding"), _axes("binding"))
    bundle_binding = G.G3ContractBindingV2(G.g3_contract_ref(:bundle), _candidate_ref("bundle"), _axes("bundle"))

    c = _FIXTURE.construction
    resources = Tuple(G.G3ResourcePortV2(String(x.id), Symbol(String(x.kind)), Symbol(String(x.direction)),
        _unit(x.unit), String(x.account_id)) for x in c.resources)
    accounts = Tuple(G.G3LedgerAccountV2(String(x.id), Symbol(String(x.domain)), _unit(x.unit), String(x.owner)) for x in c.accounts)
    entries = Tuple(G.G3LedgerEntryV2(String(x.id), String(x.account_id), String(x.port_id), String(x.component_id),
        _rat(x.coefficient), _unit(x.unit), Symbol(String(x.effect))) for x in c.entries)
    closures = Tuple(G.G3LedgerClosureV2(String(x.id), Symbol(String(x.domain)), _ids(x.account_ids), _rat(x.expected_balance)) for x in c.closures)
    components = Tuple(G.G3RealizationComponentV2(String(x.id), Symbol(String(x.kind)), _ids(x.resource_port_ids),
        _rat(x.capacity), _unit(x.capacity_unit), String(x.material_id), String(x.manufacturing_process_id), Bool(x.passive),
        Tuple(_state(y) for y in x.initial_states), Tuple(_event(y) for y in x.events)) for x in c.components)
    network = G.G3ResourceNetworkV2(components, resources, accounts, entries, closures)
    materials = Tuple(G.G3MaterialDomainV2(String(x.id), Symbol(String(x.property)), _rat(x.lower), _rat(x.upper), _unit(x.unit)) for x in c.materials)
    manufacturing = Tuple(G.G3ManufacturingDomainV2(String(x.id), Symbol(String(x.parameter)), _rat(x.lower), _rat(x.upper), _unit(x.unit)) for x in c.manufacturing)
    realization = G.RealizationGenomeV5(realization_binding, network, materials, manufacturing;
        provider_match=provider_match)

    signals = Tuple(G.G3SignalPortV2(String(x.id), Symbol(String(x.kind)), Symbol(String(x.direction)), _unit(x.unit), String(x.account_id)) for x in c.signals)
    faults = Tuple(G.G3FaultPathV2(String(x.id), String(x.target_id), Symbol(String(x.mode)), Symbol(String(x.safe_action)), String(x.detection_signal_id), _rat(x.deadline)) for x in c.faults)
    controllers = Tuple(G.G3ControllerV2(String(x.id), _ids(x.sensor_port_ids), _ids(x.actuator_port_ids), _ids(x.actuator_resource_port_ids), _ids(x.fault_ids),
        Tuple(_state(y) for y in x.initial_states), Tuple(_event(y) for y in x.events)) for x in c.controllers)
    control_plan = G.G3ControlPlanV2(_ids(c.control_plan.controller_ids), _ids(c.control_plan.signal_port_ids), _ids(c.control_plan.fault_ids))
    control = G.ControlGenomeV5(control_binding, signals, controllers, faults, control_plan;
        provider_match=provider_match)

    links = Tuple(G.G3ControlResourceLinkV2(String(x.id), String(x.controller_id), String(x.sensor_port_id),
        String(x.actuator_port_id), String(x.resource_port_id), String(x.fault_id)) for x in c.links)
    feedback = Tuple(begin
        layer = Symbol(String(x.target_layer))
        G.G3FeedbackChannelV2(String(x.id), layer, _target_ref(String(x.target_layer)), Symbol(String(x.channel)),
            _unit(x.unit), Symbol(String(x.kind)), String(x.source_id))
    end for x in c.feedback)
    binding = G.CoupledRealizationControlBindingV2(binding_contract,
        realization_binding, control_binding, links, feedback)
    G.RealizationControlGenomeV5(bundle_binding, realization, control, binding)
end

function _rebuild(bundle, realization=bundle.realization, control=bundle.control; links=bundle.binding.links)
    binding = G.CoupledRealizationControlBindingV2(bundle.binding.contract_binding,
        realization.contract_binding, control.contract_binding, links, bundle.binding.feedback)
    G.RealizationControlGenomeV5(bundle.contract_binding, realization, control, binding)
end

@testset "UP1-03 G3 fixture and candidate-bound identity" begin
    @test _FIXTURE.fixture_id == "UP1-FX-G3-001"
    for layer in (:bundle, :realization, :control, :binding)
        @test _candidate_ref(String(layer)) == _CANDIDATE
        @test _candidate_ref(String(layer)).version == "v5"
        @test _axes(String(layer)) == G.g3_version_axes(layer)
        @test _axes(String(layer)).payload_schema_version == G.g3_version_axes(layer).payload_schema_version
        @test _axes(String(layer)).canonicalization_profile_version == G.g3_version_axes(layer).canonicalization_profile_version
        @test _axes(String(layer)).applicability_profile_version == G.g3_version_axes(layer).applicability_profile_version
        @test _axes(String(layer)).evidence_receipt_version == G.g3_version_axes(layer).evidence_receipt_version
    end
    @test Set(String.(_FIXTURE.resource_port_kinds)) == Set(("effort", "flow", "load", "return", "heat_sink", "material"))
    @test Set(String.(_FIXTURE.feedback_targets)) == Set(("G1", "G2"))
    c = _FIXTURE.construction
    @test !isempty(c.resources) && !isempty(c.accounts) && !isempty(c.entries) && !isempty(c.closures)
    @test !isempty(c.components) && !isempty(c.materials) && !isempty(c.manufacturing)
    @test !isempty(c.signals) && !isempty(c.faults) && !isempty(c.controllers) && !isempty(c.links) && !isempty(c.feedback)
    @test !isempty(c.control_plan.controller_ids) && !isempty(c.control_plan.signal_port_ids) && !isempty(c.control_plan.fault_ids)
    bundle = _make_fixture()
    admission = G.g3_admission(bundle)
    @test admission.structural_status == :valid
    @test admission.provider_match == :no_match
    @test admission.resolution == :terminal_deferred
    @test isempty(admission.errors)
    @test "feedback_authority_gap:g1-loss:G1" in admission.gaps
    @test "feedback_authority_gap:g2-thermal:G2" in admission.gaps
    @test all(c -> c.contract_binding.candidate_ref == _CANDIDATE,
        (bundle.realization, bundle.control))
    @test length(unique(canonical_hash.(
        (bundle.realization.contract_binding.contract_ref,
         bundle.control.contract_binding.contract_ref,
         bundle.binding.contract_binding.contract_ref)))) == 3
    @test bundle.realization.contract_binding.contract_ref.schema_hash != Digest256(repeat("0", 64))
    @test bundle.admission.candidate_hash == G.g3_candidate_hash(bundle)
    edited_component = G.g3_edit_component_capacity(bundle, "source", 9 // 1)
    @test G.g3_candidate_hash(edited_component) != G.g3_candidate_hash(bundle)
    @test edited_component.realization.plan_hash != bundle.realization.plan_hash
    edited_fault = G.g3_edit_fault(bundle, "open_fault", :sensor_dropout)
    @test G.g3_candidate_hash(edited_fault) != G.g3_candidate_hash(bundle)
    @test edited_fault.control.plan_hash != bundle.control.plan_hash
end

@testset "UP1-03 resource, ledger and fault fail-closed controls" begin
    bundle = _make_fixture()
    network = bundle.realization.network
    source_mutation = _mutation("missing_source_effort_or_flow")
    no_source = G.G3ResourceNetworkV2(network.components,
        Tuple(p for p in network.resource_ports if p.port_id != String(source_mutation.target)),
        network.accounts, network.entries, network.closures)
    no_source_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        no_source, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test G.g3_admission(no_source_bundle).structural_status == :fail_closed
    @test any(startswith(e, "missing_required_resource_port:flow") for e in G.g3_admission(no_source_bundle).errors)

    missing_account_mutation = _mutation("missing_account_entry")
    missing_account_entries = Tuple(e.entry_id == String(missing_account_mutation.entry_target) ?
        G.G3LedgerEntryV2(e.entry_id, String(missing_account_mutation.account_id), e.port_id,
            e.component_id, e.coefficient, e.unit, e.effect) : e for e in network.entries)
    missing_account_closures = Tuple(cl.closure_id == String(missing_account_mutation.closure_target) ?
        G.G3LedgerClosureV2(cl.closure_id, cl.domain,
            Tuple(id == String(missing_account_mutation.replace_account_id) ?
                String(missing_account_mutation.account_id) : id for id in cl.account_ids),
            cl.expected_balance) : cl for cl in network.closures)
    missing_account_network = G.G3ResourceNetworkV2(network.components, network.resource_ports,
        network.accounts, missing_account_entries, missing_account_closures)
    missing_account_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        missing_account_network, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    missing_account_admission = G.g3_admission(missing_account_bundle)
    @test missing_account_admission.structural_status == :fail_closed
    @test missing_account_admission.resolution == :fail_closed
    @test !isempty(missing_account_admission.gaps)
    @test "entry_account_missing:source-entry" in missing_account_admission.errors
    @test "closure_entry_account_missing:energy-balance" in missing_account_admission.errors

    @test _fixture_negative("missing_heat_sink")
    no_heat_mutation = _mutation("missing_heat_sink")
    no_heat = G.G3ResourceNetworkV2(network.components,
        Tuple(p for p in network.resource_ports if p.kind !== Symbol(String(no_heat_mutation.target))),
        network.accounts, network.entries, network.closures)
    no_heat_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        no_heat, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test G.g3_admission(no_heat_bundle).structural_status == :fail_closed
    @test G.g3_admission(no_heat_bundle).resolution == :fail_closed
    @test !isempty(G.g3_admission(no_heat_bundle).gaps)
    @test "missing_required_resource_port:heat_sink" in G.g3_admission(no_heat_bundle).errors

    no_return_resources = network.resource_ports
    no_return_mutation = _mutation("missing_return_path")
    no_return_entries = Tuple(e for e in network.entries if e.port_id != String(no_return_mutation.target))
    no_return_network = G.G3ResourceNetworkV2(network.components, no_return_resources,
        network.accounts, no_return_entries, network.closures)
    no_return_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        no_return_network, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test _fixture_negative("missing_return_path")
    @test G.g3_admission(no_return_bundle).structural_status == :fail_closed
    @test any(startswith(e, "missing_consumable_entry:return") for e in G.g3_admission(no_return_bundle).errors)

    over_capacity_mutation = _mutation("capacity_exceeded")
    over_capacity_entries = Tuple(e.entry_id == String(over_capacity_mutation.target) ?
        G.G3LedgerEntryV2(e.entry_id, e.account_id, e.port_id, e.component_id, _rat(over_capacity_mutation.value),
            e.unit, e.effect) : e for e in network.entries)
    over_capacity_network = G.G3ResourceNetworkV2(network.components, network.resource_ports,
        network.accounts, over_capacity_entries, network.closures)
    over_capacity_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        over_capacity_network, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test _fixture_negative("capacity_exceeded")
    @test G.g3_admission(over_capacity_bundle).structural_status == :fail_closed
    @test "component_capacity_exceeded:source-entry" in G.g3_admission(over_capacity_bundle).errors

    unit_mutation = _mutation("unit_mismatch")
    bad_units = Tuple(p.port_id == String(unit_mutation.target) ? G.G3ResourcePortV2(p.port_id, p.kind, p.direction, _unit(unit_mutation.unit), p.account_id) : p
        for p in network.resource_ports)
    bad_unit_network = G.G3ResourceNetworkV2(network.components, bad_units, network.accounts, network.entries, network.closures)
    bad_unit_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        bad_unit_network, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test _fixture_negative("unit_mismatch")
    @test G.g3_admission(bad_unit_bundle).structural_status == :fail_closed
    @test any(startswith(e, "resource_unit_mismatch:load") for e in G.g3_admission(bad_unit_bundle).errors)

    passive_mutation = _mutation("passive_component_source")
    passive_source = Tuple(c.component_id == String(passive_mutation.target) ? G.G3RealizationComponentV2(c.component_id, c.kind,
        c.resource_port_ids, c.capacity, c.capacity_unit, c.material_id, c.manufacturing_process_id, true,
        c.initial_states, c.events) : c for c in network.components)
    passive_network = G.G3ResourceNetworkV2(passive_source, network.resource_ports, network.accounts, network.entries, network.closures)
    passive_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        passive_network, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test _fixture_negative("passive_component_source")
    @test "passive_component_cannot_source:source-entry" in G.g3_admission(passive_bundle).errors

    duplicate_mutation = _mutation("duplicate_control_plan_ids")
    @test_throws ArgumentError G.G3ControlPlanV2(
        (String(duplicate_mutation.target), String(duplicate_mutation.target)),
        bundle.control.plan.signal_port_ids, bundle.control.plan.fault_ids)
    @test_throws ArgumentError G.G3ControlPlanV2(
        bundle.control.plan.controller_ids,
        (bundle.control.plan.signal_port_ids[1], bundle.control.plan.signal_port_ids[1]),
        bundle.control.plan.fault_ids)
    @test_throws ArgumentError G.G3ControlPlanV2(
        bundle.control.plan.controller_ids, bundle.control.plan.signal_port_ids,
        (bundle.control.plan.fault_ids[1], bundle.control.plan.fault_ids[1]))

    shared_owner_accounts = Tuple(a.account_id == "load_power" ? G.G3LedgerAccountV2(a.account_id, a.domain, a.unit, "source_owner") : a
        for a in network.accounts)
    shared_owner_network = G.G3ResourceNetworkV2(network.components, network.resource_ports,
        shared_owner_accounts, network.entries, network.closures)
    shared_owner_bundle = _rebuild(bundle, G.RealizationGenomeV5(bundle.realization.contract_binding,
        shared_owner_network, bundle.realization.material_domains, bundle.realization.manufacturing_domains))
    @test _fixture_negative("shared_owner_multiple_accounts_allowed")
    @test G.g3_admission(shared_owner_bundle).structural_status == :valid

    open_loop_mutation = _mutation("open_loop_control")
    open_loop_binding = G.CoupledRealizationControlBindingV2(bundle.binding.contract_binding,
        bundle.realization.contract_binding, bundle.control.contract_binding, (), bundle.binding.feedback)
    open_loop = G.RealizationControlGenomeV5(bundle.contract_binding, bundle.realization, bundle.control, open_loop_binding)
    @test _fixture_negative("open_loop_control")
    @test !isempty(open_loop_mutation.target) && "open_loop_control_binding" in G.g3_admission(open_loop).errors

    fault_mutation = _mutation("fault_target_or_detection_missing")
    bad_faults = (G.G3FaultPathV2(String(fault_mutation.target), "missing-controller", :open_circuit,
        :trip, "missing-signal", 1 // 1),)
    bad_control = G.ControlGenomeV5(bundle.control.contract_binding, bundle.control.signal_ports,
        bundle.control.controllers, bad_faults, bundle.control.plan)
    bad_fault_bundle = _rebuild(bundle, bundle.realization, bad_control)
    bad_fault_errors = G.g3_admission(bad_fault_bundle).errors
    @test _fixture_negative("fault_target_or_detection_missing")
    @test "fault_target_missing:" * String(fault_mutation.target) in bad_fault_errors
    @test "fault_detection_signal_missing:" * String(fault_mutation.target) in bad_fault_errors

    @test _fixture_negative("provider_no_match_terminal_deferred")
    @test G.g3_provider_resolution(bundle) == :terminal_deferred
end

@testset "UP1-03 versioned references and JSON fixture boundary" begin
    @test_throws ArgumentError G.G3ContractBindingV2(
        G.GenomeContractRef("fusionconceptai://GenomeV5/G3/bad", "v1",
            G.digest256_text("bad-schema"), G.digest256_text("bad-canonical"), "bad"),
        _CANDIDATE, _axes("realization"))
    @test_throws ArgumentError G.G3ContractBindingV2(
        G.GenomeContractRef("fusionconceptai://GenomeV5/G3/realization", "v5",
            G.digest256_text("foreign-schema"), G.digest256_text("foreign-canonical"), "foreign-profile"),
        _CANDIDATE, _axes("realization"))
    @test_throws ArgumentError G.G3ContractBindingV2(
        G.g3_contract_ref(:realization), _CANDIDATE,
        G.G3VersionAxesV2(G.QualifiedRefV1("foreign/payload", "v5"),
            G.QualifiedRefV1("foreign/canonical", "v5"),
            G.QualifiedRefV1("foreign/applicability", "v5"),
            G.QualifiedRefV1("foreign/receipt", "v2")))
    @test_throws ArgumentError G.G3VersionAxesV2(G.QualifiedRefV1("legacy", "v1"),
        G.QualifiedRefV1("canonical", "v5"), G.QualifiedRefV1("profile", "v5"),
            G.QualifiedRefV1("receipt", "v2"))
    @test G.g3_contract_ref(:binding).version == "v2"
    @test G.g3_version_axes(:binding).payload_schema_version.version == "v2"
    binding_ref = G.g3_contract_ref(:binding)
    @test_throws ArgumentError G.G3ContractBindingV2(
        G.GenomeContractRef(binding_ref.uri, "v5", binding_ref.schema_hash,
            binding_ref.canonicalization_hash, binding_ref.compatibility_profile),
        _CANDIDATE, _axes("binding"))
    @test _fixture_negative("foreign_schema_or_axis_ref_rejected")
    @test _fixture_negative("wrong_candidate_ref_fail_closed")
    forged_candidate = G.QualifiedRefV1("fusionconceptai://candidate/FORGED", "v5")
    forged_realization_binding = G.G3ContractBindingV2(G.g3_contract_ref(:realization), forged_candidate, _axes("realization"))
    forged_control_binding = G.G3ContractBindingV2(G.g3_contract_ref(:control), forged_candidate, _axes("control"))
    forged_binding_contract = G.G3ContractBindingV2(G.g3_contract_ref(:binding), forged_candidate, _axes("binding"))
    forged_realization = G.RealizationGenomeV5(forged_realization_binding,
        _make_fixture().realization.network, _make_fixture().realization.material_domains,
        _make_fixture().realization.manufacturing_domains; provider_match=:no_match)
    forged_control = G.ControlGenomeV5(forged_control_binding,
        _make_fixture().control.signal_ports, _make_fixture().control.controllers,
        _make_fixture().control.faults, _make_fixture().control.plan; provider_match=:no_match)
    forged_coupling = G.CoupledRealizationControlBindingV2(forged_binding_contract,
        forged_realization_binding, forged_control_binding, _make_fixture().binding.links,
        _make_fixture().binding.feedback)
    forged_bundle = G.RealizationControlGenomeV5(_make_fixture().contract_binding,
        forged_realization, forged_control, forged_coupling)
    @test forged_bundle.admission.structural_status == :fail_closed
    @test "realization_candidate_binding_mismatch" in forged_bundle.admission.errors

    @test _fixture_negative("wrong_version_axis_fail_closed")
    axis_mutation = _mutation("wrong_version_axis_fail_closed")
    realization_axes = _axes("realization")
    bad_payload_axis = G.QualifiedRefV1(String(axis_mutation.value),
        realization_axes.payload_schema_version.version)
    @test_throws ArgumentError G.G3ContractBindingV2(G.g3_contract_ref(:realization),
        _candidate_ref("realization"), G.G3VersionAxesV2(bad_payload_axis,
            realization_axes.canonicalization_profile_version,
            realization_axes.applicability_profile_version,
            realization_axes.evidence_receipt_version))

    @test _fixture_negative("feedback_target_role_mismatch_fail_closed")
    bad_target = G.GenomeContractRef("fusionconceptai://GenomeV5/G2/other-role", "v5",
        G.Digest256(repeat("0", 64)), G.Digest256(repeat("0", 64)),
        "pending-external-authority-g1")
    bad_feedback = Tuple(x.feedback_id == "g1-loss" ?
        G.G3FeedbackChannelV2(x.feedback_id, x.target_layer, bad_target, x.channel,
            x.unit, x.kind, x.source_id) : x for x in _make_fixture().binding.feedback)
    base = _make_fixture()
    bad_binding = G.CoupledRealizationControlBindingV2(base.binding.contract_binding,
        base.realization.contract_binding, base.control.contract_binding,
        base.binding.links, bad_feedback)
    bad_feedback_bundle = G.RealizationControlGenomeV5(base.contract_binding,
        base.realization, base.control, bad_binding)
    @test bad_feedback_bundle.admission.structural_status == :fail_closed
    @test "feedback_target_uri_layer_mismatch:g1-loss" in bad_feedback_bundle.admission.errors

    @test _fixture_negative("feedback_target_authority_required")
    pending_binding_errors, pending_binding_gaps = G.g3_validate_binding(base.binding,
        base.realization, base.control)
    @test isempty(pending_binding_errors)
    @test "feedback_authority_gap:g1-loss:G1" in pending_binding_gaps
    provided_g1 = G.GenomeContractRef(_target_ref("G1").uri, "v5",
        G.digest256_text("actual-g1-schema"), G.digest256_text("actual-g1-canonical"),
        "actual-g1-profile")
    provided_g2 = G.GenomeContractRef(_target_ref("G2").uri, "v5",
        G.digest256_text("actual-g2-schema"), G.digest256_text("actual-g2-canonical"),
        "actual-g2-profile")
    synthetic_feedback = Tuple(
        x.feedback_id == "g1-loss" ? G.G3FeedbackChannelV2(x.feedback_id, x.target_layer,
            provided_g1, x.channel, x.unit, x.kind, x.source_id) :
        G.G3FeedbackChannelV2(x.feedback_id, x.target_layer, provided_g2, x.channel,
            x.unit, x.kind, x.source_id) for x in base.binding.feedback)
    synthetic_binding = G.CoupledRealizationControlBindingV2(base.binding.contract_binding,
        base.realization.contract_binding, base.control.contract_binding, base.binding.links,
        synthetic_feedback)
    # synthetic_equality_only: matching values never establish provenance or clear the gap.
    authority_errors, authority_gaps = G.g3_compare_feedback_target_refs(synthetic_binding,
        provided_g1, provided_g2)
    @test !any(startswith(e, "feedback_target_authority_") for e in authority_errors)
    @test "feedback_authority_gap:g1-loss:G1" in authority_gaps
    @test "feedback_authority_gap:g2-thermal:G2" in authority_gaps
    @test _fixture_negative("synthetic_equality_only")
end
