using Test
using SHA
using JSON3

const IH_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const IH_EXPECTED_SOLVER_SOURCE_SHA256 =
    "BD8E60FF527C42723B2B38C28494761D33C30D9E2FB200C464FADA926A4351BF"

include(joinpath(@__DIR__, "focused_fixture.jl"))
const IH_RUNTIME = Main.FusionRuntimeV4
ng12_runtime_include_if_missing(joinpath(IH_ROOT, "src", "RuntimeV4",
    "InHouseG1G2Q1SolverV1.jl"), :NativeG1G2InHouseQ1ReportV1)

function ih_rehash_replace(value; changes...)
    names = fieldnames(typeof(value))
    hash_name = last(names)
    staged_values = ntuple(i -> haskey(changes, names[i]) ?
        getproperty(changes, names[i]) : getfield(value, i), length(names))
    staged = typeof(value)(staged_values...)
    semantic = IH_RUNTIME.semantic_view(staged)
    body_names = Tuple(name for name in keys(semantic) if name != hash_name)
    body = NamedTuple{body_names}(Tuple(getproperty(semantic, name)
        for name in body_names))
    digest = IH_RUNTIME.canonical_hash(body)
    final_values = ntuple(i -> names[i] == hash_name ? digest :
        staged_values[i], length(names))
    typeof(value)(final_values...)
end

function ih_forge_runtime_evidence(plan, evidence;
        binding_provenance=evidence.binding_provenance,
        physical_subject_hash=evidence.physical_subject_hash,
        scenario_hash=evidence.scenario_hash,
        status_vector=evidence.status_vector,
        numerical_configuration_hash=evidence.numerical_configuration_hash,
        artifact_refs=evidence.artifact_refs)
    IH_RUNTIME.RuntimeEvidenceV4(
        physical_subject_hash, scenario_hash, evidence.solver_input_hash,
        evidence.provider_manifest_hash, binding_provenance,
        status_vector, evidence.metrics;
        claim_ceiling=evidence.claim_ceiling,
        independence_group=evidence.independence_group,
        provider_manifest=plan.provider,
        backend_revision=evidence.backend_revision,
        numerical_configuration_hash=numerical_configuration_hash,
        artifact_refs=artifact_refs,
        uncertainty_or_null=evidence.uncertainty_or_null)
end

function ih_rebind_tampered_form(fixture, plan, new_form)
    compilation = ih_rehash_replace(plan.compilation; form=new_form)
    result = fixture.compile_result
    result_hash = NG12_G.canonical_hash(
        IH_RUNTIME._ng12_compile_result_body(result.status, result.resolution,
            result.accepted, result.claim_ceiling, compilation, result.errors,
            result.gaps))
    ih_rehash_replace(plan; compilation=compilation,
        compile_result_hash=result_hash)
end

function ih_level_json(level)
    out = Dict{String,Any}()
    for name in fieldnames(typeof(level))
        name in (:matrix_hash, :full_matrix_hash, :rhs_hash,
                 :solution_hash, :dof_partition_hash, :level_hash) && continue
        value = getproperty(level, name)
        out[string(name)] = value isa Symbol ? string(value) :
            value isa Tuple && all(item -> item isa Symbol, value) ?
                string.(collect(value)) : value
    end
    out["artifact_hashes"] = Dict(string(name) =>
        string(getproperty(level, name)) for name in
        (:matrix_hash, :full_matrix_hash, :rhs_hash, :solution_hash,
         :dof_partition_hash, :level_hash))
    out
end

function ih_write_independent_input(plan, report, path)
    payload = Dict{String,Any}(
        "grid_levels" => [collect(counts) for counts in
            plan.protocol.cell_counts],
        "inhouse" => Dict{String,Any}(
            "identity" => Dict{String,String}(
                "candidate_ref" => report.candidate_ref.id,
                "candidate_version" => report.candidate_ref.version,
                "t1_package_hash" => string(report.t1_package_hash),
                "source_binding_hash" => string(report.source_binding_hash),
                "plan_hash" => string(report.plan_hash),
                "solver_input_hash" => string(report.solver_input_hash),
                "protocol_hash" => string(report.protocol_hash),
                "solver_source_hash" => string(report.solver_source_hash),
                "report_hash" => string(report.report_hash)),
            "plan_identity" => Dict{String,String}(
                "candidate_ref" => plan.compilation.form.candidate_ref.id,
                "candidate_version" => plan.compilation.form.candidate_ref.version,
                "t1_package_hash" => string(
                    plan.compilation.form.t1_package_hash),
                "source_binding_hash" => string(plan.source_binding_hash),
                "plan_hash" => string(plan.plan_hash),
                "solver_input_hash" => string(
                    plan.solver_input.solver_input_hash),
                "protocol_hash" => string(plan.protocol.protocol_hash),
                "solver_source_hash" => string(plan.solver_source_hash)),
            "status" => string(report.status),
            "resolution" => string(report.resolution),
            "accepted" => report.accepted,
            "claim_ceiling" => string(report.claim_ceiling),
            "errors" => string.(collect(report.errors)),
            "l2_orders" => collect(report.l2_orders),
            "h1_orders" => collect(report.h1_orders),
            "levels" => [ih_level_json(level) for level in report.levels]))
    open(path, "w") do io
        JSON3.write(io, payload)
        write(io, '\n')
    end
