"""Repository-owned deterministic execution of the manufactured ECF contract.

This narrow adapter reuses `TrustedProviderRegistryV4` only as a content-addressed
repository trust root. It deliberately does not widen the generic registration
API: provider identity, source, entrypoint, manifest, and executor are fixed here.
"""
const _TECFE_SCHEMA =
    "fusionconceptai:runtime-v4-trusted-engineering-control-fault-provider"
const _TECFE_REVISION = "trusted-engineering-control-fault-provider-v2"
const _TECFE_INPUT_SCHEMA =
    "fusionconceptai:runtime-v4-trusted-engineering-control-fault-input"
const _TECFE_SECONDS = UnitSignature((0, 0, 1, 0, 0, 0, 0))
const _TECFE_POST_RECOVERY_WINDOW = 1 // 2
const _TECFE_INITIAL_STATE = 0 // 1
const _TECFE_SETPOINT = 1 // 1
const _TECFE_PLANT_RESPONSE = 1 // 2
const _TECFE_DROPOUT_DRAW_DENOMINATOR = Int64(1) << 60
const _TECFE_DROPOUT_COUNTER_DOMAIN =
    "fusionconceptai:runtime-v4-trusted-ecf-dropout-counter-v1"
const _TECFE_EXPECTED_OPERATORS =
    ("ECFGO_OBSERVE", "ECFGO_CONTROL", "ECFGO_ACTUATE")

struct _TrustedEngineeringControlFaultToken end
const _TECFE_TOKEN = _TrustedEngineeringControlFaultToken()
_tecfe_require_token(token::_TrustedEngineeringControlFaultToken) =
    token === _TECFE_TOKEN || throw(ArgumentError("private constructor token mismatch"))

const _TECFE_FALSE_FIELDS = (:emits_evidence, :engineering_evidence,
    :physical_evidence, :validation_evidence, :promotion_authority,
    :p5_authority, :terminal_authority)

function _tecfe_require_screen_only(x)
    x.claim_ceiling === screen_only ||
        throw(ArgumentError("trusted engineering control/fault result must remain screen_only"))
    x.credible_device_count == 0 ||
        throw(ArgumentError("trusted engineering control/fault credible device count must be zero"))
    all(field -> getfield(x, field) === false, _TECFE_FALSE_FIELDS) ||
        throw(ArgumentError("trusted engineering control/fault object cannot grant evidence or authority"))
    nothing
end

