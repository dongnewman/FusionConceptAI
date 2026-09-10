"""Analytic, candidate-bound compatibility proof for the DESC geometry program."""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _DGCP_REVISION = "runtime-v4-desc-geometry-compatibility-proof-v1"
const _DGCP_SCHEMA = "fusionconceptai:runtime-v4-desc-geometry-compatibility-proof"
const _DGCP_PRECISION_BITS = 256
const _DGCP_GAPS = (
    "required_current_prover_linear_abs_m1_radial_extension",
    "required_one_positive_major_radius_axis",
    "required_one_positive_radial_m1_n0_base",
    "required_one_positive_vertical_m1_n0_base",
    "required_strict_major_radius_interval_bound",
    "required_strict_cross_section_orientation_interval_bound",
    "required_strict_oriented_volume_density_interval_bound")

_dgcp_down(f) = setprecision(BigFloat, _DGCP_PRECISION_BITS) do
    setrounding(BigFloat, RoundDown) do
        f()
    end
end
_dgcp_up(f) = setprecision(BigFloat, _DGCP_PRECISION_BITS) do
    setrounding(BigFloat, RoundUp) do
        f()
    end
end
function _dgcp_lower_float(value::BigFloat)
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("proof bound is not finite"))
    result > value ? prevfloat(result) : result
end

function _dgcp_linear_axis_regular(program::DESCFourierGeometryProgramV4)
    all(mode -> ((mode.poloidal_mode == 0 && mode.toroidal_mode == 0) ?
            mode.radial_power == 0 :
            abs(mode.poloidal_mode) == 1 && mode.radial_power == 1),
        program.radial_modes) &&
    all(mode -> abs(mode.poloidal_mode) == 1 && mode.radial_power == 1,
        program.vertical_modes)
end

function _dgcp_mode_partition(program::DESCFourierGeometryProgramV4)
    axes = Tuple(mode for mode in program.radial_modes
        if mode.poloidal_mode == 0 && mode.toroidal_mode == 0)
    radial_base = Tuple(mode for mode in program.radial_modes
        if abs(mode.poloidal_mode) == 1 && mode.toroidal_mode == 0)
    vertical_base = Tuple(mode for mode in program.vertical_modes
        if abs(mode.poloidal_mode) == 1 && mode.toroidal_mode == 0)
    radial_remainder = Tuple(mode for mode in program.radial_modes
        if !((mode.poloidal_mode == 0 && mode.toroidal_mode == 0) ||
             (abs(mode.poloidal_mode) == 1 && mode.toroidal_mode == 0)))
    vertical_remainder = Tuple(mode for mode in program.vertical_modes
        if !(abs(mode.poloidal_mode) == 1 && mode.toroidal_mode == 0))
    (axes=axes, radial_base=radial_base, vertical_base=vertical_base,
     radial_remainder=radial_remainder,
     vertical_remainder=vertical_remainder)
end

