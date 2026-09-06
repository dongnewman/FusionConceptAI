using Test
using Pkg
Pkg.activate(joinpath(@__DIR__,".."))
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeResidual.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeRefinement.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeEvents.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeExecutionContracts.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeExecution.jl"))
using .FusionRuntimeV4
const ProviderManifestV4=FusionRuntimeV4.ProviderManifestV4
const ExecutablePhysicalSubjectV4=FusionRuntimeV4.ExecutablePhysicalSubjectV4
const SolverInputV4=FusionRuntimeV4.SolverInputV4
const TypedTimeResidualReportV4=FusionRuntimeV4.TypedTimeResidualReportV4
const TypedTimeExecutionPlanV4=FusionRuntimeV4.TypedTimeExecutionPlanV4
const TypedTimeExecutionReceiptV4=FusionRuntimeV4.TypedTimeExecutionReceiptV4
include(joinpath(@__DIR__,"..","examples","runtime_v4_typed_time_execution_fixture.jl"))

@testset "D1.3 typed execution" begin
 for (p,r) in ((texec_plan_continuous,texec_continuous_report),(texec_plan_refinement,texec_refinement_report),(texec_plan_event,texec_event_report))
  @test p.operation in (:continuous,:three_level_refinement,:single_threshold_event)
  @test p.provider isa ProviderManifestV4 && p.provider.executor===nothing
  @test p.provider.capability.operator == String(p.operation)
  @test p.subject isa ExecutablePhysicalSubjectV4 && p.input isa SolverInputV4
  @test r isa TypedTimeResidualReportV4 && r.claim_ceiling===screen_only
  @test r.credible_physical_candidate_count==0 && !r.p5_ready && !r.unsupported_emitted
  @test validate_typed_time_report(p,r)
 end
 @test length(texec_store.execution_counts)==3
 @test texec_store.execution_counts[texec_plan_continuous.input.solver_input_hash]==1
 @test cache_typed_time_execution(texec_store,texec_plan_continuous) === texec_continuous_report
 @test texec_store.execution_counts[texec_plan_continuous.input.solver_input_hash]==1
 @test replay_typed_time_execution(texec_plan_event,texec_event_report)
 @test replay_typed_time_execution(texec_plan_continuous,texec_continuous_report)
 @test replay_typed_time_execution(texec_plan_refinement,texec_refinement_report)
 for (p,r) in ((texec_plan_continuous,texec_continuous_report),(texec_plan_refinement,texec_refinement_report),(texec_plan_event,texec_event_report))
  before=texec_store.execution_counts[p.input.solver_input_hash]
  @test execute_once!(texec_store,p.input,p.provider,p)===r
  @test texec_store.execution_counts[p.input.solver_input_hash]==before==1
 end
 missing_store=TypedTimeExecutionStoreV4()
 missing=execute_once!(missing_store,texec_plan_continuous.input,nothing,texec_plan_continuous)
 @test missing.numerical_status===:terminal_deferred && missing.evidence.claim_ceiling===none
 @test missing.artifact===nothing && isempty(missing_store.reports)
 local_provider=texec_plan_continuous.provider
 foreign_provider=ProviderManifestV4(local_provider.schema,local_provider.revision,local_provider.kind,local_provider.capability,local_provider.domain,local_provider.backend,"foreign",local_provider.code_hash,local_provider.independence_group,local_provider.claim_ceiling;input_schema_hash=local_provider.input_schema_hash,executor=nothing)
 @test_throws ArgumentError execute_once!(TypedTimeExecutionStoreV4(),texec_plan_continuous.input,foreign_provider,texec_plan_continuous)
 foreign_input=SolverInputV4(texec_plan_continuous.input.physical_subject_hash,digest256_text("foreign-scenario"),texec_plan_continuous.input.provider_manifest_hash,texec_plan_continuous.input.input_schema_hash,texec_plan_continuous.input.payload)
 @test_throws ArgumentError execute_once!(TypedTimeExecutionStoreV4(),foreign_input,texec_plan_continuous.provider,texec_plan_continuous)
 @test_throws ArgumentError compile_typed_time_execution_plan(ttr_compiled,ttr_registry,ttr_scenario;operation=:continuous,residual_plan=nothing)
 @test_throws ArgumentError compile_typed_time_execution_plan(ttr_compiled,ttr_registry,ttr_scenario;operation=:three_level_refinement,residual_plan=ttr_plan)
 polluted=deepcopy(texec_store); key=(texec_plan_continuous.input.solver_input_hash,texec_continuous_report.receipt.artifact_hash); polluted.artifacts[key]=nothing
 @test_throws ArgumentError cache_typed_time_execution(polluted,texec_plan_continuous)
 count_only=TypedTimeExecutionStoreV4(); count_only.execution_counts[texec_plan_continuous.input.solver_input_hash]=1
 @test_throws ArgumentError execute_once!(count_only,texec_plan_continuous.input,texec_plan_continuous.provider,texec_plan_continuous)
 artifact_only=TypedTimeExecutionStoreV4(); artifact_only.artifacts[key]=texec_continuous_report.artifact
 @test_throws ArgumentError execute_once!(artifact_only,texec_plan_continuous.input,texec_plan_continuous.provider,texec_plan_continuous)
 report_without_count=deepcopy(texec_store); delete!(report_without_count.execution_counts,texec_plan_continuous.input.solver_input_hash)
 @test_throws ArgumentError execute_once!(report_without_count,texec_plan_continuous.input,texec_plan_continuous.provider,texec_plan_continuous)
 @test_throws ArgumentError cache_typed_time_execution(report_without_count,texec_plan_continuous)
 # Rehashing a coordinated trajectory/receipt/evidence/report mutation must
 # still fail because trajectory provenance is derived from the artifact.
 tr=texec_continuous_report.trajectory
 tr2=FusionRuntimeV4.TypedTimeTrajectoryV4(FusionRuntimeV4._TEXEC_TOKEN,
      tr.physical_subject_hash,tr.solver_input_hash,tr.execution_plan_hash,tr.scenario_hash,
      tr.result_hash,tr.status,(tr.times[1],tr.times[2]+1.0),tr.states,tr.event_hashes,
      tr.mass_residual_norm,tr.trajectory_defect_norm,tr.residual_norm,
      canonical_hash((revision=FusionRuntimeV4._TEXEC_REVISION,physical_subject=tr.physical_subject_hash,
       solver_input=tr.solver_input_hash,execution_plan=tr.execution_plan_hash,scenario=tr.scenario_hash,
       result=tr.result_hash,status=tr.status,times=(tr.times[1],tr.times[2]+1.0),states=tr.states,
       event_hashes=tr.event_hashes,mass_residual_norm=tr.mass_residual_norm,
       trajectory_defect_norm=tr.trajectory_defect_norm,residual_norm=tr.residual_norm)))
 e2=FusionRuntimeV4._texec_evidence(texec_plan_continuous,texec_continuous_report.artifact,tr2,pass)
 rc3=texec_continuous_report.receipt
 rc4=TypedTimeExecutionReceiptV4(FusionRuntimeV4._TEXEC_TOKEN,rc3.invocation_hash,rc3.solver_input_hash,
      rc3.provider_manifest_hash,rc3.execution_plan_hash,rc3.physical_subject_hash,rc3.scenario_hash,
      rc3.operation,rc3.status,rc3.failure_code,rc3.failure_reason,rc3.artifact_hash,canonical_hash(tr2),
      e2.evidence_id,rc3.execution_count,canonical_hash((revision=FusionRuntimeV4._TEXEC_REVISION,
       invocation=rc3.invocation_hash,solver_input=rc3.solver_input_hash,provider=rc3.provider_manifest_hash,
       execution_plan=rc3.execution_plan_hash,physical_subject=rc3.physical_subject_hash,
       scenario=rc3.scenario_hash,operation=rc3.operation,status=rc3.status,failure_code=rc3.failure_code,
       failure_reason=rc3.failure_reason,artifact=rc3.artifact_hash,trajectory=canonical_hash(tr2),
       evidence=e2.evidence_id,execution_count=rc3.execution_count)))
 bad2=TypedTimeResidualReportV4(FusionRuntimeV4._TEXEC_TOKEN,texec_continuous_report.artifact,tr2,e2,rc4,
      texec_continuous_report.numerical_status,texec_continuous_report.unresolved_gaps,
      texec_continuous_report.executed_scope,texec_continuous_report.unexecuted_scopes,screen_only,0,false,false,
      digest256_text("draft"))
 bad2=TypedTimeResidualReportV4(FusionRuntimeV4._TEXEC_TOKEN,bad2.artifact,bad2.trajectory,bad2.evidence,bad2.receipt,
      bad2.numerical_status,bad2.unresolved_gaps,bad2.executed_scope,bad2.unexecuted_scopes,screen_only,0,false,false,
      canonical_hash(FusionRuntimeV4._texec_report_identity(bad2)))
 @test_throws ArgumentError validate_typed_time_report(texec_plan_continuous,bad2)
 rc=texec_continuous_report.receipt
 rc2=TypedTimeExecutionReceiptV4(FusionRuntimeV4._TEXEC_TOKEN,rc.invocation_hash,rc.solver_input_hash,rc.provider_manifest_hash,rc.execution_plan_hash,rc.physical_subject_hash,rc.scenario_hash,rc.operation,rc.status,rc.failure_code,rc.failure_reason,rc.artifact_hash,rc.trajectory_hash,rc.evidence_id,rc.execution_count+1,canonical_hash((revision=FusionRuntimeV4._TEXEC_REVISION,invocation=rc.invocation_hash,solver_input=rc.solver_input_hash,provider=rc.provider_manifest_hash,execution_plan=rc.execution_plan_hash,physical_subject=rc.physical_subject_hash,scenario=rc.scenario_hash,operation=rc.operation,status=rc.status,failure_code=rc.failure_code,failure_reason=rc.failure_reason,artifact=rc.artifact_hash,trajectory=rc.trajectory_hash,evidence=rc.evidence_id,execution_count=rc.execution_count+1)))
 draft=TypedTimeResidualReportV4(FusionRuntimeV4._TEXEC_TOKEN,texec_continuous_report.artifact,texec_continuous_report.trajectory,texec_continuous_report.evidence,rc2,texec_continuous_report.numerical_status,texec_continuous_report.unresolved_gaps,texec_continuous_report.executed_scope,texec_continuous_report.unexecuted_scopes,screen_only,0,false,false,digest256_text("draft"))
 bad_report=TypedTimeResidualReportV4(FusionRuntimeV4._TEXEC_TOKEN,draft.artifact,draft.trajectory,draft.evidence,rc2,draft.numerical_status,draft.unresolved_gaps,draft.executed_scope,draft.unexecuted_scopes,screen_only,0,false,false,canonical_hash(FusionRuntimeV4._texec_report_identity(draft)))
 @test_throws ArgumentError validate_typed_time_report(texec_plan_continuous,bad_report)
 @test typed_time_execution_manifest().operations==(:continuous,:three_level_refinement,:single_threshold_event)
 @test typed_time_execution_manifest().claim_ceiling===screen_only
 @test_throws Exception TypedTimeExecutionPlanV4(:bad,texec_plan_continuous.operation,texec_plan_continuous.compiled,texec_plan_continuous.registry,texec_plan_continuous.subject,texec_plan_continuous.input,texec_plan_continuous.provider,texec_plan_continuous.scenario,texec_plan_continuous.residual_plan,nothing,nothing,texec_plan_continuous.source_hash,texec_plan_continuous.authority_hash,texec_plan_continuous.plan_hash)
 @test_throws KeyError cache_typed_time_execution(TypedTimeExecutionStoreV4(),texec_plan_event)
end
