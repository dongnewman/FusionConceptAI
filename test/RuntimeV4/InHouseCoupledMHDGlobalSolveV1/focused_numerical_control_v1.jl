"""Focused software controls for the coupled-global solver and an ordered three-region graph.

This file is preparation/test_only. All manufactured closures and results are
physical=false, grant no authority, emit no evidence, and have the claim ceiling
`numerical_mechanism_only`. They do not represent a physical MHD case or a
production acceptance policy.

Run `julia --startup-file=no --project=. test/RuntimeV4/InHouseCoupledMHDGlobalSolveV1/focused_numerical_control_v1.jl test`
for the in-process controls. `single-region-test` runs the isolated callback
capture and assembly controls; `gs-inverse-test` runs the native-band inverse
RHS scale control. `partition-test` opts into the isolated weighted residual/KKT
partition matrix oracle. `produce <path>` and `replay <baseline> <path>`
are intended for two separately launched Julia processes; the latter loads the
saved canonical solver-result wire and validates it with the solver replay API
before copying the original wire bytes to its fresh-process artifact.
"""
module FocusedNumericalControlV1

using Test
using LinearAlgebra
using SparseArrays
using SHA
using JSON3

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const CORE_PATH = joinpath(REPO_ROOT, "src", "RuntimeV4",
    "MultiTopologyNonlinearSolveV1.jl")
const SOLVER_PATH = joinpath(REPO_ROOT, "src", "RuntimeV4",
    "InHouseCoupledMHDGlobalSolveV1.jl")
const ORACLE_PATH = joinpath(@__DIR__, "coupled_global_fd_oracle_v1.jl")
const RUNS_ROOT = joinpath(REPO_ROOT, "runs", "InHouseCoupledMHDGlobalSolveV1")
const R22_ATTEMPT5_FIXTURE_PATH = joinpath(REPO_ROOT, "test", "fixtures",
    "r22_inhouse_kkt_attempt5_v1.json")
_sha256(bytes) = bytes2hex(SHA.sha256(bytes))

isfile(CORE_PATH) || error("accepted-step core source is absent: $CORE_PATH")
isfile(SOLVER_PATH) || error("production solver source is absent: $SOLVER_PATH")
isfile(ORACLE_PATH) || error("finite-difference oracle is absent: $ORACLE_PATH")

include(CORE_PATH)
const StepCore = MultiTopologyNonlinearSolveV1
isdefined(StepCore, :accepted_step_v1) || error("accepted-step core API was not loaded")
include(SOLVER_PATH)
const Solver = InHouseCoupledMHDGlobalSolveV1
include(ORACLE_PATH)
const Oracle = CoupledGlobalFDOracleV1

const CONTROL_SOURCE_PATH = abspath(@__FILE__)
const CONTROL_ACCEPTANCE_REF = "urn:test-only:coupled-global-control-v1"
const TEST_ONLY_CLASSIFICATION = (
    preparation=true,
    test_only=true,
    physical_authority=false,
    physical_validation=false,
    engineering_validation=false,
    emits_evidence=false,
    grants_pass=false,
    claim_ceiling=:numerical_mechanism_only,
)

# These are private software-control parameters only. They are not a frozen
# production policy and do not replace any formal model/resource gate.
const POLICY = Solver.make_global_policy_v1(
    acceptance_ref=CONTROL_ACCEPTANCE_REF,
    contract_source_path=CONTROL_SOURCE_PATH,
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
    stagnation_window=3,
)

function _stagnation_envelope(context, region_id::String)
    (candidate_hash=context.candidate_hash,
     provider_semantic_hash=context.provider_semantic_hash,
     provider_context_hash=context.provider_context_hash,
     region_id=region_id)
end

# A fourth, constant residual row makes the merit dominate the useful
# manufactured rows. The production line search can accept equal-rounded
# merit for three steps and must then report its existing stagnation status.
_stagnation_regional_residual_only(x) =
    [x[1] * (1.0 - x[1]), x[2] - 0.5, x[3], 1.0e8]
_stagnation_interface_residual_only(x) = [x[1] - x[4]]
_stagnation_outer_residual_only(x) = [x[3]]
_stagnation_conservation_residual_only(x) = [x[2] + x[5] - 1.0]

function _stagnation_regional_jacobian(x)
    J = zeros(Float64, 4, 3)
    J[1, 1] = 1.0 - 2.0 * Float64(x[1])
    J[2, 2] = 1.0
    J[3, 3] = 1.0
    J
end

const _STAG_REGION_IDS = ("region_a", "region_b")
const _STAG_REGION_DOFS = (3, 3)
const _STAG_EQUATION_IDS = (("region_a_u_nonlinear", "region_a_p_fixed",
        "region_a_w_fixed", "region_a_dominating_constant"),
    ("region_b_u_nonlinear", "region_b_p_fixed", "region_b_w_fixed",
        "region_b_dominating_constant"))
const _STAG_INTERFACE_IDS = ("interface_u_a_b",)
const _STAG_OUTER_IDS = (("outer_region_a_w",), ("outer_region_b_w",))
const _STAG_CONSERVATION_IDS = ("global_pressure_sum",)

function _stagnation_regional_evaluator(region_id::String, local_state::AbstractVector,
        closure_evidence, context)
    region_id in _STAG_REGION_IDS || throw(ArgumentError("unknown stagnation-control region"))
    i = findfirst(==(region_id), _STAG_REGION_IDS)
    merge(_stagnation_envelope(context, region_id),
        (equation_ids=_STAG_EQUATION_IDS[i],
         residual=_stagnation_regional_residual_only(local_state),
         jacobian=_stagnation_regional_jacobian(local_state)))
end

function _stagnation_interface_evaluator(state_a::AbstractVector, state_b::AbstractVector,
        closure_evidence, context)
    merge(_stagnation_envelope(context, "interface:region_a->region_b"),
        (constraint_ids=_STAG_INTERFACE_IDS,
         residual=[state_a[1] - state_b[1]],
         jacobian_minus=reshape([1.0, 0.0, 0.0], 1, 3),
         jacobian_plus=reshape([-1.0, 0.0, 0.0], 1, 3)))
end

function _stagnation_outer_evaluator(region_id::String, local_state::AbstractVector,
        closure_evidence, context)
    region_id in _STAG_REGION_IDS || throw(ArgumentError("unknown stagnation-control region"))
    i = findfirst(==(region_id), _STAG_REGION_IDS)
    merge(_stagnation_envelope(context, region_id),
        (constraint_ids=_STAG_OUTER_IDS[i],
         residual=[local_state[3]],
         jacobian=reshape([0.0, 0.0, 1.0], 1, 3)))
end

function _stagnation_conservation_evaluator(global_state::AbstractVector,
        closure_evidence, context)
    merge(_stagnation_envelope(context, "global"),
        (conservation_ids=_STAG_CONSERVATION_IDS,
         residual=[global_state[2] + global_state[5] - 1.0],
         jacobian=reshape([0.0, 1.0, 0.0, 0.0, 1.0, 0.0], 1, 6)))
end

function _stagnation_oracle_state(operation::Symbol, state)
    if operation === :regional
        return Float64.(collect(state)), _stagnation_regional_residual_only
    elseif operation === :outer
        return Float64.(collect(state)), _stagnation_outer_residual_only
    elseif operation === :interface
        flat = vcat(Float64.(collect(state[1])), Float64.(collect(state[2])))
        residual_only = z -> _stagnation_interface_residual_only(z)
        return flat, residual_only
    elseif operation === :global_conservation
        return Float64.(collect(state)), _stagnation_conservation_residual_only
    end
    throw(ArgumentError("unsupported stagnation Jacobian-oracle operation: $operation"))
end

