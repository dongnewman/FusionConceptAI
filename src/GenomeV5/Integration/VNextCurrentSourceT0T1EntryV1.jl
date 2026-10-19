"""Run the existing typed current-source T0 -> V2 -> parent/G3 -> V3 -> T1 chain.

The declarations, children, feedback and expected G3 commitment must come from
the caller's live authored builders. `source_root` is passed to the existing
source reader through each stage; this entry point creates no source receipt or
candidate identity.
"""
function _vnext_current_source_continue_v1_uncached(candidate::QualifiedRefV1, t0, root::AbstractString,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1,
        binding_key::G3BindingChildKeyV2; initial_links=(),
        g3_factory_invocation=nothing)
    t0.status === :valid || return (status=t0.status, resolution=t0.resolution,
        t0=t0, recheck=nothing, parent=nothing, bridge=nothing,
        witness=nothing, witness_validation=nothing, t1=nothing)

    recheck = vnext_declaration_authority_recheck_local_v2(
        VNextAuthorityRecheckLocalV2Input(candidate, t0.transport))
    recheck.status === :local_checked_present || return (
        status=recheck.status, resolution=recheck.resolution, t0=t0,
        recheck=recheck, parent=nothing, bridge=nothing, witness=nothing,
        witness_validation=nothing, t1=nothing)

    parent = bind_local_parent_baseline_from_t0_v1(
        T0LocalParentBaselineInputV1(candidate,
            (t0.transport.declarations[1], t0.transport.declarations[2]));
        frozen_context=root)
    parent.status === :present || return (status=parent.status,
        resolution=parent.resolution, t0=t0, recheck=recheck, parent=parent,
        bridge=nothing, witness=nothing, witness_validation=nothing, t1=nothing)
    parents = ntuple(i -> vnext_t1_parent_commitment_v2(candidate,
        t0.transport.declarations[i]), 2)

    bridge = vnext_t2_concrete_g3_bridge_v3(recheck, expected,
        realization_state, control_payload, control_state, binding_key;
        initial_links=initial_links)
    bridge.status === :local_checked_present && bridge.authority_verified ||
        return (status=bridge.status, resolution=bridge.resolution, t0=t0,
            recheck=recheck, parent=parent, bridge=bridge, witness=nothing,
            witness_validation=nothing, t1=nothing)

    witness = if g3_factory_invocation===nothing
        prepare_vnext_t2_concrete_source_witness_v3(t0.transport,
            recheck, parent, expected, bridge, realization_state, control_payload,
            control_state, binding_key; frozen_context=root)
    else
        prepare_vnext_t2_concrete_source_witness_v3(t0.transport,
            recheck, parent, expected, bridge, realization_state, control_payload,
            control_state, binding_key; frozen_context=root,
            g3_factory_invocation=g3_factory_invocation)
    end
    witness.source_ready || return (status=witness.status,
        resolution=witness.resolution, t0=t0, recheck=recheck, parent=parent,
        bridge=bridge, witness=witness, witness_validation=nothing, t1=nothing)
    witness_validation = if g3_factory_invocation===nothing
        validate_vnext_t2_concrete_source_witness_v3(
            witness.witness, t0.transport, recheck, parent, expected, bridge,
            realization_state, control_payload, control_state, binding_key;
            frozen_context=root)
    else
        validate_vnext_t2_concrete_source_witness_v3(
            witness.witness, t0.transport, recheck, parent, expected, bridge,
            realization_state, control_payload, control_state, binding_key;
            frozen_context=root, g3_factory_invocation=g3_factory_invocation)
    end
    witness_validation.source_ready || return (status=witness_validation.status,
        resolution=witness_validation.resolution, t0=t0, recheck=recheck,
        parent=parent, bridge=bridge, witness=witness,
        witness_validation=witness_validation, t1=nothing)

    authority = (status=bridge.status, resolution=bridge.resolution,
        commitment_hash=expected.commitment_hash, authority_verified=bridge.authority_verified,
        expected_commitment=expected, binding_state=bridge.binding_state)
    t1 = vnext_t1_admit_v2(VNextT1AdmissionInputV2(candidate, t0.transport,
        recheck, parents, expected.commitment_hash, authority))
    (status=t1.status, resolution=t1.resolution, t0=t0, recheck=recheck,
     parent=parent, bridge=bridge, witness=witness,
     witness_validation=witness_validation, t1=t1)
end


# Keep the authoritative caller-supplied T0 transport and both source-witness
# passes intact. Within this one continuation, memoize only the exact immutable
# authored G1 AST stages carried by T0; both passes serialize those same objects.
function _vnext_current_source_continue_v1(candidate::QualifiedRefV1, t0, root::AbstractString,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1,
        binding_key::G3BindingChildKeyV2; initial_links=(),
        g3_factory_invocation=nothing)
    normalized_root = realpath(String(root))
    stage_asts = nothing
    if t0.status === :valid
        try
            g1_records = Tuple(record for record in t0.transport.declarations
                if record isa VNextT0LocalPresentDeclarationV1 && record.layer === :G1)
            if length(g1_records) == 1
                body = only(g1_records).semantic_body.body
                if hasproperty(body, :value) &&
                        hasproperty(body.value, :g1_typed_source_field_program)
                    capability = body.value.g1_typed_source_field_program
                    if hasproperty(capability, :program)
                        programs = capability.program
                        if programs isa NamedTuple &&
                                keys(programs) === (:x_coordinate, :x_bubble, :u, :f)
                            candidates = Tuple(stage.ast for stage in values(programs)
                                if hasproperty(stage, :ast))
                            length(candidates) == 4 &&
                                all(ast -> ast isa TypedASTProgramV1, candidates) &&
                                (stage_asts = candidates)
                        end
                    end
                end
            end
        catch err
            err isa InterruptException && rethrow()
            # Fall back to the original validation path on carrier-shape issues.
            stage_asts = nothing
        end
    end
    run_continuation() = _vnext_current_source_continue_v1_uncached(
        candidate, t0, normalized_root, expected, realization_state,
        control_payload, control_state, binding_key; initial_links=initial_links,
        g3_factory_invocation=g3_factory_invocation)
    stage_asts === nothing && return run_continuation()
    # The tuple is a deeply immutable scope owner; payload_targets are the exact
    # four AST objects stored in the T0 capability, keyed by object identity.
    _with_canonical_json_memo(stage_asts; payload_targets=stage_asts) do
        run_continuation()
    end
end


