"""Additive UP2 pre-T0 typed compiler IR contract.

This file is deliberately standalone and declaration-only.  It defines a
sealed, candidate-bound structural IR and a fail-closed validator.  It does
not include the shared runtime, invoke a compiler/provider, lower a field,
discretize a mesh, solve an equation, or produce numerical/physical evidence.
Synthetic payloads are contract fixtures only and are always `contract_only`
and `not_measured`.
"""

const _TCIR_SCHEMA_V1 = "FusionConceptAI/RuntimeV4/TypedCompilerIRV1"
const _TCIR_REVISION_V1 = "typed-compiler-ir-v1"
const _TCIR_CONTRACT_ONLY_V1 = :contract_only
const _TCIR_NOT_MEASURED_V1 = :not_measured
const _TCIR_READY_V1 = :ready
const _TCIR_TERMINAL_DEFERRED_V1 = :terminal_deferred
const _TCIR_FAIL_CLOSED_V1 = :fail_closed
const _TCIR_TYPED_ABSENT_V1 = "typed_absent"
const _TCIR_SOURCE_AUTHORITY_SCHEMA_V1 = "FusionConceptAI/RuntimeV4/TypedCompilerSourceAuthorityV1"
const _TCIR_SOURCE_AUTHORITY_REVISION_V1 = "typed-compiler-source-authority-v1"
const _TCIR_SOURCE_AUTHORITY_CHECKED_PRESENT_V1 = :checked_present

struct _TypedCompilerSealV1 end
const _TCIR_SEAL_V1 = _TypedCompilerSealV1()

function _tc_text_v1(value, field::AbstractString; allow_typed_absent::Bool=false)
    value isa AbstractString || throw(ArgumentError("$field must be a string"))
    # `strip` may return a SubString; the sealed constructors require the
    # concrete String field type promised by the public factories.
    text = String(strip(String(value)))
    isempty(text) && throw(ArgumentError("$field cannot be empty"))
    lowercase(text) in ("*", "any", "wildcard", "all") &&
        throw(ArgumentError("$field cannot be wildcard"))
    !allow_typed_absent && lowercase(text) == _TCIR_TYPED_ABSENT_V1 &&
        throw(ArgumentError("$field cannot be typed_absent"))
    text
end

function _tc_tuple_text_v1(values, field::AbstractString; allow_empty::Bool=false)
    values isa Tuple || throw(ArgumentError("$field must be a tuple"))
    result = Tuple(_tc_text_v1(value, field) for value in values)
    (!allow_empty && isempty(result)) && throw(ArgumentError("$field cannot be empty"))
    length(unique(result)) == length(result) || throw(ArgumentError("$field contains duplicates"))
    result
end

struct TypedCompilerUnitV1
    name::String
    exponents::NTuple{7,Int}
    scale_to_si::Float64
    function TypedCompilerUnitV1(::_TypedCompilerSealV1, name::String,
                                 exponents::NTuple{7,Int}, scale_to_si::Float64)
        isempty(strip(name)) && throw(ArgumentError("unit name cannot be empty"))
        isfinite(scale_to_si) && scale_to_si > 0.0 ||
            throw(ArgumentError("unit scale must be finite and positive"))
        new(name, exponents, scale_to_si)
    end
end
TypedCompilerUnitV1(args...) = throw(ArgumentError("TypedCompilerUnitV1 is sealed; use typed_compiler_unit_v1"))

function _tc_new_unit_v1(name::String, exponents::NTuple{7,Int}, scale_to_si::Float64)
    invoke(TypedCompilerUnitV1,
        Tuple{_TypedCompilerSealV1,String,NTuple{7,Int},Float64},
        _TCIR_SEAL_V1, _tc_text_v1(name, "unit name"), exponents, scale_to_si)
end

function typed_compiler_unit_v1(name::AbstractString, exponents; scale::Real=1.0)
    raw = Tuple(exponents)
    length(raw) == 7 || throw(ArgumentError("unit requires seven base-dimension exponents"))
    all(x -> x isa Integer, raw) || throw(ArgumentError("unit exponents must be integers"))
    _tc_new_unit_v1(_tc_text_v1(name, "unit name"),
        ntuple(i -> Int(raw[i]), 7), Float64(scale))
end

