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
const G1_DIFFUSION_PROFILE_ID_V1 =
    "fusionconceptai://GenomeV5/G1/diffusion/profile/v1"
const G1_DIFFUSION_CLAIM_CEILING_V1 = :contract_only
const G1_DIFFUSION_REQUIRED_GAPS_V1 =
    ("authority_terminal_deferred:no_external_source_or_provider",)

const _G1_DIFFUSION_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/G1/DiffusionDeclarationV1
version=v1
fields=candidate_ref,source_ref,source_version,source_payload,source_hash,u,K,f,grad,K_apply,div,closure,applicability,negative_controls
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

g1_diffusion_schema_hash_v1() = digest256_text(_G1_DIFFUSION_SCHEMA_SOURCE_V1)
g1_diffusion_canonicalization_hash_v1() = digest256_text(_G1_DIFFUSION_CANONICALIZATION_SOURCE_V1)
g1_diffusion_applicability_hash_v1() = digest256_text(_G1_DIFFUSION_APPLICABILITY_SOURCE_V1)
g1_diffusion_profile_hash_v1() = canonical_hash((
    profile_ref=G1_DIFFUSION_PROFILE_ID_V1,
    schema_version=G1_DIFFUSION_SCHEMA_VERSION_V1,
    schema_hash=g1_diffusion_schema_hash_v1(),
    canonicalization_hash=g1_diffusion_canonicalization_hash_v1(),
    applicability_hash=g1_diffusion_applicability_hash_v1(),
    claim_ceiling=G1_DIFFUSION_CLAIM_CEILING_V1))

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
    expression::G1DiffusionDiagonalAffineKFieldV1
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
        expression isa G1DiffusionDiagonalAffineKFieldV1 ||
            throw(ArgumentError("K requires a candidate-owned diagonal-affine expression"))
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
        ref.version == "v1" || throw(ArgumentError("GRAD operator version must be v1"))
        i = input_type isa PhysicalType ? input_type : throw(ArgumentError("GRAD input type must be PhysicalType"))
        o = output_type isa PhysicalType ? output_type : throw(ArgumentError("GRAD output type must be PhysicalType"))
        i.tensor_rank == 0 && i.spatial_dimension == 3 || throw(ArgumentError("GRAD input must be 3-D scalar"))
        o.tensor_rank == 1 && o.spatial_dimension == 3 || throw(ArgumentError("GRAD output must be 3-D vector"))
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
        ref.version == "v1" || throw(ArgumentError("K_APPLY operator version must be v1"))
        i = input_type isa PhysicalType ? input_type : throw(ArgumentError("K_APPLY input type must be PhysicalType"))
        o = output_type isa PhysicalType ? output_type : throw(ArgumentError("K_APPLY output type must be PhysicalType"))
        i.tensor_rank == 1 && i.spatial_dimension == 3 || throw(ArgumentError("K_APPLY input must be 3-D vector"))
        o.tensor_rank == 1 && o.spatial_dimension == 3 || throw(ArgumentError("K_APPLY output must be 3-D vector"))
        cu = _g1d_unit(coefficient_units, "K_APPLY coefficient_units")
        o.units == _g1d_add(i.units, cu) || throw(ArgumentError("K_APPLY output units must include coefficient units"))
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
        ref.version == "v1" || throw(ArgumentError("DIV operator version must be v1"))
        i = input_type isa PhysicalType ? input_type : throw(ArgumentError("DIV input type must be PhysicalType"))
        o = output_type isa PhysicalType ? output_type : throw(ArgumentError("DIV output type must be PhysicalType"))
        i.tensor_rank == 1 && i.spatial_dimension == 3 || throw(ArgumentError("DIV input must be 3-D vector"))
        o.tensor_rank == 0 && o.spatial_dimension == 3 || throw(ArgumentError("DIV output must be 3-D scalar"))
        o.units == _g1d_sub(i.units, _g1d_length_unit()) || throw(ArgumentError("DIV unit closure failed"))
        new(ref, _g1d_text(input_field_id, "DIV input_field_id"), _g1d_text(output_field_id, "DIV output_field_id"), i, o)
    end
end

struct G1DiffusionSourcePayloadV1
    source_ref::QualifiedRefV1
    source_version::String
    u::G1DiffusionScalarFieldV1
    K::G1DiffusionCoefficientFieldV1
    f::G1DiffusionScalarFieldV1
    function G1DiffusionSourcePayloadV1(source_ref::Any, source_version::Any,
                                        u::G1DiffusionScalarFieldV1,
                                        K::G1DiffusionCoefficientFieldV1,
                                        f::G1DiffusionScalarFieldV1)
        src = _g1d_ref(source_ref, "source payload source_ref")
        u.source_ref == src && K.source_ref == src && f.source_ref == src ||
            throw(ArgumentError("source payload field identities must match source_ref"))
        new(src, _g1d_text(source_version, "source payload source_version"), u, K, f)
    end
