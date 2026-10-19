using Test, LinearAlgebra, FusionConceptAI
println("DECLARED_LOAD_TEST_ENV julia_version=",VERSION," threads=",Threads.nthreads()," machine=",Sys.MACHINE)

const REPO=normpath(joinpath(@__DIR__,"..","..",".."))
include(joinpath(REPO,"scripts","runtime_v4_manufactured_recovery_benchmark.jl"))
const R=RuntimeV4ManufacturedRecoveryBenchmark
const S=R.SPF

module DeclaredLoadsLegacyOracle
    include(joinpath(@__DIR__,"..","..","..","src","RuntimeV4","SpatialExecutionTypesV4.jl"))
    include(joinpath(@__DIR__,"..","..","..","docs","implementation","UP2-04-CLOSURE-REPAIR-PREC",
        "agent_r1_20260922","SpatialMultiRegionV4.before.jl"))
end
const L=DeclaredLoadsLegacyOracle

function replace_declaration(d;kwargs...)
    values=merge(S.semantic_view(d),(;kwargs...))
    S.SpatialMultiRegionDeclarationV4((getproperty(values,k) for k in fieldnames(typeof(d)))...)
end
function declaration(source=(4.,-3.,2.);kwargs...)
    d=S.spatial_multiregion_declaration_v4(flux_Wb=pi)
    S.spatial_multiregion_declared_loads_v1(d;source_xyz_N_m3=source,normal_B_T=0.,
        source_provenance="Explicit numerical test load; not measured or physically validated",
        boundary_provenance="Closed torus zero normal magnetic flux numerical declaration",kwargs...)
end

@testset "versioned declared-load producer and frozen boundary" begin
    old=S.spatial_multiregion_declaration_v4(flux_Wb=pi)
    legacy=L.spatial_multiregion_declaration_v4(flux_Wb=pi)
    @test canonical_json(old)==canonical_json(legacy)
    @test canonical_hash(old)==canonical_hash(legacy)
    d=declaration()
    @test d.revision=="spatial-q1-static-mhd-declared-loads-v1"
    @test S.validate_spatial_multiregion_declaration_v4(d)
    @test canonical_hash(d)!=canonical_hash(old)
    @test canonical_hash(d)!=canonical_hash(declaration((4.,-3.,3.)))
    @test d.solver==old.solver && d.scaling==old.scaling && d.spaces==old.spaces
    @test_throws ArgumentError declaration((1.,2.))
    @test_throws ArgumentError declaration((1.,2.,NaN))
    @test_throws ArgumentError declaration(zeros(3,1))
    @test_throws ArgumentError declaration((true,0.,0.))
    @test_throws ArgumentError declaration(source_unit="Pa")
    @test_throws ArgumentError declaration(normal_field_unit="Wb")
    @test_throws ArgumentError S.spatial_multiregion_declared_loads_v1(old;
        source_xyz_N_m3=(0.,0.,0.),normal_B_T=0.,source_provenance=" ",boundary_provenance="explicit")
    @test_throws ArgumentError S.spatial_multiregion_declared_loads_v1(old;
        source_xyz_N_m3=(0.,0.,0.),normal_B_T=0.1,source_provenance="explicit",boundary_provenance="explicit")
    @test_throws ArgumentError S.validate_spatial_multiregion_declaration_v4(replace_declaration(d;
        solver=merge(d.solver,(residual_tolerance=1.e-3,))))
    @test_throws ArgumentError S.validate_spatial_multiregion_declaration_v4(replace_declaration(d;
        boundary=merge(d.boundary,(traction=:invented_external_load,))))
    @test_throws ArgumentError S.validate_spatial_multiregion_declaration_v4(replace_declaration(d;
        source=(equation="div(T)=source",value_xyz_N_m3=(0.,0.,0.),source="explicit")))
    @test_throws ArgumentError S.validate_spatial_multiregion_declaration_v4(d;flux_Wb=2pi)
end

