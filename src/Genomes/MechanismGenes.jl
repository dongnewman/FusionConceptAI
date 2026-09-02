"""Closed, value-level primitives for the mechanism genome.

This file intentionally contains no genome aggregate or normalization logic.  The
types here are the small, typed vocabulary that later genome layers may compose.
"""

# Do not use the open P0 helpers for admission here.  This fixed-width helper is
# invoked with `invoke` by every constructor so a downstream method extension
# cannot turn an invalid gene into a valid one.
function _gene_text(value::Any, field::Any)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    isvalid(value) || throw(ArgumentError("$field must contain valid Unicode scalar values"))
    isempty(value) && throw(ArgumentError("$field cannot be empty"))
    String(value)
end

const _GENE_INTEGER_TYPES = (Int8, Int16, Int32, Int64, Int128,
                             UInt8, UInt16, UInt32, UInt64, UInt128)

function _gene_rational(value::Any, field::Any)
    value_type = typeof(value)
    if value_type === Rational{Int64}
        denominator(value) > 0 || throw(ArgumentError("$field denominator must be positive"))
        return value
    end
    value_type in _GENE_INTEGER_TYPES ||
        throw(ArgumentError("$field requires Rational{Int64} or a fixed-width integer"))
    if value_type <: Signed
        (typemin(Int64) <= value <= typemax(Int64)) ||
            throw(ArgumentError("$field is outside the Int64 rational range"))
    else
        value <= typemax(Int64) || throw(ArgumentError("$field is outside the Int64 rational range"))
    end
    Rational{Int64}(Int64(value))
end

function _gene_ref(value::Any, field::Any)
    invoke(_gene_text, Tuple{Any,Any}, value, field)
end

struct StateGeneRefV1
    value::String
    function StateGeneRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "state gene reference"))
    end
end

struct InvariantRefV1
    value::String
    function InvariantRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "invariant reference"))
    end
end

struct ParameterRefV1
    value::String
    function ParameterRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "parameter reference"))
    end
end

struct SymmetryRefV1
    value::String
    function SymmetryRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "symmetry reference"))
    end
end

struct ObservableRefV1
    value::String
    function ObservableRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "observable reference"))
    end
end

struct OperatorSiteRefV1
    value::String
    function OperatorSiteRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "operator site reference"))
    end
end

struct ConstraintRefV1
    value::String
    function ConstraintRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "constraint reference"))
    end
end

struct HoleRefV1
    value::String
    function HoleRefV1(value::Any)
        new(invoke(_gene_ref, Tuple{Any,Any}, value, "hole reference"))
    end
end

for ref_type in (:StateGeneRefV1, :InvariantRefV1, :ParameterRefV1, :SymmetryRefV1,
                 :ObservableRefV1, :OperatorSiteRefV1, :ConstraintRefV1, :HoleRefV1)
    @eval begin
        Base.:(==)(a::$ref_type, b::$ref_type) = a.value == b.value
        Base.hash(a::$ref_type, h::UInt) = hash(a.value, h)
        semantic_view(a::$ref_type) = (value=a.value,)
    end
end

struct ExactFiniteIntervalV1
    lower::Rational{Int64}
    upper::Rational{Int64}
    allow_equal::Bool
    function ExactFiniteIntervalV1(lower::Any, upper::Any, allow_equal::Any)
        allow_equal isa Bool || throw(ArgumentError("allow_equal must be Bool"))
        lo = invoke(_gene_rational, Tuple{Any,Any}, lower, "interval lower bound")
        hi = invoke(_gene_rational, Tuple{Any,Any}, upper, "interval upper bound")
        lo <= hi || throw(ArgumentError("interval lower bound exceeds upper bound"))
        allow_equal || lo < hi || throw(ArgumentError("strict interval cannot have equal bounds"))
        new(lo, hi, allow_equal)
    end
end
ExactFiniteIntervalV1(lower::Any, upper::Any; allow_equal::Any=true) =
    ExactFiniteIntervalV1(lower, upper, allow_equal)

struct QuantityIntervalV1
    interval::ExactFiniteIntervalV1
    unit::UnitSignature
    function QuantityIntervalV1(interval::Any, unit::Any)
        interval isa ExactFiniteIntervalV1 || throw(ArgumentError("interval must be ExactFiniteIntervalV1"))
        unit isa UnitSignature || throw(ArgumentError("unit must be UnitSignature"))
        new(interval, unit)
    end
end

struct NonnegativeQuantityV1
    value::Rational{Int64}
    unit::UnitSignature
    function NonnegativeQuantityV1(value::Any, unit::Any)
        unit isa UnitSignature || throw(ArgumentError("unit must be UnitSignature"))
        amount = invoke(_gene_rational, Tuple{Any,Any}, value, "nonnegative quantity")
        amount >= 0 || throw(ArgumentError("quantity must be non-negative"))
        new(amount, unit)
    end
end

struct ExactRationalMatrixV1
    rows::Tuple
    function ExactRationalMatrixV1(rows::Any)
        rows isa Tuple || throw(ArgumentError("matrix must be a tuple of tuples"))
        isempty(rows) && throw(ArgumentError("matrix cannot be empty"))
        all(row isa Tuple for row in rows) ||
            throw(ArgumentError("matrix rows must be tuples"))
        width = length(first(rows))
        width > 0 || throw(ArgumentError("matrix cannot have empty rows"))
        all(length(row) == width for row in rows) ||
            throw(ArgumentError("matrix must be rectangular"))
        converted = Tuple(Tuple(invoke(_gene_rational, Tuple{Any,Any}, value, "matrix entry")
                                for value in row) for row in rows)
        new(converted)
    end
end

semantic_view(x::ExactFiniteIntervalV1) =
    (lower=x.lower, upper=x.upper, allow_equal=x.allow_equal)
semantic_view(x::QuantityIntervalV1) = (interval=x.interval, unit=x.unit)
semantic_view(x::NonnegativeQuantityV1) = (value=x.value, unit=x.unit)
semantic_view(x::ExactRationalMatrixV1) = (rows=x.rows,)

@enum StateEpistemicV1 state_derived state_measured state_declared_known state_hypothesized state_learned state_empirical_prior state_unknown_placeholder state_not_applicable
@enum ParitySignV1 even odd
@enum InvariantScopeV1 scope_global scope_domain scope_interface
@enum EntropyDirectionV1 entropy_not_applicable entropy_nondecreasing entropy_nonincreasing entropy_conserved
@enum ParameterTransformKindV1 transform_linear transform_log transform_signed_log
@enum SymmetryGroupKindV1 symmetry_discrete symmetry_continuous
@enum SymmetryBehaviorV1 symmetry_invariant symmetry_equivariant
@enum ConservationEffectKindV1 redistribution interface_flux net_creation net_destruction

struct ParityActionV1
    generator_ref::QualifiedRefV1
    sign::ParitySignV1
    function ParityActionV1(generator_ref::Any, sign::Any)
        generator_ref isa QualifiedRefV1 || throw(ArgumentError("generator_ref must be QualifiedRefV1"))
        sign isa ParitySignV1 || throw(ArgumentError("sign must be ParitySignV1"))
        new(generator_ref, sign)
    end
end
semantic_view(x::ParityActionV1) = (generator_ref=x.generator_ref, sign=x.sign)
