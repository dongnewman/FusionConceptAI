"""Declarative, immutable operator signatures for the P0 typed IR."""

struct OperatorRefV1
    qualified::QualifiedRefV1
    function OperatorRefV1(qualified::QualifiedRefV1)
        new(qualified)
    end
end
OperatorRefV1(id::AbstractString, version::AbstractString) = OperatorRefV1(QualifiedRefV1(id, version))

struct OperatorParameterSpecV1
    name::Symbol
    type_tag::Symbol
    required::Bool
    function OperatorParameterSpecV1(name::Symbol, type_tag::Symbol, required::Bool=false)
        !isempty(String(name)) && isvalid(String(name)) || throw(ArgumentError("parameter name is invalid"))
        isvalid(String(type_tag)) && type_tag in _OPERATOR_PARAMETER_TAGS ||
            throw(ArgumentError("unknown parameter type tag"))
        new(name, type_tag, required)
    end
end

abstract type OperatorTypeRuleV1 end
struct ExactTypeRuleV1 <: OperatorTypeRuleV1
    input_types::Tuple{Vararg{PhysicalType}}
    output_types::Tuple{Vararg{PhysicalType}}
    function ExactTypeRuleV1(input_types, output_types)
        ins, outs = Tuple(input_types), Tuple(output_types)
        all(t -> t isa PhysicalType, ins) && all(t -> t isa PhysicalType, outs) ||
            throw(ArgumentError("exact operator rule requires PhysicalType values"))
        new(ins, outs)
    end
end
struct SameTypeVariadicRuleV1 <: OperatorTypeRuleV1
    minimum_arity::Int
    maximum_arity::Int
    function SameTypeVariadicRuleV1(minimum_arity::Integer=1, maximum_arity::Integer=typemax(Int))
        invoke(_checked_int, Tuple{Any,Any}, minimum_arity, "minimum arity") >= 0 || throw(ArgumentError("invalid variadic rule arity"))
        lo, hi = invoke(_checked_int, Tuple{Any,Any}, minimum_arity, "minimum arity"),
            invoke(_checked_int, Tuple{Any,Any}, maximum_arity, "maximum arity")
        lo <= hi || throw(ArgumentError("invalid variadic rule arity"))
        new(lo, hi)
    end
end
struct ScalarProductRuleV1 <: OperatorTypeRuleV1
    division::Bool
    function ScalarProductRuleV1(division::Bool=false)
        new(division)
    end
end
struct DotProductRuleV1 <: OperatorTypeRuleV1
    function DotProductRuleV1()
        new()
    end
end
struct TensorProductRuleV1 <: OperatorTypeRuleV1
    function TensorProductRuleV1()
        new()
    end
end
struct ContractRuleV1 <: OperatorTypeRuleV1
    function ContractRuleV1()
        new()
    end
end
ContractRuleV1(args...) = throw(ArgumentError("ContractRuleV1 is a marker; contraction_order is a required typed parameter"))
struct SpatialDerivativeRuleV1 <: OperatorTypeRuleV1
    opcode::Symbol
    function SpatialDerivativeRuleV1(opcode::Symbol)
        opcode in (:gradient, :divergence, :curl, :laplace) || throw(ArgumentError("unsupported spatial derivative rule"))
        new(opcode)
    end
end
struct TimeDerivativeRuleV1 <: OperatorTypeRuleV1
    function TimeDerivativeRuleV1()
        new()
    end
end
struct SamplingRuleV1 <: OperatorTypeRuleV1
    hold::Bool
    function SamplingRuleV1(hold::Bool=false)
        new(hold)
    end
end
struct DelayRuleV1 <: OperatorTypeRuleV1
    function DelayRuleV1()
        new()
    end
end
struct EventTransitionRuleV1 <: OperatorTypeRuleV1
    opcode::Symbol
    function EventTransitionRuleV1(opcode::Symbol)
        opcode in (:threshold_switch, :event_reset) ||
            throw(ArgumentError("unsupported event transition rule"))
        new(opcode)
    end
end

semantic_view(x::OperatorRefV1) = (qualified=x.qualified,)
semantic_view(x::OperatorParameterSpecV1) = (name=x.name, type_tag=x.type_tag, required=x.required)
semantic_view(x::ExactTypeRuleV1) = (input_types=x.input_types, output_types=x.output_types)
semantic_view(x::SameTypeVariadicRuleV1) = (minimum_arity=x.minimum_arity, maximum_arity=x.maximum_arity)
semantic_view(x::ScalarProductRuleV1) = (division=x.division,)
semantic_view(::DotProductRuleV1) = (rule=:dot_product,)
semantic_view(::TensorProductRuleV1) = (rule=:tensor_product,)
semantic_view(::ContractRuleV1) = (rule=:contract,)
semantic_view(x::SpatialDerivativeRuleV1) = (opcode=x.opcode,)
semantic_view(::TimeDerivativeRuleV1) = (rule=:time_derivative,)
semantic_view(x::SamplingRuleV1) = (hold=x.hold,)
semantic_view(::DelayRuleV1) = (rule=:delay,)
semantic_view(x::EventTransitionRuleV1) = (opcode=x.opcode,)
Base.:(==)(a::OperatorRefV1, b::OperatorRefV1) = a.qualified == b.qualified
Base.hash(a::QualifiedRefV1, h::UInt) = hash((a.id, a.version), h)
Base.hash(a::OperatorRefV1, h::UInt) = hash(a.qualified, h)

const _OPERATOR_PARAMETER_TAGS = (:finite_nonnegative_real, :finite_real, :qualified_ref, :symbol,
                                  :nonnegative_integer)
const _OPERATOR_ROLE_SET = (:governing, :additive, :constraint, :interface, :boundary, :source,
                            :control, :state, :event)
const _OPERATOR_LOCALITIES = (:local, :neighbor, :global, :boundary)

function _checked_int(x, field)
    x isa Bool && throw(ArgumentError("$field must be an integer"))
    x isa Integer || throw(ArgumentError("$field must be an integer"))
    typemin(Int) <= x <= typemax(Int) || throw(ArgumentError("$field is out of range"))
    Int(x)
end

function _normalize_symbol_set(xs, field; whitelist=nothing, nonempty=false)
    vals = _tuple_or_argument(xs, field)
    all(x -> x isa Symbol && isvalid(String(x)) && (whitelist === nothing || x in whitelist), vals) ||
        throw(ArgumentError("$field must contain valid symbols"))
    nonempty && isempty(vals) && throw(ArgumentError("$field cannot be empty"))
    length(unique(vals)) == length(vals) || throw(ArgumentError("$field contains duplicates"))
    Tuple(sort(collect(vals), by=String))
end

function _tuple_or_argument(value, field)
    try
        Tuple(value)
    catch
        throw(ArgumentError("$field must be a tuple-like collection"))
    end
end

function _normalize_groups(groups, input_arity)
    raw = _tuple_or_argument(groups, "commutative input groups")
    normalized = Tuple[]
    used = Set{Int}()
    for group in raw
        g = _tuple_or_argument(group, "commutative input group")
        all(i -> i isa Integer && !(i isa Bool) && 1 <= i <= input_arity, g) ||
            throw(ArgumentError("commutative input index is out of range"))
        length(g) >= 2 || throw(ArgumentError("commutative groups require at least two inputs"))
        length(unique(g)) == length(g) || throw(ArgumentError("commutative group contains duplicates"))
        any(i -> i in used, g) && throw(ArgumentError("commutative groups overlap"))
        union!(used, Int.(g))
        push!(normalized, Tuple(sort(collect(Int.(g)))))
    end
    Tuple(sort(normalized, by=repr))
end

function _rule_derivative_contribution(rule::OperatorTypeRuleV1)
    typeof(rule) === SpatialDerivativeRuleV1 && return rule.opcode == :laplace ? 2 : 1
    typeof(rule) === TimeDerivativeRuleV1 && return 1
    0
end

function _rule_event(rule::OperatorTypeRuleV1)
    typeof(rule) === EventTransitionRuleV1
end

function _rule_parameter_names(schema)
    names = Tuple(p.name for p in schema)
    length(unique(names)) == length(names) || throw(ArgumentError("parameter schema has duplicate names"))
    all(p -> p isa OperatorParameterSpecV1 && p.type_tag in _OPERATOR_PARAMETER_TAGS, schema) ||
        throw(ArgumentError("parameter schema contains an unknown type tag"))
    names
end

