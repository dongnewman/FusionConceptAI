"""AD-34 T0 authority recheck typed-absent scaffold.

This additive file is intentionally not included by FusionConceptAI.jl. It
consumes a read-only T0 bundle and the current G3 V1 declaration shape. The
legacy G3 authority is only a six-field projection. It can expose an internal
contradiction, but it cannot provide declaration identity, canonical bytes, or
a source receipt. A checked-present result therefore requires an independently
owned T0 authority record; synthetic, ref-only, and fixture records are
rejected. No T1, package, registry, or physical path is called here.
"""

const VNEXT_AR_SCHEMA_ID = "GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1"
const VNEXT_AR_SCHEMA_VERSION = "v1"
const VNEXT_AR_REQUIRED_LAYERS = (:G1, :G2)
const VNEXT_AR_LEGACY_STATUS_MAP = (
    actual = (:typed_absent, :terminal_deferred, :legacy_actual_without_declaration_authority),
    missing = (:typed_absent, :terminal_deferred, :legacy_missing_authority),
    historical_absent = (:typed_absent, :terminal_deferred, :legacy_historical_absent_authority),
    stale = (:fail_closed, :none, :legacy_stale_authority),
    contradictory = (:fail_closed, :none, :legacy_contradictory_authority),
    unknown = (:fail_closed, :none, :unmapped_legacy_authority_status))
const VNEXT_AR_ERROR_CODES = (
    :none, :t0_bundle_hash_mismatch, :program_exception,
    :duplicate_upstream_authority_layer, :missing_upstream_authority_layer,
    :unknown_upstream_authority_layer, :upstream_authority_candidate_mismatch,
    :declaration_candidate_mismatch,
    :unknown_target_layer, :legacy_target_authority_layer_or_candidate_mismatch,
    :legacy_target_upstream_projection_mismatch,
    :duplicate_or_ambiguous_feedback_target, :duplicate_feedback_target_id,
    :synthetic_authority_rejected, :ref_only_authority_rejected,
    :fixture_authority_rejected, :fresh_authority_missing_field,
    :fresh_authority_bundle_candidate_mismatch,
    :fresh_authority_bundle_layer_mismatch, :fresh_authority_bytes_mismatch,
    :fresh_authority_declaration_hash_mismatch,
    :fresh_authority_receipt_missing)

_vnext_ar_sha256(bytes::AbstractVector{UInt8}) =
    Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))

struct VNextT0BundleSourceV1{N}
    canonical_bytes::NTuple{N,UInt8}
    canonical_sha256::Digest256
    function VNextT0BundleSourceV1(bytes::AbstractVector{UInt8}, expected::Digest256)
        owned = Tuple(UInt8.(bytes))
        actual = _vnext_ar_sha256(collect(owned))
        actual == expected || throw(ArgumentError("t0_bundle_hash_mismatch"))
        new{length(owned)}(owned, actual)
    end
end
VNextT0BundleSourceV1(bytes::AbstractVector{UInt8}) =
    VNextT0BundleSourceV1(bytes, _vnext_ar_sha256(bytes))
vnext_t0_bundle_bytes_v1(x::VNextT0BundleSourceV1) = collect(x.canonical_bytes)

"""A record that may only become checked-present when origin is fresh T0-owned."""
struct VNextT0OwnedAuthorityRecordV1
    layer::Symbol
    candidate_ref::QualifiedRefV1
    declaration_ref::Union{Nothing,QualifiedRefV1}
    declaration_hash::Union{Nothing,Digest256}
    canonical_bytes::Union{Nothing,Tuple}
    source_receipt_ref::Union{Nothing,QualifiedRefV1}
    status::Symbol
    attestation::Symbol
    origin::Symbol
    function VNextT0OwnedAuthorityRecordV1(layer::Symbol,
            candidate_ref::QualifiedRefV1,
            declaration_ref::Union{Nothing,QualifiedRefV1},
            declaration_hash::Union{Nothing,Digest256},
            canonical_bytes,
            source_receipt_ref::Union{Nothing,QualifiedRefV1},
            status::Symbol, attestation::Symbol, origin::Symbol)
        layer in (:G1, :G2) || throw(ArgumentError("unknown_upstream_authority_layer"))
        status in (:actual, :missing, :historical_absent, :stale, :contradictory) ||
            throw(ArgumentError("unmapped_legacy_authority_status"))
        origin in (:fresh_t0_owned, :synthetic, :ref_only, :fixture, :typed_absent) ||
            throw(ArgumentError("program_exception"))
        owned = canonical_bytes === nothing ? nothing : Tuple(UInt8.(canonical_bytes))
        new(layer, candidate_ref, declaration_ref, declaration_hash, owned,
            source_receipt_ref, status, attestation, origin)
    end
