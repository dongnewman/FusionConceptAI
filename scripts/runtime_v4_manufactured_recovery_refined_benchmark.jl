"""Preregistered N1 v3 three-level recovery family; importing performs no solve."""
module RuntimeV4ManufacturedRecoveryRefinedBenchmark
include(joinpath(@__DIR__, "runtime_v4_manufactured_recovery_benchmark.jl"))
const M = RuntimeV4ManufacturedRecoveryBenchmark
const REFINED_RESOLUTIONS = (
    M.DEFAULT_RESOLUTIONS[2],
    M.DEFAULT_RESOLUTIONS[3],
    (:h02, 1, ((level=:h02, rho=(0., .2, .4, .5, .6, .8, 1.),
        theta_count=10, zeta_per_period=5),), .2),
)

run_refined_benchmark() = M.run_manufactured_recovery_benchmark(
    resolutions=REFINED_RESOLUTIONS, perturbations=M.DEFAULT_PERTURBATIONS,
    max_iterations=48, benchmark_id=:runtime_v4_manufactured_recovery_n1_v3)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    result = RuntimeV4ManufacturedRecoveryRefinedBenchmark.run_refined_benchmark()
    text = RuntimeV4ManufacturedRecoveryRefinedBenchmark.M.SPF.canonical_json(result) * "\n"
    if isempty(ARGS)
        print(text)
    else
        output = abspath(first(ARGS)); mkpath(dirname(output)); write(output, text)
        println("N1_REFINED_RECOVERY_OUTPUT=", output)
    end
end
