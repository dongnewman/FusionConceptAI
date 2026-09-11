# Candidate-bound local ideal-MHD traction and paired interface-flux execution.
#
# The inputs are real DESC pressure/B samples at the exact c±epsilon points from
# the accepted rho-surface provider.  This edge evaluates a local constitutive
# law and a central paired flux only.  It does not validate Rankine-Hugoniot
# conditions, assemble a regional residual/Jacobian, or establish closure.

using FusionConceptAI
using SHA
using LinearAlgebra
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _IMIT_REVISION = "runtime-v4-ideal-mhd-interface-traction-v1"
const _IMIT_SCHEMA = "fusionconceptai:runtime-v4-ideal-mhd-interface-traction"
const _IMIT_MU0_N_A2 = 1.25663706127e-6
const _IMIT_MU0_UNIT = raw"N \cdot A^{-2}"
const _IMIT_MU0_SOURCE = "NIST-CODATA-2022-vacuum-magnetic-permeability"
const _IMIT_NORMAL_CONVENTION = :minus_and_plus_region_outward_unit_normals
const _IMIT_STATE_SEMANTICS = :desc_c_plus_minus_epsilon_proxy_not_boundary_limit
const _IMIT_FLUX_FORMULA = :central_oriented_traction_half_tminus_minus_tplus
const _IMIT_TRACTION_UNIT = "Pa"
const _IMIT_TOKEN = Val(:ideal_mhd_interface_traction_private)
const _IMIT_SOURCE_PATH = abspath(@__FILE__)

_imit_sha256(path::AbstractString) =
    Digest256(bytes2hex(SHA.sha256(read(path))))

function _imit_text(value, field)
    typeof(value) === String || throw(ArgumentError("$field must be a String"))
    result = strip(value)
    !isempty(result) && isvalid(result) &&
        !any(character -> character in ('\t', '\r', '\n'), result) ||
        throw(ArgumentError("$field is empty or unsafe"))
    result
end

function _imit_vec3(value, field)
    value isa Tuple && !(value isa NamedTuple) && length(value) == 3 ||
        throw(ArgumentError("$field must be an immutable 3-tuple"))
    result = ntuple(i -> Float64(value[i]), 3)
    all(isfinite, result) || throw(ArgumentError("$field must be finite"))
    result
end

struct IdealMHDInterfaceTractionSpecV4
    interface_id::String
    interface_hash::Digest256
    minus_region_id::String
    plus_region_id::String
    minus_region_support_hash::Digest256
    plus_region_support_hash::Digest256
    surface_sample_hash::Digest256
    minus_state_point_hash::Digest256
    plus_state_point_hash::Digest256
    minus_state_sample_hash::Digest256
    plus_state_sample_hash::Digest256
    quadrature_rule::Symbol
    quadrature_weight::Float64
    spec_hash::Digest256
    function IdealMHDInterfaceTractionSpecV4(
            token::Val{:ideal_mhd_interface_traction_private}, fields...)
        token === _IMIT_TOKEN || throw(ArgumentError("private traction spec constructor"))
        new(fields...)
    end
end

function _imit_spec_body(x::IdealMHDInterfaceTractionSpecV4)
    names = fieldnames(typeof(x))[1:end-1]
    NamedTuple{names}(ntuple(i -> getfield(x, i), length(names)))
end
semantic_view(x::IdealMHDInterfaceTractionSpecV4) = _imit_spec_body(x)

function canonical_hash(x::IdealMHDInterfaceTractionSpecV4)
    _imit_text(x.interface_id, "interface_id") == x.interface_id &&
        _imit_text(x.minus_region_id, "minus_region_id") == x.minus_region_id &&
        _imit_text(x.plus_region_id, "plus_region_id") == x.plus_region_id &&
        x.minus_region_id != x.plus_region_id &&
        x.quadrature_rule === :single_point_sample_no_surface_integral &&
        x.quadrature_weight == 1.0 ||
        throw(ArgumentError("invalid ideal-MHD traction specification"))
    expected = canonical_hash(semantic_view(x))
    expected == x.spec_hash || throw(ArgumentError("traction spec hash mismatch"))
    expected
