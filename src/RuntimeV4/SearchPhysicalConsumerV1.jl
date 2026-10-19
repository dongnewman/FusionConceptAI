"""Isolated Search-to-FreeGS request/receipt adapter; not included by FusionRuntimeV4.

This adapter consumes only an already-active, complete Search entry and an
externally revalidated ForwardChainContextV4. Its only physical provider is the
repository-owned, typed FreeGS axisymmetric screen. It makes no G1/G3 solver,
engineering, discovery, or whole-device claim.
"""
module SearchPhysicalConsumerV1

using FusionConceptAI: Digest256, ClaimCeiling, screen_only, none
import FusionConceptAI: canonical_hash
using ..FusionRuntimeV4: CandidateQueueV4, ForwardChainContextV4,
    TrustedProviderRegistryV4, CapabilitySignatureV4,
    TrustedFreeGSAxisymmetricInputV4, TrustedProviderDispatchRequestV4,
    TrustedProviderExecutionReceiptV4, validate_forward_chain_context,
    _runtime_validate_compiled_prefix, validate_trusted_provider_registry,
    trusted_freegs_axisymmetric_capability,
    validate_trusted_freegs_axisymmetric_capability,
    make_trusted_freegs_axisymmetric_input,
    validate_trusted_freegs_axisymmetric_input,
    build_trusted_provider_dispatch_request,
    validate_trusted_provider_dispatch_request,
    execute_trusted_provider,
    validate_trusted_provider_execution_receipt

const _SPC_STATES = (:ready_for_dispatch, :deferred, :not_executed,
    :screen_only, :program_exception)
struct _SearchPhysicalConsumerToken end
const _SPC_TOKEN = _SearchPhysicalConsumerToken()

struct SearchPhysicalConsumerReceiptV1
    state::Symbol
    queue_entry_ref::Digest256
    queue_status::Union{Nothing,Symbol}
    search_registry_hash::Union{Nothing,Digest256}
    candidate_hash::Digest256
    genome_bundle_hash::Digest256
    g1_hash::Digest256
    g2_hash::Digest256
    g3_hash::Digest256
    prefix_hash::Digest256
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    trusted_registry_hash::Digest256
    capability_hash::Union{Nothing,Digest256}
    input_hash::Union{Nothing,Digest256}
    request_hash::Union{Nothing,Digest256}
    provider_status::Union{Nothing,Symbol}
    trusted_receipt_hash::Union{Nothing,Digest256}
    output_hash::Union{Nothing,Digest256}
    gaps::Tuple{Vararg{String}}
    failure_code::Union{Nothing,Symbol}
    failure_type::String
    failure_message::String
    capability::Union{Nothing,CapabilitySignatureV4}
    input::Union{Nothing,TrustedFreeGSAxisymmetricInputV4}
    request::Union{Nothing,TrustedProviderDispatchRequestV4}
    trusted_receipt::Union{Nothing,TrustedProviderExecutionReceiptV4}
    claim_ceiling::ClaimCeiling
    physical_validation::Bool
    engineering_validation::Bool
    p5_ready::Bool
    terminal_authority::Bool
    candidate_discovery_credit::Int
    credible_device_count::Int
    record_hash::Digest256
    function SearchPhysicalConsumerReceiptV1(token::_SearchPhysicalConsumerToken,
            state::Symbol, queue_entry_ref::Digest256, queue_status,
            search_registry_hash, candidate_hash::Digest256,
            genome_bundle_hash::Digest256, g1_hash::Digest256,
            g2_hash::Digest256, g3_hash::Digest256, prefix_hash::Digest256,
            context_hash::Digest256, subject_hash::Digest256,
            scenario_hash::Digest256, trusted_registry_hash::Digest256,
            capability_hash, input_hash, request_hash, provider_status,
            trusted_receipt_hash, output_hash, gaps, failure_code,
            failure_type::String, failure_message::String, capability, input,
            request, trusted_receipt, claim_ceiling::ClaimCeiling,
            physical_validation::Bool, engineering_validation::Bool,
            p5_ready::Bool, terminal_authority::Bool,
            candidate_discovery_credit::Int, credible_device_count::Int,
            record_hash::Digest256)
        token === _SPC_TOKEN || throw(ArgumentError("private constructor"))
        state in _SPC_STATES || throw(ArgumentError("invalid consumer state"))
        new(state, queue_entry_ref, queue_status, search_registry_hash,
            candidate_hash, genome_bundle_hash, g1_hash, g2_hash, g3_hash,
            prefix_hash, context_hash, subject_hash, scenario_hash,
            trusted_registry_hash, capability_hash, input_hash, request_hash,
            provider_status, trusted_receipt_hash, output_hash, gaps,
            failure_code, failure_type, failure_message, capability, input,
            request, trusted_receipt, claim_ceiling, physical_validation,
            engineering_validation, p5_ready, terminal_authority,
            candidate_discovery_credit, credible_device_count, record_hash)
    end
