"""Reload-time adapter from the V2 digest-manifest package to binding V2."""

const VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V2 =
    "GenomeV5/Contracts/VNextT1PackageBindingAdapterV2"
const VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V2 = "v2"

struct VNextT1PackageBindingAdapterResultV2
    status::Symbol
    resolution::Symbol
    reason::Symbol
    package_hash::Digest256
    semantic_identity::Digest256
    input::Union{Nothing,VNextT1CandidateBindingInputV2}
    binding::Union{Nothing,VNextT1CandidateBindingReceiptV2}
    input_hash::Digest256
end

semantic_view(x::VNextT1PackageBindingAdapterResultV2) =
    (schema=VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V2,
        version=VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V2, status=x.status,
        resolution=x.resolution, reason=x.reason, package_hash=x.package_hash,
        semantic_identity=x.semantic_identity, input=x.input, binding=x.binding,
        input_hash=x.input_hash)

function _vnext_t1_adapter_v2_result(package, status, resolution, reason, input=nothing, binding=nothing)
    ih = canonical_hash((candidate_ref=package.candidate_ref,
        semantic_identity=package.semantic_identity, package_hash=package.package_hash,
        wire_hash=package.wire.sha256, reason=reason))
    VNextT1PackageBindingAdapterResultV2(status, resolution, reason,
        package.package_hash, package.semantic_identity, input, binding, ih)
end

function _vnext_t1_adapter_v2_carrier_ok(x, zero_allowed=false)
    x isa VNextT1CanonicalBytesV2 || return false
    zero_allowed || !isempty(copy_bytes(x)) || return false
    x.sha256 == Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(copy_bytes(x))))))
end

function _vnext_t1_adapter_v2_fields_ok(package)
    package.candidate_ref.version == "v5" || return :candidate_ref_conflict
    for d in package.declarations
        d.candidate_ref == package.candidate_ref || return :declaration_candidate_conflict
        _vnext_t1_adapter_v2_carrier_ok(d.source_bytes) || return :source_bytes_conflict
        _vnext_t1_adapter_v2_carrier_ok(d.declaration_bytes) || return :declaration_bytes_conflict
        _vnext_t1_adapter_v2_carrier_ok(d.semantic_body_bytes) || return :semantic_bytes_conflict
        _vnext_t1_adapter_v2_carrier_ok(d.factory_receipt_bytes) || return :factory_receipt_conflict
        _vnext_t1_adapter_v2_carrier_ok(d.declaration_receipt_bytes) || return :declaration_receipt_conflict
        d.source_identity_hash == canonical_hash((kind=:source, ref=d.source_ref,
            bytes_sha256=d.source_bytes.sha256)) || return :source_identity_conflict
        d.declaration_identity_hash == canonical_hash((kind=:declaration,
            ref=d.declaration_ref, bytes_sha256=d.declaration_bytes.sha256)) ||
            return :declaration_identity_conflict
    end
    for c in package.children
        c.candidate_ref == package.candidate_ref || return :child_candidate_conflict
        if c.status === :present
            c.source_bytes === nothing && return :child_source_missing
            _vnext_t1_adapter_v2_carrier_ok(c.source_bytes) || return :child_source_conflict
            c.body_hash === nothing && return :child_body_missing
            c.child_identity_hash === nothing && return :child_identity_missing
        elseif c.status in (:typed_absent, :terminal_deferred)
            c.factory_receipt_bytes === nothing && return :child_receipt_missing
            _vnext_t1_adapter_v2_carrier_ok(c.factory_receipt_bytes, true) || return :child_receipt_conflict
            c.factory_receipt_hash == c.factory_receipt_bytes.sha256 || return :child_receipt_conflict
        else
            return :child_status_conflict
        end
    end
    nothing
end

function _vnext_t1_package_binding_adapter_v2_after_validation(
        package::CandidateStatePackageV5NextV2)
    fields = _vnext_t1_adapter_v2_fields_ok(package)
    fields === nothing || return _vnext_t1_adapter_v2_result(package, :fail_closed, :none, fields)
    package.g3_authority.status === :typed_absent &&
        return _vnext_t1_adapter_v2_result(package, :terminal_deferred,
            :terminal_deferred, :g3_typed_absent)
    package.g3_authority.authority_verified ||
        return _vnext_t1_adapter_v2_result(package, :fail_closed, :none,
            :g3_authority_unverified)
    input = VNextT1CandidateBindingInputV2(package.candidate_ref,
        package.semantic_identity, package.package_hash, package.wire)
    _vnext_t1_adapter_v2_result(package, :prepared_not_executed,
        :terminal_deferred, :mapped_prepared_not_executed, input)
end

"""Validate a deserialized package; no original source object is accepted."""
function vnext_t1_package_binding_adapter_v2(
        package::CandidateStatePackageV5NextV2)
    reason = vnext_t1_package_v2_validate(package)
    reason === nothing || return _vnext_t1_adapter_v2_result(package, :fail_closed, :none, reason)
    _vnext_t1_package_binding_adapter_v2_after_validation(package)
end

function vnext_t1_package_binding_adapter_v2(package::CandidateStatePackageV5NextV2,
        observations::Tuple{Vararg{VNextT1CandidateBindingInputV2}})
    base = vnext_t1_package_binding_adapter_v2(package)
    base.input === nothing && return base
    binding = vnext_t1_candidate_binding_v2(base.input, observations)
    binding.status === :fail_closed && return _vnext_t1_adapter_v2_result(package,
        :fail_closed, :none, binding.reason, base.input, binding)
    _vnext_t1_adapter_v2_result(package, :prepared_not_executed,
        :terminal_deferred, :mapped_prepared_not_executed, base.input, binding)
end

export VNextT1PackageBindingAdapterResultV2,vnext_t1_package_binding_adapter_v2