end

struct IdealMHDInterfaceTractionRequestV4
    revision::String
    schema::String
    request_kind::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    geometry_bridge_hash::Digest256
    geometry_evaluation_hash::Digest256
    geometry_proof_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    basis_request_hash::Digest256
    basis_result_hash::Digest256
    partition_request_hash::Digest256
    partition_result_hash::Digest256
    partition_receipt_hash::Digest256
    surface_request_hash::Digest256
    surface_result_hash::Digest256
    surface_receipt_hash::Digest256
    pressure_field_request_hash::Digest256
    pressure_field_result_hash::Digest256
    pressure_field_receipt_hash::Digest256
    specs::Tuple{Vararg{IdealMHDInterfaceTractionSpecV4}}
    mu0_N_A2::Float64
    mu0_unit::String
    mu0_source::String
    B_unit::String
    pressure_unit::String
    traction_unit::String
    normal_convention::Symbol
    state_semantics::Symbol
    constitutive_formula::Symbol
    numerical_flux_formula::Symbol
    residual_owner::Symbol
    jacobian_owner::Symbol
    source_path::String
    source_sha256::Digest256
    julia_executable::String
    julia_executable_sha256::Digest256
    claim_ceiling::ClaimCeiling
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    request_hash::Digest256
    function IdealMHDInterfaceTractionRequestV4(
            token::Val{:ideal_mhd_interface_traction_private}, fields...)
        token === _IMIT_TOKEN || throw(ArgumentError("private traction request constructor"))
        new(fields...)
    end
end

function _imit_body_without_last(x)
    names = fieldnames(typeof(x))[1:end-1]
    NamedTuple{names}(ntuple(i -> getfield(x, i), length(names)))
end
semantic_view(x::IdealMHDInterfaceTractionRequestV4) = _imit_body_without_last(x)

function canonical_hash(x::IdealMHDInterfaceTractionRequestV4)
    x.revision == _IMIT_REVISION && x.schema == _IMIT_SCHEMA &&
        x.request_kind === :candidate_bound_local_ideal_mhd_interface_traction &&
        !isempty(x.specs) && length(x.specs) <= 4096 ||
        throw(ArgumentError("ideal-MHD traction request schema/count mismatch"))
    foreach(canonical_hash, x.specs)
    length(unique(canonical_hash.(x.specs))) == length(x.specs) ||
        throw(ArgumentError("ideal-MHD traction request repeats a spec"))
    x.mu0_N_A2 == _IMIT_MU0_N_A2 && x.mu0_unit == _IMIT_MU0_UNIT &&
        x.mu0_source == _IMIT_MU0_SOURCE && x.B_unit == "T" &&
        x.pressure_unit == "Pa" && x.traction_unit == _IMIT_TRACTION_UNIT &&
        x.normal_convention === _IMIT_NORMAL_CONVENTION &&
        x.state_semantics === _IMIT_STATE_SEMANTICS &&
        x.constitutive_formula === :ideal_mhd_static_momentum_flux_tensor &&
        x.numerical_flux_formula === _IMIT_FLUX_FORMULA &&
        x.residual_owner === :not_assembled && x.jacobian_owner === :not_executed ||
        throw(ArgumentError("ideal-MHD traction convention mismatch"))
    isfile(x.source_path) && _imit_sha256(x.source_path) == x.source_sha256 ||
        throw(ArgumentError("ideal-MHD traction source is missing or changed"))
    isfile(x.julia_executable) &&
        _imit_sha256(x.julia_executable) == x.julia_executable_sha256 ||
        throw(ArgumentError("ideal-MHD traction Julia runtime is missing or changed"))
    x.claim_ceiling == screen_only && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("ideal-MHD traction request exceeds screen-only authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash || throw(ArgumentError("ideal-MHD traction request hash mismatch"))
    expected
end

function _imit_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result)
    trusted = parentmodule(typeof(context))
    trusted === (@__MODULE__) ||
        throw(ArgumentError("ideal-MHD traction context is outside its trust root"))
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
        (partition_result, :DESCRhoPartitionResultV4),
        (surface_request, :DESCRhoSurfaceTraceProviderRequestV4),
        (surface_result, :DESCRhoSurfaceTraceProviderResultV4),
        (pressure_request, :DESCFieldProviderRequestV4),
        (pressure_result, :DESCFieldProviderResultV4))
    all(isdefined(trusted, name) && typeof(value) === getfield(trusted, name)
        for (value, name) in expected) ||
        throw(ArgumentError("ideal-MHD traction upstream type/module is untrusted"))
    getfield(trusted, :validate_desc_rho_surface_trace_provider_result)(context,
        geometry_bridge, geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result)
    getfield(trusted, :validate_desc_field_provider_result)(context,
        execution_request, execution_result, execution_receipt,
        pressure_request, pressure_result)
    surface_result.two_sided_trace_executed &&
        surface_result.region_ownership_validated &&
        !surface_result.interface_flux_executed && pressure_result.provider_executed ||
        throw(ArgumentError("ideal-MHD traction upstream execution is not accepted"))
    pressure_request.equilibrium_output_sha256 == surface_request.equilibrium_output_sha256 &&
        pressure_result.context_hash == context.context_hash &&
        pressure_result.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("pressure states are foreign to the rho-surface execution"))
    true
