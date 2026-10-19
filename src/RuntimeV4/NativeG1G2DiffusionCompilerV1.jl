"""Candidate-bound native G1/G2 variable-diffusion compiler.

This additive compiler consumes the actual native Genome V5 declarations and a
fresh V2 T1 package.  The manufactured reference and source are typed programs
whose canonical bytes are carried by the native G1 source fields.  It does not
change the default operator registry and it does not grant physical or formal
T2 acceptance.
"""

using SHA

# Native declarations and the formal T1 package live in FusionConceptAI;
# runtime capability/provider types live in the enclosing FusionRuntimeV4
# module.  These imports make the cross-module boundary explicit and prevent
# a test harness from creating a second copy of either type vocabulary.
import FusionConceptAI: G1DiffusionDeclarationV1, G2MBChartMapV1,
    G2MBDeclarationV1, CandidateStatePackageV5NextV2,
    G1_DIFFUSION_GRAD_OPERATOR_ID_V1,
    G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, G1_DIFFUSION_DIV_OPERATOR_ID_V1,
    g1_diffusion_validate, g2mb_admit, g2mb_chart_image_bounds,
    vnext_t1_package_binding_adapter_v2, copy_bytes

const NATIVE_G1G2_DIFFUSION_SCHEMA_V1 =
    "RuntimeV4/NativeG1G2DiffusionCompilerV1"
const NATIVE_G1G2_DIFFUSION_VERSION_V1 = "v1"
const NATIVE_G1G2_DIFFUSION_PROFILE_V1 =
    "native-g1g2-physical-chart-variable-diffusion-v1"
const NATIVE_G1G2_K_APPLY_OPERATOR_V1 =
    "fusionconceptai://RuntimeV4/native-g1g2/K_APPLY"
const NATIVE_G1G2_MMS_REFERENCE_OPERATOR_V1 =
    "fusionconceptai://RuntimeV4/native-g1g2/MMS_REFERENCE"
const NATIVE_G1G2_MMS_SOURCE_OPERATOR_V1 =
    "fusionconceptai://RuntimeV4/native-g1g2/MMS_SOURCE"

const _NG12_STAGE_START_NS_V1 = time_ns()

function _ng12_stage_v1(marker::AbstractString)
    runner_start = tryparse(UInt64, get(ENV, "UP1_NATIVE_RUN_START_NS", ""))
    start_ns = runner_start === nothing ? _NG12_STAGE_START_NS_V1 : runner_start
    elapsed_seconds = Float64(time_ns() - start_ns) / 1.0e9
    println("UP1_NATIVE_COMPILER_STAGE\t", round(elapsed_seconds; digits=3),
        "\t", marker)
    flush(stdout)
    nothing
end

native_g1g2_diffusion_compiler_source_hash_v1() =
    Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

_ng12_r3(x, field) = begin
    values = Tuple(x)
    length(values) == 3 || throw(ArgumentError("$field must contain three values"))
    ntuple(i -> Rational{Int64}(values[i]), 3)
end

_ng12_matrix3(x, field) = begin
    rows = Tuple(x)
    length(rows) == 3 || throw(ArgumentError("$field must be a 3x3 matrix"))
    ntuple(i -> begin
        row = Tuple(rows[i])
        length(row) == 3 || throw(ArgumentError("$field must be a 3x3 matrix"))
        ntuple(j -> begin
            value = row[j]
            ((value isa Integer && !(value isa Bool)) ||
                value isa Rational) ||
                throw(ArgumentError("$field entries must be exact rational values"))
            Rational{Int64}(value)
        end, 3)
    end, 3)
end

_ng12_unit(exponents) = UnitSignature(ntuple(i -> Rational{Int64}(exponents[i]), 7))
_ng12_zero_unit() = UnitSignature()
_ng12_native_length_unit(power=1) = _ng12_unit((power, 0, 0, 0, 0, 0, 0))
_ng12_si_length_unit(power=1) = _ng12_unit((0, power, 0, 0, 0, 0, 0))

struct NativeG1G2UnitCompatibilityProfileV1
    source_basis::String
    target_basis::String
    source_length_axis::Int
    target_length_axis::Int
    length_scale_metres::Rational{Int64}
    source_allowed_nonzero_axes::Tuple{Vararg{Int}}
    target_allowed_nonzero_axes::Tuple{Vararg{Int}}
    coordinate_semantics::Symbol
    profile_hash::Digest256
end

function _ng12_unit_profile_body(source_basis, target_basis, source_length_axis,
        target_length_axis, length_scale_metres, source_allowed_nonzero_axes,
        target_allowed_nonzero_axes, coordinate_semantics)
    (domain="native-g1g2-unit-compatibility-v1",
        source_basis=source_basis, target_basis=target_basis,
        source_length_axis=source_length_axis,
        target_length_axis=target_length_axis,
        length_scale_metres=length_scale_metres,
        source_allowed_nonzero_axes=source_allowed_nonzero_axes,
        target_allowed_nonzero_axes=target_allowed_nonzero_axes,
        coordinate_semantics=coordinate_semantics)
end

function native_g1g2_unit_compatibility_profile_v1(;
        source_basis="GenomeV5/native-length-first-partial-basis-v1",
        target_basis="RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1",
        source_length_axis::Integer=1, target_length_axis::Integer=2,
        length_scale_metres=1 // 1,
        source_allowed_nonzero_axes=(1,), target_allowed_nonzero_axes=(2,),
        coordinate_semantics::Symbol=:physical_cartesian_metres)
    sa = Tuple(Int(i) for i in source_allowed_nonzero_axes)
    ta = Tuple(Int(i) for i in target_allowed_nonzero_axes)
    source_basis == "GenomeV5/native-length-first-partial-basis-v1" ||
        throw(ArgumentError("limited v1 requires the native length-first basis"))
    target_basis == "RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1" ||
        throw(ArgumentError("limited v1 requires the RuntimeV4 SI basis"))
    source_length_axis == 1 ||
        throw(ArgumentError("native G1/G2 length axis must be explicitly axis 1"))
    target_length_axis == 2 ||
        throw(ArgumentError("RuntimeV4 SI length axis must be explicitly axis 2"))
    sa == (1,) && ta == (2,) ||
        throw(ArgumentError("only the justified length-axis translation is supported"))
    scale = Rational{Int64}(length_scale_metres)
    scale > 0 || throw(ArgumentError("length scale must be positive"))
    scale == 1 // 1 || throw(ArgumentError(
        "limited v1 supports only a one-metre native length scale"))
    coordinate_semantics === :physical_cartesian_metres ||
        throw(ArgumentError("only explicit physical Cartesian coordinates are supported"))
    body = _ng12_unit_profile_body(String(source_basis), String(target_basis),
        1, 2, scale, sa, ta, coordinate_semantics)
    NativeG1G2UnitCompatibilityProfileV1(body.source_basis,
        body.target_basis, body.source_length_axis, body.target_length_axis,
        body.length_scale_metres, body.source_allowed_nonzero_axes,
        body.target_allowed_nonzero_axes, body.coordinate_semantics,
        canonical_hash(body))
end

semantic_view(x::NativeG1G2UnitCompatibilityProfileV1) = merge(
    _ng12_unit_profile_body(x.source_basis, x.target_basis,
        x.source_length_axis, x.target_length_axis, x.length_scale_metres,
        x.source_allowed_nonzero_axes, x.target_allowed_nonzero_axes,
        x.coordinate_semantics), (profile_hash=x.profile_hash,))
