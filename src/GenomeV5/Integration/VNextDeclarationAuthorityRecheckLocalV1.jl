"""Versioned local-profile recheck for the source-backed T0 bundle.

This is an additive adapter.  It consumes an already-built
`VNextT0LocalTransportV1` and a separately owned tuple of declaration records;
it never edits the T0 transport or promotes a legacy projection.  The local
records are compared to the bundle byte-for-byte at the canonical level, then
their source bytes, declaration bytes, locator, factory receipt and declaration
receipt are independently rechecked through the T0 local validation contract.

The only successful state is `local_checked_present`.  G3 feedback remains a
projection carried by the bundle and all three G3 children must remain typed
deferred/absent.  Missing material produces typed absence; contradictory,
foreign, stale or tampered material is deterministic `fail_closed`.  Every
result retains an immutable canonical bundle snapshot and its observed hash.
"""

const VNEXT_AR_LOCAL_SCHEMA_ID_V1 =
    "GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1"
const VNEXT_AR_LOCAL_SCHEMA_VERSION_V1 = "v1"
const VNEXT_AR_LOCAL_REQUIRED_LAYERS_V1 = (:G1, :G2)
const VNEXT_AR_LOCAL_ALL_LAYERS_V1 = (:G1, :G2, :G3)
const VNEXT_AR_LOCAL_G3_CHILD_KINDS_V1 = (:realization, :control, :binding)
const VNEXT_AR_LOCAL_ALLOWED_CHILD_STATUS_V1 = (:terminal_deferred, :typed_absent)
const VNEXT_AR_LOCAL_ERROR_CODES_V1 = (
    :bundle_hash_mismatch, :bundle_status_invalid, :bundle_errors_present,
    :candidate_mismatch, :unknown_layer, :duplicate_layer, :missing_layer,
    :record_type_invalid, :record_bundle_canonical_mismatch,
    :source_ref_mismatch, :declaration_ref_mismatch, :source_hash_mismatch,
    :declaration_hash_mismatch, :source_bytes_mismatch, :declaration_bytes_mismatch,
    :source_locator_mismatch, :locator_mismatch, :factory_receipt_mismatch, :declaration_receipt_mismatch,
    :canonical_equality_mismatch, :feedback_projection_mismatch,
    :duplicate_feedback_target, :unknown_feedback_layer, :foreign_candidate,
    :g3_child_present_forbidden, :g3_child_missing, :g3_child_duplicate,
    :g3_child_status_invalid, :stale_bundle, :program_exception)

const VNEXT_AR_LOCAL_RECORD_V1 = Union{
    VNextT0LocalPresentDeclarationV1, VNextT0LocalAbsentDeclarationV1}

"""Read-only input: the bundle and records remain owned by the caller."""
struct VNextAuthorityRecheckLocalInputV1
    candidate_ref::QualifiedRefV1
    bundle::VNextT0LocalTransportV1
    local_records::Tuple{Vararg{VNEXT_AR_LOCAL_RECORD_V1}}
    function VNextAuthorityRecheckLocalInputV1(candidate_ref::QualifiedRefV1,
            bundle::VNextT0LocalTransportV1, local_records::Tuple)
        new(candidate_ref, bundle, local_records)
    end
end

struct VNextAuthorityRecheckLocalCheckedPresentV1
    candidate_ref::QualifiedRefV1
    g1::VNextT0LocalPresentDeclarationV1
    g2::VNextT0LocalPresentDeclarationV1
    g3::VNextT0LocalPresentDeclarationV1
    feedback::Tuple
    children::NTuple{3,VNextT0LocalChildV1}
    bundle_hash::Digest256
end

struct VNextAuthorityRecheckLocalTypedAbsentV1
    candidate_ref::QualifiedRefV1
    reasons::Tuple{Vararg{Symbol}}
    bundle_hash::Digest256
    g3_children_deferred::Bool
end

