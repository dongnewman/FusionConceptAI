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
        _checked_int(minimum_arity, "minimum arity") >= 0 || throw(ArgumentError("invalid variadic rule arity"))
        lo, hi = _checked_int(minimum_arity, "minimum arity"), _checked_int(maximum_arity, "maximum arity")
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
        all(i -> i isa Integer && 1 <= i <= input_arity, g) ||
            throw(ArgumentError("commutative input index is out of range"))
        length(g) >= 2 || throw(ArgumentError("commutative groups require at least two inputs"))
        length(unique(g)) == length(g) || throw(ArgumentError("commutative group contains duplicates"))
        any(i -> i in used, g) && throw(ArgumentError("commutative groups overlap"))
        union!(used, Int.(g))
        push!(normalized, Tuple(sort(collect(Int.(g)))))
    end
    Tuple(sort(normalized, by=repr))
end

function _rule_derivative_contribution(rule)
    rule isa SpatialDerivativeRuleV1 && return rule.opcode == :laplace ? 2 : 1
    rule isa TimeDerivativeRuleV1 && return 1
    0
end

function _rule_event(rule)
    rule isa EventTransitionRuleV1
end

function _rule_parameter_names(schema)
    names = Tuple(p.name for p in schema)
    length(unique(names)) == length(names) || throw(ArgumentError("parameter schema has duplicate names"))
    all(p -> p isa OperatorParameterSpecV1 && p.type_tag in _OPERATOR_PARAMETER_TAGS, schema) ||
        throw(ArgumentError("parameter schema contains an unknown type tag"))
    names
end

function _sealed_rule_arity(rule, input_arity::Int, output_arity::Int)
    if typeof(rule) === ExactTypeRuleV1
        return input_arity == length(rule.input_types) && output_arity == length(rule.output_types)
    elseif typeof(rule) === SameTypeVariadicRuleV1
        return rule.minimum_arity <= input_arity <= rule.maximum_arity && output_arity == 1
    elseif typeof(rule) === ScalarProductRuleV1 || typeof(rule) === EventTransitionRuleV1
        return input_arity == 2 && output_arity == 1
    elseif typeof(rule) === SpatialDerivativeRuleV1 || typeof(rule) === TimeDerivativeRuleV1 ||
           typeof(rule) === SamplingRuleV1 || typeof(rule) === DelayRuleV1
        return input_arity == 1 && output_arity == 1
    end
    false
end

function _sealed_rule_schema(rule)
    if typeof(rule) === DelayRuleV1
        (OperatorParameterSpecV1(:delay_seconds, :finite_nonnegative_real, true),)
    elseif typeof(rule) === SamplingRuleV1
        rule.hold ? (OperatorParameterSpecV1(:target_kind, :symbol, true),) :
            (OperatorParameterSpecV1(:target_clock, :qualified_ref, true),)
    else
        ()
    end
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
         typeof(input_type_rule) === ScalarProductRuleV1 || typeof(input_type_rule) === SpatialDerivativeRuleV1 ||
         typeof(input_type_rule) === TimeDerivativeRuleV1 || typeof(input_type_rule) === SamplingRuleV1 ||
         typeof(input_type_rule) === DelayRuleV1 || typeof(input_type_rule) === EventTransitionRuleV1) &&
        (typeof(output_type_rule) === ExactTypeRuleV1 || typeof(output_type_rule) === SameTypeVariadicRuleV1 ||
         typeof(output_type_rule) === ScalarProductRuleV1 || typeof(output_type_rule) === SpatialDerivativeRuleV1 ||
         typeof(output_type_rule) === TimeDerivativeRuleV1 || typeof(output_type_rule) === SamplingRuleV1 ||
         typeof(output_type_rule) === DelayRuleV1 || typeof(output_type_rule) === EventTransitionRuleV1) ||
            throw(ArgumentError("operator manifest accepts core declarative rules only"))
        roles = _normalize_symbol_set(allowed_roles, "allowed roles"; whitelist=_OPERATOR_ROLE_SET, nonempty=true)
        allowed = _normalize_symbol_set(allowed_conservation_effects, "allowed conservation effects")
        forbidden = _normalize_symbol_set(forbidden_conservation_effects, "forbidden conservation effects")
        isempty(intersect(Set(allowed), Set(forbidden))) ||
            throw(ArgumentError("allowed and forbidden conservation effects overlap"))
        params = _tuple_or_argument(parameter_schema, "parameter schema")
        all(p -> p isa OperatorParameterSpecV1, params) || throw(ArgumentError("parameter schema elements must be typed"))
        params = Tuple(sort(collect(params), by=p -> String(p.name)))
        _rule_parameter_names(params)
        groups = _normalize_groups(commutative_input_groups, input_arity)
        locality in _OPERATOR_LOCALITIES || throw(ArgumentError("operator locality is not in the closed vocabulary"))
        input_arity == _checked_int(input_arity, "input arity") && output_arity == _checked_int(output_arity, "output arity") ||
            throw(ArgumentError("operator arity is out of range"))
        _sealed_rule_arity(input_type_rule, input_arity, output_arity) &&
            _sealed_rule_arity(output_type_rule, input_arity, output_arity) ||
            throw(ArgumentError("manifest arity does not match its sealed type rule"))
        params == _sealed_rule_schema(input_type_rule) && params == _sealed_rule_schema(output_type_rule) ||
            throw(ArgumentError("manifest parameter schema is not rule-derived"))
        max_derivative_contribution == _rule_derivative_contribution(input_type_rule) ==
            _rule_derivative_contribution(output_type_rule) ||
            throw(ArgumentError("max derivative contribution is not rule-derived"))
        event == _rule_event(input_type_rule) && event == _rule_event(output_type_rule) ||
            throw(ArgumentError("event metadata is inconsistent with type rule"))
        pure == !(stateful || stochastic || event) ||
            throw(ArgumentError("pure metadata is inconsistent with operator effects"))
        cse_allowed == !(stateful || stochastic || event) ||
            throw(ArgumentError("CSE permission is inconsistent with stateful/event metadata"))
        all(_is_canonical_registry_value, (operator_ref, input_type_rule, output_type_rule, roles, params,
                                            groups, allowed, forbidden)) ||
            throw(ArgumentError("operator manifest contains a non-canonical value"))
        expected = _operator_manifest_digest(operator_ref, input_arity, output_arity, input_type_rule, output_type_rule,
            roles, params, locality, max_derivative_contribution, pure, stateful, stochastic, event,
            groups, cse_allowed, allowed, forbidden)
        manifest_hash == expected || throw(ArgumentError("operator manifest hash mismatch"))
        new(operator_ref, manifest_hash, input_arity, output_arity, input_type_rule, output_type_rule, roles,
            params, locality, max_derivative_contribution, pure, stateful, stochastic, event,
            groups, cse_allowed, allowed, forbidden)
    end
