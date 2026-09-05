using Test
using FusionConceptAI

module RuntimeV4AlgebraicResidualTestModule
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Execution.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "AlgebraicResidual.jl"))
end

module RuntimeV4AlgebraicResidualFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl"))
end

const R = RuntimeV4AlgebraicResidualTestModule
const F = RuntimeV4AlgebraicResidualFixture

function _alg_compiled()
    R.compile_candidate(F.candidate, F.registry;
        mission_payload=F.candidate.mission_contract_ref,
        bounds_payload=(scope="algebraic-residual-test",),
        comparison_scope=("algebraic-residual",), scenario_scope=("zero-dimensional",))
end

function _alg_plan()
    compiled = _alg_compiled()
    result = R.compile_algebraic_residual_plan(compiled, F.registry)
    @test result.status == :ready
    @test isempty(result.unresolved_gaps)
    result.plan
end

function _alg_scenario(; x=0.0, y=0.0, name="zero", abs_tol=1.0e-10,
        rel_tol=1.0e-10, max_iterations=64, fd_step=1.0e-7, min_line_search=1.0 / 1024.0)
    unit = UnitSignature()
    R.AlgebraicScenarioV4(name,
        (R.StateValueV4(StateGeneRefV1("x"), x, unit),
         R.StateValueV4(StateGeneRefV1("y"), y, unit)); abs_tol=abs_tol,
        rel_tol=rel_tol, max_iterations=max_iterations, fd_step=fd_step,
        min_line_search=min_line_search)
end

@testset "0D algebraic residual qualification and exact route" begin
    compiled = _alg_compiled()
    @test compiled.candidate.mechanism_genome_ref.payload.parameters == ()
    @test compiled.candidate.mechanism_genome_ref.payload.operator_holes == ()
    plan = _alg_plan()
    @test plan.state_refs == (StateGeneRefV1("x"), StateGeneRefV1("y"))
    @test length(plan.rows) == 2
    @test Tuple(row.edge_id for row in plan.rows) == ("constraint-sum", "constraint-difference")
    @test length(plan.ignored_edge_hashes) == 3
    @test plan.capability.schema == "fusionconceptai:runtime-v4-algebraic-residual"
    @test plan.capability.kind == :algebraic_constraint_screen
    @test plan.capability.dimension == 0
    @test plan.capability.coordinates == ()
    @test plan.capability.evidence_level == screen_only
    @test plan.capability.applicability_bounds == compiled.minimality_scope.bounds_hash
    @test plan.plan_hash isa Digest256
    @test plan.plan_hash == R.compile_algebraic_residual_plan(compiled, F.registry).plan.plan_hash
end

@testset "0D Newton solve is bounded, deterministic, and residual checked" begin
    plan = _alg_plan()
    initial = _alg_scenario()
    @test R.evaluate_algebraic_residual(plan, (0.0, 0.0)) == (-3.0, -1.0)
    result = R.solve_algebraic_residual(plan, initial)
    @test result.status == :converged
    @test result.state_values == (2.0, 1.0)
    @test result.residuals !== nothing
    @test maximum(abs.(result.residuals)) <= 1.0e-10
    @test result.residual_norm !== nothing && result.residual_norm <= 1.0e-10
    @test all(a -> a.margin_lower >= 0 && a.margin_upper >= 0, result.bounds_audit)
    @test result.result_hash isa Digest256
    @test result == R.solve_algebraic_residual(plan, initial)
    @test R.evaluate_algebraic_residual(plan, result.state_values) == (0.0, 0.0)
    renamed = R.solve_algebraic_residual(plan, _alg_scenario(name="renamed"))
    @test renamed.state_values == result.state_values
    @test renamed.result_hash != result.result_hash
end

