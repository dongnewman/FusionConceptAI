using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _N06_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n06_source_field_ledger_mapping_fixtures.json"), String))

function _n06_fixture_selector_key(selector)
    (ledger_id=String(selector.ledger_id), equation_id=String(selector.equation_id),
        port_side=Symbol(String(selector.port_side)), port_index=Int(selector.port_index))
end

function _n06_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n06_actual_g1(base, candidate)
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

function _n06_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _n06_actual_g3(base, candidate, g1_ref, g2_ref)
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

function _n06_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/n06-a", "v5")
    g1 = _n06_actual_g1(_n06_child_fixture("G1"), candidate)
    g2 = _n06_actual_g2(_n06_child_fixture("G2"), candidate)
    base_g3 = _n06_child_fixture("G3")
    g3 = _n06_actual_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n06_specs()
    Tuple(G.N06MutationSpecV1(String(x.id), Symbol(String(x.class_id)),
        String(x.field_path), String(x.source_locator), Symbol(String(x.source_type)),
        Symbol(String(x.mutation_kind)), Symbol(String(x.expected_error)))
        for x in _N06_FIXTURE.mutations)
end

function _n06_valid_join(package, projection)
    _, _, _, region, patch, network, _, _, link, _ = G._n06_actual_fields(package)
    role_kinds = Dict(:source => (:effort, :flow), :field => (:load,),
        :return => (:return,), :heat => (:heat_sink,))
    selectors = _N06_FIXTURE.g1_occurrence_selectors
    Tuple(begin
        role = Symbol(String(selector.role))
        kinds = role_kinds[role]
        selected_equation = G._n06_unique_match(package.g1.payload.equation_plan.equations,
            e -> e.equation_id == String(selector.equation_id),
            "test G1 selected equation")
        selected = G._n06_unique_match(selected_equation.occurrences,
            o -> o.ledger_id == String(selector.ledger_id) &&
                o.equation_id == String(selector.equation_id) &&
                String(o.port_side) == String(selector.port_side) &&
                o.port_index == Int(selector.port_index),
            "test G1 selected occurrence")
        selected_closure = G._n06_unique_match(package.g1.payload.grammar_profile.closures,
            c -> c.closure_id == selected_equation.closure_ref,
            "test G1 equation closure")
        key = (ledger_id=selected.ledger_id, equation_id=selected.equation_id,
            port_side=selected.port_side, port_index=selected.port_index)
        port = G._n06_unique_match(network.resource_ports,
            p -> role === :source ? p.kind == :flow : p.kind in kinds,
            "test role resource port")
        partner_port = role === :source ? G._n06_unique_match(network.resource_ports,
            p -> p.kind == :effort, "test power effort partner") : nothing
        role_entry = G._n06_unique_match(network.entries,
            e -> e.port_id == port.port_id, "test role entry")
        selected_g3closure = G._n06_unique_match(network.closures,
            c -> role_entry.account_id in c.account_ids, "test role closure")
        selected_patch = G._n06_unique_match(package.g2.plan.exterior.boundary_patches,
            p -> p.region_id == region.region_id && p.face == patch.face,
            "test selected G2 boundary")
        boundary_index = G._n06_index_for(package.g2.plan.exterior.boundary_patches,
            p -> (p.region_id, p.face), (selected_patch.region_id, selected_patch.face),
            "test selected G2 boundary")
        account = G._n06_unique_match(network.accounts,
            a -> a.account_id == role_entry.account_id, "test role account")
        conversion = G.N06DimensionedConversionV1(
            G.QualifiedRefV1("fusionconceptai://law/n06/unit-conversion-$(role)", "v1"),
            selected.unit, role_entry.unit, 1 // 1, 0 // 1,
            role === :source ? :power_from_effort_flow : :same_dimension,
            "authored N06 source audit")
        G.N06SourceFieldLedgerJoinV1(role, selected_equation.equation_id, key, selected_closure.closure_id,
            region.region_id, patch.face,
            "/g2/plan/exterior/boundary_patches/$(boundary_index - 1)/$(patch.face)",
            port.port_id, role_entry.account_id, role_entry.entry_id,
            selected_g3closure.closure_id, account.owner,
            Tuple(a.account_id for a in network.accounts if a.owner == account.owner),
            "$(region.region_id):$(patch.face):$(selected_g3closure.closure_id):$(role_entry.entry_id)",
            conversion, "candidate-owned authored mapping";
            partner_port_id=partner_port === nothing ? nothing : partner_port.port_id,
            link_id=role === :source ? link.link_id : nothing)
    end for selector in selectors)
