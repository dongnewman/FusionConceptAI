using FusionConceptAI,Test,SHA
module SPET
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialExecutionTypesV4.jl"))
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialPickupEngineeringV4.jl"))
end

@testset "spatial pickup ownership and analytic clearance" begin
    d=SPET.spatial_engineering_declaration_v4()
    @test canonical_hash(d)==canonical_hash(SPET.spatial_engineering_declaration_v4())
    @test d.case_ids==("nominal_coarse","nominal_fine","flux_low_coarse","flux_high_coarse")
    @test d.static_model.induced_emf_V==0.
    @test !d.static_model.total_external_field
    g=SPET._spe_geometry_v4((R_upper_m=3.,provenance=(method=:unit_test_bound,)),((2.,0.,0.),),d)
    @test g.analytic_clearance_lower_bound_m≈.045
    @test g.center_xyz_m==(3.05,0.,0.)
    @test g.declared_map_clearance_proved
    @test g.actual_sample_enclosure_verified
    @test g.continuous_solved_interior_enclosure===:unsupported
    beyond=SPET._spe_geometry_v4((R_upper_m=3.,),((3.1,0.,0.),),d)
    @test !beyond.actual_sample_enclosure_verified
    @test beyond.continuous_solved_interior_enclosure===:unsupported
    @test beyond.center_xyz_m==g.center_xyz_m
    @test_throws ArgumentError SPET._spe_geometry_v4((R_upper_m=3.,),((3.05,0.,0.),),d)
    unsupported=SPET._spe_geometry_v4((R_upper_m=3.,),((2.,0.,0.),),d;
        provider_enclosure=(supported=false,source=:manufactured_test_only))
    @test unsupported.continuous_solved_interior_enclosure===:unsupported
    @test_throws ArgumentError SPET._spe_geometry_v4((R_upper_m=3.,),((2.,0.,0.),),d;
        provider_enclosure=(supported=true,R_upper_m=2.9))
    mktempdir() do dir
        path=joinpath(dir,"manufactured_enclosure.txt");write(path,"unit-test analytic bound record\n")
        artifact=SPET.SpatialArtifactV4(path,SPET._spe_sha(path),"unit-test-bound",1)
        enclosure=(supported=true,R_upper_m=2.9,method=:unit_test_only,artifact=artifact)
        proven=SPET._spe_geometry_v4((R_upper_m=3.,),((2.,0.,0.),),d;provider_enclosure=enclosure)
        @test proven.continuous_solved_interior_enclosure===:proved
        conservative=merge(enclosure,(R_upper_m=3.2,))
        unproved=SPET._spe_geometry_v4((R_upper_m=3.,),((2.,0.,0.),),d;provider_enclosure=conservative)
        @test unproved.continuous_solved_interior_enclosure===:unsupported
        @test unproved.center_xyz_m==proven.center_xyz_m
        write(path,"tampered\n")
        @test_throws ArgumentError SPET._spe_geometry_v4((R_upper_m=3.,),((2.,0.,0.),),d;provider_enclosure=enclosure)
    end
end

@testset "Biot Savart analytic loop and independent finite-aperture reciprocity" begin
    # Manufactured filament quadrature verifies the kernel only. Production
    # accepts current-state artifacts through the full physics validator.
    n=128;mu0=SPET._SPE_MU0
    loop=Tuple(begin
        angle=2pi*(j-.5)/n
        SPET.SpatialCurrentQuadratureV4((cos(angle),sin(angle),0.),
            (-sin(angle)*2pi/n,cos(angle)*2pi/n,0.),:unit_test_filament)
    end for j in 1:n)
    B=SPET.spatial_plasma_field_v4((0.,0.,2.),loop)
    @test abs(B[1])+abs(B[2])<1e-20
    @test B[3]≈mu0/(2*5.0^1.5) rtol=1e-12
    transfer=SPET.spatial_pickup_transfer_v4(loop,(0.,0.,2.))
    @test transfer.status===:pass
    @test transfer.biot_savart_flux_Wb>0
    @test transfer.absolute_difference_Wb<1e-18
    @test transfer.disk_area_m2≈pi*.005^2 rtol=1e-13
    empty=SPET.spatial_pickup_transfer_v4((),(1.,0.,0.))
    @test empty.biot_savart_flux_Wb==empty.reciprocity_flux_Wb==0.
    @test_throws ArgumentError SPET.spatial_plasma_field_v4(first(loop).position_xyz_m,loop)
