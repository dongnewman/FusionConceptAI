"""A narrow 0D Bosch–Hale D-T reactivity screen.

This provider consumes only explicit user-declared homogeneous plasma inputs.
It is not bound to a candidate plasma state and does not provide a spatial
heat-deposition model or device-level result. The separate opt-in composition
evolver uses this rate provider but remains an unbound homogeneous 0D screen.
"""

const _DT_REACTIVITY_SCHEMA = "fusionconceptai:dt-thermonuclear-reactivity"
const _DT_REACTIVITY_REVISION = "v1"
const _DT_REACTIVITY_REFERENCE = (citation="Bosch and Hale, Nuclear Fusion 32(4), 611-631 (1992)",
    doi="10.1088/0029-5515/32/4/I07", implementation="bosch-hale-dt-fit-v1")
const _DT_BOSCH_HALE_DOMAIN = (minimum_Ti_keV=0.2, maximum_Ti_keV=100.0,
    interval="strict-open", distribution="equal-temperature Maxwellian D/T",
    composition="uniform, frozen nD and nT", spatial_model="homogeneous 0D",
    source="Bosch-Hale 1992 DT fit")

const _DT_UNIT_ONE = UnitSignature()
const _DT_UNIT_DENSITY = UnitSignature((-3, 0, 0, 0, 0, 0, 0))
const _DT_UNIT_ENERGY = UnitSignature((2, 1, -2, 0, 0, 0, 0))
const _DT_UNIT_REACTIVITY = UnitSignature((3, 0, -1, 0, 0, 0, 0))
const _DT_UNIT_VOLUME = UnitSignature((3, 0, 0, 0, 0, 0, 0))
const _DT_UNIT_SECONDS = UnitSignature((0, 0, 1, 0, 0, 0, 0))
const _DT_UNIT_RATE_DENSITY = UnitSignature((-3, 0, -1, 0, 0, 0, 0))
const _DT_UNIT_POWER_DENSITY = UnitSignature((-1, 1, -3, 0, 0, 0, 0))
const _DT_UNIT_ENERGY_DENSITY = UnitSignature((-1, 1, -2, 0, 0, 0, 0))
const _DT_UNIT_ENERGY_J = UnitSignature((2, 1, -2, 0, 0, 0, 0))

"""A scalar accompanied by a display unit and its SI dimension signature."""
struct DTFusionQuantityV1{T<:Real}
    value::T
    unit::Symbol
    dimension::UnitSignature
    function DTFusionQuantityV1(value::Real, unit::Symbol, dimension::UnitSignature)
        value isa Bool && throw(ArgumentError("D-T quantity value cannot be Bool"))
        isvalid(String(unit)) && lowercase(String(unit)) ∉ ("*", "any", "wildcard", "all") ||
            throw(ArgumentError("D-T quantity unit cannot be empty or wildcard"))
        new{typeof(value)}(value, unit, dimension)
    end
end
semantic_view(x::DTFusionQuantityV1) =
    (value=x.value, unit=x.unit, dimension=x.dimension)

"""Explicit inputs for a homogeneous, frozen-composition DT rate screen.

All fields are required. In particular, no plasma conditions, deposition
fraction, auxiliary heating, or loss term is defaulted by this API.
"""
struct DTFusionReactivityInputV1
    nD_m3::DTFusionQuantityV1
    nT_m3::DTFusionQuantityV1
    Ti_keV::DTFusionQuantityV1
    volume_m3::DTFusionQuantityV1
    interval_s::DTFusionQuantityV1
    alpha_deposition_fraction::DTFusionQuantityV1
    auxiliary_power_density_W_m3::DTFusionQuantityV1
    declared_loss_power_density_W_m3::DTFusionQuantityV1
    function DTFusionReactivityInputV1(nD_m3, nT_m3, Ti_keV, volume_m3,
            interval_s, alpha_deposition_fraction, auxiliary_power_density_W_m3,
            declared_loss_power_density_W_m3)
        fields = (nD_m3, nT_m3, Ti_keV, volume_m3, interval_s,
            alpha_deposition_fraction, auxiliary_power_density_W_m3,
            declared_loss_power_density_W_m3)
        all(x -> x isa DTFusionQuantityV1, fields) ||
            throw(ArgumentError("all D-T screen inputs must be explicit DTFusionQuantityV1 values"))
        new(fields...)
    end
