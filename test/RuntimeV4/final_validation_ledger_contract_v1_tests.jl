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
