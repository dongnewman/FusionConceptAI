using Test
using FusionConceptAI
using JSON3

const _G2V5_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G2")
Base.include(FusionConceptAI, joinpath(_G2V5_ROOT, "SpatialGrammarProfileV2.jl"))
Base.include(FusionConceptAI, joinpath(_G2V5_ROOT, "RegionInterfaceContractV2.jl"))
Base.include(FusionConceptAI, joinpath(_G2V5_ROOT, "FieldSpacePlanV2.jl"))
Base.include(FusionConceptAI, joinpath(_G2V5_ROOT, "FieldGeometryGenomeV5.jl"))

const G = FusionConceptAI
const _FIXTURE = JSON3.read(read(joinpath(@__DIR__, "fixtures.json"), String))

_g2_ref(id, version="v2") = G.QualifiedRefV1(String(id), String(version))
_g2_symbol(x) = Symbol(String(x))
_g2_symbols(xs) = Tuple(_g2_symbol(x) for x in xs)
_g2_ratio(x::Rational{Int64}) = x
_g2_ratio(x::Integer) = Int64(x) // 1
function _g2_ratio(x::Any)
    text = String(x)
    if occursin("/", text)
        numerator, denominator = split(text, "/"; limit=2)
        return parse(Int64, numerator) // parse(Int64, denominator)
    end
    parse(Int64, text) // 1
end
_g2_ratios(xs, n) = ntuple(i -> _g2_ratio(xs[i]), n)
_g2_ints(xs, n) = ntuple(i -> Int(xs[i]), n)

function _g2_case(case_id::String)
    matches = [c for c in _FIXTURE.legal_cases if String(c.case_id) == case_id]
    length(matches) == 1 || throw(ArgumentError("fixture legal case not unique: $case_id"))
    first(matches)
end

function _g2_mutation_kind(mutation)
    mutation === nothing ? nothing : String(mutation.kind)
end

function _g2_different_digest(digest::G.Digest256)
    first_char = digest.value[1] == '0' ? '1' : '0'
    G.Digest256(string(first_char, digest.value[2:end]))
end

