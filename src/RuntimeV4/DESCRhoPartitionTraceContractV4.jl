# Candidate-bound structural rho partition and oriented trace specification.
#
# This edge seals an exact partition of the positive-rho domain and a paired
# trace sampling map drawn from accepted DESC field-basis samples.  It does
# not claim that the declared Cartesian normals were computed by DESC, execute
# an interface provider, solve a multi-region system, or emit evidence.

using FusionConceptAI
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _DRP_REVISION = "runtime-v4-desc-rho-partition-trace-v2"
const _DRP_SCHEMA =
    "fusionconceptai:runtime-v4-desc-rho-partition-trace-specification"
const _DRP_TOKEN = Val(:desc_rho_partition_trace_private)
const _DRP_POSITION_ATOL_M = 1.0e-10
const _DRP_FIELD_ATOL = 1.0e-10
const _DRP_NORMAL_ATOL = 1.0e-12

function _drp_finite(value, field::String)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$field must be finite"))
    result
end

function _drp_text(value, field::String)
    typeof(value) === String ||
        throw(ArgumentError("$field must be an immutable String"))
    result = strip(value)
    !isempty(result) && isvalid(result) ||
        throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(result)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', result)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(result)
end

function _drp_vector3(value, field::String)
    value isa Tuple && !(value isa NamedTuple) && length(value) == 3 ||
        throw(ArgumentError("$field must be an immutable 3-tuple"))
    ntuple(i -> _drp_finite(value[i], field), 3)
end

function _drp_region_body(region_id, rho_lower, rho_upper,
        parent_support_hash, support_hash)
    (region_id=region_id, rho_lower=rho_lower, rho_upper=rho_upper,
     parent_physical_support_hash=parent_support_hash,
     region_support_hash=support_hash)
end

struct DESCRhoRegionV4
    region_id::String
    rho_lower::Float64
    rho_upper::Float64
    parent_physical_support_hash::Digest256
    region_support_hash::Digest256
    region_hash::Digest256
    function DESCRhoRegionV4(token::Val{:desc_rho_partition_trace_private},
            fields...)
        token === _DRP_TOKEN ||
            throw(ArgumentError("private rho region constructor"))
        new(fields...)
    end
end

function DESCRhoRegionV4(region_id, rho_lower, rho_upper,
        parent_support_hash::Digest256)
    id = _drp_text(region_id, "region_id")
    lower = _drp_finite(rho_lower, "rho_lower")
    upper = _drp_finite(rho_upper, "rho_upper")
    0.0 <= lower < upper <= 1.0 ||
        throw(ArgumentError("rho interval must be inside the unit domain"))
    support_hash = canonical_hash((support_kind=:candidate_rho_subdomain,
        parent_physical_support_hash=parent_support_hash, region_id=id,
        rho_lower=lower, rho_upper=upper))
    body = _drp_region_body(id, lower, upper, parent_support_hash,
        support_hash)
    DESCRhoRegionV4(_DRP_TOKEN, body..., canonical_hash(body))
end

semantic_view(x::DESCRhoRegionV4) = _drp_region_body(x.region_id,
    x.rho_lower, x.rho_upper, x.parent_physical_support_hash,
    x.region_support_hash)

function canonical_hash(x::DESCRhoRegionV4)
    _drp_text(x.region_id, "region_id") == x.region_id ||
        throw(ArgumentError("rho region ID is not canonical"))
    0.0 <= x.rho_lower < x.rho_upper <= 1.0 ||
        throw(ArgumentError("rho region is outside the unit domain"))
    expected_support = canonical_hash((support_kind=:candidate_rho_subdomain,
        parent_physical_support_hash=x.parent_physical_support_hash,
        region_id=x.region_id, rho_lower=x.rho_lower, rho_upper=x.rho_upper))
    expected_support == x.region_support_hash ||
        throw(ArgumentError("rho region support hash mismatch"))
    expected = canonical_hash(semantic_view(x))
    expected == x.region_hash ||
        throw(ArgumentError("rho region hash mismatch"))
    expected
end

function _drp_trace_body(source_sample_hash, point_hash, rho, theta, zeta,
        position, B, F, sqrt_g, trace_side, declared_normal)
    (source_basis_sample_hash=source_sample_hash, point_hash=point_hash,
     rho=rho, theta_rad=theta, zeta_rad=zeta,
     cartesian_position_xyz_m=position, B_cartesian_xyz_T=B,
     F_cartesian_xyz_N_m3=F, sqrt_g_m3=sqrt_g, trace_side=trace_side,
     declared_cartesian_normal_xyz=declared_normal)