struct VNextAuthorityRecheckLocalResultV1{O}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    errors::Tuple{Vararg{Symbol}}
    reasons::Tuple{Vararg{Symbol}}
    output::O
    prior_bundle_bytes::Tuple
    prior_bundle_sha256::Digest256
end

function _ar_local_snapshot(bundle::VNextT0LocalTransportV1)
    Tuple(Vector{UInt8}(codeunits(canonical_json(bundle))))
end

function _ar_local_unique!(xs::Vector{Symbol})
    unique!(xs)
    xs
end

function _ar_local_result(input::VNextAuthorityRecheckLocalInputV1,
        prior_bytes::Tuple, status::Symbol, resolution::Symbol,
        errors::Vector{Symbol}, reasons::Vector{Symbol}, output)
    _ar_local_unique!(errors)
    _ar_local_unique!(reasons)
    VNextAuthorityRecheckLocalResultV1(status, resolution, false, :contract_only,
        Tuple(errors), Tuple(reasons), output, prior_bytes,
        input.bundle.bundle_hash)
end

function _ar_local_fail(input, prior_bytes, code::Symbol; reason::Symbol=code)
    _ar_local_result(input, prior_bytes, :fail_closed, :none, [code], [reason], nothing)
end

function _ar_local_layer_map(items, errors::Vector{Symbol})
    layers = Symbol[]
    for item in items
        layer = try
            getproperty(item, :layer)
        catch
            push!(errors, :record_type_invalid)
            continue
        end
        layer isa Symbol || (push!(errors, :record_type_invalid); continue)
        layer in VNEXT_AR_LOCAL_ALL_LAYERS_V1 || push!(errors, :unknown_layer)
        layer in layers && push!(errors, :duplicate_layer)
        push!(layers, layer)
    end
    for layer in VNEXT_AR_LOCAL_ALL_LAYERS_V1
        count(==(layer), layers) == 1 || push!(errors,
            count(==(layer), layers) == 0 ? :missing_layer : :duplicate_layer)
    end
    Dict(layer => findfirst(x -> getproperty(x, :layer) === layer, items)
        for layer in unique(layers) if layer in VNEXT_AR_LOCAL_ALL_LAYERS_V1)
end

function _ar_local_validate_bundle_and_records(input,
        prior_bytes::Tuple, errors::Vector{Symbol}, reasons::Vector{Symbol})
    bundle = input.bundle
    bundle.candidate_ref == input.candidate_ref || push!(errors, :candidate_mismatch)
    recomputed = try
        vnext_t0_local_bundle_hash_recompute_v1(bundle)
    catch
        push!(errors, :bundle_hash_mismatch)
        nothing
    end
    recomputed === nothing || recomputed == bundle.bundle_hash ||
        push!(errors, :bundle_hash_mismatch)
    bundle.status === :valid || push!(errors, :bundle_status_invalid)
    isempty(bundle.errors) || push!(errors, :bundle_errors_present)

    bundle_map = _ar_local_layer_map(bundle.declarations, errors)
    local_map = _ar_local_layer_map(input.local_records, errors)
    isempty(errors) || return bundle_map, local_map

    for layer in VNEXT_AR_LOCAL_ALL_LAYERS_V1
        bundle_record = bundle.declarations[bundle_map[layer]]
        local_record = input.local_records[local_map[layer]]
        try
            canonical_json(bundle_record) == canonical_json(local_record) ||
                push!(errors, :record_bundle_canonical_mismatch)
        catch
            push!(errors, :canonical_equality_mismatch)
        end
        if bundle_record isa VNextT0LocalPresentDeclarationV1
            local_record isa VNextT0LocalPresentDeclarationV1 ||
                push!(errors, :record_bundle_canonical_mismatch)
            if local_record isa VNextT0LocalPresentDeclarationV1
                append!(errors, _vnl_t0_errors(local_record, input.candidate_ref))
            end
        else
            local_record isa VNextT0LocalAbsentDeclarationV1 ||
                push!(errors, :record_bundle_canonical_mismatch)
            if local_record isa VNextT0LocalAbsentDeclarationV1
                append!(errors, _vnl_t0_absent_errors(local_record, input.candidate_ref))
                push!(reasons, local_record.reason)
            end
        end
    end

    child_layers = Symbol[]
    for kind in VNEXT_AR_LOCAL_G3_CHILD_KINDS_V1
        indices = findall(child -> child.kind === kind, bundle.children)
        isempty(indices) && push!(errors, :g3_child_missing)
        length(indices) > 1 && push!(errors, :g3_child_duplicate)
        isempty(indices) && continue
        child = bundle.children[first(indices)]
        append!(errors, _vnl_t0_child_errors(child, input.candidate_ref, kind))
        child isa VNextT0LocalChildAbsentV1 || push!(errors, :g3_child_present_forbidden)
        if child isa VNextT0LocalChildAbsentV1
            child.status in VNEXT_AR_LOCAL_ALLOWED_CHILD_STATUS_V1 ||
                push!(errors, :g3_child_status_invalid)
        end
        push!(child_layers, kind)
    end
    append!(errors, _vnl_t0_feedback_errors(bundle.feedback,
        input.candidate_ref, bundle.declarations))
    for item in bundle.feedback
        item.candidate_ref == input.candidate_ref || push!(errors, :foreign_candidate)
        item.target_layer in VNEXT_AR_LOCAL_REQUIRED_LAYERS_V1 ||
            push!(errors, :unknown_feedback_layer)
    end
    bundle_map, local_map
