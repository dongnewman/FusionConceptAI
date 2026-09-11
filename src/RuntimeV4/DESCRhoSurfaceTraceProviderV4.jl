# Candidate-bound fresh-process DESC rho-surface geometry and two-sided traces.
#
# This edge consumes the accepted structural rho partition, samples each
# interface at rho=c and rho=c±epsilon from the sealed DESC equilibrium, maps
# DESC's embedded orthonormal cylindrical vectors to laboratory Cartesian
# components, and validates sampled normals/tangents and strict region
# ownership. It does not prove global spatial coverage, solve interface fluxes,
# validate convergence, or emit promotion evidence.

using FusionConceptAI
using SHA
using LinearAlgebra
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _DRSTP_REVISION = "runtime-v4-desc-rho-surface-trace-provider-v1"
const _DRSTP_SCHEMA =
    "fusionconceptai:runtime-v4-desc-rho-surface-trace-provider"
const _DRSTP_REQUEST_SCHEMA =
    "fusionconceptai:runtime-v4-desc-rho-surface-trace-provider-request"
const _DRSTP_OUTPUT_SCHEMA =
    "fusionconceptai:runtime-v4-desc-rho-surface-trace-provider-output"
const _DRSTP_SOURCE_BASIS = :desc_embedded_orthonormal_cylindrical_R_phi_Z
const _DRSTP_TARGET_BASIS = :laboratory_cartesian_x_y_z
const _DRSTP_PHI_FRAME = :desc_laboratory_toroidal_angle
const _DRSTP_QUANTITIES = ("rho", "theta", "zeta", "R", "phi", "Z", "grad(rho)",
    "n_rho", "e_theta", "e_zeta", "B", "F", "sqrt(g)")
const _DRSTP_UNITS = ("~", "rad", "rad", "m", "rad", "m", "m^{-1}", "~", "m",
    "m", "T", raw"N \cdot m^{-3}", "m^{3}")
const _DRSTP_TOKEN = Val(:desc_rho_surface_trace_provider_private)
const _DRSTP_NORMAL_ATOL = 5.0e-10
const _DRSTP_COORD_ATOL = 5.0e-12

_drstp_sha256(path::AbstractString) =
    Digest256(bytes2hex(SHA.sha256(read(path))))

function _drstp_text(value, field::String)
    typeof(value) === String || throw(ArgumentError("$field must be a String"))
    result = strip(value)
    !isempty(result) && isvalid(result) &&
        !any(character -> character in ('\t', '\r', '\n'), result) ||
        throw(ArgumentError("$field is empty or unsafe for the sealed TSV schema"))
    lowercase(result) in ("*", "any", "all", "wildcard") &&
        throw(ArgumentError("$field cannot be a wildcard"))
    result
end

function _drstp_finite(value, field::String)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$field must be finite"))
    result
end

function _drstp_vec3(value, field::String)
    value isa Tuple && !(value isa NamedTuple) && length(value) == 3 ||
        throw(ArgumentError("$field must be an immutable 3-tuple"))
    ntuple(i -> _drstp_finite(value[i], field), 3)
end

struct DESCRhoSurfaceTraceSampleSpecV4
    interface_id::String
    interface_hash::Digest256
    minus_region_id::String
    plus_region_id::String
    minus_region_support_hash::Digest256
    plus_region_support_hash::Digest256
    rho_level::Float64
    theta_rad::Float64
    zeta_rad::Float64
    structural_minus_trace_hash::Digest256
    structural_plus_trace_hash::Digest256
    spec_hash::Digest256
    function DESCRhoSurfaceTraceSampleSpecV4(
            token::Val{:desc_rho_surface_trace_provider_private}, fields...)
        token === _DRSTP_TOKEN || throw(ArgumentError("private sample spec constructor"))
        new(fields...)
    end
end

function _drstp_spec_body(interface_id, interface_hash, minus_region_id,
        plus_region_id, minus_support_hash, plus_support_hash, rho_level,
        theta, zeta, minus_trace_hash, plus_trace_hash)
    (interface_id=interface_id, interface_hash=interface_hash,
     minus_region_id=minus_region_id, plus_region_id=plus_region_id,
     minus_region_support_hash=minus_support_hash,
     plus_region_support_hash=plus_support_hash, rho_level=rho_level,
     theta_rad=theta, zeta_rad=zeta,
     structural_minus_trace_hash=minus_trace_hash,
     structural_plus_trace_hash=plus_trace_hash)
end

semantic_view(x::DESCRhoSurfaceTraceSampleSpecV4) = _drstp_spec_body(
    x.interface_id, x.interface_hash, x.minus_region_id, x.plus_region_id,
    x.minus_region_support_hash, x.plus_region_support_hash, x.rho_level,
    x.theta_rad, x.zeta_rad, x.structural_minus_trace_hash,
    x.structural_plus_trace_hash)

function canonical_hash(x::DESCRhoSurfaceTraceSampleSpecV4)
    _drstp_text(x.interface_id, "interface_id") == x.interface_id &&
        _drstp_text(x.minus_region_id, "minus_region_id") == x.minus_region_id &&
        _drstp_text(x.plus_region_id, "plus_region_id") == x.plus_region_id &&
        x.minus_region_id != x.plus_region_id && 0.0 < x.rho_level < 1.0 &&
        0.0 <= x.theta_rad < 2pi && x.zeta_rad >= 0.0 ||
        throw(ArgumentError("invalid rho surface sample specification"))
    expected = canonical_hash(semantic_view(x))
    expected == x.spec_hash || throw(ArgumentError("rho surface sample spec hash mismatch"))
    expected
end