end

function _is_canonical_registry_value(x)
    x isa OperatorManifestV1 && return false
    is_canonical_value(x)
end

function _operator_manifest_digest(operator_ref, input_arity, output_arity, input_type_rule, output_type_rule,
                                   allowed_roles, parameter_schema, locality, max_derivative_contribution, pure,
                                   stateful, stochastic, event, commutative_input_groups, cse_allowed,
                                   allowed_conservation_effects, forbidden_conservation_effects)
    payload = (domain="FusionConceptAI.OperatorManifestV1", version="1", operator_ref=operator_ref,
        input_arity=input_arity, output_arity=output_arity, input_type_rule=input_type_rule,
        output_type_rule=output_type_rule, allowed_roles=allowed_roles, parameter_schema=parameter_schema,
        locality=locality, max_derivative_contribution=max_derivative_contribution, pure=pure,
        stateful=stateful, stochastic=stochastic, event=event,
        commutative_input_groups=commutative_input_groups, cse_allowed=cse_allowed,
        allowed_conservation_effects=allowed_conservation_effects,
        forbidden_conservation_effects=forbidden_conservation_effects)
    digest256_text(canonical_json(payload))
end

function OperatorManifestV1(operator_ref::OperatorRefV1, input_arity::Integer, output_arity::Integer,
                            input_type_rule::OperatorTypeRuleV1, output_type_rule::OperatorTypeRuleV1;
                            allowed_roles=(:governing, :additive, :constraint, :interface), parameter_schema=(),
                            locality::Symbol=:local, max_derivative_contribution::Integer=0, pure::Bool=true,
                            stateful::Bool=false, stochastic::Bool=false, event::Bool=false,
                            commutative_input_groups=(), cse_allowed::Union{Nothing,Bool}=nothing,
                            allowed_conservation_effects=(), forbidden_conservation_effects=(), manifest_hash=nothing)
    ia, oa = _checked_int(input_arity, "input arity"), _checked_int(output_arity, "output arity")
    ia >= 0 && oa >= 0 || throw(ArgumentError("operator arity cannot be negative"))
    roles = _normalize_symbol_set(allowed_roles, "allowed roles"; whitelist=_OPERATOR_ROLE_SET, nonempty=true)
    params = _tuple_or_argument(parameter_schema, "parameter schema")
    all(p -> p isa OperatorParameterSpecV1, params) || throw(ArgumentError("parameter schema elements must be typed"))
    params = Tuple(sort(collect(params), by=p -> String(p.name)))
    groups = _normalize_groups(commutative_input_groups, ia)
    allowed = _normalize_symbol_set(allowed_conservation_effects, "allowed conservation effects")
    forbidden = _normalize_symbol_set(forbidden_conservation_effects, "forbidden conservation effects")
    _rule_parameter_names(params)
    (typeof(input_type_rule) === ExactTypeRuleV1 || typeof(input_type_rule) === SameTypeVariadicRuleV1 ||
     typeof(input_type_rule) === ScalarProductRuleV1 || typeof(input_type_rule) === SpatialDerivativeRuleV1 ||
     typeof(input_type_rule) === TimeDerivativeRuleV1 || typeof(input_type_rule) === SamplingRuleV1 ||
     typeof(input_type_rule) === DelayRuleV1 || typeof(input_type_rule) === EventTransitionRuleV1) &&
    (typeof(output_type_rule) === ExactTypeRuleV1 || typeof(output_type_rule) === SameTypeVariadicRuleV1 ||
     typeof(output_type_rule) === ScalarProductRuleV1 || typeof(output_type_rule) === SpatialDerivativeRuleV1 ||
     typeof(output_type_rule) === TimeDerivativeRuleV1 || typeof(output_type_rule) === SamplingRuleV1 ||
     typeof(output_type_rule) === DelayRuleV1 || typeof(output_type_rule) === EventTransitionRuleV1) ||
        throw(ArgumentError("operator manifest accepts core declarative rules only"))
    max_derivative_contribution isa Bool && throw(ArgumentError("derivative contribution must be an integer"))
    max_derivative_contribution isa Integer && 0 <= max_derivative_contribution <= 255 ||
        throw(ArgumentError("derivative contribution must fit UInt8"))
    cse = cse_allowed === nothing ? !(stateful || stochastic || event) : cse_allowed
    mh = _operator_manifest_digest(operator_ref, ia, oa, input_type_rule, output_type_rule,
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
        deep_immutable(normalized) && is_canonical_value(normalized) || throw(ArgumentError("operator registry must be immutable/canonical"))
        new(normalized)
    end
end
semantic_view(x::OperatorRegistryV1) = (operators=x.operators,)

function register_operator(registry::OperatorRegistryV1, manifest::OperatorManifestV1)
    any(o -> o.operator_ref == manifest.operator_ref, registry.operators) && throw(ArgumentError("duplicate operator reference"))
    OperatorRegistryV1((registry.operators..., manifest))
end

function operator_manifest(registry::OperatorRegistryV1, ref::QualifiedRefV1)
    operator_manifest(registry, ref.id, ref.version)
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

function _infer_rule_output(rule::ExactTypeRuleV1, inputs, parameters)
    Tuple(inputs) == rule.input_types || throw(ArgumentError("exact operator rule rejected inputs"))
    rule.output_types
end
function _infer_rule_output(rule::SameTypeVariadicRuleV1, inputs, parameters)
    ins = Tuple(inputs)
    length(ins) >= rule.minimum_arity && length(ins) <= rule.maximum_arity ||
        throw(ArgumentError("variadic operator arity rejected"))
    all(t -> t == ins[1], ins) || throw(ArgumentError("variadic operator requires equal types"))
    (ins[1],)
end
function _infer_rule_output(rule::ScalarProductRuleV1, inputs, parameters)
    ins = Tuple(inputs)
    length(ins) == 2 || throw(ArgumentError("scalar product requires two inputs"))
    all(t -> t.tensor_rank == 0, ins) || throw(ArgumentError("scalar product requires scalar inputs"))
    _temporal_compatible(ins[1].temporal_type, ins[2].temporal_type) ||
        throw(ArgumentError("scalar product crosses incompatible temporal types"))
    temporal = ins[1].temporal_type.kind == static_time ? ins[2].temporal_type : ins[1].temporal_type
    value_kind = ins[1].value_kind == ins[2].value_kind ? ins[1].value_kind :
        throw(ArgumentError("scalar product requires matching value kinds"))
    (PhysicalType(value_kind, 0, ins[1].spatial_dimension, temporal,
                  UnitSignature(ntuple(i -> rule.division ? ins[1].units.exponents[i] - ins[2].units.exponents[i] :
                                                    ins[1].units.exponents[i] + ins[2].units.exponents[i], 7))),)
end
function _infer_rule_output(rule::SpatialDerivativeRuleV1, inputs, parameters)
    ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("spatial derivative requires one input"))
    ins[1].spatial_dimension >= 1 || throw(ArgumentError("spatial derivative requires spatial dimension"))
    rule.opcode == :curl && ins[1].spatial_dimension == 3 || rule.opcode != :curl ||
        throw(ArgumentError("curl is defined only in three dimensions"))
    (_derived_spatial_type(rule, ins[1]),)