function _dgcp_directed_bounds(program::DESCFourierGeometryProgramV4,
        parts)
    length(parts.axes) == 1 && length(parts.radial_base) == 1 &&
        length(parts.vertical_base) == 1 || return nothing
    r00 = parts.axes[1].normalized_coefficient
    a = parts.radial_base[1].normalized_coefficient
    b = parts.vertical_base[1].poloidal_mode *
        parts.vertical_base[1].normalized_coefficient
    a > 0.0 && b > 0.0 || return nothing

    radial_amplitude = _dgcp_up() do
        sum(abs(BigFloat(mode.normalized_coefficient))
            for mode in parts.radial_remainder; init=BigFloat(0))
    end
    radial_theta = _dgcp_up() do
        two_pi = BigFloat(2) * BigFloat(pi)
        sum(two_pi * abs(BigFloat(mode.poloidal_mode)) *
            abs(BigFloat(mode.normalized_coefficient))
            for mode in parts.radial_remainder; init=BigFloat(0))
    end
    vertical_amplitude = _dgcp_up() do
        sum(abs(BigFloat(mode.normalized_coefficient))
            for mode in parts.vertical_remainder; init=BigFloat(0))
    end
    vertical_theta = _dgcp_up() do
        two_pi = BigFloat(2) * BigFloat(pi)
        sum(two_pi * abs(BigFloat(mode.poloidal_mode)) *
            abs(BigFloat(mode.normalized_coefficient))
            for mode in parts.vertical_remainder; init=BigFloat(0))
    end
    radial_nonaxis = _dgcp_up() do
        abs(BigFloat(a)) + radial_amplitude
    end
    major_lower = _dgcp_down() do
        BigFloat(r00) - radial_nonaxis
    end
    base_cross = _dgcp_down() do
        BigFloat(2) * BigFloat(pi) * BigFloat(a) * BigFloat(b)
    end
    error_upper = _dgcp_up() do
        two_pi = BigFloat(2) * BigFloat(pi)
        aa, bb = abs(BigFloat(a)), abs(BigFloat(b))
        aa * vertical_theta + two_pi * bb * radial_amplitude +
        radial_amplitude * vertical_theta +
        two_pi * aa * vertical_amplitude + bb * radial_theta +
        radial_theta * vertical_amplitude
    end
    cross_lower = _dgcp_down() do
        base_cross - error_upper
    end
    density_lower = if major_lower > 0 && cross_lower > 0
        _dgcp_down() do
            (BigFloat(2) * BigFloat(pi) /
             BigFloat(program.boundary.field_periods)) *
            major_lower * cross_lower
        end
    else
        BigFloat(-1)
    end
    (major_radius_lower_bound=_dgcp_lower_float(major_lower),
     cross_section_orientation_lower_bound=_dgcp_lower_float(cross_lower),
     normalized_oriented_volume_density_lower_bound=
        _dgcp_lower_float(density_lower),
     base_radial_amplitude=a, base_vertical_amplitude=b,
     determinant_orientation_sign=-1)
end

mutable struct _DGCPPrivateToken end
const _DGCP_TOKEN = _DGCPPrivateToken()

struct DESCGeometryCompatibilityCertificateV4
    payload::NamedTuple
    certificate_hash::Digest256
    function DESCGeometryCompatibilityCertificateV4(
            token::_DGCPPrivateToken, payload::NamedTuple,
            certificate_hash::Digest256)
        token === _DGCP_TOKEN ||
            throw(ArgumentError("private DESC geometry proof constructor"))
        new(payload, certificate_hash)
    end
end
semantic_view(x::DESCGeometryCompatibilityCertificateV4) =
    merge(x.payload, (certificate_hash=x.certificate_hash,))
function canonical_hash(x::DESCGeometryCompatibilityCertificateV4)
    expected = canonical_hash(x.payload)
    expected == x.certificate_hash ||
        throw(ArgumentError("DESC geometry certificate hash mismatch"))
    p = x.payload
    length(keys(p)) == 53 && p.schema == _DGCP_SCHEMA &&
        p.revision == _DGCP_REVISION &&
        p.proof_kind === :desc_geometry_compatibility &&
        p.status === :proved && p.proof_method === :analytic_fourier_mpfr &&
        p.precision_bits == _DGCP_PRECISION_BITS &&
        p.phase_convention === :two_pi_m_theta_minus_n_zeta_field_turn &&
        p.azimuth_convention === :two_pi_zeta_field_turn_over_nfp &&
        p.radial_extension === :explicit_linear_abs_m1_current_prover &&
        p.determinant_orientation_sign == -1 &&
        p.major_radius_lower_bound > 0.0 &&
        p.cross_section_orientation_lower_bound > 0.0 &&
        p.normalized_oriented_volume_density_lower_bound > 0.0 &&
        p.boundary_value_exact &&
        p.boundary_tangential_first_derivatives_exact &&
        p.poloidal_seam_symbolic && p.field_period_equivariance_symbolic &&
        p.metric_identity_symbolic && p.axis_regularity_symbolic &&
        p.global_nondegenerate_for_positive_rho &&
        p.axis_coordinate_singularity_explicit &&
        p.geometric_compatibility_proved && p.certificate_emitted &&
        !p.request_emitted && !p.provider_selected && !p.provider_executed &&
        !p.solver_execution_attempted && !p.solver_executed &&
        !p.physical_validation && !p.engineering_validation &&
        !p.grants_pass && !p.promotion_authority && !p.p5_ready &&
        !p.terminal_authority && p.claim_ceiling == screen_only &&
        p.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC geometry certificate schema mismatch"))
    expected
end

