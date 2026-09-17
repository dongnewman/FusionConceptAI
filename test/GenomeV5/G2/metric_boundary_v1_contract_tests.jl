using Test
using FusionConceptAI
using JSON3

const _G2MB_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G2")
Base.include(FusionConceptAI, joinpath(_G2MB_ROOT, "MetricBoundaryDeclarationV1.jl"))
const G = FusionConceptAI
const _FIXTURE = JSON3.read(read(joinpath(@__DIR__, "metric_boundary_v1_fixture.json"), String))

const _r(n, d=1) = Int64(n) // Int64(d)
const _chart_ref = G.QualifiedRefV1("fusion.g2.metric-boundary.chart", "v1")
const _mesh_ref = G.QualifiedRefV1("fusion.g2.metric-boundary.mesh", "v1")
const _ref_u = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
const _coord_u = G.UnitSignature((1, 0, 0, 0, 0, 0, 0))
const _metric_u = G.UnitSignature((2, 0, 0, 0, 0, 0, 0))
const _volume_u = G.UnitSignature((3, 0, 0, 0, 0, 0, 0))
const _field_u = G.UnitSignature((0, 0, 0, 0, 0, 0, 1))
const _flux_u = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))

function _fixture_source(; authority=G.G2MBAuthorityV1(:unique_match, :no_match, :no_match),
                         faces=nothing, chart=nothing)
    chart === nothing && (chart = G.G2MBChartMapV1(_chart_ref, (0, 0, 0), (1, 1, 1),
        ((2, 0, 0), (0, 3, 0), (0, 0, 4)), (_r(1, 2), _r(1, 3), _r(1, 4))))
    mesh = G.G2MBMeshPlanV1(_mesh_ref, _chart_ref, (2, 3, 4), :Q1,
        ((_r(1, 2), _r(1, 2), _r(1, 2)), (_r(1, 4), _r(1, 4), _r(1, 4))), (1, _r(1, 2));
        execution_status=:not_executed)
    faces === nothing && (faces = (
        G.G2MBFaceOwnerV1("face-x-min", :x_min, "candidate-domain", (-1, 0, 0), G.G2MBFaceValueV1(:dirichlet, 0, _field_u)),
        G.G2MBFaceOwnerV1("face-x-max", :x_max, "candidate-domain", (1, 0, 0), G.G2MBFaceValueV1(:neumann, 1, _flux_u)),
        G.G2MBFaceOwnerV1("face-y-min", :y_min, "candidate-domain", (0, -1, 0), G.G2MBFaceValueV1(:dirichlet, 0, _field_u)),
        G.G2MBFaceOwnerV1("face-y-max", :y_max, "candidate-domain", (0, 1, 0), G.G2MBFaceValueV1(:neumann, 1, _flux_u)),
        G.G2MBFaceOwnerV1("face-z-min", :z_min, "candidate-domain", (0, 0, -1), G.G2MBFaceValueV1(:dirichlet, 0, _field_u)),
        G.G2MBFaceOwnerV1("face-z-max", :z_max, "candidate-domain", (0, 0, 1), G.G2MBFaceValueV1(:neumann, 1, _flux_u))))
    profile = G.G2MBProfileV1("fusion.g2.metric-boundary.profile.fixture")
    units = G.G2MBUnitContractV1(_ref_u, _coord_u, _coord_u, _metric_u, _metric_u,
        _volume_u, _field_u, _flux_u)
    source = G.g2mb_source_v1(G.QualifiedRefV1("fusionconceptai://source/up2-01-g2-metric-boundary-fixture", "v1"),
        "g2-metric-boundary-source-v1", G.GenomeContractRef(
            "fusionconceptai://GenomeV5/candidate/up2-01-g2-metric-boundary-fixture", "v5",
            G.digest256_text("candidate-schema-up2-01-g2-metric-boundary"),
            G.digest256_text("candidate-canonicalization-up2-01-g2-metric-boundary"), "candidate-profile"),
        chart, mesh, faces, profile, units, authority)
    source
end

function _fixture_declaration(source)
    profile = source.profile
    contract = G.GenomeContractRef("fusionconceptai://GenomeV5/G2/metric-boundary/up2-01-fixture", "v5",
        G.g2mb_schema_hash_v1(), G.g2mb_canonicalization_hash_v1(), G.g2mb_profile_token_v1(profile))
    G.g2mb_declaration_v1(contract, source)
end

