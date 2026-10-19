# Focused opt-in production dispatch and evidence/replay tests. No acceptance
# of nonlinear convergence, mesh refinement, or external closure is implied.
module BoundedProductionV1Tests
using Test, LinearAlgebra, SparseArrays, SHA, FusionConceptAI
const REPO=normpath(joinpath(@__DIR__,"..","..",".."))
const LEGACY_FIXTURE_DIR=joinpath(REPO,"test","fixtures","historical_sources","bounded_production_r2")
const LEGACY_SOURCE_FIXTURE=joinpath(LEGACY_FIXTURE_DIR,"SpatialMultiRegionV4.before_bounded_step.jl")
const FAILED_INPUT_FIXTURE=joinpath(LEGACY_FIXTURE_DIR,"step_0001_input.json")
const LEGACY_SOURCE_FIXTURE_BYTES=63745
const LEGACY_SOURCE_FIXTURE_SHA256="022b57b8f75da597fcd6b6a8d6783cf7eba514d4c0e558ef0e81a5282fc67bc8"
const FAILED_INPUT_FIXTURE_BYTES=443406
const FAILED_INPUT_FIXTURE_SHA256="27df9da2f717d34eda92086fa4c3026a2b2760b61b074bc4b74f40ce1156f41d"
const BOUNDED_STEP_BACKEND_PATH=joinpath(REPO,"src","RuntimeV4","SpatialBoundedLinearStepV1.jl")
const BOUNDED_STEP_BACKEND_SHA256=bytes2hex(SHA.sha256(read(BOUNDED_STEP_BACKEND_PATH)))
include(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl"))
const N=N1ManufacturedRefinementV2
const S=N.S
module PreservedLegacy
    include(joinpath(@__DIR__,"..","..","..","src","RuntimeV4","SpatialExecutionTypesV4.jl"))
    include(joinpath(@__DIR__,"..","..","fixtures","historical_sources","bounded_production_r2",
        "SpatialMultiRegionV4.before_bounded_step.jl"))
end
const L=PreservedLegacy

function replace_declaration(d;kwargs...)
    values=merge(S.semantic_view(d),(;kwargs...))
    S.SpatialMultiRegionDeclarationV4((getproperty(values,k) for k in fieldnames(typeof(d)))...)
end
function artifact_catalog(root,attempts)
    artifacts=NamedTuple()
    for (j,t) in enumerate(attempts),kind in (:input,:result)
        ref=getproperty(t.bounded_linear_step,Symbol(kind,"_artifact"))
        path=S._smr_bounded_path_v1(root,ref.relative_path)
        artifacts=merge(artifacts,NamedTuple{(Symbol("bounded_",kind,"_",j),)}((S._smr_artifact(path,ref.schema,1),)))
    end
    artifacts
end
function main(args)
    length(args)==1 || error("expected unused OUTPUT directory")
    out=abspath(only(args));ispath(out) && error("retain existing test evidence");mkpath(out)
    println("BOUNDED_PRODUCTION_TEST_ENV julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads())
    @testset "lossless local canonical artifact reader" begin
        @test filesize(LEGACY_SOURCE_FIXTURE)==LEGACY_SOURCE_FIXTURE_BYTES
        @test N.sha(LEGACY_SOURCE_FIXTURE)==LEGACY_SOURCE_FIXTURE_SHA256
        @test filesize(FAILED_INPUT_FIXTURE)==FAILED_INPUT_FIXTURE_BYTES
        @test N.sha(FAILED_INPUT_FIXTURE)==FAILED_INPUT_FIXTURE_SHA256
        fixture=(integer=3,float=3.0,zero=-0.0,negative=-2.5,tiny=1.0e-10,positive_exponent=1.25e20,
            large=Int64(9007199254740993),digest=canonical_hash((input=:test,)),
            nested=(key123="digits 123 and escaped quote \"4.0\" and backslash \\5",flag=true,absent=nothing),
            mixed=(1,1.0,0.25,Int64(9007199254740993),false,nothing,"6.0"))
        wire=canonical_json(fixture)*"\n"
        lossy=S._smr_json_native_v1(S.JSON3.read(wire))
        @test canonical_json(lossy)!=canonical_json(fixture)
        restored=S._smr_read_canonical_json_v1(wire)
        @test canonical_json(restored)==canonical_json(fixture)
        @test restored.integer isa Int64 && restored.float isa Float64
        @test restored.large==Int64(9007199254740993)
        @test restored.mixed[4]==Int64(9007199254740993)
        @test S._smr_same_json_v1(restored.digest,fixture.digest)
        @test string(restored.digest)!=string(fixture.digest)
        @test restored.zero isa Float64 && restored.nested.flag isa Bool && restored.nested.absent===nothing
        @test !signbit(restored.zero) && restored.negative==-2.5 && restored.positive_exponent==1.25e20
        @test !S._smr_same_json_v1(S._smr_read_canonical_json_v1("{\"x\":1}\n"),S._smr_read_canonical_json_v1("{\"x\":1.0}\n"))
        for invalid in ("{\"x\":3e0}\n","{\"x\":3,\"x\":3}\n","{\"x\": 3}\n","{\"x\":3}",
                "{\"x\":-0.0}\n","{\"x\":-0}\n")
            @test_throws Exception S._smr_read_canonical_json_v1(invalid)
        end
        failed_wire=read(FAILED_INPUT_FIXTURE,String)
        @test canonical_json(S._smr_json_native_v1(S.JSON3.read(failed_wire)))*"\n"!=failed_wire
        @test canonical_json(S._smr_read_canonical_json_v1(failed_wire))*"\n"==failed_wire
    end
    old=S.spatial_multiregion_declaration_v4(flux_Wb=pi)
    bounded=S.spatial_multiregion_bounded_step_v1(old)
    loaded=S.spatial_multiregion_declared_loads_v1(old;source_xyz_N_m3=(3.0,-2.0,1.0),normal_B_T=0.0,
        source_provenance="explicit numerical load only",boundary_provenance="closed torus zero normal field")
    combined=S.spatial_multiregion_bounded_step_v1(loaded)
    @testset "authoritative version and frozen original declaration" begin
        @test canonical_json(old)==canonical_json(L.spatial_multiregion_declaration_v4(flux_Wb=pi))
        @test S.validate_spatial_multiregion_declaration_v4(bounded)
        @test S.validate_spatial_multiregion_declaration_v4(combined)
        @test length(unique(canonical_hash.((old,loaded,bounded,combined))))==4
        for (base,new) in ((old,bounded),(loaded,combined))
            for field in fieldnames(typeof(old))
                field in (:revision,:solver) && continue
                @test getfield(base,field)==getfield(new,field)
            end
            for field in keys(base.solver)
                field==:method && continue
                @test getproperty(base.solver,field)==getproperty(new.solver,field)
            end
        end
        @test_throws ArgumentError S.spatial_multiregion_bounded_step_v1(bounded)
        for bad in (replace_declaration(bounded;solver=merge(bounded.solver,(residual_tolerance=1.0e-3,))),
                replace_declaration(bounded;solver=merge(bounded.solver,(coarse_iterations=13,))),
                replace_declaration(bounded;solver=merge(bounded.solver,(bounded_linear_step=merge(bounded.solver.bounded_linear_step,
                    (implementation_sha256=repeat("0",64),)),))),
                replace_declaration(bounded;revision=old.revision),
                replace_declaration(combined;boundary=merge(combined.boundary,(normal_B_T=0.1,))),
                replace_declaration(combined;source=merge(combined.source,(unit="Pa",))))
            @test_throws ArgumentError S.validate_spatial_multiregion_declaration_v4(bad)
        end
        @test_throws ArgumentError S._smr_check_bounded_method_v1(replace_declaration(bounded;revision=old.revision))
        @test S._smr_has_loads(combined)
        @test S._smr_bounded_identity_v1().implementation_sha256==BOUNDED_STEP_BACKEND_SHA256
    end
    fixture=N.fixture_v2(first(N.LEVELS));data=fixture.data
    # The numerical fixture keeps its old 40-DOF grid. It is deliberately not
    # an authoritative candidate declaration and earns no candidate credit.
    d=replace_declaration(bounded;spaces=fixture.declaration.spaces)
    initial=data.initial_state.+repeat(collect(N.INPUTS.perturbation),div(length(data.initial_state),4))
    kwargs=(flux_Wb=N.flux_v2(),limits=(max_iterations=1,seconds=120.0),
        source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2)
    @testset "unchanged actual legacy update" begin
        mesh=L.SpatialMeshV4((getfield(data.mesh,k) for k in fieldnames(typeof(data.mesh)))...)
        legacy_d=L.SpatialMultiRegionDeclarationV4((getfield(fixture.declaration,k) for k in fieldnames(typeof(fixture.declaration)))...)
        previous=L.solve_spatial_state_v4(legacy_d,merge(data,(mesh=mesh,)),initial;kwargs...)
        current=S.solve_spatial_state_v4(fixture.declaration,data,initial;kwargs...)
        for key in (:initial_state,:final_state,:solver_exit_code,:stopping_reason,:attempt_count,:accepted_update_count)
            @test getproperty(current,key)==getproperty(previous,key)
        end
        @test current.final_assembly.residual==previous.final_assembly.residual
        @test current.final_assembly.jacobian==previous.final_assembly.jacobian
        @test current.attempts[1].proposed_scaled_step==previous.attempts[1].proposed_scaled_step
        write(joinpath(out,"legacy_equivalence.json"),canonical_json((equivalent=true,scope=:one_actual_update,
            original_exit=previous.solver_exit_code,current_exit=current.solver_exit_code,state=current.final_state))*"\n")
    end
    root=joinpath(out,"bounded_dispatch");mkpath(root)
    binding=(scope=:manufactured_numerical_only,callback_source_sha256=N.sha(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl")),
        analytic_inputs=N.INPUTS)
    sink=S._smr_bounded_sink_v1(root,binding)
    sol=S.solve_spatial_state_v4(d,data,initial;kwargs...,_bounded_evidence_sink=sink)
    write(joinpath(root,"solver_primary.json"),canonical_json((solver_exit_code=sol.solver_exit_code,stopping_reason=sol.stopping_reason,
        final_state=sol.final_state,iterations=sol.iterations,attempts=sol.attempts,numerical_algorithm=sol.numerical_algorithm))*"\n")
    arts=artifact_catalog(root,sol.attempts)
    @testset "actual opt-in dispatch and full nonlinear acceptance replay" begin
        @test sol.attempt_count==1
        t=only(sol.attempts)
        @test t.bounded_linear_step.converged
        @test t.bounded_linear_step.audit.passed
        @test t.accepted
        @test t.direction==:lower_bounded_sparse_QR_active_set_v1
        @test t.bounded_linear_step.physical_convergence==:not_assessed
        @test S._smr_replay_bounded_attempt_v1(d,data,Tuple(initial),t,binding,root,arts;
            flux_Wb=N.flux_v2(),source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2,limits=kwargs.limits)
        @test_throws Exception S._smr_replay_bounded_attempt_v1(d,data,Tuple(initial),merge(t,
            (proposed_scaled_step=Tuple(collect(t.proposed_scaled_step).+0.01),)),binding,root,arts;
            flux_Wb=N.flux_v2(),source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2,limits=kwargs.limits)
        @test_throws Exception S._smr_replay_bounded_attempt_v1(d,data,Tuple(initial),t,merge(binding,(scope=:foreign,)),root,arts;
            flux_Wb=N.flux_v2(),source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2,limits=kwargs.limits)
        for altered in (merge(t,(accepted_alpha=t.accepted_alpha/2,)),
                merge(t,(trials=Tuple(j==length(t.trials) ? merge(z,(armijo_accepted=!z.armijo_accepted,)) : z for (j,z) in enumerate(t.trials)),)))
            @test_throws Exception S._smr_replay_bounded_attempt_v1(d,data,Tuple(initial),altered,binding,root,arts;
                flux_Wb=N.flux_v2(),source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2,limits=kwargs.limits)
        end
        ref=t.bounded_linear_step.result_artifact
        result_path=S._smr_bounded_path_v1(root,ref.relative_path)
        original_bytes=read(result_path)
        payload=S._smr_read_canonical_json_v1(String(copy(original_bytes)))
        negative_records=NamedTuple[]
        for (label,bad_result) in ((:inner_limit,merge(payload.result,(inner_iteration_limit=payload.result.inner_iteration_limit+1,))),
                (:history_count,merge(payload.result,(inner_iterations=payload.result.inner_iterations+1,))),
                (:terminal_event,merge(payload.result,(history=Tuple(j==length(payload.result.history) ? merge(h,(event="release",)) : h
                    for (j,h) in enumerate(payload.result.history)),))))
            try
                write(result_path,canonical_json(merge(payload,(result=bad_result,)))*"\n")
                new_art=S._smr_artifact(result_path,ref.schema,1)
                changed=merge(t,(bounded_linear_step=merge(t.bounded_linear_step,
                    (result_artifact=merge(ref,(sha256=new_art.sha256,)),)),))
                changed_arts=merge(arts,(bounded_result_1=new_art,))
                @test_throws Exception S._smr_replay_bounded_attempt_v1(d,data,Tuple(initial),changed,binding,root,changed_arts;
                    flux_Wb=N.flux_v2(),source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2,limits=kwargs.limits)
                push!(negative_records,(mutation=label,artifact_sha256=new_art.sha256,reference_hash_updated=true))
            finally
                write(result_path,original_bytes)
            end
        end
        write(joinpath(root,"rehash_negative_cases.json"),canonical_json(Tuple(negative_records))*"\n")
        @test S._smr_sha(result_path)==ref.sha256
        @test_throws ArgumentError S._smr_bounded_path_v1(root,"../escape.json")
        @test_throws ArgumentError S._smr_bounded_write_v1(sink,1,:input,(schema="must-not-overwrite",))
        @test sol.solver_exit_code!=0 || maximum(abs,sol.final_assembly.residual./sol.final_assembly.row_scales)<=1.0e-6
        @test all(>=(0.0),sol.final_state[4:4:end])
    end
    @testset "real inner budget failure retains input and result" begin
        failroot=joinpath(out,"inner_budget_failure");mkpath(failroot)
        failsink=S._smr_bounded_sink_v1(failroot,binding)
        a=S.assemble_spatial_system_v4(d,data,initial;flux_Wb=N.flux_v2(),source_function=N.source_v2,
            boundary_function=N.traction_v2,normal_field_function=N.normal_v2)
        cols=repeat([d.scaling.B_T,d.scaling.B_T,d.scaling.B_T,d.scaling.p_Pa],div(length(initial),4))
        r=a.residual./a.row_scales;A=spdiagm(0=>1 ./a.row_scales)*a.jacobian*spdiagm(0=>cols)
        inner=S._smr_bounded_attempt_v1(d,data,initial,a,A,r,cols,N.flux_v2(),1,0.0,failsink,(N.source_v2,N.traction_v2,N.normal_v2))
        @test !inner.success
        @test inner.summary.status==:wall_time_budget
        @test inner.summary.classification==:resource_limit
        @test isfile(S._smr_bounded_path_v1(failroot,inner.summary.input_artifact.relative_path))
        @test isfile(S._smr_bounded_path_v1(failroot,inner.summary.result_artifact.relative_path))
        @test inner.result.physical_convergence==:not_assessed
    end
    write(joinpath(out,"complete.json"),canonical_json((status=:focused_tests_completed,
        scope=:dispatch_and_replay_only,nonlinear_acceptance=:not_claimed,physical_validation=:unsupported))*"\n")
end
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    BoundedProductionV1Tests.main(ARGS)
end
