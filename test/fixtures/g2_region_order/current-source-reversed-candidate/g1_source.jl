# Target: G1SourceAuthorityFactoryV1 -> T0 -> V1/V2 -> T1 V2 -> V3.
# Next gate: 240s / 2 GiB local software source admission only; this is not solver input evidence.
# This builder consumes only the frozen candidate-design projection record; it does not load
# RuntimeV4 or certify that record. The consumer must verify its pins and reconstruct the exact
# bundle with the frozen native compiler/profile before any native compilation or Gridap work.
function up4_r2_build_g1_design(source_expressions)
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
    (source_expressions.profile_source_length_axis isa Integer &&
        !(source_expressions.profile_source_length_axis isa Bool) &&
        source_expressions.profile_source_length_axis == 1) ||
        throw(ArgumentError("native MMS profile source length axis mismatch"))
    (source_expressions.profile_target_length_axis isa Integer &&
        !(source_expressions.profile_target_length_axis isa Bool) &&
        source_expressions.profile_target_length_axis == 2) ||
        throw(ArgumentError("native MMS profile target length axis mismatch"))
    unknown_source_expression = source_expressions.unknown_source_expression
    source_expression = source_expressions.source_expression
    (unknown_source_expression isa AbstractString && !isempty(unknown_source_expression)) ||
        throw(ArgumentError("native MMS unknown expression is missing"))
    (source_expression isa AbstractString && !isempty(source_expression)) ||
        throw(ArgumentError("native MMS source expression is missing"))
    for pin in (:profile_source_basis, :profile_target_basis, :profile_hash,
            :registry_hash, :bundle_hash, :bundle_canonical_sha256,
            :compiler_sha256, :producer_input_snapshot_id, :producer_input_manifest_sha256,
            :unknown_source_expression_sha256, :source_expression_sha256)
        hasproperty(source_expressions, pin) ||
            throw(ArgumentError("native MMS provenance pin missing: " * String(pin)))
        value = getproperty(source_expressions, pin)
        (value isa AbstractString && !isempty(value)) ||
            throw(ArgumentError("native MMS provenance pin empty: " * String(pin)))
    end

    identity = UP4_R2_IDENTITY
    candidate = identity.candidate_ref
    source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G1/source/local-authored-up4-g123-20260928-r2", "v1")
    source_version = "native-g1g2-mms-v1"
    physical_lower = (1//2, 1//3, 1//4)
    physical_upper = (5//2, 10//3, 17//4)
    k_base = (2//1, 3//1, 4//1)
    k_slope = (1//10, 1//20, 1//30)

    u_unit = UnitSignature()
    k_unit = UnitSignature()
    grad_unit = UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    f_unit = UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    static = TemporalTypeV1(static_time)
    u_type = PhysicalType(:scalar_field, 0, 3, static, u_unit)
    grad_type = PhysicalType(:vector_field, 1, 3, static, grad_unit)
    k_type = PhysicalType(:tensor_field, 2, 3, static, k_unit)
    f_type = PhysicalType(:scalar_field, 0, 3, static, f_unit)

    u = G1DiffusionScalarFieldV1("u", u_type, source_ref;
        source_expression=unknown_source_expression)
    f = G1DiffusionScalarFieldV1("f", f_type, source_ref;
        source_expression=source_expression)
    k_expression = G1DiffusionDiagonalAffineKFieldV1("K_diag_affine_local_v1";
        domain_min=physical_lower, domain_max=physical_upper,
        base_diag=k_base, slope_diag=k_slope)
    k = G1DiffusionCoefficientFieldV1("K_diag", k_type, source_ref;
        lower_bound=41//20, upper_bound=497//120, expression=k_expression)

    grad = G1TypedGradV1(QualifiedRefV1(G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"),
        u.field_id, "grad_u", u_type, grad_type)
    k_apply = G1TypedKApplyV1(QualifiedRefV1(G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1"),
        "grad_u", "flux_K_grad_u", grad_type, grad_type, k.field_id; coefficient_units=k_unit)
    div = G1TypedDivV1(QualifiedRefV1(G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1"),
        "flux_K_grad_u", f.field_id, grad_type, f_type)
    operators = G1DiffusionOperatorChainV1(grad, k_apply, div, f.field_id; residual_sign=-1)
    unknown_state_binding = G1DiffusionUnknownStateBindingV1(0, :unknown, u.field_id, u.physical_type)
    operator_temporal_support = G1DiffusionOperatorTemporalSupportV1(
        G1DiffusionOperatorTemporalWhitelistV1(grad.operator_ref, (static_time,)),
        G1DiffusionOperatorTemporalWhitelistV1(k_apply.operator_ref, (static_time,)),
        G1DiffusionOperatorTemporalWhitelistV1(div.operator_ref, (static_time,)))
    # Independent candidate-authored interface flux ports. These do not read
    # or derive from the G2 normal; T1 later checks them against the pinned G2
    # region geometry. The pair law is manufactured contract data only.
    interface_flux_pair = G1DiffusionInterfaceFluxPairV1(
        QualifiedRefV1("fusionconceptai://GenomeV5/G2/interface/local-authored-up4-g123-20260928-r2/x-half", "v2"),
        "local_unit_cube_left", "local_unit_cube_right",
        "left_outward_flux_K_grad_u", "right_outward_flux_K_grad_u",
        k_apply.operator_ref, k_apply.output_field_id,
        (1,0,0), (-1,0,0), 1, -1,
        :left_outward_flux_plus_right_outward_flux_equals_zero)
    payload = G1DiffusionSourcePayloadV1(candidate, source_ref, source_version, u, k, f;
        unknown_state_binding=unknown_state_binding,
        operator_temporal_support=operator_temporal_support,
        interface_flux_pair=interface_flux_pair)
    declaration = g1_diffusion_declaration_v1(candidate, source_ref, source_version,
        g1_diffusion_source_hash_v1(payload), u, k, f, operators,
        QualifiedRefV1(G1_DIFFUSION_CLOSURE_ID_V1, G1_DIFFUSION_PROFILE_VERSION_V1),
        QualifiedRefV1(G1_DIFFUSION_APPLICABILITY_ID_V1, G1_DIFFUSION_PROFILE_VERSION_V1),
        "locally authored native MMS candidate payload; compiler validation required; no provider or physical evidence", (); ownership=:candidate_owned,
        source_payload=payload)
    return (candidate_id=identity.candidate_id, scenario_id=identity.scenario_id,
        candidate_ref=candidate, source_ref=source_ref, source_payload=payload,
        declaration=declaration, admission=g1_diffusion_admit_v1(declaration),
        physical_resolution=:unknown)
end

"""Build an explicit source-authored G1 MechanismGenomeV5 for the R2 diffusion design.

This is a new V5 design projection from the checked R2 source-expression record,
not a V1-to-V5 migration. The original `up4_r2_build_g1_design` and its V1
T0 declaration remain the legacy transport input.
"""
function up4_r2_build_g1_v5_design(source_expressions)
    source = up4_r2_build_g1_design(source_expressions)
    declaration = source.declaration
    # The old source declaration intentionally remains deferred because no
    # external provider was invoked. This new source-authored V5 design may be
    # structurally built from its checked candidate source without upgrading
    # that V1 authority status.
    source.admission.status === :terminal_deferred &&
        source.admission.declaration === declaration ||
        throw(ArgumentError("R2 G1 V1 source declaration is not the expected deferred design"))
    for (expression, pin) in ((source_expressions.unknown_source_expression,
                               source_expressions.unknown_source_expression_sha256),
                              (source_expressions.source_expression,
                               source_expressions.source_expression_sha256))
        actual = Digest256(bytes2hex(SHA.sha256(codeunits(String(expression)))))
        actual == Digest256(String(pin)) ||
            throw(ArgumentError("R2 G1 V5 source-expression byte hash mismatch"))
    end
    u, k, f = declaration.u, declaration.K, declaration.f
    grad, k_apply, div = declaration.operators.grad,
        declaration.operators.coefficient_apply, declaration.operators.div
    candidate = source.candidate_ref

    # These V2 operator refs and equations are authored here as explicit
    # residual laws. They do not relabel V1 operator refs or claim migration.
    operator_root = "fusionconceptai://GenomeV5/G1/r2/typed-diffusion"
    gradient_residual_ref = QualifiedRefV1(operator_root * "/GRADIENT_CONSTRAINT_RESIDUAL", "v2")
    constitutive_residual_ref = QualifiedRefV1(operator_root * "/FLUX_CONSTITUTIVE_RESIDUAL", "v2")
    coefficient_profile_residual_ref = QualifiedRefV1(operator_root * "/AFFINE_K_PROFILE_RESIDUAL", "v2")
    source_contribution_ref = QualifiedRefV1(operator_root * "/NEGATIVE_SOURCE_CONTRIBUTION", "v2")
    governing_residual_ref = QualifiedRefV1(operator_root * "/NEG_DIV_MINUS_SOURCE_RESIDUAL", "v2")
    grad_type = grad.output_type
    flux_type = k_apply.output_type
    residual_type = f.physical_type
    all(x -> x isa PhysicalType,
        (u.physical_type, k.physical_type, f.physical_type,
         grad_type, flux_type, residual_type)) ||
        throw(ArgumentError("R2 G1 design lacks typed physical endpoints"))
    grad_type.units == flux_type.units && k.physical_type.units == UnitSignature() ||
        throw(ArgumentError("R2 diffusion flux-chain units do not close"))
    grad.input_type == u.physical_type &&
        k_apply.input_type == grad_type &&
        k_apply.coefficient_field_id == k.field_id &&
        div.input_type == flux_type && div.output_type == residual_type &&
        declaration.operators.residual_sign == -1 ||
        throw(ArgumentError("R2 source GRAD/K_APPLY/DIV endpoints are not the authored chain"))
    String(source_expressions.source_sign) == "minus_div_k_grad" &&
        String(source_expressions.boundary_semantics) == "all_six_faces_zero_dirichlet" ||
        throw(ArgumentError("R2 governing equation or boundary source differs"))

    axes = G1VersionAxesV2(
        QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        QualifiedRefV1("fusion.g1.applicability", "v2"),
        QualifiedRefV1("fusion.g1.receipt", "v2"))
    profile_ref = QualifiedRefV1(operator_root * "/profile", "v2")
    canonicalization_ref = QualifiedRefV1("fusion.g1.canonicalization", "v2")
    applicability_ref = QualifiedRefV1("fusion.g1.applicability", "v2")
    temporal = (static_time,)
    gradient_law_ref = grad.operator_ref
    k_apply_law_ref = k_apply.operator_ref
    div_law_ref = div.operator_ref
    no_effect = (:none,)
    grad_operator = G1OperatorSpecV2(gradient_residual_ref, 2, 1, (:constraint,),
        (grad_type.units, u.physical_type.units), (grad_type.units,), temporal, 0,
        no_effect; input_ranks=(grad_type.tensor_rank, u.physical_type.tensor_rank),
        output_ranks=(grad_type.tensor_rank,), provider_match=:no_match)
    k_apply_operator = G1OperatorSpecV2(constitutive_residual_ref, 3, 1, (:constraint,),
        (flux_type.units, grad_type.units, k.physical_type.units), (flux_type.units,), temporal, 0,
        no_effect; input_ranks=(flux_type.tensor_rank, grad_type.tensor_rank, k.physical_type.tensor_rank),
        output_ranks=(flux_type.tensor_rank,), provider_match=:no_match)
    k_profile_operator = G1OperatorSpecV2(coefficient_profile_residual_ref, 1, 1, (:constraint,),
        (k.physical_type.units,), (k.physical_type.units,), temporal, 0,
        no_effect; input_ranks=(k.physical_type.tensor_rank,),
        output_ranks=(k.physical_type.tensor_rank,), provider_match=:no_match)
    source_contribution_operator = G1OperatorSpecV2(source_contribution_ref, 1, 1, (:additive,),
        (f.physical_type.units,), (f.physical_type.units,), temporal, 0,
        no_effect; input_ranks=(f.physical_type.tensor_rank,),
        output_ranks=(f.physical_type.tensor_rank,), provider_match=:no_match)
    governing_operator = G1OperatorSpecV2(governing_residual_ref, 2, 1, (:governing,),
        (flux_type.units, f.physical_type.units), (residual_type.units,), temporal, 0,
        no_effect; input_ranks=(flux_type.tensor_rank, f.physical_type.tensor_rank),
        output_ranks=(residual_type.tensor_rank,), provider_match=:no_match)
    # These are typed dataflow-incidence balances only. They do not assert
    # conservation, integrated boundary balance, or physical closure.
    gradient_closure_id = "r2-gradient-residual-dataflow-incidence-only"
    constitutive_closure_id = "r2-constitutive-residual-dataflow-incidence-only"
    profile_closure_id = "r2-affine-K-profile-dataflow-incidence-only"
    source_closure_id = "r2-negative-source-dataflow-incidence-only"
    governing_closure_id = "r2-governing-residual-dataflow-incidence-only"
    gradient_ledger = "r2-gradient-residual-incidence-not-conservation"
    constitutive_ledger = "r2-constitutive-residual-incidence-not-conservation"
    profile_ledger = "r2-affine-K-residual-incidence-not-conservation"
    source_ledger = "r2-negative-source-incidence-not-conservation"
    governing_ledger = "r2-governing-residual-incidence-not-conservation"
    gradient_closure = G1ClosureRuleV2(gradient_closure_id, gradient_ledger,
        grad_type.units, ("r2-grad-constraint",), 0 // 1)
    constitutive_closure = G1ClosureRuleV2(constitutive_closure_id, constitutive_ledger,
        flux_type.units, ("r2-flux-constitutive-constraint",), 0 // 1)
    profile_closure = G1ClosureRuleV2(profile_closure_id, profile_ledger,
        k.physical_type.units, ("r2-k-affine-profile-constraint",), 0 // 1)
    source_closure = G1ClosureRuleV2(source_closure_id, source_ledger,
        f.physical_type.units, ("r2-negative-source-additive",), 0 // 1)
    governing_closure = G1ClosureRuleV2(governing_closure_id, governing_ledger,
        residual_type.units, ("r2-diffusion-governing",), 0 // 1)
    profile = GrammarProfileV2(profile_ref, canonicalization_ref,
        applicability_ref, (grad_operator, k_apply_operator, k_profile_operator,
            source_contribution_operator, governing_operator),
        (gradient_closure, constitutive_closure, profile_closure, source_closure, governing_closure);
        max_states=10, max_equations=5, max_ast_nodes=24)

    grad_state = G1StateV2("grad_u", grad_type; derivative_order=0)
    flux_state = G1StateV2(k_apply.output_field_id, flux_type; derivative_order=0)
    gradient_residual_state = G1StateV2("r2_gradient_residual", grad_type; derivative_order=0)
    constitutive_residual_state = G1StateV2("r2_flux_constitutive_residual", flux_type; derivative_order=0)
    profile_residual_state = G1StateV2("r2_k_affine_profile_residual", k.physical_type; derivative_order=0)
    source_contribution_state = G1StateV2("r2_negative_source_contribution", f.physical_type; derivative_order=0)
    governing_residual_state = G1StateV2("r2_diffusion_governing_residual", residual_type; derivative_order=0)
    states = (G1StateV2(u.field_id, u.physical_type; derivative_order=0),
        G1StateV2(k.field_id, k.physical_type; derivative_order=0),
        G1StateV2(f.field_id, f.physical_type; derivative_order=0),
        grad_state, flux_state, gradient_residual_state, constitutive_residual_state,
        profile_residual_state, source_contribution_state, governing_residual_state)

    grad_expr = G1TypedExpressionV2((
        G1StateInputV2(grad_state.state_id, grad_type),
        G1StateInputV2(u.field_id, u.physical_type),
        G1OperatorApplyV2(gradient_residual_ref, (1, 2), grad_type; parameters=(
            law="g - GRAD(u) = 0",
            operator_law=(kind=:subtract, left_state_ref=grad_state.state_id,
                right_operator_ref=gradient_law_ref, right_input_refs=(u.field_id,), zero_target=0 // 1),
            residual_definition="g - GRAD(u)",
            source_operator_ref=gradient_law_ref,
            unknown_source_expression=String(source_expressions.unknown_source_expression),
            physical_coordinates=true,
            boundary_semantics=String(source_expressions.boundary_semantics))),
    ), 3)
    grad_eq = G1EquationV2("r2-grad-constraint", :constraint, gradient_residual_ref,
        (grad_state.state_id, u.field_id), (gradient_residual_state.state_id,),
        (grad_type.units, u.physical_type.units), (grad_type.units,),
        static_time, 0, no_effect,
        (G1LedgerOccurrenceV2("r2-grad-constraint", :input, 1, 1 // 1,
            gradient_ledger, grad_type.units, :none),
         G1LedgerOccurrenceV2("r2-grad-constraint", :output, 1, -1 // 1,
            gradient_ledger, grad_type.units, :none)), gradient_closure_id, grad_expr;
        input_ranks=(grad_type.tensor_rank, u.physical_type.tensor_rank),
        output_ranks=(grad_type.tensor_rank,))

    constitutive_expr = G1TypedExpressionV2((
        G1StateInputV2(flux_state.state_id, flux_type),
        G1StateInputV2(grad_state.state_id, grad_type),
        G1StateInputV2(k.field_id, k.physical_type),
        G1OperatorApplyV2(constitutive_residual_ref, (1, 2, 3), flux_type; parameters=(
            law="q - K_APPLY(g, K) = 0",
            operator_law=(kind=:subtract, left_state_ref=flux_state.state_id,
                right_operator_ref=k_apply_law_ref,
                right_input_refs=(grad_state.state_id, k.field_id), zero_target=0 // 1),
            residual_definition="q - K_APPLY(g, K)",
            source_operator_ref=k_apply_law_ref,
            coefficient_field_id=k.field_id,
            coefficient_units=k_apply.coefficient_units,
            coefficient_base=k.expression.base_diag,
            coefficient_slope=k.expression.slope_diag,
            coefficient_domain_min=k.expression.domain_min,
            coefficient_domain_max=k.expression.domain_max)),
    ), 4)
    constitutive_eq = G1EquationV2("r2-flux-constitutive-constraint", :constraint,
        constitutive_residual_ref,
        (flux_state.state_id, grad_state.state_id, k.field_id),
        (constitutive_residual_state.state_id,),
        (flux_type.units, grad_type.units, k.physical_type.units), (flux_type.units,),
        static_time, 0, no_effect,
        (G1LedgerOccurrenceV2("r2-flux-constitutive-constraint", :input, 1, 1 // 1,
            constitutive_ledger, flux_type.units, :none),
         G1LedgerOccurrenceV2("r2-flux-constitutive-constraint", :output, 1, -1 // 1,
            constitutive_ledger, flux_type.units, :none)), constitutive_closure_id, constitutive_expr;
        input_ranks=(flux_type.tensor_rank, grad_type.tensor_rank, k.physical_type.tensor_rank),
        output_ranks=(flux_type.tensor_rank,))

    profile_expr = G1TypedExpressionV2((
        G1StateInputV2(k.field_id, k.physical_type),
        G1OperatorApplyV2(coefficient_profile_residual_ref, (1,), k.physical_type; parameters=(
            law="K_diag - diag(k_base[i] + k_slope[i] * x_i) = 0",
            operator_law=(kind=:affine_diagonal_addition, coefficient_field_ref=k.field_id,
                coordinate_basis="physical_cartesian_metres", zero_target=0 // 1),
            residual_definition="K_diag - diag(k_base[i] + k_slope[i] * x_i)",
            coefficient_field_id=k.field_id,
            coefficient_units=k.physical_type.units,
            coefficient_base=k.expression.base_diag,
            coefficient_slope=k.expression.slope_diag,
            coefficient_domain_min=k.expression.domain_min,
            coefficient_domain_max=k.expression.domain_max,
            coordinate_basis="physical_cartesian_metres",
            source_formula=String(source_expressions.formula))),
    ), 2)
    profile_eq = G1EquationV2("r2-k-affine-profile-constraint", :constraint,
        coefficient_profile_residual_ref, (k.field_id,),
        (profile_residual_state.state_id,), (k.physical_type.units,), (k.physical_type.units,),
        static_time, 0, no_effect,
        (G1LedgerOccurrenceV2("r2-k-affine-profile-constraint", :input, 1, 1 // 1,
            profile_ledger, k.physical_type.units, :none),
         G1LedgerOccurrenceV2("r2-k-affine-profile-constraint", :output, 1, -1 // 1,
            profile_ledger, k.physical_type.units, :none)), profile_closure_id, profile_expr;
        input_ranks=(k.physical_type.tensor_rank,), output_ranks=(k.physical_type.tensor_rank,))

    source_expr = G1TypedExpressionV2((
        G1StateInputV2(f.field_id, f.physical_type),
        G1OperatorApplyV2(source_contribution_ref, (1,), f.physical_type; parameters=(
            law="s = -f",
            operator_law=(kind=:negate_source, source_state_ref=f.field_id, sign=-1),
            residual_definition="-f",
            source_expression=String(source_expressions.source_expression))),
    ), 2)
    source_eq = G1EquationV2("r2-negative-source-additive", :additive,
        source_contribution_ref, (f.field_id,), (source_contribution_state.state_id,),
        (f.physical_type.units,), (f.physical_type.units,), static_time, 0, no_effect,
        (G1LedgerOccurrenceV2("r2-negative-source-additive", :input, 1, 1 // 1,
            source_ledger, f.physical_type.units, :none),
         G1LedgerOccurrenceV2("r2-negative-source-additive", :output, 1, -1 // 1,
            source_ledger, f.physical_type.units, :none)), source_closure_id, source_expr;
        input_ranks=(f.physical_type.tensor_rank,), output_ranks=(f.physical_type.tensor_rank,))

    governing_expr = G1TypedExpressionV2((
        G1StateInputV2(flux_state.state_id, flux_type),
        G1StateInputV2(source_contribution_state.state_id, f.physical_type),
        G1OperatorApplyV2(governing_residual_ref, (1, 2), residual_type; parameters=(
            law="-DIV(q) + s = 0; s = -f",
            operator_law=(kind=:negated_divergence_plus_source_contribution,
                divergence_operator_ref=div_law_ref, divergence_input_ref=flux_state.state_id,
                source_contribution_state_ref=source_contribution_state.state_id,
                source_state_ref=f.field_id, zero_target=0 // 1),
            residual_definition="-DIV(q) + s",
            zero_target=0 // 1,
            source_operator_ref=div_law_ref,
            source_sign=String(source_expressions.source_sign),
            boundary_semantics=String(source_expressions.boundary_semantics),
            residual_sign=Int(declaration.operators.residual_sign))),
    ), 3)
    governing_eq = G1EquationV2("r2-diffusion-governing", :governing,
        governing_residual_ref, (flux_state.state_id, source_contribution_state.state_id),
        (governing_residual_state.state_id,),
        (flux_type.units, f.physical_type.units), (residual_type.units,),
        static_time, 0, no_effect,
        (G1LedgerOccurrenceV2("r2-diffusion-governing", :input, 2, 1 // 1,
            governing_ledger, residual_type.units, :none),
         G1LedgerOccurrenceV2("r2-diffusion-governing", :output, 1, -1 // 1,
            governing_ledger, residual_type.units, :none)), governing_closure_id,
        governing_expr; input_ranks=(flux_type.tensor_rank, f.physical_type.tensor_rank),
        output_ranks=(residual_type.tensor_rank,))
    plan = G1EquationPlanV2(QualifiedRefV1(operator_root * "/equation-plan", "v2"),
        (grad_eq, constitutive_eq, profile_eq, source_eq, governing_eq))
    payload_contract = G1GenomeContractRefV2(
        "fusionconceptai://GenomeV5/G1/r2/typed-diffusion", "v5",
        g1_schema_hash(), g1_canonicalization_hash(),
        "candidate-owned-g1-v2", axes, candidate.id;
        grammar_profile_hash=g1_grammar_profile_hash(profile),
        applicability_profile_hash=g1_applicability_profile_hash(profile))
    payload = MechanismGenomePayloadV2(payload_contract, states, plan, profile)
    public_contract = g1_materialize_contract_ref(payload_contract, profile)
    genome = MechanismGenomeV5(public_contract, payload, axes)
    genome.admission.structural_status === :valid ||
        throw(ArgumentError("authored R2 G1 V5 design failed admission"))
    (source_revision="up4-r2-explicit-g1-v5-design-v1",
     migration_claim=:none, source_candidate_ref=candidate,
     source_v1_design=source, g1_v5=genome, g1_payload=payload,
     closure_semantics=:typed_dataflow_incidence_only_no_physical_conservation,
     operator_law_status=:candidate_authored_descriptor_not_executed_or_provider_validated,
     source_expression_hashes=(unknown=source_expressions.unknown_source_expression_sha256,
        manufactured=source_expressions.source_expression_sha256))
end
