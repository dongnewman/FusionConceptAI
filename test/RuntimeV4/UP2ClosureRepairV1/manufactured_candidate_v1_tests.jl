# Same-batch canonical input preflight and actual candidate -> provider -> writer
# -> full nonlinear solve -> attempt replay. No include-time solve and no
# alternate residual/solver implementation. DESC and physical closure remain absent.
module ManufacturedCandidateV1Tests
using Test, FusionConceptAI, LinearAlgebra, SparseArrays, SHA
const REPO=normpath(joinpath(@__DIR__,"..","..",".."))

module DefinitionRuntime
    using FusionConceptAI
    const REPO=normpath(joinpath(@__DIR__,"..","..",".."))
    for name in ("Contracts.jl","Compiler.jl","ForwardChainContext.jl","ThreeDPhysicalProviderInputV4.jl",
                 "CompleteMultiRegionV4.jl","RevisedCandidateV4.jl","SpatialExecutionTypesV4.jl",
                 "SpatialMultiRegionV4.jl","SpatialPickupEngineeringV4.jl","SpatialVerificationUQV4.jl",
                 "SpatialCandidateV4.jl","SpatialWholeDeviceV4.jl")
        include(joinpath(REPO,"src","RuntimeV4",name))
    end
end
const S=DefinitionRuntime
module ParentTemplate
    using FusionConceptAI
    include(joinpath(@__DIR__,"..","..","..","examples","runtime_v4_declared_fixture.jl"))
