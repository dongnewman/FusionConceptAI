"""Fail-closed candidate-bound validation admission and UQ records."""

_vuq_text(x, field) = x isa AbstractString && !isempty(strip(String(x))) ? String(x) : throw(ArgumentError("$field must be non-empty"))
_vuq_digest(x::Digest256) = x
_vuq_digest(x::AbstractString) = length(String(x)) == 64 ? Digest256(String(x)) : throw(ArgumentError("$x must be a validated Digest256"))

struct GenomeIdentityV4
    genome_kind::Symbol; genome_hash::Digest256; typed_ast_hash::Digest256; operator_hypergraph_hash::Digest256
    function GenomeIdentityV4(kind::Symbol, genome_hash::Digest256, ast::Digest256, graph::Digest256)
        kind in (:mechanism, :field_geometry, :realization_control) || throw(ArgumentError("invalid genome kind")); new(kind, genome_hash, ast, graph)
    end
end
semantic_view(x::GenomeIdentityV4) = (genome_kind=x.genome_kind, genome_hash=x.genome_hash, typed_ast_hash=x.typed_ast_hash, operator_hypergraph_hash=x.operator_hypergraph_hash)

struct ValidationBindingV4
    candidate_hash::Digest256; subject_hash::Digest256; scenario_hash::Digest256; observable_hash::Digest256
    genome_identities::NTuple{3,GenomeIdentityV4}; binding_hash::Digest256
    function ValidationBindingV4(::Val{:validated}, candidate, subject, scenario, observable, genomes, binding)
        new(candidate, subject, scenario, observable, genomes, binding)
    end
end
semantic_view(x::ValidationBindingV4) = (candidate_hash=x.candidate_hash, subject_hash=x.subject_hash, scenario_hash=x.scenario_hash, observable_hash=x.observable_hash, genome_identities=x.genome_identities)

"""Derive a binding from frozen Runtime artifacts; no hash-only constructor exists."""
function ValidationBindingV4(candidate::CandidateStatePackageV4, subject::ExecutablePhysicalSubjectV4, scenario::Digest256, observable::Digest256, genomes::NTuple{3,GenomeIdentityV4})
    subject.genome_bundle_hash == candidate.canonical_hashes.genome_bundle_hash || throw(ArgumentError("subject is not bound to candidate Genome bundle"))
    subject.mission_hash == candidate.mission_contract_ref.canonicalization_hash || throw(ArgumentError("subject mission does not bind candidate"))
    Set(g.genome_kind for g in genomes) == Set((:mechanism,:field_geometry,:realization_control)) || throw(ArgumentError("three Genome identities are required"))
    expected=Dict(:mechanism=>candidate.canonical_hashes.mechanism_hash,:field_geometry=>candidate.canonical_hashes.field_geometry_hash,:realization_control=>candidate.canonical_hashes.realization_control_hash)
    all(g.genome_hash==expected[g.genome_kind] for g in genomes) || throw(ArgumentError("Genome identity is not candidate-bound")); scenario in subject.scenarios || throw(ArgumentError("scenario is not present in executable subject"))
    body=(candidate_hash=candidate.canonical_hashes.genome_bundle_hash,subject_hash=subject.physical_subject_hash,scenario_hash=scenario,observable_hash=observable,genome_identities=genomes); ValidationBindingV4(Val(:validated),body...,canonical_hash(body))
end

struct ApplicabilityEnvelopeV4
    domain::NamedTuple; evaluated::Bool; within_domain::Bool
    function ApplicabilityEnvelopeV4(domain::NamedTuple; evaluated::Bool=false, within_domain::Bool=false)
        isempty(domain) && throw(ArgumentError("applicability domain cannot be empty")); evaluated || within_domain && throw(ArgumentError("applicability must be evaluated before admission")); new(domain,evaluated,within_domain)
    end
end
semantic_view(x::ApplicabilityEnvelopeV4)=(domain=x.domain,evaluated=x.evaluated,within_domain=x.within_domain)

struct ProvenanceV4
    source_uri::String; dataset_id::String; record_hash::Digest256; partition::String; license::String; method::String
    function ProvenanceV4(uri,dataset,record_hash::Digest256,partition,license,method)
        u=_vuq_text(uri,"source_uri"); occursin("example.test",u) && throw(ArgumentError("synthetic example source is not physical evidence")); new(u,_vuq_text(dataset,"dataset_id"),record_hash,_vuq_text(partition,"dataset partition"),_vuq_text(license,"license"),_vuq_text(method,"method"))
    end
end
semantic_view(x::ProvenanceV4)=(source_uri=x.source_uri,dataset_id=x.dataset_id,record_hash=x.record_hash,partition=x.partition,license=x.license,method=x.method)