@testset "G2 metric-boundary V1 has executable chart metric and determinant orientation" begin
    @test String(_FIXTURE.fixture_id) == "UP2-01-G2-METRIC-BOUNDARY-V1-FX-001"
    @test Bool(_FIXTURE.review_pending) && !Bool(_FIXTURE.accepted)
    @test String(_FIXTURE.claim_ceiling) == "contract_only"
    @test String(_FIXTURE.source.mesh.execution_status) == "not_executed"
    @test length(_FIXTURE.source.units.coordinate) == 7
    @test Set(String(face.unit_role) for face in _FIXTURE.source.faces) == Set(("field_value", "flux_value"))
    source = _fixture_source()
    chart = source.chart_map
    @test G.g2mb_chart_map(chart, (_r(1, 2), _r(1, 2), _r(1, 2))) == (_r(3, 2), _r(11, 6), _r(9, 4))
    @test G.g2mb_chart_jacobian(chart) == ((2, 0, 0), (0, 3, 0), (0, 0, 4))
    @test G.g2mb_metric(chart) == ((4, 0, 0), (0, 9, 0), (0, 0, 16))
    @test G.g2mb_metric_positive_definite(chart)
    @test G.g2mb_det_jacobian(chart) == 24
    @test G.g2mb_orientation_positive(chart)
    @test G.g2mb_physical_oriented_area_vector(chart, (-1, 0, 0)) == (-12, 0, 0)
    @test G.g2mb_physical_oriented_area_vector(chart, (0, 1, 0)) == (0, 8, 0)
    area_measure = G.g2mb_physical_oriented_area_measure(chart, (-1, 0, 0), source.units)
    @test area_measure.oriented_vector == (-12, 0, 0)
    @test area_measure.unit == source.units.area
    volume_measure = G.g2mb_volume_measure(chart, source.units)
    @test volume_measure.orientation === :orientation_preserving
    @test volume_measure.absolute_scale == 24
    @test volume_measure.unit == source.units.volume
    @test G.g2mb_chart_image_bounds(chart) == ((_r(1, 2), _r(5, 2)), (_r(1, 3), _r(10, 3)), (_r(1, 4), _r(17, 4)))
end

@testset "G2 candidate-owned mesh and face declarations are hash-addressed" begin
    declaration = _fixture_declaration(_fixture_source())
    @test declaration.source.source_hash == G.canonical_hash((
        source_ref=declaration.source.source_ref, source_version=declaration.source.source_version,
        candidate_ref=declaration.source.candidate_ref, chart_map=declaration.source.chart_map,
        mesh=declaration.source.mesh, faces=declaration.source.faces, profile=declaration.source.profile,
        units=declaration.source.units,
        authority=declaration.source.authority))
    @test declaration.source.mesh.cells == (2, 3, 4)
    @test all(f.ownership === :candidate_owned for f in declaration.source.faces)
    @test Set(f.value.kind for f in declaration.source.faces) == Set((:dirichlet, :neumann))
    @test length(Set(f.face for f in declaration.source.faces)) == 6
    receipt = G.g2mb_receipt_v1(declaration)
    @test receipt.review_pending && !receipt.accepted
    @test receipt.admission_status === :terminal_deferred
    @test receipt.resolution === :terminal_deferred
    @test receipt.compile_calls == receipt.provider_calls == receipt.mesh_calls == receipt.solver_calls == 0
    @test !receipt.physical_evidence
end

@testset "editing source fields rebuilds source and declaration identity" begin
    declaration = _fixture_declaration(_fixture_source())
    edited_chart = G.G2MBChartMapV1(_chart_ref, (0, 0, 0), (1, 1, 1),
        ((5, 0, 0), (0, 3, 0), (0, 0, 4)), (_r(1, 2), _r(1, 3), _r(1, 4)))
    edited = G.g2mb_edit_source(declaration, :chart_map, edited_chart)
    @test edited.source.source_hash != declaration.source.source_hash
    @test edited.declaration_hash != declaration.declaration_hash
    @test edited.source.chart_map.jacobian_rows[1][1] == 5
    edited_value = G.g2mb_edit_source(declaration, :face_value,
        ("face-x-min", G.G2MBFaceValueV1(:dirichlet, 2, _field_u)))
    @test edited_value.source.source_hash != declaration.source.source_hash
    @test edited_value.declaration_hash != declaration.declaration_hash
end

