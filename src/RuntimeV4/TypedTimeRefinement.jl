# D1.2a deterministic three-level time refinement.  Include after TypedTimeResidual.jl.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: canonical_hash

const _TREF_REVISION = "typed-time-refinement-v1"
const _TREF_TOKEN = Val(:typed_time_refinement_private)

struct TimeRefinementProtocolV4
    base_step::Float64
    max_steps_per_level::NTuple{3,Int}
    ratio::Int
    order_lower::Float64
    order_upper::Float64
    protocol_hash::Digest256
    function TimeRefinementProtocolV4(base_step, max_steps_per_level::NTuple{3,Int};
                                      ratio=2, order_lower=3.5, order_upper=4.5)
        base_step isa Bool && throw(ArgumentError("base_step must be numeric, not Bool"))
        h = try Float64(base_step) catch; throw(ArgumentError("base_step must be numeric")) end
        isfinite(h) && h > 0 && isfinite(h / 4) && h / 4 > 0 || throw(ArgumentError("base_step must remain positive through refinement"))
        typeof(ratio) === Int && ratio == 2 || throw(ArgumentError("refinement ratio must be strict Int 2"))
        all(x -> typeof(x) === Int && x > 0, max_steps_per_level) || throw(ArgumentError("step budgets must be strict positive Int"))
        lo, hi = Float64(order_lower), Float64(order_upper)
        isfinite(lo) && isfinite(hi) && 3.5 <= lo < hi <= 4.5 || throw(ArgumentError("order interval must be within frozen [3.5,4.5]"))
        body = (revision=_TREF_REVISION, base_step=h, max_steps_per_level,
                ratio=2, order_lower=lo, order_upper=hi)
        new(h, max_steps_per_level, 2, lo, hi, canonical_hash(body))
    end
end

struct TimeRefinementReceiptV4
    status::Symbol
    failure_code::Union{Nothing,Symbol}
    prefix_hash::Digest256
    form_hash::Digest256
    scenario_hash::Digest256
    protocol_hash::Digest256
    plan_hashes::NTuple{3,Union{Nothing,Digest256}}
    result_hashes::NTuple{3,Union{Nothing,Digest256}}
    actual_steps::NTuple{3,Union{Nothing,Float64}}
    actual_step_counts::NTuple{3,Union{Nothing,Int}}
    rhs_evaluations::NTuple{3,Union{Nothing,Int}}
    endpoint_linf_differences::Union{Nothing,NTuple{2,Float64}}
    self_convergence_order::Union{Nothing,Float64}
    receipt_hash::Digest256
    function TimeRefinementReceiptV4(token::Val{:typed_time_refinement_private}, fields...)
        token === _TREF_TOKEN || throw(ArgumentError("private constructor"))
        new(fields...)
    end
end

function _tref_hash(fields...)
    canonical_hash((revision=_TREF_REVISION, fields=fields))
end

function _tref_receipt(status, failure, plan, scenario, protocol, ph, rh, steps, counts, rhs, diffs, order)
    vals = (status, failure, plan.compiled_prefix_hash, plan.form.form_hash,
        scenario.scenario_hash, protocol.protocol_hash, ph, rh, steps, counts, rhs, diffs, order)
    TimeRefinementReceiptV4(_TREF_TOKEN, status, failure, plan.compiled_prefix_hash,
        plan.form.form_hash, scenario.scenario_hash, protocol.protocol_hash,
        ph, rh, steps, counts, rhs, diffs, order, _tref_hash(vals...))
end

function _tref_receipt_identity(x::TimeRefinementReceiptV4)
    (x.status, x.failure_code, x.prefix_hash, x.form_hash, x.scenario_hash,
     x.protocol_hash, x.plan_hashes, x.result_hashes, x.actual_steps,
     x.actual_step_counts, x.rhs_evaluations, x.endpoint_linf_differences,
     x.self_convergence_order)
end

function _tref_failure(plan, scenario, protocol, code;
                       plan_hashes=(nothing,nothing,nothing), result_hashes=(nothing,nothing,nothing),
                       steps=(nothing,nothing,nothing), counts=(nothing,nothing,nothing),
                       rhs=(nothing,nothing,nothing), diffs=nothing, order=nothing)
    _tref_receipt(:refinement_failure, code, plan, scenario, protocol,
        plan_hashes, result_hashes, steps, counts, rhs, diffs, order)
end

