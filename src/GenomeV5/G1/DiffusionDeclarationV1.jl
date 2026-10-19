"""Candidate-owned 3-D variable-coefficient diffusion declaration.

This is a contract-only preparation slice for UP2-01-G1-DIFFUSION-V1.  It
declares the typed chain `-DIV(K * GRAD(u)) = f`, its units and source identity;
it does not evaluate a field, assemble a mesh, call a provider, or claim a
physical result.
"""

const G1_DIFFUSION_SCHEMA_ID_V1 = "GenomeV5/G1/DiffusionDeclarationV1"
const G1_DIFFUSION_SCHEMA_VERSION_V1 = "v1"
const G1_DIFFUSION_CANONICALIZATION_ID_V1 =
    "fusionconceptai://GenomeV5/G1/diffusion/canonicalization/v1"
const G1_DIFFUSION_APPLICABILITY_ID_V1 =
    "fusionconceptai://GenomeV5/G1/diffusion/applicability/v1"
const G1_DIFFUSION_CLOSURE_ID_V1 =
    "fusionconceptai://GenomeV5/G1/closure/diffusion"
const G1_DIFFUSION_PROFILE_VERSION_V1 = "v1"
const G1_DIFFUSION_PROFILE_ID_V1 =
    "fusionconceptai://GenomeV5/G1/diffusion/profile/v1"
const G1_DIFFUSION_CLAIM_CEILING_V1 = :contract_only
const G1_DIFFUSION_REQUIRED_GAPS_V1 =
    ("authority_terminal_deferred:no_external_source_or_provider",)

const _G1_DIFFUSION_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/G1/DiffusionDeclarationV1
version=v1
fields=candidate_ref,source_ref,source_version,source_payload(candidate_bound,optional_typed_unknown_state_binding,optional_per_operator_temporal_whitelist),source_hash,u,K,f,grad,K_apply,div,closure(profile_bound),applicability(profile_bound),negative_controls
unknown_state_binding=optional;state_index=0;role=unknown;field_id=u.field_id;physical_type=u.physical_type(exact)
operator_temporal_support=optional;operators=GRAD,K_APPLY,DIV;each_ref_exact;each_temporal_kinds_nonempty_unique;each_input_output_kind_member
equation=-DIV(K(x)*GRAD(u(x)))=f(x); residual_sign=-1
u=3-D scalar candidate-owned source field; K=editable diagonal-affine 3x3 source field; f=3-D scalar candidate-owned source field
ownership=all field declarations are candidate-owned; no manufactured value is an authority
status=proposal;accepted=false;resolution=terminal_deferred;claim_ceiling=contract_only
"""
const _G1_DIFFUSION_CANONICALIZATION_SOURCE_V1 = """
encoding=UTF-8;line_endings=LF;tuple_order=declared;refs=id,version;hash=SHA-256(canonical semantic value)
identity=source_ref,source_version,source_payload,source_hash,declaration fields,negative controls
edit=any source field edit rebuilds declaration and changes declaration_hash
"""
const _G1_DIFFUSION_APPLICABILITY_SOURCE_V1 = """
scope=contract-only candidate-owned 3-D variable-coefficient diffusion
requires=positive-definite bounded K(x), unit closure, typed GRAD/K_APPLY/DIV, source identity
missing_authority=terminal_deferred;contradiction=fail_closed
provider_calls=0;compiler_calls=0;mesh_calls=0;solver_calls=0;physical_evidence=false
"""
const _G1_DIFFUSION_CLOSURE_SOURCE_V1 = """
closure_id=fusionconceptai://GenomeV5/G1/closure/diffusion
version=v1; equation=-DIV(K(x)*GRAD(u(x)))=f(x); residual_sign=-1
profile_binding=G1_DIFFUSION_PROFILE_VERSION_V1
"""

g1_diffusion_schema_hash_v1() = digest256_text(_G1_DIFFUSION_SCHEMA_SOURCE_V1)
const _G1_DIFFUSION_INTERFACE_FLUX_PAIR_EXTENSION_V1 = """
source_payload.interface_flux_pair=optional typed G1DiffusionInterfaceFluxPairV1
scope=x-half only (axis=1, coordinate=1/2); fields=G2 interface ref, ordered region ids and ports, exact K_APPLY operator/output field, outward normals, signs and explicit law; unit=exact K_APPLY output PhysicalType.units, not duplicated
law=left_outward_flux_plus_right_outward_flux_equals_zero; signs=left-to-right orientation; typed output units
claim_ceiling=contract_only; physical_authority=false; provider_calls=0; solver_calls=0
"""
const _G1_DIFFUSION_TRANSIENT_CAPACITY_EXTENSION_V1 = """
source_payload.transient_capacity=optional typed source-bound G1DiffusionTransientCapacityV1
units=J/(m^3 K);time_unit=second;equation=rhoCp*du/dt-DIV(K*GRAD(u))=f
applicable_domain=transient_thermal_diffusion;closed=true;no default
"""
g1_diffusion_schema_hash_v1(interface_flux_pair_present::Bool,
                            transient_capacity_present::Bool) = begin
    transient_capacity_present ||
        return g1_diffusion_schema_hash_v1(interface_flux_pair_present)
    extensions = String[]
    interface_flux_pair_present && push!(extensions,
        _G1_DIFFUSION_INTERFACE_FLUX_PAIR_EXTENSION_V1)
    transient_capacity_present && push!(extensions,
        _G1_DIFFUSION_TRANSIENT_CAPACITY_EXTENSION_V1)
    isempty(extensions) ? g1_diffusion_schema_hash_v1() :
        canonical_hash((base=g1_diffusion_schema_hash_v1(),
            extensions=Tuple(digest256_text(x) for x in extensions)))
end
g1_diffusion_schema_hash_v1(interface_flux_pair_present::Bool) =
    interface_flux_pair_present ? canonical_hash((base=g1_diffusion_schema_hash_v1(),
        extension=digest256_text(_G1_DIFFUSION_INTERFACE_FLUX_PAIR_EXTENSION_V1))) :
        g1_diffusion_schema_hash_v1()
g1_diffusion_canonicalization_hash_v1() = digest256_text(_G1_DIFFUSION_CANONICALIZATION_SOURCE_V1)
g1_diffusion_applicability_hash_v1() = digest256_text(_G1_DIFFUSION_APPLICABILITY_SOURCE_V1)
g1_diffusion_closure_hash_v1() = digest256_text(_G1_DIFFUSION_CLOSURE_SOURCE_V1)
g1_diffusion_profile_hash_v1() = canonical_hash((
    profile_ref=G1_DIFFUSION_PROFILE_ID_V1,
    profile_version=G1_DIFFUSION_PROFILE_VERSION_V1,
    schema_version=G1_DIFFUSION_SCHEMA_VERSION_V1,
    schema_hash=g1_diffusion_schema_hash_v1(),
    canonicalization_hash=g1_diffusion_canonicalization_hash_v1(),
    applicability_hash=g1_diffusion_applicability_hash_v1(),
    applicability_ref=G1_DIFFUSION_APPLICABILITY_ID_V1,
    closure_ref=G1_DIFFUSION_CLOSURE_ID_V1,
    closure_hash=g1_diffusion_closure_hash_v1(),
    claim_ceiling=G1_DIFFUSION_CLAIM_CEILING_V1))
g1_diffusion_profile_hash_v1(interface_flux_pair_present::Bool) =
    interface_flux_pair_present ? canonical_hash((base=g1_diffusion_profile_hash_v1(),
        schema_hash=g1_diffusion_schema_hash_v1(true))) : g1_diffusion_profile_hash_v1()
g1_diffusion_profile_hash_v1(interface_flux_pair_present::Bool,
                              transient_capacity_present::Bool) =
    !transient_capacity_present ?
        g1_diffusion_profile_hash_v1(interface_flux_pair_present) :
        canonical_hash((base=g1_diffusion_profile_hash_v1(),
            schema_hash=g1_diffusion_schema_hash_v1(interface_flux_pair_present,
                transient_capacity_present)))

const G1_DIFFUSION_GRAD_OPERATOR_ID_V1 = "fusionconceptai://GenomeV5/G1/operator/GRAD"
const G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1 = "fusionconceptai://GenomeV5/G1/operator/K_APPLY"
const G1_DIFFUSION_DIV_OPERATOR_ID_V1 = "fusionconceptai://GenomeV5/G1/operator/DIV"

_g1d_text(x, field) = begin
    value = String(x)
    !isempty(value) || throw(ArgumentError("$field cannot be empty"))
    isvalid(value) || throw(ArgumentError("$field must be valid UTF-8"))
    value
end
_g1d_ref(x, field) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$field must be QualifiedRefV1"))
_g1d_unit(x, field) = x isa UnitSignature ? x : throw(ArgumentError("$field must be UnitSignature"))
_g1d_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_g1d_three_units(x, field) = begin
    values = Tuple(x)
    length(values) == 3 && all(v -> v isa Integer || v isa Rational, values) ||
        throw(ArgumentError("$field must have exactly three integer/rational exponents"))
    Tuple(values)
end
_g1d_add(a::UnitSignature, b::UnitSignature) = UnitSignature(ntuple(i -> a.exponents[i] + b.exponents[i], 7))
_g1d_sub(a::UnitSignature, b::UnitSignature) = UnitSignature(ntuple(i -> a.exponents[i] - b.exponents[i], 7))
_g1d_length_unit() = UnitSignature((1, 0, 0, 0, 0, 0, 0))

_g1d_r3(x, field) = begin
    values = Tuple(x)
    length(values) == 3 || throw(ArgumentError("$field must have exactly three values"))
    Tuple(Rational{Int64}(value) for value in values)
end

struct G1DiffusionDiagonalAffineKFieldV1
    expression_id::String
    domain_min::NTuple{3,Rational{Int64}}
    domain_max::NTuple{3,Rational{Int64}}
    base_diag::NTuple{3,Rational{Int64}}
    slope_diag::NTuple{3,Rational{Int64}}
    function G1DiffusionDiagonalAffineKFieldV1(expression_id::Any;
                                               domain_min=(0 // 1, 0 // 1, 0 // 1),
                                               domain_max=(1 // 1, 1 // 1, 1 // 1),
                                               base_diag=(2 // 1, 3 // 1, 4 // 1),
                                               slope_diag=(1 // 10, 1 // 20, 1 // 30))
        dmin = _g1d_r3(domain_min, "K domain_min")
        dmax = _g1d_r3(domain_max, "K domain_max")
        base = _g1d_r3(base_diag, "K base_diag")
        slope = _g1d_r3(slope_diag, "K slope_diag")
        all(dmin[i] < dmax[i] for i in 1:3) || throw(ArgumentError("K domain must be bounded and non-degenerate"))
        any(value -> !iszero(value), slope) || throw(ArgumentError("K expression must be non-constant"))
        lo = ntuple(i -> base[i] + min(slope[i] * dmin[i], slope[i] * dmax[i]), 3)
        all(x -> x > 0, lo) || throw(ArgumentError("K diagonal affine enclosure is not positive definite"))
        _g1d_text(expression_id, "K expression_id")
        new(String(expression_id), dmin, dmax, base, slope)
    end
end

semantic_view(x::G1DiffusionDiagonalAffineKFieldV1) =
    (expression_id=x.expression_id, domain_min=x.domain_min, domain_max=x.domain_max,
     base_diag=x.base_diag, slope_diag=x.slope_diag)

function g1_diffusion_k_eval(x::G1DiffusionDiagonalAffineKFieldV1, point)
    p = _g1d_r3(point, "K evaluation point")
    all(x.domain_min[i] <= p[i] <= x.domain_max[i] for i in 1:3) ||
        throw(ArgumentError("K evaluation point is outside declared bounded domain"))
    diag = ntuple(i -> x.base_diag[i] + x.slope_diag[i] * p[i], 3)
    ((diag[1], 0 // 1, 0 // 1), (0 // 1, diag[2], 0 // 1), (0 // 1, 0 // 1, diag[3]))
end

function g1_diffusion_k_enclosure(x::G1DiffusionDiagonalAffineKFieldV1)
    lower = ntuple(i -> x.base_diag[i] + min(x.slope_diag[i] * x.domain_min[i], x.slope_diag[i] * x.domain_max[i]), 3)
    upper = ntuple(i -> x.base_diag[i] + max(x.slope_diag[i] * x.domain_min[i], x.slope_diag[i] * x.domain_max[i]), 3)
    (lower=minimum(lower), upper=maximum(upper), diagonal_lower=lower, diagonal_upper=upper)
end

"""Candidate-owned affine symmetric 3-D conductivity tensor.

