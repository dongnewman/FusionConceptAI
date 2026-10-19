"""An unintegrated, screen-only bridge exercised with a source-backed local VNext fixture.

The fixture's synthetic-local T2 gate sets `formal_t1_accepted=true` only to
form the typed local contract input, while `formal_gate_verified=false`;
this is not verified formal T1 acceptance or identity linkage from the actual
r3 producer package. The bridge runs the existing declared G1/G2/G3 diffusion
screen and does not implement or accept formal B00/B04 or general UP2 gates.
"""

const VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_ID_V1 =
    "GenomeV5/UP2/VNextUP2ConsumerBridgeV1"
const VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_VERSION_V1 = "v1"
const VNEXT_UP2_CONSUMER_BRIDGE_CLAIM_CEILING_V1 = :screen_only

_vnext_up2_bridge_zero_digest_v1() = Digest256(repeat("0", 64))

struct VNextUP2DGDObservationV1
    candidate_ref::QualifiedRefV1
    t1_package_hash::Digest256
    t2_input_hash::Digest256
    t2_ledger_hash::Digest256
    source_witness_hash::Digest256
    t0_bundle_hash::Digest256
    package_children_hash::Digest256
    witness_children_hash::Digest256
    g3_edit_use::Symbol
    compile_status::Symbol
    compile_code::Symbol
    expression_subset::Symbol
    transfer_status::Symbol
    transfer_conservation_residual::Float64
    composition_status::Symbol
    composition_code::Symbol
    composition_energy_residual::Float64
    composition_ledger_residual::Float64
    numerical_status::Union{Nothing,Symbol}
    numerical_code::Union{Nothing,Symbol}
    numerical_solution::Union{Nothing,NTuple{2,Float64}}
    numerical_residual_norm::Union{Nothing,Float64}
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    runtime_status::Symbol
    runtime_resolution::Symbol
    runtime_receipt_hash::Digest256
    gaps::Tuple{Vararg{Symbol}}
    observation_hash::Digest256
end

function _vnext_up2_dgd_observation_body_v1(x::VNextUP2DGDObservationV1)
    (domain="vnext-up2-dgd-observation-v1",
        candidate_ref=x.candidate_ref,
        t1_package_hash=x.t1_package_hash,
        t2_input_hash=x.t2_input_hash,
        t2_ledger_hash=x.t2_ledger_hash,
        source_witness_hash=x.source_witness_hash,
        t0_bundle_hash=x.t0_bundle_hash,
        package_children_hash=x.package_children_hash,
        witness_children_hash=x.witness_children_hash,
        g3_edit_use=x.g3_edit_use,
        compile_status=x.compile_status,
        compile_code=x.compile_code,
        expression_subset=x.expression_subset,
        transfer_status=x.transfer_status,
        transfer_conservation_residual=x.transfer_conservation_residual,
        composition_status=x.composition_status,
        composition_code=x.composition_code,
        composition_energy_residual=x.composition_energy_residual,
        composition_ledger_residual=x.composition_ledger_residual,
        numerical_status=x.numerical_status,
        numerical_code=x.numerical_code,
        numerical_solution=x.numerical_solution,
        numerical_residual_norm=x.numerical_residual_norm,
        provider_calls=x.provider_calls, mesh_calls=x.mesh_calls,
        solver_calls=x.solver_calls, runtime_status=x.runtime_status,
        runtime_resolution=x.runtime_resolution,
        runtime_receipt_hash=x.runtime_receipt_hash, gaps=x.gaps)
end

semantic_view(x::VNextUP2DGDObservationV1) = merge(
    _vnext_up2_dgd_observation_body_v1(x),
    (observation_hash=x.observation_hash,))
canonical_json(x::VNextUP2DGDObservationV1) = canonical_json(semantic_view(x))

