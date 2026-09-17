using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _N04_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n04_ledger_authority_fixtures.json"), String))

function _n04_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n04_actual_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(uri, old.version, old.schema_hash,
        old.canonicalization_hash, old.compatibility_profile, old.version_axes,
        candidate.id; grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    G.MechanismGenomeV5(G.g1_materialize_contract_ref(ref, base.payload.grammar_profile),
        payload, base.version_axes)
end

function _n04_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _n04_actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle = G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(x.feedback_id, x.target_layer,
        x.target_layer === :G1 ? g1_ref : g2_ref, x.channel, x.unit, x.kind,
        x.source_id) for x in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle, realization, control, binding)
end

function _n04_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v5")
    g1 = _n04_actual_g1(_n04_child_fixture("G1"), candidate)
    g2 = _n04_actual_g2(_n04_child_fixture("G2"), candidate)
    base_g3 = _n04_child_fixture("G3")
    g3 = _n04_actual_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n04_specs()
    Tuple(G.N04MutationSpecV1(String(x.id), Symbol(String(x.class_id)),
        String(x.field_path), String(x.source_locator), Symbol(String(x.source_type)),
        Symbol(String(x.mutation_kind)), Symbol(String(x.expected_error)))
        for x in _N04_FIXTURE.mutations)
end

@testset "UP2-00D N04 actual A ledger projection" begin
    @test String(_N04_FIXTURE.schema_id) == "GenomeV5/UP2/N04LedgerAuthorityProjectionV1"
    @test String(_N04_FIXTURE.version) == "v1"
    @test Bool(_N04_FIXTURE.schema_validation_only)
    @test length(_N04_FIXTURE.mutations) == 5
    package = _n04_actual_package()
    projection = G.n04_projection_from_a(package)
    @test package isa G.CandidateStatePackageV5
    @test projection.candidate_ref == package.candidate_ref
    @test projection.package_hash == package.candidate_hash
    @test length(projection.g1_occurrences) > 0
    @test length(projection.network.accounts) >= Int(_N04_FIXTURE.expected_actual_fixture_shape.accounts_at_least)
    @test length(projection.network.entries) >= Int(_N04_FIXTURE.expected_actual_fixture_shape.entries_at_least)
    @test length(projection.network.closures) >= Int(_N04_FIXTURE.expected_actual_fixture_shape.closures_at_least)
    @test isempty(G.g3_validate_resource_network(projection.network))
    @test "g1_occurrence_to_g3_account_exact_join_missing" in projection.authority_gaps
    @test "owner_uniqueness_scope_missing_shared_owner_is_legal" in projection.authority_gaps
    @test projection.g1_schema_hash == package.g1.contract_ref.schema_hash
    @test projection.g3_schema_hash == package.g3.contract_binding.contract_ref.schema_hash

    for row in _N04_FIXTURE.mutations
        spec = first(x for x in _n04_specs() if x.id == String(row.id))
        result = G.n04_validate_mutation(projection, spec)
        @test result.mutated_input_hash != result.input_hash
        @test result.error_path == spec.field_path
        @test result.status == Symbol(String(row.expected_status))
        @test result.error_code == Symbol(String(row.expected_status) == "terminal_deferred" ? "terminal_deferred" : String(row.expected_error))
        @test result.compile_calls == result.provider_calls == result.solver_calls == 0
        @test result.original_value != result.mutated_value
    end
end

@testset "UP2-00D N04 owner boundary and independent classification" begin
    package = _n04_actual_package()
    projection = G.n04_projection_from_a(package)
    owner_spec = first(x for x in _n04_specs() if x.id == "N04-01")
    owner_result = G.n04_validate_mutation(projection, owner_spec)
    @test owner_result.status == :terminal_deferred
    @test owner_result.error_code == :terminal_deferred
    @test owner_result.gap == "owner_uniqueness_scope_missing_shared_owner_is_legal"

    local_spec = first(x for x in _n04_specs() if x.id == "N04-02")
    forged_oracle = G.N04MutationSpecV1(local_spec.id, local_spec.class_id,
        local_spec.field_path, local_spec.source_locator, local_spec.source_type,
        local_spec.mutation_kind, :terminal_deferred)
    @test G.n04_validate_mutation(projection, forged_oracle).error_code == :invalid_closure
end
