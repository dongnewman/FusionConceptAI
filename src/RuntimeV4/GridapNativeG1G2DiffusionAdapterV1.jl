"""Gridap adapter for the native G1/G2 variable-diffusion compilation.

The adapter builds an actual physical-domain Q1 mesh and assembles
`integral(grad(v) dot K(x) grad(u)) = integral(v f)` for the candidate-bound
native form.  Its evidence ceiling is a numerical manufactured screen.
"""

using Gridap
using LinearAlgebra
using SparseArrays
using SHA
using Serialization

const NATIVE_G1G2_GRIDAP_ADAPTER_VERSION_V1 = "v2-q1-region-ownership"
const NATIVE_G1G2_GRIDAP_BACKEND_V1 = "Gridap-native-g1g2"

native_g1g2_gridap_adapter_source_hash_v1() =
    Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

"""Pre-run error budget derived independently from the solver output.

The interpolation values are rounded decimal approximations to square roots
of exact Fraction tensor-Q1 integrals of the declared bubble on the three
frozen grids.  Uniform ellipticity and Cea give the stated finest H1 bound;
the box Poincare constant gives the stated L2 bound.  The reported upper
bounds are rounded upward and remain conservative.  These numbers are inputs
to the protocol and are never fitted to a Gridap result.
"""
function native_g1g2_error_budget_basis_v1(; tensor_coefficients=nothing)
    diagonal = (schema="native-g1g2-pre-run-q1-error-budget-v1",
        derivation=:tensor_q1_fraction_integration_cea_poincare,
        value_representation=
            :rounded_decimal_approximations_of_fraction_integral_square_roots,
        physical_lower_metres=(1 // 2, 1 // 3, 1 // 4),
        physical_upper_metres=(5 // 2, 10 // 3, 17 // 4),
        physical_lengths_metres=(2 // 1, 3 // 1, 4 // 1),
        k_base=(2 // 1, 3 // 1, 4 // 1),
        k_slope=(1 // 10, 1 // 20, 1 // 30),
        ellipticity_bounds=(41 // 20, 497 // 120),
        q1_interpolation_l2_m32=(0.01042000975, 0.002805701325,
            0.000714216274),
        q1_interpolation_h1_m12=(0.02939176804, 0.01368454119,
            0.006674632049),
        cea_finest_h1_bound_m12=0.009487198126,
        poincare_finest_l2_bound_m32=0.004639855187,
        expected_l2_order=2 // 1, expected_h1_order=1 // 1,
        preasymptotic_order_half_width=3 // 5,
        polynomial_degree_bounds=(stiffness=2, rhs=3, squared_errors=4),
        gridap_quadrature_degree=8,
        declared_g2_quadrature_role=
            :identity_bound_geometry_metadata_not_execution_rule)
    tensor_coefficients === nothing && return diagonal
    lower = tensor_coefficients.physical_lower
    upper = tensor_coefficients.physical_upper
    base = tensor_coefficients.base_matrix
    slopes = tensor_coefficients.slope_matrices
    vertices = ntuple(mask -> begin
        point = ntuple(c -> iszero((mask - 1) & (1 << (c - 1))) ?
            lower[c] : upper[c], 3)
        ntuple(i -> ntuple(j -> base[i][j] +
            sum(slopes[c][i][j] * point[c] for c in 1:3), 3), 3)
    end, 8)
    diagonal_lower = ntuple(i -> minimum(matrix[i][i] for matrix in vertices), 3)
    diagonal_upper = ntuple(i -> maximum(matrix[i][i] for matrix in vertices), 3)
    offdiag_abs_upper = ntuple(i -> ntuple(j -> i == j ? 0 // 1 :
        maximum(abs(matrix[i][j]) for matrix in vertices), 3), 3)
    alpha = minimum(diagonal_lower[i] -
        sum(offdiag_abs_upper[i][j] for j in 1:3 if j != i) for i in 1:3)
    beta = maximum(diagonal_upper[i] +
        sum(offdiag_abs_upper[i][j] for j in 1:3 if j != i) for i in 1:3)
    alpha > 0 || throw(ArgumentError("tensor K budget requires a positive Gershgorin lower bound"))
    kappa_squared = beta / alpha
    default_hierarchy = _ng12_mesh_hierarchy_v1((2, 3, 4))
    exact_errors = Tuple(_ng12_q1_tensor_error_squares_v1(cells)
        for cells in default_hierarchy)
    h1_squared = Tuple(item.h1_squared for item in exact_errors)
    l2_squared = Tuple(item.l2_squared for item in exact_errors)
    cea_squared = kappa_squared * h1_squared[3]
    pi_lower = BigInt(314159) // BigInt(100000)
    inverse_length_square_sum = sum(BigInt(1) // (BigInt(length)^2)
        for length in (2, 3, 4))
    poincare_squared = cea_squared /
        (pi_lower^2 * inverse_length_square_sum)
    merge(diagonal, (schema="native-g1g2-pre-run-q1-tensor-error-budget-v2",
        coefficient_kind=:symmetric_affine_tensor,
        physical_lower_metres=lower, physical_upper_metres=upper,
        k_base_matrix=base, k_slope_matrices=slopes,
        k_base=ntuple(i -> base[i][i], 3),
        k_slope=ntuple(i -> slopes[i][i][i], 3),
        ellipticity_bounds=(alpha, beta),
        value_representation=:exact_q1_fraction_integrals_with_gershgorin_cea,
        q1_interpolation_l2_squared_m3=l2_squared,
        q1_interpolation_h1_squared_m1=h1_squared,
        cea_finest_h1_squared_m1=cea_squared,
        cea_finest_h1_bound_m12=_ng12_upper_sqrt_float64_v1(cea_squared),
        poincare_pi_lower=pi_lower,
        poincare_finest_l2_squared_m3=poincare_squared,
        poincare_finest_l2_bound_m32=
            _ng12_upper_sqrt_float64_v1(poincare_squared)))
end

_ng12_big_rational_v1(x::Rational) =
    BigInt(numerator(x)) // BigInt(denominator(x))

function _ng12_base_cell_counts_v1(base_cells)
    base_cells isa Tuple && !(base_cells isa NamedTuple) &&
        length(base_cells) == 3 && all(n -> n isa Integer &&
            !(n isa Bool) && 1 <= n <= typemax(Int) ÷ 4, base_cells) ||
        throw(ArgumentError("base cells must be three positive Int-sized integers"))
    ntuple(i -> Int(base_cells[i]), 3)
end

function _ng12_check_mesh_size_v1(cells)
    cells isa NTuple{3,Int} && all(>(0), cells) ||
        throw(ArgumentError("mesh counts must be three positive Int values"))
    Base.Checked.checked_mul(Base.Checked.checked_mul(cells[1], cells[2]),
        cells[3])
    nodes = ntuple(i -> Base.Checked.checked_add(cells[i], 1), 3)
    Base.Checked.checked_mul(Base.Checked.checked_mul(nodes[1], nodes[2]),
        nodes[3])
    nothing
end

function _ng12_mesh_hierarchy_v1(base_cells)
    base = _ng12_base_cell_counts_v1(base_cells)
    hierarchy = ntuple(level -> ntuple(i -> base[i] * (1 << (level - 1)), 3), 3)
    foreach(_ng12_check_mesh_size_v1, hierarchy)
    hierarchy
end

"""Exact closed-form 1D moments for g(t)=t(1-t) and its Q1 interpolant."""
function _ng12_q1_1d_moments_v1(ncells::Int, length_value::Rational)
    ncells > 0 || throw(ArgumentError("cell count must be positive"))
    n = BigInt(ncells)
    n2 = n * n
    n4 = n2 * n2
    length_exact = _ng12_big_rational_v1(length_value)
    g2 = length_exact * (BigInt(1) // BigInt(30))
    l2 = length_exact * (((n2 - 1) * (3n2 - 2)) //
        (BigInt(90) * n4))
    gl = length_exact * (((n2 - 1) * (6n2 + 1)) //
        (BigInt(180) * n4))
    dg2 = (BigInt(1) // BigInt(3)) / length_exact
    dgl = ((n2 - 1) // (BigInt(3) * n2)) / length_exact
    (g2=g2, l2=l2, gl=gl, dg2=dg2, dgl=dgl, dl2=dgl)
end
function _ng12_q1_tensor_error_squares_v1(cells)
    lengths = (2 // 1, 3 // 1, 4 // 1)
    moments = ntuple(i -> _ng12_q1_1d_moments_v1(cells[i], lengths[i]), 3)
    l2_squared = prod(moments[i].g2 for i in 1:3) -
        2 * prod(moments[i].gl for i in 1:3) +
        prod(moments[i].l2 for i in 1:3)
    h1_squared = BigInt(0) // BigInt(1)
    for i in 1:3
        others = Tuple(j for j in 1:3 if j != i)
        h1_squared += moments[i].dg2 * moments[others[1]].g2 *
                moments[others[2]].g2 -
            2 * moments[i].dgl * moments[others[1]].gl *
                moments[others[2]].gl +
            moments[i].dl2 * moments[others[1]].l2 *
                moments[others[2]].l2
    end
    l2_squared > 0 && h1_squared > 0 ||
        throw(ArgumentError("exact Q1 interpolation error square is nonpositive"))
    (l2_squared=l2_squared, h1_squared=h1_squared)
end

function _ng12_upper_sqrt_float64_v1(value::Rational{BigInt})
    value >= 0 || throw(ArgumentError("error bound square must be nonnegative"))
    precision_bits = max(256, ndigits(numerator(value); base=2),
        ndigits(denominator(value); base=2)) + 32
    upper = setprecision(BigFloat, precision_bits) do
        exact_rational = setrounding(BigFloat, RoundUp) do
            BigFloat(numerator(value)) / BigFloat(denominator(value))
        end
        setrounding(BigFloat, RoundUp) do
            sqrt(exact_rational)
        end
    end
    rounded = Float64(upper)
    isfinite(rounded) || throw(ArgumentError("error bound is outside Float64 range"))
    rounded_below_upper = setprecision(BigFloat, precision(upper)) do
        BigFloat(rounded) < upper
    end
    rounded_below_upper ? nextfloat(rounded) : rounded
end

function native_g1g2_error_budget_basis_v1(base_cells::NTuple{3,<:Integer};
        tensor_coefficients=nothing)
    base = _ng12_base_cell_counts_v1(base_cells)
    base == (2, 3, 4) && return native_g1g2_error_budget_basis_v1(
        tensor_coefficients=tensor_coefficients)
    hierarchy = _ng12_mesh_hierarchy_v1(base)
    exact_errors = Tuple(_ng12_q1_tensor_error_squares_v1(cells)
        for cells in hierarchy)
    l2_squared = Tuple(item.l2_squared for item in exact_errors)
    h1_squared = Tuple(item.h1_squared for item in exact_errors)
    l2_errors = Tuple(_ng12_upper_sqrt_float64_v1(value)
        for value in l2_squared)
    h1_errors = Tuple(_ng12_upper_sqrt_float64_v1(value)
        for value in h1_squared)
    coefficient_basis = native_g1g2_error_budget_basis_v1(
        tensor_coefficients=tensor_coefficients)
    kappa_squared = coefficient_basis.ellipticity_bounds[2] /
        coefficient_basis.ellipticity_bounds[1]
    cea_squared = kappa_squared * h1_squared[3]
    # 314159/100000 is a strict rational lower bound for pi, so this exact
    # rational Poincare factor is an upper bound for the Dirichlet box constant.
    pi_lower = BigInt(314159) // BigInt(100000)
    lengths = (BigInt(2)//BigInt(1), BigInt(3)//BigInt(1), BigInt(4)//BigInt(1))
    inverse_length_square_sum = sum(BigInt(1) // (length^2) for length in lengths)
    poincare_l2_squared = cea_squared /
        (pi_lower^2 * inverse_length_square_sum)
    merge(coefficient_basis,
        (base_cell_counts=base, three_level_cell_counts=hierarchy,
         value_representation=:exact_rational_tensor_q1_integrals_with_upward_float64_sqrt,
         q1_interpolation_l2_squared_m3=l2_squared,
         q1_interpolation_h1_squared_m1=h1_squared,
         q1_interpolation_l2_m32=l2_errors,
         q1_interpolation_h1_m12=h1_errors,
         cea_finest_h1_squared_m1=cea_squared,
         cea_finest_h1_bound_m12=_ng12_upper_sqrt_float64_v1(cea_squared),
         poincare_pi_lower=pi_lower,
         poincare_finest_l2_squared_m3=poincare_l2_squared,
         poincare_finest_l2_bound_m32=
            _ng12_upper_sqrt_float64_v1(poincare_l2_squared)))
end

function _ng12_error_budget_applies(form, protocol)
    p = form.programs.parameters
    source = form.g2_declaration.source
    tensor_coefficients = _ng12_tensor_budget_coefficients_v1(
        form.g1_declaration.K.expression)
    expected_protocol = native_g1g2_numerical_protocol_v1(source.mesh.cells;
        tensor_coefficients=tensor_coefficients)
    canonical_json(protocol) == canonical_json(expected_protocol) || return false
    b = protocol.budget_basis
    bounds = g2mb_chart_image_bounds(source.chart_map)
    lower = ntuple(i -> bounds[i][1], 3)
    upper = ntuple(i -> bounds[i][2], 3)
    ellipticity_matches = if tensor_coefficients === nothing
        endpoint_values = Tuple(p.k_base[i] + p.k_slope[i] * x
            for i in 1:3 for x in (lower[i], upper[i]))
        (minimum(endpoint_values), maximum(endpoint_values)) ==
            b.ellipticity_bounds
    else
        native_g1g2_error_budget_basis_v1(source.mesh.cells;
            tensor_coefficients=tensor_coefficients).ellipticity_bounds ==
                b.ellipticity_bounds
    end
    p.physical_lower == b.physical_lower_metres &&
    p.physical_upper == b.physical_upper_metres &&
    p.physical_lengths == b.physical_lengths_metres &&
    (if tensor_coefficients === nothing
        p.k_base == b.k_base && p.k_slope == b.k_slope
     else
        b.k_base_matrix == tensor_coefficients.base_matrix &&
        b.k_slope_matrices == tensor_coefficients.slope_matrices &&
        p.k_base_matrix == tensor_coefficients.base_matrix &&
        p.k_slope_matrices == tensor_coefficients.slope_matrices
     end) &&
    lower == b.physical_lower_metres && upper == b.physical_upper_metres &&
    ellipticity_matches &&
    protocol.cell_counts == _ng12_mesh_hierarchy_v1(source.mesh.cells) &&
    b.cea_finest_h1_bound_m12 <= protocol.finest_h1_seminorm_max &&
    b.poincare_finest_l2_bound_m32 <= protocol.finest_l2_max
end

_ng12_tensor_budget_coefficients_v1(expression::FusionConceptAI.G1DiffusionDiagonalAffineKFieldV1) =
    nothing
_ng12_tensor_budget_coefficients_v1(expression::FusionConceptAI.G1DiffusionSymmetricAffineTensorKFieldV2) =
    (physical_lower=expression.domain_min, physical_upper=expression.domain_max,
     base_matrix=expression.base_matrix, slope_matrices=expression.slope_matrices)

function _ng12_budget_coefficients_from_basis_v1(basis)
    hasproperty(basis, :k_base_matrix) || return nothing
    (physical_lower=basis.physical_lower_metres,
     physical_upper=basis.physical_upper_metres,
     base_matrix=basis.k_base_matrix,
     slope_matrices=basis.k_slope_matrices)
end

struct NativeG1G2NumericalProtocolV1
    cell_counts::NTuple{3,NTuple{3,Int}}
    quadrature_degree::Int
    solver::Symbol
    residual_abs_tol::Float64
    residual_rel_tol::Float64
    boundary_abs_tol::Float64
    source_integral_abs_tol::Float64
    analytic_identity_abs_tol::Float64
    reaction_balance_abs_tol::Float64
    l2_order_interval::NTuple{2,Float64}
    h1_order_interval::NTuple{2,Float64}
    finest_l2_max::Float64
    finest_h1_seminorm_max::Float64
    budget_basis::NamedTuple
    protocol_hash::Digest256
end

# The exact dynamic error budget uses Rational{BigInt}, intentionally outside the
# global primitive whitelist. Give those values an explicit, lossless semantic
# view for protocol hashing while keeping the original rationals in the protocol.
_ng12_budget_canonical_value_v1(x::Rational{BigInt}) =
    (kind=:exact_rational_bigint, numerator=string(numerator(x)),
     denominator=string(denominator(x)))
_ng12_budget_canonical_value_v1(x::NamedTuple{names}) where {names} =
    NamedTuple{names}(map(_ng12_budget_canonical_value_v1, values(x)))
_ng12_budget_canonical_value_v1(x::Tuple) =
    map(_ng12_budget_canonical_value_v1, x)
_ng12_budget_canonical_value_v1(x) = x

function _ng12_protocol_body(cell_counts, quadrature_degree, solver,
        residual_abs_tol, residual_rel_tol, boundary_abs_tol,
        source_integral_abs_tol, analytic_identity_abs_tol,
        reaction_balance_abs_tol,
        l2_order_interval, h1_order_interval, finest_l2_max,
        finest_h1_seminorm_max, budget_basis)
    (domain="native-g1g2-gridap-numerical-protocol-v1",
        cell_counts=cell_counts, quadrature_degree=quadrature_degree,
        solver=solver, residual_abs_tol=residual_abs_tol,
        residual_rel_tol=residual_rel_tol,
        boundary_abs_tol=boundary_abs_tol,
        source_integral_abs_tol=source_integral_abs_tol,
        analytic_identity_abs_tol=analytic_identity_abs_tol,
        reaction_balance_abs_tol=reaction_balance_abs_tol,
        l2_order_interval=l2_order_interval,
        h1_order_interval=h1_order_interval,
        finest_l2_max=finest_l2_max,
        finest_h1_seminorm_max=finest_h1_seminorm_max,
        budget_basis=_ng12_budget_canonical_value_v1(budget_basis))
end

function native_g1g2_numerical_protocol_v1(;
        cell_counts=((2, 3, 4), (4, 6, 8), (8, 12, 16)),
        quadrature_degree::Integer=8,
        solver::Symbol=:gridap_sparse_lu,
        residual_abs_tol::Real=1.0e-9,
        residual_rel_tol::Real=1.0e-11,
        boundary_abs_tol::Real=1.0e-10,
        source_integral_abs_tol::Real=1.0e-10,
        analytic_identity_abs_tol::Real=1.0e-12,
        reaction_balance_abs_tol::Real=1.0e-9,
        l2_order_interval=(1.4, 2.6),
        h1_order_interval=(0.6, 1.4),
        finest_l2_max::Real=5.0e-3,
        finest_h1_seminorm_max::Real=1.0e-2,
        tensor_coefficients=nothing)
    counts = Tuple(ntuple(i -> Int(level[i]), 3) for level in cell_counts)
    length(counts) == 3 || throw(ArgumentError("protocol requires three grids"))
    all(all(>(0), level) for level in counts) ||
        throw(ArgumentError("cell counts must be positive"))
    foreach(_ng12_check_mesh_size_v1, counts)
    all(counts[i + 1] == ntuple(j ->
            Base.Checked.checked_mul(2, counts[i][j]), 3) for i in 1:2) ||
        throw(ArgumentError("grids must be nested 2x refinements"))
    quadrature_degree >= 6 ||
        throw(ArgumentError("variable polynomial MMS requires quadrature degree >= 6"))
    solver === :gridap_sparse_lu || throw(ArgumentError("unsupported solver"))
    tolerances = Float64.((residual_abs_tol, residual_rel_tol,
        boundary_abs_tol, source_integral_abs_tol,
        analytic_identity_abs_tol, reaction_balance_abs_tol, finest_l2_max,
        finest_h1_seminorm_max))
    all(isfinite, tolerances) && all(>(0.0), tolerances) ||
        throw(ArgumentError("protocol tolerances must be finite and positive"))
    l2 = (Float64(l2_order_interval[1]), Float64(l2_order_interval[2]))
    h1 = (Float64(h1_order_interval[1]), Float64(h1_order_interval[2]))
    0.0 < l2[1] < l2[2] && 0.0 < h1[1] < h1[2] ||
        throw(ArgumentError("order intervals are invalid"))
    body = _ng12_protocol_body(counts, Int(quadrature_degree), solver,
        tolerances[1], tolerances[2], tolerances[3], tolerances[4],
        tolerances[5], tolerances[6], l2, h1, tolerances[7], tolerances[8],
        native_g1g2_error_budget_basis_v1(
            tensor_coefficients=tensor_coefficients))
    NativeG1G2NumericalProtocolV1(counts, Int(quadrature_degree), solver,
        tolerances[1], tolerances[2], tolerances[3], tolerances[4],
        tolerances[5], tolerances[6], l2, h1, tolerances[7], tolerances[8],
        native_g1g2_error_budget_basis_v1(
            tensor_coefficients=tensor_coefficients),
        canonical_hash(body))
end

function native_g1g2_numerical_protocol_v1(base_cells::NTuple{3,<:Integer};
        tensor_coefficients=nothing)
    base = _ng12_base_cell_counts_v1(base_cells)
    base == (2, 3, 4) && return native_g1g2_numerical_protocol_v1(
        tensor_coefficients=tensor_coefficients)
    hierarchy = _ng12_mesh_hierarchy_v1(base)
    baseline = native_g1g2_numerical_protocol_v1(cell_counts=hierarchy,
        tensor_coefficients=tensor_coefficients)
    budget = native_g1g2_error_budget_basis_v1(base;
        tensor_coefficients=tensor_coefficients)
    body = _ng12_protocol_body(baseline.cell_counts,
        baseline.quadrature_degree, baseline.solver,
        baseline.residual_abs_tol, baseline.residual_rel_tol,
        baseline.boundary_abs_tol, baseline.source_integral_abs_tol,
        baseline.analytic_identity_abs_tol, baseline.reaction_balance_abs_tol,
        baseline.l2_order_interval, baseline.h1_order_interval,
        baseline.finest_l2_max, baseline.finest_h1_seminorm_max, budget)
    NativeG1G2NumericalProtocolV1(baseline.cell_counts,
        baseline.quadrature_degree, baseline.solver,
        baseline.residual_abs_tol, baseline.residual_rel_tol,
        baseline.boundary_abs_tol, baseline.source_integral_abs_tol,
        baseline.analytic_identity_abs_tol, baseline.reaction_balance_abs_tol,
        baseline.l2_order_interval, baseline.h1_order_interval,
        baseline.finest_l2_max, baseline.finest_h1_seminorm_max,
        budget, canonical_hash(body))
end

semantic_view(x::NativeG1G2NumericalProtocolV1) = merge(
    _ng12_protocol_body(x.cell_counts, x.quadrature_degree, x.solver,
        x.residual_abs_tol, x.residual_rel_tol, x.boundary_abs_tol,
        x.source_integral_abs_tol, x.analytic_identity_abs_tol,
        x.reaction_balance_abs_tol,
        x.l2_order_interval, x.h1_order_interval, x.finest_l2_max,
        x.finest_h1_seminorm_max, x.budget_basis),
    (protocol_hash=x.protocol_hash,))
canonical_hash(x::NativeG1G2NumericalProtocolV1) = x.protocol_hash

function _ng12_protocol_integrity(x::NativeG1G2NumericalProtocolV1)
    valid_counts = try
        x.cell_counts == _ng12_mesh_hierarchy_v1(x.cell_counts[1])
    catch
        false
    end
    expected_budget = try
        native_g1g2_error_budget_basis_v1(x.cell_counts[1];
            tensor_coefficients=_ng12_budget_coefficients_from_basis_v1(
                x.budget_basis))
    catch
        nothing
    end
    valid_counts && length(x.cell_counts) == 3 &&
    all(x.cell_counts[i + 1] == ntuple(j -> 2 * x.cell_counts[i][j], 3)
        for i in 1:2) && x.quadrature_degree >= 6 &&
    x.solver === :gridap_sparse_lu &&
    all(isfinite, (x.residual_abs_tol, x.residual_rel_tol,
        x.boundary_abs_tol, x.source_integral_abs_tol,
        x.analytic_identity_abs_tol, x.reaction_balance_abs_tol,
        x.finest_l2_max,
        x.finest_h1_seminorm_max, x.l2_order_interval...,
        x.h1_order_interval...)) &&
    expected_budget !== nothing && x.budget_basis == expected_budget &&
    canonical_hash(_ng12_protocol_body(x.cell_counts,
        x.quadrature_degree, x.solver, x.residual_abs_tol,
        x.residual_rel_tol, x.boundary_abs_tol,
        x.source_integral_abs_tol, x.analytic_identity_abs_tol,
        x.reaction_balance_abs_tol,
        x.l2_order_interval, x.h1_order_interval, x.finest_l2_max,
        x.finest_h1_seminorm_max, x.budget_basis)) == x.protocol_hash
end

struct NativeG1G2GridapPlanV1
    compilation::NativeG1G2DiffusionCompilationV1
    compile_result_hash::Digest256
    protocol::NativeG1G2NumericalProtocolV1
    dependency_identity::NamedTuple
    provider::ProviderManifestV4
    subject::ExecutablePhysicalSubjectV4
    solver_input::SolverInputV4
    adapter_source_hash::Digest256
    plan_hash::Digest256
end

function _ng12_canonical_payload_targets_v1(
        compilation::NativeG1G2DiffusionCompilationV1)
    programs = getfield(getfield(compilation, :form), :programs)
    (getfield(programs, :unknown_program),
        getfield(programs, :reference_program),
        getfield(programs, :source_program),
        getfield(programs, :residual_program))
end
_ng12_canonical_payload_targets_v1(::Nothing) = ()

# The compilation is embedded unchanged in several complete canonical parent
# bodies while this plan is prepared. Reuse only its exact immutable JSON
# subtree; enclosing objects continue to hash their complete canonical bodies.
function FusionConceptAI._canonical(
        x::NativeG1G2DiffusionCompilationV1)
    FusionConceptAI._canonical_json_memoized(x) do
        FusionConceptAI._canonical(FusionConceptAI.semantic_view(x))
    end
end

"""Compiler-validated plan payload whose plan validation is explicitly deferred.

This staging carrier has no admission token and cannot be passed to execution
APIs.  A consumer must extract `plan` and run the public plan validator in its
own process before executing it.
"""
struct NativeG1G2GridapStagedPlanV1
    plan::NativeG1G2GridapPlanV1
    validation_state::Symbol
    numerical_execution::Symbol
    accepted::Bool
end

function _ng12_gridap_plan_body(compilation, compile_result_hash, protocol,
        dependency_identity, provider, subject, solver_input,
        adapter_source_hash)
    (domain="native-g1g2-gridap-plan-v1", compilation=compilation,
        compile_result_hash=compile_result_hash, protocol=protocol,
        dependency_identity=dependency_identity, provider=provider,
        subject=subject, solver_input=solver_input,
        adapter_source_hash=adapter_source_hash)
end

semantic_view(x::NativeG1G2GridapPlanV1) = merge(
    _ng12_gridap_plan_body(x.compilation, x.compile_result_hash,
        x.protocol, x.dependency_identity, x.provider, x.subject,
        x.solver_input, x.adapter_source_hash), (plan_hash=x.plan_hash,))
canonical_hash(x::NativeG1G2GridapPlanV1) = x.plan_hash

"""Process-local proof that a complete Gridap plan was fully validated.

The token is intentionally mutable and registered by object identity so a
caller cannot synthesize an equivalent-looking token.  Its admission record
binds the current canonical plan content, or all raw fields for a deeply
immutable plan, and the active compiler, adapter, qualification environment,
and (when present) UP1 frozen snapshot.
"""
mutable struct NativeG1G2GridapPlanAdmissionV1
    plan_hash::Digest256
    fingerprint::Digest256
    context_hash::Digest256
end

const _NG12_ADMISSION_LOCK = ReentrantLock()
const _NG12_PLAN_ADMISSIONS = Dict{Digest256,NativeG1G2GridapPlanAdmissionV1}()
const _NG12_PLAN_ADMISSION_RECORDS = IdDict{Any,NamedTuple}()
const _NG12_COMPILATION_ADMISSIONS = Dict{Digest256,NamedTuple}()

function _ng12_serialized_fingerprint_v1(value)
    io = IOBuffer()
    Serialization.serialize(io, value)
    Digest256(bytes2hex(SHA.sha256(take!(io))))
end

function _ng12_snapshot_admission_identity_v1()
    root_value = get(ENV, "UP1_FROZEN_SNAPSHOT_ROOT", "")
    receipt_path_value = get(ENV, "UP1_FROZEN_RECEIPT_PATH", "")
    receipt_sha_value = lowercase(get(ENV,
        "UP1_FROZEN_RECEIPT_SHA256", ""))
    if isempty(root_value) && isempty(receipt_path_value) &&
            isempty(receipt_sha_value)
        return (snapshot_root="", manifest_sha256="", receipt_sha256="")
    end
    isempty(root_value) && throw(ArgumentError("frozen snapshot root is missing"))
    isempty(receipt_path_value) &&
        throw(ArgumentError("frozen receipt path is missing"))
    occursin(r"^[0-9a-f]{64}$", receipt_sha_value) ||
        throw(ArgumentError("frozen receipt SHA-256 is invalid"))
    root = normpath(abspath(root_value))
    manifest_path = joinpath(root, "manifest.toml")
    isfile(manifest_path) ||
        throw(ArgumentError("frozen snapshot manifest is missing"))
    receipt_path = normpath(abspath(receipt_path_value))
    isfile(receipt_path) ||
        throw(ArgumentError("frozen snapshot receipt is missing"))
    actual_receipt_sha = bytes2hex(SHA.sha256(read(receipt_path)))
    actual_receipt_sha == receipt_sha_value ||
        throw(ArgumentError("frozen snapshot receipt SHA-256 mismatch"))
    (snapshot_root=root,
        manifest_sha256=bytes2hex(SHA.sha256(read(manifest_path))),
        receipt_sha256=actual_receipt_sha)
end

function _ng12_admission_context_hash_v1()
    dependency = _gridap_dependency_identity()
    snapshot = _ng12_snapshot_admission_identity_v1()
    canonical_hash((
        compiler_source_hash=native_g1g2_diffusion_compiler_source_hash_v1(),
        adapter_source_hash=native_g1g2_gridap_adapter_source_hash_v1(),
        dependency_identity=dependency,
        snapshot_identity=snapshot))
end

function _ng12_admit_compilation_after_full_validation_v1(compilation)
    fingerprint = _ng12_serialized_fingerprint_v1(compilation)
    context_hash = _ng12_admission_context_hash_v1()
    hash = compilation.compilation_hash
    lock(_NG12_ADMISSION_LOCK) do
        if haskey(_NG12_COMPILATION_ADMISSIONS, hash)
            record = _NG12_COMPILATION_ADMISSIONS[hash]
            record.fingerprint == fingerprint &&
                record.context_hash == context_hash || return false
            return true
        end
        _NG12_COMPILATION_ADMISSIONS[hash] =
            (fingerprint=fingerprint, context_hash=context_hash)
        true
    end
end

function _ng12_validate_compilation_with_admission_v1(compilation)
    _ng12_stage_v1("adapter_compilation_fingerprint_begin")
    fingerprint = try
        _ng12_serialized_fingerprint_v1(compilation)
    catch
        _ng12_stage_v1("adapter_compilation_fingerprint_error")
        return false
    end
    _ng12_stage_v1("adapter_compilation_fingerprint_complete")
    context_hash = try
        _ng12_admission_context_hash_v1()
    catch
        return false
    end
    hash = compilation.compilation_hash
    record = lock(_NG12_ADMISSION_LOCK) do
        get(_NG12_COMPILATION_ADMISSIONS, hash, nothing)
    end
    if record !== nothing
        return record.fingerprint == fingerprint &&
            record.context_hash == context_hash
    end
    _ng12_stage_v1("adapter_compilation_full_validation_begin")
    valid = validate_native_g1g2_diffusion_compilation_v1(compilation)
    _ng12_stage_v1("adapter_compilation_full_validation_complete")
    valid ||
        return false
    _ng12_admit_compilation_after_full_validation_v1(compilation)
end

function _ng12_canonical_plan_fingerprint_v1(
        x::NativeG1G2GridapPlanV1)
    FusionConceptAI._with_canonical_json_memo(x.compilation;
        payload_targets=_ng12_canonical_payload_targets_v1(x.compilation)) do
        canonical_hash(_ng12_gridap_plan_body(x.compilation,
            x.compile_result_hash, x.protocol, x.dependency_identity,
            x.provider, x.subject, x.solver_input, x.adapter_source_hash))
    end
end

function _ng12_plan_admission_projection_valid_v1(
        x::NativeG1G2GridapPlanV1)
    x.provider.executor === _native_g1g2_gridap_provider_executor_v1 ||
        return false
    form = x.compilation.form
    package = form.t1_package
    package.package_hash == form.t1_package_hash || return false
    package.semantic_identity == form.t1_semantic_identity || return false
    package.bundle_hash == form.t0_bundle_hash || return false
    isempty(_ng12_t1_package_binding_errors(package,
        form.g1_declaration, form.g2_declaration))
end

function _ng12_issue_plan_admission_v1(x::NativeG1G2GridapPlanV1)
    plan_is_deep_immutable = FusionConceptAI.deep_immutable(x)
    _ng12_stage_v1("adapter_plan_admission_deep_immutable=" *
        string(plan_is_deep_immutable))
    # The caller has just completed the full plan validator, which recomputes
    # the canonical body hash and proves it equals plan_hash. Keep the full
    # body fingerprint for any plan containing mutable reachable state.
    fingerprint = plan_is_deep_immutable ? x.plan_hash :
        _ng12_canonical_plan_fingerprint_v1(x)
    context_hash = _ng12_admission_context_hash_v1()
    token = NativeG1G2GridapPlanAdmissionV1(x.plan_hash, fingerprint,
        context_hash)
    record = (plan_hash=x.plan_hash, fingerprint=fingerprint,
        context_hash=context_hash, plan=x,
        plan_deep_immutable=plan_is_deep_immutable)
    lock(_NG12_ADMISSION_LOCK) do
        previous = get(_NG12_PLAN_ADMISSIONS, x.plan_hash, nothing)
        if previous !== nothing
            old = get(_NG12_PLAN_ADMISSION_RECORDS, previous, nothing)
            old !== nothing && old.fingerprint == fingerprint &&
                old.context_hash == context_hash || return false
            return true
        end
        _NG12_PLAN_ADMISSIONS[x.plan_hash] = token
        _NG12_PLAN_ADMISSION_RECORDS[token] = record
        true
    end
end

function native_g1g2_gridap_plan_admission_v1(
        x::NativeG1G2GridapPlanV1)
    token = lock(_NG12_ADMISSION_LOCK) do
        get(_NG12_PLAN_ADMISSIONS, x.plan_hash, nothing)
    end
    token !== nothing &&
        validate_native_g1g2_gridap_plan_admission_v1(x, token) ? token : nothing
end

function validate_native_g1g2_gridap_plan_admission_v1(
        x::NativeG1G2GridapPlanV1,
        token::NativeG1G2GridapPlanAdmissionV1)
    record = lock(_NG12_ADMISSION_LOCK) do
        get(_NG12_PLAN_ADMISSION_RECORDS, token, nothing)
    end
    record === nothing && return false
    try
        token.plan_hash == x.plan_hash == record.plan_hash || return false
        token.fingerprint == record.fingerprint || return false
        token.context_hash == record.context_hash || return false
        context_hash = _ng12_admission_context_hash_v1()
        context_hash == record.context_hash || return false
        # The issue-time recursive seal admits only immutable plan graphs.
        # For the same immutable type, whole-value egal is fieldwise egal.
        if record.plan_deep_immutable &&
                typeof(x) === typeof(record.plan) && x === record.plan
            return true
        end
        _ng12_plan_admission_projection_valid_v1(x) || return false
        _ng12_canonical_plan_fingerprint_v1(x) == record.fingerprint
    catch
        false
    end
end

function _ng12_validate_native_g1g2_gridap_plan_full_v1(
        x::NativeG1G2GridapPlanV1)
    try
        _ng12_validate_compilation_with_admission_v1(x.compilation) ||
            return false
        expected_gaps = (:native_g1g2_numerical_execution_pending,
            :up1_aggregate_gate_pending,
            :g3_material_conversion_missing,
            :g3_two_region_interface_missing)
        x.compile_result_hash == canonical_hash(_ng12_compile_result_body(
            :compiled_numerical_preparation, :terminal_deferred, false,
            :contract_only, x.compilation, (), expected_gaps)) || return false
        _ng12_protocol_integrity(x.protocol) || return false
        expected_protocol = native_g1g2_numerical_protocol_v1(
            x.compilation.form.g2_declaration.source.mesh.cells;
            tensor_coefficients=_ng12_tensor_budget_coefficients_v1(
                x.compilation.form.g1_declaration.K.expression))
        canonical_json(x.protocol) == canonical_json(expected_protocol) || return false
        _ng12_error_budget_applies(x.compilation.form, x.protocol) ||
            return false
        _gridap_dependency_integrity(x.dependency_identity) || return false
        x.adapter_source_hash == native_g1g2_gridap_adapter_source_hash_v1() ||
            return false
        match_provider(x.compilation.capability, (x.provider,)).status ==
            unique_match || return false
        x.subject.operator_obligations == (x.compilation.capability,) ||
            return false
        x.subject.scenarios == (x.compilation.scenario,) || return false
        materialized = x.subject.materialized_payload
        materialized == (compilation=x.compilation,
            compile_result_hash=x.compile_result_hash,
            protocol=x.protocol, dependency_identity=x.dependency_identity,
            adapter_source_hash=x.adapter_source_hash,
            execution_scope=:numerical_preparation,
            formal_t2_receipt_assignment=false) || return false
        x.solver_input.physical_subject_hash == x.subject.physical_subject_hash ||
            return false
        x.solver_input.provider_manifest_hash == x.provider.manifest_hash ||
            return false
        x.solver_input.input_schema_hash ==
            x.compilation.capability.input_schema_hash || return false
        x.solver_input.payload.materialized_payload == materialized || return false
        x.solver_input.payload.requested_obligation ==
            x.compilation.capability || return false
        x.solver_input.payload.scenario == x.compilation.scenario || return false
        x.provider.executor === _native_g1g2_gridap_provider_executor_v1 ||
            return false
        canonical_hash(_ng12_gridap_plan_body(x.compilation,
            x.compile_result_hash, x.protocol, x.dependency_identity,
            x.provider, x.subject, x.solver_input,
            x.adapter_source_hash)) == x.plan_hash
    catch
        false
    end
end

function validate_native_g1g2_gridap_plan_v1(x::NativeG1G2GridapPlanV1)
    try
        token = lock(_NG12_ADMISSION_LOCK) do
            get(_NG12_PLAN_ADMISSIONS, x.plan_hash, nothing)
        end
        if token !== nothing
            return validate_native_g1g2_gridap_plan_admission_v1(x, token)
        end
        valid = FusionConceptAI._with_canonical_json_memo(x.compilation;
            payload_targets=_ng12_canonical_payload_targets_v1(x.compilation)) do
            _ng12_validate_native_g1g2_gridap_plan_full_v1(x)
        end
        valid || return false
        _ng12_issue_plan_admission_v1(x)
    catch
        false
    end
end

function native_g1g2_gridap_provider_v1(
        compilation::NativeG1G2DiffusionCompilationV1,
        protocol::NativeG1G2NumericalProtocolV1,
        dependency_identity, adapter_source_hash)
    domain = (bounds_hash=compilation.capability.applicability_bounds,
        form_hash=compilation.form.form_hash,
        protocol_hash=protocol.protocol_hash,
        supported_chart=:positive_diagonal_affine,
        supported_basis=:Q1,
        supported_boundary=:all_six_faces_zero_dirichlet,
        declared_g2_quadrature_role=
            :identity_bound_geometry_metadata_not_execution_rule,
        gridap_quadrature_degree=protocol.quadrature_degree,
        gridap_dependency_hash=dependency_identity.dependency_hash)
    ProviderManifestV4(NATIVE_G1G2_DIFFUSION_SCHEMA_V1,
        NATIVE_G1G2_DIFFUSION_VERSION_V1, :native_g1g2_diffusion,
        compilation.capability, domain, NATIVE_G1G2_GRIDAP_BACKEND_V1,
        string(dependency_identity.gridap_version), adapter_source_hash,
        "gridap-native-g1g2-variable-diffusion-v1", screen_only;
        input_schema_hash=compilation.capability.input_schema_hash,
        executor=_native_g1g2_gridap_provider_executor_v1)
end

"""A independently matchable native Gridap service request.

The request contains a canonical SolverInput and its exact subject/provider
binding.  Constructing it does not create Gridap objects or execute a solve.
"""
struct NativeG1G2GridapServiceRequestV1
    service::Symbol
    capability::CapabilitySignatureV4
    provider::ProviderManifestV4
    subject::ExecutablePhysicalSubjectV4
    solver_input::SolverInputV4
    plan::NativeG1G2GridapPlanV1
    plan_hash::Digest256
    level::Int
end

"""Runtime objects constructed by the candidate-bound chart/mesh service."""
struct NativeG1G2GridapChartMeshContextV1
    service::Symbol
    service_input_hash::Digest256
    provider_manifest_hash::Digest256
    plan_hash::Digest256
    candidate_ref::Any
    package_hash::Digest256
    g1_declaration_hash::Digest256
    g2_declaration_hash::Digest256
    form_hash::Digest256
    level::Int
    physical_domain::NTuple{6,Float64}
    cell_counts::NTuple{3,Int}
    declared_mesh_quadrature_hash::Digest256
    execution_quadrature_degree::Int
    model::Any
    reffe::Any
    omega::Any
    measure::Any
end

"""Runtime objects and six-face bindings from the exterior-boundary service."""
struct NativeG1G2GridapExteriorBoundaryContextV1
    service::Symbol
    service_input_hash::Digest256
    provider_manifest_hash::Digest256
    plan_hash::Digest256
    candidate_ref::Any
    package_hash::Digest256
    g1_declaration_hash::Digest256
    g2_declaration_hash::Digest256
    form_hash::Digest256
    level::Int
    chart_mesh_input_hash::Digest256
    source_face_hash::Digest256
    face_owners::Tuple
    dirichlet_tag::String
    dirichlet_value::Float64
    test_space::Any
    trial_space::Any
    boundary::Any
    boundary_measure::Any
    boundary_normal::Any
end

const _NG12_CHART_MESH_SERVICE_V1 = :native_g1g2_gridap_chart_mesh
const _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 = :native_g1g2_gridap_exterior_boundary
const _NG12_GRAD_SERVICE_V1 = :native_g1g2_gridap_grad
const _NG12_SERVICE_SCHEMA_V1 = "native-g1g2-gridap-component-service-v1"

function _ng12_gridap_expected_reference_normal(face::Symbol)
    face === :x_min && return (Int8(-1), Int8(0), Int8(0))
    face === :x_max && return (Int8(1), Int8(0), Int8(0))
    face === :y_min && return (Int8(0), Int8(-1), Int8(0))
    face === :y_max && return (Int8(0), Int8(1), Int8(0))
    face === :z_min && return (Int8(0), Int8(0), Int8(-1))
    face === :z_max && return (Int8(0), Int8(0), Int8(1))
    throw(ArgumentError("unsupported G2 exterior face"))
end

function _ng12_gridap_service_request_v1(
        plan::NativeG1G2GridapPlanV1, level::Integer, service::Symbol)
    _ng12_stage_v1("adapter_thin_service_factory_begin")
    service in (_NG12_CHART_MESH_SERVICE_V1,
        _NG12_EXTERIOR_BOUNDARY_SERVICE_V1, _NG12_GRAD_SERVICE_V1) ||
        throw(ArgumentError("unsupported native G1/G2 Gridap service"))
    validate_native_g1g2_gridap_plan_v1(plan) ||
        throw(ArgumentError("Gridap plan integrity mismatch"))
    1 <= level <= 3 || throw(ArgumentError("refinement level must be 1:3"))
    compilation = plan.compilation
    form = compilation.form
    source = form.g2_declaration.source
    level_index = Int(level)
    cells = plan.protocol.cell_counts[level_index]
    source.mesh.cells == plan.protocol.cell_counts[1] ||
        throw(ArgumentError("G2 mesh declaration does not bind the frozen level-1 mesh"))
    declared_mesh_quadrature_hash = canonical_hash((
        points=source.mesh.quadrature_points,
        weights=source.mesh.quadrature_weights))
    g1_grad_contract = service === _NG12_GRAD_SERVICE_V1 ?
        semantic_view(form.g1_declaration.operators.grad) : nothing
    service_executor = service === _NG12_CHART_MESH_SERVICE_V1 ?
        _ng12_gridap_chart_mesh_executor_v1 :
        service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 ?
        _ng12_gridap_exterior_boundary_executor_v1 :
        _ng12_gridap_grad_executor_v1
    input_schema_body = (
        schema=_NG12_SERVICE_SCHEMA_V1, revision="v1", service=service,
        plan_hash=plan.plan_hash, candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        g2_source_hash=source.source_hash, form_hash=form.form_hash,
        declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
        protocol_hash=plan.protocol.protocol_hash, level=level_index,
        cells=cells, dependency_hash=plan.dependency_identity.dependency_hash,
        adapter_source_hash=plan.adapter_source_hash)
    input_schema_hash = canonical_hash(service === _NG12_GRAD_SERVICE_V1 ?
        merge(input_schema_body, (g1_grad_contract=g1_grad_contract,)) :
        input_schema_body)
    applicability_hash = canonical_hash((
        service_scope="candidate-bound-native-g1g2-gridap-service-v1",
        service=service, plan_hash=plan.plan_hash,
        candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        g2_source_hash=source.source_hash, form_hash=form.form_hash,
        declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
        protocol_hash=plan.protocol.protocol_hash, level=level_index,
        cells=cells))
    boundary_relation = service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 ?
        "six-candidate-owned-exterior-faces-zero-dirichlet" : "none"
    outputs = service === _NG12_CHART_MESH_SERVICE_V1 ?
        ("cartesian_discrete_model", "q1_reference_element",
         "physical_triangulation", "quadrature_measure") :
        service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 ?
        ("six_face_owner_bindings", "zero_dirichlet_test_trial_spaces",
         "boundary_triangulation", "boundary_measure", "outward_normal") :
        ("candidate_u_gradient_cell_field",)
    operator_name = service === _NG12_CHART_MESH_SERVICE_V1 ?
        "materialize_candidate_chart_mesh_basis_quadrature" :
        service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 ?
        "materialize_candidate_exterior_boundary_conditions" :
        string(g1_grad_contract.operator_ref.id, "@",
            g1_grad_contract.operator_ref.version)
    source_space = service === _NG12_GRAD_SERVICE_V1 ?
        "gridap_q1_h1_static_3d_scalar" : "physical_candidate_field"
    target_space = service === _NG12_GRAD_SERVICE_V1 ?
        "gridap_q1_piecewise_l2_static_3d_vector" : "gridap_q1_h1_space"
    capability = CapabilitySignatureV4(_NG12_SERVICE_SCHEMA_V1, "v1",
        service, operator_name, ("u",), source_space, target_space, 3,
        ("x", "y", "z"), boundary_relation, "none", "steady",
        outputs, screen_only, applicability_hash;
        input_schema_hash=input_schema_hash,
        coordinate_system="candidate_physical_cartesian")
    domain = (bounds_hash=applicability_hash,
        service=service, plan_hash=plan.plan_hash,
        candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        g2_source_hash=source.source_hash, form_hash=form.form_hash,
        protocol_hash=plan.protocol.protocol_hash, level=level_index,
        cell_counts=cells,
        declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
        execution_quadrature_degree=plan.protocol.quadrature_degree,
        gridap_dependency_hash=plan.dependency_identity.dependency_hash)
    provider = ProviderManifestV4(_NG12_SERVICE_SCHEMA_V1, "v1", service,
        capability, domain, NATIVE_G1G2_GRIDAP_BACKEND_V1,
        string(plan.dependency_identity.gridap_version),
        plan.adapter_source_hash, "gridap-native-g1g2-component-service-v1",
        screen_only; input_schema_hash=input_schema_hash,
        executor=service_executor)
    payload_body = (service_scope="native-g1g2-gridap-service-input-v1",
        service=service, plan_hash=plan.plan_hash,
        candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        g2_source_hash=source.source_hash, form_hash=form.form_hash,
        protocol_hash=plan.protocol.protocol_hash,
        dependency_hash=plan.dependency_identity.dependency_hash,
        adapter_source_hash=plan.adapter_source_hash,
        level=level_index, cell_counts=cells,
        declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
        execution_quadrature_degree=plan.protocol.quadrature_degree,
        capability_hash=canonical_hash(capability),
        provider_manifest_hash=provider.manifest_hash,
        input_schema_hash=input_schema_hash,
        applicability_hash=applicability_hash)
    payload = service === _NG12_GRAD_SERVICE_V1 ?
        merge(payload_body, (g1_grad_contract_hash=canonical_hash(
            g1_grad_contract),)) : payload_body
    subject = ExecutablePhysicalSubjectV4(
        plan.subject.compiled_prefix_hash, plan.subject.genome_bundle_hash,
        plan.subject.mission_hash, applicability_hash,
        plan.subject.bindings, (compilation.scenario,), payload,
        (capability,))
    solver_input = compile_solver_input(subject, compilation.scenario,
        capability, provider)
    request = NativeG1G2GridapServiceRequestV1(service, capability, provider,
        subject, solver_input, plan, plan.plan_hash, level_index)
    _ng12_stage_v1("adapter_thin_service_factory_complete")
    request
end

"""Build the separately matchable chart, mesh, basis and quadrature request."""
native_g1g2_gridap_chart_mesh_service_v1(
        plan::NativeG1G2GridapPlanV1, level::Integer) =
    _ng12_gridap_service_request_v1(plan, level,
        _NG12_CHART_MESH_SERVICE_V1)

"""Build the separately matchable six-face exterior boundary request."""
native_g1g2_gridap_exterior_boundary_service_v1(
        plan::NativeG1G2GridapPlanV1, level::Integer) =
    _ng12_gridap_service_request_v1(plan, level,
        _NG12_EXTERIOR_BOUNDARY_SERVICE_V1)

"""Build the separately matchable, source-typed scalar-to-vector GRAD request."""
native_g1g2_gridap_grad_service_v1(
        plan::NativeG1G2GridapPlanV1, level::Integer) =
    _ng12_gridap_service_request_v1(plan, level, _NG12_GRAD_SERVICE_V1)

function _ng12_validate_service_input_v1(request::NativeG1G2GridapServiceRequestV1,
        expected_service::Symbol, expected_executor::Function;
        provider_candidates=(request.provider,))
    payload = request.solver_input.payload.materialized_payload
    plan = request.plan
    form = plan.compilation.form
    source = form.g2_declaration.source
    request.service === expected_service ||
        throw(ArgumentError("service request kind mismatch"))
    request.provider.executor === expected_executor ||
        throw(ArgumentError("service executor binding mismatch"))
    validate_native_g1g2_gridap_plan_v1(plan) ||
        throw(ArgumentError("service request plan validation failed"))
    request.plan_hash == plan.plan_hash == payload.plan_hash ||
        throw(ArgumentError("service plan binding mismatch"))
    request.level == payload.level ||
        throw(ArgumentError("service level binding mismatch"))
    canonical_hash(request.capability) == payload.capability_hash ||
        throw(ArgumentError("service capability binding mismatch"))
    request.provider.manifest_hash == payload.provider_manifest_hash ||
        throw(ArgumentError("service manifest binding mismatch"))
    request.solver_input.provider_manifest_hash == request.provider.manifest_hash ||
        throw(ArgumentError("service input/provider binding mismatch"))
    request.solver_input.physical_subject_hash == request.subject.physical_subject_hash ||
        throw(ArgumentError("service input/subject binding mismatch"))
    request.solver_input.input_schema_hash == request.capability.input_schema_hash ==
        request.provider.input_schema_hash ||
        throw(ArgumentError("service input schema binding mismatch"))
    request.provider.capability == request.capability ||
        throw(ArgumentError("service provider capability mismatch"))
    request.capability.applicability_bounds == request.provider.domain.bounds_hash ||
        throw(ArgumentError("service domain applicability mismatch"))
    matched = match_provider(request.capability, provider_candidates)
    matched.status == unique_match && matched.provider === request.provider ||
        throw(ArgumentError("service provider did not match its exact obligation"))
    canonical_hash(request.solver_input.payload.materialized_payload) ==
        canonical_hash(request.subject.materialized_payload) ||
        throw(ArgumentError("service input materialization mismatch"))
    payload.service_scope == "native-g1g2-gridap-service-input-v1" &&
        payload.service === expected_service &&
        payload.candidate_ref == form.candidate_ref &&
        payload.package_hash == form.t1_package_hash &&
        payload.semantic_identity == form.t1_semantic_identity &&
        payload.bundle_hash == form.t0_bundle_hash &&
        payload.g1_declaration_hash == form.g1_declaration.declaration_hash &&
        payload.g2_declaration_hash == form.g2_declaration.declaration_hash &&
        payload.g2_source_hash == source.source_hash &&
        payload.form_hash == form.form_hash &&
        payload.protocol_hash == plan.protocol.protocol_hash &&
        payload.dependency_hash == plan.dependency_identity.dependency_hash &&
        payload.adapter_source_hash == plan.adapter_source_hash &&
        1 <= payload.level <= 3 &&
        payload.cell_counts == plan.protocol.cell_counts[payload.level] &&
        payload.declared_mesh_quadrature_hash == canonical_hash((
            points=source.mesh.quadrature_points,
            weights=source.mesh.quadrature_weights)) &&
        payload.execution_quadrature_degree ==
            plan.protocol.quadrature_degree &&
        payload.input_schema_hash == request.capability.input_schema_hash &&
        payload.applicability_hash ==
            request.capability.applicability_bounds ||
        throw(ArgumentError("service payload plan/source identity mismatch"))
    expected = _ng12_gridap_service_request_v1(plan, request.level,
        expected_service)
    canonical_hash(expected.capability) == canonical_hash(request.capability) &&
        canonical_hash(expected.provider.domain) ==
            canonical_hash(request.provider.domain) &&
        expected.provider.manifest_hash == request.provider.manifest_hash &&
        expected.provider.executor === request.provider.executor &&
        request.provider.executor === expected_executor &&
        expected.subject.physical_subject_hash == request.subject.physical_subject_hash &&
        expected.solver_input.solver_input_hash ==
            request.solver_input.solver_input_hash ||
        throw(ArgumentError("service request does not match the exact factory result"))
    matched.provider
end

"""Return whether a service request exactly matches its admitted plan factory."""
function validate_native_g1g2_gridap_service_request_v1(
        request::NativeG1G2GridapServiceRequestV1)::Bool
    try
        executor = request.service === _NG12_CHART_MESH_SERVICE_V1 ?
            _ng12_gridap_chart_mesh_executor_v1 :
            request.service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 ?
            _ng12_gridap_exterior_boundary_executor_v1 :
            request.service === _NG12_GRAD_SERVICE_V1 ?
            _ng12_gridap_grad_executor_v1 : nothing
        executor === nothing && return false
        _ng12_validate_service_input_v1(request, request.service, executor)
        true
    catch
        false
    end
end

function _ng12_validate_service_payload_v1(input::SolverInputV4,
        plan::NativeG1G2GridapPlanV1, expected_service::Symbol)
    payload = input.payload.materialized_payload
    validate_native_g1g2_gridap_plan_v1(plan) ||
        throw(ArgumentError("service payload plan validation failed"))
    1 <= payload.level <= 3 ||
        throw(ArgumentError("service level is outside the frozen protocol"))
    form = plan.compilation.form
    source = form.g2_declaration.source
    payload.service === expected_service &&
        payload.plan_hash == plan.plan_hash &&
        payload.candidate_ref == form.candidate_ref &&
        payload.package_hash == form.t1_package_hash &&
        payload.semantic_identity == form.t1_semantic_identity &&
        payload.bundle_hash == form.t0_bundle_hash &&
        payload.g1_declaration_hash == form.g1_declaration.declaration_hash &&
        payload.g2_declaration_hash == form.g2_declaration.declaration_hash &&
        payload.g2_source_hash == source.source_hash &&
        payload.form_hash == form.form_hash &&
        payload.protocol_hash == plan.protocol.protocol_hash &&
        payload.dependency_hash == plan.dependency_identity.dependency_hash &&
        payload.adapter_source_hash == plan.adapter_source_hash &&
        payload.service_scope == "native-g1g2-gridap-service-input-v1" &&
        payload.cell_counts == plan.protocol.cell_counts[payload.level] &&
        payload.declared_mesh_quadrature_hash == canonical_hash((
            points=source.mesh.quadrature_points,
            weights=source.mesh.quadrature_weights)) &&
        payload.execution_quadrature_degree ==
            plan.protocol.quadrature_degree &&
        payload.input_schema_hash == input.input_schema_hash ||
        throw(ArgumentError("service payload plan/source identity mismatch"))
    expected = _ng12_gridap_service_request_v1(plan, payload.level,
        expected_service)
    expected.solver_input.solver_input_hash == input.solver_input_hash &&
        expected.provider.manifest_hash == input.provider_manifest_hash &&
        payload.capability_hash == canonical_hash(expected.capability) &&
        payload.applicability_hash ==
            expected.capability.applicability_bounds ||
        throw(ArgumentError("service payload does not match its plan factory"))
    plan
end

function _ng12_gridap_chart_mesh_executor_v1(input::SolverInputV4,
        plan::NativeG1G2GridapPlanV1)
    plan = _ng12_validate_service_payload_v1(input, plan,
        _NG12_CHART_MESH_SERVICE_V1)
    payload = input.payload.materialized_payload
    level = Int(payload.level)
    compilation = plan.compilation
    form = compilation.form
    source = form.g2_declaration.source
    cells = plan.protocol.cell_counts[level]
    source.mesh.basis === :Q1 ||
        throw(ArgumentError("Gridap chart/mesh service requires declared Q1 basis"))
    _ng12_cartesian_chart_supported_v1(source.chart_map) ||
        throw(ArgumentError("typed_absent: Gridap Cartesian route does not map this affine chart"))
    domain = _ng12_physical_domain(form)
    model = CartesianDiscreteModel(domain, cells)
    reffe = Gridap.ReferenceFEs.LagrangianRefFE(Float64,
        Gridap.ReferenceFEs.HEX, 1)
    omega = Triangulation(model)
    measure = Measure(omega, plan.protocol.quadrature_degree)
    NativeG1G2GridapChartMeshContextV1(
        _NG12_CHART_MESH_SERVICE_V1, input.solver_input_hash,
        input.provider_manifest_hash, plan.plan_hash,
        form.candidate_ref, form.t1_package_hash,
        form.g1_declaration.declaration_hash,
        form.g2_declaration.declaration_hash, form.form_hash, level, domain,
        cells, canonical_hash((points=source.mesh.quadrature_points,
            weights=source.mesh.quadrature_weights)),
        plan.protocol.quadrature_degree, model, reffe, omega, measure)
end

function _ng12_validate_chart_mesh_context_v1(
        plan::NativeG1G2GridapPlanV1,
        chart_mesh::NativeG1G2GridapChartMeshContextV1)
    expected = _ng12_gridap_service_request_v1(plan, chart_mesh.level,
        _NG12_CHART_MESH_SERVICE_V1)
    source = plan.compilation.form.g2_declaration.source
    domain = _ng12_physical_domain(plan.compilation.form)
    cells = plan.protocol.cell_counts[chart_mesh.level]
    chart_mesh.service === _NG12_CHART_MESH_SERVICE_V1 &&
        chart_mesh.service_input_hash == expected.solver_input.solver_input_hash &&
        chart_mesh.provider_manifest_hash == expected.provider.manifest_hash &&
        chart_mesh.plan_hash == plan.plan_hash &&
        chart_mesh.candidate_ref == plan.compilation.form.candidate_ref &&
        chart_mesh.package_hash == plan.compilation.form.t1_package_hash &&
        chart_mesh.g1_declaration_hash ==
            plan.compilation.form.g1_declaration.declaration_hash &&
        chart_mesh.g2_declaration_hash ==
            plan.compilation.form.g2_declaration.declaration_hash &&
        chart_mesh.form_hash == plan.compilation.form.form_hash &&
        chart_mesh.physical_domain == domain &&
        chart_mesh.cell_counts == cells &&
        chart_mesh.declared_mesh_quadrature_hash == canonical_hash((
            points=source.mesh.quadrature_points,
            weights=source.mesh.quadrature_weights)) &&
        chart_mesh.execution_quadrature_degree == plan.protocol.quadrature_degree ||
        throw(ArgumentError("chart/mesh context request binding mismatch"))
    chart_mesh.model isa CartesianDiscreteModel ||
        throw(ArgumentError("chart/mesh context model is not CartesianDiscreteModel"))
    descriptor = Gridap.Geometry.get_cartesian_descriptor(chart_mesh.model)
    descriptor.partition == cells && !any(descriptor.isperiodic) ||
        throw(ArgumentError("chart/mesh model topology mismatch"))
    scale = max(1.0, maximum(abs, domain))
    tolerance = 64 * eps(Float64) * scale
    all(isapprox(Float64(descriptor.origin[i]), domain[2i - 1];
            atol=tolerance, rtol=0.0) &&
        isapprox(Float64(descriptor.origin[i] +
            descriptor.sizes[i] * descriptor.partition[i]), domain[2i];
            atol=tolerance, rtol=0.0) &&
        isapprox(Float64(descriptor.sizes[i]),
            (domain[2i] - domain[2i - 1]) / cells[i];
            atol=tolerance, rtol=0.0) for i in 1:3) ||
        throw(ArgumentError("chart/mesh model physical bounds mismatch"))
    num_cells(chart_mesh.model) == prod(cells) ||
        throw(ArgumentError("chart/mesh model cell count mismatch"))
    chart_mesh.omega isa Triangulation &&
        get_background_model(chart_mesh.omega) === chart_mesh.model &&
        num_cells(chart_mesh.omega) == prod(cells) ||
        throw(ArgumentError("chart/mesh volume triangulation/model mismatch"))
    chart_mesh.reffe isa Gridap.ReferenceFEs.LagrangianRefFE{3} &&
        Gridap.ReferenceFEs.get_polytope(chart_mesh.reffe) ==
            Gridap.ReferenceFEs.HEX &&
        Gridap.ReferenceFEs.get_order(chart_mesh.reffe) == 1 ||
        throw(ArgumentError("chart/mesh reference element is not Q1"))
    actual_measure = chart_mesh.measure.quad
    expected_measure = Measure(chart_mesh.omega,
        plan.protocol.quadrature_degree).quad
    actual_rule = first(actual_measure.cell_quad)
    expected_rule = first(expected_measure.cell_quad)
    get_triangulation(actual_measure) === chart_mesh.omega &&
        Gridap.ReferenceFEs.get_coordinates(actual_rule) ==
            Gridap.ReferenceFEs.get_coordinates(expected_rule) &&
        Gridap.ReferenceFEs.get_weights(actual_rule) ==
            Gridap.ReferenceFEs.get_weights(expected_rule) ||
        throw(ArgumentError("chart/mesh quadrature measure binding mismatch"))
    true
end

function _ng12_gridap_boundary_face_projection_v1(boundary, domain, cells,
        faces, chart_map)
    axis_of(face) = face in (:x_min, :x_max) ? 1 :
        face in (:y_min, :y_max) ? 2 : 3
    side_of(face) = face in (:x_min, :y_min, :z_min) ? 1 : 2
    plane_of(face) = domain[2 * axis_of(face) - 2 + side_of(face)]
    expected_face_cells(face) = prod(cells[i] for i in 1:3
        if i != axis_of(face))
    face_names = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
    counts = Dict(face => 0 for face in face_names)
    total_expected = 2 * (cells[1] * cells[2] +
        cells[1] * cells[3] + cells[2] * cells[3])
    num_cells(boundary) == total_expected ||
        throw(ArgumentError("Gridap boundary triangulation cell count mismatch"))
    scale = max(1.0, maximum(abs, domain))
    tolerance = 64 * eps(Float64) * scale
    observed = 0
    for cell_vertices in get_cell_coordinates(boundary)
        matches = Symbol[]
        for face in face_names
            axis = axis_of(face)
            plane = Float64(plane_of(face))
            if all(vertex -> isapprox(Float64(vertex[axis]), plane;
                    atol=tolerance, rtol=0.0), cell_vertices)
                push!(matches, face)
            end
        end
        length(matches) == 1 ||
            throw(ArgumentError("Gridap boundary cell does not project to exactly one typed face"))
        for vertex in cell_vertices, axis in 1:3
            lo, hi = domain[2 * axis - 1], domain[2 * axis]
            lo - tolerance <= vertex[axis] <= hi + tolerance ||
                throw(ArgumentError("Gridap boundary vertex is outside the physical chart bounds"))
        end
        counts[only(matches)] += 1
        observed += 1
    end
    observed == total_expected ||
        throw(ArgumentError("Gridap boundary projection is incomplete"))
    all(counts[face] == expected_face_cells(face) for face in face_names) ||
        throw(ArgumentError("Gridap boundary face projection coverage mismatch"))
    Tuple((face_id=face.face_id, face=face.face,
        owner_region_id=face.owner_region_id,
        reference_normal=face.reference_normal, kind=face.value.kind,
        value=Float64(face.value.value), unit=face.value.unit,
        physical_plane_coordinate=Float64(plane_of(face.face)),
        physical_oriented_area_vector=Tuple(Float64.(
            FusionConceptAI.g2mb_physical_oriented_area_vector(chart_map,
                face.reference_normal))),
        projected_gridap_boundary_cells=counts[face.face],
        expected_gridap_boundary_cells=expected_face_cells(face.face),
        gridap_dirichlet_tag="boundary") for face in faces)
end

function _ng12_gridap_exterior_boundary_executor_v1(
        input::SolverInputV4, chart_mesh::NativeG1G2GridapChartMeshContextV1,
        plan::NativeG1G2GridapPlanV1)
    payload = input.payload.materialized_payload
    plan = _ng12_validate_service_payload_v1(input, plan,
        _NG12_EXTERIOR_BOUNDARY_SERVICE_V1)
    compilation = plan.compilation
    form = compilation.form
    source = form.g2_declaration.source
    input.provider_manifest_hash == payload.provider_manifest_hash &&
        _ng12_validate_chart_mesh_context_v1(plan, chart_mesh) ||
        throw(ArgumentError("exterior boundary/chart-mesh identity mismatch"))
    faces = source.faces
    length(faces) == 6 ||
        throw(ArgumentError("exterior boundary service requires six typed faces"))
    expected = Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
    Set(face.face for face in faces) == expected ||
        throw(ArgumentError("exterior boundary service face coverage mismatch"))
    all(face.value.kind === :dirichlet && iszero(face.value.value) for face in faces) ||
        throw(ArgumentError("exterior boundary service requires zero Dirichlet data"))
    all(face.ownership === :candidate_owned for face in faces) ||
        throw(ArgumentError("exterior boundary service requires candidate-owned faces"))
    all(face.reference_normal == _ng12_gridap_expected_reference_normal(face.face)
        for face in faces) ||
        throw(ArgumentError("exterior boundary service reference normal mismatch"))
    boundary = BoundaryTriangulation(chart_mesh.model)
    get_background_model(boundary) === chart_mesh.model ||
        throw(ArgumentError("Gridap boundary triangulation/model mismatch"))
    owners = _ng12_gridap_boundary_face_projection_v1(boundary,
        chart_mesh.physical_domain, chart_mesh.cell_counts, faces,
        source.chart_map)
    test_space = TestFESpace(chart_mesh.model, chart_mesh.reffe;
        conformity=:H1, dirichlet_tags="boundary")
    trial_space = TrialFESpace(test_space, x -> 0.0)
    boundary_measure = Measure(boundary, plan.protocol.quadrature_degree)
    boundary_normal = get_normal_vector(boundary)
    NativeG1G2GridapExteriorBoundaryContextV1(
        _NG12_EXTERIOR_BOUNDARY_SERVICE_V1, input.solver_input_hash,
        input.provider_manifest_hash, plan.plan_hash,
        form.candidate_ref, form.t1_package_hash,
        form.g1_declaration.declaration_hash,
        form.g2_declaration.declaration_hash, form.form_hash,
        Int(payload.level), chart_mesh.service_input_hash,
        canonical_hash(faces), owners, "boundary", 0.0, test_space,
        trial_space, boundary, boundary_measure, boundary_normal)
end

function _ng12_gridap_grad_executor_v1(input::SolverInputV4,
        chart_mesh::NativeG1G2GridapChartMeshContextV1,
        boundary_service::NativeG1G2GridapExteriorBoundaryContextV1,
        solution, free_values, plan::NativeG1G2GridapPlanV1)
    plan = _ng12_validate_service_payload_v1(input, plan,
        _NG12_GRAD_SERVICE_V1)
    form = plan.compilation.form
    payload = input.payload.materialized_payload
    _ng12_validate_chart_mesh_context_v1(plan, chart_mesh) ||
        throw(ArgumentError("GRAD service chart/mesh context mismatch"))
    boundary_request = native_g1g2_gridap_exterior_boundary_service_v1(
        plan, payload.level)
    boundary_service.service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1 &&
        boundary_service.service_input_hash ==
            boundary_request.solver_input.solver_input_hash &&
        boundary_service.provider_manifest_hash ==
            boundary_request.provider.manifest_hash &&
        boundary_service.plan_hash == plan.plan_hash &&
        boundary_service.candidate_ref == form.candidate_ref &&
        boundary_service.package_hash == form.t1_package_hash &&
        boundary_service.g1_declaration_hash ==
            form.g1_declaration.declaration_hash &&
        boundary_service.g2_declaration_hash ==
            form.g2_declaration.declaration_hash &&
        boundary_service.form_hash == form.form_hash &&
        boundary_service.level == payload.level &&
        boundary_service.chart_mesh_input_hash == chart_mesh.service_input_hash ||
        throw(ArgumentError("GRAD service boundary/trial-space context mismatch"))
    grad = form.g1_declaration.operators.grad
    grad.operator_ref.id == G1_DIFFUSION_GRAD_OPERATOR_ID_V1 &&
        grad.operator_ref.version == "v1" &&
        grad.input_field_id == form.g1_declaration.u.field_id &&
        grad.output_field_id ==
            form.g1_declaration.operators.coefficient_apply.input_field_id ||
        throw(ArgumentError("GRAD service source endpoint binding mismatch"))
    Gridap.FESpaces.get_fe_space(solution) ===
        boundary_service.trial_space ||
        throw(ArgumentError("GRAD service solution does not belong to the candidate trial space"))
    solution_values = Gridap.FESpaces.get_free_dof_values(solution)
    length(free_values) == num_free_dofs(boundary_service.trial_space) &&
        Tuple(solution_values) == Tuple(free_values) &&
        all(isfinite, solution_values) ||
        throw(ArgumentError("GRAD service free values differ from the candidate solution"))
    gradient_field = ∇(solution)
    domain = chart_mesh.physical_domain
    probe = ntuple(i -> domain[2i - 1] +
        (domain[2i] - domain[2i - 1]) /
            (2 * chart_mesh.cell_counts[i]), 3)
    gradient_value = Tuple(gradient_field(Point(probe...)))
    length(gradient_value) == 3 && all(isfinite, gradient_value) ||
        throw(ArgumentError("GRAD service did not produce a finite 3-D vector field"))
    (plan_hash=plan.plan_hash,
        service_input_hash=input.solver_input_hash,
        provider_manifest_hash=input.provider_manifest_hash,
        level=payload.level, candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        form_hash=form.form_hash,
        chart_mesh_input_hash=chart_mesh.service_input_hash,
        boundary_service_input_hash=boundary_service.service_input_hash,
        solution_hash=canonical_hash(free_values), gradient_field)
end

function _ng12_execute_gridap_service_v1(
        request::NativeG1G2GridapServiceRequestV1, expected_service::Symbol,
        expected_executor::Function, args...;
        provider_candidates=(request.provider,))
    plan = request.plan
    FusionConceptAI._with_canonical_json_memo(plan.compilation;
        payload_targets=_ng12_canonical_payload_targets_v1(plan.compilation)) do
        selected_provider = _ng12_validate_service_input_v1(request,
            expected_service, expected_executor; provider_candidates)
        result = selected_provider.executor(request.solver_input, args..., plan)
        result.plan_hash == request.plan_hash &&
            result.service_input_hash == request.solver_input.solver_input_hash &&
            result.provider_manifest_hash == request.provider.manifest_hash &&
            result.level == request.level ||
            throw(ArgumentError("service result binding mismatch"))
        form = plan.compilation.form
        result.candidate_ref == form.candidate_ref &&
            result.package_hash == form.t1_package_hash &&
            result.g1_declaration_hash == form.g1_declaration.declaration_hash &&
            result.g2_declaration_hash == form.g2_declaration.declaration_hash &&
            result.form_hash == form.form_hash ||
            throw(ArgumentError("service candidate/source result binding mismatch"))
        if expected_service === _NG12_EXTERIOR_BOUNDARY_SERVICE_V1
            length(args) == 1 && args[1] isa NativeG1G2GridapChartMeshContextV1 &&
                result.chart_mesh_input_hash == args[1].service_input_hash ||
                throw(ArgumentError("boundary result chart/mesh binding mismatch"))
        elseif expected_service === _NG12_GRAD_SERVICE_V1
            length(args) == 4 &&
                args[1] isa NativeG1G2GridapChartMeshContextV1 &&
                args[2] isa NativeG1G2GridapExteriorBoundaryContextV1 &&
                result.chart_mesh_input_hash == args[1].service_input_hash &&
                result.boundary_service_input_hash ==
                    args[2].service_input_hash &&
                result.solution_hash == canonical_hash(args[4]) ||
                throw(ArgumentError("GRAD result field/mesh binding mismatch"))
        end
        result
    end
end

function _ng12_build_gridap_native_g1g2_plan_v1(
        result::NativeG1G2DiffusionCompileResultV1,
        protocol::NativeG1G2NumericalProtocolV1)
    FusionConceptAI._with_canonical_json_memo(result.compilation;
        payload_targets=_ng12_canonical_payload_targets_v1(result.compilation)) do
    result.status === :compiled_numerical_preparation &&
    result.compilation !== nothing && isempty(result.errors) ||
        throw(ArgumentError("native G1/G2 compilation is not executable"))
    _ng12_stage_v1("adapter_compile_result_hash_begin")
    result_integrity_hash = canonical_hash(_ng12_compile_result_body(result.status,
        result.resolution, result.accepted, result.claim_ceiling,
        result.compilation, result.errors, result.gaps))
    _ng12_stage_v1("adapter_compile_result_hash_complete")
    result_integrity_hash == result.result_hash ||
        throw(ArgumentError("compile result integrity mismatch"))
    compilation = result.compilation
    _ng12_validate_compilation_with_admission_v1(compilation) ||
        throw(ArgumentError("compilation integrity or admission mismatch"))
    _ng12_protocol_integrity(protocol) ||
        throw(ArgumentError("numerical protocol integrity mismatch"))
    expected_protocol = native_g1g2_numerical_protocol_v1(
        compilation.form.g2_declaration.source.mesh.cells;
        tensor_coefficients=_ng12_tensor_budget_coefficients_v1(
            compilation.form.g1_declaration.K.expression))
    canonical_json(protocol) == canonical_json(expected_protocol) ||
        throw(ArgumentError("frozen limited-v1 error budget does not apply to candidate form"))
    _ng12_error_budget_applies(compilation.form, protocol) ||
        throw(ArgumentError(
            "frozen limited-v1 error budget does not apply to candidate form"))
    dependency = _gridap_dependency_identity()
    adapter_hash = native_g1g2_gridap_adapter_source_hash_v1()
    provider = native_g1g2_gridap_provider_v1(compilation, protocol,
        dependency, adapter_hash)
    materialized = (compilation=compilation,
        compile_result_hash=result.result_hash, protocol=protocol,
        dependency_identity=dependency, adapter_source_hash=adapter_hash,
        execution_scope=:numerical_preparation,
        formal_t2_receipt_assignment=false)
    subject = ExecutablePhysicalSubjectV4(
        compilation.subject.compiled_prefix_hash,
        compilation.subject.genome_bundle_hash,
        compilation.subject.mission_hash,
        compilation.subject.bounds_hash,
        compilation.subject.bindings, compilation.subject.scenarios,
        materialized, (compilation.capability,))
    solver_input = compile_solver_input(subject, compilation.scenario,
        compilation.capability, provider)
    body = _ng12_gridap_plan_body(compilation, result.result_hash,
        protocol, dependency, provider, subject, solver_input, adapter_hash)
    plan = NativeG1G2GridapPlanV1(compilation, result.result_hash,
        protocol, dependency, provider, subject, solver_input, adapter_hash,
        canonical_hash(body))
    plan
    end
end

function stage_gridap_native_g1g2_diffusion_v1(
        result::NativeG1G2DiffusionCompileResultV1,
        protocol::NativeG1G2NumericalProtocolV1=
            native_g1g2_numerical_protocol_v1())
    plan = _ng12_build_gridap_native_g1g2_plan_v1(result, protocol)
    NativeG1G2GridapStagedPlanV1(plan, :plan_validation_deferred,
        :not_executed, false)
end

function prepare_gridap_native_g1g2_diffusion_v1(
        result::NativeG1G2DiffusionCompileResultV1,
        protocol::NativeG1G2NumericalProtocolV1=
            native_g1g2_numerical_protocol_v1())
    _ng12_stage_v1("adapter_plan_prepare_begin")
    FusionConceptAI._with_canonical_json_memo(result.compilation;
        payload_targets=_ng12_canonical_payload_targets_v1(result.compilation)) do
        plan = _ng12_build_gridap_native_g1g2_plan_v1(result, protocol)
        _ng12_stage_v1("adapter_plan_build_complete")
        _ng12_stage_v1("adapter_plan_validation_begin")
        validate_native_g1g2_gridap_plan_v1(plan) ||
            throw(ArgumentError("Gridap native G1/G2 plan integrity mismatch"))
        _ng12_stage_v1("adapter_plan_validation_complete")
        plan
    end
end

"""Candidate-bound raw scalar Q1 state and topology exported by the real Gridap solve.

The current G1/G2 producer has one scalar `u` field.  The explicit component
inventory keeps that fact in the result; it is not vector or multifield
coverage.  This process-local Gridap path is serial, so its halo inventory is
explicitly empty.  UP2's transfer consumer must pair a source report state
with a separately materialized and T0/T1-compiled G2 edit child state and its
source-edit relation.  A later refinement level inside this same report is
not an edited G2 child and cannot stand in for one.
"""
struct NativeG1G2Q1FieldStateV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    semantic_identity::Digest256
    t0_bundle_hash::Digest256
    plan_hash::Digest256
    g1_declaration_hash::Digest256
    g2_declaration_hash::Digest256
    g2_source_ref::QualifiedRefV1
    g2_source_hash::Digest256
    g2_mesh_ref::QualifiedRefV1
    g2_chart_ref::QualifiedRefV1
    source_sign::Symbol
    level::Int
    cell_counts::NTuple{3,Int}
    physical_domain::NTuple{6,Float64}
    mesh_hash::Digest256
    component_field_ids::Tuple{Vararg{String}}
    component_units::Tuple{Vararg{UnitSignature}}
    component_orientations::Tuple{Vararg{Symbol}}
    component_dof_values::Tuple
    dof_coordinates::Tuple{Vararg{NTuple{3,Float64}}}
    cell_dof_ids::Tuple
    cell_dof_coordinates::Tuple
    free_to_full::Tuple{Vararg{Int}}
    boundary_to_full::Tuple{Vararg{Int}}
    face_owners::Tuple
    face_dof_full_ids::Tuple
    g2_entity_ownership::NamedTuple
    cell_owner_domain::Symbol
    cell_owner_refs::Tuple{Vararg{String}}
    partition_count::Int
    halo_status::Symbol
    halo_owner_refs::Tuple{Vararg{String}}
    state_hash::Digest256
end

function _ng12_q1_field_state_body(candidate_ref, package_hash,
        semantic_identity, t0_bundle_hash, plan_hash, g1_declaration_hash,
        g2_declaration_hash, g2_source_ref, g2_source_hash, g2_mesh_ref,
        g2_chart_ref, source_sign, level, cell_counts,
        physical_domain, mesh_hash, component_field_ids, component_units,
        component_orientations,
        component_dof_values, dof_coordinates, cell_dof_ids,
        cell_dof_coordinates, free_to_full, boundary_to_full, face_owners,
        face_dof_full_ids, g2_entity_ownership, cell_owner_domain,
        cell_owner_refs, partition_count, halo_status,
        halo_owner_refs)
    (domain="native-g1g2-q1-field-state-v2-region-map", candidate_ref=candidate_ref,
        package_hash=package_hash, semantic_identity=semantic_identity,
        t0_bundle_hash=t0_bundle_hash, plan_hash=plan_hash,
        g1_declaration_hash=g1_declaration_hash,
        g2_declaration_hash=g2_declaration_hash,
        g2_source_ref=g2_source_ref, g2_source_hash=g2_source_hash,
        g2_mesh_ref=g2_mesh_ref, g2_chart_ref=g2_chart_ref,
        source_sign=source_sign, level=level, cell_counts=cell_counts,
        physical_domain=physical_domain,
        mesh_hash=mesh_hash,
        component_field_ids=component_field_ids,
        component_units=component_units,
        component_orientations=component_orientations,
        component_dof_values=component_dof_values,
        dof_coordinates=dof_coordinates, cell_dof_ids=cell_dof_ids,
        cell_dof_coordinates=cell_dof_coordinates,
        free_to_full=free_to_full, boundary_to_full=boundary_to_full,
        face_owners=face_owners, face_dof_full_ids=face_dof_full_ids,
        g2_entity_ownership=g2_entity_ownership,
        cell_owner_domain=cell_owner_domain, cell_owner_refs=cell_owner_refs,
        partition_count=partition_count, halo_status=halo_status,
        halo_owner_refs=halo_owner_refs)
end

function _ng12_q1_field_state_body(state::NativeG1G2Q1FieldStateV1)
    _ng12_q1_field_state_body(state.candidate_ref, state.package_hash,
        state.semantic_identity, state.t0_bundle_hash, state.plan_hash,
        state.g1_declaration_hash, state.g2_declaration_hash,
        state.g2_source_ref, state.g2_source_hash, state.g2_mesh_ref,
        state.g2_chart_ref, state.source_sign, state.level, state.cell_counts,
        state.physical_domain, state.mesh_hash, state.component_field_ids,
        state.component_units, state.component_orientations,
        state.component_dof_values, state.dof_coordinates, state.cell_dof_ids,
        state.cell_dof_coordinates, state.free_to_full, state.boundary_to_full,
        state.face_owners, state.face_dof_full_ids, state.g2_entity_ownership,
        state.cell_owner_domain, state.cell_owner_refs, state.partition_count,
        state.halo_status, state.halo_owner_refs)
end

semantic_view(state::NativeG1G2Q1FieldStateV1) = merge(
    _ng12_q1_field_state_body(state), (state_hash=state.state_hash,))

function _ng12_q1_field_state_valid(state::NativeG1G2Q1FieldStateV1)
    try
        body = _ng12_q1_field_state_body(state.candidate_ref,
            state.package_hash, state.semantic_identity, state.t0_bundle_hash,
            state.plan_hash, state.g1_declaration_hash,
            state.g2_declaration_hash, state.g2_source_ref,
            state.g2_source_hash, state.g2_mesh_ref, state.g2_chart_ref,
            state.source_sign, state.level,
            state.cell_counts, state.physical_domain, state.mesh_hash,
            state.component_field_ids, state.component_units,
            state.component_orientations,
            state.component_dof_values, state.dof_coordinates,
            state.cell_dof_ids, state.cell_dof_coordinates,
            state.free_to_full, state.boundary_to_full, state.face_owners,
            state.face_dof_full_ids, state.g2_entity_ownership,
            state.cell_owner_domain, state.cell_owner_refs, state.partition_count,
            state.halo_status, state.halo_owner_refs)
        length(state.component_field_ids) == 1 &&
        length(state.component_field_ids) == length(state.component_units) ==
            length(state.component_dof_values) &&
        all(length(values) == length(state.dof_coordinates)
            for values in state.component_dof_values) &&
        state.component_orientations == (:scalar_invariant,) &&
        state.source_sign in (:declared, :reversed_test_control) &&
        length(state.cell_dof_ids) == prod(state.cell_counts) ==
            length(state.cell_dof_coordinates) ==
            length(state.cell_owner_refs) &&
        all(length(ids) == 8 for ids in state.cell_dof_ids) &&
        all(length(coords) == 8 for coords in state.cell_dof_coordinates) &&
        all(isfinite, Iterators.flatten(state.component_dof_values)) &&
        all(point -> all(isfinite, point), state.dof_coordinates) &&
        all(all(1 <= id <= length(state.dof_coordinates)
            for id in ids) && Tuple(state.dof_coordinates[id] for id in ids) ==
            state.cell_dof_coordinates[cell]
            for (cell, ids) in enumerate(state.cell_dof_ids)) &&
        length(state.free_to_full) + length(state.boundary_to_full) ==
            length(state.dof_coordinates) &&
        sort(vcat(collect(state.free_to_full),
            collect(state.boundary_to_full))) ==
            collect(1:length(state.dof_coordinates)) &&
        length(state.face_owners) == 6 &&
        Set(face.face for face in state.face_owners) ==
            Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)) &&
        Set(face.face for face in state.face_dof_full_ids) ==
            Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)) &&
        all(all(id in state.boundary_to_full for id in face.dof_full_ids) &&
            all(isapprox(state.dof_coordinates[id][
                face.face in (:x_min,:x_max) ? 1 :
                face.face in (:y_min,:y_max) ? 2 : 3],
                face.physical_plane_coordinate; atol=1e-12, rtol=0.0)
                for id in face.dof_full_ids)
            for face in state.face_dof_full_ids) &&
        all(face.kind === :dirichlet && iszero(face.value)
            for face in state.face_owners) &&
        all(iszero(state.component_dof_values[1][id])
            for id in state.boundary_to_full) &&
        state.g2_entity_ownership.status in (:mapped, :typed_absent) &&
        state.cell_owner_domain === :process_partition &&
        all(==("serial-process:0"), state.cell_owner_refs) &&
        state.mesh_hash == canonical_hash((
            domain="native-g1g2-q1-space-v2-region-map",
            cell_counts=state.cell_counts,
            physical_domain=state.physical_domain,
            dof_coordinates=state.dof_coordinates,
            cell_dof_ids=state.cell_dof_ids,
            face_owners=state.face_owners,
            face_dof_full_ids=state.face_dof_full_ids,
            g2_entity_ownership=state.g2_entity_ownership,
            cell_owner_domain=state.cell_owner_domain,
            cell_owner_refs=state.cell_owner_refs)) &&
        state.partition_count == 1 &&
        state.halo_status === :single_rank_empty &&
        isempty(state.halo_owner_refs) &&
        canonical_hash(body) == state.state_hash
    catch
        false
    end
end

function _ng12_g2_entity_ownership_v1(source, cell_counts, dof_coordinates, cell_dof_ids)
    partition = source.region_interface
    partition === nothing && return (status=:typed_absent,
        reason=:g2_region_interface_missing, regions=(), physical_regions=(),
        interfaces=(), cell_owners=(), interface_maps=(),
        exterior_source_rows=(), exterior_maps=())
    regions = partition.regions
    interfaces = partition.interfaces
    chart = source.chart_map
    if !_ng12_cartesian_chart_supported_v1(chart)
        return (status=:typed_absent, reason=:native_cartesian_affine_chart_unsupported,
            regions=Tuple(semantic_view(r) for r in partition.regions),
            physical_regions=(), interfaces=Tuple(semantic_view(i) for i in partition.interfaces),
            cell_owners=(), interface_maps=(),
            exterior_source_rows=source.region_exterior_owners === nothing ? () :
                Tuple((face=row.face, owner_region_id=row.owner_region_id)
                    for row in source.region_exterior_owners),
            exterior_maps=())
    end
    physical_box(region) = begin
        lo = Tuple(Float64.(Tuple(FusionConceptAI.g2mb_chart_map(chart, region.lower))))
        hi = Tuple(Float64.(Tuple(FusionConceptAI.g2mb_chart_map(chart, region.upper))))
        (lower=lo, upper=hi)
    end
    boxes = Tuple((region_id=r.region_id, lower=physical_box(r).lower,
        upper=physical_box(r).upper) for r in regions)
    scale = max(1.0, maximum(abs, (coordinate for box in boxes for axis in 1:3 for coordinate in (box.lower[axis], box.upper[axis]))))
    tol = 64 * eps(Float64) * scale
    cell_bounds = Tuple((lower=ntuple(a -> minimum(dof_coordinates[id][a]
        for id in ids), 3), upper=ntuple(a -> maximum(dof_coordinates[id][a]
        for id in ids), 3)) for ids in cell_dof_ids)
    cell_owners = Tuple(begin
        matches = Tuple(box.region_id for box in boxes if all(
            box.lower[a] - tol <= cell_bounds[i].lower[a] &&
            cell_bounds[i].upper[a] <= box.upper[a] + tol for a in 1:3))
        (cell_index=i, status=length(matches) == 1 ? :mapped : :typed_absent,
         owner_region_id=length(matches) == 1 ? only(matches) : nothing,
         reason=length(matches) == 1 ? :inside_one_source_region :
             :cell_crosses_or_misses_source_region_interface)
    end for i in eachindex(cell_dof_ids))
    interface_maps = Tuple(begin
        axis = Int(iface.axis)
        chart_point = ntuple(a -> a == axis ? iface.coordinate : chart.domain_lower[a], 3)
        physical_coordinate = Float64(FusionConceptAI.g2mb_chart_map(chart, chart_point)[axis])
        left_ids = Tuple(i for i in eachindex(cell_owners) if
            cell_owners[i].status === :mapped &&
            cell_owners[i].owner_region_id == iface.left_region_id)
        right_ids = Tuple(i for i in eachindex(cell_owners) if
            cell_owners[i].status === :mapped &&
            cell_owners[i].owner_region_id == iface.right_region_id)
        expected_pairs = prod(cell_counts[a] for a in 1:3 if a != axis)
        left_by_face = Dict{NTuple{4,Int},Int}()
        invalid_face_key = false
        for li in left_ids
            isapprox(cell_bounds[li].upper[axis], physical_coordinate;
                atol=tol, rtol=0.0) || continue
            on_face = sort!(Int[id for id in cell_dof_ids[li]
                if isapprox(dof_coordinates[id][axis], physical_coordinate;
                    atol=tol, rtol=0.0)])
            if length(on_face) != 4
                invalid_face_key = true
                continue
            end
            key = ntuple(j -> on_face[j], 4)
            if haskey(left_by_face, key)
                invalid_face_key = true
            else
                left_by_face[key] = li
            end
        end
        mapped_pairs = NamedTuple[]
        for ri in right_ids
            isapprox(cell_bounds[ri].lower[axis], physical_coordinate;
                atol=tol, rtol=0.0) || continue
            on_face = sort!(Int[id for id in cell_dof_ids[ri]
                if isapprox(dof_coordinates[id][axis], physical_coordinate;
                    atol=tol, rtol=0.0)])
            if length(on_face) != 4
                invalid_face_key = true
                continue
            end
            key = ntuple(j -> on_face[j], 4)
            li = get(left_by_face, key, 0)
            li == 0 && continue
            push!(mapped_pairs, (left_cell_index=li, right_cell_index=ri,
                interface_dof_ids=key))
        end
        sort!(mapped_pairs; by=pair -> (pair.left_cell_index, pair.right_cell_index))
        mapped_pairs = Tuple(mapped_pairs)
        reference_normal = ntuple(a -> a == axis ? Int8(iface.normal) : Int8(0), 3)
        (interface_ref=iface.interface_ref, left_region_id=iface.left_region_id,
         right_region_id=iface.right_region_id, axis=axis,
         chart_coordinate=iface.coordinate, physical_coordinate=physical_coordinate,
         reference_normal=reference_normal,
         physical_oriented_area_vector=Tuple(Float64.(
             FusionConceptAI.g2mb_physical_oriented_area_vector(chart, reference_normal))),
         continuity=iface.continuity,
         transfer_kind=iface.transfer_kind,
         status=!invalid_face_key && length(left_by_face) == expected_pairs &&
             length(mapped_pairs) == expected_pairs ? :mapped : :typed_absent,
         reason=!invalid_face_key && length(left_by_face) == expected_pairs &&
             length(mapped_pairs) == expected_pairs ? :mesh_faces_match_source_interface :
             :source_interface_not_mesh_aligned,
         expected_face_count=expected_pairs, mapped_faces=mapped_pairs)
    end for iface in interfaces)
    exterior_rows = source.region_exterior_owners === nothing ? () :
        source.region_exterior_owners
    exterior_source_rows = Tuple((face=row.face, owner_region_id=row.owner_region_id)
        for row in exterior_rows)
    exterior_maps = Tuple(begin
        face = row.face
        axis = face in (:x_min, :x_max) ? 1 : face in (:y_min, :y_max) ? 2 : 3
        lower_side = face in (:x_min, :y_min, :z_min)
        plane = lower_side ? source.chart_map.domain_lower[axis] :
            source.chart_map.domain_upper[axis]
        point = ntuple(a -> a == axis ? plane : source.chart_map.domain_lower[a], 3)
        physical_plane = Float64(FusionConceptAI.g2mb_chart_map(chart, point)[axis])
        box = only(filter(b -> b.region_id == row.owner_region_id, boxes))
        face_cells = Tuple(i for i in eachindex(cell_bounds) if
            isapprox(cell_bounds[i].lower[axis], physical_plane; atol=tol, rtol=0.0) ||
            isapprox(cell_bounds[i].upper[axis], physical_plane; atol=tol, rtol=0.0))
        # A cell belongs to this physical face patch only if it intersects the
        # authored region with positive tangential area. Partial intersections
        # are recorded as absent instead of being assigned by their midpoint.
        touched = Tuple(i for i in eachindex(cell_bounds) if begin
            bounds = cell_bounds[i]
            on_plane = isapprox(bounds.lower[axis], physical_plane; atol=tol, rtol=0.0) ||
                isapprox(bounds.upper[axis], physical_plane; atol=tol, rtol=0.0)
            on_plane && all(min(bounds.upper[a], box.upper[a]) -
                max(bounds.lower[a], box.lower[a]) > tol for a in 1:3 if a != axis)
        end)
        mapped = Tuple(i for i in touched if all(
            box.lower[a] - tol <= cell_bounds[i].lower[a] &&
            cell_bounds[i].upper[a] <= box.upper[a] + tol for a in 1:3 if a != axis))
        source_face = only(filter(f -> f.face === face, source.faces))
        (face=face, owner_region_id=row.owner_region_id,
         source_face_id=source_face.face_id,
         reference_normal=source_face.reference_normal,
         physical_oriented_area_vector=Tuple(Float64.(
             FusionConceptAI.g2mb_physical_oriented_area_vector(chart,
                 source_face.reference_normal))),
         physical_plane_coordinate=physical_plane,
         status=length(mapped) == length(touched) ? :mapped : :typed_absent,
         reason=length(mapped) == length(touched) ? :surface_cells_match_source_region_owner :
             :surface_cell_crosses_source_region_boundary,
         source_face_cell_count=length(face_cells), mapped_cell_indices=mapped,
         unmapped_intersecting_cell_indices=Tuple(i for i in touched if !(i in mapped)))
    end for row in exterior_rows)
    status = length(regions) == 2 && length(interfaces) == 1 &&
        length(exterior_source_rows) == 10 &&
        all(x.status === :mapped for x in cell_owners) &&
        all(x.status === :mapped for x in interface_maps) &&
        length(exterior_maps) == length(exterior_source_rows) &&
        all(x.status === :mapped for x in exterior_maps) ? :mapped : :typed_absent
    (status=status, reason=status === :mapped ? :all_g2_entities_projected_to_mesh :
        :g2_mesh_does_not_resolve_all_source_regions_and_owners,
     regions=Tuple(semantic_view(r) for r in regions),
     physical_regions=boxes,
     interfaces=Tuple(semantic_view(i) for i in interfaces),
     cell_owners=cell_owners, interface_maps=interface_maps,
     exterior_source_rows=exterior_source_rows, exterior_maps=exterior_maps)
end

function _ng12_q1_field_state_v1(plan, level, source_sign, full_values,
        full_test_space, dof_partition, boundary_service, chart_mesh)
    form = plan.compilation.form
    coords, dirichlet_coords =
        Gridap.FESpaces.get_free_and_dirichlet_dof_coordinates(full_test_space)
    isempty(dirichlet_coords) ||
        throw(ArgumentError("unconstrained full Q1 space has Dirichlet coordinates"))
    dof_coordinates = Tuple(Tuple(Float64.(Tuple(p))) for p in coords)
    length(dof_coordinates) == length(full_values) ||
        throw(ArgumentError("full Q1 DOF coordinate/value inventory mismatch"))
    cell_dof_ids = Tuple(Tuple(Int(id) for id in ids)
        for ids in get_cell_dof_ids(full_test_space))
    cell_dof_coordinates = Tuple(Tuple(dof_coordinates[id] for id in ids)
        for ids in cell_dof_ids)
    face_dof_full_ids = Tuple((face_id=face.face_id, face=face.face,
        owner_region_id=face.owner_region_id,
        physical_plane_coordinate=face.physical_plane_coordinate,
        dof_full_ids=Tuple(i for i in eachindex(dof_coordinates)
            if isapprox(dof_coordinates[i][
                face.face in (:x_min,:x_max) ? 1 :
                face.face in (:y_min,:y_max) ? 2 : 3],
                face.physical_plane_coordinate; atol=1e-12, rtol=0.0)))
        for face in boundary_service.face_owners)
    g2_entity_ownership = _ng12_g2_entity_ownership_v1(
        form.g2_declaration.source, chart_mesh.cell_counts, dof_coordinates, cell_dof_ids)
    component_field_ids = (form.g1_declaration.u.field_id,)
    component_units = (form.g1_declaration.u.physical_type.units,)
    component_orientations = (:scalar_invariant,)
    component_dof_values = (Tuple(Float64.(full_values)),)
    cell_owner_refs = Tuple("serial-process:0" for _ in cell_dof_ids)
    partition_count = 1
    halo_status = :single_rank_empty
    halo_owner_refs = ()
    mesh_hash = canonical_hash((domain="native-g1g2-q1-space-v2-region-map",
        cell_counts=chart_mesh.cell_counts,
        physical_domain=chart_mesh.physical_domain,
        dof_coordinates=dof_coordinates, cell_dof_ids=cell_dof_ids,
        face_owners=boundary_service.face_owners,
        face_dof_full_ids=face_dof_full_ids,
        g2_entity_ownership=g2_entity_ownership,
        cell_owner_domain=:process_partition,
        cell_owner_refs=cell_owner_refs))
    args = (form.candidate_ref, form.t1_package_hash,
        form.t1_semantic_identity, form.t0_bundle_hash, plan.plan_hash,
        form.g1_declaration.declaration_hash,
        form.g2_declaration.declaration_hash,
        form.g2_declaration.source.source_ref,
        form.g2_declaration.source.source_hash,
        form.g2_declaration.source.mesh.mesh_ref,
        form.g2_declaration.source.chart_map.chart_ref, source_sign, Int(level),
        chart_mesh.cell_counts, chart_mesh.physical_domain, mesh_hash,
        component_field_ids, component_units, component_orientations,
        component_dof_values,
        dof_coordinates, cell_dof_ids, cell_dof_coordinates,
        Tuple(dof_partition.free_to_full),
        Tuple(dof_partition.boundary_to_full), boundary_service.face_owners,
        face_dof_full_ids, g2_entity_ownership, :process_partition,
        cell_owner_refs, partition_count, halo_status, halo_owner_refs)
    body = _ng12_q1_field_state_body(args...)
    NativeG1G2Q1FieldStateV1(args..., canonical_hash(body))
end

struct NativeG1G2GridapLevelResultV1
    level::Int
    cell_counts::NTuple{3,Int}
    physical_domain::NTuple{6,Float64}
    cells::Int
    free_dofs::Int
    dirichlet_dofs::Int
    matrix_shape::NTuple{2,Int}
    matrix_nnz::Int
    matrix_hash::Digest256
    rhs_hash::Digest256
    solution_hash::Digest256
    residual_abs::Float64
    residual_rel::Float64
    l2_error::Float64
    h1_seminorm_error::Float64
    boundary_linf::Float64
    assembled_source_integral::Float64
    analytic_source_integral::Float64
    source_integral_error::Float64
    analytic_outward_conormal_integral::Float64
    analytic_identity_defect::Float64
    discrete_trace_conormal_integral::Float64
    discrete_trace_conormal_error::Float64
    dof_partition_hash::Digest256
    discrete_interior_reaction_linf::Float64
    discrete_interior_reaction_sum::Float64
    discrete_interior_residual_match_linf::Float64
    discrete_boundary_reaction_integral::Float64
    discrete_boundary_reaction_balance_defect::Float64
    field_state::NativeG1G2Q1FieldStateV1
    source_sign::Symbol
    status::Symbol
    level_hash::Digest256
end

function _ng12_level_body(level, cell_counts, physical_domain, cells,
        free_dofs, dirichlet_dofs, matrix_shape, matrix_nnz, matrix_hash,
        rhs_hash, solution_hash, residual_abs, residual_rel, l2_error,
        h1_seminorm_error, boundary_linf, assembled_source_integral,
        analytic_source_integral, source_integral_error,
        analytic_outward_conormal_integral, analytic_identity_defect,
        discrete_trace_conormal_integral, discrete_trace_conormal_error,
        dof_partition_hash, discrete_interior_reaction_linf,
        discrete_interior_reaction_sum,
        discrete_interior_residual_match_linf,
        discrete_boundary_reaction_integral,
        discrete_boundary_reaction_balance_defect, field_state,
        source_sign, status)
    (domain="native-g1g2-gridap-level-result-v2-q1-state", level=level,
        cell_counts=cell_counts, physical_domain=physical_domain,
        cells=cells, free_dofs=free_dofs, dirichlet_dofs=dirichlet_dofs,
        matrix_shape=matrix_shape, matrix_nnz=matrix_nnz,
        matrix_hash=matrix_hash, rhs_hash=rhs_hash,
        solution_hash=solution_hash, residual_abs=residual_abs,
        residual_rel=residual_rel, l2_error=l2_error,
        h1_seminorm_error=h1_seminorm_error,
        boundary_linf=boundary_linf,
        assembled_source_integral=assembled_source_integral,
        analytic_source_integral=analytic_source_integral,
        source_integral_error=source_integral_error,
        analytic_outward_conormal_integral=analytic_outward_conormal_integral,
        analytic_identity_defect=analytic_identity_defect,
        discrete_trace_conormal_integral=discrete_trace_conormal_integral,
        discrete_trace_conormal_error=discrete_trace_conormal_error,
        dof_partition_hash=dof_partition_hash,
        discrete_interior_reaction_linf=discrete_interior_reaction_linf,
        discrete_interior_reaction_sum=discrete_interior_reaction_sum,
        discrete_interior_residual_match_linf=
            discrete_interior_residual_match_linf,
        discrete_boundary_reaction_integral=
            discrete_boundary_reaction_integral,
        discrete_boundary_reaction_balance_defect=
            discrete_boundary_reaction_balance_defect,
        field_state=field_state,
        source_sign=source_sign, status=status)
end

semantic_view(x::NativeG1G2GridapLevelResultV1) = merge(
    _ng12_level_body(x.level, x.cell_counts, x.physical_domain, x.cells,
        x.free_dofs, x.dirichlet_dofs, x.matrix_shape, x.matrix_nnz,
        x.matrix_hash, x.rhs_hash, x.solution_hash, x.residual_abs,
        x.residual_rel, x.l2_error, x.h1_seminorm_error,
        x.boundary_linf, x.assembled_source_integral,
        x.analytic_source_integral, x.source_integral_error,
        x.analytic_outward_conormal_integral, x.analytic_identity_defect,
        x.discrete_trace_conormal_integral, x.discrete_trace_conormal_error,
        x.dof_partition_hash, x.discrete_interior_reaction_linf,
        x.discrete_interior_reaction_sum,
        x.discrete_interior_residual_match_linf,
        x.discrete_boundary_reaction_integral,
        x.discrete_boundary_reaction_balance_defect,
        x.field_state, x.source_sign, x.status), (level_hash=x.level_hash,))
canonical_hash(x::NativeG1G2GridapLevelResultV1) = x.level_hash

function _ng12_sparse_hash(matrix)
    rows, columns, values = findnz(sparse(matrix))
    canonical_hash((shape=(size(matrix, 1), size(matrix, 2)),
        rows=Vector{Int}(rows), columns=Vector{Int}(columns),
        values=Vector{Float64}(values)))
end

function _ng12_cartesian_chart_supported_v1(chart::G2MBChartMapV1)
    chart.map_kind === :affine && chart.axes == (:x, :y, :z) &&
        all(iszero(chart.jacobian_rows[i][j]) for i in 1:3 for j in 1:3 if i != j) &&
        all(chart.jacobian_rows[i][i] > 0 for i in 1:3)
end

function _ng12_physical_domain(form::NativeG1G2VariableDiffusionFormV1)
    bounds = g2mb_chart_image_bounds(form.g2_declaration.source.chart_map)
    (Float64(bounds[1][1]), Float64(bounds[1][2]),
     Float64(bounds[2][1]), Float64(bounds[2][2]),
     Float64(bounds[3][1]), Float64(bounds[3][2]))
end

function _ng12_q1_plan_mapping_v1(plan::NativeG1G2GridapPlanV1, level::Int)
    form = plan.compilation.form
    source = form.g2_declaration.source
    _ng12_cartesian_chart_supported_v1(source.chart_map) || return nothing
    domain = _ng12_physical_domain(form)
    cells = plan.protocol.cell_counts[level]
    model = CartesianDiscreteModel(domain, cells)
    reffe = Gridap.ReferenceFEs.LagrangianRefFE(Float64,
        Gridap.ReferenceFEs.HEX, 1)
    full_space = TestFESpace(model, reffe; conformity=:H1)
    coords, dirichlet_coords =
        Gridap.FESpaces.get_free_and_dirichlet_dof_coordinates(full_space)
    isempty(dirichlet_coords) || return nothing
    dof_coordinates = Tuple(Tuple(Float64.(Tuple(point))) for point in coords)
    cell_dof_ids = Tuple(Tuple(Int(id) for id in ids)
        for ids in get_cell_dof_ids(full_space))
    constrained_space = TestFESpace(model, reffe; conformity=:H1,
        dirichlet_tags="boundary")
    partition = _ng12_full_space_dof_partition(constrained_space, full_space)
    boundary = BoundaryTriangulation(model)
    face_owners = _ng12_gridap_boundary_face_projection_v1(boundary,
        domain, cells, source.faces, source.chart_map)
    face_dof_full_ids = Tuple((face_id=face.face_id, face=face.face,
        owner_region_id=face.owner_region_id,
        physical_plane_coordinate=face.physical_plane_coordinate,
        dof_full_ids=Tuple(i for i in eachindex(dof_coordinates)
            if isapprox(dof_coordinates[i][
                face.face in (:x_min,:x_max) ? 1 :
                face.face in (:y_min,:y_max) ? 2 : 3],
                face.physical_plane_coordinate; atol=1e-12, rtol=0.0)))
        for face in face_owners)
    entity_ownership = _ng12_g2_entity_ownership_v1(source, cells,
        dof_coordinates, cell_dof_ids)
    (dof_coordinates=dof_coordinates, cell_dof_ids=cell_dof_ids,
     cell_dof_coordinates=Tuple(Tuple(dof_coordinates[id] for id in ids)
        for ids in cell_dof_ids),
     free_to_full=Tuple(partition.free_to_full),
     boundary_to_full=Tuple(partition.boundary_to_full),
     face_owners=face_owners, face_dof_full_ids=face_dof_full_ids,
     g2_entity_ownership=entity_ownership)
end

function _ng12_tensor_value(form, x)
    k = native_g1g2_k_tensor_v1(form, (x[1], x[2], x[3]))
    TensorValue(k[1][1], k[1][2], k[1][3],
                k[2][1], k[2][2], k[2][3],
                k[3][1], k[3][2], k[3][3])
end

function _ng12_boundary_points(domain)
    xs = (domain[1], (domain[1] + domain[2]) / 2, domain[2])
    ys = (domain[3], (domain[3] + domain[4]) / 2, domain[4])
    zs = (domain[5], (domain[5] + domain[6]) / 2, domain[6])
    points = NTuple{3,Float64}[]
    for y in ys, z in zs
        push!(points, (domain[1], y, z), (domain[2], y, z))
    end
    for x in xs, z in zs
        push!(points, (x, domain[3], z), (x, domain[4], z))
    end
    for x in xs, y in ys
        push!(points, (x, y, domain[5]), (x, y, domain[6]))
    end
    Tuple(unique(points))
end

"""Map the constrained Q1 numbering into the matching unconstrained space.

Both spaces use the same model and reference element.  Positive constrained
cell ids name free (interior) dofs and negative ids name Dirichlet (boundary)
dofs.  Pairing each local id with the corresponding unconstrained local id
produces an explicit, checked partition of every global Q1 dof.
"""
function _ng12_full_space_dof_partition(constrained_space, full_space)
    constrained_cells = get_cell_dof_ids(constrained_space)
    full_cells = get_cell_dof_ids(full_space)
    length(constrained_cells) == length(full_cells) ||
        error("constrained/full cell inventory mismatch")
    free_to_full = zeros(Int, num_free_dofs(constrained_space))
    boundary_to_full = zeros(Int, num_dirichlet_dofs(constrained_space))
    for cell in eachindex(constrained_cells)
        constrained_ids = constrained_cells[cell]
        full_ids = full_cells[cell]
        length(constrained_ids) == length(full_ids) ||
            error("constrained/full local dof inventory mismatch")
        for local_dof in eachindex(constrained_ids)
            constrained_id = Int(constrained_ids[local_dof])
            full_id = Int(full_ids[local_dof])
            full_id > 0 || error("unconstrained dof id must be positive")
            if constrained_id > 0
                previous = free_to_full[constrained_id]
                previous in (0, full_id) ||
                    error("free dof maps to multiple full dofs")
                free_to_full[constrained_id] = full_id
            else
                boundary_id = -constrained_id
                previous = boundary_to_full[boundary_id]
                previous in (0, full_id) ||
                    error("boundary dof maps to multiple full dofs")
                boundary_to_full[boundary_id] = full_id
            end
        end
    end
    all(>(0), free_to_full) || error("free dof mapping is incomplete")
    all(>(0), boundary_to_full) ||
        error("boundary dof mapping is incomplete")
    all_full = vcat(free_to_full, boundary_to_full)
    length(unique(all_full)) == length(all_full) ||
        error("constrained/full dof partition overlaps")
    sort(all_full) == collect(1:num_free_dofs(full_space)) ||
        error("constrained/full dof partition is not exhaustive")
    body = (domain="native-g1g2-q1-dof-partition-v1",
        free_to_full=free_to_full, boundary_to_full=boundary_to_full)
    (free_to_full=free_to_full, boundary_to_full=boundary_to_full,
        partition_hash=canonical_hash(body))
end

function run_native_g1g2_gridap_level_v1(plan::NativeG1G2GridapPlanV1,
        level::Integer; source_sign::Symbol=:declared, transfer_outcome=nothing)
    validate_native_g1g2_gridap_plan_v1(plan) ||
        throw(ArgumentError("Gridap plan integrity mismatch"))
    source_sign in (:declared, :reversed_test_control) ||
        throw(ArgumentError("unsupported source sign control"))
    1 <= level <= 3 || throw(ArgumentError("refinement level must be 1:3"))
    form = plan.compilation.form
    protocol = plan.protocol
    chart_mesh_request = native_g1g2_gridap_chart_mesh_service_v1(plan, level)
    chart_mesh = _ng12_execute_gridap_service_v1(chart_mesh_request,
        _NG12_CHART_MESH_SERVICE_V1,
        _ng12_gridap_chart_mesh_executor_v1)
    boundary_request = native_g1g2_gridap_exterior_boundary_service_v1(plan,
        level)
    boundary_service = _ng12_execute_gridap_service_v1(boundary_request,
        _NG12_EXTERIOR_BOUNDARY_SERVICE_V1,
        _ng12_gridap_exterior_boundary_executor_v1, chart_mesh)
    cells = chart_mesh.cell_counts
    domain = chart_mesh.physical_domain
    model = chart_mesh.model
    reffe = chart_mesh.reffe
    omega = chart_mesh.omega
    measure = chart_mesh.measure
    test_space = boundary_service.test_space
    trial_space = boundary_service.trial_space
    k_field = CellField(x -> _ng12_tensor_value(form, x), omega)
    sign_multiplier = source_sign === :declared ? 1.0 : -1.0
    source_function(x) = sign_multiplier * native_g1g2_source_value_v1(
        form, (x[1], x[2], x[3]))
    a(u, v) = ∫(∇(v) ⋅ (k_field ⋅ ∇(u))) * measure
    b(v) = ∫(v * source_function) * measure
    operator = AffineFEOperator(a, b, trial_space, test_space)
    matrix = get_matrix(operator)
    rhs = Float64.(get_vector(operator))
    if transfer_outcome === nothing
        solution = solve(LinearFESolver(LUSolver()), operator)
        free_values = Float64.(get_free_values(solution))
        transfer_consumption = nothing
    else
        transfer_seed = _ng12_consume_child_transfer_v1(plan, Int(level),
            transfer_outcome, test_space, matrix, rhs)
        correction = matrix \ (rhs - matrix * transfer_seed.free_values)
        free_values = transfer_seed.free_values + Float64.(correction)
        solution = FEFunction(trial_space, free_values)
        corrected_residual = matrix * free_values - rhs
        old_receipt = transfer_seed.receipt
        receipt_body = (domain=old_receipt.domain,
            transfer_receipt_hash=old_receipt.transfer_receipt_hash,
            transfer_projection_hash=old_receipt.transfer_projection_hash,
            child_plan_hash=old_receipt.child_plan_hash,
            child_level=old_receipt.child_level,
            matrix_hash=old_receipt.matrix_hash, rhs_hash=old_receipt.rhs_hash,
            residual_abs=old_receipt.residual_abs,
            residual_rel=old_receipt.residual_rel,
            boundary_linf=old_receipt.boundary_linf,
            boundary_preserved=old_receipt.boundary_preserved,
            consumer=:native_child_q1_residual_correction_seed,
            seed_used=true, correction_linf=norm(correction,Inf),
            corrected_residual_abs=norm(corrected_residual,Inf),
            corrected_residual_rel=norm(corrected_residual,Inf) /
                max(norm(rhs,Inf),eps(Float64)), status=:measured,
            pass=false, claim_ceiling=:screen_only)
        transfer_consumption = merge(receipt_body,
            (receipt_hash=FusionConceptAI.canonical_hash(receipt_body),))
    end
    grad_request = native_g1g2_gridap_grad_service_v1(plan, level)
    grad_service = _ng12_execute_gridap_service_v1(grad_request,
        _NG12_GRAD_SERVICE_V1, _ng12_gridap_grad_executor_v1, chart_mesh,
        boundary_service, solution, free_values)
    algebraic_residual = matrix * free_values - rhs
    residual_abs = norm(algebraic_residual, Inf)
    residual_rel = residual_abs / max(norm(rhs, Inf), eps(Float64))

    exact_value = CellField(x -> native_g1g2_reference_value_v1(form,
        (x[1], x[2], x[3])), omega)
    exact_gradient = CellField(x -> VectorValue(
        native_g1g2_reference_gradient_v1(form,
            (x[1], x[2], x[3]))...), omega)
    value_error = exact_value - solution
    gradient_error = exact_gradient - grad_service.gradient_field
    l2_error = sqrt(sum(∫(value_error * value_error) * measure))
    h1_error = sqrt(sum(∫(gradient_error ⋅ gradient_error) * measure))
    boundary_linf = maximum(abs(Float64(solution(Point(p...))))
        for p in _ng12_boundary_points(domain))
    assembled_source_integral = sum(∫(CellField(source_function, omega)) * measure)
    balance = native_g1g2_continuous_balance_v1(form)
    analytic_source_integral = sign_multiplier * balance.source_integral
    source_integral_error = abs(assembled_source_integral -
        analytic_source_integral)
    analytic_outward_conormal_integral =
        sign_multiplier * balance.outward_conormal_integral
    analytic_identity_defect = analytic_source_integral +
        analytic_outward_conormal_integral

    # Record the physical solved-field trace.  Continuous Q1 gradients are not
    # locally conservative, so this trace is a diagnostic rather than the
    # conservation gate below.
    boundary = boundary_service.boundary
    boundary_measure = boundary_service.boundary_measure
    boundary_normal = boundary_service.boundary_normal
    boundary_k = CellField(x -> _ng12_tensor_value(form, x), boundary)
    discrete_trace_conormal_integral = sum(
        ∫(boundary_normal ⋅ (boundary_k ⋅ grad_service.gradient_field)) * boundary_measure)
    discrete_trace_conormal_error = abs(discrete_trace_conormal_integral -
        analytic_outward_conormal_integral)

    # Assemble the same weak form on the unconstrained Q1 space and evaluate
    # its residual at the solved field.  The explicit local-dof pairing below
    # separates constrained boundary reactions from interior equations; only
    # the boundary subset enters the global balance.  The interior subset is
    # independently compared with the reduced algebraic residual.
    full_test_space = TestFESpace(model, reffe; conformity=:H1)
    full_trial_space = TrialFESpace(full_test_space)
    full_operator = AffineFEOperator(a, b, full_trial_space, full_test_space)
    full_matrix = get_matrix(full_operator)
    full_rhs = Float64.(get_vector(full_operator))
    dof_partition = _ng12_full_space_dof_partition(test_space,
        full_test_space)
    full_values = zeros(Float64, num_free_dofs(full_test_space))
    full_values[dof_partition.free_to_full] = free_values
    field_state = _ng12_q1_field_state_v1(plan, level, source_sign, full_values,
        full_test_space, dof_partition, boundary_service, chart_mesh)
    full_reactions = full_matrix * full_values - full_rhs
    interior_reactions = full_reactions[dof_partition.free_to_full]
    boundary_reactions = full_reactions[dof_partition.boundary_to_full]
    discrete_interior_reaction_linf = norm(interior_reactions, Inf)
    discrete_interior_reaction_sum = sum(interior_reactions)
    discrete_interior_residual_match_linf = norm(
        interior_reactions - algebraic_residual, Inf)
    discrete_boundary_reaction_integral = sum(boundary_reactions)
    discrete_boundary_reaction_balance_defect = assembled_source_integral +
        discrete_boundary_reaction_integral
    finite = all(isfinite, (residual_abs, residual_rel, l2_error,
        h1_error, boundary_linf, assembled_source_integral,
        analytic_source_integral, source_integral_error,
        analytic_outward_conormal_integral, analytic_identity_defect,
        discrete_trace_conormal_integral, discrete_trace_conormal_error,
        discrete_interior_reaction_linf, discrete_interior_reaction_sum,
        discrete_interior_residual_match_linf,
        discrete_boundary_reaction_integral,
        discrete_boundary_reaction_balance_defect)) &&
        all(isfinite, free_values)
    residual_ok = residual_abs <= protocol.residual_abs_tol ||
        residual_rel <= protocol.residual_rel_tol
    status = if form.authored_source_capability !== nothing
        # The manufactured reference and analytic source identity belong only
        # to the regression fixture. A candidate-authored source has a real
        # assembled residual above, but no compatible exact-u/gradient
        # contract in this adapter yet, so it cannot receive MMS acceptance.
        :not_applicable_reference
    elseif finite && source_sign === :declared && residual_ok &&
        boundary_linf <= protocol.boundary_abs_tol &&
        source_integral_error <= protocol.source_integral_abs_tol &&
        abs(analytic_identity_defect) <=
            protocol.analytic_identity_abs_tol &&
        discrete_interior_reaction_linf <= protocol.residual_abs_tol &&
        discrete_interior_residual_match_linf <=
            protocol.residual_abs_tol &&
        abs(discrete_boundary_reaction_balance_defect) <=
        protocol.reaction_balance_abs_tol
        :pass
    else
        :numerical_fail
    end
    matrix_hash = _ng12_sparse_hash(matrix)
    rhs_hash = canonical_hash(rhs)
    solution_hash = grad_service.solution_hash
    args = (Int(level), cells, domain, num_cells(model),
        num_free_dofs(test_space), num_dirichlet_dofs(test_space),
        (size(matrix, 1), size(matrix, 2)), nnz(matrix), matrix_hash,
        rhs_hash, solution_hash, residual_abs, residual_rel, l2_error,
        h1_error, boundary_linf, assembled_source_integral,
        analytic_source_integral, source_integral_error,
        analytic_outward_conormal_integral, analytic_identity_defect,
        discrete_trace_conormal_integral, discrete_trace_conormal_error,
        dof_partition.partition_hash, discrete_interior_reaction_linf,
        discrete_interior_reaction_sum,
        discrete_interior_residual_match_linf,
        discrete_boundary_reaction_integral,
        discrete_boundary_reaction_balance_defect, field_state,
        source_sign, status)
    body = _ng12_level_body(args...)
    result = NativeG1G2GridapLevelResultV1(args..., canonical_hash(body))
    transfer_consumption === nothing ? result :
        (level=result, transfer_consumption=transfer_consumption)
end

function _ng12_level_integrity(x::NativeG1G2GridapLevelResultV1)
    x.level in 1:3 && all(>(0), x.cell_counts) && x.cells > 0 &&
    x.free_dofs > 0 && x.dirichlet_dofs > 0 && x.matrix_nnz > 0 &&
    _ng12_q1_field_state_valid(x.field_state) &&
    x.field_state.level == x.level &&
    x.field_state.cell_counts == x.cell_counts &&
    x.field_state.physical_domain == x.physical_domain &&
    length(x.field_state.dof_coordinates) == x.free_dofs + x.dirichlet_dofs &&
    canonical_hash(Float64[x.field_state.component_dof_values[1][i]
        for i in x.field_state.free_to_full]) == x.solution_hash &&
    all(isfinite, (x.residual_abs, x.residual_rel, x.l2_error,
        x.h1_seminorm_error, x.boundary_linf,
        x.assembled_source_integral, x.analytic_source_integral,
        x.source_integral_error, x.analytic_outward_conormal_integral,
        x.analytic_identity_defect, x.discrete_trace_conormal_integral,
        x.discrete_trace_conormal_error,
        x.discrete_interior_reaction_linf,
        x.discrete_interior_reaction_sum,
        x.discrete_interior_residual_match_linf,
        x.discrete_boundary_reaction_integral,
        x.discrete_boundary_reaction_balance_defect)) &&
    canonical_hash(_ng12_level_body(x.level, x.cell_counts,
        x.physical_domain, x.cells, x.free_dofs, x.dirichlet_dofs,
        x.matrix_shape, x.matrix_nnz, x.matrix_hash, x.rhs_hash,
        x.solution_hash, x.residual_abs, x.residual_rel, x.l2_error,
        x.h1_seminorm_error, x.boundary_linf,
        x.assembled_source_integral, x.analytic_source_integral,
        x.source_integral_error, x.analytic_outward_conormal_integral,
        x.analytic_identity_defect, x.discrete_trace_conormal_integral,
        x.discrete_trace_conormal_error,
        x.dof_partition_hash, x.discrete_interior_reaction_linf,
        x.discrete_interior_reaction_sum,
        x.discrete_interior_residual_match_linf,
        x.discrete_boundary_reaction_integral,
        x.discrete_boundary_reaction_balance_defect,
        x.field_state, x.source_sign, x.status)) ==
        x.level_hash
end

function _ng12_level_matches_plan(plan::NativeG1G2GridapPlanV1,
        x::NativeG1G2GridapLevelResultV1, level::Int)
    protocol = plan.protocol
    form = plan.compilation.form
    state = x.field_state
    expected_mapping = _ng12_q1_plan_mapping_v1(plan, level)
    expected_mapping === nothing && return false
    balance = native_g1g2_continuous_balance_v1(form)
    residual_ok = x.residual_abs <= protocol.residual_abs_tol ||
        x.residual_rel <= protocol.residual_rel_tol
    expected_status = if form.authored_source_capability !== nothing
        :not_applicable_reference
    elseif x.source_sign === :declared && residual_ok &&
        x.boundary_linf <= protocol.boundary_abs_tol &&
        x.source_integral_error <= protocol.source_integral_abs_tol &&
        abs(x.analytic_identity_defect) <=
            protocol.analytic_identity_abs_tol &&
        x.discrete_interior_reaction_linf <= protocol.residual_abs_tol &&
        x.discrete_interior_residual_match_linf <=
            protocol.residual_abs_tol &&
        abs(x.discrete_boundary_reaction_balance_defect) <=
        protocol.reaction_balance_abs_tol
        :pass
    else
        :numerical_fail
    end
    _ng12_q1_field_state_valid(state) &&
    state.dof_coordinates == expected_mapping.dof_coordinates &&
    state.cell_dof_ids == expected_mapping.cell_dof_ids &&
    state.cell_dof_coordinates == expected_mapping.cell_dof_coordinates &&
    state.free_to_full == expected_mapping.free_to_full &&
    state.boundary_to_full == expected_mapping.boundary_to_full &&
    canonical_hash(state.face_owners) == canonical_hash(expected_mapping.face_owners) &&
    canonical_hash(state.face_dof_full_ids) ==
        canonical_hash(expected_mapping.face_dof_full_ids) &&
    canonical_hash(state.g2_entity_ownership) ==
        canonical_hash(expected_mapping.g2_entity_ownership) &&
    all(state.component_dof_values[1][id] == projected.value
        for projected in expected_mapping.face_owners
        for face in (only(filter(x -> x.face === projected.face,
            expected_mapping.face_dof_full_ids)),)
        for id in face.dof_full_ids) &&
    state.candidate_ref == form.candidate_ref &&
    state.package_hash == form.t1_package_hash &&
    state.semantic_identity == form.t1_semantic_identity &&
    state.t0_bundle_hash == form.t0_bundle_hash &&
    state.plan_hash == plan.plan_hash &&
    state.g1_declaration_hash == form.g1_declaration.declaration_hash &&
    state.g2_declaration_hash == form.g2_declaration.declaration_hash &&
    state.g2_source_ref == form.g2_declaration.source.source_ref &&
    state.g2_source_hash == form.g2_declaration.source.source_hash &&
    state.g2_mesh_ref == form.g2_declaration.source.mesh.mesh_ref &&
    state.g2_chart_ref == form.g2_declaration.source.chart_map.chart_ref &&
    state.component_field_ids == (form.g1_declaration.u.field_id,) &&
    state.component_units == (form.g1_declaration.u.physical_type.units,) &&
    all(begin
        source_face = only(filter(face -> face.face === projected.face,
            form.g2_declaration.source.faces))
        projected.face_id == source_face.face_id &&
        projected.owner_region_id == source_face.owner_region_id &&
        projected.reference_normal == source_face.reference_normal &&
        projected.kind === source_face.value.kind &&
        projected.value == source_face.value.value &&
        projected.unit == source_face.value.unit
    end for projected in state.face_owners) &&
    x.level == level && x.cell_counts == protocol.cell_counts[level] &&
    x.physical_domain == _ng12_physical_domain(form) &&
    x.cells == prod(x.cell_counts) &&
    x.free_dofs + x.dirichlet_dofs == prod(x.cell_counts .+ 1) &&
    x.matrix_shape == (x.free_dofs, x.free_dofs) &&
    x.source_sign === :declared &&
    x.analytic_source_integral == balance.source_integral &&
    x.analytic_outward_conormal_integral ==
        balance.outward_conormal_integral &&
    x.source_integral_error == abs(x.assembled_source_integral -
        x.analytic_source_integral) &&
    x.analytic_identity_defect == x.analytic_source_integral +
        x.analytic_outward_conormal_integral &&
    x.discrete_trace_conormal_error ==
        abs(x.discrete_trace_conormal_integral -
            x.analytic_outward_conormal_integral) &&
    isapprox(x.discrete_interior_reaction_linf, x.residual_abs;
        atol=protocol.residual_abs_tol, rtol=0.0) &&
    x.discrete_interior_residual_match_linf <=
        protocol.residual_abs_tol &&
    x.discrete_boundary_reaction_balance_defect ==
        x.assembled_source_integral +
            x.discrete_boundary_reaction_integral &&
    isapprox(x.discrete_boundary_reaction_balance_defect,
        -x.discrete_interior_reaction_sum;
        atol=protocol.reaction_balance_abs_tol, rtol=0.0) &&
    x.status === expected_status
end

struct NativeG1G2GridapReportV1
    candidate_ref::QualifiedRefV1
    t1_package_hash::Digest256
    plan_hash::Digest256
    solver_input_hash::Digest256
    protocol_hash::Digest256
    levels::NTuple{3,NativeG1G2GridapLevelResultV1}
    l2_orders::NTuple{2,Float64}
    h1_orders::NTuple{2,Float64}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::ClaimCeiling
    numerical_scope::Symbol
    physical_status::Symbol
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    report_hash::Digest256
end

function _ng12_report_body(candidate_ref, t1_package_hash, plan_hash,
        solver_input_hash, protocol_hash, levels, l2_orders, h1_orders,
        status, resolution, accepted, claim_ceiling, numerical_scope,
        physical_status, errors, gaps)
    (domain="native-g1g2-gridap-report-v2-q1-state", candidate_ref=candidate_ref,
        t1_package_hash=t1_package_hash, plan_hash=plan_hash,
        solver_input_hash=solver_input_hash, protocol_hash=protocol_hash,
        levels=levels, l2_orders=l2_orders, h1_orders=h1_orders,
        status=status, resolution=resolution, accepted=accepted,
        claim_ceiling=claim_ceiling, numerical_scope=numerical_scope,
        physical_status=physical_status, errors=errors, gaps=gaps)
end

semantic_view(x::NativeG1G2GridapReportV1) = merge(
    _ng12_report_body(x.candidate_ref, x.t1_package_hash, x.plan_hash,
        x.solver_input_hash, x.protocol_hash, x.levels, x.l2_orders,
        x.h1_orders, x.status, x.resolution, x.accepted,
        x.claim_ceiling, x.numerical_scope, x.physical_status, x.errors,
        x.gaps), (report_hash=x.report_hash,))
canonical_hash(x::NativeG1G2GridapReportV1) = x.report_hash

function _ng12_orders(errors)
    ntuple(i -> log(errors[i] / errors[i + 1]) / log(2.0), 2)
end

function _ng12_run_gridap_series(plan::NativeG1G2GridapPlanV1)
    levels = ntuple(i -> run_native_g1g2_gridap_level_v1(plan, i), 3)
    l2_orders = _ng12_orders(ntuple(i -> levels[i].l2_error, 3))
    h1_orders = _ng12_orders(ntuple(i -> levels[i].h1_seminorm_error, 3))
    protocol = plan.protocol
    reasons = Symbol[]
    all(level -> level.status === :pass, levels) ||
        push!(reasons, :level_numerical_gate_failed)
    all(levels[i].l2_error > levels[i + 1].l2_error &&
        levels[i].h1_seminorm_error > levels[i + 1].h1_seminorm_error
        for i in 1:2) || push!(reasons, :errors_not_monotone)
    all(levels[i].discrete_trace_conormal_error >
        levels[i + 1].discrete_trace_conormal_error for i in 1:2) ||
        push!(reasons, :boundary_trace_flux_error_not_monotone)
    all(protocol.l2_order_interval[1] <= order <=
        protocol.l2_order_interval[2] for order in l2_orders) ||
        push!(reasons, :l2_order_outside_interval)
    all(protocol.h1_order_interval[1] <= order <=
        protocol.h1_order_interval[2] for order in h1_orders) ||
        push!(reasons, :h1_order_outside_interval)
    levels[3].l2_error <= protocol.finest_l2_max ||
        push!(reasons, :finest_l2_budget_exceeded)
    levels[3].h1_seminorm_error <= protocol.finest_h1_seminorm_max ||
        push!(reasons, :finest_h1_budget_exceeded)
    status = isempty(reasons) ? :pass : :numerical_fail
    gaps = (:native_g1g2_numerical_execution_pending,
        :up1_aggregate_gate_pending,
        :g3_material_conversion_missing,
        :g3_two_region_interface_missing,
        :strong_trace_flux_is_nonconservative_diagnostic,
        :independent_physical_validation_missing)
    status === :pass && (gaps = Base.tail(gaps))
    args = (plan.compilation.form.candidate_ref,
        plan.compilation.form.t1_package_hash, plan.plan_hash,
        plan.solver_input.solver_input_hash, protocol.protocol_hash, levels,
        l2_orders, h1_orders, status, :terminal_deferred, false,
        screen_only, :manufactured_variable_diffusion,
        :unknown, Tuple(reasons), gaps)
    body = _ng12_report_body(args...)
    NativeG1G2GridapReportV1(args..., canonical_hash(body))
end

function validate_native_g1g2_gridap_report_v1(
        plan::NativeG1G2GridapPlanV1, report::NativeG1G2GridapReportV1)
    try
        validate_native_g1g2_gridap_plan_v1(plan) || return false
        all(_ng12_level_integrity, report.levels) || return false
        all(_ng12_level_matches_plan(plan, report.levels[i], i)
            for i in 1:3) || return false
        report.candidate_ref == plan.compilation.form.candidate_ref || return false
        report.t1_package_hash == plan.compilation.form.t1_package_hash ||
            return false
        report.plan_hash == plan.plan_hash || return false
        report.solver_input_hash == plan.solver_input.solver_input_hash ||
            return false
        report.protocol_hash == plan.protocol.protocol_hash || return false
        Tuple(level.cell_counts for level in report.levels) ==
            plan.protocol.cell_counts || return false
        report.l2_orders == _ng12_orders(ntuple(i ->
            report.levels[i].l2_error, 3)) || return false
        report.h1_orders == _ng12_orders(ntuple(i ->
            report.levels[i].h1_seminorm_error, 3)) || return false
        report.resolution === :terminal_deferred && !report.accepted &&
            report.claim_ceiling == screen_only &&
            report.numerical_scope === :manufactured_variable_diffusion &&
            report.physical_status === :unknown || return false
        expected_reasons = Symbol[]
        all(level -> level.status === :pass, report.levels) ||
            push!(expected_reasons, :level_numerical_gate_failed)
        all(report.levels[i].l2_error > report.levels[i + 1].l2_error &&
            report.levels[i].h1_seminorm_error >
                report.levels[i + 1].h1_seminorm_error for i in 1:2) ||
            push!(expected_reasons, :errors_not_monotone)
        all(report.levels[i].discrete_trace_conormal_error >
            report.levels[i + 1].discrete_trace_conormal_error
            for i in 1:2) ||
            push!(expected_reasons, :boundary_trace_flux_error_not_monotone)
        all(plan.protocol.l2_order_interval[1] <= order <=
            plan.protocol.l2_order_interval[2] for order in report.l2_orders) ||
            push!(expected_reasons, :l2_order_outside_interval)
        all(plan.protocol.h1_order_interval[1] <= order <=
            plan.protocol.h1_order_interval[2] for order in report.h1_orders) ||
            push!(expected_reasons, :h1_order_outside_interval)
        report.levels[3].l2_error <= plan.protocol.finest_l2_max ||
            push!(expected_reasons, :finest_l2_budget_exceeded)
        report.levels[3].h1_seminorm_error <=
            plan.protocol.finest_h1_seminorm_max ||
            push!(expected_reasons, :finest_h1_budget_exceeded)
        report.errors == Tuple(expected_reasons) || return false
        report.status == (isempty(expected_reasons) ? :pass :
            :numerical_fail) || return false
        expected_gaps = (:native_g1g2_numerical_execution_pending,
            :up1_aggregate_gate_pending,
            :g3_material_conversion_missing,
            :g3_two_region_interface_missing,
            :strong_trace_flux_is_nonconservative_diagnostic,
            :independent_physical_validation_missing)
        report.status === :pass && (expected_gaps = Base.tail(expected_gaps))
        report.gaps == expected_gaps || return false
        canonical_hash(_ng12_report_body(report.candidate_ref,
            report.t1_package_hash, report.plan_hash,
            report.solver_input_hash, report.protocol_hash, report.levels,
            report.l2_orders, report.h1_orders, report.status,
            report.resolution, report.accepted, report.claim_ceiling,
            report.numerical_scope, report.physical_status, report.errors,
            report.gaps)) == report.report_hash
    catch
        false
    end
end

function _ng12_provider_metrics_v1(report::NativeG1G2GridapReportV1)
    length_unit = _ng12_si_length_unit(1)
    l2_unit = _ng12_si_length_unit(3 // 2)
    h1_unit = _ng12_si_length_unit(1 // 2)
    (MetricWithUnit(:finest_l2_error, report.levels[3].l2_error, l2_unit),
        MetricWithUnit(:finest_h1_seminorm_error,
            report.levels[3].h1_seminorm_error, h1_unit),
        MetricWithUnit(:max_algebraic_residual,
            maximum(level.residual_abs for level in report.levels),
            length_unit),
        MetricWithUnit(:max_relative_algebraic_residual,
            maximum(level.residual_rel for level in report.levels)),
        MetricWithUnit(:max_source_integral_error,
            maximum(level.source_integral_error for level in report.levels),
            length_unit),
        MetricWithUnit(:max_interior_reaction_linf,
            maximum(level.discrete_interior_reaction_linf
                for level in report.levels), length_unit),
        MetricWithUnit(:max_interior_residual_match_linf,
            maximum(level.discrete_interior_residual_match_linf
                for level in report.levels), length_unit),
        MetricWithUnit(:max_discrete_boundary_reaction_balance_defect,
            maximum(abs(level.discrete_boundary_reaction_balance_defect)
                for level in report.levels), length_unit),
        MetricWithUnit(:finest_boundary_trace_conormal_error,
            report.levels[3].discrete_trace_conormal_error, length_unit),
        MetricWithUnit(:solver_calls, 3.0))
end

_ng12_provider_artifacts_v1(report::NativeG1G2GridapReportV1) =
    (report.report_hash, (level.level_hash for level in report.levels)...)

const _NG12_EXECUTOR_ADMISSIONS = Dict{Digest256,NamedTuple}()

function _ng12_register_executor_plan_admission_v1(
        plan::NativeG1G2GridapPlanV1)
    token = native_g1g2_gridap_plan_admission_v1(plan)
    token === nothing &&
        throw(ArgumentError("Gridap plan has no current admission"))
    input_fingerprint = _ng12_serialized_fingerprint_v1(plan.solver_input)
    record = (plan=plan, plan_admission=token,
        input_fingerprint=input_fingerprint,
        context_hash=token.context_hash)
    key = plan.solver_input.solver_input_hash
    lock(_NG12_ADMISSION_LOCK) do
        haskey(_NG12_EXECUTOR_ADMISSIONS, key) &&
            throw(ArgumentError("Gridap executor admission key is already active"))
        _NG12_EXECUTOR_ADMISSIONS[key] = record
    end
    key
end

function _ng12_unregister_executor_plan_admission_v1!(key,
        plan::NativeG1G2GridapPlanV1)
    lock(_NG12_ADMISSION_LOCK) do
        record = get(_NG12_EXECUTOR_ADMISSIONS, key, nothing)
        record !== nothing && record.plan === plan &&
            delete!(_NG12_EXECUTOR_ADMISSIONS, key)
    end
    nothing
end

function _ng12_admitted_executor_plan_v1(input::SolverInputV4)
    record = lock(_NG12_ADMISSION_LOCK) do
        get(_NG12_EXECUTOR_ADMISSIONS, input.solver_input_hash, nothing)
    end
    record === nothing && return nothing
    try
        plan = record.plan
        context_hash = _ng12_admission_context_hash_v1()
        context_hash == record.context_hash ||
            throw(ArgumentError("Gridap executor admission context changed"))
        input.solver_input_hash == plan.solver_input.solver_input_hash ||
            throw(ArgumentError("Gridap executor input hash mismatch"))
        validate_native_g1g2_gridap_plan_admission_v1(plan,
            record.plan_admission) ||
            throw(ArgumentError("Gridap executor plan admission is stale"))
        _ng12_serialized_fingerprint_v1(input) ==
            record.input_fingerprint ||
            throw(ArgumentError("Gridap executor input content mismatch"))
        _ng12_serialized_fingerprint_v1(plan.solver_input) ==
            record.input_fingerprint ||
            throw(ArgumentError("Gridap admitted plan input was mutated"))
        plan
    catch error
        error isa ArgumentError && rethrow()
        throw(ArgumentError("Gridap executor admission validation failed"))
    end
end

function _native_g1g2_gridap_provider_executor_v1(input::SolverInputV4)
    admitted_plan = _ng12_admitted_executor_plan_v1(input)
    if admitted_plan !== nothing
        report = _ng12_run_gridap_series(admitted_plan)
        metrics = _ng12_provider_metrics_v1(report)
        return (report=report, metrics=metrics,
            stage_outcome=report.status === :pass ? pass : numerical_fail,
            uncertainty=nothing,
            artifacts=_ng12_provider_artifacts_v1(report),
            provider_calls=1, mesh_calls=3, assembly_calls=6, solver_calls=3)
    end
    materialized = input.payload.materialized_payload
    compilation = materialized.compilation
    compile_result_hash = materialized.compile_result_hash
    protocol = materialized.protocol
    dependency = materialized.dependency_identity
    adapter_hash = materialized.adapter_source_hash
    provider = native_g1g2_gridap_provider_v1(compilation, protocol,
        dependency, adapter_hash)
    subject = ExecutablePhysicalSubjectV4(
        compilation.subject.compiled_prefix_hash,
        compilation.subject.genome_bundle_hash,
        compilation.subject.mission_hash,
        compilation.subject.bounds_hash, compilation.subject.bindings,
        compilation.subject.scenarios, materialized,
        (compilation.capability,))
    rebuilt_input = compile_solver_input(subject, compilation.scenario,
        compilation.capability, provider)
    rebuilt_input.solver_input_hash == input.solver_input_hash ||
        throw(ArgumentError("provider solver input reconstruction mismatch"))
    body = _ng12_gridap_plan_body(compilation,
        compile_result_hash,
        protocol, dependency, provider, subject, rebuilt_input, adapter_hash)
    rebuilt_plan = NativeG1G2GridapPlanV1(compilation,
        compile_result_hash, protocol, dependency, provider, subject,
        rebuilt_input, adapter_hash, canonical_hash(body))
    validate_native_g1g2_gridap_plan_v1(rebuilt_plan) ||
        throw(ArgumentError("provider plan reconstruction mismatch"))
    report = _ng12_run_gridap_series(rebuilt_plan)
    metrics = _ng12_provider_metrics_v1(report)
    (report=report, metrics=metrics,
        stage_outcome=report.status === :pass ? pass : numerical_fail,
        uncertainty=nothing,
        artifacts=_ng12_provider_artifacts_v1(report),
        provider_calls=1, mesh_calls=3, assembly_calls=6, solver_calls=3)
end

struct NativeG1G2ExecutionBundleV1
    plan_hash::Digest256
    solver_input_hash::Digest256
    report::NativeG1G2GridapReportV1
    evidence::RuntimeEvidenceV4
    invocation_counts::NamedTuple
    formal_t2_consumer_receipts_reclassified::Bool
    bundle_hash::Digest256
end

function _ng12_execution_bundle_body(plan_hash, solver_input_hash, report,
        evidence, invocation_counts, formal_t2_consumer_receipts_reclassified)
    (domain="native-g1g2-execution-bundle-v1", plan_hash=plan_hash,
        solver_input_hash=solver_input_hash, report=report,
        evidence=evidence, invocation_counts=invocation_counts,
        formal_t2_consumer_receipts_reclassified=
            formal_t2_consumer_receipts_reclassified)
end

semantic_view(x::NativeG1G2ExecutionBundleV1) = merge(
    _ng12_execution_bundle_body(x.plan_hash, x.solver_input_hash,
        x.report, x.evidence, x.invocation_counts,
        x.formal_t2_consumer_receipts_reclassified),
    (bundle_hash=x.bundle_hash,))
canonical_hash(x::NativeG1G2ExecutionBundleV1) = x.bundle_hash

function _ng12_expected_runtime_evidence_v1(plan, report)
    status_vector = StatusVectorV4(required, unique_match, resolved,
        low_fidelity_evaluated,
        report.status === :pass ? pass : numerical_fail)
    binding = (candidate_ref=report.candidate_ref,
        t1_package_hash=report.t1_package_hash,
        plan_hash=plan.plan_hash, report_hash=report.report_hash,
        numerical_scope=report.numerical_scope,
        physical_status=report.physical_status)
    RuntimeEvidenceV4(plan.subject.physical_subject_hash,
        plan.solver_input.scenario_hash, plan.solver_input.solver_input_hash,
        plan.provider.manifest_hash, binding, status_vector,
        _ng12_provider_metrics_v1(report); claim_ceiling=screen_only,
        independence_group=plan.provider.independence_group,
        provider_manifest=plan.provider,
        backend_revision=plan.provider.backend_revision,
        numerical_configuration_hash=plan.protocol.protocol_hash,
        artifact_refs=_ng12_provider_artifacts_v1(report),
        uncertainty_or_null=nothing)
end

function execute_native_g1g2_gridap_once!(store,
        plan::NativeG1G2GridapPlanV1)
    store isa AbstractDict || throw(ArgumentError("execution store must be a dictionary"))
    validate_native_g1g2_gridap_plan_v1(plan) ||
        throw(ArgumentError("Gridap plan integrity mismatch"))
    key = plan.solver_input.solver_input_hash
    if haskey(store, key)
        cached = store[key]
        cached isa NativeG1G2ExecutionBundleV1 ||
            throw(ArgumentError("cached native G1/G2 execution bundle type mismatch"))
        validate_native_g1g2_execution_bundle_v1(plan, cached) ||
            throw(ArgumentError("cached native G1/G2 execution bundle integrity mismatch"))
        return cached
    end
    executor_admission_key =
        _ng12_register_executor_plan_admission_v1(plan)
    raw = try
        plan.provider.executor(plan.solver_input)
    finally
        _ng12_unregister_executor_plan_admission_v1!(
            executor_admission_key, plan)
    end
    report = raw.report
    validate_native_g1g2_gridap_report_v1(plan, report) ||
        throw(ArgumentError("native G1/G2 report integrity mismatch"))
    raw.metrics == _ng12_provider_metrics_v1(report) ||
        throw(ArgumentError("provider metrics mismatch"))
    raw.artifacts == _ng12_provider_artifacts_v1(report) ||
        throw(ArgumentError("provider artifacts mismatch"))
    evidence = _ng12_expected_runtime_evidence_v1(plan, report)
    counts = (compiler_calls=1, provider_calls=raw.provider_calls,
        mesh_calls=raw.mesh_calls, assembly_calls=raw.assembly_calls,
        solver_calls=raw.solver_calls, formal_t2_consumer_receipts=0)
    body = _ng12_execution_bundle_body(plan.plan_hash,
        plan.solver_input.solver_input_hash, report, evidence, counts, false)
    bundle = NativeG1G2ExecutionBundleV1(plan.plan_hash,
        plan.solver_input.solver_input_hash, report, evidence, counts, false,
        canonical_hash(body))
    validate_native_g1g2_execution_bundle_v1(plan, bundle) ||
        throw(ArgumentError("native G1/G2 execution bundle integrity mismatch"))
    store[key] = bundle
    bundle
end

function validate_native_g1g2_execution_bundle_v1(plan, bundle)
    try
        validate_native_g1g2_gridap_report_v1(plan, bundle.report) ||
            return false
        bundle.plan_hash == plan.plan_hash || return false
        bundle.solver_input_hash == plan.solver_input.solver_input_hash ||
            return false
        bundle.invocation_counts == (compiler_calls=1, provider_calls=1,
            mesh_calls=3, assembly_calls=6, solver_calls=3,
            formal_t2_consumer_receipts=0) || return false
        !bundle.formal_t2_consumer_receipts_reclassified || return false
        bundle.evidence.solver_input_hash == bundle.solver_input_hash ||
            return false
        canonical_json(bundle.evidence) == canonical_json(
            _ng12_expected_runtime_evidence_v1(plan, bundle.report)) ||
            return false
        canonical_hash(_ng12_execution_bundle_body(bundle.plan_hash,
            bundle.solver_input_hash, bundle.report, bundle.evidence,
            bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified)) ==
            bundle.bundle_hash
    catch
        false
    end
end

"""A local T1 handoff derived from the actual native Gridap execution.

This records execution of the bound local numerical consumer only. It leaves
the source admission/package prepared and does not grant physical or candidate
acceptance credit.
"""
struct NativeG1G2T1RuntimeHandoffV1
    status::Symbol
    resolution::Symbol
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    semantic_identity::Digest256
    wire_hash::Digest256
    t0_bundle_hash::Digest256
    scenario_hash::Digest256
    bundle_hash::Digest256
    report_hash::Digest256
    accepted::Bool
    claim_ceiling::ClaimCeiling
    physical_status::Symbol
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    result_hash::Digest256
end

function _ng12_t1_runtime_handoff_body(status, resolution, candidate_ref,
        package_hash, semantic_identity, wire_hash, t0_bundle_hash,
        scenario_hash, bundle_hash, report_hash, accepted, claim_ceiling,
        physical_status, errors, gaps)
    (domain="native-g1g2-t1-runtime-handoff-v1", status=status,
        resolution=resolution, candidate_ref=candidate_ref,
        package_hash=package_hash, semantic_identity=semantic_identity,
        wire_hash=wire_hash, t0_bundle_hash=t0_bundle_hash,
        scenario_hash=scenario_hash, bundle_hash=bundle_hash,
        report_hash=report_hash, accepted=accepted,
        claim_ceiling=claim_ceiling, physical_status=physical_status,
        errors=errors, gaps=gaps)
end

semantic_view(x::NativeG1G2T1RuntimeHandoffV1) = merge(
    _ng12_t1_runtime_handoff_body(x.status, x.resolution,
        x.candidate_ref, x.package_hash, x.semantic_identity, x.wire_hash,
        x.t0_bundle_hash, x.scenario_hash, x.bundle_hash, x.report_hash,
        x.accepted, x.claim_ceiling, x.physical_status, x.errors, x.gaps),
    (result_hash=x.result_hash,))
canonical_hash(x::NativeG1G2T1RuntimeHandoffV1) = x.result_hash

"""Finalize a T1 handoff only from a verified native Gridap execution bundle.

The admission remains `prepared_not_executed`/`terminal_deferred`; this result
separately records the local numerical execution and keeps its screen-only,
physical-unknown ceiling. Identity or integrity mismatches fail closed.
"""
function finalize_native_g1g2_t1_handoff_v1(admission,
        compilation::NativeG1G2DiffusionCompilationV1,
        plan::NativeG1G2GridapPlanV1,
        bundle::NativeG1G2ExecutionBundleV1)
    admission.status === :prepared_not_executed ||
        throw(ArgumentError("T1 admission status is not prepared_not_executed"))
    admission.resolution === :terminal_deferred ||
        throw(ArgumentError("T1 admission resolution is not terminal_deferred"))
    admission.accepted === false ||
        throw(ArgumentError("T1 admission accepted=true"))
    admission.claim_ceiling === :contract_only ||
        throw(ArgumentError("T1 admission claim ceiling is invalid"))
    isempty(admission.errors) ||
        throw(ArgumentError("T1 admission has errors"))
    package = admission.package
    package isa CandidateStatePackageV5NextV2 ||
        throw(ArgumentError("T1 admission package is missing"))
    FusionConceptAI.vnext_t1_package_v2_validate(package) === nothing ||
        throw(ArgumentError("T1 package integrity mismatch"))

    form = compilation.form
    form.t1_package_hash == package.package_hash ||
        throw(ArgumentError("compiled form T1 package hash mismatch"))
    form.t1_semantic_identity == package.semantic_identity ||
        throw(ArgumentError("compiled form T1 semantic identity mismatch"))
    form.t0_bundle_hash == package.bundle_hash ||
        throw(ArgumentError("compiled form T0 bundle mismatch"))
    form.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("compiled form candidate mismatch"))
    form.t1_package.package_hash == package.package_hash ||
        throw(ArgumentError("compiled form package payload mismatch"))
    canonical_hash(compilation) == canonical_hash(plan.compilation) ||
        throw(ArgumentError("Gridap plan compilation mismatch"))
    compilation.scenario == plan.solver_input.payload.scenario ||
        throw(ArgumentError("Gridap scenario mismatch"))
    validate_native_g1g2_execution_bundle_v1(plan, bundle) ||
        throw(ArgumentError("native Gridap execution bundle integrity mismatch"))

    report = bundle.report
    report.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("Gridap report candidate mismatch"))
    report.t1_package_hash == package.package_hash ||
        throw(ArgumentError("Gridap report package mismatch"))
    report.plan_hash == plan.plan_hash ||
        throw(ArgumentError("Gridap report plan mismatch"))
    report.solver_input_hash == plan.solver_input.solver_input_hash ||
        throw(ArgumentError("Gridap report solver input mismatch"))

    status = report.status === :pass ? :executed_local : :numerical_fail
    errors = report.errors
    gaps = report.gaps
    args = (status, :terminal_deferred, package.candidate_ref,
        package.package_hash, package.semantic_identity, package.wire.sha256,
        package.bundle_hash, canonical_hash(compilation.scenario),
        bundle.bundle_hash, report.report_hash, false, screen_only,
        :unknown, errors, gaps)
    NativeG1G2T1RuntimeHandoffV1(args...,
        canonical_hash(_ng12_t1_runtime_handoff_body(args...)))
end

function validate_native_g1g2_t1_runtime_handoff_v1(admission,
        compilation::NativeG1G2DiffusionCompilationV1,
        plan::NativeG1G2GridapPlanV1,
        bundle::NativeG1G2ExecutionBundleV1,
        result::NativeG1G2T1RuntimeHandoffV1)
    try
        expected = finalize_native_g1g2_t1_handoff_v1(admission,
            compilation, plan, bundle)
        canonical_json(expected) == canonical_json(result)
    catch
        false
    end
end

export NativeG1G2T1RuntimeHandoffV1,
    finalize_native_g1g2_t1_handoff_v1,
    validate_native_g1g2_t1_runtime_handoff_v1

"""One-level wrong-sign negative control; it never enters a passing report."""
function run_native_g1g2_wrong_sign_control_v1(
        plan::NativeG1G2GridapPlanV1; level::Integer=2)
    result = run_native_g1g2_gridap_level_v1(plan, level;
        source_sign=:reversed_test_control)
    result.status === :numerical_fail ||
        throw(ArgumentError("wrong-sign control unexpectedly passed"))
    result
end

struct NativeG1G2DownstreamInputLinkV1
    candidate_ref::QualifiedRefV1
    t1_package_hash::Digest256
    numerical_bundle_hash::Digest256
    solver_input_hash::Digest256
    t2_ledger_hash::Union{Nothing,Digest256}
    t2_input_hash::Union{Nothing,Digest256}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::ClaimCeiling
    same_candidate_validated::Bool
    formal_t2_consumer_receipts_reclassified::Bool
    numerical_invocation_counts::NamedTuple
    gaps::Tuple{Vararg{Symbol}}
    link_hash::Digest256
end

function _ng12_downstream_link_body(candidate_ref, t1_package_hash,
        numerical_bundle_hash, solver_input_hash, t2_ledger_hash,
        t2_input_hash, status,
        resolution, accepted, claim_ceiling, same_candidate_validated,
        formal_t2_consumer_receipts_reclassified,
        numerical_invocation_counts, gaps)
    (domain="native-g1g2-downstream-input-link-v1",
        candidate_ref=candidate_ref, t1_package_hash=t1_package_hash,
        numerical_bundle_hash=numerical_bundle_hash,
        solver_input_hash=solver_input_hash,
        t2_ledger_hash=t2_ledger_hash, t2_input_hash=t2_input_hash,
        status=status,
        resolution=resolution, accepted=accepted,
        claim_ceiling=claim_ceiling,
        same_candidate_validated=same_candidate_validated,
        formal_t2_consumer_receipts_reclassified=
            formal_t2_consumer_receipts_reclassified,
        numerical_invocation_counts=numerical_invocation_counts,
        gaps=gaps)
end

semantic_view(x::NativeG1G2DownstreamInputLinkV1) = merge(
    _ng12_downstream_link_body(x.candidate_ref, x.t1_package_hash,
        x.numerical_bundle_hash, x.solver_input_hash, x.t2_ledger_hash,
        x.t2_input_hash, x.status, x.resolution, x.accepted, x.claim_ceiling,
        x.same_candidate_validated,
        x.formal_t2_consumer_receipts_reclassified,
        x.numerical_invocation_counts, x.gaps), (link_hash=x.link_hash,))
canonical_hash(x::NativeG1G2DownstreamInputLinkV1) = x.link_hash

function _ng12_validate_actual_t2_ledger_v1(input, ledger, report)
    required = (:VNextT2ReceiptLedgerV2,
        :VNextT2UP2BoundInputV2,
        :VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2,
        :VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2,
        :VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2,
        :VNEXT_T2_CONSUMER_ORDER_V2,
        :VNEXT_T2_UP2_CLAIM_CEILING_V2,
        :vnext_t2_up2_validate_input_v2,
        :_vnext_t2_stage_input_hash_v2,
        :_vnext_t2_invocation_receipt_body_v2,
        :_vnext_t2_receipt_ledger_body_v2)
    all(name -> isdefined(FusionConceptAI, name), required) || return false
    ledger isa getfield(FusionConceptAI, :VNextT2ReceiptLedgerV2) ||
        return false
    input isa getfield(FusionConceptAI, :VNextT2UP2BoundInputV2) ||
        return false
    validation = getfield(FusionConceptAI,
        :vnext_t2_up2_validate_input_v2)(input)
    validation.status === :valid || return false
    input.package.candidate_ref == report.candidate_ref || return false
    input.package.package_hash == report.t1_package_hash || return false
    ledger.schema_id == getfield(FusionConceptAI,
        :VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2) || return false
    ledger.schema_version == getfield(FusionConceptAI,
        :VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2) || return false
    ledger.profile == getfield(FusionConceptAI,
        :VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2) || return false
    ledger.candidate_ref == report.candidate_ref || return false
    ledger.package_hash == report.t1_package_hash || return false
    ledger.input_hash == input.input_hash || return false
    ledger.scenario == input.scenario || return false
    ledger.profile == input.profile || return false
    ledger.status === :complete_contract_receipts &&
        ledger.resolution === :terminal_deferred && !ledger.accepted ||
        return false
    ledger.claim_ceiling == getfield(FusionConceptAI,
        :VNEXT_T2_UP2_CLAIM_CEILING_V2) || return false
    ledger.counts == getfield(FusionConceptAI,
        :VNextT2InvocationCountsV2)(1, 1, 1, 1, 1, 0, 0, 0) || return false
    Tuple(receipt.consumer_id for receipt in ledger.receipts) ==
        getfield(FusionConceptAI, :VNEXT_T2_CONSUMER_ORDER_V2) || return false
    receipts = ledger.receipts
    stage_hash = getfield(FusionConceptAI, :_vnext_t2_stage_input_hash_v2)
    expected_stage_inputs = (input.input_hash,
        stage_hash(input.input_hash, :GI1A, receipts[1].output_hash),
        stage_hash(input.input_hash, :E1, receipts[2].output_hash),
        stage_hash(input.input_hash, :E2, receipts[2].output_hash),
        stage_hash(input.input_hash, :UP2_N10,
            input.formal_gate.identity_hash))
    Tuple(receipt.input_hash for receipt in receipts) ==
        expected_stage_inputs || return false
    receipt_profile = first(ledger.receipts).profile
    receipt_profile == input.profile || return false
    for receipt in ledger.receipts
        receipt.t1_package_hash == ledger.package_hash || return false
        receipt.candidate_ref == ledger.candidate_ref || return false
        receipt.scenario == ledger.scenario || return false
        receipt.profile == receipt_profile || return false
        receipt.invocation_count == 1 || return false
        body = getfield(FusionConceptAI,
            :_vnext_t2_invocation_receipt_body_v2)(receipt.consumer_id,
            receipt.t1_package_hash, receipt.candidate_ref,
            receipt.scenario, receipt.profile, receipt.input_hash,
            receipt.output_hash, receipt.invocation_count, receipt.status,
            receipt.resolution)
        receipt.identity_hash == canonical_hash(body) || return false
    end
    all(gap -> gap in ledger.gaps,
        (:compiler_not_executed, :provider_not_executed,
            :solver_not_executed)) || return false
    body = getfield(FusionConceptAI,
        :_vnext_t2_receipt_ledger_body_v2)(ledger.schema_id,
        ledger.schema_version, ledger.profile, ledger.candidate_ref,
        ledger.scenario, ledger.input_hash, ledger.package_hash,
        ledger.receipts, ledger.counts, ledger.status, ledger.resolution,
        ledger.accepted, ledger.claim_ceiling, ledger.gaps)
    ledger.ledger_hash == canonical_hash(body)
end

function native_g1g2_downstream_input_link_v1(
        plan::NativeG1G2GridapPlanV1,
        bundle::NativeG1G2ExecutionBundleV1)
    validate_native_g1g2_execution_bundle_v1(plan, bundle) ||
        throw(ArgumentError("native G1/G2 execution bundle is invalid"))
    report = bundle.report
    gaps = Tuple(unique((report.gaps...,
        :qualified_t2_receipt_ledger_required)))
    args = (report.candidate_ref, report.t1_package_hash,
        bundle.bundle_hash, bundle.solver_input_hash, nothing, nothing,
        :pending_qualified_t2, :terminal_deferred, false, screen_only,
        false, false, bundle.invocation_counts, gaps)
    NativeG1G2DownstreamInputLinkV1(args...,
        canonical_hash(_ng12_downstream_link_body(args...)))
end

function native_g1g2_downstream_input_link_v1(
        plan::NativeG1G2GridapPlanV1,
        bundle::NativeG1G2ExecutionBundleV1, t2_input, ledger)
    validate_native_g1g2_execution_bundle_v1(plan, bundle) ||
        throw(ArgumentError("native G1/G2 execution bundle is invalid"))
    report = bundle.report
    _ng12_validate_actual_t2_ledger_v1(t2_input, ledger, report) ||
        throw(ArgumentError("actual qualified T2 receipt ledger is invalid"))
    gaps = Tuple(unique((report.gaps...,
        :t2_contract_receipts_do_not_cover_numerical_provider)))
    args = (report.candidate_ref, report.t1_package_hash,
        bundle.bundle_hash, bundle.solver_input_hash, ledger.ledger_hash,
        t2_input.input_hash,
        :same_candidate_t2_link_validated, :terminal_deferred, false,
        screen_only, true, false, bundle.invocation_counts, gaps)
    NativeG1G2DownstreamInputLinkV1(args...,
        canonical_hash(_ng12_downstream_link_body(args...)))
end


const _NG12_SCALAR_HEAT_LIFT_SERVICE_V1 = :native_g1g2_gridap_scalar_heat_lift
const _NG12_SCALAR_HEAT_LIFT_SCHEMA_V1 = "native-g1g2-gridap-scalar-heat-lift-v1"

struct NativeG1G2ScalarHeatLiftResultV1
    candidate_ref::Any
    scenario_id::String
    t1_package_hash::Digest256
    g1_declaration_hash::Digest256
    g1_source_ref::Any
    g1_source_hash::Digest256
    g2_declaration_hash::Digest256
    g2_source_ref::Any
    g2_source_hash::Digest256
    plan_hash::Digest256
    report_hash::Digest256
    authored_obligation_hash::Digest256
    source_sign::Symbol
    reference_temperature_k::Float64
    temperature_scale_k::Float64
    conductivity_scale_w_m_k::Float64
    source_integral_m::Float64
    source_power_w::Float64
    source_power_limit_w::Float64
    probe_sample::NamedTuple
    result_hash::Digest256
end

const _NG12_HEAT_LIFT_RECEIPT_SEAL_V1 = Ref{Nothing}(nothing)

struct NativeG1G2ScalarHeatLiftServiceReceiptV1
    service::Symbol
    obligation::CapabilitySignatureV4
    provider::ProviderManifestV4
    match::ProviderMatchResultV4
    result::NativeG1G2ScalarHeatLiftResultV1
    receipt_hash::Digest256
    function NativeG1G2ScalarHeatLiftServiceReceiptV1(service::Symbol,
            obligation::CapabilitySignatureV4, provider::ProviderManifestV4,
            matched::ProviderMatchResultV4, result::NativeG1G2ScalarHeatLiftResultV1,
            receipt_hash::Digest256, seal::Base.RefValue{Nothing})
        seal === _NG12_HEAT_LIFT_RECEIPT_SEAL_V1 ||
            throw(ArgumentError("native scalar heat-lift receipt requires runtime minting"))
        new(service, obligation, provider, matched, result, receipt_hash)
    end
end

function _ng12_scalar_heat_lift_service_receipt_body(service, obligation,
        provider, matched, result)
    (service=service, obligation_hash=canonical_hash(obligation),
        provider_manifest_hash=provider.manifest_hash,
        match_status=matched.status, result_hash=canonical_hash(result))
end

semantic_view(x::NativeG1G2ScalarHeatLiftServiceReceiptV1) = merge(
    _ng12_scalar_heat_lift_service_receipt_body(x.service, x.obligation,
        x.provider, x.match, x.result), (receipt_hash=x.receipt_hash,))
canonical_hash(x::NativeG1G2ScalarHeatLiftServiceReceiptV1) = x.receipt_hash

function _ng12_scalar_heat_lift_body(candidate_ref, scenario_id, t1_package_hash,
        g1_declaration_hash, g1_source_ref, g1_source_hash,
        g2_declaration_hash, g2_source_ref, g2_source_hash, plan_hash,
        report_hash, authored_obligation_hash, source_sign, reference_temperature_k,
        temperature_scale_k, conductivity_scale_w_m_k, source_integral_m,
        source_power_w, source_power_limit_w, probe_sample)
    (domain=_NG12_SCALAR_HEAT_LIFT_SCHEMA_V1, candidate_ref=candidate_ref,
        scenario_id=scenario_id,
        t1_package_hash=t1_package_hash,
        g1_declaration_hash=g1_declaration_hash,
        g1_source_ref=g1_source_ref, g1_source_hash=g1_source_hash,
        g2_declaration_hash=g2_declaration_hash, g2_source_ref=g2_source_ref,
        g2_source_hash=g2_source_hash,
        plan_hash=plan_hash, report_hash=report_hash,
        authored_obligation_hash=authored_obligation_hash, source_sign=source_sign,
        reference_temperature_k=reference_temperature_k,
        temperature_scale_k=temperature_scale_k,
        conductivity_scale_w_m_k=conductivity_scale_w_m_k,
        source_integral_m=source_integral_m, source_power_w=source_power_w,
        source_power_limit_w=source_power_limit_w, probe_sample=probe_sample)
end

semantic_view(x::NativeG1G2ScalarHeatLiftResultV1) = merge(
    _ng12_scalar_heat_lift_body(x.candidate_ref, x.scenario_id,
        x.t1_package_hash, x.g1_declaration_hash, x.g1_source_ref,
        x.g1_source_hash, x.g2_declaration_hash, x.g2_source_ref, x.g2_source_hash,
        x.plan_hash, x.report_hash, x.authored_obligation_hash, x.source_sign,
        x.reference_temperature_k, x.temperature_scale_k,
        x.conductivity_scale_w_m_k, x.source_integral_m, x.source_power_w,
        x.source_power_limit_w, x.probe_sample),
    (result_hash=x.result_hash,))
canonical_hash(x::NativeG1G2ScalarHeatLiftResultV1) = x.result_hash

function _ng12_scalar_heat_lift_probe_sample_v1(form, domain, tref, theta, kappa)
    # The noncentered point makes the Fourier-flux sign observable.
    probe_point = ntuple(i -> domain[2i-1] +
        (domain[2i] - domain[2i-1]) * (i == 1 ? 1 // 3 : 1 // 2), 3)
    u = native_g1g2_reference_value_v1(form, probe_point)
    grad_u = native_g1g2_reference_gradient_v1(form, probe_point)
    kdiag = native_g1g2_k_diagonal_v1(form, probe_point)
    f = native_g1g2_source_value_v1(form, probe_point)
    field_units = (point=UnitSignature((1, 0, 0, 0, 0, 0, 0)),
        u_dimensionless=UnitSignature(),
        temperature=UnitSignature((0, 0, 0, 0, 1, 0, 0)),
        conductivity=UnitSignature((1, 1, -3, 0, -1, 0, 0)),
        gradient_temperature=UnitSignature((-1, 0, 0, 0, 1, 0, 0)),
        conductive_flux=UnitSignature((0, 1, -3, 0, 0, 0, 0)),
        source_density=UnitSignature((-1, 1, -3, 0, 0, 0, 0)),
        source_integral=UnitSignature((1, 0, 0, 0, 0, 0, 0)),
        source_power=UnitSignature((2, 1, -3, 0, 0, 0, 0)),
        source_power_limit=UnitSignature((2, 1, -3, 0, 0, 0, 0)))
    (point_m=probe_point, u_dimensionless=u,
        temperature_k=tref + theta * u,
        conductivity_diagonal_w_m_k=ntuple(i -> kappa * kdiag[i], 3),
        gradient_temperature_k_m=ntuple(i -> theta * grad_u[i], 3),
        conductive_flux_w_m2=ntuple(i -> -kappa * theta * kdiag[i] * grad_u[i], 3),
        source_density_w_m3=kappa * theta * f,
        heat_flux_convention=:fourier_q_equals_minus_k_grad_temperature,
        source_balance_convention=:div_fourier_q_equals_source,
        units=field_units)
end

function _ng12_scalar_heat_lift_executor_v1(plan::NativeG1G2GridapPlanV1,
        report::NativeG1G2GridapReportV1, capability::CapabilitySignatureV4,
        authored_heat_lift::NamedTuple)
    validate_native_g1g2_gridap_report_v1(plan, report) ||
        throw(ArgumentError("scalar heat lift requires an exact validated Gridap report"))
    report.status === :pass && all(level -> level.source_sign === :declared &&
        level.status === :pass, report.levels) ||
        throw(ArgumentError("scalar heat lift requires passing declared-sign levels"))
    required = (:schema, :version, :candidate_id, :scenario_id,
        :reference_temperature_k, :temperature_scale_k,
        :conductivity_scale_w_m_k, :source_unit_basis, :native_unit_basis,
        :native_basis_permutation, :source_operator, :budget_join)
    all(name -> name in keys(authored_heat_lift), required) ||
        throw(ArgumentError("G3 authored heat-lift obligation is incomplete"))
    authored_heat_lift.schema == "g3-authored-scalar-heat-lift-v1" &&
        authored_heat_lift.source_operator === :minus_div_k_grad ||
        throw(ArgumentError("G3 authored heat-lift schema or source operator is unsupported"))
    authored_heat_lift.reference_temperature_k == 293 // 1 &&
        authored_heat_lift.temperature_scale_k == 1 // 1 &&
        authored_heat_lift.conductivity_scale_w_m_k == 1 // 1 ||
        throw(ArgumentError("G3 authored heat-lift constants differ from the authorized 293K/1K/1W(mK) lift"))
    form = plan.compilation.form
    candidate_prefix = "fusionconceptai://candidate-design/"
    startswith(form.candidate_ref.id, candidate_prefix) ||
        throw(ArgumentError("native G1/G2 candidate ref is outside the local candidate-design namespace"))
    expected_candidate_id = form.candidate_ref.id[length(candidate_prefix)+1:end]
    authored_heat_lift.version == "v1" &&
        authored_heat_lift.candidate_id == expected_candidate_id &&
        authored_heat_lift.scenario_id == plan.compilation.scenario.scenario_id &&
        authored_heat_lift.source_unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) &&
        authored_heat_lift.native_unit_basis == (:m, :kg, :s, :A, :K, :mol, :cd) &&
        authored_heat_lift.native_basis_permutation == (2, 1, 3, 4, 5, 6, 7) ||
        throw(ArgumentError("G3 authored heat-lift candidate/scenario or unit-basis conversion is stale/unsupported"))
    budget = authored_heat_lift.budget_join
    all(name -> name in keys(budget),
        (:entry_id, :account_id, :port_id, :component_id, :coefficient_w, :limit_w)) &&
        budget.entry_id == "field_allocation" &&
        budget.account_id == "design_energy" &&
        budget.port_id == "diffusion_load" &&
        budget.component_id == "diffusion_core" &&
        budget.coefficient_w isa Real && !(budget.coefficient_w isa Bool) &&
        budget.limit_w == abs(budget.coefficient_w) && budget.limit_w > 0 ||
        throw(ArgumentError("G3 authored heat-lift budget is not the current field_allocation ledger join"))
    scales = (authored_heat_lift.reference_temperature_k,
        authored_heat_lift.temperature_scale_k,
        authored_heat_lift.conductivity_scale_w_m_k,
        budget.limit_w)
    all(value -> value isa Real && !(value isa Bool) && isfinite(Float64(value)), scales) ||
        throw(ArgumentError("G3 authored heat-lift scales or field-allocation budget are invalid"))
    tref, theta, kappa, limit = Float64.(scales)
    all(isfinite, (tref, theta, kappa, limit)) && tref > 0 && theta > 0 &&
        kappa > 0 && limit > 0 ||
        throw(ArgumentError("scalar heat lift scales and source budget must be finite and positive"))
    level = report.levels[3]
    abs(level.assembled_source_integral - level.analytic_source_integral) <=
        plan.protocol.source_integral_abs_tol ||
        throw(ArgumentError("assembled source integral disagrees with analytic source integral"))
    power = kappa * theta * level.assembled_source_integral
    isfinite(power) && power >= 0 && power <= limit ||
        throw(ArgumentError("lifted source power is negative, non-finite, or exceeds the G3 source budget"))
    domain = level.physical_domain
    form = plan.compilation.form
    sample = _ng12_scalar_heat_lift_probe_sample_v1(form, domain, tref, theta, kappa)
    expected_capability = _ng12_scalar_heat_lift_capability_v1(plan, report,
        authored_heat_lift)
    canonical_hash(expected_capability) == canonical_hash(capability) ||
        throw(ArgumentError("scalar heat lift capability does not bind this report and authored lift"))
    body = _ng12_scalar_heat_lift_body(report.candidate_ref,
        plan.compilation.scenario.scenario_id, report.t1_package_hash,
        form.g1_declaration.declaration_hash, form.g1_declaration.source_ref,
        form.g1_declaration.source_hash, form.g2_declaration.declaration_hash,
        form.g2_declaration.source.source_ref,
        form.g2_declaration.source.source_hash,
        report.plan_hash, report.report_hash, canonical_hash(authored_heat_lift),
        level.source_sign, tref, theta,
        kappa, level.assembled_source_integral, power, limit, sample)
    NativeG1G2ScalarHeatLiftResultV1(report.candidate_ref,
        plan.compilation.scenario.scenario_id, report.t1_package_hash,
        form.g1_declaration.declaration_hash, form.g1_declaration.source_ref,
        form.g1_declaration.source_hash,
        form.g2_declaration.declaration_hash, form.g2_declaration.source.source_ref,
        form.g2_declaration.source.source_hash, report.plan_hash,
        report.report_hash, canonical_hash(authored_heat_lift),
        level.source_sign, tref, theta, kappa,
        level.assembled_source_integral, power, limit, sample,
        canonical_hash(body))
end

function _ng12_scalar_heat_lift_capability_v1(plan::NativeG1G2GridapPlanV1,
        report::NativeG1G2GridapReportV1, authored_heat_lift::NamedTuple)
    validate_native_g1g2_gridap_report_v1(plan, report) ||
        throw(ArgumentError("scalar heat lift capability requires a validated report"))
    form = plan.compilation.form
    applicability = canonical_hash((service=_NG12_SCALAR_HEAT_LIFT_SERVICE_V1,
        candidate_ref=report.candidate_ref, package_hash=report.t1_package_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        g2_source_hash=form.g2_declaration.source.source_hash,
        plan_hash=report.plan_hash, report_hash=report.report_hash,
        source_sign=report.levels[3].source_sign,
        authored_heat_lift=authored_heat_lift))
    input_hash = canonical_hash((schema=_NG12_SCALAR_HEAT_LIFT_SCHEMA_V1,
        revision="v1", plan_hash=report.plan_hash, report_hash=report.report_hash,
        g1_hash=form.g1_declaration.declaration_hash,
        g2_hash=form.g2_declaration.declaration_hash,
        authored_heat_lift=authored_heat_lift))
    CapabilitySignatureV4(_NG12_SCALAR_HEAT_LIFT_SCHEMA_V1, "v1",
        _NG12_SCALAR_HEAT_LIFT_SERVICE_V1,
        "lift_authored_scalar_diffusion_to_heat", ("u", "K", "f"),
        "dimensionless_g1_scalar_field", "temperature_conductivity_heat_source",
        3, ("x", "y", "z"), "candidate_physical_domain",
        "native_g1g2_report_validated", "steady",
        ("T:K", "k:W_m_K", "q:W_m2", "source:W_m3", "integral:W"),
        screen_only, applicability; input_schema_hash=input_hash,
        coordinate_system="candidate_physical_cartesian")
end

function native_g1g2_gridap_scalar_heat_lift_service_v1(
        plan::NativeG1G2GridapPlanV1, report::NativeG1G2GridapReportV1,
        source_context::NamedTuple)
    authored_heat_lift = _ng12_validated_scalar_heat_lift_source_v1(
        plan, source_context)
    capability = _ng12_scalar_heat_lift_capability_v1(plan, report,
        authored_heat_lift)
    domain = (bounds_hash=capability.applicability_bounds,
        candidate_ref=report.candidate_ref, plan_hash=report.plan_hash,
        report_hash=report.report_hash,
        g1_declaration_hash=plan.compilation.form.g1_declaration.declaration_hash,
        g2_declaration_hash=plan.compilation.form.g2_declaration.declaration_hash,
        source_integral_m=report.levels[3].assembled_source_integral,
        authored_obligation_hash=canonical_hash(authored_heat_lift))
    provider = ProviderManifestV4(capability.schema, capability.revision,
        capability.kind, capability, domain, NATIVE_G1G2_GRIDAP_BACKEND_V1,
        "scalar-heat-lift-v1", plan.adapter_source_hash,
        "gridap-native-g1g2-scalar-heat-lift-v1", screen_only;
        input_schema_hash=capability.input_schema_hash,
        executor=_ng12_scalar_heat_lift_executor_v1)
    matched = match_provider(capability, (provider,))
    matched.status === unique_match && matched.provider === provider ||
        throw(ArgumentError("native scalar heat lift provider did not uniquely match its capability"))
    result = provider.executor(plan, report, capability, authored_heat_lift)
    body = _ng12_scalar_heat_lift_service_receipt_body(
        _NG12_SCALAR_HEAT_LIFT_SERVICE_V1, capability, provider, matched, result)
    NativeG1G2ScalarHeatLiftServiceReceiptV1(
        _NG12_SCALAR_HEAT_LIFT_SERVICE_V1, capability, provider, matched,
        result, canonical_hash(body), _NG12_HEAT_LIFT_RECEIPT_SEAL_V1)
end

function _ng12_validated_scalar_heat_lift_source_v1(
        plan::NativeG1G2GridapPlanV1, source_context::NamedTuple)
    required_context = (:candidate_ref, :candidate_id, :scenario_id,
        :identity_hash, :source_sha256, :source_pin_sha256, :source_path,
        :source_accounts, :account_owners, :owner_scope_account_membership,
        :entries, :accounts, :closures, :balances, :authored_heat_lift,
        :unit_basis, :resource_network, :effort_ports_without_ledger,
        :authored_power_laws, :control_resource_links, :command_to_current_map,
        :command_to_power_map, :power_status_signal_id)
    all(name -> name in keys(source_context), required_context) ||
        throw(ArgumentError("scalar heat lift requires the rebuilt typed G3 source context"))
    form = plan.compilation.form
    package = form.t1_package
    source_context.candidate_ref == form.candidate_ref == package.candidate_ref &&
        source_context.candidate_id == last(split(form.candidate_ref.id, '/')) &&
        source_context.scenario_id == plan.compilation.scenario.scenario_id &&
        source_context.identity_hash isa Digest256 &&
        source_context.source_sha256 isa Digest256 &&
        source_context.source_pin_sha256 isa Digest256 &&
        source_context.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) &&
        source_context.source_sha256 == source_context.source_pin_sha256 ||
        throw(ArgumentError("scalar heat-lift G3 context differs from the native T1 candidate identity"))

    # Independently bind the supplied G3 child pin to every source carrier in
    # the actual T1 package embedded in the admitted native plan.
    children = package.children
    length(children) == 3 && all(child -> child.source_bytes !== nothing &&
        child.source_bytes.sha256 == source_context.source_pin_sha256 &&
        Digest256(bytes2hex(SHA.sha256(copy_bytes(child.source_bytes)))) ==
            source_context.source_pin_sha256, children) ||
        throw(ArgumentError("scalar heat-lift G3 child source pin differs from the native T1 package carriers"))

    # Rebind every value consumed below to the frozen G3 semantic body carried
    # by the actual native T1 package. A caller-supplied NamedTuple and its
    # identity hash are not source authority by themselves.
    g3_declarations = Tuple(d for d in package.declarations if d.layer === :G3)
    length(g3_declarations) == 1 ||
        throw(ArgumentError("scalar heat lift requires one G3 declaration in the native T1 package"))
    runtime_module = FusionConceptAI
    n03_get = getfield(runtime_module, :_n03_get)
    wire_equal = getfield(runtime_module, :_up2_vnext_wire_semantic_equal)
    semantic_equal(wire, value) = Base.invokelatest(wire_equal, wire, value)
    json3 = getfield(runtime_module, :JSON3)
    declaration_wire = Base.invokelatest(getfield(json3, :read),
        String(copy_bytes(only(g3_declarations).semantic_body_bytes)))
    t1_wire_bytes = copy_bytes(package.wire)
    package.wire.sha256 == Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(t1_wire_bytes)))) ||
        throw(ArgumentError("native T1 package wire SHA-256 mismatch"))
    t1_wire = Base.invokelatest(getfield(json3, :read), String(t1_wire_bytes))
    wire_children = Base.invokelatest(n03_get, t1_wire, :children)
    binding_children = Tuple(child for child in package.children if
        child.kind === :binding)
    binding_rows = Tuple(child for child in wire_children if
        String(Base.invokelatest(n03_get, child, :kind)) == "binding")
    length(binding_children) == length(binding_rows) == 1 ||
        throw(ArgumentError("native T1 package requires one G3 binding child"))
    binding_child = only(binding_children)
    binding_wire_body = Base.invokelatest(n03_get, only(binding_rows), :body)
    g3_ref_fn = getfield(runtime_module, :g3_contract_ref)
    binding_contract_ref = Base.invokelatest(g3_ref_fn, :binding)
    binding_child.status === :present &&
        semantic_view(binding_child.candidate_ref) == semantic_view(form.candidate_ref) &&
        Base.invokelatest(getfield(runtime_module, :_up2_vnext_g2_ref_matches),
            Base.invokelatest(n03_get, only(binding_rows), :candidate_ref),
            form.candidate_ref) &&
        binding_child.body_hash == canonical_hash(
            getfield(runtime_module, :_up2_n10_json_semantic)(binding_wire_body)) &&
        semantic_equal(Base.invokelatest(n03_get, binding_wire_body, :contract_ref),
            binding_contract_ref) ||
        throw(ArgumentError("native T1 G3 binding child contract ref differs from g3_contract_ref(:binding)"))
    ledger_wire = Base.invokelatest(n03_get, declaration_wire,
        :authored_typed_ledger_source)
    child_design_wire = Base.invokelatest(n03_get, declaration_wire,
        :authored_child_design)
    ledger_wire === nothing &&
        throw(ArgumentError("native T1 G3 declaration has no authored typed ledger source"))
    child_design_wire === nothing &&
        throw(ArgumentError("native T1 G3 declaration has no authored child design source"))
    wire_source_sha = Base.invokelatest(n03_get,
        Base.invokelatest(n03_get, ledger_wire, :source_sha256), :value)
    wire_identity = Base.invokelatest(n03_get,
        Base.invokelatest(n03_get, ledger_wire, :identity_hash), :value)
    wire_lift = Base.invokelatest(n03_get, ledger_wire, :authored_heat_lift)
    child_lift = Base.invokelatest(n03_get, child_design_wire,
        :authored_heat_lift)
    ref_matches = getfield(runtime_module, :_up2_vnext_g2_ref_matches)
    Base.invokelatest(ref_matches,
        Base.invokelatest(n03_get, ledger_wire, :candidate_ref),
        source_context.candidate_ref) &&
        Base.invokelatest(n03_get, ledger_wire, :candidate_id) ==
            source_context.candidate_id &&
        Base.invokelatest(n03_get, ledger_wire, :scenario_id) ==
            source_context.scenario_id &&
        Base.invokelatest(n03_get, ledger_wire, :source_path) ==
            source_context.source_path &&
        wire_source_sha == source_context.source_sha256.value &&
        wire_identity == source_context.identity_hash.value &&
        semantic_equal(wire_lift, source_context.authored_heat_lift) &&
        semantic_equal(child_lift, source_context.authored_heat_lift) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :source_accounts),
            source_context.source_accounts) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :account_owners),
            source_context.account_owners) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire,
            :owner_scope_account_membership),
            source_context.owner_scope_account_membership) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :entries),
            source_context.entries) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :accounts),
            source_context.accounts) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :closures),
            source_context.closures) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :balances),
            source_context.balances) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :unit_basis),
            source_context.unit_basis) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire, :resource_network),
            source_context.resource_network) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire,
            :effort_ports_without_ledger), source_context.effort_ports_without_ledger) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire,
            :authored_power_laws), source_context.authored_power_laws) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire,
            :control_resource_links), source_context.control_resource_links) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire,
            :command_to_current_map), source_context.command_to_current_map) &&
        semantic_equal(Base.invokelatest(n03_get, ledger_wire,
            :command_to_power_map), source_context.command_to_power_map) &&
        Base.invokelatest(n03_get, ledger_wire, :power_status_signal_id) ==
            source_context.power_status_signal_id ||
        throw(ArgumentError("scalar heat-lift typed context differs from the actual native T1 G3 wire body"))

    lift = source_context.authored_heat_lift
    lift isa NamedTuple ||
        throw(ArgumentError("scalar heat-lift authored source tuple is absent"))
    candidate_id = form.candidate_ref.id[length("fusionconceptai://candidate-design/")+1:end]
    lift.candidate_id == source_context.candidate_id == candidate_id &&
        lift.scenario_id == source_context.scenario_id ||
        throw(ArgumentError("scalar heat-lift tuple differs from its validated G3 source identity"))
    budget = lift.budget_join
    matches = Tuple(entry for entry in source_context.entries
        if entry.entry_id == budget.entry_id)
    length(matches) == 1 ||
        throw(ArgumentError("scalar heat-lift budget entry is missing or duplicated in the typed ledger"))
    entry = only(matches)
    account_matches = Tuple(account for account in source_context.accounts
        if account.account_id == entry.account_id)
    length(account_matches) == 1 ||
        throw(ArgumentError("scalar heat-lift ledger account is missing or duplicated"))
    account = only(account_matches)
    source_watts = UnitSignature((1, 2, -3, 0, 0, 0, 0))
    entry.account_id == budget.account_id == "design_energy" &&
        entry.port_id == budget.port_id == "diffusion_load" &&
        entry.component_id == budget.component_id == "diffusion_core" &&
        entry.coefficient == budget.coefficient_w == -500 &&
        entry.unit == account.unit == source_watts && account.domain === :energy &&
        budget.limit_w == abs(entry.coefficient) ||
        throw(ArgumentError("scalar heat-lift budget join differs from the pinned typed ledger entry"))
    lift
