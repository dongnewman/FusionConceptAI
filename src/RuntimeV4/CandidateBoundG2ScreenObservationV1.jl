"""Candidate-bound FreeGS screen observation with explicit edge deferral.

This module is intentionally not included by `FusionRuntimeV4.jl`. It uses the
repository-trusted FreeGS dispatcher to make one G2 screen observation for an
already validated `ForwardChainContextV4`. The observation is bound to the
candidate/context/scenario and exact axisymmetric binding, but it is not an
edge receipt and it never activates Search. All typed graph edge obligations
remain unresolved in the returned record, including the separate G1 IDENTITY
edges. The public entry accepts no caller-supplied capability, input, request,
executor, or receipt.
"""
module CandidateBoundG2ScreenObservationV1

using FusionConceptAI: Digest256, ClaimCeiling, screen_only, none
import FusionConceptAI: canonical_hash, semantic_view

using ..FusionRuntimeV4: ForwardChainContextV4, CapabilitySignatureV4,
    TrustedProviderRegistryV4, TrustedProviderDispatchRequestV4,
    TrustedProviderExecutionReceiptV4,
    TrustedFreeGSAxisymmetricInputV4,
    validate_forward_chain_context, validate_trusted_provider_registry,
    trusted_freegs_axisymmetric_capability,
    validate_trusted_freegs_axisymmetric_capability,
    make_trusted_freegs_axisymmetric_input,
    validate_trusted_freegs_axisymmetric_input,
    build_trusted_provider_dispatch_request,
    validate_trusted_provider_dispatch_request,
    execute_trusted_provider,
    validate_trusted_provider_execution_receipt,
    _freegs_context_binding
import ..PhysicalEdgeObligationV1Compat: PhysicalEdgeObligationV1,
    physical_edge_obligations_v1, validate_obligation_set_v1

export G2ScreenObservationV1, observe_candidate_bound_g2_screen_v1,
    validate_candidate_bound_g2_screen_observation_v1

const _G2OBS_STATES = (:screen_only, :deferred, :program_exception)
const _G2OBS_ISSUE_LOCK = ReentrantLock()
const _G2OBS_EXECUTION_LOCK = ReentrantLock()

mutable struct _G2OBS_IssueTicket
    nonce::UInt64
end

const _G2OBS_ISSUE_COUNTER = Ref{UInt64}(0)
const _G2OBS_ISSUED = IdDict{_G2OBS_IssueTicket,Tuple{UInt64,Digest256}}()

function _g2obs_ticket()
    lock(_G2OBS_ISSUE_LOCK) do
        _G2OBS_ISSUE_COUNTER[] += UInt64(1)
        _G2OBS_IssueTicket(_G2OBS_ISSUE_COUNTER[])
    end
end

function _g2obs_body(candidate_hash, genome_bundle_hash, subject_hash,
        context_hash, scenario_hash, registry_hash, provider_descriptor_hash,
        provider_manifest_hash, provider_source_hash, provider_runtime_hash,
        provider_attested_source_paths, provider_attested_source_hashes,
        binding_hash, declaration_hash, obligation_inventory_hash, obligation_hashes,
        unresolved_obligation_hashes, unresolved_g1_identity_hashes,
        capability_hash, input_hash, request_hash, receipt_hash, output_hash,
        provider_status, exit_code, execution_started, status, failure_stage,
        failure_code, failure_type, failure_message, claim_ceiling,
        search_activation, physical_validation, engineering_validation,
        candidate_discovery_credit, credible_device_count)
    (schema="fusionconceptai:up5-candidate-bound-g2-screen-observation-v1",
     revision="candidate-bound-g2-screen-observation-v1",
     candidate_hash=candidate_hash, genome_bundle_hash=genome_bundle_hash,
     subject_hash=subject_hash, context_hash=context_hash,
     scenario_hash=scenario_hash, registry_hash=registry_hash,
     provider_descriptor_hash=provider_descriptor_hash,
     provider_manifest_hash=provider_manifest_hash,
     provider_source_hash=provider_source_hash,
     provider_runtime_hash=provider_runtime_hash,
     provider_attested_source_paths=provider_attested_source_paths,
     provider_attested_source_hashes=provider_attested_source_hashes,
     binding_hash=binding_hash, declaration_hash=declaration_hash,
     obligation_inventory_hash=obligation_inventory_hash,
     obligation_hashes=obligation_hashes,
     unresolved_obligation_hashes=unresolved_obligation_hashes,
     unresolved_g1_identity_hashes=unresolved_g1_identity_hashes,
     capability_hash=capability_hash, input_hash=input_hash,
     request_hash=request_hash, receipt_hash=receipt_hash,
     output_hash=output_hash, provider_status=provider_status,
     exit_code=exit_code, execution_started=execution_started,
     status=status, failure_stage=failure_stage, failure_code=failure_code,
     failure_type=failure_type, failure_message=failure_message,
     claim_ceiling=claim_ceiling, search_activation=search_activation,
     physical_validation=physical_validation,
     engineering_validation=engineering_validation,
     candidate_discovery_credit=candidate_discovery_credit,
     credible_device_count=credible_device_count)
