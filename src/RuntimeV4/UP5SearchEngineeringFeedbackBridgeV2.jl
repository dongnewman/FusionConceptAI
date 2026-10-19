"""Isolated UP5 bridge V2: bind Search registry metadata to its validated context.

Load after `UP5SearchEngineeringFeedbackBridgeV1.jl` in an isolated RuntimeV4
composition. This is not included by `FusionRuntimeV4.jl`. V2 adds one
fail-closed provenance join before delegating to V1: the Search entry's registry
hash must equal the registry hash in the validated ForwardChainContextV4.
The consumer result keeps V1's screen-only/no-credit ceiling.
"""

import FusionConceptAI: Digest256, canonical_hash, semantic_view

const UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V2 =
    "UP5-SEARCH-ENGINEERING-FEEDBACK-BRIDGE-V2-R1"
const _UP5_SEFB_V2_TOKEN = Ref{Nothing}(nothing)
const _UP5_SEFB_V2_BINDING_STATUSES = (:exact, :mismatch)

function _up5_sefb_v2_registry_binding_body(revision, status, entry_ref,
        context_hash, candidate_hash, scenario_hash, g3_hash,
        queue_registry_hash, context_registry_hash)
    (schema="fusionconceptai:up5-search-engineering-registry-binding-v2",
        revision=revision, status=status, entry_ref=entry_ref,
        context_hash=context_hash, candidate_hash=candidate_hash,
        scenario_hash=scenario_hash, g3_hash=g3_hash,
        queue_registry_hash=queue_registry_hash,
        context_registry_hash=context_registry_hash)
end

"""A digest-bound proof that the queue and validated context name one registry."""
struct SearchEngineeringRegistryBindingV2
    revision::String
    status::Symbol
    entry_ref::Digest256
    context_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    queue_registry_hash::Digest256
    context_registry_hash::Digest256
    binding_hash::Digest256

    function SearchEngineeringRegistryBindingV2(token::Base.RefValue{Nothing},
            revision::String, status::Symbol, entry_ref::Digest256,
            context_hash::Digest256, candidate_hash::Digest256,
            scenario_hash::Digest256, g3_hash::Digest256,
            queue_registry_hash::Digest256, context_registry_hash::Digest256,
            binding_hash::Digest256)
        token === _UP5_SEFB_V2_TOKEN ||
            throw(ArgumentError("private UP5 registry-binding constructor"))
        revision == UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V2 ||
            throw(ArgumentError("UP5 registry-binding revision mismatch"))
        status in _UP5_SEFB_V2_BINDING_STATUSES ||
            throw(ArgumentError("invalid UP5 registry-binding status"))
        (status === :exact) == (queue_registry_hash == context_registry_hash) ||
            throw(ArgumentError("UP5 registry-binding status/hash mismatch"))
        body = _up5_sefb_v2_registry_binding_body(revision, status,
            entry_ref, context_hash, candidate_hash, scenario_hash, g3_hash,
            queue_registry_hash, context_registry_hash)
        canonical_hash(body) == binding_hash ||
            throw(ArgumentError("UP5 registry-binding hash mismatch"))
        new(revision, status, entry_ref, context_hash, candidate_hash,
            scenario_hash, g3_hash, queue_registry_hash,
            context_registry_hash, binding_hash)
    end
end

semantic_view(x::SearchEngineeringRegistryBindingV2) = merge(
    _up5_sefb_v2_registry_binding_body(x.revision, x.status, x.entry_ref,
        x.context_hash, x.candidate_hash, x.scenario_hash, x.g3_hash,
        x.queue_registry_hash, x.context_registry_hash),
    (binding_hash=x.binding_hash,))