end

function ih_build_fixture()
    ng12_stage("acceptance.fixture_build.begin")
    fixture = ng12_inhouse_compiled_fixture()
    ng12_stage("acceptance.fixture_build.complete")
    fixture
end

function ih_validate_protocol_and_plan(fixture)
    ng12_stage("acceptance.plan_build.begin")
    protocol = IH_RUNTIME.native_g1g2_inhouse_q1_protocol_v1()
    plan = IH_RUNTIME.prepare_native_g1g2_inhouse_q1_v1(
        fixture.compile_result, protocol)
    ng12_stage("acceptance.plan_build.complete")

    @testset "in-house Q1 protocol and candidate-bound plan" begin
        @test fixture.compile_result.status === :compiled_numerical_preparation
        @test isempty(fixture.compile_result.errors)
        @test protocol.cell_counts == ((2, 3, 4), (4, 6, 8), (8, 12, 16))
        @test protocol.quadrature_degree == 8
        @test protocol.solver === :inhouse_q1_jacobi_pcg
        @test protocol.residual_abs_tol == 1.0e-9
        @test protocol.residual_rel_tol == 1.0e-11
        @test protocol.boundary_abs_tol == 1.0e-10
        @test protocol.source_integral_abs_tol == 1.0e-10
        @test protocol.analytic_identity_abs_tol == 1.0e-12
        @test protocol.reaction_balance_abs_tol == 1.0e-9
        @test protocol.l2_order_interval == (1.4, 2.6)
        @test protocol.h1_order_interval == (0.6, 1.4)
        @test protocol.finest_l2_max == 5.0e-3
        @test protocol.finest_h1_seminorm_max == 1.0e-2
        @test IH_RUNTIME.validate_native_g1g2_inhouse_q1_plan_v1(plan)
        @test plan.provider.backend == "Native-inhouse-Q1-Jacobi-PCG"
        @test plan.provider.backend_revision == "inhouse-q1-jacobi-pcg-v1"
        @test plan.protocol.solver != :gridap_sparse_lu
        @test plan.compilation.form.candidate_ref == NG12_CANDIDATE
        @test string(plan.solver_source_hash) == lowercase(
            IH_EXPECTED_SOLVER_SOURCE_SHA256)
    end

    @testset "candidate, source, and chart mutations fail closed" begin
        original = plan.compilation.form
        foreign_candidate = ih_rehash_replace(original;
            candidate_ref=NG12_FOREIGN_CANDIDATE)
        @test !IH_RUNTIME.validate_native_g1g2_inhouse_q1_plan_v1(
            ih_rebind_tampered_form(fixture, plan, foreign_candidate))

        altered_source = ng12_alternative_source_program_bundle(
            original.unit_profile, original.programs)
        source_form = ih_rehash_replace(original; programs=altered_source)
        @test !IH_RUNTIME.validate_native_g1g2_inhouse_q1_plan_v1(
            ih_rebind_tampered_form(fixture, plan, source_form))

        altered_chart = ng12_g2_declaration(
            chart_rows=((2, 1, 0), (0, 3, 0), (0, 0, 4)))
        chart_form = ih_rehash_replace(original; g2_declaration=altered_chart)
        @test !IH_RUNTIME.validate_native_g1g2_inhouse_q1_plan_v1(
            ih_rebind_tampered_form(fixture, plan, chart_form))
    end
    plan
end

function ih_execute_and_validate_report(plan, output_path)
    ng12_stage("acceptance.q1_three_grid_execute.begin")
    store = Dict()
    bundle = IH_RUNTIME.execute_native_g1g2_inhouse_q1_once!(store, plan)
    ng12_stage("acceptance.q1_three_grid_execute.complete";
        detail="levels=$(length(bundle.report.levels))")
    report = bundle.report
    ih_write_independent_input(plan, report, output_path)

    @testset "three-grid candidate-bound Q1 report" begin
        @test report.status === :pass
        @test IH_RUNTIME.validate_native_g1g2_inhouse_q1_report_v1(plan, report)
        @test report.candidate_ref == plan.compilation.form.candidate_ref
        @test report.t1_package_hash == plan.compilation.form.t1_package_hash
        @test report.source_binding_hash == plan.source_binding_hash
        @test report.plan_hash == plan.plan_hash
        @test report.solver_input_hash == plan.solver_input.solver_input_hash
        @test report.protocol_hash == plan.protocol.protocol_hash
        @test report.solver_source_hash == plan.solver_source_hash
        @test IH_RUNTIME.validate_native_g1g2_inhouse_q1_execution_bundle_v1(
            plan, bundle)
        @test report.resolution === :terminal_deferred
        @test report.accepted === false
        @test report.claim_ceiling === IH_RUNTIME.screen_only
        @test all(level.status === :pass for level in report.levels)
        @test all(level.assembly_quadrature_points == 125 * level.cells
            for level in report.levels)
        @test bundle.invocation_counts.provider_calls == 1
        @test bundle.invocation_counts.assembly_calls == 3
        @test bundle.invocation_counts.solver_calls == 3
    end
    bundle
