# D1.3 static execution, ownership, replay, and claim firewall.
using FusionConceptAI
import FusionConceptAI: canonical_hash

function _texec_scenario_check(s::TimeIntegrationScenarioV4)
    expected = canonical_hash((revision=_TTR_REVISION, name=s.name, t_start=s.t_start,
        t_stop=s.t_stop, time_unit=s.time_unit, initial_values=s.initial_values))
    expected == s.scenario_hash || throw(ArgumentError("typed-time scenario tampered"))
    expected
end

function _texec_validate_numerical_authority(operation, compiled, residual_plan,
                                              refinement_protocol, event_plan)
    _texec_shape(operation, residual_plan, refinement_protocol, event_plan)
    if residual_plan !== nothing
        canonical_hash(residual_plan)
        residual_plan.compiled_prefix_hash == compiled.prefix_hash ||
            throw(ArgumentError("residual plan/compiled prefix mismatch"))
    end
    if refinement_protocol !== nothing
        canonical_hash(refinement_protocol)
    end
    if event_plan !== nothing
        canonical_hash(event_plan)
        event_plan.residual_plan.prefix_hash == compiled.prefix_hash ||
            throw(ArgumentError("event plan/compiled prefix mismatch"))
        canonical_hash(event_plan.mechanism_graph) == canonical_hash(compiled.mechanism_graph) ||
            throw(ArgumentError("event plan mechanism authority mismatch"))
    end
    true
end

function compile_typed_time_execution_plan(compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, scenario::TimeIntegrationScenarioV4;
        operation, residual_plan=nothing, refinement_protocol=nothing, event_plan=nothing)
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope,
        compiled.minimality_scope.scenario_scope)
    _texec_scenario_check(scenario)
    _texec_validate_numerical_authority(operation, compiled, residual_plan,
        refinement_protocol, event_plan)
    source_hash = _texec_source_hash()
    capability = _texec_capability(operation, compiled, residual_plan,
        refinement_protocol, event_plan)
    subject = _texec_subject(compiled, scenario, capability, operation,
        residual_plan, refinement_protocol, event_plan)
    provider = _texec_provider(capability, operation, source_hash)
    authority_hash = _texec_authority_hash(operation, compiled, subject, scenario,
        residual_plan, refinement_protocol, event_plan, capability, provider, source_hash)
    input = _texec_solver_input(subject, scenario, provider, operation, authority_hash,
        residual_plan, refinement_protocol, event_plan)
    plan_hash = canonical_hash((revision=_TEXEC_REVISION, authority=authority_hash,
        solver_input=input.solver_input_hash))
    plan = TypedTimeExecutionPlanV4(_TEXEC_TOKEN, operation, compiled, registry,
        subject, input, provider, scenario, residual_plan, refinement_protocol,
        event_plan, source_hash, authority_hash, plan_hash)
    canonical_hash(plan)
    plan
end