struct DESCRhoSurfaceTraceProviderRequestV4
    revision::String
    schema::String
    request_kind::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    partition_request_hash::Digest256
    partition_result_hash::Digest256
    partition_receipt_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    physical_support_hash::Digest256
    region_hashes::Tuple{Vararg{Digest256}}
    interface_hashes::Tuple{Vararg{Digest256}}
    samples::Tuple{Vararg{DESCRhoSurfaceTraceSampleSpecV4}}
    epsilon_rho::Float64
    nfp::Int
    provider_quantities::Tuple{Vararg{String}}
    units::Tuple{Vararg{String}}
    source_basis::Symbol
    target_basis::Symbol
    phi_frame::Symbol
    claim_ceiling::ClaimCeiling
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    request_hash::Digest256
    function DESCRhoSurfaceTraceProviderRequestV4(
            token::Val{:desc_rho_surface_trace_provider_private}, fields...)
        token === _DRSTP_TOKEN || throw(ArgumentError("private provider request constructor"))
        new(fields...)
    end
end

_drstp_values(x) = ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1)
semantic_view(x::DESCRhoSurfaceTraceProviderRequestV4) =
    NamedTuple{fieldnames(DESCRhoSurfaceTraceProviderRequestV4)[1:end-1]}(
        _drstp_values(x))

function canonical_hash(x::DESCRhoSurfaceTraceProviderRequestV4)
    x.revision == _DRSTP_REVISION && x.schema == _DRSTP_SCHEMA &&
        x.request_kind === :candidate_bound_desc_rho_surface_two_sided_trace &&
        !isempty(x.region_hashes) && !isempty(x.interface_hashes) &&
        !isempty(x.samples) && length(x.samples) <= 4096 ||
        throw(ArgumentError("rho surface provider request schema or cover mismatch"))
    foreach(canonical_hash, x.samples)
    length(unique(canonical_hash.(x.samples))) == length(x.samples) ||
        throw(ArgumentError("rho surface provider request repeats a sample"))
    0.0 < x.epsilon_rho < 0.5 ||
        throw(ArgumentError("rho trace epsilon must be inside (0,0.5)"))
    x.nfp > 0 && all(sample -> sample.zeta_rad < 2pi / x.nfp, x.samples) ||
        throw(ArgumentError("rho surface sample reaches the periodic seam"))
    all(sample -> sample.rho_level - x.epsilon_rho > 0.0 &&
        sample.rho_level + x.epsilon_rho < 1.0, x.samples) ||
        throw(ArgumentError("rho trace epsilon reaches the axis or boundary"))
    x.provider_quantities == _DRSTP_QUANTITIES && x.units == _DRSTP_UNITS &&
        x.source_basis === _DRSTP_SOURCE_BASIS &&
        x.target_basis === _DRSTP_TARGET_BASIS &&
        x.phi_frame === _DRSTP_PHI_FRAME ||
        throw(ArgumentError("rho surface provider convention mismatch"))
    x.claim_ceiling == screen_only && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("rho surface provider request exceeds screen-only authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash || throw(ArgumentError("rho surface provider request hash mismatch"))
    expected
end

function _drstp_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result)
    trusted = parentmodule(typeof(context))
    trusted === (@__MODULE__) ||
        throw(ArgumentError("rho surface provider context is outside its trust root"))
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
        (basis_result, :DESCFieldBasisBridgeResultV4),
        (partition_request, :DESCRhoPartitionRequestV4),
        (partition_result, :DESCRhoPartitionResultV4))
    all(isdefined(trusted, name) && typeof(value) === getfield(trusted, name)
        for (value, name) in expected) ||
        throw(ArgumentError("rho surface provider upstream type or module is untrusted"))
    isdefined(trusted, :validate_desc_rho_partition_result) ||
        throw(ArgumentError("trust root has no rho partition result validator"))
    getfield(trusted, :validate_desc_rho_partition_result)(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result)
    partition_result.partition_structure_validated &&
        partition_result.trace_sample_map_validated &&
        partition_result.declared_normal_pairing_validated &&
        !partition_result.provider_executed ||
        throw(ArgumentError("rho partition is not an accepted structural-only result"))
    partition_request.context_hash == context.context_hash &&
        partition_request.candidate_hash == context.candidate_hash &&
        partition_request.execution_receipt_hash == canonical_hash(execution_receipt) &&
        partition_request.equilibrium_output_sha256 == execution_receipt.output_sha256 ||
        throw(ArgumentError("rho partition is foreign to the executed equilibrium"))
    true
end

function _drstp_specs(partition_request)
    regions = Dict(region.region_id => region for region in partition_request.regions)
    specs = DESCRhoSurfaceTraceSampleSpecV4[]
    for interface in partition_request.interfaces
        minus_region = regions[interface.minus_region_id]
        plus_region = regions[interface.plus_region_id]
        for (minus_trace, plus_trace) in zip(interface.minus_trace,
                interface.plus_trace)
            body = _drstp_spec_body(interface.interface_id,
                canonical_hash(interface), interface.minus_region_id,
                interface.plus_region_id, minus_region.region_support_hash,
                plus_region.region_support_hash, interface.rho_level,
                minus_trace.theta_rad, minus_trace.zeta_rad,
                canonical_hash(minus_trace), canonical_hash(plus_trace))
            push!(specs, DESCRhoSurfaceTraceSampleSpecV4(_DRSTP_TOKEN,
                values(body)..., canonical_hash(body)))
        end
    end
    Tuple(specs)
end

