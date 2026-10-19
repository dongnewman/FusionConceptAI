# Test-only current-source G2 authoring fixture for the native MMS Q1 box.
function up4_r2_build_g2_design(source_expressions)
    identity = UP4_R2_IDENTITY
    source_expressions.schema == "up4-r2-native-mms-source-expressions-v1" &&
        source_expressions.status == "candidate_design_projection_only" &&
        source_expressions.design_scope == "candidate_design_only" &&
        source_expressions.compiler_rebuild_required === true ||
        throw(ArgumentError("native MMS G2 expression record is not design-only and rebuildable"))
    source_expressions.candidate_id == identity.candidate_id &&
        source_expressions.candidate_ref == identity.candidate_ref.id &&
        source_expressions.scenario_id == identity.scenario_id &&
        source_expressions.scenario_ref == identity.scenario_ref.id ||
        throw(ArgumentError("native MMS candidate/scenario identity mismatch"))
    ratio(s) = begin
        parts = split(String(s), "/"; limit=2)
        length(parts) == 2 || throw(ArgumentError("native MMS rational label is malformed"))
        parse(Int64, parts[1]) // parse(Int64, parts[2])
    end
    physical_lower = Tuple(ratio(x) for x in source_expressions.physical_lower_metres)
    physical_upper = Tuple(ratio(x) for x in source_expressions.physical_upper_metres)
    physical_lower == (1//2, 1//3, 1//4) &&
        physical_upper == (5//2, 10//3, 17//4) &&
        source_expressions.formula == "tensor_bubble_product_variable_diagonal_affine_v1" &&
        source_expressions.boundary_semantics == "all_six_faces_zero_dirichlet" ||
        throw(ArgumentError("native MMS G2 chart/boundary parameters mismatch"))
    G = Main.NG12_G
    chart_ref = G.QualifiedRefV1("local://native-g1g2/g2/physical-chart", "v1")
    mesh_ref = G.QualifiedRefV1("local://native-g1g2/g2/q1-mesh", "v1")
    chart_rows = ((2, 0, 0), (0, 3, 0), (0, 0, 4))
    chart = G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1),
        chart_rows, physical_lower; axes=(:x, :y, :z))
    cells = Tuple(Int(x) for x in source_expressions.mesh_cells)
    length(cells) == 3 && all(x > 0 for x in cells) ||
        throw(ArgumentError("native MMS mesh cell counts are invalid"))
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, cells, :Q1,
        ((1//2, 1//2, 1//2),), (1//1,); execution_status=:not_executed)
    face_specs = (("x-min", :x_min, (-1, 0, 0)),
        ("x-max", :x_max, (1, 0, 0)),
        ("y-min", :y_min, (0, -1, 0)),
        ("y-max", :y_max, (0, 1, 0)),
        ("z-min", :z_min, (0, 0, -1)),
        ("z-max", :z_max, (0, 0, 1)))
    faces = ntuple(i -> begin
        id, face, normal = face_specs[i]
        G.G2MBFaceOwnerV1(id, face, "native-g1g2-region", normal,
            G.G2MBFaceValueV1(:dirichlet, 0//1, G.UnitSignature()))
    end, 6)
    length_unit = G.UnitSignature((1, 0, 0, 0, 0, 0, 0))
    area_unit = G.UnitSignature((2, 0, 0, 0, 0, 0, 0))
    volume_unit = G.UnitSignature((3, 0, 0, 0, 0, 0, 0))
    flux_unit = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    units = G.G2MBUnitContractV1(G.UnitSignature(), length_unit, length_unit,
        area_unit, area_unit, volume_unit, G.UnitSignature(), flux_unit)
    contract = G._g2sf_expected_contract()
    source_ref = G.QualifiedRefV1("local://native-g1g2/g2/source", "v1")
    profile = G.G2MBProfileV1("fusion.g2.metric-boundary.profile")
    source = G.g2mb_source_v1(source_ref, "native-g1g2-g2-source-v1",
        contract, chart, mesh, faces, profile, units,
        G.G2MBAuthorityV1(:unique_match, :unique_match, :unique_match))
    declaration = G.g2mb_declaration_v1(contract, source)
    return (candidate_id=identity.candidate_id, scenario_id=identity.scenario_id,
        candidate_ref=identity.candidate_ref, contract_ref=contract,
        source_ref=source_ref, source=source, declaration=declaration,
        admission=G.g2mb_admit(source), mesh_execution=:not_executed,
        physical_resolution=:unknown)
end