end

function validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
        plan::NativeG1G2GridapPlanV1, report::NativeG1G2GridapReportV1,
        source_context::NamedTuple,
        receipt::NativeG1G2ScalarHeatLiftServiceReceiptV1)
    try
        form = plan.compilation.form
        authored_heat_lift = _ng12_validated_scalar_heat_lift_source_v1(
            plan, source_context)
        validate_native_g1g2_gridap_report_v1(plan, report) || return false
        receipt.service === _NG12_SCALAR_HEAT_LIFT_SERVICE_V1 || return false
        required = (:schema, :version, :candidate_id, :scenario_id,
            :reference_temperature_k, :temperature_scale_k,
            :conductivity_scale_w_m_k, :source_unit_basis, :native_unit_basis,
            :native_basis_permutation, :source_operator, :budget_join)
        all(name -> name in keys(authored_heat_lift), required) || return false
        authored_heat_lift.schema == "g3-authored-scalar-heat-lift-v1" &&
            authored_heat_lift.source_operator === :minus_div_k_grad &&
            authored_heat_lift.reference_temperature_k == 293 // 1 &&
            authored_heat_lift.temperature_scale_k == 1 // 1 &&
            authored_heat_lift.conductivity_scale_w_m_k == 1 // 1 &&
            authored_heat_lift.version == "v1" &&
            authored_heat_lift.candidate_id ==
                form.candidate_ref.id[length("fusionconceptai://candidate-design/")+1:end] &&
            authored_heat_lift.scenario_id == plan.compilation.scenario.scenario_id &&
            authored_heat_lift.source_unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) &&
            authored_heat_lift.native_unit_basis == (:m, :kg, :s, :A, :K, :mol, :cd) &&
            authored_heat_lift.native_basis_permutation == (2, 1, 3, 4, 5, 6, 7) || return false
        budget = authored_heat_lift.budget_join
        all(name -> name in keys(budget),
            (:entry_id, :account_id, :port_id, :component_id, :coefficient_w, :limit_w)) &&
            budget.entry_id == "field_allocation" &&
            budget.account_id == "design_energy" &&
            budget.port_id == "diffusion_load" &&
            budget.component_id == "diffusion_core" &&
            budget.coefficient_w isa Real && !(budget.coefficient_w isa Bool) &&
            budget.limit_w == abs(budget.coefficient_w) && budget.limit_w > 0 || return false
        authored_heat_lift.candidate_id ==
            form.candidate_ref.id[length("fusionconceptai://candidate-design/")+1:end] || return false
        expected = _ng12_scalar_heat_lift_capability_v1(plan, report,
            authored_heat_lift)
        canonical_hash(expected) == canonical_hash(receipt.obligation) || return false
        matched = match_provider(expected, (receipt.provider,))
        matched.status === unique_match && matched.provider === receipt.provider &&
            receipt.match.status === unique_match &&
            receipt.match.provider === receipt.provider || return false
        expected_domain = (bounds_hash=expected.applicability_bounds,
            candidate_ref=report.candidate_ref, plan_hash=report.plan_hash,
            report_hash=report.report_hash,
            g1_declaration_hash=plan.compilation.form.g1_declaration.declaration_hash,
            g2_declaration_hash=plan.compilation.form.g2_declaration.declaration_hash,
            source_integral_m=report.levels[3].assembled_source_integral,
            authored_obligation_hash=canonical_hash(authored_heat_lift))
        canonical_hash(receipt.provider.domain) == canonical_hash(expected_domain) &&
            receipt.provider.backend == NATIVE_G1G2_GRIDAP_BACKEND_V1 &&
            receipt.provider.backend_revision == "scalar-heat-lift-v1" &&
            receipt.provider.code_hash == plan.adapter_source_hash &&
            receipt.provider.independence_group ==
                "gridap-native-g1g2-scalar-heat-lift-v1" &&
            receipt.provider.claim_ceiling == screen_only &&
            receipt.provider.executor === _ng12_scalar_heat_lift_executor_v1 ||
            return false
        result = receipt.result
        expected_probe_sample = _ng12_scalar_heat_lift_probe_sample_v1(
            form, report.levels[3].physical_domain,
            result.reference_temperature_k, result.temperature_scale_k,
            result.conductivity_scale_w_m_k)
        canonical_hash(result.probe_sample) ==
            canonical_hash(expected_probe_sample) || return false
        result.candidate_ref == report.candidate_ref &&
            result.t1_package_hash == report.t1_package_hash &&
            result.scenario_id == plan.compilation.scenario.scenario_id &&
            result.g1_declaration_hash == form.g1_declaration.declaration_hash &&
            result.g1_source_ref == form.g1_declaration.source_ref &&
            result.g1_source_hash == form.g1_declaration.source_hash &&
            result.g2_declaration_hash == form.g2_declaration.declaration_hash &&
            result.g2_source_ref == form.g2_declaration.source.source_ref &&
            result.g2_source_hash == form.g2_declaration.source.source_hash &&
            result.plan_hash == report.plan_hash &&
            result.report_hash == report.report_hash &&
            result.authored_obligation_hash == canonical_hash(authored_heat_lift) &&
            result.source_sign === :declared &&
            result.source_integral_m == report.levels[3].assembled_source_integral &&
            result.reference_temperature_k == Float64(authored_heat_lift.reference_temperature_k) &&
            result.temperature_scale_k == Float64(authored_heat_lift.temperature_scale_k) &&
            result.conductivity_scale_w_m_k == Float64(authored_heat_lift.conductivity_scale_w_m_k) &&
            result.source_power_limit_w == Float64(authored_heat_lift.budget_join.limit_w) &&
            result.source_power_w == result.conductivity_scale_w_m_k *
                result.temperature_scale_k * result.source_integral_m &&
            0 <= result.source_power_w <= result.source_power_limit_w &&
            result.probe_sample.heat_flux_convention ===
                :fourier_q_equals_minus_k_grad_temperature &&
            result.probe_sample.source_balance_convention ===
                :div_fourier_q_equals_source &&
            result.probe_sample.gradient_temperature_k_m[1] > 0 &&
            result.probe_sample.conductive_flux_w_m2[1] < 0 &&
            all(i -> isapprox(result.probe_sample.conductive_flux_w_m2[i],
                -result.probe_sample.conductivity_diagonal_w_m_k[i] *
                    result.probe_sample.gradient_temperature_k_m[i];
                atol=1e-12, rtol=1e-12), 1:3) &&
            canonical_hash(result.probe_sample.units) == canonical_hash((
                point=UnitSignature((1, 0, 0, 0, 0, 0, 0)),
                u_dimensionless=UnitSignature(),
                temperature=UnitSignature((0, 0, 0, 0, 1, 0, 0)),
                conductivity=UnitSignature((1, 1, -3, 0, -1, 0, 0)),
                gradient_temperature=UnitSignature((-1, 0, 0, 0, 1, 0, 0)),
                conductive_flux=UnitSignature((0, 1, -3, 0, 0, 0, 0)),
                source_density=UnitSignature((-1, 1, -3, 0, 0, 0, 0)),
                source_integral=UnitSignature((1, 0, 0, 0, 0, 0, 0)),
                source_power=UnitSignature((2, 1, -3, 0, 0, 0, 0)),
                source_power_limit=UnitSignature((2, 1, -3, 0, 0, 0, 0)))) ||
            return false
        body = _ng12_scalar_heat_lift_body(result.candidate_ref,
            result.scenario_id, result.t1_package_hash,
            result.g1_declaration_hash, result.g1_source_ref,
            result.g1_source_hash, result.g2_declaration_hash,
            result.g2_source_ref, result.g2_source_hash,
            result.plan_hash, result.report_hash, result.authored_obligation_hash,
            result.source_sign, result.reference_temperature_k,
            result.temperature_scale_k, result.conductivity_scale_w_m_k,
            result.source_integral_m, result.source_power_w,
            result.source_power_limit_w, result.probe_sample)
        canonical_hash(body) == result.result_hash || return false
        receipt.receipt_hash == canonical_hash(
            _ng12_scalar_heat_lift_service_receipt_body(receipt.service,
                receipt.obligation, receipt.provider, receipt.match, result))
    catch
        false
    end
