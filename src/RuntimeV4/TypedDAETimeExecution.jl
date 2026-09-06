# D2.2 candidate-bound backward-Euler execution for the frozen D2.1 subset.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: canonical_hash

struct _TDAETNumericalFailure <: Exception
    code::Symbol
    message::String
end

_tdaet_fail(code, message) = throw(_TDAETNumericalFailure(code, String(message)))

function _tdaet_source_hash()
    parts = Tuple(begin
        path = joinpath(@__DIR__, file)
        isfile(path) || throw(ArgumentError("missing D2.2 source file $(file)"))
        (file=file, content=read(path, String))
    end for file in _TDAET_SOURCE_FILES)
    canonical_hash((revision=_TDAET_REVISION, sources=parts))
end

function _tdaet_initialization_identity(initialization_plan,
                                         initialization_report)
    validate_typed_dae_initialization_report(initialization_plan,
        initialization_report)
    initialization_report.numerical_status === :pass &&
        initialization_report.artifact !== nothing &&
        initialization_report.artifact.status === :pass ||
        throw(ArgumentError("D2.2 requires a passing D2.1 initialization"))
    (plan_hash=initialization_plan.plan_hash,
     report_hash=canonical_hash(initialization_report),
     artifact_hash=canonical_hash(initialization_report.artifact))
end

function _tdaet_initial_values(initialization_plan, initialization_report,
                               authority)
    values = initialization_report.artifact.final_values
    all(value -> value isa StateValueV4, values) ||
        throw(ArgumentError("D2.2 initialization values must remain typed"))
    Tuple(value.state_ref for value in values) ==
        Tuple(state.state_ref for state in authority.states) ||
        throw(ArgumentError("D2.2 initialization state order mismatch"))
    for (value, state) in zip(values, authority.states)
        value.unit == state.physical_type.units ||
            throw(ArgumentError("D2.2 initialization unit mismatch"))
        lower = Float64(state.physical_bounds.interval.lower)
        upper = Float64(state.physical_bounds.interval.upper)
        lower <= value.value <= upper ||
            throw(ArgumentError("D2.2 initialization outside state bounds"))
    end
    Tuple(values)
end

function _tdaet_authority_binding(initialization_plan, initialization_report,
                                   authority, protocol, source_hash)
    candidate = initialization_plan.compiled.candidate
    identity = _tdaet_initialization_identity(initialization_plan,
        initialization_report)
    (revision=_TDAET_REVISION,
     compiled_prefix_hash=initialization_plan.compiled.prefix_hash,
     mechanism_hash=mechanism_hash(candidate.mechanism_genome_ref),
     field_geometry_hash=field_geometry_hash(candidate.field_geometry_genome_ref),
     realization_control_hash=realization_control_hash(
         candidate.realization_control_genome_ref),
     genome_bundle_hash=candidate.canonical_hashes.genome_bundle_hash,
     mission_hash=initialization_plan.compiled.minimality_scope.mission_hash,
     bounds_hash=initialization_plan.compiled.minimality_scope.bounds_hash,
     minimality_scope=initialization_plan.compiled.minimality_scope,
     row_authority=authority.row_authority,
     initialization_plan_hash=identity.plan_hash,
     initialization_report_hash=identity.report_hash,
     initialization_artifact_hash=identity.artifact_hash,
     initialization_scenario_hash=initialization_plan.scenario.scenario_hash,
     initialization_protocol_hash=canonical_hash(initialization_plan.protocol),
     time_protocol_hash=canonical_hash(protocol), source_hash=source_hash,
     temporal_partition=:differential_rhs_and_algebraic_constraints_only)
end

function _tdaet_capability(initialization_plan, authority, binding, protocol)
    schema_hash = canonical_hash((schema=_TDAET_SCHEMA,
        revision=_TDAET_REVISION, authority=binding,
        protocol=canonical_hash(protocol)))
    CapabilitySignatureV4(_TDAET_SCHEMA, _TDAET_REVISION, _TDAET_KIND,
        _TDAET_OPERATOR,
        Tuple(state.state_ref.value for state in
            (authority.differential_states..., authority.algebraic_states...)),
        "consistent_mixed_state_0d", "short_mixed_trajectory_0d", 0, (),
        "no_spatial_boundary_in_d2_2", "no_spatial_interface_in_d2_2",
        "fixed_step_backward_euler",
        ("typed_time_points", "scaled_differential_residual",
         "scaled_algebraic_residual", "scaled_local_jacobian_audit"),
        screen_only, initialization_plan.compiled.minimality_scope.bounds_hash;
        input_schema_hash=schema_hash, coordinate_system="lumped_0d")
