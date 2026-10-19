# Candidate-owned SI steady planar diffusion fields for the thermal-slab fixture.
function up4_r2_build_g1_design(source_expressions)
    id = UP4_R2_IDENTITY
    source_expressions.schema == "up4-r2-native-mms-source-expressions-v1" ||
        throw(ArgumentError("thermal slab expression schema mismatch"))
    source_expressions.status == "candidate_design_projection_only" &&
        source_expressions.design_scope == "candidate_design_only" &&
        source_expressions.compiler_rebuild_required === true ||
        throw(ArgumentError("thermal slab expression scope mismatch"))
    source_expressions.candidate_id == id.candidate_id &&
        source_expressions.candidate_ref == id.candidate_ref.id &&
        source_expressions.scenario_id == id.scenario_id &&
        source_expressions.scenario_ref == id.scenario_ref.id ||
        throw(ArgumentError("thermal slab G1 identity mismatch"))
    source_expressions.formula == "steady_planar_quadratic_diffusion_v1" &&
        source_expressions.unknown_source_expression == "u_candidate_steady_planar_quadratic_diffusion_v1" &&
        source_expressions.source_expression == "f(x)=1" ||
        throw(ArgumentError("thermal slab G1 expression contract mismatch"))

    candidate = id.candidate_ref
    source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G1/source/thermal-slab-up4-v5-20261003-wrong-f-expression", "v1")
    zero = UnitSignature()
    temperature = UnitSignature((0, 0, 0, 0, 1, 0, 0))
    gradient = UnitSignature((-1, 0, 0, 0, 1, 0, 0))
    conductivity = UnitSignature((1, 1, -3, 0, -1, 0, 0))
    source = UnitSignature((-1, 1, -3, 0, 0, 0, 0))
    static = TemporalTypeV1(static_time)
    u_type = PhysicalType(:scalar_field, 0, 3, static, temperature)
    grad_type = PhysicalType(:vector_field, 1, 3, static, gradient)
    k_type = PhysicalType(:tensor_field, 2, 3, static, conductivity)
    flux = UnitSignature((0, 1, -3, 0, 0, 0, 0))
    flux_type = PhysicalType(:vector_field, 1, 3, static, flux)
    f_type = PhysicalType(:scalar_field, 0, 3, static, source)
    u = G1DiffusionScalarFieldV1("temperature", u_type, source_ref;
        source_expression=source_expressions.unknown_source_expression)
    f = G1DiffusionScalarFieldV1("heat_source", f_type, source_ref;
        source_expression=source_expressions.source_expression)
    kexpr = G1DiffusionDiagonalAffineKFieldV1("thermal_slab_diagonal_affine_heldout_k3_v1";
        domain_min=(0//1, 0//1, 0//1), domain_max=(2//1, 1//1, 1//1),
        base_diag=(3//1, 3//1, 4//1), slope_diag=(0//1, 1//10, 0//1))
    enclosure = g1_diffusion_k_enclosure(kexpr)
    K = G1DiffusionCoefficientFieldV1("conductivity", k_type, source_ref;
        lower_bound=enclosure.lower, upper_bound=enclosure.upper, expression=kexpr)
    grad = G1TypedGradV1(QualifiedRefV1(G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"),
        u.field_id, "grad_temperature", u_type, grad_type)
    k_apply = G1TypedKApplyV1(QualifiedRefV1(G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1"),
        grad.output_field_id, "conductive_flux", grad_type, flux_type, K.field_id;
        coefficient_units=K.physical_type.units)
    div = G1TypedDivV1(QualifiedRefV1(G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1"),
        k_apply.output_field_id, f.field_id, flux_type, f_type)
    operators = G1DiffusionOperatorChainV1(grad, k_apply, div, f.field_id; residual_sign=-1)
    binding = G1DiffusionUnknownStateBindingV1(0, :unknown, u.field_id, u.physical_type)
    support = G1DiffusionOperatorTemporalSupportV1(
        G1DiffusionOperatorTemporalWhitelistV1(grad.operator_ref, (static_time,)),
        G1DiffusionOperatorTemporalWhitelistV1(k_apply.operator_ref, (static_time,)),
        G1DiffusionOperatorTemporalWhitelistV1(div.operator_ref, (static_time,)))
    payload = G1DiffusionSourcePayloadV1(candidate, source_ref, "thermal-slab-source-v1",
        u, K, f; unknown_state_binding=binding, operator_temporal_support=support)
    declaration = g1_diffusion_declaration_v1(candidate, source_ref,
        "thermal-slab-source-v1", g1_diffusion_source_hash_v1(payload), u, K, f,
        operators, QualifiedRefV1(G1_DIFFUSION_CLOSURE_ID_V1, G1_DIFFUSION_PROFILE_VERSION_V1),
        QualifiedRefV1(G1_DIFFUSION_APPLICABILITY_ID_V1, G1_DIFFUSION_PROFILE_VERSION_V1),
        "candidate-only steady SI thermal slab; typed source evaluation is not physical validation",
        (); ownership=:candidate_owned, source_payload=payload)
    (candidate_id=id.candidate_id, scenario_id=id.scenario_id,
     candidate_ref=candidate, source_ref=source_ref, source_payload=payload,
     declaration=declaration, admission=g1_diffusion_admit_v1(declaration),
     physical_resolution=:unknown)
end