end

"""
    native_g1g2_gridap_scalar_heat_lift_fe_boundary_energy_readout_v1(
        plan, report, source_context, heat_lift_receipt)

Return an opt-in readout of the actual level-3 FE solution's integrated
outer-boundary conormal trace and its Fourier-sign outward heat loss. The
existing report's surface trace is diagnostic; the separate algebraic
boundary-reaction residual remains the conservation check. This readout does
not map the total-domain loss to a device heat-sink allocation or establish
physical calibration.
"""
function native_g1g2_gridap_scalar_heat_lift_fe_boundary_energy_readout_v1(
        plan::NativeG1G2GridapPlanV1, report::NativeG1G2GridapReportV1,
        source_context::NamedTuple,
        heat_lift_receipt::NativeG1G2ScalarHeatLiftServiceReceiptV1)
    validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
        plan, report, source_context, heat_lift_receipt) ||
        throw(ArgumentError("FE boundary-energy readout requires a valid native heat-lift receipt"))
    level = only(level for level in report.levels if level.level == 3)
    heat_lift = heat_lift_receipt.result
    scale = heat_lift.conductivity_scale_w_m_k * heat_lift.temperature_scale_k
    signed_conormal_power_w = scale * level.discrete_trace_conormal_integral
    outward_fourier_loss_w = -signed_conormal_power_w
    assembled_source_power_w = scale * level.assembled_source_integral
    (
        domain="native-g1g2-gridap-fe-boundary-energy-readout-v1",
        candidate_ref=report.candidate_ref,
        scenario_id=heat_lift.scenario_id,
        t1_package_hash=report.t1_package_hash,
        plan_hash=report.plan_hash,
        report_hash=report.report_hash,
        level_hash=level.level_hash,
        heat_lift_result_hash=heat_lift.result_hash,
        authored_obligation_hash=heat_lift.authored_obligation_hash,
        source_sign=level.source_sign,
        source_balance_convention=:div_fourier_q_equals_source,
        heat_flux_convention=:fourier_q_equals_minus_k_grad_temperature,
        surface_trace_status=:diagnostic,
        claim_ceiling=screen_only,
        physical_status=:unknown,
        scale_w_per_m=scale,
        discrete_trace_conormal_integral_m=level.discrete_trace_conormal_integral,
        signed_conormal_power_w=signed_conormal_power_w,
        outward_fourier_loss_w=outward_fourier_loss_w,
        assembled_source_integral_m=level.assembled_source_integral,
        assembled_source_power_w=assembled_source_power_w,
        fe_surface_balance_residual_w=assembled_source_power_w -
            outward_fourier_loss_w,
        discrete_boundary_reaction_integral_m=
            level.discrete_boundary_reaction_integral,
        algebraic_boundary_reaction_power_w=scale *
            level.discrete_boundary_reaction_integral,
        algebraic_boundary_balance_residual_w=scale *
            level.discrete_boundary_reaction_balance_defect,
    )