end

function _tdaet_subject(initialization_plan, initialization_report, authority,
                        binding, capability, protocol, initial_values)
    compiled = initialization_plan.compiled
    payload = (authority=binding,
        initial_values=initial_values,
        time=(method=protocol.method, t_start=protocol.t_start,
            t_stop=protocol.t_stop, step=protocol.step,
            step_count=protocol.step_count, time_scale=protocol.time_scale,
            time_unit=protocol.time_unit),
        executed_scope="g1_lumped_index1_dae_time_screen",
        unexecuted_scopes=("cross_temporal_coupling", "events",
            "adaptive_refinement", "g2_field_geometry",
            "g3_realization_control", "whole_device_vvuq"))
    ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        compiled.candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash,
        (("typed_dae_time_authority", binding),),
        ((name=initialization_plan.scenario.name,
          initial_values=initial_values,
          scenario_hash=initialization_plan.scenario.scenario_hash,
          t_start=protocol.t_start, t_stop=protocol.t_stop,
          step=protocol.step, time_unit=protocol.time_unit),),
        payload, (capability,))
end

function _tdaet_provider(capability, source_hash)
    ProviderManifestV4(_TDAET_SCHEMA, _TDAET_REVISION, _TDAET_KIND,
        capability,
        (bounds_hash=capability.applicability_bounds,
         operation=:backward_euler_index1_dae,
         executed_scope="g1_lumped_index1_dae_time_screen"),
        _TDAET_BACKEND, _TDAET_REVISION, source_hash, _TDAET_GROUP,
        screen_only; input_schema_hash=capability.input_schema_hash,
        executor=nothing)
end

function _tdaet_components(initialization_plan, initialization_report,
                            protocol)
    canonical_hash(protocol)
    _tdaet_initialization_identity(initialization_plan, initialization_report)
    authority = _tdae_check_plan(initialization_plan)
    initial_values = _tdaet_initial_values(initialization_plan,
        initialization_report, authority)
    source_hash = _tdaet_source_hash()
    binding = _tdaet_authority_binding(initialization_plan,
        initialization_report, authority, protocol, source_hash)
    capability = _tdaet_capability(initialization_plan, authority, binding,
        protocol)
    subject = _tdaet_subject(initialization_plan, initialization_report,
        authority, binding, capability, protocol, initial_values)
    provider = _tdaet_provider(capability, source_hash)
    authority_hash = canonical_hash((revision=_TDAET_REVISION,
        binding=binding, capability=canonical_hash(capability),
        subject=subject.physical_subject_hash, provider=provider.manifest_hash))
    payload = (revision=_TDAET_REVISION, authority_hash=authority_hash,
        physical_subject_hash=subject.physical_subject_hash,
        initialization_plan_hash=initialization_plan.plan_hash,
        initialization_report_hash=canonical_hash(initialization_report),
        initialization_artifact_hash=canonical_hash(initialization_report.artifact),
        scenario_hash=initialization_plan.scenario.scenario_hash,
        initial_values=initial_values, protocol_hash=canonical_hash(protocol),
        provider_manifest_hash=provider.manifest_hash, source_hash=source_hash,
        row_authority=authority.row_authority)
    input = SolverInputV4(subject.physical_subject_hash,
        initialization_plan.scenario.scenario_hash, provider.manifest_hash,
        capability.input_schema_hash, payload)
    plan_hash = canonical_hash((revision=_TDAET_REVISION,
        authority=authority_hash, solver_input=input.solver_input_hash))
    (authority=authority, capability=capability, subject=subject, input=input,
     provider=provider, source_hash=source_hash,
     authority_hash=authority_hash, plan_hash=plan_hash)
end

