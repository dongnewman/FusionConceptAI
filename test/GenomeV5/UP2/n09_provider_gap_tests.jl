using Test
using JSON3
using Serialization

const G = FusionConceptAI
const _N09_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n09_provider_gap_fixtures.json"), String))

function _n09_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n09_actual_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(uri, old.version, old.schema_hash, old.canonicalization_hash,
        old.compatibility_profile, old.version_axes, candidate.id;
        grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    G.MechanismGenomeV5(G.g1_materialize_contract_ref(ref, base.payload.grammar_profile),
        payload, base.version_axes)
end

function _n09_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _n09_actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle_binding = G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=base.realization.provider_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=base.control.provider_match)
    feedback = Tuple(G.G3FeedbackChannelV2(ch.feedback_id, ch.target_layer,
        ch.target_layer === :G1 ? g1_ref : g2_ref, ch.channel, ch.unit, ch.kind,
        ch.source_id) for ch in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle_binding, realization, control, binding)
end

function _n09_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/n09-provider-gap", "v5")
    g1 = _n09_actual_g1(_n09_child_fixture("G1"), candidate)
    g2 = _n09_actual_g2(_n09_child_fixture("G2"), candidate)
    g3base = _n09_child_fixture("G3")
    g3 = _n09_actual_g3(g3base, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n09_specs()
    Tuple(G.N09ProviderMutationSpecV1(String(row.id), String(row.field_path),
        String(row.source_locator), Symbol(String(row.baseline_provider_match)),
        Symbol(String(row.mutated_provider_match)),
        Symbol(String(row.expected_error)), Symbol(String(row.expected_resolution)),
        Int(row.expected_provider_calls)) for row in _N09_FIXTURE.mutations)
end

@testset "UP2-00C N09 fixture is schema-bound" begin
    @test String(_N09_FIXTURE.fixture_id) == "UP2-00C-N09-provider-gap-001"
    @test String(_N09_FIXTURE.schema_id) == "GenomeV5/UP2/N09ProviderGapProjectionV1"
    @test String(_N09_FIXTURE.schema_version) == "v1"
    @test Bool(_N09_FIXTURE.schema_validation_only)
    @test !Bool(_N09_FIXTURE.provider_resolution_executed)
    @test Int(_N09_FIXTURE.mutation_count) == 11
    @test length(_n09_specs()) == 11
end

@testset "UP2-00C N09 projects five actual declarations" begin
    package = _n09_actual_package()
    projection = G.n09_provider_gap_projection(package)
    @test G.n09_projection_complete(projection)
    @test length(projection.declarations) == 5
    @test projection.candidate_ref == package.candidate_ref
    @test projection.package_hash == package.candidate_hash
    refs = Dict(
        :g1_operator => package.g1.contract_ref,
        :g2_grammar => package.g2.contract_ref,
        :g2_exterior => package.g2.contract_ref,
        :g3_realization => package.g3.realization.contract_binding.contract_ref,
        :g3_control => package.g3.control.contract_binding.contract_ref)
    hashes = Dict(
        :g1_operator => package.g1.candidate_hash,
        :g2_grammar => package.g2.candidate_hash,
        :g2_exterior => package.g2.candidate_hash,
        :g3_realization => package.g3.realization.candidate_hash,
        :g3_control => package.g3.control.candidate_hash)
    for declaration in projection.declarations
        @test declaration.candidate_ref == package.candidate_ref
        @test declaration.genome_ref == refs[declaration.layer]
        @test declaration.component_hash == hashes[declaration.layer]
        @test declaration.provider_match in (:unique_match, :no_match, :ambiguous,
                                             :out_of_domain, :invalid_signature)
    end
end

@testset "UP2-00C N09 mutations are fixture-driven provider gaps" begin
    package = _n09_actual_package()
    projection = G.n09_provider_gap_projection(package)
    specs = _n09_specs()
    @test Set(Symbol(String(row.mutated_provider_match)) for row in _N09_FIXTURE.mutations) ==
        Set((:no_match, :out_of_domain, :invalid_signature))
    for (row, spec) in zip(_N09_FIXTURE.mutations, specs)
        declaration = only(filter(x -> x.field_path == spec.field_path, projection.declarations))
        @test declaration.source_locator == spec.source_locator
        counter = G.UP2InvocationCounterV1()
        result = G.n09_validate_mutation(projection, spec; counter=counter)
        @test result.mutation_id == spec.id
        @test result.input_hash == projection.projection_hash
        @test result.mutated_projection_hash != result.input_hash
        @test result.status == :terminal_deferred
        @test result.resolution == :terminal_deferred
        @test result.error_code == spec.expected_error
        @test result.error_path == spec.field_path
        @test result.detail == "provider_capability_gap:" * String(spec.mutated_provider_match)
        @test result.compile_calls == Int(row.expected_compile_calls) == 0
        @test result.provider_calls == Int(row.expected_provider_calls) == 0
        @test result.solver_calls == Int(row.expected_solver_calls) == 0
        @test result.evidence_reused == Bool(row.evidence_reused)
    end
end

@testset "UP2-00C N09 rejects non-authoritative mutation metadata" begin
    package = _n09_actual_package()
    projection = G.n09_provider_gap_projection(package)
    valid = first(_n09_specs())
    wrong_path = G.N09ProviderMutationSpecV1(valid.id, "/not/a/provider/path",
        valid.source_locator, valid.baseline_provider_match,
        valid.mutated_provider_match, :provider_match,
        :terminal_deferred, 0)
    @test_throws ArgumentError G.n09_validate_mutation(projection, wrong_path)
    dirty_counter = G.UP2InvocationCounterV1()
    dirty_counter.provider_calls = 1
    @test_throws ArgumentError G.n09_validate_mutation(projection, valid; counter=dirty_counter)
end
