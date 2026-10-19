using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "SearchPhysicalConsumerV4",
    "search_physical_consumer_fixture_v4.jl"))

const F_G2OBS = SearchPhysicalConsumerV4TestRuntime
const R_G2OBS = F_G2OBS.R
const G2OBS_ROOT = normpath(abspath(joinpath(@__DIR__, "..", "..", "..")))

# Load the renamed compatibility copy in its own namespace. It is not added to
# FusionRuntimeV4.jl and it does not alter the frozen V1/V3 files.
Base.include(R_G2OBS, joinpath(G2OBS_ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV1Compat.jl"))
Base.include(R_G2OBS, joinpath(G2OBS_ROOT, "src", "RuntimeV4",
    "CandidateBoundG2ScreenObservationV1.jl"))

const G2OBS = R_G2OBS.CandidateBoundG2ScreenObservationV1

function _g2obs_single_scenario_fixture(index::Int=1; foreign_g3=false)
    base = F_G2OBS.search_physical_fixture_v4(foreign_g3=foreign_g3)
    scenario = base.scenarios[index]
    scenarios = (scenario,)
    scenario_scope = (scenario.name,)
    compiled = R_G2OBS.compile_candidate(base.candidate, F_G2OBS.registry;
        mission_payload=base.mission_payload,
        bounds_payload=base.bounds_payload,
        comparison_scope=base.comparison_scope,
        scenario_scope=scenario_scope)
    binding = R_G2OBS.make_axisymmetric_equilibrium_binding(compiled,
        F_G2OBS.registry, base.mission_payload, base.bounds_payload,
        base.comparison_scope, scenario_scope, scenario, base.declaration)
    subject = R_G2OBS.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        base.candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, (binding,), scenarios,
        (fixture_scope=:g2_axisymmetric_consumer_single_scenario_test_only,
         declaration_hash=canonical_hash(base.declaration)),
        R_G2OBS.derive_capability_obligations(compiled))
    contexts = R_G2OBS.make_forward_chain_contexts(base.candidate, compiled,
        F_G2OBS.registry, base.mission_payload, base.bounds_payload,
        base.comparison_scope, scenario_scope, subject, scenarios)
    (; candidate=base.candidate, g1_payload=base.g1_payload, compiled,
       declaration=base.declaration, scenarios, mission_payload=base.mission_payload,
       bounds_payload=base.bounds_payload, comparison_scope=base.comparison_scope,
       scenario_scope, subject, contexts)
end

function _g2obs_empty_trusted_registry()
    R_G2OBS.bootstrap_trusted_provider_registry(
        Val(:trusted_repository_with_freegs_bootstrap),
        F_G2OBS.TRUSTED_REPOSITORY_ROOT)
end

function _g2obs_replace_field(record, field::Symbol, replacement)
    names = fieldnames(typeof(record))
    position = findfirst(==(field), names)
    position === nothing && throw(ArgumentError("unknown observation field"))
    values = Any[getfield(record, i) for i in 1:fieldcount(typeof(record))]
    values[position] = replacement
    typeof(record)(values...)
end

@testset "G2 observation defers without a context registration" begin
    fixture = _g2obs_single_scenario_fixture()
    context = fixture.contexts[1]
    registry = _g2obs_empty_trusted_registry()
    record = G2OBS.observe_candidate_bound_g2_screen_v1(context, registry)

    @test record.status === :deferred
    @test record.failure_code === :provider_registration_unavailable
    @test !record.execution_started
    @test record.request !== nothing
    @test record.request.status === :recoverable_gap
    @test record.receipt === nothing
    @test record.provider_descriptor_hash !== nothing
    @test record.provider_source_hash !== nothing
    @test record.provider_runtime_hash !== nothing
    @test record.provider_manifest_hash === nothing
    @test length(record.unresolved_g1_identity_hashes) == 2
    @test G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        record, context, registry)
    @test !record.search_activation
    @test !record.physical_validation && !record.engineering_validation
    @test record.candidate_discovery_credit == 0
    @test record.credible_device_count == 0
end