function compile_typed_dae_time_execution_plan(
        initialization_plan::TypedDAEInitializationPlanV4,
        initialization_report::TypedDAEInitializationReportV4;
        protocol=TypedDAETimeProtocolV4())
    parts = _tdaet_components(initialization_plan, initialization_report,
        protocol)
    plan = TypedDAETimePlanV4(_TDAET_TOKEN, initialization_plan,
        initialization_report, protocol, parts.capability, parts.subject,
        parts.input, parts.provider, parts.source_hash, parts.authority_hash,
        parts.plan_hash)
    canonical_hash(plan)
    plan
end

function _tdaet_check_plan(plan::TypedDAETimePlanV4)
    parts = _tdaet_components(plan.initialization_plan,
        plan.initialization_report, plan.protocol)
    canonical_hash(plan.capability) == canonical_hash(parts.capability) &&
        plan.subject.physical_subject_hash == parts.subject.physical_subject_hash &&
        plan.input.solver_input_hash == parts.input.solver_input_hash &&
        plan.provider.manifest_hash == parts.provider.manifest_hash &&
        plan.provider.executor === nothing &&
        plan.source_hash == parts.source_hash &&
        plan.authority_hash == parts.authority_hash &&
        plan.plan_hash == parts.plan_hash ||
        throw(ArgumentError("D2.2 plan authority mismatch"))
    parts.authority
end

canonical_hash(plan::TypedDAETimePlanV4) =
    (_tdaet_check_plan(plan); plan.plan_hash)

function _tdaet_bounds(authority)
    Dict(state.state_ref.value =>
        (Float64(state.physical_bounds.interval.lower),
         Float64(state.physical_bounds.interval.upper))
        for state in authority.states)
end

function _tdaet_value_dict(states)
    Dict(value.state_ref.value => value.value for value in states)
end

function _tdaet_typed_states(authority, values)
    Tuple(StateValueV4(state.state_ref, values[state.state_ref.value],
        state.physical_type.units) for state in authority.states)
end

function _tdaet_joint_refs(plan)
    (plan.initialization_plan.differential_refs...,
     plan.initialization_plan.algebraic_refs...)
end

function _tdaet_joint_scales(plan, authority)
    differential_state = collect(authority.differential_state_scales)
    differential_rows = differential_state ./ plan.protocol.time_scale
    algebraic_rows = collect(authority.algebraic_row_scales)
    algebraic_columns = collect(authority.algebraic_column_scales)
    (row=vcat(differential_rows, algebraic_rows),
     column=vcat(differential_state, algebraic_columns),
     differential_rows=differential_rows,
     algebraic_rows=algebraic_rows,
     algebraic_columns=algebraic_columns)
end

function _tdaet_raw_step_residual(plan, authority, previous_values,
                                   algebraic_residual, refs, candidate)
    values = copy(previous_values)
    for (ref, value) in zip(refs, candidate)
        values[ref.value] = Float64(value)
    end
    h = plan.protocol.step
    derivative = [(values[ref.value] - previous_values[ref.value]) / h
        for ref in plan.initialization_plan.differential_refs]
    rhs = _tdae_eval(authority.rhs_edge.program, authority.rhs_ports,
        values, authority.differential_row.rhs_root_position)
    differential = authority.mass * derivative .- [rhs]
    z = [values[ref.value]
        for ref in plan.initialization_plan.algebraic_refs]
    vcat(differential, algebraic_residual(z))
end

function _tdaet_condition(matrix, protocol, singular_code,
                           ill_conditioned_code, label)
    try
        _tdae_matrix_condition(matrix, protocol, singular_code,
            ill_conditioned_code, label)
    catch err
        if err isa _TDAENumericalFailure
            _tdaet_fail(err.code, err.message)
        end
        rethrow()
    end
end

function _tdaet_jacobian(residual, values, plan, bounds, refs, scales)
    try
        _tdae_jacobian(residual, values,
            plan.protocol.finite_difference_step, bounds, refs,
            scales.row, scales.column)
    catch err
        if err isa _TDAENumericalFailure
            _tdaet_fail(err.code, err.message)
        end
        rethrow()
    end
end

