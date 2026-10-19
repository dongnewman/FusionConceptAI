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

@testset "axisymmetric five-point MHD component equations and sampled-state Jacobian" begin
    K = CCPP_KERNEL
    coordinates = ((2.0,0.5),(1.75,0.5),(2.25,0.5),(2.0,0.375),(2.0,0.625))
    mu0 = 4e-7pi
    state_for = fields -> [v for (R,Z) in coordinates for v in fields(R,Z)]
    # Uniform axial B has zero curl/div; a linear pressure has its exact gradient.
    q = state_for((R,Z) -> (7R+11Z,0.0,0.0,2.0))
    v = K._ccp_axisymmetric_mhd_stencil(q,coordinates,mu0)
    @test v.residual ≈ [-7.0,0.0,-11.0,0.0]
    @test v.current_cylindrical_A_m2 == zeros(3)
    # Bphi=aR gives Jz=2a/mu0 and radial force=-2a^2 R/mu0.
    # Both the curl metric term and cylindrical cross-product sign are necessary.
    a = 0.75
    q = state_for((R,Z) -> (3.0,0.0,a*R,0.0))
    v = K._ccp_axisymmetric_mhd_stencil(q,coordinates,mu0)
    @test v.current_cylindrical_A_m2 ≈ [0.0,0.0,2a/mu0]
    @test v.residual ≈ [-2a*a*coordinates[1][1]/mu0,0.0,0.0,0.0]
    # Br=aR detects the divergence metric term independently of the force rows.
    q = state_for((R,Z) -> (0.0,a*R,0.0,0.0))
    @test K._ccp_axisymmetric_mhd_stencil(q,coordinates,mu0).residual[4] ≈ 2a

    a,b,c,d,e,f,g,h = 0.7,-0.2,0.3,0.4,-0.6,0.1,3e4,-2e4
    q = state_for((R,Z) -> (g*R+h*Z,c*R+d*Z,a*R+b*Z,e*R+f*Z))
    v = K._ccp_axisymmetric_mhd_stencil(q,coordinates,mu0)
    R,Z = coordinates[1]
    exact_current = [-b,d-e,2a+b*Z/R]/mu0
    exact_B = [c*R+d*Z,a*R+b*Z,e*R+f*Z]
    @test v.current_cylindrical_A_m2 ≈ exact_current
    @test v.residual[1:3] ≈ cross(exact_current,exact_B)-[g,0.0,h]
    @test v.residual[4] ≈ 2c+d*Z/R+f
    @test size(v.jacobian) == (4,20)
    @test norm(v.jacobian) > 0
    @test v.row_units == ("N m^-3","N m^-3","N m^-3","T m^-1")
    @test v.state_units == Tuple(mod1(i,4) == 1 ? "Pa" : "T" for i in 1:20)
    # Residual is degree <=2 in the sampled state, so central FD has no
    # truncation error. Pressure and magnetic columns use their own unit scales.
    fd = zeros(4,20)
    for j in 1:20
        scale = mod1(j,4) == 1 ? maximum(abs,q[1:4:end]) : maximum(abs,q[2:4:end])+maximum(abs,q[3:4:end])+maximum(abs,q[4:4:end])
        step = 1e-3*max(scale,1.0)
        plus=copy(q); minus=copy(q); plus[j]+=step; minus[j]-=step
        fd[:,j] = (K._ccp_axisymmetric_mhd_stencil(plus,coordinates,mu0).residual-
            K._ccp_axisymmetric_mhd_stencil(minus,coordinates,mu0).residual)/(2step)
    end
    @test maximum(abs.(v.jacobian-fd)./max.(1.0,abs.(v.jacobian))) < 1e-6
    changed=copy(q); changed[3]+=0.2
    w=K._ccp_axisymmetric_mhd_stencil(changed,coordinates,mu0)
    @test norm(w.residual-v.residual) > 0
    @test norm(w.jacobian-v.jacobian) > 0
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil(q[1:19],coordinates,mu0)
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil([Inf;q[2:end]],coordinates,mu0)
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil(q,coordinates,0.0)
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil(q,
        (coordinates[1],coordinates[3],coordinates[2],coordinates[4],coordinates[5]),mu0)
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil(q,
        (coordinates[1],(1.5,0.5),coordinates[3],coordinates[4],coordinates[5]),mu0)
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil(q,
        ((0.0,0.5),coordinates[2:end]...),mu0)
    @test_throws ArgumentError K._ccp_axisymmetric_mhd_stencil(q,
        (coordinates[1:3]...,coordinates[1],coordinates[1]),mu0)
end

println("CANDIDATE_COUPLED_PHYSICS_KERNEL_EXIT_CODE=0")