end

function _spc_body(state, queue_entry_ref, queue_status, search_registry_hash,
        candidate_hash, genome_bundle_hash, g1_hash, g2_hash, g3_hash,
        prefix_hash, context_hash, subject_hash, scenario_hash,
        trusted_registry_hash, capability_hash, input_hash, request_hash,
        provider_status, trusted_receipt_hash, output_hash, gaps, failure_code,
        failure_type, failure_message, claim_ceiling, physical_validation,
        engineering_validation, p5_ready, terminal_authority,
        candidate_discovery_credit, credible_device_count)
    (schema="fusionconceptai:runtime-v4-search-physical-consumer-receipt",
     revision="search-physical-consumer-v1", state=state,
     queue_entry_ref=queue_entry_ref, queue_status=queue_status,
     search_registry_hash=search_registry_hash, candidate_hash=candidate_hash,
     genome_bundle_hash=genome_bundle_hash, g1_hash=g1_hash, g2_hash=g2_hash,
     g3_hash=g3_hash, prefix_hash=prefix_hash, context_hash=context_hash,
     subject_hash=subject_hash, scenario_hash=scenario_hash,
     trusted_registry_hash=trusted_registry_hash,
     capability_hash=capability_hash, input_hash=input_hash,
     request_hash=request_hash, provider_status=provider_status,
     trusted_receipt_hash=trusted_receipt_hash, output_hash=output_hash,
     gaps=gaps, failure_code=failure_code, failure_type=failure_type,
     failure_message=failure_message, claim_ceiling=claim_ceiling,
     physical_validation=physical_validation,
     engineering_validation=engineering_validation, p5_ready=p5_ready,
     terminal_authority=terminal_authority,
     candidate_discovery_credit=candidate_discovery_credit,
     credible_device_count=credible_device_count)
end

function _spc_make_record(queue::CandidateQueueV4, entry_ref::Digest256,
        context::ForwardChainContextV4, registry::TrustedProviderRegistryV4;
        state::Symbol, gaps=(), failure_code=nothing, failure_type="",
        failure_message="", capability=nothing, input=nothing, request=nothing,
        trusted_receipt=nothing)
    entry = get(queue.entries, entry_ref, nothing)
    queue_status = entry === nothing ? nothing : entry.status
    search_registry_hash = entry === nothing ? nothing : entry.registry_hash
    bindings = context.genome_bindings
    capability_hash = capability === nothing ? nothing : canonical_hash(capability)
    input_hash = input === nothing ? nothing : canonical_hash(input)
    request_hash = request === nothing ? nothing : request.request_hash
    provider_status = trusted_receipt === nothing ?
        (request === nothing ? nothing : request.status) : trusted_receipt.status
    trusted_receipt_hash = trusted_receipt === nothing ? nothing : trusted_receipt.receipt_hash
    output_hash = trusted_receipt === nothing ? nothing : trusted_receipt.output_hash
    gap_tuple = Tuple(String(x) for x in gaps)
    ceiling = state === :screen_only ? screen_only : none
    body = _spc_body(state, entry_ref, queue_status, search_registry_hash,
        context.candidate_hash, context.candidate.canonical_hashes.genome_bundle_hash,
        bindings[1].genome_hash, bindings[2].genome_hash, bindings[3].genome_hash,
        context.compiled.prefix_hash, context.context_hash,
        context.subject.physical_subject_hash, context.scenario_hash,
        registry.registry_hash, capability_hash, input_hash, request_hash,
        provider_status, trusted_receipt_hash, output_hash, gap_tuple,
        failure_code, String(failure_type), String(failure_message), ceiling,
        false, false, false, false, 0, 0)
    record = SearchPhysicalConsumerReceiptV1(_SPC_TOKEN, state, entry_ref,
        queue_status, search_registry_hash, context.candidate_hash,
        context.candidate.canonical_hashes.genome_bundle_hash,
        bindings[1].genome_hash, bindings[2].genome_hash, bindings[3].genome_hash,
        context.compiled.prefix_hash, context.context_hash,
        context.subject.physical_subject_hash, context.scenario_hash,
        registry.registry_hash, capability_hash, input_hash, request_hash,
        provider_status, trusted_receipt_hash, output_hash, gap_tuple,
        failure_code, String(failure_type), String(failure_message), capability,
        input, request, trusted_receipt, ceiling, false, false, false, false, 0,
        0, canonical_hash(body))
    canonical_hash(record)
    record