K(x) = base_matrix + sum_c x[c] * slope_matrices[c]. The closed convex
box domain is part of the declaration; exact SPD admission checks every box
vertex, which suffices because this affine matrix field is a convex
combination of its vertex matrices throughout the box.
"""
function _g1d_exact_r3(x, field)
    values = Tuple(x)
    length(values) == 3 || throw(ArgumentError("$field must have exactly three finite rational values"))
    ntuple(i -> begin
        value = values[i]
        (value isa Integer && !(value isa Bool)) || value isa Rational ||
            throw(ArgumentError("$field must contain only finite exact rational values"))
        try
            Rational{Int64}(value)
        catch
            throw(ArgumentError("$field entry is outside the exact rational range"))
        end
    end, 3)
end

struct G1DiffusionSymmetricAffineTensorKFieldV2
    expression_id::String
    domain_min::NTuple{3,Rational{Int64}}
    domain_max::NTuple{3,Rational{Int64}}
    base_matrix::NTuple{3,NTuple{3,Rational{Int64}}}
    slope_matrices::NTuple{3,NTuple{3,NTuple{3,Rational{Int64}}}}
    function G1DiffusionSymmetricAffineTensorKFieldV2(expression_id::Any;
            domain_min=(0 // 1, 0 // 1, 0 // 1),
            domain_max=(1 // 1, 1 // 1, 1 // 1),
            base_matrix=((4 // 1, 1 // 1, 0 // 1),
                        (1 // 1, 3 // 1, 0 // 1),
                        (0 // 1, 0 // 1, 2 // 1)),
            slope_matrices=(
                ((1 // 5, 1 // 20, 0 // 1),
                 (1 // 20, 1 // 10, 0 // 1),
                 (0 // 1, 0 // 1, 1 // 10)),
                ((1 // 10, 1 // 10, 0 // 1),
                 (1 // 10, 1 // 5, 0 // 1),
                 (0 // 1, 0 // 1, 1 // 20)),
                ((0 // 1, 0 // 1, 0 // 1),
                 (0 // 1, 0 // 1, 0 // 1),
                 (0 // 1, 0 // 1, 0 // 1))))
        dmin = _g1d_exact_r3(domain_min, "K domain_min")
        dmax = _g1d_exact_r3(domain_max, "K domain_max")
        all(dmin[i] < dmax[i] for i in 1:3) ||
            throw(ArgumentError("K domain must be a convex non-degenerate box"))
        base = _g1d_matrix3(base_matrix, "K base_matrix")
        slopes_in = Tuple(slope_matrices)
        length(slopes_in) == 3 ||
            throw(ArgumentError("K requires one affine slope matrix per coordinate"))
        slopes = ntuple(i -> _g1d_matrix3(slopes_in[i], "K slope_matrices[$i]"), 3)
        all(_g1d_symmetric3, (base, slopes...)) ||
            throw(ArgumentError("K affine matrices must be exactly symmetric"))
        any(value -> !iszero(value), (value for matrix in slopes for row in matrix for value in row)) ||
            throw(ArgumentError("K affine tensor must have a nonzero spatial slope"))
        _g1d_text(expression_id, "K expression_id")
        expression = new(String(expression_id), dmin, dmax, base, slopes)
        vertices = _g1d_tensor_box_vertices(expression)
        all(_g1d_spd3, vertices) ||
            throw(ArgumentError("K affine tensor is not positive definite over its declared box"))
        expression
    end
end

function _g1d_matrix3(x, field)
    rows = Tuple(x)
    length(rows) == 3 || throw(ArgumentError("$field must be a 3x3 matrix"))
    ntuple(i -> begin
        row = Tuple(rows[i])
        length(row) == 3 || throw(ArgumentError("$field must be a 3x3 matrix"))
        ntuple(j -> begin
            value = row[j]
            (value isa Integer && !(value isa Bool)) || value isa Rational ||
                throw(ArgumentError("$field entries must be finite exact rationals"))
            try
                Rational{Int64}(value)
            catch
                throw(ArgumentError("$field entry is outside the exact rational range"))
            end
        end, 3)
    end, 3)
end

_g1d_symmetric3(matrix) = all(matrix[i][j] == matrix[j][i] for i in 1:3 for j in 1:3)
_g1d_big_rational(value::Rational) = BigInt(numerator(value)) // BigInt(denominator(value))

function _g1d_tensor_box_vertices(expression::G1DiffusionSymmetricAffineTensorKFieldV2)
    vertices = Vector{NTuple{3,NTuple{3,Rational{BigInt}}}}(undef, 8)
    for mask in 0:7
        point = ntuple(c -> iszero(mask & (1 << (c - 1))) ?
            expression.domain_min[c] : expression.domain_max[c], 3)
        wide_point = ntuple(c -> _g1d_big_rational(point[c]), 3)
        vertices[mask + 1] = ntuple(i -> ntuple(j ->
            _g1d_big_rational(expression.base_matrix[i][j]) +
            sum(_g1d_big_rational(expression.slope_matrices[c][i][j]) * wide_point[c]
                for c in 1:3), 3), 3)
    end
    Tuple(vertices)
end

function _g1d_spd3(matrix)
    a, b, c = matrix[1]
    d, e, f = matrix[2]
    g, h, i = matrix[3]
    a > 0 && a * e - b * d > 0 &&
        a * (e * i - f * h) - b * (d * i - f * g) +
        c * (d * h - e * g) > 0
end

semantic_view(x::G1DiffusionSymmetricAffineTensorKFieldV2) =
    (expression_id=x.expression_id, domain_min=x.domain_min, domain_max=x.domain_max,
     base_matrix=x.base_matrix, slope_matrices=x.slope_matrices)

function g1_diffusion_k_eval(x::G1DiffusionSymmetricAffineTensorKFieldV2, point)
    p = _g1d_r3(point, "K evaluation point")
    all(x.domain_min[i] <= p[i] <= x.domain_max[i] for i in 1:3) ||
        throw(ArgumentError("K evaluation point is outside declared bounded domain"))
    ntuple(i -> ntuple(j -> x.base_matrix[i][j] +
        sum(x.slope_matrices[c][i][j] * p[c] for c in 1:3), 3), 3)
end

function _g1d_tensor_k_admissible(x::G1DiffusionSymmetricAffineTensorKFieldV2)
    all(x.domain_min[i] < x.domain_max[i] for i in 1:3) || return false
    all(_g1d_symmetric3, (x.base_matrix, x.slope_matrices...)) || return false
    all(_g1d_spd3, _g1d_tensor_box_vertices(x))
end

function g1_diffusion_k_enclosure(x::G1DiffusionSymmetricAffineTensorKFieldV2)
    vertices = _g1d_tensor_box_vertices(x)
    lower_big = ntuple(i -> minimum(matrix[i][i] for matrix in vertices), 3)
    upper_big = ntuple(i -> maximum(matrix[i][i] for matrix in vertices), 3)
    lower = try
        ntuple(i -> Rational{Int64}(lower_big[i]), 3)
    catch
        throw(ArgumentError("K diagonal enclosure is outside the exact rational range"))
    end
    upper = try
        ntuple(i -> Rational{Int64}(upper_big[i]), 3)
    catch
        throw(ArgumentError("K diagonal enclosure is outside the exact rational range"))
    end
    (lower=minimum(lower), upper=maximum(upper),
     diagonal_lower=lower, diagonal_upper=upper)
end

struct G1DiffusionScalarFieldV1
    field_id::String
    physical_type::PhysicalType
    source_ref::QualifiedRefV1
    source_expression::String
    function G1DiffusionScalarFieldV1(field_id::Any, physical_type::Any, source_ref::Any;
                                      source_expression=field_id)
        id = _g1d_text(field_id, "scalar field_id")
        ty = physical_type isa PhysicalType ? physical_type : throw(ArgumentError("scalar physical_type must be PhysicalType"))
        ty.tensor_rank == 0 && ty.spatial_dimension == 3 && ty.value_kind == :scalar_field ||
            throw(ArgumentError("u/f must be 3-D scalar fields"))
        new(id, ty, _g1d_ref(source_ref, "scalar source_ref"), _g1d_text(source_expression, "scalar source_expression"))
    end
end

struct G1DiffusionCoefficientFieldV1
    field_id::String
    physical_type::PhysicalType
    source_ref::QualifiedRefV1
    spatial_dependency::Symbol
    symmetry::Symbol
    positive_definite::Bool
    lower_bound::Rational{Int64}
    upper_bound::Rational{Int64}
    expression::Union{G1DiffusionDiagonalAffineKFieldV1,
        G1DiffusionSymmetricAffineTensorKFieldV2}
    function G1DiffusionCoefficientFieldV1(field_id::Any, physical_type::Any, source_ref::Any;
                                            spatial_dependency=:spatial, symmetry=:symmetric,
                                            positive_definite=true, lower_bound=1 // 1000,
                                            upper_bound=1000 // 1, expression=nothing)
        id = _g1d_text(field_id, "K field_id")
        ty = physical_type isa PhysicalType ? physical_type : throw(ArgumentError("K physical_type must be PhysicalType"))
        ty.tensor_rank == 2 && ty.spatial_dimension == 3 && ty.value_kind == :tensor_field ||
            throw(ArgumentError("K must be a 3-D rank-2 tensor field"))
        spatial_dependency === :spatial || throw(ArgumentError("K must declare spatial dependency"))
        symmetry === :symmetric || throw(ArgumentError("K must declare symmetric structure"))
        positive_definite === true || throw(ArgumentError("K must declare positive definiteness"))
        expression isa Union{G1DiffusionDiagonalAffineKFieldV1,
            G1DiffusionSymmetricAffineTensorKFieldV2} ||
            throw(ArgumentError("K requires a supported candidate-owned affine tensor expression"))
        enclosure = g1_diffusion_k_enclosure(expression)
        lo = Rational{Int64}(lower_bound); hi = Rational{Int64}(upper_bound)
        lo == enclosure.lower && hi == enclosure.upper ||
            throw(ArgumentError("K bounds must equal the exact diagonal-affine enclosure"))
        new(id, ty, _g1d_ref(source_ref, "K source_ref"), spatial_dependency, symmetry,
            positive_definite, lo, hi, expression)
    end
end

struct G1TypedGradV1
    operator_ref::QualifiedRefV1
    input_field_id::String
    output_field_id::String
    input_type::PhysicalType
    output_type::PhysicalType
    function G1TypedGradV1(operator_ref::Any, input_field_id::Any, output_field_id::Any,
                           input_type::Any, output_type::Any)
        ref = _g1d_ref(operator_ref, "GRAD operator_ref")
        ref.id == G1_DIFFUSION_GRAD_OPERATOR_ID_V1 || throw(ArgumentError("GRAD operator id must be the diffusion GRAD id"))
        ref.version == "v1" || throw(ArgumentError("GRAD operator version must be v1"))
        i = input_type isa PhysicalType ? input_type : throw(ArgumentError("GRAD input type must be PhysicalType"))
        o = output_type isa PhysicalType ? output_type : throw(ArgumentError("GRAD output type must be PhysicalType"))
        i.tensor_rank == 0 && i.spatial_dimension == 3 && i.value_kind == :scalar_field &&
            o isa PhysicalType && o.temporal_type == i.temporal_type ||
            throw(ArgumentError("GRAD input/output must be matching 3-D scalar/vector temporal types"))
        o.tensor_rank == 1 && o.spatial_dimension == 3 && o.value_kind == :vector_field ||
            throw(ArgumentError("GRAD output must be a 3-D vector"))
        o.units == _g1d_sub(i.units, _g1d_length_unit()) || throw(ArgumentError("GRAD unit closure failed"))
        new(ref, _g1d_text(input_field_id, "GRAD input_field_id"), _g1d_text(output_field_id, "GRAD output_field_id"), i, o)
    end
end

struct G1TypedKApplyV1
    operator_ref::QualifiedRefV1
    input_field_id::String
    output_field_id::String
    input_type::PhysicalType
    output_type::PhysicalType
    coefficient_field_id::String
    coefficient_units::UnitSignature
    function G1TypedKApplyV1(operator_ref::Any, input_field_id::Any, output_field_id::Any,
                             input_type::Any, output_type::Any, coefficient_field_id::Any;
                             coefficient_units=UnitSignature())
        ref = _g1d_ref(operator_ref, "K_APPLY operator_ref")
        ref.id == G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1 || throw(ArgumentError("K_APPLY operator id must be the diffusion K_APPLY id"))
        ref.version == "v1" || throw(ArgumentError("K_APPLY operator version must be v1"))
        i = input_type isa PhysicalType ? input_type : throw(ArgumentError("K_APPLY input type must be PhysicalType"))
        o = output_type isa PhysicalType ? output_type : throw(ArgumentError("K_APPLY output type must be PhysicalType"))
        i.tensor_rank == 1 && i.spatial_dimension == 3 && i.value_kind == :vector_field ||
            throw(ArgumentError("K_APPLY input must be a 3-D vector"))
        o.tensor_rank == 1 && o.spatial_dimension == 3 && o.value_kind == :vector_field ||
            throw(ArgumentError("K_APPLY output must be a 3-D vector"))
        cu = _g1d_unit(coefficient_units, "K_APPLY coefficient_units")
        o.units == _g1d_add(i.units, cu) && o.temporal_type == i.temporal_type ||
            throw(ArgumentError("K_APPLY output type closure failed"))
        new(ref, _g1d_text(input_field_id, "K_APPLY input_field_id"), _g1d_text(output_field_id, "K_APPLY output_field_id"), i, o,
            _g1d_text(coefficient_field_id, "K_APPLY coefficient_field_id"), cu)
    end
end

struct G1TypedDivV1
    operator_ref::QualifiedRefV1
    input_field_id::String
    output_field_id::String
    input_type::PhysicalType
    output_type::PhysicalType
    function G1TypedDivV1(operator_ref::Any, input_field_id::Any, output_field_id::Any,
                          input_type::Any, output_type::Any)
        ref = _g1d_ref(operator_ref, "DIV operator_ref")
        ref.id == G1_DIFFUSION_DIV_OPERATOR_ID_V1 || throw(ArgumentError("DIV operator id must be the diffusion DIV id"))
        ref.version == "v1" || throw(ArgumentError("DIV operator version must be v1"))
        i = input_type isa PhysicalType ? input_type : throw(ArgumentError("DIV input type must be PhysicalType"))
        o = output_type isa PhysicalType ? output_type : throw(ArgumentError("DIV output type must be PhysicalType"))
        i.tensor_rank == 1 && i.spatial_dimension == 3 && i.value_kind == :vector_field ||
            throw(ArgumentError("DIV input must be a 3-D vector"))
        o.tensor_rank == 0 && o.spatial_dimension == 3 && o.value_kind == :scalar_field ||
            throw(ArgumentError("DIV output must be a 3-D scalar"))
        o.units == _g1d_sub(i.units, _g1d_length_unit()) && o.temporal_type == i.temporal_type ||
            throw(ArgumentError("DIV output type closure failed"))
        new(ref, _g1d_text(input_field_id, "DIV input_field_id"), _g1d_text(output_field_id, "DIV output_field_id"), i, o)
    end
end

struct G1DiffusionUnknownStateBindingV1
    state_index::Int
    role::Symbol
    field_id::String
    physical_type::PhysicalType
    function G1DiffusionUnknownStateBindingV1(state_index::Any, role::Any,
                                               field_id::Any, physical_type::Any)
        state_index isa Integer && !(state_index isa Bool) && state_index == 0 ||
            throw(ArgumentError("unknown-state binding state_index must be 0"))
        role === :unknown || throw(ArgumentError("unknown-state binding role must be :unknown"))
        id = _g1d_text(field_id, "unknown-state binding field_id")
        ty = physical_type isa PhysicalType ? physical_type :
            throw(ArgumentError("unknown-state binding physical_type must be PhysicalType"))
        new(Int(state_index), :unknown, id, ty)
    end
end

semantic_view(x::G1DiffusionUnknownStateBindingV1) =
    (state_index=x.state_index, role=x.role, field_id=x.field_id, physical_type=x.physical_type)

struct G1DiffusionOperatorTemporalWhitelistV1
    operator_ref::QualifiedRefV1
    temporal_kinds::Tuple{Vararg{TimeKindV1}}
    function G1DiffusionOperatorTemporalWhitelistV1(operator_ref::Any, temporal_kinds::Any)
        ref = _g1d_ref(operator_ref, "operator temporal whitelist operator_ref")
        ref.version == "v1" || throw(ArgumentError("operator temporal whitelist ref version must be v1"))
        ref.id in (G1_DIFFUSION_GRAD_OPERATOR_ID_V1,
                   G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1,
                   G1_DIFFUSION_DIV_OPERATOR_ID_V1) ||
            throw(ArgumentError("operator temporal whitelist ref must name GRAD, K_APPLY or DIV"))
        kinds = Tuple(temporal_kinds)
        !isempty(kinds) && all(kind -> kind isa TimeKindV1, kinds) ||
            throw(ArgumentError("operator temporal whitelist must contain TimeKindV1 members"))
        length(unique(kinds)) == length(kinds) ||
            throw(ArgumentError("operator temporal whitelist members must be unique"))
        new(ref, kinds)
    end
end

semantic_view(x::G1DiffusionOperatorTemporalWhitelistV1) =
    (operator_ref=x.operator_ref, temporal_kinds=x.temporal_kinds)

struct G1DiffusionOperatorTemporalSupportV1
    grad::G1DiffusionOperatorTemporalWhitelistV1
    coefficient_apply::G1DiffusionOperatorTemporalWhitelistV1
    div::G1DiffusionOperatorTemporalWhitelistV1
    function G1DiffusionOperatorTemporalSupportV1(grad::Any, coefficient_apply::Any, div::Any)
        grad isa G1DiffusionOperatorTemporalWhitelistV1 ||
            throw(ArgumentError("GRAD temporal support must be a typed whitelist"))
        coefficient_apply isa G1DiffusionOperatorTemporalWhitelistV1 ||
            throw(ArgumentError("K_APPLY temporal support must be a typed whitelist"))
        div isa G1DiffusionOperatorTemporalWhitelistV1 ||
            throw(ArgumentError("DIV temporal support must be a typed whitelist"))
        grad.operator_ref == QualifiedRefV1(G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1") ||
            throw(ArgumentError("GRAD temporal whitelist identity mismatch"))
        coefficient_apply.operator_ref == QualifiedRefV1(G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1") ||
            throw(ArgumentError("K_APPLY temporal whitelist identity mismatch"))
        div.operator_ref == QualifiedRefV1(G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1") ||
            throw(ArgumentError("DIV temporal whitelist identity mismatch"))
        new(grad, coefficient_apply, div)
    end
end

semantic_view(x::G1DiffusionOperatorTemporalSupportV1) =
    (grad=x.grad, coefficient_apply=x.coefficient_apply, div=x.div)

"""Candidate-authored normal-flux port pair for one internal diffusion interface.