function _sealed_rule_arity(rule::OperatorTypeRuleV1, input_arity::Int, output_arity::Int)
    if typeof(rule) === ExactTypeRuleV1
        return input_arity == length(rule.input_types) && output_arity == length(rule.output_types)
    elseif typeof(rule) === SameTypeVariadicRuleV1
        return rule.minimum_arity <= input_arity <= rule.maximum_arity && output_arity == 1
    elseif typeof(rule) === ScalarProductRuleV1 || typeof(rule) === DotProductRuleV1 ||
           typeof(rule) === TensorProductRuleV1 || typeof(rule) === ContractRuleV1 ||
           typeof(rule) === EventTransitionRuleV1
        return input_arity == 2 && output_arity == 1
    elseif typeof(rule) === SpatialDerivativeRuleV1 || typeof(rule) === TimeDerivativeRuleV1 ||
           typeof(rule) === SamplingRuleV1 || typeof(rule) === DelayRuleV1
        return input_arity == 1 && output_arity == 1
    end
    false
end

function _sealed_rule_schema(rule::OperatorTypeRuleV1)
    if typeof(rule) === ContractRuleV1
        (OperatorParameterSpecV1(:contraction_order, :nonnegative_integer, true),)
    elseif typeof(rule) === DelayRuleV1
        (OperatorParameterSpecV1(:delay_seconds, :finite_nonnegative_real, true),)
    elseif typeof(rule) === SamplingRuleV1
        rule.hold ? (OperatorParameterSpecV1(:target_kind, :symbol, true),) :
            (OperatorParameterSpecV1(:target_clock, :qualified_ref, true),)
    else
        ()
    end
end

"""Compare sealed parameter schemas field-by-field, never through overloaded equality."""
function _sealed_schema_equal(a::Tuple, b::Tuple)
    length(a) == length(b) || return false
    for (left, right) in zip(a, b)
        typeof(left) === OperatorParameterSpecV1 && typeof(right) === OperatorParameterSpecV1 || return false
        left.name === right.name && left.type_tag === right.type_tag && left.required === right.required || return false
    end
    true
end

"""Fixed normalization used by both manifest constructors; never dispatches on user types."""
function _sealed_normalize_manifest(allowed_roles::Tuple, parameter_schema::Tuple,
                                    commutative_input_groups::Tuple,
                                    allowed_conservation_effects::Tuple,
                                    forbidden_conservation_effects::Tuple, input_arity::Int)
    roles_raw = allowed_roles
    all(x -> typeof(x) === Symbol && isvalid(String(x)) && x in _OPERATOR_ROLE_SET, roles_raw) && !isempty(roles_raw) ||
        throw(ArgumentError("allowed roles must be a non-empty closed symbol set"))
    length(unique(roles_raw)) == length(roles_raw) || throw(ArgumentError("allowed roles contain duplicates"))
    roles = Tuple(sort(collect(roles_raw), by=String))

    params_raw = parameter_schema
    all(p -> typeof(p) === OperatorParameterSpecV1, params_raw) ||
        throw(ArgumentError("parameter schema elements must be typed"))
    names = Tuple(p.name for p in params_raw)
    length(unique(names)) == length(names) || throw(ArgumentError("parameter schema has duplicate names"))
    params = Tuple(sort(collect(params_raw), by=p -> String(p.name)))

    groups = Tuple[]
    used = Set{Int}()
    for raw_group in commutative_input_groups
        raw_group isa Tuple || throw(ArgumentError("commutative groups must be tuples"))
        length(raw_group) >= 2 || throw(ArgumentError("commutative groups require at least two inputs"))
        all(i -> typeof(i) <: Integer && !(i isa Bool) && 1 <= i <= input_arity, raw_group) ||
            throw(ArgumentError("commutative input index is out of range"))
        length(unique(raw_group)) == length(raw_group) || throw(ArgumentError("commutative group contains duplicates"))
        any(i -> i in used, raw_group) && throw(ArgumentError("commutative groups overlap"))
        ints = Tuple(Int(i) for i in raw_group)
        union!(used, ints)
        push!(groups, Tuple(sort(collect(ints))))
    end
    normalized_groups = Tuple(sort(groups, by=repr))

    all(x -> typeof(x) === Symbol && isvalid(String(x)), allowed_conservation_effects) ||
        throw(ArgumentError("allowed conservation effects must be valid symbols"))
    all(x -> typeof(x) === Symbol && isvalid(String(x)), forbidden_conservation_effects) ||
        throw(ArgumentError("forbidden conservation effects must be valid symbols"))
    length(unique(allowed_conservation_effects)) == length(allowed_conservation_effects) ||
        throw(ArgumentError("allowed conservation effects contain duplicates"))
    length(unique(forbidden_conservation_effects)) == length(forbidden_conservation_effects) ||
        throw(ArgumentError("forbidden conservation effects contain duplicates"))
    isempty(intersect(Set(allowed_conservation_effects), Set(forbidden_conservation_effects))) ||
        throw(ArgumentError("allowed and forbidden conservation effects overlap"))
    allowed = Tuple(sort(collect(allowed_conservation_effects), by=String))
    forbidden = Tuple(sort(collect(forbidden_conservation_effects), by=String))
    (roles, params, normalized_groups, allowed, forbidden)
end

