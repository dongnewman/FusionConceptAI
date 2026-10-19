using Serialization, SHA, JSON3, LinearAlgebra

length(ARGS)==6 || error("expected current numeric input, KKT trial input, baseline, field sampler, saved production result, output dir")
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))
include(joinpath(ROOT, "examples", "runtime_v4_freegs_axisymmetric_execution.jl"))
const F=FreeGSAxisymmetricRuntime
Base.include(F,joinpath(ROOT, "src", "RuntimeV4", "CandidateCoupledPhysicsV4.jl"))
Base.include(F,joinpath(ROOT, "src", "RuntimeV4", "DeclaredCrossMeshConservativeTransferExecutionV1.jl"))

const INPUTS=NamedTuple{(:current,:input,:baseline,:field,:production)}(
    Tuple(abspath(ARGS[i]) for i in 1:5))
all(isfile,values(INPUTS)) || error("missing pinned actual C771 remesh input")
function pin(path)
    (path=path,bytes=filesize(path),sha256=bytes2hex(open(SHA.sha256,path)))
end
PINS=NamedTuple{keys(INPUTS)}(Tuple(pin(p) for p in values(INPUTS)))
current,trial_input,baseline,field,production=(open(deserialize,p) for p in values(INPUTS))
trial_input.schema===:saved_actual_D_trial_input_v1 &&
    trial_input.status===:qualified_saved_C771_numeric_KKT_metadata_ABI ||
    error("saved actual D trial ABI differs")
trial_input.state_record.state_coordinate_id===:native_F_defect_T_m_v1 &&
    length(trial_input.state_record.state)==69447 || error("saved KKT state record coordinate/shape differs")
baseline.schema===:x3_full_duffy_primal_partition_numeric_v1 &&
    baseline.status===:numeric_saved_before_postchecks || error("saved baseline ABI differs")
trial_input.binding.baseline_state_sha256==baseline.source_state_sha256 ||
    error("saved trial input and full64 baseline state do not join")
field.schema=="actual-field-sampler-numeric-inputs-v1" || error("actual field sampler ABI differs")
production.schema===:x3_full_duffy_C771_actual_trial_production_result_v1 &&
    production.status===:numeric_saved_before_postchecks &&
    production.formal_acceptance===false && production.physical_validation===false ||
    error("saved 69c3 production result ABI differs")
for name in (:current,:input,:baseline,:field)
    hasproperty(production.source_pins,name) || error("saved trial lacks input pin $name")
    expected=getproperty(production.source_pins,name); actual=getproperty(PINS,name)
    normpath(abspath(expected.path))==normpath(actual.path) && expected.bytes==actual.bytes &&
        expected.sha256==actual.sha256 || error("saved 69c3 result does not bind exact $name input")
end
state=collect(Float64,production.state)
state_sha=bytes2hex(SHA.sha256(reinterpret(UInt8,state)))
state_sha==production.trial_state_sha256=="69c3bdbc3c2b1840fff5d935428e8b4e8b5b68dd8f5502d2c51dac1af39be7da" ||
    error("actual 69c3 trial state hash differs")
production.state_coordinate_id===:native_F_defect_T_m_v1 || error("actual source is not in D coordinates")
production.dynamic_geometry.status===:evaluated_dynamic_LCFS_geometry &&
    production.dynamic_geometry.mask_event===:unchanged ||
    error("saved 69c3 dynamic geometry is not evaluated with unchanged topology")

current_numeric=current.provider_numeric_inputs.lcfs_current_numeric_data
domain0=current_numeric.state_domain
domain1=merge(domain0,(toroidal_coordinate=:native_F_defect_T_m_v1,))
gd=merge(field.sampler_numeric_data.geometry_data,
    (toroidal_coordinate=:native_F_defect_T_m_v1,toroidal_geometry_domain=domain1,))
domain=merge(domain1,(dynamic_geometry_data=gd,))
for key in (:Raxis,:Zaxis,:mask,:pressure_dofs,:nr,:nz,:n)
    hasproperty(domain0.dynamic_geometry_data,key) && hasproperty(field.sampler_numeric_data.geometry_data,key) ||
        error("actual provider/sampler geometry ABI misses $key")
    getproperty(domain0.dynamic_geometry_data,key)==getproperty(field.sampler_numeric_data.geometry_data,key) ||
        error("current-provider and field-sampler $key do not exactly join")
end
identity=field.current_numeric_data.trace_identity
for key in (:candidate_hash,:context_hash,:trace_hash,:upstream_output_hash)
    string(getproperty(identity,key))==string(getproperty(current.source_identity,key)) ||
        error("provider/source identity differs at $key")
