# Test delta for the source-owned D-T reactivity provider.
# Inputs are explicit homogeneous authored screen assumptions. These are not
# candidate measurements and do not bind the existing thermal slab to plasma.
using Test
using FusionConceptAI
using JSON3

if !isdefined(Main, :FusionRuntimeV4)
    FusionConceptAI.load_vnext_t2_components_v2!()
    Base.include(Main, joinpath(dirname(pathof(FusionConceptAI)), "RuntimeV4",
        "FusionRuntimeV4.jl"))
end

@testset "D-T fusion reactivity frozen-composition screen" begin
    rt = Main.FusionRuntimeV4
    # Independent project-order tuple literals: m, kg, s, A, K, mol, cd.
    nD_unit = UnitSignature((-3, 0, 0, 0, 0, 0, 0))
    nT_unit = UnitSignature((-3, 0, 0, 0, 0, 0, 0))
    Ti_unit = UnitSignature((2, 1, -2, 0, 0, 0, 0))
    volume_unit = UnitSignature((3, 0, 0, 0, 0, 0, 0))
    time_unit = UnitSignature((0, 0, 1, 0, 0, 0, 0))
    dimensionless_unit = UnitSignature()
    power_density_unit = UnitSignature((-1, 1, -3, 0, 0, 0, 0))

    dq(value, unit, dimensions) = rt.DTFusionQuantityV1(value, unit, dimensions)
    function input_v1(;nD=1.1e20, nT=0.7e20, Ti=10.0, volume=0.05,
            interval=0.25, alpha_fraction=0.35, auxiliary=1.8e5, loss=4.0e4)
        rt.DTFusionReactivityInputV1(
            dq(nD, :m3_inverse, nD_unit),
            dq(nT, :m3_inverse, nT_unit),
            dq(Ti, :keV, Ti_unit),
            dq(volume, :m3, volume_unit),
            dq(interval, :s, time_unit),
            dq(alpha_fraction, :one, dimensionless_unit),
            dq(auxiliary, :W_m3, power_density_unit),
            dq(loss, :W_m3, power_density_unit))
    end

    provider = rt.dt_fusion_reactivity_manifest_v1()
    @test provider isa rt.ProviderManifestV4
    @test provider.backend_revision == "bosch-hale-1992-fit-v1"

    source = rt.evaluate_dt_fusion_reactivity_v1(input_v1(); providers=(provider,))
    @test source.status === :screen_only
    @test source.reason === :explicit_homogeneous_0d_input_evaluated
    @test source.provider_match_status === rt.unique_match
    @test source.candidate_bound === false
    @test source.physical_evidence === false
    @test source.engineering_evidence === false
    @test source.terminal_authority === false
    @test source.whole_device === false
    @test source.claim_ceiling === rt.screen_only

    # Frozen Bosch-Hale/PROCESS reference value for thermal D-T at 10 keV.
    # This catches the fit/temperature-unit path independently of the power
    # bookkeeping assertions below.
    expected_reactivity_10keV = 1.1361654705836232e-22
    @test isapprox(source.reactivity_m3_s, expected_reactivity_10keV;
        rtol=2e-12, atol=0.0)
    @test source.reaction_rate_density_per_m3_s ≈ 1.1e20 * 0.7e20 *
        expected_reactivity_10keV rtol=2e-12
    @test source.source_reference.citation ==
        "Bosch and Hale, Nuclear Fusion 32(4), 611-631 (1992)"
    @test source.source_reference.doi == "10.1088/0029-5515/32/4/I07"
    @test source.source_reference.implementation == "bosch-hale-dt-fit-v1"
    @test source.provider_code_hash == provider.code_hash
    @test source.integration_model === :frozen_composition_exposure
    provider_source = joinpath(dirname(pathof(FusionConceptAI)), "RuntimeV4",
        "DTFusionReactivityV1.jl")
    @test provider.code_hash == digest256_text(read(provider_source, String))

    joules_per_eV = 1.602176634e-19
    joules_per_MeV = 1e6 * joules_per_eV
    dt_total_J = 17.6 * joules_per_MeV
    dt_alpha_J = 3.5 * joules_per_MeV
    dt_neutron_J = 14.1 * joules_per_MeV
    expected_reactions = source.reaction_rate_density_per_m3_s * 0.05 * 0.25
    @test source.reaction_count_over_interval ≈ expected_reactions rtol=2e-12
    @test source.fusion_birth_energy_J ≈ expected_reactions * dt_total_J rtol=2e-12
    @test source.alpha_birth_energy_J ≈ expected_reactions * dt_alpha_J rtol=2e-12
    @test source.neutron_birth_energy_J ≈ expected_reactions * dt_neutron_J rtol=2e-12
    @test source.alpha_birth_energy_J + source.neutron_birth_energy_J ≈
        source.fusion_birth_energy_J rtol=2e-12
    @test source.alpha_birth_power_density_W_m3 ≈
        source.reaction_rate_density_per_m3_s * dt_alpha_J rtol=2e-12
    @test source.neutron_birth_power_density_W_m3 ≈
        source.reaction_rate_density_per_m3_s * dt_neutron_J rtol=2e-12
    @test source.fusion_power_density_W_m3 ≈
        source.reaction_rate_density_per_m3_s * dt_total_J rtol=2e-12
    @test source.alpha_birth_power_density_W_m3 +
        source.neutron_birth_power_density_W_m3 ≈
        source.fusion_power_density_W_m3 rtol=2e-12
    @test source.deuterium_consumption_density_per_m3 ≈
        source.reaction_rate_density_per_m3_s * 0.25 rtol=2e-12
    @test source.tritium_consumption_density_per_m3 ≈
        source.reaction_rate_density_per_m3_s * 0.25 rtol=2e-12
    @test source.helium_birth_count_over_interval ≈ expected_reactions rtol=2e-12
    @test source.neutron_birth_count_over_interval ≈ expected_reactions rtol=2e-12
    @test abs(source.fusion_partition_residual_J) <= 1e-10 * source.fusion_birth_energy_J
    @test source.deposited_alpha_energy_J ≈
        source.alpha_birth_energy_J * 0.35 rtol=2e-12
    @test source.net_thermal_source_W_m3 ≈
        source.deposited_alpha_power_density_W_m3 + 1.8e5 - 4e4 rtol=2e-12
    @test abs(source.thermal_account_residual_J) <= 1e-10 *
        max(abs(source.net_thermal_source_energy_J), 1.0)
    @test 0.0 < source.frozen_composition_fuel_demand_fraction < 0.01
    @test any(x -> occursin("homogeneous 0D", x), source.assumptions)
    @test any(x -> occursin("frozen", x), source.assumptions)

    # Density, temperature, time, and deposition are consumed inputs, not
    # metadata: each changes the expected physical output in the correct way.
    density_scaled = rt.evaluate_dt_fusion_reactivity_v1(
        input_v1(nD=2.2e20); providers=(provider,))
    @test density_scaled.status === :screen_only
    @test density_scaled.reaction_rate_density_per_m3_s ≈
        2 * source.reaction_rate_density_per_m3_s rtol=2e-12
    @test density_scaled.fusion_birth_energy_J ≈ 2 * source.fusion_birth_energy_J rtol=2e-12

    hotter = rt.evaluate_dt_fusion_reactivity_v1(
        input_v1(Ti=15.0); providers=(provider,))
    @test hotter.status === :screen_only
    @test hotter.reactivity_m3_s ≈ 2.7399296107880726e-22 rtol=2e-12
    @test hotter.reaction_rate_density_per_m3_s > source.reaction_rate_density_per_m3_s

    longer = rt.evaluate_dt_fusion_reactivity_v1(
        input_v1(interval=0.5); providers=(provider,))
    @test longer.status === :screen_only
    @test longer.reaction_count_over_interval ≈ 2 * source.reaction_count_over_interval rtol=2e-12
    @test longer.fusion_birth_energy_J ≈ 2 * source.fusion_birth_energy_J rtol=2e-12

    larger_volume = rt.evaluate_dt_fusion_reactivity_v1(
        input_v1(volume=0.1); providers=(provider,))
    @test larger_volume.status === :screen_only
    @test larger_volume.reaction_count_over_interval ≈
        2 * source.reaction_count_over_interval rtol=2e-12
    @test larger_volume.fusion_birth_energy_J ≈
        2 * source.fusion_birth_energy_J rtol=2e-12

    more_deposition = rt.evaluate_dt_fusion_reactivity_v1(
        input_v1(alpha_fraction=0.7); providers=(provider,))
    @test more_deposition.status === :screen_only
    @test more_deposition.fusion_birth_energy_J ≈ source.fusion_birth_energy_J rtol=2e-12
    @test more_deposition.deposited_alpha_energy_J ≈
        2 * source.deposited_alpha_energy_J rtol=2e-12

    absent = rt.evaluate_dt_fusion_reactivity_v1(nothing; providers=(provider,))
    @test absent.status === :typed_absent
    @test absent.reason === :plasma_input_not_available
    @test absent.provider_match_status === :not_attempted
    missing_provider = rt.evaluate_dt_fusion_reactivity_v1(input_v1(); providers=())
    @test missing_provider.status === :typed_absent
    @test missing_provider.reason === :provider_match_not_unique
    @test missing_provider.provider_match_status === rt.no_match

    for bad_Ti in (0.19, 0.2, 100.0, 100.01)
        outside = rt.evaluate_dt_fusion_reactivity_v1(
            input_v1(Ti=bad_Ti); providers=(provider,))
        @test outside.status === :typed_absent
        @test outside.reason === :Ti_outside_Bosch_Hale_domain
        @test outside.provider_match_status === rt.unique_match
    end

    valid = input_v1()
    swapped_mass_length = rt.DTFusionReactivityInputV1(
        dq(1.1e20, :m3_inverse, UnitSignature((0, -3, 0, 0, 0, 0, 0))),
        valid.nT_m3, valid.Ti_keV, valid.volume_m3, valid.interval_s,
        valid.alpha_deposition_fraction, valid.auxiliary_power_density_W_m3,
        valid.declared_loss_power_density_W_m3)
    @test_throws ArgumentError rt.evaluate_dt_fusion_reactivity_v1(
        swapped_mass_length; providers=(provider,))
    wrong_energy_label = rt.DTFusionReactivityInputV1(valid.nD_m3, valid.nT_m3,
        dq(10.0, :eV, Ti_unit), valid.volume_m3, valid.interval_s,
        valid.alpha_deposition_fraction, valid.auxiliary_power_density_W_m3,
        valid.declared_loss_power_density_W_m3)
    @test_throws ArgumentError rt.evaluate_dt_fusion_reactivity_v1(
        wrong_energy_label; providers=(provider,))
    wrong_time_dimension = rt.DTFusionReactivityInputV1(valid.nD_m3, valid.nT_m3,
        valid.Ti_keV, valid.volume_m3, dq(0.25, :s,
            UnitSignature((0, 0, 0, 0, 0, 0, 0))),
        valid.alpha_deposition_fraction, valid.auxiliary_power_density_W_m3,
        valid.declared_loss_power_density_W_m3)
    @test_throws ArgumentError rt.evaluate_dt_fusion_reactivity_v1(
        wrong_time_dimension; providers=(provider,))
    wrong_power_dimension = rt.DTFusionReactivityInputV1(valid.nD_m3, valid.nT_m3,
        valid.Ti_keV, valid.volume_m3, valid.interval_s,
        valid.alpha_deposition_fraction, dq(1.8e5, :W_m3,
            UnitSignature((2, 1, -3, 0, 0, 0, 0))),
        valid.declared_loss_power_density_W_m3)
    @test_throws ArgumentError rt.evaluate_dt_fusion_reactivity_v1(
        wrong_power_dimension; providers=(provider,))

    println("UP2_DT_REACTIVITY_ACTUAL=" * JSON3.write((
        status=source.status,
        reason=source.reason,
        provider_match_status=string(source.provider_match_status),
        provider_backend_revision=source.provider_backend_revision,
        integration_model=source.integration_model,
        reactivity_10keV_m3_s=source.reactivity_m3_s,
        reactivity_15keV_m3_s=hotter.reactivity_m3_s,
        reaction_rate_density_per_m3_s=source.reaction_rate_density_per_m3_s,
        alpha_birth_power_density_W_m3=source.alpha_birth_power_density_W_m3,
        neutron_birth_power_density_W_m3=source.neutron_birth_power_density_W_m3,
        fusion_power_density_W_m3=source.fusion_power_density_W_m3,
        deposited_alpha_power_density_W_m3=source.deposited_alpha_power_density_W_m3,
        net_thermal_source_W_m3=source.net_thermal_source_W_m3,
        thermal_account_residual_J=source.thermal_account_residual_J,
        claim_ceiling=string(source.claim_ceiling),
        candidate_bound=source.candidate_bound,
        physical_evidence=source.physical_evidence,
        engineering_evidence=source.engineering_evidence,
        terminal_authority=source.terminal_authority,
        whole_device=source.whole_device)))

    evolve(input; providers=(provider,)) =
        rt.evolve_dt_fusion_composition_v1(input; providers=providers)
    function assert_evolved_closure(result, volume=0.05)
        @test result.status === :screen_only
        @test result.integration_model === :analytic_composition_evolution
        @test result.claim_ceiling === rt.screen_only
        @test result.candidate_bound === false
        @test result.physical_evidence === false
        @test result.engineering_evidence === false
        @test result.terminal_authority === false
        @test result.whole_device === false
        @test isfinite(result.reaction_extent_per_m3)
        @test 0.0 <= result.reaction_extent_per_m3 <= min(result.initial_nD_m3,
            result.initial_nT_m3)
        @test 0.0 <= result.final_nD_m3 <= result.initial_nD_m3
        @test 0.0 <= result.final_nT_m3 <= result.initial_nT_m3
        @test 0.0 <= result.final_fuel_demand_fraction <= 1.0
        density_scale = max(result.initial_nD_m3, result.initial_nT_m3, 1.0)
        @test abs(result.deuterium_particle_balance_residual_per_m3) <= 1e-12 * density_scale
        @test abs(result.tritium_particle_balance_residual_per_m3) <= 1e-12 * density_scale
        @test abs(result.helium_particle_balance_residual_per_m3) <= 1e-12 * density_scale
        @test abs(result.neutron_particle_balance_residual_per_m3) <= 1e-12 * density_scale
        @test abs(result.nucleon_inventory_balance_residual_per_m3) <= 1e-12 * density_scale
        energy_scale = max(abs(result.fusion_birth_energy_J),
            abs(result.net_thermal_source_energy_J), 1.0)
        @test abs(result.fusion_energy_partition_residual_J) <= 1e-12 * energy_scale
        @test abs(result.thermal_energy_account_residual_J) <= 1e-12 * energy_scale
        @test result.helium4_birth_count ≈ result.fusion_reaction_count rtol=2e-12
        @test result.neutron_birth_count ≈ result.fusion_reaction_count rtol=2e-12
        @test result.deuterium_consumed_count ≈
            (result.initial_nD_m3 - result.final_nD_m3) * volume rtol=2e-12
        @test result.tritium_consumed_count ≈
            (result.initial_nT_m3 - result.final_nT_m3) * volume rtol=2e-12
        @test result.fusion_birth_energy_density_J_m3 ≈
            result.alpha_birth_energy_density_J_m3 + result.neutron_birth_energy_density_J_m3 rtol=2e-12
        @test result.fusion_birth_energy_J ≈
            result.fusion_birth_energy_density_J_m3 * volume rtol=2e-12
        @test result.net_thermal_source_energy_density_J_m3 ≈
            result.deposited_alpha_energy_density_J_m3 + result.auxiliary_energy_density_J_m3 -
                result.declared_loss_energy_density_J_m3 rtol=2e-12
        @test result.net_thermal_source_energy_J ≈
            result.net_thermal_source_energy_density_J_m3 * volume rtol=2e-12
        @test result.source_reference.doi == "10.1088/0029-5515/32/4/I07"
        @test result.source_reference.implementation == "bosch-hale-dt-fit-v1"
        return nothing
    end

    # Equal-fuel analytic solution and the low-extent limit against the existing
    # frozen-composition exposure on the same explicit input.
    equal_input = input_v1(nD=0.7e20, nT=0.7e20)
    equal_evolved = evolve(equal_input)
    assert_evolved_closure(equal_evolved, equal_input.volume_m3.value)
    equal_expected_final = 0.7e20 / (1 + source.reactivity_m3_s * 0.7e20 * 0.25)
    @test equal_evolved.final_nD_m3 ≈ equal_expected_final rtol=2e-12
    @test equal_evolved.final_nT_m3 ≈ equal_expected_final rtol=2e-12
    @test equal_evolved.reaction_extent_per_m3 ≈
        equal_input.nD_m3.value - equal_expected_final rtol=2e-12
    @test equal_evolved.fixed_Ti_keV == equal_input.Ti_keV.value

    low_input = input_v1()
    low_extent = evolve(low_input)
    assert_evolved_closure(low_extent, low_input.volume_m3.value)
    @test low_extent.reaction_extent_per_m3 ≈
        source.reaction_rate_density_per_m3_s * low_input.interval_s.value rtol=5e-3
    @test low_extent.final_nD_m3 < low_extent.initial_nD_m3
    @test low_extent.final_nT_m3 < low_extent.initial_nT_m3

    near_equal_input = input_v1(nD=0.7e20, nT=0.700007e20, interval=100.0)
    near_equal = evolve(near_equal_input)
    assert_evolved_closure(near_equal, near_equal_input.volume_m3.value)
    near_equal_mean = (near_equal_input.nD_m3.value + near_equal_input.nT_m3.value) / 2
    near_equal_expected = near_equal_mean /
        (1 + near_equal.frozen_temperature_reactivity_m3_s * near_equal_mean *
            near_equal_input.interval_s.value)
    @test near_equal.final_nD_m3 ≈ near_equal_expected rtol=2e-5
    @test near_equal.final_nT_m3 ≈ near_equal_expected rtol=2e-5
    @test near_equal.final_nD_m3 > 0.0 && near_equal.final_nT_m3 > 0.0

    adjacent_input = input_v1(nD=1.0e20, nT=nextfloat(1.0e20))
    adjacent_evolved = evolve(adjacent_input)
    assert_evolved_closure(adjacent_evolved, adjacent_input.volume_m3.value)
    @test adjacent_input.nT_m3.value - adjacent_input.nD_m3.value == eps(1.0e20)
    adjacent_expected = 1.0e20 /
        (1 + adjacent_evolved.frozen_temperature_reactivity_m3_s * 1.0e20 *
            adjacent_input.interval_s.value)
    @test adjacent_evolved.final_nD_m3 ≈ adjacent_expected rtol=2e-12
    @test adjacent_evolved.final_nT_m3 ≈ adjacent_expected rtol=2e-12
    @test adjacent_evolved.final_nD_m3 > 0.0 && adjacent_evolved.final_nT_m3 > 0.0

    # Both majority/minority orientations use the same depletion law. This
    # finite interval exceeds the frozen evaluator's inventory screen.
    high_d_rich_input = input_v1(nD=1.1e20, nT=0.7e20, interval=100.0)
    high_d_rich = evolve(high_d_rich_input)
    assert_evolved_closure(high_d_rich, high_d_rich_input.volume_m3.value)
    @test high_d_rich.final_fuel_demand_fraction > 0.5
    d_ratio_change = log((high_d_rich.final_nT_m3 / high_d_rich.final_nD_m3) /
        (high_d_rich.initial_nT_m3 / high_d_rich.initial_nD_m3))
    @test d_ratio_change ≈ -high_d_rich.frozen_temperature_reactivity_m3_s *
        (high_d_rich.initial_nD_m3 - high_d_rich.initial_nT_m3) *
        high_d_rich_input.interval_s.value rtol=2e-11
    frozen_overdraw = rt.evaluate_dt_fusion_reactivity_v1(high_d_rich_input;
        providers=(provider,))
    @test frozen_overdraw.status === :typed_absent
    @test frozen_overdraw.reason === :frozen_composition_fuel_demand_exceeds_inventory
    frozen_manifest_overdraw =
        rt.dt_fusion_reactivity_manifest_v1().executor(high_d_rich_input)
    @test frozen_manifest_overdraw.status === :typed_absent
    @test frozen_manifest_overdraw.reason === :frozen_composition_fuel_demand_exceeds_inventory
    @test_throws MethodError rt.dt_fusion_reactivity_manifest_v1().executor(
        high_d_rich_input; allow_frozen_interval_overdraw=true)
    @test high_d_rich.final_nD_m3 >= 0.0 && high_d_rich.final_nT_m3 >= 0.0
    @test high_d_rich.status === :screen_only

    high_t_rich_input = input_v1(nD=0.7e20, nT=1.1e20, interval=100.0)
    high_t_rich = evolve(high_t_rich_input)
    assert_evolved_closure(high_t_rich, high_t_rich_input.volume_m3.value)
    @test high_t_rich.final_fuel_demand_fraction > 0.5
    t_ratio_change = log((high_t_rich.final_nD_m3 / high_t_rich.final_nT_m3) /
        (high_t_rich.initial_nD_m3 / high_t_rich.initial_nT_m3))
    @test t_ratio_change ≈ -high_t_rich.frozen_temperature_reactivity_m3_s *
        (high_t_rich.initial_nT_m3 - high_t_rich.initial_nD_m3) *
        high_t_rich_input.interval_s.value rtol=2e-11
    @test rt.evaluate_dt_fusion_reactivity_v1(high_t_rich_input;
        providers=(provider,)).status === :typed_absent

    # Each supplied case keeps its own Ti; the evolver holds it fixed.
    hot_input = input_v1(nD=0.7e20, nT=0.7e20, Ti=15.0)
    hot_evolved = evolve(hot_input)
    assert_evolved_closure(hot_evolved, hot_input.volume_m3.value)
    @test hot_evolved.fixed_Ti_keV == 15.0
    @test hot_evolved.frozen_temperature_reactivity_m3_s ≈
        2.7399296107880726e-22 rtol=2e-12
    @test hot_evolved.frozen_temperature_reactivity_m3_s >
        equal_evolved.frozen_temperature_reactivity_m3_s

    no_fuel_input = input_v1(nD=0.0, nT=0.7e20)
    no_fuel = evolve(no_fuel_input)
    assert_evolved_closure(no_fuel, no_fuel_input.volume_m3.value)
    @test no_fuel.reaction_extent_per_m3 == 0.0
    @test no_fuel.final_nD_m3 == 0.0
    @test no_fuel.final_nT_m3 == 0.7e20
    @test no_fuel.final_fuel_demand_fraction == 0.0

    absent_evolution = rt.evolve_dt_fusion_composition_v1(nothing; providers=(provider,))
    @test absent_evolution.status === :typed_absent
    @test absent_evolution.reason === :plasma_input_not_available
    @test absent_evolution.provider_match_status === :not_attempted
    no_provider_evolution = rt.evolve_dt_fusion_composition_v1(input_v1(); providers=())
    @test no_provider_evolution.status === :typed_absent
    @test no_provider_evolution.reason === :provider_match_not_unique
    @test no_provider_evolution.provider_match_status === rt.no_match

    for bad_Ti in (0.19, 0.2, 100.0, 100.01)
        outside_evolution = evolve(input_v1(Ti=bad_Ti))
        @test outside_evolution.status === :typed_absent
        @test outside_evolution.reason === :Ti_outside_Bosch_Hale_domain
        @test outside_evolution.provider_match_status === rt.unique_match
    end
    negative_fuel = evolve(input_v1(nD=-1.0))
    @test negative_fuel.status === :typed_absent
    @test negative_fuel.reason === :negative_fuel_density
    @test_throws ArgumentError rt.evolve_dt_fusion_composition_v1(
        swapped_mass_length; providers=(provider,))
    @test_throws ArgumentError rt.evolve_dt_fusion_composition_v1(
        wrong_energy_label; providers=(provider,))
    @test_throws ArgumentError rt.evolve_dt_fusion_composition_v1(
        wrong_time_dimension; providers=(provider,))
    @test_throws ArgumentError rt.evolve_dt_fusion_composition_v1(
        wrong_power_dimension; providers=(provider,))

    println("UP2_DT_COMPOSITION_EVOLUTION_ACTUAL=" * JSON3.write((
        status=equal_evolved.status,
        model=equal_evolved.integration_model,
        equal_initial=(nD=equal_evolved.initial_nD_m3, nT=equal_evolved.initial_nT_m3,
            final_nD=equal_evolved.final_nD_m3, final_nT=equal_evolved.final_nT_m3,
            extent=equal_evolved.reaction_extent_per_m3, fixed_Ti_keV=equal_evolved.fixed_Ti_keV),
        unequal_d_rich=(nD=high_d_rich.final_nD_m3, nT=high_d_rich.final_nT_m3,
            extent=high_d_rich.reaction_extent_per_m3,
            demand=high_d_rich.final_fuel_demand_fraction),
        unequal_t_rich=(nD=high_t_rich.final_nD_m3, nT=high_t_rich.final_nT_m3,
            extent=high_t_rich.reaction_extent_per_m3,
            demand=high_t_rich.final_fuel_demand_fraction),
        near_equal=(final_nD=near_equal.final_nD_m3,
            final_nT=near_equal.final_nT_m3, demand=near_equal.final_fuel_demand_fraction),
        adjacent_to_equal=(nT_minus_nD=adjacent_input.nT_m3.value -
            adjacent_input.nD_m3.value, final_nD=adjacent_evolved.final_nD_m3,
            final_nT=adjacent_evolved.final_nT_m3),
        hot=(Ti_keV=hot_evolved.fixed_Ti_keV,
            reactivity_m3_s=hot_evolved.frozen_temperature_reactivity_m3_s),
        no_fuel_extent=no_fuel.reaction_extent_per_m3,
        scope=(screen_only=equal_evolved.claim_ceiling === rt.screen_only,
            candidate_bound=equal_evolved.candidate_bound,
            physical_evidence=equal_evolved.physical_evidence,
            terminal_authority=equal_evolved.terminal_authority))))
end
