using Test
using Pkg
using LinearAlgebra
Pkg.activate(joinpath(@__DIR__, ".."))
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedTimeResidual.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "fixtures", "RuntimeV4", "runtime_v4_typed_time_fixture.jl"))

@testset "typed time residual D1.1 compiler" begin
    @test ttr_compiled isa CompiledCandidatePrefixV4
    @test ttr_compiled.mechanism_graph == ttr_payload.operator_graph
    @test length(ttr_payload.states) == 2
    @test length(ttr_graph.hyperedges) == 4
    @test all(e isa AtomicMIMOHyperedgeV1 for e in ttr_graph.hyperedges)
    @test ttr_g1.role === governing
    @test ttr_a1.role === additive
    @test length(ttr_g1.program.roots) == 2
    @test length(ttr_g2.program.roots) == 2
    @test ttr_g1.program.nodes[ttr_g1.program.roots[1]].operator_ref.qualified.id == "IDENTITY"
    @test ttr_g1.program.nodes[ttr_g1.program.roots[2]].operator_ref.qualified.id == "ADD"
    @test ttr_m1.nodes[3].output_type.temporal_type.derivative_order == 1
    @test ttr_r1.nodes[5].output_type.temporal_type.derivative_order == 0
    @test canonical_hash(ttr_g1) == ttr_bindings[1].governing_edge_hash
    @test canonical_hash(ttr_a2) == ttr_bindings[2].rhs_edge_hash
    plan = compile_typed_time_residual_plan(ttr_compiled, ttr_registry; row_bindings=ttr_bindings)
    @test plan isa TypedTimeResidualPlanV4
    @test plan.form.mass_matrix == [2.0 1.0; 1.0 2.0]
    @test plan.form.mass_matrix != Matrix{Float64}(I, 2, 2)
    @test plan.compiled_prefix_hash == ttr_compiled.prefix_hash
    @test plan.form.state_refs == ttr_refs
    @test_throws ArgumentError compile_typed_time_residual_plan(ttr_compiled, ttr_registry;
        row_bindings=(ttr_bindings[1], ttr_bindings[1]))
    @test_throws ArgumentError compile_typed_time_residual_plan(ttr_compiled, ttr_registry;
        row_bindings=(TimeResidualRowBindingV4(ttr_refs[1], canonical_hash(ttr_g1), 1,
            canonical_hash(ttr_a1), 1), ttr_bindings[2]))
    @test canonical_hash(plan.form) == plan.form.form_hash
    @test_throws MethodError TypedTimeResidualFormV4(ttr_refs, (), (), zeros(2, 2), digest256_text("x"))
    @test_throws MethodError TypedTimeResidualPlanV4(ttr_compiled.prefix_hash, plan.form,
        TimeIntegrationProtocolV4(), digest256_text("x"))
    normal = integrate_typed_time_residual(plan, ttr_scenario)
    @test normal.status == :integrated
    @test length(normal.times) - 1 == 100
    @test normal.rhs_evaluations == 800
    @test all(isfinite, reduce(vcat, (collect(s) for s in normal.states)))
    @test abs(sum(normal.states[end]) - sum(normal.states[1])) <= 1e-12
    @test normal.residual_norm <= 1e-10
    @test normal.trajectory_hash == canonical_hash((times=normal.times, states=normal.states))
    @test normal.result_hash == integrate_typed_time_residual(plan, ttr_scenario).result_hash
    hs = (0.2, 0.1, 0.05)
    runs = [integrate_typed_time_residual(derive_typed_time_residual_plan(plan,
        TimeIntegrationProtocolV4(:fixed_rk4, h, 1000)),
        TimeIntegrationScenarioV4("h", 0.0, 1.0, ttr_time_unit,
            (StateValueV4(ttr_refs[1], 1.0, ttr_unit), StateValueV4(ttr_refs[2], 0.0, ttr_unit))),
        ) for h in hs]
    exact = ((1 + exp(-2)) / 2, (1 - exp(-2)) / 2)
    errors = [maximum(abs.(Float64[r.states[end]...] .- exact)) for r in runs]
    @test errors[1] > errors[2] > errors[3]
    @test Tuple(length(r.times) - 1 for r in runs) == (5, 10, 20)
    @test length(runs[2].times) - 1 == 10
    @test all(r.status == :integrated for r in runs)
    @test all(r.rhs_evaluations == 8 * (length(r.times) - 1) for r in runs)
    @test all(abs(sum(r.states[end]) - sum(r.states[1])) <= 1e-12 for r in runs)
    @test all(r.residual_norm <= 1e-10 for r in runs)
    @test_throws ArgumentError compile_typed_time_residual_plan(ttr_parameter_compiled,
        ttr_registry; row_bindings=ttr_parameter_bindings)
    @test_throws ArgumentError ttr_parameter_plan(1.0; unit=ttr_unit)
    @test_throws ArgumentError ttr_parameter_plan(0.0)
    @test_throws ArgumentError ttr_parameter_plan(3.1)
    parameter_plan = ttr_parameter_plan(0.5)
    parameter_result = integrate_typed_time_residual(parameter_plan, ttr_scenario)
    @test parameter_result.status === :integrated
    @test parameter_result.residual_norm <= 1e-10
    parameter_exact = ((1 + exp(-1)) / 2, (1 - exp(-1)) / 2)
    @test maximum(abs.(Float64[parameter_result.states[end]...] .- parameter_exact)) <= 1e-8
    @test replay_typed_time_trajectory(parameter_plan.form,
        parameter_result.times, parameter_result.states).defect <= 1e-10
    parameter_holdout = integrate_typed_time_residual(ttr_parameter_plan(1.5), ttr_scenario)
    @test parameter_holdout.status === :integrated
    @test parameter_holdout.residual_norm <= 1e-10
    parameter_holdout_exact = ((1 + exp(-3)) / 2, (1 - exp(-3)) / 2)
    @test maximum(abs.(Float64[parameter_holdout.states[end]...] .-
        parameter_holdout_exact)) <= 1e-6
    @test replay_typed_time_trajectory(ttr_parameter_plan(1.5).form,
        parameter_holdout.times, parameter_holdout.states).defect <= 1e-10
    @test maximum(abs.(Float64[parameter_holdout.states[end]...] .-
        Float64[parameter_result.states[end]...])) > 1e-2
    @test parameter_plan.form.form_hash != ttr_parameter_plan(1.5).form.form_hash
    @test !hasproperty(semantic_view(plan.form), :parameter_values)
    @test semantic_view(parameter_plan.form).parameter_values ==
        (TimeParameterValueV4(:rate, 0.5, ttr_rate_unit),)
    parameter_replay_plan = ttr_parameter_plan(0.5)
    parameter_replay_result = integrate_typed_time_residual(parameter_replay_plan, ttr_scenario)
    parameter_replay_audit = replay_typed_time_trajectory(parameter_replay_plan.form,
        parameter_replay_result.times, parameter_replay_result.states)
    holdout_plan = ttr_parameter_plan(1.5)
    holdout_replay_result = integrate_typed_time_residual(holdout_plan, ttr_scenario)
    holdout_replay_audit = replay_typed_time_trajectory(holdout_plan.form,
        holdout_replay_result.times, holdout_replay_result.states)
    @test parameter_replay_result.result_hash == parameter_result.result_hash
    @test parameter_replay_result.trajectory_hash == parameter_result.trajectory_hash
    @test holdout_replay_result.result_hash == parameter_holdout.result_hash
    @test holdout_replay_result.trajectory_hash == parameter_holdout.trajectory_hash
    @test parameter_replay_audit.defect == parameter_result.trajectory_defect_norm
    @test holdout_replay_audit.defect == parameter_holdout.trajectory_defect_norm
    println("UP2_TYPED_TIME_PARAMETER_RAW_RESULT=", canonical_json((classification="preparation",
        test_only=true, physical=false, rates=(
            (rate=0.5, final_state=Tuple(Float64[parameter_result.states[end]...]),
                form_hash=string(parameter_plan.form.form_hash), plan_hash=string(parameter_plan.plan_hash),
                result_hash=string(parameter_result.result_hash), trajectory_hash=string(parameter_result.trajectory_hash),
                mass_solve_residual_norm=parameter_result.mass_solve_residual_norm,
                trajectory_defect_norm=parameter_result.trajectory_defect_norm,
                residual_norm=parameter_result.residual_norm,
                replay_defect=parameter_replay_audit.defect,
                max_abs_exact_error=maximum(abs.(Float64[parameter_result.states[end]...] .- parameter_exact)),
                same_process_replay=(result_hash=string(parameter_replay_result.result_hash),
                    trajectory_hash=string(parameter_replay_result.trajectory_hash),
                    replay_defect=parameter_replay_audit.defect)),
            (rate=1.5, final_state=Tuple(Float64[parameter_holdout.states[end]...]),
                form_hash=string(holdout_plan.form.form_hash), plan_hash=string(holdout_plan.plan_hash),
                result_hash=string(parameter_holdout.result_hash), trajectory_hash=string(parameter_holdout.trajectory_hash),
                mass_solve_residual_norm=parameter_holdout.mass_solve_residual_norm,
                trajectory_defect_norm=parameter_holdout.trajectory_defect_norm,
                residual_norm=parameter_holdout.residual_norm,
                replay_defect=holdout_replay_audit.defect,
                max_abs_exact_error=maximum(abs.(Float64[parameter_holdout.states[end]...] .- parameter_holdout_exact)),
                same_process_replay=(result_hash=string(holdout_replay_result.result_hash),
                    trajectory_hash=string(holdout_replay_result.trajectory_hash),
                    replay_defect=holdout_replay_audit.defect))))))
    @test_throws ArgumentError FusionRuntimeV4._ttr_mass(ttr_parameter_rhs_1,
        Dict(1 => 1, 2 => 2), 2, 1, default_operator_registry())
    @test_throws ArgumentError TimeIntegrationScenarioV4("bad", 1, 0, ttr_time_unit, ())
    @test_throws ArgumentError TimeIntegrationScenarioV4("bad", 0, 1, ttr_unit, ())
    @test_throws ArgumentError TimeIntegrationProtocolV4(:fixed_rk4, 0.1, 1.5)
    budget = integrate_typed_time_residual(derive_typed_time_residual_plan(plan,
        TimeIntegrationProtocolV4(:fixed_rk4, 0.01, 2)), ttr_scenario)
    @test budget.status == :numerical_failure
    @test budget.failure_reason !== nothing
    @test length(budget.times) == 3
    @test budget.result_hash == integrate_typed_time_residual(derive_typed_time_residual_plan(plan,
        TimeIntegrationProtocolV4(:fixed_rk4, 0.01, 2)), ttr_scenario).result_hash
    @test canonical_hash(plan) == plan.plan_hash
    @test typed_time_residual_manifest().claim_ceiling == screen_only
    @test typed_time_residual_manifest().kind == :typed_constant_mass_ode_integration
    @test size(plan.form.mass_matrix) == (2, 2)
    @test det(plan.form.mass_matrix) == 3.0
    @test plan.form.rows[1].mass_coefficients == [2.0, 1.0]
    @test plan.form.rows[2].mass_coefficients == [1.0, 2.0]
    @test plan.form.rows[1].lower == -10.0
    @test plan.form.rows[1].upper == 10.0
    @test ttr_scenario.initial_values[1].value == 1.0
    @test ttr_scenario.initial_values[2].value == 0.0
    @test ttr_scenario.scenario_hash == TimeIntegrationScenarioV4("two-state", 0.0, 1.0,
        ttr_time_unit, reverse(ttr_scenario.initial_values)).scenario_hash
    @test ttr_scenario.scenario_hash != TimeIntegrationScenarioV4("two-state", 0.0, 2.0,
        ttr_time_unit, ttr_scenario.initial_values).scenario_hash
    @test rk4_update_defect_v4([0.0], [1.01], 1.0, [1.0], [1.0], [1.0], [1.0]) > 0
    @test all(!(getfield(r, i) isa Function) for r in plan.form.rows for i in 1:fieldcount(typeof(r)))
    @test rk4_update_defect_v4(normal.states[1], normal.states[2] .+ [1e-6, 0.0],
        normal.times[2] - normal.times[1], [0.0, 0.0], [0.0, 0.0],
        [0.0, 0.0], [0.0, 0.0]) > 1e-7
    @test normal.mass_solve_residual_norm !== nothing
    @test normal.trajectory_defect_norm !== nothing
    audit = replay_typed_time_trajectory(plan.form, normal.times, normal.states)
    @test audit.evaluations == 4 * (length(normal.times) - 1)
    perturbed = collect(normal.states)
    perturbed[2] = Tuple(Float64[perturbed[2]...] .+ [1e-5, 0.0])
    @test replay_typed_time_trajectory(plan.form, normal.times, Tuple(perturbed)).defect > 1e-6
    original_mass = plan.form.mass_matrix[1, 1]
    plan.form.mass_matrix[1, 1] = original_mass + 1.0
    @test_throws ArgumentError replay_typed_time_trajectory(plan.form, normal.times, normal.states)
    plan.form.mass_matrix[1, 1] = original_mass
    plan.form.mass_matrix[1, 1] = original_mass + 1.0
    @test_throws ArgumentError derive_typed_time_residual_plan(plan,
        TimeIntegrationProtocolV4(:fixed_rk4, 0.1, 1000))
    plan.form.mass_matrix[1, 1] = original_mass
    original_coeff = plan.form.rows[1].mass_coefficients[1]
    plan.form.rows[1].mass_coefficients[1] = original_coeff + 1.0
    @test_throws ArgumentError derive_typed_time_residual_plan(plan,
        TimeIntegrationProtocolV4(:fixed_rk4, 0.1, 1000))
    plan.form.rows[1].mass_coefficients[1] = original_coeff
    @test budget.residual_norm === nothing

    bad_g2 = ttr_edge("bad-g2", 2, ttr_m1, governing)
    bad_graph = TypedOperatorHypergraphV1(ttr_graph.nodes,
        (ttr_g1, bad_g2, ttr_a1, ttr_a2); registry=ttr_ops)
    bad_payload = MechanismGenomePayloadV1(ttr_payload.states, ttr_payload.invariants,
        bad_graph, ttr_payload.parameters, ttr_payload.symmetries,
        ttr_payload.observables, ttr_payload.operator_holes)
    bad_mechanism = MechanismGenomeV4(1, ttr_mechanism_ref, bad_payload)
    bad_candidate = CandidateStatePackageV4("bad-owner", ttr_mission,
        bad_mechanism, ttr_field, ttr_realization, ttr_registry)
    bad_compiled = compile_candidate(bad_candidate, ttr_registry;
        mission_payload=ttr_mission, bounds_payload=nothing,
        comparison_scope=("typed-time",), scenario_scope=("two-state",))
    @test_throws ArgumentError compile_typed_time_residual_plan(bad_compiled, ttr_registry;
        row_bindings=ttr_bindings)
end