struct TypedCompilerBindingV1
    candidate_ref::String
    owner_ref::String
    region_ref::String
    chart_ref::String
    operator_ref::String
    source_ref::String
    conservation_ref::String
    input_unit::TypedCompilerUnitV1
    output_unit::TypedCompilerUnitV1
    function TypedCompilerBindingV1(::_TypedCompilerSealV1,
                                    candidate_ref::String, owner_ref::String,
                                    region_ref::String, chart_ref::String,
                                    operator_ref::String, source_ref::String,
                                    conservation_ref::String,
                                    input_unit::TypedCompilerUnitV1,
                                    output_unit::TypedCompilerUnitV1)
        new(_tc_text_v1(candidate_ref, "candidate_ref"),
            _tc_text_v1(owner_ref, "owner_ref"),
            _tc_text_v1(region_ref, "region_ref"),
            _tc_text_v1(chart_ref, "chart_ref"),
            _tc_text_v1(operator_ref, "operator_ref"),
            _tc_text_v1(source_ref, "source_ref"; allow_typed_absent=true),
            _tc_text_v1(conservation_ref, "conservation_ref"),
            input_unit, output_unit)
    end
end
TypedCompilerBindingV1(args...) = throw(ArgumentError("TypedCompilerBindingV1 is sealed; use typed_compiler_binding_v1"))

function _tc_new_binding_v1(candidate_ref::String, owner_ref::String,
        region_ref::String, chart_ref::String, operator_ref::String,
        source_ref::String, conservation_ref::String,
        input_unit::TypedCompilerUnitV1, output_unit::TypedCompilerUnitV1)
    invoke(TypedCompilerBindingV1,
        Tuple{_TypedCompilerSealV1,String,String,String,String,String,String,String,TypedCompilerUnitV1,TypedCompilerUnitV1},
        _TCIR_SEAL_V1, _tc_text_v1(candidate_ref, "candidate_ref"),
        _tc_text_v1(owner_ref, "owner_ref"), _tc_text_v1(region_ref, "region_ref"),
        _tc_text_v1(chart_ref, "chart_ref"), _tc_text_v1(operator_ref, "operator_ref"),
        _tc_text_v1(source_ref, "source_ref"; allow_typed_absent=true),
        _tc_text_v1(conservation_ref, "conservation_ref"), input_unit, output_unit)
end

function typed_compiler_binding_v1(; candidate_ref::AbstractString="candidate:contract-fixture-v1",
                                   owner_ref::AbstractString="owner:contract-fixture-v1",
                                   region_ref::AbstractString="region:Omega",
                                   chart_ref::AbstractString="chart:cartesian-v1",
                                   operator_ref::AbstractString="operator:identity-v1",
                                   source_ref::AbstractString="source:local-contract-v1",
                                   conservation_ref::AbstractString="conservation:ledger-v1",
                                   input_unit::TypedCompilerUnitV1=typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)),
                                   output_unit::TypedCompilerUnitV1=typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)))
    _tc_new_binding_v1(String(candidate_ref), String(owner_ref), String(region_ref),
        String(chart_ref), String(operator_ref), String(source_ref),
        String(conservation_ref), input_unit, output_unit)
end

struct TypedCompilerSourceAuthorityV1
    schema::String
    revision::String
    status::Symbol
    receipt_ref::String
    candidate_ref::String
    owner_ref::String
    region_ref::String
    chart_ref::String
    operator_ref::String
    source_ref::String
    conservation_ref::String
    input_unit::TypedCompilerUnitV1
    output_unit::TypedCompilerUnitV1
    function TypedCompilerSourceAuthorityV1(::_TypedCompilerSealV1,
            schema::String, revision::String, status::Symbol, receipt_ref::String,
            candidate_ref::String, owner_ref::String, region_ref::String,
            chart_ref::String, operator_ref::String, source_ref::String,
            conservation_ref::String, input_unit::TypedCompilerUnitV1,
            output_unit::TypedCompilerUnitV1)
        _tc_text_v1(receipt_ref, "receipt_ref")
        _tc_text_v1(source_ref, "source_ref")
        new(schema, revision, status, receipt_ref,
            _tc_text_v1(candidate_ref, "candidate_ref"),
            _tc_text_v1(owner_ref, "owner_ref"),
            _tc_text_v1(region_ref, "region_ref"),
            _tc_text_v1(chart_ref, "chart_ref"),
            _tc_text_v1(operator_ref, "operator_ref"), source_ref,
            _tc_text_v1(conservation_ref, "conservation_ref"), input_unit, output_unit)
    end