function _g2_build(case_id::String; mutation=nothing)
    case = _g2_case(case_id)
    kind = _g2_mutation_kind(mutation)
    region_specs = case.regions
    regions = G.G2RegionV2[]
    for region_spec in region_specs
        lower = _g2_ratios(region_spec.lower, 3)
        upper = _g2_ratios(region_spec.upper, 3)
        if kind == "region_lower" && String(mutation.region_id) == String(region_spec.id)
            axis = Int(mutation.axis)
            lower = ntuple(i -> i == axis ? _g2_ratio(mutation.value) : lower[i], 3)
        end
        push!(regions, G.G2RegionV2(String(region_spec.id), lower, upper,
            _g2_ref(region_spec.chart_ref), _g2_ref(region_spec.embedding_ref),
            _g2_ref(region_spec.field_space_ref), _g2_symbols(region_spec.boundary_kinds)))
    end

    interface_spec = case.interface
    interface_id = String(interface_spec.id)
    interface_coordinate = _g2_ratio(interface_spec.coordinate)
    interface_normal = Int(interface_spec.normal)
    kind == "interface_coordinate" && (interface_coordinate = _g2_ratio(mutation.value))
    kind == "interface_normal" && (interface_normal = Int(mutation.value))
    iface = G.G2InterfaceV2(_g2_ref(interface_id), String(interface_spec.left_region_id),
        String(interface_spec.right_region_id),
        findfirst(==(String(interface_spec.axis)), ("x", "y", "z")),
        interface_coordinate, interface_normal, _g2_symbol(interface_spec.continuity),
        _g2_symbol(interface_spec.transfer))
    interfaces = if kind == "drop_interface"
        ()
    elseif kind == "duplicate_interface"
        duplicate = G.G2InterfaceV2(_g2_ref(interface_id * ".duplicate"), iface.left_region_id,
            iface.right_region_id, iface.axis, iface.coordinate, iface.normal,
            iface.continuity, iface.transfer_kind)
        (iface, duplicate)
    else
        (iface,)
    end
    contract = G.RegionInterfaceContractV2(Tuple(regions), interfaces)

    plan_spec = case.plan
    chart_spec = plan_spec.chart
    chart = G.G2ChartPlanV2(_g2_ref(chart_spec.chart_ref), _g2_ref(chart_spec.frame_ref),
        _g2_symbols(chart_spec.axes), _g2_symbol(chart_spec.map_kind))
    embedding_spec = plan_spec.embedding
    embedding = G.G2EmbeddingPlanV2(_g2_ref(embedding_spec.embedding_ref),
        _g2_ref(embedding_spec.chart_ref), 3, _g2_symbol(embedding_spec.kind))
    field_spec = plan_spec.field_space
    field_space = G.G2FieldSpacePlanV2(_g2_ref(field_spec.ref),
        _g2_symbol(field_spec.value_shape), _g2_symbol(field_spec.continuity),
        String(field_spec.state_unit))
    mesh_spec = plan_spec.mesh
    mesh = G.G2MeshPlanV2(_g2_ref(mesh_spec.ref),
        Tuple(String(x) for x in mesh_spec.region_ids), _g2_ints(mesh_spec.cells, 3),
        _g2_symbol(mesh_spec.basis), _g2_symbol(mesh_spec.quadrature))

    exterior_spec = plan_spec.exterior
    faces = Tuple(_g2_symbol(x) for x in exterior_spec.faces)
    if kind == "drop_boundary_face"
        faces = Tuple(x for x in faces if x != _g2_symbol(mutation.face))
    end
    patches = G.G2BoundaryFacePatchV2[]
    for patch_spec in exterior_spec.patches
        lower = _g2_ratios(patch_spec.lower, 2)
        if kind == "patch_lower" && String(mutation.face) == String(patch_spec.face) &&
                String(mutation.region_id) == String(patch_spec.region_id)
            lower = _g2_ratios(mutation.lower, 2)
        end
        push!(patches, G.G2BoundaryFacePatchV2(_g2_symbol(patch_spec.face),
            String(patch_spec.region_id), lower, _g2_ratios(patch_spec.upper, 2)))
    end
    if kind == "duplicate_boundary_patch"
        duplicate = first(p for p in patches if p.face == _g2_symbol(mutation.face) &&
            p.region_id == String(mutation.region_id))
        push!(patches, duplicate)
    end
    provider_match = _g2_symbol(exterior_spec.condition) == :none_declared ? :no_match :
        _g2_symbol(case.profile.provider_match)
    if kind == "profile_provider_match"
        provider_match = _g2_symbol(mutation.value)
    end
    boundary_region_ids = Tuple(String(x) for x in exterior_spec.boundary_region_ids)
    if kind == "duplicate_exterior_owner"
        boundary_region_ids = (first(boundary_region_ids), first(boundary_region_ids))
    end
    exterior = G.G2ExteriorPlanV2(_g2_ref(exterior_spec.ref), boundary_region_ids,
        _g2_symbol(exterior_spec.condition), faces; boundary_patches=Tuple(patches),
        provider_match=provider_match)
    plan = G.FieldSpacePlanV2(_g2_ref(plan_spec.plan_ref), chart, embedding, field_space, mesh, exterior)

    profile_spec = case.profile
    profile_id = String(profile_spec.profile_ref)
    canonical_id = String(profile_spec.canonicalization_ref)
    applicability_id = String(profile_spec.applicability_ref)
    if kind == "wrong_internal_profile_ref"
        profile_id *= ".wrong"
    end
    profile = G.SpatialGrammarProfileV2(_g2_ref(profile_id), _g2_ref(canonical_id),
        _g2_ref(applicability_id), Int(_FIXTURE.ambient_dimension),
        _g2_symbols(profile_spec.topologies), _g2_symbols(profile_spec.mesh_families);
        provider_match=provider_match)

    axes_spec = _FIXTURE.version_axes
    axis_id = kind == "wrong_version_axis_id" ? "fusion.g2.wrong-axis" : String(axes_spec.payload_schema.id)
    axes = G.G2VersionAxesV2(_g2_ref(axis_id, axes_spec.payload_schema.version),
        _g2_ref(axes_spec.canonicalization.id, axes_spec.canonicalization.version),
        _g2_ref(axes_spec.applicability.id, axes_spec.applicability.version),
        _g2_ref(axes_spec.receipt.id, axes_spec.receipt.version))

    schema_hash = G.g2_schema_hash()
    canonicalization_hash = G.g2_canonicalization_hash()
    compatibility_profile = G.g2_compatibility_profile_token(profile)
    kind == "wrong_external_schema" && (schema_hash = _g2_different_digest(schema_hash))
    kind == "wrong_external_canonicalization" &&
        (canonicalization_hash = _g2_different_digest(canonicalization_hash))
    kind == "wrong_external_profile" && (compatibility_profile *= ".wrong")
    external_ref = G.GenomeContractRef(String(case.contract.uri), String(case.contract.version),
        schema_hash, canonicalization_hash, compatibility_profile)
    genome = G.FieldGeometryGenomeV5(external_ref, contract, plan, profile, axes)
    genome, contract, plan, profile
