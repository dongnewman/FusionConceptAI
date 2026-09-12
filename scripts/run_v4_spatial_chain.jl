# julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl RUN_DIR [--resume] [--upstream-only] [--physics-only]
using FusionConceptAI,SHA,Serialization,Test,Dates,LinearAlgebra
const SPATIAL_REPO=dirname(@__DIR__)
isempty(ARGS) && error("new spatial run directory required")
const SPATIAL_RUN=abspath(first(ARGS))
const SPATIAL_RESUME="--resume" in ARGS
mkpath(SPATIAL_RUN)
!SPATIAL_RESUME && !isempty(readdir(SPATIAL_RUN)) && error("refusing nonempty run directory")
file_record(p)=(path=abspath(p),sha256=Digest256(bytes2hex(SHA.sha256(read(p)))))
const SPATIAL_LEDGER=joinpath(SPATIAL_RUN,"execution_ledger.jsonl")
function spatial_ledger_event(stage,state;classification=:not_executed,program_exit_code=nothing,
        solver_exit_code=nothing,scientific_status=:not_available,elapsed_seconds=0.0,detail=(;))
    event=(timestamp_utc=string(Dates.now(Dates.UTC)),stage=String(stage),execution_state=state,
        classification=classification,program_exit_code=program_exit_code,solver_exit_code=solver_exit_code,
        scientific_status=scientific_status,elapsed_seconds=elapsed_seconds,detail=detail)
    open(SPATIAL_LEDGER,"a") do io
        println(io,canonical_json(event));flush(io)
    end
    println("SPATIAL_LEDGER_EVENT=",stage," state=",state," classification=",classification);flush(stdout)
    event
end
function spatial_recorded(f,stage;completion=x->(;solver_exit_code=nothing,scientific_status=:not_applicable))
    started=time_ns();spatial_ledger_event(stage,:running;classification=:running)
    try
        value=f();done=completion(value);elapsed=(time_ns()-started)/1e9
        class=done.scientific_status===:fail ? :scientific_fail :
            (done.scientific_status in (:unsupported,:deferred) ? :scientific_unsupported_or_deferred : :completed)
        spatial_ledger_event(stage,:completed;classification=class,program_exit_code=0,
            solver_exit_code=done.solver_exit_code,scientific_status=done.scientific_status,
            elapsed_seconds=elapsed)
        value
    catch err
        elapsed=(time_ns()-started)/1e9
        class=err isa InterruptException ? :human_interruption : :program_exception
        spatial_ledger_event(stage,:aborted;classification=class,
            program_exit_code=err isa InterruptException ? 130 : 1,elapsed_seconds=elapsed,
            detail=(exception_type=string(typeof(err)),message=sprint(showerror,err)))
        rethrow()
    end
end
if !SPATIAL_RESUME
    for stage in (:candidate,:upstream_DESC,:physics,:engineering,:verification,:whole,:manifest)
        spatial_ledger_event(stage,:not_executed)
    end
else
    spatial_ledger_event(:runner,:resume_requested;classification=:resume)
end
const SPATIAL_ENVIRONMENT=joinpath(SPATIAL_RUN,"environment.json")
const spatial_environment=(julia_version=string(VERSION),machine=Sys.MACHINE,kernel=string(Sys.KERNEL),
    architecture=string(Sys.ARCH),logical_cpu_threads=Sys.CPU_THREADS,julia_threads=Threads.nthreads(),
    blas_threads=LinearAlgebra.BLAS.get_num_threads(),word_size=Sys.WORD_SIZE,
    thread_environment=(JULIA_NUM_THREADS=get(ENV,"JULIA_NUM_THREADS",nothing),
        OMP_NUM_THREADS=get(ENV,"OMP_NUM_THREADS",nothing),OPENBLAS_NUM_THREADS=get(ENV,"OPENBLAS_NUM_THREADS",nothing),
        MKL_NUM_THREADS=get(ENV,"MKL_NUM_THREADS",nothing),XLA_FLAGS=get(ENV,"XLA_FLAGS",nothing)))
if SPATIAL_RESUME
    isfile(SPATIAL_ENVIRONMENT) && read(SPATIAL_ENVIRONMENT,String)==canonical_json(spatial_environment)*"\n" ||
        error("resume environment snapshot differs")
else
    write(SPATIAL_ENVIRONMENT,canonical_json(spatial_environment)*"\n")
end
if !SPATIAL_RESUME
    write(joinpath(SPATIAL_RUN,"initial_head.txt"),read(`git -C $SPATIAL_REPO rev-parse HEAD`,String))
    write(joinpath(SPATIAL_RUN,"initial_status.txt"),read(`git -C $SPATIAL_REPO status --porcelain=v1`,String))