end

"""One exact basis sample viewed from one declared side of an interface."""
struct DESCRhoTraceSampleV4
    source_basis_sample_hash::Digest256
    point_hash::Digest256
    rho::Float64
    theta_rad::Float64
    zeta_rad::Float64
    cartesian_position_xyz_m::NTuple{3,Float64}
    B_cartesian_xyz_T::NTuple{3,Float64}
    F_cartesian_xyz_N_m3::NTuple{3,Float64}
    sqrt_g_m3::Float64
    trace_side::Symbol
    declared_cartesian_normal_xyz::NTuple{3,Float64}
    sample_hash::Digest256
    function DESCRhoTraceSampleV4(
            token::Val{:desc_rho_partition_trace_private}, fields...)
        token === _DRP_TOKEN ||
            throw(ArgumentError("private rho trace-sample constructor"))
        new(fields...)
    end
end

function make_desc_rho_trace_sample(basis_sample, trace_side::Symbol,
        declared_cartesian_normal_xyz)
    trace_side in (:minus, :plus) ||
        throw(ArgumentError("trace side must be minus or plus"))
    canonical_hash(basis_sample)
    position = _drp_vector3(basis_sample.cartesian_position_xyz_m,
        "Cartesian trace position")
    B = _drp_vector3(basis_sample.B_cartesian_xyz_T, "Cartesian B")
    F = _drp_vector3(basis_sample.F_cartesian_xyz_N_m3, "Cartesian F")
    normal = _drp_vector3(declared_cartesian_normal_xyz,
        "declared Cartesian normal")
    isapprox(sum(component^2 for component in normal), 1.0;
        atol=_DRP_NORMAL_ATOL, rtol=_DRP_NORMAL_ATOL) ||
        throw(ArgumentError("declared Cartesian normal must have unit length"))
    body = _drp_trace_body(canonical_hash(basis_sample),
        basis_sample.point_hash, _drp_finite(basis_sample.rho, "trace rho"),
        _drp_finite(basis_sample.theta_rad, "trace theta"),
        _drp_finite(basis_sample.zeta_rad, "trace zeta"), position, B, F,
        _drp_finite(basis_sample.sqrt_g_m3, "trace sqrt(g)"), trace_side,
        normal)
    DESCRhoTraceSampleV4(_DRP_TOKEN, body..., canonical_hash(body))
end

semantic_view(x::DESCRhoTraceSampleV4) = _drp_trace_body(
    x.source_basis_sample_hash, x.point_hash, x.rho, x.theta_rad,
    x.zeta_rad, x.cartesian_position_xyz_m, x.B_cartesian_xyz_T,
    x.F_cartesian_xyz_N_m3, x.sqrt_g_m3, x.trace_side,
    x.declared_cartesian_normal_xyz)

function canonical_hash(x::DESCRhoTraceSampleV4)
    all(isfinite, (x.rho, x.theta_rad, x.zeta_rad)) &&
        0.0 < x.rho <= 1.0 && x.sqrt_g_m3 > 0.0 ||
        throw(ArgumentError("rho trace coordinates or sqrt(g) are invalid"))
    x.trace_side in (:minus, :plus) ||
        throw(ArgumentError("invalid trace side"))
    all(isfinite, x.cartesian_position_xyz_m) &&
        all(isfinite, x.B_cartesian_xyz_T) &&
        all(isfinite, x.F_cartesian_xyz_N_m3) && isfinite(x.sqrt_g_m3) ||
        throw(ArgumentError("rho trace sample contains non-finite values"))
    isapprox(sum(component^2 for component in
            x.declared_cartesian_normal_xyz), 1.0;
        atol=_DRP_NORMAL_ATOL, rtol=_DRP_NORMAL_ATOL) ||
        throw(ArgumentError("declared Cartesian normal is not unit length"))
    expected = canonical_hash(semantic_view(x))
    expected == x.sample_hash ||
        throw(ArgumentError("rho trace-sample hash mismatch"))
    expected
end

function _drp_interface_body(interface_id, minus_region_id, plus_region_id,
        rho_level, minus_trace, plus_trace)
    (interface_id=interface_id, minus_region_id=minus_region_id,
     plus_region_id=plus_region_id, rho_level=rho_level,
     minus_trace=minus_trace, plus_trace=plus_trace)
end