end

"""Execute the admitted G1 thermal source on the actual three-dimensional G2 Q1 mesh.

This opt-in route is a software/numerical screen. It consumes the current T0
G1/G2 records and their reconstructed typed thermal program, assembles a
continuous HEX-Q1 weak form, applies the actual x-face Dirichlet data as a
constant temperature shift, and leaves the four zero-Neumann faces natural.
It does not change the legacy NativeG1G2 MMS plan or its boundary contract.
"""
function _ng12_thermal_physical_domain_v1(chart)
    bounds = FusionConceptAI.g2mb_chart_image_bounds(chart)
    (Float64(bounds[1][1]), Float64(bounds[1][2]),
     Float64(bounds[2][1]), Float64(bounds[2][2]),
     Float64(bounds[3][1]), Float64(bounds[3][2]))
end

function _ng12_thermal_chart_point_v1(chart, physical_point)
    p = Tuple(physical_point)
    length(p) == 3 && all(x -> x isa Real && isfinite(x), p) ||
        throw(ArgumentError("thermal Gridap point must be a finite physical 3-vector"))
    chart.map_kind === :affine ||
        throw(ArgumentError("thermal Gridap route requires the admitted affine G2 chart"))
    all(iszero(chart.jacobian_rows[i][j]) for i in 1:3 for j in 1:3 if i != j) &&
        all(chart.jacobian_rows[i][i] > 0 for i in 1:3) ||
        throw(ArgumentError("thermal Gridap route requires a positive diagonal G2 chart"))
    Tuple(begin
        value = (Float64(p[i]) - Float64(chart.offset[i])) /
            Float64(chart.jacobian_rows[i][i])
        Float64(chart.domain_lower[i]) <= value <=
            Float64(chart.domain_upper[i]) ||
            throw(ArgumentError("thermal Gridap point is outside the actual G2 chart"))
        value
    end for i in 1:3)