canonical_hash(x::NativeG1G2UnitCompatibilityProfileV1) = x.profile_hash

function _ng12_unit_profile_integrity(x::NativeG1G2UnitCompatibilityProfileV1)
    x.source_basis == "GenomeV5/native-length-first-partial-basis-v1" &&
    x.target_basis == "RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1" &&
    x.source_length_axis == 1 && x.target_length_axis == 2 &&
    x.source_allowed_nonzero_axes == (1,) &&
    x.target_allowed_nonzero_axes == (2,) &&
    x.length_scale_metres == 1 // 1 &&
    x.coordinate_semantics === :physical_cartesian_metres &&
    canonical_hash(_ng12_unit_profile_body(x.source_basis, x.target_basis,
        x.source_length_axis, x.target_length_axis, x.length_scale_metres,
        x.source_allowed_nonzero_axes, x.target_allowed_nonzero_axes,
        x.coordinate_semantics)) == x.profile_hash
end

function native_g1g2_translate_unit_v1(
        profile::NativeG1G2UnitCompatibilityProfileV1, unit::UnitSignature)
    _ng12_unit_profile_integrity(profile) ||
        throw(ArgumentError("unit compatibility profile integrity mismatch"))
    all(iszero(unit.exponents[i]) for i in 1:7 if i != profile.source_length_axis) ||
        throw(ArgumentError("native unit uses an undocumented non-length axis"))
    exponent = unit.exponents[profile.source_length_axis]
    zero_exponent = Rational{Int64}(0)
    UnitSignature(ntuple(i -> i == profile.target_length_axis ? exponent : zero_exponent, 7))
end

function native_g1g2_operator_registry_v1()
    registry = default_operator_registry()
    static = TemporalTypeV1(static_time)
    k_type = PhysicalType(:tensor_field, 2, 3, static, _ng12_zero_unit())
    grad_type = PhysicalType(:vector_field, 1, 3, static,
        _ng12_si_length_unit(-1))
    coordinate_type = PhysicalType(:scalar_field, 0, 3, static,
        _ng12_si_length_unit(1))
    value_type = PhysicalType(:scalar_field, 0, 3, static,
        _ng12_zero_unit())
    source_type = PhysicalType(:scalar_field, 0, 3, static,
        _ng12_si_length_unit(-2))
    k_apply = OperatorManifestV1(
        OperatorRefV1(NATIVE_G1G2_K_APPLY_OPERATOR_V1, "v1"), 2, 1,
        ExactTypeRuleV1((k_type, grad_type), (grad_type,)),
        ExactTypeRuleV1((k_type, grad_type), (grad_type,));
        allowed_roles=(:governing,), locality=:local,
        allowed_conservation_effects=(:redistribution,))
    reference = OperatorManifestV1(
        OperatorRefV1(NATIVE_G1G2_MMS_REFERENCE_OPERATOR_V1, "v1"), 3, 1,
        ExactTypeRuleV1((coordinate_type, coordinate_type, coordinate_type),
            (value_type,)),
        ExactTypeRuleV1((coordinate_type, coordinate_type, coordinate_type),
            (value_type,)); allowed_roles=(:state,), locality=:local)
    source = OperatorManifestV1(
        OperatorRefV1(NATIVE_G1G2_MMS_SOURCE_OPERATOR_V1, "v1"), 3, 1,
        ExactTypeRuleV1((coordinate_type, coordinate_type, coordinate_type),
            (source_type,)),
        ExactTypeRuleV1((coordinate_type, coordinate_type, coordinate_type),
            (source_type,)); allowed_roles=(:source,), locality=:local)
    register_operator(register_operator(register_operator(registry, k_apply),
        reference), source)
end

struct NativeG1G2ProgramBundleV1
    registry::OperatorRegistryV1
    unknown_program::TypedASTProgramV1
    reference_program::TypedASTProgramV1
    source_program::TypedASTProgramV1
    residual_program::TypedASTProgramV1
    parameters::NamedTuple
    unit_profile_hash::Digest256
    unknown_source_expression::String
    source_expression::String
    registry_hash::Digest256
    bundle_hash::Digest256
end

function _ng12_unknown_expression_body(unknown_program, reference_program,
        parameters, unit_profile_hash)
    (schema="native-g1g2-state-source-expression-v1",
        role=:unknown_with_manufactured_reference,
        coordinate_basis=:physical_cartesian,
        unknown_program=unknown_program,
        manufactured_reference_program=reference_program,
        parameters=parameters, unit_profile_hash=unit_profile_hash)
end

function _ng12_source_expression_body(source_program, parameters,
        unit_profile_hash)
    (schema="native-g1g2-manufactured-source-expression-v1",
        role=:manufactured_source,
        strong_equation=:minus_div_k_grad_equals_f,
        coordinate_basis=:physical_cartesian,
        source_program=source_program, parameters=parameters,
        unit_profile_hash=unit_profile_hash)
end

function _ng12_program_bundle_body(registry, unknown_program,
        reference_program, source_program, residual_program, parameters,
        unit_profile_hash, unknown_source_expression, source_expression,
        registry_hash)
    (domain="native-g1g2-program-bundle-v1", registry=registry,
        unknown_program=unknown_program, reference_program=reference_program,
        source_program=source_program, residual_program=residual_program,
        parameters=parameters, unit_profile_hash=unit_profile_hash,
        unknown_source_expression=unknown_source_expression,
        source_expression=source_expression, registry_hash=registry_hash)
end

semantic_view(x::NativeG1G2ProgramBundleV1) = merge(
    _ng12_program_bundle_body(x.registry, x.unknown_program,
        x.reference_program, x.source_program, x.residual_program,
        x.parameters, x.unit_profile_hash, x.unknown_source_expression,
        x.source_expression, x.registry_hash), (bundle_hash=x.bundle_hash,))
canonical_hash(x::NativeG1G2ProgramBundleV1) = x.bundle_hash

