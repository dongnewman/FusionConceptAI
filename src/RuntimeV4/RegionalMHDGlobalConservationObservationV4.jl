using FusionConceptAI
using SHA
import FusionConceptAI: Digest256, ClaimCeiling, canonical_hash, semantic_view, screen_only

const _RMGCO_REVISION = "runtime-v4-regional-mhd-global-conservation-observation-v3"
const _RMGCO_SOURCE = abspath(@__FILE__)
_rmgco_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_rmgco_vec(value) = length(value) == 3 && all(isfinite, value) ?
    (Float64(value[1]), Float64(value[2]), Float64(value[3])) :
    throw(ArgumentError("non-finite vector"))

# The observation is deliberately split into typed request/result/receipt
# records as well.  These records carry identity and replay obligations; they
# do not confer solver or device authority.
struct RegionalMHDGlobalConservationObservationRequestV4
    revision::String; candidate_hash::Digest256; context_hash::Digest256
    q3_request_hash::Digest256; q3_result_hash::Digest256; q3_receipt_hash::Digest256
    partition_request_hash::Digest256; partition_result_hash::Digest256
    ledger_request_hash::Digest256; ledger_result_hash::Digest256
    region_ids::Tuple; interface_ids::Tuple; volume_units::String
    interface_units::String; sign_convention::Symbol; source_path::String
    source_sha256::Digest256; request_hash::Digest256
end
struct RegionalMHDGlobalConservationObservationReceiptV4
    request_hash::Digest256; observation_hash::Digest256; replay_hash::Digest256
    source_path::String; source_sha256::Digest256; receipt_hash::Digest256
end
struct RegionalMHDGlobalConservationObservationResultV4
    request_hash::Digest256; receipt_hash::Digest256; observation_hash::Digest256
    region_volume_force_total::NTuple{3,Float64}; status::Symbol; result_hash::Digest256
end
for T in (:RegionalMHDGlobalConservationObservationRequestV4,
          :RegionalMHDGlobalConservationObservationReceiptV4,
          :RegionalMHDGlobalConservationObservationResultV4)
    @eval semantic_view(x::$T) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x))-1))
end
for T in (:RegionalMHDGlobalConservationObservationRequestV4,
          :RegionalMHDGlobalConservationObservationReceiptV4,
          :RegionalMHDGlobalConservationObservationResultV4)
    @eval function canonical_hash(x::$T)
        h = canonical_hash(semantic_view(x)); h == getfield(x, fieldnames(typeof(x))[end]) ||
            throw(ArgumentError("typed global-conservation hash mismatch")); h
    end
end

struct RegionalMHDGlobalConservationObservationV4
    revision::String; candidate_hash::Digest256; context_hash::Digest256
    q3_request_hash::Digest256; q3_result_hash::Digest256; q3_receipt_hash::Digest256
    ledger_request_hash::Digest256; ledger_result_hash::Digest256
    partition_request_hash::Digest256; partition_result_hash::Digest256
    region_volume_force::Tuple; region_volume_force_total::NTuple{3,Float64}
    internal_interface_ledger::Tuple
    internal_interface_pair_sum::Union{Nothing,NTuple{3,Float64}}
    external_boundary_terms::Nothing; missing_capabilities::Tuple
    global_residual::Nothing; global_residual_norm::Nothing; status::Symbol
    multiregion_closure::Bool; claim_ceiling::ClaimCeiling; evidence_credit::Int
    source_path::String; source_sha256::Digest256; observation_hash::Digest256
    function RegionalMHDGlobalConservationObservationV4(
            token::Val{:rmgco_private}, fields...)
        token === Val(:rmgco_private) || throw(ArgumentError("private constructor"))
        new(fields...)
    end
end

