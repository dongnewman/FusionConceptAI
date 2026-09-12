using Test
using FusionConceptAI

module MEGT
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","MagneticEngineeringV4.jl"))
end

@testset "candidate magnetic pickup declaration and deterministic scope" begin
    d=MEGT.engineering_declaration_v4()
    @test canonical_hash(d)==canonical_hash(MEGT.engineering_declaration_v4())
    @test all(p->!isempty(p.source) && !isempty(p.applicability),d.parameters)
    @test all(p->occursin("not measured",p.source),d.parameters)
    @test d.placement.rho==1.0
    @test d.placement.exterior_extension===:unverified_boundary_continuation
    @test length(d.scenarios)==2
    @test_throws ArgumentError MEGT.magnetic_pickup_response_v4(NaN)
    @test_throws ArgumentError MEGT.magnetic_pickup_response_v4(2.;fault=:undeclared)
    @test_throws ArgumentError MEGT.magnetic_pickup_response_v4(2.;overrides=(load_resistance_ohm=5.,))
    @test_throws ArgumentError MEGT.magnetic_pickup_response_v4(2.;overrides=(invented=1.,))
    @test_throws ArgumentError MEGT.magnetic_pickup_response_v4(2.;dt_override=1e-3)
end

@testset "independent closed-form RL benchmark: synthetic software verification only" begin
    # The number 2 T is a manufactured unit-test input, never a production receipt.
    run=MEGT.magnetic_pickup_response_v4(2.)
    p=run.parameters; a=run.derived.N_area_m2
    rt=run.derived.winding_resistance_ohm+p.load_resistance_ohm
    tau=p.series_inductance_H/rt
    emf=-a*2*p.ramp_fraction/p.ramp_duration_s
    peak=abs(emf/rt*(1-exp(-p.ramp_duration_s/tau)))
    final=emf/rt*(1-exp(-p.ramp_duration_s/tau))*exp(-(p.duration_s-p.ramp_duration_s)/tau)
    delta=-p.load_resistance_ohm/a*(emf*p.ramp_duration_s-p.series_inductance_H*final)/rt
    @test run.executed && run.solver_exit_code==0
    @test run.metrics.trip_time_s===nothing
    @test run.metrics.measurement_valid
    @test run.metrics.current_peak_A≈peak rtol=1e-6
    @test run.metrics.reconstructed_delta_B_T≈delta rtol=1e-8
    @test run.metrics.maximum_circuit_residual_V<1e-12
    @test abs(run.metrics.discrete_energy_identity_error_J)<1e-17
    @test run.metrics.backward_euler_numerical_dissipation_J>0
    @test run.metrics.integrated_energy_balance_defect_J≈run.metrics.backward_euler_numerical_dissipation_J atol=1e-17
    refined=MEGT.magnetic_pickup_response_v4(2.;dt_override=p.time_step_s/2)
    @test abs(refined.metrics.final_current_A-final)<abs(run.metrics.final_current_A-final)
    @test refined.metrics.backward_euler_numerical_dissipation_J<run.metrics.backward_euler_numerical_dissipation_J
    zero=MEGT.magnetic_pickup_response_v4(0.)
    @test zero.metrics.current_peak_A==zero.metrics.joule_energy_J==0
    @test zero.metrics.reconstructed_delta_B_T==0
    reverse=MEGT.magnetic_pickup_response_v4(-2.)
    @test reverse.metrics.current_peak_A==run.metrics.current_peak_A
    @test reverse.metrics.reconstructed_delta_B_T==-run.metrics.reconstructed_delta_B_T
    @test reverse.metrics.joule_energy_J==run.metrics.joule_energy_J
end

@testset "executed short-circuit and latching protection equations" begin
    r=MEGT.magnetic_pickup_response_v4(2.;fault=:load_short)
    @test r.executed && r.solver_exit_code==0
    @test r.metrics.protection_latched
    @test !r.metrics.measurement_valid
    @test r.metrics.trip_time_s>r.parameters.short_time_s
    @test r.metrics.current_peak_A>=r.parameters.trip_current_A
    @test any(t->t.branch_resistance_ohm==r.parameters.short_resistance_ohm,r.trajectory)
    @test any(t->t.branch_resistance_ohm==r.parameters.dump_resistance_ohm,r.trajectory)
    @test abs(r.metrics.final_current_A)<r.metrics.current_peak_A*1e-4
    @test abs(r.metrics.discrete_energy_identity_error_J)<1e-17
    @test r.metrics.maximum_circuit_residual_V<1e-12
    @test all(t->t.relay_latched,filter(t->t.t_s>=r.metrics.trip_time_s,r.trajectory))
    # Exposes detection discretization instead of claiming continuous event timing.
    refined=MEGT.magnetic_pickup_response_v4(2.;fault=:load_short,dt_override=5e-6)
    @test abs(refined.metrics.trip_time_s-r.metrics.trip_time_s)<=2r.parameters.time_step_s
end

@testset "exact declared engineering scenarios cannot be replaced or duplicated" begin
    declaration=MEGT.engineering_declaration_v4()
    nominal=MEGT.magnetic_pickup_response_v4(2.;fault=:none)
    shorted=MEGT.magnetic_pickup_response_v4(2.;fault=:load_short)
    @test MEGT._meg_assert_scenario_sequence_v4((nominal,shorted),declaration)
    @test_throws ArgumentError MEGT._meg_assert_scenario_sequence_v4((nominal,nominal),declaration)
    @test_throws ArgumentError MEGT._meg_assert_scenario_sequence_v4((shorted,nominal),declaration)
    @test_throws ArgumentError MEGT._meg_assert_scenario_sequence_v4((nominal,),declaration)
    @test_throws ArgumentError MEGT._meg_assert_scenario_sequence_v4((nominal,shorted,shorted),declaration)
end

println("MAGNETIC_ENGINEERING_FOCUSED_EXIT_CODE=0")