function make_desc_rho_surface_trace_provider_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result; epsilon_rho=1.0e-3)
    _drstp_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result)
    epsilon = _drstp_finite(epsilon_rho, "epsilon_rho")
    specs = _drstp_specs(partition_request)
    regions = Dict(region.region_id => region for region in partition_request.regions)
    all(spec -> spec.rho_level - epsilon > regions[spec.minus_region_id].rho_lower &&
        spec.rho_level - epsilon < regions[spec.minus_region_id].rho_upper &&
        spec.rho_level + epsilon > regions[spec.plus_region_id].rho_lower &&
        spec.rho_level + epsilon < regions[spec.plus_region_id].rho_upper,
        specs) || throw(ArgumentError("epsilon samples do not lie strictly inside adjacent regions"))
    body = (revision=_DRSTP_REVISION, schema=_DRSTP_SCHEMA,
        request_kind=:candidate_bound_desc_rho_surface_two_sided_trace,
        context_hash=context.context_hash, candidate_hash=context.candidate_hash,
        partition_request_hash=canonical_hash(partition_request),
        partition_result_hash=canonical_hash(partition_result),
        partition_receipt_hash=canonical_hash(partition_result.receipt),
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        equilibrium_output_sha256=execution_receipt.output_sha256,
        physical_support_hash=partition_request.physical_support_hash,
        region_hashes=Tuple(canonical_hash.(partition_request.regions)),
        interface_hashes=Tuple(canonical_hash.(partition_request.interfaces)),
        samples=specs, epsilon_rho=epsilon,
        nfp=Int(execution_request.runner_payload.nfp),
        provider_quantities=_DRSTP_QUANTITIES, units=_DRSTP_UNITS,
        source_basis=_DRSTP_SOURCE_BASIS, target_basis=_DRSTP_TARGET_BASIS,
        phi_frame=_DRSTP_PHI_FRAME, claim_ceiling=screen_only,
        emits_evidence=false, grants_pass=false, promotion_authority=false,
        p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0)
    request = DESCRhoSurfaceTraceProviderRequestV4(_DRSTP_TOKEN,
        values(body)..., canonical_hash(body))
    canonical_hash(request)
    request
end

function validate_desc_rho_surface_trace_provider_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, request::DESCRhoSurfaceTraceProviderRequestV4)
    _drstp_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result)
    expected = make_desc_rho_surface_trace_provider_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result; epsilon_rho=request.epsilon_rho)
    semantic_view(request) == semantic_view(expected) ||
        throw(ArgumentError("rho surface provider request contains foreign identity or samples"))
    request
end

function _drstp_cyl_to_cart(vector, phi)
    radial, toroidal, vertical = vector
    cosine, sine = cos(phi), sin(phi)
    (radial * cosine - toroidal * sine,
     radial * sine + toroidal * cosine, vertical)
end

_drstp_position(R, phi, Z) = (R * cos(phi), R * sin(phi), Z)

struct DESCRhoSurfaceTraceProviderSampleV4
    spec_hash::Digest256
    interface_id::String
    minus_region_id::String
    plus_region_id::String
    rho_level::Float64
    theta_rad::Float64
    zeta_rad::Float64
    epsilon_rho::Float64
    surface_position_xyz_m::NTuple{3,Float64}
    minus_outward_normal_xyz::NTuple{3,Float64}
    plus_outward_normal_xyz::NTuple{3,Float64}
    surface_e_theta_xyz_m::NTuple{3,Float64}
    surface_e_zeta_xyz_m::NTuple{3,Float64}
    minus_rho::Float64
    minus_position_xyz_m::NTuple{3,Float64}
    minus_B_xyz_T::NTuple{3,Float64}
    minus_F_xyz_N_m3::NTuple{3,Float64}
    minus_sqrt_g_m3::Float64
    plus_rho::Float64
    plus_position_xyz_m::NTuple{3,Float64}
    plus_B_xyz_T::NTuple{3,Float64}
    plus_F_xyz_N_m3::NTuple{3,Float64}
    plus_sqrt_g_m3::Float64
    normal_grad_alignment::Float64
    tangent_normal_max_abs_dot::Float64
    sample_hash::Digest256
end

function _drstp_sample_body(x::DESCRhoSurfaceTraceProviderSampleV4)
    names = fieldnames(typeof(x))[1:end-1]
    NamedTuple{names}(ntuple(i -> getfield(x, i), length(names)))
end
semantic_view(x::DESCRhoSurfaceTraceProviderSampleV4) = _drstp_sample_body(x)

function canonical_hash(x::DESCRhoSurfaceTraceProviderSampleV4)
    _drstp_text(x.interface_id, "interface_id") == x.interface_id &&
        _drstp_text(x.minus_region_id, "minus_region_id") == x.minus_region_id &&
        _drstp_text(x.plus_region_id, "plus_region_id") == x.plus_region_id ||
        throw(ArgumentError("rho surface provider sample identity mismatch"))
    all(isfinite, (x.rho_level, x.theta_rad, x.zeta_rad, x.epsilon_rho,
        x.minus_rho, x.minus_sqrt_g_m3, x.plus_rho, x.plus_sqrt_g_m3,
        x.normal_grad_alignment, x.tangent_normal_max_abs_dot)) ||
        throw(ArgumentError("rho surface provider sample contains nonfinite scalars"))
    vectors = (x.surface_position_xyz_m, x.minus_outward_normal_xyz,
        x.plus_outward_normal_xyz, x.surface_e_theta_xyz_m,
        x.surface_e_zeta_xyz_m, x.minus_position_xyz_m, x.minus_B_xyz_T,
        x.minus_F_xyz_N_m3, x.plus_position_xyz_m, x.plus_B_xyz_T,
        x.plus_F_xyz_N_m3)
    all(v -> all(isfinite, v), vectors) ||
        throw(ArgumentError("rho surface provider sample contains nonfinite vectors"))
    x.minus_rho == x.rho_level - x.epsilon_rho &&
        x.plus_rho == x.rho_level + x.epsilon_rho &&
        x.minus_sqrt_g_m3 > 0.0 && x.plus_sqrt_g_m3 > 0.0 ||
        throw(ArgumentError("rho surface provider sample has invalid two-sided trace"))
    isapprox(norm(collect(x.minus_outward_normal_xyz)), 1.0;
        atol=_DRSTP_NORMAL_ATOL, rtol=_DRSTP_NORMAL_ATOL) &&
        all(isapprox(x.minus_outward_normal_xyz[i],
            -x.plus_outward_normal_xyz[i]; atol=_DRSTP_NORMAL_ATOL,
            rtol=_DRSTP_NORMAL_ATOL) for i in 1:3) ||
        throw(ArgumentError("rho surface provider normals are not opposite unit vectors"))
    x.normal_grad_alignment >= 1.0 - _DRSTP_NORMAL_ATOL &&
        x.normal_grad_alignment <= 1.0 + _DRSTP_NORMAL_ATOL &&
        x.tangent_normal_max_abs_dot <= 5.0e-8 ||
        throw(ArgumentError("rho surface provider normal/tangent geometry is inconsistent"))
    expected = canonical_hash(semantic_view(x))
    expected == x.sample_hash || throw(ArgumentError("rho surface provider sample hash mismatch"))
    expected
