using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _GI1_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "gi1_authority_context_fixtures.json"), String))

function _gi1_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _gi1_package(candidate_id="fusionconceptai://candidate/gi1-a")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    base_g1 = _gi1_child_fixture("G1")
    old_g1 = base_g1.payload.contract_ref
    g1_ref = G.G1GenomeContractRefV2(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/"),
        old_g1.version, old_g1.schema_hash, old_g1.canonicalization_hash,
        old_g1.compatibility_profile, old_g1.version_axes, candidate.id;
        grammar_profile_hash=old_g1.grammar_profile_hash,
        applicability_profile_hash=old_g1.applicability_profile_hash)
    g1_payload = G.MechanismGenomePayloadV2(g1_ref, base_g1.payload.states,
        base_g1.payload.equation_plan, base_g1.payload.grammar_profile)
    g1 = G.MechanismGenomeV5(G.g1_materialize_contract_ref(g1_ref, base_g1.payload.grammar_profile),
        g1_payload, base_g1.version_axes)

    base_g2 = _gi1_child_fixture("G2")
    g2_ref = G.GenomeContractRef(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/"),
        "v5", base_g2.contract_ref.schema_hash, base_g2.contract_ref.canonicalization_hash,
        base_g2.contract_ref.compatibility_profile)
    g2 = G.FieldGeometryGenomeV5(g2_ref, base_g2.region_interface, base_g2.plan,
        base_g2.grammar_profile, base_g2.version_axes)

    base_g3 = _gi1_child_fixture("G3")
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
        x.target_layer === :G1 ? g1.contract_ref : g2_ref, x.channel, x.unit, x.kind,
        x.source_id) for x in base_g3.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base_g3.binding.links, feedback)
    g3 = G.RealizationControlGenomeV5(bundle, realization, control, binding)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _gi1_n05_declaration(package)
    candidate = package.candidate_ref
    g1_ref, g2_ref, g3_ref = package.g1.contract_ref, package.g2.contract_ref,
        package.g3.contract_binding.contract_ref
    interface = package.g2.region_interface.interfaces[1]
    equations = package.g1.payload.equation_plan.equations
    occurrences = [o for e in equations for o in e.occurrences]
    left_o, right_o = occurrences[1], occurrences[2]
    unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
    left_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :left), "v1")
    right_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :right), "v1")
    left_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(left_ref, unit), :authoritative)
    right_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(right_ref, unit), :authoritative)
    left = G.UP2N05FluxEndpointV1(left_ref, "gi1-left", :left, 1, left_unit,
        G.UP2N05OccurrenceLocatorV1(left_o.equation_id, left_o.port_side, left_o.port_index,
            left_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(left_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    right = G.UP2N05FluxEndpointV1(right_ref, "gi1-right", :right, -1, right_unit,
        G.UP2N05OccurrenceLocatorV1(right_o.equation_id, right_o.port_side, right_o.port_index,
            right_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(right_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    expression = G.UP2N05LawExpressionV1(:signed_transfer, left.port_id, right.port_id,
        :antisymmetric_transfer)
    law_ref = G.QualifiedRefV1(G._n05_law_id(candidate, interface.interface_ref), "v1")
    law = G.UP2N05FluxLawV1(law_ref, :flux, expression, 1, -1, unit,
        G.UP2N05SourceLocatorV1(:N05, "/n05/authored_flux_law/$(law_ref.id)", law_ref,
            G._n05_law_source_hash(law_ref, expression, 1, -1, unit), :AuthoredFluxLawV1))
    G.UP2N05FluxDeclarationV1(candidate, package.candidate_hash, g1_ref, g2_ref, g3_ref,
        package.version_axes, :flux, law, interface.interface_ref, interface.left_region_id,
        interface.right_region_id, left, right)
end

function _gi1_e0(package)
    G.up2_candidate_physical_binding_from_a(package)
end

function _gi1_rebuild(c::G.GI1AuthorityContextV1;
                      schema_hash=c.schema_hash, g1_component_hash=c.g1_component_hash,
                      version_axes=c.version_axes, e1=c.e1, e2=c.e2,
                      context_hash=c.context_hash)
    G.GI1AuthorityContextV1(c.context_version, schema_hash, c.canonicalization_hash,
        c.compatibility_profile_hash, c.candidate_ref, c.package_hash,
        c.package_structural_status, c.package_resolution, c.package_claim_ceiling,
        c.g1_ref, c.g2_ref, c.g3_ref, g1_component_hash, c.g2_component_hash,
        c.g3_component_hash, version_axes, c.e0_binding, e1, e2,
        c.contract_admission, c.physical_resolution, c.gaps, c.errors,
        c.compile_calls, c.provider_calls, c.solver_calls, context_hash)
end

@testset "G-I1A typed authority context" begin
    cases = Dict(String(c.id) => c for c in _GI1_FIXTURE.cases)
    package = _gi1_package()
    e0 = _gi1_e0(package)
    declaration = _gi1_n05_declaration(package)
    n05 = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    context = G.gi1_authority_context_from_a(package, e0; n05=n05)
    @test haskey(cases, "actual_a_e1_present_e2_absent")
    @test context.candidate_ref == package.candidate_ref
    @test context.context_version == "v1"
    @test context.schema_hash == G.gi1_schema_hash()
    @test context.canonicalization_hash == G.gi1_canonicalization_hash()
    @test context.compatibility_profile_hash == G.gi1_profile_hash()
    @test context.package_hash == package.candidate_hash
    @test context.package_structural_status == package.structural_status
    @test context.package_resolution == G.terminal_deferred
    @test context.package_claim_ceiling == G.none
    @test context.g1_ref == package.g1.contract_ref
    @test context.g2_ref == package.g2.contract_ref
    @test context.g3_ref == package.g3.contract_binding.contract_ref
    @test context.g1_component_hash == package.g1.candidate_hash
    @test context.g2_component_hash == package.g2.candidate_hash
    @test context.g3_component_hash == package.g3.candidate_hash
    @test context.e0_binding === e0
    @test context.e1 isa G.GI1N05PresentAuthoritySlotV1
    @test context.e2 isa G.GI1AbsentAuthoritySlotV1
    @test context.e1.compatibility_profile_hash == context.e1.authority.profile_hash
    @test context.e2.compatibility_profile_hash == context.e2.profile_hash
    @test context.e2.reason == :missing_authority
    @test context.contract_admission == :terminal_deferred
    @test context.physical_resolution == G.terminal_deferred
    @test context.compile_calls == context.provider_calls == context.solver_calls == 0
    @test G.gi1_validate_authority_context_schema(context).status == :valid
    trusted = G.gi1_validate_authority_context(context, package, e0; n05=n05)
    @test trusted.status == :valid
    @test trusted.source_bound
    @test trusted.contract_admission == :terminal_deferred
    @test context.context_hash == G.canonical_hash(G._gi1_context_body(context))
end

@testset "G-I1A constructor status branches and explicit N06 boundary" begin
    cases = Dict(String(c.id) => c for c in _GI1_FIXTURE.cases)
    @test haskey(cases, "constructor_state_branches")
    @test haskey(cases, "explicit_n06_invalid_mapping")
    @test haskey(cases, "admission_taxonomy_statuses")
    @test haskey(cases, "program_exception_factory_path")
    package = _gi1_package("fusionconceptai://candidate/gi1-state")
    e0 = _gi1_e0(package)
    declaration = _gi1_n05_declaration(package)
    n05 = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    actual_context = G.gi1_authority_context_from_a(package, e0; n05=n05)
    for status in (:declared_consistent, :fail_closed, :terminal_deferred, :program_exception)
        @test G.gi1_admission_taxonomy(status) == status
    end
    @test G.GI1ProgramException("taxonomy") isa Exception
    @test_throws ArgumentError G.gi1_admission_taxonomy(:unexpected)
    synthetic_mapping_seed = G.N06SourceFieldLedgerMappingV1(package.candidate_ref,
            package.candidate_hash, e0.bound_input_hash, package.g1.contract_ref,
            package.g2.contract_ref, package.g3.contract_binding.contract_ref,
            package.version_axes, (), G.n06_schema_hash(), G.n06_canonicalization_hash(),
            G.n06_profile_hash(), G.digest256_text("synthetic-mapping"))
    synthetic_mapping = G.N06SourceFieldLedgerMappingV1(package.candidate_ref,
        package.candidate_hash, e0.bound_input_hash, package.g1.contract_ref,
        package.g2.contract_ref, package.g3.contract_binding.contract_ref,
        package.version_axes, (), G.n06_schema_hash(), G.n06_canonicalization_hash(),
        G.n06_profile_hash(), G._n06_mapping_hash(synthetic_mapping_seed))
    synthetic_e2 = G._gi1_make_n06_present(synthetic_mapping, package, e0)
    @test G._gi1_overall_admission(actual_context.e1, synthetic_e2,
        :declared_consistent, :terminal_deferred, ("law_missing",), ()) == :terminal_deferred
    @test G._gi1_overall_admission(actual_context.e1, synthetic_e2,
        :declared_consistent, :declared_consistent, (), ()) == :declared_consistent
    context = G.gi1_authority_context_from_a(package, e0)
    bad_n05 = G.UP2N05AuthorityV1(n05.candidate_ref, n05.package_hash, n05.g1_ref,
        n05.g2_ref, n05.g3_ref, n05.g1_component_hash, n05.g2_component_hash,
        n05.g3_component_hash, n05.version_axes, n05.declaration, n05.schema_hash,
        n05.canonicalization_hash, n05.profile_hash, n05.binding_hash, n05.gaps,
        :program_exception)
    trusted_program = G.gi1_validate_authority_context(actual_context, package, e0;
        n05=bad_n05)
    @test trusted_program.status == :program_exception
    @test trusted_program.compile_calls == trusted_program.provider_calls ==
        trusted_program.solver_calls == 0
    valid = G.GI1AuthorityContextV1(context.context_version, context.schema_hash,
        context.canonicalization_hash, context.compatibility_profile_hash,
        context.candidate_ref, context.package_hash, :valid, context.package_resolution,
        context.package_claim_ceiling, context.g1_ref, context.g2_ref, context.g3_ref,
        context.g1_component_hash, context.g2_component_hash, context.g3_component_hash,
        context.version_axes, context.e0_binding, context.e1, context.e2,
        :terminal_deferred, context.physical_resolution, (), (), 0, 0, 0,
        context.context_hash)
    @test valid.package_structural_status == :valid
    @test_throws ArgumentError G.GI1AuthorityContextV1(context.context_version,
        context.schema_hash, context.canonicalization_hash,
        context.compatibility_profile_hash, context.candidate_ref, context.package_hash,
        :valid, context.package_resolution, context.package_claim_ceiling,
        context.g1_ref, context.g2_ref, context.g3_ref, context.g1_component_hash,
        context.g2_component_hash, context.g3_component_hash, context.version_axes,
        context.e0_binding, context.e1, context.e2, :terminal_deferred,
        context.physical_resolution, (), ("unexpected_error",), 0, 0, 0,
        context.context_hash)
    closed = G.GI1AuthorityContextV1(context.context_version, context.schema_hash,
        context.canonicalization_hash, context.compatibility_profile_hash,
        context.candidate_ref, context.package_hash, :fail_closed,
        context.package_resolution, context.package_claim_ceiling, context.g1_ref,
        context.g2_ref, context.g3_ref, context.g1_component_hash,
        context.g2_component_hash, context.g3_component_hash, context.version_axes,
        context.e0_binding, context.e1, context.e2, :fail_closed,
        context.physical_resolution, (), ("source_invalid",), 0, 0, 0,
        context.context_hash)
    @test closed.package_structural_status == :fail_closed
    @test_throws ArgumentError G.GI1AuthorityContextV1(context.context_version,
        context.schema_hash, context.canonicalization_hash,
        context.compatibility_profile_hash, context.candidate_ref, context.package_hash,
        :fail_closed, context.package_resolution, context.package_claim_ceiling,
        context.g1_ref, context.g2_ref, context.g3_ref, context.g1_component_hash,
        context.g2_component_hash, context.g3_component_hash, context.version_axes,
        context.e0_binding, context.e1, context.e2, :fail_closed,
        context.physical_resolution, (), (), 0, 0, 0, context.context_hash)
    bad_n06 = G.N06SourceFieldLedgerMappingV1(package.candidate_ref,
        G.digest256_text("foreign-package"), e0.bound_input_hash, package.g1.contract_ref,
        package.g2.contract_ref, package.g3.contract_binding.contract_ref,
        package.version_axes, (), G.n06_schema_hash(), G.n06_canonicalization_hash(),
        G.n06_profile_hash(), G.digest256_text("bad-mapping"))
    @test_throws ArgumentError G.gi1_authority_context_from_a(package, e0; n06=bad_n06)
end

@testset "G-I1A E1 absent and E2 absent slots" begin
    cases = Dict(String(c.id) => c for c in _GI1_FIXTURE.cases)
    @test haskey(cases, "actual_a_e1_absent_e2_absent")
    package = _gi1_package("fusionconceptai://candidate/gi1-b")
    e0 = _gi1_e0(package)
    context = G.gi1_authority_context_from_a(package, e0)
    @test context.e1 isa G.GI1AbsentAuthoritySlotV1
    @test context.e1.slot == :E1
    @test context.e2 isa G.GI1AbsentAuthoritySlotV1
    @test context.e2.slot == :E2
    @test context.e1.content_hash == G._gi1_slot_hash(context.e1)
    @test context.e2.content_hash == G._gi1_slot_hash(context.e2)
    @test context.contract_admission == :terminal_deferred
    @test G.gi1_validate_authority_context_schema(context).status == :valid
    @test G.gi1_validate_authority_context(context, package, e0).status == :valid
end

@testset "G-I1A source-derived tamper controls" begin
    cases = Dict(String(c.id) => c for c in _GI1_FIXTURE.cases)
    @test haskey(cases, "foreign_e0_candidate")
    @test haskey(cases, "stale_e1_package_hash")
    @test haskey(cases, "tampered_context_identity")
    @test haskey(cases, "tampered_context_metadata")
    @test haskey(cases, "swapped_slots")
    @test haskey(cases, "foreign_component_hash")
    @test haskey(cases, "foreign_axis")
    @test haskey(cases, "invalid_e2_present")
    package = _gi1_package("fusionconceptai://candidate/gi1-c")
    e0 = _gi1_e0(package)
    declaration = _gi1_n05_declaration(package)
    n05 = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    @test_throws ArgumentError G.gi1_authority_context_from_a(package, e0;
        n05=G.UP2N05AuthorityV1(n05.candidate_ref, G.digest256_text("foreign-package"),
            n05.g1_ref, n05.g2_ref, n05.g3_ref, n05.g1_component_hash,
            n05.g2_component_hash, n05.g3_component_hash, n05.version_axes,
            n05.declaration, n05.schema_hash, n05.canonicalization_hash,
            n05.profile_hash, n05.binding_hash, n05.gaps, n05.resolution))
    foreign_candidate = G.QualifiedRefV1("fusionconceptai://candidate/foreign", "v5")
    foreign_e0 = G.UP2CandidatePhysicalBindingV1(foreign_candidate, e0.package_hash,
        e0.g1_ref, e0.g2_ref, e0.g3_ref, e0.g1_component_hash, e0.g2_component_hash,
        e0.g3_component_hash, e0.version_axes, e0.schema_hash,
        e0.canonicalization_hash, e0.profile_hash, nothing, nothing, e0.gaps)
    @test_throws ArgumentError G.gi1_authority_context_from_a(package, foreign_e0)
    valid_context = G.gi1_authority_context_from_a(package, e0)
    forged_hash = G.digest256_text("forged-context")
    forged = G.GI1AuthorityContextV1(valid_context.context_version, valid_context.schema_hash,
        valid_context.canonicalization_hash, valid_context.compatibility_profile_hash,
        valid_context.candidate_ref, valid_context.package_hash,
        valid_context.package_structural_status, valid_context.package_resolution,
        valid_context.package_claim_ceiling, valid_context.g1_ref, valid_context.g2_ref,
        valid_context.g3_ref, valid_context.g1_component_hash, valid_context.g2_component_hash,
        valid_context.g3_component_hash, valid_context.version_axes, valid_context.e0_binding,
        valid_context.e1, valid_context.e2, valid_context.contract_admission,
        valid_context.physical_resolution, valid_context.gaps, valid_context.errors,
        0, 0, 0, forged_hash)
    @test G.gi1_validate_authority_context_schema(forged).status == :fail_closed
    @test G.gi1_validate_authority_context(forged, package, e0).status == :fail_closed
    @test G.gi1_validate_authority_context(forged, package, e0).compile_calls == 0
    @test_throws ArgumentError _gi1_rebuild(valid_context,
        schema_hash=G.digest256_text("tampered-context-schema"))
    @test_throws ArgumentError _gi1_rebuild(valid_context, e1=valid_context.e2,
        e2=valid_context.e1)
    foreign_component = _gi1_rebuild(valid_context,
        g1_component_hash=G.digest256_text("foreign-component"))
    @test G.gi1_validate_authority_context_schema(foreign_component).status == :fail_closed
    @test G.gi1_validate_authority_context(foreign_component, package, e0).status == :fail_closed
    foreign_axes = merge(valid_context.version_axes, (g1=:foreign_axis,))
    axis_forgery = _gi1_rebuild(valid_context, version_axes=foreign_axes)
    @test G.gi1_validate_authority_context_schema(axis_forgery).status == :fail_closed
    @test G.gi1_validate_authority_context(axis_forgery, package, e0).status == :fail_closed
    @test isdefined(G, :GI1N06PresentAuthoritySlotV1)
end