end

"""One in-process receipt observation; never a Search or edge-resolution result."""
struct G2ScreenObservationV1
    _ticket::_G2OBS_IssueTicket
    candidate_hash::Union{Nothing,Digest256}
    genome_bundle_hash::Union{Nothing,Digest256}
    subject_hash::Union{Nothing,Digest256}
    context_hash::Union{Nothing,Digest256}
    scenario_hash::Union{Nothing,Digest256}
    registry_hash::Union{Nothing,Digest256}
    provider_descriptor_hash::Union{Nothing,Digest256}
    provider_manifest_hash::Union{Nothing,Digest256}
    provider_source_hash::Union{Nothing,Digest256}
    provider_runtime_hash::Union{Nothing,Digest256}
    provider_attested_source_paths::Tuple{Vararg{String}}
    provider_attested_source_hashes::Tuple{Vararg{Digest256}}
    binding_hash::Union{Nothing,Digest256}
    declaration_hash::Union{Nothing,Digest256}
    obligation_inventory_hash::Union{Nothing,Digest256}
    obligation_hashes::Tuple{Vararg{Digest256}}
    unresolved_obligation_hashes::Tuple{Vararg{Digest256}}
    unresolved_g1_identity_hashes::Tuple{Vararg{Digest256}}
    capability::Union{Nothing,CapabilitySignatureV4}
    input::Union{Nothing,TrustedFreeGSAxisymmetricInputV4}
    request::Union{Nothing,TrustedProviderDispatchRequestV4}
    receipt::Union{Nothing,TrustedProviderExecutionReceiptV4}
    capability_hash::Union{Nothing,Digest256}
    input_hash::Union{Nothing,Digest256}
    request_hash::Union{Nothing,Digest256}
    receipt_hash::Union{Nothing,Digest256}
    output_hash::Union{Nothing,Digest256}
    provider_status::Union{Nothing,Symbol}
    exit_code::Union{Nothing,Int}
    execution_started::Bool
    status::Symbol
    failure_stage::Union{Nothing,Symbol}
    failure_code::Union{Nothing,Symbol}
    failure_type::Union{Nothing,String}
    failure_message::Union{Nothing,String}
    claim_ceiling::ClaimCeiling
    search_activation::Bool
    physical_validation::Bool
    engineering_validation::Bool
    candidate_discovery_credit::Int
    credible_device_count::Int
    record_hash::Digest256
end