@testset "same production assembly consumes declared loads on both grids" begin
    base=S.spatial_multiregion_declaration_v4(flux_Wb=pi)
    declared=declaration();force=collect(declared.source.value_xyz_N_m3)
    for level in (:coarse,:fine)
        bundle=R.benchmark_data((level,1,base.spaces,level==:coarse ? .5 : .25))
        data=bundle.data;x=copy(data.initial_state)
        oldmesh=L.SpatialMeshV4((getfield(data.mesh,k) for k in fieldnames(typeof(data.mesh)))...)
        olddata=merge(data,(mesh=oldmesh,));oldd=L.spatial_multiregion_declaration_v4(flux_Wb=pi)
        original=L.assemble_spatial_system_v4(oldd,olddata,x)
        zero=S.assemble_spatial_system_v4(base,data,x)
        @test zero.residual==original.residual
        @test zero.jacobian==original.jacobian
        @test zero.row_scales==original.row_scales
        actual=S.assemble_spatial_system_v4(declared,data,x)
        callback=S.assemble_spatial_system_v4(base,data,x;source_function=xyz->Tuple(force))
        @test actual.residual==callback.residual
        @test actual.jacobian==zero.jacobian
        @test actual.row_scales==zero.row_scales && actual.row_blocks==zero.row_blocks
        # Sum local basis moments: partition of unity leaves exactly -V*f.
        delta=actual.residual-zero.residual;total=zeros(3)
        for (c,ids) in enumerate(data.mesh.cell_nodes),a in eachindex(ids)
            row=data.mesh.cell_row_start[c]+4*(a-1)
            total.+=delta[row:row+2]
            @test delta[row+3]==0.
        end
        volume=sum(s.weight for s in data.volume)
        @test total≈-volume.*force rtol=1.e-9 atol=1.e-7
        @test all(iszero,delta[findall(b->b in (:traction_N,:normal_B_Wb,:total_flux_Wb),zero.row_blocks)])
        # A nonzero constant Bn is deliberately incompatible and cannot be a
        # production candidate.  The kernel must nevertheless not erase it.
        invalid=replace_declaration(declared;boundary=merge(declared.boundary,(normal_B_T=.125,)))
        @test_throws ArgumentError S.validate_spatial_multiregion_declaration_v4(invalid)
        bactual=S.assemble_spatial_system_v4(invalid,data,x)
        bcallback=S.assemble_spatial_system_v4(declared,data,x;normal_field_function=(xyz,n)->.125)
        @test bactual.residual==bcallback.residual
        @test bactual.jacobian==actual.jacobian
        bn_delta=bactual.residual-actual.residual
        area=sum(s.weight for s in data.face_quadrature if data.mesh.faces[s.entity_id].role==:exterior)
        @test sum(bn_delta[findall(==(:divB_Wb),actual.row_blocks)])≈.125*area rtol=1.e-11 atol=1.e-9
        @test sum(bn_delta[findall(==(:normal_B_Wb),actual.row_blocks)])≈-.125*area rtol=1.e-11 atol=1.e-9
        @test_throws ArgumentError S.assemble_spatial_system_v4(declared,data,x;source_function=xyz->(1.,2.))
        @test_throws ArgumentError S.assemble_spatial_system_v4(declared,data,x;source_function=xyz->(Inf,0.,0.))
        @test_throws ArgumentError S.assemble_spatial_system_v4(declared,data,x;normal_field_function=(xyz,n)->NaN)
        text=S._smr_current_texts(data,x;declaration=declared)
        @test text.current_closure.outer_Bout==:unknown
        @test text.current_closure.outer_K==:unknown
        @test text.diagnostics.declared_loads.external_closure_status==:terminal_deferred
        @test text.diagnostics.declared_loads.compatibility_certified==false
        @test !hasproperty(S._smr_current_texts(data,x;declaration=base).diagnostics,:declared_loads)
        if level==:coarse
            solved=S.solve_spatial_state_v4(declared,data,x;limits=(max_iterations=0,seconds=0.))
            @test solved.final_assembly.residual==actual.residual
            @test solved.solver_exit_code==4
            @test solved.final_state==Tuple(x)
            @test solved.attempt_count==0
        end
    end
end
