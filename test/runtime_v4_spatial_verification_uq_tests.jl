using Test,FusionConceptAI,LinearAlgebra,SparseArrays
module SVQT
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialExecutionTypesV4.jl"))
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialPickupEngineeringV4.jl"))
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialVerificationUQV4.jl"))
end

@testset "Every structural state column and physical block is verified" begin
    x=[2.,.3,.1,500.,.2,.4,.5,700.]
    f(x)=[x[1]^2+x[4],x[2]*x[5],x[3]+2x[6],x[7]-x[8],x[1]+x[5]]
    J=[2x[1] 0 0 1 0 0 0 0;0 x[5] 0 0 x[2] 0 0 0;
       0 0 1 0 0 2 0 0;0 0 0 0 0 0 1 -1;1 0 0 0 1 0 0 0]
    supports=[[1,4],[2,5],[3,6],[7,8],[1,5]]
    scales=[1e6,5.,5.,1e3,1.];blocks=[:momentum_N,:divB_Wb,:normal_B_Wb,:traction_N,:total_flux_Wb]
    flux=Dict(5=>[1.,0.,0.,0.,1.,0.,0.,0.])
    good=SVQT.verify_spatial_jacobian_v4(f,x,J,scales,blocks,supports;independent_linear_rows=flux)
    @test good.status===:pass
    @test good.columns==8&&good.rows==5&&good.all_columns_covered
    @test good.independent_linear_rows==(5,)
    @test length(good.column_records)==8
    wrong=copy(J);wrong[1,4]=0.
    failed=SVQT.verify_spatial_jacobian_v4(f,x,wrong,scales,blocks,supports;independent_linear_rows=flux)
    @test failed.status===:fail
    @test failed.column_records[4].status===:fail
    wrongflux=Dict(5=>zeros(8))
    @test SVQT.verify_spatial_jacobian_v4(f,x,J,scales,blocks,supports;independent_linear_rows=wrongflux).status===:fail
    @test_throws ArgumentError SVQT.verify_spatial_jacobian_v4(f,x,J[:,1:7],scales,blocks,supports)
    @test_throws ArgumentError SVQT.spatial_jacobian_coloring_v4([[9]],8)
    incomplete=copy(supports);incomplete[1]=[1]
    @test_throws ArgumentError SVQT.verify_spatial_jacobian_v4(f,x,J,scales,blocks,incomplete)
    colors=SVQT.spatial_jacobian_coloring_v4(supports,8)
    @test all(length(unique(colors.colors[s]))==length(s) for s in supports)
end

@testset "Nonzero-source analytic MMS is specified independently" begin
    d=SVQT.spatial_verification_declaration_v4();m=d.manufactured_solution;mu=1.25663706127e-6
    x=[1.2,-.7,.3];f=SVQT._svq_analytic_mms(x,mu,m)
    @test f.B≈[.186,-.1045,.312]
    @test f.p≈507.5
    @test f.J≈[.015,-.01,-.02]./mu
    # Independently differentiate the explicit Cartesian stress numerically.
    h=1e-5;divergence=zeros(3)
    for j in 1:3
        plus=copy(x);minus=copy(x);plus[j]+=h;minus[j]-=h
        divergence.+=(SVQT._svq_analytic_mms(plus,mu,m).stress[:,j]-SVQT._svq_analytic_mms(minus,mu,m).stress[:,j])./(2h)
    end
    @test divergence≈f.source rtol=1e-8
    @test norm(f.source)>0
    @test m.physical_validation_credit==0
    @test d.validation.status===:unsupported
    rows=[["1","momentum_N","1.0","2.0","3.0","4.0"],
          ["2","divB_Wb","5.0","6.0","7.0","8.0"]]
    parsed=SVQT._svq_mms_columns(rows,[:momentum_N,:divB_Wb])
    @test parsed.interpolated_weak==[1.,5.] && parsed.analytic_strong==[4.,8.]
    @test_throws ErrorException SVQT._svq_mms_columns([rows[1][1:5],rows[2]],[:momentum_N,:divB_Wb])
    nonfinite=deepcopy(rows);nonfinite[2][6]="NaN"
    @test_throws ErrorException SVQT._svq_mms_columns(nonfinite,[:momentum_N,:divB_Wb])
    sourcekey="manufactured.analytic.source_weighted_l2_N_per_m3_sqrt_m3"
    @test SVQT._svq_mms_source_status(Dict(sourcekey=>2.)).nonzero
    @test !SVQT._svq_mms_source_status(Dict(sourcekey=>0.)).nonzero
    @test_throws ErrorException SVQT._svq_mms_source_status(Dict(sourcekey=>NaN))
end

@testset "Independent high precision circuit checks real response equations" begin
    d=SVQT.spatial_engineering_declaration_v4()
    for (flux,fault) in ((1e-4,:none),(1e-2,:load_short),(0.,:none))
        # Manufactured flux only tests circuit verification; integrated runs
        # always pass actual current-derived flux via bound engineering cases.
        r=SVQT.spatial_pickup_exact_response_v4(flux;declaration=d,fault=fault)
        check=SVQT.verify_spatial_circuit_v4(r,d)
        @test check.status===:pass
        @test check.controls_agree
        @test check.trajectory_count==length(r.trajectory)
        @test check.independent_metrics.induced_emf_peak_V≈r.metrics.induced_emf_peak_V
        @test hasproperty(check.independent_metrics,:energy_identity_error_J)
        @test hasproperty(check.independent_metrics,:maximum_segment_energy_identity_error_J)
        bad=merge(r,(metrics=merge(r.metrics,(joule_energy_J=r.metrics.joule_energy_J+1.,)),))
        @test SVQT.verify_spatial_circuit_v4(bad,d).status===:fail
        bademf=merge(r,(metrics=merge(r.metrics,(induced_emf_peak_V=r.metrics.induced_emf_peak_V+1.,)),))
        @test SVQT.verify_spatial_circuit_v4(bademf,d).status===:fail
        badidentity=merge(r,(metrics=merge(r.metrics,(energy_identity_error_J=r.metrics.energy_identity_error_J+1.,)),))
        @test SVQT.verify_spatial_circuit_v4(badidentity,d).status===:fail
        badsegment=merge(r,(metrics=merge(r.metrics,(maximum_segment_energy_identity_error_J=r.metrics.maximum_segment_energy_identity_error_J+1.,)),))
        @test SVQT.verify_spatial_circuit_v4(badsegment,d).status===:fail
    end
end

@testset "Rehashed oracle artifacts cannot be relabeled to another state" begin
    mktempdir() do dir
        expected=(fixture=:manufactured_binding_test_only,state=(1.,2.,3.,400.),geometry_hash="a")
        path=joinpath(dir,"oracle_input.json")
        write(path,FusionConceptAI.canonical_json(expected)*"\n")
        artifact=SVQT.SpatialArtifactV4(path,SVQT._svq_sha(path),"test-only-request",1)
        @test SVQT._svq_validate_oracle_request(artifact,expected)
        other=merge(expected,(state=(1.,2.,3.,900.),))
        write(path,FusionConceptAI.canonical_json(other)*"\n")
        rehashed=SVQT.SpatialArtifactV4(path,SVQT._svq_sha(path),"test-only-request",1)
        @test_throws ArgumentError SVQT._svq_validate_oracle_request(rehashed,expected)
        @test_throws ArgumentError SVQT._svq_validate_oracle_request(artifact,expected)
    end
end
