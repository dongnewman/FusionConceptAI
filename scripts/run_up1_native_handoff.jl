using SHA
using TOML
using JSON3
using Serialization
using Pkg

const _NATIVE_RUN_START_NS = time_ns()
ENV["UP1_NATIVE_RUN_START_NS"] = string(_NATIVE_RUN_START_NS)

function _native_require(condition, message)
    condition || throw(ArgumentError(message))
    nothing
end

function _native_stage(marker)
    elapsed_seconds = Float64(time_ns() - _NATIVE_RUN_START_NS) / 1.0e9
    println("UP1_NATIVE_STAGE\t", round(elapsed_seconds; digits=3), "\t", marker)
    flush(stdout)
    nothing
end

function _native_rational3(values, name)
    length(values) == 3 || throw(ArgumentError(name * " must have three values"))
    Tuple(begin
        parts = split(String(value), "/"; limit=2)
        length(parts) == 2 || throw(ArgumentError(name * " contains a non-rational value"))
        parse(Int64, parts[1]) // parse(Int64, parts[2])
    end for value in values)
end

function _native_rational(value, name)
    parts = split(String(value), "/"; limit=2)
    length(parts) == 2 || throw(ArgumentError(name * " is not a rational value"))
    parse(Int64, parts[1]) // parse(Int64, parts[2])
end

function _native_write_new(path, raw)
    ispath(path) && throw(ArgumentError("refusing to overwrite handoff receipt: " * path))
    mkpath(dirname(abspath(path)))
    io = Base.Filesystem.open(path,
        Base.JL_O_WRONLY | Base.JL_O_CREAT | Base.JL_O_EXCL, 0o666)
    try
        write(io, raw)
        flush(io)
    finally
        close(io)
    end
    read(path) == raw || throw(ArgumentError("handoff receipt bytes changed after write"))
    nothing
end

function _native_serialized_bytes(value)
    io = IOBuffer()
    Serialization.serialize(io, value)
    take!(io)
end

_native_frozen_source(N, context, logical_path) =
    begin
        _native_stage("frozen_read_begin:" * String(logical_path))
        entry = Base.invokelatest(getproperty(N, :frozen_source), context, logical_path)
        _native_stage("frozen_read_complete:" * String(logical_path))
        entry
    end

function _native_t1_runtime_handoff(state, plan, bundle)
    handoff = Base.invokelatest(
        state.R.finalize_native_g1g2_t1_handoff_v1,
        state.admission, state.compilation.compilation, plan, bundle)
    handoff.status === (bundle.report.status === :pass ?
        :executed_local : :numerical_fail) &&
        handoff.resolution === :terminal_deferred &&
        !handoff.accepted &&
        Base.invokelatest(string, handoff.claim_ceiling) == "screen_only" &&
        handoff.physical_status === :unknown &&
        handoff.errors == bundle.report.errors &&
        handoff.gaps == bundle.report.gaps &&
        handoff.candidate_ref == state.admission.package.candidate_ref &&
        handoff.package_hash == state.admission.package.package_hash &&
        handoff.semantic_identity == state.admission.package.semantic_identity &&
        handoff.wire_hash == state.admission.package.wire.sha256 &&
        handoff.t0_bundle_hash == state.admission.package.bundle_hash &&
        handoff.scenario_hash == Base.invokelatest(
            state.R.canonical_hash, state.compilation.compilation.scenario) &&
        handoff.bundle_hash == bundle.bundle_hash &&
        handoff.report_hash == bundle.report.report_hash ||
        error("actual T1 runtime handoff rejected current candidate/package/Gridap result")
    handoff
end

function _native_gridap_execute_a_v1(state, plan; verify_attempt_cache=false)
    _native_stage("gridap_three_level_execute_begin")
    if verify_attempt_cache
        store = Dict{Any,Any}()
        isempty(store) || error("native Gridap attempt store must start empty")
        key = plan.solver_input.solver_input_hash
        bundle = Base.invokelatest(state.R.execute_native_g1g2_gridap_once!, store, plan)
        Base.invokelatest(haskey, store, key) &&
            Base.invokelatest(getindex, store, key) === bundle ||
            error("native Gridap first call did not store its executed bundle")
        cached = Base.invokelatest(state.R.execute_native_g1g2_gridap_once!, store, plan)
        cached === bundle || error("native Gridap same-attempt cache did not return the stored bundle")
        attempt_cache = (scope="process_local_empty_store", process_id=getpid(),
            plan_hash=plan.plan_hash.value, solver_input_hash=key.value,
            first_bundle_hash=bundle.bundle_hash.value,
            second_bundle_hash=cached.bundle_hash.value,
            second_call_reused_same_bundle=true,
            invocation_counts=bundle.invocation_counts)
    else
        bundle = Base.invokelatest(state.R.execute_native_g1g2_gridap_once!, Dict(), plan)
        attempt_cache = nothing
    end
    _native_stage("gridap_three_level_execute_complete")
    handoff = _native_t1_runtime_handoff(state, plan, bundle)
    (bundle=bundle, handoff=handoff, attempt_cache=attempt_cache)
end

