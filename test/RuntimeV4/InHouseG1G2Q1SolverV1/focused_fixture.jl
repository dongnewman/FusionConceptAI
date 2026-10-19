const NG12_TEST_EPOCH_NS = time_ns()
function ng12_stage(label::AbstractString; detail="")
    elapsed_ms = div(time_ns() - NG12_TEST_EPOCH_NS, 1_000_000)
    suffix = isempty(detail) ? "" : " detail=" * detail
    println("INHOUSE_FIXTURE_STAGE stage=", label,
        " elapsed_ms=", elapsed_ms, suffix)
    flush(stdout)
end

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

# Reuse the real source-authority and G3 child constructors.  The included
# files are definition-only in this process; no historical testset or child
# Julia process is started here.
ng12_stage("fixture.before_v3_fixture_include")
Base.include(Main, joinpath(NG12_ROOT, "test", "GenomeV5", "Integration",
    "VNextT2ConcreteSourceWitnessV3", "fixture_helpers.jl"))
ng12_stage("fixture.after_v3_fixture_include")

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

# Runtime capability/provider types and the candidate-bound compiler retain
# their existing module authority. Gridap adapters are intentionally omitted.
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
    "NativeG1G2DiffusionCompilerV1.jl"),
    :NativeG1G2DiffusionCompileResultV1)
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
        chart_rows, NG12_PHYSICAL_LOWER)
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

