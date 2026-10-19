using Test
using JSON3
using FusionConceptAI

const _FVLC_SOURCE = normpath(joinpath(@__DIR__, "../../src/RuntimeV4/FinalValidationLedgerContractV1.jl"))
@assert isfile(_FVLC_SOURCE)
include(_FVLC_SOURCE)

const _FVLC_FIXTURE_PATH = joinpath(@__DIR__, "fixtures", "final_validation_ledger_contract_v1.json")
const _FVLC_FIXTURE = JSON3.read(read(_FVLC_FIXTURE_PATH, String))
const _FVLC_HASH_A = repeat("a", 64)
const _FVLC_HASH_B = repeat("b", 64)
const _FVLC_R_IDS = Tuple(String(x) for x in _FVLC_FIXTURE.required_r_ids)
const _FVLC_ENG_IDS = Tuple(String(x) for x in _FVLC_FIXTURE.engineering_families)
const _FVLC_NEGATIVE_IDS = Tuple(String(x.id) for x in _FVLC_FIXTURE.negative)
const _FVLC_NEGATIVE_EXPECTED = Dict(
    String(x.id) => Symbol(String(x.expected_status)) for x in _FVLC_FIXTURE.negative)

const _FVLC_DIMENSIONS = Tuple(String(x) for x in _FVLC_FIXTURE.dimensions)

function _fvlc_identity(hash_text, candidate; missing=())
    h(field) = field in missing ? nothing : hash_text
    FinalValidationLedgerIdentityV1(
        candidate_ref=candidate,
        mission_hash=h(:mission_hash), mechanism_hash=h(:mechanism_hash),
        field_geometry_hash=h(:field_geometry_hash), realization_control_hash=h(:realization_control_hash),
        genome_bundle_hash=h(:genome_bundle_hash), physical_subject_hash=h(:physical_subject_hash),
        solver_input_hash=h(:solver_input_hash), scenario_manifest_hash=h(:scenario_manifest_hash),
        provider_ref=h(:provider_ref) === nothing ? nothing : "provider.local", provider_hash=h(:provider_hash),
        toolchain_ref=h(:toolchain_ref) === nothing ? nothing : "julia-project", toolchain_hash=h(:toolchain_hash),
        source_tree_ref=h(:source_tree_ref) === nothing ? nothing : "working-tree", source_tree_hash=h(:source_tree_hash),
        build_ref=h(:build_ref) === nothing ? nothing : "build.local", build_hash=h(:build_hash),
        channel_ref=h(:channel_ref) === nothing ? nothing : "package-lock", channel_hash=h(:channel_hash),
        interpreter_ref=h(:interpreter_ref) === nothing ? nothing : "julia", interpreter_hash=h(:interpreter_hash),
        module_ref=h(:module_ref) === nothing ? nothing : "FusionConceptAI", module_hash=h(:module_hash))
end

function _fvlc_rows(identity; physical_status=:pass, numerical_status=:pass,
        execution_classification=:process_completed, ledger_status=:observed,
        evidence=true, applicability=:required, provider_match=:unique_match,
        resolution=:resolved, metrics=FinalValidationLedgerMetricsV1(), required=true,
        evidence_candidate_ref=identity.candidate_ref,
        evidence_physical_subject_hash=identity.physical_subject_hash,
        evidence_solver_input_hash=identity.solver_input_hash,
        evidence_scenario_ref=string(identity.scenario_manifest_hash))
    ids = (_FVLC_R_IDS..., _FVLC_ENG_IDS...)
    Tuple(FinalValidationLedgerObligationV1(id, startswith(id, "R") ? :requirement : :engineering,
        "candidate-bound $id obligation"; required=required, ledger_status=ledger_status,
        applicability=applicability, provider_match=provider_match, resolution=resolution,
        execution_classification=execution_classification,
        numerical_status=numerical_status, physical_status=physical_status,
        lifecycle=:terminal_classified, identity=identity, metrics=metrics,
        evidence_refs=evidence ? (FinalValidationLedgerEvidenceRefV1(
            "evidence.$id", :verification, content_hash=_FVLC_HASH_A,
            candidate_ref=evidence_candidate_ref, scenario_ref=evidence_scenario_ref,
            physical_subject_hash=evidence_physical_subject_hash,
            solver_input_hash=evidence_solver_input_hash,
            independence_group="group-a", status=:pass),) : ()) for id in ids)
end

function _fvlc_ledger(identity, rows)
    FinalValidationLedgerContractV1("ledger.whole-device.001", identity, rows;
        protocol_hash=_FVLC_HASH_A, claim_ceiling=:contract_only)
end