end

struct DESCRhoSurfaceTraceProviderReceiptV4
    command::String
    input_path::String
    output_path::String
    adapter_path::String
    upstream_hdf5_path::String
    python_executable::String
    desc_module_path::String
    input_sha256::Digest256
    output_sha256::Union{Nothing,Digest256}
    adapter_source_sha256::Digest256
    upstream_hdf5_sha256::Digest256
    python_executable_sha256::Digest256
    desc_module_sha256::Digest256
    exit_code::Int
    stdout::String
    stderr::String
    output_schema_validated::Bool
    process_hash::Digest256
    receipt_hash::Digest256
end

function _drstp_receipt_body(x::DESCRhoSurfaceTraceProviderReceiptV4)
    names = fieldnames(typeof(x))[1:end-1]
    NamedTuple{names}(ntuple(i -> getfield(x, i), length(names)))
end
semantic_view(x::DESCRhoSurfaceTraceProviderReceiptV4) = _drstp_receipt_body(x)

function canonical_hash(x::DESCRhoSurfaceTraceProviderReceiptV4)
    expected = canonical_hash(semantic_view(x))
    expected == x.receipt_hash || throw(ArgumentError("rho surface provider receipt hash mismatch"))
    expected
end

function validate_desc_rho_surface_trace_provider_receipt(
        receipt::DESCRhoSurfaceTraceProviderReceiptV4)
    canonical_hash(receipt)
    process_names = fieldnames(typeof(receipt))[1:end-2]
    process_body = NamedTuple{process_names}(ntuple(i -> getfield(receipt, i),
        length(process_names)))
    canonical_hash(process_body) == receipt.process_hash ||
        throw(ArgumentError("rho surface provider process hash mismatch"))
    receipt.adapter_source_sha256 == _DRSTP_ADAPTER_SHA256 ||
        throw(ArgumentError("rho surface provider adapter is not the trusted source"))
    checks = ((receipt.input_path, receipt.input_sha256, "input"),
        (receipt.adapter_path, receipt.adapter_source_sha256, "adapter"),
        (receipt.upstream_hdf5_path, receipt.upstream_hdf5_sha256, "HDF5"),
        (receipt.python_executable, receipt.python_executable_sha256, "Python"),
        (receipt.desc_module_path, receipt.desc_module_sha256, "DESC module"))
    for (path, expected, label) in checks
        isfile(path) && _drstp_sha256(path) == expected ||
            throw(ArgumentError("rho surface provider $label receipt was tampered"))
    end
    receipt.output_sha256 !== nothing && isfile(receipt.output_path) &&
        _drstp_sha256(receipt.output_path) == receipt.output_sha256 ||
        throw(ArgumentError("rho surface provider output is missing or tampered"))
    receipt.exit_code == 0 && receipt.output_schema_validated ||
        throw(ArgumentError("rho surface provider receipt is unsuccessful"))
    true
end

struct DESCRhoSurfaceTraceProviderResultV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    provider_request_hash::Digest256
    partition_request_hash::Digest256
    partition_result_hash::Digest256
    equilibrium_output_sha256::Digest256
    desc_version::String
    nfp::Int
    samples::Tuple{Vararg{DESCRhoSurfaceTraceProviderSampleV4}}
    provider_selected::Bool
    provider_executed::Bool
    output_schema_validated::Bool
    surface_geometry_sampled::Bool
    normal_geometry_validated::Bool
    tangent_geometry_validated::Bool
    two_sided_trace_executed::Bool
    region_ownership_validated::Bool
    declared_normals_cross_checked::Bool
    spatial_partition_geometry_validated::Bool
    interface_flux_executed::Bool
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
    receipt::DESCRhoSurfaceTraceProviderReceiptV4
    result_hash::Digest256
end

function _drstp_result_body(x::DESCRhoSurfaceTraceProviderResultV4)
    names = fieldnames(typeof(x))[1:end-2]
    values = ntuple(i -> getfield(x, i), length(names))
    merge(NamedTuple{names}(values), (receipt_hash=canonical_hash(x.receipt),))
end
semantic_view(x::DESCRhoSurfaceTraceProviderResultV4) = _drstp_result_body(x)