end

function _n06_rebuild_join(join; owner_account_ids=join.owner_account_ids,
                           conversion=join.conversion,
                           partner_port_id=join.g3_partner_port_id,
                           occurrence_key=join.g1_occurrence_key,
                           link_id=join.g3_link_id)
    G.N06SourceFieldLedgerJoinV1(join.role, join.g1_equation_id,
        occurrence_key, join.g1_closure_id, join.g2_region_id,
        join.g2_boundary_face, join.g2_boundary_locator, join.g3_port_id,
        join.g3_account_id, join.g3_entry_id, join.g3_closure_id,
        join.owner_scope, owner_account_ids, join.energy_boundary, conversion,
        join.provenance; partner_port_id=partner_port_id,
        link_id=link_id)
end

function _n06_mapping_error_set(package, projection, joins)
    Set(String.(G._n06_join_errors(package, joins; projection=projection)))
end

function _n06_expect_new_mapping_error(package, e0, projection, baseline_errors,
                                       joins, expected_code)
    errors = _n06_mapping_error_set(package, projection, joins)
    @test expected_code in setdiff(errors, baseline_errors)
    @test_throws ArgumentError G.n06_mapping_from_a(package, e0, joins)
end

function _n06_with_network(package, network)
    g3 = package.g3
    realization = G.RealizationGenomeV5(g3.realization.contract_binding, network,
        g3.realization.material_domains, g3.realization.manufacturing_domains;
        provider_match=:no_match)
    rebuilt = G.RealizationControlGenomeV5(g3.contract_binding, realization,
        g3.control, g3.binding)
    G.integrate_genome_v5(package.g1, package.g2, rebuilt;
        candidate_ref=package.candidate_ref)
end

@testset "UP2-00E N06 actual A authored sample and typed boundary" begin
    @test String(_N06_FIXTURE.schema_id) == "GenomeV5/UP2/N06SourceFieldLedgerMappingV1"
    @test String(_N06_FIXTURE.version) == "v1"
    @test Bool(_N06_FIXTURE.schema_validation_only)
    @test length(_N06_FIXTURE.mutations) == 5
    @test haskey(G._N06_G1_ROLE_SELECTORS, :source)
    @test G._N06_G1_ROLE_SELECTORS[:source].equation_id == "governing-0"
    for selector in _N06_FIXTURE.g1_occurrence_selectors
        role = Symbol(String(selector.role))
        @test G._N06_G1_ROLE_SELECTORS[role] == _n06_fixture_selector_key(selector)
    end
    package = _n06_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    projection = G.n06_projection_from_a(package, e0)
    @test projection.candidate_ref == package.candidate_ref
    @test projection.package_hash == package.candidate_hash
    @test projection.e0_bound_input_hash == e0.bound_input_hash
    @test !isempty(projection.g1_equation_id)
    @test projection.g1_occurrence_key.equation_id == projection.g1_equation_id
    @test projection.g3_selected_flow_link_id ==
        G._n06_actual_fields(package)[9].link_id
    @test !isempty(projection.g1_closure_id)
    @test !isempty(projection.g2_region_id)
    @test !isempty(projection.g2_boundary_locator)
    @test length(projection.fields) == 5
    @test projection.authority_gaps == Tuple(String.( _N06_FIXTURE.expected_authority_gaps))
    @test projection.fields[1].value isa G.N06TextValueV1
    @test projection.fields[4].value isa G.N06RationalValueV1
    @test projection.fields[5].value isa G.N06SymbolValueV1
    joins = _n06_valid_join(package, projection)
    @test joins !== nothing
    baseline_errors = _n06_mapping_error_set(package, projection, joins)
    @test "conversion_same_dimension_mismatch" in baseline_errors
    @test_throws ArgumentError G.n06_mapping_from_a(package, e0, joins)
    # The actual A package has no authoritative cross-layer law, so a mapping
    # cannot be admitted merely because the authored sample is structurally
    # populated.
    @test G.n06_mapping_admission(package, e0).status == :terminal_deferred
