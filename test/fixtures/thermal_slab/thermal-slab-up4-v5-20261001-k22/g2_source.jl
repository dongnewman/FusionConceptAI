# Candidate-owned affine SI chart and six thermal boundary faces for the slab.
function up4_r2_build_g2_design(source_expressions)
    id = UP4_R2_IDENTITY
    source_expressions.schema == "up4-r2-native-mms-source-expressions-v1" &&
        source_expressions.status == "candidate_design_projection_only" &&
        source_expressions.design_scope == "candidate_design_only" &&
        source_expressions.compiler_rebuild_required === true ||
        throw(ArgumentError("thermal slab expression scope mismatch"))
    source_expressions.candidate_id == id.candidate_id &&
        source_expressions.candidate_ref == id.candidate_ref.id &&
        source_expressions.scenario_id == id.scenario_id &&
        source_expressions.scenario_ref == id.scenario_ref.id &&
        source_expressions.formula == "steady_planar_quadratic_diffusion_v1" ||
        throw(ArgumentError("thermal slab G2 identity/formula mismatch"))
    candidate = id.candidate_ref
    profile = G2MBProfileV1(G2MB_PROFILE_ID_V1)
    contract = GenomeContractRef("fusionconceptai://GenomeV5/G2/metric-boundary/public-contract/v1",
        "v5", g2mb_schema_hash_v1(false), g2mb_canonicalization_hash_v1(),
        g2mb_profile_token_v1(profile))
    source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/source/thermal-slab-up4-v5-20261001-k22", "v1")
    chart_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/chart/thermal-slab-up4-v5-20261001-k22", "v1")
    mesh_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/mesh/thermal-slab-up4-v5-20261001-k22", "v1")
    chart = G2MBChartMapV1(chart_ref, (0//1,0//1,0//1), (1//1,1//1,1//1),
        ((2//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)),
        (0//1,0//1,0//1); axes=(:x,:y,:z))
    mesh = G2MBMeshPlanV1(mesh_ref, chart_ref, (4,1,1), :Q1,
        ((1//2,1//2,1//2),), (1//1,); execution_status=:not_executed)
    zero = UnitSignature()
    length = UnitSignature((1,0,0,0,0,0,0))
    square = UnitSignature((2,0,0,0,0,0,0))
    cube = UnitSignature((3,0,0,0,0,0,0))
    temperature = UnitSignature((0,0,0,0,1,0,0))
    conormal = UnitSignature((0,1,-3,0,0,0,0))
    units = G2MBUnitContractV1(zero, length, length, square, square, cube,
        temperature, conormal)
    field_space = G2MBFieldSpaceV1("temperature", :scalar, "K", temperature)
    dirichlet(value) = G2MBFaceValueV1(:dirichlet, value, temperature)
    neumann_zero = G2MBFaceValueV1(:neumann, 0//1, conormal)
    faces = (
        G2MBFaceOwnerV1("thermal_x_min", :x_min, "thermal_slab", (-1,0,0), dirichlet(300//1)),
        G2MBFaceOwnerV1("thermal_x_max", :x_max, "thermal_slab", (1,0,0), dirichlet(300//1)),
        G2MBFaceOwnerV1("thermal_y_min", :y_min, "thermal_slab", (0,-1,0), neumann_zero),
        G2MBFaceOwnerV1("thermal_y_max", :y_max, "thermal_slab", (0,1,0), neumann_zero),
        G2MBFaceOwnerV1("thermal_z_min", :z_min, "thermal_slab", (0,0,-1), neumann_zero),
        G2MBFaceOwnerV1("thermal_z_max", :z_max, "thermal_slab", (0,0,1), neumann_zero),
    )
    source = g2mb_source_v1(source_ref, "thermal-slab-source-v1", contract,
        chart, mesh, faces, profile, units,
        G2MBAuthorityV1(:missing, :missing, :missing);
        field_space=field_space, q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1,
        boundary_coverage=:whole_face)
    declaration = g2mb_declaration_v1(contract, source)
    (candidate_id=id.candidate_id, scenario_id=id.scenario_id,
     candidate_ref=candidate, contract_ref=contract, source_ref=source_ref,
     source=source, declaration=declaration, admission=g2mb_admit(source),
     mesh_execution=:not_executed, physical_resolution=:unknown)
end
