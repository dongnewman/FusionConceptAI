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
        0 <= minimum_arity <= maximum_arity || throw(ArgumentError("invalid variadic rule arity"))
        new(Int(minimum_arity), Int(maximum_arity))
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

semantic_view(x::OperatorRefV1) = (qualified=x.qualified,)
semantic_view(x::OperatorParameterSpecV1) = (name=x.name, type_tag=x.type_tag, required=x.required)
semantic_view(x::ExactTypeRuleV1) = (input_types=x.input_types, output_types=x.output_types)
semantic_view(x::SameTypeVariadicRuleV1) = (minimum_arity=x.minimum_arity, maximum_arity=x.maximum_arity)
semantic_view(x::ScalarProductRuleV1) = (division=x.division,)
semantic_view(x::SpatialDerivativeRuleV1) = (opcode=x.opcode,)
semantic_view(::TimeDerivativeRuleV1) = (rule=:time_derivative,)
semantic_view(x::SamplingRuleV1) = (hold=x.hold,)
semantic_view(::DelayRuleV1) = (rule=:delay,)
Base.:(==)(a::OperatorRefV1, b::OperatorRefV1) = a.qualified == b.qualified
Base.hash(a::QualifiedRefV1, h::UInt) = hash((a.id, a.version), h)
Base.hash(a::OperatorRefV1, h::UInt) = hash(a.qualified, h)

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
    function OperatorManifestV1(operator_ref::OperatorRefV1, manifest_hash::Digest256, input_arity::Int, output_arity::Int,
                                input_type_rule::OperatorTypeRuleV1, output_type_rule::OperatorTypeRuleV1,
                                allowed_roles::Tuple{Vararg{Symbol}}, parameter_schema::Tuple{Vararg{OperatorParameterSpecV1}},
                                locality::Symbol, max_derivative_contribution::UInt8, pure::Bool, stateful::Bool,
                                stochastic::Bool, event::Bool, commutative_input_groups::Tuple,
                                cse_allowed::Bool, allowed_conservation_effects::Tuple{Vararg{Symbol}},
                                forbidden_conservation_effects::Tuple{Vararg{Symbol}})
        input_arity >= 0 && output_arity >= 0 || throw(ArgumentError("operator arity cannot be negative"))
        all(g -> g isa Tuple && all(i -> i isa Integer && i >= 1, g), commutative_input_groups) ||
            throw(ArgumentError("commutative input groups must be typed index tuples"))
        all(_is_canonical_registry_value, (operator_ref, input_type_rule, output_type_rule, allowed_roles, parameter_schema,
                                            commutative_input_groups, allowed_conservation_effects, forbidden_conservation_effects)) ||
            throw(ArgumentError("operator manifest contains a non-canonical value"))
        expected = _operator_manifest_digest(operator_ref, input_arity, output_arity, input_type_rule, output_type_rule,
            allowed_roles, parameter_schema, locality, max_derivative_contribution, pure, stateful, stochastic, event,
            commutative_input_groups, cse_allowed, allowed_conservation_effects, forbidden_conservation_effects)
        manifest_hash == expected || throw(ArgumentError("operator manifest hash mismatch"))
        new(operator_ref, manifest_hash, input_arity, output_arity, input_type_rule, output_type_rule, allowed_roles,
            parameter_schema, locality, max_derivative_contribution, pure, stateful, stochastic, event,
            commutative_input_groups, cse_allowed, allowed_conservation_effects, forbidden_conservation_effects)
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
    digest256_text(repr((operator_ref, input_arity, output_arity, input_type_rule, output_type_rule, allowed_roles,
                         parameter_schema, locality, max_derivative_contribution, pure, stateful, stochastic, event,
                         commutative_input_groups, cse_allowed, allowed_conservation_effects, forbidden_conservation_effects)))
end

function OperatorManifestV1(operator_ref::OperatorRefV1, input_arity::Integer, output_arity::Integer,
                            input_type_rule::OperatorTypeRuleV1, output_type_rule::OperatorTypeRuleV1;
                            allowed_roles=(:governing, :additive, :constraint, :interface), parameter_schema=(),
                            locality::Symbol=:local, max_derivative_contribution::Integer=0, pure::Bool=true,
                            stateful::Bool=false, stochastic::Bool=false, event::Bool=false,
                            commutative_input_groups=(), cse_allowed::Bool=true,
                            allowed_conservation_effects=(), forbidden_conservation_effects=(), manifest_hash=nothing)
    roles = Tuple(Symbol(r) for r in allowed_roles)
    params = Tuple(parameter_schema)
    groups = Tuple(Tuple(Int(i) for i in g) for g in commutative_input_groups)
    allowed = Tuple(Symbol(x) for x in allowed_conservation_effects)
    forbidden = Tuple(Symbol(x) for x in forbidden_conservation_effects)
    max_derivative_contribution in 0:255 || throw(ArgumentError("derivative contribution must fit UInt8"))
    mh = _operator_manifest_digest(operator_ref, Int(input_arity), Int(output_arity), input_type_rule, output_type_rule,
        roles, params, locality, UInt8(max_derivative_contribution), pure, stateful, stochastic, event, groups,
        cse_allowed, allowed, forbidden)
    manifest_hash === nothing || (manifest_hash isa Digest256 && manifest_hash == mh) ||
        throw(ArgumentError("operator manifest hash mismatch"))
    OperatorManifestV1(operator_ref, mh, Int(input_arity), Int(output_arity), input_type_rule, output_type_rule,
        roles, params, locality, UInt8(max_derivative_contribution), pure, stateful, stochastic, event, groups,
        cse_allowed, allowed, forbidden)
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
        deep_immutable(ops) && is_canonical_value(ops) || throw(ArgumentError("operator registry must be immutable/canonical"))
        new(ops)
    end
