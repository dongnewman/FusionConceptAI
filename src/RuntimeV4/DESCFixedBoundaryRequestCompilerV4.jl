"""Candidate-bound compiler for a DESC 0.17.3 fixed-boundary request.

This isolated slice defines the exact translation contract for one already-
composed RuntimeV4 3-D input.  It requires an explicit coordinate/Fourier
convention declaration and DESC-specific controls.  The current typed geometry
cannot prove that convention against the physical chart, so public compilation
returns an exact recoverable geometry-proof gap and emits no request.  Generic
mesh, finite-element, Newton, linear-solver, and refinement controls remain
identity-bearing inputs and are not translated.

The compiler selects or executes no provider, invokes no solver, emits no
evidence, and grants no pass, promotion, P5, or terminal authority.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _DFBRC_REVISION = "runtime-v4-desc-fixed-boundary-request-compiler-v1"
const _DFBRC_SCHEMA = "fusionconceptai:runtime-v4-desc-fixed-boundary-request"
const _DFBRC_RUNNER_VERSION =
    "desc_explicit_fourier_fixed_boundary_runner_v1"
const _DFBRC_MODEL_ID = "stellarator_symmetric_fourier_fixed_boundary_v1"
const _DFBRC_SOURCE_BINDING = "DESC-0.17.3"
const _DFBRC_REQUIRED_GAPS = (
    "required_desc_geometry_convention_declaration",
    "required_desc_fixed_boundary_request_declaration",
    "required_desc_fixed_boundary_request_subject_binding")
const _DFBRC_GEOMETRY_PROOF_GAP =
    "required_verified_desc_geometric_compatibility_proof"
const _DFBRC_COMPOSITION_AMBIGUITY_GAPS = (
    "ambiguous_typed_three_d_geometry_profile_declaration",
    "ambiguous_three_d_physical_provider_input_subject_binding",
    "ambiguous_typed_three_d_physical_region_support_mapping",
    "ambiguous_three_d_physical_region_support_mapping_subject_binding",
    "ambiguous_typed_three_d_region_law_exact_cover_set",
    "ambiguous_three_d_region_law_set_subject_binding",
    "ambiguous_typed_three_d_oriented_interface_discrete_spaces",
    "ambiguous_three_d_oriented_interface_subject_binding",
    "ambiguous_typed_three_d_governing_residual_jacobian_ownership",
    "ambiguous_three_d_governing_residual_jacobian_subject_binding",
    "ambiguous_typed_three_d_discretization_controls",
    "ambiguous_three_d_discretization_controls_subject_binding",
    "ambiguous_three_d_physical_input_composition_subject_binding")
const _DFBRC_INVENTORY_AMBIGUITY_GAPS = (
    "ambiguous_desc_geometry_convention_declaration",
    "ambiguous_desc_fixed_boundary_request_declaration",
    "ambiguous_desc_fixed_boundary_request_subject_binding")
const _DFBRC_DOMAIN_GAPS = (
    "desc_compatibility_physical_hash_mismatch",
    "desc_compatibility_support_mapping_hash_mismatch",
    "desc_compatibility_support_ref_mismatch",
    "desc_compatibility_chart_ref_mismatch",
    "desc_field_periods_outside_2_8",
    "desc_requires_stellarator_symmetric_boundary",
    "desc_radial_mode_count_outside_1_30",
    "desc_vertical_mode_count_outside_1_30",
    "desc_boundary_mode_outside_abs_6",
    "desc_radial_mode_would_be_truncated_by_symmetry",
    "desc_vertical_mode_would_be_truncated_by_symmetry",
    "desc_requires_one_positive_major_radius_mode",
    "desc_major_radius_dominance_not_satisfied",
    "desc_boundary_not_strictly_right_handed",
    "desc_spectral_m_below_boundary_mode",
    "desc_spectral_n_below_boundary_mode",
    "desc_pressure_series_length_outside_1_13",
    "desc_requires_iota_profile_not_current",
    "desc_iota_series_length_outside_1_13",
    "desc_toroidal_flux_outside_1e_4_100_wb",
    "desc_pressure_profile_not_positive",
    "desc_pressure_profile_negative_on_audited_grid",
    "desc_pressure_profile_not_closed_at_rho_1",
    "desc_iota_profile_outside_abs_0_02_3",
    _DFBRC_GEOMETRY_PROOF_GAP)
const _DFBRC_GAP_VOCABULARY = (
    _TDPIC_REQUIRED_GAPS[1], _TDPIC_REQUIRED_GAPS[2],
    _TDPIC_REQUIRED_GAPS[3], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[1],
    _TDPIC_REQUIRED_GAPS[4], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[2],
    _TDPIC_REQUIRED_GAPS[5], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[3],
    _TDPIC_REQUIRED_GAPS[6], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[4],
    _TDPIC_REQUIRED_GAPS[7], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[5],
    _TDPIC_REQUIRED_GAPS[8], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[6],
    _TDPIC_REQUIRED_GAPS[9], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[7],
    _TDPIC_REQUIRED_GAPS[10], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[8],
    _TDPIC_REQUIRED_GAPS[11], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[9],
    _TDPIC_REQUIRED_GAPS[12], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[10],
    _TDPIC_REQUIRED_GAPS[13], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[11],
    _TDPIC_REQUIRED_GAPS[14], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[12],
    _TDPIC_REQUIRED_GAPS[15], _DFBRC_COMPOSITION_AMBIGUITY_GAPS[13],
    _DFBRC_REQUIRED_GAPS[1], _DFBRC_INVENTORY_AMBIGUITY_GAPS[1],
    _DFBRC_REQUIRED_GAPS[2], _DFBRC_INVENTORY_AMBIGUITY_GAPS[2],
    _DFBRC_REQUIRED_GAPS[3], _DFBRC_INVENTORY_AMBIGUITY_GAPS[3],
    _DFBRC_DOMAIN_GAPS...)

const _DFBRC_COORDINATE_ORDER = (:rho, :theta, :zeta)
const _DFBRC_RADIAL_DOMAIN = :rho_zero_to_one
const _DFBRC_TOROIDAL_DOMAIN = :zeta_zero_to_two_pi_over_nfp
const _DFBRC_R_BASIS = :cos_mtheta_minus_n_nfp_zeta
const _DFBRC_Z_BASIS = :sin_mtheta_minus_n_nfp_zeta
const _DFBRC_MODE_MAPPING = :poloidal_to_m_toroidal_to_n_identity
const _DFBRC_PROFILE_BASIS = :ascending_monic_power_series_in_rho
const _DFBRC_ORIENTATION = :right_handed_e_theta_cross_e_zeta_outward

function _dfbrc_text(value, field::String)
    typeof(value) === String ||
        throw(ArgumentError("$field must be an immutable String"))
    text = strip(value)
    !isempty(text) && isvalid(text) ||
        throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(text)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', text)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(text)
end

function _dfbrc_validate_gap_tuple(gaps)
    gaps isa Tuple && !(gaps isa NamedTuple) && !isempty(gaps) &&
        all(x -> typeof(x) === String, gaps) ||
        throw(ArgumentError("DESC recoverable gaps must be a nonempty immutable String tuple"))
    normalized = Tuple(_dfbrc_text(x, "recoverable gap") for x in gaps)
    normalized == gaps ||
        throw(ArgumentError("DESC recoverable gaps must use canonical text"))
    ranks = Tuple(findfirst(==(gap), _DFBRC_GAP_VOCABULARY)
        for gap in gaps)
    all(x -> !isnothing(x), ranks) ||
        throw(ArgumentError("DESC recoverable gap is outside the closed vocabulary"))
    integer_ranks = Tuple(Int(rank) for rank in ranks)
    length(unique(integer_ranks)) == length(integer_ranks) &&
        issorted(integer_ranks) ||
        throw(ArgumentError("DESC recoverable gaps must be unique and canonically ordered"))
    gaps
end

function _dfbrc_int(value, field::String; minimum::Int, maximum::Int)
    value isa Bool && throw(ArgumentError("$field must be an integer, not Bool"))
    typeof(value) <: Integer || throw(ArgumentError("$field must be an integer"))
    typemin(Int) <= value <= typemax(Int) ||
        throw(ArgumentError("$field is out of range"))
    result = Int(value)
    minimum <= result <= maximum ||
        throw(ArgumentError("$field is outside its admitted range"))
    result
end

function _dfbrc_finite_range(value, field::String, minimum::Float64,
        maximum::Float64)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) && minimum <= result <= maximum ||
        throw(ArgumentError("$field is outside its admitted finite range"))
    result
end

function _dfbrc_finite(value, field::String)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$field must be finite"))
    result
end

mutable struct _DFBRCPrivateToken end
const _DFBRC_TOKEN = _DFBRCPrivateToken()

function _dfbrc_compatibility_body(declaration_id, physical_hash,
        support_mapping_hash, support_ref, chart_ref)
    (revision=_DFBRC_REVISION,
     declaration_kind=:desc_fixed_boundary_geometric_compatibility,
     declaration_id=declaration_id,
     physical_declaration_hash=physical_hash,
     support_mapping_declaration_hash=support_mapping_hash,
     physical_support_ref=support_ref, chart_ref=chart_ref,
     coordinate_order=_DFBRC_COORDINATE_ORDER,
     radial_domain=_DFBRC_RADIAL_DOMAIN,
     toroidal_domain=_DFBRC_TOROIDAL_DOMAIN,
     radial_fourier_basis=_DFBRC_R_BASIS,
     vertical_fourier_basis=_DFBRC_Z_BASIS,
     mode_index_mapping=_DFBRC_MODE_MAPPING,
     radial_profile_basis=_DFBRC_PROFILE_BASIS,
     coordinate_orientation=_DFBRC_ORIENTATION,
     coefficient_length_unit=:metre,
     geometric_compatibility_proved=false,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

"""Candidate-owned declaration of the proposed RuntimeV4-to-DESC convention.