struct DESCGeometryCompatibilityResolutionV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    interpreter_evaluation_hash::Digest256
    recoverable_gaps::Tuple{Vararg{String}}
    certificate::Union{Nothing,DESCGeometryCompatibilityCertificateV4}
    geometric_compatibility_proved::Bool
    certificate_emitted::Bool
    request_emitted::Bool
    claim_ceiling::ClaimCeiling
    credible_physical_device_count::Int
    resolution_hash::Digest256
end
function _dgcp_resolution_body(status, context_hash, candidate_hash,
        evaluation_hash, gaps, certificate)
    proved = status === :proved
    (schema=_DGCP_SCHEMA, revision=_DGCP_REVISION,
     proof_kind=:desc_geometry_compatibility,
     status=status, context_hash=context_hash, candidate_hash=candidate_hash,
     interpreter_evaluation_hash=evaluation_hash, recoverable_gaps=gaps,
     certificate_hash=certificate === nothing ? nothing :
        canonical_hash(certificate),
     geometric_compatibility_proved=proved, certificate_emitted=proved,
     request_emitted=false, claim_ceiling=screen_only,
     credible_physical_device_count=0)
end
semantic_view(x::DESCGeometryCompatibilityResolutionV4) = merge(
    _dgcp_resolution_body(x.status, x.context_hash, x.candidate_hash,
        x.interpreter_evaluation_hash, x.recoverable_gaps, x.certificate),
    (resolution_hash=x.resolution_hash,))
function canonical_hash(x::DESCGeometryCompatibilityResolutionV4)
    x.status in (:proved, :recoverable_gap) ||
        throw(ArgumentError("unknown DESC geometry proof status"))
    Tuple(gap for gap in _DGCP_GAPS if gap in x.recoverable_gaps) ==
        x.recoverable_gaps && length(unique(x.recoverable_gaps)) ==
        length(x.recoverable_gaps) ||
        throw(ArgumentError("DESC geometry proof gaps are not closed and ordered"))
    proved = x.status === :proved
    proved == isempty(x.recoverable_gaps) &&
        proved == (x.certificate !== nothing) &&
        proved == x.geometric_compatibility_proved &&
        proved == x.certificate_emitted && !x.request_emitted &&
        x.claim_ceiling == screen_only &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC geometry proof resolution schema mismatch"))
    x.certificate === nothing || canonical_hash(x.certificate)
    body = _dgcp_resolution_body(x.status, x.context_hash, x.candidate_hash,
        x.interpreter_evaluation_hash, x.recoverable_gaps, x.certificate)
    expected = canonical_hash(body)
    expected == x.resolution_hash ||
        throw(ArgumentError("DESC geometry proof resolution hash mismatch"))
    expected
end

function _dgcp_certificate_payload(context, bridge_resolution, evaluation,
        data, bounds)
    (schema=_DGCP_SCHEMA, revision=_DGCP_REVISION,
     proof_kind=:desc_geometry_compatibility,
     status=:proved, context_hash=context.context_hash,
     candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     declaration_hash=canonical_hash(data.declaration),
     support_hash=canonical_hash(data.support), chart_hash=canonical_hash(data.chart),
     graph_binding_hash=data.graph.binding_hash,
     coordinate_program_hash=canonical_hash(data.coordinate_edge.program),
     metric_program_hash=canonical_hash(data.metric_edge.program),
     bridge_resolution_hash=canonical_hash(bridge_resolution),
     interpreter_evaluation_hash=canonical_hash(evaluation),
     geometry_payload_hash=canonical_hash(data.program),
     proof_method=:analytic_fourier_mpfr,
     precision_bits=_DGCP_PRECISION_BITS,
     phase_convention=:two_pi_m_theta_minus_n_zeta_field_turn,
     azimuth_convention=:two_pi_zeta_field_turn_over_nfp,
     field_periods=data.program.boundary.field_periods,
     radial_extension=:explicit_linear_abs_m1_current_prover,
     determinant_orientation_sign=bounds.determinant_orientation_sign,
     major_radius_lower_bound=bounds.major_radius_lower_bound,
     cross_section_orientation_lower_bound=
        bounds.cross_section_orientation_lower_bound,
     normalized_oriented_volume_density_lower_bound=
        bounds.normalized_oriented_volume_density_lower_bound,
     base_radial_amplitude=bounds.base_radial_amplitude,
     base_vertical_amplitude=bounds.base_vertical_amplitude,
     boundary_value_exact=true,
     boundary_tangential_first_derivatives_exact=true,
     poloidal_seam_symbolic=true, field_period_equivariance_symbolic=true,
     metric_identity_symbolic=true, axis_regularity_symbolic=true,
     global_nondegenerate_for_positive_rho=true,
     axis_coordinate_singularity_explicit=true,
     geometric_compatibility_proved=true, certificate_emitted=true,
     request_emitted=false, provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     grants_pass=false, promotion_authority=false, p5_ready=false,
     terminal_authority=false, claim_ceiling=screen_only,
     credible_physical_device_count=0)
