using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _N10_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n10_identity_receipt_fixtures.json"), String))

function _n10_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n10_g1(base, candidate)
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

function _n10_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _n10_g3(base, candidate, g1_ref, g2_ref)
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

function _n10_actual_package(candidate_id="fusionconceptai://candidate/candidate-1")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    g1 = _n10_g1(_n10_child_fixture("G1"), candidate)
    g2 = _n10_g2(_n10_child_fixture("G2"), candidate)
    base_g3 = _n10_child_fixture("G3")
    g3 = _n10_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n10_specs()
    Tuple(G.N10MutationSpecV1(String(x.id), String(x.field_path), String(x.source_locator),
        Symbol(String(x.source_type)), Symbol(String(x.mutation_kind)), Symbol(String(x.expected_error)),
        Symbol(String(x.expected_resolution)), Int(x.expected_compile_calls),
        Int(x.expected_provider_calls), Int(x.expected_solver_calls)) for x in _N10_FIXTURE.mutations)
end

@testset "UP2-00C N10 actual A identity and receipt projection" begin
    @test String(_N10_FIXTURE.schema_id) == "GenomeV5/UP2/N10IdentityReceiptProjectionV1"
    @test String(_N10_FIXTURE.schema_version) == "v1"
    @test Bool(_N10_FIXTURE.schema_validation_only)
    @test length(_N10_FIXTURE.mutations) == 5
    package = _n10_actual_package()
    @test package.candidate_hash.value == String(_N10_FIXTURE.expected_package_hash)
    @test package.migration_receipt.candidate_identity_after == String(_N10_FIXTURE.expected_receipt_after)
    projection = G.n10_identity_projection_from_a(package)
    @test projection.package_hash == package.candidate_hash
    @test length(projection.fields) == 5
    @test "legacy_v4_receipt_provenance_absent_terminal_deferred" in projection.gaps
    @test projection.g3_child_refs.control == package.g3.control.contract_binding.contract_ref
    @test first(x for x in projection.fields if x.id == "N10-04").source_ref == package.candidate_ref
    @test first(x for x in projection.fields if x.id == "N10-05").source_ref == package.candidate_ref
    @test G.n10_schema_hash() isa G.Digest256
    @test G.n10_canonicalization_hash() isa G.Digest256

    for row in _N10_FIXTURE.mutations
        spec = first(s for s in _n10_specs() if s.id == String(row.id))
        result = G.n10_validate_mutation(projection, spec)
        @test result.baseline_package_hash == package.candidate_hash
        @test result.input_hash == projection.projection_hash
        @test result.mutated_input_hash != result.input_hash
        @test result.original_value != result.mutated_value
        @test result.status == :fail_closed
        @test result.resolution == :fail_closed
        @test result.error_code == :invalid_type
        @test result.error_path == spec.field_path
        @test result.compile_calls == 0
        @test result.provider_calls == 0
        @test result.solver_calls == 0
        @test result.mutation_hash isa G.Digest256
        @test result.result_hash isa G.Digest256
    end

    # The expected error is only an oracle: changing it cannot alter the
    # source-derived classification.
    row = first(x for x in _N10_FIXTURE.mutations if String(x.id) == "N10-04")
    forged_oracle = G.N10MutationSpecV1(String(row.id), String(row.field_path),
        String(row.source_locator), Symbol(String(row.source_type)), Symbol(String(row.mutation_kind)),
        :invalid_boundary, :fail_closed, 0, 0, 0)
    @test G.n10_validate_mutation(projection, forged_oracle).error_code == :invalid_type
end

@testset "UP2-00C N10 foreign candidate and receipt controls" begin
    c1 = "fusionconceptai://candidate/candidate-1"
    c2 = "fusionconceptai://candidate/candidate-2"
    p1 = _n10_actual_package(c1)
    p2 = _n10_actual_package(c2)
    @test G.canonical_hash(p1.g2.plan) == G.canonical_hash(p2.g2.plan)
    @test p1.g2.contract_ref != p2.g2.contract_ref
    @test p1.g2.candidate_hash != p2.g2.candidate_hash
    @test p1.candidate_hash != p2.candidate_hash

    # Reusing candidate-1's G2 object with candidate-2 must fail in the new
    # N10 candidate-bound factory even though the underlying plan is reusable.
    g1_2 = _n10_g1(_n10_child_fixture("G1"), G.QualifiedRefV1(c2, "v5"))
    g3_2base = _n10_child_fixture("G3")
    g2_foreign = p1.g2
    g3_2 = _n10_g3(g3_2base, G.QualifiedRefV1(c2, "v5"), g1_2.contract_ref, g2_foreign.contract_ref)
    foreign = G.integrate_genome_v5(g1_2, g2_foreign, g3_2; candidate_ref=G.QualifiedRefV1(c2, "v5"))
    @test_throws ArgumentError G.n10_identity_projection_from_a(foreign)

    projection = G.n10_identity_projection_from_a(p1)
    n03 = first(s for s in _n10_specs() if s.id == "N10-03")
    @test G.n10_validate_mutation(projection, n03).error_code == :invalid_type
    n05 = first(s for s in _n10_specs() if s.id == "N10-05")
    @test G.n10_validate_mutation(projection, n05).detail == "fresh_receipt_candidate_identity_after_mismatch"
end