function _native_gridap_handoff(phase, state)
    N, context, R, snapshot_root = state.N, state.context, state.R, state.snapshot_root
    qualification_dir = joinpath(snapshot_root, "runtime_project", "tools",
        "qualification", "gridap")
    project_entry = _native_frozen_source(N, context,
        "runtime_project/tools/qualification/gridap/Project.toml")
    manifest_entry = _native_frozen_source(N, context,
        "runtime_project/tools/qualification/gridap/Manifest.toml")
    field_entry = _native_frozen_source(N, context,
        "runtime_project/src/RuntimeV4/GridapFieldResidualAdapter.jl")
    adapter_entry = _native_frozen_source(N, context,
        "runtime_project/src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl")
    active_before = normpath(Base.active_project())
    active_before == joinpath(snapshot_root, "runtime_project", "Project.toml") ||
        error("Gridap handoff did not begin in the frozen UP1 runtime project")
    _native_stage("gridap_qualification_activation_begin")
    Base.invokelatest(Pkg.activate, qualification_dir; io=devnull)
    active_after = normpath(Base.active_project())
    active_after == joinpath(qualification_dir, "Project.toml") ||
        error("Gridap qualification project was not activated from the frozen snapshot")
    _native_stage("gridap_qualification_activation_complete")
    _native_stage("gridap_adapter_include_begin")
    Base.include(R, joinpath(snapshot_root, split(field_entry.logical_path, '/')...))
    Base.include(R, joinpath(snapshot_root, split(adapter_entry.logical_path, '/')...))
    _native_stage("gridap_adapter_include_complete")
    if phase === :gridap_prepare
        _native_stage("gridap_plan_stage_begin")
        protocol = Base.invokelatest(R.native_g1g2_numerical_protocol_v1)
        staged = Base.invokelatest(R.stage_gridap_native_g1g2_diffusion_v1,
            state.compilation, protocol)
        staged.validation_state === :plan_validation_deferred &&
            staged.numerical_execution === :not_executed &&
            staged.accepted === false ||
            error("Gridap staged plan exceeded its no-credit ceiling")
        plan = staged.plan
        _native_stage("gridap_plan_stage_complete")
    else
        prepare_raw = read(state.gridap_prepare_receipt_path)
        prepare_sha = bytes2hex(SHA.sha256(prepare_raw))
        prepare_sha == state.gridap_prepare_receipt_expected_sha ||
            error("Gridap prepare receipt differs from explicit replay pin")
        prepared = JSON3.read(String(copy(prepare_raw)))
        String(prepared.phase) == "gridap_prepare" ||
            error("Gridap prepare receipt names the wrong phase")
        plan_path = normpath(abspath(String(prepared.gridap_plan_path)))
        plan_path != state.receipt_out &&
            plan_path != state.gridap_prepare_receipt_path ||
            error("Gridap plan artifact path collides with a receipt")
        plan_raw = read(plan_path)
        length(plan_raw) == Int(prepared.gridap_plan_bytes) &&
            bytes2hex(SHA.sha256(plan_raw)) == String(prepared.gridap_plan_sha256) ||
            error("Gridap plan artifact bytes or SHA changed")
        _native_stage("gridap_plan_deserialize_begin")
        plan = Base.invokelatest(Serialization.deserialize, IOBuffer(plan_raw))
        _native_stage("gridap_plan_deserialize_complete")
        plan isa R.NativeG1G2GridapPlanV1 ||
            error("reloaded Gridap plan has the wrong type")
        _native_stage("gridap_plan_public_validation_begin")
        Base.invokelatest(R.validate_native_g1g2_gridap_plan_v1, plan) ||
            error("reloaded Gridap plan failed its public validator")
        _native_stage("gridap_plan_public_validation_complete")
        plan.compilation.compilation_hash ==
            state.compilation.compilation.compilation_hash &&
            plan.compile_result_hash == state.compilation.result_hash ||
            error("reloaded Gridap plan differs from frozen Phase-A compilation")
        protocol = plan.protocol
    end
    dependency = plan.dependency_identity
    dependency.project_sha256.value == project_entry.sha256 &&
        dependency.manifest_sha256.value == manifest_entry.sha256 &&
        plan.adapter_source_hash.value == adapter_entry.sha256 ||
        error("Gridap plan differs from frozen qualification lock or adapter bytes")
    common = (schema="up1-native-g1g2-gridap-handoff-v1",
        snapshot_id=context.snapshot_id,
        manifest_sha256=context.manifest_sha256,
        candidate_id=String(state.record.candidate_id),
        scenario_id=String(state.record.scenario_id),
        admission_artifact_sha256=state.artifact_sha,
        g3_expected_receipt_sha256=String(state.sidecar.g3_expected_receipt_sha256),
        phase_a_receipt_sha256=state.phase_a_receipt_sha,
        compilation_artifact_sha256=String(state.phase_a_receipt.compilation_artifact_sha256),
        compiler_result_hash=state.compilation.result_hash.value,
        compiler_status=String(state.compilation.status),
        gridap_field_source_sha256=field_entry.sha256,
        gridap_adapter_source_sha256=adapter_entry.sha256,
        qualification_project_sha256=project_entry.sha256,
        qualification_manifest_sha256=manifest_entry.sha256,
        qualification_active_project_before=active_before,
        qualification_active_project_after=active_after,
        gridap_dependency_hash=dependency.dependency_hash.value,
        gridap_installed_project_sha256=dependency.installed_project_sha256.value,
        protocol_hash=protocol.protocol_hash.value,
        plan_hash=plan.plan_hash.value,
        solver_input_hash=plan.solver_input.solver_input_hash.value)
    if phase === :gridap_prepare
        raw = _native_serialized_bytes(plan)
        _native_write_new(state.gridap_plan_out, raw)
        receipt = merge(common, (phase="gridap_prepare",
            plan_validation_state="plan_validation_deferred",
            numerical_execution="not_executed",
            accepted=false,
            gridap_plan_path=state.gridap_plan_out,
            gridap_plan_bytes=length(raw),
            gridap_plan_sha256=bytes2hex(SHA.sha256(raw)),
            formal_t2_consumer_receipts=0))
        _native_write_new(state.receipt_out,
            Vector{UInt8}(codeunits(JSON3.write(receipt))))
        println("UP1_NATIVE_GRIDAP_PREPARE_PASS\t", context.snapshot_id,
            "\t", plan.plan_hash.value, "\tPhysicsCredit=none")
        return nothing
    end
    String(prepared.plan_validation_state) == "plan_validation_deferred" &&
        String(prepared.numerical_execution) == "not_executed" &&
        prepared.accepted === false ||
        error("Gridap staged-plan receipt claims unearned validation")
    for key in keys(common)
        String(getproperty(prepared, key)) == String(getproperty(common, key)) ||
            error("Gridap prepare receipt differs from current frozen inputs: " *
                String(key))
    end
    if phase === :gridap_a
        execution = _native_gridap_execute_a_v1(state, plan)
        bundle, handoff = execution.bundle, execution.handoff
        report = bundle.report
        raw = _native_serialized_bytes(bundle)
        _native_write_new(state.gridap_artifact_out, raw)
        receipt = merge(common, (phase="gridap_a",
            gridap_prepare_receipt_sha256=prepare_sha,
            gridap_plan_sha256=String(prepared.gridap_plan_sha256),
            gridap_bundle_path=state.gridap_artifact_out,
            gridap_bundle_bytes=length(raw),
            gridap_bundle_sha256=bytes2hex(SHA.sha256(raw)),
            gridap_bundle_hash=bundle.bundle_hash.value,
            gridap_report_hash=report.report_hash.value,
            t1_runtime_status=String(handoff.status),
            t1_runtime_errors=Tuple(String.(handoff.errors)),
            t1_runtime_gaps=Tuple(String.(handoff.gaps)),
            t1_runtime_result_hash=handoff.result_hash.value,
            t1_runtime_package_hash=handoff.package_hash.value,
            t1_runtime_semantic_identity=handoff.semantic_identity.value,
            t1_runtime_wire_hash=handoff.wire_hash.value,
            t1_runtime_t0_bundle_hash=handoff.t0_bundle_hash.value,
            t1_runtime_scenario_hash=handoff.scenario_hash.value,
            numerical_status=String(report.status),
            numerical_resolution=String(report.resolution),
            numerical_accepted=report.accepted,
            claim_ceiling=Base.invokelatest(string, report.claim_ceiling),
            physical_status=String(report.physical_status),
            l2_orders=report.l2_orders, h1_orders=report.h1_orders,
            level_l2_errors=Tuple(level.l2_error for level in report.levels),
            level_h1_errors=Tuple(level.h1_seminorm_error for level in report.levels),
            invocation_counts=bundle.invocation_counts,
            formal_t2_consumer_receipts=0))
        _native_write_new(state.receipt_out,
            Vector{UInt8}(codeunits(JSON3.write(receipt))))
        report.status === :pass || error("native Gridap numerical_fail: " * repr(report.errors))
        println("UP1_NATIVE_GRIDAP_A_PASS\t", context.snapshot_id, "\t",
            bundle.bundle_hash.value, "\tPhysicsCredit=none")
        return nothing
    end
    if phase === :gridap_negative
        _native_stage("gridap_wrong_sign_control_begin")
        declared_level = Base.invokelatest(R.run_native_g1g2_gridap_level_v1,
            plan, 2)
        wrong_sign = Base.invokelatest(R.run_native_g1g2_wrong_sign_control_v1,
            plan; level=2)
        _native_stage("gridap_wrong_sign_control_complete")
        declared_level.status === :pass &&
            wrong_sign.status === :numerical_fail &&
            wrong_sign.source_sign === :reversed_test_control ||
            error("Gridap wrong-sign negative control did not fail numerically")
        wrong_sign.analytic_source_integral < 0 &&
            wrong_sign.matrix_hash == declared_level.matrix_hash &&
            wrong_sign.rhs_hash != declared_level.rhs_hash &&
            wrong_sign.solution_hash != declared_level.solution_hash &&
            isapprox(wrong_sign.assembled_source_integral,
                -declared_level.assembled_source_integral;
                atol=protocol.source_integral_abs_tol, rtol=0.0) &&
            wrong_sign.discrete_interior_reaction_linf <= protocol.residual_abs_tol &&
            wrong_sign.discrete_interior_residual_match_linf <= protocol.residual_abs_tol &&
            abs(wrong_sign.discrete_boundary_reaction_balance_defect) <=
                protocol.reaction_balance_abs_tol ||
            error("Gridap wrong-sign control changed the operator or lacks source/reaction evidence")
        wrong_sign.l2_error > max(2 * declared_level.l2_error,
                protocol.finest_l2_max) &&
            wrong_sign.h1_seminorm_error > max(2 * declared_level.h1_seminorm_error,
                protocol.finest_h1_seminorm_max) ||
            error("Gridap wrong-sign control lacks an independent numerical error increase")
        receipt = merge(common, (phase="gridap_negative",
            gridap_prepare_receipt_sha256=prepare_sha,
            gridap_plan_sha256=String(prepared.gridap_plan_sha256),
            wrong_sign_level=wrong_sign.level,
            wrong_sign_status=String(wrong_sign.status),
            wrong_sign_source_sign=String(wrong_sign.source_sign),
            wrong_sign_level_hash=wrong_sign.level_hash.value,
            declared_level_hash=declared_level.level_hash.value,
            declared_matrix_hash=declared_level.matrix_hash.value,
            reversed_matrix_hash=wrong_sign.matrix_hash.value,
            declared_rhs_hash=declared_level.rhs_hash.value,
            reversed_rhs_hash=wrong_sign.rhs_hash.value,
            declared_solution_hash=declared_level.solution_hash.value,
            reversed_solution_hash=wrong_sign.solution_hash.value,
            declared_assembled_source_integral=declared_level.assembled_source_integral,
            reversed_assembled_source_integral=wrong_sign.assembled_source_integral,
            declared_l2_error=declared_level.l2_error,
            wrong_sign_l2_error=wrong_sign.l2_error,
            declared_h1_error=declared_level.h1_seminorm_error,
            wrong_sign_h1_error=wrong_sign.h1_seminorm_error,
            formal_t2_consumer_receipts=0))
        _native_write_new(state.receipt_out,
            Vector{UInt8}(codeunits(JSON3.write(receipt))))
        println("UP1_NATIVE_GRIDAP_NEGATIVE_PASS\t", context.snapshot_id,
            "\twrong_sign=numerical_fail\tPhysicsCredit=none")
        return nothing
    end
    receipt_raw = read(state.gridap_a_receipt_path)
    receipt_sha = bytes2hex(SHA.sha256(receipt_raw))
    receipt_sha == state.gridap_a_receipt_expected_sha ||
        error("Gridap-A receipt raw SHA differs from explicit replay pin")
    prior = JSON3.read(String(copy(receipt_raw)))
    String(prior.phase) == "gridap_a" ||
        error("Gridap-A receipt names the wrong phase")
    String(prior.gridap_prepare_receipt_sha256) == prepare_sha &&
        String(prior.gridap_plan_sha256) == String(prepared.gridap_plan_sha256) ||
        error("Gridap-A receipt names a different frozen plan")
    for key in keys(common)
        String(getproperty(prior, key)) == String(getproperty(common, key)) ||
            error("Gridap-A receipt differs from current frozen candidate and plan: " *
                String(key))
    end
    bundle_path = normpath(abspath(String(prior.gridap_bundle_path)))
    bundle_path != state.receipt_out &&
        bundle_path != state.gridap_a_receipt_path ||
        error("Gridap bundle path collides with a receipt")
    raw = read(bundle_path)
    length(raw) == Int(prior.gridap_bundle_bytes) &&
        bytes2hex(SHA.sha256(raw)) == String(prior.gridap_bundle_sha256) ||
        error("Gridap bundle artifact bytes or SHA changed")
    _native_stage("gridap_bundle_deserialize_begin")
    bundle = Base.invokelatest(Serialization.deserialize, IOBuffer(raw))
    _native_stage("gridap_bundle_deserialize_complete")
    bundle isa R.NativeG1G2ExecutionBundleV1 ||
        error("reloaded Gridap artifact has the wrong execution bundle type")
    handoff = _native_t1_runtime_handoff(state, plan, bundle)
    _native_stage("gridap_independent_three_level_replay_begin")
    replayed_bundle = Base.invokelatest(R.execute_native_g1g2_gridap_once!, Dict(), plan)
    _native_stage("gridap_independent_three_level_replay_complete")
    replayed_handoff = _native_t1_runtime_handoff(state, plan, replayed_bundle)
    replayed_bundle.bundle_hash == bundle.bundle_hash &&
        replayed_bundle.report.report_hash == bundle.report.report_hash &&
        replayed_bundle.invocation_counts == bundle.invocation_counts &&
        replayed_handoff.result_hash == handoff.result_hash ||
        error("fresh Gridap solve differs from persisted first-process result")
    report = bundle.report
    bundle.bundle_hash.value == String(prior.gridap_bundle_hash) &&
        report.report_hash.value == String(prior.gridap_report_hash) &&
        String(prior.t1_runtime_status) == String(handoff.status) &&
        Tuple(String.(handoff.errors)) == Tuple(String.(prior.t1_runtime_errors)) &&
        Tuple(String.(handoff.gaps)) == Tuple(String.(prior.t1_runtime_gaps)) &&
        String(prior.t1_runtime_result_hash) == handoff.result_hash.value &&
        String(prior.t1_runtime_package_hash) == handoff.package_hash.value &&
        String(prior.t1_runtime_semantic_identity) ==
            handoff.semantic_identity.value &&
        String(prior.t1_runtime_wire_hash) == handoff.wire_hash.value &&
        String(prior.t1_runtime_t0_bundle_hash) == handoff.t0_bundle_hash.value &&
        String(prior.t1_runtime_scenario_hash) == handoff.scenario_hash.value &&
        String(report.status) == String(prior.numerical_status) &&
        String(report.resolution) == String(prior.numerical_resolution) &&
        report.accepted === prior.numerical_accepted &&
        Base.invokelatest(string, report.claim_ceiling) ==
            String(prior.claim_ceiling) &&
        String(report.physical_status) == String(prior.physical_status) &&
        Tuple(report.l2_orders) == Tuple(prior.l2_orders) &&
        Tuple(report.h1_orders) == Tuple(prior.h1_orders) &&
        Tuple(level.l2_error for level in report.levels) ==
            Tuple(prior.level_l2_errors) &&
        Tuple(level.h1_seminorm_error for level in report.levels) ==
            Tuple(prior.level_h1_errors) ||
        error("reloaded Gridap report differs from first-process receipt")
    report.status === :pass || error("reloaded native Gridap numerical_fail")
    receipt = merge(common, (phase="gridap_b",
        gridap_prepare_receipt_sha256=prepare_sha,
        gridap_plan_sha256=String(prepared.gridap_plan_sha256),
        gridap_a_receipt_sha256=receipt_sha,
        gridap_bundle_sha256=String(prior.gridap_bundle_sha256),
        gridap_bundle_hash=bundle.bundle_hash.value,
        fresh_replay_bundle_hash=replayed_bundle.bundle_hash.value,
        gridap_report_hash=report.report_hash.value,
        fresh_replay_report_hash=replayed_bundle.report.report_hash.value,
        t1_runtime_status=String(handoff.status),
        t1_runtime_result_hash=handoff.result_hash.value,
        fresh_replay_t1_runtime_result_hash=replayed_handoff.result_hash.value,
        t1_runtime_package_hash=handoff.package_hash.value,
        t1_runtime_semantic_identity=handoff.semantic_identity.value,
        t1_runtime_wire_hash=handoff.wire_hash.value,
        t1_runtime_t0_bundle_hash=handoff.t0_bundle_hash.value,
        t1_runtime_scenario_hash=handoff.scenario_hash.value,
        fresh_replay_invocation_counts=replayed_bundle.invocation_counts,
        numerical_status=String(report.status),
        numerical_resolution=String(report.resolution),
        numerical_accepted=report.accepted,
        claim_ceiling=Base.invokelatest(string, report.claim_ceiling),
        physical_status=String(report.physical_status),
        formal_t2_consumer_receipts=0))
    _native_write_new(state.receipt_out,
        Vector{UInt8}(codeunits(JSON3.write(receipt))))
    println("UP1_NATIVE_GRIDAP_B_PASS\t", context.snapshot_id, "\t",
        bundle.bundle_hash.value, "\tPhysicsCredit=none")
    nothing
end

function _native_current_source_handoff(args)
    length(args) == 4 || error(
        "usage: run_up1_native_handoff.jl current_source <source-root> " *
        "<candidate-directory> <t1-artifact-out> <handoff-receipt-out>")
    source_root, candidate_directory, artifact_out, receipt_out = args
    root = realpath(String(source_root))
    artifact_path = normpath(abspath(String(artifact_out)))
    receipt_path = normpath(abspath(String(receipt_out)))
    artifact_path != receipt_path ||
        throw(ArgumentError("current-source artifact and receipt paths must differ"))
    ispath(artifact_path) && throw(ArgumentError("preserve existing current-source T1 artifact"))
    ispath(receipt_path) && throw(ArgumentError("preserve existing current-source handoff receipt"))

    G = Base.require(@__MODULE__, :FusionConceptAI)
    Base.invokelatest(G.load_genome_v5_components!)
    Base.invokelatest(G.load_vnext_t2_components_v2!)
    _native_stage("current_source_t0_t1_begin")
    result = Base.invokelatest(G.vnext_current_source_t0_t1_local_v1,
        root, String(candidate_directory))
    _native_stage("current_source_t0_t1_complete")
    result.t1 isa G.VNextT1AdmissionResultV2 ||
        error("current-source chain did not produce the actual V2 T1 result")
    result.t1.status === :prepared_not_executed &&
        result.t1.resolution === :terminal_deferred &&
        result.t1.accepted === false && result.t1.claim_ceiling === :contract_only &&
        result.t1.package !== nothing ||
        error("current-source T1 result did not meet the deferred local contract")
    Base.invokelatest(G.vnext_t1_package_v2_validate, result.t1.package) === nothing ||
        error("current-source T1 package failed its public validator")

    raw = _native_serialized_bytes(result.t1)
    _native_write_new(artifact_path, raw)
    artifact_sha = bytes2hex(SHA.sha256(raw))
    identity_fields = (;)
    if hasproperty(result, :identity_package) && result.identity_package !== nothing
        identity_package = result.identity_package
        identity_package isa G.CandidateStatePackageV5 ||
            error("current source identity artifact is not an actual V5 package")
        identity_package.candidate_ref == result.t1.package.candidate_ref ||
            error("current source identity artifact belongs to another candidate")
        Base.invokelatest(G.load_genome_v5_up2_components!)
        Base.invokelatest(G.n10_identity_projection_from_a, identity_package)
        identity_path = joinpath(dirname(artifact_path), "identity_package.bin")
        identity_path != artifact_path && identity_path != receipt_path ||
            error("current source identity output collides with T1 outputs")
        identity_raw = _native_serialized_bytes(identity_package)
        _native_write_new(identity_path, identity_raw)
        identity_fields = (identity_package_path=identity_path,
            identity_package_bytes=length(identity_raw),
            identity_package_sha256=bytes2hex(SHA.sha256(identity_raw)),
            identity_package_hash=identity_package.candidate_hash.value,
            identity_after=identity_package.migration_receipt.candidate_identity_after,
            identity_package_status=String(result.identity_package_status))
    end
    receipt = (schema="vnext-current-source-t0-t1-handoff-v1",
        source_root=root,
        candidate_directory=String(candidate_directory),
        candidate_ref_id=result.t1.package.candidate_ref.id,
        candidate_ref_version=result.t1.package.candidate_ref.version,
        t0_status=String(result.t0.status),
        t0_resolution=String(result.t0.resolution),
        t0_bundle_hash=result.t0.transport.bundle_hash.value,
        g3_commitment_hash=result.t1.package.g3_authority.commitment_hash.value,
        t1_status=String(result.t1.status),
        t1_resolution=String(result.t1.resolution),
        t1_accepted=result.t1.accepted,
        t1_claim_ceiling=String(result.t1.claim_ceiling),
        t1_package_hash=result.t1.package.package_hash.value,
        t1_package_semantic_identity=result.t1.package.semantic_identity.value,
        artifact_path=artifact_path, artifact_bytes=length(raw),
        artifact_sha256=artifact_sha,
        formal_t2_consumer_receipts=0,
        physical_validation="not_assessed", engineering_validation="not_assessed",
        measurement_authority="missing")
    receipt = merge(receipt, identity_fields)
    _native_write_new(receipt_path, Vector{UInt8}(codeunits(JSON3.write(receipt))))
    println("UP1_NATIVE_CURRENT_SOURCE_T0_T1_PASS\t", result.t0.transport.bundle_hash.value,
        "\t", result.t1.package.package_hash.value, "\tPhysicsCredit=none")
    nothing