end

"""Recheck a local T0 bundle without mutating any input bytes or hashes."""
function vnext_declaration_authority_recheck_local_v1(
        input::VNextAuthorityRecheckLocalInputV1)
    prior_bytes = try
        _ar_local_snapshot(input.bundle)
    catch
        ()
    end
    try
        errors = Symbol[]
        reasons = Symbol[]
        bundle_map, local_map = _ar_local_validate_bundle_and_records(input,
            prior_bytes, errors, reasons)
        !isempty(errors) && return _ar_local_fail(input, prior_bytes, first(errors);
            reason=first(errors))

        g1 = input.local_records[local_map[:G1]]
        g2 = input.local_records[local_map[:G2]]
        g3 = input.local_records[local_map[:G3]]
        g1_present = g1 isa VNextT0LocalPresentDeclarationV1
        g2_present = g2 isa VNextT0LocalPresentDeclarationV1
        g3_present = g3 isa VNextT0LocalPresentDeclarationV1
        if !(g1_present && g2_present && g3_present)
            !g1_present && push!(reasons, :g1_material_absent)
            !g2_present && push!(reasons, :g2_material_absent)
            !g3_present && push!(reasons, :g3_feedback_material_absent)
            output = VNextAuthorityRecheckLocalTypedAbsentV1(input.candidate_ref,
                Tuple(unique(reasons)), input.bundle.bundle_hash, true)
            return _ar_local_result(input, prior_bytes, :typed_absent,
                :terminal_deferred, Symbol[], reasons, output)
        end
        output = VNextAuthorityRecheckLocalCheckedPresentV1(input.candidate_ref,
            g1, g2, g3, input.bundle.feedback, input.bundle.children,
            input.bundle.bundle_hash)
        _ar_local_result(input, prior_bytes, :local_checked_present, :resolved,
            Symbol[], Symbol[], output)
    catch
        _ar_local_fail(input, prior_bytes, :program_exception)
    end
end

vnext_authority_recheck_local_bundle_hash_v1(
    x::VNextAuthorityRecheckLocalResultV1) = x.prior_bundle_sha256
vnext_authority_recheck_local_bundle_bytes_v1(
    x::VNextAuthorityRecheckLocalResultV1) = x.prior_bundle_bytes