end

function ideal_mhd_pressure_points(surface_result)
    points = getfield(parentmodule(typeof(surface_result)), :DESCFieldSamplePointV4)[]
    for sample in surface_result.samples
        push!(points, getfield(parentmodule(typeof(surface_result)),
            :DESCFieldSamplePointV4)(sample.minus_rho, sample.theta_rad,
                sample.zeta_rad))
        push!(points, getfield(parentmodule(typeof(surface_result)),
            :DESCFieldSamplePointV4)(sample.plus_rho, sample.theta_rad,
                sample.zeta_rad))
    end
    Tuple(points)
end

function _imit_specs(partition_request, surface_result, pressure_request,
        pressure_result)
    expected_points = ideal_mhd_pressure_points(surface_result)
    pressure_request.points == expected_points &&
        length(pressure_result.samples) == length(expected_points) ||
        throw(ArgumentError("pressure request/result do not cover exact two-sided points"))
    interfaces = Dict(interface.interface_id => interface
        for interface in partition_request.interfaces)
    regions = Dict(region.region_id => region for region in partition_request.regions)
    specs = IdealMHDInterfaceTractionSpecV4[]
    for (index, surface) in enumerate(surface_result.samples)
        interface = interfaces[surface.interface_id]
        minus_region, plus_region = regions[surface.minus_region_id], regions[surface.plus_region_id]
        minus_state, plus_state = pressure_result.samples[2index-1], pressure_result.samples[2index]
        body = (interface_id=surface.interface_id,
            interface_hash=canonical_hash(interface),
            minus_region_id=surface.minus_region_id,
            plus_region_id=surface.plus_region_id,
            minus_region_support_hash=minus_region.region_support_hash,
            plus_region_support_hash=plus_region.region_support_hash,
            surface_sample_hash=canonical_hash(surface),
            minus_state_point_hash=canonical_hash(minus_state.point),
            plus_state_point_hash=canonical_hash(plus_state.point),
            minus_state_sample_hash=canonical_hash(minus_state),
            plus_state_sample_hash=canonical_hash(plus_state),
            quadrature_rule=:single_point_sample_no_surface_integral,
            quadrature_weight=1.0)
        spec = IdealMHDInterfaceTractionSpecV4(_IMIT_TOKEN, values(body)...,
            canonical_hash(body))
        canonical_hash(spec)
        push!(specs, spec)
    end
    Tuple(specs)