canonical_hash(x::SearchEngineeringRegistryBindingV2) = begin
    body = _up5_sefb_v2_registry_binding_body(x.revision, x.status,
        x.entry_ref, x.context_hash, x.candidate_hash, x.scenario_hash,
        x.g3_hash, x.queue_registry_hash, x.context_registry_hash)
    expected = canonical_hash(body)
    expected == x.binding_hash ||
        throw(ArgumentError("UP5 registry-binding hash mismatch"))
    (x.status === :exact) ==
        (x.queue_registry_hash == x.context_registry_hash) ||
        throw(ArgumentError("UP5 registry-binding status/hash mismatch"))
    expected
end

function _up5_sefb_registry_binding_v2(entry::CandidateQueueEntryV4,
        context::ForwardChainContextV4, validated_context_hash::Digest256)
    context_hash = validate_forward_chain_context(context)
    context_hash == validated_context_hash ||
        throw(ArgumentError("validated forward context changed"))
    entry.candidate_ref == entry.compiled.prefix_hash ||
        throw(ArgumentError("Search entry ref does not bind its compiled prefix"))
    entry.compiled.prefix_hash == context.compiled.prefix_hash ||
        throw(ArgumentError("Search entry and forward context prefixes differ"))
    candidate_hash = _forward_candidate_identity(context.candidate)
    _forward_candidate_identity(entry.candidate) == candidate_hash ||
        throw(ArgumentError("Search entry and forward context candidates differ"))
    entry.candidate.canonical_hashes == context.candidate.canonical_hashes ||
        throw(ArgumentError("Search entry and forward context Genome bundles differ"))
    context.candidate_hash == candidate_hash ||
        throw(ArgumentError("forward context candidate identity is stale"))
    context.registry_hash == canonical_hash(context.registry) ||
        throw(ArgumentError("forward context registry identity is stale"))
    scenario_hash = canonical_hash(context.scenario)
    g3_hash = canonical_hash(context.candidate.realization_control_genome_ref)
    status = entry.registry_hash == context.registry_hash ? :exact : :mismatch
    body = _up5_sefb_v2_registry_binding_body(
        UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V2, status,
        entry.candidate_ref, context_hash, candidate_hash, scenario_hash,
        g3_hash, entry.registry_hash, context.registry_hash)
    SearchEngineeringRegistryBindingV2(_UP5_SEFB_V2_TOKEN,
        UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V2, status,
        entry.candidate_ref, context_hash, candidate_hash, scenario_hash,
        g3_hash, entry.registry_hash, context.registry_hash,
        canonical_hash(body))
end

"""Validate the metadata join without changing queue state or running an evaluator.

This pure helper is useful for static/contract checks. It deliberately accepts
deferred entries so registry provenance can be checked before compiler/provider
eligibility exists; it does not promote an entry or imply evaluator readiness.
"""
function search_engineering_registry_binding_v2(
        entry::CandidateQueueEntryV4, context::ForwardChainContextV4)
    context_hash = validate_forward_chain_context(context)
    _up5_sefb_registry_binding_v2(entry, context, context_hash)
end

function _up5_sefb_v2_active_preflight(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        request::EngineeringFeedbackExecutionRequestV1)
    current = get(queue.entries, entry_ref, nothing)
    current isa CandidateQueueEntryV4 && current.status === :active ||
        return nothing
    request_pin = _up5_sefb_digest_v1(request, "request")
    request_pin.error === nothing || return nothing
    context_hash = try
        validate_forward_chain_context(context)
    catch
        return nothing
    end
    identities = try
        candidate_hash = _forward_candidate_identity(context.candidate)
        queue_candidate_hash = _forward_candidate_identity(current.candidate)
        scenario_hash = canonical_hash(context.scenario)
        g3_hash = canonical_hash(context.candidate.realization_control_genome_ref)
        ready = current.candidate_ref == entry_ref &&
            current.compiled.prefix_hash == entry_ref &&
            context.compiled.prefix_hash == entry_ref &&
            current.compiled.prefix_hash == context.compiled.prefix_hash &&
            current.candidate.canonical_hashes == context.candidate.canonical_hashes &&
            queue_candidate_hash == candidate_hash &&
            context.candidate_hash == candidate_hash &&
            context.scenario_hash == scenario_hash &&
            request.candidate_hash == candidate_hash &&
            request.scenario_hash == scenario_hash &&
            request.g3_hash == g3_hash &&
            _up5_sefb_g3_present_v1(context.candidate)
        (ready=ready, candidate_hash=candidate_hash,
            scenario_hash=scenario_hash, g3_hash=g3_hash)
    catch
        return nothing
    end
    identities.ready || return nothing
    binding = try
        _up5_sefb_registry_binding_v2(current, context, context_hash)
    catch
        return nothing
    end
    (binding=binding, context_hash=context_hash,
        candidate_hash=identities.candidate_hash,
        scenario_hash=identities.scenario_hash, g3_hash=identities.g3_hash,
        request_pin=request_pin)