struct DESCRhoInterfaceV4
    interface_id::String
    minus_region_id::String
    plus_region_id::String
    rho_level::Float64
    minus_trace::Tuple{Vararg{DESCRhoTraceSampleV4}}
    plus_trace::Tuple{Vararg{DESCRhoTraceSampleV4}}
    interface_hash::Digest256
    function DESCRhoInterfaceV4(
            token::Val{:desc_rho_partition_trace_private}, fields...)
        token === _DRP_TOKEN ||
            throw(ArgumentError("private rho interface constructor"))
        new(fields...)
    end
end

function DESCRhoInterfaceV4(interface_id, minus_region_id, plus_region_id,
        rho_level, minus_trace, plus_trace)
    id = _drp_text(interface_id, "interface_id")
    minus_id = _drp_text(minus_region_id, "minus_region_id")
    plus_id = _drp_text(plus_region_id, "plus_region_id")
    minus_id != plus_id ||
        throw(ArgumentError("interface regions must differ"))
    level = _drp_finite(rho_level, "rho_level")
    0.0 < level < 1.0 ||
        throw(ArgumentError("rho interface must be internal to the unit domain"))
    minus = Tuple(minus_trace)
    plus = Tuple(plus_trace)
    !isempty(minus) && length(minus) == length(plus) &&
        all(x -> typeof(x) === DESCRhoTraceSampleV4, minus) &&
        all(x -> typeof(x) === DESCRhoTraceSampleV4, plus) ||
        throw(ArgumentError("interface traces must be nonempty paired typed tuples"))
    body = _drp_interface_body(id, minus_id, plus_id, level, minus, plus)
    result = DESCRhoInterfaceV4(_DRP_TOKEN, body..., canonical_hash(body))
    canonical_hash(result)
    result
end


semantic_view(x::DESCRhoInterfaceV4) = _drp_interface_body(x.interface_id,
    x.minus_region_id, x.plus_region_id, x.rho_level, x.minus_trace,
    x.plus_trace)

function canonical_hash(x::DESCRhoInterfaceV4)
    _drp_text(x.interface_id, "interface_id") == x.interface_id &&
        _drp_text(x.minus_region_id, "minus_region_id") ==
            x.minus_region_id &&
        _drp_text(x.plus_region_id, "plus_region_id") == x.plus_region_id &&
        x.minus_region_id != x.plus_region_id && 0.0 < x.rho_level < 1.0 ||
        throw(ArgumentError("rho interface identity or level is invalid"))
    !isempty(x.minus_trace) &&
        length(x.minus_trace) == length(x.plus_trace) ||
        throw(ArgumentError("rho interface trace pairing is incomplete"))
    seen = Digest256[]
    for (minus, plus) in zip(x.minus_trace, x.plus_trace)
        canonical_hash(minus)
        canonical_hash(plus)
        minus.trace_side === :minus && plus.trace_side === :plus ||
            throw(ArgumentError("rho interface trace sides are reversed"))
        minus.rho == x.rho_level && plus.rho == x.rho_level ||
            throw(ArgumentError("trace sample is off the declared rho level"))
        minus.source_basis_sample_hash == plus.source_basis_sample_hash &&
            minus.point_hash == plus.point_hash ||
            throw(ArgumentError("paired traces do not name one basis sample"))
        push!(seen, minus.source_basis_sample_hash)
        minus.theta_rad == plus.theta_rad && minus.zeta_rad == plus.zeta_rad &&
            minus.sqrt_g_m3 == plus.sqrt_g_m3 ||
            throw(ArgumentError("paired trace coordinates differ"))
        all(isapprox(minus.cartesian_position_xyz_m[i],
                plus.cartesian_position_xyz_m[i]; atol=_DRP_POSITION_ATOL_M,
                rtol=1.0e-12) for i in 1:3) ||
            throw(ArgumentError("paired trace positions differ"))
        all(isapprox(minus.B_cartesian_xyz_T[i], plus.B_cartesian_xyz_T[i];
                atol=_DRP_FIELD_ATOL, rtol=1.0e-12) &&
            isapprox(minus.F_cartesian_xyz_N_m3[i],
                plus.F_cartesian_xyz_N_m3[i]; atol=_DRP_FIELD_ATOL,
                rtol=1.0e-12) for i in 1:3) ||
            throw(ArgumentError("paired trace field samples differ"))
        all(isapprox(minus.declared_cartesian_normal_xyz[i],
                -plus.declared_cartesian_normal_xyz[i];
                atol=_DRP_NORMAL_ATOL, rtol=_DRP_NORMAL_ATOL)
            for i in 1:3) ||
            throw(ArgumentError("declared trace normals are not opposite"))
    end
    length(unique(seen)) == length(seen) ||
        throw(ArgumentError("rho interface repeats a basis sample"))
    expected = canonical_hash(semantic_view(x))
    expected == x.interface_hash ||
        throw(ArgumentError("rho interface hash mismatch"))
    expected