function _tdaet_make_point(plan, authority, time, values,
                            differential_residual, algebraic_residual,
                            joint_condition, jzz_condition)
    all(isfinite, Base.values(values)) || _tdaet_fail(:nonfinite_state,
        "D2.2 accepted state is nonfinite")
    states = _tdaet_typed_states(authority, values)
    fields = (Float64(time), plan.protocol.time_unit, states,
        Tuple(Float64.(differential_residual)),
        Tuple(Float64.(algebraic_residual)),
        joint_condition === nothing ? nothing : Float64(joint_condition),
        Float64(jzz_condition))
    draft = TypedDAETimePointV4(_TDAET_TOKEN, fields...,
        digest256_text("draft"))
    TypedDAETimePointV4(_TDAET_TOKEN, fields...,
        canonical_hash(_tdaet_point_identity(draft)))
end

function _tdaet_initial_point(plan, authority, values, bounds, scales,
                              algebraic_residual)
    z = [values[ref.value]
        for ref in plan.initialization_plan.algebraic_refs]
    algebraic_raw = algebraic_residual(z)
    algebraic_scaled = algebraic_raw ./ scales.algebraic_rows
    norm(algebraic_scaled, Inf) <= plan.protocol.residual_abs_tol +
        plan.protocol.residual_rel_tol ||
        _tdaet_fail(:inconsistent_initial_algebraic_residual,
            "D2.1 initial artifact fails D2.2 algebraic tolerance")
    jacobian = try
        _tdae_jacobian(algebraic_residual, z,
            plan.protocol.finite_difference_step, bounds,
            plan.initialization_plan.algebraic_refs,
            scales.algebraic_rows, scales.algebraic_columns)
    catch err
        err isa _TDAENumericalFailure &&
            _tdaet_fail(err.code, err.message)
        rethrow()
    end
    condition = _tdaet_condition(jacobian.normalized, plan.protocol,
        :singular_algebraic_jacobian, :ill_conditioned_algebraic_jacobian,
        "D2.2 initial scaled Jzz")
    derivative = collect(plan.initialization_report.artifact.initial_derivative)
    rhs = _tdae_eval(authority.rhs_edge.program, authority.rhs_ports,
        values, authority.differential_row.rhs_root_position)
    differential_scaled = (authority.mass * derivative .- [rhs]) ./
        scales.differential_rows
    norm(differential_scaled, Inf) <= plan.protocol.residual_abs_tol +
        plan.protocol.residual_rel_tol ||
        _tdaet_fail(:inconsistent_initial_mass_residual,
            "D2.1 initial artifact fails D2.2 mass tolerance")
    _tdaet_make_point(plan, authority, plan.protocol.t_start, values,
        differential_scaled, algebraic_scaled, nothing, condition)
end