function canonical_hash(x::DESCRhoSurfaceTraceProviderResultV4)
    canonical_hash(x.receipt)
    foreach(canonical_hash, x.samples)
    x.status === :desc_rho_surface_traces_sampled && x.nfp > 0 &&
        !isempty(x.samples) && x.provider_selected && x.provider_executed &&
        x.output_schema_validated && x.surface_geometry_sampled &&
        x.normal_geometry_validated && x.tangent_geometry_validated &&
        x.two_sided_trace_executed && x.region_ownership_validated &&
        !x.declared_normals_cross_checked &&
        !x.spatial_partition_geometry_validated && !x.interface_flux_executed &&
        !x.solver_convergence_validated && !x.multiregion_closure &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only ||
        throw(ArgumentError("rho surface provider result exceeds sampled screen authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash || throw(ArgumentError("rho surface provider result hash mismatch"))
    expected
end

function _drstp_request_text(request::DESCRhoSurfaceTraceProviderRequestV4)
    rows = ["SCHEMA\t$_DRSTP_REQUEST_SCHEMA",
        "REQUEST_HASH\t$(request.request_hash)",
        "CONTEXT_HASH\t$(request.context_hash)",
        "CANDIDATE_HASH\t$(request.candidate_hash)",
        "EQUILIBRIUM_SHA256\t$(request.equilibrium_output_sha256)",
        "EPSILON_RHO\t$(repr(request.epsilon_rho))",
        "NFP\t$(request.nfp)",
        "COUNT\t$(length(request.samples))"]
    for (index, sample) in enumerate(request.samples)
        push!(rows, join(("SAMPLE", index, sample.spec_hash,
            sample.interface_id, sample.minus_region_id, sample.plus_region_id,
            repr(sample.rho_level), repr(sample.theta_rad), repr(sample.zeta_rad)), '\t'))
    end
    push!(rows, "END\t1")
    join(rows, '\n') * "\n"
end

const _DRSTP_ADAPTER_SOURCE = raw"""
import math
import sys
from pathlib import Path
import numpy as np
import desc
from desc.compute import data_index
from desc.grid import Grid
from desc.io import load

REQUEST_SCHEMA = "fusionconceptai:runtime-v4-desc-rho-surface-trace-provider-request"
OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-desc-rho-surface-trace-provider-output"
KEY = "desc.equilibrium.equilibrium.Equilibrium"
QUANTITIES = ["rho", "theta", "zeta", "R", "phi", "Z", "grad(rho)", "n_rho",
              "e_theta", "e_zeta", "B", "F", "sqrt(g)"]
EXPECTED = {
    "rho": ("~", 1, "r"), "theta": ("rad", 1, "t"),
    "zeta": ("rad", 1, "z"), "R": ("m", 1, "rtz"),
    "phi": ("rad", 1, "rtz"), "Z": ("m", 1, "rtz"),
    "grad(rho)": ("m^{-1}", 3, "rtz"), "n_rho": ("~", 3, "rtz"),
    "e_theta": ("m", 3, "rtz"), "e_zeta": ("m", 3, "rtz"),
    "B": ("T", 3, "rtz"), "F": ("N \\cdot m^{-3}", 3, "rtz"),
    "sqrt(g)": ("m^{3}", 1, "rtz"),
}

def read_request(path):
    with open(path, encoding="utf-8") as stream:
        rows = [line.rstrip("\n").split("\t") for line in stream]
    if rows[0] != ["SCHEMA", REQUEST_SCHEMA] or rows[-1] != ["END", "1"]:
        raise ValueError("request framing mismatch")
    labels = ["REQUEST_HASH", "CONTEXT_HASH", "CANDIDATE_HASH",
              "EQUILIBRIUM_SHA256", "EPSILON_RHO", "NFP", "COUNT"]
    if [row[0] for row in rows[1:8]] != labels or any(len(row) != 2 for row in rows[1:8]):
        raise ValueError("request header order/width mismatch")
    headers = {row[0]: row[1] for row in rows[1:8]}
    samples = rows[8:-1]
    if len(samples) != int(headers["COUNT"]):
        raise ValueError("request sample count mismatch")
    parsed = []
    for expected_index, row in enumerate(samples, 1):
        if len(row) != 9 or row[0] != "SAMPLE" or int(row[1]) != expected_index:
            raise ValueError("request sample row mismatch")
        parsed.append((row[2], row[3], row[4], row[5],
                       float(row[6]), float(row[7]), float(row[8])))
    return headers, parsed

def verify_metadata():
    metadata = data_index[KEY]
    for name, expected in EXPECTED.items():
        actual = metadata[name]
        got = (actual["units"], int(actual["dim"]), actual["coordinates"])
        if got != expected:
            raise ValueError("DESC quantity metadata mismatch for " + name + ": " + repr(got))

def finite_array(data, name, count, dim):
    value = np.asarray(data[name], dtype=float)
    expected_shape = (count,) if dim == 1 else (count, dim)
    if value.shape != expected_shape or not np.all(np.isfinite(value)):
        raise ValueError("DESC output shape/nonfinite mismatch for " + name)
    return value

headers, specs = read_request(sys.argv[2])
verify_metadata()
if Path(desc.__file__).resolve() != Path(sys.argv[4]).resolve():
    raise ValueError("imported DESC module differs from sealed module path")
eq = load(sys.argv[1])
if int(eq.NFP) != int(headers["NFP"]):
    raise ValueError("request NFP differs from sealed equilibrium")
epsilon = float(headers["EPSILON_RHO"])
points = []
for spec in specs:
    _, _, _, _, rho, theta, zeta = spec
    points.extend(((rho, theta, zeta), (rho-epsilon, theta, zeta),
                   (rho+epsilon, theta, zeta)))
grid = Grid(np.asarray(points, dtype=float), coordinates="rtz",
            NFP=int(eq.NFP), sort=False)
data = eq.compute(QUANTITIES, grid=grid)
count = len(points)
arrays = {name: finite_array(data, name, count, EXPECTED[name][1])
          for name in QUANTITIES}
if not np.all(arrays["sqrt(g)"] > 0):
    raise ValueError("DESC returned nonpositive sqrt(g)")
rows = ["SCHEMA\t" + OUTPUT_SCHEMA,
        "REQUEST_HASH\t" + headers["REQUEST_HASH"],
        "CONTEXT_HASH\t" + headers["CONTEXT_HASH"],
        "CANDIDATE_HASH\t" + headers["CANDIDATE_HASH"],
        "EQUILIBRIUM_SHA256\t" + headers["EQUILIBRIUM_SHA256"],
        "DESC_VERSION\t" + desc.__version__, "NFP\t" + str(int(eq.NFP)),
        "COUNT\t" + str(len(specs)),
        "QUANTITIES\t" + "\t".join(QUANTITIES),
        "UNITS\t" + "\t".join(EXPECTED[name][0] for name in QUANTITIES)]
for index, spec in enumerate(specs, 1):
    spec_hash, interface_id, minus_id, plus_id, rho, theta, zeta = spec
    values = []
    for offset in range(3):
        point_index = 3 * (index - 1) + offset
        values.extend((arrays["rho"][point_index], arrays["theta"][point_index],
                       arrays["zeta"][point_index], arrays["R"][point_index],
                       arrays["phi"][point_index], arrays["Z"][point_index]))
        for name in ("grad(rho)", "n_rho", "e_theta", "e_zeta", "B", "F"):
            values.extend(arrays[name][point_index])
        values.append(arrays["sqrt(g)"][point_index])
    rows.append("\t".join(("SAMPLE", str(index), spec_hash, interface_id,
        minus_id, plus_id, repr(rho), repr(theta), repr(zeta),
        *(repr(float(value)) for value in values))))
rows.append("END\t1")
with open(sys.argv[3], "w", encoding="utf-8", newline="\n") as stream:
    stream.write("\n".join(rows) + "\n")
"""

const _DRSTP_ADAPTER_SHA256 =
    Digest256(bytes2hex(SHA.sha256(codeunits(_DRSTP_ADAPTER_SOURCE))))

function _drstp_parse_float(value, label)
    parsed = tryparse(Float64, value)
    parsed !== nothing && isfinite(parsed) ||
        throw(ArgumentError("invalid $label in rho surface provider output"))
    parsed
end

function _drstp_output_sample(row, spec, epsilon)
    length(row) == 84 || throw(ArgumentError("rho surface provider sample column mismatch"))
    row[1] == "SAMPLE" || throw(ArgumentError("rho surface provider sample tag mismatch"))
    row[3] == string(spec.spec_hash) && row[4] == spec.interface_id &&
        row[5] == spec.minus_region_id && row[6] == spec.plus_region_id ||
        throw(ArgumentError("rho surface provider output sample identity mismatch"))
    declared = _drstp_parse_float.(row[7:9], ("rho", "theta", "zeta"))
    declared == [spec.rho_level, spec.theta_rad, spec.zeta_rad] ||
        throw(ArgumentError("rho surface provider output coordinates differ from request"))
    numeric = _drstp_parse_float.(row[10:end], Ref("sample value"))
    function point(offset)
        start = 1 + offset * 25
        rho, theta, zeta, R, phi, Z = numeric[start:start+5]
        grad = Tuple(numeric[start+6:start+8])
        normal = Tuple(numeric[start+9:start+11])
        etheta = Tuple(numeric[start+12:start+14])
        ezeta = Tuple(numeric[start+15:start+17])
        B = Tuple(numeric[start+18:start+20])
        F = Tuple(numeric[start+21:start+23])
        sqrt_g = numeric[start+24]
        (rho=rho, theta=theta, zeta=zeta, R=R, phi=phi, Z=Z,
         grad=grad, normal=normal,
         etheta=etheta, ezeta=ezeta, B=B, F=F, sqrt_g=sqrt_g)
    end
    surface, minus, plus = point(0), point(1), point(2)
    isapprox(surface.rho, spec.rho_level; atol=_DRSTP_COORD_ATOL, rtol=0.0) &&
        isapprox(minus.rho, spec.rho_level-epsilon; atol=_DRSTP_COORD_ATOL, rtol=0.0) &&
        isapprox(plus.rho, spec.rho_level+epsilon; atol=_DRSTP_COORD_ATOL, rtol=0.0) ||
        throw(ArgumentError("DESC returned a different rho coordinate"))
    all(point -> isapprox(point.theta, spec.theta_rad;
            atol=_DRSTP_COORD_ATOL, rtol=0.0) &&
        isapprox(point.zeta, spec.zeta_rad;
            atol=_DRSTP_COORD_ATOL, rtol=0.0), (surface, minus, plus)) ||
        throw(ArgumentError("DESC returned different theta/zeta coordinates"))
    alignments = Float64[]
    tangent_errors = Float64[]
    for geometry_point in (surface, minus, plus)
        grad_norm = norm(collect(geometry_point.grad))
        grad_norm > 0.0 || throw(ArgumentError("DESC returned zero grad(rho)"))
        computed_normal = Tuple(component / grad_norm
            for component in geometry_point.grad)
        alignment = dot(collect(computed_normal),
            collect(geometry_point.normal))
        alignment >= 1.0 - _DRSTP_NORMAL_ATOL ||
            throw(ArgumentError("DESC n_rho is not aligned with grad(rho)"))
        push!(alignments, alignment)
        push!(tangent_errors, max(
            abs(dot(collect(geometry_point.normal),
                collect(geometry_point.etheta))),
            abs(dot(collect(geometry_point.normal),
                collect(geometry_point.ezeta)))))
    end
    alignment = minimum(alignments)
    tangent_error = maximum(tangent_errors)
    normal_xyz = _drstp_cyl_to_cart(surface.normal, surface.phi)
    etheta_xyz = _drstp_cyl_to_cart(surface.etheta, surface.phi)
    ezeta_xyz = _drstp_cyl_to_cart(surface.ezeta, surface.phi)
    body = (spec_hash=spec.spec_hash, interface_id=spec.interface_id,
        minus_region_id=spec.minus_region_id, plus_region_id=spec.plus_region_id,
        rho_level=spec.rho_level, theta_rad=spec.theta_rad,
        zeta_rad=spec.zeta_rad, epsilon_rho=epsilon,
        surface_position_xyz_m=_drstp_position(surface.R, surface.phi, surface.Z),
        minus_outward_normal_xyz=normal_xyz,
        plus_outward_normal_xyz=Tuple(-component for component in normal_xyz),
        surface_e_theta_xyz_m=etheta_xyz, surface_e_zeta_xyz_m=ezeta_xyz,
        minus_rho=spec.rho_level-epsilon,
        minus_position_xyz_m=_drstp_position(minus.R, minus.phi, minus.Z),
        minus_B_xyz_T=_drstp_cyl_to_cart(minus.B, minus.phi),
        minus_F_xyz_N_m3=_drstp_cyl_to_cart(minus.F, minus.phi),
        minus_sqrt_g_m3=minus.sqrt_g, plus_rho=spec.rho_level+epsilon,
        plus_position_xyz_m=_drstp_position(plus.R, plus.phi, plus.Z),
        plus_B_xyz_T=_drstp_cyl_to_cart(plus.B, plus.phi),
        plus_F_xyz_N_m3=_drstp_cyl_to_cart(plus.F, plus.phi),
        plus_sqrt_g_m3=plus.sqrt_g, normal_grad_alignment=alignment,
        tangent_normal_max_abs_dot=tangent_error)
    provisional = DESCRhoSurfaceTraceProviderSampleV4(values(body)...,
        canonical_hash(body))
    canonical_hash(provisional)
    provisional
end

function _drstp_parse_output(path, request)
    rows = [split(chomp(line), '\t'; keepempty=true) for line in readlines(path)]
    length(rows) >= 11 && rows[1] == ["SCHEMA", _DRSTP_OUTPUT_SCHEMA] &&
        rows[end] == ["END", "1"] ||
        throw(ArgumentError("rho surface provider output framing mismatch"))
    expected_labels = ["REQUEST_HASH", "CONTEXT_HASH", "CANDIDATE_HASH",
        "EQUILIBRIUM_SHA256", "DESC_VERSION", "NFP", "COUNT",
        "QUANTITIES", "UNITS"]
    [row[1] for row in rows[2:10]] == expected_labels &&
        length(unique(expected_labels)) == length(expected_labels) &&
        all(length(rows[index]) == 2 for index in 2:8) ||
        throw(ArgumentError("rho surface provider output header order/width mismatch"))
    headers = Dict(row[1] => row[2:end] for row in rows[2:10])
    headers["REQUEST_HASH"] == [string(request.request_hash)] &&
        headers["CONTEXT_HASH"] == [string(request.context_hash)] &&
        headers["CANDIDATE_HASH"] == [string(request.candidate_hash)] &&
        headers["EQUILIBRIUM_SHA256"] == [string(request.equilibrium_output_sha256)] ||
        throw(ArgumentError("rho surface provider output identity mismatch"))
    headers["QUANTITIES"] == collect(_DRSTP_QUANTITIES) &&
        headers["UNITS"] == collect(_DRSTP_UNITS) ||
        throw(ArgumentError("rho surface provider output metadata mismatch"))
    count = tryparse(Int, only(headers["COUNT"]))
    nfp = tryparse(Int, only(headers["NFP"]))
    count == length(request.samples) && nfp == request.nfp && nfp > 0 ||
        throw(ArgumentError("rho surface provider output count/NFP mismatch"))
    sample_rows = rows[11:end-1]
    length(sample_rows) == count || throw(ArgumentError("rho surface provider output sample count mismatch"))
    samples = Tuple(_drstp_output_sample(row, request.samples[index],
        request.epsilon_rho) for (index, row) in enumerate(sample_rows))
    (desc_version=_drstp_text(String(only(headers["DESC_VERSION"])), "DESC version"),
     nfp=nfp, samples=samples)
end

function _drstp_process(execution_receipt, request, run_dir;
        adapter_source=_DRSTP_ADAPTER_SOURCE)
    directory = String(run_dir)
    mkpath(directory)
    input_path = joinpath(directory, "rho_surface_trace_request.tsv")
    output_path = joinpath(directory, "rho_surface_trace_result.tsv")
    adapter_path = joinpath(directory, "desc_rho_surface_trace_adapter.py")
    isfile(output_path) && rm(output_path; force=true)
    open(input_path, "w") do io
        write(io, _drstp_request_text(request))
    end
    open(adapter_path, "w") do io
        write(io, adapter_source)
    end
    executable = String(execution_receipt.python_executable)
    hdf5_path = String(execution_receipt.output_path)
    module_path = String(execution_receipt.desc_module_path)
    command = `$executable $adapter_path $hdf5_path $input_path $output_path $module_path`
    stdout_buffer, stderr_buffer = IOBuffer(), IOBuffer()
    process = run(pipeline(ignorestatus(command), stdout=stdout_buffer,
        stderr=stderr_buffer))
    (command=string(command), input_path=input_path, output_path=output_path,
     adapter_path=adapter_path, upstream_hdf5_path=hdf5_path,
     python_executable=executable, desc_module_path=module_path,
     input_sha256=_drstp_sha256(input_path),
     output_sha256=isfile(output_path) ? _drstp_sha256(output_path) : nothing,
     adapter_source_sha256=_drstp_sha256(adapter_path),
     upstream_hdf5_sha256=_drstp_sha256(hdf5_path),
     python_executable_sha256=_drstp_sha256(executable),
     desc_module_sha256=_drstp_sha256(module_path), exit_code=process.exitcode,
     stdout=String(take!(stdout_buffer)), stderr=String(take!(stderr_buffer)))
end

function _drstp_receipt(process, validated)
    process_body = merge(process, (output_schema_validated=validated,))
    process_hash = canonical_hash(process_body)
    body = merge(process_body, (process_hash=process_hash,))
    DESCRhoSurfaceTraceProviderReceiptV4(values(body)..., canonical_hash(body))
end

function execute_desc_rho_surface_trace_provider(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request::DESCRhoSurfaceTraceProviderRequestV4; run_dir,
        adapter_source=_DRSTP_ADAPTER_SOURCE)
    validate_desc_rho_surface_trace_provider_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request)
    process = _drstp_process(execution_receipt, request, run_dir;
        adapter_source=adapter_source)
    parsed, parse_error = nothing, nothing
    if process.exit_code == 0 && process.output_sha256 !== nothing
        try
            parsed = _drstp_parse_output(process.output_path, request)
        catch error
            parse_error = error
        end
    end
    receipt = _drstp_receipt(process, parsed !== nothing)
    process.exit_code == 0 ||
        throw(ArgumentError("DESC rho surface provider exited $(process.exit_code): $(process.stderr)"))
    parse_error === nothing || throw(parse_error)
    validate_desc_rho_surface_trace_provider_receipt(receipt)
    body = (status=:desc_rho_surface_traces_sampled,
        context_hash=context.context_hash, candidate_hash=context.candidate_hash,
        provider_request_hash=request.request_hash,
        partition_request_hash=canonical_hash(partition_request),
        partition_result_hash=canonical_hash(partition_result),
        equilibrium_output_sha256=request.equilibrium_output_sha256,
        desc_version=parsed.desc_version, nfp=parsed.nfp, samples=parsed.samples,
        provider_selected=true, provider_executed=true,
        output_schema_validated=true, surface_geometry_sampled=true,
        normal_geometry_validated=true, tangent_geometry_validated=true,
        two_sided_trace_executed=true, region_ownership_validated=true,
        declared_normals_cross_checked=false,
        spatial_partition_geometry_validated=false,
        interface_flux_executed=false, solver_convergence_validated=false,
        multiregion_closure=false, physical_validation=false,
        engineering_validation=false, emits_evidence=false, grants_pass=false,
        promotion_authority=false, p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only,
        receipt=receipt)
    provisional = DESCRhoSurfaceTraceProviderResultV4(values(body)...,
        canonical_hash(merge(Base.structdiff(body, NamedTuple{(:receipt,)}),
            (receipt_hash=canonical_hash(receipt),))))
    validate_desc_rho_surface_trace_provider_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request, provisional)
    provisional