function _fvlc_fixture_negative(identity, id)
    id == "identity_mismatch" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(_fvlc_identity(_FVLC_HASH_B, "candidate.other"))))
    id == "provider_out_of_domain" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; provider_match=:out_of_domain,
            resolution=:terminal_deferred, execution_classification=:not_executed,
            numerical_status=:not_executed, physical_status=:not_applicable)))
    id == "exit_zero_missing_terminal_artifact" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; evidence=false,
            execution_classification=:process_completed)))
    id == "iteration_limit" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; numerical_status=:numerical_fail)))
    id == "negative_engineering_margin" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; physical_status=:physical_fail)))
    id == "net_output_interval_crosses_zero" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; metrics=FinalValidationLedgerMetricsV1(
            net_output=(status=:unknown, interval_crosses_zero=true,)))) )
    id == "calibration_reused_as_held_out" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; metrics=FinalValidationLedgerMetricsV1(
            vvuq=(status=:unknown, calibration_heldout_disjoint=false,)))) )
    id == "not_applicable_without_proof" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; applicability=:not_applicable)))
    id == "historical_receipt_as_fresh" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; metrics=FinalValidationLedgerMetricsV1(
            replay=(status=:unknown, historical_receipt_as_fresh=true,)))) )
    id == "missing_required_scenario" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; metrics=FinalValidationLedgerMetricsV1(
            engineering=(status=:unknown, required_scenarios_complete=false,)))) )
    id == "evidence_binding_mismatch" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; evidence_candidate_ref="candidate.other")))
    id == "required_false" && return validate_final_validation_ledger(
        _fvlc_ledger(identity, _fvlc_rows(identity; required=false)))
    error("unknown fixture negative: $id")
end