end

@testset "UP2-00E N06 typed occurrence identity index" begin
    typed_a = ("energy", "governing-0", :output, Int64(1))
    typed_b = ("energy", "governing-0", :output, Int64(2))
    typed_index = G._n06_unique_index((typed_a, typed_b), identity,
        "test typed occurrence keys")
    @test typed_index[typed_a] === typed_a
    @test typed_index[typed_b] === typed_b
    @test_throws ArgumentError G._n06_unique_index((typed_a, typed_a), identity,
        "test duplicate typed occurrence keys")
end

@testset "UP2-00E N06 source-derived mutation controls" begin
    package = _n06_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    projection = G.n06_projection_from_a(package, e0)
    for row in _N06_FIXTURE.mutations
        spec = first(x for x in _n06_specs() if x.id == String(row.id))
        result = G.n06_validate_mutation(package, e0, projection, spec)
        @test result.mutated_input_hash != result.input_hash
        @test result.error_path == spec.field_path
        @test result.status == Symbol(String(row.expected_status))
        @test result.error_code == Symbol(String(row.expected_error))
        @test result.compile_calls == result.provider_calls == result.solver_calls == 0
        @test result.original_value != result.mutated_value
    end
    row = first(x for x in _n06_specs() if x.id == "N06-01")
    forged_oracle = G.N06MutationSpecV1(row.id, row.class_id, row.field_path,
        row.source_locator, row.source_type, row.mutation_kind, :terminal_deferred)
    @test G.n06_validate_mutation(package, e0, projection, forged_oracle).error_code == :invalid_ref
end