end

const _UP5_SEFB_V2_GATE_KEYS = (:energy, :thermal, :force, :material,
    :source_capacity, :current_capacity, :cooling_capacity, :temperature,
    :yield_strength, :clearance)
const _UP5_SEFB_V2_UNKNOWN_GATES = NamedTuple{_UP5_SEFB_V2_GATE_KEYS}(
    ntuple(_ -> :unknown, length(_UP5_SEFB_V2_GATE_KEYS)))

"""A search proposal target, never an applied Genome edit or physical claim."""
struct SearchEngineeringEditTargetV2
    genome_role::Symbol
    facet::Symbol
    trigger::Symbol
    applicability::Symbol

    function SearchEngineeringEditTargetV2(genome_role, facet, trigger)
        genome_role in (:G2, :G3) || throw(ArgumentError("unsupported Genome edit target"))
        new(genome_role, facet, trigger, :requires_typed_model_binding)
    end
end
semantic_view(x::SearchEngineeringEditTargetV2) = (genome_role=x.genome_role,
    facet=x.facet, trigger=x.trigger, applicability=x.applicability)

"""Digest-bound UP4-02B observations for search; absent component loads stay unknown."""
struct SearchEngineeringSignalV2
    candidate_hash::Union{Nothing,Digest256}
    scenario_hash::Union{Nothing,Digest256}
    g3_hash::Union{Nothing,Digest256}
    observation_status::Symbol
    failure_class::Symbol
    failure_codes::Tuple{Vararg{Symbol}}
    gate_states::NamedTuple
    thermal_bottleneck::Symbol
    supply_bottleneck::Symbol
    component_load_status::Symbol
    edit_targets::Tuple{Vararg{SearchEngineeringEditTargetV2}}
    source_output_hash::Union{Nothing,Digest256}
    signal_hash::Digest256

    function SearchEngineeringSignalV2(candidate_hash, scenario_hash, g3_hash,
            observation_status, failure_class, failure_codes, gate_states,
            thermal_bottleneck, supply_bottleneck, component_load_status,
            edit_targets, source_output_hash, signal_hash)
        observation_status in (:reduced_si_screen, :unknown) ||
            throw(ArgumentError("invalid engineering observation status"))
        component_load_status === :unknown ||
            throw(ArgumentError("component load cannot be inferred by UP4-02B"))
        keys(gate_states) == _UP5_SEFB_V2_GATE_KEYS ||
            throw(ArgumentError("engineering gate shape mismatch"))
        all(x -> x in (:pass, :violated, :unknown), values(gate_states)) ||
            throw(ArgumentError("invalid engineering gate state"))
        if observation_status === :unknown
            gate_states == _UP5_SEFB_V2_UNKNOWN_GATES &&
                thermal_bottleneck === :unknown && supply_bottleneck === :unknown &&
                isempty(edit_targets) && source_output_hash === nothing ||
                throw(ArgumentError("missing engineering data cannot imply a bottleneck or edit"))
        else
            source_output_hash isa Digest256 ||
                throw(ArgumentError("observed engineering signal needs evaluator digest"))
        end
        body = _up5_sefb_v2_signal_body(candidate_hash, scenario_hash, g3_hash,
            observation_status, failure_class, failure_codes, gate_states,
            thermal_bottleneck, supply_bottleneck, component_load_status,
            edit_targets, source_output_hash)
        canonical_hash(body) == signal_hash ||
            throw(ArgumentError("engineering signal hash mismatch"))
        new(candidate_hash, scenario_hash, g3_hash, observation_status,
            failure_class, failure_codes, gate_states, thermal_bottleneck,
            supply_bottleneck, component_load_status, edit_targets,
            source_output_hash, signal_hash)
    end
