using Test
using LinearAlgebra
using FusionConceptAI
const CCPP_KERNEL=Module(:CCPP_KERNEL)
Base.include(CCPP_KERNEL,joinpath(@__DIR__,"..","src","RuntimeV4","CandidateCoupledPhysicsV4.jl"))

@testset "candidate weak-volume numerical kernel (test-only states)" begin
    K=CCPP_KERNEL
    # Independently calculable unmagnetized uniform pressure: integral T grad(x/L).
    s=K._ccp_sample(7.0,(0.0,0.0,0.0),(3.0,4.0,5.0),(2.0,3.0,4.0),6.0,1,2.0)
    @test s.weak[1,:]==zeros(3)
    @test s.weak[2:4,:]==21.0*Matrix{Float64}(I,3,3)
    @test s.strong[1,:]==[12.0,18.0,24.0]
    @test s.strong[2,:]==[18.0,27.0,36.0]
    @test s.jacobian[4:6,1]==[3.0,0.0,0.0]
    @test s.jacobian[:,2:4]==zeros(12,3)
    # B parallel z: perpendicular magnetic pressure, parallel magnetic tension.
    mu=K._CCP_MU0
    m=K._ccp_sample(0.0,(0.0,0.0,2.0),(1.0,0.0,0.0),(0.0,0.0,0.0),1.0,1,1.0)
    @test m.weak[2:4,:]≈diagm([2/mu,2/mu,-2/mu])
    # Five-fold rotation cancels horizontal constant-test force but not x*Fx.
    p=K._ccp_sample(0.0,(0.0,0.0,0.0),(2.0,0.0,3.0),(4.0,0.0,7.0),5.0,5,1.0)
    @test norm(p.strong[1,1:2])<1e-13
    @test p.strong[1,3]≈35.0
    @test p.strong[2,1]≈20.0
    @test p.strong[3,2]≈20.0
    @test p.strong[4,3]≈105.0
    # Same scalar volume for all NFP; no second multiplication of the measure.
    p1=K._ccp_sample(9.0,(0.0,0.0,0.0),(2.0,0.0,3.0),(0.0,0.0,0.0),5.0,1,1.0)
    p5=K._ccp_sample(9.0,(0.0,0.0,0.0),(2.0,0.0,3.0),(0.0,0.0,0.0),5.0,5,1.0)
    @test p1.weak≈p5.weak
    # A base-sector Cartesian dB rotates with the tensor, including cross terms.
    for nfp in (1,2,5), B in ((1.0,2.0,3.0),(-0.2,0.7,0.0))
        args=(4e4,B,(4.8,1.2,-0.4),(32.0,-11.0,91.0),0.83,nfp,5.5)
        a=K._ccp_sample(args...); fd=K._ccp_sample_fd(args...)
        @test maximum(abs.(a.jacobian-fd)./max.(1.0,abs.(a.jacobian)))<1e-6
    end
    @test_throws ArgumentError K._ccp_sample(1.0,(1,2,3),(1,2,3),(1,2,3),1.0,0,1.0)
    @test_throws ArgumentError K._ccp_sample(1.0,(1,2,3),(1,2,3),(1,2,3),1.0,1,0.0)
    @test_throws ArgumentError K._ccp_artifacts((request=nothing,))
    @test !K._CCP_EXECUTION.complete_weak_residual_executed
    @test !K._CCP_EXECUTION.external_source_term_executed
    @test !K._CCP_EXECUTION.boundary_term_executed
    @test !K._CCP_EXECUTION.coupled_solve_attempted
end
println("CANDIDATE_COUPLED_PHYSICS_KERNEL_EXIT_CODE=0")