struct OperatorManifestV1
    operator_ref::OperatorRefV1
    manifest_hash::Digest256
    input_arity::Int
    output_arity::Int
    input_type_rule::OperatorTypeRuleV1
    output_type_rule::OperatorTypeRuleV1
    allowed_roles::Tuple{Vararg{Symbol}}
    parameter_schema::Tuple{Vararg{OperatorParameterSpecV1}}
    locality::Symbol
    max_derivative_contribution::UInt8
    pure::Bool
    stateful::Bool
    stochastic::Bool
    event::Bool
    commutative_input_groups::Tuple
    cse_allowed::Bool
    allowed_conservation_effects::Tuple{Vararg{Symbol}}
    forbidden_conservation_effects::Tuple{Vararg{Symbol}}
    function OperatorManifestV1(operator_ref, manifest_hash, input_arity, output_arity,
                                input_type_rule, output_type_rule, allowed_roles, parameter_schema,
                                locality, max_derivative_contribution, pure, stateful, stochastic, event,
                                commutative_input_groups, cse_allowed, allowed_conservation_effects,
                                forbidden_conservation_effects)
        operator_ref isa OperatorRefV1 && manifest_hash isa Digest256 && input_arity isa Int && output_arity isa Int &&
            input_type_rule isa OperatorTypeRuleV1 && output_type_rule isa OperatorTypeRuleV1 &&
            locality isa Symbol && max_derivative_contribution isa UInt8 &&
            pure isa Bool && stateful isa Bool && stochastic isa Bool && event isa Bool &&
            cse_allowed isa Bool || throw(ArgumentError("operator manifest has invalid typed fields"))
        allowed_roles isa Tuple && parameter_schema isa Tuple && commutative_input_groups isa Tuple &&
            allowed_conservation_effects isa Tuple && forbidden_conservation_effects isa Tuple ||
            throw(ArgumentError("operator manifest collection fields must be tuples"))
        input_arity >= 0 && output_arity >= 0 || throw(ArgumentError("operator arity cannot be negative"))
        (typeof(input_type_rule) === ExactTypeRuleV1 || typeof(input_type_rule) === SameTypeVariadicRuleV1 ||
         typeof(input_type_rule) === ScalarProductRuleV1 || typeof(input_type_rule) === DotProductRuleV1 ||
         typeof(input_type_rule) === TensorProductRuleV1 || typeof(input_type_rule) === ContractRuleV1 ||
         typeof(input_type_rule) === SpatialDerivativeRuleV1 ||
         typeof(input_type_rule) === TimeDerivativeRuleV1 || typeof(input_type_rule) === SamplingRuleV1 ||
         typeof(input_type_rule) === DelayRuleV1 || typeof(input_type_rule) === EventTransitionRuleV1) &&
        (typeof(output_type_rule) === ExactTypeRuleV1 || typeof(output_type_rule) === SameTypeVariadicRuleV1 ||
         typeof(output_type_rule) === ScalarProductRuleV1 || typeof(output_type_rule) === DotProductRuleV1 ||
         typeof(output_type_rule) === TensorProductRuleV1 || typeof(output_type_rule) === ContractRuleV1 ||
         typeof(output_type_rule) === SpatialDerivativeRuleV1 ||
         typeof(output_type_rule) === TimeDerivativeRuleV1 || typeof(output_type_rule) === SamplingRuleV1 ||
         typeof(output_type_rule) === DelayRuleV1 || typeof(output_type_rule) === EventTransitionRuleV1) ||
            throw(ArgumentError("operator manifest accepts core declarative rules only"))
        allowed_roles isa Tuple && parameter_schema isa Tuple && commutative_input_groups isa Tuple &&
            allowed_conservation_effects isa Tuple && forbidden_conservation_effects isa Tuple ||
            throw(ArgumentError("operator manifest collection fields must be tuples"))
        roles, params, groups, allowed, forbidden = invoke(_sealed_normalize_manifest,
            Tuple{Tuple,Tuple,Tuple,Tuple,Tuple,Int}, allowed_roles, parameter_schema,
            commutative_input_groups, allowed_conservation_effects, forbidden_conservation_effects, input_arity)
        locality in _OPERATOR_LOCALITIES || throw(ArgumentError("operator locality is not in the closed vocabulary"))
        invoke(_sealed_rule_arity, Tuple{OperatorTypeRuleV1,Int,Int}, input_type_rule, input_arity, output_arity) &&
            invoke(_sealed_rule_arity, Tuple{OperatorTypeRuleV1,Int,Int}, output_type_rule, input_arity, output_arity) ||
            throw(ArgumentError("manifest arity does not match its sealed type rule"))
        invoke(_sealed_schema_equal, Tuple{Tuple,Tuple}, params,
            invoke(_sealed_rule_schema, Tuple{OperatorTypeRuleV1}, input_type_rule)) &&
            invoke(_sealed_schema_equal, Tuple{Tuple,Tuple}, params,
                invoke(_sealed_rule_schema, Tuple{OperatorTypeRuleV1}, output_type_rule)) ||
            throw(ArgumentError("manifest parameter schema is not rule-derived"))
        input_derivative = if typeof(input_type_rule) === SpatialDerivativeRuleV1
            UInt8(input_type_rule.opcode === :laplace ? 2 : 1)
        elseif typeof(input_type_rule) === TimeDerivativeRuleV1
            UInt8(1)
        else
            UInt8(0)
        end
        output_derivative = if typeof(output_type_rule) === SpatialDerivativeRuleV1
            UInt8(output_type_rule.opcode === :laplace ? 2 : 1)
        elseif typeof(output_type_rule) === TimeDerivativeRuleV1
            UInt8(1)
        else
            UInt8(0)
        end
        max_derivative_contribution === input_derivative && input_derivative === output_derivative ||
            throw(ArgumentError("max derivative contribution is not rule-derived"))
        event == invoke(_rule_event, Tuple{OperatorTypeRuleV1}, input_type_rule) &&
            event == invoke(_rule_event, Tuple{OperatorTypeRuleV1}, output_type_rule) ||
            throw(ArgumentError("event metadata is inconsistent with type rule"))
        pure == !(stateful || stochastic || event) ||
            throw(ArgumentError("pure metadata is inconsistent with operator effects"))
        cse_allowed == !(stateful || stochastic || event) ||
            throw(ArgumentError("CSE permission is inconsistent with stateful/event metadata"))
        all(x -> typeof(x) === Symbol && isvalid(String(x)), roles) &&
            all(x -> x isa Symbol && isvalid(String(x)), allowed) &&
            all(x -> x isa Symbol && isvalid(String(x)), forbidden) &&
            all(x -> x isa OperatorParameterSpecV1, params) &&
            all(g -> g isa Tuple && all(i -> i isa Int && !(i isa Bool), g), groups) ||
            throw(ArgumentError("operator manifest contains a non-canonical value"))
        expected = invoke(_operator_manifest_digest, Tuple{OperatorRefV1,Int,Int,OperatorTypeRuleV1,OperatorTypeRuleV1,Tuple,Tuple,Symbol,UInt8,Bool,Bool,Bool,Bool,Tuple,Bool,Tuple,Tuple}, operator_ref, input_arity, output_arity, input_type_rule, output_type_rule,
            roles, params, locality, max_derivative_contribution, pure, stateful, stochastic, event,
            groups, cse_allowed, allowed, forbidden)
        manifest_hash == expected || throw(ArgumentError("operator manifest hash mismatch"))
        new(operator_ref, manifest_hash, input_arity, output_arity, input_type_rule, output_type_rule, roles,
            params, locality, max_derivative_contribution, pure, stateful, stochastic, event,
            groups, cse_allowed, allowed, forbidden)
    end
end

function _operator_manifest_digest(operator_ref::OperatorRefV1, input_arity::Int, output_arity::Int,
                                   input_type_rule::OperatorTypeRuleV1, output_type_rule::OperatorTypeRuleV1,
                                   allowed_roles, parameter_schema, locality, max_derivative_contribution, pure,
                                   stateful, stochastic, event, commutative_input_groups, cse_allowed,
                                   allowed_conservation_effects, forbidden_conservation_effects)
    io = IOBuffer()
    function quote_string(s::String)
        isvalid(s) || throw(ArgumentError("manifest text must be valid UTF-8"))
        b = IOBuffer(); print(b, '"')
        for c in s
            if c == '"'; print(b, "\\\"")
            elseif c == '\\'; print(b, "\\\\")
            elseif c == '\b'; print(b, "\\b")
            elseif c == '\f'; print(b, "\\f")
            elseif c == '\n'; print(b, "\\n")
            elseif c == '\r'; print(b, "\\r")
            elseif c == '\t'; print(b, "\\t")
            elseif UInt32(c) < 0x20; print(b, "\\u", lpad(string(UInt32(c), base=16), 4, '0'))
            else; print(b, c)
            end
        end
        print(b, '"'); String(take!(b))
    end
    function enc(x)
        x === nothing && return "null"
        x isa Bool && return x ? "true" : "false"
        x isa String && return quote_string(x)
        x isa Symbol && return quote_string(String(x))
        x isa Enum && return quote_string(String(Symbol(x)))
        typeof(x) in _P0_SAFE_INTEGER_TYPES && return string(x)
        typeof(x) === UInt8 && return string(x)
        x isa Rational && return object(("denominator", enc(denominator(x))), ("numerator", enc(numerator(x))))
        x isa QualifiedRefV1 && return object(("id", enc(x.id)), ("version", enc(x.version)))
        x isa OperatorRefV1 && return object(("qualified", enc(x.qualified)))
        x isa UnitSignature && return object(("exponents", enc(x.exponents)))
        x isa TemporalTypeV1 && return object(("clock_ref", enc(x.clock_ref)), ("derivative_order", enc(x.derivative_order)), ("kind", enc(x.kind)))
        x isa PhysicalType && return object(("spatial_dimension", enc(x.spatial_dimension)), ("tensor_rank", enc(x.tensor_rank)),
                                            ("temporal_type", enc(x.temporal_type)), ("units", enc(x.units)), ("value_kind", enc(x.value_kind)))
        x isa OperatorParameterSpecV1 && return object(("name", enc(x.name)), ("required", enc(x.required)), ("type_tag", enc(x.type_tag)))
        typeof(x) === ExactTypeRuleV1 && return object(("input_types", enc(x.input_types)), ("output_types", enc(x.output_types)), ("rule", "\"exact\""))
        typeof(x) === SameTypeVariadicRuleV1 && return object(("maximum_arity", enc(x.maximum_arity)), ("minimum_arity", enc(x.minimum_arity)), ("rule", "\"same_type_variadic\""))
        typeof(x) === ScalarProductRuleV1 && return object(("division", enc(x.division)), ("rule", "\"scalar_product\""))
        typeof(x) === DotProductRuleV1 && return "{\"rule\":\"dot_product\"}"
        typeof(x) === TensorProductRuleV1 && return "{\"rule\":\"tensor_product\"}"
        typeof(x) === ContractRuleV1 && return "{\"rule\":\"contract\"}"
        typeof(x) === SpatialDerivativeRuleV1 && return object(("opcode", enc(x.opcode)), ("rule", "\"spatial_derivative\""))
        typeof(x) === TimeDerivativeRuleV1 && return "{\"rule\":\"time_derivative\"}"
        typeof(x) === SamplingRuleV1 && return object(("hold", enc(x.hold)), ("rule", "\"sampling\""))
        typeof(x) === DelayRuleV1 && return "{\"rule\":\"delay\"}"
        typeof(x) === EventTransitionRuleV1 && return object(("opcode", enc(x.opcode)), ("rule", "\"event_transition\""))
        x isa Tuple && return "[" * join((enc(v) for v in x), ",") * "]"
        throw(ArgumentError("manifest encoder encountered an unsealed value"))
    end
    function object(pairs::Vararg{Tuple{String,String}})
        ordered = sort(collect(pairs), by=first)
        names = first.(ordered)
        length(unique(names)) == length(names) || throw(ArgumentError("manifest object has duplicate keys"))
        "{" * join((quote_string(k) * ":" * v for (k, v) in ordered), ",") * "}"
    end
    payload = object(("allowed_conservation_effects", enc(allowed_conservation_effects)),
        ("allowed_roles", enc(allowed_roles)), ("commutative_input_groups", enc(commutative_input_groups)),
        ("cse_allowed", enc(cse_allowed)), ("domain", quote_string("FusionConceptAI.OperatorManifestV1")),
        ("event", enc(event)), ("forbidden_conservation_effects", enc(forbidden_conservation_effects)),
        ("input_arity", enc(input_arity)), ("input_type_rule", enc(input_type_rule)),
        ("locality", enc(locality)), ("manifest_version", quote_string("1")),
        ("max_derivative_contribution", enc(max_derivative_contribution)), ("operator_ref", enc(operator_ref)),
        ("output_arity", enc(output_arity)), ("output_type_rule", enc(output_type_rule)),
        ("parameter_schema", enc(parameter_schema)), ("pure", enc(pure)), ("stateful", enc(stateful)),
        ("stochastic", enc(stochastic)))
    Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(String(payload))))))
