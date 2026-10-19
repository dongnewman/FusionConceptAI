using Test
using SHA
using TOML
using JSON3
using Serialization
using Pkg

const G = FusionConceptAI
const _UP2_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "fixtures.json"), String))

# UP2 component loading is intentionally narrower than the source declaration
# suite. Load these existing source APIs only when the full test process has not
# loaded them already; the direct source-binding tests below exercise these
# public layer constructors without creating a second type vocabulary.
const _UP2_SOURCE_COMPONENT_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..",
    "src", "GenomeV5"))
if !isdefined(G, :G1DiffusionScalarFieldV1)
    Base.include(G, joinpath(_UP2_SOURCE_COMPONENT_ROOT, "G1",
        "DiffusionDeclarationV1.jl"))
end
if !isdefined(G, :G2MBFieldSpaceV1)
    Base.include(G, joinpath(_UP2_SOURCE_COMPONENT_ROOT, "G2",
        "MetricBoundaryDeclarationV1.jl"))
end

function _up2_r71_native_runtime(root::AbstractString)
    qualification = joinpath(root, "tools", "qualification", "gridap")
    project = joinpath(qualification, "Project.toml")
    manifest = joinpath(qualification, "Manifest.toml")
    isfile(project) && isfile(manifest) ||
        error("R71 Gridap qualification project or manifest is absent")
    qualification in LOAD_PATH || pushfirst!(LOAD_PATH, qualification)

    # FusionRuntimeV4 imports FusionConceptAI names when it is created, so load
    # the current T2 source declarations before loading the runtime module.
    G.load_vnext_t2_components_v2!()

    runtime_entry = joinpath(root, "src", "RuntimeV4", "FusionRuntimeV4.jl")
    if !isdefined(Main, :FusionRuntimeV4)
        Base.include(Main, runtime_entry)
    end
    runtime = Main.FusionRuntimeV4
    include_if_missing(path, sentinel) = isdefined(runtime, sentinel) ||
        Base.include(runtime, path)
    include_if_missing(joinpath(root, "src", "RuntimeV4",
        "GridapFieldResidualAdapter.jl"), :GridapFieldProtocolV4)
    include_if_missing(joinpath(root, "src", "RuntimeV4",
        "NativeG1G2DiffusionCompilerV1.jl"),
        :NativeG1G2DiffusionCompileResultV1)
    include_if_missing(joinpath(root, "src", "RuntimeV4",
        "GridapNativeG1G2DiffusionAdapterV1.jl"),
        :NativeG1G2ExecutionBundleV1)
    (runtime=runtime, qualification_project=project,
        qualification_manifest=manifest)
end

# Define adapter/compiler methods before the test helpers are compiled. This
# keeps later calls in the current Julia world and only extends LOAD_PATH.
const _UP2_R71_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _UP2_R71_RUNTIME = _up2_r71_native_runtime(_UP2_R71_ROOT)

function _up2_fixture_specs()
    Tuple(G.UP2MutationSpecV1(String(row.id), Symbol(String(row.class_id)),
        String(row.field_path), String(row.source_locator), Symbol(String(row.source_type)),
        Symbol(String(row.mutation_kind)), Symbol(String(row.expected_error)),
        getfield(G, Symbol(String(row.expected_resolution))), Int(row.expected_provider_calls),
        String(row.detail)) for row in _UP2_FIXTURE.mutations)
end

