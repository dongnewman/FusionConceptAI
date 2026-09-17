using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _N05_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n05_flux_authority_fixtures.json"), String))

function _n05_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n05_g1(base, candidate)
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

function _n05_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _n05_g3(base, candidate, g1_ref, g2_ref)
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

function _n05_actual_package(candidate_id="fusionconceptai://candidate/candidate-1")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    g1 = _n05_g1(_n05_child_fixture("G1"), candidate)
    g2 = _n05_g2(_n05_child_fixture("G2"), candidate)
    base_g3 = _n05_child_fixture("G3")
    g3 = _n05_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n05_e0_binding(package)
    G.up2_candidate_physical_binding_from_a(package)
end

function _n05_declaration(package)
    candidate_ref = package.candidate_ref
    g1_ref, g2_ref, g3_ref = package.g1.contract_ref, package.g2.contract_ref,
        package.g3.contract_binding.contract_ref
    g1_hash, g2_hash, g3_hash = package.g1.candidate_hash, package.g2.candidate_hash,
        package.g3.candidate_hash
    equations = package.g1.payload.equation_plan.equations
    left = first(o for e in equations for o in e.occurrences if e.equation_id == "governing-0")
    right = first(o for e in equations for o in e.occurrences if e.equation_id == "source-0")
    interface = first(package.g2.region_interface.interfaces)
    left_source = G.UP2N05SourceLocatorV1(:G1,
        G._n05_occurrence_path(left),
        g1_ref, g1_hash, :G1LedgerOccurrenceV2)
    right_source = G.UP2N05SourceLocatorV1(:G1,
        G._n05_occurrence_path(right),
        g1_ref, g1_hash, :G1LedgerOccurrenceV2)
    left_occ = G.UP2N05OccurrenceLocatorV1(left.equation_id, left.port_side, left.port_index,
        left.ledger_id, left_source)
    right_occ = G.UP2N05OccurrenceLocatorV1(right.equation_id, right.port_side, right.port_index,
        right.ledger_id, right_source)
    left_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate_ref, interface.interface_ref, :left), "v1")
    right_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate_ref, interface.interface_ref, :right), "v1")
    # Flux units are authored N05 values.  The G1 occurrence units remain
    # occurrence provenance and are deliberately not reused as flux authority.
    flux_unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
    left_unit = G.UP2N05UnitProvenanceV1(flux_unit,
        G._n05_authored_unit_source(left_ref, flux_unit), :authoritative)
    right_unit = G.UP2N05UnitProvenanceV1(flux_unit,
        G._n05_authored_unit_source(right_ref, flux_unit), :authoritative)
    left_endpoint = G.UP2N05FluxEndpointV1(left_ref, "authored-flux-left", :left, 1, left_unit, left_occ)
    right_endpoint = G.UP2N05FluxEndpointV1(right_ref, "authored-flux-right", :right, -1, right_unit, right_occ)
    expression = G.UP2N05LawExpressionV1(:signed_transfer, left_endpoint.port_id,
        right_endpoint.port_id, :antisymmetric_transfer)
    law_ref = G.QualifiedRefV1(G._n05_law_id(candidate_ref, interface.interface_ref), "v1")
    law_source_hash = G._n05_law_source_hash(law_ref, expression, 1, -1, flux_unit)
    law_source = G.UP2N05SourceLocatorV1(:N05,
        "/n05/authored_flux_law/$(law_ref.id)", law_ref, law_source_hash,
        :AuthoredFluxLawV1)
    law = G.UP2N05FluxLawV1(law_ref, :flux, expression, 1, -1, flux_unit, law_source)
    G.UP2N05FluxDeclarationV1(candidate_ref, package.candidate_hash, g1_ref, g2_ref, g3_ref,
        package.version_axes, :flux, law, interface.interface_ref, interface.left_region_id,
        interface.right_region_id, left_endpoint, right_endpoint)
end

function _n05_specs()
    Tuple(G.UP2N05MutationSpecV1(String(x.id), String(x.field_path),
        Symbol(String(x.mutation_kind)), Symbol(String(x.expected_error)),
        Symbol(String(x.expected_resolution))) for x in _N05_FIXTURE.mutations)
end

@testset "UP2-00E1 N05 actual A source and deferred baseline" begin
    @test String(_N05_FIXTURE.schema_id) == "GenomeV5/UP2/N05FluxAuthorityProjectionV1"
    @test String(_N05_FIXTURE.schema_version) == "v1"
    @test Bool(_N05_FIXTURE.schema_validation_only)
    @test length(_N05_FIXTURE.mutations) == 5
    package = _n05_actual_package()
    e0 = _n05_e0_binding(package)
    deferred = G.up2n05_authority_from_a(package, e0)
    @test deferred.resolution == :terminal_deferred
    @test length(deferred.gaps) == 5
    @test G.up2n05_validate(deferred, package, e0).status == :terminal_deferred
    @test package.candidate_hash == G._up2e0_package_hash(package)
    @test package.g2.region_interface.interfaces[1].normal in (-1, 1)