function _stagnation_jacobian_oracle(operation::Symbol, region_id::String, state,
        closure_evidence, context)
    flat_state, residual_only = _stagnation_oracle_state(operation, state)
    Jfd = Oracle.fd_jacobian(residual_only, flat_state)
    oracle_hash = string(Solver.canonical_hash(
        Solver._callback_identity(_stagnation_jacobian_oracle)))
    envelope = _stagnation_envelope(context, region_id)
    if operation === :regional
        ids = _STAG_EQUATION_IDS[findfirst(==(region_id), _STAG_REGION_IDS)]
        return merge(envelope, (equation_ids=ids, jacobian=Jfd,
            jacobian_oracle_hash=oracle_hash))
    elseif operation === :interface
        return merge(envelope, (constraint_ids=_STAG_INTERFACE_IDS,
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    elseif operation === :outer
        ids = _STAG_OUTER_IDS[findfirst(==(region_id), _STAG_REGION_IDS)]
        return merge(envelope, (constraint_ids=ids, jacobian=Jfd,
            jacobian_oracle_hash=oracle_hash))
    end
    merge(envelope, (conservation_ids=_STAG_CONSERVATION_IDS,
        jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
end

function _stagnation_model()
    closures = Oracle.test_closures()
    callbacks = (_stagnation_regional_evaluator,
        _stagnation_interface_evaluator,
        _stagnation_outer_evaluator,
        _stagnation_conservation_evaluator,
        _stagnation_jacobian_oracle)
    context_hash = Solver.coupled_mhd_provider_context_hash_v1(callbacks...)
    Solver.make_global_model_v1(
        candidate_hash=Oracle.CANDIDATE_HASH,
        region_ids=_STAG_REGION_IDS,
        region_dofs=_STAG_REGION_DOFS,
        pressure_indices=Oracle.PRESSURE_INDICES,
        regional_equation_ids=_STAG_EQUATION_IDS,
        interface_constraint_ids=_STAG_INTERFACE_IDS,
        outer_constraint_ids=_STAG_OUTER_IDS,
        global_conservation_ids=_STAG_CONSERVATION_IDS,
        closure_evidence=closures,
        provider_id="preparation/test_only/physical=false/coupled-global-stagnation-control-v1",
        provider_source_path=CONTROL_SOURCE_PATH,
        provider_context_hash=context_hash,
        regional_evaluator=_stagnation_regional_evaluator,
        interface_evaluator=_stagnation_interface_evaluator,
        outer_evaluator=_stagnation_outer_evaluator,
        conservation_evaluator=_stagnation_conservation_evaluator,
        jacobian_oracle=_stagnation_jacobian_oracle,
    )
end

const _GRAPH_REGION_IDS = ("core", "mantle", "edge")
const _GRAPH_REGION_DOFS = (4, 5, 4)
const _GRAPH_INITIAL_STATE = Float64[1.18, 0.32, 0.34, 0.35,
    0.86, 0.08, 0.18, -0.2, 0.05, 0.72, 0.31, 0.21, -0.1]
const _GRAPH_PRESSURE_INDICES = (2, 6, 11)
const _GRAPH_EDGES = (
    (edge_id="core_to_mantle", minus_region_id="core", plus_region_id="mantle",
        constraint_ids=("interface_core_mantle_u", "interface_core_mantle_p")),
    (edge_id="mantle_to_edge", minus_region_id="mantle", plus_region_id="edge",
        constraint_ids=("interface_mantle_edge_u", "interface_mantle_edge_p")),
)

_graph_equation_ids(region, dofs) = Tuple("$(region)_equation_$(i)" for i in 1:(dofs == 5 ? 4 : 3))
_graph_outer_ids(region) = ("outer_$(region)_q",)

function _graph_region_residual(state)
    coupled = state[1] - 1.0 - 0.08 * state[2] - 0.04 * state[3] -
        0.02 * state[1] * state[2]
    residual = [coupled, state[2] - 0.2, state[3] - 0.25 * state[1]]
    length(state) == 5 && push!(residual, state[5] - 0.3)
    residual
end

function _graph_region_jacobian(state)
    J = zeros(Float64, length(state) == 5 ? 4 : 3, length(state))
    J[1, 1] = 1.0 - 0.02 * state[2]
    J[1, 2] = -0.08 - 0.02 * state[1]
    J[1, 3] = -0.04
    J[2, 2] = 1.0
    J[3, 1] = -0.25
    J[3, 3] = 1.0
    length(state) == 5 && (J[4, 5] = 1.0)
    J
end

_graph_interface_residual(minus, plus) = [minus[1] - plus[1], minus[2] - plus[2]]

function _graph_outer_residual(state)
    [state[4] - 0.1]
end

function _graph_conservation_residual(state)
    [state[2] + state[6] + state[11] - 0.6]
end

function _graph_envelope(context, region_id)
    (candidate_hash=context.candidate_hash,
     provider_semantic_hash=context.provider_semantic_hash,
     provider_context_hash=context.provider_context_hash,
     region_id=region_id)
end

function _graph_region_evaluator(region_id::String, state::AbstractVector, closures, context)
    i = findfirst(==(region_id), _GRAPH_REGION_IDS)
    i === nothing && throw(ArgumentError("unknown graph region"))
    merge(_graph_envelope(context, region_id),
        (equation_ids=_graph_equation_ids(region_id, _GRAPH_REGION_DOFS[i]),
         residual=_graph_region_residual(state), jacobian=_graph_region_jacobian(state)))
end

function _graph_interface_evaluator(minus::AbstractVector, plus::AbstractVector, closures, context)
    edge = context.interface_edge
    region_id = "interface:$(edge.edge_id)"
    minus_jacobian = zeros(Float64, 2, length(minus))
    plus_jacobian = zeros(Float64, 2, length(plus))
    minus_jacobian[1, 1] = 1.0; minus_jacobian[2, 2] = 1.0
    plus_jacobian[1, 1] = -1.0; plus_jacobian[2, 2] = -1.0
    merge(_graph_envelope(context, region_id),
        (constraint_ids=edge.constraint_ids,
         residual=_graph_interface_residual(minus, plus),
         jacobian_minus=minus_jacobian, jacobian_plus=plus_jacobian))
end

function _graph_outer_evaluator(region_id::String, state::AbstractVector, closures, context)
    region_id in _GRAPH_REGION_IDS || throw(ArgumentError("unknown graph outer region"))
    jacobian = zeros(Float64, 1, length(state))
    jacobian[1, 4] = 1.0
    merge(_graph_envelope(context, region_id),
        (constraint_ids=_graph_outer_ids(region_id), residual=_graph_outer_residual(state),
         jacobian=jacobian))
end

function _graph_conservation_evaluator(state::AbstractVector, closures, context)
    jacobian = zeros(Float64, 1, length(state))
    jacobian[1, collect(_GRAPH_PRESSURE_INDICES)] .= 1.0
    merge(_graph_envelope(context, "global"),
        (conservation_ids=("global_pressure_sum",),
         residual=_graph_conservation_residual(state), jacobian=jacobian))
end

function _graph_fd_residual(operation, state, context)
    if operation === :regional
        values = [state[1] - 1.0 - 0.08 * state[2] - 0.04 * state[3] -
            0.02 * state[1] * state[2], state[2] - 0.2,
            state[3] - 0.25 * state[1]]
        length(state) == 5 && push!(values, state[5] - 0.3)
        return values
    elseif operation === :outer
        return [state[4] - 0.1]
    elseif operation === :interface
        return [state[1][1] - state[2][1], state[1][2] - state[2][2]]
    elseif operation === :global_conservation
        return [state[2] + state[6] + state[11] - 0.6]
    end
    throw(ArgumentError("unknown graph oracle operation"))
end

function _graph_jacobian_oracle(operation::Symbol, region_id::String, state,
        closures, context)
    flattened = operation === :interface ? vcat(collect(state[1]), collect(state[2])) : collect(state)
    residual_only = x -> begin
        if operation === :interface
            minus_count = length(state[1])
            minus = view(x, 1:minus_count)
            plus = view(x, minus_count + 1:length(x))
            _graph_fd_residual(operation, (minus, plus), context)
        else
            _graph_fd_residual(operation, x, context)
        end
    end
    Jfd = Oracle.fd_jacobian(residual_only, flattened)
    envelope = _graph_envelope(context, region_id)
    oracle_hash = string(Solver.canonical_hash(Solver._callback_identity(_graph_jacobian_oracle)))
    if operation === :regional
        i = findfirst(==(region_id), _GRAPH_REGION_IDS)
        return merge(envelope, (equation_ids=_graph_equation_ids(region_id, _GRAPH_REGION_DOFS[i]),
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    elseif operation === :outer
        return merge(envelope, (constraint_ids=_graph_outer_ids(region_id),
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    elseif operation === :interface
        return merge(envelope, (constraint_ids=context.interface_edge.constraint_ids,
            jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
    end
    merge(envelope, (conservation_ids=("global_pressure_sum",),
        jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
end

function _three_region_model(; interface_edges=_GRAPH_EDGES,
        equilibrium_row_scales=nothing)
    closure_payload = (classification=:preparation, test_only=true, physical=false,
        algebraic_control="three-region four/five/four DOF chain; not a physical closure")
    closures = NamedTuple{Solver._REQUIRED_CLOSURES}(Tuple(
        Solver.make_closure_evidence_v1(kind, Oracle.CANDIDATE_HASH,
            "preparation/test_only/physical=false/three-region-chain-v1",
            CONTROL_SOURCE_PATH, closure_payload)
        for kind in Solver._REQUIRED_CLOSURES))
    callbacks = (_graph_region_evaluator, _graph_interface_evaluator,
        _graph_outer_evaluator, _graph_conservation_evaluator, _graph_jacobian_oracle)
    context_hash = Solver.coupled_mhd_provider_context_hash_v1(callbacks...)
    Solver.make_global_model_v1(candidate_hash=Oracle.CANDIDATE_HASH,
        region_ids=_GRAPH_REGION_IDS, region_dofs=_GRAPH_REGION_DOFS,
        pressure_indices=_GRAPH_PRESSURE_INDICES,
        regional_equation_ids=Tuple(_graph_equation_ids(region, dofs)
            for (region, dofs) in zip(_GRAPH_REGION_IDS, _GRAPH_REGION_DOFS)),
        interface_edges=interface_edges, outer_constraint_ids=Tuple(
            _graph_outer_ids(region) for region in _GRAPH_REGION_IDS),
        global_conservation_ids=("global_pressure_sum",), closure_evidence=closures,
        equilibrium_row_scales=equilibrium_row_scales,
        provider_id="preparation/test_only/physical=false/three-region-chain-v1",
        provider_source_path=CONTROL_SOURCE_PATH, provider_context_hash=context_hash,
        regional_evaluator=_graph_region_evaluator,
        interface_evaluator=_graph_interface_evaluator,
        outer_evaluator=_graph_outer_evaluator,
        conservation_evaluator=_graph_conservation_evaluator,
        jacobian_oracle=_graph_jacobian_oracle)
end

# Two-region shared-node assembly control. The interface evaluator remains an
# equality constraint; the oriented edge equilibrium callback below contributes
# opposite weak fluxes to each endpoint's regional test rows.
const _SHARED_REGION_IDS = ("left", "right")
const _SHARED_REGION_DOFS = (2, 2)
const _SHARED_DOF_MAPS = ((1, 2), (1, 3))
const _SHARED_ROW_MAPS = ((1, 2), (1, 3))
const _SHARED_EQUATION_IDS = (("left_shared_row", "left_local_row"),
    ("right_shared_row", "right_local_row"))
const _SHARED_EDGE = (edge_id="left_to_right", minus_region_id="left",
    plus_region_id="right", constraint_ids=("shared_node_continuity",))

_shared_region_residual(region, state) = region == "left" ?
    [state[1]^2 + 2.0 * state[2], 3.0 * state[2]] :
    [4.0 * state[1] + state[2], state[1] - 2.0 * state[2]]

function _shared_region_jacobian(region, state)
    region == "left" && return [2.0 * state[1] 2.0; 0.0 3.0]
    region == "right" && return [4.0 1.0; 1.0 -2.0]
    throw(ArgumentError("unknown shared-scatter region"))
end

_shared_flux(minus, plus) = 3.0 * minus[1] + 2.0 * minus[2] -
    4.0 * plus[1] + 5.0 * plus[2]

function _shared_envelope(context, region_id)
    (candidate_hash=context.candidate_hash,
     provider_semantic_hash=context.provider_semantic_hash,
     provider_context_hash=context.provider_context_hash,
     region_id=region_id)
end

function _shared_region_evaluator(region::String, state::AbstractVector, closures, context)
    i = findfirst(==(region), _SHARED_REGION_IDS)
    i === nothing && throw(ArgumentError("unknown shared-scatter region"))
    merge(_shared_envelope(context, region),
        (equation_ids=_SHARED_EQUATION_IDS[i],
         residual=_shared_region_residual(region, state),
         jacobian=_shared_region_jacobian(region, state)))
end

function _shared_interface_evaluator(minus::AbstractVector, plus::AbstractVector,
        closures, context)
    edge = context.interface_edge
    merge(_shared_envelope(context, "interface:$(edge.edge_id)"),
        (constraint_ids=edge.constraint_ids,
         residual=[minus[1] - plus[1]],
         jacobian_minus=reshape([1.0, 0.0], 1, 2),
         jacobian_plus=reshape([-1.0, 0.0], 1, 2)))
end

function _shared_outer_evaluator(region::String, state::AbstractVector, closures, context)
    i = findfirst(==(region), _SHARED_REGION_IDS)
    i === nothing && throw(ArgumentError("unknown shared-scatter region"))
    jacobian = reshape([0.0, 1.0], 1, 2)
    merge(_shared_envelope(context, region),
        (constraint_ids=("outer_$(region)_row",), residual=[state[2] - 0.1],
         jacobian=jacobian))
end

function _shared_conservation_evaluator(state::AbstractVector, closures, context)
    merge(_shared_envelope(context, "global"),
        (conservation_ids=("shared_global_balance",),
         residual=[state[2] + state[3] - 0.4],
         jacobian=reshape([0.0, 1.0, 1.0], 1, 3)))
end

function _shared_edge_equilibrium_evaluator(edge, minus::AbstractVector,
        plus::AbstractVector, closures, context)
    edge_id = "edge_equilibrium:$(edge.edge_id)"
    q = _shared_flux(minus, plus)
    merge(_shared_envelope(context, edge_id),
        (edge_id=edge.edge_id,
         equation_ids=(_SHARED_EQUATION_IDS[1]...,_SHARED_EQUATION_IDS[2]...),
         minus_residual=[q, -0.25 * q],
         plus_residual=[-q, 0.25 * q],
         jacobian_minus_minus=[3.0 2.0; -0.75 -0.5],
         jacobian_minus_plus=[-4.0 5.0; 1.0 -1.25],
         jacobian_plus_minus=[-3.0 -2.0; 0.75 0.5],
         jacobian_plus_plus=[4.0 -5.0; -1.0 1.25]))
end

function _shared_edge_residual_oracle(state)
    minus = state.minus
    plus = state.plus
    q = _shared_flux(minus, plus)
    vcat([q, -0.25 * q], [-q, 0.25 * q])
end

function _shared_global_residual_oracle(x)
    left = view(x, 1:2)
    right = [x[1], x[3]]
    q = _shared_flux(left, right)
    [left[1]^2 + 2.0 * left[2] + 4.0 * right[1] + right[2],
     3.0 * left[2] - 0.25 * q,
     right[1] - 2.0 * right[2] + 0.25 * q]
end

function _shared_jacobian_oracle(operation::Symbol, region_id::String, state,
        closures, context)
    if operation === :edge_equilibrium
        flat = vcat(collect(state.minus), collect(state.plus))
        residual_only = z -> _shared_edge_residual_oracle(
            (minus=view(z, 1:2), plus=view(z, 3:4)))
        ids = (_SHARED_EQUATION_IDS[1]...,_SHARED_EQUATION_IDS[2]...)
        field = (equation_ids=ids,)
    elseif operation === :regional
        flat = collect(state)
        residual_only = z -> _shared_region_residual(region_id, z)
        i = findfirst(==(region_id), _SHARED_REGION_IDS)
        field = (equation_ids=_SHARED_EQUATION_IDS[i],)
    elseif operation === :interface
        flat = vcat(collect(state[1]), collect(state[2]))
        residual_only = z -> [z[1] - z[3]]
        field = (constraint_ids=context.interface_edge.constraint_ids,)
    elseif operation === :outer
        flat = collect(state)
        residual_only = z -> [z[2] - 0.1]
        field = (constraint_ids=("outer_$(region_id)_row",),)
    elseif operation === :global_conservation
        flat = collect(state)
        residual_only = z -> [z[2] + z[3] - 0.4]
        field = (conservation_ids=("shared_global_balance",),)
    else
        throw(ArgumentError("unsupported shared-scatter oracle operation"))
    end
    Jfd = Oracle.fd_jacobian(residual_only, flat)
    oracle_hash = string(Solver.canonical_hash(
        Solver._callback_identity(_shared_jacobian_oracle)))
    merge(_shared_envelope(context, region_id), field,
        (jacobian=Jfd, jacobian_oracle_hash=oracle_hash))
end

function _shared_scatter_model(; dof_maps=_SHARED_DOF_MAPS,
        row_maps=_SHARED_ROW_MAPS, edge_evaluator=_shared_edge_equilibrium_evaluator,
        row_scales=nothing)
    closures = Oracle.test_closures()
    callbacks = (_shared_region_evaluator, _shared_interface_evaluator,
        _shared_outer_evaluator, _shared_conservation_evaluator,
        _shared_jacobian_oracle)
    context_hash = Solver.coupled_mhd_provider_context_hash_v1(callbacks...;
        edge_equilibrium_evaluator=edge_evaluator)
    Solver.make_global_model_v1(candidate_hash=Oracle.CANDIDATE_HASH,
        region_ids=_SHARED_REGION_IDS, region_dofs=_SHARED_REGION_DOFS,
        pressure_indices=(2, 3), regional_equation_ids=_SHARED_EQUATION_IDS,
        interface_edges=(_SHARED_EDGE,), local_dof_to_global=dof_maps,
        local_test_row_to_global=row_maps, pressure_indices_global=true,
        edge_equilibrium_evaluator=edge_evaluator,
        outer_constraint_ids=(("outer_left_row",), ("outer_right_row",)),
        global_conservation_ids=("shared_global_balance",),
        closure_evidence=closures,
        equilibrium_row_scales=row_scales,
        provider_id="preparation/test_only/physical=false/shared-scatter-fd-control-v1",
        provider_source_path=CONTROL_SOURCE_PATH, provider_context_hash=context_hash,
        regional_evaluator=_shared_region_evaluator,
        interface_evaluator=_shared_interface_evaluator,
        outer_evaluator=_shared_outer_evaluator,
        conservation_evaluator=_shared_conservation_evaluator,
        jacobian_oracle=_shared_jacobian_oracle)
end

function _three_region_control()
    model = _three_region_model()
    assembly = Solver.assemble_coupled_mhd_global_v1(model, _GRAPH_INITIAL_STATE)
    solution = Solver.solve_coupled_mhd_global_v1(model, _GRAPH_INITIAL_STATE, POLICY)
    replay = Solver.replay_coupled_mhd_global_v1(model, _GRAPH_INITIAL_STATE, POLICY, solution)
    (model=model, assembly=assembly, solution=solution, replay=replay)
end

function _r22_phase_marker(enabled, boundary, phase)
    enabled || return nothing
    println("R22_PHASE_$(boundary)=$(phase)")
    flush(stdout)
    nothing
end

function _rank_deficient_kkt_control()
    Solver._active_kkt_step(
        spzeros(1, 1), [0.0], sparse(reshape([1.0, 1.0], 2, 1)),
        [0.0, 1.0], [0.0], (), POLICY)
end

function _square_root_test_kkt(J, f, C, c)
    n=size(J,2);m=size(J,1);k=size(C,1)
    K=[spzeros(Float64,n,n) transpose(J) transpose(C);
       J -spdiagm(0=>ones(Float64,m)) spzeros(Float64,m,k);
       C spzeros(Float64,k,m) spzeros(Float64,k,k)]
    rhs=vcat(zeros(Float64,n),-f,-c)
    result=Solver._kkt_square_root_qr_solution(J,f,C,c,K,POLICY)
    (result=result,K=K,rhs=rhs)
end

function _weak_full_rank_jz_control()
    weak_singular=1.0e-8
    J=[1.0 0.0;0.0 weak_singular]
    C=sparse(reshape([1.0,0.0],1,2))
    f=[-1.0,0.0]
    c=[-1.0]
    control=_square_root_test_kkt(J,f,C,c)
    threshold=Solver._kkt_rank_threshold([1.0,weak_singular],size(J))
    squared_threshold=Solver._kkt_rank_threshold([weak_singular^2],(1,1))
    relative_defect=maximum(abs,control.K*control.result.z-control.rhs)/
        max(1.0,maximum(abs,control.rhs),
            opnorm(control.K,Inf)*maximum(abs,control.result.z))
    (control=control,weak_singular=weak_singular,
        squared_weak_singular=weak_singular^2,squared_threshold=squared_threshold,
        jz_threshold=threshold,
        relative_defect=relative_defect)
end

function _rank_deficient_jz_control()
    _square_root_test_kkt([1.0 0.0;0.0 0.0],[-1.0,0.0],
        sparse(reshape([1.0,0.0],1,2)),[-1.0])
end

function _jz_threshold_boundary_control()
    threshold=Solver._kkt_rank_threshold([1.0,1.0],(2,2))
    solve_at(value)=_square_root_test_kkt([1.0 0.0;0.0 value],
        zeros(Float64,2),spzeros(Float64,0,2),Float64[]).result
    (threshold=threshold,below=solve_at(prevfloat(threshold)),
        equal=solve_at(threshold),above=solve_at(nextfloat(threshold)))
end

function _r22_fifth_attempt_control(; emit_markers=false)
    _r22_phase_marker(emit_markers, "BEGIN", "fixture_load_and_kkt_assembly")
    isfile(R22_ATTEMPT5_FIXTURE_PATH) ||
        error("R22 attempt-5 numerical fixture is absent: $R22_ATTEMPT5_FIXTURE_PATH")
    fixture = JSON3.read(read(R22_ATTEMPT5_FIXTURE_PATH, String))
    fixture.schema == "r22-inhouse-kkt-attempt-input-fixture-v1" &&
        fixture.provenance.attempt_index == 5 ||
        error("R22 KKT attempt-5 fixture identity is malformed")
    input = fixture.input
    input.jacobian.format == "coordinate" && input.index_base == 1 ||
        error("R22 KKT attempt-5 fixture sparse matrix encoding is unsupported")

    row_indices = Int.(collect(input.jacobian.row_indices))
    column_indices = Int.(collect(input.jacobian.column_indices))
    values = Float64.(collect(input.jacobian.values))
    J = sparse(row_indices, column_indices, values,
        Int(input.rows), Int(input.columns))
    column_scales = Float64.(collect(input.column_scales))
    length(column_scales) == Int(input.columns) ||
        error("R22 KKT attempt-5 column scales are incomplete")
    # The consumer snapshot stores the already column-scaled Jacobian. Apply
    # the inverse only when rebuilding the API's pre-column-scaled partition.
    scaled_residual = Float64.(collect(input.scaled_residual))
    length(scaled_residual) == Int(input.rows) ||
        error("R22 KKT attempt-5 residual is incomplete")
    pressure_bounds = input.pressure_step_lower_bounds
    pressure_indices = Int[Int(bound.index) for bound in pressure_bounds]
    state = zeros(Float64, Int(input.columns))
    for bound in pressure_bounds
        state[Int(bound.index)] = -Float64(bound.lower)
    end
    active = Int[index for index in pressure_indices if iszero(state[index])]
    active == [4, 24] || error("R22 fifth KKT active bounds changed")
    n, m, k = Int(input.columns), Int(input.rows), length(active)
    E = sparse(1:k, active, ones(Float64, k), k, n)
    # Rebuild the R22 KKT input from its minimal fixture for budget and solve
    # controls; the source attempts artifact remains provenance only.
    K = [spzeros(Float64, n, n) transpose(J) transpose(E);
         J -spdiagm(0 => ones(Float64, m)) spzeros(Float64, m, k);
         E spzeros(Float64, k, m) spzeros(Float64, k, k)]
    rank = fixture.historical_rank
    _r22_phase_marker(emit_markers, "COMPLETE", "fixture_load_and_kkt_assembly")

    _r22_phase_marker(emit_markers, "BEGIN", "expired_budget_gate")
    expired_budget = Solver._kkt_rank_fallback_budget(K, (deadline_ns=Int128(0),))
    _r22_phase_marker(emit_markers, "COMPLETE", "expired_budget_gate")

    _r22_phase_marker(emit_markers, "BEGIN", "independent_rank_deficient_kkt")
    rank_deficient_kkt = _rank_deficient_kkt_control()
    rank_deficient_jz = _rank_deficient_jz_control()
    _r22_phase_marker(emit_markers, "COMPLETE", "independent_rank_deficient_kkt")

    _r22_phase_marker(emit_markers, "BEGIN", "weak_full_rank_jz")
    weak_full_rank_jz = _weak_full_rank_jz_control()
    _r22_phase_marker(emit_markers, "COMPLETE", "weak_full_rank_jz")

    _r22_phase_marker(emit_markers, "BEGIN", "jz_threshold_boundary")
    jz_threshold_boundary = _jz_threshold_boundary_control()
    _r22_phase_marker(emit_markers, "COMPLETE", "jz_threshold_boundary")

    _r22_phase_marker(emit_markers, "BEGIN", "fresh_r22_rank_path")
    fresh_policy = (stationarity_tolerance=POLICY.stationarity_tolerance,
        bound_dual_tolerance=POLICY.bound_dual_tolerance,
        max_active_set_iterations=POLICY.max_active_set_iterations,
        compact_trace=true,
        deadline_ns=time_ns() + UInt64(10_000_000_000))
    fresh = Solver._active_kkt_step(J, scaled_residual, spzeros(Float64, 0, n),
        Float64[], state, pressure_indices, fresh_policy)
    _r22_phase_marker(emit_markers, "COMPLETE", "fresh_r22_rank_path")

    _r22_phase_marker(emit_markers, "BEGIN", "public_r22_api_path")
    candidate_hash = repeat("c", 64)
    partition = Solver.weighted_residual_kkt_partition_v1(
        candidate_hash=candidate_hash,
        consumer_identity=(candidate_hash=candidate_hash,
            consumer_id="preparation/test_only/R22-attempt5-rank-fallback-control"),
        least_squares_row_ids=Tuple("r22_row_$i" for i in 1:m),
        least_squares_residual=scaled_residual,
        least_squares_jacobian=J * spdiagm(0 => 1.0 ./ column_scales),
        least_squares_row_scales=ones(Float64, m))
    r22_api = Solver.solve_weighted_residual_kkt_step_v1(partition;
        scaled_state=state, column_scales=column_scales,
        pressure_indices=pressure_indices,
        stationarity_tolerance=POLICY.stationarity_tolerance,
        bound_dual_tolerance=POLICY.bound_dual_tolerance,
        max_active_set_iterations=POLICY.max_active_set_iterations,
        seconds=10.0)
    _r22_phase_marker(emit_markers, "COMPLETE", "public_r22_api_path")

    _r22_phase_marker(emit_markers, "BEGIN", "public_budget_detail")
    budget_hash = repeat("e", 64)
    budget_partition = Solver.weighted_residual_kkt_partition_v1(
        candidate_hash=budget_hash,
        consumer_identity=(candidate_hash=budget_hash,
            consumer_id="preparation/test_only/rank-deficient-budget-control"),
        least_squares_row_ids=("budget_ls_row",),
        least_squares_residual=[0.0],
        least_squares_jacobian=spzeros(Float64, 1, 1),
        least_squares_row_scales=[1.0],
        equality_row_ids=("duplicate_exact_a", "duplicate_exact_b"),
        equality_residual=[0.0, 1.0],
        equality_jacobian=sparse(reshape([1.0, 1.0], 2, 1)))
    api_budget = Solver.solve_weighted_residual_kkt_step_v1(budget_partition;
        scaled_state=[0.0], column_scales=[1.0], pressure_indices=(),
        stationarity_tolerance=POLICY.stationarity_tolerance,
        bound_dual_tolerance=POLICY.bound_dual_tolerance,
        max_active_set_iterations=POLICY.max_active_set_iterations,
        seconds=0.0)
    _r22_phase_marker(emit_markers, "COMPLETE", "public_budget_detail")

    _r22_phase_marker(emit_markers, "BEGIN", "public_rank_capability_gap")
    gap_hash = repeat("d", 64)
    gap_partition = Solver.weighted_residual_kkt_partition_v1(
        candidate_hash=gap_hash,
        consumer_identity=(candidate_hash=gap_hash,
            consumer_id="preparation/test_only/rank-verification-capability-gap-control"),
        least_squares_row_ids=Tuple("gap_row_$i" for i in 1:127),
        least_squares_residual=zeros(Float64, 127),
        least_squares_jacobian=spzeros(Float64, 127, 1),
        least_squares_row_scales=ones(Float64, 127),
        equality_row_ids=("unobservable_exact_row",),
        equality_residual=[1.0],
        equality_jacobian=spzeros(Float64, 1, 1))
    capability_gap = Solver.solve_weighted_residual_kkt_step_v1(gap_partition;
        scaled_state=[1.0], column_scales=[1.0], pressure_indices=(),
        stationarity_tolerance=POLICY.stationarity_tolerance,
        bound_dual_tolerance=POLICY.bound_dual_tolerance,
        max_active_set_iterations=POLICY.max_active_set_iterations,
        seconds=5.0)
    _r22_phase_marker(emit_markers, "COMPLETE", "public_rank_capability_gap")

    (attempt_index=Int(fixture.provenance.attempt_index),
        source_sha256=String(fixture.provenance.source_sha256),
        rows=m, columns=n, active_bounds=Tuple(active), kkt_order=size(K, 1),
        recorded_rank=Int(rank.rank_estimate),
        recorded_rank_columns=Int(rank.columns),
        recorded_rank_threshold=Float64(rank.relative_threshold),
        budget=expired_budget, rank_deficient_kkt=rank_deficient_kkt,
        rank_deficient_jz=rank_deficient_jz,
        weak_full_rank_jz=weak_full_rank_jz,
        jz_threshold_boundary=jz_threshold_boundary,
        fresh=fresh, r22_api=r22_api,
        api_budget=api_budget,
        capability_gap=capability_gap)
end

function _bound_only_minimum_norm_controls()
    @testset "bound-only rank-deficient sparse QR minimum norm" begin
        # Dense SVD is an independent, tiny test oracle only; production is sparse.
        function oracle(J, f, x, active)
            free = setdiff(collect(axes(J, 2)), active)
            p = zeros(size(J, 2)); p[active] = -x[active]
            A = Matrix(J[:, free]); b = -(J * p + f)
            if !isempty(free)
                S = svd(A)
                r = count(>(1.0e-12), S.S)
                r > 0 && (p[free] = S.V[:, 1:r] * ((S.U[:, 1:r]' * b) ./ S.S[1:r]))
            end
            p
        end
        base = [0.0 1 2 0; 0 0 0 3; 0 2 4 -1; 0 0 0 0; 0 -1 -2 2]
        f = [1.0, -2, 0.5, 3, -1]
        # Row/column permutations, tall and wide cases, active nonzero values,
        # rank zero and an empty free set exercise each reconstruction branch.
        cases = ((sparse(base), f, zeros(4), Int[]),
            (sparse(base[[5, 2, 4, 1, 3], [4, 1, 3, 2]]), f[[5, 2, 4, 1, 3]], zeros(4), Int[]),
            (sparse(transpose(base)), [1.0, -2, 3, -4], zeros(5), Int[]),
            (sparse([1.0 1 0 0; 0 0 0 0; 0 0 1 0]), [1.0, 2, 3], zeros(4), Int[]),
            (sparse(base), f, [0.0, 0.25, 0.0, 0.0], [2]),
            (spzeros(3, 4), [1.0, -2, 3], zeros(4), Int[]),
            (sparse(base), f, [1.0, 0.25, 0.5, 2.0], [1, 2, 3, 4]))
        first_qr_permuted = false
        second_qr_permuted = false
        for (J, r, x, active) in cases
            result = Solver._kkt_bound_only_minimum_norm(J, r, x, active, POLICY)
            @test result.status === :ok
            p = result.z[1:size(J, 2)]
            expected = oracle(J, r, x, active)
            @test p ≈ expected atol=1.0e-11 rtol=1.0e-11
            @test p[active] == -x[active]
            free = setdiff(collect(axes(J, 2)), active)
            @test norm((J' * (J * p + r))[free], Inf) <= 1.0e-11
            @test all(isfinite, result.z)
            n, m, k = size(J, 2), size(J, 1), length(active)
            E = sparse(1:k, active, ones(k), k, n)
            K = [spzeros(n, n) J' E'; J -spdiagm(0 => ones(m)) spzeros(m, k);
                E spzeros(k, m) spzeros(k, k)]
            @test norm(K * result.z - vcat(zeros(n), -r, -x[active]), Inf) <= 1.0e-11
            if !isempty(free)
                # Coverage audit only: the solution oracle above remains SVD.
                # Do not assume that reordered input causes backend pivoting.
                A = sparse(J[:, free])
                tol = result.rank_snapshot.relative_threshold
                first_qr = qr(A; tol=tol)
                first_qr_permuted |= first_qr.prow != collect(1:size(A, 1)) ||
                    (!isempty(first_qr.pcol) && first_qr.pcol != collect(1:size(A, 2)))
                if rank(first_qr) > 0
                    B = sparse(transpose(first_qr.R[1:rank(first_qr), :]))
                    second_qr = qr(B; tol=tol)
                    second_qr_permuted |= second_qr.prow != collect(1:size(B, 1)) ||
                        (!isempty(second_qr.pcol) && second_qr.pcol != collect(1:size(B, 2)))
                end
            end
        end
        @test first_qr_permuted
        @test second_qr_permuted
        zero_rank = Solver._kkt_bound_only_minimum_norm(spzeros(3, 4),
            [1.0, -2, 3], zeros(4), Int[], POLICY)
        @test zero_rank.rank_snapshot.free_rank == 0
        @test zero_rank.z[5:7] == [1.0, -2, 3]
        @test norm(zero_rank.z[5:7]) > 0.0
        expired = Solver._kkt_bound_only_minimum_norm(sparse(base), f, zeros(4),
            Int[], (deadline_ns=Int128(0),))
        @test expired.status === :resource_interruption
        @test expired.reason === :wall_time_budget
        nonfinite = Solver._kkt_bound_only_minimum_norm(sparse([NaN 0.0]), [0.0],
            zeros(2), Int[], POLICY)
        @test nonfinite.status === :numerical_fail
        # The null direction is real: basic QR may return (1,0), but the
        # minimum-norm solution of p1+p2=1 is (1/2,1/2).
        minimum_norm = Solver._kkt_bound_only_minimum_norm(sparse([1.0 1.0]),
            [-1.0], zeros(2), Int[], POLICY)
        @test minimum_norm.z[1:2] ≈ [0.5, 0.5] atol=1.0e-12 rtol=0.0
        @test norm(minimum_norm.z[1:2]) < 1.0
        threshold = Solver._kkt_rank_threshold([1.0, 1.0], (2, 2))
        for (weak, expected_rank) in ((threshold / 4, 1), (threshold * 4, 2))
            ranked = Solver._kkt_bound_only_minimum_norm(spdiagm(0 => [1.0, weak]),
                zeros(2), zeros(2), Int[], POLICY)
            @test ranked.status === :ok
            @test ranked.rank_snapshot.free_rank == expected_rank
        end
        function public_step(J, f, x, pressure; iterations=4)
            hash = repeat("9", 64)
            partition = Solver.weighted_residual_kkt_partition_v1(candidate_hash=hash,
                consumer_identity=(candidate_hash=hash, consumer_id="test-only/bound-minimum-norm"),
                least_squares_row_ids=Tuple("ls_$i" for i in eachindex(f)),
                least_squares_residual=f, least_squares_jacobian=J,
                least_squares_row_scales=ones(length(f)))
            Solver.solve_weighted_residual_kkt_step_v1(partition; scaled_state=x,
                pressure_indices=pressure, stationarity_tolerance=1.0e-12,
                bound_dual_tolerance=1.0e-12, max_active_set_iterations=iterations)
        end
        # Two dependent free columns remain after activating nonzero p1.
        # Their RHS must include J_A*(-x_A): p2=p3=-0.375, not -0.5.
        bound_J = sparse([1.0 1.0 1.0; 1.0 0.0 0.0])
        bound = public_step(bound_J, [1.0, 1.0], [0.25, 0.0, 0.0], (1,))
        @test bound.status === :ok
        @test collect(bound.step) ≈ [-0.25, -0.375, -0.375] atol=1.0e-12 rtol=0.0
        @test bound.step[1] == -0.25
        @test collect(bound.step) ≈ oracle(bound_J, [1.0, 1.0], [0.25, 0.0, 0.0], [1]) atol=1.0e-12 rtol=0.0
        @test bound.active_bounds == (1,)
        @test Tuple(s.active_bounds for s in bound.active_set_trace) == ((), (1,))
        @test bound.stationarity <= 1.0e-12
        @test bound.dual_violation == bound.complementarity == 0.0
        @test bound.kkt_relative_defect <= 1.0e-12
        @test bound.linear_solver === :bounded_matrix_free_restarted_gmres
        @test last(bound.active_set_trace).linear_solve.status === :ok
        @test last(bound.active_set_trace).linear_solve.iterations > 0
        # Wrong-sign active multiplier must release the initial zero bound.
        released = public_step(sparse([1.0 0.0]), [-1.0], zeros(2), (1,))
        @test released.status === :ok
        @test collect(released.step) ≈ [1.0, 0.0] atol=1.0e-12 rtol=0.0
        @test isempty(released.active_bounds)
        @test Tuple(s.active_bounds for s in released.active_set_trace) == ((1,), ())
        limited = public_step(sparse([1.0 0.0]), [-1.0], zeros(2), (1,); iterations=1)
        @test limited.status === :numerical_fail
        @test limited.reason === :active_set_iteration_limit
        # Rank zero certifies stationarity, not a zero residual or global solve.
        constant = public_step(spzeros(2, 3), [1.0, 2.0], zeros(3), ())
        @test constant.status === :ok
        @test collect(constant.step) == zeros(3)
        @test constant.rank_certificate === :not_established_matrix_free_krylov
        @test only(constant.active_set_trace).linear_solve.iterations > 0
        @test norm([1.0, 2.0]) > 1.0
        identity = Solver.weighted_residual_kkt_step_identity_v1()
        @test identity.linear_solver === :bounded_matrix_free_restarted_gmres
        @test identity.gmres_restart_cap == 100 && identity.gmres_iteration_limit == 1000
        @test identity.gmres_restart_rule === :min_cap_and_actual_kkt_order
        @test identity.rank_certificate === :not_established_by_krylov_residual
        # The rank-repair primitive uses the untruncated R factor and a single
        # absolute threshold. Tiny dense SVDs are test oracles only.
        function bounded_r_svd_oracle(A,b,tau)
            S=svd(Matrix(A);full=false)
            rank=count(>(tau),S.S)
            y=zeros(Float64,size(A,2))
            rank>0 && (y=S.V[:,1:rank]*((S.U[:,1:rank]'*b)./S.S[1:rank]))
            (y=y,rank=rank,residual=norm(A*y-b))
        end
        tau=1.0e-12
        tall=sparse([1.0 2.0;2 4;0 0;-1 -2])
        permuted=sparse(tall[[4,2,1,3],[2,1]])
        wide=sparse([1.0 1 0 0;0 0 0 0])
        fixtures=((tall,[3.0,-1,2,4]),
            (permuted,[4.0,-1,3,2]),(wide,[1.0,-3]))
        for (A,b) in fixtures
            expected=bounded_r_svd_oracle(A,b,tau)
            repaired=Solver._kkt_bound_only_r_svd(A,b,tau,POLICY)
            @test repaired.status===:ok
            @test repaired.method===:untruncated_sparse_QR_bounded_R_SVD
            @test repaired.rank_estimate==expected.rank
            @test repaired.rank_threshold==tau
            @test repaired.y≈expected.y atol=1.0e-11 rtol=1.0e-11
            @test norm(A*repaired.y-b)≈expected.residual atol=1.0e-11 rtol=1.0e-11
            @test all(isfinite,repaired.y)
            @test repaired.estimated_workspace_bytes<=repaired.workspace_limit_bytes
        end
        @test norm(tall*bounded_r_svd_oracle(tall,[3.0,-1,2,4],tau).y-
            [3.0,-1,2,4])>0.0

        # Exercise active-coordinate RHS, original residual, pressure equality,
        # stationarity and the unchanged original KKT equations with the R-SVD y.
        J=sparse([1.0 1 1;1 0 0]);f=[1.0,1];x=[0.25,0,0];active=[1]
        free=[2,3];p=zeros(3);p[active].=-x[active]
        A=sparse(J[:,free]);b=-(f+J*p)
        repaired=Solver._kkt_bound_only_r_svd(A,b,tau,POLICY)
        @test repaired.status===:ok
        @test repaired.y≈[-0.375,-0.375] atol=1.0e-12 rtol=0.0
        p[free]=repaired.y
        lambda=J*p+f;mu=-(transpose(J)*lambda)[active]
        E=sparse([1],[1],[1.0],1,3)
        K=[spzeros(3,3) transpose(J) transpose(E);
            J -spdiagm(0=>ones(2)) spzeros(2,1);
            E spzeros(1,2) spzeros(1,1)]
        rhs=vcat(zeros(3),-f,-x[active]);z=vcat(p,lambda,mu)
        @test p[active]==-x[active]
        @test x[active]+p[active]==[0.0]
        @test norm(lambda)>0.0
        @test norm((transpose(J)*lambda)[free],Inf)<=1.0e-12
        @test norm(K*z-rhs,Inf)<=1.0e-12

        zero_A=spzeros(3,4);zero_b=[1.0,-2,3]
        zero_repair=Solver._kkt_bound_only_r_svd(zero_A,zero_b,tau,POLICY)
        @test zero_repair.status===:ok
        @test zero_repair.rank_estimate==0
        @test zero_repair.y==zeros(4)
        @test norm(zero_A*zero_repair.y-zero_b)==norm(zero_b)>0.0

        # 400 free columns exceed the fixed workspace reserve before QR/SVD.
        oversized=Solver._kkt_bound_only_r_svd(spzeros(1,400),zeros(1),tau,POLICY)
        @test oversized.status===:numerical_fail
        @test oversized.reason===:bound_only_rank_reveal_workspace_limit
        @test oversized.detail.estimated_workspace_bytes>oversized.detail.workspace_limit_bytes
        expired=Solver._kkt_bound_only_r_svd(tall,ones(size(tall,1)),tau,
            (deadline_ns=Int128(0),))
        @test expired.status===:resource_interruption
        @test expired.reason===:insufficient_wall_budget
        saved_design_workspace=Int128(sizeof(Float64))*(32Int128(249)^2+
            8Int128(337)*Int128(249)+3Int128(337))
        @test saved_design_workspace==21_250_776
        @test saved_design_workspace<=Solver._KKT_RANK_FALLBACK_MEMORY_RESERVE_BYTES
        @test identity.rank_deficiency ===
            :nonconvergence_stagnation_or_original_residual_failure
    end
    nothing
end


function _assert_r22_control_results(r22; emit_markers=false)
    _r22_phase_marker(emit_markers, "BEGIN", "assertions")
    @testset "R22 KKT rank and budget controls" begin
        @test r22.attempt_index == 5
        @test occursin(r"^[0-9a-f]{64}$", r22.source_sha256)
        @test (r22.rows, r22.columns, r22.active_bounds, r22.kkt_order) ==
            (57, 40, (4, 24), 99)
        @test (r22.recorded_rank, r22.recorded_rank_columns) == (98, 99)
        @test r22.recorded_rank_threshold == 2.19824158875781e-14
        @test r22.budget.allowed === false
        @test r22.budget.reason === :insufficient_wall_budget
        @test r22.budget.remaining_ns == 0

        @test r22.rank_deficient_kkt.status === :numerical_fail
        @test r22.rank_deficient_kkt.reason === :rank_deficient_kkt_system
        rank_deficient_kkt=only(r22.rank_deficient_kkt.steps).kkt_rank
        @test rank_deficient_kkt.fallback_status === :numerical_fail
        @test rank_deficient_kkt.fallback_method === :constraint_nullspace_pivoted_qr
        @test rank_deficient_kkt.fallback_detail.constraint_rows == 2
        @test rank_deficient_kkt.fallback_detail.variables == 1

        @test r22.rank_deficient_jz.result.status === :numerical_fail
        @test r22.rank_deficient_jz.result.reason === :rank_deficient_kkt_system
        @test r22.rank_deficient_jz.result.detail.method ===
            :pivoted_qr_reduced_least_squares_design_JZ
        @test r22.rank_deficient_jz.result.detail.rank_estimate == 0
        @test r22.rank_deficient_jz.result.detail.columns == 1

        weak_jz=r22.weak_full_rank_jz
        @test weak_jz.control.result.status === :ok
        @test weak_jz.control.result.rank_snapshot.method ===
            :pivoted_qr_reduced_least_squares_design_JZ
        @test weak_jz.control.result.rank_snapshot.rank_estimate ==
            weak_jz.control.result.rank_snapshot.columns == 1
        @test weak_jz.squared_weak_singular <= weak_jz.squared_threshold
        @test weak_jz.weak_singular > weak_jz.jz_threshold
        @test abs(weak_jz.control.result.z[1]-1.0) <= 1.0e-12
        @test abs(weak_jz.control.result.z[2]) <= 1.0e-12
        @test abs(weak_jz.control.result.z[1]+(-1.0)) <= 1.0e-12 # exact row C*p+c=0
        @test isfinite(weak_jz.relative_defect)
        @test weak_jz.relative_defect <= POLICY.stationarity_tolerance

        boundary=r22.jz_threshold_boundary
        @test boundary.threshold == 2eps(Float64)
        @test boundary.below.status === :numerical_fail
        @test boundary.below.detail.rank_estimate == 1
        @test boundary.equal.status === :numerical_fail
        @test boundary.equal.detail.rank_estimate == 1
        @test boundary.equal.detail.relative_threshold == boundary.threshold
        @test boundary.above.status === :ok
        @test boundary.above.rank_snapshot.rank_estimate == 2

        @test r22.fresh.status === :ok
        fresh_rank = only(r22.fresh.steps).kkt_rank
        @test fresh_rank.method === :sparse_qr_R_diagonal
        @test fresh_rank.rank_estimate == fresh_rank.columns == 99
        @test 1 <= fresh_rank.kkt_equilibration_passes <= 8
        @test isfinite(fresh_rank.kkt_equilibrated_row_norm_ratio)
        @test fresh_rank.kkt_equilibrated_row_norm_ratio <= 4.0 ||
            fresh_rank.kkt_equilibration_passes == 8
        fresh_defect = only(r22.fresh.steps).kkt_relative_defect
        @test isfinite(fresh_defect)
        @test fresh_defect <= POLICY.stationarity_tolerance

        @test r22.r22_api.status === :ok
        @test r22.r22_api.reason === nothing
        @test r22.r22_api.linear_solver === :bounded_matrix_free_restarted_gmres
        @test r22.r22_api.rank_certificate === :not_established_matrix_free_krylov
        @test !isempty(r22.r22_api.active_set_trace)
        @test all(s->s.linear_solve.status===:ok,r22.r22_api.active_set_trace)
        r22_gmres = last(r22.r22_api.active_set_trace).linear_solve
        @test r22_gmres.status === :ok && r22_gmres.iterations > 0
        @test isfinite(r22.r22_api.kkt_relative_defect)
        @test r22.r22_api.kkt_relative_defect <= POLICY.stationarity_tolerance

        @test r22.api_budget.status === :resource_interruption
        @test r22.api_budget.reason === :wall_time_budget
        # A zero deadline can stop before any Krylov trace exists.

        @test r22.capability_gap.status === :numerical_fail
        @test r22.capability_gap.reason === :gmres_stagnation
        @test only(r22.capability_gap.active_set_trace).linear_solve.stagnant_cycles == 5
    end
    _bound_only_minimum_norm_controls()
    _r22_phase_marker(emit_markers, "COMPLETE", "assertions")
    nothing
end

function _controls()
    Solver._validate_policy(POLICY)
    model = Oracle.test_model()
    assembly = Solver.assemble_coupled_mhd_global_v1(model, Oracle.INITIAL_STATE)
    solution = Solver.solve_coupled_mhd_global_v1(model, Oracle.INITIAL_STATE, POLICY)
    replay = Solver.replay_coupled_mhd_global_v1(model, Oracle.INITIAL_STATE,
        POLICY, solution)

    absences = Tuple(begin
        missing_model = Oracle.test_model(; missing_kind=kind)
        assembled = Solver.assemble_coupled_mhd_global_v1(missing_model, Oracle.INITIAL_STATE)
        solved = Solver.solve_coupled_mhd_global_v1(missing_model, Oracle.INITIAL_STATE, POLICY)
        (kind=kind, assembled=assembled, solved=solved)
    end for kind in Solver._REQUIRED_CLOSURES)

    release = Oracle.release_problem()
    released = Solver._active_kkt_step(release.J, release.f, release.C, release.c,
        release.x, release.pressure_indices, POLICY)

    stagnation_model = _stagnation_model()
    stagnation = Solver.solve_coupled_mhd_global_v1(stagnation_model,
        [0.25, 0.5, 0.0, 0.25, 0.5, 0.0], POLICY)

    topology = _three_region_control()

    inconsistent = _rank_deficient_kkt_control()
    r22_fifth = _r22_fifth_attempt_control()

    (model=model, assembly=assembly, solution=solution, replay=replay,
     absences=absences, release=release, released=released,
     stagnation_model=stagnation_model, stagnation=stagnation,
     topology=topology,
     inconsistent=inconsistent, r22_fifth=r22_fifth)
end

# Explicit one-domain extension of the existing authored algebraic control.
# Existing regional and outer laws are reused. The source-bound balance is p=1.
_single_region_no_interface(args...) = error("single-region interface must never execute")
function _single_region_conservation(state,closures,context)
    merge(_stagnation_envelope(context,"global"),
        (conservation_ids=("single_pressure_inventory",),residual=[state[2]-1.0],
         jacobian=sparse(reshape([0.0,1.0,0.0],1,3))))
end
function _single_region_oracle(operation,region_id,state,closures,context)
    if operation === :regional
        residual=Oracle.regional_residual_only
        ids=(equation_ids=Oracle._region_equation_ids(region_id),)
    elseif operation === :outer
        residual=Oracle.outer_residual_only
        ids=(constraint_ids=Oracle._outer_ids(region_id),)
    elseif operation === :global_conservation
        residual=z->[z[2]-1.0]
        ids=(conservation_ids=("single_pressure_inventory",),)
    else
        error("single-domain oracle must not receive an internal edge")
    end
    merge(_stagnation_envelope(context,region_id),ids,
        (jacobian=Oracle.fd_jacobian(residual,collect(state)),
         jacobian_oracle_hash=context.jacobian_oracle_hash))
end
function _single_region_model(;missing_kind=nothing,include_single_region=true,overrides...)
    callbacks=(Oracle.regional_evaluator,_single_region_no_interface,
        Oracle.outer_evaluator,_single_region_conservation,_single_region_oracle)
    defaults=(candidate_hash=Oracle.CANDIDATE_HASH,single_region=true,
        region_ids=("region_a",),region_dofs=(3,),pressure_indices=(2,),
        regional_equation_ids=(Oracle._region_equation_ids("region_a"),),
        interface_edges=(),outer_constraint_ids=(Oracle._outer_ids("region_a"),),
        global_conservation_ids=("single_pressure_inventory",),
        closure_evidence=Oracle.test_closures(;missing_kind),
        provider_id="preparation/test_only/physical=false/single-region-control",
        provider_source_path=CONTROL_SOURCE_PATH,
        provider_context_hash=Solver.coupled_mhd_provider_context_hash_v1(callbacks...),
        regional_evaluator=callbacks[1],interface_evaluator=callbacks[2],
        outer_evaluator=callbacks[3],conservation_evaluator=callbacks[4],
        jacobian_oracle=callbacks[5])
    kwargs=merge(defaults,(;overrides...))
    include_single_region || (kwargs=Base.structdiff(kwargs,NamedTuple{(:single_region,)}))
    Solver.make_global_model_v1(;kwargs...)
end
function _single_region_controls()
    @testset "explicit single-region assembly and unchanged multi-region contract" begin
        @testset "oracle sparse CSC ownership and streaming difference" begin
            A=SparseMatrixCSC{Float64,Int}(2,2,[1,3,4],[1,2,1],[0.0,2.0,0.0])
            B=SparseMatrixCSC{Float64,Int}(2,2,[1,2,4],[2,1,2],[-1.0,4.0,0.0])
            copied=Solver._sparse_float64_csc(A)
            @test Solver._sparse_float64_csc_borrowed(A) === A
            @test copied !== A
            @test copied.colptr !== A.colptr && copied.rowval !== A.rowval && copied.nzval !== A.nzval
            @test Solver._sparse_max_abs_difference(A,A)==0.0
            @test Solver._sparse_max_abs_difference(A,B)==4.0
            @test Solver._sparse_max_abs_difference(B,A)==4.0
            copied.nzval[1]=3.0
            @test A.nzval[1]==0.0
            dense_int=[1 0;0 2]
            converted=Solver._sparse_float64_csc(dense_int)
            @test converted isa SparseMatrixCSC{Float64,Int}
            @test Matrix(converted)==Float64.(dense_int)
            unsorted=SparseMatrixCSC{Float64,Int}(2,1,[1,3],[2,1],[1.0,2.0])
            duplicate=SparseMatrixCSC{Float64,Int}(2,1,[1,3],[1,1],[2.0,3.0])
            canonical=SparseMatrixCSC{Float64,Int}(2,1,[1,2],[1],[5.0])
            @test !Solver._sparse_csc_rows_sorted_unique(unsorted)
            @test !Solver._sparse_csc_rows_sorted_unique(duplicate)
            @test_throws ArgumentError Solver._sparse_max_abs_difference(unsorted,canonical)
            @test_throws ArgumentError Solver._sparse_max_abs_difference(duplicate,canonical)
            normalized_unsorted=Solver._sparse_float64_csc(unsorted)
            normalized_duplicate=Solver._sparse_float64_csc(duplicate)
            @test Solver._sparse_csc_rows_sorted_unique(normalized_unsorted)
            @test Solver._sparse_csc_rows_sorted_unique(normalized_duplicate)
            @test Matrix(normalized_unsorted)==reshape([2.0,1.0],2,1)
            @test Matrix(normalized_duplicate)==reshape([5.0,0.0],2,1)
        end
        mutable_capture=[1.0]
        captured_oracle=let parameter=mutable_capture
            (operation,region_id,state,closures,context)->begin
                isfinite(parameter[1]) || error("invalid captured oracle parameter")
                _single_region_oracle(operation,region_id,state,closures,context)
            end
        end
        captured_callbacks=(Oracle.regional_evaluator,_single_region_no_interface,
            Oracle.outer_evaluator,_single_region_conservation,captured_oracle)
        empty_capture_identity=Solver._callback_identity(_single_region_no_interface)
        @test isempty(fieldnames(typeof(_single_region_no_interface)))
        @test empty_capture_identity.capture_hash==
            string(Solver.canonical_hash(()))==bytes2hex(SHA.sha256(codeunits("[]")))
        capture_identity=Solver._callback_identity(captured_oracle)
        @test !hasproperty(capture_identity,:captures)
        capture_values=Tuple((name=String(name),value=getfield(captured_oracle,name))
            for name in fieldnames(typeof(captured_oracle)))
        capture_json=Solver.canonical_json(capture_values)
        legacy_capture_digest=string(Solver.canonical_hash(capture_values))
        direct_capture_digest=bytes2hex(SHA.sha256(codeunits(capture_json)))
        @test direct_capture_digest==legacy_capture_digest==capture_identity.capture_hash
        captured_context=Solver.coupled_mhd_provider_context_hash_v1(captured_callbacks...)
        @test captured_context==Solver._provider_context_hash_from_identities_v1(
            Tuple(Solver._callback_identity(f) for f in captured_callbacks))
        captured_model=_single_region_model(jacobian_oracle=captured_oracle,
            provider_context_hash=captured_context)
        @test Solver._validate_model(captured_model)
        public_signature=Solver.coupled_mhd_capability_signature_v1(captured_model)
        @test Solver._capability_signature_body_v1(captured_model,
            Solver._missing_closures(captured_model))==public_signature
        mutable_capture[1]=2.0
        @test Solver._callback_identity(captured_oracle).capture_hash!=capture_identity.capture_hash
        @test_throws ArgumentError Solver._validate_model(captured_model)
        @test_throws ArgumentError Solver.coupled_mhd_capability_signature_v1(captured_model)

        @testset "callback capture SHA streaming boundaries" begin
            capture_callback(payload)=let captured_payload=payload
                (args...)->captured_payload
            end
            capture_bytes(callback)=begin
                values=Tuple((name=String(name),value=getfield(callback,name))
                    for name in fieldnames(typeof(callback)))
                codeunits(Solver.canonical_json(values))
            end
            capture_digest(callback)=bytes2hex(SHA.sha256(capture_bytes(callback)))

            for payload in ("", "磁场-雪-λ")
                callback=capture_callback(payload)
                identity=Solver._callback_identity(callback)
                @test identity.capture_hash==capture_digest(callback)
            end

            # Put the first byte of a three-byte UTF-8 character at byte
            # CHUNK_BYTES-1 in the canonical capture JSON. Its code point then
            # straddles the production SHA reader's 1 MiB chunk boundary.
            chunk_bytes=1024*1024
            empty_callback=capture_callback("")
            empty_capture_bytes=capture_bytes(empty_callback)
            quote_positions=findall(==(UInt8(0x22)),empty_capture_bytes)
            @test length(quote_positions)>=2
            payload_start=quote_positions[end-1]+1
            payload_prefix_length=chunk_bytes-1-payload_start
            @test payload_prefix_length>=0
            boundary_callback=capture_callback("a"^payload_prefix_length*"雪"*"b")
            boundary_bytes=capture_bytes(boundary_callback)
            snow_first=findfirst(==(UInt8(0xe9)),boundary_bytes)
            @test snow_first==chunk_bytes-1
            @test length(boundary_bytes)>chunk_bytes
            boundary_identity=Solver._callback_identity(boundary_callback)
            @test boundary_identity.capture_hash==capture_digest(boundary_callback)

            mutable_payload=["a"^(chunk_bytes+17)*"雪"]
            mutable_callback=let captured_payload=mutable_payload
                (args...)->captured_payload[1]
            end
            before_identity=Solver._callback_identity(mutable_callback)
            @test before_identity.capture_hash==capture_digest(mutable_callback)
            mutable_payload[1]*="-changed"
            after_identity=Solver._callback_identity(mutable_callback)
            @test after_identity.capture_hash!=before_identity.capture_hash
            @test after_identity.capture_hash==capture_digest(mutable_callback)
        end

        model=_single_region_model()
        @test isempty(model.interface_edges)
        @test Solver._validate_model(model)
        @test !Solver.coupled_mhd_capability_signature_v1(model).capabilities.multi_region_global_assembly
        for x in ([1.25,0.75,0.125],[0.875,0.25,-0.25])
            a=Solver.assemble_coupled_mhd_global_v1(model,x)
            @test a.status === :assembled
            @test a.residual == Oracle.expected_regional_residual(x)
            @test Matrix(a.jacobian) == Oracle.expected_regional_jacobian(x)
            @test a.equality_residual == [x[3],x[2]-1.0]
            @test Matrix(a.equality_jacobian) == [0.0 0.0 1.0;0.0 1.0 0.0]
            @test a.row_ownership == (regional=("region_a",),interface_rows=0,outer_rows=1,conservation_rows=1)
            @test a.raw_blocks.interface === nothing && a.raw_blocks.interfaces == ()
            serialized=Solver._trace_eval(a,model)
            @test serialized.raw_blocks.interface === nothing && serialized.raw_blocks.interfaces == ()
            @test a.jacobian_checks.interface === nothing && a.jacobian_checks.interfaces == ()
            @test all(c->c.passed,(a.jacobian_checks.regional...,a.jacobian_checks.outer...,a.jacobian_checks.global_conservation))
        end
        initial=[1.25,0.75,0.125]
        result=Solver.solve_coupled_mhd_global_v1(model,initial,POLICY)
        @test result.status === :converged
        @test !result.capability_signature.capabilities.multi_region_global_assembly
        @test Solver.replay_coupled_mhd_global_v1(model,initial,POLICY,result).status === :replayed_exact
        # Nontrivial permutation proves real region-local/global ownership.
        mapped=_single_region_model(local_dof_to_global=((3,2,1),),
            local_test_row_to_global=((2,3,1),),pressure_indices_global=true,pressure_indices=(2,))
        x=[0.125,0.75,1.25]
        ma=Solver.assemble_coupled_mhd_global_v1(mapped,x)
        @test ma.residual == Oracle.expected_regional_residual(x[[3,2,1]])[[3,1,2]]
        @test Matrix(ma.jacobian) == Oracle.expected_regional_jacobian(x[[3,2,1]])[[3,1,2],[3,2,1]]
        @test ma.equality_residual == [0.125,-0.25]
        @test Matrix(ma.equality_jacobian) == [1.0 0.0 0.0;0.0 1.0 0.0]
        # Same candidate, callbacks, source and numeric case; only input containers differ.
        vector_mapped=_single_region_model(local_dof_to_global=([3,2,1],),
            local_test_row_to_global=([2,3,1],),pressure_indices_global=true,pressure_indices=[2],
            regional_equation_ids=(collect(Oracle._region_equation_ids("region_a")),))
        @test vector_mapped.model_hash==mapped.model_hash
        @test vector_mapped.provider_context_hash==mapped.provider_context_hash
        @test vector_mapped.local_dof_to_global==mapped.local_dof_to_global
        @test vector_mapped.local_test_row_to_global==mapped.local_test_row_to_global
        @test vector_mapped.pressure_indices==mapped.pressure_indices
        @test vector_mapped.regional_equation_ids==mapped.regional_equation_ids
        vector_assembly=Solver.assemble_coupled_mhd_global_v1(vector_mapped,x)
        @test vector_assembly.residual==ma.residual && vector_assembly.jacobian==ma.jacobian
        @test vector_assembly.equality_residual==ma.equality_residual && vector_assembly.equality_jacobian==ma.equality_jacobian
        @test Solver.canonical_json(Solver._trace_eval(vector_assembly,vector_mapped))==
            Solver.canonical_json(Solver._trace_eval(ma,mapped))
        mapped_result=Solver.solve_coupled_mhd_global_v1(mapped,x,POLICY)
        @test mapped_result.status===:converged
        cross_representation_replay=Solver.replay_coupled_mhd_global_v1(vector_mapped,x,POLICY,mapped_result)
        @test cross_representation_replay.status===:replayed_exact
        @test cross_representation_replay.raw_trace_match && cross_representation_replay.disposition_match
        for kind in Solver._REQUIRED_CLOSURES
            incomplete_model=_single_region_model(;missing_kind=kind)
            absent=Solver.assemble_coupled_mhd_global_v1(incomplete_model,initial)
            @test absent.status === :typed_absent && absent.missing_closures == (kind,)
            diagnostic_absent=Solver.assemble_coupled_mhd_global_v1(
                incomplete_model,initial;allow_incomplete=true)
            public_signature=Solver.coupled_mhd_capability_signature_v1(incomplete_model)
            @test diagnostic_absent.status===:typed_absent
            @test diagnostic_absent.missing_closures==(kind,)
            @test diagnostic_absent.capability_signature==public_signature
            @test diagnostic_absent.capability_signature.missing_closures==
                diagnostic_absent.missing_closures==(kind,)
            @test diagnostic_absent.capability_signature.complete===false
            @test diagnostic_absent.physical_authority===false
            @test diagnostic_absent.claim_ceiling===:diagnostic_only
            absent_solve=Solver.solve_coupled_mhd_global_v1(
                _single_region_model(;missing_kind=kind),initial,POLICY)
            @test absent_solve.status === :typed_absent
            @test absent_solve.missing_closures == (kind,)
            @test isempty(absent_solve.raw_trace)
            @test absent_solve.solver_convergence_validated === false
            @test absent_solve.independent_replay_validated === false
        end
        @test_throws ArgumentError _single_region_model(include_single_region=false)
        @test_throws ArgumentError _single_region_model(single_region=false)
        @test_throws ArgumentError _single_region_model(single_region=1)
        @test_throws ArgumentError _single_region_model(region_ids=("region_a","region_b"))
        @test_throws ArgumentError _single_region_model(interface_edges=nothing)
        @test_throws ArgumentError _single_region_model(interface_constraint_ids=("unprovided",))
        @test_throws ArgumentError _single_region_model(interface_edges=(_GRAPH_EDGES[1],))
        @test_throws ArgumentError _single_region_model(edge_equilibrium_evaluator=_single_region_no_interface)
        @test_throws ArgumentError _single_region_model(outer_constraint_ids=((),))
        @test_throws ArgumentError _single_region_model(global_conservation_ids=())
        @test_throws ArgumentError Solver.assemble_coupled_mhd_global_v1(model,[1.0,-0.1,0.0])
        @test_throws ArgumentError _three_region_model(interface_edges=())
        @test_throws ArgumentError _three_region_model(interface_edges=(_GRAPH_EDGES[1],))
        legacy=Oracle.test_model()
        la=Solver.assemble_coupled_mhd_global_v1(legacy,Oracle.INITIAL_STATE)
        @test la.residual == Oracle.expected_residual(Oracle.INITIAL_STATE)
        @test la.equality_residual == Oracle.expected_equalities(Oracle.INITIAL_STATE)
        @test la.jacobian_checks.interface.passed
        @test Solver._trace_eval(la,legacy).raw_blocks.interface !== nothing
        @test Solver.coupled_mhd_capability_signature_v1(legacy).capabilities.multi_region_global_assembly
        three=_three_region_model()
        @test length(Solver.assemble_coupled_mhd_global_v1(three,_GRAPH_INITIAL_STATE).jacobian_checks.interfaces)==2
    end
end

function _gs_inverse_controls()
    @testset "native band inverse preserves RHS scale for G and transpose" begin
        G=sparse([4.0 1.0 0.0 0.0;
            -1.0 4.0 1.0 0.0;
            0.0 -1.0 4.0 1.0;
            0.0 0.0 -1.0 3.0])
        node_rz=((1,1),(1,2),(2,1),(2,2))
        band=Solver._gs_native_band_factor_v1(G,node_rz;radius_r=1,radius_z=2)
        @test band.status===:ok
        base_rhs=[1.0,-2.0,0.5,3.0]
        for transpose_system in (false,true), scale in (1.0,1.0e-12,1.0e6,0.0)
            rhs=scale.*base_rhs
            operator=transpose_system ? transpose(G) : G
            direct=operator\rhs
            result=Solver.gs_native_band_inverse_v1(G,node_rz,rhs;
                transpose_system=transpose_system,restart=32,max_iterations=512,
                max_refinements=2,relative_tolerance=1.0e-10,
                radius_r=1,radius_z=2,factorization=band)
            @test result.status===:ok
            @test result.transpose_system===transpose_system
            @test length(result.solve_reports)==1
            solution=result.solution
            @test all(isfinite,solution)
            @test norm(solution-direct)<=1.0e-10*max(norm(direct),1.0e-300)
            true_residual=rhs-operator*solution
            relative_residual=iszero(norm(rhs)) ? norm(true_residual) :
                norm(true_residual)/norm(rhs)
            @test relative_residual<=1.0e-10
            if scale==1.0e-12
                # Before RHS normalization, the shared GMRES's absolute floor
                # accepts a zero iterate at 0 iterations; the true residual
                # gate then rejects this valid tiny load.
                @test only(result.solve_reports).iterations>0
                @test norm(solution)>0.0
            elseif iszero(scale)
                @test only(result.solve_reports).iterations==0
                @test iszero(norm(solution))
            end
        end

        # A diagonal surrogate is intentionally not an exact preconditioner.
        # One GMRES iteration must fail for this tiny RHS, and the diagnostic
        # true residual must use the normalized correction restored by its
        # preconditioned RHS norm.
        approximate_band=Solver._gs_native_band_factor_v1(G,node_rz;
            radius_r=0,radius_z=0)
        @test approximate_band.status===:ok
        tiny_rhs=1.0e-12.*base_rhs
        one_iteration=Solver.gs_native_band_inverse_v1(G,node_rz,tiny_rhs;
            restart=1,max_iterations=1,max_refinements=0,
            relative_tolerance=1.0e-10,radius_r=0,radius_z=0,
            factorization=approximate_band)
        @test one_iteration.status===:numerical_fail
        @test one_iteration.reason===:gmres_iteration_limit
        @test one_iteration.true_residual_available
        rhs_scale=norm(approximate_band.factor\tiny_rhs)
        @test one_iteration.preconditioned_rhs_norm≈rhs_scale rtol=1.0e-14 atol=0.0
        normalized_correction=one_iteration.gmres.solution
        restored_trial=rhs_scale.*normalized_correction
        expected_true_residual=tiny_rhs-G*restored_trial
        expected_true_norm=norm(expected_true_residual)
        expected_true_relative=expected_true_norm/norm(tiny_rhs)
        @test one_iteration.true_residual_norm≈expected_true_norm rtol=1.0e-12 atol=0.0
        @test one_iteration.true_relative_residual≈expected_true_relative rtol=1.0e-12 atol=0.0
        @test one_iteration.true_relative_residual>1.0e-10
    end

    @testset "native FD3 surrogate controls against full G" begin
        nr=2; nz=2; n=nr*nz
        Raxis=[1.0,2.0]; Zaxis=[-0.5,0.5]; native_ids=collect(1:n)
        rz=NTuple{2,Int}[(1,1),(1,2),(2,1),(2,2)]
        payload=Solver.ExactRowPivotGSFD3PayloadV1(Raxis,Zaxis,native_ids,
            trues(n),1.0,1.5,(6,7),(1,9))
        state=zeros(Float64,16)
        state[1]=0.2; state[6]=1.0; state[7]=0.0; state[9]=0.1
        for k in native_ids
            state[4k]=0.25
        end

        # Small, nonsymmetric actual operator with the native grid ordering;
        # its perturbed diagonal and couplings differ from the FD3 surrogate.
        Irow=Int[]; Jcol=Int[]; values=Float64[]
        for ir in 1:nr, iz in 1:nz
            row=(ir-1)*nz+iz
            push!(Irow,row); push!(Jcol,row); push!(values,8.0+0.2row)
            ir<nr && (push!(Irow,row);push!(Jcol,row+nz);push!(values,-0.25))
            ir>1 && (push!(Irow,row);push!(Jcol,row-nz);push!(values,-0.20))
            iz<nz && (push!(Irow,row);push!(Jcol,row+1);push!(values,-0.35))
            iz>1 && (push!(Irow,row);push!(Jcol,row-1);push!(values,-0.30))
        end
        Graw=sparse(Irow,Jcol,values,n,n)
        row_scales=[0.7,1.4,0.9,1.8]
        gs_column_scales=[1.1,0.6,1.5,0.8]
        G=spdiagm(0=>1.0 ./ row_scales)*Graw*spdiagm(0=>gs_column_scales)
        factor=Solver._gs_native_fd3_factor_v1(G,rz,payload,state,row_scales,
            gs_column_scales,Int(64*1024^2))
        @test factor.status===:ok
        @test factor.preconditioner_kind===:scaled_fd3_plus_exact_diagonal_reaction
        @test norm(factor.factor\ones(n)-G\ones(n))>1.0e-4

        for transpose_system in (false,true), rhs_scale in (1.0,1.0e-12,1.0e6,0.0)
            rhs=rhs_scale.*[1.0,-2.0,0.5,3.0]
            operator=transpose_system ? transpose(G) : G
            direct=operator\rhs
            solved=Solver.gs_native_band_inverse_v1(G,rz,rhs;
                transpose_system=transpose_system,restart=32,max_iterations=512,
                max_refinements=2,relative_tolerance=1.0e-10,
                max_auxiliary_bytes=Int(64*1024^2),factorization=factor)
            @test solved.status===:ok
            @test norm(solved.solution-direct)<=1.0e-10*max(norm(direct),1.0e-300)
            residual=rhs-operator*solved.solution
            relative_residual=iszero(norm(rhs)) ? norm(residual) : norm(residual)/norm(rhs)
            @test relative_residual<=1.0e-10
        end

        wrong_order=Solver._gs_native_fd3_factor_v1(G,reverse(rz),payload,state,
            row_scales,gs_column_scales,Int(64*1024^2))
        @test wrong_order.status===:numerical_fail
        @test wrong_order.reason===:fd3_native_axis_order_mismatch
        wrong_shape=Solver._gs_native_fd3_factor_v1(G[1:3,1:3],rz,payload,state,
            row_scales,gs_column_scales,Int(64*1024^2))
        @test wrong_shape.status===:numerical_fail
        @test wrong_shape.reason===:fd3_grid_G_shape_mismatch
        wrong_scale=copy(row_scales); wrong_scale[2]=0.0
        scale_rejected=Solver._gs_native_fd3_factor_v1(G,rz,payload,state,wrong_scale,
            gs_column_scales,Int(64*1024^2))
        @test scale_rejected.status===:numerical_fail
        @test scale_rejected.reason===:fd3_scaled_G_scale_shape_or_value_mismatch

        # Reach the mapped exact-row-pivot candidate path with the same tiny
        # FD3 payload and scaled full-G block. The result remains an incomplete,
        # diagnostic step and carries no full-G rank certificate.
        columns=collect(1:16)
        gs_columns=4 .* native_ids
        column_groups=([1],gs_columns,[2],[3],[5])
        pivot_columns=vcat(column_groups...)
        free_columns=setdiff(columns,pivot_columns)
        map_rows=([1],[2,3,4,5],[6],[7],[8])
        map_row_ids=String["normalization"]
        append!(map_row_ids,["diagnostic:GS4:node_$(k)" for k in native_ids])
        append!(map_row_ids,["scalar_a","scalar_b","scalar_c"])
        Jraw=zeros(Float64,8,16)
        Jraw[1,1]=1.0; Jraw[2:5,gs_columns]=Graw
        Jraw[6,2]=1.0; Jraw[7,3]=1.0; Jraw[8,5]=1.0
        ls_scales=ones(Float64,8); ls_scales[2:5]=row_scales
        column_scales=collect(range(0.6,1.6;length=16))
        column_scales[gs_columns]=gs_column_scales
        Jscaled=spdiagm(0=>1.0 ./ ls_scales)*Jraw*spdiagm(0=>column_scales)
        equality_raw=zeros(Float64,9,16)
        for (i,col) in enumerate(free_columns)
            equality_raw[i,col]=1.0
        end
        equality_raw[9,gs_columns[1]]=0.3
        equality_raw[9,free_columns[1]]=0.2
        equality_scaled=equality_raw*spdiagm(0=>column_scales)
        target_direction=[0.01*(i-4) for i in columns]
        raw_residual=ls_scales.*(-(Jscaled*target_direction))
        equality_residual=-(equality_scaled*target_direction)
        candidate_hash=repeat("f",64)
        partition=Solver.weighted_residual_kkt_partition_v1(
            candidate_hash=candidate_hash,
            consumer_identity=(candidate_hash=candidate_hash,consumer_id="test-only/fd3-mapped-step"),
            least_squares_row_ids=Tuple(map_row_ids),least_squares_residual=raw_residual,
            least_squares_jacobian=sparse(Jraw),least_squares_row_scales=ls_scales,
            equality_row_ids=Tuple("equality_$(i)" for i in 1:9),
            equality_row_scales=ones(9),equality_residual=equality_residual,
            equality_jacobian=sparse(equality_raw))
        map=Solver.ExactRowPivotKKTMapV1(map_rows,column_groups,free_columns,(),
            Tuple(map_row_ids),Tuple("equality_$(i)" for i in 1:9);
            gs_native_rz=rz,gs_fd3_payload=payload)
        mapped_step=Solver.solve_weighted_residual_kkt_step_v1(partition;
            scaled_state=state,column_scales=column_scales,pressure_indices=(),
            stationarity_tolerance=1.0e-7,bound_dual_tolerance=1.0e-7,
            max_active_set_iterations=2,seconds=10.0,max_working_memory_bytes=Int(64*1024^2),
            exact_row_pivot_map=map,precomputed_scaled_jacobian=
                Solver._column_scaled_sparse_copy_v1(partition.scaled_least_squares_jacobian,column_scales))
        @test mapped_step.status===:ok
        @test mapped_step.step≈column_scales.*target_direction atol=1.0e-8 rtol=1.0e-8
        @test mapped_step.gs_preconditioner===:scaled_fd3_plus_exact_diagonal_reaction
        @test mapped_step.inverse_action_semantics===:full_G_true_residual_checked
        @test mapped_step.rank_certificate===:not_established_for_full_G
        inverse_reports=mapped_step.gs_inverse_solve_reports
        @test any(report->!report.transpose_system,inverse_reports)
        @test any(report->report.transpose_system,inverse_reports)
        @test all(report->report.true_relative_residual<=1.0e-10,inverse_reports)
    end
    println("gs_inverse_rhs_scale=pass classification=preparation/test_only/physical=false claim_ceiling=numerical_mechanism_only")
    nothing
end

function _assert_control_results(c)
    Base.@nospecialize c
    @testset "focused coupled-global numerical software controls" begin
        _single_region_controls()
        @test POLICY.acceptance_ref == CONTROL_ACCEPTANCE_REF
        @test POLICY.contract_source_path == CONTROL_SOURCE_PATH
        @test POLICY.contract_semantic_hash ==
            Solver._semantic_sha((acceptance_ref=CONTROL_ACCEPTANCE_REF,
                contract_source_path=CONTROL_SOURCE_PATH))
        @test (POLICY.max_updates, POLICY.wall_seconds, POLICY.residual_tolerance,
            POLICY.constraint_tolerance, POLICY.stationarity_tolerance,
            POLICY.bound_dual_tolerance, POLICY.complementarity_tolerance,
            POLICY.step_tolerance, POLICY.minimum_step, POLICY.armijo_fraction,
            POLICY.max_backtracks, POLICY.max_active_set_iterations,
            POLICY.stagnation_window) ==
            (12, 120.0, 1.0e-6, 1.0e-10, 1.0e-10, 1.0e-10, 1.0e-10,
                1.0e-12, 2.0^-20, 1.0e-4, 20, 16, 3)
        @test TEST_ONLY_CLASSIFICATION.physical_authority === false
        @test TEST_ONLY_CLASSIFICATION.physical_validation === false
        @test TEST_ONLY_CLASSIFICATION.engineering_validation === false
        @test TEST_ONLY_CLASSIFICATION.emits_evidence === false
        @test TEST_ONLY_CLASSIFICATION.grants_pass === false
        @test TEST_ONLY_CLASSIFICATION.claim_ceiling === :numerical_mechanism_only

        shared_model = _shared_scatter_model()
        shared_state = [0.7, 0.2, 0.4]
        shared = Solver.assemble_coupled_mhd_global_v1(shared_model, shared_state)
        shared_q = -shared_state[1] + 2.0 * shared_state[2] + 5.0 * shared_state[3]
        shared_edge = only(shared.raw_blocks.edge_equilibrium)
        shared_fd = Oracle.fd_jacobian(_shared_global_residual_oracle, shared_state)
        expected_edge_scatter = [0.0 0.0 0.0;
            0.25 -0.5 -1.25; -0.25 0.5 1.25]
        @test shared_model.shared_scatter === true
        @test shared_model.local_dof_to_global == _SHARED_DOF_MAPS
        @test shared_model.local_test_row_to_global == _SHARED_ROW_MAPS
        @test shared_model.equilibrium_row_scales === nothing
        @test size(shared.jacobian) == (3, 3)
        @test shared.residual ≈ _shared_global_residual_oracle(shared_state) atol=1.0e-12 rtol=0.0
        @test Matrix(shared.jacobian) ≈ shared_fd atol=1.0e-8 rtol=0.0
        @test shared_edge.minus_residual ≈ [shared_q, -0.25 * shared_q] atol=1.0e-12 rtol=0.0
        @test shared_edge.plus_residual ≈ [-shared_q, 0.25 * shared_q] atol=1.0e-12 rtol=0.0
        @test Matrix(shared_edge.global_jacobian) == expected_edge_scatter
        local_edge_fd = Oracle.fd_jacobian(z -> _shared_edge_residual_oracle(
            (minus=view(z, 1:2), plus=view(z, 3:4))),
            [shared_state[1], shared_state[2], shared_state[1], shared_state[3]])
        local_edge_blocks = [shared_edge.jacobian_minus_minus shared_edge.jacobian_minus_plus;
            shared_edge.jacobian_plus_minus shared_edge.jacobian_plus_plus]
        @test Matrix(local_edge_blocks) ≈ local_edge_fd atol=1.0e-8 rtol=0.0
        raw_equilibrium = Solver._equilibrium_system_v1(shared_model, shared)
        @test raw_equilibrium.residual == shared.residual
        @test raw_equilibrium.jacobian == shared.jacobian
        @test raw_equilibrium.row_scales === nothing
        @test !hasproperty(shared, :scaled_residual)

        # Scaling belongs to global test-row IDs after regional and edge blocks
        # have scatter-added. The independent FD oracle starts from the already
        # assembled global residual, so a local-before-scatter scale is rejected.
        row_scales = (2.0, 4.0, 8.0)
        scaled_model = _shared_scatter_model(row_scales=row_scales)
        scaled = Solver.assemble_coupled_mhd_global_v1(scaled_model, shared_state)
        expected_raw = _shared_global_residual_oracle(shared_state)
        expected_raw_jacobian = Oracle.fd_jacobian(
            _shared_global_residual_oracle, shared_state)
        expected_scaled_residual = expected_raw ./ collect(row_scales)
        scale_vector = collect(row_scales)
        expected_scaled_jacobian = Oracle.fd_jacobian(
            x -> _shared_global_residual_oracle(x) ./ scale_vector,
            shared_state)
        @test scaled_model.equilibrium_row_scales == row_scales
        @test scaled.residual ≈ expected_raw atol=1.0e-12 rtol=0.0
        @test Matrix(scaled.jacobian) ≈ expected_raw_jacobian atol=1.0e-8 rtol=0.0
        @test scaled.scaled_residual ≈ expected_scaled_residual atol=1.0e-12 rtol=0.0
        @test Matrix(scaled.scaled_jacobian) ≈ expected_scaled_jacobian atol=1.0e-8 rtol=0.0
        @test scaled.equilibrium_row_scales == row_scales
        @test scaled.equilibrium_row_scale_hash ==
            string(Solver.canonical_hash(row_scales))
        @test scaled.equality_residual == shared.equality_residual
        @test scaled.equality_jacobian == shared.equality_jacobian
        scaled_system = Solver._equilibrium_system_v1(scaled_model, scaled)
        expected_scaled_merit = 0.5 * (dot(expected_scaled_residual,
            expected_scaled_residual) + dot(scaled.equality_residual,
            scaled.equality_residual))
        @test Solver._merit(scaled_system.residual,
            scaled.equality_residual) ≈ expected_scaled_merit atol=1.0e-14 rtol=0.0
        @test maximum(abs, scaled_system.residual) ≈
            maximum(abs, expected_scaled_residual) atol=1.0e-14 rtol=0.0
        @test expected_scaled_merit < Solver._merit(expected_raw,
            scaled.equality_residual)
        scale_trace = Solver._equilibrium_trace_fields_v1(scaled_model, scaled)
        @test collect(scale_trace.raw_equilibrium_residual) ≈ expected_raw atol=1.0e-12 rtol=0.0
        @test scale_trace.raw_equilibrium_jacobian ==
            Solver._matrix_snapshot(scaled.jacobian)
        @test scale_trace.equilibrium_row_scales == row_scales
        @test collect(scale_trace.scaled_equilibrium_residual) ≈ expected_scaled_residual atol=1.0e-12 rtol=0.0
        @test scale_trace.scaled_equilibrium_jacobian ==
            Solver._matrix_snapshot(scaled.scaled_jacobian)

        # Compare the production KKT direction to a separate dense weighted
        # least-squares KKT system assembled from this scatter result. Select
        # one compatible equality row; the full fixture intentionally contains
        # an inconsistent conservation control and is not a solver case.
        J_weighted = Matrix(scaled.scaled_jacobian)
        f_weighted = collect(scaled.scaled_residual)
        C_weighted = Matrix(scaled.equality_jacobian[2:2, :])
        c_weighted = collect(scaled.equality_residual[2:2])
        H_weighted = transpose(J_weighted) * J_weighted
        weighted_kkt = [H_weighted transpose(C_weighted);
            C_weighted zeros(size(C_weighted, 1), size(C_weighted, 1))]
        weighted_rhs = vcat(-transpose(J_weighted) * f_weighted, -c_weighted)
        weighted_solution = weighted_kkt \ weighted_rhs
        expected_direction = weighted_solution[1:length(shared_state)]
        expected_multiplier = weighted_solution[(length(shared_state) + 1):end]
        weighted_step = Solver._active_kkt_step(scaled.scaled_jacobian,
            scaled.scaled_residual, C_weighted, c_weighted, shared_state, (), POLICY)
        @test weighted_step.status === :ok
        @test weighted_step.step ≈ expected_direction atol=1.0e-10 rtol=0.0
        weighted_lambda = J_weighted * expected_direction + f_weighted
        weighted_stationarity = maximum(abs,
            transpose(J_weighted) * weighted_lambda +
                transpose(C_weighted) * expected_multiplier)
        @test weighted_step.stationarity ≈ weighted_stationarity atol=1.0e-10 rtol=0.0

        @test_throws ArgumentError _shared_scatter_model(
            dof_maps=_SHARED_DOF_MAPS, row_maps=nothing)
        @test_throws ArgumentError _shared_scatter_model(
            dof_maps=((1, 2), (1,)), row_maps=_SHARED_ROW_MAPS)
        @test_throws ArgumentError _shared_scatter_model(
            dof_maps=((1, 2), (1, 4)), row_maps=_SHARED_ROW_MAPS)
        @test_throws ArgumentError _shared_scatter_model(row_scales=(2.0, 4.0))
        @test_throws ArgumentError _shared_scatter_model(row_scales=(2.0, 0.0, 8.0))
        @test_throws ArgumentError _shared_scatter_model(row_scales=(2.0, -4.0, 8.0))
        @test_throws ArgumentError _shared_scatter_model(row_scales=(2.0, Inf, 8.0))
        @test_throws ArgumentError _shared_scatter_model(row_scales=(2.0, NaN, 8.0))
        @test_throws ArgumentError _shared_scatter_model(row_scales=())
        @test_throws ArgumentError _shared_scatter_model(row_scales=(2.0, true, 8.0))
        @test_throws ArgumentError _shared_scatter_model(
            row_scales=(2.0, 4.0, 8.0, 16.0))

        a = c.assembly
        @test a.status === :assembled
        @test a.candidate_hash == Oracle.CANDIDATE_HASH
        @test a.model_hash == c.model.model_hash
        @test a.residual == Oracle.expected_residual(Oracle.INITIAL_STATE)
        @test Matrix(a.jacobian) == Oracle.expected_residual_jacobian(Oracle.INITIAL_STATE)
        @test a.equality_residual == Oracle.expected_equalities(Oracle.INITIAL_STATE)
        @test Matrix(a.equality_jacobian) == Oracle.expected_equality_jacobian()
        @test a.conservation_residual == [0.0]
        @test a.conservation_defect == 0.0
        @test a.row_ownership == (regional=Oracle.REGION_IDS,
            interface_rows=1, outer_rows=2, conservation_rows=1)
        @test length(a.jacobian_checks.regional) == 2
        @test a.jacobian_checks.interface.passed
        @test a.jacobian_checks.interface == first(a.jacobian_checks.interfaces)
        @test length(a.jacobian_checks.interfaces) == 1
        @test length(a.jacobian_checks.outer) == 2
        checks = (a.jacobian_checks.regional..., a.jacobian_checks.interfaces...,
            a.jacobian_checks.outer..., a.jacobian_checks.global_conservation)
        @test length(checks) == 6
        @test all(check -> check.passed && check.max_abs_defect <= check.roundoff_tolerance, checks)
        @test a.physical_authority === false
        @test a.engineering_authority === false
        @test a.claim_ceiling === :numerical_mechanism_only

        topology = c.topology
        ta = topology.assembly
        tm = topology.model
        tr = topology.solution
        @test tm.region_ids == _GRAPH_REGION_IDS
        @test tm.region_dofs == _GRAPH_REGION_DOFS
        @test tm.shared_scatter === false
        @test tm.local_dof_to_global == ((1, 2, 3, 4), (5, 6, 7, 8, 9), (10, 11, 12, 13))
        @test tm.local_test_row_to_global == ((1, 2, 3), (4, 5, 6, 7), (8, 9, 10))
        @test tm.interface_edges == _GRAPH_EDGES
        @test length(ta.raw_blocks.regions) == 3
        @test Tuple(size(block.jacobian, 2) for block in ta.raw_blocks.regions) == (4, 5, 4)
        @test Tuple(edge.edge_id for edge in ta.raw_blocks.interfaces) ==
            ("core_to_mantle", "mantle_to_edge")
        @test Tuple(edge.constraint_ids for edge in ta.raw_blocks.interfaces) ==
            Tuple(edge.constraint_ids for edge in _GRAPH_EDGES)
        @test size(ta.jacobian) == (10, 13)
        @test size(ta.equality_jacobian) == (8, 13)
        @test length(ta.jacobian_checks.regional) == 3
        @test ta.jacobian_checks.interface == first(ta.jacobian_checks.interfaces)
        @test length(ta.jacobian_checks.interfaces) == 2
        @test length(ta.jacobian_checks.outer) == 3
        topology_checks = (ta.jacobian_checks.regional..., ta.jacobian_checks.interfaces...,
            ta.jacobian_checks.outer..., ta.jacobian_checks.global_conservation)
        @test length(topology_checks) == 9
        @test all(check -> check.passed && check.max_abs_defect <= check.roundoff_tolerance,
            topology_checks)
        @test ta.row_ownership.regional == _GRAPH_REGION_IDS
        @test ta.row_ownership.interface_rows == 4
        @test tr.status === :converged
        @test tr.solver_convergence_validated === false
        @test tr.independent_replay_validated === false
        @test tr.physical_validation === false
        @test tr.engineering_validation === false
        @test tr.emits_evidence === false && tr.grants_pass === false
        @test tr.claim_ceiling === :numerical_mechanism_only
        @test tr.final_metrics.max_residual <= POLICY.residual_tolerance
        @test tr.final_metrics.max_constraint <= POLICY.constraint_tolerance
        @test tr.final_metrics.conservation_defect <= POLICY.constraint_tolerance
        expected_u = 1.016 / 0.986
        expected_state = [expected_u, 0.2, 0.25 * expected_u, 0.1,
            expected_u, 0.2, 0.25 * expected_u, 0.1, 0.3,
            expected_u, 0.2, 0.25 * expected_u, 0.1]
        @test isapprox(collect(tr.final_state), expected_state; atol=1.0e-8, rtol=0.0)

        solve_row_scales = (0.8, 0.9, 1.1, 1.2, 0.95, 1.05,
            1.15, 0.85, 1.25, 1.0)
        scaled_solve_model = _three_region_model(
            equilibrium_row_scales=solve_row_scales)
        scaled_solution = Solver.solve_coupled_mhd_global_v1(
            scaled_solve_model, _GRAPH_INITIAL_STATE, POLICY)
        @test scaled_solution.status === :converged
        @test scaled_solution.capability_signature.physical_authority === false
        @test scaled_solution.capability_signature.engineering_authority === false
        @test scaled_solution.claim_ceiling === :numerical_mechanism_only
        @test scaled_solution.final_metrics.residual_tolerance_basis ===
            :scaled_equilibrium_rows
        @test scaled_solution.final_metrics.equilibrium_row_scales == solve_row_scales
        @test scaled_solution.final_metrics.equilibrium_row_scale_hash ==
            string(Solver.canonical_hash(solve_row_scales))
        scaled_final_evaluation = scaled_solution.raw_trace[end].evaluation
        scaled_final_residual = collect(
            scaled_final_evaluation.scaled_equilibrium_residual)
        raw_final_residual = collect(
            scaled_final_evaluation.raw_equilibrium_residual)
        @test scaled_solution.final_metrics.max_residual ≈
            maximum(abs, scaled_final_residual) atol=1.0e-12 rtol=0.0
        @test scaled_solution.final_metrics.max_raw_equilibrium_residual ≈
            maximum(abs, raw_final_residual) atol=1.0e-12 rtol=0.0
        @test scaled_solution.final_metrics.max_scaled_equilibrium_residual ≈
            maximum(abs, scaled_final_residual) atol=1.0e-12 rtol=0.0
        @test scaled_solution.final_metrics.max_scaled_equilibrium_residual <=
            POLICY.residual_tolerance
        @test all(hasproperty(entry.evaluation, :raw_equilibrium_residual) &&
            hasproperty(entry.evaluation, :scaled_equilibrium_residual)
            for entry in scaled_solution.raw_trace if hasproperty(entry, :evaluation))
        line_search_index = findfirst(entry -> hasproperty(entry, :line_search) &&
            entry.line_search !== nothing && entry.accepted,
            scaled_solution.raw_trace)
        @test line_search_index !== nothing
        if line_search_index !== nothing
            line_search_entry = scaled_solution.raw_trace[line_search_index]
            line_search_evaluation = line_search_entry.line_search.evaluation
            line_search_scaled = collect(
                line_search_evaluation.scaled_equilibrium_residual)
            line_search_equalities = collect(line_search_evaluation.equality_residual)
            @test line_search_entry.line_search.merit ≈
                Solver._merit(line_search_scaled, line_search_equalities) atol=1.0e-12 rtol=0.0
            @test line_search_evaluation.equilibrium_row_scales == solve_row_scales
            @test line_search_evaluation.raw_equilibrium_residual !=
                line_search_evaluation.scaled_equilibrium_residual
        end
        @test topology.replay.status === :replayed_exact
        @test topology.replay.raw_trace_match === true
        @test topology.replay.disposition_match === true
        reordered = _three_region_model(interface_edges=(_GRAPH_EDGES[2], _GRAPH_EDGES[1]))
        @test reordered.model_hash != tm.model_hash
        @test_throws ArgumentError _three_region_model(interface_edges=(_GRAPH_EDGES[1],))
        @test_throws ArgumentError _three_region_model(interface_edges=(
            merge(_GRAPH_EDGES[1], (plus_region_id="unknown",)), _GRAPH_EDGES[2]))
        @test_throws ArgumentError _three_region_model(interface_edges=(
            _GRAPH_EDGES[1], merge(_GRAPH_EDGES[2], (edge_id="core_to_mantle",))))
        @test tr.multiregion_closure === false

        bad_pressure = copy(Oracle.INITIAL_STATE)
        bad_pressure[2] = -0.125
        @test_throws ArgumentError Solver.assemble_coupled_mhd_global_v1(c.model, bad_pressure)

        @test length(c.absences) == 5
        @test Tuple(item.kind for item in c.absences) == Solver._REQUIRED_CLOSURES
        for item in c.absences
            @test item.assembled.status === :typed_absent
            @test item.assembled.missing_closures == (item.kind,)
            @test item.solved.status === :typed_absent
            @test item.solved.missing_closures == (item.kind,)
            @test isempty(item.solved.raw_trace)
            @test item.solved.solver_convergence_validated === false
            @test item.solved.independent_replay_validated === false
            @test item.solved.physical_validation === false
            @test item.solved.engineering_validation === false
            @test item.solved.emits_evidence === false
            @test item.solved.grants_pass === false
        end

        result = c.solution
        @test result.status === :converged
        @test result.solver_convergence_criteria_met === true
        @test result.solver_convergence_validated === false
        @test result.independent_replay_validated === false
        @test result.formal_consumer_connected === false
        @test result.multiregion_closure === false
        @test result.physical_validation === false
        @test result.engineering_validation === false
        @test result.emits_evidence === false
        @test result.grants_pass === false
        @test result.promotion_authority === false
        @test result.terminal_authority === false
        @test result.credible_physical_device_count == 0
        @test result.claim_ceiling === :numerical_mechanism_only
        @test result.updates == 1
        @test length(result.raw_trace) == 3
        @test isapprox(collect(result.final_state), [1.0, 0.0, 0.0, 1.0, 1.0, 0.0];
            atol=1.0e-12, rtol=0.0)
        @test result.final_metrics.max_residual <= POLICY.residual_tolerance
        @test result.final_metrics.max_constraint <= POLICY.constraint_tolerance
        @test result.final_metrics.conservation_defect <= POLICY.constraint_tolerance
        first_kkt_path = Tuple(step.active_bounds for step in result.raw_trace[1].kkt_active_set)
        @test first_kkt_path == ((), (2,))
        @test isapprox(collect(result.raw_trace[1].proposed_step),
            [0.0, -0.25, 0.0, 0.0, 0.25, 0.0]; atol=1.0e-12, rtol=0.0)
        @test result.raw_trace[2].accepted === true
        @test result.raw_trace[2].accepted_alpha == 1.0
        @test isapprox(collect(result.raw_trace[2].line_search.state),
            [1.0, 0.0, 0.0, 1.0, 1.0, 0.0]; atol=1.0e-12, rtol=0.0)
        @test result.raw_trace[3].update == 1

        @test c.replay.status === :replayed_exact
        @test c.replay.raw_trace_match === true
        @test c.replay.disposition_match === true
        @test c.replay.recorded_result_hash == result.result_hash
        @test c.replay.replayed_result_hash == result.result_hash
        @test c.replay.physical_authority === false
        @test c.replay.replayed_result.claim_ceiling === :numerical_mechanism_only

        disk_wire = _solver_result_wire(c)
        disk_bytes = collect(codeunits(Solver.canonical_json(disk_wire) * "\n"))
        decoded = _parse_solver_result_wire(disk_bytes)
        @test decoded.solver_result.result_hash == result.result_hash
        @test decoded.fixture.model_hash == c.model.model_hash
        @test decoded.topology_control.fixture.interface_edges == c.topology.model.interface_edges
        bad_result = merge(result, (final_state=ntuple(i ->
            result.final_state[i] + (i == 1 ? 0.125 : 0.0), length(result.final_state)),))
        bad_body = merge(_drop_wire_field(disk_wire, :wire_hash),
            (solver_result=bad_result,))
        bad_wire = _seal_solver_result_wire(bad_body)
        @test_throws ArgumentError _parse_solver_result_wire(
            collect(codeunits(Solver.canonical_json(bad_wire) * "\n")))

        @test c.released.status === :ok
        @test Tuple(step.active_bounds for step in c.released.steps) ==
            Oracle.EXPECTED_RELEASE_ACTIVE_SEQUENCE
        @test c.released.active_bounds == (2,)
        @test Tuple(c.released.step) == Oracle.EXPECTED_RELEASE_STEP
        @test length(c.released.constraint_multipliers) ==
            length(Oracle.EXPECTED_RELEASE_MULTIPLIER) &&
            maximum(abs.(collect(c.released.constraint_multipliers) .-
                collect(Oracle.EXPECTED_RELEASE_MULTIPLIER))) <= 2eps(Float64)
        @test c.released.stationarity <= POLICY.stationarity_tolerance
        @test c.released.dual_violation <= POLICY.bound_dual_tolerance
        @test c.released.complementarity <= POLICY.complementarity_tolerance

        expired_step = Solver._active_kkt_step(c.release.J, c.release.f,
            c.release.C, c.release.c, c.release.x, c.release.pressure_indices,
            (max_active_set_iterations=POLICY.max_active_set_iterations,
             stationarity_tolerance=POLICY.stationarity_tolerance,
             bound_dual_tolerance=POLICY.bound_dual_tolerance,
             deadline_ns=typemin(Int64)))
        @test expired_step.status === :resource_interruption
        @test expired_step.reason === :wall_time_budget

        @test c.stagnation.status === :numerical_fail
        @test c.stagnation.failure.kind === :stagnation
        @test c.stagnation.updates == POLICY.stagnation_window
        @test c.stagnation.physical_validation === false
        @test c.stagnation.engineering_validation === false
        @test c.stagnation.emits_evidence === false
        @test c.stagnation.grants_pass === false
        @test c.stagnation.claim_ceiling === :numerical_mechanism_only

        @test c.inconsistent.status === :numerical_fail
        @test c.inconsistent.reason === :rank_deficient_kkt_system
        @test hasproperty(c.inconsistent, :steps)
        singular_kkt_rank = only(c.inconsistent.steps).kkt_rank
        @test singular_kkt_rank.fallback_status === :numerical_fail
        @test singular_kkt_rank.fallback_method === :constraint_nullspace_pivoted_qr
        @test singular_kkt_rank.fallback_detail.constraint_rows == 2
        @test singular_kkt_rank.fallback_detail.variables == 1

        _assert_r22_control_results(c.r22_fifth)
    end
    c
end

function _policy_record()
    (acceptance_ref=POLICY.acceptance_ref,
     contract_source_path=POLICY.contract_source_path,
     contract_semantic_hash=POLICY.contract_semantic_hash,
     max_updates=POLICY.max_updates,
     wall_seconds=POLICY.wall_seconds,
     residual_tolerance=POLICY.residual_tolerance,
     constraint_tolerance=POLICY.constraint_tolerance,
     stationarity_tolerance=POLICY.stationarity_tolerance,
     bound_dual_tolerance=POLICY.bound_dual_tolerance,
     complementarity_tolerance=POLICY.complementarity_tolerance,
     step_tolerance=POLICY.step_tolerance,
     minimum_step=POLICY.minimum_step,
     armijo_fraction=POLICY.armijo_fraction,
     max_backtracks=POLICY.max_backtracks,
     max_active_set_iterations=POLICY.max_active_set_iterations,
     stagnation_window=POLICY.stagnation_window,
     policy_hash=POLICY.policy_hash)
end

function _observation(c)
    Solver.canonical_json((
        schema="focused-coupled-global-numerical-control-v1",
        classification=TEST_ONLY_CLASSIFICATION,
        authorities=(physical=false, engineering=false, evidence=false, pass=false),
        policy=_policy_record(),
        assembly=(status=c.assembly.status,
            model_hash=c.assembly.model_hash,
            residual=Tuple(c.assembly.residual),
            jacobian=Solver._matrix_snapshot(c.assembly.jacobian),
            equality_residual=Tuple(c.assembly.equality_residual),
            equality_jacobian=Solver._matrix_snapshot(c.assembly.equality_jacobian),
            conservation_defect=c.assembly.conservation_defect,
            row_ownership=c.assembly.row_ownership,
            jacobian_checks=c.assembly.jacobian_checks),
        solve=(status=c.solution.status, result_hash=c.solution.result_hash,
            initial_state=c.solution.initial_state, final_state=c.solution.final_state,
            updates=c.solution.updates, final_metrics=c.solution.final_metrics,
            raw_trace=c.solution.raw_trace, authority=(physical=false,
                engineering=false, evidence=false, pass=false)),
        topology_control=(region_ids=c.topology.model.region_ids,
            region_dofs=c.topology.model.region_dofs,
            interface_edges=c.topology.model.interface_edges,
            model_hash=c.topology.model.model_hash,
            assembly=(jacobian_size=size(c.topology.assembly.jacobian),
                equality_jacobian_size=size(c.topology.assembly.equality_jacobian),
                row_ownership=c.topology.assembly.row_ownership,
                edge_checks=c.topology.assembly.jacobian_checks.interfaces),
            solve=(status=c.topology.solution.status,
                result_hash=c.topology.solution.result_hash,
                initial_state=c.topology.solution.initial_state,
                final_state=c.topology.solution.final_state,
                final_metrics=c.topology.solution.final_metrics,
                authority=(physical=false, engineering=false, evidence=false, pass=false)),
            same_process_replay=(status=c.topology.replay.status,
                raw_trace_match=c.topology.replay.raw_trace_match,
                disposition_match=c.topology.replay.disposition_match)),
        same_process_api_replay=(status=c.replay.status,
            raw_trace_match=c.replay.raw_trace_match,
            disposition_match=c.replay.disposition_match,
            recorded_result_hash=c.replay.recorded_result_hash,
            replayed_result_hash=c.replay.replayed_result_hash),
        separate_process_contract=(mode_independent_payload=true,
            comparison="canonical JSON bytes must match between producer and new Julia process"),
        typed_absent=Tuple((kind=item.kind, assemble_status=item.assembled.status,
            solve_status=item.solved.status, missing=item.solved.missing_closures)
            for item in c.absences),
        active_set_release=(status=c.released.status,
            sequence=Tuple(step.active_bounds for step in c.released.steps),
            final_active=c.released.active_bounds,
            step=Tuple(c.released.step),
            multipliers=Tuple(c.released.constraint_multipliers),
            stationarity=c.released.stationarity,
            dual_violation=c.released.dual_violation,
            complementarity=c.released.complementarity),
        stagnation=(status=c.stagnation.status, failure=c.stagnation.failure,
            updates=c.stagnation.updates, raw_trace=c.stagnation.raw_trace),
        inconsistent_equalities=(status=c.inconsistent.status,
            reason=c.inconsistent.reason, active=c.inconsistent.active,
            steps=c.inconsistent.steps),
        no_candidate_or_physics_credit=true,
    ))
end

function _checked_observation()
    c = _controls()
    _assert_control_results(c)
    observation = _observation(c)
    observation
end

function _weighted_residual_kkt_partition_controls()
    @testset "weighted residual KKT partition independent matrix oracle" begin
        candidate_hash = repeat("a", 64)
        consumer_identity = (candidate_hash=candidate_hash,
            consumer_id="test-only/weighted-residual-kkt-partition-v1")
        ls_ids = ("equilibrium:u", "equilibrium:f")
        equality_ids = ("hard:interface",)
        raw_f = [3.0, -4.0]
        raw_J = [1.0 0.0; 0.0 2.0]
        scales = (2.0, 4.0)
        hard_c = [5.0]
        hard_C = [1.0 1.0]

        function partition_call(; row_ids=ls_ids, residual=raw_f, jacobian=raw_J,
                row_scales=scales, eq_ids=equality_ids, eq_residual=hard_c,
                eq_jacobian=hard_C, identity=consumer_identity,
                candidate=candidate_hash)
            Solver.weighted_residual_kkt_partition_v1(
                candidate_hash=candidate, consumer_identity=identity,
                least_squares_row_ids=row_ids,
                least_squares_residual=residual,
                least_squares_jacobian=jacobian,
                least_squares_row_scales=row_scales,
                equality_row_ids=eq_ids, equality_residual=eq_residual,
                equality_jacobian=eq_jacobian)
        end

        partition = partition_call()
        expected_scaled_f = [1.5, -1.0]
        expected_scaled_J = [0.5 0.0; 0.0 0.5]
        # Independent hand calculation: 0.5*((1.5)^2+(-1)^2+5^2)=14.125;
        # J_scaled' * f_scaled + C' * c = [0.75,-0.5] + [5,5].
        @test partition.raw_least_squares_residual == raw_f
        @test Matrix(partition.raw_least_squares_jacobian) == raw_J
        @test partition.scaled_least_squares_residual == expected_scaled_f
        @test Matrix(partition.scaled_least_squares_jacobian) == expected_scaled_J
        @test partition.least_squares_row_ids == ls_ids
        @test partition.equality_row_ids == equality_ids
        @test partition.identity.schema == "weighted-residual-kkt-partition-v1"
        @test partition.identity.candidate_hash == candidate_hash
        @test partition.consumer_identity_hash ==
            string(Solver.canonical_hash(consumer_identity))
        @test partition.identity.consumer_identity_hash == partition.consumer_identity_hash
        @test partition.least_squares_row_scales == scales
        @test partition.least_squares_row_scale_hash ==
            string(Solver.canonical_hash(scales))
        @test partition.identity.least_squares_row_scale_hash ==
            partition.least_squares_row_scale_hash
        expected_row_identity_hash = string(Solver.canonical_hash(
            (least_squares=ls_ids, equalities=equality_ids)))
        @test partition.row_identity_hash == expected_row_identity_hash
        @test partition.identity.row_identity_hash == expected_row_identity_hash
        @test partition.equality_residual == hard_c
        @test Matrix(partition.equality_jacobian) == hard_C
        preconditioned_hard=Solver.weighted_residual_kkt_partition_v1(
            candidate_hash=candidate_hash,consumer_identity=consumer_identity,
            least_squares_row_ids=ls_ids,least_squares_residual=raw_f,
            least_squares_jacobian=raw_J,least_squares_row_scales=scales,
            equality_row_ids=equality_ids,equality_row_scales=(10.0,),
            equality_residual=hard_c,equality_jacobian=hard_C)
        @test preconditioned_hard.raw_equality_residual==hard_c
        @test preconditioned_hard.equality_residual==[0.5]
        @test Matrix(preconditioned_hard.equality_jacobian)==[0.1 0.1]
        @test preconditioned_hard.equality_row_scale_hash==string(Solver.canonical_hash((10.0,)))
        @test partition.merit == 14.125
        @test partition.gradient ≈ [5.75, 4.5] atol=1.0e-14 rtol=0.0
        @test partition.physical_authority === false
        @test partition.emits_evidence === false
        @test partition.claim_ceiling === :numerical_mechanism_only

        @test_throws ArgumentError partition_call(row_ids=("equilibrium:u",
            "equilibrium:u"))
        @test_throws ArgumentError partition_call(eq_ids=("equilibrium:u",))
        @test_throws ArgumentError partition_call(row_ids=("equilibrium:u",))
        @test_throws ArgumentError partition_call(row_scales=(2.0,))
        @test_throws ArgumentError partition_call(eq_residual=[5.0, 6.0])
        @test_throws ArgumentError partition_call(eq_jacobian=zeros(1, 1))
        @test_throws ArgumentError partition_call(identity=(candidate_hash=repeat("b", 64),
            consumer_id="test-only/weighted-residual-kkt-partition-v1"))
    end

    @testset "independent active pressure-bound KKT oracle" begin
        candidate_hash=repeat("c",64)
        identity=(candidate_hash=candidate_hash,
            consumer_id="test-only/active-pressure-bound-kkt-oracle-v1")
        # min 1/2 ||p + f||^2, f=(-2,1), x=(1,0.25), p₂ >= -0.25.
        # The unconstrained minimizer (2,-1) violates the pressure bound;
        # the exact constrained minimizer is (2,-0.25), with residual (0,0.75)
        # and lower-bound multiplier mu=-0.75 under the solver sign convention.
        J=[1.0 0.0;0.0 1.0]
        f=[-2.0,1.0]
        x=[1.0,0.25]
        partition=Solver.weighted_residual_kkt_partition_v1(
            candidate_hash=candidate_hash,consumer_identity=identity,
            least_squares_row_ids=("oracle:u","oracle:p"),
            least_squares_residual=f,least_squares_jacobian=J,
            least_squares_row_scales=(1.0,1.0),
            equality_row_ids=(),equality_residual=Float64[],
            equality_jacobian=zeros(0,2))
        result=Solver.solve_weighted_residual_kkt_step_v1(partition;
            scaled_state=x,column_scales=(2.0,3.0),pressure_indices=(2,),
            stationarity_tolerance=1.0e-12,bound_dual_tolerance=1.0e-12,
            max_active_set_iterations=4)
        reusable_J=partition.scaled_least_squares_jacobian*spdiagm(0=>[2.0,3.0])
        result_reuse=Solver.solve_weighted_residual_kkt_step_v1(partition;
            scaled_state=x,column_scales=(2.0,3.0),pressure_indices=(2,),
            stationarity_tolerance=1.0e-12,bound_dual_tolerance=1.0e-12,
            max_active_set_iterations=4,precomputed_scaled_jacobian=reusable_J)
        @test result_reuse.status==result.status
        @test result_reuse.step==result.step
        @test_throws ArgumentError Solver.solve_weighted_residual_kkt_step_v1(partition;
            scaled_state=x,column_scales=(2.0,3.0),pressure_indices=(2,),
            stationarity_tolerance=1.0e-12,bound_dual_tolerance=1.0e-12,
            max_active_set_iterations=4,precomputed_scaled_jacobian=sparse([1.0 0.0;0.0 1.0]))
        expected_step=[2.0,-0.25]
        expected_residual=J*expected_step+f
        expected_mu=-0.75
        @test partition.identity.solver_semantic_hash ==
            Solver.weighted_residual_kkt_step_identity_v1().solver_semantic_hash
        @test partition.scaled_least_squares_residual==f
        @test Matrix(partition.scaled_least_squares_jacobian)==J
        @test isempty(partition.equality_row_ids) && size(partition.equality_jacobian)==(0,2)
        @test result.status==:ok
        @test result.active_bounds==(2,)
        @test result.column_scales==(2.0,3.0)
        @test collect(result.step)≈expected_step atol=1.0e-12 rtol=0.0
        @test expected_step[2]>=-x[2]
        unconstrained_step=-f
        @test unconstrained_step[2]<-x[2] # unconstrained pressure direction is infeasible
        @test expected_residual≈[0.0,0.75] atol=1.0e-12 rtol=0.0
        oracle_mu=-dot(J[:,2],expected_residual)
        oracle_stationarity=[2.0,3.0].*(transpose(J)*expected_residual+[0.0,oracle_mu])
        oracle_dual_violation=max(0.0,oracle_mu)
        oracle_complementarity=abs((x[2]+expected_step[2])*(-oracle_mu))
        @test oracle_mu≈expected_mu atol=1.0e-12 rtol=0.0
        @test oracle_stationarity≈zeros(2) atol=1.0e-12 rtol=0.0
        @test result.stationarity≈norm(oracle_stationarity,Inf) atol=1.0e-12 rtol=0.0
        @test result.dual_violation≈oracle_dual_violation atol=1.0e-12 rtol=0.0
        @test result.complementarity≈oracle_complementarity atol=1.0e-12 rtol=0.0
        @test result.stationarity<=1.0e-12
        @test result.dual_violation<=1.0e-12
        @test result.complementarity<=1.0e-12
        @test partition.physical_authority===false && partition.claim_ceiling===:numerical_mechanism_only
        # Exercise the active-set preflight itself, including its preserved audit.
        cap_policy=(stationarity_tolerance=1e-12,bound_dual_tolerance=1e-12,
            max_active_set_iterations=4,gmres_restart=100,gmres_iteration_limit=1000,
            gmres_stagnation_cycles=5,max_working_memory_bytes=Int128(1))
        capped=Solver._active_kkt_step_matrix_free(sparse(J),f,spzeros(0,2),
            Float64[],x,ones(2),(2,),cap_policy)
        @test capped.status===:resource_interruption
        @test capped.reason===:matrix_free_working_set_cap
        @test capped.detail.scope===:kkt_workspace
        @test capped.detail.estimated_working_set_bytes>capped.detail.max_working_memory_bytes==1
        @test only(capped.steps).linear_solve.estimated_working_set_bytes==
            capped.detail.estimated_working_set_bytes
    end
    _bound_only_minimum_norm_controls()
    println("partition_oracle=pass classification=preparation/test_only/physical=false claim_ceiling=numerical_mechanism_only")
    nothing
end

function _safe_artifact_path(path::AbstractString)
    isdir(RUNS_ROOT) || throw(ArgumentError("test-only runs root is absent: $RUNS_ROOT"))
    target = abspath(path)
    root_real = realpath(RUNS_ROOT)
    parent = dirname(target)
    isdir(parent) || throw(ArgumentError("test-only artifact parent directory is absent: $parent"))
    parent_real = realpath(parent)
    separator = Sys.iswindows() ? "\\" : "/"
    startswith(lowercase(parent_real), lowercase(root_real * separator)) ||
        throw(ArgumentError("test-only artifacts must stay below $root_real"))
    target
end

function _write_new_artifact(path::AbstractString, bytes::Vector{UInt8})
    target = _safe_artifact_path(path)
    ispath(target) && throw(ArgumentError("refusing to overwrite an existing test-only artifact: $target"))
    open(target, "w") do io
        write(io, bytes)
        flush(io)
    end
    target
end

const _SOLVER_RESULT_WIRE_SCHEMA = "focused-coupled-global-solver-result-wire-v3"
const _SOLVER_RESULT_WIRE_FIELDS = (:schema, :classification,
    :fixture, :policy, :solver_result, :topology_control, :wire_hash)
const _COUPLED_RESULT_FIELDS = (:revision, :status, :candidate_hash, :model_hash,
    :policy_hash, :capability_signature, :missing_closures, :updates,
    :initial_state, :final_state, :final_metrics, :raw_trace, :failure,
    :solver_convergence_criteria_met, :solver_convergence_validated,
    :independent_replay_validated, :formal_consumer_connected,
    :multiregion_closure, :physical_validation, :engineering_validation,
    :emits_evidence, :grants_pass, :promotion_authority, :terminal_authority,
    :credible_physical_device_count, :claim_ceiling, :result_hash)

function _drop_wire_field(value::NamedTuple, field::Symbol)
    hasproperty(value, field) || throw(ArgumentError("wire field is absent: $field"))
    names = Tuple(key for key in keys(value) if key !== field)
    NamedTuple{names}(Tuple(getfield(value, key) for key in names))
end

function _seal_solver_result_wire(body::NamedTuple)
    hasproperty(body, :wire_hash) && throw(ArgumentError("wire body already has a hash"))
    merge(body, (wire_hash=string(Solver.canonical_hash(body)),))
end

function _wire_numeric_lexemes(text::String)
    bytes = collect(codeunits(text))
    tokens = String[]
    in_string = false
    escaped = false
    i = 1
    while i <= length(bytes)
        byte = bytes[i]
        if in_string
            if escaped
                escaped = false
            elseif byte == UInt8('\\')
                escaped = true
            elseif byte == UInt8('"')
                in_string = false
            end
            i += 1
        elseif byte == UInt8('"')
            in_string = true
            i += 1
        elseif byte == UInt8('-') || UInt8('0') <= byte <= UInt8('9')
            first = i
            i += 1
            while i <= length(bytes) &&
                    (UInt8('0') <= bytes[i] <= UInt8('9') ||
                     bytes[i] == UInt8('+') || bytes[i] == UInt8('-') ||
                     bytes[i] == UInt8('.') || bytes[i] == UInt8('e') ||
                     bytes[i] == UInt8('E'))
                i += 1
            end
            push!(tokens, String(bytes[first:i - 1]))
        else
            i += 1
        end
    end
    tokens
end

function _wire_native(value, number_lexemes::Vector{String}, number_index::Base.RefValue{Int})
    if value isa AbstractDict
        source_keys = Tuple(keys(value))
        raw_keys = Tuple(String(key) for key in source_keys)
        length(unique(raw_keys)) == length(raw_keys) ||
            throw(ArgumentError("duplicate wire object keys"))
        symbol_keys = Tuple(Symbol(key) for key in raw_keys)
        length(unique(symbol_keys)) == length(symbol_keys) ||
            throw(ArgumentError("wire keys collide after symbol conversion"))
        return NamedTuple{symbol_keys}(Tuple(_wire_native(value[key], number_lexemes, number_index)
            for key in source_keys))
    elseif value isa AbstractArray
        return Tuple(_wire_native(item, number_lexemes, number_index) for item in value)
    elseif value isa Bool || value === nothing || value isa AbstractString
        return value
    elseif value isa Integer || value isa AbstractFloat
        number_index[] <= length(number_lexemes) ||
            throw(ArgumentError("JSON3 number token walk disagrees with parsed solver result wire"))
        lexeme = number_lexemes[number_index[]]
        number_index[] += 1
        if occursin('.', lexeme) || occursin('e', lowercase(lexeme))
            return parse(Float64, lexeme)
        end
    end
    value
end

function _wire_exact_fields(value, expected::Tuple, label::AbstractString)
    value isa NamedTuple || throw(ArgumentError("$label must be a JSON object"))
    Set(keys(value)) == Set(expected) || throw(ArgumentError("$label fields differ from the frozen schema"))
    true
end

function _solver_result_wire(c)
    body = (schema=_SOLVER_RESULT_WIRE_SCHEMA,
        classification=TEST_ONLY_CLASSIFICATION,
        fixture=(candidate_hash=c.model.candidate_hash,
            model_hash=c.model.model_hash,
            provider_context_hash=c.model.provider_context_hash,
            policy_hash=POLICY.policy_hash,
            initial_state=Tuple(Float64.(Oracle.INITIAL_STATE))),
        policy=_policy_record(),
        solver_result=c.solution,
        topology_control=(fixture=(candidate_hash=c.topology.model.candidate_hash,
            model_hash=c.topology.model.model_hash,
            provider_context_hash=c.topology.model.provider_context_hash,
            region_ids=c.topology.model.region_ids,
            region_dofs=c.topology.model.region_dofs,
            interface_edges=c.topology.model.interface_edges,
            policy_hash=POLICY.policy_hash,
            initial_state=Tuple(_GRAPH_INITIAL_STATE)),
            solver_result=c.topology.solution))
    _seal_solver_result_wire(body)
end

function _solver_result_from_wire(value; state_length=length(Oracle.INITIAL_STATE))
    _wire_exact_fields(value, _COUPLED_RESULT_FIELDS, "solver result")
    typeof(value.revision) === String && typeof(value.status) === String &&
        typeof(value.candidate_hash) === String && typeof(value.model_hash) === String &&
        typeof(value.policy_hash) === String && typeof(value.updates) === Int &&
        value.initial_state isa Tuple && value.final_state isa Tuple &&
        value.raw_trace isa Tuple && typeof(value.result_hash) === String ||
        throw(ArgumentError("solver result field types differ from the frozen wire"))
    length(value.initial_state) == state_length &&
        all(x -> typeof(x) === Float64, value.initial_state) &&
        length(value.final_state) == state_length &&
        all(x -> typeof(x) === Float64, value.final_state) ||
        throw(ArgumentError("solver state wire must contain the exact Float64 coordinates"))
    value.status == "converged" && value.solver_convergence_criteria_met === true &&
        value.solver_convergence_validated === false &&
        value.independent_replay_validated === false &&
        value.formal_consumer_connected === false && value.multiregion_closure === false &&
        value.physical_validation === false && value.engineering_validation === false &&
        value.emits_evidence === false && value.grants_pass === false &&
        value.promotion_authority === false && value.terminal_authority === false &&
        value.credible_physical_device_count === 0 &&
        value.claim_ceiling == "numerical_mechanism_only" ||
        throw(ArgumentError("solver result status or claim ceiling is invalid"))
    body = _drop_wire_field(value, :result_hash)
    string(Solver.canonical_hash(body)) == value.result_hash ||
        throw(ArgumentError("serialized solver result hash mismatch"))
    merge(value, (status=Symbol(value.status),
        missing_closures=Tuple(Symbol(String(x)) for x in value.missing_closures),
        claim_ceiling=Symbol(value.claim_ceiling)))
end

function _solver_wire_hex_window(bytes::Vector{UInt8}, first::Int, last::Int)
    first > last && return ""
    join((lpad(string(bytes[i], base=16), 2, '0') for i in first:last), "")
end

function _solver_wire_escaped_window(bytes::Vector{UInt8}, first::Int, last::Int)
    first > last && return ""
    io = IOBuffer()
    for byte in bytes[first:last]
        if byte == 0x5c
            print(io, "\\\\")
        elseif byte == 0x22
            print(io, "\\\"")
        elseif 0x20 <= byte <= 0x7e
            print(io, Char(byte))
        else
            print(io, "\\x", lpad(string(byte, base=16), 2, '0'))
        end
    end
    String(take!(io))
end

function _solver_wire_mismatch_diagnostic(original::String, reencoded::String)
    original_bytes = collect(codeunits(original))
    reencoded_bytes = collect(codeunits(reencoded))
    common_length = min(length(original_bytes), length(reencoded_bytes))
    first_diff_offset = 0
    while first_diff_offset < common_length &&
            original_bytes[first_diff_offset + 1] == reencoded_bytes[first_diff_offset + 1]
        first_diff_offset += 1
    end
    original_left_first = max(1, first_diff_offset - 31)
    reencoded_left_first = max(1, first_diff_offset - 31)
    original_right_last = min(length(original_bytes), first_diff_offset + 32)
    reencoded_right_last = min(length(reencoded_bytes), first_diff_offset + 32)
    original_left_last = min(length(original_bytes), first_diff_offset)
    reencoded_left_last = min(length(reencoded_bytes), first_diff_offset)
    original_right_first = first_diff_offset + 1
    reencoded_right_first = first_diff_offset + 1
    "original_length=$(length(original_bytes)) original_sha256=$(_sha256(original_bytes)) " *
    "reencoded_length=$(length(reencoded_bytes)) reencoded_sha256=$(_sha256(reencoded_bytes)) " *
    "first_diff_offset_zero_based=$first_diff_offset " *
    "original_left_hex=$(_solver_wire_hex_window(original_bytes, original_left_first, original_left_last)) " *
    "original_left_escaped=\"$(_solver_wire_escaped_window(original_bytes, original_left_first, original_left_last))\" " *
    "original_right_hex=$(_solver_wire_hex_window(original_bytes, original_right_first, original_right_last)) " *
    "original_right_escaped=\"$(_solver_wire_escaped_window(original_bytes, original_right_first, original_right_last))\" " *
    "reencoded_left_hex=$(_solver_wire_hex_window(reencoded_bytes, reencoded_left_first, reencoded_left_last)) " *
    "reencoded_left_escaped=\"$(_solver_wire_escaped_window(reencoded_bytes, reencoded_left_first, reencoded_left_last))\" " *
    "reencoded_right_hex=$(_solver_wire_hex_window(reencoded_bytes, reencoded_right_first, reencoded_right_last)) " *
    "reencoded_right_escaped=\"$(_solver_wire_escaped_window(reencoded_bytes, reencoded_right_first, reencoded_right_last))\""
end

function _parse_solver_result_wire(bytes::Vector{UInt8})
    text = String(copy(bytes))
    parsed = try
        JSON3.read(text)
    catch err
        throw(ArgumentError("solver result wire is invalid JSON: $(sprint(showerror, err))"))
    end
    wire = _wire_native(parsed, _wire_numeric_lexemes(text), Ref(1))
    _wire_exact_fields(wire, _SOLVER_RESULT_WIRE_FIELDS, "solver result envelope")
    reencoded_text = Solver.canonical_json(wire) * "\n"
    reencoded_text == text || throw(ArgumentError(
        "solver result wire is not canonical JSON with one final newline; " *
        _solver_wire_mismatch_diagnostic(text, reencoded_text)))
    wire.schema == _SOLVER_RESULT_WIRE_SCHEMA ||
        throw(ArgumentError("unsupported solver result wire schema"))
    Solver.canonical_json(wire.classification) ==
        Solver.canonical_json(TEST_ONLY_CLASSIFICATION) ||
        throw(ArgumentError("solver result wire classification changed"))
    Solver.canonical_json(wire.policy) == Solver.canonical_json(_policy_record()) ||
        throw(ArgumentError("solver result wire policy changed"))
    _wire_exact_fields(wire.fixture, (:candidate_hash, :model_hash,
        :provider_context_hash, :policy_hash, :initial_state), "solver fixture binding")
    _wire_exact_fields(wire.topology_control, (:fixture, :solver_result),
        "topology control")
    topology_fixture = wire.topology_control.fixture
    _wire_exact_fields(topology_fixture, (:candidate_hash, :model_hash,
        :provider_context_hash, :region_ids, :region_dofs, :interface_edges,
        :policy_hash, :initial_state), "multi-region fixture binding")
    all(value -> typeof(value) === String, (topology_fixture.candidate_hash,
        topology_fixture.model_hash, topology_fixture.provider_context_hash,
        topology_fixture.policy_hash)) &&
        topology_fixture.region_ids isa Tuple &&
        all(value -> typeof(value) === String, topology_fixture.region_ids) &&
        topology_fixture.region_dofs isa Tuple &&
        all(value -> typeof(value) === Int && value > 0, topology_fixture.region_dofs) &&
        topology_fixture.interface_edges isa Tuple &&
        all(edge -> edge isa NamedTuple && Set(keys(edge)) ==
            Set((:edge_id, :minus_region_id, :plus_region_id, :constraint_ids)),
            topology_fixture.interface_edges) &&
        length(topology_fixture.region_ids) >= 3 &&
        length(topology_fixture.region_ids) == length(topology_fixture.region_dofs) &&
        length(topology_fixture.initial_state) == sum(topology_fixture.region_dofs) &&
        all(x -> typeof(x) === Float64, topology_fixture.initial_state) ||
        throw(ArgumentError("multi-region fixture has invalid ordered topology or state dimensions"))
    ordered_interface_edges = Tuple((edge_id=edge.edge_id,
        minus_region_id=edge.minus_region_id, plus_region_id=edge.plus_region_id,
        constraint_ids=edge.constraint_ids) for edge in topology_fixture.interface_edges)
    topology_fixture = merge(topology_fixture,
        (interface_edges=ordered_interface_edges,))
    typeof(wire.wire_hash) === String || throw(ArgumentError("wire hash must be a string"))
    body = _drop_wire_field(wire, :wire_hash)
    string(Solver.canonical_hash(body)) == wire.wire_hash ||
        throw(ArgumentError("solver result envelope hash mismatch"))
    result = _solver_result_from_wire(wire.solver_result)
    topology_result = _solver_result_from_wire(wire.topology_control.solver_result;
        state_length=length(topology_fixture.initial_state))
    fixture = wire.fixture
        typeof(fixture.candidate_hash) === String && typeof(fixture.model_hash) === String &&
        typeof(fixture.provider_context_hash) === String && typeof(fixture.policy_hash) === String &&
        fixture.initial_state isa Tuple &&
        length(fixture.initial_state) == length(Oracle.INITIAL_STATE) &&
        all(x -> typeof(x) === Float64, fixture.initial_state) ||
        throw(ArgumentError("solver fixture field types differ from the frozen wire"))
    (schema=wire.schema, classification=wire.classification,
        fixture=fixture, policy=wire.policy,
        solver_result=result,
        topology_control=(fixture=topology_fixture, solver_result=topology_result),
        wire_hash=wire.wire_hash)
end

function _produce(path::AbstractString)
    c = _controls()
    _assert_control_results(c)
    wire = _solver_result_wire(c)
    bytes = collect(codeunits(Solver.canonical_json(wire) * "\n"))
    target = _write_new_artifact(path, bytes)
    println("control=pass classification=preparation/test_only/physical=false claim_ceiling=numerical_mechanism_only")
    println("artifact=$target bytes=$(length(bytes)) sha256=$(_sha256(bytes))")
    0
end

function _replay(baseline_path::AbstractString, replay_path::AbstractString)
    baseline = abspath(baseline_path)
    isfile(baseline) || throw(ArgumentError("producer artifact is absent: $baseline"))
    root_real = realpath(RUNS_ROOT)
    baseline_parent = realpath(dirname(baseline))
    separator = Sys.iswindows() ? "\\" : "/"
    startswith(lowercase(baseline_parent), lowercase(root_real * separator)) ||
        throw(ArgumentError("producer artifact must be below $root_real"))
    expected = read(baseline)
    wire = _parse_solver_result_wire(expected)
    model = Oracle.test_model()
    fixture = wire.fixture
    fixture.candidate_hash == model.candidate_hash &&
        fixture.model_hash == model.model_hash &&
        fixture.provider_context_hash == model.provider_context_hash &&
        fixture.policy_hash == POLICY.policy_hash &&
        fixture.initial_state == Tuple(Float64.(Oracle.INITIAL_STATE)) ||
        throw(ArgumentError("serialized solver fixture no longer matches the bound test candidate"))
    replay = Solver.replay_coupled_mhd_global_v1(model, collect(fixture.initial_state),
        POLICY, wire.solver_result)
    replay.status === :replayed_exact && replay.raw_trace_match === true &&
        replay.disposition_match === true && replay.physical_authority === false ||
        throw(ArgumentError("fresh solver replay did not validate the saved result wire"))
    topology = wire.topology_control
    topology_model = _three_region_model()
    topology_fixture = topology.fixture
    topology_fixture.candidate_hash == topology_model.candidate_hash &&
        topology_fixture.model_hash == topology_model.model_hash &&
        topology_fixture.provider_context_hash == topology_model.provider_context_hash &&
        topology_fixture.region_ids == topology_model.region_ids &&
        topology_fixture.region_dofs == topology_model.region_dofs &&
        topology_fixture.interface_edges == topology_model.interface_edges &&
        topology_fixture.policy_hash == POLICY.policy_hash &&
        topology_fixture.initial_state == Tuple(_GRAPH_INITIAL_STATE) ||
        throw(ArgumentError("serialized multi-region graph does not match the bound test candidate"))
    topology_replay = Solver.replay_coupled_mhd_global_v1(topology_model,
        collect(topology_fixture.initial_state), POLICY, topology.solver_result)
    topology_replay.status === :replayed_exact && topology_replay.raw_trace_match === true &&
        topology_replay.disposition_match === true && topology_replay.physical_authority === false ||
        throw(ArgumentError("fresh process did not replay the ordered multi-region graph result"))
    target = _write_new_artifact(replay_path, expected)
    println("fresh_process_replay=exact_bytes artifact_driven=solver_result_wire multi_region_graph=3_regions/2_edges classification=preparation/test_only/physical=false claim_ceiling=numerical_mechanism_only")
    println("producer=$baseline producer_bytes=$(length(expected)) producer_sha256=$(_sha256(expected))")
    println("replay=$target replay_bytes=$(length(expected)) replay_sha256=$(_sha256(expected))")
    0
end

function main(args::Vector{String}=ARGS)
    try
        if isempty(args) || args[1] == "test"
            _checked_observation()
            println("control=pass classification=preparation/test_only/physical=false claim_ceiling=numerical_mechanism_only")
            return 0
        elseif length(args) == 1 && args[1] == "single-region-test"
            _single_region_controls()
            return 0
        elseif length(args) == 1 && args[1] == "gs-inverse-test"
            _gs_inverse_controls()
            return 0
        elseif length(args) == 1 && args[1] == "r22-test"
            println("R22_CONTROL_BEGIN=targeted")
            flush(stdout)
            r22 = _r22_fifth_attempt_control(emit_markers=true)
            _assert_r22_control_results(r22; emit_markers=true)
            println("r22_control=pass classification=preparation/test_only/physical=false claim_ceiling=numerical_mechanism_only")
            return 0
        elseif length(args) == 1 && args[1] == "partition-test"
            _weighted_residual_kkt_partition_controls()
            return 0
        elseif args[1] == "produce" && length(args) == 2
            result = _produce(args[2])
            return result
        elseif args[1] == "replay" && length(args) == 3
            result = _replay(args[2], args[3])
            return result
        end
        throw(ArgumentError("usage: focused_numerical_control_v1.jl test | single-region-test | gs-inverse-test | r22-test | partition-test | produce <new-runs-path> | replay <producer-path> <new-runs-path>"))
    catch err
        showerror(stderr, err)
        println(stderr)
        return 2
    end
end

end # module FocusedNumericalControlV1

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    exit(FocusedNumericalControlV1.main(ARGS))
end