function _tdaet_step(plan, authority, previous_values, bounds, scales,
                      algebraic_residual, step_index)
    refs = _tdaet_joint_refs(plan)
    candidate = [previous_values[ref.value] for ref in refs]
    raw_residual = u -> _tdaet_raw_step_residual(plan, authority,
        previous_values, algebraic_residual, refs, u)
    converged = false
    for _ in 1:plan.protocol.max_iterations
        scaled_residual = raw_residual(candidate) ./ scales.row
        tolerance = plan.protocol.residual_abs_tol +
            plan.protocol.residual_rel_tol *
                max(1.0, norm(candidate ./ scales.column, Inf))
        if norm(scaled_residual, Inf) <= tolerance
            converged = true
            break
        end
        jacobian = _tdaet_jacobian(raw_residual, candidate, plan, bounds,
            refs, scales)
        _tdaet_condition(jacobian.normalized, plan.protocol,
            :singular_step_jacobian, :ill_conditioned_step_jacobian,
            "D2.2 scaled backward-Euler Jacobian")
        correction_scaled = jacobian.normalized \ scaled_residual
        all(isfinite, correction_scaled) ||
            _tdaet_fail(:nonfinite_newton_step, "nonfinite D2.2 Newton step")
        norm(correction_scaled, Inf) > plan.protocol.correction_abs_tol ||
            _tdaet_fail(:newton_stagnation,
                "D2.2 Newton correction stagnated before convergence")
        correction = scales.column .* correction_scaled
        old_norm = norm(scaled_residual, Inf)
        accepted = false
        damping = 1.0
        for _ in 0:plan.protocol.max_backtracks
            trial = candidate .- damping .* correction
            in_bounds = all(begin
                lower, upper = bounds[ref.value]
                lower <= value <= upper
            end for (ref, value) in zip(refs, trial))
            trial_scaled = in_bounds && all(isfinite, trial) ?
                raw_residual(trial) ./ scales.row : fill(Inf, length(trial))
            if norm(trial_scaled, Inf) < old_norm
                candidate = trial
                accepted = true
                if norm(trial_scaled, Inf) <= tolerance
                    converged = true
                end
                break
            end
            damping /= 2
        end
        accepted || _tdaet_fail(:newton_line_search_failed,
            "D2.2 bounded Newton line search failed")
        converged && break
    end
    converged || _tdaet_fail(:newton_nonconvergence,
        "D2.2 backward-Euler step did not converge")

    values = copy(previous_values)
    for (ref, value) in zip(refs, candidate)
        values[ref.value] = Float64(value)
    end
    final_raw = raw_residual(candidate)
    differential_scaled = final_raw[1:length(scales.differential_rows)] ./
        scales.differential_rows
    algebraic_scaled = final_raw[(length(scales.differential_rows) + 1):end] ./
        scales.algebraic_rows
    tolerance = plan.protocol.residual_abs_tol +
        plan.protocol.residual_rel_tol *
            max(1.0, norm(candidate ./ scales.column, Inf))
    norm(differential_scaled, Inf) <= tolerance ||
        _tdaet_fail(:differential_residual_exceeded,
            "D2.2 differential residual exceeds tolerance")
    norm(algebraic_scaled, Inf) <= tolerance ||
        _tdaet_fail(:algebraic_residual_exceeded,
            "D2.2 algebraic residual exceeds tolerance")

    final_joint = _tdaet_jacobian(raw_residual, candidate, plan, bounds,
        refs, scales)
    joint_condition = _tdaet_condition(final_joint.normalized, plan.protocol,
        :singular_step_jacobian, :ill_conditioned_step_jacobian,
        "D2.2 accepted-step scaled joint Jacobian")

    z = [values[ref.value]
        for ref in plan.initialization_plan.algebraic_refs]
    jzz = try
        _tdae_jacobian(algebraic_residual, z,
            plan.protocol.finite_difference_step, bounds,
            plan.initialization_plan.algebraic_refs,
            scales.algebraic_rows, scales.algebraic_columns)
    catch err
        err isa _TDAENumericalFailure && _tdaet_fail(err.code, err.message)
        rethrow()
    end
    condition = _tdaet_condition(jzz.normalized, plan.protocol,
        :singular_algebraic_jacobian, :ill_conditioned_algebraic_jacobian,
        "D2.2 accepted-step scaled Jzz")
    time = plan.protocol.t_start + step_index * plan.protocol.step
    _tdaet_make_point(plan, authority, time, values,
        differential_scaled, algebraic_scaled, joint_condition, condition)
end

function _tdaet_result(status, code, reason, trajectory, attempted_step)
    points = Tuple(trajectory)
    accepted_steps = max(0, length(points) - 1)
    max_diff = isempty(points) ? nothing : maximum(
        maximum(abs, point.scaled_differential_residual) for point in points)
    max_alg = isempty(points) ? nothing : maximum(
        maximum(abs, point.scaled_algebraic_residual) for point in points)
    joint_conditions = Tuple(point.scaled_joint_condition for point in points
        if point.scaled_joint_condition !== nothing)
    max_joint = isempty(joint_conditions) ? nothing : maximum(joint_conditions)
    fields = (status, code, reason === nothing ? nothing : String(reason),
        points, accepted_steps, Int(attempted_step),
        max_diff === nothing ? nothing : Float64(max_diff),
        max_alg === nothing ? nothing : Float64(max_alg),
        max_joint === nothing ? nothing : Float64(max_joint))
    draft = TypedDAETimeResultV4(_TDAET_TOKEN, fields...,
        digest256_text("draft"))
    TypedDAETimeResultV4(_TDAET_TOKEN, fields...,
        canonical_hash(_tdaet_result_identity(draft)))
end

function _tdaet_failure(err)
    err isa _TDAETNumericalFailure &&
        return (:numerical_fail, err.code, err.message)
    err isa _TDAENumericalFailure &&
        return (:numerical_fail, err.code, err.message)
    (:unknown, :backend_exception, sprint(showerror, err))
