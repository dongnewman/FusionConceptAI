"""Patch-only candidate for a family-neutral accepted nonlinear step.

The operator owns geometry, topology, sparse assembly, linearized constraints,
and its frozen acceptance policy. This module owns only the common feasible
backtracking transaction. It does not provide physical closures or authority.
"""
module MultiTopologyNonlinearSolveV1

using SHA
using LinearAlgebra

export accepted_step_v1, verify_source_v1

const _SOURCE_PATH = abspath(@__FILE__)
# Provenance snapshot for callers that record the loaded source identity. This
# value is not used to decide whether the solver may run.
const _SOURCE_SHA256 = bytes2hex(SHA.sha256(read(_SOURCE_PATH)))

function _verify_core_method_origin()
    for method in methods(accepted_step_v1)
        location = try
            Base.functionloc(method)
        catch err
            throw(ArgumentError("accepted-step method source is unresolved: $(sprint(showerror, err))"))
        end
        abspath(String(location[1])) == _SOURCE_PATH ||
            throw(ArgumentError("accepted-step method is defined outside its frozen source"))
    end
    true
end

function verify_source_v1(expected_path::AbstractString)
    _verify_core_method_origin()
    abspath(expected_path) == _SOURCE_PATH ||
        throw(ArgumentError("accepted-step module has an unexpected source path"))
    true
end

function _verify_binding(guard::Function)
    fingerprint = guard()
    fingerprint isa AbstractString &&
        occursin(r"^[0-9a-f]{64}$", fingerprint) ||
        throw(ArgumentError("operator binding guard must return a lowercase SHA-256 fingerprint"))
    String(fingerprint)
end