end

struct VNextAuthorityRecheckInputV1{D}
    candidate_ref::QualifiedRefV1
    t0_bundle::VNextT0BundleSourceV1
    declaration::D
    fresh_authority::Union{Nothing,VNextT0OwnedAuthorityRecordV1}
end
VNextAuthorityRecheckInputV1(candidate_ref::QualifiedRefV1,
    t0_bundle::VNextT0BundleSourceV1, declaration) =
    VNextAuthorityRecheckInputV1(candidate_ref, t0_bundle, declaration, nothing)

struct VNextTypedAbsentLayerAuthorityV1
    layer::Symbol
    legacy_status::Symbol
    reason::Symbol
    resolution::Symbol
    absence_digest::Digest256
end

struct VNextTypedAbsentAuthorityV1
    candidate_ref::QualifiedRefV1
    layers::NTuple{2,VNextTypedAbsentLayerAuthorityV1}
    reason::Symbol
    absence_digest::Digest256
end

struct VNextCheckedPresentAuthorityV1
    candidate_ref::QualifiedRefV1
    layer::Symbol
    declaration_ref::QualifiedRefV1
    declaration_hash::Digest256
    canonical_bytes_hash::Digest256
    source_receipt_ref::QualifiedRefV1
    status::Symbol
    attestation::Symbol
end

struct VNextAuthorityRecheckResultV1{O}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    errors::Tuple{Vararg{Symbol}}
    reasons::Tuple{Vararg{Symbol}}
    output::O
    output_hash::Digest256
    prior_bundle_bytes::Tuple
    prior_bundle_sha256::Digest256
end

_vnext_ar_ref_text(::Nothing) = "null"
_vnext_ar_ref_text(x::QualifiedRefV1) = string(x.id, "@", x.version)
_vnext_ar_digest_text(::Nothing) = "null"
_vnext_ar_digest_text(x::Digest256) = x.value
function _vnext_ar_contract_text(x::GenomeContractRef)
    string(x.uri, "@", x.version, ":", x.schema_hash.value, ":",
        x.canonicalization_hash.value, ":", x.compatibility_profile)
end
_vnext_ar_contract_text(::Nothing) = "null"

function _vnext_ar_legacy_authority_bytes(a)
    fields = ("layer=" * String(a.layer),
        "candidate_ref=" * _vnext_ar_ref_text(a.candidate_ref),
        "contract_ref=" * _vnext_ar_contract_text(a.contract_ref),
        "contract_hash=" * _vnext_ar_digest_text(a.contract_hash),
        "status=" * String(a.status),
        "attestation=" * String(a.attestation))
    Vector{UInt8}(codeunits(join(fields, "\0")))
end
_vnext_ar_legacy_authority_hash(a) = _vnext_ar_sha256(_vnext_ar_legacy_authority_bytes(a))

function _vnext_ar_target_key(target)
    (target.target_layer, target.target_path, target.quantity, target.unit,
        target.direction, target.sign, target.source_id, target.owner_scope)
end
function _vnext_ar_target_key_text(key)
    string(key[1], "\0", key[2], "\0", key[3], "\0", repr(key[4]), "\0",
        key[5], "\0", key[6], "\0", key[7], "\0", key[8])
end
_vnext_ar_target_key_hash(target) =
    digest256_text("ad34:target-key:v1\0" * _vnext_ar_target_key_text(_vnext_ar_target_key(target)))

function _vnext_ar_absence_digest(candidate::QualifiedRefV1, layer::Symbol,
        reason::Symbol, bundle_hash::Digest256)
    digest256_text(string("ad34:authority-absence:v1\0", _vnext_ar_ref_text(candidate),
        "\0", layer, "\0", reason, "\0", bundle_hash.value))