end

function canonical_hash(x::SearchPhysicalConsumerReceiptV1)
    x.state in _SPC_STATES || throw(ArgumentError("invalid consumer state"))
    x.claim_ceiling == (x.state === :screen_only ? screen_only : none) ||
        throw(ArgumentError("consumer claim ceiling exceeds state"))
    !x.physical_validation && !x.engineering_validation && !x.p5_ready &&
        !x.terminal_authority && x.candidate_discovery_credit == 0 &&
        x.credible_device_count == 0 ||
        throw(ArgumentError("consumer receipt exceeds screen-only authority"))
    if x.request === nothing
        x.request_hash === nothing && x.input === nothing &&
            x.capability === nothing && x.trusted_receipt === nothing ||
            throw(ArgumentError("consumer receipt has detached dispatch data"))
    else
        x.request_hash == x.request.request_hash && x.input !== nothing &&
            x.capability !== nothing ||
            throw(ArgumentError("consumer request identity mismatch"))
        x.input_hash == x.request.input_hash ||
            throw(ArgumentError("consumer input hash mismatch"))
        canonical_hash(x.capability) == x.capability_hash ||
            throw(ArgumentError("consumer capability hash mismatch"))
        canonical_hash(x.input) == x.input_hash ||
            throw(ArgumentError("consumer input hash mismatch"))
    end
    if x.trusted_receipt === nothing
        x.trusted_receipt_hash === nothing && x.output_hash === nothing ||
            throw(ArgumentError("consumer receipt has detached provider output"))
        x.state === :screen_only && throw(ArgumentError("screen-only state lacks execution receipt"))
    else
        x.request === nothing && throw(ArgumentError("provider receipt lacks request"))
        x.trusted_receipt_hash == x.trusted_receipt.receipt_hash &&
            x.output_hash == x.trusted_receipt.output_hash ||
            throw(ArgumentError("trusted receipt/output hash mismatch"))
        expected_state = x.trusted_receipt.status === :physical_model_screen &&
            x.trusted_receipt.exit_code == 0 ? :screen_only :
            x.trusted_receipt.status === :executor_error ? :program_exception : :deferred
        (x.state == expected_state ||
            (x.failure_code === :trusted_receipt_invalid &&
             x.state === :program_exception)) ||
            throw(ArgumentError("consumer state does not match trusted execution status"))
        x.claim_ceiling == (x.state === :screen_only ? screen_only : none) ||
            throw(ArgumentError("consumer result ceiling mismatch"))
        x.provider_status == x.trusted_receipt.status ||
            throw(ArgumentError("consumer provider status mismatch"))
    end
    body = _spc_body(x.state, x.queue_entry_ref, x.queue_status,
        x.search_registry_hash, x.candidate_hash, x.genome_bundle_hash,
        x.g1_hash, x.g2_hash, x.g3_hash, x.prefix_hash, x.context_hash,
        x.subject_hash, x.scenario_hash, x.trusted_registry_hash,
        x.capability_hash, x.input_hash, x.request_hash, x.provider_status,
        x.trusted_receipt_hash, x.output_hash, x.gaps, x.failure_code,
        x.failure_type, x.failure_message, x.claim_ceiling,
        x.physical_validation, x.engineering_validation, x.p5_ready,
        x.terminal_authority, x.candidate_discovery_credit,
        x.credible_device_count)
    h = canonical_hash(body)
    h == x.record_hash || throw(ArgumentError("consumer record hash mismatch"))
    h
end

semantic_view(x::SearchPhysicalConsumerReceiptV1) = (
    state=x.state, queue_entry_ref=x.queue_entry_ref,
    queue_status=x.queue_status,
    search_registry_hash=x.search_registry_hash,
    candidate_hash=x.candidate_hash, genome_bundle_hash=x.genome_bundle_hash,
    g1_hash=x.g1_hash, g2_hash=x.g2_hash, g3_hash=x.g3_hash,
    prefix_hash=x.prefix_hash, context_hash=x.context_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    trusted_registry_hash=x.trusted_registry_hash,
    capability_hash=x.capability_hash, input_hash=x.input_hash,
    request_hash=x.request_hash, provider_status=x.provider_status,
    trusted_receipt_hash=x.trusted_receipt_hash, output_hash=x.output_hash,
    gaps=x.gaps, failure_code=x.failure_code, failure_type=x.failure_type,
    failure_message=x.failure_message, claim_ceiling=x.claim_ceiling,
    physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation, p5_ready=x.p5_ready,
    terminal_authority=x.terminal_authority,
    candidate_discovery_credit=x.candidate_discovery_credit,
    credible_device_count=x.credible_device_count, record_hash=x.record_hash)