This is an unevaluated contract over K_APPLY's vector output; it grants no
physical or provider authority. `left_sign` and `right_sign` express each
region's outward normal relative to the left-to-right interface orientation.
"""
struct G1DiffusionInterfaceFluxPairV1
    interface_ref::QualifiedRefV1
    left_region_id::String
    right_region_id::String
    left_port_id::String
    right_port_id::String
    operator_ref::QualifiedRefV1
    field_id::String
    left_outward_normal::NTuple{3,Int8}
    right_outward_normal::NTuple{3,Int8}
    left_sign::Int8
    right_sign::Int8
    law::Symbol
    function G1DiffusionInterfaceFluxPairV1(interface_ref::Any,
            left_region_id::Any, right_region_id::Any, left_port_id::Any,
            right_port_id::Any, operator_ref::Any, field_id::Any,
            left_outward_normal::Any, right_outward_normal::Any,
            left_sign::Any, right_sign::Any, law::Any)
        interface_ref isa QualifiedRefV1 && interface_ref.version == "v2" ||
            throw(ArgumentError("interface flux pair requires a v2 G2 interface ref"))
        left_region_id isa AbstractString && !isempty(String(left_region_id)) &&
            right_region_id isa AbstractString && !isempty(String(right_region_id)) &&
            String(left_region_id) != String(right_region_id) ||
            throw(ArgumentError("interface flux pair regions must be distinct nonempty ids"))
        left_port_id isa AbstractString && !isempty(String(left_port_id)) &&
            right_port_id isa AbstractString && !isempty(String(right_port_id)) &&
            String(left_port_id) != String(right_port_id) ||
            throw(ArgumentError("interface flux pair ports must be distinct nonempty ids"))
        operator_ref isa QualifiedRefV1 && operator_ref.version == "v1" &&
            operator_ref.id == G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1 ||
            throw(ArgumentError("interface flux ports must use the typed K_APPLY operator"))
        left_outward_normal isa Tuple && length(left_outward_normal) == 3 &&
            right_outward_normal isa Tuple && length(right_outward_normal) == 3 &&
            all(x -> x isa Integer && !(x isa Bool) && x in (-1, 0, 1),
                (left_outward_normal..., right_outward_normal...)) ||
            throw(ArgumentError("interface flux outward normals must be typed signed axis vectors"))
        left_normal = ntuple(i -> Int8(left_outward_normal[i]), 3)
        right_normal = ntuple(i -> Int8(right_outward_normal[i]), 3)
        left_normal == (Int8(1), Int8(0), Int8(0)) && right_normal == (Int8(-1), Int8(0), Int8(0)) ||
            throw(ArgumentError("this x-half interface requires left +x and right -x outward normals"))
        left_sign isa Integer && !(left_sign isa Bool) && right_sign isa Integer &&
            !(right_sign isa Bool) && left_sign in (-1, 1) && right_sign == -left_sign ||
            throw(ArgumentError("interface flux signs must be opposite signed orientations"))
        law === :left_outward_flux_plus_right_outward_flux_equals_zero ||
            throw(ArgumentError("unsupported authored interface flux law"))
        new(interface_ref, String(left_region_id), String(right_region_id),
            String(left_port_id), String(right_port_id), operator_ref,
            _g1d_text(field_id, "interface flux field_id"), left_normal,
            right_normal, Int8(left_sign), Int8(right_sign), law)
    end
end
semantic_view(x::G1DiffusionInterfaceFluxPairV1) =
    (interface_ref=x.interface_ref, left_region_id=x.left_region_id,
     right_region_id=x.right_region_id, left_port_id=x.left_port_id,
     right_port_id=x.right_port_id, operator_ref=x.operator_ref,
     field_id=x.field_id, left_outward_normal=x.left_outward_normal,
     right_outward_normal=x.right_outward_normal, left_sign=x.left_sign,
     right_sign=x.right_sign, law=x.law)

"""An explicitly authored source-bound transient volumetric capacity.

