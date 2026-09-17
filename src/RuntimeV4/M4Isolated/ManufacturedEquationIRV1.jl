"""Isolated M4-A manufactured equation declaration.

This file is intentionally standalone.  It declares one manufactured,
steady scalar diffusion equation and provides a structural validator for the
declaration.  It does not evaluate a residual, assemble a matrix, bind a
candidate, invoke a provider, or emit physical evidence.  The types use only
immutable scalar/tuple fields so that a later lane can serialize the
declaration deterministically without importing the shared RuntimeV4 module.
"""

const M4_MANUFACTURED_EQUATION_ID_V1 = "M4-MANUFACTURED-DIFFUSION-V1"
const M4_MANUFACTURED_OPERATOR_ID_V1 = "NEG_DIV_K_GRAD_MINUS_SOURCE"
const M4_MANUFACTURED_OPERATOR_VERSION_V1 = "v1"
const M4_MANUFACTURED_FIELD_ID_V1 = "u"
const M4_MANUFACTURED_COEFFICIENT_ID_V1 = "K"
const M4_MANUFACTURED_SOURCE_ID_V1 = "f"
const M4_MANUFACTURED_CONSERVATION_OWNER_V1 = "M4-A-equation-balance"

"""A named SI unit with seven base-dimension exponents.

The exponent order is `(length, mass, time, temperature, amount, current,
luminous_intensity)`.  The scale is retained explicitly even though the
frozen declaration uses SI units only.
"""
struct M4UnitV1
    name::String
    exponents::NTuple{7,Int}
    scale_to_si::Float64
end

function M4UnitV1(name::AbstractString, exponents, scale::Real=1.0)
    raw = Tuple(exponents)
    length(raw) == 7 || throw(ArgumentError("M4UnitV1 requires seven dimension exponents"))
    M4UnitV1(String(name), ntuple(i -> Int(raw[i]), 7), Float64(scale))
end

const M4_DIMENSIONLESS_V1 = M4UnitV1("1", (0, 0, 0, 0, 0, 0, 0), 1.0)
const M4_LENGTH_V1 = M4UnitV1("m", (1, 0, 0, 0, 0, 0, 0), 1.0)
const M4_AREA_V1 = M4UnitV1("m^2", (2, 0, 0, 0, 0, 0, 0), 1.0)

struct M4RationalV1
    numerator::Int
    denominator::Int
end

M4RationalV1(n::Integer, d::Integer) = M4RationalV1(Int(n), Int(d))

struct M4DomainDeclarationV1
    id::String
    dimension::Int
    coordinate_names::NTuple{3,String}
    lower::NTuple{3,Float64}
    upper::NTuple{3,Float64}
    coordinate_unit::M4UnitV1
    length_scale_m::Float64
end

struct M4ScalarFieldDeclarationV1
    id::String
    value_kind::Symbol
    units::M4UnitV1
    domain_id::String
    expression::String
    conservation_owner::String
end

struct M4OperatorDeclarationV1
    id::String
    version::String
    name::String
    expression::String
    input_field_id::String
    coefficient_id::String
    source_id::String
    input_unit::M4UnitV1
    output_unit::M4UnitV1
    residual_sign::Int
    conservation_owner::String
end

struct M4DiagonalCoefficientDeclarationV1
    id::String
    tensor_rank::Int
    dimension::Int
    units::M4UnitV1
    diagonal_terms::NTuple{3,String}
    positive_lower_bounds::NTuple{3,Float64}
    spd_certificate::Symbol
    domain_id::String
    conservation_owner::String
end

struct M4SourceDeclarationV1
    id::String
    equation_id::String
    units::M4UnitV1
    value::M4RationalV1
    expression::String
    owner::String
    conservation_owner::String
end

struct M4BoundaryClosureDeclarationV1
    id::String
    equation_id::String
    domain_id::String
    owner::String
    closure_kind::Symbol
    face_ids::NTuple{6,String}
    condition_expression::String
    complete::Bool
    conservation_owner::String
end

struct M4ProvenanceDeclarationV1
    input_kind::Symbol
    source_scope::Symbol
    authority_kind::Symbol
    candidate_bound::Bool
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

"""The complete, declaration-only manufactured equation IR."""
struct ManufacturedEquationIRV1
    equation_id::String
    equation_kind::Symbol
    domain::M4DomainDeclarationV1
    scalar_field::M4ScalarFieldDeclarationV1
    operator::M4OperatorDeclarationV1
    coefficient::M4DiagonalCoefficientDeclarationV1
    source::M4SourceDeclarationV1
    boundary_closure::M4BoundaryClosureDeclarationV1
    conservation_owners::Tuple{Vararg{String}}
    provenance::M4ProvenanceDeclarationV1
    time_scope::Symbol
    multifield_scope::Symbol