@testset "UP6 final validation ledger contract-only v1" begin
    @test _FVLC_FIXTURE.schema == "FinalValidationLedgerContractFixtureV1"
    @test _FVLC_FIXTURE.claim_ceiling == "contract_only"
    @test _FVLC_FIXTURE.publish == "no_publish"
    @test _FVLC_FIXTURE.accepted == false
    @test _FVLC_FIXTURE.evidence_credit == 0
    @test _FVLC_FIXTURE.l4_credible_count == 0
    @test _FVLC_FIXTURE.authority == "FinalWholeDeviceAuthorityV4"
    @test _FVLC_FIXTURE.all_obligations_required == true
    @test (_FVLC_R_IDS..., _FVLC_ENG_IDS...) == _FVLC_REQUIRED_ALL_IDS
    @test length(_FVLC_DIMENSIONS) == 16
    @test _FVLC_ALLOWED_STAGE ==
        (:pass, :physical_fail, :numerical_fail, :unknown, :not_applicable, :not_executed, :terminal_deferred)
    identity = _fvlc_identity(_FVLC_HASH_A, "candidate.001")
    ledger = _fvlc_ledger(identity, _fvlc_rows(identity))
    default_ledger = FinalValidationLedgerContractV1("ledger.whole-device.default", identity,
        _fvlc_rows(identity); protocol_hash=_FVLC_HASH_A)
    explicit_contract_ledger = FinalValidationLedgerContractV1("ledger.whole-device.default", identity,
        _fvlc_rows(identity); protocol_hash=_FVLC_HASH_A, claim_ceiling=:contract_only)
    @test default_ledger.claim_ceiling == :contract_only
    @test explicit_contract_ledger.claim_ceiling == :contract_only
    @test semantic_view(default_ledger) == semantic_view(explicit_contract_ledger)
    @test canonical_hash(default_ledger) == canonical_hash(explicit_contract_ledger)
    @test_throws ArgumentError FinalValidationLedgerContractV1("ledger.whole-device.screen", identity,
        _fvlc_rows(identity); protocol_hash=_FVLC_HASH_A, claim_ceiling=:screen_only)
    decision = validate_final_validation_ledger(ledger)
    @test decision.status == :contract_only
    @test !decision.accepted
    @test decision.claim_ceiling == :contract_only
    @test decision.publish == :no_publish
    @test decision.evidence_credit == 0
    @test decision.authority == "FinalWholeDeviceAuthorityV4"
    @test canonical_hash(ledger) == ledger.ledger_hash
    @test canonical_hash(decision) == decision.decision_hash

    @test_throws MethodError FinalValidationLedgerContractV1(
        "raw-bypass", identity, ledger.obligations, nothing, "FinalWholeDeviceAuthorityV4",
        :reserved_not_implemented, :contract_only, false, :no_publish, 0, ledger.ledger_hash)
    raw_row = ledger.obligations[1]
    @test_throws MethodError FinalValidationLedgerObligationV1(
        raw_row.obligation_id, raw_row.family, raw_row.requirement, raw_row.required,
        raw_row.ledger_status, raw_row.applicability, raw_row.provider_match,
        raw_row.resolution, raw_row.execution_classification, raw_row.numerical_status,
        raw_row.physical_status, raw_row.lifecycle, raw_row.claim_ceiling,
        raw_row.authority, raw_row.accepted, raw_row.identity, raw_row.evidence_refs,
        raw_row.metrics, raw_row.remaining_gaps)
    @test_throws MethodError FinalValidationLedgerDecisionV1(
        :contract_only, false, :contract_only, :no_publish, 0,
        "FinalWholeDeviceAuthorityV4", ledger.ledger_hash, (), decision.decision_hash)

    # A freshly constructed token is not the trusted singleton.  The stolen
    # singleton is intentionally reachable in this isolated test, so each
    # token-bearing constructor must still repeat its complete invariants.
    forged_token = _FVLCConstructionToken()
    stolen_token = _FVLC_TOKEN
    @test forged_token !== stolen_token
    @test_throws ArgumentError FinalValidationLedgerObligationV1(forged_token,
        raw_row.obligation_id, raw_row.family, raw_row.requirement, raw_row.required,
        raw_row.ledger_status, raw_row.applicability, raw_row.provider_match,
        raw_row.resolution, raw_row.execution_classification, raw_row.numerical_status,
        raw_row.physical_status, raw_row.lifecycle, raw_row.claim_ceiling,
        raw_row.authority, true, raw_row.identity, raw_row.evidence_refs,
        raw_row.metrics, raw_row.remaining_gaps)
    @test_throws ArgumentError FinalValidationLedgerObligationV1(stolen_token,
        raw_row.obligation_id, raw_row.family, raw_row.requirement, raw_row.required,
        raw_row.ledger_status, raw_row.applicability, raw_row.provider_match,
        raw_row.resolution, raw_row.execution_classification, raw_row.numerical_status,
        raw_row.physical_status, raw_row.lifecycle, raw_row.claim_ceiling,
        raw_row.authority, true, raw_row.identity, raw_row.evidence_refs,
        raw_row.metrics, raw_row.remaining_gaps)
    @test_throws ArgumentError FinalValidationLedgerContractV1(forged_token,
        ledger.ledger_ref, ledger.identity, ledger.protocol_hash, ledger.obligations,
        ledger.authority, ledger.authority_status, ledger.claim_ceiling, true,
        ledger.publish, ledger.evidence_credit, ledger.ledger_hash)
    @test_throws ArgumentError FinalValidationLedgerContractV1(stolen_token,
        ledger.ledger_ref, ledger.identity, ledger.protocol_hash, ledger.obligations,
        ledger.authority, ledger.authority_status, ledger.claim_ceiling, true,
        ledger.publish, ledger.evidence_credit, ledger.ledger_hash)
    @test_throws ArgumentError FinalValidationLedgerDecisionV1(forged_token,
        decision.status, true, decision.claim_ceiling, decision.publish,
        decision.evidence_credit, decision.authority, decision.ledger_hash,
        decision.reasons, decision.decision_hash)
    @test_throws ArgumentError FinalValidationLedgerDecisionV1(stolen_token,
        decision.status, true, decision.claim_ceiling, decision.publish,
        decision.evidence_credit, decision.authority, decision.ledger_hash,
        decision.reasons, decision.decision_hash)

    missing_set = admit_final_validation_ledger() do
        FinalValidationLedgerContractV1("missing-r10", identity,
            ledger.obligations[1:end-1]; protocol_hash=_FVLC_HASH_A)
    end
    @test missing_set.status == :fail_closed
    foreign_set = admit_final_validation_ledger() do
        foreign = FinalValidationLedgerObligationV1("ENG-FOREIGN", :engineering,
            "foreign obligation"; ledger_status=:observed,
            execution_classification=:process_completed, numerical_status=:pass,
            physical_status=:pass, lifecycle=:terminal_classified, identity=identity)
        FinalValidationLedgerContractV1("foreign-id", identity,
            (foreign, ledger.obligations[2:end]...); protocol_hash=_FVLC_HASH_A)
    end
    @test foreign_set.status == :fail_closed
    duplicate_set = admit_final_validation_ledger() do
        FinalValidationLedgerContractV1("duplicate-id", identity,
            (ledger.obligations[1], ledger.obligations[1], ledger.obligations[3:end]...);
            protocol_hash=_FVLC_HASH_A)
    end
    @test duplicate_set.status == :fail_closed

    precedence_identity_provider = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(_fvlc_identity(_FVLC_HASH_B, "candidate.other");
            provider_match=:out_of_domain, resolution=:terminal_deferred,
            numerical_status=:numerical_fail)))
    @test precedence_identity_provider.status == :fail_closed
    precedence_provider_numerical = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(identity; provider_match=:out_of_domain,
            resolution=:terminal_deferred, numerical_status=:numerical_fail)))
    @test precedence_provider_numerical.status == :terminal_deferred
    precedence_program_numerical = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(identity; execution_classification=:program_exception,
            numerical_status=:numerical_fail)))
    @test precedence_program_numerical.status == :unknown
    precedence_numerical_physical = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(identity; numerical_status=:numerical_fail,
            physical_status=:physical_fail)))
    @test precedence_numerical_physical.status == :numerical_fail
    precedence_physical_unknown = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(identity; physical_status=:physical_fail,
            execution_classification=:unknown)))
    @test precedence_physical_unknown.status == :physical_fail
    precedence_unknown_deferred = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(identity; execution_classification=:unknown, ledger_status=:pending)))
    @test precedence_unknown_deferred.status == :unknown
    precedence_deferred_only = validate_final_validation_ledger(_fvlc_ledger(identity,
        _fvlc_rows(identity; execution_classification=:not_executed,
            numerical_status=:not_executed, physical_status=:not_applicable,
            ledger_status=:pending, evidence=false)))
    @test precedence_deferred_only.status == :terminal_deferred

    pending = _fvlc_ledger(FinalValidationLedgerIdentityV1(),
        _fvlc_rows(FinalValidationLedgerIdentityV1(); ledger_status=:pending, evidence=false))
    pending_decision = validate_final_validation_ledger(pending)
    @test pending_decision.status == :terminal_deferred
    @test any(occursin(":identity_pending", reason) for reason in pending_decision.reasons)
    @test any(occursin(":evidence_missing", reason) for reason in pending_decision.reasons)
    @test pending_decision.publish == :no_publish

    identity_mismatch = _fvlc_rows(identity)
    mismatched_row = FinalValidationLedgerObligationV1(identity_mismatch[1].obligation_id,
        identity_mismatch[1].family, identity_mismatch[1].requirement;
        ledger_status=:observed, provider_match=:unique_match, resolution=:resolved,
        execution_classification=:process_completed, numerical_status=:pass,
        physical_status=:pass, lifecycle=:terminal_classified,
        identity=_fvlc_identity(_FVLC_HASH_B, "candidate.other"),
        evidence_refs=identity_mismatch[1].evidence_refs)
    mismatch_decision = validate_final_validation_ledger(_fvlc_ledger(identity,
        (mismatched_row, identity_mismatch[2:end]...)))
    @test mismatch_decision.status == :fail_closed
    @test "R01:identity_mismatch" in mismatch_decision.reasons

    provider_gap = _fvlc_rows(identity)
    provider_row = FinalValidationLedgerObligationV1(provider_gap[1].obligation_id,
        provider_gap[1].family, provider_gap[1].requirement;
        ledger_status=:observed, provider_match=:out_of_domain,
        resolution=:terminal_deferred, execution_classification=:not_executed,
        numerical_status=:not_executed, physical_status=:not_applicable,
        lifecycle=:compiled, identity=identity,
        evidence_refs=provider_gap[1].evidence_refs)
    provider_decision = validate_final_validation_ledger(_fvlc_ledger(identity,
        (provider_row, provider_gap[2:end]...)))
    @test provider_decision.status == :terminal_deferred
    @test "R01:provider_match_gap" in provider_decision.reasons

    for mismatched_rows in (
            _fvlc_rows(identity; evidence_candidate_ref="candidate.other"),
            _fvlc_rows(identity; evidence_physical_subject_hash=_FVLC_HASH_B),
            _fvlc_rows(identity; evidence_solver_input_hash=_FVLC_HASH_B),
            _fvlc_rows(identity; evidence_scenario_ref="scenario.other"))
        evidence_binding_decision = validate_final_validation_ledger(
            _fvlc_ledger(identity, mismatched_rows))
        @test evidence_binding_decision.status == :fail_closed
        @test any(occursin(":evidence_binding_mismatch", reason)
            for reason in evidence_binding_decision.reasons)
    end

    for field in (:mission_hash, :mechanism_hash, :field_geometry_hash, :realization_control_hash)
        missing_identity = _fvlc_identity(_FVLC_HASH_A, "candidate.001"; missing=(field,))
        missing_decision = validate_final_validation_ledger(_fvlc_ledger(missing_identity,
            _fvlc_rows(missing_identity; ledger_status=:pending,
                execution_classification=:not_executed,
                numerical_status=:not_executed, physical_status=:not_applicable,
                evidence=false)))
        @test missing_decision.status == :terminal_deferred
        @test any(occursin(":identity_pending", reason) for reason in missing_decision.reasons)
    end

    iteration_limit = _fvlc_ledger(identity, _fvlc_rows(identity;
        numerical_status=:numerical_fail))
    @test validate_final_validation_ledger(iteration_limit).status == :numerical_fail

    negative_margin = _fvlc_ledger(identity, _fvlc_rows(identity;
        physical_status=:physical_fail))
    @test validate_final_validation_ledger(negative_margin).status == :physical_fail

    unknown_interval = _fvlc_ledger(identity, _fvlc_rows(identity;
        execution_classification=:unknown, physical_status=:unknown))
    @test validate_final_validation_ledger(unknown_interval).status == :unknown

    not_applicable_without_proof = _fvlc_rows(identity)
    not_applicable_row = FinalValidationLedgerObligationV1(
        not_applicable_without_proof[1].obligation_id,
        not_applicable_without_proof[1].family,
        not_applicable_without_proof[1].requirement;
        ledger_status=:observed, applicability=:not_applicable,
        provider_match=:unique_match, resolution=:resolved,
        execution_classification=:process_completed, numerical_status=:pass,
        physical_status=:not_applicable, lifecycle=:terminal_classified,
        identity=identity, evidence_refs=not_applicable_without_proof[1].evidence_refs)
    @test validate_final_validation_ledger(_fvlc_ledger(identity,
        (not_applicable_row, not_applicable_without_proof[2:end]...))).status == :terminal_deferred

    @test _FVLC_PUBLISH === :no_publish
    @test _FVLC_AUTHORITY == "FinalWholeDeviceAuthorityV4"
    @test length(_FVLC_NEGATIVE_IDS) == 12

    for negative_id in _FVLC_NEGATIVE_IDS
        @testset "fixture negative $negative_id" begin
            result = _fvlc_fixture_negative(identity, negative_id)
            @test result.status === _FVLC_NEGATIVE_EXPECTED[negative_id]
            @test result.publish === :no_publish
            @test !result.accepted
            @test result.evidence_credit == 0
        end
    end
