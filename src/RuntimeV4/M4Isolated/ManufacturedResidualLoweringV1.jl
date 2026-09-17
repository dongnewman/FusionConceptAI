"""Isolated M4-B analytic residual lowering.

This file is deliberately independent of the shared RuntimeV4 entry point.  It
lowers only the frozen manufactured equation declaration from M4-A to an
analytic residual declaration.  It does not create a mesh, discretize or
assemble anything, invoke a solver/provider, transfer a topology, bind a
candidate, or emit physics/engineering evidence.
"""

# Permit this file to be included either after M4-A in a test module or by
# itself.  The guard avoids redefining A's immutable declaration types.
if !isdefined(@__MODULE__, :ManufacturedEquationIRV1)
    include(joinpath(@__DIR__, "ManufacturedEquationIRV1.jl"))
end

const M4B_RESIDUAL_SCHEMA_V1 = "M4-B-MANUFACTURED-RESIDUAL-V1"
const M4B_CLAIM_CEILING_V1 = :manufactured_residual_lowering
const M4B_EVIDENCE_SCOPE_V1 = :screen_only
const M4B_EXPECTED_DIVERGENCE_TERMS_V1 =
    (M4RationalV1(1, 10), M4RationalV1(1, 20), M4RationalV1(1, 30))
const M4B_EXPECTED_DIVERGENCE_V1 = M4RationalV1(11, 60)
const M4B_EXPECTED_SOURCE_V1 = M4RationalV1(-11, 60)
const M4B_EXPECTED_RESIDUAL_V1 = M4RationalV1(0, 1)

"""A stable typed failure emitted by M4-B validation/lowering."""
struct ManufacturedResidualLoweringFailureV1
    code::Symbol
    path::String
    detail::String
end

_m4b_failure(code::Symbol, path::AbstractString, detail::AbstractString) =
    ManufacturedResidualLoweringFailureV1(code, String(path), String(detail))

"""The declaration-only result of analytic lowering."""
struct ManufacturedResidualDeclarationV1
    equation_id::String
    equation_kind::Symbol
    domain::M4DomainDeclarationV1
    field_id::String
    field_unit::M4UnitV1
    operator_id::String
    operator_version::String
    operator_expression::String
    operator_input_unit::M4UnitV1
    operator_output_unit::M4UnitV1
    source_id::String
    source_equation_id::String
    source_unit::M4UnitV1
    coefficient_unit::M4UnitV1
    source_owner::String
    conservation_owner::String
    provenance::M4ProvenanceDeclarationV1
    # Vararg tuple permits a typed term-count failure for negative controls;
    # the lowering constructor itself always emits exactly three terms.
    divergence_contributions::Tuple{Vararg{M4RationalV1}}
    divergence_total::M4RationalV1
    source_value::M4RationalV1
    residual_value::M4RationalV1
    claim_ceiling::Symbol
    evidence_scope::Symbol
    time_scope::Symbol
    multifield_scope::Symbol
end