function _g2obs_publish(candidate_hash, genome_bundle_hash, subject_hash,
        context_hash, scenario_hash, registry_hash, source_provenance,
        binding_hash, declaration_hash, obligation_inventory_hash, obligation_hashes,
        unresolved_obligation_hashes, unresolved_g1_identity_hashes,
        capability, input, request, receipt, execution_started::Bool,
        status::Symbol, failure_stage, failure_code, failure_type,
        failure_message)
    status in _G2OBS_STATES || throw(ArgumentError("invalid G2 observation state"))
    capability_hash = capability === nothing ? nothing : canonical_hash(capability)
    input_hash = input === nothing ? nothing : canonical_hash(input)
    request_hash = request === nothing ? nothing : request.request_hash
    receipt_hash = receipt === nothing ? nothing : receipt.receipt_hash
    output_hash = receipt === nothing ? nothing : receipt.output_hash
    provider_status = receipt === nothing ? nothing : receipt.status
    exit_code = receipt === nothing ? nothing : receipt.exit_code
    provider_descriptor_hash = source_provenance.provider_descriptor_hash
    provider_manifest_hash = source_provenance.provider_manifest_hash
    provider_source_hash = source_provenance.provider_source_hash
    provider_runtime_hash = source_provenance.provider_runtime_hash
    provider_attested_source_paths = source_provenance.provider_attested_source_paths
    provider_attested_source_hashes = source_provenance.provider_attested_source_hashes
    ceiling = status === :screen_only ? screen_only : none
    ticket = _g2obs_ticket()
    body = _g2obs_body(candidate_hash, genome_bundle_hash, subject_hash,
        context_hash, scenario_hash, registry_hash, provider_descriptor_hash,
        provider_manifest_hash, provider_source_hash, provider_runtime_hash,
        Tuple(provider_attested_source_paths),
        Tuple(provider_attested_source_hashes), binding_hash, declaration_hash,
        obligation_inventory_hash, Tuple(obligation_hashes),
        Tuple(unresolved_obligation_hashes),
        Tuple(unresolved_g1_identity_hashes), capability_hash, input_hash,
        request_hash, receipt_hash, output_hash, provider_status, exit_code,
        execution_started, status, failure_stage, failure_code, failure_type,
        failure_message, ceiling, false, false, false, 0, 0)
    record = G2ScreenObservationV1(ticket, candidate_hash, genome_bundle_hash,
        subject_hash, context_hash, scenario_hash, registry_hash,
        provider_descriptor_hash, provider_manifest_hash, provider_source_hash,
        provider_runtime_hash, Tuple(provider_attested_source_paths),
        Tuple(provider_attested_source_hashes), binding_hash, declaration_hash,
        obligation_inventory_hash, Tuple(obligation_hashes),
        Tuple(unresolved_obligation_hashes),
        Tuple(unresolved_g1_identity_hashes), capability, input, request,
        receipt, capability_hash, input_hash, request_hash, receipt_hash,
        output_hash, provider_status, exit_code, execution_started, status,
        failure_stage, failure_code, failure_type, failure_message, ceiling,
        false, false, false, 0, 0, canonical_hash(body))
    lock(_G2OBS_ISSUE_LOCK) do
        _G2OBS_ISSUED[ticket] = (ticket.nonce, record.record_hash)
    end
    record
end

function canonical_hash(x::G2ScreenObservationV1)
    x.status in _G2OBS_STATES || throw(ArgumentError("invalid G2 observation state"))
    x.capability_hash == (x.capability === nothing ? nothing : canonical_hash(x.capability)) ||
        throw(ArgumentError("observation capability hash mismatch"))
    x.input_hash == (x.input === nothing ? nothing : canonical_hash(x.input)) ||
        throw(ArgumentError("observation input hash mismatch"))
    x.request_hash == (x.request === nothing ? nothing : x.request.request_hash) ||
        throw(ArgumentError("observation request hash mismatch"))
    x.receipt_hash == (x.receipt === nothing ? nothing : x.receipt.receipt_hash) &&
        x.output_hash == (x.receipt === nothing ? nothing : x.receipt.output_hash) &&
        x.provider_status == (x.receipt === nothing ? nothing : x.receipt.status) &&
        x.exit_code == (x.receipt === nothing ? nothing : x.receipt.exit_code) ||
        throw(ArgumentError("observation receipt fields mismatch"))
    x.execution_started == (x.receipt !== nothing) ||
        throw(ArgumentError("execution flag does not match registry receipt"))
    x.claim_ceiling == (x.status === :screen_only ? screen_only : none) ||
        throw(ArgumentError("observation claim ceiling exceeds status"))
    !x.search_activation && !x.physical_validation && !x.engineering_validation &&
        x.candidate_discovery_credit == 0 && x.credible_device_count == 0 ||
        throw(ArgumentError("G2 observation exceeds screen-only authority"))
    if x.status === :screen_only
        x.receipt !== nothing && x.request !== nothing &&
            x.provider_status === :physical_model_screen && x.exit_code == 0 &&
            !isempty(x.unresolved_g1_identity_hashes) ||
            throw(ArgumentError("screen-only observation lacks an issued result or deferred G1 edges"))
    end
    expected = canonical_hash(_g2obs_body(x.candidate_hash,
        x.genome_bundle_hash, x.subject_hash, x.context_hash,
        x.scenario_hash, x.registry_hash, x.provider_descriptor_hash,
        x.provider_manifest_hash, x.provider_source_hash,
        x.provider_runtime_hash, x.provider_attested_source_paths,
        x.provider_attested_source_hashes, x.binding_hash, x.declaration_hash,
        x.obligation_inventory_hash, x.obligation_hashes,
        x.unresolved_obligation_hashes, x.unresolved_g1_identity_hashes,
        x.capability_hash, x.input_hash, x.request_hash, x.receipt_hash,
        x.output_hash, x.provider_status, x.exit_code, x.execution_started,
        x.status, x.failure_stage, x.failure_code, x.failure_type,
        x.failure_message, x.claim_ceiling, x.search_activation,
        x.physical_validation, x.engineering_validation,
        x.candidate_discovery_credit, x.credible_device_count))
    expected == x.record_hash || throw(ArgumentError("G2 observation record hash mismatch"))
    expected