function _spc_preflight_gap(queue, entry_ref, context)
    entry = get(queue.entries, entry_ref, nothing)
    entry === nothing && return (:not_executed, :search_entry_missing,
        ("search_entry_missing",))
    entry.status === :active || return (:deferred, :search_entry_not_active,
        ("search_entry_not_active",))
    entry.candidate_ref == entry_ref && entry.compiled.prefix_hash == entry_ref ||
        return (:not_executed, :queue_prefix_identity_mismatch,
            ("queue_prefix_identity_mismatch",))
    entry.compiled.compilation_status === :prefix_consistent &&
        isempty(entry.compiled.unresolved_nonterminals) ||
        return (:deferred, :compiler_obligations_unresolved,
            Tuple(String(x) for x in entry.compiled.unresolved_nonterminals))
    context.compiled.prefix_hash == entry_ref &&
        context.candidate.canonical_hashes == entry.candidate.canonical_hashes &&
        context.compiled.candidate.canonical_hashes == entry.candidate.canonical_hashes ||
        return (:not_executed, :search_context_candidate_or_prefix_mismatch,
            ("search_context_candidate_or_prefix_mismatch",))
    context.registry_hash == entry.registry_hash &&
        context.registry_hash == canonical_hash(context.registry) ||
        return (:not_executed, :search_registry_identity_mismatch,
            ("search_registry_identity_mismatch",))
    roles = Tuple(x.role for x in context.genome_bindings)
    roles == (:mechanism, :field_geometry, :realization_control) ||
        return (:not_executed, :genome_binding_roles_invalid,
            ("genome_binding_roles_invalid",))
    hashes = Tuple(x.genome_hash for x in context.genome_bindings)
    hashes == (canonical_hash(context.candidate.mechanism_genome_ref),
        canonical_hash(context.candidate.field_geometry_genome_ref),
        canonical_hash(context.candidate.realization_control_genome_ref)) ||
        return (:not_executed, :genome_binding_identity_mismatch,
            ("genome_binding_identity_mismatch",))
    _runtime_validate_compiled_prefix(entry.compiled, entry.candidate,
        context.registry, context.mission_payload, context.bounds_payload,
        context.comparison_scope, context.scenario_scope)
    nothing
end

"""Build an exact FreeGS dispatch request without invoking the solver."""
function prepare_search_physical_consumer(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4)
    try
        validate_forward_chain_context(context)
        gate = _spc_preflight_gap(queue, entry_ref, context)
        gate === nothing || return _spc_make_record(queue, entry_ref, context,
            registry; state=gate[1], failure_code=gate[2], gaps=gate[3])
        validate_trusted_provider_registry(registry)
        capability = trusted_freegs_axisymmetric_capability(context)
        validate_trusted_freegs_axisymmetric_capability(capability, context)
        input = make_trusted_freegs_axisymmetric_input(context, capability)
        validate_trusted_freegs_axisymmetric_input(input, context, capability)
        request = build_trusted_provider_dispatch_request(registry, context,
            capability, input)
        if request.status !== :ready_for_dispatch
            return _spc_make_record(queue, entry_ref, context, registry;
                state=:deferred, gaps=request.recoverable_gaps,
                failure_code=:trusted_provider_registration_unavailable,
                capability=capability, input=input, request=request)
        end
        validate_trusted_provider_dispatch_request(request, registry, context,
            capability, input) || return _spc_make_record(queue, entry_ref,
                context, registry; state=:not_executed,
                gaps=("trusted_dispatch_request_revalidation_failed",),
                failure_code=:trusted_dispatch_request_revalidation_failed,
                capability=capability, input=input, request=request)
        _spc_make_record(queue, entry_ref, context, registry;
            state=:ready_for_dispatch, capability=capability, input=input,
            request=request)
    catch error
        _spc_make_record(queue, entry_ref, context, registry;
            state=:program_exception, failure_code=:preflight_exception,
            failure_type=string(typeof(error)),
            failure_message=sprint(showerror, error))
    end
end