function _texec_check_plan(p::TypedTimeExecutionPlanV4)
    _runtime_validate_compiled_prefix(p.compiled, p.compiled.candidate, p.registry,
        p.compiled.mission_payload, p.compiled.bounds_payload,
        p.compiled.minimality_scope.comparison_scope,
        p.compiled.minimality_scope.scenario_scope)
    _texec_scenario_check(p.scenario)
    _texec_validate_numerical_authority(p.operation, p.compiled, p.residual_plan,
        p.refinement_protocol, p.event_plan)
    source_hash = _texec_source_hash()
    source_hash == p.source_hash || throw(ArgumentError("typed-time source authority changed"))
    capability = _texec_capability(p.operation, p.compiled, p.residual_plan,
        p.refinement_protocol, p.event_plan)
    subject = _texec_subject(p.compiled, p.scenario, capability, p.operation,
        p.residual_plan, p.refinement_protocol, p.event_plan)
    provider = _texec_provider(capability, p.operation, source_hash)
    authority_hash = _texec_authority_hash(p.operation, p.compiled, subject,
        p.scenario, p.residual_plan, p.refinement_protocol, p.event_plan,
        capability, provider, source_hash)
    input = _texec_solver_input(subject, p.scenario, provider, p.operation,
        authority_hash, p.residual_plan, p.refinement_protocol, p.event_plan)
    p.subject.physical_subject_hash == subject.physical_subject_hash ||
        throw(ArgumentError("typed-time subject authority mismatch"))
    p.provider.executor === nothing || throw(ArgumentError("typed-time provider must be static"))
    p.provider.manifest_hash == provider.manifest_hash && p.provider.code_hash == source_hash ||
        throw(ArgumentError("typed-time provider authority mismatch"))
    p.input.solver_input_hash == input.solver_input_hash &&
        p.input.physical_subject_hash == subject.physical_subject_hash &&
        p.input.scenario_hash == p.scenario.scenario_hash &&
        p.input.provider_manifest_hash == provider.manifest_hash &&
        p.input.input_schema_hash == provider.input_schema_hash ||
        throw(ArgumentError("typed-time solver input authority mismatch"))
    p.authority_hash == authority_hash || throw(ArgumentError("typed-time authority hash mismatch"))
    expected = canonical_hash((revision=_TEXEC_REVISION, authority=authority_hash,
        solver_input=input.solver_input_hash))
    expected == p.plan_hash || throw(ArgumentError("typed-time execution plan tampered"))
    expected
end
canonical_hash(x::TypedTimeExecutionPlanV4) = _texec_check_plan(x)

_texec_artifact_hash(x::TypedTimeResidualResultV4) = x.result_hash
_texec_artifact_hash(x::TimeRefinementReceiptV4) = canonical_hash(x)
_texec_artifact_hash(x::TypedTimeEventResultV4) = canonical_hash(x)

function _texec_trajectory(plan, result::TypedTimeResidualResultV4)
    identity = (revision=_TEXEC_REVISION,
        physical_subject=plan.subject.physical_subject_hash,
        solver_input=plan.input.solver_input_hash, execution_plan=plan.plan_hash,
        scenario=plan.scenario.scenario_hash, result=result.result_hash,
        status=result.status, times=result.times, states=result.states,
        event_hashes=(), mass_residual_norm=result.mass_solve_residual_norm,
        trajectory_defect_norm=result.trajectory_defect_norm,
        residual_norm=result.residual_norm)
    TypedTimeTrajectoryV4(_TEXEC_TOKEN, plan.subject.physical_subject_hash,
        plan.input.solver_input_hash, plan.plan_hash, plan.scenario.scenario_hash,
        result.result_hash, result.status, result.times, result.states, (),
        result.mass_solve_residual_norm, result.trajectory_defect_norm,
        result.residual_norm, canonical_hash(identity))
end

function _texec_trajectory(plan, result::TypedTimeEventResultV4)
    event_hashes = Tuple(canonical_hash(e) for e in result.events)
    identity = (revision=_TEXEC_REVISION,
        physical_subject=plan.subject.physical_subject_hash,
        solver_input=plan.input.solver_input_hash, execution_plan=plan.plan_hash,
        scenario=plan.scenario.scenario_hash, result=result.result_hash,
        status=result.status, times=result.times, states=result.states,
        event_hashes=event_hashes, mass_residual_norm=result.mass_residual_norm,
        trajectory_defect_norm=result.trajectory_defect_norm,
        residual_norm=result.residual_norm)
    TypedTimeTrajectoryV4(_TEXEC_TOKEN, plan.subject.physical_subject_hash,
        plan.input.solver_input_hash, plan.plan_hash, plan.scenario.scenario_hash,
        result.result_hash, result.status, result.times, result.states, event_hashes,
        result.mass_residual_norm, result.trajectory_defect_norm,
        result.residual_norm, canonical_hash(identity))
end