end

function _up5_sefb_v2_signal_body(candidate_hash, scenario_hash, g3_hash,
        observation_status, failure_class, failure_codes, gate_states,
        thermal_bottleneck, supply_bottleneck, component_load_status,
        edit_targets, source_output_hash)
    (schema="fusionconceptai:up5-search-engineering-signal-v2",
        candidate_hash=candidate_hash, scenario_hash=scenario_hash,
        g3_hash=g3_hash, observation_status=observation_status,
        failure_class=failure_class, failure_codes=failure_codes,
        gate_states=gate_states, thermal_bottleneck=thermal_bottleneck,
        supply_bottleneck=supply_bottleneck,
        component_load_status=component_load_status,
        edit_targets=Tuple(semantic_view(x) for x in edit_targets),
        source_output_hash=source_output_hash)
end
semantic_view(x::SearchEngineeringSignalV2) = merge(
    _up5_sefb_v2_signal_body(x.candidate_hash, x.scenario_hash, x.g3_hash,
        x.observation_status, x.failure_class, x.failure_codes, x.gate_states,
        x.thermal_bottleneck, x.supply_bottleneck, x.component_load_status,
        x.edit_targets, x.source_output_hash), (signal_hash=x.signal_hash,))
canonical_hash(x::SearchEngineeringSignalV2) = begin
    body = _up5_sefb_v2_signal_body(x.candidate_hash, x.scenario_hash, x.g3_hash,
        x.observation_status, x.failure_class, x.failure_codes, x.gate_states,
        x.thermal_bottleneck, x.supply_bottleneck, x.component_load_status,
        x.edit_targets, x.source_output_hash)
    expected = canonical_hash(body)
    expected == x.signal_hash || throw(ArgumentError("engineering signal hash mismatch"))
    expected
end