function _up2_value(spec)
    spec.id in ("N01-01", "N01-02", "N01-03") && return G.UP2IntegerValueV1(0)
    spec.id == "N01-04" && return G.UP2IntegerValueV1(3)
    spec.id == "N01-05" && return G.UP2SymbolValueV1(:scalar)
    spec.id == "N02-03" && return G.UP2TextValueV1("1")
    spec.id == "N05-01" && return G.UP2TextValueV1("flux-left")
    spec.id == "N05-02" && return G.UP2TextValueV1("flux-right")
    spec.id == "N05-03" && return G.UP2IntegerValueV1(1)
    spec.id == "N05-04" && return G.UP2IntegerValueV1(-1)
    spec.id == "N05-05" && return G.UP2UnitValueV1(G.UnitSignature())
    spec.source_type === :integer && return G.UP2IntegerValueV1(0)
    spec.source_type === :symbol && return G.UP2SymbolValueV1(:valid)
    spec.source_type === :text && return G.UP2TextValueV1("1")
    spec.source_type === :rational && return G.UP2RationalValueV1(0 // 1)
    spec.source_type === :unit && return G.UP2UnitValueV1(G.UnitSignature())
    spec.source_type === :tuple && return G.UP2TupleValueV1((:valid,), :symbol)
    spec.source_type === :hash && return G.UP2HashValueV1(G.Digest256(repeat("a", 64)))
    spec.source_type === :ref && return G.UP2RefValueV1(G.QualifiedRefV1("fusionconceptai://candidate/up2", "v5"))
    error("unhandled source type $(spec.source_type)")
end

function _up2_reference_input()
    refs = (
        G.GenomeContractRef("fusionconceptai://GenomeV5/G1/candidate-up2", "v5",
            G.Digest256(repeat("1", 64)), G.Digest256(repeat("2", 64)), "g1-up2-profile"),
        G.GenomeContractRef("fusionconceptai://GenomeV5/G2/candidate-up2", "v5",
            G.Digest256(repeat("3", 64)), G.Digest256(repeat("4", 64)), "g2-up2-profile"),
        G.GenomeContractRef("fusionconceptai://GenomeV5/G3/candidate-up2", "v5",
            G.Digest256(repeat("5", 64)), G.Digest256(repeat("6", 64)), "g3-up2-profile"))
    fields = Tuple(G.UP2SemanticFieldV1(spec.id, spec.field_path, spec.source_locator,
        spec.source_type, _up2_value(spec)) for spec in _up2_fixture_specs())
    state = G.UP2PrecompilerStateV1(fields,
        G.UP2FluxPairV1("pair-1", "flux-left", "flux-right", 1, -1, G.UnitSignature()))
    mission = G.UP2MissionBoundsV1("up2_contract_smoke", "scalar_field", "1", "m",
        (0 // 1, 0 // 1, 0 // 1), (1 // 1, 1 // 1, 1 // 1), :static)
    G.UP2PrecompilerInputV1(G.QualifiedRefV1("fusionconceptai://candidate/up2-reference", "v5"),
        refs[1], refs[2], refs[3], G.Digest256(repeat("a", 64)), G.Digest256(repeat("b", 64)),
        G.Digest256(repeat("c", 64)), G.Digest256(repeat("d", 64)), mission, state,
        G.Digest256(repeat("e", 64)), :a_limited, G.terminal_deferred, G.none)
end

function _up2_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    try
        run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
        open(output, "r") do io
            Serialization.deserialize(io)
        end
    finally
        rm(output; force=true)
    end
end

function _up2_actual_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(uri, old.version, old.schema_hash, old.canonicalization_hash,
        old.compatibility_profile, old.version_axes, candidate.id;
        grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    G.MechanismGenomeV5(G.g1_materialize_contract_ref(ref, base.payload.grammar_profile), payload, base.version_axes)
end

function _up2_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _up2_actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle_binding = G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(ch.feedback_id, ch.target_layer,
        ch.target_layer === :G1 ? g1_ref : g2_ref, ch.channel, ch.unit, ch.kind,
        ch.source_id) for ch in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle_binding, realization, control, binding)
end

function _up2_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v5")
    g1 = _up2_actual_g1(_up2_child_fixture("G1"), candidate)
    g2 = _up2_actual_g2(_up2_child_fixture("G2"), candidate)
    g3base = _up2_child_fixture("G3")
    g3 = _up2_actual_g3(g3base, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _up2_native_g1_declaration(; bind_unknown=true, bind_temporal=false)
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/up2-native-source-g1", "v5")
    source = G.QualifiedRefV1("fusionconceptai://source/up2-native-source-g1", "v1")
    zero = G.UnitSignature()
    grad_unit = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    source_unit = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    static = G.TemporalTypeV1(G.static_time)
    scalar = G.PhysicalType(:scalar_field, 0, 3, static, zero)
    gradient = G.PhysicalType(:vector_field, 1, 3, static, grad_unit)
    tensor = G.PhysicalType(:tensor_field, 2, 3, static, zero)
    source_type = G.PhysicalType(:scalar_field, 0, 3, static, source_unit)
    u = G.G1DiffusionScalarFieldV1("u", scalar, source;
        source_expression="u(x)=x1+x2+x3")
    k_expression = G.G1DiffusionDiagonalAffineKFieldV1("K-affine";
        domain_min=(0 // 1, 0 // 1, 0 // 1), domain_max=(1 // 1, 1 // 1, 1 // 1),
        base_diag=(2 // 1, 3 // 1, 4 // 1),
        slope_diag=(1 // 10, 1 // 20, 1 // 30))
    k = G.G1DiffusionCoefficientFieldV1("K", tensor, source;
        lower_bound=2 // 1, upper_bound=121 // 30, expression=k_expression)
    f = G.G1DiffusionScalarFieldV1("f", source_type, source;
        source_expression="f(x)=1")
    grad = G.G1TypedGradV1(G.QualifiedRefV1(G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"),
        "u", "grad_u", scalar, gradient)
    k_apply = G.G1TypedKApplyV1(
        G.QualifiedRefV1(G.G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1"),
        "grad_u", "flux_u", gradient, gradient, "K")
    div = G.G1TypedDivV1(G.QualifiedRefV1(G.G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1"),
        "flux_u", "f", gradient, source_type)
    operators = G.G1DiffusionOperatorChainV1(grad, k_apply, div, "f")
    binding = bind_unknown ? G.G1DiffusionUnknownStateBindingV1(0, :unknown,
        u.field_id, u.physical_type) : nothing
    temporal_support = if bind_temporal
        grad_ref = G.QualifiedRefV1(G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1")
        apply_ref = G.QualifiedRefV1(G.G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1")
        div_ref = G.QualifiedRefV1(G.G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1")
        G.G1DiffusionOperatorTemporalSupportV1(
            G.G1DiffusionOperatorTemporalWhitelistV1(grad_ref, (G.static_time,)),
            G.G1DiffusionOperatorTemporalWhitelistV1(apply_ref, (G.static_time,)),
            G.G1DiffusionOperatorTemporalWhitelistV1(div_ref, (G.static_time,)))
    else
        nothing
    end
    payload = G.G1DiffusionSourcePayloadV1(candidate, source,
        "candidate-source-v1", u, k, f; unknown_state_binding=binding,
        operator_temporal_support=temporal_support)
    G.g1_diffusion_declaration_v1(candidate, source, "candidate-source-v1",
        G.g1_diffusion_source_hash_v1(payload), u, k, f, operators,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/G1/closure/diffusion", "v1"),
        G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v1"),
        "bounded-3d-candidate-domain",
        (:missing_authoritative_source, :manufactured_solution_as_authority);
        source_payload=payload)
end

function _up2_native_g2_source(; field_space=nothing,
        q1_interpretation=nothing, mesh_basis=:Q1, field_value_unit=nothing,
        chart_axes=nothing, boundary_coverage=nothing)
    r(n, d=1) = Int64(n) // Int64(d)
    chart_ref = G.QualifiedRefV1("fusion.g2.up2-native-source.chart", "v1")
    mesh_ref = G.QualifiedRefV1("fusion.g2.up2-native-source.mesh", "v1")
    chart = G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1),
        ((2, 0, 0), (0, 3, 0), (0, 0, 4)), (r(1, 2), r(1, 3), r(1, 4));
        axes=chart_axes)
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2, 3, 4), mesh_basis,
        ((r(1, 2), r(1, 2), r(1, 2)),), (1,); execution_status=:not_executed)
    scalar_unit = field_value_unit === nothing ? G.UnitSignature() : field_value_unit
    flux_unit = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))
    faces = Tuple(G.G2MBFaceOwnerV1("face-" * String(name), name, "candidate-domain",
        normal, G.G2MBFaceValueV1(:dirichlet, 0, scalar_unit)) for
        (name, normal) in ((:x_min, (-1, 0, 0)), (:x_max, (1, 0, 0)),
        (:y_min, (0, -1, 0)), (:y_max, (0, 1, 0)),
        (:z_min, (0, 0, -1)), (:z_max, (0, 0, 1))))
    units = G.G2MBUnitContractV1(G.UnitSignature(),
        G.UnitSignature((1, 0, 0, 0, 0, 0, 0)),
        G.UnitSignature((1, 0, 0, 0, 0, 0, 0)),
        G.UnitSignature((2, 0, 0, 0, 0, 0, 0)),
        G.UnitSignature((2, 0, 0, 0, 0, 0, 0)),
        G.UnitSignature((3, 0, 0, 0, 0, 0, 0)), scalar_unit, flux_unit)
    profile = G.G2MBProfileV1("fusion.g2.up2-native-source.profile")
    G.g2mb_source_v1(G.QualifiedRefV1("fusionconceptai://source/up2-native-source-g2", "v1"),
        "g2-metric-boundary-source-v1", G.GenomeContractRef(
            "fusionconceptai://GenomeV5/candidate/up2-native-source-g2", "v5",
            G.digest256_text("up2-native-source-schema"),
            G.digest256_text("up2-native-source-canon"), "up2-native-source-profile"),
        chart, mesh, faces, profile, units,
        G.G2MBAuthorityV1(:unique_match, :no_match, :no_match);
        field_space=field_space, q1_interpretation=q1_interpretation,
        boundary_coverage=boundary_coverage)
end

function _up2_native_g2_declaration(source)
    profile = source.profile
    contract = G.GenomeContractRef(
        "fusionconceptai://GenomeV5/G2/up2-native-source", "v5",
        G.g2mb_schema_hash_v1(), G.g2mb_canonicalization_hash_v1(),
        G.g2mb_profile_token_v1(profile))
    G.g2mb_declaration_v1(contract, source)
end

@testset "UP2-00 native G1/G2 optional source bindings preserve old canonical bytes" begin
    legacy_g1 = _up2_native_g1_declaration(bind_unknown=false)
    bound_g1 = _up2_native_g1_declaration()
    old_payload = legacy_g1.source_payload
    old_payload_semantic = (
        schema_id="GenomeV5/G1/DiffusionSourcePayloadV1", version="v1",
        candidate_ref=old_payload.candidate_ref, source_ref=old_payload.source_ref,
        source_version=old_payload.source_version, u=old_payload.u,
        K=old_payload.K, f=old_payload.f)
    @test old_payload.unknown_state_binding === nothing
    @test old_payload.operator_temporal_support === nothing
    @test !hasproperty(G.semantic_view(old_payload), :unknown_state_binding)
    @test !hasproperty(G.semantic_view(old_payload), :operator_temporal_support)
    @test G.canonical_json(old_payload) == G.canonical_json(old_payload_semantic)
    @test G.g1_diffusion_source_hash_v1(old_payload) ==
        G.canonical_hash(old_payload_semantic)
    @test bound_g1.source_payload.unknown_state_binding ==
        G.G1DiffusionUnknownStateBindingV1(0, :unknown, bound_g1.u.field_id,
            bound_g1.u.physical_type)
    @test bound_g1.source_hash != legacy_g1.source_hash
    @test hasproperty(G.semantic_view(bound_g1.source_payload),
        :unknown_state_binding)

    temporal_g1 = _up2_native_g1_declaration(bind_temporal=true)
    temporal_support = temporal_g1.source_payload.operator_temporal_support
    @test temporal_support isa G.G1DiffusionOperatorTemporalSupportV1
    @test temporal_support.grad.operator_ref == temporal_g1.operators.grad.operator_ref
    @test temporal_support.coefficient_apply.operator_ref ==
        temporal_g1.operators.coefficient_apply.operator_ref
    @test temporal_support.div.operator_ref == temporal_g1.operators.div.operator_ref
    @test temporal_support.grad.temporal_kinds == (G.static_time,)
    @test temporal_support.coefficient_apply.temporal_kinds == (G.static_time,)
    @test temporal_support.div.temporal_kinds == (G.static_time,)
    @test hasproperty(G.semantic_view(temporal_g1.source_payload),
        :operator_temporal_support)
    @test temporal_g1.source_hash != bound_g1.source_hash
    @test temporal_g1.declaration_hash != bound_g1.declaration_hash
    @test_throws ArgumentError G.G1DiffusionOperatorTemporalWhitelistV1(
        temporal_g1.operators.grad.operator_ref, ())
    @test_throws ArgumentError G.G1DiffusionOperatorTemporalWhitelistV1(
        temporal_g1.operators.grad.operator_ref,
        (G.static_time, G.static_time))
    @test_throws ArgumentError G.G1DiffusionOperatorTemporalSupportV1(
        temporal_support.coefficient_apply, temporal_support.grad,
        temporal_support.div)
    wrong_temporal_support = G.G1DiffusionOperatorTemporalSupportV1(
        G.G1DiffusionOperatorTemporalWhitelistV1(
            temporal_g1.operators.grad.operator_ref, (G.event_time,)),
        temporal_support.coefficient_apply, temporal_support.div)
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(
        temporal_g1.candidate_ref, temporal_g1.source_ref,
        temporal_g1.source_version,
        G.g1_diffusion_source_hash_v1(G.G1DiffusionSourcePayloadV1(
            temporal_g1.candidate_ref, temporal_g1.source_ref,
            temporal_g1.source_version, temporal_g1.u, temporal_g1.K, temporal_g1.f;
            unknown_state_binding=temporal_g1.source_payload.unknown_state_binding,
            operator_temporal_support=wrong_temporal_support)),
        temporal_g1.u, temporal_g1.K, temporal_g1.f, temporal_g1.operators,
        temporal_g1.closure_ref, temporal_g1.applicability_ref,
        temporal_g1.applicability_domain, temporal_g1.negative_controls;
        source_payload=G.G1DiffusionSourcePayloadV1(temporal_g1.candidate_ref,
            temporal_g1.source_ref, temporal_g1.source_version, temporal_g1.u,
            temporal_g1.K, temporal_g1.f;
            unknown_state_binding=temporal_g1.source_payload.unknown_state_binding,
            operator_temporal_support=wrong_temporal_support))

    binding = bound_g1.source_payload.unknown_state_binding
    @test_throws ArgumentError G.G1DiffusionUnknownStateBindingV1(1,
        :unknown, bound_g1.u.field_id, bound_g1.u.physical_type)
    @test_throws ArgumentError G.G1DiffusionUnknownStateBindingV1(0,
        :state, bound_g1.u.field_id, bound_g1.u.physical_type)
    @test_throws ArgumentError G.G1DiffusionSourcePayloadV1(
        bound_g1.candidate_ref, bound_g1.source_ref, bound_g1.source_version,
        bound_g1.u, bound_g1.K, bound_g1.f;
        unknown_state_binding=G.G1DiffusionUnknownStateBindingV1(0, :unknown,
            "different_state", bound_g1.u.physical_type))
    wrong_state_type = G.PhysicalType(:vector_field, 1, 3,
        bound_g1.u.physical_type.temporal_type, bound_g1.u.physical_type.units)
    @test_throws ArgumentError G.G1DiffusionSourcePayloadV1(
        bound_g1.candidate_ref, bound_g1.source_ref, bound_g1.source_version,
        bound_g1.u, bound_g1.K, bound_g1.f;
        unknown_state_binding=G.G1DiffusionUnknownStateBindingV1(0, :unknown,
            bound_g1.u.field_id, wrong_state_type))
    wrong_state_unit = G.PhysicalType(:scalar_field, 0, 3,
        bound_g1.u.physical_type.temporal_type,
        G.UnitSignature((0, 0, 0, 0, 0, 0, 1)))
    @test_throws ArgumentError G.G1DiffusionSourcePayloadV1(
        bound_g1.candidate_ref, bound_g1.source_ref, bound_g1.source_version,
        bound_g1.u, bound_g1.K, bound_g1.f;
        unknown_state_binding=G.G1DiffusionUnknownStateBindingV1(0, :unknown,
            bound_g1.u.field_id, wrong_state_unit))
    edited_u = G.G1DiffusionScalarFieldV1(bound_g1.u.field_id,
        bound_g1.u.physical_type, bound_g1.source_ref;
        source_expression="u(x)=2*x1+x2+x3")
    edited_g1 = G.g1_diffusion_edit_source(bound_g1, :u, edited_u)
    @test edited_g1.source_payload.unknown_state_binding == binding
    @test edited_g1.source_hash != bound_g1.source_hash
    @test edited_g1.declaration_hash != bound_g1.declaration_hash
    @test G.g1_diffusion_validate(edited_g1)[1] === :valid
    edited_temporal_g1 = G.g1_diffusion_edit_source(temporal_g1, :u,
        G.G1DiffusionScalarFieldV1(temporal_g1.u.field_id,
            temporal_g1.u.physical_type, temporal_g1.source_ref;
            source_expression="u(x)=3*x1+x2+x3"))
    @test edited_temporal_g1.source_payload.operator_temporal_support ==
        temporal_support
    @test G.g1_diffusion_validate(edited_temporal_g1)[1] === :valid

    legacy_g2 = _up2_native_g2_source()
    old_g2_body = (
        source_ref=legacy_g2.source_ref, source_version=legacy_g2.source_version,
        candidate_ref=legacy_g2.candidate_ref, chart_map=legacy_g2.chart_map,
        mesh=legacy_g2.mesh, faces=G._g2mb_canonical_faces(legacy_g2.faces),
        profile=legacy_g2.profile, units=legacy_g2.units,
        authority=legacy_g2.authority)
    @test legacy_g2.field_space === nothing
    @test legacy_g2.q1_interpretation === nothing
    @test legacy_g2.chart_map.axes === nothing
    @test legacy_g2.boundary_coverage === nothing
    @test !hasproperty(G.semantic_view(legacy_g2.chart_map), :axes)
    @test !hasproperty(G.semantic_view(legacy_g2), :boundary_coverage)
    @test G.semantic_view(legacy_g2) ==
        merge(old_g2_body, (source_hash=legacy_g2.source_hash,))
    @test legacy_g2.source_hash == G.canonical_hash(old_g2_body)

    covered_g2 = _up2_native_g2_source(chart_axes=(:x, :y, :z),
        boundary_coverage=:whole_face)
    @test covered_g2.chart_map.axes == (:x, :y, :z)
    @test covered_g2.boundary_coverage === :whole_face
    @test G.semantic_view(covered_g2.chart_map).axes == (:x, :y, :z)
    @test G.semantic_view(covered_g2).boundary_coverage === :whole_face
    @test covered_g2.source_hash != legacy_g2.source_hash
    @test_throws ArgumentError G.G2MBChartMapV1(
        G.QualifiedRefV1("fusion.g2.test.invalid-axes", "v1"),
        (0, 0, 0), (1, 1, 1), ((2, 0, 0), (0, 3, 0), (0, 0, 4)),
        (0, 0, 0); axes=(:x, :x, :z))
    @test_throws ArgumentError _up2_native_g2_source(
        boundary_coverage=:whole_face)
    @test_throws ArgumentError _up2_native_g2_source(
        chart_axes=(:x, :y, :z), boundary_coverage=:partial_face)
    @test_throws ArgumentError _up2_native_g2_source(
        chart_axes=(:y, :x, :z), boundary_coverage=:whole_face)
    covered_native_g2 = _up2_native_g2_source(field_space=
        G.G2MBFieldSpaceV1("u", :scalar, "1", G.UnitSignature()),
        q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1,
        chart_axes=(:x, :y, :z), boundary_coverage=:whole_face)
    covered_decl = _up2_native_g2_declaration(covered_native_g2)
    edited_covered = G.g2mb_edit_source(covered_decl, :field_space,
        G.G2MBFieldSpaceV1("u-edited", :scalar, "1", G.UnitSignature()))
    @test edited_covered.source.chart_map.axes == (:x, :y, :z)
    @test edited_covered.source.boundary_coverage === :whole_face

    dimensionless = G.G2MBFieldSpaceV1("u", :scalar, "1", G.UnitSignature())
    native_g2 = _up2_native_g2_source(field_space=dimensionless,
        q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1)
    @test native_g2.field_space == dimensionless
    @test native_g2.q1_interpretation ===
        :continuous_tensor_product_lagrange_degree1_h1
    @test native_g2.source_hash != legacy_g2.source_hash
    @test :field_space in keys(G.semantic_view(native_g2))
    @test :q1_interpretation in keys(G.semantic_view(native_g2))

    @test_throws ArgumentError G.G2MBFieldSpaceV1("", :scalar, "1",
        G.UnitSignature())
    @test_throws ArgumentError G.G2MBFieldSpaceV1("u", :tensor3, "1",
        G.UnitSignature())
    @test_throws ArgumentError G.G2MBFieldSpaceV1("u", :scalar, "1",
        G.UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    @test_throws ArgumentError G.G2MBFieldSpaceV1("u", :scalar, "m",
        G.UnitSignature())
    @test_throws ArgumentError _up2_native_g2_source(
        field_space=G.G2MBFieldSpaceV1("u", :scalar, "1", G.UnitSignature()),
        q1_interpretation=:unsupported_q1)
    @test_throws ArgumentError _up2_native_g2_source(
        field_space=G.G2MBFieldSpaceV1("u", :scalar, "1", G.UnitSignature()),
        q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1,
        mesh_basis=:Q2)
    nonzero_field_unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 1))
    @test_throws ArgumentError _up2_native_g2_source(
        field_space=G.G2MBFieldSpaceV1("u", :scalar, "K", nonzero_field_unit),
        q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1)

    g2_declaration = _up2_native_g2_declaration(native_g2)
    edited_space = G.G2MBFieldSpaceV1("u-edited", :scalar, "1",
        G.UnitSignature())
    edited_g2 = G.g2mb_edit_source(g2_declaration, :field_space, edited_space)
    @test edited_g2.source.field_space == edited_space
    @test edited_g2.source.q1_interpretation ===
        native_g2.q1_interpretation
    @test edited_g2.source.chart_map == native_g2.chart_map
    @test edited_g2.source.mesh == native_g2.mesh
    @test edited_g2.source.units == native_g2.units
    @test edited_g2.source.chart_map.axes === nothing
    @test edited_g2.source.boundary_coverage === nothing
    @test edited_g2.source.source_hash != native_g2.source_hash
    @test edited_g2.declaration_hash != g2_declaration.declaration_hash
end

@testset "UP2-00 fixture is schema-bound" begin
    specs = _up2_fixture_specs()
    @test _UP2_FIXTURE.fixture_id == "UP2-00-N01-N10-001"
    @test _UP2_FIXTURE.schema_id == "GenomeV5/UP2/TypedPrecompilerContractV1"
    @test String(_UP2_FIXTURE.schema_version) == "v2"
    @test Bool(_UP2_FIXTURE.schema_validation_only)
    @test Int(_UP2_FIXTURE.mutation_count) == 50
    @test length(specs) == 50
    @test Tuple(G.semantic_view.(specs)) == Tuple(G.semantic_view.(G.up2_expected_mutations()))
end

@testset "UP2-00 real N01 N02 slice and N05 deferred" begin
    input = _up2_reference_input()
    @test G.up2_validate_input(input)
    @test G.up2_schema_hash() isa G.Digest256
    real_specs = filter(x -> x.class_id in (:N01, :N02), _up2_fixture_specs())
    @test length(real_specs) == 10
    for spec in real_specs
        counter = G.UP2InvocationCounterV1()
        result = G.up2_validate_mutation(input, spec; counter=counter)
        expected = :invalid_type
        @test result.error_code == expected
        @test result.error_path == spec.field_path
        @test result.status == :fail_closed
        @test result.mutated_input_hash != input.input_hash
        @test result.compile_calls == 0
        @test result.provider_calls == 0
        @test result.solver_calls == 0
        @test !result.evidence_reused
    end
end

@testset "UP2-00 A projection entrance is typed and package-bound" begin
    input = _up2_reference_input()
    mission = input.mission_bounds
    projection = G.UP2AProjectionV1(input.candidate_ref, input.package_hash,
        input.state.fields, input.state.flux_pair)
    @test projection.projection_hash isa G.Digest256
    @test G.up2_flux_pair_valid(projection.flux_pair)
    @test_throws MethodError G.up2_input_from_a(input, mission, projection, input.source_manifest_hash)
end

@testset "UP2-00 actual A package projection slice" begin
    package = _up2_actual_package()
    @test package isa G.CandidateStatePackageV5
    projection = G.up2_projection_from_a(package)
    specs = _up2_fixture_specs()
    projected = Dict(field.id => field for field in projection.fields)
    equation = first(package.g1.payload.equation_plan.equations)
    operators = package.g1.payload.grammar_profile.operators
    g3_event = first(first(package.g3.control.controllers).events)
    @test g3_event isa G.G3EventV2
    @test g3_event.trigger == :initial
    @test g3_event.time == 0 // 1
    @test G._up2_n03_g3_event_source(package) === g3_event
    operator_index = findfirst(op -> op.ref == equation.operator_ref, operators)
    @test operator_index == 1
    operator = operators[operator_index]
    @test projected["N03-01"].value isa G.UP2SymbolValueV1
    @test projected["N03-01"].value.value == Symbol(equation.temporal_kind)
    @test projected["N03-02"].value isa G.UP2IntegerValueV1
    @test projected["N03-02"].value.value == Int(equation.derivative_order)
    @test projected["N03-03"].value isa G.UP2TupleValueV1
    @test projected["N03-03"].value.values == Tuple(Symbol(x) for x in operator.temporal_kinds)
    @test projected["N03-03"].value.element_type == :timekind_v1
    @test projected["N03-04"].value isa G.UP2SymbolValueV1
    @test projected["N03-04"].value.value == g3_event.trigger
    @test projected["N03-05"].value isa G.UP2RationalValueV1
    @test projected["N03-05"].value.value == g3_event.time
    @test_throws ArgumentError G.G3EventV2("invalid_trigger", :unregistered, 0 // 1, :enable)
    @test_throws ArgumentError G.G3EventV2("negative_event_time", :scheduled, -1 // 1, :enable)
    @test length(specs) == G.up2_mutation_count() == 50
    # Twenty-six rows remain unclassified in the legacy A test scope; the ten
    # N07/N08 rows are exercised by the bound G2 fixture projection below.
    actual_pending = filter(x -> !(x.class_id in (:N01, :N02, :N07, :N08)) &&
        !(x.id in ("N03-01", "N03-02", "N03-03", "N04-02")), specs)
    @test length(actual_pending) == 26
    n03_local = filter(x -> x.id in ("N03-01", "N03-02", "N03-03"), specs)
    @test Tuple(x.mutation_kind for x in n03_local) ==
        (:unsupported_time_kind, :negative_derivative_order, :exclude_equation_time_kind)
    n03_event_specs = filter(x -> x.id in ("N03-04", "N03-05"), specs)
    @test all(x -> x.mutation_kind === :pending, n03_event_specs)
    @test all(x -> x.detail == "time_semantics_mismatch" &&
        x.expected_resolution === G.terminal_deferred && x.expected_provider_calls == 0,
        n03_event_specs)
    n04_02 = only(filter(x -> x.id == "N04-02", specs))
    @test n04_02.mutation_kind === :duplicate_account_ids
    source_account_ids = Tuple(package.g3.realization.network.closures[1].account_ids)
    @test projected["N04-02"].field_path == n04_02.field_path
    @test projected["N04-02"].source_locator == n04_02.source_locator
    @test projected["N04-02"].source_type === n04_02.source_type
    @test projected["N04-02"].value isa G.UP2TupleValueV1
    @test projected["N04-02"].value.element_type === :string
    @test projected["N04-02"].value.values == source_account_ids
    @test !isempty(source_account_ids)
    @test all(x -> x isa String && !isempty(x), source_account_ids)
    @test length(unique(source_account_ids)) == length(source_account_ids)

    other_operator = first(filter(op -> op.ref != equation.operator_ref, operators))
    matched_operator = operators[operator_index]
    misordered_package = (g1=(payload=(grammar_profile=(operators=(other_operator, matched_operator),),),),)
    @test findfirst(op -> op.ref == equation.operator_ref,
        misordered_package.g1.payload.grammar_profile.operators) == 2
    @test_throws ArgumentError G._up2_n03_local_source_values(misordered_package, equation)

    mission = G.UP2MissionBoundsV1("actual_a_package", "scalar_field", "1", "m",
        (0 // 1, 0 // 1, 0 // 1), (1 // 1, 1 // 1, 1 // 1), :static)
    source_manifest_hash = G.digest256_text(read(joinpath(@__DIR__, "..", "UP1-04", "fixtures.json"), String))
    input = G.up2_input_from_a(package, mission, source_manifest_hash)
    @test G.up2_validate_input(input)
    @test Tuple(G.semantic_view.(input.state.fields)) == Tuple(G.semantic_view.(projection.fields))
    local_active = filter(x -> x.class_id in (:N01, :N02, :N03) &&
        x.id != "N03-04" && x.id != "N03-05", _up2_fixture_specs())
    @test length(local_active) == 13
    @test length(local_active) + 1 +
        count(x -> x.class_id in (:N07, :N08), specs) == 24
    for spec in local_active
        result = G.up2_validate_mutation(input, spec)
        @test result.status == :fail_closed
        @test result.error_code == spec.expected_error
        @test result.error_path == spec.field_path
        @test result.mutated_input_hash != result.input_hash
        @test result.compile_calls == 0
        @test result.provider_calls == 0
        @test result.solver_calls == 0
    end
    n04_counter = G.UP2InvocationCounterV1()
    n04_result = G.up2_validate_mutation(input, n04_02; counter=n04_counter)
    @test n04_result.mutation_id == "N04-02"
    @test n04_result.error_path == "/g3/realization/network/closures/0/account_ids"
    @test n04_result.error_code == :invalid_closure
    @test n04_result.status == :fail_closed
    @test n04_result.mutated_input_hash != n04_result.input_hash
    @test n04_result.compile_calls == n04_counter.compile_calls == 0
    @test n04_result.provider_calls == n04_counter.provider_calls == 0
    @test n04_result.solver_calls == n04_counter.solver_calls == 0
    @test !n04_result.evidence_reused
    for spec in actual_pending
        @test_throws ArgumentError G.up2_validate_mutation(input, spec)
    end
    forged_fields = Tuple(i == 1 ? G.UP2SemanticFieldV1(
        projection.fields[i].id, projection.fields[i].field_path,
        projection.fields[i].source_locator, projection.fields[i].source_type,
        G.UP2IntegerValueV1(-1)) : projection.fields[i] for i in eachindex(projection.fields))
    forged = G.UP2AProjectionV1(package.candidate_ref, package.candidate_hash,
        forged_fields, projection.flux_pair)
    @test_throws ArgumentError G.up2_input_from_a(package, mission, forged,
        source_manifest_hash)
end

@testset "UP2-00 fixture-only actual A G2 projection maps all ten rows" begin
    # _up2_actual_package is assembled from the UP1-04 layer fixtures. This is
    # legacy A projector coverage only; R65 source binding is tested separately.
    package = _up2_actual_package()
    @test package.candidate_ref.id == "fusionconceptai://candidate/candidate-1"
    projection = G.n07_n08_projection_from_a(package)
    g2 = package.g2
    @test projection.candidate_ref == package.candidate_ref
    @test projection.package_hash == package.candidate_hash
    @test length(projection.fields) == 10
    expected_ids = ("N07-01", "N07-02", "N07-03", "N07-04", "N07-05",
        "N08-01", "N08-02", "N08-03", "N08-04", "N08-05")
    @test Tuple(field.id for field in projection.fields) == expected_ids
    projected = Dict(field.id => field for field in projection.fields)
    specs = Dict(spec.id => spec for spec in _up2_fixture_specs())
    @test all(field -> field.field_path == specs[field.id].field_path &&
        field.source_locator == specs[field.id].source_locator,
        projection.fields)
    @test projected["N07-01"].value isa G.N07N08Rational3V1
    @test projected["N07-01"].value.value == first(g2.region_interface.regions).lower
    @test projected["N07-02"].value isa G.N07N08Rational3V1
    @test projected["N07-02"].value.value == first(g2.region_interface.regions).upper
    @test projected["N07-03"].value isa G.N07N08SymbolTupleV1
    @test projected["N07-03"].value.value == Tuple(g2.plan.exterior.boundary_faces)
    @test projected["N07-04"].value isa G.N07N08Rational2V1
    @test projected["N07-04"].value.value == first(g2.plan.exterior.boundary_patches).lower
    @test projected["N07-05"].value isa G.N07N08SymbolValueV1
    @test projected["N07-05"].value.value === g2.plan.exterior.boundary_condition
    @test projected["N08-01"].value isa G.N07N08SymbolTupleV1
    @test projected["N08-01"].value.value == g2.plan.chart.axes
    @test projected["N08-02"].value isa G.N07N08SymbolValueV1
    @test projected["N08-02"].value.value === g2.plan.chart.map_kind
    @test projected["N08-03"].value isa G.N07N08Int3V1
    @test projected["N08-03"].value.value == g2.plan.mesh.cells_per_region
    @test projected["N08-04"].value isa G.N07N08SymbolValueV1
    @test projected["N08-04"].value.value === g2.plan.mesh.basis
    @test projected["N08-05"].value isa G.N07N08InterfaceRefsV1
    @test projected["N08-05"].value.value ==
        Tuple(interface.interface_ref for interface in g2.region_interface.interfaces)

    geometry_fixture = JSON3.read(read(joinpath(@__DIR__, "n07_n08_geometry_fixtures.json"), String))
    geometry_specs = Tuple(G.N07N08MutationSpecV1(String(row.id),
        Symbol(String(row.class_id)), String(row.field_path),
        String(row.source_locator), Symbol(String(row.source_type)),
        Symbol(String(row.mutation_kind)), Symbol(String(row.expected_error)),
        getfield(G, Symbol(String(row.expected_resolution))),
        Int(row.expected_provider_calls)) for row in geometry_fixture.mutations)
    @test Int(geometry_fixture.mutation_count) == 10
    @test length(geometry_specs) == 10
    @test Tuple(spec.id for spec in geometry_specs) == expected_ids
    mission = G.UP2MissionBoundsV1("fixture_g2_projection", "scalar_field",
        "1", "m", (0 // 1, 0 // 1, 0 // 1),
        (1 // 1, 1 // 1, 1 // 1), :static)
    source_manifest_hash = G.digest256_text(read(joinpath(@__DIR__, "..",
        "UP1-04", "fixtures.json"), String))
    input = G.up2_input_from_a(package, mission, source_manifest_hash)
    for spec in geometry_specs
        up2_spec = G.up2_spec_for_id(spec.id)
        counter = G.UP2InvocationCounterV1()
        result = G.up2_validate_mutation(input, up2_spec; package=package,
            counter=counter)
        @test result.mutation_id == spec.id
        @test result.status === :fail_closed
        @test result.error_code === :invalid_boundary
        @test result.error_path == spec.field_path
        @test result.detail == specs[spec.id].detail
        @test result.mutated_input_hash != input.input_hash
        @test result.compile_calls == counter.compile_calls == 0
        @test result.provider_calls == counter.provider_calls == 0
        @test result.solver_calls == counter.solver_calls == 0
        @test !result.evidence_reused
    end
end

@testset "UP2-00 pending classes do not self-certify" begin
    input = _up2_reference_input()
    pending = filter(x -> !(x.class_id in (:N01, :N02, :N07, :N08)) &&
        !(x.id in ("N03-01", "N03-02", "N03-03", "N04-02")), _up2_fixture_specs())
    @test length(pending) == 26
    for spec in pending
        @test_throws ArgumentError G.up2_validate_mutation(input, spec)
    end
end

@testset "UP2-00 admission boundaries" begin
    input = _up2_reference_input()
    @test_throws ArgumentError G.UP2PrecompilerInputV1(input.candidate_ref, input.g1_ref,
        G.GenomeContractRef("urn:fusion:g2:old", "v5", input.g2_ref.schema_hash,
            input.g2_ref.canonicalization_hash, input.g2_ref.compatibility_profile), input.g3_ref,
        input.g1_hash, input.g2_hash, input.g3_hash, input.package_hash, input.mission_bounds,
        input.state, input.source_manifest_hash, :a_limited, G.terminal_deferred, G.none)
    @test_throws ArgumentError G.UP2PrecompilerInputV1(input.candidate_ref, input.g1_ref,
        input.g2_ref, input.g3_ref, input.g1_hash, input.g2_hash, input.g3_hash,
        input.package_hash, input.mission_bounds, input.state, input.source_manifest_hash,
        :unreviewed, G.terminal_deferred, G.none)
    counter = G.UP2InvocationCounterV1()
    @test_throws ArgumentError G.up2_provider!(counter, :forbidden)
    @test G.up2_provider_calls(counter) == 0
end

function _up2_current_source_t1_case(root::AbstractString)
    artifact_a = normpath(abspath(get(ENV, "UP2_CURRENT_SOURCE_T1_A",
        joinpath(root, "runs", "e", "up2_native_services_20261001_r20",
            "current_source_actual_t1_commitment_fixed_a_bounded", "t1_admission.bin"))))
    artifact_b = normpath(abspath(get(ENV, "UP2_CURRENT_SOURCE_T1_B",
        joinpath(root, "runs", "e", "up2_native_services_20261001_r20",
            "current_source_actual_t1_commitment_fixed_b_bounded", "t1_admission.bin"))))
    manifest_path = normpath(abspath(get(ENV, "UP2_CURRENT_SOURCE_MANIFEST",
        joinpath(root, "benchmarks", "candidate_designs",
            "local-authored-up4-g123-20260928-r2", "manifest.json"))))
    manifest_bytes = read(manifest_path)
    manifest = JSON3.read(String(copy(manifest_bytes)))
    @test manifest.schema == "candidate-design-input-manifest-v1"
    @test manifest.design_status == "unvalidated_design_input"
    manifest_sha = bytes2hex(SHA.sha256(manifest_bytes))
    candidate_directory = replace(String(get(ENV, "UP2_CURRENT_SOURCE_CANDIDATE_DIRECTORY",
        "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2")), '\\' => '/')
    source_root = normpath(joinpath(root, split(candidate_directory, '/')...))
    @test normpath(dirname(manifest_path)) == source_root
    if get(ENV, "UP2_CURRENT_SOURCE_REQUIRE_G3_REENABLE", "") == "1"
        @test String(manifest.candidate_directory) == candidate_directory
    end
    candidate_ref = G.QualifiedRefV1(String(manifest.candidate_ref.id),
        String(manifest.candidate_ref.version))
    candidate_id = String(manifest.candidate_id)
    scenario_id = String(manifest.scenario_id)
    @test String(manifest.candidate_ref.id) ==
        "fusionconceptai://candidate-design/$(candidate_id)"
    @test String(manifest.scenario_ref.id) ==
        "fusionconceptai://scenario-design/$(scenario_id)"

    function read_current_t1_artifact(path)
        handoff_path = joinpath(dirname(path), "t1_handoff.json")
        handoff_bytes = read(handoff_path)
        handoff = JSON3.read(String(copy(handoff_bytes)))
        @test handoff.schema == "vnext-current-source-t0-t1-handoff-v1"
        @test normpath(abspath(String(handoff.artifact_path))) == path
        artifact_bytes = read(path)
        @test Int(handoff.artifact_bytes) == length(artifact_bytes)
        @test bytes2hex(SHA.sha256(artifact_bytes)) == String(handoff.artifact_sha256)
        @test handoff.candidate_ref_id == candidate_ref.id
        @test handoff.candidate_ref_version == candidate_ref.version
        @test handoff.t0_status == "valid"
        @test handoff.t0_resolution == "local_contract_ready"
        @test handoff.t1_status == "prepared_not_executed"
        @test handoff.t1_resolution == "terminal_deferred"
        @test handoff.t1_accepted == false
        @test handoff.t1_claim_ceiling == "contract_only"
        admission = Serialization.deserialize(IOBuffer(artifact_bytes))
        @test admission isa G.VNextT1AdmissionResultV2
        @test admission.status === :prepared_not_executed
        @test admission.resolution === :terminal_deferred
        @test !admission.accepted && admission.claim_ceiling === :contract_only
        package = admission.package
        @test package isa G.CandidateStatePackageV5NextV2
        @test package.candidate_ref == candidate_ref
        @test package.package_hash.value == String(handoff.t1_package_hash)
        @test package.semantic_identity.value == String(handoff.t1_package_semantic_identity)
        @test package.bundle_hash.value == String(handoff.t0_bundle_hash)
        (; package, handoff)
    end
    a = read_current_t1_artifact(artifact_a)
    b = read_current_t1_artifact(artifact_b)
    function read_current_identity_artifact(which, t1_path)
        env_key = which === :a ? "UP2_CURRENT_SOURCE_IDENTITY_A" : "UP2_CURRENT_SOURCE_IDENTITY_B"
        identity_path = normpath(abspath(get(ENV, env_key, "")))
        @test !isempty(identity_path) && isfile(identity_path)
        if isempty(identity_path) || !isfile(identity_path)
            return nothing
        end
        handoff = JSON3.read(String(copy(read(joinpath(dirname(t1_path), "t1_handoff.json")))))
        identity_bytes = read(identity_path)
        @test normpath(abspath(String(handoff.identity_package_path))) == identity_path
        @test Int(handoff.identity_package_bytes) == length(identity_bytes)
        @test bytes2hex(SHA.sha256(identity_bytes)) == String(handoff.identity_package_sha256)
        identity_package = Serialization.deserialize(IOBuffer(identity_bytes))
        @test identity_package isa G.CandidateStatePackageV5
        if identity_package isa G.CandidateStatePackageV5
            @test String(handoff.identity_package_hash) == identity_package.candidate_hash.value
            @test String(handoff.identity_after) == identity_package.migration_receipt.candidate_identity_after
            @test identity_package.candidate_ref == candidate_ref
            @test identity_package.candidate_hash == G.canonical_hash((
                package_version="v5", candidate_ref=identity_package.candidate_ref,
                component_identity=identity_package.component_identity,
                version_axes=identity_package.version_axes,
                migration_receipt=identity_package.migration_receipt))
            @test identity_package.migration_receipt.candidate_identity_after ==
                G.canonical_hash((candidate_ref=identity_package.candidate_ref,
                    identity=identity_package.component_identity,
                    axes=identity_package.version_axes)).value
            @test G._v5_package_identity_valid(identity_package.candidate_ref,
                identity_package.g1, identity_package.g2, identity_package.g2_binding,
                identity_package.g3, identity_package.version_axes,
                identity_package.component_identity, identity_package.migration_receipt)
            g3_source = identity_package.g3
            @test g3_source isa G.G3AuthoredSourceDesignAggregateV1
            if g3_source isa G.G3AuthoredSourceDesignAggregateV1
                payload = g3_source.authored_payload
                proof = payload.source_proof
                @test G.g3_authored_source_design_payload_valid_v1(g3_source)
                @test payload.candidate_ref == candidate_ref
                @test payload.candidate_id == candidate_id
                @test payload.scenario_id == scenario_id
                @test g3_source.contract_binding.candidate_ref == candidate_ref
                @test payload.source_ref.id == candidate_ref.id * "/g3-child-design"
                @test payload.source_path == candidate_directory *
                    "/g3_child_design_source.jl"
                @test proof.record.candidate_ref == candidate_ref
                @test proof.record.layer === :G3
                @test proof.record.source_ref == payload.builder_source_ref
                @test proof.record.source_bytes.sha256 == payload.builder_source_sha256
                binding_child = only(Tuple(child for child in proof.children if child.kind === :binding))
                @test binding_child.candidate_ref == candidate_ref
                @test binding_child.source_ref == payload.source_ref
                @test binding_child.source_bytes.sha256 == payload.source_sha256
                if hasproperty(manifest, :g3_child_factory)
                    guarded_child = proof.rebuilt_child
                    @test guarded_child.candidate_id == candidate_id
                    @test guarded_child.scenario_id == scenario_id
                    @test guarded_child.source_path == payload.source_path
                    @test guarded_child.control_design.re_enable_policy.threshold_kelvin == 325//1
                    @test guarded_child.control_design.sampled_fault_trace_kelvin ==
                        (293//1, 325//1, 330//1, 335//1, 350//1, 325//1, 293//1)
                end
                if which === :a
                    thermal_source_path = "test/fixtures/thermal_slab/" *
                        "thermal-slab-up4-v5-20261001/g3_child_design_source.jl"
                    thermal_source_bytes = read(joinpath(root,
                        split(thermal_source_path, '/')...))
                    thermal_source_sha = G.Digest256(bytes2hex(SHA.sha256(thermal_source_bytes)))
                    thermal_default_rebuild = G.vnext_t2_v3_rebuild_g3_child_design_source_v1(
                        G.VNextT0LocalBytesV1(thermal_source_bytes, thermal_source_sha),
                        thermal_source_sha, thermal_source_path)
                    thermal_factory_module = G._vnext_t2_v3_frozen_source_module()
                    Base.include_string(thermal_factory_module, String(copy(thermal_source_bytes)),
                        thermal_source_path)
                    thermal_factory_default = Base.invokelatest(getfield(
                        thermal_factory_module, :up4_r2_g3_child_design_source_v1))
                    @test G.canonical_hash(thermal_default_rebuild) ==
                        G.canonical_hash(thermal_factory_default)
                    @test thermal_default_rebuild.candidate_id == "thermal-slab-up4-v5-20261001"
                    @test thermal_default_rebuild.scenario_id ==
                        "scenario-thermal-slab-up4-v5-20261001"
                    @test thermal_default_rebuild.source_path == thermal_source_path
                    @test thermal_default_rebuild.control_design.sampled_fault_trace_kelvin ==
                        (293//1, 325//1, 330//1, 335//1, 350//1)
                end
                for binding in (g3_source.realization.contract_binding,
                        g3_source.control.contract_binding, g3_source.binding.contract_binding)
                    @test binding.candidate_ref == candidate_ref
                    @test binding.binding_hash == G.canonical_hash((
                        contract_ref=binding.contract_ref, candidate_ref=binding.candidate_ref,
                        version_axes=binding.version_axes))
                end
                @test !G.g3_authored_source_design_payload_valid_v1(g3_source,
                    proof.record, proof.children, proof.rebuilt_child; frozen_context=nothing)
            end
            if which === :a
                @test hasproperty(identity_package.component_identity, :g2_source_projection)
                g2_source_projection = identity_package.component_identity.g2_source_projection
                @test G._v5_g2_source_projection_valid(g2_source_projection)
                @test g2_source_projection.genome === identity_package.g2
                original_g2_uri = G._v5_contract_ref(identity_package.g2).uri
                legacy_expected_g2_uri = replace(identity_package.candidate_ref.id,
                    "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
                @test original_g2_uri != legacy_expected_g2_uri

                # Remove only the retained G2 source projection, then recompute the
                # actual identity-after and package hashes through their normal APIs.
                plain_identity = Base.structdiff(identity_package.component_identity,
                    NamedTuple{(:g2_source_projection,)}((g2_source_projection,)))
                @test !hasproperty(plain_identity, :g2_source_projection)
                @test plain_identity.g2_ref == identity_package.component_identity.g2_ref
                plain_identity_after = G.canonical_hash((
                    candidate_ref=identity_package.candidate_ref,
                    identity=plain_identity,
                    axes=identity_package.version_axes)).value
                old_receipt = identity_package.migration_receipt
                plain_receipt = G.GenomeV5MigrationReceipt(old_receipt.receipt_id,
                    old_receipt.candidate_ref, old_receipt.records, old_receipt.status,
                    old_receipt.candidate_identity_before, plain_identity_after,
                    old_receipt.scope)
                @test G._v5_package_identity_valid(identity_package.candidate_ref,
                    identity_package.g1, identity_package.g2, identity_package.g2_binding,
                    identity_package.g3, identity_package.version_axes,
                    plain_identity, plain_receipt)
                plain_package = G.CandidateStatePackageV5(
                    identity_package.candidate_ref, identity_package.g1,
                    identity_package.g2, identity_package.g2_binding,
                    identity_package.g3, identity_package.version_axes,
                    plain_receipt, plain_identity, identity_package.structural_status,
                    identity_package.resolution, identity_package.errors,
                    identity_package.gaps, identity_package.claim_ceiling)
                @test G._v5_contract_ref(plain_package.g2).uri == original_g2_uri
                @test plain_package.candidate_hash == G.canonical_hash((
                    package_version="v5", candidate_ref=plain_package.candidate_ref,
                    component_identity=plain_package.component_identity,
                    version_axes=plain_package.version_axes,
                    migration_receipt=plain_package.migration_receipt))
                n10_error = try
                    G._n10_check_package(plain_package)
                    nothing
                catch err
                    err
                end
                @test n10_error isa ArgumentError
                @test sprint(showerror, n10_error) ==
                    "ArgumentError: N10 G2 ref is foreign to package candidate"
            end
        end
        @test String(handoff.identity_package_status) == "valid"
        identity_package
    end
    identity_a = read_current_identity_artifact(:a, artifact_a)
    identity_b = read_current_identity_artifact(:b, artifact_b)
    @test identity_a isa G.CandidateStatePackageV5
    @test identity_b isa G.CandidateStatePackageV5
    if identity_a isa G.CandidateStatePackageV5 && identity_b isa G.CandidateStatePackageV5
        @test identity_a.candidate_hash == identity_b.candidate_hash
        @test identity_a.migration_receipt.candidate_identity_after == identity_b.migration_receipt.candidate_identity_after
    end
    @test a.handoff.t0_bundle_hash == b.handoff.t0_bundle_hash
    @test a.handoff.g3_commitment_hash == b.handoff.g3_commitment_hash
    @test a.handoff.t1_package_hash == b.handoff.t1_package_hash
    @test a.handoff.t1_package_semantic_identity == b.handoff.t1_package_semantic_identity
    @test a.package.package_hash == b.package.package_hash
    @test a.package.semantic_identity == b.package.semantic_identity
    @test a.package.bundle_hash == b.package.bundle_hash

    sources = (
        g1_builder=(path="g1_source.jl", role="candidate_design_source"),
        g1_declaration_source=(path="src/GenomeV5/G1/DiffusionDeclarationV1.jl", role="production_source"),
        g2_builder=(path="g2_source.jl", role="candidate_design_source"),
        g2_declaration_source=(path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", role="production_source"),
        g3_builder=(path="g3_source.jl", role="candidate_design_source"),
        g3_child_design=(path="g3_child_design_source.jl", role="candidate_design_source"),
    )
    pin_for(role, source) = begin
        path_root = source.role == "candidate_design_source" ? source_root : root
        raw = read(joinpath(path_root, split(source.path, '/')...))
        if source.role == "candidate_design_source"
            entries = filter(row -> String(row.path) == source.path, manifest.files)
            @test length(entries) == 1
            entry = only(entries)
            @test Int(entry.bytes) == length(raw)
            @test bytes2hex(SHA.sha256(raw)) == String(entry.sha256)
        end
        role => (bytes=length(raw), sha256=G.Digest256(bytes2hex(SHA.sha256(raw))))
    end
    source_pins = (; (pin_for(role, source) for (role, source) in pairs(sources))...)
    manifest_hash = G.Digest256(manifest_sha)
    snapshot_id = "current-source:" * scenario_id
    identity = (; candidate_ref, candidate_id, scenario_id, snapshot_id,
        manifest_sha256=manifest_hash)
    mission = G.UP2MissionBoundsV1("current_source_vnext_t1", "scalar_field",
        "1", "m", (0 // 1, 0 // 1, 0 // 1),
        (1 // 1, 1 // 1, 1 // 1), :static)
    build(; p=a.package, id=identity, pins=source_pins, native_plan=nothing,
            native_report=nothing, heat_lift_receipt=nothing, identity_package=identity_a,
            available_route_ids=nothing) =
        G.up2_input_from_vnext_t1(p, mission; id..., source_pins=pins,
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt, current_identity=true,
            identity_package=identity_package, available_route_ids=available_route_ids)
    upstream_receipts = (t0_bundle_hash=String(a.handoff.t0_bundle_hash),
        g3_commitment_hash=String(a.handoff.g3_commitment_hash))
    (; build, identity, mission, package=a.package, replay_package=b.package,
        identity_package=identity_a, replay_identity_package=identity_b,
        source_pins, sources, receipt=nothing, manifest, sidecar=a.handoff,
        upstream_receipts, candidate_id, candidate_ref, candidate_directory,
        current_source_root=source_root)
end

function _up2_vnext_t1_case(run::Symbol)
    G.load_genome_v5_up2_components!()
    G.load_vnext_t2_components_v2!()

    if run === :current_source
        root = normpath(joinpath(@__DIR__, "..", "..", ".."))
        # Keep the source-case closure tuple out of the shared run-symbol inference.
        return Base.invokelatest(_up2_current_source_t1_case, root)
    end

    actual_run, frozen_run = run === :r55 ?
        ("up1_up4_r2_candidate_actual_20260930_r55",
         "up1_up4_r2_frozen_candidate_20260930_r55") :
        run === :r70 ?
        ("up1_up4_r2_candidate_actual_20261001_r70",
         "up1_up4_r2_frozen_candidate_20261001_r70") :
        run === :r71 ?
        ("up1_up4_r2_candidate_actual_20261001_r71",
         "up1_up4_r2_frozen_candidate_20261001_r71") :
        run === :r69 ?
        ("up1_up4_r2_candidate_actual_20260930_r69",
         "up1_up4_r2_frozen_candidate_20260930_r69") :
        run === :r65 ?
        ("up1_up4_r2_candidate_actual_20260930_r65",
         "up1_up4_r2_frozen_candidate_20260930_r65") :
        run === :r54 ?
        ("up1_up4_r2_candidate_actual_20260929_r54",
         "up1_up4_r2_frozen_candidate_20260929_r54") :
        throw(ArgumentError("unsupported UP2 VNext test artifact $run"))
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    artifact_path = joinpath(root, "runs", "e", actual_run, "t1_admission_o0.bin")
    sidecar_path = artifact_path * ".json"
    receipt_path = joinpath(root, "runs", "e", frozen_run, "freeze_receipt.json")
    artifact_bytes = read(artifact_path)
    sidecar = JSON3.read(String(copy(read(sidecar_path))))
    @test sidecar.schema == "up1-native-t1-admission-artifact-sidecar-v1"
    @test Int(sidecar.artifact_bytes) == length(artifact_bytes)
    @test bytes2hex(SHA.sha256(artifact_bytes)) == String(sidecar.artifact_sha256)
    @test normpath(abspath(String(sidecar.freeze_receipt_path))) == normpath(abspath(receipt_path))

    receipt_bytes = read(receipt_path)
    @test bytes2hex(SHA.sha256(receipt_bytes)) == String(sidecar.freeze_receipt_sha256)
    receipt = JSON3.read(String(copy(receipt_bytes)))
    @test receipt.schema == "up1-candidate-freeze-receipt-v1"
    @test receipt.snapshot_id == sidecar.snapshot_id
    @test receipt.scenario_id == sidecar.scenario_id
    @test receipt.candidate_ref == sidecar.candidate_ref.id
    @test receipt.manifest_sha256 == sidecar.manifest_sha256
    manifest_path = joinpath(String(receipt.snapshot_root), "manifest.toml")
    manifest_bytes = read(manifest_path)
    @test bytes2hex(SHA.sha256(manifest_bytes)) == String(receipt.manifest_sha256)
    manifest = TOML.parse(String(copy(manifest_bytes)))
    @test manifest["snapshot"]["snapshot_id"] == String(sidecar.snapshot_id)
    @test manifest["snapshot"]["candidate_ref"] == String(sidecar.candidate_ref.id)
    @test manifest["snapshot"]["scenario_id"] == String(sidecar.scenario_id)

    upstream_receipts = if run in (:r69, :r70, :r71)
        t0_path = run in (:r70, :r71) ?
            joinpath(root, "runs", "e", actual_run, "t0_receipt_o0.json") :
            normpath(abspath(String(sidecar.t0_receipt_path)))
        @test normpath(abspath(String(sidecar.t0_receipt_path))) ==
            normpath(abspath(t0_path))
        t0_bytes = read(t0_path)
        @test bytes2hex(SHA.sha256(t0_bytes)) == String(sidecar.t0_receipt_sha256)
        t0_receipt = JSON3.read(String(copy(t0_bytes)))
        @test t0_receipt.schema == "up1-up4-r2-t0-recheck-receipt-v1"
        @test t0_receipt.status == "valid"
        @test t0_receipt.resolution == "local_contract_ready"
        @test t0_receipt.snapshot_id == sidecar.snapshot_id
        @test t0_receipt.manifest_sha256 == sidecar.manifest_sha256
        @test t0_receipt.candidate_ref.id == sidecar.candidate_ref.id
        @test t0_receipt.bundle_hash == sidecar.package_bundle_hash

        g3_path = run in (:r70, :r71) ?
            joinpath(root, "runs", "e", actual_run, "g3_expected_receipt_o0.json") :
            normpath(abspath(String(sidecar.g3_expected_receipt_path)))
        @test normpath(abspath(String(sidecar.g3_expected_receipt_path))) ==
            normpath(abspath(g3_path))
        g3_bytes = read(g3_path)
        @test bytes2hex(SHA.sha256(g3_bytes)) ==
            String(sidecar.g3_expected_receipt_sha256)
        g3_receipt = JSON3.read(String(copy(g3_bytes)))
        @test g3_receipt.schema == "up1-up4-r2-g3-expected-commitment-v1"
        @test g3_receipt.t0_receipt_sha256 == sidecar.t0_receipt_sha256
        @test g3_receipt.snapshot_id == sidecar.snapshot_id
        @test g3_receipt.manifest_sha256 == sidecar.manifest_sha256
        @test g3_receipt.candidate_ref.id == sidecar.candidate_ref.id
        @test g3_receipt.bundle_hash == sidecar.package_bundle_hash
        @test occursin(r"^[0-9a-f]{64}$", String(g3_receipt.commitment_hash))
        (t0_receipt_sha256=String(sidecar.t0_receipt_sha256),
            g3_expected_receipt_sha256=String(sidecar.g3_expected_receipt_sha256),
            g3_commitment_hash=String(g3_receipt.commitment_hash))
    else
        nothing
    end

    sources = (
        g1_builder=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g1_source.jl", role="candidate_design_source"),
        g1_declaration_source=(path="src/GenomeV5/G1/DiffusionDeclarationV1.jl", role="production_source"),
        g2_builder=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g2_source.jl", role="candidate_design_source"),
        g2_declaration_source=(path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", role="production_source"),
        g3_builder=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g3_source.jl", role="candidate_design_source"),
        g3_child_design=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g3_child_design_source.jl", role="candidate_design_source"),
    )
    pin_for(role, source) = begin
        receipt_rows = filter(row -> row.logical_path == source.path, receipt.entries)
        @test length(receipt_rows) == 1
        row = only(receipt_rows)
        @test row.role == source.role
        manifest_rows = filter(entry -> entry["logical_path"] == source.path,
            manifest["entries"])
        @test length(manifest_rows) == 1
        manifest_row = only(manifest_rows)
        @test manifest_row["role"] == row.role
        @test Int(manifest_row["bytes"]) == Int(row.bytes)
        @test String(manifest_row["sha256"]) == String(row.sha256)
        raw = read(joinpath(String(receipt.snapshot_root), split(source.path, '/')...))
        @test length(raw) == Int(row.bytes)
        @test bytes2hex(SHA.sha256(raw)) == String(row.sha256)
        role => (bytes=Int(row.bytes), sha256=G.Digest256(String(row.sha256)))
    end
    source_pins = (; (pin_for(role, source) for (role, source) in pairs(sources))...)

    admission = Serialization.deserialize(IOBuffer(artifact_bytes))
    @test admission isa G.VNextT1AdmissionResultV2
    @test admission.package isa G.CandidateStatePackageV5NextV2
    @test admission.status === :prepared_not_executed
    @test admission.resolution === :terminal_deferred
    @test !admission.accepted && admission.claim_ceiling === :contract_only
    package = admission.package
    @test package.package_hash.value == String(sidecar.package_hash)
    @test package.semantic_identity.value == String(sidecar.package_semantic_identity)
    @test package.bundle_hash.value == String(sidecar.package_bundle_hash)

    candidate_ref = G.QualifiedRefV1(String(sidecar.candidate_ref.id),
        String(sidecar.candidate_ref.version))
    candidate_prefix = "fusionconceptai://candidate-design/"
    @test startswith(candidate_ref.id, candidate_prefix)
    candidate_id = candidate_ref.id[length(candidate_prefix)+1:end]
    mission = G.UP2MissionBoundsV1("$(run)_vnext_t1", "scalar_field", "1", "m",
        (0 // 1, 0 // 1, 0 // 1), (1 // 1, 1 // 1, 1 // 1), :static)
    identity = (; candidate_ref, candidate_id,
        scenario_id=String(sidecar.scenario_id),
        snapshot_id=String(sidecar.snapshot_id),
        manifest_sha256=G.Digest256(String(sidecar.manifest_sha256)))
    build(; p=package, id=identity, pins=source_pins, native_plan=nothing) =
        G.up2_input_from_vnext_t1(p, mission; id..., source_pins=pins,
            native_plan=native_plan)

    replay_package = if run in (:r65, :r69, :r70, :r71)
        replay_path = joinpath(root, "runs", "e", actual_run, "t1_admission_replay.bin")
        replay_bytes = read(replay_path)
        replay_sidecar = JSON3.read(String(copy(read(replay_path * ".json"))))
        @test Int(replay_sidecar.artifact_bytes) == length(replay_bytes)
        @test bytes2hex(SHA.sha256(replay_bytes)) == String(replay_sidecar.artifact_sha256)
        @test replay_sidecar.snapshot_id == sidecar.snapshot_id
        @test replay_sidecar.manifest_sha256 == sidecar.manifest_sha256
        @test replay_sidecar.candidate_ref.id == sidecar.candidate_ref.id
        @test replay_sidecar.scenario_id == sidecar.scenario_id
        @test replay_sidecar.package_hash == sidecar.package_hash
        @test replay_sidecar.package_semantic_identity == sidecar.package_semantic_identity
        @test replay_sidecar.package_bundle_hash == sidecar.package_bundle_hash
        replay_admission = Serialization.deserialize(IOBuffer(replay_bytes))
        @test replay_admission isa G.VNextT1AdmissionResultV2
        @test replay_admission.package isa G.CandidateStatePackageV5NextV2
        @test replay_admission.package.package_hash == package.package_hash
        @test replay_admission.package.semantic_identity == package.semantic_identity
        @test replay_admission.package.bundle_hash == package.bundle_hash
        replay_admission.package
    else
        nothing
    end
    (; build, identity, mission, package, replay_package, source_pins, sources,
        receipt, manifest, sidecar, upstream_receipts, candidate_id, candidate_ref)
end

function _up2_assert_g2_source_role_binding(case)
    declaration = only(filter(x -> x.layer === :G2, case.package.declarations))
    body = JSON3.read(String(G.copy_bytes(declaration.semantic_body_bytes)))
    declaration_pin = case.source_pins.g2_declaration_source
    builder_pin = case.source_pins.g2_builder
    authored_input = body.authored_builder_input
    authored_bytes_node = authored_input.bytes
    authored_bytes = UInt8.(Int.(authored_bytes_node.values))
    declaration_bytes = G.copy_bytes(declaration.source_bytes)
    @test length(declaration_bytes) == declaration_pin.bytes
    @test bytes2hex(SHA.sha256(declaration_bytes)) ==
        declaration_pin.sha256.value
    @test declaration.source_bytes.sha256.value == declaration_pin.sha256.value
    @test length(authored_bytes) == builder_pin.bytes
    @test Int(first(authored_bytes_node.shape)) == builder_pin.bytes
    @test bytes2hex(SHA.sha256(authored_bytes)) == builder_pin.sha256.value
    @test String(authored_input.sha256.value) == builder_pin.sha256.value
    @test declaration_pin.sha256.value != builder_pin.sha256.value
    @test _up2_vnext_raw_bytes(case, case.sources.g2_builder) == authored_bytes
    @test _up2_vnext_raw_bytes(case, case.sources.g2_declaration_source) ==
        declaration_bytes
    nothing
end

function _up2_vnext_raw_bytes(case, source)
    if hasproperty(case, :current_source_root)
        path_root = source.role == "candidate_design_source" ?
            String(case.current_source_root) : normpath(joinpath(@__DIR__, "..", "..", ".."))
        return read(joinpath(path_root, split(source.path, '/')...))
    end
    read(joinpath(String(case.receipt.snapshot_root), split(source.path, '/')...))
end

function _up2_assert_n01_n02_source_projection(case, input)
    binding = input.source_binding
    g1 = G._up2_vnext_g1_operator_type_context(case.package, binding)
    g2 = G._up2_vnext_g2_geometry_context(case.package, binding)
    expected = (
        "N01-01" => (G.UP2IntegerValueV1(0),
            :candidate_design_g1_operator_type_contract_only,
            (:g1_builder, :g1_declaration_source)),
        "N01-02" => (G.UP2IntegerValueV1(0),
            :candidate_design_g1_operator_type_contract_only,
            (:g1_builder, :g1_declaration_source)),
        "N03-01" => (G.UP2SymbolValueV1(:static_time),
            :candidate_design_g1_diffusion_time_contract_only,
            (:g1_builder, :g1_declaration_source)),
        "N03-02" => (G.UP2IntegerValueV1(0),
            :candidate_design_g1_diffusion_time_contract_only,
            (:g1_builder, :g1_declaration_source)),
        "N01-04" => (G.UP2IntegerValueV1(3),
            :candidate_design_g2_profile_contract_only,
            (:g2_builder, :g2_declaration_source)),
        "N02-01" => (G.UP2UnitValueV1(G.UnitSignature((0, 0, 0, 0, 0, 0, 0))),
            :candidate_design_g1_operator_type_contract_only,
            (:g1_builder, :g1_declaration_source)),
        "N02-02" => (G.UP2UnitValueV1(G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))),
            :candidate_design_g1_operator_type_contract_only,
            (:g1_builder, :g1_declaration_source)))
    projected = Dict(field.id => field for field in input.state.fields)
    for (id, (expected_value, expected_reason, expected_roles)) in expected
        spec = G.up2_spec_for_id(id)
        field = projected[id]
        state = only(filter(row -> row.field_id == id, input.field_states))
        source_value = id == "N01-04" ? G.UP2IntegerValueV1(g2.profile_dimension) :
            id in ("N01-01", "N01-02") ?
            G.UP2IntegerValueV1(g1.values[id]) :
            id == "N03-01" ? G.UP2SymbolValueV1(g1.values[id]) :
            id == "N03-02" ? G.UP2IntegerValueV1(g1.values[id]) :
            G.UP2UnitValueV1(g1.values[id])
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === spec.source_type
        @test G.semantic_view(field.value) == G.semantic_view(expected_value)
        @test G.semantic_view(field.value) == G.semantic_view(source_value)
        @test state.state === :source_present_deferred
        @test state.reason === expected_reason
        @test state.source_pin_roles == expected_roles
    end
    # R55/R65 do not carry the typed G3 ledger crosswalk. Keep N02-04/05
    # source-present-but-unprojected until that source exists; do not infer W
    # from a different layer or from the later R69 candidate.
    ledger = G._up2_vnext_n04_05_context(case.package, binding)
    @test ledger.typed_ledger_context === nothing
    @test !ledger.n02_04_05_present
    for id in ("N02-04", "N02-05")
        spec = G.up2_spec_for_id(id)
        field = projected[id]
        state = only(filter(row -> row.field_id == id, input.field_states))
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === spec.source_type
        @test field.value isa G.UP2AbsentValueV1
        @test field.value.intended_type === spec.source_type
        @test field.value.reason === :field_projector_not_implemented
        @test state.state === :source_present_deferred
        @test state.reason === :pinned_layer_source_field_projector_absent
        @test state.source_pin_roles == (:g3_builder, :g3_child_design)
    end
    for role in (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source)
        bound_pin = only(filter(pin -> pin.role === role, binding.source_pins))
        source_pin = getproperty(case.source_pins, role)
        @test bound_pin.byte_count == source_pin.bytes
        @test bound_pin.sha256 == source_pin.sha256
    end
    @test g1.package_hash == binding.package_hash
    @test g2.package_hash == binding.package_hash
    nothing
end

@testset "UP2-00 R55 VNext T1 finite consumer stays design-only and deferred" begin
    case = _up2_vnext_t1_case(:r55)
    _up2_assert_g2_source_role_binding(case)
    result = case.build()
    @test result.status === :prepared_not_executed
    @test result.resolution === :terminal_deferred
    @test result.reason === :vnext_t1_50_row_input_prepared_deferred
    @test result.input isa G.UP2VNextPrecompilerInputV1
    input = result.input
    @test G.up2_validate_vnext_input(input)
    @test input.status === :prepared_not_executed
    @test input.resolution === :terminal_deferred
    @test input.claim_ceiling === :contract_only
    @test length(input.state.fields) == length(input.field_states) ==
        length(_up2_fixture_specs()) == G.up2_mutation_count() == 50
    @test Tuple(field.id for field in input.state.fields) ==
        Tuple(spec.id for spec in _up2_fixture_specs())
    _up2_assert_n01_n02_source_projection(case, input)

    binding = input.source_binding
    @test Tuple(pin.role for pin in binding.source_pins) ==
        (:g1_builder, :g1_declaration_source, :g2_builder,
         :g2_declaration_source, :g3_builder, :g3_child_design)
    @test binding.time_basis === :event
    @test binding.projection_status === :local_source_bound
    @test binding.projection_resolution === :terminal_deferred
    @test binding.authority_scope === :local_source_data
    @test binding.authority_gap == "candidate_authored_event_time_policy_is_design_only"
    @test binding.trigger === :initial
    @test binding.time == 0 // 1
    @test_throws ArgumentError G.UP2VNextSourceBindingV1(binding.candidate_ref,
        binding.candidate_id, binding.scenario_id, binding.snapshot_id,
        binding.manifest_sha256, binding.package_hash, binding.semantic_identity,
        binding.bundle_hash, binding.n03_projection_hash, binding.source_pins,
        binding.event_id, binding.trigger, binding.time, nothing,
        binding.projection_status, binding.projection_resolution, :cross_layer,
        "event_time_basis_not_authoritative")
    n03_trigger = only(filter(field -> field.id == "N03-04", input.state.fields))
    n03_time = only(filter(field -> field.id == "N03-05", input.state.fields))
    @test n03_trigger.value isa G.UP2SymbolValueV1
    @test n03_trigger.value.value === :initial
    @test n03_time.value isa G.UP2RationalValueV1
    @test n03_time.value.value == 0 // 1
    n03_states = filter(state -> state.field_id in ("N03-04", "N03-05"),
        input.field_states)
    @test all(state -> state.state === :source_present_deferred &&
        state.reason === :candidate_design_event_time_policy_design_only &&
        state.source_pin_roles == (:g3_builder, :g3_child_design), n03_states)

    n04_spec = G.up2_spec_for_id("N04-05")
    n04_field = only(filter(field -> field.id == "N04-05", input.state.fields))
    n04_state = only(filter(state -> state.field_id == "N04-05",
        input.field_states))
    @test n04_spec.field_path == "/g3/realization/network/entries/1/coefficient"
    @test n04_spec.source_locator ==
        "G3LedgerEntryV2.coefficient::Rational{Int64}"
    @test n04_spec.source_type === :rational
    @test n04_spec.mutation_kind === :pending
    @test n04_field.source_locator == n04_spec.source_locator
    @test n04_field.source_type === :rational
    @test n04_field.value isa G.UP2RationalValueV1
    @test n04_field.value.value isa Rational{Int64}
    @test n04_state.state === :source_present_deferred
    @test n04_state.reason === :candidate_design_ledger_capacity_design_only
    @test n04_state.source_pin_roles == (:g3_builder, :g3_child_design)
    n04_context = G._up2_vnext_n04_05_context(case.package, binding)
    g3_declaration = only(filter(d -> d.layer === :G3, case.package.declarations))
    g3_body = JSON3.read(String(G.copy_bytes(g3_declaration.semantic_body_bytes)))
    authored_realization = g3_body.authored_child_design.realization
    authored_entry = authored_realization.ledger_entries[2]
    authored_port = only(filter(x -> x.port_id == authored_entry.port_id,
        authored_realization.ports))
    authored_component = only(filter(x -> x.component_id == authored_entry.component_id,
        authored_realization.components))
    authored_account = only(filter(x -> x.account_id == authored_entry.account_id,
        authored_realization.ledger_accounts))
    n04_capacity = G._n03_vnext_time(authored_component.capacity)
    @test String(authored_entry.entry_id) == "field_allocation"
    @test String(authored_entry.effect) == "load"
    @test String(authored_port.role) == "field"
    @test String(authored_port.direction) == "in"
    @test String(authored_component.kind) == "passive_component"
    @test String(authored_account.domain) == "energy"
    @test n04_context.entry_id == String(authored_entry.entry_id)
    @test n04_context.account_id == String(authored_entry.account_id)
    @test n04_context.port_id == String(authored_entry.port_id)
    @test n04_context.component_id == String(authored_entry.component_id)
    @test n04_context.coefficient isa Rational{Int64}
    @test n04_context.coefficient == n04_field.value.value ==
        G._n03_vnext_time(authored_entry.coefficient)
    @test n04_context.capacity == n04_capacity
    @test n04_context.unit == G._up2_vnext_unit_signature(authored_entry.unit)
    @test n04_context.port_role === :field
    @test n04_context.port_direction === :in
    @test n04_context.authority_scope === :local_source_data
    @test n04_context.authority_gap ==
        "candidate_authored_g3_ledger_capacity_is_design_only"
    @test n04_context.package_hash == binding.package_hash
    @test n04_context.n03_projection_hash == binding.n03_projection_hash

    n04_closure_spec = G.up2_spec_for_id("N04-02")
    n04_closure_field = only(filter(field -> field.id == "N04-02",
        input.state.fields))
    n04_closure_state = only(filter(state -> state.field_id == "N04-02",
        input.field_states))
    @test n04_closure_spec.mutation_kind === :duplicate_account_ids
    @test n04_closure_field.value isa G.UP2TupleValueV1
    @test n04_closure_field.value.element_type === :string
    @test n04_closure_field.value.values == n04_context.closure_account_ids
    @test n04_closure_state.state === :source_present_deferred
    @test n04_closure_state.reason === :candidate_design_ledger_closure_design_only
    @test n04_closure_state.source_pin_roles == (:g3_builder, :g3_child_design)
    n04_closure_mutated = G._up2_mutated_input(input, n04_closure_spec;
        package=case.package)
    n04_closure_changed = only(filter(field -> field.id == "N04-02",
        n04_closure_mutated.state.fields))
    @test n04_closure_changed.value isa G.UP2TupleValueV1
    @test n04_closure_changed.value.values ==
        (first(n04_context.closure_account_ids), first(n04_context.closure_account_ids))
    n04_closure_counter = G.UP2InvocationCounterV1()
    n04_closure_result = G.up2_validate_mutation(input, n04_closure_spec;
        package=case.package, counter=n04_closure_counter)
    @test n04_closure_result.mutation_id == "N04-02"
    @test n04_closure_result.status === :fail_closed
    @test n04_closure_result.error_code === :invalid_closure
    @test n04_closure_result.error_path == n04_closure_spec.field_path
    @test n04_closure_result.detail == "duplicate_or_unresolved_closure_account"
    @test n04_closure_result.mutated_input_hash == n04_closure_mutated.input_hash
    @test n04_closure_result.compile_calls == n04_closure_counter.compile_calls == 0
    @test n04_closure_result.provider_calls == n04_closure_counter.provider_calls == 0
    @test n04_closure_result.solver_calls == n04_closure_counter.solver_calls == 0
    @test !n04_closure_result.evidence_reused

    n04_component_spec = G.up2_spec_for_id("N04-04")
    n04_component_field = only(filter(field -> field.id == "N04-04",
        input.state.fields))
    n04_component_state = only(filter(state -> state.field_id == "N04-04",
        input.field_states))
    @test n04_component_spec.mutation_kind === :pending
    @test n04_component_field.value isa G.UP2TextValueV1
    @test n04_component_field.value.value == n04_context.source_entry_component_id
    @test n04_component_state.state === :source_present_deferred
    @test n04_component_state.reason === :candidate_design_ledger_component_design_only
    @test n04_component_state.source_pin_roles == (:g3_builder, :g3_child_design)
    n04_component_mutated = G._up2_mutated_input(input, n04_component_spec;
        package=case.package)
    n04_component_changed = only(filter(field -> field.id == "N04-04",
        n04_component_mutated.state.fields))
    @test n04_component_changed.value isa G.UP2TextValueV1
    @test n04_component_changed.value.value == n04_context.passive_component_id
    @test n04_component_changed.value.value != n04_component_field.value.value
    n04_component_counter = G.UP2InvocationCounterV1()
    n04_component_result = G.up2_validate_mutation(input, n04_component_spec;
        package=case.package, counter=n04_component_counter)
    @test n04_component_result.mutation_id == "N04-04"
    @test n04_component_result.status === :fail_closed
    @test n04_component_result.error_code === :invalid_closure
    @test n04_component_result.error_path == n04_component_spec.field_path
    @test n04_component_result.detail == "passive_component_cannot_source"
    @test n04_component_result.mutated_input_hash == n04_component_mutated.input_hash
    @test n04_component_result.compile_calls == n04_component_counter.compile_calls == 0
    @test n04_component_result.provider_calls == n04_component_counter.provider_calls == 0
    @test n04_component_result.solver_calls == n04_component_counter.solver_calls == 0
    @test !n04_component_result.evidence_reused

    for deferred_id in ("N04-01", "N04-03")
        deferred_spec = G.up2_spec_for_id(deferred_id)
        deferred_field = only(filter(field -> field.id == deferred_id,
            input.state.fields))
        deferred_state = only(filter(state -> state.field_id == deferred_id,
            input.field_states))
        @test deferred_spec.mutation_kind ===
            (deferred_id == "N04-01" ? :owner_crosswalk_mismatch : :unknown_account_ref)
        @test deferred_field.value isa G.UP2AbsentValueV1
        @test deferred_state.state === :source_present_deferred
        @test deferred_state.reason === :pinned_layer_source_field_projector_absent
        @test deferred_state.source_pin_roles == (:g3_builder, :g3_child_design)
        @test_throws ArgumentError G.up2_validate_mutation(input, deferred_spec;
            package=case.package)
    end

    @test n04_field.value.value == -500 // 1
    @test n04_field.value.value < 0
    @test abs(n04_field.value.value) <= n04_capacity

    @test_throws ArgumentError G.up2_validate_mutation(input, n04_spec)
    n04_mutated_input = G._up2_mutated_input(input, n04_spec;
        package=case.package, n04_05_context=n04_context)
    n04_changed_field = only(filter(field -> field.id == "N04-05",
        n04_mutated_input.state.fields))
    @test n04_changed_field.value isa G.UP2RationalValueV1
    @test n04_changed_field.value.value == -(n04_capacity + 1 // 1)
    @test sign(n04_changed_field.value.value) == sign(n04_field.value.value)
    @test abs(n04_changed_field.value.value) > n04_capacity
    n04_counter = G.UP2InvocationCounterV1()
    n04_result = G.up2_validate_mutation(input, n04_spec;
        package=case.package, counter=n04_counter)
    @test n04_result.mutation_id == "N04-05"
    @test n04_result.status === :fail_closed
    @test n04_result.error_code === :invalid_closure
    @test n04_result.error_path == n04_spec.field_path
    @test n04_result.detail == "component_capacity_exceeded"
    @test n04_result.mutated_input_hash != input.input_hash
    @test n04_result.mutated_input_hash == n04_mutated_input.input_hash
    @test n04_result.compile_calls == n04_counter.compile_calls == 0
    @test n04_result.provider_calls == n04_counter.provider_calls == 0
    @test n04_result.solver_calls == n04_counter.solver_calls == 0
    @test !n04_result.evidence_reused

    n03_trigger_spec = G.up2_spec_for_id("N03-04")
    n03_trigger_counter = G.UP2InvocationCounterV1()
    n03_trigger_result = G.up2_validate_mutation(input, n03_trigger_spec;
        counter=n03_trigger_counter)
    @test n03_trigger_result.mutation_id == "N03-04"
    @test n03_trigger_result.status === :fail_closed
    @test n03_trigger_result.error_code === :invalid_type
    @test n03_trigger_result.error_path == n03_trigger_spec.field_path
    @test n03_trigger_result.detail ==
        "event_trigger_policy_mismatch: mutated G3 trigger differs from authored initial trigger"
    @test n03_trigger_result.mutated_input_hash != input.input_hash
    @test n03_trigger_result.compile_calls == n03_trigger_counter.compile_calls == 0
    @test n03_trigger_result.provider_calls == n03_trigger_counter.provider_calls == 0
    @test n03_trigger_result.solver_calls == n03_trigger_counter.solver_calls == 0
    @test !n03_trigger_result.evidence_reused

    n03_time_spec = G.up2_spec_for_id("N03-05")
    n03_time_counter = G.UP2InvocationCounterV1()
    n03_time_result = G.up2_validate_mutation(input, n03_time_spec;
        counter=n03_time_counter)
    @test n03_time_result.mutation_id == "N03-05"
    @test n03_time_result.status === :fail_closed
    @test n03_time_result.error_code === :invalid_type
    @test n03_time_result.error_path == n03_time_spec.field_path
    @test n03_time_result.detail ==
        "event_time_negative: mutated G3 event time must be nonnegative"
    @test n03_time_result.mutated_input_hash != input.input_hash
    @test n03_time_result.compile_calls == n03_time_counter.compile_calls == 0
    @test n03_time_result.provider_calls == n03_time_counter.provider_calls == 0
    @test n03_time_result.solver_calls == n03_time_counter.solver_calls == 0
    @test !n03_time_result.evidence_reused

    @test count(state -> state.state === :typed_absent, input.field_states) == 13
    @test count(state -> state.state === :source_present_deferred,
        input.field_states) == 37
    typed_absent_ids = Set(state.field_id for state in input.field_states
        if state.state === :typed_absent)
    expected_absent_ids = Set(("N05-01", "N05-02", "N06-02", "N06-04",
        (spec.id for spec in _up2_fixture_specs() if spec.class_id === :N09)...,
        "N07-04", "N08-01", "N08-04", "N08-05"))
    @test typed_absent_ids == expected_absent_ids
    n06_02_field = only(filter(x -> x.id == "N06-02", input.state.fields))
    n06_02_state = only(filter(x -> x.field_id == "N06-02", input.field_states))
    @test n06_02_field.value isa G.UP2AbsentValueV1
    @test n06_02_field.value.reason === :candidate_design_typed_ledger_entries_absent
    @test n06_02_state.state === :typed_absent &&
        n06_02_state.reason === :candidate_design_typed_ledger_entries_absent
    @test isempty(n06_02_state.source_pin_roles)
    pending = filter(spec -> !(spec.class_id in (:N01, :N02, :N07, :N08)) &&
        !(spec.id in ("N03-01", "N03-02", "N03-03", "N04-02")),
        _up2_fixture_specs())
    @test length(pending) == 26
    @test all(spec -> only(filter(state -> state.field_id == spec.id,
        input.field_states)).state in (:typed_absent, :source_present_deferred), pending)
    # Candidate-bound N03 event and N04-02/04/05 ledger mutations are
    # classified below; the registered 50-row matrix and other deferred rows stay intact.
    # This contract consumer cannot establish total UP2/B04 GO.

    missing_package = case.build(p=nothing)
    @test missing_package.status === :typed_absent
    @test missing_package.resolution === :terminal_deferred
    @test missing_package.reason === :candidate_scenario_package_or_source_pin_absent
    missing_pins = case.build(pins=nothing)
    @test missing_pins.status === :typed_absent
    @test missing_pins.resolution === :terminal_deferred
    @test missing_pins.reason === :candidate_scenario_package_or_source_pin_absent

    wrong_pin_set = merge(case.source_pins,
        (; g3_child_design=(bytes=case.source_pins.g3_child_design.bytes,
            sha256=G.Digest256(repeat("0", 64)))))
    wrong_pin = case.build(pins=wrong_pin_set)
    @test wrong_pin.status === :fail_closed
    @test wrong_pin.resolution === :none

    wrong_ref = G.QualifiedRefV1(
        "fusionconceptai://candidate-design/not-the-r55-candidate", "v5")
    wrong_identity = merge(case.identity, (; candidate_ref=wrong_ref))
    wrong_candidate = case.build(id=wrong_identity)
    @test wrong_candidate.status === :fail_closed
    @test wrong_candidate.resolution === :none
    @test wrong_candidate.input === nothing
    # Replay the same R55 T1 package under an unbound scenario identity.
    wrong_scenario = case.build(id=merge(case.identity,
        (; scenario_id="scenario-not-bound-to-r55")))
    @test wrong_scenario.status === :fail_closed
    @test wrong_scenario.resolution === :none
    @test wrong_scenario.input === nothing
end

@testset "UP2-00 R65 VNext G2MB projection remains source-bound and incomplete" begin
    case = _up2_vnext_t1_case(:r65)
    _up2_assert_g2_source_role_binding(case)
    result = case.build()
    @test result.status === :prepared_not_executed
    @test result.resolution === :terminal_deferred
    @test result.input isa G.UP2VNextPrecompilerInputV1
    input = result.input
    binding = input.source_binding
    @test G.up2_validate_vnext_input(input)
    @test input.status === :prepared_not_executed
    @test input.resolution === :terminal_deferred
    @test input.claim_ceiling === :contract_only
    @test length(input.state.fields) == length(input.field_states) ==
        length(_up2_fixture_specs()) == G.up2_mutation_count() == 50
    @test case.package.package_hash == binding.package_hash
    @test case.package.semantic_identity == binding.semantic_identity
    @test case.package.bundle_hash == binding.bundle_hash
    @test case.source_pins.g2_builder.sha256 == only(filter(pin ->
        pin.role === :g2_builder, binding.source_pins)).sha256
    _up2_assert_n01_n02_source_projection(case, input)

    geometry = G._up2_vnext_g2_geometry_context(case.package, binding)
    @test geometry.candidate_ref == case.candidate_ref
    @test geometry.package_hash == binding.package_hash
    @test geometry.semantic_identity == case.package.semantic_identity
    @test geometry.bundle_hash == case.package.bundle_hash
    @test geometry.declaration_hash isa G.Digest256
    @test geometry.projection_hash isa G.Digest256
    @test geometry.values == Dict{String,Any}(
        "N07-01" => (1 // 2, 1 // 3, 1 // 4),
        "N07-02" => (5 // 2, 10 // 3, 17 // 4),
        "N07-03" => (:x_max, :x_min, :y_max, :y_min, :z_max, :z_min),
        "N07-05" => :dirichlet,
        "N08-02" => :declared_map,
        "N08-03" => (2, 3, 4))
    @test geometry.absent_reasons == Dict{String,Symbol}(
        "N07-04" => :g2mb_source_has_no_boundary_patch,
        "N08-01" => :g2mb_chart_has_no_coordinate_axis_labels,
        "N08-04" => :g2mb_q1_basis_equivalence_not_frozen,
        "N08-05" => :g2mb_source_has_no_internal_interfaces)

    projected = Dict(field.id => field for field in input.state.fields)
    g2_present = ("N07-01", "N07-02", "N07-03", "N07-05", "N08-02", "N08-03")
    @test projected["N07-01"].value isa G.UP2TupleValueV1
    @test projected["N07-01"].value.values == geometry.values["N07-01"]
    @test projected["N07-01"].value.element_type === :rational
    @test projected["N07-02"].value.values == geometry.values["N07-02"]
    @test projected["N07-03"].value.values == geometry.values["N07-03"]
    @test projected["N07-03"].value.element_type === :symbol
    @test projected["N07-05"].value isa G.UP2SymbolValueV1
    @test projected["N07-05"].value.value === :dirichlet
    @test projected["N08-02"].value.value === :declared_map
    @test projected["N08-03"].value.values == (2, 3, 4)
    for id in g2_present
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test state.state === :source_present_deferred
        @test state.reason === :candidate_design_g2_geometry_contract_only
        @test state.source_pin_roles == (:g2_builder, :g2_declaration_source)
    end
    for (id, reason) in geometry.absent_reasons
        field = projected[id]
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test field.value isa G.UP2AbsentValueV1
        @test field.value.reason === reason
        @test state.state === :typed_absent
        @test state.reason === reason
        @test isempty(state.source_pin_roles)
    end
    @test count(state -> state.state === :typed_absent, input.field_states) == 13
    @test count(state -> state.state === :source_present_deferred,
        input.field_states) == 37
    @test Tuple(field.id for field in input.state.fields) ==
        Tuple(spec.id for spec in _up2_fixture_specs())

    # R65 has no explicit typed owner/account_ref source: do not backfill it
    # from a later candidate package or infer it from owner_scope/account text.
    for id in ("N04-01", "N04-03")
        spec = G.up2_spec_for_id(id)
        field = only(filter(x -> x.id == id, input.state.fields))
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test spec.mutation_kind ===
            (id == "N04-01" ? :owner_crosswalk_mismatch : :unknown_account_ref)
        @test field.value isa G.UP2AbsentValueV1
        @test state.state === :source_present_deferred
        @test state.reason === :pinned_layer_source_field_projector_absent
        @test state.source_pin_roles == (:g3_builder, :g3_child_design)
    end

    n06_02_field = only(filter(x -> x.id == "N06-02", input.state.fields))
    n06_02_state = only(filter(x -> x.field_id == "N06-02", input.field_states))
    @test n06_02_field.value isa G.UP2AbsentValueV1
    @test n06_02_field.value.reason === :candidate_design_typed_ledger_entries_absent
    @test n06_02_state.state === :typed_absent &&
        n06_02_state.reason === :candidate_design_typed_ledger_entries_absent
    @test isempty(n06_02_state.source_pin_roles)
    n06_04_field = only(filter(x -> x.id == "N06-04", input.state.fields))
    n06_04_state = only(filter(x -> x.field_id == "N06-04", input.field_states))
    @test n06_04_field.value isa G.UP2AbsentValueV1
    @test n06_04_field.value.reason === :candidate_design_typed_ledger_closure_absent
    @test n06_04_state.state === :typed_absent &&
        n06_04_state.reason === :candidate_design_typed_ledger_closure_absent
    @test isempty(n06_04_state.source_pin_roles)
    function g2_mutation_summary(candidate_package, candidate_input)
        Tuple(begin
            spec = G.up2_spec_for_id(id)
            counter = G.UP2InvocationCounterV1()
            mutation = G.up2_validate_mutation(candidate_input, spec;
                package=candidate_package, counter=counter)
            @test mutation.status === :fail_closed
            @test mutation.error_code === :invalid_boundary
            @test mutation.error_path == spec.field_path
            @test mutation.detail == spec.detail
            @test mutation.compile_calls == counter.compile_calls == 0
            @test mutation.provider_calls == counter.provider_calls == 0
            @test mutation.solver_calls == counter.solver_calls == 0
            @test !mutation.evidence_reused
            (id=id, error_code=String(mutation.error_code),
                mutated_input_hash=mutation.mutated_input_hash.value,
                result_hash=mutation.result_hash.value)
        end for id in g2_present)
    end
    geometry_mutations = g2_mutation_summary(case.package, input)

    # The R65 replay artifact was emitted by the independent T1 consumer process.
    # Rebind that serialized package through the same pinned source identities.
    replay_result = case.build(p=case.replay_package)
    @test replay_result.status === :prepared_not_executed
    @test replay_result.resolution === :terminal_deferred
    @test replay_result.input isa G.UP2VNextPrecompilerInputV1
    @test Tuple(G.semantic_view.(replay_result.input.state.fields)) ==
        Tuple(G.semantic_view.(input.state.fields))
    replay_geometry = G._up2_vnext_g2_geometry_context(case.replay_package,
        replay_result.input.source_binding)
    @test replay_geometry.projection_hash == geometry.projection_hash
    @test replay_geometry.values == geometry.values
    replay_geometry_mutations = g2_mutation_summary(case.replay_package,
        replay_result.input)
    @test replay_geometry_mutations == geometry_mutations
    absent_ids = Tuple(sort!(String[id for (id, _) in geometry.absent_reasons]))
    println("UP2_R65_G2_SUMMARY=" * G.canonical_json((
        package_hash=binding.package_hash.value,
        input_hash=input.input_hash.value,
        projection_hash=geometry.projection_hash.value,
        geometry_mutations=geometry_mutations,
        typed_absent_ids=absent_ids,
        replay_package_hash=replay_result.input.source_binding.package_hash.value,
        replay_input_hash=replay_result.input.input_hash.value,
        replay_projection_hash=replay_geometry.projection_hash.value,
        replay_geometry_mutations=replay_geometry_mutations)))

    with_binding(; candidate_ref=binding.candidate_ref,
            candidate_id=binding.candidate_id, package_hash=binding.package_hash,
            source_pins=binding.source_pins) = G.UP2VNextSourceBindingV1(
        candidate_ref, candidate_id, binding.scenario_id, binding.snapshot_id,
        binding.manifest_sha256, package_hash, binding.semantic_identity,
        binding.bundle_hash, binding.n03_projection_hash, source_pins,
        binding.event_id, binding.trigger, binding.time, binding.time_basis,
        binding.projection_status, binding.projection_resolution,
        binding.authority_scope, binding.authority_gap)
    @test_throws ArgumentError G._up2_vnext_g2_geometry_context(case.package,
        with_binding(package_hash=G.Digest256(repeat("0", 64))))
    foreign_ref = G.QualifiedRefV1(
        "fusionconceptai://candidate-design/not-the-r65-candidate", "v5")
    @test_throws ArgumentError G._up2_vnext_g2_geometry_context(case.package,
        with_binding(candidate_ref=foreign_ref,
            candidate_id="not-the-r65-candidate"))
    wrong_builder_pin = Tuple(pin.role === :g2_builder ?
        G.UP2VNextSourcePinV1(pin.role, pin.byte_count,
            G.Digest256(repeat("0", 64))) : pin for pin in binding.source_pins)
    @test_throws ArgumentError G._up2_vnext_g2_geometry_context(case.package,
        with_binding(source_pins=wrong_builder_pin))

    wrong_identity = merge(case.identity, (; candidate_ref=foreign_ref,
        candidate_id="not-the-r65-candidate"))
    wrong_candidate = case.build(id=wrong_identity)
    @test wrong_candidate.status === :fail_closed
    @test wrong_candidate.resolution === :none
    @test wrong_candidate.input === nothing
    wrong_pins = merge(case.source_pins,
        (; g2_builder=(bytes=case.source_pins.g2_builder.bytes,
            sha256=G.Digest256(repeat("0", 64)))))
    wrong_source = case.build(pins=wrong_pins)
    @test wrong_source.status === :fail_closed
    @test wrong_source.resolution === :none
    @test wrong_source.input === nothing

    @test_throws ArgumentError G.up2_validate_mutation(input,
        G.up2_spec_for_id("N08-05"); package=case.package)
    @test G._up2_vnext_g2_geometry_context(case.package, binding).absent_reasons[
        "N08-05"] === :g2mb_source_has_no_internal_interfaces
end

function _up2_r71_fresh_native_plan(case, source_binding)
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    @test Base.active_project() == joinpath(root, "tools", "qualification",
        "gridap", "Project.toml")
    if hasproperty(case, :current_source_root)
        plan_path = normpath(abspath(get(ENV, "UP2_CURRENT_SOURCE_NATIVE_PLAN",
            joinpath(root, "runs", "e", "up2_native_services_20261001_r20",
                "current_source_native_prepare_bounded", "native_plan.bin"))))
        result_path = joinpath(dirname(plan_path), "native_plan_result.json")
        result_bytes = read(result_path)
        result = JSON3.read(String(copy(result_bytes)))
        @test result.schema == "up1-native-current-source-gridap-plan-v1"
        @test result.plan_validation_state == "validated_plan"
        @test result.numerical_execution == "not_executed"
        @test result.accepted == false
        @test result.claim_ceiling == "contract_only"
        plan_bytes = read(plan_path)
        @test Int(result.artifact_bytes) == length(plan_bytes)
        @test bytes2hex(SHA.sha256(plan_bytes)) == String(result.artifact_sha256)
        loaded = _up2_r71_native_runtime(root)
        R = loaded.runtime
        plan = Serialization.deserialize(IOBuffer(plan_bytes))
        @test plan isa R.NativeG1G2GridapPlanV1
        @test R.validate_native_g1g2_gridap_plan_v1(plan)
        @test plan.plan_hash.value == String(result.plan_hash)
        form = plan.compilation.form
        @test form.candidate_ref == source_binding.candidate_ref == case.package.candidate_ref
        @test form.t1_package_hash == source_binding.package_hash == case.package.package_hash
        @test form.t1_semantic_identity == source_binding.semantic_identity ==
            case.package.semantic_identity
        @test form.t0_bundle_hash == source_binding.bundle_hash == case.package.bundle_hash
        @test String(result.candidate_ref_id) == source_binding.candidate_ref.id
        @test String(result.package_hash) == source_binding.package_hash.value
        @test String(result.semantic_identity) == source_binding.semantic_identity.value
        @test String(result.bundle_hash) == source_binding.bundle_hash.value
        @test plan.dependency_identity.project_sha256.value ==
            bytes2hex(SHA.sha256(read(joinpath(root, "tools", "qualification",
                "gridap", "Project.toml"))))
        @test plan.dependency_identity.manifest_sha256.value ==
            bytes2hex(SHA.sha256(read(joinpath(root, "tools", "qualification",
                "gridap", "Manifest.toml"))))
        protocol = plan.protocol
        @test Tuple(Tuple(Int(x) for x in row) for row in
            result.three_level_protocol.cell_counts) == protocol.cell_counts
        @test Int(result.three_level_protocol.quadrature_degree) ==
            protocol.quadrature_degree
        @test String(result.three_level_protocol.protocol_hash) ==
            protocol.protocol_hash.value
        admission = R.native_g1g2_gridap_plan_admission_v1(plan)
        @test admission !== nothing
        @test R.validate_native_g1g2_gridap_plan_admission_v1(plan, admission)
        return plan
    end
    run_dir = joinpath(root, "runs", "e",
        "up1_up4_r2_candidate_actual_20261001_r71")
    prepare_path = joinpath(run_dir, "gridap_prepare_o0.json")
    phase_a_path = joinpath(run_dir, "native_phase_a_o0.json")
    compile_path = joinpath(run_dir, "native_compile_o0.bin")
    prepare = JSON3.read(String(copy(read(prepare_path))))
    phase_a_bytes = read(phase_a_path)
    @test prepare.schema == "up1-native-g1g2-gridap-handoff-v1"
    @test prepare.phase == "gridap_prepare"
    @test bytes2hex(SHA.sha256(phase_a_bytes)) ==
        String(prepare.phase_a_receipt_sha256)
    phase_a = JSON3.read(String(copy(phase_a_bytes)))
    @test phase_a.schema == "up1-native-g1g2-compile-artifact-v1"
    @test phase_a.snapshot_id == prepare.snapshot_id
    @test phase_a.manifest_sha256 == prepare.manifest_sha256
    @test phase_a.candidate_ref_id == source_binding.candidate_ref.id
    @test phase_a.scenario_id == source_binding.scenario_id
    @test phase_a.package_hash == source_binding.package_hash.value
    @test phase_a.package_semantic_identity ==
        source_binding.semantic_identity.value
    @test phase_a.package_bundle_hash == source_binding.bundle_hash.value

    native_source = joinpath(root, "src", "RuntimeV4",
        "NativeG1G2DiffusionCompilerV1.jl")
    qualification_project = joinpath(root, "tools", "qualification", "gridap",
        "Project.toml")
    qualification_manifest = joinpath(root, "tools", "qualification", "gridap",
        "Manifest.toml")
    native_source_sha = bytes2hex(SHA.sha256(read(native_source)))
    @test native_source_sha == String(phase_a.compiler_source_hash) ==
        String(phase_a.compiler_source_entry_sha256)
    @test bytes2hex(SHA.sha256(read(qualification_project))) ==
        String(prepare.qualification_project_sha256)
    @test bytes2hex(SHA.sha256(read(qualification_manifest))) ==
        String(prepare.qualification_manifest_sha256)

    compile_bytes = read(compile_path)
    compile_sha = bytes2hex(SHA.sha256(compile_bytes))
    @test length(compile_bytes) == Int(phase_a.compilation_artifact_bytes)
    @test compile_sha == String(phase_a.compilation_artifact_sha256) ==
        String(prepare.compilation_artifact_sha256)
    @test String(prepare.compiler_result_hash) ==
        String(phase_a.compiler_result_hash)

    loaded = _up2_r71_native_runtime(root)
    R = loaded.runtime
    @test bytes2hex(SHA.sha256(read(loaded.qualification_project))) ==
        String(prepare.qualification_project_sha256)
    @test bytes2hex(SHA.sha256(read(loaded.qualification_manifest))) ==
        String(prepare.qualification_manifest_sha256)
    @test R.native_g1g2_diffusion_compiler_source_hash_v1().value ==
        native_source_sha

    compile_result = Serialization.deserialize(IOBuffer(compile_bytes))
    @test compile_result isa R.NativeG1G2DiffusionCompileResultV1
    @test compile_result.status === :compiled_numerical_preparation
    @test compile_result.resolution === :terminal_deferred
    @test !compile_result.accepted
    @test compile_result.claim_ceiling === :contract_only
    @test compile_result.result_hash.value == String(phase_a.compiler_result_hash)
    compilation = compile_result.compilation
    @test compilation isa R.NativeG1G2DiffusionCompilationV1
    form = compilation.form
    @test form.candidate_ref == source_binding.candidate_ref == case.package.candidate_ref
    @test form.t1_package_hash == source_binding.package_hash == case.package.package_hash
    @test form.t1_semantic_identity == source_binding.semantic_identity ==
        case.package.semantic_identity
    @test form.t0_bundle_hash == source_binding.bundle_hash == case.package.bundle_hash
    g1_manifest = only(filter(d -> d.layer === :G1,
        case.package.declarations))
    g2_manifest = only(filter(d -> d.layer === :G2,
        case.package.declarations))
    @test Vector{UInt8}(codeunits(G.canonical_json(form.g1_declaration))) ==
        Vector{UInt8}(G.copy_bytes(g1_manifest.declaration_bytes))
    @test Vector{UInt8}(codeunits(G.canonical_json(form.g2_declaration))) ==
        Vector{UInt8}(G.copy_bytes(g2_manifest.declaration_bytes))
    @test g1_manifest.declaration_identity_hash == G.canonical_hash((
        kind=:declaration, ref=g1_manifest.declaration_ref,
        bytes_sha256=g1_manifest.declaration_bytes.sha256))
    @test g2_manifest.declaration_identity_hash == G.canonical_hash((
        kind=:declaration, ref=g2_manifest.declaration_ref,
        bytes_sha256=g2_manifest.declaration_bytes.sha256))
    @test isempty(R._ng12_t1_package_binding_errors(case.package,
        form.g1_declaration, form.g2_declaration))

    protocol = R.native_g1g2_numerical_protocol_v1()
    plan = R.prepare_gridap_native_g1g2_diffusion_v1(compile_result, protocol)
    @test plan.dependency_identity.project_sha256.value ==
        String(prepare.qualification_project_sha256)
    @test plan.dependency_identity.manifest_sha256.value ==
        String(prepare.qualification_manifest_sha256)
    @test R._ng12_validate_compilation_with_admission_v1(compilation)
    @test R.validate_native_g1g2_gridap_plan_v1(plan)
    @test plan.plan_hash.value != String(prepare.plan_hash)
    admission = R.native_g1g2_gridap_plan_admission_v1(plan)
    @test admission !== nothing
    @test R.validate_native_g1g2_gridap_plan_admission_v1(plan, admission)
    @test plan.compilation.form.t1_package_hash == case.package.package_hash
    @test plan.compilation.form.candidate_ref == case.package.candidate_ref
    return plan
end

Base.@noinline Base.@nospecializeinfer function _up2_assert_current_source_label_invariance(case, input, base_result;
        native_plan=nothing, native_report=nothing, heat_lift_receipt=nothing)
    Base.@nospecialize case input base_result native_plan native_report heat_lift_receipt
    helper_stage_started = time_ns()
    G.load_genome_v5_up2_components!()
    G.load_vnext_t2_components_v2!()
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    built = G._vnext_current_source_candidate_records_v1(root,
        case.candidate_directory)
    records = G._vnext_current_source_records_v1(built)
    old_declarations = records.declarations
    @test Tuple(d.layer for d in old_declarations) == (:G1, :G2, :G3)
    authored_labels = old_declarations[1].semantic_body.labels
    geometry_labels = old_declarations[2].semantic_body.labels
    feedback_labels = old_declarations[3].semantic_body.labels
    @test authored_labels == (:up4_r2_authored_input_bytes,
        :up4_r2_expression_input_bytes)
    @test geometry_labels == (:up4_r2_authored_input_bytes,)
    @test feedback_labels == (:up4_r2_g3_feedback_input_bytes,
        :up4_r2_g3_child_design_input_bytes)

    # Four display-label classes change; body values and exact byte carriers stay put.
    changed_labels = ((:f3_current_authored_input, :f3_current_expression_input),
        (:f3_current_authored_input,),
        (:f3_current_feedback_input, :f3_current_child_design_input))
    changed_declarations = ntuple(i -> begin
        old = old_declarations[i]
        semantic = G.VNextT0LocalSemanticBodyV1(old.semantic_body.body,
            old.semantic_body.bytes, changed_labels[i])
        @test semantic.body === old.semantic_body.body
        @test semantic.bytes === old.semantic_body.bytes
        @test semantic.labels == changed_labels[i]
        @test G.canonical_json(G.semantic_view(semantic)) ==
            G.canonical_json(G.semantic_view(old.semantic_body))
        G.VNextT0LocalPresentDeclarationV1(old.layer, old.candidate_ref,
            old.source_ref, old.declaration_ref, old.source_identity_hash,
            old.declaration_identity_hash, old.axes, old.source_bytes,
            old.declaration_bytes, semantic, old.source_locator,
            old.factory_receipt, old.declaration_receipt)
    end, 3)
    changed_records = merge(records, (declarations=changed_declarations,
        g3_record=changed_declarations[3]))

    original_t0 = G.vnext_declaration_transport_local_v1(records.candidate,
        old_declarations, records.children, records.feedback;
        frozen_context=built.root)
    changed_t0 = G.vnext_declaration_transport_local_v1(records.candidate,
        changed_declarations, records.children, records.feedback;
        frozen_context=built.root)
    @test original_t0.status === :valid
    @test changed_t0.status === :valid
    (original_t0.status === :valid && changed_t0.status === :valid) || return nothing
    @test G.canonical_json(G.semantic_view(changed_t0.transport)) ==
        G.canonical_json(G.semantic_view(original_t0.transport))
    @test changed_t0.transport.bundle_hash == original_t0.transport.bundle_hash ==
        case.package.bundle_hash

    independent = G._vnext_current_source_independent_g3_inputs_v1(built,
        changed_records, changed_t0.transport)
    continued = G._vnext_current_source_continue_v1(records.candidate,
        changed_t0, built.root, independent.expected,
        independent.realization_state, independent.control_payload,
        independent.control_state, independent.binding_key;
        initial_links=independent.initial_links,
        g3_factory_invocation=built.g3_factory_invocation)
    @test continued.status === :prepared_not_executed
    @test continued.t1 isa G.VNextT1AdmissionResultV2
    continued.t1 isa G.VNextT1AdmissionResultV2 || return nothing
    changed_t1_package = continued.t1.package
    @test changed_t1_package isa G.CandidateStatePackageV5NextV2
    @test G.canonical_json(G._vnext_t1_v2_package_manifest(changed_t1_package)) ==
        G.canonical_json(G._vnext_t1_v2_package_manifest(case.package))
    @test changed_t1_package.package_hash == case.package.package_hash
    @test changed_t1_package.semantic_identity == case.package.semantic_identity
    @test changed_t1_package.bundle_hash == case.package.bundle_hash

    println("UP2_R71_STAGE=label_changed_identity_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    changed_identity = G._vnext_current_v5_identity_package_v1(built,
        changed_records, continued.witness, changed_t0.transport)
    println("UP2_R71_STAGE=label_changed_identity_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test changed_identity isa G.CandidateStatePackageV5
    println("UP2_R71_STAGE=label_changed_identity_wire_compare_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G.canonical_json(G.semantic_view(changed_identity)) ==
        G.canonical_json(G.semantic_view(case.identity_package))
    println("UP2_R71_STAGE=label_changed_identity_wire_compare_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test changed_identity.candidate_hash == case.identity_package.candidate_hash
    @test changed_identity.migration_receipt.candidate_identity_after ==
        case.identity_package.migration_receipt.candidate_identity_after

    println("UP2_R71_STAGE=label_changed_result_build_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    changed_result = case.build(p=changed_t1_package,
        native_plan=native_plan, native_report=native_report,
        heat_lift_receipt=heat_lift_receipt, identity_package=changed_identity)
    println("UP2_R71_STAGE=label_changed_result_build_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test changed_result.status == base_result.status
    @test changed_result.resolution == base_result.resolution
    @test changed_result.reason == base_result.reason
    @test changed_result.input isa G.UP2VNextPrecompilerInputV1
    changed_input = changed_result.input
    changed_input isa G.UP2VNextPrecompilerInputV1 || return nothing
    println("UP2_R71_STAGE=label_changed_input_wire_compare_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G.canonical_json(G.semantic_view(changed_input)) ==
        G.canonical_json(G.semantic_view(input))
    println("UP2_R71_STAGE=label_changed_input_wire_compare_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test changed_input.input_hash == input.input_hash
    @test G.canonical_json(changed_input.provider_bindings) ==
        G.canonical_json(input.provider_bindings)
    @test G.up2_validate_input(changed_input; package=changed_t1_package,
        native_plan=native_plan, native_report=native_report,
        heat_lift_receipt=heat_lift_receipt,
        identity_package=changed_identity) === true

    snapshot(t1, identity, consumer_result, consumer_input, t0) = (
        t0_transport=G.canonical_json(G.semantic_view(t0.transport)),
        t1_package=G.canonical_json(G._vnext_t1_v2_package_manifest(t1)),
        v5_identity_package=G.canonical_json(G.semantic_view(identity)),
        component_identity=G.canonical_json(identity.component_identity),
        input=G.canonical_json(G.semantic_view(consumer_input)),
        provider_bindings=G.canonical_json(consumer_input.provider_bindings),
        applicability=(g1=G.canonical_json(G.semantic_view(identity.g1.admission)),
            g2=G.canonical_json(G.semantic_view(identity.g2.admission)),
            g3=G.canonical_json(G.semantic_view(identity.g3.admission))),
        decision=(status=consumer_result.status,
            resolution=consumer_result.resolution, reason=consumer_result.reason,
            input_status=consumer_input.status,
            input_resolution=consumer_input.resolution,
            package_claim_ceiling=t1.claim_ceiling,
            identity_claim_ceiling=identity.claim_ceiling,
            input_claim_ceiling=consumer_input.claim_ceiling))
    println("UP2_R71_STAGE=label_before_snapshot_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    before = snapshot(case.package, case.identity_package, base_result, input,
        original_t0)
    println("UP2_R71_STAGE=label_before_snapshot_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    println("UP2_R71_STAGE=label_after_snapshot_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    after = snapshot(changed_t1_package, changed_identity, changed_result,
        changed_input, changed_t0)
    println("UP2_R71_STAGE=label_after_snapshot_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    println("UP2_R71_STAGE=label_snapshot_final_compare_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G.canonical_json(before) == G.canonical_json(after)
    println("UP2_R71_STAGE=label_snapshot_final_compare_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)

    g1_projection = case.identity_package.component_identity.g1_source_projection
    g2_projection = case.identity_package.component_identity.g2_source_projection
    g3_payload = case.identity_package.g3.authored_payload
    binding = input.source_binding
    (; schema="b00-f3-label-invariance-v1",
        candidate_binding=(candidate_ref=binding.candidate_ref,
            candidate_version=binding.candidate_ref.version,
            candidate_id=binding.candidate_id, scenario_id=binding.scenario_id,
            snapshot_id=binding.snapshot_id,
            manifest_sha256=binding.manifest_sha256.value,
            t1_package_hash=binding.package_hash.value,
            t1_semantic_identity=binding.semantic_identity.value,
            t0_bundle_hash=binding.bundle_hash.value,
            v5_identity_hash=case.identity_package.candidate_hash.value,
            v5_identity_after=case.identity_package.migration_receipt.candidate_identity_after,
            g3_upstream_commitment=case.upstream_receipts.g3_commitment_hash,
            g1_projection_hash=g1_projection.source_projection_hash.value,
            g2_projection_hash=g2_projection.projection_hash.value,
            g3_source_proof_hash=G.canonical_hash(g3_payload.source_proof).value,
            g3_child_source_sha256=g3_payload.source_sha256.value,
            g3_network_semantic_hash=G.canonical_hash(G.semantic_view(g3_payload.network)).value,
            source_binding_hash=binding.binding_hash.value,
            source_pins=G.canonical_json(binding.source_pins)),
        f3cases=((case_id="current-source-four-label-classes",
            changed_labels=(g1=changed_labels[1], g2=changed_labels[2],
                g3=changed_labels[3]), before=before, after=after),))
end

function _up2_assert_current_source_f4_consumer(case, input;
        native_plan, native_report, heat_lift_receipt, f4_result=nothing)
    Base.invokelatest(_up2_assert_current_source_f4_consumer_positional_impl,
        case, input, native_plan, native_report, heat_lift_receipt, f4_result)
end

Base.@noinline Base.@nospecializeinfer function _up2_assert_current_source_f4_consumer_positional_impl(
        case, input, native_plan, native_report, heat_lift_receipt, f4_result)
    Base.@nospecialize case input native_plan native_report heat_lift_receipt f4_result
    f4_helper_started = time_ns()
    println("UP2_R71_STAGE=f4_consumer_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    G.load_genome_v5_up2_components!()
    G.load_vnext_t2_components_v2!()
    binding = input.source_binding
    f4 = f4_result === nothing ?
        G._up2_vnext_candidate_provider_registry_v1(input, case.package;
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package) : f4_result
    registry = f4.registry
    @test registry.schema == "up1-04b-candidate-owned-provider-registry-v1"
    @test registry.version == "v1"
    @test registry.design_scope === :candidate_design_only
    @test registry.status === :unique_match
    @test registry.resolution === :contract_only
    @test registry.claim_ceiling === :contract_only
    @test !registry.emits_evidence && !registry.execution_authority &&
        !registry.terminal_authority
    @test Tuple(route.selection_id for route in registry.routes) ==
        ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
    @test Tuple(route.service for route in registry.routes) ==
        (:native_g1g2_gridap_grad, :native_g1g2_gridap_chart_mesh,
         :native_g1g2_gridap_exterior_boundary,
         :native_g1g2_gridap_scalar_heat_lift,
         :engineering_control_fault_operational_screen)
    provider_unique_match = getfield(G._up2_vnext_n09_runtime(), :unique_match)
    @test all(route -> route.match_status === provider_unique_match &&
        route.provider_code_hash isa G.Digest256 &&
        route.manifest_hash isa G.Digest256, registry.routes)
    provider_root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    @test all(route -> begin
        provider_path = normpath(joinpath(provider_root,
            split(route.provider_source_path, '/')...))
        isfile(provider_path) && route.provider_code_hash ==
            G.Digest256(bytes2hex(SHA.sha256(read(provider_path))))
    end, registry.routes)
    @test registry.identity.candidate_ref == binding.candidate_ref
    @test registry.identity.candidate_id == binding.candidate_id
    @test registry.identity.scenario_id == binding.scenario_id
    @test registry.identity.source_binding_hash == binding.binding_hash
    @test registry.identity.t1_package_hash == binding.package_hash
    @test registry.identity.native_plan_hash == native_plan.plan_hash
    @test registry.identity.g3_child_source_hash ==
        only(pin for pin in binding.source_pins if pin.role === :g3_child_design).sha256
    ecf = f4.ecf_compatibility
    if hasproperty(case.manifest, :g3_child_factory)
        selection = case.manifest.g3_child_factory
        @test selection.schema == "up4-g3-child-factory-invocation-v1"
        @test selection.entrypoint == "up4_r2_g3_child_design_source_v1"
        @test String(selection.candidate_id) == binding.candidate_id
        @test String(selection.scenario_id) == binding.scenario_id
        @test String(selection.source_path) ==
            case.candidate_directory * "/g3_child_design_source.jl"
        @test selection.re_enable_threshold_kelvin == 325
        @test ecf.schema == "up2-vnext-n09-g3-ecf-screen-input-v1"
        @test ecf.candidate_ref == binding.candidate_ref
        @test ecf.candidate_id == binding.candidate_id
        @test ecf.scenario_id == binding.scenario_id
        @test ecf.t1_package_hash == binding.package_hash
        @test ecf.t1_semantic_identity == binding.semantic_identity
        @test ecf.t0_bundle_hash == binding.bundle_hash
        @test ecf.source_pin_sha256 == registry.identity.g3_child_source_hash
        @test ecf.claim_ceiling === getfield(Main.FusionRuntimeV4, :screen_only)
        @test !ecf.engineering_evidence && !ecf.physical_evidence && !ecf.terminal_authority
        ecf_body = Base.structdiff(ecf, NamedTuple{(:input_hash,)}((ecf.input_hash,)))
        @test ecf.input_hash == G.canonical_hash(ecf_body)
    else
        @test ecf.status === :typed_absent
        @test ecf.reason === :no_current_v5_source_bound_ecf_input
        @test ecf.candidate_ref == binding.candidate_ref
        @test ecf.t1_package_hash == binding.package_hash
        @test ecf.source_pin_sha256 == registry.identity.g3_child_source_hash
    end

    wrong_ref = G.QualifiedRefV1(
        "fusionconceptai://candidate-design/f4_wrong_candidate", "v5")
    wrong_binding = G.UP2VNextSourceBindingV1(wrong_ref,
        "f4_wrong_candidate", binding.scenario_id, binding.snapshot_id,
        binding.manifest_sha256, binding.package_hash, binding.semantic_identity,
        binding.bundle_hash, binding.n03_projection_hash, binding.source_pins,
        binding.event_id, binding.trigger, binding.time, binding.time_basis,
        binding.projection_status, binding.projection_resolution,
        binding.authority_scope, binding.authority_gap)
    wrong_input = G.UP2VNextPrecompilerInputV1(wrong_binding,
        input.mission_bounds, input.state, input.field_states;
        provider_bindings=input.provider_bindings)
    f4_negative_started = time_ns()
    println("UP2_R71_STAGE=f4_wrong_candidate_registry_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    wrong_candidate_error = try
        G._up2_vnext_candidate_provider_registry_v1(wrong_input, case.package;
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        nothing
    catch err
        err
    end
    println("UP2_R71_STAGE=f4_wrong_candidate_registry_end elapsed_ms=",
        (time_ns() - f4_negative_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test wrong_candidate_error isa ArgumentError
    @test wrong_candidate_error.msg ==
        "F4 T1 package differs from its validated source binding"

    stale_hash = G.Digest256(repeat("0", 64))
    stale_hash == binding.package_hash && (stale_hash = G.Digest256(repeat("1", 64)))
    stale_binding = G.UP2VNextSourceBindingV1(binding.candidate_ref,
        binding.candidate_id, binding.scenario_id, binding.snapshot_id,
        binding.manifest_sha256, stale_hash, binding.semantic_identity,
        binding.bundle_hash, binding.n03_projection_hash, binding.source_pins,
        binding.event_id, binding.trigger, binding.time, binding.time_basis,
        binding.projection_status, binding.projection_resolution,
        binding.authority_scope, binding.authority_gap)
    stale_input = G.UP2VNextPrecompilerInputV1(stale_binding,
        input.mission_bounds, input.state, input.field_states;
        provider_bindings=input.provider_bindings)
    f4_negative_started = time_ns()
    println("UP2_R71_STAGE=f4_stale_binding_registry_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    stale_binding_error = try
        G._up2_vnext_candidate_provider_registry_v1(stale_input, case.package;
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        nothing
    catch err
        err
    end
    println("UP2_R71_STAGE=f4_stale_binding_registry_end elapsed_ms=",
        (time_ns() - f4_negative_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test stale_binding_error isa ArgumentError
    @test stale_binding_error.msg ==
        "F4 T1 package differs from its validated source binding"

    altered_first_route = merge(first(input.provider_bindings),
        (status=:provider_summary_tampered,))
    altered_provider_summary = (altered_first_route,
        Base.tail(input.provider_bindings)...)
    altered_input = G.UP2VNextPrecompilerInputV1(binding,
        input.mission_bounds, input.state, input.field_states;
        provider_bindings=altered_provider_summary)
    f4_negative_started = time_ns()
    println("UP2_R71_STAGE=f4_altered_summary_registry_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    provider_summary_error = try
        G._up2_vnext_candidate_provider_registry_v1(altered_input, case.package;
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        nothing
    catch err
        err
    end
    println("UP2_R71_STAGE=f4_altered_summary_registry_end elapsed_ms=",
        (time_ns() - f4_negative_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test provider_summary_error isa ArgumentError
    @test provider_summary_error.msg ==
        "F4 input provider bindings differ from freshly rebuilt current N09 routes"

    malformed_first_route = merge(first(input.provider_bindings),
        (obligation_hash="malformed-obligation-hash",))
    malformed_summary_input = G.UP2VNextPrecompilerInputV1(binding,
        input.mission_bounds, input.state, input.field_states;
        provider_bindings=(malformed_first_route,
            Base.tail(input.provider_bindings)...))
    f4_negative_started = time_ns()
    println("UP2_R71_STAGE=f4_malformed_summary_registry_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    malformed_summary_error = try
        G._up2_vnext_candidate_provider_registry_v1(malformed_summary_input,
            case.package; native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        nothing
    catch err
        err
    end
    println("UP2_R71_STAGE=f4_malformed_summary_registry_end elapsed_ms=",
        (time_ns() - f4_negative_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test malformed_summary_error isa ArgumentError
    @test malformed_summary_error.msg ==
        "F4 input provider bindings differ from freshly rebuilt current N09 routes"

    missing_provider_bindings_input = G.UP2VNextPrecompilerInputV1(binding,
        input.mission_bounds, input.state, input.field_states;
        provider_bindings=Base.tail(input.provider_bindings))
    f4_negative_started = time_ns()
    println("UP2_R71_STAGE=f4_missing_bindings_registry_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    missing_provider_bindings_error = try
        G._up2_vnext_candidate_provider_registry_v1(missing_provider_bindings_input,
            case.package; native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        nothing
    catch err
        err
    end
    println("UP2_R71_STAGE=f4_missing_bindings_registry_end elapsed_ms=",
        (time_ns() - f4_negative_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test missing_provider_bindings_error isa ArgumentError
    @test missing_provider_bindings_error.msg ==
        "F4 input provider bindings differ from freshly rebuilt current N09 routes"

    wildcard_first_binding = merge(first(input.provider_bindings),
        (field_id="*",))
    wildcard_provider_bindings_input = G.UP2VNextPrecompilerInputV1(binding,
        input.mission_bounds, input.state, input.field_states;
        provider_bindings=(wildcard_first_binding, Base.tail(input.provider_bindings)...))
    f4_negative_started = time_ns()
    println("UP2_R71_STAGE=f4_wildcard_bindings_registry_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    wildcard_provider_bindings_error = try
        G._up2_vnext_candidate_provider_registry_v1(wildcard_provider_bindings_input,
            case.package; native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        nothing
    catch err
        err
    end
    println("UP2_R71_STAGE=f4_wildcard_bindings_registry_end elapsed_ms=",
        (time_ns() - f4_negative_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test wildcard_provider_bindings_error isa ArgumentError
    @test wildcard_provider_bindings_error.msg ==
        "F4 input provider bindings differ from freshly rebuilt current N09 routes"

        source_context = G._up2_vnext_n04_05_context(case.package, binding;
            include_child_design=true, identity_package=case.identity_package)
        source_child = source_context.rebuilt_child_design
        source_typed = source_context.typed_ledger_context
        selection_context = G._up2_vnext_current_source_selection_v1(source_child,
            binding, source_typed)
        @test selection_context.declaration == source_child.provider_route_selection
        @test Tuple(x.selection_id for x in selection_context.selections) ==
            ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
        @test selection_context.child_pin.sha256 == registry.identity.g3_child_source_hash

        function capture_selection(case_id, child)
            try
                G._up2_vnext_current_source_selection_v1(child, binding, source_typed)
                (case_id=case_id, exception_type=nothing, message=nothing)
            catch err
                (case_id=case_id, exception_type=string(nameof(typeof(err))),
                    message=sprint(showerror, err))
            end
        end
        child_without_selection = Base.structdiff(source_child,
            NamedTuple{(:provider_route_selection,)}((source_child.provider_route_selection,)))
        missing_selection = capture_selection("selection_missing", child_without_selection)
        bad_metadata_declaration = merge(source_child.provider_route_selection,
            (candidate_id="foreign-candidate",))
        bad_metadata_child = merge(source_child,
            (provider_route_selection=bad_metadata_declaration,))
        bad_metadata = capture_selection("selection_metadata_candidate_mismatch",
            bad_metadata_child)
        declaration = source_child.provider_route_selection
        missing_row_declaration = merge(declaration,
            (selections=declaration.selections[1:end-1],))
        missing_row_child = merge(source_child,
            (provider_route_selection=missing_row_declaration,))
        missing_row = capture_selection("selection_row_missing", missing_row_child)
        wildcard_rows = (merge(first(declaration.selections), (selection_id="*",)),
            Base.tail(declaration.selections)...)
        wildcard_declaration = merge(declaration, (selections=wildcard_rows,))
        wildcard_child = merge(source_child,
            (provider_route_selection=wildcard_declaration,))
        wildcard_row = capture_selection("selection_wildcard_row", wildcard_child)
        @test missing_selection.exception_type == "ArgumentError"
        @test missing_selection.message ==
            "ArgumentError: F4 candidate provider selection is absent from the rebuilt pinned G3 source"
        @test bad_metadata.exception_type == "ArgumentError"
        @test bad_metadata.message ==
            "ArgumentError: F4 provider selection differs from rebuilt T1 G3 source identity"
        bad_schema_declaration = merge(source_child.provider_route_selection,
            (schema="tampered-selection-schema",))
        bad_schema_child = merge(source_child,
            (provider_route_selection=bad_schema_declaration,))
        bad_schema = capture_selection("selection_schema_mismatch", bad_schema_child)
        @test bad_schema.exception_type == "ArgumentError"
        @test bad_schema.message ==
            "ArgumentError: F4 provider selection differs from rebuilt T1 G3 source identity"
        @test missing_row.exception_type == "ArgumentError"
        @test missing_row.message ==
            "ArgumentError: F4 candidate provider selection is not the fixed current N09 route set"
        @test wildcard_row.exception_type == "ArgumentError"
        @test wildcard_row.message ==
            "ArgumentError: F4 candidate provider selection is not the fixed current N09 route set"

        runtime = selection_context.runtime
        match_summary(result) = (status=string(result.status),
            provider=result.provider === nothing ? nothing :
                (backend=result.provider.backend,
                 manifest_hash=result.provider.manifest_hash.value),
            reason=result.reason)
        function route_match_outcomes(route)
            capability = route.capability
            provider = route.manifest
            unique_result = Base.invokelatest(getfield(runtime, :match_provider),
                capability, (provider,))
            changed_kind = Base.invokelatest(getfield(runtime, :CapabilitySignatureV4),
                capability.schema, capability.revision,
                Symbol(string(capability.kind) * "_f4_no_match"),
                capability.operator, capability.states, capability.source_space,
                capability.target_space, capability.dimension, capability.coordinates,
                capability.boundary_relation, capability.interface_relation,
                capability.time_semantics, capability.required_output,
                capability.evidence_level, capability.applicability_bounds;
                input_schema_hash=capability.input_schema_hash,
                coordinate_system=capability.coordinate_system)
            no_match_result = Base.invokelatest(getfield(runtime, :match_provider),
                changed_kind, (provider,))
            changed_domain = Base.invokelatest(getfield(runtime, :CapabilitySignatureV4),
                capability.schema, capability.revision, capability.kind,
                capability.operator,
                capability.states, capability.source_space * "_f4_out_of_domain",
                capability.target_space, capability.dimension, capability.coordinates,
                capability.boundary_relation, capability.interface_relation,
                capability.time_semantics, capability.required_output,
                capability.evidence_level, capability.applicability_bounds;
                input_schema_hash=capability.input_schema_hash,
                coordinate_system=capability.coordinate_system)
            out_of_domain_result = Base.invokelatest(getfield(runtime, :match_provider),
                changed_domain, (provider,))
            ambiguous_result = Base.invokelatest(getfield(runtime, :match_provider),
                capability, (provider, provider))
            @test unique_result.status === getfield(runtime, :unique_match)
            @test unique_result.provider === provider
            @test no_match_result.status === getfield(runtime, :no_match)
            @test no_match_result.provider === nothing
            @test ambiguous_result.status === getfield(runtime, :ambiguous)
            @test ambiguous_result.provider === nothing
            @test out_of_domain_result.status === getfield(runtime, :out_of_domain)
            @test out_of_domain_result.provider === nothing
            (selection_id=String(route.selection_id),
                unique=match_summary(unique_result),
                no_match=match_summary(no_match_result),
                ambiguous=match_summary(ambiguous_result),
                out_of_domain=match_summary(out_of_domain_result))
        end
        matcher_outcomes = Tuple(route_match_outcomes(route) for route in registry.routes)

    error_summary(err) = (exception_type=string(nameof(typeof(err))),
        message=sprint(showerror, err))
    println("UP2_R71_STAGE=f4_consumer_body_before_return elapsed_ms=",
        (time_ns() - f4_helper_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    (; schema="b00-f4-current-source-summary-v1",
            candidate_binding=(candidate_ref=binding.candidate_ref,
                candidate_id=binding.candidate_id, scenario_id=binding.scenario_id,
                source_binding_hash=binding.binding_hash.value,
                t1_package_hash=binding.package_hash.value,
                v5_identity_hash=case.identity_package.candidate_hash.value,
                v5_identity_after=case.identity_package.migration_receipt.candidate_identity_after,
                g3_child_source_hash=registry.identity.g3_child_source_hash.value),
            registry_json=G.canonical_json(registry),
            ecf_compatibility_json=G.canonical_json(ecf),
            matcher_outcomes=matcher_outcomes,
            source_selection=(declaration_json=G.canonical_json(selection_context.declaration),
                child_pin=(role=string(selection_context.child_pin.role),
                    sha256=selection_context.child_pin.sha256.value),
                negative_outputs=(missing_selection=missing_selection,
                    bad_metadata=bad_metadata, bad_schema=bad_schema,
                    missing_row=missing_row,
                    wildcard_row=wildcard_row)),
            registry_negative_summaries=(wrong_candidate=error_summary(wrong_candidate_error),
                stale_package_hash=error_summary(stale_binding_error),
                altered_provider_summary=error_summary(provider_summary_error),
                malformed_provider_obligation_hash=error_summary(malformed_summary_error),
                missing_provider_bindings=error_summary(missing_provider_bindings_error),
                wildcard_provider_bindings=error_summary(wildcard_provider_bindings_error)),
            execution_counters=(available=false,
                reason="the current F4 consumer exposes no compile/provider/solver counters"))
end

Base.@noinline Base.@nospecializeinfer function _up2_assert_current_source_g2_order_consumer(case, input; native_plan=nothing, native_report=nothing, heat_lift_receipt=nothing)
    Base.@nospecialize case input native_plan native_report heat_lift_receipt
    helper_stage_started = time_ns()
    package = case.identity_package
    @test package isa G.CandidateStatePackageV5
    package isa G.CandidateStatePackageV5 || return nothing
    projection = package.component_identity.g2_source_projection
    genome = package.g2
    @test projection.genome === genome

    # Renumber only two independent G1 input nodes and remap the ordered
    # operator ports so they still bind grad_u first and u second.
    g1 = package.g1
    gradient = only(filter(eq -> eq.equation_id == "r2-grad-constraint",
        g1.payload.equation_plan.equations))
    expression = gradient.expression
    @test length(expression.nodes) == 3
    @test expression.nodes[1] isa G.G1StateInputV2
    @test expression.nodes[2] isa G.G1StateInputV2
    apply = expression.nodes[3]
    @test apply isa G.G1OperatorApplyV2
    @test apply.input_indices == (1, 2)
    renumbered_expression = G.G1TypedExpressionV2((
        expression.nodes[2], expression.nodes[1],
        G.G1OperatorApplyV2(apply.operator_ref, (2, 1), apply.output_type;
            parameters=apply.parameters)), expression.roots)
    renumbered_gradient = G.G1EquationV2(gradient.equation_id,
        gradient.role, gradient.operator_ref, gradient.input_state_refs,
        gradient.output_state_refs, gradient.input_units, gradient.output_units,
        gradient.temporal_kind, gradient.derivative_order, gradient.effects,
        gradient.occurrences, gradient.closure_ref, renumbered_expression;
        input_ranks=gradient.input_ranks, output_ranks=gradient.output_ranks)
    renumbered_equations = Tuple(eq.equation_id == gradient.equation_id ?
        renumbered_gradient : eq for eq in g1.payload.equation_plan.equations)
    renumbered_plan = G.G1EquationPlanV2(g1.payload.equation_plan.plan_ref,
        renumbered_equations)
    renumbered_payload = G.MechanismGenomePayloadV2(g1.payload.contract_ref,
        g1.payload.states, renumbered_plan, g1.payload.grammar_profile)
    renumbered_g1 = G.MechanismGenomeV5(g1.contract_ref, renumbered_payload,
        g1.version_axes)
    @test renumbered_expression.nodes != expression.nodes
    @test renumbered_expression.roots == expression.roots
    @test G.canonical_json(G.semantic_view(renumbered_g1)) ==
        G.canonical_json(G.semantic_view(g1))
    @test renumbered_g1.candidate_hash == g1.candidate_hash

    # Negative controls keep storage permutation but alter actual operator
    # port order or the equation root; typed admission must reject each.
    wrong_ports_expression = G.G1TypedExpressionV2((
        expression.nodes[1], expression.nodes[2],
        G.G1OperatorApplyV2(apply.operator_ref, (2, 1), apply.output_type;
            parameters=apply.parameters)), expression.roots)
    wrong_ports_gradient = G.G1EquationV2(gradient.equation_id,
        gradient.role, gradient.operator_ref, gradient.input_state_refs,
        gradient.output_state_refs, gradient.input_units, gradient.output_units,
        gradient.temporal_kind, gradient.derivative_order, gradient.effects,
        gradient.occurrences, gradient.closure_ref, wrong_ports_expression;
        input_ranks=gradient.input_ranks, output_ranks=gradient.output_ranks)
    wrong_ports_plan = G.G1EquationPlanV2(g1.payload.equation_plan.plan_ref,
        Tuple(eq.equation_id == gradient.equation_id ? wrong_ports_gradient : eq
            for eq in g1.payload.equation_plan.equations))
    wrong_ports_payload = G.MechanismGenomePayloadV2(g1.payload.contract_ref,
        g1.payload.states, wrong_ports_plan, g1.payload.grammar_profile)
    @test_throws ArgumentError G.MechanismGenomeV5(g1.contract_ref,
        wrong_ports_payload, g1.version_axes)
    wrong_root_expression = G.G1TypedExpressionV2(expression.nodes, 1)
    wrong_root_gradient = G.G1EquationV2(gradient.equation_id,
        gradient.role, gradient.operator_ref, gradient.input_state_refs,
        gradient.output_state_refs, gradient.input_units, gradient.output_units,
        gradient.temporal_kind, gradient.derivative_order, gradient.effects,
        gradient.occurrences, gradient.closure_ref, wrong_root_expression;
        input_ranks=gradient.input_ranks, output_ranks=gradient.output_ranks)
    wrong_root_plan = G.G1EquationPlanV2(g1.payload.equation_plan.plan_ref,
        Tuple(eq.equation_id == gradient.equation_id ? wrong_root_gradient : eq
            for eq in g1.payload.equation_plan.equations))
    wrong_root_payload = G.MechanismGenomePayloadV2(g1.payload.contract_ref,
        g1.payload.states, wrong_root_plan, g1.payload.grammar_profile)
    @test_throws ArgumentError G.MechanismGenomeV5(g1.contract_ref,
        wrong_root_payload, g1.version_axes)
    @test genome.grammar_profile.canonicalization_profile_ref.id ==
        G.G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID
    @test genome.contract_ref.canonicalization_hash ==
        G.g2_canonicalization_hash(genome.grammar_profile)
    @test genome.version_axes.canonicalization_profile_version.id ==
        G.G2_SOURCE_ORDER_CANONICALIZATION_AXIS_REF_ID
    @test genome.plan.mesh.cells_per_region == (2, 3, 4)

    # Reverse only the legal owner representation tuples, preserving every
    # semantic ID, owner, coordinate, interface orientation and source witness.
    reversed_regions = reverse(genome.region_interface.regions)
    reversed_region_ids = Tuple(region.region_id for region in reversed_regions)
    @test reversed_region_ids != Tuple(region.region_id for region in genome.region_interface.regions)
    contract = G.RegionInterfaceContractV2(reversed_regions,
        genome.region_interface.interfaces)
    reversed_mesh_region_ids = reverse(genome.plan.mesh.region_ids)
    @test reversed_mesh_region_ids != genome.plan.mesh.region_ids
    mesh = G.G2MeshPlanV2(genome.plan.mesh.mesh_ref,
        reversed_mesh_region_ids, genome.plan.mesh.cells_per_region,
        genome.plan.mesh.basis, genome.plan.mesh.quadrature;
        execution_status=genome.plan.mesh.execution_status)
    reversed_patches = reverse(genome.plan.exterior.boundary_patches)
    @test reversed_patches != genome.plan.exterior.boundary_patches
    exterior = G.G2ExteriorPlanV2(genome.plan.exterior.exterior_ref,
        reverse(genome.plan.exterior.boundary_region_ids),
        genome.plan.exterior.boundary_condition,
        reverse(genome.plan.exterior.boundary_faces);
        boundary_patches=reversed_patches,
        provider_match=genome.plan.exterior.provider_match)
    plan = G.FieldSpacePlanV2(genome.plan.plan_ref, genome.plan.chart,
        genome.plan.embedding, genome.plan.field_space, mesh, exterior)
    reordered_genome = G.FieldGeometryGenomeV5(genome.contract_ref, contract, plan,
        genome.grammar_profile, genome.version_axes)
    @test G.semantic_view(reordered_genome) == G.semantic_view(genome)
    @test reordered_genome.candidate_hash == genome.candidate_hash
    # These are the physical x/y/z axis counts, not per-region counts; their
    # order and values stay fixed while the independent region-owner set sorts.
    @test reordered_genome.plan.mesh.cells_per_region == genome.plan.mesh.cells_per_region == (2, 3, 4)
    @test reordered_genome.region_interface.interfaces == genome.region_interface.interfaces
    @test Tuple(region.region_id for region in reordered_genome.region_interface.regions) ==
        Tuple(region.region_id for region in genome.region_interface.regions)
    @test reordered_genome.plan.exterior.boundary_patches ==
        genome.plan.exterior.boundary_patches

    reordered_projection = G.G2V5SourceProjectionV1(reordered_genome,
        projection.source_declaration, projection.source_factory_identity,
        projection.source_factory_receipt, projection.source_payload_hash,
        projection.source_content_hash, projection.declaration_hash,
        projection.source_map_retained, projection.resolution,
        projection.claim_ceiling, projection.projection_hash)
    @test reordered_projection.source_declaration === projection.source_declaration
    @test reordered_projection.source_factory_identity === projection.source_factory_identity
    @test reordered_projection.source_factory_receipt === projection.source_factory_receipt
    @test G._v5_g2_source_projection_valid(reordered_projection)
    println("UP2_R71_STAGE=g2_replay_integrate_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    replay = G.integrate_genome_v5(renumbered_g1, reordered_projection, package.g3;
        candidate_ref=package.candidate_ref,
        g3_source_proof=package.g3.authored_payload.source_proof,
        g1_source_projection=package.component_identity.g1_source_projection)
    println("UP2_R71_STAGE=g2_replay_integrate_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test replay.structural_status == package.structural_status
    @test replay.resolution == package.resolution
    @test replay.errors == package.errors
    @test replay.gaps == package.gaps
    @test replay.claim_ceiling == package.claim_ceiling
    @test replay.g2.admission.structural_status == genome.admission.structural_status
    @test replay.g2.admission.geometry_status == genome.admission.geometry_status
    @test replay.g2.admission.provider_match == genome.admission.provider_match
    @test replay.g2.admission.resolution == genome.admission.resolution
    @test replay.g2.admission.errors == genome.admission.errors
    @test replay.g2.candidate_hash == genome.candidate_hash
    println("UP2_R71_STAGE=g2_component_identity_hash_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G.canonical_hash(replay.component_identity) ==
        G.canonical_hash(package.component_identity)
    println("UP2_R71_STAGE=g2_component_identity_hash_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test replay.migration_receipt.candidate_identity_after ==
        package.migration_receipt.candidate_identity_after
    @test replay.candidate_hash == package.candidate_hash
    println("UP2_R71_STAGE=g2_n10_package_check_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G._n10_check_package(replay) == G._n10_check_package(package)
    println("UP2_R71_STAGE=g2_n10_package_check_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test replay.structural_status == package.structural_status
    @test replay.resolution == package.resolution
    @test replay.errors == package.errors
    @test replay.gaps == package.gaps
    @test replay.claim_ceiling == package.claim_ceiling
    @test replay.component_identity == package.component_identity
    @test replay.migration_receipt == package.migration_receipt
    @test G.semantic_view(replay) == G.semantic_view(package)
    println("UP2_R71_STAGE=g2_replay_semantic_hash_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G.canonical_hash(G.semantic_view(replay)) ==
        G.canonical_hash(G.semantic_view(package))
    println("UP2_R71_STAGE=g2_replay_semantic_hash_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test G.canonical_hash(G.semantic_view(replay.g1.admission)) ==
        G.canonical_hash(G.semantic_view(package.g1.admission))
    @test G.canonical_hash(G.semantic_view(replay.g2.admission)) ==
        G.canonical_hash(G.semantic_view(package.g2.admission))
    @test replay.g1.candidate_hash == package.g1.candidate_hash
    @test replay.g2.candidate_hash == package.g2.candidate_hash
    @test replay.g3.candidate_hash == package.g3.candidate_hash
    @test replay.g3.authored_payload.source_proof ===
        package.g3.authored_payload.source_proof

    # A real geometry edit must not be accepted under the retained source proof.
    interface = only(genome.region_interface.interfaces)
    geometry_rejected = try
        changed_g2 = G.g2_edit_interface(genome, interface.interface_ref.id;
            coordinate=interface.coordinate + 1 // 100)
        changed_projection = G.G2V5SourceProjectionV1(changed_g2,
            projection.source_declaration, projection.source_factory_identity,
            projection.source_factory_receipt, projection.source_payload_hash,
            projection.source_content_hash, projection.declaration_hash,
            projection.source_map_retained, projection.resolution,
            projection.claim_ceiling, projection.projection_hash)
        !G._v5_g2_source_projection_valid(changed_projection)
    catch err
        err isa ArgumentError
    end
    @test geometry_rejected

    @test input isa G.UP2VNextPrecompilerInputV1
    @test input.status === :prepared_not_executed
    @test input.resolution === :terminal_deferred
    @test input.claim_ceiling === :contract_only
    println("UP2_R71_STAGE=g2_reordered_build_begin_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    reordered_build = case.build(native_plan=native_plan,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
        identity_package=replay)
    println("UP2_R71_STAGE=g2_reordered_build_end_ms=",
        (time_ns() - helper_stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test reordered_build.status === :prepared_not_executed
    @test reordered_build.resolution === :terminal_deferred
    @test reordered_build.reason === :vnext_t1_50_row_input_prepared_deferred
    @test reordered_build.input isa G.UP2VNextPrecompilerInputV1
    if reordered_build.input isa G.UP2VNextPrecompilerInputV1
        @test G.semantic_view(reordered_build.input) == G.semantic_view(input)
        @test reordered_build.input.input_hash == input.input_hash
        @test reordered_build.input.provider_bindings == input.provider_bindings
        @test G.up2_validate_input(reordered_build.input; package=case.package,
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=replay) === true
    end
    nothing
end

function _up2_assert_g3_reenable_manifest_selection(case)
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    temp_root = mktempdir(joinpath(root, "runs"))
    try
        for row in case.manifest.files
            logical = String(row.path)
            src = joinpath(case.current_source_root, split(logical, '/')...)
            dst = joinpath(temp_root, split(logical, '/')...)
            mkpath(dirname(dst))
            cp(src, dst; force=true)
        end
        relative_dir = replace(relpath(temp_root, root), '\\' => '/')
        manifest_path = joinpath(temp_root, "manifest.json")
        source_manifest_path = joinpath(case.current_source_root, "manifest.json")
        base_doc = JSON3.read(String(copy(read(source_manifest_path))), Dict{String,Any})
        function write_variant(mutator)
            doc = deepcopy(base_doc)
            selection = doc["g3_child_factory"]
            selection["source_path"] = relative_dir * "/g3_child_design_source.jl"
            mutator(doc, selection)
            write(manifest_path, JSON3.write(doc))
            G._vnext_current_source_candidate_records_v1(root, relative_dir)
        end
        built = write_variant((doc, selection) ->
            (selection["re_enable_threshold_kelvin"] = 325))
        @test hasproperty(built.child_design.control_design, :re_enable_policy)
        @test built.child_design.control_design.re_enable_policy.threshold_kelvin == 325//1
        @test built.g3.candidate_ref == case.candidate_ref

        function assert_manifest_rejected(mutator, expected)
            err = try
                write_variant(mutator)
                nothing
            catch caught
                caught
            end
            @test err isa ArgumentError
            if err isa ArgumentError
                @test sprint(showerror, err) == "ArgumentError: " * expected
            end
        end
        assert_manifest_rejected((doc, selection) ->
            (selection["re_enable_threshold_kelvin"] = 350),
            "candidate manifest G3 clear threshold must be exact Kelvin below the 350 K trip")
        assert_manifest_rejected((doc, selection) ->
            (selection["re_enable_threshold_kelvin"] = true),
            "candidate manifest G3 clear threshold must be exact Kelvin below the 350 K trip")
        assert_manifest_rejected((doc, selection) ->
            delete!(selection, "re_enable_threshold_kelvin"),
            "candidate manifest G3 factory selection is incomplete")
        assert_manifest_rejected((doc, selection) ->
            (selection["candidate_id"] = "foreign-candidate"),
            "candidate manifest G3 factory selection differs from its pinned identity/path")
        assert_manifest_rejected((doc, selection) ->
            (selection["scenario_id"] = "foreign-scenario"),
            "candidate manifest G3 factory selection differs from its pinned identity/path")
        assert_manifest_rejected((doc, selection) ->
            (selection["source_path"] = relative_dir * "/other_child.jl"),
            "candidate manifest G3 factory selection differs from its pinned identity/path")

        no_threshold = write_variant((doc, selection) ->
            (selection["re_enable_threshold_kelvin"] = nothing))
        @test !hasproperty(no_threshold.child_design.control_design, :re_enable_policy)
        @test no_threshold.g3.candidate_ref == case.candidate_ref
        @test hasproperty(no_threshold, :g3_factory_invocation)
        @test no_threshold.g3_factory_invocation !== nothing
        @test no_threshold.g3_factory_invocation.re_enable_threshold_kelvin === nothing
        no_threshold_records = G._vnext_current_source_records_v1(no_threshold)
        no_threshold_t0 = G.vnext_declaration_transport_local_v1(
            no_threshold_records.candidate, no_threshold_records.declarations,
            no_threshold_records.children, no_threshold_records.feedback;
            frozen_context=no_threshold.root)
        @test no_threshold_t0.status === :valid
        if no_threshold_t0.status === :valid
            no_threshold_raw = G._vnext_current_source_independent_g3_inputs_v1(
                no_threshold, no_threshold_records, no_threshold_t0.transport)
            @test no_threshold.identity.candidate_id == case.candidate_id
            @test no_threshold.identity.scenario_id == case.identity.scenario_id
            @test no_threshold.child_design.source_path == relative_dir *
                "/g3_child_design_source.jl"
            @test no_threshold_raw.expected.candidate_ref == case.candidate_ref
            @test G.canonical_hash(no_threshold_raw.control_payload.body) ==
                G.canonical_hash(no_threshold.child_design.control)
            @test !hasproperty(no_threshold.child_design.control_design, :re_enable_policy)
            @test no_threshold.child_design.control_design.sampled_fault_trace_kelvin ==
                (293//1, 325//1, 330//1, 335//1, 350//1)
        end

        # The historical manifest-absent route still invokes the authored
        # factory with no keywords and preserves that source's own defaults.
        legacy_root = joinpath(root, "runs", "e", "up1_up4_r2_frozen_candidate_20261001_r71", "snapshot")
        legacy_directory = "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2"
        legacy_manifest = JSON3.read(String(copy(read(joinpath(legacy_root,
            split(legacy_directory, '/')..., "manifest.json")))))
        @test !hasproperty(legacy_manifest, :g3_child_factory)
        legacy = G._vnext_current_source_candidate_records_v1(legacy_root, legacy_directory)
        @test hasproperty(legacy, :g3_factory_invocation)
        @test legacy.g3_factory_invocation === nothing
        @test legacy.g3.candidate_id == "local-authored-up4-g123-20260928-r2"
        @test legacy.g3.scenario_id == "scenario-local-authored-up4-g123-20260928-r2"
        legacy_records = G._vnext_current_source_records_v1(legacy)
        legacy_t0 = G.vnext_declaration_transport_local_v1(
            legacy_records.candidate, legacy_records.declarations,
            legacy_records.children, legacy_records.feedback;
            frozen_context=legacy.root)
        @test legacy_t0.status === :valid
        if legacy_t0.status === :valid
            legacy_raw = G._vnext_current_source_independent_g3_inputs_v1(
                legacy, legacy_records, legacy_t0.transport)
            @test legacy.identity.candidate_id == "local-authored-up4-g123-20260928-r2"
            @test legacy.identity.scenario_id == "scenario-local-authored-up4-g123-20260928-r2"
            @test legacy.child_design.source_path == legacy_directory * "/g3_child_design_source.jl"
            @test legacy_raw.expected.candidate_ref == legacy.candidate_ref
            @test G.canonical_hash(legacy_raw.control_payload.body) ==
                G.canonical_hash(legacy.child_design.control)
            @test !hasproperty(legacy.child_design.control_design, :re_enable_policy)
        end
    finally
        rm(temp_root; recursive=true, force=true)
    end
    nothing
end

function _up2_assert_candidate_bound_typed_source_impl(run::Symbol)
    stage_started = time_ns()
    case = _up2_vnext_t1_case(run)
    if run === :current_source
        if get(ENV, "UP2_CURRENT_SOURCE_REQUIRE_G3_REENABLE", "") == "1"
            @test hasproperty(case.manifest, :g3_child_factory)
        end
        println("UP2_R71_STAGE=case_loaded_ms=", (time_ns() - stage_started) / 1.0e6)
        flush(stdout)
    end
    native = if run in (:r71, :current_source)
        base = case.build()
        if run === :current_source
            println("UP2_R71_STAGE=base_input_built_ms=", (time_ns() - stage_started) / 1.0e6)
            flush(stdout)
        end
        _up2_r71_fresh_native_plan(case, base.input.source_binding)
    else
        nothing
    end
    native_plan = native
    native_runtime = native_plan === nothing ? nothing : Main.FusionRuntimeV4
    if run in (:r71, :current_source)
        println("UP2_R71_STAGE=native_plan_prepared_ms=",
            (time_ns() - stage_started) / 1.0e6)
        flush(stdout)
    end
    native_bundle = nothing
    native_report = nothing
    heat_lift_receipt = nothing
    if run === :current_source
        native_result_path = get(ENV, "UP2_CURRENT_SOURCE_NATIVE_RESULT", "")
        heat_lift_path = get(ENV, "UP2_CURRENT_SOURCE_HEAT_LIFT", "")
        @test !isempty(native_result_path) && isfile(native_result_path)
        @test !isempty(heat_lift_path) && isfile(heat_lift_path)
        if !isempty(native_result_path) && isfile(native_result_path) &&
                !isempty(heat_lift_path) && isfile(heat_lift_path)
            native_bundle = open(native_result_path, "r") do io
                Serialization.deserialize(io)
            end
            heat_lift_receipt = open(heat_lift_path, "r") do io
                Serialization.deserialize(io)
            end
            native_report = native_bundle.report
        end
    end
    native_evidence_kwargs = run === :current_source ?
        (; native_report=native_report, heat_lift_receipt=heat_lift_receipt) : (;)
    identity_evidence_kwargs = run === :current_source ?
        (; identity_package=case.identity_package) : (;)
    result = run === :current_source ?
        case.build(native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package) :
        case.build(native_plan=native_plan)
    if run in (:r71, :current_source)
        println("UP2_R71_STAGE=input_built_ms=",
            (time_ns() - stage_started) / 1.0e6)
        flush(stdout)
        if result.status !== :prepared_not_executed
            println("UP2_R71_N09_INPUT_OBSERVED=status=",
                result.status, ",resolution=", result.resolution,
                ",reason=", result.reason)
            probe_error = nothing
            base_binding = base.input.source_binding
            try
                geometry = G._up2_vnext_g2_geometry_context(case.package,
                    base_binding)
                g3_source_context = G._up2_vnext_n04_05_context(
                    case.package, base_binding; include_child_design=true,
                    identity_evidence_kwargs...)
                G._up2_vnext_n09_context(case.package, base_binding,
                    geometry, native_plan; g3_source_context=g3_source_context,
                    native_evidence_kwargs...)
            catch err
                probe_error = err
                println("UP2_R71_N09_CONTEXT_PROBE_ERROR=",
                    sprint(showerror, err))
                Base.show_backtrace(stdout, catch_backtrace())
                println()
            end
            @test result.status === :prepared_not_executed
            @test probe_error === nothing
            return nothing
        end
    end
    @test result.status === :prepared_not_executed
    @test result.resolution === :terminal_deferred
    @test result.reason === :vnext_t1_50_row_input_prepared_deferred
    @test result.input isa G.UP2VNextPrecompilerInputV1
    input = result.input
    run === :current_source && (println("UP2_R71_STAGE=g2_order_helper_begin_ms=",
        (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    run === :current_source && _up2_assert_current_source_g2_order_consumer(case,
        input; native_plan=native_plan, native_report=native_report,
        heat_lift_receipt=heat_lift_receipt)
    run === :current_source && (println("UP2_R71_STAGE=g2_order_helper_end_ms=",
        (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    run === :current_source && (println("UP2_R71_STAGE=label_helper_begin_ms=",
        (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    run === :current_source && _up2_assert_current_source_label_invariance(case,
        input, result; native_plan=native_plan, native_report=native_report,
        heat_lift_receipt=heat_lift_receipt)
    run === :current_source && (println("UP2_R71_STAGE=label_helper_end_ms=",
        (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    n09_05_present = !(only(filter(x -> x.id == "N09-05", input.state.fields)).value isa
        G.UP2AbsentValueV1)
    n09_04_present = run === :current_source && native_report !== nothing &&
        heat_lift_receipt !== nothing
    binding = input.source_binding
    if run === :current_source
        source_refs_started = time_ns()
        println("UP2_R71_STAGE=source_contract_refs_begin elapsed_ms=0.0 gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        source_contract_refs = G.up2_vnext_source_contract_refs_v1(case.package, input)
        @test Tuple(keys(source_contract_refs)) == (:g1, :g2, :g3)
        @test source_contract_refs.g1 isa G.GenomeContractRef
        @test source_contract_refs.g2 isa G.GenomeContractRef
        @test source_contract_refs.g3 isa G.GenomeContractRef
        receipt_contract_ref(layer) = begin
            declaration = only(Tuple(d for d in case.package.declarations if
                d.layer === layer))
            receipt_bytes = G.copy_bytes(declaration.factory_receipt_bytes)
            @test declaration.factory_receipt_bytes.sha256 ==
                G.Digest256(bytes2hex(SHA.sha256(receipt_bytes)))
            receipt = JSON3.read(String(receipt_bytes))
            G._up2_n10_contract_ref_from_wire(receipt.contract_ref,
                "test.$(layer).factory_receipt")
        end
        @test source_contract_refs.g1 == receipt_contract_ref(:G1)
        @test source_contract_refs.g2 == receipt_contract_ref(:G2)
        @test source_contract_refs.g3 == receipt_contract_ref(:G3)

        wrong_source_ref = G.QualifiedRefV1(
            "fusionconceptai://candidate-design/up2_accessor_wrong_candidate", "v5")
        wrong_source_binding = G.UP2VNextSourceBindingV1(wrong_source_ref,
            "up2_accessor_wrong_candidate", binding.scenario_id,
            binding.snapshot_id, binding.manifest_sha256, binding.package_hash,
            binding.semantic_identity, binding.bundle_hash, binding.n03_projection_hash,
            binding.source_pins, binding.event_id, binding.trigger, binding.time,
            binding.time_basis, binding.projection_status,
            binding.projection_resolution, binding.authority_scope, binding.authority_gap)
        wrong_source_input = G.UP2VNextPrecompilerInputV1(wrong_source_binding,
            input.mission_bounds, input.state, input.field_states;
            provider_bindings=input.provider_bindings)
        wrong_source_ref_error = try
            G.up2_vnext_source_contract_refs_v1(case.package, wrong_source_input)
            nothing
        catch err
            err
        end
        @test wrong_source_ref_error isa ArgumentError
        @test wrong_source_ref_error.msg ==
            "N10 current-source package identity differs from its source binding"
        println("UP2_R71_STAGE=source_contract_refs_end elapsed_ms=",
            (time_ns() - source_refs_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
    end
    vnext_input_validate_started = time_ns()
    run === :current_source && (println("UP2_R71_STAGE=vnext_input_validate_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    @test G.up2_validate_vnext_input(input; package=case.package,
        native_plan=native_plan, native_evidence_kwargs...,
        identity_evidence_kwargs...)
    run === :current_source && (println("UP2_R71_STAGE=vnext_input_validate_end elapsed_ms=",
        (time_ns() - vnext_input_validate_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    if run === :current_source
        G.load_genome_v5_up2_components!()
        G.load_vnext_t2_components_v2!()
        f4_registry_started = time_ns()
        println("UP2_R71_STAGE=f4_registry_begin elapsed_ms=0.0 gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        f4 = G._up2_vnext_candidate_provider_registry_v1(input, case.package;
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            identity_package=case.identity_package)
        println("UP2_R71_STAGE=f4_registry_end elapsed_ms=",
            (time_ns() - f4_registry_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        f4_consumer_started = time_ns()
        println("UP2_R71_STAGE=f4_consumer_call_begin elapsed_ms=0.0 gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        f4_summary = _up2_assert_current_source_f4_consumer(case, input;
            native_plan=native_plan, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt, f4_result=f4)
        println("UP2_R71_STAGE=f4_consumer_call_end elapsed_ms=",
            (time_ns() - f4_consumer_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
    end
    @test input.status === :prepared_not_executed
    @test input.resolution === :terminal_deferred
    @test input.claim_ceiling === :contract_only
    @test length(input.state.fields) == length(input.field_states) ==
        length(_up2_fixture_specs()) == G.up2_mutation_count() == 50
    @test Tuple(field.id for field in input.state.fields) ==
        Tuple(spec.id for spec in _up2_fixture_specs())
    @test case.package.package_hash == binding.package_hash
    @test case.package.semantic_identity == binding.semantic_identity
    @test case.package.bundle_hash == binding.bundle_hash
    @test case.upstream_receipts !== nothing

    with_binding(; candidate_ref=binding.candidate_ref,
            candidate_id=binding.candidate_id, package_hash=binding.package_hash,
            source_pins=binding.source_pins) = G.UP2VNextSourceBindingV1(
        candidate_ref, candidate_id, binding.scenario_id, binding.snapshot_id,
        binding.manifest_sha256, package_hash, binding.semantic_identity,
        binding.bundle_hash, binding.n03_projection_hash, source_pins,
        binding.event_id, binding.trigger, binding.time, binding.time_basis,
        binding.projection_status, binding.projection_resolution,
        binding.authority_scope, binding.authority_gap)

    # Candidate-bound native G1/G2 fields remain contract-only and deferred.
    g1_context_started = time_ns()
    run === :current_source && (println("UP2_R71_STAGE=g1_context_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    g1_types = G._up2_vnext_g1_operator_type_context(case.package, binding)
    run === :current_source && (println("UP2_R71_STAGE=g1_context_end elapsed_ms=",
        (time_ns() - g1_context_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    g2_context_started = time_ns()
    run === :current_source && (println("UP2_R71_STAGE=g2_context_begin elapsed_ms=0.0 gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    g2_geometry = G._up2_vnext_g2_geometry_context(case.package, binding)
    run === :current_source && (println("UP2_R71_STAGE=g2_context_end elapsed_ms=",
        (time_ns() - g2_context_started) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
    @test g1_types.candidate_ref == binding.candidate_ref
    @test g1_types.package_hash == binding.package_hash
    @test g1_types.semantic_identity == binding.semantic_identity
    @test g1_types.bundle_hash == binding.bundle_hash
    @test g1_types.projection_hash isa G.Digest256
    for role in (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source)
        bound_pin = only(filter(pin -> pin.role === role,
            binding.source_pins))
        fixture_pin = getproperty(case.source_pins, role)
        @test bound_pin.byte_count == fixture_pin.bytes
        @test bound_pin.sha256 == fixture_pin.sha256
    end
    @test g2_geometry.candidate_ref == binding.candidate_ref
    @test g2_geometry.package_hash == binding.package_hash
    @test g2_geometry.profile_dimension == 3
    @test g2_geometry.projection_hash isa G.Digest256
    if run in (:r70, :r71, :current_source)
        cross_state = g2_geometry.cross_state_context
        @test cross_state isa NamedTuple
        @test g1_types.unknown_state_binding.state_index == 0
        @test g1_types.unknown_state_binding.role === :unknown
        @test g1_types.unknown_state_binding.field_id == cross_state.state_field_id
        @test cross_state.g1_field_id == g1_types.unknown_state_binding.field_id
        @test cross_state.g1_physical_signature ==
            g1_types.unknown_state_binding.physical_signature
        @test cross_state.g1_state_index == 0
        @test cross_state.g1_role === :unknown
        @test cross_state.value_shape === :scalar
        @test cross_state.state_unit == "1"
        @test cross_state.state_unit_signature == G.UnitSignature()
        @test cross_state.q1_interpretation ===
            :continuous_tensor_product_lagrange_degree1_h1
        @test g2_geometry.cross_state_projection_hash == g1_types.projection_hash
        @test g2_geometry.values["N08-04"] === :linear
        @test !haskey(g2_geometry.absent_reasons, "N08-04")
        r70_source_rows = (
            ("N01-03", G.UP2IntegerValueV1(0),
                :candidate_design_g1_g2_state_field_binding_contract_only,
                (:g1_builder, :g1_declaration_source, :g2_builder,
                    :g2_declaration_source)),
            ("N01-05", G.UP2SymbolValueV1(:scalar),
                :candidate_design_g1_g2_state_field_binding_contract_only,
                (:g1_builder, :g1_declaration_source, :g2_builder,
                    :g2_declaration_source)),
            ("N02-03", G.UP2TextValueV1("1"),
                :candidate_design_g1_g2_state_field_binding_contract_only,
                (:g1_builder, :g1_declaration_source, :g2_builder,
                    :g2_declaration_source)),
            ("N08-04", G.UP2SymbolValueV1(:linear),
                :candidate_design_g2_q1_h1_degree1_basis_contract_only,
                (:g2_builder, :g2_declaration_source)))
        for (id, expected, reason, roles) in r70_source_rows
            spec = G.up2_spec_for_id(id)
            field = only(filter(x -> x.id == id, input.state.fields))
            state = only(filter(x -> x.field_id == id, input.field_states))
            @test field.field_path == spec.field_path
            @test field.source_locator == spec.source_locator
            @test field.source_type === spec.source_type
            @test G.semantic_view(field.value) == G.semantic_view(expected)
            @test state.state === :source_present_deferred
            @test state.reason === reason
            @test state.source_pin_roles == roles
            @test all(role -> begin
                pin = only(filter(x -> x.role === role, binding.source_pins))
                pin.byte_count > 0 && pin.sha256 isa G.Digest256
            end, roles)
        end
    else
        # R69's pinned source predates the optional G1/G2 state binding.
        # Keep its old rows absent instead of applying R70 facts retroactively.
        @test g1_types.unknown_state_binding === nothing
        @test g2_geometry.cross_state_context === nothing
        @test haskey(g2_geometry.absent_reasons, "N08-04")
        n08_04 = only(filter(x -> x.id == "N08-04", input.state.fields))
        @test n08_04.value isa G.UP2AbsentValueV1
        @test n08_04.value.reason ===
            :g2mb_q1_basis_equivalence_not_frozen
    end
    if run in (:r71, :current_source)
        g1_declaration = only(filter(d -> d.layer === :G1,
            case.package.declarations))
        g1_body = JSON3.read(String(G.copy_bytes(
            g1_declaration.semantic_body_bytes)))
        temporal_wire = g1_body.source_payload.operator_temporal_support
        for operator_name in (:grad, :coefficient_apply, :div)
            operator_wire = getproperty(temporal_wire, operator_name)
            @test Tuple(Symbol(String(kind)) for kind in
                operator_wire.temporal_kinds) == (:static_time,)
        end
        g2_declaration = only(filter(d -> d.layer === :G2,
            case.package.declarations))
        g2_body = JSON3.read(String(G.copy_bytes(
            g2_declaration.semantic_body_bytes)))
        @test Tuple(Symbol(String(axis)) for axis in
            g2_body.source.chart_map.axes) == (:x, :y, :z)
        @test g2_body.source.boundary_coverage == "whole_face"
        @test haskey(g1_types.values, "N03-03")
        @test g1_types.operator_temporal_kinds == (:static_time,)
        @test g1_types.values["N03-03"] == (:static_time,)
        @test g2_geometry.values["N07-04"] == (1 // 3, 1 // 4)
        @test g2_geometry.boundary_patch_context.coverage === :whole_face
        @test g2_geometry.boundary_patch_context.face === :x_max
        @test g2_geometry.boundary_patch_context.tangent_axes == (2, 3)
        @test g2_geometry.boundary_patch_context.lower ==
            g2_geometry.values["N07-04"]
        @test g2_geometry.boundary_patch_context.upper == (10 // 3, 17 // 4)
        @test g2_geometry.values["N08-01"] == (:x, :y, :z)
        r71_source_rows = (
            ("N03-03", G.UP2TupleValueV1(g1_types.values["N03-03"],
                :timekind_v1),
                :candidate_design_g1_operator_temporal_whitelist_contract_only,
                (:g1_builder, :g1_declaration_source)),
            ("N09-01", G.UP2SymbolValueV1(:unique_match),
                :candidate_design_g1_grad_native_gridap_service_match,
                (:g1_builder, :g1_declaration_source)),
            ("N07-04", G.UP2TupleValueV1(g2_geometry.values["N07-04"],
                :rational), :candidate_design_g2_geometry_contract_only,
                (:g2_builder, :g2_declaration_source)),
            ("N08-01", G.UP2TupleValueV1(g2_geometry.values["N08-01"],
                :symbol), :candidate_design_g2_geometry_contract_only,
                (:g2_builder, :g2_declaration_source)),
            (run === :current_source ?
                (("N08-05", G.UP2TupleValueV1(
                    g2_geometry.values["N08-05"], :qualified_ref),
                    :candidate_design_g2_geometry_contract_only,
                    (:g2_builder, :g2_declaration_source)),) : ())...)
        for (id, expected, reason, roles) in r71_source_rows
            spec = G.up2_spec_for_id(id)
            field = only(filter(x -> x.id == id, input.state.fields))
            state = only(filter(x -> x.field_id == id, input.field_states))
            @test field.field_path == spec.field_path
            @test field.source_locator == spec.source_locator
            @test field.source_type === spec.source_type
            @test G.semantic_view(field.value) == G.semantic_view(expected)
            @test state.state === :source_present_deferred
            @test state.reason === reason
            @test state.source_pin_roles == roles
            @test all(role -> begin
                pin = only(filter(x -> x.role === role, binding.source_pins))
                pin.byte_count > 0 && pin.sha256 isa G.Digest256
            end, roles)
        end
        n09_g3_context_started = time_ns()
        run === :current_source && (println("UP2_R71_STAGE=n09_g3_context_begin elapsed_ms=0.0 gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
        n09_g3_context = G._up2_vnext_n04_05_context(case.package, binding;
            include_child_design=true, identity_evidence_kwargs...)
        run === :current_source && (println("UP2_R71_STAGE=n09_g3_context_end elapsed_ms=",
            (time_ns() - n09_g3_context_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
        n09_context_started = time_ns()
        run === :current_source && (println("UP2_R71_STAGE=n09_context_begin elapsed_ms=0.0 gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
        n09_context = G._up2_vnext_n09_context(case.package, binding,
            g2_geometry, native_plan; g3_source_context=n09_g3_context)
        run === :current_source && (println("UP2_R71_STAGE=n09_context_end elapsed_ms=",
            (time_ns() - n09_context_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes()); flush(stdout))
        if run === :current_source
            @test n09_05_present
            @test haskey(g2_geometry.values, "N08-05")
            @test !haskey(g2_geometry.absent_reasons, "N08-05")
        end
        @test haskey(n09_context.matches, "N09-05") == n09_05_present
        n09_row_ids = ("N09-01", "N09-02", "N09-03",
            (n09_04_present ? ("N09-04",) : ())...,
            (n09_05_present ? ("N09-05",) : ())...)
        @test Tuple(binding.field_id for binding in input.provider_bindings) == n09_row_ids
        @test Tuple(binding.status for binding in input.provider_bindings) ==
            ntuple(_ -> :unique_match, length(n09_row_ids))
        @test Tuple(binding.plan_hash for binding in input.provider_bindings
            if hasproperty(binding, :plan_hash)) ==
            (native_plan.plan_hash, native_plan.plan_hash, native_plan.plan_hash)
        @test native_plan.plan_hash == n09_context.plan_hash
        if n09_05_present
            g3_service = n09_context.requests["N09-05"]
            g3_controller = only(g3_service.control.controllers)
            g3_initial_state = only(g3_controller.initial_states)
            g3_initial_event = first(g3_controller.events)
            @test g3_initial_state.value == 293//1
            @test g3_initial_state.unit == G.UnitSignature((0, 0, 0, 0, 1, 0, 0))
            @test g3_initial_event.event_id == "initial_enable"
            @test g3_initial_event.trigger === :initial
            @test g3_initial_event.time == 0//1
            @test g3_initial_event.action === :enable
            if hasproperty(case.manifest, :g3_child_factory)
                @test length(g3_controller.events) == 2
                clear_event = last(g3_controller.events)
                @test clear_event.event_id == g3_service.design.re_enable_policy.event_id
                @test clear_event.trigger === :threshold && clear_event.time == 0//1
                @test clear_event.action === :recover
                @test length(g3_service.result.samples) == 7
                @test Tuple(x.time_seconds for x in g3_service.result.samples) ==
                    (0//1, 1//20, 1//10, 3//20, 1//5, 1//4, 3//10)
                @test Tuple(x.temperature_kelvin for x in g3_service.result.samples) ==
                    (293//1, 325//1, 330//1, 335//1, 350//1, 325//1, 293//1)
                @test Tuple(x.action for x in g3_service.result.samples) ==
                    (:full_source, :full_source, :hold_previous_fraction, :zero_source,
                     :trip, :recover, :full_source)
                @test Tuple(x.command_fraction for x in g3_service.result.samples) ==
                    (1//1, 1//1, 1//1, 0//1, 0//1, 0//1, 1//1)
                @test Tuple(x.power_status for x in g3_service.result.samples) ==
                    (1000//1, 1000//1, 1000//1, 0//1, 0//1, 0//1, 1000//1)
                @test Tuple(x.power_unit for x in g3_service.result.samples) ==
                    ntuple(_ -> G.UnitSignature((2, 1, -3, 0, 0, 0, 0)), 7)
                @test Tuple(x.fault_latched for x in g3_service.result.samples) ==
                    (false, false, false, false, true, false, false)
                @test g3_service.result.re_enable_threshold_kelvin == 325//1
                @test g3_service.result.re_enabled_at == 1//4
                @test g3_service.result.re_enable_policy_hash ==
                    G.canonical_hash(g3_service.design.re_enable_policy)
                @test g3_service.result.fault_latched === false
                ecf = f4.ecf_compatibility
                @test ecf.provider_hash == g3_service.provider.manifest_hash
                @test ecf.capability_hash == G.canonical_hash(g3_service.provider.capability)
                @test ecf.obligation_hash == G.canonical_hash(g3_service.obligation)
                @test ecf.control_hash == G.canonical_hash(g3_service.control)
                @test ecf.guard == g3_service.design.re_enable_policy
                ecf_source_proof = case.identity_package.g3.authored_payload.source_proof
                @test G.canonical_hash(ecf.source_selection) ==
                    G.canonical_hash(ecf_source_proof.rebuilt_child.provider_route_selection.ecf_compatibility)
                @test G.canonical_hash(ecf.discrete_trace) == G.canonical_hash(g3_service.result)
                @test ecf.trace_hash == g3_service.trace_hash
                _up2_assert_g3_reenable_manifest_selection(case)
            else
                @test length(g3_controller.events) == 1
                @test length(g3_service.result.samples) == 5
                @test Tuple(x.time_seconds for x in g3_service.result.samples) ==
                    (0//1, 1//20, 1//10, 3//20, 1//5)
                @test Tuple(x.temperature_kelvin for x in g3_service.result.samples) ==
                    (293//1, 325//1, 330//1, 335//1, 350//1)
                @test Tuple(x.command_fraction for x in g3_service.result.samples) ==
                    (1//1, 1//1, 1//1, 0//1, 0//1)
                @test Tuple(x.power_status for x in g3_service.result.samples) ==
                    (1000//1, 1000//1, 1000//1, 0//1, 0//1)
                @test Tuple(x.power_unit for x in g3_service.result.samples) ==
                    ntuple(_ -> G.UnitSignature((2, 1, -3, 0, 0, 0, 0)), 5)
            end
            @test g3_service.result.fault_observed_at == 1//5
            @test g3_service.result.trip_action_at == 1//5
            @test g3_service.result.logical_response_seconds == 0//1
            @test g3_service.result.deadline_seconds == 1//10
            @test g3_service.result.deadline_satisfied
            @test g3_service.result.timing_scope === :discrete_software_samples
            @test !g3_service.result.engineering_evidence &&
                !g3_service.result.physical_evidence && !g3_service.result.terminal_authority
        else
            absent05 = only(filter(x -> x.id == "N09-05", input.state.fields))
            state05 = only(filter(x -> x.field_id == "N09-05", input.field_states))
            @test absent05.value isa G.UP2AbsentValueV1
            @test state05.state === :typed_absent
            @test state05.reason === :provider_match_evidence_absent
            @test isempty(state05.source_pin_roles)
        end
        println("UP2_R71_STAGE=service_request_loop_begin_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        for id in ("N09-01", "N09-02", "N09-03")
            println("UP2_R71_STAGE=service_request_id_begin id=", id,
                " elapsed_ms=", (time_ns() - stage_started) / 1.0e6,
                " gc_live_bytes=", Base.gc_live_bytes(),
                " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            spec = G.up2_spec_for_id(id)
            field = only(filter(x -> x.id == id, input.state.fields))
            state = only(filter(x -> x.field_id == id, input.field_states))
            request = n09_context.requests[id]
            obligation = n09_context.obligations[id]
            @test field.field_path == spec.field_path
            @test field.source_locator == spec.source_locator
            @test field.source_type === :symbol
            @test field.value == G.UP2SymbolValueV1(:unique_match)
            @test n09_context.matches[id] === :unique_match
            @test state.state === :source_present_deferred
            @test state.reason === (id == "N09-01" ?
                :candidate_design_g1_grad_native_gridap_service_match :
                id == "N09-02" ?
                :candidate_design_g2_profile_native_gridap_service_match :
                :candidate_design_g2_exterior_native_gridap_service_match)
            @test state.source_pin_roles == (id == "N09-01" ?
                (:g1_builder, :g1_declaration_source) :
                (:g2_builder, :g2_declaration_source))
            @test spec.expected_error === :provider_match
            @test spec.expected_resolution === G.terminal_deferred
            @test spec.expected_provider_calls == 0
            println("UP2_R71_STAGE=service_request_validate_begin id=", id, " elapsed_ms=", (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            @test native_runtime.validate_native_g1g2_gridap_service_request_v1(request)
            println("UP2_R71_STAGE=service_request_validate_end id=", id,
                " elapsed_ms=", (time_ns() - stage_started) / 1.0e6,
                " gc_live_bytes=", Base.gc_live_bytes(),
                " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            println("UP2_R71_STAGE=service_input_validate_begin id=", id,
                " elapsed_ms=", (time_ns() - stage_started) / 1.0e6,
                " gc_live_bytes=", Base.gc_live_bytes(),
                " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            @test native_runtime._ng12_validate_service_input_v1(request,
                request.service, request.provider.executor) === request.provider
            println("UP2_R71_STAGE=service_input_validate_end id=", id,
                " elapsed_ms=", (time_ns() - stage_started) / 1.0e6,
                " gc_live_bytes=", Base.gc_live_bytes(),
                " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            if id == "N09-02"
                no_provider_error = try
                    native_runtime._ng12_execute_gridap_service_v1(
                        request, request.service, request.provider.executor;
                        provider_candidates=())
                    nothing
                catch err
                    err
                end
                @test no_provider_error isa ArgumentError
                @test sprint(showerror, no_provider_error) ==
                    "ArgumentError: service provider did not match its exact obligation"
            end
            @test request.plan_hash == native_plan.plan_hash
            @test request.plan === native_plan
            @test request.level == 1
            @test G.canonical_hash(obligation) ==
                G.canonical_hash(request.capability)
            service_payload = request.solver_input.payload.materialized_payload
            shared_service_payload_properties = (
                :service_scope, :service, :plan_hash, :candidate_ref,
                :package_hash, :semantic_identity, :bundle_hash,
                :g1_declaration_hash, :g2_declaration_hash, :g2_source_hash,
                :form_hash, :protocol_hash, :dependency_hash,
                :adapter_source_hash, :level, :cell_counts,
                :declared_mesh_quadrature_hash,
                :execution_quadrature_degree, :capability_hash,
                :provider_manifest_hash, :input_schema_hash,
                :applicability_hash)
            @test propertynames(service_payload) == (id == "N09-01" ?
                (shared_service_payload_properties...,
                    :g1_grad_contract_hash) :
                shared_service_payload_properties)
            @test !hasproperty(service_payload, :service_plan)
            @test !hasproperty(service_payload, :plan)
            form = native_plan.compilation.form
            @test service_payload.candidate_ref == form.candidate_ref
            @test service_payload.package_hash == form.t1_package_hash
            @test service_payload.semantic_identity == form.t1_semantic_identity
            @test service_payload.bundle_hash == form.t0_bundle_hash
            @test service_payload.g1_declaration_hash ==
                form.g1_declaration.declaration_hash
            @test service_payload.g2_declaration_hash ==
                form.g2_declaration.declaration_hash
            @test service_payload.g2_source_hash ==
                form.g2_declaration.source.source_hash
            @test service_payload.form_hash == form.form_hash
            @test service_payload.protocol_hash == native_plan.protocol.protocol_hash
            @test service_payload.dependency_hash ==
                native_plan.dependency_identity.dependency_hash
            @test service_payload.adapter_source_hash ==
                native_plan.adapter_source_hash
            @test G.canonical_hash(service_payload) ==
                G.canonical_hash(request.subject.materialized_payload)
            @test service_payload.capability_hash ==
                G.canonical_hash(request.capability)
            if id == "N09-01"
                form = native_plan.compilation.form
                grad = form.g1_declaration.operators.grad
                coefficient_apply =
                    form.g1_declaration.operators.coefficient_apply
                @test request.service === native_runtime._NG12_GRAD_SERVICE_V1
                @test request.provider.executor ===
                    native_runtime._ng12_gridap_grad_executor_v1
                @test grad.operator_ref.id ==
                    G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1
                @test grad.operator_ref.version == "v1"
                @test grad.input_field_id == form.g1_declaration.u.field_id
                @test grad.output_field_id == coefficient_apply.input_field_id
                @test grad.input_field_id ==
                    g1_types.unknown_state_binding.field_id
                @test grad.input_type.value_kind === :scalar_field
                @test grad.input_type.tensor_rank == 0
                @test grad.input_type.spatial_dimension == 3
                @test grad.input_type.temporal_type ==
                    G.TemporalTypeV1(G.static_time)
                @test grad.output_type.value_kind === :vector_field
                @test grad.output_type.tensor_rank == 1
                @test grad.output_type.spatial_dimension == 3
                @test grad.output_type.temporal_type ==
                    G.TemporalTypeV1(G.static_time)
                @test service_payload.g1_grad_contract_hash ==
                    G.canonical_hash(G.semantic_view(grad))
                @test obligation.source_space ==
                    "gridap_q1_h1_static_3d_scalar"
                @test obligation.target_space ==
                    "gridap_q1_piecewise_l2_static_3d_vector"
                negative = G._up2_vnext_n09_mutated_match(n09_context, id)
                @test negative.status === G.out_of_domain
                @test negative.provider === nothing
                @test negative.reason ==
                    "signature matched but provider domain or ceiling did not"
                @test negative.obligation_hash != G.canonical_hash(obligation)
                target_space_only_mismatch = native_runtime.CapabilitySignatureV4(
                    obligation.schema, obligation.revision, obligation.kind,
                    obligation.operator, obligation.states,
                    obligation.source_space, obligation.source_space,
                    obligation.dimension, obligation.coordinates,
                    obligation.boundary_relation, obligation.interface_relation,
                    obligation.time_semantics, obligation.required_output,
                    obligation.evidence_level, obligation.applicability_bounds;
                    input_schema_hash=obligation.input_schema_hash,
                    coordinate_system=obligation.coordinate_system)
                @test target_space_only_mismatch.source_space ==
                    obligation.source_space
                @test target_space_only_mismatch.target_space ==
                    obligation.source_space
                @test target_space_only_mismatch.input_schema_hash ==
                    request.capability.input_schema_hash
                @test target_space_only_mismatch.input_schema_hash ==
                    obligation.input_schema_hash
                @test negative.obligation_hash ==
                    G.canonical_hash(target_space_only_mismatch)
                target_space_only_match = native_runtime.match_provider(
                    target_space_only_mismatch, (request.provider,))
                @test target_space_only_match.status === G.out_of_domain
                @test target_space_only_match.provider === nothing
                @test G.semantic_view(target_space_only_match) ==
                    G.semantic_view(negative)
            end
            provider_binding = only(filter(x -> x.field_id == id,
                input.provider_bindings))
            @test provider_binding.service == request.service
            @test provider_binding.obligation_hash ==
                G.canonical_hash(obligation)
            @test provider_binding.service_contract_hash ==
                G.canonical_hash(request.capability)
            @test provider_binding.subject_hash ==
                request.subject.physical_subject_hash
            @test provider_binding.solver_input_hash ==
                request.solver_input.solver_input_hash
            @test provider_binding.plan_hash == request.plan.plan_hash
            tampered_plan_request = typeof(request)(request.service,
                request.capability, request.provider, request.subject,
                request.solver_input, request.plan,
                G.canonical_hash((plan_tamper=id,)), request.level)
            @test !native_runtime.validate_native_g1g2_gridap_service_request_v1(
                tampered_plan_request)
            wrong_plan = typeof(request.plan)(request.plan.compilation,
                request.plan.compile_result_hash, request.plan.protocol,
                request.plan.dependency_identity, request.plan.provider,
                request.plan.subject, request.plan.solver_input,
                request.plan.adapter_source_hash,
                G.canonical_hash((wrong_plan=id,)))
            wrong_plan_request = typeof(request)(request.service,
                request.capability, request.provider, request.subject,
                request.solver_input, wrong_plan, request.plan_hash,
                request.level)
            @test !native_runtime.validate_native_g1g2_gridap_service_request_v1(
                wrong_plan_request)
            provider = request.provider
            no_executor_provider = native_runtime.ProviderManifestV4(provider.schema,
                provider.revision, provider.kind, provider.capability,
                provider.domain, provider.backend, provider.backend_revision,
                provider.code_hash, provider.independence_group,
                provider.claim_ceiling; input_schema_hash=provider.input_schema_hash,
                executor=nothing)
            no_executor_request = typeof(request)(request.service,
                request.capability, no_executor_provider, request.subject,
                request.solver_input, request.plan, request.plan_hash,
                request.level)
            @test !native_runtime.validate_native_g1g2_gridap_service_request_v1(
                no_executor_request)
            @test_throws ArgumentError native_runtime.ProviderManifestV4(provider.schema,
                provider.revision, provider.kind, provider.capability,
                provider.domain, provider.backend, provider.backend_revision,
                provider.code_hash, provider.independence_group,
                provider.claim_ceiling; input_schema_hash=provider.input_schema_hash,
                executor=(input -> nothing))
            if id != "N09-01"
                controlled_match = G._up2_vnext_n09_mutated_match(n09_context, id)
                @test controlled_match.status === G.out_of_domain
                @test controlled_match.provider === nothing
            end
        end
        println("UP2_R71_STAGE=service_request_loop_end_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        # The admission token must bind the canonical plan body, its exact
        # embedded T1 package, and the registered executor independently of
        # caller-preserved hashes.
        println("UP2_R71_STAGE=admission_negative_checks_begin_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        admission = native_runtime.native_g1g2_gridap_plan_admission_v1(
            native_plan)
        @test admission !== nothing
        @test !native_runtime.validate_native_g1g2_gridap_plan_admission_v1(
            native_plan, deepcopy(admission))

        changed_plan_body = typeof(native_plan)(native_plan.compilation,
            native_plan.compile_result_hash, native_plan.protocol,
            native_plan.dependency_identity, native_plan.provider,
            native_plan.subject, native_plan.solver_input,
            G.Digest256(repeat("0", 64)), native_plan.plan_hash)
        @test changed_plan_body.plan_hash == native_plan.plan_hash
        @test !native_runtime.validate_native_g1g2_gridap_plan_admission_v1(
            changed_plan_body, admission)

        cross_plan = typeof(native_plan)(native_plan.compilation,
            native_plan.compile_result_hash, native_plan.protocol,
            native_plan.dependency_identity, native_plan.provider,
            native_plan.subject, native_plan.solver_input,
            native_plan.adapter_source_hash,
            G.canonical_hash((cross_plan=native_plan.plan_hash,)))
        @test cross_plan.plan_hash != native_plan.plan_hash
        @test !native_runtime.validate_native_g1g2_gridap_plan_admission_v1(
            cross_plan, admission)

        plan_provider = native_plan.provider
        no_executor_plan_provider = native_runtime.ProviderManifestV4(
            plan_provider.schema, plan_provider.revision, plan_provider.kind,
            plan_provider.capability, plan_provider.domain, plan_provider.backend,
            plan_provider.backend_revision, plan_provider.code_hash,
            plan_provider.independence_group, plan_provider.claim_ceiling;
            input_schema_hash=plan_provider.input_schema_hash, executor=nothing)
        @test no_executor_plan_provider.manifest_hash ==
            native_plan.provider.manifest_hash
        changed_executor_plan = typeof(native_plan)(native_plan.compilation,
            native_plan.compile_result_hash, native_plan.protocol,
            native_plan.dependency_identity, no_executor_plan_provider,
            native_plan.subject, native_plan.solver_input,
            native_plan.adapter_source_hash, native_plan.plan_hash)
        @test !native_runtime.validate_native_g1g2_gridap_plan_admission_v1(
            changed_executor_plan, admission)
        println("UP2_R71_STAGE=admission_negative_checks_end_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)

        # Positive, service-scoped Gridap work is separately measured below;
        # it is not part of either controlled-negative mutation counter.
        chart_request = n09_context.requests["N09-02"]
        boundary_request = n09_context.requests["N09-03"]
        println("UP2_R71_STAGE=chart_mesh_execute_begin_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        chart_mesh = native_runtime._ng12_execute_gridap_service_v1(
            chart_request, chart_request.service, chart_request.provider.executor)
        println("UP2_R71_STAGE=chart_mesh_execute_end_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        @test chart_mesh isa native_runtime.NativeG1G2GridapChartMeshContextV1
        @test chart_mesh.plan_hash == native_plan.plan_hash
        @test chart_mesh.package_hash == case.package.package_hash
        println("UP2_R71_STAGE=boundary_execute_begin_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        boundary = native_runtime._ng12_execute_gridap_service_v1(
            boundary_request, boundary_request.service,
            boundary_request.provider.executor, chart_mesh)
        println("UP2_R71_STAGE=boundary_execute_end_ms=",
            (time_ns() - stage_started) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        @test boundary isa native_runtime.NativeG1G2GridapExteriorBoundaryContextV1
        @test boundary.plan_hash == native_plan.plan_hash
        @test boundary.chart_mesh_input_hash == chart_mesh.service_input_hash
        @test boundary.dirichlet_tag == "boundary"
        @test boundary.dirichlet_value == 0.0
        @test boundary.test_space !== nothing && boundary.trial_space !== nothing
        @test Set(owner.face for owner in boundary.face_owners) ==
            Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
        @test all(owner.kind === :dirichlet && iszero(owner.value) &&
            owner.gridap_dirichlet_tag == "boundary" &&
            owner.projected_gridap_boundary_cells ==
                owner.expected_gridap_boundary_cells for owner in boundary.face_owners)
        println("UP2_R71_STAGE=services_checked_ms=",
            (time_ns() - stage_started) / 1.0e6)
        flush(stdout)
        bad_measure = native_runtime.Measure(chart_mesh.omega,
            native_plan.protocol.quadrature_degree + 2)
        gridap = native_runtime.Gridap
        good_rule = first(gridap.CellData.get_cell_quadrature(
            chart_mesh.measure).cell_quad)
        bad_rule = first(gridap.CellData.get_cell_quadrature(
            bad_measure).cell_quad)
        good_coordinates = gridap.ReferenceFEs.get_coordinates(good_rule)
        bad_coordinates = gridap.ReferenceFEs.get_coordinates(bad_rule)
        good_weights = gridap.ReferenceFEs.get_weights(good_rule)
        bad_weights = gridap.ReferenceFEs.get_weights(bad_rule)
        @test length(good_weights) == 5^3
        @test length(bad_weights) == 6^3
        @test good_coordinates != bad_coordinates
        @test good_weights != bad_weights
        bad_mesh = native_runtime.NativeG1G2GridapChartMeshContextV1(
            chart_mesh.service, chart_mesh.service_input_hash,
            chart_mesh.provider_manifest_hash, chart_mesh.plan_hash,
            chart_mesh.candidate_ref, chart_mesh.package_hash,
            chart_mesh.g1_declaration_hash, chart_mesh.g2_declaration_hash,
            chart_mesh.form_hash, chart_mesh.level, chart_mesh.physical_domain,
            chart_mesh.cell_counts, chart_mesh.declared_mesh_quadrature_hash,
            chart_mesh.execution_quadrature_degree, chart_mesh.model,
            chart_mesh.reffe, chart_mesh.omega, bad_measure)
        @test_throws ArgumentError native_runtime._ng12_validate_chart_mesh_context_v1(
            native_plan, bad_mesh)
        @test_throws ArgumentError boundary_request.provider.executor(
            boundary_request.solver_input, bad_mesh,
            boundary_request.plan)
        tet_reffe = gridap.ReferenceFEs.LagrangianRefFE(Float64,
            gridap.ReferenceFEs.TET, 1)
        @test gridap.ReferenceFEs.get_polytope(tet_reffe) ==
            gridap.ReferenceFEs.TET
        @test gridap.ReferenceFEs.get_order(tet_reffe) == 1
        tet_mesh = native_runtime.NativeG1G2GridapChartMeshContextV1(
            chart_mesh.service, chart_mesh.service_input_hash,
            chart_mesh.provider_manifest_hash, chart_mesh.plan_hash,
            chart_mesh.candidate_ref, chart_mesh.package_hash,
            chart_mesh.g1_declaration_hash, chart_mesh.g2_declaration_hash,
            chart_mesh.form_hash, chart_mesh.level, chart_mesh.physical_domain,
            chart_mesh.cell_counts, chart_mesh.declared_mesh_quadrature_hash,
            chart_mesh.execution_quadrature_degree, chart_mesh.model,
            tet_reffe, chart_mesh.omega, chart_mesh.measure)
        @test_throws ArgumentError native_runtime._ng12_validate_chart_mesh_context_v1(
            native_plan, tet_mesh)
        @test_throws ArgumentError boundary_request.provider.executor(
            boundary_request.solver_input, tet_mesh,
            boundary_request.plan)
        @test_throws ArgumentError G._up2_vnext_n09_context(case.package,
            binding, merge(g2_geometry,
                (source_hash=G.canonical_hash((tampered_source=true,)),)),
            native_plan)
        if run === :current_source
            println("UP2_CURRENT_SOURCE_BOUNDARY=service_executor_negatives_complete")
            flush(stdout)
        end
    end
    for (id, expected) in (("N01-01", 0), ("N01-02", 0),
            ("N01-04", 3))
        spec = G.up2_spec_for_id(id)
        field = only(filter(x -> x.id == id, input.state.fields))
        state = only(filter(x -> x.field_id == id, input.field_states))
        source_value = id == "N01-04" ? g2_geometry.profile_dimension :
            g1_types.values[id]
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === :integer
        @test field.value isa G.UP2IntegerValueV1
        @test field.value.value == expected == source_value
        @test state.state === :source_present_deferred
        @test state.reason === (id == "N01-04" ?
            :candidate_design_g2_profile_contract_only :
            :candidate_design_g1_operator_type_contract_only)
        @test state.source_pin_roles == (id == "N01-04" ?
            (:g2_builder, :g2_declaration_source) :
            (:g1_builder, :g1_declaration_source))
    end
    expected_units = (
        "N02-01" => G.UnitSignature((0, 0, 0, 0, 0, 0, 0)),
        "N02-02" => G.UnitSignature((-2, 0, 0, 0, 0, 0, 0)))
    for (id, expected) in expected_units
        spec = G.up2_spec_for_id(id)
        field = only(filter(x -> x.id == id, input.state.fields))
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === :unit
        @test field.value isa G.UP2UnitValueV1
        @test field.value.value == expected == g1_types.values[id]
        @test state.state === :source_present_deferred
        @test state.reason === :candidate_design_g1_operator_type_contract_only
        @test state.source_pin_roles == (:g1_builder, :g1_declaration_source)
    end
    for (id, expected) in (("N03-01", G.UP2SymbolValueV1(:static_time)),
            ("N03-02", G.UP2IntegerValueV1(0)))
        spec = G.up2_spec_for_id(id)
        field = only(filter(x -> x.id == id, input.state.fields))
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === spec.source_type
        @test G.semantic_view(field.value) == G.semantic_view(expected)
        @test G.semantic_view(field.value) == G.semantic_view(
            id == "N03-01" ? G.UP2SymbolValueV1(g1_types.values[id]) :
                G.UP2IntegerValueV1(g1_types.values[id]))
        @test state.state === :source_present_deferred
        @test state.reason === :candidate_design_g1_diffusion_time_contract_only
        @test state.source_pin_roles == (:g1_builder, :g1_declaration_source)
    end

    g1_declaration = only(filter(d -> d.layer === :G1,
        case.package.declarations))
    g1_wire = JSON3.read(String(G.copy_bytes(g1_declaration.semantic_body_bytes)))
    grad_wire = g1_wire.operators.grad
    k_apply_wire = g1_wire.operators.coefficient_apply
    div_wire = g1_wire.operators.div
    g1_temporal_nodes = (
        g1_wire.u.physical_type.temporal_type,
        g1_wire.K.physical_type.temporal_type,
        g1_wire.f.physical_type.temporal_type,
        grad_wire.input_type.temporal_type,
        grad_wire.output_type.temporal_type,
        k_apply_wire.input_type.temporal_type,
        k_apply_wire.output_type.temporal_type,
        div_wire.input_type.temporal_type,
        div_wire.output_type.temporal_type)
    @test length(g1_temporal_nodes) == 9
    @test all(node -> String(node.kind) == "static_time" &&
        Int(node.derivative_order) == 0 && node.clock_ref === nothing,
        g1_temporal_nodes)
    n03_whitelist = only(filter(x -> x.id == "N03-03", input.state.fields))
    n03_whitelist_state = only(filter(x -> x.field_id == "N03-03",
        input.field_states))
    if run in (:r71, :current_source)
        n03_spec = G.up2_spec_for_id("N03-03")
        @test n03_whitelist.value isa G.UP2TupleValueV1
        @test n03_whitelist.value.values == (:static_time,)
        @test n03_whitelist.value.element_type === :timekind_v1
        @test n03_whitelist.field_path == n03_spec.field_path
        @test n03_whitelist.source_locator == n03_spec.source_locator
        @test n03_whitelist.source_type === n03_spec.source_type
        @test n03_whitelist_state.state === :source_present_deferred
        @test n03_whitelist_state.reason ===
            :candidate_design_g1_operator_temporal_whitelist_contract_only
        @test n03_whitelist_state.source_pin_roles ==
            (:g1_builder, :g1_declaration_source)
        n03_counter = G.UP2InvocationCounterV1()
        n03_mutation = if run === :current_source
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=n03_mutation_begin")
            flush(stdout)
            Base.cumulative_compile_timing(true)
            n03_compile_before = Base.cumulative_compile_time_ns()
            n03_timed = Base.@timed try
                G.up2_validate_mutation(input, n03_spec;
                    package=case.package, native_plan=native_plan,
                    counter=n03_counter, native_evidence_kwargs...,
                    identity_evidence_kwargs...)
            finally
                Base.cumulative_compile_timing(false)
            end
            n03_compile_delta = Base.cumulative_compile_time_ns() .- n03_compile_before
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=n03_mutation_complete elapsed_ms=$(n03_timed.time * 1000) compile_ms=$(n03_compile_delta[1] / 1.0e6) recompile_ms=$(n03_compile_delta[2] / 1.0e6)")
            flush(stdout)
            n03_timed.value
        else
            G.up2_validate_mutation(input, n03_spec;
                package=case.package, native_plan=native_plan,
                counter=n03_counter, native_evidence_kwargs...,
                identity_evidence_kwargs...)
        end
        @test n03_mutation.mutation_id == "N03-03"
        @test n03_mutation.status === :fail_closed
        @test n03_mutation.error_code === :invalid_type
        @test n03_mutation.error_path == n03_spec.field_path
        @test n03_mutation.detail == n03_spec.detail
        @test n03_mutation.input_hash == input.input_hash
        @test n03_mutation.mutated_input_hash != input.input_hash
        @test n03_mutation.compile_calls == n03_counter.compile_calls == 0
        @test n03_mutation.provider_calls == n03_counter.provider_calls == 0
        @test n03_mutation.solver_calls == n03_counter.solver_calls == 0
        @test !n03_mutation.evidence_reused
    else
        @test n03_whitelist.value isa G.UP2AbsentValueV1
        @test n03_whitelist.value.reason === :field_projector_not_implemented
        @test n03_whitelist_state.state === :source_present_deferred
        @test n03_whitelist_state.reason === :pinned_layer_source_field_projector_absent
        @test n03_whitelist_state.source_pin_roles ==
            (:g1_builder, :g1_declaration_source)
        @test_throws ArgumentError G.up2_validate_mutation(input,
            G.up2_spec_for_id("N03-03"); package=case.package,
            native_plan=native_plan)
    end
    @test input.state.fields[findfirst(x -> x.id == "N02-01",
        input.state.fields)].value.value != input.state.fields[findfirst(
        x -> x.id == "N02-02", input.state.fields)].value.value

    wrong_g1_builder_pins = Tuple(pin.role === :g1_builder ?
        G.UP2VNextSourcePinV1(pin.role, pin.byte_count,
            G.Digest256(repeat("0", 64))) : pin for pin in binding.source_pins)
    @test_throws ArgumentError G._up2_vnext_g1_operator_type_context(
        case.package, with_binding(source_pins=wrong_g1_builder_pins))
    g1_decl_index = findfirst(d -> d.layer === :G1, case.package.declarations)
    g1_decl = case.package.declarations[g1_decl_index]
    changed_g1_body = JSON3.read(String(G.copy_bytes(
        g1_decl.semantic_body_bytes)), Dict{String,Any})
    changed_g1_body["operators"]["grad"]["input_type"]["tensor_rank"] = 1
    changed_g1_semantic_bytes = G.VNextT1CanonicalBytesV2(collect(codeunits(
        G.canonical_json(changed_g1_body))))
    changed_g1_decl = G.VNextT1DeclarationManifestV2(g1_decl.layer,
        g1_decl.candidate_ref, g1_decl.source_ref, g1_decl.declaration_ref,
        g1_decl.axes, g1_decl.source_bytes, g1_decl.declaration_bytes,
        changed_g1_semantic_bytes, g1_decl.factory_receipt_bytes,
        g1_decl.declaration_receipt_bytes, g1_decl.source_identity_hash,
        g1_decl.declaration_identity_hash)
    changed_declarations = ntuple(i -> i == g1_decl_index ? changed_g1_decl :
        case.package.declarations[i], length(case.package.declarations))
    changed_semantic_package = G.CandidateStatePackageV5NextV2(
        case.package.schema_id, case.package.schema_version,
        case.package.canonicalization_version, case.package.profile_version,
        case.package.candidate_ref, case.package.bundle_hash,
        changed_declarations, case.package.children, case.package.feedback,
        case.package.axes, case.package.parent_commitments,
        case.package.g3_authority, case.package.wire,
        case.package.semantic_identity, case.package.package_hash,
        case.package.status, case.package.resolution, case.package.accepted,
        case.package.claim_ceiling)
    @test_throws ArgumentError G._up2_vnext_g1_operator_type_context(
        changed_semantic_package, binding)

    # Rehash the changed semantic body so this exercises the source-bound
    # reconstruction path rather than only the semantic-body byte checksum.
    dynamic_g1_body = JSON3.read(String(G.copy_bytes(
        g1_decl.semantic_body_bytes)), Dict{String,Any})
    dynamic_g1_body["operators"]["grad"]["output_type"]["temporal_type"]["kind"] =
        "dynamic_time"
    dynamic_g1_bytes = G.VNextT1CanonicalBytesV2(collect(codeunits(
        G.canonical_json(dynamic_g1_body))))
    @test dynamic_g1_bytes.sha256 ==
        G.Digest256(bytes2hex(SHA.sha256(G.copy_bytes(dynamic_g1_bytes))))
    dynamic_g1_decl = G.VNextT1DeclarationManifestV2(g1_decl.layer,
        g1_decl.candidate_ref, g1_decl.source_ref, g1_decl.declaration_ref,
        g1_decl.axes, g1_decl.source_bytes, g1_decl.declaration_bytes,
        dynamic_g1_bytes, g1_decl.factory_receipt_bytes,
        g1_decl.declaration_receipt_bytes, g1_decl.source_identity_hash,
        g1_decl.declaration_identity_hash)
    dynamic_g1_declarations = ntuple(i -> i == g1_decl_index ? dynamic_g1_decl :
        case.package.declarations[i], length(case.package.declarations))
    dynamic_g1_package = G.CandidateStatePackageV5NextV2(
        case.package.schema_id, case.package.schema_version,
        case.package.canonicalization_version, case.package.profile_version,
        case.package.candidate_ref, case.package.bundle_hash,
        dynamic_g1_declarations, case.package.children, case.package.feedback,
        case.package.axes, case.package.parent_commitments,
        case.package.g3_authority, case.package.wire,
        case.package.semantic_identity, case.package.package_hash,
        case.package.status, case.package.resolution, case.package.accepted,
        case.package.claim_ceiling)
    @test_throws ArgumentError G._up2_vnext_g1_operator_type_context(
        dynamic_g1_package, binding)
    if run in (:r71, :current_source)
        original_form = native_plan.compilation.form
        changed_package_form = typeof(original_form)(
            original_form.candidate_ref, dynamic_g1_package,
            original_form.t1_package_hash,
            original_form.t1_semantic_identity, original_form.t0_bundle_hash,
            original_form.g1_declaration, original_form.g2_declaration,
            original_form.programs, original_form.unit_profile,
            original_form.weak_form_sign, original_form.coordinate_semantics,
            original_form.boundary_semantics, original_form.form_hash)
        original_compilation = native_plan.compilation
        changed_package_compilation = typeof(original_compilation)(
            changed_package_form, original_compilation.capability,
            original_compilation.subject, original_compilation.scenario,
            original_compilation.compiler_source_hash,
            original_compilation.compilation_hash)
        changed_embedded_package_plan = typeof(native_plan)(
            changed_package_compilation, native_plan.compile_result_hash,
            native_plan.protocol, native_plan.dependency_identity,
            native_plan.provider, native_plan.subject, native_plan.solver_input,
            native_plan.adapter_source_hash, native_plan.plan_hash)
        @test dynamic_g1_package.package_hash == original_form.t1_package_hash
        @test dynamic_g1_package.semantic_identity ==
            original_form.t1_semantic_identity
        @test dynamic_g1_package.candidate_ref == original_form.candidate_ref
        @test dynamic_g1_package.bundle_hash == original_form.t0_bundle_hash
        @test dynamic_g1_package !== original_form.t1_package
        original_embedded_g1_decl =
            original_form.t1_package.declarations[g1_decl_index]
        @test G.copy_bytes(dynamic_g1_decl.semantic_body_bytes) !=
                G.copy_bytes(original_embedded_g1_decl.semantic_body_bytes)
        @test changed_embedded_package_plan.plan_hash == native_plan.plan_hash
        @test !native_runtime.validate_native_g1g2_gridap_plan_admission_v1(
            changed_embedded_package_plan, admission)
        @test_throws ArgumentError G._up2_vnext_n09_context(
            dynamic_g1_package, binding, g2_geometry, native_plan)
    end

    context = G._up2_vnext_n04_05_context(case.package, binding;
        include_child_design=run in (:r71, :current_source),
        identity_evidence_kwargs...)
    if run === :current_source
        @test context.rebuilt_child_design ===
            case.identity_package.g3.authored_payload.source_proof.rebuilt_child
    end
    typed = context.typed_ledger_context
    @test typed isa NamedTuple
    @test typed.identity_hash isa G.Digest256
    @test typed.source_sha256 isa G.Digest256
    @test typed.source_pin_sha256 isa G.Digest256
    @test typed.source_sha256 == typed.source_pin_sha256 ==
        case.source_pins.g3_child_design.sha256
    @test typed.owner == "local-authored-design-energy-account-owner"
    @test typed.entry_account_id == "design_energy"
    @test typed.entry_account_id in typed.account_ids
    @test typed.authority_scope === :local_source_data
    @test typed.authority_gap == "candidate_authored_typed_ledger_is_design_only"

    # The numerical producer and heat-lift producer run in their own bounded
    # leaf.  The current-source UP2 consumer only validates their serialized
    # receipts against this already rebuilt G3 source context.
    if run === :current_source
        R = Main.FusionRuntimeV4
        @test native_bundle isa R.NativeG1G2ExecutionBundleV1
        @test heat_lift_receipt isa R.NativeG1G2ScalarHeatLiftServiceReceiptV1
        report = native_report
            @test R.validate_native_g1g2_execution_bundle_v1(native_plan,
                native_bundle)
            @test R.validate_native_g1g2_gridap_report_v1(native_plan, report)
            @test report.status === :pass
            @test length(report.levels) == 3
            @test all(level -> level.status === :pass &&
                level.source_sign === :declared, report.levels)
            @test isapprox(report.levels[3].assembled_source_integral,
                3925 / 2592; atol=native_plan.protocol.source_integral_abs_tol,
                rtol=0.0)

            lift = typed.authored_heat_lift
            budget = lift.budget_join
            field_allocation = only(filter(entry ->
                entry.entry_id == "field_allocation", typed.entries))
            # G3 typed ledger uses kg,m,s basis; native sample units use m,kg,s.
            watts = G.UnitSignature((1, 2, -3, 0, 0, 0, 0))
            @test typed.source_sha256 == typed.source_pin_sha256 ==
                case.source_pins.g3_child_design.sha256
            @test typed.candidate_ref == binding.candidate_ref
            @test lift.candidate_id == typed.candidate_id
            @test lift.scenario_id == binding.scenario_id
            @test field_allocation.account_id == budget.account_id ==
                "design_energy"
            @test field_allocation.entry_id == budget.entry_id ==
                "field_allocation"
            @test field_allocation.port_id == budget.port_id == "diffusion_load"
            @test field_allocation.component_id == budget.component_id ==
                "diffusion_core"
            @test field_allocation.coefficient == budget.coefficient_w == -500
            @test field_allocation.unit == watts
            @test budget.limit_w == abs(field_allocation.coefficient) == 500
            @test R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, report, typed, heat_lift_receipt)
            # Reuse the already validated G2 projection for this same package
            # and binding; the public validator below still rebuilds it fresh.
            n09_context = G._up2_vnext_n09_context(case.package, binding,
                g2_geometry, native_plan; g3_source_context=context,
                native_report=report, heat_lift_receipt=heat_lift_receipt)
            @test !hasproperty(n09_context, :fe_boundary_energy_readout)
            n09_energy_context = G._up2_vnext_n09_context(case.package,
                binding, g2_geometry, native_plan; g3_source_context=context,
                native_report=report, heat_lift_receipt=heat_lift_receipt,
                include_fe_boundary_energy_readout=true)
            fe_energy = n09_energy_context.fe_boundary_energy_readout
            level3 = report.levels[3]
            fe_scale = heat_lift_receipt.result.conductivity_scale_w_m_k *
                heat_lift_receipt.result.temperature_scale_k
            @test fe_energy.domain ==
                "native-g1g2-gridap-fe-boundary-energy-readout-v1"
            @test fe_energy.candidate_ref == report.candidate_ref ==
                binding.candidate_ref
            @test fe_energy.scenario_id == heat_lift_receipt.result.scenario_id ==
                binding.scenario_id
            @test fe_energy.t1_package_hash == report.t1_package_hash ==
                binding.package_hash
            @test fe_energy.plan_hash == report.plan_hash == native_plan.plan_hash
            @test fe_energy.report_hash == report.report_hash
            @test fe_energy.level_hash == level3.level_hash
            @test fe_energy.heat_lift_result_hash ==
                heat_lift_receipt.result.result_hash
            @test fe_energy.authored_obligation_hash ==
                heat_lift_receipt.result.authored_obligation_hash
            @test fe_energy.source_sign === level3.source_sign === :declared
            @test fe_energy.source_balance_convention ===
                :div_fourier_q_equals_source
            @test fe_energy.heat_flux_convention ===
                :fourier_q_equals_minus_k_grad_temperature
            @test fe_energy.surface_trace_status === :diagnostic
            @test fe_energy.claim_ceiling === R.screen_only
            @test fe_energy.physical_status === :unknown
            @test fe_energy.scale_w_per_m == fe_scale
            @test fe_energy.discrete_trace_conormal_integral_m ==
                level3.discrete_trace_conormal_integral
            @test fe_energy.signed_conormal_power_w ==
                fe_scale * level3.discrete_trace_conormal_integral
            @test fe_energy.outward_fourier_loss_w ==
                -fe_energy.signed_conormal_power_w
            @test fe_energy.assembled_source_integral_m ==
                level3.assembled_source_integral
            @test fe_energy.assembled_source_power_w ==
                fe_scale * level3.assembled_source_integral
            @test fe_energy.fe_surface_balance_residual_w ==
                fe_energy.assembled_source_power_w -
                fe_energy.outward_fourier_loss_w
            @test !iszero(fe_energy.fe_surface_balance_residual_w)
            @test fe_energy.discrete_boundary_reaction_integral_m ==
                level3.discrete_boundary_reaction_integral
            @test fe_energy.algebraic_boundary_reaction_power_w ==
                fe_scale * level3.discrete_boundary_reaction_integral
            @test fe_energy.algebraic_boundary_balance_residual_w ==
                fe_scale * level3.discrete_boundary_reaction_balance_defect
            println("UP2_CURRENT_SOURCE_FE_BOUNDARY=", join((
                string(fe_energy.candidate_ref), fe_energy.report_hash.value,
                repr(fe_energy.discrete_trace_conormal_integral_m),
                repr(fe_energy.signed_conormal_power_w),
                repr(fe_energy.outward_fourier_loss_w),
                repr(fe_energy.assembled_source_power_w),
                repr(fe_energy.fe_surface_balance_residual_w),
                repr(fe_energy.algebraic_boundary_balance_residual_w),
                String(fe_energy.surface_trace_status),
                string(fe_energy.claim_ceiling)), "|"))
            @test n09_context.matches["N09-04"] === :unique_match
            @test n09_context.requests["N09-04"] === heat_lift_receipt
            # The input above came through the public current-source builder.
            n09_field = G._up2_find_field(result.input.state, "N09-04")
            @test n09_field.value isa G.UP2SymbolValueV1
            @test n09_field.value.value === :unique_match
            heat_result = heat_lift_receipt.result
            form = native_plan.compilation.form
            @test heat_result.candidate_ref == report.candidate_ref == binding.candidate_ref
            @test heat_result.t1_package_hash == report.t1_package_hash == binding.package_hash
            @test heat_result.scenario_id == binding.scenario_id
            @test heat_result.g1_source_ref == form.g1_declaration.source_ref
            @test heat_result.g1_source_hash == form.g1_declaration.source_hash
            @test heat_result.g2_source_ref == form.g2_declaration.source.source_ref
            @test heat_result.g2_source_hash == form.g2_declaration.source.source_hash
            @test heat_result.plan_hash == report.plan_hash == native_plan.plan_hash
            @test heat_result.report_hash == report.report_hash
            @test heat_result.source_sign === :declared
            @test isapprox(heat_result.source_integral_m, 3925 / 2592;
                atol=native_plan.protocol.source_integral_abs_tol, rtol=0.0)
            @test isapprox(heat_result.source_power_w, 3925 / 2592;
                atol=native_plan.protocol.source_integral_abs_tol, rtol=0.0)
            @test heat_result.source_power_limit_w == 500.0
            @test heat_result.source_power_w < heat_result.source_power_limit_w
            @test heat_lift_receipt.match.status === R.unique_match
            @test heat_lift_receipt.match.provider === heat_lift_receipt.provider
            @test heat_lift_receipt.provider.claim_ceiling === R.screen_only
            @test heat_lift_receipt.obligation.required_output ==
                ("T:K", "k:W_m_K", "q:W_m2", "source:W_m3", "integral:W")
            sample = heat_result.probe_sample
            @test all(isfinite, sample.point_m)
            @test all(isapprox(sample.point_m[i],
                (7 / 6, 11 / 6, 9 / 4)[i]; atol=1e-12, rtol=1e-12)
                for i in 1:3)
            @test sample.temperature_k ≈ 293 + sample.u_dimensionless
            @test isapprox(sample.u_dimensionless, 1 / 72;
                atol=1e-12, rtol=1e-12)
            @test sample.heat_flux_convention ===
                :fourier_q_equals_minus_k_grad_temperature
            @test sample.source_balance_convention ===
                :div_fourier_q_equals_source
            @test all(isfinite, sample.conductivity_diagonal_w_m_k)
            @test all(>(0), sample.conductivity_diagonal_w_m_k)
            @test isapprox(sample.conductivity_diagonal_w_m_k[1], 127 / 60;
                atol=1e-12, rtol=1e-12)
            @test all(isfinite, sample.gradient_temperature_k_m)
            @test sample.gradient_temperature_k_m[1] > 0
            @test isapprox(sample.gradient_temperature_k_m[1], 1 / 96;
                atol=1e-12, rtol=1e-12)
            @test sample.conductive_flux_w_m2[1] < 0
            @test isapprox(sample.conductive_flux_w_m2[1], -127 / 5760;
                atol=1e-12, rtol=1e-12)
            @test all(isapprox(sample.conductive_flux_w_m2[i],
                -sample.conductivity_diagonal_w_m_k[i] *
                sample.gradient_temperature_k_m[i]; atol=1e-12, rtol=1e-12)
                for i in 1:3)
            @test all(isfinite, sample.conductive_flux_w_m2)
            @test isfinite(sample.source_density_w_m3)
            expected_units = (
                point=G.UnitSignature((1, 0, 0, 0, 0, 0, 0)),
                u_dimensionless=G.UnitSignature(),
                temperature=G.UnitSignature((0, 0, 0, 0, 1, 0, 0)),
                conductivity=G.UnitSignature((1, 1, -3, 0, -1, 0, 0)),
                gradient_temperature=G.UnitSignature((-1, 0, 0, 0, 1, 0, 0)),
                conductive_flux=G.UnitSignature((0, 1, -3, 0, 0, 0, 0)),
                source_density=G.UnitSignature((-1, 1, -3, 0, 0, 0, 0)),
                source_integral=G.UnitSignature((1, 0, 0, 0, 0, 0, 0)),
                source_power=G.UnitSignature((2, 1, -3, 0, 0, 0, 0)),
                source_power_limit=G.UnitSignature((2, 1, -3, 0, 0, 0, 0)))
            @test sample.units == expected_units
            @test report.claim_ceiling === R.screen_only
            @test !report.accepted
            @test report.physical_status === :unknown
            @test native_bundle.invocation_counts.formal_t2_consumer_receipts == 0

            # A lower forged G3 limit would put the witnessed 3925/2592 W
            # demand over budget; it must be rejected because it no longer
            # joins the pinned source ledger or the existing receipt.
            low_budget = merge(budget,
                (coefficient_w=-1 // 1, limit_w=1 // 1))
            low_lift = merge(lift, (budget_join=low_budget,))
            low_context = merge(typed, (authored_heat_lift=low_lift,))
            @test heat_result.source_power_w > low_budget.limit_w
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, report, low_context, heat_lift_receipt)

            forged_entry = G.G3LedgerEntryV2(field_allocation.entry_id,
                field_allocation.account_id, field_allocation.port_id,
                field_allocation.component_id, -5000 // 1,
                field_allocation.unit, field_allocation.effect)
            forged_entries = Tuple(entry.entry_id == "field_allocation" ?
                forged_entry : entry for entry in typed.entries)
            forged_context = merge(typed, (entries=forged_entries,))
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, report, forged_context, heat_lift_receipt)

            # Rehash internally consistent foreign/stale and wrong-sign/quality
            # reports so these checks test binding/gates rather than a bad hash.
            rehash_level = function (level; source_sign=level.source_sign,
                    status=level.status)
                names = fieldnames(typeof(level))[1:end-1]
                args = Tuple(name === :source_sign ? source_sign :
                    name === :status ? status : getfield(level, name)
                    for name in names)
                R.NativeG1G2GridapLevelResultV1(args...,
                    G.canonical_hash(R._ng12_level_body(args...)))
            end
            rehash_report = function (source_report;
                    candidate_ref=source_report.candidate_ref,
                    plan_hash=source_report.plan_hash,
                    levels=source_report.levels,
                    status=source_report.status)
                l2_orders = R._ng12_orders(ntuple(i -> levels[i].l2_error, 3))
                h1_orders = R._ng12_orders(ntuple(i ->
                    levels[i].h1_seminorm_error, 3))
                args = (candidate_ref, source_report.t1_package_hash, plan_hash,
                    source_report.solver_input_hash, source_report.protocol_hash,
                    levels, l2_orders, h1_orders, status, source_report.resolution,
                    source_report.accepted, source_report.claim_ceiling,
                    source_report.numerical_scope, source_report.physical_status,
                    source_report.errors, source_report.gaps)
                R.NativeG1G2GridapReportV1(args...,
                    G.canonical_hash(R._ng12_report_body(args...)))
            end
            foreign_report = rehash_report(report; candidate_ref=
                G.QualifiedRefV1("fusionconceptai://candidate-design/foreign", "v5"))
            stale_report = rehash_report(report;
                plan_hash=G.digest256_text("stale-native-plan"))
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, foreign_report, typed, heat_lift_receipt)
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, stale_report, typed, heat_lift_receipt)

            wrong_sign_levels = (report.levels[1], report.levels[2],
                rehash_level(report.levels[3]; source_sign=:reversed_test_control))
            wrong_sign_report = rehash_report(report; levels=wrong_sign_levels)
            wrong_quality_levels = (report.levels[1], report.levels[2],
                rehash_level(report.levels[3]; status=:numerical_fail))
            wrong_quality_report = rehash_report(report;
                levels=wrong_quality_levels, status=:numerical_fail)
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, wrong_sign_report, typed, heat_lift_receipt)
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, wrong_quality_report, typed, heat_lift_receipt)

            capability = heat_lift_receipt.obligation
            mismatched_capability = R.CapabilitySignatureV4(
                capability.schema, capability.revision, capability.kind,
                capability.operator, capability.states, capability.source_space,
                capability.target_space, capability.dimension,
                capability.coordinates, "mutated_heat_lift_boundary",
                capability.interface_relation, capability.time_semantics,
                capability.required_output, capability.evidence_level,
                capability.applicability_bounds;
                input_schema_hash=capability.input_schema_hash,
                coordinate_system=capability.coordinate_system)
            mismatched = R.match_provider(mismatched_capability,
                (heat_lift_receipt.provider,))
            @test mismatched.status === R.out_of_domain
            @test mismatched.provider === nothing

            # The public consumer must accept the exact current input and reject
            # missing, foreign, stale, or forged evidence at its boundary.
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_positive_begin")
            flush(stdout)
            @test G.up2_validate_vnext_input(result.input; package=case.package,
                native_plan=native_plan, native_report=report,
                heat_lift_receipt=heat_lift_receipt, identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_positive_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_missing_report_begin")
            flush(stdout)
            @test_throws ArgumentError G.up2_validate_vnext_input(result.input;
                package=case.package, native_plan=native_plan,
                native_report=nothing, heat_lift_receipt=heat_lift_receipt,
                identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_missing_report_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_missing_receipt_begin")
            flush(stdout)
            @test_throws ArgumentError G.up2_validate_vnext_input(result.input;
                package=case.package, native_plan=native_plan,
                native_report=report, heat_lift_receipt=nothing,
                identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_missing_receipt_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_foreign_report_begin")
            flush(stdout)
            @test_throws ArgumentError G.up2_validate_vnext_input(result.input;
                package=case.package, native_plan=native_plan,
                native_report=foreign_report, heat_lift_receipt=heat_lift_receipt,
                identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_foreign_report_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_stale_report_begin")
            flush(stdout)
            @test_throws ArgumentError G.up2_validate_vnext_input(result.input;
                package=case.package, native_plan=native_plan,
                native_report=stale_report, heat_lift_receipt=heat_lift_receipt,
                identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_stale_report_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            forged_receipt = R.NativeG1G2ScalarHeatLiftServiceReceiptV1(
                heat_lift_receipt.service, heat_lift_receipt.obligation,
                heat_lift_receipt.provider, heat_lift_receipt.match,
                heat_lift_receipt.result, G.digest256_text("forged-heat-lift-receipt"),
                getfield(R, :_NG12_HEAT_LIFT_RECEIPT_SEAL_V1))
            @test_throws ArgumentError G._up2_vnext_n09_context(
                case.package, binding, g2_geometry, native_plan;
                g3_source_context=context, native_report=nothing,
                heat_lift_receipt=heat_lift_receipt,
                include_fe_boundary_energy_readout=true)
            @test_throws ArgumentError G._up2_vnext_n09_context(
                case.package, binding, g2_geometry, native_plan;
                g3_source_context=context, native_report=report,
                heat_lift_receipt=forged_receipt,
                include_fe_boundary_energy_readout=true)
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_forged_receipt_begin")
            flush(stdout)
            @test_throws ArgumentError G.up2_validate_vnext_input(result.input;
                package=case.package, native_plan=native_plan,
                native_report=report, heat_lift_receipt=forged_receipt,
                identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_forged_receipt_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            # Rehash both layers after changing the serialized probe sample so
            # validation must recompute the fixed point, not only check hashes.
            forged_probe_sample = merge(heat_result.probe_sample,
                (temperature_k=heat_result.probe_sample.temperature_k + 1.0,))
            forged_result_args = Tuple(name === :probe_sample ? forged_probe_sample :
                getfield(heat_result, name) for name in fieldnames(typeof(heat_result))[1:end-1])
            forged_result_hash = G.canonical_hash(
                R._ng12_scalar_heat_lift_body(forged_result_args...))
            forged_probe_result = R.NativeG1G2ScalarHeatLiftResultV1(
                forged_result_args..., forged_result_hash)
            forged_receipt_hash = G.canonical_hash(
                R._ng12_scalar_heat_lift_service_receipt_body(
                    heat_lift_receipt.service, heat_lift_receipt.obligation,
                    heat_lift_receipt.provider, heat_lift_receipt.match,
                    forged_probe_result))
            forged_probe_receipt = R.NativeG1G2ScalarHeatLiftServiceReceiptV1(
                heat_lift_receipt.service, heat_lift_receipt.obligation,
                heat_lift_receipt.provider, heat_lift_receipt.match,
                forged_probe_result, forged_receipt_hash,
                getfield(R, :_NG12_HEAT_LIFT_RECEIPT_SEAL_V1))
            @test !R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1(
                native_plan, report, typed, forged_probe_receipt)
            public_evidence_started = time_ns()
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_forged_probe_begin")
            flush(stdout)
            @test_throws ArgumentError G.up2_validate_vnext_input(result.input;
                package=case.package, native_plan=native_plan,
                native_report=report, heat_lift_receipt=forged_probe_receipt,
                identity_evidence_kwargs...)
            println("UP2_CURRENT_SOURCE_PUBLIC_TIMING=heat_forged_probe_complete elapsed_ms=$((time_ns() - public_evidence_started) / 1.0e6)")
            flush(stdout)
            if run === :current_source
                println("UP2_CURRENT_SOURCE_BOUNDARY=heat_lift_public_evidence_complete")
                flush(stdout)
            end
        end


    g3_declaration = only(filter(d -> d.layer === :G3, case.package.declarations))
    g3_body = JSON3.read(String(G.copy_bytes(g3_declaration.semantic_body_bytes)))
    ledger_wire = g3_body.authored_typed_ledger_source
    membership = only(ledger_wire.owner_scope_account_membership)
    g3_design_realization = g3_body.authored_child_design.realization
    source_bus = only(filter(port -> String(port.port_id) == "source_bus",
        g3_design_realization.ports))
    source_input_wire = only(filter(entry -> String(entry.entry_id) ==
        "source_input", g3_design_realization.ledger_entries))
    source_input = only(filter(entry -> entry.entry_id == "source_input",
        typed.entries))
    watts = G.UnitSignature((2, 1, -3, 0, 0, 0, 0))
    source_power_unit = run === :current_source && hasproperty(typed, :unit_basis) ?
        G.UnitSignature((1, 2, -3, 0, 0, 0, 0)) : watts
    source_bus_unit = G._up2_vnext_unit_signature(source_bus.unit)
    @test source_input_wire.port_id == source_bus.port_id
    @test source_input.port_id == String(source_bus.port_id) ==
        context.source_entry_port_id
    @test source_input.entry_id == "source_input"
    @test source_input.unit == source_power_unit ==
        G._up2_vnext_unit_signature(source_input_wire.unit)
    @test source_bus_unit == source_power_unit
    @test typed.source_pin_sha256 == case.source_pins.g3_child_design.sha256
    for (id, expected) in (("N02-04", source_bus_unit),
            ("N02-05", source_input.unit))
        spec = G.up2_spec_for_id(id)
        field = only(filter(x -> x.id == id, input.state.fields))
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === :unit
        @test field.value isa G.UP2UnitValueV1
        @test field.value.value == expected == source_power_unit
        @test state.state === :source_present_deferred
        @test state.reason === :candidate_design_g3_ledger_unit_design_only
        @test state.source_pin_roles == (:g3_builder, :g3_child_design)
    end
    # Rehash a structurally valid input whose N02 pair agrees internally but
    # disagrees with the positive source-bound W unit. Classification must
    # use this package's real G3 source context and reject the forged baseline.
    wrong_n02_unit = G.UnitSignature((3, 1, -3, 0, 0, 0, 0))
    wrong_n02_fields = Tuple(field.id in ("N02-04", "N02-05") ?
        G.UP2SemanticFieldV1(field.id, field.field_path, field.source_locator,
            field.source_type, G.UP2UnitValueV1(wrong_n02_unit)) : field
        for field in input.state.fields)
    wrong_n02_state = G.UP2PrecompilerStateV1(wrong_n02_fields,
        input.state.flux_pair)
    wrong_n02_input = G.UP2VNextPrecompilerInputV1(binding,
        input.mission_bounds, wrong_n02_state, input.field_states;
        provider_bindings=input.provider_bindings)
    @test wrong_n02_input.input_hash != input.input_hash
    @test G.up2_validate_vnext_input(wrong_n02_input; package=case.package,
        native_plan=native_plan, native_evidence_kwargs...,
        identity_evidence_kwargs...)
    @test only(filter(field -> field.id == "N02-04",
        wrong_n02_input.state.fields)).value.value ==
        only(filter(field -> field.id == "N02-05",
            wrong_n02_input.state.fields)).value.value == wrong_n02_unit
    wrong_n02_counter = G.UP2InvocationCounterV1()
    wrong_n02_error = try
        G.up2_validate_mutation(wrong_n02_input, G.up2_spec_for_id("N02-04");
            package=case.package, native_plan=native_plan,
            counter=wrong_n02_counter, native_evidence_kwargs...,
            identity_evidence_kwargs...)
        nothing
    catch err
        err
    end
    @test wrong_n02_error isa ArgumentError
    @test wrong_n02_error.msg ==
        "VNext N02-04 baseline differs from its source-pinned value"
    @test wrong_n02_counter.compile_calls == 0
    @test wrong_n02_counter.provider_calls == 0
    @test wrong_n02_counter.solver_calls == 0
    if run === :current_source
        println("UP2_CURRENT_SOURCE_BOUNDARY=wrong_n02_checks_complete")
        flush(stdout)
    end
    @test String(membership.owner_scope) != typed.owner
    @test String(ledger_wire.identity_hash.value) == typed.identity_hash.value
    @test String(ledger_wire.source_sha256.value) == typed.source_sha256.value
    for (id, expected, reason) in (
            ("N04-01", typed.owner,
                :candidate_design_ledger_owner_design_only),
            ("N04-03", typed.entry_account_id,
                :candidate_design_ledger_entry_account_design_only))
        spec = G.up2_spec_for_id(id)
        field = only(filter(x -> x.id == id, input.state.fields))
        state = only(filter(x -> x.field_id == id, input.field_states))
        @test field.field_path == spec.field_path
        @test field.source_locator == spec.source_locator
        @test field.source_type === :text
        @test field.value isa G.UP2TextValueV1
        @test field.value.value == expected
        @test state.state === :source_present_deferred
        @test state.reason === reason
        @test state.source_pin_roles == (:g3_builder, :g3_child_design)
    end

    # Rebuild the candidate typed view with a changed owner and changed membership.
    # Recompute each inner identity hash while the frozen child source pin stays fixed.
    owner_records = Tuple((account_id=String(row.account_id), owner=String(row.owner))
        for row in ledger_wire.account_owners)
    raw_membership = only(Tuple((owner_scope=String(row.owner_scope),
        account_ids=Tuple(String(id) for id in row.account_ids))
        for row in ledger_wire.owner_scope_account_membership))
    design = g3_body.authored_child_design
    child_input = g3_body.authored_child_design_input
    child_pin = only(filter(pin -> pin.role === :g3_child_design,
        binding.source_pins))
    child_values = child_input.bytes.values
    child_bytes = UInt8.(Int.(child_values))
    child_sha = G.Digest256(String(child_input.sha256.value))
    control_child = only(filter(child -> child.kind === :control,
        case.package.children))
    @test length(child_bytes) == Int(first(child_input.bytes.shape))
    @test bytes2hex(SHA.sha256(child_bytes)) == child_sha.value
    @test child_sha == child_pin.sha256 == control_child.source_bytes.sha256
    @test child_bytes == G.copy_bytes(control_child.source_bytes)
    invocation = if run === :current_source
        proof = case.identity_package.g3.authored_payload.source_proof
        hasproperty(proof, :g3_factory_invocation) ? proof.g3_factory_invocation : nothing
    else
        nothing
    end
    rebuilt_design = if invocation === nothing
        Base.invokelatest(G.vnext_t2_v3_rebuild_g3_child_design_source_v1,
            G.VNextT0LocalBytesV1(child_bytes, child_sha), child_pin.sha256,
            String(ledger_wire.source_path))
    else
        Base.invokelatest(G.vnext_t2_v3_rebuild_g3_child_design_source_v1,
            G.VNextT0LocalBytesV1(child_bytes, child_sha), child_pin.sha256,
            String(ledger_wire.source_path); candidate_id=invocation.candidate_id,
            scenario_id=invocation.scenario_id,
            re_enable_threshold_kelvin=invocation.re_enable_threshold_kelvin)
    end
    realization = rebuilt_design.realization
    @test rebuilt_design.candidate_id == binding.candidate_id
    @test rebuilt_design.scenario_id == binding.scenario_id
    @test rebuilt_design.source_path == String(ledger_wire.source_path)
    source_accounts = realization.ledger_accounts
    function rebuilt_ledger_wire(accounts, owners, owner_membership)
        body = (candidate_ref=binding.candidate_ref,
            candidate_id=binding.candidate_id, scenario_id=binding.scenario_id,
            source_path=String(ledger_wire.source_path),
            design_scope=:candidate_design_only,
            source_sha256=typed.source_sha256,
            source_accounts=source_accounts, account_owners=owners,
            owner_scope_account_membership=owner_membership,
            accounts=accounts, entries=typed.entries, closures=typed.closures,
            balances=typed.balances, claim_ceiling=:contract_only,
            physical_validation=false, engineering_validation=false,
            measurement_authority=false, upstream_G1_authority=:missing,
            upstream_G2_authority=:missing)
        if hasproperty(typed, :unit_basis)
            body = merge(body, (unit_basis=typed.unit_basis,
                resource_network=typed.resource_network,
                effort_ports_without_ledger=typed.effort_ports_without_ledger,
                authored_power_laws=typed.authored_power_laws,
                authored_heat_lift=typed.authored_heat_lift,
                control_resource_links=typed.control_resource_links,
                command_to_current_map=typed.command_to_current_map,
                command_to_power_map=typed.command_to_power_map,
                power_status_signal_id=typed.power_status_signal_id,
                source_unit_contract=:declared_si_candidate_design_v2))
        end
        merge(body, (identity_hash=G.canonical_hash(body),))
    end
    valid_wire = rebuilt_ledger_wire(typed.accounts, owner_records,
        (raw_membership,))
    @test valid_wire.identity_hash == typed.identity_hash
    wrong_owner = owner_records[1].owner * "_tampered"
    changed_owners = Tuple(i == 1 ?
        (account_id=row.account_id, owner=wrong_owner) : row
        for (i, row) in enumerate(owner_records))
    changed_accounts = Tuple(i == 1 ? G.G3LedgerAccountV2(account.account_id,
        account.domain, account.unit, wrong_owner) : account
        for (i, account) in enumerate(typed.accounts))
    owner_tampered_wire = rebuilt_ledger_wire(changed_accounts, changed_owners,
        (raw_membership,))
    @test owner_tampered_wire.identity_hash != typed.identity_hash
    @test owner_tampered_wire.source_sha256 == typed.source_sha256
    @test owner_tampered_wire.account_owners[1].owner ==
        owner_tampered_wire.accounts[1].owner
    @test only(filter(pin -> pin.role === :g3_child_design,
        binding.source_pins)).sha256 == typed.source_pin_sha256
    @test_throws ArgumentError G._up2_vnext_typed_ledger_context(
        owner_tampered_wire, design, realization, rebuilt_design, binding)
    changed_membership = (owner_scope=raw_membership.owner_scope * "_tampered",
        account_ids=Tuple("__tampered__" * id for id in raw_membership.account_ids))
    membership_tampered_wire = rebuilt_ledger_wire(typed.accounts,
        owner_records, (changed_membership,))
    @test membership_tampered_wire.identity_hash != typed.identity_hash
    @test membership_tampered_wire.source_sha256 == typed.source_sha256
    @test membership_tampered_wire.owner_scope_account_membership[1].owner_scope !=
        raw_membership.owner_scope
    @test membership_tampered_wire.owner_scope_account_membership[1].account_ids !=
        raw_membership.account_ids
    @test_throws ArgumentError G._up2_vnext_typed_ledger_context(
        membership_tampered_wire, design, realization, rebuilt_design, binding)

    foreign_ref = G.QualifiedRefV1(
        "fusionconceptai://candidate-design/not-the-r69-candidate", "v5")
    @test_throws ArgumentError G._up2_vnext_n04_05_context(case.package,
        with_binding(candidate_ref=foreign_ref,
            candidate_id="not-the-r69-candidate"))
    @test_throws ArgumentError G._up2_vnext_n04_05_context(case.package,
        with_binding(package_hash=G.Digest256(repeat("0", 64))))
    if run === :current_source
        @test_throws ArgumentError G._up2_vnext_n04_05_context(case.package,
            with_binding(candidate_ref=foreign_ref,
                candidate_id="not-the-r69-candidate");
            include_child_design=true, identity_package=case.identity_package)
    end

    # Integrity-only tamper case: rehash a changed G3 body but retain the old
    # package identity. Its expected rejection may occur at package/source
    # binding; the source-specific N02 baseline rejection is exercised above.
    g3_decl_index = findfirst(d -> d.layer === :G3, case.package.declarations)
    original_g3_decl = case.package.declarations[g3_decl_index]
    changed_g3_unit_body = JSON3.read(String(G.copy_bytes(
        original_g3_decl.semantic_body_bytes)), Dict{String,Any})
    changed_g3_design_realization =
        changed_g3_unit_body["authored_child_design"]["realization"]
    changed_source_bus_wire = only(filter(port -> port["port_id"] == "source_bus",
        changed_g3_design_realization["ports"]))
    @test changed_source_bus_wire["unit"]["exponents"][1]["numerator"] ==
        (hasproperty(typed, :unit_basis) ? 1 : 2)
    changed_source_bus_wire["unit"]["exponents"][1] =
        Dict("numerator" => 3, "denominator" => 1)
    changed_g3_unit_bytes = G.VNextT1CanonicalBytesV2(collect(codeunits(
        G.canonical_json(changed_g3_unit_body))))
    @test changed_g3_unit_bytes.sha256 ==
        G.Digest256(bytes2hex(SHA.sha256(G.copy_bytes(changed_g3_unit_bytes))))
    changed_g3_unit_decl = G.VNextT1DeclarationManifestV2(
        original_g3_decl.layer, original_g3_decl.candidate_ref,
        original_g3_decl.source_ref, original_g3_decl.declaration_ref,
        original_g3_decl.axes, original_g3_decl.source_bytes,
        original_g3_decl.declaration_bytes, changed_g3_unit_bytes,
        original_g3_decl.factory_receipt_bytes,
        original_g3_decl.declaration_receipt_bytes,
        original_g3_decl.source_identity_hash,
        original_g3_decl.declaration_identity_hash)
    changed_g3_unit_declarations = ntuple(i -> i == g3_decl_index ?
        changed_g3_unit_decl : case.package.declarations[i],
        length(case.package.declarations))
    changed_g3_unit_package = G.CandidateStatePackageV5NextV2(
        case.package.schema_id, case.package.schema_version,
        case.package.canonicalization_version, case.package.profile_version,
        case.package.candidate_ref, case.package.bundle_hash,
        changed_g3_unit_declarations, case.package.children,
        case.package.feedback, case.package.axes, case.package.parent_commitments,
        case.package.g3_authority, case.package.wire,
        case.package.semantic_identity, case.package.package_hash,
        case.package.status, case.package.resolution, case.package.accepted,
        case.package.claim_ceiling)
    @test changed_g3_unit_decl.semantic_body_bytes.sha256 !=
        original_g3_decl.semantic_body_bytes.sha256
    @test_throws ArgumentError G._up2_vnext_n04_05_context(
        changed_g3_unit_package, binding)
    if run in (:r71, :current_source)
        altered_candidate_ref = G.QualifiedRefV1(
            case.package.candidate_ref.id * "/tampered",
            case.package.candidate_ref.version)
        altered_candidate_package = G.CandidateStatePackageV5NextV2(
            case.package.schema_id, case.package.schema_version,
            case.package.canonicalization_version, case.package.profile_version,
            altered_candidate_ref, case.package.bundle_hash,
            case.package.declarations, case.package.children,
            case.package.feedback, case.package.axes, case.package.parent_commitments,
            case.package.g3_authority, case.package.wire,
            case.package.semantic_identity, case.package.package_hash,
            case.package.status, case.package.resolution, case.package.accepted,
            case.package.claim_ceiling)
        @test_throws ArgumentError G._up2_vnext_n09_context(
            altered_candidate_package, binding, g2_geometry, native_plan)
    end

    n06_04_present = context.typed_ledger_context !== nothing
    n06_network_present = run === :current_source && typed isa NamedTuple &&
        hasproperty(typed, :resource_network) &&
        hasproperty(typed, :authored_power_laws) &&
        hasproperty(typed, :control_resource_links)
    if run === :current_source
        println("UP2_CURRENT_SOURCE_BOUNDARY=n10_binding_presence_begin")
        flush(stdout)
    end
    n10_binding_present = run === :current_source &&
        G._up2_vnext_n10_identity_context(case.package, binding).contract_refs.binding !== nothing
    if run === :current_source
        @test n06_04_present
        @test n06_network_present
        n06_network = typed.resource_network
        n06_ports = n06_network.resource_ports
        n06_source_voltage = only(Tuple(port for port in n06_ports
            if port.port_id == "source_voltage"))
        @test typed.effort_ports_without_ledger == ("source_voltage",)
        @test isempty(G.g3_validate_resource_network(n06_network;
            effort_ports_without_ledger=typed.effort_ports_without_ledger))
        @test !any(entry -> entry.port_id == n06_source_voltage.port_id,
            n06_network.entries)
        @test any(account -> account.account_id == n06_source_voltage.account_id,
            n06_network.accounts)
        @test any(closure -> n06_source_voltage.account_id in closure.account_ids,
            n06_network.closures)
        @test "missing_consumable_entry:source_voltage" in
            G.g3_validate_resource_network(n06_network)
        source_voltage_account = only(Tuple(account for account in n06_network.accounts
            if account.account_id == n06_source_voltage.account_id))
        source_voltage_component = only(Tuple(component for component in n06_network.components
            if n06_source_voltage.port_id in component.resource_port_ids))
        source_voltage_entry = G.G3LedgerEntryV2("n06_forbidden_effort_entry",
            n06_source_voltage.account_id, n06_source_voltage.port_id,
            source_voltage_component.component_id, 1 // 1,
            source_voltage_account.unit, :load)
        network_with_waived_effort_entry = G.G3ResourceNetworkV2(
            n06_network.components, n06_network.resource_ports, n06_network.accounts,
            (n06_network.entries..., source_voltage_entry), n06_network.closures)
        @test "waived_effort_port_has_ledger_entry:source_voltage" in
            G.g3_validate_resource_network(network_with_waived_effort_entry;
                effort_ports_without_ledger=typed.effort_ports_without_ledger)
        n06_source_current = only(Tuple(port for port in n06_ports
            if port.port_id == "source_supply_current"))
        n06_source_law = only(Tuple(law for law in typed.authored_power_laws
            if law.law_id == "source_bus_VI"))
        n06_link = only(typed.control_resource_links)
        for id in ("N06-01", "N06-03", "N06-05")
            field = only(filter(x -> x.id == id, input.state.fields))
            state = only(filter(x -> x.field_id == id, input.field_states))
            spec = G.up2_spec_for_id(id)
            @test field.field_path == spec.field_path
            @test field.source_locator == spec.source_locator
            @test state.state === :source_present_deferred
            expected_n06_reason = id == "N06-03" ?
                :candidate_design_g3_control_flow_link_design_only :
                :candidate_design_g3_typed_resource_network_contract_only
            @test state.reason === expected_n06_reason
            @test state.source_pin_roles == (:g3_builder, :g3_child_design)
        end
        n06_ports_field = only(filter(x -> x.id == "N06-01", input.state.fields))
        @test n06_ports_field.source_type === :tuple
        @test n06_ports_field.value isa G.UP2TupleValueV1
        @test n06_ports_field.value.element_type === :G3ResourcePortV2
        @test G.canonical_hash(n06_ports_field.value.values) == G.canonical_hash(n06_ports)
        n06_link_field = only(filter(x -> x.id == "N06-03", input.state.fields))
        @test n06_link_field.source_type === :text
        @test n06_link_field.value isa G.UP2TextValueV1
        @test n06_link_field.value.value == n06_link.resource_port_id ==
            n06_source_current.port_id == "source_supply_current"
        n06_kind_field = only(filter(x -> x.id == "N06-05", input.state.fields))
        @test n06_kind_field.source_type === :symbol
        @test n06_kind_field.value isa G.UP2SymbolValueV1
        @test n06_kind_field.value.value == n06_ports[1].kind == :effort
        @test n06_ports[1].port_id == "source_voltage"
        @test n06_source_voltage.kind === :effort
        @test n06_source_voltage.unit == G.UnitSignature((1, 2, -3, -1, 0, 0, 0))
        @test n06_source_current.kind === :flow
        @test n06_source_current.unit == G.UnitSignature((0, 0, 0, 1, 0, 0, 0))
        @test n06_source_law.effort_port_id == n06_source_voltage.port_id
        @test n06_source_law.current_port_id == n06_source_current.port_id
        @test n06_source_law.power_endpoint_id == "source_bus"
        @test n06_source_law.voltage == 500 // 1
        @test n06_source_law.current == 2 // 1
        @test n06_source_law.power == 1000 // 1
        @test n06_source_law.voltage * n06_source_law.current == n06_source_law.power
        @test n06_source_law.voltage_unit == n06_source_voltage.unit
        @test n06_source_law.current_unit == n06_source_current.unit
        @test n06_source_law.power_unit == G.UnitSignature((1, 2, -3, 0, 0, 0, 0))
        @test n06_link.controller_id == "candidate_thermal_supervisor"
        @test n06_link.sensor_port_id == "core_temperature"
        @test n06_link.actuator_port_id == "source_fraction_command"
        @test n06_link.fault_id == "core_overtemperature_trip"
        @test typed.power_status_signal_id == "source_power_resource"
        @test typed.power_status_signal_id != n06_link.resource_port_id
        g1_for_n10 = only(filter(d -> d.layer === :G1, case.package.declarations))
        changed_factory_wire = G._up2_n10_json_semantic(JSON3.read(String(G.copy_bytes(
            g1_for_n10.factory_receipt_bytes))))
        @test G.canonical_json(changed_factory_wire) ==
            String(G.copy_bytes(g1_for_n10.factory_receipt_bytes))
        old_schema = changed_factory_wire["contract_ref"]["schema_hash"]["value"]
        changed_factory_wire["contract_ref"]["schema_hash"]["value"] =
            old_schema == repeat("0", 64) ? repeat("1", 64) : repeat("0", 64)
        tampered_factory_bytes = G.VNextT1CanonicalBytesV2(collect(codeunits(
            G.canonical_json(changed_factory_wire))))
        @test tampered_factory_bytes.sha256 != g1_for_n10.factory_receipt_bytes.sha256
        g1_index_for_n10 = findfirst(d -> d.layer === :G1, case.package.declarations)
        tampered_g1 = G.VNextT1DeclarationManifestV2(g1_for_n10.layer,
            g1_for_n10.candidate_ref, g1_for_n10.source_ref,
            g1_for_n10.declaration_ref, g1_for_n10.axes,
            g1_for_n10.source_bytes, g1_for_n10.declaration_bytes,
            g1_for_n10.semantic_body_bytes, tampered_factory_bytes,
            g1_for_n10.declaration_receipt_bytes,
            g1_for_n10.source_identity_hash, g1_for_n10.declaration_identity_hash)
        tampered_declarations = ntuple(i -> i == g1_index_for_n10 ?
            tampered_g1 : case.package.declarations[i],
            length(case.package.declarations))
        tampered_semantic_identity = G.canonical_hash(
            G._vnext_t1_v2_identity_manifest(case.package.candidate_ref,
                case.package.bundle_hash, tampered_declarations, case.package.children,
                case.package.feedback, case.package.axes, case.package.parent_commitments,
                case.package.g3_authority, case.package.wire))
        tampered_pre_hash = G.CandidateStatePackageV5NextV2(
            case.package.schema_id, case.package.schema_version,
            case.package.canonicalization_version, case.package.profile_version,
            case.package.candidate_ref, case.package.bundle_hash, tampered_declarations,
            case.package.children, case.package.feedback, case.package.axes,
            case.package.parent_commitments, case.package.g3_authority, case.package.wire,
            tampered_semantic_identity, case.package.package_hash, case.package.status,
            case.package.resolution, case.package.accepted, case.package.claim_ceiling)
        tampered_package_hash = G.vnext_t1_package_v2_manifest_hash(tampered_pre_hash)
        tampered_package = G.CandidateStatePackageV5NextV2(
            tampered_pre_hash.schema_id, tampered_pre_hash.schema_version,
            tampered_pre_hash.canonicalization_version, tampered_pre_hash.profile_version,
            tampered_pre_hash.candidate_ref, tampered_pre_hash.bundle_hash,
            tampered_pre_hash.declarations, tampered_pre_hash.children,
            tampered_pre_hash.feedback, tampered_pre_hash.axes,
            tampered_pre_hash.parent_commitments, tampered_pre_hash.g3_authority,
            tampered_pre_hash.wire, tampered_pre_hash.semantic_identity,
            tampered_package_hash, tampered_pre_hash.status, tampered_pre_hash.resolution,
            tampered_pre_hash.accepted, tampered_pre_hash.claim_ceiling)
        @test G.vnext_t1_package_v2_validate(tampered_package) === nothing
        tampered_io = IOBuffer()
        Serialization.serialize(tampered_io, tampered_package)
        seekstart(tampered_io)
        tampered_reloaded = Serialization.deserialize(tampered_io)
        @test tampered_reloaded.package_hash == tampered_package.package_hash
        tampered_result = case.build(p=tampered_reloaded, native_plan=native_plan;
            native_evidence_kwargs...)
        @test tampered_result.status === :fail_closed
        @test tampered_result.input === nothing
        @test tampered_result.reason === :vnext_n09_native_service_context_invalid
        for id in ("N06-02", "N06-04")
            field = only(filter(x -> x.id == id, input.state.fields))
            state = only(filter(x -> x.field_id == id, input.field_states))
            @test !(field.value isa G.UP2AbsentValueV1)
            @test state.state === :source_present_deferred
            @test state.reason ==
                (id == "N06-02" ?
                    :candidate_design_g3_ledger_entries_design_only :
                    :candidate_design_g3_closure_balance_design_only)
        end
    end
    n06_ids = n06_04_present ? ("N06-02", "N06-04") : ()
    supported_r69_ids = ("N01-01", "N01-02", "N01-04", "N02-01", "N02-02",
        "N02-04", "N02-05", "N03-01", "N03-02", "N03-04", "N03-05", "N04-01", "N04-02", "N04-03", "N04-04",
        "N04-05", n06_ids..., "N07-01", "N07-02", "N07-03", "N07-05", "N08-02",
        "N08-03")
    @test length(supported_r69_ids) == 22 + 2 * Int(n06_04_present)
    supported_r70_ids =
        (supported_r69_ids..., "N01-03", "N01-05", "N02-03", "N08-04")
    @test length(supported_r70_ids) == 26 + 2 * Int(n06_04_present)
    supported_r71_ids =
        (supported_r70_ids..., "N03-03", "N07-04", "N08-01",
            "N09-01", "N09-02", "N09-03",
            (n09_05_present ? ("N09-05",) : ())...)
    supported_current_source_ids = (supported_r71_ids...,
            (n06_network_present ? ("N06-01", "N06-03", "N06-05") : ())...,
            (n09_04_present ? ("N09-04",) : ())...,
            "N08-05", "N05-01", "N05-02", "N05-03", "N05-04", "N05-05",
            "N10-01", "N10-02",
            (n10_binding_present ? ("N10-03",) : ())...,
            "N10-04", "N10-05")
    @test length(supported_r71_ids) == 32 + 2 * Int(n06_04_present) + Int(n09_05_present)
    @test run !== :current_source || n06_04_present && n09_05_present &&
        !(only(filter(x -> x.id == "N08-05", input.state.fields)).value isa
            G.UP2AbsentValueV1)
    supported_ids = run === :r71 ? supported_r71_ids :
        run === :current_source ? supported_current_source_ids :
        run === :r70 ? supported_r70_ids : supported_r69_ids
    @test length(supported_ids) ==
        (run === :current_source ? 42 + Int(n09_05_present) +
                Int(n10_binding_present) + Int(n09_04_present) +
                3 * Int(n06_network_present) :
            run === :r71 ? 32 + Int(n09_05_present) : run === :r70 ? 26 : 22) +
            2 * Int(n06_04_present)
    @test run !== :current_source || n06_04_present && n06_network_present &&
        n09_04_present && n09_05_present && n10_binding_present
    @test run !== :current_source || length(supported_ids) == 50
    function _up2_b04_boundary_snapshot(package, input)
        g1_g2 = Tuple(d for d in package.declarations if d.layer in (:G1, :G2))
        Tuple(d.layer for d in g1_g2) == (:G1, :G2) ||
            throw(ArgumentError("B04 requires the actual T1 G1/G2 declaration carriers"))
        package.candidate_ref == input.source_binding.candidate_ref ||
            throw(ArgumentError("B04 T1 package/input candidate refs differ"))
        carriers = Tuple((layer=String(d.layer), carrier=String(name),
            bytes=length(raw), sha256=bytes2hex(SHA.sha256(raw)))
            for d in g1_g2 for (name, carrier) in
                ((:source, d.source_bytes), (:declaration, d.declaration_bytes),
                 (:semantic_body, d.semantic_body_bytes))
            for raw in (G.copy_bytes(carrier),))
        (candidate_ref=package.candidate_ref.id,
         input_hash=input.input_hash.value,
         package_hash=package.package_hash.value,
         carriers=carriers)
    end
    function _up2_b04_archive_snapshot(archive)
        records = [(candidate_ref=record.candidate_ref,
            stage=String(record.stage),
            signature_hash=G.canonical_hash(record.signature).value,
            match_status=string(record.match_status), reason=record.reason,
            retry_registry_hash=record.retry_registry_hash.value)
            for record in values(archive.deferred)]
        sort!(records, by=record ->
            (record.candidate_ref, record.stage, record.signature_hash))
        ordered = Tuple(records)
        (record_count=length(ordered),
            state_hash=G.canonical_hash(ordered).value, records=ordered)
    end

    Base.@nospecializeinfer function typed_mutation_summary(candidate_package,
            candidate_input, candidate_g1_context, candidate_g2_context,
            candidate_g3_context; candidate_native_plan=nothing,
            candidate_n09_context=nothing, candidate_native_report=nothing,
            candidate_heat_lift_receipt=nothing, batch_label=:primary,
            candidate_identity_package=nothing)
        Base.@nospecialize candidate_package
        Base.@nospecialize candidate_input
        Base.@nospecialize candidate_g1_context
        Base.@nospecialize candidate_g2_context
        Base.@nospecialize candidate_g3_context
        Base.@nospecialize candidate_native_plan
        Base.@nospecialize candidate_n09_context
        Base.@nospecialize candidate_native_report candidate_heat_lift_receipt candidate_identity_package
        candidate_identity_kwargs = candidate_identity_package === nothing ?
            (;) : (; identity_package=candidate_identity_package)
        n10_context_started = time_ns()
        n10_context = run === :current_source ?
            G._up2_vnext_n10_identity_context(candidate_package,
                candidate_input.source_binding) : nothing
        identity_n10_context = candidate_identity_package === nothing ? n10_context :
            G._up2_vnext_n10_current_package_context(candidate_package,
                candidate_input.source_binding, candidate_identity_package,
                n10_context, n10_context.g1_context, n10_context.geometry_context,
                G._up2_vnext_n04_05_context(candidate_package,
                    candidate_input.source_binding; include_child_design=true,
                    candidate_identity_kwargs...))
        if run === :current_source
            n10_context_ms = (time_ns() - n10_context_started) / 1.0e6
            println("UP2_MUTATION_TIMING batch=$(batch_label) phase=n10_contexts_ready context_ms=$(n10_context_ms)")
            flush(stdout)
        end
        batch_validation_contexts = nothing
        if run === :current_source
            ref_from_bytes = raw -> G.GenomeContractRef(String(raw.uri),
                String(raw.version), G.Digest256(String(raw.schema_hash.value)),
                G.Digest256(String(raw.canonicalization_hash.value)),
                String(raw.compatibility_profile))
            for (layer, context_ref) in ((:G1, n10_context.contract_refs.g1),
                    (:G2, n10_context.contract_refs.g2))
                declaration = only(filter(d -> d.layer === layer,
                    candidate_package.declarations))
                receipt = JSON3.read(String(G.copy_bytes(
                    declaration.factory_receipt_bytes)))
                declaration_receipt = JSON3.read(String(G.copy_bytes(
                    declaration.declaration_receipt_bytes)))
                @test G.semantic_view(context_ref) == G.semantic_view(
                    ref_from_bytes(receipt.contract_ref))
                @test G.semantic_view(context_ref) == G.semantic_view(
                    ref_from_bytes(declaration_receipt.contract_ref))
            end
            transport_wire = JSON3.read(String(G.copy_bytes(candidate_package.wire)))
            binding_child = only(filter(child -> String(child.kind) == "binding",
                transport_wire.children))
            binding_ref_present = haskey(binding_child.body, "contract_ref")
            @test binding_ref_present == (n10_context.contract_refs.binding !== nothing)
            if binding_ref_present
                @test G.semantic_view(n10_context.contract_refs.binding) ==
                    G.semantic_view(ref_from_bytes(binding_child.body.contract_ref))
            end
            for n10_id in ("N10-01", "N10-02")
                n10_spec = G.up2_spec_for_id(n10_id)
                n10_ref = n10_id == "N10-01" ? n10_context.contract_refs.g1 :
                    n10_context.contract_refs.g2
                @test n10_ref isa G.GenomeContractRef
                n10_expected = n10_id == "N10-01" ?
                    G.UP2HashValueV1(n10_ref.schema_hash) :
                    G.UP2HashValueV1(n10_ref.canonicalization_hash)
                n10_field = only(filter(f -> f.id == n10_id,
                    candidate_input.state.fields))
                n10_state = only(filter(s -> s.field_id == n10_id,
                    candidate_input.field_states))
                @test n10_field.field_path == n10_spec.field_path
                @test n10_field.source_locator == n10_spec.source_locator
                @test n10_field.source_type === n10_spec.source_type
                @test G.semantic_view(n10_field.value) ==
                    G.semantic_view(n10_expected)
                @test n10_state.state === :source_present_deferred
                @test n10_state.reason ===
                    :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity
                @test n10_state.source_pin_roles ==
                    (n10_id == "N10-01" ?
                        (:g1_builder, :g1_declaration_source) :
                        (:g2_builder, :g2_declaration_source))
            end
            for (n10_id, n10_expected, n10_reason) in (
                    ("N10-04", G.UP2HashValueV1(candidate_identity_package.candidate_hash),
                        :current_vnext_t0_t1_component_identity_compatibility_view),
                    ("N10-05", G.UP2TextValueV1(candidate_identity_package.migration_receipt.candidate_identity_after),
                        :current_vnext_t0_t1_fresh_identity_receipt_not_v4_migration))
                n10_spec = G.up2_spec_for_id(n10_id)
                n10_field = only(filter(f -> f.id == n10_id, candidate_input.state.fields))
                n10_state = only(filter(st -> st.field_id == n10_id, candidate_input.field_states))
                @test n10_field.field_path == n10_spec.field_path
                @test n10_field.source_locator == n10_spec.source_locator
                @test n10_field.source_type === n10_spec.source_type
                @test G.semantic_view(n10_field.value) == G.semantic_view(n10_expected)
                @test n10_state.state === :source_present_deferred
                @test n10_state.reason === n10_reason
                @test n10_state.source_pin_roles ==
                    (:g1_builder, :g1_declaration_source, :g2_builder,
                     :g2_declaration_source, :g3_builder, :g3_child_design)
            end
            n10_binding_field = only(filter(f -> f.id == "N10-03",
                candidate_input.state.fields))
            n10_binding_state = only(filter(s -> s.field_id == "N10-03",
                candidate_input.field_states))
            if n10_binding_present
                @test n10_binding_field.value isa G.UP2ContractRefValueV1
                @test n10_binding_state.state === :source_present_deferred
                @test n10_binding_state.reason ===
                    :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity
                @test n10_binding_state.source_pin_roles ==
                    (:g3_builder, :g3_child_design)
            else
                @test n10_binding_field.value isa G.UP2AbsentValueV1
                @test n10_binding_state.state === :typed_absent
                @test n10_binding_state.reason ===
                    :n10_binding_t0_child_contract_ref_absent
                @test isempty(n10_binding_state.source_pin_roles)
            end
            flux_pair = candidate_g1_context.interface_flux_pair
            geometry = candidate_g2_context.interface_flux_geometry
            @test flux_pair isa NamedTuple
            @test geometry isa NamedTuple
            @test flux_pair.interface_ref == geometry.interface_ref
            @test flux_pair.left_region == geometry.left_region == "local_unit_cube_left"
            @test flux_pair.right_region == geometry.right_region == "local_unit_cube_right"
            @test geometry.axis == 1
            @test geometry.coordinate == 1 // 2
            @test flux_pair.left_port == "left_outward_flux_K_grad_u"
            @test flux_pair.right_port == "right_outward_flux_K_grad_u"
            @test flux_pair.left_normal == (1, 0, 0)
            @test flux_pair.right_normal == (-1, 0, 0)
            @test flux_pair.left_sign == 1
            @test flux_pair.right_sign == -1
            @test flux_pair.law ===
                :left_outward_flux_plus_right_outward_flux_equals_zero
            g1_declaration = only(filter(d -> d.layer === :G1,
                candidate_package.declarations))
            g1_body = JSON3.read(String(G.copy_bytes(
                g1_declaration.semantic_body_bytes)))
            operators = G._n03_get(g1_body, :operators)
            k_apply = G._n03_get(operators, :coefficient_apply)
            output_type = G._n03_get(k_apply, :output_type)
            @test flux_pair.operator_ref.id ==
                G._n03_get(G._n03_get(k_apply, :operator_ref), :id)
            @test flux_pair.field_id == G._n03_get(k_apply, :output_field_id)
            @test flux_pair.unit == G._up2_vnext_unit_signature(
                G._n03_get(output_type, :units))
            @test flux_pair.unit == G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
            source_payload = G._n03_get(g1_body, :source_payload)
            authored_pair_wire = G._n03_get(source_payload, :interface_flux_pair)
            @test !haskey(authored_pair_wire, :unit)
            expected_n05_values = (
                "N05-01" => G.UP2TextValueV1(flux_pair.left_port),
                "N05-02" => G.UP2TextValueV1(flux_pair.right_port),
                "N05-03" => G.UP2IntegerValueV1(flux_pair.left_sign),
                "N05-04" => G.UP2IntegerValueV1(flux_pair.right_sign),
                "N05-05" => G.UP2UnitValueV1(flux_pair.unit))
            for (n05_id, expected_value) in expected_n05_values
                @test G.semantic_view(only(filter(field -> field.id == n05_id,
                    candidate_input.state.fields)).value) ==
                    G.semantic_view(expected_value)
            end
            g1_projection = candidate_identity_package.component_identity.g1_source_projection
            @test G._v5_g1_source_projection_valid(candidate_identity_package.g1,
                candidate_identity_package.candidate_ref, g1_projection)
            source_u = g1_projection.source_record.semantic_body.body.source_payload.u
            source_u_state = only(Tuple(state for state in
                candidate_identity_package.g1.payload.states
                if state.state_id == source_u.field_id))
            physical = source_u_state.physical_type
            wrong_physical = G.PhysicalType(:wrong_source_value_kind,
                physical.tensor_rank, physical.spatial_dimension,
                physical.temporal_type, physical.units)
            wrong_states = Tuple(state.state_id == source_u.field_id ?
                G.G1StateV2(state.state_id, wrong_physical;
                    derivative_order=state.derivative_order) : state
                for state in candidate_identity_package.g1.payload.states)
            same_expression_wrong_type_g1 = (
                contract_ref=candidate_identity_package.g1.contract_ref,
                candidate_hash=candidate_identity_package.g1.candidate_hash,
                payload=(contract_ref=candidate_identity_package.g1.payload.contract_ref,
                    states=wrong_states,
                    equation_plan=candidate_identity_package.g1.payload.equation_plan))
            @test source_u.source_expression ==
                g1_projection.source_record.semantic_body.body.source_payload.u.source_expression
            @test !G._v5_g1_source_projection_valid(same_expression_wrong_type_g1,
                candidate_identity_package.candidate_ref, g1_projection)
            @test !G._v5_package_identity_valid(candidate_identity_package.candidate_ref,
                same_expression_wrong_type_g1, candidate_identity_package.g2,
                candidate_identity_package.g2_binding, candidate_identity_package.g3,
                candidate_identity_package.version_axes,
                candidate_identity_package.component_identity,
                candidate_identity_package.migration_receipt)
        end
        batch_validation_started = time_ns()
        batch_validation_contexts = run === :current_source ?
            G._up2_validate_vnext_input_with_context(candidate_input,
                candidate_package, candidate_native_plan, nothing, identity_n10_context;
                native_report=candidate_native_report,
                heat_lift_receipt=candidate_heat_lift_receipt,
                identity_package=candidate_identity_package) : nothing
        batch_validation_ms = (time_ns() - batch_validation_started) / 1.0e6
        if run === :current_source
            println("UP2_MUTATION_TIMING batch=$(batch_label) phase=batch_validation_complete validation_ms=$(batch_validation_ms)")
            flush(stdout)
        end
        if run === :current_source
            batch_validation_contexts isa NamedTuple ||
                throw(ArgumentError("current-source mutation batch lacks its validated contexts"))
            representative_id = first(supported_ids)
            representative_spec = G.up2_spec_for_id(representative_id)
            println("UP2_MUTATION_TIMING batch=$(batch_label) phase=direct_wrapper_begin")
            flush(stdout)
            direct_wrapper_started = time_ns()
            direct_mutated_input = G._up2_mutated_input(candidate_input,
                representative_spec; package=candidate_package,
                native_plan=candidate_native_plan,
                g1_context=candidate_g1_context,
                n07n08_context=candidate_g2_context,
                n04_05_context=candidate_g3_context,
                n09_context=candidate_n09_context,
                native_report=candidate_native_report,
                heat_lift_receipt=candidate_heat_lift_receipt,
                identity_package=candidate_identity_package)
            direct_after_validation = G._up2_mutated_input_after_validation(
                candidate_input, representative_spec; package=candidate_package,
                native_plan=candidate_native_plan,
                g1_context=batch_validation_contexts.g1_context,
                n07n08_context=batch_validation_contexts.geometry_context,
                n05_context=hasproperty(batch_validation_contexts, :n05_context) ?
                    batch_validation_contexts.n05_context : nothing,
                n10_context=hasproperty(batch_validation_contexts, :n10_context) ?
                    batch_validation_contexts.n10_context : nothing,
                native_report=candidate_native_report,
                heat_lift_receipt=candidate_heat_lift_receipt)
            @test direct_mutated_input.input_hash == direct_after_validation.input_hash
            direct_wrapper_ms = (time_ns() - direct_wrapper_started) / 1.0e6
            println("UP2_MUTATION_TIMING batch=$(batch_label) phase=batch_setup validation_ms=$(batch_validation_ms) direct_wrapper_ms=$(direct_wrapper_ms)")
            flush(stdout)
        end
        rows = NamedTuple[]
        archive = run === :current_source ?
            _UP2_R71_RUNTIME.runtime.CapabilityArchiveV4() : nothing
        archive_kwargs = run === :current_source ? (; archive=archive) : (;)
        archive_batch_previous = run === :current_source ?
            _up2_b04_archive_snapshot(archive) : nothing
        archive_first_id = first(collect(String, supported_ids))
        archive_last_id = last(collect(String, supported_ids))
        archive_expected_stages = ("up2_n09_01", "up2_n09_02",
            "up2_n09_03", "up2_n09_04", "up2_n09_05")
        for id in collect(String, supported_ids)
        spec = G.up2_spec_for_id(id)
        private_mutation_started = time_ns()
        if batch_validation_contexts === nothing
            mutated_input = G._up2_mutated_input(candidate_input, spec;
                package=candidate_package, native_plan=candidate_native_plan,
                g1_context=candidate_g1_context,
                n07n08_context=candidate_g2_context,
                n04_05_context=candidate_g3_context,
                n09_context=candidate_n09_context,
                native_report=candidate_native_report,
                heat_lift_receipt=candidate_heat_lift_receipt)
        else
            n06_network_mutation = id in ("N06-01", "N06-05")
            ledger_mutation = id in ("N04-01", "N04-02", "N04-03",
                "N04-04", "N04-05", "N06-02", "N06-03", "N06-04",
                "N02-04", "N02-05")
            g1_mutation = id in ("N01-01", "N01-02", "N02-01", "N02-02",
                "N03-01", "N03-02", "N03-03")
            geometry_mutation = id in ("N07-01", "N07-02", "N07-03",
                "N07-04", "N07-05", "N08-01", "N08-02", "N08-03",
                "N08-04", "N08-05", "N01-03", "N01-04", "N01-05",
                "N02-03")
            ledger_context = n06_network_mutation ?
                batch_validation_contexts.ledger_context :
                ledger_mutation ? G._up2_vnext_n04_05_context_without_child_design(
                    batch_validation_contexts.ledger_context) : nothing
            mutated_input = G._up2_mutated_input_after_validation(candidate_input,
                spec; package=candidate_package,
                native_plan=candidate_native_plan,
                n04_05_context=ledger_context,
                g1_context=g1_mutation ? batch_validation_contexts.g1_context : nothing,
                n07n08_context=geometry_mutation ?
                    batch_validation_contexts.geometry_context : nothing,
                n09_context=startswith(id, "N09-") ?
                    batch_validation_contexts.n09_context : nothing,
                n05_context=hasproperty(batch_validation_contexts, :n05_context) ?
                    batch_validation_contexts.n05_context : nothing,
                n10_context=hasproperty(batch_validation_contexts, :n10_context) ?
                    batch_validation_contexts.n10_context : nothing,
                native_report=candidate_native_report,
                heat_lift_receipt=candidate_heat_lift_receipt)
        end
        private_mutation_ms = (time_ns() - private_mutation_started) / 1.0e6
        baseline = only(filter(field -> field.id == id,
            candidate_input.state.fields))
        baseline_state = only(filter(state -> state.field_id == id,
            candidate_input.field_states))
        changed = only(filter(field -> field.id == id,
            mutated_input.state.fields))
        expected_reason = id in ("N01-01", "N01-02", "N02-01", "N02-02") ?
            :candidate_design_g1_operator_type_contract_only :
            id == "N03-03" ?
            :candidate_design_g1_operator_temporal_whitelist_contract_only :
            id == "N01-04" ? :candidate_design_g2_profile_contract_only :
            id in ("N01-03", "N01-05", "N02-03") ?
            :candidate_design_g1_g2_state_field_binding_contract_only :
            id == "N08-04" ?
            :candidate_design_g2_q1_h1_degree1_basis_contract_only :
            id in ("N03-01", "N03-02") ?
            :candidate_design_g1_diffusion_time_contract_only :
            id in ("N02-04", "N02-05") ?
            :candidate_design_g3_ledger_unit_design_only :
            id in ("N03-04", "N03-05") ?
            :candidate_design_event_time_policy_design_only :
            id == "N04-01" ? :candidate_design_ledger_owner_design_only :
            id == "N04-02" ? :candidate_design_ledger_closure_design_only :
            id == "N04-03" ? :candidate_design_ledger_entry_account_design_only :
            id == "N04-04" ? :candidate_design_ledger_component_design_only :
            id == "N04-05" ? :candidate_design_ledger_capacity_design_only :
            id == "N06-03" ?
            :candidate_design_g3_control_flow_link_design_only :
            id in ("N06-01", "N06-05") ?
            :candidate_design_g3_typed_resource_network_contract_only :
            id == "N06-02" ? :candidate_design_g3_ledger_entries_design_only :
            id == "N06-04" ? :candidate_design_g3_closure_balance_design_only :
            id == "N09-01" ? :candidate_design_g1_grad_native_gridap_service_match :
            id == "N09-02" ? :candidate_design_g2_profile_native_gridap_service_match :
            id == "N09-03" ? :candidate_design_g2_exterior_native_gridap_service_match :
            id == "N09-04" ? :candidate_design_g1_g2_scalar_heat_lift_provider_match :
            id == "N09-05" ? :candidate_design_g3_control_sampled_service_match :
            id in ("N05-01", "N05-02", "N05-03", "N05-04") ?
            :candidate_design_g1_g2_interface_flux_contract_only :
            id == "N05-05" ?
            :candidate_design_g1_k_apply_output_unit_contract_only :
            id == "N10-04" ? :current_vnext_t0_t1_component_identity_compatibility_view :
            id == "N10-05" ? :current_vnext_t0_t1_fresh_identity_receipt_not_v4_migration :
            startswith(id, "N10-") ?
            :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity :
            :candidate_design_g2_geometry_contract_only
        expected_roles = id in ("N06-01", "N06-03", "N06-05") ?
            (:g3_builder, :g3_child_design) :
            id in ("N05-01", "N05-02", "N05-03", "N05-04") ?
            (:g1_builder, :g1_declaration_source, :g2_builder,
                :g2_declaration_source) :
            id == "N05-05" ?
            (:g1_builder, :g1_declaration_source) :
            id == "N10-01" ? (:g1_builder, :g1_declaration_source) :
            id == "N10-02" ? (:g2_builder, :g2_declaration_source) :
            id == "N10-03" ? (:g3_builder, :g3_child_design) :
            id in ("N10-04", "N10-05") ?
            (:g1_builder, :g1_declaration_source, :g2_builder,
             :g2_declaration_source, :g3_builder, :g3_child_design) :
            id in ("N01-03", "N01-05", "N02-03") ?
            (:g1_builder, :g1_declaration_source, :g2_builder,
                :g2_declaration_source) :
            id in ("N01-01", "N01-02", "N02-01", "N02-02",
                "N03-01", "N03-02", "N03-03") ?
            (:g1_builder, :g1_declaration_source) :
            id == "N09-01" ? (:g1_builder, :g1_declaration_source) :
            id == "N09-04" ? (:g1_builder, :g1_declaration_source, :g2_builder,
                :g2_declaration_source, :g3_builder, :g3_child_design) :
            id == "N09-05" ? (:g3_builder, :g3_child_design) :
            id == "N01-04" || startswith(id, "N07-") ||
                (startswith(id, "N09-") && id != "N09-05") ||
                startswith(id, "N08-") ?
            (:g2_builder, :g2_declaration_source) :
            (:g3_builder, :g3_child_design)
        @test baseline.field_path == spec.field_path
        @test baseline.source_locator == spec.source_locator
        @test baseline.source_type === spec.source_type
        @test baseline_state.state === :source_present_deferred
        @test baseline_state.reason === expected_reason
        @test baseline_state.source_pin_roles == expected_roles
        if id in ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
            @test baseline.value == G.UP2SymbolValueV1(:unique_match)
        end
        if id == "N09-04"
            @test candidate_n09_context.requests["N09-04"] ===
                candidate_heat_lift_receipt
            @test candidate_n09_context.matches["N09-04"] === :unique_match
        end
        if id in ("N02-04", "N02-05")
            candidate_power_unit = hasproperty(
                candidate_g3_context.typed_ledger_context, :unit_basis) ?
                G.UnitSignature((1, 2, -3, 0, 0, 0, 0)) : watts
            @test baseline.value == G.UP2UnitValueV1(candidate_power_unit)
        elseif id == "N06-01"
            source_ports = candidate_g3_context.typed_ledger_context.resource_network.resource_ports
            @test baseline.value isa G.UP2TupleValueV1
            @test baseline.value.element_type === :G3ResourcePortV2
            @test G.canonical_hash(baseline.value.values) == G.canonical_hash(source_ports)
        elseif id == "N06-03"
            selected_link = only(candidate_g3_context.typed_ledger_context.control_resource_links)
            @test baseline.value isa G.UP2TextValueV1
            @test baseline.value.value == selected_link.resource_port_id ==
                "source_supply_current"
            @test selected_link.resource_port_id in Tuple(port.port_id for port in
                candidate_g3_context.typed_ledger_context.resource_network.resource_ports)
        elseif id == "N06-05"
            source_ports = candidate_g3_context.typed_ledger_context.resource_network.resource_ports
            @test baseline.value isa G.UP2SymbolValueV1
            @test baseline.value.value == source_ports[1].kind === :effort
            @test source_ports[1].port_id == "source_voltage"
        elseif id == "N06-02"
            verified = G._up2_vnext_n06_04_closure(candidate_g3_context,
                candidate_input.source_binding)
            @test baseline.value isa G.UP2TupleValueV1
            @test baseline.value.element_type === :g3_ledger_entry_v2
            @test G.canonical_hash(baseline.value.values) == G.canonical_hash(verified.entries)
        elseif id == "N06-04"
            closure = G._up2_vnext_n06_04_closure(candidate_g3_context,
                candidate_input.source_binding).closure
            @test baseline.value == G.UP2RationalValueV1(closure.expected_balance)
            @test candidate_g3_context.typed_ledger_context.source_pin_sha256 ==
                only(filter(pin -> pin.role === :g3_child_design,
                    candidate_input.source_binding.source_pins)).sha256
        end
        if id in ("N10-01", "N10-04")
            @test changed.value isa G.UP2TextValueV1
        else
            @test typeof(changed.value) === typeof(baseline.value)
        end
        @test G.semantic_view(changed.value) != G.semantic_view(baseline.value)
        if id in ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
            @test changed.value == G.UP2SymbolValueV1(:out_of_domain)
        elseif id == "N06-01"
            source_ports = candidate_g3_context.typed_ledger_context.resource_network.resource_ports
            expected_ports = Tuple(port for port in source_ports
                if port.port_id != "source_voltage")
            @test changed.value isa G.UP2TupleValueV1
            @test changed.value.element_type === :G3ResourcePortV2
            @test G.canonical_hash(changed.value.values) == G.canonical_hash(expected_ports)
            @test length(changed.value.values) == length(source_ports) - 1
        elseif id == "N06-03"
            @test changed.value isa G.UP2TextValueV1
            @test changed.value.value == "source_supply_current__unknown_resource"
            @test !(changed.value.value in Tuple(port.port_id for port in
                candidate_g3_context.typed_ledger_context.resource_network.resource_ports))
        elseif id == "N06-05"
            @test changed.value isa G.UP2SymbolValueV1
            @test changed.value.value === :flow
            @test changed.value.value != baseline.value.value
        elseif id == "N06-02"
            verified = G._up2_vnext_n06_04_closure(candidate_g3_context,
                candidate_input.source_binding)
            heat_entry = only(Tuple(e for e in verified.entries if e.effect === :heat_rejection))
            @test G.canonical_hash(changed.value.values) == G.canonical_hash(Tuple(e for e in verified.entries
                if e.entry_id != heat_entry.entry_id))
            @test sum(e.coefficient for e in changed.value.values
                if e.account_id in verified.closure.account_ids) != verified.closure.expected_balance
        elseif id == "N06-04"
            @test changed.value == G.UP2RationalValueV1(
                baseline.value.value + (Int64(1) // Int64(1)))
            @test changed.value.value != G._up2_vnext_n06_04_closure(
                candidate_g3_context, candidate_input.source_binding).actual_balance
        elseif id == "N10-01"
            @test baseline.value isa G.UP2HashValueV1
            @test changed.value isa G.UP2TextValueV1
            @test changed.value.value != baseline.value.value.value
        elseif id == "N10-02"
            @test baseline.value isa G.UP2HashValueV1
            @test changed.value isa G.UP2HashValueV1
            @test changed.value.value != baseline.value.value
        elseif id == "N10-04"
            @test baseline.value isa G.UP2HashValueV1
            @test baseline.value.value == candidate_identity_package.candidate_hash
            @test changed.value isa G.UP2TextValueV1
            @test changed.value.value != baseline.value.value.value
        elseif id == "N10-05"
            @test baseline.value isa G.UP2TextValueV1
            @test baseline.value.value == candidate_identity_package.migration_receipt.candidate_identity_after
            @test changed.value isa G.UP2TextValueV1
            @test changed.value.value != baseline.value.value
        elseif id == "N10-03"
            @test baseline.value isa G.UP2ContractRefValueV1
            @test changed.value isa G.UP2ContractRefValueV1
            baseline_ref = baseline.value.value
            changed_ref = changed.value.value
            @test changed_ref.uri != baseline_ref.uri
            @test changed_ref.version == baseline_ref.version
            @test changed_ref.schema_hash == baseline_ref.schema_hash
            @test changed_ref.canonicalization_hash == baseline_ref.canonicalization_hash
            @test changed_ref.compatibility_profile == baseline_ref.compatibility_profile
        end
        counter = G.UP2InvocationCounterV1()
        b04_boundary_before = run === :current_source ?
            _up2_b04_boundary_snapshot(candidate_package, candidate_input) : nothing
        b04_archive_before = run === :current_source ?
            _up2_b04_archive_snapshot(archive) : nothing
        public_validation_started = time_ns()
        mutation = G.up2_validate_mutation(candidate_input, spec;
            package=candidate_package, native_plan=candidate_native_plan,
            native_report=candidate_native_report,
            heat_lift_receipt=candidate_heat_lift_receipt,
            candidate_identity_kwargs..., archive_kwargs..., counter=counter)
        public_validation_ms = (time_ns() - public_validation_started) / 1.0e6
        b04_boundary_after = run === :current_source ?
            _up2_b04_boundary_snapshot(candidate_package, candidate_input) : nothing
        b04_archive_after = run === :current_source ?
            _up2_b04_archive_snapshot(archive) : nothing
        if run === :current_source
            @test b04_boundary_after == b04_boundary_before
            is_n09_archive_case = id in
                ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
            archive_batch_continuous = b04_archive_before == archive_batch_previous &&
                (id != archive_first_id || b04_archive_before.record_count == 0)
            archive_added = Tuple(record for record in b04_archive_after.records
                if !(record in b04_archive_before.records))
            archive_removed = Tuple(record for record in b04_archive_before.records
                if !(record in b04_archive_after.records))
            if is_n09_archive_case
                expected_candidate_ref =
                    G._up2_vnext_archive_candidate_ref_v1(candidate_input.source_binding).value
                expected_stage = String(Symbol("up2_", replace(lowercase(id), "-" => "_")))
                expected_matched_provider = candidate_n09_context.requests[id].provider
                expected_mutated_match = G._up2_vnext_n09_mutated_match(
                    candidate_n09_context, id)
                expected_retry_registry_hash = Base.invokelatest(
                    getfield(_UP2_R71_RUNTIME.runtime, :_archive_provider_hash),
                    (expected_matched_provider,)).value
                actual_gap_is_bound = false
                if length(archive_added) == 1
                    actual_gap = only(archive_added)
                    actual_gap_is_bound =
                        actual_gap.candidate_ref == expected_candidate_ref &&
                        actual_gap.stage == expected_stage &&
                        actual_gap.signature_hash == expected_mutated_match.obligation_hash.value &&
                        string(expected_mutated_match.status) == "out_of_domain" &&
                        expected_mutated_match.provider === nothing &&
                        actual_gap.match_status == string(expected_mutated_match.status) &&
                        actual_gap.reason == expected_mutated_match.reason &&
                        actual_gap.retry_registry_hash == expected_retry_registry_hash
                end
                @test archive_batch_continuous &&
                    b04_archive_after.record_count == b04_archive_before.record_count + 1 &&
                    length(archive_added) == 1 && isempty(archive_removed) &&
                    actual_gap_is_bound &&
                    b04_archive_before.state_hash != b04_archive_after.state_hash

                parity_counter = G.UP2InvocationCounterV1()
                parity_result = G.up2_validate_mutation(candidate_input, spec;
                    package=candidate_package, native_plan=candidate_native_plan,
                    native_report=candidate_native_report,
                    heat_lift_receipt=candidate_heat_lift_receipt,
                    candidate_identity_kwargs..., counter=parity_counter)
                parity_archive_after = _up2_b04_archive_snapshot(archive)
                @test G.semantic_view(parity_result) == G.semantic_view(mutation) &&
                    parity_archive_after == b04_archive_after &&
                    parity_counter.compile_calls == 0 &&
                    parity_counter.provider_calls == 0 &&
                    parity_counter.solver_calls == 0
            else
                final_archive_is_complete = id != archive_last_id ||
                    (b04_archive_after.record_count == 5 &&
                     Set(record.stage for record in b04_archive_after.records) ==
                        Set(archive_expected_stages))
                @test archive_batch_continuous &&
                    b04_archive_after == b04_archive_before &&
                    isempty(archive_added) && isempty(archive_removed) &&
                    b04_archive_after.record_count == b04_archive_before.record_count &&
                    final_archive_is_complete
            end
            archive_batch_previous = b04_archive_after
        end
        if run === :current_source
            println("UP2_MUTATION_TIMING batch=$(batch_label) id=$(id) private_mutation_ms=$(private_mutation_ms) public_validation_ms=$(public_validation_ms)")
            flush(stdout)
        end
        @test mutation.mutation_id == id
        @test mutation.status === (id in ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05",
                "N10-02", "N10-03", "N10-05") ?
            :terminal_deferred : :fail_closed)
        @test mutation.error_code === spec.expected_error
        @test id != "N09-04" || mutation.detail == spec.detail
        if id in ("N01-03", "N01-05", "N02-03", "N02-04", "N02-05",
                "N03-01", "N03-02", "N03-03")
            @test mutation.error_code === :invalid_type
        end
        @test mutation.error_path == spec.field_path
        expected_detail = id == "N06-03" ?
            "control_link_resource_port_missing" :
            id in ("N02-04", "N02-05", "N03-01", "N03-02") ?
            spec.detail :
            id == "N03-04" ?
            "event_trigger_policy_mismatch: mutated G3 trigger differs from authored initial trigger" :
            id == "N03-05" ?
            "event_time_negative: mutated G3 event time must be nonnegative" :
            id == "N04-01" ? "owner_crosswalk_mismatch" :
            id == "N04-02" ? "duplicate_or_unresolved_closure_account" :
            id == "N04-03" ? "entry_account_ref_missing" :
            id == "N04-04" ? "passive_component_cannot_source" :
            id == "N04-05" ? "component_capacity_exceeded" : spec.detail
        @test mutation.detail == expected_detail
        @test mutation.mutated_input_hash == mutated_input.input_hash
        @test mutation.input_hash == candidate_input.input_hash
        @test mutation.mutated_input_hash != mutation.input_hash
        @test mutation.compile_calls == counter.compile_calls == 0
        @test mutation.provider_calls == counter.provider_calls == 0
        @test mutation.solver_calls == counter.solver_calls == 0
        @test !mutation.evidence_reused
        row = (id=id, input_hash=mutation.input_hash.value,
            mutated_input_hash=mutation.mutated_input_hash.value,
            status=String(mutation.status), error_code=String(mutation.error_code),
            error_path=mutation.error_path, detail=mutation.detail,
            compile_calls=mutation.compile_calls,
            provider_calls=mutation.provider_calls,
            solver_calls=mutation.solver_calls,
            evidence_reused=mutation.evidence_reused,
            result_hash=mutation.result_hash.value)
        if run === :current_source
            # The before/after records below are snapshots of the actual
            # RuntimeV4 archive sink passed to this row's public validator call.
            # N09 rows must add one source-bound real matcher gap; other rows
            # must leave this fresh per-row archive unchanged.
            is_n09_archive_case = id in
                ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
            row = merge(row, (validator_scope=is_n09_archive_case ?
                    "typed_mutation_with_real_n09_provider_match" :
                    "schema_validation_only",
                archive_observation=(applicability=is_n09_archive_case ?
                        "actual_n09_transition" : "actual_non_applicable_observation",
                    object_type="RuntimeV4.CapabilityArchiveV4",
                    writer="RuntimeV4.defer!",
                    changed=b04_archive_before.state_hash != b04_archive_after.state_hash,
                    added=archive_added, removed=archive_removed,
                    before=b04_archive_before, after=b04_archive_after),
                candidate_ref_before=b04_boundary_before.candidate_ref,
                candidate_ref_after=b04_boundary_after.candidate_ref,
                input_hash_before=b04_boundary_before.input_hash,
                input_hash_after=b04_boundary_after.input_hash,
                package_hash_before=b04_boundary_before.package_hash,
                package_hash_after=b04_boundary_after.package_hash,
                carriers_before=b04_boundary_before.carriers,
                carriers_after=b04_boundary_after.carriers))
        end
        push!(rows, row)
        if run === :current_source
            Base.GC.gc(true)
        end
        end
        Tuple(rows)
    end
    if run === :current_source
        println("UP2_CURRENT_SOURCE_BOUNDARY=primary_mutation_summary_begin")
        flush(stdout)
    end
    typed_source_mutations = typed_mutation_summary(case.package, input, g1_types,
        g2_geometry, context; candidate_native_plan=native_plan,
        candidate_native_report=native_report,
        candidate_heat_lift_receipt=heat_lift_receipt,
        candidate_identity_package=run === :current_source ? case.identity_package : nothing,
        candidate_n09_context=run === :current_source ? n09_context :
            run === :r71 ? G._up2_vnext_n09_context(case.package, binding,
                g2_geometry, native_plan; g3_source_context=context,
                native_report=native_report,
                heat_lift_receipt=heat_lift_receipt) : nothing,
        batch_label=:primary)
    typed_absent_ids = Tuple(sort!(String[state.field_id for state in input.field_states
        if state.state === :typed_absent]))
    expected_typed_absent_ids = run === :current_source ?
        ((n09_04_present ? () : ("N09-04",))...,
         (n10_binding_present ? () : ("N10-03",))...) :
        run === :r71 ?
        (n09_05_present ?
            ("N05-01", "N05-02", "N08-05", "N09-04") :
            ("N05-01", "N05-02", "N08-05", "N09-04", "N09-05")) :
        run === :r70 ?
        ("N05-01", "N05-02", "N07-04", "N08-01", "N08-05",
         "N09-01", "N09-02", "N09-03", "N09-04", "N09-05") :
        ("N05-01", "N05-02", "N07-04", "N08-01", "N08-04", "N08-05",
         "N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
    expected_typed_absent_ids = n06_04_present ? expected_typed_absent_ids :
        Tuple(sort!(String[expected_typed_absent_ids..., "N06-02", "N06-04"]))
    expected_typed_absent_count = (run === :current_source ?
        (n10_binding_present ? 1 : 2) - Int(n09_04_present) :
        run === :r71 ? (n09_05_present ? 4 : 5) :
        run === :r70 ? 10 : 11) + 2 * Int(!n06_04_present)
    @test typed_absent_ids == expected_typed_absent_ids
    @test length(typed_absent_ids) == expected_typed_absent_count

    replay_result = run === :current_source ?
        case.build(p=case.replay_package, native_plan=native_plan,
            native_report=native_report, heat_lift_receipt=heat_lift_receipt,
            identity_package=case.replay_identity_package) :
        case.build(p=case.replay_package, native_plan=native_plan)
    @test replay_result.status === :prepared_not_executed
    @test replay_result.resolution === :terminal_deferred
    @test replay_result.input isa G.UP2VNextPrecompilerInputV1
    replay_input = replay_result.input
    replay_typed_absent_ids = Tuple(sort!(String[state.field_id for state in
        replay_input.field_states if state.state === :typed_absent]))
    @test replay_typed_absent_ids == expected_typed_absent_ids
    @test length(replay_typed_absent_ids) == expected_typed_absent_count
    @test replay_input.input_hash == input.input_hash
    @test replay_input.provider_bindings == input.provider_bindings
    @test replay_input.source_binding.binding_hash == binding.binding_hash
    @test Tuple(G.semantic_view.(replay_input.state.fields)) ==
        Tuple(G.semantic_view.(input.state.fields))
    replay_identity_kwargs = run === :current_source ?
        (; identity_package=case.replay_identity_package) : (;)
    replay_context = G._up2_vnext_n04_05_context(case.replay_package,
        replay_input.source_binding; include_child_design=run in (:r71, :current_source),
        replay_identity_kwargs...)
    replay_g1_types = G._up2_vnext_g1_operator_type_context(
        case.replay_package, replay_input.source_binding)
    replay_g2_geometry = G._up2_vnext_g2_geometry_context(
        case.replay_package, replay_input.source_binding)
    replay_n09_context = run in (:r71, :current_source) ? G._up2_vnext_n09_context(
        case.replay_package, replay_input.source_binding, replay_g2_geometry,
        native_plan; g3_source_context=replay_context,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt) : nothing
    if run in (:r71, :current_source)
        @test haskey(replay_n09_context.matches, "N09-05") == n09_05_present
        @test run !== :current_source || haskey(replay_n09_context.matches, "N09-05")
        @test run !== :current_source || haskey(replay_n09_context.matches, "N09-04") == n09_04_present
        @test run !== :current_source || haskey(replay_g2_geometry.values, "N08-05")
    end
    @test replay_g1_types.projection_hash == g1_types.projection_hash
    @test replay_g2_geometry.projection_hash == g2_geometry.projection_hash
    @test replay_g2_geometry.cross_state_context ==
        g2_geometry.cross_state_context
    @test replay_g2_geometry.values == g2_geometry.values
    if run in (:r71, :current_source)
        @test replay_g1_types.values == g1_types.values
        @test replay_g1_types.operator_temporal_kinds ==
            g1_types.operator_temporal_kinds
        @test replay_g2_geometry.boundary_patch_context ==
            g2_geometry.boundary_patch_context
    end
    @test (replay_context.typed_ledger_context !== nothing) == n06_04_present
    @test replay_context.typed_ledger_context.identity_hash == typed.identity_hash
    @test replay_context.typed_ledger_context.source_pin_sha256 ==
        typed.source_pin_sha256
    replay_mutations = typed_mutation_summary(case.replay_package, replay_input,
        replay_g1_types, replay_g2_geometry, replay_context;
        candidate_native_plan=native_plan,
        candidate_n09_context=replay_n09_context,
        candidate_native_report=native_report,
        candidate_heat_lift_receipt=heat_lift_receipt,
        batch_label=:replay,
        candidate_identity_package=run === :current_source ? case.replay_identity_package : nothing)
    if run === :r70
        println("UP2_R70_TAIL=before_replay_equality")
        flush(stdout)
    end
    @test collect(replay_mutations) == collect(typed_source_mutations)
    if run === :r70
        println("UP2_R70_TAIL=replay_equality_complete")
        flush(stdout)
    end
    if run in (:r71, :current_source)
        expected_mutation_ids = run === :current_source ? supported_ids :
            supported_r71_ids
        @test Tuple(row.id for row in typed_source_mutations) == expected_mutation_ids
        @test Tuple(row.id for row in replay_mutations) == expected_mutation_ids
        if run === :current_source
            route_ids = ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
            all_routes = case.build(native_plan=native_plan,
                native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                identity_package=case.identity_package, available_route_ids=route_ids)
            @test all_routes.status === :prepared_not_executed
            @test all_routes.input isa G.UP2VNextPrecompilerInputV1
            if all_routes.input isa G.UP2VNextPrecompilerInputV1
                @test G.canonical_hash(all_routes.input) == G.canonical_hash(input)
                @test all_routes.input.provider_bindings == input.provider_bindings
                @test G.up2_validate_vnext_input(all_routes.input;
                    package=case.package, native_plan=native_plan,
                    native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                    identity_package=case.identity_package, available_route_ids=route_ids)
            end
            route_cases = (
                (ids=(), missing=route_ids),
                (ids=("N09-05",), missing=("N09-01", "N09-02", "N09-03", "N09-04")),
                (ids=("N09-01", "N09-02", "N09-03", "N09-05"), missing=("N09-04",)),
                (ids=("N09-01", "N09-02", "N09-03", "N09-04"), missing=("N09-05",)))
            route_reasons = Dict("N09-01"=>:candidate_design_g1_grad_native_gridap_service_match,
                "N09-02"=>:candidate_design_g2_profile_native_gridap_service_match,
                "N09-03"=>:candidate_design_g2_exterior_native_gridap_service_match,
                "N09-04"=>:candidate_design_g1_g2_scalar_heat_lift_provider_match,
                "N09-05"=>:candidate_design_g3_control_sampled_service_match)
            for selection in route_cases
                built_gap = case.build(native_plan=native_plan,
                    native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                    identity_package=case.identity_package,
                    available_route_ids=selection.ids)
                @test built_gap.status === :typed_absent
                @test built_gap.resolution === :terminal_deferred
                @test built_gap.reason === :n09_provider_availability_gap
                @test built_gap.input isa G.UP2VNextPrecompilerInputV1
                if built_gap.input isa G.UP2VNextPrecompilerInputV1
                    gap_input = built_gap.input
                    @test length(gap_input.state.fields) == length(gap_input.field_states) == 50
                    @test G.up2_validate_vnext_input(gap_input;
                        package=case.package, native_plan=native_plan,
                        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                        identity_package=case.identity_package,
                        available_route_ids=selection.ids)
                    for id in route_ids
                        field = only(filter(x->x.id==id, gap_input.state.fields))
                        state = only(filter(x->x.field_id==id, gap_input.field_states))
                        binding_row = only(filter(x->x.field_id==id, gap_input.provider_bindings))
                        if id in selection.ids
                            @test field.value == G.UP2SymbolValueV1(:unique_match)
                            @test state.state === :source_present_deferred
                            @test state.reason === route_reasons[id]
                            @test binding_row.status === :unique_match
                        else
                            @test field.value == G.UP2SymbolValueV1(:no_match)
                            @test state.state === :source_present_deferred
                            @test state.reason === :provider_availability_gap
                            @test binding_row.status === :no_match
                        end
                    end
                    for id in selection.missing
                        archive = _UP2_R71_RUNTIME.runtime.CapabilityArchiveV4()
                        before = _up2_b04_archive_snapshot(archive)
                        counter = G.UP2InvocationCounterV1()
                        result = G.up2_validate_mutation(gap_input, G.up2_spec_for_id(id);
                            package=case.package, native_plan=native_plan,
                            native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                            identity_package=case.identity_package, archive=archive,
                            counter=counter, available_route_ids=selection.ids)
                        @test result.status === :terminal_deferred
                        @test result.error_code === :provider_match
                        @test result.detail == "provider_availability_gap; mutation not executed"
                        @test result.input_hash == result.mutated_input_hash == gap_input.input_hash
                        @test result.compile_calls == counter.compile_calls == 0
                        @test result.provider_calls == counter.provider_calls == 0
                        @test result.solver_calls == counter.solver_calls == 0
                        @test !result.evidence_reused
                        @test _up2_b04_archive_snapshot(archive) == before
                        Base.GC.gc(true)
                    end
                end
            end
            @test_throws ArgumentError case.build(native_plan=native_plan,
                native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                identity_package=case.identity_package,
                available_route_ids=("N09-01", "N09-01"))
            @test_throws ArgumentError case.build(native_plan=native_plan,
                native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                identity_package=case.identity_package, available_route_ids=("N09-00",))

            empty_input_result = case.build(native_plan=native_plan,
                native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                identity_package=case.identity_package, available_route_ids=())
            @test empty_input_result.input isa G.UP2VNextPrecompilerInputV1
            if empty_input_result.input isa G.UP2VNextPrecompilerInputV1
                gap_input = empty_input_result.input
                @test G.up2_validate_vnext_input(gap_input;
                    package=case.package, native_plan=native_plan,
                    native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                    identity_package=case.identity_package, available_route_ids=())
                archive = _UP2_R71_RUNTIME.runtime.CapabilityArchiveV4()
                for id in collect(String, supported_ids)
                    before = _up2_b04_archive_snapshot(archive)
                    counter = G.UP2InvocationCounterV1()
                    validation_started = time_ns()
                    println("UP2_R71_STAGE=availability_empty_mutation_begin id=", id,
                        " elapsed_ms=", (validation_started - stage_started) / 1.0e6,
                        " gc_live_bytes=", Base.gc_live_bytes(),
                        " jit_total_bytes=", Base.jit_total_bytes())
                    flush(stdout)
                    result = G.up2_validate_mutation(gap_input, G.up2_spec_for_id(id);
                        package=case.package, native_plan=native_plan,
                        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
                        identity_package=case.identity_package, archive=archive,
                        counter=counter, available_route_ids=())
                    validation_elapsed_ms = (time_ns() - validation_started) / 1.0e6
                    println("UP2_R71_STAGE=availability_empty_mutation_end id=", id,
                        " call_elapsed_ms=", validation_elapsed_ms,
                        " elapsed_ms=", (time_ns() - stage_started) / 1.0e6,
                        " gc_live_bytes=", Base.gc_live_bytes(),
                        " jit_total_bytes=", Base.jit_total_bytes())
                    flush(stdout)
                    @test _up2_b04_archive_snapshot(archive) == before
                    @test result.mutation_id == id && result.input_hash == gap_input.input_hash
                    if startswith(id, "N09-")
                        @test result.status === :terminal_deferred
                        @test result.error_code === :provider_match
                        @test result.detail == "provider_availability_gap; mutation not executed"
                        @test result.mutated_input_hash == gap_input.input_hash
                    else
                        baseline_row = only(filter(row->row.id==id, typed_source_mutations))
                        @test String(result.status) == baseline_row.status
                        @test String(result.error_code) == baseline_row.error_code
                        @test result.error_path == baseline_row.error_path
                        @test result.detail == baseline_row.detail
                    end
                    @test result.compile_calls == counter.compile_calls == 0
                    @test result.provider_calls == counter.provider_calls == 0
                    @test result.solver_calls == counter.solver_calls == 0
                    @test !result.evidence_reused
                    Base.GC.gc(true)
                end
                @test _up2_b04_archive_snapshot(archive).record_count == 0
            end
        end
        println("UP2_R71_STAGE=mutation_complete_ms=",
            (time_ns() - stage_started) / 1.0e6)
    end
    summary_label = run === :current_source ? "UP2_CURRENT_SOURCE_TYPED_SOURCE_SUMMARY=" :
        run === :r69 ? "UP2_R69_N04_SUMMARY=" :
        run === :r70 ? "UP2_R70_TYPED_SOURCE_SUMMARY=" :
        "UP2_R71_TYPED_SOURCE_SUMMARY="
    mutation_key = run === :r69 ? :r69_mutations :
        run === :r70 ? :r70_mutations :
        run === :current_source ? :current_source_mutations : :r71_mutations
    summary_fields = Dict{Symbol,Any}(
        :package_hash => binding.package_hash.value,
        :input_hash => input.input_hash.value,
        :binding_hash => binding.binding_hash.value,
        :g1_type_projection_hash => g1_types.projection_hash.value,
        :g2_geometry_projection_hash => g2_geometry.projection_hash.value,
        :source_field_ids => Tuple(field.id for field in input.state.fields
            if !(field.value isa G.UP2AbsentValueV1)),
        :typed_ledger_identity_hash => typed.identity_hash.value,
        :typed_ledger_source_sha256 => typed.source_sha256.value,
        :upstream_receipts => case.upstream_receipts,
        :typed_absent_ids => typed_absent_ids,
        :replay_package_hash => replay_input.source_binding.package_hash.value,
        :replay_input_hash => replay_input.input_hash.value,
        :replay_binding_hash => replay_input.source_binding.binding_hash.value,
        :replay_typed_ledger_identity_hash =>
            replay_context.typed_ledger_context.identity_hash.value,
        :replay_mutations => replay_mutations,
        mutation_key => typed_source_mutations)
    if run === :r70
        println("UP2_R70_TAIL=summary_fields_complete")
        flush(stdout)
    end
    run === :current_source &&
        (summary_fields[:candidate_ref] = input.source_binding.candidate_ref.id)
    run === :current_source &&
        (summary_fields[:archive_candidate_ref] =
            G._up2_vnext_archive_candidate_ref_v1(input.source_binding).value)
    summary_json = G.canonical_json(summary_fields)
    if run === :r70
        println("UP2_R70_TAIL=canonical_json_complete type=",
            typeof(summary_json), " bytes=", ncodeunits(summary_json))
        flush(stdout)
    end
    println(summary_label, summary_json)
    if run === :r70
        flush(stdout)
    end
end

function _up2_assert_candidate_bound_typed_source(run::Symbol)
    run in (:r71, :current_source) ||
        return _up2_assert_candidate_bound_typed_source_impl(run)
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    root_project = joinpath(root, "Project.toml")
    qualification_project = joinpath(root, "tools", "qualification", "gridap")
    @test Base.active_project() == root_project
    try
        Pkg.activate(qualification_project; io=devnull)
        @test Base.active_project() == joinpath(qualification_project, "Project.toml")
        _up2_assert_candidate_bound_typed_source_impl(run)
    finally
        Pkg.activate(root; io=devnull)
    end
    @test Base.active_project() == root_project
end

@testset "UP2-00 R69 typed G3 owner and account rows stay candidate-bound and deferred" begin
    _up2_assert_candidate_bound_typed_source(:r69)
end

@testset "UP2-00 R70 typed G1/G2/G3 source rows stay candidate-bound and deferred" begin
    _up2_assert_candidate_bound_typed_source(:r70)
end
println("UP2_R70_TESTSET_COMPLETE")
flush(stdout)

@testset "UP2-00 R71 typed G1/G2/G3 source rows stay candidate-bound and deferred" begin
    println("UP2_R71_TESTSET_ENTERED")
    flush(stdout)
    run = haskey(ENV, "UP2_CURRENT_SOURCE_T1_A") ? :current_source : :r71
    _up2_assert_candidate_bound_typed_source(run)
end

@testset "UP2-00 R54 actual T1 package without policy remains typed absent" begin
    case = _up2_vnext_t1_case(:r54)
    result = case.build()
    @test result.status === :typed_absent
    @test result.resolution === :terminal_deferred
    @test result.reason === :candidate_design_event_time_basis_absent
    @test result.input === nothing
    r55 = _up2_vnext_t1_case(:r55)
    r55_input = r55.build().input
    n04_spec = G.up2_spec_for_id("N04-05")
    @test_throws ArgumentError G.up2_validate_mutation(r55_input, n04_spec;
        package=case.package)
end
