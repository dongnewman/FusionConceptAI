"""Stable, thin API facade for the frozen RuntimeV4 bounded linear step.

Load `SpatialBoundedLinearStepV1.jl` in the containing module before including
this file.  The facade contains no numerical implementation: every operation
delegates to that one implementation after checking its exact source binding.
`facade_identity()` identifies this API surface; `implementation_identity()`
continues to report the underlying V1 implementation identity.  Those two
identities must not be substituted for one another.
"""
module BoundedLinearStep

using SHA
import ..SpatialBoundedLinearStepV1

export api_revision,
       policy,
       facade_identity,
       implementation_identity,
       identity_bundle,
       snapshot,
       solve_lower_bounded_step,
       audit_kkt,
       bounded_linear_step_policy_v1,
       bounded_linear_step_identity_v1,
       solve_lower_bounded_step_v1,
       bounded_step_kkt_v1,
       bounded_linear_step_snapshot_v1

const _API_REVISION = "runtime-v4-bounded-linear-step-facade-v1"
const _FACADE_SOURCE_PATH = abspath(@__FILE__)
const _FACADE_SOURCE_SHA256 = bytes2hex(SHA.sha256(read(_FACADE_SOURCE_PATH)))
const _IMPLEMENTATION_SOURCE_PATH = normpath(abspath(joinpath(
    @__DIR__, "..", "SpatialBoundedLinearStepV1.jl")))
const _EXPECTED_IMPLEMENTATION_SHA256 =
    bytes2hex(SHA.sha256(read(_IMPLEMENTATION_SOURCE_PATH)))

const _DELEGATED_FUNCTION_NAMES = (
    :bounded_linear_step_policy_v1,
    :bounded_linear_step_identity_v1,
    :bounded_linear_step_snapshot_v1,
    :solve_lower_bounded_step_v1,
    :bounded_step_kkt_v1,
)

api_revision() = (_check_facade_source(); _checked_implementation_identity(); _API_REVISION)

function _checked_implementation_identity()
    isfile(_IMPLEMENTATION_SOURCE_PATH) ||
        throw(ArgumentError("bounded-step implementation source is absent"))
    source_sha256 = bytes2hex(SHA.sha256(read(_IMPLEMENTATION_SOURCE_PATH)))
    source_sha256 == _EXPECTED_IMPLEMENTATION_SHA256 ||
        throw(ArgumentError("bounded-step implementation source hash mismatch"))

    _check_delegate_method_sources()

    implementation = SpatialBoundedLinearStepV1.bounded_linear_step_identity_v1()
    string(implementation.implementation_sha256) == source_sha256 ||
        throw(ArgumentError("bounded-step module identity does not match its source"))
    implementation
end

function _check_delegate_method_sources()
    for function_name in _DELEGATED_FUNCTION_NAMES
        isdefined(SpatialBoundedLinearStepV1, function_name) ||
            throw(ArgumentError("bounded-step delegated function is absent: $(function_name)"))
        delegated = getfield(SpatialBoundedLinearStepV1, function_name)
        delegated isa Function ||
            throw(ArgumentError("bounded-step delegated binding is not a function: $(function_name)"))
        delegated_methods = collect(methods(delegated))
        isempty(delegated_methods) &&
            throw(ArgumentError("bounded-step delegated function has no methods: $(function_name)"))

        for method in delegated_methods
            getfield(method, :module) === SpatialBoundedLinearStepV1 ||
                throw(ArgumentError("bounded-step delegated method belongs to another module: $(function_name)"))
            location = try
                Base.functionloc(method)
            catch
                nothing
            end
            location isa Tuple && !isempty(location) ||
                throw(ArgumentError("bounded-step delegated method source is unknown: $(function_name)"))
            source_file = first(location)
            source_text = if source_file isa Symbol
                String(source_file)
            elseif source_file isa AbstractString
                String(source_file)
            else
                ""
            end
            isempty(source_text) &&
                throw(ArgumentError("bounded-step delegated method source is unknown: $(function_name)"))
            normpath(abspath(source_text)) == _IMPLEMENTATION_SOURCE_PATH ||
                throw(ArgumentError("bounded-step delegated method source mismatch: $(function_name)"))
        end
    end
    nothing
end

function _check_facade_source()
    isfile(_FACADE_SOURCE_PATH) ||
        throw(ArgumentError("bounded-step facade source is absent"))
    current_sha256 = bytes2hex(SHA.sha256(read(_FACADE_SOURCE_PATH)))
    current_sha256 == _FACADE_SOURCE_SHA256 ||
        throw(ArgumentError("bounded-step facade source changed after load"))
    nothing
end

function policy()
    _check_facade_source()
    _checked_implementation_identity()
    SpatialBoundedLinearStepV1.bounded_linear_step_policy_v1()
end

function facade_identity()
    _check_facade_source()
    _checked_implementation_identity()
    (api_revision=_API_REVISION,
        source_path=_FACADE_SOURCE_PATH,
        source_sha256=_FACADE_SOURCE_SHA256)
end

function implementation_identity()
    _check_facade_source()
    _checked_implementation_identity()
end

function identity_bundle()
    _check_facade_source()
    implementation = _checked_implementation_identity()
    (api_revision=_API_REVISION,
        facade=(source_path=_FACADE_SOURCE_PATH,
            source_sha256=_FACADE_SOURCE_SHA256),
        implementation=implementation)
end

function snapshot(A, r, lower; kwargs...)
    _check_facade_source()
    _checked_implementation_identity()
    SpatialBoundedLinearStepV1.bounded_linear_step_snapshot_v1(
        A, r, lower; kwargs...)
end

function solve_lower_bounded_step(A, r, lower; kwargs...)
    _check_facade_source()
    _checked_implementation_identity()
    SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
        A, r, lower; kwargs...)
end

function audit_kkt(A, r, lower, step, active_indices; kwargs...)
    _check_facade_source()
    _checked_implementation_identity()
    SpatialBoundedLinearStepV1.bounded_step_kkt_v1(
        A, r, lower, step, active_indices; kwargs...)
end

# Compatibility spellings preserve the original V1 calls and return values.
# Their identity alias intentionally remains the implementation identity;
# callers that need to bind this facade must also record facade_identity().
bounded_linear_step_policy_v1() = policy()
bounded_linear_step_identity_v1() = implementation_identity()
solve_lower_bounded_step_v1(args...; kwargs...) =
    solve_lower_bounded_step(args...; kwargs...)
bounded_step_kkt_v1(args...; kwargs...) = audit_kkt(args...; kwargs...)
bounded_linear_step_snapshot_v1(args...; kwargs...) =
    snapshot(args...; kwargs...)

end # module BoundedLinearStep
