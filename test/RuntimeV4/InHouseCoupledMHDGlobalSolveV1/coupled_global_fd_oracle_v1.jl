"""Residual-only finite-difference oracle for isolated algebraic controls.

Preparation/test-only data. This file does not describe a physical closure,
candidate, MHD validation, or formal acceptance policy. Include the production
`InHouseCoupledMHDGlobalSolveV1` module in the parent module before including
this file. Candidate closures retain their source byte hashes; solver,
provider, and policy identities are semantic.
"""
module CoupledGlobalFDOracleV1

using LinearAlgebra
using SparseArrays

const Solver = getfield(parentmodule(@__MODULE__), :InHouseCoupledMHDGlobalSolveV1)

export CANDIDATE_HASH,
       REGION_IDS,
       INITIAL_STATE,
       PRESSURE_INDICES,
       fd_jacobian,
       regional_evaluator,
       interface_evaluator,
       outer_evaluator,
       conservation_evaluator,
       jacobian_oracle,
       test_closures,
       test_model,
       test_policy,
       expected_regional_residual,
       expected_regional_jacobian,
       expected_residual,
       expected_residual_jacobian,
       expected_equalities,
       expected_equality_jacobian,
       release_problem,
       EXPECTED_RELEASE_ACTIVE_SEQUENCE,
       EXPECTED_RELEASE_STEP,
       EXPECTED_RELEASE_MULTIPLIER

const CANDIDATE_HASH = repeat("a", 64)
const REGION_IDS = ("region_a", "region_b")
const REGION_DOF = 3
const GLOBAL_DOF = 2 * REGION_DOF
const PRESSURE_INDICES = (2, 5)
const INITIAL_STATE = [1.0, 0.25, 0.0, 1.0, 0.75, 0.0]
const FD_STEP = 2.0^-8
const _TEST_SOURCE_PATH = abspath(@__FILE__)
const _TEST_ACCEPTANCE_REF = "preparation/test_only/physical=false/coupled-global-fd-oracle-v1"

_region_equation_ids(region_id) = ("$(region_id)_u", "$(region_id)_p", "$(region_id)_w")
_outer_ids(region_id) = ("outer_$(region_id)_w",)
_interface_id() = ("interface_u_a_b",)
_conservation_ids() = ("global_pressure_sum",)
_interface_region_id() = "interface:$(REGION_IDS[1])->$(REGION_IDS[2])"

# This is the only residual definition. The analytic matrices below and the
# finite-difference oracle are separate calculations over this residual map.
regional_residual_only(x) = [x[1] - 1.0, x[2] * (1.0 - x[2]), x[3]]
interface_residual_only(xa, xb) = [xa[1] - xb[1]]
outer_residual_only(x) = [x[3]]
conservation_residual_only(x) = [x[2] + x[5] - 1.0]
interface_flat_residual_only(z) = interface_residual_only(
    view(z, 1:REGION_DOF), view(z, (REGION_DOF + 1):GLOBAL_DOF))

"Central-difference a residual-only map; does not call a provider Jacobian."
function fd_jacobian(residual_only::Function, x::AbstractVector{<:Real}; h::Real=FD_STEP)
    isfinite(h) && h > 0 || throw(ArgumentError("finite-difference step must be positive and finite"))
    x0 = Float64.(collect(x))
    all(isfinite, x0) || throw(ArgumentError("finite-difference state must be finite"))
    base = Float64.(collect(residual_only(x0)))
    !isempty(base) && all(isfinite, base) ||
        throw(ArgumentError("finite-difference residual must be nonempty and finite"))
    J = Matrix{Float64}(undef, length(base), length(x0))
    step = Float64(h)
    for j in eachindex(x0)
        xp = copy(x0); xm = copy(x0)
        xp[j] += step
        xm[j] -= step
        rp = Float64.(collect(residual_only(xp)))
        rm = Float64.(collect(residual_only(xm)))
        length(rp) == length(base) && length(rm) == length(base) ||
            throw(ArgumentError("finite-difference residual shape changed"))
        J[:, j] = (rp .- rm) ./ (2.0 * step)
    end
    all(isfinite, J) || throw(ArgumentError("finite-difference Jacobian is nonfinite"))
    J
end

function _analytic_regional_jacobian(x)
    J = zeros(Float64, REGION_DOF, REGION_DOF)
    J[1, 1] = 1.0
    J[2, 2] = 1.0 - 2.0 * Float64(x[2])
    J[3, 3] = 1.0
    J