function _tecfe_compilation(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    compilation = resolve_engineering_control_fault_graph_obligation(context)
    validate_engineering_control_fault_graph_compilation(compilation, context) ||
        throw(ArgumentError("invalid current ECF compilation"))
    compilation.status === :compiled_contract ||
        throw(ArgumentError("current ECF contract is not compiled"))
    compilation.claim_ceiling === screen_only &&
        compilation.credible_device_count == 0 ||
        throw(ArgumentError("current ECF compilation exceeds the operational screen boundary"))
    compilation
end

function _tecfe_fixture_contract(context::ForwardChainContextV4)
    compilation = _tecfe_compilation(context)
    declaration = compilation.declaration::EngineeringControlFaultDeclarationV4
    binding = compilation.subject_binding::EngineeringControlFaultSubjectBindingV4
    operators = Tuple(spec.root_operator_ref.qualified.id for spec in declaration.specs)
    operators == _TECFE_EXPECTED_OPERATORS ||
        throw(ArgumentError("trusted executor supports only the repository manufactured control operators"))
    Tuple(edge.stage for edge in binding.edges) ==
        (observation_stage, controller_stage, actuator_stage) ||
        throw(ArgumentError("trusted executor requires the complete manufactured control chain"))
    timing = declaration.timing
    all(quantity -> quantity.unit == _TECFE_SECONDS,
        (timing.transport_delay, timing.dropout_onset, timing.dropout_duration,
         timing.fault_onset, timing.recovery_deadline)) ||
        throw(ArgumentError("trusted executor requires exact seconds timing"))
    compilation
end

function _tecfe_input_schema_body(context::ForwardChainContextV4,
        compilation::EngineeringControlFaultGraphCompilationV4)
    declaration = compilation.declaration::EngineeringControlFaultDeclarationV4
    binding = compilation.subject_binding::EngineeringControlFaultSubjectBindingV4
    (schema=_TECFE_INPUT_SCHEMA, revision=_TECFE_REVISION,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        declaration_hash=canonical_hash(declaration),
        subject_binding_hash=canonical_hash(binding),
        compilation_hash=canonical_hash(compilation),
        schedule_rule=:declared_boundaries_and_delayed_releases,
        dropout_sampling=:canonical_sha256_counter_first_60_bits,
        dropout_draw_denominator=_TECFE_DROPOUT_DRAW_DENOMINATOR,
        dropout_decision=:window_active_and_draw_strictly_below_probability,
        post_recovery_window=_TECFE_POST_RECOVERY_WINDOW,
        initial_state=_TECFE_INITIAL_STATE, setpoint=_TECFE_SETPOINT,
        plant_response=_TECFE_PLANT_RESPONSE)
end

function trusted_engineering_control_fault_capability(context::ForwardChainContextV4)
    compilation = _tecfe_fixture_contract(context)
    declaration = compilation.declaration::EngineeringControlFaultDeclarationV4
    input_schema_hash = canonical_hash(_tecfe_input_schema_body(context, compilation))
    CapabilitySignatureV4(_TECFE_SCHEMA, _TECFE_REVISION,
        :engineering_control_fault_operational_screen,
        "repository_manufactured_observation_controller_actuator_demo",
        Tuple(edge.output_node.node_id for edge in
            compilation.subject_binding.edges),
        "typed_current_g3_control_chain", "operational_receipt", 0, (),
        "typed_actuator_interval", "single_manufactured_control_chain",
        "exact_event_aligned_discrete_time",
        ("deterministic_trace_hash", "exact_dropout_draws",
         "bounded_actuator_summary",
         "operational_receipt_hash"), screen_only,
        context.compiled.minimality_scope.bounds_hash;
        input_schema_hash=input_schema_hash, coordinate_system="lumped_control")
end

function validate_trusted_engineering_control_fault_capability(
        capability::CapabilitySignatureV4, context::ForwardChainContextV4)
    expected = trusted_engineering_control_fault_capability(context)
    canonical_hash(capability) == canonical_hash(expected) ||
        throw(ArgumentError("engineering control/fault capability is not derived from current context"))
    expected
end

struct TrustedEngineeringControlFaultInputV4
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    declaration_hash::Digest256
    subject_binding_hash::Digest256
    compilation_hash::Digest256
    capability_hash::Digest256
    sample_times::Tuple{Vararg{NonnegativeQuantityV1}}
    horizon::NonnegativeQuantityV1
    initial_state::Rational{Int64}
    setpoint::Rational{Int64}
    plant_response::Rational{Int64}
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    engineering_evidence::Bool
    physical_evidence::Bool
    validation_evidence::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    input_hash::Digest256
    function TrustedEngineeringControlFaultInputV4(
            token::_TrustedEngineeringControlFaultToken, a...)
        _tecfe_require_token(token)
        new(a...)
    end
end
TrustedEngineeringControlFaultInputV4(a...) =
    throw(ArgumentError("sealed trusted engineering control/fault input"))

function _tecfe_input_body(x::TrustedEngineeringControlFaultInputV4)
    _tecfe_require_screen_only(x)
    !isempty(x.sample_times) || throw(ArgumentError("sample schedule cannot be empty"))
    all(item -> item.unit == _TECFE_SECONDS, x.sample_times) &&
        x.horizon.unit == _TECFE_SECONDS ||
        throw(ArgumentError("trusted engineering control/fault protocol must use seconds"))
    x.horizon.value > 0 || throw(ArgumentError("horizon must be positive"))
    values = Tuple(item.value for item in x.sample_times)
    first(values) == 0 // 1 && last(values) == x.horizon.value ||
        throw(ArgumentError("sample schedule must span zero through horizon"))
    issorted(values) && length(unique(values)) == length(values) ||
        throw(ArgumentError("sample schedule must be strictly ordered and unique"))
    (schema=_TECFE_INPUT_SCHEMA, revision=_TECFE_REVISION,
        context_hash=x.context_hash, physical_subject_hash=x.physical_subject_hash,
        scenario_hash=x.scenario_hash, declaration_hash=x.declaration_hash,
        subject_binding_hash=x.subject_binding_hash,
        compilation_hash=x.compilation_hash, capability_hash=x.capability_hash,
        sample_times=x.sample_times, horizon=x.horizon, initial_state=x.initial_state,
        setpoint=x.setpoint, plant_response=x.plant_response,
        claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        engineering_evidence=x.engineering_evidence,
        physical_evidence=x.physical_evidence,
        validation_evidence=x.validation_evidence,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end


function _tecfe_sample_times(timing::EngineeringControlFaultTimingV4,
        horizon::Rational{Int64})
    dropout_end = timing.dropout_onset.value + timing.dropout_duration.value
    base = (0 // 1, timing.dropout_onset.value, dropout_end,
        timing.fault_onset.value, timing.recovery_deadline.value, horizon)
    delayed = Tuple(time + timing.transport_delay.value for time in base
        if time + timing.transport_delay.value <= horizon)
    values = Tuple(sort!(unique!(collect((base..., delayed...)))))
    Tuple(NonnegativeQuantityV1(value, _TECFE_SECONDS) for value in values)
end
semantic_view(x::TrustedEngineeringControlFaultInputV4) = _tecfe_input_body(x)
function canonical_hash(x::TrustedEngineeringControlFaultInputV4)
    expected = canonical_hash(_tecfe_input_body(x))
    x.input_hash == expected ||
        throw(ArgumentError("trusted engineering control/fault input hash mismatch"))
    expected
end

function make_trusted_engineering_control_fault_input(context::ForwardChainContextV4)
    compilation = _tecfe_fixture_contract(context)
    declaration = compilation.declaration::EngineeringControlFaultDeclarationV4
    timing = declaration.timing
    horizon_value = timing.recovery_deadline.value + _TECFE_POST_RECOVERY_WINDOW
    timing.dropout_onset.value + timing.dropout_duration.value <= horizon_value ||
        throw(ArgumentError("declared dropout extends beyond trusted demo horizon"))
    capability = trusted_engineering_control_fault_capability(context)
    binding = compilation.subject_binding::EngineeringControlFaultSubjectBindingV4
    body = (schema=_TECFE_INPUT_SCHEMA, revision=_TECFE_REVISION,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        declaration_hash=canonical_hash(declaration),
        subject_binding_hash=canonical_hash(binding),
        compilation_hash=canonical_hash(compilation),
        capability_hash=canonical_hash(capability),
        sample_times=_tecfe_sample_times(timing, horizon_value),
        horizon=NonnegativeQuantityV1(horizon_value, _TECFE_SECONDS),
        initial_state=Rational{Int64}(_TECFE_INITIAL_STATE),
        setpoint=Rational{Int64}(_TECFE_SETPOINT),
        plant_response=Rational{Int64}(_TECFE_PLANT_RESPONSE),
        claim_ceiling=screen_only, credible_device_count=0,
        emits_evidence=false, engineering_evidence=false,
        physical_evidence=false, validation_evidence=false,
        promotion_authority=false, p5_authority=false, terminal_authority=false)
    input = TrustedEngineeringControlFaultInputV4(_TECFE_TOKEN,
        body.context_hash, body.physical_subject_hash, body.scenario_hash,
        body.declaration_hash, body.subject_binding_hash, body.compilation_hash,
        body.capability_hash, body.sample_times, body.horizon, body.initial_state,
        body.setpoint, body.plant_response, screen_only, 0, false, false, false,
        false, false, false, false, canonical_hash(body))
    canonical_hash(input)
    input
end

function validate_trusted_engineering_control_fault_input(
        input::TrustedEngineeringControlFaultInputV4,
        context::ForwardChainContextV4)
    expected = make_trusted_engineering_control_fault_input(context)
    canonical_hash(input) == canonical_hash(expected) &&
        semantic_view(input) == semantic_view(expected) ||
        throw(ArgumentError("trusted engineering control/fault input is not current"))
    expected
end

struct EngineeringControlFaultOperationalStepV4
    step_index::Int
    time::Rational{Int64}
    plant_state::Rational{Int64}
    observation::Union{Nothing,Rational{Int64}}
    requested_command::Rational{Int64}
    actuator_command::Rational{Int64}
    released_command::Bool
    dropout_window_active::Bool
    dropout_draw::Rational{Int64}
    scheduled_dropout_active::Bool
    declared_fault_active::Bool
end
semantic_view(x::EngineeringControlFaultOperationalStepV4) = (
    step_index=x.step_index, time=x.time, plant_state=x.plant_state,
    observation=x.observation, requested_command=x.requested_command,
    actuator_command=x.actuator_command,
    released_command=x.released_command,
    dropout_window_active=x.dropout_window_active,
    dropout_draw=x.dropout_draw,
    scheduled_dropout_active=x.scheduled_dropout_active,
    declared_fault_active=x.declared_fault_active)

struct TrustedEngineeringControlFaultResultV4
    input_hash::Digest256
    declaration_hash::Digest256
    subject_binding_hash::Digest256
    sample_count::Int
    final_state::Rational{Int64}
    maximum_absolute_actuator::Rational{Int64}
    actuator_bound_violation_count::Int
    saturation_count::Int
    scheduled_dropout_sample_count::Int
    declared_fault_sample_count::Int
    transport_release_count::Int
    trace::Tuple{Vararg{EngineeringControlFaultOperationalStepV4}}
    trace_hash::Digest256
    status::Symbol
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    engineering_evidence::Bool
    physical_evidence::Bool
    validation_evidence::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    result_hash::Digest256
    function TrustedEngineeringControlFaultResultV4(
            token::_TrustedEngineeringControlFaultToken, a...)
        _tecfe_require_token(token)
        new(a...)
    end
end
TrustedEngineeringControlFaultResultV4(a...) =
    throw(ArgumentError("sealed trusted engineering control/fault result"))

function _tecfe_result_body(x::TrustedEngineeringControlFaultResultV4)
    _tecfe_require_screen_only(x)
    x.status === :operational_screen_completed ||
        throw(ArgumentError("trusted engineering control/fault result status is invalid"))
    x.sample_count == length(x.trace) || throw(ArgumentError("result sample count mismatch"))
    expected_trace_hash = canonical_hash(x.trace)
    x.trace_hash == expected_trace_hash || throw(ArgumentError("result trace hash mismatch"))
    x.actuator_bound_violation_count == 0 ||
        throw(ArgumentError("trusted result contains an actuator bound violation"))
    (schema=_TECFE_SCHEMA, revision=_TECFE_REVISION, input_hash=x.input_hash,
        declaration_hash=x.declaration_hash,
        subject_binding_hash=x.subject_binding_hash, sample_count=x.sample_count,
        final_state=x.final_state,
        maximum_absolute_actuator=x.maximum_absolute_actuator,
        actuator_bound_violation_count=x.actuator_bound_violation_count,
        saturation_count=x.saturation_count,
        scheduled_dropout_sample_count=x.scheduled_dropout_sample_count,
        declared_fault_sample_count=x.declared_fault_sample_count,
        transport_release_count=x.transport_release_count,
        trace=x.trace, trace_hash=x.trace_hash,
        status=x.status, claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        engineering_evidence=x.engineering_evidence,
        physical_evidence=x.physical_evidence,
        validation_evidence=x.validation_evidence,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::TrustedEngineeringControlFaultResultV4) = _tecfe_result_body(x)
function canonical_hash(x::TrustedEngineeringControlFaultResultV4)
    expected = canonical_hash(_tecfe_result_body(x))
    x.result_hash == expected ||
        throw(ArgumentError("trusted engineering control/fault result hash mismatch"))
    expected
end

function _tecfe_clamp(value::Rational{Int64}, interval::ExactFiniteIntervalV1)
    max(interval.lower, min(interval.upper, value))
end

function _tecfe_dropout_draw(context::ForwardChainContextV4,
        input_hash::Digest256, time::Rational{Int64}, index::Int)
    index >= 0 || throw(ArgumentError("dropout counter index must be nonnegative"))
    time >= 0 || throw(ArgumentError("dropout counter time must be nonnegative"))
    counter_hash = canonical_hash((domain=_TECFE_DROPOUT_COUNTER_DOMAIN,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash, input_hash=input_hash,
        sample_time=time, sample_index=index))
    numerator_value = parse(Int64, first(string(counter_hash), 15); base=16)
    numerator_value // _TECFE_DROPOUT_DRAW_DENOMINATOR
end

function _tecfe_dropout_decision(draw::Rational{Int64},
        probability::Rational{Int64}, window_active::Bool)
    0 // 1 <= draw < 1 // 1 ||
        throw(ArgumentError("dropout draw must be in [0,1)"))
    0 // 1 <= probability <= 1 // 1 ||
        throw(ArgumentError("dropout probability must be in [0,1]"))
    window_active && draw < probability
end

function _tecfe_execute_kernel(context::ForwardChainContextV4,
        input::TrustedEngineeringControlFaultInputV4)
    validate_trusted_engineering_control_fault_input(input, context)
    compilation = _tecfe_fixture_contract(context)
    declaration = compilation.declaration::EngineeringControlFaultDeclarationV4
    binding = compilation.subject_binding::EngineeringControlFaultSubjectBindingV4
    timing = declaration.timing
    interval = declaration.actuator_limit.interval.interval
    control_times = Set((0 // 1, timing.dropout_onset.value,
        timing.dropout_onset.value + timing.dropout_duration.value,
        timing.fault_onset.value, timing.recovery_deadline.value,
        input.horizon.value))
    pending_commands = Tuple{Rational{Int64},Rational{Int64}}[]
    trace = EngineeringControlFaultOperationalStepV4[]
    state = input.initial_state
    last_observation = state
    active_delayed_command = 0 // 1
    prior_actuator = 0 // 1
    prior_time = 0 // 1
    violations = 0
    saturations = 0
    scheduled_dropout_samples = 0
    declared_fault_samples = 0
    transport_releases = 0
    maximum_actuator = 0 // 1
    dropout_end = timing.dropout_onset.value + timing.dropout_duration.value
    input_hash = canonical_hash(input)
    for (offset, sample_time) in enumerate(input.sample_times)
        index = offset - 1
        time = sample_time.value
        if index > 0
            state += (time - prior_time) * input.plant_response * prior_actuator
        end
        released = false
        while !isempty(pending_commands) && first(pending_commands)[1] <= time
            _, active_delayed_command = popfirst!(pending_commands)
            transport_releases += 1
            released = true
        end
        dropout_window_active = timing.dropout_onset.value <= time < dropout_end
        dropout_draw = _tecfe_dropout_draw(context, input_hash, time, index)
        scheduled_dropout = _tecfe_dropout_decision(dropout_draw,
            timing.dropout_probability, dropout_window_active)
        declared_fault = timing.fault_onset.value <= time <
            timing.recovery_deadline.value
        observation_lost = scheduled_dropout ||
            (timing.fault_mode === observation_dropout && declared_fault)
        observation = observation_lost ? nothing : state
        observation === nothing || (last_observation = observation)
        requested = input.setpoint - last_observation
        if time in control_times
            bounded = _tecfe_clamp(requested, interval)
            bounded != requested && (saturations += 1)
            release_time = time + timing.transport_delay.value
            if release_time == time
                active_delayed_command = bounded
                transport_releases += 1
                released = true
            elseif release_time <= input.horizon.value
                push!(pending_commands, (release_time, bounded))
            end
        end
        actuator = timing.fault_mode === actuator_stuck && declared_fault ?
            prior_actuator : active_delayed_command
        !(interval.lower <= actuator <= interval.upper) && (violations += 1)
        maximum_actuator = max(maximum_actuator, abs(actuator))
        scheduled_dropout && (scheduled_dropout_samples += 1)
        declared_fault && (declared_fault_samples += 1)
        push!(trace, EngineeringControlFaultOperationalStepV4(index, time, state,
            observation, requested, actuator, released, dropout_window_active,
            dropout_draw, scheduled_dropout, declared_fault))
        prior_actuator = actuator
        prior_time = time
    end
    trace_tuple = Tuple(trace)
    trace_hash = canonical_hash(trace_tuple)
    body = (schema=_TECFE_SCHEMA, revision=_TECFE_REVISION,
        input_hash=input_hash, declaration_hash=canonical_hash(declaration),
        subject_binding_hash=canonical_hash(binding), sample_count=length(trace_tuple),
        final_state=state, maximum_absolute_actuator=maximum_actuator,
        actuator_bound_violation_count=violations, saturation_count=saturations,
        scheduled_dropout_sample_count=scheduled_dropout_samples,
        declared_fault_sample_count=declared_fault_samples,
        transport_release_count=transport_releases,
        trace=trace_tuple, trace_hash=trace_hash,
        status=:operational_screen_completed, claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        engineering_evidence=false, physical_evidence=false,
        validation_evidence=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    result = TrustedEngineeringControlFaultResultV4(_TECFE_TOKEN,
        body.input_hash, body.declaration_hash, body.subject_binding_hash,
        body.sample_count, body.final_state, body.maximum_absolute_actuator,
        body.actuator_bound_violation_count, body.saturation_count,
        body.scheduled_dropout_sample_count, body.declared_fault_sample_count,
        body.transport_release_count, trace_tuple, trace_hash, body.status,
        screen_only, 0,
        false, false, false, false, false, false, false, canonical_hash(body))
    canonical_hash(result)
    result
end

function validate_trusted_engineering_control_fault_result(
        result::TrustedEngineeringControlFaultResultV4,
        context::ForwardChainContextV4,
        input::TrustedEngineeringControlFaultInputV4)
    expected = _tecfe_execute_kernel(context, input)
    canonical_hash(result) == canonical_hash(expected) &&
        semantic_view(result) == semantic_view(expected) ||
        throw(ArgumentError("trusted engineering control/fault result is not reproducible"))
    expected
end

function _tecfe_domain(context::ForwardChainContextV4,
        descriptor::RepositoryProviderDescriptorV4,
        compilation::EngineeringControlFaultGraphCompilationV4,
        capability::CapabilitySignatureV4,
        input::TrustedEngineeringControlFaultInputV4)
    (model_class=_TPR_ENGINEERING_CONTROL_FAULT_MODEL_CLASS,
        descriptor_hash=descriptor.descriptor_hash,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        declaration_hash=canonical_hash(compilation.declaration),
        subject_binding_hash=canonical_hash(compilation.subject_binding),
        compilation_hash=canonical_hash(compilation),
        capability_hash=canonical_hash(capability), input_hash=canonical_hash(input),
        bounds_hash=context.compiled.minimality_scope.bounds_hash)
end

function _tecfe_manifest(descriptor::RepositoryProviderDescriptorV4,
        context::ForwardChainContextV4,
        compilation::EngineeringControlFaultGraphCompilationV4,
        capability::CapabilitySignatureV4,
        input::TrustedEngineeringControlFaultInputV4)
    ProviderManifestV4(capability.schema, capability.revision, capability.kind,
        capability, _tecfe_domain(context, descriptor, compilation, capability, input),
        descriptor.provider_id, _TPR_REVISION, descriptor.source_hash,
        "trusted-repository:$(_TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)",
        screen_only; input_schema_hash=capability.input_schema_hash,
        executor=descriptor.executor)
end

struct TrustedEngineeringControlFaultRegistrationV4
    base_registry_hash::Digest256
    descriptor_hash::Digest256
    source_hash::Digest256
    runtime_hash::Digest256
    attested_source_hashes::Tuple{Vararg{Digest256}}
    context::ForwardChainContextV4
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    declaration_hash::Digest256
    subject_binding_hash::Digest256
    compilation_hash::Digest256
    capability::CapabilitySignatureV4
    capability_hash::Digest256
    input::TrustedEngineeringControlFaultInputV4
    input_hash::Digest256
    manifest::ProviderManifestV4
    manifest_hash::Digest256
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    engineering_evidence::Bool
    physical_evidence::Bool
    validation_evidence::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    registration_hash::Digest256
    function TrustedEngineeringControlFaultRegistrationV4(
            token::_TrustedEngineeringControlFaultToken, a...)
        _tecfe_require_token(token)
        new(a...)
    end
end
TrustedEngineeringControlFaultRegistrationV4(a...) =
    throw(ArgumentError("sealed trusted engineering control/fault registration"))

function _tecfe_registration_body(x::TrustedEngineeringControlFaultRegistrationV4)
    _tecfe_require_screen_only(x)
    canonical_hash(x.input) == x.input_hash ||
        throw(ArgumentError("engineering registration input hash mismatch"))
    canonical_hash(x.capability) == x.capability_hash ||
        throw(ArgumentError("engineering registration capability hash mismatch"))
    x.manifest.manifest_hash == x.manifest_hash ||
        throw(ArgumentError("engineering registration manifest hash mismatch"))
    (revision=_TECFE_REVISION, base_registry_hash=x.base_registry_hash,
        descriptor_hash=x.descriptor_hash, source_hash=x.source_hash,
        runtime_hash=x.runtime_hash,
        attested_source_hashes=x.attested_source_hashes,
        context_hash=x.context_hash, physical_subject_hash=x.physical_subject_hash,
        scenario_hash=x.scenario_hash, declaration_hash=x.declaration_hash,
        subject_binding_hash=x.subject_binding_hash,
        compilation_hash=x.compilation_hash, capability_hash=x.capability_hash,
        input_hash=x.input_hash, manifest_hash=x.manifest_hash,
        claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        engineering_evidence=x.engineering_evidence,
        physical_evidence=x.physical_evidence,
        validation_evidence=x.validation_evidence,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::TrustedEngineeringControlFaultRegistrationV4) =
    _tecfe_registration_body(x)
function canonical_hash(x::TrustedEngineeringControlFaultRegistrationV4)
    expected = canonical_hash(_tecfe_registration_body(x))
    x.registration_hash == expected ||
        throw(ArgumentError("engineering control/fault registration hash mismatch"))
    expected
end

struct TrustedEngineeringControlFaultRegistryV4
    base_registry::TrustedProviderRegistryV4
    registration::TrustedEngineeringControlFaultRegistrationV4
    registry_hash::Digest256
    function TrustedEngineeringControlFaultRegistryV4(
            token::_TrustedEngineeringControlFaultToken, a...)
        _tecfe_require_token(token)
        new(a...)
    end
end
TrustedEngineeringControlFaultRegistryV4(a...) =
    throw(ArgumentError("sealed trusted engineering control/fault registry"))

function validate_trusted_engineering_control_fault_registration(
        registration::TrustedEngineeringControlFaultRegistrationV4,
        base_registry::TrustedProviderRegistryV4)
    validate_trusted_provider_registry(base_registry)
    descriptor = _tpr_find_descriptor(base_registry,
        _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    validate_repository_provider_descriptor(descriptor,
        base_registry.repository_root)
    registration.base_registry_hash == base_registry.registry_hash ||
        throw(ArgumentError("engineering registration base registry mismatch"))
    registration.descriptor_hash == descriptor.descriptor_hash ||
        throw(ArgumentError("engineering registration descriptor mismatch"))
    registration.source_hash == descriptor.source_hash ||
        throw(ArgumentError("engineering registration source mismatch"))
    registration.runtime_hash == descriptor.runtime_hash ||
        throw(ArgumentError("engineering registration runtime mismatch"))
    registration.attested_source_hashes == descriptor.attested_source_hashes ||
        throw(ArgumentError("engineering registration attested sources mismatch"))
    context = registration.context
    validate_forward_chain_context(context)
    context.context_hash == registration.context_hash ||
        throw(ArgumentError("engineering registration context mismatch"))
    context.subject.physical_subject_hash == registration.physical_subject_hash ||
        throw(ArgumentError("engineering registration subject mismatch"))
    context.scenario_hash == registration.scenario_hash ||
        throw(ArgumentError("engineering registration scenario mismatch"))
    compilation = _tecfe_fixture_contract(context)
    canonical_hash(compilation.declaration) == registration.declaration_hash ||
        throw(ArgumentError("engineering registration declaration mismatch"))
    canonical_hash(compilation.subject_binding) == registration.subject_binding_hash ||
        throw(ArgumentError("engineering registration subject binding mismatch"))
    canonical_hash(compilation) == registration.compilation_hash ||
        throw(ArgumentError("engineering registration compilation mismatch"))
    capability = validate_trusted_engineering_control_fault_capability(
        registration.capability, context)
    canonical_hash(capability) == registration.capability_hash ||
        throw(ArgumentError("engineering registration capability mismatch"))
    input = validate_trusted_engineering_control_fault_input(
        registration.input, context)
    canonical_hash(input) == registration.input_hash ||
        throw(ArgumentError("engineering registration input mismatch"))
    expected_manifest = _tecfe_manifest(descriptor, context, compilation,
        capability, input)
    registration.manifest.executor === descriptor.executor ||
        throw(ArgumentError("engineering registration executor is not repository-owned"))
    registration.manifest.manifest_hash == expected_manifest.manifest_hash &&
        semantic_view(registration.manifest) == semantic_view(expected_manifest) ||
        throw(ArgumentError("engineering registration manifest mismatch"))
    registration.manifest_hash == expected_manifest.manifest_hash ||
        throw(ArgumentError("engineering registration manifest identity mismatch"))
    match_provider(capability, (registration.manifest,)).status == unique_match ||
        throw(ArgumentError("engineering provider does not exactly match capability"))
    expected_hash = canonical_hash(_tecfe_registration_body(registration))
    registration.registration_hash == expected_hash ||
        throw(ArgumentError("engineering registration hash mismatch"))
    expected_hash
end

function validate_trusted_engineering_control_fault_registry(
        registry::TrustedEngineeringControlFaultRegistryV4)
    validate_trusted_engineering_control_fault_registration(registry.registration,
        registry.base_registry)
    expected = canonical_hash((revision=_TECFE_REVISION,
        base_registry_hash=registry.base_registry.registry_hash,
        registration_hash=registry.registration.registration_hash))
    registry.registry_hash == expected ||
        throw(ArgumentError("trusted engineering control/fault registry hash mismatch"))
    expected
end
canonical_hash(x::TrustedEngineeringControlFaultRegistryV4) =
    validate_trusted_engineering_control_fault_registry(x)
semantic_view(x::TrustedEngineeringControlFaultRegistryV4) = (
    base_registry_hash=x.base_registry.registry_hash,
    registration_hash=x.registration.registration_hash,
    registry_hash=x.registry_hash)

"""Register the one built-in engineering executor and its context-derived input.

There are deliberately no provider-id, descriptor, manifest, executor,
capability, or input arguments.
"""
function register_trusted_engineering_control_fault_provider(
        base_registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4)
    validate_trusted_provider_registry(base_registry)
    isempty(base_registry.registrations) ||
        throw(ArgumentError("engineering trust root cannot contain generic registrations"))
    descriptor = _tpr_find_descriptor(base_registry,
        _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    validate_repository_provider_descriptor(descriptor,
        base_registry.repository_root)
    compilation = _tecfe_fixture_contract(context)
    capability = trusted_engineering_control_fault_capability(context)
    input = make_trusted_engineering_control_fault_input(context)
    manifest = _tecfe_manifest(descriptor, context, compilation, capability, input)
    body = (revision=_TECFE_REVISION,
        base_registry_hash=base_registry.registry_hash,
        descriptor_hash=descriptor.descriptor_hash,
        source_hash=descriptor.source_hash, runtime_hash=descriptor.runtime_hash,
        attested_source_hashes=descriptor.attested_source_hashes,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        declaration_hash=canonical_hash(compilation.declaration),
        subject_binding_hash=canonical_hash(compilation.subject_binding),
        compilation_hash=canonical_hash(compilation),
        capability_hash=canonical_hash(capability), input_hash=canonical_hash(input),
        manifest_hash=manifest.manifest_hash, claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        engineering_evidence=false, physical_evidence=false,
        validation_evidence=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    registration = TrustedEngineeringControlFaultRegistrationV4(_TECFE_TOKEN,
        body.base_registry_hash, body.descriptor_hash, body.source_hash,
        body.runtime_hash, body.attested_source_hashes, context,
        body.context_hash, body.physical_subject_hash, body.scenario_hash,
        body.declaration_hash, body.subject_binding_hash, body.compilation_hash,
        capability, body.capability_hash, input, body.input_hash, manifest,
        body.manifest_hash, screen_only, 0, false, false, false, false,
        false, false, false, canonical_hash(body))
    canonical_hash(registration)
    validate_trusted_engineering_control_fault_registration(registration,
        base_registry)
    registry_body = (revision=_TECFE_REVISION,
        base_registry_hash=base_registry.registry_hash,
        registration_hash=registration.registration_hash)
    trusted = TrustedEngineeringControlFaultRegistryV4(_TECFE_TOKEN,
        base_registry, registration, canonical_hash(registry_body))
    validate_trusted_engineering_control_fault_registry(trusted)
    trusted
end

struct TrustedEngineeringControlFaultDispatchRequestV4
    registry_hash::Digest256
    registration_hash::Digest256
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    declaration_hash::Digest256
    subject_binding_hash::Digest256
    compilation_hash::Digest256
    capability_hash::Digest256
    input_hash::Digest256
    status::Symbol
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    engineering_evidence::Bool
    physical_evidence::Bool
    validation_evidence::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    request_hash::Digest256
    function TrustedEngineeringControlFaultDispatchRequestV4(
            token::_TrustedEngineeringControlFaultToken, a...)
        _tecfe_require_token(token)
        new(a...)
    end
end
TrustedEngineeringControlFaultDispatchRequestV4(a...) =
    throw(ArgumentError("sealed trusted engineering control/fault request"))

function _tecfe_request_body(x::TrustedEngineeringControlFaultDispatchRequestV4)
    _tecfe_require_screen_only(x)
    x.status === :ready_for_dispatch ||
        throw(ArgumentError("engineering control/fault request is not ready"))
    (revision=_TECFE_REVISION, registry_hash=x.registry_hash,
        registration_hash=x.registration_hash, context_hash=x.context_hash,
        physical_subject_hash=x.physical_subject_hash,
        scenario_hash=x.scenario_hash, declaration_hash=x.declaration_hash,
        subject_binding_hash=x.subject_binding_hash,
        compilation_hash=x.compilation_hash, capability_hash=x.capability_hash,
        input_hash=x.input_hash, status=x.status, claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        engineering_evidence=x.engineering_evidence,
        physical_evidence=x.physical_evidence,
        validation_evidence=x.validation_evidence,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::TrustedEngineeringControlFaultDispatchRequestV4) =
    _tecfe_request_body(x)
function canonical_hash(x::TrustedEngineeringControlFaultDispatchRequestV4)
    expected = canonical_hash(_tecfe_request_body(x))
    x.request_hash == expected ||
        throw(ArgumentError("engineering control/fault request hash mismatch"))
    expected
end

function build_trusted_engineering_control_fault_dispatch_request(
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4)
    validate_trusted_engineering_control_fault_registry(registry)
    registration = registry.registration
    validate_trusted_engineering_control_fault_registration(registration,
        registry.base_registry)
    validate_forward_chain_context(context)
    context.context_hash == registration.context_hash &&
        context.subject.physical_subject_hash == registration.physical_subject_hash &&
        context.scenario_hash == registration.scenario_hash ||
        throw(ArgumentError("dispatch context does not match trusted registration"))
    compilation = _tecfe_fixture_contract(context)
    capability = validate_trusted_engineering_control_fault_capability(
        registration.capability, context)
    input = validate_trusted_engineering_control_fault_input(
        registration.input, context)
    body = (revision=_TECFE_REVISION, registry_hash=registry.registry_hash,
        registration_hash=registration.registration_hash,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        declaration_hash=canonical_hash(compilation.declaration),
        subject_binding_hash=canonical_hash(compilation.subject_binding),
        compilation_hash=canonical_hash(compilation),
        capability_hash=canonical_hash(capability), input_hash=canonical_hash(input),
        status=:ready_for_dispatch, claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        engineering_evidence=false, physical_evidence=false,
        validation_evidence=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    request = TrustedEngineeringControlFaultDispatchRequestV4(_TECFE_TOKEN,
        body.registry_hash, body.registration_hash, body.context_hash,
        body.physical_subject_hash, body.scenario_hash, body.declaration_hash,
        body.subject_binding_hash, body.compilation_hash, body.capability_hash,
        body.input_hash, body.status, screen_only, 0, false, false, false,
        false, false, false, false, canonical_hash(body))
    canonical_hash(request)
    request
end

function validate_trusted_engineering_control_fault_dispatch_request(
        request::TrustedEngineeringControlFaultDispatchRequestV4,
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4)
    expected = build_trusted_engineering_control_fault_dispatch_request(
        registry, context)
    canonical_hash(request) == canonical_hash(expected) &&
        semantic_view(request) == semantic_view(expected) ||
        throw(ArgumentError("engineering control/fault dispatch request is not current"))
    expected
end

"""Fixed repository entrypoint used by the content-addressed descriptor."""
function _trusted_engineering_control_fault_executor(
        context::ForwardChainContextV4,
        input::TrustedEngineeringControlFaultInputV4)
    _tecfe_execute_kernel(context, input)
end

struct TrustedEngineeringControlFaultOperationalReceiptV4
    registry_hash::Digest256
    registration_hash::Digest256
    request_hash::Digest256
    descriptor_hash::Digest256
    source_hash::Digest256
    runtime_hash::Digest256
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    input_hash::Digest256
    result::TrustedEngineeringControlFaultResultV4
    result_hash::Digest256
    exit_code::Int
    status::Symbol
    message::String
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    engineering_evidence::Bool
    physical_evidence::Bool
    validation_evidence::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    receipt_hash::Digest256
    function TrustedEngineeringControlFaultOperationalReceiptV4(
            token::_TrustedEngineeringControlFaultToken, a...)
        _tecfe_require_token(token)
        new(a...)
    end
end
TrustedEngineeringControlFaultOperationalReceiptV4(a...) =
    throw(ArgumentError("sealed trusted engineering control/fault operational receipt"))

function _tecfe_receipt_body(x::TrustedEngineeringControlFaultOperationalReceiptV4)
    _tecfe_require_screen_only(x)
    x.exit_code == 0 || throw(ArgumentError("operational receipt exit code must be zero"))
    x.status === :operational_screen ||
        throw(ArgumentError("operational receipt status is invalid"))
    canonical_hash(x.result) == x.result_hash ||
        throw(ArgumentError("operational receipt result hash mismatch"))
    (revision=_TECFE_REVISION, registry_hash=x.registry_hash,
        registration_hash=x.registration_hash, request_hash=x.request_hash,
        descriptor_hash=x.descriptor_hash, source_hash=x.source_hash,
        runtime_hash=x.runtime_hash, context_hash=x.context_hash,
        physical_subject_hash=x.physical_subject_hash,
        scenario_hash=x.scenario_hash, input_hash=x.input_hash,
        result_hash=x.result_hash, exit_code=x.exit_code, status=x.status,
        message=x.message, claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        engineering_evidence=x.engineering_evidence,
        physical_evidence=x.physical_evidence,
        validation_evidence=x.validation_evidence,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::TrustedEngineeringControlFaultOperationalReceiptV4) =
    _tecfe_receipt_body(x)
function canonical_hash(x::TrustedEngineeringControlFaultOperationalReceiptV4)
    expected = canonical_hash(_tecfe_receipt_body(x))
    x.receipt_hash == expected ||
        throw(ArgumentError("engineering control/fault receipt hash mismatch"))
    expected
end

function execute_trusted_engineering_control_fault_provider(
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4,
        request::TrustedEngineeringControlFaultDispatchRequestV4)
    validate_trusted_engineering_control_fault_registry(registry)
    validate_trusted_engineering_control_fault_dispatch_request(request,
        registry, context)
    registration = registry.registration
    descriptor = _tpr_find_descriptor(registry.base_registry,
        _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    validate_repository_provider_descriptor(descriptor,
        registry.base_registry.repository_root)
    descriptor.executor === _trusted_engineering_control_fault_executor ||
        throw(ArgumentError("engineering executor identity changed before dispatch"))
    input = validate_trusted_engineering_control_fault_input(
        registration.input, context)
    result = Base.invokelatest(_trusted_engineering_control_fault_executor,
        context, input)
    result isa TrustedEngineeringControlFaultResultV4 ||
        throw(ArgumentError("engineering executor returned the wrong result type"))
    validate_trusted_engineering_control_fault_result(result, context, input)
    # Revalidate the repository trust root, fixed source/runtime, context, input,
    # and recomputable result after dispatch before issuing a receipt.
    validate_trusted_engineering_control_fault_registry(registry)
    validate_repository_provider_descriptor(descriptor,
        registry.base_registry.repository_root)
    validate_forward_chain_context(context)
    validate_trusted_engineering_control_fault_input(input, context)
    validate_trusted_engineering_control_fault_result(result, context, input)
    message = "repository-owned manufactured control/fault operational screen"
    body = (revision=_TECFE_REVISION, registry_hash=registry.registry_hash,
        registration_hash=registration.registration_hash,
        request_hash=request.request_hash, descriptor_hash=descriptor.descriptor_hash,
        source_hash=descriptor.source_hash, runtime_hash=descriptor.runtime_hash,
        context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash, input_hash=canonical_hash(input),
        result_hash=canonical_hash(result), exit_code=0,
        status=:operational_screen, message=message, claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        engineering_evidence=false, physical_evidence=false,
        validation_evidence=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    receipt = TrustedEngineeringControlFaultOperationalReceiptV4(_TECFE_TOKEN,
        body.registry_hash, body.registration_hash, body.request_hash,
        body.descriptor_hash, body.source_hash, body.runtime_hash,
        body.context_hash, body.physical_subject_hash, body.scenario_hash,
        body.input_hash, result, body.result_hash, body.exit_code, body.status,
        body.message, screen_only, 0, false, false, false, false, false,
        false, false, canonical_hash(body))
    canonical_hash(receipt)
    receipt
end

function validate_trusted_engineering_control_fault_operational_receipt(
        receipt::TrustedEngineeringControlFaultOperationalReceiptV4,
        request::TrustedEngineeringControlFaultDispatchRequestV4,
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4)
    validate_trusted_engineering_control_fault_registry(registry)
    validate_trusted_engineering_control_fault_dispatch_request(request,
        registry, context)
    registration = registry.registration
    descriptor = _tpr_find_descriptor(registry.base_registry,
        _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    validate_repository_provider_descriptor(descriptor,
        registry.base_registry.repository_root)
    input = validate_trusted_engineering_control_fault_input(
        registration.input, context)
    validate_trusted_engineering_control_fault_result(receipt.result,
        context, input)
    expected = execute_trusted_engineering_control_fault_provider(registry,
        context, request)
    canonical_hash(receipt) == canonical_hash(expected) &&
        semantic_view(receipt) == semantic_view(expected) ||
        throw(ArgumentError("engineering control/fault operational receipt is not reproducible"))
    expected
end

trusted_engineering_control_fault_provider_manifest() = (
    schema=_TECFE_SCHEMA, revision=_TECFE_REVISION,
    provider_id=_TPR_ENGINEERING_CONTROL_FAULT_PROVIDER,
    source_relative_path=_TPR_ENGINEERING_CONTROL_FAULT_SOURCE,
    entrypoint=:_trusted_engineering_control_fault_executor,
    attested_source_paths=_TPR_ENGINEERING_CONTROL_FAULT_ATTESTED_SOURCES,
    accepts_caller_descriptor=false, accepts_caller_manifest=false,
    accepts_caller_executor=false, registration_binds_capability_and_input=true,
    pre_and_post_dispatch_revalidation=true,
    result_is_recomputed_from_exact_rational_trace=true,
    dropout_sampling=:canonical_sha256_counter_first_60_bits,
    dropout_draw_denominator=_TECFE_DROPOUT_DRAW_DENOMINATOR,
    dropout_decision=:window_active_and_draw_strictly_below_probability,
    statistical_validation=false,
    operational_status=:operational_screen, claim_ceiling=screen_only,
    credible_device_count=0, emits_evidence=false,
    engineering_evidence=false, physical_evidence=false,
    validation_evidence=false, promotion_authority=false,
    p5_authority=false, terminal_authority=false)
