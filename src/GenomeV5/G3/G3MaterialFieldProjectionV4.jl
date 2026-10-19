"""Candidate-bound G3 material-field projection V4 receipt boundary.

V4 wraps only a hash-valid, no-credit V3 screen/deferred receipt. It gives that
projection a new V4 receipt hash, removes caller-settable acceptance/credit
fields, and revalidates both the wrapped V3 receipt and the V4 hash whenever a
semantic view is requested. It does not authenticate the opaque G2 map/frame
references or Jacobian claim carried by V3, and therefore remains screen-only.
Include G3MaterialFieldProjectionV3.jl before this file.
"""

const G3_MFP_V4_SCHEMA_ID = "GenomeV5/G3/G3MaterialFieldProjectionV4"
const G3_MFP_V4_VERSION = "v4"
const G3_MFP_V4_CLAIM_CEILING = :screen_only
const G3_MFP_V4_HASH_DOMAIN = "G3-MFP-V4-projection-receipt"
const _G3MFP_PROJECTION_RECEIPT_V4_SEAL = Ref{Nothing}(nothing)

struct G3MFPProjectionReceiptV4
    upstream_v3_receipt::Union{Nothing,G3MFPProjectionReceiptV3}
    status::Symbol
    resolution::Symbol
    errors::Tuple{Vararg{String}}
    receipt_hash::Digest256
    function G3MFPProjectionReceiptV4(
            upstream_v3_receipt::Union{Nothing,G3MFPProjectionReceiptV3},
            status::Symbol, resolution::Symbol, errors::Tuple{Vararg{String}},
            receipt_hash::Digest256, seal::Base.RefValue{Nothing})
        seal === _G3MFP_PROJECTION_RECEIPT_V4_SEAL ||
            throw(ArgumentError("G3 MFP V4 receipt requires the module seal"))
        new(upstream_v3_receipt, status, resolution, errors, receipt_hash)
    end
end

function _g3mfp4_status_resolution_valid(status::Symbol, resolution::Symbol)
    (status === :terminal_deferred && resolution === :terminal_deferred) ||
    (status === :fail_closed && resolution === :fail_closed) ||
    (status === :evaluated_screen_only && resolution === :screen_only)
end

function _g3mfp4_tensor_spd(k)
    length(k) == 9 || return false
    all(value -> value isa Rational, k) || return false
    a, b, c, d, e, f, g, h, i = k
    b == d && c == g && f == h || return false
    minor1 = a
    minor2 = a * e - b * d
    determinant = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    minor1 > 0 && minor2 > 0 && determinant > 0
end

function _g3mfp4_projected_region_valid(region::G3MFPProjectedRegionV3, heat_power)
    fraction = region.allocation_fraction
    volume = region.physical_volume_m3
    weight = region.normalized_source_weight_m_inv3
    volume > 0 && fraction >= 0 || return false
    weight == fraction / volume || return false
    region.volumetric_source_w_m3 == heat_power * weight || return false
    _g3mfp4_tensor_spd(region.conductivity_tensor_w_m_k)
end