semantic_view(x::RegionalMHDGlobalConservationObservationV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::RegionalMHDGlobalConservationObservationV4)
    all(v -> hasproperty(v, :region_id) && hasproperty(v, :force) &&
        v.force isa NTuple{3,Float64} && all(isfinite, v.force),
        x.region_volume_force) &&
        x.region_volume_force_total == ntuple(i ->
            sum(v.force[i] for v in x.region_volume_force), 3) ||
        throw(ArgumentError("invalid regional volume-force ledger"))
    all(e -> hasproperty(e, :interface_id) && hasproperty(e, :minus_region_id) &&
        hasproperty(e, :plus_region_id) && e.minus_region_id != e.plus_region_id &&
        e.pair_sum === nothing &&
        e.contribution_status === :not_surface_contribution &&
        length(e.jump_proxy) == 3 && all(isfinite, e.jump_proxy), x.internal_interface_ledger) ||
        throw(ArgumentError("invalid proxy-only interface ledger"))
    x.revision == _RMGCO_REVISION && x.internal_interface_pair_sum === nothing &&
        x.external_boundary_terms === nothing && x.global_residual === nothing &&
        x.global_residual_norm === nothing && x.missing_capabilities ==
            (:external_boundary_limit_trace, :external_boundary_flux, :global_weak_form) &&
        x.status === :nonclosure_deferred && !x.multiregion_closure &&
        x.claim_ceiling == screen_only && x.evidence_credit == 0 &&
        isfile(x.source_path) && _rmgco_sha(x.source_path) == x.source_sha256 ||
        throw(ArgumentError("invalid partial global balance authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.observation_hash || throw(ArgumentError("observation hash mismatch"))
    expected
end

function _rmgco_owner(x, name)
    owner = parentmodule(typeof(x))
    isdefined(owner, name) || throw(ArgumentError("upstream validator unavailable: $name"))
    getfield(owner, name)
end

function execute_regional_mhd_global_conservation_observation(q3_upstream,
        traction_request, traction_result, q2_request, q2_result, q2_execution,
        q3_execution, partition_request, partition_result, ledger_request, ledger_result)
    q3 = q3_execution.comparison
    _rmgco_owner(q3, :validate_regional_force_q3_execution)(q3_upstream,
        traction_request, traction_result, q2_request, q2_result, q2_execution, q3_execution)
    _rmgco_owner(ledger_result, :validate_static_mhd_interface_jump_ledger)(
        q3_upstream..., traction_request, traction_result, ledger_request, ledger_result)
    canonical_hash(q3); canonical_hash(ledger_request); canonical_hash(ledger_result)
    q3.q3_result.request_hash == q3.q3_request.request_hash &&
        q3.q3_result.receipt_hash == q3.q3_receipt.receipt_hash ||
        throw(ArgumentError("q3 request/result/receipt identity mismatch"))
    length(q3.q3_region_force) == length(partition_request.regions) &&
        length(ledger_result.entries) == length(partition_request.interfaces) ||
        throw(ArgumentError("regional/interface cardinality mismatch"))
    prh, psh = canonical_hash(partition_request), canonical_hash(partition_result)
    request = q3.q3_request
    ids = Tuple(r.region_id for r in partition_request.regions)
    region_hashes = Tuple(r.region_hash for r in partition_request.regions)
    support_hashes = Tuple(r.region_support_hash for r in partition_request.regions)
    interface_hashes = Tuple(canonical_hash(i) for i in partition_request.interfaces)
    Tuple(e.interface_id for e in ledger_result.entries) ==
        Tuple(i.interface_id for i in partition_request.interfaces) ||
        throw(ArgumentError("interface ordering/identity mismatch"))
    request.partition_request_hash == prh && request.partition_result_hash == psh &&
        request.physical_support_hash == partition_request.physical_support_hash &&
        request.partition_region_ids == ids &&
        request.partition_region_hashes == region_hashes &&
        request.partition_support_hashes == support_hashes &&
        request.partition_interface_hashes == interface_hashes ||
        throw(ArgumentError("partition identity mismatch"))
    q3.candidate_hash == ledger_result.candidate_hash &&
        q3.context_hash == ledger_result.context_hash ||
        throw(ArgumentError("candidate/context mismatch"))
    ledger_result.request_hash == ledger_request.request_hash ||
        throw(ArgumentError("ledger request/result identity mismatch"))
    regions = Tuple((region_id=ids[i], force=_rmgco_vec(q3.q3_region_force[i]))
        for i in eachindex(ids))
    pairs = Tuple((interface_id=e.interface_id, minus_region=e.minus_region_id,
        plus_region=e.plus_region_id, jump_proxy=_rmgco_vec(e.static_conditions[1].proxy_values),
        pair_sum=nothing, contribution_status=:not_surface_contribution)
        for e in ledger_result.entries)
    body = (revision=_RMGCO_REVISION, candidate_hash=q3.candidate_hash,
        context_hash=q3.context_hash, q3_request_hash=request.request_hash,
        q3_result_hash=q3.q3_result.result_hash, q3_receipt_hash=q3.q3_receipt.receipt_hash,
        ledger_request_hash=ledger_request.request_hash,
        ledger_result_hash=ledger_result.result_hash, partition_request_hash=prh,
        partition_result_hash=psh, region_volume_force=regions,
        region_volume_force_total=_rmgco_vec(q3.q3_total_force),
        internal_interface_ledger=pairs, internal_interface_pair_sum=nothing,
        external_boundary_terms=nothing,
        missing_capabilities=(:external_boundary_limit_trace,
            :external_boundary_flux, :global_weak_form), global_residual=nothing,
        global_residual_norm=nothing, status=:nonclosure_deferred,
        multiregion_closure=false, claim_ceiling=screen_only, evidence_credit=0,
        source_path=_RMGCO_SOURCE, source_sha256=_rmgco_sha(_RMGCO_SOURCE))
    x = RegionalMHDGlobalConservationObservationV4(Val(:rmgco_private),
        values(body)..., canonical_hash(body))
    canonical_hash(x)
    x
end

"""Construct the immutable, candidate-bound request envelope."""
function make_regional_mhd_global_conservation_observation_request(
        q3_upstream, traction_request, traction_result, q2_request, q2_result,
        q2_execution, q3_execution, partition_request, partition_result,
        ledger_request, ledger_result)
    obs = execute_regional_mhd_global_conservation_observation(q3_upstream,
        traction_request, traction_result, q2_request, q2_result, q2_execution,
        q3_execution, partition_request, partition_result, ledger_request, ledger_result)
    q3 = q3_execution.comparison
    body = (revision=_RMGCO_REVISION, candidate_hash=obs.candidate_hash,
        context_hash=obs.context_hash, q3_request_hash=obs.q3_request_hash,
        q3_result_hash=obs.q3_result_hash, q3_receipt_hash=obs.q3_receipt_hash,
        partition_request_hash=obs.partition_request_hash,
        partition_result_hash=obs.partition_result_hash,
        ledger_request_hash=obs.ledger_request_hash,
        ledger_result_hash=obs.ledger_result_hash,
        region_ids=Tuple(r.region_id for r in partition_request.regions),
        interface_ids=Tuple(i.interface_id for i in partition_request.interfaces),
        volume_units="N", interface_units="Pa (proxy; not integrated)",
        sign_convention=:minus_outward_plus_inward,
        source_path=_RMGCO_SOURCE, source_sha256=_rmgco_sha(_RMGCO_SOURCE))
    RegionalMHDGlobalConservationObservationRequestV4(values(body)..., canonical_hash(body))
end

"""Execute with a typed result/receipt and an independent replay hash."""
function execute_regional_mhd_global_conservation_observation_typed(args...)
    obs = execute_regional_mhd_global_conservation_observation(args...)
    req = make_regional_mhd_global_conservation_observation_request(args...)
    result_body = (request_hash=canonical_hash(req), receipt_hash=Digest256("0"^64),
        observation_hash=obs.observation_hash, region_volume_force_total=obs.region_volume_force_total,
        status=obs.status)
    # receipt is sealed after the result hash is known; replay is the canonical
    # recomputation of the volume ledger (never an authority claim).
    result0 = RegionalMHDGlobalConservationObservationResultV4(values(result_body)..., Digest256("0"^64))
    rb = merge(semantic_view(result0), (result_hash=canonical_hash(semantic_view(result0)),))
    result = RegionalMHDGlobalConservationObservationResultV4(values(rb)..., canonical_hash(rb))
    receipt_body = (request_hash=canonical_hash(req), observation_hash=obs.observation_hash,
        replay_hash=canonical_hash(obs.region_volume_force_total), source_path=_RMGCO_SOURCE,
        source_sha256=_rmgco_sha(_RMGCO_SOURCE))
    receipt = RegionalMHDGlobalConservationObservationReceiptV4(values(receipt_body)..., canonical_hash(receipt_body))
    final_body = merge(semantic_view(result), (receipt_hash=receipt.receipt_hash,))
    result = RegionalMHDGlobalConservationObservationResultV4(values(final_body)..., canonical_hash(final_body))
    (request=req, result=result, receipt=receipt, observation=obs)
end

validate_regional_mhd_global_conservation_observation(
    x::RegionalMHDGlobalConservationObservationV4) = canonical_hash(x)