end

function prove_desc_geometry_compatibility(context::ForwardChainContextV4,
        bridge_resolution::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        evaluation::DESCGeometryProgramEvaluationV4)
    validate_desc_geometry_program_evaluation(context, bridge_resolution,
        evaluation)
    data = _dgpi_candidate_program(context, bridge_resolution)
    evaluation.payload_hash == canonical_hash(data.program) ||
        throw(ArgumentError("interpreter evaluation uses a foreign geometry payload"))
    parts = _dgcp_mode_partition(data.program)
    linear = _dgcp_linear_axis_regular(data.program)
    axis_ok = length(parts.axes) == 1 &&
        parts.axes[1].normalized_coefficient > 0.0
    radial_base_ok = length(parts.radial_base) == 1 &&
        parts.radial_base[1].normalized_coefficient > 0.0
    vertical_base_ok = length(parts.vertical_base) == 1 &&
        parts.vertical_base[1].poloidal_mode *
        parts.vertical_base[1].normalized_coefficient > 0.0
    bounds = linear && radial_base_ok && vertical_base_ok ?
        _dgcp_directed_bounds(data.program, parts) : nothing
    major_ok = bounds !== nothing && bounds.major_radius_lower_bound > 0.0
    cross_ok = bounds !== nothing &&
        bounds.cross_section_orientation_lower_bound > 0.0
    density_ok = bounds !== nothing &&
        bounds.normalized_oriented_volume_density_lower_bound > 0.0
    conditions = (linear, axis_ok, radial_base_ok, vertical_base_ok,
        major_ok, cross_ok, density_ok)
    gaps = Tuple(_DGCP_GAPS[i] for i in eachindex(_DGCP_GAPS)
        if !conditions[i])
    certificate = if isempty(gaps)
        payload = _dgcp_certificate_payload(context, bridge_resolution,
            evaluation, data, something(bounds))
        DESCGeometryCompatibilityCertificateV4(_DGCP_TOKEN, payload,
            canonical_hash(payload))
    else
        nothing
    end
    status = isempty(gaps) ? :proved : :recoverable_gap
    body = _dgcp_resolution_body(status, context.context_hash,
        context.candidate_hash, canonical_hash(evaluation), gaps, certificate)
    result = DESCGeometryCompatibilityResolutionV4(status,
        context.context_hash, context.candidate_hash,
        canonical_hash(evaluation), gaps, certificate,
        status === :proved, status === :proved, false, screen_only, 0,
        canonical_hash(body))
    canonical_hash(result)
    result
end

function validate_desc_geometry_compatibility(
        context::ForwardChainContextV4,
        bridge_resolution::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        evaluation::DESCGeometryProgramEvaluationV4,
        resolution::DESCGeometryCompatibilityResolutionV4)
    canonical_hash(resolution)
    rebuilt = prove_desc_geometry_compatibility(context, bridge_resolution,
        evaluation)
    canonical_hash(rebuilt) == resolution.resolution_hash &&
        semantic_view(rebuilt) == semantic_view(resolution) ||
        throw(ArgumentError("DESC geometry proof is foreign to context"))
    resolution.resolution_hash
end

desc_geometry_compatibility_proof_manifest() = (
    schema=_DGCP_SCHEMA, revision=_DGCP_REVISION,
    proof_method=:analytic_fourier_mpfr,
    precision_bits=_DGCP_PRECISION_BITS,
    recoverable_gaps=_DGCP_GAPS, request_emitted=false,
    provider_selected=false, provider_executed=false,
    solver_execution_attempted=false, solver_executed=false,
    physical_validation=false, engineering_validation=false,
    grants_pass=false, promotion_authority=false, p5_ready=false,
    terminal_authority=false, claim_ceiling=screen_only,
    credible_physical_device_count=0)