end
TypedCompilerSourceAuthorityV1(args...) =
    throw(ArgumentError("TypedCompilerSourceAuthorityV1 is sealed; use typed_compiler_source_authority_v1"))

function _tc_new_source_authority_v1(schema::String, revision::String, status::Symbol,
        receipt_ref::String, candidate_ref::String, owner_ref::String,
        region_ref::String, chart_ref::String, operator_ref::String,
        source_ref::String, conservation_ref::String,
        input_unit::TypedCompilerUnitV1, output_unit::TypedCompilerUnitV1)
    invoke(TypedCompilerSourceAuthorityV1,
        Tuple{_TypedCompilerSealV1,String,String,Symbol,String,String,String,String,String,String,String,String,TypedCompilerUnitV1,TypedCompilerUnitV1},
        _TCIR_SEAL_V1, _tc_text_v1(schema, "schema"), _tc_text_v1(revision, "revision"),
        status, _tc_text_v1(receipt_ref, "receipt_ref"),
        _tc_text_v1(candidate_ref, "candidate_ref"), _tc_text_v1(owner_ref, "owner_ref"),
        _tc_text_v1(region_ref, "region_ref"), _tc_text_v1(chart_ref, "chart_ref"),
        _tc_text_v1(operator_ref, "operator_ref"), _tc_text_v1(source_ref, "source_ref"),
        _tc_text_v1(conservation_ref, "conservation_ref"), input_unit, output_unit)
end

function typed_compiler_source_authority_v1(; receipt_ref::AbstractString="receipt:local-source-v1",
        candidate_ref::AbstractString="candidate:contract-fixture-v1",
        owner_ref::AbstractString="owner:contract-fixture-v1",
        region_ref::AbstractString="region:Omega",
        chart_ref::AbstractString="chart:cartesian-v1",
        operator_ref::AbstractString="operator:identity-v1",
        source_ref::AbstractString="source:local-contract-v1",
        conservation_ref::AbstractString="conservation:ledger-v1",
        input_unit::TypedCompilerUnitV1=typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)),
        output_unit::TypedCompilerUnitV1=typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)))
    _tc_new_source_authority_v1(
        _TCIR_SOURCE_AUTHORITY_SCHEMA_V1, _TCIR_SOURCE_AUTHORITY_REVISION_V1,
        _TCIR_SOURCE_AUTHORITY_CHECKED_PRESENT_V1, String(receipt_ref),
        String(candidate_ref), String(owner_ref), String(region_ref), String(chart_ref),
        String(operator_ref), String(source_ref), String(conservation_ref),
        input_unit, output_unit)
end

struct TypedCompilerIRV1
    schema::String
    revision::String
    candidate_ref::String
    owner_ref::String
    region_ref::String
    chart_ref::String
    operator_ref::String
    source_ref::String
    conservation_ref::String
    input_unit::TypedCompilerUnitV1
    output_unit::TypedCompilerUnitV1
    operations::Tuple{Vararg{String}}
    source_kind::Symbol
    synthetic::Bool
    measured::Bool
    claim_ceiling::Symbol
    evidence_scope::Symbol
    source_authority::Union{Nothing,TypedCompilerSourceAuthorityV1}
    function TypedCompilerIRV1(::_TypedCompilerSealV1, schema::String, revision::String,
                               candidate_ref::String, owner_ref::String,
                               region_ref::String, chart_ref::String,
                               operator_ref::String, source_ref::String,
                               conservation_ref::String, input_unit::TypedCompilerUnitV1,
                               output_unit::TypedCompilerUnitV1,
                               operations::Tuple{Vararg{String}}, source_kind::Symbol,
                               synthetic::Bool, measured::Bool, claim_ceiling::Symbol,
                               evidence_scope::Symbol,
                               source_authority::Union{Nothing,TypedCompilerSourceAuthorityV1})
        _tc_text_v1(schema, "schema")
        _tc_text_v1(revision, "revision")
        _tc_text_v1(candidate_ref, "candidate_ref")
        _tc_text_v1(owner_ref, "owner_ref")
        _tc_text_v1(region_ref, "region_ref")
        _tc_text_v1(chart_ref, "chart_ref")
        _tc_text_v1(operator_ref, "operator_ref")
        _tc_text_v1(source_ref, "source_ref"; allow_typed_absent=true)
        _tc_text_v1(conservation_ref, "conservation_ref")
        isempty(operations) && throw(ArgumentError("operations cannot be empty"))
        all(op -> !isempty(strip(op)), operations) || throw(ArgumentError("operation cannot be empty"))
        source_kind in (:synthetic, :local_source) || throw(ArgumentError("unsupported source_kind"))
        claim_ceiling == _TCIR_CONTRACT_ONLY_V1 ||
            throw(ArgumentError("typed compiler IR claim ceiling must be contract_only"))
        evidence_scope == _TCIR_NOT_MEASURED_V1 ||
            throw(ArgumentError("typed compiler IR evidence scope must be not_measured"))
        !measured || throw(ArgumentError("typed compiler IR cannot claim measured evidence"))
        synthetic == (source_kind === :synthetic) ||
            throw(ArgumentError("synthetic flag and source_kind must agree"))
        source_kind == :synthetic && source_authority !== nothing &&
            throw(ArgumentError("synthetic contract cannot carry local source authority"))
        new(schema, revision, candidate_ref, owner_ref, region_ref, chart_ref,
            operator_ref, source_ref, conservation_ref, input_unit, output_unit,
            operations, source_kind, synthetic, measured, claim_ceiling, evidence_scope,
            source_authority)
    end
