include(joinpath(@__DIR__,"..","examples","runtime_v4_candidate_validation_propagation.jl"))
print(read(candidate_validation_propagation.output_path,String))
println("CANDIDATE_VALIDATION_PROPAGATION_RUNNER_EXIT_CODE=0")