end
println("SPATIAL_RUN=",SPATIAL_RUN);flush(stdout)
spatial_recorded(:candidate) do
    include(joinpath(SPATIAL_REPO,"examples","runtime_v4_spatial_candidate.jl"))
end
const ctx=spatial_context
const candidate_record=canonical_json((candidate=semantic_view(ctx.candidate),candidate_hash=ctx.candidate_hash,
    context_hash=ctx.context_hash,parent_hash=spatial.parent_hash,changes=spatial.changes,provenance=spatial.provenance))*"\n"
const candidate_path=joinpath(SPATIAL_RUN,"candidate.json")
if SPATIAL_RESUME
    isfile(candidate_path) && read(candidate_path,String)==candidate_record || error("resume candidate bytes differ")
else
    write(candidate_path,candidate_record)
end
write(joinpath(SPATIAL_RUN,"process.txt"),"pid=$(getpid())\n")
println("SPATIAL_CANDIDATE_HASH=",ctx.candidate_hash);flush(stdout)
const reused=Dict{String,Bool}()
const upstream_path=joinpath(SPATIAL_RUN,"upstream.jls")
reused["upstream"]=SPATIAL_RESUME && isfile(upstream_path)
const upstream=spatial_recorded(:upstream_DESC;
        completion=u->(;solver_exit_code=u.result.receipt.exit_code,scientific_status=:observed)) do
    if reused["upstream"]
        u=deserialize(upstream_path)
        u.request.candidate_hash==ctx.candidate_hash && u.request.context_hash==ctx.context_hash || error("foreign upstream checkpoint")
        SCV.validate_desc_geometry_compatibility(ctx,u.bridge,u.geometry,u.proof)
        SCV.validate_desc_provider_receipt(something(u.result.receipt))
        u
    else
        SPATIAL_RESUME && error("missing upstream checkpoint; inspect prior failure before starting another solve")
        probe=SCV.probe_desc_environment()
        controls=SCV.DESCExecutionControlsV4(2,2,1,4,4,3,20,1e-8,1e-8,1e-8)
        request=SCV.make_desc_execution_request(ctx,spatial_bridge,spatial_geometry,spatial_proof,controls)
        result=SCV.execute_desc_request_provider(ctx,request,spatial_bridge,spatial_geometry,spatial_proof,probe;run_dir=joinpath(SPATIAL_RUN,"desc"))
        u=(bridge=spatial_bridge,geometry=spatial_geometry,proof=spatial_proof,request=request,result=result,probe=probe)
        write(joinpath(SPATIAL_RUN,"upstream.json"),canonical_json(u)*"\n")
        result.provider_executed || error("DESC execution did not finish; inspect upstream.json")
        serialize(upstream_path,u);u
    end
end
write(joinpath(SPATIAL_RUN,"upstream_receipt.json"),canonical_json(semantic_view(upstream.result.receipt))*"\n")
println("SPATIAL_DESC_PROCESS_EXIT_CODE=",upstream.result.receipt.exit_code);flush(stdout)
if "--upstream-only" in ARGS
    write(joinpath(SPATIAL_RUN,"upstream_stage.exit"),"0\n");exit(0)
end
function checkpoint_stage(name,execute,validate)
    path=joinpath(SPATIAL_RUN,name*".jls")
    reused[name]=SPATIAL_RESUME && isfile(path)
    stage_dir=joinpath(SPATIAL_RUN,name)
    !reused[name] && isdir(stage_dir) && !isempty(readdir(stage_dir)) &&
        error("stage $name has partial artifacts but no checkpoint; inspect/recover them before another execution")
    result=spatial_recorded(Symbol(name);
            completion=r->(;solver_exit_code=r.solver_exit_code,scientific_status=r.status)) do
        println("SPATIAL_STAGE_BEGIN=",name," reused=",reused[name]);flush(stdout)
        if reused[name]
            r=deserialize(path);validate(r);r
        else
            r=execute();serialize(path,r);r
        end
    end
    write(joinpath(SPATIAL_RUN,name*".json"),canonical_json(semantic_view(result))*"\n")
    println("SPATIAL_STAGE_EXIT=",name," code=",result.solver_exit_code);flush(stdout)
    result
end
const physics=checkpoint_stage("physics",()->SCV.execute_spatial_multiregion_v4(ctx,upstream,joinpath(SPATIAL_RUN,"physics")),
    r->SCV.validate_spatial_result_v4(ctx,r))
