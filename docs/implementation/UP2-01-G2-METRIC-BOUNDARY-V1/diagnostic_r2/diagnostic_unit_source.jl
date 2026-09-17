using FusionConceptAI

const _G2MB_SOURCE = joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl")
Base.include(FusionConceptAI, _G2MB_SOURCE)
const G = FusionConceptAI
const r(n, d=1) = Int64(n) // Int64(d)
const chart_ref = G.QualifiedRefV1("fusion.g2.metric-boundary.chart", "v1")
const mesh_ref = G.QualifiedRefV1("fusion.g2.metric-boundary.mesh", "v1")
const ref_u = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
const coord_u = G.UnitSignature((1, 0, 0, 0, 0, 0, 0))
const metric_u = G.UnitSignature((2, 0, 0, 0, 0, 0, 0))
const volume_u = G.UnitSignature((3, 0, 0, 0, 0, 0, 0))
const field_u = G.UnitSignature((0, 0, 0, 0, 0, 0, 1))
const flux_u = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))

chart = G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1),
    ((2, 0, 0), (0, 3, 0), (0, 0, 4)), (r(1, 2), r(1, 3), r(1, 4)))
mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2, 3, 4), :Q1,
    ((r(1, 2), r(1, 2), r(1, 2)), (r(1, 4), r(1, 4), r(1, 4))), (1, r(1, 2));
    execution_status=:not_executed)
faces = (
    G.G2MBFaceOwnerV1("face-x-min", :x_min, "candidate-domain", (-1, 0, 0), G.G2MBFaceValueV1(:dirichlet, 0, flux_u)),
    G.G2MBFaceOwnerV1("face-x-max", :x_max, "candidate-domain", (1, 0, 0), G.G2MBFaceValueV1(:neumann, 1, flux_u)),
    G.G2MBFaceOwnerV1("face-y-min", :y_min, "candidate-domain", (0, -1, 0), G.G2MBFaceValueV1(:dirichlet, 0, field_u)),
    G.G2MBFaceOwnerV1("face-y-max", :y_max, "candidate-domain", (0, 1, 0), G.G2MBFaceValueV1(:neumann, 1, flux_u)),
    G.G2MBFaceOwnerV1("face-z-min", :z_min, "candidate-domain", (0, 0, -1), G.G2MBFaceValueV1(:dirichlet, 0, field_u)),
    G.G2MBFaceOwnerV1("face-z-max", :z_max, "candidate-domain", (0, 0, 1), G.G2MBFaceValueV1(:neumann, 1, flux_u)))
profile = G.G2MBProfileV1("fusion.g2.metric-boundary.profile.fixture")
units = G.G2MBUnitContractV1(ref_u, coord_u, coord_u, metric_u, metric_u, volume_u, field_u, flux_u)
authority = G.G2MBAuthorityV1(:unique_match, :no_match, :no_match)
candidate = G.GenomeContractRef(
    "fusionconceptai://GenomeV5/candidate/up2-01-g2-metric-boundary-fixture", "v5",
    G.digest256_text("candidate-schema-up2-01-g2-metric-boundary"),
    G.digest256_text("candidate-canonicalization-up2-01-g2-metric-boundary"), "candidate-profile")
source = G.g2mb_source_v1(G.QualifiedRefV1("fusionconceptai://source/up2-01-g2-metric-boundary-fixture", "v1"),
    "g2-metric-boundary-source-v1", candidate, chart, mesh, faces, profile, units, authority)
unit_source = G.g2mb_source_v1(source.source_ref, source.source_version, source.candidate_ref,
    source.chart_map, source.mesh, faces, source.profile, source.units, source.authority)
admission = G.g2mb_admit(unit_source)
println("diagnostic=unit_source_boundary_value")
println("status=", admission.status)
println("error_code=", admission.error_code)
println("errors=", admission.errors)
println("gaps=", admission.gaps)
println("face_value_unit=", unit_source.faces[1].value.unit)
println("field_value_unit=", unit_source.units.field_value)
println("flux_value_unit=", unit_source.units.flux_value)
println("source_hash=", unit_source.source_hash)