end

function _ng12_thermal_eval_root_v1(input, capability, root_name::Symbol,
        chart_points)
    root_name in (:u, :f) ||
        throw(ArgumentError("thermal Gridap source root must be u or f"))
    points = Tuple(ntuple(i -> Float64(point[i]), 3) for point in chart_points)
    result = evaluate_g1_typed_source_program_v1(capability,
        getproperty(capability.roots, root_name), points)
    root = getproperty(capability.roots, root_name)
    result.status === :ready && result.candidate_ref == input.candidate_ref &&
        result.g1_source_ref == capability.g1_source_ref &&
        result.g1_declaration_ref == capability.g1_declaration_ref &&
        result.g2_source_ref == capability.g2_source_ref &&
        result.g2_declaration_ref == capability.g2_declaration_ref &&
        result.program_hash == capability.program_hash &&
        result.binding_hash == capability.binding_hash &&
        result.root_ref == root && result.root_hash == canonical_hash(root) &&
        result.root_type == root.declared_type && result.chart_points == points ||
        throw(ArgumentError("thermal Gridap typed-root evaluation identity mismatch"))
    Tuple(Float64(value) for value in result.values)
end

function _ng12_thermal_x_dirichlet_tag_v1(model, domain, cells)
    topology = Gridap.Geometry.get_grid_topology(model)
    facet_coordinates = Gridap.Geometry.get_face_coordinates(topology, 2)
    is_boundary = Gridap.Geometry.get_isboundary_face(topology, 2)
    length(facet_coordinates) == length(is_boundary) ||
        throw(ArgumentError("thermal Gridap facet-coordinate inventory mismatch"))
    scale = max(1.0, maximum(abs, domain))
    tolerance = 64 * eps(Float64) * scale
    x_min_faces = Int[]
    x_max_faces = Int[]
    for facet in eachindex(is_boundary)
        is_boundary[facet] || continue
        vertices = facet_coordinates[facet]
        on_x_min = all(vertex -> isapprox(Float64(vertex[1]), domain[1];
            atol=tolerance, rtol=0.0), vertices)
        on_x_max = all(vertex -> isapprox(Float64(vertex[1]), domain[2];
            atol=tolerance, rtol=0.0), vertices)
        on_x_min && on_x_max &&
            throw(ArgumentError("thermal Gridap facet lies on both x boundary planes"))
        on_x_min && push!(x_min_faces, Int(facet))
        on_x_max && push!(x_max_faces, Int(facet))
    end
    expected = cells[2] * cells[3]
    length(x_min_faces) == expected && length(x_max_faces) == expected &&
        isempty(intersect(x_min_faces, x_max_faces)) ||
        throw(ArgumentError("thermal Gridap x-face facet coverage mismatch"))
    # FaceLabeling entity ids are categorical labels shared by all dimensions,
    # not geometric face indices. Give every boundary vertex/edge/facet on the
    # two x planes one fresh category so Q1 vertex DOFs receive the tag too.
    selected_by_dim = Vector{Vector{Int}}()
    for dimension in 0:2
        coordinates = Gridap.Geometry.get_face_coordinates(topology, dimension)
        boundary = Gridap.Geometry.get_isboundary_face(topology, dimension)
        length(coordinates) == length(boundary) ||
            throw(ArgumentError("thermal Gridap boundary-entity inventory mismatch"))
        selected = Int[]
        for entity in eachindex(boundary)
            boundary[entity] || continue
            vertices = coordinates[entity]
            on_x_min = all(vertex -> isapprox(Float64(vertex[1]), domain[1];
                atol=tolerance, rtol=0.0), vertices)
            on_x_max = all(vertex -> isapprox(Float64(vertex[1]), domain[2];
                atol=tolerance, rtol=0.0), vertices)
            on_x_min && on_x_max &&
                throw(ArgumentError("thermal Gridap entity lies on both x boundary planes"))
            (on_x_min || on_x_max) && push!(selected, Int(entity))
        end
        expected_count = dimension == 0 ?
            2 * (cells[2] + 1) * (cells[3] + 1) :
            dimension == 1 ?
                2 * (cells[2] * (cells[3] + 1) + cells[3] * (cells[2] + 1)) :
                2 * cells[2] * cells[3]
        length(selected) == expected_count ||
            throw(ArgumentError("thermal Gridap x-plane boundary entity coverage mismatch"))
        push!(selected_by_dim, selected)
    end
    tag = "g1_thermal_x_dirichlet_v1"
    labels = Gridap.Geometry.get_face_labeling(model)
    entity_ids = Gridap.Geometry.get_face_entity(labels)
    next_entity = Int32(maximum(entity_ids; init=Int32(0)) + 1)
    for dimension in 0:2
        entity_map = Gridap.Geometry.get_face_entity(labels, dimension)
        for entity in selected_by_dim[dimension + 1]
            entity_map[entity] = next_entity
        end
    end
    # Keep Gridap's general "boundary" selector complete after subdividing
    # its categorical entity label for the x-only Dirichlet selector.
    boundary_tag_entities = Gridap.Geometry.get_tag_entities(labels, "boundary")
    push!(boundary_tag_entities, next_entity)
    sort!(unique!(boundary_tag_entities))
    Gridap.Geometry.add_tag!(labels, tag, Int32[next_entity])
    (tag=tag, x_min_faces=Tuple(sort(x_min_faces)),
        x_max_faces=Tuple(sort(x_max_faces)))
