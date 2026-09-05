"""Frozen campaign wrapper used by the spine CLI."""

struct FrozenCampaignV4
    stage_specs::Tuple{Vararg{StageSpecV4}}
    scenario_scope::Tuple
    campaign_hash::Digest256
end

"""Return the complete declared S0--S10 ladder for the bounded CLI fixture.

The single supplied signature is structural-screen only; higher required
ceilings therefore remain explicit evidence gaps until their typed providers
exist.  No physical operator is invented by this manifest.
"""
function default_stage_specs(signature::CapabilitySignatureV4, scenario::AbstractString)
    names = (:s0_compiled_materialized, :s1_analytic_certified_bounds,
        :s2_field_source_realization, :s3_trajectory_or_loss,
        :s4_finite_pressure_equilibrium, :s5_applicable_stability,
        :s6_transport_reaction_power, :s7_engineering_control_scenarios,
        :s8_integrated_high_fidelity_numerical_vvuq, :s9_independent_cross_code,
        :s10_validation_vvuq)
    ceilings = (screen_only, screen_only, candidate_bound, candidate_bound,
        candidate_bound, candidate_bound, candidate_bound, whole_device_vvuq,
        whole_device_vvuq, whole_device_vvuq, validation_vvuq)
    reqs = Tuple(i == 1 ? ExactCapabilityRequirementV4(signature) :
        UnresolvedStageDeclarationV4(name,
            (:operator, :states, :source_space, :target_space, :coordinates,
             :boundary_relation, :interface_relation, :time_semantics, :scenario_scope),
            canonical_hash((stage=name, scenario=String(scenario))), ceilings[i])
        for (i, name) in enumerate(names))
    Tuple(StageSpecV4(name, (reqs[i],), i == 1 ? () : (names[i - 1],),
        i == 1 ? (String(scenario),) : (), ceilings[i]) for (i, name) in enumerate(names))
end

function freeze_campaign(specs, scenarios)
    ss = Tuple(specs)
    all(s -> s isa StageSpecV4, ss) || throw(ArgumentError("campaign stages must be StageSpecV4"))
    isempty(ss) && throw(ArgumentError("campaign requires at least one stage"))
    stages = Tuple(s.stage for s in ss)
    length(unique(stages)) == length(stages) || throw(ArgumentError("campaign stages must be unique"))
    all(!isempty(s.prerequisites) ? all(p -> p in stages, s.prerequisites) : true for s in ss) ||
        throw(ArgumentError("campaign prerequisite references unknown stage"))
    for (i, spec) in enumerate(ss), prerequisite in spec.prerequisites
        findfirst(==(prerequisite), stages) < i || throw(ArgumentError("campaign prerequisites must point to earlier stages"))
    end
    xs = _stage_named_scenarios(scenarios)
    isempty(xs) && throw(ArgumentError("campaign scenario scope cannot be empty"))
    is_canonical_value(xs) || throw(ArgumentError("campaign scenarios must be canonicalizable"))
    names = Set(String(getfield(x, :name)) for x in xs)
    all(all(scenario in names for scenario in spec.scenario_scope) for spec in ss) ||
        throw(ArgumentError("stage scenario scope is outside campaign scenarios"))
    FrozenCampaignV4(ss, xs, canonical_hash((stage_specs=ss, scenarios=xs)))
end

struct SpineReportV4
    campaign::FrozenCampaignV4
    compiled::CompiledCandidatePrefixV4
    p1::VerticalSliceReportV4
    admission::WholeDeviceClosureV4
    closure::WholeDeviceClosureV4
    authority::AuthorityClassificationV4
end

function run_v4_spine(candidate::CandidateStatePackageV4, registry::GenomeContractRegistryV4;
                       stage_specs, scenarios, providers=(), bindings=(candidate="candidate",),
                       mission_payload=candidate.mission_contract_ref,
                       bounds_payload=(scope="runtime-v4-spine-bounds",),
                       compiled_prefix=nothing)
    campaign = freeze_campaign(stage_specs, scenarios)
    compiled = compiled_prefix === nothing ? compile_candidate(candidate, registry; mission_payload=mission_payload,
        bounds_payload=bounds_payload, comparison_scope=("runtime-v4-spine",),
        scenario_scope=Tuple(String(getfield(s, :name)) for s in campaign.scenario_scope)) : compiled_prefix
    p1 = run_v4_vertical_slice(candidate, registry; mission_payload=mission_payload,
        bounds_payload=bounds_payload, providers=providers, bindings=bindings,
        scenarios=campaign.scenario_scope, comparison_scope=("runtime-v4-spine",),
        scenario_scope=Tuple(String(getfield(s, :name)) for s in campaign.scenario_scope),
        compiled_prefix=compiled)
    p1.compiled.prefix_hash == compiled.prefix_hash || throw(ArgumentError("spine compilation hash mismatch"))
    admission = admit_whole_device(campaign.stage_specs, p1.subject; providers=providers,
        scenarios=campaign.scenario_scope, hard_gates=(), protocol_ready=false,
        resources_ready=false)
    closure = audit_whole_device(admission, campaign.stage_specs, campaign.scenario_scope;
        providers=providers)
    SpineReportV4(campaign, compiled, p1, admission, closure, classify_authority(closure))
end