It deliberately records `geometric_compatibility_proved=false`.  Current typed
geometry does not contain enough executable coordinate-map semantics to prove
this mapping, and no caller-supplied reference or hash can promote it.
"""
struct DESCGeometryCompatibilityV4
    declaration_id::String
    physical_declaration_hash::Digest256
    support_mapping_declaration_hash::Digest256
    physical_support_ref::SpatialSupportRefV1
    chart_ref::ChartRefV1
    coordinate_order::NTuple{3,Symbol}
    radial_domain::Symbol
    toroidal_domain::Symbol
    radial_fourier_basis::Symbol
    vertical_fourier_basis::Symbol
    mode_index_mapping::Symbol
    radial_profile_basis::Symbol
    coordinate_orientation::Symbol
    coefficient_length_unit::Symbol
    geometric_compatibility_proved::Bool
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function DESCGeometryCompatibilityV4(
            token::_DFBRCPrivateToken, fields...)
        token === _DFBRC_TOKEN ||
            throw(ArgumentError("private DESC compatibility constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCGeometryCompatibilityV4) = merge(
    _dfbrc_compatibility_body(x.declaration_id,
        x.physical_declaration_hash, x.support_mapping_declaration_hash,
        x.physical_support_ref, x.chart_ref),
    (declaration_hash=x.declaration_hash,))

function canonical_hash(x::DESCGeometryCompatibilityV4)
    expected = canonical_hash(_dfbrc_compatibility_body(x.declaration_id,
        x.physical_declaration_hash, x.support_mapping_declaration_hash,
        x.physical_support_ref, x.chart_ref))
    expected == x.declaration_hash ||
        throw(ArgumentError("DESC convention declaration hash mismatch"))
    _dfbrc_text(x.declaration_id, "declaration_id") == x.declaration_id ||
        throw(ArgumentError("DESC convention declaration ID is not canonical"))
    x.coordinate_order == _DFBRC_COORDINATE_ORDER &&
        x.radial_domain === _DFBRC_RADIAL_DOMAIN &&
        x.toroidal_domain === _DFBRC_TOROIDAL_DOMAIN &&
        x.radial_fourier_basis === _DFBRC_R_BASIS &&
        x.vertical_fourier_basis === _DFBRC_Z_BASIS &&
        x.mode_index_mapping === _DFBRC_MODE_MAPPING &&
        x.radial_profile_basis === _DFBRC_PROFILE_BASIS &&
        x.coordinate_orientation === _DFBRC_ORIENTATION &&
        x.coefficient_length_unit === :metre &&
        !x.geometric_compatibility_proved &&
        x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_execution_attempted &&
        !x.solver_executed && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC convention declaration exceeded its contract"))
    expected
end

function declare_desc_geometry_convention(
        physical::ThreeDPhysicalProviderInputV4,
        support_mapping::ThreeDPhysicalRegionSupportMappingV4;
        declaration_id::String)
    canonical_hash(physical)
    canonical_hash(support_mapping)
    support_mapping.physical_declaration_hash == canonical_hash(physical) &&
        support_mapping.physical_support_ref ==
            physical.coordinate_metric.support_ref ||
        throw(ArgumentError("DESC compatibility names a foreign physical support"))
    id = _dfbrc_text(declaration_id, "declaration_id")
    body = _dfbrc_compatibility_body(id, canonical_hash(physical),
        canonical_hash(support_mapping), support_mapping.physical_support_ref,
        physical.coordinate_metric.chart_ref)
    DESCGeometryCompatibilityV4(_DFBRC_TOKEN, body.declaration_id,
        body.physical_declaration_hash,
        body.support_mapping_declaration_hash, body.physical_support_ref,
        body.chart_ref, body.coordinate_order, body.radial_domain,
        body.toroidal_domain,
        body.radial_fourier_basis, body.vertical_fourier_basis,
        body.mode_index_mapping, body.radial_profile_basis,
        body.coordinate_orientation, body.coefficient_length_unit,
        body.geometric_compatibility_proved, body.model_class,
        body.claim_ceiling, body.provider_selected, body.provider_executed,
        body.solver_execution_attempted, body.solver_executed,
        body.physical_validation, body.engineering_validation,
        body.emits_evidence, body.grants_pass,
        body.promotion_authority, body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

@enum DESCFixedBoundaryOptimizerV4 desc_lsq_exact

function _dfbrc_declaration_body(declaration_id, compatibility_hash,
        spectral_l, spectral_m, spectral_n, grid_l, grid_m, grid_n,
        optimizer, max_iterations, ftol, xtol, gtol, pressure_step,
        boundary_step, shaping_first, force_limit, fixed_limit, min_sqrt_g)
    (revision=_DFBRC_REVISION,
     declaration_kind=:desc_fixed_boundary_request_controls,
     declaration_id=declaration_id,
     compatibility_declaration_hash=compatibility_hash,
     spectral_l=spectral_l, spectral_m=spectral_m, spectral_n=spectral_n,
     grid_l=grid_l, grid_m=grid_m, grid_n=grid_n,
     optimizer=optimizer, max_iterations=max_iterations,
     ftol=ftol, xtol=xtol, gtol=gtol,
     pressure_step=pressure_step, boundary_step=boundary_step,
     shaping_first=shaping_first,
     max_force_normalized_magnetic=force_limit,
     max_fixed_constraint_error=fixed_limit, min_sqrt_g=min_sqrt_g,
     generic_control_translation=:none,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

"""DESC-only spectral, continuation, solver, and audit controls."""
struct DESCFixedBoundaryRequestDeclarationV4
    declaration_id::String
    compatibility_declaration_hash::Digest256
    spectral_l::Int
    spectral_m::Int
    spectral_n::Int
    grid_l::Int
    grid_m::Int
    grid_n::Int
    optimizer::DESCFixedBoundaryOptimizerV4
    max_iterations::Int
    ftol::Float64
    xtol::Float64
    gtol::Float64
    pressure_step::Float64
    boundary_step::Float64
    shaping_first::Bool
    max_force_normalized_magnetic::Float64
    max_fixed_constraint_error::Float64
    min_sqrt_g::Float64
    generic_control_translation::Symbol
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function DESCFixedBoundaryRequestDeclarationV4(
            token::_DFBRCPrivateToken, fields...)
        token === _DFBRC_TOKEN ||
            throw(ArgumentError("private DESC request declaration constructor"))
        new(fields...)
    end
end

function DESCFixedBoundaryRequestDeclarationV4(declaration_id,
        compatibility::DESCGeometryCompatibilityV4;
        L, M, N, L_grid, M_grid, N_grid,
        optimizer::DESCFixedBoundaryOptimizerV4=desc_lsq_exact,
        max_iterations, ftol, xtol, gtol, pressure_step, boundary_step,
        shaping_first,
        max_force_normalized_magnetic, max_fixed_constraint_error,
        min_sqrt_g)
    canonical_hash(compatibility)
    typeof(shaping_first) === Bool ||
        throw(ArgumentError("shaping_first must be Bool"))
    spectral_l = _dfbrc_int(L, "L"; minimum=2, maximum=12)
    spectral_m = _dfbrc_int(M, "M"; minimum=2, maximum=12)
    spectral_n = _dfbrc_int(N, "N"; minimum=1, maximum=12)
    gl = _dfbrc_int(L_grid, "L_grid"; minimum=spectral_l, maximum=24)
    gm = _dfbrc_int(M_grid, "M_grid"; minimum=spectral_m, maximum=24)
    gn = _dfbrc_int(N_grid, "N_grid"; minimum=spectral_n, maximum=24)
    iterations = _dfbrc_int(max_iterations, "max_iterations";
        minimum=1, maximum=200)
    f = _dfbrc_finite_range(ftol, "ftol", 1.0e-12, 1.0e-3)
    x = _dfbrc_finite_range(xtol, "xtol", 1.0e-12, 1.0e-3)
    g = _dfbrc_finite_range(gtol, "gtol", 1.0e-12, 1.0e-3)
    ps = _dfbrc_finite_range(pressure_step, "pressure_step", 0.05, 1.0)
    bs = _dfbrc_finite_range(boundary_step, "boundary_step", 0.05, 1.0)
    force = _dfbrc_finite_range(max_force_normalized_magnetic,
        "max_force_normalized_magnetic", 1.0e-5, 0.1)
    fixed = _dfbrc_finite_range(max_fixed_constraint_error,
        "max_fixed_constraint_error", 1.0e-15, 1.0e-8)
    jacobian = _dfbrc_finite_range(min_sqrt_g, "min_sqrt_g", 0.0, 1.0)
    id = _dfbrc_text(declaration_id, "declaration_id")
    body = _dfbrc_declaration_body(id, canonical_hash(compatibility),
        spectral_l, spectral_m, spectral_n, gl, gm, gn, optimizer,
        iterations, f, x, g, ps, bs, shaping_first, force, fixed, jacobian)
    DESCFixedBoundaryRequestDeclarationV4(_DFBRC_TOKEN,
        body.declaration_id, body.compatibility_declaration_hash,
        body.spectral_l, body.spectral_m, body.spectral_n,
        body.grid_l, body.grid_m, body.grid_n, body.optimizer,
        body.max_iterations, body.ftol, body.xtol, body.gtol,
        body.pressure_step, body.boundary_step, body.shaping_first,
        body.max_force_normalized_magnetic,
        body.max_fixed_constraint_error, body.min_sqrt_g,
        body.generic_control_translation, body.model_class,
        body.claim_ceiling, body.provider_selected, body.provider_executed,
        body.solver_execution_attempted, body.solver_executed,
        body.physical_validation, body.engineering_validation,
        body.emits_evidence, body.grants_pass,
        body.promotion_authority, body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

semantic_view(x::DESCFixedBoundaryRequestDeclarationV4) = merge(
    _dfbrc_declaration_body(x.declaration_id,
        x.compatibility_declaration_hash, x.spectral_l, x.spectral_m,
        x.spectral_n, x.grid_l, x.grid_m, x.grid_n, x.optimizer,
        x.max_iterations, x.ftol, x.xtol, x.gtol, x.pressure_step,
        x.boundary_step, x.shaping_first,
        x.max_force_normalized_magnetic, x.max_fixed_constraint_error,
        x.min_sqrt_g), (declaration_hash=x.declaration_hash,))

function canonical_hash(x::DESCFixedBoundaryRequestDeclarationV4)
    expected = canonical_hash(_dfbrc_declaration_body(x.declaration_id,
        x.compatibility_declaration_hash, x.spectral_l, x.spectral_m,
        x.spectral_n, x.grid_l, x.grid_m, x.grid_n, x.optimizer,
        x.max_iterations, x.ftol, x.xtol, x.gtol, x.pressure_step,
        x.boundary_step, x.shaping_first,
        x.max_force_normalized_magnetic, x.max_fixed_constraint_error,
        x.min_sqrt_g))
    expected == x.declaration_hash ||
        throw(ArgumentError("DESC request declaration hash mismatch"))
    _dfbrc_text(x.declaration_id, "declaration_id") == x.declaration_id ||
        throw(ArgumentError("DESC request declaration ID is not canonical"))
    _dfbrc_int(x.spectral_l, "L"; minimum=2, maximum=12)
    _dfbrc_int(x.spectral_m, "M"; minimum=2, maximum=12)
    _dfbrc_int(x.spectral_n, "N"; minimum=1, maximum=12)
    _dfbrc_int(x.grid_l, "L_grid"; minimum=x.spectral_l, maximum=24)
    _dfbrc_int(x.grid_m, "M_grid"; minimum=x.spectral_m, maximum=24)
    _dfbrc_int(x.grid_n, "N_grid"; minimum=x.spectral_n, maximum=24)
    _dfbrc_int(x.max_iterations, "max_iterations"; minimum=1, maximum=200)
    _dfbrc_finite_range(x.ftol, "ftol", 1.0e-12, 1.0e-3)
    _dfbrc_finite_range(x.xtol, "xtol", 1.0e-12, 1.0e-3)
    _dfbrc_finite_range(x.gtol, "gtol", 1.0e-12, 1.0e-3)
    _dfbrc_finite_range(x.pressure_step, "pressure_step", 0.05, 1.0)
    _dfbrc_finite_range(x.boundary_step, "boundary_step", 0.05, 1.0)
    _dfbrc_finite_range(x.max_force_normalized_magnetic,
        "max_force_normalized_magnetic", 1.0e-5, 0.1)
    _dfbrc_finite_range(x.max_fixed_constraint_error,
        "max_fixed_constraint_error", 1.0e-15, 1.0e-8)
    _dfbrc_finite_range(x.min_sqrt_g, "min_sqrt_g", 0.0, 1.0)
    typeof(x.shaping_first) === Bool ||
        throw(ArgumentError("shaping_first must be Bool"))
    x.optimizer === desc_lsq_exact &&
        x.generic_control_translation === :none &&
        x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_execution_attempted &&
        !x.solver_executed && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC request declaration exceeded its contract"))
    expected
end

function _dfbrc_binding_body(declaration_hash, compatibility_hash,
        candidate_hash, prefix_hash, genome_hash, graph_hash,
        graph_binding_hash, composition_binding_hash, physical_hash,
        physical_binding_hash, support_mapping_hash,
        support_mapping_binding_hash, region_law_hash,
        region_law_binding_hash, oriented_hash, oriented_binding_hash,
        residual_hash, residual_binding_hash, discretization_hash,
        discretization_binding_hash, mission_hash, bounds_hash, scenario_hash)
    (revision=_DFBRC_REVISION,
     binding_kind=:desc_fixed_boundary_request_subject_binding,
     declaration_hash=declaration_hash,
     compatibility_declaration_hash=compatibility_hash,
     candidate_hash=candidate_hash, compiled_prefix_hash=prefix_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     composition_binding_hash=composition_binding_hash,
     physical_declaration_hash=physical_hash,
     physical_binding_hash=physical_binding_hash,
     support_mapping_declaration_hash=support_mapping_hash,
     support_mapping_binding_hash=support_mapping_binding_hash,
     region_law_set_declaration_hash=region_law_hash,
     region_law_set_binding_hash=region_law_binding_hash,
     oriented_declaration_hash=oriented_hash,
     oriented_binding_hash=oriented_binding_hash,
     residual_declaration_hash=residual_hash,
     residual_binding_hash=residual_binding_hash,
     discretization_declaration_hash=discretization_hash,
     discretization_binding_hash=discretization_binding_hash,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash, geometric_compatibility_proved=false,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct DESCFixedBoundaryRequestBindingV4
    declaration_hash::Digest256
    compatibility_declaration_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    composition_binding_hash::Digest256
    physical_declaration_hash::Digest256
    physical_binding_hash::Digest256
    support_mapping_declaration_hash::Digest256
    support_mapping_binding_hash::Digest256
    region_law_set_declaration_hash::Digest256
    region_law_set_binding_hash::Digest256
    oriented_declaration_hash::Digest256
    oriented_binding_hash::Digest256
    residual_declaration_hash::Digest256
    residual_binding_hash::Digest256
    discretization_declaration_hash::Digest256
    discretization_binding_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    geometric_compatibility_proved::Bool
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    binding_hash::Digest256
    function DESCFixedBoundaryRequestBindingV4(
            token::_DFBRCPrivateToken, fields...)
        token === _DFBRC_TOKEN ||
            throw(ArgumentError("private DESC request binding constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCFixedBoundaryRequestBindingV4) = merge(
    _dfbrc_binding_body(x.declaration_hash,
        x.compatibility_declaration_hash, x.candidate_hash,
        x.compiled_prefix_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.composition_binding_hash, x.physical_declaration_hash,
        x.physical_binding_hash, x.support_mapping_declaration_hash,
        x.support_mapping_binding_hash, x.region_law_set_declaration_hash,
        x.region_law_set_binding_hash, x.oriented_declaration_hash,
        x.oriented_binding_hash, x.residual_declaration_hash,
        x.residual_binding_hash, x.discretization_declaration_hash,
        x.discretization_binding_hash, x.mission_hash, x.bounds_hash,
        x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::DESCFixedBoundaryRequestBindingV4)
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.binding_hash ||
        throw(ArgumentError("DESC request subject binding hash mismatch"))
    !x.geometric_compatibility_proved &&
        x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_execution_attempted &&
        !x.solver_executed && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC request binding exceeded authority ceiling"))
    expected
end

function _dfbrc_owned(candidate::CandidateStatePackageV4, value, T, label)
    matches = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === T && canonical_hash(x) == canonical_hash(value))
    length(matches) == 1 && semantic_view(only(matches)) == semantic_view(value) ||
        throw(ArgumentError("$label is absent from or ambiguous in current G2"))
    value
end

function _dfbrc_unique_candidate_field(candidate::CandidateStatePackageV4,
        T, label::String)
    values = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === T)
    length(values) == 1 ||
        throw(ArgumentError("current G2 must contain exactly one $label"))
    only(values)
end

function make_desc_fixed_boundary_request_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        composition_binding::ThreeDPhysicalInputCompositionBindingV4,
        physical_binding::ThreeDPhysicalProviderInputBindingV4,
        support_mapping_binding::ThreeDPhysicalRegionSupportMappingBindingV4,
        region_law_binding::ThreeDRegionLawSetBindingV4,
        oriented_binding::ThreeDOrientedInterfaceBindingV4,
        residual_binding::ThreeDGoverningResidualJacobianBindingV4,
        discretization_binding::ThreeDDiscretizationControlBindingV4,
        compatibility::DESCGeometryCompatibilityV4,
        declaration::DESCFixedBoundaryRequestDeclarationV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) &&
        _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("DESC request scenario is outside frozen scope"))
    canonical_hash(composition_binding)
    _dfbrc_owned(compiled.candidate, compatibility,
        DESCGeometryCompatibilityV4, "DESC geometry convention declaration")
    _dfbrc_owned(compiled.candidate, declaration,
        DESCFixedBoundaryRequestDeclarationV4, "DESC request declaration")
    declaration.compatibility_declaration_hash == canonical_hash(compatibility) ||
        throw(ArgumentError("DESC request names a foreign convention declaration"))
    compatibility.physical_declaration_hash ==
            composition_binding.physical_declaration_hash &&
        compatibility.support_mapping_declaration_hash ==
            composition_binding.support_mapping_declaration_hash ||
        throw(ArgumentError("DESC convention differs from composition binding"))
    candidate = compiled.candidate
    physical = _dfbrc_unique_candidate_field(candidate,
        ThreeDPhysicalProviderInputV4, "3-D physical declaration")
    support_mapping = _dfbrc_unique_candidate_field(candidate,
        ThreeDPhysicalRegionSupportMappingV4, "physical support mapping")
    region_laws = _dfbrc_unique_candidate_field(candidate,
        ThreeDRegionLawSetDeclarationV4, "region-law set")
    oriented = _dfbrc_unique_candidate_field(candidate,
        ThreeDOrientedInterfaceDeclarationSetV4, "oriented-interface declaration")
    residual = _dfbrc_unique_candidate_field(candidate,
        ThreeDGoverningResidualJacobianDeclarationSetV4,
        "residual/Jacobian declaration")
    discretization = _dfbrc_unique_candidate_field(candidate,
        ThreeDDiscretizationControlDeclarationV4,
        "discretization declaration")
    rebuilt_composition = make_three_d_physical_input_composition_binding(
        compiled, registry, mission_payload, bounds_payload, comparison,
        scenarios, scenario, physical, support_mapping, region_laws,
        oriented, residual, discretization, physical_binding,
        support_mapping_binding, region_law_binding, oriented_binding,
        residual_binding, discretization_binding)
    canonical_hash(composition_binding) == canonical_hash(rebuilt_composition) &&
        semantic_view(composition_binding) == semantic_view(rebuilt_composition) ||
        throw(ArgumentError("DESC request received a foreign composition binding"))
    graph = _make_forward_graph_binding(:field_geometry,
        compiled.field_geometry_graph)
    body = _dfbrc_binding_body(canonical_hash(declaration),
        canonical_hash(compatibility),
        _forward_candidate_identity(compiled.candidate), compiled.prefix_hash,
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        graph.canonical_graph_hash, canonical_hash(graph),
        canonical_hash(composition_binding),
        composition_binding.physical_declaration_hash,
        composition_binding.physical_binding_hash,
        composition_binding.support_mapping_declaration_hash,
        composition_binding.support_mapping_binding_hash,
        composition_binding.region_law_set_declaration_hash,
        composition_binding.region_law_set_binding_hash,
        composition_binding.oriented_declaration_hash,
        composition_binding.oriented_binding_hash,
        composition_binding.residual_declaration_hash,
        composition_binding.residual_binding_hash,
        composition_binding.discretization_declaration_hash,
        composition_binding.discretization_binding_hash,
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        canonical_hash(scenario))
    DESCFixedBoundaryRequestBindingV4(_DFBRC_TOKEN,
        body.declaration_hash, body.compatibility_declaration_hash,
        body.candidate_hash, body.compiled_prefix_hash,
        body.field_geometry_genome_hash, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash,
        body.composition_binding_hash, body.physical_declaration_hash,
        body.physical_binding_hash,
        body.support_mapping_declaration_hash,
        body.support_mapping_binding_hash,
        body.region_law_set_declaration_hash,
        body.region_law_set_binding_hash, body.oriented_declaration_hash,
        body.oriented_binding_hash, body.residual_declaration_hash,
        body.residual_binding_hash, body.discretization_declaration_hash,
        body.discretization_binding_hash, body.mission_hash,
        body.bounds_hash, body.scenario_hash,
        body.geometric_compatibility_proved, body.model_class,
        body.claim_ceiling, body.provider_selected, body.provider_executed,
        body.solver_execution_attempted, body.solver_executed,
        body.physical_validation, body.engineering_validation,
        body.emits_evidence, body.grants_pass, body.promotion_authority,
        body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

_dfbrc_sign0(value::Int) = value < 0 ? -1 : 1

function _dfbrc_boundary_reasons(boundary::ThreeDFourierBoundaryV4,
        declaration::DESCFixedBoundaryRequestDeclarationV4)
    reasons = String[]
    !(2 <= boundary.field_periods <= 8) &&
        push!(reasons, "desc_field_periods_outside_2_8")
    !boundary.stellarator_symmetric &&
        push!(reasons, "desc_requires_stellarator_symmetric_boundary")
    radial = boundary.radial_coefficients
    vertical = boundary.vertical_coefficients
    !(1 <= length(radial) <= 30) &&
        push!(reasons, "desc_radial_mode_count_outside_1_30")
    !(1 <= length(vertical) <= 30) &&
        push!(reasons, "desc_vertical_mode_count_outside_1_30")
    any(x -> abs(x.poloidal_mode) > 6 || abs(x.toroidal_mode) > 6,
        (radial..., vertical...)) &&
        push!(reasons, "desc_boundary_mode_outside_abs_6")
    any(x -> _dfbrc_sign0(x.poloidal_mode) !=
             _dfbrc_sign0(x.toroidal_mode), radial) &&
        push!(reasons, "desc_radial_mode_would_be_truncated_by_symmetry")
    any(x -> _dfbrc_sign0(x.poloidal_mode) ==
             _dfbrc_sign0(x.toroidal_mode), vertical) &&
        push!(reasons, "desc_vertical_mode_would_be_truncated_by_symmetry")
    r00 = Tuple(x.coefficient_m for x in radial
        if x.poloidal_mode == 0 && x.toroidal_mode == 0)
    if length(r00) != 1 || only(r00) <= 0
        push!(reasons, "desc_requires_one_positive_major_radius_mode")
    else
        nonaxis = sum(abs(x.coefficient_m) for x in radial
            if !(x.poloidal_mode == 0 && x.toroidal_mode == 0))
        only(r00) > 2.0 * nonaxis ||
            push!(reasons, "desc_major_radius_dominance_not_satisfied")
    end
    if length(r00) == 1
        function coefficient(values, m, n)
            matches = Tuple(x.coefficient_m for x in values
                if x.poloidal_mode == m && x.toroidal_mode == n)
            isempty(matches) ? 0.0 : only(matches)
        end
        r0 = only(r00)
        rsin = coefficient(radial, -1, 0)
        rcos = coefficient(radial, 1, 0)
        zsin = coefficient(vertical, -1, 0)
        zcos = coefficient(vertical, 1, 0)
        orientation_measure = (r0 + rcos) * (rsin * zcos - rcos * zsin)
        orientation_measure > 0 ||
            push!(reasons, "desc_boundary_not_strictly_right_handed")
    end
    max_m = maximum(abs(x.poloidal_mode) for x in (radial..., vertical...))
    max_n = maximum(abs(x.toroidal_mode) for x in (radial..., vertical...))
    declaration.spectral_m >= max_m ||
        push!(reasons, "desc_spectral_m_below_boundary_mode")
    declaration.spectral_n >= max_n ||
        push!(reasons, "desc_spectral_n_below_boundary_mode")
    Tuple(unique(reasons))
end

_dfbrc_polynomial(coefficients, rho) = sum(
    coefficient * rho^(power - 1)
    for (power, coefficient) in enumerate(coefficients))

function _dfbrc_profile_reasons(profiles::ThreeDProfilesFluxV4)
    reasons = String[]
    pressure = profiles.pressure.coefficients
    rotational = profiles.rotational_or_current
    !(1 <= length(pressure) <= 13) &&
        push!(reasons, "desc_pressure_series_length_outside_1_13")
    rotational.quantity === :iota ||
        push!(reasons, "desc_requires_iota_profile_not_current")
    !(1 <= length(rotational.coefficients) <= 13) &&
        push!(reasons, "desc_iota_series_length_outside_1_13")
    1.0e-4 <= profiles.toroidal_flux_wb <= 100.0 ||
        push!(reasons, "desc_toroidal_flux_outside_1e_4_100_wb")
    if 1 <= length(pressure) <= 13
        samples = Tuple(_dfbrc_polynomial(pressure, index / 20.0)
            for index in 0:20)
        peak = maximum(samples)
        peak > 0 || push!(reasons, "desc_pressure_profile_not_positive")
        peak > 0 && minimum(samples) < -1.0e-9 * peak &&
            push!(reasons, "desc_pressure_profile_negative_on_audited_grid")
        peak > 0 && abs(last(samples)) > 1.0e-8 * peak &&
            push!(reasons, "desc_pressure_profile_not_closed_at_rho_1")
    end
    if rotational.quantity === :iota &&
            1 <= length(rotational.coefficients) <= 13
        samples = Tuple(_dfbrc_polynomial(rotational.coefficients,
            index / 20.0) for index in 0:20)
        (maximum(abs, samples) <= 3.0 && minimum(abs, samples) >= 0.02) ||
            push!(reasons, "desc_iota_profile_outside_abs_0_02_3")
    end
    Tuple(unique(reasons))
end

function _dfbrc_unsupported_reasons(
        composition::ThreeDPhysicalInputCompositionV4,
        compatibility::DESCGeometryCompatibilityV4,
        declaration::DESCFixedBoundaryRequestDeclarationV4)
    physical = composition.physical
    reasons = String[]
    compatibility.physical_declaration_hash == canonical_hash(physical) ||
        push!(reasons, "desc_compatibility_physical_hash_mismatch")
    compatibility.support_mapping_declaration_hash ==
        canonical_hash(composition.support_mapping) ||
        push!(reasons, "desc_compatibility_support_mapping_hash_mismatch")
    compatibility.physical_support_ref ==
        physical.coordinate_metric.support_ref ||
        push!(reasons, "desc_compatibility_support_ref_mismatch")
    compatibility.chart_ref == physical.coordinate_metric.chart_ref ||
        push!(reasons, "desc_compatibility_chart_ref_mismatch")
    append!(reasons, _dfbrc_boundary_reasons(
        physical.fourier_boundary, declaration))
    append!(reasons, _dfbrc_profile_reasons(physical.profiles_flux))
    Tuple(unique(reasons))
end

function _dfbrc_mode_payload(values)
    Tuple((m=x.poloidal_mode, n=x.toroidal_mode,
           coefficient_m=x.coefficient_m) for x in values)
end

function _dfbrc_runner_payload(composition::ThreeDPhysicalInputCompositionV4,
        declaration::DESCFixedBoundaryRequestDeclarationV4)
    physical = composition.physical
    boundary = physical.fourier_boundary
    profiles = physical.profiles_flux
    (runner_version=_DFBRC_RUNNER_VERSION,
     model_id=_DFBRC_MODEL_ID,
     source_binding=_DFBRC_SOURCE_BINDING,
     boundary=(field_periods=boundary.field_periods,
        stellarator_symmetric=boundary.stellarator_symmetric,
        R_modes=_dfbrc_mode_payload(boundary.radial_coefficients),
        Z_modes=_dfbrc_mode_payload(boundary.vertical_coefficients)),
     profiles=(pressure_power_series_pa=profiles.pressure.coefficients,
        iota_power_series=profiles.rotational_or_current.coefficients,
        toroidal_flux_wb=profiles.toroidal_flux_wb),
     resolution=(L=declaration.spectral_l, M=declaration.spectral_m,
        N=declaration.spectral_n, L_grid=declaration.grid_l,
        M_grid=declaration.grid_m, N_grid=declaration.grid_n),
     solver=(optimizer="lsq-exact",
        max_iterations=declaration.max_iterations,
        ftol=declaration.ftol, xtol=declaration.xtol, gtol=declaration.gtol,
        pressure_step=declaration.pressure_step,
        boundary_step=declaration.boundary_step,
        shaping_first=declaration.shaping_first),
     audit=(max_force_normalized_magnetic=
            declaration.max_force_normalized_magnetic,
        max_fixed_constraint_error=declaration.max_fixed_constraint_error,
        min_sqrt_g=declaration.min_sqrt_g))
end

function _dfbrc_request_body(context, composition, compatibility,
        declaration, binding, payload)
    (revision=_DFBRC_REVISION, schema=_DFBRC_SCHEMA,
     capability=:desc_fixed_boundary_ideal_mhd_equilibrium,
     context_hash=context.context_hash, candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     composition_input_hash=canonical_hash(composition),
     composition_binding_hash=composition.composition_binding_hash,
     compatibility_declaration_hash=canonical_hash(compatibility),
     request_declaration_hash=canonical_hash(declaration),
      request_binding_hash=canonical_hash(binding),
      generic_discretization_input_hash=canonical_hash(composition.discretization),
      generic_control_translation=:none, runner_payload=payload,
      geometric_compatibility_proved=false,
      model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct DESCFixedBoundaryExecutionRequestV4
    capability::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    physical_subject_hash::Digest256
    composition_input_hash::Digest256
    composition_binding_hash::Digest256
    compatibility_declaration_hash::Digest256
    request_declaration_hash::Digest256
    request_binding_hash::Digest256
    generic_discretization_input_hash::Digest256
    generic_control_translation::Symbol
    runner_payload::NamedTuple
    geometric_compatibility_proved::Bool
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    request_hash::Digest256
    function DESCFixedBoundaryExecutionRequestV4(
            token::_DFBRCPrivateToken, fields...)
        token === _DFBRC_TOKEN ||
            throw(ArgumentError("private DESC execution request constructor"))
        new(fields...)
    end
end

function semantic_view(x::DESCFixedBoundaryExecutionRequestV4)
    (revision=_DFBRC_REVISION, schema=_DFBRC_SCHEMA,
     capability=x.capability, context_hash=x.context_hash,
     candidate_hash=x.candidate_hash,
     compiled_prefix_hash=x.compiled_prefix_hash,
     registry_hash=x.registry_hash,
     physical_subject_hash=x.physical_subject_hash,
     composition_input_hash=x.composition_input_hash,
     composition_binding_hash=x.composition_binding_hash,
     compatibility_declaration_hash=x.compatibility_declaration_hash,
     request_declaration_hash=x.request_declaration_hash,
     request_binding_hash=x.request_binding_hash,
      generic_discretization_input_hash=x.generic_discretization_input_hash,
      generic_control_translation=x.generic_control_translation,
      runner_payload=x.runner_payload,
      geometric_compatibility_proved=x.geometric_compatibility_proved,
      model_class=x.model_class,
     claim_ceiling=x.claim_ceiling, provider_selected=x.provider_selected,
     provider_executed=x.provider_executed,
     solver_execution_attempted=x.solver_execution_attempted,
     solver_executed=x.solver_executed,
     physical_validation=x.physical_validation,
     engineering_validation=x.engineering_validation,
     emits_evidence=x.emits_evidence,
     grants_pass=x.grants_pass,
     promotion_authority=x.promotion_authority, p5_ready=x.p5_ready,
     terminal_authority=x.terminal_authority,
     credible_physical_device_count=x.credible_physical_device_count,
     request_hash=x.request_hash)
end

function _dfbrc_payload_modes(items, label::String)
    items isa Tuple && !(items isa NamedTuple) && 1 <= length(items) <= 30 ||
        throw(ArgumentError("$label must contain 1..30 immutable modes"))
    modes = Tuple(begin
        item isa NamedTuple && keys(item) == (:m, :n, :coefficient_m) ||
            throw(ArgumentError("$label mode fields are not exact"))
        m = _dfbrc_int(item.m, "$label.m"; minimum=-6, maximum=6)
        n = _dfbrc_int(item.n, "$label.n"; minimum=-6, maximum=6)
        coefficient = _dfbrc_finite(item.coefficient_m,
            "$label.coefficient_m")
        (m=m, n=n, coefficient_m=coefficient)
    end for item in items)
    mode_keys = Tuple((x.m, x.n) for x in modes)
    length(unique(mode_keys)) == length(mode_keys) ||
        throw(ArgumentError("$label contains duplicate modes"))
    modes
end

function _dfbrc_payload_profile(values, label::String)
    values isa Tuple && !(values isa NamedTuple) && 1 <= length(values) <= 13 ||
        throw(ArgumentError("$label must contain 1..13 immutable coefficients"))
    Tuple(_dfbrc_finite(value, label) for value in values)
end

function _dfbrc_validate_runner_payload(payload::NamedTuple)
    keys(payload) ==
        (:runner_version, :model_id, :source_binding, :boundary, :profiles,
         :resolution, :solver, :audit) ||
        throw(ArgumentError("DESC runner payload fields are not exact"))
    payload.runner_version == _DFBRC_RUNNER_VERSION &&
        payload.model_id == _DFBRC_MODEL_ID &&
        payload.source_binding == _DFBRC_SOURCE_BINDING ||
        throw(ArgumentError("DESC runner identity is not compiler pinned"))
    keys(payload.boundary) ==
        (:field_periods, :stellarator_symmetric, :R_modes, :Z_modes) &&
        keys(payload.profiles) ==
        (:pressure_power_series_pa, :iota_power_series, :toroidal_flux_wb) &&
        keys(payload.resolution) ==
        (:L, :M, :N, :L_grid, :M_grid, :N_grid) &&
        keys(payload.solver) ==
        (:optimizer, :max_iterations, :ftol, :xtol, :gtol,
         :pressure_step, :boundary_step, :shaping_first) &&
        keys(payload.audit) ==
        (:max_force_normalized_magnetic, :max_fixed_constraint_error,
         :min_sqrt_g) ||
        throw(ArgumentError("DESC nested runner payload fields are not exact"))
    payload.boundary.stellarator_symmetric === true &&
        payload.solver.optimizer == "lsq-exact" &&
        typeof(payload.solver.shaping_first) === Bool ||
        throw(ArgumentError("DESC runner payload fixed semantics changed"))
    all(values -> values isa Tuple && !(values isa NamedTuple),
        (payload.boundary.R_modes, payload.boundary.Z_modes,
         payload.profiles.pressure_power_series_pa,
         payload.profiles.iota_power_series)) ||
        throw(ArgumentError("DESC runner arrays must be immutable tuples"))
    all(mode -> mode isa NamedTuple && keys(mode) == (:m, :n, :coefficient_m),
        (payload.boundary.R_modes..., payload.boundary.Z_modes...)) ||
        throw(ArgumentError("DESC Fourier mode fields are not exact"))
    nfp = _dfbrc_int(payload.boundary.field_periods, "field_periods";
        minimum=2, maximum=8)
    nfp == payload.boundary.field_periods ||
        throw(ArgumentError("field_periods is not canonical"))
    radial = _dfbrc_payload_modes(payload.boundary.R_modes, "R_modes")
    vertical = _dfbrc_payload_modes(payload.boundary.Z_modes, "Z_modes")
    all(x -> _dfbrc_sign0(x.m) == _dfbrc_sign0(x.n), radial) ||
        throw(ArgumentError("R mode would be truncated by DESC symmetry"))
    all(x -> _dfbrc_sign0(x.m) != _dfbrc_sign0(x.n), vertical) ||
        throw(ArgumentError("Z mode would be truncated by DESC symmetry"))
    r00 = Tuple(x.coefficient_m for x in radial if x.m == 0 && x.n == 0)
    length(r00) == 1 && only(r00) > 0 ||
        throw(ArgumentError("DESC payload requires one positive R(0,0)"))
    only(r00) > 2.0 * sum(abs(x.coefficient_m) for x in radial
        if !(x.m == 0 && x.n == 0)) ||
        throw(ArgumentError("DESC payload fails major-radius dominance"))
    coefficient(values, m, n) = begin
        matches = Tuple(x.coefficient_m for x in values
            if x.m == m && x.n == n)
        isempty(matches) ? 0.0 : only(matches)
    end
    rcos = coefficient(radial, 1, 0)
    rsin = coefficient(radial, -1, 0)
    zcos = coefficient(vertical, 1, 0)
    zsin = coefficient(vertical, -1, 0)
    (only(r00) + rcos) * (rsin * zcos - rcos * zsin) > 0 ||
        throw(ArgumentError("DESC payload boundary is not strictly right handed"))

    resolution = payload.resolution
    spectral_l = _dfbrc_int(resolution.L, "L"; minimum=2, maximum=12)
    spectral_m = _dfbrc_int(resolution.M, "M"; minimum=2, maximum=12)
    spectral_n = _dfbrc_int(resolution.N, "N"; minimum=1, maximum=12)
    _dfbrc_int(resolution.L_grid, "L_grid";
        minimum=spectral_l, maximum=24)
    _dfbrc_int(resolution.M_grid, "M_grid";
        minimum=spectral_m, maximum=24)
    _dfbrc_int(resolution.N_grid, "N_grid";
        minimum=spectral_n, maximum=24)
    spectral_m >= maximum(abs(x.m) for x in (radial..., vertical...)) ||
        throw(ArgumentError("DESC payload M is below a boundary mode"))
    spectral_n >= maximum(abs(x.n) for x in (radial..., vertical...)) ||
        throw(ArgumentError("DESC payload N is below a boundary mode"))

    profiles = payload.profiles
    pressure = _dfbrc_payload_profile(profiles.pressure_power_series_pa,
        "pressure_power_series_pa")
    iota = _dfbrc_payload_profile(profiles.iota_power_series,
        "iota_power_series")
    _dfbrc_finite_range(profiles.toroidal_flux_wb, "toroidal_flux_wb",
        1.0e-4, 100.0)
    pressure_samples = Tuple(_dfbrc_polynomial(pressure, index / 20.0)
        for index in 0:20)
    pressure_peak = maximum(pressure_samples)
    pressure_peak > 0 &&
        minimum(pressure_samples) >= -1.0e-9 * pressure_peak &&
        abs(last(pressure_samples)) <= 1.0e-8 * pressure_peak ||
        throw(ArgumentError("DESC payload pressure profile fails audited shape"))
    iota_samples = Tuple(_dfbrc_polynomial(iota, index / 20.0)
        for index in 0:20)
    maximum(abs, iota_samples) <= 3.0 &&
        minimum(abs, iota_samples) >= 0.02 ||
        throw(ArgumentError("DESC payload iota profile fails audited range"))

    solver = payload.solver
    _dfbrc_int(solver.max_iterations, "max_iterations";
        minimum=1, maximum=200)
    _dfbrc_finite_range(solver.ftol, "ftol", 1.0e-12, 1.0e-3)
    _dfbrc_finite_range(solver.xtol, "xtol", 1.0e-12, 1.0e-3)
    _dfbrc_finite_range(solver.gtol, "gtol", 1.0e-12, 1.0e-3)
    _dfbrc_finite_range(solver.pressure_step, "pressure_step", 0.05, 1.0)
    _dfbrc_finite_range(solver.boundary_step, "boundary_step", 0.05, 1.0)
    audit = payload.audit
    _dfbrc_finite_range(audit.max_force_normalized_magnetic,
        "max_force_normalized_magnetic", 1.0e-5, 0.1)
    _dfbrc_finite_range(audit.max_fixed_constraint_error,
        "max_fixed_constraint_error", 1.0e-15, 1.0e-8)
    _dfbrc_finite_range(audit.min_sqrt_g, "min_sqrt_g", 0.0, 1.0)
    payload
end

function canonical_hash(x::DESCFixedBoundaryExecutionRequestV4)
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.request_hash ||
        throw(ArgumentError("DESC execution request hash mismatch"))
    _dfbrc_validate_runner_payload(x.runner_payload)
    x.capability === :desc_fixed_boundary_ideal_mhd_equilibrium &&
        x.generic_control_translation === :none &&
        !x.geometric_compatibility_proved &&
        x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_execution_attempted &&
        !x.solver_executed && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC request exceeded its authority ceiling"))
    throw(ArgumentError(
        "no verified DESC geometry proof contract can validate a request"))
end

"""Return the exact payload projection for a later process adapter."""
function desc_fixed_boundary_runner_payload(
        request::DESCFixedBoundaryExecutionRequestV4)
    canonical_hash(request)
    request.runner_payload
end

function _dfbrc_make_request(context, composition, compatibility,
        declaration, binding)
    canonical_hash(compatibility)
    compatibility.geometric_compatibility_proved ||
        throw(ArgumentError("verified DESC geometric compatibility is required"))
    payload = _dfbrc_runner_payload(composition, declaration)
    body = _dfbrc_request_body(context, composition, compatibility,
        declaration, binding, payload)
    DESCFixedBoundaryExecutionRequestV4(_DFBRC_TOKEN,
        body.capability, body.context_hash, body.candidate_hash,
        body.compiled_prefix_hash, body.registry_hash,
        body.physical_subject_hash, body.composition_input_hash,
        body.composition_binding_hash, body.compatibility_declaration_hash,
        body.request_declaration_hash, body.request_binding_hash,
         body.generic_discretization_input_hash,
         body.generic_control_translation, body.runner_payload,
         body.geometric_compatibility_proved,
         body.model_class, body.claim_ceiling, body.provider_selected,
        body.provider_executed, body.solver_execution_attempted,
        body.solver_executed, body.physical_validation,
        body.engineering_validation, body.emits_evidence,
        body.grants_pass, body.promotion_authority, body.p5_ready,
        body.terminal_authority, body.credible_physical_device_count,
        canonical_hash(body))
end

function _dfbrc_resolution_body(context_hash, status, request, gaps)
    (revision=_DFBRC_REVISION, kind=:desc_fixed_boundary_request_resolution,
      context_hash=context_hash, status=status,
      request_hash=request === nothing ? nothing : canonical_hash(request),
      recoverable_gaps=gaps,
      model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
      provider_selected=false,
     provider_executed=false, solver_execution_attempted=false,
     solver_executed=false, physical_validation=false,
     engineering_validation=false, emits_evidence=false,
     grants_pass=false, promotion_authority=false, p5_ready=false,
     terminal_authority=false, credible_physical_device_count=0)
end

struct DESCFixedBoundaryRequestResolutionV4
    context_hash::Digest256
    status::Symbol
    request::Union{Nothing,DESCFixedBoundaryExecutionRequestV4}
    recoverable_gaps::Tuple{Vararg{String}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    resolution_hash::Digest256
    function DESCFixedBoundaryRequestResolutionV4(
            token::_DFBRCPrivateToken, fields...)
        token === _DFBRC_TOKEN ||
            throw(ArgumentError("private DESC request resolution constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCFixedBoundaryRequestResolutionV4) = merge(
    _dfbrc_resolution_body(x.context_hash, x.status, x.request,
        x.recoverable_gaps),
    (resolution_hash=x.resolution_hash,))

function canonical_hash(x::DESCFixedBoundaryRequestResolutionV4)
    x.status === :recoverable_gap ||
        throw(ArgumentError("invalid DESC request resolution status"))
    x.request === nothing && !isempty(x.recoverable_gaps) ||
        throw(ArgumentError("DESC request resolution payload mismatch"))
    _dfbrc_validate_gap_tuple(x.recoverable_gaps)
    expected = canonical_hash(_dfbrc_resolution_body(x.context_hash,
        x.status, x.request, x.recoverable_gaps))
    expected == x.resolution_hash ||
        throw(ArgumentError("DESC request resolution hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_execution_attempted &&
        !x.solver_executed && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC request resolution exceeded authority ceiling"))
    expected
end

function _dfbrc_resolution(context_hash, status; request=nothing, gaps=())
    gap_tuple = Tuple(gaps)
    _dfbrc_validate_gap_tuple(gap_tuple)
    body = _dfbrc_resolution_body(context_hash, status, request, gap_tuple)
    DESCFixedBoundaryRequestResolutionV4(_DFBRC_TOKEN, context_hash, status,
        request, gap_tuple, :manufactured_input_fixture, screen_only,
        false, false, false,
        false, false, false, false, false, false, false, false,
        0, canonical_hash(body))
end

function _dfbrc_inventory(context::ForwardChainContextV4)
    fields = context.candidate.field_geometry_genome_ref.fields
    bindings = context.subject.bindings
    (compatibility=Tuple(x for x in fields
         if typeof(x) === DESCGeometryCompatibilityV4),
     declarations=Tuple(x for x in fields
         if typeof(x) === DESCFixedBoundaryRequestDeclarationV4),
     bindings=Tuple(x for x in bindings
         if typeof(x) === DESCFixedBoundaryRequestBindingV4),
     composition_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDPhysicalInputCompositionBindingV4),
     physical_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDPhysicalProviderInputBindingV4),
     support_mapping_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDPhysicalRegionSupportMappingBindingV4),
     region_law_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDRegionLawSetBindingV4),
     oriented_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDOrientedInterfaceBindingV4),
     residual_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDGoverningResidualJacobianBindingV4),
     discretization_bindings=Tuple(x for x in bindings
         if typeof(x) === ThreeDDiscretizationControlBindingV4))
end

function _dfbrc_inventory_gaps(inventory)
    gaps = String[]
    isempty(inventory.compatibility) ? push!(gaps, _DFBRC_REQUIRED_GAPS[1]) :
        length(inventory.compatibility) == 1 ||
            push!(gaps, "ambiguous_desc_geometry_convention_declaration")
    isempty(inventory.declarations) ? push!(gaps, _DFBRC_REQUIRED_GAPS[2]) :
        length(inventory.declarations) == 1 ||
            push!(gaps, "ambiguous_desc_fixed_boundary_request_declaration")
    isempty(inventory.bindings) ? push!(gaps, _DFBRC_REQUIRED_GAPS[3]) :
        length(inventory.bindings) == 1 ||
            push!(gaps, "ambiguous_desc_fixed_boundary_request_subject_binding")
    Tuple(gaps)
end

"""Validate the current inputs and return exact closed capability gaps."""
function compile_desc_fixed_boundary_request(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    inventory = _dfbrc_inventory(context)
    length(inventory.bindings) > 1 &&
        throw(ArgumentError("duplicate DESC request bindings are an integrity error"))
    component_binding_groups = (
        inventory.composition_bindings, inventory.physical_bindings,
        inventory.support_mapping_bindings, inventory.region_law_bindings,
        inventory.oriented_bindings, inventory.residual_bindings,
        inventory.discretization_bindings)
    length(inventory.bindings) == 1 &&
        (length(inventory.compatibility) != 1 ||
         length(inventory.declarations) != 1 ||
         any(values -> length(values) != 1, component_binding_groups)) &&
        throw(ArgumentError(
            "orphan DESC binding lacks exact declarations or upstream bindings"))
    composition_resolution = compose_three_d_physical_inputs(context)
    composition_resolution.status === :input_complete ||
        return _dfbrc_resolution(context.context_hash, :recoverable_gap;
            gaps=composition_resolution.recoverable_gaps)
    composition = something(composition_resolution.input)
    gaps = _dfbrc_inventory_gaps(inventory)
    isempty(gaps) || return _dfbrc_resolution(context.context_hash,
        :recoverable_gap; gaps=gaps)
    length(inventory.composition_bindings) == 1 ||
        throw(ArgumentError("DESC request requires one composition binding"))
    compatibility = only(inventory.compatibility)
    declaration = only(inventory.declarations)
    binding = only(inventory.bindings)
    rebuilt = make_desc_fixed_boundary_request_binding(context.compiled,
        context.registry, context.mission_payload, context.bounds_payload,
        context.comparison_scope, context.scenario_scope, context.scenario,
        only(inventory.composition_bindings),
        only(inventory.physical_bindings),
        only(inventory.support_mapping_bindings),
        only(inventory.region_law_bindings), only(inventory.oriented_bindings),
        only(inventory.residual_bindings),
        only(inventory.discretization_bindings), compatibility, declaration)
    canonical_hash(binding) == canonical_hash(rebuilt) &&
        semantic_view(binding) == semantic_view(rebuilt) ||
        throw(ArgumentError("DESC request binding is foreign to current context"))
    unsupported = _dfbrc_unsupported_reasons(composition, compatibility,
        declaration)
    compatibility.geometric_compatibility_proved ||
        (unsupported = (unsupported..., _DFBRC_GEOMETRY_PROOF_GAP))
    _dfbrc_resolution(context.context_hash, :recoverable_gap;
        gaps=Tuple(unique(unsupported)))
end

function validate_desc_fixed_boundary_request(context::ForwardChainContextV4,
        ::DESCFixedBoundaryExecutionRequestV4)
    compile_desc_fixed_boundary_request(context)
    throw(ArgumentError(
        "current compiler has no verified DESC geometry proof contract"))
end

validate_desc_fixed_boundary_request(
    ::DESCFixedBoundaryExecutionRequestV4) = false

desc_fixed_boundary_request_manifest() = (
    schema=_DFBRC_SCHEMA, revision=_DFBRC_REVISION,
    runner_version=_DFBRC_RUNNER_VERSION, model_id=_DFBRC_MODEL_ID,
    source_binding=_DFBRC_SOURCE_BINDING,
    purpose=:candidate_bound_desc_fixed_boundary_request_compiler,
    statuses=(:recoverable_gap,), can_emit_request=false,
    requires_three_d_physical_input_composition=true,
    requires_geometry_convention_declaration=true,
    geometric_compatibility_proved=false,
    pins_fourier_phase_sign_nfp_convention=true,
    pins_profile_basis=true, rejects_silent_mode_truncation=true,
    rejects_silent_orientation_flip=true,
    generic_control_translation=:none,
    model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
    provider_selected=false, provider_executed=false,
    solver_execution_attempted=false, solver_executed=false,
    emits_evidence=false, grants_pass=false,
    physical_validation=false, engineering_validation=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