end
semantic_view(x::DTFusionReactivityInputV1) =
    (schema="dt-fusion-reactivity-input-v1", nD_m3=x.nD_m3, nT_m3=x.nT_m3,
     Ti_keV=x.Ti_keV, volume_m3=x.volume_m3, interval_s=x.interval_s,
     alpha_deposition_fraction=x.alpha_deposition_fraction,
     auxiliary_power_density_W_m3=x.auxiliary_power_density_W_m3,
     declared_loss_power_density_W_m3=x.declared_loss_power_density_W_m3)

function _dt_reactivity_capability()
    input_schema = canonical_hash((schema="dt-fusion-reactivity-input-v1",
        fields=((:nD_m3, :m3_inverse, _DT_UNIT_DENSITY),
                (:nT_m3, :m3_inverse, _DT_UNIT_DENSITY),
                (:Ti_keV, :keV, _DT_UNIT_ENERGY),
                (:volume_m3, :m3, _DT_UNIT_VOLUME),
                (:interval_s, :s, _DT_UNIT_SECONDS),
                (:alpha_deposition_fraction, :one, _DT_UNIT_ONE),
                (:auxiliary_power_density_W_m3, :W_m3, _DT_UNIT_POWER_DENSITY),
                (:declared_loss_power_density_W_m3, :W_m3, _DT_UNIT_POWER_DENSITY))))
    CapabilitySignatureV4(_DT_REACTIVITY_SCHEMA, _DT_REACTIVITY_REVISION,
        :dt_thermonuclear_reactivity, "bosch_hale_dt_rate_and_0d_energy_screen",
        ("uniform_D_T_density", "equal_Maxwellian_ion_temperature", "constant_interval"),
        "user_declared_0d_plasma", "dt_reactivity_energy_screen", 0, (),
        "uniform-volume-account", "no-spatial-interface", "constant-over-interval",
        ("reactivity", "reaction_rate_density", "fusion_power_partition", "screen_energy_balance"),
        screen_only, canonical_hash(_DT_BOSCH_HALE_DOMAIN);
        input_schema_hash=input_schema, coordinate_system="lumped")
end

function _dt_reactivity_provider_code_hash()
    source_path = joinpath(@__DIR__, basename(@__FILE__))
    isfile(source_path) || throw(ArgumentError("D-T provider source file is unavailable"))
    digest256_text(read(source_path, String))
end

function _dt_bosch_hale_reactivity_m3_s(Ti_keV::Float64)
    0.2 < Ti_keV < 100.0 || return nothing
    bg = 34.3827
    mrc2 = 1124656.0
    c1 = 1.17302e-9
    c2 = 0.0151361
    c3 = 0.0751886
    c4 = 0.00460643
    c5 = 0.0135
    c6 = -0.00010675
    c7 = 1.366e-5
    theta1 = Ti_keV * (c2 + Ti_keV * (c4 + Ti_keV * c6)) /
        (1.0 + Ti_keV * (c3 + Ti_keV * (c5 + Ti_keV * c7)))
    theta = Ti_keV / (1.0 - theta1)
    theta > 0.0 && isfinite(theta) || return nothing
    xi = (bg^2 / (4.0 * theta))^(1.0 / 3.0)
    value = 1.0e-6 * c1 * theta * sqrt(xi / (mrc2 * Ti_keV^3)) * exp(-3.0 * xi)
    isfinite(value) && value > 0.0 ? value : nothing