end

@testset "actual-current CSV schema, J/K mapping and byte protection" begin
    mktempdir() do dir
        volume=joinpath(dir,"volume.csv");sheet=joinpath(dir,"sheet.csv");outer=joinpath(dir,"outer.csv")
        write(volume,SPET.SPATIAL_VOLUME_HEADER_V4*"\n1,test,0,0,0,1,0,0,0,0,1,0,1,0,0,0,0\n")
        # Manufactured jump gives K=(0,-1,0); it cancels the unit volume source
        # here, exercising the independently weighted sheet contribution.
        write(sheet,SPET.SPATIAL_INTERFACE_HEADER_V4*"\n1,a,b,0,0,0,1,1,0,0,0,0,0,0,0,$(SPET._SPE_MU0),0,-1,0,0,0\n")
        write(outer,SPET.SPATIAL_EXTERIOR_HEADER_V4*"\n1,1,0,0,1,1,0,0,0,0,0,0,0,0,1\n")
        artifact(path)=SPET.SpatialArtifactV4(path,SPET._spe_sha(path),"unit-test-csv",1)
        h=canonical_hash((fixture=:manufactured_software_only,))
        input=SPET.SpatialCurrentInputV4(h,h,"nominal_coarse",h,h,
            artifact(volume),artifact(sheet),artifact(outer),(scope=:manufactured,),:fail,3,false,"unit test only")
        parsed=SPET.spatial_current_sources_v4(input)
        @test length(parsed.sources)==2
        @test parsed.sources[1].weighted_current_Am==(0.,1.,0.)
        @test parsed.sources[2].weighted_current_Am==(0.,-1.,0.)
        @test SPET.spatial_plasma_field_v4((1.,0.,0.),parsed.sources)==(0.,0.,0.)
        @test !parsed.diagnostics.source_closure_certified
        @test parsed.diagnostics.outer_sheet_current===:unknown
        conditional=(nominal=SPET.spatial_pickup_exact_response_v4(0.),
            readout_short=SPET.spatial_pickup_exact_response_v4(0.;fault=:load_short))
        transfer=(solver_exit_code=0,status=:pass)
        function case_result(identity_valid,physical_valid,legacy_valid,transfer_exit,circuit_exit,combined_exit)
            body=(candidate_hash=h,context_hash=h,case_id="nominal_coarse",state_hash=h,
                input_hash=canonical_hash(input),source_input=input,executed=true,
                transfer_exit_code=transfer_exit,circuit_exit_code=circuit_exit,solver_exit_code=combined_exit,
                status=:fail,upstream_status=:fail,input_identity_valid=identity_valid,
                physical_upstream_valid=physical_valid,upstream_valid=legacy_valid,
                applicability_status=:unsupported,geometry=(scope=:unit_test,),
                static=(induced_emf_V=0.0,total_external_field=false),transfer=transfer,
                conditional=conditional,current_closure=parsed.diagnostics,artifacts=())
            SPET.SpatialPickupCaseResultV4(values(body)...,canonical_hash(body))
        end
        valid=case_result(true,false,false,0,0,0)
        @test canonical_hash(valid)==valid.case_hash
        @test valid.input_identity_valid
        @test !valid.physical_upstream_valid && valid.upstream_valid==valid.physical_upstream_valid
        @test valid.transfer_exit_code==valid.circuit_exit_code==valid.solver_exit_code==0
        @test_throws ArgumentError canonical_hash(case_result(false,false,false,0,0,0))
        @test_throws ArgumentError canonical_hash(case_result(true,true,true,0,0,0))
        @test_throws ArgumentError canonical_hash(case_result(true,false,false,1,0,1))
        @test_throws ArgumentError canonical_hash(case_result(true,false,false,0,0,1))
        write(volume,read(volume,String)*"tampered\n")
        @test_throws ArgumentError SPET.spatial_current_sources_v4(input)
    end
