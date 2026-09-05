using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

module RuntimeV4AlgebraicSliceFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl"))
end

const F = RuntimeV4AlgebraicSliceFixture

function _slice_compiled()
    compile_candidate(F.candidate, F.registry;
        mission_payload=F.candidate.mission_contract_ref,
        bounds_payload=(scope="algebraic-residual-cli",),
        comparison_scope=("algebraic-residual",),
        scenario_scope=("zero-dimensional",))
end

function _slice_scenario()
    unit = UnitSignature()
    AlgebraicScenarioV4("zero",
        (StateValueV4(StateGeneRefV1("x"), 0.5, unit),
         StateValueV4(StateGeneRefV1("y"), -0.25, unit)))
end

@testset "RuntimeV4 algebraic vertical slice" begin
    compiled = _slice_compiled()
    compilation = compile_algebraic_residual_plan(compiled, F.registry)
    @test compilation.status == :ready
    plan = compilation.plan
    @test plan !== nothing
    scenario = _slice_scenario()
    provider = algebraic_residual_manifest(plan)
    report = execute_algebraic_once!(Dict{Digest256,Any}(), plan, scenario; provider=provider)
    @test report.result.status == :converged
    @test all(isapprox.(report.result.state_values, (2.0, 1.0); atol=1.0e-10))
    @test report.result.residual_norm <= 1.0e-10
    @test report.evidence.claim_ceiling == screen_only
    @test report.evidence.binding_provenance.constraint_subgraph_scope === true
    @test length(plan.ignored_edge_hashes) == 3
    @test !isempty(compiled.unresolved_nonterminals)
    @test !isempty(compiled.capability_obligations)
    @test report.evidence.status_vector.stage_outcome == pass
end

@testset "RuntimeV4 algebraic CLI preserves candidate gaps and screen ceiling" begin
    cli = normpath(joinpath(@__DIR__, "..", "scripts", "run_v4_algebraic_slice.jl"))
    project = Base.active_project()
    project === nothing && error("test requires an active Julia project")
    command = Cmd(vcat(collect(Base.julia_cmd().exec),
        ["--startup-file=no", "--project=$(project)", cli]))
    output = read(command, String)
    @test occursin("final_x=2.0", output)
    @test occursin("final_y=1.0", output)
    @test occursin("residuals=(0.0, 0.0)", output)
    @test occursin("claim_ceiling=screen_only", output)
    @test occursin("constraint_subgraph_scope=true", output)
    @test occursin("ignored_edge_count=3", output)
    @test occursin("compiled_unresolved_nonterminals=", output)
    @test occursin("non_slice_capability_gaps=", output)
    @test occursin("credible_physical_count=0", output)
    @test occursin("authority=withheld", output)
    @test occursin("p5_ready=false", output)
end