function vnext_current_source_t0_t1_local_v1(candidate::QualifiedRefV1,
        declarations, children, feedback,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1,
        binding_key::G3BindingChildKeyV2;
        source_root::AbstractString, initial_links=())
    root = realpath(String(source_root))
    t0 = vnext_declaration_transport_local_v1(candidate, declarations,
        children, feedback; frozen_context=root)
    _vnext_current_source_continue_v1(candidate, t0, root, expected,
        realization_state, control_payload, control_state, binding_key;
        initial_links=initial_links)
end


import JSON3

function _vnext_current_source_candidate_records_v1(source_root::AbstractString,
        candidate_directory::AbstractString)
    root = realpath(String(source_root))
    candidate_dir = realpath(isabspath(candidate_directory) ? String(candidate_directory) :
        joinpath(root, String(candidate_directory)))
    relative_dir = replace(relpath(candidate_dir, root), '\\' => '/')
    (isabspath(relative_dir) || first(splitpath(relative_dir)) == "..") &&
        throw(ArgumentError("candidate directory escapes current source root"))
    logical(path) = relative_dir * "/" * String(path)
    read_current(path) = NativeGitReadCompatibilityV1.current_source(root, logical(path))
    manifest_entry = read_current("manifest.json")
    manifest = JSON3.read(String(copy(manifest_entry.bytes)))
    manifest.schema == "candidate-design-input-manifest-v1" ||
        throw(ArgumentError("current candidate manifest schema mismatch"))
    file_entries = Dict(String(row.path) => row for row in manifest.files)
    required_paths = ("identity.jl", "design_identity.json", "scenario.json",
        "g1_source.jl", "g2_source.jl", "g3_source.jl",
        "g3_child_design_source.jl", "native_mms_source_expressions.json")
    entries = NamedTuple{Tuple(Symbol(replace(path, "." => "_")) for path in required_paths)}(
        Tuple(read_current(path) for path in required_paths))
    for path in required_paths
        haskey(file_entries, path) || throw(ArgumentError("candidate manifest omits $path"))
        entry = getproperty(entries, Symbol(replace(path, "." => "_")))
        pin = file_entries[path]
        Int(pin.bytes) == entry.byte_count &&
            lowercase(String(pin.sha256)) == entry.sha256 ||
            throw(ArgumentError("current candidate manifest pin mismatch: $path"))
    end
    identity_json = JSON3.read(String(copy(entries.design_identity_json.bytes)))
    scenario_json = JSON3.read(String(copy(entries.scenario_json.bytes)))
    expression = JSON3.read(String(copy(entries.native_mms_source_expressions_json.bytes)))
    expected_fields = union(Set(("schema", "status")), Set(String.(
        manifest.native_g1g2_mms_alignment.source_expression_record.required_fields)))
    Set(String.(propertynames(expression))) == expected_fields ||
        throw(ArgumentError("current native MMS source expression fields differ from manifest"))
    expression.schema == "up4-r2-native-mms-source-expressions-v1" &&
        expression.status == "candidate_design_projection_only" &&
        expression.design_scope == "candidate_design_only" &&
        expression.compiler_rebuild_required === true ||
        throw(ArgumentError("current native MMS source expression contract mismatch"))
    identity_json.candidate_id == manifest.candidate_id == expression.candidate_id &&
        scenario_json.candidate_id == manifest.candidate_id &&
        identity_json.scenario_id == manifest.scenario_id == expression.scenario_id &&
        scenario_json.scenario_id == manifest.scenario_id &&
        String(identity_json.candidate_ref.id) == String(manifest.candidate_ref.id) &&
        String(scenario_json.candidate_ref.id) == String(manifest.candidate_ref.id) &&
        String(identity_json.scenario_ref.id) == String(manifest.scenario_ref.id) &&
        String(scenario_json.scenario_ref.id) == String(manifest.scenario_ref.id) &&
        manifest.design_status == "unvalidated_design_input" &&
        identity_json.design_status == "unvalidated_design_input" &&
        scenario_json.scenario_status == "unvalidated_design_input" ||
        throw(ArgumentError("current candidate/scenario identity mismatch"))

    builder_module = _vnext_t2_v3_frozen_source_module()
    for path in ("identity.jl", "g1_source.jl", "g2_source.jl",
            "g3_child_design_source.jl", "g3_source.jl")
        entry = getproperty(entries, Symbol(replace(path, "." => "_")))
        Base.include_string(builder_module, String(copy(entry.bytes)), logical(path))
    end
    identity = getfield(builder_module, :UP4_R2_IDENTITY)
    identity.candidate_ref == QualifiedRefV1(String(manifest.candidate_ref.id),
        String(manifest.candidate_ref.version)) &&
        identity.scenario_id == String(manifest.scenario_id) ||
        throw(ArgumentError("current identity.jl differs from candidate manifest"))
    g1 = Base.invokelatest(getfield(builder_module, :up4_r2_build_g1_design), expression)
    g1_v5_source = if isdefined(builder_module, :up4_r2_build_g1_v5_design)
        Base.invokelatest(getfield(builder_module, :up4_r2_build_g1_v5_design), expression)
    else
        nothing
    end
    g2 = Base.invokelatest(getfield(builder_module, :up4_r2_build_g2_design), expression)
    child_factory=getfield(builder_module,:up4_r2_g3_child_design_source_v1)
    factory_invocation=nothing
    if hasproperty(manifest,:g3_child_factory)
        selection=manifest.g3_child_factory
        required=(:schema,:entrypoint,:candidate_id,:scenario_id,:source_path,
            :re_enable_threshold_kelvin)
        all(key->hasproperty(selection,key),required) ||
            throw(ArgumentError("candidate manifest G3 factory selection is incomplete"))
        selection.schema=="up4-g3-child-factory-invocation-v1" &&
            selection.entrypoint=="up4_r2_g3_child_design_source_v1" &&
            String(selection.candidate_id)==String(manifest.candidate_id) &&
            String(selection.scenario_id)==String(manifest.scenario_id) &&
            String(selection.source_path)==logical("g3_child_design_source.jl") ||
            throw(ArgumentError("candidate manifest G3 factory selection differs from its pinned identity/path"))
        threshold=selection.re_enable_threshold_kelvin
        threshold===nothing || (threshold isa Integer &&
            !(threshold isa Bool) && 0<=threshold<350) ||
            throw(ArgumentError("candidate manifest G3 clear threshold must be exact Kelvin below the 350 K trip"))
        threshold_arg=threshold===nothing ? nothing : Rational{Int64}(threshold)
        factory_invocation=(candidate_id=String(selection.candidate_id),
            scenario_id=String(selection.scenario_id),
            source_path=logical("g3_child_design_source.jl"),
            re_enable_threshold_kelvin=threshold_arg)
        child_design=Base.invokelatest(child_factory;
            candidate_id=factory_invocation.candidate_id,
            scenario_id=factory_invocation.scenario_id,
            source_path=factory_invocation.source_path,
            re_enable_threshold_kelvin=factory_invocation.re_enable_threshold_kelvin)
    else
        child_design=Base.invokelatest(child_factory)
    end
    child_entry = entries.g3_child_design_source_jl
    child_sha = bytes2hex(SHA.sha256(child_entry.bytes))
    child_sha == child_entry.sha256 || throw(ArgumentError("current G3 child source changed"))
    g3 = Base.invokelatest(getfield(builder_module, :up4_r2_build_g3_design),
        child_design; source_file_sha256=child_sha)
    g1.candidate_ref == identity.candidate_ref == g2.candidate_ref == g3.candidate_ref ||
        throw(ArgumentError("current authored builders disagree on candidate"))
    g1.scenario_id == identity.scenario_id == g2.scenario_id == g3.scenario_id ||
        throw(ArgumentError("current authored builders disagree on scenario"))
    (root=root, candidate_ref=identity.candidate_ref, identity=identity,
     g1=g1, g1_v5_source=g1_v5_source, g2=g2, g3=g3,
     child_design=child_design, child_sha=child_sha,
     g3_factory_invocation=factory_invocation,
     entries=entries, expression=expression, read_current=read_current)