end

function _tdaet_execute_artifact(plan::TypedDAETimePlanV4)
    authority = _tdaet_check_plan(plan)
    initial_states = plan.initialization_report.artifact.final_values
    values = _tdaet_value_dict(initial_states)
    bounds = _tdaet_bounds(authority)
    scales = _tdaet_joint_scales(plan, authority)
    algebraic_residual = _tdae_residual_function(plan.initialization_plan,
        authority, values)
    trajectory = TypedDAETimePointV4[]
    try
        push!(trajectory, _tdaet_initial_point(plan, authority, values, bounds,
            scales, algebraic_residual))
        for step_index in 1:plan.protocol.step_count
            point = _tdaet_step(plan, authority, values, bounds, scales,
                algebraic_residual, step_index)
            push!(trajectory, point)
            values = _tdaet_value_dict(point.states)
        end
        _tdaet_result(:pass, nothing, nothing, trajectory,
            plan.protocol.step_count)
    catch err
        err isa InterruptException && rethrow()
        status, code, reason = _tdaet_failure(err)
        attempted = isempty(trajectory) ? 0 :
            min(plan.protocol.step_count, length(trajectory))
        _tdaet_result(status, code, reason, trajectory, attempted)
    end
end

function _tdaet_status(artifact)
    artifact.status === :pass && return (pass, :pass, nothing, nothing, ())
    artifact.status === :numerical_fail && return (
        numerical_fail, :numerical_fail, artifact.failure_code,
        artifact.failure_reason, ("local_dae_time_numerical_failure",))
    (unknown, :unknown, artifact.failure_code, artifact.failure_reason,
     ("dae_time_backend_exception",))
end

function _tdaet_evidence(plan, artifact, stage_outcome; provider=plan.provider,
                          reason=nothing)
    artifact_hash = artifact === nothing ? nothing : canonical_hash(artifact)
    if provider === nothing
        status = StatusVectorV4(required, no_match, terminal_deferred,
            high_fidelity_pending, terminal_deferred_stage)
        return RuntimeEvidenceV4(plan.subject.physical_subject_hash,
            plan.initialization_plan.scenario.scenario_hash,
            plan.input.solver_input_hash, nothing,
            (execution_plan_hash=plan.plan_hash,
             operation=:backward_euler_index1_dae,
             reason=reason === nothing ? "provider unavailable" : String(reason)),
            status, (); claim_ceiling=none)
    end
    status = StatusVectorV4(required, unique_match, resolved,
        low_fidelity_evaluated, stage_outcome)
    metrics = artifact === nothing || artifact.status !== :pass ? () : (
        MetricWithUnit(:accepted_dae_time_steps, artifact.accepted_steps),
        MetricWithUnit(:max_scaled_differential_residual,
            artifact.max_scaled_differential_residual),
        MetricWithUnit(:max_scaled_algebraic_residual,
            artifact.max_scaled_algebraic_residual),
        MetricWithUnit(:max_scaled_joint_condition,
            artifact.max_scaled_joint_condition),
        MetricWithUnit(:final_time, plan.protocol.t_stop,
            plan.protocol.time_unit))
    RuntimeEvidenceV4(plan.subject.physical_subject_hash,
        plan.initialization_plan.scenario.scenario_hash,
        plan.input.solver_input_hash, provider.manifest_hash,
        (execution_plan_hash=plan.plan_hash,
         operation=:backward_euler_index1_dae,
         initialization_plan_hash=plan.initialization_plan.plan_hash,
         initialization_report_hash=canonical_hash(plan.initialization_report),
         initialization_artifact_hash=canonical_hash(
             plan.initialization_report.artifact),
         physical_subject_hash=plan.subject.physical_subject_hash,
         provider_manifest_hash=provider.manifest_hash,
         source_hash=plan.source_hash), status, metrics;
        claim_ceiling=screen_only, provider_manifest=provider,
        backend_revision=provider.backend_revision,
        numerical_configuration_hash=canonical_hash(plan.protocol),
        artifact_refs=artifact_hash === nothing ? () : (artifact_hash,))
end

