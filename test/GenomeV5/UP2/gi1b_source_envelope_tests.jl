using Test
using JSON3
using Serialization

const G = FusionConceptAI
const GI1B_FIXTURE = joinpath(@__DIR__, "gi1b_source_envelope_fixtures.json")

function _gi1b_test_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _gi1b_test_package(candidate_id="fusionconceptai://candidate/gi1b-a")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    base_g1 = _gi1b_test_child_fixture("G1")
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
    base_g2 = _gi1b_test_child_fixture("G2")
    g2_ref = G.GenomeContractRef(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/"),
        "v5", base_g2.contract_ref.schema_hash, base_g2.contract_ref.canonicalization_hash,
        base_g2.contract_ref.compatibility_profile)
    g2 = G.FieldGeometryGenomeV5(g2_ref, base_g2.region_interface, base_g2.plan,
        base_g2.grammar_profile, base_g2.version_axes)
    base_g3 = _gi1b_test_child_fixture("G3")
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

function _gi1b_test_declaration(package)
    candidate = package.candidate_ref
    g1_ref, g2_ref, g3_ref = package.g1.contract_ref, package.g2.contract_ref,
        package.g3.contract_binding.contract_ref
    interface = package.g2.region_interface.interfaces[1]
    occurrences = [o for e in package.g1.payload.equation_plan.equations for o in e.occurrences]
    left_o, right_o = occurrences[1], occurrences[2]
    unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
    left_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :left), "v1")
    right_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :right), "v1")
    left_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(left_ref, unit), :authoritative)
    right_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(right_ref, unit), :authoritative)
    left = G.UP2N05FluxEndpointV1(left_ref, "gi1b-left", :left, 1, left_unit,
        G.UP2N05OccurrenceLocatorV1(left_o.equation_id, left_o.port_side, left_o.port_index,
            left_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(left_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    right = G.UP2N05FluxEndpointV1(right_ref, "gi1b-right", :right, -1, right_unit,
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

function _gi1b_test_expected_manifest(package, context)
    eq = package.g1.payload.equation_plan.equations[1]
    state_id = eq.input_state_refs[1]
    state = only(Tuple(x for x in package.g1.payload.states if x.state_id == state_id))
    operator = only(Tuple(x for x in package.g1.payload.grammar_profile.operators if x.ref == eq.operator_ref))
    network = package.g3.realization.network
    effort_ports = Tuple(x for x in network.resource_ports if x.kind === :effort)
    effort_port = length(effort_ports) == 1 ? only(effort_ports) : nothing
    effort_entries = effort_port === nothing ? () :
        Tuple(x for x in network.entries if x.port_id == effort_port.port_id)
    effort_entry = length(effort_entries) == 1 ? only(effort_entries) : nothing
    flow_links = Tuple(x for x in package.g3.binding.links if
        x.resource_port_id in Tuple(p.port_id for p in network.resource_ports if p.kind === :flow))
    flow_link = length(flow_links) == 1 ? only(flow_links) : nothing
    balances = effort_entry === nothing ? () :
        Tuple(x for x in network.closures if effort_entry.account_id in x.account_ids)
    balance = length(balances) == 1 ? only(balances) : nothing
    regions = package.g2.region_interface.regions
    region = isempty(regions) ? nothing : first(regions)
    patches = region === nothing ? () : Tuple(x for x in package.g2.plan.exterior.boundary_patches if
        x.region_id == region.region_id && x.face === :x_min)
    patch = length(patches) == 1 ? only(patches) : nothing
    n05 = context.e1 isa G.GI1N05PresentAuthoritySlotV1 ? context.e1.authority.declaration : nothing
    values = Dict{String,Any}(
        "N01-01" => eq.input_ranks[1],
        "N01-02" => eq.output_ranks[1],
        "N01-03" => state.physical_type.tensor_rank,
        "N01-04" => package.g2.plan.embedding.ambient_dimension,
        "N01-05" => package.g2.plan.field_space.value_shape,
        "N02-01" => eq.input_units[1],
        "N02-02" => eq.output_units[1],
        "N02-03" => package.g2.plan.field_space.state_unit,
        "N02-04" => effort_port === nothing ? nothing : effort_port.unit,
        "N02-05" => effort_entry === nothing ? nothing : effort_entry.unit,
        "N03-01" => eq.temporal_kind,
        "N03-02" => eq.derivative_order,
        "N03-03" => operator.temporal_kinds,
        "N03-04" => package.g3.control.controllers[1].events[1].trigger,
        "N03-05" => package.g3.control.controllers[1].events[1].time,
        "N04-01" => network.accounts[1].owner,
        "N04-02" => network.closures[1].account_ids,
        "N04-03" => network.entries[1].account_id,
        "N04-04" => network.entries[1].component_id,
        "N04-05" => network.entries[2].coefficient,
        "N05-01" => n05 === nothing ? nothing : n05.left_endpoint.endpoint_ref,
        "N05-02" => n05 === nothing ? nothing : n05.right_endpoint.endpoint_ref,
        "N05-03" => n05 === nothing ? nothing : n05.left_endpoint.sign,
        "N05-04" => n05 === nothing ? nothing : n05.right_endpoint.sign,
        "N05-05" => n05 === nothing ? nothing : n05.right_endpoint.unit.unit,
        "N06-01" => effort_port === nothing ? nothing : effort_port.port_id,
        "N06-02" => effort_entry === nothing ? nothing : effort_entry.account_id,
        "N06-03" => flow_link === nothing ? nothing : flow_link.resource_port_id,
        "N06-04" => balance === nothing ? nothing : balance.expected_balance,
        "N06-05" => effort_port === nothing ? nothing : effort_port.kind,
        "N07-01" => region === nothing ? nothing : region.lower,
        "N07-02" => region === nothing ? nothing : region.upper,
        "N07-03" => package.g2.plan.exterior.boundary_faces,
        "N07-04" => patch === nothing ? nothing : patch.lower,
        "N07-05" => package.g2.plan.exterior.boundary_condition,
        "N08-01" => package.g2.plan.chart.axes,
        "N08-02" => package.g2.plan.chart.map_kind,
        "N08-03" => package.g2.plan.mesh.cells_per_region,
        "N08-04" => package.g2.plan.mesh.basis,
        "N08-05" => Tuple(x.interface_ref for x in package.g2.region_interface.interfaces),
        "N09-01" => operator.provider_match,
        "N09-02" => package.g2.grammar_profile.provider_match,
        "N09-03" => package.g2.plan.exterior.provider_match,
        "N09-04" => package.g3.realization.provider_match,
        "N09-05" => package.g3.control.provider_match,
        "N10-01" => package.component_identity.g1_ref.schema_hash,
        "N10-02" => package.component_identity.g2_ref.canonicalization_hash,
        "N10-03" => package.g3.binding.contract_binding.contract_ref,
        "N10-04" => package.candidate_hash,
        "N10-05" => package.migration_receipt.candidate_identity_after)
    values
end

function _gi1b_test_expected_attempt(value, spec)
    value === nothing && return (absent=true, mutation=spec.mutation_kind)
    value isa Bool && return !value
    value isa Integer && return value + one(value)
    value isa Rational && return value + one(value)
    value isa AbstractString && return value * "__gi1b_mutated"
    value isa Symbol && return Symbol("gi1b_invalid_", value)
    value isa G.TimeKindV1 && return value == G.static_time ? G.event_time : G.static_time
    value isa G.QualifiedRefV1 && return G.QualifiedRefV1(value.id * "/gi1b-foreign", value.version)
    value isa G.GenomeContractRef && return G.GenomeContractRef(value.uri * "/gi1b-foreign",
        value.version, value.schema_hash, value.canonicalization_hash, value.compatibility_profile)
    value isa G.UnitSignature && return G.UnitSignature((1,0,0,0,0,0,0))
    value isa G.Digest256 && return G.digest256_text(string(value) * ":gi1b")
    value isa Tuple && return (value..., :gi1b_mutated)
    error("independent GI1B attempted manifest lacks a typed rule for $(spec.id)")
end

function _gi1b_test_expected_classification(spec, context, value)
    value === nothing && return (:terminal_deferred, :authority_gap)
    spec.group === :N06 && return (:terminal_deferred, :authority_gap)
    spec.group === :N09 && return (:terminal_deferred, :provider_gap)
    spec.id == "N10-05" && return (:terminal_deferred, :legacy_provenance_gap)
    spec.id in ("N03-04", "N03-05", "N04-01") &&
        return (:terminal_deferred, :authority_gap)
    spec.group === :N04 && return (:fail_closed, :invalid_closure)
    spec.group === :N05 && spec.id in ("N05-01","N05-02","N05-03","N05-04") &&
        return (:fail_closed, :invalid_closure)
    spec.group === :N05 && return (:fail_closed, :invalid_type)
    spec.group in (:N07,:N08) && return (:fail_closed, :invalid_boundary)
    (:fail_closed, :invalid_type)
end

function _gi1b_test_expected_mutation_manifest(envelope, package, context)
    originals = _gi1b_test_expected_manifest(package, context)
    specs = Dict(s.id => s for s in G.GI1B_ROW_SPECS_V1)
    manifest = Dict{String,NamedTuple}()
    for (id, original) in originals
        spec = specs[id]
        attempted = _gi1b_test_expected_attempt(original, spec)
        resolution, error_code = _gi1b_test_expected_classification(spec, context, original)
        original_hash = G.canonical_hash((source_type=spec.source_type, value=original))
        attempted_hash = G.canonical_hash((source_type=spec.source_type, value=attempted))
        row = only(filter(r -> r.id == id, envelope.rows))
        payload = (id=id, field_path=spec.field_path, mutation_kind=spec.mutation_kind,
            binding=row.binding, original=original_hash, attempted=attempted_hash,
            error_code=error_code, error_path=spec.field_path, resolution=resolution)
        manifest[id] = (attempted=attempted, original_hash=original_hash,
            attempted_hash=attempted_hash, error_code=error_code,
            resolution=resolution, mutation_hash=G.canonical_hash(payload))
    end
    manifest
end

function _gi1b_test_assert_rows(envelope, package, context)
    expected = _gi1b_test_expected_manifest(package, context)
    expected_mutations = _gi1b_test_expected_mutation_manifest(envelope, package, context)
    @test length(expected) == 50
    @test length(expected_mutations) == 50
    @test length(envelope.rows) == 50
    @test length(Set(r.id for r in envelope.rows)) == 50
    @test length(Set(r.field_path for r in envelope.rows)) == 50
    specs = Dict(s.id => s for s in G.GI1B_ROW_SPECS_V1)
    for row in envelope.rows
        spec = specs[row.id]
        @test row.group === spec.group
        @test row.field_path == spec.field_path
        @test row.binding.source_locator == spec.source_locator
        @test row.binding.source_type === spec.source_type
        @test row.binding.original.source_type === spec.source_type
        @test row.attempted.source_type === spec.source_type
        @test haskey(expected, row.id)
        @test row.binding.original.value == expected[row.id]
        @test row.attempted.value == expected_mutations[row.id].attempted
        @test row.binding.source_hash isa G.Digest256
        if spec.group !== :N05 && !startswith(spec.id, "N10-")
            locator_tokens = split(strip(spec.field_path, ['/']), '/'; keepempty=false)
            layer = Symbol(lowercase(String(first(locator_tokens))))
            @test layer in (:g1, :g2, :g3)
            @test row.binding.source_ref == getproperty(envelope.outer_refs, layer)
            @test row.binding.source_hash == getproperty(envelope.component_hashes, layer)
        elseif startswith(spec.id, "N10-")
            expected_ref, expected_hash = spec.id == "N10-01" ?
                (envelope.outer_refs.g1, envelope.component_hashes.g1) :
                spec.id == "N10-02" ? (envelope.outer_refs.g2, envelope.component_hashes.g2) :
                spec.id == "N10-03" ? (envelope.outer_refs.g3, envelope.component_hashes.g3) :
                (envelope.candidate_ref, envelope.package_hash)
            @test row.binding.source_ref == expected_ref
            @test row.binding.source_hash == expected_hash
        end
        if row.binding.original.value !== nothing
            @test G._gi1b_type_matches(row.binding.original.value, spec.source_type)
        end
        @test row.original_hash == expected_mutations[row.id].original_hash
        @test row.attempted_hash == expected_mutations[row.id].attempted_hash
        @test row.error_code == expected_mutations[row.id].error_code
        @test row.resolution == expected_mutations[row.id].resolution
        @test row.compile_calls == row.provider_calls == row.solver_calls == 0
        @test row.mutation_hash == expected_mutations[row.id].mutation_hash
    end
    @test envelope.candidate_ref == package.candidate_ref
    @test envelope.package_hash == package.candidate_hash
    @test envelope.version_axes == package.version_axes
    @test envelope.compile_calls == envelope.provider_calls == envelope.solver_calls == 0
end

@testset "G-I1B actual-A E1-present and both-absent factory" begin
    package = _gi1b_test_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    declaration = _gi1b_test_declaration(package)
    n05 = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    present_context = G.gi1_authority_context_from_a(package, e0; n05=n05)
    present_root, present_rest = G._gi1b_root_for(package, present_context,
        "/n05/left_endpoint/endpoint_ref")
    @test present_root === declaration
    @test present_rest == "left_endpoint/endpoint_ref"
    present = G.gi1b_source_mutation_envelope(package, e0, present_context)
    _gi1b_test_assert_rows(present, package, present_context)
    @test present.status == :fail_closed
    @test !isempty(present.errors)
    @test present.context_hash == present_context.context_hash
    @test present.e0_bound_input_hash == e0.bound_input_hash
    @test all(r -> r.binding.source_ref isa G.QualifiedRefV1 || r.binding.source_ref isa G.GenomeContractRef,
        (r for r in present.rows if r.group !== :N05))
    n05_rows = Tuple(r for r in present.rows if r.group === :N05)
    @test n05_rows[1].binding.source_ref == declaration.left_endpoint.endpoint_ref
    @test n05_rows[2].binding.source_ref == declaration.right_endpoint.endpoint_ref
    @test n05_rows[3].binding.source_ref == declaration.law.law_ref
    @test n05_rows[5].binding.source_ref == declaration.right_endpoint.unit.source.source_ref
    @test n05_rows[5].binding.source_hash == declaration.right_endpoint.unit.source.source_hash
    n06_rows = Tuple(r for r in present.rows if r.group === :N06)
    @test all(r -> r.resolution == :terminal_deferred && r.error_code == :authority_gap,
        n06_rows)
    @test all(r -> r.binding.authority == :typed_absent && occursin("N06", r.binding.gap), n06_rows)
    n09_rows = Tuple(r for r in present.rows if r.group === :N09)
    @test all(r -> r.resolution == :terminal_deferred && r.error_code == :provider_gap,
        n09_rows)
    @test all(r -> occursin("provider", r.binding.gap), n09_rows)
    n10_rows = Tuple(r for r in present.rows if r.group === :N10)
    @test all(r -> r.id == "N10-05" ?
        (r.resolution == :terminal_deferred && r.error_code == :legacy_provenance_gap &&
         occursin("fresh receipt", r.binding.gap)) :
        (r.resolution == :fail_closed && r.error_code == :invalid_type &&
         (r.error_path * ":" * String(r.error_code)) in present.errors), n10_rows)
    @test present.status == G._gi1b_aggregate_status(present.rows)
    fault_builder = function(pkg, ctx, spec)
        spec.id == "N02-03" && throw(G.GI1ProgramException("controlled accessor fault"))
        G._gi1b_row(pkg, ctx, spec)
    end
    @test_throws MethodError G.gi1b_source_mutation_envelope(package, e0, present_context;
        row_builder=fault_builder)
    faulted = G._gi1b_source_mutation_envelope_with_row_builder(package, e0, present_context,
        fault_builder)
    @test faulted.status == :program_exception
    fault_row = only(filter(r -> r.id == "N02-03", faulted.rows))
    @test fault_row.resolution == :program_exception
    @test fault_row.error_code == :program_exception
    @test fault_row.error_path == fault_row.field_path
    @test (fault_row.error_path * ":program_exception") in faulted.errors
    @test any((r.error_path * ":" * String(r.error_code)) in faulted.errors
        for r in faulted.rows if r.resolution == :fail_closed)
    @test faulted.compile_calls == faulted.provider_calls == faulted.solver_calls == 0
    @test all(r -> r.compile_calls == r.provider_calls == r.solver_calls == 0, faulted.rows)
    forged_spec = G.GI1BRowSpecV1(:N02, "N02-forged",
        "/g1/equation_plan/equations/0/input_units/0", :String,
        "forged accessor", :unitsignature_mutation, "forged type boundary",
        :actual_A, true)
    forged_row = G._gi1b_row(package, present_context, forged_spec)
    @test forged_row.resolution == :fail_closed
    @test forged_row.error_code == :invalid_type
    exception_spec = only(filter(s -> s.id == "N02-03", G.GI1B_ROW_SPECS_V1))
    exception_row = G._gi1b_exception_row(package, (e1=nothing,), exception_spec,
        ErrorException("synthetic source identity fault"))
    @test exception_row.resolution == :program_exception
    @test exception_row.error_code == :program_exception
    @test exception_row.error_path == exception_spec.field_path
    @test exception_row.binding.source_ref isa G.GI1BUnavailableSourceIdentityV1
    @test exception_row.binding.source_ref.layer == :G2
    @test exception_row.binding.source_ref.reason == :source_identity_unavailable
    @test exception_row.binding.source_hash == exception_row.binding.source_ref.marker_hash
    @test exception_row.compile_calls == exception_row.provider_calls == exception_row.solver_calls == 0
    @test G._gi1b_aggregate_status((present.rows..., exception_row)) == :program_exception
    foreign_package = _gi1b_test_package("fusionconceptai://candidate/gi1b-foreign")
    @test_throws Exception G.gi1b_source_mutation_envelope(foreign_package, e0, present_context)

    absent_context = G.gi1_authority_context_from_a(package, e0)
    absent_root, absent_rest = G._gi1b_root_for(package, absent_context,
        "/n05/left_endpoint/endpoint_ref")
    @test absent_root === nothing
    @test absent_rest == "left_endpoint/endpoint_ref"
    absent = G.gi1b_source_mutation_envelope(package, e0, absent_context)
    _gi1b_test_assert_rows(absent, package, absent_context)
    absent_n05 = Tuple(r for r in absent.rows if r.group === :N05)
    @test all(r -> r.binding.source_ref isa G.GI1BAbsentSourceIdentityV1, absent_n05)
    @test all(r -> r.binding.source_hash == absent_context.e1.content_hash, absent_n05)
    @test all(r -> r.binding.source_ref.content_hash == absent_context.e1.content_hash, absent_n05)
    @test all(r -> r.binding.source_ref.schema_hash == absent_context.e1.schema_hash, absent_n05)
    @test all(r -> r.binding.source_ref.canonicalization_hash == absent_context.e1.canonicalization_hash, absent_n05)
    @test all(r -> r.binding.source_ref.profile_hash == absent_context.e1.profile_hash, absent_n05)
    @test all(r -> r.binding.source_ref.compatibility_profile_hash == absent_context.e1.compatibility_profile_hash, absent_n05)
    @test all(r -> r.binding.source_ref != absent_context.g3_ref, absent_n05)
    @test absent.status == :fail_closed
    @test !isempty(absent.errors)
end

@testset "G-I1B aggregate taxonomy and source type boundary" begin
    @test G._gi1b_aggregate_status((:declared_consistent,)) == :declared_consistent
    @test G._gi1b_aggregate_status((:terminal_deferred, :declared_consistent)) == :terminal_deferred
    @test G._gi1b_aggregate_status((:fail_closed, :terminal_deferred)) == :fail_closed
    @test G._gi1b_aggregate_status((:program_exception, :fail_closed)) == :program_exception
    @test !G._gi1b_type_matches(:wrong, :UnitSignature)
    @test !G._gi1b_type_matches((:wrong,), :TupleTimeKindV1)
    @test G._gi1b_type_matches(G.UnitSignature(), :UnitSignature)
    @test G._gi1b_type_matches((G.static_time,), :TupleTimeKindV1)
end

@testset "G-I1B source envelope schema and frozen matrix" begin
    fixture = JSON3.read(read(GI1B_FIXTURE, String))
    @test Bool(fixture.expected_error_not_routing)
    rows = collect(fixture.rows)
    @test length(rows) == 50
    @test length(Set(String(r.id) for r in rows)) == 50
    @test length(Set(String(r.field_path) for r in rows)) == 50
    @test all(count(==(String(g)), String(r.group) for r in rows) == 5 for g in (:N01,:N02,:N03,:N04,:N05,:N06,:N07,:N08,:N09,:N10))
    @test length(G.GI1B_ROW_SPECS_V1) == 50
    @test length(Set(s.id for s in G.GI1B_ROW_SPECS_V1)) == 50
    @test length(Set(s.field_path for s in G.GI1B_ROW_SPECS_V1)) == 50
    @test all(count(==(g), s.group for s in G.GI1B_ROW_SPECS_V1) == 5 for g in (:N01,:N02,:N03,:N04,:N05,:N06,:N07,:N08,:N09,:N10))
    r205 = only(filter(r -> String(r.id) == "N05-05", rows))
    @test String(r205.source_locator) == "declaration.right_endpoint.unit.source.source_ref"
    @test only(filter(s -> s.id == "N05-05", G.GI1B_ROW_SPECS_V1)).source_locator ==
        "declaration.right_endpoint.unit.source.source_ref"
    @test G.gi1b_schema_hash() isa G.Digest256
    @test G.gi1b_canonicalization_hash() isa G.Digest256
    @test G.gi1b_profile_hash() isa G.Digest256
end

@testset "G-I1B production boundary" begin
    @test hasmethod(G.gi1b_source_mutation_envelope,
        Tuple{G.CandidateStatePackageV5,G.UP2CandidatePhysicalBindingV1,G.GI1AuthorityContextV1})
    @test all(s.eligible for s in G.GI1B_ROW_SPECS_V1)
    @test count(s -> s.group === :N06, G.GI1B_ROW_SPECS_V1) == 5
    @test all(s -> !isempty(strip(s.authority_gap)), (s for s in G.GI1B_ROW_SPECS_V1 if s.group === :N06))
    @test G._GI1B_PROFILE_SOURCE_V1 isa String
    @test occursin("expected-error", lowercase(G._GI1B_SCHEMA_SOURCE_V1)) == false
end

@testset "G-I1B fixture is oracle-only" begin
    fixture_text = read(GI1B_FIXTURE, String)
    @test occursin("expected_error_not_routing", fixture_text)
    @test !occursin("FusionConceptAI.gi1b_source_mutation_envelope", fixture_text)
    @test all(isempty(findall(c -> UInt32(c) < 0x20 && c != '\n' && c != '\r' && c != '\t', fixture_text)))
end