end

function _vnext_current_source_locator_v1(root, entry, source_ref)
    VNextT0LocalSourceLocatorV1(root, entry.logical_path, source_ref.id,
        source_ref, entry.byte_count, Digest256(entry.sha256), "current-source",
        :not_observed, :not_observed, :not_observed, nothing, :current_source)
end

const _VNEXT_CURRENT_G1_THERMAL_U_SOURCE_MARKER_V1 =
    "u_candidate_steady_planar_quadratic_diffusion_v1"
const _VNEXT_CURRENT_G1_AUTHORED_AST_SCHEMA_V1 =
    "fusionconceptai:genome-v5:g1-source-expression-ast-v1"
function _vnext_current_source_g1_typed_source_kind_v1(g1::G1DiffusionDeclarationV1)
    expressions = (g1.u.source_expression, g1.f.source_expression)
    is_json_object(expression) = expression isa AbstractString &&
        startswith(strip(String(expression)), "{")
    object_flags = Tuple(is_json_object(expression) for expression in expressions)
    any(object_flags) || return :legacy
    all(object_flags) || throw(ArgumentError(
        "candidate G1 source-expression JSON pair is incomplete"))
    function read_document(expression)
        try
            JSON3.read(strip(String(expression)))
        catch
            throw(ArgumentError("candidate G1 source-expression JSON is malformed"))
        end
    end
    u = read_document(g1.u.source_expression)
    f = read_document(g1.f.source_expression)
    all(document -> hasproperty(document, :schema) &&
        hasproperty(document, :role) && document.schema isa AbstractString &&
        document.role isa AbstractString, (u, f)) ||
        throw(ArgumentError("candidate G1 source-expression schema/role is missing"))
    if u.schema == "native-g1g2-state-source-expression-v1" &&
            u.role == "unknown_with_manufactured_reference" &&
            f.schema == "native-g1g2-manufactured-source-expression-v1" &&
            f.role == "manufactured_source"
        return :native
    end
    if u.schema == _VNEXT_CURRENT_G1_AUTHORED_AST_SCHEMA_V1 && u.role == "u" &&
            f.schema == _VNEXT_CURRENT_G1_AUTHORED_AST_SCHEMA_V1 && f.role == "f"
        return :candidate_ast
    end
    throw(ArgumentError("candidate G1 source-expression schema pair is unsupported"))
end
function _vnext_current_source_g1_typed_spec_v1(g1::G1DiffusionDeclarationV1)
    _vnext_current_source_g1_typed_source_kind_v1(g1) === :candidate_ast ||
        return nothing
    runtime = if isdefined(Main, :FusionRuntimeV4)
        getfield(Main, :FusionRuntimeV4)
    else
        runtime_path = joinpath(@__DIR__, "..", "..", "RuntimeV4",
            "FusionRuntimeV4.jl")
        Base.include(Main, normpath(runtime_path))
        getfield(Main, :FusionRuntimeV4)
    end
    isdefined(runtime, :_g1_authored_typed_source_spec_v1) ||
        throw(ArgumentError("loaded RuntimeV4 lacks the candidate G1 source-expression AST parser"))
    Base.invokelatest(getfield(runtime, :_g1_authored_typed_source_spec_v1), g1)
end