end


function _drp_request_body(context_hash, candidate_hash, basis_request_hash,
        basis_result_hash, basis_receipt_hash, compatibility_resolution_hash,
        compatibility_certificate_hash, compiled_prefix_hash,
        physical_subject_hash, physical_declaration_hash,
        physical_support_hash, coordinate_chart_hash,
        geometry_graph_binding_hash, coordinate_program_hash,
        metric_program_hash, geometry_payload_hash, execution_request_hash,
        execution_result_hash, execution_receipt_hash, field_request_hash,
        field_result_hash, field_receipt_hash, equilibrium_output_sha256,
        point_hashes, basis_sample_hashes, rho_domain_lower, rho_domain_upper,
        regions, interfaces)
    (revision=_DRP_REVISION, schema=_DRP_SCHEMA,
     request_kind=:candidate_bound_desc_rho_partition_trace_specification,
     context_hash=context_hash, candidate_hash=candidate_hash,
     basis_request_hash=basis_request_hash, basis_result_hash=basis_result_hash,
     basis_receipt_hash=basis_receipt_hash,
     compatibility_resolution_hash=compatibility_resolution_hash,
     compatibility_certificate_hash=compatibility_certificate_hash,
     compiled_prefix_hash=compiled_prefix_hash,
     physical_subject_hash=physical_subject_hash,
     physical_declaration_hash=physical_declaration_hash,
     physical_support_hash=physical_support_hash,
     coordinate_chart_hash=coordinate_chart_hash,
     geometry_graph_binding_hash=geometry_graph_binding_hash,
     coordinate_program_hash=coordinate_program_hash,
     metric_program_hash=metric_program_hash,
     geometry_payload_hash=geometry_payload_hash,
     execution_request_hash=execution_request_hash,
     execution_result_hash=execution_result_hash,
     execution_receipt_hash=execution_receipt_hash,
     field_request_hash=field_request_hash, field_result_hash=field_result_hash,
     field_receipt_hash=field_receipt_hash,
     equilibrium_output_sha256=equilibrium_output_sha256,
     point_hashes=point_hashes, basis_sample_hashes=basis_sample_hashes,
     rho_domain_lower=rho_domain_lower, rho_domain_upper=rho_domain_upper,
     regions=regions, interfaces=interfaces, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     interface_trace_executed=false, emits_evidence=false,
     p5_ready=false, credible_physical_device_count=0)
end

struct DESCRhoPartitionRequestV4
    revision::String
    schema::String
    request_kind::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    basis_request_hash::Digest256
    basis_result_hash::Digest256
    basis_receipt_hash::Digest256
    compatibility_resolution_hash::Digest256
    compatibility_certificate_hash::Digest256
    compiled_prefix_hash::Digest256
    physical_subject_hash::Digest256
    physical_declaration_hash::Digest256
    physical_support_hash::Digest256
    coordinate_chart_hash::Digest256
    geometry_graph_binding_hash::Digest256
    coordinate_program_hash::Digest256
    metric_program_hash::Digest256
    geometry_payload_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    field_request_hash::Digest256
    field_result_hash::Digest256
    field_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    point_hashes::Tuple{Vararg{Digest256}}
    basis_sample_hashes::Tuple{Vararg{Digest256}}
    rho_domain_lower::Float64
    rho_domain_upper::Float64
    regions::Tuple{Vararg{DESCRhoRegionV4}}
    interfaces::Tuple{Vararg{DESCRhoInterfaceV4}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    interface_trace_executed::Bool
    emits_evidence::Bool
    p5_ready::Bool
    credible_physical_device_count::Int
    request_hash::Digest256
    function DESCRhoPartitionRequestV4(
            token::Val{:desc_rho_partition_trace_private}, fields...)
        token === _DRP_TOKEN ||
            throw(ArgumentError("private rho request constructor"))
        new(fields...)
    end
end

_drp_request_values(x::DESCRhoPartitionRequestV4) =
    ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1)