end

function validate_desc_rho_surface_trace_provider_result(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, request::DESCRhoSurfaceTraceProviderRequestV4,
        result::DESCRhoSurfaceTraceProviderResultV4)
    validate_desc_rho_surface_trace_provider_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request)
    canonical_hash(result)
    validate_desc_rho_surface_trace_provider_receipt(result.receipt)
    result.receipt.upstream_hdf5_path == String(execution_receipt.output_path) &&
        result.receipt.python_executable == String(execution_receipt.python_executable) &&
        result.receipt.desc_module_path == String(execution_receipt.desc_module_path) &&
        result.receipt.upstream_hdf5_sha256 == execution_receipt.output_sha256 &&
        result.receipt.python_executable_sha256 ==
            _drstp_sha256(execution_receipt.python_executable) &&
        result.receipt.desc_module_sha256 ==
            _drstp_sha256(execution_receipt.desc_module_path) ||
        throw(ArgumentError("rho surface provider runtime is foreign to upstream execution"))
    read(result.receipt.input_path, String) == _drstp_request_text(request) ||
        throw(ArgumentError("rho surface provider input differs from canonical request"))
    expected_command = string(`$(result.receipt.python_executable) $(result.receipt.adapter_path) $(result.receipt.upstream_hdf5_path) $(result.receipt.input_path) $(result.receipt.output_path) $(result.receipt.desc_module_path)`)
    result.receipt.command == expected_command ||
        throw(ArgumentError("rho surface provider command does not match sealed runtime paths"))
    parsed = _drstp_parse_output(result.receipt.output_path, request)
    result.context_hash == context.context_hash &&
        result.candidate_hash == context.candidate_hash &&
        result.provider_request_hash == request.request_hash &&
        result.partition_request_hash == canonical_hash(partition_request) &&
        result.partition_result_hash == canonical_hash(partition_result) &&
        result.equilibrium_output_sha256 == execution_receipt.output_sha256 &&
        result.desc_version == parsed.desc_version && result.nfp == parsed.nfp &&
        result.samples == parsed.samples ||
        throw(ArgumentError("rho surface provider result differs from sealed replay"))
    regions = Dict(region.region_id => region for region in partition_request.regions)
    interfaces = Dict(interface.interface_id => interface
        for interface in partition_request.interfaces)
    specs = Dict(spec.spec_hash => spec for spec in request.samples)
    for sample in result.samples
        haskey(specs, sample.spec_hash) ||
            throw(ArgumentError("rho surface provider result names a foreign sample spec"))
        spec = specs[sample.spec_hash]
        interface = interfaces[sample.interface_id]
        minus_region, plus_region = regions[sample.minus_region_id], regions[sample.plus_region_id]
        sample.interface_id == spec.interface_id &&
            sample.minus_region_id == spec.minus_region_id &&
            sample.plus_region_id == spec.plus_region_id &&
            spec.interface_hash == canonical_hash(interface) &&
            spec.minus_region_support_hash == minus_region.region_support_hash &&
            spec.plus_region_support_hash == plus_region.region_support_hash ||
            throw(ArgumentError("rho surface provider interface/support identity mismatch"))
        minus_region.rho_lower < sample.minus_rho < minus_region.rho_upper &&
            plus_region.rho_lower < sample.plus_rho < plus_region.rho_upper ||
            throw(ArgumentError("rho surface provider result violates region ownership"))
    end
    result.result_hash
