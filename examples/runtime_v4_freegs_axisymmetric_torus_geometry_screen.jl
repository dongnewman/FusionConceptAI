# Candidate-authored torus geometry layer on the existing typed DESC Fourier consumer.
# Screen-only data preparation; no FreeGS, DESC, or MHD solve. The exact existing
# FreeGS declaration is carried into a new candidate hash with authored geometry.
using FusionConceptAI
using LinearAlgebra
const UP2_REPO_ROOT = let candidates = (normpath(joinpath(@__DIR__, "..")), normpath(joinpath(@__DIR__, "..", "..")), normpath(joinpath(@__DIR__, "..", "..", "..", "..")))
    match = findfirst(path -> isfile(joinpath(path, "examples", "runtime_v4_freegs_axisymmetric_execution.jl")), candidates)
    isnothing(match) && error("repository root not found")
    candidates[match]
end

include(joinpath(UP2_REPO_ROOT, "examples", "runtime_v4_freegs_axisymmetric_execution.jl"))

module TCG
using FusionConceptAI
const TCG_REPO_ROOT = Main.UP2_REPO_ROOT
include(joinpath(TCG_REPO_ROOT, "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(TCG_REPO_ROOT, "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(TCG_REPO_ROOT, "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(TCG_REPO_ROOT, "src", "RuntimeV4", "ThreeDPhysicalProviderInputV4.jl"))
include(joinpath(TCG_REPO_ROOT, "src", "RuntimeV4", "ThreeDNormalizedPhysicalRootBridgeV4.jl"))
include(joinpath(TCG_REPO_ROOT, "src", "RuntimeV4", "DESCGeometryProgramInterpreterV4.jl"))
end

const TC = FreeGSAxisymmetricRuntime
const G = TCG
const L_M = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const M2 = UnitSignature((0, 2, 0, 0, 0, 0, 0))
const LENGTH_TYPE = PhysicalType(:physical_coordinate_map, 1, 3,
    TemporalTypeV1(static_time), L_M)
const METRIC_TYPE = PhysicalType(:covariant_metric, 2, 3,
    TemporalTypeV1(static_time), M2)

# New candidate design values: not inferred from the FreeGS point samples.
const R0_M = 1.1
const A_M = 0.3
const NFP_CHART = 2 # one pi sector per unit zeta; duplicate twice for 2pi coverage
const SCALE = NonnegativeQuantityV1(11 // 10, L_M)
const FOURIER_BOUNDARY = G.ThreeDFourierBoundaryV4(
    "up2-freegs-candidate-authored-axisymmetric-torus-r1", NFP_CHART, true,
    (G.ThreeDFourierCoefficientV4(0, 0, R0_M),
     G.ThreeDFourierCoefficientV4(1, 0, A_M)),
    # The evaluator uses sine(2pi*m*theta); negative m with negative coeff gives +a*sin(theta).
    (G.ThreeDFourierCoefficientV4(-1, 0, -A_M),))
const GEOMETRY_PROGRAM = G.DESCFourierGeometryProgramV4(
    FOURIER_BOUNDARY, SCALE, (0, 1), (1,))
const COORD_SITE = FieldOperatorSiteRefV1("up2-freegs-torus-coordinate")
const METRIC_SITE = FieldOperatorSiteRefV1("up2-freegs-torus-metric")
const GEOMETRY_BINDING = G.desc_geometry_typed_binding(
    GEOMETRY_PROGRAM, COORD_SITE, METRIC_SITE)
const CHART_BOUNDS = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(0, 1, false), UnitSignature()), 3)
const SUPPORT_REF = SpatialSupportRefV1("up2-freegs-authored-torus-support-r1")
const CHART_REF = ChartRefV1("up2-freegs-authored-torus-chart-r1")
const FRAME_REF = CoordinateFrameRefV1("up2-freegs-authored-torus-frame-r1")
const PERIODIC = (
    PeriodicAxisV1(2, NonnegativeQuantityV1(1, UnitSignature())),
    PeriodicAxisV1(3, NonnegativeQuantityV1(1, UnitSignature())))
const GRAPH = TypedOperatorHypergraphV1((
    node(:chart_coordinate, chart_coordinate_type_v1(); id="up2-torus-chart"),
    node(:normalized_coordinate, normalized_ambient_coordinate_type_v1(); id="up2-torus-normalized-x"),
    node(:physical_coordinate, LENGTH_TYPE; id="up2-torus-x-m"),
    node(:normalized_metric, normalized_covariant_metric_type_v1(); id="up2-torus-normalized-g"),
    node(:physical_metric, METRIC_TYPE; id="up2-torus-g-m2")),
    (GEOMETRY_BINDING.coordinate_edge, GEOMETRY_BINDING.metric_edge);
    registry=GEOMETRY_BINDING.registry)
const GRAPH_BINDING = G._make_forward_graph_binding(:field_geometry, GRAPH)
const SUPPORT = SpatialSupportGeneV1(SUPPORT_REF, 3, (FRAME_REF,),
    (CoordinateChartGeneV1(CHART_REF, FRAME_REF, CHART_BOUNDS, PERIODIC,
        SpatialProgramRootRefV1(COORD_SITE, 1,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(METRIC_SITE, 1,
            chart_coordinate_type_v1(), normalized_covariant_metric_type_v1())),),
    (), SCALE)
const COORDINATE_METRIC = G.ThreeDCoordinateMetricV4(
    SUPPORT_REF, CHART_REF, COORD_SITE, METRIC_SITE,
    GRAPH_BINDING.ast_root_identity_hashes[2],
    GRAPH_BINDING.ast_root_identity_hashes[4], LENGTH_TYPE, METRIC_TYPE,
    CHART_BOUNDS)


_cross(a, b) = (a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1])
_dot(a, b) = sum(a[i]*b[i] for i in 1:3)
_scale(s, a) = ntuple(i -> s*a[i], 3)
_add(a, b) = ntuple(i -> a[i]+b[i], 3)
_rotate_pi(v) = (-v[1], -v[2], v[3])

"""Physical outward area-vector quadrature on rho=constant; one sector then both sectors."""
function toroidal_face_quadrature(rho::Float64; ntheta=8, nzeta=8)
    roots = (0.5 - 0.5/sqrt(3.0), 0.5 + 0.5/sqrt(3.0))
    out = NamedTuple[]
    for sector in 0:1, itheta in 0:(ntheta-1), izeta in 0:(nzeta-1),
        (gt, gz) in Iterators.product(roots, roots)
        theta = (itheta + gt)/ntheta
        zeta = (izeta + gz)/nzeta
        q = (rho, theta, zeta)
        xyz0 = G.desc_coordinate(GEOMETRY_PROGRAM, q)
        J = G.desc_coordinate_jacobian(GEOMETRY_PROGRAM, q) # rows xyz, columns rho/theta/zeta
        jt = (J[1][2], J[2][2], J[3][2])
        jz = (J[1][3], J[2][3], J[3][3])
        # det(J)<0 in this chart. Negate cofactor cross(j_theta,j_zeta)
        # so the resulting rho-normal is physically outward (+rho).
        dA_dturns = _scale(-1.0, _cross(jt, jz))
        dturn_area = (1.0/ntheta) * (1.0/nzeta) * 0.25
        dA = _scale(dturn_area, dA_dturns)
        xyz = sector == 0 ? xyz0 : _rotate_pi(xyz0)
        area_vector = sector == 0 ? dA : _rotate_pi(dA)
        area = sqrt(_dot(area_vector, area_vector))
        normal = _scale(1.0/area, area_vector)
        isfinite(area) && area > 0 && all(isfinite, xyz) && all(isfinite, normal) ||
            error("invalid toroidal surface quadrature sample")
        push!(out, (rho=rho, sector=sector, theta_turn=theta,
            zeta_period_turn=zeta, xyz_m=xyz, outward_area_vector_m2=area_vector,
            area_weight_m2=area, outward_unit_normal=normal))
    end
    Tuple(out)
end

const OUTER_FACE_QP = toroidal_face_quadrature(1.0)
const CORE_EDGE_QP = toroidal_face_quadrature(0.5)
const COIL_RING_SUPPORT = Tuple((
    coil_id=coil.coil_id,
    major_radius_m=coil.major_radius_m,
    vertical_position_m=coil.vertical_position_m,
    current_a=nothing,
    current_source="artifacts.output_json decoded raw JSON field coil_currents_a[coil_id]",
    current_status=:typed_absent,
    current_result_status=:source_pending_not_read,
    parameterization="r(phi)=(R*cos(phi),R*sin(phi),Z), phi from 0 to 2pi",
    positive_current_direction="+e_phi, counterclockwise viewed from +Z",
    closed_filament_ring=true, finite_cross_section=false)
    for coil in freegs_axisymmetric_declaration.coils)
const REGION_TOPOLOGY = (
    regions=((region_id="plasma_core", rho=(0.0, 0.5), angular_cells=(8, 8)),
             (region_id="plasma_edge", rho=(0.5, 1.0), angular_cells=(8, 8))),
    core_edge_interface=(minus="plasma_core", plus="plasma_edge",
        reference_normal=(1, 0, 0), continuity=:trace_flux,
        transfer=:conservative),
    outer_face=(owner="plasma_edge", rho=1.0,
        reference_normal=(1, 0, 0), sector_count=2),
    periodic_seams=((axis=:theta_turn, pair=(0.0, 1.0), rotation_rad=0.0),
        (axis=:zeta_period_turn, pair=(0.0, 1.0), rotation_rad=3.141592653589793)),
    axis_merge=(rho=0.0, all_angular_copies=true, boundary_face=false))

# The authored face data must be included in the new candidate identity.
const BASE = freegs_candidate
const FIELD_GENOME = FieldGeometryGenomeV4(20261005,
    BASE.field_geometry_genome_ref.contract_ref, GRAPH;
    fields=(freegs_axisymmetric_declaration, FOURIER_BOUNDARY,
        GEOMETRY_PROGRAM, SUPPORT, COORDINATE_METRIC,
        REGION_TOPOLOGY, OUTER_FACE_QP, CORE_EDGE_QP, COIL_RING_SUPPORT))
const CANDIDATE = CandidateStatePackageV4(
    "runtime-v4-freegs-axisymmetric-torus-design-r1",
    BASE.mission_contract_ref, BASE.mechanism_genome_ref,
    FIELD_GENOME, BASE.realization_control_genome_ref, registry)


const FREEGS_MISSION = (
    mission_id="candidate-authored-axisymmetric-torus-screen-r1",
    model_scope="static-axisymmetric-free-boundary-grad-shafranov",
    contract=CANDIDATE.mission_contract_ref)
const FREEGS_BOUNDS = (
    declaration_hash=canonical_hash(freegs_axisymmetric_declaration),
    candidate_geometry_hash=CANDIDATE.canonical_hashes.field_geometry_hash,
    model="FreeGS-0.8.2-explicit-filament-bounded-subset",
    maximum_grid_points_per_axis=257)
const FREEGS_COMPARISON_SCOPE = ("candidate-authored-freegs-torus-screen-r1",)
const FREEGS_SCENARIO = (name="nominal-static-equilibrium-torus-design-r1",
    load_case="candidate-authored-design-input")
const FREEGS_SCENARIO_SCOPE = (FREEGS_SCENARIO.name,)
const FREEGS_COMPILED = TC.compile_candidate(CANDIDATE, registry;
    mission_payload=FREEGS_MISSION, bounds_payload=FREEGS_BOUNDS,
    comparison_scope=FREEGS_COMPARISON_SCOPE,
    scenario_scope=FREEGS_SCENARIO_SCOPE)
const FREEGS_BINDING = TC.make_axisymmetric_equilibrium_binding(
    FREEGS_COMPILED, registry, FREEGS_MISSION, FREEGS_BOUNDS,
    FREEGS_COMPARISON_SCOPE, FREEGS_SCENARIO_SCOPE, FREEGS_SCENARIO,
    freegs_axisymmetric_declaration)
const FREEGS_SUBJECT = TC.ExecutablePhysicalSubjectV4(
    FREEGS_COMPILED.prefix_hash, CANDIDATE.canonical_hashes.genome_bundle_hash,
    FREEGS_COMPILED.minimality_scope.mission_hash,
    FREEGS_COMPILED.minimality_scope.bounds_hash, (FREEGS_BINDING,),
    (FREEGS_SCENARIO,),
    (materialization="candidate-authored-torus-geometry-and-FreeGS-declaration",
     declaration_hash=canonical_hash(freegs_axisymmetric_declaration),
     geometry_design_hash=canonical_hash((FOURIER_BOUNDARY, GEOMETRY_PROGRAM,
         REGION_TOPOLOGY, OUTER_FACE_QP, CORE_EDGE_QP))),
    TC.derive_capability_obligations(FREEGS_COMPILED))
const FREEGS_CONTEXT = TC.make_forward_chain_context(
    CANDIDATE, FREEGS_COMPILED, registry, FREEGS_MISSION, FREEGS_BOUNDS,
    FREEGS_COMPARISON_SCOPE, FREEGS_SCENARIO_SCOPE, FREEGS_SUBJECT,
    FREEGS_SCENARIO)
const FREEGS_SOLVER_INPUT = TC.freegs_axisymmetric_solver_input(FREEGS_CONTEXT)


function run_candidate_torus_geometry_screen(io::IO=stdout)
    freegs_axisymmetric_declaration in CANDIDATE.field_geometry_genome_ref.fields ||
        error("candidate lost its exact FreeGS G2 declaration")
    CANDIDATE.canonical_hashes.field_geometry_hash ==
        canonical_hash(CANDIDATE.field_geometry_genome_ref) ||
        error("candidate G2 field hash mismatch")
    q = (0.7, 0.25, 0.2)
    point = G.desc_coordinate(GEOMETRY_PROGRAM, q)
    J = G.desc_coordinate_jacobian(GEOMETRY_PROGRAM, q)
    metric = G.desc_metric(GEOMETRY_PROGRAM, q)
    detJ = J[1][1]*(J[2][2]*J[3][3]-J[2][3]*J[3][2]) -
        J[1][2]*(J[2][1]*J[3][3]-J[2][3]*J[3][1]) +
        J[1][3]*(J[2][1]*J[3][2]-J[2][2]*J[3][1])
    detJ < 0 || error("authored torus chart orientation sign changed")
    length(OUTER_FACE_QP) == 512 && length(CORE_EDGE_QP) == 512 ||
        error("unexpected two-sector face quadrature count")
    all(qp -> qp.area_weight_m2 > 0, OUTER_FACE_QP) || error("nonpositive outer face weight")
    radial(qp) = (cospi(2*qp.theta_turn)*cospi(qp.zeta_period_turn + qp.sector),
        cospi(2*qp.theta_turn)*sinpi(qp.zeta_period_turn + qp.sector),
        sinpi(2*qp.theta_turn))
    all(qp -> _dot(qp.outward_unit_normal, radial(qp)) > 0, OUTER_FACE_QP) ||
        error("outer face normal is not outward")
    all(qp -> _dot(qp.outward_unit_normal, radial(qp)) > 0, CORE_EDGE_QP) ||
        error("core-to-edge interface normal is not +rho")
    current_values_present = all(x -> x.current_a !== nothing, COIL_RING_SUPPORT)
    println(io, "candidate_id=", CANDIDATE.identity_ref)
    println(io, "candidate_hash=", CANDIDATE.canonical_hashes.genome_bundle_hash)
    println(io, "freegs_declaration_hash=", canonical_hash(freegs_axisymmetric_declaration))
    println(io, "freegs_context_hash=", FREEGS_CONTEXT.context_hash)
    println(io, "freegs_binding_hash=", FREEGS_BINDING.binding_hash)
    println(io, "freegs_solver_input_hash=", canonical_hash(FREEGS_SOLVER_INPUT))
    println(io, "geometry_program_hash=", canonical_hash(GEOMETRY_PROGRAM))
    println(io, "geometry_point_xyz_m=", point)
    println(io, "geometry_detJ_m3_per_turn3=", detJ)
    println(io, "geometry_metric_m2=", metric)
    println(io, "outer_face_qp_count=", length(OUTER_FACE_QP))
    println(io, "core_edge_interface_qp_count=", length(CORE_EDGE_QP))
    println(io, "outer_face_area_vector_hash=", canonical_hash(OUTER_FACE_QP))
    println(io, "core_edge_area_vector_hash=", canonical_hash(CORE_EDGE_QP))
    println(io, "ideal_ring_support_count=", length(COIL_RING_SUPPORT))
    println(io, "solved_current_values_present=", current_values_present)
    println(io, "finite_cross_section=unsupported")
    println(io, "plasma_return_current_path=typed_absent")
    println(io, "K_outer=typed_absent")
    println(io, "claim_ceiling=screen_only")
    println(io, "physical_validation=false")
    println(io, "credible_device_count=0")
    nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_candidate_torus_geometry_screen()
end