semantic_view(x::DESCRhoPartitionRequestV4) =
    NamedTuple{fieldnames(DESCRhoPartitionRequestV4)[1:end-1]}(
        _drp_request_values(x))

function _drp_check_partition(request::DESCRhoPartitionRequestV4)
    length(request.regions) >= 2 &&
        length(request.interfaces) == length(request.regions) - 1 ||
        throw(ArgumentError("rho partition requires one interface per adjacency"))
    foreach(canonical_hash, request.regions)
    foreach(canonical_hash, request.interfaces)
    region_ids = Tuple(region.region_id for region in request.regions)
    interface_ids = Tuple(interface.interface_id for interface in request.interfaces)
    length(unique(region_ids)) == length(region_ids) &&
        length(unique(interface_ids)) == length(interface_ids) ||
        throw(ArgumentError("rho region and interface IDs must be unique"))
    request.rho_domain_lower == 0.0 && request.rho_domain_upper == 1.0 &&
        request.regions[1].rho_lower == request.rho_domain_lower &&
        request.regions[end].rho_upper == request.rho_domain_upper ||
        throw(ArgumentError("rho partition does not exactly cover its declared domain"))
    all(region -> region.parent_physical_support_hash ==
            request.physical_support_hash, request.regions) ||
        throw(ArgumentError("rho region is foreign to the physical support"))
    length(unique(region.region_support_hash for region in request.regions)) ==
        length(request.regions) ||
        throw(ArgumentError("rho region supports must be unique"))
    for i in 2:length(request.regions)
        request.regions[i - 1].rho_upper == request.regions[i].rho_lower ||
            throw(ArgumentError("rho intervals have a gap or overlap"))
    end
    used_samples = Digest256[]
    for i in eachindex(request.interfaces)
        interface = request.interfaces[i]
        minus = request.regions[i]
        plus = request.regions[i + 1]
        interface.minus_region_id == minus.region_id &&
            interface.plus_region_id == plus.region_id &&
            interface.rho_level == minus.rho_upper == plus.rho_lower ||
            throw(ArgumentError("rho interface does not encode ordered adjacency"))
        append!(used_samples,
            sample.source_basis_sample_hash for sample in interface.minus_trace)
    end
    all(sample_hash -> sample_hash in request.basis_sample_hashes,
        used_samples) ||
        throw(ArgumentError("rho trace references a foreign basis sample"))
    length(unique(request.point_hashes)) == length(request.point_hashes) &&
        length(unique(request.basis_sample_hashes)) ==
            length(request.basis_sample_hashes) &&
        length(request.point_hashes) == length(request.basis_sample_hashes) ||
        throw(ArgumentError("basis sample identity cover is incomplete"))
    true
end