end

semantic_view(x::G2ScreenObservationV1) = (
    candidate_hash=x.candidate_hash, genome_bundle_hash=x.genome_bundle_hash,
    subject_hash=x.subject_hash, context_hash=x.context_hash,
    scenario_hash=x.scenario_hash, registry_hash=x.registry_hash,
    provider_descriptor_hash=x.provider_descriptor_hash,
    provider_manifest_hash=x.provider_manifest_hash,
    provider_source_hash=x.provider_source_hash,
    provider_runtime_hash=x.provider_runtime_hash,
    provider_attested_source_paths=x.provider_attested_source_paths,
    provider_attested_source_hashes=x.provider_attested_source_hashes,
    binding_hash=x.binding_hash, declaration_hash=x.declaration_hash,
    obligation_inventory_hash=x.obligation_inventory_hash,
    obligation_hashes=x.obligation_hashes,
    unresolved_obligation_hashes=x.unresolved_obligation_hashes,
    unresolved_g1_identity_hashes=x.unresolved_g1_identity_hashes,
    capability_hash=x.capability_hash, input_hash=x.input_hash,
    request_hash=x.request_hash, receipt_hash=x.receipt_hash,
    output_hash=x.output_hash, provider_status=x.provider_status,
    exit_code=x.exit_code, execution_started=x.execution_started,
    status=x.status, failure_stage=x.failure_stage,
    failure_code=x.failure_code, failure_type=x.failure_type,
    failure_message=x.failure_message, claim_ceiling=x.claim_ceiling,
    search_activation=x.search_activation,
    physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation,
    candidate_discovery_credit=x.candidate_discovery_credit,
    credible_device_count=x.credible_device_count, record_hash=x.record_hash)

function _g2obs_inventory(context::ForwardChainContextV4)
    obligations = physical_edge_obligations_v1(context)
    inventory_hash = validate_obligation_set_v1(context, obligations)
    all(x -> x.provider.receipt_state === :missing, obligations) ||
        throw(ArgumentError("fresh observation must preserve unresolved edge receipts"))
    obligation_hashes = Tuple(canonical_hash(x) for x in obligations)
    unresolved_hashes = Tuple(canonical_hash(x) for x in obligations
        if x.provider.receipt_state !== :validated)
    g1_unresolved = Tuple(x.identity.identity_hash for x in obligations
        if x.identity.layer === :g1_mechanism &&
           x.provider.receipt_state !== :validated)
    (obligations=obligations, inventory_hash=inventory_hash,
     obligation_hashes=obligation_hashes,
     unresolved_hashes=unresolved_hashes, g1_unresolved=g1_unresolved)
end

function _g2obs_source_provenance(registry::TrustedProviderRegistryV4, request)
    hits = Tuple(item for item in registry.descriptors
        if :axisymmetric_equilibrium_screen in item.allowed_capability_kinds)
    length(hits) == 1 || throw(ArgumentError(
        "trusted FreeGS descriptor is missing or ambiguous"))
    descriptor = only(hits)
    registration = request === nothing ? nothing : request.registration
    registration === nothing || registration.manifest.backend == descriptor.provider_id ||
        throw(ArgumentError("dispatch registration does not match the fixed FreeGS descriptor"))
    (provider_descriptor_hash=descriptor.descriptor_hash,
     provider_manifest_hash=registration === nothing ? nothing :
        registration.manifest.manifest_hash,
     provider_source_hash=descriptor.source_hash,
     provider_runtime_hash=descriptor.runtime_hash,
     provider_attested_source_paths=descriptor.attested_source_paths,
     provider_attested_source_hashes=descriptor.attested_source_hashes)