end

@testset "UP2-00E1 N05 absent authority mutation receipts remain deferred" begin
    package = _n05_actual_package()
    e0 = _n05_e0_binding(package)
    deferred = G.up2n05_authority_from_a(package, e0)
    for spec in _n05_specs()
        receipt = G.up2n05_validate_mutation(deferred, package, e0, spec)
        @test receipt.id == spec.id
        @test receipt.original_value == receipt.mutated_value
        @test receipt.error_code == :authority_gap
        @test receipt.error_path == spec.field_path
        @test receipt.resolution == :terminal_deferred
    @test receipt.compile_calls == receipt.provider_calls == receipt.solver_calls == 0
    end
end

@testset "UP2-00E1 N05 authored typed declaration and exact joins" begin
    package = _n05_actual_package()
    e0 = _n05_e0_binding(package)
    declaration = _n05_declaration(package)
    authority = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    result = G.up2n05_validate(authority, package, e0)
    @test result.status == :valid
    @test authority.resolution == :contract_ready
    @test authority.declaration.interface_ref == package.g2.region_interface.interfaces[1].interface_ref
    @test G._n05_unique_interface(package.g2.region_interface.interfaces,
        authority.declaration.interface_ref) == package.g2.region_interface.interfaces[1]
    @test authority.declaration.left_endpoint.unit.source.layer == :N05
    @test authority.declaration.left_endpoint.unit.source.source_type == :AuthoredFluxLawUnitV1
    @test authority.declaration.left_endpoint.unit.source.source_ref == authority.declaration.left_endpoint.endpoint_ref
    @test authority.declaration.left_endpoint.unit.source.source_hash ==
        G.canonical_hash((endpoint_ref=authority.declaration.left_endpoint.endpoint_ref,
                          unit=authority.declaration.left_endpoint.unit.unit))
    @test authority.declaration.left_endpoint.occurrence.locator.layer == :G1
    @test authority.declaration.right_endpoint.occurrence.locator.layer == :G1
    @test G.semantic_view(authority.declaration.left_endpoint.occurrence) !=
        G.semantic_view(authority.declaration.right_endpoint.occurrence)
    @test authority.declaration.law.source.layer == :N05
    @test authority.declaration.law.source.source_type == :AuthoredFluxLawV1
    @test authority.declaration.law.left_sign == authority.declaration.left_endpoint.sign
    @test authority.declaration.law.right_sign == authority.declaration.right_endpoint.sign
    @test authority.declaration.law.expression.left_port == authority.declaration.left_endpoint.port_id
    @test authority.declaration.law.expression.right_port == authority.declaration.right_endpoint.port_id
    @test authority.package_hash == package.candidate_hash
    @test authority.binding_hash isa G.Digest256
    @test authority.schema_hash == G.UP2N05_SCHEMA_HASH_V1
    @test authority.canonicalization_hash == G.UP2N05_CANONICAL_HASH_V1
    @test authority.profile_hash == G.UP2N05_PROFILE_HASH_V1
end