function _g3mfp4_v3_receipt_errors(receipt::G3MFPProjectionReceiptV3)
    errors = String[]
    expected_hash = try
        canonical_hash(_g3mfp3_receipt_content(receipt))
    catch error
        push!(errors, "v3_receipt_content_unreadable:" * string(typeof(error)))
        nothing
    end
    expected_hash === nothing || expected_hash == receipt.receipt_hash ||
        push!(errors, "v3_receipt_hash_mismatch")

    receipt.accepted === false || push!(errors, "v3_receipt_accepted_flag_not_false")
    receipt.claim_ceiling === :screen_only || push!(errors, "v3_receipt_claim_ceiling_not_screen_only")
    receipt.physical_status === :unknown || push!(errors, "v3_receipt_physical_status_not_unknown")
    (receipt.formal_up2_credit === false && receipt.formal_r_credit === false &&
        receipt.discovery_credit === false && receipt.engineering_credit === false) ||
        push!(errors, "v3_receipt_credit_flag_set")
    (receipt.compiler_calls == 0 && receipt.provider_calls == 0 &&
        receipt.mesh_calls == 0 && receipt.solver_calls == 0) ||
        push!(errors, "v3_receipt_execution_count_nonzero")
    _g3mfp4_status_resolution_valid(receipt.status, receipt.resolution) ||
        push!(errors, "v3_receipt_status_resolution_invalid")
    all(item -> item isa String, receipt.errors) || push!(errors, "v3_receipt_errors_malformed")
    all(item -> item isa String, receipt.gaps) || push!(errors, "v3_receipt_gaps_malformed")

    if receipt.status === :fail_closed
        isempty(receipt.errors) && push!(errors, "v3_fail_closed_receipt_lacks_error")
    elseif receipt.status === :terminal_deferred
        isempty(receipt.gaps) && push!(errors, "v3_deferred_receipt_lacks_gap")
    elseif receipt.status === :evaluated_screen_only
        isempty(receipt.errors) || push!(errors, "v3_screen_receipt_has_errors")
        isempty(receipt.gaps) || push!(errors, "v3_screen_receipt_has_gaps")
        receipt.input_provenance in (:synthetic_local, :agent_local_source_record) ||
            push!(errors, "v3_screen_receipt_provenance_invalid")
        receipt.source_power_w !== nothing && receipt.field_power_w !== nothing &&
            receipt.return_power_w !== nothing && receipt.heat_power_w !== nothing ||
            push!(errors, "v3_screen_receipt_power_ledger_missing")
        receipt.energy_residual_w == 0 // 1 || push!(errors, "v3_screen_energy_residual_nonzero")
        receipt.ledger_residual_w == 0 // 1 || push!(errors, "v3_screen_ledger_residual_nonzero")
        receipt.normalized_support_integral == 1 // 1 ||
            push!(errors, "v3_screen_support_integral_not_one")
        !isempty(receipt.regions) || push!(errors, "v3_screen_projected_regions_missing")
        receipt.heat_power_w === nothing || receipt.integrated_heat_power_w == receipt.heat_power_w ||
            push!(errors, "v3_screen_integrated_heat_disagrees")
        if receipt.heat_power_w !== nothing && !isempty(receipt.regions)
            all(region -> _g3mfp4_projected_region_valid(region, receipt.heat_power_w), receipt.regions) ||
                push!(errors, "v3_screen_region_content_invalid")
            sum(region.allocation_fraction for region in receipt.regions; init=0 // 1) == 1 // 1 ||
                push!(errors, "v3_screen_region_fractions_not_conservative")
            sum(region.normalized_source_weight_m_inv3 * region.physical_volume_m3
                for region in receipt.regions; init=0 // 1) == 1 // 1 ||
                push!(errors, "v3_screen_normalized_support_not_conservative")
            sum(region.volumetric_source_w_m3 * region.physical_volume_m3
                for region in receipt.regions; init=0 // 1) == receipt.heat_power_w ||
                push!(errors, "v3_screen_integrated_heat_not_conservative")
        end
    end
    Tuple(unique(errors))
end

function _g3mfp4_upstream_view(receipt::Union{Nothing,G3MFPProjectionReceiptV3})
    receipt === nothing && return nothing
    (schema_id=G3_MFP_V3_SCHEMA_ID, version=G3_MFP_V3_VERSION,
     content=_g3mfp3_receipt_content(receipt), receipt_hash=receipt.receipt_hash)
end

function _g3mfp4_receipt_body(upstream, status::Symbol, resolution::Symbol,
        errors::Tuple{Vararg{String}})
    (schema_id=G3_MFP_V4_SCHEMA_ID, version=G3_MFP_V4_VERSION,
     upstream_v3_receipt=_g3mfp4_upstream_view(upstream),
     status=status, resolution=resolution,
     accepted=false, claim_ceiling=G3_MFP_V4_CLAIM_CEILING,
     physical_status=:unknown, formal_up2_credit=false, formal_r_credit=false,
     discovery_credit=false, engineering_credit=false,
     compiler_calls=0, provider_calls=0, mesh_calls=0, solver_calls=0,
     g2_map_provenance=:opaque_unverified, jacobian_payload_verified=false,
     errors=errors)
end

function _g3mfp4_mint(upstream, status::Symbol, resolution::Symbol, errors)
    error_tuple = Tuple(String.(errors))
    body = _g3mfp4_receipt_body(upstream, status, resolution, error_tuple)
    receipt_hash = canonical_hash((domain=G3_MFP_V4_HASH_DOMAIN, body=body))
    G3MFPProjectionReceiptV4(upstream, status, resolution, error_tuple,
        receipt_hash, _G3MFP_PROJECTION_RECEIPT_V4_SEAL)
end

function _g3mfp4_wrap_v3_receipt(upstream::Any)
    upstream isa G3MFPProjectionReceiptV3 ||
        return _g3mfp4_mint(nothing, :fail_closed, :fail_closed,
            ("upstream_projection_receipt_type_invalid",))
    receipt = upstream::G3MFPProjectionReceiptV3
    validation_errors = _g3mfp4_v3_receipt_errors(receipt)
    isempty(validation_errors) ||
        return _g3mfp4_mint(nothing, :fail_closed, :fail_closed,
            Tuple("upstream_v3_receipt_rejected:" * error for error in validation_errors))
    _g3mfp4_mint(receipt, receipt.status, receipt.resolution, receipt.errors)
end

"""Run the V3 screen projection and wrap its result in the V4 receipt boundary."""
function g3_mfp_project_v4(declaration::Any, source_point::Any=nothing; kwargs...)
    upstream = g3_mfp_project_v3(declaration, source_point; kwargs...)
    _g3mfp4_wrap_v3_receipt(upstream)
end

function g3_mfp_validate_projection_receipt_v4(receipt::Any)
    receipt isa G3MFPProjectionReceiptV4 ||
        return (:invalid, ("projection_receipt_type_invalid",))
    x = receipt::G3MFPProjectionReceiptV4
    errors = String[]
    _g3mfp4_status_resolution_valid(x.status, x.resolution) ||
        push!(errors, "v4_status_resolution_invalid")
    all(item -> item isa String, x.errors) || push!(errors, "v4_errors_malformed")
    if x.upstream_v3_receipt === nothing
        (x.status === :fail_closed && x.resolution === :fail_closed && !isempty(x.errors)) ||
            push!(errors, "v4_absent_upstream_must_be_fail_closed")
    else
        upstream_errors = _g3mfp4_v3_receipt_errors(x.upstream_v3_receipt)
        isempty(upstream_errors) || push!(errors, "v4_upstream_v3_invalid")
        x.status === x.upstream_v3_receipt.status || push!(errors, "v4_status_disagrees_with_upstream")
        x.resolution === x.upstream_v3_receipt.resolution ||
            push!(errors, "v4_resolution_disagrees_with_upstream")
        x.errors == x.upstream_v3_receipt.errors || push!(errors, "v4_errors_disagree_with_upstream")
    end
    expected_hash = try
        canonical_hash((domain=G3_MFP_V4_HASH_DOMAIN,
            body=_g3mfp4_receipt_body(x.upstream_v3_receipt, x.status, x.resolution, x.errors)))
    catch error
        push!(errors, "v4_receipt_content_unreadable:" * string(typeof(error)))
        nothing
    end
    expected_hash === nothing || expected_hash == x.receipt_hash ||
        push!(errors, "v4_receipt_hash_mismatch")
    isempty(errors) ? (:valid, ()) : (:invalid, Tuple(unique(errors)))
end

function semantic_view(receipt::G3MFPProjectionReceiptV4)
    validity, errors = g3_mfp_validate_projection_receipt_v4(receipt)
    validity === :valid || throw(ArgumentError(
        "G3 MFP V4 receipt failed validation: " * join(errors, ", ")))
    merge(_g3mfp4_receipt_body(receipt.upstream_v3_receipt, receipt.status,
        receipt.resolution, receipt.errors), (receipt_hash=receipt.receipt_hash,))
end