"""Derive the opt-in thermal G1 program only from actual typed G1/G2 source declarations."""
function _vnext_current_source_g1_thermal_program_v1(candidate::QualifiedRefV1,
        g1::G1DiffusionDeclarationV1, g1_declaration_ref::QualifiedRefV1,
        g2_record::VNextT0LocalPresentDeclarationV1)
    authored_spec = _vnext_current_source_g1_typed_spec_v1(g1)
    if authored_spec !== nothing
        g1.candidate_ref == candidate && g1.source_payload.candidate_ref == candidate ||
            throw(ArgumentError("candidate-authored G1 typed source candidate mismatch"))
        g2_record.layer === :G2 && g2_record.candidate_ref == candidate ||
            throw(ArgumentError("candidate-authored G2 typed source record mismatch"))
        g2body = g2_record.semantic_body.body
        hasproperty(g2body, :source) && g2body.source isa G2MBSourceV1 ||
            throw(ArgumentError("candidate-authored G1 typed source lacks actual typed G2 source"))
        runtime = if isdefined(Main, :FusionRuntimeV4)
            getfield(Main, :FusionRuntimeV4)
        else
            runtime_path = joinpath(g2_record.source_locator.repository_root,
                "src", "RuntimeV4", "FusionRuntimeV4.jl")
            Base.include(Main, runtime_path)
            getfield(Main, :FusionRuntimeV4)
        end
        isdefined(runtime, :build_g1_candidate_typed_source_capability_v1) ||
            throw(ArgumentError("loaded RuntimeV4 lacks candidate G1 typed source compiler"))
        g2 = g2body.source
        return Base.invokelatest(
            getfield(runtime, :build_g1_candidate_typed_source_capability_v1), (
                spec=authored_spec, candidate_ref=candidate,
                g1_source_ref=g1.source_ref, g1_declaration_ref=g1_declaration_ref,
                u_field_id=g1.u.field_id, f_field_id=g1.f.field_id,
                u_type=g1.u.physical_type, f_type=g1.f.physical_type,
                g2_source_ref=g2.source_ref, g2_declaration_ref=g2_record.declaration_ref,
                chart_ref=g2.chart_map.chart_ref, chart_hash=canonical_hash(g2.chart_map),
                chart_input_type=Base.invokelatest(
                    getfield(runtime, :chart_coordinate_type_v1))))
    end
    g1.u.source_expression == _VNEXT_CURRENT_G1_THERMAL_U_SOURCE_MARKER_V1 ||
        return nothing
    g1.f.source_expression in ("f_candidate(x)=1", "f(x)=1") ||
        throw(ArgumentError("thermal G1 source marker requires the exact constant-one f expression"))
    g1.candidate_ref == candidate ||
        throw(ArgumentError("thermal G1 source candidate mismatch"))
    g2_record.layer === :G2 && g2_record.candidate_ref == candidate ||
        throw(ArgumentError("thermal G2 source record candidate/layer mismatch"))
    g2body = g2_record.semantic_body.body
    hasproperty(g2body, :source) && g2body.source isa G2MBSourceV1 ||
        throw(ArgumentError("thermal G2 record lacks actual typed source"))
    g2 = g2body.source
    chart = g2.chart_map
    chart.map_kind === :affine && chart.domain_lower == (0 // 1, 0 // 1, 0 // 1) &&
        chart.domain_upper == (1 // 1, 1 // 1, 1 // 1) &&
        all(iszero(chart.jacobian_rows[i][j]) for i in 1:3 for j in 1:3 if i != j) &&
        all(chart.jacobian_rows[i][i] > 0 for i in 1:3) ||
        throw(ArgumentError("thermal G2 chart must be a positive diagonal affine unit cube"))
    physical_lower = ntuple(i -> chart.offset[i] +
        chart.jacobian_rows[i][i] * chart.domain_lower[i], 3)
    physical_upper = ntuple(i -> chart.offset[i] +
        chart.jacobian_rows[i][i] * chart.domain_upper[i], 3)
    x_origin = physical_lower[1]
    x_extent = physical_upper[1] - physical_lower[1]
    faces = g2.faces
    face_map = Dict(face.face => face for face in faces)
    haskey(face_map, :x_min) && haskey(face_map, :x_max) ||
        throw(ArgumentError("thermal G2 x boundary faces are missing"))
    t0 = Float64(face_map[:x_min].value.value)
    kexpr = g1.K.expression
    kexpr isa G1DiffusionDiagonalAffineKFieldV1 ||
        throw(ArgumentError("thermal G1 requires the existing typed diagonal-affine K expression"))
    kexpr.domain_min == physical_lower && kexpr.domain_max == physical_upper ||
        throw(ArgumentError("thermal G1 K domain differs from the actual G2 physical chart"))
    runtime = if isdefined(Main, :FusionRuntimeV4)
        getfield(Main, :FusionRuntimeV4)
    else
        runtime_path = joinpath(g2_record.source_locator.repository_root,
            "src", "RuntimeV4", "FusionRuntimeV4.jl")
        Base.include(Main, runtime_path)
        getfield(Main, :FusionRuntimeV4)
    end
    isdefined(runtime, :build_g1_steady_thermal_field_capability_v1) ||
        throw(ArgumentError("loaded RuntimeV4 lacks the opt-in G1 source builder"))
    Base.invokelatest(getfield(runtime, :build_g1_steady_thermal_field_capability_v1), (
        candidate_ref=candidate,
        g1=(source_ref=g1.source_ref, declaration_ref=g1_declaration_ref,
            u_field_id=g1.u.field_id, f_field_id=g1.f.field_id,
            K_field_id=g1.K.field_id, u_type=g1.u.physical_type,
            K_type=g1.K.physical_type, f_type=g1.f.physical_type,
            grad_ref=g1.operators.grad.operator_ref,
            k_apply_ref=g1.operators.coefficient_apply.operator_ref,
            div_ref=g1.operators.div.operator_ref, q_W_m3=1.0,
            q_unit=g1.f.physical_type.units, Kxx_W_mK=Float64(kexpr.base_diag[1]),
            Kxx_unit=g1.K.physical_type.units,
            Kxx_slope_x=Float64(kexpr.slope_diag[1])),
        g2=(source_ref=g2.source_ref,
            declaration_ref=g2_record.declaration_ref,
            chart_ref=chart.chart_ref, chart_hash=canonical_hash(chart),
            x_origin_m=Float64(x_origin), x_extent_m=Float64(x_extent),
            reference_x_lower=Float64(chart.domain_lower[1]),
            reference_x_upper=Float64(chart.domain_upper[1]), T0_K=t0,
            T0_unit=g2.units.field_value, x_origin_unit=g2.units.coordinate,
            x_extent_unit=g2.units.coordinate, faces=faces)))
end

function _vnext_current_source_present_record_v1(raw, layer, candidate,
        builder_entry, source_entry, root; expression_entry=nothing,
        g2_record=nothing)
    declaration = raw.source_declaration.declaration
    source_ref = layer === :G1 ? declaration.source_ref : declaration.source.source_ref
    source_bytes = VNextT0LocalBytesV1(copy(source_entry.bytes), Digest256(source_entry.sha256))
    locator = _vnext_current_source_locator_v1(root, source_entry, source_ref)
    declaration_raw = Vector{UInt8}(codeunits(canonical_json(declaration)))
    declaration_bytes = VNextT0LocalBytesV1(declaration_raw,
        Digest256(bytes2hex(SHA.sha256(declaration_raw))))
    declaration_ref = QualifiedRefV1("local://up4-r2/" * String(layer) * "/declaration/" *
        declaration_bytes.sha256.value, "v1")
    builder_input = (logical_path=builder_entry.logical_path,
        byte_count=builder_entry.byte_count, sha256=Digest256(builder_entry.sha256),
        bytes=copy(builder_entry.bytes))
    expression_input = expression_entry === nothing ? nothing :
        (logical_path=expression_entry.logical_path,
         byte_count=expression_entry.byte_count,
         sha256=Digest256(expression_entry.sha256), bytes=copy(expression_entry.bytes))
    value = if layer === :G1
        base = merge(_g1d_declaration_body(declaration),
            (candidate_ref=candidate, authored_builder_input=builder_input,
             authored_expression_input=expression_input))
        authored_spec = layer === :G1 ?
            _vnext_current_source_g1_typed_spec_v1(declaration) : nothing
        if declaration.u.source_expression == _VNEXT_CURRENT_G1_THERMAL_U_SOURCE_MARKER_V1 ||
                authored_spec !== nothing
            g2_record isa VNextT0LocalPresentDeclarationV1 ||
                throw(ArgumentError("thermal G1 source requires the actual G2 T0 record"))
            cap = _vnext_current_source_g1_thermal_program_v1(candidate,
                declaration, declaration_ref, g2_record)
            merge(base, (value=(g1_typed_source_field_program=cap,),))
        else
            base
        end
    else
        (candidate_ref=candidate,
         candidate_envelope=VNextT0LocalG2CandidateEnvelopeV1(candidate,
            declaration.contract_ref, declaration.source.source_ref,
            declaration.source.source_hash),
         contract_ref=declaration.contract_ref, source=declaration.source,
         schema_hash=declaration.schema_hash,
         canonicalization_hash=declaration.canonicalization_hash,
         profile_hash=declaration.profile_hash,
         declaration_hash=declaration.declaration_hash,
         authored_builder_input=builder_input)
    end
    semantic_raw = Vector{UInt8}(codeunits(canonical_json(value)))
    semantic = VNextT0LocalSemanticBodyV1(value,
        VNextT0LocalBytesV1(semantic_raw,
            Digest256(bytes2hex(SHA.sha256(semantic_raw)))),
        layer === :G1 ? (:up4_r2_authored_input_bytes, :up4_r2_expression_input_bytes) :
            (:up4_r2_authored_input_bytes,))
    contract_ref = raw.source_declaration.public_contract_ref
    factory = vnext_t0_local_normalize_factory_result_v1(raw, layer, layer,
        candidate, source_ref, source_bytes, locator, declaration_ref,
        declaration_bytes, contract_ref; frozen_context=root)
    axes = ntuple(i -> QualifiedRefV1(VNEXT_T0_LOCAL_AXIS_IDS_V1[i],
        VNEXT_T0_LOCAL_AXIS_VERSION_V1), 4)
    source_identity = canonical_hash((kind=:source, ref=source_ref,
        bytes_sha256=source_bytes.sha256))
    declaration_identity = canonical_hash((kind=:declaration, ref=declaration_ref,
        bytes_sha256=declaration_bytes.sha256))
    factory_receipt = VNextT0LocalFactoryReceiptV1(candidate, layer, source_ref,
        declaration_ref, axes, :present, factory)
    declaration_receipt = VNextT0LocalDeclarationReceiptV1(candidate, layer,
        source_ref, declaration_ref, axes, :present, factory)
    VNextT0LocalPresentDeclarationV1(layer, candidate, source_ref, declaration_ref,
        source_identity, declaration_identity, axes, source_bytes, declaration_bytes,
        semantic, locator, factory_receipt, declaration_receipt)
end

function _vnext_current_source_g3_record_v1(candidate, design, builder_entry,
        identity_entry, child_entry, child_design, root)
    source_ref = design.source_ref
    source_sha = bytes2hex(SHA.sha256(builder_entry.bytes))
    source_sha == builder_entry.sha256 || throw(ArgumentError("current G3 builder bytes changed"))
    source_bytes = VNextT0LocalBytesV1(copy(builder_entry.bytes), Digest256(source_sha))
    locator = _vnext_current_source_locator_v1(root, builder_entry, source_ref)
    declaration = design.declaration
    child_sha = bytes2hex(SHA.sha256(child_entry.bytes))
    child_sha == child_entry.sha256 || throw(ArgumentError("current G3 child bytes changed"))
    child_bytes = VNextT0LocalBytesV1(copy(child_entry.bytes), Digest256(child_sha))
    semantic_value = merge(_g3sf_body(declaration),
        (candidate_ref=candidate, source_ref=source_ref,
         authored_child_design=child_design,
         authored_child_design_input=child_bytes,
         authored_builder_input=VNextT0LocalBytesV1(copy(builder_entry.bytes),
            Digest256(builder_entry.sha256)),
         authored_identity_input=VNextT0LocalBytesV1(copy(identity_entry.bytes),
            Digest256(identity_entry.sha256)),
         authored_typed_ledger_source=design.typed_ledger_source))
    semantic_raw = Vector{UInt8}(codeunits(canonical_json(semantic_value)))
    semantic = VNextT0LocalSemanticBodyV1(semantic_value,
        VNextT0LocalBytesV1(semantic_raw,
            Digest256(bytes2hex(SHA.sha256(semantic_raw)))),
        (:up4_r2_g3_feedback_input_bytes, :up4_r2_g3_child_design_input_bytes))
    declaration_raw = Vector{UInt8}(codeunits(canonical_json(declaration)))
    declaration_bytes = VNextT0LocalBytesV1(declaration_raw,
        Digest256(bytes2hex(SHA.sha256(declaration_raw))))
    declaration_ref = QualifiedRefV1("local://up4-r2/G3/declaration/" *
        declaration_bytes.sha256.value, "v1")
    normalized = vnext_t0_local_normalize_g3_feedback_declaration_v1(
        declaration, candidate, source_ref, source_bytes, locator,
        declaration_ref, semantic; frozen_context=root)
    axes = ntuple(i -> QualifiedRefV1(VNEXT_T0_LOCAL_AXIS_IDS_V1[i],
        VNEXT_T0_LOCAL_AXIS_VERSION_V1), 4)
    source_identity = canonical_hash((kind=:source, ref=source_ref,
        bytes_sha256=source_bytes.sha256))
    declaration_identity = canonical_hash((kind=:declaration, ref=declaration_ref,
        bytes_sha256=declaration_bytes.sha256))
    factory_receipt = VNextT0LocalFactoryReceiptV1(candidate, :G3,
        source_ref, declaration_ref, axes, :present, normalized)
    declaration_receipt = VNextT0LocalDeclarationReceiptV1(candidate, :G3,
        source_ref, declaration_ref, axes, :present, normalized)
    VNextT0LocalPresentDeclarationV1(:G3, candidate, source_ref,
        declaration_ref, source_identity, declaration_identity, axes,
        source_bytes, declaration_bytes, semantic, locator,
        factory_receipt, declaration_receipt)
end


function _vnext_current_source_records_v1(built)
    root = built.root
    candidate = built.candidate_ref
    source(path) = NativeGitReadCompatibilityV1.current_source(root, path)
    no_git = (:not_observed, :not_observed, :not_observed)
    g1_path = G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
    g1_entry = source(g1_path)
    g1_locator = G1IndependentSourceLocatorV1(root, "current-source", g1_path,
        g1_entry.byte_count, Digest256(g1_entry.sha256), no_git[1], no_git[2],
        no_git[3], nothing, :current_source)
    g2_path = G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
    g2_entry = source(g2_path)
    g2_locator = G2IndependentSourceLocatorV1(root, "current-source", g2_path,
        g2_entry.byte_count, Digest256(g2_entry.sha256), no_git[1], no_git[2],
        no_git[3], nothing, :current_source)
    g3_path = _g3s_expected_source(:bundle)
    g3_entry = source(g3_path)
    g3_locator = G3IndependentSourceLocatorV1(:bundle, root, "current-source",
        g3_path, g3_entry.byte_count, Digest256(g3_entry.sha256), no_git[1],
        no_git[2], no_git[3], nothing)
    handle = QualifiedRefV1(G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
    g1_axes = G1VersionAxesV2(QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        QualifiedRefV1("fusion.g1.applicability", "v2"),
        QualifiedRefV1("fusion.g1.receipt", "v2"))
    g2_axes = G2VersionAxesV2(QualifiedRefV1("fusion.g2.payload-schema", "v5"),
        QualifiedRefV1("fusion.g2.canonicalization", "v5"),
        QualifiedRefV1("fusion.g2.applicability", "v5"),
        QualifiedRefV1("fusion.g2.receipt", "v5"))
    g1_declaration = built.g1.declaration
    g1_constructor = G1SourceDeclarationConstructorV1(g1_diffusion_declaration_v1,
        candidate, g1_declaration.operators, g1_declaration.closure_ref,
        g1_declaration.applicability_ref, g1_declaration.applicability_domain,
        g1_declaration.negative_controls)
    g2_constructor = G2SourceDeclarationConstructorV1(g2mb_declaration_v1)
    raw_g1 = g1_source_authority_factory_v1(g1_locator, handle,
        _g1sf_expected_contract(built.g1.source_payload), built.g1.source_payload, g1_axes,
        g1_constructor, root)
    raw_g2 = g2_source_authority_factory_v1(g2_locator, handle,
        built.g2.contract_ref, built.g2.source, g2_axes, g2_constructor, root)
    g3_handle = QualifiedRefV1(G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
    g3_declaration_ref = QualifiedRefV1(
        "fusionconceptai://GenomeV5/G3/bundle/source-declaration/up4-r2", "v1")
    raw_g3 = g3_source_authority_factory_v1(:bundle, g3_locator, g3_handle,
        g3_contract_ref(:bundle), g3_version_axes(:bundle), g3_declaration_ref, root)
    all(x.receipt.status === :present for x in (raw_g1, raw_g2, raw_g3)) ||
        throw(ArgumentError("current-source authority factory did not produce present declarations"))

    g2_record = _vnext_current_source_present_record_v1(raw_g2, :G2, candidate,
        built.entries.g2_source_jl, g2_entry, root)
    g1_record = _vnext_current_source_present_record_v1(raw_g1, :G1, candidate,
        built.entries.g1_source_jl, g1_entry, root;
        expression_entry=built.entries.native_mms_source_expressions_json,
        g2_record=g2_record)
    g3_record = _vnext_current_source_g3_record_v1(candidate, built.g3,
        built.entries.g3_source_jl, built.entries.identity_jl,
        built.entries.g3_child_design_source_jl, built.child_design, root)
    declarations = (g1_record, g2_record, g3_record)
    child_entry = built.entries.g3_child_design_source_jl
    child_sha = Digest256(built.child_sha)
    child_source_ref = QualifiedRefV1("fusionconceptai://candidate-design/" *
        replace(candidate.id, "fusionconceptai://candidate-design/" => "") *
        "/g3-child-design", "v1")
    children = ntuple(i -> begin
        kind = VNEXT_T0_LOCAL_CHILD_KINDS_V1[i]
        child_bytes = VNextT0LocalBytesV1(copy(child_entry.bytes), child_sha)
        child_locator = _vnext_current_source_locator_v1(root, child_entry,
            child_source_ref)
        body = (kind=kind, source_ref=child_source_ref, source_sha256=child_sha,
            contract=:candidate_bound_g3, child_design=built.child_design)
        # T1 binding contract on only the explicit-SI v2 child envelope.
        # Historical child-body bytes keep their original shape.
        if kind === :binding && hasproperty(built.child_design, :schema) &&
                built.child_design.schema == "up4-r2-g3-child-design-source-v2"
            body = merge(body,
                (contract_ref=g3_contract_ref(:binding),))
        end
        child_ref = QualifiedRefV1("local://GenomeV5/G3/" * String(kind) * "/" *
            child_sha.value, "v1")
        body_hash = canonical_hash(body)
        identity_hash = canonical_hash((candidate_ref=candidate, layer=:G3,
            child_id=String(kind), kind=kind, child_ref=child_ref,
            body_hash=body_hash, source_ref=child_source_ref,
            source_sha256=child_sha))
        VNextT0LocalChildPresentV1(kind, candidate, :G3, String(kind), child_ref,
            child_source_ref, child_bytes, child_locator, body, body_hash, identity_hash)
    end, 3)
    feedback = Tuple(begin
        target_record = only(filter(record -> record.layer === target.target_layer,
            declarations))
        body = (candidate_ref=candidate, source_ref=target_record.source_ref,
            declaration_ref=target_record.declaration_ref,
            target_ref=target_record.source_ref, feedback_targets=(target,),
            source_g3_ref=g3_record.source_ref,
            source_g3_declaration_ref=g3_record.declaration_ref, target=target)
        VNextT0LocalFeedbackV1(target.target_id, target.target_layer, candidate,
            target_record.source_ref, body, canonical_hash(body))
    end for target in built.g3.declaration.feedback_targets)
    (candidate=candidate, declarations=declarations, children=children,
        feedback=feedback, g1=raw_g1, g2=raw_g2, g3=raw_g3,
        g3_record=g3_record)
end

function _vnext_current_source_independent_g3_inputs_v1(built, records, transport)
    child_entry = built.entries.g3_child_design_source_jl
    child_sha = Digest256(built.child_sha)
    child_sha.value == child_entry.sha256 ||
        throw(ArgumentError("independent G3 child source digest mismatch"))
    source_input=VNextT0LocalBytesV1(copy(child_entry.bytes), child_sha)
    invocation=built.g3_factory_invocation
    source=if invocation===nothing
        vnext_t2_v3_rebuild_g3_child_design_source_v1(
            source_input,child_sha,child_entry.logical_path)
    else
        invocation.source_path==child_entry.logical_path ||
            throw(ArgumentError("independent G3 factory path differs from the validated manifest"))
        vnext_t2_v3_rebuild_g3_child_design_source_v1(
            source_input,child_sha,child_entry.logical_path;
            candidate_id=invocation.candidate_id,scenario_id=invocation.scenario_id,
            re_enable_threshold_kelvin=invocation.re_enable_threshold_kelvin)
    end
    source.schema in ("up4-r2-g3-child-design-source-v1",
        "up4-r2-g3-child-design-source-v2") &&
        (source.schema == "up4-r2-g3-child-design-source-v1" ||
            source.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd)) &&
        source.design_scope == "candidate_design_only" &&
        source.candidate_id == built.identity.candidate_id &&
        source.scenario_id == built.identity.scenario_id &&
        source.source_path == child_entry.logical_path &&
        source.physical_validation === false &&
        source.engineering_validation === false &&
        source.measurement_authority === false &&
        source.upstream_G1_authority === :missing &&
        source.upstream_G2_authority === :missing ||
        throw(ArgumentError("independent G3 raw child source contract mismatch"))
    occursin("no validated transfer function, plant model, or G1/G2 coupling",
        source.control_design.applicability) ||
        throw(ArgumentError("independent G3 child source exceeds its declared scope"))

    candidate = records.candidate
    t0_g3 = transport.declarations[3]
    parent_ref = t0_g3.declaration_ref
    parent_hash = t0_g3.declaration_identity_hash

    # This follows scripts/up1_g3_expected_commitment_producer_v1.jl's
    # _derive_after_schema derivation over the raw child design. It does not
    # consult the authored G3 builder's state or the consumer's child states.
    realization_body = source.realization
    realization_key = G3RealizationChildKeyV1(candidate, parent_hash,
        G3_REALIZATION_CHILD_EDIT_KIND_V1, realization_body.source_id)
    realization_record = g3_realization_source_record_v1(candidate;
        source_uri="fusionconceptai://GenomeV5/G3/local-authored-realization-source",
        source_version="candidate-design-v1",
        schema_ref=QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-schema", "v1"),
        schema_hash=g3_realization_child_edit_schema_hash_v1(),
        canonicalization_ref=QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-canonicalization", "v1"),
        canonicalization_hash=g3_realization_child_edit_canonicalization_hash_v1(),
        profile_ref=QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-profile", "v1"),
        profile_hash=g3_realization_child_edit_profile_hash_v1(),
        evidence_receipt_ref=QualifiedRefV1(
            "fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2/g3-child-design-source", "v1"),
        evidence_receipt_hash=child_sha)
    realization_payload = g3_realization_source_payload_v1(realization_key,
        parent_ref, realization_body, realization_record)
    realization_state = g3_realization_initial_state_v1(realization_key,
        realization_payload)
    realization_state.state_status === :present ||
        throw(ArgumentError("independent realization source did not admit"))
    realization_source_ref = QualifiedRefV1(realization_record.source_uri,
        realization_record.source_version)
    realization_expected = VNextG3BindingChildExpectedCommitmentV1(
        :realization, candidate, parent_ref, parent_hash,
        QualifiedRefV1("local://GenomeV5/G3/realization:" * realization_key.child_id, "v1"),
        realization_payload.child_contract_ref, realization_source_ref,
        realization_record.source_record_hash,
        realization_payload.source_content_hash,
        realization_payload.child_contract_identity_hash,
        realization_state.state_hash)

    control_body = source.control
    control_key = G3ControlChildKeyV1(candidate, parent_hash,
        G3_CONTROL_CHILD_EDIT_KIND_V1, control_body.source_id)
    control_contract = GenomeContractRef(G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,
        G3_CONTROL_CHILD_EDIT_VERSION_V1, g3_control_child_edit_schema_hash_v1(),
        g3_control_child_edit_canonicalization_hash_v1(),
        G3_CONTROL_CHILD_EDIT_PROFILE_V1)
    control_path = String(source.source_path)
    slot(kind, suffix, digest) = G3ControlProvenanceSlotV1(kind, :present,
        QualifiedRefV1("fusionconceptai://GenomeV5/G3/control-child/" * suffix, "v1"),
        control_path, digest, candidate, nothing, nothing)
    control_slots = (
        slot(:payload_schema_version, "schema", g3_control_child_edit_schema_hash_v1()),
        slot(:canonicalization_profile_version, "canonicalization", g3_control_child_edit_canonicalization_hash_v1()),
        slot(:applicability_profile_version, "profile", g3_control_child_edit_profile_hash_v1()),
        slot(:evidence_receipt_version, "candidate-source", child_sha))
    control_record_body = (record_uri=G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,
        record_version=G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
        payload_schema_version=control_slots[1],
        canonicalization_profile_version=control_slots[2],
        applicability_profile_version=control_slots[3],
        evidence_receipt_version=control_slots[4])
    control_record = G3ControlSourceRecordV1(control_record_body.record_uri,
        control_record_body.record_version, control_slots[1], control_slots[2],
        control_slots[3], control_slots[4], canonical_hash(control_record_body))
    control_state = g3_control_admit_source_v1(control_key, parent_ref,
        control_body, control_contract, control_record)
    control_state.state_status === :present ||
        throw(ArgumentError("independent control source did not admit"))
    control_ref = control_state.source_payload_ref
    control_payload = G3ControlSourcePayloadV1(control_state.key,
        control_ref.parent_g3_declaration_ref, control_ref.parent_g3_declaration_hash,
        control_ref.child_contract_ref, control_ref.child_contract_identity_hash,
        control_record.record_uri, control_record.record_version,
        control_state.editable_body, control_record, control_ref.source_content_hash)
    control_source_ref = QualifiedRefV1(control_record.record_uri,
        control_record.record_version)
    control_expected = VNextG3BindingChildExpectedCommitmentV1(
        :control, candidate, parent_ref, parent_hash,
        QualifiedRefV1("local://GenomeV5/G3/control:" * control_key.child_id, "v1"),
        control_contract, control_source_ref, control_record.source_record_hash,
        control_ref.source_content_hash, control_ref.child_contract_identity_hash,
        control_state.current_state_hash)

    expected = vnext_g3_binding_expected_commitment_v1(candidate,
        transport.bundle_hash, parent_ref, parent_hash,
        realization_expected, control_expected)
    declaration = records.g3_record.semantic_body.body
    binding_key = G3BindingChildKeyV2(candidate, parent_ref, parent_hash,
        :binding, "local-authored-binding-r2")
    initial_links = Tuple(G3BindingLinkV1(target.target_id, target.target_layer,
        target.target_path, target.quantity, target.unit, target.direction,
        target.sign, target.source_id, target.owner_scope, target.authority)
        for target in declaration.feedback_targets)
    (expected=expected, realization_state=realization_state,
     control_payload=control_payload, control_state=control_state,
     binding_key=binding_key, initial_links=initial_links)
end

"""Build the fresh typed V5 identity from the exact current T0/T1 source run.

No factory is rerun here: G1 uses the V5 source result already built from the
manifest-pinned expression record, G2 consumes the present factory result
retained by `records`, and G3 joins the present T1 record/child carriers to the
independent T2 child rebuild. This creates a current V5 package; it does not
claim a lossless legacy V4 migration.
"""
function _vnext_current_v5_identity_package_v1(built, records, witness_result, t0_transport)
    built.g1_v5_source !== nothing ||
        throw(ArgumentError("current G1 V5 source builder is unavailable"))
    witness_result.source_ready && witness_result.witness !== nothing ||
        throw(ArgumentError("current T2 source witness is not source-ready"))
    g1_record = only(Tuple(d for d in records.declarations if d.layer === :G1))
    g3_record = only(Tuple(d for d in records.declarations if d.layer === :G3))
    g3_children = t0_transport.children
    Tuple(records.children) == Tuple(g3_children) ||
        throw(ArgumentError("current T1 children differ from the T0 transport carriers"))
    binding_child = only(Tuple(c for c in g3_children if c.kind === :binding))
    g1_source = built.g1_v5_source
    g1_source.g1_v5 isa MechanismGenomeV5 &&
        g1_source.source_candidate_ref == records.candidate ||
        throw(ArgumentError("current G1 V5 source projection candidate mismatch"))
    hashes = g1_source.source_expression_hashes
    g1_source_projection = (candidate_ref=records.candidate,
        source_declaration_ref=g1_record.declaration_ref,
        source_bytes_sha256=g1_record.source_bytes.sha256,
        declaration_identity_hash=g1_record.declaration_identity_hash,
        unknown_source_expression_sha256=hashes.unknown isa Digest256 ?
            hashes.unknown : Digest256(String(hashes.unknown)),
        source_expression_sha256=hashes.manufactured isa Digest256 ?
            hashes.manufactured : Digest256(String(hashes.manufactured)),
        g1_candidate_hash=g1_source.g1_v5.candidate_hash)
    g1_source_projection = merge(g1_source_projection,
        (source_projection_hash=canonical_hash((
            domain="up4-r2-g1-v5-source-projection-v1",
            candidate_ref=g1_source_projection.candidate_ref,
            source_declaration_ref=g1_source_projection.source_declaration_ref,
            source_bytes_sha256=g1_source_projection.source_bytes_sha256,
            declaration_identity_hash=g1_source_projection.declaration_identity_hash,
            unknown_source_expression_sha256=g1_source_projection.unknown_source_expression_sha256,
            source_expression_sha256=g1_source_projection.source_expression_sha256,
            g1_candidate_hash=g1_source_projection.g1_candidate_hash)),))
    g1_source_projection = merge(g1_source_projection,
        (source_record=g1_record, frozen_context=built.root))

    g2_projection = g2_v5_source_projection_v1(records.g2)
    invocation=built.g3_factory_invocation
    rebuilt_child=if invocation===nothing
        vnext_t2_v3_rebuild_g3_child_design_source_v1(
            binding_child.source_bytes,binding_child.source_locator.source_sha256,
            binding_child.source_locator.source_path)
    else
        invocation.source_path==binding_child.source_locator.source_path ||
            throw(ArgumentError("current identity G3 factory path differs from child locator"))
        vnext_t2_v3_rebuild_g3_child_design_source_v1(
            binding_child.source_bytes,binding_child.source_locator.source_sha256,
            binding_child.source_locator.source_path;
            candidate_id=invocation.candidate_id,scenario_id=invocation.scenario_id,
            re_enable_threshold_kelvin=invocation.re_enable_threshold_kelvin)
    end
    g3_payload = g3_authored_realization_payload_v1(g3_record, g3_children,
        rebuilt_child; frozen_context=built.root,
        g3_factory_invocation=invocation)
    g3_aggregate = g3_authored_source_design_aggregate_v1(g3_payload;
        g1_contract_ref=g1_source.g1_v5.contract_ref,
        g2_contract_ref=g2_projection.genome.contract_ref)
    source_proof=(record=g3_record, children=g3_children,
        rebuilt_child=rebuilt_child, frozen_context=built.root)
    source_proof=invocation===nothing ? source_proof :
        merge(source_proof,(g3_factory_invocation=invocation,))
    integrate_genome_v5(g1_source.g1_v5, g2_projection, g3_aggregate;
        candidate_ref=records.candidate,
        g1_source_projection=g1_source_projection,
        g3_source_proof=source_proof)
end

"""Read real current sources, independently derive G3 authority, and run T0 through T1."""
function vnext_current_source_t0_t1_local_v1(source_root::AbstractString,
        candidate_directory::AbstractString)
    built = _vnext_current_source_candidate_records_v1(source_root,
        candidate_directory)
    records = _vnext_current_source_records_v1(built)
    t0 = vnext_declaration_transport_local_v1(records.candidate,
        records.declarations, records.children, records.feedback;
        frozen_context=built.root)
    t0.status === :valid || return (status=t0.status,
        resolution=t0.resolution, t0=t0, recheck=nothing, parent=nothing,
        bridge=nothing, witness=nothing, witness_validation=nothing, t1=nothing)
    independent = _vnext_current_source_independent_g3_inputs_v1(built,
        records, t0.transport)
    result = if built.g3_factory_invocation===nothing
        _vnext_current_source_continue_v1(records.candidate, t0, built.root,
            independent.expected, independent.realization_state,
            independent.control_payload, independent.control_state,
            independent.binding_key; initial_links=independent.initial_links)
    else
        _vnext_current_source_continue_v1(records.candidate, t0, built.root,
            independent.expected, independent.realization_state,
            independent.control_payload, independent.control_state,
            independent.binding_key; initial_links=independent.initial_links,
            g3_factory_invocation=built.g3_factory_invocation)
    end
    if result.t1 !== nothing && result.witness !== nothing &&
            result.witness.source_ready && result.witness_validation !== nothing &&
            result.witness_validation.status === :source_ready
        try
            identity_package = _vnext_current_v5_identity_package_v1(built,
                records, result.witness, result.t0.transport)
            return merge(result, (identity_package=identity_package,
                identity_package_status=:valid, identity_package_reason=nothing))
        catch err
            @error "current V5 identity package remains unavailable" exception=(err, catch_backtrace())
            return merge(result, (identity_package=nothing,
                identity_package_status=:fail_closed,
                identity_package_reason=:current_source_component_identity_join_incomplete))
        end
    end
    merge(result, (identity_package=nothing,
        identity_package_status=:typed_absent,
        identity_package_reason=:current_t0_t1_t2_source_witness_not_ready))
end