end
function _infer_rule_output(::TimeDerivativeRuleV1, inputs, parameters)
    ins = Tuple(inputs); length(ins) == 1 || throw(ArgumentError("time derivative requires one input"))
    input = ins[1]
    input.temporal_type.kind == differential_time || throw(ArgumentError("DT requires differential time"))
    order = Int(input.temporal_type.derivative_order) + 1
    order <= typemax(UInt8) || throw(ArgumentError("DT derivative order overflow"))
    (_physical_with_temporal(input, TemporalTypeV1(differential_time, order), -1),)
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
    tag == :symbol && return value isa Symbol
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

function validate_operator_signature(registry::OperatorRegistryV1, ref::OperatorRefV1, inputs, outputs; parameters=(;))
    manifest = operator_manifest(registry, ref.qualified.id, ref.qualified.version)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == manifest.input_arity && length(outs) == manifest.output_arity || throw(ArgumentError("operator arity mismatch"))
    all(t -> t isa PhysicalType, ins) && all(t -> t isa PhysicalType, outs) ||
        throw(ArgumentError("operator signature requires PhysicalType values"))
    _validate_parameters(manifest, parameters)
    expected_outputs = _infer_rule_output(manifest.input_type_rule, ins, parameters)
    expected_outputs == outs || throw(ArgumentError("operator output does not match sealed rule inference"))
    _validate_rule(manifest.input_type_rule, ins, outs, parameters) || throw(ArgumentError("operator input type rule rejected signature"))
    manifest.output_type_rule === manifest.input_type_rule || _validate_rule(manifest.output_type_rule, ins, outs, parameters) || throw(ArgumentError("operator output type rule rejected signature"))
    true