@testset "contradictions fail closed and missing authority is deferred" begin
    source = _fixture_source()
    @test G.g2mb_admit(source).status === :terminal_deferred
    @test occursin("mesh_authority", join(G.g2mb_admit(source).gaps, "|"))
    unique_authority = _fixture_source(authority=G.G2MBAuthorityV1(:unique_match, :unique_match, :unique_match))
    @test G.g2mb_admit(unique_authority).status === :terminal_deferred
    @test "mesh_execution_not_executed" in G.g2mb_admit(unique_authority).gaps
    bad_faces = (source.faces[1], source.faces[2], source.faces[3], source.faces[4], source.faces[5],
        G.G2MBFaceOwnerV1("face-z-max", :z_max, "candidate-domain", (0, 0, -1), G.G2MBFaceValueV1(:neumann, 1, _flux_u)))
    bad = G.g2mb_source_v1(source.source_ref, source.source_version, source.candidate_ref,
        source.chart_map, source.mesh, bad_faces, source.profile, source.units, source.authority)
    @test G.g2mb_admit(bad).status === :fail_closed
    @test :structural_contradiction == G.g2mb_admit(bad).error_code
    @test G.g2mb_admit(nothing).status === :fail_closed
    @test G.g2mb_admit(nothing).error_code === :source_type
    @test G.g2mb_admit(G._g2mb_fault_probe(source)).status === :program_exception
    @test G.g2mb_admit(G._g2mb_fault_probe(source)).exception_type !== nothing
    reversed = G.G2MBChartMapV1(_chart_ref, (0, 0, 0), (1, 1, 1),
        ((-2, 0, 0), (0, 3, 0), (0, 0, 4)), (_r(1, 2), _r(1, 3), _r(1, 4)))
    reversed_source = G.g2mb_source_v1(source.source_ref, source.source_version, source.candidate_ref,
        reversed, source.mesh, source.faces, source.profile, source.units, source.authority)
    @test G.g2mb_admit(reversed_source).status === :fail_closed
    @test any(error -> occursin("chart_orientation_not_preserved", error), G.g2mb_admit(reversed_source).errors)
    unit_mismatch = G.G2MBFaceOwnerV1("face-x-min", :x_min, "candidate-domain", (-1, 0, 0),
        G.G2MBFaceValueV1(:dirichlet, 0, _flux_u))
    unit_faces = (unit_mismatch, source.faces[2:end]...)
    unit_source = G.g2mb_source_v1(source.source_ref, source.source_version, source.candidate_ref,
        source.chart_map, source.mesh, unit_faces, source.profile, source.units, source.authority)
    @test G.g2mb_admit(unit_source).status === :fail_closed
    @test any(error -> occursin("boundary_value_unit_mismatch", error), G.g2mb_admit(unit_source).errors)
end

@testset "unit exponent algebra is enforced at admission and binds derived measures" begin
    source = _fixture_source()
    valid = source.units
    @test G.g2mb_unit_algebra_errors(valid) == ()
    @test G.g2mb_physical_oriented_area_measure(source.chart_map, (0, 0, 1), valid).unit == valid.area
    @test G.g2mb_volume_measure(source.chart_map, valid).unit == valid.volume
    bad_units = (
        (:reference_coordinate, G.UnitSignature((1, 0, 0, 0, 0, 0, 0)), "reference_coordinate_unit_mismatch"),
        (:coordinate, _ref_u, "coordinate_unit_mismatch"),
        (:jacobian, _metric_u, "jacobian_unit_mismatch"),
        (:metric, _coord_u, "metric_unit_mismatch"),
        (:area, _coord_u, "area_unit_mismatch"),
        (:volume, _metric_u, "volume_unit_mismatch"),
    )
    for (field, wrong, token) in bad_units
        values = (reference_coordinate=valid.reference_coordinate, coordinate=valid.coordinate,
            jacobian=valid.jacobian, metric=valid.metric, area=valid.area, volume=valid.volume,
            field_value=valid.field_value, flux_value=valid.flux_value)
        values = merge(values, NamedTuple{(field,)}((wrong,)))
        malformed_units = G.G2MBUnitContractV1(values.reference_coordinate, values.coordinate,
            values.jacobian, values.metric, values.area, values.volume, values.field_value,
            values.flux_value)
        malformed = G.g2mb_source_v1(source.source_ref, source.source_version, source.candidate_ref,
            source.chart_map, source.mesh, source.faces, source.profile, malformed_units, source.authority)
        admission = G.g2mb_admit(malformed)
        @test admission.status === :fail_closed
        @test token in admission.errors
    end
end

println("G2_METRIC_BOUNDARY_V1_STATIC_TEST_DEFINED=true")
println("G2_METRIC_BOUNDARY_V1_JULIA_OR_DESC_EXECUTED=false")