end

function _dt_screen_typed_absent(reason::Symbol; provider_match_status=:not_attempted,
        detail="D-T input is unavailable within the declared screen scope")
    (status=:typed_absent, reason=reason, detail=detail,
     provider_match_status=provider_match_status, claim_ceiling=screen_only,
     candidate_bound=false, physical_evidence=false, engineering_evidence=false,
     terminal_authority=false, whole_device=false)
end

function _dt_input_values(input::DTFusionReactivityInputV1)
    expected = ((:nD_m3, input.nD_m3, :m3_inverse, _DT_UNIT_DENSITY),
        (:nT_m3, input.nT_m3, :m3_inverse, _DT_UNIT_DENSITY),
        (:Ti_keV, input.Ti_keV, :keV, _DT_UNIT_ENERGY),
        (:volume_m3, input.volume_m3, :m3, _DT_UNIT_VOLUME),
        (:interval_s, input.interval_s, :s, _DT_UNIT_SECONDS),
        (:alpha_deposition_fraction, input.alpha_deposition_fraction, :one, _DT_UNIT_ONE),
        (:auxiliary_power_density_W_m3, input.auxiliary_power_density_W_m3, :W_m3, _DT_UNIT_POWER_DENSITY),
        (:declared_loss_power_density_W_m3, input.declared_loss_power_density_W_m3, :W_m3, _DT_UNIT_POWER_DENSITY))
    for (name, quantity, expected_unit, expected_dimension) in expected
        quantity.unit == expected_unit && quantity.dimension == expected_dimension ||
            throw(ArgumentError("D-T screen input $name has an incompatible unit label or dimension"))
    end
    vals = ntuple(i -> Float64(expected[i][2].value), length(expected))
    all(isfinite, vals) || return nothing, :nonfinite_input
    nD, nT, Ti, volume, interval, fraction, auxiliary, loss = vals
    nD >= 0.0 && nT >= 0.0 || return nothing, :negative_fuel_density
    Ti > 0.0 && volume > 0.0 && interval > 0.0 || return nothing, :nonpositive_temperature_volume_or_interval
    0.0 <= fraction <= 1.0 || return nothing, :alpha_deposition_fraction_out_of_range
    auxiliary >= 0.0 && loss >= 0.0 || return nothing, :negative_auxiliary_or_loss_power
    (nD=nD, nT=nT, Ti=Ti, volume=volume, interval=interval,
     alpha_fraction=fraction, auxiliary=auxiliary, loss=loss), nothing
end