@testset "G2 observation does not reuse a registration across scenarios" begin
    fixture_a = _g2obs_single_scenario_fixture(1)
    fixture_b = _g2obs_single_scenario_fixture(2)
    context_a = only(fixture_a.contexts)
    context_b = only(fixture_b.contexts)
    registry_a = F_G2OBS.trusted_registry_v4(context_a)
    record_b = G2OBS.observe_candidate_bound_g2_screen_v1(context_b, registry_a)

    @test record_b.status === :deferred
    @test record_b.failure_code === :provider_registration_unavailable
    @test !record_b.execution_started
    @test record_b.request !== nothing
    @test record_b.request.status === :recoverable_gap
    @test record_b.receipt === nothing
    @test G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        record_b, context_b, registry_a)
    @test !G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        record_b, context_a, registry_a)

    foreign_fixture = _g2obs_single_scenario_fixture(1; foreign_g3=true)
    foreign_context = only(foreign_fixture.contexts)
    foreign_record = G2OBS.observe_candidate_bound_g2_screen_v1(
        foreign_context, registry_a)
    @test foreign_record.status === :deferred
    @test !foreign_record.execution_started
    @test !G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        foreign_record, context_a, registry_a)

    # The public API has no receipt/capability/request injection overload.
    @test !applicable(G2OBS.observe_candidate_bound_g2_screen_v1,
        context_b, registry_a, record_b.capability)
    @test !applicable(G2OBS.observe_candidate_bound_g2_screen_v1,
        context_b, registry_a, record_b.receipt)
end

@testset "real TPR call returns a separate G2 observation only" begin
    fixture = _g2obs_single_scenario_fixture()
    @test fixture.compiled.compilation_status === :prefix_incomplete
    @test fixture.compiled.unresolved_nonterminals ==
        ("required_physical_capability:IDENTITY@v1",)
    context = only(fixture.contexts)
    registry = F_G2OBS.trusted_registry_v4(context)
    record = G2OBS.observe_candidate_bound_g2_screen_v1(context, registry)

    typed_obligations = R_G2OBS.PhysicalEdgeObligationV1Compat.
        physical_edge_obligations_v1(context)
    g1 = Tuple(x for x in typed_obligations if x.identity.layer === :g1_mechanism)
    @test length(g1) == 2
    @test all(x -> x.identity.operator_id == "IDENTITY" &&
        x.identity.operator_version == "v1" &&
        x.provider.receipt_state === :missing, g1)
    @test record.unresolved_g1_identity_hashes ==
        Tuple(x.identity.identity_hash for x in g1)
    @test record.unresolved_obligation_hashes ==
        Tuple(canonical_hash(x) for x in typed_obligations)

    # The single screen observation is produced by the repository-owned TPR
    # execution path. Its status can be a screen, typed provider failure, or
    # deferred solver result; none discharges any graph edge.
    @test record.request !== nothing
    @test record.receipt !== nothing
    @test record.execution_started
    @test record.provider_manifest_hash ==
        record.request.registration.manifest.manifest_hash
    descriptor = only(x for x in registry.descriptors
        if :axisymmetric_equilibrium_screen in x.allowed_capability_kinds)
    @test record.provider_descriptor_hash == descriptor.descriptor_hash
    @test record.provider_source_hash == descriptor.source_hash
    @test record.provider_runtime_hash == descriptor.runtime_hash
    @test record.provider_attested_source_paths == descriptor.attested_source_paths
    @test record.provider_attested_source_hashes == descriptor.attested_source_hashes
    @test record.receipt_hash == record.receipt.receipt_hash
    @test record.output_hash == record.receipt.output_hash
    @test record.status in (:screen_only, :deferred, :program_exception)
    @test G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        record, context, registry)

    @test !record.search_activation
    @test !record.physical_validation && !record.engineering_validation
    @test record.candidate_discovery_credit == 0
    @test record.credible_device_count == 0
    if record.status === :screen_only
        @test record.provider_status === :physical_model_screen
        @test record.exit_code == 0
        @test record.claim_ceiling === screen_only
    end

    # Cloning loses the process-local issuance ticket. Replacing the raw
    # registry receipt without recomputing a direct TPR call also fails closed.
    clone = deepcopy(record)
    @test clone._ticket !== record._ticket
    @test !G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        clone, context, registry)
    forged = _g2obs_replace_field(record, :receipt, nothing)
    @test !G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        forged, context, registry)
    @test !G2OBS.validate_candidate_bound_g2_screen_observation_v1(
        record, context, _g2obs_empty_trusted_registry())
end