end

"""Run one source-bound, full-3D Q1 Gridap solve for an admitted DGD input."""
function run_g1_thermal_q1_gridap_v1(input;
        quadrature_degree::Integer=4, source_density_profile=nothing,
        source_density_runtime_input=nothing,
        include_cell_center_sensor::Bool=false)
    input isa FusionConceptAI.DeclaredG123InputV1 ||
        throw(ArgumentError("thermal Gridap input must be a typed admitted G1/G2/G3 input"))
    quadrature_degree >= 1 ||
        throw(ArgumentError("thermal Gridap quadrature degree must be positive"))
    compilation = FusionConceptAI.dgd_compile_v1(input)
    compilation.status === :ready ||
        throw(ArgumentError("thermal Gridap requires the existing DGD compile gate to pass"))
    capability = FusionConceptAI._dgd_g1_typed_source_capability_v1(input)
    capability === nothing &&
        throw(ArgumentError("thermal Gridap requires the authenticated T0 G1 thermal program"))

    g1 = input.g1
    g2 = input.g2.source
    chart = g2.chart_map
    g2.mesh.basis === :Q1 ||
        throw(ArgumentError("thermal Gridap requires the actual G2 Q1 mesh"))
    cells = g2.mesh.cells
    all(>(0), cells) ||
        throw(ArgumentError("thermal Gridap G2 cell counts must be positive"))
    domain = _ng12_thermal_physical_domain_v1(chart)
    all(isfinite, domain) && all(domain[2i - 1] < domain[2i] for i in 1:3) ||
        throw(ArgumentError("thermal Gridap physical G2 domain is invalid"))

    faces = g2.faces
    length(faces) == 6 &&
        Set(face.face for face in faces) ==
            Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)) &&
        length(Set(face.face_id for face in faces)) == 6 ||
        throw(ArgumentError("thermal Gridap requires the exact six G2 face owners"))
    all(face.ownership === :candidate_owned &&
        face.reference_normal == _ng12_gridap_expected_reference_normal(face.face)
        for face in faces) ||
        throw(ArgumentError("thermal Gridap G2 face ownership or normal mismatch"))
    Tuple(sort(collect(faces), by=face -> String(face.face))) ==
        capability.source_law.boundary_faces ||
        throw(ArgumentError("thermal Gridap G2 faces differ from the authenticated source law"))
    face_by_name = Dict(face.face => face for face in faces)
    x_min, x_max = face_by_name[:x_min], face_by_name[:x_max]
    t0 = Float64(x_min.value.value)
    x_min.value.kind === :dirichlet && x_max.value.kind === :dirichlet &&
        x_min.value.unit == g1.u.physical_type.units == x_max.value.unit &&
        Float64(x_max.value.value) == t0 ||
        throw(ArgumentError("thermal Gridap x-face Dirichlet data mismatch"))
    conormal_unit = capability.source_law.bindings.transverse_zero_conormal.unit
    all(face -> face.value.kind === :neumann &&
        iszero(face.value.value) && face.value.unit == conormal_unit,
        (face_by_name[:y_min], face_by_name[:y_max],
         face_by_name[:z_min], face_by_name[:z_max])) ||
        throw(ArgumentError("thermal Gridap transverse zero-Neumann data mismatch"))

    model = CartesianDiscreteModel(domain, cells)
    reffe = Gridap.ReferenceFEs.LagrangianRefFE(Float64,
        Gridap.ReferenceFEs.HEX, 1)
    omega = Triangulation(model)
    measure = Measure(omega, Int(quadrature_degree))
    boundary = BoundaryTriangulation(model)
    raw_face_projection = _ng12_gridap_boundary_face_projection_v1(boundary,
        domain, cells, faces, chart)
    dirichlet = _ng12_thermal_x_dirichlet_tag_v1(model, domain, cells)
    face_projection = Tuple(begin
        condition = face.face in (:x_min, :x_max) ?
            :essential_dirichlet : :natural_zero_neumann
        (face_id=owner.face_id, face=owner.face,
            owner_region_id=owner.owner_region_id,
            reference_normal=owner.reference_normal, kind=owner.kind,
            value=owner.value, unit=owner.unit,
            physical_plane_coordinate=owner.physical_plane_coordinate,
            physical_oriented_area_vector=owner.physical_oriented_area_vector,
            projected_gridap_boundary_cells=owner.projected_gridap_boundary_cells,
            expected_gridap_boundary_cells=owner.expected_gridap_boundary_cells,
            gridap_boundary_condition=condition,
            gridap_dirichlet_tag=condition === :essential_dirichlet ?
                dirichlet.tag : nothing)
    end for (face, owner) in zip(faces, raw_face_projection))
    test_space = TestFESpace(model, reffe; conformity=:H1,
        dirichlet_tags=dirichlet.tag)
    # Solve for theta = T - T0. This is the exact weak-form constant shift and
    # avoids adding 300 K boundary terms into the reduced right-hand side.
    trial_space = TrialFESpace(test_space, _ -> 0.0)
    free_coordinates, dirichlet_coordinates =
        Gridap.FESpaces.get_free_and_dirichlet_dof_coordinates(test_space)
    dof_coordinates = (free=Tuple(Tuple(Float64.(Tuple(p))) for p in free_coordinates),
        dirichlet=Tuple(Tuple(Float64.(Tuple(p))) for p in dirichlet_coordinates))

    reference_midpoint = ntuple(i ->
        (Float64(chart.domain_lower[i]) + Float64(chart.domain_upper[i])) / 2,
        3)
    (source_density_profile === nothing) ==
        (source_density_runtime_input === nothing) ||
        throw(ArgumentError("thermal Gridap runtime source profile/input pair is incomplete"))
    runtime_source_evaluation = nothing
    q = 0.0
    if source_density_profile !== nothing
        source_density_profile isa G1RuntimeSourceDensityParameterV1 &&
            source_density_runtime_input isa G1RuntimeSourceDensityInputV1 ||
            throw(ArgumentError("thermal Gridap runtime source inputs have the wrong typed API"))
        runtime_source_evaluation = evaluate_g1_runtime_source_density_v1(
            capability, source_density_profile, source_density_runtime_input,
            (reference_midpoint,))
        length(runtime_source_evaluation.values) == 1 ||
            throw(ArgumentError("thermal Gridap runtime source evaluation must return one scalar"))
        q = only(Float64.(runtime_source_evaluation.values))
    else
        q = only(_ng12_thermal_eval_root_v1(input, capability, :f,
            (reference_midpoint,)))
    end
    q0_reference = runtime_source_evaluation === nothing ? q :
        source_density_profile.q0_W_m3
    isfinite(q) || throw(ArgumentError("thermal Gridap typed source is nonfinite"))
    source_function(x) = q
    k_field = CellField(x -> begin
        physical = ntuple(i -> Float64(x[i]), 3)
        diagonal = FusionConceptAI.g1_diffusion_k_eval(g1.K.expression,
            physical)
        TensorValue(Float64(diagonal[1][1]), 0.0, 0.0,
            0.0, Float64(diagonal[2][2]), 0.0,
            0.0, 0.0, Float64(diagonal[3][3]))
    end, omega)
    a(u, v) = ∫(∇(v) ⋅ (k_field ⋅ ∇(u))) * measure
    b(v) = ∫(v * source_function) * measure
    operator = AffineFEOperator(a, b, trial_space, test_space)
    theta = solve(LinearFESolver(LUSolver()), operator)
    matrix = get_matrix(operator)
    rhs = Float64.(get_vector(operator))
    free_values = Float64.(get_free_values(theta))
    algebraic_residual = matrix * free_values - rhs
    residual_abs = norm(algebraic_residual, Inf)
    residual_rel = residual_abs / max(norm(rhs, Inf), eps(Float64))

    # Audit power and essential-boundary reactions from this same Q1 weak
    # form and solved theta vector.  The full-space solve is not repeated.
    source_power_integral_w = sum(∫(CellField(source_function, omega)) * measure)
    full_test_space = TestFESpace(model, reffe; conformity=:H1)
    full_trial_space = TrialFESpace(full_test_space)
    full_operator = AffineFEOperator(a, b, full_trial_space, full_test_space)
    full_matrix = get_matrix(full_operator)
    full_rhs = Float64.(get_vector(full_operator))
    dof_partition = _ng12_full_space_dof_partition(test_space,
        full_test_space)
    full_values = zeros(Float64, num_free_dofs(full_test_space))
    full_values[dof_partition.free_to_full] = free_values
    full_reactions = full_matrix * full_values - full_rhs
    interior_reactions = full_reactions[dof_partition.free_to_full]
    dirichlet_reactions = full_reactions[dof_partition.boundary_to_full]
    dirichlet_reaction_sum_w = sum(dirichlet_reactions)
    source_power_balance_defect_w = source_power_integral_w +
        dirichlet_reaction_sum_w
    interior_reaction_linf_w = norm(interior_reactions, Inf)
    interior_residual_match_linf_w = norm(
        interior_reactions - algebraic_residual, Inf)
    energy_balance_abs_tol_w = 1.0e-12
    energy_balance_finite = all(isfinite, (source_power_integral_w,
        dirichlet_reaction_sum_w, source_power_balance_defect_w,
        interior_reaction_linf_w, interior_residual_match_linf_w))
    energy_balance_status = energy_balance_finite &&
        residual_abs <= energy_balance_abs_tol_w &&
        interior_reaction_linf_w <= energy_balance_abs_tol_w &&
        interior_residual_match_linf_w <= energy_balance_abs_tol_w &&
        abs(source_power_balance_defect_w) <= energy_balance_abs_tol_w ?
            :pass : :numerical_fail
    energy_balance = (source_power_integral_w=source_power_integral_w,
        dirichlet_reaction_sum_w=dirichlet_reaction_sum_w,
        source_power_balance_defect_w=source_power_balance_defect_w,
        interior_reaction_linf_w=interior_reaction_linf_w,
        interior_residual_match_linf_w=interior_residual_match_linf_w,
        dof_partition_hash=dof_partition.partition_hash,
        tolerance_w=energy_balance_abs_tol_w, status=energy_balance_status)

    node_axes = ntuple(i -> range(domain[2i - 1], domain[2i];
        length=cells[i] + 1), 3)
    physical_nodes = Tuple((Float64(x), Float64(y), Float64(z))
        for z in node_axes[3] for y in node_axes[2] for x in node_axes[1])
    chart_nodes = Tuple(_ng12_thermal_chart_point_v1(chart, point)
        for point in physical_nodes)
    typed_source_temperature = _ng12_thermal_eval_root_v1(input, capability,
        :u, chart_nodes)
    numerical_temperature = Tuple(t0 + Float64(theta(Point(point...)))
        for point in physical_nodes)
    # Compare the solved Q1 field against the declared constant-source slab
    # solution by integrating its squared error over the actual Gridap cells.
    # This is an element-integrated norm, not a nodal-only interpolation check.
    exact_temperature(x) = t0 + q * (Float64(x[1]) - Float64(domain[1])) *
        (Float64(domain[2]) - Float64(x[1])) / (2.0 *
            Float64(capability.source_law.Kxx_W_mK))
    mms_l2_quadrature_degree = max(Int(quadrature_degree), 4)
    mms_l2_measure = Measure(omega, mms_l2_quadrature_degree)
    mms_error_squared = sum(∫(CellField(x -> begin
        error = Float64(theta(x)) -
            (exact_temperature(x) - t0)
        error * error
    end, omega)) * mms_l2_measure)
    mms_error_squared = Float64(mms_error_squared)
    (isfinite(mms_error_squared) && mms_error_squared >= 0.0) ||
        return (status=:numerical_fail, resolution=:numerical_fail,
            accepted=false, claim_ceiling=:screen_only,
            candidate_ref=input.candidate_ref,
            code=isfinite(mms_error_squared) ?
                :negative_mms_l2_integral : :nonfinite_mms_l2_integral)
    manufactured_solution_l2_error_k_m32 = sqrt(mms_error_squared)
    all(isfinite, free_values) && all(isfinite, rhs) &&
        all(isfinite, numerical_temperature) &&
        all(isfinite, typed_source_temperature) &&
        all(isfinite, (residual_abs, residual_rel,
            manufactured_solution_l2_error_k_m32)) ||
        return (status=:numerical_fail, resolution=:numerical_fail,
            accepted=false, claim_ceiling=:screen_only,
            candidate_ref=input.candidate_ref,
            code=:nonfinite_thermal_q1_solution)

    result = (
        status=:executed, resolution=:screen_only, accepted=false,
        claim_ceiling=:screen_only,
        candidate_ref=input.candidate_ref,
        source_binding=(g1_source_ref=capability.g1_source_ref,
            g1_declaration_ref=capability.g1_declaration_ref,
            g2_source_ref=capability.g2_source_ref,
            g2_declaration_ref=capability.g2_declaration_ref,
            g1_body_hash=input.hashes.g1_body_hash,
            g2_body_hash=input.hashes.g2_body_hash,
            bundle_hash=input.hashes.bundle_hash,
            typed_program_hash=capability.program_hash,
            typed_capability_hash=capability.capability_hash),
        mesh=(basis=:Q1, element=:HEX, cells=cells,
            cell_count=num_cells(model), nodal_count=length(physical_nodes),
            free_dofs=num_free_dofs(test_space),
            dirichlet_dofs=num_dirichlet_dofs(test_space),
            dof_coordinates=dof_coordinates,
            physical_domain=domain, quadrature_degree=Int(quadrature_degree),
            x_dirichlet_facets=dirichlet,
            face_projection=face_projection),
        source_density_w_m3=q, temperature_reference_k=t0,
        runtime_source_density=runtime_source_evaluation === nothing ? nothing :
            (profile_hash=runtime_source_evaluation.profile_hash,
             input_hash=runtime_source_evaluation.input_hash,
             parameter_hash=runtime_source_evaluation.parameter_hash,
             evaluation_hash=runtime_source_evaluation.result_hash,
             q_W_m3=q, unit=runtime_source_evaluation.unit),
        energy_balance=energy_balance,
        matrix=matrix, rhs=Tuple(rhs), free_theta_values=Tuple(free_values),
        physical_nodes=physical_nodes,
        temperature_nodes_k=numerical_temperature,
        typed_source_temperature_nodes_k=typed_source_temperature,
        nodal_source_error_linf=maximum(abs.(collect(numerical_temperature) .-
            collect(typed_source_temperature))),
        typed_source_temperature_scope=:frozen_g1_u_q0_reference,
        nodal_source_comparison_scope=runtime_source_evaluation === nothing ?
            :same_q0_reference : :q0_baseline_only,
        nodal_source_comparison_q0_W_m3=q0_reference,
        manufactured_solution=(kind=:constant_source_planar_slab,
            equation="-d/dx(Kxx*du/dx)=q'''; Kxx constant in x",
            temperature_l2_error_k_m32=manufactured_solution_l2_error_k_m32,
            norm=:non_normalized_volume_l2,
            error_units=:K_m3_2,
            quadrature_degree=mms_l2_quadrature_degree,
            exact_solution=(T0_K=t0, q_W_m3=q,
                Kxx_W_mK=Float64(capability.source_law.Kxx_W_mK),
                x_domain=(Float64(domain[1]), Float64(domain[2])))),
        residual_abs=residual_abs, residual_rel=residual_rel,
        solver_invocations=1,
        numerical_scope=:source_bound_full_3d_q1_steady_diffusion_screen,
        authority_scope=:g1_g2_source_bound_only)
    include_cell_center_sensor || return result

    cell_centers = Tuple((
        Float64(domain[1]) + (Float64(i) - 0.5) *
            (Float64(domain[2]) - Float64(domain[1])) / cells[1],
        Float64(domain[3]) + (Float64(j) - 0.5) *
            (Float64(domain[4]) - Float64(domain[3])) / cells[2],
        Float64(domain[5]) + (Float64(k) - 0.5) *
            (Float64(domain[6]) - Float64(domain[5])) / cells[3])
        for k in 1:cells[3] for j in 1:cells[2] for i in 1:cells[1])
    cell_center_temperatures = Tuple(t0 + Float64(theta(Point(point...)))
        for point in cell_centers)
    all(isfinite, cell_center_temperatures) ||
        return merge(result, (status=:numerical_fail,
            resolution=:numerical_fail, code=:nonfinite_cell_center_sensor))
    merge(result, (physical_cell_centers=cell_centers,
        temperature_cell_centers_k=cell_center_temperatures,
        maximum_cell_center_temperature_k=maximum(cell_center_temperatures),
        sensor_reduction=:maximum_cell_center))