For the SI thermal lane this is rho*cp in J/(m^3 K).  It is optional for a
steady declaration, but no transient consumer may infer or default it.
"""
struct G1DiffusionTransientCapacityV1
    coefficient::Float64
    units::UnitSignature
    source_ref::QualifiedRefV1
    applicable_domain::Symbol
    closed::Bool
    function G1DiffusionTransientCapacityV1(coefficient, units, source_ref;
                                            applicable_domain=:transient_thermal_diffusion,
                                            closed=false)
        value = Float64(coefficient)
        isfinite(value) && value > 0.0 ||
            throw(ArgumentError("transient volumetric capacity must be finite and positive"))
        typed_units = _g1d_unit(units, "transient capacity units")
        source = _g1d_ref(source_ref, "transient capacity source_ref")
        domain = Symbol(applicable_domain)
        domain === :transient_thermal_diffusion ||
            throw(ArgumentError("transient capacity applicable_domain is unsupported"))
        closed === true || throw(ArgumentError("transient capacity must be explicitly closed"))
        new(value, typed_units, source, domain, true)
    end
end
semantic_view(x::G1DiffusionTransientCapacityV1) =
    (coefficient=x.coefficient, units=x.units, source_ref=x.source_ref,
     applicable_domain=x.applicable_domain, closed=x.closed,
     kind=:volumetric_heat_capacity)

struct G1DiffusionSourcePayloadV1
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_version::String
    u::G1DiffusionScalarFieldV1
    K::G1DiffusionCoefficientFieldV1
    f::G1DiffusionScalarFieldV1
    unknown_state_binding::Union{Nothing,G1DiffusionUnknownStateBindingV1}
    operator_temporal_support::Union{Nothing,G1DiffusionOperatorTemporalSupportV1}
    interface_flux_pair::Union{Nothing,G1DiffusionInterfaceFluxPairV1}
    transient_capacity::Union{Nothing,G1DiffusionTransientCapacityV1}
    function G1DiffusionSourcePayloadV1(candidate_ref::Any, source_ref::Any, source_version::Any,
                                        u::G1DiffusionScalarFieldV1,
                                        K::G1DiffusionCoefficientFieldV1,
                                        f::G1DiffusionScalarFieldV1;
                                        unknown_state_binding=nothing,
                                        operator_temporal_support=nothing,
                                        interface_flux_pair=nothing,
                                        transient_capacity=nothing)
        candidate = _g1d_ref(candidate_ref, "source payload candidate_ref")
        candidate.version == "v5" || throw(ArgumentError("source payload candidate_ref must use v5"))
        src = _g1d_ref(source_ref, "source payload source_ref")
        u.source_ref == src && K.source_ref == src && f.source_ref == src ||
            throw(ArgumentError("source payload field identities must match source_ref"))
        binding = if unknown_state_binding === nothing
            nothing
        else
            unknown_state_binding isa G1DiffusionUnknownStateBindingV1 ||
                throw(ArgumentError("unknown_state_binding must be G1DiffusionUnknownStateBindingV1 or nothing"))
            unknown_state_binding.field_id == u.field_id ||
                throw(ArgumentError("unknown-state binding field_id must identify u"))
            unknown_state_binding.physical_type == u.physical_type ||
                throw(ArgumentError("unknown-state binding physical_type must match u exactly"))
            unknown_state_binding
        end
        temporal_support = if operator_temporal_support === nothing
            nothing
        else
            operator_temporal_support isa G1DiffusionOperatorTemporalSupportV1 ||
                throw(ArgumentError("operator_temporal_support must be G1DiffusionOperatorTemporalSupportV1 or nothing"))
            operator_temporal_support
        end
        flux_pair = if interface_flux_pair === nothing
            nothing
        else
            interface_flux_pair isa G1DiffusionInterfaceFluxPairV1 ||
                throw(ArgumentError("interface_flux_pair must be G1DiffusionInterfaceFluxPairV1 or nothing"))
            interface_flux_pair
        end
        capacity = if transient_capacity === nothing
            nothing
        else
            transient_capacity isa G1DiffusionTransientCapacityV1 ||
                throw(ArgumentError("transient_capacity must be G1DiffusionTransientCapacityV1 or nothing"))
            transient_capacity.source_ref == src ||
                throw(ArgumentError("transient capacity source_ref must match source payload source_ref"))
            transient_capacity
        end
        new(candidate, src, _g1d_text(source_version, "source payload source_version"), u, K, f,
            binding, temporal_support, flux_pair, capacity)
    end
end

G1DiffusionSourcePayloadV1(::Any, ::Any, ::G1DiffusionScalarFieldV1,
                           ::G1DiffusionCoefficientFieldV1, ::G1DiffusionScalarFieldV1) =
    throw(ArgumentError("candidate_ref is required for a candidate-bound source payload"))

semantic_view(x::G1DiffusionSourcePayloadV1) = begin
    body = (schema_id="GenomeV5/G1/DiffusionSourcePayloadV1", version="v1",
            candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_version=x.source_version,
            u=x.u, K=x.K, f=x.f)
    if x.unknown_state_binding !== nothing
        body = merge(body, (unknown_state_binding=x.unknown_state_binding,))
    end
    if x.operator_temporal_support !== nothing
        body = merge(body, (operator_temporal_support=x.operator_temporal_support,))
    end
    x.interface_flux_pair === nothing ||
        (body = merge(body, (interface_flux_pair=x.interface_flux_pair,)))
    x.transient_capacity === nothing ||
        (body = merge(body, (transient_capacity=x.transient_capacity,)))
    body
end
canonical_json(x::G1DiffusionSourcePayloadV1) = canonical_json(semantic_view(x))
g1_diffusion_source_hash_v1(x::G1DiffusionSourcePayloadV1) = canonical_hash(x)

struct G1DiffusionOperatorChainV1
    grad::G1TypedGradV1
    coefficient_apply::G1TypedKApplyV1
    div::G1TypedDivV1
    source_field_id::String
    residual_sign::Int8
    function G1DiffusionOperatorChainV1(grad::G1TypedGradV1, coefficient_apply::G1TypedKApplyV1,
                                        div::G1TypedDivV1, source_field_id::Any; residual_sign=-1)
        coefficient_apply.input_field_id == grad.output_field_id || throw(ArgumentError("K_APPLY input is not GRAD output"))
        div.input_field_id == coefficient_apply.output_field_id || throw(ArgumentError("DIV input is not K_APPLY output"))
        div.output_field_id == String(source_field_id) || throw(ArgumentError("DIV output is not source field"))
        residual_sign isa Integer && !(residual_sign isa Bool) && residual_sign == -1 ||
            throw(ArgumentError("diffusion residual sign must be the typed value -1"))
        new(grad, coefficient_apply, div, _g1d_text(source_field_id, "operator chain source_field_id"), Int8(-1))
    end
end

struct G1DiffusionDeclarationV1
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_version::String
    source_payload::G1DiffusionSourcePayloadV1
    source_hash::Digest256
    u::G1DiffusionScalarFieldV1
    K::G1DiffusionCoefficientFieldV1
    f::G1DiffusionScalarFieldV1
    operators::G1DiffusionOperatorChainV1
    closure_ref::QualifiedRefV1
    applicability_ref::QualifiedRefV1
    applicability_domain::String
    ownership::Symbol
    negative_controls::Tuple{Vararg{Symbol}}
    declaration_hash::Digest256
    function G1DiffusionDeclarationV1(candidate_ref::Any, source_ref::Any, source_version::Any,
                                       source_hash::Any, u::G1DiffusionScalarFieldV1,
                                       K::G1DiffusionCoefficientFieldV1, f::G1DiffusionScalarFieldV1,
                                       operators::G1DiffusionOperatorChainV1, closure_ref::Any,
                                       applicability_ref::Any, applicability_domain::Any,
                                       negative_controls::Any; ownership=:candidate_owned,
                                       source_payload=nothing, declaration_hash=nothing)
        candidate = _g1d_ref(candidate_ref, "candidate_ref")
        candidate.version == "v5" || throw(ArgumentError("candidate_ref must use v5"))
        src = _g1d_ref(source_ref, "source_ref")
        sh = _g1d_digest(source_hash, "source_hash")
        source_payload isa G1DiffusionSourcePayloadV1 ||
            throw(ArgumentError("candidate-owned source_payload is required"))
        source_payload.candidate_ref == candidate ||
            throw(ArgumentError("source payload candidate_ref does not match declaration candidate_ref"))
        source_payload.source_ref == src || throw(ArgumentError("source payload ref mismatch"))
        source_payload.source_version == String(source_version) || throw(ArgumentError("source payload version mismatch"))
        canonical_hash(source_payload.u) == canonical_hash(u) &&
            canonical_hash(source_payload.K) == canonical_hash(K) &&
            canonical_hash(source_payload.f) == canonical_hash(f) ||
            throw(ArgumentError("source payload fields must match declaration fields"))
        sh == g1_diffusion_source_hash_v1(source_payload) ||
            throw(ArgumentError("source_hash does not match candidate-owned source payload"))
        u.source_ref == src && K.source_ref == src && f.source_ref == src ||
            throw(ArgumentError("u/K/f source identities must match declaration source_ref"))
        capacity = source_payload.transient_capacity
        if capacity !== nothing
            capacity.source_ref == src ||
                throw(ArgumentError("transient capacity source identity must match declaration source_ref"))
            capacity.applicable_domain === :transient_thermal_diffusion ||
                throw(ArgumentError("transient capacity applicable domain is unsupported"))
            _g1d_add(_g1d_sub(capacity.units, UnitSignature((0, 0, 1, 0, 0, 0, 0))),
                u.physical_type.units) == f.physical_type.units ||
                throw(ArgumentError("transient capacity, time, u and f units do not close"))
        end
        operators.grad.input_field_id == u.field_id || throw(ArgumentError("GRAD must consume u"))
        operators.div.output_field_id == f.field_id || throw(ArgumentError("DIV must produce f"))
        u.physical_type.units == operators.grad.input_type.units || throw(ArgumentError("u/GRAD units disagree"))
        f.physical_type.units == operators.div.output_type.units || throw(ArgumentError("f/DIV units disagree"))
        operators.coefficient_apply.coefficient_field_id == K.field_id ||
            throw(ArgumentError("K_APPLY coefficient field binding mismatch"))
        operators.coefficient_apply.coefficient_units == K.physical_type.units ||
            throw(ArgumentError("K_APPLY coefficient units disagree with K"))
        operators.coefficient_apply.output_type.units ==
            _g1d_add(operators.coefficient_apply.input_type.units, K.physical_type.units) ||
            throw(ArgumentError("K_APPLY unit closure failed"))
        operators.grad.operator_ref.id == G1_DIFFUSION_GRAD_OPERATOR_ID_V1 ||
            throw(ArgumentError("GRAD operator id is not the diffusion operator"))
        operators.coefficient_apply.operator_ref.id == G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1 ||
            throw(ArgumentError("K_APPLY operator id is not the diffusion operator"))
        operators.div.operator_ref.id == G1_DIFFUSION_DIV_OPERATOR_ID_V1 ||
            throw(ArgumentError("DIV operator id is not the diffusion operator"))
        operators.grad.input_type == u.physical_type ||
            throw(ArgumentError("GRAD input PhysicalType does not equal u PhysicalType"))
        operators.grad.output_type == operators.coefficient_apply.input_type ||
            throw(ArgumentError("GRAD output PhysicalType does not equal K_APPLY input PhysicalType"))
        operators.coefficient_apply.output_type == operators.div.input_type ||
            throw(ArgumentError("K_APPLY output PhysicalType does not equal DIV input PhysicalType"))
        operators.div.output_type == f.physical_type ||
            throw(ArgumentError("DIV output PhysicalType does not equal f PhysicalType"))
        temporal_support = source_payload.operator_temporal_support
        if temporal_support !== nothing
            _g1d_temporal_support_matches(temporal_support.grad, operators.grad.operator_ref,
                operators.grad.input_type, operators.grad.output_type, "GRAD")
            _g1d_temporal_support_matches(temporal_support.coefficient_apply,
                operators.coefficient_apply.operator_ref, operators.coefficient_apply.input_type,
                operators.coefficient_apply.output_type, "K_APPLY")
            _g1d_temporal_support_matches(temporal_support.div, operators.div.operator_ref,
                operators.div.input_type, operators.div.output_type, "DIV")
        end
        flux_pair = source_payload.interface_flux_pair
        if flux_pair !== nothing
            flux_pair.operator_ref == operators.coefficient_apply.operator_ref &&
                flux_pair.field_id == operators.coefficient_apply.output_field_id &&
                operators.coefficient_apply.output_type.value_kind === :vector_field &&
                operators.coefficient_apply.output_type.tensor_rank == 1 &&
                operators.coefficient_apply.output_type.spatial_dimension == 3 ||
                throw(ArgumentError("interface flux pair is not bound to the typed K_APPLY vector output"))
            flux_pair.left_sign == flux_pair.left_outward_normal[1] &&
                flux_pair.right_sign == flux_pair.right_outward_normal[1] ||
                throw(ArgumentError("interface flux signs do not match authored outward orientation"))
        end
        closure = _g1d_ref(closure_ref, "closure_ref")
        closure.id == G1_DIFFUSION_CLOSURE_ID_V1 && closure.version == G1_DIFFUSION_PROFILE_VERSION_V1 ||
            throw(ArgumentError("closure_ref is not bound to the diffusion profile"))
        applicability = _g1d_ref(applicability_ref, "applicability_ref")
        applicability.id == G1_DIFFUSION_APPLICABILITY_ID_V1 && applicability.version == G1_DIFFUSION_PROFILE_VERSION_V1 ||
            throw(ArgumentError("applicability_ref is not bound to the diffusion profile"))
        ownership === :candidate_owned || throw(ArgumentError("diffusion fields must be candidate-owned"))
        isempty(negative_controls) || all(x -> x isa Symbol, Tuple(negative_controls)) ||
            throw(ArgumentError("negative_controls must be symbols"))
        new(candidate, src, _g1d_text(source_version, "source_version"), source_payload, sh, u, K, f, operators,
            _g1d_ref(closure_ref, "closure_ref"), _g1d_ref(applicability_ref, "applicability_ref"),
            _g1d_text(applicability_domain, "applicability_domain"), ownership, Tuple(Symbol.(negative_controls)),
            declaration_hash === nothing ? Digest256(repeat("0", 64)) : _g1d_digest(declaration_hash, "declaration_hash"))
    end
end

semantic_view(x::G1DiffusionScalarFieldV1) =
    (field_id=x.field_id, physical_type=x.physical_type, source_ref=x.source_ref,
     source_expression=x.source_expression)
semantic_view(x::G1DiffusionCoefficientFieldV1) =
    (field_id=x.field_id, physical_type=x.physical_type, source_ref=x.source_ref,
     spatial_dependency=x.spatial_dependency, symmetry=x.symmetry,
     positive_definite=x.positive_definite, lower_bound=x.lower_bound, upper_bound=x.upper_bound,
     expression=x.expression)
semantic_view(x::G1TypedGradV1) =
    (operator_ref=x.operator_ref, input_field_id=x.input_field_id, output_field_id=x.output_field_id,
     input_type=x.input_type, output_type=x.output_type)
semantic_view(x::G1TypedKApplyV1) =
    (operator_ref=x.operator_ref, input_field_id=x.input_field_id, output_field_id=x.output_field_id,
     input_type=x.input_type, output_type=x.output_type, coefficient_field_id=x.coefficient_field_id,
     coefficient_units=x.coefficient_units)
semantic_view(x::G1TypedDivV1) =
    (operator_ref=x.operator_ref, input_field_id=x.input_field_id, output_field_id=x.output_field_id,
     input_type=x.input_type, output_type=x.output_type)
semantic_view(x::G1DiffusionOperatorChainV1) =
    (grad=x.grad, coefficient_apply=x.coefficient_apply, div=x.div,
     source_field_id=x.source_field_id, residual_sign=x.residual_sign)

function _g1d_temporal_support_matches(support::G1DiffusionOperatorTemporalWhitelistV1,
                                       operator_ref::QualifiedRefV1,
                                       input_type::PhysicalType, output_type::PhysicalType,
                                       label::AbstractString)
    support.operator_ref == operator_ref ||
        throw(ArgumentError("$label temporal whitelist operator identity does not match declaration"))
    input_type.temporal_type.kind in support.temporal_kinds &&
        output_type.temporal_type.kind in support.temporal_kinds ||
        throw(ArgumentError("$label temporal whitelist does not contain actual input/output temporal kinds"))
    nothing
end

function _g1d_declaration_body(x::G1DiffusionDeclarationV1)
    (schema_id=G1_DIFFUSION_SCHEMA_ID_V1, schema_version=G1_DIFFUSION_SCHEMA_VERSION_V1,
     candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_version=x.source_version,
      source_payload=x.source_payload, source_hash=x.source_hash, u=x.u, K=x.K, f=x.f, operators=x.operators,
      closure_ref=x.closure_ref, applicability_ref=x.applicability_ref,
      profile_version=G1_DIFFUSION_PROFILE_VERSION_V1,
      closure_profile_hash=g1_diffusion_closure_hash_v1(),
      applicability_profile_hash=g1_diffusion_applicability_hash_v1(),
      applicability_domain=x.applicability_domain, ownership=x.ownership,
     negative_controls=x.negative_controls)
end
semantic_view(x::G1DiffusionDeclarationV1) =
    merge(_g1d_declaration_body(x), (declaration_hash=x.declaration_hash,))
canonical_json(x::Union{G1DiffusionSymmetricAffineTensorKFieldV2,
                        G1DiffusionScalarFieldV1,G1DiffusionCoefficientFieldV1,G1TypedGradV1,
                        G1TypedKApplyV1,G1TypedDivV1,G1DiffusionOperatorChainV1,
                        G1DiffusionDeclarationV1}) = canonical_json(semantic_view(x))

"""Build a declaration and seal its content hash after all typed checks pass."""
function g1_diffusion_declaration_v1(args...; kwargs...)
    draft = G1DiffusionDeclarationV1(args...; kwargs...)
    body = _g1d_declaration_body(draft)
    # The immutable record is rebuilt with the computed hash; no source field is hidden.
    G1DiffusionDeclarationV1(draft.candidate_ref, draft.source_ref, draft.source_version, draft.source_hash,
        draft.u, draft.K, draft.f, draft.operators, draft.closure_ref, draft.applicability_ref,
        draft.applicability_domain, draft.negative_controls; ownership=draft.ownership,
        source_payload=draft.source_payload,
        declaration_hash=canonical_hash(body))
end

g1_diffusion_declaration_hash_v1(x::G1DiffusionDeclarationV1) = x.declaration_hash

struct G1DiffusionAdmissionResultV1
    status::Symbol
    error_code::Symbol
    error_path::String
    declaration::Union{Nothing,G1DiffusionDeclarationV1}
    exception_type::Union{Nothing,DataType}
end

_g1d_admission_fail(code::Symbol, path::AbstractString) =
    G1DiffusionAdmissionResultV1(:fail_closed, code, String(path), nothing, nothing)
_g1d_admission_deferred(path::AbstractString, declaration=nothing) =
    G1DiffusionAdmissionResultV1(:terminal_deferred, :missing_external_authority,
        String(path), declaration, nothing)
_g1d_admission_program_exception(path::AbstractString, error::Exception) =
    G1DiffusionAdmissionResultV1(:program_exception, :unexpected_exception,
        String(path), nothing, typeof(error))

function _g1d_admit_v1_impl(declaration::Any, validator::Function)
    declaration isa G1DiffusionDeclarationV1 || return _g1d_admission_fail(:declaration_type, "/declaration")
    result = try
        validator(declaration)
    catch error
        return _g1d_admission_program_exception("/declaration", error)
    end
    result[1] == :valid || return _g1d_admission_fail(:declaration_validation, "/declaration")
    _g1d_admission_deferred("/authority/source", declaration)
end

"""Typed public admission; the validator is fixed to the production validator."""
g1_diffusion_admit_v1(declaration::Any) = _g1d_admit_v1_impl(declaration, g1_diffusion_validate)

"""Internal static-QA seam; never exposed as a public checker injection point."""
function _g1d_admit_v1_fault_probe(declaration::Any)
    _g1d_admit_v1_impl(declaration, _ -> throw(ErrorException("controlled admission fault seam")))
end

"""Typed source/hash admission. A valid payload still has no external authority in this slice."""
function g1_diffusion_admit_source_v1(payload::Any, supplied_hash::Any)
    payload isa G1DiffusionSourcePayloadV1 || return _g1d_admission_fail(:source_payload_type, "/source_payload")
    supplied_hash isa Digest256 || return _g1d_admission_fail(:source_hash_type, "/source_hash")
    computed_hash = try
        g1_diffusion_source_hash_v1(payload)
    catch error
        return _g1d_admission_program_exception("/source_payload", error)
    end
    supplied_hash == computed_hash ||
        return _g1d_admission_fail(:source_hash_mismatch, "/source_hash")
    _g1d_admission_deferred("/authority/source")
end

"""Typed K profile admission with explicit bound and domain paths."""
function g1_diffusion_admit_k_v1(expression::Any; lower_bound=nothing, upper_bound=nothing, probe_point=nothing)
    expression isa Union{G1DiffusionDiagonalAffineKFieldV1,
        G1DiffusionSymmetricAffineTensorKFieldV2} ||
        return _g1d_admission_fail(:K_expression_type, "/K/expression")
    expression isa G1DiffusionSymmetricAffineTensorKFieldV2 &&
        !_g1d_tensor_k_admissible(expression) &&
        return _g1d_admission_fail(:K_not_positive_definite, "/K/expression")
    enclosure = try
        g1_diffusion_k_enclosure(expression)
    catch error
        return _g1d_admission_program_exception("/K/expression", error)
    end
    lower_bound === nothing || lower_bound == enclosure.lower ||
        return _g1d_admission_fail(:K_lower_bound_mismatch, "/K/lower_bound")
    upper_bound === nothing || upper_bound == enclosure.upper ||
        return _g1d_admission_fail(:K_upper_bound_mismatch, "/K/upper_bound")
    if probe_point !== nothing
        point = try
            _g1d_r3(probe_point, "K probe_point")
        catch
            return _g1d_admission_fail(:K_probe_point_malformed, "/K/probe_point")
        end
        all(expression.domain_min[i] <= point[i] <= expression.domain_max[i] for i in 1:3) ||
            return _g1d_admission_fail(:K_domain_out_of_bounds, "/K/probe_point")
    end
    _g1d_admission_deferred("/authority/source")
end

"""Typed operator admission for sign and unit contradictions."""
function g1_diffusion_admit_chain_v1(chain::Any; expected_residual_sign=-1,
                                     expected_grad_input_units=nothing,
                                     expected_div_output_units=nothing)
    chain isa G1DiffusionOperatorChainV1 || return _g1d_admission_fail(:operator_chain_type, "/operators")
    expected_residual_sign == -1 || return _g1d_admission_fail(:expected_residual_sign_not_negative, "/operators/residual_sign")
    chain.residual_sign == -1 || return _g1d_admission_fail(:residual_sign_not_negative, "/operators/residual_sign")
    expected_grad_input_units === nothing || chain.grad.input_type.units == expected_grad_input_units ||
        return _g1d_admission_fail(:grad_unit_mismatch, "/operators/grad/input_type/units")
    expected_div_output_units === nothing || chain.div.output_type.units == expected_div_output_units ||
        return _g1d_admission_fail(:div_unit_mismatch, "/operators/div/output_type/units")
    _g1d_admission_deferred("/authority/source")
end

struct G1DiffusionReceiptV1
    declaration_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    status::Symbol
    accepted::Bool
    resolution::Symbol
    claim_ceiling::Symbol
    gaps::Tuple{Vararg{String}}
    compile_calls::Int
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    physical_evidence::Bool
end

semantic_view(x::G1DiffusionReceiptV1) =
    (declaration_hash=x.declaration_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
     status=x.status, accepted=x.accepted, resolution=x.resolution,
     claim_ceiling=x.claim_ceiling, gaps=x.gaps, compile_calls=x.compile_calls,
     provider_calls=x.provider_calls, mesh_calls=x.mesh_calls, solver_calls=x.solver_calls,
     physical_evidence=x.physical_evidence)
canonical_json(x::G1DiffusionReceiptV1) = canonical_json(semantic_view(x))
g1_diffusion_receipt_hash_v1(x::G1DiffusionReceiptV1) = canonical_hash(x)

function g1_diffusion_receipt_v1(x::G1DiffusionDeclarationV1)
    present = x.source_payload.interface_flux_pair !== nothing
    capacity_present = x.source_payload.transient_capacity !== nothing
    G1DiffusionReceiptV1(x.declaration_hash,
        g1_diffusion_schema_hash_v1(present, capacity_present),
        g1_diffusion_canonicalization_hash_v1(),
        g1_diffusion_profile_hash_v1(present, capacity_present),
        :proposal, false, :terminal_deferred, G1_DIFFUSION_CLAIM_CEILING_V1,
        G1_DIFFUSION_REQUIRED_GAPS_V1, 0, 0, 0, 0, false)
end

function g1_diffusion_validate(x::G1DiffusionDeclarationV1)
    errors = String[]
    x.candidate_ref.version == "v5" || push!(errors, "candidate_ref_version_not_v5")
    x.source_payload.candidate_ref == x.candidate_ref || push!(errors, "source_payload_candidate_binding_mismatch")
    x.source_payload.source_ref == x.source_ref || push!(errors, "source_payload_source_binding_mismatch")
    x.source_payload.transient_capacity === nothing ||
        (x.source_payload.transient_capacity.source_ref == x.source_ref &&
         x.source_payload.transient_capacity.closed &&
         x.source_payload.transient_capacity.applicable_domain === :transient_thermal_diffusion) ||
        push!(errors, "transient_capacity_source_binding_mismatch")
    x.K.lower_bound > 0 && x.K.upper_bound >= x.K.lower_bound || push!(errors, "K_bounds_not_positive_ordered")
    x.K.expression isa G1DiffusionSymmetricAffineTensorKFieldV2 &&
        !_g1d_tensor_k_admissible(x.K.expression) &&
        push!(errors, "K_affine_tensor_not_spd_on_declared_box")
    x.K.spatial_dependency === :spatial || push!(errors, "K_not_spatially_dependent")
    x.K.positive_definite || push!(errors, "K_not_positive_definite")
    x.ownership === :candidate_owned || push!(errors, "field_ownership_not_candidate_owned")
    x.operators.grad.input_field_id == x.u.field_id || push!(errors, "GRAD_u_binding_mismatch")
    x.operators.div.output_field_id == x.f.field_id || push!(errors, "DIV_f_binding_mismatch")
    x.operators.grad.operator_ref.id == G1_DIFFUSION_GRAD_OPERATOR_ID_V1 || push!(errors, "GRAD_operator_id_mismatch")
    x.operators.coefficient_apply.operator_ref.id == G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1 || push!(errors, "K_APPLY_operator_id_mismatch")
    x.operators.div.operator_ref.id == G1_DIFFUSION_DIV_OPERATOR_ID_V1 || push!(errors, "DIV_operator_id_mismatch")
    x.operators.grad.input_type == x.u.physical_type || push!(errors, "GRAD_input_type_mismatch")
    x.operators.grad.output_type == x.operators.coefficient_apply.input_type || push!(errors, "GRAD_K_APPLY_type_mismatch")
    x.operators.coefficient_apply.output_type == x.operators.div.input_type || push!(errors, "K_APPLY_DIV_type_mismatch")
    x.operators.div.output_type == x.f.physical_type || push!(errors, "DIV_f_type_mismatch")
    x.closure_ref.id == G1_DIFFUSION_CLOSURE_ID_V1 && x.closure_ref.version == G1_DIFFUSION_PROFILE_VERSION_V1 || push!(errors, "closure_profile_binding_mismatch")
    x.applicability_ref.id == G1_DIFFUSION_APPLICABILITY_ID_V1 && x.applicability_ref.version == G1_DIFFUSION_PROFILE_VERSION_V1 || push!(errors, "applicability_profile_binding_mismatch")
    x.operators.residual_sign == -1 || push!(errors, "diffusion_residual_sign_not_negative")
    x.declaration_hash == canonical_hash(_g1d_declaration_body(x)) || push!(errors, "declaration_hash_mismatch")
    isempty(x.source_version) && push!(errors, "source_version_missing")
    unique!(errors)
    isempty(errors) ? :valid : :fail_closed, Tuple(errors)
end

function g1_diffusion_edit_source(x::G1DiffusionDeclarationV1, field::Symbol, value)
    field === :u && value isa G1DiffusionScalarFieldV1 &&
        return begin
            payload = G1DiffusionSourcePayloadV1(x.candidate_ref, x.source_ref, x.source_version, value, x.K, x.f;
                unknown_state_binding=x.source_payload.unknown_state_binding,
                operator_temporal_support=x.source_payload.operator_temporal_support,
                interface_flux_pair=x.source_payload.interface_flux_pair,
                transient_capacity=x.source_payload.transient_capacity)
            g1_diffusion_declaration_v1(x.candidate_ref, x.source_ref, x.source_version,
                g1_diffusion_source_hash_v1(payload), value, x.K, x.f, x.operators,
                x.closure_ref, x.applicability_ref, x.applicability_domain, x.negative_controls;
                ownership=x.ownership, source_payload=payload)
        end
    field === :K && value isa G1DiffusionCoefficientFieldV1 &&
        return begin
            payload = G1DiffusionSourcePayloadV1(x.candidate_ref, x.source_ref, x.source_version, x.u, value, x.f;
                unknown_state_binding=x.source_payload.unknown_state_binding,
                operator_temporal_support=x.source_payload.operator_temporal_support,
                interface_flux_pair=x.source_payload.interface_flux_pair,
                transient_capacity=x.source_payload.transient_capacity)
            g1_diffusion_declaration_v1(x.candidate_ref, x.source_ref, x.source_version,
                g1_diffusion_source_hash_v1(payload), x.u, value, x.f, x.operators,
                x.closure_ref, x.applicability_ref, x.applicability_domain, x.negative_controls;
                ownership=x.ownership, source_payload=payload)
        end
    field === :f && value isa G1DiffusionScalarFieldV1 &&
        return begin
            payload = G1DiffusionSourcePayloadV1(x.candidate_ref, x.source_ref, x.source_version, x.u, x.K, value;
                unknown_state_binding=x.source_payload.unknown_state_binding,
                operator_temporal_support=x.source_payload.operator_temporal_support,
                interface_flux_pair=x.source_payload.interface_flux_pair,
                transient_capacity=x.source_payload.transient_capacity)
            g1_diffusion_declaration_v1(x.candidate_ref, x.source_ref, x.source_version,
                g1_diffusion_source_hash_v1(payload), x.u, x.K, value, x.operators,
                x.closure_ref, x.applicability_ref, x.applicability_domain, x.negative_controls;
                ownership=x.ownership, source_payload=payload)
        end
    throw(ArgumentError("editable source field must be :u, :K or :f with its typed declaration"))
end

g1_diffusion_edit_source(::G1DiffusionDeclarationV1, ::Symbol, ::AbstractString) =
    throw(ArgumentError("string-only diffusion source edits are rejected"))

function g1_diffusion_authority_check(x::G1DiffusionDeclarationV1; authoritative_source=false)
    authoritative_source === true ?
        (status=:terminal_deferred, reason="provider_not_invoked_in_preparation_slice") :
        (status=:terminal_deferred, reason="no_authoritative_external_source")
end