function _tdaet_build_report(plan, artifact, execution_count;
                              provider=plan.provider, deferred_reason=nothing)
    stage, numerical_status, failure_code, failure_reason, gaps =
        artifact === nothing ?
        (terminal_deferred_stage, :terminal_deferred, :missing_provider,
         deferred_reason === nothing ? "provider unavailable" :
             String(deferred_reason), ("missing_provider",)) :
        _tdaet_status(artifact)
    evidence = _tdaet_evidence(plan, artifact, stage; provider=provider,
        reason=failure_reason)
    artifact_hash = artifact === nothing ? nothing : canonical_hash(artifact)
    init_report_hash = canonical_hash(plan.initialization_report)
    init_artifact_hash = canonical_hash(plan.initialization_report.artifact)
    invocation_hash = canonical_hash((revision=_TDAET_REVISION,
        solver_input=plan.input.solver_input_hash,
        provider=provider === nothing ? nothing : provider.manifest_hash,
        plan=plan.plan_hash, initialization_plan=plan.initialization_plan.plan_hash,
        initialization_report=init_report_hash,
        initialization_artifact=init_artifact_hash, artifact=artifact_hash))
    receipt_fields = (invocation_hash, plan.input.solver_input_hash,
        provider === nothing ? nothing : provider.manifest_hash,
        plan.plan_hash, plan.initialization_plan.plan_hash, init_report_hash,
        init_artifact_hash, numerical_status, failure_code, failure_reason,
        artifact_hash, evidence.evidence_id, Int(execution_count))
    receipt_draft = TypedDAETimeReceiptV4(_TDAET_TOKEN,
        receipt_fields..., digest256_text("draft"))
    receipt = TypedDAETimeReceiptV4(_TDAET_TOKEN, receipt_fields...,
        canonical_hash(_tdaet_receipt_identity(receipt_draft)))
    report_fields = (artifact, evidence, receipt, numerical_status, gaps,
        "g1_lumped_index1_dae_time_screen",
        ("cross_temporal_coupling", "events", "adaptive_refinement",
         "g2_field_geometry", "g3_realization_control",
         "whole_device_vvuq"), screen_only, 0, false, false)
    report_draft = TypedDAETimeReportV4(_TDAET_TOKEN,
        report_fields..., digest256_text("draft"))
    TypedDAETimeReportV4(_TDAET_TOKEN, report_fields...,
        canonical_hash(_tdaet_report_identity(report_draft)))
end

function validate_typed_dae_time_report(plan::TypedDAETimePlanV4,
                                        report::TypedDAETimeReportV4)
    canonical_hash(plan)
    canonical_hash(report)
    receipt = report.receipt
    receipt.solver_input_hash == plan.input.solver_input_hash &&
        receipt.plan_hash == plan.plan_hash &&
        receipt.initialization_plan_hash == plan.initialization_plan.plan_hash &&
        receipt.initialization_report_hash == canonical_hash(
            plan.initialization_report) &&
        receipt.initialization_artifact_hash == canonical_hash(
            plan.initialization_report.artifact) ||
        throw(ArgumentError("D2.2 receipt authority mismatch"))
    expected_count = receipt.provider_manifest_hash === nothing ? 0 : 1
    receipt.execution_count == expected_count ||
        throw(ArgumentError("D2.2 execution count tampered"))
    expected_artifact = report.artifact === nothing ? nothing :
        canonical_hash(report.artifact)
    receipt.artifact_hash == expected_artifact ||
        throw(ArgumentError("D2.2 artifact ownership mismatch"))
    if receipt.provider_manifest_hash === nothing
        report.artifact === nothing &&
            report.numerical_status === :terminal_deferred ||
            throw(ArgumentError("D2.2 deferred report shape mismatch"))
        provider = nothing
    else
        receipt.provider_manifest_hash == plan.provider.manifest_hash ||
            throw(ArgumentError("D2.2 receipt provider mismatch"))
        report.artifact !== nothing ||
            throw(ArgumentError("D2.2 provider report lacks artifact"))
        fresh = _tdaet_execute_artifact(plan)
        canonical_hash(fresh) == canonical_hash(report.artifact) ||
            throw(ArgumentError("D2.2 artifact was not derived from plan"))
        report.numerical_status == report.artifact.status ||
            throw(ArgumentError("D2.2 artifact/report status mismatch"))
        provider = plan.provider
    end
    rebuilt = _tdaet_build_report(plan, report.artifact,
        receipt.execution_count; provider=provider)
    canonical_hash(rebuilt) == canonical_hash(report) ||
        throw(ArgumentError("D2.2 report was not derived from invocation"))
    true