"""
    accepted_step_v1(state, direction, state_scales; ...)

Apply one caller-computed Newton/Gauss-Newton direction through a feasible
backtracking search. `assemble_trial` must return the assembly for the exact
projected trial. Callers normally assemble each eligible trial; a caller may
reuse a fully validated assembly produced earlier in the same nonlinear iteration
only when the projected trial is exactly equal to that assembly's state and its
row scales match. The probe and the core's surrounding binding checks establish
that it belongs to the unchanged operator/input binding. The core checks
`binding_guard` before and after every `assemble_trial` callback, including a
same-call reuse. No linear step is computed here: GlobalWeak retains its frozen
sparse bounded-QR step and Coupled retains its equality-KKT active-set step.

The return value is an internal transaction record. Callers map it into their
existing report schemas and preserve their own status/authority decisions.
"""
function accepted_step_v1(state::AbstractVector{<:Real}, direction::AbstractVector{<:Real},
        state_scales::AbstractVector{<:Real};
        objective_before::Real,
        directional_derivative::Real,
        max_backtracks::Integer,
        alpha0::Real=1.0,
        reduction::Real=0.5,
        minimum_alpha::Real=0.0,
        armijo_fraction::Real,
        require_strict_decrease::Bool,
        assemble_trial::Function,
        assembly_ready::Function,
        unavailable_reason::Function,
        residual_for_merit::Function,
        merit::Function,
        project_state::Function,
        feasible::Function,
        changed::Function,
        evaluation_record::Function,
        binding_guard::Function,
        continue_trial::Function=()->true)
    _verify_core_method_origin()
    n = length(state)
    n > 0 && length(direction) == n && length(state_scales) == n ||
        throw(ArgumentError("accepted-step state, direction, and scales must have the same nonzero length"))
    all(isfinite, state) && all(isfinite, direction) && all(isfinite, state_scales) ||
        throw(ArgumentError("accepted-step input contains a nonfinite value"))
    all(>(0.0), state_scales) ||
        throw(ArgumentError("accepted-step state scales must be positive"))
    isfinite(objective_before) && objective_before >= 0.0 ||
        throw(ArgumentError("accepted-step base objective must be finite and nonnegative"))
    isfinite(directional_derivative) ||
        throw(ArgumentError("accepted-step directional derivative must be finite"))
    max_backtracks >= 0 || throw(ArgumentError("accepted-step backtrack count cannot be negative"))
    isfinite(alpha0) && alpha0 > 0.0 || throw(ArgumentError("initial alpha must be positive and finite"))
    isfinite(reduction) && 0.0 < reduction < 1.0 ||
        throw(ArgumentError("backtracking reduction must lie strictly between zero and one"))
    isfinite(minimum_alpha) && 0.0 <= minimum_alpha <= alpha0 ||
        throw(ArgumentError("minimum alpha must lie in [0, alpha0]"))
    isfinite(armijo_fraction) && 0.0 < armijo_fraction < 1.0 ||
        throw(ArgumentError("Armijo fraction must lie strictly between zero and one"))

    base_binding = _verify_binding(binding_guard)
    traces = NamedTuple[]
    accepted_state = Float64.(state)
    accepted_assembly = nothing
    accepted_alpha = nothing
    accepted_objective = Float64(objective_before)
    status = :stalled
    failure = nothing

    for trial_index in 0:max_backtracks
        continue_trial() || begin
            status = :budget_boundary
            failure = (kind=:caller_budget_boundary,)
            break
        end
        alpha = Float64(alpha0) * Float64(reduction)^trial_index
        alpha < minimum_alpha && break
        candidate = Float64.(state .+ alpha .* state_scales .* direction)
        projected = project_state(candidate)
        projected isa AbstractVector && length(projected) == n && all(isfinite, projected) ||
            throw(ArgumentError("accepted-step projection returned invalid state"))
        trial = Float64.(projected)
        is_feasible = feasible(trial)
        state_changed = changed(state, trial)
        if !is_feasible || !state_changed
            push!(traces, (trial_index=trial_index, alpha=alpha, state=Tuple(trial), evaluated=false,
                feasible=is_feasible, scaled_state_change=state_changed,
                objective_after=nothing, armijo=false, strict_decrease=false,
                accepted=false, evaluation=nothing, armijo_bound=nothing))
            continue
        end

        _verify_core_method_origin()
        before_assembly_binding = _verify_binding(binding_guard)
        before_assembly_binding == base_binding ||
            throw(ArgumentError("operator binding changed during accepted-step search"))
        assembly = assemble_trial(trial)
        after_assembly_binding = _verify_binding(binding_guard)
        after_assembly_binding == base_binding ||
            throw(ArgumentError("operator binding changed during trial assembly"))
        _verify_core_method_origin()

        if !assembly_ready(assembly)
            failure = unavailable_reason(assembly)
            push!(traces, (trial_index=trial_index, alpha=alpha, state=Tuple(trial), evaluated=false,
                feasible=true, scaled_state_change=true, objective_after=nothing,
                armijo=false, strict_decrease=false, accepted=false,
                evaluation=nothing, armijo_bound=nothing))
            status = :operator_unavailable
            break
        end
        residual = residual_for_merit(assembly)
        finite_residual = residual isa AbstractVector{<:Real} && all(isfinite, residual)
        objective_after = finite_residual ? Float64(merit(assembly, residual)) : Inf
        finite_objective = isfinite(objective_after) && objective_after >= 0.0
        armijo_bound = Float64(objective_before) +
            Float64(armijo_fraction) * alpha * Float64(directional_derivative)
        armijo = finite_objective && objective_after <= armijo_bound
        strict_decrease = finite_objective && objective_after < objective_before
        accepted = armijo && (!require_strict_decrease || strict_decrease)
        record = evaluation_record(assembly)
        push!(traces, (trial_index=trial_index, alpha=alpha, state=Tuple(trial), evaluated=true,
            feasible=true, scaled_state_change=true,
            objective_after=finite_objective ? objective_after : nothing,
            armijo=armijo, strict_decrease=strict_decrease,
            accepted=accepted, evaluation=record, armijo_bound=armijo_bound))
        if accepted
            status = :accepted
            accepted_state = trial
            accepted_assembly = assembly
            accepted_alpha = alpha
            accepted_objective = objective_after
            break
        end
    end
    _verify_binding(binding_guard) == base_binding ||
        throw(ArgumentError("operator binding changed before accepted-step return"))
    _verify_core_method_origin()
    (status=status, state=accepted_state, accepted_alpha=accepted_alpha,
        accepted_assembly=accepted_assembly, accepted_objective=accepted_objective,
        trials=Tuple(traces), failure=failure, binding_fingerprint=base_binding)
end

end # module MultiTopologyNonlinearSolveV1
