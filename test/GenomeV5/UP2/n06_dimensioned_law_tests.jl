using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _H0A_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n06_dimensioned_law_fixtures.json"), String))

_h0a_digest(ch) = G.digest256_text(String(ch))
_h0a_unit() = G.UnitSignature((0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1))

function _h0a_binding()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/h0a-schema-only", "v5")
    ref(role, ch) = G.GenomeContractRef("fusionconceptai://GenomeV5/$(role)/h0a", "v5",
        _h0a_digest(ch), _h0a_digest("z"), "h0a-profile-v1")
    G.N06H0AInputBindingV1(candidate, _h0a_digest("a"), _h0a_digest("b"),
        _h0a_digest("c"), _h0a_digest("d"), _h0a_digest("e"), _h0a_digest("f"),
        ref("G1", "c"), ref("G2", "d"), ref("G3", "e"),
        _h0a_digest("1"), _h0a_digest("2"), _h0a_digest("3"),
        (g1="v5-axis-g1", g2="v5-axis-g2", g3="v5-axis-g3"))
end

function _h0a_endpoints()
    selectors = Tuple((ledger_id="energy", equation_id="governing-0", port_side=:output, port_index=i) for i in 1:4)
    occ = Tuple((selector=s, ledger_id=s.ledger_id, equation_id="governing-0", closure_id="closure-0", unit=_h0a_unit(), effect=:source, coefficient=1 // 1) for s in selectors)
    g2 = (region_id="region-0", interface_ref=G.QualifiedRefV1("g2://interface/0", "v2"),
        left_region_id="region-0", right_region_id="region-1", interface_side=:left, axis=1,
        coordinate=0 // 1, normal=1, continuity=:continuous, transfer_kind=:field,
        boundary_face=:x_min, boundary_locator="/g2/plan/exterior/boundary_patches/0/x_min")
    g3 = (selected_flow_link_id="link-0", ports=(), accounts=(), entries=(), closures=(), links=(), feedback=())
    G.N06H0AEndpointSetV1(occ, g2, g3)
end

function _h0a_equation(; equation="P = eta * scale * E", scale=1 // 1,
        efficiency=1 // 1, direction=:out, sign=1,
        closure_equation="P - eta * scale * E = 0", closure_relation=nothing,
        owner_scope="candidate-owner:h0a",
        owner_account_ids=("energy-owner",), calibration_source=nothing,
        closure_source=nothing, law_source=nothing, calibration_payload=nothing,
        closure_payload=nothing, law_payload=nothing, role_coefficients=NamedTuple{(),Tuple{}}(()),
        role_directions=NamedTuple{(),Tuple{}}(()))
    u = _h0a_unit()
    G.N06H0AUnitEquationV1(("P", "E", "eta", "scale"), equation, (u, u), (u,),
        scale, efficiency, "schema-validation-only authored calibration provenance",
        direction, sign, closure_equation, owner_scope, owner_account_ids;
        calibration_source=calibration_source, closure_source=closure_source,
        law_source=law_source, calibration_payload=calibration_payload,
        closure_payload=closure_payload, law_payload=law_payload,
        role_coefficients=role_coefficients, role_directions=role_directions,
        closure_relation=closure_relation)
end

@testset "H0-A unit equation constructor dispatch" begin
    default_equation = _h0a_equation()
    @test default_equation isa G.N06H0AUnitEquationV1
    @test fieldcount(typeof(default_equation)) == 21
    @test default_equation.calibration_source === nothing
    @test default_equation.closure_source === nothing
    @test default_equation.law_source === nothing

    law_payload = (law_id="fusionconceptai://GenomeV5/N06/law/h0a", version="v1")
    law_source = G._n06_h0a_provenance(:N06, law_payload,
        "/n06/law/h0a", :N06LawV1)
    sourced_equation = _h0a_equation(
        law_source=law_source, law_payload=law_payload,
        closure_relation=(kind=:balance, lhs=:power, rhs=:effort_flow))
    @test sourced_equation isa G.N06H0AUnitEquationV1
    @test sourced_equation.law_source === law_source
    @test sourced_equation.law_payload == law_payload
    @test sourced_equation.closure_relation ==
        (kind=:balance, lhs=:power, rhs=:effort_flow)
end

@testset "H0-A exact source match classification" begin
    @test G._n06_h0a_exact_match(())[1] == :missing
    @test G._n06_h0a_exact_match((:one,))[1:2] == (:single, :one)
    @test G._n06_h0a_exact_match((:one, :two))[1] == :ambiguous
    endpoints = _h0a_endpoints()
    law = _h0a_equation()
    missing_source = G._n06_h0a_validate_law(law,
        (g1_occurrences=(), g3=endpoints.g3))
    @test "g1_occurrence_source_missing" in missing_source.gaps
    ambiguous_source = G._n06_h0a_validate_law(law,
        (g1_occurrences=tuple(endpoints.g1_occurrences...,
            endpoints.g1_occurrences[1]), g3=endpoints.g3))
    @test "g1_occurrence_source_ambiguous" in ambiguous_source.errors
    source_selector = G._N06_G1_ROLE_SELECTORS[:source]
    reordered = reverse(endpoints.g1_occurrences)
    reordered_match = G._n06_h0a_source_role_match(reordered)
    @test reordered_match[1] == :single
    @test reordered_match[2].selector == source_selector
    source_occurrence = only(x for x in endpoints.g1_occurrences if x.selector == source_selector)
    foreign_selector = (ledger_id="foreign", equation_id="foreign",
        port_side=:output, port_index=99)
    missing_rows = Tuple(x.selector == source_selector ?
        merge(x, (selector=foreign_selector,)) : x for x in endpoints.g1_occurrences)
    missing_match = G._n06_h0a_source_role_match(missing_rows)
    @test missing_match[1] == :missing
    missing_check = G._n06_h0a_validate_law(law,
        (g1_occurrences=missing_rows, g3=endpoints.g3))
    @test "g1_occurrence_source_missing" in missing_check.gaps
    duplicate_match = G._n06_h0a_source_role_match((source_occurrence, source_occurrence))
    @test duplicate_match[1] == :ambiguous
    registry_match = G._n06_h0a_source_role_match(endpoints.g1_occurrences, nothing)
    @test registry_match[1] == :registry_missing
    registry_check = G._n06_h0a_validate_law(law,
        (g1_occurrences=endpoints.g1_occurrences, g3=endpoints.g3);
        source_registry=nothing)
    @test "source_binding_missing" in registry_check.gaps

    source_entry = (entry_id="r15-source-entry", account_id="source-owner",
        port_id="r15-source-port", component_id="r15-component",
        coefficient=1 // 1, unit=_h0a_unit(), effect=:source,
        provenance=nothing)
    source_g3 = merge(endpoints.g3, (entries=(source_entry,),))
    source_zero_port = G._n06_h0a_validate_law(law,
        (g1_occurrences=(endpoints.g1_occurrences[1],), g3=source_g3))
    @test "law_direction_source_port_missing" in source_zero_port.gaps
    @test !("law_direction_source_port_missing" in source_zero_port.errors)
    @test "role_port_missing:source" in source_zero_port.gaps
    @test !("role_port_missing:source" in source_zero_port.errors)

    ambiguous_port = (port_id="r15-source-port", kind=:flow,
        direction=:out, unit=_h0a_unit())
    ambiguous_g3 = merge(source_g3, (ports=(ambiguous_port, ambiguous_port),))
    source_ambiguous_port = G._n06_h0a_validate_law(law,
        (g1_occurrences=(endpoints.g1_occurrences[1],), g3=ambiguous_g3))
    @test "law_direction_source_port_ambiguous" in source_ambiguous_port.errors
    @test "role_port_ambiguous:source" in source_ambiguous_port.errors

    unexpected = G._n06_h0a_translate_upstream(ErrorException("r15 unexpected"), :r15)
    @test unexpected isa G.N06H0AProgramError
    @test !(unexpected isa G.N06H0AKnownGapError)
    @test G._n06_h0a_classify_error(unexpected) == :program_exception
    @test unexpected.code == :source_projection_exception
end

function _h0a_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _h0a_actual_g1(base, candidate)
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

function _h0a_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _h0a_actual_g3(base, candidate, g1_ref, g2_ref)
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

function _h0a_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/h0a-actual", "v5")
    g1 = _h0a_actual_g1(_h0a_child_fixture("G1"), candidate)
    g2 = _h0a_actual_g2(_h0a_child_fixture("G2"), candidate)
    base_g3 = _h0a_child_fixture("G3")
    g3 = _h0a_actual_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _h0a_actual_package_foreign_feedback()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/h0a-foreign-feedback", "v5")
    g1 = _h0a_actual_g1(_h0a_child_fixture("G1"), candidate)
    g2 = _h0a_actual_g2(_h0a_child_fixture("G2"), candidate)
    base_g3 = _h0a_child_fixture("G3")
    foreign_g1 = G.GenomeContractRef("fusionconceptai://GenomeV5/G1/foreign-authority", "v5",
        _h0a_digest("foreign-schema"), _h0a_digest("foreign-canonical"), "foreign-profile")
    g3 = _h0a_actual_g3(base_g3, candidate, foreign_g1, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _h0a_e0_variant(e0; package_hash=e0.package_hash, g1_ref=e0.g1_ref,
        g2_ref=e0.g2_ref, g3_ref=e0.g3_ref, g1_component_hash=e0.g1_component_hash,
        g2_component_hash=e0.g2_component_hash, g3_component_hash=e0.g3_component_hash,
        version_axes=e0.version_axes)
    G.UP2CandidatePhysicalBindingV1(e0.candidate_ref, package_hash, g1_ref, g2_ref,
        g3_ref, g1_component_hash, g2_component_hash, g3_component_hash, version_axes,
        e0.schema_hash, e0.canonicalization_hash, e0.profile_hash, nothing, nothing,
        e0.gaps)
end

function _h0a_trusted_declaration(package, e0; binding=G._n06_h0a_binding(package,e0),
        endpoints=G._n06_h0a_endpoint_set(package,G._n06_h0a_project(package,e0)),
        law_id=G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"),
        equation=_h0a_equation())
    G.n06_h0a_present(binding, endpoints, law_id, equation)
end

@testset "H0-A fixture and contract schema" begin
    @test String(_H0A_FIXTURE.schema_id) == "GenomeV5/UP2/N06DimensionedLedgerLawV1"
    @test String(_H0A_FIXTURE.version) == "v1"
    @test Bool(_H0A_FIXTURE.schema_validation_only)
    @test !Bool(_H0A_FIXTURE.actual_a_positive)
    @test length(_H0A_FIXTURE.cases) == 7
    binding = _h0a_binding()
    endpoints = _h0a_endpoints()
    law = _h0a_equation()
    declaration = G.n06_h0a_present(binding, endpoints,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"), law)
    checked = G.n06_h0a_validate(declaration)
    @test checked.status == :schema_validation_only
    @test checked.authority == :schema_only
    @test checked.compile_calls == checked.provider_calls == checked.solver_calls == 0
    edited = G.n06_h0a_edit(declaration, _h0a_equation(equation="P = eta * scale * E + bias"))
    @test edited.content_hash != declaration.content_hash
    @test G.n06_h0a_validate(edited).status == :schema_validation_only
end

@testset "H0-A contradiction, absent, and exception taxonomy" begin
    binding = _h0a_binding(); endpoints = _h0a_endpoints(); law = _h0a_equation()
    declaration = G.n06_h0a_present(binding, endpoints,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"), law)
    forged = G.N06H0APresentV1(declaration.binding, declaration.endpoints, declaration.law_id,
        declaration.equation, declaration.schema_hash, declaration.canonicalization_hash,
        declaration.profile_hash, _h0a_digest("f"))
    @test G.n06_h0a_validate(forged).status == :fail_closed
    absent = G.n06_h0a_absent(binding, endpoints, "actual A lacks authored coefficient provenance")
    @test G.n06_h0a_validate(absent).status == :terminal_deferred
    @test_throws ArgumentError G.n06_h0a_absent(binding, endpoints, "", :dimensioned_law_missing)
    @test G.n06_h0a_validate(G.n06_h0a_absent(binding, nothing,
        "construction exception", :program_exception)).status == :program_exception
end

@testset "H0-A actual-A source binding remains deferred" begin
    package = _h0a_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    result = G.n06_h0a_bind_actual_a(package, e0)
    @test result.status == :terminal_deferred
    @test result.declaration isa G.N06H0ATypedAbsentV1
    if result.declaration isa G.N06H0ATypedAbsentV1
        @test result.declaration.gap_code in (:external_ref_required, :dimensioned_law_missing)
        @test result.declaration.binding.package_hash == package.candidate_hash
        @test result.declaration.binding.e0_bound_input_hash == e0.bound_input_hash
    end
    @test result.compile_calls == result.provider_calls == result.solver_calls == 0
    if result.declaration isa G.N06H0ATypedAbsentV1
        @test G.n06_h0a_validate(result.declaration).status == :terminal_deferred
    end
end

@testset "H0-A F06 actual pending authority and foreign-target controls" begin
    pending_package = _h0a_actual_package()
    pending_e0 = G.up2_candidate_physical_binding_from_a(pending_package)
    pending = G.n06_h0a_bind_actual_a(pending_package, pending_e0)
    @test pending.status == :terminal_deferred
    @test pending.declaration isa G.N06H0ATypedAbsentV1
    @test pending.declaration.gap_code == :external_ref_required
    @test any(startswith(x, "external_ref_required") for x in pending.gaps)
    pending_admission = G.n06_h0a_admit_present(pending_package, pending_e0,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"), _h0a_equation())
    @test pending_admission isa G.N06H0AResultV1
    @test pending_admission.status == :terminal_deferred

    foreign_package = _h0a_actual_package_foreign_feedback()
    @test_throws ArgumentError G.up2_candidate_physical_binding_from_a(foreign_package)
    valid_package = _h0a_actual_package()
    valid_e0 = G.up2_candidate_physical_binding_from_a(valid_package)
    foreign_g1_ref = G.GenomeContractRef("fusionconceptai://GenomeV5/G1/foreign", "v5",
        _h0a_digest("foreign-schema"), _h0a_digest("foreign-canonical"), "foreign-profile")
    foreign_e0 = _h0a_e0_variant(valid_e0; g1_ref=foreign_g1_ref)
    foreign = G.n06_h0a_admit_present(valid_package, foreign_e0,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"), _h0a_equation())
    @test foreign isa G.N06H0AResultV1
    @test foreign.status == :fail_closed
end

@testset "H0-A trusted package/E0 admission revalidates every identity field" begin
    package = _h0a_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    declaration = _h0a_trusted_declaration(package, e0)
    trusted = G.n06_h0a_validate(declaration, package, e0)
    # The dimensionless helper equation is a deliberate contradiction against
    # the actual G3 effort/flow units, so source-derived unit validation must
    # win over the unrelated authority gaps.
    @test trusted.status == :fail_closed
    @test any(contains("law_input_unit_equation_mismatch"), trusted.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), trusted.errors)
    admitted = G.n06_h0a_admit_present(package, e0, declaration.law_id, declaration.equation)
    @test admitted isa G.N06H0AResultV1
    @test admitted.status == :terminal_deferred
    @test admitted.declaration isa G.N06H0ATypedAbsentV1
    @test admitted.declaration.gap_code == :external_ref_required
    @test !any(contains("g1_occurrence_source_ambiguous"), admitted.errors)

    stale_package = _h0a_trusted_declaration(package, e0;
        binding=G.N06H0AInputBindingV1(e0.candidate_ref, _h0a_digest("stale"),
            e0.schema_hash, e0.canonicalization_hash, e0.profile_hash, e0.binding_hash,
            e0.bound_input_hash, e0.g1_ref, e0.g2_ref, e0.g3_ref,
            e0.g1_component_hash, e0.g2_component_hash, e0.g3_component_hash,
            package.version_axes))
    @test G.n06_h0a_validate(stale_package, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(stale_package, package, e0).status == :fail_closed

    foreign_ref = _h0a_e0_variant(e0; g2_ref=G.GenomeContractRef(
        "fusionconceptai://GenomeV5/G2/foreign", "v5", e0.g2_ref.schema_hash,
        e0.g2_ref.canonicalization_hash, e0.g2_ref.compatibility_profile))
    foreign_decl = _h0a_trusted_declaration(package, e0;
        binding=G._n06_h0a_binding(package, foreign_ref))
    @test G.n06_h0a_validate(foreign_decl, package, foreign_ref).status == :fail_closed
    @test G.n06_h0a_admit_present(foreign_decl, package, foreign_ref).status == :fail_closed

    stale_component = _h0a_e0_variant(e0; g3_component_hash=_h0a_digest("stale-g3"))
    stale_component_decl = _h0a_trusted_declaration(package, e0;
        binding=G._n06_h0a_binding(package, stale_component))
    @test G.n06_h0a_validate(stale_component_decl, package, stale_component).status == :fail_closed
    @test G.n06_h0a_admit_present(stale_component_decl, package, stale_component).status == :fail_closed

    stale_axes = _h0a_e0_variant(e0; version_axes=(g1="stale-g1", g2=e0.version_axes.g2, g3=e0.version_axes.g3))
    stale_axes_decl = _h0a_trusted_declaration(package, e0;
        binding=G._n06_h0a_binding(package, stale_axes))
    @test G.n06_h0a_validate(stale_axes_decl, package, stale_axes).status == :fail_closed
    @test G.n06_h0a_admit_present(stale_axes_decl, package, stale_axes).status == :fail_closed

    first_occ = first(declaration.endpoints.g1_occurrences)
    stale_occ = merge(first_occ, (coefficient=first_occ.coefficient + 1 // 1,))
    stale_endpoints = G.N06H0AEndpointSetV1(
        (stale_occ, declaration.endpoints.g1_occurrences[2], declaration.endpoints.g1_occurrences[3], declaration.endpoints.g1_occurrences[4]),
        declaration.endpoints.g2, declaration.endpoints.g3)
    stale_endpoint_decl = G.n06_h0a_present(declaration.binding, stale_endpoints,
        declaration.law_id, declaration.equation)
    @test G.n06_h0a_validate(stale_endpoint_decl, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(stale_endpoint_decl, package, e0).status == :fail_closed

    wrong_law = G.N06H0APresentV1(declaration.binding, declaration.endpoints,
        G.QualifiedRefV1(declaration.law_id.id, "v0"), declaration.equation,
        declaration.schema_hash, declaration.canonicalization_hash, declaration.profile_hash,
        declaration.content_hash)
    @test G.n06_h0a_validate(wrong_law, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(wrong_law, package, e0).status == :fail_closed

    authored_law_payload = (law_id=declaration.law_id,)
    authored_law_source = G._n06_h0a_provenance(:N06, authored_law_payload,
        "/n06/law/authored", :N06LawV1)
    authored_equation = G.N06H0AUnitEquationV1(declaration.equation.variables,
        declaration.equation.equation, declaration.equation.input_units,
        declaration.equation.output_units, declaration.equation.scale,
        declaration.equation.efficiency, declaration.equation.calibration_provenance,
        declaration.equation.direction, declaration.equation.sign,
        declaration.equation.closure_equation, declaration.equation.owner_scope,
        declaration.equation.owner_account_ids; law_source=authored_law_source,
        law_payload=authored_law_payload,
        closure_relation=declaration.equation.closure_relation)
    correctly_rehashed_wrong_law = G.n06_h0a_present(declaration.binding,
        declaration.endpoints,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/foreign", "v1"),
        authored_equation)
    @test G.n06_h0a_validate(correctly_rehashed_wrong_law, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(correctly_rehashed_wrong_law, package, e0).status == :fail_closed
end

@testset "H0-A source-derived endpoint identity and mutation controls" begin
    package = _h0a_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    projection = G.n06_projection_from_a(package, e0)
    endpoints = G._n06_h0a_endpoint_set(package, projection)
    @test length(endpoints.g1_occurrences) == 4
    @test Set(x.equation_id for x in endpoints.g1_occurrences) ==
        Set(("governing-0", "source-0", "constraint-0"))
    @test all(x.provenance isa G.N06H0ASourceProvenanceV1 for x in endpoints.g1_occurrences)
    @test all(x.equation_provenance.source_path != x.closure_provenance.source_path for x in endpoints.g1_occurrences)
    @test all(x.provenance.source_hash isa G.Digest256 for x in endpoints.g3.entries)
    source_selector = G._N06_G1_ROLE_SELECTORS[:source]
    source_occurrence = only(x for x in endpoints.g1_occurrences if x.selector == source_selector)
    reordered_match = G._n06_h0a_source_role_match(reverse(endpoints.g1_occurrences))
    @test reordered_match[1] == :single
    @test reordered_match[2].selector == source_selector

    # A typed source occurrence unit edit must remain source-identity failure,
    # even though its selector still matches the authored source role.
    edited_unit = G.UnitSignature((1 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1))
    unit_edited_occurrence = merge(source_occurrence, (unit=edited_unit,))
    unit_edited_rows = Tuple(x.selector == source_selector ?
        unit_edited_occurrence : x for x in endpoints.g1_occurrences)
    unit_edited_endpoints = G.N06H0AEndpointSetV1(unit_edited_rows,
        endpoints.g2, endpoints.g3)
    unit_edited_check = G._n06_h0a_validate_endpoint_semantics(package,
        unit_edited_endpoints)
    @test any(contains("g1_occurrence_source_hash_mismatch"), unit_edited_check.errors)
    unit_edited_decl = G.n06_h0a_present(G._n06_h0a_binding(package, e0),
        unit_edited_endpoints,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/unit-edit", "v1"),
        _h0a_equation())
    unit_edited_public = G.n06_h0a_validate(unit_edited_decl, package, e0)
    @test unit_edited_public.status == :fail_closed
    @test any(contains("source_endpoint_identity_mismatch"), unit_edited_public.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), unit_edited_public.errors)
    unit_edited_admitted = G.n06_h0a_admit_present(unit_edited_decl, package, e0)
    @test unit_edited_admitted.status == :fail_closed
    @test any(contains("source_endpoint_identity_mismatch"), unit_edited_admitted.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), unit_edited_admitted.errors)

    # The public declaration overload must classify a legal four-endpoint
    # permutation by source identity, rather than by tuple position.  The
    # permutation remains a fail-closed identity edit because the endpoint
    # content hash is order-sensitive, but it must never become ambiguity.
    reordered_endpoints = G.N06H0AEndpointSetV1(reverse(endpoints.g1_occurrences),
        endpoints.g2, endpoints.g3)
    reordered_decl = G.n06_h0a_present(G._n06_h0a_binding(package, e0),
        reordered_endpoints,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/reorder", "v1"),
        _h0a_equation())
    reordered_public = G.n06_h0a_validate(reordered_decl, package, e0)
    @test reordered_public.status == :fail_closed
    @test any(contains("source_endpoint_identity_mismatch"), reordered_public.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), reordered_public.errors)
    reordered_admitted = G.n06_h0a_admit_present(reordered_decl, package, e0)
    @test reordered_admitted.status == :fail_closed
    @test any(contains("source_endpoint_identity_mismatch"), reordered_admitted.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), reordered_admitted.errors)

    # A copied value with a stale source hash is a real source-derived negative,
    # not a self-consistent synthetic rehash.
    first_occ = first(endpoints.g1_occurrences)
    forged_occ = merge(first_occ, (coefficient=first_occ.coefficient + 1 // 1,))
    forged_endpoints = G.N06H0AEndpointSetV1(
        (forged_occ, endpoints.g1_occurrences[2], endpoints.g1_occurrences[3], endpoints.g1_occurrences[4]),
        endpoints.g2, endpoints.g3)
    forged_check = G._n06_h0a_validate_endpoint_semantics(package, forged_endpoints)
    @test any(contains("g1_occurrence_source_hash_mismatch"), forged_check.errors)
    forged_decl = G.n06_h0a_present(G._n06_h0a_binding(package, e0),
        forged_endpoints,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/source-hash-edit", "v1"),
        _h0a_equation())
    forged_public = G.n06_h0a_validate(forged_decl, package, e0)
    @test forged_public.status == :fail_closed
    @test any(contains("source_endpoint_identity_mismatch"), forged_public.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), forged_public.errors)
    forged_admitted = G.n06_h0a_admit_present(forged_decl, package, e0)
    @test forged_admitted.status == :fail_closed
    @test any(contains("source_endpoint_identity_mismatch"), forged_admitted.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), forged_admitted.errors)

    # Feedback authority is an independent gap; the exact candidate target ref
    # is retained while the typed G3 admission gap remains open.
    base_feedback = first(endpoints.g3.feedback)
    @test G._n06_h0a_feedback_authority(package, base_feedback) == :external_ref_required
    pending_check = G._n06_h0a_validate_endpoint_semantics(package, endpoints)
    @test any(startswith(x, "external_ref_required") for x in pending_check.gaps)
end

@testset "H0-A trusted semantic and G2 provenance controls" begin
    package = _h0a_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    endpoints = G._n06_h0a_endpoint_set(package, G._n06_h0a_project(package, e0))
    region = endpoints.g2.region_payload
    interface = endpoints.g2.interface_payload
    patch = endpoints.g2.boundary_payload
    forged_region = G.G2RegionV2(region.region_id * "-foreign", region.lower, region.upper,
        region.chart_ref, region.embedding_ref, region.field_space_ref, region.boundary_kinds)
    forged_interface = G.G2InterfaceV2(interface.interface_ref, interface.left_region_id,
        interface.right_region_id, interface.axis, interface.coordinate + 1 // 1,
        interface.normal, interface.continuity, interface.transfer_kind)
    forged_patch = G.G2BoundaryFacePatchV2(patch.face, patch.region_id,
        (patch.lower[1] - 1 // 1, patch.lower[2]), patch.upper)
    forged_g2 = merge(endpoints.g2, (region_payload=forged_region,
        interface_payload=forged_interface, boundary_payload=forged_patch))
    forged_g2_endpoints = G.N06H0AEndpointSetV1(endpoints.g1_occurrences,
        forged_g2, endpoints.g3)
    g2_check = G._n06_h0a_validate_endpoint_semantics(package, forged_g2_endpoints)
    @test any(contains("g2_boundary_payload_mismatch"), g2_check.errors)
    @test any(contains("g2_boundary_source_hash_mismatch"), g2_check.errors)
    @test any(contains("g2_region_payload_mismatch"), g2_check.errors)
    @test any(contains("g2_interface_payload_mismatch"), g2_check.errors)
    g2_forged_decl = G.n06_h0a_present(G._n06_h0a_binding(package, e0),
        forged_g2_endpoints, G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/g2", "v1"),
        _h0a_equation())
    @test G.n06_h0a_validate(g2_forged_decl, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(g2_forged_decl, package, e0).status == :fail_closed

    effort = first(p for p in endpoints.g3.ports if p.kind === :effort)
    flow = first(p for p in endpoints.g3.ports if p.kind === :flow)
    power_unit = G._n06_h0a_unit_add(effort.unit, flow.unit)
    semantic_source_selector = G._N06_G1_ROLE_SELECTORS[:source]
    semantic_source_occurrence = only(x for x in endpoints.g1_occurrences if
        x.selector == semantic_source_selector)
    role_entry(effect) = first(e for e in endpoints.g3.entries if e.effect === effect &&
        !(effect === :source && e.port_id === effort.port_id))
    role_port(effect) = first(p for p in endpoints.g3.ports if p.port_id === role_entry(effect).port_id)
    role_coefficients = NamedTuple{(:source,:load,:return,:heat)}((
        role_entry(:source).coefficient, role_entry(:load).coefficient,
        role_entry(:return).coefficient, role_entry(:heat_rejection).coefficient))
    role_directions = NamedTuple{(:source,:load,:return,:heat)}((
        role_port(:source).direction, role_port(:load).direction,
        role_port(:return).direction, role_port(:heat_rejection).direction))
    owner_ids = Tuple(sort!(collect(x.account_id for x in endpoints.g3.accounts)))
    owner_scope = join(owner_ids, "|")
    law_id = G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/source-derived", "v1")
    cal_payload = (scale=1 // 1, efficiency=1 // 1)
    closure_text = "energy_balance=0; thermal_balance=-1"
    closure_payload = (equation=closure_text,)
    closure_relation = (energy=(closure_id="energy-balance", expected_balance=0 // 1,
            account_ids=("source_power", "load_power", "return_power")),
        thermal=(closure_id="thermal-sink", expected_balance=-1 // 1,
            account_ids=("heat_rejection",)))
    law_payload = (law_id=law_id,)
    cal_source = G._n06_h0a_provenance(:N06, cal_payload, "/n06/calibration", :N06CalibrationV1)
    closure_source = G._n06_h0a_provenance(:N06, closure_payload, "/n06/closure", :N06ClosureV1)
    law_source = G._n06_h0a_provenance(:N06, law_payload, "/n06/law", :N06LawV1)
    good = _h0a_equation(equation="P = eta * scale * E", scale=1 // 1,
        efficiency=1 // 1, direction=:out, sign=G._n06_h0a_sign(semantic_source_occurrence.coefficient),
        closure_equation=closure_text, owner_scope=owner_scope, owner_account_ids=owner_ids,
        closure_relation=closure_relation,
        calibration_source=cal_source, closure_source=closure_source, law_source=law_source,
        calibration_payload=cal_payload, closure_payload=closure_payload, law_payload=law_payload,
        role_coefficients=role_coefficients, role_directions=role_directions)
    good = G.N06H0AUnitEquationV1(good.variables, good.equation, (effort.unit, flow.unit),
        (power_unit,), good.scale, good.efficiency, good.calibration_provenance, good.direction,
        good.sign, good.closure_equation, good.owner_scope, good.owner_account_ids;
        calibration_source=good.calibration_source, closure_source=good.closure_source,
        law_source=good.law_source, calibration_payload=good.calibration_payload,
        closure_payload=good.closure_payload, law_payload=good.law_payload,
        role_coefficients=good.role_coefficients, role_directions=good.role_directions,
        closure_relation=good.closure_relation)
    @test isempty(G._n06_h0a_validate_law(good, endpoints; law_id=law_id).errors)
    sign_edit = G.N06H0AUnitEquationV1(good.variables, good.equation,
        good.input_units, good.output_units, good.scale, good.efficiency,
        good.calibration_provenance, good.direction, -good.sign,
        good.closure_equation, good.owner_scope, good.owner_account_ids;
        calibration_source=good.calibration_source, closure_source=good.closure_source,
        law_source=good.law_source, calibration_payload=good.calibration_payload,
        closure_payload=good.closure_payload, law_payload=good.law_payload,
        role_coefficients=good.role_coefficients, role_directions=good.role_directions,
        closure_relation=good.closure_relation)
    sign_edit_check = G._n06_h0a_validate_law(sign_edit, endpoints; law_id=law_id)
    @test any(contains("law_sign_source_mismatch"), sign_edit_check.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), sign_edit_check.errors)
    sign_edit_decl = G.n06_h0a_present(G._n06_h0a_binding(package, e0),
        endpoints, law_id, sign_edit)
    sign_edit_public = G.n06_h0a_validate(sign_edit_decl, package, e0)
    @test sign_edit_public.status == :fail_closed
    @test any(contains("law_sign_source_mismatch"), sign_edit_public.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), sign_edit_public.errors)
    sign_edit_admitted = G.n06_h0a_admit_present(sign_edit_decl, package, e0)
    @test sign_edit_admitted.status == :fail_closed
    @test any(contains("law_sign_source_mismatch"), sign_edit_admitted.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), sign_edit_admitted.errors)
    bad_calibration = _h0a_equation(calibration_source=cal_source,
        closure_source=closure_source, law_source=law_source,
        calibration_payload=(scale=2 // 1, efficiency=1 // 1),
        closure_payload=closure_payload, law_payload=law_payload,
        closure_relation=closure_relation, role_coefficients=role_coefficients,
        role_directions=role_directions)
    bad_calibration_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0),
        endpoints, law_id, bad_calibration)
    @test G.n06_h0a_validate(bad_calibration_decl, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(bad_calibration_decl, package, e0).status == :fail_closed
    bad_closure = _h0a_equation(calibration_source=cal_source,
        closure_source=closure_source, law_source=law_source,
        calibration_payload=cal_payload, closure_payload=(equation="unrelated",),
        law_payload=law_payload, closure_relation=closure_relation,
        role_coefficients=role_coefficients, role_directions=role_directions)
    bad_closure_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0),
        endpoints, law_id, bad_closure)
    @test G.n06_h0a_validate(bad_closure_decl, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(bad_closure_decl, package, e0).status == :fail_closed
    malformed_relation = _h0a_equation(calibration_source=cal_source,
        closure_source=closure_source, law_source=law_source,
        calibration_payload=cal_payload, closure_payload=closure_payload,
        law_payload=law_payload, closure_relation=(energy="malformed", thermal=()),
        role_coefficients=role_coefficients, role_directions=role_directions)
    malformed_relation_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0),
        endpoints, law_id, malformed_relation)
    @test G.n06_h0a_admit_present(malformed_relation_decl, package, e0).status == :fail_closed
    bad_law_payload = (law_id=G.QualifiedRefV1(
        "fusionconceptai://GenomeV5/N06/law/foreign", "v1"),)
    bad_law = _h0a_equation(calibration_source=cal_source,
        closure_source=closure_source, law_source=law_source,
        calibration_payload=cal_payload, closure_payload=closure_payload,
        law_payload=bad_law_payload, closure_relation=closure_relation,
        role_coefficients=role_coefficients, role_directions=role_directions)
    bad_law_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0),
        endpoints, law_id, bad_law)
    @test G.n06_h0a_validate(bad_law_decl, package, e0).status == :fail_closed
    @test G.n06_h0a_admit_present(bad_law_decl, package, e0).status == :fail_closed
    bad_roles_public = merge(role_coefficients, (load=role_coefficients.load + 1 // 1,))
    bad_role_equation = G.N06H0AUnitEquationV1(good.variables, good.equation,
        good.input_units, good.output_units, good.scale, good.efficiency,
        good.calibration_provenance, good.direction, good.sign, good.closure_equation,
        good.owner_scope, good.owner_account_ids; calibration_source=good.calibration_source,
        closure_source=good.closure_source, law_source=good.law_source,
        calibration_payload=good.calibration_payload, closure_payload=good.closure_payload,
        law_payload=good.law_payload, closure_relation=good.closure_relation,
        role_coefficients=bad_roles_public, role_directions=good.role_directions)
    bad_role_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0), endpoints,
        law_id, bad_role_equation)
    @test G.n06_h0a_admit_present(bad_role_decl, package, e0).status == :fail_closed
    bad_direction_map = merge(role_directions, (load=:out,))
    bad_direction_equation = G.N06H0AUnitEquationV1(good.variables, good.equation,
        good.input_units, good.output_units, good.scale, good.efficiency,
        good.calibration_provenance, good.direction, good.sign, good.closure_equation,
        good.owner_scope, good.owner_account_ids; calibration_source=good.calibration_source,
        closure_source=good.closure_source, law_source=good.law_source,
        calibration_payload=good.calibration_payload, closure_payload=good.closure_payload,
        law_payload=good.law_payload, closure_relation=good.closure_relation,
        role_coefficients=good.role_coefficients, role_directions=bad_direction_map)
    bad_direction_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0), endpoints,
        law_id, bad_direction_equation)
    @test G.n06_h0a_admit_present(bad_direction_decl, package, e0).status == :fail_closed
    bad_input_equation = G.N06H0AUnitEquationV1(good.variables, good.equation,
        (flow.unit, effort.unit), good.output_units, good.scale, good.efficiency,
        good.calibration_provenance, good.direction, good.sign, good.closure_equation,
        good.owner_scope, good.owner_account_ids; calibration_source=good.calibration_source,
        closure_source=good.closure_source, law_source=good.law_source,
        calibration_payload=good.calibration_payload, closure_payload=good.closure_payload,
        law_payload=good.law_payload, closure_relation=good.closure_relation,
        role_coefficients=good.role_coefficients, role_directions=good.role_directions)
    bad_input_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0), endpoints,
        law_id, bad_input_equation)
    bad_input_check = G._n06_h0a_validate_law(bad_input_equation, endpoints; law_id=law_id)
    @test any(contains("law_input_unit_equation_mismatch"), bad_input_check.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), bad_input_check.errors)
    bad_input_public = G.n06_h0a_validate(bad_input_decl, package, e0)
    @test bad_input_public.status == :fail_closed
    @test any(contains("law_input_unit_equation_mismatch"), bad_input_public.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), bad_input_public.errors)
    bad_input_admitted = G.n06_h0a_admit_present(bad_input_decl, package, e0)
    @test bad_input_admitted.status == :fail_closed
    @test any(contains("law_input_unit_equation_mismatch"), bad_input_admitted.errors)
    @test !any(contains("g1_occurrence_source_ambiguous"), bad_input_admitted.errors)
    bad_output_equation = G.N06H0AUnitEquationV1(good.variables, good.equation,
        good.input_units, (effort.unit,), good.scale, good.efficiency,
        good.calibration_provenance, good.direction, good.sign, good.closure_equation,
        good.owner_scope, good.owner_account_ids; calibration_source=good.calibration_source,
        closure_source=good.closure_source, law_source=good.law_source,
        calibration_payload=good.calibration_payload, closure_payload=good.closure_payload,
        law_payload=good.law_payload, closure_relation=good.closure_relation,
        role_coefficients=good.role_coefficients, role_directions=good.role_directions)
    bad_output_decl = G.n06_h0a_present(G._n06_h0a_binding(package,e0), endpoints,
        law_id, bad_output_equation)
    @test G.n06_h0a_admit_present(bad_output_decl, package, e0).status == :fail_closed
    @test any(contains("calibration_scale_mismatch"), G._n06_h0a_validate_law(
        _h0a_equation(scale=2 // 1, efficiency=1 // 1, calibration_source=cal_source,
            closure_source=closure_source, law_source=law_source,
            calibration_payload=cal_payload, closure_payload=closure_payload,
            law_payload=law_payload, role_coefficients=role_coefficients,
            role_directions=role_directions), endpoints; law_id=law_id).errors)
    @test any(contains("calibration_efficiency_mismatch"), G._n06_h0a_validate_law(
        _h0a_equation(scale=1 // 1, efficiency=1 // 2, calibration_source=cal_source,
            closure_source=closure_source, law_source=law_source,
            calibration_payload=cal_payload, closure_payload=closure_payload,
            law_payload=law_payload, role_coefficients=role_coefficients,
            role_directions=role_directions), endpoints; law_id=law_id).errors)
    @test any(contains("closure_equation_mismatch"), G._n06_h0a_validate_law(
        _h0a_equation(closure_equation="wrong closure", calibration_source=cal_source,
            closure_source=closure_source, law_source=law_source,
            calibration_payload=cal_payload, closure_payload=closure_payload,
            law_payload=law_payload, role_coefficients=role_coefficients,
            role_directions=role_directions), endpoints; law_id=law_id).errors)
    direction_check = G._n06_h0a_validate_law(_h0a_equation(direction=:in, calibration_source=cal_source,
            closure_source=closure_source, law_source=law_source, calibration_payload=cal_payload,
            closure_payload=closure_payload, law_payload=law_payload,
            role_coefficients=role_coefficients, role_directions=role_directions), endpoints;
            law_id=law_id).errors
    @test any(contains("law_direction_source_mismatch"), direction_check)
    @test any(contains("law_owner_scope_mismatch"), G._n06_h0a_validate_law(
        _h0a_equation(owner_scope="foreign-owner", calibration_source=cal_source,
            closure_source=closure_source, law_source=law_source,
            calibration_payload=cal_payload, closure_payload=closure_payload,
            law_payload=law_payload, role_coefficients=role_coefficients,
            role_directions=role_directions), endpoints; law_id=law_id).errors)
    bad_roles = merge(role_coefficients, (load=role_coefficients.load + 1 // 1,))
    @test any(contains("role_coefficient_mismatch"), G._n06_h0a_validate_law(
        _h0a_equation(calibration_source=cal_source, closure_source=closure_source,
            law_source=law_source, calibration_payload=cal_payload,
            closure_payload=closure_payload, law_payload=law_payload,
            role_coefficients=bad_roles, role_directions=role_directions), endpoints;
            law_id=law_id).errors)
end

@testset "H0-A typed input mismatch is fail-closed" begin
    @test_throws ArgumentError G.N06H0AEndpointSetV1(
        ((selector=(ledger_id="x", equation_id="e", port_side=:out, port_index=1), equation_id="e", closure_id="c"),),
        (region_id="r", interface_side=:left, boundary_face=:x_min, boundary_locator="/g2/0"),
        (selected_flow_link_id="l", ports=(), accounts=(), entries=(), closures=(), links=(), feedback=()))
    binding = _h0a_binding()
    @test G.n06_h0a_bind_actual_a(nothing, nothing).status == :program_exception
    @test G.n06_h0a_validate(G.n06_h0a_absent(binding, nothing,
        "known source binding gap", :source_binding_missing)).status == :terminal_deferred
end

@testset "H0-A upstream taxonomy is typed before public admission" begin
    known = G.N06H0AKnownGapError(:source_binding_missing, "typed source gap")
    contradiction = G.N06H0AConflictError(:source_binding_contradiction, "typed source contradiction")
    unexpected = G._n06_h0a_translate_upstream(ArgumentError("unexpected upstream error"), :test)
    @test known isa G.N06H0AKnownGapError
    @test G._n06_h0a_classify_error(known) == :terminal_deferred
    @test contradiction isa G.N06H0AConflictError
    @test G._n06_h0a_classify_error(contradiction) == :fail_closed
    @test unexpected isa G.N06H0AProgramError
    @test G._n06_h0a_classify_error(unexpected) == :program_exception
    package = _h0a_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    known_public = G.n06_h0a_admit_present(package, e0,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"), _h0a_equation())
    @test known_public isa G.N06H0AResultV1
    @test known_public.status == :terminal_deferred
    foreign_ref = G.GenomeContractRef("fusionconceptai://GenomeV5/G1/foreign", "v5",
        _h0a_digest("foreign-schema"), _h0a_digest("foreign-canonical"), "foreign-profile")
    contradiction_public = G.n06_h0a_admit_present(package,
        _h0a_e0_variant(e0; g1_ref=foreign_ref),
        G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"), _h0a_equation())
    @test contradiction_public isa G.N06H0AResultV1
    @test contradiction_public.status == :fail_closed
    @test contradiction_public.declaration === nothing

    endpoints = G._n06_h0a_endpoint_set(package, G._n06_h0a_project(package,e0))
    malformed_calibration = (scale=(unexpected=1,), efficiency=1 // 1)
    malformed_calibration_source = G._n06_h0a_provenance(:N06,
        malformed_calibration, "/n06/calibration/malformed", :N06CalibrationV1)
    malformed_equation = _h0a_equation(calibration_source=malformed_calibration_source,
        calibration_payload=malformed_calibration)
    malformed_declaration = G.n06_h0a_present(G._n06_h0a_binding(package,e0),
        endpoints, G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"),
        malformed_equation)
    malformed_validated = G.n06_h0a_validate(malformed_declaration, package, e0)
    @test malformed_validated isa G.N06H0AResultV1
    @test malformed_validated.status == :program_exception
    @test malformed_validated.declaration === nothing
    malformed_admitted = G.n06_h0a_admit_present(malformed_declaration, package, e0)
    @test malformed_admitted isa G.N06H0AResultV1
    @test malformed_admitted.status == :program_exception
    @test malformed_admitted.declaration === nothing

    malformed_closure_payload = (equation=(unexpected=1,),)
    malformed_closure_source = G._n06_h0a_provenance(:N06,
        malformed_closure_payload, "/n06/closure/malformed", :N06ClosureV1)
    malformed_closure_equation = _h0a_equation(closure_source=malformed_closure_source,
        closure_payload=malformed_closure_payload)
    malformed_closure_declaration = G.n06_h0a_present(G._n06_h0a_binding(package,e0),
        endpoints, G.QualifiedRefV1("fusionconceptai://GenomeV5/N06/law/h0a", "v1"),
        malformed_closure_equation)
    malformed_closure_validated = G.n06_h0a_validate(malformed_closure_declaration, package, e0)
    @test malformed_closure_validated isa G.N06H0AResultV1
    @test malformed_closure_validated.status == :program_exception
    @test malformed_closure_validated.declaration === nothing
    malformed_closure_admitted = G.n06_h0a_admit_present(malformed_closure_declaration, package, e0)
    @test malformed_closure_admitted isa G.N06H0AResultV1
    @test malformed_closure_admitted.status == :program_exception
    @test malformed_closure_admitted.declaration === nothing
end