end
TypedCompilerIRV1(args...) = throw(ArgumentError("TypedCompilerIRV1 is sealed; use typed_compiler_ir_v1"))

function _tc_new_ir_v1(schema::String, revision::String, candidate_ref::String,
        owner_ref::String, region_ref::String, chart_ref::String,
        operator_ref::String, source_ref::String, conservation_ref::String,
        input_unit::TypedCompilerUnitV1, output_unit::TypedCompilerUnitV1,
        operations::Tuple{Vararg{String}}, source_kind::Symbol, synthetic::Bool,
        measured::Bool, claim_ceiling::Symbol, evidence_scope::Symbol,
        source_authority::Union{Nothing,TypedCompilerSourceAuthorityV1})
    invoke(TypedCompilerIRV1,
        Tuple{_TypedCompilerSealV1,String,String,String,String,String,String,String,String,String,TypedCompilerUnitV1,TypedCompilerUnitV1,Tuple{Vararg{String}},Symbol,Bool,Bool,Symbol,Symbol,Union{Nothing,TypedCompilerSourceAuthorityV1}},
        _TCIR_SEAL_V1, _tc_text_v1(schema, "schema"), _tc_text_v1(revision, "revision"),
        _tc_text_v1(candidate_ref, "candidate_ref"), _tc_text_v1(owner_ref, "owner_ref"),
        _tc_text_v1(region_ref, "region_ref"), _tc_text_v1(chart_ref, "chart_ref"),
        _tc_text_v1(operator_ref, "operator_ref"),
        _tc_text_v1(source_ref, "source_ref"; allow_typed_absent=true),
        _tc_text_v1(conservation_ref, "conservation_ref"), input_unit,
        output_unit, Tuple(_tc_text_v1(op, "operation") for op in operations),
        source_kind, synthetic, measured, claim_ceiling,
        evidence_scope, source_authority)
end

function typed_compiler_ir_v1(; schema::AbstractString=_TCIR_SCHEMA_V1,
                              revision::AbstractString=_TCIR_REVISION_V1,
                              candidate_ref::AbstractString="candidate:contract-fixture-v1",
                              owner_ref::AbstractString="owner:contract-fixture-v1",
                              region_ref::AbstractString="region:Omega",
                              chart_ref::AbstractString="chart:cartesian-v1",
                              operator_ref::AbstractString="operator:identity-v1",
                              source_ref::AbstractString="source:local-contract-v1",
                              conservation_ref::AbstractString="conservation:ledger-v1",
                              input_unit::TypedCompilerUnitV1=typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)),
                              output_unit::TypedCompilerUnitV1=typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)),
                              operations=("input", "operator", "source", "conservation"),
                              source_kind::Symbol=:synthetic, synthetic::Bool=true,
                              measured::Bool=false, claim_ceiling::Symbol=_TCIR_CONTRACT_ONLY_V1,
                              evidence_scope::Symbol=_TCIR_NOT_MEASURED_V1,
                              source_authority::Union{Nothing,TypedCompilerSourceAuthorityV1}=nothing)
    ops = _tc_tuple_text_v1(Tuple(operations), "operations")
    _tc_new_ir_v1(String(schema), String(revision), String(candidate_ref),
        String(owner_ref), String(region_ref), String(chart_ref), String(operator_ref),
        String(source_ref), String(conservation_ref), input_unit, output_unit, ops,
        source_kind, synthetic, measured, claim_ceiling, evidence_scope, source_authority)