end

"""Make one trusted G2 screen observation; this function never enters Search.

The caller supplies only the current context and a repository-trusted registry.
The FreeGS capability/input/request are derived and revalidated here; the raw
registry receipt is accepted only as the direct return from `execute_trusted_provider`.
"""
function observe_candidate_bound_g2_screen_v1(
        context::ForwardChainContextV4, registry::TrustedProviderRegistryV4)
    stage = :validate_context
    candidate_hash = nothing
    genome_bundle_hash = nothing
    subject_hash = nothing
    context_hash = nothing
    scenario_hash = nothing
    registry_hash = nothing
    source_provenance = (provider_descriptor_hash=nothing,
        provider_manifest_hash=nothing, provider_source_hash=nothing,
        provider_runtime_hash=nothing, provider_attested_source_paths=(),
        provider_attested_source_hashes=())
    binding_hash = nothing
    declaration_hash = nothing
    inventory_hash = nothing
    obligation_hashes = ()
    unresolved_hashes = ()
    g1_unresolved = ()
    capability = nothing
    input = nothing
    request = nothing
    receipt = nothing
    try
        validate_forward_chain_context(context)
        candidate_hash = context.candidate_hash
        genome_bundle_hash = context.candidate.canonical_hashes.genome_bundle_hash
        subject_hash = context.subject.physical_subject_hash
        context_hash = context.context_hash
        scenario_hash = context.scenario_hash

        stage = :validate_registry
        validate_trusted_provider_registry(registry)
        registry_hash = registry.registry_hash

        stage = :enumerate_physical_edges
        inventory = _g2obs_inventory(context)
        inventory_hash = inventory.inventory_hash
        obligation_hashes = inventory.obligation_hashes
        unresolved_hashes = inventory.unresolved_hashes
        g1_unresolved = inventory.g1_unresolved

        stage = :derive_g2_binding
        binding = _freegs_context_binding(context)
        binding_hash = binding.binding_hash
        declaration_hash = canonical_hash(binding.declaration)
        capability = trusted_freegs_axisymmetric_capability(context)
        validate_trusted_freegs_axisymmetric_capability(capability, context)
        input = make_trusted_freegs_axisymmetric_input(context, capability)
        validate_trusted_freegs_axisymmetric_input(input, context, capability)
        source_provenance = _g2obs_source_provenance(registry, nothing)

        stage = :prepare_trusted_dispatch
        request = build_trusted_provider_dispatch_request(registry, context,
            capability, input)
        source_provenance = _g2obs_source_provenance(registry, request)
        if request.status !== :ready_for_dispatch
            return _g2obs_publish(candidate_hash, genome_bundle_hash,
                subject_hash, context_hash, scenario_hash, registry_hash,
                source_provenance,
                binding_hash, declaration_hash, inventory_hash,
                obligation_hashes, unresolved_hashes, g1_unresolved,
                capability, input, request, nothing, false, :deferred,
                :prepare_trusted_dispatch, :provider_registration_unavailable,
                nothing, join(request.recoverable_gaps, ";"))
        end
        validate_trusted_provider_dispatch_request(request, registry, context,
            capability, input) || throw(ArgumentError("dispatch request revalidation failed"))

        stage = :execute_trusted_provider
        receipt = lock(_G2OBS_EXECUTION_LOCK) do
            execute_trusted_provider(registry, context, request)
        end

        stage = :revalidate_trusted_receipt
        validate_trusted_provider_execution_receipt(receipt, request,
            registry, context) || throw(ArgumentError("trusted receipt revalidation failed"))
        if receipt.status === :physical_model_screen && receipt.exit_code == 0
            return _g2obs_publish(candidate_hash, genome_bundle_hash,
                subject_hash, context_hash, scenario_hash, registry_hash,
                source_provenance,
                binding_hash, declaration_hash, inventory_hash,
                obligation_hashes, unresolved_hashes, g1_unresolved,
                capability, input, request, receipt, true, :screen_only,
                nothing, nothing, nothing, nothing)
        elseif receipt.status === :executor_error
            return _g2obs_publish(candidate_hash, genome_bundle_hash,
                subject_hash, context_hash, scenario_hash, registry_hash,
                source_provenance,
                binding_hash, declaration_hash, inventory_hash,
                obligation_hashes, unresolved_hashes, g1_unresolved,
                capability, input, request, receipt, true, :program_exception,
                :execute_trusted_provider, :trusted_provider_executor_error,
                "TrustedProviderRegistryV4", receipt.message)
        end
        _g2obs_publish(candidate_hash, genome_bundle_hash, subject_hash,
            context_hash, scenario_hash, registry_hash, source_provenance,
            binding_hash,
            declaration_hash, inventory_hash, obligation_hashes,
            unresolved_hashes, g1_unresolved, capability, input, request,
            receipt, true, :deferred, :revalidate_trusted_receipt,
            :provider_result_not_screen_only, nothing, String(receipt.status))
    catch error
        _g2obs_publish(candidate_hash, genome_bundle_hash, subject_hash,
            context_hash, scenario_hash, registry_hash, source_provenance,
            binding_hash,
            declaration_hash, inventory_hash, obligation_hashes,
            unresolved_hashes, g1_unresolved, capability, input, request,
            receipt, receipt !== nothing, :program_exception, stage,
            :g2_screen_observation_exception, string(typeof(error)),
            sprint(showerror, error))
    end
