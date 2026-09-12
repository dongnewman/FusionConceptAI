include(joinpath(@__DIR__,"runtime_v4_regional_force_independent_cubature.jl"))
const CVP=Module(:CandidateValidationPropagation)
Base.include(CVP,joinpath(@__DIR__,"..","src","RuntimeV4","CandidateValidationPropagationV4.jl"))
const candidate_validation_propagation=CVP.execute_candidate_validation_propagation(
    imit_upstream,imit_request,imit_result,drifo_request,drifo_result,
    drifo_execution,q3_execution,q4_execution,independent_execution;
    run_dir=joinpath(RFQ3_RUN_ROOT,"validation_propagation"))
if abspath(PROGRAM_FILE)==@__FILE__
    print(read(candidate_validation_propagation.output_path,String))
    println("CANDIDATE_VALIDATION_PROPAGATION_RUNNER_EXIT_CODE=0")
end