end

"""A stable typed structural validation failure."""
struct ManufacturedEquationIRFailureV1
    code::Symbol
    path::String
    detail::String
end

"""Result of validating an M4-A declaration; no exception is used for IR gaps."""
struct ManufacturedEquationIRValidationV1
    valid::Bool
    status::Symbol
    failures::Tuple{Vararg{ManufacturedEquationIRFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

_m4_failure(code::Symbol, path::AbstractString, detail::AbstractString) =
    ManufacturedEquationIRFailureV1(code, String(path), String(detail))

"""Build the frozen M4-A manufactured declaration.

Keyword overrides are provided solely for deterministic negative controls and
structural review.  The default value is the frozen declaration:
`R(u) = -div(K grad(u)) - f = 0` on `[0,1 m]^3`.
"""
function manufactured_equation_ir_v1(; equation_id::AbstractString=M4_MANUFACTURED_EQUATION_ID_V1,
        operator_name::AbstractString=M4_MANUFACTURED_OPERATOR_ID_V1,
        operator_version::AbstractString=M4_MANUFACTURED_OPERATOR_VERSION_V1,
        scalar_unit::M4UnitV1=M4_DIMENSIONLESS_V1,
        coefficient_unit::M4UnitV1=M4_AREA_V1,
        source_unit::M4UnitV1=M4_DIMENSIONLESS_V1,
        coefficient_terms::NTuple{3,String}=("2 + 0.1*x/L", "3 + 0.05*y/L", "4 + z/(30*L)"),
        coefficient_lower_bounds::NTuple{3,Real}=(2.0, 3.0, 4.0),
        spd_certificate::Symbol=:diagonal_positive,
        source_equation_id::AbstractString=equation_id,
        source_value::M4RationalV1=M4RationalV1(-11, 60),
        source_owner::AbstractString="M4-A-manufactured-source",
        boundary_equation_id::AbstractString=equation_id,
        boundary_domain_id::AbstractString="Omega",
        boundary_owner::AbstractString="M4-A-boundary-closure",
        boundary_complete::Bool=true,
        conservation_owners::Tuple{Vararg{String}}=(M4_MANUFACTURED_CONSERVATION_OWNER_V1,),
        input_kind::Symbol=:explicit_manufactured_or_analytic,
        source_scope::Symbol=:manufactured_only,
        authority_kind::Symbol=:no_external_authority,
        candidate_bound::Bool=false,
        claim_ceiling::Symbol=:manufactured_control,
        evidence_scope::Symbol=:screen_only,
        time_scope::Symbol=:terminal_deferred,
        multifield_scope::Symbol=:terminal_deferred)
    eid = String(equation_id)
    domain = M4DomainDeclarationV1(
        "Omega", 3, ("x", "y", "z"),
        (0.0, 0.0, 0.0), (1.0, 1.0, 1.0), M4_LENGTH_V1, 1.0)
    field = M4ScalarFieldDeclarationV1(
        M4_MANUFACTURED_FIELD_ID_V1, :scalar, scalar_unit, domain.id,
        "x/L + y/L + z/L", M4_MANUFACTURED_CONSERVATION_OWNER_V1)
    operator = M4OperatorDeclarationV1(
        M4_MANUFACTURED_OPERATOR_ID_V1, String(operator_version), String(operator_name),
        "-div(K*grad(u)) - f = 0", field.id, M4_MANUFACTURED_COEFFICIENT_ID_V1,
        M4_MANUFACTURED_SOURCE_ID_V1, field.units, source_unit, -1,
        M4_MANUFACTURED_CONSERVATION_OWNER_V1)
    coefficient = M4DiagonalCoefficientDeclarationV1(
        M4_MANUFACTURED_COEFFICIENT_ID_V1, 2, 3, coefficient_unit,
        coefficient_terms, ntuple(i -> Float64(coefficient_lower_bounds[i]), 3),
        spd_certificate, domain.id, M4_MANUFACTURED_CONSERVATION_OWNER_V1)
    source = M4SourceDeclarationV1(
        M4_MANUFACTURED_SOURCE_ID_V1, String(source_equation_id), source_unit,
        source_value, "-11/60", String(source_owner), M4_MANUFACTURED_CONSERVATION_OWNER_V1)
    boundary = M4BoundaryClosureDeclarationV1(
        "boundary-closure", String(boundary_equation_id), String(boundary_domain_id),
        String(boundary_owner), :manufactured_flux,
        ("x_min", "x_max", "y_min", "y_max", "z_min", "z_max"),
        "K*grad(u)·n on every domain face", boundary_complete,
        M4_MANUFACTURED_CONSERVATION_OWNER_V1)
    ManufacturedEquationIRV1(
        eid, :steady_scalar_diffusion, domain, field, operator, coefficient, source,
        boundary, conservation_owners,
        M4ProvenanceDeclarationV1(input_kind, source_scope, authority_kind,
            candidate_bound, claim_ceiling, evidence_scope),
        time_scope, multifield_scope)
end

"""Return an immutable named-tuple payload suitable for deterministic serialization."""
function manufactured_equation_payload(ir::ManufacturedEquationIRV1)
    (equation_id=ir.equation_id, equation_kind=ir.equation_kind,
     domain=ir.domain, scalar_field=ir.scalar_field, operator=ir.operator,
     coefficient=ir.coefficient, source=ir.source,
     boundary_closure=ir.boundary_closure,
     conservation_owners=ir.conservation_owners, provenance=ir.provenance,
     time_scope=ir.time_scope, multifield_scope=ir.multifield_scope)
end

function _m4_check_unit!(failures, actual::M4UnitV1, expected::M4UnitV1, path)
    actual == expected || push!(failures, _m4_failure(
        :unit_closure_failure, path,
        string("expected ", expected.name, " with exponents ", expected.exponents,
            ", got ", actual.name, " with exponents ", actual.exponents)))
end

"""Validate the declaration and return stable typed failures instead of throwing."""
function validate_manufactured_equation_ir(ir::ManufacturedEquationIRV1)
    failures = ManufacturedEquationIRFailureV1[]
    ir.equation_id == M4_MANUFACTURED_EQUATION_ID_V1 || push!(failures,
        _m4_failure(:foreign_equation, "equation_id", "declaration is not the frozen M4-A equation"))
    ir.equation_kind == :steady_scalar_diffusion || push!(failures,
        _m4_failure(:unsupported_equation_kind, "equation_kind", "only steady scalar diffusion is admitted"))

    d = ir.domain
    d.id == "Omega" && d.dimension == 3 && d.coordinate_names == ("x", "y", "z") ||
        push!(failures, _m4_failure(:domain_mismatch, "domain", "domain must be Omega with x,y,z and dimension 3"))
    d.lower == (0.0, 0.0, 0.0) && d.upper == (1.0, 1.0, 1.0) &&
        d.length_scale_m == 1.0 || push!(failures,
        _m4_failure(:domain_mismatch, "domain.bounds", "Omega must be [0,1 m]^3 with L=1 m"))
    _m4_check_unit!(failures, d.coordinate_unit, M4_LENGTH_V1, "domain.coordinate_unit")

    f = ir.scalar_field
    f.id == M4_MANUFACTURED_FIELD_ID_V1 && f.value_kind == :scalar && f.domain_id == d.id ||
        push!(failures, _m4_failure(:field_declaration_failure, "scalar_field", "u must be one scalar field on Omega"))
    f.expression == "x/L + y/L + z/L" || push!(failures,
        _m4_failure(:field_declaration_failure, "scalar_field.expression", "frozen affine manufactured field differs"))
    _m4_check_unit!(failures, f.units, M4_DIMENSIONLESS_V1, "scalar_field.units")

    op = ir.operator
    op.id == M4_MANUFACTURED_OPERATOR_ID_V1 &&
        op.name == M4_MANUFACTURED_OPERATOR_ID_V1 &&
        op.version == M4_MANUFACTURED_OPERATOR_VERSION_V1 || push!(failures,
        _m4_failure(:unknown_operator, "operator", "operator must be NEG_DIV_K_GRAD_MINUS_SOURCE@v1"))
    op.input_field_id == f.id && op.coefficient_id == ir.coefficient.id &&
        op.source_id == ir.source.id && op.residual_sign == -1 || push!(failures,
        _m4_failure(:operator_declaration_failure, "operator.bindings", "operator inputs or residual sign are not closed"))
    op.expression == "-div(K*grad(u)) - f = 0" || push!(failures,
        _m4_failure(:operator_declaration_failure, "operator.expression", "residual sign/expression differs"))
    _m4_check_unit!(failures, op.input_unit, f.units, "operator.input_unit")
    _m4_check_unit!(failures, op.output_unit, M4_DIMENSIONLESS_V1, "operator.output_unit")

    k = ir.coefficient
    k.id == M4_MANUFACTURED_COEFFICIENT_ID_V1 && k.tensor_rank == 2 &&
        k.dimension == 3 && k.domain_id == d.id || push!(failures,
        _m4_failure(:coefficient_declaration_failure, "coefficient", "K must be a 3x3 diagonal field on Omega"))
    k.diagonal_terms == ("2 + 0.1*x/L", "3 + 0.05*y/L", "4 + z/(30*L)") ||
        push!(failures, _m4_failure(:coefficient_declaration_failure, "coefficient.diagonal_terms", "frozen K diagonal differs"))
    _m4_check_unit!(failures, k.units, M4_AREA_V1, "coefficient.units")
    all(isfinite, k.positive_lower_bounds) && all(>(0.0), k.positive_lower_bounds) ||
        push!(failures, _m4_failure(:nonpositive_coefficient, "coefficient.positive_lower_bounds", "all diagonal lower bounds must be positive and finite"))
    k.spd_certificate == :diagonal_positive || push!(failures,
        _m4_failure(:non_spd_coefficient, "coefficient.spd_certificate", "K requires a positive diagonal SPD certificate"))

    s = ir.source
    s.id == M4_MANUFACTURED_SOURCE_ID_V1 && s.equation_id == ir.equation_id ||
        push!(failures, _m4_failure(:foreign_source_reference, "source", "f must belong to the frozen equation"))
    s.value.numerator == -11 && s.value.denominator == 60 && s.expression == "-11/60" ||
        push!(failures, _m4_failure(:source_declaration_failure, "source.value", "f must be exactly -11/60"))
    s.value.denominator > 0 || push!(failures,
        _m4_failure(:source_declaration_failure, "source.value.denominator", "source denominator must be positive"))
    _m4_check_unit!(failures, s.units, M4_DIMENSIONLESS_V1, "source.units")
    isempty(s.owner) && push!(failures,
        _m4_failure(:foreign_source_reference, "source.owner", "source owner must be explicit and nonempty"))

    b = ir.boundary_closure
    b.equation_id == ir.equation_id && b.domain_id == d.id && !isempty(b.owner) &&
        b.closure_kind == :manufactured_flux && b.complete &&
        b.face_ids == ("x_min", "x_max", "y_min", "y_max", "z_min", "z_max") ||
        push!(failures, _m4_failure(:missing_boundary_closure, "boundary_closure", "all six Omega faces require one complete manufactured closure"))

    owners = Tuple(ir.conservation_owners)
    length(owners) == 1 && !isempty(only(owners)) || push!(failures,
        _m4_failure(:non_unique_source_owner, "conservation_owners", "exactly one conservation owner is required"))
    length(unique(owners)) == length(owners) || push!(failures,
        _m4_failure(:non_unique_source_owner, "conservation_owners", "conservation owners must be unique"))
    if length(owners) == 1
        owner = only(owners)
        for (path, value) in (("scalar_field.conservation_owner", f.conservation_owner),
                              ("operator.conservation_owner", op.conservation_owner),
                              ("coefficient.conservation_owner", k.conservation_owner),
                              ("source.conservation_owner", s.conservation_owner),
                              ("boundary_closure.conservation_owner", b.conservation_owner))
            value == owner || push!(failures,
                _m4_failure(:non_unique_source_owner, path, "declaration is owned by a different conservation owner"))
        end
    end

    p = ir.provenance
    p.input_kind == :explicit_manufactured_or_analytic &&
        p.source_scope == :manufactured_only &&
        p.authority_kind == :no_external_authority && !p.candidate_bound &&
        p.claim_ceiling == :manufactured_control && p.evidence_scope == :screen_only ||
        push!(failures, _m4_failure(:provenance_ceiling_failure, "provenance", "M4-A must remain manufactured_control/screen_only"))
    ir.time_scope == :terminal_deferred || push!(failures,
        _m4_failure(:terminal_deferred, "time_scope", "time-dependent extensions are terminal_deferred"))
    ir.multifield_scope == :terminal_deferred || push!(failures,
        _m4_failure(:terminal_deferred, "multifield_scope", "multifield extensions are terminal_deferred"))

    typed_failures = Tuple(failures)
    ManufacturedEquationIRValidationV1(isempty(typed_failures),
        isempty(typed_failures) ? :valid : :typed_failure, typed_failures,
        p.claim_ceiling, p.evidence_scope)
end

"""Convenience predicate for callers that only need the declaration status."""
is_valid_manufactured_equation_ir(ir::ManufacturedEquationIRV1) =
    validate_manufactured_equation_ir(ir).valid