@testset "UP2-00E1 N05 five typed fail-closed mutations" begin
    package = _n05_actual_package()
    e0 = _n05_e0_binding(package)
    declaration = _n05_declaration(package)
    authority = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    for row in _N05_FIXTURE.mutations
        spec = first(s for s in _n05_specs() if s.id == String(row.id))
        receipt = G.up2n05_validate_mutation(authority, package, e0, spec)
        @test receipt.id == spec.id
        @test receipt.baseline_package_hash == package.candidate_hash
        @test receipt.original_value_hash != receipt.mutated_value_hash
        @test receipt.original_value != receipt.mutated_value
        @test receipt.source_locator.layer == :N05
        @test receipt.source_locator.source_type ==
            (spec.field_path == "/n05/right_endpoint/unit" ?
                :AuthoredFluxLawUnitV1 : :AuthoredFluxEndpointV1)
        @test receipt.source_locator.source_hash != package.g1.candidate_hash
        @test receipt.error_code == Symbol(String(row.expected_error))
        @test receipt.error_path == String(row.field_path)
        @test receipt.resolution == :fail_closed
        @test receipt.compile_calls == receipt.provider_calls == receipt.solver_calls == 0
    end
    left_ref_spec = first(s for s in _n05_specs() if s.mutation_kind === :foreign_left_endpoint_ref)
    unit_spec = first(s for s in _n05_specs() if s.mutation_kind === :right_unit_mismatch)
    @test G.up2n05_validate_mutation(authority, package, e0, left_ref_spec).error_code == :invalid_closure
    @test G.up2n05_validate_mutation(authority, package, e0, unit_spec).error_code == :invalid_type
    # The receipt label is not the dispatch key: the typed path/kind pair is.
    canonical = first(_n05_specs())
    relabeled = G.UP2N05MutationSpecV1("forged-receipt-label", canonical.field_path,
        canonical.mutation_kind, canonical.expected_error, canonical.expected_resolution)
    relabeled_receipt = G.up2n05_validate_mutation(authority, package, e0, relabeled)
    @test relabeled_receipt.id == "forged-receipt-label"
    @test relabeled_receipt.error_path == canonical.field_path
    @test relabeled_receipt.source_locator.path == canonical.field_path
    @test_throws ArgumentError G.up2n05_validate_mutation(authority, package, e0,
        G.UP2N05MutationSpecV1("N05-01", "/n05/right_endpoint/endpoint_ref",
            :foreign_left_endpoint_ref, :invalid_closure, :fail_closed))
end

@testset "UP2-00E1 N05 foreign identity and authority boundaries" begin
    package = _n05_actual_package()
    e0 = _n05_e0_binding(package)
    declaration = _n05_declaration(package)
    foreign = G.UP2N05FluxDeclarationV1(G.QualifiedRefV1("fusionconceptai://candidate/foreign", "v5"),
        declaration.package_hash, declaration.g1_ref, declaration.g2_ref, declaration.g3_ref,
        declaration.version_axes, declaration.law_kind, declaration.law, declaration.interface_ref,
        declaration.left_region_id, declaration.right_region_id, declaration.left_endpoint,
        declaration.right_endpoint)
    foreign_authority = G.up2n05_authority_from_a(package, e0; declaration=foreign)
    @test foreign_authority.resolution == :fail_closed
    @test G.up2n05_validate(foreign_authority, package, e0).status == :fail_closed
    bad_axis = (g1=package.version_axes.g1, g2=(foreign_axis=:v1,), g3=package.version_axes.g3)
    @test bad_axis != package.version_axes
    @test G.up2n05_validate(G.up2n05_authority_from_a(package, e0; declaration=declaration), package, e0).status == :valid
    @test G.up2n05_authority_from_a(package, e0).gaps == G.UP2N05_MISSING_AUTHORITY_GAPS_V1
    @test_throws ArgumentError G.up2n05_validate_mutation(foreign_authority, package, e0, first(_n05_specs()))
    foreign_package = _n05_actual_package("fusionconceptai://candidate/foreign-package")
    @test_throws ArgumentError G.up2n05_validate_mutation(
        G.up2n05_authority_from_a(package, e0; declaration=declaration), foreign_package, e0,
        first(_n05_specs()))
end

@testset "UP2-00E1 N05 duplicate occurrence locator is fail-closed" begin
    package = _n05_actual_package()
    e0 = _n05_e0_binding(package)
    declaration = _n05_declaration(package)
    duplicate_right = G.UP2N05FluxEndpointV1(
        declaration.right_endpoint.endpoint_ref, declaration.right_endpoint.port_id,
        declaration.right_endpoint.side, declaration.right_endpoint.sign,
        declaration.right_endpoint.unit, declaration.left_endpoint.occurrence)
    duplicate_declaration = G.UP2N05FluxDeclarationV1(
        declaration.candidate_ref, declaration.package_hash, declaration.g1_ref,
        declaration.g2_ref, declaration.g3_ref, declaration.version_axes,
        declaration.law_kind, declaration.law, declaration.interface_ref,
        declaration.left_region_id, declaration.right_region_id,
        declaration.left_endpoint, duplicate_right)
    duplicate_authority = G.up2n05_authority_from_a(package, e0; declaration=duplicate_declaration)
    @test duplicate_authority.resolution == :fail_closed
    duplicate_result = G.up2n05_validate(duplicate_authority, package, e0)
    @test duplicate_result.status == :fail_closed
    @test any(contains(String(x), "G1_occurrences_not_independent") for x in duplicate_result.errors)
end

@testset "UP2-00E1 N05 duplicate interface lookup is not silently selected" begin
    package = _n05_actual_package()
    interface = first(package.g2.region_interface.interfaces)
    @test G._n05_unique_interface((interface, interface), interface.interface_ref) === nothing
end
