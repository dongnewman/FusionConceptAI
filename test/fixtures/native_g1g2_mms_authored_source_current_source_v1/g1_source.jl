# Test-only current-source G1 authoring fixture for the native MMS contract.
function up4_r2_canonical_ast_json_value(value)
    value isa AbstractDict && return Dict{String,Any}(
        String(key) => up4_r2_canonical_ast_json_value(child)
        for (key, child) in value)
    value isa AbstractArray && return Tuple(
        up4_r2_canonical_ast_json_value(child) for child in value)
    value
end

function up4_r2_build_g1_design(source_expressions)
    identity = UP4_R2_IDENTITY
    source_expressions.schema == "up4-r2-native-mms-source-expressions-v1" ||
        throw(ArgumentError("unexpected native MMS source-expression schema"))
    source_expressions.status == "candidate_design_projection_only" &&
        source_expressions.design_scope == "candidate_design_only" &&
        source_expressions.compiler_rebuild_required === true ||
        throw(ArgumentError("native MMS expression record is not design-only and rebuildable"))
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
    k_base = Tuple(ratio(x) for x in source_expressions.k_base)
    k_slope = Tuple(ratio(x) for x in source_expressions.k_slope)
    physical_lower == (1//2, 1//3, 1//4) &&
        physical_upper == (5//2, 10//3, 17//4) &&
        all(x > 0 for x in k_base) && all(x >= 0 for x in k_slope) &&
        source_expressions.formula == "tensor_bubble_product_variable_diagonal_affine_v1" &&
        source_expressions.boundary_semantics == "all_six_faces_zero_dirichlet" &&
        source_expressions.source_sign == "minus_div_k_grad" ||
        throw(ArgumentError("native MMS G1 source-expression parameters mismatch"))
    G = Main.NG12_G
    R = Main.NG12_R
    profile = R.native_g1g2_unit_compatibility_profile_v1()
    programs = R.native_g1g2_program_bundle_v1(profile;
        physical_lower=physical_lower, physical_upper=physical_upper,
        k_base=k_base, k_slope=k_slope)
    expression_fields = (:unknown_source_expression, :source_expression, :bundle_hash)
    unknown_expression = programs.unknown_source_expression
    source_expression = programs.source_expression
    authored_fields = (:authored_u_ast, :authored_f_ast)
    if all(name -> hasproperty(source_expressions, name), authored_fields)
        unknown_expression = G.canonical_json(
            up4_r2_canonical_ast_json_value(source_expressions.authored_u_ast))
        source_expression = G.canonical_json(
            up4_r2_canonical_ast_json_value(source_expressions.authored_f_ast))
    elseif any(name -> hasproperty(source_expressions, name), authored_fields)
        throw(ArgumentError("native MMS authored AST roots are incomplete"))
    elseif all(name -> hasproperty(source_expressions, name), expression_fields)
        String(source_expressions.unknown_source_expression) == programs.unknown_source_expression &&
            String(source_expressions.source_expression) == programs.source_expression &&
            String(source_expressions.bundle_hash) == programs.bundle_hash.value ||
            throw(ArgumentError("native MMS expression bytes differ from frozen source parameters"))
    elseif any(name -> hasproperty(source_expressions, name), expression_fields)
        throw(ArgumentError("native MMS source-expression projection is incomplete"))
    end

    zero = G.UnitSignature()
    grad_unit = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    source_unit = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    static = G.TemporalTypeV1(G.static_time)
    scalar = G.PhysicalType(:scalar_field, 0, 3, static, zero)
    gradient = G.PhysicalType(:vector_field, 1, 3, static, grad_unit)
    tensor = G.PhysicalType(:tensor_field, 2, 3, static, zero)
    source_type = G.PhysicalType(:scalar_field, 0, 3, static, source_unit)
    source_ref = G.QualifiedRefV1("local://native-g1g2/g1/source/" *
        programs.bundle_hash.value[1:16], "v1")
    u = G.G1DiffusionScalarFieldV1("u", scalar, source_ref;
        source_expression=unknown_expression)
    k_expression = G.G1DiffusionDiagonalAffineKFieldV1(
        "native-g1g2-diagonal-affine-K"; domain_min=physical_lower,
        domain_max=physical_upper, base_diag=k_base, slope_diag=k_slope)
    enclosure = G.g1_diffusion_k_enclosure(k_expression)
    k = G.G1DiffusionCoefficientFieldV1("K", tensor, source_ref;
        lower_bound=enclosure.lower, upper_bound=enclosure.upper,
        expression=k_expression)
    f = G.G1DiffusionScalarFieldV1("f", source_type, source_ref;
        source_expression=source_expression)
    grad = G.G1TypedGradV1(G.QualifiedRefV1(
        G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"),
        "u", "grad_u", scalar, gradient)
    apply = G.G1TypedKApplyV1(G.QualifiedRefV1(
        G.G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1"),
        "grad_u", "K_grad_u", gradient, gradient, "K";
        coefficient_units=zero)
    div = G.G1TypedDivV1(G.QualifiedRefV1(
        G.G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1"),
        "K_grad_u", "f", gradient, source_type)
    operators = G.G1DiffusionOperatorChainV1(grad, apply, div, "f")
    payload = G.G1DiffusionSourcePayloadV1(identity.candidate_ref, source_ref,
        "native-g1g2-mms-source-v1", u, k, f)
    closure = G.QualifiedRefV1(G.G1_DIFFUSION_CLOSURE_ID_V1,
        G.G1_DIFFUSION_PROFILE_VERSION_V1)
    applicability = G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1,
        G.G1_DIFFUSION_PROFILE_VERSION_V1)
    declaration = G.g1_diffusion_declaration_v1(identity.candidate_ref,
        source_ref, "native-g1g2-mms-source-v1",
        G.g1_diffusion_source_hash_v1(payload), u, k, f, operators,
        closure, applicability,
        "single-physical-cartesian-box-variable-diagonal-diffusion",
        (:manufactured_reference, :source_sign, :coefficient_domain);
        source_payload=payload)
    return (candidate_id=identity.candidate_id, scenario_id=identity.scenario_id,
        candidate_ref=identity.candidate_ref, source_ref=source_ref,
        source_payload=payload, declaration=declaration,
        admission=G.g1_diffusion_admit_v1(declaration), physical_resolution=:unknown)
end