@testset "UP2-00E shared owner and E0 identity boundary" begin
    package = _n06_actual_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    projection = G.n06_projection_from_a(package, e0)
    @test G.n06_mapping_admission(package, e0).status == :terminal_deferred
    @test "owner_scope_mapping_missing_shared_owner_is_legal" in projection.authority_gaps
    foreign = G.N06SourceFieldLedgerMappingV1(projection.candidate_ref,
        G.Digest256(repeat("f", 64)), projection.e0_bound_input_hash,
        projection.g1_ref, projection.g2_ref, projection.g3_ref, package.version_axes,
        (), G.n06_schema_hash(), G.n06_canonicalization_hash(), G.n06_profile_hash(),
        G.Digest256(repeat("e", 64)))
    @test G.n06_mapping_admission(package, e0, foreign).status == :fail_closed
    empty_mapping = G.N06SourceFieldLedgerMappingV1(projection.candidate_ref,
        package.candidate_hash, e0.bound_input_hash, projection.g1_ref, projection.g2_ref,
        projection.g3_ref, package.version_axes, (), G.n06_schema_hash(),
        G.n06_canonicalization_hash(), G.n06_profile_hash(), G.Digest256(repeat("a", 64)))
    @test G.n06_mapping_admission(package, e0, empty_mapping).status == :fail_closed
    @test length(_N06_FIXTURE.mapping_negative_controls) == 5
    expected_static_negative_controls = Set((
        "duplicate_resource_port_id", "forged_source_locator", "forged_source_type",
        "same_dimension_exponent_mismatch", "missing_power_flow_partner",
        "foreign_valid_flow_link", "reordered_network_dynamic_path",
        "wrong_mutation_kind_for_target", "relabeled_mutation_id",
        "detached_projection", "detached_g1_occurrence", "foreign_e0_binding",
        "missing_source_selector", "wrong_source_selector"))
    actual_static_negative_controls = Set(String.( _N06_FIXTURE.static_negative_controls))
    @test length(_N06_FIXTURE.static_negative_controls) == length(expected_static_negative_controls)
    @test length(actual_static_negative_controls) == length(_N06_FIXTURE.static_negative_controls)
    @test actual_static_negative_controls == expected_static_negative_controls
    joins = _n06_valid_join(package, projection)
    baseline_errors = _n06_mapping_error_set(package, projection, joins)
    duplicate_scope = _n06_rebuild_join(joins[1];
        owner_account_ids=(joins[1].owner_account_ids[1],
            joins[1].owner_account_ids[1]))
    _n06_expect_new_mapping_error(package, e0, projection, baseline_errors,
        (duplicate_scope, joins[2], joins[3], joins[4]),
        "owner_scope_accounts_duplicate")
    c = joins[1].conversion
    derived_offset = G.N06DimensionedConversionV1(c.law_id, c.from_unit,
        c.to_unit, c.scale, 1 // 1, c.dimension_rule, c.provenance)
    bad_conversion = _n06_rebuild_join(joins[1]; conversion=derived_offset)
    _n06_expect_new_mapping_error(package, e0, projection, baseline_errors,
        (bad_conversion, joins[2], joins[3], joins[4]),
        "conversion_offset_invalid_for_derived_dimension")
    missing_flow = _n06_rebuild_join(joins[1]; partner_port_id=nothing)
    _n06_expect_new_mapping_error(package, e0, projection, baseline_errors,
        (missing_flow, joins[2], joins[3], joins[4]),
        "power_flow_partner_missing")
    foreign_link_join = _n06_rebuild_join(joins[1]; link_id="foreign-link")
    _n06_expect_new_mapping_error(package, e0, projection, baseline_errors,
        (foreign_link_join, joins[2], joins[3], joins[4]),
        "power_flow_link_identity_mismatch")
    detached_g1 = _n06_rebuild_join(joins[2]; occurrence_key=joins[1].g1_occurrence_key)
    _n06_expect_new_mapping_error(package, e0, projection, baseline_errors,
        (joins[1], detached_g1, joins[3], joins[4]),
        "g1_occurrence_not_bound_to_role_selector")
    @test all(x -> String(x) in Tuple(String.( _N06_FIXTURE.mapping_negative_controls)),
        ("duplicate_owner_account_scope", "nonzero_derived_conversion_offset",
         "missing_power_flow_partner", "foreign_valid_flow_link", "detached_g1_occurrence"))
    foreign_link = G.G3ControlResourceLinkV2("foreign", "controller", "field_sensor",
        "source_command", "load", "open_fault")
    @test_throws ArgumentError G._n06_unique_match((foreign_link,),
        x -> x.resource_port_id == "source_flow", "test exact selected flow link")
    row = first(x for x in _n06_specs() if x.id == "N06-01")
    forged_locator = G.N06MutationSpecV1(row.id, row.class_id, row.field_path,
        "forged.locator::String", row.source_type, row.mutation_kind,
        row.expected_error)
    @test_throws ArgumentError G.n06_validate_mutation(package, e0, projection, forged_locator)
    forged_type = G.N06MutationSpecV1(row.id, row.class_id, row.field_path,
        row.source_locator, :symbol, row.mutation_kind, row.expected_error)
    @test_throws ArgumentError G.n06_validate_mutation(package, e0, projection, forged_type)
    forged_kind = G.N06MutationSpecV1(row.id, row.class_id, row.field_path,
        row.source_locator, row.source_type, :wrong_resource_kind, row.expected_error)
    @test_throws ArgumentError G.n06_validate_mutation(package, e0, projection, forged_kind)
    relabeled = G.N06MutationSpecV1("relabeled-receipt", row.class_id, row.field_path,
        row.source_locator, row.source_type, row.mutation_kind, row.expected_error)
    @test G.n06_validate_mutation(package, e0, projection, relabeled).mutation_id ==
        "relabeled-receipt"
    detached_projection = G.N06LedgerProjectionV1(projection.candidate_ref,
        projection.package_hash, projection.e0_bound_input_hash, projection.g1_ref,
        projection.g2_ref, projection.g3_ref, projection.g1_equation_id,
        projection.g1_occurrence_key, projection.g1_occurrence_keys,
        projection.g1_closure_id, projection.g2_region_id, projection.g2_boundary_face,
        projection.g2_boundary_locator, "foreign-link", projection.network,
        projection.fields, projection.authority_gaps, projection.projection_hash)
    @test_throws ArgumentError G.n06_validate_mutation(package, e0,
        detached_projection, row)
    foreign_e0 = G.UP2CandidatePhysicalBindingV1(
        G.QualifiedRefV1("fusionconceptai://candidate/foreign", "v5"), e0.package_hash,
        e0.g1_ref, e0.g2_ref, e0.g3_ref, e0.g1_component_hash,
        e0.g2_component_hash, e0.g3_component_hash, e0.version_axes,
        e0.schema_hash, e0.canonicalization_hash, e0.profile_hash,
        nothing, nothing, e0.gaps)
    @test_throws ArgumentError G.n06_validate_mutation(package, foreign_e0,
        projection, row)
    @test all(x -> String(x) in Tuple(String.( _N06_FIXTURE.static_negative_controls)),
        ("relabeled_mutation_id", "detached_projection", "foreign_e0_binding"))
    @test "missing_source_selector" in Tuple(String.( _N06_FIXTURE.static_negative_controls))
    saved_source_selector = G._N06_G1_ROLE_SELECTORS[:source]
    missing_selector_error = nothing
    try
        delete!(G._N06_G1_ROLE_SELECTORS, :source)
        missing_selector_error = try
            G.n06_projection_from_a(package, e0)
            nothing
        catch err
            err
        end
    finally
        G._N06_G1_ROLE_SELECTORS[:source] = saved_source_selector
    end
    @test missing_selector_error isa ArgumentError
    missing_selector_text = missing_selector_error === nothing ? "" :
        sprint(showerror, missing_selector_error)
    @test occursin("authored governing selector is missing", missing_selector_text)
    @test "wrong_source_selector" in
        Tuple(String.( _N06_FIXTURE.static_negative_controls))
    saved_source_selector = G._N06_G1_ROLE_SELECTORS[:source]
    wrong_selector_error = nothing
    try
        G._N06_G1_ROLE_SELECTORS[:source] =
            (ledger_id="energy", equation_id="governing-0",
                port_side=:output, port_index=99)
        wrong_selector_error = try
            G.n06_projection_from_a(package, e0)
            nothing
        catch err
            err
        end
    finally
        G._N06_G1_ROLE_SELECTORS[:source] = saved_source_selector
    end
    @test wrong_selector_error isa ArgumentError
    wrong_selector_text = wrong_selector_error === nothing ? "" :
        sprint(showerror, wrong_selector_error)
    @test occursin("G1 authored governing occurrence has no source match",
        wrong_selector_text)
    @test "wrong_mutation_kind_for_target" in
        Tuple(String.( _N06_FIXTURE.static_negative_controls))
    ports = package.g3.realization.network.resource_ports
    duplicate_port = G.G3ResourcePortV2(ports[1].port_id, ports[2].kind,
        ports[2].direction, ports[2].unit, ports[2].account_id)
    @test_throws ArgumentError G.G3ResourceNetworkV2(package.g3.realization.network.components,
        (ports[1], duplicate_port, ports[3:end]...), package.g3.realization.network.accounts,
        package.g3.realization.network.entries, package.g3.realization.network.closures)
    c = joins[2].conversion
    same_dimension = G.N06DimensionedConversionV1(c.law_id, c.from_unit,
        c.to_unit, c.scale, c.offset, :same_dimension, c.provenance)
    mismatched_dimension = _n06_rebuild_join(joins[2]; conversion=same_dimension)
    mismatched_errors = _n06_mapping_error_set(package, projection,
        (joins[1], mismatched_dimension, joins[3], joins[4]))
    @test "conversion_same_dimension_mismatch" in mismatched_errors
    # This is a duplicate baseline mismatch control, not an additional
    # mapping credit; it is retained to ensure the typed code remains explicit.
    @test isempty(setdiff(mismatched_errors, baseline_errors))
    @test_throws ArgumentError G.n06_mapping_from_a(package, e0,
        (joins[1], mismatched_dimension, joins[3], joins[4]))
    reversed = G.G3ResourceNetworkV2(package.g3.realization.network.components,
        reverse(package.g3.realization.network.resource_ports),
        package.g3.realization.network.accounts, package.g3.realization.network.entries,
        package.g3.realization.network.closures)
    reordered = _n06_with_network(package, reversed)
    reordered_fields = G._n06_actual_fields(reordered)[end]
    @test reordered_fields[1].value.value == "source_effort"
    @test reordered_fields[1].field_path != projection.fields[1].field_path
end
