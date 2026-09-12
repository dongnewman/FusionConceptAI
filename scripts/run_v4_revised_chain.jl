# Unified, sequential execution with a validated upstream checkpoint.
# julia --startup-file=no --project=. scripts/run_v4_revised_chain.jl RUN_DIR [--resume] [--upstream-only]
using FusionConceptAI, SHA, Serialization, Test
const REVISED_REPO=dirname(@__DIR__)
isempty(ARGS) && error("a new run directory is required")
const REVISED_RUN=abspath(first(ARGS))
const REVISED_RESUME="--resume" in ARGS
const REVISED_UPSTREAM_ONLY="--upstream-only" in ARGS
mkpath(REVISED_RUN)
!REVISED_RESUME && !isempty(readdir(REVISED_RUN)) && error("refusing nonempty run; use explicit --resume")
revised_file_record(p)=(path=abspath(p),sha256=Digest256(bytes2hex(SHA.sha256(read(p)))))
if !REVISED_RESUME
    write(joinpath(REVISED_RUN,"initial_head.txt"),read(`git -C $REVISED_REPO rev-parse HEAD`,String))
    write(joinpath(REVISED_RUN,"initial_status.txt"),read(`git -C $REVISED_REPO status --porcelain=v1`,String))
end
println("REVISED_RUN=",REVISED_RUN);flush(stdout)
include(joinpath(REVISED_REPO,"examples","runtime_v4_revised_candidate.jl"))
include(joinpath(@__DIR__,"revised_run_checkpoint_v4.jl"))
const ctx=revised_context
const candidate_record=canonical_json((candidate=semantic_view(ctx.candidate),
    candidate_hash=ctx.candidate_hash,context_hash=ctx.context_hash,
    parent_hash=revised.parent_hash,changes=revised.changes,provenance=revised.provenance))*"\n"
if REVISED_RESUME
    verify_revised_checkpoint_identity_v4(joinpath(REVISED_RUN,"candidate.json"),candidate_record)
else
    write(joinpath(REVISED_RUN,"candidate.json"),candidate_record)
end
println("REVISED_CANDIDATE_HASH=",ctx.candidate_hash);flush(stdout)
const checkpoint=joinpath(REVISED_RUN,"upstream.jls")
const reused_upstream=REVISED_RESUME && isfile(checkpoint)
if reused_upstream
    global upstream=deserialize(checkpoint)
    canonical_hash(upstream.request);canonical_hash(upstream.result)
    upstream.request.candidate_hash==ctx.candidate_hash &&
        upstream.request.context_hash==ctx.context_hash || error("checkpoint belongs to another candidate revision")
    RCV.validate_desc_geometry_compatibility(ctx,upstream.bridge,upstream.geometry,upstream.proof)
    RCV.validate_desc_provider_receipt(something(upstream.result.receipt))
    println("REVISED_UPSTREAM_CHECKPOINT_REUSED=true");flush(stdout)
else
    REVISED_RESUME && error("no upstream checkpoint; inspect prior failure before creating a new run")
    probe=RCV.probe_desc_environment()
    controls=RCV.DESCExecutionControlsV4(2,2,1,4,4,3,20,1e-8,1e-8,1e-8)
    request=RCV.make_desc_execution_request(ctx,revised_bridge,revised_geometry,revised_proof,controls)
    result=RCV.execute_desc_request_provider(ctx,request,revised_bridge,revised_geometry,
        revised_proof,probe;run_dir=joinpath(REVISED_RUN,"desc"))
    global upstream=(bridge=revised_bridge,geometry=revised_geometry,proof=revised_proof,
        request=request,result=result,probe=probe)
    write(joinpath(REVISED_RUN,"upstream.json"),canonical_json(upstream)*"\n")
    result.provider_executed || error("DESC provider did not finish; see upstream.json")
    serialize(checkpoint,upstream)
end
write(joinpath(REVISED_RUN,"process.txt"),"pid=$(getpid())\n")
write(joinpath(REVISED_RUN,"upstream_receipt.json"),canonical_json(semantic_view(upstream.result.receipt))*"\n")
println("REVISED_DESC_PROCESS_EXIT_CODE=",upstream.result.receipt.exit_code)
println("REVISED_DESC_INSPECTOR_EXIT_CODE=",upstream.result.receipt.inspection_exit_code);flush(stdout)
if REVISED_UPSTREAM_ONLY
    write(joinpath(REVISED_RUN,"upstream_stage.exit"),"0\n")
    println("REVISED_UPSTREAM_STAGE_EXIT_CODE=0")
    exit(0)
end

const reused_physics=REVISED_RESUME && isfile(joinpath(REVISED_RUN,"physics.jls"))
const physics=if reused_physics
    p=deserialize(joinpath(REVISED_RUN,"physics.jls"))
    RCV.validate_multiregion_result_v4(ctx,p)
    println("REVISED_PHYSICS_CHECKPOINT_REUSED=true");p
else
    RCV.execute_multiregion_v4(ctx,upstream,joinpath(REVISED_RUN,"physics"))
end
reused_physics || serialize(joinpath(REVISED_RUN,"physics.jls"),physics)
write(joinpath(REVISED_RUN,"physics.json"),canonical_json(semantic_view(physics))*"\n")
println("REVISED_PHYSICS_SOLVER_EXIT_CODE=",physics.solver_exit_code);flush(stdout)
const reused_engineering=REVISED_RESUME && isfile(joinpath(REVISED_RUN,"engineering.jls"))
const engineering=if reused_engineering
    e=deserialize(joinpath(REVISED_RUN,"engineering.jls"))
    RCV.validate_engineering_result_v4(ctx,physics,e)
    println("REVISED_ENGINEERING_CHECKPOINT_REUSED=true");e
