ng12_stage("fixture.before_using_test")
using Test
ng12_stage("fixture.after_using_test")
using SHA
ng12_stage("fixture.after_using_sha")
using Serialization
ng12_stage("fixture.after_using_serialization")
ng12_stage("fixture.before_using_fusionconceptai")
using FusionConceptAI
ng12_stage("fixture.after_using_fusionconceptai")

const NG12_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const NG12_G = FusionConceptAI

# Use the same current-source component loader as the actual T0/T1 case helper.
# It registers definitions only and loads T0 before the V2 recheck type.
Base.invokelatest(NG12_G.load_genome_v5_components!)
Base.invokelatest(NG12_G.load_vnext_t2_components_v2!)

function ng12_include_if_missing(path::AbstractString, sentinel::Symbol)
    if isdefined(NG12_G, sentinel)
        ng12_stage("fixture.fusion_include.skip"; detail=basename(path))
    else
        ng12_stage("fixture.fusion_include.begin"; detail=basename(path))
        Base.include(NG12_G, path)
        ng12_stage("fixture.fusion_include.complete"; detail=basename(path))
    end
end

ng12_include_if_missing(joinpath(NG12_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"), :VNextT1CanonicalBytesV2)
ng12_include_if_missing(joinpath(NG12_ROOT, "src", "Contracts",
    "VNextT1CandidateBindingV2.jl"), :VNextT1CandidateBindingInputV2)
ng12_include_if_missing(joinpath(NG12_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV2.jl"),
    :VNextAuthorityRecheckLocalV2Input)
ng12_include_if_missing(joinpath(NG12_ROOT, "src", "Contracts",
    "CandidateStatePackageV5NextV2.jl"), :CandidateStatePackageV5NextV2)
ng12_include_if_missing(joinpath(NG12_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5IntegrationV2.jl"), :VNextT1AdmissionInputV2)
ng12_include_if_missing(joinpath(NG12_ROOT, "src", "Contracts",
    "VNextT1PackageBindingAdapterV2.jl"),
    :VNextT1PackageBindingAdapterResultV2)

# Runtime capability/provider types retain their existing module authority.
# Gridap remains an isolated qualification dependency; the old adapter is
# loaded only for its pinned dependency identity and generic mesh interfaces.
if isdefined(Main, :FusionRuntimeV4)
    ng12_stage("fixture.runtime_module_include.skip")
else
    ng12_stage("fixture.runtime_module_include.begin")
    Base.include(Main,
        joinpath(NG12_ROOT, "src", "RuntimeV4", "FusionRuntimeV4.jl"))
    ng12_stage("fixture.runtime_module_include.complete")
end
const NG12_R = Main.FusionRuntimeV4

function ng12_runtime_include_if_missing(path::AbstractString,
        sentinel::Symbol)
    if isdefined(NG12_R, sentinel)
        ng12_stage("fixture.runtime_include.skip"; detail=basename(path))
    else
        ng12_stage("fixture.runtime_include.begin"; detail=basename(path))
        Base.include(NG12_R, path)
        ng12_stage("fixture.runtime_include.complete"; detail=basename(path))
    end
end

ng12_runtime_include_if_missing(joinpath(NG12_ROOT, "src", "RuntimeV4",
    "GridapFieldResidualAdapter.jl"), :GridapFieldProtocolV4)
ng12_runtime_include_if_missing(joinpath(NG12_ROOT, "src", "RuntimeV4",
    "NativeG1G2DiffusionCompilerV1.jl"),
    :NativeG1G2DiffusionCompileResultV1)
ng12_runtime_include_if_missing(joinpath(NG12_ROOT, "src", "RuntimeV4",
    "GridapNativeG1G2DiffusionAdapterV1.jl"),
    :NativeG1G2ExecutionBundleV1)

const NG12_CANDIDATE = NG12_G.QualifiedRefV1(
    "fusionconceptai://candidate/native-g1g2-diffusion-mms-v1", "v5")
const NG12_FOREIGN_CANDIDATE = NG12_G.QualifiedRefV1(
    "fusionconceptai://candidate/native-g1g2-diffusion-foreign-v1", "v5")

const NG12_PHYSICAL_LOWER = (1 // 2, 1 // 3, 1 // 4)
const NG12_PHYSICAL_UPPER = (5 // 2, 10 // 3, 17 // 4)
const NG12_PHYSICAL_LENGTHS = (2 // 1, 3 // 1, 4 // 1)
const NG12_K_BASE = (2 // 1, 3 // 1, 4 // 1)
const NG12_K_SLOPE = (1 // 10, 1 // 20, 1 // 30)

ng12_native_unit(exponents) = NG12_G.UnitSignature(
    ntuple(i -> Rational{Int64}(exponents[i]), 7))
ng12_native_length(power=1) =
    ng12_native_unit((power, 0, 0, 0, 0, 0, 0))

function ng12_profile_and_programs()
    profile = NG12_R.native_g1g2_unit_compatibility_profile_v1()
    programs = NG12_R.native_g1g2_program_bundle_v1(profile;
        physical_lower=NG12_PHYSICAL_LOWER,
        physical_upper=NG12_PHYSICAL_UPPER,
        k_base=NG12_K_BASE, k_slope=NG12_K_SLOPE)
    (profile=profile, programs=programs)
end

function ng12_alternative_source_program_bundle(profile, programs)
    source = programs.source_program
    source_type = source.nodes[source.roots[1]].output_type
    neg = NG12_G.ASTApplyV1(NG12_G.OperatorRefV1("NEG", "v1"),
        (source.roots[1],), (;); registry=programs.registry,
        input_types=(source_type,))
    alternative_source = NG12_G.TypedASTProgramV1((source.nodes..., neg),
        (length(source.nodes) + 1,), source.input_ports;
        registry=programs.registry)
    unknown_expression = NG12_G.canonical_json(
        NG12_R._ng12_unknown_expression_body(programs.unknown_program,
            programs.reference_program, programs.parameters,
            profile.profile_hash))
    source_expression = NG12_G.canonical_json(
        NG12_R._ng12_source_expression_body(alternative_source,
            programs.parameters, profile.profile_hash))
    body = NG12_R._ng12_program_bundle_body(programs.registry,
        programs.unknown_program, programs.reference_program,
        alternative_source, programs.residual_program, programs.parameters,
        profile.profile_hash, unknown_expression, source_expression,
        programs.registry_hash)
    NG12_R.NativeG1G2ProgramBundleV1(programs.registry,
        programs.unknown_program, programs.reference_program,
        alternative_source, programs.residual_program, programs.parameters,
        profile.profile_hash, unknown_expression, source_expression,
        programs.registry_hash, NG12_G.canonical_hash(body))
end

function ng12_g1_declaration(candidate::NG12_G.QualifiedRefV1,
        programs::NG12_R.NativeG1G2ProgramBundleV1;
        domain_min=NG12_PHYSICAL_LOWER,
        domain_max=NG12_PHYSICAL_UPPER,
        unknown_source_expression=programs.unknown_source_expression,
        source_expression=programs.source_expression)
    zero = NG12_G.UnitSignature()
    grad_unit = ng12_native_length(-1)
    source_unit = ng12_native_length(-2)
    static = NG12_G.TemporalTypeV1(NG12_G.static_time)
    scalar = NG12_G.PhysicalType(:scalar_field, 0, 3, static, zero)
    gradient = NG12_G.PhysicalType(:vector_field, 1, 3, static, grad_unit)
    tensor = NG12_G.PhysicalType(:tensor_field, 2, 3, static, zero)
    source_type = NG12_G.PhysicalType(:scalar_field, 0, 3, static,
        source_unit)
    source_ref = NG12_G.QualifiedRefV1(
        "local://native-g1g2/g1/source/" *
            programs.bundle_hash.value[1:16], "v1")
    u = NG12_G.G1DiffusionScalarFieldV1("u", scalar, source_ref;
        source_expression=unknown_source_expression)
    expression = NG12_G.G1DiffusionDiagonalAffineKFieldV1(
        "native-g1g2-diagonal-affine-K"; domain_min=domain_min,
        domain_max=domain_max, base_diag=programs.parameters.k_base,
        slope_diag=programs.parameters.k_slope)
    enclosure = NG12_G.g1_diffusion_k_enclosure(expression)
    k = NG12_G.G1DiffusionCoefficientFieldV1("K", tensor, source_ref;
        lower_bound=enclosure.lower, upper_bound=enclosure.upper,
        expression=expression)
    f = NG12_G.G1DiffusionScalarFieldV1("f", source_type, source_ref;
        source_expression=source_expression)
    grad = NG12_G.G1TypedGradV1(NG12_G.QualifiedRefV1(
        NG12_G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"),
        "u", "grad_u", scalar, gradient)
    apply = NG12_G.G1TypedKApplyV1(NG12_G.QualifiedRefV1(
        NG12_G.G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1"),
        "grad_u", "K_grad_u", gradient, gradient, "K";
        coefficient_units=zero)
    div = NG12_G.G1TypedDivV1(NG12_G.QualifiedRefV1(
        NG12_G.G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1"),
        "K_grad_u", "f", gradient, source_type)
    operators = NG12_G.G1DiffusionOperatorChainV1(grad, apply, div, "f")
    payload = NG12_G.G1DiffusionSourcePayloadV1(candidate, source_ref,
        "native-g1g2-mms-source-v1", u, k, f)
    closure = NG12_G.QualifiedRefV1(NG12_G.G1_DIFFUSION_CLOSURE_ID_V1,
        NG12_G.G1_DIFFUSION_PROFILE_VERSION_V1)
    applicability = NG12_G.QualifiedRefV1(
        NG12_G.G1_DIFFUSION_APPLICABILITY_ID_V1,
        NG12_G.G1_DIFFUSION_PROFILE_VERSION_V1)
    NG12_G.g1_diffusion_declaration_v1(candidate, source_ref,
        "native-g1g2-mms-source-v1",
        NG12_G.g1_diffusion_source_hash_v1(payload), u, k, f, operators,
        closure, applicability,
        "single-physical-cartesian-box-variable-diagonal-diffusion",
        (:manufactured_reference, :source_sign, :coefficient_domain);
        source_payload=payload)
end

function ng12_g2_declaration(;
        chart_rows=((2, 0, 0), (0, 3, 0), (0, 0, 4)),
        cells=(2, 3, 4),
        all_zero_dirichlet::Bool=true,
        field_unit=NG12_G.UnitSignature(),
        flux_unit=ng12_native_length(-1))
    chart_ref = NG12_G.QualifiedRefV1(
        "local://native-g1g2/g2/physical-chart", "v1")
    mesh_ref = NG12_G.QualifiedRefV1(
        "local://native-g1g2/g2/q1-mesh", "v1")
    chart = NG12_G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1),
        chart_rows, NG12_PHYSICAL_LOWER; axes=(:x, :y, :z))
    mesh = NG12_G.G2MBMeshPlanV1(mesh_ref, chart_ref, cells, :Q1,
        ((1 // 2, 1 // 2, 1 // 2),), (1 // 1,);
        execution_status=:not_executed)
    face_specs = (("x-min", :x_min, (-1, 0, 0)),
        ("x-max", :x_max, (1, 0, 0)),
        ("y-min", :y_min, (0, -1, 0)),
        ("y-max", :y_max, (0, 1, 0)),
        ("z-min", :z_min, (0, 0, -1)),
        ("z-max", :z_max, (0, 0, 1)))
    faces = ntuple(i -> begin
        id, face, normal = face_specs[i]
        kind = all_zero_dirichlet || i != 2 ? :dirichlet : :neumann
        value = kind === :dirichlet ? 0 // 1 : 1 // 1
        unit = kind === :dirichlet ? field_unit : flux_unit
        NG12_G.G2MBFaceOwnerV1(id, face, "native-g1g2-region", normal,
            NG12_G.G2MBFaceValueV1(kind, value, unit))
    end, 6)
    units = NG12_G.G2MBUnitContractV1(NG12_G.UnitSignature(),
        ng12_native_length(1), ng12_native_length(1),
        ng12_native_length(2), ng12_native_length(2),
        ng12_native_length(3), field_unit, flux_unit)
    contract = NG12_G._g2sf_expected_contract()
    source = NG12_G.g2mb_source_v1(NG12_G.QualifiedRefV1(
        "local://native-g1g2/g2/source", "v1"),
        "native-g1g2-g2-source-v1", contract, chart, mesh, faces,
        NG12_G.G2MBProfileV1("fusion.g2.metric-boundary.profile"), units,
        NG12_G.G2MBAuthorityV1(:unique_match, :unique_match,
            :unique_match))
    NG12_G.g2mb_declaration_v1(contract, source)
end

const NG12_CURRENT_SOURCE_MMS_CANDIDATE_DIR =
    "test/fixtures/native_g1g2_mms_current_source_v1"
const NG12_CURRENT_SOURCE_MMS_FOREIGN_CANDIDATE_DIR =
    "test/fixtures/native_g1g2_mms_foreign_current_source_v1"
const NG12_CURRENT_SOURCE_MMS_MESH_VARIANT_DIR =
    "test/fixtures/native_g1g2_mms_mesh_334_current_source_v1"
const NG12_CURRENT_SOURCE_MMS_K_VARIANT_DIR =
    "test/fixtures/native_g1g2_mms_k_334_current_source_v1"
const NG12_CURRENT_SOURCE_MMS_ALTERNATIVE_DIR =
    "test/fixtures/native_g1g2_mms_alt_source_current_source_v1"
const NG12_CURRENT_SOURCE_AUTHORED_AST_DIR =
    "test/fixtures/native_g1g2_mms_authored_source_current_source_v1"

function ng12_programs_from_current_expression(expression)
    ratio(s) = begin
        parts = split(String(s), "/"; limit=2)
        length(parts) == 2 || throw(ArgumentError("current-source native MMS rational is malformed"))
        parse(Int64, parts[1]) // parse(Int64, parts[2])
    end
    physical_lower = Tuple(ratio(x) for x in expression.physical_lower_metres)
    physical_upper = Tuple(ratio(x) for x in expression.physical_upper_metres)
    k_base = Tuple(ratio(x) for x in expression.k_base)
    k_slope = Tuple(ratio(x) for x in expression.k_slope)
    profile = NG12_R.native_g1g2_unit_compatibility_profile_v1()
    programs = if hasproperty(expression, :k_base_matrix)
        ratio_matrix(rows) = Tuple(Tuple(ratio(value) for value in row)
            for row in rows)
        base_matrix = ratio_matrix(expression.k_base_matrix)
        slope_matrices = Tuple(ratio_matrix(matrix)
            for matrix in expression.k_slope_matrices)
        NG12_R.native_g1g2_program_bundle_v1(profile;
            physical_lower=physical_lower, physical_upper=physical_upper,
            k_base_matrix=base_matrix, k_slope_matrices=slope_matrices)
    else
        NG12_R.native_g1g2_program_bundle_v1(profile;
            physical_lower=physical_lower, physical_upper=physical_upper,
            k_base=k_base, k_slope=k_slope)
    end
    if hasproperty(expression, :source_program_variant)
        if expression.source_program_variant == "negate_source_root_v1"
            programs = ng12_alternative_source_program_bundle(profile, programs)
        else
            throw(ArgumentError("unsupported native MMS source-program variant"))
        end
    end
    (profile=profile, programs=programs)
end

function ng12_current_source_native_chain(candidate_directory=
        NG12_CURRENT_SOURCE_MMS_CANDIDATE_DIR)
    # Build authored source records, T0, G3 children/witness and T1 exactly
    # once. Native compilation consumes declarations/admission from this run.
    case = ng12_current_source_t1(candidate_directory)
    candidate = case.built.candidate_ref
    profile_programs = ng12_programs_from_current_expression(case.built.expression)
    current = case.current
    independent = case.independent
    transport = case.t0.transport
    witness_build = current.witness
    witness_build !== nothing && witness_build.witness !== nothing ||
        throw(ArgumentError("current-source MMS fixture did not build its source witness"))
    expected_g1_path = replace(String(candidate_directory), '\\' => '/') * "/g1_source.jl"
    expected_g2_path = replace(String(candidate_directory), '\\' => '/') * "/g2_source.jl"
    case.built.entries.g1_source_jl.logical_path == expected_g1_path ||
        throw(ArgumentError("current-source G1 builder origin path mismatch"))
    case.built.entries.g2_source_jl.logical_path == expected_g2_path ||
        throw(ArgumentError("current-source G2 builder origin path mismatch"))
    expected_g3_child_path = replace(String(candidate_directory), '\\' => '/') *
        "/g3_child_design_source.jl"
    case.built.entries.g3_child_design_source_jl.logical_path == expected_g3_child_path ||
        throw(ArgumentError("current-source G3 child entry path mismatch"))
    case.built.child_design.source_path == expected_g3_child_path ||
        throw(ArgumentError("current-source G3 child builder origin path mismatch"))
    recheck_v2 = NG12_G.vnext_declaration_authority_recheck_local_v2(
        NG12_G.VNextAuthorityRecheckLocalV2Input(candidate, transport))
    NG12_G.canonical_json(NG12_G._vnext_t2_t1_recheck_projection_v2(recheck_v2)) == NG12_G.canonical_json(NG12_G._vnext_t2_t1_recheck_projection_v2(current.recheck)) ||
        throw(ArgumentError("current-source V2 recheck changed within the same T0 transport"))
    bridge = current.bridge
    expected = independent.expected
    authority = (status=bridge.status, resolution=bridge.resolution,
        authority_verified=bridge.authority_verified,
        expected_commitment=expected, binding_state=bridge.binding_state,
        commitment_hash=expected.commitment_hash)
    (candidate=candidate, candidate_directory=String(candidate_directory),
     profile=profile_programs.profile, programs=profile_programs.programs,
     g1=case.built.g1.declaration, g2=case.built.g2.declaration,
     g3=case.built.g3.declaration,
     g3_factory_invocation=case.built.g3_factory_invocation,
     declarations=case.records.declarations,
     children=case.records.children, feedback=case.records.feedback,
     transport=transport, recheck_v2=recheck_v2, parent=current.parent,
     realization=independent.realization_state,
     control_payload=independent.control_payload,
     control_state=independent.control_state, projection=nothing,
     expected=expected, binding_key=independent.binding_key, bridge=bridge,
     witness_build=witness_build, witness=witness_build.witness,
     witness_validation=current.witness_validation,
     parents=case.admission.package.parent_commitments, authority=authority,
     admission_input=nothing, admission=case.admission, current=current,
     preparation_counts=(t0_source_record_factory_calls=3,
         v3_source_witness_calls=1, t1_admission_calls=1))
end

function ng12_compiled_fixture(; candidate=NG12_CANDIDATE,
        candidate_directory=NG12_CURRENT_SOURCE_MMS_CANDIDATE_DIR)
    ng12_stage("fixture.source_chain.begin")
    chain = ng12_current_source_native_chain(candidate_directory)
    chain.candidate == candidate ||
        throw(ArgumentError("requested native fixture candidate differs from current-source T1"))
    ng12_stage("fixture.source_chain.complete")
    compiler_calls = 1
    ng12_stage("fixture.compiler.begin")
    compile_result = NG12_R.compile_native_g1g2_diffusion_v1(
        chain.admission, chain.g1, chain.g2, chain.programs, chain.profile)
    ng12_stage("fixture.compiler.complete")
    ng12_stage("fixture.protocol.begin")
    tensor_coefficients = NG12_R._ng12_tensor_budget_coefficients_v1(
        compile_result.compilation.form.g1_declaration.K.expression)
    protocol = NG12_R.native_g1g2_numerical_protocol_v1(
        chain.g2.source.mesh.cells; tensor_coefficients=tensor_coefficients)
    ng12_stage("fixture.protocol.complete")
    ng12_stage("fixture.plan.begin")
    plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
        compile_result, protocol)
    ng12_stage("fixture.plan.complete")
    (chain=chain, compile_result=compile_result, protocol=protocol, plan=plan,
        preparation_counts=merge(chain.preparation_counts,
            (compiler_calls=compiler_calls,)))
end

# Independent analytic oracle.  These functions use the fixture's exact
# rational constants directly and never call a production evaluator.
function ng12_oracle_reference(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    t = ntuple(i -> (x[i] - Float64(NG12_PHYSICAL_LOWER[i])) /
        Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    prod(t[i] * (1.0 - t[i]) for i in 1:3)
end

function ng12_oracle_gradient(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    t = ntuple(i -> (x[i] - Float64(NG12_PHYSICAL_LOWER[i])) /
        Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    ntuple(i -> (1.0 - 2.0 * t[i]) /
        Float64(NG12_PHYSICAL_LENGTHS[i]) *
        prod(t[j] * (1.0 - t[j]) for j in 1:3 if j != i), 3)
end

function ng12_oracle_k(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    ntuple(i -> Float64(NG12_K_BASE[i]) +
        Float64(NG12_K_SLOPE[i]) * x[i], 3)
end

const NG12_TENSOR_K_BASE = ((3 // 1, 1 // 10, 0 // 1),
    (1 // 10, 3 // 1, 0 // 1), (0 // 1, 0 // 1, 4 // 1))
const NG12_TENSOR_K_SLOPES = (
    ((1 // 10, 1 // 100, 0 // 1), (1 // 100, 0 // 1, 0 // 1),
     (0 // 1, 0 // 1, 0 // 1)),
    ((0 // 1, 1 // 200, 0 // 1), (1 // 200, 1 // 20, 0 // 1),
     (0 // 1, 0 // 1, 0 // 1)),
    ((0 // 1, 0 // 1, 0 // 1), (0 // 1, 0 // 1, 0 // 1),
     (0 // 1, 0 // 1, 1 // 30)))

function ng12_tensor_oracle_k(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    ntuple(i -> ntuple(j -> Float64(NG12_TENSOR_K_BASE[i][j]) +
        sum(Float64(NG12_TENSOR_K_SLOPES[c][i][j]) * x[c]
            for c in 1:3), 3), 3)
end

function ng12_tensor_oracle_source(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    t = ntuple(i -> (x[i] - Float64(NG12_PHYSICAL_LOWER[i])) /
        Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    grad = ntuple(i -> (1 - 2t[i]) / Float64(NG12_PHYSICAL_LENGTHS[i]) *
        prod(t[m] * (1 - t[m]) for m in 1:3 if m != i), 3)
    hessian = ntuple(i -> ntuple(j -> i == j ?
        -2 / Float64(NG12_PHYSICAL_LENGTHS[i])^2 *
            prod(t[m] * (1 - t[m]) for m in 1:3 if m != i) :
        ((1 - 2t[i]) / Float64(NG12_PHYSICAL_LENGTHS[i])) *
        ((1 - 2t[j]) / Float64(NG12_PHYSICAL_LENGTHS[j])) *
            prod(t[m] * (1 - t[m]) for m in 1:3 if m != i && m != j), 3), 3)
    k = ng12_tensor_oracle_k(x)
    -sum(Float64(NG12_TENSOR_K_SLOPES[i][i][j]) * grad[j] +
        k[i][j] * hessian[i][j] for i in 1:3 for j in 1:3)
end

function ng12_tensor_oracle_source_diagonal_only(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    t = ntuple(i -> (x[i] - Float64(NG12_PHYSICAL_LOWER[i])) /
        Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    sum((2 * (Float64(NG12_TENSOR_K_BASE[i][i]) +
        sum(Float64(NG12_TENSOR_K_SLOPES[c][i][i]) * x[c]
            for c in 1:3)) / Float64(NG12_PHYSICAL_LENGTHS[i])^2 -
        Float64(NG12_TENSOR_K_SLOPES[i][i][i]) *
            (1 - 2t[i]) / Float64(NG12_PHYSICAL_LENGTHS[i])) *
        prod(t[m] * (1 - t[m]) for m in 1:3 if m != i) for i in 1:3)
end

function ng12_tensor_oracle_balance()
    lo = ntuple(i -> Float64(NG12_PHYSICAL_LOWER[i]), 3)
    lengths = ntuple(i -> Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    midpoint = ntuple(i -> lo[i] + lengths[i] / 2, 3)

    # Integrate the independently authored source formula analytically.  The
    # box integrals of each first-derivative term vanish because the bubble is
    # zero on every face; off-diagonal Hessian terms also vanish against an
    # affine coefficient.  For each diagonal term, integrating the two
    # transverse bubble factors gives 1/36 and the remaining second derivative
    # is constant, yielding Kii(midpoint) * Lj * Lk / (18 * Li).
    source = 0.0
    for axis in 1:3
        k_mid = Float64(NG12_TENSOR_K_BASE[axis][axis]) +
            sum(Float64(NG12_TENSOR_K_SLOPES[c][axis][axis]) * midpoint[c]
                for c in 1:3)
        transverse_area = prod(lengths[i] for i in 1:3 if i != axis)
        source += k_mid * transverse_area / (18 * lengths[axis])
    end

    # For n⋅K∇u, tangential derivatives vanish on each coordinate face.
    # The remaining transverse bubble product has integral 1/36. Since Kii
    # is affine in the transverse coordinates, its face integral is its value
    # at the transverse midpoint times the face area. This closed-form oracle
    # does not share the production 2-point face quadrature or axis mapping.
    outward = 0.0
    for axis in 1:3
        transverse = Tuple(i for i in 1:3 if i != axis)
        face_area = prod(lengths[i] for i in transverse)
        face_pair = 0.0
        for side in 0:1
            point = ntuple(i -> i == axis ? lo[i] + side * lengths[i] :
                midpoint[i], 3)
            k_ii = Float64(NG12_TENSOR_K_BASE[axis][axis]) +
                sum(Float64(NG12_TENSOR_K_SLOPES[c][axis][axis]) * point[c]
                    for c in 1:3)
            face_pair += k_ii
        end
        outward -= face_pair * face_area / (36 * lengths[axis])
    end
    (source_integral=source, outward_conormal_integral=outward,
        defect=source + outward)
end

function ng12_oracle_source(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    t = ntuple(i -> (x[i] - Float64(NG12_PHYSICAL_LOWER[i])) /
        Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    k = ng12_oracle_k(x)
    sum((2.0 * k[i] / Float64(NG12_PHYSICAL_LENGTHS[i])^2 -
        Float64(NG12_K_SLOPE[i]) * (1.0 - 2.0 * t[i]) /
            Float64(NG12_PHYSICAL_LENGTHS[i])) *
        prod(t[j] * (1.0 - t[j]) for j in 1:3 if j != i)
        for i in 1:3)
end

function ng12_oracle_source_without_grad_k(point)
    x = ntuple(i -> Float64(Tuple(point)[i]), 3)
    t = ntuple(i -> (x[i] - Float64(NG12_PHYSICAL_LOWER[i])) /
        Float64(NG12_PHYSICAL_LENGTHS[i]), 3)
    k = ng12_oracle_k(x)
    sum(2.0 * k[i] / Float64(NG12_PHYSICAL_LENGTHS[i])^2 *
        prod(t[j] * (1.0 - t[j]) for j in 1:3 if j != i)
        for i in 1:3)
end

function ng12_oracle_continuous_balance()
    source_integral = 0.0
    outward_conormal = 0.0
    for i in 1:3
        lo = Float64(NG12_PHYSICAL_LOWER[i])
        hi = Float64(NG12_PHYSICAL_UPPER[i])
        length_i = Float64(NG12_PHYSICAL_LENGTHS[i])
        k_lo = Float64(NG12_K_BASE[i]) + Float64(NG12_K_SLOPE[i]) * lo
        k_hi = Float64(NG12_K_BASE[i]) + Float64(NG12_K_SLOPE[i]) * hi
        transverse = prod(Float64(NG12_PHYSICAL_LENGTHS[j]) / 6.0
            for j in 1:3 if j != i)
        face_flux = -(k_lo + k_hi) / length_i * transverse
        outward_conormal += face_flux
        source_integral -= face_flux
    end
    (source_integral=source_integral,
        outward_conormal_integral=outward_conormal,
        defect=source_integral + outward_conormal)
end

function ng12_serialize_bytes(value)
    io = IOBuffer()
    Serialization.serialize(io, value)
    take!(io)
end

ng12_stage("fixture.definitions.complete")
