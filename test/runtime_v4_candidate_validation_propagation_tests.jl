using Test
using FusionConceptAI
const CVPT=Module(:CandidateValidationPropagationTests)
Base.include(CVPT,joinpath(@__DIR__,"..","src","RuntimeV4","CandidateValidationPropagationV4.jl"))

@testset "periodic vector formulation and discrepancy propagation" begin
    b=CVPT.execute_periodic_force_benchmark_v4()
    @test b.status==:pass
    @test b.vector_absolute_error < 1e-12
    @test b.unrotated_proxy_error > 1.0
    @test isapprox(b.observed_error_ratio,4;atol=1e-12)
    @test b.physical_validation_credit==0
    @test CVPT.periodic_cartesian_sum_v4((1.,2.,3.),1)==(1.,2.,3.)
    for n in (2,3,5,8)
        x=CVPT.periodic_cartesian_sum_v4((1.,2.,3.),n)
        @test hypot(x[1],x[2])<1e-13
        @test x[3]==3n
    end
    @test_throws ArgumentError CVPT.periodic_cartesian_sum_v4((1.,2.,3.),0)
    @test_throws ArgumentError CVPT.periodic_cartesian_sum_v4((NaN,2.,3.),2)
    center=((2.,0.,0.),(-1.,0.,0.))
    alternatives=(((3.,1.,0.),(-2.,-1.,0.)),((1.,-1.,0.),(0.,1.,0.)))
    spread=CVPT.propagate_force_formulation_spread_v4(("inner","outer"),center,alternatives)
    @test spread.total_lower_N==(-1.,-2.,0.)
    @test spread.total_upper_N==(3.,2.,0.)
    @test spread.resultant_norm_interval_N==(0.,sqrt(13.))
    @test !spread.certified_error_bound && !spread.probability_model
    # Region deviations can cancel in the original ensemble; propagation must
    # retain the larger worst-case independent box instead of that cancellation.
    @test spread.resultant_norm_interval_N[2]>1
    @test_throws ArgumentError CVPT.propagate_force_formulation_spread_v4(("a","a"),center,alternatives)
    @test_throws ArgumentError CVPT.propagate_force_formulation_spread_v4(("a","b"),center,())
    # Analytic cylindrical force on one field period; phi differs from zeta.
    nfp=3; phi=.41; h=canonical_hash(:periodic_test_point)
    point=(point_hash=h,)
    nodes=((region_id="region",point=point,weight=6.),)
    samples=((point_hash=h,sqrt_g_m3=2.,zeta_rad=.2,
        cylindrical_position_R_phi_Z=(1.,phi,0.),
        F_cylindrical_R_phi_Z_N_m3=(1.,2.,3.),
        F_cartesian_xyz_N_m3=(cos(phi)-2sin(phi),sin(phi)+2cos(phi),3.)),)
    d=CVPT.candidate_periodic_force_diagnostic_v4(nodes,samples,("region",),nfp)
    @test hypot(d.periodic_full_torus_force_N[1],d.periodic_full_torus_force_N[2])<1e-13
    @test d.periodic_full_torus_force_N[3]==36
    @test d.volume_m3==12
    @test isapprox(d.local_force_magnitude_integral_N,12sqrt(14))
    @test !d.explicit_all_periods_provider_execution
    @test d.max_phi_minus_zeta_rad==abs(phi-.2)
    @test_throws ArgumentError CVPT.candidate_periodic_force_diagnostic_v4(nodes,(),("region",),nfp)
    foreign=merge(samples[1],(point_hash=canonical_hash(:foreign),))
    @test_throws ArgumentError CVPT.candidate_periodic_force_diagnostic_v4(nodes,(foreign,),("region",),nfp)
end
println("CANDIDATE_VALIDATION_PROPAGATION_FOCUSED_EXIT_CODE=0")