function canonical_hash(x::DESCRhoPartitionRequestV4)
    x.revision == _DRP_REVISION && x.schema == _DRP_SCHEMA &&
        x.request_kind ===
            :candidate_bound_desc_rho_partition_trace_specification ||
        throw(ArgumentError("rho request schema mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.interface_trace_executed &&
        !x.emits_evidence && !x.p5_ready &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("rho request authority ceiling was exceeded"))
    _drp_check_partition(x)
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash ||
        throw(ArgumentError("rho request hash mismatch"))
    expected
end

function _drp_validate_basis_chain(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result)
    trusted_module = parentmodule(typeof(context))
    trusted_module === (@__MODULE__) ||
        throw(ArgumentError("rho contract context is outside its trust-root module"))
    expected = ((context, :ForwardChainContextV4),
        (geometry_bridge, :ThreeDNormalizedPhysicalRootBridgeResolutionV4),
        (geometry_evaluation, :DESCGeometryProgramEvaluationV4),
        (geometry_proof, :DESCGeometryCompatibilityResolutionV4),
        (execution_request, :DESCExecutionRequestV4),
        (execution_result, :DESCRequestProviderExecutionV4),
        (execution_receipt, :DESCProviderReceiptV4),
        (field_request, :DESCFieldProviderRequestV4),
        (field_result, :DESCFieldProviderResultV4),
        (basis_request, :DESCFieldBasisBridgeRequestV4),
        (basis_result, :DESCFieldBasisBridgeResultV4))
    all(isdefined(trusted_module, type_name) &&
        typeof(value) === getfield(trusted_module, type_name)
        for (value, type_name) in expected) ||
        throw(ArgumentError("rho contract upstream type or module is untrusted"))
    isdefined(trusted_module, :validate_desc_field_basis_bridge_result) ||
        throw(ArgumentError("basis result module has no external validator"))
    validator = getfield(trusted_module,
        :validate_desc_field_basis_bridge_result)
    validator(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result)
    basis_request.context_hash == context.context_hash &&
        basis_request.candidate_hash == context.candidate_hash &&
        basis_result.context_hash == context.context_hash &&
        basis_result.candidate_hash == context.candidate_hash &&
        basis_result.basis_request_hash == canonical_hash(basis_request) &&
        basis_result.field_request_hash == basis_request.field_request_hash &&
        basis_result.field_result_hash == basis_request.field_result_hash &&
        basis_result.field_receipt_hash == basis_request.field_receipt_hash ||
        throw(ArgumentError("rho contract received a foreign basis chain"))
    sample_hashes = Tuple(canonical_hash(sample) for sample in basis_result.samples)
    point_hashes = Tuple(sample.point_hash for sample in basis_result.samples)
    !isempty(sample_hashes) && length(unique(sample_hashes)) ==
        length(sample_hashes) && point_hashes == basis_request.point_hashes ||
        throw(ArgumentError("rho contract basis sample cover is invalid"))
    (sample_hashes=sample_hashes, point_hashes=point_hashes)
end

function _drp_request_body_from_upstream(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, regions, interfaces)
    cover = _drp_validate_basis_chain(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result)
    rho_lower = 0.0
    _drp_request_body(context.context_hash, context.candidate_hash,
        canonical_hash(basis_request), canonical_hash(basis_result),
        canonical_hash(basis_result.receipt),
        basis_request.compatibility_resolution_hash,
        basis_request.compatibility_certificate_hash,
        basis_request.compiled_prefix_hash, basis_request.physical_subject_hash,
        basis_request.physical_declaration_hash,
        basis_request.physical_support_hash, basis_request.coordinate_chart_hash,
        basis_request.geometry_graph_binding_hash,
        basis_request.coordinate_program_hash, basis_request.metric_program_hash,
        basis_request.geometry_payload_hash, basis_request.execution_request_hash,
        basis_request.execution_result_hash, basis_request.execution_receipt_hash,
        basis_request.field_request_hash, basis_request.field_result_hash,
        basis_request.field_receipt_hash, basis_request.equilibrium_output_sha256,
        cover.point_hashes, cover.sample_hashes, rho_lower, 1.0,
        Tuple(regions), Tuple(interfaces))
end

function make_desc_rho_partition_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, regions, interfaces)
    body = _drp_request_body_from_upstream(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, regions, interfaces)
    request = DESCRhoPartitionRequestV4(_DRP_TOKEN, values(body)...,
        canonical_hash(body))
    validate_desc_rho_partition_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request)
end

function _drp_validate_trace_sources(basis_result,
        request::DESCRhoPartitionRequestV4)
    source = Dict(canonical_hash(sample) => sample
        for sample in basis_result.samples)
    for interface in request.interfaces
        for trace in (interface.minus_trace..., interface.plus_trace...)
            haskey(source, trace.source_basis_sample_hash) ||
                throw(ArgumentError("rho trace sample is absent from basis result"))
            sample = source[trace.source_basis_sample_hash]
            trace.point_hash == sample.point_hash && trace.rho == sample.rho &&
                trace.theta_rad == sample.theta_rad &&
                trace.zeta_rad == sample.zeta_rad &&
                trace.cartesian_position_xyz_m ==
                    sample.cartesian_position_xyz_m &&
                trace.B_cartesian_xyz_T == sample.B_cartesian_xyz_T &&
                trace.F_cartesian_xyz_N_m3 == sample.F_cartesian_xyz_N_m3 &&
                trace.sqrt_g_m3 == sample.sqrt_g_m3 ||
                throw(ArgumentError("rho trace sample differs from basis result"))
        end
    end
    true
end

function validate_desc_rho_partition_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request::DESCRhoPartitionRequestV4)
    canonical_hash(request)
    expected = _drp_request_body_from_upstream(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request.regions, request.interfaces)
    semantic_view(request) == expected ||
        throw(ArgumentError("rho request contains a foreign upstream identity"))
    _drp_validate_trace_sources(basis_result, request)
    request
end


function _drp_receipt_body(request_hash, partition_hash, trace_map_hash,
        orientation_pairing_hash, replay_hash)
    (revision=_DRP_REVISION, schema=_DRP_SCHEMA, request_hash=request_hash,
     partition_hash=partition_hash, trace_sample_map_hash=trace_map_hash,
     orientation_pairing_hash=orientation_pairing_hash,
     replay_hash=replay_hash)