end

function _test_envelope(context, region_id::String)
    (candidate_hash=context.candidate_hash,
     provider_semantic_hash=context.provider_semantic_hash,
     provider_context_hash=context.provider_context_hash,
     region_id=region_id)
end

function regional_evaluator(region_id::String, local_state::AbstractVector,
        closure_evidence, context)
    region_id in REGION_IDS || throw(ArgumentError("unknown test region"))
    merge(_test_envelope(context, region_id),
        (equation_ids=_region_equation_ids(region_id),
         residual=regional_residual_only(local_state),
         jacobian=_analytic_regional_jacobian(local_state)))
end

function interface_evaluator(state_a::AbstractVector, state_b::AbstractVector,
        closure_evidence, context)
    merge(_test_envelope(context, _interface_region_id()),
        (constraint_ids=_interface_id(),
         residual=interface_residual_only(state_a, state_b),
         jacobian_minus=reshape([1.0, 0.0, 0.0], 1, REGION_DOF),
         jacobian_plus=reshape([-1.0, 0.0, 0.0], 1, REGION_DOF)))
end

function outer_evaluator(region_id::String, local_state::AbstractVector,
        closure_evidence, context)
    region_id in REGION_IDS || throw(ArgumentError("unknown test region"))
    merge(_test_envelope(context, region_id),
        (constraint_ids=_outer_ids(region_id),
         residual=outer_residual_only(local_state),
         jacobian=reshape([0.0, 0.0, 1.0], 1, REGION_DOF)))
end

function conservation_evaluator(global_state::AbstractVector,
        closure_evidence, context)
    merge(_test_envelope(context, "global"),
        (conservation_ids=_conservation_ids(),
         residual=conservation_residual_only(global_state),
         jacobian=reshape([0.0, 1.0, 0.0, 0.0, 1.0, 0.0], 1, GLOBAL_DOF)))
end

function _oracle_state(operation::Symbol, state)
    if operation === :regional || operation === :outer
        residual_only = operation === :regional ? regional_residual_only : outer_residual_only
        return Float64.(collect(state)), residual_only
    elseif operation === :interface
        length(state) == 2 || throw(ArgumentError("interface oracle requires two regional states"))
        length(state[1]) == REGION_DOF && length(state[2]) == REGION_DOF ||
            throw(ArgumentError("interface oracle regional dimensions differ"))
        flat = vcat(Float64.(collect(state[1])), Float64.(collect(state[2])))
        return flat, interface_flat_residual_only
    elseif operation === :global_conservation
        return Float64.(collect(state)), conservation_residual_only
    end
    throw(ArgumentError("unsupported Jacobian-oracle operation: $operation"))
end

