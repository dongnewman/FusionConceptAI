using Serialization, SHA

function _g2_ideal_periodic_jn_acceptance_contract_tests(F)
    @testset "Ideal-periodic Jn scientific acceptance contract" begin
        protocol=F._CCP_IDEAL_PERIODIC_JN_ACCEPTANCE
        @test protocol.pointwise_total_upper_limit_A_per_m2==1.0e-4
        @test protocol.absolute_leakage_total_upper_limit_A==1.0e-3
        @test protocol.signed_leakage_absolute_upper_limit_A==1.0e-4
        state=[0.25,-0.5]
        trace=(current_topology=:ideal_axisymmetric_periodic_lcfs_no_normal_current,
            return_current_path=:periodic_toroidal_plasma_with_zero_normal_current_at_LCFS,
            Jn_A_per_m2=zeros(64),integrated_current_A=0.0)
        bounds=(state=copy(state),Jn_A_per_m2=copy(trace.Jn_A_per_m2),
            whole_LCFS_coverage_certified=true,included_error_terms=protocol.error_terms,
            pointwise_total_upper_A_per_m2=1.0e-5,absolute_leakage_total_upper_A=1.0e-4,
            signed_leakage_absolute_upper_A=1.0e-5,nonzero_D_h_h2_control_passed=true)
        evaluate(t,b)=F._ccp_ideal_periodic_jn_error_acceptance(t,state,b)
        @test evaluate(trace,bounds).accepted
        @test !evaluate(trace,nothing).accepted
        @test !evaluate(trace,merge(bounds,(state=[0.25,-0.4],))).accepted
        @test !evaluate(trace,merge(bounds,(whole_LCFS_coverage_certified=false,))).accepted
        @test !evaluate(trace,merge(bounds,(included_error_terms=(:actual_constraint_residual,),))).accepted
        @test !evaluate(trace,merge(bounds,(nonzero_D_h_h2_control_passed=false,))).accepted
        @test !evaluate(trace,merge(bounds,(pointwise_total_upper_A_per_m2=NaN,))).accepted
        @test !evaluate(trace,merge(bounds,(pointwise_total_upper_A_per_m2=2.0e-4,))).accepted
        @test !evaluate(trace,merge(bounds,(signed_leakage_absolute_upper_A=2.0e-4,))).accepted
        cancelling=merge(trace,(Jn_A_per_m2=[isodd(i) ? 5.0e-5 : -5.0e-5 for i in 1:64],))
        leakage=merge(bounds,(Jn_A_per_m2=copy(cancelling.Jn_A_per_m2),
            pointwise_total_upper_A_per_m2=5.0e-5,absolute_leakage_total_upper_A=1.1e-3,
            signed_leakage_absolute_upper_A=0.0))
        result=evaluate(cancelling,leakage)
        @test !result.accepted && result.status===:scientific_fail
        @test result.passes.signed_leakage && !result.passes.absolute_leakage
        @test !result.global_topology_closed && !result.physical_validation
    end
end

function _g2_global_diag_result_file_sha256(path::AbstractString)
    open(path,"r") do io
        bytes2hex(SHA.sha256(io))
    end
end

Base.@noinline Base.@nospecializeinfer function _g2_near_cut_numeric_capture_summary(F,result,join,run_leaf)
    Base.@nospecialize F result join run_leaf
    getvalue(x,k,default=:typed_absent)=x isa NamedTuple && hasproperty(x,k) ? getproperty(x,k) : default
    bounds(x)=x===:typed_absent ? :typed_absent : Tuple(string(v) for v in x)
    identity=(candidate_hash=string(getvalue(result,:candidate_hash)),
        context_hash=string(getvalue(result,:context_hash)),
        upstream_output_hash=string(getvalue(result,:upstream_output_hash)),
        trace_hash=string(getvalue(result,:trace_hash)),target_index=19,selected_dof=41032)
    capture=getvalue(join,:numeric_replay_capture)
    path=:not_written;sha=:not_written;byte_count=0
    if capture!==:typed_absent
        isdir(run_leaf) || throw(ArgumentError("near-cut capture run leaf must already exist"))
        result_dir=joinpath(run_leaf,"result_data","near_cut")
        mkpath(result_dir)
        capture_path=joinpath(result_dir,"numeric_inputs.jls")
        ispath(capture_path) && throw(ArgumentError("near-cut numeric capture path already exists"))
        open(capture_path,"w") do io
            Serialization.serialize(io,(schema="near-cut-q8-numeric-replay-file-v1",
                capture_identity=identity,capture=capture))
            flush(io)
        end
        path=capture_path;byte_count=filesize(capture_path);sha=_g2_global_diag_result_file_sha256(capture_path)
    end
    summary=(capture_identity=identity,producer_status=getvalue(result,:status),join_status=getvalue(join,:status),
        reason=getvalue(join,:reason),consumer_status=getvalue(join,:consumer_status),
        near_cut_integral_gate_passed=getvalue(join,:near_cut_integral_gate_passed),
        active_basis_terms=getvalue(join,:near_cut_active_basis_terms),
        covered_basis_terms=getvalue(join,:covered_near_cut_basis_terms),
        interval_operations=getvalue(join,:interval_operations),max_interval_operations=getvalue(join,:max_interval_operations),
        kernel_calls=getvalue(join,:kernel_calls),max_kernel_calls=getvalue(join,:max_kernel_calls),
        G_error_bound_RZ=bounds(getvalue(join,:aggregate_G_dot_to_exact_leaf_sum_distance_upper_RZ)),
        E_current_error_bound_RZ=bounds(getvalue(join,:aggregate_E_dot_current_to_exact_leaf_basis_sum_distance_upper_RZ)),
        E_dcurrent_error_bound_RZ=bounds(getvalue(join,:aggregate_E_dot_dcurrent_to_exact_leaf_basis_sum_distance_upper_RZ)),
        E_plus_G_error_bound_RZ=bounds(getvalue(join,:consumer_Q8_to_exact_E_dot_plus_G_integral_interval_distance_upper_RZ)),
        numeric_replay_capture_bytes=getvalue(join,:numeric_replay_capture_bytes),
        capture_path=path,capture_bytes=byte_count,capture_sha256=sha)
    println("NEAR_CUT_G2_CAPTURE="*F.canonical_json(summary));flush(stdout)
    summary
end

function _g2_global_diag_spill_matrices(run_leaf::AbstractString, jacobian::SparseArrays.SparseMatrixCSC{Float64,Int}, equality_jacobian::SparseArrays.SparseMatrixCSC{Float64,Int};
        residual,equality_residual,state,column_scales,least_squares_row_scales,equality_row_scales,replay_metadata)
    isdir(run_leaf) || throw(ArgumentError("global diagnostic run leaf must already exist"))
    size(jacobian,2)==size(equality_jacobian,2) ||
        throw(ArgumentError("global diagnostic matrix column counts differ"))
    size(jacobian,1)==length(residual)==length(least_squares_row_scales) &&
        size(equality_jacobian,1)==length(equality_residual)==length(equality_row_scales) &&
        size(jacobian,2)==length(state)==length(column_scales) ||
        throw(ArgumentError("global diagnostic numeric replay dimensions differ"))
    all(isfinite,SparseArrays.nonzeros(jacobian)) &&
        all(isfinite,SparseArrays.nonzeros(equality_jacobian)) ||
        throw(ArgumentError("global diagnostic matrices must be finite before spill"))
    hasproperty(replay_metadata,:schema) && replay_metadata.schema=="g2-global-diagnostic-replay-metadata-v1" &&
        hasproperty(replay_metadata,:ordered_ids) && hasproperty(replay_metadata,:least_squares_row_indices) &&
        hasproperty(replay_metadata,:equality_base_row_indices) && hasproperty(replay_metadata,:endpoint_row_indices) &&
        hasproperty(replay_metadata,:equality_endpoint_positions) && hasproperty(replay_metadata,:pressure_indices) &&
        hasproperty(replay_metadata,:consumer_identity) && hasproperty(replay_metadata,:data_identity) ||
        throw(ArgumentError("global diagnostic replay metadata are incomplete"))
    numeric=(Float64.(collect(residual)),Float64.(collect(equality_residual)),Float64.(collect(state)),
        Float64.(collect(column_scales)),Float64.(collect(least_squares_row_scales)),Float64.(collect(equality_row_scales)))
    all(v->all(isfinite,v),numeric) || throw(ArgumentError("global diagnostic replay vectors must be finite"))
    result_dir=joinpath(run_leaf,"result_data","g2_global_diagnostic")
    mkpath(result_dir)
    path=joinpath(result_dir,"numeric_matrices_v3.jls")
    ispath(path) && throw(ArgumentError("global diagnostic numeric-result path already exists"))
    payload=(schema="g2-global-diagnostic-numeric-matrices-v3",jacobian,equality_jacobian,
        residual=numeric[1],equality_residual=numeric[2],state=numeric[3],column_scales=numeric[4],
        least_squares_row_scales=numeric[5],equality_row_scales=numeric[6],replay_metadata=replay_metadata)
    open(path,"w") do io
        Serialization.serialize(io,payload)
        flush(io)
    end
    path
end

function _g2_global_diag_reload_matrices(path::AbstractString; expected_sha256::AbstractString)
    isfile(path) || throw(ArgumentError("global diagnostic numeric-result file is missing"))
    occursin(r"^[0-9a-f]{64}$",expected_sha256) &&
        _g2_global_diag_result_file_sha256(path)==expected_sha256 ||
        throw(ArgumentError("global diagnostic numeric-result file integrity differs"))
    payload=open(path,"r") do io
        Serialization.deserialize(io)
    end
    hasproperty(payload,:schema) && payload.schema=="g2-global-diagnostic-numeric-matrices-v3" ||
        throw(ArgumentError("global diagnostic numeric-result schema differs"))
    J=getproperty(payload,:jacobian);C=getproperty(payload,:equality_jacobian)
    J isa SparseArrays.SparseMatrixCSC{Float64,Int} &&
        C isa SparseArrays.SparseMatrixCSC{Float64,Int} && size(J,2)==size(C,2) ||
        throw(ArgumentError("global diagnostic numeric-result matrices are malformed"))
    all(isfinite,SparseArrays.nonzeros(J)) && all(isfinite,SparseArrays.nonzeros(C)) ||
        throw(ArgumentError("global diagnostic numeric-result matrices are nonfinite"))
    vectors=(payload.residual,payload.equality_residual,payload.state,payload.column_scales,
        payload.least_squares_row_scales,payload.equality_row_scales)
    all(v->v isa Vector{Float64} && all(isfinite,v),vectors) ||
        throw(ArgumentError("global diagnostic replay vectors are malformed"))
    (jacobian=J,equality_jacobian=C,residual=payload.residual,equality_residual=payload.equality_residual,
        state=payload.state,column_scales=payload.column_scales,
        least_squares_row_scales=payload.least_squares_row_scales,equality_row_scales=payload.equality_row_scales,
        replay_metadata=payload.replay_metadata)
end

Base.@noinline Base.@nospecializeinfer function _g2_saved_baseline_gs_u_plus_resource_short_v1(
        S,component,trace,provider,composed,regional,diagnostic_model,candidate_scaling,scale_contract,run_leaf)
    Base.@nospecialize S component trace provider composed regional diagnostic_model candidate_scaling scale_contract run_leaf
    path=get(ENV,"FUSION_G2_PRECHECK_SAVED_NUMERIC_BASELINE_PATH","")
    sha=lowercase(get(ENV,"FUSION_G2_PRECHECK_SAVED_NUMERIC_BASELINE_SHA256",""))
    !isempty(path) && isfile(path) || error("saved-baseline plus short requires its pinned R4 numeric result")
    occursin(r"^[0-9a-f]{64}$",sha) || error("saved-baseline plus short requires the exact result SHA-256")
    saved=_g2_global_diag_reload_matrices(path;expected_sha256=sha)
    meta=saved.replay_metadata
    meta.validation_stage===:global_oracles_passed || error("saved baseline lacks completed global-oracle validation")
    meta.consumer_identity.scope===:diagnostic_incomplete_global_assembly ||
        error("saved baseline is outside the diagnostic incomplete-assembly scope")
    id=meta.consumer_identity
    all(k->hasproperty(id,k),(:candidate_hash,:trace_hash,:current_operator_model_id,:hagenow_source_operator_model_id)) &&
        id.candidate_hash==component.candidate_hash && id.trace_hash==trace.trace_hash &&
        id.current_operator_model_id===component.current_operator_model_id &&
        id.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id ||
        error("saved baseline semantic model identity differs from the live field model")
    hasproperty(id,:provider_id) && id.provider_id==diagnostic_model.provider_id ||
        error("saved baseline provider identity differs")
    hasproperty(id,:component_context_hash) && id.component_context_hash==component.context_hash ||
        error("saved baseline component-context identity differs")
    hasproperty(id,:scale_contract_hash) && id.scale_contract_hash==scale_contract.contract_hash ||
        error("saved baseline scale-contract identity differs")
    hasproperty(id,:scale_policy) && id.scale_policy===scale_contract.scale_policy ||
        error("saved baseline scale policy differs")
    n=length(component.initial_state)
    diagnostic_model.region_ids==(regional.region_id,) && diagnostic_model.shared_scatter &&
        diagnostic_model.edge_equilibrium_evaluator===nothing &&
        length(diagnostic_model.local_dof_to_global)==1 &&
        length(diagnostic_model.local_test_row_to_global)==1 &&
        all(i->diagnostic_model.local_dof_to_global[1][i]==i,1:n) &&
        length(diagnostic_model.local_test_row_to_global[1])==length(regional.equation_ids) &&
        all(i->diagnostic_model.local_test_row_to_global[1][i]==i,1:length(regional.equation_ids)) ||
        error("live model is not the saved one-region identity-map consumer")
    size(saved.jacobian)==(length(regional.equation_ids),n) &&
        size(saved.equality_jacobian)==(length(scale_contract.equalities.row_ids),n) ||
        error("saved baseline J/C dimensions differ from the live model")
    data=meta.data_identity
    data.jacobian_dimensions==size(saved.jacobian) && data.jacobian_nnz==SparseArrays.nnz(saved.jacobian) &&
        data.equality_jacobian_dimensions==size(saved.equality_jacobian) &&
        data.equality_jacobian_nnz==SparseArrays.nnz(saved.equality_jacobian) &&
        data.residual_length==length(saved.residual) &&
        data.equality_residual_length==length(saved.equality_residual) ||
        error("saved baseline replay data identity differs from its numeric payload")
    Tuple(meta.ordered_ids.least_squares_raw)==Tuple(regional.equation_ids) ||
        error("saved baseline regional equation order differs")
    Tuple(meta.ordered_ids.equality_base)==Tuple(scale_contract.equalities.row_ids) ||
        error("saved baseline equality row order differs")
    Tuple(meta.ordered_ids.endpoint)==Tuple(component.dynamic_span_equation_ids) ||
        error("saved baseline endpoint row order differs")
    Tuple(meta.pressure_indices)==Tuple(i for i in component.pressure_dofs if i>0) ||
        error("saved baseline pressure map differs")
    Tuple(saved.column_scales)==Tuple(candidate_scaling.column_scales) ||
        error("saved baseline column scales differ")
    Tuple(saved.least_squares_row_scales)==Tuple(diagnostic_model.equilibrium_row_scales) ||
        error("saved baseline least-squares row scales differ")
    Tuple(saved.equality_row_scales)==Tuple(scale_contract.equalities.characteristics) ||
        error("saved baseline equality scales differ")
    endpoint_rows=Tuple(component.dynamic_span_row_range)
    Tuple(meta.endpoint_row_indices)==endpoint_rows || error("saved endpoint row map differs")
    Tuple(meta.least_squares_row_indices)==Tuple(i for i in eachindex(saved.residual) if !(i in endpoint_rows)) ||
        error("saved least-squares row map differs")
    Tuple(meta.equality_base_row_indices)==Tuple(1:length(scale_contract.equalities.row_ids)) ||
        error("saved equality base row map differs")
    Tuple(meta.equality_endpoint_positions)==Tuple(length(scale_contract.equalities.row_ids)+i for i in eachindex(endpoint_rows)) ||
        error("saved endpoint equality positions differ")
    expected_state=copy(component.initial_state)
    law=component.profile_law
    pressure_dof=first(i for i in component.pressure_dofs if i>0)
    expected_state[pressure_dof]+=1.0
    changed_core=first(k for k in eachindex(component.core_mask) if component.core_mask[k] &&
        0.3<(component.initial_state[4k]-law.psi_boundary_wb_per_rad)/
            (law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)<0.7)
    expected_state[4changed_core]+=1.0e-4*(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)
    axis_col,boundary_col=component.profile_span_columns
    endpoint_step=1.0e-8*abs(component.initial_state[axis_col]-component.initial_state[boundary_col])
    expected_state[axis_col]+=endpoint_step;expected_state[boundary_col]-=endpoint_step
    saved.state==expected_state || error("saved baseline state differs from the exact live diagnostic perturbation")
    gs_rows=findall(id->occursin(":GS4:",id),regional.equation_ids)
    length(gs_rows)>0 || error("live selected-GS row map is empty")
    u_col=component.profile_coefficient_columns[1]
    analytic=Float64[saved.jacobian[row,u_col] for row in gs_rows]
    all(isfinite,analytic) && any(!iszero,analytic) || error("saved analytic GS-u column is invalid")
    state=copy(saved.state)
    u_step=1.0e-3*max(1.0,abs(state[u_col]))
    saved=nothing;expected_state=nothing;GC.gc(true)
    println("G2_GLOBAL_DIAGNOSTIC_SAVED_BASELINE_REUSE status=exact_binding_pass",
        " source_bytes=",filesize(path)," semantic_identity=true maps_scales_state=true",
        " state_dofs=",n," regional_rows=",length(regional.equation_ids),
        " gs_rows=",length(gs_rows)," gs_u_column=",u_col,
        " gc_live_bytes_before_plus=",Base.gc_live_bytes()," full_baseline_assembly=not_repeated")
    flush(stdout)
    plus_state=copy(state);plus_state[u_col]+=u_step;state=nothing
    result=begin
        get(ENV,"FUSION_G2_BORROW_CANONICAL_IDENTITY_REGION_BLOCK","0")=="1" ||
            error("saved-baseline plus short requires the exact-identity canonical CSC borrow")
        println("G2_GLOBAL_DIAGNOSTIC_SAVED_BASELINE_PLUS_BEGIN gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        S.assemble_coupled_mhd_global_v1(diagnostic_model,plus_state;allow_incomplete=true)
    end
    result_dir=joinpath(run_leaf,"result_data","g2_global_diagnostic");mkpath(result_dir)
    raw_path=joinpath(result_dir,"saved_baseline_gs_u_plus_assembly_raw_v1.jls")
    ispath(raw_path) && error("refusing to overwrite saved-baseline plus raw result")
    open(raw_path,"w") do io
        Serialization.serialize(io,(schema="saved-baseline-gs-u-plus-assembly-raw-v1",
            result=result,state=plus_state,u_column=u_col,step=u_step,baseline_analytic_gs_u=analytic,
            baseline_path=path,baseline_sha256=sha));flush(io)
    end
    raw_bytes=filesize(raw_path);raw_sha=_g2_global_diag_result_file_sha256(raw_path)
    result.status===:typed_absent && result.missing_closures==S._REQUIRED_CLOSURES ||
        error("plus assembly returned an unexpected closure status")
    assembly=result.diagnostic_assembly
    assembly.status===:incomplete_assembly && assembly.claim_ceiling===:diagnostic_only &&
        !assembly.physical_authority || error("plus assembly status/claim ceiling differs")
    all(check->check.passed,assembly.jacobian_checks.regional) &&
        all(check->check.passed,assembly.jacobian_checks.outer) &&
        assembly.jacobian_checks.global_conservation.passed || error("plus assembly oracle gate failed")
    assembly.equation_ids.regional==(Tuple(regional.equation_ids),) &&
        assembly.equation_ids.outer==(composed.outer.constraint_ids,) &&
        assembly.equation_ids.conservation==Tuple(provider.conservation_ids) ||
        error("plus assembly row ownership differs")
    println("G2_GLOBAL_DIAGNOSTIC_SAVED_BASELINE_PLUS_RESULT status=assembler_oracles_passed",
        " raw_path=",raw_path," raw_bytes=",raw_bytes," raw_sha256=",raw_sha,
        " gc_live_bytes=",Base.gc_live_bytes()," gs_u_fd_comparison=not_executed",
        " nonlinear_trial=not_executed kkt=not_executed closure_credit=false physical_validation=false")
    flush(stdout)
    result=nothing;assembly=nothing;plus_state=nothing;analytic=nothing;GC.gc(true)
    (status=:saved_baseline_gs_u_plus_resource_short_completed,raw_path=raw_path,
        raw_bytes=raw_bytes,raw_sha256=raw_sha,gs_u_fd_comparison=:not_executed,
        nonlinear_trial=:not_executed,kkt=:not_executed,closure_credit=false,physical_validation=false)
end
Base.@noinline Base.@nospecializeinfer function _g2_global_diag_spill_actual_nonlinear_trial_raw(run_leaf,trial_result,trial_state,alpha,trial_index;state_record=nothing)
    Base.@nospecialize run_leaf trial_result trial_state alpha trial_index
    isdir(run_leaf) || throw(ArgumentError("actual nonlinear trial raw requires the existing bounded run leaf"))
    result_dir=joinpath(run_leaf,"result_data","g2_global_diagnostic")
    mkpath(result_dir)
    path=joinpath(result_dir,"actual_nonlinear_trial_raw_$(lpad(string(trial_index),3,'0'))_v1.jls")
    ispath(path) && throw(ArgumentError("refusing to overwrite actual nonlinear trial raw result"))
    payload=(schema="g2-global-diagnostic-actual-nonlinear-trial-raw-v1",
        trial_index=Int(trial_index),alpha=Float64(alpha),state=trial_state,result=trial_result)
    if state_record!==nothing
        state_record.state==trial_state || error("raw trial coordinate record differs from assembled state")
        payload=merge(payload,(state_record=state_record,state_coordinate_id=state_record.state_coordinate_id))
    end
    open(path,"w") do io
        Serialization.serialize(io,payload)
        flush(io)
    end
    byte_count=filesize(path)
    result_sha256=_g2_global_diag_result_file_sha256(path)
    println("G2_GLOBAL_NONLINEAR_TRIAL_RAW path=",path," bytes=",byte_count,
        " sha256=",result_sha256," trial_index=",trial_index," alpha=",alpha)
    flush(stdout)
    (path=path,bytes=byte_count,sha256=result_sha256)
end

function _selected_fd_active_dof_roundoff_floor(x,direction)
    length(x)==length(direction) || throw(ArgumentError("selected FD state and direction lengths differ"))
    floor=0.0;active_count=0
    for column in eachindex(direction)
        raw_direction=direction[column]
        isfinite(raw_direction) || throw(ArgumentError("selected FD direction must be finite"))
        direction_value=Float64(raw_direction)
        iszero(direction_value) && continue
        state_value=Float64(x[column])
        isfinite(state_value) || throw(ArgumentError("active selected FD state entries must be finite"))
        component_floor=128eps(Float64)*max(1.0,abs(state_value))/abs(direction_value)
        isfinite(component_floor) && component_floor>0.0 ||
            throw(ArgumentError("active selected FD roundoff floor is not finite and positive"))
        floor=max(floor,component_floor);active_count+=1
    end
    active_count>0 && isfinite(floor) && floor>0.0 ||
        throw(ArgumentError("selected FD direction must have a finite nonzero active entry"))
    floor
end

function test_actual_exterior_far_rectangular_control(F,base_prep,safe_preparations,
        safe_geometries,base_geometry,direction,h1,h2,max_calls;total_error=false,capture_identity=nothing,capture_inputs=true)
    domain=base_prep.domain;cells=base_prep.prepared_cells;mu0=domain.law.mu0_N_per_A2
    rect_timing=get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1"
    capture_inputs isa Bool || throw(ArgumentError("far numeric input capture selector must be Bool"))
    if total_error && capture_inputs
        result_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
        !isempty(result_leaf) && isdir(result_leaf) || error("actual far64 numeric input capture requires the existing result leaf")
        capture_identity isa NamedTuple || error("actual far64 numeric input capture requires consumer identity")
        hasproperty(capture_identity,:candidate_identity) && hasproperty(capture_identity,:provider_context) &&
            hasproperty(capture_identity,:trace_identity) || error("actual far64 capture identity is incomplete")
        result_dir=joinpath(result_leaf,"result_data");mkpath(result_dir)
        input_path=joinpath(result_dir,"actual_far64_numeric_inputs_v1.jls")
        ispath(input_path) && error("actual far64 numeric input capture path already exists")
        numeric_domain=(law=(mu0_N_per_A2=mu0,),)
        numeric_cell(c)=(native_cell=c.native_cell,bounds=Tuple(c.bounds),columns=Tuple(c.columns),
            pieces=Tuple((points=Tuple(piece.points),
                velocities=hasproperty(piece,:velocities) ? Tuple(piece.velocities) : (),
                lineage=piece.lineage) for piece in c.pieces),
            tolerance=hasproperty(c,:tolerance) ? c.tolerance : nothing)
        numeric_prep(p)=(status=p.status,target=Tuple(p.target),target_index=p.target_index,
            current=collect(p.current),core_ids=collect(p.core_ids),domain=numeric_domain,
            state=collect(p.state),state_direction=collect(p.state_direction),
            dtarget=Tuple(p.dtarget),dcurrent=collect(p.dcurrent),
            support_ownership_counts=p.support_ownership_counts,
            near_target_cell_ids=collect(p.near_target_cell_ids),
            polygon_triangulation_signature=p.polygon_triangulation_signature,
            clipping_signature=p.clipping_signature,
            quadrature_partition_signature=p.quadrature_partition_signature,
            singular_cover_count=p.singular_cover_count,refined_triangle_count=p.refined_triangle_count)
        numeric_base_prep=merge(numeric_prep(base_prep),
            (prepared_cells=NamedTuple[numeric_cell(c) for c in cells],))
        numeric_safe_preparations=Tuple((h=Float64(h),prep=numeric_prep(safe_preparations[h]))
            for h in sort!(collect(keys(safe_preparations))))
        numeric_geometry(g)=(first_outward_crossing_signature=g.first_outward_crossing_signature,
            coordinates_RZ_m=Tuple(Tuple(x) for x in g.coordinates_RZ_m))
        numeric_safe_geometries=Tuple((h=Float64(h),geometry=numeric_geometry(safe_geometries[h]))
            for h in sort!(collect(keys(safe_geometries))))
        payload=(schema="actual-far64-numeric-inputs-v1",base_prep=numeric_base_prep,
            safe_preparations=numeric_safe_preparations,safe_geometries=numeric_safe_geometries,
            base_geometry=numeric_geometry(base_geometry),direction=collect(direction),h1=Float64(h1),h2=Float64(h2),
            max_calls=Int(max_calls),total_error=total_error,capture_identity=capture_identity)
        open(input_path,"w") do io;Serialization.serialize(io,payload);flush(io);end
        input_sha256=_g2_global_diag_result_file_sha256(input_path)
        println("ACTUAL_FAR64_NUMERIC_INPUT_CAPTURE path=",input_path," sha256=",input_sha256,
            " bytes=",filesize(input_path)," cells=",length(cells)," rays=",length(base_geometry.coordinates_RZ_m));flush(stdout)
    end
    length(base_geometry.coordinates_RZ_m)==64 || error("accepted candidate LCFS ray inventory is not 64")
    max_calls isa Integer && !(max_calls isa Bool) && 0<=max_calls<=40_000_000 ||
        error("far-rectangle control needs a nonnegative remaining shared kernel budget")
    rtol=5e-6;exact_limit=rtol/(1+rtol);total_calls=Ref(0)
    total_error isa Bool || error("total-error control must be Bool")
    if total_error
        Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned","exterior_far_rect_total_error_join_fixture.jl"))
        Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned","exterior_far_rect_joint_EG_actual_entry_fixture.jl"))
        join_fixture=Base.invokelatest(Main.test_far_total_error_join_fixture,F)
        join_fixture.status===:far_total_error_join_fixture_pass || error("aggregate interval join fixture failed")
    end
    total_state=total_error ? F._ccp_q1_lcfs_far_rect_total_error_state(
        max_gauss_interval_operations=8_000_000,max_ring_interval_operations=5_200_000_000,
        max_total_interval_operations=5_208_000_000,max_reference_ring_points=12_500_000) : nothing
    total_error_entries=0;total_error_points=0;total_error_orders=Set{Int}()
    max_local_ratio=0.0;max_q32_q64_over_bound=0.0;actual_target_count=64;q32_control_count=Ref(0)
    fixed_cell_response_count=0;fallback_cell_response_count=0
    fixed_attempt_count=0;fallback_attempt_count=0;fallback_response_total_ring_calls=0
    fixed_order_attempt_ring_calls=0;adaptive_subdivision_ring_calls=0
    fallback_depth_counts=Dict{Int,Int}();fallback_order_counts=Dict{Int,Int}()


    function evaluate(prep;check_q32=false,check_total_error=false)
        E=zeros(Float64,2,length(prep.core_ids));G=zeros(Float64,2,128)
        error_entries=zeros(Float64,2,length(prep.core_ids));farfield=zeros(Float64,2)
        farbound=zeros(Float64,2);orders=Int[];control_done=false
        total_stream=check_total_error ? (E_lower=zeros(Float64,2,length(prep.core_ids)),
            E_upper=zeros(Float64,2,length(prep.core_ids)),G_lower=zeros(Float64,2,2),G_upper=zeros(Float64,2,2),
            weighted_unsigned_E_bound=zeros(Float64,2),ring_interval_operations=total_state.ring_interval_operations,
            gauss_interval_operations=total_state.gauss_interval_operations,
            max_ring_interval_operations=5_200_000_000,max_total_interval_operations=5_208_000_000) : nothing
        total_G_error_bound=check_total_error ? zeros(Float64,2,128) : nothing
        total_local_E_ratio=0.0;total_local_G_ratio=0.0
        local_total_entries=0;local_total_attempt_entries=0;local_total_points=0;local_total_helper_kernel_calls=0
        local_total_G_column_checks=0
        local_total_helper_elapsed_ns=UInt64(0);local_total_response_elapsed_ns=UInt64(0)
        total_orders_used=Set{Int}()
        processed_far_cell_ids=Any[];local_fallback_depths=Int[];local_fallback_orders=Int[]
        local_fallback_cells=0;local_fallback_attempts=0;local_fixed_cells=0
        near_ids=Tuple(cell.native_cell for cell in cells
            if first(F._ccp_q1_lcfs_target_cell_distance(prep.target,cell.bounds))<=
                last(F._ccp_q1_lcfs_target_cell_distance(prep.target,cell.bounds)))
        expected_far_cell_ids=Tuple(cell.native_cell for cell in cells if !isempty(cell.pieces) &&
            all(piece->hasproperty(piece.lineage,:source) &&
                piece.lineage.source===:plasma_only_native_cell,cell.pieces) && !(cell.native_cell in near_ids))
        length(unique(expected_far_cell_ids))==length(expected_far_cell_ids) ||
            error("prepared cell inventory repeats a native cell in strict far coverage")
        for cell in cells
            isempty(cell.pieces) && continue
            all(piece->hasproperty(piece.lineage,:source) &&
                piece.lineage.source===:plasma_only_native_cell,cell.pieces) || continue
            cell.native_cell in near_ids && continue
            helper_prep=check_total_error ? (status=prep.status,target=Tuple(prep.target),
                target_index=prep.target_index,current=prep.current,core_ids=Tuple(prep.core_ids),
                domain=(law=(mu0_N_per_A2=mu0,),)) : nothing
            helper_cell=check_total_error ? (native_cell=cell.native_cell,
                bounds=Tuple(cell.bounds),columns=Tuple(cell.columns)) : nothing
            joint_total_error_check=check_total_error ? function(candidate)
                helper_ring_calls_before=total_calls[]
                reference_points_before=total_state.reference_ring_points[]
                binding=candidate.q1_response_binding
                projection_identity_ok=binding.target==helper_prep.target &&
                    binding.target_index==helper_prep.target_index &&
                    all(i->isequal(binding.current[i],helper_prep.current[i]),eachindex(helper_prep.current)) &&
                    isequal(binding.mu0,helper_prep.domain.law.mu0_N_per_A2) &&
                    all(i->isequal(binding.core_ids[i],helper_prep.core_ids[i]),eachindex(helper_prep.core_ids)) &&
                    binding.cell_native_id==helper_cell.native_cell && binding.bounds==helper_cell.bounds &&
                    binding.columns==helper_cell.columns
                projection_identity_ok || return (status=:typed_absent,
                    reason=:total_error_projection_identity_mismatch,kernel_calls=0)
                G_coverage=Base.invokelatest(Main._fixed_far_G_column_coverage,prep,cell,candidate)
                G_coverage.status===:evaluated_fixed_far_G_column_coverage || return (
                    status=:typed_absent,reason=G_coverage.reason,kernel_calls=0,
                    G_column_coverage=G_coverage)
                local_total_G_column_checks+=1
                local_total_attempt_entries+=1;total_error_attempt_entries[]+=1
                helper_started_ns=rect_timing ? time_ns() : UInt64(0)
                total=F._ccp_q1_lcfs_far_rect_total_error(helper_prep,helper_cell,candidate;
                    relative_error_tolerance=rtol,terms=16,precision_bits=256,
                    max_interval_points=12_500_000,max_subrectangles=256,
                    max_gauss_interval_ops=8_000_000,max_ring_interval_ops=5_200_000_000,
                    max_total_interval_ops=5_208_000_000,interval_state=total_state,
                    ring_interval_method=:floatagm,kernel_calls=total_calls,max_kernel_calls=max_calls,
                    compact_E_columns=true)
                rect_timing && (local_total_helper_elapsed_ns+=time_ns()-helper_started_ns)
                entry_helper_kernel_calls=total_calls[]-helper_ring_calls_before
                entry_reference_points=total_state.reference_ring_points[]-reference_points_before
                local_total_helper_kernel_calls+=entry_helper_kernel_calls
                local_total_points+=entry_reference_points;total_error_points+=entry_reference_points
                total.status===:evaluated_selected_target_far_rect_total_error ||
                    return (status=:typed_absent,reason=get(total,:reason,:total_error_unavailable),total=total,kernel_calls=entry_helper_kernel_calls)
                push!(total_orders_used,candidate.order);push!(total_error_orders,candidate.order)
                (status=:evaluated,
                    E_ratio=maximum(total.E_local_relative_ratio_by_active_column;init=0.0),
                    G_ratio=total.selected_target_G_local_relative_ratio,total=total,
                    kernel_calls=total.production_kernel_calls_this_entry)
            end : nothing
            helper_calls_before=local_total_helper_kernel_calls
            before=total_calls[]
            response_started_ns=rect_timing ? time_ns() : UInt64(0)
            result=F._ccp_q1_lcfs_rectangular_far_response(prep,cell,total_calls,max_calls;
                relative_error_tolerance=rtol,joint_total_error_check=joint_total_error_check)
            rect_timing && (local_total_response_elapsed_ns+=time_ns()-response_started_ns)
            if result.status===:typed_absent && (hasproperty(result,:joint_response) ||
                    (hasproperty(result,:last_joint_total_error_attempt) && result.last_joint_total_error_attempt!==nothing))
                joint=get(result,:last_joint_total_error_attempt,nothing)
                check=joint===nothing ? get(result,:joint_total_error_check,:typed_absent) : joint.check
                candidate=joint===nothing ? get(result,:joint_response,:typed_absent) : joint.response
                check_value(k,default)=check isa NamedTuple && hasproperty(check,k) ? getproperty(check,k) : default
                report=check_value(:total,:typed_absent)
                report_status=report isa NamedTuple && hasproperty(report,:status) ? report.status : :typed_absent
                report_reason=report isa NamedTuple && hasproperty(report,:reason) ? report.reason : :none
                result_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
                !isempty(result_leaf) && isdir(result_leaf) || error(
                    "joint far-total-error failure capture requires the existing result leaf")
                hasproperty(candidate,:E) && hasproperty(candidate,:G) &&
                    hasproperty(candidate,:q1_response_binding) && hasproperty(candidate,:subdivision_rectangles) ||
                    error("joint far-total-error failure response is incomplete for numeric capture")
                numeric_prep=(status=prep.status,target=Tuple(prep.target),target_index=prep.target_index,
                    current=copy(prep.current),core_ids=Tuple(prep.core_ids),
                    domain=(law=(mu0_N_per_A2=prep.domain.law.mu0_N_per_A2,),))
                numeric_cell=(native_cell=cell.native_cell,bounds=Tuple(cell.bounds),columns=Tuple(cell.columns))
                numeric_response=(status=candidate.status,E=copy(candidate.E),G=copy(candidate.G),
                    E_error_bound=copy(candidate.E_error_bound),order=candidate.order,
                    kernel_calls=candidate.kernel_calls,fallback_used=candidate.fallback_used,
                    fixed_attempts=candidate.fixed_attempts,subdivision_attempts=candidate.subdivision_attempts,
                    subdivision_depth=candidate.subdivision_depth,q1_parent_bounds=candidate.q1_parent_bounds,
                    q1_parent_columns=candidate.q1_parent_columns,
                    q1_parent_basis_mapping=candidate.q1_parent_basis_mapping,
                    q1_response_binding=candidate.q1_response_binding,
                    subdivision_rectangles=candidate.subdivision_rectangles)
                payload=(schema="far-failure-numeric-v1",
                    failure=(status=result.status,reason=result.reason,target_index=prep.target_index,
                        native_cell=cell.native_cell,total_status=report_status,
                        total_reason=report_reason,joint_check=check),
                    prep=numeric_prep,cell=numeric_cell,response=numeric_response,total=report,
                    timing=(response_inclusive_elapsed_ns=local_total_response_elapsed_ns,
                        joint_reference_helper_elapsed_ns=local_total_helper_elapsed_ns,
                        response_non_helper_elapsed_ns=max(UInt64(0),local_total_response_elapsed_ns-local_total_helper_elapsed_ns)),
                    counters=(production_kernel_calls=total_calls[],
                        reference_ring_points=total_state.reference_ring_points[],
                        gauss_cache_hits=total_state.gauss_rule_cache_hits[],
                        gauss_cache_misses=total_state.gauss_rule_cache_misses[],
                        gauss_interval_operations=total_state.gauss_interval_operations[],
                        ring_interval_operations=total_state.ring_interval_operations[],
                        joint_reference_kernel_calls=local_total_helper_kernel_calls-helper_calls_before,
                        max_kernel_calls=max_calls))
                result_dir=joinpath(result_leaf,"result_data");mkpath(result_dir)
                capture_path=joinpath(result_dir,"far_failure_numeric_$(getpid())_$(time_ns()).jls")
                ispath(capture_path) && error("joint far-total-error numeric capture path collision")
                open(capture_path,"w") do io
                    Serialization.serialize(io,payload);flush(io)
                end
                capture_sha256=_g2_global_diag_result_file_sha256(capture_path)
                println("FAR_FAILURE_NUMERIC_CAPTURE path=",capture_path," sha256=",capture_sha256);flush(stdout)
                rect_timing && println("LCFS_EXTERIOR_FAR_RECT_TIMING phase=failed ray=$(prep.target_index) cell=$(cell.native_cell) response_inclusive_ns=$(local_total_response_elapsed_ns) joint_reference_helper_ns=$(local_total_helper_elapsed_ns) response_non_helper_ns=$(max(UInt64(0),local_total_response_elapsed_ns-local_total_helper_elapsed_ns))")
                rect_timing && flush(stdout)
                return (status=:joint_total_error_unresolved,target_index=prep.target_index,
                    native_cell=cell.native_cell,reason=result.reason,
                    total_error_E_ratio=check_value(:E_ratio,:typed_absent),
                    total_error_G_ratio=check_value(:G_ratio,:typed_absent),
                    numeric_capture=(path=capture_path,sha256=capture_sha256),calls=total_calls[])
            end
            result.status===:evaluated || error("actual far-cell helper failed: ray=$(prep.target_index) cell=$(cell.native_cell) status=$(result.status) detail=$(repr(result))")
            result.kernel_calls+local_total_helper_kernel_calls-helper_calls_before==total_calls[]-before || error(
                "adaptive helper plus joint E/G reference ring-call accounting mismatch")
            fixed_attempt_calls=sum((a.kernel_calls for a in result.fixed_attempts);init=0)
            subdivision_attempt_calls=sum((a.kernel_calls for a in result.subdivision_attempts);init=0)
            recorded_attempt_calls=fixed_attempt_calls+subdivision_attempt_calls
            recorded_attempt_calls==result.kernel_calls || error("fixed plus fallback attempt metadata does not account for helper calls")
            fixed_order_attempt_ring_calls+=fixed_attempt_calls
            adaptive_subdivision_ring_calls+=subdivision_attempt_calls
            fixed_attempt_count+=length(result.fixed_attempts)
            fallback_attempt_count+=length(result.subdivision_attempts)
            if result.fallback_used
                fallback_cell_response_count+=1
                fallback_response_total_ring_calls+=result.kernel_calls
                local_fallback_cells+=1;local_fallback_attempts+=length(result.subdivision_attempts)
                depth=result.subdivision_depth
                push!(local_fallback_depths,depth);push!(local_fallback_orders,result.order)
                fallback_depth_counts[depth]=get(fallback_depth_counts,depth,0)+1
                fallback_order_counts[result.order]=get(fallback_order_counts,result.order,0)+1
                result.q1_parent_bounds==cell.bounds && result.q1_parent_columns==cell.columns &&
                    result.q1_parent_basis_mapping===:original_cell_Q1_UV ||
                    error("adaptive fallback response lost the original parent Q1 mapping")
            else
                fixed_cell_response_count+=1;local_fixed_cells+=1
                result.subdivision_depth==0 && isempty(result.subdivision_attempts) ||
                    error("fixed-order response reported inconsistent fallback metadata")
            end
            push!(processed_far_cell_ids,cell.native_cell)
            E .+= result.E;G .+= result.G;error_entries .+= result.E_error_bound
            farfield .+= result.E*prep.current
            if check_total_error
                check=result.joint_total_error_check;total=check.total
                local_total_entries+=1;total_error_entries+=1
                active=Tuple(c for c in cell.columns if c>0)
                total.E_total_error_bound_columns==active || error("compact total-error E columns differ from parent Q1 columns")
                total_local_E_ratio=max(total_local_E_ratio,check.E_ratio)
                total_local_G_ratio=max(total_local_G_ratio,check.G_ratio)
                joined=F._ccp_q1_lcfs_far_rect_total_error_interval_join!(total_stream,prep.current;
                    action=:accumulate,contribution=(prep=(target_index=prep.target_index,),cell=cell,response=result,total=total))
                joined.status===:accumulated_far_total_error_interval || error(
                    "far total-error stream accumulation unavailable: ray=$(prep.target_index) cell=$(cell.native_cell) detail=$(repr(joined))")
            end
            for component in 1:2
                farbound[component]+=sum(abs(prep.current[c])*result.E_error_bound[component,c]
                    for c in eachindex(prep.current))
                for c in cell.columns
                    if c>0
                        qnorm=F.norm(result.E[:,c]);bnorm=F.norm(result.E_error_bound[:,c])
                        qnorm==0 && bnorm>0 && error("nonzero far-cell bound with zero Q1 field column")
                        ratio=qnorm==0 ? 0.0 : bnorm/qnorm
                        max_local_ratio=max(max_local_ratio,ratio)
                    end
                end
            end
            push!(orders,result.order)
            if check_q32 && !control_done
                rect=(a0=cell.bounds[1],a1=cell.bounds[2],z0=cell.bounds[3],z1=cell.bounds[4],columns=cell.columns)
                bound32,_=F._ccp_q1_green_cell_bound(prep.target,rect,32,mu0)
                qrect(n,calls,budget)=begin
                    nodes,weights=F._ccp_q1_green_gauss(n);Q=zeros(Float64,2,length(prep.core_ids))
                    for ir in 1:n,iz in 1:n
                        u=nodes[ir];v=nodes[iz]
                        calls[]<budget || error("Q32/Q64 control would exceed shared ring-kernel budget")
                        calls[]+=1
                        ring=F._ccp_ring_unit_field_RZ(prep.target[1],prep.target[2],
                            cell.bounds[1]+(cell.bounds[2]-cell.bounds[1])*u,
                            cell.bounds[3]+(cell.bounds[4]-cell.bounds[3])*v,mu0)
                        w=(cell.bounds[2]-cell.bounds[1])*(cell.bounds[4]-cell.bounds[3])*weights[ir]*weights[iz]
                        phi=((1-u)*(1-v),u*(1-v),(1-u)*v,u*v)
                        for k in 1:4
                            c=cell.columns[k];c==0 && continue
                            Q[1,c]+=w*phi[k]*ring[1];Q[2,c]+=w*phi[k]*ring[2]
                        end
                    end
                    Q
                end
                Q32=qrect(32,total_calls,max_calls);Q64=qrect(64,total_calls,max_calls)
                f32=Q32*prep.current;f64=Q64*prep.current
                for component in 1:2
                    b=sum(abs(prep.current[c])*bound32[component] for c in cell.columns if c>0)
                    abs(f64[component]-f32[component])<=b+64eps(Float64)*max(abs(f32[component]),1.0) ||
                        error("actual-ray Q32 to Q64 control escaped order-32 analytic bound")
                    max_q32_q64_over_bound=max(max_q32_q64_over_bound,
                        abs(f64[component]-f32[component])/max(b,floatmin(Float64)))
                end
                q32_control_count[]+=1
                control_done=true
            end
            total_calls[]>before || error("rectangle helper did not account for ring-kernel calls")
        end
        Tuple(processed_far_cell_ids)==expected_far_cell_ids || error(
            "strict complete-far-cell coverage failed for ray=$(prep.target_index): expected=$(length(expected_far_cell_ids)) evaluated=$(length(processed_far_cell_ids))")
        check_q32 && !control_done && error("actual ray lacks a complete far-cell Q32/Q64 control")
        bound_norm=F.norm(farbound);field_norm=F.norm(farfield)
        bound_norm<=exact_limit*field_norm || error(
            "aggregate far-field bound unresolved due cancellation: bound=$bound_norm field=$field_norm")
        aggregate_ratio=field_norm==0 ? (bound_norm==0 ? 0.0 : error(
            "nonzero aggregate far-field bound with zero far field")) : bound_norm/field_norm
        total_E_weighted_bound_norm=0.0;total_E_weighted_ratio=0.0
        total_E_interval_error_ratio=0.0;total_E_consumer_interval_ratio=0.0;total_G_interval_error_ratio=0.0
        if check_total_error
            selected_cols=(2prep.target_index-1):(2prep.target_index)
            joined=F._ccp_q1_lcfs_far_rect_total_error_interval_join!(total_stream,prep.current;
                action=:finalize,farfield=farfield,consumer_field=E*prep.current,
                selected_target_G=G[:,selected_cols],exact_relative_limit=exact_limit,
                selected_G_relative_tolerance=rtol)
            joined.status===:evaluated_far_total_error_interval_join || error(
                "outward aggregate far E/G error gate failed: $(get(joined,:reason,:unknown))")
            nonlocal_G_columns=Tuple(j for j in 1:128 if !(j in selected_cols))
            all(j->iszero(G[1,j]) && iszero(G[2,j]),nonlocal_G_columns) || error(
                "fixed far-cell G accumulated outside the selected target coordinate pair")
            total_G_error_bound[:,selected_cols].=joined.selected_target_G_error_bound
            local_total_G_column_checks==local_total_attempt_entries || error(
                "not every accepted far entry passed complete G column coverage")
            total_E_weighted_bound_norm=joined.weighted_unsigned_E_error_bound_norm
            total_E_weighted_ratio=joined.weighted_E_ratio
            total_E_interval_error_ratio=joined.per_cell_farfield_E_interval_ratio
            total_E_consumer_interval_ratio=joined.E_times_current_interval_ratio
            total_G_interval_error_ratio=joined.selected_target_G_interval_ratio
            total_local_E_ratio<=exact_limit && total_local_G_ratio<=rtol || error(
                "joint per-cell total-error acceptance failed: ray=$(prep.target_index) E_ratio=$total_local_E_ratio E_limit=$exact_limit G_ratio=$total_local_G_ratio G_limit=$rtol")
        end
        (target_index=prep.target_index,E=E,G=G,farfield=farfield,farbound=farbound,
            aggregate_ratio=aggregate_ratio,orders=Tuple(orders),calls=total_calls[],
            total_error_enabled=check_total_error,total_error_entries=local_total_entries,
            total_error_reference_ring_points=local_total_points,
            total_error_orders=Tuple(sort!(collect(total_orders_used))),
            total_error_local_E_ratio=total_local_E_ratio,total_error_local_G_ratio=total_local_G_ratio,
            total_error_weighted_E_bound_norm=total_E_weighted_bound_norm,
            total_error_weighted_E_ratio=total_E_weighted_ratio,
            total_error_E_interval_ratio=total_E_interval_error_ratio,
            total_error_E_consumer_interval_ratio=total_E_consumer_interval_ratio,
            total_error_G_interval_ratio=total_G_interval_error_ratio,
            total_error_G_column_coverage=check_total_error ? :all_128_fixed_far_columns : :not_run,
            total_error_G_structural_zero_columns=check_total_error ?
                Tuple(j for j in 1:128 if !(j in ((2prep.target_index-1):(2prep.target_index)))) : (),
            total_error_G_error_bound=check_total_error ? total_G_error_bound : :typed_absent,
            total_error_E_lower=check_total_error ? total_stream.E_lower : :typed_absent,
            total_error_E_upper=check_total_error ? total_stream.E_upper : :typed_absent,
            total_error_gauss_cache_hits=check_total_error ? total_state.gauss_rule_cache_hits[] : 0,
            total_error_gauss_cache_misses=check_total_error ? total_state.gauss_rule_cache_misses[] : 0,
            total_error_gauss_interval_operations=check_total_error ? total_state.gauss_interval_operations[] : 0,
            total_error_ring_interval_operations=check_total_error ? total_state.ring_interval_operations[] : 0,
            total_error_total_interval_operations=check_total_error ? total_state.gauss_interval_operations[]+total_state.ring_interval_operations[] : 0,
            response_inclusive_elapsed_ns=local_total_response_elapsed_ns,
            joint_reference_helper_elapsed_ns=local_total_helper_elapsed_ns,
            response_non_helper_elapsed_ns=max(UInt64(0),local_total_response_elapsed_ns-local_total_helper_elapsed_ns),
            eligible_far_cell_count=length(expected_far_cell_ids),
            evaluated_far_cell_count=length(processed_far_cell_ids),strict_far_cell_coverage=true,
            fallback_cell_response_count=local_fallback_cells,
            fallback_attempt_count=local_fallback_attempts,fixed_cell_response_count=local_fixed_cells,
            fallback_depths=Tuple(local_fallback_depths),fallback_orders=Tuple(local_fallback_orders))
    end

    function actual_ray_preparation(ray)
        target=base_geometry.coordinates_RZ_m[ray]
        ray_near_ids=collect(c.native_cell for c in cells if
            first(F._ccp_q1_lcfs_target_cell_distance(target,c.bounds))<=
            last(F._ccp_q1_lcfs_target_cell_distance(target,c.bounds)))
        merge(base_prep,(target=target,target_index=ray,near_target_cell_ids=ray_near_ids))
    end
    base=actual_ray_preparation(base_prep.target_index)
    total_error_attempt_entries=Ref(0)
    replay_spec=get(ENV,"FUSION_G2_PRECHECK_FAR_TOTAL_ERROR_REPLAY_CELL","")
    if !isempty(replay_spec)
        total_error || error("targeted joint E/G replay requires FUSION_G2_PRECHECK_FAR_TOTAL_ERROR_64=1")
        parts=split(replay_spec,",")
        length(parts)==3 || error("targeted replay cell must be target_index,native_i,native_j")
        target_index=tryparse(Int,parts[1]);native_i=tryparse(Int,parts[2]);native_j=tryparse(Int,parts[3])
        target_index!==nothing && 1<=target_index<=64 && native_i!==nothing && native_i>0 &&
            native_j!==nothing && native_j>0 || error("invalid targeted joint E/G replay selector")
        replay_cell_index=findfirst(c->c.native_cell==(native_i,native_j),cells)
        replay_cell_index===nothing && error("targeted replay native far cell is absent from the prepared cell inventory")
        replay_prep=actual_ray_preparation(target_index)
        Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned","exterior_far_rect_joint_EG_actual_entry_fixture.jl"))
        replay=Base.invokelatest(Main.test_far_rect_joint_EG_actual_entry,F,replay_prep,
            cells[replay_cell_index];max_kernel_calls=max_calls)
        replay_field(k,default)=hasproperty(replay,k) ? getproperty(replay,k) : default
        replay_summary=(status=replay.status,reason=replay_field(:reason,:none),
            target_index=replay_field(:target_index,target_index),native_cell=replay_field(:native_cell,(native_i,native_j)),
            order=replay_field(:order,:typed_absent),subdivision_depth=replay_field(:subdivision_depth,:typed_absent),
            E_ratio=replay_field(:E_ratio,:typed_absent),G_ratio=replay_field(:G_ratio,:typed_absent),
            attempt_count=replay_field(:attempt_count,0),kernel_calls=replay_field(:kernel_calls,0))
        return (status=replay.status===:joint_far_cell_EG_enclosed ? :actual_candidate_one_cell_joint_EG_replay : :joint_total_error_refinement_needed,
            reason=replay_field(:reason,:targeted_joint_total_error_replay_not_enclosed),
            target_index=target_index,native_cell=(native_i,native_j),replay_result=replay_summary,
            total_ring_kernel_calls=replay.kernel_calls,final_spent_ring_kernel_calls=replay.kernel_calls,
            remaining_shared_kernel_budget=max_calls-replay.kernel_calls,total_error_enabled=true,
            physical_validation=false,global_closure=false)
    end
    base_eval=evaluate(base;check_q32=false)
    ray_evaluations=Any[]
    for ray in 1:actual_target_count
        rayprep=actual_ray_preparation(ray)
        ray_call_start=total_calls[]
        if rect_timing
            println("LCFS_EXTERIOR_FAR_RECT_RAY phase=begin ray=$ray/64 calls_before=$(ray_call_start)");flush(stdout)
        end
        ray_eval=evaluate(rayprep;check_q32=true,check_total_error=total_error)
        if hasproperty(ray_eval,:status) && ray_eval.status===:joint_total_error_unresolved
            return (status=:joint_total_error_refinement_needed,reason=ray_eval.reason,
                target_index=ray_eval.target_index,failing_native_cell=ray_eval.native_cell,
                total_error_E_ratio=ray_eval.total_error_E_ratio,
                total_error_G_ratio=ray_eval.total_error_G_ratio,numeric_capture=ray_eval.numeric_capture,
                actual_target_count=64,per_cell_basis_columns=4,q32_q64_control_target_count=q32_control_count[],
                total_ring_kernel_calls=total_calls[],final_spent_ring_kernel_calls=total_calls[],
                remaining_shared_kernel_budget=max_calls-total_calls[],
                total_error_64_enabled=true,total_error_64_entries=total_error_entries,
                total_error_64_attempt_entries=total_error_attempt_entries[],
                total_error_64_reference_ring_points=total_error_points,
                total_error_64_distinct_orders=Tuple(sort!(collect(total_error_orders))),
                total_error_64_gauss_cache_hits=total_state.gauss_rule_cache_hits[],
                total_error_64_gauss_cache_misses=total_state.gauss_rule_cache_misses[],
                total_error_64_gauss_interval_operations=total_state.gauss_interval_operations[],
                total_error_64_ring_interval_operations=total_state.ring_interval_operations[],
                total_error_64_total_interval_operations=total_state.gauss_interval_operations[]+total_state.ring_interval_operations[],
                E_bound_scope=:complete_native_plasma_only_far_cells_only,G_error_bound=:typed_absent,
                physical_validation=false,global_closure=false)
        end
        ray_calls=ray_eval.calls-ray_call_start
        if total_error
            result_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
            ray_dir=joinpath(result_leaf,"result_data","far_rays");mkpath(ray_dir)
            ray_path=joinpath(ray_dir,"ray_$(lpad(string(ray),2,"0")).jls")
            ispath(ray_path) && error("refusing to replace actual far ray numeric result")
            ray_record=(schema="actual-far-ray-EG-result-v1",identity=capture_identity,
                target=rayprep.target,core_ids=collect(base_prep.core_ids),
                E=ray_eval.E,G=ray_eval.G,E_lower=ray_eval.total_error_E_lower,
                E_upper=ray_eval.total_error_E_upper,G_error_bound=ray_eval.total_error_G_error_bound,
                coverage=(target_index=ray,eligible_cell_count=ray_eval.eligible_far_cell_count,
                    evaluated_cell_count=ray_eval.evaluated_far_cell_count,
                    strict_match=ray_eval.strict_far_cell_coverage,
                    G_columns=ray_eval.total_error_G_column_coverage),
                counters=(ring_calls_this_ray=ray_calls,ring_calls_accumulated=ray_eval.calls),
                physical_validation=false,global_closure=false)
            open(ray_path,"w") do io;Serialization.serialize(io,ray_record);flush(io);end
            println("ACTUAL_FAR_RAY_NUMERIC_RESULT ray=",ray," path=",ray_path,
                " sha256=",_g2_global_diag_result_file_sha256(ray_path));flush(stdout)
        end
        if rect_timing
            println("LCFS_EXTERIOR_FAR_RECT_TIMING phase=ray ray=$ray/64 response_inclusive_ns=$(ray_eval.response_inclusive_elapsed_ns) joint_reference_helper_ns=$(ray_eval.joint_reference_helper_elapsed_ns) response_non_helper_ns=$(ray_eval.response_non_helper_elapsed_ns)")
            flush(stdout)
        end
        push!(ray_evaluations,(target_index=ray,eligible_far_cell_count=ray_eval.eligible_far_cell_count,
            evaluated_far_cell_count=ray_eval.evaluated_far_cell_count,strict_far_cell_coverage=ray_eval.strict_far_cell_coverage,
            fallback_cell_response_count=ray_eval.fallback_cell_response_count,
            fallback_attempt_count=ray_eval.fallback_attempt_count,fixed_cell_response_count=ray_eval.fixed_cell_response_count,
            fallback_depths=ray_eval.fallback_depths,fallback_orders=ray_eval.fallback_orders,
            ring_kernel_calls=ray_calls,aggregate_error_ratio=ray_eval.aggregate_ratio,
            total_error_entries=ray_eval.total_error_entries,
            total_error_reference_ring_points=ray_eval.total_error_reference_ring_points,
            total_error_orders=ray_eval.total_error_orders,
            total_error_local_E_ratio=ray_eval.total_error_local_E_ratio,
            total_error_local_G_ratio=ray_eval.total_error_local_G_ratio,
            total_error_weighted_E_bound_norm=ray_eval.total_error_weighted_E_bound_norm,
            total_error_weighted_E_ratio=ray_eval.total_error_weighted_E_ratio,
            total_error_E_interval_ratio=ray_eval.total_error_E_interval_ratio,
            total_error_E_consumer_interval_ratio=ray_eval.total_error_E_consumer_interval_ratio,
            total_error_G_interval_ratio=ray_eval.total_error_G_interval_ratio,
            total_error_G_column_coverage=ray_eval.total_error_G_column_coverage,
            total_error_G_structural_zero_columns=ray_eval.total_error_G_structural_zero_columns,
            total_error_G_error_bound=ray_eval.total_error_G_error_bound,
            total_error_gauss_cache_hits=ray_eval.total_error_gauss_cache_hits,
            total_error_gauss_cache_misses=ray_eval.total_error_gauss_cache_misses,
            total_error_gauss_interval_operations=ray_eval.total_error_gauss_interval_operations,
            total_error_ring_interval_operations=ray_eval.total_error_ring_interval_operations,
            total_error_total_interval_operations=ray_eval.total_error_total_interval_operations))
        if rect_timing
            println("LCFS_EXTERIOR_FAR_RECT_RAY phase=completed ray=$ray/64 eligible=$(ray_eval.eligible_far_cell_count) evaluated=$(ray_eval.evaluated_far_cell_count) calls=$ray_calls aggregate_error_ratio=$(ray_eval.aggregate_ratio) fallback_cells=$(ray_eval.fallback_cell_response_count)");flush(stdout)
        end
    end
    length(ray_evaluations)==64 && Tuple(x.target_index for x in ray_evaluations)==Tuple(1:64) ||
        error("actual 64-ray control did not evaluate each ray exactly once in strict order")
    all(x->x.strict_far_cell_coverage,ray_evaluations) ||
        error("one or more actual rays failed strict eligible far-cell coverage")
    if total_error
        all(x->x.total_error_G_column_coverage===:all_128_fixed_far_columns &&
            size(x.total_error_G_error_bound)==(2,128) && all(isfinite,x.total_error_G_error_bound) &&
            all(>=(0),x.total_error_G_error_bound),ray_evaluations) ||
            error("whole-64 far G structural/error coverage is incomplete")
    end
    if total_error
        total_error_entries==175_059 || error(
            "accepted unique far total-error inventory mismatch: entries=$total_error_entries expected=175059")
        total_error_attempt_entries[]>=total_error_entries || error(
            "far total-error attempt count is below accepted unique coverage")
        total_error_points>=12_093_120 && total_error_points<=12_500_000 || error("far total-error attempt reference-point budget mismatch: points=$total_error_points")
        total_state.reference_ring_points[]==total_error_points || error("shared reference-point counter differs from streamed attempt point total")
        total_state.gauss_rule_cache_misses[]==length(total_error_orders) || error(
            "true Gauss cache misses do not equal the distinct accepted orders")
        total_state.gauss_rule_cache_hits[]+total_state.gauss_rule_cache_misses[]==total_error_attempt_entries[] ||
            error("Gauss cache hit/miss counters do not account for every far-helper attempt")
        total_calls[]<=40_000_000 && total_state.ring_interval_operations[]<=5_200_000_000 &&
            total_state.reference_ring_points[]<=12_500_000 &&
            total_state.gauss_interval_operations[]+total_state.ring_interval_operations[]<=5_208_000_000 ||
            error("actual far total-error shared budget exceeded")
    end

    dtarget=base_prep.dtarget
    target_G_columns=(2*base_prep.target_index-1):(2*base_prep.target_index)
    analytic=base_eval.E*base_prep.dcurrent+
        view(base_eval.G,:,target_G_columns)*[dtarget[1],dtarget[2]]
    fd_errors=Float64[];fd_vectors=Vector{Float64}[]
    for h in (h1,h2)
        plus_prep=safe_preparations[h];minus_prep=safe_preparations[-h]
        plus_geo=safe_geometries[h];minus_geo=safe_geometries[-h]
        plus_geo.first_outward_crossing_signature===base_geometry.first_outward_crossing_signature ||
            error("plus actual geometry signature changed at h=$h")
        minus_geo.first_outward_crossing_signature===base_geometry.first_outward_crossing_signature ||
            error("minus actual geometry signature changed at h=$h")
        for candidate_prep in (plus_prep,minus_prep)
            candidate_prep.support_ownership_counts==base_prep.support_ownership_counts ||
                error("far-cell support ownership changed at h=$h")
            candidate_prep.near_target_cell_ids==base_prep.near_target_cell_ids ||
                error("selected-ray near-target set changed at h=$h")
            candidate_prep.polygon_triangulation_signature==base_prep.polygon_triangulation_signature ||
                error("polygon triangulation signature changed at h=$h")
            candidate_prep.clipping_signature==base_prep.clipping_signature ||
                error("cut-cell clipping signature changed at h=$h")
            candidate_prep.quadrature_partition_signature==base_prep.quadrature_partition_signature ||
                error("near-target red-chart signature changed at h=$h")
            candidate_prep.refined_triangle_count==base_prep.refined_triangle_count ||
                error("near-target red-chart leaf count changed at h=$h")
        end
        plus=evaluate(plus_prep);minus=evaluate(minus_prep)
        fd=(plus.farfield-minus.farfield)/(2h)
        error_norm=F.norm(fd-analytic);limit=5e-6*F.norm(analytic)+5e-11
        error_norm<=limit || error("actual target-G h=$h vector FD error $error_norm exceeds $limit")
        push!(fd_errors,error_norm);push!(fd_vectors,fd)
    end
    pair_error=F.norm(fd_vectors[1]-fd_vectors[2]);pair_limit=5e-6*F.norm(analytic)+5e-11
    pair_error<=pair_limit || error("actual target-G h/h2 pair disagreement $pair_error exceeds $pair_limit")

    # Negative control: a zero budget must fail before its first ring call.
    first_far=findfirst(cell->!isempty(cell.pieces) &&
        all(piece->hasproperty(piece.lineage,:source) && piece.lineage.source===:plasma_only_native_cell,
            cell.pieces) && !(cell.native_cell in base.near_target_cell_ids),cells)
    first_far===nothing && error("actual candidate has no eligible complete far plasma cell")
    negative=F._ccp_q1_lcfs_rectangular_far_response(base,cells[first_far],Ref(0),0;
        relative_error_tolerance=rtol)
    negative.status===:typed_absent && negative.reason===:far_cell_kernel_budget_exceeded ||
        error("zero-call budget negative control did not fail closed")
    (status=:actual_candidate_64ray_far_cell_E_G_diagnostic,
        target_scope=:actual_candidate_LCFS_rays,actual_target_count=actual_target_count,
        q1_columns=length(base.core_ids),per_cell_basis_columns=4,total_ring_kernel_calls=total_calls[],
        q32_q64_control_target_count=q32_control_count[],
        max_local_bound_to_Q_magnitude_ratio=max_local_ratio,
        max_actual_ray_Q32_to_Q64_over_analytic_order32_bound=max_q32_q64_over_bound,
        strict_64_ray_far_cell_coverage=true,
        per_ray_far_cell_coverage=Tuple((target_index=x.target_index,
            eligible_cell_count=x.eligible_far_cell_count,evaluated_cell_count=x.evaluated_far_cell_count,
            strict_match=x.strict_far_cell_coverage,fallback_cell_response_count=x.fallback_cell_response_count,
            fallback_attempt_count=x.fallback_attempt_count,fallback_depths=x.fallback_depths,
            fallback_orders=x.fallback_orders,ring_kernel_calls=x.ring_kernel_calls,
            aggregate_error_ratio=x.aggregate_error_ratio) for x in ray_evaluations),
        fallback_statistics_scope=:base_plus_all_64_rays_plus_h_h2_endpoints,
        fixed_order_cell_response_count=fixed_cell_response_count,
        adaptive_fallback_cell_response_count=fallback_cell_response_count,
        fixed_order_attempt_count=fixed_attempt_count,adaptive_subdivision_attempt_count=fallback_attempt_count,
        adaptive_fallback_response_total_ring_kernel_calls=fallback_response_total_ring_calls,
        fixed_order_attempt_ring_kernel_calls=fixed_order_attempt_ring_calls,
        adaptive_subdivision_ring_kernel_calls=adaptive_subdivision_ring_calls,
        adaptive_fallback_depth_histogram=Tuple((depth=d,count=fallback_depth_counts[d])
            for d in sort!(collect(keys(fallback_depth_counts)))),
        adaptive_fallback_accepted_order_histogram=Tuple((order=n,count=fallback_order_counts[n])
            for n in sort!(collect(keys(fallback_order_counts)))),
        actual_target_G_fd_error_h=fd_errors[1],actual_target_G_fd_error_h2=fd_errors[2],
        actual_target_G_fd_pair_error=pair_error,relative_tolerance=rtol,
        exact_relative_limit=exact_limit,budget_negative_control=negative.reason,
        remaining_shared_kernel_budget=max_calls-total_calls[],final_spent_ring_kernel_calls=total_calls[],
        E_bound_scope=:complete_native_plasma_only_far_cells_only,
        far_G_structural_mapping=total_error ? :complete_64_ray_far_2x128_structural_mapping : :typed_absent,
        G_error_bound_scope=total_error ? :selected_target_pair_interval_plus_exact_zero_other_columns : :not_run,
        total_error_64_G_column_coverage=total_error ? :all_64_rays_all_128_columns : :not_run,
        total_error_64_enabled=total_error,total_error_64_entries=total_error_entries,
        total_error_64_attempt_entries=total_error_attempt_entries[],
        total_error_64_reference_ring_points=total_error_points,
        total_error_64_distinct_orders=Tuple(sort!(collect(total_error_orders))),
        total_error_64_gauss_cache_hits=total_error ? total_state.gauss_rule_cache_hits[] : 0,
        total_error_64_gauss_cache_misses=total_error ? total_state.gauss_rule_cache_misses[] : 0,
        total_error_64_gauss_interval_operations=total_error ? total_state.gauss_interval_operations[] : 0,
        total_error_64_ring_interval_operations=total_error ? total_state.ring_interval_operations[] : 0,
        total_error_64_total_interval_operations=total_error ? total_state.gauss_interval_operations[]+total_state.ring_interval_operations[] : 0,
        G_error_bound=:typed_absent,floating_point_roundoff_bound=:missing,
        physical_validation=false,global_closure=false)
end

function test_native_critical_points_parser(F)
    R=(0.1,0.2,0.3); Z=(-1.0,0.0,1.0); psi_boundary=1.0
    # Mirrors the pre-patch saved current_support, which has no critical_points
    # field. This is a parser compatibility fixture, not a physical result.
    legacy_support=(status="present",reason="same_final_psi_profile_native_grid_Jphi")
    absent=F._freegs_parse_native_critical_points(
        hasproperty(legacy_support,:critical_points) ? legacy_support.critical_points : nothing,
        R,Z,psi_boundary)
    @test absent==(status=:typed_absent,reason=:actual_critical_points_not_emitted)

    # Static format fixture matches the new producer schema. It does not claim
    # these synthetic points came from FreeGS or from an accepted equilibrium.
    record=Dict{Symbol,Any}(:R_m=>0.2,:Z_m=>0.0,:psi_wb_per_rad=>2.0,:nearest_native_id=>5)
    xrecord=Dict{Symbol,Any}(:R_m=>0.1,:Z_m=>1.0,:psi_wb_per_rad=>1.5,:nearest_native_id=>3)
    raw=Dict{Symbol,Any}(:method=>"freegs.critical.find_critical",
        :flux_source=>"sampled_eq.psi_native_total_grid",
        :core_mask_method=>"freegs.critical.core_mask",
        :xpoint_neighborhood_rule=>"block_nearest_3x3_then_restore_psiN_lt_1_without_connectivity_recheck",
        :opoints=>[record],:xpoints=>[xrecord],
        :core_mask_psi_axis_wb_per_rad=>2.0,
        :core_mask_psi_boundary_wb_per_rad=>psi_boundary)
    raw_with=(key,value)->merge(raw,Dict{Symbol,Any}(key=>value))
    parsed=F._freegs_parse_native_critical_points(raw,R,Z,psi_boundary)
    @test parsed.status===:present
    @test parsed.method===:freegs_critical_find_critical
    @test parsed.flux_source===:sampled_eq_psi_native_total_grid
    @test parsed.core_mask_method===:freegs_critical_core_mask
    @test parsed.opoints==((R_m=0.2,Z_m=0.0,psi_wb_per_rad=2.0,nearest_native_id=5),)
    @test parsed.xpoints==((R_m=0.1,Z_m=1.0,psi_wb_per_rad=1.5,nearest_native_id=3),)
    @test parsed.xpoint_neighborhood_rule===
        :block_nearest_3x3_then_restore_psiN_lt_1_without_connectivity_recheck
    @test parsed.continuous_component_membership===:not_validated

    # Finite Newton coordinates may lie outside the axis domain; the producer's
    # core_mask consumes them through nearest-cell argmin/clip semantics.
    outside_record=Dict{Symbol,Any}(:R_m=>0.05,:Z_m=>0.0,:psi_wb_per_rad=>2.0,:nearest_native_id=>2)
    outside=F._freegs_parse_native_critical_points(
        raw_with(:opoints,[outside_record]),R,Z,psi_boundary)
    @test outside.opoints==((R_m=0.05,Z_m=0.0,psi_wb_per_rad=2.0,nearest_native_id=2),)
    @test isfinite(outside.opoints[1].R_m)
    outside_nearest_id=(argmin(abs.(collect(R) .- outside.opoints[1].R_m))-1)*length(Z)+
        argmin(abs.(collect(Z) .- outside.opoints[1].Z_m))
    @test outside.opoints[1].nearest_native_id==outside_nearest_id==2
    @test_throws ArgumentError F._freegs_parse_native_critical_points(
        raw_with(:opoints,[merge(record,Dict{Symbol,Any}(:R_m=>NaN))]),R,Z,psi_boundary)
    @test_throws ArgumentError F._freegs_parse_native_critical_points(
        raw_with(:opoints,[merge(record,Dict{Symbol,Any}(:R_m=>Inf))]),R,Z,psi_boundary)
    @test_throws ArgumentError F._freegs_parse_native_critical_points(
        raw_with(:opoints,[merge(record,Dict{Symbol,Any}(:nearest_native_id=>6))]),R,Z,psi_boundary)
    @test_throws ArgumentError F._freegs_parse_native_critical_points(
        raw_with(:core_mask_psi_axis_wb_per_rad,2.1),R,Z,psi_boundary)
    @test_throws ArgumentError F._freegs_parse_native_critical_points(
        raw_with(:core_mask_psi_boundary_wb_per_rad,0.9),R,Z,psi_boundary)
    true
end

function test_hagenow_source_response_reader(F)
    nr=nz=3; boundary=[1,2,3,4,6,7,8,9]; core=[5]
    values=reshape(collect(1.0:8.0),length(boundary),length(core))
    bytes=Vector{UInt8}(reinterpret(UInt8,htol.(reinterpret(UInt64,vec(values)))))
    metadata=(status="present",file_name="hagenow_source_response.f64",
        encoding="ieee754_float64_little_endian_column_major",shape=[length(boundary),length(core)],
        byte_count=length(bytes),sha256=string(F._freegs_sha256_bytes(bytes)),
        boundary_native_ids=boundary,core_native_ids=core)
    grid=Tuple(Tuple(0.0 for _ in 1:nz) for _ in 1:nr)
    output(meta)=F.JSON3.write((native_gs_state=(status="present",
        plasma_psi_wb_per_rad=grid,hagenow_source_feedback=(source_response_matrix=meta,)),))
    absent=F.JSON3.write((native_gs_state=(status="present",),))
    mktempdir() do directory
        path=joinpath(directory,"hagenow_source_response.f64")
        write(path,bytes)
        parsed=F._freegs_read_hagenow_source_response(directory,output(metadata))
        @test parsed.values==values && parsed.bytes==bytes
        @test parsed.boundary_native_ids==boundary && parsed.core_native_ids==core
        @test parsed.encoding===:ieee754_float64_little_endian_column_major
        @test F._freegs_read_hagenow_source_response(directory,absent)===nothing
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,
            output(merge(metadata,(encoding="ieee754_float64_big_endian_column_major",))))
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,
            output(merge(metadata,(shape=[length(boundary),length(core)+1],))))
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,
            output(merge(metadata,(boundary_native_ids=reverse(boundary),))))
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,
            output(merge(metadata,(core_native_ids=Int[],shape=[length(boundary),0],byte_count=0))))
        rm(path)
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,output(metadata))
        write(path,bytes[1:end-8])
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,output(metadata))
        corrupt=copy(bytes);corrupt[1]⊻=0x01;write(path,corrupt)
        @test_throws ArgumentError F._freegs_read_hagenow_source_response(directory,output(metadata))
    end
end

function test_lcfs_dynamic_geometry_numeric(F;full_size=false)
    # Same cubic numeric-kernel sentinel on the default 25x27 grid or the
    # resource diagnostic 129x129 grid. The spline must preserve R-major/Z-fast
    # IDs and the connected core mask exactly.
    small_R=collect(range(2.0,full_size ? 6.0 : 5.0;length=full_size ? 129 : 25));
    small_Z=collect(range(-1.625,1.625;length=full_size ? 129 : 27))
    small_nr=length(small_R);small_nz=length(small_Z);small_n=small_nr*small_nz
    small_rx=2.5;small_ro=3.5
    small_f(r)=r^3/3-(small_ro+small_rx)*r^2/2+small_ro*small_rx*r
    small_psi_RZ=[small_f(r)-small_f(small_ro)+z^2 for r in small_R,z in small_Z]
    small_psi=Float64[small_psi_RZ[i,j] for i in 1:small_nr for j in 1:small_nz]
    small_span=small_f(small_rx)-small_f(small_ro)
    small_q_RZ=small_psi_RZ./small_span
    @test (full_size ? (small_nr==129 && small_nz==129) : small_nr!=small_nz) && small_span>0
    @test small_psi_RZ[findfirst(==(small_ro),small_R),findfirst(==(0.0),small_Z)]==0.0
    @test isapprox(small_q_RZ[findfirst(==(small_rx),small_R),findfirst(==(0.0),small_Z)],1.0;rtol=0,atol=4eps(Float64))
    small_blocked=falses(small_nr,small_nz);small_mask_RZ=falses(small_nr,small_nz)
    small_xi=findfirst(==(small_rx),small_R);small_xj=findfirst(==(0.0),small_Z)
    for i in max(1,small_xi-1):min(small_nr,small_xi+1),j in max(1,small_xj-1):min(small_nz,small_xj+1)
        small_blocked[i,j]=true
    end
    small_ai=findfirst(==(small_ro),small_R);small_aj=findfirst(==(0.0),small_Z)
    small_stack=Tuple{Int,Int}[(small_ai,small_aj)]
    while !isempty(small_stack)
        i,j=pop!(small_stack)
        1<=i<=small_nr && 1<=j<=small_nz && small_q_RZ[i,j]<1 &&
            !small_blocked[i,j] && !small_mask_RZ[i,j] || continue
        small_mask_RZ[i,j]=true
        for (ii,jj) in ((i+1,j),(i-1,j),(i,j+1),(i,j-1))
            1<=ii<=small_nr && 1<=jj<=small_nz && small_q_RZ[ii,jj]<1 &&
                !small_blocked[ii,jj] && !small_mask_RZ[ii,jj] && push!(small_stack,(ii,jj))
        end
    end
    for i in max(1,small_xi-1):min(small_nr,small_xi+1),j in max(1,small_xj-1):min(small_nz,small_xj+1)
        small_mask_RZ[i,j]=small_q_RZ[i,j]<1
    end
    small_mask=BitVector(vec(permutedims(small_mask_RZ)))
    small_axis_id=(small_ai-1)*small_nz+small_aj
    small_x_id=(small_xi-1)*small_nz+small_xj
    small_cp=(status=:present,method=:stationary_cubic_spline_gradient_hessian_v2,
        opoints=((R_m=small_ro,Z_m=0.0,nearest_native_id=small_axis_id),),
        xpoints=((R_m=small_rx,Z_m=0.0,nearest_native_id=small_x_id),))
    small_pressure_dofs=collect(4small_n+1:5small_n)
    small_state=zeros(5small_n)
    for k in 1:small_n
        small_state[4k-2]=1.0;small_state[4k]=small_psi[k]
        small_state[small_pressure_dofs[k]]=small_mask[k] ? 1.0 : 0.0
    end
    small_data=(gs_ready=true,critical_points=small_cp,support_psi=copy(small_psi),
        anchor_psi=copy(small_psi),Raxis=small_R,Zaxis=small_Z,
        Dr=F._ccp_native_spline_derivative(small_R),Dz=F._ccp_native_spline_derivative(small_Z),
        nr=small_nr,nz=small_nz,n=small_n,ndof=length(small_state),mask=small_mask,
        pressure_dofs=small_pressure_dofs)
    small_geometry=F._ccp_full_native_dynamic_geometry(small_data,small_state)
    @test small_geometry.status===:evaluated_dynamic_LCFS_geometry
    if small_geometry.status===:evaluated_dynamic_LCFS_geometry
        @test small_geometry.mask_event===:unchanged
        @test small_geometry.ray_rule===Symbol("64_ray_first_sampled_outward_psiN_1_bracket")
        @test small_geometry.candidate_total_psi_Wb_per_rad==small_psi
        @test maximum(abs,collect(small_geometry.axis_RZ_m).- [small_ro,0.0])<=2e-12
        @test maximum(abs,collect(small_geometry.boundary_RZ_m).- [small_rx,0.0])<=2e-12
        @test length(small_geometry.coordinates_RZ_m)==64
        # A one-ID baseline-mask perturb must be detected with the exact native ID.
        bad_small_mask=copy(small_mask);bad_small_mask[small_axis_id]=false
        bad_small=F._ccp_full_native_dynamic_geometry(merge(small_data,(mask=bad_small_mask,)),small_state)
        @test bad_small.status===:needs_rebuild
        @test bad_small.reason===:candidate_core_mask_changed
        @test bad_small.changed_native_ids==(small_axis_id,)
    end

    return true
end

@noinline Base.@nospecializeinfer function test_actual_lcfs_dynamic_geometry_component(F,@nospecialize(trace),@nospecialize(component))
    geometry_actual_started=time()
    geometry_actual_mark(label)=begin
        println("FREEGS_DYNAMIC_GEOMETRY_ACTUAL_",label," elapsed_s=",time()-geometry_actual_started,
            " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    end
    x=component.initial_state
    n=length(component.core_mask)
    # The real consumer may expose new geometry while keeping source-bound
    # pressure/current rows absent until the 64 source records are rebound.
    geometry_actual_mark("FIRST_CALLBACK_BEGIN")
    moving_profile=Base.invokelatest(component.lcfs_profile_current_trace,x;
        with_jacobian=true,dynamic_geometry=true)
    geometry_actual_mark("FIRST_CALLBACK_END")
    @test moving_profile.status===:typed_absent
    @test moving_profile.reason===:dynamic_geometry_only_profile_current_source_rebind_pending
    @test moving_profile.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry
    @test moving_profile.candidate_hash==component.candidate_hash
    @test moving_profile.fixed_geometry===false && moving_profile.fixed_source_mask===true
    @test moving_profile.source_fields_reused===false
    @test moving_profile.fields===nothing && moving_profile.residual===nothing && moving_profile.jacobian===nothing
    @test moving_profile.pressure_status===:typed_absent
    @test moving_profile.current_status===:typed_absent
    @test moving_profile.current_normal_trace===:typed_absent
    @test moving_profile.extra_solver_rows==0
    @test moving_profile.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    geometry=moving_profile.dynamic_geometry
    @test geometry.jacobian_columns===:psi_native_dofs_only
    geometry_actual_mark("IDS_EQUALITY_BEGIN")
    @test geometry.psi_global_dof_ids==Tuple(4k for k in 1:n)
    geometry_actual_mark("IDS_EQUALITY_END")
    @test geometry.fixed_PF_total_psi===true
    @test length(geometry.coordinates_RZ_m)==64 && length(geometry.normals_RZ)==64
    @test length(geometry.surface_quadrature_m2)==64
    @test size(geometry.coordinate_jacobian)==(128,n)
    @test size(geometry.normal_jacobian)==(128,n)
    @test size(geometry.surface_quadrature_jacobian)==(64,n)
    @test size(geometry.axis_coordinate_jacobian)==(2,n)
    @test size(geometry.axis_flux_jacobian)==(1,n)
    @test size(geometry.boundary_flux_jacobian)==(1,n)
    @test size(geometry.boundary_coordinate_jacobian)==(2,n)
    @test geometry.mask_event===:unchanged
    @test geometry.solver_rows_added==0 && !geometry.global_topology_closed && !geometry.physical_validation

    ray_vector(points)=Float64[q for point in points for q in point]
    function check_dynamic_fd(fd,analytic)
        scale=max(maximum(abs,fd;init=0.0),maximum(abs,analytic;init=0.0),1e-12)
        maximum(abs,fd-analytic;init=0.0)<=5e-5*scale
    end
    for a in 1:64
        @test isapprox(hypot(geometry.normals_RZ[a]...),1.0;rtol=0,atol=2e-12)
        dR=geometry.coordinates_RZ_m[a][1]-geometry.axis_RZ_m[1]
        dZ=geometry.coordinates_RZ_m[a][2]-geometry.axis_RZ_m[2]
        rho=hypot(dR,dZ);mu=(geometry.normals_RZ[a][1]*dR+geometry.normals_RZ[a][2]*dZ)/rho
        @test mu>0
        @test isapprox(geometry.surface_quadrature_m2[a],
            2pi*geometry.coordinates_RZ_m[a][1]*(rho/mu)*(2pi/64);rtol=2e-12,atol=2e-14)
    end

    # Two-sided finite differences of the same candidate's moving O/X,
    # axis/boundary, 64 roots, normals and 2πR ds map.
    motion_node=trace.data.current_support.critical_points.opoints[1].nearest_native_id
    primary_x_node=trace.data.current_support.critical_points.xpoints[1].nearest_native_id
    motion_span=abs(geometry.psi_boundary_Wb_per_rad-geometry.psi_axis_Wb_per_rad)
    motion_h=1e-6*motion_span
    motion_columns=((:O,motion_node),(:primary_X,primary_x_node))
    continuous_model=:plasma_spline_plus_exact_pf_potential_jet_v1
    optin_profile=Base.invokelatest(component.lcfs_profile_current_trace,x;
        with_jacobian=true,dynamic_geometry=true,continuous_field_model=continuous_model)
    @test optin_profile.status===:typed_absent
    @test optin_profile.reason===:composite_dynamic_current_requires_authored_pressure_domain
    @test optin_profile.field_model_id===continuous_model
    @test optin_profile.fixed_geometry===false && optin_profile.fixed_source_mask===true
    @test optin_profile.source_fields_reused===false && optin_profile.source_fd_anchors_preserved_separately
    @test optin_profile.fields===nothing && optin_profile.residual===nothing && optin_profile.jacobian===nothing
    @test optin_profile.pressure_status===:typed_absent && optin_profile.current_status===:typed_absent
    @test optin_profile.current_normal_trace===:typed_absent && optin_profile.extra_solver_rows==0
    @test optin_profile.fixed_geometry===false && optin_profile.fixed_source_mask===false
    @test optin_profile.source_fields_reused===false && optin_profile.solver_rows_added==0
    jet_geometry=optin_profile.dynamic_geometry
    @test jet_geometry.field_model_id===continuous_model
    @test jet_geometry.field_representation===:plasma_not_a_knot_spline_plus_unclipped_exact_PF_Green_jet
    @test jet_geometry.source_critical_point_method===:stationary_cubic_spline_gradient_hessian_v2
    @test jet_geometry.source_critical_point_role===:seed_only_rebound_on_composite_psi
    @test jet_geometry.source_fd_anchor_use===:unchanged_source_records_not_reused_as_continuous_fields
    @test jet_geometry.exact_PF_grid_node_checks.scope===:native_grid_nodes_only
    @test length(jet_geometry.candidate_total_psi_Wb_per_rad)==n && all(isfinite,jet_geometry.candidate_total_psi_Wb_per_rad)
    @test size(jet_geometry.coordinate_jacobian)==(128,n) && size(jet_geometry.normal_jacobian)==(128,n)
    @test size(jet_geometry.surface_quadrature_jacobian)==(64,n)
    @test jet_geometry.profile_endpoint_values==(axis=component.profile_law.psi_axis_wb_per_rad,
        boundary=component.profile_law.psi_boundary_wb_per_rad,
        delta=component.profile_law.psi_axis_wb_per_rad-component.profile_law.psi_boundary_wb_per_rad)
    @test jet_geometry.endpoint_definition_residual==(
        jet_geometry.profile_endpoint_values.axis-jet_geometry.psi_axis_Wb_per_rad,
        jet_geometry.profile_endpoint_values.boundary-jet_geometry.psi_boundary_Wb_per_rad)
    jet_motion_h=1e-6*abs(jet_geometry.psi_boundary_Wb_per_rad-jet_geometry.psi_axis_Wb_per_rad)
    for (motion_column,node_col) in motion_columns
        dynamic_plus_state=copy(x);dynamic_minus_state=copy(x)
        dynamic_plus_state[4node_col]+=motion_h
        dynamic_minus_state[4node_col]-=motion_h
        geometry_actual_mark("PLUS_MINUS_BEGIN")
        gplus=Base.invokelatest(component.lcfs_dynamic_geometry_trace,dynamic_plus_state)
        gminus=Base.invokelatest(component.lcfs_dynamic_geometry_trace,dynamic_minus_state)
        geometry_actual_mark("PLUS_MINUS_END")
        @test gplus.status===gminus.status===:evaluated_dynamic_LCFS_geometry
        @test gplus.candidate_total_psi_Wb_per_rad!=geometry.candidate_total_psi_Wb_per_rad
        if motion_column===:O
            @test gplus.axis_RZ_m!=geometry.axis_RZ_m
        else
            @test gplus.boundary_RZ_m!=geometry.boundary_RZ_m
        end
        @test ray_vector(gplus.coordinates_RZ_m)!=ray_vector(geometry.coordinates_RZ_m)
        @test ray_vector(gplus.normals_RZ)!=ray_vector(geometry.normals_RZ)
        @test collect(gplus.surface_quadrature_m2)!=collect(geometry.surface_quadrature_m2)
        @test all(isfinite,gplus.surface_quadrature_m2) && all(>(0),gplus.surface_quadrature_m2)
        geometry_actual_mark("FD_STAGE_BEGIN")
        axis_fd=(collect(gplus.axis_RZ_m).-collect(gminus.axis_RZ_m))./(2motion_h)
        axis_flux_fd=(gplus.psi_axis_Wb_per_rad-gminus.psi_axis_Wb_per_rad)/(2motion_h)
        boundary_fd=(collect(gplus.boundary_RZ_m).-collect(gminus.boundary_RZ_m))./(2motion_h)
        boundary_flux_fd=(gplus.psi_boundary_Wb_per_rad-gminus.psi_boundary_Wb_per_rad)/(2motion_h)
        coordinates_fd=(ray_vector(gplus.coordinates_RZ_m).-ray_vector(gminus.coordinates_RZ_m))./(2motion_h)
        normals_fd=(ray_vector(gplus.normals_RZ).-ray_vector(gminus.normals_RZ))./(2motion_h)
        quadrature_fd=(collect(gplus.surface_quadrature_m2).-collect(gminus.surface_quadrature_m2))./(2motion_h)
        @test check_dynamic_fd(axis_fd,geometry.axis_coordinate_jacobian[:,node_col])
        @test check_dynamic_fd([axis_flux_fd],[geometry.axis_flux_jacobian[1,node_col]])
        @test check_dynamic_fd(boundary_fd,geometry.boundary_coordinate_jacobian[:,node_col])
        @test check_dynamic_fd([boundary_flux_fd],[geometry.boundary_flux_jacobian[1,node_col]])
        @test check_dynamic_fd(coordinates_fd,geometry.coordinate_jacobian[:,node_col])
        @test check_dynamic_fd(normals_fd,geometry.normal_jacobian[:,node_col])
        @test check_dynamic_fd(quadrature_fd,geometry.surface_quadrature_jacobian[:,node_col])
        jet_plus_state=copy(x);jet_minus_state=copy(x)
        jet_plus_state[4node_col]+=jet_motion_h;jet_minus_state[4node_col]-=jet_motion_h
        jet_plus=Base.invokelatest(component.lcfs_dynamic_geometry_trace,jet_plus_state;model_id=continuous_model)
        jet_minus=Base.invokelatest(component.lcfs_dynamic_geometry_trace,jet_minus_state;model_id=continuous_model)
        @test jet_plus.status===jet_minus.status===:evaluated_dynamic_LCFS_geometry
        @test jet_plus.source_critical_point_role===:seed_only_rebound_on_composite_psi
        @test jet_plus.candidate_total_psi_Wb_per_rad!=jet_geometry.candidate_total_psi_Wb_per_rad
        jet_coordinates_fd=(ray_vector(jet_plus.coordinates_RZ_m).-ray_vector(jet_minus.coordinates_RZ_m))./(2jet_motion_h)
        jet_normals_fd=(ray_vector(jet_plus.normals_RZ).-ray_vector(jet_minus.normals_RZ))./(2jet_motion_h)
        jet_quadrature_fd=(collect(jet_plus.surface_quadrature_m2).-collect(jet_minus.surface_quadrature_m2))./(2jet_motion_h)
        jet_axis_fd=(collect(jet_plus.axis_RZ_m).-collect(jet_minus.axis_RZ_m))./(2jet_motion_h)
        jet_boundary_fd=(collect(jet_plus.boundary_RZ_m).-collect(jet_minus.boundary_RZ_m))./(2jet_motion_h)
        @test check_dynamic_fd(jet_coordinates_fd,jet_geometry.coordinate_jacobian[:,node_col])
        @test check_dynamic_fd(jet_normals_fd,jet_geometry.normal_jacobian[:,node_col])
        @test check_dynamic_fd(jet_quadrature_fd,jet_geometry.surface_quadrature_jacobian[:,node_col])
        @test check_dynamic_fd(jet_axis_fd,jet_geometry.axis_coordinate_jacobian[:,node_col])
        @test check_dynamic_fd(jet_boundary_fd,jet_geometry.boundary_coordinate_jacobian[:,node_col])
        geometry_actual_mark("FD_STAGE_END")
    end

    # A same-candidate X-point neighborhood perturb must invalidate stale
    # fixed-source pressure/current rows when geometry crosses a rebuild gate.
    event_node=trace.data.current_support.critical_points.xpoints[1].nearest_native_id
    event_state=copy(x);event_state[4event_node]+=10.0*motion_span
    event_profile=Base.invokelatest(component.lcfs_profile_current_trace,event_state;
        with_jacobian=true,dynamic_geometry=true)
    @test event_profile.status===:needs_rebuild
    if event_profile.status===:needs_rebuild
        @test event_profile.dynamic_geometry.status===:needs_rebuild
        @test event_profile.dynamic_geometry.global_topology_closed===false
        @test event_profile.fields===nothing && event_profile.residual===nothing && event_profile.jacobian===nothing
        @test event_profile.pressure_status===:typed_absent
        @test event_profile.current_status===:typed_absent
        @test event_profile.current_normal_trace===:typed_absent
        @test event_profile.fixed_geometry===false && event_profile.fixed_source_mask===false
        @test event_profile.source_fields_reused===false
        @test event_profile.extra_solver_rows==0
        @test event_profile.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    end

    optin_event=Base.invokelatest(component.lcfs_profile_current_trace,event_state;
        with_jacobian=true,dynamic_geometry=true,continuous_field_model=continuous_model)
    @test optin_event.status===:needs_rebuild
    if optin_event.status===:needs_rebuild
        @test optin_event.dynamic_geometry.status===:needs_rebuild
        @test optin_event.dynamic_geometry.global_topology_closed===false
        @test optin_event.fields===nothing && optin_event.residual===nothing && optin_event.jacobian===nothing
        @test optin_event.pressure_status===:typed_absent && optin_event.current_status===:typed_absent
        @test optin_event.current_normal_trace===:typed_absent
        @test optin_event.fixed_geometry===false && optin_event.fixed_source_mask===false
        @test optin_event.source_fields_reused===false && optin_event.extra_solver_rows==0
        @test optin_event.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    end
    return true
end

function _full_native_h_outer_test_context(F,component,trace,provider)
    S=F.InHouseCoupledMHDGlobalSolveV1
    evaluator_id=S._callback_identity(provider.outer_evaluator)
    oracle_id=S._callback_identity(provider.jacobian_oracle)
    semantic_hash=string(F.canonical_hash(F.semantic_view(trace)))
    context=(candidate_hash=component.candidate_hash,
        provider_semantic_hash=semantic_hash,
        provider_context_hash=string(F.canonical_hash((evaluator_id,oracle_id))),
        jacobian_oracle_hash=string(F.canonical_hash(oracle_id)))
    closures=NamedTuple{F._CCP_AXISYMMETRIC_MISSING_CLOSURES}(ntuple(_->nothing,5))
    (context=context,closures=closures,validator=(candidate_hash=context.candidate_hash,
        provider_semantic_hash=context.provider_semantic_hash,
        provider_context_hash=context.provider_context_hash))
end

# Uses one real 512-ID provider record and changes only its ID field.
function test_provider_record_ids_dynamic_compare(S,record,validator,expected_ids,region_id)
    @test expected_ids isa NTuple{512,String}
    check(ids)=S._check_provider_record(merge(record,(constraint_ids=ids,)),validator,
        expected_ids,region_id,"full-native H outer ID representation",:constraint_ids)
    @test check(Tuple(expected_ids))
    vector_ids=collect(expected_ids)
    @test vector_ids isa Vector{String} && length(vector_ids)==512
    @test check(vector_ids)
    symbol_ids=Tuple(Symbol.(vector_ids))
    @test check(symbol_ids)
    @test check(collect(symbol_ids))
    wrong_content=copy(vector_ids);wrong_content[256]*=":foreign"
    @test_throws ArgumentError check(wrong_content)
    @test_throws ArgumentError check(vector_ids[1:end-1])
    @test_throws ArgumentError check(vcat(vector_ids,["extra"]))
    @test_throws ArgumentError check(reverse(vector_ids))
    true
end

Base.@noinline function _test_full_native_h_source_jacobian(state,source_H,core,boundary_ids,coordinates,
        law,u,v,delta,vary_profile_coefficients,profile_coefficient_columns,nr,ndof)
    source_rows=Int[];source_cols=Int[];source_values=Float64[]
    source_capacity=nr*(length(core)+1+(vary_profile_coefficients ? 2 : 0))
    sizehint!(source_rows,source_capacity);sizehint!(source_cols,source_capacity)
    sizehint!(source_values,source_capacity)
    for (r,boundary_node) in enumerate(boundary_ids)
        push!(source_rows,r);push!(source_cols,4boundary_node);push!(source_values,1.0)
        u_source_derivative=0.0
        v_source_derivative=0.0
        for (c,node) in enumerate(core)
            R=coordinates[node][1]
            coeff=u*R/law.Raxis_m+v*law.Raxis_m/R
            q=(state[4node]-law.psi_boundary_wb_per_rad)/delta
            dpsi=2coeff*q/delta
            push!(source_rows,r);push!(source_cols,4node)
            push!(source_values,-source_H[r,c]*dpsi)
            if vary_profile_coefficients
                u_source_derivative+=-source_H[r,c]*R/law.Raxis_m*q^2
                v_source_derivative+=-source_H[r,c]*law.Raxis_m/R*q^2
            end
        end
        if vary_profile_coefficients
            ucol,vcol=profile_coefficient_columns
            push!(source_rows,r);push!(source_cols,ucol);push!(source_values,u_source_derivative)
            push!(source_rows,r);push!(source_cols,vcol);push!(source_values,v_source_derivative)
        end
    end
    sparse(source_rows,source_cols,source_values,nr,ndof)
end

Base.@noinline function _test_full_native_h_parent_source_jacobian(source_H,boundary_ids,core_ids,derivative_dJ_dpsi,
        coordinates,state,vary_profile_coefficients,law,profile_coefficient_columns,span,nr,ndof)
    source_rows=Int[];source_cols=Int[];source_values=Float64[]
    for (r,node) in enumerate(boundary_ids)
        push!(source_rows,r);push!(source_cols,4node);push!(source_values,1.0)
        for (c,core_node) in enumerate(core_ids)
            push!(source_rows,r);push!(source_cols,4core_node)
            push!(source_values,-source_H[r,c]*derivative_dJ_dpsi[c])
            if vary_profile_coefficients
                q=(state[4core_node]-law.psi_boundary_wb_per_rad)/span
                ucol,vcol=profile_coefficient_columns
                push!(source_rows,r);push!(source_cols,ucol)
                push!(source_values,-source_H[r,c]*coordinates[core_node][1]*q^2/law.Raxis_m)
                push!(source_rows,r);push!(source_cols,vcol)
                push!(source_values,-source_H[r,c]*law.Raxis_m/coordinates[core_node][1]*q^2)
            end
        end
    end
    sparse(source_rows,source_cols,source_values,nr,ndof)
end

Base.@noinline Base.@nospecializeinfer function _test_full_native_h_outer_state(F,component,provider,closures,context,state,source_H,source_plasma_boundary;
        expected_residual=nothing,expected_jacobian=nothing)
    Base.@nospecialize component provider closures context
    rid=provider.region_id
    value=provider.outer_evaluator(rid,state,closures,context)
    oracle=provider.jacobian_oracle(:outer,rid,state,closures,context)
    @test value.constraint_ids==provider.constraint_ids
    @test length(value.residual)==component.hagenow_boundary_row_count==512
    @test size(value.jacobian)==(512,length(state)) && SparseArrays.issparse(value.jacobian)
    @test size(oracle.jacobian)==(512,length(state)) && SparseArrays.issparse(oracle.jacobian)
    @test oracle.jacobian_oracle_hash==context.jacobian_oracle_hash
    @test value.candidate_hash==context.candidate_hash && value.region_id==rid
    @test value.provider_semantic_hash==context.provider_semantic_hash
    @test value.provider_context_hash==context.provider_context_hash
    @test oracle.constraint_ids==provider.constraint_ids
    law=component.profile_law;anchor=component.initial_state
    core=component.hagenow_core_native_ids
    boundary_ids=component.hagenow_boundary_native_ids
    coordinates=component.coordinates_RZ_m
    vary_profile_coefficients=component.vary_profile_coefficients
    profile_coefficient_columns=component.profile_coefficient_columns
    @test size(source_H)==(512,length(core))
    @test all(isfinite,source_H)
    delta=law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad
    u,v=vary_profile_coefficients ?
        (state[profile_coefficient_columns[1]],state[profile_coefficient_columns[2]]) :
        (law.L_A_per_m2*law.Beta0,law.L_A_per_m2*(1-law.Beta0))
    current=[(u*coordinates[k][1]/law.Raxis_m+
        v*law.Raxis_m/coordinates[k][1])*
        ((state[4k]-law.psi_boundary_wb_per_rad)/delta)^2 for k in core]
    @test length(source_plasma_boundary)==512 && all(isfinite,source_plasma_boundary)
    # The raw accepted plasma boundary is not the source API's recomputed H[Jfinal].
    source_residual=source_plasma_boundary+
        [state[4k]-anchor[4k] for k in boundary_ids]-source_H*current
    residual_bound=component.hagenow_source_comparison_bound
    @test maximum(abs,value.residual-source_residual;init=0.0)<=residual_bound
    if expected_residual!==nothing
        @test maximum(abs,value.residual-expected_residual;init=0.0)<=residual_bound
    end
    if expected_jacobian!==nothing
        @test maximum(abs,SparseArrays.nonzeros(SparseArrays.sparse(value.jacobian-expected_jacobian));init=0.0)<=
            component.hagenow_initial_source_jacobian_bound
    end
    nr=component.hagenow_boundary_row_count;ndof=length(state)
    source_J_live_before=Base.gc_live_bytes()
    println("G2_H_SOURCE_J_BEGIN gc_live_bytes=",source_J_live_before);flush(stdout)
    source_J_timed=@timed _test_full_native_h_source_jacobian(state,source_H,core,boundary_ids,
        coordinates,law,u,v,delta,vary_profile_coefficients,profile_coefficient_columns,nr,ndof)
    source_jacobian=source_J_timed.value
    source_J_live_after=Base.gc_live_bytes()
    println("G2_H_SOURCE_J_MEASURE elapsed_s=",source_J_timed.time,
        " allocated_bytes=",source_J_timed.bytes," gc_seconds=",source_J_timed.gctime,
        " gc_live_delta_bytes=",source_J_live_after-source_J_live_before);flush(stdout)
    jacobian_bound=component.hagenow_initial_source_jacobian_bound
    @test maximum(abs,SparseArrays.nonzeros(SparseArrays.sparse(value.jacobian-source_jacobian));init=0.0)<=jacobian_bound
    @test maximum(abs,SparseArrays.nonzeros(SparseArrays.sparse(oracle.jacobian-source_jacobian));init=0.0)<=jacobian_bound
    S=F.InHouseCoupledMHDGlobalSolveV1
    @test S._check_provider_record(value,(candidate_hash=context.candidate_hash,
        provider_semantic_hash=context.provider_semantic_hash,
        provider_context_hash=context.provider_context_hash),provider.constraint_ids,rid,
        "full-native H outer",:constraint_ids)
    @test test_provider_record_ids_dynamic_compare(S,value,
        (candidate_hash=context.candidate_hash,
         provider_semantic_hash=context.provider_semantic_hash,
         provider_context_hash=context.provider_context_hash),provider.constraint_ids,rid)
    residual_copy=copy(value.residual)
    value=nothing;oracle=nothing;source_jacobian=nothing;source_residual=nothing;current=nothing
    GC.gc(false)
    residual_copy
end

function _g2_a3_timed_call(label, f)
    started = time()
    live_before = Base.gc_live_bytes()
    println("G2_A3_CALL_BEGIN label=", label, " gc_live_bytes=", live_before)
    flush(stdout)
    try
        measured = @timed f()
        live_after = Base.gc_live_bytes()
        println("G2_A3_CALL_END label=", label, " elapsed_s=", measured.time,
            " allocated_bytes=", measured.bytes, " gc_seconds=", measured.gctime,
            " gc_live_delta_bytes=", live_after - live_before)
        flush(stdout)
        measured.value
    catch
        live_after = Base.gc_live_bytes()
        println("G2_A3_CALL_END label=", label, " elapsed_s=", time() - started,
            " outcome=threw gc_live_delta_bytes=", live_after - live_before)
        flush(stdout)
        rethrow()
    end
end

# Shared exact comparator: the actual consumer and numeric-only rejection
# checks call this same implementation. No provider or Fusion module is needed.
function _test_g2_map_csc_equal_rows(actual_B,actual_normal,sources,row_maps,normals)
    nB,ncolumns=size(actual_B);nnormal=size(actual_normal,1)
    nB==3nnormal && size(actual_normal,2)==ncolumns && length(normals)==nnormal ||
        throw(ArgumentError("G2 stream comparison dimensions differ"))
    length(sources)==length(row_maps) || throw(ArgumentError("G2 source map count differs"))
    covered=falses(nB)
    for (matrix,rows) in zip(sources,row_maps)
        size(matrix,2)==ncolumns && size(matrix,1)==length(rows) ||
            throw(ArgumentError("G2 source CSC shape differs"))
        for row in rows
            1<=row<=nB && !covered[row] || throw(ArgumentError("G2 row map is not a permutation"))
            covered[row]=true
        end
    end
    all(covered) || throw(ArgumentError("G2 row map omits source rows"))
    expected_B=zeros(Float64,nB);expected_normal=zeros(Float64,nnormal)
    touched_B=Int[];touched_normal=Int[]
    sizehint!(touched_B,nB);sizehint!(touched_normal,2nnormal)
    B_equal=trues(nB);normal_equal=trues(nnormal)
    for column in 1:ncolumns
        empty!(touched_B);empty!(touched_normal)
        for (matrix,rows) in zip(sources,row_maps)
            for pointer in SparseArrays.nzrange(matrix,column)
                row=rows[matrix.rowval[pointer]]
                value=SparseArrays.nonzeros(matrix)[pointer]
                expected_B[row]=value;push!(touched_B,row)
                incidence=cld(row,3);field=mod1(row,3)
                weight=field==1 ? normals[incidence][1] : field==3 ? normals[incidence][2] : 0.0
                if weight!=0.0
                    expected_normal[incidence]+=weight*value
                    push!(touched_normal,incidence)
                end
            end
        end
        for pointer in SparseArrays.nzrange(actual_B,column)
            row=actual_B.rowval[pointer]
            B_equal[row] &= SparseArrays.nonzeros(actual_B)[pointer]==expected_B[row]
            expected_B[row]=0.0
        end
        for row in touched_B
            B_equal[row] &= iszero(expected_B[row]);expected_B[row]=0.0
        end
        for pointer in SparseArrays.nzrange(actual_normal,column)
            row=actual_normal.rowval[pointer]
            normal_equal[row] &= SparseArrays.nonzeros(actual_normal)[pointer]==expected_normal[row]
            expected_normal[row]=0.0
        end
        for row in touched_normal
            normal_equal[row] &= iszero(expected_normal[row]);expected_normal[row]=0.0
        end
    end
    (B_equal,normal_equal)
end

function g2_diag_csc_stats(value)
    if value isa SparseArrays.SparseMatrixCSC
        bytes=sizeof(eltype(value.colptr))*length(value.colptr)+
            sizeof(eltype(value.rowval))*length(value.rowval)+
            sizeof(eltype(value.nzval))*length(value.nzval)
        return (rows=size(value,1),cols=size(value,2),nnz=SparseArrays.nnz(value),
            csc_payload_bytes=bytes,blocks=1)
    elseif value isa Tuple
        rows=0;cols=0;nnz=0;bytes=0;blocks=0
        for item in value
            matrix=item isa SparseArrays.SparseMatrixCSC ? item :
                (hasproperty(item,:jacobian) ? item.jacobian : nothing)
            matrix isa SparseArrays.SparseMatrixCSC || continue
            rows+=size(matrix,1);cols=max(cols,size(matrix,2))
            nnz+=SparseArrays.nnz(matrix)
            bytes+=sizeof(eltype(matrix.colptr))*length(matrix.colptr)+
                sizeof(eltype(matrix.rowval))*length(matrix.rowval)+
                sizeof(eltype(matrix.nzval))*length(matrix.nzval)
            blocks+=1
        end
        return (rows=rows,cols=cols,nnz=nnz,csc_payload_bytes=bytes,blocks=blocks)
    end
    (rows=0,cols=0,nnz=0,csc_payload_bytes=0,blocks=0)
end
function g2_diag_lifetime_marker(phase,matrices...)
    print("G2_GLOBAL_DIAGNOSTIC_LIFETIME phase=",phase,
        " gc_live_bytes=",Base.gc_live_bytes())
    for (name,value) in matrices
        stats=g2_diag_csc_stats(value)
        print(" ",name,"_blocks=",stats.blocks,"_rows=",stats.rows,
            "_cols=",stats.cols,"_nnz=",stats.nnz,
            "_csc_payload_bytes=",stats.csc_payload_bytes)
    end
    println();flush(stdout)
end

Base.@noinline Base.@nospecializeinfer function _g2_actual_nonlinear_trial_consumer_v1(S,F,component,composed,provider,regional,diagnostic_model,scale_contract,kkt_partition,kkt_step,changed_state,numeric_result_run_leaf,endpoint_rows,endpoint_ids,diagnostic;geometry_cache=nothing,max_alpha_power=3,min_alpha_power=0,projection_replay_binding=nothing,require_acceptance=true,apply_span_projection=nothing)
    Base.@nospecialize S F component composed provider regional diagnostic_model scale_contract kkt_partition kkt_step changed_state numeric_result_run_leaf endpoint_rows endpoint_ids diagnostic
    min_alpha_power isa Integer && !(min_alpha_power isa Bool) &&
        max_alpha_power isa Integer && !(max_alpha_power isa Bool) &&
        0<=min_alpha_power<=max_alpha_power<=14 ||
        throw(ArgumentError("actual nonlinear alpha-power interval must satisfy 0 <= min <= max <= 14"))
    trial_status=:not_executed;accepted_trial=nothing
    trial_records=NamedTuple[]
        if !isempty(endpoint_rows)
            # This is a true nonlinear trial through the existing full-native
            # global assembler. It is deliberately off-shell-capable: dynamic
            # geometry/mask, checked native state (p/Bphi/F/flux span), and a
            # strict decrease in the frozen LS/equality-scaled merit govern
            # line search. Endpoint and p=1e-8 limits are final gates only.
            base_merit=kkt_partition.merit
            frozen_trial_equality_scales=Tuple(vcat(
                collect(scale_contract.equalities.characteristics),
                collect(scale_contract.equilibrium.characteristics)[endpoint_rows]))
            frozen_trial_equality_ids=if composed===nothing || provider===nothing
                composed===nothing && provider===nothing &&
                    get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")=="1" &&
                    hasproperty(scale_contract.equalities,:row_ids) ||
                    throw(ArgumentError("metadata-only ABI preflight requires saved equality IDs; live trial requires providers"))
                (Tuple(scale_contract.equalities.row_ids)...,Tuple(endpoint_ids)...)
            else
                (Tuple(composed.outer.constraint_ids)...,
                    Tuple(provider.conservation_ids)...,Tuple(endpoint_ids)...)
            end
            expected_trial_equality_rows=length(frozen_trial_equality_ids)
            length(frozen_trial_equality_scales)==expected_trial_equality_rows &&
                Tuple(kkt_partition.equality_row_ids)==frozen_trial_equality_ids ||
                throw(ArgumentError("KKT equality IDs differ from the live outer/current/endpoint join"))
            kkt_partition.equality_row_scales==frozen_trial_equality_scales ||
                throw(ArgumentError("KKT equality scales differ from the original equality/endpoint join"))
            kkt_partition.equality_row_scale_hash==string(F.canonical_hash(frozen_trial_equality_scales)) ||
                throw(ArgumentError("KKT equality scale identity differs from the frozen join"))
            trial_records=NamedTuple[]
            actual_trial_metrics=NamedTuple[]
            accepted_trial=nothing
            pressure_indices=Tuple(i for i in component.pressure_dofs if i>0)
            bphi_indices=Tuple(4k-2 for k in eachindex(component.core_mask))
            D_coordinate=get(component,:state_coordinate_id,:native_Bphi_T_v1)===:native_F_defect_T_m_v1
            D_coordinate && !(projection_replay_binding!==nothing &&
                get(projection_replay_binding,:kind,nothing) in (:saved_actual_D_kkt_step,:saved_D_mask_feasible_direction) &&
                get(projection_replay_binding,:state_coordinate_id,nothing)===:native_F_defect_T_m_v1) &&
                error("D nonlinear trial requires an explicitly bound D solver step")
            @test diagnostic.diagnostic_assembly.jacobian===nothing
            @test diagnostic.diagnostic_assembly.equality_jacobian===nothing
            @test kkt_partition.raw_least_squares_jacobian===nothing
            @test kkt_partition.raw_equality_jacobian===nothing
            # The KKT solver has returned its numeric step; release its scaled
            # operators before the first actual trial assembly.
            kkt_partition=merge(kkt_partition,
                (scaled_least_squares_jacobian=nothing,equality_jacobian=nothing))
            regional_initial_residual=nothing;regional_oracle=nothing;regional=nothing
            changed_regional_value=nothing;changed_regional_oracle=nothing
            GC.gc(true)
            g2_diag_lifetime_marker("before_actual_nonlinear_trial",
                (:baseline_J,diagnostic.diagnostic_assembly.jacobian),
                (:baseline_C,diagnostic.diagnostic_assembly.equality_jacobian),
                (:scaled_KKT_J,kkt_partition.scaled_least_squares_jacobian),
                (:scaled_KKT_C,kkt_partition.equality_jacobian),
                (:raw_KKT_J,kkt_partition.raw_least_squares_jacobian),
                (:raw_KKT_C,kkt_partition.raw_equality_jacobian))
            @test kkt_partition.scaled_least_squares_jacobian===nothing
            @test kkt_partition.equality_jacobian===nothing
            abi_preflight_flag=get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")
            abi_preflight_flag in ("0","1") || error("saved-minus ABI preflight flag must be 0 or 1")
            endpoint_restore_flag=apply_span_projection===nothing ? get(ENV,"FUSION_G2_TRIAL_EXACT_SPAN_RESTORE","0") : (apply_span_projection ? "1" : "0")
            endpoint_restore_flag in ("0","1") || error("exact-span trial restoration flag must be 0 or 1")
            endpoint_restore_flag=="1" && projection_replay_binding===nothing &&
                error("exact-span trial projection requires the validated prior accepted-alpha replay binding")
            if abi_preflight_flag=="1"
                n=length(changed_state)
                length(kkt_partition.least_squares_row_ids)==68_932 &&
                    length(kkt_partition.least_squares_row_scales)==68_932 &&
                    length(kkt_partition.equality_row_ids)==expected_trial_equality_rows &&
                    length(kkt_partition.equality_row_scales)==expected_trial_equality_rows &&
                    length(kkt_partition.gradient)==n==69_447 &&
                    length(kkt_step.step)==n && length(endpoint_rows)==length(endpoint_ids)==2 &&
                    Tuple(kkt_partition.equality_row_ids[end-1:end])==Tuple(endpoint_ids) &&
                    _g2_actual_pressure_dof_map_matches_v1(component) ||
                    error("saved-minus actual trial consumer row/state/pressure ABI preflight failed")
                all(isfinite,kkt_step.step) && all(isfinite,changed_state) &&
                    all(isfinite,kkt_partition.gradient) && isfinite(kkt_partition.merit) &&
                    all(x->isfinite(x)&&x>0,kkt_partition.least_squares_row_scales) &&
                    all(x->isfinite(x)&&x>0,kkt_partition.equality_row_scales) ||
                    error("saved-minus actual trial consumer numeric preflight failed")
                diagnostic.diagnostic_assembly.jacobian===nothing &&
                    diagnostic.diagnostic_assembly.equality_jacobian===nothing &&
                    kkt_partition.raw_least_squares_jacobian===nothing &&
                    kkt_partition.raw_equality_jacobian===nothing &&
                    kkt_partition.scaled_least_squares_jacobian===nothing &&
                    kkt_partition.equality_jacobian===nothing ||
                    error("saved-minus actual trial consumer released-operator ABI preflight failed")
                println("G2_SAVED_MINUS_ACTUAL_TRIAL_ABI_PREFLIGHT_PASS state_dofs=",n,
                    " least_squares_rows=68932 equality_rows=",expected_trial_equality_rows,
                    " endpoint_rows=2 positive_pressure_dofs=2879 geometry=false assembly=false");flush(stdout)
                return (status=:abi_preflight,accepted_trial=nothing,kkt_partition=kkt_partition)
            end
            geometry_raw_replay_preflight_flag=get(ENV,"FUSION_G2_SAVED_GEOMETRY_RAW_REPLAY_PREFLIGHT_ONLY","0")
            geometry_raw_replay_preflight_flag in ("0","1") || error("saved geometry replay preflight flag must be 0 or 1")
            if geometry_raw_replay_preflight_flag=="1"
                geometry_cache!==nothing && max_alpha_power==6 ||
                    error("saved geometry replay preflight requires the seven-record saved cache and alpha powers 0:6")
                Tuple(entry.alpha for entry in geometry_cache.records)==ntuple(i->0.5^(i-1),7) ||
                    error("saved geometry replay preflight cache alpha sequence differs")
            end
            if geometry_cache!==nothing
                geometry_cache.identity.candidate_hash==component.candidate_hash &&
                    geometry_cache.identity.component_context_hash==component.context_hash &&
                    geometry_cache.identity.current_operator_model_id===component.current_operator_model_id &&
                    geometry_cache.identity.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id &&
                    geometry_cache.identity.field_model_id===component.native_field_model_id &&
                    geometry_cache.identity.state_sha256==bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(changed_state)))) &&
                    geometry_cache.identity.step_sha256==bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(kkt_step.step)))) ||
                    throw(ArgumentError("saved geometry raw identity differs from the live nonlinear trial"))
            end
            for trial_index in min_alpha_power:max_alpha_power
                alpha=0.5^trial_index
                trial_state=Float64.(changed_state).+alpha.*Float64.(kkt_step.step)
                # Signed D is authoritative. Positive physical Bphi/F is checked
                # by the original D component assembler after exact-span restore.
                # The legacy branch retains its original raw-Bphi preguard.
                preguard=all(isfinite,trial_state) &&
                    all(i->trial_state[i]>=0.0,pressure_indices) &&
                    (D_coordinate || all(i->trial_state[i]>0.0,bphi_indices))
                if D_coordinate && preguard
                    admitted=Base.invokelatest(component.admit_state_record,
                        (state=trial_state,state_coordinate_id=:native_F_defect_T_m_v1,
                            coordinate_origin=:solver_trial_in_D_coordinates))
                    admitted==trial_state || error("D trial admission changed the authoritative state")
                end
                geometry_raw_replay_preflight_flag=="1" && !preguard &&
                    error("saved geometry replay preflight trial fails the original finite/pressure/Bphi preguard")
                if !preguard
                    push!(trial_records,(alpha=alpha,status=:typed_guard,
                        reason=D_coordinate ? :finite_nonnegative_pressure_D_state_guard :
                            :finite_nonnegative_pressure_and_positive_Bphi_guard,merit_after=nothing,
                        merit_reduction=nothing))
                    continue
                end
                geometry_entry=nothing
                geometry_source=(kind=:live_geometry_call,path=nothing,sha256=nothing)
                if geometry_cache!==nothing
                    entry_index=findfirst(item->item.alpha==alpha,geometry_cache.records)
                    entry_index===nothing || (geometry_entry=geometry_cache.records[entry_index])
                end
                geometry_raw_replay_preflight_flag=="1" && geometry_entry===nothing &&
                    error("saved geometry replay preflight has no pinned raw record for alpha $(alpha)")
                geometry_raw=nothing
                if geometry_entry===nothing
                    geometry_source=(kind=:live_geometry_call,path=nothing,sha256=nothing,
                        deferred_toroidal_profile_admission=D_coordinate && endpoint_restore_flag=="1")
                    geometry=try
                        Base.invokelatest(component.lcfs_dynamic_geometry_trace,trial_state;
                            defer_toroidal_profile_admission=D_coordinate && endpoint_restore_flag=="1")
                    catch err
                        if err isa DomainError
                            push!(trial_records,(alpha=alpha,status=:typed_guard,
                                reason=:dynamic_geometry_domain_guard,merit_after=nothing,
                                merit_reduction=nothing,geometry_source=geometry_source))
                            continue
                        end
                        rethrow()
                    end
                else
                    raw_sha=_g2_global_diag_result_file_sha256(geometry_entry.path)
                    raw_sha==geometry_entry.sha256 || throw(ArgumentError("saved geometry raw digest differs at alpha $(alpha)"))
                    geometry_raw=open(Serialization.deserialize,geometry_entry.path,"r")
                    geometry_raw.schema=="saved-step-dynamic-geometry-raw-v1" &&
                        geometry_raw.alpha==alpha && geometry_raw.state==trial_state &&
                        geometry_raw.state_sha256==bytes2hex(SHA.sha256(reinterpret(UInt8,trial_state))) &&
                        geometry_raw.pre_geometry_state_guard_passed===true && preguard ||
                        throw(ArgumentError("saved geometry raw exact trial state/pre-guard binding differs at alpha $(alpha)"))
                    for key in keys(geometry_cache.identity)
                        isequal(getproperty(geometry_raw.source_identity,key),getproperty(geometry_cache.identity,key)) ||
                            throw(ArgumentError("saved geometry raw source identity differs at alpha $(alpha): $(key)"))
                    end
                    geometry=geometry_raw.geometry_result
                    if geometry_entry.expected===:mask_changed
                        hasproperty(geometry,:status) && geometry.status===:needs_rebuild &&
                            get(geometry,:reason,nothing)===:candidate_core_mask_changed &&
                            hasproperty(geometry,:changed_native_ids) && !isempty(geometry.changed_native_ids) ||
                            throw(ArgumentError("saved prior guard-fail geometry predicate differs at alpha $(alpha)"))
                    elseif geometry_entry.expected===:geometry_gate_pass
                        hasproperty(geometry,:status) && geometry.status===:evaluated_dynamic_LCFS_geometry &&
                            get(geometry,:mask_event,:unknown)===:unchanged &&
                            hasproperty(geometry,:endpoint_definition_residual) &&
                            hasproperty(geometry,:psi_axis_Wb_per_rad) &&
                            hasproperty(geometry,:psi_boundary_Wb_per_rad) ||
                            throw(ArgumentError("saved geometry-pass raw no longer satisfies the live geometry gate"))
                    else
                        throw(ArgumentError("saved geometry raw has an unsupported expected predicate"))
                    end
                    geometry_source=(kind=:pinned_saved_geometry_raw,path=geometry_entry.path,sha256=raw_sha)
                    if geometry_raw_replay_preflight_flag=="1"
                        changed_native_count=hasproperty(geometry,:changed_native_ids) ? length(geometry.changed_native_ids) : 0
                        push!(trial_records,(alpha=alpha,status=:saved_geometry_raw_replayed,
                            expected=geometry_entry.expected,changed_native_count=changed_native_count,
                            geometry_source=geometry_source))
                        geometry_raw=nothing;geometry=nothing;trial_state=nothing;GC.gc(false)
                        if trial_index==max_alpha_power
                            println("G2_SAVED_GEOMETRY_RAW_REPLAY_PREFLIGHT_PASS records=",length(trial_records),
                                " cached_alphas=",Tuple(r.alpha for r in trial_records)," geometry_calls=0 assembly=false");flush(stdout)
                            return (status=:geometry_raw_replay_preflight,accepted_trial=nothing,
                                trial_records=Tuple(trial_records),kkt_partition=kkt_partition)
                        end
                        continue
                    end
                    geometry_raw=nothing
                end
                if !hasproperty(geometry,:status) ||
                        geometry.status!==:evaluated_dynamic_LCFS_geometry ||
                        get(geometry,:mask_event,:unknown)!==:unchanged ||
                        !hasproperty(geometry,:endpoint_definition_residual) ||
                        !hasproperty(geometry,:psi_axis_Wb_per_rad) ||
                        !hasproperty(geometry,:psi_boundary_Wb_per_rad)
                    changed_native_count=hasproperty(geometry,:changed_native_ids) ? length(geometry.changed_native_ids) : 0
                    push!(trial_records,(alpha=alpha,status=:typed_guard,
                        reason=:dynamic_geometry_or_mask_guard,merit_after=nothing,
                        merit_reduction=nothing,changed_native_count=changed_native_count,
                        geometry_source=geometry_source))
                    geometry_raw=nothing;geometry=nothing;trial_state=nothing;GC.gc(false)
                    continue
                end
                span_projection_raw=nothing
                if endpoint_restore_flag=="1"
                    # This is a trial-state projection only. The native psi state
                    # is unchanged; the two appended profile-span DOFs are set to
                    # the axis/boundary fluxes returned by the already-valid live
                    # geometry. Any derivative of this map is algorithmic and is
                    # not substituted for the physical assembler Jacobian below.
                    span_columns=Tuple(Int.(collect(component.profile_span_columns)))
                    length(trial_state)==69_447 && span_columns==(69_446,69_447) &&
                        length(unique(span_columns))==2 &&
                        all(c->1<=c<=length(trial_state),span_columns) ||
                        throw(ArgumentError("exact-span projection requires the two appended dynamic profile-span DOFs"))
                    psi_ids=Tuple(Int.(collect(geometry.psi_global_dof_ids)))
                    length(psi_ids)==16_641 && all(k->psi_ids[k]==4k,eachindex(psi_ids)) &&
                        all(c->!(c in psi_ids),span_columns) ||
                        throw(ArgumentError("exact-span projection requires the producer native-psi map and disjoint appended endpoint DOFs"))
                    endpoint_target=(Float64(geometry.psi_axis_Wb_per_rad),
                        Float64(geometry.psi_boundary_Wb_per_rad))
                    endpoint_before=(Float64(trial_state[span_columns[1]]),
                        Float64(trial_state[span_columns[2]]))
                    endpoint_before_residual=(endpoint_before[1]-endpoint_target[1],
                        endpoint_before[2]-endpoint_target[2])
                    all(isfinite,endpoint_target) && all(isfinite,endpoint_before_residual) &&
                        hasproperty(geometry,:endpoint_definition_residual) &&
                        Tuple(Float64.(geometry.endpoint_definition_residual))==endpoint_before_residual ||
                        throw(ArgumentError("live geometry endpoint residual differs from the exact-span state binding"))
                    endpoint_projection_tolerance=64eps(Float64)*max(1.0,
                        maximum(abs,endpoint_target;init=0.0))
                    projection_applied=maximum(abs,endpoint_before_residual;init=0.0)>
                        endpoint_projection_tolerance
                    pre_projection_state=copy(trial_state)
                    if projection_applied
                        trial_state=copy(trial_state)
                        trial_state[span_columns[1]]=endpoint_target[1]
                        trial_state[span_columns[2]]=endpoint_target[2]
                    end
                    endpoint_after=(Float64(trial_state[span_columns[1]]),
                        Float64(trial_state[span_columns[2]]))
                    endpoint_after_residual=(endpoint_after[1]-endpoint_target[1],
                        endpoint_after[2]-endpoint_target[2])
                    (projection_applied ? endpoint_after_residual==(0.0,0.0) :
                        endpoint_after_residual==endpoint_before_residual) ||
                        throw(ArgumentError("exact-span trial projection state/residual binding failed"))
                    all(i->pre_projection_state[psi_ids[i]]==trial_state[psi_ids[i]],eachindex(psi_ids)) ||
                        throw(ArgumentError("exact-span projection unexpectedly changed a native psi DOF"))
                    projection_dir=joinpath(numeric_result_run_leaf,"result_data","g2_global_diagnostic")
                    mkpath(projection_dir)
                    projection_path=joinpath(projection_dir,
                        "actual_nonlinear_trial_span_projection_$(lpad(string(trial_index),3,'0'))_v1.jls")
                    ispath(projection_path) &&
                        throw(ArgumentError("refusing to overwrite exact-span projection evidence"))
                    projection_payload=(schema="g2-global-diagnostic-actual-trial-exact-span-projection-v1",
                        trial_index=Int(trial_index),alpha=Float64(alpha),
                        projection_applied=projection_applied,
                        projection_rule=:set_only_dynamic_span_dofs_to_same_state_live_geometry_fluxes,
                        physical_assembler_jacobian_changed=false,
                        algorithmic_projection_jacobian_status=:not_used_for_this_line_search,
                        future_direction_derivative_requirement=:differentiate_endpoint_flux_map_or_verify_projected_trial_map_by_finite_difference,
                        unprojected_accepted_trial_replay=(projection_replay_binding!==nothing &&
                            hasproperty(projection_replay_binding,:kind) &&
                            projection_replay_binding.kind in (:actual_bphi_retraction_next_kkt,:saved_x2_mask_projected_direction,:saved_actual_D_kkt_step,:saved_D_mask_feasible_direction) ? nothing : projection_replay_binding),
                        projection_origin_binding=(projection_replay_binding!==nothing &&
                            hasproperty(projection_replay_binding,:kind) &&
                            projection_replay_binding.kind in (:actual_bphi_retraction_next_kkt,:saved_x2_mask_projected_direction,:saved_actual_D_kkt_step,:saved_D_mask_feasible_direction) ? projection_replay_binding : nothing),
                        pre_projection_state=pre_projection_state,post_projection_state=trial_state,
                        pre_projection_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,pre_projection_state))),
                        post_projection_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,trial_state))),
                        profile_span_columns=span_columns,psi_global_dof_ids=psi_ids,
                        endpoint_target=endpoint_target,endpoint_before=endpoint_before,
                        endpoint_before_residual=endpoint_before_residual,
                        endpoint_after=endpoint_after,endpoint_after_residual=endpoint_after_residual,
                        original_endpoint_tolerance=endpoint_projection_tolerance,
                        native_psi_exactly_unchanged=true,geometry_source=geometry_source,
                        geometry_result=geometry)
                    open(projection_path,"w") do io
                        Serialization.serialize(io,projection_payload)
                        flush(io)
                    end
                    projection_bytes=filesize(projection_path)
                    projection_sha256=_g2_global_diag_result_file_sha256(projection_path)
                    span_projection_raw=(path=projection_path,bytes=projection_bytes,
                        sha256=projection_sha256,applied=projection_applied)
                    println("G2_GLOBAL_TRIAL_EXACT_SPAN_PROJECTION_RAW path=",projection_path,
                        " bytes=",projection_bytes," sha256=",projection_sha256,
                        " trial_index=",trial_index," alpha=",alpha,
                        " applied=",projection_applied,
                        " before_residual=",endpoint_before_residual,
                        " after_residual=",endpoint_after_residual,
                        " native_psi_unchanged=true")
                    flush(stdout)
                    # Re-run the real geometry producer on the projected state;
                    # equality is checked on the full geometry record after
                    # removing only its two span-dependent bookkeeping fields.
                    geometry_recheck=try
                        Base.invokelatest(component.lcfs_dynamic_geometry_trace,trial_state)
                    catch err
                        if err isa DomainError
                            (status=:typed_absent,reason=:dynamic_geometry_domain_guard,
                                exception_type=string(nameof(typeof(err))))
                        else
                            rethrow()
                        end
                    end
                    geometry_recheck_path=joinpath(projection_dir,
                        "actual_nonlinear_trial_span_geometry_recheck_$(lpad(string(trial_index),3,'0'))_v1.jls")
                    ispath(geometry_recheck_path) &&
                        throw(ArgumentError("refusing to overwrite projected-state geometry recheck evidence"))
                    open(geometry_recheck_path,"w") do io
                        Serialization.serialize(io,(schema="g2-global-diagnostic-actual-trial-span-geometry-recheck-v1",
                            trial_index=Int(trial_index),alpha=Float64(alpha),
                            projected_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,trial_state))),
                            initial_geometry=geometry,projected_state_geometry=geometry_recheck))
                        flush(io)
                    end
                    geometry_recheck_sha256=_g2_global_diag_result_file_sha256(geometry_recheck_path)
                    span_projection_raw=merge(span_projection_raw,
                        (geometry_recheck_path=geometry_recheck_path,geometry_recheck_sha256=geometry_recheck_sha256))
                    if !hasproperty(geometry_recheck,:status) ||
                            geometry_recheck.status!==:evaluated_dynamic_LCFS_geometry ||
                            get(geometry_recheck,:mask_event,:unknown)!==:unchanged ||
                            !hasproperty(geometry_recheck,:endpoint_definition_residual)
                        push!(trial_records,(alpha=alpha,status=:typed_guard,
                            reason=:projected_state_geometry_or_mask_guard,merit_after=nothing,
                            merit_reduction=nothing,geometry_source=geometry_source,
                            span_projection_raw=span_projection_raw))
                        geometry_recheck=nothing;geometry=nothing;trial_state=nothing;GC.gc(false)
                        continue
                    end
                    geometry_compare_before=merge(geometry,
                        (profile_endpoint_values=nothing,endpoint_definition_residual=nothing))
                    geometry_compare_after=merge(geometry_recheck,
                        (profile_endpoint_values=nothing,endpoint_definition_residual=nothing))
                    isequal(geometry_compare_before,geometry_compare_after) ||
                        throw(ArgumentError("projecting only the endpoint DOFs changed the producer geometry record"))
                    Tuple(Float64.(geometry_recheck.endpoint_definition_residual))==endpoint_after_residual ||
                        throw(ArgumentError("projected-state geometry endpoint residual does not match the restored span DOFs"))
                    geometry=geometry_recheck
                    geometry_recheck=nothing
                end
                trial_state_record=D_coordinate ?
                    (state=trial_state,state_coordinate_id=:native_F_defect_T_m_v1,
                        coordinate_origin=:solver_trial_in_D_coordinates) : nothing
                if D_coordinate
                    Base.invokelatest(component.admit_state_record,trial_state_record)==trial_state ||
                        error("projected D trial coordinate admission differs")
                end
                trial_result=nothing
                try
                    # The actual assembler invokes the component's checked-state
                    # callbacks, including its positive-F and flux-span guards.
                    trial_result=S.assemble_coupled_mhd_global_v1(
                        diagnostic_model,trial_state;allow_incomplete=true)
                catch err
                    if err isa DomainError
                        push!(trial_records,(alpha=alpha,status=:typed_guard,
                            reason=:full_native_F_or_flux_span_guard,merit_after=nothing,
                            merit_reduction=nothing,geometry_source=geometry_source,
                            span_projection_raw=span_projection_raw))
                        continue
                    end
                    rethrow()
                end
                trial_raw_result=_g2_global_diag_spill_actual_nonlinear_trial_raw(
                    numeric_result_run_leaf,trial_result,trial_state,alpha,trial_index;state_record=trial_state_record)
                hasproperty(trial_result,:diagnostic_assembly) &&
                    trial_result.diagnostic_assembly.status===:incomplete_assembly ||
                    throw(ArgumentError("actual global trial assembly did not return the expected diagnostic R/J/C"))
                trial_assembly=trial_result.diagnostic_assembly
                trial_assembly.residual_scaling===:frozen_row_scales ||
                    throw(ArgumentError("actual trial residuals are not using the frozen row scales"))
                trial_assembly.equilibrium_row_scales==scale_contract.equilibrium.characteristics ||
                    throw(ArgumentError("actual trial equilibrium scales differ from the frozen scale contract"))
                trial_assembly.equilibrium_row_scale_hash==
                    string(F.canonical_hash(scale_contract.equilibrium.characteristics)) ||
                    throw(ArgumentError("actual trial equilibrium scale hash differs from the frozen scale contract"))
                actual_ls_ids=kkt_partition.least_squares_row_ids
                actual_region_ids=trial_assembly.equation_ids.regional[1]
                actual_endpoint_ids=Tuple(actual_region_ids[i] for i in endpoint_rows)
                actual_original_ls_ids=Tuple(id for id in actual_region_ids if !(id in endpoint_ids))
                actual_endpoint_ids==endpoint_ids ||
                    throw(ArgumentError("actual dynamic endpoint rows differ from the frozen endpoint join"))
                actual_ls_ids==actual_original_ls_ids ||
                    throw(ArgumentError("actual original least-squares row IDs differ from the frozen full row set"))
                row_index=Dict(id=>i for (i,id) in enumerate(actual_region_ids))
                ls_rows=Int[row_index[id] for id in actual_ls_ids]
                actual_outer_ids=Tuple(id for region_ids in trial_assembly.equation_ids.outer
                    for id in region_ids)
                actual_eq_ids=(actual_outer_ids...,
                    trial_assembly.equation_ids.conservation...,component.dynamic_span_equation_ids...)
                actual_eq_ids==kkt_partition.equality_row_ids ||
                    throw(ArgumentError("actual trial equality rows differ from the frozen KKT partition"))
                kkt_partition.equality_row_scales==frozen_trial_equality_scales ||
                    throw(ArgumentError("actual trial consumer equality scales changed"))
                trial_ls=(trial_assembly.residual[ls_rows]./
                    collect(kkt_partition.least_squares_row_scales))
                trial_eq=(vcat(trial_assembly.equality_residual,
                    trial_assembly.residual[endpoint_rows])./
                    collect(kkt_partition.equality_row_scales))
                all(isfinite,trial_ls) && all(isfinite,trial_eq) ||
                    throw(ArgumentError("actual nonlinear trial scaled residual is nonfinite"))
                trial_merit=0.5*(sum(abs2,trial_ls)+sum(abs2,trial_eq))
                isfinite(trial_merit) || throw(ArgumentError("actual nonlinear trial merit is nonfinite"))
                merit_reduction=base_merit-trial_merit
                trial_metrics=(alpha=alpha,merit_after=trial_merit,
                    merit_reduction=merit_reduction,
                    max_abs_scaled_equilibrium=maximum(abs,trial_ls;init=0.0),
                    max_abs_scaled_equality=maximum(abs,trial_eq;init=0.0),
                    max_abs_raw_equilibrium=maximum(abs,trial_assembly.residual;init=0.0),
                    max_abs_raw_equality=maximum(abs,trial_assembly.equality_residual;init=0.0))
                push!(actual_trial_metrics,trial_metrics)
                if trial_merit<base_merit
                    endpoint_residual=Tuple(Float64.(trial_assembly.residual[endpoint_rows]))
                    endpoint_max=maximum(abs,endpoint_residual;init=0.0)
                    endpoint_tolerance=64eps(Float64)*max(1.0,
                        maximum(abs,(geometry.psi_axis_Wb_per_rad,
                            geometry.psi_boundary_Wb_per_rad);init=0.0))
                    pressure_trace=try
                        Base.invokelatest(component.lcfs_profile_current_trace,trial_state;
                            pressure_only=true,dynamic_geometry=true,with_jacobian=false)
                    catch err
                        err isa DomainError ? nothing : rethrow()
                    end
                    pressure_trace_status=pressure_trace===nothing ? :not_executed :
                        get(pressure_trace,:status,:typed_absent)
                    pressure_residual=pressure_trace!==nothing &&
                        pressure_trace_status===:evaluated_dynamic_LCFS_pressure_only &&
                        hasproperty(pressure_trace,:pressure_residual) &&
                        get(pressure_trace,:pressure_row_count,0)==64 &&
                        length(pressure_trace.pressure_residual)==64 &&
                        all(isfinite,pressure_trace.pressure_residual) &&
                        get(pressure_trace,:candidate_hash,nothing)==component.candidate_hash &&
                        get(pressure_trace,:context_hash,nothing)==component.context_hash &&
                        hasproperty(pressure_trace,:dynamic_geometry) &&
                        Tuple(pressure_trace.dynamic_geometry.coordinates_RZ_m)==
                            Tuple(geometry.coordinates_RZ_m) ?
                        Tuple(Float64.(pressure_trace.pressure_residual)) : nothing
                    pressure_max_residual=pressure_residual===nothing ? nothing :
                        maximum(abs,pressure_residual;init=0.0)
                    pressure_final_gate=pressure_max_residual===nothing ? :not_executed :
                        pressure_max_residual<=1.0e-8
                    accepted_trial=(alpha=alpha,state=Tuple(trial_state),
                        residual=Tuple(Float64.(trial_assembly.residual)),
                        equality_residual=Tuple(Float64.(trial_assembly.equality_residual)),
                        merit=trial_merit,merit_reduction=merit_reduction,
                        endpoint_residual=endpoint_residual,endpoint_max=endpoint_max,
                        endpoint_tolerance=endpoint_tolerance,
                        endpoint_final_gate=endpoint_max<=endpoint_tolerance,
                        span_projection_raw=span_projection_raw,
                        pressure_trace_status=pressure_trace_status,
                        pressure_coverage_status=pressure_residual===nothing ?
                            :not_executed_missing_same_state_64_finite_trace : :evaluated_same_state_64,
                        pressure_residual=pressure_residual,
                        pressure_max_residual=pressure_max_residual,
                        pressure_final_gate=pressure_final_gate)
                    push!(trial_records,(alpha=alpha,status=:accepted,
                        reason=:strict_frozen_scaled_nonlinear_merit_decrease,
                        merit_after=trial_merit,merit_reduction=merit_reduction,
                        geometry_source=geometry_source,span_projection_raw=span_projection_raw))
                    trial_assembly=nothing;trial_result=nothing;geometry=nothing;pressure_trace=nothing
                    trial_state=nothing;row_index=nothing;ls_rows=nothing
                    trial_ls=nothing;trial_eq=nothing;GC.gc(false)
                    break
                end
                push!(trial_records,(alpha=alpha,status=:no_descent,
                    reason=:nonlinear_merit_not_strictly_decreased,
                    merit_after=trial_merit,merit_reduction=merit_reduction,
                    geometry_source=geometry_source,span_projection_raw=span_projection_raw))
                trial_assembly=nothing;trial_result=nothing;geometry=nothing
                trial_state=nothing;row_index=nothing;ls_rows=nothing
                trial_ls=nothing;trial_eq=nothing;GC.gc(false)
            end
            trial_status=accepted_trial!==nothing ? :accepted :
                (isempty(actual_trial_metrics) ? :typed_guard : :no_descent)
            trial_hash_payload=accepted_trial===nothing ?
                (alphas=Tuple(Float64(r.alpha) for r in trial_records),
                 initial_merit=Float64(base_merit),
                 actual_metrics=Tuple((Float64(r.alpha),Float64(r.merit_after),
                     Float64(r.merit_reduction),Float64(r.max_abs_scaled_equilibrium),
                     Float64(r.max_abs_scaled_equality),Float64(r.max_abs_raw_equilibrium),
                     Float64(r.max_abs_raw_equality)) for r in actual_trial_metrics)) :
                (alpha=Float64(accepted_trial.alpha),state=accepted_trial.state,
                 residual=accepted_trial.residual,equality_residual=accepted_trial.equality_residual,
                 pressure_residual=accepted_trial.pressure_residual,
                 merit_before=Float64(base_merit),merit_after=Float64(accepted_trial.merit))
            trial_result_hash=string(F.canonical_hash(trial_hash_payload))
            println("G2_GLOBAL_NONLINEAR_TRIAL_CONSUMER status=",trial_status,
                " trials=",Tuple(trial_records),
                " baseline_scaled_merit=",base_merit,
                " accepted_alpha=",accepted_trial===nothing ? nothing : accepted_trial.alpha,
                " accepted_scaled_merit=",accepted_trial===nothing ? nothing : accepted_trial.merit,
                " actual_merit_reduction=",accepted_trial===nothing ? nothing : accepted_trial.merit_reduction,
                " endpoint_final_gate=",accepted_trial===nothing ? nothing : accepted_trial.endpoint_final_gate,
                " endpoint_max_Wb_per_rad=",accepted_trial===nothing ? nothing : accepted_trial.endpoint_max,
                " endpoint_tolerance_Wb_per_rad=",accepted_trial===nothing ? nothing : accepted_trial.endpoint_tolerance,
                " pressure_trace_status=",accepted_trial===nothing ? nothing : accepted_trial.pressure_trace_status,
                " pressure_coverage_status=",accepted_trial===nothing ? :not_executed : accepted_trial.pressure_coverage_status,
                " pressure_max_residual_Pa=",accepted_trial===nothing ? nothing : accepted_trial.pressure_max_residual,
                " pressure_final_gate=",accepted_trial===nothing ? nothing : accepted_trial.pressure_final_gate,
                " numeric_result_hash=",trial_result_hash,
                " claim_ceiling=diagnostic_only physical_validation=false")
            flush(stdout)
            if require_acceptance
                @test trial_status===:accepted
            end
            if accepted_trial!==nothing
                @test accepted_trial.merit_reduction>0.0
                @test any(power->accepted_trial.alpha==0.5^power,
                    min_alpha_power:max_alpha_power)
            end
        end
    (status=trial_status,accepted_trial=accepted_trial,trial_records=Tuple(trial_records),kkt_partition=kkt_partition)
end

Base.@noinline Base.@nospecializeinfer function _g2_resume_saved_gs_u_plus_trial_v1(S,F,component,trace,provider,composed,regional,diagnostic_model,candidate_scaling,scale_contract,run_leaf)
    Base.@nospecialize S F component trace provider composed regional diagnostic_model candidate_scaling scale_contract run_leaf
    pp=get(ENV,"FUSION_G2_SAVED_GS_U_PLUS_RAW_PATH",""); ps=lowercase(get(ENV,"FUSION_G2_SAVED_GS_U_PLUS_RAW_SHA256",""))
    bp=get(ENV,"FUSION_G2_PRECHECK_SAVED_NUMERIC_BASELINE_PATH",""); bs=lowercase(get(ENV,"FUSION_G2_PRECHECK_SAVED_NUMERIC_BASELINE_SHA256",""))
    reuse_minus_raw_flag=get(ENV,"FUSION_G2_REUSE_SAVED_GS_U_MINUS_RAW","0")
    reuse_minus_raw_flag in ("0","1") || error("saved minus raw reuse flag must be 0 or 1")
    reuse_minus_raw_sha=lowercase(get(ENV,"FUSION_G2_SAVED_GS_U_MINUS_RAW_SHA256",""))
    all(p->!isempty(p)&&isfile(p),(pp,bp)) || error("saved baseline and plus raw are required")
    occursin(r"^[0-9a-f]{64}$",ps)&&_g2_global_diag_result_file_sha256(pp)==ps || error("plus raw SHA mismatch")
    occursin(r"^[0-9a-f]{64}$",bs)&&_g2_global_diag_result_file_sha256(bp)==bs || error("saved baseline SHA mismatch")
    plus=open(Serialization.deserialize,pp,"r"); plus.schema=="saved-baseline-gs-u-plus-assembly-raw-v1" || error("plus raw schema mismatch")
    plus.baseline_path==bp&&plus.baseline_sha256==bs || error("saved plus is not bound to its pinned baseline result")
    bs=="10622ee1c5613d2896365056d692ab84850c38cb525304fd5e8c682f038ee2f9" || error("plus baseline digest differs from the completed R1 input")
    n=length(component.initial_state);u=Int(first(component.profile_coefficient_columns));rows=findall(x->occursin(":GS4:",x),regional.equation_ids)
    expected_state=copy(component.initial_state);pd=first(i for i in component.pressure_dofs if i>0);expected_state[pd]+=1.0
    law=component.profile_law;kc=first(k for k in eachindex(component.core_mask) if component.core_mask[k]&&0.3<(component.initial_state[4k]-law.psi_boundary_wb_per_rad)/(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)<0.7)
    expected_state[4kc]+=1e-4*(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad);ac,bc=component.profile_span_columns
    hs=1e-8*abs(component.initial_state[ac]-component.initial_state[bc]);expected_state[ac]+=hs;expected_state[bc]-=hs
    h=1e-3*max(1.0,abs(expected_state[u]));expected_plus=copy(expected_state);expected_plus[u]+=h
    plus.state==expected_plus&&plus.u_column==u&&plus.step==h||error("saved plus state/step differs from the exact R4 perturbation")
    pa=plus.result.diagnostic_assembly
    plus.result.status===:typed_absent&&plus.result.missing_closures==S._REQUIRED_CLOSURES&&pa.status===:incomplete_assembly&&pa.claim_ceiling===:diagnostic_only&&!pa.physical_authority||error("saved plus status/claim ceiling differs")
    all(c->c.passed,pa.jacobian_checks.regional)&&all(c->c.passed,pa.jacobian_checks.outer)&&pa.jacobian_checks.global_conservation.passed||error("saved plus original oracles fail")
    pa.residual_scaling===:frozen_row_scales&&pa.equilibrium_row_scales==scale_contract.equilibrium.characteristics&&
      pa.equilibrium_row_scale_hash==string(F.canonical_hash(scale_contract.equilibrium.characteristics))||error("saved plus frozen scale contract differs")
    pa.equation_ids.regional==(Tuple(regional.equation_ids),)&&pa.equation_ids.outer==(composed.outer.constraint_ids,)&&pa.equation_ids.conservation==Tuple(provider.conservation_ids)||error("saved plus row ownership differs")
    rp=Float64.(pa.residual[rows]);all(isfinite,rp)||error("saved plus selected residual is nonfinite")
    plus_analytic=Float64.(plus.baseline_analytic_gs_u);all(isfinite,plus_analytic)&&any(!iszero,plus_analytic)||error("saved plus analytic GS-u column invalid")
    state=copy(expected_state);expected_state=nothing;expected_plus=nothing;plus=nothing;pa=nothing;GC.gc(true)
    qualified_path=joinpath(@__DIR__,"..","runs","e","up2_continuous_psi_global_numeric_capture_20261012_r4","preoracle_checkpoint","result_data","g2_global_diagnostic","numeric_matrices_v3.jls")
    qualified=_g2_global_diag_reload_matrices(qualified_path;expected_sha256="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec")
    m=qualified.replay_metadata;id=m.consumer_identity
    baseline=_g2_global_diag_reload_matrices(bp;expected_sha256=bs);bm=baseline.replay_metadata;bid=bm.consumer_identity
    bm.validation_stage===:global_oracles_passed&&bid.scope===:diagnostic_incomplete_global_assembly || error("saved completed baseline scope differs")
    all(k->hasproperty(bid,k)&&hasproperty(id,k),(:candidate_hash,:trace_hash,:current_operator_model_id,:hagenow_source_operator_model_id,:provider_id,:component_context_hash,:scale_contract_hash,:scale_policy)) || error("saved baseline semantic identity incomplete")
    all(k->isequal(getproperty(bid,k),getproperty(id,k)),(:candidate_hash,:trace_hash,:current_operator_model_id,:hagenow_source_operator_model_id,:provider_id,:component_context_hash,:scale_contract_hash,:scale_policy)) || error("saved baseline and qualified capture semantic identities differ")
    baseline.jacobian==qualified.jacobian&&baseline.equality_jacobian==qualified.equality_jacobian&&baseline.residual==qualified.residual&&baseline.equality_residual==qualified.equality_residual || error("saved baseline numeric R/J/C/c differs from qualified R4 capture")
    baseline.state==qualified.state&&Tuple(baseline.column_scales)==Tuple(qualified.column_scales)&&Tuple(baseline.least_squares_row_scales)==Tuple(qualified.least_squares_row_scales)&&Tuple(baseline.equality_row_scales)==Tuple(qualified.equality_row_scales) || error("saved baseline state/scales differ from qualified R4 capture")
    m.validation_stage===:pre_global_assembler_oracles_pending&&id.scope===:diagnostic_incomplete_global_assembly || error("qualified R4 baseline scope differs")
    all(k->hasproperty(id,k),(:candidate_hash,:trace_hash,:current_operator_model_id,:hagenow_source_operator_model_id,:provider_id,:component_context_hash,:scale_contract_hash,:scale_policy)) || error("qualified R4 semantic identity incomplete")
    id.candidate_hash==component.candidate_hash&&id.trace_hash==trace.trace_hash&&id.current_operator_model_id===component.current_operator_model_id&&
      id.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id&&id.provider_id==diagnostic_model.provider_id&&
      id.component_context_hash==component.context_hash&&id.scale_contract_hash==scale_contract.contract_hash&&id.scale_policy===scale_contract.scale_policy || error("qualified R4 semantic identity differs from live source")
    size(qualified.jacobian)==(length(regional.equation_ids),n)&&size(qualified.equality_jacobian)==(length(scale_contract.equalities.row_ids),n)||error("qualified R4 J/C dimensions differ")
    m.data_identity.jacobian_dimensions==size(qualified.jacobian)&&m.data_identity.jacobian_nnz==SparseArrays.nnz(qualified.jacobian)&&
      m.data_identity.equality_jacobian_dimensions==size(qualified.equality_jacobian)&&m.data_identity.equality_jacobian_nnz==SparseArrays.nnz(qualified.equality_jacobian)||error("qualified R4 matrix metadata differs")
    Tuple(m.ordered_ids.least_squares_raw)==Tuple(regional.equation_ids)&&Tuple(m.ordered_ids.equality_base)==Tuple(scale_contract.equalities.row_ids)&&
      Tuple(m.ordered_ids.endpoint)==Tuple(component.dynamic_span_equation_ids)&&Tuple(m.pressure_indices)==Tuple(i for i in component.pressure_dofs if i>0)||error("qualified R4 ordered row/pressure maps differ")
    Tuple(qualified.column_scales)==Tuple(candidate_scaling.column_scales)&&Tuple(qualified.least_squares_row_scales)==Tuple(diagnostic_model.equilibrium_row_scales)&&
      Tuple(qualified.equality_row_scales)==Tuple(scale_contract.equalities.characteristics)||error("qualified R4 scales differ")
    er=collect(component.dynamic_span_row_range);ei=Tuple(component.dynamic_span_equation_ids);lsrows=[i for i in 1:length(regional.equation_ids) if !(i in Set(er))]
    Tuple(m.endpoint_row_indices)==Tuple(er)&&Tuple(m.least_squares_row_indices)==Tuple(lsrows)&&
      Tuple(m.equality_base_row_indices)==Tuple(1:length(scale_contract.equalities.row_ids))&&
      Tuple(m.equality_endpoint_positions)==Tuple(length(scale_contract.equalities.row_ids)+i for i in eachindex(er))||error("qualified R4 exact row positions differ")
    state==qualified.state&&state==baseline.state||error("saved diagnostic state differs from qualified R4 baseline")
    analytic=Float64[qualified.jacobian[r,u] for r in rows];all(isfinite,analytic)&&any(!iszero,analytic)&&analytic==plus_analytic||error("qualified analytic GS-u column differs from plus capture")
    plus_analytic=nothing
    stepdir=get(ENV,"FUSION_G2_SAVED_STEP_RESULT_DATA_DIR","");isdir(stepdir)||error("saved step result_data directory absent")
    corepath=joinpath(stepdir,"gs_inverse_full_kkt_core_result_v1.jls");bundlepath=joinpath(stepdir,"gs_inverse_full_kkt_numeric_step_v1.jls");candpath=joinpath(stepdir,"gs_inverse_full_kkt_candidate_v1.jls")
    core=open(Serialization.deserialize,corepath,"r");bundle=open(Serialization.deserialize,bundlepath,"r");cand=open(Serialization.deserialize,candpath,"r")
    core.schema===:actual_R4_exact_row_pivot_full_kkt_core_result_v1&&bundle.schema===:actual_R4_exact_row_pivot_numeric_step_v1&&cand.schema===:actual_R4_exact_row_pivot_full_kkt_candidate_v1||error("saved KKT schemas differ")
    capture="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec";core.capture_sha256==bundle.capture_sha256==capture||error("saved step is not bound to qualified R4 capture")
    cand.core_result_sha256==_g2_global_diag_result_file_sha256(corepath)||error("candidate/core digest mismatch")
    statehash=bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(state))));bundle.state_sha256==statehash==cand.state_sha256||error("saved step state hash differs")
    step=Float64.(bundle.step);stephash=bytes2hex(SHA.sha256(reinterpret(UInt8,step)));bundle.step_sha256==cand.step_sha256==stephash&&length(step)==length(state)&&all(isfinite,step)||error("saved step vector/digest invalid")
    actual=core.result
    actual.status===:ok&&actual.state_before==state&&actual.step==step&&Tuple(actual.column_scales)==Tuple(candidate_scaling.column_scales)&&
      Tuple(actual.pressure_indices)==Tuple(i for i in component.pressure_dofs if i>0)||error("saved step state/scales/pressure map differ")
    actual.original_kkt_gate===true&&actual.true_kkt_gate===true&&actual.pressure_bound_gate===true&&actual.dual_gate===true&&actual.true_kkt_relative_defect<=1e-8&&actual.stationarity<=1e-6&&
      actual.dual_violation==0.0&&actual.complementarity==0.0&&actual.pressure_lower_bound_violation==0.0||error("saved core KKT/bound gates fail")
    cand.status===:ok&&cand.original_kkt_gate===true&&cand.pressure_bound_gate===true&&cand.true_kkt_relative_defect<=1e-8&&cand.stationarity<=1e-6&&
      cand.schur_rank==cand.schur_dimension&&cand.dual_violation==0.0&&cand.complementarity==0.0&&cand.pressure_lower_bound_violation==0.0||error("saved candidate gates fail")
    actual.rank_certificate===:not_established_for_full_G&&cand.rank_certificate===:not_established_for_full_G&&actual.full_global_kkt===false&&cand.full_global_kkt===false&&cand.science_credit===false||error("saved evidence ceiling differs")
    kkt_step=(step=step,);actual=nothing;plus=nothing;pa=nothing;qualified=nothing;m=nothing;id=nothing;baseline=nothing;bm=nothing;bid=nothing;core=nothing;bundle=nothing;cand=nothing;expected_state=nothing;expected_plus=nothing;GC.gc(true)
    minus=copy(state);minus[u]-=h;out=joinpath(run_leaf,"result_data","g2_global_diagnostic");mkpath(out)
    if reuse_minus_raw_flag=="1"
        mp=get(ENV,"FUSION_G2_SAVED_GS_U_MINUS_RAW_PATH","")
        !isempty(mp)&&isfile(mp)&&occursin(r"^[0-9a-f]{64}$",reuse_minus_raw_sha) || error("saved minus raw path/SHA is required")
        ms=_g2_global_diag_result_file_sha256(mp);ms==reuse_minus_raw_sha || error("saved minus raw SHA mismatch")
        saved_minus=open(Serialization.deserialize,mp,"r")
        saved_minus.schema=="saved-baseline-gs-u-minus-assembly-raw-v1" || error("saved minus raw schema mismatch")
        saved_minus.state==minus&&saved_minus.step==h&&saved_minus.u_column==u&&
            saved_minus.baseline_path==bp&&saved_minus.baseline_sha256==bs&&
            saved_minus.plus_path==pp&&saved_minus.plus_sha256==ps || error("saved minus raw state/step/input binding differs")
        mr=saved_minus.result
        hasproperty(mr,:candidate_hash)&&mr.candidate_hash==component.candidate_hash || error("saved minus source candidate differs")
        mb=filesize(mp);saved_minus=nothing
        println("G2_SAVED_BASELINE_GS_U_MINUS_RAW_REUSE status=sha_and_binding_pass path=",mp," bytes=",mb," sha256=",ms," minus_reassembly=false");flush(stdout)
    else
        mp=joinpath(out,"saved_baseline_gs_u_minus_assembly_raw_v1.jls");ispath(mp)&&error("minus raw already exists")
        println("G2_SAVED_BASELINE_GS_U_MINUS_BEGIN baseline_reassembly=false plus_reassembly=false gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        mr=S.assemble_coupled_mhd_global_v1(diagnostic_model,minus;allow_incomplete=true)
        open(mp,"w") do io;Serialization.serialize(io,(schema="saved-baseline-gs-u-minus-assembly-raw-v1",result=mr,state=minus,step=h,u_column=u,baseline_path=bp,baseline_sha256=bs,plus_path=pp,plus_sha256=ps));flush(io);end
        ms=_g2_global_diag_result_file_sha256(mp);mb=filesize(mp)
    end
    ma=mr.diagnostic_assembly
    mr.status===:typed_absent&&mr.missing_closures==S._REQUIRED_CLOSURES&&ma.status===:incomplete_assembly&&ma.claim_ceiling===:diagnostic_only&&!ma.physical_authority||error("minus status/claim ceiling differs")
    all(c->c.passed,ma.jacobian_checks.regional)&&all(c->c.passed,ma.jacobian_checks.outer)&&ma.jacobian_checks.global_conservation.passed||error("minus original oracles fail")
    ma.residual_scaling===:frozen_row_scales&&ma.equilibrium_row_scales==scale_contract.equilibrium.characteristics&&ma.equilibrium_row_scale_hash==string(F.canonical_hash(scale_contract.equilibrium.characteristics))||error("minus frozen scales differ")
    ma.equation_ids.regional==(Tuple(regional.equation_ids),)&&ma.equation_ids.outer==(composed.outer.constraint_ids,)&&ma.equation_ids.conservation==Tuple(provider.conservation_ids)||error("minus row ownership differs")
    rm=Float64.(ma.residual[rows]);fd=(rp-rm)./(2h);close=isapprox(fd,analytic;rtol=5e-6,atol=1e-9);@test any(!iszero,analytic)&&close
    println("G2_SAVED_BASELINE_GS_U_CENTRAL_FD pass=",close," h=",h," absdefect=",maximum(abs,fd-analytic;init=0.0)," minus_raw=",mp," bytes=",mb," sha256=",ms);flush(stdout)
    ma=nothing;mr=nothing;GC.gc(true)
    q=_g2_global_diag_reload_matrices(qualified_path;expected_sha256=capture);rawids=collect(regional.equation_ids);er=collect(component.dynamic_span_row_range);ei=Tuple(component.dynamic_span_equation_ids)
    lsrows=[i for i in eachindex(q.residual) if !(i in Set(er))];lsids=Tuple(rawids[lsrows]);lss=Float64[q.least_squares_row_scales[i] for i in lsrows]
    eqids=(Tuple(scale_contract.equalities.row_ids)...,ei...);eqs=vcat(collect(Float64.(scale_contract.equalities.characteristics)),Float64[q.least_squares_row_scales[i] for i in er])
    part=S.weighted_residual_kkt_partition_v1(candidate_hash=diagnostic_model.candidate_hash,
      consumer_identity=(candidate_hash=diagnostic_model.candidate_hash,provider_id=diagnostic_model.provider_id,model_hash=diagnostic_model.model_hash,
        component_context_hash=component.context_hash,trace_hash=trace.trace_hash,scale_contract_hash=scale_contract.contract_hash,scale_policy=scale_contract.scale_policy,scope=:diagnostic_incomplete_global_assembly),
      least_squares_row_ids=lsids,least_squares_residual=q.residual[lsrows],least_squares_jacobian=q.jacobian[lsrows,:],least_squares_row_scales=lss,
      equality_row_ids=eqids,equality_row_scales=eqs,equality_residual=vcat(q.equality_residual,q.residual[er]),
      equality_jacobian=[q.equality_jacobian;q.jacobian[er,:]])
    base_merit=part.merit;q=nothing;GC.gc(true)
    part=merge(part,(raw_least_squares_jacobian=nothing,raw_equality_jacobian=nothing,
        scaled_least_squares_jacobian=nothing,equality_jacobian=nothing));GC.gc(true)
    diagnostic=(diagnostic_assembly=(jacobian=nothing,equality_jacobian=nothing,),)
    hasproperty(diagnostic,:diagnostic_assembly) &&
        hasproperty(diagnostic.diagnostic_assembly,:jacobian) &&
        hasproperty(diagnostic.diagnostic_assembly,:equality_jacobian) ||
        error("actual nonlinear trial diagnostic input shape is invalid")
    length(er)==2&&length(ei)==2&&_g2_actual_pressure_dof_map_matches_v1(component) ||
        error("actual nonlinear trial endpoint/pressure ABI differs")
    regional=nothing;GC.gc(true)
    geometry_reuse_flag=get(ENV,"FUSION_G2_SAVED_GEOMETRY_RAW_REUSE","0")
    geometry_reuse_flag in ("0","1") || error("saved geometry raw reuse flag must be 0 or 1")
    geometry_cache=nothing;max_alpha_power=3
    geometry_raw_replay_preflight_flag=get(ENV,"FUSION_G2_SAVED_GEOMETRY_RAW_REPLAY_PREFLIGHT_ONLY","0")
    geometry_raw_replay_preflight_flag in ("0","1") || error("saved geometry replay preflight flag must be 0 or 1")
    if geometry_raw_replay_preflight_flag=="1"
        geometry_reuse_flag=="1" || error("saved geometry replay preflight requires saved geometry cache reuse")
    end
    if geometry_reuse_flag=="1"
        geometry_identity=(candidate_hash=component.candidate_hash,component_context_hash=component.context_hash,
            trace_hash=trace.trace_hash,current_operator_model_id=component.current_operator_model_id,
            hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
            field_model_id=component.native_field_model_id,capture_sha256=capture,
            step_sha256=stephash,state_sha256=statehash)
        geometry_identity.trace_hash==trace.trace_hash || error("saved geometry cache trace identity differs from the live trace")
        runroot=normpath(joinpath(@__DIR__,"..","runs","e"))
        specifications=((alpha=1.0,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r1",file="saved_step_dynamic_geometry_trial_0_raw_v1.jls",sha="1e5f888a03da135c38036b751189a43a47731592935a01d1de29bb781e89b5db",expected=:mask_changed),
            (alpha=0.5,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r1",file="saved_step_dynamic_geometry_trial_1_raw_v1.jls",sha="3ec00261ece7f5029dfa90f4fbb3a3de266639518cd408716cc578808b0d9843",expected=:mask_changed),
            (alpha=0.25,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r1",file="saved_step_dynamic_geometry_trial_2_raw_v1.jls",sha="6179b817a6171db86728e28e3b109a7f5d2b94642ba2bf44f5d2c72cc92f41ff",expected=:mask_changed),
            (alpha=0.125,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r1",file="saved_step_dynamic_geometry_trial_3_raw_v1.jls",sha="8b027b872b90b0477c98a78df44b10b398406a9d78e45387c34a9a6a0f9b2554",expected=:mask_changed),
            (alpha=0.0625,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r2",file="saved_step_dynamic_geometry_trial_0_raw_v1.jls",sha="bfa5c4f31abcfdbc30eba8b69a236b9cbc071ca5d50fe04401a5dc0997739821",expected=:mask_changed),
            (alpha=0.03125,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r2",file="saved_step_dynamic_geometry_trial_1_raw_v1.jls",sha="19fcdf6196228d3db3df68be7ebed0354755363da34dd8fbb9da298ae57f46f4",expected=:mask_changed),
            (alpha=0.015625,leaf="up2_saved_minus_dynamic_geometry_probe_20261014_r2",file="saved_step_dynamic_geometry_trial_2_raw_v1.jls",sha="e054b51fa86f96e43ae6c9584b41b7102bf9a9a8f3acaddd70f7dd5a0e5cd5e2",expected=:geometry_gate_pass))
        geometry_entries=Tuple((alpha=spec.alpha,path=joinpath(runroot,spec.leaf,"result_data","g2_global_diagnostic",spec.file),
            sha256=spec.sha,expected=spec.expected) for spec in specifications)
        geometry_cache=(identity=geometry_identity,records=geometry_entries)
        max_alpha_power=geometry_raw_replay_preflight_flag=="1" ? 6 : 12
        println("G2_SAVED_GEOMETRY_RAW_REUSE_BEGIN cached_alphas=",Tuple(spec.alpha for spec in specifications),
            " first_live_geometry_alpha=",2.0^(-7)," max_alpha_power=",max_alpha_power);flush(stdout)
    end
    tr=_g2_actual_nonlinear_trial_consumer_v1(S,F,component,composed,provider,nothing,diagnostic_model,scale_contract,part,kkt_step,state,run_leaf,er,ei,diagnostic;
        geometry_cache=geometry_cache,max_alpha_power=max_alpha_power)
    reportpath=joinpath(out,"saved_baseline_gs_u_minus_fd_trial_report_v1.jls");ispath(reportpath)&&error("continuation report exists")
    report=(schema="saved-baseline-gs-u-minus-fd-trial-report-v1",trial=(status=tr.status,accepted_trial=tr.accepted_trial,records=tr.trial_records),
      abi_preflight_only=(get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")=="1"),
      geometry_raw_replay_preflight_only=(get(ENV,"FUSION_G2_SAVED_GEOMETRY_RAW_REPLAY_PREFLIGHT_ONLY","0")=="1"),central_fd_pass=close,
      fd_abs_defect=maximum(abs,fd-analytic;init=0.0),minus_raw_path=mp,minus_raw_sha256=ms,plus_raw_path=pp,plus_raw_sha256=ps,
      baseline_path=bp,baseline_sha256=bs,minus_raw_reused=(reuse_minus_raw_flag=="1"),kkt_rerun=false,saved_step_reused=true,baseline_scaled_merit=base_merit,
      rank_certificate=:not_established_for_full_G,full_global_kkt=false,science_credit=false,closure_credit=false,physical_validation=false)
    open(reportpath,"w") do io;Serialization.serialize(io,report);flush(io);end
    println("G2_SAVED_BASELINE_GS_U_PLUS_RESUME status=",tr.status," report_path=",reportpath," baseline_reassembly=false plus_reassembly=false kkt_rerun=false closure_credit=false physical_validation=false");flush(stdout)
    (status=tr.status,report_path=reportpath,report=report)
end

"Numeric-only full-shape memory/equality gate; never loads a physical provider."
function test_g2_map_memory_numeric()
@testset "G2 full-shape CSC stream equality and difference rejection" begin
    # The old full-width slices/vcat/P*B path remains the independent reference.
    function old_reference(actual_B,sources,row_maps,normals)
        nB,ncolumns=size(actual_B);nface=length(normals)
        source_ids=zeros(Int,nB);source_rows=zeros(Int,nB)
        for (source_id,rows) in enumerate(row_maps), row in eachindex(rows)
            source_ids[rows[row]]=source_id;source_rows[rows[row]]=row
        end
        blocks=SparseArrays.SparseMatrixCSC{Float64,Int}[]
        incidence_equal=trues(nface)
        for i in 1:nface
            rows=3i-2:3i;source_id=source_ids[first(rows)];first_row=source_rows[first(rows)]
            all(source_ids[row]==source_id && source_rows[row]==first_row+row-first(rows) for row in rows) ||
                error("numeric reference needs intact three-row incidence blocks")
            block=sources[source_id][first_row:first_row+2,:]
            incidence_equal[i]=actual_B[rows,:]==block
            push!(blocks,block)
        end
        expected_B=vcat(blocks...)
        pr=Int[];pc=Int[];pv=Float64[]
        for i in 1:nface
            nr,nz=normals[i]
            nr==0.0 || (push!(pr,i);push!(pc,3i-2);push!(pv,nr))
            nz==0.0 || (push!(pr,i);push!(pc,3i);push!(pv,nz))
        end
        expected_normal=SparseArrays.sparse(pr,pc,pv,nface,nB)*expected_B
        (B=expected_B,normal=expected_normal,incidence_equal=incidence_equal)
    end
    # Warm both exact callables on small dimensions, then measure full shapes.
    tiny=[SparseArrays.sparse([1,3],[4,8],[0.5,-0.25],3,8) for _ in 1:4]
    tiny_maps=[collect(3k-2:3k) for k in 1:4]
    tiny_normals=[(-1.0,0.0),(1.0,0.0),(0.0,-1.0),(0.0,1.0)]
    tiny_B=vcat(tiny...);tiny_ref=old_reference(tiny_B,tiny,tiny_maps,tiny_normals)
    @test all(all,_test_g2_map_csc_equal_rows(tiny_B,tiny_ref.normal,tiny,tiny_maps,tiny_normals))
    tiny=nothing;tiny_maps=nothing;tiny_B=nothing;tiny_ref=nothing;GC.gc()

    nr=nz=129;ncolumns=69443;nface=516
    side_ids=([j for j in 1:nz],[(nr-1)*nz+j for j in 1:nz],
        [(i-1)*nz+1 for i in 1:nr],[i*nz for i in 1:nr])
    sources=SparseArrays.SparseMatrixCSC{Float64,Int}[]
    for ids in side_ids
        rr=Int[];cc=Int[];vv=Float64[]
        for (q,k) in enumerate(ids)
            i=cld(k,nz);j=mod1(k,nz)
            for l in 1:nz
                push!(rr,3q-2);push!(cc,4*((i-1)*nz+l));push!(vv,-(l+j+1)/1024)
            end
            for l in 1:nr
                push!(rr,3q);push!(cc,4*((l-1)*nz+j));push!(vv,(2l+i+1)/2048)
            end
        end
        push!(sources,SparseArrays.sparse(rr,cc,vv,387,ncolumns))
    end
    # Actual native column support, but deliberately synthetic exact values:
    # this fixture carries no FreeGS/Green/physical-result credit.
    sources[1].nzval[end]=0.0
    row_maps=[collect(387(k-1)+1:387k) for k in 1:4]
    normals=vcat(fill((-1.0,0.0),129),fill((1.0,0.0),129),
        fill((0.0,-1.0),129),fill((0.0,1.0),129))
    actual_B=vcat(sources...)
    normal_rows=[normals[i][1]!=0.0 ? 3i-2 : 3i for i in 1:nface]
    normal_sign=[normals[i][1]!=0.0 ? normals[i][1] : normals[i][2] for i in 1:nface]
    actual_normal=actual_B[normal_rows,:]
    for pointer in eachindex(actual_normal.nzval)
        actual_normal.nzval[pointer]*=normal_sign[actual_normal.rowval[pointer]]
    end
    @test size(actual_B)==(1548,69443) && size(actual_normal)==(516,69443)
    @test length(unique(vcat(side_ids...)))==512
    @test all(matrix->size(matrix)==(387,69443),sources)
    GC.gc();old_live_before=Base.gc_live_bytes()
    println("G2_MAP_MEMORY_PHASE old_BEGIN unix_s=",time());flush(stdout)
    old_measured=@timed old_reference(actual_B,sources,row_maps,normals)
    println("G2_MAP_MEMORY_PHASE old_END unix_s=",time()," allocated_bytes=",old_measured.bytes,
        " elapsed_s=",old_measured.time," gc_live_delta_bytes=",Base.gc_live_bytes()-old_live_before);flush(stdout)
    reference=old_measured.value
    @test all(reference.incidence_equal) && actual_B==reference.B && actual_normal==reference.normal
    GC.gc();new_live_before=Base.gc_live_bytes()
    println("G2_MAP_MEMORY_PHASE stream_BEGIN unix_s=",time());flush(stdout)
    new_measured=@timed _test_g2_map_csc_equal_rows(actual_B,actual_normal,sources,row_maps,normals)
    println("G2_MAP_MEMORY_PHASE stream_END unix_s=",time()," allocated_bytes=",new_measured.bytes,
        " elapsed_s=",new_measured.time," gc_live_delta_bytes=",Base.gc_live_bytes()-new_live_before);flush(stdout)
    @test all(all,new_measured.value)
    @test new_measured.bytes<old_measured.bytes
    # Every mutation below calls the same comparator as the actual consumer.
    checked=Symbol[]
    function compare_case(name,B,N,expected;maps=row_maps,ref=reference)
        rows=_test_g2_map_csc_equal_rows(B,N,sources,maps,normals)
        actual=(all(rows[1]),all(rows[2]))
        @test actual==(B==ref.B,N==ref.normal)==expected
        push!(checked,name)
    end
    bp=findfirst(v->!iszero(v),actual_B.nzval);bc=searchsortedlast(actual_B.colptr,bp);br=actual_B.rowval[bp]
    np=findfirst(v->!iszero(v),actual_normal.nzval);nc=searchsortedlast(actual_normal.colptr,np);nn=actual_normal.rowval[np]
    changed=copy(actual_B);changed.nzval[bp]+=1.0
    compare_case(:stored_B_value,changed,actual_normal,(false,true))
    changed=copy(actual_B);changed[2,ncolumns]=1.0
    compare_case(:extra_B_inactive_last_column,changed,actual_normal,(false,true))
    changed=copy(actual_B);changed[br,bc]=0.0;SparseArrays.dropzeros!(changed)
    compare_case(:missing_B_value,changed,actual_normal,(false,true))
    changed_normal=copy(actual_normal);changed_normal.nzval[np]*=-1.0
    compare_case(:stored_normal_value,actual_B,changed_normal,(true,false))
    changed_normal=copy(actual_normal);changed_normal[1,ncolumns]=1.0
    compare_case(:extra_normal_inactive_last_column,actual_B,changed_normal,(true,false))
    changed_normal=copy(actual_normal);changed_normal[nn,nc]=0.0;SparseArrays.dropzeros!(changed_normal)
    compare_case(:missing_normal_value,actual_B,changed_normal,(true,false))
    changed=copy(actual_B);changed[2,ncolumns]=1.0;changed[2,ncolumns]=0.0
    changed_normal=copy(actual_normal);changed_normal[1,ncolumns]=1.0;changed_normal[1,ncolumns]=0.0
    @test SparseArrays.nnz(changed)==SparseArrays.nnz(actual_B)+1
    @test SparseArrays.nnz(changed_normal)==SparseArrays.nnz(actual_normal)+1
    compare_case(:explicit_zeros_added,changed,changed_normal,(true,true))
    SparseArrays.dropzeros!(changed);SparseArrays.dropzeros!(changed_normal)
    compare_case(:explicit_zeros_removed,changed,changed_normal,(true,true))
    corner_maps=deepcopy(row_maps);corner_maps[1][1:6]=corner_maps[1][[4,5,6,1,2,3]]
    wrong_reference=old_reference(actual_B,sources,corner_maps,normals)
    compare_case(:wrong_corner_row_map,actual_B,actual_normal,(false,false);maps=corner_maps,ref=wrong_reference)
    @test length(checked)==9 && length(unique(checked))==9
    println("G2_MAP_MEMORY_NUMERIC_COMPLETE old_allocated_bytes=",old_measured.bytes,
        " stream_allocated_bytes=",new_measured.bytes," cases=",join(string.(checked),","),
        " B_shape=1548x69443 normal_shape=516x69443 physical_credit=false")
    flush(stdout)
end
end

Base.@noinline Base.@nospecializeinfer function _test_candidate_bound_g2_outer_face_map(F,component,context,trace,region,x,faces)
    Base.@nospecialize component context trace region faces
    println("G2_MAP_STAGE body_enter");flush(stdout)
    map=component.g2_outer_face_map
    coverage=region.grid_coverage
    if map===nothing
        absent=component.g2_outer_face_trace(x)
        @test absent.status===:typed_absent
        @test absent.reason===:candidate_has_no_explicit_g2_outer_face_map
        @test coverage.candidate_g2_outer_face_map===:typed_absent
        @test coverage.candidate_g2_outer_face_incidence_count===:typed_absent
        @test coverage.candidate_g2_outer_face_unique_native_count===:typed_absent
        @test coverage.candidate_g2_outer_face_sample_gather===:typed_absent
        @test coverage.candidate_g2_outer_face_region_state_gather.status===:typed_absent
        return :typed_absent
    end

    println("G2_MAP_STAGE context_binding_begin");flush(stdout)
    binding=F._freegs_context_binding(context)
    domain=binding.declaration.domain
    println("G2_MAP_STAGE context_binding_end");flush(stdout)
    println("G2_MAP_STAGE live_graph_validation_begin");flush(stdout)
    @test F._freegs_validate_outer_face_graph(context.candidate,map,domain)==map.map_hash
    println("G2_MAP_STAGE live_graph_validation_end");flush(stdout)
    println("G2_MAP_STAGE domain_hash_begin");flush(stdout)
    @test map.domain_hash==string(F.canonical_hash(F.semantic_view(domain)))
    println("G2_MAP_STAGE domain_hash_end");flush(stdout)
    println("G2_MAP_STAGE graph_hash_begin");flush(stdout)
    @test map.field_geometry_graph_hash==string(F.canonical_hash(context.compiled.field_geometry_graph))
    println("G2_MAP_STAGE graph_hash_end");flush(stdout)
    @test length(map.native_boundary_ids)==516
    @test length(unique(map.native_boundary_ids))==512
    @test length(map.face_node_ids)==length(map.face_support_ids)==length(map.side_ids)==
        length(map.face_dof_ids)==length(map.support_RZ_m)==length(map.normals_RZ)==
        length(map.orientation_signs)==516
    expected_sides=Tuple(vcat(fill(:R_min,domain.ny),fill(:R_max,domain.ny),
        fill(:Z_min,domain.nx),fill(:Z_max,domain.nx)))
    @test map.side_ids==expected_sides
    outward=Dict(:R_min=>(-1.0,0.0),:R_max=>(1.0,0.0),
        :Z_min=>(0.0,-1.0),:Z_max=>(0.0,1.0))
    @test all(i->(map.orientation_signs[i]*map.normals_RZ[i][1],
        map.orientation_signs[i]*map.normals_RZ[i][2])==outward[map.side_ids[i]],
        eachindex(map.side_ids))

    # Candidate identity is sealed to the actual graph; grid and normal mutations reject.
    stale_graph=map.field_geometry_graph_hash==repeat("0",64) ? repeat("1",64) : repeat("0",64)
    println("G2_MAP_STAGE stale_graph_validation_begin");flush(stdout)
    stale_graph_map=F.AxisymmetricG2OuterFaceMapV1(domain,stale_graph,map.face_node_ids,
        map.face_support_ids,map.side_ids,map.native_boundary_ids,map.face_dof_ids,
        map.support_RZ_m,map.normals_RZ,map.orientation_signs;provenance=map.provenance)
    @test_throws ArgumentError F._freegs_validate_outer_face_graph(context.candidate,stale_graph_map,domain)
    println("G2_MAP_STAGE stale_graph_validation_end");flush(stdout)
    stale_domain=F.AxisymmetricDomainV4(domain.r_min_m,domain.r_max_m,domain.z_min_m,
        domain.z_max_m,domain.nx+2,domain.ny,domain.boundary_model)
    println("G2_MAP_STAGE stale_domain_validation_begin");flush(stdout)
    @test_throws ArgumentError F._validate_freegs_outer_face_map(map,stale_domain)
    println("G2_MAP_STAGE stale_domain_validation_end");flush(stdout)
    shifted_support=collect(map.support_RZ_m)
    shifted_support[1]=(shifted_support[1][1]+1e-3,shifted_support[1][2])
    println("G2_MAP_STAGE shifted_support_rejection_begin");flush(stdout)
    @test_throws ArgumentError F.AxisymmetricG2OuterFaceMapV1(domain,
        map.field_geometry_graph_hash,map.face_node_ids,map.face_support_ids,map.side_ids,
        map.native_boundary_ids,map.face_dof_ids,Tuple(shifted_support),map.normals_RZ,
        map.orientation_signs;provenance=map.provenance)
    println("G2_MAP_STAGE shifted_support_rejection_end");flush(stdout)
    bad_normals=collect(map.normals_RZ);bad_normals[1]=(0.0,1.0)
    println("G2_MAP_STAGE bad_normals_rejection_begin");flush(stdout)
    @test_throws ArgumentError F.AxisymmetricG2OuterFaceMapV1(domain,
        map.field_geometry_graph_hash,map.face_node_ids,map.face_support_ids,map.side_ids,
        map.native_boundary_ids,map.face_dof_ids,map.support_RZ_m,Tuple(bad_normals),
        map.orientation_signs;provenance=map.provenance)
    println("G2_MAP_STAGE bad_normals_rejection_end");flush(stdout)
    reversed_signs=collect(map.orientation_signs);reversed_signs[1]=Int8(-1)
    println("G2_MAP_STAGE reversed_signs_rejection_begin");flush(stdout)
    @test_throws ArgumentError F.AxisymmetricG2OuterFaceMapV1(domain,
        map.field_geometry_graph_hash,map.face_node_ids,map.face_support_ids,map.side_ids,
        map.native_boundary_ids,map.face_dof_ids,map.support_RZ_m,map.normals_RZ,
        Tuple(reversed_signs);provenance=map.provenance)
    println("G2_MAP_STAGE reversed_signs_rejection_end");flush(stdout)
    lcfs_faces=collect(map.face_node_ids)
    for i in eachindex(lcfs_faces)
        map.side_ids[i]===:R_min && (lcfs_faces[i]=F._FREEGS_LCFS_NODE)
    end
    lcfs_map=F.AxisymmetricG2OuterFaceMapV1(domain,map.field_geometry_graph_hash,
        Tuple(lcfs_faces),map.face_support_ids,map.side_ids,map.native_boundary_ids,
        map.face_dof_ids,map.support_RZ_m,map.normals_RZ,map.orientation_signs;
        provenance=map.provenance)
    println("G2_MAP_STAGE lcfs_graph_rejection_begin");flush(stdout)
    @test_throws ArgumentError F._freegs_validate_outer_face_graph(context.candidate,lcfs_map,domain)
    println("G2_MAP_STAGE lcfs_graph_rejection_end");flush(stdout)

    println("G2_MAP_STAGE coverage_semantic_map_begin");flush(stdout)
    @test coverage.candidate_g2_outer_face_map==F.semantic_view(map)
    println("G2_MAP_STAGE coverage_semantic_map_end");flush(stdout)
    @test coverage.candidate_g2_outer_face_incidence_count==516
    @test coverage.candidate_g2_outer_face_unique_native_count==512
    gather=coverage.candidate_g2_outer_face_sample_gather
    @test length(gather)==516
    @test coverage.candidate_g2_outer_face_region_state_gather.status===:typed_absent
    @test coverage.candidate_g2_outer_face_region_state_gather.reason===
        :native_region_state_contains_only_core_stencil_nodes
    for i in eachindex(map.native_boundary_ids)
        item=gather[i]
        @test item.incidence==i && item.side_id==map.side_ids[i]
        @test item.face_node_id==map.face_node_ids[i] && item.face_support_id==map.face_support_ids[i]
        @test item.native_boundary_id==item.sample_index==map.native_boundary_ids[i]
        @test item.face_dof_id==map.face_dof_ids[i]
        @test item.support_RZ_m==map.support_RZ_m[i] && item.orientation_sign==map.orientation_signs[i]
    end
    println("G2_MAP_STAGE incidence_gather_loop_end");flush(stdout)

    observed=component.g2_outer_face_trace(x)
    @test observed.status===:evaluated_candidate_bound_g2_outer_face_trace
    @test observed.candidate_hash==component.candidate_hash
    @test observed.context_hash==string(context.context_hash)
    @test observed.upstream_output_hash==component.upstream_output_hash==string(trace.data.upstream_output_hash)
    @test observed.map_hash==string(map.map_hash)
    @test observed.incidence_count==516 && observed.unique_native_node_count==512
    @test observed.native_boundary_ids==map.native_boundary_ids
    @test observed.face_node_ids==map.face_node_ids && observed.face_support_ids==map.face_support_ids
    @test observed.side_ids==map.side_ids && observed.face_dof_ids==map.face_dof_ids
    @test size(observed.B_cylindrical_jacobian)==(1548,length(x))
    @test size(observed.normal_B_jacobian)==(516,length(x))
    @test length(observed.B_cylindrical_T)==516 && length(observed.normal_B_T)==516
    faces_by_side=Dict(face.face=>face for face in faces)
    # Only row permutations are retained; one 69444-entry CSC colptr per
    # incidence would keep 286664832 bytes before any values or projection.
    source_faces=collect(faces)
    source_index_by_side=Dict(face.face=>k for (k,face) in enumerate(source_faces))
    source_row_maps=[zeros(Int,size(face.B_cylindrical_jacobian,1)) for face in source_faces]
    for i in eachindex(map.native_boundary_ids)
        face=faces_by_side[map.side_ids[i]]
        position=findfirst(==(map.native_boundary_ids[i]),face.native_ids)
        @test position!==nothing
        @test Tuple(face.state_dofs[4position-3:4position])==observed.state_dof_columns[i]
        @test observed.state_dof_columns[i]==ntuple(field->4*map.native_boundary_ids[i]-4+field,4)
        @test observed.B_cylindrical_T[i]==face.B_cylindrical_T[position]
        @test observed.normal_B_T[i]==sum(observed.oriented_normals_RZ[i][k]*
            observed.B_cylindrical_T[i][k==1 ? 1 : 3] for k in 1:2)
        rows=source_row_maps[source_index_by_side[map.side_ids[i]]]
        for field in 1:3
            rows[3position-3+field]=3i-3+field
        end
    end
    @test sort(vcat(source_row_maps...))==collect(1:1548)
    println("G2_MAP_STAGE jacobian_stream_all_columns_begin");flush(stdout)
    # Reproduce the original full row gather and signed normal projection for
    # every column. Stored and implicit zeros are compared exactly, without
    # 516 CSC slices, a second whole B matrix, or wide sparse multiplication.
    B_rows_equal,normal_rows_equal=_test_g2_map_csc_equal_rows(
        observed.B_cylindrical_jacobian,observed.normal_B_jacobian,
        [face.B_cylindrical_jacobian for face in source_faces],source_row_maps,
        collect(observed.oriented_normals_RZ))
    for i in eachindex(map.native_boundary_ids)
        @test all(B_rows_equal[3i-2:3i])
    end
    @test all(B_rows_equal)
    @test all(normal_rows_equal)
    println("G2_MAP_STAGE jacobian_stream_all_columns_end");flush(stdout)
    GC.gc(false)

    corners=observed.shared_corner_state_columns
    @test length(corners)==4
    for corner in corners
        @test length(corner.incidence_indices)==2
        a,b=corner.incidence_indices
        @test map.native_boundary_ids[a]==map.native_boundary_ids[b]==corner.native_boundary_id
        @test map.side_ids[a]!=map.side_ids[b]
        @test corner.state_dof_columns[1]==corner.state_dof_columns[2]==observed.state_dof_columns[a]
        @test observed.state_dof_columns[a]==observed.state_dof_columns[b]
        @test observed.oriented_normals_RZ[a]==outward[map.side_ids[a]]
        @test observed.oriented_normals_RZ[b]==outward[map.side_ids[b]]
    end

    # Independent polynomial curl oracle: delta F=c+aR+bZ+dRZ on the actual grid.
    # Compare increments; the source state's current need not vanish.
    trial_state=copy(x);mu0=component.profile_law.mu0_N_per_A2
    analytic_current_max_error=0.0;analytic_normal_max_error=0.0;fd_current_max_error=0.0
    native_count=prod(component.grid_shape)
    for (k,(r,z)) in enumerate(component.coordinates_RZ_m)
        trial_state[4k-2]+=(0.002+0.003r+0.004z+0.001r*z)/r
    end
    trial_faces=component.boundary_trace(trial_state)
    trial_observed=component.g2_outer_face_trace(trial_state)
    trial_by_side=Dict(face.face=>face for face in trial_faces)
    @test size(trial_observed.trial_current_RZ_jacobian)==(1032,length(x))
    @test size(trial_observed.trial_normal_J_jacobian)==(516,length(x))
    @test trial_observed.trial_current_RZ_jacobian==observed.trial_current_RZ_jacobian
    @test trial_observed.trial_normal_J_jacobian==observed.trial_normal_J_jacobian
    @test trial_observed.B_cylindrical_T==observed.B_cylindrical_T
    @test maximum(abs,trial_observed.trial_normal_J_A_m2-observed.trial_normal_J_A_m2)>0.0
    for face in trial_faces
        original_face=faces_by_side[face.face]
        @test face.trial_current_normal_trace===:evaluated_box_observation
        @test face.trial_current_scope===:axisymmetric_native_spline_curl_of_actual_R_times_Bphi
        @test face.trial_current_jacobian_columns===:full_state_Bphi_native_dofs
        @test face.trial_current_row_order==(:JR,:JZ) && face.trial_current_units===:A_per_m2
        @test face.current_normal_trace===:typed_absent && face.full_J_normal_trace===:typed_absent
        @test face.extra_solver_rows==0 && length(face.native_ids)==129
        @test size(face.trial_current_RZ_jacobian)==(258,length(x))
        @test size(face.trial_normal_J_jacobian)==(129,length(x))
        @test face.B_cylindrical_T==original_face.B_cylindrical_T
        for q in eachindex(face.native_ids)
            r,z=face.coordinates_RZ_m[q]
            expected=[-(0.004+0.001r)/(mu0*r),(0.003+0.001z)/(mu0*r)]
            actual=collect(face.trial_current_RZ_A_m2[q])-collect(original_face.trial_current_RZ_A_m2[q])
            analytic_current_max_error=max(analytic_current_max_error,maximum(abs,actual-expected))
            @test maximum(abs,actual-expected)<=1e-8*max(1.0,maximum(abs,actual),maximum(abs,expected))
            normal=outward[face.face]
            expected_normal=normal[1]*expected[1]+normal[2]*expected[2]
            actual_normal=face.trial_normal_J_A_m2[q]-original_face.trial_normal_J_A_m2[q]
            analytic_normal_max_error=max(analytic_normal_max_error,abs(actual_normal-expected_normal))
            @test abs(actual_normal-expected_normal)<=1e-8*max(1.0,abs(actual_normal),abs(expected_normal))
        end
    end
    for q in eachindex(map.native_boundary_ids)
        face=trial_by_side[map.side_ids[q]]
        position=findfirst(==(map.native_boundary_ids[q]),face.native_ids)
        @test trial_observed.trial_current_RZ_A_m2[q]==face.trial_current_RZ_A_m2[position]
        @test trial_observed.trial_current_RZ_jacobian[2q-1:2q,:]==face.trial_current_RZ_jacobian[2position-1:2position,:]
        @test trial_observed.trial_normal_J_A_m2[q]==face.trial_normal_J_A_m2[position]
        @test trial_observed.trial_normal_J_jacobian[q,:]==face.trial_normal_J_jacobian[position,:]
    end
    # Sparse structural support rejects accidental pressure/psi/u/v/Br/Bz derivatives.
    invalid_current_columns=Int[]
    for matrix in (trial_observed.trial_current_RZ_jacobian,trial_observed.trial_normal_J_jacobian)
        for col in axes(matrix,2)
            if col>4native_count || mod(col,4)!=2
                for pointer in SparseArrays.nzrange(matrix,col)
                    iszero(SparseArrays.nonzeros(matrix)[pointer]) || push!(invalid_current_columns,col)
                end
            end
        end
    end
    @test isempty(invalid_current_columns)
    for corner in corners
        a,b=corner.incidence_indices
        @test trial_observed.trial_current_RZ_A_m2[a]==trial_observed.trial_current_RZ_A_m2[b]
        @test trial_observed.trial_current_RZ_jacobian[2a-1:2a,:]==trial_observed.trial_current_RZ_jacobian[2b-1:2b,:]
        for q in (a,b)
            jr,jz=trial_observed.trial_current_RZ_A_m2[q]
            normal=outward[map.side_ids[q]]
            @test trial_observed.oriented_normals_RZ[q]==normal
            @test trial_observed.trial_normal_J_A_m2[q]==normal[1]*jr+normal[2]*jz
        end
    end
    # A non-corner Bphi column probes every current row, including remote spline support.
    current_column=4*map.native_boundary_ids[2]-2;current_step=1e-6
    current_plus=copy(trial_state);current_minus=copy(trial_state)
    current_plus[current_column]+=current_step;current_minus[current_column]-=current_step
    current_plus_trace=component.g2_outer_face_trace(current_plus)
    current_plus_values=current_plus_trace.trial_current_RZ_A_m2
    current_plus_normal=current_plus_trace.trial_normal_J_A_m2
    current_plus_trace=nothing;GC.gc(false)
    current_minus_trace=component.g2_outer_face_trace(current_minus)
    current_minus_values=current_minus_trace.trial_current_RZ_A_m2
    current_minus_normal=current_minus_trace.trial_normal_J_A_m2
    current_minus_trace=nothing;GC.gc(false)
    for field in 1:2
        fd=[(current_plus_values[q][field]-current_minus_values[q][field])/
            (2current_step) for q in 1:516]
        derivative=trial_observed.trial_current_RZ_jacobian[field:2:1032,current_column]
        fd_current_max_error=max(fd_current_max_error,maximum(abs,fd-derivative))
        @test maximum(abs,fd-derivative)<=1e-8*max(1.0,maximum(abs,fd),maximum(abs,derivative))
    end
    fd_normal_current=(current_plus_normal-current_minus_normal)/(2current_step)
    derivative_normal=trial_observed.trial_normal_J_jacobian[:,current_column]
    @test maximum(abs,fd_normal_current-derivative_normal)<=1e-8*max(1.0,maximum(abs,fd_normal_current),maximum(abs,derivative_normal))
    @test trial_observed.current_normal_trace===:typed_absent && trial_observed.full_J_normal_trace===:typed_absent
    @test trial_observed.extra_solver_rows==0 && trial_observed.missing_closures==component.missing_closures

    # One non-corner full-native psi column checks the materialized B and normal gathers.
    i=2;native_id=map.native_boundary_ids[i];column=4native_id;step=1e-6
    plus=copy(x);minus=copy(x);plus[column]+=step;minus[column]-=step
    plus_trace=component.g2_outer_face_trace(plus)
    plus_B=plus_trace.B_cylindrical_T[i];plus_normal=plus_trace.normal_B_T[i]
    plus_trace=nothing;GC.gc(false)
    minus_trace=component.g2_outer_face_trace(minus)
    minus_B=minus_trace.B_cylindrical_T[i];minus_normal=minus_trace.normal_B_T[i]
    minus_trace=nothing;GC.gc(false)
    fd_B=(collect(plus_B).-collect(minus_B))./(2step)
    jac_B=observed.B_cylindrical_jacobian[3i-2:3i,column]
    @test maximum(abs,fd_B-jac_B)<=1e-8*max(1.0,maximum(abs,fd_B),maximum(abs,jac_B))
    fd_normal=(plus_normal-minus_normal)/(2step)
    @test abs(fd_normal-observed.normal_B_jacobian[i,column])<=
        1e-8*max(1.0,abs(fd_normal),abs(observed.normal_B_jacobian[i,column]))
    @test observed.B_out_law===:typed_absent && observed.K_outer_law===:typed_absent
    @test !observed.physical_validation && !observed.engineering_validation
    @test observed.missing_closures==component.missing_closures
    @test component.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    # Deterministic numerical comparison output only; no identity/admission gate.
    # Keep CSC storage as Vectors, never enormous Tuple inventories or dense matrices.
    current_values=Float64[value for pair in trial_observed.trial_current_RZ_A_m2 for value in pair]
    current_matrix=trial_observed.trial_current_RZ_jacobian
    normal_matrix=trial_observed.trial_normal_J_jacobian
    current_matrix_hash=string(F.canonical_hash((shape=size(current_matrix),
        colptr=current_matrix.colptr,rowval=current_matrix.rowval,nzval=SparseArrays.nonzeros(current_matrix))))
    normal_matrix_hash=string(F.canonical_hash((shape=size(normal_matrix),
        colptr=normal_matrix.colptr,rowval=normal_matrix.rowval,nzval=SparseArrays.nonzeros(normal_matrix))))
    println("FREEGS_G2_TRIAL_CURRENT_ACTUAL_JSON="*F.canonical_json((
        candidate_hash=component.candidate_hash,upstream_output_hash=component.upstream_output_hash,
        incidence_count=516,unique_native_node_count=512,
        perturbation_delta_F_coefficients=(constant=0.002,R=0.003,Z=0.004,RZ=0.001),
        current_row_order=trial_observed.trial_current_row_order,
        current_values=(count=length(current_values),minimum=minimum(current_values),
            maximum=maximum(current_values),max_abs=maximum(abs,current_values),
            numerical_hash=string(F.canonical_hash(current_values))),
        normal_current_values=(count=length(trial_observed.trial_normal_J_A_m2),
            minimum=minimum(trial_observed.trial_normal_J_A_m2),maximum=maximum(trial_observed.trial_normal_J_A_m2),
            max_abs=maximum(abs,trial_observed.trial_normal_J_A_m2),
            numerical_hash=string(F.canonical_hash(trial_observed.trial_normal_J_A_m2))),
        current_jacobian=(shape=size(current_matrix),nnz=SparseArrays.nnz(current_matrix),numerical_csc_hash=current_matrix_hash),
        normal_jacobian=(shape=size(normal_matrix),nnz=SparseArrays.nnz(normal_matrix),numerical_csc_hash=normal_matrix_hash),
        analytic_current_max_abs_error_A_per_m2=analytic_current_max_error,
        analytic_normal_max_abs_error_A_per_m2=analytic_normal_max_error,
        fd_current_max_abs_error=fd_current_max_error,
        fd_normal_max_abs_error=maximum(abs,fd_normal_current-derivative_normal),
        fd_column=current_column,fd_step=current_step,
        scope=trial_observed.trial_current_scope,units=trial_observed.trial_current_units,
        trial_current_normal_trace=trial_observed.trial_current_normal_trace,
        current_normal_trace=trial_observed.current_normal_trace,
        full_J_normal_trace=trial_observed.full_J_normal_trace,
        B_out_law=trial_observed.B_out_law,K_outer_law=trial_observed.K_outer_law,
        missing_closures=trial_observed.missing_closures,extra_solver_rows=trial_observed.extra_solver_rows,
        physical_validation=false,engineering_validation=false)))
    flush(stdout)
    :evaluated_candidate_bound_g2_outer_face_trace
end

function test_interface_stress_jump_kernel(F)
@testset "local three-component interface Cauchy stress/J" begin
    # The local stress-jump kernel differentiates both traces and a moving unit normal.
    let n0=[0.6,0.0,0.8],t1=[0.0,1.0,0.0],t2=[0.8,0.0,-0.6]
        z=[3.2e4,1.1e4,0.42,0.31,0.87,-0.18,0.22,0.91,0.0,0.0]
        function stress_at(y)
            raw=n0+y[9]*t1+y[10]*t2;n=raw/norm(raw)
            normal_map=zeros(3,10)
            normal_map[:,9].=((Matrix{Float64}(I,3,3)-n*transpose(n))*t1)/norm(raw)
            normal_map[:,10].=((Matrix{Float64}(I,3,3)-n*transpose(n))*t2)/norm(raw)
            F._ccp_axisymmetric_interface_stress_jump([y[1]],[y[2]],
                reshape(y[3:5],3,1),reshape(y[6:8],3,1),reshape(n,3,1),4pi*1e-7;
                pressure_plasma_jacobian=sparse([1],[1],[1.0],1,10),
                pressure_exterior_jacobian=sparse([1],[2],[1.0],1,10),
                B_plasma_jacobian=sparse(1:3,3:5,ones(3),3,10),
                B_exterior_jacobian=sparse(1:3,6:8,ones(3),3,10),
                normal_jacobian=sparse(normal_map))
        end
        stress_base=stress_at(z);stress_fd=zeros(3,10)
        current_fd=zeros(3,10);normal_jump_fd=zeros(1,10)
        for j in eachindex(z)
            h=j<=2 ? 1.0e-3 : (j<=8 ? 1.0e-6 : 1.0e-6)
            plus=copy(z);minus=copy(z);plus[j]+=h;minus[j]-=h
            stress_fd[:,j].=(stress_at(plus).traction_jump_Pa-
                stress_at(minus).traction_jump_Pa)/(2h)
            current_fd[:,j].=(stress_at(plus).derived_surface_current_jump_A_per_m-
                stress_at(minus).derived_surface_current_jump_A_per_m)/(2h)
            normal_jump_fd[:,j].=(stress_at(plus).normal_magnetic_field_jump_T-
                stress_at(minus).normal_magnetic_field_jump_T)/(2h)
        end
        @test stress_base.status===:evaluated_local_maxwell_pressure_stress_jump
        @test issparse(stress_base.jacobian) && size(stress_base.jacobian)==(3,10)
        @test stress_base.jacobian_includes_moving_normal
        @test isapprox(Matrix(stress_base.jacobian),stress_fd;rtol=5e-6,atol=1e-6)
        n=n0/norm(n0);deltaB=z[6:8]-z[3:5];mu0=4pi*1e-7
        expected_K=[n[2]*deltaB[3]-n[3]*deltaB[2],
            n[3]*deltaB[1]-n[1]*deltaB[3],n[1]*deltaB[2]-n[2]*deltaB[1]]/mu0
        @test isapprox(stress_base.derived_surface_current_jump_A_per_m,expected_K;rtol=1e-13,atol=1e-8)
        @test isapprox(stress_base.normal_magnetic_field_jump_T,[dot(n,deltaB)];rtol=1e-13,atol=1e-14)
        @test abs(dot(n,stress_base.derived_surface_current_jump_A_per_m))<=1e-8
        @test issparse(stress_base.derived_surface_current_jump_jacobian)
        @test size(stress_base.derived_surface_current_jump_jacobian)==(3,10)
        @test issparse(stress_base.normal_magnetic_field_jump_jacobian)
        @test size(stress_base.normal_magnetic_field_jump_jacobian)==(1,10)
        @test stress_base.surface_current_is_diagnostic && stress_base.K_outer_closure===:typed_absent &&
            !stress_base.normal_magnetic_jump_is_global_constraint &&
            !stress_base.traction_is_global_residual && stress_base.global_rows_added==0
        @test isapprox(Matrix(stress_base.derived_surface_current_jump_jacobian),current_fd;rtol=5e-6,atol=1e-7)
        @test isapprox(Matrix(stress_base.normal_magnetic_field_jump_jacobian),normal_jump_fd;rtol=5e-6,atol=1e-8)
        # Distinct meridional normals and disjoint state columns expose face-row scattering errors.
        nbase=[0.6 0.8;0.0 0.0;0.8 -0.6]
        tangents=(([0.0,1.0,0.0],[0.8,0.0,-0.6]),([0.0,1.0,0.0],[0.6,0.0,0.8]))
        z2=[3.2e4,1.1e4,0.42,0.31,0.87,-0.18,0.22,0.91,0.0,0.0,
            2.4e4,0.8e4,-0.36,0.53,0.14,0.75,-0.41,0.62,0.0,0.0]
        function stress_two_at(y)
            ns=zeros(3,2);Jns=zeros(6,20)
            for a in 1:2
                base=(a-1)*10;raw=nbase[:,a]+y[base+9]*tangents[a][1]+y[base+10]*tangents[a][2]
                ns[:,a].=raw/norm(raw)
                Jns[(a-1)*3+1:a*3,base+9].=((Matrix{Float64}(I,3,3)-ns[:,a]*transpose(ns[:,a]))*tangents[a][1])/norm(raw)
                Jns[(a-1)*3+1:a*3,base+10].=((Matrix{Float64}(I,3,3)-ns[:,a]*transpose(ns[:,a]))*tangents[a][2])/norm(raw)
            end
            F._ccp_axisymmetric_interface_stress_jump([y[1],y[11]],[y[2],y[12]],
                reshape(vcat(y[3:5],y[13:15]),3,2),reshape(vcat(y[6:8],y[16:18]),3,2),ns,4pi*1e-7;
                pressure_plasma_jacobian=sparse([1,2],[1,11],[1.0,1.0],2,20),
                pressure_exterior_jacobian=sparse([1,2],[2,12],[1.0,1.0],2,20),
                B_plasma_jacobian=sparse([1,2,3,4,5,6],[3,4,5,13,14,15],ones(6),6,20),
                B_exterior_jacobian=sparse([1,2,3,4,5,6],[6,7,8,16,17,18],ones(6),6,20),
                normal_jacobian=sparse(Jns))
        end
        two_base=stress_two_at(z2);two_K_fd=zeros(6,20);two_Bn_fd=zeros(2,20)
        for j in eachindex(z2)
            h=j in (1,2,11,12) ? 1.0e-3 : 1.0e-6
            plus=copy(z2);minus=copy(z2);plus[j]+=h;minus[j]-=h
            two_K_fd[:,j].=(stress_two_at(plus).derived_surface_current_jump_A_per_m-
                stress_two_at(minus).derived_surface_current_jump_A_per_m)/(2h)
            two_Bn_fd[:,j].=(stress_two_at(plus).normal_magnetic_field_jump_T-
                stress_two_at(minus).normal_magnetic_field_jump_T)/(2h)
        end
        expected_two_K=vcat(
            [nbase[2,1]*(z2[8]-z2[5])-nbase[3,1]*(z2[7]-z2[4]),
                nbase[3,1]*(z2[6]-z2[3])-nbase[1,1]*(z2[8]-z2[5]),
                nbase[1,1]*(z2[7]-z2[4])-nbase[2,1]*(z2[6]-z2[3])],
            [nbase[2,2]*(z2[18]-z2[15])-nbase[3,2]*(z2[17]-z2[14]),
                nbase[3,2]*(z2[16]-z2[13])-nbase[1,2]*(z2[18]-z2[15]),
                nbase[1,2]*(z2[17]-z2[14])-nbase[2,2]*(z2[16]-z2[13])])/(4pi*1e-7)
        @test size(two_base.derived_surface_current_jump_A_per_m)==(6,)
        @test size(two_base.normal_magnetic_field_jump_T)==(2,)
        @test isapprox(two_base.derived_surface_current_jump_A_per_m,expected_two_K;rtol=1e-13,atol=1e-8)
        @test isapprox(Matrix(two_base.derived_surface_current_jump_jacobian),two_K_fd;rtol=5e-6,atol=1e-7)
        @test isapprox(Matrix(two_base.normal_magnetic_field_jump_jacobian),two_Bn_fd;rtol=5e-6,atol=1e-8)
        two_K_jac=Matrix(two_base.derived_surface_current_jump_jacobian)
        two_Bn_jac=Matrix(two_base.normal_magnetic_field_jump_jacobian)
        @test all(iszero,two_K_jac[1:3,11:20]) && all(iszero,two_K_jac[4:6,1:10])
        @test all(iszero,two_Bn_jac[1,11:20]) && all(iszero,two_Bn_jac[2,1:10])
        @test_throws ArgumentError F._ccp_axisymmetric_interface_stress_jump([1.0],[0.0],
            reshape([0.1,0.2,0.3],3,1),reshape([0.0,0.1,0.2],3,1),reshape([2.0,0.0,0.0],3,1),
            4pi*1e-7;pressure_plasma_jacobian=spzeros(1,3),pressure_exterior_jacobian=spzeros(1,3),
            B_plasma_jacobian=spzeros(3,3),B_exterior_jacobian=spzeros(3,3),normal_jacobian=spzeros(3,3))
    end
end
    true
end

# Included by the existing actual provider suite; never starts a provider.
function test_actual_freegs_lcfs_trace(F,context,artifacts,indices;native_region=nothing)
    local trace=nothing
@testset "actual LCFS trace, profile topology and frozen-plasma current response" begin
    test_interface_stress_jump_kernel(F)
    test_hagenow_source_response_reader(F)
    test_native_critical_points_parser(F)
    trace=F.freegs_axisymmetric_lcfs_trace(context,artifacts)
    @test trace isa F.FreeGSAxisymmetricLCFSTraceV4
    d=trace.data
    @test d.candidate_hash==string(context.candidate_hash)
    @test d.upstream_output_hash==string(artifacts.receipt.output_hash)
    @test length(d.coordinates_m)==64
    @test length(d.pf_loop_support)==length(d.coil_ids)
    @test all(s -> s.closed_PF_filament && !s.plasma_return_path_verified &&
        !s.engineering_leads_verified,d.pf_loop_support)
    @test all(p -> abs(p-1.0)<=1.0e-9,d.psi_normalized)
    base=F.evaluate_freegs_axisymmetric_lcfs_trace(trace,d.initial_state)
    @test size(base.jacobian)==(192,256)
    @test size(base.cauchy_traction_jacobian)==(192,256)
    @test !base.traction_is_residual
    @test base.stress_convention===:cauchy_BB_minus_isotropic
    @test base.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    @test !base.physical_validation && !base.coupled_solve_attempted
    authored=d.authored_sources.status===:evaluated_authored_G1_G3_sources
    @test base.sheet_current_law===(authored ? :executed_G1_no_delta_sheet : :typed_absent)
    @test base.exterior_total_field===:typed_absent && base.plasma_return_path===:typed_absent
    @test all(isfinite,base.residual) && all(isfinite,base.cauchy_traction_cylindrical_Pa)

    callbacks=F.freegs_axisymmetric_lcfs_boundary_callbacks(trace)
    @test callbacks.independent_sheet_current_law===
        (authored ? :executed_G1_no_delta_sheet : :typed_absent)
    @test callbacks.declared_sheet_current_A_per_m===
        (authored ? (0.0,0.0,0.0) : nothing)
    @test callbacks.external_total_field===:typed_absent
    @test callbacks.plasma_return_path===:typed_absent
    @test :K_outer in callbacks.missing_closures
    outer_id=F.InHouseCoupledMHDGlobalSolveV1._callback_identity(callbacks.outer_evaluator)
    oracle_id=F.InHouseCoupledMHDGlobalSolveV1._callback_identity(callbacks.jacobian_oracle)
    direct_context=(candidate_hash=d.candidate_hash,
        provider_semantic_hash=string(F.canonical_hash(F.semantic_view(trace))),
        provider_context_hash=string(F.canonical_hash((outer_id,oracle_id))),
        jacobian_oracle_hash=string(F.canonical_hash(oracle_id)))
    absent=NamedTuple{F._CCP_AXISYMMETRIC_MISSING_CLOSURES}(ntuple(_->nothing,5))
    rows=callbacks.outer_evaluator(callbacks.region_id,d.initial_state,absent,direct_context)
    oracle=callbacks.jacobian_oracle(:outer,callbacks.region_id,d.initial_state,absent,direct_context)
    @test rows.residual==base.residual && rows.jacobian==base.jacobian
    outer_error=maximum(abs.(Matrix(base.jacobian)-oracle.jacobian))
    @test outer_error<=64eps(Float64)*max(1.0,maximum(abs,oracle.jacobian))
    @test_throws ArgumentError callbacks.jacobian_oracle(:regional,callbacks.region_id,
        d.initial_state,absent,direct_context)
    @test_throws ArgumentError callbacks.outer_evaluator("foreign_region",d.initial_state,absent,direct_context)
    validator=(candidate_hash=d.candidate_hash,region_id=callbacks.region_id,
        provider_semantic_hash=direct_context.provider_semantic_hash,
        provider_context_hash=direct_context.provider_context_hash,
        jacobian_oracle_hash=direct_context.jacobian_oracle_hash,
        jacobian_oracle=callbacks.jacobian_oracle,closure_evidence=absent)
    # Use the actual existing roundoff validator, including its wrong-J negative.
    check=F.InHouseCoupledMHDGlobalSolveV1._check_jacobian_oracle(validator,:outer,
        callbacks.region_id,d.initial_state,callbacks.constraint_ids,:constraint_ids,
        base.jacobian,"actual LCFS trace";provider_context=direct_context)
    @test check.passed
    wrong=copy(base.jacobian); wrong[1,2]+=1.0
    @test_throws ArgumentError F.InHouseCoupledMHDGlobalSolveV1._check_jacobian_oracle(validator,:outer,
        callbacks.region_id,d.initial_state,callbacks.constraint_ids,:constraint_ids,wrong,"wrong LCFS trace";
        provider_context=direct_context)

    traction_oracle=zeros(192,256); step=1.0e-30
    for j in 1:256
        z=ComplexF64.(collect(d.initial_state)); z[j]+=im*step
        values=F._ccp_axisymmetric_lcfs_trace_oracle(z,d.normals_RZ,
            d.profile_boundary_pressure_Pa,d.mu0_N_per_A2)
        traction_oracle[:,j].=imag.(values.traction)./step
    end
    traction_error=maximum(abs.(Matrix(base.cauchy_traction_jacobian)-traction_oracle))
    @test traction_error<=64eps(Float64)*max(1.0,maximum(abs,traction_oracle))
    perturbed=collect(d.initial_state)
    perturbed[1]+=1.0
    perturbed[2]+=1.0e-3*d.normals_RZ[1][1]
    perturbed[4]+=1.0e-3*d.normals_RZ[1][2]
    changed=F.evaluate_freegs_axisymmetric_lcfs_trace(trace,perturbed)
    @test isapprox(changed.residual[1]-base.residual[1],1.0e-3;rtol=1.0e-10,atol=1.0e-14)
    @test changed.residual[2]-base.residual[2]==1.0
    @test changed.residual[4:end]==base.residual[4:end]
    @test changed.cauchy_traction_cylindrical_Pa!=base.cauchy_traction_cylindrical_Pa
    negative=collect(d.initial_state); negative[1]=-1.0
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_trace(trace,negative)
    nonfinite=collect(d.initial_state); nonfinite[2]=NaN
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_trace(trace,nonfinite)

    direct=F.evaluate_freegs_axisymmetric_lcfs_actuator_response(trace,d.coil_currents_A_per_turn)
    @test direct.state==collect(d.initial_state)
    @test direct.residual==base.residual
    @test !direct.equilibrium_recomputed && !direct.coil_only_is_total_exterior
    @test size(direct.current_jacobian)==(192,length(d.coil_ids))
    currents=collect(d.coil_currents_A_per_turn); currents[1]+=1.0
    actuator=F.evaluate_freegs_axisymmetric_lcfs_actuator_response(trace,currents)
    @test actuator.state!=direct.state
    @test isapprox(actuator.residual-direct.residual,collect(direct.current_jacobian[:,1]);
        rtol=1.0e-8,atol=1.0e-13)
    @test all(i -> actuator.state[i]==direct.state[i],1:4:256)
    @test all(i -> actuator.state[i]==direct.state[i],3:4:256)
    current_traction_oracle=zeros(192,length(currents))
    for j in eachindex(currents)
        z=ComplexF64.(collect(d.initial_state))+im*step*direct.state_current_jacobian[:,j]
        current_traction_oracle[:,j].=imag.(F._ccp_axisymmetric_lcfs_trace_oracle(z,d.normals_RZ,
            d.profile_boundary_pressure_Pa,d.mu0_N_per_A2).traction)./step
    end
    current_error=maximum(abs.(Matrix(direct.traction_current_jacobian)-current_traction_oracle))
    @test current_error<=128eps(Float64)*max(1.0,maximum(abs,current_traction_oracle))


    # Same provider artifacts; no second solve or FreeGS total-field backfill.
    current_field=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace)
    @test current_field.status===:evaluated_native_signed_current_poloidal_field
    @test d.current_support.status===:present
    @test !current_field.continuum_exterior_trace_validated && !current_field.equilibrium_recomputed
    @test current_field.exterior_total_field===:typed_absent
    @test current_field.independent_toroidal_field_source.status===(authored ? :evaluated_authored_G1_G3_sources : :typed_absent)
    if authored
        tf=current_field.independent_toroidal_field_source
        @test tf.NI_A_turn==5_000_000.0
        @test current_field.declared_sheet_current_A_per_m==(0.0,0.0,0.0)
        @test length(current_field.declared_exterior_B_cylindrical_T)==64
        shifted=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;TF_NI_A_turn=tf.NI_A_turn+1000.0)
        @test shifted.poloidal_field_RZ_T==current_field.poloidal_field_RZ_T
        bt=shifted.independent_toroidal_field_source
        @test maximum(abs.(collect(bt.TF_Bphi_T)-collect(tf.TF_Bphi_T)-1000.0*collect(tf.TF_dBphi_dNI_T_per_A)))<1.0e-14
        @test all(isapprox(2pi*d.coordinates_m[k][1]*tf.TF_Bphi_T[k],d.mu0_N_per_A2*tf.NI_A_turn;
            rtol=128eps(Float64),atol=0.0) for k in 1:64)
        @test !tf.TF_is_internal_plasma_total_Bphi && !tf.physical_validation
        println("FREEGS_AUTHORED_G1_G3_LCFS_ACTUAL_JSON="*F.canonical_json((candidate_hash=d.candidate_hash,
            context_hash=d.context_hash,upstream_output_hash=d.upstream_output_hash,
            g1_program_hash=tf.g1_program_hash,g3_program_hashes=tf.g3_program_hashes,
            NI_A_turn=tf.NI_A_turn,TF_Bphi_T=tf.TF_Bphi_T,TF_dBphi_dNI_T_per_A=tf.TF_dBphi_dNI_T_per_A,
            declared_K_A_per_m=tf.K_cylindrical_A_per_m,
            declared_exterior_B_cylindrical_T=current_field.declared_exterior_B_cylindrical_T,
            native_cell_quadrature_error=:unestimated,global_closures_complete=false,
            physical_validation=false,engineering_validation=false,terminal_authority=false)))
        flush(stdout)
    else
        @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;TF_NI_A_turn=5_000_000.0)
    end
    # This physical point is already part of the same actual FreeGS input at
    # both resolutions; the explicit keyword keeps the observation point fixed.
    fixed_observation=((2.0,1.0),)
    fixed_field=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        observation_points_rz_m=fixed_observation)
    @test fixed_field.coordinates_m==fixed_observation
    @test fixed_field.coordinates_source===:fixed_physical_RZ_points
    actual_fixed=filter(s -> s.R_m==2.0 && s.Z_m==1.0,artifacts.field_samples_rz_m)
    @test length(actual_fixed)==1
    provider_fixed=only(actual_fixed)
    estimated_fixed=only(fixed_field.poloidal_field_RZ_T)
    fixed_error=hypot(estimated_fixed[1]-provider_fixed.Br_T,
        estimated_fixed[2]-provider_fixed.Bz_T)
    @test all(isfinite,(estimated_fixed...,provider_fixed.Br_T,provider_fixed.Bz_T,fixed_error))
    nj=length(current_field.Jphi_A_per_m2)
    @test size(current_field.jacobian)==(128,nj+length(d.coil_ids))
    @test all(isfinite,current_field.field_vector_T)
    jd=collect(current_field.Jphi_A_per_m2); jd[1]+=1.0
    jp=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;Jphi_A_per_m2=jd)
    ic=collect(d.coil_currents_A_per_turn); ic[1]+=1.0
    cp=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;coil_currents_A_per_turn=ic)
    @test jp.field_vector_T!=current_field.field_vector_T
    @test cp.field_vector_T!=current_field.field_vector_T
    j_error=maximum(abs.(jp.field_vector_T-current_field.field_vector_T-current_field.jacobian[:,1]))
    c_error=maximum(abs.(cp.field_vector_T-current_field.field_vector_T-current_field.jacobian[:,nj+1]))
    @test j_error<=512eps(Float64)*max(1.0,maximum(abs,current_field.field_vector_T))
    @test c_error<=512eps(Float64)*max(1.0,maximum(abs,current_field.field_vector_T))
    # Reversing every signed source reverses B exactly up to summation roundoff.
    reverse=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        Jphi_A_per_m2=-collect(current_field.Jphi_A_per_m2),
        coil_currents_A_per_turn=-collect(d.coil_currents_A_per_turn))
    @test isapprox(reverse.field_vector_T,-current_field.field_vector_T;rtol=64eps(Float64),atol=0)
    # Independent Cartesian dl cross (x-y)/|x-y|^3 angular quadrature.
    # Choose well separated actual source/observation pairs for this kernel check;
    # this does not claim to resolve native-cell quadrature error at the LCFS.
    function angular_oracle(R,Z,a,z0,nangle)
        br=0.0; bz=0.0
        for q in 0:nangle-1
            angle=2pi*(q+0.5)/nangle; c=cos(angle); s=sin(angle)
            dx=R-a*c; dy=-a*s; dz=Z-z0
            inverse_distance3=(dx*dx+dy*dy+dz*dz)^(-1.5)
            br+=a*c*dz*inverse_distance3
            bz+=(a*a-a*R*c)*inverse_distance3
        end
        d.mu0_N_per_A2/(2nangle).*[br,bz]
    end
    oracle_error=0.0; oracle_refinement=0.0
    plasma_i,plasma_j=current_field.plasma_source_indices[1]
    sources=((d.current_support.R_m[plasma_i],d.current_support.Z_m[plasma_j]),
        (d.pf_loop_support[1].R_m,d.pf_loop_support[1].Z_m))
    for (source_index,(a,z0)) in enumerate(sources)
        k=argmax([hypot(R-a,Z-z0) for (R,Z) in d.coordinates_m]); R,Z=d.coordinates_m[k]
        low=angular_oracle(R,Z,a,z0,2048); high=angular_oracle(R,Z,a,z0,4096)
        column=source_index==1 ? 1 : nj+1
        weight=source_index==1 ? d.current_support.area_weight_m2[plasma_i][plasma_j] : d.pf_loop_support[1].turns
        analytic=current_field.jacobian[2k-1:2k,column]/weight
        oracle_error=max(oracle_error,maximum(abs.(analytic-high)))
        oracle_refinement=max(oracle_refinement,maximum(abs.(low-high)))
        # Floating-point kernel check only, with actual quadrature refinement.
        @test maximum(abs.(analytic-high))<=max(8*maximum(abs.(low-high)),4096eps(Float64)*maximum(abs,high))
    end
    # One complete current-weighted sum with the independent angular kernel.
    # Pick the actual LCFS observation furthest from its nearest source ring.
    weighted_sources=[(d.current_support.R_m[i],d.current_support.Z_m[j],
        current_field.Jphi_A_per_m2[q]*d.current_support.area_weight_m2[i][j])
        for (q,(i,j)) in enumerate(current_field.plasma_source_indices)]
    append!(weighted_sources,[(c.R_m,c.Z_m,d.coil_currents_A_per_turn[q]*c.turns)
        for (q,c) in enumerate(d.pf_loop_support)])
    full_k=argmax([minimum(hypot(R-a,Z-z0) for (a,z0,_) in weighted_sources)
        for (R,Z) in d.coordinates_m])
    full_R,full_Z=d.coordinates_m[full_k]
    full_low=zeros(2); full_high=zeros(2); absolute_contribution=zeros(2)
    for (a,z0,current) in weighted_sources
        low=current*angular_oracle(full_R,full_Z,a,z0,2048)
        high=current*angular_oracle(full_R,full_Z,a,z0,4096)
        full_low.+=low; full_high.+=high; absolute_contribution.+=abs.(high)
    end
    full_oracle_error=maximum(abs.(current_field.field_vector_T[2full_k-1:2full_k]-full_high))
    full_refinement=maximum(abs.(full_low-full_high))
    @test full_oracle_error<=max(8*full_refinement,4096eps(Float64)*maximum(absolute_contribution))
    @test_throws ArgumentError F._ccp_ring_unit_field_RZ(1.0,0.0,1.0,0.0,d.mu0_N_per_A2)
    bad_J=collect(current_field.Jphi_A_per_m2); bad_J[1]=NaN
    bad_I=collect(d.coil_currents_A_per_turn); bad_I[1]=Inf
    @test length(bad_J)==nj && length(bad_I)==length(d.coil_ids)
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;Jphi_A_per_m2=bad_J)
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;coil_currents_A_per_turn=bad_I)
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;Jphi_A_per_m2=zeros(nj+1))
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        coil_currents_A_per_turn=zeros(length(d.coil_ids)+1))
    # The opt-in last-solve RHS uses every raw native RZ node. It remains
    # separate from the accepted-final-psi profile used by the default path.
    accepted_state=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        state=:accepted_psi_profile)
    @test accepted_state.status===current_field.status
    @test accepted_state.Jphi_A_per_m2==current_field.Jphi_A_per_m2
    @test accepted_state.plasma_source_indices==current_field.plasma_source_indices
    @test accepted_state.field_vector_T==current_field.field_vector_T
    @test accepted_state.jacobian==current_field.jacobian

    last_diag=d.solver_jtor_diagnostic
    @test last_diag.status===:present
    @test last_diag.representation===:FreeGS_eq_Jtor_last_linear_solve_RZ_nodes
    @test last_diag.axis_order===:R_then_Z
    nr,nz=length(last_diag.R_m),length(last_diag.Z_m)
    @test (nr,nz)==(129,129)
    solver_rhs_grid=[last_diag.solver_eq_Jtor_A_per_m2[i][j] for i in 1:nr,j in 1:nz]
    accepted_psi_grid=[last_diag.recomputed_final_psi_Jphi_A_per_m2[i][j] for i in 1:nr,j in 1:nz]
    @test size(solver_rhs_grid)==(nr,nz)
    @test size(accepted_psi_grid)==(nr,nz)
    @test all(isfinite,solver_rhs_grid) && all(isfinite,accepted_psi_grid)
    @test all(isapprox(accepted_psi_grid[i,j],d.current_support.Jphi_A_per_m2[i][j];
        rtol=16eps(Float64),atol=0.0) for i in 1:nr,j in 1:nz)
    rhs_area_grid=[last_diag.area_weight_m2[i][j] for i in 1:nr,j in 1:nz]
    rhs_delta_grid=solver_rhs_grid.-accepted_psi_grid
    rhs_linf=maximum(abs,rhs_delta_grid)
    rhs_l2=sqrt(sum(abs2,rhs_delta_grid))
    profile_l2=sqrt(sum(abs2,accepted_psi_grid))
    solver_l2=sqrt(sum(abs2,solver_rhs_grid))
    rhs_relative_l2=rhs_l2/max(solver_l2,profile_l2,1.0e-300)
    rhs_integral=sum(solver_rhs_grid.*rhs_area_grid)
    accepted_integral=sum(accepted_psi_grid.*rhs_area_grid)
    delta_integral=sum(rhs_delta_grid.*rhs_area_grid)
    reported_norms=last_diag.solver_minus_recomputed_norms
    reported_integrals=last_diag.current_integrals
    @test isapprox(reported_norms.difference_Linf_A_per_m2,rhs_linf;rtol=1.0e-11,atol=1.0e-8)
    @test isapprox(reported_norms.difference_L2_frobenius_A_per_m2,rhs_l2;rtol=1.0e-11,atol=1.0e-8)
    @test isapprox(reported_norms.relative_difference_L2_dimensionless,rhs_relative_l2;
        rtol=1.0e-11,atol=1.0e-13)
    @test isapprox(reported_norms.difference_RZ_trapezoid_integral_A,delta_integral;
        rtol=1.0e-11,atol=1.0e-8)
    @test isapprox(reported_integrals.solver_eq_Jtor_RZ_trapezoid_A,rhs_integral;
        rtol=1.0e-11,atol=1.0e-8)
    @test isapprox(reported_integrals.recomputed_final_psi_Jphi_RZ_trapezoid_A,accepted_integral;
        rtol=1.0e-11,atol=1.0e-8)
    @test isapprox(reported_integrals.difference_solver_minus_recomputed_trapezoid_A,delta_integral;
        rtol=1.0e-11,atol=1.0e-8)
    output_doc=F.JSON3.read(artifacts.output_json)
    @test reported_integrals.solver_eq_plasmaCurrent_Romberg_A==
        output_doc[:equilibrium][:plasma_current_a]

    # Pick one actual LCFS observation well separated from all raw RHS rings;
    # use angular thin-ring integration over every raw source at that point.
    all_rhs_indices=Tuple((i,j) for i in 1:nr for j in 1:nz)
    rhs_sources=Tuple((i,j) for (i,j) in all_rhs_indices if !iszero(solver_rhs_grid[i,j]))
    rhs_observation_index=argmax([minimum(hypot(R-last_diag.R_m[i],Z-last_diag.Z_m[j])
        for (i,j) in all_rhs_indices) for (R,Z) in d.coordinates_m])
    rhs_observation=(d.coordinates_m[rhs_observation_index],)
    rhs_field=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        state=:last_linear_solve_rhs,observation_points_rz_m=rhs_observation)
    @test rhs_field.status===:evaluated_native_signed_current_poloidal_field
    @test rhs_field.current_state===:last_linear_solve_rhs
    @test rhs_field.current_state_provenance===:FreeGS_eq_Jtor_last_linear_solve_RZ_nodes
    @test rhs_field.current_state_scope===:exact_nonzero_retained_rhs_nodes_fixed_geometry
    @test rhs_field.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    @test :return_current_path in rhs_field.missing_closures
    @test rhs_field.source_model_complete_is_not_global_closure
    @test rhs_field.coordinates_m==rhs_observation
    @test !rhs_field.physical_validation && !rhs_field.engineering_validation
    @test !rhs_field.coupled_solve_attempted && !rhs_field.equilibrium_recomputed
    @test !rhs_field.terminal_authority && !rhs_field.p5_ready
    @test rhs_field.exterior_total_field===:typed_absent
    @test rhs_field.independent_sheet_law===:typed_absent
    @test rhs_field.global_regional_dof_map===:typed_absent
    @test !isempty(rhs_sources)
    @test rhs_field.plasma_source_indices==rhs_sources
    @test length(rhs_field.Jphi_A_per_m2)==length(rhs_sources)
    @test size(rhs_field.jacobian)==(2,length(rhs_sources)+length(d.coil_ids))
    @test all(isfinite,rhs_field.field_vector_T)
    @test Tuple(rhs_field.Jphi_A_per_m2)==Tuple(solver_rhs_grid[i,j]
        for (i,j) in rhs_sources)
    @test solver_rhs_grid!=accepted_psi_grid

    rhs_R,rhs_Z=only(rhs_observation)
    rhs_low=zeros(2); rhs_high=zeros(2); rhs_absolute=zeros(2)
    for (i,j) in rhs_sources
        area=rhs_area_grid[i,j]
        signed_ring_current=solver_rhs_grid[i,j]*area
        low=signed_ring_current*angular_oracle(rhs_R,rhs_Z,last_diag.R_m[i],last_diag.Z_m[j],2048)
        high=signed_ring_current*angular_oracle(rhs_R,rhs_Z,last_diag.R_m[i],last_diag.Z_m[j],4096)
        rhs_low.+=low; rhs_high.+=high; rhs_absolute.+=abs.(high)
    end
    for coil in d.pf_loop_support
        low=coil.current_A_per_turn*angular_oracle(rhs_R,rhs_Z,coil.R_m,coil.Z_m,512)*coil.turns
        high=coil.current_A_per_turn*angular_oracle(rhs_R,rhs_Z,coil.R_m,coil.Z_m,1024)*coil.turns
        rhs_low.+=low; rhs_high.+=high; rhs_absolute.+=abs.(high)
    end
    rhs_oracle_error=maximum(abs.(collect(rhs_field.field_vector_T)-rhs_high))
    rhs_oracle_refinement=maximum(abs.(rhs_low-rhs_high))
    @test rhs_oracle_error<=max(16*rhs_oracle_refinement,
        8192eps(Float64)*maximum(rhs_absolute))
    if !isempty(rhs_sources)
        source_index=first(rhs_sources)
        source_i,source_j=source_index
        source_column=findfirst(==(source_index),rhs_sources)
        source_area=rhs_area_grid[source_i,source_j]
        source_low=angular_oracle(rhs_R,rhs_Z,last_diag.R_m[source_i],last_diag.Z_m[source_j],2048)
        source_high=angular_oracle(rhs_R,rhs_Z,last_diag.R_m[source_i],last_diag.Z_m[source_j],4096)
        source_analytic=rhs_field.jacobian[1:2,source_column]/source_area
        @test maximum(abs.(source_analytic-source_high))<=max(
            8*maximum(abs.(source_low-source_high)),
            4096eps(Float64)*maximum(abs,source_high))
    end

    # The physical fixed corner (2,1) coincides with the last RZ grid node;
    # its raw RHS value is exactly zero and must not be retained as a singular ring.
    corner_observation=((2.0,1.0),)
    @test last_diag.R_m[nr]==2.0 && last_diag.Z_m[nz]==1.0
    @test iszero(solver_rhs_grid[nr,nz])
    corner_rhs_field=F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        state=:last_linear_solve_rhs,observation_points_rz_m=corner_observation)
    @test corner_rhs_field.coordinates_m==corner_observation
    @test all(isfinite,corner_rhs_field.field_vector_T)
    @test all(isfinite,corner_rhs_field.jacobian)
    @test (nr,nz) ∉ corner_rhs_field.plasma_source_indices

    # Evaluator-only synthetic trace test (not parser-valid or provider evidence):
    # verify support selection follows its raw-RHS array, not the accepted core mask.
    outside_core=Tuple((i,j) for i in 1:nr for j in 1:nz
        if d.current_support.core_mask[i][j]==0.0)
    @test !isempty(outside_core)
    if !isempty(outside_core)
        outside_index=first(outside_core)
        outside_i,outside_j=outside_index
        @test iszero(solver_rhs_grid[outside_i,outside_j])
        synthetic_grid=copy(solver_rhs_grid)
        synthetic_grid[outside_i,outside_j]=1.0
        synthetic_rows=Tuple(Tuple(synthetic_grid[i,j] for j in 1:nz) for i in 1:nr)
        # This deliberately bypasses parser/provenance validation and tests only
        # the evaluator's support selection on a hash-consistent trace value.
        synthetic_diag=merge(last_diag,(solver_eq_Jtor_A_per_m2=synthetic_rows,))
        synthetic_data=merge(d,(solver_jtor_diagnostic=synthetic_diag,))
        synthetic_hash=string(F.canonical_hash((data=synthetic_data,source_hash=trace.source_hash)))
        synthetic_trace=F.FreeGSAxisymmetricLCFSTraceV4(F._CCP_LCFS_TRACE_TOKEN,
            synthetic_data,trace.source_hash,synthetic_hash)
        synthetic_field=F.evaluate_freegs_axisymmetric_lcfs_current_field(synthetic_trace;
            state=:last_linear_solve_rhs,observation_points_rz_m=rhs_observation)
        synthetic_column=findfirst(==(outside_index),synthetic_field.plasma_source_indices)
        @test synthetic_column!==nothing
        if synthetic_column!==nothing
            @test all(isfinite,synthetic_field.jacobian[:,synthetic_column])
            @test any(value -> !iszero(value),synthetic_field.jacobian[:,synthetic_column])
        end
    end

    # Last-RHS is a frozen parsed state, not an override slot; invalid states
    # and typed absence fail closed instead of falling back.
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        state=:last_linear_solve_rhs,Jphi_A_per_m2=rhs_field.Jphi_A_per_m2)
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_lcfs_current_field(trace;
        state=:unknown_state)
    absent_rhs=F._freegs_parse_solver_jtor_diagnostic(nothing,
        F.JSON3.read(artifacts.input_json)[:solver_input],output_doc)
    @test absent_rhs.status===:typed_absent
    absent_rhs_trace_data=merge(d,(solver_jtor_diagnostic=absent_rhs,))
    absent_rhs_trace_hash=string(F.canonical_hash((data=absent_rhs_trace_data,
        source_hash=trace.source_hash)))
    absent_rhs_trace=F.FreeGSAxisymmetricLCFSTraceV4(F._CCP_LCFS_TRACE_TOKEN,
        absent_rhs_trace_data,trace.source_hash,absent_rhs_trace_hash)
    absent_rhs_field=F.evaluate_freegs_axisymmetric_lcfs_current_field(absent_rhs_trace;
        state=:last_linear_solve_rhs)
    @test absent_rhs_field.status===:typed_absent
    @test absent_rhs_field.reason===absent_rhs.reason

    input_doc=F.JSON3.read(artifacts.input_json); solver_doc=input_doc[:solver_input]
    function parse_rhs_diag(doc)
        F._freegs_parse_solver_jtor_diagnostic(doc,solver_doc,output_doc)
    end
    raw_rhs=output_doc[:solver_jtor_diagnostic]
    bad_rhs=Dict{Symbol,Any}(pairs(raw_rhs))
    bad_rhs[:axis_order]="Z_then_R"
    @test_throws ArgumentError parse_rhs_diag(bad_rhs)
    bad_norms=Dict{Symbol,Any}(pairs(raw_rhs[:solver_minus_recomputed_norms]))
    bad_norms[:difference_L2_frobenius_A_per_m2]+=1.0
    bad_rhs=Dict{Symbol,Any}(pairs(raw_rhs)); bad_rhs[:solver_minus_recomputed_norms]=bad_norms
    @test_throws ArgumentError parse_rhs_diag(bad_rhs)
    bad_integrals=Dict{Symbol,Any}(pairs(raw_rhs[:current_integrals]))
    bad_integrals[:solver_eq_Jtor_RZ_trapezoid_A]+=1.0
    bad_rhs=Dict{Symbol,Any}(pairs(raw_rhs)); bad_rhs[:current_integrals]=bad_integrals
    @test_throws ArgumentError parse_rhs_diag(bad_rhs)
    bad_rhs=Dict{Symbol,Any}(pairs(raw_rhs))
    bad_rhs[:R_m]=collect(raw_rhs[:R_m]); bad_rhs[:R_m][1]+=0.01
    @test_throws ArgumentError parse_rhs_diag(bad_rhs)
    bad_values=[collect(row) for row in raw_rhs[:solver_eq_Jtor_A_per_m2]]
    pop!(bad_values)
    bad_rhs=Dict{Symbol,Any}(pairs(raw_rhs)); bad_rhs[:solver_eq_Jtor_A_per_m2]=bad_values
    @test_throws ArgumentError parse_rhs_diag(bad_rhs)
    bad_values=[Float64.(collect(row)) for row in raw_rhs[:solver_eq_Jtor_A_per_m2]]
    bad_values[1][1]=Inf
    bad_rhs=Dict{Symbol,Any}(pairs(raw_rhs)); bad_rhs[:solver_eq_Jtor_A_per_m2]=bad_values
    @test_throws ArgumentError parse_rhs_diag(bad_rhs)
    overflow_values=[Float64.(collect(row)) for row in raw_rhs[:solver_eq_Jtor_A_per_m2]]
    overflow_values[1][1]=1.0e200
    overflow_rhs=Dict{Symbol,Any}(pairs(raw_rhs)); overflow_rhs[:solver_eq_Jtor_A_per_m2]=overflow_values
    @test_throws ArgumentError parse_rhs_diag(overflow_rhs)
    equal_huge_solver=[Float64.(collect(row)) for row in raw_rhs[:solver_eq_Jtor_A_per_m2]]
    equal_huge_profile=[Float64.(collect(row)) for row in raw_rhs[:recomputed_final_psi_Jphi_A_per_m2]]
    equal_huge_solver[2][2]=1.0e200; equal_huge_profile[2][2]=1.0e200
    equal_huge=Dict{Symbol,Any}(pairs(raw_rhs))
    equal_huge[:solver_eq_Jtor_A_per_m2]=equal_huge_solver
    equal_huge[:recomputed_final_psi_Jphi_A_per_m2]=equal_huge_profile
    equal_huge_error=try
        parse_rhs_diag(equal_huge)
        nothing
    catch err
        err
    end
    @test equal_huge_error isa ArgumentError
    @test equal_huge_error isa ArgumentError &&
        occursin("solver Jtor comparison norms overflowed",sprint(showerror,equal_huge_error))

    println("FREEGS_AXISYMMETRIC_NATIVE_CURRENT_FIELD_ACTUAL_JSON="*F.canonical_json((
        candidate_hash=d.candidate_hash,upstream_output_hash=d.upstream_output_hash,trace_hash=trace.trace_hash,
        plasma_source_count=nj,coil_ids=d.coil_ids,field_RZ_T=current_field.poloidal_field_RZ_T,
        plasma_field_RZ_T=current_field.plasma_poloidal_field_RZ_T,coil_field_RZ_T=current_field.coil_poloidal_field_RZ_T,
        signed_Jphi_response_max_error_T=j_error,PF_response_max_error_T=c_error,
        independent_angular_oracle_max_error_T_per_A=oracle_error,angular_refinement_max_error_T_per_A=oracle_refinement,
        full_sum_oracle_observation_index=full_k,full_sum_oracle_error_T=full_oracle_error,
        full_sum_angular_refinement_T=full_refinement,full_sum_oracle_scope=:one_actual_LCFS_point_all_signed_sources,
        fixed_point_RZ_m=only(fixed_observation),fixed_point_loop_BrBz_T=estimated_fixed,
        fixed_point_same_run_FreeGS_BrBz_T=(provider_fixed.Br_T,provider_fixed.Bz_T),
        fixed_point_absolute_difference_T=fixed_error,
        fixed_point_scope=:actual_fixed_domain_corner_shared_across_resolution_candidates,
        native_spacing_m=current_field.native_spacing_m,nearest_plasma_ring_distance_m=current_field.nearest_plasma_ring_distance_m,
        cell_quadrature_error=:unestimated,continuum_exterior_trace_validated=false,
        exterior_total_field=:typed_absent,independent_sheet_law=:typed_absent,
        independent_TF_source=:typed_absent,global_regional_dof_map=:typed_absent,
        physical_validation=false,equilibrium_recomputed=false)))
    flush(stdout)

    topology_timing=get(ENV,"FUSION_FREEGS_SOURCE_PRECHECK","0")=="1"
    topology_timing && (println("FREEGS_LCFS_TOPOLOGY_BUILD_BEGIN");flush(stdout))
    topology_started=time()
    topology=F.freegs_axisymmetric_topology_component(context,artifacts,indices,trace)
    topology_timing && (println("FREEGS_LCFS_TOPOLOGY_BUILD_END elapsed_s=",time()-topology_started);flush(stdout))
    @test topology isa F.FreeGSAxisymmetricTopologyComponentV4
    td=topology.data
    topology_started=time()
    topology_timing && (println("FREEGS_LCFS_TOPOLOGY_EVALUATE_BEGIN");flush(stdout))
    top=F.evaluate_freegs_axisymmetric_topology_component(topology,td.initial_state)
    topology_timing && (println("FREEGS_LCFS_TOPOLOGY_EVALUATE_END elapsed_s=",time()-topology_started);flush(stdout))
    @test size(top.jacobian)==(7,25)
    @test top.pressure_topology_rows_executed && top.current_topology_rows_executed
    @test !top.pressure_gauge_closed && !top.global_topology_closed && !top.plasma_return_path_verified
    top_oracle=zeros(7,25)
    topology_started=time()
    topology_timing && (println("FREEGS_LCFS_TOPOLOGY_ORACLE_BEGIN");flush(stdout))
    for j in 1:25
        z=ComplexF64.(collect(td.initial_state)); z[j]+=im*step
        top_oracle[:,j].=imag.(F._ccp_axisymmetric_topology_oracle(z,td.coordinates_m,td.profile_law))./step
    end
    topology_timing && (println("FREEGS_LCFS_TOPOLOGY_ORACLE_END elapsed_s=",time()-topology_started);flush(stdout))
    topology_error=maximum(abs.(top.jacobian-top_oracle))
    @test topology_error<=128eps(Float64)*max(1.0,maximum(abs,top_oracle))
    changed_top_state=collect(td.initial_state)
    changed_top_state[5]+=1.0e-5*(td.profile_law.psi_boundary_wb_per_rad-td.profile_law.psi_axis_wb_per_rad)
    changed_top=F.evaluate_freegs_axisymmetric_topology_component(topology,changed_top_state)
    @test changed_top.residual!=top.residual && changed_top.jacobian!=top.jacobian
    outside=collect(td.initial_state); outside[5]=td.profile_law.psi_boundary_wb_per_rad
    @test_throws ArgumentError F.evaluate_freegs_axisymmetric_topology_component(topology,outside)
    tampered=F.FreeGSAxisymmetricExecutionArtifactsV4(artifacts.receipt,
        artifacts.input_json,artifacts.output_json*" ",artifacts.field_samples_rz_m)
    @test_throws ArgumentError F.freegs_axisymmetric_lcfs_trace(context,tampered)
    println("FREEGS_AXISYMMETRIC_LCFS_TRACE_ACTUAL_JSON="*F.canonical_json((
        candidate_hash=d.candidate_hash,context_hash=d.context_hash,upstream_output_hash=d.upstream_output_hash,
        trace_hash=trace.trace_hash,coordinates_m=d.coordinates_m,normals_RZ=d.normals_RZ,
        psi_normalized=d.psi_normalized,initial_state=d.initial_state,
        intrinsic_boundary_residual=Tuple(base.residual),cauchy_traction_Pa=Tuple(base.cauchy_traction_cylindrical_Pa),
        coil_ids=d.coil_ids,coil_currents_A_per_turn=d.coil_currents_A_per_turn,
        coil_field_RZ_T=d.coil_field_RZ_T,plasma_field_RZ_T=d.plasma_field_RZ_T,
        pf_loop_support=d.pf_loop_support,
        outer_jacobian_max_error=outer_error,traction_jacobian_max_error=traction_error,
        actuator_traction_jacobian_max_error=current_error,
        topology_state=td.initial_state,topology_residual=Tuple(top.residual),
        topology_jacobian_max_error=topology_error,profile_law=td.profile_law,
        missing_closures=base.missing_closures,global_topology_closed=false,
        exterior_total_field=:typed_absent,independent_sheet_law=:typed_absent,
        plasma_return_path=:typed_absent,physical_validation=false)))
    flush(stdout)
    native_region===nothing || Base.invokelatest(test_actual_freegs_full_support_profile,F,context,artifacts,trace,native_region)
end
    return trace
end
function _test_actual_freegs_full_support_fixed_phase(F,context_ref::Ref{Any},artifacts,trace,region)
context=context_ref[]
d=trace.data
    started=time();println("FREEGS_FULL_PROFILE_BEGIN");flush(stdout)
    callback_started=time()
    legacy_native_field_id="source_fd_anchor_plus_plasma_spline_increment_v1"
    absolute_native_field_id="plasma_spline_plus_exact_pf_potential_jet_v1"
    native_field_env=get(ENV,"FUSION_FREEGS_NATIVE_FIELD_MODEL_ID",legacy_native_field_id)
    @test native_field_env in (legacy_native_field_id,absolute_native_field_id)
    native_field_optin=native_field_env==absolute_native_field_id
    component=native_field_optin ?
        F.freegs_axisymmetric_full_support_profile_callbacks(context,artifacts,trace;
            native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1) :
        F.freegs_axisymmetric_full_support_profile_callbacks(context,artifacts,trace)
    println("FREEGS_FULL_PROFILE_CALLBACK_END elapsed_s=",time()-callback_started);flush(stdout)
    @test component.status===:prepared_full_native_profile_component
    if native_field_optin
        @test component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1
        @test component.native_field_source_fd_equivalence===:not_claimed
        @test component.native_field_initial_state===:unchanged_accepted_FreeGS_field_samples
        @test component.native_field_initial_state_adjustment===:none
        @test component.native_exact_pf_grid_field_model===:unclipped_analytic_circular_filament_Green_jet
        @test component.native_exact_pf_grid_source_fd_anchor_use===:provenance_only
        @test_throws ArgumentError F.freegs_axisymmetric_full_support_profile_callbacks(context,artifacts,trace;
            native_field_model_id=:unsupported_native_field_model)
    else
        @test !hasproperty(component,:native_field_model_id)
    end
    if hasproperty(component,:pressure_domain_declaration_status) &&
            component.pressure_domain_declaration_status===:authored_law_only
        domain=F._freegs_owned_pressure_domain(context.candidate)
        geometry_map=component.pressure_domain_geometry_map
        @test component.grid_shape==(length(d.current_support.R_m),length(d.current_support.Z_m))
        @test geometry_map.status===:present
        if geometry_map.status===:present
            @test geometry_map.trace_hash==trace.trace_hash
            @test geometry_map.geometry_scope===:separate_frozen_actual_source_bound_64_point_lcfs_polygon
            @test geometry_map.topology_scope===:discrete_native_flux_connected_roles_without_contour_equivalence
            @test geometry_map.interface_boundary_binding==
                (interface_node_id=domain.interface_node_id,boundary_node_id=domain.boundary_node_id)
            @test geometry_map.region_role_map==(plasma_region_id=domain.plasma_region_id,
                vacuum_region_id=domain.vacuum_region_id,classification_rule=domain.classification_rule)
            @test geometry_map.polygon_orientation===:clockwise
            @test geometry_map.source_normal_orientation_check===:all_outward_normals_agree
            @test length(geometry_map.region_id_by_native_node)==length(component.core_mask)
            @test all(geometry_map.region_id_by_native_node[k]==
                (geometry_map.native_role_inside[k] ? domain.plasma_region_id : domain.vacuum_region_id)
                for k in eachindex(component.core_mask))
            @test geometry_map.native_role_inside==Tuple(component.core_mask)
            @test geometry_map.native_role_map.inside==Tuple(component.core_mask)
            @test geometry_map.native_role_map.classification_rule===domain.classification_rule
            @test geometry_map.native_role_map.source_representation===:FreeGS_profile_Jtor_final_psi_RZ_nodes
            @test geometry_map.native_role_map.source_output_hash==trace.data.upstream_output_hash
            @test geometry_map.native_role_map.source_output_hash==string(artifacts.receipt.output_hash)
            @test geometry_map.native_role_map.runner_code_hash==string(artifacts.receipt.runner_code_hash)
            @test geometry_map.native_role_map.role_count==2_879
            @test geometry_map.native_role_map.node_count==16_641
            @test geometry_map.pressure_dof_support_status===:present
            @test geometry_map.pressure_dof_support_mismatch_count==0
            @test geometry_map.continuous_geometry.classification_rule===:frozen_64_point_oriented_lcfs_polygon
            @test geometry_map.continuous_geometry.source_trace_hash==trace.trace_hash
            @test geometry_map.continuous_geometry.mismatch_with_discrete_roles_count==11
            # The separate 1537-sample closed-O contour has four different IDs:
            # (8539,8668,8669,8797); neither contour assigns these native roles.
            @test geometry_map.continuous_geometry.mismatch_with_discrete_roles_native_ids==
                (8414,8539,8542,8612,8668,8669,8670,8671,8797,8871,13737)
        end
        pressure_view=component.pressure_domain_view(component.initial_state)
        if geometry_map.status===:present && geometry_map.pressure_dof_support_status===:present
            @test component.pressure_domain_consumer_status===:derived_view_ready
            @test pressure_view.status===:derived_authored_fixed_geometry_pressure_view
            @test pressure_view.geometry_map===geometry_map
            @test pressure_view.plasma_region_id==domain.plasma_region_id
            @test pressure_view.vacuum_region_id==domain.vacuum_region_id
            @test pressure_view.interface_node_id==domain.interface_node_id
            @test pressure_view.boundary_node_id==domain.boundary_node_id
            @test pressure_view.solver_rows_added==0
            @test pressure_view.global_topology_closed===false && pressure_view.physical_validation===false
            @test :pressure_topology in component.missing_closures
            @test component.global_topology_closed===false && !component.physical_validation
            @test length(pressure_view.pressure_Pa)==length(component.core_mask)
            @test SparseArrays.issparse(pressure_view.jacobian)
            @test size(pressure_view.jacobian)==(length(component.core_mask),length(component.initial_state))
            @test all(pressure_view.pressure_Pa[k]==component.initial_state[component.pressure_dofs[k]]
                for k in findall(component.core_mask))
            @test all(pressure_view.pressure_Pa[k]==domain.exterior_pressure_pa
                for k in findall(!,component.core_mask))
            changed=copy(component.initial_state)
            core_node=first(findall(component.core_mask));core_dof=component.pressure_dofs[core_node]
            changed[core_dof]+=1.0
            changed_view=component.pressure_domain_view(changed)
            @test changed_view.status===:derived_authored_fixed_geometry_pressure_view
            @test changed_view.pressure_Pa[core_node]==component.initial_state[core_dof]+1.0
            @test all(changed_view.pressure_Pa[k]==domain.exterior_pressure_pa
                for k in findall(!,component.core_mask))
        else
            @test component.pressure_domain_consumer_status===:typed_absent
            geometry_map.status===:present && begin
                @test geometry_map.pressure_dof_support_status===:typed_absent
                @test geometry_map.pressure_dof_support_mismatch_count>0
            end
            @test pressure_view.status===:typed_absent
            @test pressure_view.pressure_Pa===nothing && pressure_view.jacobian===nothing
        end

        # Synthetic cases prove native roles follow the mask while continuous geometry stays a separate diagnostic.
        theta=((k+0.5)*2pi/64 for k in 0:63)
        points=Tuple((2.0+sin(a),cos(a)) for a in theta)
        outward=Tuple((sin(a),cos(a)) for a in theta)
        # The radius-one polygon has R<=3: the R=3.1 column is strictly exterior.
        synthetic_R=(2.0,3.1);synthetic_Z=(-0.5,0.0,0.5)
        synthetic_mask=(true,true,true,false,false,false)
        classify(poly,normals,rgrid,zgrid,mask,dofs=Tuple(mask[k] ? k : 0 for k in eachindex(mask)))=
            F._ccp_pressure_domain_geometry_map(poly,normals,rgrid,zgrid,mask,dofs,domain,
                "synthetic-trace",:final_total_psi_grid_spline_radial_lcfs,
                "synthetic-source-output","synthetic-runner-code")
        synthetic=classify(points,outward,synthetic_R,synthetic_Z,synthetic_mask)
        @test synthetic.status===:present
        @test classify(points,outward,collect(synthetic_R),collect(synthetic_Z),synthetic_mask)==synthetic
        for bad_R in ((2.0,2.0),(2.9,2.0),(NaN,2.9)), axis_form in (identity,collect)
            bad_axis=classify(points,outward,axis_form(bad_R),axis_form(synthetic_Z),synthetic_mask)
            @test bad_axis==(status=:typed_absent,reason=:lcfs_polygon_coordinates_nonfinite)
        end
        for bad_Z in ((-0.5,-0.5,0.5),(0.5,0.0,-0.5),(-0.5,0.0,Inf)), axis_form in (identity,collect)
            bad_axis=classify(points,outward,axis_form(synthetic_R),axis_form(bad_Z),synthetic_mask)
            @test bad_axis==(status=:typed_absent,reason=:lcfs_polygon_coordinates_nonfinite)
        end
        @test synthetic.continuous_geometry.inside==(true,true,true,false,false,false)
        @test synthetic.native_role_inside==synthetic_mask
        @test synthetic.continuous_geometry.mismatch_with_discrete_roles_count==0
        @test synthetic.pressure_dof_support_status===:present
        @test synthetic.region_id_by_native_node==
            (domain.plasma_region_id,domain.plasma_region_id,domain.plasma_region_id,
             domain.vacuum_region_id,domain.vacuum_region_id,domain.vacuum_region_id)
        island_mask=classify(points,outward,synthetic_R,synthetic_Z,trues(6))
        @test island_mask.status===:present
        @test island_mask.continuous_geometry.inside==synthetic.continuous_geometry.inside
        @test island_mask.native_role_inside==Tuple(trues(6))
        @test island_mask.continuous_geometry.mismatch_with_discrete_roles_count==3
        @test island_mask.continuous_geometry.mismatch_with_discrete_roles_native_ids==(4,5,6)
        @test island_mask.pressure_dof_support_status===:present
        @test all(==(domain.plasma_region_id),island_mask.region_id_by_native_node)
        hole_mask=classify(points,outward,synthetic_R,synthetic_Z,falses(6))
        @test hole_mask.status===:present
        @test hole_mask.continuous_geometry.inside==synthetic.continuous_geometry.inside
        @test hole_mask.native_role_inside==Tuple(falses(6))
        @test hole_mask.continuous_geometry.mismatch_with_discrete_roles_count==3
        @test hole_mask.continuous_geometry.mismatch_with_discrete_roles_native_ids==(1,2,3)
        @test hole_mask.pressure_dof_support_status===:present
        @test all(==(domain.vacuum_region_id),hole_mask.region_id_by_native_node)
        dof_mismatch=classify(points,outward,synthetic_R,synthetic_Z,synthetic_mask,(0,2,3,0,0,0))
        @test dof_mismatch.status===:present
        @test dof_mismatch.pressure_dof_support_status===:typed_absent
        @test dof_mismatch.pressure_dof_support_mismatch_count==1
        @test dof_mismatch.pressure_dof_support_mismatch_native_ids==(1,)
        bad_role_types=classify(points,outward,synthetic_R,synthetic_Z,(1,1,1,0,0,0),(1,2,3,0,0,0))
        @test bad_role_types.status===:typed_absent
        @test bad_role_types.reason===:native_role_mask_or_pressure_dof_map_invalid
        reversed=classify(reverse(points),reverse(outward),synthetic_R,synthetic_Z,synthetic_mask)
        @test reversed.status===:typed_absent
        @test reversed.reason===:lcfs_polygon_orientation_unexpected
        flipped_normals=classify(points,Tuple((-v[1],-v[2]) for v in outward),
            synthetic_R,synthetic_Z,synthetic_mask)
        @test flipped_normals.status===:typed_absent
        @test flipped_normals.reason===:source_normals_disagree_with_clockwise_lcfs_orientation
        boundary_R=(points[1][1],3.0);boundary_Z=(points[1][2],1.1)
        boundary=classify(points,outward,boundary_R,boundary_Z,falses(4))
        @test boundary.status===:typed_absent
        @test boundary.reason===:native_node_on_lcfs_interface
        star_order=Tuple(mod1(1+3k,64) for k in 0:63)
        star_points=Tuple(points[k] for k in star_order)
        star_normals=Tuple(outward[k] for k in star_order)
        ambiguous=classify(star_points,star_normals,synthetic_R,synthetic_Z,synthetic_mask)
        @test ambiguous.status===:typed_absent
    else
        @test component.pressure_domain_declaration_status===:typed_absent
        @test component.pressure_domain_geometry_map.status===:typed_absent
        @test component.pressure_domain_geometry_map.reason===:no_authored_pressure_domain
        @test component.pressure_domain_consumer_status===:typed_absent
        absent_view=component.pressure_domain_view(component.initial_state)
        @test absent_view.status===:typed_absent
        @test absent_view.reason===:no_authored_pressure_domain
        @test absent_view.pressure_Pa===nothing && absent_view.jacobian===nothing
    end
    n=length(artifacts.field_samples_rz_m); nr,nz=component.grid_shape
    parsed_output=F.JSON3.read(artifacts.output_json)
    @test n==nr*nz && length(component.initial_state)==4n+count(component.core_mask)
    @test length(component.core_mask)==n && count(component.core_mask)==region.grid_coverage.core_node_count
    @test n==16_641 && count(component.core_mask)==2_879
    @test component.profile_row_count==19_520
    @test count(>(0),component.pressure_dofs)==2_879
    @test length(trace.data.coordinates_m)==64
    core_ids=findall(component.core_mask)
    tails=setdiff(core_ids,collect(region.grid_coverage.node_native_ids))
    @test length(tails)==4 && Tuple(sort(tails))==(8539,8668,8669,8797)
    @test all(k->component.raw_constitutive_status[k]===:present,tails)
    @test all(k->component.pressure_dofs[k]==0 && component.pressure_rows[k]==0,findall(!,component.core_mask))
    @test length(component.boundary_native_ids)==2nr+2nz-4
    @test all(k->!component.core_mask[k] && component.raw_constitutive_status[k]===:typed_absent,
        component.boundary_native_ids)
    exterior=component.exterior_native_ids
    @test length(exterior)==13762
    @test all(k->component.raw_constitutive_reason[k]===artifacts.field_samples_rz_m[k].constitutive.reason,exterior)
    @test Set(component.raw_constitutive_reason[exterior])==Set((:outside_supported_core,:domain_boundary))
    @test count(==(:domain_boundary),component.raw_constitutive_reason)==512
    @test all(k->component.raw_constitutive_reason[k]===:domain_boundary,component.boundary_native_ids)
    outer=component.boundary_trace(component.initial_state)
    @test Tuple(x.face for x in outer)==(:R_min,:R_max,:Z_min,:Z_max)
    @test sum(length(x.native_ids) for x in outer)==2nr+2nz
    @test length(unique(vcat((collect(x.native_ids) for x in outer)...)))==2nr+2nz-4
    @test all(length(x.native_ids)==length(x.coordinates_RZ_m)==length(x.B_cylindrical_T)==
        length(x.normal_B_T) for x in outer)
    @test all(SparseArrays.issparse(x.B_cylindrical_jacobian) &&
        SparseArrays.issparse(x.normal_B_jacobian) for x in outer)
    @test all(size(x.B_cylindrical_jacobian)==(3length(x.native_ids),length(component.initial_state)) &&
        size(x.normal_B_jacobian)==(length(x.native_ids),length(component.initial_state)) for x in outer)
    @test all(x.Bphi_source===:authored_G3_TF_equals_Fvac_over_R &&
        x.poloidal_source===:same_run_FreeGS_total_B_plus_fixed_PF_delta_psi &&
        x.psi_increment_interpretation===:total_flux_increment_equals_plasma_flux_increment for x in outer)
    for face in outer, q in eachindex(face.native_ids)
        k=face.native_ids[q]; sample=artifacts.field_samples_rz_m[k]
        @test face.source_reference_B_cylindrical_T[q]==
            (sample.Br_T,component.initial_state[4k-2],sample.Bz_T)
        @test all(isapprox(face.B_cylindrical_T[q][axis],
            face.source_reference_B_cylindrical_T[q][axis];rtol=64eps(Float64),atol=0)
            for axis in 1:3)
        @test isapprox(face.B_cylindrical_T[q][2],
            component.profile_law.fvac_T_m/face.coordinates_RZ_m[q][1];rtol=64eps(Float64),atol=0)
        @test face.normal_B_T[q]==face.normal_RZ[1]*sample.Br_T+
            face.normal_RZ[2]*sample.Bz_T
    end
    Ra=collect(trace.data.current_support.R_m);Za=collect(trace.data.current_support.Z_m)
    Or=F._ccp_native_spline_derivative_oracle(Ra);Oz=F._ccp_native_spline_derivative_oracle(Za)
    for face in outer
        expected=SparseArrays.spzeros(Float64,3length(face.native_ids),length(component.initial_state))
        projection=SparseArrays.spzeros(Float64,length(face.native_ids),3length(face.native_ids))
        for (q,k) in enumerate(face.native_ids)
            i=cld(k,nz);j=mod1(k,nz)
            for l in 1:nz
                expected[3q-2,4*((i-1)*nz+l)]=-Oz[j,l]/Ra[i]
            end
            for l in 1:nr
                expected[3q,4*((l-1)*nz+j)]=Or[i,l]/Ra[i]
            end
            projection[q,3q-2]=face.normal_RZ[1]
            projection[q,3q]=face.normal_RZ[2]
        end
        @test maximum(abs,SparseArrays.nonzeros(face.B_cylindrical_jacobian-expected);init=0.0)<=
            256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(expected);init=0.0))
        expected_normal=projection*expected
        @test maximum(abs,SparseArrays.nonzeros(face.normal_B_jacobian-expected_normal);init=0.0)<=
            256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(expected_normal);init=0.0))
    end
    changed_outer=collect(component.initial_state)
    changed_outer[4*component.boundary_native_ids[1]]+=1e-5
    changed_trace=component.boundary_trace(changed_outer)
    for (face,altered) in zip(outer,changed_trace)
        delta=changed_outer-component.initial_state
        expected_changed=component.boundary_native_ids[1] in face.native_ids
        @test (altered.B_cylindrical_T!=face.B_cylindrical_T)==expected_changed
        predicted=face.B_cylindrical_jacobian*delta
        observed=collect(Iterators.flatten(altered.B_cylindrical_T))-collect(Iterators.flatten(face.B_cylindrical_T))
        @test maximum(abs,predicted-observed;init=0.0)<=
            256eps(Float64)*max(1.0,maximum(abs,observed;init=0.0))
        @test maximum(abs,face.normal_B_jacobian*delta-
            (altered.normal_B_T.-face.normal_B_T);init=0.0)<=
            256eps(Float64)*max(1.0,maximum(abs,altered.normal_B_T.-face.normal_B_T;init=0.0))
    end
    @test length(component.executed_exterior_TF_Bphi_T)==length(exterior)
    @test all(q->isapprox(component.initial_state[4exterior[q]-2],component.executed_exterior_TF_Bphi_T[q];
        rtol=64eps(Float64),atol=0),eachindex(exterior))
    @test component.internal_core_F_is_total
    @test component.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    @test !component.raw_exterior_constitutive_reclassified && !component.global_topology_closed
    @test hasproperty(component,:lcfs_dynamic_geometry_trace)
    @test component.computational_outer_K===:typed_absent && component.full_current_conservation===:typed_absent
    @test F._ccp_full_profile_law_supported(component.profile_law)
    @test !F._ccp_full_profile_law_supported(merge(component.profile_law,(alpha_n=3.0,)))
    profile_rows=n+length(core_ids)
    x=component.initial_state;evaluate_started=time();base=component.evaluate(x)
    if native_field_optin
        @test base.native_field_model_id===component.native_field_model_id
    else
        @test !hasproperty(base,:native_field_model_id)
    end
    println("FREEGS_FULL_PROFILE_EVALUATE_END elapsed_s=",time()-evaluate_started);flush(stdout)
    source_native_mode=(get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1" ||
        get(ENV,"FUSION_FREEGS_NATIVE_GRID_MHD","0")=="1")
    source_replay_dir=get(ENV,"FUSION_FREEGS_LCFS_REPLAY_ARTIFACT_DIRECTORY","")
    source_fresh=source_native_mode && get(ENV,"FUSION_FREEGS_SOURCE_PRECHECK","0")=="0" &&
        isempty(source_replay_dir)
    source_present=trace.data.offgrid_source_method!==nothing
    best=(a=0,node=0,S=0.0,q=0.0);delta=0.0
    @test !source_fresh || source_present
    @test hasproperty(component,:lcfs_profile_current_trace)
    if source_present
    # Reconstruct independent tensor-cubic value/gradient weights for the 64
    # off-grid source points. This oracle uses the independently solved spline
    # derivative operator and explicit Hermite basis, not the consumer tables.
        sources=trace.data.offgrid_source;method=trace.data.offgrid_source_method
        source_plasma=parsed_output[:native_gs_state][:plasma_psi_wb_per_rad]
        @test length(sources)==64 && all(s->s.status===:present,sources)
        @test method.gradient_method=="analytic_installed_FreeGS_Greens_sum_weighted_by_current_times_turns"
        @test method.gradient_validation=="centered_difference_of_installed_FreeGS_Greens_source_per_LCFS_point"
        @test all(s->s.coil_psi_gradient_status===:present,sources)
        law0=component.profile_law
        @test F._freegs_parse_lcfs_offgrid_source(nothing,d.coordinates_m[1][1],law0,
            law0.psi_axis_wb_per_rad,law0.psi_boundary_wb_per_rad).status===:typed_absent
        bad_source=Dict{Symbol,Any}(pairs(F.JSON3.read(F.canonical_json(sources[1]))))
        bad_source[:coil_psi_gradient_RZ_Wb_per_rad_m]=[Inf,0.0]
        @test_throws ArgumentError F._freegs_parse_lcfs_offgrid_source(bad_source,
            d.coordinates_m[1][1],law0,law0.psi_axis_wb_per_rad,law0.psi_boundary_wb_per_rad)
        @test all(s->s.eq_profile_axis_pairs_equal===
            (s.eq_psi_axis_wb_per_rad==s.profile_psi_axis_wb_per_rad &&
             s.eq_psi_boundary_wb_per_rad==s.profile_psi_boundary_wb_per_rad),sources)
        @test all(s->s.mask_source=="sampled_eq.mask_func RectBivariateSpline of sampled_eq.mask",sources)
        @test all(s->s.mask_matches_refreshed_current_support isa Bool,sources)
        @test minimum(s.mask_value for s in sources)<0.0 # preserve actual mask overshoot
        @test all(s->all(isfinite,s.mask_gradient_RZ_per_m),sources)
        function lcfs_weights(axis,at,D)
            n1=length(axis);i=clamp(searchsortedlast(axis,at),1,n1-1)
            h=axis[i+1]-axis[i];t=(at-axis[i])/h
            h00=2t^3-3t^2+1;h10=t^3-2t^2+t
            h01=-2t^3+3t^2;h11=t^3-t^2
            v=h10*h.*D[i,:]+h11*h.*D[i+1,:]
            v[i]+=h00;v[i+1]+=h01
            derivative_weights=((6t^2-6t)/h).*([j==i ? 1.0 : 0.0 for j in 1:n1])+((3t^2-4t+1)).*D[i,:]+
                ((-6t^2+6t)/h).*([j==i+1 ? 1.0 : 0.0 for j in 1:n1])+((3t^2-2t)).*D[i+1,:]
            v,derivative_weights
        end
        raxis=collect(trace.data.current_support.R_m);zaxis=collect(trace.data.current_support.Z_m)
        Dr=F._ccp_native_spline_derivative_oracle(raxis);Dz=F._ccp_native_spline_derivative_oracle(zaxis)
        W=Matrix{Float64}(undef,64,nr);WR=similar(W)
        _lcfs_offgrid_wz=Matrix{Float64}(undef,64,nz)
        _lcfs_offgrid_wzd=similar(_lcfs_offgrid_wz)
        for a in 1:64
            W[a,:],WR[a,:]=lcfs_weights(raxis,d.coordinates_m[a][1],Dr)
            wz,wzd=lcfs_weights(zaxis,d.coordinates_m[a][2],Dz)
            # Keep the R and Z factors separately for an independent tensor product.
            _lcfs_offgrid_wz[a,:]=wz;_lcfs_offgrid_wzd[a,:]=wzd
        end
        function independent_offgrid(state,a)
            pg=Matrix{Float64}(undef,nr,nz)
            for i in 1:nr,j in 1:nz
                psi_dof=4*((i-1)*nz+j)
                pg[i,j]=Float64(source_plasma[i][j])+state[psi_dof]-x[psi_dof]
            end
            s=sources[a]
            qpsi=sum(W[a,i]*_lcfs_offgrid_wz[a,j]*pg[i,j] for i in 1:nr,j in 1:nz)+s.coil_psi_wb_per_rad
            gR=sum(WR[a,i]*_lcfs_offgrid_wz[a,j]*pg[i,j] for i in 1:nr,j in 1:nz)+s.coil_psi_gradient_RZ_Wb_per_rad_m[1]
            gZ=sum(W[a,i]*_lcfs_offgrid_wzd[a,j]*pg[i,j] for i in 1:nr,j in 1:nz)+s.coil_psi_gradient_RZ_Wb_per_rad_m[2]
            q=(qpsi-s.eq_psi_axis_wb_per_rad)/(s.eq_psi_boundary_wb_per_rad-s.eq_psi_axis_wb_per_rad)
            law=component.profile_law;Dprof=s.profile_psi_axis_wb_per_rad-s.profile_psi_boundary_wb_per_rad
            eqspan=s.eq_psi_boundary_wb_per_rad-s.eq_psi_axis_wb_per_rad
            I=q<=0 ? 1/3-q : q>=1 ? 0.0 : (1-q)^3/3
            f2=law.fvac_T_m^2+2law.mu0_N_per_A2*law.Raxis_m*(law.L_A_per_m2*(1-law.Beta0))*Dprof*I
            f=sqrt(f2);fq=-law.mu0_N_per_A2*(law.L_A_per_m2*(1-law.Beta0))*law.Raxis_m*Dprof*(1-clamp(q,0,1))^2/f
            m=s.mask_value;mr,mz=s.mask_gradient_RZ_per_m;R=d.coordinates_m[a][1]
            Fmix=m*f+(1-m)*law.fvac_T_m
            dF_dR=m*fq*gR/eqspan+(f-law.fvac_T_m)*mr
            dF_dZ=m*fq*gZ/eqspan+(f-law.fvac_T_m)*mz
            # Curl the independently reconstructed scalar Fmix/R field.
            Jn=(d.normals_RZ[a][2]*dF_dR-d.normals_RZ[a][1]*dF_dZ)/
                (law.mu0_N_per_A2*R)
            mu=law.mu0_N_per_A2;ra=law.Raxis_m;u=law.L_A_per_m2*law.Beta0
            v=law.L_A_per_m2*(1-law.Beta0);slope=(1-clamp(q,0,1))^2
            ds=0<q<1 ? -2(1-q) : 0.0;c=mu*v*ra*Dprof
            fqq=-c*ds/f-fq^2/f;fv=mu*ra*Dprof*I/f
            fqv=-mu*ra*Dprof*slope/f-fq*fv/f
            nr0,nz0=d.normals_RZ[a];hflux=nz0*gR-nr0*gZ
            hmask=nz0*mr-nr0*mz
            partials=zeros(3,5)
            partials[1,1]=-u*Dprof*slope/ra;partials[1,4]=Dprof*I/ra
            partials[2,1]=m*fq;partials[2,5]=m*fv
            partials[3,1]=(m*fqq*hflux/eqspan+fq*hmask)/(mu*R)
            partials[3,2]=m*fq*nz0/(eqspan*mu*R)
            partials[3,3]=-m*fq*nr0/(eqspan*mu*R)
            partials[3,5]=(m*fqv*hflux/eqspan+fv*hmask)/(mu*R)
            (psi=qpsi,q=q,gR=gR,gZ=gZ,p=(law.L_A_per_m2*law.Beta0)*Dprof*I/law.Raxis_m,
             Bphi=Fmix/R,F=f,Jn=Jn,partials=partials)
        end
        anchor=component.lcfs_profile_current_trace(x;with_jacobian=false)
        @test anchor.status===:evaluated_fixed_LCFS_offgrid_profile_and_curl_Bphi
        moving=component.lcfs_profile_current_trace(x;dynamic_geometry=true)
        @test moving.status===:typed_absent
        @test moving.reason===:dynamic_geometry_only_profile_current_source_rebind_pending
        @test moving.source_fields_reused===false
        geometry=moving.dynamic_geometry
        @test geometry.status===:evaluated_dynamic_LCFS_geometry
        @test length(geometry.coordinates_RZ_m)==64 && length(geometry.normals_RZ)==64
        @test length(geometry.surface_quadrature_m2)==64
        @test size(geometry.coordinate_jacobian)==(128,n)
        @test size(geometry.normal_jacobian)==(128,n)
        @test size(geometry.surface_quadrature_jacobian)==(64,n)
        @test size(geometry.axis_flux_jacobian)==(1,n)
        @test size(geometry.boundary_flux_jacobian)==(1,n)
        @test size(geometry.boundary_coordinate_jacobian)==(2,n)
        @test geometry.psi_global_dof_ids==Tuple(4k for k in 1:n)
        if native_field_optin
            @test geometry.field_model_id===absolute_native_field_id
            @test all(a->abs((geometry.composite_surface_psi_Wb_per_rad[a]-
                geometry.psi_boundary_Wb_per_rad)/geometry.profile_endpoint_values.delta-1)<=1e-9,1:64)
        end
        @test geometry.ray_rule===Symbol("64_ray_first_sampled_outward_psiN_1_bracket")
        @test geometry.mask_event===:unchanged && geometry.solver_rows_added==0
        @test !geometry.global_topology_closed && !geometry.physical_validation
        moved_state=copy(x);motion_node=trace.data.current_support.critical_points.opoints[1].nearest_native_id
        motion_step=1e-6*abs(geometry.psi_boundary_Wb_per_rad-geometry.psi_axis_Wb_per_rad)
        moved_state[4motion_node]+=motion_step
        moved_geometry=component.lcfs_profile_current_trace(moved_state;dynamic_geometry=true)
        @test moved_geometry.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry
        moved_coordinates=[q for point in moved_geometry.dynamic_geometry.coordinates_RZ_m for q in point]
        base_coordinates=[q for point in geometry.coordinates_RZ_m for q in point]
        @test maximum(abs,moved_coordinates.-base_coordinates)>0.0
        @test anchor.pressure_scope===:offgrid_profile_evaluation_not_exterior_native_pressure
        pressure_only=component.lcfs_profile_current_trace(x;pressure_only=true,with_jacobian=true)
        @test pressure_only.status===:evaluated_fixed_LCFS_pressure_only
        @test pressure_only.current_status===:not_evaluated_by_pressure_only_request
        @test pressure_only.pressure_scope===anchor.pressure_scope
        @test pressure_only.pressure_field_definition===:same_source_profile_p_of_actual_total_psi
        @test pressure_only.pressure_state_representation===:constrained_native_nodal_samples
        @test pressure_only.pressure_dof_interpolation===:not_used
        @test pressure_only.pressure_trace_scope===:fixed_actual_source_lcfs_64_points
        @test size(pressure_only.pressure_jacobian)==(64,length(x))
        @test pressure_only.pressure_trace_extra_solver_rows==0
        @test pressure_only.global_topology_closed===false
        @test isapprox(pressure_only.profile_pressure_Pa,anchor.profile_pressure_Pa;rtol=0,atol=0)
        @test isapprox(pressure_only.pressure_residual,anchor.residual[1:3:end];rtol=0,atol=0)
        q1_pressure=F._ccp_lcfs_profile_pressure(1.0,
            component.profile_law.L_A_per_m2*component.profile_law.Beta0,
            sources[1],component.profile_law)
        @test q1_pressure.pressure==0.0 && q1_pressure.dp_dq==0.0
        anchor_psi=[independent_offgrid(x,a).psi for a in 1:64]
        for a in 1:64
            q=independent_offgrid(x,a);s=sources[a]
            @test isapprox(q.psi,s.psi_physical_wb_per_rad;rtol=2e-12,atol=2e-12)
            @test isapprox(q.p,s.profile_pressure_Pa;rtol=2e-12,atol=1e-10)
            @test isapprox(q.Bphi,s.Btor_T;rtol=2e-12,atol=2e-12)
            @test isapprox(q.F,s.fpol_T_m;rtol=2e-12,atol=2e-12)
            @test isapprox(anchor.fields[a,1],q.p;rtol=2e-12,atol=1e-10)
            @test isapprox(pressure_only.profile_pressure_Pa[a],q.p;rtol=2e-12,atol=1e-10)
            @test isapprox(anchor.fields[a,2],q.Bphi;rtol=2e-12,atol=2e-12)
            @test isapprox(anchor.fields[a,5],q.Jn;rtol=2e-11,atol=1e-10)
            @test isapprox(anchor.fpol_T_m[a],q.F;rtol=2e-12,atol=2e-12)
        end
        # A noncore node with the largest independent tensor weight at one
        # off-grid point gives a deterministic q=0.9 changing-state holdout.
        best=(absweight=0.0,a=0,node=0,S=0.0,q=0.0)
        for a in 1:64,node in findall(!,component.core_mask)
            i=cld(node,nz);j=mod1(node,nz);S=W[a,i]*_lcfs_offgrid_wz[a,j]
            q0=(anchor_psi[a]-sources[a].eq_psi_axis_wb_per_rad)/
                (sources[a].eq_psi_boundary_wb_per_rad-sources[a].eq_psi_axis_wb_per_rad)
            if abs(S)>best.absweight;best=(absweight=abs(S),a=a,node=node,S=S,q=q0);end
        end
        @test best.a>0 && best.S!=0
        span=sources[best.a].eq_psi_boundary_wb_per_rad-sources[best.a].eq_psi_axis_wb_per_rad
        delta=(0.9-best.q)*span/best.S
        changed=collect(x);changed[4best.node]+=delta
        noJ=component.lcfs_profile_current_trace(changed;with_jacobian=false)
        fullJ=component.lcfs_profile_current_trace(changed;with_jacobian=true)
        @test noJ.status===fullJ.status===:evaluated_fixed_LCFS_offgrid_profile_and_curl_Bphi
        @test length(fullJ.pressure_residual)==64
        @test size(fullJ.pressure_jacobian)==(64,length(changed))
        @test fullJ.pressure_residual==fullJ.residual[1:3:end]
        @test fullJ.pressure_jacobian==fullJ.jacobian[1:3:192,:]
        pressure_only_changed=component.lcfs_profile_current_trace(changed;pressure_only=true,with_jacobian=true)
        @test pressure_only_changed.status===:evaluated_fixed_LCFS_pressure_only
        @test pressure_only_changed.current_status===:not_evaluated_by_pressure_only_request
        @test pressure_only_changed.pressure_residual==fullJ.pressure_residual
        oracle=independent_offgrid(changed,best.a)
        @test isapprox(oracle.q,0.9;rtol=0,atol=1e-12)
        @test isapprox(oracle.psi,noJ.psi_physical_wb_per_rad[best.a];rtol=2e-12,atol=2e-12)
        @test isapprox(oracle.p,noJ.fields[best.a,1];rtol=2e-11,atol=1e-9)
        @test isapprox(oracle.Bphi,noJ.fields[best.a,2];rtol=2e-11,atol=2e-12)
        @test isapprox(oracle.Jn,noJ.fields[best.a,5];rtol=2e-10,atol=1e-8)
        # Compare the entire 192-by-ndof sparse current Jacobian against the
        # independent point derivatives and tensor weights without a dense copy.
        point_oracles=[independent_offgrid(changed,a) for a in 1:64]
        Jlcfs=fullJ.jacobian;actual_col=zeros(192);sparse_defect=0.0
        for col in axes(Jlcfs,2)
            fill!(actual_col,0.0)
            for ptr in Jlcfs.colptr[col]:Jlcfs.colptr[col+1]-1
                actual_col[Jlcfs.rowval[ptr]]=Jlcfs.nzval[ptr]
            end
            if col<=4n && mod(col,4)==0
                node=col÷4;i=cld(node,nz);j=mod1(node,nz)
                for a in 1:64
                    point=point_oracles[a];s=sources[a]
                    span_a=s.eq_psi_boundary_wb_per_rad-s.eq_psi_axis_wb_per_rad
                    S=W[a,i]*_lcfs_offgrid_wz[a,j]
                    SR=WR[a,i]*_lcfs_offgrid_wz[a,j]
                    SZ=W[a,i]*_lcfs_offgrid_wzd[a,j]
                    actual_expected=(point.partials[1,1]*S/span_a,
                        point.partials[2,1]*S/span_a,
                        point.partials[3,1]*S/span_a+point.partials[3,2]*SR+point.partials[3,3]*SZ)
                    for r in 1:3
                        row=3a-3+r
                        sparse_defect=max(sparse_defect,abs(actual_col[row]-actual_expected[r]))
                    end
                end
            else
                sparse_defect=max(sparse_defect,maximum(abs,actual_col))
            end
        end
        sparse_bound=256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(Jlcfs)))
        @test sparse_defect<=sparse_bound
        # Preserve the exact clipped-axis kink as unsupported.
        @test noJ.fields[best.a,1:2]!=anchor.fields[best.a,1:2]
        h=1e-6*abs(span/best.S);xp=copy(changed);xm=copy(changed)
        xp[4best.node]+=h;xm[4best.node]-=h
        pressure_rp=component.lcfs_profile_current_trace(xp;pressure_only=true,with_jacobian=false).pressure_residual
        pressure_rm=component.lcfs_profile_current_trace(xm;pressure_only=true,with_jacobian=false).pressure_residual
        @test isapprox((pressure_rp-pressure_rm)/(2h),pressure_only_changed.pressure_jacobian[:,4best.node];
            rtol=5e-6,atol=5e-18)
        rp=component.lcfs_profile_current_trace(xp;with_jacobian=false).residual
        rm=component.lcfs_profile_current_trace(xm;with_jacobian=false).residual
        @test isapprox((rp-rm)/(2h),fullJ.jacobian[:,4best.node];rtol=5e-6,atol=5e-11)

        Base.invokelatest(test_lcfs_dynamic_geometry_numeric,F)
        println("FREEGS_DYNAMIC_GEOMETRY_NUMERIC_FULL_BEGIN grid=129x129 elapsed_s=",time()-started,
            " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        Base.invokelatest(test_lcfs_dynamic_geometry_numeric,F;full_size=true)
        println("FREEGS_DYNAMIC_GEOMETRY_NUMERIC_FULL_END grid=129x129 elapsed_s=",time()-started,
            " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        Base.invokelatest(test_actual_lcfs_dynamic_geometry_component,F,trace,component)
        @test_throws DomainError F._ccp_lcfs_offgrid_profile_point(0.0,0.0,0.0,
            component.profile_law.L_A_per_m2*component.profile_law.Beta0,
            component.profile_law.L_A_per_m2*(1-component.profile_law.Beta0),
            d.coordinates_m[best.a][1],d.normals_RZ[best.a],sources[best.a],component.profile_law)
        fullJ=nothing;Jlcfs=nothing;actual_col=nothing;point_oracles=nothing
        GC.gc(false)
    else
        @test trace.data.offgrid_source_method===nothing
        @test all(s->s.status===:typed_absent,trace.data.offgrid_source)
    end
    @test size(base.jacobian)==(3n+length(core_ids)+component.gs_row_count+
        component.normalization_row_count+component.hagenow_boundary_row_count,4n+length(core_ids))
    @test SparseArrays.nnz(base.jacobian)<=n+3length(core_ids)+n*(nr+nz+2)+
        11component.gs_row_count+2component.normalization_row_count+
        component.hagenow_boundary_row_count*(length(core_ids)+1)
    native_grid_mhd=get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1"
    if native_grid_mhd
        if isempty(get(ENV,"FUSION_FREEGS_LCFS_REPLAY_ARTIFACT_DIRECTORY",""))
            @test get(ENV,"FUSION_FREEGS_SOURCE_PRECHECK","0")=="0"
        end
        @test component.gs_status===:present && component.gs_row_count==16_129
        @test component.hagenow_status===:present && component.hagenow_boundary_row_count==512
        @test artifacts.hagenow_source_response!==nothing
        @test component.hagenow_source_reference.full_jacobian_status===:passed
        @test component.hagenow_source_reference.api===:freegs_boundary_freeBoundaryHagenow
        @test !component.hagenow_source_reference.absolute_boundary_anchor_subtracted
        @test !component.hagenow_source_reference.source_eq_mutated
        @test component.hagenow_source_reference.source_plasma_psi_input_copy
    end
    oracle_started=time();oracle=component.jacobian_oracle(x)
    println("FREEGS_FULL_PROFILE_ORACLE_END elapsed_s=",time()-oracle_started);flush(stdout)
    oracle_compare_started=time()
    println("FREEGS_FULL_PROFILE_ORACLE_SPARSE_COMPARE_BEGIN elapsed_s=",time()-started,
        " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    oracle_error=maximum(abs,SparseArrays.nonzeros(base.jacobian-oracle);init=0.0)
    @test oracle_error<=256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(oracle)))
    @test maximum(abs,base.residual[n+1:profile_rows])<=1e-8
    @test maximum(abs,base.residual[1:n])<=1e-11
    println("FREEGS_FULL_PROFILE_ORACLE_SPARSE_COMPARE_END elapsed_s=",time()-oracle_compare_started,
        " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    # Nonzero changing-state response; baseline zero is only the accepted anchor.
    @test component.fixed_PF_currents && !component.zero_anchor_is_physics_acceptance
    @test component.flux_response_node_count==n && component.flux_response_row_count==2n
    @test component.fixed_PF_coil_ids==trace.data.coil_ids
    @test component.fixed_PF_currents_A_per_turn==trace.data.coil_currents_A_per_turn
    spline_setup_started=time()
    println("FREEGS_FULL_PROFILE_SPLINE_SETUP_BEGIN elapsed_s=",time()-started,
        " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    Ra=collect(trace.data.current_support.R_m);Za=collect(trace.data.current_support.Z_m)
    Or=F._ccp_native_spline_derivative_oracle(Ra)
    Oz=F._ccp_native_spline_derivative_oracle(Za)
    @test maximum(abs,F._ccp_native_spline_derivative(Ra)*Ra.-1)<=1e-11
    @test maximum(abs,F._ccp_native_spline_derivative(Za)*(Za.^3).-3 .* Za.^2)<=1e-11
    @test_throws ArgumentError F._ccp_native_spline_derivative(reverse(Ra))
    margin=minimum(min(abs(x[4k]-component.profile_law.psi_axis_wb_per_rad),
        abs(x[4k]-component.profile_law.psi_boundary_wb_per_rad)) for k in core_ids)
    @test margin>0
    max_response_error=0.0
    println("FREEGS_FULL_PROFILE_SPLINE_SETUP_END elapsed_s=",time()-spline_setup_started,
        " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    for mode in (:mixed_cubic,:corner_local,:near_coil_local)
        mode_setup_started=time()
        direction=zeros(nr,nz)
        if mode===:mixed_cubic
            for i in 1:nr,j in 1:nz
                direction[i,j]=Ra[i]^3-0.3Ra[i]*Za[j]+0.5Za[j]^3
            end
        elseif mode===:corner_local
            direction[1,1]=1.0
        else
            # Actual declared in-box PF coordinate, used only to select a node.
            i=argmin(abs.(Ra.-1.75));j=argmin(abs.(Za.-0.6));direction[i,j]=1.0
        end
        direction .*= (0.01margin)/max(1.0,maximum(abs,direction))
        changed=copy(x)
        for i in 1:nr,j in 1:nz
            changed[4*((i-1)*nz+j)]+=direction[i,j]
        end
        println("FREEGS_FULL_PROFILE_SPLINE_MODE_SETUP_END mode=",mode,
            " elapsed_s=",time()-mode_setup_started," gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        eval_started=time()
        println("FREEGS_FULL_PROFILE_SPLINE_EVALUATE_BEGIN mode=",mode,
            " elapsed_s=",time()-started," gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        altered=component.evaluate(changed)
        println("FREEGS_FULL_PROFILE_SPLINE_EVALUATE_END mode=",mode,
            " eval_elapsed_s=",time()-eval_started," elapsed_s=",time()-started,
            " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        actual=altered.residual[profile_rows+1:profile_rows+2n]
        realized=permutedims(reshape(changed[4:4:4n]-x[4:4:4n],nz,nr))
        independent_r=Or*realized;independent_z=realized*transpose(Oz)
        expected=zeros(2n)
        for i in 1:nr,j in 1:nz
            k=(i-1)*nz+j;expected[2k-1]=independent_z[i,j]/Ra[i]
            expected[2k]=-independent_r[i,j]/Ra[i]
        end
        @test maximum(abs,actual)>0
        error=maximum(abs,actual-expected)
        max_response_error=max(max_response_error,error)
        @test error<=256eps(Float64)*max(1.0,maximum(abs,expected))
        # Verify the full sparse map against the independently evaluated response.
        predicted=base.jacobian[profile_rows+1:profile_rows+2n,:]*(changed-x)
        @test maximum(abs,predicted-expected)<=256eps(Float64)*max(1.0,maximum(abs,expected))
        # Drop full evaluate result and loop temporaries before the next full-J call.
        altered=nothing;actual=nothing;expected=nothing;predicted=nothing
        changed=nothing;direction=nothing;realized=nothing;independent_r=nothing;independent_z=nothing
        gc_started=time();GC.gc(true)
        println("FREEGS_FULL_PROFILE_SPLINE_GC_END mode=",mode,
            " gc_elapsed_s=",time()-gc_started," elapsed_s=",time()-started,
            " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    end
    for (node,column,row) in ((1,1,1),(n,4n-1,2n))
        changed=copy(x);changed[column]+=0.01
        evaluate_started=time();evaluate_live_before=Base.gc_live_bytes()
        println("FREEGS_FULL_PROFILE_BOUNDARY_EVALUATE_BEGIN node=",node,
            " gc_live_bytes=",evaluate_live_before);flush(stdout)
        evaluated=component.evaluate(changed)
        println("FREEGS_FULL_PROFILE_BOUNDARY_EVALUATE_END node=",node,
            " elapsed_s=",time()-evaluate_started," gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
        response=evaluated.residual[profile_rows+1:profile_rows+2n]
        @test isapprox(response[row],0.01;rtol=0,atol=1e-12)
        @test count(!iszero,response)==1
        evaluated=nothing;response=nothing;changed=nothing
        release_live_before=Base.gc_live_bytes();release_started=time();GC.gc(true)
        println("FREEGS_FULL_PROFILE_BOUNDARY_RELEASE_END node=",node,
            " reclaimed_bytes=",release_live_before-Base.gc_live_bytes(),
            " elapsed_s=",time()-release_started," gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    end
    summary_serialize_started=time()
    println("FREEGS_NATIVE_SPLINE_RESPONSE_SERIALIZE_BEGIN gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    native_spline_response_json=F.canonical_json((
        source_scope=:fixed_accepted_PF_affine_plasma_spline_response,
        full_native_nodes=n,full_boundary_nodes=length(component.boundary_native_ids),
        flux_rows=2n,total_rows=length(base.residual),dofs=length(x),
        jacobian_nnz=SparseArrays.nnz(base.jacobian),independent_response_max_abs_error=max_response_error,
        fixed_PF_coil_ids=component.fixed_PF_coil_ids,
        fixed_PF_currents_A_per_turn=component.fixed_PF_currents_A_per_turn,
        zero_anchor_is_physics_acceptance=false,all_five_closures_still_missing=true,
        global_topology_closed=false,physical_validation=false))
    println("FREEGS_NATIVE_SPLINE_RESPONSE_JSON="*native_spline_response_json)
    println("FREEGS_NATIVE_SPLINE_RESPONSE_SERIALIZE_END elapsed_s=",time()-summary_serialize_started,
        " payload_bytes=",ncodeunits(native_spline_response_json),
        " gc_live_bytes=",Base.gc_live_bytes());flush(stdout)
    native_spline_response_json=nothing

    # Old accepted artifacts explicitly lack the absolute plasma-flux input.
    @test !component.gs_residual_baseline_subtracted
    @test component.gs_boundary_feedback_executed==(component.gs_status===:present)
    @test component.gs_boundary_feedback_executed==component.hagenow_boundary_feedback_executed
    @test component.row_meanings[end]===:absolute_freeBoundaryHagenow_boundary_trace
    @test component.row_units[end]=="Wb/rad"
    @test component.gs_profile_scope===:fixed_accepted_mask_axis_boundary_and_profile_coefficients
    @test F._ccp_native_gs4_input(nothing,trace.data.current_support).reason===:accepted_native_plasma_flux_not_exported
    if component.gs_status===:typed_absent
        @test component.gs_reason===:accepted_native_plasma_flux_not_exported
        @test component.gs_row_count==0
    else
        @test component.gs_status===:present
        @test component.gs_row_count==(nr-2)*(nz-2)
        @test component.gs_native_ids==[(i-1)*nz+j for i in 2:nr-1 for j in 2:nz-1]
        @test isempty(intersect(component.gs_native_ids,component.boundary_native_ids))
        gs_slice=(profile_rows+2n+1):(profile_rows+2n+component.gs_row_count)
        reference=component.gs_final_profile_reference
        # Source GS4 equations occupy only their declared interior rows; H rows follow separately.
        @test length(gs_slice)==component.gs_row_count
        if component.hagenow_status===:present
            @test component.hagenow_boundary_row_range ==
                (last(gs_slice)+component.normalization_row_count+1):length(base.residual)
        end
        # True absolute source residual remains visible; no zero threshold is imposed.
        @test length(reference)==length(gs_slice)
        @test all(isfinite,base.residual[gs_slice])
        @test all(isfinite,component.gs_retained_current_reference)
        @test isapprox(base.residual[gs_slice],reference;rtol=0,atol=component.gs_source_comparison_roundoff_bound)
        analytic=F._ccp_native_gs4_operator(Ra,Za)
        independent=F._ccp_native_gs4_operator(Ra,Za;independent=true)
        @test maximum(abs,analytic.operator-independent.operator)<=1e-9
        # Polynomial moment holdouts cover both one-sided edge stencils.
        polynomials=([Ra[i]^2 for i in 1:nr for j in 1:nz],
            [Za[j]^2 for i in 1:nr for j in 1:nz])
        @test maximum(abs,analytic.operator*polynomials[1])<=1e-9
        @test maximum(abs,analytic.operator*polynomials[2].-2)<=1e-9
        for node in (first(core_ids),core_ids[cld(length(core_ids),2)],(2-1)*nz+2,nz+cld(nz,2))
            direction=zeros(length(x));direction[4node]=1
            amplitude=0.01margin
            changed=copy(x);changed .+= amplitude.*direction
            actual=component.evaluate(changed)
            derivative=component.jacobian_oracle(changed)
            @test maximum(abs,actual.jacobian-derivative)<=1e-8
            response=actual.residual[gs_slice]-base.residual[gs_slice]
            actual=nothing;derivative=nothing
            @test maximum(abs,response)>0
            # Exact quadratic secant check with the independently computed
            # midpoint derivative, including genuine source-current feedback.
            midpoint=x.+(amplitude/2).*direction
            expected=component.jacobian_oracle(midpoint)[gs_slice,:]*(changed-x)
            @test maximum(abs,response-expected)<=component.gs_source_comparison_roundoff_bound
            response=nothing;expected=nothing;midpoint=nothing;changed=nothing;direction=nothing
        end
        raw_gs=Dict{Symbol,Any}(pairs(parsed_output[:native_gs_state]))
        # Metadata and dimensions are part of the actual discretization, not labels.
        wrong=deepcopy(raw_gs);wrong[:order]=2
        @test_throws ArgumentError F._ccp_native_gs4_input(wrong,trace.data.current_support)
        wrong=deepcopy(raw_gs);wrong[:boundary_method]="fixedBoundary"
        @test_throws ArgumentError F._ccp_native_gs4_input(wrong,trace.data.current_support)
        wrong=copy(raw_gs);wrong[:plasma_psi_wb_per_rad]=collect(raw_gs[:plasma_psi_wb_per_rad])[1:end-1]
        @test_throws ArgumentError F._ccp_native_gs4_input(wrong,trace.data.current_support)
        @test_throws ArgumentError F._ccp_native_gs4_operator(reverse(Ra),Za)
    end
    println("FREEGS_NATIVE_GS4_JSON="*F.canonical_json((status=component.gs_status,
        reason=component.gs_reason,rows=component.gs_row_count,
        source_scope=component.gs_profile_scope,
        final_profile_residual_Linf=component.gs_row_count==0 ? nothing : maximum(abs,base.residual[(profile_rows+2n+1):(profile_rows+2n+component.gs_row_count)]),
        retained_current_residual_Linf=component.gs_row_count==0 ? nothing : maximum(abs,component.gs_retained_current_reference),
        residual_baseline_subtracted=false,boundary_feedback_executed=component.gs_boundary_feedback_executed,
        all_five_closures_still_missing=true,global_topology_closed=false,physical_validation=false)));flush(stdout)

    @test !component.hagenow_absolute_boundary_anchor_subtracted
    if component.hagenow_status===:typed_absent
        @test component.hagenow_reason===component.gs_reason
        @test component.hagenow_boundary_row_count==0
        @test !component.hagenow_boundary_feedback_executed
    else
        @test component.hagenow_status===:present
        @test component.hagenow_boundary_feedback_executed
        @test component.hagenow_boundary_row_count==2nr+2nz-4
        @test component.hagenow_boundary_native_ids==component.boundary_native_ids
        @test component.hagenow_core_native_ids==core_ids
        @test component.hagenow_face_native_ids[1]==[((i-1)*nz+1) for i in 1:nr]
        @test component.hagenow_face_native_ids[2]==[i*nz for i in 1:nr]
        @test component.hagenow_face_native_ids[3]==collect(1:nz)
        @test component.hagenow_face_native_ids[4]==collect((nr-1)*nz+1:nr*nz)
        @test Tuple(component.hagenow_face_normals_RZ)==((0.0,-1.0),(0.0,1.0),(-1.0,0.0),(1.0,0.0))
        @test size(component.hagenow_response_per_Jphi)==(length(component.boundary_native_ids),length(core_ids))
        @test component.hagenow_greens_source_arguments===:face_RZ
        @test component.hagenow_greens_observation_arguments===:shifted_boundary_RZ
        @test component.hagenow_outward_observation_epsilon_m==1e-2
        @test component.hagenow_callSolver_direct_lu && component.hagenow_iterative_tolerance===:not_applicable
        @test isfinite(component.hagenow_adjoint_solve_max_backward_error)
        if artifacts.hagenow_source_response===nothing
            if get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1"
                @test artifacts.hagenow_source_response!==nothing
            end
            @test component.hagenow_source_reference.full_jacobian_status===:not_executed
            @test component.hagenow_full_jacobian_source_validation===:not_executed
        else
            @test component.hagenow_source_reference.full_jacobian_status===:passed
            @test component.hagenow_source_reference.producer_full_jacobian_status===:not_executed
            @test component.hagenow_source_reference.full_jacobian_validation_scope===
                :complete_source_H_and_initial_sparse_H_block_fixed_PF_mask_axis_boundary
            @test component.hagenow_source_reference.full_jacobian_kernel_validation_scope===
                :analytic_reconstructed_H_vs_exported_source_H_entrywise_max_abs_with_2048eps_bound
            @test component.hagenow_full_jacobian_source_validation===:passed
            @test base.hagenow_feedback.full_hagenow_jacobian_source_validation===:passed
            @test isfinite(component.hagenow_full_source_map_error) &&
                component.hagenow_full_source_map_error<=component.hagenow_full_source_map_bound
            @test isfinite(component.hagenow_initial_source_jacobian_error) &&
                component.hagenow_initial_source_jacobian_error<=component.hagenow_initial_source_jacobian_bound
            raw_gs=parsed_output[:native_gs_state]
            @test String(raw_gs[:hagenow_source_feedback][:full_hagenow_jacobian_status])=="not_executed"
        end
        @test component.hagenow_source_directional_validation===:base_plus_full_core_psi_u_v_dJ_directions
        @test base.hagenow_feedback.status===:evaluated_absolute_plasma_psi_minus_freeBoundaryHagenow
        @test !base.hagenow_feedback.absolute_boundary_anchor_subtracted
        @test all(isfinite,base.hagenow_feedback.residual)
        hagenow_rows=component.hagenow_boundary_row_range
        @test length(hagenow_rows)==component.hagenow_boundary_row_count
        @test base.hagenow_feedback.residual==base.residual[hagenow_rows]
        source_bound=component.hagenow_source_comparison_bound
        @test base.hagenow_feedback.source_map_comparison_error<=source_bound
        @test maximum(abs,base.hagenow_feedback.residual-
            base.hagenow_feedback.source_boundary_residual)<=source_bound
        @test base.hagenow_feedback.source_boundary_values==
            component.hagenow_source_reference.final_profile_boundary_values
        @test component.current_conservation_callbacks(nothing).reason===:original_variable_profile_Ip_row_unavailable
        outer_provider=component.outer_callbacks()
        if artifacts.hagenow_source_response!==nothing
            source_response=artifacts.hagenow_source_response
            @test source_response.boundary_native_ids==component.hagenow_boundary_native_ids
            @test source_response.core_native_ids==component.hagenow_core_native_ids
            source_H=source_response.values
            source_plasma_grid=parsed_output[:native_gs_state][:plasma_psi_wb_per_rad]
            source_plasma_boundary=[Float64(source_plasma_grid[cld(k,nz)][mod1(k,nz)])
                for k in component.hagenow_boundary_native_ids]
            source_boundary_ids=component.hagenow_boundary_native_ids
            source_coordinates=component.coordinates_RZ_m
            source_vary_profile_coefficients=component.vary_profile_coefficients
            source_profile_law=component.profile_law
            source_profile_coefficient_columns=component.profile_coefficient_columns
            source_derivative_dJ_dpsi=base.hagenow_feedback.derivative_dJ_dpsi_A_m2_per_Wb_rad
            span=source_profile_law.psi_boundary_wb_per_rad-source_profile_law.psi_axis_wb_per_rad
            parent_source_J_live_before=Base.gc_live_bytes()
            println("G2_PARENT_SOURCE_J_BEGIN gc_live_bytes=",parent_source_J_live_before);flush(stdout)
            parent_source_J_timed=@timed _test_full_native_h_parent_source_jacobian(source_H,
                source_boundary_ids,core_ids,source_derivative_dJ_dpsi,source_coordinates,x,
                source_vary_profile_coefficients,source_profile_law,source_profile_coefficient_columns,
                span,component.hagenow_boundary_row_count,length(x))
            source_jacobian=parent_source_J_timed.value
            parent_source_J_live_after=Base.gc_live_bytes()
            println("G2_PARENT_SOURCE_J_END elapsed_s=",parent_source_J_timed.time,
                " allocated_bytes=",parent_source_J_timed.bytes," gc_seconds=",parent_source_J_timed.gctime,
                " gc_live_delta_bytes=",parent_source_J_live_after-parent_source_J_live_before);flush(stdout)
            source_oracle=oracle[hagenow_rows,:]
            source_defect=SparseArrays.sparse(source_jacobian-source_oracle)
            @test size(source_oracle)==size(source_jacobian)
            @test maximum(abs,SparseArrays.nonzeros(source_defect);init=0.0)<=
                component.hagenow_initial_source_jacobian_bound
            @test outer_provider.status===:prepared_outer_evaluator
            @test outer_provider.hagenow_full_jacobian_source_validation===:passed
            @test outer_provider.source_reference_full_jacobian_status===:passed
            expected_ids=Tuple("$(outer_provider.region_id):freeBoundaryHagenow:node_$(k)" for k in
                component.hagenow_boundary_native_ids)
            @test outer_provider.constraint_ids==expected_ids
            @test length(outer_provider.constraint_ids)==512
            @test outer_provider.region_dofs==length(x)
            @test outer_provider.outer_row_indices==hagenow_rows
            @test outer_provider.regional_row_indices==(first(hagenow_rows)-1==0 ? (1:0) : 1:(first(hagenow_rows)-1))
            @test isempty(intersect(outer_provider.regional_row_indices,outer_provider.outer_row_indices))
            @test sort(vcat(collect(outer_provider.regional_row_indices),collect(outer_provider.outer_row_indices)))==
                collect(eachindex(base.residual))
            @test outer_provider.trace_equation_count==0
            @test sum(length(face.native_ids) for face in outer)==2nr+2nz==516
            @test outer_provider.missing_closures==component.missing_closures==
                F._CCP_AXISYMMETRIC_MISSING_CLOSURES
            @test !outer_provider.global_topology_closed && !outer_provider.closure_evidence_created
            bindings=_full_native_h_outer_test_context(F,component,trace,outer_provider)
            @test all(isnothing,values(bindings.closures))
            _test_full_native_h_outer_state(F,component,outer_provider,bindings.closures,
                bindings.context,x,source_H,source_plasma_boundary;expected_residual=base.hagenow_feedback.residual,
                expected_jacobian=base.jacobian[hagenow_rows,:])
            attached_outer=outer_provider.outer_evaluator(outer_provider.region_id,x,
                bindings.closures,bindings.context)
            if component.g2_outer_face_map===nothing
                @test !hasproperty(attached_outer,:g2_outer_face_trace)
            else
                @test attached_outer.g2_outer_face_trace.status===:evaluated_candidate_bound_g2_outer_face_trace
                @test attached_outer.g2_outer_face_trace.map_hash==string(component.g2_outer_face_map.map_hash)
                @test length(attached_outer.constraint_ids)==512
                # The real outer provider carries changing trial J while retaining its H512 rows.
                box_trial=copy(x)
                for (k,(r,z)) in enumerate(component.coordinates_RZ_m)
                    box_trial[4k-2]+=(0.002+0.003r+0.004z+0.001r*z)/r
                end
                attached_trial=outer_provider.outer_evaluator(outer_provider.region_id,box_trial,
                    bindings.closures,bindings.context)
                direct_trial=component.g2_outer_face_trace(box_trial)
                @test attached_trial.constraint_ids==attached_outer.constraint_ids
                @test attached_trial.residual==attached_outer.residual
                @test attached_trial.jacobian==attached_outer.jacobian
                @test attached_trial.g2_outer_face_trace.trial_current_RZ_A_m2==direct_trial.trial_current_RZ_A_m2
                @test attached_trial.g2_outer_face_trace.trial_current_RZ_jacobian==direct_trial.trial_current_RZ_jacobian
                @test attached_trial.g2_outer_face_trace.trial_normal_J_A_m2==direct_trial.trial_normal_J_A_m2
                @test attached_trial.g2_outer_face_trace.trial_normal_J_jacobian==direct_trial.trial_normal_J_jacobian
                @test attached_trial.g2_outer_face_trace.full_J_normal_trace===:typed_absent
                @test maximum(abs,attached_outer.residual-base.hagenow_feedback.residual;init=0.0)<=
                    component.hagenow_source_comparison_bound
                @test maximum(abs,SparseArrays.nonzeros(SparseArrays.sparse(
                    attached_outer.jacobian-base.jacobian[hagenow_rows,:]));init=0.0)<=
                    component.hagenow_initial_source_jacobian_bound
            end
            wrong_candidate=merge(bindings.context,(candidate_hash=
                bindings.context.candidate_hash==repeat("0",64) ? repeat("1",64) : repeat("0",64),))
            @test_throws ArgumentError outer_provider.outer_evaluator(outer_provider.region_id,x,
                bindings.closures,wrong_candidate)
            @test_throws ArgumentError outer_provider.outer_evaluator(outer_provider.region_id*"_foreign",
                x,bindings.closures,bindings.context)
            @test_throws ArgumentError outer_provider.jacobian_oracle(:regional,outer_provider.region_id,
                x,bindings.closures,bindings.context)
            @test_throws ArgumentError outer_provider.outer_evaluator(outer_provider.region_id,x[1:end-1],
                bindings.closures,bindings.context)
            wrong_order_record=(candidate_hash=bindings.context.candidate_hash,
                provider_semantic_hash=bindings.context.provider_semantic_hash,
                provider_context_hash=bindings.context.provider_context_hash,
                region_id=outer_provider.region_id,constraint_ids=reverse(collect(outer_provider.constraint_ids)))
            @test_throws ArgumentError F.InHouseCoupledMHDGlobalSolveV1._check_provider_record(
                wrong_order_record,bindings.validator,expected_ids,outer_provider.region_id,
                "reordered full-native H outer",:constraint_ids)
        else
            @test outer_provider.status===:typed_absent
            @test !hasproperty(outer_provider,:outer_evaluator) && !hasproperty(outer_provider,:jacobian_oracle)
        end
        no_source_outer=F._ccp_full_native_outer_callbacks(nothing,component.candidate_hash,
            component.upstream_output_hash,:not_executed,:not_executed,first(hagenow_rows))
        @test no_source_outer.status===:typed_absent
        @test no_source_outer.reason===:freeBoundaryHagenow_boundary_rows_unavailable
        @test no_source_outer.missing_closures==component.missing_closures
        @test !hasproperty(no_source_outer,:outer_evaluator) && !hasproperty(no_source_outer,:jacobian_oracle)
        source_jacobian=nothing;source_oracle=nothing;source_defect=nothing
        source_rows=nothing;source_cols=nothing;source_values=nothing
        GC.gc(false)
        psi_direction=zeros(length(x));psi_direction[4 .* core_ids].=1.0
        source_psi=-component.hagenow_source_reference.psi_direction_boundary_values
        assembled_psi=base.jacobian[hagenow_rows,:]*psi_direction
        psi_bound=2048eps(Float64)*max(1.0,maximum(abs,source_psi),maximum(abs,assembled_psi))
        @test maximum(abs,assembled_psi-source_psi)<=psi_bound
        if component.vary_profile_coefficients
            ucol,vcol=component.profile_coefficient_columns
            for (column,source_direction) in ((ucol,component.hagenow_source_reference.u_direction_boundary_values),
                                               (vcol,component.hagenow_source_reference.v_direction_boundary_values))
                expected=-source_direction
                assembled=base.jacobian[hagenow_rows,column]
                direction_bound=2048eps(Float64)*max(1.0,maximum(abs,expected),maximum(abs,assembled))
                @test maximum(abs,assembled-expected)<=direction_bound
            end
        end
        core_mid=first(k for k in core_ids if 0.2<(x[4k]-component.profile_law.psi_axis_wb_per_rad)/
            (component.profile_law.psi_boundary_wb_per_rad-component.profile_law.psi_axis_wb_per_rad)<0.8)
        changed=copy(x);changed[4core_mid]+=0.01margin;midpoint=(x.+changed)./2
        actual=_g2_a3_timed_call("changed_state_component_evaluate",
            ()->component.evaluate(changed)).residual[hagenow_rows]-base.residual[hagenow_rows]
        if artifacts.hagenow_source_response!==nothing
            adapter_residual=_g2_a3_timed_call("changed_state_full_native_outer_helper",
                ()->_test_full_native_h_outer_state(F,component,outer_provider,bindings.closures,
                    bindings.context,changed,source_H,source_plasma_boundary))
            @test maximum(abs,adapter_residual-(base.hagenow_feedback.residual+actual);init=0.0)<=source_bound
        end
        predicted=_g2_a3_timed_call("changed_state_midpoint_jacobian_oracle",
            ()->component.jacobian_oracle(midpoint)[hagenow_rows,:]*(changed-x))
        @test maximum(abs,actual-predicted)<=256eps(Float64)*max(1.0,maximum(abs,actual))
        edge=first(component.hagenow_boundary_native_ids)
        edge_row=findfirst(==(edge),component.hagenow_boundary_native_ids)
        edge_changed=copy(x);edge_changed[4edge]+=1e-6
        edge_delta=_g2_a3_timed_call("boundary_node_component_evaluate",
            ()->component.evaluate(edge_changed)).residual[hagenow_rows]-base.residual[hagenow_rows]
        edge_increment=edge_changed[4edge]-x[4edge]
        edge_expected=zeros(length(edge_delta));edge_expected[edge_row]=edge_increment
        @test maximum(abs,edge_delta-edge_expected)<=256eps(Float64)*max(1.0,maximum(abs,edge_delta))
    end

    law=component.profile_law;span=law.psi_boundary_wb_per_rad-law.psi_axis_wb_per_rad
    core=first(k for k in core_ids if 0.2<(x[4k]-law.psi_axis_wb_per_rad)/span<0.8)
    outside=first(component.boundary_native_ids)
    for (node,field,step) in ((core,:p,1.0),(core,:Bphi,1e-4),(core,:psi,1e-5*span),
                             (outside,:Bphi,1e-4))
        column=field===:p ? component.pressure_dofs[node] : field===:Bphi ? 4node-2 : 4node
        changed=copy(x);changed[column]+=step
        altered=_g2_a3_timed_call("profile_perturb_component_evaluate_$(field)_$(node)",
            ()->component.evaluate(changed))
        @test altered.residual!=base.residual
        @test all(k->k in (node,component.pressure_rows[node]),findall(!iszero,altered.residual[1:profile_rows]-base.residual[1:profile_rows]))
        if field===:psi
            @test altered.jacobian!=base.jacobian
            changed_oracle=_g2_a3_timed_call("profile_perturb_jacobian_oracle_$(field)_$(node)",
                ()->component.jacobian_oracle(changed))
            @test maximum(abs,SparseArrays.nonzeros(altered.jacobian-changed_oracle);init=0.0)<=
                256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(changed_oracle)))
        else
            row=field===:p ? component.pressure_rows[node] : node
            @test isapprox(altered.residual[row]-base.residual[row],
                step*(field===:p ? 1.0 : component.coordinates_RZ_m[node][1]);rtol=0,atol=1e-10)
        end
    end
    # Exact LCFS endpoint compatibility is not a nodal mask-cut continuity proof.
    endpoint=F._ccp_full_profile_node(0.0,law.fvac_T_m/1.3,
        law.psi_boundary_wb_per_rad,1.3,true,law)
    @test maximum(abs,endpoint)<=16eps(Float64)*max(1.0,law.fvac_T_m)
    @test length(component.mask_cut_native_pairs)==270
    expected_cuts=Set{Tuple{Int,Int}}()
    accepted_mask=trace.data.current_support.core_mask
    for i in 1:nr,j in 1:nz
        id=(i-1)*nz+j
        i<nr && accepted_mask[i][j]!=accepted_mask[i+1][j] && push!(expected_cuts,(id,id+nz))
        j<nz && accepted_mask[i][j]!=accepted_mask[i][j+1] && push!(expected_cuts,(id,id+1))
    end
    @test length(expected_cuts)==270 && Set(component.mask_cut_native_pairs)==expected_cuts
    @test all(pair->component.core_mask[pair[1]]!=component.core_mask[pair[2]],component.mask_cut_native_pairs)
    cut_F_jump=maximum(abs(component.coordinates_RZ_m[a][1]*x[4a-2]-
        component.coordinates_RZ_m[b][1]*x[4b-2]) for (a,b) in component.mask_cut_native_pairs)
    @test cut_F_jump>0
    @test component.frozen_mask_interface_continuity===:unverified
    @test component.exterior_pressure_status===:typed_absent
    faces=_g2_a3_timed_call("boundary_trace_for_candidate_map_test",
        ()->component.boundary_trace(x))
    @test _g2_a3_timed_call("candidate_bound_g2_outer_face_map_helper",
        ()->_test_candidate_bound_g2_outer_face_map(F,component,context,trace,region,x,faces)) in
        (:typed_absent,:evaluated_candidate_bound_g2_outer_face_trace)
    @test Tuple(f.normal_RZ for f in faces)==((-1.0,0.0),(1.0,0.0),(0.0,-1.0),(0.0,1.0))
    @test length(unique(vcat([f.native_ids for f in faces]...)))==length(component.boundary_native_ids)
    @test sum(length(f.native_ids) for f in faces)==2nr+2nz
    @test all(f->all(q->f.normal_B_T[q]==f.normal_RZ[1]*f.B_cylindrical_T[q][1]+
        f.normal_RZ[2]*f.B_cylindrical_T[q][3],eachindex(f.native_ids)),faces)
    @test all(f->f.sheet_current_law===:typed_absent && f.current_normal_trace===:typed_absent,faces)
    @test all(f->f.pressure_status===:typed_absent && all(isnothing,f.p_Pa),faces)
    # Actual total exported Br/Bz are retained on every boundary face.
    @test all(f->all(q->begin
        sample=artifacts.field_samples_rz_m[f.native_ids[q]]
        f.B_cylindrical_T[q][1]==sample.Br_T && f.B_cylindrical_T[q][3]==sample.Bz_T
    end,eachindex(f.native_ids)),faces)
    @test outside==faces[1].native_ids[1]
    changed=copy(x);changed[4outside]+=0.01
    moved=_g2_a3_timed_call("changed_state_boundary_trace",
        ()->component.boundary_trace(changed))
    expected_normal_delta=faces[1].normal_RZ[1]*(-0.01*Oz[1,1]/Ra[1])
    @test expected_normal_delta!=0
    @test moved[1].normal_B_T[1]-faces[1].normal_B_T[1]≈expected_normal_delta
    bad=copy(x);bad[4core-2]=-bad[4core-2]
    @test_throws ArgumentError _g2_a3_timed_call("invalid_state_component_evaluate",
        ()->component.evaluate(bad))
    badpsi=copy(x);badpsi[4core]=law.psi_axis_wb_per_rad-span
    @test_throws DomainError _g2_a3_timed_call("invalid_psi_component_evaluate",
        ()->component.evaluate(badpsi))
    foreign=(candidate_hash=repeat("0",64),context_hash=context.context_hash)
    @test_throws ArgumentError F.freegs_axisymmetric_full_support_profile_callbacks(foreign,artifacts,trace)
    tampered=F.FreeGSAxisymmetricExecutionArtifactsV4(artifacts.receipt,artifacts.input_json,
        artifacts.output_json*" ",artifacts.field_samples_rz_m)
    @test_throws ArgumentError F.freegs_axisymmetric_full_support_profile_callbacks(context,tampered,trace)
    missing=F.FreeGSAxisymmetricLCFSTraceV4(F._CCP_LCFS_TRACE_TOKEN,
        merge(trace.data,(current_support=(status=:typed_absent,),)),trace.source_hash,trace.trace_hash)
    @test_throws ArgumentError F.freegs_axisymmetric_full_support_profile_callbacks(context,artifacts,missing)
    println("FREEGS_FULL_NATIVE_PROFILE_COMPONENT_JSON="*F.canonical_json((
        candidate_hash=component.candidate_hash,upstream_output_hash=component.upstream_output_hash,
        node_count=n,dof_count=length(x),row_count=length(base.residual),jacobian_nnz=SparseArrays.nnz(base.jacobian),
        core_count=length(core_ids),previously_unmapped_core_ids=Tuple(tails),
        boundary_unique_nodes=length(component.boundary_native_ids),face_incidences=2nr+2nz,
        hagenow_status=component.hagenow_status,
        hagenow_source_comparison_error=component.hagenow_source_comparison_error,
        hagenow_source_comparison_bound=component.hagenow_source_comparison_bound,
        hagenow_source_reference=component.hagenow_source_reference,
        hagenow_directional_validation=component.hagenow_source_directional_validation,
        hagenow_full_jacobian_source_validation=component.hagenow_full_jacobian_source_validation,
        hagenow_absolute_source_residual=base.hagenow_feedback.source_boundary_residual,
        pressure_residual_max_Pa=maximum(abs,base.residual[n+1:profile_rows]),
        F_residual_max_T_m=maximum(abs,base.residual[1:n]),oracle_max_abs_error=oracle_error,
        raw_exterior_constitutive_reclassified=false,derived_exterior_branch=component.exterior_branch,
        exterior_pressure_status=:typed_absent,mask_cut_count=length(component.mask_cut_native_pairs),
        largest_adjacent_cut_F_difference_T_m=cut_F_jump,frozen_mask_interface_continuity=:unverified,
        executed_exterior_TF_node_count=length(exterior),raw_domain_boundary_absence_count=512,
        missing_closures=component.missing_closures,global_topology_closed=false,
        computational_outer_K=:typed_absent,full_current_conservation=:typed_absent,
        physical_validation=false,coupled_solve_attempted=false)))
    println("FREEGS_FULL_PROFILE_END elapsed_s=",time()-started);flush(stdout)
    Base.invokelatest(test_actual_freegs_core_current_trace,F,component,trace,region)
    Base.invokelatest(test_actual_freegs_LCFS_flux_map,F,component,trace,region)
    # Preserve actual fixed-mode metadata/output comparisons without carrying
    # the callback closures and their sparse Ref caches into the next phase.
    fixed_summary=(status=component.status,initial_state=component.initial_state,
        vary_profile_coefficients=component.vary_profile_coefficients,
        normalization_row_count=component.normalization_row_count,
        pressure_dofs=component.pressure_dofs,core_mask=component.core_mask,
        raw_constitutive_status=component.raw_constitutive_status,
        raw_constitutive_reason=component.raw_constitutive_reason,
        missing_closures=component.missing_closures,
        gs_status=component.gs_status,gs_reason=component.gs_reason,
        hagenow_status=component.hagenow_status,hagenow_reason=component.hagenow_reason,
        hagenow_boundary_row_count=component.hagenow_boundary_row_count,
        hagenow_boundary_native_ids=component.hagenow_boundary_native_ids,
        hagenow_core_native_ids=component.hagenow_core_native_ids,
        hagenow_face_native_ids=component.hagenow_face_native_ids,
        hagenow_face_normals_RZ=component.hagenow_face_normals_RZ,
        hagenow_response_per_Jphi=component.hagenow_response_per_Jphi)
    component=nothing
    oracle=nothing
    GC.gc(false)
    return Ref{NamedTuple}((fixed=fixed_summary,base=base,
        holdout_node=best.node,holdout_delta=delta,holdout_sample=best.a))
end

Base.@noinline function _g2_actual_pressure_dof_map_matches_v1(component)
    Base.@nospecialize component
    n=prod(component.grid_shape)
    length(component.pressure_dofs)==n==16_641 && length(component.core_mask)==n || return false
    core_ids=findall(component.core_mask)
    length(core_ids)==2_879 || return false
    all(k->(component.pressure_dofs[k]>0)==component.core_mask[k],eachindex(component.pressure_dofs)) || return false
    Tuple(component.pressure_dofs[core_ids])==Tuple(4*n+i for i in eachindex(core_ids))
end

Base.@noinline Base.@nospecializeinfer function _g2_saved_step_dynamic_geometry_probe_v1(F,component,trace;alpha_probe_mode=false)
    Base.@nospecialize F component trace
    get(ENV,"FUSION_G2_PRECHECK_MODE","")=="global_diagnostic" &&
        get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1" &&
        get(ENV,"FUSION_FREEGS_DYNAMIC_PROFILE_SPAN","0")=="1" ||
        error("saved-step geometry probe requires the original global diagnostic dynamic-span mode")
    component.status===:prepared_full_native_profile_component && component.dynamic_profile_span &&
        component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1 &&
        length(component.initial_state)==69_447 || error("live selected component identity/state differs")
    run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
    !isempty(run_leaf)&&isdir(run_leaf) || error("geometry probe requires an existing bounded run leaf")
    stepdir=get(ENV,"FUSION_G2_SAVED_STEP_RESULT_DATA_DIR","")
    isdir(stepdir) || error("geometry probe saved KKT result_data directory is absent")
    corepath=joinpath(stepdir,"gs_inverse_full_kkt_core_result_v1.jls")
    bundlepath=joinpath(stepdir,"gs_inverse_full_kkt_numeric_step_v1.jls")
    candpath=joinpath(stepdir,"gs_inverse_full_kkt_candidate_v1.jls")
    all(isfile,(corepath,bundlepath,candpath)) || error("geometry probe requires all pinned saved-step files")
    core=open(Serialization.deserialize,corepath,"r")
    bundle=open(Serialization.deserialize,bundlepath,"r")
    candidate=open(Serialization.deserialize,candpath,"r")
    core.schema===:actual_R4_exact_row_pivot_full_kkt_core_result_v1 &&
        bundle.schema===:actual_R4_exact_row_pivot_numeric_step_v1 &&
        candidate.schema===:actual_R4_exact_row_pivot_full_kkt_candidate_v1 ||
        error("geometry probe saved-step schemas differ")
    capture="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec"
    core.capture_sha256==bundle.capture_sha256==capture ||
        error("geometry probe step is not bound to the qualified R4 numeric capture")
    bundle.coordinates===:physical_state_coordinates &&
        candidate.step_coordinates===:physical_state_coordinates ||
        error("geometry probe saved step coordinate semantics differ")
    candidate.core_result_sha256==_g2_global_diag_result_file_sha256(corepath) ||
        error("geometry probe saved candidate/core digest mismatch")
    actual=core.result
    step=Float64.(collect(bundle.step))
    length(step)==69_447 && all(isfinite,step) || error("geometry probe saved step vector is invalid")
    state=Float64.(collect(actual.state_before))
    length(state)==69_447 && all(isfinite,state) || error("geometry probe saved KKT state is invalid")
    expected_state=copy(component.initial_state)
    pressure_dof=first(i for i in component.pressure_dofs if i>0)
    expected_state[pressure_dof]+=1.0
    law=component.profile_law
    core_psi_node=first(k for k in eachindex(component.core_mask) if component.core_mask[k] &&
        0.3<(component.initial_state[4k]-law.psi_boundary_wb_per_rad)/
            (law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)<0.7)
    expected_state[4core_psi_node]+=1e-4*(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)
    axis_column,boundary_column=component.profile_span_columns
    endpoint_delta=1e-8*abs(component.initial_state[axis_column]-component.initial_state[boundary_column])
    expected_state[axis_column]+=endpoint_delta;expected_state[boundary_column]-=endpoint_delta
    state==expected_state || error("saved KKT state differs from the exact captured nonlinear changed_state")
    expected_state=nothing
    qualified_path=normpath(joinpath(@__DIR__,"..","runs","e",
        "up2_continuous_psi_global_numeric_capture_20261012_r4","preoracle_checkpoint",
        "result_data","g2_global_diagnostic","numeric_matrices_v3.jls"))
    qualified=_g2_global_diag_reload_matrices(qualified_path;expected_sha256=capture)
    qm=qualified.replay_metadata;qi=qm.consumer_identity
    qm.validation_stage===:pre_global_assembler_oracles_pending &&
        qi.scope===:diagnostic_incomplete_global_assembly && qualified.state==state &&
        qi.candidate_hash==component.candidate_hash && qi.trace_hash==trace.trace_hash &&
        qi.current_operator_model_id===component.current_operator_model_id &&
        qi.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id &&
        qi.component_context_hash==component.context_hash ||
        error("saved changed_state/live component/R4 numeric capture binding differs")
    qualified=nothing;qm=nothing;qi=nothing;GC.gc(true)
    step_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,step)))
    state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,state)))
    bundle.step_sha256==candidate.step_sha256==step_sha &&
        bundle.state_sha256==candidate.state_sha256==state_sha &&
        actual.status===:ok && actual.step==step || error("geometry probe state/step binding differs")
    actual.full_global_kkt===false && actual.rank_certificate===:not_established_for_full_G &&
        actual.original_kkt_gate===true && actual.true_kkt_gate===true &&
        actual.pressure_bound_gate===true && actual.dual_gate===true ||
        error("geometry probe saved KKT diagnostic gates/claim ceiling differ")
    identity=(schema="saved-step-dynamic-geometry-probe-identity-v1",
        candidate_hash=component.candidate_hash,component_context_hash=component.context_hash,
        trace_hash=trace.trace_hash,current_operator_model_id=component.current_operator_model_id,
        hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
        field_model_id=component.native_field_model_id,capture_sha256=capture,
        step_sha256=step_sha,state_sha256=state_sha,
        qualified_capture_path="runs/e/up2_continuous_psi_global_numeric_capture_20261012_r4/preoracle_checkpoint/result_data/g2_global_diagnostic/numeric_matrices_v3.jls",
        formal_acceptance=false,
        physical_validation=false,science_credit=false)
    output=joinpath(run_leaf,"result_data","g2_global_diagnostic");mkpath(output)
    reportpath=joinpath(output,"saved_step_dynamic_geometry_probe_report_v1.jls")
    ispath(reportpath) && error("geometry probe report already exists")
    records=NamedTuple[]
    component_initial_signature=nothing;saved_kkt_state_signature=nothing
    prior_geometry_binding=nothing
    if alpha_probe_mode
        prior_dir=get(ENV,"FUSION_G2_SAVED_GEOMETRY_ALPHA_PROBE_INPUT_DIR","")
        isdir(prior_dir) || error("alpha probe requires completed geometry-only R1 results")
        prior_raw=joinpath(prior_dir,"result_data","g2_global_diagnostic")
        baseline_path=joinpath(prior_raw,"saved_step_dynamic_geometry_saved_kkt_baseline_raw_v1.jls")
        failed_path=joinpath(prior_raw,"saved_step_dynamic_geometry_trial_3_raw_v1.jls")
        isfile(baseline_path)&&isfile(failed_path) || error("pinned R1 geometry raw inputs are absent")
        baseline_sha="6a859507f4df13e99a9c1a5b349ac4d4f95e92de7b30caca9919a55c00bfff13"
        failed_sha="8b027b872b90b0477c98a78df44b10b398406a9d78e45387c34a9a6a0f9b2554"
        _g2_global_diag_result_file_sha256(baseline_path)==baseline_sha || error("R1 changed-state baseline raw digest differs")
        _g2_global_diag_result_file_sha256(failed_path)==failed_sha || error("R1 alpha=1/8 failure raw digest differs")
        baseline_raw=open(Serialization.deserialize,baseline_path,"r")
        failed_raw=open(Serialization.deserialize,failed_path,"r")
        baseline_raw.schema=="saved-step-dynamic-geometry-raw-v1" && failed_raw.schema==baseline_raw.schema ||
            error("R1 geometry raw schemas differ")
        baseline_raw.state_sha256==state_sha && baseline_raw.state==state &&
            baseline_raw.geometry_result.status===:evaluated_dynamic_LCFS_geometry &&
            baseline_raw.geometry_result.mask_event===:unchanged ||
            error("R1 saved changed-state baseline is not this exact bound state/geometry")
        failed_raw.alpha==0.125 && failed_raw.state==Float64.(state).+0.125.*step &&
            failed_raw.geometry_result.status===:needs_rebuild &&
            failed_raw.geometry_result.reason===:candidate_core_mask_changed ||
            error("R1 alpha=1/8 raw is not the observed mask-change result for this exact direction")
        for prior_identity in (baseline_raw.source_identity,failed_raw.source_identity)
            for key in (:candidate_hash,:component_context_hash,:trace_hash,:current_operator_model_id,
                    :hagenow_source_operator_model_id,:field_model_id,:capture_sha256,:step_sha256,:state_sha256)
                isequal(getproperty(prior_identity,key),getproperty(identity,key)) ||
                    error("R1 geometry identity differs at $(key)")
            end
        end
        changed_ids=Tuple(failed_raw.geometry_result.changed_native_ids)
        !isempty(changed_ids) || error("R1 alpha=1/8 raw has no changed native IDs")
        component_initial_signature=nothing
        saved_kkt_state_signature=baseline_raw.geometry_result.first_outward_crossing_signature
        prior_geometry_binding=(baseline_raw_path=baseline_path,baseline_raw_sha256=baseline_sha,
            failed_raw_path=failed_path,failed_raw_sha256=failed_sha,changed_native_ids=changed_ids,
            changed_native_count=length(changed_ids),baseline_signature=saved_kkt_state_signature)
        alphas=ntuple(i->2.0^(-(i+3)),9)
        cases=Tuple((trial_index=i-1,alpha=alphas[i],state_source=:saved_kkt_changed_state) for i in 1:9)
        open(joinpath(output,"saved_step_dynamic_geometry_alpha_probe_inputs_v1.jls"),"w") do io
            Serialization.serialize(io,(schema="saved-step-dynamic-geometry-alpha-probe-inputs-v1",
                source_identity=identity,prior_geometry_binding=prior_geometry_binding,
                alpha_candidates=alphas));flush(io)
        end
        baseline_raw=nothing;failed_raw=nothing;GC.gc(true)
        println("G2_SAVED_STEP_DYNAMIC_GEOMETRY_ALPHA_PROBE_BEGIN alphas=",alphas,
            " changed_native_count=",prior_geometry_binding.changed_native_count,
            " reused_R1_raw=true");flush(stdout)
    else
        cases=((trial_index=-2,alpha=0.0,state_source=:component_initial),
            (trial_index=-1,alpha=0.0,state_source=:saved_kkt_changed_state),
            (trial_index=0,alpha=1.0,state_source=:saved_kkt_changed_state),
            (trial_index=1,alpha=0.5,state_source=:saved_kkt_changed_state),
            (trial_index=2,alpha=0.25,state_source=:saved_kkt_changed_state),
            (trial_index=3,alpha=0.125,state_source=:saved_kkt_changed_state))
    end
    for case in cases
        trial_state=case.state_source===:component_initial ? Float64.(component.initial_state) :
            Float64.(state).+case.alpha.*Float64.(step)
        println("G2_SAVED_STEP_DYNAMIC_GEOMETRY_BEGIN trial_index=",case.trial_index,
            " alpha=",case.alpha," state_source=",case.state_source);flush(stdout)
        finite=all(isfinite,trial_state)
        pressure_indices=Tuple(i for i in component.pressure_dofs if i>0)
        bphi_indices=Tuple(4k-2 for k in eachindex(component.core_mask))
        preguard=finite && all(i->trial_state[i]>=0.0,pressure_indices) &&
            all(i->trial_state[i]>0.0,bphi_indices)
        state_hash=bytes2hex(SHA.sha256(reinterpret(UInt8,trial_state)))
        geometry_record=if preguard
            try
                Base.invokelatest(component.lcfs_dynamic_geometry_trace,trial_state)
            catch err
                message=sprint(showerror,err)
                ncodeunits(message)>4096 && (message=first(message,4096))
                (call_status=err isa DomainError ? :domain_error : :exception,
                    error_type=String(nameof(typeof(err))),error_message=message)
            end
        else
            (call_status=:pre_geometry_state_guard_failed,)
        end
        suffix=case.trial_index==-2 ? "component_initial_baseline" :
            case.trial_index==-1 ? "saved_kkt_baseline" : "trial_$(case.trial_index)"
        rawpath=joinpath(output,"saved_step_dynamic_geometry_$(suffix)_raw_v1.jls")
        ispath(rawpath) && error("geometry raw output already exists")
        open(rawpath,"w") do io
            Serialization.serialize(io,(schema="saved-step-dynamic-geometry-raw-v1",
                source_identity=identity,trial_index=case.trial_index,alpha=case.alpha,
                state_sha256=state_hash,state=trial_state,pre_geometry_state_guard_passed=preguard,
                geometry_result=geometry_record))
            flush(io)
        end
        raw_bytes=filesize(rawpath);raw_sha=_g2_global_diag_result_file_sha256(rawpath)
        hasgeo=hasproperty(geometry_record,:status)
        getgeo(k,default=nothing)=hasproperty(geometry_record,k) ? getproperty(geometry_record,k) : default
        signature=getgeo(:first_outward_crossing_signature,nothing)
        case.state_source===:component_initial && (component_initial_signature=signature)
        case.state_source===:saved_kkt_changed_state && case.trial_index==-1 &&
            (saved_kkt_state_signature=signature)
        summary=(trial_index=case.trial_index,alpha=case.alpha,state_source=case.state_source,state_sha256=state_hash,
            pre_geometry_state_guard_passed=preguard,call_status=hasgeo ? :returned :
                getgeo(:call_status,:unknown),status=getgeo(:status,nothing),reason=getgeo(:reason,nothing),
            ray=getgeo(:ray,nothing),mask_event=getgeo(:mask_event,nothing),
            global_topology_closed=getgeo(:global_topology_closed,nothing),
            has_endpoint_definition_residual=hasproperty(geometry_record,:endpoint_definition_residual),
            endpoint_definition_residual=getgeo(:endpoint_definition_residual,nothing),
            has_psi_axis=hasproperty(geometry_record,:psi_axis_Wb_per_rad),
            psi_axis_Wb_per_rad=getgeo(:psi_axis_Wb_per_rad,nothing),
            has_psi_boundary=hasproperty(geometry_record,:psi_boundary_Wb_per_rad),
            psi_boundary_Wb_per_rad=getgeo(:psi_boundary_Wb_per_rad,nothing),
            changed_native_ids=getgeo(:changed_native_ids,nothing),
            changed_native_count=hasproperty(geometry_record,:changed_native_ids) ? length(geometry_record.changed_native_ids) : 0,
            first_outward_crossing_signature=signature,
            signature_matches_component_initial=(component_initial_signature===nothing || signature===nothing ?
                nothing : isequal(signature,component_initial_signature)),
            signature_matches_saved_kkt_state=(saved_kkt_state_signature===nothing || signature===nothing ?
                nothing : isequal(signature,saved_kkt_state_signature)),
            raw_path=rawpath,raw_bytes=raw_bytes,raw_sha256=raw_sha)
        open(joinpath(output,"saved_step_dynamic_geometry_$(suffix)_summary_v1.jls"),"w") do io
            Serialization.serialize(io,summary);flush(io)
        end
        push!(records,summary)
        println("G2_SAVED_STEP_DYNAMIC_GEOMETRY_RECORD trial_index=",case.trial_index,
            " alpha=",case.alpha," state_source=",case.state_source," preguard=",preguard," call_status=",summary.call_status,
            " geometry_status=",summary.status," reason=",summary.reason,
            " mask_event=",summary.mask_event," endpoint_residual_present=",
            summary.has_endpoint_definition_residual," raw_bytes=",raw_bytes," raw_sha256=",raw_sha);flush(stdout)
        geometry_record=nothing;trial_state=nothing;GC.gc(true)
        valid_geometry=summary.status===:evaluated_dynamic_LCFS_geometry &&
            summary.mask_event===:unchanged && summary.has_endpoint_definition_residual &&
            summary.has_psi_axis && summary.has_psi_boundary
        alpha_probe_mode && valid_geometry && break
    end
    report=(schema="saved-step-dynamic-geometry-probe-report-v1",source_identity=identity,
        mode=alpha_probe_mode ? :smaller_positive_dyadic_alphas : :original_alphas,
        prior_geometry_binding=prior_geometry_binding,
        trial_step_sha256=step_sha,saved_kkt_state_sha256=state_sha,
        component_initial_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(component.initial_state)))),
        records=Tuple(records),component_initial_signature=component_initial_signature,
        saved_kkt_state_signature=saved_kkt_state_signature,baseline_reassembly=false,plus_reassembly=false,
        minus_reassembly=false,kkt_rerun=false,assembly=false,formal_acceptance=false,
        physical_validation=false,science_credit=false)
    open(reportpath,"w") do io;Serialization.serialize(io,report);flush(io);end
    unexpected=Tuple(r.trial_index for r in records if r.call_status===:exception)
    isempty(unexpected) || error("unexpected geometry exceptions saved to $(reportpath) for trial indices $(unexpected)")
    println("G2_SAVED_STEP_DYNAMIC_GEOMETRY_PROBE_COMPLETE report_path=",reportpath,
        " saved_geometries=",length(records)," assembly=false kkt_rerun=false formal_acceptance=false");flush(stdout)
    (status=:raw_geometry_saved,report_path=reportpath,records=Tuple(records))
end

Base.@noinline Base.@nospecializeinfer function _g2_saved_followup_bphi_action_consumer_v1(
        S,F,component,trace,provider,composed,regional,diagnostic_model,scale_contract,
        numeric_result_run_leaf,endpoint_rows,endpoint_ids,diagnostic)
    Base.@nospecialize S F component trace provider composed regional diagnostic_model scale_contract
    Base.@nospecialize numeric_result_run_leaf endpoint_rows endpoint_ids diagnostic
    action_path=get(ENV,"FUSION_G2_FOLLOWUP_BPHI_ACTION_RAW_PATH","")
    action_sha=lowercase(get(ENV,"FUSION_G2_FOLLOWUP_BPHI_ACTION_RAW_SHA256",""))
    baseline_path=get(ENV,"FUSION_G2_FOLLOWUP_BPHI_BASELINE_RAW_PATH","")
    baseline_sha=lowercase(get(ENV,"FUSION_G2_FOLLOWUP_BPHI_BASELINE_RAW_SHA256",""))
    report_path=get(ENV,"FUSION_G2_FOLLOWUP_BPHI_BASELINE_REPORT_PATH","")
    report_sha=lowercase(get(ENV,"FUSION_G2_FOLLOWUP_BPHI_BASELINE_REPORT_SHA256",""))
    all(p->!isempty(p)&&isfile(p),(action_path,baseline_path,report_path)) &&
        all(h->occursin(r"^[0-9a-f]{64}$",h),(action_sha,baseline_sha,report_sha)) ||
        error("follow-up Bphi action requires pinned action, accepted baseline raw, and accepted report")
    all(p->_g2_global_diag_result_file_sha256(p[1])==p[2],
        ((action_path,action_sha),(baseline_path,baseline_sha),(report_path,report_sha))) ||
        error("follow-up Bphi action/baseline/report digest mismatch")
    out=joinpath(numeric_result_run_leaf,"result_data","g2_global_diagnostic")
    mkpath(out)
    action=open(Serialization.deserialize,action_path,"r")
    baseline_raw=open(Serialization.deserialize,baseline_path,"r")
    accepted_report=open(Serialization.deserialize,report_path,"r")
    action.schema===:saved_followup_bphi_retraction_action_raw_v1 &&
        action.status===:numeric_action_saved_before_postconditions && all(values(action.checks)) ||
        error("follow-up Bphi action schema/status/checks are not qualified")
    baseline_raw.schema=="g2-global-diagnostic-actual-nonlinear-trial-raw-v1" &&
        accepted_report.schema=="actual-saved-trial-next-kkt-nonlinear-trial-report-v1" &&
        accepted_report.status===:accepted && accepted_report.trial_status===:accepted &&
        accepted_report.accepted_trial!==nothing &&
        accepted_report.accepted_trial.endpoint_final_gate===true &&
        accepted_report.accepted_trial.pressure_final_gate===true ||
        error("follow-up Bphi source is not an accepted actual nonlinear trial with endpoint/pressure gates")
    baseline_state=collect(Float64,baseline_raw.state)
    length(baseline_state)==69_447 && all(isfinite,baseline_state) ||
        error("follow-up Bphi baseline state dimensions/values differ")
    baseline_state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,baseline_state)))
    source_trial_index=Int(baseline_raw.trial_index)
    source_alpha=Float64(baseline_raw.alpha)
    accepted_state=collect(Float64,accepted_report.accepted_trial.state)
    action_before=collect(Float64,action.correction.state_before)
    action_after=collect(Float64,action.correction.state_after)
    action_profile_F_before=collect(Float64,action.correction.profile_F_before_T_m)
    action_current_scales=collect(Float64,action.current.row_scales_A_per_m2)
    action.source.trial_index==source_trial_index &&
        action.source.alpha==source_alpha==accepted_report.accepted_trial.alpha &&
        accepted_state==baseline_state && action_before==baseline_state &&
        action.source.state_sha256==baseline_state_sha &&
        normpath(abspath(action.inputs.paths.trial))==normpath(abspath(baseline_path)) &&
        action.inputs.sha256.trial==baseline_sha ||
        error("follow-up action, accepted report, and trial raw do not bind the same state/alpha/source")
    for key in (:lineage_report,:field_capture)
        input_path=getproperty(action.inputs.paths,key)
        input_sha=getproperty(action.inputs.sha256,key)
        isfile(input_path) && occursin(r"^[0-9a-f]{64}$",input_sha) &&
            _g2_global_diag_result_file_sha256(input_path)==input_sha ||
            error("follow-up action's $(key) input binding/digest differs")
    end
    action.source.candidate_hash==component.candidate_hash &&
        action.source.current_operator_model_id===component.current_operator_model_id &&
        action.source.field_model_id===component.native_field_model_id &&
        action.source.source_operator_model_id===:not_embedded_in_trial_raw &&
        component.current_operator_model_id===:not_a_knot_spline_delta_star_strong_collocation_v1 ||
        error("follow-up action candidate/current/field lineage differs from the live component")
    component.status===:prepared_full_native_profile_component && component.dynamic_profile_span &&
        length(component.core_mask)==16_641 && length(component.profile_span_columns)==2 &&
        Tuple(component.profile_span_columns)==(69_446,69_447) &&
        length(endpoint_rows)==length(endpoint_ids)==2 ||
        error("follow-up action live native component/endpoint ABI differs")
    assembly=baseline_raw.result.diagnostic_assembly
    baseline_raw.result.status===:typed_absent && baseline_raw.result.missing_closures===S._REQUIRED_CLOSURES &&
        assembly.status===:incomplete_assembly && assembly.claim_ceiling===:diagnostic_only &&
        assembly.physical_authority===false && assembly.residual_scaling===:frozen_row_scales &&
        all(c->c.passed,assembly.jacobian_checks.regional) &&
        all(c->c.passed,assembly.jacobian_checks.outer) &&
        assembly.jacobian_checks.global_conservation.passed===true ||
        error("follow-up baseline actual assembly/oracles/claim scope differ")
    length(assembly.equation_ids.regional)==1 && length(assembly.equation_ids.outer)==1 &&
        collect(assembly.equation_ids.regional[1])==collect(regional.equation_ids) &&
        collect(assembly.equation_ids.outer[1])==collect(composed.outer.constraint_ids) &&
        collect(assembly.equation_ids.conservation)==collect(provider.conservation_ids) &&
        collect(Float64,assembly.equilibrium_row_scales)==collect(Float64,scale_contract.equilibrium.characteristics) ||
        error("follow-up baseline ordered row ownership/frozen scale binding differs")
    baseline_report_merit=Float64(accepted_report.accepted_trial.merit)
    isfinite(baseline_report_merit) && baseline_report_merit>0.0 ||
        error("follow-up accepted baseline merit is invalid")
    regional_ids=collect(assembly.equation_ids.regional[1])
    n=16_641;ndof=69_447
    size(assembly.jacobian)==(68_934,ndof) && size(assembly.equality_jacobian)==(577,ndof) &&
        length(assembly.residual)==68_934 && length(assembly.equality_residual)==577 &&
        length(assembly.equilibrium_row_scales)==68_934 ||
        error("follow-up baseline R/J/C/c dimensions differ")
    phi=collect(Int,action.native_map.phi_global_columns)
    expected_phi=Int[4k-2 for k in 1:n]
    phi==expected_phi && action.native_map.n==n && action.native_map.domain_ndof==ndof ||
        error("follow-up Bphi native global-column map differs")
    expected_pressure=Int[component.pressure_dofs[k] for k in eachindex(component.core_mask) if component.core_mask[k]]
    length(expected_pressure)==2879 &&
        collect(Int,action.native_map.pressure_global_columns)==expected_pressure ||
        error("follow-up action pressure map differs from the live 2879 active pressure columns")
    phi_set=Set(phi)
    profile_rows=zeros(Int,n)
    profile_ids=Vector{String}(undef,n)
    for (row,id) in enumerate(regional_ids)
        m=match(r":profile_F:node_(\d+)$",string(id))
        m===nothing && continue
        k=parse(Int,m.captures[1])
        1<=k<=n && profile_rows[k]==0 || error("follow-up profile-F row map is duplicate or out of range")
        profile_rows[k]=row;profile_ids[k]=String(id)
    end
    all(>(0),profile_rows) && profile_ids==String[String(x) for x in action.native_map.profile_F_row_ids] ||
        error("follow-up action profile-F row IDs/order differ from the saved baseline")
    D=collect(Float64,action.correction.profile_F_before_T_m)
    radius=collect(Float64,action.native_map.R_then_Z_native_R_m)
    delta=collect(Float64,action.correction.delta_Bphi_T)
    length(D)==length(radius)==length(delta)==n && all(isfinite,D) &&
        all(x->isfinite(x)&&x>0.0,radius) && delta==Float64[-D[k]/radius[k] for k in 1:n] &&
        collect(Float64,assembly.residual[profile_rows])==D ||
        error("follow-up Bphi action D/R is not bound to the saved actual F rows")
    expected_after=copy(baseline_state);expected_after[phi].+=delta
    expected_after==action_after && all(k->baseline_state[4k]==action_after[4k],1:n) &&
        all(i->baseline_state[i]==action_after[i],(i for i in eachindex(baseline_state) if !(i in phi_set))) ||
        error("follow-up Bphi action state changes anything outside its native Bphi columns")
    all(k->isfinite(action_after[phi[k]])&&action_after[phi[k]]>0.0,1:n) &&
        all(i->action_after[i]>=0.0,(i for i in component.pressure_dofs if i>0)) ||
        error("follow-up Bphi action violates the original state-domain preguard")
    outer_ids=String[]
    for group in assembly.equation_ids.outer;append!(outer_ids,String[String(id) for id in group]);end
    equality_ids=vcat(outer_ids,String[String(id) for id in assembly.equation_ids.conservation])
    equality_ids==String[String(id) for id in scale_contract.equalities.row_ids] ||
        error("follow-up baseline equality row order differs from the live consumer")
    equality_scales=collect(Float64,scale_contract.equalities.characteristics)
    length(equality_scales)==length(equality_ids)==577 &&
        all(x->isfinite(x)&&x>0.0,equality_scales) || error("follow-up equality row scales differ")
    equality_map=Dict{String,Int}(id=>i for (i,id) in enumerate(equality_ids))
    current_ids=String[String(id) for id in action.native_map.current_row_ids]
    expected_current_ids=String["current_topology:LCFS_Jn:ray_"*lpad(string(i),3,'0') for i in 1:64]
    current_rows=Int[equality_map[id] for id in current_ids if haskey(equality_map,id)]
    length(current_rows)==64 && current_ids==expected_current_ids &&
        current_rows==collect(Int,action.native_map.current_row_indices) ||
        error("follow-up ordered 64-ray current row map differs")
    baseline_current=collect(Float64,assembly.equality_residual[current_rows])
    action.current.units=="A m^-2" && baseline_current==collect(Float64,action.current.before_A_per_m2) &&
        collect(Float64,equality_scales[current_rows])==collect(Float64,action.current.row_scales_A_per_m2) ||
        error("follow-up action baseline Jn/current scales differ from the saved assembly")
    displacement=zeros(Float64,ndof)
    displacement[phi]=delta
    baseline_state.+displacement==action_after &&
        all(i->displacement[i]==0.0,(i for i in eachindex(displacement) if !(i in phi_set))) ||
        error("follow-up displacement does not reproduce the exact saved Bphi action state")
    observed_state_delta=action_after.-baseline_state
    state_update_roundoff_max_T=maximum(abs,observed_state_delta[phi].-delta;init=0.0)
    predicted=collect(Float64,assembly.equality_jacobian[current_rows,phi]*delta)
    predicted==collect(Float64,action.current.Cphi_predicted_delta_A_per_m2) ||
        error("follow-up action predicted current delta differs from the saved same-state Cphi block")
    action_predicted=copy(predicted)
    endpoint_rows=Int.(collect(endpoint_rows));endpoint_ids=Tuple(endpoint_ids)
    Tuple(regional_ids[i] for i in endpoint_rows)==endpoint_ids ||
        error("follow-up dynamic endpoint rows do not match the live producer")
    ls_rows=Int[i for i in eachindex(assembly.residual) if !(i in Set(endpoint_rows))]
    length(ls_rows)==68_932 || error("follow-up least-squares rows differ from the original partition")
    ls_ids=String[regional_ids[i] for i in ls_rows]
    ls_scales=collect(Float64,assembly.equilibrium_row_scales[ls_rows])
    partition_eq_ids=vcat(String[String(id) for id in scale_contract.equalities.row_ids],String[String(id) for id in endpoint_ids])
    partition_eq_scales=vcat(equality_scales,Float64[assembly.equilibrium_row_scales[i] for i in endpoint_rows])
    partition_eq_residual=vcat(collect(Float64,assembly.equality_residual),
        Float64[assembly.residual[i] for i in endpoint_rows])
    partition_eq_jacobian=[assembly.equality_jacobian;assembly.jacobian[endpoint_rows,:]]
    actual_profile_rows=copy(profile_rows)
    actual_ls_rows=copy(ls_rows)
    baseline_ls_scaled=collect(Float64,assembly.residual[ls_rows])./ls_scales
    predicted_ls=collect(Float64,assembly.residual[ls_rows])+assembly.jacobian[ls_rows,:]*displacement
    predicted_ls_scaled=predicted_ls./ls_scales
    baseline_eq_scaled=partition_eq_residual./partition_eq_scales
    predicted_eq=partition_eq_residual+partition_eq_jacobian*displacement
    predicted_eq_scaled=predicted_eq./partition_eq_scales
    predicted_F=collect(Float64,assembly.residual[profile_rows])+assembly.jacobian[profile_rows,:]*displacement
    linearized_merit_after=0.5*(sum(abs2,predicted_ls_scaled)+sum(abs2,predicted_eq_scaled))
    all(isfinite,predicted_F) && isfinite(linearized_merit_after) ||
        error("follow-up saved-J action prediction is nonfinite")
    part=S.weighted_residual_kkt_partition_v1(candidate_hash=component.candidate_hash,
        consumer_identity=(candidate_hash=component.candidate_hash,provider_id=diagnostic_model.provider_id,
            model_hash=diagnostic_model.model_hash,component_context_hash=component.context_hash,
            trace_hash=trace.trace_hash,scale_contract_hash=scale_contract.contract_hash,
            scale_policy=scale_contract.scale_policy,scope=:diagnostic_incomplete_global_assembly),
        least_squares_row_ids=ls_ids,least_squares_residual=assembly.residual[ls_rows],
        least_squares_jacobian=assembly.jacobian[ls_rows,:],least_squares_row_scales=ls_scales,
        equality_row_ids=partition_eq_ids,equality_row_scales=partition_eq_scales,
        equality_residual=partition_eq_residual,equality_jacobian=partition_eq_jacobian)
    abs(part.merit-baseline_report_merit)<=64eps(Float64)*max(1.0,baseline_report_merit) ||
        error("reconstructed follow-up baseline merit differs from its accepted trial report")
    part=merge(part,(raw_least_squares_jacobian=nothing,raw_equality_jacobian=nothing,
        scaled_least_squares_jacobian=nothing,equality_jacobian=nothing))
    baseline_raw=nothing;assembly=nothing;accepted_report=nothing;action=nothing
    profile_rows=nothing;profile_ids=nothing;regional_ids=nothing;partition_eq_jacobian=nothing
    partition_eq_residual=nothing;GC.gc(true)
    diagnostic.diagnostic_assembly.jacobian===nothing &&
        diagnostic.diagnostic_assembly.equality_jacobian===nothing ||
        error("follow-up action must use the released-operator production consumer")
    println("G2_FOLLOWUP_BPHI_ACTION_BOUND baseline_alpha=1/1024 state_sha256=",baseline_state_sha,
        " profile_F_rows=16641 current_rows=64 baseline_merit=",part.merit,
        " linearized_merit_after=",linearized_merit_after,
        " linearized_merit_delta=",linearized_merit_after-part.merit,
        " predicted_F_max=",maximum(abs,predicted_F;init=0.0),
        " predicted_Jn_max_delta=",maximum(abs,predicted;init=0.0),"; actual corrected current remains uncomputed")
    flush(stdout)
    result=_g2_actual_nonlinear_trial_consumer_v1(S,F,component,composed,provider,regional,
        diagnostic_model,scale_contract,part,(step=displacement,),baseline_state,
        numeric_result_run_leaf,endpoint_rows,endpoint_ids,diagnostic;
        geometry_cache=nothing,max_alpha_power=0,min_alpha_power=0,
        projection_replay_binding=nothing,require_acceptance=false,apply_span_projection=false)
    if get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")=="1"
        result.status===:abi_preflight || error("follow-up Bphi production consumer ABI preflight failed")
        raw=(schema=:actual_saved_followup_bphi_action_input_preflight_v1,
            status=:abi_preflight,action_sha256=action_sha,baseline_raw_sha256=baseline_sha,
            baseline_report_sha256=report_sha,baseline_state_sha256=baseline_state_sha,
            corrected_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,expected_after))),
            baseline_trial_index=source_trial_index,baseline_alpha=source_alpha,
            baseline_merit=part.merit,linearized_merit_after=linearized_merit_after,
            linearized_merit_delta=linearized_merit_after-part.merit,
            baseline_F_max=maximum(abs,D;init=0.0),linearized_F_max=maximum(abs,predicted_F;init=0.0),
            state_update=(requested_Bphi_delta_T=delta,observed_Bphi_delta_T=observed_state_delta[phi],
                max_abs_observed_minus_requested_T=state_update_roundoff_max_T,
                pressure_dof_count=length(expected_pressure),pressure_columns_exactly_match_live=true),
            current=(before_A_per_m2=baseline_current,predicted_delta_A_per_m2=action_predicted,
                linearized_after_A_per_m2=baseline_current.+action_predicted,
                max_abs_before=maximum(abs,baseline_current;init=0.0),
                max_abs_linearized_after=maximum(abs,baseline_current.+action_predicted;init=0.0)),
            rows=(least_squares=length(ls_ids),equality=length(partition_eq_ids),profile_F=n,current=64),
            execution=(geometry_calls=0,new_assemblies=0,kkt_solves=0,
                actual_corrected_Jn=false,formal_acceptance=false,physical_validation=false))
        preflight_path=joinpath(out,"actual_saved_followup_bphi_action_input_preflight_v1.jls")
        ispath(preflight_path)&&error("refusing to overwrite follow-up Bphi input preflight raw")
        open(preflight_path,"w") do io;Serialization.serialize(io,raw);flush(io);end
        println("G2_FOLLOWUP_BPHI_ACTION_INPUT_PREFLIGHT_RAW path=",abspath(preflight_path),
            " sha256=",_g2_global_diag_result_file_sha256(preflight_path),
            " linearized_merit_delta=",linearized_merit_after-part.merit,
            " predicted_Jn_max_before=",maximum(abs,baseline_current;init=0.0),
            " predicted_Jn_max_after=",maximum(abs,baseline_current.+action_predicted;init=0.0),
            " geometry_calls=0 assemblies=0 kkt_solves=0");flush(stdout)
        return (status=:followup_bphi_action_abi_preflight,accepted_trial=nothing,
            trial_records=(),preflight_raw_path=preflight_path,report_path=preflight_path,
            formal_acceptance=false,physical_validation=false)
    end
    result_path=joinpath(out,"actual_followup_bphi_consumer_return_raw_v1.jls")
    ispath(result_path)&&error("refusing to overwrite follow-up Bphi consumer return raw")
    open(result_path,"w") do io;Serialization.serialize(io,result);flush(io);end
    accepted=result.accepted_trial
    trial_path=joinpath(out,"actual_nonlinear_trial_raw_000_v1.jls")
    isfile(trial_path) || error("follow-up Bphi trial did not save the actual full assembly raw")
    trial_sha=_g2_global_diag_result_file_sha256(trial_path)
    trial=open(Serialization.deserialize,trial_path,"r")
    trial.schema=="g2-global-diagnostic-actual-nonlinear-trial-raw-v1" &&
        collect(Float64,trial.state)==expected_after || error("follow-up actual raw does not bind the corrected action state")
    actual_assembly=trial.result.diagnostic_assembly
    actual_assembly.status===:incomplete_assembly && actual_assembly.claim_ceiling===:diagnostic_only &&
        actual_assembly.physical_authority===false &&
        all(c->c.passed,actual_assembly.jacobian_checks.regional) &&
        all(c->c.passed,actual_assembly.jacobian_checks.outer) &&
        actual_assembly.jacobian_checks.global_conservation.passed===true ||
        error("follow-up corrected-state actual assembly/oracles failed")
    actual_outer_ids=String[]
    for group in actual_assembly.equation_ids.outer;append!(actual_outer_ids,String[String(id) for id in group]);end
    actual_eq_ids=vcat(actual_outer_ids,String[String(id) for id in actual_assembly.equation_ids.conservation])
    actual_eq_ids==equality_ids &&
        collect(actual_assembly.equation_ids.regional[1])==collect(regional.equation_ids) ||
        error("follow-up corrected-state row ownership/order changed")
    actual_eq_map=Dict{String,Int}(id=>i for (i,id) in enumerate(actual_eq_ids))
    actual_current_rows=Int[actual_eq_map[id] for id in current_ids]
    actual_current=collect(Float64,actual_assembly.equality_residual[actual_current_rows])
    current_delta=actual_current.-baseline_current
    actual_profile_F=collect(Float64,actual_assembly.residual[actual_profile_rows])
    actual_ls=actual_assembly.residual[actual_ls_rows]./collect(part.least_squares_row_scales)
    actual_eq=vcat(collect(Float64,actual_assembly.equality_residual),
        Float64[actual_assembly.residual[i] for i in endpoint_rows])./collect(part.equality_row_scales)
    actual_merit=0.5*(sum(abs2,actual_ls)+sum(abs2,actual_eq))
    isfinite(actual_merit) || error("follow-up corrected-state merit is nonfinite")
    current_before_max=maximum(abs,baseline_current;init=0.0)
    current_after_max=maximum(abs,actual_current;init=0.0)
    actual_endpoint=collect(Float64,actual_assembly.residual[endpoint_rows])
    post_geometry=Base.invokelatest(component.lcfs_dynamic_geometry_trace,expected_after)
    geometry_status=get(post_geometry,:status,:typed_absent)
    geometry_mask=get(post_geometry,:mask_event,:unknown)
    geometry_ids=hasproperty(post_geometry,:psi_global_dof_ids) ?
        collect(Int,post_geometry.psi_global_dof_ids) : Int[]
    geometry_coordinates=hasproperty(post_geometry,:coordinates_RZ_m) ?
        Tuple(post_geometry.coordinates_RZ_m) : ()
    geometry_normals=hasproperty(post_geometry,:normals_RZ) ? Tuple(post_geometry.normals_RZ) : ()
    geometry_record=(state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,expected_after))),
        status=geometry_status,mask_event=geometry_mask,coordinates_RZ_m=geometry_coordinates,
        normals_RZ=geometry_normals,
        psi_axis_Wb_per_rad=hasproperty(post_geometry,:psi_axis_Wb_per_rad) ?
            Float64(post_geometry.psi_axis_Wb_per_rad) : nothing,
        psi_boundary_Wb_per_rad=hasproperty(post_geometry,:psi_boundary_Wb_per_rad) ?
            Float64(post_geometry.psi_boundary_Wb_per_rad) : nothing,
        endpoint_definition_residual=hasproperty(post_geometry,:endpoint_definition_residual) ?
            Tuple(Float64.(post_geometry.endpoint_definition_residual)) : nothing,
        first_outward_crossing_signature=hasproperty(post_geometry,:first_outward_crossing_signature) ?
            Tuple(post_geometry.first_outward_crossing_signature) : (),
        psi_global_dof_ids=geometry_ids,ray_rule=get(post_geometry,:ray_rule,:typed_absent),
        field_model_id=get(post_geometry,:field_model_id,:typed_absent),
        field_representation=get(post_geometry,:field_representation,:typed_absent),
        source_critical_point_method=get(post_geometry,:source_critical_point_method,:typed_absent),
        source_critical_point_role=get(post_geometry,:source_critical_point_role,:typed_absent),
        source_fd_anchor_use=get(post_geometry,:source_fd_anchor_use,:typed_absent),
        solver_rows_added=get(post_geometry,:solver_rows_added,:typed_absent),
        global_topology_closed=get(post_geometry,:global_topology_closed,:typed_absent),
        physical_validation=get(post_geometry,:physical_validation,:typed_absent))
    coordinates_finite=length(geometry_coordinates)==64 && all(p->length(p)==2 && all(isfinite,p),geometry_coordinates)
    normals_finite=length(geometry_normals)==64 && all(p->length(p)==2 && all(isfinite,p),geometry_normals)
    endpoint_values_finite=geometry_record.endpoint_definition_residual!==nothing &&
        length(geometry_record.endpoint_definition_residual)==2 && all(isfinite,geometry_record.endpoint_definition_residual)
    geometry_gate=geometry_status===:evaluated_dynamic_LCFS_geometry && geometry_mask===:unchanged &&
        length(geometry_coordinates)==length(geometry_normals)==64 && length(geometry_ids)==n &&
        coordinates_finite && normals_finite &&
        all(k->geometry_ids[k]==4k,1:n) && geometry_record.field_model_id===component.native_field_model_id &&
        geometry_record.ray_rule===Symbol("64_ray_first_sampled_outward_psiN_1_bracket") &&
        geometry_record.field_representation===:plasma_not_a_knot_spline_plus_unclipped_exact_PF_Green_jet &&
        endpoint_values_finite && geometry_record.psi_axis_Wb_per_rad!==nothing &&
        isfinite(geometry_record.psi_axis_Wb_per_rad) && geometry_record.psi_boundary_Wb_per_rad!==nothing &&
        isfinite(geometry_record.psi_boundary_Wb_per_rad) && geometry_record.solver_rows_added==0 &&
        geometry_record.global_topology_closed===false && geometry_record.physical_validation===false &&
        geometry_record.source_critical_point_role===:seed_only_rebound_on_composite_psi &&
        geometry_record.source_fd_anchor_use===:unchanged_source_records_not_reused_as_continuous_fields
    endpoint_tol=geometry_gate ? 64eps(Float64)*max(1.0,maximum(abs,
        (geometry_record.psi_axis_Wb_per_rad,geometry_record.psi_boundary_Wb_per_rad);init=0.0)) : nothing
    actual_endpoint_gate=endpoint_tol===nothing ? false :
        maximum(abs,actual_endpoint;init=0.0)<=endpoint_tol
    pressure_gate=accepted===nothing ? :not_evaluated : accepted.pressure_final_gate===true
    pressure_status=accepted===nothing ? :not_evaluated : accepted.pressure_trace_status
    pressure_max=accepted===nothing ? nothing : accepted.pressure_max_residual
    pressure_coverage=accepted===nothing ? :not_evaluated : accepted.pressure_coverage_status
    action_raw_result=(schema=:actual_saved_followup_bphi_action_consumer_numeric_v1,
        status=:actual_corrected_state_full_assembly_saved,action_path=abspath(action_path),action_sha256=action_sha,
        baseline_raw_path=abspath(baseline_path),baseline_raw_sha256=baseline_sha,
        baseline_report_path=abspath(report_path),baseline_report_sha256=report_sha,
        baseline_state_sha256=baseline_state_sha,corrected_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,expected_after))),
        trial_raw_path=abspath(trial_path),trial_raw_sha256=trial_sha,
        source=(trial_index=source_trial_index,alpha=source_alpha,current_operator_model_id=component.current_operator_model_id,
            source_operator_model_id=component.hagenow_source_operator_model_id,
            field_model_id=component.native_field_model_id),
        identity=(candidate_hash=component.candidate_hash,context_hash=component.context_hash,
            upstream_output_hash=component.upstream_output_hash,trace_hash=trace.trace_hash),
        profile_F=(before_T_m=action_profile_F_before,
            actual_after_T_m=actual_profile_F,delta_Bphi_T=delta),
        current=(row_ids=current_ids,row_scales_A_per_m2=action_current_scales,
            before_A_per_m2=baseline_current,actual_after_A_per_m2=actual_current,
            actual_delta_A_per_m2=current_delta,predicted_delta_A_per_m2=action_predicted,
            max_abs_before_A_per_m2=current_before_max,max_abs_after_A_per_m2=current_after_max,
            residual_max_decreased=current_after_max<current_before_max),
        merit=(before=part.merit,after=actual_merit,reduction=part.merit-actual_merit,
            strict_decrease=actual_merit<part.merit),
        endpoints=(row_ids=endpoint_ids,residual_Wb_per_rad=actual_endpoint,
            tolerance_Wb_per_rad=endpoint_tol,gate=actual_endpoint_gate),
        pressure=(status=pressure_status,max_residual_Pa=pressure_max,
            gate=pressure_gate,coverage=pressure_coverage),
        conservation=(normalization_residual=Float64(actual_assembly.raw_blocks.conservation.residual[1]),
            all_64_current_rows=true),
        geometry=geometry_record,geometry_gate=geometry_gate,
        geometry_source=only(result.trial_records).geometry_source,
        consumer_status=result.status,consumer_trial_records=result.trial_records,
        checks=(baseline_raw_report_action_exact_binding=true,action_is_Bphi_only=true,
            corrected_state_actual_assembly_oracles=true,post_consumer_geometry_recheck=geometry_gate,
            strict_merit_decrease=accepted!==nothing,
            actual_endpoint_gate=actual_endpoint_gate,actual_pressure_gate=pressure_gate),
        evidence_ceiling=:actual_same_state_Bphi_action_full_assembly_diagnostic,
        formal_acceptance=false,physical_validation=false,current_topology_decision=:hold)
    outpath=joinpath(out,"actual_saved_followup_bphi_action_consumer_numeric_v1.jls")
    ispath(outpath)&&error("refusing to overwrite follow-up Bphi action consumer raw")
    open(outpath,"w") do io;Serialization.serialize(io,action_raw_result);flush(io);end
    println("G2_FOLLOWUP_BPHI_ACTION_CONSUMER_RAW path=",abspath(outpath),
        " sha256=",_g2_global_diag_result_file_sha256(outpath),
        " merit_before=",part.merit," merit_after=",actual_merit,
        " Jn_max_before=",current_before_max," Jn_max_after=",current_after_max,
        " Jn_max_decreased=",current_after_max<current_before_max,
        " endpoint_gate=",actual_endpoint_gate," pressure_gate=",pressure_gate,
        " formal_acceptance=false topology=hold");flush(stdout)
    (!geometry_gate || (accepted!==nothing && (actual_endpoint_gate!==true || pressure_gate!==true))) &&
        error("follow-up Bphi corrected state fails endpoint/pressure gates; raw retained")
    (status=accepted===nothing ? :actual_followup_bphi_no_strict_merit_decrease :
        :actual_followup_bphi_action_consumer_completed,accepted_trial=accepted,
        trial_records=result.trial_records,consumer_numeric_path=outpath,report_path=outpath,
        trial_raw_path=trial_path,physical_validation=false,formal_acceptance=false)
end

Base.@noinline Base.@nospecializeinfer function _g2_saved_minus_raw_trial_direct_entry_v1(F,context,artifacts,trace,component)
    Base.@nospecialize context artifacts trace component
    followup_bphi_mode=get(ENV,"FUSION_G2_FOLLOWUP_BPHI_ACTION_CONSUMER","0")
    followup_bphi_mode in ("0","1") || error("follow-up Bphi action consumer flag must be 0 or 1")
    D_reassembly_mode=get(ENV,"FUSION_G2_SAVED_X3_D_REASSEMBLY","0")
    D_reassembly_mode in ("0","1") || error("saved x3 D reassembly flag must be 0 or 1")
    x3_live_cut_mode=get(ENV,"FUSION_G2_X3_LIVE_CURRENT_CUT_ONLY","0")
    x3_live_cut_mode in ("0","1") || error("x3 live-current/cut mode must be 0 or 1")
    x3_region_short_mode=get(ENV,"FUSION_G2_X3_LIVE_REGION_SHORT_ONLY","0")
    x3_region_short_mode in ("0","1") || error("x3 live-region short mode must be 0 or 1")
    x3_region_short_mode=="1" && x3_live_cut_mode!="0" &&
        error("live-region short is separate from live current/cut capture")
    (D_reassembly_mode=="1")===(get(component,:state_coordinate_id,:native_Bphi_T_v1)===:native_F_defect_T_m_v1) ||
        error("D component requires the explicit D state-admission/reassembly route")
    standard_saved_minus_mode=get(ENV,"FUSION_G2_RESUME_SAVED_GS_U_PLUS","0")=="1" &&
        get(ENV,"FUSION_G2_REUSE_SAVED_GS_U_MINUS_RAW","0")=="1"
    get(ENV,"FUSION_G2_PRECHECK_MODE","")=="global_diagnostic" &&
        get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1" &&
        get(ENV,"FUSION_FREEGS_DYNAMIC_PROFILE_SPAN","0")=="1" &&
        (D_reassembly_mode=="1" || followup_bphi_mode=="1" || standard_saved_minus_mode) ||
        error("saved direct trial requires the original selected native dynamic-span diagnostic mode")
    run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
    !isempty(run_leaf)&&isdir(run_leaf) || error("saved-minus trial-only requires the current bounded output leaf")
    component.status===:prepared_full_native_profile_component && component.dynamic_profile_span &&
        length(component.initial_state)==69_447 && length(component.dynamic_span_row_range)==2 &&
        length(component.dynamic_span_equation_ids)==2 || error("actual selected component state/endpoint map differs")
    component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1 ||
        error("actual native field model identity differs")
    _g2_actual_pressure_dof_map_matches_v1(component) || error("actual pressure DOF map differs from native core mask")
    if x3_region_short_mode=="1"
        D_reassembly_mode=="1" || error("live-region short requires the admitted D-coordinate component")
        get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ONLY","0")=="1" ||
            error("live-region short requires the direct trial-only route")
        Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_x3_D_global_reassembly.jl"))
        Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned","current_x3_live_region_short_check.jl"))
        println("G2_REGION_SHORT_FACTORY_BEGIN");flush(stdout)
        region=F.freegs_axisymmetric_mhd_native_grid_region(context,artifacts)
        println("G2_REGION_SHORT_FACTORY_END");flush(stdout)
        region isa F.FreeGSAxisymmetricMHDRegionV4 ||
            error("accepted FreeGS native MHD region factory returned unavailable data")
        input=Base.invokelatest(_g2_saved_x3_D_admitted_input_v1)
        state=component.admit_state_record(input.state_record)
        core_stage_path=joinpath(@__DIR__,"..","runs","e",
            "up2_x3_live_current_periodic_cut_20261015_r2","result_data","g2_global_diagnostic",
            "current_x3_live_core_current_trace_v1.jls")
        core_stage=open(Serialization.deserialize,core_stage_path)
        reuse_base_path=get(ENV,"FUSION_G2_X3_LIVE_REGION_REUSE_BASE_RAW_PATH","")
        reuse_base_sha=get(ENV,"FUSION_G2_X3_LIVE_REGION_REUSE_BASE_RAW_SHA256","")
        reuse_fd_plan=get(ENV,"FUSION_G2_X3_LIVE_REGION_REUSE_FD_PLAN_PATH","")
        reuse_fd_plan_sha=get(ENV,"FUSION_G2_X3_LIVE_REGION_REUSE_FD_PLAN_SHA256","")
        if isempty(reuse_base_path)
            isempty(reuse_base_sha) && isempty(reuse_fd_plan) && isempty(reuse_fd_plan_sha) ||
                error("partial R1 base/FD-plan reuse pins are not allowed")
            result=Base.invokelatest(save_x3_live_region_short_check_v1,component,
                region,state,core_stage,run_leaf)
        else
            all(x->!isempty(x),(reuse_base_sha,reuse_fd_plan,reuse_fd_plan_sha)) ||
                error("R1 base reuse requires its expected hash and saved FD plan")
            result=Base.invokelatest(save_x3_live_region_short_check_v1,component,
                region,state,core_stage,run_leaf;
                reuse_base_raw_path=reuse_base_path,
                reuse_base_raw_sha256=reuse_base_sha,
                reuse_fd_plan_path=reuse_fd_plan,
                reuse_fd_plan_sha256=reuse_fd_plan_sha)
        end
        result.status===:x3_live_region_short_completed || error("regional current short-check failed")
        println("G2_SAVED_MINUS_DIRECT_REGION_SHORT_COMPLETE status=",result.status,
            " report_path=",result.report_path," full_curl_reused=true global_assembly=0 KKT=0");flush(stdout)
        return result
    end
    S=F.InHouseCoupledMHDGlobalSolveV1
    stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=payload");flush(stdout)
    payload=F.freegs_axisymmetric_toroidal_loop_payload(context,artifacts,trace)
    println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=payload elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
    payload.status===:present && payload.candidate_hash==component.candidate_hash &&
        payload.trace_hash==trace.trace_hash && !payload.closure_evidence_created &&
        !payload.physical_validation || error("actual current payload is not bound or diagnostic-only")
    stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=provider");flush(stdout)
    provider=component.current_conservation_callbacks(payload)
    println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=provider elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
    provider.status===:prepared_conservation_evaluator && provider.psi_dofs==4 .* provider.native_ids ||
        error("actual conservation provider/native map differs")
    if x3_live_cut_mode=="1"
        D_reassembly_mode=="1" || error("x3 live current/cut capture requires the admitted D-coordinate component")
        get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ONLY","0")=="1" ||
            error("x3 live current/cut capture requires the direct trial-only route")
        Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_x3_D_global_reassembly.jl"))
        Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned","current_x3_live_callback_cut.jl"))
        return Base.invokelatest(_g2_x3_live_current_cut_capture_v1,S,F,component,provider,trace,run_leaf)
    end
    outer=component.outer_callbacks()
    outer.status===:prepared_outer_evaluator || error("actual Hagenow outer provider is unavailable")
    stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=composed");flush(stdout)
    composed=component.current_outer_partition(provider,outer)
    println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=composed elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
    composed.status===:prepared_current_outer_partition || error("actual current/outer partition is unavailable")
    stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=regional");flush(stdout)
    regional=component.regional_callbacks(composed;region_id="freegs_g2_full_native")
    println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=regional elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
    regional.status===:prepared_regional_evaluator && length(regional.equation_ids)==68_934 ||
        error("actual selected regional equation map differs")
    if D_reassembly_mode=="1" && get(ENV,"FUSION_G2_SAVED_D_C771_TRIAL","0")=="1"
        isdefined(Main,:_g2_x3_D_checkpoint) ||
            Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_x3_D_global_reassembly.jl"))
        isdefined(Main,:_g2_saved_D_C771_actual_trial_abi_preflight_v1) ||
            Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_D_kkt_trial_consumer.jl"))
        c771_pin=Base.invokelatest(_g2_D_trial_pin,"INPUT")
        c771_input=open(Serialization.deserialize,c771_pin.path)
        c771_pre=Base.invokelatest(_g2_saved_D_C771_actual_trial_abi_preflight_v1,
            F,component,trace,provider,c771_input)
        c771_pre_dir=joinpath(run_leaf,"result_data","g2_global_diagnostic");mkpath(c771_pre_dir)
        c771_pre_path=joinpath(c771_pre_dir,"saved_C771_live_interface_preflight_v1.jls")
        ispath(c771_pre_path) && error("refuse overwrite live C771 ABI checkpoint")
        open(c771_pre_path,"w") do io
            Serialization.serialize(io,(result=c771_pre,trace_fields=propertynames(trace),
                trace_data_fields=propertynames(trace.data),component_fields=propertynames(component),
                provider_fields=propertynames(provider),source_input_pin=c771_pin,
                field_calls=0,assemblies=0,KKT_solves=0));flush(io)
        end
        println("C771_LIVE_INTERFACE_PREFLIGHT status=",c771_pre.status,
            " reason=",get(c771_pre,:reason,:none)," saved=",c771_pre_path,
            " field=0 assembly=0 KKT=0");flush(stdout)
        c771_pre.status===:passed || error("C771 live interface preflight rejected: "*string(c771_pre.reason))
        c771_resume_dir=get(ENV,"FUSION_G2_SAVED_D_C771_RESUME_DIR","")
        if !isempty(c771_resume_dir)
            outer_numeric_path=get(ENV,"FUSION_G2_SAVED_D_C771_OUTER_NUMERIC_PATH","")
            result=if isempty(outer_numeric_path)
                Base.invokelatest(_g2_saved_D_C771_actual_trial_resume_v1,
                    F,component,trace,provider,c771_input,c771_resume_dir,run_leaf)
            else
                expected_sha=get(ENV,"FUSION_G2_SAVED_D_C771_OUTER_NUMERIC_SHA256","")
                bytes2hex(open(SHA.sha256,outer_numeric_path))==expected_sha || error("saved paired outer numeric result pin mismatch")
                n=open(Serialization.deserialize,outer_numeric_path)
                (status=:paired_Duffy_outer_diagnostic_complete,numeric=n,report_path=outer_numeric_path)
            end
            println("C771_SAVED_TRIAL_RESUME status=",result.status,
                " reason=",get(result,:reason,:none)," report=",result.report_path,
                " assembly=0 KKT=0");flush(stdout)
            if get(ENV,"FUSION_G2_C771_SAVED_PAIR_CURL_GS_OBSERVER","0")=="1"
                !isempty(outer_numeric_path) && result.status===:paired_Duffy_outer_diagnostic_complete ||
                    error("curl/GS observer requires pinned saved paired outer numeric")
                observer_region=F.freegs_axisymmetric_mhd_native_grid_region(context,artifacts)
                observer_region isa F.FreeGSAxisymmetricMHDRegionV4 ||
                    error("curl/GS observer native region is unavailable")
                Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned",
                    "C771_saved_pair_curl_gs_observer.jl"))
                return Base.invokelatest(_g2_C771_saved_pair_curl_gs_observer_v1,
                    F,component,observer_region,c771_input,result.numeric,run_leaf,c771_pin)
            end
            if result.status===:paired_Duffy_outer_diagnostic_complete &&
                    get(ENV,"FUSION_G2_SAVED_D_C771_FINISH_GLOBAL_MERIT","0")=="1"
                bindings=_g2_full_native_diagnostic_bindings_v1(F,context,component,trace,
                    provider,composed,regional)
                finished=try
                    Base.invokelatest(_g2_saved_D_C771_finish_saved_outer_merit_v1,
                        S,F,c771_input,bindings.model,result.numeric,run_leaf)
                catch err
                    (status=:typed_absent,reason=:resumed_global_merit_exception,
                        exception=sprint(showerror,err),paired_outer_report_path=result.report_path,
                        formal_acceptance=false,physical_validation=false)
                end
                if !hasproperty(finished,:report_path)
                    p=Base.invokelatest(_g2_x3_D_checkpoint,run_leaf,
                        "saved_actual_D_C771_resumed_global_merit_failure_v1",finished)
                    finished=merge(finished,(report_path=p.path,report_pin=p))
                end
                return finished
            end
            return result
        end
        c771_input=nothing;GC.gc(true)
    end
    stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=model_bindings");flush(stdout)
    bindings=_g2_full_native_diagnostic_bindings_v1(F,context,component,trace,
        provider,composed,regional)
    println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=model_bindings elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
    model=bindings.model;scale_contract=bindings.scale_contract
    candidate_scaling=(contract=scale_contract,column_scales=bindings.column_scales)
    length(candidate_scaling.column_scales)==69_447 &&
        length(scale_contract.equilibrium.characteristics)==68_934 &&
        length(scale_contract.equalities.row_ids)==577 &&
        length(scale_contract.equalities.characteristics)==577 &&
        Tuple(bindings.regional_row_ids)==Tuple(regional.equation_ids) &&
        Tuple(bindings.equality_row_ids)==Tuple(scale_contract.equalities.row_ids) &&
        _g2_actual_pressure_dof_map_matches_v1(component) || error("actual nonlinear trial row/scale/pressure bindings differ")
    all(isnothing,values(model.closure_evidence)) && model.candidate_hash==component.candidate_hash ||
        error("actual diagnostic trial model admitted closure evidence or changed candidate")
    endpoint_rows=Tuple(component.dynamic_span_row_range)
    endpoint_ids=Tuple(component.dynamic_span_equation_ids)
    length(endpoint_rows)==length(endpoint_ids)==2 || error("actual dynamic endpoint row/ID ABI differs")
    diagnostic_stub=(diagnostic_assembly=(jacobian=nothing,equality_jacobian=nothing,),)
    hasproperty(diagnostic_stub,:diagnostic_assembly) &&
        diagnostic_stub.diagnostic_assembly.jacobian===nothing &&
        diagnostic_stub.diagnostic_assembly.equality_jacobian===nothing ||
        error("actual trial diagnostic stub smoke failed")
    println("G2_SAVED_MINUS_TRIAL_DIRECT_PREFLIGHT_PASS state=69447 regional_rows=68934 base_equalities=577 endpoint_rows=2 pressure_grid=16641 positive_pressure_dofs=2879 assembly=0 kkt=0");flush(stdout)
    GC.gc(true)
    if D_reassembly_mode=="1"
        # Regression for captured providers: reject before invocation while
        # retaining the existing 512 H rows and adding no LCFS rows.
        provider_calls=Ref(0)
        captured_provider=let calls=provider_calls
            (args...;kwargs...)->begin
                calls[]+=1
                error("unsupported captured provider must never execute")
            end
        end
        rejected=component.outer_callbacks(lcfs_full64_inventory_provider=captured_provider)
        rejected.status===:typed_absent &&
            rejected.reason===:actual_full64_inventory_provider_captures_are_unsupported &&
            length(rejected.constraint_ids)==512 && rejected.global_rows_added==0 &&
            isempty(get(rejected,:lcfs_interface_row_ids,())) && provider_calls[]==0 ||
            error("D canonical captured-provider rejection lost its H512 fail-closed contract")
        println("D_CANONICAL_CAPTURED_PROVIDER_REJECT_PASS H_rows=512 LCFS_rows=0 provider_calls=0");flush(stdout)
        scale_contract.provenance.state_coordinate_id===:native_F_defect_T_m_v1 &&
            scale_contract.provenance.toroidal_column_rule===:R_times_physical_magnetic_field_T ||
            error("D canonical producer did not use the real coordinate-aware scale caller")
        Bscale=scale_contract.provenance.characteristics.magnetic_field_T
        all(k->candidate_scaling.column_scales[4k-2]==
            component.toroidal_coordinate_metric_R_m[k]*Bscale,eachindex(component.core_mask)) ||
            error("D canonical actual solver column scales are not R times physical B scale")
        Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_x3_D_global_reassembly.jl"))
        D_trial_mode=get(ENV,"FUSION_G2_SAVED_D_KKT_TRIAL","0")
        D_trial_mode in ("0","1") || error("D saved KKT trial flag must be 0 or 1")
        if D_trial_mode=="1"
            isdefined(Main,:_g2_saved_D_kkt_trial_consumer_v1) ||
                Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_D_kkt_trial_consumer.jl"))
            C771_trial_mode=get(ENV,"FUSION_G2_SAVED_D_C771_TRIAL","0")
            C771_trial_mode in ("0","1") || error("saved C771 trial selector must be 0 or 1")
            if C771_trial_mode=="1"
                input_pin=Base.invokelatest(_g2_D_trial_pin,"INPUT")
                abi_pin=Base.invokelatest(_g2_D_trial_pin,"C771_PREFLIGHT")
                b=open(Serialization.deserialize,input_pin.path)
                abi=open(Serialization.deserialize,abi_pin.path)
                if b.status===:qualified_saved_C771_numeric_KKT_metadata_ABI
                    if b.diagnostic_step_qualification.jacobian_role===:current_state_full_J_diagnostic
                        guard_path=joinpath(run_leaf,"result_data","g2_global_diagnostic",
                            "saved_C771_numeric_step_adapter_abi_guard_v1.jls")
                        guard=Base.invokelatest(_g2_C771_saved_numeric_step_adapter_abi_guard_v1,
                            b,abi,guard_path)
                        guard.status===:passed || error("C771 numeric-step ABI guard failed: "*
                            join(string.(guard.failed_checks),","))
                    else
                    abi.schema===:saved_actual_C771_numeric_KKT_trial_input_adapter_v1 &&
                        abi.status===:actual_C771_numeric_KKT_trial_metadata_ready &&
                        abi.state_sha256==b.binding.baseline_state_sha256 &&
                        abi.direction_sha256==b.binding.step_sha256 &&
                        all(k->getproperty(abi.source_pins.step,k)==getproperty(b.producing_C771_kkt_step_pin,k),
                            (:path,:sha256,:bytes)) &&
                        all(k->getproperty(abi.source_pins.rjc,k)==getproperty(b.source_full_unscaled_RJcC_pin,k),
                            (:path,:sha256,:bytes)) &&
                        abi.new_fields==abi.new_geometry==abi.new_assemblies==abi.new_KKT_solves==0 &&
                        abi.full_current_state_J===abi.full_global_kkt===abi.formal_acceptance===abi.physical_validation===false ||
                        error("C771 numeric-step ABI report differs from the actual saved input")
                    Base.invokelatest(_g2_C771_saved_numeric_step_metadata_check_v1,b)
                    end
                    b=Base.invokelatest(_g2_C771_trial_metadata_input_v1,b)
                else
                isdefined(Main,:_sao_sequence_equal) || Base.include(Main,joinpath(@__DIR__,"..",
                    "tmp","gs_linear_owned","saved_actual_outer_block_update.jl"))
                b.schema===:saved_actual_D_trial_input_v1 &&
                    b.status===:qualified_stage_c_metadata_ABI &&
                    abi.schema===:saved_C771_actual_saved_trial_inventory_v1 && abi.ready===true &&
                    abi.status===:saved_actual_C771_step_ready_for_separate_geometry_trial &&
                    all(c->c.passed,abi.checks) &&
                    Base.invokelatest(_sao_sequence_equal,abi.step,b.step) &&
                    Base.invokelatest(_sao_sequence_equal,abi.baseline_state,b.state_record.state) ||
                    error("C771 live trial requires the actual saved-input ABI and qualified step")
                raw_file=only(filter(f->f.name===:raw,abi.files))
                # A corrected R8 direction has its own result pin. Stage-C
                # remains the baseline metadata source, not the step source.
                raw_pin=hasproperty(b.binding,:producing_C771_step_pin) ?
                    b.binding.producing_C771_step_pin : b.binding.producing_stage_c_raw_pin
                normpath(abspath(raw_file.path))==normpath(abspath(raw_pin.path)) &&
                    raw_file.sha256==raw_pin.sha256 && raw_file.bytes==raw_pin.bytes ||
                    error("C771 trial ABI belongs to a different saved KKT step")
                end
                # Execute the original metadata consumer on the actual 769+2
                # row contract before any new-state field/assembly operation.
                frozen=(equalities=(row_ids=Tuple(b.equality_ids),
                        characteristics=Tuple(b.equality_scales)),
                    equilibrium=(characteristics=Tuple(b.regional_scales),))
                had_abi_flag=haskey(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY")
                old_abi_flag=get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")
                original_abi=try
                    ENV["FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY"]="1"
                    Base.invokelatest(_g2_actual_nonlinear_trial_consumer_v1,S,F,component,
                        nothing,nothing,nothing,nothing,frozen,b.partition,
                        (step=b.step,full_global_kkt=false),b.state_record.state,run_leaf,
                        b.endpoint_rows,b.endpoint_ids,
                        (diagnostic_assembly=(jacobian=nothing,equality_jacobian=nothing),);
                        min_alpha_power=0,max_alpha_power=0,
                        projection_replay_binding=b.binding,require_acceptance=false,
                        apply_span_projection=false)
                finally
                    if had_abi_flag
                        ENV["FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY"]=old_abi_flag
                    else
                        delete!(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY")
                    end
                end
                original_abi.status===:abi_preflight || error("original C771 consumer ABI did not pass")
                alpha=parse(Float64,get(ENV,"FUSION_G2_D_C771_TRIAL_ALPHA","1.0"))
                isfinite(alpha) && 0.0<alpha<=1.0 || error("C771 trial alpha is outside (0,1]")
                b=nothing;abi=nothing;original_abi=nothing;GC.gc(true)
                println("C771_ORIGINAL_CONSUMER_ABI_PASS rows=771 alpha=",alpha,
                    " assembly=0 solve=0 proof=HOLD");flush(stdout)
                return Base.invokelatest(_g2_saved_D_C771_actual_trial_v1,S,F,component,
                    trace,provider,composed,regional,model,scale_contract,run_leaf;alpha=alpha)
            end
            return Base.invokelatest(_g2_saved_D_kkt_trial_consumer_v1,S,F,component,trace,provider,
                composed,regional,model,candidate_scaling,scale_contract,run_leaf)
        end
        return Base.invokelatest(_g2_saved_x3_D_global_reassembly_v1,S,F,component,trace,provider,
            composed,regional,model,candidate_scaling,scale_contract,run_leaf)
    end
    projected_mode=get(ENV,"FUSION_G2_SAVED_PROJECTED_TRIAL","0")
    projected_mode in ("0","1") || error("saved projected trial flag must be 0 or 1")
    if projected_mode=="1"
        followup_bphi_mode=="0" && get(ENV,"FUSION_G2_RESUME_SAVED_TRIAL_NEXT_KKT","0")=="0" ||
            error("projected direction must use its own bound step, without Bphi or KKT resume")
        Base.include(Main,joinpath(@__DIR__,"..","tmp","astra_global_owned","saved_projected_trial_consumer.jl"))
        return Base.invokelatest(_g2_saved_projected_trial_consumer_v1,S,F,component,trace,provider,
            composed,regional,model,candidate_scaling,scale_contract,run_leaf)
    end
    if followup_bphi_mode=="1"
        get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ONLY","0")=="1" ||
            error("follow-up Bphi action requires the existing direct trial-only entry")
        stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=followup_bphi_action_consumer");flush(stdout)
        followup_result=_g2_saved_followup_bphi_action_consumer_v1(S,F,component,trace,provider,
            composed,regional,model,scale_contract,run_leaf,endpoint_rows,endpoint_ids,diagnostic_stub)
        followup_path=get(followup_result,:report_path,nothing)
        followup_path isa AbstractString && isfile(followup_path) ||
            error("follow-up Bphi consumer did not save its result-first raw report")
        println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=followup_bphi_action_consumer elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
        println("G2_FOLLOWUP_BPHI_ACTION_DIRECT_RESULT status=",followup_result.status,
            " report_path=",followup_path," formal_acceptance=false topology=hold");flush(stdout)
        return followup_result
    end
    next_kkt_resume_flag=get(ENV,"FUSION_G2_RESUME_SAVED_TRIAL_NEXT_KKT","0")
    next_kkt_resume_flag in ("0","1") || error("saved next-trial KKT direct-resume flag must be 0 or 1")
    if next_kkt_resume_flag=="1"
        get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ONLY","0")=="1" &&
            get(ENV,"FUSION_G2_REUSE_SAVED_GS_U_MINUS_RAW","0")=="1" &&
            get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0") in ("0","1") ||
            error("next-trial KKT direct route requires the saved-minus entry and existing consumer ABI flag")
        stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=next_trial_kkt_consumer");flush(stdout)
        consumer_result=_g2_resume_saved_trial_next_kkt_consumer_v1(S,F,component,trace,provider,
            composed,regional,model,candidate_scaling,scale_contract,run_leaf)
        consumer_status=get(consumer_result,:status,:unknown)
        report_path=joinpath(run_leaf,"result_data","g2_global_diagnostic",
            "saved_trial_next_kkt_nonlinear_trial_report_v1.jls")
        isfile(report_path) || error("next-trial helper did not save its result-first report")
        if get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")=="1"
            consumer_status===:abi_preflight ||
                error("direct next-KKT route did not complete the requested production consumer ABI preflight")
        end
        println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=next_trial_kkt_consumer elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
        println("G2_SAVED_MINUS_NEXT_KKT_DIRECT_RESULT status=",consumer_status,
            " report_path=",report_path," formal_acceptance=false");flush(stdout)
        return merge(consumer_result,(report_path=report_path,))
    end
    stage_started_ns=time_ns();println("G2_SAVED_MINUS_DIRECT_STAGE_BEGIN stage=saved_continuation");flush(stdout)
    result=_g2_resume_saved_gs_u_plus_trial_v1(S,F,component,trace,provider,composed,
        regional,model,candidate_scaling,scale_contract,run_leaf)
    println("G2_SAVED_MINUS_DIRECT_STAGE_END stage=saved_continuation elapsed_ns=",time_ns()-stage_started_ns);flush(stdout)
    println("G2_SAVED_MINUS_TRIAL_DIRECT_RESULT status=",result.status,
        " report_path=",result.report_path," formal_acceptance=false");flush(stdout)
    result
end

function test_actual_freegs_full_support_profile(F,context,artifacts,trace,region)
@testset "actual full-native F and core-pressure profile and oriented outer traces" begin
    # Finish and release the measured large fixed-phase native frame before
    # constructing the variable-profile component in the same original testset.
    phase_ref=Base.invokelatest(_test_actual_freegs_full_support_fixed_phase,
        F,Ref{Any}(context),artifacts,trace,region)
    phase=phase_ref[]
    Base.invokelatest(test_actual_freegs_profile_normalization,F,context,artifacts,trace,
        phase.fixed,phase.base,region,phase.holdout_node,phase.holdout_delta,phase.holdout_sample)
end
end

Base.@noinline Base.@nospecializeinfer function test_actual_freegs_LCFS_flux_map(F,component,trace,region)
    Base.@nospecialize component
@testset "Actual full-native state to fixed LCFS flux and Bpol" begin
    # Compare the complete CSC matrices without materializing A-B, which can
    # temporarily duplicate a full field/normal Jacobian at this grid size.
    function sparse_max_abs_difference(A,B)
        size(A)==size(B) || throw(ArgumentError("sparse comparison dimensions differ"))
        error=0.0
        for column in axes(A,2)
            ia=A.colptr[column];ib=B.colptr[column]
            enda=A.colptr[column+1]-1;endb=B.colptr[column+1]-1
            while ia<=enda && ib<=endb
                ra=A.rowval[ia];rb=B.rowval[ib]
                if ra==rb
                    error=max(error,abs(A.nzval[ia]-B.nzval[ib]));ia+=1;ib+=1
                elseif ra<rb
                    error=max(error,abs(A.nzval[ia]));ia+=1
                else
                    error=max(error,abs(B.nzval[ib]));ib+=1
                end
            end
            while ia<=enda
                error=max(error,abs(A.nzval[ia]));ia+=1
            end
            while ib<=endb
                error=max(error,abs(B.nzval[ib]));ib+=1
            end
        end
        error
    end
    x=component.initial_state;n=length(component.core_mask);d=trace.data
    actual=component.lcfs_flux_trace(x)
    if component.gs_status!==:present
        @test actual.status===:typed_absent
        @test actual.reason===:absolute_native_plasma_flux_unavailable
        return
    end
    @test actual.status===:evaluated_fixed_LCFS_absolute_flux_and_poloidal_field
    @test actual.candidate_hash==component.candidate_hash
    @test actual.upstream_output_hash==component.upstream_output_hash
    @test actual.trace_hash==trace.trace_hash
    @test actual.coordinates_RZ_m==collect(d.coordinates_m) && actual.normals_RZ==collect(d.normals_RZ)
    @test size(actual.field_jacobian)==(192,length(x)) && size(actual.jacobian)==(64,length(x))
    @test actual.geometry_psi_scope===:total_native_grid_spline_at_fixed_accepted_LCFS
    @test actual.Bpol_scope===:absolute_plasma_spline_plus_fixed_PF_field
    @test actual.pressure_trace_state_map===:typed_absent && actual.toroidal_field_trace_state_map===:typed_absent
    @test actual.current_normal_trace===:typed_absent && actual.extra_solver_rows==0
    @test actual.missing_closures==component.missing_closures && !actual.global_topology_closed
    expected=[v for a in 1:64 for v in (
        d.profile_law.psi_axis_wb_per_rad+d.psi_normalized[a]*(d.profile_law.psi_boundary_wb_per_rad-d.profile_law.psi_axis_wb_per_rad),
        d.initial_state[4a-2],d.initial_state[4a])]
    source_scale=max(1.0,maximum(abs,expected),
        F.opnorm(actual.field_jacobian,Inf)*maximum(abs,x[4:4:4n]))
    source_error=maximum(abs,actual.fields-expected)
    @test source_error<=2048eps(Float64)*source_scale
    expected_normal=F._ccp_axisymmetric_lcfs_trace_oracle(collect(d.initial_state),d.normals_RZ,
        d.profile_boundary_pressure_Pa,d.mu0_N_per_A2).residual[1:2:end]
    @test maximum(abs,actual.residual-expected_normal)<=2048eps(Float64)*source_scale
    independent=component.lcfs_flux_trace_oracle(x)
    field_j_error=sparse_max_abs_difference(actual.field_jacobian,independent.field_jacobian)
    normal_j_error=sparse_max_abs_difference(actual.jacobian,independent.jacobian)
    @test field_j_error<=256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(independent.field_jacobian)))
    @test normal_j_error<=256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(independent.jacobian)))
    @test maximum(abs,actual.fields-independent.fields)<=2048eps(Float64)*source_scale
    independent=nothing
    # A real nonzero exterior psi perturbation changes the global plasma spline
    # without requiring absent exterior pressure or violating the frozen core.
    point=d.coordinates_m[1];outside=findall(!,component.core_mask)
    distances=[sum(abs2,component.coordinates_RZ_m[k].-point) for k in outside]
    k=outside[argmin(distances)];step=1e-6
    changed=copy(x);changed[4k]+=step
    moved=component.lcfs_flux_trace(changed)
    moved_fields=moved.fields;moved_residual=moved.residual;moved=nothing
    @test maximum(abs,moved_fields-actual.fields)>1e-10
    @test maximum(abs,moved_fields-actual.fields-step.*Vector(actual.field_jacobian[:,4k]))<=4096eps(Float64)*source_scale
    @test maximum(abs,moved_residual-actual.residual-step.*Vector(actual.jacobian[:,4k]))<=4096eps(Float64)*source_scale
    independent=component.lcfs_flux_trace_oracle(changed)
    @test maximum(abs,moved_fields-independent.fields)<=2048eps(Float64)*source_scale
    @test maximum(abs,moved_residual-independent.residual)<=2048eps(Float64)*source_scale
    independent=nothing
    # The trace is governed by source plasma flux, not arbitrary interpolation
    # of the separate nodal Br/Bz unknowns away from their flux equations.
    off_manifold=copy(x);off_manifold[4k-3]+=1e-4
    observed=component.lcfs_flux_trace(off_manifold)
    @test observed.fields==actual.fields && observed.residual==actual.residual
    observed=nothing
    R=collect(d.current_support.R_m);Z=collect(d.current_support.Z_m)
    for (axis,points) in ((R,first.(d.coordinates_m)),(Z,last.(d.coordinates_m)))
        D=F._ccp_native_spline_derivative(axis)
        w=F._ccp_native_spline_point_weights(axis,D,points)
        H=F._ccp_native_spline_point_hessian_weights(axis,D,points)
        o=F._ccp_native_spline_point_weights_oracle(axis,points)
        for power in 0:3
            exact=collect(points).^power
            exact_derivative=power==0 ? zeros(64) : power.*collect(points).^(power-1)
            exact_second=power<2 ? zeros(64) : power*(power-1).*collect(points).^(power-2)
            @test maximum(abs,w.value*(axis.^power)-exact)<=2048eps(Float64)*max(1.0,maximum(abs,exact))
            @test maximum(abs,w.derivative*(axis.^power)-exact_derivative)<=2048eps(Float64)*max(1.0,F.opnorm(w.derivative,Inf)*maximum(abs,axis.^power))
            @test maximum(abs,H*(axis.^power)-exact_second)<=4096eps(Float64)*max(1.0,maximum(abs,exact_second))
            @test maximum(abs,w.value-o.value)<=256eps(Float64)*max(1.0,maximum(abs,o.value))
        end
        @test_throws ArgumentError F._ccp_native_spline_point_weights(axis,D,[first(axis)-1.0])
        @test_throws ArgumentError F._ccp_native_spline_point_weights(reverse(axis),D,points)
        @test_throws ArgumentError F._ccp_native_spline_point_weights(axis,D[1:end-1,:],points)
    end
    bad=copy(x);bad[4k]=NaN
    @test_throws ArgumentError component.lcfs_flux_trace(bad)
    @test_throws ArgumentError component.lcfs_flux_trace(x[1:end-1])
    println("FREEGS_NATIVE_LCFS_FLUX_MAP_JSON="*F.canonical_json((
        candidate_hash=component.candidate_hash,upstream_output_hash=component.upstream_output_hash,
        points=64,full_native_nodes=n,dofs=length(x),field_jacobian_size=size(actual.field_jacobian),
        source_max_error=source_error,source_roundoff_bound=2048eps(Float64)*source_scale,
        independent_field_jacobian_error=field_j_error,independent_normal_jacobian_error=normal_j_error,
        changed_native_id=k,changed_psi=step,nonzero_field_response=maximum(abs,moved_fields-actual.fields),
        normal_B_residual_max=maximum(abs,actual.residual),fixed_accepted_LCFS=true,
        fixed_PF=true,pressure_trace_state_map=:typed_absent,current_normal_trace=:typed_absent,
        extra_solver_rows=0,all_five_closures_still_missing=true,global_topology_closed=false)))
end
end

Base.@noinline Base.@nospecializeinfer function test_actual_freegs_core_current_trace(F,component,trace,region;with_lcfs_F_curl_probe=false)
    Base.@nospecialize component
@testset "actual core current vector and existing regional MHD gather" begin
    started=time();println("FREEGS_CORE_CURRENT_BEGIN variable=",component.vary_profile_coefficients);flush(stdout)
    x=component.initial_state;law=component.profile_law
    nr,nz=component.grid_shape
    ids=findall(component.core_mask);ndof=length(x)
    current=component.core_current_trace(x;region=region)
    if with_lcfs_F_curl_probe
        # `current` above is the already-computed default call; reuse it to verify
        # that the expensive full-native curl remains explicitly opt-in.
        @test current.full_native_state_curl_current.status===:typed_absent
        @test current.full_native_state_curl_current.reason===:explicit_full_curl_opt_in_required
        full_curl_current=component.core_current_trace(x;region=region,with_full_curl=true,with_full_curl_jacobian=true)
        # Preserve same-state operator evidence even if a later LCFS FD assertion fails.
        curl_now=full_curl_current.full_native_state_curl_current
        profile_now=curl_now.candidate_GS4_profile_Jphi_core_A_per_m2
        source_now=curl_now.accepted_GS4_source_Jphi_core_A_per_m2
        metric_now(v)=(max_abs_A_per_m2=maximum(abs,v;init=0.0),
            rms_A_per_m2=sqrt(sum(abs2,v)/length(v)))
        println("FREEGS_CORE_CURRENT_NUMERIC_PRE_FD_JSON="*F.canonical_json((
            same_candidate_state=true,native_nodes=length(curl_now.native_ids),
            curl_minus_candidate_GS4_profile_Jphi=metric_now(curl_now.curl_minus_candidate_profile_Jphi_A_per_m2),
            curl_minus_accepted_GS4_source_Jphi=metric_now(curl_now.curl_minus_accepted_GS4_source_Jphi_A_per_m2),
            candidate_profile_vs_accepted_source=metric_now(profile_now.-source_now),
            ip_comparison=curl_now.ip_comparison,
            holdout_status=current.mhd_Jphi_holdout.status,
            global_topology_closed=false,physical_validation=false)));flush(stdout)
    end
    if with_lcfs_F_curl_probe
        independent_Ftrace=component.lcfs_state_F_curl_trace(x;with_jacobian=true)
        @test independent_Ftrace.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
        @test independent_Ftrace.field_representation===:profile_of_continuous_psi_plus_spline_constitutive_residual_divided_by_R && independent_Ftrace.profile_law_change===:none_existing_profile_law_unchanged
        @test independent_Ftrace.common_field_scope===:accepted_plasma_domain_only
        @test independent_Ftrace.outside_domain_profile_relation===:LCFS_unclamped_P_native_profile_clamped_to_Fvac
        @test independent_Ftrace.distinct_from==(:direct_Bphi_tensor_spline,:R_times_tensor_spline_of_Bphi,
            :canonical_P_of_psi_plus_Q1D)
        @test independent_Ftrace.current_topology===:ideal_axisymmetric_periodic_lcfs_no_normal_current
        @test independent_Ftrace.return_current_path===:periodic_toroidal_plasma_with_zero_normal_current_at_LCFS
        @test length(independent_Ftrace.F_B_T_m)==64 && length(independent_Ftrace.Jn_A_per_m2)==64
        @test maximum(abs.(independent_Ftrace.Bphi_lcfs_T .-
            independent_Ftrace.F_B_T_m./first.(independent_Ftrace.coordinates_RZ_m)))<=
            32eps(Float64)*max(1.0,maximum(abs,independent_Ftrace.Bphi_lcfs_T))
        @test size(independent_Ftrace.jacobian)==(64,ndof)
        @test size(independent_Ftrace.cut_segment_jacobian)==(64,ndof)
        @test independent_Ftrace.solver_rows_added==0 && !independent_Ftrace.global_topology_closed
        @test independent_Ftrace.closure_evidence_created===false
        @test independent_Ftrace.physical_validation===false
        @test independent_Ftrace.independent_return_current_evidence===false
        @test independent_Ftrace.compatible_divergence_oracle_max_abs>=0
        @test independent_Ftrace.nodal_operator_consistency.status===:legacy_nodal_spline_only
        @test independent_Ftrace.nodal_operator_consistency.diagnostic_scope===
            :raw_Fnodes_tensor_spline_interpolation_not_lift_verification
        ncons=independent_Ftrace.nodal_operator_consistency
        @test ncons.max_F_error_T_m<=ncons.max_F_bound_T_m
        @test ncons.max_dR_error_T<=ncons.max_dR_bound_T
        @test ncons.max_dZ_error_T<=ncons.max_dZ_bound_T
        @test length(independent_Ftrace.cut_segment_outward_current_A)==64
        @test abs(independent_Ftrace.cut_flux_sum_A)<=
            512eps(Float64)*max(1.0,maximum(abs,independent_Ftrace.cut_segment_outward_current_A))
        # The public composite result exposes the already-computed canonical
        # current Jn on this same 69,445-DOF state; no canonical Jacobian is built.
        canonical_profile_trace=component.lcfs_profile_current_trace(x;
            dynamic_geometry=true,with_jacobian=false)
        @test canonical_profile_trace.status===:evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi
        @test canonical_profile_trace.current_normal_trace===:evaluated_dynamic_geometry_holdout
        @test canonical_profile_trace.field_order===(:profile_pressure_Pa,:Bphi_T,
            :JR_A_per_m2,:JZ_A_per_m2,:Jn_A_per_m2)
        @test size(canonical_profile_trace.fields)==(64,5)
        @test length(canonical_profile_trace.residual)==192
        @test length(canonical_profile_trace.canonical_state_current_normal_A_per_m2)==64
        @test canonical_profile_trace.canonical_state_current_representation===
            :shared_profile_P_total_psi_plus_tensor_spline_D_over_R
        canonical_dynamic_geometry=canonical_profile_trace.dynamic_geometry
        same_lcfs_coordinates=canonical_dynamic_geometry.coordinates_RZ_m==
            independent_Ftrace.dynamic_geometry.coordinates_RZ_m
        same_lcfs_normals=canonical_dynamic_geometry.normals_RZ==
            independent_Ftrace.dynamic_geometry.normals_RZ
        same_lcfs_surface_weights=canonical_dynamic_geometry.surface_quadrature_m2==
            independent_Ftrace.dynamic_geometry.surface_quadrature_m2
        @test same_lcfs_coordinates && same_lcfs_normals && same_lcfs_surface_weights
        @test canonical_profile_trace.candidate_hash==independent_Ftrace.candidate_hash
        @test canonical_profile_trace.context_hash==independent_Ftrace.context_hash
        @test canonical_profile_trace.upstream_output_hash==independent_Ftrace.upstream_output_hash
        canonical_current_normal=collect(canonical_profile_trace.canonical_state_current_normal_A_per_m2)
        legacy_composite_fields_Jn=collect(canonical_profile_trace.fields[:,5])
        independent_F_Jn=collect(independent_Ftrace.Jn_A_per_m2)
        canonical_vs_F_B_Jn=independent_F_Jn.-canonical_current_normal
        lcfs_Jn_metric=v->(max_abs_A_per_m2=maximum(abs,v;init=0.0),
            rms_A_per_m2=sqrt(sum(abs2,v)/length(v)))
        same_state_lcfs_current_comparison=(
            state_columns=ndof,state_identity=:component_initial_state,
            canonical_trace=canonical_profile_trace.status,
            identity_match=(candidate_hash=canonical_profile_trace.candidate_hash==independent_Ftrace.candidate_hash,
                context_hash=canonical_profile_trace.context_hash==independent_Ftrace.context_hash,
                upstream_output_hash=canonical_profile_trace.upstream_output_hash==independent_Ftrace.upstream_output_hash),
            canonical_current_representation=canonical_profile_trace.canonical_state_current_representation,
            canonical_current_normal=lcfs_Jn_metric(canonical_current_normal),
            canonical_and_independent_F_B_current_comparison=:same_shared_lift_evaluator_not_independent,
            canonical_vs_F_B_Jn_zero_evidence=false,
            shared_lift_fields_Jn_representation=:same_shared_lift_evaluator,
            legacy_composite_fields_Jn=lcfs_Jn_metric(legacy_composite_fields_Jn),
            independent_F_B_trace=independent_Ftrace.field_representation,
            independent_F_B_Jn=lcfs_Jn_metric(independent_F_Jn),
            F_B_minus_canonical_Jn=lcfs_Jn_metric(canonical_vs_F_B_Jn),
            F_B_minus_canonical_Jn_A_per_m2=Tuple(canonical_vs_F_B_Jn),
            geometry_match=(coordinates=same_lcfs_coordinates,normals=same_lcfs_normals,
                surface_quadrature=same_lcfs_surface_weights),
            physical_budget=:unknown_not_configured,
            physical_no_normal_current_acceptance=:typed_absent,
            physical_validation=false,solver_rows_added=0,global_topology_closed=false)
        println("CURRENT_CANONICAL_VS_F_B_JN="*F.canonical_json(same_state_lcfs_current_comparison));flush(stdout)
        # Capture primal values before selected-column FD evaluation/gates.
        println("FREEGS_LCFS_STATE_F_CURL_NUMERIC_PRE_FD_JSON="*F.canonical_json((
            same_candidate_state=true,field_representation=independent_Ftrace.field_representation,
            Jn_max_A_per_m2=maximum(abs,independent_F_Jn),
            Jn_rms_A_per_m2=sqrt(sum(abs2,independent_F_Jn)/length(independent_F_Jn)),
            cut_segment_current_A=Tuple(independent_Ftrace.cut_segment_outward_current_A),
            cut_flux_sum_A=independent_Ftrace.cut_flux_sum_A,
            F_B_minus_canonical_Jn=same_state_lcfs_current_comparison.F_B_minus_canonical_Jn,
            geometry_match=same_state_lcfs_current_comparison.geometry_match,
            FD_credit=false,global_topology_closed=false,physical_validation=false)));flush(stdout)
        # Select the strongest Bphi derivative and the strongest geometry-sensitive
        # psi derivative only when both h/h2 pairs remain in the same mask, ray,
        # and native-cell branches. Unavailable safe steps are typed absent, not credit.
        geo0=independent_Ftrace.dynamic_geometry
        Raxis=component.lcfs_dynamic_geometry_data.Raxis;Zaxis=component.lcfs_dynamic_geometry_data.Zaxis
        nr,nz=component.grid_shape;n=length(component.core_mask)
        function native_cell_signature(g)
            cells=NTuple{2,Int}[]
            for (R,Z) in g.coordinates_RZ_m
                i=searchsortedlast(Raxis,R);j=searchsortedlast(Zaxis,Z)
                1<=i<nr && 1<=j<nz || return nothing
                tolR=128eps(Float64)*max(1.0,abs(R),abs(Raxis[i]),abs(Raxis[i+1]))
                tolZ=128eps(Float64)*max(1.0,abs(Z),abs(Zaxis[j]),abs(Zaxis[j+1]))
                min(R-Raxis[i],Raxis[i+1]-R)>tolR && min(Z-Zaxis[j],Zaxis[j+1]-Z)>tolZ || return nothing
                push!(cells,(i,j))
            end
            Tuple(cells)
        end
        base_cells=native_cell_signature(geo0)
        function same_branch(t)
            t.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl &&
                t.dynamic_geometry.mask_event===:unchanged &&
                t.dynamic_geometry.first_outward_crossing_signature===geo0.first_outward_crossing_signature &&
                native_cell_signature(t.dynamic_geometry)==base_cells
        end
        @test base_cells!==nothing
        bphi_columns=[4k-2 for k in 1:n]
        bphi_scores=[sum(abs2,independent_Ftrace.jacobian[:,col]) for col in bphi_columns]
        bphi_col=0;bphi_step=0.0
        for idx in sortperm(bphi_scores;rev=true)
            col=bphi_columns[idx];score=bphi_scores[idx]
            score>0.0 || break
            step=min(1e-4*max(abs(x[col]),1.0),0.125*abs(x[col]))
            if isfinite(step) && step>128eps(Float64)*max(abs(x[col]),1.0)
                bphi_col=col;bphi_step=step;break
            end
        end
        geometry_scores=[sum(abs2,geo0.coordinate_jacobian[:,k]) for k in 1:n]
        margins=abs.(geo0.candidate_total_psi_Wb_per_rad.-geo0.psi_boundary_Wb_per_rad)
        geometry_col=0;geometry_step=0.0;geometry_safe=(cell=0.0,mask=0.0,motion=0.0)
        profile_span=abs(component.profile_law.psi_axis_wb_per_rad-component.profile_law.psi_boundary_wb_per_rad)
        for native in (base_cells===nothing ? Int[] : sortperm(geometry_scores;rev=true))
            geometry_scores[native]>0.0 || break
            col=4native;step=(1e-4/128)*max(profile_span,abs(x[col]))
            boundary_tangent=geo0.boundary_flux_jacobian[native]
            mask_bound=Inf
            for i in 1:n
                tangent=(i==native ? 1.0 : 0.0)-boundary_tangent
                iszero(tangent) || (mask_bound=min(mask_bound,margins[i]/abs(tangent)))
            end
            cell_bound=Inf;motion=0.0
            for a in 1:64
                i,j=base_cells[a];R,Z=geo0.coordinates_RZ_m[a]
                dR=geo0.coordinate_jacobian[2a-1,native];dZ=geo0.coordinate_jacobian[2a,native]
                motion=max(motion,abs(dR),abs(dZ))
                iszero(dR) || (cell_bound=min(cell_bound,min(R-Raxis[i],Raxis[i+1]-R)/abs(dR)))
                iszero(dZ) || (cell_bound=min(cell_bound,min(Z-Zaxis[j],Zaxis[j+1]-Z)/abs(dZ)))
            end
            safe_step=min(step,0.25cell_bound,0.25mask_bound,motion>0 ? 1e-7/motion : Inf)
            scale=max(abs(x[col]),profile_span,1e-12)
            if isfinite(safe_step) && safe_step>128eps(Float64)*scale
                geometry_col=col;geometry_step=safe_step
                geometry_safe=(cell=cell_bound,mask=mask_bound,motion=motion);break
            end
        end
        fd_records=NamedTuple[]
        function observed_geometry_residual_equivalent(sample)
            g=sample.geometry
            g===nothing && return (status=:typed_absent,reason=:dynamic_geometry_not_returned,
                step=sample.step,side=sample.side,available_trace_fields=sample.available_trace_fields)
            required=(:surface_psi_Wb_per_rad,:psi_boundary_Wb_per_rad,
                :surface_gradient_RZ_Wb_per_rad_m,:first_outward_crossing_signature)
            available=Tuple(propertynames(g))
            missing=Tuple(k for k in required if !hasproperty(g,k))
            isempty(missing) || return (status=:typed_absent,reason=:required_geometry_field_missing,
                step=sample.step,side=sample.side,available_geometry_fields=available,missing_fields=missing)
            npoint=length(g.surface_psi_Wb_per_rad)
            npoint==64 && length(g.surface_gradient_RZ_Wb_per_rad_m)==npoint &&
                length(g.first_outward_crossing_signature)==npoint ||
                return (status=:typed_absent,reason=:geometry_ray_field_lengths_differ,
                    step=sample.step,side=sample.side,available_geometry_fields=available,
                    surface_psi_count=npoint,gradient_count=length(g.surface_gradient_RZ_Wb_per_rad_m),
                    ray_signature_count=length(g.first_outward_crossing_signature))
            psi_residual=Float64[];coordinate_residual=Float64[];ray_gradient=Float64[]
            for a in 1:npoint
                theta=g.first_outward_crossing_signature[a].theta_rad
                gradient=g.surface_gradient_RZ_Wb_per_rad_m[a]
                ray=(sin(theta),cos(theta)) # same (R,Z) ray definition as the geometry producer
                delta=Float64(g.surface_psi_Wb_per_rad[a]-g.psi_boundary_Wb_per_rad)
                directional=Float64(gradient[1]*ray[1]+gradient[2]*ray[2])
                all(isfinite,(theta,gradient[1],gradient[2],delta,directional)) ||
                    return (status=:typed_absent,reason=:nonfinite_geometry_residual_operands,
                        step=sample.step,side=sample.side,ray=a,available_geometry_fields=available)
                push!(psi_residual,abs(delta));push!(ray_gradient,abs(directional))
                if !iszero(directional)
                    push!(coordinate_residual,abs(delta)/abs(directional))
                end
            end
            (status=length(coordinate_residual)==npoint ? :observed_residual_equivalent_coordinate : :partial,
                definition=:abs_surface_psi_minus_boundary_psi_div_abs_surface_gradpsi_dot_first_outward_ray,
                interpretation=:observed_root_residual_equivalent_coordinate_not_strict_error_bound,
                step=sample.step,side=sample.side,ray_count=npoint,
                psi_residual_max_Wb_per_rad=maximum(psi_residual),
                psi_residual_rms_Wb_per_rad=sqrt(sum(abs2,psi_residual)/npoint),
                ray_directional_gradient_min_Wb_per_rad_m=minimum(ray_gradient),
                ray_directional_gradient_max_Wb_per_rad_m=maximum(ray_gradient),
                coordinate_available_count=length(coordinate_residual),
                coordinate_residual_equivalent_max_m=isempty(coordinate_residual) ? nothing : maximum(coordinate_residual),
                coordinate_residual_equivalent_rms_m=isempty(coordinate_residual) ? nothing :
                    sqrt(sum(abs2,coordinate_residual)/length(coordinate_residual)),
                available_geometry_fields=available)
        end
        function report_geometry_residuals(summaries,reason)
            # Inputs are scalar-only summaries; never retain dynamic geometry/Jacobian payloads.
            summaries=Tuple(summaries)
            println("FREEGS_MOVING_PSI_GEOMETRY_RESIDUAL_EQUIVALENT="*F.canonical_json((
                status=:observed_diagnostic_only,reason=reason,samples=summaries,
                acceptance_threshold=:none,FD_credit=false)));flush(stdout)
        end
        function check_pair(col,h,kind)
            if !(isfinite(h) && h/2>128eps(Float64)*max(abs(x[col]),1e-12))
                push!(fd_records,(status=:typed_absent,reason=:no_safe_representable_step,column=col,kind=kind));return
            end
            derivatives=Vector{Vector{Float64}}(undef,2);cut_derivatives=similar(derivatives)
            geometry_samples=kind===:moving_psi_state ? Any[observed_geometry_residual_equivalent(
                (step=0.0,side=:base,geometry=geo0))] : Any[]
            for (q,step) in enumerate((h,h/2))
                xp=copy(x);xm=copy(x);xp[col]+=step;xm[col]-=step
                rp=component.lcfs_state_F_curl_trace(xp;with_jacobian=false)
                rm=component.lcfs_state_F_curl_trace(xm;with_jacobian=false)
                if kind===:moving_psi_state
                    for (side,t) in ((:plus,rp),(:minus,rm))
                        if hasproperty(t,:dynamic_geometry)
                            push!(geometry_samples,observed_geometry_residual_equivalent(
                                (step=step,side=side,geometry=t.dynamic_geometry)))
                        else
                            push!(geometry_samples,observed_geometry_residual_equivalent(
                                (step=step,side=side,geometry=nothing,
                                    available_trace_fields=Tuple(propertynames(t)))))
                        end
                    end
                end
                if !same_branch(rp) || !same_branch(rm)
                    kind===:moving_psi_state && report_geometry_residuals(geometry_samples,:branch_gate_failed)
                    push!(fd_records,(status=:typed_absent,reason=:mask_first_crossing_or_cell_signature_changed,
                        column=col,kind=kind,step=step));return
                end
                derivatives[q]=(rp.Jn_A_per_m2-rm.Jn_A_per_m2)./(2step)
                cut_derivatives[q]=(rp.cut_segment_outward_current_A-rm.cut_segment_outward_current_A)./(2step)
            end
            kind===:moving_psi_state && report_geometry_residuals(geometry_samples,:same_branch_h_h2_samples)
            analytic=Vector(independent_Ftrace.jacobian[:,col])
            cut_analytic=Vector(independent_Ftrace.cut_segment_jacobian[:,col])
            fd_h=derivatives[1];fd_h2=derivatives[2]
            cut_h=cut_derivatives[1];cut_h2=cut_derivatives[2]
            @test isapprox(fd_h,analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(fd_h2,analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(fd_h,fd_h2;rtol=5e-6,atol=5e-11)
            @test isapprox(cut_h,cut_analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(cut_h2,cut_analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(cut_h,cut_h2;rtol=5e-6,atol=5e-11)
            maxerr(a,b)=maximum(abs,a-b;init=0.0)
            push!(fd_records,(status=:evaluated,column=col,kind=kind,h=h,h_over_2=h/2,
                Jn_defect_h=maxerr(fd_h,analytic),Jn_defect_h2=maxerr(fd_h2,analytic),
                Jn_step_defect=maxerr(fd_h,fd_h2),Jn_scale=max(maximum(abs,fd_h),maximum(abs,analytic)),
                cut_defect_h=maxerr(cut_h,cut_analytic),cut_defect_h2=maxerr(cut_h2,cut_analytic),
                cut_step_defect=maxerr(cut_h,cut_h2),cut_scale=max(maximum(abs,cut_h),maximum(abs,cut_analytic)),
                rtol=5e-6,atol=5e-11,operation_gate=:selected_columns_only))
        end
        bphi_col>0 ? check_pair(bphi_col,bphi_step,:Bphi_state) :
            push!(fd_records,(status=:typed_absent,reason=:no_safe_Bphi_column,kind=:Bphi_state))
        geometry_col>0 ? check_pair(geometry_col,geometry_step,:moving_psi_state) :
            push!(fd_records,(status=:typed_absent,reason=:no_safe_moving_psi_column,kind=:moving_psi_state,
                safety=geometry_safe))
        @test any(record->record.status===:evaluated && record.kind===:Bphi_state,fd_records)
        @test any(record->record.status===:evaluated && record.kind===:moving_psi_state,fd_records)
        println("FREEGS_LCFS_STATE_F_CURL_JSON="*F.canonical_json((
            native_nodes=length(component.core_mask),state_columns=ndof,trace_rows=64,
            field_representation=independent_Ftrace.field_representation,
            state_F_curl_jacobian_nnz=SparseArrays.nnz(independent_Ftrace.jacobian),
            cut_segment_jacobian_nnz=SparseArrays.nnz(independent_Ftrace.cut_segment_jacobian),
            polygon_signed_area_RZ_m2=independent_Ftrace.polygon_signed_area_RZ_m2,
            nodal_operator_consistency=independent_Ftrace.nodal_operator_consistency,
            Bphi_lcfs_representation=:F_B_divided_by_actual_R,
            cut_flux_sum_A=independent_Ftrace.cut_flux_sum_A,
            compatible_divergence_oracle_max_abs=independent_Ftrace.compatible_divergence_oracle_max_abs,
            canonical_vs_independent_F_B=same_state_lcfs_current_comparison,
            selected_fd=fd_records,solver_rows_added=0,global_topology_closed=false,
            closure_evidence_created=false,physical_validation=false)));flush(stdout)
    end
    @test current.native_ids==ids && length(ids)==2879
    @test current.candidate_hash==region.candidate_hash && current.upstream_output_hash==region.upstream_output_hash
    @test current.component_order==(:R,:phi,:Z)
    @test current.row_role===:constitutive_current_observation && current.row_units===:A_per_m2
    @test current.row_scaling===:unscaled_physical_units
    @test current.extra_solver_rows==0 && !current.global_topology_closed
    @test current.current_normal_trace===:typed_absent && current.exterior_current_vector===:typed_absent
    @test current.missing_closures==component.missing_closures
    @test size(current.jacobian)==(3length(ids),ndof)
    face_map=current.poloidal_face_flux
    nRfaces=nr*(nz-1);nZfaces=(nr-1)*nz
    nfaces=nRfaces+nZfaces;ncell=(nr-1)*(nz-1)
    @test face_map.status===:evaluated_axisymmetric_poloidal_current_face_flux
    @test size(face_map.cell_outward_incidence)==(ncell,nfaces)
    @test size(face_map.face_flux_jacobian)==(nfaces,ndof)
    @test length(face_map.cell_flux_divergence_A)==ncell
    @test face_map.face_flux_order===:positive_R_faces_then_positive_Z_faces
    @test face_map.face_flux_jacobian_columns===:full_state_Bphi_native_dofs
    @test face_map.face_flux_definition===:two_pi_integral_RJpol_from_endpoint_delta_F
    @test SparseArrays.nnz(face_map.face_flux_jacobian)==2nfaces

    # Independent endpoint oracle for every oriented face: F_k=R_k*Bphi_k.
    # This validates a discrete flux map, not a new current-topology equation.
    scale=2pi/law.mu0_N_per_A2
    radial=[component.coordinates_RZ_m[k][1] for k in 1:length(component.core_mask)]
    endpoint_F=[radial[k]*x[4k-2] for k in eachindex(radial)]
    expected_face_flux=zeros(nfaces);face_rows=Int[];face_columns=Int[];face_values=Float64[]
    sizehint!(face_rows,2nfaces);sizehint!(face_columns,2nfaces);sizehint!(face_values,2nfaces)
    rface(i,j)=(i-1)*(nz-1)+j
    zface(i,j)=nRfaces+(i-1)*nz+j
    for i in 1:nr,j in 1:nz-1
        row=rface(i,j);a=(i-1)*nz+j;b=a+1
        expected_face_flux[row]=-scale*(endpoint_F[b]-endpoint_F[a])
        push!(face_rows,row);push!(face_columns,4a-2);push!(face_values,scale*radial[a])
        push!(face_rows,row);push!(face_columns,4b-2);push!(face_values,-scale*radial[b])
    end
    for i in 1:nr-1,j in 1:nz
        row=zface(i,j);a=(i-1)*nz+j;b=i*nz+j
        expected_face_flux[row]=scale*(endpoint_F[b]-endpoint_F[a])
        push!(face_rows,row);push!(face_columns,4a-2);push!(face_values,-scale*radial[a])
        push!(face_rows,row);push!(face_columns,4b-2);push!(face_values,scale*radial[b])
    end
    @test maximum(abs,face_map.face_flux_A-expected_face_flux)<=
        64eps(Float64)*max(1.0,maximum(abs,expected_face_flux))
    expected_face_jacobian=SparseArrays.sparse(face_rows,face_columns,face_values,nfaces,ndof)
    face_jacobian_error=face_map.face_flux_jacobian-expected_face_jacobian
    @test maximum(abs,SparseArrays.nonzeros(face_jacobian_error);init=0.0)<=
        256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(expected_face_jacobian);init=0.0))
    @test all(column->mod(column,4)==2,SparseArrays.findnz(face_map.face_flux_jacobian)[2])

    # Independent structured-cell incidence: internal shared faces occur twice with opposite signs.
    # Each outer R/Z boundary face belongs to one cell.
    incidence_rows=Int[];incidence_columns=Int[];incidence_values=Float64[]
    sizehint!(incidence_rows,4ncell);sizehint!(incidence_columns,4ncell);sizehint!(incidence_values,4ncell)
    for i in 1:nr-1,j in 1:nz-1
        row=(i-1)*(nz-1)+j
        for (column,sign) in ((rface(i+1,j),1.0),(rface(i,j),-1.0),
                (zface(i,j+1),1.0),(zface(i,j),-1.0))
            push!(incidence_rows,row);push!(incidence_columns,column);push!(incidence_values,sign)
        end
    end
    expected_incidence=SparseArrays.sparse(incidence_rows,incidence_columns,incidence_values,ncell,nfaces)
    @test face_map.cell_outward_incidence==expected_incidence
    @test SparseArrays.nnz(face_map.cell_outward_incidence)==4ncell
    expected_face_owners=vcat([i==1 || i==nr ? 1.0 : 2.0 for i in 1:nr for _ in 1:nz-1],
        [j==1 || j==nz ? 1.0 : 2.0 for _ in 1:nr-1 for j in 1:nz])
    @test collect(vec(sum(abs.(face_map.cell_outward_incidence);dims=1)))==expected_face_owners

    expected_cell_class=Vector{Symbol}(undef,ncell)
    for i in 1:nr-1,j in 1:nz-1
        row=(i-1)*(nz-1)+j
        nodes=((i-1)*nz+j,(i-1)*nz+j+1,i*nz+j,i*nz+j+1)
        active=count(k->component.core_mask[k],nodes)
        expected_cell_class[row]=active==4 ? :core : active==0 ? :exterior : :mask_cut
    end
    @test face_map.cell_support_class==expected_cell_class
    @test face_map.cell_native_order===:R_then_Z
    @test face_map.mask_cut_cells_are_not_LCFS
    # A near-zero incidence divergence here is only the telescoping endpoint-F identity.
    @test maximum(abs,face_map.cell_flux_divergence_A)<=
        64eps(Float64)*max(1.0,maximum(abs,face_map.face_flux_A))
    @test SparseArrays.nnz(current.jacobian)<=(component.vary_profile_coefficients ? 11 : 7)*length(ids)
    support=trace.data.current_support
    if with_lcfs_F_curl_probe
        full_curl=full_curl_current.full_native_state_curl_current
        n=nz*nr
        @test full_curl.status===:evaluated_full_native_axisymmetric_spline_curl_current
        @test full_curl.native_ids==(1:n) && length(full_curl.current_cylindrical_A_per_m2)==3n
        @test full_curl.component_order==(:R,:phi,:Z) && full_curl.extra_solver_rows==0
        @test !full_curl.global_topology_closed && !full_curl.physical_return_current_claim
        fullJ=full_curl.current_cylindrical_A_per_m2
        curlJ=full_curl.jacobian
        @test length(fullJ)==3n && size(curlJ)==(3n,ndof) && issparse(curlJ)
        @test full_curl.jacobian_row_order===:native_node_major_interleaved_R_phi_Z
        @test full_curl.jacobian_columns===:full_state_Br_Bphi_Bz_psi_profile_v_A_B
        @test full_curl.common_field_scope===:accepted_plasma_domain_only
        @test full_curl.outside_domain_profile_relation===:native_P_clamped_to_Fvac_while_LCFS_P_is_unclamped
        @test full_curl.relation_to_LCFS_canonical_F===:shared_profile_F_lift_only_on_accepted_plasma_domain
        @test full_curl.accepted_source_native_ids==ids
        @test full_curl.accepted_source_native_ids !== ids
        @test length(full_curl.curl_minus_accepted_GS4_source_Jphi_A_per_m2)==length(ids)
        @test length(full_curl.candidate_profile_minus_accepted_GS4_Jphi_A_per_m2)==length(ids)
        @test full_curl.ip_comparison.no_additional_Ip_equation
        @test full_curl.ip_comparison.solver_plasma_Ip_A==support.solver_plasma_current_A
        @test full_curl.ip_comparison.source_reported_trapezoid_A==support.current_integral_trapezoid_A
        @test full_curl.ip_comparison.curl_Jphi_integral_A==sum(
            [support.area_weight_m2[cld(k,nz)][mod1(k,nz)]*fullJ[3k-1] for k in ids])
        # Independent scalar oracle for the lifted F curl at one accepted node and
        # one exterior node. The exterior profile value is explicitly Fvac-clamped.
        Raxis=[component.coordinates_RZ_m[(i-1)*nz+1][1] for i in 1:nr]
        Zaxis=[component.coordinates_RZ_m[j][2] for j in 1:nz]
        Dr=F._ccp_native_spline_derivative(Raxis);Dz=F._ccp_native_spline_derivative(Zaxis)
        native_data=component.lcfs_dynamic_geometry_data
        continuous_model=component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1
        function independent_lift_curl(state,k)
            axis_col,boundary_col=component.dynamic_profile_span ? component.profile_span_columns : (0,0)
            A=component.dynamic_profile_span ? state[axis_col] : law.psi_axis_wb_per_rad
            B=component.dynamic_profile_span ? state[boundary_col] : law.psi_boundary_wb_per_rad
            v=component.vary_profile_coefficients ? state[component.profile_coefficient_columns[2]] :
                law.L_A_per_m2*(1-law.Beta0)
            span=A-B;Rmat=repeat(reshape(Raxis,nr,1),1,nz)
            Pnode=zeros(n);Ppsi=zeros(n);Dnode=zeros(n)
            for qid in 1:n
                if component.core_mask[qid]
                    q=(state[4qid]-B)/span
                    integral=span*q^3/3
                    rad=law.fvac_T_m^2+2law.mu0_N_per_A2*v*law.Raxis_m*integral
                    rad>0 || error("independent lifted-curl oracle left positive F branch")
                    Pnode[qid]=sqrt(rad)
                    Ppsi[qid]=law.mu0_N_per_A2*v*law.Raxis_m*q^2/Pnode[qid]
                else
                    Pnode[qid]=law.fvac_T_m
                end
                Pnode[qid]>0 || error("independent lifted-curl oracle requires positive native F")
                ir=cld(qid,nz);Pnode[qid]=Pnode[qid]
                Dnode[qid]=Raxis[ir]*state[4qid-2]-Pnode[qid]
            end
            psi_nodes=continuous_model ? F._ccp_full_native_plasma_nodes(state,native_data,
                component.native_field_model_id) :
                Float64[native_data.support_psi[qid]+state[4qid]-native_data.anchor_psi[qid] for qid in 1:n]
            psi_mat=permutedims(reshape(psi_nodes,nz,nr))
            psi_R=Dr*psi_mat;psi_Z=psi_mat*transpose(Dz)
            if continuous_model
                for qid in 1:n
                    ir=cld(qid,nz);jz=mod1(qid,nz)
                    pf=F._ccp_full_native_exact_pf_jet(native_data,Raxis[ir],Zaxis[jz])
                    psi_R[ir,jz]+=pf.gradient[1];psi_Z[ir,jz]+=pf.gradient[2]
                end
            end
            Dmat=permutedims(reshape(Dnode,nz,nr))
            ir=cld(k,nz);jz=mod1(k,nz)
            FR=Ppsi[k]*psi_R[ir,jz]+sum(Dr[ir,l]*Dmat[l,jz] for l in 1:nr)
            FZ=Ppsi[k]*psi_Z[ir,jz]+sum(Dz[jz,l]*Dmat[ir,l] for l in 1:nz)
            Jphi=(sum(Dz[jz,l]*state[4((ir-1)*nz+l)-3] for l in 1:nz)-
                sum(Dr[ir,l]*state[4((l-1)*nz+jz)-1] for l in 1:nr))/law.mu0_N_per_A2
            (JR=-FZ/(law.mu0_N_per_A2*Raxis[ir]),
                Jphi=Jphi,JZ=FR/(law.mu0_N_per_A2*Raxis[ir]),
                native_profile_F=Pnode[k])
        end
        exterior_id=findfirst(!,component.core_mask)
        core_probe=ids[argmax([min((x[4k]-law.psi_boundary_wb_per_rad)/
            (law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad),
            1-(x[4k]-law.psi_boundary_wb_per_rad)/
            (law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)) for k in ids])]
        for k in (core_probe,exterior_id)
            expected=independent_lift_curl(x,k)
            @test isapprox(fullJ[3k-2],expected.JR;rtol=5e-12,atol=5e-11)
            @test isapprox(fullJ[3k-1],expected.Jphi;rtol=5e-12,atol=5e-11)
            @test isapprox(fullJ[3k],expected.JZ;rtol=5e-12,atol=5e-11)
            @test component.core_mask[k] || expected.native_profile_F==law.fvac_T_m
        end
        # Independent state-column FD covers Bphi, psi, v, and dynamic span A/B.
        outside_id=exterior_id
        selected_columns=Int[4core_probe-3,4core_probe-2,4core_probe-1,
            4outside_id-3,4outside_id-2,4outside_id-1,4core_probe,4outside_id]
        component.vary_profile_coefficients && push!(selected_columns,component.profile_coefficient_columns[2])
        component.dynamic_profile_span && append!(selected_columns,component.profile_span_columns)
        fd_probe_records=NamedTuple[]
        for column in unique(selected_columns)
            h=eps(Float64)^(1/3)*max(1.0,abs(x[column]))
            fd_values=Vector{Vector{Float64}}(undef,2)
            for (level,step) in enumerate((h,h/2))
                xp=copy(x);xm=copy(x);xp[column]+=step;xm[column]-=step
                yp_result=component.core_current_trace(xp;with_full_curl=true,with_full_curl_jacobian=false)
                ym_result=component.core_current_trace(xm;with_full_curl=true,with_full_curl_jacobian=false)
                yp_result.full_native_state_curl_current.jacobian===:typed_absent || error("unexpected FD Jacobian allocation")
                ym_result.full_native_state_curl_current.jacobian===:typed_absent || error("unexpected FD Jacobian allocation")
                yp=yp_result.full_native_state_curl_current.current_cylindrical_A_per_m2
                ym=ym_result.full_native_state_curl_current.current_cylindrical_A_per_m2
                fd=(yp.-ym)./(2step);analytic=Vector(curlJ[:,column])
                scale=max(maximum(abs,fd),maximum(abs,analytic),1e-12)
                @test maximum(abs,fd.-analytic)<=5e-6*scale+5e-11
                fd_values[level]=fd
            end
            scale=max(maximum(abs,fd_values[1]),maximum(abs,fd_values[2]),1e-12)
            @test maximum(abs,fd_values[1].-fd_values[2])<=5e-6*scale+5e-11
            push!(fd_probe_records,(state_column=column,h=Float64(h),h_over_2=Float64(h/2),
                max_abs_defect_h=maximum(abs,fd_values[1].-curlJ[:,column]),
                max_abs_defect_h_over_2=maximum(abs,fd_values[2].-curlJ[:,column]),
                relative_fd_tolerance=5e-6,absolute_fd_tolerance=5e-11))
        end
    end
        actual_phi=[support.Jphi_A_per_m2[cld(k,nz)][mod1(k,nz)] for k in ids]
        @test maximum(abs,current.current_cylindrical_A_m2[2:3:end]-actual_phi)<=
            512eps(Float64)*max(1.0,maximum(abs,actual_phi))
        function independent_current_oracle(state)
            rows=Int[];columns=Int[];values=Float64[]
            for (j,k) in enumerate(ids)
                R=component.coordinates_RZ_m[k][1]
                coefficients=component.vary_profile_coefficients ? state[collect(component.profile_coefficient_columns)] :
                    [law.L_A_per_m2*law.Beta0,law.L_A_per_m2*(1-law.Beta0)]
                variables=ComplexF64[state[4k-3],state[4k-2],state[4k-1],state[4k],coefficients...]
                cols=[4k-3,4k-2,4k-1,4k]
                component.vary_profile_coefficients && append!(cols,component.profile_coefficient_columns)
                for (field,column) in enumerate(cols)
                    z=copy(variables);z[field]+=1e-30im
                    br,bp,bz,psi,u,v=z
                    pn=(psi-law.psi_axis_wb_per_rad)/(law.psi_boundary_wb_per_rad-law.psi_axis_wb_per_rad)
                    pprime=(u/law.Raxis_m)*(1-pn)^2
                    ffprime=law.mu0_N_per_A2*v*law.Raxis_m*(1-pn)^2
                    field_derivative=ffprime/(R*bp)
                    vector=(field_derivative*br/law.mu0_N_per_A2,
                        R*pprime+ffprime/(law.mu0_N_per_A2*R),field_derivative*bz/law.mu0_N_per_A2)
                    for axis in 1:3
                        value=imag(vector[axis])/1e-30
                        value==0 && continue
                        push!(rows,3(j-1)+axis);push!(columns,column);push!(values,value)
                    end
                end
            end
            SparseArrays.sparse(rows,columns,values,3length(ids),ndof)
        end
        independent=independent_current_oracle(x)
        @test maximum(abs,SparseArrays.nonzeros(current.jacobian-independent);init=0.0)<=
            256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(independent)))
        eligible=[s[1] for s in region.sample_stencils if
            0<(x[4*s[1]]-law.psi_boundary_wb_per_rad)/(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)<1]
        @test !isempty(eligible)
        k=eligible[argmax([abs(x[4node-3])+abs(x[4node-1]) for node in eligible])]
        @test abs(x[4k-3])+abs(x[4k-1])>0
        directions=[4k-3,4k-2,4k-1,4k]
        component.vary_profile_coefficients && append!(directions,component.profile_coefficient_columns)
        for column in directions
            changed=copy(x)
            changed[column]=column==4k ? (x[column]+law.psi_boundary_wb_per_rad)/2 :
                x[column]+0.001max(1.0,abs(x[column]))
            actual=component.core_current_trace(changed)
            @test maximum(abs,actual.current_cylindrical_A_m2-current.current_cylindrical_A_m2)>0
        end
        changed=copy(x);changed[4k]=(x[4k]+law.psi_boundary_wb_per_rad)/2
        changed[4k-3]+=0.001;changed[4k-2]+=0.002;changed[4k-1]-=0.001
        component.vary_profile_coefficients && (changed[collect(component.profile_coefficient_columns)].*=1.001)
        changed_current=component.core_current_trace(changed)
        changed_independent=independent_current_oracle(changed)
        @test maximum(abs,SparseArrays.nonzeros(changed_current.jacobian-changed_independent);init=0.0)<=
            256eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(changed_independent)))
        mapping=component.regional_mhd_dof_map(region)
        gather=mapping.global_dofs
        @test length(gather)==11500 && length(unique(gather))==11500
        @test x[gather]==collect(region.initial_state)
        @test mapping.row_role===:independent_centered_cross_force_and_divB_holdout
        @test mapping.row_scaling===:unscaled_physical_units && mapping.extra_solver_rows==0
        @test !mapping.global_topology_closed && mapping.missing_closures==component.missing_closures
        # Exercise the actual established evaluator and its scalar-expression oracle
        # once, in variable mode; fixed-mode gather/current checks remain above.
        curl_holdout=nothing
        if component.vary_profile_coefficients
            S=F.InHouseCoupledMHDGlobalSolveV1
            callbacks=F.freegs_axisymmetric_mhd_regional_callbacks(region)
            rid=S._callback_identity(callbacks.regional_evaluator);oid=S._callback_identity(callbacks.jacobian_oracle)
            direct_context=(candidate_hash=region.candidate_hash,
                provider_semantic_hash=string(F.canonical_hash(F.semantic_view(region))),
                provider_context_hash=string(F.canonical_hash((rid,oid))),
                jacobian_oracle_hash=string(F.canonical_hash(oid)))
            absent=NamedTuple{component.missing_closures}(ntuple(_->nothing,5))
            initial=callbacks.regional_evaluator(region.region_id,x[gather],absent,direct_context)
            # A real p/B perturbation must change the original force/divB holdout.
            changed[component.pressure_dofs[k]]+=10.0
            block=callbacks.regional_evaluator(region.region_id,changed[gather],absent,direct_context)
            oracle=callbacks.jacobian_oracle(:regional,region.region_id,changed[gather],absent,direct_context)
            @test length(block.residual)==10820 && block.residual!=initial.residual
            @test collect(block.equation_ids)==mapping.regional_equation_ids
            rr,cc,vv=SparseArrays.findnz(block.jacobian)
            scattered=SparseArrays.sparse(rr,gather[cc],vv,length(block.residual),ndof)
            or,oc,ov=SparseArrays.findnz(oracle.jacobian)
            scattered_oracle=SparseArrays.sparse(or,gather[oc],ov,length(block.residual),ndof)
            @test size(scattered)==(10820,69445)
            @test scattered[:,gather]==block.jacobian
            @test SparseArrays.nnz(scattered)<=80length(region.local_stencils)
            @test maximum(abs,SparseArrays.nonzeros(scattered-scattered_oracle);init=0.0)<=
                64eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(scattered)))
            @test all(==(0.0),scattered[:,collect(component.profile_coefficient_columns)])
            center=findfirst(s->s[1]==k,region.sample_stencils)
            local_nodes=region.local_stencils[center]
            local_dofs=[4(node-1)+field for node in local_nodes for field in 1:4]
            points=Tuple(region.coordinates_m[node] for node in local_nodes)
            curl_initial=F._ccp_axisymmetric_mhd_stencil(x[gather[local_dofs]],points,region.mu0_N_per_A2).current_cylindrical_A_m2
            curl_changed=F._ccp_axisymmetric_mhd_stencil(changed[gather[local_dofs]],points,region.mu0_N_per_A2).current_cylindrical_A_m2
            core_row=findfirst(==(k),ids);current_rows=(3core_row-2):(3core_row)
            @test curl_changed!=curl_initial
            curl_holdout=(native_id=k,discretization=:existing_centered_cross_curl,
                initial_curl_A_m2=curl_initial,initial_constitutive_A_m2=current.current_cylindrical_A_m2[current_rows],
                changed_curl_A_m2=curl_changed,changed_constitutive_A_m2=changed_current.current_cylindrical_A_m2[current_rows],
                source_discretization_equivalence_claim=false)
            # Source-bound negatives reuse the same region; no provider reconstruction.
            body=F._ccp_axisymmetric_region_body(region)
            function altered_region(changes)
                altered=merge(body,changes)
                Base.invokelatest(F.FreeGSAxisymmetricMHDRegionV4,F._CCP_AXISYMMETRIC_REGION_TOKEN,
                    values(altered)...,string(F.canonical_hash(altered)))
            end
            @test_throws ArgumentError component.regional_mhd_dof_map(altered_region((candidate_hash=repeat("0",64),)))
            reordered=merge(region.grid_coverage,(node_native_ids=Tuple(reverse(collect(region.grid_coverage.node_native_ids))),))
            @test_throws ArgumentError component.regional_mhd_dof_map(altered_region((grid_coverage=reordered,)))
            unsupported=collect(region.grid_coverage.node_native_ids);unsupported[1]=first(component.exterior_native_ids)
            wrong_support=merge(region.grid_coverage,(node_native_ids=Tuple(unsupported),))
            @test_throws ArgumentError component.regional_mhd_dof_map(altered_region((grid_coverage=wrong_support,)))
        end
        bad=copy(x);bad[4k-2]=0.0
        @test_throws ArgumentError component.core_current_trace(bad)
    current_representation_comparison = if with_lcfs_F_curl_probe
        full_curl=full_curl_current.full_native_state_curl_current
        curl_minus_profile=full_curl.curl_minus_candidate_profile_Jphi_A_per_m2
        curl_minus_source=full_curl.curl_minus_accepted_GS4_source_Jphi_A_per_m2
        metric(v)=(max_abs_A_per_m2=maximum(abs,v;init=0.0),
            rms_A_per_m2=sqrt(sum(abs2,v)/length(v)))
        holdout=current.mhd_Jphi_holdout
        @test holdout.status===:compared_existing_centered_mhd_and_profile_Jphi
        region_minus_native=Float64[holdout.centered_MHD_curl_Jphi_A_m2[j]-
            full_curl.current_cylindrical_A_per_m2[3*holdout.native_center_ids[j]-1]
            for j in eachindex(holdout.native_center_ids)]
        (same_candidate_state=true,
         native_full_curl_vs_regional_centered_MHD_Jphi=metric(region_minus_native),
         native_full_curl_vs_candidate_GS_profile_Jphi=metric(curl_minus_profile),
         native_full_curl_vs_accepted_GS4_Jphi=metric(curl_minus_source),
         regional_centered_MHD_vs_candidate_GS_profile_Jphi=metric(holdout.centered_minus_profile_Jphi_A_m2),
         regional_center_ids=holdout.native_center_ids,
         physical_budget=:unknown_not_configured,physical_acceptance=:not_established)
    else
        nothing
    end
    println("FREEGS_CORE_CURRENT_JSON="*F.canonical_json((
        core_nodes=length(ids),vector_rows=length(current.current_cylindrical_A_m2),
        current_jacobian_nnz=SparseArrays.nnz(current.jacobian),variable_coefficients=component.vary_profile_coefficients,
        gathered_regional_dofs=length(gather),original_force_divB_rows=10820,
        current_curl_holdout=curl_holdout,
        full_native_curl_current=with_lcfs_F_curl_probe ? (
            native_nodes=length(full_curl.native_ids),state_columns=ndof,
            sparse_jacobian_rows=size(full_curl.jacobian,1),
            sparse_jacobian_columns=size(full_curl.jacobian,2),
            sparse_jacobian_nnz=SparseArrays.nnz(full_curl.jacobian),
            relation_to_LCFS_canonical_F=full_curl.relation_to_LCFS_canonical_F,
            curl_minus_candidate_profile_Jphi=(max_abs_A_per_m2=maximum(abs,curl_minus_profile),
                rms_A_per_m2=sqrt(sum(abs2,curl_minus_profile)/length(curl_minus_profile))),
            curl_minus_accepted_GS4_source_Jphi=(max_abs_A_per_m2=maximum(abs,curl_minus_source),
                rms_A_per_m2=sqrt(sum(abs2,curl_minus_source)/length(curl_minus_source))),
            ip_comparison=full_curl.ip_comparison,
            representation_comparison=current_representation_comparison,
            selected_B_column_fd=fd_probe_records,
            maximum_fd_defect_h=maximum(record.max_abs_defect_h for record in fd_probe_records),
            maximum_fd_defect_h_over_2=maximum(record.max_abs_defect_h_over_2 for record in fd_probe_records),
            fd_step_range=(minimum(record.h_over_2 for record in fd_probe_records),
                maximum(record.h for record in fd_probe_records)))
            : nothing,
        source_scope=:fixed_mask_axis_boundary_core_profile_current,extra_solver_rows=0,
        global_topology_closed=false,all_five_closures_still_missing=true,
        face_current_trace=:typed_absent,physical_validation=false)))
    println("FREEGS_CORE_CURRENT_END elapsed_s=",time()-started);flush(stdout)
end
end

Base.@noinline function test_actual_dynamic_lcfs_F_boundary_profile_partial(F,component)
    @test component.dynamic_profile_span===true
    x=component.initial_state;col=component.profile_span_columns[2]
    trace=component.lcfs_state_F_curl_trace(x;with_jacobian=true)
    @test trace.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
    geom=trace.dynamic_geometry;Raxis=component.lcfs_dynamic_geometry_data.Raxis
    Zaxis=component.lcfs_dynamic_geometry_data.Zaxis;nr,nz=component.grid_shape
    function cells(g)
        out=NTuple{2,Int}[]
        for (R,Z) in g.coordinates_RZ_m
            i=searchsortedlast(Raxis,R);j=searchsortedlast(Zaxis,Z)
            1<=i<nr && 1<=j<nz || return nothing
            tolR=128eps(Float64)*max(1.0,abs(R),abs(Raxis[i]),abs(Raxis[i+1]))
            tolZ=128eps(Float64)*max(1.0,abs(Z),abs(Zaxis[j]),abs(Zaxis[j+1]))
            min(R-Raxis[i],Raxis[i+1]-R)>tolR && min(Z-Zaxis[j],Zaxis[j+1]-Z)>tolZ || return nothing
            push!(out,(i,j))
        end
        Tuple(out)
    end
    base_cells=cells(geom)
    span=abs(x[component.profile_span_columns[1]]-x[component.profile_span_columns[2]])
    core_ids=findall(component.core_mask)
    core_endpoint_margin=minimum((abs(x[4k]-x[col]) for k in core_ids);init=Inf)
    h=min(1e-4*max(span,abs(x[col]),1e-12),0.125span,0.25core_endpoint_margin)
    floor=128eps(Float64)*max(1.0,abs(x[col]))
    reports=NamedTuple[]
    if !(isfinite(h) && h/2>floor && base_cells!==nothing)
        push!(reports,(status=:typed_absent,reason=:no_safe_representable_boundary_endpoint_step,
            h=h,core_endpoint_margin_Wb=core_endpoint_margin,
            first_crossing=geom.first_outward_crossing_signature,FD_credit=false))
    else
        vectors=Vector{Vector{Float64}}(undef,2);cuts=similar(vectors)
        for (q,step) in enumerate((h,h/2))
            xp=copy(x);xm=copy(x);xp[col]+=step;xm[col]-=step
            rp=component.lcfs_state_F_curl_trace(xp;with_jacobian=false)
            rm=component.lcfs_state_F_curl_trace(xm;with_jacobian=false)
            branch(t)=t.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl &&
                t.dynamic_geometry.mask_event===:unchanged &&
                t.dynamic_geometry.first_outward_crossing_signature===geom.first_outward_crossing_signature &&
                cells(t.dynamic_geometry)==base_cells
            if !branch(rp) || !branch(rm)
                empty!(reports);push!(reports,(status=:typed_absent,
                    reason=:boundary_endpoint_changed_mask_first_crossing_or_cell_signature,
                    step=step,FD_credit=false));break
            end
            vectors[q]=(rp.Jn_A_per_m2-rm.Jn_A_per_m2)./(2step)
            cuts[q]=(rp.cut_segment_outward_current_A-rm.cut_segment_outward_current_A)./(2step)
        end
        if isempty(reports)
            analytic=Vector(trace.jacobian[:,col]);cut_analytic=Vector(trace.cut_segment_jacobian[:,col])
            @test maximum(abs,analytic;init=0.0)>0
            @test maximum(abs,cut_analytic;init=0.0)>0
            @test maximum(abs,vectors[1];init=0.0)>0 && maximum(abs,vectors[2];init=0.0)>0
            @test maximum(abs,cuts[1];init=0.0)>0 && maximum(abs,cuts[2];init=0.0)>0
            @test isapprox(vectors[1],analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(vectors[2],analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(cuts[1],cut_analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(cuts[2],cut_analytic;rtol=5e-6,atol=5e-11)
            @test isapprox(vectors[1],vectors[2];rtol=5e-6,atol=5e-11)
            @test isapprox(cuts[1],cuts[2];rtol=5e-6,atol=5e-11)
            push!(reports,(status=:evaluated,column=col,h=h,h_over_2=h/2,
                Jn_max_abs_fd_h=maximum(abs,vectors[1];init=0.0),
                Jn_max_abs_fd_h2=maximum(abs,vectors[2];init=0.0),
                Jn_max_abs_analytic=maximum(abs,analytic;init=0.0),
                cut_max_abs_fd_h=maximum(abs,cuts[1];init=0.0),
                cut_max_abs_fd_h2=maximum(abs,cuts[2];init=0.0),
                cut_max_abs_analytic=maximum(abs,cut_analytic;init=0.0),
                analytic_endpoint_column=:profile_lift_nonzero_checked_by_independent_FD,
                actual_geometry_level=:refined_xpoint_boundary_psi,
                profile_endpoint_role=:live_profile_normalization_and_residual_lift,
                FD_credit=:analytic_vs_two_step_independent_state_FD))
        end
    end
    @test any(record->hasproperty(record,:status) && record.status===:evaluated,reports)
    println("FREEGS_LCFS_STATE_F_ENDPOINT_ZERO_PARTIAL_JSON="*F.canonical_json((
        dynamic_profile_span=true,boundary_endpoint_column=col,
        geometry_endpoint_sensitivity=:zero_by_actual_value_function,
        field_profile_endpoint_sensitivity=:nonzero_checked_by_independent_FD,records=reports,
        actual_geometry_level=:refined_xpoint_boundary_psi,
        profile_endpoint_role=:live_profile_normalization_and_residual_lift,
        current_rows_added=0,physical_validation=false)));flush(stdout)
end

# Compatibility entry point for the existing focused runner; the test now checks
# the live profile-lift endpoint derivative against independent state finite differences.
Base.@noinline function test_actual_dynamic_lcfs_F_endpoint_zero_partial(F,component)
    test_actual_dynamic_lcfs_F_boundary_profile_partial(F,component)
end

Base.@noinline function test_actual_composite_current_point_oracle(law,q,D,u,v,R,gR,gZ,
        mask,mask_R,mask_Z,normal_R,normal_Z,p0)
    setprecision(BigFloat,256) do
        q_b=BigFloat(q);D_b=BigFloat(D);u_b=BigFloat(u);v_b=BigFloat(v)
        R_b=BigFloat(R);gR_b=BigFloat(gR);gZ_b=BigFloat(gZ)
        mask_b=BigFloat(mask);mask_R_b=BigFloat(mask_R);mask_Z_b=BigFloat(mask_Z)
        normal_R_b=BigFloat(normal_R);normal_Z_b=BigFloat(normal_Z);p0_b=BigFloat(p0)
        Raxis_b=BigFloat(law.Raxis_m);mu0_b=BigFloat(law.mu0_N_per_A2)
        Fvac_b=BigFloat(law.fvac_T_m)
        I_b=D_b*q_b^3/3
        pressure_b=p0_b+u_b*I_b/Raxis_b
        F_b=sqrt(Fvac_b^2+2mu0_b*v_b*Raxis_b*I_b)
        deltaF_b=F_b-Fvac_b
        Fmix_b=Fvac_b+mask_b*deltaF_b
        fpol_psi_b=mu0_b*v_b*Raxis_b*q_b^2/F_b
        JR_b=-(mask_b*fpol_psi_b*gZ_b+deltaF_b*mask_Z_b)/(mu0_b*R_b)
        JZ_b=(mask_b*fpol_psi_b*gR_b+deltaF_b*mask_R_b)/(mu0_b*R_b)
        Jn_b=normal_R_b*JR_b+normal_Z_b*JZ_b
        (fields=(Float64(pressure_b),Float64(Fmix_b/R_b),Float64(JR_b),
                 Float64(JZ_b),Float64(Jn_b)),
         residual=(Float64(pressure_b-p0_b),Float64(mask_b*deltaF_b),Float64(Jn_b)))
    end
end
function g2_precheck_reuse_qualified_local_fd(precheck_mode,component,provider)
    flag=get(ENV,"FUSION_G2_REUSE_QUALIFIED_LOCAL_FD","0")
    flag in ("0","1") || error("FUSION_G2_REUSE_QUALIFIED_LOCAL_FD must be 0 or 1")
    requested_reuse = flag=="1" || precheck_mode=="global_first_assembly_short"
    requested_reuse || return false
    precheck_mode in ("global_diagnostic","global_first_assembly_short","current_topology_smoke") ||
        error("qualified local FD reuse is supported only by global diagnostic/current-topology modes")
    provider.status===:prepared_conservation_evaluator ||
        error("qualified local FD reuse requires the prepared conservation provider")
    if flag=="1"
        component.candidate_hash=="f49af93fad205952b8ef5b6eccb7f783924bf67c9c60bd7cf00f8b613606c222" ||
            error("qualified local FD reuse candidate hash does not match the pinned f49 candidate")
        component.context_hash=="e59eea4af0f08a680328a7dcb78ada8504209308ff7a6da72f1e3c9742a2d14f" ||
            error("qualified local FD reuse context hash does not match the pinned e59 context")
        component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1 ||
            error("qualified local FD reuse requires the absolute native field model")
        get(ENV,"FUSION_FREEGS_DYNAMIC_PROFILE_SPAN","0")=="1" &&
            component.dynamic_profile_span===true ||
            error("qualified local FD reuse requires dynamic profile span")
        provider.current_topology===:ideal_axisymmetric_periodic_lcfs_no_normal_current &&
            provider.return_current_path===:periodic_toroidal_plasma_with_zero_normal_current_at_LCFS ||
            error("qualified local FD reuse requires the pinned periodic topology and return-path declaration")
    end
    true
end

Base.@noinline function test_actual_composite_dynamic_profile_current(F,trace,component;
        diagnostic_psi_only=false,diagnostic_interface_sweep=false,
        reuse_qualified_local_fd=false)
    diagnostic_interface_sweep = diagnostic_interface_sweep ||
        get(ENV,"FUSION_G2_INTERFACE_FD_DIAGNOSTIC","0")=="1"
    reuse_qualified_local_fd && (diagnostic_psi_only || diagnostic_interface_sweep) &&
        error("qualified-FD reuse cannot be combined with a diagnostic FD sweep")
    x=component.initial_state
    @test component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1
    geometry=component.lcfs_dynamic_geometry_trace(x)
    @test geometry.status===:evaluated_dynamic_LCFS_geometry
    @test geometry.field_model_id===component.native_field_model_id
    @test geometry.field_representation===:plasma_not_a_knot_spline_plus_unclipped_exact_PF_Green_jet
    @test geometry.source_fd_anchor_use===:unchanged_source_records_not_reused_as_continuous_fields
    @test geometry.global_topology_closed===false && geometry.physical_validation===false
    @test_throws ArgumentError component.lcfs_dynamic_geometry_trace(x;model_id=:source_cp_v2)
    explicit_probe=component.lcfs_dynamic_geometry_trace(x;
        model_id=:plasma_spline_plus_exact_pf_potential_jet_v1)
    @test explicit_probe.status===:evaluated_dynamic_LCFS_geometry
    @test explicit_probe.field_model_id===component.native_field_model_id
    @test explicit_probe.source_fd_anchor_use===:unchanged_source_records_not_reused_as_continuous_fields
    @test explicit_probe.global_topology_closed===false && explicit_probe.physical_validation===false
   # A mathematically zero fan wedge is skipped; a positive sub-tolerance
   # triangle is a topology/numerics failure and must not be silently zeroed.
   duffy_nodes,duffy_weights=F._ccp_q1_green_gauss(2)
   duffy_bounds=(1.0,2.0,0.0,1.0);duffy_columns=(1,2,3,4)
   zero_calls=Ref(0)
   zero_wedge=F._ccp_q1_duffy_triangle_response((1.5,0.5),(1.2,0.2),
       (1.4,0.2),(1.6,0.2),duffy_bounds,duffy_columns,4,4pi*1e-7,2,
       duffy_nodes,duffy_weights,zero_calls,32)
   @test zero_wedge==zeros(2,4) && zero_calls[]==0
   tiny_calls=Ref(0)
   tiny_wedge=F._ccp_q1_duffy_triangle_response((1.5,0.5),(1.25,0.25),
       (1.25+1e-15,0.25),(1.25,0.25+1e-15),duffy_bounds,duffy_columns,4,
       4pi*1e-7,2,duffy_nodes,duffy_weights,tiny_calls,32)
   @test tiny_wedge.status===:typed_absent
   @test tiny_wedge.reason===:duffy_nonzero_triangle_area_below_stable_tolerance
   @test tiny_wedge.area2>0 && tiny_wedge.area2<=tiny_wedge.area_tolerance
   @test tiny_calls[]==0
   # Four simultaneous analytic ring directions share one primal elliptic K/E evaluation.
   ring_directions=zeros(4,4)
   for q in 1:4; ring_directions[q,q]=1.0; end
   ring_base=(1.38,0.21,1.12,-0.31);ring_mu0=4pi*1e-7
   ring_jet=F._ccp_ring_unit_field_RZ(ring_base...,ring_mu0;directions=ring_directions)
   ring_h=1e-6
   for q in 1:4
       d=ring_directions[:,q]
       plus=F._ccp_ring_unit_field_RZ(ring_base[1]+ring_h*d[1],ring_base[2]+ring_h*d[2],
           ring_base[3]+ring_h*d[3],ring_base[4]+ring_h*d[4],ring_mu0)
       minus=F._ccp_ring_unit_field_RZ(ring_base[1]-ring_h*d[1],ring_base[2]-ring_h*d[2],
           ring_base[3]-ring_h*d[3],ring_base[4]-ring_h*d[4],ring_mu0)
       for c in 1:2
           analytic=c==1 ? ring_jet[3][q] : ring_jet[4][q]
           fd=(plus[c]-minus[c])/(2ring_h)
           @test abs(fd-analytic)/max(abs(fd),abs(analytic),1e-12)<=5e-6
       end
   end
   # Co-moving singular triangle geometry control: target/source anchor and a distal
   # clipped-vertex coordinate are checked at the existing h/h2 and 5e-6 gate.
   tri_bounds=(1.0,2.0,0.0,1.0);tri_columns=(1,2,3,4);tri_mu0=4pi*1e-7
   tri_order=4;tri_nodes,tri_weights=F._ccp_q1_green_gauss(tri_order)
   tri_p0=(1.35,0.4);tri_p1=(1.65,0.4);tri_p2=(1.35,0.7);tri_target=tri_p0
   tri_current=[1.0,1.2,0.8,1.1]
   tri_targetJ=zeros(2,6);tri_targetJ[1,1]=1.0
   tri_D0=zeros(2,6);tri_D0[1,1]=1.0
   tri_D1=zeros(2,6);tri_D2=zeros(2,6);tri_D2[2,6]=1.0
   tri_geometry=zeros(2,6);tri_calls=Ref(0)
   tri_response=F._ccp_q1_duffy_triangle_response(tri_target,tri_p0,tri_p1,tri_p2,
       tri_bounds,tri_columns,4,tri_mu0,tri_order,tri_nodes,tri_weights,tri_calls,4096;
       target_jacobian=tri_targetJ,vertex_jacobians=(tri_D0,tri_D1,tri_D2),
       current_density=tri_current,geometry_accumulator=tri_geometry,geometry_row=1)
   @test size(tri_response)==(2,4) && 0<tri_calls[]<=4096
   tri_fixed_calls=Ref(0)
   tri_fixed=F._ccp_q1_duffy_triangle_response(tri_target,tri_p0,tri_p1,tri_p2,tri_bounds,
       tri_columns,4,tri_mu0,tri_order,tri_nodes,tri_weights,tri_fixed_calls,4096)
   @test tri_fixed_calls[]==tri_calls[]
   @test all(isapprox.(tri_fixed,tri_response;rtol=0,atol=0))
   for (ell,h) in ((1,1e-5),(1,5e-6),(6,1e-5),(6,5e-6))
       move0=ell==1;move2=ell==6
       plus0=(tri_p0[1]+(move0 ? h : 0.0),tri_p0[2])
       minus0=(tri_p0[1]-(move0 ? h : 0.0),tri_p0[2])
       plus2=(tri_p2[1],tri_p2[2]+(move2 ? h : 0.0))
       minus2=(tri_p2[1],tri_p2[2]-(move2 ? h : 0.0))
       plus_target=(tri_target[1]+(move0 ? h : 0.0),tri_target[2])
       minus_target=(tri_target[1]-(move0 ? h : 0.0),tri_target[2])
       plus_calls=Ref(0);minus_calls=Ref(0)
       plus_E=F._ccp_q1_duffy_triangle_response(plus_target,plus0,tri_p1,plus2,tri_bounds,
           tri_columns,4,tri_mu0,tri_order,tri_nodes,tri_weights,plus_calls,4096)
       minus_E=F._ccp_q1_duffy_triangle_response(minus_target,minus0,tri_p1,minus2,tri_bounds,
           tri_columns,4,tri_mu0,tri_order,tri_nodes,tri_weights,minus_calls,4096)
       fd=(plus_E*tri_current-minus_E*tri_current)/(2h)
       analytic=(tri_geometry[1,ell],tri_geometry[2,ell])
       @test hypot(fd[1]-analytic[1],fd[2]-analytic[2])/
           max(hypot(fd[1],fd[2]),hypot(analytic[1],analytic[2]),1e-12)<=5e-6
   end
    if precheck_mode=="lcfs_exterior_field_local_controls"
        return (status=:exterior_local_controls_completed,solver_rows_added=0,global_closure=false)
    end
    if get(ENV,"FUSION_G2_PRECHECK_MODE","")=="lcfs_exterior_field_full64_primal_smoke"
    # Full 64-ray same-state exterior-field primal plus a candidate Jacobian that remains unvalidated.
    # diagnostic with no quadrature certificate or full-state field Jacobian.
    exterior=Base.invokelatest(component.lcfs_exterior_field_primal,x)
    @test exterior.status===:diagnostic_same_state_64_ray_LCFS_exterior_field_primal
    if exterior.status===:diagnostic_same_state_64_ray_LCFS_exterior_field_primal
        @test exterior.trace_hash==trace.trace_hash
        @test exterior.ray_ids===Tuple(1:64)
        @test exterior.target_coordinates_RZ_m===geometry.coordinates_RZ_m
        @test size(exterior.B_exterior_T)==(3,64)
        @test size(exterior.normal_jacobian)==(192,length(x)) && issparse(exterior.normal_jacobian)
        @test exterior.field_row_order===:point_major_Br_Bphi_Bz
        @test all(isfinite,exterior.B_exterior_T)
        @test exterior.B_exterior_jacobian===:typed_absent
        @test exterior.B_exterior_jacobian_partial_status===:available_all_analytic_terms_unvalidated
        @test size(exterior.B_exterior_jacobian_partial_T_per_state_dof)==(192,length(x))
        @test size(exterior.native_source_current_jacobian_A_per_m2_per_state_dof)==
            (length(exterior.source_current_native_ids),length(x))
        @test all(isfinite,exterior.B_exterior_jacobian_partial_T_per_state_dof)
        @test exterior.B_exterior_jacobian_partial_terms.plasma_source_current_at_fixed_clipped_support!==nothing
        @test exterior.B_exterior_jacobian_partial_terms.exact_PF_and_authored_TF_dynamic_target_motion!==nothing
        @test :certified_quadrature_error_bound in exterior.full_state_Jacobian_missing_terms
        @test :independent_selected_state_column_validation in exterior.full_state_Jacobian_missing_terms
        @test exterior.B_exterior_jacobian_partial_terms.co_moving_plasma_target_and_clipped_source_shape===:included
        @test exterior.B_exterior_jacobian_candidate_status===:analytic_full_state_candidate_unvalidated
        @test size(exterior.B_exterior_jacobian_candidate_T_per_state_dof)==(192,length(x))
        @test exterior.derivative_error_bound_T===:typed_absent
        @test exterior.consumer_status===:typed_absent && !exterior.global_closure
        @test exterior.solver_rows_added==0 && !exterior.physical_validation
        @test all(isapprox.(exterior.B_exterior_T[1,:],
            exterior.B_exterior_components.plasma_Q1_RZ_T[1,:].+
            exterior.B_exterior_components.PF_exact_RZ_T[1,:];rtol=0,atol=0))
        @test all(isapprox.(exterior.B_exterior_T[2,:],
            exterior.B_exterior_components.authored_TF_phi_T;rtol=0,atol=0))
        @test all(isapprox.(exterior.B_exterior_T[3,:],
            exterior.B_exterior_components.plasma_Q1_RZ_T[2,:].+
            exterior.B_exterior_components.PF_exact_RZ_T[2,:];rtol=0,atol=0))
    end
    end
    fixed_current=component.lcfs_profile_current_trace(x;with_jacobian=true)
    @test fixed_current.status===:typed_absent
    @test fixed_current.reason===:composite_native_field_model_requires_same_state_dynamic_geometry
    @test fixed_current.fields===nothing && fixed_current.residual===nothing && fixed_current.jacobian===nothing
    @test fixed_current.fixed_geometry===false && fixed_current.source_fields_reused===false
    pressure_view=component.pressure_domain_view(x)
    @test pressure_view.status===:derived_same_state_dynamic_analytic_pressure_and_constrained_nodal_samples
    @test pressure_view.dynamic_geometry.field_model_id===geometry.field_model_id
    pressure_trace=component.lcfs_profile_current_trace(x;
        pressure_only=true,dynamic_geometry=true,with_jacobian=true)
    @test pressure_trace.status===:evaluated_dynamic_LCFS_pressure_only
    @test pressure_trace.dynamic_geometry.field_model_id===geometry.field_model_id
    @test pressure_trace.pressure_status===:evaluated_same_state_analytic_profile_pressure
    @test pressure_trace.current_status===:not_evaluated_by_pressure_only_request
    # This positive current path requires the authored pressure-domain
    # candidate. Keep the LCFS geometry fixed while moving only the
    # independent profile boundary endpoint into the native flux span.
    composite_model=:plasma_spline_plus_exact_pf_potential_jet_v1
    offgrid_source=trace.data.offgrid_source
    @test length(offgrid_source)==64
    @test all(sample->sample.status===:present &&
        sample.mask_matches_refreshed_current_support===true,offgrid_source)
    p0=pressure_trace.authored_exterior_pressure_Pa
    @test isfinite(p0) && p0==trace.data.profile_boundary_pressure_Pa
    @test component.pressure_domain_declaration_status===:authored_law_only
    axis_col,boundary_col=component.profile_span_columns
    u_col,v_col=component.profile_coefficient_columns
    profile_A=Float64(x[axis_col]);profile_B=Float64(x[boundary_col])
    profile_D=profile_A-profile_B
    @test profile_D>0
    shifted_B_state=copy(x)
    shifted_B_state[boundary_col]=profile_B-0.001profile_D
    shifted_current=Base.invokelatest(component.lcfs_profile_current_trace,shifted_B_state;
        with_jacobian=true,dynamic_geometry=true)
    @test shifted_current.status===:evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi
    @test shifted_current.field_model_id===composite_model
    @test shifted_current.dynamic_geometry.field_model_id===component.native_field_model_id
    @test shifted_current.pressure_status===:evaluated_composite_profile_pressure
    @test shifted_current.current_status===:evaluated_composite_profile_curl_Bphi
    @test shifted_current.current_normal_trace===:evaluated_dynamic_geometry_holdout
    @test shifted_current.field_order===(:profile_pressure_Pa,:Bphi_T,:JR_A_per_m2,:JZ_A_per_m2,:Jn_A_per_m2)
    @test shifted_current.residual_order===(:pressure_minus_boundary,:stable_shared_lifted_F_B_minus_fvac,:actual_lifted_curl_Jn)
    @test size(shifted_current.fields)==(64,5)
    @test size(shifted_current.residual)==(192,)
    @test size(shifted_current.jacobian)==(192,length(x))
    interface_inputs=shifted_current.plasma_side_interface_inputs
    @test interface_inputs.status===:evaluated_plasma_side_dynamic_LCFS_inputs
    expected_interface_representation=component.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1 ?
        :continuous_total_psi_gradient_plus_actual_state_F_over_R :
        :native_state_Br__actual_state_F_B_over_actual_R__native_state_Bz
    @test interface_inputs.interface_B_representation===expected_interface_representation
    @test interface_inputs.Bphi_source===:actual_state_F_B_spline_over_actual_R
    @test interface_inputs.field_topology_scope===:field_observation_only_no_current_topology_claim
    @test !interface_inputs.canonical_current_trace_retained_for_comparison
    @test interface_inputs.canonical_profile_Bphi_minus_actual_state_F_B_T===:not_independent_same_evaluator
    @test length(interface_inputs.native_poloidal_minus_exact_PF_psi_gradient_T)==64
    # The reported poloidal mismatch is diagnostic and need not vanish off-constraint.
    for a in 1:64
        R=shifted_current.dynamic_geometry.coordinates_RZ_m[a][1]
        gR,gZ=shifted_current.dynamic_geometry.surface_gradient_RZ_Wb_per_rad_m[a]
        observed=interface_inputs.native_poloidal_minus_exact_PF_psi_gradient_T[a]
        @test isapprox(observed[1],interface_inputs.B_plasma_T[1,a]+gZ/R;rtol=0,atol=64eps(Float64)*max(1.0,abs(observed[1])))
        @test isapprox(observed[2],interface_inputs.B_plasma_T[3,a]-gR/R;rtol=0,atol=64eps(Float64)*max(1.0,abs(observed[2])))
    end
    @test interface_inputs.legacy_composite_Bphi_semantics===:off_constraint_composite_profile_point_field
    @test interface_inputs.canonical_profile_Bphi_semantics===:shared_P_total_psi_plus_tensor_spline_D_over_R
    @test interface_inputs.canonical_profile_Bphi_comparison_status===:not_independent_same_production_evaluator
    @test interface_inputs.legacy_Q1_regional_F_defect_role===:historical_comparison_only_not_evaluated_by_production_consumer
    @test interface_inputs.legacy_and_canonical_Bphi_semantic_equivalence===:not_established
    @test interface_inputs.legacy_composite_F_not_used_for_interface_Bphi
    @test size(interface_inputs.B_plasma_T)==(3,64)
    @test size(interface_inputs.B_plasma_jacobian)==(192,length(x)) && issparse(interface_inputs.B_plasma_jacobian)
    @test length(interface_inputs.pressure_plasma_Pa)==64
    @test size(interface_inputs.pressure_plasma_jacobian)==(64,length(x))
    @test interface_inputs.pressure_exterior_Pa==fill(p0,64)
    @test size(interface_inputs.pressure_exterior_jacobian)==(64,length(x))
    @test size(interface_inputs.normal_plasma_to_exterior)==(3,64)
    @test size(interface_inputs.normal_jacobian)==(192,length(x)) && issparse(interface_inputs.normal_jacobian)
    @test interface_inputs.B_exterior_status===:typed_absent &&
        interface_inputs.B_exterior_jacobian_status===:typed_absent && interface_inputs.stress_jump_status===:typed_absent
    @test interface_inputs.reason===:moving_LCFS_exterior_B_out_and_stress_jump_unavailable
    @test interface_inputs.solver_rows_added==0 && !interface_inputs.global_topology_closed
    @test shifted_current.jacobian_columns===:full_existing_state_columns_for_pressure_and_shared_lifted_F_current
    @test shifted_current.dynamic_geometry_jacobian_columns===:psi_native_dofs_only
    @test shifted_current.q_normalized_to===:dynamic_profile_axis_boundary_flux
    @test shifted_current.profile_shape_q_convention===:(psi_minus_B_over_A_minus_B)
    @test shifted_current.fixed_geometry===false && shifted_current.fixed_source_mask===true
    @test shifted_current.source_fields_reused===false && shifted_current.solver_rows_added==0
    @test shifted_current.extra_solver_rows==0
    @test shifted_current.source_mask_rebuild_gate===:native_core_mask_inventory_unchanged_required
    mask_anchor_check=shifted_current.mask_spline_anchor_check
    @test mask_anchor_check.max_value_error<=mask_anchor_check.value_bound
    @test mask_anchor_check.max_gradient_error<=mask_anchor_check.gradient_bound
    @test shifted_current.missing_closures==component.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
    @test shifted_current.global_topology_closed===false && shifted_current.physical_validation===false
    @test shifted_current.dynamic_geometry.coordinates_RZ_m==pressure_trace.dynamic_geometry.coordinates_RZ_m
    @test shifted_current.dynamic_geometry.candidate_total_psi_Wb_per_rad==
        pressure_trace.dynamic_geometry.candidate_total_psi_Wb_per_rad
    shifted_profile_A=Float64(shifted_B_state[axis_col])
    shifted_profile_B=Float64(shifted_B_state[boundary_col])
    shifted_profile_D=shifted_profile_A-shifted_profile_B
    @test shifted_current.profile_endpoint_values==(axis=shifted_profile_A,
        boundary=shifted_profile_B,delta=shifted_profile_D)
    @test shifted_current.endpoint_definition_residual==(
        shifted_profile_A-shifted_current.dynamic_geometry.psi_axis_Wb_per_rad,
        shifted_profile_B-shifted_current.dynamic_geometry.psi_boundary_Wb_per_rad)
    @test length(shifted_current.profile_q)==64
    @test all(isfinite,shifted_current.profile_q) && all(q->0<q<1,shifted_current.profile_q)
    @test length(shifted_current.effective_boundary_q)==64
    @test length(shifted_current.effective_boundary_helper_Q)==64
    @test shifted_current.effective_boundary_q_source===:same_state_dynamic_geometry_psi_boundary_flux
    @test shifted_current.profile_q_source===:raw_composite_surface_psi_preserved
    @test maximum(abs.(shifted_current.residual[1:3:192]);init=0.0)>0
    @test maximum(abs.(shifted_current.residual[2:3:192]);init=0.0)>0
    @test maximum(abs.(shifted_current.residual[3:3:192]);init=0.0)>0
    law=component.profile_law
    u_value=Float64(shifted_B_state[u_col]);v_value=Float64(shifted_B_state[v_col])
    composite_fields=zeros(64,5);composite_residual=zeros(192)
    dynamic_points=collect(shifted_current.dynamic_geometry.coordinates_RZ_m)
    Raxis=Float64.(collect(trace.data.current_support.R_m))
    Zaxis=Float64.(collect(trace.data.current_support.Z_m))
    rw=F._ccp_native_spline_point_weights_oracle(Raxis,first.(dynamic_points))
    zw=F._ccp_native_spline_point_weights_oracle(Zaxis,last.(dynamic_points))
    mask_grid=Float64.(component.core_mask)
    expected_mask=zeros(64);expected_mask_gradient=zeros(64,2)
    for a in 1:64, i in eachindex(Raxis), j in eachindex(Zaxis)
        k=(i-1)*length(Zaxis)+j;mask_node=mask_grid[k]
        expected_mask[a]+=rw.value[a,i]*zw.value[a,j]*mask_node
        expected_mask_gradient[a,1]+=rw.derivative[a,i]*zw.value[a,j]*mask_node
        expected_mask_gradient[a,2]+=rw.value[a,i]*zw.derivative[a,j]*mask_node
    end
    actual_mask=Float64.(collect(shifted_current.mask_spline_value))
    actual_mask_gradient=reduce(vcat,(reshape(collect(g),1,2) for g in
        shifted_current.mask_spline_gradient_RZ_per_m))
    @test isapprox(actual_mask,expected_mask;rtol=2e-10,atol=1e-14)
    @test isapprox(actual_mask_gradient,expected_mask_gradient;rtol=2e-10,atol=1e-14)
    for a in 1:64
        q=(shifted_current.composite_surface_psi_Wb_per_rad[a]-shifted_profile_B)/shifted_profile_D
        @test isapprox(shifted_current.profile_q[a],q;rtol=64eps(Float64),atol=0.0)
        @test 0<q<1
        effective_boundary_q=(shifted_current.dynamic_geometry.psi_boundary_Wb_per_rad-
            shifted_profile_B)/shifted_profile_D
        @test isapprox(shifted_current.effective_boundary_q[a],effective_boundary_q;
            rtol=64eps(Float64),atol=0.0)
        @test isapprox(shifted_current.effective_boundary_q[a]+
            shifted_current.effective_boundary_helper_Q[a],1.0;rtol=64eps(Float64),atol=0.0)
        radius=dynamic_points[a][1]
        gR,gZ=shifted_current.composite_surface_gradient_RZ_Wb_per_rad_m[a]
        normal_R,normal_Z=shifted_current.dynamic_geometry.normals_RZ[a]
        point_oracle=test_actual_composite_current_point_oracle(law,q,shifted_profile_D,
            u_value,v_value,radius,gR,gZ,expected_mask[a],expected_mask_gradient[a,1],
            expected_mask_gradient[a,2],normal_R,normal_Z,p0)
        composite_fields[a,:].=point_oracle.fields
        composite_residual[3a-2:3a].=point_oracle.residual
    end
    @test isapprox(shifted_current.fields[:,1],composite_fields[:,1];rtol=2e-11,atol=1e-14)
    legacy_current=shifted_current.legacy_profile_point_diagnostic
    @test legacy_current.current_partial_role===:legacy_diagnostic_only
    @test legacy_current.pressure_partial_role===:reused_for_active_pressure_rows
    @test isapprox(legacy_current.fields[:,2:5],composite_fields[:,2:5];rtol=2e-10,atol=1e-14)
    @test isapprox(shifted_current.residual[1:3:192],composite_residual[1:3:192];rtol=2e-10,atol=1e-14)
    @test isapprox(legacy_current.F_residual,composite_residual[2:3:192];rtol=2e-10,atol=1e-14)
    @test shifted_current.residual[3:3:192]==shifted_current.fields[:,5]
    active_F_residual=shifted_current.residual[2:3:192]
    raw_Bphi_F_residual=shifted_current.fields[:,2].*
        first.(shifted_current.dynamic_geometry.coordinates_RZ_m).-law.fvac_T_m
    F_centering_roundoff=shifted_current.F_B_centering_roundoff_T_m
    @test length(F_centering_roundoff)==64
    F_centering_scale=max.(1.0,abs.(shifted_current.fields[:,2].*
        first.(shifted_current.dynamic_geometry.coordinates_RZ_m)),abs(law.fvac_T_m))
    @test all(isfinite,F_centering_roundoff)
    @test all(abs.(F_centering_roundoff).<=8eps(Float64).*F_centering_scale)
    @test isapprox(active_F_residual,raw_Bphi_F_residual.+F_centering_roundoff;
        rtol=0,atol=64eps(Float64)*max(1.0,maximum(abs,active_F_residual)))
    @test length(legacy_current.raw_normal_current_projection_A_per_m2)==64
    @test length(legacy_current.levelset_normal_parallel_flux_cross_Wb_per_rad_m)==64
    @test length(legacy_current.normal_current_identity_error_A_per_m2)==64
    @test isapprox(collect(legacy_current.raw_normal_current_projection_A_per_m2),
        collect(composite_fields[:,5]);rtol=2e-10,atol=1e-14)
    raw_jn=collect(legacy_current.raw_normal_current_projection_A_per_m2)
    normal_cross=collect(legacy_current.levelset_normal_parallel_flux_cross_Wb_per_rad_m)
    identity_error=collect(legacy_current.normal_current_identity_error_A_per_m2)
    stable_jn=collect(legacy_current.fields[:,5])
    @test all(isfinite,raw_jn) && all(isfinite,normal_cross) && all(isfinite,identity_error)
    for a in 1:64
        gR,gZ=shifted_current.composite_surface_gradient_RZ_Wb_per_rad_m[a]
        @test abs(normal_cross[a])<=64eps(Float64)*hypot(gR,gZ)
        @test isapprox(identity_error[a],raw_jn[a]-stable_jn[a];rtol=0,atol=0)
        @test isapprox(raw_jn[a],composite_fields[a,5];rtol=2e-10,atol=1e-14)
    end
    @test maximum(abs.(shifted_current.fields[:,1] .- p0);init=0.0)>0
    @test maximum(abs.(shifted_current.fields[:,2].*
        first.(shifted_current.dynamic_geometry.coordinates_RZ_m).-law.fvac_T_m);init=0.0)>0
    @test maximum(abs.(shifted_current.fields[:,5]);init=0.0)>0
    psi_node=first(k for k in findall(component.core_mask) if
        0.3<(x[4k]-profile_B)/profile_D<0.7)
    function flatten_pairs(pairs)
        vcat((Float64.(collect(p)) for p in pairs)...)
    end
    function check_composite_dynamic_column(column,step;diagnostic=false,collect_fd=false,
            interface_diagnostic=false,label=:unlabeled)
        plus=copy(shifted_B_state);minus=copy(shifted_B_state)
        plus[column]+=step;minus[column]-=step
        plus_value=Base.invokelatest(component.lcfs_profile_current_trace,plus;
            with_jacobian=false,dynamic_geometry=true)
        minus_value=Base.invokelatest(component.lcfs_profile_current_trace,minus;
            with_jacobian=false,dynamic_geometry=true)
        @test plus_value.status===minus_value.status===
            :evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi
        if plus_value.status!==:evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi ||
                minus_value.status!==:evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi
            return nothing
        end
        # A changed support/event must stop before interpreting a finite difference.
        for probe in (plus_value,minus_value)
            if probe.status===:evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi
                @test probe.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry
                @test probe.dynamic_geometry.mask_event===:unchanged
                @test length(probe.dynamic_geometry.coordinates_RZ_m)==64
                @test length(probe.dynamic_geometry.normals_RZ)==64
                @test all(a->abs((probe.dynamic_geometry.composite_surface_psi_Wb_per_rad[a]-
                    probe.dynamic_geometry.psi_boundary_Wb_per_rad)/
                    probe.dynamic_geometry.profile_endpoint_values.delta)<=1e-9,1:64)
                @test probe.fixed_source_mask===true
                @test probe.source_mask_rebuild_gate===:native_core_mask_inventory_unchanged_required
            end
        end
        fd=(plus_value.residual-minus_value.residual)/(2step)
        interface_base=shifted_current.plasma_side_interface_inputs
        interface_plus=plus_value.plasma_side_interface_inputs
        interface_minus=minus_value.plasma_side_interface_inputs
        point_major(M)=vcat((M[:,a] for a in 1:size(M,2))...)
        B_fd=(point_major(interface_plus.B_plasma_T)-point_major(interface_minus.B_plasma_T))/(2step)
        normal_fd=(point_major(interface_plus.normal_plasma_to_exterior)-
            point_major(interface_minus.normal_plasma_to_exterior))/(2step)
        pressure_fd=(interface_plus.pressure_plasma_Pa-interface_minus.pressure_plasma_Pa)/(2step)
        @test interface_plus.B_plasma_jacobian===nothing && interface_minus.B_plasma_jacobian===nothing
        B_analytic=interface_base.B_plasma_jacobian[:,column]
        normal_analytic=interface_base.normal_jacobian[:,column]
        pressure_analytic=interface_base.pressure_plasma_jacobian[:,column]
        interface_metric(fd_value,analytic_value)=begin
            scale=max(F.norm(fd_value),F.norm(analytic_value),1e-12)
            error_norm=F.norm(fd_value-analytic_value)
            (fd_norm=F.norm(fd_value),analytic_norm=F.norm(analytic_value),
                error_norm=error_norm,scale=scale,relative_error=error_norm/scale,
                original_gate_pass=error_norm<=5e-6*scale,
                original_gate_relative_tolerance=5e-6)
        end
        interface_metrics=(label=label,column=column,step=step,
            B=(Br=interface_metric(B_fd[1:3:192],B_analytic[1:3:192]),
                Bphi=interface_metric(B_fd[2:3:192],B_analytic[2:3:192]),
                Bz=interface_metric(B_fd[3:3:192],B_analytic[3:3:192])),
            normal=(R=interface_metric(normal_fd[1:3:192],normal_analytic[1:3:192]),
                phi=interface_metric(normal_fd[2:3:192],normal_analytic[2:3:192]),
                Z=interface_metric(normal_fd[3:3:192],normal_analytic[3:3:192])),
            pressure=interface_metric(pressure_fd,pressure_analytic))
        if interface_diagnostic
            report=merge((diagnostic_only=true,),interface_metrics)
            println("COMPOSITE_INTERFACE_FD_DIAGNOSTIC="*F.canonical_json(report))
            return report
        end
        if column==axis_col || column==v_col
            old_B_scale=max(F.norm(B_fd),F.norm(B_analytic),1e-12)
            old_B_error=F.norm(B_fd-B_analytic)
            println("COMPOSITE_INTERFACE_B_OLD_STEP_DIAGNOSTIC="*F.canonical_json((
                diagnostic_only=true,column=column,step=step,Bphi=interface_metrics.B.Bphi,
                original_gate_pass=old_B_error<=5e-6*old_B_scale,
                original_gate_relative_tolerance=5e-6)))
            @test F.norm(normal_fd-normal_analytic)<=5e-6*max(F.norm(normal_fd),F.norm(normal_analytic),1e-12)
            @test F.norm(pressure_fd-pressure_analytic)<=5e-6*max(F.norm(pressure_fd),F.norm(pressure_analytic),1e-12)
        else
            for (fd_value,analytic_value) in ((B_fd,B_analytic),(normal_fd,normal_analytic),(pressure_fd,pressure_analytic))
                @test F.norm(fd_value-analytic_value)<=5e-6*max(F.norm(fd_value),F.norm(analytic_value),1e-12)
            end
        end
        geometry=shifted_current.dynamic_geometry
        analytic=shifted_current.jacobian[:,column]
        row_groups=(1:3:192,2:3:192,3:3:192)
        group_metrics=Tuple((fdnorm=F.norm(fd[rows]),jacobian_norm=F.norm(analytic[rows]),
            error_norm=F.norm(fd[rows]-analytic[rows])) for rows in row_groups)
        if !diagnostic
            for (metric,rows) in zip(group_metrics,row_groups)
                scale=max(metric.fdnorm,metric.jacobian_norm,1e-12)
                @test metric.error_norm<=5e-6*scale
            end
            collect_fd && return (fd_jn=copy(fd[3:3:192]),
                analytic_jn=copy(analytic[3:3:192]))
            return nothing
        end
        println("COMPOSITE_PSI_ONLY_GROUP_METRICS="*F.canonical_json((column=column,step=step,
            residual_groups=(pressure=group_metrics[1],Bphi_minus_fvac=group_metrics[2],
                Jn=group_metrics[3]))))
        native_node=div(column,4)
        @assert rem(column,4)==0
        n_native=length(component.core_mask)
        @assert 1<=native_node<=n_native
        @assert length(geometry.psi_global_dof_ids)==n_native &&
            geometry.psi_global_dof_ids[native_node]==column
        @assert size(geometry.coordinate_jacobian)==(128,n_native)
        @assert size(geometry.normal_jacobian)==(128,n_native)
        @assert size(geometry.boundary_flux_jacobian)==(1,n_native)
        plus_geometry=plus_value.dynamic_geometry;minus_geometry=minus_value.dynamic_geometry
        for g in (geometry,plus_geometry,minus_geometry)
            @assert length(g.coordinates_RZ_m)==64 && length(g.normals_RZ)==64
            @assert all(p->length(p)==2,g.coordinates_RZ_m) && all(n->length(n)==2,g.normals_RZ)
            @assert length(g.composite_surface_psi_Wb_per_rad)==64 &&
                length(g.composite_surface_gradient_RZ_Wb_per_rad_m)==64
            @assert all(gv->length(gv)==2,g.composite_surface_gradient_RZ_Wb_per_rad_m)
            @assert length(g.axis_RZ_m)==2 && length(g.boundary_RZ_m)==2
        end
        coordinate_fd=(flatten_pairs(plus_geometry.coordinates_RZ_m)-
            flatten_pairs(minus_geometry.coordinates_RZ_m))/(2step)
        coordinate_jacobian=geometry.coordinate_jacobian[:,native_node]
        normal_fd=(flatten_pairs(plus_geometry.normals_RZ)-
            flatten_pairs(minus_geometry.normals_RZ))/(2step)
        normal_jacobian=geometry.normal_jacobian[:,native_node]
        surface_boundary_error(g)=maximum(abs.(collect(g.composite_surface_psi_Wb_per_rad).-g.psi_boundary_Wb_per_rad);init=0.0)
        normal_gradient_cross_max(g)=maximum(abs(
            g.normals_RZ[a][1]*g.composite_surface_gradient_RZ_Wb_per_rad_m[a][2]-
            g.normals_RZ[a][2]*g.composite_surface_gradient_RZ_Wb_per_rad_m[a][1])
            for a in eachindex(g.normals_RZ);init=0.0)
        report=(column=column,step=step,
            residual_groups=(pressure=group_metrics[1],Bphi_minus_fvac=group_metrics[2],
                Jn=group_metrics[3]),
            boundary_flux=(minus=minus_geometry.psi_boundary_Wb_per_rad,
                baseline=geometry.psi_boundary_Wb_per_rad,plus=plus_geometry.psi_boundary_Wb_per_rad,
                jacobian_column=geometry.boundary_flux_jacobian[1,native_node]),
            axis_position=(minus=minus_geometry.axis_RZ_m,baseline=geometry.axis_RZ_m,
                plus=plus_geometry.axis_RZ_m),
            boundary_position=(minus=minus_geometry.boundary_RZ_m,baseline=geometry.boundary_RZ_m,
                plus=plus_geometry.boundary_RZ_m),
            surface_psi_minus_boundary_max=(minus=surface_boundary_error(minus_geometry),
                baseline=surface_boundary_error(geometry),plus=surface_boundary_error(plus_geometry)),
            normal_gradient_cross_max=(minus=normal_gradient_cross_max(minus_geometry),
                baseline=normal_gradient_cross_max(geometry),plus=normal_gradient_cross_max(plus_geometry)),
            geometry_coordinate=(fd_norm=F.norm(coordinate_fd),jacobian_norm=F.norm(coordinate_jacobian),
                error_norm=F.norm(coordinate_fd-coordinate_jacobian)),
            geometry_normal=(fd_norm=F.norm(normal_fd),jacobian_norm=F.norm(normal_jacobian),
                error_norm=F.norm(normal_fd-normal_jacobian)))
        println("COMPOSITE_PSI_ONLY_DIAGNOSTIC="*F.canonical_json(report))
        collect_fd && return (fd_jn=copy(fd[3:3:192]),
            analytic_jn=copy(analytic[3:3:192]))
        report
    end
    function check_composite_interface_Bfield_column(column,step;label)
        plus=copy(shifted_B_state);minus=copy(shifted_B_state)
        plus[column]+=step;minus[column]-=step
        plus_value=Base.invokelatest(component.lcfs_profile_current_trace,plus;
            with_jacobian=false,dynamic_geometry=true)
        minus_value=Base.invokelatest(component.lcfs_profile_current_trace,minus;
            with_jacobian=false,dynamic_geometry=true)
        expected_status=:evaluated_composite_dynamic_LCFS_offgrid_profile_and_curl_Bphi
        @test plus_value.status===minus_value.status===expected_status
        if plus_value.status!==expected_status || minus_value.status!==expected_status
            return nothing
        end
        for probe in (plus_value,minus_value)
            @test probe.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry
            @test probe.dynamic_geometry.mask_event===:unchanged
            @test length(probe.dynamic_geometry.coordinates_RZ_m)==64
            @test length(probe.dynamic_geometry.normals_RZ)==64
            @test all(a->abs((probe.dynamic_geometry.composite_surface_psi_Wb_per_rad[a]-
                probe.dynamic_geometry.psi_boundary_Wb_per_rad)/
                probe.dynamic_geometry.profile_endpoint_values.delta)<=1e-9,1:64)
            @test probe.fixed_source_mask===true
            @test probe.source_mask_rebuild_gate===:native_core_mask_inventory_unchanged_required
        end
        base=shifted_current.plasma_side_interface_inputs
        plus_interface=plus_value.plasma_side_interface_inputs
        minus_interface=minus_value.plasma_side_interface_inputs
        @test plus_interface.B_plasma_jacobian===nothing && minus_interface.B_plasma_jacobian===nothing
        point_major(M)=vcat((M[:,a] for a in 1:size(M,2))...)
        B_fd=(point_major(plus_interface.B_plasma_T)-point_major(minus_interface.B_plasma_T))/(2step)
        B_analytic=base.B_plasma_jacobian[:,column]
        scale=max(F.norm(B_fd),F.norm(B_analytic),1e-12)
        error_norm=F.norm(B_fd-B_analytic)
        metric=(fd_norm=F.norm(B_fd),analytic_norm=F.norm(B_analytic),
            error_norm=error_norm,scale=scale,relative_error=error_norm/scale,
            original_gate_pass=error_norm<=5e-6*scale,original_gate_relative_tolerance=5e-6)
        println("COMPOSITE_INTERFACE_BFIELD_STEP="*F.canonical_json((
            label=label,column=column,step=step,B=metric)))
        @test error_norm<=5e-6*scale
        (fd=copy(B_fd),analytic=copy(B_analytic),metric=metric)
    end
    function check_composite_interface_Bfield_pair(column,unit_scale;label)
        h=1e-4*unit_scale
        full=check_composite_interface_Bfield_column(column,h;label=label*"_h")
        half=check_composite_interface_Bfield_column(column,h/2;label=label*"_h_over_2")
        @test full!==nothing && half!==nothing
        (full===nothing || half===nothing) && return nothing
        delta_norm=F.norm(full.fd-half.fd)
        comparison_scale=max(F.norm(full.fd),F.norm(half.fd),F.norm(full.analytic),1e-12)
        conditional_h_over_2_estimate=delta_norm/3
        @test all(isfinite,(delta_norm,comparison_scale,conditional_h_over_2_estimate))
        report=(label=label,column=column,steps=(h,h/2),step_sensitivity_norm=delta_norm,
            step_sensitivity_relative=delta_norm/comparison_scale,comparison_scale=comparison_scale,
            conditional_h_over_2_error_estimate_if_quadratic=conditional_h_over_2_estimate,
            quadratic_order_assumption=:unverified,quadratic_order_certified=false,
            independent_truncation_certificate=false,
            unchanged_relative_tolerance=5e-6,
            step_sensitivity_status=:reported_without_resolution_claim,
            direct_h_gate=full.metric.original_gate_pass,direct_h_over_2_gate=half.metric.original_gate_pass)
        println("COMPOSITE_INTERFACE_BFIELD_PAIRED_METRICS="*F.canonical_json(report))
        report
    end
    endpoint_step=1e-6*shifted_profile_D
    psi_column_step_reports=if reuse_qualified_local_fd
        println("COMPOSITE_LOCAL_FD_REUSE="*F.canonical_json((
            status=:reused_prequalified_pressure_full_and_current_R9_local_FD,
            pressure_reference="up2_pressure_interface_full_20261010_r2",
            pressure_reference_stdout_sha256="539a1f6e20a44fd015516a00ba862fb636504d88bf763f40eddd8e7fac44475c",
            current_reference="up2_actual_periodic_current_rows_short_20261010_r9",
            current_reference_stdout_sha256="1834994727bd066db1f4851fc7fadca86801ba5c23081aaa39d275e2c3a7a0fd",
            fresh_baseline_values_and_interface_records_retained=true,
            no_new_fd_or_physical_acceptance_credit=true,physical_validation=false)))
        flush(stdout)
        ()
    elseif diagnostic_interface_sweep
        endpoint_step=1e-6*shifted_profile_D
        v_step=1e-6*max(abs(v_value),1.0)
        samples=Tuple(check_composite_dynamic_column(column,step;
            interface_diagnostic=true,label=label*"_"*string(factor)*"h")
            for (column,label,base_step) in ((axis_col,"profile_axis_A",endpoint_step),
                (v_col,"profile_coefficient_v",v_step))
            for factor in (0.5,1.0,2.0,10.0,100.0)
            for step in (factor*base_step,))
        println("COMPOSITE_INTERFACE_FD_DIAGNOSTIC_SUMMARY="*F.canonical_json((
            diagnostic_only=true,columns=(axis_col,v_col),step_factors=(0.5,1.0,2.0,10.0,100.0),
            unchanged_relative_tolerance=5e-6,software_acceptance_gate_asserted=false,
            support_status_checked=true,samples=samples)))
        samples
    elseif diagnostic_psi_only
        # Reuse the one baseline setup and keep the original endpoint step as
        # the control before probing truncation versus Float64/root-floor error.
        Tuple(check_composite_dynamic_column(4psi_node,step;diagnostic=true)
            for step in (endpoint_step,100*endpoint_step,1000*endpoint_step))
    else
        check_composite_dynamic_column(axis_col,endpoint_step)
        check_composite_dynamic_column(boundary_col,endpoint_step)
        check_composite_dynamic_column(4psi_node,100*endpoint_step)
        # The original 1e-6*D step is cancellation-sensitive for Jn. Add a
        # same-state 1e-3*D point as the actual acceptance probe, then use
        # 2x/4x probes with the same direct FD accuracy and support checks.
        # The tolerance stays at 5e-6; report an O(h^2) trend only when its
        # differences can be resolved within the declared derivative accuracy.
        psi_h=1000*endpoint_step
        psi_h_probe=check_composite_dynamic_column(4psi_node,psi_h;collect_fd=true)
        psi_2h_probe=check_composite_dynamic_column(4psi_node,2psi_h;collect_fd=true)
        psi_4h_probe=check_composite_dynamic_column(4psi_node,4psi_h;collect_fd=true)
        psi_h_error=psi_h_probe.fd_jn-psi_h_probe.analytic_jn
        psi_2h_delta=psi_2h_probe.fd_jn-psi_h_probe.fd_jn
        psi_4h_delta=psi_4h_probe.fd_jn-psi_2h_probe.fd_jn
        truncation_ratio=F.norm(psi_4h_delta)/max(F.norm(psi_2h_delta),floatmin(Float64))
        jn_scale=max(F.norm(psi_h_probe.fd_jn),F.norm(psi_h_probe.analytic_jn),1e-12)
        truncation_estimate=F.norm(psi_2h_delta)/3
        @test all(isfinite,(truncation_ratio,truncation_estimate,F.norm(psi_h_error)))
        # A trend cannot be resolved when adjacent differences are smaller than
        # the paired error bounds of the already checked derivatives. Direct FD
        # accuracy at all three steps and unchanged support remain mandatory.
        accuracy_bounds=Tuple(5e-6*max(F.norm(probe.fd_jn),
            F.norm(probe.analytic_jn),1e-12) for probe in
            (psi_h_probe,psi_2h_probe,psi_4h_probe))
        trend_resolved=F.norm(psi_2h_delta)>accuracy_bounds[1]+accuracy_bounds[2] &&
            F.norm(psi_4h_delta)>accuracy_bounds[2]+accuracy_bounds[3]
        if trend_resolved
            @test 2.0<=truncation_ratio<=8.0
        end
        @test truncation_estimate<=5e-6*jn_scale
        @test F.norm(psi_h_error)<=5e-6*jn_scale
        println("COMPOSITE_PSI_JN_TRUNCATION_SWEEP="*F.canonical_json((
            column=4psi_node,steps=(psi_h,2psi_h,4psi_h),
            truncation_difference_ratio=truncation_ratio,
            trend_status=trend_resolved ? :resolved : :unresolved_below_accuracy,
            estimated_h_truncation_norm=truncation_estimate,
            selected_h_error_norm=F.norm(psi_h_error),
            jn_scale=jn_scale,relative_tolerance=5e-6)))
        check_composite_dynamic_column(u_col,1e-6*max(abs(u_value),1.0))
        check_composite_dynamic_column(v_col,1e-6*max(abs(v_value),1.0))
        for (column,label) in ((4psi_node-3,"native_Br"),(4psi_node-2,"native_Bphi"),
                (4psi_node-1,"native_Bz"))
            check_composite_dynamic_column(column,1e-6*max(abs(x[column]),1.0);label=label)
        end
        nothing
    end
    axis_Bfield_pair=nothing
    v_Bfield_pair=nothing
    if !diagnostic_psi_only && !diagnostic_interface_sweep && !reuse_qualified_local_fd
        axis_Bfield_pair=check_composite_interface_Bfield_pair(axis_col,abs(shifted_profile_D);
            label="profile_axis_A")
        v_Bfield_pair=check_composite_interface_Bfield_pair(v_col,max(abs(v_value),1.0);
            label="profile_coefficient_v")
    end
    psi_column_diagnostic=diagnostic_psi_only ? first(psi_column_step_reports) : nothing
    if !diagnostic_psi_only && !diagnostic_interface_sweep
        current_event_state=copy(x)
        xpoint_psi_id=trace.data.current_support.critical_points.xpoints[1].nearest_native_id
        current_event_state[4xpoint_psi_id]+=10profile_D
        current_event=Base.invokelatest(component.lcfs_profile_current_trace,current_event_state;
            with_jacobian=true,dynamic_geometry=true)
        @test current_event.status===:needs_rebuild
        @test current_event.fields===nothing && current_event.residual===nothing &&
            current_event.jacobian===nothing
        @test current_event.fixed_geometry===false && current_event.fixed_source_mask===false
        @test current_event.source_fields_reused===false
        @test current_event.missing_closures==component.missing_closures
    end
    diagnostic_interface_sweep ?
        (diagnostic_only=true,pressure_trace=pressure_trace,pressure_view=pressure_view,
            interface_fd_diagnostic=psi_column_step_reports) : diagnostic_psi_only ?
        (pressure_trace=pressure_trace,pressure_view=pressure_view,
            psi_column_diagnostic=psi_column_diagnostic,
            psi_column_step_sensitivity=Tuple((step=r.step,
                residual_groups=r.residual_groups,geometry_coordinate=r.geometry_coordinate,
                geometry_normal=r.geometry_normal) for r in psi_column_step_reports)) :
        (pressure_trace=pressure_trace,pressure_view=pressure_view,
            interface_B_pair_reports=(axis=axis_Bfield_pair,v=v_Bfield_pair))
end

function test_q1_lcfs_red_child_parent_affine_geometry(F)
    points=((1.6393154922150266,-0.109375),
        (1.6304725368731614,-0.125),(1.62890625,-0.125))
    velocities=((0.07366906380411375,0.0),
        (-0.6135760520467279,0.0),(0.0,0.0))
    area(points)=F._ccp_q1_lcfs_triangle_signed_area(points,
        ntuple(_->(0.0,0.0),3))[1]
    parent_area,parent_darea=F._ccp_q1_lcfs_triangle_signed_area(points,velocities)
    nodes3,weights3=F._ccp_q1_green_gauss(3)
    children=F._ccp_q1_lcfs_red_midpoint_children(points,velocities,nodes3,weights3)
    @test children isa Tuple
    @test length(children)==4
    @test all(c.affine_det_ratio==0.25 for c in children)
    @test all(c.parent_points===points && c.parent_velocities===velocities for c in children)
    @test sum(c.affine_det_ratio*parent_area for c in children)==parent_area
    @test sum(c.affine_det_ratio*parent_darea for c in children)==parent_darea
    @test Tuple(c.child_path for c in children)==((1,),(2,),(3,),(4,))

    midpoint(a,b)=ntuple(k->0.5*(a[k]+b[k]),2)
    p0,p1,p2=points;m01=midpoint(p0,p1);m12=midpoint(p1,p2);m20=midpoint(p2,p0)
    old_children=((p0,m01,m20),(m01,p1,m12),(m20,m12,p2),(m01,m12,m20))
    @test all(children[c].points[i]==ntuple(k->points[1][k]+
        children[c].vertex_weights[i][2]*(points[2][k]-points[1][k])+
        children[c].vertex_weights[i][3]*(points[3][k]-points[1][k]),2)
        for c in 1:4,i in 1:3)
    @test all(children[c].velocities[i]==ntuple(k->velocities[1][k]+
        children[c].vertex_weights[i][2]*(velocities[2][k]-velocities[1][k])+
        children[c].vertex_weights[i][3]*(velocities[3][k]-velocities[1][k]),2)
        for c in 1:4,i in 1:3)
    @test all(isapprox(2area(children[i].points),2children[i].affine_det_ratio*parent_area;
        rtol=5e-6,atol=1e-18) for i in 1:4)
    @test all(isapprox(F._ccp_q1_lcfs_triangle_signed_area(children[i].points,
        children[i].velocities)[2],children[i].affine_det_ratio*parent_darea;
        rtol=5e-6,atol=1e-12) for i in 1:4)
    old_areas=Tuple(area(c) for c in old_children)
    world_closure=sum(old_areas)-parent_area
    world_scale=max(1.0,maximum(abs,Iterators.flatten(points)))
    world_guard=256eps(Float64)*world_scale^2
    closure_tol=256eps(Float64)*max(abs(parent_area),sum(abs,old_areas),1e-300)
    @test abs(world_closure)>closure_tol # exact r6 materialized-world failure
    @test all(abs(2*area(c.points))>world_guard for c in children)

    function mapped_area_tangent(x,dx)
        _,dA=F._ccp_q1_lcfs_triangle_signed_area(x,dx)
        sum(c.affine_det_ratio*dA for c in
            F._ccp_q1_lcfs_red_midpoint_children(x,dx,nodes3,weights3))
    end
    for h in (1e-5,5e-6)
        plus=ntuple(i->ntuple(k->points[i][k]+h*velocities[i][k],2),3)
        minus=ntuple(i->ntuple(k->points[i][k]-h*velocities[i][k],2),3)
        fd=(sum(c.affine_det_ratio*area(plus) for c in children)-
            sum(c.affine_det_ratio*area(minus) for c in children))/(2h)
        @test isapprox(fd,parent_darea;rtol=5e-6,atol=1e-12)
        @test isapprox(mapped_area_tangent(plus,velocities),parent_darea;rtol=5e-6,atol=1e-12)
        @test isapprox(mapped_area_tangent(minus,velocities),parent_darea;rtol=5e-6,atol=1e-12)
    end

    reversed=F._ccp_q1_lcfs_red_midpoint_children(reverse(points),reverse(velocities),nodes3,weights3)
    @test length(reversed)==4 && all(c.affine_det_ratio==0.25 for c in reversed)
    @test sum(c.affine_det_ratio*area(reverse(points)) for c in reversed)==area(reverse(points))
    @test_throws ArgumentError F._ccp_q1_lcfs_red_midpoint_children((points[1],points[2]),(velocities[1],velocities[2]),nodes3,weights3)

    nodes2,weights2=F._ccp_q1_green_gauss(2)
    target=(1.9,0.5);dtarget=(0.03,-0.02)
    bounds=(1.0,2.0,-0.2,0.2);columns=(1,2,3,4)
    current=fill(1e5,4);dcurrent=fill(1e3,4);mu0=4*pi*1e-7
    affine_calls=Ref(0);world_calls=Ref(0)
    for child in children
        affine_response=F._ccp_q1_lcfs_duffy_triangle_directional(target,dtarget,
            child.points[1],child.velocities[1],child.points[2],child.velocities[2],
            child.points[3],child.velocities[3],bounds,columns,current,dcurrent,mu0,
            2,nodes2,weights2,affine_calls,64;
            affine_parent_points=child.parent_points,
            affine_parent_velocities=child.parent_velocities,
            affine_vertex_weights=child.vertex_weights,
            affine_det_ratio=child.affine_det_ratio)
        world_response=F._ccp_q1_lcfs_duffy_triangle_directional(target,dtarget,
            child.points[1],child.velocities[1],child.points[2],child.velocities[2],
            child.points[3],child.velocities[3],bounds,columns,current,dcurrent,mu0,
            2,nodes2,weights2,world_calls,64)
        @test affine_response.status===:evaluated && world_response.status===:evaluated
        @test affine_response.kernel_calls==4 && world_response.kernel_calls==4
        @test all(isapprox(affine_response.field[k],world_response.field[k];rtol=1e-10,atol=1e-14)
            for k in 1:2)
        @test all(isapprox(affine_response.directional[k],world_response.directional[k];rtol=1e-10,atol=1e-14)
            for k in 1:2)
    end
    @test affine_calls[]==16 && world_calls[]==16

    # The first red child retains the target as its exact first vertex; compare
    # the affine-map path against the original target-star Duffy branch.
    star=children[1];star_calls=Ref(0);star_world_calls=Ref(0)
    star_affine=F._ccp_q1_lcfs_duffy_triangle_directional(points[1],velocities[1],
        star.points[1],star.velocities[1],star.points[2],star.velocities[2],
        star.points[3],star.velocities[3],bounds,columns,current,dcurrent,mu0,
        2,nodes2,weights2,star_calls,64;affine_parent_points=star.parent_points,
        affine_parent_velocities=star.parent_velocities,
        affine_vertex_weights=star.vertex_weights,affine_det_ratio=star.affine_det_ratio)
    star_world=F._ccp_q1_lcfs_duffy_triangle_directional(points[1],velocities[1],
        star.points[1],star.velocities[1],star.points[2],star.velocities[2],
        star.points[3],star.velocities[3],bounds,columns,current,dcurrent,mu0,
        2,nodes2,weights2,star_world_calls,64)
    @test star.points[1]===points[1] && star.velocities[1]===velocities[1]
    @test star_affine.status===:evaluated && star_world.status===:evaluated
    @test star_affine.kernel_calls==4 && star_world.kernel_calls==4
    @test all(isapprox(star_affine.field[k],star_world.field[k];rtol=1e-10,atol=1e-14) for k in 1:2)
    @test all(isapprox(star_affine.directional[k],star_world.directional[k];rtol=1e-10,atol=1e-14) for k in 1:2)

    radial_nodes,radial_weights=F._ccp_q1_duffy_radial_rule(nodes3,weights3,true)
    @test isapprox(sum(radial_weights .* radial_nodes.^2),1/3;rtol=128eps(Float64),atol=128eps(Float64))
    @test star.vertex_weights[1]==(1.0,0.0,0.0)
    @test star.points[1]===points[1] && star.velocities[1]===velocities[1]
    function singular_affine_field(parent,current_values)
        zero_parent_velocity=ntuple(_->(0.0,0.0),3)
        child=first(F._ccp_q1_lcfs_red_midpoint_children(parent,zero_parent_velocity,nodes3,weights3))
        target_at_anchor=parent[1];zero_target=(0.0,0.0);calls=Ref(0)
        response=F._ccp_q1_lcfs_duffy_triangle_directional(target_at_anchor,zero_target,
            child.points[1],zero_target,child.points[2],zero_target,child.points[3],zero_target,
            bounds,columns,current_values,zeros(length(current_values)),mu0,2,nodes2,weights2,calls,64;
            affine_parent_points=parent,affine_parent_velocities=zero_parent_velocity,
            affine_vertex_weights=child.vertex_weights,affine_det_ratio=child.affine_det_ratio)
        response.status===:evaluated && response.kernel_calls==4 || error("singular affine endpoint field unavailable")
        response.field
    end
    function anchored_local_node(s,t)
        local_barycentric=(1-s,s*(1-t),s*t)
        parent_barycentric=ntuple(j->sum(local_barycentric[i]*star.vertex_weights[i][j] for i in 1:3),3)
        x=(points[1][1]+parent_barycentric[2]*(points[2][1]-points[1][1])+parent_barycentric[3]*(points[3][1]-points[1][1]),
            points[1][2]+parent_barycentric[2]*(points[2][2]-points[1][2])+parent_barycentric[3]*(points[3][2]-points[1][2]))
        dx=(velocities[1][1]+parent_barycentric[2]*(velocities[2][1]-velocities[1][1])+parent_barycentric[3]*(velocities[3][1]-velocities[1][1]),
            velocities[1][2]+parent_barycentric[2]*(velocities[2][2]-velocities[1][2])+parent_barycentric[3]*(velocities[3][2]-velocities[1][2]))
        x,dx
    end
    anchor,anchor_direction=anchored_local_node(0.0,nodes2[1])
    @test anchor==points[1] && anchor_direction==velocities[1]
    first_local,first_local_direction=anchored_local_node(radial_nodes[1],nodes2[1])
    last_local,last_local_direction=anchored_local_node(radial_nodes[end],nodes2[end])
    @test 0<radial_nodes[1]<radial_nodes[end]<1
    @test all(isfinite,(first_local...,first_local_direction...,last_local...,last_local_direction...))
    @test first_local!=last_local && first_local_direction!=last_local_direction
    for h in (1e-5,5e-6)
        plus_parent=ntuple(i->ntuple(k->points[i][k]+h*velocities[i][k],2),3)
        minus_parent=ntuple(i->ntuple(k->points[i][k]-h*velocities[i][k],2),3)
        plus_current=current .+ h .* dcurrent;minus_current=current .- h .* dcurrent
        plus_field=singular_affine_field(plus_parent,plus_current)
        minus_field=singular_affine_field(minus_parent,minus_current)
        centered=(plus_field .- minus_field)./(2h)
        @test all(isapprox(centered[k],star_affine.directional[k];rtol=5e-6,atol=1e-12) for k in 1:2)
    end
    calls=Ref(0)
    degenerate=F._ccp_q1_lcfs_duffy_triangle_directional((1.5,0.5),(0.0,0.0),
        (1.25,0.0),(0.0,0.0),(1.5,0.0),(0.0,0.0),(1.75,0.0),(0.0,1.0),
        (1.0,2.0,-1.0,1.0),(1,2,3,4),zeros(4),zeros(4),4*pi*1e-7,
        2,nodes2,weights2,calls,100)
    @test degenerate.status===:typed_absent
    @test degenerate.reason===:duffy_degenerate_triangle_has_nonzero_first_order_area
    @test calls[]==0
    incomplete_calls=Ref(0)
    incomplete_map=F._ccp_q1_lcfs_duffy_triangle_directional(target,dtarget,
        points[1],velocities[1],points[2],velocities[2],points[3],velocities[3],
        bounds,columns,current,dcurrent,mu0,2,nodes2,weights2,incomplete_calls,64;
        affine_parent_points=points)
    @test incomplete_map.status===:typed_absent
    @test incomplete_map.reason===:duffy_affine_child_map_incomplete
    @test incomplete_calls[]==0

    # The second level is composed directly in the original parent chart. This
    # avoids recursively rounding world-coordinate midpoints at R~1 m.
    leaves=F._ccp_q1_lcfs_red_midpoint_children(points,velocities,nodes3,weights3;
        refinement_levels=2)
    @test leaves isa Tuple && length(leaves)==16
    @test Tuple(leaf.child_path for leaf in leaves)==Tuple((i,j) for i in 1:4 for j in 1:4)
    @test all(leaf.parent_points===points && leaf.parent_velocities===velocities for leaf in leaves)
    @test all(leaf.affine_det_ratio==1/16 for leaf in leaves)
    @test sum(leaf.affine_det_ratio for leaf in leaves)==1.0
    @test sum(leaf.affine_det_ratio*parent_area for leaf in leaves)==parent_area
    @test sum(leaf.affine_det_ratio*parent_darea for leaf in leaves)==parent_darea
    @test all(leaf.points[i]==ntuple(k->points[1][k]+
        leaf.vertex_weights[i][2]*(points[2][k]-points[1][k])+
        leaf.vertex_weights[i][3]*(points[3][k]-points[1][k]),2)
        for leaf in leaves,i in 1:3)
    @test all(leaf.velocities[i]==ntuple(k->velocities[1][k]+
        leaf.vertex_weights[i][2]*(velocities[2][k]-velocities[1][k])+
        leaf.vertex_weights[i][3]*(velocities[3][k]-velocities[1][k]),2)
        for leaf in leaves,i in 1:3)
    leaf_world_areas=Tuple(2area(leaf.points) for leaf in leaves)
    leaf_world_dareas=Tuple(F._ccp_q1_lcfs_triangle_signed_area(leaf.points,leaf.velocities)[2]
        for leaf in leaves)
    @test all(isapprox(leaf_world_areas[i],2leaves[i].affine_det_ratio*parent_area;
        rtol=5e-6,atol=1e-18) for i in eachindex(leaves))
    @test all(isapprox(leaf_world_dareas[i],leaves[i].affine_det_ratio*parent_darea;
        rtol=5e-6,atol=1e-12) for i in eachindex(leaves))
    @test all(abs(leaf_world_areas[i])>256eps(Float64)*world_scale^2 for i in eachindex(leaves))
    @test isapprox(sum(leaf_world_areas),2parent_area;rtol=5e-6,atol=1e-18)
    @test isapprox(sum(leaf_world_dareas),parent_darea;rtol=5e-6,atol=1e-12)

    # Exactly one second-level leaf retains the moving singular target anchor.
    two_level_star=only(leaf for leaf in leaves if leaf.child_path==(1,1))
    @test two_level_star.points[1]===points[1]
    @test two_level_star.velocities[1]===velocities[1]
    two_level_calls=Ref(0)
    two_level_directional=zeros(2);two_level_field=zeros(2)
    for leaf in leaves
        response=F._ccp_q1_lcfs_duffy_triangle_directional(points[1],velocities[1],
            leaf.points[1],leaf.velocities[1],leaf.points[2],leaf.velocities[2],
            leaf.points[3],leaf.velocities[3],bounds,columns,current,dcurrent,mu0,
            2,nodes2,weights2,two_level_calls,1024;
            affine_parent_points=leaf.parent_points,
            affine_parent_velocities=leaf.parent_velocities,
            affine_vertex_weights=leaf.vertex_weights,affine_det_ratio=leaf.affine_det_ratio)
        @test response.status===:evaluated && response.kernel_calls==4
        two_level_field .+= response.field
        two_level_directional .+= response.directional
    end
    @test two_level_calls[]==64
    function two_level_singular_field(x,dx,source_current)
        refined=F._ccp_q1_lcfs_red_midpoint_children(x,dx,nodes3,weights3;
            refinement_levels=2)
        target_at_anchor=x[1];dtarget_at_anchor=dx[1]
        total=zeros(2);calls=Ref(0)
        for leaf in refined
            response=F._ccp_q1_lcfs_duffy_triangle_directional(target_at_anchor,dtarget_at_anchor,
                leaf.points[1],leaf.velocities[1],leaf.points[2],leaf.velocities[2],
                leaf.points[3],leaf.velocities[3],bounds,columns,source_current,dcurrent,
                mu0,2,nodes2,weights2,calls,1024;
                affine_parent_points=leaf.parent_points,
                affine_parent_velocities=leaf.parent_velocities,
                affine_vertex_weights=leaf.vertex_weights,affine_det_ratio=leaf.affine_det_ratio)
            response.status===:evaluated || error("two-level singular affine response unavailable")
            total .+= response.field
        end
        calls[]==64 || error("two-level singular affine call count changed")
        total
    end
    for h in (1e-5,5e-6)
        plus_parent=ntuple(i->ntuple(k->points[i][k]+h*velocities[i][k],2),3)
        minus_parent=ntuple(i->ntuple(k->points[i][k]-h*velocities[i][k],2),3)
        plus_current=current .+ h .* dcurrent;minus_current=current .- h .* dcurrent
        plus_field=two_level_singular_field(plus_parent,velocities,plus_current)
        minus_field=two_level_singular_field(minus_parent,velocities,minus_current)
        centered=(plus_field .- minus_field)./(2h)
        @test all(isapprox(centered[k],two_level_directional[k];rtol=5e-6,atol=1e-12) for k in 1:2)
    end

    # Generic non-dyadic coordinates and nonzero R/Z velocity at every vertex.
    general_points=((0.13,0.27),(0.71,0.34),(0.42,0.91))
    general_velocities=((0.6685319224373205,1.1268017351547042),
        (1.350475831663482,-1.4437050719762548),(-1.664437616087581,0.659297127983618))
    @test all(x->x[1]!=0 && x[2]!=0,general_velocities)
    general_area,general_darea=F._ccp_q1_lcfs_triangle_signed_area(general_points,general_velocities)
    general_leaves=F._ccp_q1_lcfs_red_midpoint_children(general_points,general_velocities,
        nodes3,weights3;refinement_levels=2)
    @test length(general_leaves)==16
    @test all(x.affine_det_ratio==1/16 for x in general_leaves)
    @test sum(x.affine_det_ratio for x in general_leaves)==1.0
    general_area_sum=sum(x.affine_det_ratio*general_area for x in general_leaves)
    general_darea_sum=sum(x.affine_det_ratio*general_darea for x in general_leaves)
    general_area_tol=256eps(Float64)*max(abs(general_area),
        sum(abs(x.affine_det_ratio*general_area) for x in general_leaves),1e-300)
    general_darea_tol=256eps(Float64)*max(abs(general_darea),
        sum(abs(x.affine_det_ratio*general_darea) for x in general_leaves),1e-300)
    @test abs(general_area_sum-general_area)<=general_area_tol
    @test abs(general_darea_sum-general_darea)<=general_darea_tol
    for h in (1e-5,5e-6)
        plus_points=ntuple(i->ntuple(k->general_points[i][k]+h*general_velocities[i][k],2),3)
        minus_points=ntuple(i->ntuple(k->general_points[i][k]-h*general_velocities[i][k],2),3)
        plus_area,plus_darea=F._ccp_q1_lcfs_triangle_signed_area(plus_points,general_velocities)
        minus_area,minus_darea=F._ccp_q1_lcfs_triangle_signed_area(minus_points,general_velocities)
        plus_leaves=F._ccp_q1_lcfs_red_midpoint_children(plus_points,general_velocities,
            nodes3,weights3;refinement_levels=2)
        minus_leaves=F._ccp_q1_lcfs_red_midpoint_children(minus_points,general_velocities,
            nodes3,weights3;refinement_levels=2)
        @test length(plus_leaves)==16 && length(minus_leaves)==16
        plus_area_sum=sum(x.affine_det_ratio*plus_area for x in plus_leaves)
        minus_area_sum=sum(x.affine_det_ratio*minus_area for x in minus_leaves)
        plus_darea_sum=sum(x.affine_det_ratio*plus_darea for x in plus_leaves)
        minus_darea_sum=sum(x.affine_det_ratio*minus_darea for x in minus_leaves)
        @test abs(plus_area_sum-plus_area)<=256eps(Float64)*max(abs(plus_area),1e-300)
        @test abs(minus_area_sum-minus_area)<=256eps(Float64)*max(abs(minus_area),1e-300)
        @test abs(plus_darea_sum-plus_darea)<=256eps(Float64)*max(abs(plus_darea),1e-300)
        @test abs(minus_darea_sum-minus_darea)<=256eps(Float64)*max(abs(minus_darea),1e-300)
        centered_area=(plus_area_sum-minus_area_sum)/(2h)
        @test isapprox(centered_area,general_darea;rtol=5e-6,atol=1e-12)
    end
end


function test_q1_lcfs_cutcell_integral_contract(F)
    R=[1.0,2.0];Z=[0.0,1.0];mask=trues(4)
    polygon=[(1.1,0.1),(1.7,0.2),(1.3,0.8)]
    ordinary=F._ccp_q1_lcfs_cutcell_support_map(R,Z,mask,polygon)
    @test ordinary.status===:evaluated_candidate_lcfs_q1_cutcell_geometry
    @test length(ordinary.cells)==1
    @test !hasproperty(only(ordinary.cells),:q1_basis_integral_inside_LCFS_m2)
    support=F._ccp_q1_lcfs_cutcell_support_map(R,Z,mask,polygon;include_q1_integrals=true)
    @test support.status===:evaluated_candidate_lcfs_q1_cutcell_geometry
    cell=only(support.cells)
    values=[0.0,0.0,1.0,2.0] # nodal samples of the manufactured bilinear Q1 field R*Z
    q1_integral=sum(values[i]*cell.q1_basis_integral_inside_LCFS_m2[i] for i in eachindex(values))
    area=abs((polygon[2][1]-polygon[1][1])*(polygon[3][2]-polygon[1][2])-
        (polygon[2][2]-polygon[1][2])*(polygon[3][1]-polygon[1][1]))/2
    exact=area/12*((sum(first.(polygon)))*(sum(last.(polygon)))+
        sum(p[1]*p[2] for p in polygon))
    @test isapprox(q1_integral,exact;rtol=128eps(Float64),atol=128eps(Float64))
    derivative=sum(values[i]*cell.d_q1_basis_integral_d_LCFS_vertices_m[i,3]
        for i in eachindex(values))
    function manufactured_integral(points)
        m=F._ccp_q1_lcfs_cutcell_support_map(R,Z,mask,points;include_q1_integrals=true)
        sum(values[i]*only(m.cells).q1_basis_integral_inside_LCFS_m2[i] for i in eachindex(values))
    end
    h=1e-6;plus=copy(polygon);minus=copy(polygon)
    plus[2]=(plus[2][1]+h,plus[2][2]);minus[2]=(minus[2][1]-h,minus[2][2])
    @test isapprox((manufactured_integral(plus)-manufactured_integral(minus))/(2h),derivative;
        rtol=1e-6,atol=1e-9)
    reverse_support=F._ccp_q1_lcfs_cutcell_support_map(R,Z,mask,reverse(polygon);
        include_q1_integrals=true)
    reverse_integral=sum(values[i]*only(reverse_support.cells).q1_basis_integral_inside_LCFS_m2[i] for i in eachindex(values))
    @test isapprox(reverse_integral,q1_integral;rtol=128eps(Float64),atol=128eps(Float64))
    kink=[(1.0,0.2),(1.7,0.2),(1.3,0.8)]
    nondifferentiable=F._ccp_q1_lcfs_cutcell_support_map(R,Z,mask,kink;
        include_q1_integrals=true)
    @test only(nondifferentiable.cells).d_q1_basis_integral_d_LCFS_vertices_m===nothing
    test_q1_lcfs_red_child_parent_affine_geometry(F)
end

Base.@noinline Base.@nospecializeinfer function test_actual_lcfs_curl_current_rows(F,component,payload,provider,trace)
    Base.@nospecialize F component payload provider trace
    current_trace_timing=get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1"
    if current_trace_timing
        println("G2_GLOBAL_ASSEMBLE_TEST_BEGIN phase=lcfs_current_test_helper unix_ns=",time_ns())
        flush(stdout)
    end
    precheck_mode=get(ENV,"FUSION_G2_PRECHECK_MODE","")
    short_model_mode=precheck_mode=="global_model_short"
    reuse_local_fd_mode=g2_precheck_reuse_qualified_local_fd(precheck_mode,component,provider)
    cut_contract_started=current_trace_timing ? time_ns() : UInt64(0)
    test_q1_lcfs_cutcell_integral_contract(F)
    if current_trace_timing
        println("G2_GLOBAL_ASSEMBLE_TEST_END phase=q1_lcfs_cutcell_contract elapsed_ns=",time_ns()-cut_contract_started)
        flush(stdout)
    end
    if provider.current_topology===nothing
        @test provider.conservation_ids==("profile_Romberg_toroidal_current_normalization",)
        @test provider.added_global_conservation_ids==()
        @test provider.conservation_row_units==("A",)
        @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,
            (plasma_current_topology=(model=:ideal_axisymmetric_periodic_lcfs_no_normal_current,),)))
    else
        @test length(provider.conservation_ids)==65
        @test length(provider.added_global_conservation_ids)==64
        @test provider.conservation_row_units==("A",ntuple(_->"A m^-2",64)...)
        @test provider.return_current_path===:periodic_toroidal_plasma_with_zero_normal_current_at_LCFS
        @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,
            (declared_return_current_path=:foreign_return_path,)))
    end
    if provider.current_topology===nothing
        @test !hasproperty(provider,:periodic_cut_current_diagnostic)
    else
        S=F.InHouseCoupledMHDGlobalSolveV1
        eid_started=current_trace_timing ? time_ns() : UInt64(0)
        current_trace_timing && println("G2_GLOBAL_ASSEMBLE_TEST_BEGIN phase=conservation_evaluator_identity unix_ns=",eid_started)
        current_trace_timing && flush(stdout)
        eid=S._callback_identity(provider.conservation_evaluator)
        if current_trace_timing
            println("G2_GLOBAL_ASSEMBLE_TEST_END phase=conservation_evaluator_identity elapsed_ns=",time_ns()-eid_started)
            flush(stdout)
        end
        oid_started=current_trace_timing ? time_ns() : UInt64(0)
        current_trace_timing && println("G2_GLOBAL_ASSEMBLE_TEST_BEGIN phase=jacobian_oracle_identity unix_ns=",oid_started)
        current_trace_timing && flush(stdout)
        oid=S._callback_identity(provider.jacobian_oracle)
        if current_trace_timing
            println("G2_GLOBAL_ASSEMBLE_TEST_END phase=jacobian_oracle_identity elapsed_ns=",time_ns()-oid_started)
            flush(stdout)
        end
        context=(candidate_hash=component.candidate_hash,
            provider_semantic_hash=string(F.canonical_hash(F.semantic_view(trace))),
            provider_context_hash=string(F.canonical_hash((eid,oid))),
            jacobian_oracle_hash=string(F.canonical_hash(oid)))
        current_trace_timing && println("G2_GLOBAL_ASSEMBLE_TEST_READY phase=periodic_cut_current_before_g2_precheck_label unix_ns=",time_ns())
        current_trace_timing && flush(stdout)
        # Opt-in saved-step replay through the actual live provider consumer.
        # This reuses the original R4 numeric capture only as its state input;
        # provider data, identity context, cut evaluation, and Jn consumers are
        # freshly constructed by this test run.
        r4_cut_state=component.initial_state
        r4_cut_state_identity=:live_component_initial_state
        if get(ENV,"FUSION_G2_PERIODIC_CUT_R4_STATE","0")=="1"
            capture_path=get(ENV,"FUSION_G2_PERIODIC_CUT_R4_CAPTURE_PATH","")
            isempty(capture_path) && error("R4 periodic-cut replay requires its pinned global numeric capture path")
            isfile(capture_path) || error("R4 periodic-cut replay capture is missing")
            expected_capture_sha="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec"
            _g2_global_diag_result_file_sha256(capture_path)==expected_capture_sha ||
                error("R4 periodic-cut replay capture SHA-256 differs")
            saved= open(Serialization.deserialize,capture_path,"r")
            saved.schema=="g2-global-diagnostic-numeric-matrices-v3" ||
                error("R4 periodic-cut replay capture schema differs")
            saved.replay_metadata.schema=="g2-global-diagnostic-replay-metadata-v1" ||
                error("R4 periodic-cut replay metadata schema differs")
            saved.replay_metadata.consumer_identity.scope===:diagnostic_incomplete_global_assembly ||
                error("R4 periodic-cut input must remain labeled incomplete diagnostic capture")
            saved.replay_metadata.validation_stage===:pre_global_assembler_oracles_pending ||
                error("R4 periodic-cut state must remain labeled pre-global-assembler-oracles-pending")
            saved_id=saved.replay_metadata.consumer_identity
            saved_id.candidate_hash==component.candidate_hash &&
                saved_id.component_context_hash==component.context_hash &&
                saved_id.trace_hash==trace.trace_hash &&
                saved_id.current_operator_model_id===component.current_operator_model_id &&
                saved_id.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id ||
                error("R4 periodic-cut state capture does not bind to the live provider source identity")
            length(saved.state)==length(component.initial_state)==69_447 ||
                error("R4 periodic-cut state dimension differs from the live component")
            saved.state!=component.initial_state || error("R4 periodic-cut replay did not select the changed R4 state")
            r4_cut_state=Float64.(collect(saved.state))
            r4_cut_state_identity=(role=:pinned_R4_preoracle_diagnostic_state,
                capture_path=abspath(capture_path),capture_sha256=expected_capture_sha,
                state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,r4_cut_state))),
                capture_scope=:diagnostic_incomplete_global_assembly)
            saved=nothing;saved_id=nothing;GC.gc(true)
        end
        cut=if get(ENV,"FUSION_G2_PRECHECK_MODE","") in
                ("global_diagnostic","current_topology_smoke","global_model_short",
                    "global_first_assembly_short")
            g2_precheck_timed("global_diagnostic_periodic_cut_current",()->
                provider.periodic_cut_current_diagnostic(r4_cut_state,context))
        else
            provider.periodic_cut_current_diagnostic(r4_cut_state,context)
        end
         if get(ENV,"FUSION_G2_PERIODIC_CUT_R4_STATE","0")=="1"
             # Preserve raw callback output before any cut-field read/assertion.
             result_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
             !isempty(result_leaf) && isdir(result_leaf) ||
                 error("periodic-cut raw capture requires the existing bounded result leaf")
             raw_dir=joinpath(result_leaf,"result_data")
             mkpath(raw_dir)
             raw_cut_path=joinpath(raw_dir,"current_periodic_cut_R4_cut_raw_v1.jls")
             ispath(raw_cut_path) && error("refusing to overwrite raw periodic-cut callback capture")
             r4_cut_source_ids=(candidate_hash=component.candidate_hash,
                 component_context_hash=component.context_hash,trace_hash=trace.trace_hash,
                 provider_semantic_hash=context.provider_semantic_hash,
                 provider_context_hash=context.provider_context_hash,
                 jacobian_oracle_hash=context.jacobian_oracle_hash,
                 current_operator_model_id=component.current_operator_model_id,
                 hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
                 native_field_model_id=provider.lcfs_current_numeric_data.native_field_model_id)
             raw_cut=(schema=:current_periodic_cut_R4_cut_raw_v1,
                 validation_stage=:pre_global_assembler_oracles_pending,
                 state=copy(r4_cut_state),state_capture_binding=r4_cut_state_identity,
                 cut=cut,source_ids=r4_cut_source_ids)
             open(raw_cut_path,"w") do io
                 Serialization.serialize(io,raw_cut);flush(io)
             end
             println("CURRENT_PERIODIC_CUT_R4_RAW_CAPTURE="*F.canonical_json((
                 path=abspath(raw_cut_path),bytes=filesize(raw_cut_path),
                 sha256=_g2_global_diag_result_file_sha256(raw_cut_path),
                 validation_stage=raw_cut.validation_stage,source_ids=r4_cut_source_ids)));flush(stdout)
         end
        cut_ndof=length(component.initial_state)
        cut_status=get(cut,:status,:missing_status)
        cut_total_jacobian=get(cut,:jacobian,nothing)
        cut_direct_jacobian=get(cut,:current_trace_J_weighted_jacobian,nothing)
        cut_geometry_jacobian=get(cut,:moving_geometry_jacobian,nothing)
        cut_sparse_row_abi(x)=x isa AbstractMatrix && SparseArrays.issparse(x) &&
            size(x)==(1,cut_ndof)
        cut_total_row_abi=cut_sparse_row_abi(cut_total_jacobian)
        cut_direct_row_abi=cut_sparse_row_abi(cut_direct_jacobian)
        cut_geometry_row_abi=cut_sparse_row_abi(cut_geometry_jacobian)
        cut_sparse_jacobian=hasproperty(cut,:jacobian) && cut_total_jacobian isa AbstractMatrix && SparseArrays.issparse(cut_total_jacobian)
        cut_jacobian_nnz=cut_sparse_jacobian ? SparseArrays.nnz(cut_total_jacobian) : nothing
        cut_jacobian_absence=get(cut,:jacobian_absence,get(cut,:reason,:missing_jacobian_abi))
        cut_jacobian_status=:not_evaluated
        cut_jacobian_abi_valid=false
        if cut_status===:evaluated_Jphi_Q1_LCFS_cut_current
            if !hasproperty(cut,:jacobian)
                cut_jacobian_status=:invalid_jacobian_abi
                cut_jacobian_absence=:jacobian_field_absent
            elseif cut_total_jacobian===:typed_absent
                cut_jacobian_status=:typed_absent
                cut_jacobian_abi_valid=true
            elseif !cut_sparse_jacobian
                cut_jacobian_status=:invalid_jacobian_abi
                cut_jacobian_absence=:jacobian_not_sparse_or_typed_absent
            elseif !cut_total_row_abi
                cut_jacobian_status=:invalid_jacobian_abi
                cut_jacobian_absence=:jacobian_shape_invalid
            elseif !cut_direct_row_abi || !cut_geometry_row_abi
                cut_jacobian_status=:invalid_jacobian_abi
                cut_jacobian_absence=:decomposition_missing_non_sparse_or_shape_invalid
            else
                cut_jacobian_status=:available_unvalidated
                cut_jacobian_abi_valid=true
            end
        end
        cut_declared_identification=get(cut,:declared_periodic_identification,nothing)
        cut_declared_status=cut_declared_identification===nothing ? nothing :
            get(cut_declared_identification,:status,nothing)
        cut_summary=(status=cut_status,
            current_path=:periodic_native_Q1_cut_current_diagnostic,
            current_interpolation=get(cut,:current_interpolation,nothing),
            current_integral_A=get(cut,:current_integral_A,nothing),
            romberg_current_A=get(cut,:romberg_current_A,nothing),
            current_integral_minus_Romberg_A=get(cut,:current_integral_minus_Romberg_A,nothing),
            jacobian_status=cut_jacobian_status,
            jacobian_abi_valid=cut_jacobian_abi_valid,
            total_jacobian_row_abi=cut_total_row_abi,
            direct_jacobian_row_abi=cut_direct_row_abi,
            geometry_jacobian_row_abi=cut_geometry_row_abi,
            jacobian_absence=cut_jacobian_absence,
            jacobian_nnz=cut_jacobian_nnz,
            declared_periodic_identification_status=cut_declared_status,
            no_jacobian_credit=true,jacobian_validation=:selected_consumer_fd_only_if_available,
            global_topology_closed=get(cut,:global_topology_closed,false),
            physical_return_current_claim=get(cut,:physical_return_current_claim,false),
            independent_return_current_evidence=get(cut,:independent_return_current_evidence,false),
            closure_evidence_created=get(cut,:closure_evidence_created,false))
        println("CURRENT_CUT_DIAGNOSTIC="*F.canonical_json(cut_summary));flush(stdout)
        if get(ENV,"FUSION_G2_PERIODIC_CUT_R4_STATE","0")=="1"
            # The original 65-row current consumer supplies the registered Ip
            # row and all 64 Jn rows at exactly the state used by the periodic
            # cut callback. The independent trace call exposes its actual
            # declared error-budget fields; both budgets remain typed unknown.
            closures=NamedTuple{F._CCP_AXISYMMETRIC_MISSING_CLOSURES}(ntuple(_->nothing,5))
            live_current=provider.conservation_evaluator(r4_cut_state,closures,context)
            live_trace=component.lcfs_state_F_curl_trace(r4_cut_state;
                with_jacobian=false,with_cut_jacobian=false)
            result_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
            !isempty(result_leaf) && isdir(result_leaf) ||
                error("periodic-cut raw capture requires the existing bounded result leaf")
            raw_dir=joinpath(result_leaf,"result_data")
            mkpath(raw_dir)
            raw_path=joinpath(raw_dir,"current_periodic_cut_R4_live_consumer_raw_v1.jls")
            ispath(raw_path) && error("refusing to overwrite periodic-cut raw consumer capture")
            raw_capture=(schema=:current_periodic_cut_R4_live_consumer_raw_v1,
                validation_stage=:pre_global_assembler_oracles_pending,
                state=copy(r4_cut_state),state_capture_binding=r4_cut_state_identity,
                cut=cut,current=live_current,trace=live_trace,
                source_ids=r4_cut_source_ids)
            open(raw_path,"w") do io
                Serialization.serialize(io,raw_capture);flush(io)
            end
            raw_sha=_g2_global_diag_result_file_sha256(raw_path)
            println("CURRENT_PERIODIC_CUT_R4_LIVE_RAW_CAPTURE="*F.canonical_json((
                path=abspath(raw_path),bytes=filesize(raw_path),sha256=raw_sha,
                validation_stage=raw_capture.validation_stage,source_ids=r4_cut_source_ids)));flush(stdout)
            @test cut.status===:evaluated_Jphi_Q1_LCFS_cut_current
            @test live_trace.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
            @test length(provider.conservation_ids)==65
            @test length(provider.added_global_conservation_ids)==64
            @test size(live_current.residual)==(65,)
            @test length(live_trace.Jn_A_per_m2)==64
            @test live_current.residual[2:end]==live_trace.Jn_A_per_m2
            @test all(isfinite,live_current.residual[2:end])
            @test isfinite(cut.current_integral_A) && isfinite(cut.romberg_current_A)
            @test cut.current_integral_minus_Romberg_A==cut.current_integral_A-cut.romberg_current_A
            @test cut.declared_periodic_identification.constructed_outward_pair==
                (-cut.current_integral_A,cut.current_integral_A)
            @test cut.declared_periodic_identification.cancellation_A==0.0
            live_periodic_current=(state_binding=r4_cut_state_identity,
                cut_status=cut.status,cut_interpolation=cut.current_interpolation,
                cut_current_integral_A=cut.current_integral_A,
                normalization_Romberg_current_A=cut.romberg_current_A,
                cut_minus_normalization_A=cut.current_integral_minus_Romberg_A,
                declared_periodic_pair=cut.declared_periodic_identification.constructed_outward_pair,
                declared_pair_cancellation_A=cut.declared_periodic_identification.cancellation_A,
                declared_pair_is_definition_not_independent_conservation=true,
                conservation_scope=:Q1_clipped_cut_integral_vs_existing_profile_Romberg_row,
                conservation_difference_is_zero=cut.current_integral_minus_Romberg_A==0.0,
                Jn_row_ids=Tuple(provider.conservation_ids[2:end]),
                Jn_A_per_m2=Tuple(Float64.(live_current.residual[2:end])),
                Jn_max_abs_A_per_m2=maximum(abs,live_current.residual[2:end];init=0.0),
                Jn_integrated_current_A=live_trace.integrated_current_A,
                Jn_budget_A_per_m2=live_trace.residual_budget_A_per_m2,
                Jn_acceptance_threshold_A_per_m2=live_trace.acceptance_threshold_A_per_m2,
                Jn_budget_status=live_trace.Jn_acceptance_protocol.status,
                Jn_acceptance_protocol=live_trace.Jn_acceptance_protocol,
                Jn_scientific_acceptance=live_trace.Jn_scientific_acceptance,
                current_topology_closed=false,physical_return_current_claim=false,
                independent_return_current_evidence=false,solver_rows_added=0,
                state_capture_scope=:diagnostic_incomplete_global_assembly)
            println("CURRENT_PERIODIC_CUT_R4_LIVE_CONSUMER="*F.canonical_json(live_periodic_current));flush(stdout)
        end
        if cut_status===:evaluated_Jphi_Q1_LCFS_cut_current
            @test cut.current_interpolation===:piecewise_native_Q1_extension_not_exact_continuous_GS4_current
            @test isfinite(cut.current_integral_A) && isfinite(cut.current_integral_minus_Romberg_A)
            @test !cut.global_topology_closed && !cut.physical_return_current_claim
            @test !get(cut,:independent_return_current_evidence,true)
            @test !get(cut,:closure_evidence_created,true)
            identification=cut.declared_periodic_identification
            @test identification.status===:declared_periodic_identification
            @test identification.constructed_outward_pair==(-cut.current_integral_A,cut.current_integral_A)
            @test identification.cancellation_A==0.0 && !identification.independent_return_current_evidence
            native_map=identification.native_lcfs_cut_cells
            @test !isempty(native_map)
            @test propertynames(first(native_map))==(:native_cell,:native_node_ids,:q1_basis_columns)
        else
            @test cut.status===:evaluated_Jphi_Q1_LCFS_cut_current
        end
    end
    # Exercise the actual moving-LCFS residual kernel used by the topology-row
    # evaluator. The selected-column checks are consumer finite differences,
    # not a same-path oracle comparison or closure evidence.
    if get(ENV,"FUSION_G2_PRECHECK_MODE","")=="lcfs_exterior_field_selected_jacobian_smoke"
        exterior_data=provider.lcfs_current_numeric_data
        exterior_domain=exterior_data.state_domain
        x=component.initial_state;selected_ray=19;selected_psi_column=41032
        near_cut_r4_state_flag=get(ENV,"FUSION_G2_PRECHECK_NEAR_CUT_R4_LIVE_STATE","0")
        near_cut_r4_state_flag in ("0","1") ||
            error("FUSION_G2_PRECHECK_NEAR_CUT_R4_LIVE_STATE must be 0 or 1")
        if near_cut_r4_state_flag=="1"
            run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
            !isempty(run_leaf) && isdir(run_leaf) ||
                error("R4 live-state near-cut consumer requires the existing bounded result leaf")
            pin_path=joinpath(@__DIR__,"..","runs","e",
                "up2_continuous_psi_global_numeric_capture_20261012_r4",
                "preoracle_checkpoint","result_data","g2_global_diagnostic","numeric_matrices_v3.jls")
            pin_sha="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec"
            saved=_g2_global_diag_reload_matrices(pin_path;expected_sha256=pin_sha)
            meta=saved.replay_metadata
            meta.validation_stage===:pre_global_assembler_oracles_pending &&
                meta.consumer_identity.scope===:diagnostic_incomplete_global_assembly ||
                error("near-cut state input is outside the pinned R4 diagnostic scope")
            id=meta.consumer_identity
            id.candidate_hash==component.candidate_hash &&
                id.component_context_hash==component.context_hash && id.trace_hash==trace.trace_hash &&
                id.current_operator_model_id===component.current_operator_model_id &&
                id.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id ||
                error("R4 state candidate/context/operator identity differs from the live selected-GS component")
            live_state=copy(saved.state)
            length(live_state)==length(component.initial_state)==exterior_domain.ndof==69_447 &&
                all(isfinite,live_state) || error("R4 state does not match the live full-native state ABI")
            saved=nothing;meta=nothing;GC.gc(true)
            live_geometry=component.lcfs_dynamic_geometry_trace(live_state)
            live_geometry.status===:evaluated_dynamic_LCFS_geometry && live_geometry.mask_event===:unchanged ||
                error("R4 state does not produce checked same-state LCFS geometry")
            selected_psi_column in live_geometry.psi_global_dof_ids ||
                error("selected state DOF is absent from the producer's native psi-global-DOF map")
            live_direction=zeros(Float64,length(live_state));live_direction[selected_psi_column]=1.0
            live_prep=F._ccp_q1_lcfs_moving_geometry_directional_prepare(
                exterior_domain,live_state,live_direction,selected_ray)
            live_prep.status===:prepared && live_prep.domain===exterior_domain &&
                live_prep.state==live_state && live_prep.state_direction==live_direction &&
                live_prep.target_index==selected_ray &&
                live_prep.target==live_geometry.coordinates_RZ_m[selected_ray] ||
                error("fresh R4 live-state moving preparation is not bound to its real consumer state/map")
            result_dir=joinpath(run_leaf,"result_data","near_cut_r4_live_state")
            mkpath(result_dir)
            report_path=joinpath(result_dir,"live_state_ray19_consumer_v1.jls")
            ispath(report_path) && error("refusing to overwrite R4 live-state consumer report")
            result=component.lcfs_exterior_field_primal(live_state;ray_ids=(selected_ray,),order=8,
                max_kernel_calls=40_000_000,moving_preparation=live_prep,
                local_G_join=true,max_interval_ops=8_000_000)
            raw_path=joinpath(result_dir,"live_state_ray19_consumer_raw_v1.jls")
            ispath(raw_path) && error("refusing to overwrite R4 live-state raw consumer capture")
            raw_capture=(schema="actual-R4-live-state-ray19-Bout-raw-v1",
                state=live_state,state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,live_state))),
                candidate_hash=component.candidate_hash,context_hash=component.context_hash,
                trace_hash=trace.trace_hash,current_operator_model_id=component.current_operator_model_id,
                hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
                producer_psi_global_dof_ids=Tuple(live_geometry.psi_global_dof_ids),
                moving_prep_current=Tuple(live_prep.current),moving_prep_dcurrent=Tuple(live_prep.dcurrent),
                actual_one_ray_consumer_result=result)
            open(raw_path,"w") do io;Serialization.serialize(io,raw_capture);flush(io);end
            field(x,k,d=:typed_absent)=x isa NamedTuple && hasproperty(x,k) ? getproperty(x,k) : d
            join=field(result,:local_G_join_response)
            near_summary=_g2_near_cut_numeric_capture_summary(F,result,join,run_leaf)
            report=(schema="actual-R4-live-state-ray19-Bout-near-cut-consumer-v1",
                state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,live_state))),
                state_dofs=length(live_state),candidate_hash=component.candidate_hash,
                context_hash=component.context_hash,trace_hash=trace.trace_hash,
                raw_capture_path=raw_path,
                current_operator_model_id=component.current_operator_model_id,
                hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
                native_psi_global_dof_ids=Tuple(live_geometry.psi_global_dof_ids),
                selected_state_psi_dof=selected_psi_column,ray_id=selected_ray,
                preparation_state_matches=(live_prep.state==live_state),
                preparation_current=Tuple(live_prep.current),
                preparation_dcurrent=Tuple(live_prep.dcurrent),
                field_model=field(result,:field_model),ray_ids=field(result,:ray_ids),
                field_row_order=field(result,:field_row_order),
                normal_jacobian_column_order=field(result,:normal_jacobian_column_order),
                source_current_native_ids=field(result,:source_current_native_ids),
                source_current_jacobian=field(result,:native_source_current_jacobian_A_per_m2_per_state_dof),
                source_current_law=field(result,:source_current_law),
                target_coordinate_psi_global_dof_ids=field(result,:target_coordinate_psi_global_dof_ids),
                B_exterior_T=field(result,:B_exterior_T),
                B_exterior_jacobian=field(result,:B_exterior_jacobian),
                B_exterior_jacobian_candidate=field(result,:B_exterior_jacobian_candidate_T_per_state_dof),
                B_exterior_jacobian_candidate_shape=field(result,:B_exterior_jacobian_candidate_shape),
                B_exterior_jacobian_candidate_status=field(result,:B_exterior_jacobian_candidate_status),
                missing_B_exterior_jacobian_terms=field(result,:missing_B_exterior_jacobian_terms),
                producer_status=field(result,:status),join_status=field(join,:status),
                join_reason=field(join,:reason),near_cut_summary=near_summary,
                global_closure=false,physical_validation=false)
            open(report_path,"w") do io;Serialization.serialize(io,report);flush(io);end
            @test field(result,:status)===:diagnostic_selected_LCFS_exterior_field_primal
            @test field(join,:status)===:evaluated_near_cut_G_all_inventory_partial
            @test report.field_model===:clipped_Q1_plasma_volume_current_plus_exact_authored_PF_jet_plus_G3_TF_Fvac_over_R
            @test report.ray_ids==(selected_ray,) && report.field_row_order===:point_major_Br_Bphi_Bz
            @test report.target_coordinate_psi_global_dof_ids==report.native_psi_global_dof_ids
            @test report.source_current_law===:same_state_GS4_profile_Jphi_on_actual_clipped_Q1_support
            @test report.source_current_jacobian isa AbstractMatrix &&
                size(report.source_current_jacobian,2)==length(live_state) && all(isfinite,report.source_current_jacobian)
            @test report.B_exterior_jacobian_candidate isa AbstractMatrix &&
                size(report.B_exterior_jacobian_candidate)==(3,69_447) &&
                size(report.B_exterior_jacobian_candidate,2)==length(live_state) &&
                all(isfinite,report.B_exterior_jacobian_candidate)
            println("R4_LIVE_STATE_NEAR_CUT_CONSUMER="*F.canonical_json((
                report_path=report_path,state_sha256=report.state_sha256,
                producer_status=report.producer_status,join_status=report.join_status,
                join_reason=report.join_reason,near_cut_capture=near_summary.capture_path,
                near_cut_capture_sha256=near_summary.capture_sha256,
                B_exterior_jacobian=report.B_exterior_jacobian,
                B_exterior_jacobian_candidate_status=report.B_exterior_jacobian_candidate_status,
                closure=false,physical_validation=false)));flush(stdout)
            return (status=:r4_live_state_near_cut_consumer_completed,
                producer_status=report.producer_status,join_status=report.join_status,
                join_reason=report.join_reason,report_path=report_path,
                near_cut_summary=near_summary,consumer_status=:typed_absent,
                full64_not_executed=true,global_closure=false,physical_validation=false)
        end
        moving_direction=zeros(Float64,length(x));moving_direction[selected_psi_column]=1.0
        moving_prep=F._ccp_q1_lcfs_moving_geometry_directional_prepare(
            exterior_domain,x,moving_direction,selected_ray)
        @test moving_prep.status===:prepared
        if moving_prep.status!==:prepared
            return (status=:typed_absent,reason=:selected_base_moving_preparation_not_prepared,
                consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
        end
        if moving_prep.status===:prepared
            @test moving_prep.domain===exterior_domain
            @test moving_prep.target_index==selected_ray
            @test moving_prep.refined_triangle_count==6832
            @test moving_prep.near_target_cell_ids!==()
            if moving_prep.domain!==exterior_domain || moving_prep.state!=x ||
                    moving_prep.state_direction!=moving_direction || moving_prep.target_index!=selected_ray
                return (status=:typed_absent,reason=:selected_base_preparation_input_binding_mismatch,
                    consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
            end
            geometry=component.lcfs_dynamic_geometry_trace(x)
            if geometry.status!==:evaluated_dynamic_LCFS_geometry || geometry.mask_event!==:unchanged ||
                    !hasproperty(geometry,:first_outward_crossing_signature) ||
                    geometry.coordinates_RZ_m[selected_ray]!=moving_prep.target
                return (status=:typed_absent,reason=:selected_base_geometry_signature_unavailable_or_unbound,
                    consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
            end
            near_cut_join_flag=get(ENV,"FUSION_G2_PRECHECK_NEAR_CUT_JOIN","0")
            near_cut_join_flag in ("0","1") || error("FUSION_G2_PRECHECK_NEAR_CUT_JOIN must be 0 or 1")
            if near_cut_join_flag=="1"
                precheck_mode=="lcfs_exterior_field_selected_jacobian_smoke" ||
                    error("near-cut G join requires the selected-Jacobian precheck mode")
                run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
                !isempty(run_leaf) && isdir(run_leaf) ||
                    error("near-cut G numeric capture requires an existing bounded run-leaf FUSION_G2_PRECHECK_RESULT_DATA_DIR")
                Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned",
                    "near_cut_G_all_inventory_consumer_fixture.jl"))
                captured=Ref(false)
                capture_before_assertions=(result,join)->begin
                    _g2_near_cut_numeric_capture_summary(F,result,join,run_leaf)
                    captured[]=true
                    nothing
                end
                near_cut_join=Base.invokelatest(Main.run_near_cut_G_all_inventory_consumer_fixture,
                    F,exterior_data,x,trace.data.authored_sources,moving_prep;
                    order=8,max_kernel_calls=40_000_000,capture_callback=capture_before_assertions)
                captured[] || error("near-cut G fixture completed without a pre-assertion capture")
                println("NEAR_CUT_G2_FIXTURE="*F.canonical_json(near_cut_join));flush(stdout)
                return (status=:near_cut_G2_selected_diagnostic_completed,
                    near_cut_join=near_cut_join,consumer_status=:typed_absent,
                    global_closure=false,physical_validation=false,solver_rows_added=0,
                    full_Bout_error_bound=:typed_absent,all64_not_executed=true)
            end
            psi_geometry_column=findfirst(==(selected_psi_column),geometry.psi_global_dof_ids)
            @test psi_geometry_column!==nothing
            target_speed=NaN
            if psi_geometry_column!==nothing
                target_speed=hypot(geometry.coordinate_jacobian[2selected_ray-1,psi_geometry_column],
                    geometry.coordinate_jacobian[2selected_ray,psi_geometry_column])
                @test isfinite(target_speed) && target_speed>0
            end
            source_trace=component.core_current_trace(x)
            source_position=findfirst(==(div(selected_psi_column,4)),source_trace.native_ids)
            @test source_position!==nothing
            if source_position!==nothing
                @test isfinite(source_trace.jacobian[3source_position-1,selected_psi_column])
                @test source_trace.jacobian[3source_position-1,selected_psi_column]!=0
            end
            stop_after_far_rect_flag=get(ENV,"FUSION_G2_PRECHECK_STOP_AFTER_FAR_RECT","0")
            stop_after_far_rect_flag in ("0","1") ||
                error("FUSION_G2_PRECHECK_STOP_AFTER_FAR_RECT must be 0 or 1")
            stop_after_far_preparation_flag=get(ENV,"FUSION_G2_PRECHECK_STOP_AFTER_FAR_PREPARATION","0")
            stop_after_far_preparation_flag in ("0","1") ||
                error("FUSION_G2_PRECHECK_STOP_AFTER_FAR_PREPARATION must be 0 or 1")
            stop_after_far_preparation_flag=="1" && stop_after_far_rect_flag!="1" &&
                error("far preparation-only requires far rectangle short mode")
            far_total_one_cell_flag=get(ENV,"FUSION_G2_PRECHECK_FAR_TOTAL_ERROR_ONE_CELL","0")
            far_total_one_cell_flag in ("0","1") || error("far total-error one-cell flag must be 0 or 1")
            far_total_64_flag=get(ENV,"FUSION_G2_PRECHECK_FAR_TOTAL_ERROR_64","0")
            far_total_64_flag in ("0","1") || error("far total-error 64-ray flag must be 0 or 1")
            far_total_64_flag=="1" && stop_after_far_rect_flag!="1" &&
                error("64-ray total-error requires far rectangle short mode")
            far_total_64_flag=="1" && (far_total_one_cell_flag!="0" || stop_after_far_preparation_flag!="0") &&
                error("64-ray total-error cannot be combined with one-cell or preparation-only mode")
            if far_total_one_cell_flag=="1"
                stop_after_far_rect_flag=="1" || error("one-cell total-error requires existing far short mode")
                Base.include(Main,joinpath(@__DIR__,"..","tmp","current_owned",
                    "exterior_far_rect_total_error_actual_entry_fixture.jl"))
                one_cell=Base.invokelatest(Main.test_one_actual_exterior_far_rect_total_error_entry,
                    F,moving_prep;max_kernel_calls=40_000_000,capture_identity=exterior_data.trace_identity)
                println("LCFS_EXTERIOR_FAR_ONE_CELL_TOTAL_ERROR="*F.canonical_json(one_cell));flush(stdout)
                println("LCFS_EXTERIOR_FAR_ONE_CELL_RESULT_HASH="*string(F.canonical_hash(one_cell)));flush(stdout)
                return (status=:actual_far_one_cell_total_error_completed,one_cell=one_cell,
                    consumer_status=:typed_absent,global_closure=false,solver_rows_added=0,
                    full_Bout_error_bound=:typed_absent,all64_not_executed=true)
            end
            if stop_after_far_rect_flag=="1"
                rect_total_budget=40_000_000
                rect_spent=0
                @test rect_spent<=rect_total_budget
                if !(isfinite(target_speed) && target_speed>0)
                    prepdiag=(target_speed=isfinite(target_speed) ? target_speed : :nonfinite,requested_h1=:typed_absent,h1=:typed_absent,
                        h2=:typed_absent,roundoff_floor=:typed_absent,attempted_endpoint_count=0,
                        first_failure=(stage=:moving_geometry_target_speed_unavailable,))
                    println("FAR_RECT_PREPARATION_DIAGNOSTIC="*F.canonical_json(prepdiag));flush(stdout)
                    return (status=:typed_absent,reason=:far_rect_target_speed_unavailable,
                        preparation_diagnostic=prepdiag,consumer_status=:typed_absent,
                        global_closure=false,solver_rows_added=0,fd_not_executed=true)
                end
                requested_h1=1e-7/target_speed;h1=requested_h1;h2=h1/2
                roundoff_floor=_selected_fd_active_dof_roundoff_floor(x,moving_direction)
                attempted_endpoint_count=0;first_failure=nothing;first_failure_h=nothing
                last_attempt_h1=h1;last_attempt_h2=h2
                safe_preparations=Dict{Float64,Any}();safe_geometries=Dict{Float64,Any}();safe_steps=false
                for _ in 1:12
                    empty!(safe_preparations);h2=h1/2
                    last_attempt_h1=h1;last_attempt_h2=h2
                    if !(isfinite(h2) && h2>roundoff_floor)
                        if first_failure===nothing
                            first_failure_h=h2
                            first_failure=(stage=:finite_difference_step_below_roundoff_floor,
                                candidate_h1=h1,candidate_h2=h2,roundoff_floor=roundoff_floor)
                        end
                        break
                    end
                    safe_steps=true
                    for h in (h1,h2),sgn in (-1.0,1.0)
                        endpoint_h=sgn*h;endpoint_sign=sgn>0 ? :plus : :minus
                        xp=x.+endpoint_h.*moving_direction
                        attempted_endpoint_count+=1
                        gx=component.lcfs_dynamic_geometry_trace(xp)
                        geometry_signature_present=hasproperty(gx,:first_outward_crossing_signature)
                        geometry_signature_match=geometry_signature_present &&
                            gx.first_outward_crossing_signature===geometry.first_outward_crossing_signature
                        geometry_target_available=hasproperty(gx,:coordinates_RZ_m) &&
                            length(gx.coordinates_RZ_m)>=selected_ray
                        geometry_valid=gx.status===:evaluated_dynamic_LCFS_geometry &&
                            gx.mask_event===:unchanged && geometry_signature_match && geometry_target_available
                        if !geometry_valid
                            if first_failure===nothing
                                observed_target=geometry_target_available ? gx.coordinates_RZ_m[selected_ray] : nothing
                                first_failure_h=endpoint_h
                                first_failure=(stage=:endpoint_geometry,endpoint=(sign=endpoint_sign,h=endpoint_h),
                                    status=gx.status,mask_event=hasproperty(gx,:mask_event) ? gx.mask_event : :missing,
                                    first_crossing_signature_present=geometry_signature_present,
                                    first_crossing_signature_matches_base=geometry_signature_match,
                                    target_coordinate_available=geometry_target_available,
                                    target_RZ_m=observed_target)
                            end
                            safe_steps=false;break
                        end
                        pp=F._ccp_q1_lcfs_moving_geometry_directional_prepare(
                            exterior_domain,xp,moving_direction,selected_ray)
                        if pp.status!==:prepared
                            if first_failure===nothing
                                first_failure_h=endpoint_h
                                first_failure=(stage=:moving_preparation_status,
                                    endpoint=(sign=endpoint_sign,h=endpoint_h),status=pp.status,
                                    reason=hasproperty(pp,:reason) ? pp.reason : :not_reported)
                            end
                            safe_steps=false;break
                        end
                        checks=(domain_identity=pp.domain===exterior_domain,state_binding=pp.state==xp,
                            direction_binding=pp.state_direction==moving_direction,
                            target_index_binding=pp.target_index==selected_ray,
                            target_matches_endpoint=pp.target==gx.coordinates_RZ_m[selected_ray],
                            support_ownership_counts=pp.support_ownership_counts==moving_prep.support_ownership_counts,
                            near_target_cell_ids=pp.near_target_cell_ids==moving_prep.near_target_cell_ids,
                            polygon_triangulation_signature=pp.polygon_triangulation_signature==moving_prep.polygon_triangulation_signature,
                            clipping_signature=pp.clipping_signature==moving_prep.clipping_signature,
                            quadrature_partition_signature=pp.quadrature_partition_signature==moving_prep.quadrature_partition_signature,
                            singular_cover_count=pp.singular_cover_count==moving_prep.singular_cover_count,
                            refined_triangle_count=pp.refined_triangle_count==moving_prep.refined_triangle_count)
                        mismatch_fields=Tuple(k for (k,v) in pairs(checks) if !v)
                        if !isempty(mismatch_fields)
                            if first_failure===nothing
                                first_failure_h=endpoint_h
                                first_failure=(stage=:moving_preparation_signature,
                                    endpoint=(sign=endpoint_sign,h=endpoint_h),
                                    first_mismatch=first(mismatch_fields),all_checks=checks)
                            end
                            safe_steps=false;break
                        end
                        safe_preparations[endpoint_h]=pp;safe_geometries[endpoint_h]=gx
                    end
                    safe_steps && length(safe_preparations)==4 && break
                    h1/=2
                end
                prepdiag=(target_speed=target_speed,requested_h1=requested_h1,h1=last_attempt_h1,h2=last_attempt_h2,
                    roundoff_floor=roundoff_floor,attempted_endpoint_count=attempted_endpoint_count,
                    first_failure_h=first_failure_h,first_failure=first_failure,
                    safe_steps=safe_steps,prepared_endpoint_count=length(safe_preparations))
                println("FAR_RECT_PREPARATION_DIAGNOSTIC="*F.canonical_json(prepdiag));flush(stdout)
                @test safe_steps && length(safe_preparations)==4 && length(safe_geometries)==4 && h2>roundoff_floor
                if !(safe_steps && length(safe_preparations)==4 && length(safe_geometries)==4 && h2>roundoff_floor)
                    return (status=:typed_absent,reason=:far_rect_fd_geometry_or_preparation_signature_not_preserved,
                        preparation_diagnostic=prepdiag,consumer_status=:typed_absent,
                        global_closure=false,solver_rows_added=0,fd_not_executed=true)
                end
                if stop_after_far_preparation_flag=="1"
                    return (status=:exterior_far_preparation_completed,preparation_diagnostic=prepdiag,
                        farloop_not_executed=true,consumer_status=:typed_absent,global_closure=false,
                        solver_rows_added=0,fd_not_executed=true,full_Bout_error_bound=:typed_absent)
                end
                rect_far_control=Base.invokelatest(test_actual_exterior_far_rectangular_control,F,
                    moving_prep,safe_preparations,safe_geometries,geometry,moving_direction,h1,h2,
                    rect_total_budget-rect_spent;total_error=far_total_64_flag=="1",
                    capture_identity=(candidate_identity=(candidate_hash=component.candidate_hash,
                        context_hash=component.context_hash,upstream_output_hash=component.upstream_output_hash),
                        provider_context=context,trace_identity=exterior_data.trace_identity))
                rect_spent+=rect_far_control.total_ring_kernel_calls
                println("LCFS_EXTERIOR_FAR_RECT_CONTROL="*F.canonical_json(merge(rect_far_control,
                    (formal_test_spent_ring_kernel_calls=rect_spent,formal_test_total_kernel_budget=rect_total_budget))));flush(stdout)
                if rect_far_control.status in (:actual_candidate_one_cell_joint_EG_replay,:joint_total_error_refinement_needed)
                    return (status=rect_far_control.status,far_rectangle_control=rect_far_control,
                        preparation_diagnostic=prepdiag,consumer_status=:typed_absent,
                        global_closure=false,solver_rows_added=0,fd_not_executed=true,
                        full_Bout_error_bound=:typed_absent)
                end
                @test rect_spent<=rect_total_budget
                @test rect_far_control.remaining_shared_kernel_budget==rect_total_budget-rect_spent
                @test rect_far_control.final_spent_ring_kernel_calls==rect_far_control.total_ring_kernel_calls
                @test rect_far_control.status===:actual_candidate_64ray_far_cell_E_G_diagnostic
                @test rect_far_control.actual_target_count==64 && rect_far_control.per_cell_basis_columns==4
                @test rect_far_control.q32_q64_control_target_count==64
                @test rect_far_control.E_bound_scope===:complete_native_plasma_only_far_cells_only
                @test rect_far_control.G_error_bound===:typed_absent
                if far_total_64_flag=="1"
                    @test rect_far_control.total_error_64_enabled
                    @test rect_far_control.total_error_64_entries==175_059
                    @test rect_far_control.total_error_64_attempt_entries>=rect_far_control.total_error_64_entries
                    @test rect_far_control.total_error_64_reference_ring_points>=12_093_120
                    @test rect_far_control.total_error_64_reference_ring_points<=12_500_000
                    @test rect_far_control.total_error_64_gauss_cache_misses==length(rect_far_control.total_error_64_distinct_orders)
                    @test rect_far_control.total_error_64_total_interval_operations<=5_208_000_000
                end
                @test rect_far_control.physical_validation===false && rect_far_control.global_closure===false
                return (status=:exterior_far_rectangular_control_completed,far_rectangle_control=rect_far_control,
                    preparation_diagnostic=prepdiag,consumer_status=:typed_absent,global_closure=false,
                    solver_rows_added=0,fd_not_executed=false,selected_target_G_fd_executed=true,
                    full_Bout_fd_not_executed=true,full_Bout_error_bound=:typed_absent)
            end
            star_leaf=nothing
        for cell_partition in moving_prep.quadrature_partition
            cell=moving_prep.prepared_cells[cell_partition.cell_index]
            local_basis=findfirst(c->c>0,cell.columns)
            local_basis===nothing && continue
            for piece_partition in cell_partition.pieces
                for triangle in piece_partition.triangles
                    selector=(source_cell_native_ij=cell.native_cell,
                        piece_index=piece_partition.piece_index,
                        triangle_index=triangle.triangle_index,child_path=triangle.child_path,
                        basis_index=local_basis,interval_operations=Ref(0),max_interval_ops=2_000_000)
                    selector_check=F._ccp_q1_lcfs_validate_local_E_join_selector(
                        moving_prep,selector;order=8,max_kernel_calls=40_000_000)
                    if selector_check.status===:validated_local_E_join_selector
                        star_leaf=(cell_partition=cell_partition,piece_partition=piece_partition,
                            triangle=triangle,local_basis=local_basis,selector=selector,
                            selector_check=selector_check)
                        break
                    end
                end
                star_leaf===nothing || break
            end
            star_leaf===nothing || break
        end
        @test star_leaf!==nothing
        star_leaf===nothing && return (status=:typed_absent,reason=:actual_target_star_red_leaf_unavailable,
            consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
        star_box=nothing;star_whole=nothing
        if star_leaf!==nothing
            cell=moving_prep.prepared_cells[star_leaf.cell_partition.cell_index]
            local_basis=star_leaf.local_basis
            @test local_basis!==nothing && cell.columns[local_basis]>0
            if local_basis!==nothing
                tri=star_leaf.triangle
                if get(ENV,"FUSION_G2_EXTERIOR_LOCAL_E_CONSUMER_JOIN","0")=="1"
                    join_interval_ops=Ref(0)
                    join_input=merge(star_leaf.selector,(interval_operations=join_interval_ops,))
                    println("LCFS_LOCAL_E_CONSUMER_JOIN_SELECTOR ",repr((selector=join_input,
                        validation=star_leaf.selector_check)));flush(stdout)
                    wrapper=component.lcfs_exterior_field_primal(x;
                        ray_ids=(moving_prep.target_index,),order=8,max_kernel_calls=40_000_000,
                        moving_preparation=moving_prep,local_E_join=join_input)
                    raw_response=get(wrapper,:local_E_join_response,(;))
                    println("LCFS_LOCAL_E_CONSUMER_JOIN_RESULT ",repr((
                        wrapper_status=get(wrapper,:status,:typed_absent),
                        wrapper_reason=get(wrapper,:reason,:none),
                        local_E_join_status=get(wrapper,:local_E_join_status,:not_present),
                        raw_response_status=get(raw_response,:status,:not_present),
                        raw_response_reason=get(raw_response,:reason,:none),
                        raw_response_detail=get(raw_response,:detail,:none),
                        selector=join_input,
                        local_E_evidence_status=get(raw_response,:local_E_evidence_status,:typed_absent),
                        local_E_evidence=get(raw_response,:local_E_evidence,:typed_absent),
                        local_partition_active_basis_terms=get(raw_response,:local_partition_active_basis_terms,:typed_absent),
                        local_partition_uncovered_nonstar_terms=get(raw_response,:local_partition_uncovered_nonstar_terms,:typed_absent),
                        local_partition_uncovered_star_terms=get(raw_response,:local_partition_uncovered_star_terms,:typed_absent),
                        local_partition_uncovered_total_terms=get(raw_response,:local_partition_uncovered_total_terms,:typed_absent),
                        local_partition_uncovered_total_status=get(raw_response,:local_partition_uncovered_total_status,:typed_absent),
                        near_cut_total_E_error_bound=get(raw_response,:near_cut_total_E_error_bound,:typed_absent),
                        full_response_error_bound=get(raw_response,:full_response_error_bound,:typed_absent),
                        G_error_bound=get(raw_response,:G_error_bound,:typed_absent),
                        consumer_status=get(raw_response,:consumer_status,:typed_absent),
                        global_closure=get(raw_response,:global_closure,:typed_absent),
                        kernel_calls=get(raw_response,:kernel_calls,:typed_absent),
                        interval_operations=join_interval_ops[])));flush(stdout)
                    if wrapper.status!==:diagnostic_selected_LCFS_exterior_field_primal ||
                            get(wrapper,:local_E_join_status,:typed_absent)!==
                                :diagnostic_co_moving_red_chart_Duffy_response_matrix ||
                            get(raw_response,:status,:typed_absent)!==
                                :diagnostic_co_moving_red_chart_Duffy_response_matrix ||
                            get(raw_response,:local_E_evidence_status,:typed_absent)!==
                                :evaluated_one_actual_star_leaf_one_basis_E_join
                        return (status=:typed_absent,reason=:actual_local_E_consumer_join_failed,
                            selector=join_input,selector_validation=star_leaf.selector_check,
                            wrapper_status=get(wrapper,:status,:typed_absent),
                            wrapper_reason=get(wrapper,:reason,:none),
                            local_E_join_status=get(wrapper,:local_E_join_status,:not_present),
                            raw_response_status=get(raw_response,:status,:not_present),
                            raw_response_reason=get(raw_response,:reason,:none),
                            raw_response_detail=get(raw_response,:detail,:none),
                            kernel_calls=get(raw_response,:kernel_calls,0),
                            interval_operations=join_interval_ops[],consumer_status=:typed_absent,
                            global_closure=false,solver_rows_added=0)
                    end
                    @test wrapper.status===:diagnostic_selected_LCFS_exterior_field_primal
                    @test raw_response.status===:diagnostic_co_moving_red_chart_Duffy_response_matrix
                    @test raw_response.local_E_evidence_status===:evaluated_one_actual_star_leaf_one_basis_E_join
                    @test raw_response.local_E_evidence.live_Q_matches_whole_star_Q_bitwise===true
                    @test raw_response.local_E_evidence.coverage_ids==((moving_prep.target_index,
                        cell.native_cell,star_leaf.piece_partition.piece_index,tri.triangle_index,
                        tri.child_path,local_basis),)
                    @test raw_response.local_partition_uncovered_total_terms==
                        raw_response.local_partition_active_basis_terms-1
                    @test raw_response.local_partition_uncovered_total_terms==
                        raw_response.local_partition_uncovered_nonstar_terms+
                        raw_response.local_partition_uncovered_star_terms
                    @test raw_response.local_partition_uncovered_total_terms>0
                    @test raw_response.local_partition_uncovered_total_status===
                        :typed_absent_nonstar_cut_and_unselected_star_terms
                    @test raw_response.near_cut_total_E_error_bound===:typed_absent
                    @test raw_response.full_response_error_bound===
                        :typed_absent_due_to_near_and_cut_Duffy_terms
                    @test raw_response.G_error_bound===:typed_absent
                    @test raw_response.consumer_status===:typed_absent && !raw_response.physical_validation
                    @test wrapper.consumer_status===:typed_absent && !wrapper.global_closure
                    return (status=:exterior_selected_E_enclosure_completed,
                        local_E_consumer_join_status=:evaluated_one_actual_star_leaf_one_basis_E_join,
                        local_E_evidence=raw_response.local_E_evidence,
                        local_partition_uncovered_total_terms=raw_response.local_partition_uncovered_total_terms,
                        near_cut_total_E_error_bound=:typed_absent,G_error_bound=:typed_absent,
                        consumer_status=:typed_absent,global_closure=false,solver_rows_added=0,
                        fd_not_executed=true)
                end
                directional_box=F._ccp_q1_lcfs_moving_prep_star_leaf_directional_box(
                    moving_prep,star_leaf.cell_partition,tri,(0.25,0.5),(0.25,0.5);
                    basis_index=local_basis,terms=16,precision_bits=256,
                    max_interval_ops=2_000_000)
                @test directional_box.selected_direction_binding===:moving_prep_full_native_state_direction
                @test directional_box.state_direction_dimension==length(moving_prep.state_direction)
                @test directional_box.target_index==moving_prep.target_index
                @test directional_box.parent_velocity_binding===:selected_partition_red_leaf
                @test directional_box.current_binding===:moving_prep_current_and_directional_current
                @test directional_box.Q1_bounds_motion===:fixed_dynamic_geometry_data_axes
                @test directional_box.status===:evaluated_positive_q_geometry_directional_box
                valid_interval=I->I isa Tuple && length(I)==2 && all(v->v isa Real && isfinite(v),I) && I[1]<=I[2]
                @test all(valid_interval,(directional_box.q_interval,directional_box.primal_q_interval,
                    directional_box.q_hull_interval,directional_box.eta_interval,
                    directional_box.rho2_interval,directional_box.S_interval,
                    directional_box.K_interval,directional_box.E_interval,
                    directional_box.dK_interval,directional_box.dE_interval,
                    directional_box.area_interval,directional_box.area_direction_interval,
                    directional_box.density_interval,directional_box.density_direction_interval))
                @test all(valid_interval,directional_box.geometry_integral_RZ)
                @test all(valid_interval,directional_box.geometry_directional_integral_RZ)
                @test all(valid_interval,directional_box.Q1_basis_intervals)
                @test all(valid_interval,directional_box.Q1_basis_direction_intervals)
                @test directional_box.q_hull_interval[1]<=directional_box.primal_q_interval[1]
                @test directional_box.q_hull_interval[1]<=directional_box.q_interval[1]
                @test directional_box.primal_q_interval[2]<=directional_box.q_hull_interval[2]
                @test directional_box.q_interval[2]<=directional_box.q_hull_interval[2]
                @test directional_box.directional_K_E_reenclosure_extra_interval_operations>=0
                @test directional_box.current_core_ids==moving_prep.core_ids
                @test length(unique(filter(>(0),directional_box.current_core_ordinals)))==
                    count(>(0),directional_box.current_core_ordinals)
                @test directional_box.current_q1_interpolation_applied_once===true
                @test directional_box.child_area_determinant_applied_once===true
                for (bad_counter,budget) in ((Ref(-1),2),(Ref(1.5),2),(Ref(true),2),
                        (Ref(3),2),(Ref(typemax(Int)),typemax(Int)))
                    bad_ke=F._ccp_q1_dlmf_ke_directional_interval((0.25,0.5),(0.0,0.0);
                        interval_ops=bad_counter,max_interval_ops=budget)
                    @test bad_ke.status===:typed_absent
                    @test bad_ke.reason===:invalid_initial_interval_operation_counter
                    @test bad_ke.interval_operations==0
                    bad_box=F._ccp_q1_lcfs_moving_prep_star_leaf_directional_box(
                        moving_prep,star_leaf.cell_partition,tri,(0.25,0.5),(0.25,0.5);
                        basis_index=local_basis,terms=16,precision_bits=256,
                        interval_ops=bad_counter,max_interval_ops=budget)
                    @test bad_box.status===:typed_absent
                    @test bad_box.reason===:invalid_initial_interval_operation_counter
                    @test bad_box.interval_operations==0
                end
                huge_interval_cap=BigInt(typemax(Int))+1
                oversized_cap_ke=F._ccp_q1_dlmf_ke_interval((0.25,0.5);
                    max_interval_ops=huge_interval_cap)
                @test oversized_cap_ke.status===:typed_absent
                @test oversized_cap_ke.reason===:invalid_DLMF_enclosure_controls
                oversized_cap_direction=F._ccp_q1_dlmf_ke_directional_interval(
                    (0.25,0.5),(0.0,0.0);max_interval_ops=huge_interval_cap)
                @test oversized_cap_direction.status===:typed_absent
                @test oversized_cap_direction.reason===:invalid_DLMF_enclosure_controls
                oversized_cap_box=F._ccp_q1_lcfs_moving_prep_star_leaf_directional_box(
                    moving_prep,star_leaf.cell_partition,tri,(0.25,0.5),(0.25,0.5);
                    basis_index=local_basis,terms=16,precision_bits=256,
                    max_interval_ops=huge_interval_cap)
                @test oversized_cap_box.status===:typed_absent
                @test oversized_cap_box.reason===:invalid_star_leaf_directional_geometry
                max_minus_one_ke=F._ccp_q1_dlmf_ke_interval((0.25,0.5);
                    interval_ops=Ref(typemax(Int)-1),max_interval_ops=typemax(Int))
                @test max_minus_one_ke.status===:typed_absent
                @test max_minus_one_ke.reason===:DLMF_K_E_interval_failure
                @test max_minus_one_ke.interval_operations==typemax(Int)
                max_minus_one_direction=F._ccp_q1_dlmf_ke_directional_interval(
                    (0.25,0.5),(0.0,0.0);interval_ops=Ref(typemax(Int)-1),
                    max_interval_ops=typemax(Int))
                @test max_minus_one_direction.status===:typed_absent
                @test max_minus_one_direction.reason===:primal_DLMF_enclosure_unavailable
                @test max_minus_one_direction.interval_operations==typemax(Int)
                max_minus_one_box=F._ccp_q1_lcfs_moving_prep_star_leaf_directional_box(
                    moving_prep,star_leaf.cell_partition,tri,(0.25,0.5),(0.25,0.5);
                    basis_index=local_basis,terms=16,precision_bits=256,
                    interval_ops=Ref(typemax(Int)-1),max_interval_ops=typemax(Int))
                @test max_minus_one_box.status===:typed_absent
                @test max_minus_one_box.reason===:primal_E_box_lane_unavailable
                @test max_minus_one_box.interval_operations==typemax(Int)
                @test max_minus_one_box.kernel_calls==0
                @test F._ccp_q1_lcfs_red_leaf_points_match_parent_chart(
                    tri.points,tri.affine_parent_points,tri.affine_vertex_weights)
                same_area_different_leaf=(tri.points[1],tri.points[3],tri.points[2])
                @test !F._ccp_q1_lcfs_red_leaf_points_match_parent_chart(
                    same_area_different_leaf,tri.affine_parent_points,tri.affine_vertex_weights)
                interval_pair_strings=I->(string(I[1]),string(I[2]))
                interval_family_strings=family->Tuple(interval_pair_strings(I) for I in family)
                interval_width_string=I->string(setrounding(BigFloat,RoundUp) do
                    I[2]-I[1]
                end)
                ratio_string=(distance,q)->string(setrounding(BigFloat,RoundUp) do
                    BigFloat(distance)/max(abs(BigFloat(q)),BigFloat("1e-12"))
                end)
                star_box=F._ccp_q1_lcfs_star_leaf_primal_E_box_enclosure(
                    moving_prep.target,tri.affine_parent_points,tri.affine_vertex_weights,
                    cell.bounds,moving_prep.law.mu0_N_per_A2,(0.25,0.5),(0.25,0.5);
                    actual_triangle_points=tri.points,
                    affine_det_ratio=tri.affine_det_ratio,basis_index=local_basis,
                    terms=16,precision_bits=256,order=4)
                local_enclosure=hasproperty(star_box,:exact_box_integral_enclosure_RZ) ?
                    interval_family_strings(star_box.exact_box_integral_enclosure_RZ) : :typed_absent
                local_q=hasproperty(star_box,:box_gauss_Q_RZ) ? Tuple(string(v) for v in star_box.box_gauss_Q_RZ) : :typed_absent
                local_distance=hasproperty(star_box,:Q_to_exact_integral_enclosure_distance_upper_RZ) ?
                    Tuple(string(v) for v in star_box.Q_to_exact_integral_enclosure_distance_upper_RZ) : :typed_absent
                local_width=hasproperty(star_box,:exact_box_integral_enclosure_RZ) ?
                    Tuple(interval_width_string(I) for I in star_box.exact_box_integral_enclosure_RZ) : :typed_absent
                local_scaled=hasproperty(star_box,:box_gauss_Q_RZ) &&
                    hasproperty(star_box,:Q_to_exact_integral_enclosure_distance_upper_RZ) ?
                    Tuple(ratio_string(star_box.Q_to_exact_integral_enclosure_distance_upper_RZ[k],star_box.box_gauss_Q_RZ[k]) for k in 1:2) : :typed_absent
                println("LCFS_STAR_LEAF_LOCAL_E_RESULT ",repr((status=star_box.status,
                    reason=get(star_box,:reason,:none),interval_boxes=get(star_box,:interval_boxes,
                        star_box.status===:enclosed_single_star_leaf_primal_E_box ? 1 : 0),
                    interval_operations=get(star_box,:interval_operations,:typed_absent),
                    kernel_calls=get(star_box,:kernel_calls,:typed_absent),
                    exact_integral_enclosure_RZ=local_enclosure,Q_RZ=local_q,
                    interval_width_RZ=local_width,Q_to_interval_distance_upper_RZ=local_distance,
                    distance_scaled_by_max_abs_Q_or_1e_12_RZ=local_scaled,
                    reference_floor=1e-12,reference_floor_scope=:diagnostic_only_no_tolerance_credit,
                    dominant_box=:typed_absent,consumer_status=get(star_box,:consumer_status,:typed_absent),
                    G=get(star_box,:G,:typed_absent))))
                flush(stdout)
                if star_box.status!==:enclosed_single_star_leaf_primal_E_box
                    return (status=:typed_absent,reason=get(star_box,:reason,:local_star_leaf_E_box_not_enclosed),
                        consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                end
                @test star_box.status===:enclosed_single_star_leaf_primal_E_box
                @test star_box.consumer_status===:typed_absent && star_box.G===:typed_absent
                @test star_box.integration_domain===:exact_parent_affine_chart_for_selected_leaf
                @test star_box.geometry_rounding_to_stored_polygon_error===:typed_absent
                @test star_box.physical_full64_credit===false
                if star_box.status===:enclosed_single_star_leaf_primal_E_box
                    @test all(isfinite,star_box.box_gauss_Q_RZ)
                    @test all(isfinite,star_box.Q_to_exact_integral_enclosure_distance_upper_RZ)
                    @test all(x->x>=0,star_box.Q_to_exact_integral_enclosure_distance_upper_RZ)
                    @test star_box.quadrature_error_certified===false
                    @test star_box.kernel_calls==16 && star_box.quadrature_order==4
                    @test all(isfinite,(star_box.DLMF_tail_upper.K,star_box.DLMF_tail_upper.E))
                    star_whole=F._ccp_q1_lcfs_star_leaf_primal_E_whole_enclosure(
                        moving_prep.target,tri.affine_parent_points,tri.affine_vertex_weights,
                        cell.bounds,moving_prep.law.mu0_N_per_A2;actual_triangle_points=tri.points,
                        affine_det_ratio=tri.affine_det_ratio,basis_index=local_basis,
                        radial_levels=8,angular_panels=16,terms=16,precision_bits=256,
                        max_interval_boxes=512,max_interval_ops=2_000_000,max_kernel_calls=40_000_000)
                    whole_bounds=hasproperty(star_whole,:exact_integral_enclosure_RZ) ?
                        interval_family_strings(star_whole.exact_integral_enclosure_RZ) : :typed_absent
                    if !(star_whole isa NamedTuple) || !hasproperty(star_whole,:status)
                        return (status=:typed_absent,reason=:whole_E_helper_return_contract_invalid,
                            consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                    end
                    whole_status=star_whole.status
                    whole_width=hasproperty(star_whole,:exact_integral_width_RZ) ?
                        Tuple(string(v) for v in star_whole.exact_integral_width_RZ) : :typed_absent
                    local_current_domain=moving_prep.domain
                    local_profile_span=F._ccp_full_native_profile_span(local_current_domain,x)
                    local_profile_uv=local_current_domain.vary_profile_coefficients ?
                        (x[local_current_domain.coefficient_columns[1]],x[local_current_domain.coefficient_columns[2]]) :
                        local_current_domain.accepted_coefficients
                    current_core_ordinal=cell.columns[local_basis]
                    current_native_node_id=moving_prep.core_ids[current_core_ordinal]
                    current_psi_global_dof_id=4current_native_node_id
                    current_psi_value_Wb_per_rad=x[current_psi_global_dof_id]
                    current_source_R_m=local_current_domain.dynamic_geometry_data.Raxis[
                        cld(current_native_node_id,local_current_domain.dynamic_geometry_data.nz)]
                    current_q=(current_psi_value_Wb_per_rad-local_profile_span.boundary)/local_profile_span.delta
                    current_C=local_profile_uv[1]*current_source_R_m/moving_prep.law.Raxis_m +
                        local_profile_uv[2]*moving_prep.law.Raxis_m/current_source_R_m
                    actual_basis_Jphi_A_per_m2=moving_prep.current[current_core_ordinal]
                    current_formula_Jphi_A_per_m2=current_C*current_q^2
                    @test isapprox(actual_basis_Jphi_A_per_m2,current_formula_Jphi_A_per_m2;
                        rtol=8eps(Float64),atol=0.0)
                    whole_field_width_T=if hasproperty(star_whole,:exact_integral_width_RZ)
                        Tuple(string(setrounding(BigFloat,RoundUp) do
                            abs(BigFloat(actual_basis_Jphi_A_per_m2))*star_whole.exact_integral_width_RZ[k]
                        end) for k in 1:2)
                    else
                        :typed_absent
                    end
                    whole_field_D32_T=if hasproperty(star_whole,:production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order)
                        Tuple(string(setrounding(BigFloat,RoundUp) do
                            abs(BigFloat(actual_basis_Jphi_A_per_m2))*
                                star_whole.production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order[32][k]
                        end) for k in 1:2)
                    else
                        :typed_absent
                    end
                    whole_weight_ops=(hasproperty(star_whole,:exact_integral_width_RZ) ? 2 : 0) +
                        (hasproperty(star_whole,:production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order) ? 2 : 0)
                    whole_output_ops=hasproperty(star_whole,:interval_operations) ?
                        star_whole.interval_operations+whole_weight_ops : :typed_absent
                    whole_orders=if hasproperty(star_whole,:production_Q_RZ_by_order) &&
                            hasproperty(star_whole,:production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order)
                        Tuple((order=n,Q_RZ=Tuple(string(v) for v in star_whole.production_Q_RZ_by_order[n]),
                            D_order_RZ=Tuple(string(v) for v in star_whole.production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order[n]),
                            D_scaled_by_max_abs_Q_or_1e_12_RZ=Tuple(ratio_string(
                                star_whole.production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order[n][k],
                                star_whole.production_Q_RZ_by_order[n][k]) for k in 1:2))
                            for n in sort!(collect(keys(star_whole.production_Q_RZ_by_order))))
                    else
                        :typed_absent
                    end
                    println("LCFS_STAR_LEAF_WHOLE_E_RESULT ",repr((status=whole_status,
                        reason=get(star_whole,:reason,:none),interval_boxes=get(star_whole,:interval_boxes,:typed_absent),
                        interval_operations=get(star_whole,:interval_operations,:typed_absent),
                        max_interval_operations=get(star_whole,:max_interval_operations,:typed_absent),
                        kernel_calls=get(star_whole,:kernel_calls,:typed_absent),
                        max_kernel_calls=get(star_whole,:max_kernel_calls,:typed_absent),
                        exact_integral_enclosure_RZ=whole_bounds,interval_width_RZ=whole_width,
                        production_orders=whole_orders,
                        interval_contribution_breakdown=get(star_whole,:interval_contribution_breakdown,:typed_absent),
                        dominant_box=get(get(star_whole,:interval_contribution_breakdown,(;)),:dominant_box_by_component_RZ,:typed_absent),
                        candidate_hash=string(component.candidate_hash),context_hash=string(component.context_hash),
                        provider_context_hash=string(context.provider_context_hash),
                        upstream_output_hash=string(trace.data.upstream_output_hash),
                        target_RZ_m=moving_prep.target,parent_points_RZ_m=tri.affine_parent_points,
                        affine_vertex_weights=tri.affine_vertex_weights,actual_triangle_points_RZ_m=tri.points,
                        source_cell_bounds_RZ_m=cell.bounds,mu0_N_per_A2=moving_prep.law.mu0_N_per_A2,
                        basis_index=local_basis,basis_current_source_index=cell.columns[local_basis],
                        current_core_ordinal=current_core_ordinal,current_native_node_id=current_native_node_id,
                        current_psi_global_dof_id=current_psi_global_dof_id,
                        current_producer=(formula=:C_times_q_squared,u=local_profile_uv[1],v=local_profile_uv[2],
                            profile_axis_Wb_per_rad=local_profile_span.axis,
                            profile_boundary_Wb_per_rad=local_profile_span.boundary,
                            profile_delta_Wb_per_rad=local_profile_span.delta,source_R_m=current_source_R_m,
                            current_psi_Wb_per_rad=current_psi_value_Wb_per_rad,q=current_q,C=current_C,
                            formula_Jphi_A_per_m2=current_formula_Jphi_A_per_m2,
                            moving_prep_current_A_per_m2=actual_basis_Jphi_A_per_m2),
                        single_basis_E_interval_width_weighted_T=whole_field_width_T,
                        single_basis_Q32_distance_weighted_T=whole_field_D32_T,
                        field_unit_conversion_interval_operations=whole_weight_ops,
                        interval_operations_including_field_unit_conversion=whole_output_ops,
                        selected_direction_tau_E=:unknown_no_explicit_error_allocation,
                        reference_floor=1e-12,reference_floor_scope=:diagnostic_only_no_tolerance_credit,
                        integration_domain=get(star_whole,:integration_domain,:typed_absent),
                        geometry_rounding_to_stored_polygon_error=get(star_whole,:geometry_rounding_to_stored_polygon_error,:typed_absent),
                        physical_full64_credit=get(star_whole,:physical_full64_credit,false),
                        consumer_status=get(star_whole,:consumer_status,:typed_absent),G=get(star_whole,:G,:typed_absent))))
                    flush(stdout)
                    if star_whole.status!==:enclosed_whole_target_star_leaf_primal_E
                        return (status=:typed_absent,reason=get(star_whole,:reason,:whole_star_leaf_E_enclosure_failed),
                            consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                    end
                    @test star_whole.status===:enclosed_whole_target_star_leaf_primal_E
                    @test star_whole.consumer_status===:typed_absent && star_whole.G===:typed_absent
                    @test star_whole.integration_domain===:exact_parent_affine_chart_for_selected_leaf
                    @test star_whole.geometry_rounding_to_stored_polygon_error===:typed_absent
                    @test star_whole.physical_full64_credit===false
                    if star_whole.status===:enclosed_whole_target_star_leaf_primal_E
                        @test star_whole.interval_boxes==144
                        @test star_whole.interval_operations<=2_000_000
                        @test star_whole.interval_operations+whole_weight_ops<=star_whole.max_interval_operations
                        @test star_whole.kernel_calls==8^2+16^2+32^2
                        @test Set(keys(star_whole.production_Q_RZ_by_order))==Set((8,16,32))
                        @test Set(keys(star_whole.production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order))==Set((8,16,32))
                        @test all(isfinite,Iterators.flatten(values(star_whole.production_Q_RZ_by_order)))
                        @test all(x->isfinite(x) && x>=0,
                            Iterators.flatten(values(star_whole.production_Q_to_exact_integral_enclosure_distance_upper_RZ_by_order)))
                        @test star_whole.radial_endpoint_epsilon==1/256
                        @test star_whole.global_closure===false
                        if get(ENV,"FUSION_G2_EXTERIOR_E_ONLY","0")=="1"
                            rpart_ops=Ref(0);rpart_calls=Ref(0)
                            rpart=F._ccp_q1_lcfs_star_leaf_regular_gauss8_r_partition_certificate(
                                moving_prep.target,tri.affine_parent_points,tri.affine_vertex_weights,
                                cell.bounds,moving_prep.law.mu0_N_per_A2,(2.0^-8,2.0^-7),(0.0,1/16);
                                local_error_upper_RZ=(1e100,1e100),starting_panels=4,
                                actual_triangle_points=tri.points,
                                affine_det_ratio=tri.affine_det_ratio,basis_index=local_basis,terms=16,precision_bits=256,
                                max_interval_ops=2_000_000,max_kernel_calls=40_000_000,
                                interval_ops=rpart_ops,kernel_calls=rpart_calls)
                            println("LCFS_STAR_LEAF_R_PARTITION_RESULT ",repr((status=rpart.status,test_role=:abi_and_four_panel_shape_only,
                                reason=get(rpart,:reason,:none),synthetic_control_only=true,
                                panel_count=get(rpart,:panel_count,:typed_absent),panels=get(rpart,:panels,:typed_absent),
                                local_error_upper_RZ=get(rpart,:local_error_upper_RZ,:typed_absent),
                                whole_selected_box_bound_RZ=get(rpart,:whole_selected_box_bound_RZ,:typed_absent),
                                original_parent_q8_float64_RZ=get(rpart,:original_parent_q8_float64_RZ,:typed_absent),
                                original_parent_q8_to_partition_enclosure_upper_RZ=get(rpart,:original_parent_q8_to_partition_enclosure_upper_RZ,:typed_absent),
                                original_parent_q8_contained_in_partition_integral_enclosure=get(rpart,:original_parent_q8_contained_in_partition_integral_enclosure,:typed_absent),
                                interval_operations=get(rpart,:interval_operations,:typed_absent),kernel_calls=get(rpart,:kernel_calls,:typed_absent),
                                scope=get(rpart,:scope,:typed_absent),global_closure=get(rpart,:global_closure,:typed_absent))))
                            flush(stdout)
                            if rpart.status!==:evaluated_regular_star_leaf_r_partition_gauss8_certificate
                                return (status=:typed_absent,reason=get(rpart,:reason,:selected_r_partition_not_certified),
                                    local_error_control=rpart,consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                            end
                            @test rpart.scope===:single_selected_regular_box_only
                            @test rpart.synthetic_control_only===true
                            @test rpart.panel_count==4
                            @test all(k->rpart.whole_selected_box_bound_RZ[k]<=rpart.local_error_upper_RZ[k],1:2)
                            return (status=:exterior_selected_E_enclosure_completed,
                                whole_star_leaf_E_enclosure=star_whole,
                                consumer_status=:typed_absent,global_closure=false,solver_rows_added=0,
                                fd_not_executed=true)
                        end
                    end
                else
                    return (status=:typed_absent,reason=:local_star_leaf_E_box_unreachable_status,
                        consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                end
            end
        end
        # This separate invocation retains the 40M kernel-call ceiling. The
        # Interior control plus whole-leaf Q8/Q16/Q32 add 1,360 ring calls.
            # Base selected-state calls are 37,166,080; local controls add 1,360.
            total_budget=40_000_000
            box_calls=star_box===nothing ? 0 : star_box.kernel_calls
            whole_leaf_calls=star_whole===nothing ? 0 : star_whole.kernel_calls
            projected_calls=moving_prep.refined_triangle_count*(8^2+16^2+5*32^2)+box_calls+whole_leaf_calls
            @test projected_calls<=total_budget
            exterior_by_order=Dict{Int,Any}();spent=box_calls+whole_leaf_calls
            for (order,budget) in ((8,600_000),(16,2_400_000),(32,9_600_000))
                value=component.lcfs_exterior_field_primal(x;ray_ids=(selected_ray,),order=order,
                    max_kernel_calls=min(budget,total_budget-spent),moving_preparation=moving_prep)
                @test value.status===:diagnostic_selected_LCFS_exterior_field_primal
                @test size(value.B_exterior_jacobian_candidate_T_per_state_dof)==(3,length(x))
                @test value.consumer_status===:typed_absent && !value.global_closure
                spent+=value.kernel_calls;exterior_by_order[order]=value
            end
            J8=exterior_by_order[8].B_exterior_jacobian_candidate_T_per_state_dof*moving_direction
            J16=exterior_by_order[16].B_exterior_jacobian_candidate_T_per_state_dof*moving_direction
            J32=exterior_by_order[32].B_exterior_jacobian_candidate_T_per_state_dof*moving_direction
            @test F.norm(J16-J8)/max(F.norm(J16),F.norm(J8),1e-12)<=5e-6
            @test F.norm(J32-J16)/max(F.norm(J32),F.norm(J16),1e-12)<=5e-6
            gd=component.lcfs_dynamic_geometry_data
            h1=1e-7/target_speed
            h2=h1/2;roundoff_floor=_selected_fd_active_dof_roundoff_floor(x,moving_direction)
            safe_preparations=Dict{Float64,Any}();safe_geometries=Dict{Float64,Any}();safe_steps=false
            for _ in 1:12
                empty!(safe_preparations);h2=h1/2
                h2>roundoff_floor || break
                safe_steps=true
                for h in (h1,h2),sgn in (-1.0,1.0)
                    xp=x.+(sgn*h).*moving_direction
                    gx=component.lcfs_dynamic_geometry_trace(xp)
                    if gx.status!==:evaluated_dynamic_LCFS_geometry || gx.mask_event!==:unchanged ||
                            !hasproperty(gx,:first_outward_crossing_signature) ||
                            gx.first_outward_crossing_signature!==geometry.first_outward_crossing_signature
                        safe_steps=false;break
                    end
                    pp=F._ccp_q1_lcfs_moving_geometry_directional_prepare(
                        exterior_domain,xp,moving_direction,selected_ray)
                    if pp.status!==:prepared || pp.domain!==exterior_domain || pp.state!=xp ||
                            pp.state_direction!=moving_direction || pp.target_index!=selected_ray ||
                            pp.target!=gx.coordinates_RZ_m[selected_ray] ||
                            pp.support_ownership_counts!=moving_prep.support_ownership_counts ||
                            pp.near_target_cell_ids!=moving_prep.near_target_cell_ids ||
                            pp.polygon_triangulation_signature!=moving_prep.polygon_triangulation_signature ||
                            pp.clipping_signature!=moving_prep.clipping_signature ||
                            pp.quadrature_partition_signature!=moving_prep.quadrature_partition_signature ||
                            pp.singular_cover_count!=moving_prep.singular_cover_count ||
                            pp.refined_triangle_count!=moving_prep.refined_triangle_count
                        safe_steps=false;break
                    end
                    safe_preparations[sgn*h]=pp;safe_geometries[sgn*h]=gx
                end
                safe_steps && length(safe_preparations)==4 && break
                h1/=2
            end
            @test safe_steps && length(safe_preparations)==4 && length(safe_geometries)==4 && h2>roundoff_floor
            if !(safe_steps && length(safe_preparations)==4 && length(safe_geometries)==4 && h2>roundoff_floor)
                return (status=:typed_absent,reason=:selected_fd_geometry_or_preparation_signature_not_preserved,
                    consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
            end
            if safe_steps && length(safe_preparations)==4 && length(safe_geometries)==4
                for h in (h1,h2)
                    plus=component.lcfs_exterior_field_primal(x.+h.*moving_direction;ray_ids=(selected_ray,),
                        order=32,max_kernel_calls=min(9_600_000,total_budget-spent),
                        moving_preparation=safe_preparations[h])
                    if plus.status!==:diagnostic_selected_LCFS_exterior_field_primal ||
                            plus.dynamic_geometry.first_outward_crossing_signature!==geometry.first_outward_crossing_signature ||
                            plus.target_coordinates_RZ_m[1]!=safe_geometries[h].coordinates_RZ_m[selected_ray]
                        return (status=:typed_absent,reason=:selected_plus_fd_geometry_signature_or_field_unavailable,
                            consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                    end
                    spent+=plus.kernel_calls
                    minus=component.lcfs_exterior_field_primal(x.-h.*moving_direction;ray_ids=(selected_ray,),
                        order=32,max_kernel_calls=min(9_600_000,total_budget-spent),
                        moving_preparation=safe_preparations[-h])
                    if minus.status!==:diagnostic_selected_LCFS_exterior_field_primal ||
                            minus.dynamic_geometry.first_outward_crossing_signature!==geometry.first_outward_crossing_signature ||
                            minus.target_coordinates_RZ_m[1]!=safe_geometries[-h].coordinates_RZ_m[selected_ray]
                        return (status=:typed_absent,reason=:selected_minus_fd_geometry_signature_or_field_unavailable,
                            consumer_status=:typed_absent,global_closure=false,solver_rows_added=0)
                    end
                    spent+=minus.kernel_calls
                    fd=(vec(plus.B_exterior_T)-vec(minus.B_exterior_T))/(2h)
                    analytic=vec(J32)
                    @test F.norm(fd-analytic)/max(F.norm(fd),F.norm(analytic),1e-12)<=5e-6
                end
            end
            @test spent<=total_budget
            @test exterior_by_order[32].B_exterior_jacobian===:typed_absent
            @test exterior_by_order[32].B_exterior_jacobian_candidate_status===:analytic_full_state_candidate_unvalidated
        end
        return (status=:exterior_selected_jacobian_completed,ray_ids=(selected_ray,),
            whole_star_leaf_E_enclosure=star_whole,
            consumer_status=:typed_absent,global_closure=false)
    end
    lcfs_current=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
        provider.lcfs_current_numeric_data,component.initial_state;with_jacobian=true)
    @test lcfs_current.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
    @test length(lcfs_current.residual)==64
    @test length(lcfs_current.regional_F_row_residuals_T_m)==prod(component.grid_shape)
    @test length(lcfs_current.regional_F_target_native_T_m)==prod(component.grid_shape)
    initial_F_defect=collect(lcfs_current.regional_F_row_residuals_T_m)
    initial_F_target=collect(lcfs_current.regional_F_target_native_T_m)
    frow=lcfs_current.regional_F_row_diagnostic
    @test frow.status===:evaluated_from_original_masked_regional_F_rows
    @test frow.row_owner===:all_native_R_Bphi_minus_F && frow.row_unit=="T m"
    @test frow.core_row_count==count(component.core_mask)
    @test frow.core_max_abs_T_m==maximum(abs,initial_F_defect[findall(component.core_mask)])
    @test frow.exterior_max_abs_T_m==maximum(abs,initial_F_defect[findall(.!component.core_mask)])
    println("CURRENT_INITIAL_REGIONAL_FROW_DEFECT="*F.canonical_json(frow));flush(stdout)
    println("CURRENT_ACTUAL_INITIAL_JN="*F.canonical_json((
        max_abs_A_per_m2=maximum(abs,lcfs_current.Jn_A_per_m2),
        rms_A_per_m2=sqrt(sum(abs2,lcfs_current.Jn_A_per_m2)/length(lcfs_current.Jn_A_per_m2)),
        integrated_diagnostic_A=lcfs_current.integrated_current_A,
        Jn_A_per_m2=Tuple(lcfs_current.Jn_A_per_m2),
        physical_budget=lcfs_current.normal_current_diagnostic.residual_budget_A_per_m2,
        acceptance_threshold=lcfs_current.normal_current_diagnostic.acceptance_threshold_A_per_m2)));flush(stdout)
    if provider.current_topology!==nothing
        independent_Ftrace=component.lcfs_state_F_curl_trace(component.initial_state;with_jacobian=false)
        @test independent_Ftrace.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
        same_coordinates=lcfs_current.dynamic_geometry.coordinates_RZ_m==
            independent_Ftrace.dynamic_geometry.coordinates_RZ_m
        same_normals=lcfs_current.dynamic_geometry.normals_RZ==independent_Ftrace.dynamic_geometry.normals_RZ
        same_surface_weights=lcfs_current.dynamic_geometry.surface_quadrature_m2==
            independent_Ftrace.dynamic_geometry.surface_quadrature_m2
        @test same_coordinates && same_normals && same_surface_weights
        canonical_Jn=lcfs_current.Jn_A_per_m2
        F_B_Jn=independent_Ftrace.Jn_A_per_m2
        delta_Jn=F_B_Jn.-canonical_Jn
        metric(v)=(max_abs_A_per_m2=maximum(abs,v;init=0.0),
            rms_A_per_m2=sqrt(sum(abs2,v)/length(v)))
        pressure_interface_trace=component.lcfs_profile_current_trace(
            component.initial_state;with_jacobian=true,dynamic_geometry=true)
        interface_pair=(status=:typed_absent,
            reason=:legacy_or_unavailable_plasma_side_interface_Bphi,
            Bphi_source=hasproperty(pressure_interface_trace,:plasma_side_interface_inputs) &&
                hasproperty(pressure_interface_trace.plasma_side_interface_inputs,:Bphi_source) ?
                pressure_interface_trace.plasma_side_interface_inputs.Bphi_source : :typed_absent)
        if hasproperty(pressure_interface_trace,:plasma_side_interface_inputs)
            interface=pressure_interface_trace.plasma_side_interface_inputs
            if interface.status===:evaluated_plasma_side_dynamic_LCFS_inputs &&
                    hasproperty(interface,:Bphi_source) &&
                    interface.Bphi_source===:actual_state_F_B_spline_over_actual_R &&
                    hasproperty(interface,:Bphi_field_jacobian_source) &&
                    interface.Bphi_field_jacobian_source===:shared_centered_F_B_point_sampler_on_checked_geometry
                interface_F_B=component.lcfs_state_F_curl_trace(component.initial_state;
                    with_jacobian=true,with_cut_jacobian=false,with_Bphi_field_jacobian=true)
                @test interface_F_B.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
                @test all(k->getproperty(pressure_interface_trace,k)==getproperty(interface_F_B,k),
                    (:candidate_hash,:context_hash,:upstream_output_hash,:trace_hash))
                @test pressure_interface_trace.dynamic_geometry.coordinates_RZ_m==
                    interface_F_B.dynamic_geometry.coordinates_RZ_m
                interface_Bphi=Float64.(vec(interface.B_plasma_T[2,:]))
                interface_Bphi_J=SparseArrays.sparse(interface.B_plasma_jacobian[2:3:192,:])
                @test interface_Bphi==interface_F_B.Bphi_lcfs_T
                @test interface_Bphi_J==interface_F_B.Bphi_field_jacobian
                Bphi_J_difference=SparseArrays.sparse(interface_Bphi_J.-interface_F_B.Bphi_field_jacobian)
                interface_pair=(status=:evaluated_same_state_shared_F_B_point_sampler_consistency,
                    Bphi_source=interface.Bphi_source,
                    Bphi_field_jacobian_source=interface.Bphi_field_jacobian_source,
                    Bphi_T=Tuple(interface_Bphi),
                    Bphi_minus_F_B_max_abs_T=maximum(abs,interface_Bphi.-interface_F_B.Bphi_lcfs_T;init=0.0),
                    Bphi_J_nnz=SparseArrays.nnz(interface_Bphi_J),
                    Bphi_J_minus_F_B_max_abs=maximum(abs,SparseArrays.nonzeros(Bphi_J_difference);init=0.0),
                    independent_oracle=false)
            end
        end
        @test interface_pair.status===:evaluated_same_state_shared_F_B_point_sampler_consistency
        if precheck_mode=="current_topology_smoke"
        # Exercise the actual 65-row production conservation consumer against
        # the refactored F_B trace, then retain the qualified centered h/h2
        # checks for the selected native Bphi and moving-psi directions.
        global_closures=NamedTuple{F._CCP_AXISYMMETRIC_MISSING_CLOSURES}(ntuple(_->nothing,5))
        global_x=component.initial_state
        global_ip=component.normalization_evaluate(global_x)
        global_F_B=component.lcfs_state_F_curl_trace(global_x;
            with_jacobian=true,with_cut_jacobian=true)
        global_value=provider.conservation_evaluator(global_x,global_closures,context)
        global_oracle=provider.jacobian_oracle(:global_conservation,"global",
            global_x,global_closures,context)
        expected_Jn_ids=ntuple(i->"current_topology:LCFS_Jn:ray_$(lpad(string(i),3,'0'))",64)
        @test length(provider.conservation_ids)==65
        @test length(provider.added_global_conservation_ids)==64
        @test provider.conservation_ids[2:end]==expected_Jn_ids
        @test provider.added_global_conservation_ids==expected_Jn_ids
        @test size(global_value.jacobian)==(65,length(global_x))
        @test SparseArrays.issparse(global_value.jacobian)
        @test global_value.residual[1:1]==global_ip.residual[2:2]
        @test global_value.jacobian[1:1,:]==global_ip.jacobian[2:2,:]
        @test global_value.residual[2:end]==global_F_B.Jn_A_per_m2
        @test global_value.jacobian[2:end,:]==global_F_B.jacobian
        @test size(global_F_B.jacobian)==(64,length(global_x))
        @test size(global_F_B.cut_segment_jacobian)==(64,length(global_x))
        global_Ip_oracle_delta=global_value.jacobian[1:1,:]-global_oracle.jacobian[1:1,:]
        global_Ip_oracle_scale=max(1.0,maximum(abs,SparseArrays.nonzeros(
            global_value.jacobian[1:1,:]);init=0.0))
        @test maximum(abs,SparseArrays.nonzeros(global_Ip_oracle_delta);init=0.0)<=
            64eps(Float64)*global_Ip_oracle_scale
        @test global_oracle.jacobian[2:end,:]==global_value.jacobian[2:end,:]
        @test global_value.return_current_integral_is_independent_constraint===false
        @test global_F_B.integrated_current_is_independent_constraint===false
        @test global_F_B.cut_segment_jacobian!==:typed_absent
        global_geometry=global_F_B.dynamic_geometry
        global_Raxis=component.lcfs_dynamic_geometry_data.Raxis
        global_Zaxis=component.lcfs_dynamic_geometry_data.Zaxis
        function global_F_B_native_cells(g)
            cells=NTuple{2,Int}[]
            for (R,Z) in g.coordinates_RZ_m
                i=searchsortedlast(global_Raxis,R);j=searchsortedlast(global_Zaxis,Z)
                1<=i<length(global_Raxis) && 1<=j<length(global_Zaxis) || return nothing
                tolR=128eps(Float64)*max(1.0,abs(R),abs(global_Raxis[i]),abs(global_Raxis[i+1]))
                tolZ=128eps(Float64)*max(1.0,abs(Z),abs(global_Zaxis[j]),abs(global_Zaxis[j+1]))
                min(R-global_Raxis[i],global_Raxis[i+1]-R)>tolR &&
                    min(Z-global_Zaxis[j],global_Zaxis[j+1]-Z)>tolZ || return nothing
                push!(cells,(i,j))
            end
            Tuple(cells)
        end
        global_base_cells=global_F_B_native_cells(global_geometry)
        @test length(global_geometry.coordinates_RZ_m)==64
        @test global_geometry.mask_event===:unchanged
        @test global_base_cells!==nothing && length(global_base_cells)==64
        function check_actual_global_F_B_column(column,h0,label)
            @test isfinite(h0) && h0>0.0
            coordinate_unit=mod(column,4)==2 ? "T" : "Wb rad^-1"
            steps=(h0,h0/2)
            reports=NamedTuple[]
            for step in steps
                xp=copy(global_x);xm=copy(global_x);xp[column]+=step;xm[column]-=step
                plus_F_B=component.lcfs_state_F_curl_trace(xp;
                    with_jacobian=false,with_cut_jacobian=false)
                minus_F_B=component.lcfs_state_F_curl_trace(xm;
                    with_jacobian=false,with_cut_jacobian=false)
                plus_global=provider.conservation_evaluator(xp,global_closures,context)
                minus_global=provider.conservation_evaluator(xm,global_closures,context)
                plus_ip=component.normalization_evaluate(xp)
                minus_ip=component.normalization_evaluate(xm)
                @test plus_F_B.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
                @test minus_F_B.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
                @test plus_F_B.dynamic_geometry.mask_event===:unchanged
                @test minus_F_B.dynamic_geometry.mask_event===:unchanged
                @test plus_F_B.dynamic_geometry.ray_rule===global_geometry.ray_rule
                @test minus_F_B.dynamic_geometry.ray_rule===global_geometry.ray_rule
                @test plus_F_B.dynamic_geometry.first_outward_crossing_signature===
                    global_geometry.first_outward_crossing_signature
                @test minus_F_B.dynamic_geometry.first_outward_crossing_signature===
                    global_geometry.first_outward_crossing_signature
                @test global_F_B_native_cells(plus_F_B.dynamic_geometry)==global_base_cells
                @test global_F_B_native_cells(minus_F_B.dynamic_geometry)==global_base_cells
                @test plus_global.residual[1:1]==plus_ip.residual[2:2]
                @test minus_global.residual[1:1]==minus_ip.residual[2:2]
                @test plus_global.residual[2:end]==plus_F_B.Jn_A_per_m2
                @test minus_global.residual[2:end]==minus_F_B.Jn_A_per_m2
                # Keep the scalar Ip(A) row and 64 Jn(A/m^2) rows in separate
                # finite-difference gates; their norms cannot be combined.
                fd_Ip_A=(plus_global.residual[1]-minus_global.residual[1])/(2step)
                analytic_Ip_A=global_value.jacobian[1,column]
                Ip_A_scale=max(abs(fd_Ip_A),abs(analytic_Ip_A),floatmin(Float64))
                Ip_A_defect=abs(fd_Ip_A-analytic_Ip_A)
                @test isapprox(fd_Ip_A,analytic_Ip_A;rtol=5e-6,atol=5e-11)
                fd_Jn_A_per_m2=(plus_global.residual[2:end].-minus_global.residual[2:end])./(2step)
                analytic_Jn_A_per_m2=collect(global_value.jacobian[2:end,column])
                Jn_A_per_m2_scale=max(F.norm(fd_Jn_A_per_m2),F.norm(analytic_Jn_A_per_m2),floatmin(Float64))
                Jn_A_per_m2_defect=F.norm(fd_Jn_A_per_m2-analytic_Jn_A_per_m2)
                @test isapprox(fd_Jn_A_per_m2,analytic_Jn_A_per_m2;rtol=5e-6,atol=5e-11)
                fd_Jn_F_B=(plus_F_B.Jn_A_per_m2.-minus_F_B.Jn_A_per_m2)./(2step)
                analytic_Jn_F_B=collect(global_F_B.jacobian[:,column])
                @test fd_Jn_F_B==fd_Jn_A_per_m2
                @test analytic_Jn_F_B==analytic_Jn_A_per_m2
                fd_F_B_cut=(plus_F_B.cut_segment_outward_current_A.-
                    minus_F_B.cut_segment_outward_current_A)./(2step)
                analytic_F_B_cut=collect(global_F_B.cut_segment_jacobian[:,column])
                cut_scale=max(F.norm(fd_F_B_cut),F.norm(analytic_F_B_cut),floatmin(Float64))
                cut_defect=F.norm(fd_F_B_cut-analytic_F_B_cut)
                @test isapprox(fd_F_B_cut,analytic_F_B_cut;rtol=5e-6,atol=5e-11)
                push!(reports,(step=step,coordinate_unit=coordinate_unit,
                    Ip_derivative=(unit="A / ("*coordinate_unit*")",fd=fd_Ip_A,analytic=analytic_Ip_A,
                        defect=Ip_A_defect,scale=Ip_A_scale),
                    Jn_derivative=(unit="A m^-2 / ("*coordinate_unit*")",fd_norm=F.norm(fd_Jn_A_per_m2),
                        analytic_norm=F.norm(analytic_Jn_A_per_m2),
                        defect_norm=Jn_A_per_m2_defect,scale=Jn_A_per_m2_scale),
                    F_B_cut_segment_derivative=(unit="A / ("*coordinate_unit*")",fd_norm=F.norm(fd_F_B_cut),
                        analytic_norm=F.norm(analytic_F_B_cut),defect_norm=cut_defect,
                        scale=cut_scale),
                    endpoint_geometry=(mask_unchanged=true,ray_rule_unchanged=true,
                        first_outward_crossing_signature_unchanged=true,
                        native_interpolation_cells_unchanged=true)))
            end
            result=(status=:evaluated_actual_global_65_and_F_B_h_h2_diagnostic,
                label=label,column=column,steps=Tuple(steps),FD=Tuple(reports),
                F_B_cut_path=:actual_state_F_B_cut_segments_not_periodic_Q1_cut,
                FD_tolerance=(Ip_derivative=(rtol=5e-6,atol=5e-11,atol_unit="A / ("*coordinate_unit*")"),
                    Jn_derivative=(rtol=5e-6,atol=5e-11,atol_unit="A m^-2 / ("*coordinate_unit*")"),
                    F_B_cut_segment_derivative=(rtol=5e-6,atol=5e-11,atol_unit="A / ("*coordinate_unit*")")),
                solver_rows_added=0,independent_integral_constraint=false,
                physical_validation=false,global_topology_closed=false)
            println("CURRENT_ACTUAL_GLOBAL_F_B_SELECTED_FD="*F.canonical_json(result))
            flush(stdout)
            result
        end
        global_Bphi_columns=[4k-2 for k in 1:prod(component.grid_shape)]
        global_Bphi_scores=[sum(abs2,global_F_B.jacobian[:,col]) for col in global_Bphi_columns]
        global_Bphi_column=global_Bphi_columns[argmax(global_Bphi_scores)]
        global_Bphi_step=min(1e-4,0.125abs(global_x[global_Bphi_column]))
        @test global_Bphi_scores[argmax(global_Bphi_scores)]>0.0
        @test global_Bphi_step>128eps(Float64)*max(abs(global_x[global_Bphi_column]),1.0)
        global_Bphi_FD=check_actual_global_F_B_column(global_Bphi_column,global_Bphi_step,
            :native_Bphi_selected_actual_global_65)
        global_psi_columns=collect(global_geometry.psi_global_dof_ids)
        global_coordinate_motion=[maximum(abs,view(global_geometry.coordinate_jacobian,:,k))
            for k in eachindex(global_psi_columns)]
        global_moving_native=argmax(global_coordinate_motion)
        global_moving_column=global_psi_columns[global_moving_native]
        global_moving_motion=global_coordinate_motion[global_moving_native]
        @test isfinite(global_moving_motion) && global_moving_motion>0.0
        global_moving_cell_bound=Inf
        for a in 1:64
            i,j=global_base_cells[a]
            R,Z=global_geometry.coordinates_RZ_m[a]
            dR=global_geometry.coordinate_jacobian[2a-1,global_moving_native]
            dZ=global_geometry.coordinate_jacobian[2a,global_moving_native]
            global_moving_cell_bound=min(global_moving_cell_bound,
                abs(dR)>0 ? min(R-global_Raxis[i],global_Raxis[i+1]-R)/abs(dR) : Inf,
                abs(dZ)>0 ? min(Z-global_Zaxis[j],global_Zaxis[j+1]-Z)/abs(dZ) : Inf)
        end
        global_psi_boundary_tangent=global_geometry.boundary_flux_jacobian[global_moving_native]
        global_psi_mask_margin=Inf
        for i in eachindex(global_geometry.candidate_total_psi_Wb_per_rad)
            tangent=(i==global_moving_native ? 1.0 : 0.0)-global_psi_boundary_tangent
            iszero(tangent) || (global_psi_mask_margin=min(global_psi_mask_margin,
                abs(global_geometry.candidate_total_psi_Wb_per_rad[i]-
                    global_geometry.psi_boundary_Wb_per_rad)/abs(tangent)))
        end
        @test isfinite(global_moving_cell_bound) && global_moving_cell_bound>0.0
        @test isfinite(global_psi_mask_margin) && global_psi_mask_margin>0.0
        global_moving_step=min(0.25global_moving_cell_bound,0.25global_psi_mask_margin,
            1e-7/global_moving_motion)
        @test isfinite(global_moving_step) && global_moving_step>0.0
        @test global_moving_step/2>128eps(Float64)*max(abs(global_x[global_moving_column]),1.0)
        global_psi_FD=check_actual_global_F_B_column(global_moving_column,global_moving_step,
            :moving_native_psi_selected_actual_global_65)
        println("CURRENT_ACTUAL_GLOBAL_F_B_FD_SUMMARY="*F.canonical_json((
            status=:evaluated,columns=(Bphi=global_Bphi_column,psi=global_moving_column),
            Bphi_step_h_h2=(global_Bphi_step,global_Bphi_step/2),
            psi_step_h_h2=(global_moving_step,global_moving_step/2),
            psi_motion_per_unit=global_moving_motion,psi_cell_safe_limit=global_moving_cell_bound,
            psi_mask_safe_limit=global_psi_mask_margin,psi_motion_limit=1e-7,
            baseline_ids=length(provider.conservation_ids),Ip_row_is_original_normalization=true,
            current_rows_equal_same_state_F_B=true,F_B_cut_is_diagnostic_only=true,
            solver_rows_added=0,physical_validation=false,global_topology_closed=false)))
        flush(stdout)
        end # current_topology_smoke only; avoid repeating the selected F_B FD in global diagnostic modes
        println("CURRENT_CANONICAL_VS_F_B_JN="*F.canonical_json((
            candidate_state=:component_initial_state,
            canonical_trace=:profile_F_plus_Q1_diagnostic_not_global_rows,
            independent_trace=independent_Ftrace.field_representation,
            same_geometry=(coordinates=same_coordinates,normals=same_normals,
                surface_weights=same_surface_weights),
            canonical_Jn=metric(canonical_Jn),F_B_Jn=metric(F_B_Jn),
            F_B_minus_canonical_Jn=metric(delta_Jn),
            F_B_minus_canonical_Jn_A_per_m2=Tuple(delta_Jn),
            plasma_side_interface_B_in=interface_pair,
            physical_budget=:unknown_not_configured,acceptance_threshold=:not_configured,
            normal_current_observation=lcfs_current.normal_current_diagnostic.status,
            physical_no_normal_current_acceptance=:typed_absent,
            physical_acceptance=:not_established,solver_rows_added=0,
            global_topology_closed=false,closure_evidence_created=false)));flush(stdout)
    end
    # Manufactured same-state field with every original masked regional F row
    # satisfied exactly. This exercises the source curl, rather than assigning
    # the expected zero Jn in the test or the implementation.
    conforming_F_state=copy(component.initial_state)
    Rnative=provider.lcfs_current_numeric_data.profile_row_numeric_data.R
    for k in eachindex(lcfs_current.regional_F_target_native_T_m)
        conforming_F_state[4k-2]=lcfs_current.regional_F_target_native_T_m[k]/Rnative[k]
    end
    conforming_F_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
        provider.lcfs_current_numeric_data,conforming_F_state;with_jacobian=true)
    @test conforming_F_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
    @test maximum(abs,conforming_F_trace.regional_F_row_residuals_T_m)<=
        512eps(Float64)*max(1.0,maximum(abs,conforming_F_trace.regional_F_target_native_T_m))
    Frow_curl_scale=maximum(abs,conforming_F_trace.regional_F_target_native_T_m)/
        (component.profile_law.mu0_N_per_A2*minimum(provider.lcfs_current_numeric_data.Raxis)*
            min(minimum(abs.(diff(provider.lcfs_current_numeric_data.Raxis))),
                minimum(abs.(diff(provider.lcfs_current_numeric_data.Zaxis)))))
    @test maximum(abs,conforming_F_trace.Jn_A_per_m2;init=0.0)<=
        512eps(Float64)*max(1.0,Frow_curl_scale)
    # A one-node off-constraint perturbation must produce a real curl residual
    # and the full 64-row analytic column must match centered differences.
    if reuse_local_fd_mode
        println("CURRENT_LOCAL_FD_REUSE="*F.canonical_json((
            status=:reused_prequalified_R9_local_current_FD,
            reference_run="up2_actual_periodic_current_rows_short_20261010_r9",
            reference_stdout_sha256="1834994727bd066db1f4851fc7fadca86801ba5c23081aaa39d275e2c3a7a0fd",
            scope=:offconstraint_profile_spatial_moving_psi_and_current_fd,
            fresh_baseline_current_and_conforming_F_traces_retained=true,
            jacobian_credit=false,physical_validation=false)))
        flush(stdout)
    else
    q1_scores=[abs(conforming_F_trace.jacobian[a,
        4conforming_F_trace.q1_native_node_signature[a][l]-2]) for a in 1:64 for l in 1:4]
    q1_probe_flat=argmax(q1_scores);q1_probe_ray=div(q1_probe_flat-1,4)+1
    q1_probe_local=mod1(q1_probe_flat,4)
    q1_probe_node=conforming_F_trace.q1_native_node_signature[q1_probe_ray][q1_probe_local]
    @test q1_scores[q1_probe_flat]>0.0
    offconstraint_state=copy(conforming_F_state);offconstraint_column=4q1_probe_node-2
    offconstraint_delta=1e-6*max(abs(offconstraint_state[offconstraint_column]),1e-3)
    offconstraint_state[offconstraint_column]+=offconstraint_delta
    offconstraint_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
        provider.lcfs_current_numeric_data,offconstraint_state;with_jacobian=true)
    @test offconstraint_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
    @test abs(offconstraint_trace.Jn_A_per_m2[q1_probe_ray])>0.0
    offconstraint_fd_step=offconstraint_delta/16
    offconstraint_plus=copy(offconstraint_state);offconstraint_minus=copy(offconstraint_state)
    offconstraint_plus[offconstraint_column]+=offconstraint_fd_step
    offconstraint_minus[offconstraint_column]-=offconstraint_fd_step
    offconstraint_plus_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
        provider.lcfs_current_numeric_data,offconstraint_plus;with_jacobian=false)
    offconstraint_minus_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
        provider.lcfs_current_numeric_data,offconstraint_minus;with_jacobian=false)
    @test offconstraint_plus_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
    @test offconstraint_minus_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
    @test offconstraint_plus_trace.q1_native_cell_signature==offconstraint_trace.q1_native_cell_signature
    @test offconstraint_minus_trace.q1_native_cell_signature==offconstraint_trace.q1_native_cell_signature
    offconstraint_fd=(offconstraint_plus_trace.residual.-offconstraint_minus_trace.residual)./(2offconstraint_fd_step)
    @test isapprox(offconstraint_fd,collect(offconstraint_trace.jacobian[:,offconstraint_column]);
        rtol=5e-6,atol=5e-11)
    # Variable GS4 profile coefficient and dynamic endpoint columns are part of
    # the same residual Jacobian through the original regional F-row defect D.
    profile_domain=provider.lcfs_current_numeric_data.state_domain
    profile_fd_columns=Int[]
    profile_domain.vary_profile_coefficients && push!(profile_fd_columns,profile_domain.coefficient_columns[2])
    profile_domain.dynamic_profile_span && profile_domain.vary_profile_coefficients &&
        append!(profile_fd_columns,profile_domain.span_columns)
    profile_fd_reports=NamedTuple[]
    profile_F_base=F._ccp_full_native_profile_evaluate(
        provider.lcfs_current_numeric_data.profile_row_numeric_data,component.initial_state)
    profile_span=F._ccp_full_native_profile_span(profile_domain,component.initial_state)
    profile_core_ids=findall(component.core_mask)
    profile_psi=[component.initial_state[4k] for k in profile_core_ids]
    profile_q1_support_ids=sort!(unique!(collect(Iterators.flatten(lcfs_current.q1_native_node_signature))))
    @test !isempty(profile_q1_support_ids)
    @test all(k->1<=k<=prod(component.grid_shape),profile_q1_support_ids)
    @test size(profile_F_base.jacobian,2)==length(component.initial_state)
    @test size(profile_F_base.jacobian,1)>=prod(component.grid_shape)
    profile_support_target=initial_F_target[profile_q1_support_ids]
    profile_target_scale=max(maximum(abs,profile_support_target),floatmin(Float64))
    profile_target_ulp=eps(profile_target_scale)
    for col in unique(profile_fd_columns)
        target_sensitivity=maximum(abs,profile_F_base.jacobian[profile_q1_support_ids,col])
        nominal_step=cbrt(eps(Float64))*max(1.0,abs(component.initial_state[col]))
        representable_step=target_sensitivity>0.0 ?
            128profile_target_ulp/target_sensitivity : Inf
        domain_margin=if col in profile_domain.span_columns
            endpoint=col==profile_domain.span_columns[1] ? profile_span.axis : profile_span.boundary
            minimum(abs.(profile_psi.-endpoint))
        elseif col==profile_domain.coefficient_columns[2]
            radicand_margin=minimum(begin
                shape=F._ccp_full_native_profile_shape(component.initial_state[4k],
                    profile_span.axis,profile_span.boundary)
                radicand=profile_domain.law.fvac_T_m^2+
                    2profile_domain.law.mu0_N_per_A2*component.initial_state[col]*
                    profile_domain.law.Raxis_m*shape.integral
                radicand_sensitivity=2profile_domain.law.mu0_N_per_A2*
                    profile_domain.law.Raxis_m*shape.integral
                iszero(radicand_sensitivity) ? Inf : radicand/abs(radicand_sensitivity)
            end for k in profile_core_ids)
            source_L=component.initial_state[profile_domain.coefficient_columns[1]]+
                component.initial_state[profile_domain.coefficient_columns[2]]
            min(radicand_margin,abs(source_L))
        else
            error("unexpected profile-current FD column $col")
        end
        admissible_step=col in profile_domain.span_columns ?
            0.25*min(domain_margin,abs(profile_span.delta)) : 0.25*domain_margin
        base_step=min(max(nominal_step,representable_step),admissible_step)
        step_feasible=isfinite(target_sensitivity) && target_sensitivity>0.0 &&
            isfinite(domain_margin) && domain_margin>0.0 && isfinite(base_step) &&
            base_step>=representable_step && base_step>0.0 &&
            base_step/2>=64profile_target_ulp/target_sensitivity
        println("CURRENT_PROFILE_COLUMN_FD_STEP="*F.canonical_json((column=col,
            step=base_step,step_half=base_step/2,nominal_step=nominal_step,
            target_sensitivity_T_m_per_unit=target_sensitivity,target_ulp_T_m=profile_target_ulp,
            target_resolution_basis=:max_q1_support_target_ulp_over_max_q1_support_F_sensitivity_heuristic_not_a_bound,
            q1_support_count=length(profile_q1_support_ids),
            domain_margin=domain_margin,admissible_step=admissible_step,
            step_feasible=step_feasible)));flush(stdout)
        @test step_feasible
        step_feasible || error("profile-current FD has no representable two-sided step within the native profile domain for column $col")
        function profile_pair(step)
            plus=copy(component.initial_state);minus=copy(component.initial_state)
            plus[col]+=step;minus[col]-=step
            plus_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
                provider.lcfs_current_numeric_data,plus;with_jacobian=false)
            minus_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
                provider.lcfs_current_numeric_data,minus;with_jacobian=false)
            @test plus_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
            @test minus_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
            @test plus_trace.q1_native_cell_signature==lcfs_current.q1_native_cell_signature
            @test minus_trace.q1_native_cell_signature==lcfs_current.q1_native_cell_signature
            ((plus_trace.residual.-minus_trace.residual)./(2step),plus_trace,minus_trace)
        end
        fd,plus_trace,minus_trace=profile_pair(base_step)
        fd_h2,plus_trace_h2,minus_trace_h2=profile_pair(base_step/2)
        analytic=collect(lcfs_current.jacobian[:,col])
        norm_scale=max(maximum(abs,fd),maximum(abs,analytic),floatmin(Float64))
        scaled_defect=maximum(abs,fd-analytic)/norm_scale
        truncation_defect=maximum(abs,fd-fd_h2)/
            max(maximum(abs,fd),maximum(abs,fd_h2),floatmin(Float64))
        report=(column=col,step=base_step,step_half=base_step/2,
            target_sensitivity_T_m_per_unit=target_sensitivity,target_ulp_T_m=profile_target_ulp,
            target_resolution_basis=:max_q1_support_target_ulp_over_max_q1_support_F_sensitivity_heuristic_not_a_bound,
            q1_support_count=length(profile_q1_support_ids),
            domain_margin=domain_margin,admissible_step=admissible_step,
            derivative_norm=norm_scale,scaled_defect=scaled_defect,
            truncation_scaled_defect=truncation_defect,
            max_abs_defect=maximum(abs,fd-analytic))
        println("CURRENT_PROFILE_COLUMN_FD="*F.canonical_json(report));flush(stdout)
        @test isapprox(fd,analytic;rtol=5e-6,atol=5e-11)
        @test isapprox(fd_h2,analytic;rtol=5e-6,atol=5e-11)
        @test isapprox(fd,fd_h2;rtol=5e-6,atol=5e-11)
        push!(profile_fd_reports,report)
    end
    @test length(profile_fd_reports)==length(unique(profile_fd_columns))
    @test all(report->hasproperty(report,:max_abs_defect),profile_fd_reports)
    # Independent spatial oracle: evaluate the actual plasma-spline plus exact PF
    # scalar psi, then P(total psi)+Q1(d) on the one-sided inside formula's smooth
    # extension at R±h/Z±h. This is not an exterior trace or interface-regularity test.
    current_data=provider.lcfs_current_numeric_data
    geometry_data=current_data.lcfs_dynamic_geometry_data
    spatial_trace=offconstraint_trace
    trace_geometry=spatial_trace.dynamic_geometry
    Raxis=geometry_data.Raxis;Zaxis=geometry_data.Zaxis
    @test current_data.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1
    spatial_model=F._ccp_native_geometry_model_id(current_data.native_field_model_id)
    @test spatial_model===:plasma_spline_plus_exact_pf_potential_jet_v1
    ray_margins=[begin
        i,j=spatial_trace.q1_native_cell_signature[a]
        R,Z=trace_geometry.coordinates_RZ_m[a]
        min(R-Raxis[i],Raxis[i+1]-R,Z-Zaxis[j],Zaxis[j+1]-Z)
    end for a in 1:64]
    margin_floor=128eps(Float64)*max(1.0,maximum(abs,Raxis),maximum(abs,Zaxis))
    spatial_candidates=[a for a in 1:64 if q1_probe_node in spatial_trace.q1_native_node_signature[a] &&
        ray_margins[a]>margin_floor]
    @test !isempty(spatial_candidates)
    spatial_ray=spatial_candidates[argmax(ray_margins[spatial_candidates])]
    spatial_margin=ray_margins[spatial_ray]
    @test spatial_margin>margin_floor
    spatial_h=min(0.125*spatial_margin,1e-6)
    spatial_cell=spatial_trace.q1_native_cell_signature[spatial_ray]
    spatial_R,spatial_Z=trace_geometry.coordinates_RZ_m[spatial_ray]
    spatial_nodes=collect(spatial_trace.q1_native_node_signature[spatial_ray])
    spatial_state=collect(offconstraint_state)
    spatial_defect=collect(spatial_trace.regional_F_row_residuals_T_m)
    @test maximum(abs,spatial_defect[spatial_nodes])>0.0
    spatial_domain=current_data.state_domain
    spatial_psi_nodes=F._ccp_full_native_plasma_nodes(spatial_state,geometry_data,spatial_model)
    spatial_psi_matrix=permutedims(reshape(spatial_psi_nodes,geometry_data.nz,geometry_data.nr))
    spatial_profile_span=F._ccp_full_native_profile_span(spatial_domain,spatial_state)
    spatial_profile_v=spatial_domain.vary_profile_coefficients ?
        spatial_state[spatial_domain.coefficient_columns[2]] :
        spatial_domain.law.L_A_per_m2*(1-spatial_domain.law.Beta0)
    function independent_point_F(r,z)
        rw=F._ccp_native_spline_point_weights(Raxis,geometry_data.Dr,[r])
        zw=F._ccp_native_spline_point_weights(Zaxis,geometry_data.Dz,[z])
        plasma_psi=sum(rw.value[1,i]*zw.value[1,j]*spatial_psi_matrix[i,j]
            for i in 1:geometry_data.nr for j in 1:geometry_data.nz)
        pf_psi=F._ccp_full_native_exact_pf_jet(geometry_data,r,z).psi
        total_psi=plasma_psi+pf_psi
        shape=F._ccp_full_native_profile_shape(total_psi,spatial_profile_span.axis,spatial_profile_span.boundary)
        law=spatial_domain.law
        radicand=law.fvac_T_m^2+2law.mu0_N_per_A2*spatial_profile_v*law.Raxis_m*shape.integral
        @test isfinite(radicand) && radicand>0.0
        P=sqrt(radicand)
        i=searchsortedlast(Raxis,r);j=searchsortedlast(Zaxis,z)
        @test (i,j)==spatial_cell
        u=(r-Raxis[i])/(Raxis[i+1]-Raxis[i]);v=(z-Zaxis[j])/(Zaxis[j+1]-Zaxis[j])
        nodes=((i-1)*geometry_data.nz+j,i*geometry_data.nz+j,
            (i-1)*geometry_data.nz+j+1,i*geometry_data.nz+j+1)
        N=((1-u)*(1-v),u*(1-v),(1-u)*v,u*v)
        correction=sum(N[k]*spatial_defect[nodes[k]] for k in 1:4)
        (F=P+correction,plasma_psi=plasma_psi,pf_psi=pf_psi,total_psi=total_psi,
            profile_F=P,Q1_defect=correction)
    end
    function independent_F_gradient(h)
        FR=(independent_point_F(spatial_R+h,spatial_Z).F-independent_point_F(spatial_R-h,spatial_Z).F)/(2h)
        FZ=(independent_point_F(spatial_R,spatial_Z+h).F-independent_point_F(spatial_R,spatial_Z-h).F)/(2h)
        (FR=FR,FZ=FZ)
    end
    spatial_components=independent_point_F(spatial_R,spatial_Z)
    @test isapprox(spatial_components.total_psi,
        trace_geometry.surface_psi_Wb_per_rad[spatial_ray];rtol=5e-6,atol=5e-11)
    spatial_fd_h=independent_F_gradient(spatial_h)
    spatial_fd_h2=independent_F_gradient(spatial_h/2)
    spatial_FR_trace=spatial_R*spatial_trace.fields[spatial_ray,2]+spatial_trace.fields[spatial_ray,1]
    spatial_FZ_trace=spatial_R*spatial_trace.fields[spatial_ray,3]
    spatial_nR,spatial_nZ=trace_geometry.normals_RZ[spatial_ray]
    spatial_mu0=spatial_domain.law.mu0_N_per_A2
    spatial_Jn_fd(hgrad)=spatial_nR*(-hgrad.FZ/(spatial_mu0*spatial_R))+
        spatial_nZ*(hgrad.FR/(spatial_mu0*spatial_R))
    spatial_Jn_fd_h=spatial_Jn_fd(spatial_fd_h)
    spatial_Jn_fd_h2=spatial_Jn_fd(spatial_fd_h2)
    spatial_trunc_R=abs(spatial_fd_h.FR-spatial_fd_h2.FR)
    spatial_trunc_Z=abs(spatial_fd_h.FZ-spatial_fd_h2.FZ)
    spatial_trunc_Jn=abs(spatial_Jn_fd_h-spatial_Jn_fd_h2)
    @test isapprox(spatial_fd_h.FR,spatial_FR_trace;rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_fd_h2.FR,spatial_FR_trace;rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_fd_h.FZ,spatial_FZ_trace;rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_fd_h2.FZ,spatial_FZ_trace;rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_fd_h.FR,spatial_fd_h2.FR;rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_fd_h.FZ,spatial_fd_h2.FZ;rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_Jn_fd_h,spatial_trace.Jn_A_per_m2[spatial_ray];rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_Jn_fd_h2,spatial_trace.Jn_A_per_m2[spatial_ray];rtol=5e-6,atol=5e-11)
    @test isapprox(spatial_Jn_fd_h,spatial_Jn_fd_h2;rtol=5e-6,atol=5e-11)
    println("CURRENT_SPATIAL_SCALAR_F_FD="*F.canonical_json((ray=spatial_ray,
        cell=spatial_cell,step=spatial_h,step_half=spatial_h/2,
        plasma_psi=spatial_components.plasma_psi,pf_psi=spatial_components.pf_psi,
        total_psi=spatial_components.total_psi,profile_F=spatial_components.profile_F,
        Q1_defect=spatial_components.Q1_defect,
        F_R_fd_h=spatial_fd_h.FR,F_R_fd_h2=spatial_fd_h2.FR,F_R_trace=spatial_FR_trace,
        F_Z_fd_h=spatial_fd_h.FZ,F_Z_fd_h2=spatial_fd_h2.FZ,F_Z_trace=spatial_FZ_trace,
        Jn_fd_h=spatial_Jn_fd_h,Jn_fd_h2=spatial_Jn_fd_h2,Jn_trace=spatial_trace.Jn_A_per_m2[spatial_ray],
        truncation=(R=spatial_trunc_R,Z=spatial_trunc_Z,Jn=spatial_trunc_Jn),
        oracle=:plasma_spline_plus_exact_PF_plus_exact_regional_F_rows)));flush(stdout)
    # Full 64-row native-psi FD. Select the column with largest actual contour
    # motion, then derive h from Q1-cell and core psi-mask margins.
    psi_global_columns=collect(trace_geometry.psi_global_dof_ids)
    coordinate_motion=[maximum(abs,trace_geometry.coordinate_jacobian[:,k]) for k in eachindex(psi_global_columns)]
    moving_native=argmax(coordinate_motion)
    moving_column=psi_global_columns[moving_native]
    moving_motion=coordinate_motion[moving_native]
    @test moving_motion>0.0
    moving_cell_bound=Inf
    for a in 1:64
        i,j=spatial_trace.q1_native_cell_signature[a]
        R,Z=trace_geometry.coordinates_RZ_m[a]
        dR=trace_geometry.coordinate_jacobian[2a-1,moving_native]
        dZ=trace_geometry.coordinate_jacobian[2a,moving_native]
        moving_cell_bound=min(moving_cell_bound,
            abs(dR)>0 ? min(R-Raxis[i],Raxis[i+1]-R)/abs(dR) : Inf,
            abs(dZ)>0 ? min(Z-Zaxis[j],Zaxis[j+1]-Z)/abs(dZ) : Inf)
    end
    moving_psi_mask_margin=Inf
    if component.core_mask[moving_native]
        moving_span=F._ccp_full_native_profile_span(spatial_domain,spatial_state)
        moving_q=(spatial_state[moving_column]-moving_span.axis)/(-moving_span.delta)
        moving_psi_mask_margin=min(moving_q,1-moving_q)*abs(moving_span.delta)
    end
    moving_step_from_motion=1e-7/moving_motion
    moving_coordinate_scale=maximum(abs,(coordinate for point in trace_geometry.coordinates_RZ_m for coordinate in point))
    moving_motion_floor=128eps(Float64)*moving_coordinate_scale
    moving_safe_step=min(0.25*moving_cell_bound,0.25*moving_psi_mask_margin,moving_step_from_motion)
    @test isfinite(moving_safe_step) && moving_safe_step>0.0
    known_domain_messages=("dynamic LCFS mask/topology changed; rebuild required",
        "native mask cannot cross its profile flux range",
        "variable profile violates the positive finite F branch",
        "dynamic LCFS state violates positive-Bphi or nonnegative-pressure support")
    known_branch_reasons=(:critical_point_inventory_empty,:critical_point_hessian_singular,
        :critical_point_step_nonfinite,:critical_point_left_spline_domain,
        :critical_point_type_or_refinement_gate_failed,:critical_point_inventory_changed,
        :refined_critical_points_became_duplicates,:primary_O_point_correspondence_changed,
        :freegs_primary_O_to_X_eligibility_inventory_changed,:primary_X_point_correspondence_changed,
        :psi_normalization_span_invalid,:candidate_core_mask_changed,:ray_theta_offset_branch_changed,
        :ray_offset_intersects_xpoint,:radial_ray_has_no_domain_exit,:ray_does_not_start_inside_core,
        :first_outward_psi1_crossing_missing,:full_weight_contour_refinement_failed,
        :ray_root_residual_exceeds_producer_tolerance,:lcfs_normal_gradient_invalid,
        :lcfs_normal_points_inward,:ray_tangent_to_lcfs,:lcfs_inside_outside_mask_support_changed,
        :q1_current_ray_on_native_cell_edge,:q1_current_ray_outside_native_cells,
        :profile_F_root_invalid_at_dynamic_LCFS,:candidate_dynamic_lcfs_geometry_unavailable)
    function moving_pair_at(step)
        plus=copy(spatial_state);minus=copy(spatial_state)
        plus[moving_column]+=step;minus[moving_column]-=step
        plus_trace=nothing;minus_trace=nothing
        for (side,trial_state) in ((:plus,plus),(:minus,minus))
            trace_value=try
                F._ccp_full_native_dynamic_lcfs_curl_current_trace(current_data,trial_state;with_jacobian=false)
            catch err
                if err isa DomainError && err.msg in known_domain_messages
                    return (status=:known_domain_error,side=side,reason=err.msg)
                end
                rethrow()
            end
            if trace_value.status!==:evaluated_dynamic_LCFS_state_Bphi_curl_current
                reason=hasproperty(trace_value,:reason) ? trace_value.reason : nothing
                reason in known_branch_reasons || error("unexpected moving-current endpoint outcome: $(trace_value.status), $(reason)")
                return (status=:known_branch_change,side=side,reason=reason)
            end
            side===:plus ? (plus_trace=trace_value) : (minus_trace=trace_value)
        end
        same_branch(t)=t.dynamic_geometry.ray_rule===trace_geometry.ray_rule &&
            t.dynamic_geometry.mask_event===trace_geometry.mask_event===:unchanged &&
            t.dynamic_geometry.first_outward_crossing_signature===trace_geometry.first_outward_crossing_signature &&
            t.q1_native_cell_signature==spatial_trace.q1_native_cell_signature
        same_branch(plus_trace) && same_branch(minus_trace) ||
            return (status=:known_branch_change,side=:pair,reason=:ray_mask_or_q1_cell_signature_changed)
        point_motion(t)=maximum(abs,(t.dynamic_geometry.coordinates_RZ_m[a][q]-trace_geometry.coordinates_RZ_m[a][q]
            for a in 1:64 for q in 1:2))
        plus_motion=point_motion(plus_trace);minus_motion=point_motion(minus_trace)
        (status=:evaluated,step=step,plus_trace=plus_trace,minus_trace=minus_trace,
            plus_motion=plus_motion,minus_motion=minus_motion)
    end
    function bounded_moving_pair(start_step)
        last_outcome=nothing
        for attempt in 1:8
            trial_step=start_step/(2.0^(attempt-1))
            outcome=moving_pair_at(trial_step)
            if outcome.status===:evaluated
                if max(outcome.plus_motion,outcome.minus_motion)<=1e-7
                    return merge(outcome,(attempts=attempt,last_absence=last_outcome))
                end
                last_outcome=(status=:motion_exceeds_1e_7_m,side=:pair,
                    reason=max(outcome.plus_motion,outcome.minus_motion))
                continue
            end
            last_outcome=(status=outcome.status,side=outcome.side,reason=outcome.reason)
        end
        error("bounded moving-current FD could not find a same-branch Q1-owned step: $(last_outcome)")
    end
    moving_pair_h=bounded_moving_pair(moving_safe_step)
    moving_pair_h2=bounded_moving_pair(moving_pair_h.step/2)
    @test min(moving_pair_h.plus_motion,moving_pair_h.minus_motion)>=moving_motion_floor
    @test min(moving_pair_h2.plus_motion,moving_pair_h2.minus_motion)>=moving_motion_floor
    @test max(moving_pair_h.plus_motion,moving_pair_h.minus_motion)<=1e-7
    @test max(moving_pair_h2.plus_motion,moving_pair_h2.minus_motion)<=1e-7
    moving_fd_reports=NamedTuple[];moving_fd_vectors=Vector{Float64}[]
    moving_analytic=collect(spatial_trace.jacobian[:,moving_column])
    for pair in (moving_pair_h,moving_pair_h2)
        fd=(pair.plus_trace.residual.-pair.minus_trace.residual)./(2pair.step)
        scale=max(maximum(abs,fd),maximum(abs,moving_analytic),floatmin(Float64))
        defect=maximum(abs,fd-moving_analytic)
        @test defect<=5e-6*scale+5e-11
        push!(moving_fd_reports,(step=pair.step,defect_inf=defect,scaled_norm=scale,
            plus_motion_m=pair.plus_motion,minus_motion_m=pair.minus_motion,attempts=pair.attempts))
        push!(moving_fd_vectors,fd)
    end
    moving_truncation=maximum(abs,moving_fd_vectors[1]-moving_fd_vectors[2])
    moving_truncation_scale=max(maximum(abs,moving_fd_vectors[1]),maximum(abs,moving_fd_vectors[2]),floatmin(Float64))
    @test moving_truncation<=5e-6*moving_truncation_scale+5e-11
    moving_peak=argmax(abs.(moving_analytic))
    @test abs(moving_analytic[moving_peak])>0.0
    println("CURRENT_NATIVE_PSI_GEOMETRY_FD="*F.canonical_json((column=moving_column,
        native_psi_index=moving_native,max_coordinate_motion_per_Wb=moving_motion,
        psi_mask_margin_Wb=moving_psi_mask_margin,q1_cell_safe_step=moving_cell_bound,
        h_safe=moving_safe_step,h_from_target_motion=moving_step_from_motion,
        motion_floor_m=moving_motion_floor,motion_upper_m=1e-7,
        steps=Tuple(moving_fd_reports),max_fd_h_vs_h2=moving_truncation,
        truncation_scaled_norm=moving_truncation_scale,peak_row=moving_peak,peak_analytic=moving_analytic[moving_peak],
        fixed_q1_cells=true,fixed_first_outward_crossing_signature=true,full_64_rows=true)));flush(stdout)
    println("CURRENT_MASKED_FROW_OFFCONSTRAINT_FD="*F.canonical_json((
        probe_ray=q1_probe_ray,probe_native_id=q1_probe_node,column=offconstraint_column,
        step=offconstraint_fd_step,offconstraint_current=offconstraint_trace.Jn_A_per_m2[q1_probe_ray],
        full_64_row_fd=Tuple(offconstraint_fd),profile_fd=Tuple(profile_fd_reports))));flush(stdout)
    end
    cut_fd_status=:not_applicable_legacy_candidate
    cut_fd_reports=NamedTuple[];cut_endpoint_checks=NamedTuple[]
    cut_selected_column=nothing;cut_selected_direct=nothing;cut_selected_geometry=nothing;cut_selected_net=nothing
    cut_truncation_estimate=nothing;cut_component_resolution_floor=10*5e-11
    if provider.current_topology!==nothing && !short_model_mode && !reuse_local_fd_mode
        if cut_jacobian_status===:typed_absent
            cut_fd_status=:lawful_typed_absent_no_jacobian_credit
        elseif !cut_jacobian_abi_valid || cut_status!==:evaluated_Jphi_Q1_LCFS_cut_current
            cut_fd_status=:invalid_or_missing_jacobian_abi_no_fd_credit
        else
            direct=cut_direct_jacobian
            geometry_term=cut_geometry_jacobian
            cut_candidates=filter(col->!iszero(direct[1,col]) && !iszero(geometry_term[1,col]),
                provider.psi_dofs)
            if isempty(cut_candidates)
                cut_fd_status=:typed_absent_no_psi_column_with_both_nonzero_terms
            else
                cut_resolved=filter(col->abs(direct[1,col])>cut_component_resolution_floor &&
                    abs(geometry_term[1,col])>cut_component_resolution_floor &&
                    abs(direct[1,col]+geometry_term[1,col])>cut_component_resolution_floor,
                    cut_candidates)
                if isempty(cut_resolved)
                    cut_fd_status=:unresolved_below_accuracy_no_fd_credit
                else
                    cut_psi_column=cut_resolved[argmax([
                        min(abs(direct[1,col]),abs(geometry_term[1,col]),
                            abs(direct[1,col]+geometry_term[1,col])) for col in cut_resolved])]
                    cut_selected_column=cut_psi_column
                    cut_selected_direct=direct[1,cut_psi_column]
                    cut_selected_geometry=geometry_term[1,cut_psi_column]
                    cut_selected_net=cut_selected_direct+cut_selected_geometry
                    cut_native=cut_psi_column÷4
                    cut_span=abs(component.profile_law.psi_axis_wb_per_rad-
                        component.profile_law.psi_boundary_wb_per_rad)
                    cut_base_step=(1e-4/128)*max(cut_span,abs(component.initial_state[cut_psi_column]))
                    cut_geometry=lcfs_current.dynamic_geometry
                    cut_margins=abs.(cut_geometry.candidate_total_psi_Wb_per_rad.-
                        cut_geometry.psi_boundary_Wb_per_rad)
                    cut_boundary_tangent=cut_geometry.boundary_flux_jacobian[cut_native]
                    cut_safe=all(i->begin
                        boundary_tangent=(i==cut_native ? 1.0 : 0.0)-cut_boundary_tangent
                        iszero(boundary_tangent) || 8cut_base_step*abs(boundary_tangent)<cut_margins[i]
                    end,eachindex(cut_margins))
                    if cut_safe
                        cut_fd_status=:pending_endpoint_evaluation
                        for h in (cut_base_step,cut_base_step/2)
                            xp=copy(component.initial_state);xm=copy(component.initial_state)
                            xp[cut_psi_column]+=h;xm[cut_psi_column]-=h
                            cp=provider.periodic_cut_current_diagnostic(xp,context)
                            cm=provider.periodic_cut_current_diagnostic(xm,context)
                            cp_status=get(cp,:status,:missing_status);cm_status=get(cm,:status,:missing_status)
                            cp_mask=get(cp,:geometry_mask_event,nothing);cm_mask=get(cm,:geometry_mask_event,nothing)
                            cp_signature=get(cp,:cut_piece_signature,nothing)
                            cm_signature=get(cm,:cut_piece_signature,nothing)
                            signature_match=hasproperty(cut,:cut_piece_signature) &&
                                cp_signature==cut.cut_piece_signature && cm_signature==cut.cut_piece_signature
                            branch_match=cp_mask===:unchanged && cm_mask===:unchanged && signature_match
                            cp_current=get(cp,:current_integral_A,nothing)
                            cm_current=get(cm,:current_integral_A,nothing)
                            endpoint_ok=cp_status===:evaluated_Jphi_Q1_LCFS_cut_current &&
                                cm_status===:evaluated_Jphi_Q1_LCFS_cut_current &&
                                cp_current isa Real && cm_current isa Real &&
                                isfinite(cp_current) && isfinite(cm_current)
                            push!(cut_endpoint_checks,(step=h,plus_status=cp_status,minus_status=cm_status,
                                plus_reason=get(cp,:reason,get(cp,:jacobian_absence,nothing)),
                                minus_reason=get(cm,:reason,get(cm,:jacobian_absence,nothing)),
                                plus_mask_event=cp_mask,minus_mask_event=cm_mask,
                                complete_cut_signature_match=branch_match,
                                plus_integral_A=cp_current,minus_integral_A=cm_current,
                                endpoint_fields_available=endpoint_ok))
                            if endpoint_ok && branch_match
                                fd_current=(cp_current-cm_current)/(2h)
                                push!(cut_fd_reports,(column=cut_psi_column,step=h,fd=fd_current,
                                    analytic=cut.jacobian[1,cut_psi_column],
                                    absolute_defect=abs(fd_current-cut.jacobian[1,cut_psi_column])))
                            elseif !endpoint_ok
                                cut_fd_status=:typed_absent_perturbed_state_no_jacobian_credit
                            else
                                cut_fd_status=:typed_absent_cut_branch_changed_no_jacobian_credit
                            end
                        end
                        if length(cut_fd_reports)==2
                            fd_h=cut_fd_reports[1].fd;fd_h2=cut_fd_reports[2].fd
                            cut_truncation_estimate=abs(fd_h-fd_h2)/3
                            cut_component_resolution_floor=10*5e-11+cut_truncation_estimate+
                                5e-6*abs(cut_selected_net)
                            components_resolved=abs(cut_selected_direct)>cut_component_resolution_floor &&
                                abs(cut_selected_geometry)>cut_component_resolution_floor &&
                                abs(cut_selected_net)>cut_component_resolution_floor
                            cut_fd_status=components_resolved ? :selected_actual_consumer_fd_diagnostic :
                                :unresolved_below_accuracy_no_fd_credit
                        elseif cut_fd_status===:pending_endpoint_evaluation
                            cut_fd_status=:typed_absent_endpoint_state_unavailable_no_jacobian_credit
                        end
                    else
                        cut_fd_status=:typed_absent_mask_safe_step_unavailable
                    end
                end
            end
        end
    end
    short_model_mode && provider.current_topology!==nothing &&
        (cut_fd_status=:skipped_global_model_short)
    reuse_local_fd_mode && provider.current_topology!==nothing &&
        (cut_fd_status=:reused_prequalified_R9_cut_fd)
    println("CURRENT_CUT_FD="*F.canonical_json((status=cut_fd_status,
        current_path=:periodic_native_Q1_cut_current_diagnostic,
        selected_psi_column=cut_selected_column,selected_direct_current_component=cut_selected_direct,
        selected_moving_geometry_component=cut_selected_geometry,selected_net_jacobian=cut_selected_net,
        endpoint_checks=Tuple(cut_endpoint_checks),total_fd_reports=Tuple(cut_fd_reports),
        measured_centered_difference_truncation=cut_truncation_estimate,
        component_resolution_floor=cut_component_resolution_floor,
        original_fd_rtol=5e-6,original_fd_atol=5e-11,jacobian_credit=false,
        independent_oracle_credit=false,physical_or_closure_credit=false)))
    flush(stdout)
    # Report the FD outcome before failing on an evaluated but malformed callback ABI.
    @test cut_status===:evaluated_Jphi_Q1_LCFS_cut_current
    if cut_status===:evaluated_Jphi_Q1_LCFS_cut_current
        @test cut_jacobian_abi_valid
        if cut_jacobian_status===:available_unvalidated
            @test cut_total_jacobian==cut_direct_jacobian+cut_geometry_jacobian
        end
    end
    # Assertions and the original total-derivative budget follow the compact outcome log.
    for endpoint in cut_endpoint_checks
        @test endpoint.plus_status===:evaluated_Jphi_Q1_LCFS_cut_current
        @test endpoint.minus_status===:evaluated_Jphi_Q1_LCFS_cut_current
        if endpoint.plus_status===:evaluated_Jphi_Q1_LCFS_cut_current &&
                endpoint.minus_status===:evaluated_Jphi_Q1_LCFS_cut_current
            @test endpoint.plus_mask_event===:unchanged && endpoint.minus_mask_event===:unchanged
            @test endpoint.complete_cut_signature_match
        end
    end
    for report in cut_fd_reports
        @test isapprox(report.fd,report.analytic;rtol=5e-6,atol=5e-11)
    end
    @test size(lcfs_current.jacobian)==(64,length(component.initial_state))
    @test lcfs_current.integrated_current_scope===:derived_budget_from_the_same_64_pointwise_Jn_rows
    @test !lcfs_current.integrated_current_is_independent_constraint
    @test isapprox(lcfs_current.integrated_current_A,
        sum(w*j for (w,j) in zip(lcfs_current.dynamic_geometry.surface_quadrature_m2,
            lcfs_current.Jn_A_per_m2));rtol=16eps(Float64),atol=0.0)
    @test lcfs_current.current_law===:axisymmetric_cylindrical_curl_of_profile_F_plus_exact_masked_regional_F_residual
    @test lcfs_current.normal_current_diagnostic.field_semantics===
        :one_sided_inside_profile_F_plus_Q1_exact_masked_regional_F_residual__exterior_trace_not_evaluated
    current_geometry_scores=[sum(abs2,view(lcfs_current.dynamic_geometry.coordinate_jacobian,:,k))+
        sum(abs2,view(lcfs_current.dynamic_geometry.normal_jacobian,:,k))
        for k in 1:size(lcfs_current.dynamic_geometry.coordinate_jacobian,2)]
    current_bphi_scores=[sum(abs2,lcfs_current.jacobian[:,4k-2]) for k in 1:prod(component.grid_shape)]
    current_probe_bphi_column=4argmax(current_bphi_scores)-2
    current_probe_span=abs(component.profile_law.psi_axis_wb_per_rad-
        component.profile_law.psi_boundary_wb_per_rad)
    # A Jacobian comparison must stay on the mask branch for which it is defined.
    # Select by actual geometric sensitivity only among columns whose linearized
    # native psi-boundary margins exceed both centered steps by a factor of eight.
    # This is a perturbation-domain check, not a relaxed residual/FD criterion.
    geometry=lcfs_current.dynamic_geometry
    margins=abs.(geometry.candidate_total_psi_Wb_per_rad.-geometry.psi_boundary_Wb_per_rad)
    current_probe_native=0;current_probe_psi_step=0.0
    for native in sortperm(current_geometry_scores;rev=true)
        current_geometry_scores[native]>0.0 || break
        # r3's h/h2 probes showed O(h^2) truncation in this sensitive geometry
        # column. Reduce the perturbation, retaining the same two-step and FD
        # accuracy gate; the F-node reconstruction removes vacuum cancellation.
        step=(1e-4/128)*max(current_probe_span,abs(component.initial_state[4native]))
        boundary_tangent=geometry.boundary_flux_jacobian[native]
        safe=all(i->begin
            tangent=(i==native ? 1.0 : 0.0)-boundary_tangent
            iszero(tangent) || 8step*abs(tangent)<margins[i]
        end,eachindex(margins))
        if safe
            current_probe_native=native;current_probe_psi_step=step;break
        end
    end
    current_probe_native>0 || error("no moving-LCFS psi column supports the unchanged-mask FD steps")
    current_probe_psi_column=4current_probe_native
    println("CURRENT_NORMAL_GEOMETRY_DIAGNOSTIC="*
        F.canonical_json(lcfs_current.normal_current_diagnostic));flush(stdout)
    println("CURRENT_TOPOLOGY_BASELINE="*F.canonical_json((
        trace=:canonical_profile_plus_Q1_legacy_diagnostic_not_global_rows,
        canonical_profile_diagnostic_Jn_max_abs_A_per_m2=maximum(abs,lcfs_current.Jn_A_per_m2),
        canonical_profile_diagnostic_integrated_current_A=lcfs_current.integrated_current_A,
        registered_global_conservation_ids=Tuple(provider.conservation_ids),
        selected_psi_native_id=current_probe_native,selected_psi_step=current_probe_psi_step,
        physical_acceptance=:not_established)));flush(stdout)
    if reuse_local_fd_mode
        println("CURRENT_TOPOLOGY_SELECTED_FD_REUSE="*F.canonical_json((
            status=:reused_prequalified_R9_local_current_FD,
            reference_run="up2_actual_periodic_current_rows_short_20261010_r9",
            reference_stdout_sha256="1834994727bd066db1f4851fc7fadca86801ba5c23081aaa39d275e2c3a7a0fd",
            columns=(32122,35196),steps=(1.0e-4,2.0783672336714679e-7),
            new_fd_or_physical_acceptance_credit=false)))
        fd_reports=NamedTuple[]
    else
    current_jacobian_fd_rtol=5e-6
    current_jacobian_fd_atol=5e-11
    fd_reports=NamedTuple[]
    for (column,base_step) in ((current_probe_bphi_column,
            1e-4*max(abs(component.initial_state[current_probe_bphi_column]),1.0)),
            (current_probe_psi_column,current_probe_psi_step))
        for fd_step in (base_step,base_step/2)
            current_plus=copy(component.initial_state);current_minus=copy(component.initial_state)
            current_plus[column]+=fd_step;current_minus[column]-=fd_step
            plus_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
                provider.lcfs_current_numeric_data,current_plus;with_jacobian=false)
            minus_trace=F._ccp_full_native_dynamic_lcfs_curl_current_trace(
                provider.lcfs_current_numeric_data,current_minus;with_jacobian=false)
            @test plus_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
            @test minus_trace.status===:evaluated_dynamic_LCFS_state_Bphi_curl_current
            @test plus_trace.dynamic_geometry.mask_event===:unchanged
            @test minus_trace.dynamic_geometry.mask_event===:unchanged
            if column==current_probe_psi_column
                @test plus_trace.dynamic_geometry.coordinates_RZ_m!=minus_trace.dynamic_geometry.coordinates_RZ_m
            else
                @test plus_trace.Jn_A_per_m2!=minus_trace.Jn_A_per_m2
            end
            fd_Jn=(plus_trace.residual.-minus_trace.residual)./(2fd_step)
            analytic_Jn=collect(lcfs_current.jacobian[:,column])
            fd_integral=(plus_trace.integrated_current_A-minus_trace.integrated_current_A)/(2fd_step)
            analytic_integral=lcfs_current.integrated_current_jacobian[column]
            @test isapprox(fd_Jn,analytic_Jn;rtol=current_jacobian_fd_rtol,atol=current_jacobian_fd_atol)
            # Keep the integrated diagnostic's original selected-column FD
            # budget explicit; it is still not a separately admitted solver row.
            @test isapprox(fd_integral,analytic_integral;
                rtol=current_jacobian_fd_rtol,atol=current_jacobian_fd_atol)
            push!(fd_reports,(column=column,step=fd_step,
                Jn_relative_defect=F.norm(fd_Jn-analytic_Jn)/max(F.norm(analytic_Jn),eps(Float64)),
                integral_fd=fd_integral,integral_analytic=analytic_integral,
                integral_abs_defect=abs(fd_integral-analytic_integral)))
        end
    end
    end
    actual_global_consumer=if precheck_mode=="current_topology_smoke"
        (status=:evaluated_same_state_actual_global_F_B_consumer,
            Ip_normalization_residual_A=global_value.residual[1],
            Jn_max_abs_A_per_m2=maximum(abs,global_value.residual[2:end]),
            Jn_source=:same_state_actual_F_B_rows,
            conservation_ids=Tuple(provider.conservation_ids),
            added_global_Jn_rows=length(provider.added_global_conservation_ids),
            independent_integral_constraint=false)
    else
        (status=:not_executed_in_this_helper_mode,
            conservation_ids=Tuple(provider.conservation_ids),)
    end
    (registered_global_conservation_ids=Tuple(provider.conservation_ids),
        actual_global_consumer=actual_global_consumer,
        canonical_profile_diagnostic=(trace=:canonical_profile_plus_Q1_legacy_diagnostic_not_global_rows,
            current_law=lcfs_current.current_law,
            Jn_max_abs_A_per_m2=maximum(abs,lcfs_current.Jn_A_per_m2),
            integrated_current_A=lcfs_current.integrated_current_A,
            normal_current_diagnostic_status=lcfs_current.normal_current_diagnostic.status,
            integrated_current_is_independent_constraint=false),
        residual_budget_A_per_m2=:unknown_not_configured,FD=Tuple(fd_reports),
        boundary_law=:J_dot_n_zero,physical_acceptance=:not_established,
        global_closure=false,registered_physical_budget=:not_provided)
end

Base.@noinline Base.@nospecializeinfer function _g2_full_native_diagnostic_bindings_v1(F,freegs_context,component,trace,provider,composed,regional; provider_id="diagnostic/full-native-pressure-H-Ip-row-wiring-v1",construct_initial_model::Bool=true)
    Base.@nospecialize freegs_context component trace provider composed regional
    S=F.InHouseCoupledMHDGlobalSolveV1
    x=component.initial_state
    s=trace.data.current_support
    no_interface=(args...)->error("single-region diagnostic assembly has no interface rows")
    diagnostic_oracle=component.global_solver_jacobian_oracle(regional,composed.outer,provider)
    callbacks=(regional.regional_evaluator,no_interface,composed.outer.global_hagenow_evaluator,
        provider.conservation_evaluator,diagnostic_oracle)
    missing_closures=NamedTuple{S._REQUIRED_CLOSURES}(ntuple(_->nothing,5))
    all(isnothing,values(missing_closures)) || error("diagnostic trial bindings must preserve missing closures")
    function full_native_candidate_scale_contract()
        law=component.profile_law
        source_state=component.initial_state
        D_coordinate=get(component,:state_coordinate_id,:native_Bphi_T_v1)===:native_F_defect_T_m_v1
        physical_source_state=D_coordinate ? component.physical_state_observation(source_state) : source_state
        native_count=prod(component.grid_shape)
        flux_span=component.dynamic_profile_span ?
            abs(source_state[component.profile_span_columns[1]]-
                source_state[component.profile_span_columns[2]]) :
            abs(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)
        field_scale=abs(law.fvac_T_m/law.Raxis_m)
        for node in 1:native_count
            field_scale=max(field_scale,abs(physical_source_state[4node-3]),
                abs(physical_source_state[4node-2]),abs(physical_source_state[4node-1]))
        end
        f_scale=abs(law.fvac_T_m)
        declared_profile=F._freegs_context_binding(freegs_context).declaration.profile
        p_scale=abs(declared_profile.axis_pressure_pa)
        ip_scale=abs(declared_profile.plasma_current_a)
        characteristics=(flux_span_Wb_per_rad=flux_span,magnetic_field_T=field_scale,
            profile_F_T_m=f_scale,pressure_Pa=p_scale,plasma_current_A=ip_scale)
        all(v->isfinite(v)&&v>0.0,values(characteristics)) ||
            error("candidate characteristic scale is nonpositive or nonfinite")
        component.dynamic_profile_span &&
            Tuple(component.row_units[1:7])!=("T m","Pa","T","T","Pa","Wb/rad","Wb/rad") &&
            error("full-native row-unit inventory differs from scale contract")
        column_scales=ones(Float64,length(source_state))
        for node in 1:native_count
            column_scales[4node-3:4node-1].=field_scale
            # y_D [T m] carries the same numerical magnetic characteristic
            # as the former Bphi [T] column under dD=R*dBphi.
            D_coordinate && (column_scales[4node-2]=
                component.toroidal_coordinate_metric_R_m[node]*field_scale)
            column_scales[4node]=flux_span
        end
        for dof in component.pressure_dofs
            dof>0 && (column_scales[dof]=p_scale)
        end
        for dof in component.profile_coefficient_columns
            column_scales[dof]=max(abs(source_state[dof]),sqrt(eps(Float64)))
        end
        if component.dynamic_profile_span
            column_scales[collect(component.profile_span_columns)].=flux_span
        end
        all(v->isfinite(v)&&v>0.0,column_scales) ||
            error("candidate state-column characteristics are nonpositive or nonfinite")
        span_ids=Set(component.dynamic_span_equation_ids)
        row_units=String[];row_scales=Float64[]
        sizehint!(row_units,length(regional.equation_ids));sizehint!(row_scales,length(regional.equation_ids))
        for id in regional.equation_ids
            if startswith(id,"$(regional.region_id):profile_F:")
                push!(row_units,"T m");push!(row_scales,f_scale)
            elseif startswith(id,"$(regional.region_id):profile_pressure:")
                push!(row_units,"Pa");push!(row_scales,p_scale)
            elseif startswith(id,"$(regional.region_id):plasma_spline_Br:") ||
                    startswith(id,"$(regional.region_id):plasma_spline_Bz:")
                push!(row_units,"T");push!(row_scales,field_scale)
            elseif startswith(id,"$(regional.region_id):GS4:")
                push!(row_units,"T");push!(row_scales,field_scale)
            elseif id=="profile_axis_pressure_normalization"
                push!(row_units,"Pa");push!(row_scales,p_scale)
            elseif id in span_ids
                push!(row_units,"Wb/rad");push!(row_scales,flux_span)
            else
                error("no candidate characteristic mapping for regional equation ID $id")
            end
        end
        current_density_scale=nothing
        if any(==("A m^-2"),provider.conservation_row_units)
            Rgrid=Float64.(collect(s.R_m));Zgrid=Float64.(collect(s.Z_m))
            current_length_scale=min(minimum(abs.(diff(Rgrid))),minimum(abs.(diff(Zgrid))))
            isfinite(current_length_scale) && current_length_scale>0.0 ||
                error("native grid current-density length scale is nonpositive or nonfinite")
            # B/(mu0*L) is a source-derived numerical characteristic for Jn
            # row scaling, not a physics tolerance, current budget or authority.
            current_density_scale=field_scale/(law.mu0_N_per_A2*current_length_scale)
            isfinite(current_density_scale) && current_density_scale>0.0 ||
                error("source-derived Jn row characteristic is nonpositive or nonfinite")
        end
        conservation_units=Tuple(provider.conservation_row_units)
        length(conservation_units)==length(provider.conservation_ids) ||
            error("current conservation ID/unit inventory differs")
        conservation_scales=Float64[]
        for (id,unit) in zip(provider.conservation_ids,conservation_units)
            if id=="profile_Romberg_toroidal_current_normalization" && unit=="A"
                push!(conservation_scales,ip_scale)
            elseif startswith(id,"current_topology:LCFS_Jn:") && unit=="A m^-2" &&
                    current_density_scale!==nothing
                push!(conservation_scales,current_density_scale)
            else
                error("no candidate characteristic mapping for current conservation ID/unit $id / $unit")
            end
        end
        outer_units=hasproperty(composed.outer,:row_units) ?
            Tuple(composed.outer.row_units) : ntuple(_->"Wb/rad",length(composed.outer.constraint_ids))
        outer_scales=hasproperty(composed.outer,:row_characteristics) ?
            Tuple(Float64.(collect(composed.outer.row_characteristics))) :
            ntuple(_->flux_span,length(composed.outer.constraint_ids))
        length(outer_units)==length(composed.outer.constraint_ids) &&
            length(outer_scales)==length(composed.outer.constraint_ids) ||
            error("outer row units/scales do not match frozen outer constraint IDs")
        equality_ids=(composed.outer.constraint_ids...,provider.conservation_ids...)
        equality_units=(outer_units...,conservation_units...)
        equality_scales=(outer_scales...,conservation_scales...)
        scale_rule="F=abs(Fvac); pressure=abs(p_axis); B=max(abs(Fvac/Raxis),native Br/Bphi/Bz); flux=abs(psi_axis-psi_boundary); equality H/Ip use flux/current"
        characteristics=(flux_span_Wb_per_rad=flux_span,magnetic_field_T=field_scale,
            profile_F_T_m=f_scale,pressure_Pa=p_scale,plasma_current_A=ip_scale)
        if current_density_scale!==nothing
            scale_rule*= "; LCFS Jn numerical characteristic=B/(mu0*minimum_native_grid_spacing)"
            characteristics=merge(characteristics,(current_density_A_per_m2=current_density_scale,))
        end
        provenance=(schema="full-native-candidate-characteristic-scale-v1",
            state_coordinate_id=get(component,:state_coordinate_id,:native_Bphi_T_v1),
            toroidal_column_rule=D_coordinate ? :R_times_physical_magnetic_field_T : :physical_magnetic_field_T,
            rule=scale_rule,
            column_rule=D_coordinate ?
                "native Br/Bz use magnetic_field_T; D uses R_m*magnetic_field_T; native psi and dynamic endpoints use flux_span_Wb_per_rad; pressure DOFs use pressure_Pa; profile coefficients use max(abs(candidate value),sqrt(eps))" :
                "native Br/Bphi/Bz use magnetic_field_T; native psi and dynamic endpoints use flux_span_Wb_per_rad; pressure DOFs use pressure_Pa; profile coefficients use max(abs(candidate value),sqrt(eps))",
            column_scale_hash=string(F.canonical_hash(Tuple(column_scales))),
            scale_role=:numerical_preconditioning_only,calibrated_physical_merit=false,
            physical_validation=false,regional_rows=length(row_units),equality_rows=length(equality_ids),
            characteristics)
        contract=S.candidate_kkt_scale_contract_v1(candidate_hash=component.candidate_hash,
            source_hashes=(candidate_hash=component.candidate_hash,
                component_context_hash=component.context_hash,
                upstream_output_hash=trace.data.upstream_output_hash,
                trace_hash=trace.trace_hash),
            equilibrium_row_ids=regional.equation_ids,equilibrium_row_units=row_units,
            equilibrium_characteristics=row_scales,equality_row_ids=equality_ids,
            equality_row_units=equality_units,equality_characteristics=equality_scales,
            provenance=provenance)
        (contract=contract,column_scales=Tuple(column_scales))
    end
    candidate_scaling=full_native_candidate_scale_contract()
    scale_contract=candidate_scaling.contract
    function make_diagnostic_model(callback_set,model_provider_id=provider_id)
        provider_hash=S.coupled_mhd_provider_context_hash_v1(callback_set...)
        S.make_global_model_v1(candidate_hash=component.candidate_hash,
            single_region=true,region_ids=(regional.region_id,),region_dofs=(length(x),),
            pressure_indices=Tuple(i for i in component.pressure_dofs if i>0),
            regional_equation_ids=(regional.equation_ids,),interface_edges=(),
            local_dof_to_global=(Tuple(1:length(x)),),
            local_test_row_to_global=(Tuple(1:length(regional.equation_ids)),),
            pressure_indices_global=true,outer_constraint_ids=(composed.outer.constraint_ids,),
            global_conservation_ids=provider.conservation_ids,closure_evidence=missing_closures,
            provider_id=model_provider_id,provider_source_path=@__FILE__,
            provider_context_hash=provider_hash,regional_evaluator=callback_set[1],
            interface_evaluator=callback_set[2],outer_evaluator=callback_set[3],
            conservation_evaluator=callback_set[4],jacobian_oracle=callback_set[5],
            equilibrium_row_scales=scale_contract.equilibrium.characteristics,
            scale_contract=scale_contract)
    end
    model=construct_initial_model ? make_diagnostic_model(callbacks,provider_id) : nothing
    (model=model,model_constructor=make_diagnostic_model,callbacks=callbacks,diagnostic_oracle=diagnostic_oracle,
        region=regional,interface_callback=no_interface,outer_callback=composed.outer.global_hagenow_evaluator,
        conservation_callback=provider.conservation_evaluator,
        scale_contract=scale_contract,column_scales=candidate_scaling.column_scales,
        regional_row_ids=Tuple(regional.equation_ids),
        equality_row_ids=Tuple(scale_contract.equalities.row_ids),
        equality_row_scales=Tuple(scale_contract.equalities.characteristics),
        missing_closures=missing_closures)
end

function _g2_test_full_native_default_guard_short_v1(F,freegs_context,artifacts,component,trace,outer)
    S=F.InHouseCoupledMHDGlobalSolveV1
    payload=F.freegs_axisymmetric_toroidal_loop_payload(freegs_context,artifacts,trace)
    payload.status===:present || error("default-guard short test requires the actual current payload")
    provider=component.current_conservation_callbacks(payload)
    provider.status===:prepared_conservation_evaluator ||
        error("default-guard short test requires the actual conservation provider")
    outer.status===:prepared_outer_evaluator ||
        error("default-guard short test requires the actual outer provider")
    composed=component.current_outer_partition(provider,outer)
    composed.status===:prepared_current_outer_partition ||
        error("default-guard short test requires the actual current/outer partition")
    regional=component.regional_callbacks(composed;region_id="freegs_g2_full_native")
    regional.status===:prepared_regional_evaluator ||
        error("default-guard short test requires the actual regional callback")
    bindings=_g2_full_native_diagnostic_bindings_v1(F,freegs_context,component,trace,
        provider,composed,regional;construct_initial_model=false)
    actual_oracle_flag=get(ENV,"FUSION_G2_PRECHECK_ACTUAL_ORACLE_SHORT","0")
    actual_oracle_flag in ("0","1") ||
        error("FUSION_G2_PRECHECK_ACTUAL_ORACLE_SHORT must be 0 or 1")
    if actual_oracle_flag=="1"
        # This opt-in keeps the measured factory-guard prefix and asks the live
        # production regional oracle to validate the R4 same-state saved J.
        # It does not evaluate the baseline, assemble the global system, or
        # create closure evidence/authority.
        saved_path=get(ENV,"FUSION_G2_PRECHECK_ACTUAL_ORACLE_NUMERIC_PATH","")
        saved_sha=get(ENV,"FUSION_G2_PRECHECK_ACTUAL_ORACLE_NUMERIC_SHA256","")
        !isempty(saved_path) && occursin(r"^[0-9a-f]{64}$",saved_sha) ||
            error("actual-oracle short requires the pinned R4 checkpoint path and SHA-256")
        saved=_g2_global_diag_reload_matrices(saved_path;expected_sha256=saved_sha)
        meta=saved.replay_metadata
        meta.validation_stage===:pre_global_assembler_oracles_pending ||
            error("actual-oracle short requires the R4 pre-oracle checkpoint")
        meta.consumer_identity.scope===:diagnostic_incomplete_global_assembly ||
            error("actual-oracle short input is outside the diagnostic incomplete-assembly scope")
        actual_model=bindings.model_constructor(bindings.callbacks)
        ci=meta.consumer_identity
        live_identity=(candidate_hash=actual_model.candidate_hash,
            provider_id=actual_model.provider_id,model_hash=actual_model.model_hash,
            component_context_hash=component.context_hash,trace_hash=trace.trace_hash,
            current_operator_model_id=component.current_operator_model_id,
            hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
            scale_contract_hash=bindings.scale_contract.contract_hash,
            scale_policy=:candidate_characteristic_numerical_preconditioning)
        identity_matches=NamedTuple{keys(live_identity)}(map(keys(live_identity)) do key
            hasproperty(ci,key) && getproperty(ci,key)==getproperty(live_identity,key)
        end)
        identity_mismatches=Tuple(key for key in keys(identity_matches) if !getproperty(identity_matches,key))
        println("G2_ACTUAL_ORACLE_IDENTITY_JSON="*F.canonical_json((
            matches=identity_matches,mismatches=identity_mismatches,
            saved=ci,actual=live_identity)));flush(stdout)
        all(==(:model_hash),identity_mismatches) ||
            error("R4 checkpoint binding differs at: "*join(string.(identity_mismatches),", "))
        length(saved.state)==length(component.initial_state)==69_447 ||
            error("R4 checkpoint state dimensions differ from the selected full-native component")
        size(saved.jacobian)==(length(regional.equation_ids),length(saved.state)) ||
            error("R4 regional Jacobian dimensions differ from the actual regional callback")
        Tuple(meta.ordered_ids.least_squares_raw)==Tuple(regional.equation_ids) ||
            error("R4 regional equation ID/order differs from the actual callback")
        Tuple(saved.column_scales)==Tuple(bindings.column_scales) &&
            Tuple(saved.least_squares_row_scales)==actual_model.equilibrium_row_scales &&
            meta.data_identity.jacobian_dimensions==size(saved.jacobian) &&
            meta.data_identity.jacobian_nnz==SparseArrays.nnz(saved.jacobian) &&
            meta.data_identity.residual_length==length(saved.residual) ||
            error("R4 checkpoint scale or matrix identity differs from the actual model")
        all(isnothing,values(actual_model.closure_evidence)) ||
            error("actual regional oracle short must retain absent closure evidence")
        required_meta=(:schema,:ordered_ids,:least_squares_row_indices,
            :equality_base_row_indices,:endpoint_row_indices,:equality_endpoint_positions,
            :pressure_indices,:consumer_identity,:validation_stage,:data_identity)
        all(k->hasproperty(meta,k),required_meta) ||
            error("R4 replay metadata lacks a required preflight field")
        expected_endpoint_rows=Tuple(component.dynamic_span_row_range)
        expected_ls_rows=Tuple(i for i in 1:68_934 if !(i in expected_endpoint_rows))
        integer_map(v)=all(i->i isa Integer && !(i isa Bool),v)
        preflight=(metadata_schema=meta.schema=="g2-global-diagnostic-replay-metadata-v1",
            J_dimensions=size(saved.jacobian)==(68_934,69_447),
            C_dimensions=size(saved.equality_jacobian)==(577,69_447),
            six_vector_lengths=map(length,(saved.residual,saved.equality_residual,
                saved.state,saved.column_scales,saved.least_squares_row_scales,
                saved.equality_row_scales))==(68_934,577,69_447,69_447,68_934,577),
            positive_finite_scales=all(v->all(z->isfinite(z)&&z>0,v),
                (saved.column_scales,saved.least_squares_row_scales,saved.equality_row_scales)),
            equality_ID_order=Tuple(meta.ordered_ids.equality_base)==Tuple(bindings.equality_row_ids),
            equality_scale_order=Tuple(saved.equality_row_scales)==Tuple(bindings.equality_row_scales),
            C_recorded_dimensions=meta.data_identity.equality_jacobian_dimensions==size(saved.equality_jacobian),
            C_recorded_nnz=meta.data_identity.equality_jacobian_nnz==SparseArrays.nnz(saved.equality_jacobian),
            c_recorded_length=meta.data_identity.equality_residual_length==length(saved.equality_residual),
            integer_row_and_DOF_maps=all(integer_map,(meta.least_squares_row_indices,
                meta.equality_base_row_indices,meta.endpoint_row_indices,
                meta.equality_endpoint_positions,meta.pressure_indices)),
            endpoint_rows=Tuple(meta.endpoint_row_indices)==expected_endpoint_rows,
            endpoint_IDs=Tuple(meta.ordered_ids.endpoint)==Tuple(component.dynamic_span_equation_ids),
            LS_row_order=Tuple(meta.least_squares_row_indices)==expected_ls_rows,
            equality_base_positions=Tuple(meta.equality_base_row_indices)==Tuple(1:577),
            equality_endpoint_positions=Tuple(meta.equality_endpoint_positions)==(578,579),
            pressure_DOF_order=Tuple(meta.pressure_indices)==Tuple(i for i in component.pressure_dofs if i>0))
        println("G2_ACTUAL_ORACLE_PREFLIGHT_JSON="*F.canonical_json(preflight));flush(stdout)
        all(values(preflight)) || error("R4 complete numerical binding preflight failed")
        started=time_ns()
        # A cross-process diagnostic may have a different callback identity after
        # a lifecycle-only source edit. Keep that identity as provenance and
        # require exact complete live R/J equality before reusing the saved data.
        # This does not change same-run model validation or closure authority.
        live_context=S._provider_context(actual_model)
        live_record=actual_model.regional_evaluator(regional.region_id,saved.state,
            actual_model.closure_evidence,live_context)
        S._check_provider_record(live_record,actual_model,Tuple(regional.equation_ids),
            regional.region_id,"live R4 diagnostic numeric binding",:equation_ids)
        live_block=S._checked_block(live_record,length(regional.equation_ids),
            length(saved.state),"live R4 diagnostic numeric binding")
        numeric_residual_defect=maximum(abs(live_block.residual[k]-saved.residual[k])
            for k in eachindex(saved.residual))
        numeric_jacobian_defect=S._sparse_max_abs_difference(live_block.jacobian,saved.jacobian)
        numeric_binding=(status=:checked_complete_same_state_RJ,
            saved_model_hash=ci.model_hash,live_model_hash=actual_model.model_hash,
            callback_identity_changed=ci.model_hash!=actual_model.model_hash,
            residual_max_abs_defect=numeric_residual_defect,
            jacobian_max_abs_defect=numeric_jacobian_defect,
            residual_exact=live_block.residual==saved.residual,
            jacobian_exact=numeric_jacobian_defect==0.0,
            state_dofs=length(saved.state),regional_rows=length(regional.equation_ids),
            checkpoint_sha256=saved_sha)
        println("G2_ACTUAL_ORACLE_NUMERIC_BINDING_JSON="*F.canonical_json(numeric_binding));flush(stdout)
        numeric_binding.residual_exact && numeric_binding.jacobian_exact ||
            error("R4 checkpoint no longer represents the complete live regional numerical problem")
        live_record=nothing;live_block=nothing;GC.gc(true)
        regional_oracle_check=S._check_jacobian_oracle(actual_model,:regional,
            regional.region_id,saved.state,Tuple(regional.equation_ids),:equation_ids,
            saved.jacobian,"regional $(regional.region_id) against R4 checkpoint";
            provider_context=live_context)
        @test regional_oracle_check.passed
        actual_oracle_report=(status=:passed_actual_regional_oracle_against_R4_saved_J,
            scope=:same_state_regional_oracle_only,
            state_dofs=length(saved.state),regional_rows=length(regional.equation_ids),
            saved_J_dimensions=size(saved.jacobian),saved_J_nnz=SparseArrays.nnz(saved.jacobian),
            oracle_max_abs_defect=regional_oracle_check.max_abs_defect,
            oracle_roundoff_tolerance=regional_oracle_check.roundoff_tolerance,
            numeric_binding=numeric_binding,
            elapsed_seconds=(time_ns()-started)/1e9,
            checkpoint_path=abspath(saved_path),checkpoint_sha256=saved_sha,
            closure_evidence_all_nothing=true,global_assembly=:not_run,
            physical_validation=false,promotion_authority=false)
        println("G2_ACTUAL_REGIONAL_ORACLE_SHORT_JSON="*F.canonical_json(actual_oracle_report));flush(stdout)
        saved=nothing;actual_model=nothing;GC.gc(true)
    end
    guarded_callbacks=((args...)->error("default/solve closure gate invoked the regional callback"),
        bindings.callbacks[2:end]...)
    guarded_model=bindings.model_constructor(guarded_callbacks,
        "diagnostic/full-native-default-gate-v1")
    missing_default=S.assemble_coupled_mhd_global_v1(guarded_model,component.initial_state)
    @test missing_default.status===:typed_absent
    @test missing_default.missing_closures==S._REQUIRED_CLOSURES
    @test keys(missing_default)==(:status,:missing_closures,:candidate_hash,:model_hash,
        :capability_signature,:physical_authority)
    @test !hasproperty(missing_default,:diagnostic_assembly) && !hasproperty(missing_default,:residual)
    @test all(isnothing,values(guarded_model.closure_evidence))
    policy=S.make_global_policy_v1(acceptance_ref="full_native_missing_closure_gate_test_v1",
        contract_source_path=@__FILE__,max_updates=1,wall_seconds=1.0,
        residual_tolerance=1e-6,constraint_tolerance=1e-6,stationarity_tolerance=1e-6,
        bound_dual_tolerance=1e-6,complementarity_tolerance=1e-6,step_tolerance=1e-8,
        minimum_step=1e-6,armijo_fraction=1e-4,max_backtracks=2,
        max_active_set_iterations=8,stagnation_window=1)
    solved=S.solve_coupled_mhd_global_v1(guarded_model,component.initial_state,policy)
    @test solved.status===:typed_absent
    @test solved.updates==0 && isempty(solved.raw_trace)
    @test !solved.physical_validation && !solved.promotion_authority
    result=(status=:passed_default_guard_short,
        scope=:actual_current_and_outer_bindings_factory_and_default_closure_rejection_only,
        state_dofs=length(component.initial_state),regional_rows=length(regional.equation_ids),
        current_rows=length(provider.conservation_ids),outer_rows=length(composed.outer.constraint_ids),
        scale_contract_hash=bindings.scale_contract.contract_hash,
        model_hash=guarded_model.model_hash,assembly_status=missing_default.status,
        solve_status=solved.status,numeric_global_assembly=:not_run,physical_validation=false,
        promotion_authority=false)
    println("G2_DEFAULT_GUARD_SHORT_RESULT="*F.canonical_json(result));flush(stdout)
    result
end

Base.@noinline Base.@nospecializeinfer function _test_actual_native_current_conservation(F,freegs_context,artifacts,component,trace,base,outer,native_field_optin;baseline_release_ref=nothing)
    Base.@nospecialize freegs_context artifacts component trace base outer
    if baseline_release_ref !== nothing
        base=baseline_release_ref[]
    end
    base isa NamedTuple && hasproperty(base,:jacobian) || error("baseline regional value is missing")
    precheck_mode=get(ENV,"FUSION_G2_PRECHECK_MODE","")
    diagnostic_timing=precheck_mode in ("global_diagnostic","global_model_short",
        "global_first_assembly_short")
    short_model_mode=precheck_mode in ("global_model_short","global_first_assembly_short")

    stop_after_first_global_assembly_flag=get(ENV,
        "FUSION_G2_PRECHECK_STOP_AFTER_FIRST_GLOBAL_ASSEMBLY","0")
    stop_after_first_global_assembly_flag in ("0","1") ||
        error("FUSION_G2_PRECHECK_STOP_AFTER_FIRST_GLOBAL_ASSEMBLY must be 0 or 1")
    stop_after_first_global_assembly=stop_after_first_global_assembly_flag=="1"
    precheck_mode=="global_first_assembly_short" && !stop_after_first_global_assembly &&
        error("global_first_assembly_short requires FUSION_G2_PRECHECK_STOP_AFTER_FIRST_GLOBAL_ASSEMBLY=1")
    stop_after_first_global_assembly && !(precheck_mode in
        ("global_diagnostic","global_first_assembly_short")) &&
        error("early global-assembly stop requires a global assembly diagnostic mode")
    diagnostic_phase(label,f)=diagnostic_timing ? g2_precheck_timed(label,f) : f()
    dynamic_span_mode=get(ENV,"FUSION_FREEGS_DYNAMIC_PROFILE_SPAN","0")=="1"
    stop_after_gs_u_fd_flag=get(ENV,"FUSION_G2_PRECHECK_STOP_AFTER_GS_U_FD","0")
    stop_after_gs_u_fd_flag in ("0","1") ||
        error("FUSION_G2_PRECHECK_STOP_AFTER_GS_U_FD must be 0 or 1")
    stop_after_gs_u_fd=stop_after_gs_u_fd_flag=="1"
    stop_after_gs_u_fd_plus_flag=get(ENV,"FUSION_G2_PRECHECK_STOP_AFTER_GS_U_FD_PLUS_RESOURCE_SHORT","0")
    stop_after_gs_u_fd_plus_flag in ("0","1") ||
        error("FUSION_G2_PRECHECK_STOP_AFTER_GS_U_FD_PLUS_RESOURCE_SHORT must be 0 or 1")
    stop_after_gs_u_fd_plus=stop_after_gs_u_fd_plus_flag=="1"
    resume_saved_gs_u_plus=get(ENV,"FUSION_G2_RESUME_SAVED_GS_U_PLUS","0")=="1"
    resume_saved_trial_next_kkt=get(ENV,"FUSION_G2_RESUME_SAVED_TRIAL_NEXT_KKT","0")
    resume_saved_trial_next_kkt in ("0","1") || error("saved next-trial KKT resume flag must be 0 or 1")
    resume_saved_trial_next_kkt=="1" && !resume_saved_gs_u_plus && error("saved next-trial KKT resume requires the existing saved-resume route")
    resume_saved_gs_u_plus && (precheck_mode!="global_diagnostic" || !native_field_optin || !dynamic_span_mode ||
        stop_after_gs_u_fd || stop_after_first_global_assembly || stop_after_gs_u_fd_plus) && error("saved-plus resume requires global diagnostic native dynamic-span mode")
    stop_after_gs_u_fd_plus && (precheck_mode!="global_diagnostic" || !native_field_optin ||
        !dynamic_span_mode || stop_after_gs_u_fd || stop_after_first_global_assembly) &&
        error("GS-u plus resource short requires global diagnostic, native field, dynamic span, and the original full baseline assembly")
    stop_after_gs_u_fd && precheck_mode!="global_diagnostic" &&
        error("GS-u FD short return requires FUSION_G2_PRECHECK_MODE=global_diagnostic")
    stop_after_gs_u_fd && !native_field_optin &&
        error("GS-u FD short return requires native field opt-in")
    stop_after_gs_u_fd && !dynamic_span_mode &&
        error("GS-u FD short return requires FUSION_FREEGS_DYNAMIC_PROFILE_SPAN=1")
    stop_after_gs_u_fd && stop_after_first_global_assembly &&
        error("GS-u FD short return cannot combine with the first-assembly stop")
    full_global_spill=precheck_mode=="global_diagnostic" && !stop_after_gs_u_fd && !stop_after_first_global_assembly
    preoracle_numeric_checkpoint=get(ENV,"FUSION_G2_PRECHECK_PREORACLE_NUMERIC_CHECKPOINT","0")=="1"
    preoracle_numeric_checkpoint && (precheck_mode!="global_diagnostic" || !native_field_optin || !dynamic_span_mode) &&
        error("pre-oracle numeric checkpoint requires global_diagnostic, native-field opt-in, and dynamic span")
    numeric_replay_capture=full_global_spill || (precheck_mode=="global_diagnostic" && stop_after_first_global_assembly) ||
        preoracle_numeric_checkpoint
    numeric_result_run_leaf=if numeric_replay_capture
        value=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
        !isempty(value) && isdir(value) || error("numeric KKT replay capture requires an existing bounded run-leaf FUSION_G2_PRECHECK_RESULT_DATA_DIR")
        value
    else
        nothing
    end
    expected_region_rows=68_932+(dynamic_span_mode ? 2 : 0)
    expected_state_dofs=69_445+(dynamic_span_mode ? 2 : 0)
    @test length(component.initial_state)==expected_state_dofs
    if diagnostic_timing
        println("G2_GLOBAL_DIAGNOSTIC_HELPER_ENTER unix_s=",time())
        flush(stdout)
    end
@testset "Actual source loop map and original Romberg Ip conservation ABI" begin
    d=trace.data;s=d.current_support;nr,nz=component.grid_shape
    # The production factory binds actual signed native current observations.
    payload = if diagnostic_timing
        g2_precheck_timed("global_diagnostic_actual_payload",()->
            F.freegs_axisymmetric_toroidal_loop_payload(freegs_context,artifacts,trace))
    else
        F.freegs_axisymmetric_toroidal_loop_payload(freegs_context,artifacts,trace)
    end
    @test payload.status===:present
    @test payload.candidate_hash==d.candidate_hash==string(freegs_context.candidate_hash)
    @test payload.context_hash==d.context_hash==string(freegs_context.context_hash)
    @test payload.upstream_output_hash==d.upstream_output_hash==string(artifacts.receipt.output_hash)
    @test payload.trace_hash==trace.trace_hash
    @test payload.missing_closures==component.missing_closures
    @test payload.full_J_normal_trace===:typed_absent && payload.exterior_current_closure===:typed_absent
    if !hasproperty(payload,:plasma_current_topology)
        @test payload.return_current_path===:typed_absent
    else
        @test payload.plasma_current_topology.model===:ideal_axisymmetric_periodic_lcfs_no_normal_current
        @test payload.declared_return_current_path===:periodic_toroidal_plasma_with_zero_normal_current_at_LCFS
    end
    @test !payload.global_topology_closed && !payload.closure_evidence_created && !payload.physical_validation
    loops=payload.loops
    @test loops isa Vector
    native_cells=[(i,j) for i in 1:nr for j in 1:nz if s.core_mask[i][j]==1.0]
    @test length(loops)==length(native_cells)==2879
    @test all(loop.R_m==s.R_m[i] && loop.Z_m==s.Z_m[j] for (loop,(i,j)) in zip(loops,native_cells))
    @test all(loop.Jphi_A_per_m2==s.Jphi_A_per_m2[i][j] for (loop,(i,j)) in zip(loops,native_cells))
    @test all(loop.area_weight_m2==s.area_weight_m2[i][j] for (loop,(i,j)) in zip(loops,native_cells))
    @test all(loop.current_A==s.ring_current_A[i][j] &&
        isapprox(loop.current_A,Float64(s.Jphi_A_per_m2[i][j])*Float64(s.area_weight_m2[i][j]);
            rtol=16eps(Float64),atol=0.0) for (loop,(i,j)) in zip(loops,native_cells))
    @test all(loop.phi_start_rad==0.0 && loop.phi_stop_rad==2pi && loop.core_mask==1.0 for loop in loops)
    @test payload.current_integral_A==sum(loop.current_A for loop in loops)
    @test payload.solver_plasma_current_A==s.solver_plasma_current_A
    @test payload.current_component===:signed_toroidal_Jphi_A_per_m2
    @test payload.independent_return_conductor===:not_claimed && payload.multi_region_G2_dof_map===:not_provided
    foreign_source_trace=F.FreeGSAxisymmetricLCFSTraceV4(F._CCP_LCFS_TRACE_TOKEN,
        d,repeat("0",64),trace.trace_hash)
    @test_throws ArgumentError F.freegs_axisymmetric_toroidal_loop_payload(freegs_context,artifacts,foreign_source_trace)
    provider = if diagnostic_timing
        g2_precheck_timed("global_diagnostic_conservation_provider",()->
            component.current_conservation_callbacks(payload))
    else
        component.current_conservation_callbacks(payload)
    end
    @test provider.status===:prepared_conservation_evaluator
    reuse_local_fd_mode=g2_precheck_reuse_qualified_local_fd(precheck_mode,component,provider)
    test_actual_lcfs_curl_current_rows(F,component,payload,provider,trace)
    @test provider.native_ids==findall(component.core_mask)
    @test length(provider.native_ids)==2879
    @test all(k->k in provider.native_ids,(8539,8668,8669,8797))
    @test provider.psi_dofs==4 .* provider.native_ids
    @test provider.coefficient_columns==component.profile_coefficient_columns
    if provider.current_topology===nothing
        @test provider.conservation_ids==("profile_Romberg_toroidal_current_normalization",)
        @test provider.conservation_row_units==("A",)
    else
        @test length(provider.conservation_ids)==65
        @test first(provider.conservation_ids)=="profile_Romberg_toroidal_current_normalization"
        @test Tuple(provider.conservation_ids[2:end])==provider.added_global_conservation_ids
        @test provider.conservation_row_units==("A",ntuple(_->"A m^-2",64)...)
    end
    @test provider.conservation_row_indices==(last(component.normalization_row_range):last(component.normalization_row_range))
    @test provider.outer_row_indices==component.hagenow_boundary_row_range
    ownership=vcat(collect(provider.regional_row_indices),collect(provider.conservation_row_indices),
        collect(provider.outer_row_indices))
    @test ownership==collect(eachindex(base.residual)) && allunique(ownership)
    if outer.status===:prepared_outer_evaluator
        composed = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_current_outer_partition",()->
                component.current_outer_partition(provider,outer))
        else
            component.current_outer_partition(provider,outer)
        end
        @test composed.status===:prepared_current_outer_partition
        @test composed.conservation===provider
        @test composed.outer.outer_evaluator===outer.outer_evaluator
        @test composed.outer.global_hagenow_evaluator isa Function
        @test composed.outer.jacobian_oracle===outer.jacobian_oracle
        @test composed.outer.regional_row_indices==provider.regional_row_indices==composed.partition.regional
        @test composed.outer.conservation_row_indices==provider.conservation_row_indices==composed.partition.conservation
        @test composed.outer.outer_row_indices==provider.outer_row_indices==composed.partition.outer
        @test outer.regional_row_indices==(1:last(provider.conservation_row_indices))
        @test composed.partition.row_count==length(base.residual)
        sliced=composed.regional_slice(base)
        @test sliced.row_indices==provider.regional_row_indices
        @test sliced.residual==base.residual[sliced.row_indices]
        @test size(sliced.jacobian)==(length(sliced.row_indices),length(component.initial_state))
        # Full CSC comparison without a second large prefix/sparse difference.
        whole=base.jacobian;part=sliced.jacobian;matches=true
        for col in 1:size(whole,2)
            cursor=part.colptr[col]
            for p in whole.colptr[col]:(whole.colptr[col+1]-1)
                whole.rowval[p]>last(sliced.row_indices) && break
                if cursor>=part.colptr[col+1] || part.rowval[cursor]!=whole.rowval[p] || part.nzval[cursor]!=whole.nzval[p]
                    matches=false;break
                end
                cursor+=1
            end
            matches &= cursor==part.colptr[col+1]
        end
        @test matches
        @test composed.missing_closures==component.missing_closures
        @test !composed.full_model_constructed && !composed.global_topology_closed && !composed.closure_evidence_created
        @test_throws ArgumentError component.current_outer_partition(provider,merge(outer,(upstream_output_hash=repeat("0",64),)))
        @test_throws ArgumentError component.current_outer_partition(provider,merge(outer,(regional_row_indices=provider.regional_row_indices,)))
        @test_throws ArgumentError component.current_outer_partition(provider,merge(outer,(region_dofs=outer.region_dofs-1,)))
        @test_throws ArgumentError composed.regional_slice(merge(base,(normalization_row_count=1,)))
        @test_throws ArgumentError composed.regional_slice(merge(base,(status=:unsupported_field_evaluation,)))
        @test_throws ArgumentError composed.regional_slice(merge(base,
            (status=:evaluated_full_native_absolute_plasma_spline_exact_PF_field_and_Hagenow_boundary,
             native_field_model_id=:unsupported_field_model)))
        @test_throws ArgumentError composed.regional_slice(merge(base,
            (status=:evaluated_full_native_profile_fixed_PF_flux_and_Hagenow_boundary,
             native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1)))
        @test_throws ArgumentError composed.regional_slice(merge(
            Base.structdiff(base,NamedTuple{(:native_field_model_id,)}),
            (status=:evaluated_full_native_absolute_plasma_spline_exact_PF_field_and_Hagenow_boundary,)))
        sliced=nothing;part=nothing;whole=nothing

        # The new provider must expose the original full-native regional rows,
        # without rescaling or merging the existing Ip/H rows into the region.
        x=component.initial_state
        regional=component.regional_callbacks(composed;region_id="freegs_g2_full_native")
        rid="freegs_g2_full_native"
        @test regional.status===:prepared_regional_evaluator
        if native_field_optin
            @test regional.native_field_model_id===component.native_field_model_id
        else
            @test !hasproperty(regional,:native_field_model_id)
        end
        @test regional.region_dofs==length(x)==expected_state_dofs
        @test regional.regional_row_indices==(1:expected_region_rows)
        @test regional.conservation_row_indices==((expected_region_rows+1):(expected_region_rows+1))
        @test regional.outer_row_indices==((expected_region_rows+2):expected_state_dofs)
        @test regional.partition==composed.partition
        @test regional.row_scaling===:unscaled_original_component_rows
        @test regional.extra_solver_rows==0
        @test regional.missing_closures==component.missing_closures==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
        @test !regional.full_model_constructed && !regional.global_topology_closed &&
            !regional.closure_evidence_created
        @test length(regional.equation_ids)==expected_region_rows && allunique(regional.equation_ids)
        @test all(id->!occursin("strong",lowercase(id)) && !occursin("lcfs",lowercase(id)),
            regional.equation_ids)
        n=prod(component.grid_shape);core_ids=findall(component.core_mask)
        pressure_first=n+1; spline_first=pressure_first+length(core_ids)
        gs_first=spline_first+2n
        @test (n,length(core_ids),2n,length(component.gs_native_ids),regional.partition.row_count)==
            (16_641,2_879,33_282,16_129,expected_state_dofs)
        @test regional.equation_ids[1]=="$(rid):profile_F:node_1"
        @test regional.equation_ids[n]=="$(rid):profile_F:node_$(n)"
        @test regional.equation_ids[pressure_first]=="$(rid):profile_pressure:node_$(first(core_ids))"
        @test regional.equation_ids[spline_first]=="$(rid):plasma_spline_Br:node_1"
        @test regional.equation_ids[spline_first+1]=="$(rid):plasma_spline_Bz:node_1"
        @test regional.equation_ids[spline_first+2]=="$(rid):plasma_spline_Br:node_2"
        @test regional.equation_ids[spline_first+2n-2]=="$(rid):plasma_spline_Br:node_$(n)"
        @test regional.equation_ids[spline_first+2n-1]=="$(rid):plasma_spline_Bz:node_$(n)"
        @test regional.equation_ids[gs_first]=="$(rid):GS4:node_$(first(component.gs_native_ids))"
        if dynamic_span_mode
            @test regional.equation_ids[end-1:end]==["dynamic_profile_axis_flux_definition","dynamic_profile_boundary_flux_definition"]
        else
            @test regional.equation_ids[end]=="profile_axis_pressure_normalization"
        end
        @test length(base.residual)==expected_state_dofs && size(base.jacobian)==(expected_state_dofs,expected_state_dofs)
        @test isempty(intersect(regional.regional_row_indices,regional.conservation_row_indices))
        @test isempty(intersect(regional.regional_row_indices,regional.outer_row_indices))
        @test isempty(intersect(regional.conservation_row_indices,regional.outer_row_indices))
        @test sort(vcat(collect(regional.regional_row_indices),collect(regional.conservation_row_indices),
            collect(regional.outer_row_indices)))==collect(1:expected_state_dofs)

        S=F.InHouseCoupledMHDGlobalSolveV1
        if diagnostic_timing
            regional_identity=g2_precheck_timed("global_diagnostic_regional_callback_identity",()->
                (evaluator=S._callback_identity(regional.regional_evaluator),
                 oracle=S._callback_identity(regional.jacobian_oracle)))
            regional_eid=regional_identity.evaluator
            regional_oid=regional_identity.oracle
        else
            regional_eid=S._callback_identity(regional.regional_evaluator)
            regional_oid=S._callback_identity(regional.jacobian_oracle)
        end
        regional_context=(candidate_hash=component.candidate_hash,
            provider_semantic_hash=string(F.canonical_hash(F.semantic_view(trace))),
            provider_context_hash=string(F.canonical_hash((regional_eid,regional_oid))),
            jacobian_oracle_hash=string(F.canonical_hash(regional_oid)))
        regional_closures=NamedTuple{component.missing_closures}(ntuple(_->nothing,5))
        @test Tuple(keys(regional_closures))==F._CCP_AXISYMMETRIC_MISSING_CLOSURES
        @test all(isnothing,values(regional_closures))
        @test_throws ArgumentError regional.regional_evaluator("foreign_region",x,
            regional_closures,regional_context)
        wrong_candidate=merge(regional_context,(candidate_hash=repeat("0",64),))
        @test_throws ArgumentError regional.regional_evaluator(rid,x,regional_closures,wrong_candidate)
        @test_throws ArgumentError regional.regional_evaluator(rid,x[1:end-1],
            regional_closures,regional_context)
        malformed_context=merge(regional_context,(provider_context_hash="",))
        @test_throws ArgumentError regional.regional_evaluator(rid,x,regional_closures,malformed_context)
        # Invalid schema is rejected. The valid five-key tuple above remains all-nothing;
        # this regional consumer does not invent any closure evidence.
        wrong_closures=NamedTuple{(first(component.missing_closures),)}((nothing,))
        @test_throws ArgumentError regional.regional_evaluator(rid,x,wrong_closures,regional_context)
        @test_throws ArgumentError regional.jacobian_oracle(:outer,rid,x,regional_closures,regional_context)
        @test_throws ArgumentError regional.jacobian_oracle(:regional,"foreign_region",x,
            regional_closures,regional_context)
        @test_throws ArgumentError regional.jacobian_oracle(:regional,rid,x[1:end-1],
            regional_closures,regional_context)
        @test_throws ArgumentError regional.jacobian_oracle(:regional,rid,x,wrong_closures,regional_context)

        validator=(candidate_hash=component.candidate_hash,
            provider_semantic_hash=regional_context.provider_semantic_hash,
            provider_context_hash=regional_context.provider_context_hash)
        expected_ids=Tuple(String.(regional.equation_ids))
        function prefix_error(full,part,nrows)
            size(full,2)==size(part,2) && size(part,1)==nrows || return (Inf,Inf)
            defect=0.0;scale=0.0
            for col in 1:size(full,2)
                i=full.colptr[col];iend=full.colptr[col+1]-1
                j=part.colptr[col];jend=part.colptr[col+1]-1
                while (i<=iend && full.rowval[i]<=nrows) || j<=jend
                    ri=(i<=iend && full.rowval[i]<=nrows) ? full.rowval[i] : typemax(Int)
                    rj=j<=jend ? part.rowval[j] : typemax(Int)
                    row=min(ri,rj)
                    av=ri==row ? full.nzval[i] : 0.0
                    bv=rj==row ? part.nzval[j] : 0.0
                    defect=max(defect,abs(av-bv));scale=max(scale,abs(av),abs(bv))
                    ri==row && (i+=1)
                    rj==row && (j+=1)
                end
                j==jend+1 || return (Inf,scale)
            end
            (defect,scale)
        end

        # Compare the complete raw-value/J slice to the existing full result.
        # CSC walking avoids allocating another 68,932 x 69,445 sparse matrix.
        regional_value = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_regional_callback_value",()->
                regional.regional_evaluator(rid,x,regional_closures,regional_context))
        else
            regional.regional_evaluator(rid,x,regional_closures,regional_context)
        end
        @test S._check_provider_record(regional_value,validator,expected_ids,rid,
            "full-native regional value",:equation_ids)
        @test length(regional_value.residual)==expected_region_rows
        @test all(i->regional_value.residual[i]==base.residual[i],eachindex(regional_value.residual))
        if native_field_optin
            flux_rows=spline_first:(spline_first+2n-1)
            @test regional_value.residual[flux_rows]==base.residual[flux_rows]
            @test component.row_meanings[3]===:all_native_Br_Bz_absolute_plasma_spline_exact_PF_field
            @test component.row_units[3]=="T"
            @test component.native_field_initial_flux_residual_max_abs_T==maximum(abs,base.residual[flux_rows])
            @test hasproperty(base,:native_field_model_id) &&
                base.native_field_model_id===component.native_field_model_id
        end
        regional_initial_residual=copy(regional_value.residual)
        value_defect,value_scale=prefix_error(base.jacobian,regional_value.jacobian,expected_region_rows)
        @test value_defect==0.0
        @test value_scale>=0.0
        @test size(regional_value.jacobian)==(expected_region_rows,expected_state_dofs)
        foreign_context_hash=regional_context.provider_context_hash==repeat("0",64) ? repeat("1",64) : repeat("0",64)
        foreign_record=merge(regional_value,(provider_context_hash=foreign_context_hash,))
        @test_throws ArgumentError S._check_provider_record(foreign_record,validator,expected_ids,rid,
            "foreign full-native regional context",:equation_ids)
        regional_value=nothing;foreign_record=nothing;GC.gc(false)

        # The separately assembled independent Jacobian oracle must reproduce
        # the same original regional entries under the existing full-oracle bound.
        regional_oracle = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_regional_callback_oracle",()->
                regional.jacobian_oracle(:regional,rid,x,regional_closures,regional_context))
        else
            regional.jacobian_oracle(:regional,rid,x,regional_closures,regional_context)
        end
        @test S._check_provider_record(regional_oracle,validator,expected_ids,rid,
            "full-native regional oracle",:equation_ids)
        @test regional_oracle.jacobian_oracle_hash==string(F.canonical_hash(regional_oid))
        oracle_defect,oracle_scale=prefix_error(base.jacobian,regional_oracle.jacobian,expected_region_rows)
        @test oracle_defect<=256eps(Float64)*max(1.0,oracle_scale)
        @test size(regional_oracle.jacobian)==(expected_region_rows,expected_state_dofs)
        if native_field_optin
            # Independently rebuild the spline derivative matrices and verify
            # the absolute field equations at source psi with the exact accepted PF jet.
            raw_output=F.JSON3.read(artifacts.output_json)
            gs_input=F._ccp_native_gs4_input(get(raw_output,:native_gs_state,nothing),trace.data.current_support)
            @test gs_input.status===:present
            Raxis=collect(trace.data.current_support.R_m);Zaxis=collect(trace.data.current_support.Z_m)
            Dr_independent=F._ccp_native_spline_derivative_oracle(Raxis)
            Dz_independent=F._ccp_native_spline_derivative_oracle(Zaxis)
            # The absolute-PF model keeps the accepted total state unchanged;
            # its plasma/PF split is derived from that state, not the old export.
            pf_nodes=[F._ccp_full_native_exact_pf_jet(
                component.lcfs_dynamic_geometry_data,Raxis[i],Zaxis[j])
                for i in 1:nr for j in 1:nz]
            psi_plasma=permutedims(reshape(
                [x[4k]-pf_nodes[k].psi for k in 1:n],nz,nr))
            dpsi_R=Dr_independent*psi_plasma
            dpsi_Z=psi_plasma*transpose(Dz_independent)
            probe_i=cld(nr,2);probe_j=cld(nz,2)
            psi_col=4*((probe_i-1)*nz+probe_j)
            for i in 1:nr,j in 1:nz
                k=(i-1)*nz+j;row=spline_first+2k-2
                pf=pf_nodes[k]
                expected_br=-dpsi_Z[i,j]/Raxis[i]-pf.gradient[2]/Raxis[i]
                expected_bz=dpsi_R[i,j]/Raxis[i]+pf.gradient[1]/Raxis[i]
                @test isapprox(regional_initial_residual[row],x[4k-3]-expected_br;rtol=2e-12,atol=2e-12)
                @test isapprox(regional_initial_residual[row+1],x[4k-1]-expected_bz;rtol=2e-12,atol=2e-12)
                expected_dbr=i==probe_i ? Dz_independent[j,probe_j]/Raxis[i] : 0.0
                expected_dbz=j==probe_j ? -Dr_independent[i,probe_i]/Raxis[i] : 0.0
                @test regional_oracle.jacobian[row,psi_col]==expected_dbr
                @test regional_oracle.jacobian[row+1,psi_col]==expected_dbz
            end
        end
        if dynamic_span_mode
            pressure_core_ids=findall(component.core_mask)
            pressure_rows=collect(component.pressure_rows[pressure_core_ids])
            pressure_dofs=component.pressure_dofs[pressure_core_ids]
            if native_field_optin
                dynamic_current_contract=Base.invokelatest(
                    test_actual_composite_dynamic_profile_current,F,trace,component;
                    reuse_qualified_local_fd=reuse_local_fd_mode)
                pressure_trace=dynamic_current_contract.pressure_trace
                pressure_view=dynamic_current_contract.pressure_view
            else
                pressure_view=component.pressure_domain_view(x)
                pressure_trace=component.lcfs_profile_current_trace(x;
                    pressure_only=true,dynamic_geometry=true,with_jacobian=true)
                @test pressure_view.status===:derived_same_state_dynamic_analytic_pressure_and_constrained_nodal_samples
                @test pressure_trace.status===:evaluated_dynamic_LCFS_pressure_only
                @test pressure_trace.pressure_status===:evaluated_same_state_analytic_profile_pressure
                @test pressure_trace.current_status===:not_evaluated_by_pressure_only_request
                if native_field_optin
                    @test length(pressure_trace.effective_boundary_q)==64
                    @test pressure_trace.effective_boundary_q_source===
                        :same_state_dynamic_geometry_psi_boundary_flux
                else
                    @test !hasproperty(pressure_trace,:effective_boundary_q)
                    @test !hasproperty(pressure_trace,:effective_boundary_q_source)
                    @test pressure_trace.pressure_scope===:continuous_analytic_p_of_dynamic_total_psi
                end
            end
            @test pressure_trace.pressure_row_count==64
            @test length(pressure_trace.pressure_Pa)==64
            @test size(pressure_trace.pressure_jacobian)==(64,length(x))
            @test all(isfinite,pressure_trace.pressure_Pa) && all(isfinite,pressure_trace.pressure_residual)
            @test pressure_trace.pressure_residual==
                pressure_trace.pressure_Pa .- pressure_trace.authored_exterior_pressure_Pa
            baseline_pressure_error=maximum(abs,pressure_trace.pressure_residual;init=0.0)
            baseline_pressure_integral=pressure_trace.pressure_interface_surface_integral_Pa_m2
            @test baseline_pressure_error<=1.0e-8
            @test isfinite(baseline_pressure_integral)
            pressure_endpoint_residual=collect(pressure_trace.endpoint_definition_residual)
            pressure_endpoint_scale=max(1.0,abs(pressure_trace.profile_endpoint_values.axis),
                abs(pressure_trace.profile_endpoint_values.boundary))
            pressure_endpoint_tolerance=64eps(Float64)*pressure_endpoint_scale
            pressure_geometry_map=pressure_view.geometry_map
            expected_pressure_boundary_conforming=
                pressure_trace.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry &&
                pressure_trace.dynamic_geometry.mask_event===:unchanged &&
                pressure_geometry_map.status===:present &&
                pressure_geometry_map.pressure_dof_support_status===:present &&
                maximum(abs,pressure_trace.pressure_residual;init=0.0)<=1.0e-8 &&
                maximum(abs,pressure_endpoint_residual;init=0.0)<=pressure_endpoint_tolerance
            expected_pressure_boundary_status=expected_pressure_boundary_conforming ?
                :derived_conforming_pressure_boundary : :nonconforming
            @test pressure_trace.derived_conforming_pressure_boundary.status===expected_pressure_boundary_status
            @test pressure_trace.derived_conforming_pressure_boundary.physics_scope===:axisymmetric_grad_shafranov_pprime_FFprime
            @test pressure_trace.derived_conforming_pressure_boundary.boundary_law===:lcfs_pressure_equals_authored_exterior_pressure
            @test pressure_trace.pressure_traction_unit===:N
            @test pressure_trace.pressure_traction_global_consumer===:typed_absent
            @test pressure_trace.pressure_force_global_consumer===:global_GS4_pprime_FFprime_rows
            @test size(pressure_trace.pressure_traction_jacobian_N)==(2,length(x))
            @test maximum(abs,pressure_trace.pressure_traction_on_plasma_RZ_N;init=0.0)<=1.0e-10
            @test length(pressure_view.pressure_Pa)==prod(component.grid_shape)
            @test length(pressure_view.profile_pressure_Pa)==prod(component.grid_shape)
            exterior_ids=findall(!,component.core_mask)
            @test all(pressure_view.pressure_Pa[k]==pressure_trace.authored_exterior_pressure_Pa for k in exterior_ids)
            @test all(pressure_view.profile_pressure_Pa[k]==pressure_trace.authored_exterior_pressure_Pa for k in exterior_ids)
            @test pressure_view.pressure_dof_ids==Tuple(pressure_dofs)
            @test pressure_view.pressure_row_ids==Tuple(pressure_rows)
            @test pressure_view.pressure_dof_to_existing_profile_row==Tuple(zip(pressure_dofs,pressure_rows))
            support=pressure_trace.dynamic_region_support
            accepted_core_ids=Tuple(findall(component.core_mask))
            accepted_exterior_ids=Tuple(findall(!,component.core_mask))
            @test pressure_trace.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry
            @test pressure_trace.dynamic_geometry.mask_event===:unchanged
            @test support.native_mask_event===:unchanged
            @test support.plasma_native_node_ids==accepted_core_ids
            @test support.exterior_native_node_ids==accepted_exterior_ids
            ray_count=length(pressure_trace.dynamic_geometry.coordinates_RZ_m)
            @test ray_count==64
            @test pressure_trace.pressure_interface_ray_ids==Tuple(1:64)
            @test pressure_trace.pressure_interface_rule===Symbol("64_ray_first_sampled_outward_psiN_1_bracket")
            @test all(pressure_view.pressure_Pa[k]==x[component.pressure_dofs[k]] for k in pressure_core_ids)
            profile_geometry_psi=pressure_view.dynamic_geometry.candidate_total_psi_Wb_per_rad
            profile_span=pressure_view.profile_endpoint_values
            profile_u=pressure_view.profile_coefficient_values.u
            for k in pressure_core_ids
                q=(profile_geometry_psi[k]-profile_span.boundary)/profile_span.delta
                expected_pressure=profile_u*profile_span.delta*q^3/(3component.profile_law.Raxis_m)
                @test isapprox(pressure_view.profile_pressure_Pa[k],expected_pressure;rtol=2e-13,atol=1e-12)
            end
            @test pressure_view.pressure_row_residual==base.residual[pressure_rows]
            @test pressure_view.pressure_row_jacobian==base.jacobian[pressure_rows,:]
            @test pressure_trace.pressure_row_residual==base.residual[pressure_rows]
            @test pressure_trace.pressure_row_jacobian==base.jacobian[pressure_rows,:]
            pressure_global_residual_defect=maximum(abs,
                pressure_view.pressure_row_residual-base.residual[pressure_rows];init=0.0)
            pressure_global_jacobian_defect=maximum(abs,SparseArrays.nonzeros(
                pressure_view.pressure_row_jacobian-base.jacobian[pressure_rows,:]);init=0.0)
            @test pressure_trace.pressure_dof_ids==Tuple(pressure_dofs)
            @test pressure_trace.pressure_row_ids==Tuple(pressure_rows)
            @test pressure_trace.pressure_dof_to_global_row==Tuple(zip(pressure_dofs,pressure_rows))
            span_rows=collect(component.dynamic_span_row_range)
            @test length(span_rows)==2
            @test base.dynamic_span_row_count==2
            @test [regional.equation_ids[k] for k in span_rows]==collect(component.dynamic_span_equation_ids)
            @test base.residual[span_rows]==collect(pressure_trace.endpoint_definition_residual)
            span_jacobian=base.jacobian[span_rows,:]
            span_oracle=regional_oracle.jacobian[span_rows,:]
            @test span_jacobian==span_oracle
            span_jacobian_defect=maximum(abs,SparseArrays.nonzeros(span_jacobian-span_oracle);init=0.0)
            axis_col,boundary_col=component.profile_span_columns
            @test span_jacobian[1,axis_col]==1.0
            @test span_jacobian[2,boundary_col]==1.0
            @test span_jacobian[1,boundary_col]==0.0
            @test span_jacobian[2,axis_col]==0.0
            pressure_oracle_slice=regional_oracle.jacobian[pressure_rows,:]
            pressure_oracle_defect=maximum(abs,SparseArrays.nonzeros(
                pressure_view.pressure_row_jacobian-pressure_oracle_slice);init=0.0)
            @test pressure_oracle_defect<=256eps(Float64)*max(1.0,
                maximum(abs,SparseArrays.nonzeros(pressure_oracle_slice);init=0.0))
            @test pressure_trace.solver_rows_added==0 && pressure_trace.extra_solver_rows==0
            @test pressure_view.solver_rows_added==0
            @test !pressure_trace.global_topology_closed && !pressure_trace.physical_validation
            @test pressure_trace.missing_closures==component.missing_closures
            @test all(isnothing,values(regional_closures))
            axis_col,boundary_col=component.profile_span_columns
            u_col,v_col=component.profile_coefficient_columns
            profile_law=component.profile_law
            derivative_node=first(k for k in pressure_core_ids if
                0.3<(x[4k]-x[boundary_col])/(x[axis_col]-x[boundary_col])<0.7)
            delta=x[axis_col]-x[boundary_col]
            q=(x[4derivative_node]-x[boundary_col])/delta
            integral=delta*q^3/3
            integral_axis=-2q^3/3
            integral_boundary=2q^3/3-q^2
            u=x[u_col];v=x[v_col]
            fvalue=sqrt(profile_law.fvac_T_m^2+2profile_law.mu0_N_per_A2*v*
                profile_law.Raxis_m*integral)
            pressure_row=component.pressure_rows[derivative_node]
            expected_pressure_psi=-u*q^2/profile_law.Raxis_m
            expected_f_psi=-profile_law.mu0_N_per_A2*v*profile_law.Raxis_m*q^2/fvalue
            @test !iszero(expected_pressure_psi) && !iszero(expected_f_psi)
            @test sign(base.jacobian[pressure_row,4derivative_node])==sign(expected_pressure_psi)
            @test sign(base.jacobian[derivative_node,4derivative_node])==sign(expected_f_psi)
            @test isapprox(base.jacobian[pressure_row,4derivative_node],expected_pressure_psi;
                rtol=32eps(Float64),atol=0.0)
            @test isapprox(base.jacobian[derivative_node,4derivative_node],expected_f_psi;
                rtol=32eps(Float64),atol=0.0)
            @test isapprox(base.jacobian[pressure_row,axis_col],-u*integral_axis/profile_law.Raxis_m;
                rtol=32eps(Float64),atol=0.0)
            @test isapprox(base.jacobian[pressure_row,boundary_col],-u*integral_boundary/profile_law.Raxis_m;
                rtol=32eps(Float64),atol=0.0)
            @test isapprox(base.jacobian[derivative_node,axis_col],-
                profile_law.mu0_N_per_A2*v*profile_law.Raxis_m*integral_axis/fvalue;
                rtol=32eps(Float64),atol=0.0)
            @test isapprox(base.jacobian[derivative_node,boundary_col],-
                profile_law.mu0_N_per_A2*v*profile_law.Raxis_m*integral_boundary/fvalue;
                rtol=32eps(Float64),atol=0.0)
            axis_col,boundary_col=component.profile_span_columns
            u_col,_=component.profile_coefficient_columns
            endpoint_delta=abs(x[axis_col]-x[boundary_col])
            endpoint_probe=copy(x)
            endpoint_probe[axis_col]+=0.001endpoint_delta
            endpoint_probe[boundary_col]-=0.001endpoint_delta
            endpoint_pressure=component.lcfs_profile_current_trace(endpoint_probe;
                pressure_only=true,dynamic_geometry=true,with_jacobian=true)
            @test endpoint_pressure.status===:evaluated_dynamic_LCFS_pressure_only
            @test maximum(abs,endpoint_pressure.pressure_residual)>0
            @test isfinite(endpoint_pressure.pressure_interface_surface_integral_Pa_m2)
            @test abs(endpoint_pressure.pressure_interface_surface_integral_Pa_m2)>0
            @test maximum(abs,collect(endpoint_pressure.endpoint_definition_residual))>0
            @test endpoint_pressure.dynamic_geometry.coordinates_RZ_m==pressure_trace.dynamic_geometry.coordinates_RZ_m
            primary_x_node=trace.data.current_support.critical_points.xpoints[1].nearest_native_id
            xpoint_psi_column=4primary_x_node
            fd_records=NamedTuple[]
            for (fd_name,column) in ((short_model_mode || reuse_local_fd_mode) ? () :
                    (("Baux",boundary_col),("u",u_col),("primary_X_psi",xpoint_psi_column)))
                step=column==u_col ? 1.0e-3*max(1.0,abs(endpoint_probe[column])) : 1.0e-6*endpoint_delta
                plus=copy(endpoint_probe);minus=copy(endpoint_probe)
                plus[column]+=step;minus[column]-=step
                plus_trace=component.lcfs_profile_current_trace(plus;
                    pressure_only=true,dynamic_geometry=true,with_jacobian=false)
                minus_trace=component.lcfs_profile_current_trace(minus;
                    pressure_only=true,dynamic_geometry=true,with_jacobian=false)
                pressure_fd=(plus_trace.pressure_residual-minus_trace.pressure_residual)/(2step)
                pressure_analytic=endpoint_pressure.pressure_jacobian[:,column]
                @test isapprox(pressure_fd,pressure_analytic;rtol=5e-6,atol=5e-18)
                pressure_fd_defect=maximum(abs,pressure_fd-pressure_analytic;init=0.0)
                integral_fd=(plus_trace.pressure_interface_surface_integral_Pa_m2-
                    minus_trace.pressure_interface_surface_integral_Pa_m2)/(2step)
                integral_analytic=endpoint_pressure.pressure_interface_integral_jacobian[1,column]
                @test isapprox(integral_fd,integral_analytic;rtol=2e-3,atol=1e-8)
                integral_fd_defect=abs(integral_fd-integral_analytic)
                traction_fd=(plus_trace.pressure_traction_on_plasma_RZ_N-
                    minus_trace.pressure_traction_on_plasma_RZ_N)/(2step)
                traction_analytic=endpoint_pressure.pressure_traction_jacobian_N[:,column]
                @test isapprox(traction_fd,traction_analytic;rtol=5e-6,atol=1e-8)
                traction_fd_defect=maximum(abs,traction_fd-traction_analytic;init=0.0)
                push!(fd_records,(column=fd_name,pressure_abs_defect=pressure_fd_defect,
                    integral_abs_defect=integral_fd_defect,traction_abs_defect=traction_fd_defect))
            end
            println("G2_DYNAMIC_PRESSURE_CONSUMER_JSON="*F.canonical_json((
                baseline_pressure_minus_authored_p0_max_abs=baseline_pressure_error,
                baseline_surface_integral_Pa_m2=baseline_pressure_integral,
                mask_event=String(pressure_trace.dynamic_geometry.mask_event),
                accepted_core_mask_equal=(support.plasma_native_node_ids==accepted_core_ids),
                accepted_exterior_mask_equal=(support.exterior_native_node_ids==accepted_exterior_ids),
                ray_count=ray_count,ray_support_checks=ray_count,ray_support=:inside_and_outside_each_ray,
                pressure_row_count=length(pressure_rows),pressure_global_row_map_equal=true,
                pressure_global_row_residual_defect=pressure_global_residual_defect,
                pressure_global_row_jacobian_defect=pressure_global_jacobian_defect,
                pressure_oracle_jacobian_defect=pressure_oracle_defect,
                pressure_boundary_conformity=(status=String(pressure_trace.derived_conforming_pressure_boundary.status),
                    predicate_passed=expected_pressure_boundary_conforming,
                    endpoint_definition_residual_Wb_per_rad=pressure_endpoint_residual,
                    endpoint_tolerance_Wb_per_rad=pressure_endpoint_tolerance,
                    geometry_status=String(pressure_trace.dynamic_geometry.status),
                    geometry_map_status=String(pressure_geometry_map.status),
                    pressure_dof_support_status=String(pressure_geometry_map.pressure_dof_support_status),
                    pressure_residual_max_abs_Pa=baseline_pressure_error),
                span_definition_rows=(rows=span_rows,residual=collect(base.residual[span_rows]),
                    axis_diagonal=span_jacobian[1,axis_col],boundary_diagonal=span_jacobian[2,boundary_col],
                    jacobian_max_defect=span_jacobian_defect,jacobian_matches_oracle=(span_jacobian==span_oracle)),
                endpoint_fd_status=reuse_local_fd_mode ? "reused_prequalified_pressure_full_fd" :
                    short_model_mode ? "skipped_global_model_short" : "evaluated",
                endpoint_fd=fd_records,missing_closures=String.(component.missing_closures),
                closure_evidence_all_nothing=all(isnothing,values(regional_closures)),
                global_topology_closed=false,physical_validation=false)))
            flush(stdout)
            baseline_authored_exterior_pressure_Pa=pressure_trace.authored_exterior_pressure_Pa
            g2_diag_lifetime_marker("baseline_summary_pressure_objects_before_release",
                (:trace_pressure_J,hasproperty(pressure_trace,:pressure_jacobian) &&
                    pressure_trace.pressure_jacobian isa SparseArrays.SparseMatrixCSC ? pressure_trace.pressure_jacobian : nothing),
                (:trace_pressure_row_J,hasproperty(pressure_trace,:pressure_row_jacobian) &&
                    pressure_trace.pressure_row_jacobian isa SparseArrays.SparseMatrixCSC ? pressure_trace.pressure_row_jacobian : nothing),
                (:view_pressure_row_J,hasproperty(pressure_view,:pressure_row_jacobian) &&
                    pressure_view.pressure_row_jacobian isa SparseArrays.SparseMatrixCSC ? pressure_view.pressure_row_jacobian : nothing),
                (:baseline_pressure_oracle_slice_J,pressure_oracle_slice),
                (:baseline_span_J,span_jacobian),(:baseline_span_oracle_J,span_oracle))
            native_field_optin && (dynamic_current_contract=nothing)
            pressure_trace=nothing;pressure_view=nothing;pressure_oracle_slice=nothing
            span_jacobian=nothing;span_oracle=nothing
            GC.gc(true)
            g2_diag_lifetime_marker("baseline_summary_pressure_objects_after_release",
                (:trace_pressure_J,nothing),(:trace_pressure_row_J,nothing),
                (:view_pressure_row_J,nothing),(:baseline_pressure_oracle_slice_J,nothing),
                (:baseline_span_J,nothing),(:baseline_span_oracle_J,nothing))
        end
        # Existing same-candidate full-native regional, H-outer, and Ip
        # providers can be inspected together while all five closures remain
        # absent. Assembly and the explicit bounded numerical step below remain
        # diagnostic; they cannot admit the formal coupled solve or line search.
        missing_closures=NamedTuple{S._REQUIRED_CLOSURES}(ntuple(_->nothing,5))
        @test all(isnothing,values(missing_closures))
        no_interface=(args...)->error("single-region diagnostic assembly has no interface rows")
        diagnostic_bindings = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_model_construction",()->
                _g2_full_native_diagnostic_bindings_v1(F,freegs_context,component,trace,provider,composed,regional))
        else
            _g2_full_native_diagnostic_bindings_v1(F,freegs_context,component,trace,provider,composed,regional)
        end
        diagnostic_oracle=diagnostic_bindings.diagnostic_oracle
        diagnostic_callbacks=diagnostic_bindings.callbacks
        candidate_scaling=(contract=diagnostic_bindings.scale_contract,column_scales=diagnostic_bindings.column_scales)
        scale_contract=diagnostic_bindings.scale_contract
        diagnostic_model=diagnostic_bindings.model
        missing_closures=diagnostic_bindings.missing_closures
        if precheck_mode=="global_model_short"
            println("G2_GLOBAL_MODEL_SHORT_RESULT="*F.canonical_json((
                status="constructed_software_diagnostic_only",
                candidate_hash=component.candidate_hash,model_hash=diagnostic_model.model_hash,
                region_dofs=diagnostic_model.region_dofs,
                regional_row_count=length(regional.equation_ids),
                closure_evidence_all_nothing=all(isnothing,values(diagnostic_model.closure_evidence)),
                closure_credit=false,physical_validation=false)))
            flush(stdout)
            return diagnostic_model
        end
        guarded_callbacks=((args...)->error("default/solve closure gate invoked the regional callback"),
            diagnostic_callbacks[2:end]...)
        guarded_model = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_default_guard_model_construction",()->
                diagnostic_bindings.model_constructor(guarded_callbacks,
                    "diagnostic/full-native-default-gate-v1"))
        else
            diagnostic_bindings.model_constructor(guarded_callbacks,
                "diagnostic/full-native-default-gate-v1")
        end
        missing_default = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_default_gate_assembly",()->
                S.assemble_coupled_mhd_global_v1(guarded_model,x))
        else
            S.assemble_coupled_mhd_global_v1(guarded_model,x)
        end
        @test missing_default.status===:typed_absent
        @test missing_default.missing_closures==S._REQUIRED_CLOSURES
        @test keys(missing_default)==(:status,:missing_closures,:candidate_hash,:model_hash,
            :capability_signature,:physical_authority)
        @test !hasproperty(missing_default,:diagnostic_assembly) && !hasproperty(missing_default,:residual)
        @test all(isnothing,values(guarded_model.closure_evidence))
        gate_policy=S.make_global_policy_v1(acceptance_ref="full_native_missing_closure_gate_test_v1",
            contract_source_path=@__FILE__,max_updates=1,wall_seconds=1.0,
            residual_tolerance=1e-6,constraint_tolerance=1e-6,stationarity_tolerance=1e-6,
            bound_dual_tolerance=1e-6,complementarity_tolerance=1e-6,step_tolerance=1e-8,
            minimum_step=1e-6,armijo_fraction=1e-4,max_backtracks=2,
            max_active_set_iterations=8,stagnation_window=1)
        gated_solve=S.solve_coupled_mhd_global_v1(guarded_model,x,gate_policy)
        @test gated_solve.status===:typed_absent
        @test gated_solve.updates==0 && isempty(gated_solve.raw_trace)
        @test !gated_solve.physical_validation && !gated_solve.promotion_authority
        @test all(isnothing,values(guarded_model.closure_evidence))
        if stop_after_gs_u_fd_plus
            run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
            !isempty(run_leaf) && isdir(run_leaf) || error("saved-baseline plus short requires the existing bounded run leaf")
            diagnostic_callbacks=nothing;diagnostic_oracle=nothing;diagnostic_bindings=nothing
            guarded_model=nothing;guarded_callbacks=nothing;missing_default=nothing;gated_solve=nothing
            GC.gc(true)
            return _g2_saved_baseline_gs_u_plus_resource_short_v1(S,component,trace,provider,composed,regional,
                diagnostic_model,candidate_scaling,scale_contract,run_leaf)
        end
        if resume_saved_gs_u_plus
            run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
            !isempty(run_leaf)&&isdir(run_leaf)||error("saved-plus resume requires existing bounded output leaf")
            if resume_saved_trial_next_kkt=="1"
                return _g2_resume_saved_trial_next_kkt_consumer_v1(S,F,component,trace,provider,composed,regional,diagnostic_model,candidate_scaling,scale_contract,run_leaf)
            end
            return _g2_resume_saved_gs_u_plus_trial_v1(S,F,component,trace,provider,composed,regional,diagnostic_model,candidate_scaling,scale_contract,run_leaf)
        end
        changed_state=copy(x)
        pressure_dof=first(i for i in component.pressure_dofs if i>0)
        changed_state[pressure_dof]+=1.0
        law=component.profile_law
        changed_core=first(k for k in eachindex(component.core_mask) if component.core_mask[k] &&
            0.3<(x[4k]-law.psi_boundary_wb_per_rad)/
                (law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)<0.7)
        changed_state[4changed_core]+=1.0e-4*(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)
        if dynamic_span_mode
            axis_col,boundary_col=component.profile_span_columns
            changed_state[axis_col]+=1.0e-8*abs(x[axis_col]-x[boundary_col])
            changed_state[boundary_col]-=1.0e-8*abs(x[axis_col]-x[boundary_col])
            pressure_core_ids=findall(component.core_mask)
            pressure_rows=collect(component.pressure_rows[pressure_core_ids])
            endpoint_step=1.0e-8*abs(x[axis_col]-x[boundary_col])
            endpoint_state=copy(x)
            endpoint_state[axis_col]+=endpoint_step
            endpoint_state[boundary_col]-=endpoint_step
            endpoint_value=regional.regional_evaluator(rid,endpoint_state,regional_closures,regional_context)
            endpoint_actual=endpoint_value.residual[pressure_rows]-regional_initial_residual[pressure_rows]
            endpoint_predicted=regional_oracle.jacobian[pressure_rows,axis_col].*endpoint_step .-
                regional_oracle.jacobian[pressure_rows,boundary_col].*endpoint_step
            endpoint_fd_defect=maximum(abs,endpoint_actual-endpoint_predicted;init=0.0)
            @test any(!iszero,endpoint_predicted)
            @test endpoint_fd_defect<=2e-6*max(1.0,
                maximum(abs,endpoint_actual;init=0.0),maximum(abs,endpoint_predicted;init=0.0))
            endpoint_value=nothing;endpoint_state=nothing
            GC.gc(false)
            changed_pressure_view=component.pressure_domain_view(changed_state)
            changed_pressure_trace=component.lcfs_profile_current_trace(changed_state;
                pressure_only=true,dynamic_geometry=true,with_jacobian=true)
            if native_field_optin
                @test changed_pressure_trace.effective_boundary_q_source===
                    :same_state_dynamic_geometry_psi_boundary_flux
                @test all(a->isapprox(changed_pressure_trace.effective_boundary_q[a],
                    (changed_pressure_trace.dynamic_geometry.psi_boundary_Wb_per_rad-
                        changed_state[boundary_col])/changed_pressure_trace.profile_endpoint_values.delta;
                    rtol=64eps(Float64),atol=0.0),1:64)
            else
                @test !hasproperty(changed_pressure_trace,:effective_boundary_q)
                @test changed_pressure_trace.pressure_scope===:continuous_analytic_p_of_dynamic_total_psi
            end
            @test changed_pressure_trace.candidate_hash==component.candidate_hash==trace.data.candidate_hash
            @test changed_pressure_trace.context_hash==component.context_hash==trace.data.context_hash
            @test changed_pressure_trace.upstream_output_hash==component.upstream_output_hash==trace.data.upstream_output_hash
            @test changed_pressure_trace.trace_hash==trace.trace_hash
            @test changed_pressure_trace.authored_exterior_pressure_Pa==baseline_authored_exterior_pressure_Pa
            @test changed_pressure_trace.pressure_residual==changed_pressure_trace.pressure_Pa .-
                changed_pressure_trace.authored_exterior_pressure_Pa
            changed_lcfs_pressure_error=maximum(abs,changed_pressure_trace.pressure_residual;init=0.0)
            @test changed_lcfs_pressure_error<=1.0e-8
            changed_regional_value=regional.regional_evaluator(rid,changed_state,regional_closures,regional_context)
            changed_regional_oracle=regional.jacobian_oracle(:regional,rid,changed_state,
                regional_closures,regional_context)
            @test changed_pressure_view.pressure_row_residual==changed_regional_value.residual[pressure_rows]
            @test changed_pressure_view.pressure_row_jacobian==changed_regional_value.jacobian[pressure_rows,:]
            @test changed_pressure_trace.pressure_row_residual==changed_regional_value.residual[pressure_rows]
            @test changed_pressure_trace.pressure_row_jacobian==changed_regional_value.jacobian[pressure_rows,:]
            changed_pressure_oracle_slice=changed_regional_oracle.jacobian[pressure_rows,:]
            changed_pressure_defect=maximum(abs,SparseArrays.nonzeros(
                changed_pressure_view.pressure_row_jacobian-changed_pressure_oracle_slice);init=0.0)
            @test changed_pressure_defect<=256eps(Float64)*max(1.0,
                maximum(abs,SparseArrays.nonzeros(changed_pressure_oracle_slice);init=0.0))
            changed_pressure_oracle_slice=nothing
            @test changed_pressure_view.pressure_row_residual!=base.residual[pressure_rows]
            @test SparseArrays.nnz(changed_pressure_view.pressure_row_jacobian[:,axis_col])>0
            @test SparseArrays.nnz(changed_pressure_view.pressure_row_jacobian[:,boundary_col])>0
            @test changed_pressure_trace.solver_rows_added==0 && changed_pressure_trace.extra_solver_rows==0
            @test changed_pressure_view.solver_rows_added==0
            @test !changed_pressure_view.global_topology_closed && !changed_pressure_view.physical_validation
            # Keep only pressure row values/J and the endpoint-definition residual used
            # by the later assembled-row comparisons; discard larger wrapper objects.
            changed_pressure_row_residual=changed_pressure_view.pressure_row_residual
            changed_pressure_row_jacobian=changed_pressure_view.pressure_row_jacobian
            changed_endpoint_definition_residual=collect(changed_pressure_trace.endpoint_definition_residual)
            changed_pressure_view=nothing;changed_pressure_trace=nothing
            GC.gc(false)
        end
        # Keep only the two changed-state span-oracle rows needed below after
        # global assembly; the full independent regional CSC has no later use.
        changed_span_oracle=dynamic_span_mode ?
            copy(changed_regional_oracle.jacobian[span_rows,:]) : nothing
        changed_regional_oracle=nothing
        GC.gc(true)
        # Preserve only the Ip baseline row used by the later provider ABI check.
        # The full baseline/oracle matrices and original regional residual have no
        # remaining consumers once the endpoint comparisons above have completed.
        g2_diag_lifetime_marker("baseline_before_release",
            (:base_J,base.jacobian),(:initial_regional_oracle_J,regional_oracle.jacobian))
        base_current_row_residual=copy(base.residual[provider.conservation_row_indices])
        base_current_row_jacobian=sparse(base.jacobian[provider.conservation_row_indices,:])
        baseline_release_ref===nothing || (baseline_release_ref[]=nothing)
        base=nothing;regional_oracle=nothing
        GC.gc(true)
        g2_diag_lifetime_marker("baseline_after_release",
            (:retained_Ip_row_J,base_current_row_jacobian))
        numeric_replay_metadata(assembly;validation_stage=:global_oracles_passed)=begin
            Base.@nospecialize assembly
            endpoint_rows=Tuple(component.dynamic_span_row_range)
            endpoint_ids=Tuple(component.dynamic_span_equation_ids)
            raw_ids=collect(assembly.equation_ids.regional[1])
            equality_ids=Tuple(scale_contract.equalities.row_ids)
            length(equality_ids)==length(assembly.equality_residual) || error("flattened equality row IDs do not match the assembled KKT equality block")
            ls_rows=[i for i in eachindex(assembly.residual) if !(i in endpoint_rows)]
            equality_base_rows=Tuple(1:length(assembly.equality_residual))
            equality_endpoint_positions=Tuple(length(assembly.equality_residual)+i for i in eachindex(endpoint_rows))
            (schema="g2-global-diagnostic-replay-metadata-v1",
                ordered_ids=(least_squares_raw=raw_ids,equality_base=equality_ids,endpoint=endpoint_ids),
                least_squares_row_indices=ls_rows,equality_base_row_indices=equality_base_rows,
                endpoint_row_indices=endpoint_rows,equality_endpoint_positions=equality_endpoint_positions,
                pressure_indices=[i for i in component.pressure_dofs if i>0],
                consumer_identity=(candidate_hash=diagnostic_model.candidate_hash,
                    provider_id=diagnostic_model.provider_id,model_hash=diagnostic_model.model_hash,
                    component_context_hash=component.context_hash,trace_hash=trace.trace_hash,
                    scale_contract_hash=scale_contract.contract_hash,scale_policy=scale_contract.scale_policy,
                    current_operator_model_id=component.current_operator_model_id,
                    hagenow_source_operator_model_id=component.hagenow_source_operator_model_id,
                    scope=:diagnostic_incomplete_global_assembly),
                validation_stage=validation_stage,
                data_identity=(jacobian_dimensions=size(assembly.jacobian),
                    jacobian_nnz=SparseArrays.nnz(assembly.jacobian),
                    equality_jacobian_dimensions=size(assembly.equality_jacobian),
                    equality_jacobian_nnz=SparseArrays.nnz(assembly.equality_jacobian),
                    residual_length=length(assembly.residual),
                    equality_residual_length=length(assembly.equality_residual)))
        end
        if preoracle_numeric_checkpoint
            length(diagnostic_model.region_ids)==1 && isempty(diagnostic_model.interface_edges) &&
                diagnostic_model.shared_scatter &&
                diagnostic_model.local_dof_to_global==(Tuple(1:length(changed_state)),) &&
                diagnostic_model.local_test_row_to_global==(Tuple(1:length(changed_regional_value.residual)),) ||
                error("pre-oracle checkpoint requires the selected single-region identity map")
            prefix_context=S._provider_context(diagnostic_model)
            prefix_closures=diagnostic_model.closure_evidence
            prefix_outer_record=diagnostic_callbacks[3](rid,changed_state,prefix_closures,prefix_context)
            S._check_provider_record(prefix_outer_record,diagnostic_model,
                diagnostic_model.outer_constraint_ids[1],rid,"outer $(rid)",:constraint_ids)
            prefix_outer_block=S._checked_block(prefix_outer_record,
                length(diagnostic_model.outer_constraint_ids[1]),length(changed_state),"outer $(rid)")
            prefix_outer_residual,prefix_outer_jacobian=S._stack_scattered_constraints(
                (prefix_outer_block,),diagnostic_model.local_dof_to_global,length(changed_state))
            prefix_conservation_record=diagnostic_callbacks[4](changed_state,prefix_closures,prefix_context)
            S._check_provider_record(prefix_conservation_record,diagnostic_model,
                diagnostic_model.global_conservation_ids,"global","conservation",:conservation_ids)
            prefix_conservation_block=S._checked_block(prefix_conservation_record,
                length(diagnostic_model.global_conservation_ids),length(changed_state),"global conservation")
            prefix_equality_ids=(diagnostic_model.outer_constraint_ids[1]...,
                diagnostic_model.global_conservation_ids...)
            prefix_equality_ids==Tuple(scale_contract.equalities.row_ids) ||
                error("pre-oracle H512/current row order differs from the frozen equality contract")
            prefix_c=vcat(prefix_outer_residual,prefix_conservation_block.residual)
            prefix_C=[prefix_outer_jacobian;prefix_conservation_block.jacobian]
            prefix_view=(jacobian=changed_regional_value.jacobian,equality_jacobian=prefix_C,
                residual=changed_regional_value.residual,equality_residual=prefix_c,
                equation_ids=(regional=(Tuple(regional.equation_ids),),))
            preoracle_leaf=joinpath(numeric_result_run_leaf,"preoracle_checkpoint")
            mkpath(preoracle_leaf)
            preoracle_path=_g2_global_diag_spill_matrices(preoracle_leaf,
                prefix_view.jacobian,prefix_view.equality_jacobian;
                residual=prefix_view.residual,equality_residual=prefix_view.equality_residual,
                state=changed_state,column_scales=candidate_scaling.column_scales,
                least_squares_row_scales=diagnostic_model.equilibrium_row_scales,
                equality_row_scales=scale_contract.equalities.characteristics,
                replay_metadata=numeric_replay_metadata(prefix_view;
                    validation_stage=:pre_global_assembler_oracles_pending))
            preoracle_sha=_g2_global_diag_result_file_sha256(preoracle_path)
            println("G2_GLOBAL_DIAGNOSTIC_PREORACLE_NUMERIC_CHECKPOINT path=",preoracle_path,
                " sha256=",preoracle_sha," scope=diagnostic_only validation_stage=pre_global_assembler_oracles_pending",
                " physical_validation=false acceptance_credit=false")
            flush(stdout)
            prefix_view=nothing;prefix_C=nothing;prefix_c=nothing
            prefix_outer_record=nothing;prefix_outer_block=nothing
            prefix_outer_residual=nothing;prefix_outer_jacobian=nothing
            prefix_conservation_record=nothing;prefix_conservation_block=nothing
            GC.gc(true)
        end
        if preoracle_numeric_checkpoint && numeric_replay_capture && !stop_after_gs_u_fd
            # The same-run preoracle spill now owns the regional R/J reference.
            # Release the in-memory callback result before global assembly; after
            # assembly, reload this pinned file for the unchanged row comparisons.
            changed_regional_value=nothing
            GC.gc(true)
            g2_diag_lifetime_marker("changed_regional_reference_released_before_assembly",
                (:regional_reference_J,nothing),(:preoracle_checkpoint_sha256,preoracle_sha))
        end
        regional_oracle_resource_short=get(ENV,"FUSION_G2_PRECHECK_REGIONAL_ORACLE_RESOURCE_SHORT","0")
        regional_oracle_resource_short in ("0","1") ||
            error("FUSION_G2_PRECHECK_REGIONAL_ORACLE_RESOURCE_SHORT must be 0 or 1")
        if regional_oracle_resource_short=="1"
            preoracle_numeric_checkpoint && numeric_replay_capture && !stop_after_gs_u_fd ||
                error("regional oracle resource short requires the pinned preoracle checkpoint path")
            run_leaf=get(ENV,"FUSION_G2_PRECHECK_RESULT_DATA_DIR","")
            !isempty(run_leaf) && isdir(run_leaf) ||
                error("regional oracle resource short requires an existing bounded result leaf")
            GC.gc(true)
            live_before=Base.gc_live_bytes()
            started_ns=time_ns()
            resource_dir=joinpath(run_leaf,"result_data","regional_oracle_resource_short")
            mkpath(resource_dir)
            evaluator_raw_path=joinpath(resource_dir,"regional_evaluator_raw_v1.jls")
            oracle_raw_path=joinpath(resource_dir,"regional_oracle_raw_v1.jls")
            report_path=joinpath(resource_dir,"regional_oracle_resource_short_v1.jls")
            any(ispath,(evaluator_raw_path,oracle_raw_path,report_path)) &&
                error("refusing to overwrite regional-oracle resource artifacts")
            resource_context=S._provider_context(diagnostic_model)
            resource_region=only(diagnostic_model.region_ids)
            resource_state=Float64[changed_state[i] for i in diagnostic_model.local_dof_to_global[1]]
            resource_raw=diagnostic_model.regional_evaluator(resource_region,resource_state,
                diagnostic_model.closure_evidence,resource_context)
            open(evaluator_raw_path,"w") do io;Serialization.serialize(io,resource_raw);flush(io);end
            resource_ids=diagnostic_model.regional_equation_ids[1]
            S._check_provider_record(resource_raw,diagnostic_model,resource_ids,resource_region,
                "resource-short regional evaluator",:equation_ids)
            resource_block=S._checked_block(resource_raw,length(resource_ids),
                diagnostic_model.region_dofs[1],"resource-short regional evaluator")
            resource_raw=nothing
            GC.gc(true)
            live_after_evaluator=Base.gc_live_bytes()
            oracle_started_ns=time_ns()
            resource_oracle_observer=record->begin
                open(oracle_raw_path,"w") do io;Serialization.serialize(io,record);flush(io);end
            end
            resource_oracle_check=S._check_jacobian_oracle(diagnostic_model,:regional,
                resource_region,resource_state,resource_ids,:equation_ids,
                resource_block.jacobian,"resource-short regional";provider_context=resource_context,
                raw_record_observer=resource_oracle_observer)
            GC.gc(true)
            live_after_oracle=Base.gc_live_bytes()
            resource_report=(schema="actual-regional-oracle-resource-short-v1",
                status=:regional_oracle_resource_short_completed,region_id=resource_region,
                state_dofs=length(resource_state),regional_rows=length(resource_ids),
                jacobian_nnz=SparseArrays.nnz(resource_block.jacobian),
                evaluator_live_bytes=live_after_evaluator,oracle_live_bytes=live_after_oracle,
                live_before_bytes=live_before,elapsed_ns=time_ns()-started_ns,
                oracle_elapsed_ns=time_ns()-oracle_started_ns,
                oracle_max_abs_defect=resource_oracle_check.max_abs_defect,
                oracle_tolerance=resource_oracle_check.roundoff_tolerance,
                oracle_passed=resource_oracle_check.passed,global_closure=false,
                physical_validation=false,full_global_assembly_not_run=true)
            resource_path=report_path
            open(resource_path,"w") do io;Serialization.serialize(io,resource_report);flush(io);end
            println("G2_REGIONAL_ORACLE_RESOURCE_SHORT="*F.canonical_json((
                report_path=resource_path,status=resource_report.status,region_id=resource_region,
                state_dofs=length(resource_state),regional_rows=length(resource_ids),
                jacobian_nnz=resource_report.jacobian_nnz,
                live_before_bytes=live_before,evaluator_live_bytes=live_after_evaluator,
                oracle_live_bytes=live_after_oracle,elapsed_ns=resource_report.elapsed_ns,
                oracle_elapsed_ns=resource_report.oracle_elapsed_ns,
                oracle_max_abs_defect=resource_report.oracle_max_abs_defect,
                oracle_tolerance=resource_report.oracle_tolerance,
                oracle_passed=resource_report.oracle_passed,
                global_closure=false,physical_validation=false,full_global_assembly_not_run=true)));flush(stdout)
            resource_block=nothing;resource_state=nothing;resource_context=nothing
            GC.gc(true)
            return merge(resource_report,(report_path=resource_path,))
        end
        diagnostic = if diagnostic_timing
            g2_precheck_timed("global_diagnostic_incomplete_global_assembly",()->
                S.assemble_coupled_mhd_global_v1(diagnostic_model,changed_state;
                    allow_incomplete=true))
        else
            S.assemble_coupled_mhd_global_v1(diagnostic_model,changed_state;
                allow_incomplete=true)
        end
        @test diagnostic.status===:typed_absent
        @test diagnostic.missing_closures==S._REQUIRED_CLOSURES
        @test all(isnothing,values(diagnostic_model.closure_evidence))
        @test !diagnostic.capability_signature.complete && !diagnostic.physical_authority
        @test diagnostic.claim_ceiling===:diagnostic_only
        @test diagnostic.diagnostic_assembly.status===:incomplete_assembly
        @test diagnostic.diagnostic_assembly.claim_ceiling===:diagnostic_only
        @test !diagnostic.diagnostic_assembly.physical_authority
        @test diagnostic.diagnostic_assembly.row_ownership==
            (regional=(regional.region_id,),interface_rows=0,
                outer_rows=length(composed.outer.constraint_ids),conservation_rows=length(provider.conservation_ids))
        @test length(diagnostic.diagnostic_assembly.residual)==length(regional.equation_ids)
        if preoracle_numeric_checkpoint && numeric_replay_capture && !stop_after_gs_u_fd
            # Drop assembler-only raw callback blocks and scaled copies before
            # restoring the same-run regional reference for complete row checks.
            diag_to_slim=diagnostic.diagnostic_assembly
            slim_diagnostic_assembly=merge(diag_to_slim,
                (raw_blocks=nothing,scaled_residual=nothing,scaled_jacobian=nothing))
            diagnostic=merge(diagnostic,(diagnostic_assembly=slim_diagnostic_assembly,))
            diag_to_slim=nothing;slim_diagnostic_assembly=nothing
            GC.gc(true)
            restored_regional=_g2_global_diag_reload_matrices(preoracle_path;
                expected_sha256=preoracle_sha)
            restored_meta=restored_regional.replay_metadata
            @test restored_meta.validation_stage===:pre_global_assembler_oracles_pending
            @test restored_meta.consumer_identity.scope===:diagnostic_incomplete_global_assembly
            @test restored_meta.consumer_identity.candidate_hash==diagnostic_model.candidate_hash
            @test restored_meta.consumer_identity.provider_id==diagnostic_model.provider_id
            @test restored_meta.consumer_identity.model_hash==diagnostic_model.model_hash
            @test restored_meta.consumer_identity.component_context_hash==component.context_hash
            @test restored_meta.consumer_identity.trace_hash==trace.trace_hash
            @test restored_meta.consumer_identity.current_operator_model_id===component.current_operator_model_id
            @test restored_meta.consumer_identity.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id
            @test Tuple(restored_meta.ordered_ids.least_squares_raw)==Tuple(regional.equation_ids)
            @test size(restored_regional.jacobian)==size(diagnostic.diagnostic_assembly.jacobian)
            @test length(restored_regional.residual)==length(diagnostic.diagnostic_assembly.residual)
            @test restored_regional.state==changed_state
            @test Tuple(restored_regional.column_scales)==Tuple(candidate_scaling.column_scales)
            @test Tuple(restored_regional.least_squares_row_scales)==diagnostic_model.equilibrium_row_scales
            @test Tuple(restored_regional.equality_row_scales)==Tuple(scale_contract.equalities.characteristics)
            @test restored_meta.data_identity.jacobian_dimensions==size(restored_regional.jacobian)
            @test restored_meta.data_identity.jacobian_nnz==SparseArrays.nnz(restored_regional.jacobian)
            @test restored_meta.data_identity.residual_length==length(restored_regional.residual)
            changed_regional_value=(jacobian=restored_regional.jacobian,
                residual=restored_regional.residual)
            restored_regional=nothing;GC.gc(false)
            g2_diag_lifetime_marker("changed_regional_reference_reloaded_after_assembly",
                (:regional_reference_J,changed_regional_value.jacobian),
                (:checkpoint_sha256,preoracle_sha))
        end
        @test diagnostic.diagnostic_assembly.residual!=regional_initial_residual
        regional_initial_residual=nothing
        GC.gc(false)
        g2_diag_lifetime_marker("after_initial_residual_release",
            (:retained_Ip_row_J,base_current_row_jacobian))
        if native_field_optin && dynamic_span_mode
            flux_rows=spline_first:(spline_first+2n-1)
            @test diagnostic.diagnostic_assembly.residual[flux_rows]==
                changed_regional_value.residual[flux_rows]
            @test diagnostic.diagnostic_assembly.jacobian[flux_rows,:]==
                changed_regional_value.jacobian[flux_rows,:]
            assembled_flux_ids=diagnostic.diagnostic_assembly.equation_ids.regional[1][flux_rows]
            expected_flux_ids=regional.equation_ids[flux_rows]
            @test length(assembled_flux_ids)==length(expected_flux_ids) &&
                all(i->isequal(assembled_flux_ids[i],expected_flux_ids[i]),eachindex(assembled_flux_ids))
            @test diagnostic.diagnostic_assembly.equation_ids.regional==(Tuple(regional.equation_ids),)
        end
        if dynamic_span_mode
            @test [diagnostic.diagnostic_assembly.equation_ids.regional[1][k] for k in span_rows]==
                collect(component.dynamic_span_equation_ids)
            @test diagnostic.diagnostic_assembly.residual[pressure_rows]==changed_pressure_row_residual
            @test diagnostic.diagnostic_assembly.jacobian[pressure_rows,:]==changed_pressure_row_jacobian
            @test diagnostic.diagnostic_assembly.residual[span_rows]==changed_regional_value.residual[span_rows]
            @test diagnostic.diagnostic_assembly.residual[span_rows]==changed_endpoint_definition_residual
            assembled_span_jacobian=diagnostic.diagnostic_assembly.jacobian[span_rows,:]
            changed_span_jacobian=changed_regional_value.jacobian[span_rows,:]
            @test assembled_span_jacobian==changed_span_jacobian
            span_oracle_defect=maximum(abs,SparseArrays.nonzeros(assembled_span_jacobian-changed_span_oracle);init=0.0)
            gs_rows=findall(id->occursin(":GS4:",id),regional.equation_ids)
            @test !isempty(gs_rows)
            @test diagnostic.diagnostic_assembly.residual[gs_rows]==changed_regional_value.residual[gs_rows]
            @test diagnostic.diagnostic_assembly.jacobian[gs_rows,:]==changed_regional_value.jacobian[gs_rows,:]
            # These full sparse records have completed their checks. Keep only
            # the checked slices needed below before another full FD assembly.
            changed_regional_value=nothing;changed_regional_oracle=nothing;GC.gc(false)
            if !stop_after_first_global_assembly
            if !(preoracle_numeric_checkpoint && full_global_spill)
            # These assembly snapshots are not consumed by the subsequent FD or
            # KKT checks. Keep raw R/J/C, row IDs/ownership, scales, and oracle
            # summaries; release only raw callback blocks and scaled copies.
            diag_to_slim=diagnostic.diagnostic_assembly
            g2_diag_lifetime_marker("diagnostic_before_snapshot_release",
                (:assembled_J,diag_to_slim.jacobian),
                (:assembled_C,diag_to_slim.equality_jacobian),
                (:scaled_J,diag_to_slim.scaled_jacobian),
                (:raw_region_J,diag_to_slim.raw_blocks.regions),
                (:raw_outer_J,diag_to_slim.raw_blocks.outer))
            slim_diagnostic_assembly=merge(diag_to_slim,
                (raw_blocks=nothing,scaled_residual=nothing,scaled_jacobian=nothing))
            diagnostic=merge(diagnostic,(diagnostic_assembly=slim_diagnostic_assembly,))
            diag_to_slim=nothing;slim_diagnostic_assembly=nothing
            GC.gc(true)
            g2_diag_lifetime_marker("diagnostic_after_snapshot_release",
                (:assembled_J,diagnostic.diagnostic_assembly.jacobian),
                (:assembled_C,diagnostic.diagnostic_assembly.equality_jacobian))
            end
            u_col,_=component.profile_coefficient_columns
            if stop_after_gs_u_fd || full_global_spill
                # The FD needs only the checked analytic GS-u column. The full run
                # keeps the numeric assembly in its bounded result leaf for KKT.
                baseline_j_stats=g2_diag_csc_stats(diagnostic.diagnostic_assembly.jacobian)
                baseline_c_stats=g2_diag_csc_stats(diagnostic.diagnostic_assembly.equality_jacobian)
                gs_u_analytic=copy(diagnostic.diagnostic_assembly.jacobian[gs_rows,u_col])
                if full_global_spill
                    numeric_result_spill_path=_g2_global_diag_spill_matrices(
                        numeric_result_run_leaf,diagnostic.diagnostic_assembly.jacobian,
                        diagnostic.diagnostic_assembly.equality_jacobian;
                        residual=diagnostic.diagnostic_assembly.residual,
                        equality_residual=diagnostic.diagnostic_assembly.equality_residual,
                        state=changed_state,column_scales=candidate_scaling.column_scales,
                        least_squares_row_scales=diagnostic.diagnostic_assembly.equilibrium_row_scales,
                        equality_row_scales=scale_contract.equalities.characteristics,
                        replay_metadata=numeric_replay_metadata(diagnostic.diagnostic_assembly))
                    numeric_result_matrix_file_sha256=_g2_global_diag_result_file_sha256(numeric_result_spill_path)
                    println("G2_GLOBAL_DIAGNOSTIC_NUMERIC_SPILL path=",numeric_result_spill_path,
                        " J_csc_payload_bytes=",baseline_j_stats.csc_payload_bytes,
                        " C_csc_payload_bytes=",baseline_c_stats.csc_payload_bytes,
                        " schema=v3 scope=full_KKT_replay_inputs_before_FD_and_KKT")
                    flush(stdout)
                end
                diag_to_slim=diagnostic.diagnostic_assembly
                slim_diagnostic_assembly=merge(diag_to_slim,
                    (jacobian=nothing,equality_jacobian=nothing))
                diagnostic=merge(diagnostic,(diagnostic_assembly=slim_diagnostic_assembly,))
                @test diagnostic.diagnostic_assembly.jacobian===nothing
                @test diagnostic.diagnostic_assembly.equality_jacobian===nothing
                diag_to_slim=nothing;slim_diagnostic_assembly=nothing
                GC.gc(true)
                g2_diag_lifetime_marker("baseline_sparse_release",
                    (:retained_gs_u_analytic,gs_u_analytic),(:released_J,nothing),(:released_C,nothing))
                println("G2_GLOBAL_DIAGNOSTIC_LIFETIME phase=baseline_sparse_release",
                    " gc_live_bytes=",Base.gc_live_bytes(),
                    " retained_gs_u_analytic_entries=",length(gs_u_analytic),
                    " released_J_csc_payload_bytes=",baseline_j_stats.csc_payload_bytes,
                    " released_C_csc_payload_bytes=",baseline_c_stats.csc_payload_bytes)
                flush(stdout)
            end
            gs_u_step=1.0e-3*max(1.0,abs(changed_state[u_col]))
            gs_plus=copy(changed_state);gs_minus=copy(changed_state)
            gs_plus[u_col]+=gs_u_step;gs_minus[u_col]-=gs_u_step
            stop_after_gs_u_fd && g2_diag_lifetime_marker("gs_u_fd_before_plus",
                (:retained_gs_u_analytic,gs_u_analytic))
            gs_plus_result=diagnostic_phase("global_diagnostic_gs_u_fd_plus_assembly",()->
                S.assemble_coupled_mhd_global_v1(diagnostic_model,gs_plus;allow_incomplete=true))
            gs_plus_residual=gs_plus_result.diagnostic_assembly.residual[gs_rows]
            gs_plus_result=nothing;GC.gc(false)
            stop_after_gs_u_fd && g2_diag_lifetime_marker("gs_u_fd_after_plus_release",
                (:retained_gs_u_analytic,gs_u_analytic))
            gs_minus_result=diagnostic_phase("global_diagnostic_gs_u_fd_minus_assembly",()->
                S.assemble_coupled_mhd_global_v1(diagnostic_model,gs_minus;allow_incomplete=true))
            gs_minus_residual=gs_minus_result.diagnostic_assembly.residual[gs_rows]
            gs_minus_result=nothing;GC.gc(false)
            stop_after_gs_u_fd && g2_diag_lifetime_marker("gs_u_fd_after_minus_release",
                (:retained_gs_u_analytic,gs_u_analytic))
            gs_u_fd=(gs_plus_residual-gs_minus_residual)/(2gs_u_step)
            if full_global_spill
                restored=_g2_global_diag_reload_matrices(numeric_result_spill_path;
                    expected_sha256=numeric_result_matrix_file_sha256)
                @test restored.residual==diagnostic.diagnostic_assembly.residual
                @test restored.equality_residual==diagnostic.diagnostic_assembly.equality_residual
                @test restored.state==changed_state
                @test Tuple(restored.column_scales)==Tuple(candidate_scaling.column_scales)
                @test Tuple(restored.least_squares_row_scales)==Tuple(diagnostic.diagnostic_assembly.equilibrium_row_scales)
                @test Tuple(restored.equality_row_scales)==Tuple(scale_contract.equalities.characteristics)
                diag_to_restore=diagnostic.diagnostic_assembly
                restored_assembly=merge(diag_to_restore,
                    (jacobian=restored.jacobian,equality_jacobian=restored.equality_jacobian))
                diagnostic=merge(diagnostic,(diagnostic_assembly=restored_assembly,))
                restored=nothing;diag_to_restore=nothing;restored_assembly=nothing
                GC.gc(true)
                println("G2_GLOBAL_DIAGNOSTIC_NUMERIC_RELOAD path=",numeric_result_spill_path,
                    " gc_live_bytes=",Base.gc_live_bytes(),
                    " J_nnz=",SparseArrays.nnz(diagnostic.diagnostic_assembly.jacobian),
                    " C_nnz=",SparseArrays.nnz(diagnostic.diagnostic_assembly.equality_jacobian))
                flush(stdout)
                diagnostic_assembly=diagnostic.diagnostic_assembly
                diagnostic_result_fingerprint=(schema="g2-global-diagnostic-result-integrity-v1",
                    matrix_digest_semantics=:serialized_numeric_result_file_bytes,
                    numeric_matrix_file_sha256=numeric_result_matrix_file_sha256,
                    residual=diagnostic_assembly.residual,
                    equality_residual=diagnostic_assembly.equality_residual,
                    jacobian=(dimensions=size(diagnostic_assembly.jacobian),
                        nnz=SparseArrays.nnz(diagnostic_assembly.jacobian)),
                    equality_jacobian=(dimensions=size(diagnostic_assembly.equality_jacobian),
                        nnz=SparseArrays.nnz(diagnostic_assembly.equality_jacobian)),
                    ordered_ids=diagnostic_assembly.equation_ids)
                println("G2_GLOBAL_DIAGNOSTIC_RESULT candidate_hash=",diagnostic.candidate_hash,
                    " numeric_result_hash=",F.canonical_hash(diagnostic_result_fingerprint))
                flush(stdout)
                diagnostic_assembly=nothing;diagnostic_result_fingerprint=nothing
                GC.gc(false)
            end
            if !stop_after_gs_u_fd && !full_global_spill
                gs_u_analytic=diagnostic.diagnostic_assembly.jacobian[gs_rows,u_col]
            end
            @test any(!iszero,gs_u_analytic)
            @test isapprox(gs_u_fd,gs_u_analytic;rtol=5e-6,atol=1e-9)
            end
            span_oracle_scale=maximum(abs,SparseArrays.nonzeros(changed_span_oracle);init=0.0)
            @test span_oracle_defect<=256eps(Float64)*max(1.0,span_oracle_scale)
        end
        @test diagnostic.diagnostic_assembly.equation_ids.regional==(Tuple(regional.equation_ids),)
        @test diagnostic.diagnostic_assembly.equation_ids.outer==(composed.outer.constraint_ids,)
        @test diagnostic.diagnostic_assembly.equation_ids.conservation==provider.conservation_ids
        expected_equality_rows=length(composed.outer.constraint_ids)+length(provider.conservation_ids)
        @test length(diagnostic.diagnostic_assembly.equality_residual)==expected_equality_rows
        @test all(check->check.passed,diagnostic.diagnostic_assembly.jacobian_checks.regional)
        @test all(check->check.passed,diagnostic.diagnostic_assembly.jacobian_checks.outer)
        @test diagnostic.diagnostic_assembly.jacobian_checks.global_conservation.passed
        if stop_after_gs_u_fd
            gs_u_fd_nonzero_pass=any(!iszero,gs_u_analytic)
            gs_u_fd_compare_pass=isapprox(gs_u_fd,gs_u_analytic;rtol=5e-6,atol=1e-9)
            gs_u_fd_abs_defect=maximum(abs,gs_u_fd-gs_u_analytic;init=0.0)
            gs_u_fd_analytic_max=maximum(abs,gs_u_analytic;init=0.0)
            g2_diag_lifetime_marker("gs_u_fd_short_before_return",
                (:retained_gs_u_analytic,gs_u_analytic))
            println("G2_GLOBAL_DIAGNOSTIC_GS_U_FD_SHORT original_fd_pass=",
                gs_u_fd_nonzero_pass && gs_u_fd_compare_pass,
                " nonzero_analytic_pass=",gs_u_fd_nonzero_pass,
                " comparison_pass=",gs_u_fd_compare_pass,
                " step=",gs_u_step," absolute_defect=",gs_u_fd_abs_defect,
                " analytic_max_abs=",gs_u_fd_analytic_max,
                " gc_live_bytes=",Base.gc_live_bytes(),
                " retained_baseline_J_is_nothing=",diagnostic.diagnostic_assembly.jacobian===nothing,
                " retained_baseline_C_is_nothing=",diagnostic.diagnostic_assembly.equality_jacobian===nothing,
                " released_baseline_J_nnz=",baseline_j_stats.nnz,
                " released_baseline_C_nnz=",baseline_c_stats.nnz,
                " kkt_partition=not_executed claim_ceiling=diagnostic_only")
            flush(stdout)
            return
        end
        if stop_after_first_global_assembly
            assembled=diagnostic.diagnostic_assembly
            if numeric_replay_capture
                numeric_result_spill_path=_g2_global_diag_spill_matrices(
                    numeric_result_run_leaf,assembled.jacobian,assembled.equality_jacobian;
                    residual=assembled.residual,equality_residual=assembled.equality_residual,
                    state=changed_state,column_scales=candidate_scaling.column_scales,
                    least_squares_row_scales=assembled.equilibrium_row_scales,
                    equality_row_scales=scale_contract.equalities.characteristics,
                    replay_metadata=numeric_replay_metadata(assembled))
                numeric_result_matrix_file_sha256=_g2_global_diag_result_file_sha256(numeric_result_spill_path)
                println("G2_GLOBAL_DIAGNOSTIC_NUMERIC_SPILL path=",numeric_result_spill_path,
                    " schema=v3 scope=first_assembled_incomplete_linear_problem_not_KKT",
                    " byte_sha256=",numeric_result_matrix_file_sha256)
                flush(stdout)
            end
            println("G2_GLOBAL_DIAGNOSTIC_FIRST_ASSEMBLY_RETURN diagnostic_status=",diagnostic.status,
                " assembly_status=",assembled.status," claim_ceiling=",assembled.claim_ceiling,
                " raw_region_size=",size(assembled.jacobian),
                " raw_region_nnz=",SparseArrays.nnz(assembled.jacobian),
                " raw_hard_size=",size(assembled.equality_jacobian),
                " raw_hard_nnz=",SparseArrays.nnz(assembled.equality_jacobian),
                " state_columns=",length(changed_state),
                " region_rows=",length(assembled.residual),
                " H512_rows=",length(composed.outer.constraint_ids),
                " current_rows=",length(provider.conservation_ids),
                " all_five_closures_nothing=",all(isnothing,values(diagnostic_model.closure_evidence)),
                " regional_oracles_pass=",all(check->check.passed,assembled.jacobian_checks.regional),
                " H512_oracle_pass=",all(check->check.passed,assembled.jacobian_checks.outer),
                " conservation_oracle_pass=",assembled.jacobian_checks.global_conservation.passed,
                " physical_authority=",diagnostic.physical_authority,
                " gc_live_bytes=",Base.gc_live_bytes())
            flush(stdout)
            return
        end
        kkt_raw=diagnostic.diagnostic_assembly
        @test kkt_raw.equilibrium_row_scale_hash==
            string(F.canonical_hash(scale_contract.equilibrium.characteristics))
        @test kkt_raw.residual_scaling===:frozen_row_scales
        @test kkt_raw.equilibrium_row_scales==scale_contract.equilibrium.characteristics
        kkt_equality_ids=scale_contract.equalities.row_ids
        @test kkt_equality_ids==(composed.outer.constraint_ids...,provider.conservation_ids...)
        @test scale_contract.equalities.row_units==candidate_scaling.contract.equalities.row_units
        @test scale_contract.equalities.characteristics==candidate_scaling.contract.equalities.characteristics
        @test length(kkt_equality_ids)==length(kkt_raw.equality_residual)==expected_equality_rows
        # The two dynamic endpoint rows define candidate geometry state. Keep
        # production assembly raw; only this diagnostic KKT partition promotes them.
        @test hasproperty(component,:dynamic_span_row_range)
        @test hasproperty(component,:dynamic_span_equation_ids)
        endpoint_ids=Tuple(component.dynamic_span_equation_ids)
        endpoint_rows=collect(component.dynamic_span_row_range)
        @test length(endpoint_rows)==length(endpoint_ids)==(dynamic_span_mode ? 2 : 0)
        if dynamic_span_mode
            @test endpoint_ids==("dynamic_profile_axis_flux_definition",
                "dynamic_profile_boundary_flux_definition")
        else
            @test isempty(endpoint_ids) && isempty(endpoint_rows)
        end
        @test length(unique(endpoint_rows))==(dynamic_span_mode ? 2 : 0)
        raw_ls_ids=kkt_raw.equation_ids.regional[1]
        raw_ls_ids_vec=collect(raw_ls_ids)
        raw_ls_scales=collect(scale_contract.equilibrium.characteristics)
        @test Tuple(raw_ls_ids_vec[i] for i in endpoint_rows)==endpoint_ids
        @test all(i->1<=i<=length(raw_ls_ids_vec),endpoint_rows)
        endpoint_set=Set(endpoint_rows)
        partition_ls_rows=[i for i in eachindex(kkt_raw.residual) if !(i in endpoint_set)]
        partition_ls_ids=raw_ls_ids_vec[partition_ls_rows]
        partition_ls_scales=raw_ls_scales[partition_ls_rows]
        endpoint_scales=raw_ls_scales[endpoint_rows]
        partition_equality_ids=(kkt_equality_ids...,endpoint_ids...)
        partition_equality_scales=vcat(collect(scale_contract.equalities.characteristics),
            endpoint_scales)
        partition_equality_residual=vcat(kkt_raw.equality_residual,
            kkt_raw.residual[endpoint_rows])
        partition_equality_jacobian=[kkt_raw.equality_jacobian;
            kkt_raw.jacobian[endpoint_rows,:]]
        partition_ls_jacobian=kkt_raw.jacobian[partition_ls_rows,:]
        @test length(partition_ls_rows)+length(partition_equality_ids)==
            length(raw_ls_ids)+length(kkt_equality_ids)
        @test size(partition_ls_jacobian)==(length(partition_ls_rows),length(changed_state))
        @test size(partition_equality_jacobian)==
            (length(partition_equality_ids),length(changed_state))
        println("G2_GLOBAL_DIAGNOSTIC_KKT_PARTITION raw_ls_size=",
            size(kkt_raw.jacobian)," raw_equality_size=",size(kkt_raw.equality_jacobian),
            " partition_ls_size=",size(partition_ls_jacobian),
            " partition_equality_size=",size(partition_equality_jacobian),
            " raw_ls_rows=",length(raw_ls_ids)," raw_equality_ids=",kkt_equality_ids,
            " moved_endpoint_rows=",Tuple(endpoint_rows)," moved_endpoint_ids=",endpoint_ids,
            " partition_ls_boundary_ids=",(first(partition_ls_ids),last(partition_ls_ids)),
            " partition_equality_ids=",partition_equality_ids)
        flush(stdout)
        build_kkt_partition=()->S.weighted_residual_kkt_partition_v1(
            candidate_hash=diagnostic.candidate_hash,
            consumer_identity=(candidate_hash=diagnostic.candidate_hash,
                provider_id=diagnostic_model.provider_id,model_hash=diagnostic.model_hash,
                component_context_hash=component.context_hash,trace_hash=trace.trace_hash,
                scale_contract_hash=scale_contract.contract_hash,
                scale_policy=scale_contract.scale_policy,
                scope=:diagnostic_incomplete_global_assembly),
            least_squares_row_ids=partition_ls_ids,
            least_squares_residual=kkt_raw.residual[partition_ls_rows],
            least_squares_jacobian=partition_ls_jacobian,
            least_squares_row_scales=partition_ls_scales,
            equality_row_ids=partition_equality_ids,
            equality_row_scales=partition_equality_scales,
            equality_residual=partition_equality_residual,
            equality_jacobian=partition_equality_jacobian)
        kkt_partition=diagnostic_phase("global_diagnostic_kkt_partition",build_kkt_partition)
        build_kkt_partition=nothing
        reuse_saved_step=get(ENV,"FUSION_G2_REUSE_SAVED_STEP_FOR_TRIAL","0")=="1"
        saved_step_live_binding_verified=false
        if reuse_saved_step
            # Compare the current live consumer's full raw J/C/R/c and row ABI
            # with the pinned R4 input while kkt_raw is still in scope.
            pin_path=joinpath(@__DIR__,"..","runs","e",
                "up2_continuous_psi_global_numeric_capture_20261012_r4",
                "preoracle_checkpoint","result_data","g2_global_diagnostic","numeric_matrices_v3.jls")
            pin_sha="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec"
            pinned=_g2_global_diag_reload_matrices(pin_path;expected_sha256=pin_sha)
            pin_meta=pinned.replay_metadata
            pin_meta.validation_stage===:pre_global_assembler_oracles_pending &&
                pin_meta.consumer_identity.scope===:diagnostic_incomplete_global_assembly ||
                error("saved matrix input is outside the pinned R4 pre-oracle diagnostic scope")
            live_pressure_indices=Tuple(i for i in component.pressure_dofs if i>0)
            live_endpoint_positions=Tuple(length(kkt_equality_ids)+i for i in eachindex(endpoint_rows))
            pin_identity=pin_meta.consumer_identity
            live_identity=(candidate_hash=diagnostic.candidate_hash,
                provider_id=diagnostic_model.provider_id,
                component_context_hash=component.context_hash,trace_hash=trace.trace_hash,
                scale_contract_hash=scale_contract.contract_hash,scale_policy=scale_contract.scale_policy,
                current_operator_model_id=component.current_operator_model_id,
                hagenow_source_operator_model_id=component.hagenow_source_operator_model_id)
            identity_match=all(k->hasproperty(pin_identity,k)&&getproperty(pin_identity,k)==getproperty(live_identity,k),keys(live_identity))
            full_binding=(matrices=pinned.jacobian==kkt_raw.jacobian&&
                    pinned.equality_jacobian==kkt_raw.equality_jacobian,
                residuals=pinned.residual==kkt_raw.residual&&
                    pinned.equality_residual==kkt_raw.equality_residual,
                state_and_columns=pinned.state==Float64.(changed_state)&&
                    Tuple(pinned.column_scales)==Tuple(Float64.(candidate_scaling.column_scales)),
                scales=Tuple(pinned.least_squares_row_scales)==Tuple(Float64.(raw_ls_scales))&&
                    Tuple(pinned.equality_row_scales)==Tuple(Float64.(collect(scale_contract.equalities.characteristics)))&&
                    Tuple(pinned.least_squares_row_scales[endpoint_rows])==Tuple(endpoint_scales)&&
                    Tuple(partition_equality_scales)==Tuple(vcat(pinned.equality_row_scales,endpoint_scales)),
                raw_and_base_ids=Tuple(pin_meta.ordered_ids.least_squares_raw)==Tuple(raw_ls_ids)&&
                    Tuple(pin_meta.ordered_ids.equality_base)==Tuple(kkt_equality_ids),
                endpoint_map=Tuple(pin_meta.ordered_ids.endpoint)==endpoint_ids&&
                    Tuple(pin_meta.endpoint_row_indices)==Tuple(endpoint_rows)&&
                    Tuple(pin_meta.equality_endpoint_positions)==live_endpoint_positions,
                row_map=Tuple(pin_meta.least_squares_row_indices)==Tuple(partition_ls_rows)&&
                    Tuple(pin_meta.equality_base_row_indices)==Tuple(1:length(kkt_equality_ids)),
                pressure_map=Tuple(pin_meta.pressure_indices)==live_pressure_indices,
                consumer_identity=identity_match)
            all(values(full_binding)) || error("saved R4 matrices/rows/scales/pressure map do not exactly bind to the live KKT consumer: $(full_binding)")
            saved_step_live_binding_verified=true
            pinned=nothing;pin_meta=nothing
            GC.gc(true)
            println("G2_SAVED_STEP_LIVE_BINDING verified=true pinned_R4_JCrc=true ordered_rows_scales_pressure=true reload_released=true")
            flush(stdout)
        end
        # Drop test-owned source/slice aliases and raw partition snapshots after
        # their identity/result checks; the step routine consumes scaled matrices.
        partition_ls_jacobian=nothing;partition_equality_jacobian=nothing
        partition_ls_rows=nothing;partition_ls_ids=nothing;partition_ls_scales=nothing
        partition_equality_ids=nothing;partition_equality_scales=nothing
        exact_native_row_ids_before_release=String.(collect(kkt_raw.equation_ids.regional[1]))
        kkt_raw=nothing
        diag_to_slim=diagnostic.diagnostic_assembly
        slim_diagnostic_assembly=merge(diag_to_slim,(jacobian=nothing,equality_jacobian=nothing))
        diagnostic=merge(diagnostic,(diagnostic_assembly=slim_diagnostic_assembly,))
        diag_to_slim=nothing;slim_diagnostic_assembly=nothing
        kkt_partition=merge(kkt_partition,
            (raw_least_squares_jacobian=nothing,raw_equality_jacobian=nothing))
        GC.gc(true)
        g2_diag_lifetime_marker("kkt_raw_snapshot_release",
            (:scaled_J,kkt_partition.scaled_least_squares_jacobian),
            (:scaled_C,kkt_partition.equality_jacobian),
            (:raw_J,kkt_partition.raw_least_squares_jacobian),
            (:raw_C,kkt_partition.raw_equality_jacobian))
        pressure_indices=Tuple(i for i in component.pressure_dofs if i>0)
        exact_map_enabled=get(ENV,"FUSION_G2_EXACT_PIVOT_SOLVE","0")=="1"
        exact_row_pivot_map=if exact_map_enabled
        # Derive row IDs independently from the assembled native rows and
        # checked endpoint row mapping before constructing the numeric map.
        actual_native_row_ids=exact_native_row_ids_before_release
        actual_endpoint_rows=Int.(collect(endpoint_rows))
        actual_endpoint_ids=String.(actual_native_row_ids[actual_endpoint_rows])
        actual_endpoint_ids==String.(collect(endpoint_ids)) ||
            error("dynamic endpoint IDs differ from actual native assembly rows")
        actual_row_index=Dict(id=>i for (i,id) in enumerate(actual_native_row_ids))
        exact_ls_rows=Int[actual_row_index[id] for id in kkt_partition.least_squares_row_ids]
        exact_ls_ids=String.(actual_native_row_ids[exact_ls_rows])
        exact_eq_ids=String.(vcat(collect(kkt_equality_ids),actual_endpoint_ids))
        exact_ls_ids==String.(collect(kkt_partition.least_squares_row_ids)) ||
            error("exact map LS IDs differ from independently derived native assembly rows")
        exact_eq_ids==String.(collect(kkt_partition.equality_row_ids)) ||
            error("exact map equality IDs differ from original outer/current plus native endpoints")
        exact_rows(tag)=findall(id->occursin(":"*tag*":node_",id),exact_ls_ids)
        exact_node(id,tag)=begin
            occursin(":"*tag*":node_",id) || error("exact row-pivot node tag mismatch")
            suffix=split(id,":node_")[end]
            parse(Int,suffix)
        end
        exact_norm_rows=findall(==("profile_axis_pressure_normalization"),exact_ls_ids)
        exact_gs_rows=exact_rows("GS4")
        exact_pressure_rows=exact_rows("profile_pressure")
        exact_f_rows=exact_rows("profile_F")
        exact_br_rows=exact_rows("plasma_spline_Br")
        exact_bz_rows=exact_rows("plasma_spline_Bz")
        exact_node_count=prod(component.grid_shape)
        exact_gs_nodes=exact_node.(exact_ls_ids[exact_gs_rows],"GS4")
        exact_pressure_nodes=exact_node.(exact_ls_ids[exact_pressure_rows],"profile_pressure")
        exact_f_nodes=exact_node.(exact_ls_ids[exact_f_rows],"profile_F")
        exact_br_nodes=exact_node.(exact_ls_ids[exact_br_rows],"plasma_spline_Br")
        exact_bz_nodes=exact_node.(exact_ls_ids[exact_bz_rows],"plasma_spline_Bz")
        (length(exact_norm_rows),length(exact_gs_rows),length(exact_pressure_rows),
            length(exact_f_rows),length(exact_br_rows),length(exact_bz_rows))==
            (1,length(component.gs_native_ids),length(pressure_indices),exact_node_count,
                exact_node_count,exact_node_count) ||
            error("original full-native exact row-pivot group dimensions changed")
        exact_gs_nodes==Int.(collect(component.gs_native_ids)) ||
            error("GS4 equation IDs differ from actual component native IDs")
        exact_f_nodes==collect(1:exact_node_count) &&
            exact_br_nodes==collect(1:exact_node_count) &&
            exact_bz_nodes==collect(1:exact_node_count) ||
            error("full-native exact row-pivot node order differs from the component grid")
        exact_pressure_columns=Int[component.pressure_dofs[node] for node in exact_pressure_nodes]
        exact_pressure_columns==collect(pressure_indices) ||
            error("profile pressure equation IDs differ from actual component pressure DOFs")
        length(component.profile_coefficient_columns)==2 ||
            error("exact row-pivot path requires the two component profile coefficient columns")
        exact_u_column=Int(component.profile_coefficient_columns[1])
        exact_column_groups=([exact_u_column],4 .* exact_gs_nodes,exact_pressure_columns,
            4 .* exact_f_nodes .- 2,
            vcat(4 .* exact_br_nodes .- 3,4 .* exact_bz_nodes .- 1))
        exact_row_groups=(exact_norm_rows,exact_gs_rows,exact_pressure_rows,exact_f_rows,
            vcat(exact_br_rows,exact_bz_rows))
        exact_pivot_columns=vcat(exact_column_groups...)
        exact_free_columns=setdiff(collect(eachindex(changed_state)),exact_pivot_columns)
        exact_span_columns=Int[i for i in component.profile_span_columns if i>0]
        all(i->i in exact_free_columns,exact_span_columns) &&
            component.profile_coefficient_columns[2] in exact_free_columns ||
            error("dynamic profile span or second profile coefficient was assigned as an exact pivot")
        native_data=component.lcfs_dynamic_geometry_data
        fd3_payload=S.ExactRowPivotGSFD3PayloadV1(native_data.Raxis,native_data.Zaxis,
            component.gs_native_ids,component.core_mask,
            component.profile_law.mu0_N_per_A2,component.profile_law.Raxis_m,
            component.profile_span_columns,component.profile_coefficient_columns)
        fd3_rz=NTuple{2,Int}[(div(k-1,length(native_data.Zaxis))+1,
            mod1(k,length(native_data.Zaxis))) for k in component.gs_native_ids]
        exact_row_pivot_map=S.ExactRowPivotKKTMapV1(exact_row_groups,exact_column_groups,
            exact_free_columns,pressure_indices,exact_ls_ids,exact_eq_ids;
            gs_native_rz=fd3_rz,gs_fd3_payload=fd3_payload)
        else
            nothing
        end
        kkt_n=size(kkt_partition.scaled_least_squares_jacobian,2)
        kkt_m=size(kkt_partition.scaled_least_squares_jacobian,1)
        kkt_k=size(kkt_partition.equality_jacobian,1)
        kkt_q=count(i->iszero(changed_state[i]),pressure_indices)
        kkt_order=kkt_n+kkt_m+kkt_k+kkt_q
        kkt_restart=min(S._KKT_GMRES_RESTART_CAP,kkt_order)
        kkt_workspace_estimate=S._matrix_free_working_set_bytes(
            kkt_partition.scaled_least_squares_jacobian,kkt_partition.equality_jacobian,
            kkt_order;restart=kkt_restart)
        kkt_workspace_cap=3*1024^3
        println("G2_GLOBAL_DIAGNOSTIC_KKT_INPUT n=",kkt_n," ls_m=",kkt_m,
            " equality_k=",kkt_k," initial_zero_pressure_q=",kkt_q," order=",kkt_order,
            " restart=",kkt_restart,
            " scaled_J_nnz=",SparseArrays.nnz(kkt_partition.scaled_least_squares_jacobian),
            " scaled_C_nnz=",SparseArrays.nnz(kkt_partition.equality_jacobian),
            " estimated_workspace_bytes=",kkt_workspace_estimate,
            " workspace_cap_bytes=",kkt_workspace_cap,
            " workspace_scope=kkt_workspace_only",
            " ls_scale_hash=",kkt_partition.least_squares_row_scale_hash,
            " equality_scale_hash=",kkt_partition.equality_row_scale_hash)
        flush(stdout)
        kkt_step=if reuse_saved_step
            saved_step_live_binding_verified || error("saved step reuse lacks exact live R4 J/C/R/c and row-map binding")
            # Reuse a previously solved, fully gated numeric step. This branch
            # deliberately skips the KKT solver and binds the artifact to this
            # exact state and pinned R4 matrix capture before the live trial.
            result_dir=get(ENV,"FUSION_G2_SAVED_STEP_RESULT_DATA_DIR",
                joinpath(@__DIR__,"..","runs","e","up2_selected_G_full_kkt_fd3_20261012_r2","result_data"))
            isdir(result_dir) || error("saved-step result_data directory is absent")
            capture_sha="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec"
            state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(changed_state))))
            core_path=joinpath(result_dir,"gs_inverse_full_kkt_core_result_v1.jls")
            step_path=joinpath(result_dir,"gs_inverse_full_kkt_numeric_step_v1.jls")
            candidate_path=joinpath(result_dir,"gs_inverse_full_kkt_candidate_v1.jls")
            all(isfile,(core_path,step_path,candidate_path)) ||
                error("saved-step core, numeric step, and candidate reports are all required")
            core=open(Serialization.deserialize,core_path,"r")
            bundle=open(Serialization.deserialize,step_path,"r")
            candidate=open(Serialization.deserialize,candidate_path,"r")
            core.schema==:actual_R4_exact_row_pivot_full_kkt_core_result_v1 &&
                bundle.schema==:actual_R4_exact_row_pivot_numeric_step_v1 &&
                candidate.schema==:actual_R4_exact_row_pivot_full_kkt_candidate_v1 ||
                error("saved-step artifact schema differs")
            core.capture_sha256==bundle.capture_sha256==capture_sha ||
                error("saved KKT result and step are not pinned to the R4 numeric capture")
            candidate.core_result_sha256==_g2_global_diag_result_file_sha256(core_path) ||
                error("saved candidate digest does not bind to the saved core result")
            bundle.coordinates===:physical_state_coordinates &&
                candidate.step_coordinates===:physical_state_coordinates ||
                error("saved step coordinates differ from the live consumer state")
            bundle.state_dofs==length(changed_state)==candidate.state_dofs ||
                error("saved step state dimension differs from the live consumer")
            bundle.state_sha256==state_sha==candidate.state_sha256 ||
                error("saved step baseline state differs from the live consumer state")
            saved_step=Float64.(collect(bundle.step))
            length(saved_step)==length(changed_state) && all(isfinite,saved_step) ||
                error("saved step shape or values are invalid")
            saved_step_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,saved_step)))
            bundle.step_sha256==candidate.step_sha256==saved_step_sha ||
                error("saved step numeric digest does not match both result records")
            actual=core.result
            actual.status===:ok && length(actual.step)==length(saved_step) &&
                all(isfinite,actual.step) &&
                bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(actual.step))))==saved_step_sha ||
                error("core result does not contain the saved numeric step")
            actual.state_before==Float64.(changed_state) &&
                Tuple(actual.column_scales)==Tuple(Float64.(candidate_scaling.column_scales)) &&
                Tuple(actual.pressure_indices)==Tuple(i for i in component.pressure_dofs if i>0) ||
                error("core result state/column/pressure maps differ from the live consumer")
            candidate.status===:ok && candidate.original_kkt_gate===true &&
                candidate.pressure_bound_gate===true &&
                candidate.true_kkt_relative_defect<=1e-8 &&
                candidate.stationarity<=1e-6 &&
                candidate.schur_rank==candidate.schur_dimension ||
                error("saved numeric step did not pass the original KKT/pressure/Schur gates")
            candidate.dual_violation==0.0 && candidate.complementarity==0.0 &&
                candidate.pressure_lower_bound_violation==0.0 ||
                error("saved candidate dual/complementarity/pressure violation gates are not zero")
            actual.original_kkt_gate===true && actual.true_kkt_gate===true &&
                actual.pressure_bound_gate===true && actual.dual_gate===true &&
                actual.schur_rank==actual.schur_dimension &&
                actual.stationarity<=1e-6 && actual.true_kkt_relative_defect<=1e-8 &&
                actual.dual_violation==0.0 && actual.complementarity==0.0 &&
                actual.pressure_lower_bound_violation==0.0 ||
                error("saved core result did not pass original true-KKT and bound gates")
            candidate.rank_certificate===:not_established_for_full_G &&
                candidate.full_global_kkt===false && candidate.science_credit===false &&
                actual.rank_certificate===:not_established_for_full_G &&
                actual.full_global_kkt===false ||
                error("saved step rank/evidence ceiling changed")
            actual
        else
            solve_kkt_step=()->S.solve_weighted_residual_kkt_step_v1(kkt_partition;
                scaled_state=changed_state,column_scales=candidate_scaling.column_scales,
                pressure_indices=pressure_indices,
                stationarity_tolerance=1e-6,bound_dual_tolerance=1e-6,
                max_active_set_iterations=8,seconds=300.0,
                max_working_memory_bytes=3*1024^3,
                exact_row_pivot_map=exact_row_pivot_map)
            step=diagnostic_phase("global_diagnostic_kkt_step",solve_kkt_step)
            solve_kkt_step=nothing
            step
        end
        reuse_saved_step && println("G2_SAVED_STEP_REUSE verified=true kkt_rerun=false path=actual_live_nonlinear_trial rank_certificate=not_established_for_full_G")
        flush(stdout)
        kkt_trace_summary=Tuple((active_bound_count=length(s.active_bounds),
            linear_status=s.linear_solve===nothing ? :not_entered : s.linear_solve.status,
            linear_reason=s.linear_solve===nothing ? nothing : get(s.linear_solve,:reason,nothing),
            iterations=s.linear_solve===nothing ? nothing : get(s.linear_solve,:iterations,nothing),
            restarts=s.linear_solve===nothing ? nothing : get(s.linear_solve,:restarts,nothing),
            residual_norm=s.linear_solve===nothing ? nothing : get(s.linear_solve,:residual_norm,nothing),
            residual_history=s.linear_solve===nothing ? () : get(s.linear_solve,:residual_history,()),
            equilibration=s.linear_solve===nothing ? nothing : get(s.linear_solve,:equilibration,nothing),
            failure_block_defect=s.linear_solve===nothing ? nothing : get(s.linear_solve,:failure_block_defect,nothing),
            estimated_working_set_bytes=s.linear_solve===nothing ? nothing :
                get(s.linear_solve,:estimated_working_set_bytes,nothing),
            kkt_relative_defect=s.kkt_relative_defect) for s in kkt_step.active_set_trace)
        kkt_trace_estimates=Int128[Int128(v) for s in kkt_step.active_set_trace
            for v in (s.linear_solve===nothing ? nothing :
                get(s.linear_solve,:estimated_working_set_bytes,nothing),) if v!==nothing]
        kkt_memory_estimate=isempty(kkt_trace_estimates) ?
            get(kkt_step,:estimated_working_set_bytes,nothing) : maximum(kkt_trace_estimates)
        kkt_detail=get(kkt_step,:detail,nothing)
        kkt_detail_summary=kkt_detail isa AbstractString ? first(kkt_detail,min(length(kkt_detail),2000)) : kkt_detail
        println("G2_GLOBAL_DIAGNOSTIC_KKT_OUTCOME status=",kkt_step.status,
            " reason=",get(kkt_step,:reason,nothing),
            " detail=",kkt_detail_summary,
            " active_trace=",kkt_trace_summary,
            " estimated_working_set_bytes=",kkt_memory_estimate,
            " max_working_memory_bytes=",get(kkt_step,:max_working_memory_bytes,nothing))
        flush(stdout)
        println("G2_GLOBAL_DIAGNOSTIC_KKT_LINEAR_OBSERVATION trace=",kkt_trace_summary)
        flush(stdout)
        @test kkt_step.status===:ok
        if kkt_step.status===:ok
            @test length(kkt_step.step)==length(changed_state)
            @test all(isfinite,kkt_step.step)
            @test kkt_step.stationarity<=1e-6
            @test kkt_step.kkt_relative_defect<=1e-6
            regional_initial_residual=nothing;regional_oracle=nothing;regional=nothing
            changed_regional_value=nothing;changed_regional_oracle=nothing
            kkt_partition=merge(kkt_partition,(scaled_least_squares_jacobian=nothing,equality_jacobian=nothing))
            GC.gc(true)
            trial_consumer_result=_g2_actual_nonlinear_trial_consumer_v1(S,F,component,composed,provider,regional,diagnostic_model,
                scale_contract,kkt_partition,kkt_step,changed_state,numeric_result_run_leaf,endpoint_rows,endpoint_ids,diagnostic)
            kkt_partition=trial_consumer_result.kkt_partition
            trial_consumer_result=nothing
            println("G2_GLOBAL_DIAGNOSTIC_KKT status=",kkt_step.status,
                " partition_hash=",kkt_partition.partition_hash,
                " step_identity_hash=",get(kkt_step,:step_identity_hash,:not_applicable_exact_row_pivot),
                " exact_backend=",get(kkt_step,:backend,:not_reported),
                " scale_contract_hash=",scale_contract.contract_hash,
                " estimated_working_set_bytes=",kkt_memory_estimate)
            flush(stdout)
        end
        @test !hasproperty(diagnostic,:solver_admission)
        regional_initial_residual=nothing;regional_oracle=nothing;regional=nothing;GC.gc(false)
    else
        @test outer.status===:typed_absent
        @test_throws ArgumentError component.current_outer_partition(provider,outer)
    end
    @test provider.loop_observation_equation_count==0
    @test provider.missing_closures==component.missing_closures
    @test !provider.global_topology_closed && !provider.closure_evidence_created
    @test provider.full_current_conservation===:typed_absent
    @test provider.full_J_normal_trace===:typed_absent && provider.exterior_current_closure===:typed_absent
        @test provider.return_current_path===(provider.current_topology===nothing ?
            :typed_absent : :periodic_toroidal_plasma_with_zero_normal_current_at_LCFS)
    @test component.current_conservation_callbacks(nothing).status===:typed_absent
    @test component.current_conservation_callbacks((status=:typed_absent,)).status===:typed_absent
    S=F.InHouseCoupledMHDGlobalSolveV1
    eid=S._callback_identity(provider.conservation_evaluator)
    oid=S._callback_identity(provider.jacobian_oracle)
    context=(candidate_hash=component.candidate_hash,
        provider_semantic_hash=string(F.canonical_hash(F.semantic_view(trace))),
        provider_context_hash=string(F.canonical_hash((eid,oid))),
        jacobian_oracle_hash=string(F.canonical_hash(oid)))
    closures=NamedTuple{F._CCP_AXISYMMETRIC_MISSING_CLOSURES}(ntuple(_->nothing,5))
    validator=(candidate_hash=context.candidate_hash,provider_semantic_hash=context.provider_semantic_hash,
        provider_context_hash=context.provider_context_hash,jacobian_oracle=provider.jacobian_oracle,
        closure_evidence=closures)
    x=component.initial_state;law=component.profile_law;ucol,vcol=component.profile_coefficient_columns
    k=first(k for k in provider.native_ids if 0.1<
        (x[4k]-law.psi_boundary_wb_per_rad)/(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)<0.9)
    changed_psi=copy(x);changed_psi[4k]=(x[4k]+law.psi_boundary_wb_per_rad)/2
    changed_u=copy(x);changed_u[ucol]*=1.001
    changed_v=copy(x);changed_v[vcol]*=1.001
    initial_value=nothing
    for (index,state) in enumerate((x,changed_psi,changed_u,changed_v))
        value=provider.conservation_evaluator(state,closures,context)
        oracle=provider.jacobian_oracle(:global_conservation,"global",state,closures,context)
        @test S._check_provider_record(value,validator,provider.conservation_ids,"global","actual current conservation rows",:conservation_ids)
        checked=S._check_jacobian_oracle(validator,:global_conservation,"global",state,
            provider.conservation_ids,:conservation_ids,value.jacobian,"actual current conservation rows";provider_context=context)
        @test checked.passed
        original=component.normalization_evaluate(state)
        @test value.residual[1:1]==original.residual[2:2]
        @test value.jacobian[1:1,:]==original.jacobian[2:2,:]
        @test SparseArrays.issparse(value.jacobian) &&
            size(value.jacobian)==(length(provider.conservation_ids),length(x))
        @test maximum(abs,SparseArrays.nonzeros(value.jacobian-oracle.jacobian);init=0.0)<=
            64eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(value.jacobian);init=0.0))
        current=component.core_current_trace(state)
        area=[loop.area_weight_m2 for loop in loops]
        @test isapprox(value.loop_current_A,area .* current.current_cylindrical_A_m2[2:3:end];rtol=32eps(Float64),atol=0.0)
        loop_J=SparseArrays.spdiagm(0=>area)*current.jacobian[2:3:end,:]
        @test maximum(abs,SparseArrays.nonzeros(value.loop_current_jacobian-loop_J);init=0.0)<=
            64eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(loop_J);init=0.0))
        if index==1
            initial_value=value
            if provider.current_topology===nothing
                @test length(provider.conservation_ids)==1
                @test value.residual==original.residual[2:2]
            else
                F_B=component.lcfs_state_F_curl_trace(state;with_jacobian=true,
                    with_cut_jacobian=false,with_Bphi_field_jacobian=false)
                @test F_B.status===:evaluated_dynamic_LCFS_profile_F_residual_lift_curl
                @test F_B.cut_segment_jacobian===:typed_absent
                @test F_B.Bphi_field_jacobian===:typed_absent
                @test value.residual[2:end]==F_B.Jn_A_per_m2
                @test value.jacobian[2:end,:]==F_B.jacobian
                @test value.return_current_integral_jacobian==F_B.integrated_current_jacobian
                @test maximum(abs,F_B.Jn_A_per_m2)>0.0
                @test value.added_global_conservation_ids==Tuple(provider.conservation_ids[2:end])
                @test value.return_current_integral_is_independent_constraint===false
                @test value.return_current_integral_A==F_B.integrated_current_A
                @test value.return_current_integral_scope===:derived_budget_from_the_same_64_pointwise_Jn_rows
            end
            @test value.residual[1:1]==base_current_row_residual
            @test value.jacobian[1:1,:]==base_current_row_jacobian
            @test isapprox(sum(value.loop_current_A),s.current_integral_trapezoid_A;rtol=1e-12,atol=1e-8)
        else
            @test value.residual!=initial_value.residual
            @test value.loop_current_A!=initial_value.loop_current_A
        end
    end
    # Do not silently replace the source's Romberg rule with loop quadrature.
    @test provider.conservation_quadrature===:source_native_RZ_Romberg
    @test provider.loop_current_quadrature===:accepted_native_RZ_tensor_trapezoid
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(candidate_hash=repeat("0",64),)))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(context_hash=repeat("0",64),)))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(upstream_output_hash=repeat("0",64),)))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(trace_hash=repeat("0",64),)))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(current_source=:coil_current,)))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(loops=reverse(loops),)))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(loops=loops[1:end-1],)))
    wrong=copy(loops);wrong[1]=merge(wrong[1],(phi_start_rad=2pi,phi_stop_rad=0.0))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(loops=wrong,)))
    wrong=copy(loops);wrong[1]=merge(wrong[1],(current_A=wrong[1].current_A+1.0,))
    @test_throws ArgumentError component.current_conservation_callbacks(merge(payload,(loops=wrong,)))
    @test_throws ArgumentError provider.conservation_evaluator(x,closures,merge(context,(candidate_hash=repeat("0",64),)))
    @test_throws ArgumentError provider.conservation_evaluator(x,closures,merge(context,(provider_context_hash="",)))
    wrong_context_value=provider.conservation_evaluator(x,closures,merge(context,(provider_context_hash=repeat("0",64),)))
    @test_throws ArgumentError S._check_provider_record(wrong_context_value,validator,
        provider.conservation_ids,"global","foreign provider current rows",:conservation_ids)
    @test_throws ArgumentError provider.jacobian_oracle(:outer,"global",x,closures,context)
    @test_throws ArgumentError provider.jacobian_oracle(:global_conservation,"foreign",x,closures,context)
end
end


function test_actual_freegs_profile_normalization(F,context,artifacts,trace,fixed,fixed_base,
                                                   region,holdout_node,holdout_delta,holdout_sample)
@testset "Actual native variable source-profile normalization" begin
    started=time();println("FREEGS_PROFILE_NORMALIZATION_BEGIN");flush(stdout)
    constructor_started=time()
    println("FREEGS_PROFILE_NORMALIZATION_CONSTRUCTOR_CALL_BEGIN t=",constructor_started);flush(stdout)
    component=try
        F.freegs_axisymmetric_full_support_profile_callbacks(context,artifacts,trace;
            vary_profile_coefficients=true)
    catch constructor_error
        constructor_bt=catch_backtrace()
        println(stderr,"FREEGS_PROFILE_NORMALIZATION_CONSTRUCTOR_ERROR elapsed_s=",
            time()-constructor_started," type=",typeof(constructor_error))
        try
            showerror(stderr,constructor_error);println(stderr)
            for (frame_index,frame) in enumerate(Iterators.take(stacktrace(constructor_bt,true),20))
                println(stderr,"FREEGS_PROFILE_NORMALIZATION_FRAME ",frame_index,
                    " func=",frame.func," file=",frame.file," line=",frame.line,
                    " from_c=",frame.from_c," inlined=",frame.inlined)
            end
        catch display_error
            println(stderr,"FREEGS_PROFILE_NORMALIZATION_BACKTRACE_DISPLAY_ERROR type=",
                typeof(display_error))
        end
        flush(stderr)
        rethrow()
    end
    println("FREEGS_PROFILE_NORMALIZATION_CONSTRUCTOR_CALL_RETURNED elapsed_s=",
        time()-constructor_started);flush(stdout)
    @test component.status===:prepared_full_native_profile_component
    @test component.status==fixed.status
    @test component.gs_status==fixed.gs_status && component.gs_reason==fixed.gs_reason
    @test component.hagenow_status==fixed.hagenow_status && component.hagenow_reason==fixed.hagenow_reason
    @test component.hagenow_boundary_row_count==fixed.hagenow_boundary_row_count
    if artifacts.hagenow_source_response===nothing
        @test component.hagenow_full_jacobian_source_validation===:not_executed
        @test component.hagenow_source_reference.full_jacobian_status===:not_executed
    else
        @test component.hagenow_full_jacobian_source_validation===:passed
        @test component.hagenow_source_reference.full_jacobian_status===:passed
        @test component.hagenow_source_reference.producer_full_jacobian_status===:not_executed
        @test component.hagenow_source_reference.full_jacobian_validation_scope===
            :complete_source_H_and_initial_sparse_H_block_fixed_PF_mask_axis_boundary
        @test component.hagenow_source_reference.full_jacobian_kernel_validation_scope===
            :analytic_reconstructed_H_vs_exported_source_H_entrywise_max_abs_with_2048eps_bound
        @test isfinite(component.hagenow_full_source_map_error) &&
            component.hagenow_full_source_map_error<=component.hagenow_full_source_map_bound
        @test isfinite(component.hagenow_initial_source_jacobian_error) &&
            component.hagenow_initial_source_jacobian_error<=component.hagenow_initial_source_jacobian_bound
    end
    @test component.hagenow_boundary_native_ids==fixed.hagenow_boundary_native_ids
    @test component.hagenow_core_native_ids==fixed.hagenow_core_native_ids
    @test component.hagenow_face_native_ids==fixed.hagenow_face_native_ids
    @test component.hagenow_face_normals_RZ==fixed.hagenow_face_normals_RZ
    @test component.hagenow_response_per_Jphi==fixed.hagenow_response_per_Jphi
    @test component.vary_profile_coefficients && !fixed.vary_profile_coefficients
    @test component.normalization_row_count==2 && fixed.normalization_row_count==0
    if get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1"
        if isempty(get(ENV,"FUSION_FREEGS_LCFS_REPLAY_ARTIFACT_DIRECTORY",""))
            @test get(ENV,"FUSION_FREEGS_SOURCE_PRECHECK","0")=="0"
        end
        @test component.gs_status===:present && component.gs_row_count==16_129
        @test component.hagenow_status===:present && component.hagenow_boundary_row_count==512
        @test component.normalization_row_count==2
        @test length(component.normalization_row_range)==2
        @test length(component.hagenow_boundary_row_range)==512
    end
    @test component.pressure_dofs==fixed.pressure_dofs
    @test component.core_mask==fixed.core_mask
    @test component.raw_constitutive_status==fixed.raw_constitutive_status
    @test component.raw_constitutive_reason==fixed.raw_constitutive_reason
    @test component.missing_closures==fixed.missing_closures
    @test !component.global_topology_closed && !component.full_model_constructed
    println("FREEGS_NORMALIZATION_STAGE=METADATA_END t=",time());flush(stdout)
    if artifacts.hagenow_source_response!==nothing
    println("FREEGS_NORMALIZATION_STAGE=ALTERED_H_NEGATIVE_BEGIN t=",time());flush(stdout)
        altered_values=copy(artifacts.hagenow_source_response.values)
        altered_values[1,1]+=1e-8
        altered_response=merge(artifacts.hagenow_source_response,(values=altered_values,))
        altered_artifacts=F.FreeGSAxisymmetricExecutionArtifactsV4(artifacts.receipt,
            artifacts.input_json,artifacts.output_json,artifacts.field_samples_rz_m,altered_response)
        @test_throws ArgumentError Base.invokelatest(
            F.freegs_axisymmetric_full_support_profile_callbacks,context,altered_artifacts,trace)
    println("FREEGS_NORMALIZATION_STAGE=ALTERED_H_NEGATIVE_END t=",time());flush(stdout)
    println("FREEGS_NORMALIZATION_STAGE=REORDERED_H_NEGATIVE_BEGIN t=",time());flush(stdout)
        reordered_response=merge(artifacts.hagenow_source_response,
            (core_native_ids=reverse(copy(artifacts.hagenow_source_response.core_native_ids)),))
        reordered_artifacts=F.FreeGSAxisymmetricExecutionArtifactsV4(artifacts.receipt,
            artifacts.input_json,artifacts.output_json,artifacts.field_samples_rz_m,reordered_response)
        @test size(reordered_response.values)==size(artifacts.hagenow_source_response.values)
        @test reordered_response.bytes==artifacts.hagenow_source_response.bytes
        @test reordered_response.core_native_ids!=artifacts.hagenow_source_response.core_native_ids
        @test_throws ArgumentError Base.invokelatest(
            F.freegs_axisymmetric_full_support_profile_callbacks,context,reordered_artifacts,trace)
    println("FREEGS_NORMALIZATION_STAGE=REORDERED_H_NEGATIVE_END t=",time());flush(stdout)
    end
    x=component.initial_state;law=component.profile_law
    ucol,vcol=component.profile_coefficient_columns
    @test (ucol,vcol)==(length(fixed.initial_state)+1,length(fixed.initial_state)+2)
    @test x[1:ucol-1]==fixed.initial_state
    @test x[ucol]==law.L_A_per_m2*law.Beta0
    @test x[vcol]==law.L_A_per_m2*(1-law.Beta0)
    println("FREEGS_NORMALIZATION_STAGE=EVALUATE_BEGIN t=",time());flush(stdout)
    base=component.evaluate(x)
    println("FREEGS_NORMALIZATION_STAGE=EVALUATE_END t=",time());flush(stdout)
    println("FREEGS_NORMALIZATION_STAGE=ORACLE_BEGIN t=",time());flush(stdout)
    oracle=component.jacobian_oracle(x)
    println("FREEGS_NORMALIZATION_STAGE=ORACLE_END t=",time());flush(stdout)
    if get(ENV,"FUSION_NATIVE_GRID_MHD","0")=="1"
        @test length(base.residual)==69_445
        @test size(base.jacobian)==(69_445,69_445)
    end
    @test size(base.jacobian)==(length(fixed_base.residual)+2,length(x))
    common_rows=setdiff(collect(eachindex(base.residual)),collect(component.normalization_row_range))
    @test length(common_rows)==length(fixed_base.residual)
    @test maximum(abs,base.residual[common_rows]-fixed_base.residual)<=1e-8
    @test maximum(abs,base.jacobian[common_rows,1:ucol-1]-fixed_base.jacobian)<=1e-8
    @test maximum(abs,base.jacobian-oracle)<=256eps(Float64)*max(1.0,maximum(abs,oracle))
    oracle=nothing
    GC.gc(false)
    variable_outer=component.outer_callbacks()
    println("FREEGS_NORMALIZATION_STAGE=CURRENT_CONSERVATION_BEGIN t=",time());flush(stdout)
    Base.invokelatest(_test_actual_native_current_conservation,F,context,artifacts,component,trace,base,variable_outer,native_field_optin)
    println("FREEGS_NORMALIZATION_STAGE=CURRENT_CONSERVATION_END t=",time());flush(stdout)
    println("FREEGS_NORMALIZATION_STAGE=OUTER_HELPER_BEGIN t=",time());flush(stdout)
    if artifacts.hagenow_source_response===nothing
        @test variable_outer.status===:typed_absent
        @test !hasproperty(variable_outer,:outer_evaluator) && !hasproperty(variable_outer,:jacobian_oracle)
    else
        @test variable_outer.status===:prepared_outer_evaluator
        @test variable_outer.hagenow_full_jacobian_source_validation===:passed
        @test variable_outer.source_reference_full_jacobian_status===:passed
        variable_bindings=_full_native_h_outer_test_context(F,component,trace,variable_outer)
        @test all(isnothing,values(variable_bindings.closures))
        source_H=artifacts.hagenow_source_response.values
        source_plasma_grid=F.JSON3.read(artifacts.output_json)[:native_gs_state][:plasma_psi_wb_per_rad]
        source_nz=component.grid_shape[2]
        source_plasma_boundary=[Float64(source_plasma_grid[cld(k,source_nz)][mod1(k,source_nz)])
            for k in component.hagenow_boundary_native_ids]
        _test_full_native_h_outer_state(F,component,variable_outer,variable_bindings.closures,
            variable_bindings.context,x,source_H,source_plasma_boundary;expected_residual=base.hagenow_feedback.residual,
            expected_jacobian=base.jacobian[component.hagenow_boundary_row_range,:])
        for column in (ucol,vcol)
            changed_coefficients=copy(x)
            changed_coefficients[column]+=1e-8*max(1.0,abs(x[column]))
            _test_full_native_h_outer_state(F,component,variable_outer,variable_bindings.closures,
                variable_bindings.context,changed_coefficients,source_H,source_plasma_boundary)
        end
    end
    println("FREEGS_NORMALIZATION_STAGE=OUTER_HELPER_END t=",time());flush(stdout)
    # Reuse the already-prepared variable-profile component for the same
    # q=.9 plasma-flux holdout. One 192-row LCFS Jacobian supplies both u/v
    # columns; plus/minus value calls do not construct any additional Jacobian.
    println("FREEGS_NORMALIZATION_STAGE=LCFS_COEFFICIENT_HOLDOUT_BEGIN t=",time());flush(stdout)
    if holdout_node>0
        lcfs_holdout_state=copy(x);lcfs_holdout_state[4holdout_node]+=holdout_delta
        lcfs_holdout=component.lcfs_profile_current_trace(lcfs_holdout_state;with_jacobian=true)
        @test lcfs_holdout.status===:evaluated_fixed_LCFS_offgrid_profile_and_curl_Bphi
        pressure_only_holdout=component.lcfs_profile_current_trace(lcfs_holdout_state;
            pressure_only=true,with_jacobian=true)
        @test pressure_only_holdout.status===:evaluated_fixed_LCFS_pressure_only
        @test pressure_only_holdout.current_status===:not_evaluated_by_pressure_only_request
        @test pressure_only_holdout.pressure_residual==lcfs_holdout.pressure_residual
        @test size(pressure_only_holdout.pressure_jacobian)==(64,length(lcfs_holdout_state))
        holdout_source=trace.data.offgrid_source[holdout_sample]
        holdout_q=(lcfs_holdout.psi_physical_wb_per_rad[holdout_sample]-
            holdout_source.eq_psi_axis_wb_per_rad)/
            (holdout_source.eq_psi_boundary_wb_per_rad-holdout_source.eq_psi_axis_wb_per_rad)
        @test isapprox(holdout_q,0.9;rtol=0,atol=1e-12)
        for column in (ucol,vcol)
            step=1e-3*max(1.0,abs(lcfs_holdout_state[column]))
            plus=copy(lcfs_holdout_state);minus=copy(lcfs_holdout_state)
            plus[column]+=step;minus[column]-=step
            rplus=component.lcfs_profile_current_trace(plus;with_jacobian=false).residual
            rminus=component.lcfs_profile_current_trace(minus;with_jacobian=false).residual
            finite_difference=(rplus-rminus)/(2step)
            analytic_column=lcfs_holdout.jacobian[:,column]
            pressure_plus=component.lcfs_profile_current_trace(plus;with_jacobian=false).pressure_residual
            pressure_minus=component.lcfs_profile_current_trace(minus;with_jacobian=false).pressure_residual
            pressure_fd=(pressure_plus-pressure_minus)/(2step)
            pressure_only_plus=component.lcfs_profile_current_trace(plus;pressure_only=true,with_jacobian=false).pressure_residual
            pressure_only_minus=component.lcfs_profile_current_trace(minus;pressure_only=true,with_jacobian=false).pressure_residual
            pressure_only_fd=(pressure_only_plus-pressure_only_minus)/(2step)
            @test pressure_fd==pressure_only_fd
            @test isapprox(pressure_only_fd,pressure_only_holdout.pressure_jacobian[:,column];rtol=5e-6,atol=5e-18)
            fd_rounding_bound=8eps(Float64)*max(1.0,maximum(abs,rplus),maximum(abs,rminus))*
                sqrt(length(finite_difference))/(2step)
            @test F.norm(analytic_column)>fd_rounding_bound
            @test any(!iszero,finite_difference)
            @test isapprox(finite_difference,analytic_column;rtol=5e-6,atol=5e-18)
        end
        lcfs_holdout=nothing
        GC.gc(false)
    else
        @test trace.data.offgrid_source_method===nothing
        absent_lcfs=component.lcfs_profile_current_trace(x;with_jacobian=true)
        @test absent_lcfs.status===:typed_absent
        @test absent_lcfs.residual===nothing && absent_lcfs.jacobian===nothing
    end
    println("FREEGS_NORMALIZATION_STAGE=LCFS_COEFFICIENT_HOLDOUT_END t=",time());flush(stdout)
    # Source targets remain actual declaration values, not measured-fit targets.
    declared=F._freegs_context_binding(context).declaration.profile
    normalization_rows=component.normalization_row_range
    pressure_normalization_row=first(normalization_rows);current_normalization_row=last(normalization_rows)
    @test abs(base.residual[pressure_normalization_row])<=2048eps(Float64)*max(1.0,abs(declared.axis_pressure_pa))
    @test abs(base.residual[current_normalization_row])<=2048eps(Float64)*max(1.0,abs(declared.plasma_current_a))
    @test SparseArrays.nnz(base.jacobian[normalization_rows,:])<=count(component.core_mask)+3
    nr,nz=component.grid_shape;n=nr*nz;core=findall(component.core_mask)
    Ra=collect(trace.data.current_support.R_m);Za=collect(trace.data.current_support.Z_m)
    @test maximum(abs,F._ccp_native_romberg_weights(nr)-F._ccp_native_romberg_weights_oracle(nr))<=1e-12
    @test maximum(abs,F._ccp_native_romberg_weights(nz)-F._ccp_native_romberg_weights_oracle(nz))<=1e-12
    @test_throws ArgumentError F._ccp_native_romberg_weights(128)
    @test_throws ArgumentError F._ccp_native_romberg_weights_oracle(128)
    # Every coefficient column reaches real p/F rows and the current normalization.
    for column in (ucol,vcol)
        @test SparseArrays.nnz(base.jacobian[:,column])>1
        changed=copy(x);changed[column]+=max(1.0,abs(x[column]))*1e-6
        result=component.evaluate(changed);reference=component.jacobian_oracle(changed)
        @test maximum(abs,result.jacobian-reference)<=256eps(Float64)*max(1.0,maximum(abs,reference))
        @test abs(result.residual[current_normalization_row]-base.residual[current_normalization_row])>0
        if component.hagenow_boundary_row_count>0
            hrows=component.hagenow_boundary_row_range
            @test SparseArrays.nnz(base.jacobian[hrows,column])>0
            changed_rows=result.residual[hrows]-base.residual[hrows]
            @test maximum(abs,changed_rows)>0
            predicted=reference[hrows,:]*(changed-x)
            @test maximum(abs,changed_rows-predicted)<=256eps(Float64)*max(1.0,maximum(abs,changed_rows))
        end
        @test maximum(abs,result.residual[1:component.profile_row_count]-base.residual[1:component.profile_row_count])>0
        if component.gs_row_count>0
            rows=(component.profile_row_count+2n+1):(component.profile_row_count+2n+component.gs_row_count)
            @test maximum(abs,result.residual[rows]-base.residual[rows])>0
        end
        result=nothing;reference=nothing
    end
    # Genuine psi perturbations change the global current integral, not Paxis.
    for node in (core[cld(length(core),3)],core[cld(2length(core),3)])
        margin=min(abs(x[4node]-law.psi_axis_wb_per_rad),abs(x[4node]-law.psi_boundary_wb_per_rad))
        changed=copy(x);changed[4node]+=0.01margin
        result=component.evaluate(changed)
        @test result.residual[pressure_normalization_row]==base.residual[pressure_normalization_row]
        @test abs(result.residual[current_normalization_row]-base.residual[current_normalization_row])>0
        midpoint=(changed+x)./2
        predicted=component.jacobian_oracle(midpoint)[normalization_rows,:]*(changed-x)
        @test maximum(abs,(result.residual[normalization_rows]-base.residual[normalization_rows])-predicted)<=2048eps(Float64)*max(1.0,abs(declared.plasma_current_a))
        result=nothing
    end
    # A trapezoidal rule is the existing filament measure, not this source rule.
    trap=collect(trace.data.current_support.area_weight_m2)
    trapezoid_current=sum(trap[i][j]*trace.data.current_support.Jphi_A_per_m2[i][j] for i in 1:nr,j in 1:nz)
    @test !isapprox(trapezoid_current,declared.plasma_current_a;rtol=2048eps(Float64),atol=0)
    bad=copy(x);bad[vcol]=-1e100
    @test_throws DomainError component.evaluate(bad)
    # Reject nonzero cancellation: it has no finite source (L,Beta0) inverse.
    # The all-zero contribution does have a finite source representation.
    cancellation=copy(x);cancellation[ucol]=-cancellation[vcol]
    @test_throws DomainError component.evaluate(cancellation)
    @test_throws DomainError component.jacobian_oracle(cancellation)
    overflow=copy(x);overflow[ucol]=overflow[vcol]=floatmax(Float64)
    @test_throws DomainError component.evaluate(overflow)
    zero_profile=copy(x);zero_profile[ucol]=zero_profile[vcol]=0.0
    @test all(isfinite,component.evaluate(zero_profile).residual)
    bad=copy(x);bad[4first(core)]=law.psi_axis_wb_per_rad+abs(law.psi_axis_wb_per_rad-law.psi_boundary_wb_per_rad)
    @test_throws DomainError component.evaluate(bad)
    @test component.normalization_is_return_current_closure===false
    Base.invokelatest(test_actual_freegs_core_current_trace,F,component,trace,region)
    Base.invokelatest(test_actual_freegs_LCFS_flux_map,F,component,trace,region)
    println("FREEGS_PROFILE_NORMALIZATION_JSON="*F.canonical_json((
        dofs=length(x),coefficient_columns=(ucol,vcol),normalization_rows=2,
        pressure_normalization_residual_Pa=base.residual[pressure_normalization_row],current_normalization_residual_A=base.residual[current_normalization_row],
        declared_Paxis_Pa=declared.axis_pressure_pa,declared_Ip_A=declared.plasma_current_a,
        hagenow_source_comparison_error=component.hagenow_source_comparison_error,
        hagenow_source_comparison_bound=component.hagenow_source_comparison_bound,
        hagenow_source_directional_validation=component.hagenow_source_directional_validation,
        hagenow_full_jacobian_source_validation=component.hagenow_full_jacobian_source_validation,
        hagenow_full_source_map_error=component.hagenow_full_source_map_error,
        hagenow_full_source_map_bound=component.hagenow_full_source_map_bound,
        hagenow_initial_source_jacobian_error=component.hagenow_initial_source_jacobian_error,
        hagenow_initial_source_jacobian_bound=component.hagenow_initial_source_jacobian_bound,
        fixed_axis_boundary_mask=true,varying_coefficients=true,
        original_bilinear_axis_diagnostic_retained=true,
        all_five_closures_still_missing=true,global_topology_closed=false,physical_validation=false)))
    println("FREEGS_PROFILE_NORMALIZATION_END elapsed_s=",time()-started);flush(stdout)
end
end

Base.@noinline Base.@nospecializeinfer function _g2_actual_bphi_retraction_consumer_v1(
        S,F,component,composed,provider,regional,diagnostic_model,scale_contract,
        kkt_partition,kkt_step,accepted_state,numeric_result_run_leaf,endpoint_rows,endpoint_ids,diagnostic)
    Base.@nospecialize S F component composed provider regional diagnostic_model scale_contract
    Base.@nospecialize kkt_partition kkt_step accepted_state numeric_result_run_leaf endpoint_rows endpoint_ids diagnostic
    inputs_only_flag=get(ENV,"FUSION_G2_BPHI_RETRACTION_INPUTS_ONLY","0")
    inputs_only_flag in ("0","1") || error("Bphi retraction inputs-only flag must be 0 or 1")
    get(ENV,"FUSION_G2_BPHI_RETRACTION_CONSUMER","0")=="1" ||
        error("Bphi retraction helper requires its explicit production dispatch")
    println("G2_BPHI_INPUTS_STAGE=helper_enter inputs_only=",inputs_only_flag);flush(stdout)
    action_path=get(ENV,"FUSION_G2_BPHI_ACTION_RAW_PATH","")
    action_sha=lowercase(get(ENV,"FUSION_G2_BPHI_ACTION_RAW_SHA256",""))
    !isempty(action_path) && isfile(action_path) && occursin(r"^[0-9a-f]{64}$",action_sha) &&
        _g2_global_diag_result_file_sha256(action_path)==action_sha ||
        error("Bphi retraction requires the pinned recovered action raw")
    action=open(Serialization.deserialize,action_path,"r")
    println("G2_BPHI_INPUTS_STAGE=action_loaded");flush(stdout)
    action.schema===:saved_actual_trial_current_constraint_bphi_action_raw_v1 &&
        all(c->c.passed,action.binding_checks) ||
        error("recovered action schema/bindings are not qualified")
    binding=action.corrected_trial_state_binding
    binding.status===:corrected_from_pinned_newer_kkt_step &&
        binding.next_step_path isa AbstractString && isfile(binding.next_step_path) &&
        _g2_global_diag_result_file_sha256(binding.next_step_path)==binding.next_step_artifact_sha256 &&
        binding.next_step_vector_sha256==bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(collect(kkt_step.step))))) &&
        binding.accepted_input_trial_path isa AbstractString && isfile(binding.accepted_input_trial_path) &&
        _g2_global_diag_result_file_sha256(binding.accepted_input_trial_path)==binding.accepted_source_sha256 &&
        kkt_step.state_before==Float64.(collect(accepted_state)) ||
        error("recovered action is not bound to the live saved next-step source")
    projection_path=action.input_paths.projection
    trial_path=action.input_paths.trial
    geometry_path=action.input_paths.trial_geometry
    all(isfile,(projection_path,trial_path,geometry_path)) ||
        error("pinned projection/trial/geometry inputs are missing")
    all(_g2_global_diag_result_file_sha256(path)==sha for (path,sha) in
        ((projection_path,action.input_sha256.projection),(trial_path,action.input_sha256.trial),
         (geometry_path,action.input_sha256.trial_geometry))) ||
        error("recovered action's projected-state input digest differs")
    projection=open(Serialization.deserialize,projection_path,"r")
    println("G2_BPHI_INPUTS_STAGE=projection_loaded");flush(stdout)
    projected_raw=open(Serialization.deserialize,trial_path,"r")
    println("G2_BPHI_INPUTS_STAGE=projected_trial_loaded");flush(stdout)
    geometry_raw=open(Serialization.deserialize,geometry_path,"r")
    println("G2_BPHI_INPUTS_STAGE=projected_geometry_loaded");flush(stdout)
    projection.schema=="g2-global-diagnostic-actual-trial-exact-span-projection-v1" &&
        projected_raw.schema=="g2-global-diagnostic-actual-nonlinear-trial-raw-v1" &&
        geometry_raw.schema=="g2-global-diagnostic-actual-trial-span-geometry-recheck-v1" ||
        error("pinned Bphi retraction projection/trial/geometry schema differs")
    step_vector=Float64.(collect(kkt_step.step))
    base_state=Float64.(collect(accepted_state))
    length(step_vector)==length(base_state)==length(projection.pre_projection_state) ||
        error("saved next-step state/direction dimensions differ")
    next_step_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,step_vector)))
    expected_unprojected=base_state.+Float64(projection.alpha).*step_vector
    projected_raw_state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,collect(Float64,projected_raw.state))))
    projection.pre_projection_state==expected_unprojected &&
        projection.pre_projection_state_sha256==bytes2hex(SHA.sha256(reinterpret(UInt8,expected_unprojected))) &&
        projected_raw.state==projection.post_projection_state &&
        projected_raw_state_sha==projection.post_projection_state_sha256 &&
        projected_raw_state_sha==action.trial_state_sha256 &&
        projection.post_projection_state_sha256==binding.projected_state_sha256 &&
        next_step_sha==binding.next_step_vector_sha256 ||
        error("projection/action state is not the exact pinned accepted next-step trial")
    action.current_operator_model_id===component.current_operator_model_id &&
        action.field_model_id===component.native_field_model_id &&
        action.source_operator_model_id===component.hagenow_source_operator_model_id ||
        error("Bphi retraction action current/source/field model differs from the live component")
    println("G2_BPHI_INPUTS_STAGE=operator_id_bindings_pass");flush(stdout)
    n=action.native_map.n
    phi_columns=Int[4k-2 for k in 1:n]
    action_bphi_columns=collect(Int,action.native_map.Bphi_global_columns)
    action_bphi_columns == phi_columns ||
        error("saved Bphi action column mapping differs from native 4-DOF nodes")
    length(component.core_mask)==n && length(base_state)==action.native_map.domain_ndof &&
        n==16_641 && length(base_state)==69_447 ||
        error("live component/native Bphi action dimensions differ")
    println("G2_BPHI_INPUTS_STAGE=native_map_pass n=",n);flush(stdout)
    delta_Bphi=Float64.(collect(action.profile_F.delta_Bphi_T))
    radius=Float64.(collect(action.native_map.native_R_m))
    D=Float64.(collect(action.profile_F.before_T_m))
    length(delta_Bphi)==length(radius)==length(D)==n && all(isfinite,delta_Bphi) &&
        all(isfinite,radius) && all(>(0.0),radius) && all(isfinite,D) &&
        delta_Bphi==Float64[-D[k]/radius[k] for k in 1:n] ||
        error("saved profile-F Bphi correction is not the exact nodewise -D/R action")
    correction=zeros(Float64,length(base_state))
    correction[phi_columns]=delta_Bphi
    corrected_state=Float64.(collect(projection.post_projection_state)).+correction
    pressure_values_valid=true
    for i in component.pressure_dofs
        if i>0 && corrected_state[i]<0.0
            pressure_values_valid=false
            break
        end
    end
    all(isfinite,corrected_state) &&
        pressure_values_valid &&
        all(k->corrected_state[4k-2]>0.0,1:n) ||
        error("Bphi-corrected state fails the existing finite/pressure/Bphi preguard")
    println("G2_BPHI_INPUTS_STAGE=correction_and_state_domain_pass");flush(stdout)

    projected_assembly=projected_raw.result.diagnostic_assembly
    projected_ids=collect(projected_assembly.equation_ids.regional[1])
    projected_region_ids=collect(projected_assembly.equation_ids.regional[1])
    expected_region_ids=collect(regional.equation_ids)
    projected_outer_ids=collect(projected_assembly.equation_ids.outer[1])
    expected_outer_ids=collect(composed.outer.constraint_ids)
    projected_conservation_ids=collect(projected_assembly.equation_ids.conservation)
    expected_conservation_ids=collect(provider.conservation_ids)
    region_mismatch=findfirst(i->!(projected_region_ids[i]==expected_region_ids[i]),
        1:min(length(projected_region_ids),length(expected_region_ids)))
    region_mismatch=region_mismatch===nothing ?
        (length(projected_region_ids)==length(expected_region_ids) ? 0 : min(length(projected_region_ids),length(expected_region_ids))+1) : region_mismatch
    outer_mismatch=findfirst(i->!(projected_outer_ids[i]==expected_outer_ids[i]),
        1:min(length(projected_outer_ids),length(expected_outer_ids)))
    outer_mismatch=outer_mismatch===nothing ?
        (length(projected_outer_ids)==length(expected_outer_ids) ? 0 : min(length(projected_outer_ids),length(expected_outer_ids))+1) : outer_mismatch
    conservation_mismatch=findfirst(i->!(projected_conservation_ids[i]==expected_conservation_ids[i]),
        1:min(length(projected_conservation_ids),length(expected_conservation_ids)))
    conservation_mismatch=conservation_mismatch===nothing ?
        (length(projected_conservation_ids)==length(expected_conservation_ids) ? 0 : min(length(projected_conservation_ids),length(expected_conservation_ids))+1) : conservation_mismatch
    source_assembly_binding=(schema=:actual_bphi_projected_source_assembly_binding_v1,
        status=projected_assembly.status,claim_ceiling=projected_assembly.claim_ceiling,
        physical_authority=projected_assembly.physical_authority,
        regional_oracles_pass=all(c->c.passed,projected_assembly.jacobian_checks.regional),
        outer_oracles_pass=all(c->c.passed,projected_assembly.jacobian_checks.outer),
        conservation_oracle_pass=projected_assembly.jacobian_checks.global_conservation.passed===true,
        regional_ids=(actual_count=length(projected_region_ids),expected_count=length(expected_region_ids),
            actual_container=string(nameof(typeof(projected_assembly.equation_ids.regional[1]))),
            expected_container=string(nameof(typeof(regional.equation_ids))),first_mismatch_index=region_mismatch,
            first_mismatch_actual=1<=region_mismatch<=length(projected_region_ids) ? projected_region_ids[region_mismatch] : nothing,
            first_mismatch_expected=1<=region_mismatch<=length(expected_region_ids) ? expected_region_ids[region_mismatch] : nothing,
            ordered_match=region_mismatch==0),
        outer_ids=(actual_count=length(projected_outer_ids),expected_count=length(expected_outer_ids),
            actual_container=string(nameof(typeof(projected_assembly.equation_ids.outer[1]))),
            expected_container=string(nameof(typeof(composed.outer.constraint_ids))),first_mismatch_index=outer_mismatch,
            first_mismatch_actual=1<=outer_mismatch<=length(projected_outer_ids) ? projected_outer_ids[outer_mismatch] : nothing,
            first_mismatch_expected=1<=outer_mismatch<=length(expected_outer_ids) ? expected_outer_ids[outer_mismatch] : nothing,
            ordered_match=outer_mismatch==0),
        conservation_ids=(actual_count=length(projected_conservation_ids),expected_count=length(expected_conservation_ids),
            actual_container=string(nameof(typeof(projected_assembly.equation_ids.conservation))),
            expected_container=string(nameof(typeof(provider.conservation_ids))),first_mismatch_index=conservation_mismatch,
            first_mismatch_actual=1<=conservation_mismatch<=length(projected_conservation_ids) ? projected_conservation_ids[conservation_mismatch] : nothing,
            first_mismatch_expected=1<=conservation_mismatch<=length(expected_conservation_ids) ? expected_conservation_ids[conservation_mismatch] : nothing,
            ordered_match=conservation_mismatch==0))
    if inputs_only_flag=="1"
        binding_path=joinpath(numeric_result_run_leaf,"result_data","g2_global_diagnostic",
            "projected_source_assembly_binding_v1.jls")
        mkpath(dirname(binding_path))
        ispath(binding_path) && error("refusing to overwrite projected source-assembly binding raw")
        open(binding_path,"w") do io;Serialization.serialize(io,source_assembly_binding);flush(io);end
        println("G2_BPHI_INPUTS_STAGE=source_assembly_binding_raw_saved path=",abspath(binding_path),
            " regional_types=",source_assembly_binding.regional_ids.actual_container,"/",
            source_assembly_binding.regional_ids.expected_container," outer_types=",
            source_assembly_binding.outer_ids.actual_container,"/",
            source_assembly_binding.outer_ids.expected_container);flush(stdout)
    end
    projected_assembly.status===:incomplete_assembly &&
        projected_assembly.claim_ceiling===:diagnostic_only &&
        projected_assembly.physical_authority===false &&
        all(c->c.passed,projected_assembly.jacobian_checks.regional) &&
        all(c->c.passed,projected_assembly.jacobian_checks.outer) &&
        projected_assembly.jacobian_checks.global_conservation.passed===true &&
        length(projected_assembly.equation_ids.regional)==1 &&
        source_assembly_binding.regional_ids.ordered_match &&
        length(projected_assembly.equation_ids.outer)==1 &&
        source_assembly_binding.outer_ids.ordered_match &&
        source_assembly_binding.conservation_ids.ordered_match ||
        error("projected-state source assembly/oracle/row ownership is not qualified")
    println("G2_BPHI_INPUTS_STAGE=projected_assembly_oracles_pass rows=",length(projected_ids));flush(stdout)
    projected_rows=Dict{eltype(projected_ids),Int}()
    sizehint!(projected_rows,length(projected_ids))
    for (i,id) in enumerate(projected_ids)
        projected_rows[id]=i
    end
    ls_ids=collect(kkt_partition.least_squares_row_ids)
    all(id->haskey(projected_rows,id),ls_ids) ||
        error("projected state does not carry the frozen least-squares rows")
    projected_ids[endpoint_rows]==collect(endpoint_ids) ||
        error("projected state's endpoint row indices differ from the frozen consumer")
    ls_rows=Vector{Int}(undef,length(ls_ids))
    for (i,id) in enumerate(ls_ids)
        ls_rows[i]=projected_rows[id]
    end
    projected_eq_ids=collect(eltype(projected_ids),projected_assembly.equation_ids.outer[1])
    append!(projected_eq_ids,projected_assembly.equation_ids.conservation)
    append!(projected_eq_ids,component.dynamic_span_equation_ids)
    projected_eq_ids==collect(eltype(projected_ids),kkt_partition.equality_row_ids) ||
        error("projected state's equality row IDs differ from the frozen consumer")
    projected_ls=projected_assembly.residual[ls_rows]./collect(kkt_partition.least_squares_row_scales)
    projected_eq=vcat(projected_assembly.equality_residual,projected_assembly.residual[endpoint_rows])./
        collect(kkt_partition.equality_row_scales)
    projected_merit=0.5*(sum(abs2,projected_ls)+sum(abs2,projected_eq))
    isfinite(projected_merit) || error("projected-state baseline merit is nonfinite")
    projected_F_row_ids=collect(action.native_map.profile_F_row_ids)
    projected_F=Float64[projected_assembly.residual[projected_rows[id]] for id in projected_F_row_ids]
    projected_F==D || error("pinned projected-state F residual differs from saved action input")
    println("G2_BPHI_INPUTS_STAGE=projected_rowmaps_and_merit_pass ls_rows=",length(ls_rows),
        " F_rows=",length(projected_F));flush(stdout)
    projected_state=Float64.(collect(projected_raw.state))
    source_geometry_raw=geometry_raw.projected_state_geometry
    source_geometry_raw.status===:evaluated_dynamic_LCFS_geometry &&
        source_geometry_raw.mask_event===:unchanged &&
        length(source_geometry_raw.coordinates_RZ_m)==length(source_geometry_raw.normals_RZ)==64 ||
        error("pinned projected-state geometry/mask is not evaluated on all 64 rays")
    psi_global_dof_ids=collect(Int,source_geometry_raw.psi_global_dof_ids)
    source_geometry=(status=source_geometry_raw.status,mask_event=source_geometry_raw.mask_event,
        coordinates_RZ_m=Tuple(source_geometry_raw.coordinates_RZ_m),
        normals_RZ=Tuple(source_geometry_raw.normals_RZ),
        psi_axis_Wb_per_rad=Float64(source_geometry_raw.psi_axis_Wb_per_rad),
        psi_boundary_Wb_per_rad=Float64(source_geometry_raw.psi_boundary_Wb_per_rad),
        first_outward_crossing_signature=Tuple(source_geometry_raw.first_outward_crossing_signature),
        psi_global_dof_ids=psi_global_dof_ids,
        ray_rule=source_geometry_raw.ray_rule,field_model_id=source_geometry_raw.field_model_id,
        field_representation=source_geometry_raw.field_representation,
        source_critical_point_method=source_geometry_raw.source_critical_point_method,
        source_critical_point_role=source_geometry_raw.source_critical_point_role,
        source_fd_anchor_use=source_geometry_raw.source_fd_anchor_use,
        jacobian_columns=source_geometry_raw.jacobian_columns,
        fixed_PF_total_psi=source_geometry_raw.fixed_PF_total_psi,
        solver_rows_added=source_geometry_raw.solver_rows_added,
        global_topology_closed=source_geometry_raw.global_topology_closed,
        physical_validation=source_geometry_raw.physical_validation)
    source_geometry.field_model_id===component.native_field_model_id &&
        source_geometry.field_representation===:plasma_not_a_knot_spline_plus_unclipped_exact_PF_Green_jet &&
        source_geometry.ray_rule===Symbol("64_ray_first_sampled_outward_psiN_1_bracket") &&
        source_geometry.jacobian_columns===:psi_native_dofs_only &&
        source_geometry.fixed_PF_total_psi===true && source_geometry.solver_rows_added==0 &&
        source_geometry.global_topology_closed===false && source_geometry.physical_validation===false &&
        source_geometry.source_critical_point_role===:seed_only_rebound_on_composite_psi &&
        source_geometry.source_fd_anchor_use===:unchanged_source_records_not_reused_as_continuous_fields &&
        length(source_geometry.psi_global_dof_ids)==action.native_map.n &&
        all(k->source_geometry.psi_global_dof_ids[k]==4k,1:action.native_map.n) ||
        error("projected geometry lacks the declared 64-ray selected-field/source branch markers")
    println("G2_BPHI_INPUTS_STAGE=compact_geometry_binding_pass rays=",
        length(source_geometry.coordinates_RZ_m)," psi_dofs=",length(psi_global_dof_ids));flush(stdout)
    projected_raw=nothing;projected_assembly=nothing;projected_ls=nothing;projected_eq=nothing
    projected_rows=nothing;ls_rows=nothing;source_geometry_raw=nothing;geometry_raw=nothing;projection=nothing;GC.gc(true)

    if inputs_only_flag=="1"
        inputs_path=joinpath(numeric_result_run_leaf,"result_data","g2_global_diagnostic",
            "actual_saved_bphi_retraction_inputs_v1.jls")
        mkpath(dirname(inputs_path))
        ispath(inputs_path) && error("refusing to overwrite Bphi retraction inputs-only raw")
        prepared_state=collect(Float64,corrected_state)
        prepared_state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,prepared_state)))
        inputs_raw=(schema=:actual_saved_bphi_retraction_inputs_v1,
            status=:actual_bphi_retraction_inputs_only_saved,
            action_sha256=action_sha,
            projection_sha256=action.input_sha256.projection,
            projected_trial_sha256=action.input_sha256.trial,
            projected_geometry_sha256=action.input_sha256.trial_geometry,
            accepted_next_step_sha256=binding.next_step_artifact_sha256,
            accepted_next_step_vector_sha256=binding.next_step_vector_sha256,
            projected_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,projected_state))),
            prepared_state_sha256=prepared_state_sha,
            prepared_state=prepared_state,
            correction=(global_Bphi_columns=collect(Int,phi_columns),
                delta_Bphi_T=collect(Float64,delta_Bphi),profile_F_before_T_m=collect(Float64,projected_F),
                delta_Bphi_max_abs_T=maximum(abs,delta_Bphi;init=0.0),
                profile_F_before_max_abs_T_m=maximum(abs,projected_F;init=0.0),
                saved_Cphi_predicted_delta_Jn_max_abs_A_per_m2=
                    maximum(abs,action.Cphi_action.predicted_delta_A_per_m2;init=0.0)),
            maps=(native_n=action.native_map.n,domain_ndof=action.native_map.domain_ndof,
                current_operator_model_id=component.current_operator_model_id,
                source_operator_model_id=component.hagenow_source_operator_model_id,
                native_field_model_id=component.native_field_model_id,
                profile_F_row_ids=projected_F_row_ids,
                current_row_ids=Tuple(action.native_map.current_row_ids),
                current_row_indices=Tuple(action.native_map.current_row_indices),
                dynamic_span_row_range=Tuple(component.dynamic_span_row_range),
                dynamic_span_equation_ids=Tuple(component.dynamic_span_equation_ids),
                profile_span_columns=Tuple(component.profile_span_columns)),
            projected_geometry_signature=source_geometry,
        source_assembly_binding=source_assembly_binding,
            execution_scope=(live_geometry_calls=0,new_assembly_calls=0,kkt_solves=0,
                formal_acceptance=false,physical_validation=false,current_topology_decision=:hold))
        open(inputs_path,"w") do io;Serialization.serialize(io,inputs_raw);flush(io);end
        println("G2_BPHI_INPUTS_STAGE=raw_saved");flush(stdout)
        println("G2_ACTUAL_BPHI_RETRACTION_INPUTS_RAW path=",abspath(inputs_path),
            " prepared_state_sha256=",prepared_state_sha," grid_n=",action.native_map.n,
            " delta_Bphi_max_abs_T=",maximum(abs,delta_Bphi;init=0.0),
            " live_geometry_calls=0 assemblies=0 kkt_solves=0 formal_acceptance=false topology=hold")
        flush(stdout)
        return (status=:actual_bphi_retraction_inputs_only_saved,accepted_trial=nothing,
            trial_records=(),prepared_state_sha256=prepared_state_sha,
            bphi_retraction_inputs_path=inputs_path,formal_acceptance=false,physical_validation=false)
    end

    local_partition=merge(kkt_partition,(merit=projected_merit,))
    diagnostic.diagnostic_assembly.jacobian===nothing &&
        diagnostic.diagnostic_assembly.equality_jacobian===nothing ||
        error("Bphi retraction must use the released-operator actual-consumer context")
    consumer_result=_g2_actual_nonlinear_trial_consumer_v1(S,F,component,composed,provider,
        regional,diagnostic_model,scale_contract,local_partition,(step=correction,),
        projected_state,numeric_result_run_leaf,endpoint_rows,endpoint_ids,diagnostic;
        geometry_cache=nothing,max_alpha_power=0,min_alpha_power=0,
        projection_replay_binding=nothing,require_acceptance=false,apply_span_projection=false)
    trial_raw_path=joinpath(numeric_result_run_leaf,"result_data","g2_global_diagnostic",
        "actual_nonlinear_trial_raw_000_v1.jls")
    isfile(trial_raw_path) || error("actual Bphi consumer did not save its full trial assembly raw")
    trial_raw_sha=_g2_global_diag_result_file_sha256(trial_raw_path)
    trial_raw=open(Serialization.deserialize,trial_raw_path,"r")
    trial_raw.schema=="g2-global-diagnostic-actual-nonlinear-trial-raw-v1" &&
        trial_raw.state==corrected_state ||
        error("actual retraction assembly raw state/schema differs from requested Bphi-only correction")
    assembly=trial_raw.result.diagnostic_assembly
    trial_ids=collect(assembly.equation_ids.regional[1])
    assembly.status===:incomplete_assembly && assembly.claim_ceiling===:diagnostic_only &&
        assembly.physical_authority===false &&
        all(c->c.passed,assembly.jacobian_checks.regional) &&
        all(c->c.passed,assembly.jacobian_checks.outer) &&
        assembly.jacobian_checks.global_conservation.passed===true &&
        length(assembly.equation_ids.regional)==1 &&
        collect(assembly.equation_ids.regional[1])==collect(regional.equation_ids) &&
        length(assembly.equation_ids.outer)==1 &&
        collect(assembly.equation_ids.outer[1])==collect(composed.outer.constraint_ids) &&
        collect(assembly.equation_ids.conservation)==collect(provider.conservation_ids) &&
        trial_ids==projected_ids ||
        error("actual Bphi-corrected full assembly fails original row/oracle gates")
    println("G2_BPHI_INPUTS_STAGE=corrected_assembly_oracles_pass rows=",length(trial_ids));flush(stdout)
    actual_rows=Dict{eltype(trial_ids),Int}()
    sizehint!(actual_rows,length(trial_ids))
    for (i,id) in enumerate(trial_ids)
        actual_rows[id]=i
    end
    actual_F_row_ids=collect(action.native_map.profile_F_row_ids)
    actual_F=Vector{Float64}(undef,length(actual_F_row_ids))
    for (i,id) in enumerate(actual_F_row_ids)
        actual_F[i]=assembly.residual[actual_rows[id]]
    end
    actual_F_delta=actual_F.-projected_F
    expected_F_delta=radius.*delta_Bphi
    outer_ids_after=collect(assembly.equation_ids.outer[1])
    equality_ids_after=copy(outer_ids_after)
    append!(equality_ids_after,assembly.equation_ids.conservation)
    append!(equality_ids_after,component.dynamic_span_equation_ids)
    equality_ids_after==collect(eltype(equality_ids_after),kkt_partition.equality_row_ids) ||
        error("actual retraction equality row mapping differs")
    eq_map=Dict{eltype(equality_ids_after),Int}()
    sizehint!(eq_map,length(equality_ids_after))
    for (i,id) in enumerate(equality_ids_after)
        eq_map[id]=i
    end
    current_ids=collect(action.native_map.current_row_ids)
    current_indices=Vector{Int}(undef,length(current_ids))
    for (i,id) in enumerate(current_ids)
        current_indices[i]=eq_map[id]
    end
    current_indices==collect(Int,action.native_map.current_row_indices) ||
        error("actual retraction Jn row indices differ from the pinned saved map")
    actual_Jn=Float64[assembly.equality_residual[i] for i in current_indices]
    actual_delta_Jn=actual_Jn.-Float64.(collect(action.actual_Jn.projected_after_A_per_m2))
    predicted_delta_Jn=Float64.(collect(action.Cphi_action.predicted_delta_A_per_m2))
    current_scales=Float64.(collect(action.actual_Jn.row_scales_A_per_m2))
    length(actual_Jn)==length(actual_delta_Jn)==length(predicted_delta_Jn)==length(current_scales)==64 ||
        error("actual retraction does not provide all 64 scaled current rows")
    endpoint_residual=Float64[assembly.residual[i] for i in endpoint_rows]
    endpoint_tolerance=64eps(Float64)*max(1.0,maximum(abs,(
        source_geometry.psi_axis_Wb_per_rad,source_geometry.psi_boundary_Wb_per_rad);init=0.0))
    endpoint_gate=maximum(abs,endpoint_residual;init=0.0)<=endpoint_tolerance
    actual_ls=assembly.residual[Int[actual_rows[id] for id in ls_ids]]./
        collect(kkt_partition.least_squares_row_scales)
    actual_eq=vcat(assembly.equality_residual,assembly.residual[endpoint_rows])./
        collect(kkt_partition.equality_row_scales)
    actual_merit=0.5*(sum(abs2,actual_ls)+sum(abs2,actual_eq))
    trial_raw=nothing;assembly=nothing;actual_ls=nothing;actual_eq=nothing;GC.gc(true)
    geometry=Base.invokelatest(component.lcfs_dynamic_geometry_trace,corrected_state)
    geometry.status===:evaluated_dynamic_LCFS_geometry && geometry.mask_event===:unchanged ||
        error("fresh corrected-state geometry or core mask is not evaluated")
    corrected_geometry=(status=geometry.status,mask_event=geometry.mask_event,
        coordinates_RZ_m=Tuple(geometry.coordinates_RZ_m),normals_RZ=Tuple(geometry.normals_RZ),
        psi_axis_Wb_per_rad=Float64(geometry.psi_axis_Wb_per_rad),
        psi_boundary_Wb_per_rad=Float64(geometry.psi_boundary_Wb_per_rad),
        first_outward_crossing_signature=Tuple(geometry.first_outward_crossing_signature),
        psi_global_dof_ids=collect(Int,geometry.psi_global_dof_ids),
        ray_rule=geometry.ray_rule,field_model_id=geometry.field_model_id,
        field_representation=geometry.field_representation,
        source_critical_point_method=geometry.source_critical_point_method,
        source_critical_point_role=geometry.source_critical_point_role,
        source_fd_anchor_use=geometry.source_fd_anchor_use,
        jacobian_columns=geometry.jacobian_columns,fixed_PF_total_psi=geometry.fixed_PF_total_psi,
        solver_rows_added=geometry.solver_rows_added,global_topology_closed=geometry.global_topology_closed,
        physical_validation=geometry.physical_validation)
    println("G2_BPHI_INPUTS_STAGE=corrected_geometry_compacted");flush(stdout)
    same_geometry=isequal(source_geometry,corrected_geometry)
    geometry=nothing;GC.gc(true)
    pressure_valid(p,g)=p.status===:evaluated_dynamic_LCFS_pressure_only &&
        get(p,:pressure_row_count,0)==64 && length(p.pressure_residual)==64 &&
        all(isfinite,p.pressure_residual) && get(p,:candidate_hash,nothing)==component.candidate_hash &&
        get(p,:context_hash,nothing)==component.context_hash &&
        Tuple(p.dynamic_geometry.coordinates_RZ_m)==Tuple(g.coordinates_RZ_m) &&
        Tuple(p.dynamic_geometry.normals_RZ)==Tuple(g.normals_RZ)
    pressure_before=Base.invokelatest(component.lcfs_profile_current_trace,projected_state;
        pressure_only=true,dynamic_geometry=true,with_jacobian=false)
    pressure_before_valid=pressure_valid(pressure_before,source_geometry)
    pressure_before_max=pressure_before_valid ? maximum(abs,pressure_before.pressure_residual;init=0.0) : nothing
    pressure_before_status=get(pressure_before,:status,:typed_absent)
    pressure_before_residual=pressure_before_valid ? Tuple(pressure_before.pressure_residual) : nothing
    pressure_before=nothing;GC.gc(true)
    pressure_after=Base.invokelatest(component.lcfs_profile_current_trace,corrected_state;
        pressure_only=true,dynamic_geometry=true,with_jacobian=false)
    pressure_after_valid=pressure_valid(pressure_after,corrected_geometry)
    pressure_after_max=pressure_after_valid ? maximum(abs,pressure_after.pressure_residual;init=0.0) : nothing
    pressure_after_status=get(pressure_after,:status,:typed_absent)
    pressure_after_residual=pressure_after_valid ? Tuple(pressure_after.pressure_residual) : nothing
    pressure_after=nothing;GC.gc(true)
    pressure_tolerance_Pa=1.0e-8
    pressure_before_gate=pressure_before_valid && pressure_before_max<=pressure_tolerance_Pa
    pressure_after_gate=pressure_after_valid && pressure_after_max<=pressure_tolerance_Pa
    checks=(saved_action_state_binding=true,source_and_corrected_assembly_oracles=true,
        fresh_geometry_same_64_coordinate_normal_boundary_signature=same_geometry,all_64_current_rows=true,
        all_native_profile_F_rows=true,projected_pressure_trace=pressure_before_valid,
        retracted_pressure_trace=pressure_after_valid,finite_actual_merit=isfinite(actual_merit))
    raw=(schema=:actual_saved_bphi_retraction_consumer_numeric_v1,
        status=:actual_full_assembly_numeric_record_saved,action_sha256=action_sha,
        trial_raw_path=abspath(trial_raw_path),trial_raw_sha256=trial_raw_sha,
        next_step_sha256=next_step_sha,projected_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,projected_state))),
        retracted_state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,corrected_state))),
        correction=(global_Bphi_columns=phi_columns,delta_Bphi_T=delta_Bphi,
            profile_F_before_T_m=projected_F,profile_F_after_T_m=actual_F,
            predicted_profile_F_delta_T_m=expected_F_delta,actual_profile_F_delta_T_m=actual_F_delta),
        current=(row_ids=current_ids,baseline_projected_A_per_m2=action.actual_Jn.projected_after_A_per_m2,
            actual_retracted_A_per_m2=actual_Jn,actual_delta_A_per_m2=actual_delta_Jn,
            saved_Cphi_predicted_delta_A_per_m2=predicted_delta_Jn,row_scales_A_per_m2=current_scales),
        merit=(before=projected_merit,after=actual_merit,reduction=projected_merit-actual_merit),
        endpoints=(row_ids=Tuple(endpoint_ids),residual_Wb_per_rad=endpoint_residual,
            tolerance_Wb_per_rad=endpoint_tolerance,gate=endpoint_gate,strict_merit_decrease=actual_merit<projected_merit),
        geometry=(before_RZ_m=source_geometry.coordinates_RZ_m,after_RZ_m=corrected_geometry.coordinates_RZ_m,
            before_normals=source_geometry.normals_RZ,after_normals=corrected_geometry.normals_RZ,
            before_axis_psi_Wb_per_rad=source_geometry.psi_axis_Wb_per_rad,
            after_axis_psi_Wb_per_rad=corrected_geometry.psi_axis_Wb_per_rad,
            before_boundary_psi_Wb_per_rad=source_geometry.psi_boundary_Wb_per_rad,
            after_boundary_psi_Wb_per_rad=corrected_geometry.psi_boundary_Wb_per_rad,
            same_64_coordinate_normal_boundary_signature=same_geometry),
        pressure=(before_status=pressure_before_status,after_status=pressure_after_status,
            before_residual_Pa=pressure_before_residual,
            after_residual_Pa=pressure_after_residual,
            before_max_residual_Pa=pressure_before_max,after_max_residual_Pa=pressure_after_max,
            acceptance_tolerance_Pa=pressure_tolerance_Pa,
            before_original_final_gate=pressure_before_gate,after_original_final_gate=pressure_after_gate),
        consumer_status=consumer_result.status,consumer_trial_records=consumer_result.trial_records,
        checks=checks,evidence_ceiling=:actual_same_state_retraction_diagnostic,
        physical_validation=false,formal_acceptance=false,current_topology_decision=:hold)
    outpath=joinpath(numeric_result_run_leaf,"result_data","g2_global_diagnostic",
        "actual_saved_bphi_retraction_consumer_numeric_v1.jls")
    ispath(outpath) && error("refusing to overwrite Bphi retraction numeric result")
    open(outpath,"w") do io;Serialization.serialize(io,raw);flush(io);end
    println("G2_BPHI_INPUTS_STAGE=consumer_numeric_raw_saved");flush(stdout)
    println("G2_ACTUAL_BPHI_RETRACTION_RAW path=",abspath(outpath),
        " sha256=",_g2_global_diag_result_file_sha256(outpath),
        " actual_merit_before=",projected_merit," actual_merit_after=",actual_merit,
        " Jn_max_before=",maximum(abs,action.actual_Jn.projected_after_A_per_m2),
        " Jn_max_after=",maximum(abs,actual_Jn)," endpoint_gate=",endpoint_gate,
        " geometry_signature_same=",same_geometry," pressure_before=",pressure_before_max,
        " pressure_after=",pressure_after_max," physical_validation=false topology=hold")
    flush(stdout)
    all(values(checks)) || error("actual Bphi retraction numeric record failed a source/oracle/geometry/pressure binding")
    (status=:actual_bphi_retraction_diagnostic_completed,accepted_trial=nothing,
        trial_records=consumer_result.trial_records,kkt_partition=local_partition,
        retraction_raw_path=outpath,physical_validation=false,formal_acceptance=false)
end

Base.@noinline Base.@nospecializeinfer function _g2_resume_saved_trial_next_kkt_consumer_v1(
        S,F,component,trace,provider,composed,regional,diagnostic_model,
        candidate_scaling,scale_contract,run_leaf)
    Base.@nospecialize S F component trace provider composed regional diagnostic_model candidate_scaling scale_contract run_leaf
    baseline_path=get(ENV,"FUSION_G2_NEXT_TRIAL_BASELINE_RAW_PATH","")
    baseline_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_BASELINE_RAW_SHA256",""))
    baseline_report_path=get(ENV,"FUSION_G2_NEXT_TRIAL_BASELINE_REPORT_PATH","")
    baseline_report_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_BASELINE_REPORT_SHA256",""))
    kkt_path=get(ENV,"FUSION_G2_NEXT_TRIAL_KKT_RAW_PATH","")
    kkt_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_KKT_RAW_SHA256",""))
    geometry_path=get(ENV,"FUSION_G2_NEXT_TRIAL_GEOMETRY_RAW_PATH","")
    geometry_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_GEOMETRY_RAW_SHA256",""))
    bphi_baseline_mode=get(ENV,"FUSION_G2_NEXT_TRIAL_BPHI_RETRACTION_BASELINE","0")=="1"
    bphi_inputs_path=get(ENV,"FUSION_G2_NEXT_TRIAL_BPHI_INPUTS_RAW_PATH","")
    bphi_inputs_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_BPHI_INPUTS_RAW_SHA256",""))
    required_paths=bphi_baseline_mode ? (baseline_path,baseline_report_path,kkt_path,bphi_inputs_path) :
        (baseline_path,baseline_report_path,kkt_path,geometry_path)
    all(p->!isempty(p)&&isfile(p),required_paths) ||
        error("next-trial baseline, report, KKT, and required source raws are missing")
    required_hashes=bphi_baseline_mode ? (baseline_sha,baseline_report_sha,kkt_sha,bphi_inputs_sha) :
        (baseline_sha,baseline_report_sha,kkt_sha,geometry_sha)
    all(h->occursin(r"^[0-9a-f]{64}$",h),required_hashes) ||
        error("next-trial saved input SHA pins are malformed")
    numeric_pins=bphi_baseline_mode ?
        ((baseline_path,baseline_sha),(baseline_report_path,baseline_report_sha),
         (kkt_path,kkt_sha),(bphi_inputs_path,bphi_inputs_sha)) :
        ((baseline_path,baseline_sha),(baseline_report_path,baseline_report_sha),
         (kkt_path,kkt_sha),(geometry_path,geometry_sha))
    all(p->_g2_global_diag_result_file_sha256(p[1])==p[2],numeric_pins) ||
        error("next-trial saved input digest mismatch")
    out=joinpath(run_leaf,"result_data","g2_global_diagnostic");mkpath(out)
    baseline_raw=open(Serialization.deserialize,baseline_path,"r")
    baseline_raw.schema=="g2-global-diagnostic-actual-nonlinear-trial-raw-v1"&&
        baseline_raw.trial_index==(bphi_baseline_mode ? 0 : 6)&&
        baseline_raw.alpha==(bphi_baseline_mode ? 1.0 : 1.0/64.0) ||
        error("next-trial baseline raw does not match the selected accepted source state")
    baseline_state=collect(Float64,baseline_raw.state)
    length(baseline_state)==69_447&&all(isfinite,baseline_state) ||
        error("next-trial baseline state shape/values differ")
    baseline_state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,baseline_state)))
    baseline_report=open(Serialization.deserialize,baseline_report_path,"r")
    bphi_inputs=nothing;bphi_baseline_merit=nothing;bphi_action_sha=nothing
    if bphi_baseline_mode
        bphi_inputs=open(Serialization.deserialize,bphi_inputs_path,"r")
        bphi_inputs.schema===:actual_saved_bphi_retraction_inputs_v1&&
            bphi_inputs.status===:actual_bphi_retraction_inputs_only_saved&&
            length(bphi_inputs.prepared_state)==69_447&&
            bphi_inputs.prepared_state_sha256==baseline_state_sha&&
            bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(bphi_inputs.prepared_state))))==baseline_state_sha ||
            error("Bphi prepared input does not exactly bind the new baseline state")
        baseline_report.schema===:actual_saved_bphi_retraction_consumer_numeric_v1&&
            baseline_report.status===:actual_full_assembly_numeric_record_saved&&
            baseline_report.trial_raw_path==abspath(baseline_path)&&
            baseline_report.trial_raw_sha256==baseline_sha&&
            baseline_report.retracted_state_sha256==baseline_state_sha&&
            baseline_report.action_sha256==bphi_inputs.action_sha256&&
            baseline_report.consumer_status===:accepted&&
            length(baseline_report.consumer_trial_records)==1&&
            baseline_report.consumer_trial_records[1].alpha==1.0&&
            baseline_report.consumer_trial_records[1].status===:accepted&&
            baseline_report.geometry.same_64_coordinate_normal_boundary_signature===true&&
            baseline_report.endpoints.gate===true&&
            baseline_report.pressure.after_original_final_gate===true&&
            baseline_report.merit.after<baseline_report.merit.before&&
            all(values(baseline_report.checks)) ||
            error("Bphi accepted baseline consumer report does not bind state, oracles, geometry, endpoints and pressure")
        length(bphi_inputs.maps.current_row_ids)==64&&
            length(bphi_inputs.maps.current_row_indices)==64&&
            length(bphi_inputs.maps.profile_F_row_ids)==16_641&&
            bphi_inputs.maps.native_n==16_641&&bphi_inputs.maps.domain_ndof==69_447&&
            bphi_inputs.maps.current_operator_model_id===component.current_operator_model_id&&
            bphi_inputs.maps.source_operator_model_id===component.hagenow_source_operator_model_id&&
            bphi_inputs.maps.native_field_model_id===component.native_field_model_id ||
            error("Bphi baseline action maps differ from the producer native/current dimensions or identities")
        bphi_baseline_merit=Float64(baseline_report.merit.after)
        bphi_action_sha=baseline_report.action_sha256
    else
        baseline_report.schema=="saved-baseline-gs-u-minus-fd-trial-report-v1"&&
            baseline_report.trial.status===:accepted&&baseline_report.saved_step_reused===true&&
            baseline_report.kkt_rerun===false&&baseline_report.trial.accepted_trial.alpha==1.0/64.0&&
            baseline_report.trial.accepted_trial.state==Tuple(baseline_state)&&
            baseline_report.trial.accepted_trial.endpoint_final_gate===false&&
            baseline_report.trial.accepted_trial.pressure_final_gate===true ||
            error("next-trial baseline report acceptance/state/final-gate binding differs")
        geometry=open(Serialization.deserialize,geometry_path,"r")
        geometry.schema=="saved-step-dynamic-geometry-raw-v1"&&geometry.alpha==1.0/64.0&&
            geometry.state==baseline_state&&geometry.state_sha256==baseline_state_sha&&
            geometry.pre_geometry_state_guard_passed===true&&
            geometry.geometry_result.status===:evaluated_dynamic_LCFS_geometry&&
            geometry.geometry_result.mask_event===:unchanged ||
            error("next-trial baseline accepted geometry state/mask binding differs")
    end
    geometry=nothing;baseline_report=nothing;GC.gc(false)
    assembly=baseline_raw.result.diagnostic_assembly
    baseline_raw.result.status===:typed_absent&&
        baseline_raw.result.missing_closures==S._REQUIRED_CLOSURES&&
        assembly.status===:incomplete_assembly&&assembly.claim_ceiling===:diagnostic_only&&
        assembly.physical_authority===false&&assembly.residual_scaling===:frozen_row_scales ||
        error("next-trial baseline raw claim/oracle scope differs")
    all(c->c.passed,assembly.jacobian_checks.regional)&&
        all(c->c.passed,assembly.jacobian_checks.outer)&&
        assembly.jacobian_checks.global_conservation.passed ||
        error("next-trial baseline actual regional/outer/conservation oracle failed")
    assembly.equilibrium_row_scales==scale_contract.equilibrium.characteristics&&
        assembly.equilibrium_row_scale_hash==string(F.canonical_hash(scale_contract.equilibrium.characteristics)) ||
        error("next-trial baseline frozen equilibrium scales differ from live contract")
    row_ownership_ok=length(assembly.equation_ids.regional)==1&&length(assembly.equation_ids.outer)==1&&
        collect(assembly.equation_ids.regional[1])==collect(regional.equation_ids)&&
        collect(assembly.equation_ids.outer[1])==collect(composed.outer.constraint_ids)&&
        collect(assembly.equation_ids.conservation)==collect(provider.conservation_ids)
    row_ownership_ok||error("next-trial baseline row ownership differs from the live producer")
    length(component.dynamic_span_row_range)==length(component.dynamic_span_equation_ids)==2 ||
        error("next-trial endpoint row ABI differs")
    endpoint_rows=Int.(collect(component.dynamic_span_row_range))
    endpoint_ids=Tuple(component.dynamic_span_equation_ids)
    Tuple(assembly.equation_ids.regional[1][i] for i in endpoint_rows)==endpoint_ids ||
        error("next-trial baseline actual endpoint rows differ")
    r4_path=joinpath(@__DIR__,"..","runs","e",
        "up2_continuous_psi_global_numeric_capture_20261012_r4","preoracle_checkpoint",
        "result_data","g2_global_diagnostic","numeric_matrices_v3.jls")
    capture_sha="c1ff9d51a43632fffe0b35fab0280db2faf9589dc2aa3603490b04bb78183bec"
    capture=_g2_global_diag_reload_matrices(r4_path;expected_sha256=capture_sha)
    meta=capture.replay_metadata;identity=meta.consumer_identity
    meta.validation_stage===:pre_global_assembler_oracles_pending&&
        identity.scope===:diagnostic_incomplete_global_assembly ||
        error("next-trial baseline numeric identity is outside the pinned R4 diagnostic scope")
    all(k->hasproperty(identity,k),(:candidate_hash,:trace_hash,:current_operator_model_id,
        :hagenow_source_operator_model_id,:provider_id,:component_context_hash,
        :scale_contract_hash,:scale_policy)) || error("next-trial R4 semantic identity is incomplete")
    identity.candidate_hash==component.candidate_hash&&identity.trace_hash==trace.trace_hash&&
        identity.current_operator_model_id===component.current_operator_model_id&&
        identity.hagenow_source_operator_model_id===component.hagenow_source_operator_model_id&&
        identity.provider_id==diagnostic_model.provider_id&&
        identity.component_context_hash==component.context_hash&&
        identity.scale_contract_hash==scale_contract.contract_hash&&
        identity.scale_policy===scale_contract.scale_policy ||
        error("next-trial R4 semantic identity differs from the live producer")
    collect(meta.ordered_ids.least_squares_raw)==collect(regional.equation_ids)&&
        collect(meta.ordered_ids.equality_base)==collect(scale_contract.equalities.row_ids)&&
        collect(meta.ordered_ids.endpoint)==collect(endpoint_ids)&&
        collect(meta.endpoint_row_indices)==endpoint_rows&&
        collect(meta.pressure_indices)==collect(i for i in component.pressure_dofs if i>0) ||
        error("next-trial R4 ordered rows/pressure map differ from the live component")
    Tuple(capture.least_squares_row_scales)==Tuple(assembly.equilibrium_row_scales)&&
        Tuple(capture.equality_row_scales)==Tuple(scale_contract.equalities.characteristics)&&
        Tuple(capture.column_scales)==Tuple(candidate_scaling.column_scales) ||
        error("next-trial R4 frozen row/column scales differ from live producer")
    capture=nothing;GC.gc(false)
    kkt_raw=open(Serialization.deserialize,kkt_path,"r")
    kkt_raw.schema=="actual-saved-trial-next-kkt-step-raw-v1"&&
        kkt_raw.input_trial_path==baseline_path&&kkt_raw.input_trial_sha256==baseline_sha&&
        kkt_raw.old_r4_capture_sha256==capture_sha&&kkt_raw.state==baseline_state&&
        kkt_raw.state_sha256==baseline_state_sha ||
        error("next-trial new-step raw is not exactly bound to the accepted saved trial")
    if bphi_baseline_mode
        bphi_binding=get(kkt_raw,:bphi_retraction_binding,nothing)
        bphi_binding!==nothing&&kkt_raw.input_trial_kind===:actual_bphi_retracted_trial&&
            bphi_binding.inputs_raw_path==bphi_inputs_path&&
            bphi_binding.inputs_raw_sha256==bphi_inputs_sha&&
            bphi_binding.consumer_raw_path==baseline_report_path&&
            bphi_binding.consumer_raw_sha256==baseline_report_sha&&
            bphi_binding.trial_raw_sha256==baseline_sha&&
            bphi_binding.prepared_state_sha256==baseline_state_sha&&
            bphi_binding.action_sha256==bphi_action_sha&&
            bphi_binding.endpoint_gate===true&&bphi_binding.pressure_gate===true&&
            bphi_binding.merit_after==bphi_baseline_merit ||
            error("new KKT raw is not bound to this exact Bphi action, accepted report and state")
    end
    step=kkt_raw.step
    step.status===:ok&&step.original_kkt_gate===true&&step.true_kkt_gate===true&&
        step.true_kkt_relative_defect<=1e-8&&step.stationarity<=1e-6&&
        step.pressure_bound_gate===true&&step.dual_gate===true&&
        step.dual_violation<=1e-6&&step.complementarity<=1e-6&&
        step.pressure_lower_bound_violation<=1e-6&&step.schur_rank==step.schur_dimension&&
        step.rank_certificate===:not_established_for_full_G&&step.full_global_kkt===false ||
        error("next-trial new KKT step fails its original stationarity/true-KKT/bounds/Schur gates")
    step.state_before==baseline_state&&Tuple(step.column_scales)==Tuple(candidate_scaling.column_scales)&&
        Tuple(step.pressure_indices)==Tuple(i for i in component.pressure_dofs if i>0) ||
        error("next-trial KKT state/column/pressure map differs from the accepted saved trial")
    step_vector=Float64.(collect(step.step))
    length(step_vector)==length(baseline_state)&&all(isfinite,step_vector) ||
        error("next-trial KKT numeric step shape/values differ")
    new_step_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,step_vector)))
    span_projection_flag=get(ENV,"FUSION_G2_TRIAL_EXACT_SPAN_RESTORE","0")
    span_projection_flag in ("0","1") || error("exact-span trial restoration flag must be 0 or 1")
    minimum_alpha_power=0;maximum_alpha_power=12
    projection_replay_binding=nothing;bphi_baseline_binding=nothing
    if span_projection_flag=="1" && bphi_baseline_mode
        hasproperty(component,:profile_span_columns) &&
            Tuple(component.profile_span_columns)==(69_446,69_447) ||
            error("Bphi exact-span trial projection requires the actual producer's appended span DOFs")
        projection_replay_binding=(kind=:actual_bphi_retraction_next_kkt,
            baseline_raw_path=baseline_path,baseline_raw_sha256=baseline_sha,
            baseline_report_path=baseline_report_path,baseline_report_sha256=baseline_report_sha,
            bphi_inputs_path=bphi_inputs_path,bphi_inputs_sha256=bphi_inputs_sha,
            kkt_raw_path=kkt_path,kkt_raw_sha256=kkt_sha,
            baseline_state_sha256=baseline_state_sha,new_step_sha256=new_step_sha,
            new_step_alpha_schedule=:bounded_dyadic_0_to_12)
        bphi_baseline_binding=(baseline_trial_index=0,baseline_alpha=1.0,
            baseline_state_sha256=baseline_state_sha,baseline_merit=bphi_baseline_merit,
            bphi_inputs_sha256=bphi_inputs_sha,bphi_consumer_sha256=baseline_report_sha,
            kkt_raw_sha256=kkt_sha)
    elseif span_projection_flag=="1"
        hasproperty(component,:profile_span_columns) &&
            Tuple(component.profile_span_columns)==(69_446,69_447) ||
            error("exact-span replay requires the actual producer's two appended profile-span columns")
        replay_raw_path=get(ENV,"FUSION_G2_NEXT_TRIAL_UNPROJECTED_ACCEPTED_RAW_PATH","")
        replay_raw_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_UNPROJECTED_ACCEPTED_RAW_SHA256",""))
        replay_report_path=get(ENV,"FUSION_G2_NEXT_TRIAL_UNPROJECTED_REPORT_PATH","")
        replay_report_sha=lowercase(get(ENV,"FUSION_G2_NEXT_TRIAL_UNPROJECTED_REPORT_SHA256",""))
        all(p->!isempty(p)&&isfile(p),(replay_raw_path,replay_report_path)) &&
            all(h->occursin(r"^[0-9a-f]{64}$",h),(replay_raw_sha,replay_report_sha)) ||
            error("exact-span replay requires pinned accepted raw and report files")
        _g2_global_diag_result_file_sha256(replay_raw_path)==replay_raw_sha &&
            _g2_global_diag_result_file_sha256(replay_report_path)==replay_report_sha ||
            error("exact-span replay accepted raw/report digest mismatch")
        replay_report=open(Serialization.deserialize,replay_report_path,"r")
        replay_report.schema=="actual-saved-trial-next-kkt-nonlinear-trial-report-v1" &&
            replay_report.status===:accepted && replay_report.trial_status===:accepted &&
            replay_report.baseline_state_sha256==baseline_state_sha &&
            replay_report.new_kkt_step_sha256==new_step_sha &&
            replay_report.accepted_trial!==nothing &&
            replay_report.accepted_trial.endpoint_final_gate===false &&
            replay_report.accepted_trial.pressure_final_gate===true ||
            error("exact-span replay report is not the accepted unprojected same-step endpoint failure")
        accepted_alpha=Float64(replay_report.accepted_trial.alpha)
        alpha_power=Int(round(-log2(accepted_alpha)))
        0<=alpha_power<=12 && accepted_alpha==0.5^alpha_power ||
            error("exact-span replay accepted alpha is not an original bounded dyadic trial")
        expected_unprojected_state=baseline_state.+accepted_alpha.*step_vector
        accepted_report_state=Float64.(collect(replay_report.accepted_trial.state))
        length(accepted_report_state)==length(expected_unprojected_state) &&
            accepted_report_state==expected_unprojected_state &&
            basename(replay_raw_path)=="actual_nonlinear_trial_raw_$(lpad(string(alpha_power),3,'0'))_v1.jls" ||
            error("exact-span replay report/raw alpha or state differs from the same baseline plus new step")
        projection_replay_binding=(raw_path=replay_raw_path,raw_sha256=replay_raw_sha,
            report_path=replay_report_path,report_sha256=replay_report_sha,
            alpha=accepted_alpha,alpha_power=alpha_power,
            state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,accepted_report_state))))
        minimum_alpha_power=alpha_power;maximum_alpha_power=alpha_power
        println("G2_EXACT_SPAN_ACCEPTED_ALPHA_REPLAY_BOUND alpha=",accepted_alpha,
            " alpha_power=",alpha_power," state_sha256=",projection_replay_binding.state_sha256,
            " raw_sha256=",replay_raw_sha," report_sha256=",replay_report_sha,
            " only_alpha=true");flush(stdout)
        replay_report=nothing;accepted_report_state=nothing;expected_unprojected_state=nothing;GC.gc(false)
    end
    projection_input_preflight=span_projection_flag=="1" &&
        get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")=="1"
    if projection_input_preflight
        result=(status=:abi_preflight,accepted_trial=nothing,trial_records=(),
            exact_span_replay_input_preflight=!bphi_baseline_mode,
            bphi_retraction_baseline_preflight=bphi_baseline_mode ? bphi_baseline_binding : nothing,
            projection_replay_binding=projection_replay_binding,
            profile_span_columns=Tuple(component.profile_span_columns),
            baseline_assembly_repeated=false,geometry_calls=0,kkt_rerun=false)
        raw_result_path=joinpath(out,"saved_trial_next_kkt_consumer_return_raw_v1.jls")
        ispath(raw_result_path)&&error("refusing to overwrite projection replay input-preflight raw result")
        open(raw_result_path,"w") do io;Serialization.serialize(io,result);flush(io);end
        report=(schema="actual-saved-trial-next-kkt-nonlinear-trial-report-v1",
            status=:abi_preflight,baseline_state_sha256=baseline_state_sha,
            new_kkt_step_sha256=new_step_sha,baseline_merit=nothing,
            trial_status=:abi_preflight,accepted_trial=nothing,trial_records=(),
            consumer_return_raw_path=raw_result_path,abi_preflight_only=true,
            exact_span_replay_input_preflight=!bphi_baseline_mode,
            bphi_retraction_baseline_preflight=bphi_baseline_mode ? bphi_baseline_binding : nothing,
            profile_span_columns=Tuple(component.profile_span_columns),
            minimum_alpha_power=minimum_alpha_power,maximum_alpha_power=maximum_alpha_power,
            unprojected_accepted_trial_replay=bphi_baseline_mode ? nothing : projection_replay_binding,
            projection_origin_binding=bphi_baseline_mode ? projection_replay_binding : nothing,
            baseline_or_trial_assembly_repeated=false,kkt_rerun=false,
            previous_endpoint_gate=bphi_baseline_mode ? true : false,
            formal_acceptance=false,science_credit=false,
            closure_credit=false,physical_validation=false)
        report_path=joinpath(out,"saved_trial_next_kkt_nonlinear_trial_report_v1.jls")
        ispath(report_path)&&error("refusing to overwrite projection replay input-preflight report")
        open(report_path,"w") do io;Serialization.serialize(io,report);flush(io);end
        if bphi_baseline_mode
            println("G2_BPHI_NEXT_TRIAL_CONSUMER_ABI_PREFLIGHT_PASS baseline_state_sha256=",baseline_state_sha,
                " new_step_sha256=",new_step_sha," baseline_trial_index=0 baseline_alpha=1.0",
                " profile_span_columns=69446,69447 report_path=",report_path,
                " geometry_calls=0 full_assembly=false kkt_solve=false");flush(stdout)
        else
            println("G2_EXACT_SPAN_REPLAY_INPUT_PREFLIGHT_PASS alpha=",projection_replay_binding.alpha,
                " alpha_power=",projection_replay_binding.alpha_power,
                " baseline_state_sha256=",baseline_state_sha," new_step_sha256=",new_step_sha,
                " report_path=",report_path," geometry_calls=0 full_assembly=false kkt_solve=false");flush(stdout)
        end
        return result
    end
    all(i->baseline_state[i]>=0.0,Tuple(i for i in component.pressure_dofs if i>0))&&
        all(k->baseline_state[4k-2]>0.0,eachindex(component.core_mask)) ||
        error("next-trial baseline violates the original pressure/Bphi preguard")
    expected_partition_hash=kkt_raw.partition_hash
    expected_partition_merit=kkt_raw.baseline_merit
    kkt_raw=nothing
    raw_assembly=assembly
    residual=Float64.(raw_assembly.residual);equality_residual=Float64.(raw_assembly.equality_residual)
    J=raw_assembly.jacobian;C=raw_assembly.equality_jacobian
    row_ids=Tuple(raw_assembly.equation_ids.regional[1])
    base_eq_ids=(Tuple(raw_assembly.equation_ids.outer[1])...,
        Tuple(raw_assembly.equation_ids.conservation)...)
    ls_rows=Int.(collect(meta.least_squares_row_indices));endpoint_set=Set(endpoint_rows)
    part_eq_rows=(base_eq_ids...,endpoint_ids...)
    Tuple(row_ids)==Tuple(meta.ordered_ids.least_squares_raw)&&
        size(J)==(68_934,69_447)&&size(C)==(577,69_447)&&
        length(residual)==68_934&&length(equality_residual)==577&&
        Tuple(ls_rows)==Tuple(i for i in eachindex(residual) if !(i in endpoint_set)) ||
        error("next-trial baseline R/J/C/c dimensions or exact row positions differ")
    ls_ids=Tuple(row_ids[i] for i in ls_rows)
    ls_scales=Float64[raw_assembly.equilibrium_row_scales[i] for i in ls_rows]
    eq_scales=vcat(collect(Float64.(scale_contract.equalities.characteristics)),
        Float64[raw_assembly.equilibrium_row_scales[i] for i in endpoint_rows])
    eq_residual=vcat(equality_residual,Float64[residual[i] for i in endpoint_rows])
    eq_jacobian=[C;J[endpoint_rows,:]]
    part=S.weighted_residual_kkt_partition_v1(candidate_hash=identity.candidate_hash,
        consumer_identity=identity,least_squares_row_ids=ls_ids,
        least_squares_residual=residual[ls_rows],least_squares_jacobian=J[ls_rows,:],
        least_squares_row_scales=ls_scales,equality_row_ids=part_eq_rows,
        equality_row_scales=eq_scales,equality_residual=eq_residual,equality_jacobian=eq_jacobian)
    length(part.least_squares_row_ids)==68_932&&length(part.equality_row_ids)==579&&
        part.partition_hash==expected_partition_hash&&
        abs(part.merit-expected_partition_merit)<=64eps(Float64)*max(1.0,expected_partition_merit) ||
        error("next-trial baseline reconstructed partition does not match the KKT step input")
    bphi_baseline_mode && abs(part.merit-bphi_baseline_merit)>
        64eps(Float64)*max(1.0,bphi_baseline_merit) &&
        error("new Bphi baseline partition merit differs from the accepted physical diagnostic report")
    baseline_merit=part.merit
    part=merge(part,(raw_least_squares_jacobian=nothing,raw_equality_jacobian=nothing,
        scaled_least_squares_jacobian=nothing,equality_jacobian=nothing))
    raw_assembly=nothing;assembly=nothing;baseline_raw=nothing;J=nothing;C=nothing
    residual=nothing;equality_residual=nothing;ls_scales=nothing;eq_scales=nothing
    eq_residual=nothing;eq_jacobian=nothing;GC.gc(true)
    diagnostic=(diagnostic_assembly=(jacobian=nothing,equality_jacobian=nothing,),)
    preflight_only=get(ENV,"FUSION_G2_SAVED_MINUS_TRIAL_ABI_PREFLIGHT_ONLY","0")=="1"
    geometry_reuse=get(ENV,"FUSION_G2_SAVED_GEOMETRY_RAW_REUSE","0")
    geometry_replay=get(ENV,"FUSION_G2_SAVED_GEOMETRY_RAW_REPLAY_PREFLIGHT_ONLY","0")
    geometry_replay=="0"||error("new KKT direction cannot replay cached geometry from the prior step")
    geometry_reuse=="0"||error("new KKT direction cannot reuse cached geometry from the prior step")
    preflight_only||geometry_reuse in ("0","1")||error("invalid geometry reuse flag")
    println("G2_SAVED_TRIAL_NEXT_STEP_BOUND state_sha256=",baseline_state_sha,
        " step_sha256=",new_step_sha," baseline_merit=",baseline_merit,
        " geometry_cache=false alpha_powers=",minimum_alpha_power,":",maximum_alpha_power,
        " assembly_before_consumer=false kkt_rerun=false");flush(stdout)
    bphi_retraction_mode=get(ENV,"FUSION_G2_BPHI_RETRACTION_CONSUMER","0")
    bphi_retraction_mode in ("0","1") || error("actual Bphi retraction consumer flag must be 0 or 1")
    result=if bphi_retraction_mode=="1"
        _g2_actual_bphi_retraction_consumer_v1(S,F,component,composed,provider,regional,
            diagnostic_model,scale_contract,part,step,baseline_state,run_leaf,
            endpoint_rows,endpoint_ids,diagnostic)
    else
        _g2_actual_nonlinear_trial_consumer_v1(S,F,component,composed,provider,regional,
            diagnostic_model,scale_contract,part,step,baseline_state,run_leaf,
            endpoint_rows,endpoint_ids,diagnostic;geometry_cache=nothing,
            max_alpha_power=maximum_alpha_power,min_alpha_power=minimum_alpha_power,
            projection_replay_binding=projection_replay_binding,
            apply_span_projection=bphi_baseline_mode ? true : nothing)
    end
    raw_result_path=joinpath(out,"saved_trial_next_kkt_consumer_return_raw_v1.jls")
    ispath(raw_result_path)&&error("refusing to overwrite next-trial consumer raw result")
    open(raw_result_path,"w") do io;Serialization.serialize(io,result);flush(io);end
    result_status=get(result,:status,:unknown)
    accepted_trial=get(result,:accepted_trial,nothing)
    trial_records=get(result,:trial_records,())
    report=(schema="actual-saved-trial-next-kkt-nonlinear-trial-report-v1",
        status=result_status,baseline_state_sha256=baseline_state_sha,
        new_kkt_step_sha256=new_step_sha,baseline_merit=baseline_merit,
        trial_status=result_status,accepted_trial=accepted_trial,
        trial_records=trial_records,consumer_return_raw_path=raw_result_path,
        abi_preflight_only=preflight_only,geometry_cache_used=false,
        minimum_alpha_power=minimum_alpha_power,maximum_alpha_power=maximum_alpha_power,
        unprojected_accepted_trial_replay=bphi_baseline_mode ? nothing : projection_replay_binding,
        projection_origin_binding=bphi_baseline_mode ? projection_replay_binding : nothing,
        baseline_or_trial_assembly_repeated=false,kkt_rerun=false,
        previous_endpoint_gate=bphi_baseline_mode ? true : false,
        formal_acceptance=false,science_credit=false,
        closure_credit=false,physical_validation=false)
    report_path=joinpath(out,"saved_trial_next_kkt_nonlinear_trial_report_v1.jls")
    ispath(report_path)&&error("refusing to overwrite next-trial nonlinear report")
    open(report_path,"w") do io;Serialization.serialize(io,report);flush(io);end
    println("G2_SAVED_TRIAL_NEXT_STEP_TRIAL status=",result_status,
        " accepted_alpha=",accepted_trial===nothing ? nothing : accepted_trial.alpha,
        " endpoint_gate=",accepted_trial===nothing ? nothing : accepted_trial.endpoint_final_gate,
        " report_path=",report_path," geometry_cache=false assembly_repeated=false kkt_rerun=false");flush(stdout)
    result
end