function _texec_status(artifact)
    if artifact isa TypedTimeResidualResultV4
        artifact.status === :integrated && return (pass, :evaluated_screen, nothing, nothing, ())
        return (numerical_fail, :numerical_failure, :numerical_failure,
            artifact.failure_reason, ("continuous_numerical_failure",))
    elseif artifact isa TimeRefinementReceiptV4
        artifact.status === :refinement_pass && return (pass, :evaluated_screen, nothing, nothing, ())
        return (numerical_fail, :refinement_failure, artifact.failure_code,
            artifact.failure_code === nothing ? "refinement failure" : String(artifact.failure_code),
            ("refinement_failure",))
    elseif artifact isa TypedTimeEventResultV4
        artifact.status in (:integrated, :terminated_event) &&
            return (pass, :evaluated_screen, nothing, nothing, ())
        artifact.status in (:deferred_initial_event_band, :deferred_multi_event) &&
            return (terminal_deferred_stage, artifact.status, artifact.failure_code,
                artifact.failure_reason, (String(artifact.status),))
        return (numerical_fail, :numerical_failure, artifact.failure_code,
            artifact.failure_reason, ("event_numerical_failure",))
    end
    (unknown, :unknown, :backend_exception, "typed-time backend exception",
     ("backend_exception",))
end

function _texec_evidence(plan, artifact, trajectory, stage_outcome;
                         provider=plan.provider, reason=nothing)
    artifact_hash = artifact === nothing ? nothing : _texec_artifact_hash(artifact)
    refs = Tuple(x for x in (artifact_hash,
        trajectory === nothing ? nothing : canonical_hash(trajectory)) if x !== nothing)
    if provider === nothing
        sv = StatusVectorV4(required, no_match, terminal_deferred,
            high_fidelity_pending, terminal_deferred_stage)
        return RuntimeEvidenceV4(plan.subject.physical_subject_hash,
            plan.scenario.scenario_hash, plan.input.solver_input_hash, nothing,
            (execution_plan_hash=plan.plan_hash, operation=plan.operation,
             reason=reason === nothing ? "missing_provider" : String(reason)), sv, ();
            claim_ceiling=none)
    end
    resolution = stage_outcome == terminal_deferred_stage ? terminal_deferred : resolved
    sv = StatusVectorV4(required, unique_match, resolution,
        low_fidelity_evaluated, stage_outcome)
    RuntimeEvidenceV4(plan.subject.physical_subject_hash,
        plan.scenario.scenario_hash, plan.input.solver_input_hash,
        provider.manifest_hash,
        (execution_plan_hash=plan.plan_hash, operation=plan.operation,
         physical_subject_hash=plan.subject.physical_subject_hash,
         scenario_hash=plan.scenario.scenario_hash,
         solver_input_hash=plan.input.solver_input_hash,
         provider_manifest_hash=provider.manifest_hash,
         source_hash=plan.source_hash), sv, ();
        claim_ceiling=screen_only, provider_manifest=provider,
        backend_revision=provider.backend_revision,
        numerical_configuration_hash=canonical_hash((operation=plan.operation,
            execution_plan_hash=plan.plan_hash)), artifact_refs=refs)
end

