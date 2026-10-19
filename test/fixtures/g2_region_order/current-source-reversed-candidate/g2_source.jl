# Target: G2SourceAuthorityFactoryV1 -> T0 -> V1/V2 -> T1 V2 -> V3.
# Next gate: 240s / 2 GiB local software source admission only; mesh execution remains not_executed.
# The reference unit cube maps to the native MMS physical box; its Q1 mesh resolution and
# six zero Dirichlet declarations match the frozen numerical contract. These remain authored
# design fields, not externally sourced geometry or a physical boundary claim. Authority is missing.
# Require the same frozen source-expression record consumed by the G1 builder so chart and
# coefficient labels cannot silently drift apart. The caller verifies record hashes/provenance.
function up4_r2_build_g2_design(source_expressions)
    source_expressions.schema == "up4-r2-native-mms-source-expressions-v1" ||
        throw(ArgumentError("unexpected native MMS source-expression schema"))
    source_expressions.status == "candidate_design_projection_only" ||
        throw(ArgumentError("native MMS record is not a candidate-design projection"))
    source_expressions.design_scope == "candidate_design_only" ||
        throw(ArgumentError("native MMS record is outside candidate-design scope"))
    source_expressions.compiler_rebuild_required === true ||
        throw(ArgumentError("native MMS record requires later compiler reconstruction"))
    source_expressions.candidate_id == "local-authored-up4-g123-20260928-r2" ||
        throw(ArgumentError("native MMS candidate identity mismatch"))
    source_expressions.candidate_ref ==
        "fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2" ||
        throw(ArgumentError("native MMS candidate reference mismatch"))
    source_expressions.scenario_id == "scenario-local-authored-up4-g123-20260928-r2" ||
        throw(ArgumentError("native MMS scenario identity mismatch"))
    source_expressions.scenario_ref ==
        "fusionconceptai://scenario-design/scenario-local-authored-up4-g123-20260928-r2" ||
        throw(ArgumentError("native MMS scenario reference mismatch"))
    source_expressions.formula == "tensor_bubble_product_variable_diagonal_affine_v1" ||
        throw(ArgumentError("native MMS formula mismatch"))
    Tuple(String.(source_expressions.physical_lower_metres)) == ("1/2", "1/3", "1/4") ||
        throw(ArgumentError("native MMS lower chart mismatch"))
    Tuple(String.(source_expressions.physical_upper_metres)) == ("5/2", "10/3", "17/4") ||
        throw(ArgumentError("native MMS upper chart mismatch"))
    Tuple(String.(source_expressions.k_base)) == ("2/1", "3/1", "4/1") ||
        throw(ArgumentError("native MMS coefficient base mismatch"))
    Tuple(String.(source_expressions.k_slope)) == ("1/10", "1/20", "1/30") ||
        throw(ArgumentError("native MMS coefficient slope mismatch"))
    source_expressions.boundary_semantics == "all_six_faces_zero_dirichlet" ||
        throw(ArgumentError("native MMS boundary contract mismatch"))
    source_expressions.source_sign == "minus_div_k_grad" ||
        throw(ArgumentError("native MMS source sign mismatch"))
    source_expressions.length_scale_metres == "1/1" ||
        throw(ArgumentError("native MMS length scale mismatch"))
    identity = UP4_R2_IDENTITY
    candidate = identity.candidate_ref
    profile = G2MBProfileV1(G2MB_PROFILE_ID_V1)
    contract = GenomeContractRef("fusionconceptai://GenomeV5/G2/metric-boundary/public-contract/v1", "v5",
        g2mb_schema_hash_v1(true), g2mb_canonicalization_hash_v1(), g2mb_profile_token_v1(profile))
    source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/source/local-authored-up4-g123-20260928-r2", "v1")
    chart_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/chart/local-authored-up4-g123-20260928-r2", "v1")
    mesh_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/mesh/local-authored-up4-g123-20260928-r2", "v1")
    chart = G2MBChartMapV1(chart_ref, (0//1,0//1,0//1), (1//1,1//1,1//1),
        ((2//1,0//1,0//1),(0//1,3//1,0//1),(0//1,0//1,4//1)),
        (1//2,1//3,1//4); axes=(:x,:y,:z))
    mesh = G2MBMeshPlanV1(mesh_ref, chart_ref, (2,3,4), :Q1,
        ((1//2,1//2,1//2),), (1//1,); execution_status=:not_executed)

    zero = UnitSignature()
    length_unit = UnitSignature((1,0,0,0,0,0,0))
    square_unit = UnitSignature((2,0,0,0,0,0,0))
    cube_unit = UnitSignature((3,0,0,0,0,0,0))
    flux_unit = UnitSignature((-1,0,0,0,0,0,0))
    units = G2MBUnitContractV1(zero, length_unit, length_unit, square_unit,
        square_unit, cube_unit, zero, flux_unit)
    field_space = G2MBFieldSpaceV1("u", :scalar, "1", zero)
    # Candidate-authored exact partition of the unit chart box at x=1/2.
    region_chart_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/chart/local-authored-up4-g123-20260928-r2", "v2")
    embedding_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/embedding/local-authored-up4-g123-20260928-r2", "v2")
    field_space_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/field-space/local-authored-up4-g123-20260928-r2", "v2")
    regions = (
        G2RegionV2("local_unit_cube_right", (1//2,0//1,0//1), (1//1,1//1,1//1),
            region_chart_ref, embedding_ref, field_space_ref, (:dirichlet,)),
        G2RegionV2("local_unit_cube_left", (0//1,0//1,0//1), (1//2,1//1,1//1),
            region_chart_ref, embedding_ref, field_space_ref, (:dirichlet,)),
    )
    interface = G2InterfaceV2(QualifiedRefV1("fusionconceptai://GenomeV5/G2/interface/local-authored-up4-g123-20260928-r2/x-half", "v2"),
        "local_unit_cube_left", "local_unit_cube_right", 1, 1//2, 1, :trace_flux, :conservative)
    region_interface = RegionInterfaceContractV2(regions, (interface,))
    faces = (
        G2MBFaceOwnerV1("x_min_owner", :x_min, "local_unit_cube", (-1,0,0), G2MBFaceValueV1(:dirichlet, 0//1, zero)),
        G2MBFaceOwnerV1("x_max_owner", :x_max, "local_unit_cube", (1,0,0), G2MBFaceValueV1(:dirichlet, 0//1, zero)),
        G2MBFaceOwnerV1("y_min_owner", :y_min, "local_unit_cube", (0,-1,0), G2MBFaceValueV1(:dirichlet, 0//1, zero)),
        G2MBFaceOwnerV1("y_max_owner", :y_max, "local_unit_cube", (0,1,0), G2MBFaceValueV1(:dirichlet, 0//1, zero)),
        G2MBFaceOwnerV1("z_min_owner", :z_min, "local_unit_cube", (0,0,-1), G2MBFaceValueV1(:dirichlet, 0//1, zero)),
        G2MBFaceOwnerV1("z_max_owner", :z_max, "local_unit_cube", (0,0,1), G2MBFaceValueV1(:dirichlet, 0//1, zero)),
    )
    region_exterior_owners = (
        G2MBRegionExteriorOwnerV1(:x_min, "local_unit_cube_left"),
        G2MBRegionExteriorOwnerV1(:x_max, "local_unit_cube_right"),
        G2MBRegionExteriorOwnerV1(:y_min, "local_unit_cube_left"),
        G2MBRegionExteriorOwnerV1(:y_min, "local_unit_cube_right"),
        G2MBRegionExteriorOwnerV1(:y_max, "local_unit_cube_left"),
        G2MBRegionExteriorOwnerV1(:y_max, "local_unit_cube_right"),
        G2MBRegionExteriorOwnerV1(:z_min, "local_unit_cube_left"),
        G2MBRegionExteriorOwnerV1(:z_min, "local_unit_cube_right"),
        G2MBRegionExteriorOwnerV1(:z_max, "local_unit_cube_left"),
        G2MBRegionExteriorOwnerV1(:z_max, "local_unit_cube_right"),
    )
    source = g2mb_source_v1(source_ref, "local-authored-v1", contract,
        chart, mesh, faces, profile, units, G2MBAuthorityV1(:missing, :missing, :missing);
        field_space=field_space,
        q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1,
        boundary_coverage=:whole_face, region_interface=region_interface,
        region_exterior_owners=region_exterior_owners)
    declaration = g2mb_declaration_v1(contract, source)
    return (candidate_id=identity.candidate_id, scenario_id=identity.scenario_id,
        candidate_ref=candidate, contract_ref=contract, source_ref=source_ref,
        source=source, declaration=declaration, admission=g2mb_admit(source),
        mesh_execution=:not_executed, physical_resolution=:unknown)
end