@testset "algebraic evidence is provider-bound screen_only and cache-stable" begin
    plan = _alg_plan()
    scenario = _alg_scenario()
    provider = R.algebraic_residual_manifest(plan)
    @test R.match_provider(plan.capability, provider).status == unique_match
    @test provider.claim_ceiling == screen_only
    @test provider.code_hash != digest256_text("runtime-v4-algebraic-residual-newton-v1")
    store = Dict{Digest256,Any}()
    first = R.execute_algebraic_once!(store, plan, scenario; provider=provider)
    second = R.execute_algebraic_once!(store, plan, scenario; provider=provider)
    @test first === second
    @test first.subject isa R.ExecutableAlgebraicSubjectV4
    @test first.input isa R.SolverInputV4
    @test first.result.status == :converged
    @test first.input.payload.requested_obligation == plan.capability
    @test first.evidence.claim_ceiling == screen_only
    @test first.evidence.provider_manifest_hash == provider.manifest_hash
    @test first.evidence.artifact_refs == (first.result.result_hash,)
    @test first.evidence.status_vector.stage_outcome == pass
    @test first.evidence.independence_group == provider.independence_group
    deferred = R.execute_algebraic_once!(Dict{Digest256,Any}(), plan, scenario; provider=nothing)
    @test deferred.result === nothing
    @test deferred.evidence.claim_ceiling == none
    @test deferred.evidence.status_vector.resolution == terminal_deferred
    @test_throws ArgumentError R.execute_algebraic_once!(Dict{Digest256,Any}(), plan, scenario;
        provider=R.ProviderManifestV4(provider.schema, provider.revision, provider.kind, provider.capability,
            provider.domain, provider.backend, provider.backend_revision, digest256_text("wrong-code"),
            provider.independence_group, screen_only; input_schema_hash=provider.input_schema_hash,
            executor=provider.executor))
end

@testset "algebraic numerical failure stays numerical and bounded" begin
    plan = _alg_plan()
    @test R.solve_algebraic_residual(plan, _alg_scenario(x=11.0)).status == :numerical_fail
    bad_protocol = R.AlgebraicScenarioV4("bad", (
        R.StateValueV4(StateGeneRefV1("x"), 0.0, UnitSignature()),
        R.StateValueV4(StateGeneRefV1("y"), 0.0, UnitSignature())); max_iterations=1)
    @test_throws ArgumentError R.solve_algebraic_residual(plan, bad_protocol)
    @test_throws ArgumentError R.AlgebraicScenarioV4("duplicate", (
        R.StateValueV4(StateGeneRefV1("x"), 0.0, UnitSignature()),
        R.StateValueV4(StateGeneRefV1("x"), 0.0, UnitSignature())))
    @test_throws ArgumentError R.AlgebraicScenarioV4("*", (
        R.StateValueV4(StateGeneRefV1("x"), 0.0, UnitSignature()),
        R.StateValueV4(StateGeneRefV1("y"), 0.0, UnitSignature())))
    @test_throws ArgumentError R.AlgebraicScenarioV4("nonfinite", (
        R.StateValueV4(StateGeneRefV1("x"), NaN, UnitSignature()),
        R.StateValueV4(StateGeneRefV1("y"), 0.0, UnitSignature())))
end