function _texec_build_report(plan, artifact, trajectory, execution_count;
                             provider=plan.provider, forced_reason=nothing)
    stage, numerical_status, failure_code, failure_reason, gaps = artifact === nothing ?
        (provider === nothing ? terminal_deferred_stage : unknown,
         provider === nothing ? :terminal_deferred : :unknown,
         provider === nothing ? :missing_provider : :backend_exception,
         forced_reason, provider === nothing ? ("missing_provider",) : ("backend_exception",)) :
        _texec_status(artifact)
    evidence = _texec_evidence(plan, artifact, trajectory, stage;
        provider=provider, reason=failure_reason)
    artifact_hash = artifact === nothing ? nothing : _texec_artifact_hash(artifact)
    trajectory_hash = trajectory === nothing ? nothing : canonical_hash(trajectory)
    invocation_hash = canonical_hash((revision=_TEXEC_REVISION,
        solver_input=plan.input.solver_input_hash, provider=provider === nothing ? nothing : provider.manifest_hash,
        execution_plan=plan.plan_hash, artifact=artifact_hash))
    rid = (revision=_TEXEC_REVISION, invocation=invocation_hash,
        solver_input=plan.input.solver_input_hash,
        provider=provider === nothing ? nothing : provider.manifest_hash,
        execution_plan=plan.plan_hash,
        physical_subject=plan.subject.physical_subject_hash,
        scenario=plan.scenario.scenario_hash, operation=plan.operation,
        status=numerical_status, failure_code=failure_code,
        failure_reason=failure_reason, artifact=artifact_hash,
        trajectory=trajectory_hash, evidence=evidence.evidence_id,
        execution_count=execution_count)
    receipt = TypedTimeExecutionReceiptV4(_TEXEC_TOKEN, invocation_hash,
        plan.input.solver_input_hash, provider === nothing ? nothing : provider.manifest_hash,
        plan.plan_hash, plan.subject.physical_subject_hash,
        plan.scenario.scenario_hash, plan.operation, numerical_status,
        failure_code, failure_reason, artifact_hash, trajectory_hash,
        evidence.evidence_id, execution_count, canonical_hash(rid))
    fields = (artifact, trajectory, evidence, receipt, numerical_status, gaps,
        "g1_lumped_time", ("g2_field_geometry", "g3_realization_control"),
        screen_only, 0, false, false)
    draft = TypedTimeResidualReportV4(_TEXEC_TOKEN, fields..., digest256_text("draft"))
    TypedTimeResidualReportV4(_TEXEC_TOKEN, fields...,
        canonical_hash(_texec_report_identity(draft)))
end

function _texec_check_evidence(plan, report)
    e = report.evidence
    e.physical_subject_hash == plan.subject.physical_subject_hash &&
        e.scenario_hash == plan.scenario.scenario_hash &&
        e.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("typed-time evidence subject/input mismatch"))
    e.evidence_id == report.receipt.evidence_id ||
        throw(ArgumentError("typed-time evidence/receipt mismatch"))
    provider = report.receipt.provider_manifest_hash === nothing ? nothing : plan.provider
    stage = report.artifact === nothing ?
        (provider === nothing ? terminal_deferred_stage : unknown) :
        _texec_status(report.artifact)[1]
    expected = _texec_evidence(plan, report.artifact, report.trajectory, stage;
        provider=provider, reason=report.receipt.failure_reason)
    canonical_hash(expected) == canonical_hash(e) && expected.evidence_id == e.evidence_id ||
        throw(ArgumentError("typed-time evidence was not derived from this invocation"))
    true
end

function _texec_validate_artifact(plan, result::TypedTimeResidualResultV4)
    plan.operation === :continuous || throw(ArgumentError("continuous artifact on wrong operation"))
    result.trajectory_hash == canonical_hash((times=result.times, states=result.states)) ||
        throw(ArgumentError("continuous trajectory identity mismatch"))
    expected = canonical_hash((revision=_TTR_REVISION,
        candidate_prefix=plan.residual_plan.compiled_prefix_hash,
        form_hash=plan.residual_plan.form.form_hash,
        scenario_hash=plan.scenario.scenario_hash,
        protocol_hash=plan.residual_plan.protocol.protocol_hash,
        status=result.status, trajectory_hash=result.trajectory_hash,
        rhs_evaluations=result.rhs_evaluations,
        mass_solve_residual_norm=result.mass_solve_residual_norm,
        trajectory_defect_norm=result.trajectory_defect_norm,
        residual_norm=result.residual_norm, failure_reason=result.failure_reason))
    expected == result.result_hash || throw(ArgumentError("continuous result tampered"))
    true
end
function _texec_validate_artifact(plan, result::TimeRefinementReceiptV4)
    plan.operation === :three_level_refinement || throw(ArgumentError("refinement artifact on wrong operation"))
    canonical_hash(result)
    result.prefix_hash == plan.compiled.prefix_hash &&
        result.form_hash == plan.residual_plan.form.form_hash &&
        result.scenario_hash == plan.scenario.scenario_hash &&
        result.protocol_hash == plan.refinement_protocol.protocol_hash ||
        throw(ArgumentError("refinement artifact authority mismatch"))
    true