end

function make_ideal_mhd_interface_traction_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result)
    _imit_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result)
    specs = _imit_specs(partition_request, surface_result, pressure_request,
        pressure_result)
    julia_executable = abspath(String(Base.julia_cmd().exec[1]))
    body = (revision=_IMIT_REVISION, schema=_IMIT_SCHEMA,
        request_kind=:candidate_bound_local_ideal_mhd_interface_traction,
        context_hash=context.context_hash, candidate_hash=context.candidate_hash,
        geometry_bridge_hash=canonical_hash(geometry_bridge),
        geometry_evaluation_hash=canonical_hash(geometry_evaluation),
        geometry_proof_hash=canonical_hash(geometry_proof),
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        equilibrium_output_sha256=execution_receipt.output_sha256,
        basis_request_hash=canonical_hash(basis_request),
        basis_result_hash=canonical_hash(basis_result),
        partition_request_hash=canonical_hash(partition_request),
        partition_result_hash=canonical_hash(partition_result),
        partition_receipt_hash=canonical_hash(partition_result.receipt),
        surface_request_hash=canonical_hash(surface_request),
        surface_result_hash=canonical_hash(surface_result),
        surface_receipt_hash=canonical_hash(surface_result.receipt),
        pressure_field_request_hash=canonical_hash(pressure_request),
        pressure_field_result_hash=canonical_hash(pressure_result),
        pressure_field_receipt_hash=canonical_hash(pressure_result.receipt),
        specs=specs, mu0_N_A2=_IMIT_MU0_N_A2,
        mu0_unit=_IMIT_MU0_UNIT, mu0_source=_IMIT_MU0_SOURCE,
        B_unit="T", pressure_unit="Pa", traction_unit=_IMIT_TRACTION_UNIT,
        normal_convention=_IMIT_NORMAL_CONVENTION,
        state_semantics=_IMIT_STATE_SEMANTICS,
        constitutive_formula=:ideal_mhd_static_momentum_flux_tensor,
        numerical_flux_formula=_IMIT_FLUX_FORMULA,
        residual_owner=:not_assembled, jacobian_owner=:not_executed,
        source_path=_IMIT_SOURCE_PATH, source_sha256=_imit_sha256(_IMIT_SOURCE_PATH),
        julia_executable=julia_executable,
        julia_executable_sha256=_imit_sha256(julia_executable),
        claim_ceiling=screen_only, emits_evidence=false, grants_pass=false,
        promotion_authority=false, p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0)
    request = IdealMHDInterfaceTractionRequestV4(_IMIT_TOKEN, values(body)...,
        canonical_hash(body))
    canonical_hash(request)
    request
end

function validate_ideal_mhd_interface_traction_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, request::IdealMHDInterfaceTractionRequestV4)
    expected = make_ideal_mhd_interface_traction_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result)
    semantic_view(request) == semantic_view(expected) ||
        throw(ArgumentError("ideal-MHD traction request is not the current reconstruction"))
    request
end

function _imit_cyl_to_cart(vector, position)
    phi = atan(position[2], position[1])
    radial, toroidal, vertical = vector
    (radial*cos(phi)-toroidal*sin(phi),
     radial*sin(phi)+toroidal*cos(phi), vertical)
end

function _imit_traction(p, B, n, mu0)
    magnetic_pressure = dot(B, B) / (2mu0)
    scale = (p + magnetic_pressure)
    traction = ntuple(i -> scale*n[i] - B[i]*dot(B, n)/mu0, 3)
    (magnetic_pressure=magnetic_pressure, total_pressure=p+magnetic_pressure,
     traction=traction)
end