function _dt_reactivity_compute(input; allow_frozen_interval_overdraw::Bool=false)
    input isa DTFusionReactivityInputV1 ||
        throw(ArgumentError("D-T provider requires DTFusionReactivityInputV1"))
    values, invalid_reason = _dt_input_values(input)
    invalid_reason === nothing || return _dt_screen_typed_absent(invalid_reason)
    nD, nT, Ti, volume, interval = values.nD, values.nT, values.Ti, values.volume, values.interval
    sv = _dt_bosch_hale_reactivity_m3_s(Ti)
    sv === nothing && return _dt_screen_typed_absent(:Ti_outside_Bosch_Hale_domain;
        detail="Bosch-Hale DT reactivity is defined here only for strict 0.2 < Ti_keV < 100")

    rate_density = nD * nT * sv
    isfinite(rate_density) && rate_density >= 0.0 ||
        return _dt_screen_typed_absent(:reaction_rate_overflow)
    fuel_demand = min(nD, nT) == 0.0 ? 0.0 : rate_density * interval / min(nD, nT)
    (!isfinite(fuel_demand) || (!allow_frozen_interval_overdraw && fuel_demand > 1.0)) &&
        return _dt_screen_typed_absent(:frozen_composition_fuel_demand_exceeds_inventory;
            detail="constant-composition screen would consume more than the lesser declared fuel density")

    mev_j = 1.602176634e-13
    alpha_j = 3.5 * mev_j
    neutron_j = 14.1 * mev_j
    alpha_birth = rate_density * alpha_j
    neutron_birth = rate_density * neutron_j
    fusion_birth = alpha_birth + neutron_birth
    deposited_alpha = values.alpha_fraction * alpha_birth
    net_thermal = deposited_alpha + values.auxiliary - values.loss
    scale = volume * interval
    reactions = rate_density * scale
    alpha_energy = alpha_birth * scale
    neutron_energy = neutron_birth * scale
    fusion_energy = fusion_birth * scale
    deposited_alpha_energy = deposited_alpha * scale
    auxiliary_energy = values.auxiliary * scale
    loss_energy = values.loss * scale
    net_thermal_energy = net_thermal * scale
    all(isfinite, (alpha_birth, neutron_birth, fusion_birth, deposited_alpha,
        net_thermal, reactions, alpha_energy, neutron_energy, fusion_energy,
        deposited_alpha_energy, auxiliary_energy, loss_energy, net_thermal_energy)) ||
        return _dt_screen_typed_absent(:derived_quantity_overflow)

    (status=:screen_only, reason=:explicit_homogeneous_0d_input_evaluated,
     provider_match_status=unique_match, reactivity_m3_s=sv,
     reaction_rate_density_per_m3_s=rate_density, fusion_power_density_W_m3=fusion_birth,
     alpha_birth_power_density_W_m3=alpha_birth,
     neutron_birth_power_density_W_m3=neutron_birth,
     alpha_deposition_fraction=values.alpha_fraction,
     deposited_alpha_power_density_W_m3=deposited_alpha,
     auxiliary_power_density_W_m3=values.auxiliary,
     declared_loss_power_density_W_m3=values.loss,
     net_thermal_source_W_m3=net_thermal,
     reaction_count_over_interval=reactions,
     deuterium_consumption_density_per_m3=rate_density * interval,
     tritium_consumption_density_per_m3=rate_density * interval,
     helium_birth_count_over_interval=reactions,
     neutron_birth_count_over_interval=reactions, alpha_birth_energy_J=alpha_energy,
     neutron_birth_energy_J=neutron_energy, fusion_birth_energy_J=fusion_energy,
     deposited_alpha_energy_J=deposited_alpha_energy,
     auxiliary_energy_J=auxiliary_energy, declared_loss_energy_J=loss_energy,
     net_thermal_source_energy_J=net_thermal_energy,
     fusion_partition_residual_J=fusion_energy-alpha_energy-neutron_energy,
     thermal_account_residual_J=net_thermal_energy-deposited_alpha_energy-auxiliary_energy+loss_energy,
     frozen_composition_fuel_demand_fraction=fuel_demand,
     integration_model=:frozen_composition_exposure,
     source_reference=_DT_REACTIVITY_REFERENCE,
     claim_ceiling=screen_only, candidate_bound=false, physical_evidence=false,
     engineering_evidence=false, terminal_authority=false, whole_device=false,
     assumptions=("homogeneous 0D densities", "equal-temperature Maxwellian D/T",
         "uniform nD and nT frozen over the supplied interval", "Bosch-Hale DT fit, strict 0.2<Ti_keV<100",
         "alpha deposition is the explicitly supplied fraction", "auxiliary heating and loss are uniform declared terms"),
     not_modelled=("spatial plasma profiles", "burn depletion evolution", "transport", "ash and radiation",
         "neutron deposition", "alpha slowing-down", "time-varying state", "whole-device or station balance"),
     inputs=semantic_view(input),
     output_units=(reactivity=_DT_UNIT_REACTIVITY, reaction_rate_density=_DT_UNIT_RATE_DENSITY,
         power_density=_DT_UNIT_POWER_DENSITY, energy=_DT_UNIT_ENERGY_J,
         volume=_DT_UNIT_VOLUME, interval=_DT_UNIT_SECONDS))