struct VNextUP2ConsumerResultV1
    schema_id::String
    schema_version::String
    candidate_ref::Union{Nothing,QualifiedRefV1}
    t1_package_hash::Digest256
    t2_input_hash::Digest256
    t2_ledger_hash::Digest256
    status::Symbol
    resolution::Symbol
    reason::Symbol
    b00_status::Symbol
    b04_status::Symbol
    formal_gate_resolution::Symbol
    formal_gate_reason::Symbol
    dgd_invocation_count::Int
    claim_ceiling::Symbol
    accepted::Bool
    formal_up_credit::Bool
    formal_r_credit::Bool
    observation::Union{Nothing,VNextUP2DGDObservationV1}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    result_hash::Digest256
    function VNextUP2ConsumerResultV1(schema_id::String,
            schema_version::String,
            candidate_ref::Union{Nothing,QualifiedRefV1},
            t1_package_hash::Digest256, t2_input_hash::Digest256,
            t2_ledger_hash::Digest256, status::Symbol, resolution::Symbol,
            reason::Symbol, b00_status::Symbol, b04_status::Symbol,
            formal_gate_resolution::Symbol, formal_gate_reason::Symbol,
            dgd_invocation_count::Int, claim_ceiling::Symbol,
            accepted::Bool, formal_up_credit::Bool,
            formal_r_credit::Bool,
            observation::Union{Nothing,VNextUP2DGDObservationV1},
            errors::Tuple{Vararg{Symbol}}, gaps::Tuple{Vararg{Symbol}},
            result_hash::Digest256)
        schema_id == VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_ID_V1 ||
            throw(ArgumentError("UP2 consumer schema id mismatch"))
        schema_version == VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_VERSION_V1 ||
            throw(ArgumentError("UP2 consumer schema version mismatch"))
        b00_status === :typed_absent && b04_status === :typed_absent ||
            throw(ArgumentError("screen bridge cannot claim B00/B04"))
        formal_gate_resolution === :terminal_deferred ||
            throw(ArgumentError("formal gate must remain deferred"))
        dgd_invocation_count in (0, 1) ||
            throw(ArgumentError("DGD invocation count is outside this slice"))
        observation === nothing || dgd_invocation_count == 1 ||
            throw(ArgumentError("DGD observation requires one invocation"))
        claim_ceiling === VNEXT_UP2_CONSUMER_BRIDGE_CLAIM_CEILING_V1 ||
            throw(ArgumentError("UP2 consumer claim ceiling mismatch"))
        accepted === false && formal_up_credit === false &&
            formal_r_credit === false ||
            throw(ArgumentError("screen bridge cannot grant acceptance"))
        new(schema_id, schema_version, candidate_ref, t1_package_hash,
            t2_input_hash, t2_ledger_hash, status, resolution, reason,
            b00_status, b04_status, formal_gate_resolution,
            formal_gate_reason, dgd_invocation_count, claim_ceiling,
            accepted, formal_up_credit,
            formal_r_credit, observation, errors, gaps, result_hash)
    end
end

function _vnext_up2_consumer_result_body_v1(x::VNextUP2ConsumerResultV1)
    (domain="vnext-up2-consumer-result-v1", schema_id=x.schema_id,
        schema_version=x.schema_version, candidate_ref=x.candidate_ref,
        t1_package_hash=x.t1_package_hash, t2_input_hash=x.t2_input_hash,
        t2_ledger_hash=x.t2_ledger_hash, status=x.status,
        resolution=x.resolution, reason=x.reason, b00_status=x.b00_status,
        b04_status=x.b04_status,
        formal_gate_resolution=x.formal_gate_resolution,
        formal_gate_reason=x.formal_gate_reason,
        dgd_invocation_count=x.dgd_invocation_count,
        claim_ceiling=x.claim_ceiling, accepted=x.accepted,
        formal_up_credit=x.formal_up_credit,
        formal_r_credit=x.formal_r_credit, observation=x.observation,
        errors=x.errors, gaps=x.gaps)
end

semantic_view(x::VNextUP2ConsumerResultV1) = merge(
    _vnext_up2_consumer_result_body_v1(x), (result_hash=x.result_hash,))
canonical_json(x::VNextUP2ConsumerResultV1) = canonical_json(semantic_view(x))