end
domain.native_field_model_id===field.sampler_numeric_data.model_id ||
    error("native field model differs from the actual sampler provider")
domain.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1 ||
    error("actual C771 provider is outside the declared native model")
nr,nz=domain.dynamic_geometry_data.nr,domain.dynamic_geometry_data.nz
nr==129 && nz==129 && domain.n==16641 && count(domain.mask)==2879 && domain.ndof==69447 &&
    domain.dynamic_profile_span===true && domain.vary_profile_coefficients===true &&
    length(domain.span_columns)==2 && length(domain.coefficient_columns)==2 &&
    length(state)==domain.ndof || error("actual 69c3 state/domain shape or topology ABI differs")

# The target chart is the nested 65x65 restriction of the same candidate's
# accepted provider chart.  Its mask is explicitly restricted from that exact
# provider mask; no new physical boundary is invented or borrowed.
rid=collect(1:2:nr); zid=collect(1:2:nz)
Rt=domain.dynamic_geometry_data.Raxis[rid]
Zt=domain.dynamic_geometry_data.Zaxis[zid]
target_mask=Tuple(domain.mask[(i-1)*nz+j] for i in rid for j in zid)
length(Rt)==65 && length(Zt)==65 || error("nested target axes do not form 65x65")
gauge_anchor=(R_m=first(Rt),Z_m=first(Zt),psi_Wb_per_rad=state[4])
candidate_identity=(candidate_hash=string(identity.candidate_hash),
    context_hash=string(identity.context_hash),trace_hash=string(identity.trace_hash),
    upstream_output_hash=string(identity.upstream_output_hash),state_sha256=state_sha)
out=abspath(ARGS[6]); mkpath(out)
mode=get(ENV,"UP2_C771_REMAP_MODE","execute")
mode in ("abi_only","execute") || error("UP2_C771_REMAP_MODE must be abi_only or execute")
abi_path=joinpath(out,"actual_C771_69c3_remesh_abi_manifest_v1.json")
if mode=="abi_only"
    ispath(abi_path) && error("refuse to overwrite actual remesh ABI manifest")
    manifest=(schema="actual-C771-axisymmetric-remesh-ABI-v1",status="passed_actual_provider_domain_and_saved_state_ABI",
        five_input_pins=PINS,candidate_identity=candidate_identity,state_coordinate=string(production.state_coordinate_id),
        state_sha256=state_sha,source_state=(ndof=domain.ndof,n=domain.n,grid=(nr,nz),core_nodes=count(domain.mask),
            pressure_dofs=count(>(0),domain.pressure_dofs),profile_coefficients=domain.coefficient_columns,
            dynamic_span_columns=domain.span_columns),
        provider_sampler_join=(Raxis=true,Zaxis=true,mask=true,pressure_dofs=true,nr=true,nz=true,n=true),
        native_field_model_id=string(domain.native_field_model_id),
        saved_dynamic_geometry=(status=string(production.dynamic_geometry.status),
            mask_event=string(production.dynamic_geometry.mask_event),
            axis_RZ_m=production.dynamic_geometry.axis_RZ_m,
            boundary_RZ_m=production.dynamic_geometry.boundary_RZ_m,
            psi_axis_Wb_per_rad=production.dynamic_geometry.psi_axis_Wb_per_rad,
            psi_boundary_Wb_per_rad=production.dynamic_geometry.psi_boundary_Wb_per_rad),
        target_chart=(shape=(length(Rt),length(Zt)),core_nodes=count(target_mask),
            construction="nested restriction of same candidate provider chart and mask"),
        gauge_anchor=gauge_anchor,remap_started=false,formal_acceptance=false,claim_ceiling="screen_only")
    write(abi_path,JSON3.write(manifest))
    println("UP2_C771_ACTUAL_REMESH_ABI status=passed_actual_provider_domain_and_saved_state_ABI pins=5 remap_started=false output=",abi_path)
    exit(0)
end
mapped=F.declared_axisymmetric_remesh_v1(domain,state,Rt,Zt,target_mask;
    candidate_identity=candidate_identity,gauge_anchor=gauge_anchor,
    expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
    profile_evaluator=(target_data,target_state)->
        F._ccp_full_native_profile_evaluate(target_data,target_state))
mapped.status===:evaluated_screen_only || error("actual candidate remesh/evaluator failed: $(mapped)")
mapped.evaluation.status===:evaluated_full_native_F_and_core_pressure_rows ||
    error("original C771 profile evaluator did not run on remeshed target")