else
    RCV.execute_engineering_v4(ctx,physics,joinpath(REVISED_RUN,"engineering"))
end
reused_engineering || serialize(joinpath(REVISED_RUN,"engineering.jls"),engineering)
write(joinpath(REVISED_RUN,"engineering.json"),canonical_json(semantic_view(engineering))*"\n")
println("REVISED_ENGINEERING_SOLVER_EXIT_CODE=",engineering.solver_exit_code);flush(stdout)
const reused_verification=REVISED_RESUME && isfile(joinpath(REVISED_RUN,"verification.jls"))
const verification=if reused_verification
    v=deserialize(joinpath(REVISED_RUN,"verification.jls"))
    RCV.validate_verification_uq_result_v4(ctx,upstream,physics,engineering,v)
    println("REVISED_VERIFICATION_CHECKPOINT_REUSED=true");v
else
    RCV.execute_verification_uq_v4(ctx,upstream,physics,engineering,joinpath(REVISED_RUN,"verification"))
end
reused_verification || serialize(joinpath(REVISED_RUN,"verification.jls"),verification)
write(joinpath(REVISED_RUN,"verification.json"),canonical_json(semantic_view(verification))*"\n")
println("REVISED_VERIFICATION_SOLVER_EXIT_CODE=",verification.solver_exit_code);flush(stdout)
Base.include(RCV,joinpath(REVISED_REPO,"src","RuntimeV4","RevisedWholeDeviceV4.jl"))
const whole=RCV.assess_revised_whole_device_v4(ctx,upstream,physics,engineering,verification)
RCV.write_revised_whole_device_v4(whole,REVISED_RUN)
include(joinpath(REVISED_REPO,"test","runtime_v4_revised_chain_checks.jl"))
check_revised_chain_v4(RCV,ctx,upstream,physics,engineering,verification,whole)
println("REVISED_INTEGRATION_TESTS_EXIT_CODE=0");flush(stdout)
const sources=Tuple(revised_file_record(joinpath(root,file))
    for dir in ("src","scripts","examples","test")
    for (root,dirs,files) in walkdir(joinpath(REVISED_REPO,dir))
    for file in sort(files) if endswith(file,".jl") || endswith(file,".py"))
const artifacts=Tuple(revised_file_record(joinpath(root,file))
    for (root,dirs,files) in walkdir(REVISED_RUN) for file in sort(files)
    if !(file in ("execution_manifest.json","runner.exit","process.txt")))
# Resumed physical checkpoints may legitimately reference their original run.
# Retain those exact sealed bytes in the final manifest as well as local outputs.
const physical_dependencies=Tuple((path=getproperty(physics.execution,key),
        sha256=getproperty(physics.execution,Symbol(replace(String(key),"_path"=>"_sha256"))))
    for key in keys(physics.execution) if endswith(String(key),"_path") &&
        haskey(physics.execution,Symbol(replace(String(key),"_path"=>"_sha256"))))
const desc_receipt=upstream.result.receipt
const desc_dependencies=Tuple((path=getproperty(desc_receipt,path),sha256=getproperty(desc_receipt,hash))
    for (path,hash) in ((:input_path,:input_sha256),(:output_path,:output_sha256),
        (:adapter_path,:adapter_source_sha256),(:inspector_path,:inspector_source_sha256),
        (:python_executable,:python_executable_sha256),(:desc_module_path,:desc_module_sha256)))
const engineering_dependencies=Tuple((path=x.path,sha256=x.sha256) for x in engineering.input_artifacts)
const manifest_artifacts=let by_path=Dict{String,NamedTuple}()
    for x in (artifacts...,physical_dependencies...,desc_dependencies...,engineering_dependencies...)
        haskey(by_path,x.path) && by_path[x.path].sha256!=x.sha256 && error("conflicting dependency hashes")
        by_path[x.path]=x
    end
    Tuple(by_path[path] for path in sort(collect(keys(by_path))))
end
manifest=(candidate_hash=ctx.candidate_hash,context_hash=ctx.context_hash,result_hash=whole.result_hash,
    starting_head=strip(read(joinpath(REVISED_RUN,"initial_head.txt"),String)),
    julia_version=string(VERSION),julia_executable=revised_file_record(joinpath(Sys.BINDIR,Base.julia_exename())),
    project=revised_file_record(joinpath(REVISED_REPO,"Project.toml")),
    manifest=revised_file_record(joinpath(REVISED_REPO,"Manifest.toml")),sources=sources,
    artifacts=manifest_artifacts,
    command=(executable=joinpath(Sys.BINDIR,Base.julia_exename()),
        arguments=("--startup-file=no","--project=.",abspath(@__FILE__),ARGS...),working_directory=pwd()),
    resume=REVISED_RESUME,reused_checkpoints=(upstream=reused_upstream,physics=reused_physics,
        engineering=reused_engineering,verification=reused_verification),
    resume_origin=isfile(joinpath(REVISED_RUN,"resume_origin.json")) ? revised_file_record(joinpath(REVISED_RUN,"resume_origin.json")) : nothing,
    fresh_reproduction_command="julia --startup-file=no --project=. scripts/run_v4_revised_chain.jl <new-run-dir>",
    process_exit_code=0,physical_solver_exit_code=physics.solver_exit_code,
    engineering_solver_exit_code=engineering.solver_exit_code,verification_exit_code=verification.solver_exit_code,
    outcome=whole.status,physical_validation=:unsupported,p5_ready=false,credible_device_count=0)
write(joinpath(REVISED_RUN,"execution_manifest.json"),canonical_json(manifest)*"\n")
write(joinpath(REVISED_RUN,"runner.exit"),"0\n")
println("REVISED_CHAIN_RUNNER_EXIT_CODE=0")