end

function OperatorManifestV1(operator_ref::OperatorRefV1, input_arity::Integer, output_arity::Integer,
                            input_type_rule::OperatorTypeRuleV1, output_type_rule::OperatorTypeRuleV1;
                            allowed_roles=(:governing, :additive, :constraint, :interface), parameter_schema=(),
                            locality::Symbol=:local, max_derivative_contribution::Integer=0, pure::Bool=true,
                            stateful::Bool=false, stochastic::Bool=false, event::Bool=false,
                            commutative_input_groups=(), cse_allowed::Union{Nothing,Bool}=nothing,
                            allowed_conservation_effects=(), forbidden_conservation_effects=(), manifest_hash=nothing)
    typeof(input_arity) in _P0_SAFE_INTEGER_TYPES && typeof(output_arity) in _P0_SAFE_INTEGER_TYPES ||
        throw(ArgumentError("operator arity must use a safe integer type"))
    typemin(Int) <= input_arity <= typemax(Int) && typemin(Int) <= output_arity <= typemax(Int) ||
        throw(ArgumentError("operator arity is out of range"))
    ia, oa = Int(input_arity), Int(output_arity)
    ia >= 0 && oa >= 0 || throw(ArgumentError("operator arity cannot be negative"))
    allowed_roles isa Tuple && parameter_schema isa Tuple && commutative_input_groups isa Tuple &&
        allowed_conservation_effects isa Tuple && forbidden_conservation_effects isa Tuple ||
        throw(ArgumentError("operator manifest collection fields must be tuples"))
    roles, params, groups, allowed, forbidden = invoke(_sealed_normalize_manifest,
        Tuple{Tuple,Tuple,Tuple,Tuple,Tuple,Int}, allowed_roles, parameter_schema,
        commutative_input_groups, allowed_conservation_effects, forbidden_conservation_effects, ia)
    (typeof(input_type_rule) === ExactTypeRuleV1 || typeof(input_type_rule) === SameTypeVariadicRuleV1 ||
     typeof(input_type_rule) === ScalarProductRuleV1 || typeof(input_type_rule) === DotProductRuleV1 ||
     typeof(input_type_rule) === TensorProductRuleV1 || typeof(input_type_rule) === ContractRuleV1 ||
     typeof(input_type_rule) === SpatialDerivativeRuleV1 ||
     typeof(input_type_rule) === TimeDerivativeRuleV1 || typeof(input_type_rule) === SamplingRuleV1 ||
     typeof(input_type_rule) === DelayRuleV1 || typeof(input_type_rule) === EventTransitionRuleV1) &&
    (typeof(output_type_rule) === ExactTypeRuleV1 || typeof(output_type_rule) === SameTypeVariadicRuleV1 ||
     typeof(output_type_rule) === ScalarProductRuleV1 || typeof(output_type_rule) === DotProductRuleV1 ||
     typeof(output_type_rule) === TensorProductRuleV1 || typeof(output_type_rule) === ContractRuleV1 ||
     typeof(output_type_rule) === SpatialDerivativeRuleV1 ||
     typeof(output_type_rule) === TimeDerivativeRuleV1 || typeof(output_type_rule) === SamplingRuleV1 ||
     typeof(output_type_rule) === DelayRuleV1 || typeof(output_type_rule) === EventTransitionRuleV1) ||
        throw(ArgumentError("operator manifest accepts core declarative rules only"))
    typeof(max_derivative_contribution) in _P0_SAFE_INTEGER_TYPES && 0 <= max_derivative_contribution <= 255 ||
        throw(ArgumentError("derivative contribution must fit UInt8"))
    cse = cse_allowed === nothing ? !(stateful || stochastic || event) : cse_allowed
    mh = invoke(_operator_manifest_digest, Tuple{OperatorRefV1,Int,Int,OperatorTypeRuleV1,OperatorTypeRuleV1,Tuple,Tuple,Symbol,UInt8,Bool,Bool,Bool,Bool,Tuple,Bool,Tuple,Tuple}, operator_ref, ia, oa, input_type_rule, output_type_rule,
        roles, params, locality, UInt8(max_derivative_contribution), pure, stateful, stochastic, event, groups,
        cse, allowed, forbidden)
    manifest_hash === nothing || (manifest_hash isa Digest256 && manifest_hash == mh) ||
        throw(ArgumentError("operator manifest hash mismatch"))
    OperatorManifestV1(operator_ref, mh, ia, oa, input_type_rule, output_type_rule,
        roles, params, locality, UInt8(max_derivative_contribution), pure, stateful, stochastic, event, groups,
        cse, allowed, forbidden)
end

semantic_view(x::OperatorManifestV1) = (operator_ref=x.operator_ref, manifest_hash=x.manifest_hash,
    input_arity=x.input_arity, output_arity=x.output_arity, input_type_rule=x.input_type_rule,
    output_type_rule=x.output_type_rule, allowed_roles=x.allowed_roles, parameter_schema=x.parameter_schema,
    locality=x.locality, max_derivative_contribution=x.max_derivative_contribution, pure=x.pure, stateful=x.stateful,
    stochastic=x.stochastic, event=x.event, commutative_input_groups=x.commutative_input_groups,
    cse_allowed=x.cse_allowed, allowed_conservation_effects=x.allowed_conservation_effects,
    forbidden_conservation_effects=x.forbidden_conservation_effects)

struct OperatorRegistryV1
    operators::Tuple{Vararg{OperatorManifestV1}}
    function OperatorRegistryV1(operators=())
        ops = Tuple(operators)
        all(o -> o isa OperatorManifestV1, ops) || throw(ArgumentError("operator registry accepts manifests only"))
        refs = [o.operator_ref.qualified for o in ops]
        length(unique(refs)) == length(refs) || throw(ArgumentError("duplicate operator reference"))
        normalized = Tuple(sort(collect(ops), by=o -> (o.operator_ref.qualified.id, o.operator_ref.qualified.version)))
        # Every element is already a sealed immutable OperatorManifestV1; do not route
        # authority through package-wide extensible value traits here.
        new(normalized)
    end
end
semantic_view(x::OperatorRegistryV1) = (operators=x.operators,)

function register_operator(registry::OperatorRegistryV1, manifest::OperatorManifestV1)
    any(o -> o.operator_ref == manifest.operator_ref, registry.operators) && throw(ArgumentError("duplicate operator reference"))
    OperatorRegistryV1((registry.operators..., manifest))
end

function operator_manifest(registry::OperatorRegistryV1, ref::QualifiedRefV1)
    invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}}, registry, ref.id, ref.version)
end
function operator_manifest(registry::OperatorRegistryV1, id::String, version::Union{Nothing,String}=nothing)
    isvalid(id) && (version === nothing || isvalid(version)) || throw(ArgumentError("operator lookup reference is invalid UTF-8"))
    matches = filter(o -> o.operator_ref.qualified.id == id && (version === nothing || o.operator_ref.qualified.version == version), registry.operators)
    length(matches) == 1 || throw(ArgumentError("operator reference is unknown or ambiguous"))
    only(matches)
end
operator_manifest(::OperatorRegistryV1, ::AbstractString, ::Any=nothing) =
    throw(ArgumentError("operator lookup requires validated String or QualifiedRefV1"))

function _temporal_compatible(a::TemporalTypeV1, b::TemporalTypeV1)
    a == b || (a.kind == static_time && a.derivative_order == 0) || (b.kind == static_time && b.derivative_order == 0)
end

function _validate_rule(rule::ExactTypeRuleV1, inputs, outputs, parameters)
    Tuple(inputs) == rule.input_types && Tuple(outputs) == rule.output_types