end
semantic_view(x::OperatorRegistryV1) = (operators=x.operators,)

function register_operator(registry::OperatorRegistryV1, manifest::OperatorManifestV1)
    any(o -> o.operator_ref == manifest.operator_ref, registry.operators) && throw(ArgumentError("duplicate operator reference"))
    OperatorRegistryV1((registry.operators..., manifest))
end

function operator_manifest(registry::OperatorRegistryV1, id::AbstractString, version=nothing)
    matches = filter(o -> o.operator_ref.qualified.id == id && (version === nothing || o.operator_ref.qualified.version == version), registry.operators)
    length(matches) == 1 || throw(ArgumentError("operator reference is unknown or ambiguous"))
    only(matches)
end

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
        outs[1].units == UnitSignature(ntuple(i -> ins[1].units.exponents[i] - (i == 2 ? 1 : 0), 7))
end
function _validate_rule(::TimeDerivativeRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == 1 && length(outs) == 1 && ins[1].temporal_type.kind == differential_time &&
        outs[1].value_kind == ins[1].value_kind && outs[1].tensor_rank == ins[1].tensor_rank &&
        outs[1].spatial_dimension == ins[1].spatial_dimension && outs[1].temporal_type.kind == differential_time &&
        outs[1].temporal_type.derivative_order == ins[1].temporal_type.derivative_order + 1 &&
        outs[1].temporal_type.clock_ref == ins[1].temporal_type.clock_ref &&
        outs[1].units == UnitSignature(ntuple(i -> ins[1].units.exponents[i] - (i == 3 ? 1 : 0), 7))
end
function _validate_rule(rule::SamplingRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == 1 && length(outs) == 1 && ins[1].value_kind == outs[1].value_kind &&
        ins[1].tensor_rank == outs[1].tensor_rank && ins[1].spatial_dimension == outs[1].spatial_dimension &&
        ins[1].units == outs[1].units && ins[1].temporal_type.clock_ref == outs[1].temporal_type.clock_ref &&
        (rule.hold ? ins[1].temporal_type.kind == discrete_time && outs[1].temporal_type.kind != discrete_time :
                    ins[1].temporal_type.kind != discrete_time && outs[1].temporal_type.kind == discrete_time)
end
function _validate_rule(::DelayRuleV1, inputs, outputs, parameters)
    ins, outs = Tuple(inputs), Tuple(outputs)
    delay = hasproperty(parameters, :delay_seconds) ? getproperty(parameters, :delay_seconds) : nothing
    length(ins) == 1 && length(outs) == 1 && ins[1] == outs[1] && delay isa Real && isfinite(Float64(delay)) && Float64(delay) >= 0
end

function validate_operator_signature(registry::OperatorRegistryV1, ref::OperatorRefV1, inputs, outputs; parameters=(;))
    manifest = operator_manifest(registry, ref.qualified.id, ref.qualified.version)
    ins, outs = Tuple(inputs), Tuple(outputs)
    length(ins) == manifest.input_arity && length(outs) == manifest.output_arity || throw(ArgumentError("operator arity mismatch"))
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
    push!(manifests, _default_manifest("INTEGRAL_KERNEL", 1, SameTypeVariadicRuleV1(1, 1), stateful=true))
    push!(manifests, _default_manifest("DELAY", 1, DelayRuleV1(), stateful=true, parameter_schema=(OperatorParameterSpecV1(:delay_seconds, :finite_nonnegative_real, true),)))
    push!(manifests, _default_manifest("SAMPLE", 1, SamplingRuleV1(false), pure=false, stateful=true))
    push!(manifests, _default_manifest("HOLD", 1, SamplingRuleV1(true), pure=false, stateful=true))
    push!(manifests, _default_manifest("THRESHOLD_SWITCH", 2, SameTypeVariadicRuleV1(2, 2), pure=false, event=true))
    push!(manifests, _default_manifest("EVENT_RESET", 2, SameTypeVariadicRuleV1(2, 2), pure=false, event=true))
    push!(manifests, _default_manifest("ALGEBRAIC_CONSTRAINT", 1, SameTypeVariadicRuleV1(1, 1)))
    OperatorRegistryV1(tuple(manifests...))
end