function ng12_source_chain(; candidate=NG12_CANDIDATE,
        profile_programs=ng12_profile_and_programs(),
        g1_declaration=nothing, g2_declaration=nothing)
    ng12_stage("fixture.chain.body.begin")
    profile = profile_programs.profile
    programs = profile_programs.programs
    g1 = g1_declaration === nothing ?
        ng12_g1_declaration(candidate, programs) : g1_declaration
    g2 = g2_declaration === nothing ? ng12_g2_declaration() : g2_declaration
    g3 = Main._t0l_g3(candidate)
    ng12_stage("fixture.chain.native_declarations.complete")
    t0_source_record_factory_calls = 0
    declarations = (
        Main._t0l_present(:G1, g1; candidate=candidate),
        Main._t0l_present(:G2, g2; candidate=candidate,
            path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        Main._t0l_present(:G3, g3; candidate=candidate,
            path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    t0_source_record_factory_calls += 3
    children = (Main._t0l_child(:realization; candidate=candidate),
        Main._t0l_child(:control; candidate=candidate),
        Main._t0l_child(:binding; candidate=candidate))
    feedback = Tuple(Main._t0l_feedback(target.target_id,
        declarations[target.target_layer === :G1 ? 1 : 2].declaration_ref;
        target_layer=target.target_layer, candidate=candidate)
        for target in g3.feedback_targets)
    ng12_stage("fixture.chain.t0_records.complete")
    ng12_stage("fixture.chain.transport.begin")
    transport_result = NG12_G.vnext_declaration_transport_local_v1(
        candidate, declarations, children, feedback)
    transport = transport_result.transport
    ng12_stage("fixture.chain.transport.complete")
    # Q1's T1 preparation uses the existing V2 byte carrier and full V2
    # transport recheck. This fixture deliberately stops before the V1
    # snapshot/T2 witness path; it is not a V3 source-witness or formal T2
    # acceptance run.
    ng12_stage("fixture.chain.recheck_v2.begin")
    recheck_v2 = NG12_G.vnext_declaration_authority_recheck_local_v2(
        NG12_G.VNextAuthorityRecheckLocalV2Input(candidate, transport))
    ng12_stage("fixture.chain.recheck_v2.complete")
    recheck_v2.status === :local_checked_present ||
        error("Q1 V2 source recheck did not produce checked-present evidence")
    recheck_v2.resolution === :resolved ||
        error("Q1 V2 source recheck did not resolve the present transport")
    recheck_v2.output isa NG12_G.VNextAuthorityRecheckLocalV2Checked ||
        error("Q1 V2 source recheck output has an invalid shape")
    g3_record = recheck_v2.output.declarations[3]
    g3_unit = only(endpoint.unit for endpoint in g3.endpoints
        if endpoint.role === :source)
    realization = v3_realization_state(candidate, g3_record;
        source=100, field=75, returned=25 // 2, heat=25 // 2, unit=g3_unit)
    control = v3_control_material(candidate, g3_record)
    ng12_stage("fixture.chain.children.complete")
    # Retain the V3 realization/control intrinsic and candidate/parent checks
    # even though this numerical fixture does not construct a V3 witness.
    child_errors = Symbol[]
    NG12_G._vnext_t2_v3_validate_realization(realization, candidate,
        g3_record.declaration_ref, g3_record.declaration_identity_hash,
        child_errors)
    NG12_G._vnext_t2_v3_validate_control(control.payload, control.state,
        candidate, g3_record.declaration_ref,
        g3_record.declaration_identity_hash, child_errors)
    isempty(child_errors) || error("Q1 V3 child validation failed: " *
        join(String.(unique(child_errors)), ","))
    projection = NG12_G.vnext_t2_g3_current_state_projection_v3(candidate,
        g3_record.declaration_ref, g3_record.declaration_identity_hash,
        realization, control.payload, control.state)
    expected = NG12_G.vnext_g3_binding_expected_commitment_v1(candidate,
        recheck_v2.output.bundle_hash, g3_record.declaration_ref,
        g3_record.declaration_identity_hash, projection.realization,
        projection.control)
    expected.commitment_hash ==
        NG12_G.vnext_g3_binding_expected_commitment_hash_v1(expected) ||
        error("Q1 G3 expected commitment hash failed its independent recheck")
    NG12_G._vnext_t2_v3_child_info_matches(projection.realization,
        expected.realization) || error("Q1 realization projection commitment mismatch")
    NG12_G._vnext_t2_v3_child_info_matches(projection.control,
        expected.control) || error("Q1 control projection commitment mismatch")
    binding_key = NG12_G.G3BindingChildKeyV2(candidate,
        g3_record.declaration_ref, g3_record.declaration_identity_hash,
        :binding, "native-g1g2-binding-v1")
    links = Tuple(NG12_G.G3BindingLinkV1(target.target_id,
        target.target_layer, target.target_path, target.quantity, target.unit,
        target.direction, target.sign, target.source_id, target.owner_scope,
        target.authority) for target in g3.feedback_targets)
    # This bridge-only projection follows the existing V2 same-chain fixture.
    # It is a NamedTuple view of V2-checked fields, not a V1 recheck result;
    # it is consumed only by the legacy G3 binding authority bridge below.
    bridge_projection = (
        status=recheck_v2.status,
        resolution=recheck_v2.resolution,
        output=(candidate_ref=recheck_v2.output.candidate_ref,
            bundle_hash=recheck_v2.output.bundle_hash,
            g1=recheck_v2.output.declarations[1],
            g2=recheck_v2.output.declarations[2],
            g3=recheck_v2.output.declarations[3],
            children=recheck_v2.output.children,
            feedback=recheck_v2.output.feedback),
        prior_bundle_sha256=recheck_v2.prior_bundle_sha256)
    bridge = NG12_G.vnext_g3_binding_authority_bridge_local_v1(
        bridge_projection, expected, realization, control.state, binding_key;
        initial_links=links)
    ng12_stage("fixture.chain.bridge.complete")
    # This focused numerical fixture intentionally has no V3 source witness.
    # Formal T2 remains covered by its separate frozen witness chain.
    witness_build = nothing
    ng12_stage("fixture.chain.v3_witness.not_built";
        detail="Q1 test-only; formal T2 remains separate; no physical credit")
    parents = ntuple(i -> NG12_G.vnext_t1_parent_commitment_v2(candidate,
        transport.declarations[i]), 2)
    authority = (status=bridge.status, resolution=bridge.resolution,
        authority_verified=bridge.authority_verified,
        expected_commitment=expected, binding_state=bridge.binding_state,
        commitment_hash=expected.commitment_hash)
    admission_input = NG12_G.VNextT1AdmissionInputV2(candidate, transport,
        recheck_v2, parents, expected.commitment_hash, authority)
    t1_admission_calls = 1
    ng12_stage("fixture.chain.admission.begin")
    admission = NG12_G.vnext_t1_admit_v2(admission_input)
    ng12_stage("fixture.chain.admission.complete")
    (candidate=candidate, profile=profile, programs=programs, g1=g1, g2=g2,
        g3=g3, declarations=declarations, children=children,
        feedback=feedback, transport=transport,
        recheck_v2=recheck_v2, realization=realization,
        control_payload=control.payload, control_state=control.state,
        projection=projection, expected=expected, binding_key=binding_key,
        bridge=bridge, witness_build=witness_build,
        witness=witness_build === nothing ? nothing : witness_build.witness,
        parents=parents, authority=authority,
        admission_input=admission_input, admission=admission,
        preparation_counts=(
            t0_source_record_factory_calls=t0_source_record_factory_calls,
            v3_source_witness_calls=0,
            t1_admission_calls=t1_admission_calls))
end

function ng12_inhouse_compiled_fixture(; candidate=NG12_CANDIDATE)
    ng12_stage("fixture.compile_chain.begin")
    chain = ng12_source_chain(candidate=candidate)
    ng12_stage("fixture.compile_chain.complete")
    ng12_stage("fixture.native_compile.begin")
    compile_result = NG12_R.compile_native_g1g2_diffusion_v1(
        chain.admission, chain.g1, chain.g2, chain.programs, chain.profile)
    ng12_stage("fixture.native_compile.complete")
    (chain=chain, compile_result=compile_result)
end