end
function _texec_validate_artifact(plan, result::TypedTimeEventResultV4)
    plan.operation === :single_threshold_event || throw(ArgumentError("event artifact on wrong operation"))
    canonical_hash(result)
    result.plan_hash == plan.event_plan.plan_hash &&
        result.scenario_hash == plan.scenario.scenario_hash ||
        throw(ArgumentError("event artifact authority mismatch"))
    true
end

function validate_typed_time_report(plan::TypedTimeExecutionPlanV4,
                                    report::TypedTimeResidualReportV4)
    canonical_hash(plan); canonical_hash(report); _texec_check_evidence(plan, report)
    r = report.receipt
    r.solver_input_hash == plan.input.solver_input_hash &&
        r.execution_plan_hash == plan.plan_hash &&
        r.physical_subject_hash == plan.subject.physical_subject_hash &&
        r.scenario_hash == plan.scenario.scenario_hash &&
        r.operation == plan.operation || throw(ArgumentError("typed-time receipt authority mismatch"))
    expected_count = r.provider_manifest_hash === nothing ? 0 : 1
    r.execution_count == expected_count ||
        throw(ArgumentError("typed-time execute-once count tampered"))
    expected_artifact = report.artifact === nothing ? nothing : _texec_artifact_hash(report.artifact)
    expected_trajectory = report.trajectory === nothing ? nothing : canonical_hash(report.trajectory)
    r.artifact_hash == expected_artifact && r.trajectory_hash == expected_trajectory ||
        throw(ArgumentError("typed-time artifact ownership mismatch"))
    report.artifact === nothing || _texec_validate_artifact(plan, report.artifact)
    if plan.operation === :three_level_refinement
        report.trajectory === nothing ||
            throw(ArgumentError("refinement must not fabricate a trajectory"))
    elseif report.artifact !== nothing
        expected_trajectory = _texec_trajectory(plan, report.artifact)
        report.trajectory !== nothing &&
            canonical_hash(expected_trajectory) == canonical_hash(report.trajectory) ||
            throw(ArgumentError("typed-time trajectory was not derived from artifact"))
    end
    provider = r.provider_manifest_hash === nothing ? nothing : plan.provider
    rebuilt = _texec_build_report(plan, report.artifact, report.trajectory,
        r.execution_count; provider=provider, forced_reason=r.failure_reason)
    rebuilt.receipt.receipt_hash == r.receipt_hash &&
        rebuilt.evidence.evidence_id == report.evidence.evidence_id &&
        rebuilt.report_hash == report.report_hash ||
        throw(ArgumentError("typed-time report was not derived from this invocation"))
    true
end

function _texec_run(plan)
    if plan.operation === :continuous
        result = integrate_typed_time_residual(plan.residual_plan, plan.scenario)
        return result, _texec_trajectory(plan, result)
    elseif plan.operation === :three_level_refinement
        result = run_typed_time_refinement(plan.residual_plan, plan.scenario,
            plan.refinement_protocol)
        return result, nothing
    end
    result = integrate_typed_time_events(plan.event_plan, plan.scenario)
    result, _texec_trajectory(plan, result)
end