end

function ih_validate_scalar_forgery(plan, report)
    ng12_stage("acceptance.scalar_forgery.begin")
    @testset "rehashing forged scalar metrics does not validate" begin
        first = report.levels[1]
        forged_level = ih_rehash_replace(first;
            l2_error=first.l2_error + 0.01)
        forged_levels = (forged_level, report.levels[2], report.levels[3])
        forged_report = ih_rehash_replace(report; levels=forged_levels,
            l2_orders=report.l2_orders)
        @test forged_level.level_hash != first.level_hash
        @test forged_report.report_hash != report.report_hash
        @test !IH_RUNTIME.validate_native_g1g2_inhouse_q1_report_v1(
            plan, forged_report)
    end
    ng12_stage("acceptance.scalar_forgery.complete")
    nothing
end

function ih_validate_runtime_evidence_forgery(plan, bundle)
    ng12_stage("acceptance.evidence_forgery.begin")
    @testset "rehashing forged runtime evidence and cache does not validate" begin
        evidence = bundle.evidence
        forged_evidence_variants = (
            ih_forge_runtime_evidence(plan, evidence;
                binding_provenance=merge(evidence.binding_provenance,
                    (candidate_ref=NG12_FOREIGN_CANDIDATE,))),
            ih_forge_runtime_evidence(plan, evidence;
                physical_subject_hash=IH_RUNTIME.canonical_hash(
                    (forged_physical_subject=true,))),
            ih_forge_runtime_evidence(plan, evidence;
                scenario_hash=IH_RUNTIME.canonical_hash(
                    (forged_scenario=true,))),
            ih_forge_runtime_evidence(plan, evidence;
                status_vector=IH_RUNTIME.StatusVectorV4(
                    evidence.status_vector.applicability,
                    evidence.status_vector.match_status,
                    evidence.status_vector.resolution,
                    evidence.status_vector.lifecycle,
                    IH_RUNTIME.numerical_fail)),
            ih_forge_runtime_evidence(plan, evidence;
                numerical_configuration_hash=IH_RUNTIME.canonical_hash(
                    (forged_configuration=true,))),
            ih_forge_runtime_evidence(plan, evidence;
                artifact_refs=(IH_RUNTIME.canonical_hash(
                    (forged_artifact=true,)),)))
        forged_bundles = map(forged_evidence_variants) do forged_evidence
            ih_rehash_replace(bundle; evidence=forged_evidence)
        end
        @test all(forged.bundle_hash != bundle.bundle_hash
            for forged in forged_bundles)
        @test all(!IH_RUNTIME.validate_native_g1g2_inhouse_q1_execution_bundle_v1(
                plan, forged) for forged in forged_bundles)

        corrupt_store = Dict{typeof(plan.solver_input.solver_input_hash),Any}(
            plan.solver_input.solver_input_hash => first(forged_bundles))
        @test_throws IH_RUNTIME.NativeG1G2InHouseQ1ErrorV1 begin
            IH_RUNTIME.execute_native_g1g2_inhouse_q1_once!(corrupt_store, plan)
        end
        cache_error = try
            IH_RUNTIME.execute_native_g1g2_inhouse_q1_once!(corrupt_store, plan)
            nothing
        catch error
            error
        end
        @test cache_error isa IH_RUNTIME.NativeG1G2InHouseQ1ErrorV1
        @test cache_error.code === :cached_execution_bundle_integrity_mismatch
    end
    ng12_stage("acceptance.evidence_forgery.complete")
    nothing
end

function ih_run()
    ng12_stage("acceptance.entry.begin")
    length(ARGS) == 2 && ARGS[1] == "--json-out" ||
        error("usage: focused_tests.jl --json-out <path>")
    output_path = abspath(ARGS[2])
    mkpath(dirname(output_path))
    ng12_stage("acceptance.output_ready")

    fixture = ih_build_fixture()
    plan = ih_validate_protocol_and_plan(fixture)
    bundle = ih_execute_and_validate_report(plan, output_path)
    ih_validate_scalar_forgery(plan, bundle.report)
    ih_validate_runtime_evidence_forgery(plan, bundle)

    println("INHOUSE_JULIA=GO levels=3 report=", output_path)
    nothing
end

ng12_stage("acceptance.dispatch")
ih_run()