end

function _tdaet_validate_store_artifacts(store, key, report)
    artifact_hash = report.receipt.artifact_hash
    artifact_hash === nothing &&
        throw(ArgumentError("D2.2 cached provider report lacks artifact"))
    expected_key = (key, artifact_hash)
    matching = Tuple(k for k in keys(store.artifacts) if k[1] == key)
    length(matching) == 1 && only(matching) == expected_key ||
        throw(ArgumentError("D2.2 cache contains foreign artifact authority"))
    canonical_hash(store.artifacts[expected_key]) ==
        canonical_hash(report.artifact) ||
        throw(ArgumentError("D2.2 cached artifact mismatch"))
    true
end

function execute_once!(store::TypedDAETimeStoreV4, input::SolverInputV4,
                       provider::ProviderManifestV4,
                       plan::TypedDAETimePlanV4)
    canonical_hash(plan)
    input.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("D2.2 execution input authority mismatch"))
    provider.manifest_hash == plan.provider.manifest_hash &&
        provider.code_hash == plan.source_hash && provider.executor === nothing ||
        throw(ArgumentError("D2.2 execution provider authority mismatch"))
    key = input.solver_input_hash
    if haskey(store.reports, key)
        report = store.reports[key]
        validate_typed_dae_time_report(plan, report)
        get(store.execution_counts, key, 0) == 1 ||
            throw(ArgumentError("D2.2 cached execution count incomplete"))
        _tdaet_validate_store_artifacts(store, key, report)
        return report
    end
    get(store.execution_counts, key, 0) == 0 ||
        throw(ArgumentError("partial D2.2 state: count without report"))
    any(k -> k[1] == key, keys(store.artifacts)) &&
        throw(ArgumentError("partial D2.2 state: artifact without report"))
    artifact = _tdaet_execute_artifact(plan)
    report = _tdaet_build_report(plan, artifact, 1)
    validate_typed_dae_time_report(plan, report)
    artifact_hash = canonical_hash(artifact)
    store.artifacts[(key, artifact_hash)] = artifact
    store.reports[key] = report
    store.execution_counts[key] = 1
    report
end

function execute_once!(store::TypedDAETimeStoreV4, input::SolverInputV4,
                       ::Nothing, plan::TypedDAETimePlanV4)
    canonical_hash(plan)
    input.solver_input_hash == plan.input.solver_input_hash ||
        throw(ArgumentError("D2.2 execution input authority mismatch"))
    _tdaet_build_report(plan, nothing, 0; provider=nothing,
        deferred_reason="provider unavailable")
end

function cache_typed_dae_time_execution(store::TypedDAETimeStoreV4,
                                        plan::TypedDAETimePlanV4)
    canonical_hash(plan)
    key = plan.input.solver_input_hash
    haskey(store.reports, key) || throw(KeyError(key))
    report = store.reports[key]
    validate_typed_dae_time_report(plan, report)
    get(store.execution_counts, key, 0) == 1 ||
        throw(ArgumentError("D2.2 cached execution count incomplete"))
    _tdaet_validate_store_artifacts(store, key, report)
    report
end

function replay_typed_dae_time_execution(plan::TypedDAETimePlanV4,
                                         report::TypedDAETimeReportV4)
    validate_typed_dae_time_report(plan, report)
    report.artifact === nothing &&
        return report.numerical_status === :terminal_deferred
    fresh = _tdaet_execute_artifact(plan)
    canonical_hash(fresh) == canonical_hash(report.artifact)
end

typed_dae_time_execution_manifest() = (schema=_TDAET_SCHEMA,
    revision=_TDAET_REVISION, kind=_TDAET_KIND, operation=_TDAET_OPERATOR,
    method=:backward_euler, claim_ceiling=screen_only,
    credible_physical_candidate_count=0, p5_ready=false,
    unsupported_emitted=false,
    excluded=("cross_temporal_coupling", "events", "adaptive_refinement",
        "spatial_execution", "whole_device", "vvuq", "validation"))