struct IdealMHDInterfaceTractionSampleV4
    spec_hash::Digest256
    interface_id::String
    minus_region_id::String
    plus_region_id::String
    minus_pressure_Pa::Float64
    plus_pressure_Pa::Float64
    minus_B_xyz_T::NTuple{3,Float64}
    plus_B_xyz_T::NTuple{3,Float64}
    minus_outward_normal_xyz::NTuple{3,Float64}
    plus_outward_normal_xyz::NTuple{3,Float64}
    minus_magnetic_pressure_Pa::Float64
    plus_magnetic_pressure_Pa::Float64
    minus_total_pressure_Pa::Float64
    plus_total_pressure_Pa::Float64
    minus_traction_xyz_Pa::NTuple{3,Float64}
    plus_traction_xyz_Pa::NTuple{3,Float64}
    traction_jump_residual_xyz_Pa::NTuple{3,Float64}
    traction_jump_residual_norm_Pa::Float64
    central_oriented_traction_xyz_Pa::NTuple{3,Float64}
    minus_flux_contribution_xyz_Pa::NTuple{3,Float64}
    plus_flux_contribution_xyz_Pa::NTuple{3,Float64}
    paired_flux_defect_xyz_Pa::NTuple{3,Float64}
    paired_flux_defect_norm_Pa::Float64
    sample_hash::Digest256
    function IdealMHDInterfaceTractionSampleV4(
            token::Val{:ideal_mhd_interface_traction_private}, fields...)
        token === _IMIT_TOKEN || throw(ArgumentError("private traction sample constructor"))
        new(fields...)
    end
end

semantic_view(x::IdealMHDInterfaceTractionSampleV4) = _imit_body_without_last(x)
function canonical_hash(x::IdealMHDInterfaceTractionSampleV4)
    vectors = (:minus_B_xyz_T, :plus_B_xyz_T, :minus_outward_normal_xyz,
        :plus_outward_normal_xyz, :minus_traction_xyz_Pa,
        :plus_traction_xyz_Pa, :traction_jump_residual_xyz_Pa,
        :central_oriented_traction_xyz_Pa, :minus_flux_contribution_xyz_Pa,
        :plus_flux_contribution_xyz_Pa, :paired_flux_defect_xyz_Pa)
    foreach(name -> _imit_vec3(getfield(x, name), String(name)), vectors)
    scalars = (x.minus_pressure_Pa, x.plus_pressure_Pa,
        x.minus_magnetic_pressure_Pa, x.plus_magnetic_pressure_Pa,
        x.minus_total_pressure_Pa, x.plus_total_pressure_Pa,
        x.traction_jump_residual_norm_Pa, x.paired_flux_defect_norm_Pa)
    all(isfinite, scalars) && all(value -> value >= 0.0, scalars) ||
        throw(ArgumentError("ideal-MHD traction sample has invalid scalar"))
    isapprox(norm(collect(x.minus_outward_normal_xyz)), 1.0; atol=5e-10, rtol=0) &&
        isapprox(norm(collect(x.plus_outward_normal_xyz)), 1.0; atol=5e-10, rtol=0) &&
        maximum(abs.(collect(x.minus_outward_normal_xyz) .+
            collect(x.plus_outward_normal_xyz))) <= 5e-10 ||
        throw(ArgumentError("ideal-MHD traction normals are not opposite units"))
    x.minus_flux_contribution_xyz_Pa == x.central_oriented_traction_xyz_Pa &&
        x.plus_flux_contribution_xyz_Pa == Tuple(-v for v in x.central_oriented_traction_xyz_Pa) &&
        x.paired_flux_defect_xyz_Pa == (0.0, 0.0, 0.0) &&
        x.paired_flux_defect_norm_Pa == 0.0 ||
        throw(ArgumentError("central paired flux does not cancel algebraically"))
    expected = canonical_hash(semantic_view(x))
    expected == x.sample_hash || throw(ArgumentError("traction sample hash mismatch"))
    expected
end