end
include(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl"))
const N=N1ManufacturedRefinementV2
sha(path)=bytes2hex(SHA.sha256(read(path)))

function replace_input(x;kwargs...)
    v=merge(S.semantic_view(x),(;kwargs...))
    S.SpatialManufacturedNumericalInputV1((getproperty(v,k) for k in fieldnames(typeof(x)))...)
end
function replace_receipt(x;kwargs...)
    v=merge(S.semantic_view(x),(;kwargs...))
    S.SpatialManufacturedGeometryReceiptV1((getproperty(v,k) for k in fieldnames(typeof(x)))...)
end
function replace_declaration(x;kwargs...)
    v=merge(S.semantic_view(x),(;kwargs...))
    S.SpatialMultiRegionDeclarationV4((getproperty(v,k) for k in fieldnames(typeof(x)))...)
end
matrix(rows)=[rows[i][j] for i in 1:3,j in 1:3]

function input_and_geometry_tests(out)
    x=S.spatial_n1_manufactured_input_v1();d=S.spatial_n1_manufactured_declaration_v1(x)
    write(joinpath(out,"canonical_input.json"),canonical_json(x)*"\n")
    write(joinpath(out,"canonical_declaration.json"),canonical_json(d)*"\n")
    formula_flux=x.fields.beta_T_m*x.geometry.R0_m*pi*x.geometry.minor_radius_m^2
    expected_flux=Float64(pi)
    write(joinpath(out,"flux_representation.json"),canonical_json((unit="Wb",
        formula=(value=formula_flux,type=string(typeof(formula_flux))),
        input=(value=x.flux.nominal_Wb,type=string(typeof(x.flux.nominal_Wb))),
        declaration=(value=d.flux.nominal_Wb,type=string(typeof(d.flux.nominal_Wb))),
        oracle=(value=expected_flux,type=string(typeof(expected_flux))),
        mathematical_pi_type=string(typeof(pi)),comparison=:exact_declared_Float64_representation))*"\n")
    @testset "closed manufactured numerical declaration" begin
        @test S.validate_spatial_manufactured_input_v1(x)
        @test S.validate_spatial_n1_manufactured_declaration_v1(d)
        @test d.revision=="spatial-q1-static-mhd-manufactured-n1-bounded-step-v1"
        @test x.geometry.nfp==1 && x.mesh.unknowns==40 && x.mesh.rows==289
        @test d.solver.coarse_iterations==12 && d.solver.coarse_seconds==120.0
        @test d.solver.residual_tolerance==1.0e-6 && d.solver.gradient_tolerance==1.0e-10
        @test d.solver.bounded_linear_step.policy.kkt_absolute_tolerance==1.0e-10
        @test formula_flux==x.flux.nominal_Wb==d.flux.nominal_Wb==expected_flux
        @test x.provenance.exterior_B_out.value===nothing && x.provenance.outer_K.value===nothing && x.provenance.return_current.value===nothing
        @test x.provenance.desc_execution==:not_executed && x.provenance.publish==:no_publish
        @test x.boundary.analytic_normal_B_T==0.0 && x.boundary.normal_model==:analytic_B_dot_raw_normal
        for bad in (replace_input(x;geometry=merge(x.geometry,(nfp=5,))),
                    replace_input(x;geometry=merge(x.geometry,(R0_m=3.1,))),
                    replace_input(x;geometry=merge(x.geometry,(angle_pullback=(1.0,1.0,1.0),))),
                    replace_input(x;fields=merge(x.fields,(beta_unit="T",))),
                    replace_input(x;fields=merge(x.fields,(alpha_Pa_m2=NaN,))),
                    replace_input(x;fields=merge(x.fields,(mu0_N_A2=1.0,))),
                    replace_input(x;initialization=merge(x.initialization,(perturbation=(0.0,0.0,0.0,0.0),))),
                    replace_input(x;mesh=merge(x.mesh,(theta_count=4,))),
                    replace_input(x;quadrature=merge(x.quadrature,(volume_loop=(:ir,:it,:iz),))),
                    replace_input(x;boundary=merge(x.boundary,(normal_model=:constant_zero,))),
                    replace_input(x;flux=merge(x.flux,(nominal_Wb=1.0,))),
                    replace_input(x;numerics=merge(x.numerics,(residual_tolerance=1.0e-3,))),
                    replace_input(x;provenance=merge(x.provenance,(exterior_B_out=(status=:present,value=(0.0,0.0,0.0)),))))
            @test_throws ArgumentError S.validate_spatial_manufactured_input_v1(bad)
        end
        for bad in (replace_declaration(d;solver=merge(d.solver,(coarse_iterations=13,))),
                    replace_declaration(d;source=merge(d.source,(unit="N m^-2",))),
                    replace_declaration(d;boundary=merge(d.boundary,(normal_B_T=1.0,))))
            @test_throws ArgumentError S.validate_spatial_n1_manufactured_declaration_v1(bad)
        end
        @test_throws ArgumentError S.spatial_manufactured_field_v1(x,(NaN,0.0,0.0))
        @test_throws ArgumentError S.spatial_manufactured_field_v1(x,(0.0,0.0,1.0))
        @test_throws ArgumentError S.spatial_manufactured_field_v1(x,(1.0e308,1.0e308,1.0e308))
    end

    default_hash=canonical_hash(default_operator_registry())
    typed=S.spatial_manufactured_parent_geometry_v1(x)
    write(joinpath(out,"typed_flux_representation.json"),canonical_json((unit="Wb",
        value=typed.physical_input.profiles_flux.toroidal_flux_wb,
        type=string(typeof(typed.physical_input.profiles_flux.toroidal_flux_wb)),
        expected_value=Float64(pi),expected_type=string(typeof(Float64(pi)))))*"\n")
    @testset "actual typed circular geometry and pullback ABI" begin
        @test typed.physical_input.fourier_boundary.field_periods==1
        @test typed.physical_input.profiles_flux.toroidal_flux_wb==Float64(pi)
        @test length(typed.graph.nodes)==5 && length(typed.graph.hyperedges)==2
        @test typed.typed_binding.coordinate_program.roots==(3,5)
        @test typed.typed_binding.metric_program.roots==(3,5)
        @test canonical_hash(default_operator_registry())==default_hash
        @test typed.typed_binding.coordinate_program.nodes[3].operator_ref==S._SMM_NCOORD_V1
        @test typed.typed_binding.metric_program.nodes[3].operator_ref==S._SMM_NMETRIC_V1
        for q in ((0.3,0.17,0.21),(0.8,0.39,0.67),(1.0,0.71,0.93))
            result=S.interpret_spatial_manufactured_geometry_v1(x,typed.typed_binding,q)
            z=result.value;theta=2pi*q[2];phi=2pi*q[3];R=3.0+q[1]*cos(theta)
            xyz=(R*cos(phi),R*sin(phi),q[1]*sin(theta));E=matrix(z.raw_E)
            D=Diagonal([1.0,2pi,2pi]);Q=[cos(phi) -sin(phi) 0.0;sin(phi) cos(phi) 0.0;0.0 0.0 1.0]
            @test z.coordinate==xyz
            @test matrix(z.turn_cartesian_jacobian)==Q*E*D
            @test matrix(z.turn_metric)==transpose(D)*(transpose(E)*E)*D
            @test matrix(z.raw_cartesian_jacobian)==Q*E
            @test z.signed_raw_detE<0.0
            @test isapprox(z.signed_raw_detE,-q[1]*R;rtol=2.0e-15,atol=0.0)
            @test isapprox(z.signed_turn_detJ,z.signed_raw_detE*(2pi)^2;rtol=3.0e-15,atol=0.0)
            @test S.validate_spatial_manufactured_chart_value_v1(x,q,z)
            @test result.desc_authorized===false && result.physical_validation==:unsupported
            @test_throws ArgumentError S.validate_spatial_manufactured_chart_value_v1(x,q,merge(z,(turn_metric=z.raw_metric,)))
            @test_throws ArgumentError S.validate_spatial_manufactured_chart_value_v1(x,q,merge(z,(turn_cartesian_jacobian=z.raw_cartesian_jacobian,)))
            @test_throws ArgumentError S.validate_spatial_manufactured_chart_value_v1(x,q,merge(z,(turn_cartesian_jacobian=S._smm_matrix_v1(E*D),)))
        end
        @test_throws ArgumentError S.spatial_manufactured_chart_value_v1(x,(0.5,1.1,0.0))
        @test_throws ArgumentError S.interpret_spatial_manufactured_geometry_v1(x,
            merge(typed.typed_binding,(input_hash=canonical_hash((foreign=true,)),)),(0.5,0.2,0.3))
    end
    write(joinpath(out,"typed_geometry.json"),canonical_json((physical_input=typed.physical_input,
        graph=typed.graph,support=typed.support,binding=typed.typed_binding,default_registry_hash=default_hash))*"\n")
    x,d
end

function retained_n1_correspondence_tests(x,d,out)
    old=N.fixture_v2(first(N.LEVELS));new=S.spatial_manufactured_geometry_samples_v1(x)
    flux=x.flux.nominal_Wb
    write(joinpath(out,"retained_flux_arguments.json"),canonical_json((
        argument_value_Wb=flux,argument_type=string(typeof(flux)),
        declaration_value_Wb=d.flux.nominal_Wb,declaration_type=string(typeof(d.flux.nominal_Wb)),
        legacy_declaration_value_Wb=old.declaration.flux.nominal_Wb,
        legacy_declaration_type=string(typeof(old.declaration.flux.nominal_Wb)),
        call_sites=(:legacy_declaration_constructor,:current_callback_assembly,:retained_N1_callback_assembly)))*"\n")
    oldinitial=old.data.initial_state.+repeat(collect(N.INPUTS.perturbation),div(length(old.data.initial_state),4))
    @testset "original N1 data and formula correspondence only" begin
        @test new.initial_state==oldinitial
        @test new.reference_state==old.data.initial_state
        @test new.mesh.nodes_q==old.data.mesh.nodes_q
        @test new.mesh.cell_nodes==old.data.mesh.cell_nodes && new.mesh.faces==old.data.mesh.faces
        @test new.mesh.row_blocks==old.data.mesh.row_blocks && new.mesh.row_supports==old.data.mesh.row_supports
        for (left,right) in ((new.nodes,old.data.nodes),(new.volume,old.data.volume),(new.face_quadrature,old.data.face_quadrature))
            @test left==right
            for (a,b) in zip(left,right)
                @test S._smm_source_v1(x,a.xyz)==N.source_v2(b.xyz)
                @test S._smm_traction_v1(x,a.xyz,a.normal)==N.traction_v2(b.xyz,b.normal)
                @test S._smm_normal_v1(x,a.xyz,a.normal)==N.normal_v2(b.xyz,b.normal)
            end
        end
    end
    # Stage 1 uses the retained legacy callback seam solely to compare the
    # new serializable formula against original N1. New-declaration production
    # consumption and nonlinear execution remain explicitly not_executed here.
    base=S.spatial_multiregion_declaration_v4(flux_Wb=flux)
    comparison=replace_declaration(base;spaces=d.spaces)
    current=S.assemble_spatial_system_v4(comparison,new,new.initial_state;flux_Wb=flux,
        source_function=xyz->S._smm_source_v1(x,xyz),boundary_function=(xyz,n)->S._smm_traction_v1(x,xyz,n),
        normal_field_function=(xyz,n)->S._smm_normal_v1(x,xyz,n))
    prior=N.S.assemble_spatial_system_v4(old.declaration,old.data,oldinitial;flux_Wb=flux,
        source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2)
    function primary(a,state,declaration,source_path)
        ii,jj,vv=findnz(a.jacobian)
        (declaration=declaration,declaration_hash=canonical_hash(declaration),
         source_path=source_path,source_sha256=sha(source_path),
         initial_state=Tuple(state),initial_state_hash=canonical_hash(Tuple(state)),
         raw_residual=Tuple(a.residual),row_scales=Tuple(a.row_scales),
         row_blocks=Tuple(a.row_blocks),row_supports=Tuple(a.row_supports),
         raw_jacobian=(rows=size(a.jacobian,1),columns=size(a.jacobian,2),
             row_indices=Tuple(ii),column_indices=Tuple(jj),values=Tuple(vv)))
    end
    # Save both observed assemblies before any comparison can throw.
    write(joinpath(out,"assembly_correspondence.json"),canonical_json((scope=:formula_correspondence_only,
        new_declaration_consumer=:not_executed,nonlinear_solve=:not_executed,
        input_hash=canonical_hash(x),
        current=primary(current,new.initial_state,comparison,S._SMM_SOURCE_V1),
        prior=primary(prior,oldinitial,old.declaration,joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl"))))*"\n")
    @testset "unchanged full raw assembly correspondence" begin
        @test current.residual==prior.residual
        @test current.jacobian==prior.jacobian
        @test current.row_scales==prior.row_scales
        @test current.row_blocks==prior.row_blocks && current.row_supports==prior.row_supports
    end
end

function provider_receipt_tests(x,d,out)
    # Explicit test fixture hashes: no actual candidate is claimed in Stage 1.
    binding=(candidate_hash=canonical_hash((stage1=:numerical_geometry_fixture,)),context_hash=canonical_hash((stage1=:no_candidate_execution,)))
    path=joinpath(out,"provider");r=S._smm_materialize_geometry_v1(x,d,binding,path)
    fixture_case=(level=:coarse,nfp=1,flux_Wb=x.flux.nominal_Wb,raw_artifacts=r.raw_artifacts)
    # Reproduce the retained failure only as an explicit incompatible fixture.
    irrational_flux_negative=merge(fixture_case,(flux_Wb=pi,))
    write(joinpath(out,"provider_flux_arguments.json"),canonical_json((
        actual_case=(level=fixture_case.level,nfp=fixture_case.nfp,value_Wb=fixture_case.flux_Wb,
            type=string(typeof(fixture_case.flux_Wb))),
        declaration=(value_Wb=x.flux.nominal_Wb,type=string(typeof(x.flux.nominal_Wb))),
        intentional_negative=(repr=repr(irrational_flux_negative.flux_Wb),
            type=string(typeof(irrational_flux_negative.flux_Wb)),expected_error="manufactured flux mismatch")))*"\n")
    @testset "actual file materialization and semantic rehash negatives" begin
        @test S._smm_validate_geometry_receipt_v1(x,d,binding,r)
        @test r.authority==:no_publish && r.desc_execution==:not_executed
        @test length(r.raw_artifacts)==3
        @test_throws ArgumentError S._smm_materialize_geometry_v1(x,d,binding,path)
        for bad in (replace_receipt(r;candidate_hash=canonical_hash((foreign=true,))),
                    replace_receipt(r;input_hash=canonical_hash((foreign_input=true,))),
                    replace_receipt(r;desc_execution=:executed),replace_receipt(r;authority=:accepted),
                    replace_receipt(r;enclosure=merge(r.enclosure,(R_upper_m=3.0,))))
            @test_throws ArgumentError S._smm_validate_geometry_receipt_v1(x,d,binding,bad)
        end
        nodes=S._smr_read_geometry(r.raw_artifacts.nodes;nodes=true)
        @test nodes==S.spatial_manufactured_geometry_samples_v1(x).nodes
        loaded=S.load_spatial_manufactured_data_v1(d,fixture_case)
        @test loaded.initial_state==S.spatial_manufactured_geometry_samples_v1(x).initial_state
        @test loaded.mesh.nfp==1 && length(loaded.mesh.row_blocks)==289
        flux_error=try
            S.load_spatial_manufactured_data_v1(d,irrational_flux_negative)
            nothing
        catch err
            err
        end
        write(joinpath(out,"irrational_flux_negative.json"),canonical_json((
            input_type=string(typeof(irrational_flux_negative.flux_Wb)),error_type=string(typeof(flux_error)),
            error=flux_error===nothing ? nothing : sprint(showerror,flux_error)))*"\n")
        @test flux_error isa ArgumentError
        @test flux_error isa ArgumentError && flux_error.msg=="manufactured flux mismatch"
        @test_throws ArgumentError S.load_spatial_manufactured_data_v1(d,(level=:coarse,nfp=5,raw_artifacts=r.raw_artifacts))
        for (index,mutation) in enumerate((:coordinate,:metric,:reference_pressure))
            target=joinpath(out,"rehash_negative_$(mutation)");mkpath(target)
            for name in (:nodes,:volume,:faces)
                cp(getproperty(r.raw_artifacts,name).path,joinpath(target,"manufactured_$(name).csv"))
            end
            sample_path=joinpath(target,"manufactured_volume.csv");lines=readlines(sample_path)
            fields=split(lines[2],',');column=mutation==:coordinate ? 6 : (mutation==:metric ? 16 : 37)
            fields[column]=string(parse(Float64,fields[column])+1.0);lines[2]=join(fields,',')
            write(sample_path,join(lines,'\n')*"\n")
            arts=NamedTuple{(:nodes,:volume,:faces)}(Tuple(S._smr_artifact(joinpath(target,"manufactured_$(k).csv"),
                "spatial-manufactured-geometry-v1",getproperty(r.raw_artifacts,k).row_count) for k in (:nodes,:volume,:faces)))
            bad=replace_receipt(r;raw_artifacts=arts)
            write(joinpath(target,"rehash_receipt.json"),canonical_json(bad)*"\n")
            @test arts.volume.sha256!=r.raw_artifacts.volume.sha256
            @test_throws ArgumentError S._smm_validate_geometry_receipt_v1(x,d,binding,bad)
        end
    end
end

function stage1_tests(out)
    mkpath(out)
    x,d=input_and_geometry_tests(out)
    retained_n1_correspondence_tests(x,d,out)
    provider_receipt_tests(x,d,out)
    write(joinpath(out,"stage1_complete.json"),canonical_json((schema="spatial-manufactured-stage1-tests-v1",
        status=:definition_tests_completed,input_hash=canonical_hash(x),declaration_hash=canonical_hash(d),
        producer_sha256=sha(S._SMM_SOURCE_V1),actual_candidate_chain=:not_executed,
        production_new_source_consumption=:not_executed,nonlinear_solve=:not_executed,
        desc_execution=:not_executed,refinement=:not_executed,physical_validation=:unsupported,authority=:no_publish))*"\n")
    x,d
end

function phase(f,out,label;expected_exception=false)
    start=time();start_ns=time_ns();compile_start=Base.cumulative_compile_time_ns()
    println("MMS_PHASE_BEGIN=",label);flush(stdout)
    write(joinpath(out,"phase_$(label)_start.json"),canonical_json((phase=label,pid=getpid(),started_unix=start,
        status=:started,compile_counter_ns=compile_start,expected_exception=expected_exception))*"\n")
    try
        value=f()
        elapsed=(time_ns()-start_ns)/1.0e9;compile_end=Base.cumulative_compile_time_ns()
        write(joinpath(out,"phase_$(label)_complete.json"),canonical_json((phase=label,elapsed_seconds=elapsed,status=:completed,
            compile_counter_ns=compile_end,compile_delta_ns=compile_end.-compile_start,
            compile_scope=:cumulative_compiler_counters_not_process_CPU))*"\n")
        println("MMS_PHASE_END=",label," elapsed_seconds=",elapsed);flush(stdout)
        value
    catch err
        compile_end=Base.cumulative_compile_time_ns()
        write(joinpath(out,"phase_$(label)_exception.json"),canonical_json((phase=label,elapsed_seconds=(time_ns()-start_ns)/1.0e9,
            classification=expected_exception ? :expected_rejection : :program_exception,
            compile_counter_ns=compile_end,compile_delta_ns=compile_end.-compile_start,
            error=sprint(showerror,err),trace=sprint(Base.show_backtrace,catch_backtrace())))*"\n")
        rethrow()
    end
end

function build_manufactured_parent(x,out)
    geometry=S.spatial_manufactured_parent_geometry_v1(x);template=ParentTemplate
    g2=FieldGeometryGenomeV4(2026092201,template._fixture_refs[2],geometry.graph;
        fields=(geometry.support,geometry.physical_input))
    candidate=CandidateStatePackageV4("manufactured-n1-circular-parent-v1",template._fixture_mission,
        template._fixture_mechanism,g2,template._fixture_realization,template.registry)
    mission=(mission="manufactured-n1-numerical-verification",contract=candidate.mission_contract_ref,authority=:no_publish)
    bounds=(declaration_hash=canonical_hash(geometry.physical_input),input_hash=canonical_hash(x),scope=:manufactured_numerical_only)
    comparison=("manufactured-n1-single-mesh-endpoint",)
    scenario=(name="manufactured-n1-circular-analytic",source=:manufactured_not_measured,desc_execution=:not_executed)
    scenarios=(scenario.name,)
    compiled=S.compile_candidate(candidate,template.registry;mission_payload=mission,bounds_payload=bounds,
        comparison_scope=comparison,scenario_scope=scenarios)
    binding=S.make_three_d_physical_provider_input_binding(compiled,template.registry,mission,bounds,
        comparison,scenarios,scenario,geometry.physical_input)
    subject=S.ExecutablePhysicalSubjectV4(compiled.prefix_hash,candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,compiled.minimality_scope.bounds_hash,(binding,),(scenario,),
        (input_hash=canonical_hash(x),materialization=:manufactured_analytic_provider,authority=:no_publish),
        S.derive_capability_obligations(compiled))
    context=S.make_forward_chain_context(candidate,compiled,template.registry,mission,bounds,comparison,scenarios,subject,scenario)
    write(joinpath(out,"parent_candidate.json"),canonical_json(candidate)*"\n")
    write(joinpath(out,"parent_context.json"),canonical_json(context)*"\n")
    write(joinpath(out,"parent_identity.json"),canonical_json((candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        package_hash=canonical_hash(candidate),physical_input_hash=canonical_hash(geometry.physical_input),
        numerical_input_hash=canonical_hash(x),nfp=geometry.physical_input.fourier_boundary.field_periods,
        subject_hash=canonical_hash(subject),geometry_graph_hash=canonical_hash(geometry.graph),authority=:no_publish))*"\n")
    S.validate_forward_chain_context(context)
    (context=context,physical_input=geometry.physical_input)
end

function candidate_preflight(x,d,parent,out)
    flux=x.flux.nominal_Wb
    write(joinpath(out,"candidate_flux_arguments.json"),canonical_json((
        argument_value_Wb=flux,argument_type=string(typeof(flux)),
        declaration_value_Wb=d.flux.nominal_Wb,declaration_type=string(typeof(d.flux.nominal_Wb)),
        parent_value_Wb=parent.physical_input.profiles_flux.toroidal_flux_wb,
        parent_type=string(typeof(parent.physical_input.profiles_flux.toroidal_flux_wb)),
        call_sites=(:legacy_identity_constructor,:manufactured_production_assembly,:retained_N1_callback_assembly)))*"\n")
    child=phase(out,"candidate_build_once") do
        S.build_spatial_candidate_v4(parent.context,parent.physical_input;physical_declaration=d)
    end
    context=child.context
    write(joinpath(out,"candidate.json"),canonical_json(context.candidate)*"\n")
    write(joinpath(out,"context.json"),canonical_json(context)*"\n")
    write(joinpath(out,"candidate_identity.json"),canonical_json((candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        declaration_hash=canonical_hash(d),input_hash=canonical_hash(x),parent_hash=child.parent_hash,
        changes=child.changes,provenance=child.provenance,subject_hash=canonical_hash(context.subject),authority=:no_publish))*"\n")
    baseline=S.spatial_multiregion_declaration_v4(flux_Wb=flux)
    loads=S.spatial_multiregion_declared_loads_v1(baseline;source_xyz_N_m3=(1.0,-2.0,3.0),normal_B_T=0.0,
        source_provenance="Constructor identity negative-control only; not solved",boundary_provenance="Closed numerical boundary")
    old=(baseline,loads,S.spatial_multiregion_bounded_step_v1(baseline),S.spatial_multiregion_bounded_step_v1(loads))
    @testset "actual manufactured candidate and canonical declaration" begin
        @test phase(()->S.validate_spatial_candidate_v4(context),out,"candidate_check_01_full_guard")
        @test phase(()->S.validate_spatial_manufactured_candidate_input_v1(context,x),out,"candidate_check_02_input_guard")
        @test phase(()->context.candidate.identity_ref==S._SMM_CANDIDATE_ID_V1,out,"candidate_check_03_identity")
        @test phase(()->context.candidate_hash!=parent.context.candidate_hash && context.context_hash!=parent.context.context_hash,
            out,"candidate_check_04_new_hashes")
        @test phase(()->S._smr_declaration(context)==d,out,"candidate_check_05_declaration")
        @test phase(()->length(unique(canonical_hash.((old...,d))))==5,out,"candidate_check_06_versions")
        @test phase(()->parent.physical_input.fourier_boundary.field_periods==1,out,"candidate_check_07_nfp")
        @test phase(()->child.provenance.authority==:no_publish && child.provenance.manufactured.desc_execution==:not_executed,
            out,"candidate_check_08_scope")
        @test_throws ArgumentError phase(()->S.execute_spatial_multiregion_v4(context,nothing,joinpath(out,"forbidden_desc")),
            out,"candidate_check_09_desc_rejection";expected_exception=true)
        @test phase(()->!ispath(joinpath(out,"forbidden_desc")),out,"candidate_check_10_no_desc_path")
        @test_throws ArgumentError phase(()->S.validate_spatial_manufactured_candidate_input_v1(parent.context,x),
            out,"candidate_check_11_foreign_parent";expected_exception=true)
        @test_throws ArgumentError phase(()->S.build_spatial_candidate_v4(parent.context,parent.physical_input;
            physical_declaration=replace_declaration(d;solver=merge(d.solver,(coarse_iterations=13,)))),
            out,"candidate_check_12_solver_policy";expected_exception=true)
    end
    samples=S.spatial_manufactured_geometry_samples_v1(x)
    assembly=S.assemble_spatial_system_v4(d,samples,samples.initial_state;flux_Wb=flux)
    original=N.fixture_v2(first(N.LEVELS))
    reference=N.S.assemble_spatial_system_v4(original.declaration,original.data,samples.initial_state;flux_Wb=flux,
        source_function=N.source_v2,boundary_function=N.traction_v2,normal_field_function=N.normal_v2)
    function raw(a)
        i,j,v=findnz(a.jacobian)
        (residual=Tuple(a.residual),row_scales=Tuple(a.row_scales),row_blocks=Tuple(a.row_blocks),
            row_supports=Tuple(Tuple(z) for z in a.row_supports),
            jacobian=(shape=size(a.jacobian),row=Tuple(i),column=Tuple(j),value=Tuple(v)))
    end
    write(joinpath(out,"production_assembly_correspondence.json"),canonical_json((
        candidate_hash=context.candidate_hash,context_hash=context.context_hash,declaration_hash=canonical_hash(d),
        state=Tuple(samples.initial_state),state_hash=canonical_hash(Tuple(samples.initial_state)),
        production=raw(assembly),retained_N1=raw(reference),
        original_N1_source_sha256=sha(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl")),
        source_sha256=sha(S._SMR_SOURCE),provider_sha256=sha(S._SMM_SOURCE_V1)))*"\n")
    @testset "actual declared source path matches retained N1" begin
        @test assembly.residual==reference.residual && assembly.jacobian==reference.jacobian
        @test assembly.row_scales==reference.row_scales && assembly.row_blocks==reference.row_blocks
        @test assembly.row_supports==reference.row_supports
        @test size(assembly.jacobian)==(289,40)
        @test_throws ArgumentError S.assemble_spatial_system_v4(d,samples,samples.initial_state;source_function=N.source_v2)
        @test_throws ArgumentError S.assemble_spatial_system_v4(d,samples,samples.initial_state;boundary_function=N.traction_v2)
        @test_throws ArgumentError S.assemble_spatial_system_v4(d,samples,samples.initial_state;normal_field_function=N.normal_v2)
        @test_throws ArgumentError S.solve_spatial_state_v4(d,samples,samples.initial_state;limits=(max_iterations=0,seconds=0.0))
    end
    context
end

function replace_result(result;kwargs...)
    body=merge(S.semantic_view(result),(;kwargs...));typeof(result)(values(body)...,canonical_hash(body))
end

function observed_rejection_v9(f,out,label,expected_type,expected_message)
    try
        phase(f,out,label;expected_exception=true)
    catch err
        # phase wrote the actual first exception before these stronger assertions.
        @test err isa expected_type
        @test sprint(showerror,err)==expected_message
        rethrow()
    end
end

function result_tests(context,result,out)
    c=only(result.cases);d=result.declaration;x=d.source.input
    # This explicit consumer pass follows the producer's internal replay.
    @testset "complete manufactured writer and attempt replay" begin
        @test result isa S.SpatialManufacturedNumericalResultV1
        @test phase(()->S.validate_spatial_manufactured_result_v1(context,result),out,"consumer_positive_full_replay")==result.result_hash
        @test result.executed && c.executed && c.case_id=="n1_q1_2" && c.nfp==1
        @test c.diagnostics.jacobian_rows==289 && c.diagnostics.jacobian_columns==40
        @test c.diagnostics.attempt_count<=12 && c.diagnostics.accepted_update_count<=12
        @test d.solver.coarse_iterations==12 && d.solver.coarse_seconds==120.0 && d.solver.residual_tolerance==1.0e-6
        @test c.diagnostics.numerical_algorithm.policy.kkt_absolute_tolerance==1.0e-10
        @test result.execution.authority==:no_publish && result.execution.desc_execution==:not_executed
        @test result.physical_validation==:unsupported
        @test all(t->t.outer_artifact!==nothing,c.diagnostics.attempts)
        @test S.validate_spatial_artifact_v4(c.artifacts.solver_primary)
        @test c.status==(c.solver_exit_code==0 ? :converged : :fail)
        @test c.solver_exit_code!=0 || c.diagnostics.scaled_max<=1.0e-6
        @test_throws ArgumentError observed_rejection_v9(()->S.validate_spatial_result_v4(context,result),out,
            "consumer_reject_DESC_type",ArgumentError,"ArgumentError: manufactured numerical result is not a DESC spatial/engineering/whole-device result")
        @test_throws ArgumentError observed_rejection_v9(()->S.execute_spatial_engineering_v4(context,result,joinpath(out,"forbidden_engineering")),out,
            "consumer_reject_engineering",ArgumentError,"ArgumentError: manufactured numerical result cannot enter spatial engineering execution")
        @test_throws ArgumentError observed_rejection_v9(()->S.assess_spatial_whole_device_v4(context,nothing,result,nothing,nothing),out,
            "consumer_reject_whole_device",ArgumentError,"ArgumentError: manufactured numerical result cannot enter whole-device assessment")
        for (index,bad_execution) in enumerate((merge(result.execution,(authority=:accepted,)),merge(result.execution,(desc_execution=:executed,)),
                merge(result.execution,(input_hash=canonical_hash((foreign=true,)),))))
            @test_throws ErrorException observed_rejection_v9(()->S.validate_spatial_manufactured_result_v1(context,replace_result(result;execution=bad_execution)),out,
                "consumer_reject_execution_$(index)",ErrorException,"manufactured result cannot acquire DESC/physical authority")
        end
        old_body=S.semantic_view(result)
        disguised=S.SpatialMultiRegionResultV4(values(old_body)...,canonical_hash(old_body))
        @test_throws ArgumentError observed_rejection_v9(()->S.validate_spatial_result_v4(context,disguised),out,
            "consumer_reject_disguised_type",ArgumentError,"ArgumentError: manufactured numerical candidate is not a DESC spatial result")
        false_peak=replace_result(c;diagnostics=merge(c.diagnostics,(scaled_max=nextfloat(c.diagnostics.scaled_max),)))
        @test_throws ErrorException observed_rejection_v9(()->S.validate_spatial_manufactured_result_v1(context,replace_result(result;cases=(false_peak,))),out,
            "consumer_reject_rehashed_peak",ErrorException,"manufactured peak residual diagnostic differs from actual residual")
        @test !ispath(joinpath(out,"forbidden_engineering"))
        @test_throws ArgumentError observed_rejection_v9(()->S.validate_spatial_manufactured_geometry_v1(context,x,
            replace_receipt(result.execution.provider_receipt;desc_execution=:executed)),out,
            "consumer_reject_provider_scope",ArgumentError,"ArgumentError: manufactured receipt cannot acquire physical/DESC authority")
    end
    # Separate public invocations must never inherit admission from the writer.
    bad_input=replace_input(x;flux=merge(x.flux,(nominal_Wb=nextfloat(x.flux.nominal_Wb),)))
    @testset "each public manufactured boundary rejects foreign input" begin
        @test_throws ArgumentError observed_rejection_v9(()->S.validate_spatial_manufactured_candidate_input_v1(context,bad_input),
            out,"public_input_foreign_x",ArgumentError,"ArgumentError: foreign manufactured input/units/model/policy")
        @test_throws ArgumentError observed_rejection_v9(()->S.materialize_spatial_manufactured_geometry_v1(context,bad_input,
            joinpath(out,"forbidden_public_provider")),out,"public_producer_foreign_x",ArgumentError,"ArgumentError: foreign manufactured input/units/model/policy")
        @test !ispath(joinpath(out,"forbidden_public_provider"))
        @test_throws ArgumentError observed_rejection_v9(()->S.validate_spatial_manufactured_geometry_v1(context,bad_input,
            result.execution.provider_receipt),out,"public_consumer_foreign_x",ArgumentError,"ArgumentError: foreign manufactured input/units/model/policy")
    end
    result
end

function endpoint_diagnostics(context,result,out)
    c=only(result.cases);d=result.declaration;x=d.source.input
    data=S.load_spatial_data_v4(d,c);samples=S.spatial_manufactured_geometry_samples_v1(x)
    reference=S.assemble_spatial_system_v4(d,data,samples.reference_state;flux_Wb=c.flux_Wb)
    reference_scaled=reference.residual./reference.row_scales
    original=N.fixture_v2(first(N.LEVELS));gl5=N.quadrature5(original.data)
    errors=N.field_errors_v2(original.declaration,gl5,collect(c.final_state);interpolant=original.data.initial_state)
    state_delta=collect(c.final_state).-samples.reference_state
    magnetic_columns=filter(i->i%4!=0,collect(eachindex(state_delta)))
    nodal=(B_RMS_T=sqrt(sum(abs2,state_delta[magnetic_columns])/length(magnetic_columns)),
        p_RMS_Pa=sqrt(sum(abs2,state_delta[4:4:end])/div(length(state_delta),4)),
        note="Difference from reference nodal interpolant is not a certified algebraic error.")
    report=(schema="spatial-manufactured-n1-single-endpoint-v1",candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        declaration_hash=canonical_hash(d),result_hash=canonical_hash(result),case_hash=canonical_hash(c),
        source_sha256=sha(S._SMR_SOURCE),provider_sha256=sha(S._SMM_SOURCE_V1),
        solver_exit_code=c.solver_exit_code,stopping_reason=c.stopping_reason,numerical_status=c.diagnostics.numerical_status,
        scaled_max=c.diagnostics.scaled_max,scaled_norm=c.diagnostics.scaled_norm,blocks=c.diagnostics.blocks,
        projected_gradient_norm=last(c.iterations).projected_gradient_norm,
        attempts=c.diagnostics.attempt_count,accepted_updates=c.diagnostics.accepted_update_count,
        reference_interpolant=(state_hash=canonical_hash(Tuple(samples.reference_state)),raw_residual=Tuple(reference.residual),
            row_scales=Tuple(reference.row_scales),scaled_max=maximum(abs,reference_scaled),blocks=S._smr_block_norms(reference)),
        nodal_reference_offset=nodal,independent_GL5_field_errors=errors,
        GL5_scope=:measured_error_quadrature_not_rigorous_bound,solved_refinement=:not_executed,
        pressure_current_topology=:not_fixed,external_closure=:terminal_deferred,desc_execution=:not_executed,
        physical_validation=:unsupported,authority=:no_publish)
    write(joinpath(out,"endpoint_diagnostics.json"),canonical_json(report)*"\n")
    report
end

function main(args)
    length(args)==2 && args[1]=="--integrated-n1" || error("expected --integrated-n1 OUTPUT; no standalone preflight run")
    out=abspath(args[2]);ispath(out) && error("preserve existing evidence");mkpath(out)
    println("MMS_INTEGRATED julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads());flush(stdout)
    x,d=phase(out,"stage1_preflight") do;stage1_tests(joinpath(out,"preflight"));end
    parent=phase(out,"actual_circular_parent") do;build_manufactured_parent(x,out);end
    context=phase(out,"actual_spatial_candidate") do;candidate_preflight(x,d,parent,out);end
    result=phase(out,"actual_provider_writer_full_solver_replay") do
        S.execute_spatial_manufactured_numerical_v1(context,joinpath(out,"production"))
    end
    phase(out,"explicit_consumer_replay_and_scope_negatives") do;result_tests(context,result,out);end
    report=phase(out,"single_endpoint_error_diagnostics") do;endpoint_diagnostics(context,result,out);end
    c=only(result.cases)
    write(joinpath(out,"integrated_complete.json"),canonical_json((schema="spatial-manufactured-integrated-test-v1",
        software_tests=:passed,candidate_hash=context.candidate_hash,context_hash=context.context_hash,result_hash=canonical_hash(result),
        actual_candidate=:executed,actual_provider=:executed,actual_writer=:executed,nonlinear_solves=1,positive_result_replays=2,
        solver_exit_code=c.solver_exit_code,stopping_reason=c.stopping_reason,numerical_status=c.diagnostics.numerical_status,
        final_scaled_max=c.diagnostics.scaled_max,endpoint_diagnostics_hash=canonical_hash(report),
        descendant_DESC_execution=:not_executed,solved_refinement=:not_executed,physical_validation=:unsupported,authority=:no_publish))*"\n")
    println("MMS_NUMERICAL_STATUS=",c.diagnostics.numerical_status," solver_exit=",c.solver_exit_code,
        " scaled_max=",c.diagnostics.scaled_max," physical_validation=unsupported");flush(stdout)
end
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    ManufacturedCandidateV1Tests.main(ARGS)
end