mapped.receipt.downstream_consumer.status===mapped.evaluation.status &&
    mapped.receipt.downstream_consumer.consumed_state_sha256==mapped.receipt.target_state_hash &&
    mapped.receipt.downstream_consumer.acceptance===:diagnostics_only_thresholds_unfrozen ||
    error("remapped state was not bound to an explicit downstream consumer result")
roundtrip=F.declared_axisymmetric_remesh_v1(mapped.domain,mapped.state,
    domain.dynamic_geometry_data.Raxis,domain.dynamic_geometry_data.Zaxis,Tuple(domain.mask);
    candidate_identity=candidate_identity,
    gauge_anchor=gauge_anchor,
    expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
    profile_evaluator=(target_data,target_state)->
        F._ccp_full_native_profile_evaluate(target_data,target_state))
roundtrip.status===:evaluated_screen_only &&
    roundtrip.evaluation.status===:evaluated_full_native_F_and_core_pressure_rows ||
    error("same-candidate actual 65x65-to-129x129 mergeback/profile evaluation failed")
roundtrip.receipt.downstream_consumer.status===roundtrip.evaluation.status &&
    roundtrip.receipt.downstream_consumer.consumed_state_sha256==roundtrip.receipt.target_state_hash &&
    roundtrip.receipt.downstream_consumer.acceptance===:diagnostics_only_thresholds_unfrozen ||
    error("mergeback state was not bound to an explicit downstream consumer result")
length(roundtrip.state)==domain.ndof || error("actual mergeback state dimension differs from source provider")

state_path=joinpath(out,"actual_C771_69c3_to_nested65_state_v1.json")
mergeback_path=joinpath(out,"actual_C771_nested65_to_69c3_chart_mergeback_v1.json")
receipt_path=joinpath(out,"actual_C771_69c3_to_nested65_remesh_receipt_v1.json")
all(!ispath,(state_path,mergeback_path,receipt_path)) || error("refuse to overwrite prior actual remesh outputs")
write(state_path,JSON3.write(mapped.state))
write(mergeback_path,JSON3.write(roundtrip.state))
receipt=(schema="actual-C771-axisymmetric-remesh-v1",status="evaluated_screen_only",
    source_state_sha256=state_sha,source_pins=PINS,candidate_identity=candidate_identity,
    source_provider_chart=(shape=(nr,nz),core_nodes=count(domain.mask),
        native_field_model_id=string(domain.native_field_model_id)),
    target_chart=(shape=(length(Rt),length(Zt)),R_m=Rt,Z_m=Zt,mask=target_mask,
        construction=:nested_restriction_of_same_candidate_provider_chart),
    gauge_anchor=gauge_anchor,transfer=mapped.receipt,
    mergeback=(status=roundtrip.status,source_chart=(65,65),target_chart=(129,129),
        target_mask_nodes=count(domain.mask),evaluator_status=roundtrip.evaluation.status,
        residual_norm=norm(roundtrip.evaluation.residual),consumer=roundtrip.receipt.downstream_consumer,
        receipt=roundtrip.receipt,
        state_path=basename(mergeback_path),state_sha256=bytes2hex(open(SHA.sha256,mergeback_path))),
    evaluator=(status=mapped.evaluation.status,residual_norm=norm(mapped.evaluation.residual),
        residual_count=length(mapped.evaluation.residual),state_coordinate=:native_F_defect_T_m_v1),
    downstream_consumer=mapped.receipt.downstream_consumer,
    source_profile_current_and_divergence=mapped.receipt,
    external_domain=(status=:typed_absent,reason=:no_candidate_bound_vacuum_or_far_field_provider_in_this_entry),
    acceptance_gates=(pressure_volume_energy=:threshold_unfrozen,
        magnetic_gauge=:threshold_unfrozen,axisymmetric_divB=:threshold_unfrozen,
        plasma_current_Ip=:threshold_unfrozen),
    target_state_path=basename(state_path),target_state_sha256=bytes2hex(open(SHA.sha256,state_path)),
    solver_execution=:not_executed,formal_acceptance=false,physical_validation=false,
    global_topology_closed=false,claim_ceiling=:screen_only)
write(receipt_path,JSON3.write(receipt))
println("UP2_C771_ACTUAL_AXISYMMETRIC_REMESH status=evaluated_screen_only source_state_sha256=",
    state_sha," source_grid=129x129 target_grid=65x65 profile_residual_norm=",
    receipt.evaluator.residual_norm," output=",receipt_path)
