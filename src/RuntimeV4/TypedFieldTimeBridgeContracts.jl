"""Sealed contracts for the D3 candidate-bound field/time obligation bridge.

The bridge records two independent screen-level executions. It never claims
that the lumped DAE trajectory drives the static field program.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TFTB_REVISION = "d3-v1"
const _TFTB_TOKEN = Val(:typed_field_time_bridge_private)

struct FieldTimeMaterializationV4
    candidate::CandidateStatePackageV4
    compiled::CompiledCandidatePrefixV4
    mechanism_genome::MechanismGenomeV4
    field_geometry_genome::FieldGeometryGenomeV4
    realization_control_genome::RealizationControlGenomeV4
    mission_payload::Any
    bounds_payload::Any
    minimality_scope::MinimalityScopeV4
    candidate_hash::Digest256
    prefix_hash::Digest256
    genome_bundle_hash::Digest256
    mechanism_hash::Digest256
    field_geometry_hash::Digest256
    realization_control_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    minimality_scope_hash::Digest256
    d2_scenario_hash::Digest256
    g2_scenario_hash::Digest256
    scenario_relationship::Symbol
    d2_initialization_plan_hash::Digest256
    d2_initialization_report_hash::Digest256
    d2_initialization_artifact_hash::Digest256
    d2_initialization_evidence_id::Digest256
    d2_time_plan_hash::Digest256
    d2_time_report_hash::Digest256
    d2_time_artifact_hash::Digest256
    d2_time_evidence_id::Digest256
    g2_plan_hash::Digest256
    g2_report_hash::Digest256
    g2_component_status::Symbol
    g2_unresolved_gaps::Tuple{Vararg{String}}
    g2_result_hash::Union{Nothing,Digest256}
    g2_subject_hash::Union{Nothing,Digest256}
    g2_solver_input_hash::Union{Nothing,Digest256}
    g2_evidence_id::Union{Nothing,Digest256}
    g2_provider_manifest_hash::Union{Nothing,Digest256}
    g2_support_hash::Digest256
    g2_chart_hash::Digest256
    g2_coordinate_map_hash::Digest256
    g2_metric_hash::Digest256
    g2_program_hash::Digest256
    g2_root_hash::Digest256
    g2_grid_hash::Digest256
    g2_parameter_hashes::Tuple{Vararg{Digest256}}
    g2_operator_manifest_bindings::Tuple
    materialization_hash::Digest256
    function FieldTimeMaterializationV4(
            token::Val{:typed_field_time_bridge_private}, fields...)
        token === _TFTB_TOKEN ||
            throw(ArgumentError("private D3 materialization constructor"))
        new(fields...)
    end
end

FieldTimeMaterializationV4(args...) =
    throw(ArgumentError("FieldTimeMaterializationV4 is sealed; use build_typed_field_time_bridge"))

function _tftb_materialization_identity(x::FieldTimeMaterializationV4)
    (revision=_TFTB_REVISION, candidate=x.candidate, compiled=x.compiled,
     mechanism_genome=x.mechanism_genome,
     field_geometry_genome=x.field_geometry_genome,
     realization_control_genome=x.realization_control_genome,
     mission_payload=x.mission_payload, bounds_payload=x.bounds_payload,
     minimality_scope=x.minimality_scope, candidate_hash=x.candidate_hash,
     prefix_hash=x.prefix_hash, genome_bundle_hash=x.genome_bundle_hash,
     mechanism_hash=x.mechanism_hash, field_geometry_hash=x.field_geometry_hash,
     realization_control_hash=x.realization_control_hash,
     mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
     minimality_scope_hash=x.minimality_scope_hash,
     d2_scenario_hash=x.d2_scenario_hash, g2_scenario_hash=x.g2_scenario_hash,
     scenario_relationship=x.scenario_relationship,
     d2_initialization_plan_hash=x.d2_initialization_plan_hash,
     d2_initialization_report_hash=x.d2_initialization_report_hash,
     d2_initialization_artifact_hash=x.d2_initialization_artifact_hash,
     d2_initialization_evidence_id=x.d2_initialization_evidence_id,
     d2_time_plan_hash=x.d2_time_plan_hash,
     d2_time_report_hash=x.d2_time_report_hash,
     d2_time_artifact_hash=x.d2_time_artifact_hash,
     d2_time_evidence_id=x.d2_time_evidence_id,
     g2_plan_hash=x.g2_plan_hash, g2_report_hash=x.g2_report_hash,
     g2_component_status=x.g2_component_status,
     g2_unresolved_gaps=x.g2_unresolved_gaps,
     g2_result_hash=x.g2_result_hash,
     g2_subject_hash=x.g2_subject_hash,
     g2_solver_input_hash=x.g2_solver_input_hash,
     g2_evidence_id=x.g2_evidence_id,
     g2_provider_manifest_hash=x.g2_provider_manifest_hash,
     g2_support_hash=x.g2_support_hash, g2_chart_hash=x.g2_chart_hash,
     g2_coordinate_map_hash=x.g2_coordinate_map_hash,
     g2_metric_hash=x.g2_metric_hash, g2_program_hash=x.g2_program_hash,
     g2_root_hash=x.g2_root_hash, g2_grid_hash=x.g2_grid_hash,
     g2_parameter_hashes=x.g2_parameter_hashes,
     g2_operator_manifest_bindings=x.g2_operator_manifest_bindings)
end

semantic_view(x::FieldTimeMaterializationV4) =
    merge(_tftb_materialization_identity(x),
          (materialization_hash=x.materialization_hash,))

function canonical_hash(x::FieldTimeMaterializationV4)
    hash = canonical_hash(_tftb_materialization_identity(x))
    hash == x.materialization_hash ||
        throw(ArgumentError("D3 materialization tampered"))
    hash
end

struct FieldTimeBridgeReportV4
    materialization::FieldTimeMaterializationV4
    status::Symbol
    field_time_executable::Bool
    field_time_artifact::Nothing
    merged_metrics::Nothing
    component_evidence_ids::Tuple{Vararg{Digest256}}
    unresolved_gaps::Tuple{Vararg{UnresolvedStageDeclarationV4}}
    claim_ceiling::ClaimCeiling
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    report_hash::Digest256
    function FieldTimeBridgeReportV4(
            token::Val{:typed_field_time_bridge_private}, fields...)
        token === _TFTB_TOKEN ||
            throw(ArgumentError("private D3 report constructor"))
        new(fields...)
    end
end


FieldTimeBridgeReportV4(args...) =
    throw(ArgumentError("FieldTimeBridgeReportV4 is sealed; use build_typed_field_time_bridge"))

function _tftb_report_identity(x::FieldTimeBridgeReportV4)
    (revision=_TFTB_REVISION,
     materialization_hash=canonical_hash(x.materialization),
     status=x.status, field_time_executable=x.field_time_executable,
     field_time_artifact=x.field_time_artifact,
     merged_metrics=x.merged_metrics,
     component_evidence_ids=x.component_evidence_ids,
     unresolved_gaps=x.unresolved_gaps, claim_ceiling=x.claim_ceiling,
     credible_physical_candidate_count=x.credible_physical_candidate_count,
     p5_ready=x.p5_ready, unsupported_emitted=x.unsupported_emitted)
end

semantic_view(x::FieldTimeBridgeReportV4) =
    merge(_tftb_report_identity(x), (report_hash=x.report_hash,))

function canonical_hash(x::FieldTimeBridgeReportV4)
    x.status === :terminal_deferred ||
        throw(ArgumentError("D3 status must remain terminal_deferred"))
    !x.field_time_executable && x.field_time_artifact === nothing &&
        x.merged_metrics === nothing ||
        throw(ArgumentError("D3 cannot contain a field-time execution artifact"))
    x.claim_ceiling === none && x.credible_physical_candidate_count == 0 &&
        !x.p5_ready && !x.unsupported_emitted ||
        throw(ArgumentError("D3 promotion firewall violated"))
    hash = canonical_hash(_tftb_report_identity(x))
    hash == x.report_hash || throw(ArgumentError("D3 report tampered"))
    hash
end