function _spc_post_execution_state(receipt::TrustedProviderExecutionReceiptV4)
    receipt.status === :physical_model_screen && receipt.exit_code == 0 &&
        return (:screen_only, nothing)
    receipt.status === :executor_error && return (:program_exception, :trusted_executor_error)
    (:deferred, :trusted_provider_result_not_screen_only)
end

"""Execute the repository-owned FreeGS consumer after fail-closed preparation.

No executor callback is accepted. Any accepted execution is still `screen_only`;
queue status is not changed and no search/discovery or engineering credit is
issued.
"""
function execute_search_physical_consumer!(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4)
    prepared = prepare_search_physical_consumer(queue, entry_ref, context, registry)
    prepared.state === :ready_for_dispatch || return prepared
    request = prepared.request::TrustedProviderDispatchRequestV4
    receipt = try
        execute_trusted_provider(registry, context, request)
    catch error
        return _spc_make_record(queue, entry_ref, context, registry;
            state=:program_exception, failure_code=:trusted_dispatch_exception,
            failure_type=string(typeof(error)),
            failure_message=sprint(showerror, error),
            capability=prepared.capability, input=prepared.input,
            request=request)
    end
    if !validate_trusted_provider_execution_receipt(receipt, request,
            registry, context)
        return _spc_make_record(queue, entry_ref, context, registry;
            state=:program_exception, failure_code=:trusted_receipt_invalid,
            gaps=("trusted_execution_receipt_failed_revalidation",),
            capability=prepared.capability, input=prepared.input,
            request=request, trusted_receipt=receipt)
    end
    state, failure_code = _spc_post_execution_state(receipt)
    _spc_make_record(queue, entry_ref, context, registry; state=state,
        failure_code=failure_code, capability=prepared.capability,
        input=prepared.input, request=request, trusted_receipt=receipt)
end

"""Revalidate an immutable consumer record against its current queue/context/registry."""
function validate_search_physical_consumer_receipt(
        record::SearchPhysicalConsumerReceiptV1, queue::CandidateQueueV4,
        context::ForwardChainContextV4, registry::TrustedProviderRegistryV4)
    try
        canonical_hash(record)
        validate_forward_chain_context(context)
        validate_trusted_provider_registry(registry)
        entry = get(queue.entries, record.queue_entry_ref, nothing)
        entry === nothing && return false
        entry.status == record.queue_status || return false
        record.state in (:ready_for_dispatch, :screen_only) &&
            record.queue_status !== :active && return false
        entry.candidate_ref == record.queue_entry_ref &&
            entry.compiled.prefix_hash == record.prefix_hash == context.compiled.prefix_hash &&
            entry.registry_hash == record.search_registry_hash &&
            entry.candidate.canonical_hashes == context.candidate.canonical_hashes &&
            context.context_hash == record.context_hash &&
            context.subject.physical_subject_hash == record.subject_hash &&
            context.scenario_hash == record.scenario_hash &&
            registry.registry_hash == record.trusted_registry_hash || return false
        _runtime_validate_compiled_prefix(entry.compiled, entry.candidate,
            context.registry, context.mission_payload, context.bounds_payload,
            context.comparison_scope, context.scenario_scope)
        record.candidate_hash == context.candidate_hash &&
            record.genome_bundle_hash == context.candidate.canonical_hashes.genome_bundle_hash ||
            return false
        Tuple(x.genome_hash for x in context.genome_bindings) ==
            (record.g1_hash, record.g2_hash, record.g3_hash) || return false
        if record.request === nothing
            return record.trusted_receipt === nothing &&
                record.state in (:deferred, :not_executed, :program_exception)
        end
        record.capability !== nothing && record.input !== nothing || return false
        validate_trusted_freegs_axisymmetric_capability(record.capability,
            context) == record.capability_hash || return false
        validate_trusted_freegs_axisymmetric_input(record.input, context,
            record.capability) == record.input_hash || return false
        validate_trusted_provider_dispatch_request(record.request, registry,
            context, record.capability, record.input) || return false
        record.request.request_hash == record.request_hash || return false
        if record.trusted_receipt === nothing
            return record.state in (:ready_for_dispatch, :deferred,
                :not_executed, :program_exception)
        end
        validate_trusted_provider_execution_receipt(record.trusted_receipt,
            record.request, registry, context) || return false
        record.trusted_receipt.receipt_hash == record.trusted_receipt_hash &&
            record.trusted_receipt.output_hash == record.output_hash
    catch
        false
    end
end

end # module SearchPhysicalConsumerV1