end

struct TypedCompilerFailureV1
    code::Symbol
    path::String
    detail::String
end

struct TypedCompilerValidationV1
    valid::Bool
    status::Symbol
    failures::Tuple{Vararg{TypedCompilerFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
    measured::Bool
end

_tc_failure_v1(code::Symbol, path::AbstractString, detail::AbstractString) =
    TypedCompilerFailureV1(code, String(path), String(detail))

function _tc_validation_v1(valid::Bool, status::Symbol,
                            failures::Vector{TypedCompilerFailureV1})
    status in (_TCIR_READY_V1, _TCIR_TERMINAL_DEFERRED_V1, _TCIR_FAIL_CLOSED_V1) ||
        throw(ArgumentError("invalid typed compiler validation status"))
    TypedCompilerValidationV1(valid, status, Tuple(failures),
                              _TCIR_CONTRACT_ONLY_V1, _TCIR_NOT_MEASURED_V1, false)
end

function _tc_unit_valid_v1(unit::TypedCompilerUnitV1, path::String,
                           failures::Vector{TypedCompilerFailureV1})
    isfinite(unit.scale_to_si) && unit.scale_to_si > 0.0 ||
        push!(failures, _tc_failure_v1(:invalid_unit, path, "unit scale is not finite and positive"))
    length(unit.exponents) == 7 ||
        push!(failures, _tc_failure_v1(:invalid_unit, path, "unit dimension rank is not seven"))
end

function _tc_unit_equal_v1(a::TypedCompilerUnitV1, b::TypedCompilerUnitV1)::Bool
    a.name == b.name && a.exponents == b.exponents && isequal(a.scale_to_si, b.scale_to_si)
end

"""Validate a sealed IR against the expected candidate/source binding.

The result is structural only.  `:ready` means ready for a later compiler
lane; it does not mean compiled, solved, converged, conserved, or physical.
`typed_absent` source identity is a typed terminal-deferred state.
"""
function validate_typed_compiler_ir(ir::TypedCompilerIRV1,
                                    expected::TypedCompilerBindingV1)
    failures = TypedCompilerFailureV1[]
    ir.schema == _TCIR_SCHEMA_V1 || push!(failures, _tc_failure_v1(:schema_mismatch,
        "schema", "IR schema is not the exact v1 declaration"))
    ir.revision == _TCIR_REVISION_V1 || push!(failures, _tc_failure_v1(:revision_mismatch,
        "revision", "IR revision is not the exact v1 declaration"))
    for field in (:candidate_ref, :owner_ref, :region_ref, :chart_ref,
                  :operator_ref, :conservation_ref)
        actual = getfield(ir, field)
        wanted = getfield(expected, field)
        actual == wanted || push!(failures, _tc_failure_v1(:binding_mismatch,
            String(field), "IR binding does not equal expected binding"))
    end
    _tc_unit_equal_v1(ir.input_unit, expected.input_unit) ||
        push!(failures, _tc_failure_v1(:unit_mismatch, "input_unit",
            "IR input unit does not equal the expected typed declaration"))
    _tc_unit_equal_v1(ir.output_unit, expected.output_unit) ||
        push!(failures, _tc_failure_v1(:unit_mismatch, "output_unit",
            "IR output unit does not equal the expected typed declaration"))
    if ir.source_ref == _TCIR_TYPED_ABSENT_V1
        push!(failures, _tc_failure_v1(:source_authority_absent, "source_ref",
            "source is typed_absent and cannot be compiled"))
    elseif ir.source_ref != expected.source_ref
        push!(failures, _tc_failure_v1(:binding_mismatch, "source_ref",
            "IR source does not equal expected source"))
    end
    if ir.source_kind == :local_source
        authority = ir.source_authority
        if ir.source_ref == _TCIR_TYPED_ABSENT_V1 || authority === nothing
            push!(failures, _tc_failure_v1(:source_authority_absent, "source_authority",
                "local source requires a sealed checked-present authority receipt"))
        else
            authority.schema == _TCIR_SOURCE_AUTHORITY_SCHEMA_V1 ||
                push!(failures, _tc_failure_v1(:source_authority_mismatch,
                    "source_authority.schema", "source authority schema is not v1"))
            authority.revision == _TCIR_SOURCE_AUTHORITY_REVISION_V1 ||
                push!(failures, _tc_failure_v1(:source_authority_mismatch,
                    "source_authority.revision", "source authority revision is not v1"))
            authority.status == _TCIR_SOURCE_AUTHORITY_CHECKED_PRESENT_V1 ||
                push!(failures, _tc_failure_v1(:source_authority_mismatch,
                    "source_authority.status", "source authority is not checked_present"))
            isempty(strip(authority.receipt_ref)) &&
                push!(failures, _tc_failure_v1(:source_authority_mismatch,
                    "source_authority.receipt_ref", "source authority receipt is empty"))
            for field in (:candidate_ref, :owner_ref, :region_ref, :chart_ref,
                          :operator_ref, :source_ref, :conservation_ref)
                getfield(authority, field) == getfield(ir, field) &&
                    getfield(authority, field) == getfield(expected, field) ||
                    push!(failures, _tc_failure_v1(:source_authority_mismatch,
                        "source_authority." * String(field),
                        "source authority field is not exactly bound to IR and expected binding"))
            end
            _tc_unit_equal_v1(authority.input_unit, ir.input_unit) &&
                _tc_unit_equal_v1(authority.input_unit, expected.input_unit) ||
                push!(failures, _tc_failure_v1(:source_authority_mismatch,
                    "source_authority.input_unit", "source authority input unit is not exactly bound"))
            _tc_unit_equal_v1(authority.output_unit, ir.output_unit) &&
                _tc_unit_equal_v1(authority.output_unit, expected.output_unit) ||
                push!(failures, _tc_failure_v1(:source_authority_mismatch,
                    "source_authority.output_unit", "source authority output unit is not exactly bound"))
        end
    elseif ir.source_authority !== nothing
        push!(failures, _tc_failure_v1(:source_authority_mismatch, "source_authority",
            "synthetic IR cannot carry local-source authority"))
    end
    _tc_unit_valid_v1(ir.input_unit, "input_unit", failures)
    _tc_unit_valid_v1(ir.output_unit, "output_unit", failures)
    allowed_operations = ("input", "operator", "source", "conservation")
    all(op -> op in allowed_operations, ir.operations) ||
        push!(failures, _tc_failure_v1(:illegal_operation, "operations",
            "operation is outside the sealed contract vocabulary"))
    length(unique(ir.operations)) == length(ir.operations) ||
        push!(failures, _tc_failure_v1(:duplicate_operation, "operations",
            "operation sequence contains duplicates"))
    ir.synthetic == (ir.source_kind === :synthetic) ||
        push!(failures, _tc_failure_v1(:synthetic_scope_mismatch, "source_kind",
            "synthetic flag and source_kind must agree"))
    ir.measured && push!(failures, _tc_failure_v1(:measured_claim_forbidden,
        "measured", "contract-only IR cannot claim measured evidence"))
    ir.claim_ceiling == _TCIR_CONTRACT_ONLY_V1 ||
        push!(failures, _tc_failure_v1(:claim_ceiling_forbidden, "claim_ceiling",
            "contract-only ceiling was changed"))
    ir.evidence_scope == _TCIR_NOT_MEASURED_V1 ||
        push!(failures, _tc_failure_v1(:evidence_scope_forbidden, "evidence_scope",
            "not_measured scope was changed"))
    deferred = any(f -> f.code == :source_authority_absent, failures)
    fatal = any(f -> f.code != :source_authority_absent, failures)
    status = fatal ? _TCIR_FAIL_CLOSED_V1 : deferred ? _TCIR_TERMINAL_DEFERRED_V1 : _TCIR_READY_V1
    _tc_validation_v1(status == _TCIR_READY_V1, status, failures)
end

validate_typed_compiler_ir(ir::TypedCompilerIRV1) =
    validate_typed_compiler_ir(ir, typed_compiler_binding_v1())

function typed_compiler_payload_v1(ir::TypedCompilerIRV1)
    (schema=ir.schema, revision=ir.revision, candidate_ref=ir.candidate_ref,
     owner_ref=ir.owner_ref, region_ref=ir.region_ref, chart_ref=ir.chart_ref,
     operator_ref=ir.operator_ref, source_ref=ir.source_ref,
     conservation_ref=ir.conservation_ref, input_unit=ir.input_unit,
     output_unit=ir.output_unit, operations=ir.operations,
     source_kind=ir.source_kind, synthetic=ir.synthetic, measured=ir.measured,
     claim_ceiling=ir.claim_ceiling, evidence_scope=ir.evidence_scope,
     source_authority=ir.source_authority)
end