function native_g1g2_program_bundle_v1(
        profile::NativeG1G2UnitCompatibilityProfileV1;
        physical_lower=(1 // 2, 1 // 3, 1 // 4),
        physical_upper=(5 // 2, 10 // 3, 17 // 4),
        k_base=(2 // 1, 3 // 1, 4 // 1),
        k_slope=(1 // 10, 1 // 20, 1 // 30),
        k_base_matrix=nothing, k_slope_matrices=nothing)
    _ng12_unit_profile_integrity(profile) ||
        throw(ArgumentError("unit compatibility profile integrity mismatch"))
    lo = _ng12_r3(physical_lower, "physical lower bound")
    hi = _ng12_r3(physical_upper, "physical upper bound")
    all(lo[i] < hi[i] for i in 1:3) ||
        throw(ArgumentError("physical bounds must be non-degenerate"))
    lengths = ntuple(i -> hi[i] - lo[i], 3)
    base = _ng12_r3(k_base, "K base")
    slope = _ng12_r3(k_slope, "K slope")
    matrix_mode = k_base_matrix !== nothing || k_slope_matrices !== nothing
    matrix_mode && (k_base_matrix === nothing || k_slope_matrices === nothing) &&
        throw(ArgumentError("tensor K requires base and all three slope matrices"))
    parameters = matrix_mode ? begin
        matrix = _ng12_matrix3(k_base_matrix, "K base matrix")
        slopes = Tuple(_ng12_matrix3(item, "K slope matrix")
            for item in k_slope_matrices)
        length(slopes) == 3 || throw(ArgumentError("K requires three slope matrices"))
        (formula=:tensor_bubble_product_affine_symmetric_matrix_v2,
         coordinate_basis=:physical_cartesian_metres,
         physical_lower=lo, physical_upper=hi, physical_lengths=lengths,
         k_base=ntuple(i -> matrix[i][i], 3),
         k_slope=ntuple(i -> slopes[i][i][i], 3),
         k_base_matrix=matrix, k_slope_matrices=slopes,
         boundary_semantics=:all_six_faces_zero_dirichlet,
         source_sign=:minus_div_k_grad,
         length_scale_metres=profile.length_scale_metres)
    end : (formula=:tensor_bubble_product_variable_diagonal_affine_v1,
        coordinate_basis=:physical_cartesian_metres,
        physical_lower=lo, physical_upper=hi, physical_lengths=lengths,
        k_base=base, k_slope=slope,
        boundary_semantics=:all_six_faces_zero_dirichlet,
        source_sign=:minus_div_k_grad,
        length_scale_metres=profile.length_scale_metres)

    registry = native_g1g2_operator_registry_v1()
    static = TemporalTypeV1(static_time)
    u_type = PhysicalType(:scalar_field, 0, 3, static, _ng12_zero_unit())
    k_type = PhysicalType(:tensor_field, 2, 3, static, _ng12_zero_unit())
    grad_type = PhysicalType(:vector_field, 1, 3, static,
        _ng12_si_length_unit(-1))
    f_type = PhysicalType(:scalar_field, 0, 3, static,
        _ng12_si_length_unit(-2))
    x_type = PhysicalType(:scalar_field, 0, 3, static,
        _ng12_si_length_unit(1))

    unknown = TypedASTProgramV1((ASTInputV1(1, u_type,
        (role=:unknown_state, coordinate_basis=:physical_cartesian)),),
        (1,), (1,); registry=registry)
    coordinate_nodes = ntuple(i -> ASTInputV1(i, x_type,
        (coordinate=Symbol("x", i), coordinate_basis=:physical_cartesian)), 3)
    reference_apply = ASTApplyV1(
        OperatorRefV1(NATIVE_G1G2_MMS_REFERENCE_OPERATOR_V1, "v1"),
        (1, 2, 3), (;); registry=registry,
        input_types=(x_type, x_type, x_type))
    reference = TypedASTProgramV1((coordinate_nodes..., reference_apply),
        (4,), (1, 2, 3); registry=registry)
    source_apply = ASTApplyV1(
        OperatorRefV1(NATIVE_G1G2_MMS_SOURCE_OPERATOR_V1, "v1"),
        (1, 2, 3), (;); registry=registry,
        input_types=(x_type, x_type, x_type))
    source = TypedASTProgramV1((coordinate_nodes..., source_apply),
        (4,), (1, 2, 3); registry=registry)

    u = ASTInputV1(1, u_type, (role=:unknown_state,))
    k = ASTInputV1(2, k_type, (role=:coefficient_field,))
    f = ASTInputV1(3, f_type, (role=:source_field,))
    grad = ASTApplyV1(OperatorRefV1("GRAD", "v1"), (1,), (;);
        registry=registry, input_types=(u_type,))
    kapplied = ASTApplyV1(
        OperatorRefV1(NATIVE_G1G2_K_APPLY_OPERATOR_V1, "v1"),
        (2, 4), (;); registry=registry, input_types=(k_type, grad_type))
    div = ASTApplyV1(OperatorRefV1("DIV_OP", "v1"), (5,), (;);
        registry=registry, input_types=(grad_type,))
    neg = ASTApplyV1(OperatorRefV1("NEG", "v1"), (6,), (;);
        registry=registry, input_types=(f_type,))
    residual_root = ASTApplyV1(OperatorRefV1("SUB", "v1"), (7, 3), (;);
        registry=registry, input_types=(f_type, f_type))
    residual = TypedASTProgramV1((u, k, f, grad, kapplied, div, neg,
        residual_root), (8,), (1, 2, 3); registry=registry)

    unknown_expression = canonical_json(_ng12_unknown_expression_body(
        unknown, reference, parameters, profile.profile_hash))
    source_expression = canonical_json(_ng12_source_expression_body(
        source, parameters, profile.profile_hash))
    registry_hash = canonical_hash(registry)
    body = _ng12_program_bundle_body(registry, unknown, reference, source,
        residual, parameters, profile.profile_hash, unknown_expression,
        source_expression, registry_hash)
    NativeG1G2ProgramBundleV1(registry, unknown, reference, source,
        residual, parameters, profile.profile_hash, unknown_expression,
        source_expression, registry_hash, canonical_hash(body))
end

function _ng12_program_rebuild(program::TypedASTProgramV1,
        registry::OperatorRegistryV1)
    TypedASTProgramV1(program.nodes, program.roots, program.input_ports;
        registry=registry)
end

function _ng12_program_bundle_errors(x::NativeG1G2ProgramBundleV1,
        profile::NativeG1G2UnitCompatibilityProfileV1)
    errors = Symbol[]
    _ng12_unit_profile_integrity(profile) ||
        push!(errors, :unit_profile_integrity_mismatch)
    x.unit_profile_hash == profile.profile_hash ||
        push!(errors, :program_unit_profile_mismatch)
    x.registry_hash == canonical_hash(x.registry) ||
        push!(errors, :operator_registry_hash_mismatch)
    expected_unknown = canonical_json(_ng12_unknown_expression_body(
        x.unknown_program, x.reference_program, x.parameters,
        x.unit_profile_hash))
    expected_source = canonical_json(_ng12_source_expression_body(
        x.source_program, x.parameters, x.unit_profile_hash))
    x.unknown_source_expression == expected_unknown ||
        push!(errors, :unknown_source_expression_mismatch)
    x.source_expression == expected_source ||
        push!(errors, :source_expression_mismatch)
    body = _ng12_program_bundle_body(x.registry, x.unknown_program,
        x.reference_program, x.source_program, x.residual_program,
        x.parameters, x.unit_profile_hash, x.unknown_source_expression,
        x.source_expression, x.registry_hash)
    x.bundle_hash == canonical_hash(body) ||
        push!(errors, :program_bundle_hash_mismatch)
    for (name, program) in ((:unknown, x.unknown_program),
            (:reference, x.reference_program), (:source, x.source_program),
            (:residual, x.residual_program))
        try
            rebuilt = _ng12_program_rebuild(program, x.registry)
            canonical_hash(rebuilt) == canonical_hash(program) ||
                push!(errors, Symbol(name, :_program_rebuild_mismatch))
        catch
            push!(errors, Symbol(name, :_program_invalid))
        end
    end
    # The numerical evaluators below intentionally implement one bounded MMS
    # vocabulary rather than a general AST interpreter.  Rebuild that complete
    # vocabulary from the carried physical parameters and require exact
    # canonical equality.  This makes the executable evaluator a projection of
    # the candidate-owned typed source bytes; a different, internally valid AST
    # cannot be paired with the hard-coded evaluator by merely rehashing it.
    try
        p = x.parameters
        expected = if p.formula === :tensor_bubble_product_affine_symmetric_matrix_v2
            native_g1g2_program_bundle_v1(profile;
                physical_lower=p.physical_lower, physical_upper=p.physical_upper,
                k_base_matrix=p.k_base_matrix,
                k_slope_matrices=p.k_slope_matrices)
        else
            native_g1g2_program_bundle_v1(profile;
                physical_lower=p.physical_lower,
                physical_upper=p.physical_upper,
                k_base=p.k_base, k_slope=p.k_slope)
        end
        canonical_json(x) == canonical_json(expected) ||
            push!(errors, :program_semantic_projection_mismatch)
    catch
        push!(errors, :program_semantic_projection_invalid)
    end
    residual = x.residual_program
    if length(residual.nodes) != 8 || residual.roots != (8,) ||
            residual.input_ports != (1, 2, 3)
        push!(errors, :residual_program_shape_invalid)
    else
        ids = Tuple(node isa ASTApplyV1 ? node.operator_ref.qualified.id : ""
            for node in residual.nodes)
        ids[4:8] == ("GRAD", NATIVE_G1G2_K_APPLY_OPERATOR_V1,
            "DIV_OP", "NEG", "SUB") ||
            push!(errors, :residual_operator_chain_invalid)
        Tuple(residual.nodes[i].inputs for i in 4:8) ==
            ((1,), (2, 4), (5,), (6,), (7, 3)) ||
            push!(errors, :residual_operator_wiring_invalid)
    end
    Tuple(unique(errors))
end

function _ng12_chart_is_positive_diagonal(chart::G2MBChartMapV1)
    all(chart.jacobian_rows[i][j] == 0 for i in 1:3 for j in 1:3 if i != j) &&
    all(chart.jacobian_rows[i][i] > 0 for i in 1:3)
end

function _ng12_face_map(faces)
    Dict(face.face => face for face in faces)
end

"""Return deterministic compile-boundary errors without executing a provider."""
function native_g1g2_physics_errors_v1(g1::G1DiffusionDeclarationV1,
        g2::G2MBDeclarationV1, programs::NativeG1G2ProgramBundleV1,
        profile::NativeG1G2UnitCompatibilityProfileV1)
    errors = Symbol[]
    append!(errors, _ng12_program_bundle_errors(programs, profile))
    g1_status, _ = g1_diffusion_validate(g1)
    g1_status === :valid || push!(errors, :g1_declaration_invalid)
    g2_admission = g2mb_admit(g2.source)
    g2_admission.status in (:valid, :terminal_deferred) ||
        push!(errors, :g2_declaration_invalid)
    authored_source = try
        _g1_authored_typed_source_spec_v1(g1) !== nothing
    catch
        false
    end
    if authored_source
        # The typed AST is checked by the shared operator registry and carried
        # into the compiled form. It must not be compared with the MMS fixture.
        g1.source_payload.u.source_expression == g1.u.source_expression ||
            push!(errors, :g1_nested_unknown_reference_payload_mismatch)
        g1.source_payload.f.source_expression == g1.f.source_expression ||
            push!(errors, :g1_nested_source_payload_mismatch)
    else
        g1.u.source_expression == programs.unknown_source_expression ||
            push!(errors, :g1_unknown_reference_payload_mismatch)
        g1.f.source_expression == programs.source_expression ||
            push!(errors, :g1_source_payload_mismatch)
        g1.source_payload.u.source_expression == programs.unknown_source_expression ||
            push!(errors, :g1_nested_unknown_reference_payload_mismatch)
        g1.source_payload.f.source_expression == programs.source_expression ||
            push!(errors, :g1_nested_source_payload_mismatch)
    end

    p = programs.parameters
    expression = g1.K.expression
    if expression isa FusionConceptAI.G1DiffusionDiagonalAffineKFieldV1
        expression.base_diag == p.k_base || push!(errors, :k_base_mismatch)
        expression.slope_diag == p.k_slope || push!(errors, :k_slope_mismatch)
        p.formula === :tensor_bubble_product_variable_diagonal_affine_v1 ||
            push!(errors, :k_formula_expression_mismatch)
    elseif expression isa FusionConceptAI.G1DiffusionSymmetricAffineTensorKFieldV2
        p.formula === :tensor_bubble_product_affine_symmetric_matrix_v2 ||
            push!(errors, :k_formula_expression_mismatch)
        expression.domain_min == p.physical_lower &&
            expression.domain_max == p.physical_upper ||
            push!(errors, :k_domain_program_bounds_mismatch)
        expression.base_matrix == p.k_base_matrix ||
            push!(errors, :k_base_matrix_mismatch)
        expression.slope_matrices == p.k_slope_matrices ||
            push!(errors, :k_slope_matrices_mismatch)
    else
        push!(errors, :k_expression_type_mismatch)
    end
    bounds = g2mb_chart_image_bounds(g2.source.chart_map)
    lower = ntuple(i -> bounds[i][1], 3)
    upper = ntuple(i -> bounds[i][2], 3)
    lower == p.physical_lower && upper == p.physical_upper ||
        push!(errors, :physical_chart_program_bounds_mismatch)
    all(expression.domain_min[i] <= lower[i] &&
        upper[i] <= expression.domain_max[i] for i in 1:3) ||
        push!(errors, :k_domain_does_not_cover_physical_chart)
    _ng12_chart_is_positive_diagonal(g2.source.chart_map) ||
        push!(errors, :unsupported_non_diagonal_or_reversing_chart)
    g2.source.mesh.basis === :Q1 || push!(errors, :unsupported_basis)

    # Optional source facts bind the compiler's scalar H1/Q1 unknown to the
    # source-declared state. Older sources without either fact keep their
    # original admission path; partial declarations cannot use that fallback.
    state_binding = g1.source_payload.unknown_state_binding
    field_space = g2.source.field_space
    interpretation = g2.source.q1_interpretation
    if state_binding !== nothing || field_space !== nothing || interpretation !== nothing
        if state_binding === nothing || field_space === nothing || interpretation === nothing
            push!(errors, :g1_g2_field_space_binding_incomplete)
        else
            state_binding.state_index == 0 && state_binding.role === :unknown &&
                state_binding.field_id == g1.u.field_id &&
                state_binding.physical_type == g1.u.physical_type ||
                push!(errors, :g1_unknown_state_binding_mismatch)
            field_space.state_field_id == state_binding.field_id ||
                push!(errors, :g1_g2_state_field_mismatch)
            field_space.value_shape === :scalar &&
                g1.u.physical_type.value_kind === :scalar_field &&
                g1.u.physical_type.tensor_rank == 0 &&
                g1.u.physical_type.spatial_dimension == 3 ||
                push!(errors, :g1_g2_field_value_shape_mismatch)
            field_space.state_unit == "1" &&
                field_space.state_unit_signature == g1.u.physical_type.units ==
                    g2.source.units.field_value == UnitSignature() ||
                push!(errors, :g1_g2_state_unit_label_mismatch)
            interpretation === :continuous_tensor_product_lagrange_degree1_h1 &&
                g2.source.mesh.basis === :Q1 &&
                g2.source.profile.basis_family === :tensor_product ||
                push!(errors, :g1_g2_basis_interpretation_mismatch)
        end
    end

    faces = _ng12_face_map(g2.source.faces)
    expected_faces = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
    Set(keys(faces)) == Set(expected_faces) ||
        push!(errors, :boundary_face_set_invalid)
    if Set(keys(faces)) == Set(expected_faces)
        all(faces[name].value.kind === :dirichlet &&
            faces[name].value.value == 0 for name in expected_faces) ||
            push!(errors, :boundary_not_all_zero_dirichlet)
    end

    native_u = g1.u.physical_type.units
    native_k = g1.K.physical_type.units
    native_f = g1.f.physical_type.units
    g2.source.units.field_value == native_u ||
        push!(errors, :g1_g2_field_unit_mismatch)
    g2.source.units.flux_value == g1.operators.coefficient_apply.output_type.units ||
        push!(errors, :g1_g2_flux_unit_mismatch)
    try
        native_g1g2_translate_unit_v1(profile, native_u) ==
            _ng12_zero_unit() || push!(errors, :translated_u_unit_mismatch)
        native_g1g2_translate_unit_v1(profile, native_k) ==
            _ng12_zero_unit() || push!(errors, :translated_k_unit_mismatch)
        native_g1g2_translate_unit_v1(profile, native_f) ==
            _ng12_si_length_unit(-2) ||
            push!(errors, :translated_source_unit_mismatch)
        native_g1g2_translate_unit_v1(profile, g2.source.units.coordinate) ==
            _ng12_si_length_unit(1) ||
            push!(errors, :translated_coordinate_unit_mismatch)
        native_g1g2_translate_unit_v1(profile,
            g2.source.units.field_value) == _ng12_zero_unit() ||
            push!(errors, :translated_g2_field_unit_mismatch)
        native_g1g2_translate_unit_v1(profile,
            g2.source.units.flux_value) == _ng12_si_length_unit(-1) ||
            push!(errors, :translated_g2_flux_unit_mismatch)
    catch
        push!(errors, :unit_basis_translation_rejected)
    end
    g1.operators.grad.operator_ref.id == G1_DIFFUSION_GRAD_OPERATOR_ID_V1 &&
    g1.operators.coefficient_apply.operator_ref.id ==
        G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1 &&
    g1.operators.div.operator_ref.id == G1_DIFFUSION_DIV_OPERATOR_ID_V1 &&
    g1.operators.residual_sign == -1 ||
        push!(errors, :native_operator_chain_mismatch)
    Tuple(unique(errors))
end

native_g1g2_physics_errors_v1(::Any, ::Any, ::Any, ::Any) =
    (:native_input_type_invalid,)

function _ng12_manifest_for_layer(package, layer::Symbol)
    matches = Tuple(d for d in package.declarations if d.layer === layer)
    length(matches) == 1 ? only(matches) : nothing
end

function _ng12_t1_package_binding_errors(package::CandidateStatePackageV5NextV2,
        g1::G1DiffusionDeclarationV1, g2::G2MBDeclarationV1)
    errors = Symbol[]
    package.candidate_ref == g1.candidate_ref ||
        push!(errors, :t1_candidate_g1_mismatch)
    adapter = vnext_t1_package_binding_adapter_v2(package)
    adapter.status === :prepared_not_executed && adapter.input !== nothing ||
        push!(errors, :t1_package_reload_adapter_rejected)
    g1_manifest = _ng12_manifest_for_layer(package, :G1)
    g2_manifest = _ng12_manifest_for_layer(package, :G2)
    g1_manifest === nothing && push!(errors, :t1_g1_manifest_missing)
    g2_manifest === nothing && push!(errors, :t1_g2_manifest_missing)
    if g1_manifest !== nothing
        Vector{UInt8}(codeunits(canonical_json(g1))) ==
            Vector{UInt8}(copy_bytes(g1_manifest.declaration_bytes)) ||
            push!(errors, :t1_g1_declaration_carrier_mismatch)
        g1_manifest.declaration_identity_hash == canonical_hash((kind=:declaration,
            ref=g1_manifest.declaration_ref,
            bytes_sha256=g1_manifest.declaration_bytes.sha256)) ||
            push!(errors, :t1_g1_declaration_identity_mismatch)
    end
    if g2_manifest !== nothing
        Vector{UInt8}(codeunits(canonical_json(g2))) ==
            Vector{UInt8}(copy_bytes(g2_manifest.declaration_bytes)) ||
            push!(errors, :t1_g2_declaration_carrier_mismatch)
        g2_manifest.declaration_identity_hash == canonical_hash((kind=:declaration,
            ref=g2_manifest.declaration_ref,
            bytes_sha256=g2_manifest.declaration_bytes.sha256)) ||
            push!(errors, :t1_g2_declaration_identity_mismatch)
    end
    Tuple(unique(errors))
end

_ng12_t1_package_binding_errors(::Any, ::Any, ::Any) =
    (:t1_package_type_invalid,)

"""Compile the candidate-authored static scalar G1 roots for the RHS consumer.

The manufactured u/f programs remain regression fixtures. This capability is
separately bound to the actual T1 declarations and is the only source used by
the Gridap weak form for candidate-authored sources. Dynamic and multi-field
roots remain outside the current G1 declaration contract.
"""
function _ng12_authored_source_capability_v1(package,
        g1::G1DiffusionDeclarationV1, g2::G2MBDeclarationV1)
    spec = _g1_authored_typed_source_spec_v1(g1)
    spec === nothing && return nothing
    g1_manifest = _ng12_manifest_for_layer(package, :G1)
    g2_manifest = _ng12_manifest_for_layer(package, :G2)
    g1_manifest === nothing && throw(ArgumentError("typed_absent: G1 declaration manifest missing"))
    g2_manifest === nothing && throw(ArgumentError("typed_absent: G2 declaration manifest missing"))
    chart = g2.source.chart_map
    chart isa G2MBChartMapV1 || throw(ArgumentError("typed_absent: G2 chart declaration missing"))
    build_g1_candidate_typed_source_capability_v1((
        spec=spec, candidate_ref=g1.candidate_ref, g1_source_ref=g1.source_ref,
        g1_declaration_ref=g1_manifest.declaration_ref,
        u_field_id=g1.u.field_id, f_field_id=g1.f.field_id,
        u_type=g1.u.physical_type, f_type=g1.f.physical_type,
        g2_source_ref=g2.source.source_ref,
        g2_declaration_ref=g2_manifest.declaration_ref,
        chart_ref=chart.chart_ref, chart_hash=canonical_hash(chart),
        chart_input_type=chart_coordinate_type_v1()))
end

function native_g1g2_t1_binding_errors_v1(admission,
        g1::G1DiffusionDeclarationV1, g2::G2MBDeclarationV1)
    errors = Symbol[]
    hasproperty(admission, :status) && hasproperty(admission, :package) ||
        return (:t1_admission_shape_invalid,)
    admission.status === :prepared_not_executed ||
        push!(errors, :t1_admission_status_invalid)
    admission.resolution === :terminal_deferred ||
        push!(errors, :t1_admission_resolution_invalid)
    admission.accepted === false || push!(errors, :t1_admission_acceptance_invalid)
    admission.claim_ceiling === :contract_only ||
        push!(errors, :t1_admission_claim_ceiling_invalid)
    isempty(admission.errors) || push!(errors, :t1_admission_errors_present)
    package = admission.package
    package === nothing && return Tuple(unique((errors...,
        :t1_package_missing)))
    append!(errors, _ng12_t1_package_binding_errors(package, g1, g2))
    Tuple(unique(errors))
end

struct NativeG1G2VariableDiffusionFormV1
    candidate_ref::QualifiedRefV1
    t1_package::CandidateStatePackageV5NextV2
    t1_package_hash::Digest256
    t1_semantic_identity::Digest256
    t0_bundle_hash::Digest256
    g1_declaration::G1DiffusionDeclarationV1
    g2_declaration::G2MBDeclarationV1
    programs::NativeG1G2ProgramBundleV1
    authored_source_capability::Union{Nothing,NamedTuple}
    unit_profile::NativeG1G2UnitCompatibilityProfileV1
    weak_form_sign::Symbol
    coordinate_semantics::Symbol
    boundary_semantics::Symbol
    form_hash::Digest256
end

function _ng12_form_body(candidate_ref, t1_package_hash,
        t1_semantic_identity, t0_bundle_hash, g1_declaration, g2_declaration,
        programs, authored_source_capability, unit_profile, weak_form_sign, coordinate_semantics,
        boundary_semantics)
    (domain="native-g1g2-variable-diffusion-form-v1",
        candidate_ref=candidate_ref,
        t1_package_hash=t1_package_hash,
        t1_semantic_identity=t1_semantic_identity,
        t0_bundle_hash=t0_bundle_hash, g1_declaration=g1_declaration,
        g2_declaration=g2_declaration, programs=programs,
        authored_source_capability=authored_source_capability,
        unit_profile=unit_profile, weak_form_sign=weak_form_sign,
        coordinate_semantics=coordinate_semantics,
        boundary_semantics=boundary_semantics)
end

semantic_view(x::NativeG1G2VariableDiffusionFormV1) = merge(
    _ng12_form_body(x.candidate_ref, x.t1_package_hash,
        x.t1_semantic_identity, x.t0_bundle_hash, x.g1_declaration,
        x.g2_declaration, x.programs, x.authored_source_capability,
        x.unit_profile, x.weak_form_sign,
        x.coordinate_semantics, x.boundary_semantics),
    (form_hash=x.form_hash,))

function FusionConceptAI._canonical(x::NativeG1G2VariableDiffusionFormV1)
    FusionConceptAI._canonical_json_memoized(x) do
        FusionConceptAI._canonical(FusionConceptAI.semantic_view(x))
    end
end

canonical_hash(x::NativeG1G2VariableDiffusionFormV1) = x.form_hash

function _ng12_form_integrity(x::NativeG1G2VariableDiffusionFormV1)
    _ng12_stage_v1("form_integrity_begin")
    basic_bindings_valid = x.weak_form_sign === :minus_div_k_grad &&
    x.coordinate_semantics === :physical_cartesian_metres &&
    x.boundary_semantics === :all_six_faces_zero_dirichlet &&
    x.candidate_ref == x.g1_declaration.candidate_ref &&
    x.t1_package.candidate_ref == x.candidate_ref &&
    x.t1_package.package_hash == x.t1_package_hash &&
    x.t1_package.semantic_identity == x.t1_semantic_identity &&
    x.t1_package.bundle_hash == x.t0_bundle_hash
    basic_bindings_valid || return false
    _ng12_stage_v1("form_integrity_package_binding_begin")
    isempty(_ng12_t1_package_binding_errors(x.t1_package,
        x.g1_declaration, x.g2_declaration)) || return false
    _ng12_stage_v1("form_integrity_package_binding_complete")
    _ng12_stage_v1("form_integrity_physics_begin")
    isempty(native_g1g2_physics_errors_v1(x.g1_declaration,
        x.g2_declaration, x.programs, x.unit_profile)) || return false
    _ng12_stage_v1("form_integrity_physics_complete")
    _ng12_stage_v1("form_integrity_hash_begin")
    valid = canonical_hash(_ng12_form_body(x.candidate_ref, x.t1_package_hash,
        x.t1_semantic_identity, x.t0_bundle_hash, x.g1_declaration,
        x.g2_declaration, x.programs, x.authored_source_capability,
        x.unit_profile, x.weak_form_sign,
        x.coordinate_semantics, x.boundary_semantics)) == x.form_hash
    _ng12_stage_v1("form_integrity_hash_complete")
    valid
end

struct NativeG1G2DiffusionCompilationV1
    form::NativeG1G2VariableDiffusionFormV1
    capability::CapabilitySignatureV4
    subject::ExecutablePhysicalSubjectV4
    scenario::NamedTuple
    compiler_source_hash::Digest256
    compilation_hash::Digest256
end

function _ng12_compilation_body(form, capability, subject, scenario,
        compiler_source_hash)
    (domain="native-g1g2-diffusion-compilation-v1", form=form,
        capability=capability, subject=subject, scenario=scenario,
        compiler_source_hash=compiler_source_hash)
end

semantic_view(x::NativeG1G2DiffusionCompilationV1) = merge(
    _ng12_compilation_body(x.form, x.capability, x.subject, x.scenario,
        x.compiler_source_hash), (compilation_hash=x.compilation_hash,))
canonical_hash(x::NativeG1G2DiffusionCompilationV1) = x.compilation_hash

function validate_native_g1g2_diffusion_compilation_v1(
        x::NativeG1G2DiffusionCompilationV1)
    try
        _ng12_stage_v1("validator_form_integrity_begin")
        form_valid = _ng12_form_integrity(x.form)
        _ng12_stage_v1("validator_form_integrity_complete")
        form_valid || return false
        _ng12_stage_v1("validator_source_hash_begin")
        source_hash_valid = x.compiler_source_hash ==
            native_g1g2_diffusion_compiler_source_hash_v1()
        _ng12_stage_v1("validator_source_hash_complete")
        source_hash_valid || return false
        _ng12_stage_v1("validator_runtime_projection_begin")
        projected = _ng12_runtime_projection_v1(x.form, x.scenario)
        _ng12_stage_v1("validator_runtime_projection_complete")
        _ng12_stage_v1("validator_capability_comparison_begin")
        canonical_json(x.capability) == canonical_json(projected.capability) ||
            return false
        _ng12_stage_v1("validator_capability_comparison_complete")
        _ng12_stage_v1("validator_subject_comparison_begin")
        canonical_json(x.subject) == canonical_json(projected.subject) ||
            return false
        _ng12_stage_v1("validator_subject_comparison_complete")
        _ng12_stage_v1("validator_compilation_hash_begin")
        valid = canonical_hash(_ng12_compilation_body(x.form, x.capability,
            x.subject, x.scenario, x.compiler_source_hash)) ==
            x.compilation_hash
        _ng12_stage_v1("validator_compilation_hash_complete")
        valid
    catch
        false
    end
end

struct NativeG1G2DiffusionCompileResultV1
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    compilation::Union{Nothing,NativeG1G2DiffusionCompilationV1}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    result_hash::Digest256
end

function _ng12_compile_result_body(status, resolution, accepted,
        claim_ceiling, compilation, errors, gaps)
    (domain="native-g1g2-diffusion-compile-result-v1", status=status,
        resolution=resolution, accepted=accepted, claim_ceiling=claim_ceiling,
        compilation=compilation, errors=errors, gaps=gaps)
end

semantic_view(x::NativeG1G2DiffusionCompileResultV1) = merge(
    _ng12_compile_result_body(x.status, x.resolution, x.accepted,
        x.claim_ceiling, x.compilation, x.errors, x.gaps),
    (result_hash=x.result_hash,))
canonical_hash(x::NativeG1G2DiffusionCompileResultV1) = x.result_hash

function _ng12_compile_result(status, resolution, compilation, errors, gaps)
    _ng12_stage_v1("compile_result_hash_begin")
    body = _ng12_compile_result_body(status, resolution, false,
        :contract_only, compilation, Tuple(errors), Tuple(gaps))
    result = NativeG1G2DiffusionCompileResultV1(status, resolution, false,
        :contract_only, compilation, Tuple(errors), Tuple(gaps),
        canonical_hash(body))
    _ng12_stage_v1("compile_result_hash_complete")
    result
end

function _ng12_runtime_projection_v1(
        form::NativeG1G2VariableDiffusionFormV1, scenario::NamedTuple)
    g1 = form.g1_declaration
    g2 = form.g2_declaration
    programs = form.programs
    profile = form.unit_profile
    bounds_hash = canonical_hash((chart=g2.source.chart_map,
        k_expression=g1.K.expression, boundary=g2.source.faces,
        compatibility_profile=profile, applicability=:single_domain_q1))
    input_schema_hash = canonical_hash((
        schema=NATIVE_G1G2_DIFFUSION_SCHEMA_V1,
        version=NATIVE_G1G2_DIFFUSION_VERSION_V1,
        form_profile=NATIVE_G1G2_DIFFUSION_PROFILE_V1,
        typed_residual_hash=canonical_hash(programs.residual_program)))
    capability = CapabilitySignatureV4(
        NATIVE_G1G2_DIFFUSION_SCHEMA_V1,
        NATIVE_G1G2_DIFFUSION_VERSION_V1, :native_g1g2_diffusion,
        "minus_div_variable_diagonal_k_grad", ("u",), "H1", "H1-dual",
        3, ("x", "y", "z"), "all-six-faces-zero-dirichlet",
        "single-domain-no-interface", "static",
        ("matrix", "rhs", "solution", "L2-error", "H1-seminorm-error",
            "analytic-balance-identity", "discrete-boundary-flux",
            "discrete-reaction-balance"), screen_only, bounds_hash;
        input_schema_hash=input_schema_hash,
        coordinate_system="physical-cartesian-metres")
    prefix_hash = canonical_hash((domain="native-g1g2-compiled-prefix-v1",
        candidate_ref=form.candidate_ref, package_hash=form.t1_package_hash,
        form_hash=form.form_hash, capability=capability))
    mission_hash = canonical_hash((mission=:manufactured_variable_diffusion,
        scope=:numerical_preparation, scenario=scenario))
    bindings = (("candidate_ref", form.candidate_ref),
        ("t1_package_hash", form.t1_package_hash),
        ("g1_declaration_hash", g1.declaration_hash),
        ("g2_declaration_hash", g2.declaration_hash),
        ("program_bundle_hash", programs.bundle_hash))
    materialized = (form_hash=form.form_hash, form=form,
        scope=:native_g1g2_numerical_preparation,
        formal_t2_receipt_assignment=false)
    subject = ExecutablePhysicalSubjectV4(prefix_hash,
        form.t1_semantic_identity, mission_hash, bounds_hash, bindings,
        (scenario,), materialized, (capability,))
    (capability=capability, subject=subject)
end

"""Compile an actual native declaration pair carried by a fresh T1 package."""
function compile_native_g1g2_diffusion_v1(admission,
        g1::G1DiffusionDeclarationV1, g2::G2MBDeclarationV1,
        programs::NativeG1G2ProgramBundleV1,
        profile::NativeG1G2UnitCompatibilityProfileV1;
        scenario=(scenario_id="native-g1g2-mms-physical-v1",
            execution_scope=:numerical_preparation))
    _ng12_stage_v1("t1_binding_begin")
    t1_errors = native_g1g2_t1_binding_errors_v1(admission, g1, g2)
    _ng12_stage_v1("t1_binding_complete")
    _ng12_stage_v1("physics_validation_begin")
    physics_errors = native_g1g2_physics_errors_v1(g1, g2, programs, profile)
    _ng12_stage_v1("physics_validation_complete")
    errors = Tuple(unique((t1_errors..., physics_errors...)))
    isempty(errors) || return _ng12_compile_result(:fail_closed, :none,
        nothing, errors, ())
    _ng12_stage_v1("scenario_validation_begin")
    scenario isa NamedTuple && is_canonical_value(scenario) ||
        return _ng12_compile_result(:fail_closed, :none, nothing,
            (:scenario_invalid,), ())
    _ng12_stage_v1("scenario_validation_complete")
    package = admission.package
    _ng12_stage_v1("form_body_construct_begin")
    form_body = _ng12_form_body(package.candidate_ref, package.package_hash,
        package.semantic_identity, package.bundle_hash, g1, g2, programs,
        _ng12_authored_source_capability_v1(package, g1, g2), profile,
        :minus_div_k_grad, :physical_cartesian_metres,
        :all_six_faces_zero_dirichlet)
    _ng12_stage_v1("form_body_construct_complete")
    _ng12_stage_v1("form_hash_begin")
    form_hash = canonical_hash(form_body)
    _ng12_stage_v1("form_hash_complete")
    form = NativeG1G2VariableDiffusionFormV1(package.candidate_ref, package,
        package.package_hash, package.semantic_identity, package.bundle_hash,
        g1, g2, programs, form_body.authored_source_capability, profile,
        :minus_div_k_grad,
        :physical_cartesian_metres, :all_six_faces_zero_dirichlet,
        form_hash)
    _ng12_stage_v1("runtime_projection_begin")
    projected = _ng12_runtime_projection_v1(form, scenario)
    _ng12_stage_v1("runtime_projection_complete")
    capability = projected.capability
    subject = projected.subject
    compiler_hash = native_g1g2_diffusion_compiler_source_hash_v1()
    return FusionConceptAI._with_canonical_json_memo(form) do
        _ng12_stage_v1("compilation_body_construct_begin")
        compilation_body = _ng12_compilation_body(form, capability, subject,
            scenario, compiler_hash)
        _ng12_stage_v1("compilation_body_construct_complete")
        _ng12_stage_v1("compilation_hash_begin")
        compilation_hash = canonical_hash(compilation_body)
        _ng12_stage_v1("compilation_hash_complete")
        compilation = NativeG1G2DiffusionCompilationV1(form, capability,
            subject, scenario, compiler_hash, compilation_hash)
        _ng12_stage_v1("compilation_validation_begin")
        validate_native_g1g2_diffusion_compilation_v1(compilation) ||
            return _ng12_compile_result(:fail_closed, :none, nothing,
                (:compiled_form_integrity_mismatch,), ())
        _ng12_stage_v1("compilation_validation_complete")
        gaps = (:native_g1g2_numerical_execution_pending,
            :up1_aggregate_gate_pending,
            :g3_material_conversion_missing,
            :g3_two_region_interface_missing)
        _ng12_stage_v1("success_result_begin")
        result = _ng12_compile_result(:compiled_numerical_preparation,
            :terminal_deferred, compilation, (), gaps)
        _ng12_stage_v1("success_result_complete")
        result
    end
end

function native_g1g2_reference_value_v1(
        form::NativeG1G2VariableDiffusionFormV1, point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    p = form.programs.parameters
    t = ntuple(i -> (x[i] - Float64(p.physical_lower[i])) /
        Float64(p.physical_lengths[i]), 3)
    prod(t[i] * (1.0 - t[i]) for i in 1:3)
end

function native_g1g2_reference_gradient_v1(
        form::NativeG1G2VariableDiffusionFormV1, point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    p = form.programs.parameters
    t = ntuple(i -> (x[i] - Float64(p.physical_lower[i])) /
        Float64(p.physical_lengths[i]), 3)
    ntuple(i -> ((1.0 - 2.0 * t[i]) / Float64(p.physical_lengths[i])) *
        prod(t[j] * (1.0 - t[j]) for j in 1:3 if j != i), 3)
end

function native_g1g2_k_diagonal_v1(
        form::NativeG1G2VariableDiffusionFormV1, point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    expression = form.g1_declaration.K.expression
    all(Float64(expression.domain_min[i]) <= x[i] <=
        Float64(expression.domain_max[i]) for i in 1:3) ||
        throw(ArgumentError("K evaluation point is outside declared physical domain"))
    if expression isa FusionConceptAI.G1DiffusionDiagonalAffineKFieldV1
        return ntuple(i -> Float64(expression.base_diag[i]) +
            Float64(expression.slope_diag[i]) * x[i], 3)
    end
    k = native_g1g2_k_tensor_v1(form, x)
    ntuple(i -> k[i][i], 3)
end

function native_g1g2_k_tensor_v1(
        form::NativeG1G2VariableDiffusionFormV1, point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    expression = form.g1_declaration.K.expression
    all(Float64(expression.domain_min[i]) <= x[i] <=
        Float64(expression.domain_max[i]) for i in 1:3) ||
        throw(ArgumentError("K evaluation point is outside declared physical domain"))
    if expression isa FusionConceptAI.G1DiffusionDiagonalAffineKFieldV1
        diagonal = native_g1g2_k_diagonal_v1(form, x)
        return ((diagonal[1], 0.0, 0.0),
            (0.0, diagonal[2], 0.0), (0.0, 0.0, diagonal[3]))
    end
    ntuple(i -> ntuple(j -> Float64(expression.base_matrix[i][j]) +
        sum(Float64(expression.slope_matrices[c][i][j]) * x[c]
            for c in 1:3), 3), 3)
end

function native_g1g2_source_value_v1(
        form::NativeG1G2VariableDiffusionFormV1, point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    if form.authored_source_capability !== nothing
        chart = form.g2_declaration.source.chart_map
        chart_point = ntuple(i -> begin
            diagonal = Float64(chart.jacobian_rows[i][i])
            diagonal > 0 || throw(ArgumentError(
                "candidate G1 source requires a positive diagonal chart"))
            (x[i] - Float64(chart.offset[i])) / diagonal
        end, 3)
        evaluated = evaluate_g1_typed_source_program_v1(
            form.authored_source_capability,
            form.authored_source_capability.roots.f, (chart_point,))
        evaluated.status === :ready && length(evaluated.values) == 1 ||
            throw(ArgumentError("candidate G1 source AST did not produce one residual value"))
        value = Float64(only(evaluated.values))
        isfinite(value) || throw(ArgumentError("candidate G1 source is nonfinite"))
        return value
    end
    p = form.programs.parameters
    t = ntuple(i -> (x[i] - Float64(p.physical_lower[i])) /
        Float64(p.physical_lengths[i]), 3)
    expression = form.g1_declaration.K.expression
    if expression isa FusionConceptAI.G1DiffusionSymmetricAffineTensorKFieldV2
        k = native_g1g2_k_tensor_v1(form, x)
        grad = native_g1g2_reference_gradient_v1(form, x)
        hessian = ntuple(i -> ntuple(j -> begin
            if i == j
                -2.0 / Float64(p.physical_lengths[i])^2 *
                    prod(t[m] * (1.0 - t[m]) for m in 1:3 if m != i)
            else
                ((1.0 - 2.0 * t[i]) / Float64(p.physical_lengths[i])) *
                ((1.0 - 2.0 * t[j]) / Float64(p.physical_lengths[j])) *
                    prod(t[m] * (1.0 - t[m]) for m in 1:3 if m != i && m != j)
            end
        end, 3), 3)
        return -sum(Float64(expression.slope_matrices[i][i][j]) * grad[j] +
            k[i][j] * hessian[i][j] for i in 1:3 for j in 1:3)
    end
    k = native_g1g2_k_diagonal_v1(form, x)
    sum((2.0 * k[i] / Float64(p.physical_lengths[i])^2 -
        Float64(p.k_slope[i]) * (1.0 - 2.0 * t[i]) /
            Float64(p.physical_lengths[i])) *
        prod(t[j] * (1.0 - t[j]) for j in 1:3 if j != i)
        for i in 1:3)
end

"""Analytic source/exact-conormal identity for the declared MMS formula.

This is a formula identity, not a numerical flux-conservation receipt.  The
Gridap adapter records the solved-field boundary trace and a separately
assembled full-space reaction balance.  The independent test oracle re-derives
this exact identity without calling here.
"""
function native_g1g2_continuous_balance_v1(
        form::NativeG1G2VariableDiffusionFormV1)
    p = form.programs.parameters
    if form.g1_declaration.K.expression isa FusionConceptAI.G1DiffusionSymmetricAffineTensorKFieldV2
        lo = ntuple(i -> Float64(p.physical_lower[i]), 3)
        lengths = ntuple(i -> Float64(p.physical_lengths[i]), 3)
        abscissae = (0.5 * (1.0 - inv(sqrt(3.0))),
            0.5 * (1.0 + inv(sqrt(3.0))))
        source_integral = 0.0
        for a in abscissae, b in abscissae, c in abscissae
            point = ntuple(i -> lo[i] + lengths[i] * (a, b, c)[i], 3)
            source_integral += native_g1g2_source_value_v1(form, point) *
                prod(lengths) / 8.0
        end
        outward_conormal = 0.0
        for axis in 1:3, side in 0:1, a in abscissae, b in abscissae
            transverse = Tuple(i for i in 1:3 if i != axis)
            coordinates = (a, b)
            point = ntuple(i -> i == axis ?
                (side == 0 ? lo[i] : lo[i] + lengths[i]) :
                lo[i] + lengths[i] * coordinates[findfirst(==(i), transverse)], 3)
            grad = native_g1g2_reference_gradient_v1(form, point)
            tensor = native_g1g2_k_tensor_v1(form, point)
            normal_sign = side == 0 ? -1.0 : 1.0
            outward_conormal += normal_sign * sum(tensor[axis][j] * grad[j]
                for j in 1:3) * prod(lengths[i] for i in transverse) / 4.0
        end
        return (source_integral=source_integral,
            outward_conormal_integral=outward_conormal,
            defect=source_integral + outward_conormal)
    end
    source_integral = 0.0
    outward_conormal = 0.0
    for i in 1:3
        lo = Float64(p.physical_lower[i])
        length_i = Float64(p.physical_lengths[i])
        a = Float64(p.k_base[i]) + Float64(p.k_slope[i]) * lo
        b = Float64(p.k_slope[i])
        transverse = prod(Float64(p.physical_lengths[j]) / 6.0
            for j in 1:3 if j != i)
        contribution = (2.0 * a / length_i + b) * transverse
        source_integral += contribution
        outward_conormal -= contribution
    end
    (source_integral=source_integral,
        outward_conormal_integral=outward_conormal,
        defect=source_integral + outward_conormal)
end