function _up5_sefb_v2_signal(feedback::SearchEngineeringFeedbackRecordV1, result)
    result_pin = result isa EngineeringFeedbackExecutionV1 ?
        _up5_sefb_digest_v1(result, "evaluator-output") : nothing
    observed = result isa EngineeringFeedbackExecutionV1 &&
        result_pin.error === nothing &&
        feedback.output_digest_kind === :canonical &&
        feedback.output_digest == result_pin.digest &&
        feedback.evaluator_status == result.status &&
        feedback.candidate_hash == result.candidate_hash &&
        feedback.scenario_hash == result.scenario_hash &&
        feedback.g3_hash == result.g3_hash &&
        result.status in (:pass, :physical_fail) &&
        result.residuals.converged &&
        all(getproperty(result.hard_gates, k) for k in
            (:energy, :thermal, :force, :material)) &&
        !isempty(result.iteration_trace) &&
        feedback.route_status in (:screen_only, :failed)
    states = observed ? NamedTuple{_UP5_SEFB_V2_GATE_KEYS}(
        Tuple(getproperty(result.hard_gates, k) ? :pass : :violated
            for k in _UP5_SEFB_V2_GATE_KEYS)) : _UP5_SEFB_V2_UNKNOWN_GATES
    thermal = observed ? (!result.hard_gates.cooling_capacity &&
        !result.hard_gates.temperature ? :cooling_and_temperature :
        !result.hard_gates.cooling_capacity ? :cooling :
        !result.hard_gates.temperature ? :temperature : :none) : :unknown
    supply = observed ? (!result.hard_gates.source_capacity &&
        !result.hard_gates.current_capacity ? :source_and_current :
        !result.hard_gates.source_capacity ? :source :
        !result.hard_gates.current_capacity ? :current : :none) : :unknown
    targets = SearchEngineeringEditTargetV2[]
    if observed
        states.source_capacity === :violated && push!(targets,
            SearchEngineeringEditTargetV2(:G3, :source_network, :source_capacity))
        states.current_capacity === :violated && push!(targets,
            SearchEngineeringEditTargetV2(:G3, :control_current, :current_capacity))
        states.cooling_capacity === :violated && push!(targets,
            SearchEngineeringEditTargetV2(:G3, :cooling_path, :cooling_capacity))
        states.temperature === :violated && push!(targets,
            SearchEngineeringEditTargetV2(:G3, :thermal_management, :temperature))
        states.yield_strength === :violated && push!(targets,
            SearchEngineeringEditTargetV2(:G3, :material_selection, :yield_strength))
        states.clearance === :violated && push!(targets,
            SearchEngineeringEditTargetV2(:G2, :clearance_geometry, :clearance))
    end
    status = observed ? :reduced_si_screen : :unknown
    failure_class = feedback.evaluator_status === nothing ?
        (feedback.route_status === :deferred ? :deferred : :unknown) :
        feedback.evaluator_status
    codes = feedback.failure_codes
    source_hash = observed ? feedback.output_digest : nothing
    body = _up5_sefb_v2_signal_body(feedback.candidate_hash,
        feedback.scenario_hash, feedback.g3_hash, status, failure_class,
        codes, states, thermal, supply, :unknown, Tuple(targets), source_hash)
    SearchEngineeringSignalV2(feedback.candidate_hash,
        feedback.scenario_hash, feedback.g3_hash, status, failure_class,
        codes, states, thermal, supply, :unknown, Tuple(targets),
        source_hash, canonical_hash(body))
end

function _up5_sefb_v2_record_body(revision, registry_binding, feedback, signal)
    (schema="fusionconceptai:up5-search-engineering-feedback-bridge-record-v2",
        revision=revision, registry_binding=registry_binding,
        feedback_hash=canonical_hash(feedback), signal_hash=canonical_hash(signal))
end

"""Search/context registry join plus reduced-SI signals for proposal planning.

`signal.edit_targets` name typed model locations to inspect. They are never
applied mutations. The signal retains unknown component load and grants no
candidate, engineering, physical, or station-output credit.
"""
struct SearchEngineeringFeedbackRecordV2
    revision::String
    registry_binding::Union{Nothing,SearchEngineeringRegistryBindingV2}
    feedback::SearchEngineeringFeedbackRecordV1
    signal::SearchEngineeringSignalV2
    record_hash::Digest256

    function SearchEngineeringFeedbackRecordV2(token::Base.RefValue{Nothing},
            revision::String,
            registry_binding::Union{Nothing,SearchEngineeringRegistryBindingV2},
            feedback::SearchEngineeringFeedbackRecordV1,
            signal::SearchEngineeringSignalV2, record_hash::Digest256)
        token === _UP5_SEFB_V2_TOKEN ||
            throw(ArgumentError("private UP5 feedback envelope constructor"))
        revision == UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V2 ||
            throw(ArgumentError("UP5 feedback envelope revision mismatch"))
        canonical_hash(feedback)
        canonical_hash(signal)
        signal.candidate_hash == feedback.candidate_hash &&
            signal.scenario_hash == feedback.scenario_hash &&
            signal.g3_hash == feedback.g3_hash ||
            throw(ArgumentError("engineering signal identity mismatch"))
        if registry_binding !== nothing
            feedback.queue_entry_ref == registry_binding.entry_ref &&
                feedback.context_hash == registry_binding.context_hash &&
                feedback.candidate_hash == registry_binding.candidate_hash &&
                feedback.scenario_hash == registry_binding.scenario_hash &&
                feedback.g3_hash == registry_binding.g3_hash ||
                throw(ArgumentError("registry binding and feedback identities differ"))
        end
        if registry_binding !== nothing && registry_binding.status === :mismatch
            feedback.route_status === :deferred ||
                throw(ArgumentError("registry mismatch must defer Search feedback"))
            :queue_registry_context_mismatch in feedback.failure_codes ||
                throw(ArgumentError("registry mismatch failure code missing"))
            feedback.output_digest === nothing ||
                throw(ArgumentError("registry mismatch cannot retain evaluator output"))
        end
        body = _up5_sefb_v2_record_body(revision, registry_binding, feedback, signal)
        canonical_hash(body) == record_hash ||
            throw(ArgumentError("UP5 feedback envelope hash mismatch"))
        new(revision, registry_binding, feedback, signal, record_hash)
    end