struct ObservableDatumV4
    name::Symbol; value::Float64; standard_uncertainty::Float64; unit::UnitSignature
    function ObservableDatumV4(name::Symbol,value::Real,uncertainty::Real,unit::UnitSignature=UnitSignature())
        v,u=Float64(value),Float64(uncertainty); isfinite(v)&&isfinite(u)&&u>0 || throw(ArgumentError("observable value/uncertainty must be finite and positive")); new(name,v,u,unit)
    end
end
semantic_view(x::ObservableDatumV4)=(name=x.name,value=x.value,standard_uncertainty=x.standard_uncertainty,unit=x.unit)

struct ComparisonProtocolV4
    metric::Symbol; tolerance::Float64; denominator::Float64
    function ComparisonProtocolV4(metric::Symbol,tolerance::Real;denominator::Real=1.0)
        t,d=Float64(tolerance),Float64(denominator); isfinite(t)&&t>=0&&isfinite(d)&&d>0 || throw(ArgumentError("invalid comparison protocol")); new(metric,t,d)
    end
end
semantic_view(x::ComparisonProtocolV4)=(metric=x.metric,tolerance=x.tolerance,denominator=x.denominator)

struct PredictionArtifactV4
    binding_hash::Digest256; datum::ObservableDatumV4; provider_hash::Digest256; result_hash::Digest256
    function PredictionArtifactV4(binding::ValidationBindingV4,datum::ObservableDatumV4,provider::Digest256,result::Digest256)
        new(binding.binding_hash,datum,provider,result)
    end
end
semantic_view(x::PredictionArtifactV4)=(binding_hash=x.binding_hash,datum=x.datum,provider_hash=x.provider_hash,result_hash=x.result_hash)

struct ComparisonResultV4
    predicted::ObservableDatumV4; observed::ObservableDatumV4; protocol::ComparisonProtocolV4; normalized_discrepancy::Float64; accepted::Bool
    function ComparisonResultV4(predicted,observed,protocol::ComparisonProtocolV4)
        predicted.name==observed.name&&predicted.unit==observed.unit || throw(ArgumentError("observable comparison binding mismatch")); n=abs(predicted.value-observed.value)/protocol.denominator; new(predicted,observed,protocol,n,n<=protocol.tolerance)
    end
end
semantic_view(x::ComparisonResultV4)=(predicted=x.predicted,observed=x.observed,protocol=x.protocol,normalized_discrepancy=x.normalized_discrepancy,accepted=x.accepted)

struct ValidationRecordV4
    record_id::String; binding::ValidationBindingV4; split::Symbol; source_kind::Symbol; provenance::ProvenanceV4; applicability::ApplicabilityEnvelopeV4; observed::ObservableDatumV4; comparison::Union{Nothing,ComparisonResultV4}
    function ValidationRecordV4(id,binding,split,source,provenance,applicability,observed;comparison=nothing)
        s=split isa Symbol ? split : Symbol(split); s in (:calibration,:held_out) || throw(ArgumentError("invalid split")); k=source isa Symbol ? source : Symbol(source); k in (:physical_experiment,:public_component,:model_benchmark,:manufactured_control,:cross_code) || throw(ArgumentError("invalid source")); comparison===nothing || (comparison isa ComparisonResultV4&&comparison.observed==observed) || throw(ArgumentError("comparison must bind observed datum")); new(_vuq_text(id,"record_id"),binding,s,k,provenance,applicability,observed,comparison)
    end
end
semantic_view(x::ValidationRecordV4)=(record_id=x.record_id,binding=x.binding,split=x.split,source_kind=x.source_kind,provenance=x.provenance,applicability=x.applicability,observed=x.observed,comparison=x.comparison)

struct ParameterDistributionV4
    parameter::String; family::Symbol; parameters::NamedTuple; bounds::Tuple{Float64,Float64}
    function ParameterDistributionV4(parameter,family::Symbol,parameters::NamedTuple,bounds)
        b=(Float64(first(bounds)),Float64(last(bounds))); isfinite.(b)|>all&&b[1]<b[2] || throw(ArgumentError("invalid parameter bounds")); isempty(parameters)&&throw(ArgumentError("distribution parameters required")); new(_vuq_text(parameter,"parameter"),family,parameters,b)
    end
end
semantic_view(x::ParameterDistributionV4)=(parameter=x.parameter,family=x.family,parameters=x.parameters,bounds=x.bounds)