end
function _validate_rule(rule::SameTypeVariadicRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(outs) == 1 && length(ins) >= rule.minimum_arity && length(ins) <= rule.maximum_arity &&
        all(t -> t == ins[1], ins) && outs[1] == ins[1]
end
function _validate_rule(rule::ScalarProductRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == 2 && length(outs) == 1 && all(t -> t.tensor_rank == 0, ins) && outs[1].tensor_rank == 0 &&
        outs[1].value_kind == ins[1].value_kind && outs[1].value_kind == ins[2].value_kind &&
        ins[1].spatial_dimension == ins[2].spatial_dimension && outs[1].spatial_dimension == ins[1].spatial_dimension &&
        _temporal_compatible(ins[1].temporal_type, ins[2].temporal_type) &&
        outs[1].temporal_type == (ins[1].temporal_type.kind == static_time ? ins[2].temporal_type : ins[1].temporal_type) &&
        outs[1].units == UnitSignature(ntuple(i -> rule.division ? ins[1].units.exponents[i] - ins[2].units.exponents[i] : ins[1].units.exponents[i] + ins[2].units.exponents[i], 7))
end
function _validate_rule(rule::SpatialDerivativeRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == 1 && length(outs) == 1 && ins[1].spatial_dimension >= 1 &&
        outs[1].spatial_dimension == ins[1].spatial_dimension && outs[1].temporal_type == ins[1].temporal_type &&
        ((rule.opcode == :gradient && ins[1].tensor_rank == 0 && outs[1].tensor_rank == 1 && ins[1].value_kind == :scalar_field && outs[1].value_kind == :vector_field) ||
         (rule.opcode == :divergence && ins[1].tensor_rank >= 1 && outs[1].tensor_rank == ins[1].tensor_rank - 1 && ins[1].value_kind == :vector_field && outs[1].value_kind == :scalar_field) ||
         (rule.opcode == :curl && ins[1].tensor_rank == 1 && outs[1].tensor_rank == 1 && ins[1].spatial_dimension == 3 && ins[1].value_kind == :vector_field && outs[1].value_kind == :vector_field) ||
         (rule.opcode == :laplace && ins[1].tensor_rank == 0 && outs[1].tensor_rank == 0 && ins[1].value_kind == outs[1].value_kind)) &&
        outs[1].units == UnitSignature(ntuple(i -> ins[1].units.exponents[i] -
            (i == 2 ? (rule.opcode == :laplace ? 2 : 1) : 0), 7))
end
function _validate_rule(::TimeDerivativeRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == 1 && length(outs) == 1 && ins[1].temporal_type.kind == differential_time &&
        outs[1].value_kind == ins[1].value_kind && outs[1].tensor_rank == ins[1].tensor_rank &&
        outs[1].spatial_dimension == ins[1].spatial_dimension && outs[1].temporal_type.kind == differential_time &&
        Int(outs[1].temporal_type.derivative_order) == Int(ins[1].temporal_type.derivative_order) + 1 &&
        outs[1].temporal_type.clock_ref == ins[1].temporal_type.clock_ref &&
        outs[1].units == UnitSignature(ntuple(i -> ins[1].units.exponents[i] - (i == 3 ? 1 : 0), 7))
end
function _validate_rule(rule::SamplingRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    target_kind = hasproperty(parameters, :target_kind) ? getproperty(parameters, :target_kind) : nothing
    target_clock = hasproperty(parameters, :target_clock) ? getproperty(parameters, :target_clock) : nothing
    length(ins) == 1 && length(outs) == 1 && ins[1].value_kind == outs[1].value_kind &&
        ins[1].tensor_rank == outs[1].tensor_rank && ins[1].spatial_dimension == outs[1].spatial_dimension &&
        ins[1].units == outs[1].units &&
        ((rule.hold ? ins[1].temporal_type.kind == discrete_time && outs[1].temporal_type.kind in
                        (static_time, algebraic_time, differential_time, event_time) :
                     ins[1].temporal_type.kind in (static_time, algebraic_time, differential_time, event_time) &&
                        outs[1].temporal_type.kind == discrete_time) &&
         (rule.hold ? (target_kind isa Symbol && target_kind == Symbol(outs[1].temporal_type.kind) && target_clock === nothing) :
                      (target_clock isa QualifiedRefV1 && target_clock == outs[1].temporal_type.clock_ref && target_kind === nothing)))
end
function _validate_rule(::DelayRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    delay = hasproperty(parameters, :delay_seconds) ? getproperty(parameters, :delay_seconds) : nothing
    length(ins) == 1 && length(outs) == 1 && ins[1] == outs[1] &&
        ins[1].temporal_type.kind != static_time && delay isa Real &&
        _validate_parameter_value(:finite_nonnegative_real, delay)
end
function _validate_rule(rule::EventTransitionRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    clocks = Tuple(t.temporal_type.clock_ref for t in (ins..., outs...))
    clocked = filter(c -> c !== nothing, clocks)
    same_clock = isempty(clocked) || (length(clocked) == length(clocks) && all(c -> c == first(clocked), clocked))
    length(ins) == 2 && length(outs) == 1 &&
        ins[1].tensor_rank == 0 && ins[1].spatial_dimension == ins[2].spatial_dimension &&
        ins[2] == outs[1] && same_clock &&
        ((rule.opcode == :threshold_switch && ins[1].value_kind == :control_signal &&
          ins[1].temporal_type.kind in (static_time, differential_time, discrete_time)) ||
         (rule.opcode == :event_reset && ins[1].value_kind == :event_signal &&
          ins[1].temporal_type.kind == event_time))
end

"""Sealed rule validator.  The broad signature is always reached with invoke."""
function _sealed_validate_rule(rule::OperatorTypeRuleV1, inputs, outputs, parameters::NamedTuple)
    ins, outs = Tuple(inputs), Tuple(outputs)
    if typeof(rule) === ExactTypeRuleV1
        return ins == rule.input_types && outs == rule.output_types
    elseif typeof(rule) === SameTypeVariadicRuleV1
        return length(outs) == 1 && length(ins) >= rule.minimum_arity && length(ins) <= rule.maximum_arity &&
            !isempty(ins) && all(t -> t == ins[1], ins) && outs[1] == ins[1]
    elseif typeof(rule) === ScalarProductRuleV1
        return length(ins) == 2 && length(outs) == 1 && all(t -> t.tensor_rank == 0, ins) && outs[1].tensor_rank == 0 &&
            outs[1].value_kind == ins[1].value_kind && outs[1].value_kind == ins[2].value_kind &&
            ins[1].spatial_dimension == ins[2].spatial_dimension && outs[1].spatial_dimension == ins[1].spatial_dimension &&
            (ins[1].temporal_type == ins[2].temporal_type ||
             (ins[1].temporal_type.kind == static_time && ins[1].temporal_type.derivative_order == 0) ||
             (ins[2].temporal_type.kind == static_time && ins[2].temporal_type.derivative_order == 0)) &&
            outs[1].temporal_type == (ins[1].temporal_type.kind == static_time ? ins[2].temporal_type : ins[1].temporal_type) &&
            outs[1].units == UnitSignature(ntuple(i -> rule.division ? ins[1].units.exponents[i] - ins[2].units.exponents[i] :
                                                               ins[1].units.exponents[i] + ins[2].units.exponents[i], 7))
    elseif typeof(rule) === DotProductRuleV1 || typeof(rule) === TensorProductRuleV1 || typeof(rule) === ContractRuleV1
        length(ins) == 2 && length(outs) == 1 || return false
        a, b, out = ins[1], ins[2], outs[1]
        temporal_ok = a.temporal_type == b.temporal_type ||
            (a.temporal_type.kind == static_time && a.temporal_type.derivative_order == 0) ||
            (b.temporal_type.kind == static_time && b.temporal_type.derivative_order == 0)
        temporal = a.temporal_type.kind == static_time ? b.temporal_type : a.temporal_type
        rank_ok = if typeof(rule) === DotProductRuleV1
            a.tensor_rank == 1 && b.tensor_rank == 1 && out.tensor_rank == 0
        elseif typeof(rule) === TensorProductRuleV1
            a.tensor_rank <= typemax(Int) - b.tensor_rank && out.tensor_rank == a.tensor_rank + b.tensor_rank
        else
            k = hasproperty(parameters, :contraction_order) ? getproperty(parameters, :contraction_order) : nothing
            k isa Integer && !(k isa Bool) && typeof(k) in _P0_SAFE_INTEGER_TYPES &&
                1 <= k <= min(a.tensor_rank, b.tensor_rank) &&
                (a.tensor_rank - Int(k)) <= typemax(Int) - (b.tensor_rank - Int(k)) &&
                out.tensor_rank == (a.tensor_rank - Int(k)) + (b.tensor_rank - Int(k))
        end
        expected_kind_ok = if typeof(rule) === DotProductRuleV1
            out.value_kind === :scalar_field
        elseif typeof(rule) === ContractRuleV1 && out.tensor_rank == 0
            out.value_kind === :scalar_field
        else
            out.value_kind == a.value_kind
        end
        return a.value_kind == b.value_kind && expected_kind_ok &&
            a.spatial_dimension == b.spatial_dimension && out.spatial_dimension == a.spatial_dimension &&
            temporal_ok && out.temporal_type == temporal && rank_ok &&
            out.units == UnitSignature(ntuple(i -> a.units.exponents[i] + b.units.exponents[i], 7))
    elseif typeof(rule) === SpatialDerivativeRuleV1
        return length(ins) == 1 && length(outs) == 1 && ins[1].spatial_dimension >= 1 &&
            outs[1].spatial_dimension == ins[1].spatial_dimension && outs[1].temporal_type == ins[1].temporal_type &&
            ((rule.opcode == :gradient && ins[1].tensor_rank == 0 && outs[1].tensor_rank == 1 && ins[1].value_kind == :scalar_field && outs[1].value_kind == :vector_field) ||
             (rule.opcode == :divergence && ins[1].tensor_rank >= 1 && outs[1].tensor_rank == ins[1].tensor_rank - 1 && ins[1].value_kind == :vector_field && outs[1].value_kind == :scalar_field) ||
             (rule.opcode == :curl && ins[1].tensor_rank == 1 && outs[1].tensor_rank == 1 && ins[1].spatial_dimension == 3 && ins[1].value_kind == :vector_field && outs[1].value_kind == :vector_field) ||
             (rule.opcode == :laplace && ins[1].tensor_rank == 0 && outs[1].tensor_rank == 0 && ins[1].value_kind == outs[1].value_kind)) &&
            outs[1].units == UnitSignature(ntuple(i -> ins[1].units.exponents[i] -
                (i == 2 ? (rule.opcode == :laplace ? 2 : 1) : 0), 7))
    elseif typeof(rule) === TimeDerivativeRuleV1
        return length(ins) == 1 && length(outs) == 1 && ins[1].temporal_type.kind == differential_time &&
            outs[1].value_kind == ins[1].value_kind && outs[1].tensor_rank == ins[1].tensor_rank &&
            outs[1].spatial_dimension == ins[1].spatial_dimension && outs[1].temporal_type.kind == differential_time &&
            Int(outs[1].temporal_type.derivative_order) == Int(ins[1].temporal_type.derivative_order) + 1 &&
            outs[1].temporal_type.clock_ref == ins[1].temporal_type.clock_ref &&
            outs[1].units == UnitSignature(ntuple(i -> ins[1].units.exponents[i] - (i == 3 ? 1 : 0), 7))
    elseif typeof(rule) === SamplingRuleV1
        target_kind = hasproperty(parameters, :target_kind) ? getproperty(parameters, :target_kind) : nothing
        target_clock = hasproperty(parameters, :target_clock) ? getproperty(parameters, :target_clock) : nothing
        return length(ins) == 1 && length(outs) == 1 && ins[1].value_kind == outs[1].value_kind &&
            ins[1].tensor_rank == outs[1].tensor_rank && ins[1].spatial_dimension == outs[1].spatial_dimension &&
            ins[1].units == outs[1].units &&
            ((rule.hold ? ins[1].temporal_type.kind == discrete_time && outs[1].temporal_type.kind in (static_time, algebraic_time, differential_time, event_time) :
                         ins[1].temporal_type.kind in (static_time, algebraic_time, differential_time, event_time) && outs[1].temporal_type.kind == discrete_time) &&
             (rule.hold ? (target_kind isa Symbol && isvalid(String(target_kind)) && target_kind == Symbol(outs[1].temporal_type.kind) && target_clock === nothing) :
                         (target_clock isa QualifiedRefV1 && target_clock == outs[1].temporal_type.clock_ref && target_kind === nothing)))
    elseif typeof(rule) === DelayRuleV1
        delay = hasproperty(parameters, :delay_seconds) ? getproperty(parameters, :delay_seconds) : nothing
        valid_delay = typeof(delay) in _P0_SAFE_INTEGER_TYPES || typeof(delay) in _P0_SAFE_FLOAT_TYPES ||
            (delay isa Rational && typeof(numerator(delay)) in _P0_SAFE_INTEGER_TYPES &&
             typeof(denominator(delay)) in _P0_SAFE_INTEGER_TYPES)
        value64 = try Float64(delay) catch; NaN end
        valid_delay = valid_delay && !(delay isa Bool) && isfinite(value64) && value64 >= 0
        return length(ins) == 1 && length(outs) == 1 && ins[1] == outs[1] && ins[1].temporal_type.kind != static_time && valid_delay
    elseif typeof(rule) === EventTransitionRuleV1
        clocks = Tuple(t.temporal_type.clock_ref for t in (ins..., outs...))
        clocked = Tuple(c for c in clocks if c !== nothing)
        same_clock = isempty(clocked) || (length(clocked) == length(clocks) && all(c -> c == clocked[1], clocked))
        return length(ins) == 2 && length(outs) == 1 && ins[1].tensor_rank == 0 &&
            ins[1].spatial_dimension == ins[2].spatial_dimension && ins[2] == outs[1] && same_clock &&
            ((rule.opcode == :threshold_switch && ins[1].value_kind == :control_signal && ins[1].temporal_type.kind in (static_time, differential_time, discrete_time)) ||
             (rule.opcode == :event_reset && ins[1].value_kind == :event_signal && ins[1].temporal_type.kind == event_time))
    end
    throw(ArgumentError("operator rule is not sealed"))
end

function _derived_spatial_type(rule::SpatialDerivativeRuleV1, input::PhysicalType)
    delta = rule.opcode == :laplace ? 2 : 1
    kind, rank = input.value_kind, input.tensor_rank
    if rule.opcode == :gradient
        kind, rank = :vector_field, 1
    elseif rule.opcode == :divergence
        kind, rank = :scalar_field, rank - 1
    elseif rule.opcode == :curl
        kind, rank = :vector_field, 1
    end
    PhysicalType(kind, rank, input.spatial_dimension, input.temporal_type,
                 UnitSignature(ntuple(i -> input.units.exponents[i] - (i == 2 ? delta : 0), 7)))
end

function _sealed_infer_outputs(rule::OperatorTypeRuleV1, inputs, parameters)
    if typeof(rule) === ExactTypeRuleV1
        Tuple(inputs) == rule.input_types || throw(ArgumentError("exact operator rule rejected inputs"))
        return rule.output_types
    elseif typeof(rule) === SameTypeVariadicRuleV1
        ins = Tuple(inputs)
        length(ins) >= rule.minimum_arity && length(ins) <= rule.maximum_arity ||
            throw(ArgumentError("variadic operator arity rejected"))
        all(t -> t == ins[1], ins) || throw(ArgumentError("variadic operator requires equal types"))
        return (ins[1],)
    elseif typeof(rule) === ScalarProductRuleV1
        ins = Tuple(inputs)
        length(ins) == 2 || throw(ArgumentError("scalar product requires two inputs"))
        all(t -> t.tensor_rank == 0, ins) || throw(ArgumentError("scalar product requires scalar inputs"))
        (ins[1].temporal_type == ins[2].temporal_type ||
         (ins[1].temporal_type.kind == static_time && ins[1].temporal_type.derivative_order == 0) ||
         (ins[2].temporal_type.kind == static_time && ins[2].temporal_type.derivative_order == 0)) ||
            throw(ArgumentError("scalar product crosses incompatible temporal types"))
        temporal = ins[1].temporal_type.kind == static_time ? ins[2].temporal_type : ins[1].temporal_type
        value_kind = ins[1].value_kind == ins[2].value_kind ? ins[1].value_kind :
            throw(ArgumentError("scalar product requires matching value kinds"))
        return (PhysicalType(value_kind, 0, ins[1].spatial_dimension, temporal,
            UnitSignature(ntuple(i -> rule.division ? ins[1].units.exponents[i] - ins[2].units.exponents[i] :
                                              ins[1].units.exponents[i] + ins[2].units.exponents[i], 7))),)
    elseif typeof(rule) === DotProductRuleV1 || typeof(rule) === TensorProductRuleV1 || typeof(rule) === ContractRuleV1
        ins = Tuple(inputs)
        length(ins) == 2 || throw(ArgumentError("binary tensor operator requires two inputs"))
        a, b = ins[1], ins[2]
        a.value_kind == b.value_kind || throw(ArgumentError("tensor operator requires matching value kinds"))
        a.spatial_dimension == b.spatial_dimension || throw(ArgumentError("tensor operator requires matching spatial dimensions"))
        temporal_ok = a.temporal_type == b.temporal_type ||
            (a.temporal_type.kind == static_time && a.temporal_type.derivative_order == 0) ||
            (b.temporal_type.kind == static_time && b.temporal_type.derivative_order == 0)
        temporal_ok || throw(ArgumentError("tensor operator crosses incompatible temporal types"))
        temporal = a.temporal_type.kind == static_time ? b.temporal_type : a.temporal_type
        rank = if typeof(rule) === DotProductRuleV1
            a.tensor_rank == 1 && b.tensor_rank == 1 || throw(ArgumentError("DOT requires rank-1 operands"))
            0
        elseif typeof(rule) === TensorProductRuleV1
            a.tensor_rank <= typemax(Int) - b.tensor_rank || throw(ArgumentError("TENSOR_PRODUCT rank overflow"))
            a.tensor_rank + b.tensor_rank
        else
            k = hasproperty(parameters, :contraction_order) ? getproperty(parameters, :contraction_order) : nothing
            k isa Integer && !(k isa Bool) && typeof(k) in _P0_SAFE_INTEGER_TYPES ||
                throw(ArgumentError("CONTRACT requires a safe contraction_order"))
            1 <= k <= min(a.tensor_rank, b.tensor_rank) || throw(ArgumentError("CONTRACT order is out of rank bounds"))
            left_rank, right_rank = a.tensor_rank - Int(k), b.tensor_rank - Int(k)
            left_rank <= typemax(Int) - right_rank || throw(ArgumentError("CONTRACT output rank overflow"))
            left_rank + right_rank
        end
        result_kind = (typeof(rule) === DotProductRuleV1 || rank == 0) ? :scalar_field : a.value_kind
        return (PhysicalType(result_kind, rank, a.spatial_dimension, temporal,
            UnitSignature(ntuple(i -> a.units.exponents[i] + b.units.exponents[i], 7))),)
    elseif typeof(rule) === SpatialDerivativeRuleV1
        ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("spatial derivative requires one input"))
        ins[1].spatial_dimension >= 1 || throw(ArgumentError("spatial derivative requires spatial dimension"))
        rule.opcode == :curl && ins[1].spatial_dimension == 3 || rule.opcode != :curl ||
            throw(ArgumentError("curl is defined only in three dimensions"))
        input = ins[1]
        delta = rule.opcode == :laplace ? 2 : 1
        kind, rank = input.value_kind, input.tensor_rank
        if rule.opcode == :gradient
            kind, rank = :vector_field, 1
        elseif rule.opcode == :divergence
            kind, rank = :scalar_field, rank - 1
        elseif rule.opcode == :curl
            kind, rank = :vector_field, 1
        end
        return (PhysicalType(kind, rank, input.spatial_dimension, input.temporal_type,
            UnitSignature(ntuple(i -> input.units.exponents[i] - (i == 2 ? delta : 0), 7))),)
    elseif typeof(rule) === TimeDerivativeRuleV1
        ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("time derivative requires one input"))
        input = ins[1]
        input.temporal_type.kind == differential_time || throw(ArgumentError("DT requires differential time"))
        order = Int(input.temporal_type.derivative_order) + 1
        order <= typemax(UInt8) || throw(ArgumentError("DT derivative order overflow"))
        return (PhysicalType(input.value_kind, input.tensor_rank, input.spatial_dimension,
            TemporalTypeV1(differential_time, order),
            UnitSignature(ntuple(i -> input.units.exponents[i] - (i == 3 ? 1 : 0), 7))),)
    elseif typeof(rule) === SamplingRuleV1
        ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("sampling requires one input"))
        target_kind = hasproperty(parameters, :target_kind) ? getproperty(parameters, :target_kind) : nothing
        target_clock = hasproperty(parameters, :target_clock) ? getproperty(parameters, :target_clock) : nothing
        if rule.hold
            ins[1].temporal_type.kind == discrete_time || throw(ArgumentError("HOLD requires discrete input"))
            target_kind isa Symbol || throw(ArgumentError("HOLD requires explicit target_kind"))
            kind = target_kind == :static_time ? static_time : target_kind == :algebraic_time ? algebraic_time :
                   target_kind == :differential_time ? differential_time : target_kind == :event_time ? event_time :
                   throw(ArgumentError("HOLD target_kind is unsupported"))
            clock = kind == event_time ? ins[1].temporal_type.clock_ref : nothing
            return (PhysicalType(ins[1].value_kind, ins[1].tensor_rank, ins[1].spatial_dimension,
                                 TemporalTypeV1(kind, 0, clock), ins[1].units),)
        end
        ins[1].temporal_type.kind in (static_time, algebraic_time, differential_time, event_time) ||
            throw(ArgumentError("SAMPLE source temporal kind is unsupported"))
        target_clock isa QualifiedRefV1 || throw(ArgumentError("SAMPLE requires explicit target_clock"))
        return (PhysicalType(ins[1].value_kind, ins[1].tensor_rank, ins[1].spatial_dimension,
                             TemporalTypeV1(discrete_time, 0, target_clock), ins[1].units),)
    elseif typeof(rule) === DelayRuleV1
        ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("DELAY requires one input"))
        ins[1].temporal_type.kind != static_time || throw(ArgumentError("DELAY cannot operate on static time"))
        return (ins[1],)
    elseif typeof(rule) === EventTransitionRuleV1
        ins = Tuple(inputs); length(ins) == 2 || throw(ArgumentError("event transition requires two inputs"))
        return (ins[2],)
    end
    throw(ArgumentError("operator rule is not sealed"))
end
function _physical_with_temporal(input::PhysicalType, temporal::TemporalTypeV1, seconds_delta::Integer)
    PhysicalType(input.value_kind, input.tensor_rank, input.spatial_dimension, temporal,
        UnitSignature(ntuple(i -> input.units.exponents[i] + (i == 3 ? seconds_delta : 0), 7)))
end
function _infer_rule_output(rule::SamplingRuleV1, inputs, parameters)
    ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("sampling requires one input"))
    target_kind = hasproperty(parameters, :target_kind) ? getproperty(parameters, :target_kind) : nothing
    target_clock = hasproperty(parameters, :target_clock) ? getproperty(parameters, :target_clock) : nothing
    if rule.hold
        ins[1].temporal_type.kind == discrete_time || throw(ArgumentError("HOLD requires discrete input"))
        target_kind === nothing && throw(ArgumentError("HOLD requires explicit target_kind"))
        kind = target_kind == :static_time ? static_time : target_kind == :algebraic_time ? algebraic_time :
               target_kind == :differential_time ? differential_time : target_kind == :event_time ? event_time :
               throw(ArgumentError("HOLD target_kind is unsupported"))
        clock = kind == event_time ? ins[1].temporal_type.clock_ref : nothing
        return (PhysicalType(ins[1].value_kind, ins[1].tensor_rank, ins[1].spatial_dimension,
                             TemporalTypeV1(kind, 0, clock), ins[1].units),)
    end
    ins[1].temporal_type.kind in (static_time, algebraic_time, differential_time, event_time) ||
        throw(ArgumentError("SAMPLE source temporal kind is unsupported"))
    target_clock isa QualifiedRefV1 || throw(ArgumentError("SAMPLE requires explicit target_clock"))
    (PhysicalType(ins[1].value_kind, ins[1].tensor_rank, ins[1].spatial_dimension,
                  TemporalTypeV1(discrete_time, 0, target_clock), ins[1].units),)
end
function _infer_rule_output(::DelayRuleV1, inputs, parameters)
    ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("DELAY requires one input"))
    ins[1].temporal_type.kind != static_time || throw(ArgumentError("DELAY cannot operate on static time"))
    (ins[1],)
end
function _infer_rule_output(rule::EventTransitionRuleV1, inputs, parameters)
    ins = Tuple(inputs); length(ins) == 2 || throw(ArgumentError("event transition requires two inputs"))
    (ins[2],)
end

function _validate_parameter_value(tag::Symbol, value)
    tag == :finite_nonnegative_real && begin
        value isa Bool && return false
        value isa Real || return false
        typeof(value) in _P0_SAFE_INTEGER_TYPES || typeof(value) in _P0_SAFE_FLOAT_TYPES ||
            _p0_safe_rational(value) || return false
        v = try Float64(value) catch; return false end
        return isfinite(v) && v >= 0
    end
    tag == :finite_real && begin
        value isa Bool && return false
        value isa Real || return false
        typeof(value) in _P0_SAFE_INTEGER_TYPES || typeof(value) in _P0_SAFE_FLOAT_TYPES ||
            _p0_safe_rational(value) || return false
        v = try Float64(value) catch; return false end
        return isfinite(v)
    end
    tag == :qualified_ref && return value isa QualifiedRefV1
    tag == :symbol && return value isa Symbol && isvalid(String(value))
    tag == :nonnegative_integer && begin
        value isa Bool && return false
        return typeof(value) in _P0_SAFE_INTEGER_TYPES && value >= 0
    end
    false
end

function _validate_parameters(manifest::OperatorManifestV1, parameters)
    parameters isa NamedTuple || throw(ArgumentError("operator parameters must be a NamedTuple"))
    names = keys(parameters)
    schema_names = _rule_parameter_names(manifest.parameter_schema)
    all(n -> n in schema_names, names) || throw(ArgumentError("unknown operator parameter"))
    for spec in manifest.parameter_schema
        present = spec.name in names
        spec.required && !present && throw(ArgumentError("required operator parameter is missing"))
        present && _validate_parameter_value(spec.type_tag, getproperty(parameters, spec.name)) ||
            (present && throw(ArgumentError("operator parameter has invalid type or range")))
    end
    deep_immutable(parameters) && is_canonical_value(parameters) ||
        throw(ArgumentError("operator parameters must be immutable/canonical"))
    true
end

function _sealed_validate_parameters(manifest::OperatorManifestV1, parameters::NamedTuple)
    names = keys(parameters)
    schema = manifest.parameter_schema
    schema_names = Tuple(p.name for p in schema)
    all(n -> n in schema_names, names) || throw(ArgumentError("unknown operator parameter"))
    for spec in schema
        present = spec.name in names
        spec.required && !present && throw(ArgumentError("required operator parameter is missing"))
        present || continue
        value = getproperty(parameters, spec.name)
        if spec.type_tag == :finite_nonnegative_real || spec.type_tag == :finite_real
            typeof(value) in _P0_SAFE_INTEGER_TYPES || typeof(value) in _P0_SAFE_FLOAT_TYPES ||
                (value isa Rational && typeof(numerator(value)) in _P0_SAFE_INTEGER_TYPES &&
                 typeof(denominator(value)) in _P0_SAFE_INTEGER_TYPES) ||
                throw(ArgumentError("operator parameter numeric type is not sealed"))
            value isa Bool && throw(ArgumentError("Bool is not a numeric parameter"))
            finite_value = try Float64(value) catch; throw(ArgumentError("operator parameter cannot convert to Float64")) end
            isfinite(finite_value) || throw(ArgumentError("operator parameter must be finite"))
            spec.type_tag == :finite_nonnegative_real && finite_value >= 0 ||
                spec.type_tag == :finite_real || throw(ArgumentError("operator parameter must be non-negative"))
        elseif spec.type_tag == :qualified_ref
            value isa QualifiedRefV1 || throw(ArgumentError("operator parameter requires QualifiedRefV1"))
        elseif spec.type_tag == :symbol
            value isa Symbol && isvalid(String(value)) || throw(ArgumentError("operator parameter requires a valid Symbol"))
        elseif spec.type_tag == :nonnegative_integer
            typeof(value) in _P0_SAFE_INTEGER_TYPES && !(value isa Bool) && value >= 0 ||
                throw(ArgumentError("operator parameter requires a non-negative safe integer"))
        else
            throw(ArgumentError("operator parameter type tag is not sealed"))
        end
    end
    true
end

function validate_operator_signature(registry::OperatorRegistryV1, ref::OperatorRefV1, inputs, outputs; parameters=(;))
    manifest = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}}, registry,
        ref.qualified.id, ref.qualified.version)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == manifest.input_arity && length(outs) == manifest.output_arity || throw(ArgumentError("operator arity mismatch"))
    all(t -> t isa PhysicalType, ins) && all(t -> t isa PhysicalType, outs) ||
        throw(ArgumentError("operator signature requires PhysicalType values"))
    parameters isa NamedTuple || throw(ArgumentError("operator parameters must be a NamedTuple"))
    invoke(_sealed_validate_parameters, Tuple{OperatorManifestV1,NamedTuple}, manifest, parameters)
    expected_outputs = invoke(_sealed_infer_outputs, Tuple{OperatorTypeRuleV1,Any,Any}, manifest.input_type_rule, ins, parameters)
    expected_outputs == outs || throw(ArgumentError("operator output does not match sealed rule inference"))
    invoke(_sealed_validate_rule, Tuple{OperatorTypeRuleV1,Any,Any,NamedTuple}, manifest.input_type_rule, ins, outs, parameters) ||
        throw(ArgumentError("operator input type rule rejected signature"))
    manifest.output_type_rule === manifest.input_type_rule ||
        invoke(_sealed_validate_rule, Tuple{OperatorTypeRuleV1,Any,Any,NamedTuple}, manifest.output_type_rule, ins, outs, parameters) ||
        throw(ArgumentError("operator output type rule rejected signature"))
    true