end

semantic_view(x::SearchEngineeringFeedbackRecordV2) = merge(
    _up5_sefb_v2_record_body(x.revision, x.registry_binding, x.feedback, x.signal),
    (record_hash=x.record_hash,))

canonical_hash(x::SearchEngineeringFeedbackRecordV2) = begin
    canonical_hash(x.feedback)
    canonical_hash(x.signal)
    x.registry_binding === nothing || canonical_hash(x.registry_binding)
    expected = canonical_hash(_up5_sefb_v2_record_body(
        x.revision, x.registry_binding, x.feedback, x.signal))
    expected == x.record_hash ||
        throw(ArgumentError("UP5 feedback envelope hash mismatch"))
    expected
end

function _up5_sefb_v2_wrap(feedback::SearchEngineeringFeedbackRecordV1,
        registry_binding::Union{Nothing,SearchEngineeringRegistryBindingV2}, result=nothing)
    revision = UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V2
    signal = _up5_sefb_v2_signal(feedback, result)
    body = _up5_sefb_v2_record_body(revision, registry_binding, feedback, signal)
    SearchEngineeringFeedbackRecordV2(_UP5_SEFB_V2_TOKEN, revision,
        registry_binding, feedback, signal, canonical_hash(body))
end

"""Run the isolated V1 screen bridge only after an exact registry metadata join.

Ineligible or invalid contexts are delegated to V1's typed deferred path. If an
otherwise evaluator-ready active entry has a queue/context registry mismatch,
V2 records a typed deferred outcome before invoking the evaluator.
"""
function route_search_engineering_feedback_v2!(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        request::EngineeringFeedbackExecutionRequestV1;
        executor::Function=execute_engineering_feedback)
    preflight = _up5_sefb_v2_active_preflight(queue, entry_ref, context, request)
    if preflight === nothing
        captured = Ref{Any}(nothing)
        feedback = route_search_engineering_feedback!(queue, entry_ref,
            context, request; executor=req -> (captured[] = executor(req)))
        return _up5_sefb_v2_wrap(feedback, nothing, captured[])
    end

    binding = preflight.binding
    if binding.status === :mismatch
        feedback = _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            preflight.request_pin.digest, preflight.request_pin.kind;
            context_hash=preflight.context_hash,
            candidate_hash=preflight.candidate_hash,
            scenario_hash=preflight.scenario_hash,
            g3_hash=preflight.g3_hash,
            failure_codes=(:queue_registry_context_mismatch,))
        return _up5_sefb_v2_wrap(feedback, binding)
    end

    captured = Ref{Any}(nothing)
    feedback = route_search_engineering_feedback!(queue, entry_ref,
        context, request; executor=req -> (captured[] = executor(req)))
    _up5_sefb_v2_wrap(feedback, binding, captured[])
end