end

function _default_manifest(id, arity, rule; output_arity=1, kwargs...)
    r = OperatorRefV1(id, "v1")
    OperatorManifestV1(r, arity, output_arity, rule, rule; kwargs...)
end

function default_operator_registry()
    manifests = OperatorManifestV1[]
    push!(manifests, _default_manifest("IDENTITY", 1, SameTypeVariadicRuleV1(1, 1)))
    push!(manifests, _default_manifest("ADD", 2, SameTypeVariadicRuleV1(2, 2), commutative_input_groups=((1, 2),)))
    push!(manifests, _default_manifest("SUB", 2, SameTypeVariadicRuleV1(2, 2)))
    push!(manifests, _default_manifest("NEG", 1, SameTypeVariadicRuleV1(1, 1)))
    push!(manifests, _default_manifest("SCALAR_MUL", 2, ScalarProductRuleV1()))
    push!(manifests, _default_manifest("SCALAR_DIV", 2, ScalarProductRuleV1(true)))
    push!(manifests, _default_manifest("CONTRACT", 2, SameTypeVariadicRuleV1(2, 2)))
    push!(manifests, _default_manifest("DOT", 2, SameTypeVariadicRuleV1(2, 2)))
    push!(manifests, _default_manifest("TENSOR_PRODUCT", 2, SameTypeVariadicRuleV1(2, 2)))
    push!(manifests, _default_manifest("DT", 1, TimeDerivativeRuleV1(), max_derivative_contribution=1))
    push!(manifests, _default_manifest("GRAD", 1, SpatialDerivativeRuleV1(:gradient), max_derivative_contribution=1))
    push!(manifests, _default_manifest("DIV_OP", 1, SpatialDerivativeRuleV1(:divergence), max_derivative_contribution=1))
    push!(manifests, _default_manifest("CURL", 1, SpatialDerivativeRuleV1(:curl), max_derivative_contribution=1))
    push!(manifests, _default_manifest("LAPLACE", 1, SpatialDerivativeRuleV1(:laplace), max_derivative_contribution=2))
    push!(manifests, _default_manifest("INTEGRAL_KERNEL", 1, SameTypeVariadicRuleV1(1, 1), pure=false, stateful=true))
    push!(manifests, _default_manifest("DELAY", 1, DelayRuleV1(), pure=false, stateful=true, parameter_schema=(OperatorParameterSpecV1(:delay_seconds, :finite_nonnegative_real, true),)))
    push!(manifests, _default_manifest("SAMPLE", 1, SamplingRuleV1(false), pure=false, stateful=true,
        parameter_schema=(OperatorParameterSpecV1(:target_clock, :qualified_ref, true),)))
    push!(manifests, _default_manifest("HOLD", 1, SamplingRuleV1(true), pure=false, stateful=true,
        parameter_schema=(OperatorParameterSpecV1(:target_kind, :symbol, true),)))
    push!(manifests, _default_manifest("THRESHOLD_SWITCH", 2, EventTransitionRuleV1(:threshold_switch), pure=false, event=true))
    push!(manifests, _default_manifest("EVENT_RESET", 2, EventTransitionRuleV1(:event_reset), pure=false, event=true))
    push!(manifests, _default_manifest("ALGEBRAIC_CONSTRAINT", 1, SameTypeVariadicRuleV1(1, 1)))
    OperatorRegistryV1(tuple(manifests...))
end