struct IdealMHDInterfaceTractionResultV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    request_hash::Digest256
    surface_result_hash::Digest256
    pressure_field_result_hash::Digest256
    samples::Tuple{Vararg{IdealMHDInterfaceTractionSampleV4}}
    provider_selected::Bool
    provider_executed::Bool
    constitutive_evaluated::Bool
    one_sided_traction_validated::Bool
    traction_jump_evaluated::Bool
    numerical_flux_evaluated::Bool
    paired_flux_assembled::Bool
    central_pair_cancelled::Bool
    interface_flux_executed::Bool
    jump_conditions_validated::Bool
    regional_residual_assembled::Bool
    jacobian_executed::Bool
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
    result_hash::Digest256
    function IdealMHDInterfaceTractionResultV4(
            token::Val{:ideal_mhd_interface_traction_private}, fields...)
        token === _IMIT_TOKEN || throw(ArgumentError("private traction result constructor"))
        new(fields...)
    end
end

semantic_view(x::IdealMHDInterfaceTractionResultV4) = _imit_body_without_last(x)
function canonical_hash(x::IdealMHDInterfaceTractionResultV4)
    foreach(canonical_hash, x.samples)
    x.status === :local_ideal_mhd_interface_traction_executed &&
        !isempty(x.samples) && x.provider_selected && x.provider_executed &&
        x.constitutive_evaluated && x.one_sided_traction_validated &&
        x.traction_jump_evaluated && x.numerical_flux_evaluated &&
        x.paired_flux_assembled && x.central_pair_cancelled &&
        x.interface_flux_executed && !x.jump_conditions_validated &&
        !x.regional_residual_assembled && !x.jacobian_executed &&
        !x.solver_convergence_validated && !x.multiregion_closure &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only ||
        throw(ArgumentError("ideal-MHD traction result exceeds local screen authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash || throw(ArgumentError("traction result hash mismatch"))
    expected
end

function _imit_sample(spec, surface, minus_state, plus_state, request)
    canonical_hash(spec); canonical_hash(surface)
    canonical_hash(minus_state); canonical_hash(plus_state)
    minus_B = _imit_cyl_to_cart(minus_state.B_desc_native_T,
        surface.minus_position_xyz_m)
    plus_B = _imit_cyl_to_cart(plus_state.B_desc_native_T,
        surface.plus_position_xyz_m)
    all(isapprox.(minus_B, surface.minus_B_xyz_T; rtol=1e-11, atol=1e-11)) &&
        all(isapprox.(plus_B, surface.plus_B_xyz_T; rtol=1e-11, atol=1e-11)) ||
        throw(ArgumentError("pressure-state B does not match rho-surface B"))
    minus = _imit_traction(minus_state.pressure_Pa, minus_B,
        surface.minus_outward_normal_xyz, request.mu0_N_A2)
    plus = _imit_traction(plus_state.pressure_Pa, plus_B,
        surface.plus_outward_normal_xyz, request.mu0_N_A2)
    jump = ntuple(i -> minus.traction[i] + plus.traction[i], 3)
    central = ntuple(i -> 0.5*(minus.traction[i] - plus.traction[i]), 3)
    plus_flux = ntuple(i -> -central[i], 3)
    defect = ntuple(i -> central[i] + plus_flux[i], 3)
    body = (spec_hash=spec.spec_hash, interface_id=spec.interface_id,
        minus_region_id=spec.minus_region_id, plus_region_id=spec.plus_region_id,
        minus_pressure_Pa=minus_state.pressure_Pa,
        plus_pressure_Pa=plus_state.pressure_Pa,
        minus_B_xyz_T=minus_B, plus_B_xyz_T=plus_B,
        minus_outward_normal_xyz=surface.minus_outward_normal_xyz,
        plus_outward_normal_xyz=surface.plus_outward_normal_xyz,
        minus_magnetic_pressure_Pa=minus.magnetic_pressure,
        plus_magnetic_pressure_Pa=plus.magnetic_pressure,
        minus_total_pressure_Pa=minus.total_pressure,
        plus_total_pressure_Pa=plus.total_pressure,
        minus_traction_xyz_Pa=minus.traction,
        plus_traction_xyz_Pa=plus.traction,
        traction_jump_residual_xyz_Pa=jump,
        traction_jump_residual_norm_Pa=norm(collect(jump)),
        central_oriented_traction_xyz_Pa=central,
        minus_flux_contribution_xyz_Pa=central,
        plus_flux_contribution_xyz_Pa=plus_flux,
        paired_flux_defect_xyz_Pa=defect,
        paired_flux_defect_norm_Pa=norm(collect(defect)))
    result = IdealMHDInterfaceTractionSampleV4(_IMIT_TOKEN, values(body)...,
        canonical_hash(body))
    canonical_hash(result)
    result
end

function _imit_compute(context, surface_result, pressure_result, request)
    samples = IdealMHDInterfaceTractionSampleV4[]
    for (index, spec) in enumerate(request.specs)
        push!(samples, _imit_sample(spec, surface_result.samples[index],
            pressure_result.samples[2index-1], pressure_result.samples[2index],
            request))
    end
    body = (status=:local_ideal_mhd_interface_traction_executed,
        context_hash=context.context_hash, candidate_hash=context.candidate_hash,
        request_hash=request.request_hash,
        surface_result_hash=canonical_hash(surface_result),
        pressure_field_result_hash=canonical_hash(pressure_result),
        samples=Tuple(samples), provider_selected=true, provider_executed=true,
        constitutive_evaluated=true, one_sided_traction_validated=true,
        traction_jump_evaluated=true, numerical_flux_evaluated=true,
        paired_flux_assembled=true, central_pair_cancelled=true,
        interface_flux_executed=true, jump_conditions_validated=false,
        regional_residual_assembled=false, jacobian_executed=false,
        solver_convergence_validated=false, multiregion_closure=false,
        physical_validation=false, engineering_validation=false,
        emits_evidence=false, grants_pass=false, promotion_authority=false,
        p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only)
    IdealMHDInterfaceTractionResultV4(_IMIT_TOKEN, values(body)...,
        canonical_hash(body))
end

function execute_ideal_mhd_interface_traction(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        request::IdealMHDInterfaceTractionRequestV4)
    validate_ideal_mhd_interface_traction_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        request)
    result = _imit_compute(context, surface_result, pressure_result, request)
    validate_ideal_mhd_interface_traction_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        request, result)
    result
