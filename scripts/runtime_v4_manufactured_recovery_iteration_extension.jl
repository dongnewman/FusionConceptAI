"""Preregistered N1 diagnostic: extend only the iteration budget for perturbation 3.

No equation, mesh, perturbation, residual tolerance, gradient tolerance, or
line-search setting is changed. Importing this file performs no solve.
"""
module RuntimeV4ManufacturedRecoveryIterationExtension
using LinearAlgebra, SHA
include(joinpath(@__DIR__, "runtime_v4_manufactured_recovery_benchmark.jl"))
const M = RuntimeV4ManufacturedRecoveryBenchmark

const CASES = (
    (level=:h033, budget=24, spec=(:h033, 1,
        ((level=:h033, rho=(0., 1/3, .5, 2/3, 1.), theta_count=6, zeta_per_period=3),), 1/3)),
    (level=:h033, budget=48, spec=(:h033, 1,
        ((level=:h033, rho=(0., 1/3, .5, 2/3, 1.), theta_count=6, zeta_per_period=3),), 1/3)),
    (level=:h025, budget=24, spec=(:h025, 1,
        ((level=:h025, rho=(0., .25, .5, .75, 1.), theta_count=8, zeta_per_period=4),), .25)),
    (level=:h025, budget=48, spec=(:h025, 1,
        ((level=:h025, rho=(0., .25, .5, .75, 1.), theta_count=8, zeta_per_period=4),), .25)),
)
const PERTURBATION = (0.37, 0.19, 0.17, 7.0e3)

function run_iteration_extension()
    results = NamedTuple[]
    for case in CASES
        bundle = M.benchmark_data(case.spec)
        d = bundle.declaration
        data = bundle.data
        truth = data.initial_state
        initial = truth .+ repeat(collect(PERTURBATION), div(length(truth), 4))
        started = time()
        sol = M.SPF.solve_spatial_state_v4(d, data, initial; flux_Wb=pi,
            limits=(max_iterations=case.budget, seconds=600.),
            source_function=xyz->M.manufactured_field(xyz).source,
            boundary_function=M.manufactured_traction,
            normal_field_function=M.manufactured_normal)
        attempts = Tuple((index=a.attempt_index, accepted=a.accepted, direction=a.direction,
            alpha=a.accepted_alpha, objective_before=a.objective_before,
            objective_after=a.objective_after, objective_decrease=a.objective_decrease,
            progress=a.progress_classification) for a in sol.attempts)
        push!(results, (level=case.level, h=case.spec[4], iteration_budget=case.budget,
            unknowns=length(truth), solver_exit_code=sol.solver_exit_code,
            status=sol.status, stopping_reason=sol.stopping_reason,
            elapsed_seconds=time()-started, attempt_count=sol.attempt_count,
            accepted_update_count=sol.accepted_update_count,
            all_accepted_updates_strict=all(a->!a.accepted ||
                (a.strict_objective_decrease && a.scaled_state_change), sol.attempts),
            initial_solution_relative_error=norm(initial.-truth)/max(norm(truth), 1.),
            final_solution_relative_error=norm(collect(sol.final_state).-truth)/max(norm(truth), 1.),
            final_scaled_residual_max=maximum(abs,
                sol.final_assembly.residual./sol.final_assembly.row_scales),
            final_projected_gradient_norm=last(sol.iterations).projected_gradient_norm,
            attempts=attempts))
    end
    source_path = abspath(@__FILE__)
    benchmark_path = abspath(joinpath(@__DIR__, "runtime_v4_manufactured_recovery_benchmark.jl"))
    production_path = abspath(joinpath(@__DIR__, "..", "src", "RuntimeV4", "SpatialMultiRegionV4.jl"))
    (diagnostic=:runtime_v4_manufactured_recovery_iteration_extension_v1,
     preregistered_change=:iteration_budget_only, perturbation=PERTURBATION,
     residual_tolerance=1.0e-6, gradient_tolerance=1.0e-10,
     source_sha256=bytes2hex(SHA.sha256(read(source_path))),
     benchmark_source_sha256=bytes2hex(SHA.sha256(read(benchmark_path))),
     production_source_sha256=bytes2hex(SHA.sha256(read(production_path))),
     results=Tuple(results), numerical_only=true, physical_validation=:unsupported,
     evidence_authority=:none)
end
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    result = RuntimeV4ManufacturedRecoveryIterationExtension.run_iteration_extension()
    text = RuntimeV4ManufacturedRecoveryIterationExtension.M.SPF.canonical_json(result) * "\n"
    if isempty(ARGS)
        print(text)
    else
        output = abspath(first(ARGS)); mkpath(dirname(output)); write(output, text)
        println("N1_ITERATION_EXTENSION_OUTPUT=", output)
    end
end
