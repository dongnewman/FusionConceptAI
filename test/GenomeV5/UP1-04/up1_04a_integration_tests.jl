using Test
using JSON3
using Serialization
using FusionConceptAI

const _FIXTURE = JSON3.read(read(joinpath(@__DIR__, "fixtures.json"), String))
const G = FusionConceptAI
_fixture_case(id::AbstractString, expected::AbstractString) =
    any(String(x.id) == id && String(x.expected) == expected for x in _FIXTURE.negative_cases)

function _child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    coupled_binding = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle_binding = G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(ch.feedback_id, ch.target_layer,
        ch.target_layer === :G1 ? g1_ref : g2_ref, ch.channel, ch.unit, ch.kind,
        ch.source_id) for ch in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(coupled_binding, rb, cb,
        base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle_binding, realization, control, binding)
end

function _actual_g1(base, candidate)
    old = base.payload.contract_ref
    g1_uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(g1_uri,
        old.version, old.schema_hash, old.canonicalization_hash,
        old.compatibility_profile, old.version_axes, candidate.id;
        grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    outer = G.g1_materialize_contract_ref(ref, base.payload.grammar_profile)
    G.MechanismGenomeV5(outer, payload, base.version_axes)
end

function _actual_g2(base, candidate)
    g2_uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(g2_uri, "v5",
        base.contract_ref.schema_hash, base.contract_ref.canonicalization_hash,
        base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

@testset "UP1-04A additive shared entry" begin
    @test String(_FIXTURE.fixture_id) == "UP1-FX-UP1-04A-001"
    @test _fixture_case("feedback_target_ref_mismatch", "fail_closed")
    @test _fixture_case("candidate_ref_mismatch", "fail_closed")
    @test _fixture_case("legacy_mapping_without_receipt", "reject_input")
    c = G.QualifiedRefV1(String(_FIXTURE.candidate_ref.id), String(_FIXTURE.candidate_ref.version))
    load_genome_v5_components!()
    g1 = _actual_g1(_child_fixture("G1"), c)
    g2 = _actual_g2(_child_fixture("G2"), c)
    g3 = _actual_g3(_child_fixture("G3"), c, g1.contract_ref, g2.contract_ref)
    package = G.integrate_genome_v5(g1, g2, g3; candidate_ref=c)
    println("UP1_04A_PACKAGE_HASH=" * package.candidate_hash.value)
    println("UP1_04A_RECEIPT_HASH=" * G.canonical_hash(package.migration_receipt).value)
    println("UP1_04A_RECEIPT_AFTER=" * package.migration_receipt.candidate_identity_after)
    @test package isa G.CandidateStatePackageV5
    @test package.structural_status == :valid
    @test package.resolution == G.terminal_deferred
    @test package.claim_ceiling == G.none
    @test isempty(package.errors)
    @test any(contains("G3_provider_match=no_match"), package.gaps)
    @test any(contains("G3_resolution=terminal_deferred"), package.gaps)
    @test any(contains("G2_mesh_status=not_executed"), package.gaps)
    @test any(contains("G2_physical_status=not_executed"), package.gaps)
    @test any(contains("feedback_provenance_gap"), package.gaps)
    @test package.component_identity.g1_genome_hash == G.g1_genome_hash(g1)
    @test package.component_identity.g2_genome_hash == G.g2_genome_hash(g2)
    @test package.g2_binding.candidate_ref == c
    @test package.g2_binding.genome_hash == G.g2_genome_hash(g2)
    c2 = G.QualifiedRefV1("fusionconceptai://candidate/candidate-2", "v5")
    g1_2 = _actual_g1(_child_fixture("G1"), c2)
    g2_2 = _actual_g2(_child_fixture("G2"), c2)
    g3_2 = _actual_g3(_child_fixture("G3"), c2, g1_2.contract_ref, g2_2.contract_ref)
    package_2 = G.integrate_genome_v5(g1_2, g2_2, g3_2; candidate_ref=c2)
    @test package_2.structural_status == :valid
    @test package_2.g2_binding.candidate_ref == c2
    @test package_2.g2.contract_ref.uri != package.g2.contract_ref.uri
    @test package_2.g2_binding.genome_hash != package.g2_binding.genome_hash
    @test package_2.candidate_hash != package.candidate_hash
    historical_g2_ref = G.GenomeContractRef("urn:fusion:g2:split-x-1", "v5",
        g2.contract_ref.schema_hash, g2.contract_ref.canonicalization_hash,
        g2.contract_ref.compatibility_profile)
    historical_g2 = G.FieldGeometryGenomeV5(historical_g2_ref, g2.region_interface,
        g2.plan, g2.grammar_profile, g2.version_axes)
    rejected_historical_g2 = G.integrate_genome_v5(g1, historical_g2, g3; candidate_ref=c)
    @test rejected_historical_g2.structural_status == :fail_closed
    @test any(contains("G2_public_uri_namespace_not_authoritative"), rejected_historical_g2.errors)
    @test package.component_identity.g3_genome_hash == G.g3_candidate_hash(g3)
    @test package.component_identity.g3_child_refs == G._v5_g3_child_refs(g3)
    @test length(package.component_identity.feedback) == length(g3.binding.feedback)
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, package.component_identity,
        :fail_closed, G.resolved, ("forged",), (), G.none)
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, package.component_identity,
        :valid, G.resolved, (), package.gaps, G.none)
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, package.component_identity,
        :valid, G.terminal_deferred, (), package.gaps, G.screen_only)
    forged_identity = merge(package.component_identity,
        (g2_genome_hash=G.Digest256(repeat("c", 64)),))
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, forged_identity,
        :valid, G.terminal_deferred, (), package.gaps, G.none)
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, forged_identity,
        :fail_closed, G.terminal_deferred, ("structural error",), package.gaps, G.none)
    forged_children = merge(package.component_identity,
        (g3_child_refs=merge(package.component_identity.g3_child_refs,
            (binding=merge(package.component_identity.g3_child_refs.binding,
                (uri="fusionconceptai://GenomeV5/G3/forged-binding",)),)),))
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, forged_children,
        :fail_closed, G.terminal_deferred, ("identity error",), package.gaps, G.none)
    forged_feedback = merge(package.component_identity,
        (feedback=(merge(first(package.component_identity.feedback),
            (target_layer=:G1, target_contract_ref=package.component_identity.g2_ref,)),
            package.component_identity.feedback[2]),))
    @test_throws ArgumentError G.CandidateStatePackageV5(c, g1, g2, package.g2_binding, g3,
        package.version_axes, package.migration_receipt, forged_feedback,
        :valid, G.terminal_deferred, (), package.gaps, G.none)

    first_feedback = first(g3.binding.feedback)
    wrong_feedback = G.G3FeedbackChannelV2(first_feedback.feedback_id, :G1,
        g2.contract_ref, first_feedback.channel, first_feedback.unit,
        first_feedback.kind, first_feedback.source_id)
    bad_binding = G.CoupledRealizationControlBindingV2(g3.binding.contract_binding,
        g3.realization.contract_binding, g3.control.contract_binding, g3.binding.links,
        (wrong_feedback, g3.binding.feedback[2:end]...))
    bad_g3 = G.RealizationControlGenomeV5(g3.contract_binding, g3.realization,
        g3.control, bad_binding)
    rejected = G.integrate_genome_v5(g1, g2, bad_g3; candidate_ref=c)
    @test rejected.structural_status == :fail_closed
    @test _fixture_case("feedback_target_ref_mismatch", "fail_closed") &&
        any(contains("feedback_target_ref_mismatch"), rejected.errors)

    forged_candidate = G.QualifiedRefV1("fusionconceptai://candidate/forged", "v5")
    wrong_candidate_package = G.integrate_genome_v5(g1, g2, g3; candidate_ref=forged_candidate)
    @test _fixture_case("candidate_ref_mismatch", "fail_closed") &&
        wrong_candidate_package.structural_status == :fail_closed

    legacy = Tuple(G.GenomeContractRef(String(x), "v4", G.Digest256(repeat("a", 64)),
        G.Digest256(repeat("b", 64)), "legacy-v4") for x in _FIXTURE.legacy_refs)
    deferred = G.integrate_genome_v5(g1, g2, g3; candidate_ref=c, legacy_refs=legacy)
    @test deferred.resolution == G.terminal_deferred
    @test deferred.migration_receipt.status == :terminal_deferred
    @test all(!row.lossless && row.new_ref === nothing for row in deferred.migration_receipt.records)
    @test all(startswith(row.provenance, "unverified typed V4 source ref")
              for row in deferred.migration_receipt.records)
    placeholder = G.GenomeContractRef("placeholder://GenomeV4/fake", "v4",
        G.Digest256(repeat("a", 64)), G.Digest256(repeat("b", 64)), "legacy-v4")
    @test_throws ArgumentError G.v5_deferred_migration_receipt(c; legacy_refs=(placeholder,))
    @test_throws ArgumentError G.v5_deferred_migration_receipt(c; legacy_refs=())
    stale = G.GenomeV5MigrationReceipt(package.migration_receipt.receipt_id, c, (), :pending,
        nothing, "foreign-after", "no_legacy_mapping_requested")
    @test_throws ArgumentError G.integrate_genome_v5(g1, g2, g3;
        candidate_ref=c, migration_receipt=stale)
end