function _tref_validate(plan, scenario, protocol)
    protocol isa TimeRefinementProtocolV4 || throw(ArgumentError("typed refinement protocol required"))
    _ttr_validate_plan(plan)
    canonical_hash(plan.form)
    canonical_hash(plan)
    canonical_hash(protocol)
    scenario isa TimeIntegrationScenarioV4 || throw(ArgumentError("typed scenario required"))
    protocol.base_step > 0 || throw(ArgumentError("invalid refinement step"))
    nothing
end

function run_typed_time_refinement(plan::TypedTimeResidualPlanV4,
                                   scenario::TimeIntegrationScenarioV4,
                                   protocol::TimeRefinementProtocolV4)
    _tref_validate(plan, scenario, protocol)
    hs = (protocol.base_step, protocol.base_step / 2, protocol.base_step / 4)
    plans = Vector{Any}(); results = Vector{Any}()
    for i in 1:3
        p = derive_typed_time_residual_plan(plan,
            TimeIntegrationProtocolV4(plan.protocol.method, hs[i], protocol.max_steps_per_level[i];
                residual_abs_tol=plan.protocol.residual_abs_tol, residual_rel_tol=plan.protocol.residual_rel_tol))
        push!(plans, p)
        r = integrate_typed_time_residual(p, scenario)
        push!(results, r)
        r.status === :integrated || return _tref_failure(plan, scenario, protocol, :nonintegrated;
            plan_hashes=ntuple(j -> j <= length(plans) ? plans[j].plan_hash : nothing, 3),
            result_hashes=ntuple(j -> j <= length(results) ? results[j].result_hash : nothing, 3),
            steps=ntuple(j -> j <= length(plans) ? hs[j] : nothing, 3),
            counts=ntuple(j -> j <= length(results) ? length(results[j].times)-1 : nothing, 3),
            rhs=ntuple(j -> j <= length(results) ? results[j].rhs_evaluations : nothing, 3))
    end
    all(r -> r.residual_norm !== nothing && isfinite(r.residual_norm), results) ||
        return _tref_failure(plan, scenario, protocol, :nonfinite;
            plan_hashes=Tuple(p.plan_hash for p in plans), result_hashes=Tuple(r.result_hash for r in results),
            steps=hs, counts=Tuple(length(r.times)-1 for r in results), rhs=Tuple(r.rhs_evaluations for r in results))
    endpoints = ntuple(i -> Float64[results[i].states[end]...], 3)
    d1 = norm(endpoints[1] .- endpoints[2], Inf); d2 = norm(endpoints[2] .- endpoints[3], Inf)
    common = (plan_hashes=Tuple(p.plan_hash for p in plans), result_hashes=Tuple(r.result_hash for r in results),
        steps=hs, counts=Tuple(length(r.times)-1 for r in results), rhs=Tuple(r.rhs_evaluations for r in results))
    (isfinite(d1) && isfinite(d2)) || return _tref_failure(plan, scenario, protocol, :nonfinite; diffs=(d1,d2), common...)
    (d1 > 0 && d2 > 0) || return _tref_failure(plan, scenario, protocol, :zero_difference; diffs=(d1,d2), common...)
    order = log(d1 / d2) / log(2)
    isfinite(order) && protocol.order_lower <= order <= protocol.order_upper ||
        return _tref_failure(plan, scenario, protocol, :order_out_of_bounds; diffs=(d1,d2), order=order, common...)
    _tref_receipt(:refinement_pass, nothing, plan, scenario, protocol,
        common.plan_hashes, common.result_hashes, common.steps, common.counts, common.rhs, (d1,d2), order)
end

canonical_hash(x::TimeRefinementProtocolV4) = begin
    expected = canonical_hash((revision=_TREF_REVISION, base_step=x.base_step,
        max_steps_per_level=x.max_steps_per_level, ratio=x.ratio,
        order_lower=x.order_lower, order_upper=x.order_upper))
    expected == x.protocol_hash || throw(ArgumentError("refinement protocol identity mismatch"))
    expected
end
canonical_hash(x::TimeRefinementReceiptV4) = begin
    expected = _tref_hash(_tref_receipt_identity(x)...)
    expected == x.receipt_hash || throw(ArgumentError("refinement receipt identity mismatch"))
    expected
end

typed_time_refinement_manifest() =
    (schema="fusionconceptai:runtime-v4-typed-time-refinement", revision=_TREF_REVISION,
     kind=:three_level_time_refinement, claim_ceiling=screen_only)