end

_dt_reactivity_executor(input) =
    _dt_reactivity_compute(input; allow_frozen_interval_overdraw=false)

function dt_fusion_reactivity_capability_v1()
    _dt_reactivity_capability()
end

function dt_fusion_reactivity_manifest_v1()
    capability = _dt_reactivity_capability()
    ProviderManifestV4(capability.schema, capability.revision, capability.kind,
        capability, (bounds_hash=capability.applicability_bounds,
            model="Bosch-Hale-1992-DT", scope="homogeneous-0D-screen",
            source_reference=_DT_REACTIVITY_REFERENCE),
        "bosch-hale-dt-reactivity", "bosch-hale-1992-fit-v1",
        _dt_reactivity_provider_code_hash(), "bosch-hale-dt-0d-screen", screen_only;
        input_schema_hash=capability.input_schema_hash, executor=_dt_reactivity_executor)
end

"""Resolve the exact D-T provider and execute the declared 0D rate screen.

`nothing` is the honest result for the current candidate until plasma inputs
and source bindings exist. Supplying standalone input does not bind it to a
candidate or make it a plasma-to-thermal-PDE result.
"""
function _dt_execute_with_provider(input; providers=nothing,
        allow_frozen_interval_overdraw::Bool=false)
    input === nothing && return _dt_screen_typed_absent(:plasma_input_not_available)
    input isa DTFusionReactivityInputV1 ||
        throw(ArgumentError("input must be DTFusionReactivityInputV1 or nothing"))
    capability = _dt_reactivity_capability()
    manifests = providers === nothing ? (dt_fusion_reactivity_manifest_v1(),) : providers
    match = match_provider(capability, manifests)
    match.status == unique_match || return _dt_screen_typed_absent(
        :provider_match_not_unique; provider_match_status=match.status, detail=match.reason)
    provider = match.provider
    expected = dt_fusion_reactivity_manifest_v1()
    provider.manifest_hash == expected.manifest_hash && provider.executor === _dt_reactivity_executor ||
        return _dt_screen_typed_absent(:matched_provider_is_not_the_local_bosch_hale_implementation;
            provider_match_status=match.status)
    result = allow_frozen_interval_overdraw ?
        _dt_reactivity_compute(input; allow_frozen_interval_overdraw=true) :
        provider.executor(input)
    merge(result, (provider_match_status=match.status,
        provider_manifest_hash=provider.manifest_hash,
        provider_code_hash=provider.code_hash, provider_backend=provider.backend,
        provider_backend_revision=provider.backend_revision))
end

function evaluate_dt_fusion_reactivity_v1(input; providers=nothing)
    _dt_execute_with_provider(input; providers=providers,
        allow_frozen_interval_overdraw=false)
end

function _dt_final_minority_density_v1(minority::Float64, majority::Float64,
        reactivity_m3_s::Float64, interval_s::Float64)
    minority == 0.0 && return 0.0
    delta = majority - minority
    delta >= 0.0 || return nothing
    if delta == 0.0
        denominator = 1.0 + reactivity_m3_s * minority * interval_s
        return isfinite(denominator) && denominator > 0.0 ? minority / denominator : 0.0
    end
    exponent = log1p(delta / minority) + reactivity_m3_s * delta * interval_s
    !isfinite(exponent) && exponent > 0.0 && return 0.0
    exponent > log(floatmax(Float64)) && return 0.0
    denominator = expm1(exponent)
    isfinite(denominator) && denominator > 0.0 || return nothing
    final_value = delta / denominator
    isfinite(final_value) && 0.0 <= final_value <= minority ? final_value : nothing
end