end

function _native_current_native_handoff(args)
    length(args) == 6 || error(
        "usage: run_up1_native_handoff.jl current_native <current-root> " *
        "<candidate-directory> <t1-artifact> <t1-handoff-receipt> " *
        "<gridap-plan-out> <plan-result-out>")
    source_root, candidate_directory, t1_artifact_path, t1_receipt_path,
        plan_out, result_out = args
    root = realpath(String(source_root))
    normpath(Base.active_project()) == normpath(joinpath(root, "Project.toml")) ||
        error("current-native handoff must start in the current root project")
    candidate_directory = String(candidate_directory)
    artifact_path = normpath(abspath(String(t1_artifact_path)))
    t1_receipt_path = normpath(abspath(String(t1_receipt_path)))
    plan_path = normpath(abspath(String(plan_out)))
    result_path = normpath(abspath(String(result_out)))
    length(unique((artifact_path, t1_receipt_path, plan_path, result_path))) == 4 ||
        throw(ArgumentError("current-native inputs and outputs must have distinct paths"))
    isfile(artifact_path) || throw(ArgumentError("current T1 artifact is missing"))
    isfile(t1_receipt_path) || throw(ArgumentError("current T1 handoff receipt is missing"))
    ispath(plan_path) && throw(ArgumentError("preserve existing current-native plan artifact"))
    ispath(result_path) && throw(ArgumentError("preserve existing current-native result receipt"))

    _native_stage("current_native_t1_artifact_read_begin")
    artifact_raw = read(artifact_path)
    t1_receipt_raw = read(t1_receipt_path)
    t1_receipt = JSON3.read(String(copy(t1_receipt_raw)))
    t1_receipt.schema == "vnext-current-source-t0-t1-handoff-v1" ||
        error("current T1 handoff receipt schema mismatch")
    String(t1_receipt.t0_status) == "valid" &&
        String(t1_receipt.t0_resolution) == "local_contract_ready" ||
        error("current T0 handoff did not retain its valid deferred result")
    normpath(abspath(String(t1_receipt.artifact_path))) == artifact_path ||
        error("current T1 handoff receipt names a different artifact")
    Int(t1_receipt.artifact_bytes) == length(artifact_raw) &&
        bytes2hex(SHA.sha256(artifact_raw)) == String(t1_receipt.artifact_sha256) ||
        error("current T1 artifact size or SHA differs from its handoff receipt")
    String(t1_receipt.source_root) == root &&
        String(t1_receipt.candidate_directory) == candidate_directory ||
        error("current T1 handoff receipt names a different source root or candidate")
    G = Base.require(@__MODULE__, :FusionConceptAI)
    Base.invokelatest(G.load_genome_v5_components!)
    Base.invokelatest(G.load_vnext_t2_components_v2!)
    admission = Serialization.deserialize(IOBuffer(artifact_raw))
    admission isa G.VNextT1AdmissionResultV2 ||
        error("current T1 artifact has the wrong admission result type")
    admission.status === :prepared_not_executed &&
        admission.resolution === :terminal_deferred &&
        admission.accepted === false &&
        admission.claim_ceiling === :contract_only &&
        admission.package isa G.CandidateStatePackageV5NextV2 ||
        error("current T1 artifact does not have the deferred contract-only result")
    package = admission.package
    Base.invokelatest(G.vnext_t1_package_v2_validate, package) === nothing ||
        error("current T1 package failed its public validator")
    adapter = Base.invokelatest(G.vnext_t1_package_binding_adapter_v2, package)
    adapter.status === :prepared_not_executed &&
        adapter.resolution === :terminal_deferred &&
        adapter.reason === :mapped_prepared_not_executed &&
        adapter.input !== nothing &&
        adapter.package_hash == package.package_hash &&
        adapter.semantic_identity == package.semantic_identity ||
        error("current T1 package-binding adapter rejected the package")
    package.candidate_ref.id == String(t1_receipt.candidate_ref_id) &&
        package.candidate_ref.version == String(t1_receipt.candidate_ref_version) &&
        String(admission.status) == String(t1_receipt.t1_status) &&
        String(admission.resolution) == String(t1_receipt.t1_resolution) &&
        admission.accepted == t1_receipt.t1_accepted &&
        String(admission.claim_ceiling) == String(t1_receipt.t1_claim_ceiling) &&
        package.package_hash.value == String(t1_receipt.t1_package_hash) &&
        package.semantic_identity.value == String(t1_receipt.t1_package_semantic_identity) &&
        package.bundle_hash.value == String(t1_receipt.t0_bundle_hash) &&
        package.g3_authority.commitment_hash.value ==
            String(t1_receipt.g3_commitment_hash) ||
        error("current T1 artifact result differs from handoff receipt metadata")
    _native_stage("current_native_t1_artifact_read_complete")

    _native_stage("current_native_candidate_rebuild_begin")
    built = Base.invokelatest(G._vnext_current_source_candidate_records_v1,
        root, candidate_directory)
    manifest_entry = Base.invokelatest(built.read_current, "manifest.json")
    bytes2hex(SHA.sha256(manifest_entry.bytes)) == manifest_entry.sha256 ||
        error("current candidate manifest bytes differ from source digest")
    records = Base.invokelatest(G._vnext_current_source_records_v1, built)
    current_t0 = Base.invokelatest(G.vnext_declaration_transport_local_v1,
        records.candidate, records.declarations, records.children, records.feedback;
        frozen_context=root)
    current_t0.status === :valid && current_t0.transport !== nothing &&
        current_t0.transport.bundle_hash == package.bundle_hash ||
        error("current G1/G2/G3 transport differs from the actual T1 input bundle")
    expression_entry = built.entries.native_mms_source_expressions_json
    expression_record = built.expression
    g1 = built.g1.declaration
    g2 = built.g2.declaration
    built.candidate_ref == package.candidate_ref ||
        error("current candidate builder ref differs from the actual T1 package")
    candidate_prefix = "fusionconceptai://candidate-design/"
    startswith(package.candidate_ref.id, candidate_prefix) &&
        expression_record.candidate_id ==
            package.candidate_ref.id[length(candidate_prefix)+1:end] ||
        error("current source expression candidate ID differs from the T1 package")
    # Candidate and scenario identity are carried by the manifest and builders;
    # the handoff receipt intentionally does not invent a freeze-snapshot identity.
    expression_record.candidate_id == built.identity.candidate_id &&
        expression_record.scenario_id == built.identity.scenario_id &&
        built.g1.candidate_ref == package.candidate_ref &&
        built.g2.candidate_ref == package.candidate_ref &&
        built.g1.scenario_id == expression_record.scenario_id &&
        built.g2.scenario_id == expression_record.scenario_id ||
        error("current source expression or G1/G2 declarations differ from T1 identity")
    _native_stage("current_native_candidate_rebuild_complete")

    isdefined(Main, :FusionRuntimeV4) &&
        error("current-native reload process unexpectedly preloaded FusionRuntimeV4")
    _native_stage("current_native_runtime_include_begin")
    Base.include(Main, joinpath(root, "src", "RuntimeV4", "FusionRuntimeV4.jl"))
    R = Main.FusionRuntimeV4
    compiler_path = joinpath(root, "src", "RuntimeV4",
        "NativeG1G2DiffusionCompilerV1.jl")
    Base.include(R, compiler_path)
    _native_stage("current_native_runtime_include_complete")

    profile = Base.invokelatest(R.native_g1g2_unit_compatibility_profile_v1;
        source_basis=String(expression_record.profile_source_basis),
        target_basis=String(expression_record.profile_target_basis),
        source_length_axis=Int(expression_record.profile_source_length_axis),
        target_length_axis=Int(expression_record.profile_target_length_axis),
        length_scale_metres=_native_rational(
            expression_record.length_scale_metres, "current-source length scale"))
    profile.profile_hash.value == String(expression_record.profile_hash) ||
        error("rebuilt current-source unit profile hash mismatch")
    programs = Base.invokelatest(R.native_g1g2_program_bundle_v1, profile;
        physical_lower=_native_rational3(expression_record.physical_lower_metres,
            "current-source physical lower"),
        physical_upper=_native_rational3(expression_record.physical_upper_metres,
            "current-source physical upper"),
        k_base=_native_rational3(expression_record.k_base, "current-source K base"),
        k_slope=_native_rational3(expression_record.k_slope, "current-source K slope"))
    programs.unknown_source_expression ==
        String(expression_record.unknown_source_expression) ||
        error("rebuilt unknown expression differs from current candidate source")
    programs.source_expression == String(expression_record.source_expression) ||
        error("rebuilt manufactured source expression differs from current candidate source")
    programs.registry_hash.value == String(expression_record.registry_hash) ||
        error("rebuilt compiler registry hash differs from current candidate projection")
    programs.bundle_hash.value == String(expression_record.bundle_hash) ||
        error("rebuilt compiler bundle hash differs from current candidate projection")
    bundle_canonical_sha = bytes2hex(SHA.sha256(codeunits(
        Base.invokelatest(G.canonical_json, programs))))
    bundle_canonical_sha == String(expression_record.bundle_canonical_sha256) ||
        error("rebuilt canonical compiler bundle differs from current candidate projection")
    expression_sha = bytes2hex(SHA.sha256(expression_entry.bytes))
    expression_sha == expression_entry.sha256 ||
        error("current native expression bytes changed after manifest validation")

    native_errors = Base.invokelatest(R.native_g1g2_t1_binding_errors_v1,
        admission, g1, g2)
    isempty(native_errors) ||
        error("current source-built G1/G2 declarations differ from actual T1 package: " *
            repr(native_errors))
    scenario = (scenario_id=String(expression_record.scenario_id),
        execution_scope=:numerical_preparation)
    _native_stage("current_native_compile_begin")
    compilation = Base.invokelatest(R.compile_native_g1g2_diffusion_v1,
        admission, g1, g2, programs, profile; scenario=scenario)
    _native_stage("current_native_compile_complete")
    compilation.status === :compiled_numerical_preparation &&
        compilation.resolution === :terminal_deferred &&
        compilation.accepted === false &&
        compilation.claim_ceiling === :contract_only &&
        compilation.compilation !== nothing && isempty(compilation.errors) ||
        error("current-native compile result exceeded or missed its contract-only ceiling: " *
            repr(compilation.errors))
    Base.invokelatest(R.validate_native_g1g2_diffusion_compilation_v1,
        compilation.compilation) ||
        error("current-native compilation failed public validation")

    qualification_dir = joinpath(root, "tools", "qualification", "gridap")
    project_path = joinpath(qualification_dir, "Project.toml")
    manifest_path = joinpath(qualification_dir, "Manifest.toml")
    project_sha = bytes2hex(SHA.sha256(read(project_path)))
    manifest_sha = bytes2hex(SHA.sha256(read(manifest_path)))
    _native_stage("current_native_gridap_activation_begin")
    Base.invokelatest(Pkg.activate, qualification_dir; io=devnull)
    normpath(Base.active_project()) == normpath(project_path) ||
        error("current Gridap qualification project was not activated")
    Base.include(R, joinpath(root, "src", "RuntimeV4",
        "GridapFieldResidualAdapter.jl"))
    Base.include(R, joinpath(root, "src", "RuntimeV4",
        "GridapNativeG1G2DiffusionAdapterV1.jl"))
    _native_stage("current_native_gridap_activation_complete")
    current_project_sha = bytes2hex(SHA.sha256(read(project_path)))
    current_manifest_sha = bytes2hex(SHA.sha256(read(manifest_path)))
    current_project_sha == project_sha && current_manifest_sha == manifest_sha ||
        error("current Gridap qualification lock changed during activation")
    protocol = Base.invokelatest(R.native_g1g2_numerical_protocol_v1,
        compilation.compilation.form.g2_declaration.source.mesh.cells)
    _native_stage("current_native_gridap_prepare_begin")
    plan = Base.invokelatest(R.prepare_gridap_native_g1g2_diffusion_v1,
        compilation, protocol)
    _native_stage("current_native_gridap_prepare_complete")
    plan isa R.NativeG1G2GridapPlanV1 &&
        Base.invokelatest(R.validate_native_g1g2_gridap_plan_v1, plan) ||
        error("current-native Gridap plan failed its public validator")
    plan.compilation.compilation_hash == compilation.compilation.compilation_hash &&
        plan.compile_result_hash == compilation.result_hash &&
        plan.compilation.form.t1_package_hash == package.package_hash &&
        plan.compilation.form.t1_semantic_identity == package.semantic_identity &&
        plan.compilation.form.t0_bundle_hash == package.bundle_hash &&
        plan.compilation.form.candidate_ref == package.candidate_ref ||
        error("current-native plan is not bound to the actual current T1 package")
    expected_protocol = Base.invokelatest(R.native_g1g2_numerical_protocol_v1,
        compilation.compilation.form.g2_declaration.source.mesh.cells)
    Base.invokelatest(G.canonical_json, protocol) ==
        Base.invokelatest(G.canonical_json, expected_protocol) ||
        error("current-native plan differs from the source-derived three-level protocol")
    admission_token = Base.invokelatest(R.native_g1g2_gridap_plan_admission_v1, plan)
    admission_token isa R.NativeG1G2GridapPlanAdmissionV1 &&
        Base.invokelatest(R.validate_native_g1g2_gridap_plan_admission_v1,
            plan, admission_token) ||
        error("current-native plan has no valid public plan admission")
    plan_raw = _native_serialized_bytes(plan)
    _native_write_new(plan_path, plan_raw)
    plan_sha = bytes2hex(SHA.sha256(plan_raw))
    result = (schema="up1-native-current-source-gridap-plan-v1",
        plan_validation_state="validated_plan", numerical_execution="not_executed",
        accepted=compilation.accepted, claim_ceiling=String(compilation.claim_ceiling),
        candidate_ref_id=package.candidate_ref.id,
        artifact_bytes=length(plan_raw), artifact_sha256=plan_sha,
        plan_hash=plan.plan_hash.value,
        package_hash=package.package_hash.value,
        semantic_identity=package.semantic_identity.value,
        bundle_hash=package.bundle_hash.value,
        three_level_protocol=(cell_counts=protocol.cell_counts,
            quadrature_degree=protocol.quadrature_degree,
            solver=String(protocol.solver), protocol_hash=protocol.protocol_hash.value))
    result_raw = Vector{UInt8}(codeunits(JSON3.write(result)))
    _native_write_new(result_path, result_raw)
    println("UP1_NATIVE_CURRENT_SOURCE_GRIDAP_PLAN_PASS\t",
        package.candidate_ref.id, "\t", plan.plan_hash.value,
        "\tNumericalExecution=not_executed\tPhysicsCredit=none")
    nothing
