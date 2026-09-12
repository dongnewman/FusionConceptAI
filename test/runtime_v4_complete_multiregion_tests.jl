using Test
using FusionConceptAI
using LinearAlgebra
module CMRFocused
    include(joinpath(@__DIR__,"..","src","RuntimeV4","CompleteMultiRegionV4.jl"))
end

@testset "complete reduced multiregion numerical core" begin
    d=CMRFocused.multiregion_declaration_v4()
    @test d.test_space.total_state_dofs==4
    @test d.test_space.total_rows==36
    @test d.interfaces[1].trace==:exact_same_surface
    # Manufactured algebraic control only: known positive state, nonlinear a^2,
    # all columns observable, requiring a genuine state update from (1,1,1,1).
    C=[1.0 0 0 0;0 2 0 0;0 0 3 0;0 0 0 4;1 1 1 1]
    exact=[1.2,0.9,0.8,1.1];u=[exact[1]^2,exact[2],exact[3]^2,exact[4]]
    dm=-C*u;dp=zeros(5);scales=ones(5)
    result=CMRFocused.solve_multiregion_state_v4(C,dm,dp,scales;tolerance=1e-10)
    @test result.solver_exit_code==0
    @test length(result.iterations)>1
    @test collect(result.final_state)≈exact atol=1e-8
    J=CMRFocused._cmr_matrix(result.jacobian)
    for j in 1:4
        h=1e-5;xp=copy(exact);xm=copy(exact);xp[j]+=h;xm[j]-=h
        finite=(CMRFocused._cmr_residual(C,dm,dp,xp,1.0)-CMRFocused._cmr_residual(C,dm,dp,xm,1.0))/(2h)
        @test J[:,j]≈finite rtol=1e-8 atol=1e-8
    end
    # A contradictory independent equation cannot be hidden by Newton convergence.
    badC=vcat(C,zeros(1,4));bad=CMRFocused.solve_multiregion_state_v4(badC,vcat(dm,1.0),zeros(6),ones(6))
    @test bad.solver_exit_code!=0
    @test bad.status==:fail
    @test abs(last(bad.residual))==1.0
    @test_throws ArgumentError CMRFocused.solve_multiregion_state_v4(C,dm,dp,scales;pressure_multiplier=1.11)

    # A volume sample's constant test has exactly zero gradient; the affine
    # test produces the Cartesian tensor column, which catches sign/index bugs.
    sample=(kind=:volume,region=1,rho=0.25,theta=0.0,zeta=0.0,
        position_xyz_m=(1.0,2.0,3.0),B_xyz_T=(2.0,0.0,0.0),p_Pa=3.0,
        J_xyz_A_m2=(0.0,0.0,0.0),gradp_xyz_N_m3=(0.0,0.0,0.0),normal_xyz=(0.0,0.0,0.0),measure=2.0)
    a=CMRFocused.assemble_multiregion_coefficients_v4([sample])
    @test a.coefficient_matrix[1:3,:]==zeros(3,4)
    @test a.coefficient_matrix[4,1]≈-4/CMRFocused._CMR_MU0
    @test a.coefficient_matrix[4,2]==6.0
    @test a.coefficient_matrix[8,1]≈4/CMRFocused._CMR_MU0
    # Interior orientation is opposite for the two region equations, but the
    # independently assembled jump rows retain the discontinuous stress.
    face=merge(sample,(kind=:interface,normal_xyz=(1.0,0.0,0.0),measure=1.0))
    fa=CMRFocused.assemble_multiregion_coefficients_v4([face])
    @test fa.coefficient_matrix[1,:]==-fa.coefficient_matrix[13,:]
    @test fa.coefficient_matrix[25,1]==-fa.coefficient_matrix[25,3]
    @test fa.coefficient_matrix[25,1]!=0
    # Adversarial controls exercise replay checks directly; no caller can
    # change row normalization/ownership/initial state and reseal the result.
    replayable=(coefficient_matrix=CMRFocused._cmr_rows(a.coefficient_matrix),constant_magnetic=Tuple(a.constant_magnetic),
        constant_pressure=Tuple(a.constant_pressure),row_scales=Tuple(a.row_scales),row_labels=a.row_labels,
        initial_state=Tuple(s.initial for s in d.states))
    @test CMRFocused._cmr_assert_assembly_v4(replayable,a,d)
    @test_throws ArgumentError CMRFocused._cmr_assert_assembly_v4(merge(replayable,(row_scales=Tuple(2 .*a.row_scales),)),a,d)
    @test_throws ArgumentError CMRFocused._cmr_assert_assembly_v4(merge(replayable,(row_labels=reverse(a.row_labels),)),a,d)
    @test_throws ArgumentError CMRFocused._cmr_assert_assembly_v4(merge(replayable,(initial_state=(1.1,1.0,1.0,1.0),)),a,d)
    diag=(strong_force_relative_peak=(0.0,0.0),pointwise_interface_traction_jump_relative=0.0,pointwise_exterior_traction_mismatch_relative=0.0)
    hash=FusionConceptAI.canonical_hash("test-only-h5")
    eng=(outer_B_scale=1.0,B_includes_final_outer_scale=true,upstream_valid=false,reduced_model_diagnostic_valid=true,
        upstream_status=:upstream_convergence_unattested,reference_hdf5_path="manufactured-test-only.h5",reference_hdf5_sha256=hash,
        pressure_semantics=:plasma_pressure_not_material_stress)
    @test CMRFocused._cmr_assert_engineering_metadata_v4(eng,diag,(1.,1.,1.,1.),0,"manufactured-test-only.h5",hash)
    @test_throws ArgumentError CMRFocused._cmr_assert_engineering_metadata_v4(merge(eng,(upstream_valid=true,)),diag,(1.,1.,1.,1.),0,"manufactured-test-only.h5",hash)
    @test_throws ArgumentError CMRFocused._cmr_assert_engineering_metadata_v4(merge(eng,(outer_B_scale=1.1,)),diag,(1.,1.,1.,1.),0,"manufactured-test-only.h5",hash)
    @test_throws ArgumentError CMRFocused._cmr_assert_engineering_metadata_v4(merge(eng,(upstream_status=:pass,)),diag,(1.,1.,1.,1.),0,"manufactured-test-only.h5",hash)
    @test_throws ArgumentError CMRFocused._cmr_assert_engineering_metadata_v4(merge(eng,(reduced_model_diagnostic_valid=false,)),diag,(1.,1.,1.,1.),0,"manufactured-test-only.h5",hash)
end