"""Analytically evolve the D/T composition for an explicit homogeneous 0D interval.

This opt-in consumer holds `Ti` fixed, uses the resolved Bosch–Hale rate
coefficient, and exactly integrates `dnD/dt = dnT/dt = -<sigma v> nD nT`.
It evolves only fuel/product number densities; it does not evolve temperature
or model spatial transport/deposition.
"""
function evolve_dt_fusion_composition_v1(input; providers=nothing)
    base = _dt_execute_with_provider(input; providers=providers,
        allow_frozen_interval_overdraw=true)
    base.status === :screen_only || return base
    values, invalid_reason = _dt_input_values(input)
    invalid_reason === nothing || return _dt_screen_typed_absent(invalid_reason;
        provider_match_status=base.provider_match_status)

    nD0, nT0 = values.nD, values.nT
    sv = base.reactivity_m3_s
    if nD0 <= nT0
        nDminor_final = _dt_final_minority_density_v1(nD0, nT0, sv, values.interval)
        nDminor_final === nothing && return _dt_screen_typed_absent(:composition_integrator_failure;
            provider_match_status=base.provider_match_status)
        extent = nD0 - nDminor_final
        nDfinal = nDminor_final
        nTfinal = nT0 - extent
    else
        nTminor_final = _dt_final_minority_density_v1(nT0, nD0, sv, values.interval)
        nTminor_final === nothing && return _dt_screen_typed_absent(:composition_integrator_failure;
            provider_match_status=base.provider_match_status)
        extent = nT0 - nTminor_final
        nTfinal = nTminor_final
        nDfinal = nD0 - extent
    end
    all(isfinite, (extent, nDfinal, nTfinal)) &&
        0.0 <= extent <= min(nD0, nT0) && nDfinal >= 0.0 && nTfinal >= 0.0 ||
        return _dt_screen_typed_absent(:composition_integrator_out_of_bounds;
            provider_match_status=base.provider_match_status)

    mev_j = 1.602176634e-13
    alpha_j = 3.5 * mev_j
    neutron_j = 14.1 * mev_j
    alpha_birth_energy_density = extent * alpha_j
    neutron_birth_energy_density = extent * neutron_j
    fusion_birth_energy_density = alpha_birth_energy_density + neutron_birth_energy_density
    deposited_alpha_energy_density = values.alpha_fraction * alpha_birth_energy_density
    auxiliary_energy_density = values.auxiliary * values.interval
    loss_energy_density = values.loss * values.interval
    net_thermal_energy_density = deposited_alpha_energy_density + auxiliary_energy_density - loss_energy_density
    volume = values.volume
    all(isfinite, (alpha_birth_energy_density, neutron_birth_energy_density,
        fusion_birth_energy_density, deposited_alpha_energy_density, auxiliary_energy_density,
        loss_energy_density, net_thermal_energy_density)) ||
        return _dt_screen_typed_absent(:composition_energy_overflow;
            provider_match_status=base.provider_match_status)

    extent_count = extent * volume
    d_consumed_count = (nD0 - nDfinal) * volume
    t_consumed_count = (nT0 - nTfinal) * volume
    alpha_count = extent_count
    neutron_count = extent_count
    fusion_energy = fusion_birth_energy_density * volume
    alpha_energy = alpha_birth_energy_density * volume
    neutron_energy = neutron_birth_energy_density * volume
    deposited_alpha_energy = deposited_alpha_energy_density * volume
    auxiliary_energy = auxiliary_energy_density * volume
    loss_energy = loss_energy_density * volume
    net_thermal_energy = net_thermal_energy_density * volume
    all(isfinite, (extent_count, d_consumed_count, t_consumed_count, alpha_count,
        neutron_count, fusion_energy, alpha_energy, neutron_energy, deposited_alpha_energy,
        auxiliary_energy, loss_energy, net_thermal_energy)) ||
        return _dt_screen_typed_absent(:composition_integrated_quantity_overflow;
            provider_match_status=base.provider_match_status)

    (status=:screen_only, reason=:explicit_homogeneous_0d_composition_evolved,
     provider_match_status=base.provider_match_status,
     provider_manifest_hash=base.provider_manifest_hash,
     provider_code_hash=base.provider_code_hash,
     provider_backend=base.provider_backend,
     provider_backend_revision=base.provider_backend_revision,
     integration_model=:analytic_composition_evolution,
     initial_nD_m3=nD0, initial_nT_m3=nT0,
     final_nD_m3=nDfinal, final_nT_m3=nTfinal,
     reaction_extent_per_m3=extent,
     fusion_reaction_count=extent_count,
     deuterium_consumed_count=d_consumed_count,
     tritium_consumed_count=t_consumed_count,
     helium4_birth_count=alpha_count, neutron_birth_count=neutron_count,
     fixed_Ti_keV=values.Ti,
     frozen_temperature_reactivity_m3_s=sv,
     initial_reaction_rate_density_per_m3_s=nD0*nT0*sv,
     final_fuel_demand_fraction=min(nD0, nT0) == 0.0 ? 0.0 : extent / min(nD0, nT0),
     fusion_birth_energy_density_J_m3=fusion_birth_energy_density,
     alpha_birth_energy_density_J_m3=alpha_birth_energy_density,
     neutron_birth_energy_density_J_m3=neutron_birth_energy_density,
     deposited_alpha_energy_density_J_m3=deposited_alpha_energy_density,
     auxiliary_energy_density_J_m3=auxiliary_energy_density,
     declared_loss_energy_density_J_m3=loss_energy_density,
     net_thermal_source_energy_density_J_m3=net_thermal_energy_density,
     fusion_birth_energy_J=fusion_energy,
     alpha_birth_energy_J=alpha_energy,
     neutron_birth_energy_J=neutron_energy,
     deposited_alpha_energy_J=deposited_alpha_energy,
     auxiliary_energy_J=auxiliary_energy,
     declared_loss_energy_J=loss_energy,
     net_thermal_source_energy_J=net_thermal_energy,
     deuterium_particle_balance_residual_per_m3=nD0-nDfinal-extent,
     tritium_particle_balance_residual_per_m3=nT0-nTfinal-extent,
     helium_particle_balance_residual_per_m3=alpha_count/volume-extent,
     neutron_particle_balance_residual_per_m3=neutron_count/volume-extent,
     nucleon_inventory_balance_residual_per_m3=2.0*(nD0-nDfinal)+3.0*(nT0-nTfinal)-
         4.0*(alpha_count/volume)-(neutron_count/volume),
     fusion_energy_partition_residual_J=fusion_energy-alpha_energy-neutron_energy,
     thermal_energy_account_residual_J=net_thermal_energy-deposited_alpha_energy-auxiliary_energy+loss_energy,
     source_reference=_DT_REACTIVITY_REFERENCE,
     claim_ceiling=screen_only, candidate_bound=false, physical_evidence=false,
     engineering_evidence=false, terminal_authority=false, whole_device=false,
     assumptions=("homogeneous 0D nD/nT", "equal-temperature Maxwellian D/T rate at fixed supplied Ti",
         "constant-volume isothermal composition interval", "uniform constant alpha deposition fraction",
         "uniform declared auxiliary and loss powers integrated over the interval"),
     not_modelled=("temperature/energy-state evolution", "spatial profiles or transport", "ash/radiation",
         "neutron deposition", "alpha slowing-down", "external particle sources", "whole-device or station balance"),
     input=semantic_view(input),
     output_units=(density=_DT_UNIT_DENSITY, extent=_DT_UNIT_DENSITY,
         reactivity=_DT_UNIT_REACTIVITY, fusion_energy_density=_DT_UNIT_ENERGY_DENSITY,
         energy=_DT_UNIT_ENERGY_J, volume=_DT_UNIT_VOLUME,
         reaction_count=_DT_UNIT_ONE, interval=_DT_UNIT_SECONDS))
end