function jacobian_oracle(operation::Symbol, region_id::String, state,
        closure_evidence, context)
    flat_state, residual_only = _oracle_state(operation, state)
    Jfd = fd_jacobian(residual_only, flat_state)
    oracle_hash = string(Solver.canonical_hash(Solver._callback_identity(jacobian_oracle)))
    envelope = _test_envelope(context, region_id)
    if operation === :regional
        return merge(envelope, (equation_ids=_region_equation_ids(region_id),
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    elseif operation === :interface
        return merge(envelope, (constraint_ids=_interface_id(),
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    elseif operation === :outer
        return merge(envelope, (constraint_ids=_outer_ids(region_id),
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    end
    merge(envelope, (conservation_ids=_conservation_ids(),
        jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
end

function _test_closure(kind::Symbol)
    payload = (classification=:preparation, test_only=true, physical=false,
        algebraic_control="two-region manufactured residual; not a physical closure")
    Solver.make_closure_evidence_v1(kind, CANDIDATE_HASH,
        "preparation/test_only/physical=false/coupled-global-fd-oracle-v1",
        _TEST_SOURCE_PATH, payload)
end

function test_closures(; missing_kind::Union{Nothing,Symbol}=nothing)
    kinds = Solver._REQUIRED_CLOSURES
    missing_kind === nothing || missing_kind in kinds ||
        throw(ArgumentError("missing_kind must be one of the five required closures"))
    (pressure_topology=missing_kind === :pressure_topology ? nothing : _test_closure(:pressure_topology),
     current_topology=missing_kind === :current_topology ? nothing : _test_closure(:current_topology),
     B_out=missing_kind === :B_out ? nothing : _test_closure(:B_out),
     K_outer=missing_kind === :K_outer ? nothing : _test_closure(:K_outer),
     return_current_path=missing_kind === :return_current_path ? nothing : _test_closure(:return_current_path))
end

function test_policy()
    Solver.make_global_policy_v1(
        acceptance_ref=_TEST_ACCEPTANCE_REF,
        contract_source_path=_TEST_SOURCE_PATH,
        max_updates=12,
        wall_seconds=120.0,
        residual_tolerance=1.0e-6,
        constraint_tolerance=1.0e-10,
        stationarity_tolerance=1.0e-10,
        bound_dual_tolerance=1.0e-10,
        complementarity_tolerance=1.0e-10,
        step_tolerance=1.0e-12,
        minimum_step=2.0^-20,
        armijo_fraction=1.0e-4,
        max_backtracks=20,
        max_active_set_iterations=16,
        stagnation_window=3)
end

function test_model(; missing_kind::Union{Nothing,Symbol}=nothing)
    closures = test_closures(; missing_kind=missing_kind)
    callbacks = (regional_evaluator, interface_evaluator, outer_evaluator,
        conservation_evaluator, jacobian_oracle)
    context_hash = Solver.coupled_mhd_provider_context_hash_v1(callbacks...)
    Solver.make_global_model_v1(
        candidate_hash=CANDIDATE_HASH,
        region_ids=REGION_IDS,
        region_dofs=(REGION_DOF, REGION_DOF),
        pressure_indices=PRESSURE_INDICES,
        regional_equation_ids=(_region_equation_ids(REGION_IDS[1]),
            _region_equation_ids(REGION_IDS[2])),
        interface_constraint_ids=_interface_id(),
        outer_constraint_ids=(_outer_ids(REGION_IDS[1]), _outer_ids(REGION_IDS[2])),
        global_conservation_ids=_conservation_ids(),
        closure_evidence=closures,
        provider_id="preparation/test_only/physical=false/coupled-global-fd-oracle-v1",
        provider_source_path=_TEST_SOURCE_PATH,
        provider_context_hash=context_hash,
        regional_evaluator=regional_evaluator,
        interface_evaluator=interface_evaluator,
        outer_evaluator=outer_evaluator,
        conservation_evaluator=conservation_evaluator,
        jacobian_oracle=jacobian_oracle)
end

test_model(::AbstractString; missing_kind::Union{Nothing,Symbol}=nothing) =
    test_model(; missing_kind=missing_kind)

# Independent hand-derived expected values for consumer assertions.
expected_regional_residual(x) = [Float64(x[1]) - 1.0,
    Float64(x[2]) * (1.0 - Float64(x[2])), Float64(x[3])]
function expected_regional_jacobian(x)
    J = zeros(Float64, REGION_DOF, REGION_DOF)
    J[1, 1] = 1.0
    J[2, 2] = 1.0 - 2.0 * Float64(x[2])
    J[3, 3] = 1.0
    J
end
expected_residual(x) = vcat(expected_regional_residual(view(x, 1:3)),
    expected_regional_residual(view(x, 4:6)))

function expected_residual_jacobian(x)
    J = zeros(Float64, GLOBAL_DOF, GLOBAL_DOF)
    J[1:3, 1:3] = expected_regional_jacobian(view(x, 1:3))
    J[4:6, 4:6] = expected_regional_jacobian(view(x, 4:6))
    J
end

expected_equalities(x) = [Float64(x[1]) - Float64(x[4]),
    Float64(x[3]), Float64(x[6]), Float64(x[2]) + Float64(x[5]) - 1.0]

function expected_equality_jacobian()
    [1.0 0.0 0.0 -1.0 0.0 0.0;
     0.0 0.0 1.0  0.0 0.0 0.0;
     0.0 0.0 0.0  0.0 0.0 1.0;
     0.0 1.0 0.0  0.0 1.0 0.0]
end

const EXPECTED_RELEASE_ACTIVE_SEQUENCE = ((1, 2), (2,))
const EXPECTED_RELEASE_STEP = (8.0, 0.0)
const EXPECTED_RELEASE_MULTIPLIER = (-1.0,)

"Exact small QP input whose zero-bound warm start releases one pressure bound."
function release_problem()
    (J=sparse([1.0 -10.0; 0.0 1.0]),
     f=[-8.0, 1.0],
     C=spzeros(0, 2),
     c=Float64[],
     x=[0.0, 0.0],
     pressure_indices=(1, 2))
end

end # module CoupledGlobalFDOracleV1