end

function rerun_desc_rho_surface_trace_provider(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request::DESCRhoSurfaceTraceProviderRequestV4,
        prior::DESCRhoSurfaceTraceProviderResultV4; run_dir)
    validate_desc_rho_surface_trace_provider_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request, prior)
    fresh = execute_desc_rho_surface_trace_provider(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        request; run_dir=run_dir)
    fresh.result_hash == prior.result_hash && semantic_view(fresh) == semantic_view(prior) ||
        throw(ArgumentError("rho surface provider replay mismatch"))
    fresh
end

desc_rho_surface_trace_provider_manifest() = (
    schema=_DRSTP_SCHEMA, revision=_DRSTP_REVISION,
    purpose=:candidate_bound_sampled_rho_surface_geometry_and_two_sided_traces,
    provider_quantities=_DRSTP_QUANTITIES, units=_DRSTP_UNITS,
    provider_selected=true, provider_executed=true,
    output_schema_validated=true, surface_geometry_sampled=true,
    normal_geometry_validated=true, tangent_geometry_validated=true,
    two_sided_trace_executed=true, region_ownership_validated=true,
    declared_normals_cross_checked=false,
    spatial_partition_geometry_validated=false, interface_flux_executed=false,
    solver_convergence_validated=false, multiregion_closure=false,
    physical_validation=false, engineering_validation=false,
    emits_evidence=false, grants_pass=false, promotion_authority=false,
    p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