end

function validate_candidate_bound_g2_screen_observation_v1(
        record::G2ScreenObservationV1, context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4)
    try
        canonical_hash(record)
        issued_hash = lock(_G2OBS_ISSUE_LOCK) do
            get(_G2OBS_ISSUED, record._ticket, nothing)
        end
        issued_hash == (record._ticket.nonce, record.record_hash) || return false
        validate_forward_chain_context(context)
        validate_trusted_provider_registry(registry)
        record.candidate_hash == context.candidate_hash &&
            record.genome_bundle_hash == context.candidate.canonical_hashes.genome_bundle_hash &&
            record.subject_hash == context.subject.physical_subject_hash &&
        record.context_hash == context.context_hash &&
            record.scenario_hash == context.scenario_hash &&
            record.registry_hash == registry.registry_hash || return false
        source_provenance = _g2obs_source_provenance(registry, record.request)
        record.provider_descriptor_hash == source_provenance.provider_descriptor_hash &&
            record.provider_manifest_hash == source_provenance.provider_manifest_hash &&
            record.provider_source_hash == source_provenance.provider_source_hash &&
            record.provider_runtime_hash == source_provenance.provider_runtime_hash &&
            record.provider_attested_source_paths == source_provenance.provider_attested_source_paths &&
            record.provider_attested_source_hashes == source_provenance.provider_attested_source_hashes ||
            return false
        inventory = _g2obs_inventory(context)
        record.obligation_inventory_hash == inventory.inventory_hash &&
            record.obligation_hashes == inventory.obligation_hashes &&
            record.unresolved_obligation_hashes == inventory.unresolved_hashes &&
            record.unresolved_g1_identity_hashes == inventory.g1_unresolved || return false
        binding = _freegs_context_binding(context)
        record.binding_hash == binding.binding_hash &&
            record.declaration_hash == canonical_hash(binding.declaration) || return false
        capability = trusted_freegs_axisymmetric_capability(context)
        validate_trusted_freegs_axisymmetric_capability(capability, context)
        record.capability_hash == canonical_hash(capability) || return false
        input = make_trusted_freegs_axisymmetric_input(context, capability)
        validate_trusted_freegs_axisymmetric_input(input, context, capability)
        record.input_hash == canonical_hash(input) || return false
        if record.request === nothing
            return record.receipt === nothing && !record.execution_started &&
                record.status === :program_exception
        end
        request = build_trusted_provider_dispatch_request(registry, context,
            capability, input)
        validate_trusted_provider_dispatch_request(record.request, registry,
            context, capability, input) || return false
        record.request_hash == request.request_hash == record.request.request_hash ||
            return false
        if request.status !== :ready_for_dispatch
            return record.status === :deferred && record.receipt === nothing &&
                !record.execution_started
        end
        record.receipt === nothing &&
            return record.status === :program_exception && !record.execution_started
        validate_trusted_provider_execution_receipt(record.receipt, request,
            registry, context) || return false
        expected_status = record.receipt.status === :physical_model_screen &&
            record.receipt.exit_code == 0 ? :screen_only :
            record.receipt.status === :executor_error ? :program_exception : :deferred
        record.status === expected_status && record.execution_started
    catch
        false
    end
end

end # module CandidateBoundG2ScreenObservationV1
