"""Lightweight UP3 combination enumeration and holdout preparation tests."""

using Test
using FusionConceptAI

module CompositionEnumerationIsolatedV1
using FusionConceptAI
include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4", "CompositionSolvePlanV1.jl"))
end
const E = CompositionEnumerationIsolatedV1

_ed(s) = digest256_text(String(s))
_eu() = E.CompositionSolveUnitV1(:power, (0, 0, 0, 0, 0, 0, 0))
_es(s) = E.CompositionSolveSpaceV1(_ed(s), :scalar, 3, _ed("chart"))
_eb(provider=_ed("provider")) = E.CompositionSolveBindingV1(
    _ed("candidate"), _ed("subject"), _ed("mission"), _ed("scenario"),
    provider, _ed("code"), _ed("backend"), _ed("protocol"))
_ep() = E.CompositionSolveProtocolV1(_ed("protocol"), 20, 1e-8)

function _ec(ref, direction, space; label=ref, provider=_ed("provider"),
        unit=_eu())
    port = E.CompositionSolvePortV1(label, 1, direction, :power, unit,
        _es(space), "energy", "shared", direction === :output ? 1 : -1,
        direction === :output ? :source : :sink)
    E.CompositionSolveComponentV1(_ed(ref), provider, _ed("code"),
        _ed("backend"), direction === :input ? (port,) : (),
        direction === :output ? (port,) : ())
end

@testset "UP3 typed enumeration and deterministic holdout preparation" begin
    pool = (_ec("source-a", :output, "space-a"),
        _ec("sink-a", :input, "space-a"),
        _ec("source-b", :output, "space-b"),
        _ec("sink-b", :input, "space-b"))
    split = _ed("frozen-preparation-split")
    result = E.enumerate_composition_solve(_eb(), pool, _ep();
        split_ref=split)
    @test result.status === :prepared
    @test result.claim_ceiling === :contract_only
    @test length(result.build) == 1
    @test length(result.holdout) == 1
    @test length(result.cases) == 11  # six pairs, four triples, one quadruple
    @test all(a.outcome.status === :ready for a in (result.build..., result.holdout...))
    @test all(length(a.plan.edges) == 1 for a in (result.build..., result.holdout...))
    @test all(a.outcome.provider_invocation_count == 0 &&
        a.outcome.solver_invocation_count == 0 for a in (result.build..., result.holdout...))
    @test E.select_composition_solve(result, result.build[1].outcome.input_hash) === result.build[1]
    @test E.select_composition_solve(result, result.holdout[1].outcome.input_hash) === nothing
    @test any(c.reason === :disconnected for c in result.cases)
    @test any(c.reason === :structural_reject for c in result.cases)

    renamed = (_ec("source-a", :output, "space-a"; label="erased-1"),
        _ec("sink-a", :input, "space-a"; label="erased-2"),
        _ec("source-b", :output, "space-b"; label="erased-3"),
        _ec("sink-b", :input, "space-b"; label="erased-4"))
    replay = E.enumerate_composition_solve(_eb(), reverse(renamed), _ep();
        split_ref=split)
    @test replay.split_hash == result.split_hash
    @test Tuple(a.outcome.input_hash for a in replay.build) ==
        Tuple(a.outcome.input_hash for a in result.build)
    @test Tuple(a.outcome.input_hash for a in replay.holdout) ==
        Tuple(a.outcome.input_hash for a in result.holdout)

    # A matching account sum cannot turn disconnected typed routes into a
    # legal composition; an unmatched unit fails at the admission boundary.
    bad_unit = (_ec("source-a", :output, "space-a"),
        _ec("sink-a", :input, "space-a";
            unit=E.CompositionSolveUnitV1(:power, (1, 0, 0, 0, 0, 0, 0))))
    rejected = E.enumerate_composition_solve(_eb(), bad_unit, _ep();
        split_ref=split)
    @test rejected.status === :insufficient_legal_combinations
    @test isempty(rejected.holdout)
    @test rejected.cases[1].reason === :structural_reject
    @test any(f.code === :unmatched_port for f in rejected.cases[1].admission.plan.failures)

    missing = (_ec("source-a", :output, "space-a"; provider=nothing),
        _ec("sink-a", :input, "space-a"; provider=nothing))
    deferred = E.enumerate_composition_solve(_eb(nothing), missing, _ep();
        split_ref=split)
    @test deferred.status === :insufficient_legal_combinations
    @test length(deferred.build) == 1
    @test deferred.build[1].outcome.status === :terminal_deferred
    @test E.select_composition_solve(deferred,
        deferred.build[1].outcome.input_hash) === nothing
    @test any(occursin("provider_missing:", r) for r in deferred.build[1].outcome.reasons)

    @test_throws ArgumentError E.enumerate_composition_solve(_eb(),
        (pool[1], pool[1]), _ep(); split_ref=split)
    @test_throws ArgumentError E.enumerate_composition_solve(_eb(), pool,
        _ep(); holdout_count=-1, split_ref=split)
end