function execute_once!(store::TypedTimeExecutionStoreV4, input::SolverInputV4,
                       provider::ProviderManifestV4, plan::TypedTimeExecutionPlanV4)
    canonical_hash(plan)
    input.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("execution input authority mismatch"))
    provider.manifest_hash == plan.provider.manifest_hash &&
        provider.code_hash == plan.source_hash && provider.executor === nothing ||
        throw(ArgumentError("execution provider authority mismatch"))
    if haskey(store.reports, input.solver_input_hash)
        report = store.reports[input.solver_input_hash]
        validate_typed_time_report(plan, report)
        get(store.execution_counts, input.solver_input_hash, 0) == 1 ||
            throw(ArgumentError("cached execution count is incomplete"))
        ah = report.receipt.artifact_hash
        ah === nothing || (haskey(store.artifacts, (input.solver_input_hash, ah)) &&
            store.artifacts[(input.solver_input_hash, ah)] === report.artifact) ||
            throw(ArgumentError("cached artifact ownership mismatch"))
        return report
    end
    get(store.execution_counts, input.solver_input_hash, 0) == 0 ||
        throw(ArgumentError("partial typed-time execution state: count without report"))
    any(k -> k[1] == input.solver_input_hash, keys(store.artifacts)) &&
        throw(ArgumentError("partial typed-time execution state: artifact without report"))
    count = get(store.execution_counts, input.solver_input_hash, 0) + 1
    artifact = nothing; trajectory = nothing; reason = nothing
    try
        artifact, trajectory = _texec_run(plan)
    catch err
        err isa InterruptException && rethrow()
        reason = sprint(showerror, err)
    end
    report = _texec_build_report(plan, artifact, trajectory, count;
        forced_reason=reason)
    validate_typed_time_report(plan, report)
    ah = report.receipt.artifact_hash
    if ah !== nothing
        key = (input.solver_input_hash, ah)
        haskey(store.artifacts, key) && store.artifacts[key] !== artifact &&
            throw(ArgumentError("artifact ownership collision"))
        store.artifacts[key] = artifact
    end
    store.reports[input.solver_input_hash] = report
    store.execution_counts[input.solver_input_hash] = count
    report
end

function execute_once!(store::TypedTimeExecutionStoreV4, input::SolverInputV4,
                       ::Nothing, plan::TypedTimeExecutionPlanV4)
    canonical_hash(plan)
    input.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("execution input authority mismatch"))
    _texec_build_report(plan, nothing, nothing, 0; provider=nothing,
        forced_reason="provider unavailable")
end

function cache_typed_time_execution(store::TypedTimeExecutionStoreV4,
                                    plan::TypedTimeExecutionPlanV4)
    canonical_hash(plan)
    haskey(store.reports, plan.input.solver_input_hash) ||
        throw(KeyError(plan.input.solver_input_hash))
    report = store.reports[plan.input.solver_input_hash]
    validate_typed_time_report(plan, report)
    get(store.execution_counts, plan.input.solver_input_hash, 0) == 1 ||
        throw(ArgumentError("cached execution count is incomplete"))
    ah = report.receipt.artifact_hash
    ah === nothing || (haskey(store.artifacts, (plan.input.solver_input_hash, ah)) &&
        store.artifacts[(plan.input.solver_input_hash, ah)] === report.artifact) ||
        throw(ArgumentError("foreign cached artifact"))
    report
end

function replay_typed_time_execution(plan::TypedTimeExecutionPlanV4,
                                     report::TypedTimeResidualReportV4)
    canonical_hash(plan); validate_typed_time_report(plan, report)
    report.artifact === nothing && return report.numerical_status in (:terminal_deferred, :unknown)
    fresh, trajectory = if plan.operation === :single_threshold_event
        replay_typed_time_events(plan.event_plan, plan.scenario, report.artifact)
        report.artifact, _texec_trajectory(plan, report.artifact)
    else
        _texec_run(plan)
    end
    _texec_artifact_hash(fresh) == _texec_artifact_hash(report.artifact) ||
        throw(ArgumentError("typed-time replay artifact mismatch"))
    (trajectory === nothing) == (report.trajectory === nothing) ||
        throw(ArgumentError("typed-time replay trajectory shape mismatch"))
    trajectory === nothing || canonical_hash(trajectory) == canonical_hash(report.trajectory) ||
        throw(ArgumentError("typed-time replay trajectory mismatch"))
    rebuilt = _texec_build_report(plan, fresh, trajectory,
        report.receipt.execution_count)
    canonical_hash(rebuilt) == canonical_hash(report) ||
        throw(ArgumentError("typed-time replay report mismatch"))
    true
end

typed_time_execution_manifest() = (schema=_TEXEC_SCHEMA,
    revision=_TEXEC_REVISION, kind=_TEXEC_KIND, operations=_TEXEC_OPERATIONS,
    claim_ceiling=screen_only, credible_physical_candidate_count=0,
    p5_ready=false, unsupported_emitted=false)
