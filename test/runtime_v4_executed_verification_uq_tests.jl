using Test
using FusionConceptAI
using LinearAlgebra

module ExecutedVerificationUnitRuntime
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","ExecutedVerificationUQV4.jl"))
end
const EVU = ExecutedVerificationUnitRuntime

@testset "Full-state derivative verification exposes wrong unsampled columns" begin
    residual(x)=[x[1]^2+x[2],x[2]*x[3],sin(x[4]),x[1]-3x[4]]
    x=[1.1,0.7,2.0,0.4]
    J=[2x[1] 1.0 0.0 0.0;0.0 x[3] x[2] 0.0;0.0 0.0 0.0 cos(x[4]);1.0 0.0 0.0 -3.0]
    result=EVU.verification_full_jacobian_v4(residual,x,J)
    @test result.status===:pass
    @test result.column_count==4
    wrong=copy(J); wrong[3,4]=0.0
    @test EVU.verification_full_jacobian_v4(residual,x,wrong).status===:fail
    @test_throws ArgumentError EVU.verification_full_jacobian_v4(residual,x,J[:,1:3])
end

@testset "Irreducible moment residual differs from solver suboptimality" begin
    C=[Matrix{Float64}(I,4,4); zeros(1,4)]
    d=[-1.0,-2.0,-4.0,-3.0,5.0]
    optimum=EVU.verification_residual_floor_v4(C,d,ones(5),[1.0,2.0,2.0,3.0])
    @test optimum.unconstrained_scaled_residual_floor≈5.0
    @test optimum.actual_scaled_residual≈5.0
    @test optimum.squared_objective_excess≈0.0 atol=1e-12
    off=EVU.verification_residual_floor_v4(C,d,ones(5),ones(4))
    @test off.squared_objective_excess>0
    @test optimum.rank==4
end

@testset "Independent analytic RL solution has correct limiting behavior" begin
    names=(:loop_radius_m,:turns,:wire_radius_m,:resistivity_ohm_m,
        :load_resistance_ohm,:series_inductance_H,:ramp_duration_s,:ramp_fraction)
    values=(.005,10.0,.0001,1.72e-8,10.0,.001,.002,.1)
    declaration=(parameters=Tuple((name=n,nominal=v) for (n,v) in zip(names,values)),)
    initial=EVU.verification_rl_exact_v4(2.0,declaration,0.0)
    @test initial.current_A==0
    @test initial.reconstructed_delta_B_T==0
    endramp=EVU.verification_rl_exact_v4(2.0,declaration,.002)
    @test endramp.current_A<0
    @test endramp.reconstructed_delta_B_T>0
    final=EVU.verification_rl_exact_v4(2.0,declaration,1.0)
    @test abs(final.current_A)<1e-100
    @test final.reconstructed_delta_B_T≈.2*10/(10+final.wire_resistance_ohm) rtol=1e-12
    @test EVU.validation_declaration_v4().physical_validation.status===:unsupported
    @test EVU.validation_declaration_v4().propagation.distribution===:none
end

@testset "Independent raw tensor contraction and exact-trace enforcement" begin
    volume=(kind=:volume,owner=1,position=(0.0,0.0,0.0),B=(0.0,0.0,0.0),pressure=2.0,
        J=(0.0,0.0,0.0),gradp=(0.0,0.0,0.0),normal=(0.0,0.0,0.0),weight=1.0)
    result=EVU.verification_raw_weak_residual_v4([volume],ones(4))
    expected=zeros(36); expected[[4,8,12]].=2.0
    @test result.residual==expected
    @test result.explicit_zero_body_source==zeros(24)
    interface=merge(volume,(kind=:interface,position=(1.0,0.0,0.0),normal=(1.0,0.0,0.0)))
    paired=EVU.verification_raw_weak_residual_v4([interface],ones(4))
    @test paired.interface[1]==-2.0
    @test paired.interface[13]==2.0
    @test paired.jump==zeros(12)
    changed=EVU.verification_raw_weak_residual_v4([interface],[1.0,1.0,1.0,2.0])
    @test changed.jump[1]==2.0
    mktemp() do path,io
        println(io,"kind\tregion\trho\ttheta\tzeta\tx\ty\tz\tBx\tBy\tBz\tp\tJx\tJy\tJz\tgradpx\tgradpy\tgradpz\tnx\tny\tnz\tmeasure")
        println(io,"interface\t1\t0.500001\t0\t0\t1\t0\t0\t0\t0\t0\t2\t0\t0\t0\t0\t0\t0\t1\t0\t0\t1")
        flush(io)
        @test_throws ArgumentError EVU._evuq_read_raw_samples(path)
    end
end