end

@testset "UP1-02 G2 V5 fixture-driven legal 3D plans" begin
    @test String(_FIXTURE.fixture_id) == "UP1-FX-G2-001"
    @test length(_FIXTURE.legal_cases) >= 2
    @test Set(String(c.interface.axis) for c in _FIXTURE.legal_cases) == Set(("x", "y"))
    for case in _FIXTURE.legal_cases
        genome, contract, plan, profile = _g2_build(String(case.case_id))
        @test length(contract.regions) == length(case.regions)
        @test length(contract.interfaces) == 1
        @test contract.interfaces[1].axis == findfirst(==(String(case.interface.axis)), ("x", "y", "z"))
        @test contract.interfaces[1].coordinate == _g2_ratio(case.interface.coordinate)
        @test Tuple(r.region_id for r in contract.regions) == Tuple(String(r.id) for r in case.regions)
        @test length(plan.exterior.boundary_patches) == length(case.plan.exterior.patches)
        @test genome.admission.structural_status == :valid
        @test genome.admission.geometry_status == :valid
        @test genome.admission.mesh_status == :not_executed
        @test genome.admission.physical_status == :not_executed
        @test genome.admission.provider_match == :unique_match
        @test genome.admission.resolution == :resolved
        @test isempty(genome.admission.errors)
        @test profile.profile_ref.id == G.G2_PROFILE_REF_ID
        @test profile.canonicalization_profile_ref.id == G.G2_CANONICALIZATION_PROFILE_REF_ID
        @test profile.applicability_profile_ref.id == G.G2_APPLICABILITY_PROFILE_REF_ID
        @test all(ref.version == "v2" for ref in (profile.profile_ref,
            profile.canonicalization_profile_ref, profile.applicability_profile_ref))
        @test G.g2_schema_hash() == G.canonical_hash(G.G2_SCHEMA_DESCRIPTOR_V2)
        @test G.g2_canonicalization_hash() == G.canonical_hash(G.G2_CANONICALIZATION_DESCRIPTOR_V2)
        @test genome.contract_ref.schema_hash == G.g2_schema_hash()
        @test genome.contract_ref.canonicalization_hash == G.g2_canonicalization_hash()
        @test genome.contract_ref.compatibility_profile == G.g2_compatibility_profile_token(profile)
        @test genome.contract_ref.compatibility_profile == "g2-v5-profile:" * G.g2_profile_hash(profile).value
        @test G.g2_plan_hash(genome) != G.g2_plan_hash(plan)
        @test G.g2_genome_hash(genome) isa G.Digest256
    end
    genome, _, _, _ = _g2_build("split_x_1")
    edited_interface = G.g2_edit_interface(genome, "g2.interface.x1", coordinate=2//1)
    @test G.g2_genome_hash(edited_interface) != G.g2_genome_hash(genome)
    @test G.g2_plan_hash(edited_interface) != G.g2_plan_hash(genome)
    edited_mesh = G.g2_edit_mesh_cells(genome, (3, 2, 2))
    @test G.g2_plan_hash(edited_mesh) != G.g2_plan_hash(genome)
    @test G.g2_genome_hash(edited_mesh) != G.g2_genome_hash(genome)
end

@testset "UP1-02 G2 fixture-driven negative mutations" begin
    @test length(_FIXTURE.negative_cases) >= 16
    for negative in _FIXTURE.negative_cases
        @testset "$(String(negative.case_id))" begin
            mutation = negative.mutation
            expected = String(negative.expected)
            if expected == "constructor_reject"
                @test_throws ArgumentError _g2_build(String(negative.base_case); mutation=mutation)
                continue
            end
            genome, _, _, _ = _g2_build(String(negative.base_case); mutation=mutation)
            if expected == "terminal_deferred"
                @test genome.admission.resolution == :terminal_deferred
                @test genome.admission.structural_status == :valid
                @test genome.admission.geometry_status == :valid
                @test genome.admission.mesh_status == :not_executed
                @test genome.admission.physical_status == :not_executed
                @test any(contains(gap, "provider_match") for gap in genome.admission.gaps)
            else
                @test String(negative.expected_detail) in genome.admission.errors ||
                    String(negative.expected_detail) in genome.admission.structural_errors ||
                    String(negative.expected_detail) in genome.admission.geometry_errors
                @test expected == "invalid_boundary|invalid_closure" || expected == "invalid_boundary" ||
                    expected == "invalid_closure"
                @test genome.admission.resolution == :fail_closed
                if expected == "invalid_boundary|invalid_closure" || expected == "invalid_boundary"
                    @test genome.admission.geometry_status == :fail_closed
                else
                    @test genome.admission.structural_status == :fail_closed ||
                        genome.admission.geometry_status == :fail_closed
                end
            end
            @test Int(negative.solver_calls) == 0
        end
    end
end

@testset "UP1-02 G2 physical and provider evidence boundary" begin
    provider_negative = first(n for n in _FIXTURE.negative_cases if String(n.case_id) == "missing_provider")
    deferred, _, _, _ = _g2_build("split_x_1";
        mutation=provider_negative.mutation)
    @test deferred.admission.structural_status == :valid
    @test deferred.admission.provider_match == :no_match
    @test deferred.admission.resolution == :terminal_deferred
    @test any(contains(gap, "provider_match") for gap in deferred.admission.gaps)
    @test deferred.plan.mesh.execution_status == :declared_pending
    @test deferred.admission.mesh_status == :not_executed
    @test deferred.admission.physical_status == :not_executed
    @test _FIXTURE.evidence_boundary.b04_compile_before_provider == "pending UP1-04; no provider invocation evidence in UP1-02"
end

G.load_vnext_t2_components_v2!()
const _G2_SOURCE_ORDER_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _G2_SOURCE_ORDER_BASE_DIR =
    "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2"
const _G2_SOURCE_ORDER_REVERSED_DIR =
    "test/fixtures/g2_region_order/current-source-reversed-candidate"

function _g2_current_source_order_case_v1(candidate_directory::AbstractString)
    built = G._vnext_current_source_candidate_records_v1(
        _G2_SOURCE_ORDER_ROOT, candidate_directory)
    records = G._vnext_current_source_records_v1(built)
    g2_record = only(filter(record -> record.layer === :G2, records.declarations))
    source = g2_record.semantic_body.body.source
    projection = G.g2_v5_source_projection_v1(records.g2)
    (built=built, records=records, g2_record=g2_record,
        source=source, projection=projection)
end

function _g2_projected_order_semantics_v1(genome)
    plan = genome.plan
    (regions=Tuple((region.region_id, region.lower, region.upper,
            region.chart_ref, region.embedding_ref, region.field_space_ref,
            region.boundary_kinds) for region in genome.region_interface.regions),
        interfaces=Tuple((interface.interface_ref, interface.left_region_id,
            interface.right_region_id, interface.axis, interface.coordinate,
            interface.normal, interface.continuity, interface.transfer_kind)
            for interface in genome.region_interface.interfaces),
        plan=(chart=G.semantic_view(plan.chart),
            embedding=G.semantic_view(plan.embedding),
            field_space=G.semantic_view(plan.field_space),
            mesh=(region_ids=plan.mesh.region_ids,
                cells_per_region=plan.mesh.cells_per_region,
                basis=plan.mesh.basis, quadrature=plan.mesh.quadrature,
                execution_status=plan.mesh.execution_status),
            exterior=(boundary_region_ids=plan.exterior.boundary_region_ids,
                boundary_faces=plan.exterior.boundary_faces,
                boundary_patches=Tuple(G.semantic_view(patch) for patch in
                    plan.exterior.boundary_patches),
                boundary_condition=plan.exterior.boundary_condition,
                provider_match=plan.exterior.provider_match)),
        profile=G.semantic_view(genome.grammar_profile),
        admission=(structural_status=genome.admission.structural_status,
            geometry_status=genome.admission.geometry_status,
            mesh_status=genome.admission.mesh_status,
            physical_status=genome.admission.physical_status,
            provider_match=genome.admission.provider_match,
            resolution=genome.admission.resolution,
            errors=genome.admission.errors,
            gaps=genome.admission.gaps))
end

@testset "G2 current-source projection is stable under authored region order" begin
    authored = _g2_current_source_order_case_v1(_G2_SOURCE_ORDER_BASE_DIR)
    reversed = _g2_current_source_order_case_v1(_G2_SOURCE_ORDER_REVERSED_DIR)

    @test authored.records.candidate == reversed.records.candidate
    @test authored.g2_record.source_bytes.sha256 ==
        reversed.g2_record.source_bytes.sha256
    @test authored.g2_record.semantic_body.body.authored_builder_input.sha256 !=
        reversed.g2_record.semantic_body.body.authored_builder_input.sha256

    authored_order = Tuple(region.region_id for region in
        authored.source.region_interface.regions)
    reversed_order = Tuple(region.region_id for region in
        reversed.source.region_interface.regions)
    @test authored_order == ("local_unit_cube_left", "local_unit_cube_right")
    @test reversed_order == reverse(authored_order)

    for case in (authored, reversed)
        factory = case.records.g2
        declaration = factory.source_declaration
        receipt = factory.receipt
        identity = factory.identity
        @test G.g2mb_admit(case.source).structural_status === :valid
        @test G.g2mb_admit(case.source).metric_status === :valid
        @test receipt.status === :present
        @test receipt.output_source_declaration === declaration
        @test declaration.source_payload.source_hash == case.source.source_hash
        @test identity.source_payload_hash == case.source.source_hash ==
            receipt.source_payload_hash
        @test declaration.source_content_hash == identity.source_content_hash ==
            receipt.source_content_hash
        @test declaration.local_declaration_hash == identity.declaration_hash ==
            receipt.local_declaration_hash == declaration.declaration.declaration_hash
        @test case.projection.source_declaration === declaration
        @test case.projection.source_factory_identity === identity
        @test case.projection.source_factory_receipt === receipt
        @test case.projection.source_payload_hash == case.source.source_hash
        @test case.projection.source_content_hash == identity.source_content_hash
        @test case.projection.declaration_hash == declaration.declaration_hash
        @test case.projection.source_map_retained
        @test case.projection.resolution === :terminal_deferred
        @test case.projection.claim_ceiling === :contract_only
    end

    @test authored.source.source_hash != reversed.source.source_hash
    @test authored.projection.source_content_hash !=
        reversed.projection.source_content_hash
    @test authored.projection.declaration_hash != reversed.projection.declaration_hash

    authored_genome = authored.projection.genome
    reversed_genome = reversed.projection.genome
    @test _g2_projected_order_semantics_v1(authored_genome) ==
        _g2_projected_order_semantics_v1(reversed_genome)
    expected_regions = ("local_unit_cube_left", "local_unit_cube_right")
    @test Tuple(region.region_id for region in
        authored_genome.region_interface.regions) == expected_regions
    @test authored_genome.plan.mesh.region_ids == expected_regions
    @test Tuple(region_id for region_id in
        authored_genome.plan.exterior.boundary_region_ids) == expected_regions

    authored_interface = only(authored_genome.region_interface.interfaces)
    reversed_interface = only(reversed_genome.region_interface.interfaces)
    @test (authored_interface.left_region_id, authored_interface.right_region_id,
        authored_interface.axis, authored_interface.coordinate,
        authored_interface.normal, authored_interface.continuity,
        authored_interface.transfer_kind) ==
        ("local_unit_cube_left", "local_unit_cube_right", 1, 3//2, 1,
            :trace_flux, :conservative)
    @test (reversed_interface.left_region_id, reversed_interface.right_region_id,
        reversed_interface.axis, reversed_interface.coordinate,
        reversed_interface.normal, reversed_interface.continuity,
        reversed_interface.transfer_kind) ==
        (authored_interface.left_region_id, authored_interface.right_region_id,
            authored_interface.axis, authored_interface.coordinate,
            authored_interface.normal, authored_interface.continuity,
            authored_interface.transfer_kind)

    patch_keys = Tuple((String(patch.face), patch.region_id) for patch in
        authored_genome.plan.exterior.boundary_patches)
    @test collect(patch_keys) == sort!(collect(patch_keys))
    @test authored_genome.grammar_profile.provider_match === :no_match
    @test authored_genome.plan.exterior.provider_match === :no_match
    @test authored_genome.admission.structural_status === :valid
    @test authored_genome.admission.geometry_status === :valid
    @test authored_genome.admission.provider_match === :no_match
    @test authored_genome.admission.resolution === :terminal_deferred
    @test authored_genome.admission.mesh_status === :not_executed
    @test authored_genome.admission.physical_status === :not_executed
    @test isempty(authored_genome.admission.errors)
end