@testset "algebraic negative paths preserve deferred and numerical boundaries" begin
    plan = _alg_plan()
    parameter_program = TypedASTProgramV1(
        (ASTParameterV1(:unresolved_parameter, F._alg_type),), (1,), (); registry=F._alg_ops)
    gaps = R._alg_check_program(parameter_program, Set{Tuple{String,String}}())
    @test gaps !== nothing
    @test any(==("unsupported_ast_node"), gaps)
    @test_throws ArgumentError ASTApplyV1(OperatorRefV1("DT", "v1"), (1,), (;);
        registry=F._alg_ops, input_types=(F._alg_type,))
    @test_throws ArgumentError ASTApplyV1(OperatorRefV1("UNKNOWN_OPCODE", "v9"), (1,), (;);
        registry=F._alg_ops, input_types=(F._alg_type,))

    zero_program = TypedASTProgramV1(
        (ASTConstantV1(:one, 1, F._alg_type), ASTConstantV1(:zero, 0, F._alg_type),
         ASTApplyV1(OperatorRefV1("SCALAR_DIV", "v1"), (1, 2), (;);
             registry=F._alg_ops, input_types=(F._alg_type, F._alg_type))), (3,), (); registry=F._alg_ops)
    zero_row = R.AlgebraicResidualRowV4(StateGeneRefV1("x"), "division-zero", 1, 3,
        zero_program, ())
    @test_throws ArgumentError R._alg_eval_row(plan, zero_row, (0.0, 0.0))
    @test R.solve_algebraic_residual(plan, _alg_scenario(x=11.0)).state_values == (11.0, 0.0)

    compiled = _alg_compiled()
    bogus_graph = F._alg_graph
    forged = R.CompiledCandidatePrefixV4(compiled.candidate, compiled.mission_payload,
        compiled.bounds_payload, compiled.minimality_scope, bogus_graph,
        compiled.field_geometry_graph, compiled.realization_graph, compiled.control_graph,
        compiled.normalized_regions, compiled.normalized_interfaces, compiled.normalized_boundaries,
        compiled.unresolved_nonterminals, compiled.capability_obligations, compiled.compilation_status)
    deferred = R.compile_algebraic_residual_plan(forged, F.registry)
    @test deferred.status == :deferred
    @test "compiled_mechanism_graph_mismatch" in deferred.unresolved_gaps

    one_step = R.compile_algebraic_residual_plan(compiled, F.registry;
        protocol=(abs_tol=1.0e-10, rel_tol=1.0e-10, max_iterations=1,
            fd_step=1.0e-7, min_line_search=1.0 / 1024.0))
    @test one_step.status == :ready
    one_step_result = R.solve_algebraic_residual(one_step.plan,
        _alg_scenario(max_iterations=1))
    @test one_step_result.status == :numerical_fail
    @test one_step_result.residual_norm === nothing || one_step_result.residual_norm > 1.0e-10

    singular_plan = R.AlgebraicResidualPlanV4(R._ALG_PLAN_TOKEN, compiled,
        plan.state_refs, plan.state_types, plan.lower_bounds, plan.upper_bounds,
        plan.scales, (plan.rows[1], plan.rows[1]), plan.allowed_operator_bindings,
        plan.selected_constraint_hashes, plan.ignored_edge_hashes, plan.numerical_protocol,
        plan.minimality_scope, plan.capability)
    singular_result = R.solve_algebraic_residual(singular_plan, _alg_scenario())
    @test singular_result.status == :numerical_fail

    # A legal G1 package with one exact constraint row per state, but the same
    # equation twice, must compile and then fail numerically as singular.
    base_payload = F._alg_payload()
    base_graph = base_payload.operator_graph
    sum_edge = base_graph.hyperedges[4]
    sum_y = AtomicMIMOHyperedgeV1("constraint-difference", sum_edge.input_bindings,
        (MIMOOutputBindingV1(1, 2),), sum_edge.program, constraint; registry=F._alg_ops)
    singular_graph = TypedOperatorHypergraphV1(base_graph.nodes,
        (base_graph.hyperedges[1], base_graph.hyperedges[2], base_graph.hyperedges[3],
         sum_edge, sum_y); registry=F._alg_ops)
    singular_payload = MechanismGenomePayloadV1(base_payload.states, base_payload.invariants,
        singular_graph, base_payload.parameters, base_payload.symmetries,
        base_payload.observables, base_payload.operator_holes)
    singular_mechanism = MechanismGenomeV4(9, F._alg_refs[1], singular_payload)
    singular_candidate = CandidateStatePackageV4("algebraic-singular-fixture", F._alg_mission,
        singular_mechanism, F._alg_field, F._alg_realization, F.registry)
    singular_compiled = R.compile_candidate(singular_candidate, F.registry;
        mission_payload=singular_candidate.mission_contract_ref,
        bounds_payload=(scope="algebraic-residual-test",),
        comparison_scope=("algebraic-residual",), scenario_scope=("zero-dimensional",))
    singular_compilation = R.compile_algebraic_residual_plan(singular_compiled, F.registry)
    @test singular_compilation.status == :ready
    @test R.solve_algebraic_residual(singular_compilation.plan, _alg_scenario()).status == :numerical_fail

    forged_consistent = R.CompiledCandidatePrefixV4(compiled.candidate, compiled.mission_payload,
        compiled.bounds_payload, compiled.minimality_scope, compiled.mechanism_graph,
        compiled.field_geometry_graph, compiled.realization_graph, compiled.control_graph,
        compiled.normalized_regions, compiled.normalized_interfaces, compiled.normalized_boundaries,
        (), (), :prefix_consistent)
    forged_check = R.compile_algebraic_residual_plan(forged_consistent, F.registry)
    @test forged_check.status == :deferred
    @test any(startswith("compiled_prefix_validation:"), forged_check.unresolved_gaps)

    renamed_row = R.AlgebraicResidualRowV4(plan.rows[1].state_ref, "core-tokamak-renamed", 1,
        plan.rows[1].output_node_index, plan.rows[1].program, plan.rows[1].input_state_refs)
    @test R._alg_eval_row(plan, renamed_row, (0.0, 0.0)) == R._alg_eval_row(plan, plan.rows[1], (0.0, 0.0))
    @test canonical_hash(renamed_row) != canonical_hash(plan.rows[1])

    store = Dict{Digest256,Any}()
    first = R.execute_algebraic_once!(store, plan, _alg_scenario())
    store[first.input.solver_input_hash] = :corrupt
    @test_throws ArgumentError R.execute_algebraic_once!(store, plan, _alg_scenario())
end
