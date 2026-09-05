"""Provider-bound solver input compilation and fail-closed execution."""

function _runtime_scenario_hash(scenario)
    is_canonical_value(scenario) || throw(ArgumentError("scenario must be immutable and canonicalizable"))
    canonical_hash(scenario)
end

function compile_solver_input(subject::ExecutablePhysicalSubjectV4, scenario, provider::ProviderManifestV4)
    matches = [o for o in subject.operator_obligations if match_provider(o, (provider,)).status == unique_match]
    length(matches) == 1 || throw(ArgumentError("provider must match exactly one subject capability obligation; use the obligation overload for multi-obligation subjects"))
    compile_solver_input(subject, scenario, only(matches), provider)
end

function compile_solver_input(subject::ExecutablePhysicalSubjectV4, scenario,
                              obligation::CapabilitySignatureV4, provider::ProviderManifestV4)
    sh = _runtime_scenario_hash(scenario)
    any(_runtime_scenario_hash(s) == sh for s in subject.scenarios) ||
        throw(ArgumentError("scenario is outside the materialized subject scenario scope"))
    any(canonical_hash(o) == canonical_hash(obligation) for o in subject.operator_obligations) ||
        throw(ArgumentError("obligation is not part of the materialized subject"))
    match_provider(obligation, (provider,)).status == unique_match ||
        throw(ArgumentError("provider does not exactly match the selected capability obligation"))
    payload = (physical_subject_hash=subject.physical_subject_hash, scenario=scenario,
        scenario_hash=sh, provider_manifest_hash=provider.manifest_hash,
        provider_backend=provider.backend, backend_revision=provider.backend_revision,
        provider_code_hash=provider.code_hash, input_schema_hash=provider.input_schema_hash,
        materialized_payload=subject.materialized_payload,
        requested_obligation=obligation,
        numerical_configuration=(backend_revision=provider.backend_revision,
                                 input_schema_hash=provider.input_schema_hash))
    is_canonical_value(payload) || throw(ArgumentError("solver input payload must be immutable and canonicalizable"))
    SolverInputV4(subject.physical_subject_hash, sh, provider.manifest_hash,
                  provider.input_schema_hash, payload)
end

function _runtime_cached(store, h::Digest256)
    store isa AbstractDict || throw(ArgumentError("execution store must be an AbstractDict"))
    haskey(store, h) ? store[h] : nothing
end

function _runtime_put!(store, h::Digest256, evidence::RuntimeEvidenceV4)
    store isa AbstractDict || throw(ArgumentError("execution store must be an AbstractDict"))
    store[h] = evidence
    evidence
end

function _runtime_execution_result(result)
    if result isa NamedTuple
        metrics = haskey(result, :metrics) ? result.metrics : ()
        outcome = haskey(result, :stage_outcome) ? result.stage_outcome : unknown
        uncertainty = haskey(result, :uncertainty) ? result.uncertainty : nothing
        artifacts = haskey(result, :artifacts) ? result.artifacts : ()
        return Tuple(metrics), outcome, uncertainty, Tuple(artifacts)
    elseif result isa Tuple
        return Tuple(result), unknown, nothing, ()
    else
        return (), unknown, nothing, ()
    end
end

function _runtime_outcome_symbol(x)
    x isa StageOutcome && return x
    x isa Symbol && x == :pass && return pass
    x isa Symbol && x == :physical_fail && return physical_fail
    x isa Symbol && x == :numerical_fail && return numerical_fail
    x isa Symbol && x == :not_applicable && return not_applicable_stage
    unknown
end

function execute_once!(store, input::SolverInputV4, provider::ProviderManifestV4)
    input.provider_manifest_hash == provider.manifest_hash || throw(ArgumentError("solver input/provider manifest mismatch"))
    cached = _runtime_cached(store, input.solver_input_hash)
    cached === nothing || return cached
    outcome = unknown
    metrics = ()
    uncertainty = nothing
    artifacts = ()
    executor = provider.executor === nothing ? get(_RUNTIME_EXECUTOR_BINDINGS, provider.manifest_hash, nothing) : provider.executor
    if executor === nothing
        outcome = unknown
    else
        try
            raw = executor(input)
            metrics, raw_outcome, uncertainty, artifacts = _runtime_execution_result(raw)
            outcome = _runtime_outcome_symbol(raw_outcome)
        catch
            outcome = unknown
            metrics = ()
            uncertainty = nothing
            artifacts = ()
        end
    end
    all(m -> m isa MetricWithUnit, metrics) || throw(ArgumentError("provider returned untyped metrics"))
    sv = StatusVectorV4(required, unique_match, resolved, low_fidelity_evaluated, outcome)
    evidence = RuntimeEvidenceV4(input.physical_subject_hash, input.scenario_hash, input.solver_input_hash,
        provider.manifest_hash,
        (physical_subject_hash=input.physical_subject_hash, scenario_hash=input.scenario_hash,
         solver_input_hash=input.solver_input_hash, provider_manifest_hash=provider.manifest_hash,
         backend_revision=provider.backend_revision, code_hash=provider.code_hash), sv,
        metrics; claim_ceiling=provider.claim_ceiling, provider_manifest=provider,
        backend_revision=provider.backend_revision,
        numerical_configuration_hash=canonical_hash(input.payload.numerical_configuration),
        artifact_refs=artifacts, uncertainty_or_null=uncertainty)
    _runtime_put!(store, input.solver_input_hash, evidence)
end

function execute_once!(store, input::SolverInputV4, ::Nothing)
    cached = _runtime_cached(store, input.solver_input_hash)
    cached === nothing || return cached
    sv = StatusVectorV4(required, no_match, terminal_deferred, high_fidelity_pending, terminal_deferred_stage)
    evidence = RuntimeEvidenceV4(input.physical_subject_hash, input.scenario_hash, input.solver_input_hash,
        nothing, (solver_input_hash=input.solver_input_hash, reason="missing_provider"), sv, (); claim_ceiling=none)
    _runtime_put!(store, input.solver_input_hash, evidence)
end