function _vnext_up2_consumer_result_v1(status::Symbol,
        resolution::Symbol, reason::Symbol;
        candidate_ref::Union{Nothing,QualifiedRefV1}=nothing,
        t1_package_hash::Digest256=_vnext_up2_bridge_zero_digest_v1(),
        t2_input_hash::Digest256=_vnext_up2_bridge_zero_digest_v1(),
        t2_ledger_hash::Digest256=_vnext_up2_bridge_zero_digest_v1(),
        dgd_invocation_count::Int=0,
        observation::Union{Nothing,VNextUP2DGDObservationV1}=nothing,
        errors::Tuple{Vararg{Symbol}}=(), gaps::Tuple{Vararg{Symbol}}=())
    body = (domain="vnext-up2-consumer-result-v1",
        schema_id=VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_ID_V1,
        schema_version=VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_VERSION_V1,
        candidate_ref=candidate_ref, t1_package_hash=t1_package_hash,
        t2_input_hash=t2_input_hash, t2_ledger_hash=t2_ledger_hash,
        status=status, resolution=resolution, reason=reason,
        b00_status=:typed_absent, b04_status=:typed_absent,
        formal_gate_resolution=:terminal_deferred,
        formal_gate_reason=:b00_b04_receipts_not_supplied,
        dgd_invocation_count=dgd_invocation_count,
        claim_ceiling=VNEXT_UP2_CONSUMER_BRIDGE_CLAIM_CEILING_V1,
        accepted=false, formal_up_credit=false, formal_r_credit=false,
        observation=observation, errors=errors, gaps=gaps)
    VNextUP2ConsumerResultV1(VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_ID_V1,
        VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_VERSION_V1, candidate_ref,
        t1_package_hash, t2_input_hash, t2_ledger_hash, status, resolution,
        reason, :typed_absent, :typed_absent, :terminal_deferred,
        :b00_b04_receipts_not_supplied, dgd_invocation_count,
        VNEXT_UP2_CONSUMER_BRIDGE_CLAIM_CEILING_V1, false, false, false,
        observation, errors, gaps, canonical_hash(body))
end

function _vnext_up2_counts_are_t2_only_v1(counts)
    counts.e0 == 1 && counts.gi1a == 1 && counts.e1 == 1 &&
        counts.e2 == 1 && counts.n10 == 1 && counts.compiler == 0 &&
        counts.provider == 0 && counts.solver == 0
end

function _vnext_up2_t2_ledger_valid_v1(input,
        aggregate::VNextT2IdentityReceiptIntegrationResultV2)
    aggregate.status === :complete_contract_receipts || return false
    aggregate.resolution === :terminal_deferred || return false
    aggregate.reason === :none && aggregate.committed === true || return false
    isempty(aggregate.errors) || return false
    aggregate.ledger isa VNextT2ReceiptLedgerV2 || return false
    ledger = aggregate.ledger
    expected_ids = VNEXT_T2_CONSUMER_ORDER_V2
    ledger.schema_id == VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2 || return false
    ledger.schema_version == VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2 || return false
    ledger.profile == VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2 || return false
    ledger.candidate_ref == input.package.candidate_ref || return false
    ledger.scenario == input.scenario || return false
    ledger.input_hash == input.input_hash || return false
    ledger.package_hash == input.package.package_hash || return false
    ledger.status === :complete_contract_receipts || return false
    ledger.resolution === :terminal_deferred || return false
    ledger.accepted === false || return false
    ledger.claim_ceiling === VNEXT_T2_UP2_CLAIM_CEILING_V2 || return false
    Tuple(r.consumer_id for r in ledger.receipts) == expected_ids || return false
    _vnext_up2_counts_are_t2_only_v1(ledger.counts) || return false
    _vnext_up2_counts_are_t2_only_v1(aggregate.committed_counts) || return false
    aggregate.committed_counts == ledger.counts || return false
    all(g -> g in ledger.gaps,
        (:compiler_not_executed, :provider_not_executed, :solver_not_executed)) ||
        return false
    for receipt in ledger.receipts
        receipt.t1_package_hash == input.package.package_hash || return false
        receipt.candidate_ref == input.package.candidate_ref || return false
        receipt.scenario == input.scenario || return false
        receipt.profile == input.profile || return false
        receipt.invocation_count == 1 || return false
        receipt.output_hash != _vnext_up2_bridge_zero_digest_v1() || return false
        body = _vnext_t2_invocation_receipt_body_v2(receipt.consumer_id,
            receipt.t1_package_hash, receipt.candidate_ref, receipt.scenario,
            receipt.profile, receipt.input_hash, receipt.output_hash,
            receipt.invocation_count, receipt.status, receipt.resolution)
        canonical_hash(body) == receipt.identity_hash || return false
    end
    ledger_body = _vnext_t2_receipt_ledger_body_v2(ledger.schema_id,
        ledger.schema_version, ledger.profile, ledger.candidate_ref,
        ledger.scenario, ledger.input_hash, ledger.package_hash,
        ledger.receipts, ledger.counts, ledger.status, ledger.resolution,
        ledger.accepted, ledger.claim_ceiling, ledger.gaps)
    canonical_hash(ledger_body) == ledger.ledger_hash || return false

    trace = aggregate.attempted_trace
    trace.input_hash == input.input_hash || return false
    _vnext_up2_counts_are_t2_only_v1(trace.counts) || return false
    length(trace.events) == length(expected_ids) || return false
    for (i, (event, receipt)) in enumerate(zip(trace.events, ledger.receipts))
        event.sequence == i || return false
        event.consumer_id == receipt.consumer_id || return false
        event.input_hash == receipt.input_hash || return false
        event.output_hash == receipt.output_hash || return false
        event.status == receipt.status && event.resolution == receipt.resolution ||
            return false
        event_body = _vnext_t2_attempt_event_body_v2(event.sequence,
            event.consumer_id, event.input_hash, event.output_hash,
            event.status, event.resolution, event.reason)
        canonical_hash(event_body) == event.event_hash || return false
    end
    trace_body = _vnext_t2_attempt_trace_body_v2(trace.input_hash,
        trace.events, trace.counts)
    canonical_hash(trace_body) == trace.trace_hash || return false
    aggregate_body = _vnext_t2_integration_result_body_v2(aggregate.status,
        aggregate.resolution, aggregate.reason, aggregate.committed,
        aggregate.ledger, aggregate.attempted_trace,
        aggregate.committed_counts, aggregate.errors, aggregate.gaps)
    canonical_hash(aggregate_body) == aggregate.result_hash
