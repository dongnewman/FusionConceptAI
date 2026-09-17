using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _N05_RECEIPT_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n05_flux_authority_fixtures.json"), String))

function _n05e_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n05e_package(candidate_id="fusionconceptai://candidate/candidate-1")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    base_g1 = _n05e_child_fixture("G1")
    g1_old = base_g1.payload.contract_ref
    g1_ref = G.G1GenomeContractRefV2(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/"),
        g1_old.version, g1_old.schema_hash, g1_old.canonicalization_hash,
        g1_old.compatibility_profile, g1_old.version_axes, candidate.id;
        grammar_profile_hash=g1_old.grammar_profile_hash,
        applicability_profile_hash=g1_old.applicability_profile_hash)
    g1_payload = G.MechanismGenomePayloadV2(g1_ref, base_g1.payload.states,
        base_g1.payload.equation_plan, base_g1.payload.grammar_profile)
    g1 = G.MechanismGenomeV5(G.g1_materialize_contract_ref(g1_ref, base_g1.payload.grammar_profile),
        g1_payload, base_g1.version_axes)
    base_g2 = _n05e_child_fixture("G2")
    g2_ref = G.GenomeContractRef(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/"),
        "v5", base_g2.contract_ref.schema_hash, base_g2.contract_ref.canonicalization_hash,
        base_g2.contract_ref.compatibility_profile)
    g2 = G.FieldGeometryGenomeV5(g2_ref, base_g2.region_interface, base_g2.plan,
        base_g2.grammar_profile, base_g2.version_axes)
    base_g3 = _n05e_child_fixture("G3")
    rb = G.G3ContractBindingV2(base_g3.realization.contract_binding.contract_ref,
        candidate, base_g3.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base_g3.control.contract_binding.contract_ref,
        candidate, base_g3.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base_g3.binding.contract_binding.contract_ref,
        candidate, base_g3.binding.contract_binding.version_axes)
    bundle = G.G3ContractBindingV2(base_g3.contract_binding.contract_ref,
        candidate, base_g3.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base_g3.realization.network,
        base_g3.realization.material_domains, base_g3.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base_g3.control.signal_ports, base_g3.control.controllers,
        base_g3.control.faults, base_g3.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(x.feedback_id, x.target_layer,
        x.target_layer === :G1 ? g1_ref : g2_ref, x.channel, x.unit, x.kind,
        x.source_id) for x in base_g3.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base_g3.binding.links, feedback)
    g3 = G.RealizationControlGenomeV5(bundle, realization, control, binding)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n05e_decl(package)
    candidate = package.candidate_ref
    g1_ref, g2_ref, g3_ref = package.g1.contract_ref, package.g2.contract_ref, package.g3.contract_binding.contract_ref
    interface = package.g2.region_interface.interfaces[1]
    equations = package.g1.payload.equation_plan.equations
    occurrences = [o for e in equations for o in e.occurrences]
    left_o, right_o = occurrences[1], occurrences[2]
    left_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :left), "v1")
    right_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :right), "v1")
    unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
    left_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(left_ref, unit), :authoritative)
    right_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(right_ref, unit), :authoritative)
    left = G.UP2N05FluxEndpointV1(left_ref, "authored-flux-left", :left, 1, left_unit,
        G.UP2N05OccurrenceLocatorV1(left_o.equation_id, left_o.port_side, left_o.port_index,
            left_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(left_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    right = G.UP2N05FluxEndpointV1(right_ref, "authored-flux-right", :right, -1, right_unit,
        G.UP2N05OccurrenceLocatorV1(right_o.equation_id, right_o.port_side, right_o.port_index,
            right_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(right_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    expression = G.UP2N05LawExpressionV1(:signed_transfer, left.port_id, right.port_id, :antisymmetric_transfer)
    law_ref = G.QualifiedRefV1(G._n05_law_id(candidate, interface.interface_ref), "v1")
    law = G.UP2N05FluxLawV1(law_ref, :flux, expression, 1, -1, unit,
        G.UP2N05SourceLocatorV1(:N05, "/n05/authored_flux_law/$(law_ref.id)", law_ref,
            G._n05_law_source_hash(law_ref, expression, 1, -1, unit), :AuthoredFluxLawV1))
    G.UP2N05FluxDeclarationV1(candidate, package.candidate_hash, g1_ref, g2_ref, g3_ref,
        package.version_axes, :flux, law, interface.interface_ref, interface.left_region_id,
        interface.right_region_id, left, right)
end

function _n05e_specs()
    Tuple(G.UP2N05MutationSpecV1(String(x.id), String(x.field_path), Symbol(String(x.mutation_kind)),
        Symbol(String(x.expected_error)), Symbol(String(x.expected_resolution))) for x in _N05_RECEIPT_FIXTURE.mutations)
end

@testset "UP2-00E1 N05 serialized receipt envelope" begin
    package = _n05e_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    declaration = _n05e_decl(package)
    authored = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    absent = G.up2n05_authority_from_a(package, e0)
    path = joinpath(mktempdir(), "n05_receipts.json")
    envelope = G.n05_export_receipt_envelope(package, e0, authored, absent, _n05e_specs(); output_path=path)
    @test isfile(path)
    @test G.n05_check_receipt_envelope(envelope, package, e0, authored, absent, _n05e_specs()).status == :source_bound_valid
    @test G.n05_check_receipt_file(path).status == :valid
    @test G.n05_check_receipt_file(path).authored_count == 5
    @test G.n05_check_receipt_file(path).absent_count == 5
    @test envelope.claims.compile_calls == 0
    @test envelope.claims.provider_calls == 0
    @test envelope.claims.solver_calls == 0
    authored_bad_row = merge(envelope.authored_receipts[1], (source_locator=merge(
        envelope.authored_receipts[1].source_locator, (source_hash=repeat("0", 64),)),))
    authored_bad = merge(envelope, (authored_receipts=(authored_bad_row,
        envelope.authored_receipts[2], envelope.authored_receipts[3],
        envelope.authored_receipts[4], envelope.authored_receipts[5]),))
    absent_bad_row = merge(envelope.absent_authority_receipts[1],
        (mutation_hash=repeat("0", 64),))
    absent_bad = merge(envelope, (absent_authority_receipts=(absent_bad_row,
        envelope.absent_authority_receipts[2], envelope.absent_authority_receipts[3],
        envelope.absent_authority_receipts[4], envelope.absent_authority_receipts[5]),))
    @test_throws ArgumentError G.n05_check_receipt_envelope(authored_bad, package, e0,
        authored, absent, _n05e_specs())
    @test_throws ArgumentError G.n05_check_receipt_envelope(absent_bad, package, e0,
        authored, absent, _n05e_specs())
    @test_throws ArgumentError G.n05_export_receipt_envelope(package, e0, authored, absent,
        _n05e_specs(); output_path=path)
end