end

@testset "exact RL flow independently obeys continuous energy identity" begin
    flow=SPET.spatial_exact_rl_segment_v4(0.,1.,2.,4.,1.)
    @test flow.current_A≈.5*(1-exp(-.5)) rtol=1e-14
    @test flow.integral_i_A_s≈.5*(1-2*(1-exp(-.5))) rtol=1e-14
    @test abs(flow.energy_identity_error_J)<1e-15
    tiny=SPET.spatial_exact_rl_segment_v4(0.,1.,1.,1.,1e-6)
    @test tiny.integral_i2_A2_s>0
    @test tiny.integral_i2_A2_s≈1e-18/3 rtol=1e-6
    @test_throws ArgumentError SPET.spatial_exact_rl_segment_v4(0.,1.,0.,1.,1.)
    @test_throws ArgumentError SPET.spatial_exact_rl_segment_v4(0.,NaN,1.,1.,1.)
end

@testset "fixed-cadence protection and exact switch left/right limits" begin
    flux=10pi*.005^2 # Manufactured 1-T-equivalent software fixture only.
    nominal=SPET.spatial_pickup_exact_response_v4(flux)
    shorted=SPET.spatial_pickup_exact_response_v4(flux;fault=:load_short)
    zero=SPET.spatial_pickup_exact_response_v4(0.)
    @test nominal.solver_exit_code==shorted.solver_exit_code==0
    @test !nominal.metrics.protection_latched
    @test shorted.metrics.protection_latched
    @test shorted.metrics.continuous_threshold_crossing_s<=shorted.metrics.trip_time_s
    @test shorted.metrics.trip_time_s-shorted.metrics.continuous_threshold_crossing_s<=1e-5
    @test shorted.metrics.detection_cadence_s==1e-5
    @test !shorted.metrics.local_readout_valid
    @test shorted.trajectory_semantics.sample_phase===:pre_commutation_right_limit
    @test shorted.event_semantics.phase===:instantaneous_commutation_left_right_limits
    @test first(shorted.trajectory).sample_phase===:initial_condition
    @test all(r->r.sample_phase===:pre_commutation_right_limit,shorted.trajectory[2:end])
    pending=only(r for r in shorted.trajectory if r.commutation_pending)
    @test pending.relay_latched && pending.readout_connected
    dump=only(e for e in shorted.events if e.kind===:dump_commutation)
    @test dump.time_s==pending.time_s
    @test dump.event_phase===:instantaneous_commutation_left_right_limits
    @test dump.current_left_A==dump.current_right_A
    @test dump.readout_connected_left && !dump.readout_connected_right
    @test dump.branch_resistance_left_ohm!=dump.branch_resistance_right_ohm
    @test shorted.metrics.branch_voltage_peak_V>=abs(dump.branch_voltage_right_V)
    for r in (nominal,shorted)
        @test abs(r.metrics.energy_identity_error_J)<1e-11*r.metrics.input_energy_J
        @test r.metrics.numerical_dissipation_added_J==0
    end
    @test zero.metrics.current_peak_A==zero.metrics.joule_energy_J==zero.metrics.induced_emf_peak_V==0
    reverse=SPET.spatial_pickup_exact_response_v4(-flux;fault=:load_short)
    @test reverse.metrics.trip_time_s==shorted.metrics.trip_time_s
    @test reverse.metrics.current_peak_A==shorted.metrics.current_peak_A
    @test reverse.metrics.joule_energy_J==shorted.metrics.joule_energy_J
    @test_throws ArgumentError SPET.spatial_pickup_exact_response_v4(flux;fault=:manufactured_undeclared)
end

println("SPATIAL_PICKUP_ENGINEERING_FOCUSED_EXIT_CODE=0")