end

function validate_ideal_mhd_interface_traction_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        request::IdealMHDInterfaceTractionRequestV4,
        result::IdealMHDInterfaceTractionResultV4)
    validate_ideal_mhd_interface_traction_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        request)
    canonical_hash(result)
    rebuilt = _imit_compute(context, surface_result, pressure_result, request)
    semantic_view(result) == semantic_view(rebuilt) ||
        throw(ArgumentError("ideal-MHD traction result differs from independent recomputation"))
    result.result_hash
end

ideal_mhd_interface_traction_manifest() = (
    schema=_IMIT_SCHEMA, revision=_IMIT_REVISION,
    mu0_N_A2=_IMIT_MU0_N_A2, mu0_unit=_IMIT_MU0_UNIT,
    mu0_source=_IMIT_MU0_SOURCE, normal_convention=_IMIT_NORMAL_CONVENTION,
    state_semantics=_IMIT_STATE_SEMANTICS,
    constitutive_formula=:ideal_mhd_static_momentum_flux_tensor,
    numerical_flux_formula=_IMIT_FLUX_FORMULA,
    provider_selected=true, provider_executed=true,
    constitutive_evaluated=true, one_sided_traction_validated=true,
    traction_jump_evaluated=true, numerical_flux_evaluated=true,
    paired_flux_assembled=true, central_pair_cancelled=true,
    interface_flux_executed=true, jump_conditions_validated=false,
    regional_residual_assembled=false, jacobian_executed=false,
    solver_convergence_validated=false, multiregion_closure=false,
    physical_validation=false, engineering_validation=false,
    emits_evidence=false, grants_pass=false, promotion_authority=false,
    p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