end

function _vnext_ar_result(status::Symbol, resolution::Symbol,
        errors::Vector{Symbol}, reasons::Vector{Symbol}, output,
        input::VNextAuthorityRecheckInputV1)
    unique!(errors); unique!(reasons)
    output_hash = output === nothing ?
        digest256_text(string("ad34:recheck-output:none:v1\0", status, "\0",
            join(String.(errors), ","), "\0", input.t0_bundle.canonical_sha256.value)) :
        digest256_text(string("ad34:recheck-output:v1\0", status, "\0",
            repr(output), "\0", input.t0_bundle.canonical_sha256.value))
    VNextAuthorityRecheckResultV1(status, resolution, false, :contract_only,
        Tuple(errors), Tuple(reasons), output, output_hash,
        input.t0_bundle.canonical_bytes, input.t0_bundle.canonical_sha256)
end

function _vnext_ar_fail(input, code::Symbol; reason::Symbol=code)
    _vnext_ar_result(:fail_closed, :none, [code], [reason], nothing, input)
end

function _vnext_ar_pair(declaration, candidate_ref::QualifiedRefV1)
    errors = Symbol[]
    declaration.candidate_ref == candidate_ref ||
        push!(errors, :declaration_candidate_mismatch)
    upstream = Tuple(declaration.upstream_authority)
    all(a -> a.layer in VNEXT_AR_REQUIRED_LAYERS, upstream) ||
        push!(errors, :unknown_upstream_authority_layer)
    candidate_ok = all(a -> a.candidate_ref == candidate_ref, upstream)
    candidate_ok || push!(errors, :upstream_authority_candidate_mismatch)
    for layer in VNEXT_AR_REQUIRED_LAYERS
        n = count(a -> a.layer === layer, upstream)
        n == 1 && continue
        push!(errors, n == 0 ? :missing_upstream_authority_layer :
            :duplicate_upstream_authority_layer)
    end
    isempty(errors) || return nothing, errors
    by_layer = Dict(a.layer => a for a in upstream)
    keys_seen = Any[]
    ids_seen = String[]
    for target in Tuple(declaration.feedback_targets)
        target.target_layer in VNEXT_AR_REQUIRED_LAYERS ||
            push!(errors, :unknown_target_layer)
        if target.target_layer in VNEXT_AR_REQUIRED_LAYERS
            authority = target.authority
            authority.layer === target.target_layer ||
                push!(errors, :legacy_target_authority_layer_or_candidate_mismatch)
            authority.candidate_ref == candidate_ref ||
                push!(errors, :legacy_target_authority_layer_or_candidate_mismatch)
            authority_bytes = _vnext_ar_legacy_authority_bytes(authority)
            upstream_bytes = _vnext_ar_legacy_authority_bytes(by_layer[target.target_layer])
            authority_bytes == upstream_bytes ||
                push!(errors, :legacy_target_upstream_projection_mismatch)
        end
        key = _vnext_ar_target_key(target)
        any(previous -> previous == key, keys_seen) &&
            push!(errors, :duplicate_or_ambiguous_feedback_target)
        push!(keys_seen, key)
        id = String(target.target_id)
        id in ids_seen && push!(errors, :duplicate_feedback_target_id)
        push!(ids_seen, id)
    end
    unique!(errors)
    isempty(errors) ? (by_layer, nothing) : (nothing, errors)
end

