#= Execute the current DESC candidate once and audit every downstream stage.

Usage: julia --startup-file=no --project=. scripts/run_v4_candidate_chain.jl [new_run_directory]
=#
using FusionConceptAI
using SHA
using Test

const CHAIN_REPO = dirname(@__DIR__)
const CHAIN_RUN_DIR = abspath(isempty(ARGS) ?
    mktempdir(mkpath(joinpath(CHAIN_REPO,"runs"));prefix="candidate_chain_") : first(ARGS))
mkpath(CHAIN_RUN_DIR)
isempty(readdir(CHAIN_RUN_DIR)) || error("use a new empty run directory; existing executions are preserved")
const CHAIN_STARTED_HEAD = strip(read(`git -C $CHAIN_REPO rev-parse HEAD`,String))
const CHAIN_STARTED_DIRTY = read(`git -C $CHAIN_REPO status --porcelain=v1`,String)
write(joinpath(CHAIN_RUN_DIR,"process.txt"),"pid=$(getpid())\nhead=$CHAIN_STARTED_HEAD\n")
write(joinpath(CHAIN_RUN_DIR,"initial_git_status.txt"),CHAIN_STARTED_DIRTY)
ENV["RFQ3_RUN_ROOT"] = joinpath(CHAIN_RUN_DIR,"providers")
println("CHAIN_RUN_DIR=",CHAIN_RUN_DIR); flush(stdout)

include(joinpath(CHAIN_REPO,"examples","runtime_v4_regional_force_independent_cubature.jl"))
println("CHAIN_UPSTREAM_EXIT_CODE=0"); flush(stdout)
const CCR = RFQ4
for name in ("CandidateChainContractV4.jl","CandidateCoupledPhysicsV4.jl",
        "CandidateEngineeringExecutionV4.jl","CandidateValidationPropagationV4.jl",
        "CandidateEndToEndV4.jl")
    Base.include(CCR,joinpath(CHAIN_REPO,"src","RuntimeV4",name))
end

const chain_physics = CCR.execute_candidate_coupled_physics(imit_upstream,
    independent_execution;run_dir=joinpath(CHAIN_RUN_DIR,"physics"),
    reference_length_m=Float64(dgpi_scale.value))
write(joinpath(CHAIN_RUN_DIR,"physics.json"),canonical_json(
    semantic_view(chain_physics))*"\n")
println("CHAIN_PHYSICS_WEAK_VOLUME_EXIT_CODE=0"); flush(stdout)
const chain_engineering = CCR.execute_candidate_engineering(first(imit_upstream),
    imit_upstream,imit_request,imit_result)
write(joinpath(CHAIN_RUN_DIR,"engineering.json"),canonical_json(
    semantic_view(chain_engineering))*"\n")
println("CHAIN_ENGINEERING_LOAD_PROJECTION_EXIT_CODE=0"); flush(stdout)
const chain_validation = CCR.execute_candidate_validation_propagation(
    imit_upstream,imit_request,imit_result,drifo_request,drifo_result,
    drifo_execution,q3_execution,q4_execution,independent_execution;
    run_dir=joinpath(CHAIN_RUN_DIR,"validation"))
write(joinpath(CHAIN_RUN_DIR,"validation.json"),canonical_json(
    semantic_view(chain_validation))*"\n")
println("CHAIN_NUMERICAL_DIAGNOSTIC_EXIT_CODE=0"); flush(stdout)
const chain_result = CCR.build_candidate_end_to_end(imit_upstream,
    imit_request,imit_result,drifo_request,drifo_result,drifo_execution,
    q3_execution,q4_execution,independent_execution,
    chain_physics,chain_engineering,chain_validation)
CCR.write_candidate_chain_report(chain_result,CHAIN_RUN_DIR)
println("CHAIN_WHOLE_DEVICE_ASSESSMENT_EXIT_CODE=0"); flush(stdout)

include(joinpath(CHAIN_REPO,"test","runtime_v4_candidate_coupled_physics_tests.jl"))
test_candidate_coupled_physics(CCR,imit_upstream,independent_execution,chain_physics)
include(joinpath(CHAIN_REPO,"test","runtime_v4_candidate_engineering_integration_checks.jl"))
check_candidate_engineering_integration(CCR,first(imit_upstream),imit_upstream,
    imit_request,imit_result,chain_engineering)
include(joinpath(CHAIN_REPO,"test","runtime_v4_candidate_validation_propagation_integration_tests.jl"))
test_candidate_validation_propagation_integration(chain_validation,imit_upstream,
    imit_request,imit_result,drifo_request,drifo_result,drifo_execution,
    q3_execution,q4_execution,independent_execution)
test_candidate_periodic_physics_agreement(chain_physics,chain_validation)
include(joinpath(CHAIN_REPO,"test","runtime_v4_candidate_chain_checks.jl"))
test_candidate_chain(CCR,chain_result,first(imit_upstream),chain_physics,
    chain_engineering,chain_validation)
include(joinpath(CHAIN_REPO,"test","runtime_v4_regional_force_independent_cubature_checks.jl"))
test_candidate_independent_cubature(independent_execution,imit_upstream,
    imit_request,imit_result,drifo_request,drifo_result,drifo_execution,
    q3_execution,q4_execution)
println("CHAIN_INTEGRATION_TESTS_EXIT_CODE=0"); flush(stdout)

function chain_file_record(path)
    (path=relpath(path,CHAIN_REPO),sha256=Digest256(bytes2hex(SHA.sha256(read(path)))))
end
const chain_sources = Tuple(chain_file_record(joinpath(root,file))
    for dir in ("src","examples","scripts","test")
    for (root,dirs,files) in walkdir(joinpath(CHAIN_REPO,dir))
    for file in sort(files) if endswith(file,".jl") || endswith(file,".py") ||
        file in ("Project.toml","Manifest.toml"))
const chain_artifacts = Tuple(chain_file_record(joinpath(root,file))
    for (root,dirs,files) in walkdir(CHAIN_RUN_DIR) for file in sort(files))
const chain_manifest = (revision="candidate-chain-run-v1",candidate_hash=chain_result.identity.candidate_hash,
    context_hash=chain_result.identity.context_hash,result_hash=chain_result.result_hash,
    starting_head=CHAIN_STARTED_HEAD,final_head=strip(read(`git -C $CHAIN_REPO rev-parse HEAD`,String)),
    julia_version=string(VERSION),julia_executable=joinpath(Sys.BINDIR,Base.julia_exename()),
    project=chain_file_record(joinpath(CHAIN_REPO,"Project.toml")),
    manifest=chain_file_record(joinpath(CHAIN_REPO,"Manifest.toml")),
    sources=chain_sources,artifacts=chain_artifacts,
    script_exit_code=0,whole_device_outcome=chain_result.outcome)
write(joinpath(CHAIN_RUN_DIR,"execution_manifest.json"),canonical_json(chain_manifest)*"\n")
println("candidate_hash=",chain_result.identity.candidate_hash)
println("whole_device_outcome=",chain_result.outcome)
println("numerical_status=",chain_validation.numerical_status)
println("local_force_integral_relative_spread=",chain_validation.local_force_integral_relative_spread)
println("midpoint_local_force_magnitude_integral_N=",
    last(chain_validation.quadrature_diagnostics).value.local_force_magnitude_integral_N)
println("jacobian_fd_max_scaled_error=",chain_physics.jacobian_fd_max_scaled_error)
println("credible_device_count=",chain_result.credible_device_count)
write(joinpath(CHAIN_RUN_DIR,"runner.exit"),"0\n")
println("CANDIDATE_END_TO_END_EXIT_CODE=0")