"""Typed result; invalid A input never produces a declaration."""
struct ManufacturedResidualLoweringResultV1
    valid::Bool
    status::Symbol
    declaration::Union{Nothing,ManufacturedResidualDeclarationV1}
    failures::Tuple{Vararg{ManufacturedResidualLoweringFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

const ManufacturedResidualValidationV1 = ManufacturedResidualLoweringResultV1

_m4b_rat_equal(a::M4RationalV1, b::M4RationalV1) =
    a.denominator != 0 && b.denominator != 0 &&
    a.numerator * b.denominator == b.numerator * a.denominator

_m4b_rat_payload(r::M4RationalV1) = (numerator=r.numerator, denominator=r.denominator)

"""Build a deterministic, scalar/tuple-only payload for hashing/serialization."""
function manufactured_residual_payload(d::ManufacturedResidualDeclarationV1)
    (schema=M4B_RESIDUAL_SCHEMA_V1,
     equation=(id=d.equation_id, kind=d.equation_kind),
     domain=(id=d.domain.id, dimension=d.domain.dimension,
             coordinate_names=d.domain.coordinate_names,
             lower=d.domain.lower, upper=d.domain.upper,
             coordinate_unit=d.domain.coordinate_unit,
             length_scale_m=d.domain.length_scale_m),
     field=(id=d.field_id, unit=d.field_unit),
     operator=(id=d.operator_id, version=d.operator_version,
               expression=d.operator_expression,
               input_unit=d.operator_input_unit, output_unit=d.operator_output_unit),
     source=(id=d.source_id, equation_id=d.source_equation_id,
             unit=d.source_unit, owner=d.source_owner),
     coefficient=(unit=d.coefficient_unit),
     conservation_owner=d.conservation_owner,
     provenance=d.provenance,
     divergence_contributions=Tuple(_m4b_rat_payload(r) for r in d.divergence_contributions),
     divergence_total=_m4b_rat_payload(d.divergence_total),
     source_value=_m4b_rat_payload(d.source_value),
     residual_value=_m4b_rat_payload(d.residual_value),
     claim_ceiling=d.claim_ceiling, evidence_scope=d.evidence_scope,
     time_scope=d.time_scope, multifield_scope=d.multifield_scope)
end

"""Validate the declaration's frozen analytic shape without executing physics."""
function validate_manufactured_residual(d::ManufacturedResidualDeclarationV1)
    failures = ManufacturedResidualLoweringFailureV1[]
    d.equation_id == M4_MANUFACTURED_EQUATION_ID_V1 || push!(failures,
        _m4b_failure(:foreign_equation, "equation_id", "residual declaration is not the frozen M4-A equation"))
    d.equation_kind == :steady_scalar_diffusion || push!(failures,
        _m4b_failure(:foreign_equation, "equation_kind", "only the frozen steady scalar equation is admitted"))
    d.domain == manufactured_equation_ir_v1().domain || push!(failures,
        _m4b_failure(:domain_mismatch, "domain", "domain is not the frozen Omega declaration"))
    d.field_id == M4_MANUFACTURED_FIELD_ID_V1 || push!(failures,
        _m4b_failure(:field_mismatch, "field_id", "field is not the frozen scalar field u"))
    d.field_unit == M4_DIMENSIONLESS_V1 || push!(failures,
        _m4b_failure(:unit_closure_failure, "field_unit", "field unit must be dimensionless"))
    d.operator_id == M4_MANUFACTURED_OPERATOR_ID_V1 &&
        d.operator_version == M4_MANUFACTURED_OPERATOR_VERSION_V1 || push!(failures,
        _m4b_failure(:operator_mismatch, "operator", "operator must be NEG_DIV_K_GRAD_MINUS_SOURCE@v1"))
    d.operator_expression == "-div(K*grad(u)) - f = 0" || push!(failures,
        _m4b_failure(:sign_mismatch, "operator.expression", "residual sign/expression is not frozen"))
    d.operator_input_unit == M4_DIMENSIONLESS_V1 &&
        d.operator_output_unit == M4_DIMENSIONLESS_V1 || push!(failures,
        _m4b_failure(:unit_closure_failure, "operator.units", "operator input/output units must be dimensionless"))
    d.source_id == M4_MANUFACTURED_SOURCE_ID_V1 || push!(failures,
        _m4b_failure(:source_mismatch, "source_id", "source is not the frozen source f"))
    d.source_equation_id == d.equation_id || push!(failures,
        _m4b_failure(:foreign_source_reference, "source_equation_id", "source must belong to the declared equation"))
    d.source_unit == M4_DIMENSIONLESS_V1 || push!(failures,
        _m4b_failure(:unit_closure_failure, "source_unit", "source unit must be dimensionless"))
    d.coefficient_unit == M4_AREA_V1 || push!(failures,
        _m4b_failure(:unit_closure_failure, "coefficient_unit", "coefficient unit must be m^2"))
    isempty(d.source_owner) && push!(failures,
        _m4b_failure(:owner_mismatch, "source_owner", "source owner must be explicit and nonempty"))
    isempty(d.conservation_owner) && push!(failures,
        _m4b_failure(:owner_mismatch, "conservation_owner", "conservation owner must be explicit and nonempty"))
    length(d.divergence_contributions) == 3 || push!(failures,
        _m4b_failure(:term_count_mismatch, "divergence_contributions", "exactly three analytic divergence terms are required"))
    length(d.divergence_contributions) == 3 &&
        d.divergence_contributions == M4B_EXPECTED_DIVERGENCE_TERMS_V1 || push!(failures,
        _m4b_failure(:term_mismatch, "divergence_contributions", "terms must be 1/10, 1/20, and 1/30 in order"))
    _m4b_rat_equal(d.divergence_total, M4B_EXPECTED_DIVERGENCE_V1) || push!(failures,
        _m4b_failure(:divergence_mismatch, "divergence_total", "divergence total must be 11/60"))
    _m4b_rat_equal(d.source_value, M4B_EXPECTED_SOURCE_V1) || push!(failures,
        _m4b_failure(:source_mismatch, "source_value", "source must be -11/60"))
    _m4b_rat_equal(d.residual_value, M4B_EXPECTED_RESIDUAL_V1) || push!(failures,
        _m4b_failure(:nonzero_residual, "residual_value", "analytic residual must be exactly zero"))
    d.claim_ceiling == M4B_CLAIM_CEILING_V1 && d.evidence_scope == M4B_EVIDENCE_SCOPE_V1 ||
        push!(failures, _m4b_failure(:provenance_mismatch, "claim_ceiling", "B ceiling is manufactured_residual_lowering/screen_only"))
    d.provenance == manufactured_equation_ir_v1().provenance || push!(failures,
        _m4b_failure(:provenance_mismatch, "provenance", "provenance is not bound to the frozen A declaration"))
    d.time_scope == :terminal_deferred || push!(failures,
        _m4b_failure(:terminal_deferred, "time_scope", "time-dependent lowering is terminal_deferred"))
    d.multifield_scope == :terminal_deferred || push!(failures,
        _m4b_failure(:terminal_deferred, "multifield_scope", "multifield lowering is terminal_deferred"))
    typed = Tuple(failures)
    ManufacturedResidualLoweringResultV1(isempty(typed),
        isempty(typed) ? :valid : :typed_failure, d, typed,
        d.claim_ceiling, d.evidence_scope)
end

"""Validate all bindings against the exact A input consumed by lowering."""
function validate_manufactured_residual(d::ManufacturedResidualDeclarationV1,
        ir::ManufacturedEquationIRV1)
    result = validate_manufactured_residual(d)
    failures = ManufacturedResidualLoweringFailureV1[f for f in result.failures]
    ir.equation_id == d.equation_id || push!(failures,
        _m4b_failure(:foreign_equation, "equation_id", "declaration equation differs from lowering input"))
    ir.domain == d.domain || push!(failures,
        _m4b_failure(:domain_mismatch, "domain", "declaration domain differs from lowering input"))
    ir.scalar_field.id == d.field_id && ir.scalar_field.units == d.field_unit || push!(failures,
        _m4b_failure(:field_mismatch, "field", "declaration field differs from lowering input"))
    ir.operator.id == d.operator_id && ir.operator.version == d.operator_version || push!(failures,
        _m4b_failure(:operator_mismatch, "operator", "declaration operator differs from lowering input"))
    ir.operator.input_unit == d.operator_input_unit && ir.operator.output_unit == d.operator_output_unit ||
        push!(failures, _m4b_failure(:unit_closure_failure, "operator.units", "operator units differ from lowering input"))
    ir.source.id == d.source_id && ir.source.equation_id == d.source_equation_id &&
        ir.source.units == d.source_unit || push!(failures,
        _m4b_failure(:source_mismatch, "source", "declaration source differs from lowering input"))
    ir.coefficient.units == d.coefficient_unit || push!(failures,
        _m4b_failure(:unit_closure_failure, "coefficient_unit", "coefficient unit differs from lowering input"))
    ir.source.owner == d.source_owner || push!(failures,
        _m4b_failure(:owner_mismatch, "source_owner", "source owner is not bound to the input source"))
    length(ir.conservation_owners) == 1 && only(ir.conservation_owners) == d.conservation_owner ||
        push!(failures, _m4b_failure(:owner_mismatch, "conservation_owner", "conservation owner is not bound to the input"))
    ir.provenance == d.provenance || push!(failures,
        _m4b_failure(:provenance_mismatch, "provenance", "provenance is not bound to the lowering input"))
    typed = Tuple(failures)
    ManufacturedResidualLoweringResultV1(isempty(typed),
        isempty(typed) ? :valid : :typed_failure, d, typed,
        d.claim_ceiling, d.evidence_scope)
end

"""Lower the frozen A declaration to a typed analytic residual declaration."""
function lower_manufactured_residual(ir::ManufacturedEquationIRV1)
    a = validate_manufactured_equation_ir(ir)
    if !a.valid
        failures = Tuple(ManufacturedResidualLoweringFailureV1(f.code, f.path, f.detail)
                         for f in a.failures)
        return ManufacturedResidualLoweringResultV1(false, :typed_failure, nothing,
            failures, a.claim_ceiling, a.evidence_scope)
    end
    owner = only(ir.conservation_owners)
    d = ManufacturedResidualDeclarationV1(
        ir.equation_id, ir.equation_kind, ir.domain,
        ir.scalar_field.id, ir.scalar_field.units,
        ir.operator.id, ir.operator.version, ir.operator.expression,
        ir.operator.input_unit, ir.operator.output_unit,
        ir.source.id, ir.source.equation_id, ir.source.units, ir.coefficient.units,
        ir.source.owner, owner,
        ir.provenance, M4B_EXPECTED_DIVERGENCE_TERMS_V1,
        M4B_EXPECTED_DIVERGENCE_V1, M4B_EXPECTED_SOURCE_V1,
        M4B_EXPECTED_RESIDUAL_V1, M4B_CLAIM_CEILING_V1,
        M4B_EVIDENCE_SCOPE_V1, ir.time_scope, ir.multifield_scope)
    result = validate_manufactured_residual(d, ir)
    result.valid ? result : ManufacturedResidualLoweringResultV1(
        false, result.status, d, result.failures,
        result.claim_ceiling, result.evidence_scope)
end

const lower_manufactured_residual_v1 = lower_manufactured_residual
const manufactured_residual_lowering_v1 = lower_manufactured_residual
const validate_manufactured_residual_v1 = validate_manufactured_residual
const manufactured_residual_payload_v1 = manufactured_residual_payload

is_valid_manufactured_residual(d::ManufacturedResidualDeclarationV1) =
    validate_manufactured_residual(d).valid
is_valid_manufactured_residual(r::ManufacturedResidualLoweringResultV1) = r.valid
const is_valid_manufactured_residual_v1 = is_valid_manufactured_residual
