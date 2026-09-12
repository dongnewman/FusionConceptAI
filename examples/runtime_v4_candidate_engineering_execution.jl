# Reuse an already-created real-DESC chain when included by the unified runner.
if !@isdefined(imit_upstream)
    include(joinpath(@__DIR__, "runtime_v4_ideal_mhd_interface_traction.jl"))
end
const CEE = IMIT
if !isdefined(CEE, :CandidateEngineeringExecutionV4)
    Base.include(CEE, joinpath(@__DIR__, "..", "src", "RuntimeV4", "CandidateEngineeringExecutionV4.jl"))
end
const candidate_engineering_execution = CEE.execute_candidate_engineering(
    first(imit_upstream), imit_upstream, imit_request, imit_result)

function run_candidate_engineering_execution_example(io::IO=stdout)
    for (name, value) in pairs(CEE.candidate_engineering_summary(candidate_engineering_execution))
        println(io, name, "=", value)
    end
    println(io, "CANDIDATE_ENGINEERING_EXECUTION_EXIT_CODE=0")
    candidate_engineering_execution
end
if abspath(PROGRAM_FILE) == @__FILE__
    run_candidate_engineering_execution_example()
end