end


@testset "UP6 candidate-bound station-cycle energy consumer" begin
    candidate_identity = _fvlc_identity(_FVLC_HASH_A, "candidate.station.001")
    station_boundary_ref = "station.boundary.v1"
    cycle_id = "cycle.full.001"
    times = (0.0, 5.0, 10.0)

    function station_evidence(id, kind, term; identity=candidate_identity,
            boundary=station_boundary_ref, cycle=cycle_id, measurement=id,
            scopes=("scope.$id",), status=:pass, content_hash=_FVLC_HASH_A)
        raw = FinalValidationLedgerEvidenceRefV1(id, kind;
            content_hash=content_hash, candidate_ref=identity.candidate_ref,
            scenario_ref=string(identity.scenario_manifest_hash),
            physical_subject_hash=identity.physical_subject_hash,
            solver_input_hash=identity.solver_input_hash,
            independence_group="station-cycle-oracle", status=status)
        StationCycleEvidenceV1(raw, boundary, cycle, term, measurement, scopes)
    end
    function station_trace(label, power, error_bound, scope, data_term, uncertainty_term;
            meter="meter.$label", identity=candidate_identity, boundary=station_boundary_ref,
            cycle=cycle_id, trace_times=times, uncertainty=true, data=true)
        data = data ? station_evidence("$label.data", :net_output, data_term;
            identity=identity, boundary=boundary, cycle=cycle, measurement=meter,
            scopes=(scope,)) : nothing
        uncertainty_evidence = uncertainty ? station_evidence(
            "$label.uncertainty", :uncertainty, uncertainty_term;
            identity=identity, boundary=boundary, cycle=cycle, measurement=meter,
            scopes=(scope,)) : nothing
        StationPowerTraceV1(trace_times, power, error_bound, meter, (scope,),
            data, uncertainty_evidence)
    end
    function station_input(; identity=candidate_identity,
            gross=station_trace("gross", (100.0, 100.0, 100.0), (1.0, 1.0, 1.0),
                "gross_generation", :gross_generation, :gross_generation),
            auxiliary=station_trace("aux", (20.0, 20.0, 20.0), (0.5, 0.5, 0.5),
                "auxiliary_consumption", :auxiliary_consumption,
                :auxiliary_consumption),
            loss=station_trace("loss", (10.0, 10.0, 10.0), (0.2, 0.2, 0.2),
                "conversion_loss", :loss, :loss),
            storage_start=100.0, storage_end=150.0,
            storage_start_error=2.0, storage_end_error=3.0,
            storage_scope=("storage_battery",),
            storage_start_measurement="meter.storage.start",
            storage_end_measurement="meter.storage.end",
            storage_start_evidence=station_evidence("storage.start.data",
                :net_output, :storage_start; measurement=storage_start_measurement,
                scopes=storage_scope),
            storage_start_uncertainty=station_evidence("storage.start.uncertainty",
                :uncertainty, :storage_start; measurement=storage_start_measurement,
                scopes=storage_scope),
            storage_end_evidence=station_evidence("storage.end.data",
                :net_output, :storage_end; measurement=storage_end_measurement,
                scopes=storage_scope),
            storage_end_uncertainty=station_evidence("storage.end.uncertainty",
                :uncertainty, :storage_end; measurement=storage_end_measurement,
                scopes=storage_scope),
            boundary=station_boundary_ref, cycle=cycle_id, cycle_end=10.0, maximum_gap=5.0)
        StationCycleEnergyInputV1(identity; station_boundary_ref=boundary,
            cycle_id=cycle, cycle_start_s=0.0, cycle_end_s=cycle_end,
            maximum_gap_s=maximum_gap, gross=gross, auxiliary=auxiliary, loss=loss,
            storage_start_j=storage_start, storage_end_j=storage_end,
            storage_start_error_bound_j=storage_start_error,
            storage_end_error_bound_j=storage_end_error,
            storage_start_evidence=storage_start_evidence,
            storage_start_uncertainty_evidence=storage_start_uncertainty,
            storage_end_evidence=storage_end_evidence,
            storage_end_uncertainty_evidence=storage_end_uncertainty)
    end

    positive = station_cycle_net_output_v1(station_input())
    @test positive.status === :screen_only
    @test positive.detail === :sampled_trapezoid_interval
    @test positive.classification === :sampled_positive_lower_bound
    # Trapezoidal integration gives 1000 - 200 - 100 - (150 - 100) = 650 J.
    # Worst-case absolute bounds sum to 10 + 5 + 2 + 2 + 3 = 22 J.
    @test positive.sampled_measurement_interval_j == (628.0, 672.0)
    @test positive.propagated_sample_measurement_bound_j == 22.0
    @test positive.limitations ==
        (:between_sample_waveform_and_quadrature_error_unbounded,
         :storage_endpoint_timestamps_unverified,
         :component_scope_physical_provenance_unverified,
         :statistical_coverage_and_distribution_model_missing)
    @test positive.metrics isa FinalValidationLedgerMetricsV1
    @test positive.metrics.net_output.units == (power=:W, time=:s, energy=:J)
    @test positive.metrics.net_output.counted_terms ==
        (:gross_generation, :auxiliary_consumption, :loss, :storage_delta)
    @test positive.metrics.vvuq.status === :typed_absent
    @test !positive.metrics.net_output.interval_crosses_zero
    @test positive.metrics.net_output.integration_scope === :sampled_trapezoid_only
    @test positive.metrics.net_output.sampled_measurement_interval_j ==
        positive.sampled_measurement_interval_j
    @test positive.metrics.net_output.limitations == positive.limitations
    @test positive.metrics.vvuq.status === :typed_absent
    @test positive.metrics.vvuq.reason == positive.limitations
    @test station_cycle_net_output_v1(nothing).status === :typed_absent
    discharged = station_cycle_net_output_v1(station_input(
        storage_start=150.0, storage_end=100.0))
    @test discharged.sampled_net_energy_estimate_j == 750.0
    @test discharged.classification === :sampled_positive_lower_bound

    crossing = station_cycle_net_output_v1(station_input(
        gross=station_trace("cross.gross", (20.0, 20.0, 20.0), (2.0, 2.0, 2.0),
            "gross_generation", :gross_generation, :gross_generation),
        auxiliary=station_trace("cross.aux", (20.0, 20.0, 20.0), (1.0, 1.0, 1.0),
            "auxiliary_consumption", :auxiliary_consumption,
            :auxiliary_consumption),
        loss=station_trace("cross.loss", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0),
            "conversion_loss", :loss, :loss),
        storage_start=100.0, storage_end=100.0,
        storage_start_error=0.0, storage_end_error=0.0))
    @test crossing.status === :screen_only
    @test crossing.classification === :sampled_interval_crosses_zero
    @test crossing.sampled_measurement_interval_j[1] < 0 <
        crossing.sampled_measurement_interval_j[2]
    @test crossing.metrics.net_output.interval_crosses_zero
    net_rows = _fvlc_rows(candidate_identity)
    net_index = only(findall(row -> row.obligation_id == "ENG-NET-LEDGER", net_rows))
    net_base = net_rows[net_index]
    net_obligation = FinalValidationLedgerObligationV1(net_base.obligation_id,
        net_base.family, net_base.requirement; required=net_base.required,
        ledger_status=net_base.ledger_status, applicability=net_base.applicability,
        provider_match=net_base.provider_match, resolution=net_base.resolution,
        execution_classification=net_base.execution_classification,
        numerical_status=net_base.numerical_status,
        physical_status=net_base.physical_status, lifecycle=net_base.lifecycle,
        identity=net_base.identity, evidence_refs=net_base.evidence_refs,
        metrics=crossing.metrics, remaining_gaps=net_base.remaining_gaps)
    crossing_rows = Tuple(i == net_index ? net_obligation : net_rows[i]
        for i in eachindex(net_rows))
    crossing_decision = validate_final_validation_ledger(_fvlc_ledger(
        candidate_identity, crossing_rows))
    @test crossing_decision.status === :unknown
    @test any(occursin(":net_output_interval_crosses_zero", reason)
        for reason in crossing_decision.reasons)

    duplicate_meter = station_input(auxiliary=station_trace("duplicate", (20.0, 20.0, 20.0),
        (0.5, 0.5, 0.5), "auxiliary_consumption", :auxiliary_consumption,
        :auxiliary_consumption; meter="meter.gross"))
    duplicate_meter_result = station_cycle_net_output_v1(duplicate_meter)
    @test duplicate_meter_result.status === :fail_closed
    @test duplicate_meter_result.detail === :duplicate_meter_ref

    duplicate_scope = station_input(auxiliary=station_trace("overlap", (20.0, 20.0, 20.0),
        (0.5, 0.5, 0.5), "gross_generation", :auxiliary_consumption,
        :auxiliary_consumption))
    duplicate_scope_result = station_cycle_net_output_v1(duplicate_scope)
    @test duplicate_scope_result.status === :fail_closed
    @test duplicate_scope_result.detail === :double_counted_component_scope

    storage_scope_overlap = station_input(
        storage_start_evidence=station_evidence("storage.overlap.start.data",
            :net_output, :storage_start; measurement="meter.storage.start",
            scopes=("gross_generation",)),
        storage_start_uncertainty=station_evidence("storage.overlap.start.uq",
            :uncertainty, :storage_start; measurement="meter.storage.start",
            scopes=("gross_generation",)),
        storage_end_evidence=station_evidence("storage.overlap.end.data",
            :net_output, :storage_end; measurement="meter.storage.end",
            scopes=("gross_generation",)),
        storage_end_uncertainty=station_evidence("storage.overlap.end.uq",
            :uncertainty, :storage_end; measurement="meter.storage.end",
            scopes=("gross_generation",)))
    storage_scope_overlap_result = station_cycle_net_output_v1(storage_scope_overlap)
    @test storage_scope_overlap_result.status === :fail_closed
    @test storage_scope_overlap_result.detail === :double_counted_component_scope

    storage_scope_mismatch = station_input(
        storage_end_evidence=station_evidence("storage.other.end.data",
            :net_output, :storage_end; measurement="meter.storage.end",
            scopes=("storage_other",)),
        storage_end_uncertainty=station_evidence("storage.other.end.uq",
            :uncertainty, :storage_end; measurement="meter.storage.end",
            scopes=("storage_other",)))
    storage_scope_mismatch_result = station_cycle_net_output_v1(storage_scope_mismatch)
    @test storage_scope_mismatch_result.status === :fail_closed
    @test storage_scope_mismatch_result.detail === :storage_scope_mismatch

    storage_meter_overlap = station_input(
        storage_start_evidence=station_evidence("storage.shared.start.data",
            :net_output, :storage_start; measurement="meter.gross",
            scopes=("storage_battery",)),
        storage_start_uncertainty=station_evidence("storage.shared.start.uq",
            :uncertainty, :storage_start; measurement="meter.gross",
            scopes=("storage_battery",)))
    storage_meter_overlap_result = station_cycle_net_output_v1(storage_meter_overlap)
    @test storage_meter_overlap_result.status === :fail_closed
    @test storage_meter_overlap_result.detail === :duplicate_meter_ref

    mismatched_boundary_trace = station_trace("boundary", (100.0, 100.0, 100.0),
        (1.0, 1.0, 1.0), "gross_generation", :gross_generation,
        :gross_generation; boundary="station.boundary.foreign")
    mismatched_boundary = station_cycle_net_output_v1(
        station_input(gross=mismatched_boundary_trace))
    @test mismatched_boundary.status === :fail_closed
    @test mismatched_boundary.detail === :evidence_binding_mismatch
    function replace_gross_data_evidence(trace, evidence)
        StationPowerTraceV1(trace.time_s, trace.power_w,
            trace.absolute_error_bound_w, trace.meter_ref,
            trace.component_scope_refs, evidence, trace.uncertainty_evidence)
    end
    baseline_gross = station_trace("evidence-join", (100.0, 100.0, 100.0),
        (1.0, 1.0, 1.0), "gross_generation", :gross_generation, :gross_generation)
    wrong_term = replace_gross_data_evidence(baseline_gross,
        StationCycleEvidenceV1(baseline_gross.data_evidence.evidence,
            station_boundary_ref, cycle_id, :loss, baseline_gross.meter_ref,
            baseline_gross.component_scope_refs))
    wrong_term_result = station_cycle_net_output_v1(station_input(gross=wrong_term))
    @test wrong_term_result.status === :fail_closed
    @test wrong_term_result.detail === :evidence_binding_mismatch
    wrong_measurement = replace_gross_data_evidence(baseline_gross,
        station_evidence("wrong-meter.data", :net_output, :gross_generation;
            measurement="meter.foreign", scopes=baseline_gross.component_scope_refs))
    wrong_measurement_result = station_cycle_net_output_v1(
        station_input(gross=wrong_measurement))
    @test wrong_measurement_result.status === :fail_closed
    @test wrong_measurement_result.detail === :evidence_binding_mismatch
    wrong_scope = replace_gross_data_evidence(baseline_gross,
        station_evidence("wrong-scope.data", :net_output, :gross_generation;
            measurement=baseline_gross.meter_ref, scopes=("other_scope",)))
    wrong_scope_result = station_cycle_net_output_v1(station_input(gross=wrong_scope))
    @test wrong_scope_result.status === :fail_closed
    @test wrong_scope_result.detail === :evidence_binding_mismatch
    missing_hash = replace_gross_data_evidence(baseline_gross,
        station_evidence("missing-hash.data", :net_output, :gross_generation;
            content_hash=nothing, measurement=baseline_gross.meter_ref,
            scopes=baseline_gross.component_scope_refs))
    missing_hash_result = station_cycle_net_output_v1(station_input(gross=missing_hash))
    @test missing_hash_result.status === :fail_closed
    @test missing_hash_result.detail === :evidence_binding_mismatch
    wrong_cycle = station_trace("wrong-cycle", (100.0, 100.0, 100.0),
        (1.0, 1.0, 1.0), "gross_generation", :gross_generation, :gross_generation;
        cycle="cycle.foreign")
    wrong_cycle_result = station_cycle_net_output_v1(station_input(gross=wrong_cycle))
    @test wrong_cycle_result.status === :fail_closed
    @test wrong_cycle_result.detail === :evidence_binding_mismatch

    incomplete_cycle = station_cycle_net_output_v1(station_input(
        gross=station_trace("partial", (100.0, 100.0, 100.0), (1.0, 1.0, 1.0),
            "gross_generation", :gross_generation, :gross_generation;
            trace_times=(1.0, 5.0, 10.0)),
        auxiliary=station_trace("partial.aux", (20.0, 20.0, 20.0),
            (0.5, 0.5, 0.5), "auxiliary_consumption", :auxiliary_consumption,
            :auxiliary_consumption; trace_times=(1.0, 5.0, 10.0)),
        loss=station_trace("partial.loss", (10.0, 10.0, 10.0),
            (0.2, 0.2, 0.2), "conversion_loss", :loss, :loss;
            trace_times=(1.0, 5.0, 10.0))))
    @test incomplete_cycle.status === :typed_absent
    @test incomplete_cycle.detail === :cycle_boundary_not_fully_sampled
    excessive_gap = station_cycle_net_output_v1(station_input(maximum_gap=4.0))
    @test excessive_gap.status === :typed_absent
    @test excessive_gap.detail === :cycle_gap_exceeds_declared_maximum

    mismatched_grid = station_input(auxiliary=station_trace("grid", (20.0, 20.0, 20.0),
        (0.5, 0.5, 0.5), "auxiliary_consumption", :auxiliary_consumption,
        :auxiliary_consumption; trace_times=(0.0, 4.0, 10.0)))
    @test station_cycle_net_output_v1(mismatched_grid).detail === :time_grid_mismatch

    foreign_trace = station_trace("foreign", (100.0, 100.0, 100.0),
        (1.0, 1.0, 1.0), "gross_generation", :gross_generation,
        :gross_generation;
        identity=_fvlc_identity(_FVLC_HASH_B, "candidate.foreign"))
    foreign_result = station_cycle_net_output_v1(station_input(gross=foreign_trace))
    @test foreign_result.status === :fail_closed
    @test foreign_result.detail === :evidence_binding_mismatch

    missing_uncertainty = station_input(auxiliary=station_trace("no-uq",
        (20.0, 20.0, 20.0), (0.5, 0.5, 0.5), "auxiliary_consumption",
        :auxiliary_consumption, :auxiliary_consumption;
        uncertainty=false))
    @test station_cycle_net_output_v1(missing_uncertainty).status === :typed_absent
    missing_data = station_cycle_net_output_v1(station_input(gross=station_trace(
        "no-data", (100.0, 100.0, 100.0), (1.0, 1.0, 1.0),
        "gross_generation", :gross_generation, :gross_generation; data=false)))
    @test missing_data.status === :typed_absent
    # Evidence status and content hash are checked at the consumer boundary.
    pending_data = station_trace("pending", (100.0, 100.0, 100.0),
        (1.0, 1.0, 1.0), "gross_generation", :gross_generation, :gross_generation;
        data=true)
    pending_data = StationPowerTraceV1(pending_data.time_s, pending_data.power_w,
        pending_data.absolute_error_bound_w, pending_data.meter_ref,
        pending_data.component_scope_refs,
        station_evidence("pending.data", :net_output, :gross_generation;
            status=:pending, measurement=pending_data.meter_ref,
            scopes=pending_data.component_scope_refs),
        pending_data.uncertainty_evidence)
    bad_evidence_status = station_cycle_net_output_v1(station_input(gross=pending_data))
    @test bad_evidence_status.status === :fail_closed
    @test bad_evidence_status.detail === :evidence_binding_mismatch
    incomplete_identity = _fvlc_identity(_FVLC_HASH_A, "candidate.station.001";
        missing=(:scenario_manifest_hash,))
    @test station_cycle_net_output_v1(station_input(identity=incomplete_identity)).status === :typed_absent
    println("UP6_STATION_SAMPLED_SUMMARY=" * JSON3.write((
        evidence_scope="synthetic_fixture", authority="screen_only",
        status=String(positive.status), detail=String(positive.detail),
        sampled_energy_j=positive.sampled_net_energy_estimate_j,
        sampled_measurement_interval_j=positive.sampled_measurement_interval_j,
        measurement_bound_j=positive.propagated_sample_measurement_bound_j,
        limitations=Tuple(String(x) for x in positive.limitations),
        vvuq_typed_absent=positive.metrics.vvuq.status === :typed_absent)))
end
