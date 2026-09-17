using Test
using JSON3
using Serialization

const G = FusionConceptAI
const _N03_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n03_time_authority_fixtures.json"), String))

module N03G1Fixture
using Test
using JSON3
using FusionConceptAI
include(joinpath(@__DIR__, "..", "G1", "up1_g1_contract_tests.jl"))
end
module N03G2Fixture
using Test
using JSON3
using FusionConceptAI
include(joinpath(@__DIR__, "..", "G2", "up1_g2_contract_tests.jl"))
end
module N03G3Fixture
using Test
using JSON3
using FusionConceptAI
include(joinpath(@__DIR__, "..", "G3", "up1_g3_contract_tests.jl"))
end

function _n03_actual_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(uri, old.version, old.schema_hash, old.canonicalization_hash,
        old.compatibility_profile, old.version_axes, candidate.id;
        grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states, base.payload.equation_plan,
        base.payload.grammar_profile)
    G.MechanismGenomeV5(G.g1_materialize_contract_ref(ref, base.payload.grammar_profile), payload, base.version_axes)
end

function _n03_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan, base.grammar_profile, base.version_axes)
end

function _n03_actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref, candidate,
        base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref, candidate,
        base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref, candidate,
        base.binding.contract_binding.version_axes)
    bundle_binding = G.G3ContractBindingV2(base.contract_binding.contract_ref, candidate,
        base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network, base.realization.material_domains,
        base.realization.manufacturing_domains; provider_match=base.realization.provider_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=base.control.provider_match)
    feedback = Tuple(G.G3FeedbackChannelV2(ch.feedback_id, ch.target_layer,
        ch.target_layer === :G1 ? g1_ref : g2_ref, ch.channel, ch.unit, ch.kind, ch.source_id)
        for ch in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle_binding, realization, control, binding)
end

function _n03_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/n03-time-authority", "v5")
    g1 = _n03_actual_g1(N03G1Fixture._g1_fixture()[1], candidate)
    g2 = _n03_actual_g2(N03G2Fixture._g2_build("split_x_1")[1], candidate)
    g3base = N03G3Fixture._make_fixture()
    g3 = _n03_actual_g3(g3base, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n03_value(row)
    id = String(row.id)
    id == "N03-01-local-equation-kind" && return G.discrete_time
    id == "N03-02-local-derivative-bound" && return 1
    id == "N03-03-local-operator-kind" && return (G.discrete_time,)
    id == "N03-04-cross-layer-policy-gap" && return :scheduled
    id == "N03-05-local-event-time" && return -1 // 1
    throw(ArgumentError("unknown N03 fixture row"))
end

function _n03_specs()
    Tuple(G.N03TimeMutationSpecV1(String(row.id), String(row.field_path), String(row.source_locator),
        Symbol(String(row.mutation_kind)), _n03_value(row), Symbol(String(row.expected_error)),
        Symbol(String(row.expected_resolution)), Int(row.expected_compile_calls),
        Int(row.expected_provider_calls), Int(row.expected_solver_calls)) for row in _N03_FIXTURE.mutations)
end

@testset "UP2-00D N03 fixture and provisional protocol rows" begin
    @test String(_N03_FIXTURE.fixture_id) == "UP2-00D-N03-time-authority-001"
    @test String(_N03_FIXTURE.schema_id) == "GenomeV5/UP2/N03TimeAuthorityProjectionV1"
    @test String(_N03_FIXTURE.schema_version) == "v1"
    @test Bool(_N03_FIXTURE.schema_validation_only)
    @test !Bool(_N03_FIXTURE.provider_resolution_executed)
    @test Int(_N03_FIXTURE.mutation_count) == 5
    @test length(_N03_FIXTURE.provisional_rows) == 5
    @test length(_n03_specs()) == 5
end

@testset "UP2-00D N03 projects five actual candidate-bound fields" begin
    package = _n03_actual_package()
    projection = G.n03_time_authority_projection(package)
    @test G.n03_projection_complete(projection)
    @test length(projection.declarations) == 5
    @test projection.candidate_ref == package.candidate_ref
    @test projection.package_hash == package.candidate_hash
    @test "missing_candidate_bound_g3_event_time_basis_policy" in projection.gaps
    @test all(x -> x.candidate_ref == package.candidate_ref && x.genome_ref.version == "v5",
        projection.declarations)
    @test projection.declarations[1].source_type == "TimeKindV1"
    @test projection.declarations[4].authority_scope == :cross_layer
    @test projection.declarations[5].authority_scope == :cross_layer
end

@testset "UP2-00D N03 mutations are fixture-driven and fail closed or defer" begin
    package = _n03_actual_package()
    projection = G.n03_time_authority_projection(package)
    specs = _n03_specs()
    for (row, spec) in zip(_N03_FIXTURE.mutations, specs)
        @test String(row.expected_error) == "invalid_type"  # frozen protocol metadata, never a routing input
        @test Bool(row.evidence_reused) == false
        result = G.n03_validate_mutation(projection, spec; counter=G.UP2InvocationCounterV1())
        @test String(result.error_code) == String(row.expected_actual_error)
        @test String(result.status) == String(row.expected_resolution)
        @test result.resolution == G.terminal_deferred
        @test result.error_path == spec.field_path
        @test result.input_hash == projection.projection_hash
        @test result.mutated_projection_hash != result.input_hash
        @test result.candidate_ref == package.candidate_ref
        @test result.compile_calls == 0 && result.provider_calls == 0 && result.solver_calls == 0
    end
end

@testset "UP2-00D N03 rejects forged metadata or execution counters" begin
    package = _n03_actual_package()
    projection = G.n03_time_authority_projection(package)
    valid = first(_n03_specs())
    wrong = G.N03TimeMutationSpecV1(valid.id, "/not/authoritative", valid.source_locator,
        valid.mutation_kind, valid.mutated_value, valid.expected_error, valid.expected_resolution, 0, 0, 0)
    @test_throws ArgumentError G.n03_validate_mutation(projection, wrong)
    dirty = G.UP2InvocationCounterV1()
    dirty.provider_calls = 1
    @test_throws ArgumentError G.n03_validate_mutation(projection, valid; counter=dirty)
end