end

semantic_view(x::G1DiffusionSourcePayloadV1) =
    (schema_id="GenomeV5/G1/DiffusionSourcePayloadV1", version="v1",
     source_ref=x.source_ref, source_version=x.source_version, u=x.u, K=x.K, f=x.f)
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
function _g1d_declaration_body(x::G1DiffusionDeclarationV1)
    (schema_id=G1_DIFFUSION_SCHEMA_ID_V1, schema_version=G1_DIFFUSION_SCHEMA_VERSION_V1,
     candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_version=x.source_version,
     source_payload=x.source_payload, source_hash=x.source_hash, u=x.u, K=x.K, f=x.f, operators=x.operators,
     closure_ref=x.closure_ref, applicability_ref=x.applicability_ref,
     applicability_domain=x.applicability_domain, ownership=x.ownership,
     negative_controls=x.negative_controls)
end
semantic_view(x::G1DiffusionDeclarationV1) =
    merge(_g1d_declaration_body(x), (declaration_hash=x.declaration_hash,))
canonical_json(x::Union{G1DiffusionScalarFieldV1,G1DiffusionCoefficientFieldV1,G1TypedGradV1,
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
    expression isa G1DiffusionDiagonalAffineKFieldV1 ||
        return _g1d_admission_fail(:K_expression_type, "/K/expression")
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
    G1DiffusionReceiptV1(x.declaration_hash, g1_diffusion_schema_hash_v1(),
        g1_diffusion_canonicalization_hash_v1(), g1_diffusion_profile_hash_v1(),
        :proposal, false, :terminal_deferred, G1_DIFFUSION_CLAIM_CEILING_V1,
        G1_DIFFUSION_REQUIRED_GAPS_V1, 0, 0, 0, 0, false)
end

function g1_diffusion_validate(x::G1DiffusionDeclarationV1)
    errors = String[]
    x.candidate_ref.version == "v5" || push!(errors, "candidate_ref_version_not_v5")
    x.K.lower_bound > 0 && x.K.upper_bound >= x.K.lower_bound || push!(errors, "K_bounds_not_positive_ordered")
    x.K.spatial_dependency === :spatial || push!(errors, "K_not_spatially_dependent")
    x.K.positive_definite || push!(errors, "K_not_positive_definite")
    x.ownership === :candidate_owned || push!(errors, "field_ownership_not_candidate_owned")
    x.operators.grad.input_field_id == x.u.field_id || push!(errors, "GRAD_u_binding_mismatch")
    x.operators.div.output_field_id == x.f.field_id || push!(errors, "DIV_f_binding_mismatch")
    x.operators.residual_sign == -1 || push!(errors, "diffusion_residual_sign_not_negative")
    x.declaration_hash == canonical_hash(_g1d_declaration_body(x)) || push!(errors, "declaration_hash_mismatch")
    isempty(x.source_version) && push!(errors, "source_version_missing")
    unique!(errors)
    isempty(errors) ? :valid : :fail_closed, Tuple(errors)
end

function g1_diffusion_edit_source(x::G1DiffusionDeclarationV1, field::Symbol, value)
    field === :u && value isa G1DiffusionScalarFieldV1 &&
        return begin
            payload = G1DiffusionSourcePayloadV1(x.source_ref, x.source_version, value, x.K, x.f)
            g1_diffusion_declaration_v1(x.candidate_ref, x.source_ref, x.source_version,
                g1_diffusion_source_hash_v1(payload), value, x.K, x.f, x.operators,
                x.closure_ref, x.applicability_ref, x.applicability_domain, x.negative_controls;
                ownership=x.ownership, source_payload=payload)
        end
    field === :K && value isa G1DiffusionCoefficientFieldV1 &&
        return begin
            payload = G1DiffusionSourcePayloadV1(x.source_ref, x.source_version, x.u, value, x.f)
            g1_diffusion_declaration_v1(x.candidate_ref, x.source_ref, x.source_version,
                g1_diffusion_source_hash_v1(payload), x.u, value, x.f, x.operators,
                x.closure_ref, x.applicability_ref, x.applicability_domain, x.negative_controls;
                ownership=x.ownership, source_payload=payload)
        end
    field === :f && value isa G1DiffusionScalarFieldV1 &&
        return begin
            payload = G1DiffusionSourcePayloadV1(x.source_ref, x.source_version, x.u, x.K, value)
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