struct UncertaintyBudgetV4
    numerical::NamedTuple; model::NamedTuple; measurement::NamedTuple; transfer::NamedTuple; correlations::Tuple
    function UncertaintyBudgetV4(numerical::NamedTuple,model::NamedTuple,measurement::NamedTuple,transfer::NamedTuple;correlations=())
        all(!isempty,(numerical,model,measurement,transfer))||throw(ArgumentError("four uncertainty classes required")); cs=Tuple(correlations); all(c->c isa NamedTuple&&haskey(c,:left)&&haskey(c,:right)&&haskey(c,:coefficient)&&abs(Float64(c.coefficient))<=1,cs)||throw(ArgumentError("typed bounded correlations required")); new(numerical,model,measurement,transfer,cs)
    end
end
semantic_view(x::UncertaintyBudgetV4)=(numerical=x.numerical,model=x.model,measurement=x.measurement,transfer=x.transfer,correlations=x.correlations)

struct ValidationUQContractV4
    binding::ValidationBindingV4; calibration::Tuple; held_out::Tuple; prediction::Union{Nothing,PredictionArtifactV4}; parameter_distributions::Tuple; uncertainty_budget::Union{Nothing,UncertaintyBudgetV4}; extrapolation_status::Symbol; contract_hash::Digest256
    function ValidationUQContractV4(binding;calibration=(),held_out=(),prediction=nothing,parameter_distributions=(),uncertainty_budget=nothing,extrapolation_status::Symbol=:unknown)
        cal,ho=Tuple(calibration),Tuple(held_out); all(r->r isa ValidationRecordV4&&r.binding.binding_hash==binding.binding_hash,(cal...,ho...))||throw(ArgumentError("records must bind contract")); prediction===nothing||(prediction isa PredictionArtifactV4&&prediction.binding_hash==binding.binding_hash)||throw(ArgumentError("prediction must be candidate-bound")); all(p->p isa ParameterDistributionV4,parameter_distributions)||throw(ArgumentError("typed distributions required")); uncertainty_budget===nothing||uncertainty_budget isa UncertaintyBudgetV4||throw(ArgumentError("typed uncertainty budget required")); extrapolation_status in (:within_domain,:extrapolating,:unknown)||throw(ArgumentError("invalid extrapolation status")); keys=Set((r.provenance.record_hash,r.provenance.dataset_id,r.provenance.partition) for r in cal); isempty(intersect(keys,Set((r.provenance.record_hash,r.provenance.dataset_id,r.provenance.partition) for r in ho)))||throw(ArgumentError("calibration/held-out provenance overlap")); body=(binding=binding,calibration=cal,held_out=ho,prediction=prediction,parameter_distributions=Tuple(parameter_distributions),uncertainty_budget=uncertainty_budget,extrapolation_status=extrapolation_status); new(binding,cal,ho,prediction,Tuple(parameter_distributions),uncertainty_budget,extrapolation_status,canonical_hash(body))
    end
end
semantic_view(x::ValidationUQContractV4)=(binding=x.binding,calibration=x.calibration,held_out=x.held_out,prediction=x.prediction,parameter_distributions=x.parameter_distributions,uncertainty_budget=x.uncertainty_budget,extrapolation_status=x.extrapolation_status)

function validation_closure_decision(c::ValidationUQContractV4)
    reasons = String[]
    isempty(c.held_out) && push!(reasons, "missing held-out data")
    c.prediction === nothing && push!(reasons, "missing candidate-bound prediction artifact")
    any(r -> r.comparison === nothing, c.held_out) && push!(reasons, "missing comparison result")
    any(r -> r.source_kind in (:manufactured_control, :cross_code), c.held_out) && push!(reasons, "manufactured/cross-code evidence has zero physical credit")
    any(r -> !r.applicability.evaluated || !r.applicability.within_domain, c.held_out) && push!(reasons, "applicability not proven")
    c.uncertainty_budget === nothing && push!(reasons, "missing uncertainty budget")
    isempty(c.parameter_distributions) && push!(reasons, "missing parameter distributions")
    any(r -> r.comparison !== nothing && !r.comparison.accepted, c.held_out) && push!(reasons, "comparison tolerance failed")
    status = isempty(reasons) ? :pass : (any(r -> occursin("applicability", r), reasons) ? :out_of_domain : :unknown)
    status = status === :pass && any(r -> r.source_kind in (:manufactured_control, :cross_code), c.held_out) ? :test_only : status
    (status=status, physical_validation_credit=(status === :pass ? 1.0 : 0.0), reasons=Tuple(reasons),
        calibration_is_not_validation=true, decision_hash=canonical_hash((status=status, reasons=Tuple(reasons), contract_hash=c.contract_hash)))
end
validate_validation_uq_contract=validation_closure_decision
closure_decision=validation_closure_decision