end


"""Recover a physical-coordinate tensor grid from one admitted full Q1 state."""
function _ng12_q1_physical_payload_v1(plan::NativeG1G2GridapPlanV1,
        state::NativeG1G2Q1FieldStateV1)
    coordinates = state.dof_coordinates
    axes = ntuple(axis -> Tuple(sort!(unique!(Float64[p[axis] for p in coordinates]))), 3)
    length.(axes) == ntuple(i -> state.cell_counts[i] + 1, 3) &&
        length(coordinates) == prod(length.(axes)) ||
        throw(ArgumentError("typed_absent: native Q1 state is not a rectilinear tensor grid"))
    index_by_coordinate = Dict{NTuple{3,Float64},Int}()
    for (i, point) in enumerate(coordinates)
        haskey(index_by_coordinate, point) &&
            throw(ArgumentError("typed_absent: native Q1 state has duplicate DOF coordinates"))
        index_by_coordinate[point] = i
    end
    values = state.component_dof_values[1]
    row_major_values = Tuple(begin
        full_id = get(index_by_coordinate, (axes[1][i], axes[2][j], axes[3][k]), 0)
        full_id > 0 || throw(ArgumentError("typed_absent: native Q1 tensor grid has a missing coordinate"))
        values[full_id]
    end for i in eachindex(axes[1]) for j in eachindex(axes[2])
        for k in eachindex(axes[3]))
    form = plan.compilation.form
    state.component_field_ids == (form.g1_declaration.u.field_id,) &&
        state.component_units == (form.g1_declaration.u.physical_type.units,) &&
        state.component_orientations == (:scalar_invariant,) ||
        throw(ArgumentError("typed_unsupported: native Q1 field identity differs from plan"))
    grid = FieldGridSpecV4(axes)
    payload = FieldResidualPayloadV4(StateGeneRefV1(form.g1_declaration.u.field_id),
        grid, row_major_values, form.g1_declaration.u.physical_type)
    (grid=grid, payload=payload, axes=axes)