SCV.validate_spatial_upstream_link_v4(upstream,physics)
if "--physics-only" in ARGS
    write(joinpath(SPATIAL_RUN,"physics_stage.exit"),"0\n");exit(0)
end
const engineering=checkpoint_stage("engineering",()->SCV.execute_spatial_engineering_v4(ctx,physics,joinpath(SPATIAL_RUN,"engineering")),
    r->SCV.validate_spatial_engineering_result_v4(ctx,physics,r))
const verification=checkpoint_stage("verification",()->SCV.execute_spatial_verification_v4(ctx,upstream,physics,engineering,joinpath(SPATIAL_RUN,"verification")),
    r->SCV.validate_spatial_verification_result_v4(ctx,upstream,physics,engineering,r))
# The independent verification validator seals request bytes back to real states.
SCV.validate_spatial_verification_result_v4(ctx,upstream,physics,engineering,verification)
Base.include(SCV,joinpath(SPATIAL_REPO,"src","RuntimeV4","SpatialWholeDeviceV4.jl"))
const whole=spatial_recorded(:whole;
        completion=w->(;solver_exit_code=0,scientific_status=w.status)) do
    w=SCV.assess_spatial_whole_device_v4(ctx,upstream,physics,engineering,verification)
    SCV.write_spatial_whole_device_v4(w,SPATIAL_RUN)
    include(joinpath(SPATIAL_REPO,"test","runtime_v4_spatial_chain_checks.jl"))
    check_spatial_chain_v4(SCV,ctx,upstream,physics,engineering,verification,w)
    w
end
const sources=Tuple(file_record(joinpath(root,file)) for dir in ("src","scripts","examples","test")
    for (root,dirs,files) in walkdir(joinpath(SPATIAL_REPO,dir)) for file in sort(files)
    if endswith(file,".jl") || endswith(file,".py"))
const receipt=upstream.result.receipt
const dependencies=Tuple((path=getproperty(receipt,p),sha256=getproperty(receipt,h)) for (p,h) in
    ((:input_path,:input_sha256),(:output_path,:output_sha256),(:adapter_path,:adapter_source_sha256),
     (:inspector_path,:inspector_source_sha256),(:python_executable,:python_executable_sha256),(:desc_module_path,:desc_module_sha256)))
const artifacts=let records=Dict{String,NamedTuple}()
    local_records=Tuple(file_record(joinpath(root,file)) for (root,dirs,files) in walkdir(SPATIAL_RUN)
        for file in sort(files) if !(file in ("execution_manifest.json","runner.exit","process.txt","execution_ledger.jsonl")))
    for x in (local_records...,dependencies...)
        haskey(records,x.path) && records[x.path].sha256!=x.sha256 && error("conflicting dependency hashes")
        records[x.path]=x
    end
    Tuple(records[k] for k in sort(collect(keys(records))))
end
spatial_ledger_event(:manifest,:completed;classification=:completed,program_exit_code=0,
    solver_exit_code=0,scientific_status=whole.status,
    detail=(scope="manifest inputs sealed; runner.exit is written after the manifest",))
const manifest=(candidate_hash=ctx.candidate_hash,context_hash=ctx.context_hash,result_hash=whole.result_hash,
    starting_head=strip(read(joinpath(SPATIAL_RUN,"initial_head.txt"),String)),julia_version=string(VERSION),
    julia_executable=file_record(joinpath(Sys.BINDIR,Base.julia_exename())),project=file_record(joinpath(SPATIAL_REPO,"Project.toml")),
    manifest=file_record(joinpath(SPATIAL_REPO,"Manifest.toml")),environment=file_record(SPATIAL_ENVIRONMENT),
    execution_ledger=file_record(SPATIAL_LEDGER),sources=sources,artifacts=artifacts,
    command=(executable=joinpath(Sys.BINDIR,Base.julia_exename()),arguments=("--startup-file=no","--project=.",abspath(@__FILE__),ARGS...),working_directory=pwd()),
    resume=SPATIAL_RESUME,reused_checkpoints=reused,
    fresh_reproduction_command="julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl <new-run-dir>",
    process_exit_code=0,physical_solver_exit_code=physics.solver_exit_code,engineering_solver_exit_code=engineering.solver_exit_code,
    verification_exit_code=verification.solver_exit_code,outcome=whole.status,physical_validation=:unsupported,p5_ready=false,credible_device_count=0)
write(joinpath(SPATIAL_RUN,"execution_manifest.json"),canonical_json(manifest)*"\n")
write(joinpath(SPATIAL_RUN,"runner.exit"),"0\n")
println("SPATIAL_CHAIN_RUNNER_EXIT_CODE=0")