function _vnext_ar_legacy_absent(candidate_ref, by_layer, bundle_hash)
    outputs = VNextTypedAbsentLayerAuthorityV1[]
    reasons = Symbol[]
    for layer in VNEXT_AR_REQUIRED_LAYERS
        authority = by_layer[layer]
        mapped = authority.status === :actual ? VNEXT_AR_LEGACY_STATUS_MAP.actual :
            authority.status === :missing ? VNEXT_AR_LEGACY_STATUS_MAP.missing :
            authority.status === :historical_absent ? VNEXT_AR_LEGACY_STATUS_MAP.historical_absent :
            authority.status === :stale ? VNEXT_AR_LEGACY_STATUS_MAP.stale :
            authority.status === :contradictory ? VNEXT_AR_LEGACY_STATUS_MAP.contradictory :
            VNEXT_AR_LEGACY_STATUS_MAP.unknown
        mapped[1] === :fail_closed && return nothing, [mapped[3]]
        reason = mapped[3]
        push!(reasons, reason)
        push!(outputs, VNextTypedAbsentLayerAuthorityV1(layer, authority.status,
            reason, mapped[2], _vnext_ar_absence_digest(candidate_ref, layer,
                reason, bundle_hash)))
    end
    absent = VNextTypedAbsentAuthorityV1(candidate_ref, (outputs[1], outputs[2]),
        :legacy_authority_gap,
        digest256_text(string("ad34:authority-absence-bundle:v1\0",
            bundle_hash.value, "\0", join(String.(reasons), ","))))
    absent, reasons
end

function _vnext_ar_check_fresh(input, record::VNextT0OwnedAuthorityRecordV1)
    record.origin === :fresh_t0_owned ||
        return _vnext_ar_fail(input, record.origin === :synthetic ?
            :synthetic_authority_rejected : record.origin === :ref_only ?
            :ref_only_authority_rejected : record.origin === :fixture ?
            :fixture_authority_rejected : :fresh_authority_missing_field)
    record.candidate_ref == input.candidate_ref ||
        return _vnext_ar_fail(input, :fresh_authority_bundle_candidate_mismatch)
    all(x -> x !== nothing, (record.declaration_ref, record.declaration_hash,
        record.canonical_bytes, record.source_receipt_ref)) ||
        return _vnext_ar_fail(input, :fresh_authority_missing_field)
    _vnext_ar_sha256(collect(record.canonical_bytes)) == record.declaration_hash ||
        return _vnext_ar_fail(input, :fresh_authority_declaration_hash_mismatch)
    record.status === :actual || return _vnext_ar_fail(input, :fresh_authority_missing_field)
    record.attestation === :trusted_receipt ||
        return _vnext_ar_fail(input, :fresh_authority_receipt_missing)
    record.layer in VNEXT_AR_REQUIRED_LAYERS ||
        return _vnext_ar_fail(input, :unknown_upstream_authority_layer)
    checked = VNextCheckedPresentAuthorityV1(input.candidate_ref, record.layer,
        record.declaration_ref, record.declaration_hash,
        _vnext_ar_sha256(collect(record.canonical_bytes)), record.source_receipt_ref,
        record.status, record.attestation)
    _vnext_ar_result(:checked_present, :resolved, Symbol[], Symbol[], checked, input)
end

function vnext_declaration_authority_recheck_v1(input::VNextAuthorityRecheckInputV1)
    try
        if input.t0_bundle.canonical_sha256 !=
                _vnext_ar_sha256(vnext_t0_bundle_bytes_v1(input.t0_bundle))
            return _vnext_ar_fail(input, :t0_bundle_hash_mismatch)
        end
        input.declaration.candidate_ref == input.candidate_ref ||
            return _vnext_ar_fail(input, :declaration_candidate_mismatch)
        input.fresh_authority !== nothing &&
            return _vnext_ar_check_fresh(input, input.fresh_authority)
        by_layer, pair_errors = _vnext_ar_pair(input.declaration, input.candidate_ref)
        pair_errors !== nothing && return _vnext_ar_result(:fail_closed, :none,
            pair_errors, pair_errors, nothing, input)
        absent, reasons = _vnext_ar_legacy_absent(input.candidate_ref, by_layer,
            input.t0_bundle.canonical_sha256)
        absent === nothing && return _vnext_ar_result(:fail_closed, :none,
            reasons, reasons, nothing, input)
        _vnext_ar_result(:typed_absent, :terminal_deferred, Symbol[], reasons,
            absent, input)
    catch
        _vnext_ar_fail(input, :program_exception)
    end
end

vnext_authority_recheck_output_hash_v1(x::VNextAuthorityRecheckResultV1) = x.output_hash
vnext_authority_recheck_bundle_hash_v1(x::VNextAuthorityRecheckResultV1) = x.prior_bundle_sha256