end

function _ng12_g2_edit_neutral_equal_v1(left, right, forward, reverse)
    if left isa QualifiedRefV1 || right isa QualifiedRefV1
        left isa QualifiedRefV1 && right isa QualifiedRefV1 &&
            left.version == right.version || return false
        mapped = get(forward, left.id, nothing)
        inverse = get(reverse, right.id, nothing)
        (mapped === nothing || mapped == right.id) &&
            (inverse === nothing || inverse == left.id) || return false
        forward[left.id] = right.id
        reverse[right.id] = left.id
        return true
    elseif left isa NamedTuple || right isa NamedTuple
        left isa NamedTuple && right isa NamedTuple || return false
        left_keys = Tuple(k for k in keys(left) if !(k in (:candidate_hash, :plan_hash)))
        right_keys = Tuple(k for k in keys(right) if !(k in (:candidate_hash, :plan_hash)))
        left_keys == right_keys || return false
        return all(_ng12_g2_edit_neutral_equal_v1(getproperty(left,k),
            getproperty(right,k), forward, reverse) for k in left_keys)
    elseif left isa Tuple || right isa Tuple
        left isa Tuple && right isa Tuple && length(left) == length(right) ||
            return false
        return all(_ng12_g2_edit_neutral_equal_v1(left[i], right[i],
            forward, reverse) for i in eachindex(left))
    elseif left isa AbstractVector || right isa AbstractVector
        left isa AbstractVector && right isa AbstractVector &&
            length(left) == length(right) || return false
        return all(_ng12_g2_edit_neutral_equal_v1(left[i], right[i],
            forward, reverse) for i in eachindex(left))
    end
    left_view = applicable(FusionConceptAI.semantic_view, left) ?
        FusionConceptAI.semantic_view(left) : left
    right_view = applicable(FusionConceptAI.semantic_view, right) ?
        FusionConceptAI.semantic_view(right) : right
    (left_view === left && right_view === right) && return left == right
    _ng12_g2_edit_neutral_equal_v1(left_view, right_view, forward, reverse)
end

function _ng12_g2_edit_semantics_match_v1(expected, actual)
    forward = Dict{String,String}()
    reverse = Dict{String,String}()
    _ng12_g2_edit_neutral_equal_v1(expected, actual, forward, reverse) &&
        length(unique(values(forward))) == length(forward) &&
        length(unique(values(reverse))) == length(reverse)
end

"""Return source-backed G2 fields that a mesh-only child edit must preserve.
Candidate-specific QualifiedRefs and source hashes are checked separately by
both source factories, their T0/T1 identities, and the native plans.
"""
function _ng12_g2_edit_invariant_v1(source)
    chart = source.chart_map
    regions = source.region_interface === nothing ? nothing :
        Tuple((region_id=r.region_id, lower=r.lower, upper=r.upper,
            boundary_kinds=r.boundary_kinds) for r in source.region_interface.regions)
    interfaces = source.region_interface === nothing ? nothing :
        Tuple((left_region_id=i.left_region_id, right_region_id=i.right_region_id,
            axis=i.axis, coordinate=i.coordinate, normal=i.normal,
            continuity=i.continuity, transfer_kind=i.transfer_kind)
            for i in source.region_interface.interfaces)
    (source_version=source.source_version,
        chart_geometry=(domain_lower=chart.domain_lower, domain_upper=chart.domain_upper,
            jacobian_rows=chart.jacobian_rows, offset=chart.offset,
            map_kind=chart.map_kind, axes=chart.axes),
        faces=Tuple((face=f.face, owner_region_id=f.owner_region_id,
            reference_normal=f.reference_normal, value=f.value,
            ownership=f.ownership) for f in source.faces),
        profile=source.profile, units=source.units, authority=source.authority,
        field_space=source.field_space, q1_interpretation=source.q1_interpretation,
        boundary_coverage=source.boundary_coverage, regions=regions,
        interfaces=interfaces, region_exterior_owners=source.region_exterior_owners,
        mesh_basis=source.mesh.basis, mesh_quadrature_points=source.mesh.quadrature_points,
        mesh_quadrature_weights=source.mesh.quadrature_weights,
        mesh_execution_status=source.mesh.execution_status)
end

"""Transfer one parent level-1 scalar Q1 state to a distinct nested G2 edit child.

Only this current 2x nested Cartesian case is implemented. It is a bounded
software transfer; nonnested topology, vector fields, and multi-rank halos
remain typed absent/unsupported.
"""
function transfer_gridap_field_payload_v1(
        parent_plan::NativeG1G2GridapPlanV1,
        parent_level::NativeG1G2GridapLevelResultV1,
        parent_g2_factory::FusionConceptAI.G2SourceFactoryConstructionResultV1,
        child_plan::NativeG1G2GridapPlanV1,
        child_g2_factory::FusionConceptAI.G2SourceFactoryConstructionResultV1;
        level::Integer=1)
    level == 1 || throw(ArgumentError("typed_absent: child transfer supports level 1 only"))
    validate_native_g1g2_gridap_plan_v1(parent_plan) &&
        validate_native_g1g2_gridap_plan_v1(child_plan) &&
        _ng12_level_integrity(parent_level) &&
        parent_level.level == 1 && parent_level.status === :pass &&
        _ng12_level_matches_plan(parent_plan, parent_level, 1) ||
        throw(ArgumentError("invalid_input: parent plan/state is not a current admitted pass"))
    parent_state = parent_level.field_state
    parent_form = parent_plan.compilation.form
    child_form = child_plan.compilation.form
    parent_projection = FusionConceptAI.g2_v5_source_projection_v1(parent_g2_factory)
    child_projection = FusionConceptAI.g2_v5_source_projection_v1(child_g2_factory)
    parent_source = parent_projection.source_declaration.source_payload
    child_source = child_projection.source_declaration.source_payload
    parent_projection.resolution === :terminal_deferred &&
        parent_projection.claim_ceiling === :contract_only &&
        child_projection.resolution === :terminal_deferred &&
        child_projection.claim_ceiling === :contract_only &&
        parent_projection.source_declaration.declaration == parent_form.g2_declaration &&
        child_projection.source_declaration.declaration == child_form.g2_declaration ||
        throw(ArgumentError("invalid_input: source factory differs from current T1 plan"))
    parent_state.candidate_ref == parent_form.candidate_ref &&
        parent_state.package_hash == parent_form.t1_package_hash &&
        parent_state.semantic_identity == parent_form.t1_semantic_identity &&
        parent_state.t0_bundle_hash == parent_form.t0_bundle_hash &&
        parent_state.plan_hash == parent_plan.plan_hash ||
        throw(ArgumentError("invalid_input: parent field state escaped its bound plan"))
    parent_form.candidate_ref != child_form.candidate_ref &&
        parent_form.t1_package_hash != child_form.t1_package_hash &&
        parent_form.t0_bundle_hash != child_form.t0_bundle_hash &&
        parent_source.source_ref != child_source.source_ref &&
        parent_source.source_hash != child_source.source_hash ||
        throw(ArgumentError("typed_absent: child must have independent candidate/T0/T1/G2 source identity"))
    parent_form.g1_declaration.u.field_id == child_form.g1_declaration.u.field_id &&
        parent_form.g1_declaration.u.physical_type == child_form.g1_declaration.u.physical_type ||
        throw(ArgumentError("typed_unsupported: transfer field id/unit/type mismatch"))
    parent_state.component_orientations == (:scalar_invariant,) &&
        parent_state.partition_count == 1 &&
        parent_state.halo_status === :single_rank_empty &&
        isempty(parent_state.halo_owner_refs) ||
        throw(ArgumentError("typed_unsupported: transfer supports scalar serial states only"))
    _ng12_cartesian_chart_supported_v1(parent_source.chart_map) &&
        _ng12_cartesian_chart_supported_v1(child_source.chart_map) ||
        throw(ArgumentError("typed_unsupported: transfer requires positive diagonal Cartesian charts"))
    _ng12_g2_edit_invariant_v1(parent_source) ==
        _ng12_g2_edit_invariant_v1(child_source) ||
        throw(ArgumentError("typed_absent: child changes non-mesh G2 semantics"))
    parent_cells, child_cells = parent_source.mesh.cells, child_source.mesh.cells
    child_cells == ntuple(i -> 2 * parent_cells[i], 3) ||
        throw(ArgumentError("typed_absent: current transfer supports only exact nested 2x mesh edits"))
    parent_edit = FusionConceptAI.g2_edit_mesh_cells(parent_projection.genome,
        child_projection.genome.plan.mesh.cells_per_region)
    parent_edit.plan.mesh.cells_per_region == child_cells &&
        _ng12_g2_edit_semantics_match_v1(parent_edit,
            child_projection.genome) ||
        throw(ArgumentError("typed_absent: child genome differs from the actual parent g2_edit_mesh_cells result beyond candidate-bound refs"))
    parent_state.physical_domain == _ng12_physical_domain(child_form) &&
        parent_state.cell_counts == parent_cells &&
        child_plan.protocol.cell_counts[Int(level)] == child_cells ||
        throw(ArgumentError("typed_absent: parent/child plan has a physical domain or mesh mismatch"))
    parent_state.g2_entity_ownership.status === :mapped ||
        throw(ArgumentError("typed_absent: source G2 region/interface/face ownership is incomplete"))
    child_mapping = _ng12_q1_plan_mapping_v1(child_plan, Int(level))
    child_mapping !== nothing &&
        child_mapping.g2_entity_ownership.status === :mapped ||
        throw(ArgumentError("typed_absent: child G2 regions/interfaces/exterior owners do not map to its Q1 mesh"))

    parent_tensor = _ng12_q1_physical_payload_v1(parent_plan, parent_state)
    domain = _ng12_physical_domain(child_form)
    child_axes = ntuple(axis -> Tuple(sort!(unique!(Float64[p[axis]
        for p in child_mapping.dof_coordinates]))), 3)
    length.(child_axes) == ntuple(i -> child_cells[i] + 1, 3) &&
        (first(child_axes[1]), last(child_axes[1]), first(child_axes[2]),
         last(child_axes[2]), first(child_axes[3]), last(child_axes[3])) == domain ||
        throw(ArgumentError("typed_absent: child Q1 plan mesh does not match its G2 physical domain"))
    child_grid = FieldGridSpecV4(child_axes)
    projection = transfer_gridap_field_payload_v1(parent_tensor.payload, child_grid, nothing)
    payload = projection.payload
    scale = max(1.0, abs(projection.source_integral))
    local_gate = all(abs(defect) <= 1.0e-12 * scale
        for defect in projection.cell_integral_defects)
    global_gate = abs(projection.conservation_defect) <= 1.0e-12 * scale
    boundary_payload_indices = Tuple(_gridap_node_index(i,j,k,length(child_axes[2]),length(child_axes[3]))
        for i in eachindex(child_axes[1]), j in eachindex(child_axes[2]),
            k in eachindex(child_axes[3])
        if i in (1,length(child_axes[1])) || j in (1,length(child_axes[2])) ||
            k in (1,length(child_axes[3])))
    boundary_linf = maximum(abs(payload.values[id]) for id in boundary_payload_indices; init=0.0)
    local_gate && global_gate && boundary_linf <= 1.0e-12 ||
        throw(ArgumentError("numerical_fail: child transfer violates strict local/global or zero-boundary gate"))
    relation = (schema="native-g1g2-q1-g2-child-edit-transfer-v1",
        parent_candidate_ref=parent_state.candidate_ref,
        parent_package_hash=parent_state.package_hash,
        parent_semantic_identity=parent_state.semantic_identity,
        parent_t0_bundle_hash=parent_state.t0_bundle_hash,
        parent_plan_hash=parent_plan.plan_hash, parent_state_hash=parent_state.state_hash,
        parent_g2_projection_hash=parent_projection.projection_hash,
        parent_g2_source_ref=parent_source.source_ref,
        parent_g2_source_hash=parent_source.source_hash, parent_mesh_cells=parent_cells,
        child_candidate_ref=child_form.candidate_ref,
        child_package_hash=child_form.t1_package_hash,
        child_semantic_identity=child_form.t1_semantic_identity,
        child_t0_bundle_hash=child_form.t0_bundle_hash,
        child_plan_hash=child_plan.plan_hash,
        child_g2_projection_hash=child_projection.projection_hash,
        child_g2_source_ref=child_source.source_ref, child_g2_source_hash=child_source.source_hash,
        child_mesh_cells=child_cells, field_id=parent_state.component_field_ids[1],
        unit=parent_state.component_units[1], orientation=parent_state.component_orientations[1],
        physical_domain=parent_state.physical_domain,
        edit_kind=:g2_mesh_cells_exact_2x,
        edit_result_hash=FusionConceptAI.canonical_hash(FusionConceptAI.semantic_view(parent_edit)))
    body = (domain="native-g1g2-q1-child-transfer-v1", relation=relation,
        transfer_projection_hash=projection.projection_hash,
        source_grid_hash=projection.source_grid_hash,
        target_grid_hash=projection.target_grid_hash,
        source_integral=projection.source_integral, target_integral=projection.target_integral,
        conservation_defect=projection.conservation_defect,
        cell_integral_defects=projection.cell_integral_defects,
        boundary_payload_indices=boundary_payload_indices, boundary_linf=boundary_linf,
        local_gate=local_gate, global_gate=global_gate, status=:ready,
        accepted=false, formal_up2_credit=false, claim_ceiling=:screen_only)
    merge(body, (schema="native-g1g2-q1-child-transfer-v1",
        code=:nested_g2_q1_transfer_ready, projection=projection,
        receipt_hash=FusionConceptAI.canonical_hash(body),
        integrity_context=(parent_plan=parent_plan, parent_level=parent_level,
            parent_g2_factory=parent_g2_factory,
            child_g2_factory=child_g2_factory)))
end

function _ng12_consume_child_transfer_v1(plan::NativeG1G2GridapPlanV1,
        level::Int, transfer, test_space, matrix, rhs)
    all(key -> hasproperty(transfer,key),
        (:relation,:projection,:receipt_hash,:status,:local_gate,:global_gate,
         :integrity_context,:schema,:code,:accepted,:formal_up2_credit,
         :claim_ceiling,:transfer_projection_hash,:source_grid_hash,
         :target_grid_hash,:source_integral,:target_integral,
         :conservation_defect,:cell_integral_defects,:boundary_payload_indices,
         :boundary_linf,:global_gate,:domain)) &&
        transfer.schema === "native-g1g2-q1-child-transfer-v1" &&
        transfer.code === :nested_g2_q1_transfer_ready &&
        transfer.status === :ready && transfer.accepted === false &&
        transfer.formal_up2_credit === false &&
        transfer.claim_ceiling === :screen_only &&
        transfer.local_gate && transfer.global_gate ||
        throw(ArgumentError("invalid_input: incomplete child transfer outcome"))
    form = plan.compilation.form
    relation = transfer.relation
    projection = transfer.projection
    payload = projection.payload
    context = transfer.integrity_context
    all(key -> hasproperty(context,key),
        (:parent_plan,:parent_level,:parent_g2_factory,:child_g2_factory)) ||
        throw(ArgumentError("invalid_input: child transfer lacks source verification context"))
    parent_plan = context.parent_plan
    parent_level = context.parent_level
    parent_plan isa NativeG1G2GridapPlanV1 &&
        parent_level isa NativeG1G2GridapLevelResultV1 &&
        validate_native_g1g2_gridap_plan_v1(parent_plan) &&
        _ng12_level_integrity(parent_level) && parent_level.status === :pass &&
        parent_level.level == 1 &&
        _ng12_level_matches_plan(parent_plan,parent_level,1) ||
        throw(ArgumentError("invalid_input: transfer source state/plan failed current integrity checks"))
    parent_state = parent_level.field_state
    parent_form = parent_plan.compilation.form
    parent_projection = FusionConceptAI.g2_v5_source_projection_v1(
        context.parent_g2_factory)
    child_projection = FusionConceptAI.g2_v5_source_projection_v1(
        context.child_g2_factory)
    parent_projection.source_declaration.declaration == parent_form.g2_declaration &&
        child_projection.source_declaration.declaration == form.g2_declaration &&
        parent_projection.projection_hash == relation.parent_g2_projection_hash &&
        child_projection.projection_hash == relation.child_g2_projection_hash &&
        parent_projection.source_declaration.source_payload.source_ref ==
            relation.parent_g2_source_ref &&
        parent_projection.source_declaration.source_payload.source_hash ==
            relation.parent_g2_source_hash &&
        child_projection.source_declaration.source_payload.source_ref ==
            relation.child_g2_source_ref &&
        child_projection.source_declaration.source_payload.source_hash ==
            relation.child_g2_source_hash ||
        throw(ArgumentError("invalid_input: transfer G2 edit factories no longer match the bound plans"))
    parent_state.candidate_ref == relation.parent_candidate_ref &&
        parent_state.package_hash == relation.parent_package_hash &&
        parent_state.semantic_identity == relation.parent_semantic_identity &&
        parent_state.t0_bundle_hash == relation.parent_t0_bundle_hash &&
        parent_plan.plan_hash == relation.parent_plan_hash &&
        parent_state.state_hash == relation.parent_state_hash &&
        relation.parent_mesh_cells == parent_state.cell_counts &&
        relation.field_id == only(parent_state.component_field_ids) &&
        relation.unit == only(parent_state.component_units) &&
        relation.orientation == only(parent_state.component_orientations) &&
        relation.physical_domain == parent_state.physical_domain &&
        relation.edit_kind === :g2_mesh_cells_exact_2x ||
        throw(ArgumentError("invalid_input: transfer source-state identity/hash mismatch"))
    edited_genome = FusionConceptAI.g2_edit_mesh_cells(
        parent_projection.genome, child_projection.genome.plan.mesh.cells_per_region)
    _ng12_g2_edit_semantics_match_v1(edited_genome,child_projection.genome) &&
        FusionConceptAI.canonical_hash(FusionConceptAI.semantic_view(edited_genome)) ==
            relation.edit_result_hash ||
        throw(ArgumentError("invalid_input: child G2 semantic edit no longer matches its parent edit"))
    parent_source = _ng12_q1_physical_payload_v1(parent_plan,parent_state).payload
    _gridap_projection_integrity(projection,parent_source,nothing) ||
        throw(ArgumentError("invalid_input: child transfer projection failed source/result recomputation"))
    transfer.transfer_projection_hash == projection.projection_hash &&
        transfer.source_grid_hash == projection.source_grid_hash &&
        transfer.target_grid_hash == projection.target_grid_hash &&
        transfer.source_integral == projection.source_integral &&
        transfer.target_integral == projection.target_integral &&
        transfer.conservation_defect == projection.conservation_defect &&
        transfer.cell_integral_defects == projection.cell_integral_defects ||
        throw(ArgumentError("invalid_input: transfer result fields differ from its recomputed projection"))
    gate_scale = max(1.0, abs(projection.source_integral))
    expected_local_gate = all(abs(defect) <= 1.0e-12 * gate_scale
        for defect in projection.cell_integral_defects)
    expected_global_gate = abs(projection.conservation_defect) <=
        1.0e-12 * gate_scale
    expected_boundary_indices = Tuple(_gridap_node_index(i,j,k,
        length(payload.coordinates[2]),length(payload.coordinates[3]))
        for i in eachindex(payload.coordinates[1]),
            j in eachindex(payload.coordinates[2]), k in eachindex(payload.coordinates[3])
        if i in (1,length(payload.coordinates[1])) ||
            j in (1,length(payload.coordinates[2])) ||
            k in (1,length(payload.coordinates[3])))
    expected_boundary_linf = maximum(abs(payload.values[id])
        for id in expected_boundary_indices; init=0.0)
    expected_local_gate == transfer.local_gate &&
        expected_global_gate == transfer.global_gate &&
        expected_local_gate && expected_global_gate &&
        expected_boundary_indices == transfer.boundary_payload_indices &&
        expected_boundary_linf == transfer.boundary_linf &&
        expected_boundary_linf <= 1.0e-12 ||
        throw(ArgumentError("invalid_input: transfer conservation/boundary gates failed recomputation"))
    receipt_body = (domain=transfer.domain, relation=relation,
        transfer_projection_hash=transfer.transfer_projection_hash,
        source_grid_hash=transfer.source_grid_hash,
        target_grid_hash=transfer.target_grid_hash,
        source_integral=transfer.source_integral, target_integral=transfer.target_integral,
        conservation_defect=transfer.conservation_defect,
        cell_integral_defects=transfer.cell_integral_defects,
        boundary_payload_indices=transfer.boundary_payload_indices,
        boundary_linf=transfer.boundary_linf, local_gate=transfer.local_gate,
        global_gate=transfer.global_gate, status=transfer.status,
        accepted=transfer.accepted, formal_up2_credit=transfer.formal_up2_credit,
        claim_ceiling=transfer.claim_ceiling)
    transfer.receipt_hash == FusionConceptAI.canonical_hash(receipt_body) ||
        throw(ArgumentError("invalid_input: transfer receipt hash mismatch"))
    _gridap_payload_integrity(payload) &&
        relation.child_plan_hash == plan.plan_hash &&
        relation.child_candidate_ref == form.candidate_ref &&
        relation.child_package_hash == form.t1_package_hash &&
        relation.child_semantic_identity == form.t1_semantic_identity &&
        relation.child_t0_bundle_hash == form.t0_bundle_hash &&
        relation.child_g2_source_ref == form.g2_declaration.source.source_ref &&
        relation.child_g2_source_hash == form.g2_declaration.source.source_hash &&
        relation.child_mesh_cells == plan.compilation.form.g2_declaration.source.mesh.cells &&
        level == 1 ||
        throw(ArgumentError("invalid_input: transfer outcome is not bound to this child plan"))
    axes = payload.coordinates
    Tuple(length.(axes) .- 1) == plan.protocol.cell_counts[level] &&
        (first(axes[1]), last(axes[1]), first(axes[2]), last(axes[2]),
         first(axes[3]), last(axes[3])) == relation.physical_domain &&
        payload.physical_type == form.g1_declaration.u.physical_type &&
        payload.state_ref == StateGeneRefV1(form.g1_declaration.u.field_id) ||
        throw(ArgumentError("typed_absent: transfer target grid/field differs from child operator"))
    index = Dict{NTuple{3,Float64},Int}()
    for i in eachindex(axes[1]), j in eachindex(axes[2]), k in eachindex(axes[3])
        index[(axes[1][i],axes[2][j],axes[3][k])] =
            _gridap_node_index(i,j,k,length(axes[2]),length(axes[3]))
    end
    free_coordinates, boundary_coordinates =
        Gridap.FESpaces.get_free_and_dirichlet_dof_coordinates(test_space)
    values_at = function(point)
        coord = Tuple(Float64.(Tuple(point)))
        i = ntuple(d -> findfirst(==(coord[d]), axes[d]), 3)
        all(index -> index !== nothing, i) ||
            throw(ArgumentError("typed_absent: child FE DOF is outside transferred tensor grid"))
        payload.values[index[coord]]
    end
    free_values = Float64[values_at(point) for point in free_coordinates]
    boundary_linf = maximum(abs(values_at(point)) for point in boundary_coordinates; init=0.0)
    boundary_linf <= 1.0e-12 ||
        throw(ArgumentError("numerical_fail: child boundary values are not preserved"))
    residual = matrix * free_values - rhs
    abs_residual = norm(residual, Inf)
    rel_residual = abs_residual / max(norm(rhs, Inf), eps(Float64))
    body = (domain="native-g1g2-q1-child-transfer-residual-consumer-v1",
        transfer_receipt_hash=transfer.receipt_hash,
        transfer_projection_hash=projection.projection_hash,
        child_plan_hash=plan.plan_hash, child_level=level,
        matrix_hash=_ng12_sparse_hash(matrix), rhs_hash=canonical_hash(rhs),
        residual_abs=abs_residual, residual_rel=rel_residual,
        boundary_linf=boundary_linf, boundary_preserved=true,
        consumer=:native_child_reduced_q1_residual_correction_seed,
        seed_residual_abs=abs_residual, seed_residual_rel=rel_residual,
        status=:measured, pass=false, claim_ceiling=:screen_only)
    merge(body, (free_values=free_values,
        receipt=merge(body, (receipt_hash=FusionConceptAI.canonical_hash(body),))))
end