end

function _vnext_up2_ensure_dgd_loaded_v1()
    required = (:DeclaredG123InputV1, :dgd_input_v1, :dgd_execute_v1,
        :DGDAggregateReceiptV1)
    present = count(s -> isdefined(@__MODULE__, s), required)
    present == length(required) && return :ready
    present == 0 || return :partial_definition_set
    path = normpath(joinpath(@__DIR__, "..", "..", "..", "RuntimeV4",
        "DeclaredG123DiffusionExecutionV1.jl"))
    isfile(path) || return :consumer_source_absent
    try
        Base.include(@__MODULE__, path)
    catch
        return :consumer_definition_load_failed
    end
    all(s -> isdefined(@__MODULE__, s), required) ? :ready :
        :consumer_definition_load_incomplete
end

function _vnext_up2_dgd_observation_v1(input,
        ledger::VNextT2ReceiptLedgerV2, runtime)
    numerical = runtime.numerical
    numerical_status = numerical === nothing ? nothing : numerical.status
    numerical_code = numerical === nothing ? nothing : numerical.code
    numerical_solution = numerical === nothing ? nothing : numerical.solution
    residual = numerical === nothing ? nothing : numerical.residual_norm
    package_children_hash = canonical_hash(input.package.children)
    witness_children_hash = input.witness.children.identity_hash
    gaps = Tuple(unique((ledger.gaps..., input.witness.gaps...,
        :formal_b00_b04_receipts_not_supplied,
        :formal_up2_acceptance_not_attempted,
        :g3_child_edits_identity_bound_but_outside_dgd_screen,
        :external_provider_not_executed,
        :physical_validation_not_executed)))
    draft = VNextUP2DGDObservationV1(input.package.candidate_ref,
        input.package.package_hash, input.input_hash, ledger.ledger_hash,
        input.witness.witness_hash, input.witness.t0_transport.bundle_hash,
        package_children_hash, witness_children_hash,
        :identity_bound_not_consumed_by_dgd, runtime.compile.status,
        runtime.compile.code, runtime.compile.expression_subset,
        runtime.transfer.status, runtime.transfer.conservation_residual,
        runtime.composition.status, runtime.composition.code,
        runtime.composition.energy_residual,
        runtime.composition.ledger_residual, numerical_status,
        numerical_code, numerical_solution, residual,
        runtime.provider_calls, runtime.mesh_calls, runtime.solver_calls,
        runtime.status, runtime.resolution, runtime.receipt_hash, gaps,
        _vnext_up2_bridge_zero_digest_v1())
    body = _vnext_up2_dgd_observation_body_v1(draft)
    VNextUP2DGDObservationV1(draft.candidate_ref, draft.t1_package_hash,
        draft.t2_input_hash, draft.t2_ledger_hash, draft.source_witness_hash,
        draft.t0_bundle_hash, draft.package_children_hash,
        draft.witness_children_hash, draft.g3_edit_use, draft.compile_status,
        draft.compile_code, draft.expression_subset, draft.transfer_status,
        draft.transfer_conservation_residual, draft.composition_status,
        draft.composition_code, draft.composition_energy_residual,
        draft.composition_ledger_residual, draft.numerical_status,
        draft.numerical_code, draft.numerical_solution,
        draft.numerical_residual_norm, draft.provider_calls, draft.mesh_calls,
        draft.solver_calls, draft.runtime_status, draft.runtime_resolution,
        draft.runtime_receipt_hash, draft.gaps, canonical_hash(body))