end

function _native_current_native_numeric_handoff(args)
    length(args) == 9 || error(
        "usage: run_up1_native_handoff.jl current_native_numeric <current-root> " *
        "<candidate-directory> <t1-artifact> <t1-handoff-receipt> " *
        "<native-plan> <native-plan-result> <bundle-out> " *
        "<heat-lift-receipt-out> <numeric-receipt-out>")
    source_root, candidate_directory, t1_artifact_path, t1_receipt_path,
        plan_path_arg, plan_result_path_arg, bundle_out_arg,
        heat_lift_out_arg, result_out_arg = args
    root = realpath(String(source_root))
    normpath(Base.active_project()) == normpath(joinpath(root, "Project.toml")) ||
        error("current-native numeric consumer must start in the current root project")
    candidate_directory = String(candidate_directory)
    artifact_path = normpath(abspath(String(t1_artifact_path)))
    t1_receipt_path = normpath(abspath(String(t1_receipt_path)))
    plan_path = normpath(abspath(String(plan_path_arg)))
    plan_result_path = normpath(abspath(String(plan_result_path_arg)))
    bundle_path = normpath(abspath(String(bundle_out_arg)))
    heat_lift_path = normpath(abspath(String(heat_lift_out_arg)))
    result_path = normpath(abspath(String(result_out_arg)))
    length(unique((artifact_path, t1_receipt_path, plan_path, plan_result_path,
            bundle_path, heat_lift_path, result_path))) == 7 ||
        throw(ArgumentError("current-native numeric inputs and outputs must have distinct paths"))
    all(isfile, (artifact_path, t1_receipt_path, plan_path, plan_result_path)) ||
        throw(ArgumentError("current-native numeric T1/plan input is missing"))
    ispath(bundle_path) && throw(ArgumentError("preserve existing native Gridap bundle"))
    ispath(heat_lift_path) && throw(ArgumentError("preserve existing scalar heat-lift receipt"))
    ispath(result_path) && throw(ArgumentError("preserve existing native numeric receipt"))

    _native_stage("current_native_numeric_t1_read_begin")
    artifact_raw = read(artifact_path)
    t1_receipt_raw = read(t1_receipt_path)
    t1_receipt = JSON3.read(String(copy(t1_receipt_raw)))
    String(t1_receipt.schema) == "vnext-current-source-t0-t1-handoff-v1" ||
        error("current-native numeric T1 handoff receipt schema mismatch")
    normpath(abspath(String(t1_receipt.artifact_path))) == artifact_path &&
        Int(t1_receipt.artifact_bytes) == length(artifact_raw) &&
        bytes2hex(SHA.sha256(artifact_raw)) == String(t1_receipt.artifact_sha256) ||
        error("current-native numeric T1 artifact differs from its receipt bytes/SHA")
    String(t1_receipt.source_root) == root &&
        String(t1_receipt.candidate_directory) == candidate_directory &&
        String(t1_receipt.t0_status) == "valid" &&
        String(t1_receipt.t0_resolution) == "local_contract_ready" ||
        error("current-native numeric T1 receipt names different current inputs")

    G = Base.require(@__MODULE__, :FusionConceptAI)
    Base.invokelatest(G.load_genome_v5_components!)
    Base.invokelatest(G.load_vnext_t2_components_v2!)
    Base.invokelatest(G.load_genome_v5_up2_components!)
    admission = Serialization.deserialize(IOBuffer(artifact_raw))
    admission isa G.VNextT1AdmissionResultV2 &&
        admission.status === :prepared_not_executed &&
        admission.resolution === :terminal_deferred && !admission.accepted &&
        admission.claim_ceiling === :contract_only &&
        admission.package isa G.CandidateStatePackageV5NextV2 &&
        String(admission.status) == String(t1_receipt.t1_status) &&
        String(admission.resolution) == String(t1_receipt.t1_resolution) &&
        admission.accepted == t1_receipt.t1_accepted &&
        String(admission.claim_ceiling) == String(t1_receipt.t1_claim_ceiling) ||
        error("current-native numeric input is not the receipted deferred V2 T1 package")
    package = admission.package
    Base.invokelatest(G.vnext_t1_package_v2_validate, package) === nothing ||
        error("current-native numeric T1 package failed its public validator")
    package.candidate_ref.id == String(t1_receipt.candidate_ref_id) &&
        package.candidate_ref.version == String(t1_receipt.candidate_ref_version) &&
        package.package_hash.value == String(t1_receipt.t1_package_hash) &&
        package.semantic_identity.value == String(t1_receipt.t1_package_semantic_identity) &&
        package.bundle_hash.value == String(t1_receipt.t0_bundle_hash) &&
        package.g3_authority.commitment_hash.value == String(t1_receipt.g3_commitment_hash) ||
        error("current-native numeric T1 package differs from handoff metadata")
    adapter = Base.invokelatest(G.vnext_t1_package_binding_adapter_v2, package)
    adapter.status === :prepared_not_executed &&
        adapter.resolution === :terminal_deferred &&
        adapter.reason === :mapped_prepared_not_executed &&
        adapter.input !== nothing && adapter.package_hash == package.package_hash &&
        adapter.semantic_identity == package.semantic_identity ||
        error("current-native numeric T1 package-binding adapter rejected the package")
    _native_stage("current_native_numeric_t1_read_complete")

    _native_stage("current_native_numeric_source_rebuild_begin")
    built = Base.invokelatest(G._vnext_current_source_candidate_records_v1,
        root, candidate_directory)
    manifest_entry = Base.invokelatest(built.read_current, "manifest.json")
    bytes2hex(SHA.sha256(manifest_entry.bytes)) == manifest_entry.sha256 ||
        error("current candidate manifest bytes differ from source digest")
    records = Base.invokelatest(G._vnext_current_source_records_v1, built)
    current_t0 = Base.invokelatest(G.vnext_declaration_transport_local_v1,
        records.candidate, records.declarations, records.children, records.feedback;
        frozen_context=root)
    current_t0.status === :valid && current_t0.transport !== nothing &&
        current_t0.transport.bundle_hash == package.bundle_hash ||
        error("current G1/G2/G3 source transport differs from the actual T1 package")
    built.candidate_ref == package.candidate_ref ||
        error("current candidate ref differs from the actual T1 package")
    expression_record = built.expression
    candidate_prefix = "fusionconceptai://candidate-design/"
    startswith(package.candidate_ref.id, candidate_prefix) &&
        expression_record.candidate_id ==
            package.candidate_ref.id[length(candidate_prefix)+1:end] &&
        expression_record.candidate_id == built.identity.candidate_id &&
        expression_record.scenario_id == built.identity.scenario_id &&
        built.g1.candidate_ref == package.candidate_ref &&
        built.g2.candidate_ref == package.candidate_ref &&
        built.g1.scenario_id == expression_record.scenario_id &&
        built.g2.scenario_id == expression_record.scenario_id ||
        error("current source expression/G1/G2 identity differs from T1")
    expression_entry = built.entries.native_mms_source_expressions_json
    bytes2hex(SHA.sha256(expression_entry.bytes)) == expression_entry.sha256 ||
        error("current source expression bytes differ from their source digest")

    isdefined(Main, :FusionRuntimeV4) &&
        error("current-native numeric reload process unexpectedly preloaded FusionRuntimeV4")
    runtime_dir = joinpath(root, "src", "RuntimeV4")
    _native_stage("current_native_numeric_runtime_include_begin")
    Base.include(Main, joinpath(runtime_dir, "FusionRuntimeV4.jl"))
    R = Main.FusionRuntimeV4
    Base.include(R, joinpath(runtime_dir, "NativeG1G2DiffusionCompilerV1.jl"))
    qualification_dir = joinpath(root, "tools", "qualification", "gridap")
    project_path = joinpath(qualification_dir, "Project.toml")
    manifest_path = joinpath(qualification_dir, "Manifest.toml")
    project_sha = bytes2hex(SHA.sha256(read(project_path)))
    manifest_sha = bytes2hex(SHA.sha256(read(manifest_path)))
    _native_stage("current_native_numeric_gridap_activation_begin")
    Base.invokelatest(Pkg.activate, qualification_dir; io=devnull)
    normpath(Base.active_project()) == normpath(project_path) ||
        error("current-native numeric Gridap qualification project was not activated")
    Base.include(R, joinpath(runtime_dir, "GridapFieldResidualAdapter.jl"))
    Base.include(R, joinpath(runtime_dir, "GridapNativeG1G2DiffusionAdapterV1.jl"))
    _native_stage("current_native_numeric_gridap_activation_complete")
    bytes2hex(SHA.sha256(read(project_path))) == project_sha &&
        bytes2hex(SHA.sha256(read(manifest_path))) == manifest_sha ||
        error("current Gridap qualification lock changed during activation")

    plan_raw = read(plan_path)
    plan_result_raw = read(plan_result_path)
    plan_result = JSON3.read(String(copy(plan_result_raw)))
    String(plan_result.schema) == "up1-native-current-source-gridap-plan-v1" &&
        String(plan_result.plan_validation_state) == "validated_plan" &&
        String(plan_result.numerical_execution) == "not_executed" &&
        plan_result.accepted === false && String(plan_result.claim_ceiling) == "contract_only" ||
        error("current-native numeric plan result exceeds or misses the plan-only state")
    Int(plan_result.artifact_bytes) == length(plan_raw) &&
        bytes2hex(SHA.sha256(plan_raw)) == String(plan_result.artifact_sha256) ||
        error("current-native numeric plan artifact differs from its result bytes/SHA")
    plan = Base.invokelatest(Serialization.deserialize, IOBuffer(plan_raw))
    plan isa R.NativeG1G2GridapPlanV1 ||
        error("current-native numeric plan has the wrong type")
    Base.invokelatest(R.validate_native_g1g2_gridap_plan_v1, plan) ||
        error("current-native numeric plan failed its public validator")
    token = Base.invokelatest(R.native_g1g2_gridap_plan_admission_v1, plan)
    token isa R.NativeG1G2GridapPlanAdmissionV1 &&
        Base.invokelatest(R.validate_native_g1g2_gridap_plan_admission_v1,
            plan, token) ||
        error("current-native numeric plan lacks valid current-process admission")
    Base.invokelatest(R.validate_native_g1g2_diffusion_compilation_v1,
        plan.compilation) || error("current-native numeric compilation failed public validation")
    form = plan.compilation.form
    form.t1_package_hash == package.package_hash &&
        form.t1_semantic_identity == package.semantic_identity &&
        form.t0_bundle_hash == package.bundle_hash &&
        form.candidate_ref == package.candidate_ref &&
        Base.invokelatest(G.canonical_json, form.g1_declaration) ==
            Base.invokelatest(G.canonical_json, built.g1.declaration) &&
        Base.invokelatest(G.canonical_json, form.g2_declaration) ==
            Base.invokelatest(G.canonical_json, built.g2.declaration) ||
        error("current-native plan is not bound to the rebuilt current T1/G1/G2 sources")
    source_errors = Base.invokelatest(R.native_g1g2_t1_binding_errors_v1,
        admission, built.g1.declaration, built.g2.declaration)
    isempty(source_errors) || error("current-native source/T1 binding failed: " * repr(source_errors))
    profile = Base.invokelatest(R.native_g1g2_unit_compatibility_profile_v1;
        source_basis=String(expression_record.profile_source_basis),
        target_basis=String(expression_record.profile_target_basis),
        source_length_axis=Int(expression_record.profile_source_length_axis),
        target_length_axis=Int(expression_record.profile_target_length_axis),
        length_scale_metres=_native_rational(
            expression_record.length_scale_metres, "current-source length scale"))
    programs = Base.invokelatest(R.native_g1g2_program_bundle_v1, profile;
        physical_lower=_native_rational3(expression_record.physical_lower_metres,
            "current-source physical lower"),
        physical_upper=_native_rational3(expression_record.physical_upper_metres,
            "current-source physical upper"),
        k_base=_native_rational3(expression_record.k_base, "current-source K base"),
        k_slope=_native_rational3(expression_record.k_slope, "current-source K slope"))
    form.programs.unknown_source_expression == programs.unknown_source_expression &&
        form.programs.source_expression == programs.source_expression &&
        form.programs.registry_hash.value == String(expression_record.registry_hash) &&
        form.programs.bundle_hash.value == String(expression_record.bundle_hash) &&
        bytes2hex(SHA.sha256(codeunits(Base.invokelatest(G.canonical_json, programs)))) ==
            String(expression_record.bundle_canonical_sha256) &&
        bytes2hex(SHA.sha256(codeunits(programs.unknown_source_expression))) ==
            String(expression_record.unknown_source_expression_sha256) &&
        bytes2hex(SHA.sha256(codeunits(programs.source_expression))) ==
            String(expression_record.source_expression_sha256) &&
        form.unit_profile.profile_hash == profile.profile_hash &&
        plan.compilation.scenario.scenario_id == String(expression_record.scenario_id) ||
        error("current-native plan programs/scenario differ from current candidate source")
    String(plan_result.candidate_ref_id) == package.candidate_ref.id &&
        String(plan_result.plan_hash) == plan.plan_hash.value &&
        String(plan_result.package_hash) == package.package_hash.value &&
        String(plan_result.semantic_identity) == package.semantic_identity.value &&
        String(plan_result.bundle_hash) == package.bundle_hash.value ||
        error("current-native plan result metadata differs from the actual candidate")
    plan.dependency_identity.project_sha256.value == project_sha &&
        plan.dependency_identity.manifest_sha256.value == manifest_sha &&
        plan.adapter_source_hash.value ==
            Base.invokelatest(R.native_g1g2_gridap_adapter_source_hash_v1).value ||
        error("current-native plan differs from current Gridap lock/adapter source")
    protocol = Base.invokelatest(R.native_g1g2_numerical_protocol_v1,
        form.g2_declaration.source.mesh.cells)
    Base.invokelatest(G.canonical_json, protocol) ==
        Base.invokelatest(G.canonical_json, plan.protocol) ||
        error("current-native plan protocol differs from the source-derived Gridap protocol")
    three_level = plan_result.three_level_protocol
    Tuple(Tuple(Int(x) for x in row) for row in three_level.cell_counts) == plan.protocol.cell_counts &&
        Int(three_level.quadrature_degree) == plan.protocol.quadrature_degree &&
        String(three_level.protocol_hash) == plan.protocol.protocol_hash.value ||
        error("current-native plan result protocol differs from validated plan")
    _native_stage("current_native_numeric_plan_validation_complete")

    # Build the source binding from current manifest-backed inputs and the actual T1 package.
    pin(entry) = (bytes=entry.byte_count,
        sha256=Base.invokelatest(G.Digest256, entry.sha256))
    source_file_pin(path) = begin
        raw = read(joinpath(root, split(String(path), '/')...))
        (bytes=length(raw),
            sha256=Base.invokelatest(G.Digest256, bytes2hex(SHA.sha256(raw))))
    end
    source_pins = (
        g1_builder=pin(built.entries.g1_source_jl),
        g1_declaration_source=source_file_pin("src/GenomeV5/G1/DiffusionDeclarationV1.jl"),
        g2_builder=pin(built.entries.g2_source_jl),
        g2_declaration_source=source_file_pin("src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        g3_builder=pin(built.entries.g3_source_jl),
        g3_child_design=pin(built.entries.g3_child_design_source_jl))
    snapshot_id = "current-native-numeric:" * plan.plan_hash.value
    manifest_sha256 = Base.invokelatest(G.Digest256, manifest_entry.sha256)
    projection = Base.invokelatest(G.n03_vnext_t1_local_event_projection, package;
        candidate_ref=package.candidate_ref,
        candidate_id=String(expression_record.candidate_id),
        scenario_id=String(expression_record.scenario_id),
        snapshot_id=snapshot_id,
        manifest_sha256=manifest_sha256,
        package_hash=package.package_hash,
        semantic_identity=package.semantic_identity,
        bundle_hash=package.bundle_hash,
        source_pins=source_pins)
    projection.status === :local_source_bound &&
        projection.resolution === :terminal_deferred &&
        projection.reason === :candidate_design_event_time_policy_consumed &&
        projection.time_basis === :event &&
        projection.authority_scope === :local_source_data &&
        projection.authority_gap == "candidate_authored_event_time_policy_is_design_only" &&
        projection.candidate_ref == package.candidate_ref &&
        projection.candidate_id == String(expression_record.candidate_id) &&
        projection.scenario_id == String(expression_record.scenario_id) &&
        projection.snapshot_id == snapshot_id &&
        projection.manifest_sha256 == manifest_sha256 &&
        projection.package_hash == package.package_hash &&
        projection.semantic_identity == package.semantic_identity &&
        projection.bundle_hash == package.bundle_hash ||
        error("current-native numeric N03 projection is not locally source-bound to the actual T1 package")
    projection.event_id isa AbstractString && !isempty(projection.event_id) &&
        projection.trigger isa Symbol && projection.time isa Rational{Int64} ||
        error("current-native numeric N03 event identity/time values are invalid")
    Tuple(pin.role for pin in projection.source_pins) ==
        (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source, :g3_builder, :g3_child_design) ||
        error("current-native numeric N03 projection does not contain the six expected source pins")
    pins = Tuple(Base.invokelatest(G.UP2VNextSourcePinV1,
        pin.role, pin.byte_count, pin.sha256) for pin in projection.source_pins)
    binding = Base.invokelatest(G.UP2VNextSourceBindingV1,
        projection.candidate_ref, projection.candidate_id,
        projection.scenario_id, projection.snapshot_id,
        projection.manifest_sha256, projection.package_hash,
        projection.semantic_identity, projection.bundle_hash,
        projection.projection_hash, pins, projection.event_id,
        projection.trigger, projection.time, projection.time_basis,
        projection.status, projection.resolution, projection.authority_scope,
        projection.authority_gap)
    identity_receipt_keys = (:identity_package_path, :identity_package_bytes,
        :identity_package_sha256, :identity_package_hash, :identity_after,
        :identity_package_status)
    identity_receipt_present = any(key -> hasproperty(t1_receipt, key),
        identity_receipt_keys)
    identity_package = nothing
    if identity_receipt_present
        all(key -> hasproperty(t1_receipt, key), identity_receipt_keys) ||
            error("current-native numeric T1 identity receipt is incomplete")
        String(t1_receipt.identity_package_status) == "valid" ||
            error("current-native numeric T1 identity package is not marked valid")
        identity_path = normpath(abspath(String(t1_receipt.identity_package_path)))
        expected_identity_path = normpath(joinpath(dirname(artifact_path),
            "identity_package.bin"))
        identity_path == expected_identity_path && isfile(identity_path) ||
            error("current-native numeric identity path differs from its adjacent T1 handoff")
        identity_raw = read(identity_path)
        length(identity_raw) == Int(t1_receipt.identity_package_bytes) &&
            bytes2hex(SHA.sha256(identity_raw)) ==
                String(t1_receipt.identity_package_sha256) ||
            error("current-native numeric identity bytes differ from the T1 handoff receipt")
        identity_package = Base.invokelatest(Serialization.deserialize, IOBuffer(identity_raw))
        identity_package isa G.CandidateStatePackageV5 &&
            identity_package.candidate_ref == package.candidate_ref &&
            identity_package.candidate_hash.value ==
                String(t1_receipt.identity_package_hash) &&
            identity_package.migration_receipt.candidate_identity_after ==
                String(t1_receipt.identity_after) ||
            error("current-native numeric identity package differs from receipted T1 identity")
        identity_projection = Base.invokelatest(G.n10_identity_projection_from_a,
            identity_package)
        identity_projection.candidate_ref == package.candidate_ref &&
            identity_projection.package_hash == identity_package.candidate_hash &&
            identity_projection.migration_receipt == identity_package.migration_receipt ||
            error("current-native numeric identity package failed public V5 identity validation")
    end
    _native_stage("current_native_numeric_g3_ledger_begin")
    ledger_context = if identity_package === nothing
        Base.invokelatest(G._up2_vnext_n04_05_context,
            package, binding; event_projection=projection, include_child_design=true)
    else
        Base.invokelatest(G._up2_vnext_n04_05_context,
            package, binding; event_projection=projection,
            include_child_design=true, identity_package=identity_package)
    end
    typed_ledger_context = ledger_context.typed_ledger_context
    typed_ledger_context isa NamedTuple &&
        hasproperty(typed_ledger_context, :authored_heat_lift) ||
        error("current-native numeric source lacks its validated authored scalar heat-lift ledger context")
    _native_stage("current_native_numeric_g3_ledger_complete")
    Base.invokelatest(R._ng12_validated_scalar_heat_lift_source_v1,
        plan, typed_ledger_context)
    handoff_state = (R=R, admission=admission,
        compilation=(compilation=plan.compilation, result_hash=plan.compile_result_hash))
    execution = _native_gridap_execute_a_v1(handoff_state, plan; verify_attempt_cache=true)
    bundle, handoff = execution.bundle, execution.handoff
    raw_bundle = Base.invokelatest(_native_serialized_bytes, bundle)
    report = bundle.report

    _native_stage("current_native_numeric_scalar_heat_lift_begin")
    heat_lift_receipt = Base.invokelatest(
        R.native_g1g2_gridap_scalar_heat_lift_service_v1,
        plan, report, typed_ledger_context)
    heat_lift_receipt isa R.NativeG1G2ScalarHeatLiftServiceReceiptV1 &&
        Base.invokelatest(R.validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1,
            plan, report, typed_ledger_context, heat_lift_receipt) === true ||
        error("current-native numeric scalar heat-lift receipt failed exact public validation")
    raw_heat_lift = Base.invokelatest(_native_serialized_bytes, heat_lift_receipt)
    _native_stage("current_native_numeric_scalar_heat_lift_complete")
    _native_write_new(bundle_path, raw_bundle)
    _native_write_new(heat_lift_path, raw_heat_lift)
    receipt = (schema="up1-native-current-source-gridap-numeric-v1",
        phase="current_native_numeric", lineage_mode="current_worktree_current_T1_and_plan",
        source_root=root, candidate_directory=candidate_directory,
        candidate_ref_id=package.candidate_ref.id,
        t1_artifact_path=artifact_path, t1_artifact_bytes=length(artifact_raw),
        t1_artifact_sha256=bytes2hex(SHA.sha256(artifact_raw)),
        t1_package_hash=package.package_hash.value,
        t1_semantic_identity=package.semantic_identity.value,
        t0_bundle_hash=package.bundle_hash.value,
        g3_commitment_hash=package.g3_authority.commitment_hash.value,
        plan_path=plan_path, plan_bytes=length(plan_raw),
        plan_artifact_sha256=bytes2hex(SHA.sha256(plan_raw)),
        plan_hash=plan.plan_hash.value, solver_input_hash=plan.solver_input.solver_input_hash.value,
        plan_admitted=true, gridap_adapter_source_sha256=plan.adapter_source_hash.value,
        qualification_project_sha256=project_sha, qualification_manifest_sha256=manifest_sha,
        bundle_path=bundle_path, bundle_bytes=length(raw_bundle),
        bundle_artifact_sha256=bytes2hex(SHA.sha256(raw_bundle)),
        bundle_hash=bundle.bundle_hash.value, report_hash=report.report_hash.value,
        heat_lift_receipt_path=heat_lift_path,
        heat_lift_receipt_bytes=length(raw_heat_lift),
        heat_lift_receipt_artifact_sha256=bytes2hex(SHA.sha256(raw_heat_lift)),
        heat_lift_receipt_hash=Base.invokelatest(G.canonical_hash, heat_lift_receipt).value,
        heat_lift_source_pin_sha256=typed_ledger_context.source_pin_sha256.value,
        heat_lift_result_hash=Base.invokelatest(G.canonical_hash, heat_lift_receipt.result).value,
        heat_lift_provider_evidence_level=Base.invokelatest(string, heat_lift_receipt.provider.capability.evidence_level),
        t1_runtime_status=String(handoff.status), t1_runtime_result_hash=handoff.result_hash.value,
        t1_runtime_package_hash=handoff.package_hash.value,
        t1_runtime_semantic_identity=handoff.semantic_identity.value,
        t1_runtime_wire_hash=handoff.wire_hash.value,
        t1_runtime_t0_bundle_hash=handoff.t0_bundle_hash.value,
        t1_runtime_scenario_hash=handoff.scenario_hash.value,
        numerical_status=String(report.status), numerical_resolution=String(report.resolution),
        numerical_accepted=report.accepted,
        claim_ceiling=Base.invokelatest(string, report.claim_ceiling),
        physical_status=String(report.physical_status), formal_t2_consumer_receipts=0,
        g3_material_conversion="not_executed",
        attempt_cache_observation=execution.attempt_cache)
    _native_write_new(result_path, Vector{UInt8}(codeunits(JSON3.write(receipt))))
    report.status === :pass || error("current-native Gridap numerical_fail: " * repr(report.errors))
    println("UP1_NATIVE_CURRENT_GRIDAP_NUMERIC_PASS\t", plan.plan_hash.value,
        "\t", bundle.bundle_hash.value, "\tG3Material=not_executed\tPhysicsCredit=none")
    nothing
end

function main()
    isempty(ARGS) && error("phase_a, phase_b, gridap_prepare, gridap_a, gridap_b, gridap_negative, current_source, current_native, or current_native_numeric is required")
    phase = Symbol(ARGS[1])
    phase === :current_source && return _native_current_source_handoff(ARGS[2:end])
    phase === :current_native && return _native_current_native_handoff(ARGS[2:end])
    phase === :current_native_numeric && return _native_current_native_numeric_handoff(ARGS[2:end])
    phase_a_receipt_expected_sha = nothing
    gridap_artifact_out = nothing
    gridap_plan_out = nothing
    gridap_prepare_receipt_path = nothing
    gridap_prepare_receipt_expected_sha = nothing
    gridap_a_receipt_path = nothing
    gridap_a_receipt_expected_sha = nothing
    if phase === :phase_a
        length(ARGS) == 5 || error(
            "usage: run_up1_native_handoff.jl phase_a <serialized-admission> " *
            "<expected-admission-sha256> <compile-artifact-out> <phase-a-receipt-out>")
    artifact_path, expected_sha, phase_input, receipt_out = ARGS[2:5]
    elseif phase === :phase_b
        length(ARGS) == 6 || error(
            "usage: run_up1_native_handoff.jl phase_b <serialized-admission> " *
            "<expected-admission-sha256> <phase-a-receipt> " *
            "<expected-phase-a-receipt-sha256> <final-receipt-out>")
        artifact_path, expected_sha, phase_input, phase_a_receipt_expected_sha,
            receipt_out = ARGS[2:6]
        phase_a_receipt_expected_sha = lowercase(phase_a_receipt_expected_sha)
        occursin(r"^[0-9a-f]{64}$", phase_a_receipt_expected_sha) ||
            throw(ArgumentError("expected phase-A receipt SHA-256 must be 64 lowercase hex digits"))
    elseif phase === :gridap_prepare
        length(ARGS) == 7 || error(
            "usage: run_up1_native_handoff.jl gridap_prepare <serialized-admission> " *
            "<expected-admission-sha256> <phase-a-receipt> " *
            "<expected-phase-a-receipt-sha256> <gridap-plan-out> <prepare-receipt-out>")
        artifact_path, expected_sha, phase_input, phase_a_receipt_expected_sha,
            gridap_plan_out, receipt_out = ARGS[2:7]
    elseif phase === :gridap_a
        length(ARGS) == 9 || error(
            "usage: run_up1_native_handoff.jl gridap_a <serialized-admission> " *
            "<expected-admission-sha256> <phase-a-receipt> " *
            "<expected-phase-a-receipt-sha256> <gridap-prepare-receipt> " *
            "<expected-gridap-prepare-receipt-sha256> <gridap-bundle-out> " *
            "<gridap-a-receipt-out>")
        artifact_path, expected_sha, phase_input, phase_a_receipt_expected_sha,
            gridap_prepare_receipt_path, gridap_prepare_receipt_expected_sha,
            gridap_artifact_out, receipt_out = ARGS[2:9]
    elseif phase === :gridap_b
        length(ARGS) == 10 || error(
            "usage: run_up1_native_handoff.jl gridap_b <serialized-admission> " *
            "<expected-admission-sha256> <phase-a-receipt> " *
            "<expected-phase-a-receipt-sha256> <gridap-prepare-receipt> " *
            "<expected-gridap-prepare-receipt-sha256> <gridap-a-receipt> " *
            "<expected-gridap-a-receipt-sha256> <gridap-b-receipt-out>")
        artifact_path, expected_sha, phase_input, phase_a_receipt_expected_sha,
            gridap_prepare_receipt_path, gridap_prepare_receipt_expected_sha,
            gridap_a_receipt_path, gridap_a_receipt_expected_sha,
            receipt_out = ARGS[2:10]
    elseif phase === :gridap_negative
        length(ARGS) == 8 || error(
            "usage: run_up1_native_handoff.jl gridap_negative <serialized-admission> " *
            "<expected-admission-sha256> <phase-a-receipt> " *
            "<expected-phase-a-receipt-sha256> <gridap-prepare-receipt> " *
            "<expected-gridap-prepare-receipt-sha256> <negative-receipt-out>")
        artifact_path, expected_sha, phase_input, phase_a_receipt_expected_sha,
            gridap_prepare_receipt_path, gridap_prepare_receipt_expected_sha,
            receipt_out = ARGS[2:8]
    else
        error("phase must be phase_a, phase_b, gridap_prepare, gridap_a, gridap_b, gridap_negative, or current_source")
    end
    if phase in (:gridap_prepare, :gridap_a, :gridap_b, :gridap_negative)
        phase_a_receipt_expected_sha = lowercase(phase_a_receipt_expected_sha)
        occursin(r"^[0-9a-f]{64}$", phase_a_receipt_expected_sha) ||
            throw(ArgumentError("expected phase-A receipt SHA-256 must be 64 lowercase hex digits"))
    end
    if phase in (:gridap_a, :gridap_b, :gridap_negative)
        gridap_prepare_receipt_expected_sha = lowercase(gridap_prepare_receipt_expected_sha)
        occursin(r"^[0-9a-f]{64}$", gridap_prepare_receipt_expected_sha) ||
            throw(ArgumentError("expected Gridap prepare receipt SHA-256 must be 64 lowercase hex digits"))
    end
    if phase === :gridap_b
        gridap_a_receipt_expected_sha = lowercase(gridap_a_receipt_expected_sha)
        occursin(r"^[0-9a-f]{64}$", gridap_a_receipt_expected_sha) ||
            throw(ArgumentError("expected Gridap-A receipt SHA-256 must be 64 lowercase hex digits"))
    end
    expected_sha = lowercase(expected_sha)
    occursin(r"^[0-9a-f]{64}$", expected_sha) ||
        throw(ArgumentError("expected admission SHA-256 must be 64 lowercase hex digits"))
    t1_artifact_abs = normpath(abspath(artifact_path))
    t1_sidecar_abs = normpath(abspath(artifact_path * ".json"))
    phase_input_abs = normpath(abspath(phase_input))
    receipt_out_abs = normpath(abspath(receipt_out))
    receipt_out_abs != t1_artifact_abs && receipt_out_abs != t1_sidecar_abs &&
        receipt_out_abs != phase_input_abs ||
        throw(ArgumentError("receipt output path collides with an input or phase artifact"))
    if phase === :phase_a
        phase_input_abs != t1_artifact_abs && phase_input_abs != t1_sidecar_abs ||
            throw(ArgumentError("compile artifact output path collides with T1 input"))
        ispath(phase_input_abs) &&
            throw(ArgumentError("refusing to overwrite phase-A compilation artifact"))
    end
    ispath(receipt_out_abs) &&
        throw(ArgumentError("refusing to overwrite handoff receipt"))
    if phase === :gridap_prepare
        gridap_plan_out = normpath(abspath(gridap_plan_out))
        gridap_plan_out != receipt_out_abs &&
            gridap_plan_out != t1_artifact_abs &&
            gridap_plan_out != t1_sidecar_abs &&
            gridap_plan_out != phase_input_abs ||
            throw(ArgumentError("Gridap plan output collides with an input or receipt"))
        ispath(gridap_plan_out) &&
            throw(ArgumentError("preserve existing Gridap plan artifact"))
    elseif phase === :gridap_a
        gridap_artifact_out = normpath(abspath(gridap_artifact_out))
        gridap_artifact_out != receipt_out_abs &&
            gridap_artifact_out != t1_artifact_abs &&
            gridap_artifact_out != t1_sidecar_abs &&
            gridap_artifact_out != phase_input_abs ||
            throw(ArgumentError("Gridap bundle output collides with an input or receipt"))
        ispath(gridap_artifact_out) &&
            throw(ArgumentError("preserve existing Gridap bundle artifact"))
    elseif phase === :gridap_b
        gridap_a_receipt_path = normpath(abspath(gridap_a_receipt_path))
        receipt_out_abs != gridap_a_receipt_path &&
            gridap_a_receipt_path != phase_input_abs &&
            gridap_a_receipt_path != t1_artifact_abs ||
            throw(ArgumentError("Gridap-A receipt collides with other inputs or output"))
    end
    if phase in (:gridap_a, :gridap_b, :gridap_negative)
        gridap_prepare_receipt_path = normpath(abspath(gridap_prepare_receipt_path))
        receipt_out_abs != gridap_prepare_receipt_path &&
            gridap_prepare_receipt_path != phase_input_abs &&
            gridap_prepare_receipt_path != t1_artifact_abs ||
            throw(ArgumentError("Gridap prepare receipt collides with other inputs or output"))
    end

    snapshot_root = get(ENV, "UP1_FROZEN_SNAPSHOT_ROOT", "")
    isempty(snapshot_root) && error("UP1_FROZEN_SNAPSHOT_ROOT is required")
    snapshot_root = normpath(abspath(snapshot_root))
    test_path = joinpath(snapshot_root, "test", "GenomeV5", "Integration",
        "up1_frozen_source_t0_v1_tests.jl")
    runner_path = joinpath(snapshot_root, "scripts", "run_up1_native_handoff.jl")
    isfile(test_path) && isfile(runner_path) ||
        error("frozen UP1 test or native handoff runner is missing from snapshot")

    ENV["UP1_FROZEN_SOURCE_MODE"] = "up4_r2_native_reload"
    _native_stage("test_include_begin")
    Base.include(Main, test_path)
    _native_stage("test_include_complete")
    G = Main.G
    N = Main.N
    _native_stage("snapshot_open_begin")
    context = Base.invokelatest(Main._up4_r2_open_snapshot)
    _native_stage("snapshot_open_complete")
    context.source_root == snapshot_root || error("freeze context root differs from requested snapshot")
    _native_stage("runtime_guard_activation_begin")
    Base.invokelatest(N.activate_up1_frozen_runtime!, context) === true ||
        error("UP1 frozen runtime activation failed")
    _native_stage("runtime_guard_activation_complete")
    candidate_dir = "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/"
    identity_entry = _native_frozen_source(N, context, candidate_dir * "identity.jl")
    _native_stage("identity_include_begin")
    Base.include_string(G, String(copy(identity_entry.bytes)), identity_entry.logical_path)
    _native_stage("identity_include_complete")

    runner_entry = _native_frozen_source(N, context, "scripts/run_up1_native_handoff.jl")
    runner_sha = bytes2hex(SHA.sha256(read(runner_path)))
    runner_sha == runner_entry.sha256 || error("native runner differs from frozen snapshot entry")
    test_entry = _native_frozen_source(N, context,
        "test/GenomeV5/Integration/up1_frozen_source_t0_v1_tests.jl")
    bytes2hex(SHA.sha256(read(test_path))) == test_entry.sha256 ||
        error("loaded UP1 consumer test differs from frozen snapshot entry")

    sidecar_path = artifact_path * ".json"
    sidecar_raw = read(sidecar_path)
    sidecar = JSON3.read(String(copy(sidecar_raw)))
    sidecar.schema == "up1-native-t1-admission-artifact-sidecar-v1" ||
        error("native T1 artifact sidecar schema mismatch")
    String(sidecar.artifact_path) == normpath(abspath(artifact_path)) ||
        error("native T1 sidecar names a different admission artifact path")
    String(sidecar.freeze_receipt_path) == normpath(abspath(
        get(ENV, "UP1_FROZEN_RECEIPT_PATH", ""))) ||
        error("native T1 sidecar names a different freeze receipt")
    String(sidecar.freeze_receipt_sha256) == lowercase(
        get(ENV, "UP1_FROZEN_RECEIPT_SHA256", "")) ||
        error("native T1 sidecar freeze receipt SHA differs from reload context")
    String(sidecar.snapshot_id) == context.snapshot_id &&
        String(sidecar.manifest_sha256) == context.manifest_sha256 ||
        error("native T1 sidecar snapshot/manifest identity mismatch")
    String(sidecar.scenario_id) == G.UP4_R2_IDENTITY.scenario_id &&
        String(sidecar.candidate_ref.id) == G.UP4_R2_IDENTITY.candidate_ref.id &&
        String(sidecar.candidate_ref.version) == G.UP4_R2_IDENTITY.candidate_ref.version ||
        error("native T1 sidecar candidate/scenario identity mismatch")

    t0_raw = read(String(sidecar.t0_receipt_path))
    bytes2hex(SHA.sha256(t0_raw)) == String(sidecar.t0_receipt_sha256) ||
        error("native T1 sidecar T0 receipt bytes/SHA mismatch")
    t0 = JSON3.read(String(copy(t0_raw)))
    String(t0.schema) == "up1-up4-r2-t0-recheck-receipt-v1" &&
        String(t0.snapshot_id) == context.snapshot_id &&
        String(t0.manifest_sha256) == context.manifest_sha256 &&
        String(t0.status) == "valid" &&
        String(t0.resolution) == "local_contract_ready" &&
        String(t0.candidate_ref.id) == G.UP4_R2_IDENTITY.candidate_ref.id &&
        String(t0.candidate_ref.version) == G.UP4_R2_IDENTITY.candidate_ref.version ||
        error("native T1 sidecar T0 lineage does not match current freeze/candidate")

    g3_raw = read(String(sidecar.g3_expected_receipt_path))
    bytes2hex(SHA.sha256(g3_raw)) == String(sidecar.g3_expected_receipt_sha256) ||
        error("native T1 sidecar G3 receipt bytes/SHA mismatch")
    g3 = JSON3.read(String(copy(g3_raw)))
    String(g3.schema) == "up1-up4-r2-g3-expected-commitment-v1" &&
        String(g3.snapshot_id) == context.snapshot_id &&
        String(g3.manifest_sha256) == context.manifest_sha256 &&
        String(g3.t0_receipt_sha256) == String(sidecar.t0_receipt_sha256) &&
        String(g3.bundle_hash) == String(t0.bundle_hash) &&
        String(g3.g3_declaration_ref.id) == String(t0.g3_declaration_ref.id) &&
        String(g3.g3_declaration_ref.version) == String(t0.g3_declaration_ref.version) &&
        String(g3.g3_declaration_identity_hash) ==
            String(t0.g3_declaration_identity_hash) &&
        String(g3.source_pins.freeze_receipt_sha256) ==
            String(sidecar.freeze_receipt_sha256) &&
        String(g3.candidate_ref.id) == G.UP4_R2_IDENTITY.candidate_ref.id &&
        String(g3.candidate_ref.version) == G.UP4_R2_IDENTITY.candidate_ref.version &&
        String(g3.scope.design_scope) == "candidate_design_only" &&
        g3.scope.physical_validation === false &&
        g3.scope.engineering_validation === false &&
        g3.scope.measurement_authority === false ||
        error("native T1 sidecar G3 lineage/scope does not match current freeze/candidate")
    occursin(r"^[0-9a-f]{64}$", String(g3.commitment_hash)) ||
        error("native T1 sidecar G3 commitment digest is malformed")
    g3_source_members = (
        (:g3_child_design_source_path, :g3_child_design_source_sha256,
            candidate_dir * "g3_child_design_source.jl"),
        (:g3_builder_source_path, :g3_builder_source_sha256,
            candidate_dir * "g3_source.jl"),
        (:realization_schema_source_path, :realization_schema_source_sha256,
            "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl"),
        (:control_schema_source_path, :control_schema_source_sha256,
            "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl"),
        (:producer_source_path, :producer_source_sha256,
            "scripts/up1_g3_expected_commitment_producer_v1.jl"))
    for (path_field, sha_field, logical_path) in g3_source_members
        source_entry = _native_frozen_source(N, context, logical_path)
        String(getproperty(g3.source_pins, path_field)) == logical_path &&
            String(getproperty(g3.source_pins, sha_field)) == source_entry.sha256 ||
            error("native G3 source member does not match frozen manifest: " * logical_path)
    end

    artifact = read(artifact_path)
    artifact_sha = bytes2hex(SHA.sha256(artifact))
    artifact_sha == expected_sha || error("persisted T1 admission artifact SHA-256 mismatch")
    length(artifact) == Int(sidecar.artifact_bytes) &&
        artifact_sha == String(sidecar.artifact_sha256) ||
        error("native T1 sidecar artifact byte count/SHA mismatch")
    admission = Base.invokelatest(Serialization.deserialize, IOBuffer(artifact))
    admission isa G.VNextT1AdmissionResultV2 ||
        error("deserialized artifact is not the actual VNextT1AdmissionResultV2")
    admission.status === :prepared_not_executed || error("unexpected T1 result status")
    admission.resolution === :terminal_deferred || error("unexpected T1 resolution")
    !admission.accepted && admission.claim_ceiling === :contract_only ||
        error("T1 artifact has an unexpected acceptance ceiling")
    admission.package isa G.CandidateStatePackageV5NextV2 ||
        error("persisted T1 result does not contain the full V2 package")
    isempty(admission.errors) && admission.gaps == (:t1_runtime_unresolved,) ||
        error("persisted T1 result differs from the frozen UP1 consumer contract")
    Base.invokelatest(G.vnext_t1_package_v2_validate, admission.package) === nothing ||
        error("deserialized T1 package failed its public validator")
    String(admission.status) == String(sidecar.t1_status) &&
        String(admission.resolution) == String(sidecar.t1_resolution) &&
        admission.accepted === sidecar.t1_accepted &&
        String(admission.claim_ceiling) == String(sidecar.t1_claim_ceiling) &&
        admission.package.package_hash.value == String(sidecar.package_hash) &&
        admission.package.semantic_identity.value == String(sidecar.package_semantic_identity) &&
        admission.package.bundle_hash.value == String(sidecar.package_bundle_hash) &&
        String(sidecar.package_bundle_hash) == String(t0.bundle_hash) &&
        admission.package.g3_authority.commitment_hash.value ==
            String(g3.commitment_hash) ||
        error("deserialized T1 result/package identity differs from producer sidecar")

    _native_stage("native_expression_projection_begin")
    source_projection = Base.invokelatest(Main._up4_r2_native_source_expressions, context)
    _native_stage("native_expression_projection_complete")
    record = source_projection.record
    record.candidate_id == G.UP4_R2_IDENTITY.candidate_id ||
        error("frozen expression record candidate ID differs from candidate identity")
    record.scenario_id == G.UP4_R2_IDENTITY.scenario_id ||
        error("frozen expression record scenario differs from candidate identity")
    record.candidate_ref == G.UP4_R2_IDENTITY.candidate_ref.id ||
        error("frozen expression record candidate ref differs from candidate identity")
    admission.package.candidate_ref == G.UP4_R2_IDENTITY.candidate_ref ||
        error("persisted T1 package belongs to a different candidate")

    g1_entry = _native_frozen_source(N, context, candidate_dir * "g1_source.jl")
    g2_entry = _native_frozen_source(N, context, candidate_dir * "g2_source.jl")
    _native_stage("candidate_g1_g2_include_begin")
    Base.include_string(G, String(copy(g1_entry.bytes)), g1_entry.logical_path)
    Base.include_string(G, String(copy(g2_entry.bytes)), g2_entry.logical_path)
    _native_stage("candidate_g1_g2_include_complete")
    _native_stage("candidate_g1_build_begin")
    g1 = Base.invokelatest(G.up4_r2_build_g1_design, record)
    _native_stage("candidate_g1_build_complete")
    _native_stage("candidate_g2_build_begin")
    g2 = Base.invokelatest(G.up4_r2_build_g2_design, record)
    _native_stage("candidate_g2_build_complete")

    runtime_entry = _native_frozen_source(N, context, "src/RuntimeV4/FusionRuntimeV4.jl")
    compiler_entry = _native_frozen_source(N, context,
        "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl")
    isdefined(Main, :FusionRuntimeV4) &&
        error("native reload process unexpectedly preloaded FusionRuntimeV4")
    _native_stage("runtime_v4_include_begin")
    Base.include(Main, joinpath(snapshot_root, split(runtime_entry.logical_path, '/')...))
    _native_stage("runtime_v4_include_complete")
    R = Main.FusionRuntimeV4
    if !isdefined(G, :VNextT1CandidateBindingInputV2)
        binding_entry = _native_frozen_source(N, context,
            "src/Contracts/VNextT1CandidateBindingV2.jl")
        _native_stage("candidate_binding_include_begin")
        Base.include_string(G, String(copy(binding_entry.bytes)),
            binding_entry.logical_path)
        _native_stage("candidate_binding_include_complete")
    end
    if !isdefined(G, :vnext_t1_package_binding_adapter_v2)
        adapter_entry = _native_frozen_source(N, context,
            "src/Contracts/VNextT1PackageBindingAdapterV2.jl")
        _native_stage("package_adapter_include_begin")
        Base.include_string(G, String(copy(adapter_entry.bytes)),
            adapter_entry.logical_path)
        _native_stage("package_adapter_include_complete")
    end
    _native_stage("package_adapter_call_begin")
    package_adapter = Base.invokelatest(G.vnext_t1_package_binding_adapter_v2,
        admission.package)
    _native_stage("package_adapter_call_complete")
    package_adapter.status === :prepared_not_executed &&
        package_adapter.resolution === :terminal_deferred &&
        package_adapter.reason === :mapped_prepared_not_executed &&
        package_adapter.input !== nothing &&
        package_adapter.package_hash == admission.package.package_hash &&
        package_adapter.semantic_identity == admission.package.semantic_identity ||
        error("public V2 package-binding adapter rejected the deserialized T1 package")
    _native_stage("native_compiler_include_begin")
    Base.include(R, joinpath(snapshot_root, split(compiler_entry.logical_path, '/')...))
    _native_stage("native_compiler_include_complete")

    phase_a_receipt = nothing
    phase_a_receipt_sha = nothing
    compilation = nothing
    if phase === :phase_a
        profile = Base.invokelatest(R.native_g1g2_unit_compatibility_profile_v1;
            source_basis=String(record.profile_source_basis),
            target_basis=String(record.profile_target_basis),
            source_length_axis=Int(record.profile_source_length_axis),
            target_length_axis=Int(record.profile_target_length_axis),
            length_scale_metres=_native_rational(record.length_scale_metres,
                "length scale"))
        profile.profile_hash.value == String(record.profile_hash) ||
            error("rebuilt unit profile hash differs from frozen expression record")
        programs = Base.invokelatest(R.native_g1g2_program_bundle_v1, profile;
            physical_lower=_native_rational3(record.physical_lower_metres, "physical lower"),
            physical_upper=_native_rational3(record.physical_upper_metres, "physical upper"),
            k_base=_native_rational3(record.k_base, "K base"),
            k_slope=_native_rational3(record.k_slope, "K slope"))
        programs.unknown_source_expression == String(record.unknown_source_expression) ||
            error("rebuilt compiler unknown expression differs byte-for-byte from frozen candidate input")
        programs.source_expression == String(record.source_expression) ||
            error("rebuilt compiler manufactured source differs byte-for-byte from frozen candidate input")
        programs.registry_hash.value == String(record.registry_hash) ||
            error("rebuilt compiler registry hash differs from frozen projection record")
        programs.bundle_hash.value == String(record.bundle_hash) ||
            error("rebuilt compiler bundle hash differs from frozen projection record")
        bytes2hex(SHA.sha256(codeunits(Base.invokelatest(G.canonical_json, programs)))) ==
            String(record.bundle_canonical_sha256) ||
            error("rebuilt compiler canonical bundle differs from frozen projection record")
    else
        phase_a_receipt_raw = read(phase_input)
        phase_a_receipt_sha = bytes2hex(SHA.sha256(phase_a_receipt_raw))
        phase_a_receipt_sha == phase_a_receipt_expected_sha ||
            error("phase-A receipt raw-byte SHA differs from explicit reload pin")
        phase_a_receipt = JSON3.read(String(copy(phase_a_receipt_raw)))
        String(phase_a_receipt.schema) == "up1-native-g1g2-compile-artifact-v1" ||
            error("phase-A compile artifact receipt schema mismatch")
        String(phase_a_receipt.snapshot_id) == context.snapshot_id &&
            String(phase_a_receipt.manifest_sha256) == context.manifest_sha256 &&
            normpath(String(phase_a_receipt.freeze_receipt_path)) ==
                normpath(String(sidecar.freeze_receipt_path)) &&
            String(phase_a_receipt.freeze_receipt_sha256) ==
                lowercase(get(ENV, "UP1_FROZEN_RECEIPT_SHA256", "")) ||
            error("phase-A receipt snapshot/freeze lineage mismatch")
        String(phase_a_receipt.candidate_id) == String(record.candidate_id) &&
            String(phase_a_receipt.candidate_ref_id) == G.UP4_R2_IDENTITY.candidate_ref.id &&
            String(phase_a_receipt.candidate_ref_version) ==
                G.UP4_R2_IDENTITY.candidate_ref.version &&
            String(phase_a_receipt.scenario_id) == String(record.scenario_id) ||
            error("phase-A receipt candidate/scenario identity mismatch")
        normpath(String(phase_a_receipt.t0_receipt_path)) ==
                normpath(String(sidecar.t0_receipt_path)) &&
            String(phase_a_receipt.t0_receipt_sha256) == String(sidecar.t0_receipt_sha256) &&
            String(phase_a_receipt.t0_bundle_hash) == String(t0.bundle_hash) &&
            normpath(String(phase_a_receipt.g3_expected_receipt_path)) ==
                normpath(String(sidecar.g3_expected_receipt_path)) &&
            String(phase_a_receipt.g3_expected_receipt_sha256) ==
                String(sidecar.g3_expected_receipt_sha256) &&
            String(phase_a_receipt.g3_commitment_hash) == String(g3.commitment_hash) &&
            normpath(String(phase_a_receipt.admission_artifact_path)) ==
                normpath(abspath(artifact_path)) &&
            Int(phase_a_receipt.admission_artifact_bytes) == length(artifact) &&
            String(phase_a_receipt.admission_artifact_sha256) == artifact_sha &&
            normpath(String(phase_a_receipt.admission_sidecar_path)) ==
                normpath(abspath(sidecar_path)) &&
            String(phase_a_receipt.admission_sidecar_sha256) ==
                bytes2hex(SHA.sha256(sidecar_raw)) ||
            error("phase-A receipt T0/G3/T1 lineage does not match this reload")
        String(phase_a_receipt.package_hash) == admission.package.package_hash.value &&
            String(phase_a_receipt.package_semantic_identity) ==
                admission.package.semantic_identity.value &&
            String(phase_a_receipt.package_bundle_hash) ==
                admission.package.bundle_hash.value &&
            String(phase_a_receipt.expression_record_sha256) ==
                source_projection.entry.sha256 &&
            String(phase_a_receipt.unknown_source_expression_sha256) ==
                String(record.unknown_source_expression_sha256) &&
            String(phase_a_receipt.source_expression_sha256) ==
                String(record.source_expression_sha256) &&
            String(phase_a_receipt.profile_hash) == String(record.profile_hash) &&
            String(phase_a_receipt.registry_hash) == String(record.registry_hash) &&
            String(phase_a_receipt.bundle_hash) == String(record.bundle_hash) &&
            String(phase_a_receipt.bundle_canonical_sha256) ==
                String(record.bundle_canonical_sha256) &&
            String(phase_a_receipt.compiler_source_entry_sha256) ==
                compiler_entry.sha256 &&
            String(phase_a_receipt.compiler_source_hash) == compiler_entry.sha256 ||
            error("phase-A receipt native source/compiler pins do not match this reload")
        compile_artifact_path = normpath(abspath(
            String(phase_a_receipt.compilation_artifact_path)))
        compile_artifact_raw = read(compile_artifact_path)
        compile_artifact_sha = bytes2hex(SHA.sha256(compile_artifact_raw))
        length(compile_artifact_raw) == Int(phase_a_receipt.compilation_artifact_bytes) &&
            compile_artifact_sha == String(phase_a_receipt.compilation_artifact_sha256) ||
            error("phase-A compilation artifact byte count/SHA mismatch")
        _native_stage("compile_artifact_deserialize_begin")
        compilation = Base.invokelatest(Serialization.deserialize,
            IOBuffer(compile_artifact_raw))
        _native_stage("compile_artifact_deserialize_complete")
        compilation isa R.NativeG1G2DiffusionCompileResultV1 ||
            error("phase-A artifact is not the actual native compiler result")
        compilation.compilation isa R.NativeG1G2DiffusionCompilationV1 ||
            error("phase-A compiler result does not carry the full compilation")
        _native_stage("compile_result_hash_validation_begin")
        result_body = Base.invokelatest(R._ng12_compile_result_body,
            compilation.status, compilation.resolution, compilation.accepted,
            compilation.claim_ceiling, compilation.compilation,
            compilation.errors, compilation.gaps)
        Base.invokelatest(G.canonical_hash, result_body) == compilation.result_hash ||
            error("phase-A compiler result canonical hash mismatch")
        _native_stage("compile_result_hash_validation_complete")
        form = compilation.compilation.form
        form.candidate_ref == G.UP4_R2_IDENTITY.candidate_ref &&
            form.t1_package_hash == admission.package.package_hash &&
            form.t1_semantic_identity == admission.package.semantic_identity &&
            form.t0_bundle_hash == admission.package.bundle_hash &&
            form.g1_declaration.declaration_hash == g1.declaration.declaration_hash &&
            form.g2_declaration.declaration_hash == g2.declaration.declaration_hash ||
            error("phase-A compilation is not bound to current candidate/T1/G1/G2 inputs")
        form.programs.unknown_source_expression ==
            String(record.unknown_source_expression) &&
            form.programs.source_expression == String(record.source_expression) &&
            form.unit_profile.profile_hash.value == String(record.profile_hash) &&
            form.programs.registry_hash.value == String(record.registry_hash) &&
            form.programs.bundle_hash.value == String(record.bundle_hash) ||
            error("phase-A compilation does not match current frozen MMS projection")
        String(phase_a_receipt.compiler_result_hash) == compilation.result_hash.value &&
            String(phase_a_receipt.compiler_compilation_hash) ==
                compilation.compilation.compilation_hash.value &&
        String(phase_a_receipt.compiler_source_hash) ==
                compilation.compilation.compiler_source_hash.value &&
            String(phase_a_receipt.compiler_status) == String(compilation.status) &&
            String(phase_a_receipt.compiler_resolution) ==
                String(compilation.resolution) &&
            phase_a_receipt.compiler_accepted === compilation.accepted &&
            String(phase_a_receipt.compiler_claim_ceiling) ==
                String(compilation.claim_ceiling) &&
            Tuple(String.(phase_a_receipt.compiler_errors)) ==
                Tuple(String.(compilation.errors)) &&
            Tuple(String.(phase_a_receipt.compiler_gaps)) ==
                Tuple(String.(compilation.gaps)) ||
            error("phase-A receipt compiler result hashes/status do not match artifact")
        profile = form.unit_profile
        programs = form.programs
    end

    if phase === :phase_a
        _native_stage("profile_and_program_build_complete")
    else
        _native_stage("phase_a_artifact_lineage_verified")
    end

    unit_cases = (
        (:g1_u, g1.declaration.u.physical_type.units,
            Base.invokelatest(R._ng12_zero_unit)),
        (:g1_k, g1.declaration.K.physical_type.units,
            Base.invokelatest(R._ng12_zero_unit)),
        (:g1_f, g1.declaration.f.physical_type.units,
            Base.invokelatest(R._ng12_si_length_unit, -2)),
        (:g2_coordinate, g2.source.units.coordinate,
            Base.invokelatest(R._ng12_si_length_unit, 1)),
        (:g2_field_value, g2.source.units.field_value,
            Base.invokelatest(R._ng12_zero_unit)),
        (:g2_flux_value, g2.source.units.flux_value,
            Base.invokelatest(R._ng12_si_length_unit, -1)))
    _native_stage("unit_preflight_begin")
    for (field, native_unit, expected_unit) in unit_cases
        _native_stage("unit_preflight_field_begin:" * String(field))
        translated = try
            Base.invokelatest(R.native_g1g2_translate_unit_v1, profile, native_unit)
        catch err
            throw(ErrorException("native unit preflight failed at $(field): " *
                sprint(showerror, err)))
        end
        translated == expected_unit ||
            error("native unit preflight mismatch at $(field): got " *
                repr(Tuple(translated.exponents)) * ", expected " *
                repr(Tuple(expected_unit.exponents)))
        println("UP1_NATIVE_UNIT_PREFLIGHT\t", field, "\t",
            repr(Tuple(translated.exponents)))
        flush(stdout)
        _native_stage("unit_preflight_field_complete:" * String(field))
    end
    _native_stage("unit_preflight_complete")

    scenario = (scenario_id=String(record.scenario_id), execution_scope=:numerical_preparation)
    if phase === :phase_a
        native_t1_errors = Base.invokelatest(R.native_g1g2_t1_binding_errors_v1,
            admission, g1.declaration, g2.declaration)
        isempty(native_t1_errors) ||
            error("persisted T1 package is not bound to same-candidate G1/G2: " *
                repr(native_t1_errors))
        _native_stage("native_compile_begin")
        compilation = Base.invokelatest(R.compile_native_g1g2_diffusion_v1,
            admission, g1.declaration, g2.declaration, programs, profile;
            scenario=scenario)
        _native_stage("native_compile_complete")
    else
        compilation.compilation.scenario == scenario ||
            error("phase-A compilation scenario differs from current frozen source")
        _native_stage("phase_a_result_contract_check_begin")
    end
    _native_stage("native_compile_contract_check_begin")
    compilation.status === :compiled_numerical_preparation ||
        error("native G1/G2 compiler did not accept the rebuilt exact bundle: " * repr(compilation.errors))
    compilation.resolution === :terminal_deferred && !compilation.accepted &&
        compilation.claim_ceiling === :contract_only && compilation.compilation !== nothing ||
        error("native compile result exceeded or missed its contract-only ceiling")
    _native_stage("native_compile_contract_check_complete")
    if phase in (:gridap_prepare, :gridap_a, :gridap_b, :gridap_negative)
        _native_gridap_handoff(phase, (
            N=N, context=context, R=R, snapshot_root=snapshot_root,
            admission=admission,
            compilation=compilation, phase_a_receipt=phase_a_receipt,
            phase_a_receipt_sha=phase_a_receipt_sha,
            artifact_sha=artifact_sha, sidecar=sidecar, record=record,
            gridap_artifact_out=gridap_artifact_out,
            gridap_plan_out=gridap_plan_out,
            gridap_prepare_receipt_path=gridap_prepare_receipt_path,
            gridap_prepare_receipt_expected_sha=gridap_prepare_receipt_expected_sha,
            gridap_a_receipt_path=gridap_a_receipt_path,
            gridap_a_receipt_expected_sha=gridap_a_receipt_expected_sha,
            receipt_out=receipt_out))
        return nothing
    end
    if phase === :phase_a
        compile_artifact_path = normpath(abspath(phase_input))
        compile_artifact_raw = _native_serialized_bytes(compilation)
        compile_artifact_sha = bytes2hex(SHA.sha256(compile_artifact_raw))
        _native_stage("compile_artifact_write_begin")
        _native_write_new(compile_artifact_path, compile_artifact_raw)
        _native_stage("compile_artifact_write_complete")
        phase_a_receipt_out = (
            schema="up1-native-g1g2-compile-artifact-v1",
            snapshot_id=context.snapshot_id,
            manifest_sha256=context.manifest_sha256,
            freeze_receipt_path=String(sidecar.freeze_receipt_path),
            freeze_receipt_sha256=String(sidecar.freeze_receipt_sha256),
            candidate_id=String(record.candidate_id),
            candidate_ref_id=G.UP4_R2_IDENTITY.candidate_ref.id,
            candidate_ref_version=G.UP4_R2_IDENTITY.candidate_ref.version,
            scenario_id=String(record.scenario_id),
            t0_receipt_path=String(sidecar.t0_receipt_path),
            t0_receipt_sha256=String(sidecar.t0_receipt_sha256),
            t0_bundle_hash=String(t0.bundle_hash),
            g3_expected_receipt_path=String(sidecar.g3_expected_receipt_path),
            g3_expected_receipt_sha256=String(sidecar.g3_expected_receipt_sha256),
            g3_commitment_hash=String(g3.commitment_hash),
            admission_artifact_path=normpath(abspath(artifact_path)),
            admission_artifact_bytes=length(artifact),
            admission_artifact_sha256=artifact_sha,
            admission_sidecar_path=normpath(abspath(sidecar_path)),
            admission_sidecar_sha256=bytes2hex(SHA.sha256(sidecar_raw)),
            package_hash=admission.package.package_hash.value,
            package_semantic_identity=admission.package.semantic_identity.value,
            package_bundle_hash=admission.package.bundle_hash.value,
            expression_record_sha256=source_projection.entry.sha256,
            unknown_source_expression_sha256=String(record.unknown_source_expression_sha256),
            source_expression_sha256=String(record.source_expression_sha256),
            profile_hash=profile.profile_hash.value,
            registry_hash=programs.registry_hash.value,
            bundle_hash=programs.bundle_hash.value,
            bundle_canonical_sha256=String(record.bundle_canonical_sha256),
            compiler_source_entry_sha256=compiler_entry.sha256,
            compiler_source_hash=compilation.compilation.compiler_source_hash.value,
            compiler_status=String(compilation.status),
            compiler_resolution=String(compilation.resolution),
            compiler_accepted=compilation.accepted,
            compiler_claim_ceiling=String(compilation.claim_ceiling),
            compiler_result_hash=compilation.result_hash.value,
            compiler_compilation_hash=compilation.compilation.compilation_hash.value,
            compiler_errors=String.(compilation.errors),
            compiler_gaps=String.(compilation.gaps),
            compilation_artifact_path=compile_artifact_path,
            compilation_artifact_bytes=length(compile_artifact_raw),
            compilation_artifact_sha256=compile_artifact_sha)
        _native_stage("phase_a_receipt_write_begin")
        _native_write_new(receipt_out,
            Vector{UInt8}(codeunits(JSON3.write(phase_a_receipt_out))))
        _native_stage("phase_a_receipt_write_complete")
        println("UP1_NATIVE_PHASE_A_PASS\t", context.snapshot_id, "\t",
            compile_artifact_sha, "\t", compilation.status,
            "\tNativeSolver=not_run\tPhysicsCredit=none")
        return nothing
    end

    _native_stage("public_compilation_validator_begin")
    Base.invokelatest(R.validate_native_g1g2_diffusion_compilation_v1,
        compilation.compilation) ||
        error("native compile artifact failed its public integrity validator")
    _native_stage("public_compilation_validator_complete")

    _native_stage("wrong_candidate_control_begin")
    wrong_ref = Base.invokelatest(G.QualifiedRefV1,
        "fusionconceptai://candidate-design/wrong-native-handoff-control", "v5")
    wrong_payload = Base.invokelatest(G.G1DiffusionSourcePayloadV1,
        wrong_ref, g1.declaration.source_ref,
        g1.declaration.source_version, g1.declaration.u, g1.declaration.K,
        g1.declaration.f)
    wrong_candidate_g1 = Base.invokelatest(G.g1_diffusion_declaration_v1, wrong_ref,
        g1.declaration.source_ref, g1.declaration.source_version,
        Base.invokelatest(G.g1_diffusion_source_hash_v1, wrong_payload), g1.declaration.u,
        g1.declaration.K, g1.declaration.f, g1.declaration.operators,
        g1.declaration.closure_ref, g1.declaration.applicability_ref,
        g1.declaration.applicability_domain, g1.declaration.negative_controls;
        ownership=g1.declaration.ownership, source_payload=wrong_payload)
    wrong_candidate = Base.invokelatest(R.compile_native_g1g2_diffusion_v1,
        admission, wrong_candidate_g1, g2.declaration, programs, profile; scenario=scenario)
    wrong_candidate.status === :fail_closed && !isempty(wrong_candidate.errors) ||
        error("wrong-candidate control did not fail closed")
    _native_stage("wrong_candidate_control_complete")

    _native_stage("wrong_parameter_bundle_build_begin")
    changed_slopes = (programs.parameters.k_slope[1] + 1//100,
        programs.parameters.k_slope[2], programs.parameters.k_slope[3])
    wrong_programs = Base.invokelatest(R.native_g1g2_program_bundle_v1, profile;
        physical_lower=programs.parameters.physical_lower,
        physical_upper=programs.parameters.physical_upper,
        k_base=programs.parameters.k_base, k_slope=changed_slopes)
    _native_stage("wrong_parameter_bundle_build_complete")
    _native_stage("wrong_parameter_bundle_compile_begin")
    wrong_parameter_bundle = Base.invokelatest(R.compile_native_g1g2_diffusion_v1,
        admission, g1.declaration, g2.declaration, wrong_programs, profile; scenario=scenario)
    wrong_parameter_bundle.status === :fail_closed && !isempty(wrong_parameter_bundle.errors) ||
        error("wrong parameter-bundle control did not fail closed")
    _native_stage("wrong_parameter_bundle_compile_complete")

    receipt = (schema="up1-native-g1g2-compile-only-handoff-v1",
        phase="phase_b",
        snapshot_id=context.snapshot_id,
        manifest_sha256=context.manifest_sha256,
        candidate_id=String(record.candidate_id), scenario_id=String(record.scenario_id),
        admission_artifact_sha256=artifact_sha,
        t1_status=String(admission.status), t1_resolution=String(admission.resolution),
        package_hash=admission.package.package_hash.value,
        package_semantic_identity=admission.package.semantic_identity.value,
        expression_record_sha256=source_projection.entry.sha256,
        compiler_provenance_sha256=String(record.compiler_sha256),
        compiler_source_entry_sha256=compiler_entry.sha256,
        compiler_source_hash=compilation.compilation.compiler_source_hash.value,
        rebuilt_profile_hash=profile.profile_hash.value,
        rebuilt_registry_hash=programs.registry_hash.value,
        rebuilt_bundle_hash=programs.bundle_hash.value,
        admission_sidecar_sha256=bytes2hex(SHA.sha256(sidecar_raw)),
        phase_a_receipt_sha256=phase_a_receipt_sha,
        compilation_artifact_sha256=String(phase_a_receipt.compilation_artifact_sha256),
        compiler_status=String(compilation.status),
        compiler_resolution=String(compilation.resolution),
        compiler_result_hash=compilation.result_hash.value,
        compiler_compilation_hash=compilation.compilation.compilation_hash.value,
        compiler_accepted=compilation.accepted,
        compiler_claim_ceiling=String(compilation.claim_ceiling),
        compiler_errors=String.(compilation.errors), compiler_gaps=String.(compilation.gaps),
        wrong_candidate_control=String(wrong_candidate.status),
        wrong_parameter_bundle_control=String(wrong_parameter_bundle.status),
        native_solver="not_run", numerical_result="not_executed", physics_credit="none")
    _native_stage("receipt_write_begin")
    _native_write_new(receipt_out,
        Vector{UInt8}(codeunits(JSON3.write(receipt))))
    _native_stage("receipt_write_complete")
    println("UP1_NATIVE_PHASE_B_PASS\t", context.snapshot_id, "\t",
        artifact_sha, "\t", compilation.status, "\twrong_candidate=fail_closed",
        "\twrong_parameter_bundle=fail_closed\tNativeSolver=not_run\tPhysicsCredit=none")
end

Base.invokelatest(main)