end

struct DESCRhoPartitionReceiptV4
    revision::String
    schema::String
    request_hash::Digest256
    partition_hash::Digest256
    trace_sample_map_hash::Digest256
    orientation_pairing_hash::Digest256
    replay_hash::Digest256
    receipt_hash::Digest256
    function DESCRhoPartitionReceiptV4(
            token::Val{:desc_rho_partition_trace_private}, fields...)
        token === _DRP_TOKEN ||
            throw(ArgumentError("private rho receipt constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCRhoPartitionReceiptV4) = _drp_receipt_body(x.request_hash,
    x.partition_hash, x.trace_sample_map_hash, x.orientation_pairing_hash,
    x.replay_hash)

function canonical_hash(x::DESCRhoPartitionReceiptV4)
    x.revision == _DRP_REVISION && x.schema == _DRP_SCHEMA ||
        throw(ArgumentError("rho receipt schema mismatch"))
    expected = canonical_hash(semantic_view(x))
    expected == x.receipt_hash ||
        throw(ArgumentError("rho receipt hash mismatch"))
    expected
end

function _drp_result_body(status, request_hash, partition_structure_validated,
        spatial_partition_geometry_validated,
        trace_sample_map_validated, declared_normal_pairing_validated,
        normal_geometry_validated, interface_trace_executed, provider_selected,
        provider_executed, solver_convergence_validated, multiregion_closure,
        physical_validation, engineering_validation, emits_evidence,
        grants_pass, promotion_authority, p5_ready, terminal_authority,
        credible_count, claim_ceiling, receipt_hash)
    (revision=_DRP_REVISION, schema=_DRP_SCHEMA, status=status,
     request_hash=request_hash,
     partition_structure_validated=partition_structure_validated,
     spatial_partition_geometry_validated=
        spatial_partition_geometry_validated,
     trace_sample_map_validated=trace_sample_map_validated,
     declared_normal_pairing_validated=declared_normal_pairing_validated,
     normal_geometry_validated=normal_geometry_validated,
     interface_trace_executed=interface_trace_executed,
     provider_selected=provider_selected, provider_executed=provider_executed,
     solver_convergence_validated=solver_convergence_validated,
     multiregion_closure=multiregion_closure,
     physical_validation=physical_validation,
     engineering_validation=engineering_validation,
     emits_evidence=emits_evidence, grants_pass=grants_pass,
     promotion_authority=promotion_authority, p5_ready=p5_ready,
     terminal_authority=terminal_authority,
     credible_physical_device_count=credible_count,
     claim_ceiling=claim_ceiling, receipt_hash=receipt_hash)
end

struct DESCRhoPartitionResultV4
    status::Symbol
    request_hash::Digest256
    partition_structure_validated::Bool
    spatial_partition_geometry_validated::Bool
    trace_sample_map_validated::Bool
    declared_normal_pairing_validated::Bool
    normal_geometry_validated::Bool
    interface_trace_executed::Bool
    provider_selected::Bool
    provider_executed::Bool
    solver_convergence_validated::Bool
    multiregion_closure::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    claim_ceiling::ClaimCeiling
    receipt::DESCRhoPartitionReceiptV4
    result_hash::Digest256
    function DESCRhoPartitionResultV4(
            token::Val{:desc_rho_partition_trace_private}, fields...)
        token === _DRP_TOKEN ||
            throw(ArgumentError("private rho result constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCRhoPartitionResultV4) = _drp_result_body(x.status,
    x.request_hash, x.partition_structure_validated,
    x.spatial_partition_geometry_validated,
    x.trace_sample_map_validated, x.declared_normal_pairing_validated,
    x.normal_geometry_validated, x.interface_trace_executed,
    x.provider_selected, x.provider_executed,
    x.solver_convergence_validated, x.multiregion_closure,
    x.physical_validation, x.engineering_validation, x.emits_evidence,
    x.grants_pass, x.promotion_authority, x.p5_ready, x.terminal_authority,
    x.credible_physical_device_count, x.claim_ceiling,
    canonical_hash(x.receipt))

function canonical_hash(x::DESCRhoPartitionResultV4)
    canonical_hash(x.receipt)
    x.status === :partition_trace_specification_screened &&
        x.partition_structure_validated &&
        !x.spatial_partition_geometry_validated &&
        x.trace_sample_map_validated &&
        x.declared_normal_pairing_validated &&
        !x.normal_geometry_validated && !x.interface_trace_executed &&
        !x.provider_selected && !x.provider_executed &&
        !x.solver_convergence_validated && !x.multiregion_closure &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 &&
        x.claim_ceiling == screen_only ||
        throw(ArgumentError("rho result authority ceiling was exceeded"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash ||
        throw(ArgumentError("rho result hash mismatch"))
    expected
end

function screen_desc_rho_partition(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request::DESCRhoPartitionRequestV4)
    validate_desc_rho_partition_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request)
    partition_hash = canonical_hash(request.regions)
    trace_map_hash = canonical_hash(Tuple((
        minus=Tuple(sample.source_basis_sample_hash
            for sample in interface.minus_trace),
        plus=Tuple(sample.source_basis_sample_hash
            for sample in interface.plus_trace))
        for interface in request.interfaces))
    orientation_hash = canonical_hash(Tuple((interface.interface_hash,
        Tuple(sample.declared_cartesian_normal_xyz
            for sample in interface.minus_trace),
        Tuple(sample.declared_cartesian_normal_xyz
            for sample in interface.plus_trace))
        for interface in request.interfaces))
    replay_hash = canonical_hash((request_hash=request.request_hash,
        partition_hash=partition_hash, trace_sample_map_hash=trace_map_hash,
        orientation_pairing_hash=orientation_hash))
    receipt_body = _drp_receipt_body(request.request_hash, partition_hash,
        trace_map_hash, orientation_hash, replay_hash)
    receipt = DESCRhoPartitionReceiptV4(_DRP_TOKEN, values(receipt_body)...,
        canonical_hash(receipt_body))
    body = (status=:partition_trace_specification_screened,
        request_hash=request.request_hash,
        partition_structure_validated=true,
        spatial_partition_geometry_validated=false,
        trace_sample_map_validated=true,
        declared_normal_pairing_validated=true,
        normal_geometry_validated=false, interface_trace_executed=false,
        provider_selected=false, provider_executed=false,
        solver_convergence_validated=false, multiregion_closure=false,
        physical_validation=false, engineering_validation=false,
        emits_evidence=false, grants_pass=false, promotion_authority=false,
        p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only,
        receipt=receipt)
    result_hash = canonical_hash(_drp_result_body(body.status,
        body.request_hash, body.partition_structure_validated,
        body.spatial_partition_geometry_validated,
        body.trace_sample_map_validated,
        body.declared_normal_pairing_validated,
        body.normal_geometry_validated, body.interface_trace_executed,
        body.provider_selected, body.provider_executed,
        body.solver_convergence_validated, body.multiregion_closure,
        body.physical_validation, body.engineering_validation,
        body.emits_evidence, body.grants_pass, body.promotion_authority,
        body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, body.claim_ceiling,
        canonical_hash(receipt)))
    result = DESCRhoPartitionResultV4(_DRP_TOKEN, values(body)..., result_hash)
    canonical_hash(result)
    result
end

function validate_desc_rho_partition_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request::DESCRhoPartitionRequestV4,
        result::DESCRhoPartitionResultV4)
    validate_desc_rho_partition_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request)
    canonical_hash(result)
    expected = screen_desc_rho_partition(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request)
    semantic_view(result) == semantic_view(expected) &&
        result.result_hash == expected.result_hash ||
        throw(ArgumentError("rho result is foreign to the request"))
    result.result_hash
end

function rerun_desc_rho_partition(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request::DESCRhoPartitionRequestV4,
        prior::DESCRhoPartitionResultV4)
    validate_desc_rho_partition_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request, prior)
    fresh = screen_desc_rho_partition(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, request)
    fresh.result_hash == prior.result_hash &&
        semantic_view(fresh) == semantic_view(prior) ||
        throw(ArgumentError("rho partition replay mismatch"))
    fresh
end

desc_rho_partition_trace_manifest() = (
    schema=_DRP_SCHEMA, revision=_DRP_REVISION,
    purpose=:candidate_bound_rho_partition_and_oriented_trace_specification,
    partition_structure_validated=true, trace_sample_map_validated=true,
    spatial_partition_geometry_validated=false,
    declared_normal_pairing_validated=true, normal_geometry_validated=false,
    interface_trace_executed=false, provider_selected=false,
    provider_executed=false, solver_convergence_validated=false,
    multiregion_closure=false, physical_validation=false,
    engineering_validation=false, emits_evidence=false, grants_pass=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