end

"""Consume a prepared T2 input plus its committed five-receipt aggregate.

The DGD execution is a bounded local screen.  Since this API has no B00/B04
receipt arguments, the formal gate always remains typed absent and deferred.
"""
function vnext_up2_dgd_consume_v1(
        build::VNextT2UP2InputBuildResultV2, aggregate;
        old_state=(0.25, 0.75), overlap=nothing)
    if build.status === :typed_absent
        return _vnext_up2_consumer_result_v1(:typed_absent,
            :terminal_deferred, build.reason; t2_input_hash=build.input_hash,
            gaps=(build.reason, :formal_b00_b04_receipts_not_supplied))
    elseif build.status === :fail_closed
        return _vnext_up2_consumer_result_v1(:fail_closed, :none,
            build.reason; t2_input_hash=build.input_hash,
            errors=(build.reason,))
    elseif build.status !== :prepared_not_executed ||
            !(build.input isa VNextT2UP2BoundInputV2)
        return _vnext_up2_consumer_result_v1(:fail_closed, :none,
            :t2_preflight_build_shape_invalid;
            t2_input_hash=build.input_hash,
            errors=(:t2_preflight_build_shape_invalid,))
    end
    input = build.input
    base = (candidate_ref=input.package.candidate_ref,
        t1_package_hash=input.package.package_hash,
        t2_input_hash=input.input_hash)
    input.input_hash == build.input_hash ||
        return _vnext_up2_consumer_result_v1(:fail_closed, :none,
            :t2_preflight_build_hash_mismatch; base...,
            errors=(:t2_preflight_build_hash_mismatch,))
    validation = vnext_t2_up2_validate_input_v2(input)
    validation.status === :valid ||
        return _vnext_up2_consumer_result_v1(:fail_closed, :none,
            validation.reason; base..., errors=(validation.reason,))
    aggregate isa VNextT2IdentityReceiptIntegrationResultV2 ||
        return _vnext_up2_consumer_result_v1(:typed_absent,
            :terminal_deferred, :t2_identity_receipt_aggregate_absent;
            base..., gaps=(:t2_identity_receipt_aggregate_absent,
                :formal_b00_b04_receipts_not_supplied))
    _vnext_up2_t2_ledger_valid_v1(input, aggregate) ||
        return _vnext_up2_consumer_result_v1(:fail_closed, :none,
            :t2_identity_receipt_aggregate_mismatch; base...,
            t2_ledger_hash=aggregate.ledger isa VNextT2ReceiptLedgerV2 ?
                aggregate.ledger.ledger_hash :
                _vnext_up2_bridge_zero_digest_v1(),
            errors=(:t2_identity_receipt_aggregate_mismatch,))

    load_status = _vnext_up2_ensure_dgd_loaded_v1()
    load_status === :ready ||
        return _vnext_up2_consumer_result_v1(:typed_absent,
            :terminal_deferred, Symbol("dgd_" * String(load_status));
            base..., t2_ledger_hash=aggregate.ledger.ledger_hash,
            gaps=(Symbol("dgd_" * String(load_status)),
                :formal_b00_b04_receipts_not_supplied))

    dgd_calls = 0
    try
        # The T2 preflight above byte-compares every package carrier to this
        # source witness before its typed declarations reach the real DGD API.
        declared = dgd_input_v1(input.package.candidate_ref,
            input.witness.g1.declaration, input.witness.g2.declaration,
            input.witness.g3.declaration, input.witness.t0_transport)
        declared.candidate_ref == input.package.candidate_ref ||
            return _vnext_up2_consumer_result_v1(:fail_closed, :none,
                :dgd_candidate_binding_mismatch; base...,
                t2_ledger_hash=aggregate.ledger.ledger_hash,
                errors=(:dgd_candidate_binding_mismatch,))
        dgd_calls = 1
        runtime = dgd_execute_v1(declared; old_state=old_state,
            overlap=overlap)
        runtime isa DGDAggregateReceiptV1 ||
            return _vnext_up2_consumer_result_v1(:fail_closed, :none,
                :dgd_aggregate_shape_invalid; base...,
                t2_ledger_hash=aggregate.ledger.ledger_hash,
                dgd_invocation_count=dgd_calls,
                errors=(:dgd_aggregate_shape_invalid,))
        runtime.candidate_ref == input.package.candidate_ref ||
            return _vnext_up2_consumer_result_v1(:fail_closed, :none,
                :dgd_output_candidate_mismatch; base...,
                t2_ledger_hash=aggregate.ledger.ledger_hash,
                dgd_invocation_count=dgd_calls,
                errors=(:dgd_output_candidate_mismatch,))
        runtime.accepted === false && runtime.screen_only === true &&
            runtime.claim_ceiling === :screen_only &&
            runtime.formal_up_credit === false &&
            runtime.formal_r_credit === false ||
            return _vnext_up2_consumer_result_v1(:fail_closed, :none,
                :dgd_claim_ceiling_invalid; base...,
                t2_ledger_hash=aggregate.ledger.ledger_hash,
                dgd_invocation_count=dgd_calls,
                errors=(:dgd_claim_ceiling_invalid,))
        canonical_hash(semantic_view(runtime)) == runtime.receipt_hash ||
            return _vnext_up2_consumer_result_v1(:fail_closed, :none,
                :dgd_receipt_hash_mismatch; base...,
                t2_ledger_hash=aggregate.ledger.ledger_hash,
                dgd_invocation_count=dgd_calls,
                errors=(:dgd_receipt_hash_mismatch,))
        observation = _vnext_up2_dgd_observation_v1(input,
            aggregate.ledger, runtime)
        status = runtime.numerical !== nothing &&
            runtime.numerical.status === :numerical_fail ? :numerical_fail :
            runtime.status === :fail_closed ? :fail_closed :
            :screen_observed
        resolution = status === :numerical_fail ? :numerical_fail :
            status === :fail_closed ? :none : :terminal_deferred
        reason = status === :numerical_fail ? runtime.numerical.code :
            status === :fail_closed ? runtime.compile.code :
            :formal_b00_b04_receipts_typed_absent
        _vnext_up2_consumer_result_v1(status, resolution, reason;
            base..., t2_ledger_hash=aggregate.ledger.ledger_hash,
            dgd_invocation_count=dgd_calls,
            observation=observation,
            errors=status === :numerical_fail ? (reason,) : (),
            gaps=observation.gaps)
    catch
        _vnext_up2_consumer_result_v1(:program_exception, :none,
            :dgd_screen_consumer_program_exception; base...,
            t2_ledger_hash=aggregate.ledger.ledger_hash,
            dgd_invocation_count=dgd_calls,
            errors=(:dgd_screen_consumer_program_exception,))
    end
end

export VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_ID_V1,
    VNEXT_UP2_CONSUMER_BRIDGE_SCHEMA_VERSION_V1,
    VNextUP2DGDObservationV1, VNextUP2ConsumerResultV1,
    vnext_up2_dgd_consume_v1