end

function _default_manifest(id, arity, rule; output_arity=1, kwargs...)
    r = OperatorRefV1(id, "v1")
    OperatorManifestV1(r, arity, output_arity, rule, rule; kwargs...)
end

function default_operator_registry()
    manifests = OperatorManifestV1[]
    make_default = (id, arity, rule; kwargs...) ->
        invoke(_default_manifest, Tuple{Any,Any,OperatorTypeRuleV1}, id, arity, rule; kwargs...)
    push!(manifests, make_default("IDENTITY", 1, SameTypeVariadicRuleV1(1, 1)))
    push!(manifests, make_default("ADD", 2, SameTypeVariadicRuleV1(2, 2), commutative_input_groups=((1, 2),)))
    push!(manifests, make_default("SUB", 2, SameTypeVariadicRuleV1(2, 2)))
    push!(manifests, make_default("NEG", 1, SameTypeVariadicRuleV1(1, 1)))
    push!(manifests, make_default("SCALAR_MUL", 2, ScalarProductRuleV1()))
    push!(manifests, make_default("SCALAR_DIV", 2, ScalarProductRuleV1(true)))
    push!(manifests, make_default("CONTRACT", 2, ContractRuleV1(),
        parameter_schema=(OperatorParameterSpecV1(:contraction_order, :nonnegative_integer, true),)))
    push!(manifests, make_default("DOT", 2, DotProductRuleV1()))
    push!(manifests, make_default("TENSOR_PRODUCT", 2, TensorProductRuleV1()))
    push!(manifests, make_default("DT", 1, TimeDerivativeRuleV1(), max_derivative_contribution=1))
    push!(manifests, make_default("GRAD", 1, SpatialDerivativeRuleV1(:gradient), max_derivative_contribution=1))
    push!(manifests, make_default("DIV_OP", 1, SpatialDerivativeRuleV1(:divergence), max_derivative_contribution=1))
    push!(manifests, make_default("CURL", 1, SpatialDerivativeRuleV1(:curl), max_derivative_contribution=1))
    push!(manifests, make_default("LAPLACE", 1, SpatialDerivativeRuleV1(:laplace), max_derivative_contribution=2))
    # INTEGRAL_KERNEL is intentionally not registered until a typed kernel contract exists.
    push!(manifests, make_default("DELAY", 1, DelayRuleV1(), pure=false, stateful=true, parameter_schema=(OperatorParameterSpecV1(:delay_seconds, :finite_nonnegative_real, true),)))
    push!(manifests, make_default("SAMPLE", 1, SamplingRuleV1(false), pure=false, stateful=true,
        parameter_schema=(OperatorParameterSpecV1(:target_clock, :qualified_ref, true),)))
    push!(manifests, make_default("HOLD", 1, SamplingRuleV1(true), pure=false, stateful=true,
        parameter_schema=(OperatorParameterSpecV1(:target_kind, :symbol, true),)))
    push!(manifests, make_default("THRESHOLD_SWITCH", 2, EventTransitionRuleV1(:threshold_switch), pure=false, event=true))
    push!(manifests, make_default("EVENT_RESET", 2, EventTransitionRuleV1(:event_reset), pure=false, event=true))
    push!(manifests, make_default("ALGEBRAIC_CONSTRAINT", 1, SameTypeVariadicRuleV1(1, 1)))
    OperatorRegistryV1(tuple(manifests...))
end
