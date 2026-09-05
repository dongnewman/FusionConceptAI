"""Runtime v4 contracts.

This file is intentionally additive.  It consumes the frozen Genome and P0
types exported by `FusionConceptAI`; it does not define a second Genome
vocabulary or a terminal authority.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI

const _RUNTIME_CEILINGS = (none, screen_only)
const _RUNTIME_EXECUTOR_BINDINGS = Dict{Digest256,Function}()

_runtime_digest(x::Digest256) = x
_runtime_digest(x::AbstractString) = Digest256(String(x))
_runtime_digest(x) = throw(ArgumentError("expected Digest256 or a digest string"))

function _runtime_nonempty_text(x, field::AbstractString)
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    s = String(x)
    !isempty(s) && isvalid(s) || throw(ArgumentError("$field cannot be empty"))
    s
end

function _runtime_axis_tuple(xs, field::AbstractString; allow_empty::Bool=false)
    ys = Tuple(_runtime_nonwild_text(x, field) for x in xs)
    (allow_empty || !isempty(ys)) || throw(ArgumentError("$field cannot be empty"))
    any(x -> lowercase(x) in ("*", "any", "wildcard", "all"), ys) &&
        throw(ArgumentError("$field cannot contain wildcard axes"))
    length(unique(ys)) == length(ys) || throw(ArgumentError("$field contains duplicate axes"))
    ys
end

function _runtime_nonwild_text(x, field::AbstractString)
    s = strip(_runtime_nonempty_text(x, field))
    isempty(s) && throw(ArgumentError("$field cannot be empty or whitespace"))
    lowercase(s) in ("*", "any", "wildcard", "all") && throw(ArgumentError("$field cannot be wildcard"))
    String(s)
end

function _runtime_required_ceiling(x::ClaimCeiling, field::AbstractString="claim ceiling")
    x isa ClaimCeiling || throw(ArgumentError("$field must be ClaimCeiling"))
    x
end

function _runtime_evidence_ceiling(x::ClaimCeiling, field::AbstractString="claim ceiling")
    x in _RUNTIME_CEILINGS || throw(ArgumentError("$field is restricted to none or screen_only"))
    x
end

_runtime_ceiling_rank(x::ClaimCeiling) = x == none ? 0 : x == screen_only ? 1 : Int(x)

struct MinimalityScopeV4
    grammar_hash::Digest256
    bounds_hash::Digest256
    mission_hash::Digest256
    evidence_level::ClaimCeiling
    comparison_scope::Tuple{Vararg{String}}
    scenario_scope::Tuple{Vararg{String}}
    function MinimalityScopeV4(grammar_hash, bounds_hash, mission_hash, evidence_level::ClaimCeiling,
                               comparison_scope, scenario_scope)
        scope = _runtime_axis_tuple(comparison_scope, "comparison_scope")
        scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
        new(_runtime_digest(grammar_hash), _runtime_digest(bounds_hash), _runtime_digest(mission_hash),
            _runtime_required_ceiling(evidence_level, "minimality evidence level"), scope, scenarios)
    end
end
semantic_view(x::MinimalityScopeV4) = (grammar_hash=x.grammar_hash, bounds_hash=x.bounds_hash,
    mission_hash=x.mission_hash, evidence_level=x.evidence_level, comparison_scope=x.comparison_scope,
    scenario_scope=x.scenario_scope)

struct CapabilitySignatureV4
    schema::String
    revision::String
    kind::Symbol
    operator::String
    states::Tuple{Vararg{String}}
    source_space::String
    target_space::String
    dimension::Int
    coordinates::Tuple{Vararg{String}}
    boundary_relation::String
    interface_relation::String
    time_semantics::String
    required_output::Tuple{Vararg{String}}
    evidence_level::ClaimCeiling
    applicability_bounds::Digest256
    input_schema_hash::Digest256
    coordinate_system::String
    function CapabilitySignatureV4(schema::AbstractString, revision::AbstractString, kind,
            operator::AbstractString, states, source_space::AbstractString, target_space::AbstractString,
            dimension::Integer, coordinates, boundary_relation::AbstractString,
            interface_relation::AbstractString, time_semantics::AbstractString, required_output,
            evidence_level::ClaimCeiling, applicability_bounds; input_schema_hash=nothing, coordinate_system="lumped")
        dim = Int(dimension)
        dim >= 0 || throw(ArgumentError("capability dimension must be non-negative"))
        coords = _runtime_axis_tuple(coordinates, "coordinates"; allow_empty=(dim == 0))
        length(coords) == dim || throw(ArgumentError("coordinate axis count must equal dimension"))
        st = _runtime_axis_tuple(states, "states")
        out = _runtime_axis_tuple(required_output, "required_output")
        kind_text = kind isa Symbol ? kind : Symbol(_runtime_nonempty_text(kind, "capability kind"))
        isvalid(String(kind_text)) && lowercase(String(kind_text)) ∉ ("*", "any", "wildcard", "all") ||
            throw(ArgumentError("capability kind cannot be wildcard"))
        cs = _runtime_nonwild_text(coordinate_system, "coordinate_system")
        base = (schema=_runtime_nonwild_text(schema, "capability schema"), revision=_runtime_nonwild_text(revision, "capability revision"),
            kind=kind_text, operator=_runtime_nonwild_text(operator, "capability operator"), states=st,
            source_space=_runtime_nonwild_text(source_space, "source_space"), target_space=_runtime_nonwild_text(target_space, "target_space"),
            dimension=dim, coordinates=coords, coordinate_system=cs,
            boundary_relation=_runtime_nonwild_text(boundary_relation, "boundary_relation"),
            interface_relation=_runtime_nonwild_text(interface_relation, "interface_relation"),
            time_semantics=_runtime_nonwild_text(time_semantics, "time_semantics"), required_output=out)
        ish = input_schema_hash === nothing ? canonical_hash(base) : _runtime_digest(input_schema_hash)
        new(base.schema, base.revision, base.kind, base.operator, base.states,
            base.source_space, base.target_space, base.dimension, base.coordinates, base.boundary_relation,
            base.interface_relation, base.time_semantics, base.required_output,
            _runtime_required_ceiling(evidence_level, "capability evidence level"), _runtime_digest(applicability_bounds), ish,
            base.coordinate_system)
    end
end
semantic_view(x::CapabilitySignatureV4) = (schema=x.schema, revision=x.revision, kind=x.kind,
    operator=x.operator, states=x.states, source_space=x.source_space, target_space=x.target_space,
    dimension=x.dimension, coordinates=x.coordinates, coordinate_system=x.coordinate_system, boundary_relation=x.boundary_relation,
    interface_relation=x.interface_relation, time_semantics=x.time_semantics,
    required_output=x.required_output, evidence_level=x.evidence_level,
    applicability_bounds=x.applicability_bounds, input_schema_hash=x.input_schema_hash)

struct ProviderManifestV4
    schema::String
    revision::String
    kind::Symbol
    capability::CapabilitySignatureV4
    domain::Any
    backend::String
    backend_revision::String
    code_hash::Digest256
    independence_group::String
    claim_ceiling::ClaimCeiling
    input_schema_hash::Digest256
    executor::Union{Nothing,Function}
    manifest_hash::Digest256
    function ProviderManifestV4(schema::AbstractString, revision::AbstractString, kind,
            capability::CapabilitySignatureV4, domain, backend::AbstractString, backend_revision::AbstractString,
            code_hash, independence_group::AbstractString, claim_ceiling::ClaimCeiling;
            input_schema_hash=nothing, executor=nothing)
        executor === nothing || executor isa Function || throw(ArgumentError("executor must be a Function or nothing"))
        _runtime_evidence_ceiling(claim_ceiling, "provider claim ceiling")
        is_canonical_value(domain) || throw(ArgumentError("provider domain must be immutable and canonicalizable"))
        canonical_domain_hash = canonical_hash(domain)
        provider_kind = kind isa Symbol ? kind : Symbol(_runtime_nonempty_text(kind, "provider kind"))
        isvalid(String(provider_kind)) && lowercase(String(provider_kind)) ∉ ("*", "any", "wildcard", "all") ||
            throw(ArgumentError("provider kind cannot be wildcard"))
        ish = input_schema_hash === nothing ? capability.input_schema_hash : _runtime_digest(input_schema_hash)
        capability.kind == provider_kind || throw(ArgumentError("provider kind must equal capability kind"))
        ish == capability.input_schema_hash || throw(ArgumentError("provider input_schema_hash must equal capability input_schema_hash"))
        _runtime_ceiling_rank(claim_ceiling) >= _runtime_ceiling_rank(capability.evidence_level) ||
            throw(ArgumentError("provider claim ceiling cannot understate its capability evidence level"))
        body = (schema=_runtime_nonwild_text(schema, "provider schema"), revision=_runtime_nonwild_text(revision, "provider revision"),
            kind=provider_kind, capability=capability, domain=domain,
            backend=_runtime_nonempty_text(backend, "provider backend"), backend_revision=_runtime_nonempty_text(backend_revision, "backend revision"),
            code_hash=_runtime_digest(code_hash), independence_group=_runtime_nonempty_text(independence_group, "independence group"),
            claim_ceiling=claim_ceiling, input_schema_hash=ish, domain_hash=canonical_domain_hash)
        mh = canonical_hash(body)
        if executor !== nothing
            prior = get(_RUNTIME_EXECUTOR_BINDINGS, mh, nothing)
            prior === nothing || prior === executor || throw(ArgumentError("manifest hash is already bound to another executor"))
            _RUNTIME_EXECUTOR_BINDINGS[mh] = executor
        end
        new(body.schema, body.revision, body.kind, capability, domain, body.backend, body.backend_revision,
            body.code_hash, body.independence_group, claim_ceiling, ish, executor, mh)
    end
end
semantic_view(x::ProviderManifestV4) = (schema=x.schema, revision=x.revision, kind=x.kind,
    capability=x.capability, domain=x.domain, backend=x.backend, backend_revision=x.backend_revision,
    code_hash=x.code_hash, independence_group=x.independence_group, claim_ceiling=x.claim_ceiling,
    input_schema_hash=x.input_schema_hash, manifest_hash=x.manifest_hash)

struct CompiledCandidatePrefixV4
    candidate::CandidateStatePackageV4
    mission_payload::Any
    bounds_payload::Any
    minimality_scope::MinimalityScopeV4
    mechanism_graph::TypedOperatorHypergraphV1
    field_geometry_graph::TypedOperatorHypergraphV1
    realization_graph::TypedOperatorHypergraphV1
    control_graph::TypedOperatorHypergraphV1
    normalized_regions::Tuple
    normalized_interfaces::Tuple
    normalized_boundaries::Tuple
    unresolved_nonterminals::Tuple{Vararg{String}}
    capability_obligations::Tuple
    compilation_status::Symbol
    prefix_hash::Digest256
    function CompiledCandidatePrefixV4(candidate::CandidateStatePackageV4, mission_payload, bounds_payload,
            scope::MinimalityScopeV4, mechanism_graph::TypedOperatorHypergraphV1,
            field_geometry_graph::TypedOperatorHypergraphV1, realization_graph::TypedOperatorHypergraphV1,
            control_graph::TypedOperatorHypergraphV1, regions, interfaces, boundaries, unresolved,
            obligations, compilation_status::Symbol)
        compilation_status in (:prefix_consistent, :prefix_incomplete, :certificate_candidate) ||
            throw(ArgumentError("invalid compilation status"))
        us = _runtime_axis_tuple(unresolved, "unresolved_nonterminals"; allow_empty=true)
        obs = Tuple(obligations)
        all(o -> o isa CapabilitySignatureV4, obs) || throw(ArgumentError("capability obligations must be typed"))
        body = (mechanism_hash=mechanism_hash(candidate.mechanism_genome_ref),
            field_geometry_hash=field_geometry_hash(candidate.field_geometry_genome_ref),
            realization_control_hash=realization_control_hash(candidate.realization_control_genome_ref),
            genome_bundle_hash=candidate.canonical_hashes.genome_bundle_hash,
            mission_payload=mission_payload, bounds_payload=bounds_payload,
            minimality_scope=scope, mechanism_graph=mechanism_graph, field_geometry_graph=field_geometry_graph,
            realization_graph=realization_graph, control_graph=control_graph,
            normalized_regions=Tuple(regions), normalized_interfaces=Tuple(interfaces),
            normalized_boundaries=Tuple(boundaries), unresolved_nonterminals=us,
            capability_obligations=obs, compilation_status=compilation_status)
        is_canonical_value(body) || throw(ArgumentError("compiled candidate payload is not canonicalizable"))
        new(candidate, mission_payload, bounds_payload, scope, mechanism_graph, field_geometry_graph,
            realization_graph, control_graph, Tuple(regions), Tuple(interfaces), Tuple(boundaries), us,
            obs, compilation_status, canonical_hash(body))
    end
end
semantic_view(x::CompiledCandidatePrefixV4) = (candidate=semantic_view(x.candidate), mission_payload=x.mission_payload,
    bounds_payload=x.bounds_payload, minimality_scope=x.minimality_scope, mechanism_graph=x.mechanism_graph,
    field_geometry_graph=x.field_geometry_graph, realization_graph=x.realization_graph, control_graph=x.control_graph,
    normalized_regions=x.normalized_regions, normalized_interfaces=x.normalized_interfaces,
    normalized_boundaries=x.normalized_boundaries, unresolved_nonterminals=x.unresolved_nonterminals,
    capability_obligations=x.capability_obligations, compilation_status=x.compilation_status, prefix_hash=x.prefix_hash)

struct ProviderMatchResultV4
    status::MatchStatus
    provider::Union{Nothing,ProviderManifestV4}
    obligation_hash::Digest256
    reason::String
    function ProviderMatchResultV4(status::MatchStatus, provider::Union{Nothing,ProviderManifestV4},
                                   obligation::CapabilitySignatureV4, reason::AbstractString)
        status in (unique_match, no_match, ambiguous, out_of_domain, invalid_signature) ||
            throw(ArgumentError("invalid provider match status"))
        (status == unique_match) == (provider !== nothing) ||
            throw(ArgumentError("unique match must carry exactly one provider"))
        status != unique_match && provider === nothing || true
        r = _runtime_nonempty_text(reason, "provider match reason")
        new(status, provider, canonical_hash(obligation), r)
    end
end
semantic_view(x::ProviderMatchResultV4) = (status=x.status, provider=x.provider, obligation_hash=x.obligation_hash, reason=x.reason)

struct ExecutablePhysicalSubjectV4
    compiled_prefix_hash::Digest256
    genome_bundle_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    bindings::Tuple
    scenarios::Tuple
    materialized_payload::Any
    operator_obligations::Tuple
    physical_subject_hash::Digest256
    function ExecutablePhysicalSubjectV4(compiled_prefix_hash, genome_bundle_hash, mission_hash, bounds_hash,
            bindings, scenarios, materialized_payload, operator_obligations)
        bs = Tuple(bindings); ss = Tuple(scenarios); obs = Tuple(operator_obligations)
        body = (compiled_prefix_hash=_runtime_digest(compiled_prefix_hash), genome_bundle_hash=_runtime_digest(genome_bundle_hash),
            mission_hash=_runtime_digest(mission_hash), bounds_hash=_runtime_digest(bounds_hash), bindings=bs,
            scenarios=ss, materialized_payload=materialized_payload, operator_obligations=obs)
        is_canonical_value(body) || throw(ArgumentError("physical subject payload must be immutable and canonicalizable"))
        new(body.compiled_prefix_hash, body.genome_bundle_hash, body.mission_hash, body.bounds_hash,
            bs, ss, materialized_payload, obs, canonical_hash(body))
    end
end
semantic_view(x::ExecutablePhysicalSubjectV4) = (compiled_prefix_hash=x.compiled_prefix_hash,
    genome_bundle_hash=x.genome_bundle_hash, mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
    bindings=x.bindings, scenarios=x.scenarios, materialized_payload=x.materialized_payload,
    operator_obligations=x.operator_obligations, physical_subject_hash=x.physical_subject_hash)

struct SolverInputV4
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    provider_manifest_hash::Digest256
    input_schema_hash::Digest256
    payload::Any
    solver_input_hash::Digest256
    function SolverInputV4(physical_subject_hash, scenario_hash, provider_manifest_hash, input_schema_hash, payload)
        body = (physical_subject_hash=_runtime_digest(physical_subject_hash), scenario_hash=_runtime_digest(scenario_hash),
            provider_manifest_hash=_runtime_digest(provider_manifest_hash), input_schema_hash=_runtime_digest(input_schema_hash), payload=payload)
        is_canonical_value(body) || throw(ArgumentError("solver input payload must be immutable and canonicalizable"))
        new(body.physical_subject_hash, body.scenario_hash, body.provider_manifest_hash,
            body.input_schema_hash, payload, canonical_hash(body))
    end
end
semantic_view(x::SolverInputV4) = (physical_subject_hash=x.physical_subject_hash, scenario_hash=x.scenario_hash,
    provider_manifest_hash=x.provider_manifest_hash, input_schema_hash=x.input_schema_hash,
    payload=x.payload, solver_input_hash=x.solver_input_hash)

struct RuntimeEvidenceV4
    evidence_id::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Union{Nothing,Digest256}
    backend_revision::Union{Nothing,String}
    numerical_configuration_hash::Union{Nothing,Digest256}
    artifact_refs::Tuple{Vararg{Digest256}}
    uncertainty_or_null::Union{Nothing,UncertaintyV4}
    binding_provenance::Any
    status_vector::StatusVectorV4
    metrics::Tuple{Vararg{MetricWithUnit}}
    claim_ceiling::ClaimCeiling
    independence_group::String
    function RuntimeEvidenceV4(physical_subject_hash, scenario_hash, solver_input_hash,
            provider_manifest_hash, binding_provenance, status_vector::StatusVectorV4,
            metrics=(); claim_ceiling::ClaimCeiling=screen_only, independence_group="runtime-v4",
            provider_manifest=nothing, backend_revision=nothing, numerical_configuration_hash=nothing,
            artifact_refs=(), uncertainty_or_null=nothing)
        _runtime_evidence_ceiling(claim_ceiling, "runtime evidence ceiling")
        ms = Tuple(metrics); all(m -> m isa MetricWithUnit, ms) || throw(ArgumentError("runtime metrics must be MetricWithUnit"))
        is_canonical_value(binding_provenance) || throw(ArgumentError("binding provenance must be canonicalizable"))
        refs = Tuple(_runtime_digest(a) for a in artifact_refs)
        uncertainty_or_null === nothing || uncertainty_or_null isa UncertaintyV4 || throw(ArgumentError("uncertainty must be UncertaintyV4 or nothing"))
        provider_manifest === nothing || provider_manifest isa ProviderManifestV4 || throw(ArgumentError("provider_manifest must be ProviderManifestV4 or nothing"))
        if provider_manifest === nothing
            status_vector.match_status != unique_match && status_vector.resolution == terminal_deferred &&
                status_vector.stage_outcome == terminal_deferred_stage && isempty(ms) && claim_ceiling == none ||
                throw(ArgumentError("deferred evidence without a provider cannot contain execution evidence"))
            provider_manifest_hash === nothing || throw(ArgumentError("deferred evidence cannot claim a provider manifest"))
            ph = nothing; br = nothing; nch = nothing; group = "none"
        else
            provider_manifest_hash === nothing || _runtime_digest(provider_manifest_hash) == provider_manifest.manifest_hash ||
                throw(ArgumentError("provider manifest hash does not match provider_manifest"))
            ph = provider_manifest.manifest_hash
            backend_revision === nothing && (backend_revision = provider_manifest.backend_revision)
            br = _runtime_nonempty_text(backend_revision, "backend revision")
            nch = numerical_configuration_hash === nothing ? canonical_hash((backend_revision=br, input=solver_input_hash)) : _runtime_digest(numerical_configuration_hash)
            provider_manifest.claim_ceiling == claim_ceiling || _runtime_ceiling_rank(provider_manifest.claim_ceiling) >= _runtime_ceiling_rank(claim_ceiling) ||
                throw(ArgumentError("runtime evidence ceiling exceeds provider manifest ceiling"))
            group = provider_manifest.independence_group
        end
        body = (physical_subject_hash=_runtime_digest(physical_subject_hash), scenario_hash=_runtime_digest(scenario_hash),
            solver_input_hash=_runtime_digest(solver_input_hash), provider_manifest_hash=ph,
            backend_revision=br, numerical_configuration_hash=nch, artifact_refs=refs, uncertainty_or_null=uncertainty_or_null,
            binding_provenance=binding_provenance, status_vector=status_vector, metrics=ms,
            claim_ceiling=claim_ceiling, independence_group=group)
        is_canonical_value(body) || throw(ArgumentError("runtime evidence is not canonicalizable"))
        new(canonical_hash(body), body.physical_subject_hash, body.scenario_hash, body.solver_input_hash,
            body.provider_manifest_hash, body.backend_revision, body.numerical_configuration_hash,
            body.artifact_refs, body.uncertainty_or_null, binding_provenance, status_vector, ms, claim_ceiling,
            body.independence_group)
    end
end
semantic_view(x::RuntimeEvidenceV4) = (evidence_id=x.evidence_id, physical_subject_hash=x.physical_subject_hash,
    scenario_hash=x.scenario_hash, solver_input_hash=x.solver_input_hash, provider_manifest_hash=x.provider_manifest_hash,
    backend_revision=x.backend_revision, numerical_configuration_hash=x.numerical_configuration_hash,
    artifact_refs=x.artifact_refs, uncertainty_or_null=x.uncertainty_or_null, binding_provenance=x.binding_provenance,
    status_vector=x.status_vector, metrics=x.metrics, claim_ceiling=x.claim_ceiling, independence_group=x.independence_group)

function Base.getproperty(x::CapabilitySignatureV4, name::Symbol)
    name === :capability_kind && return getfield(x, :kind)
    name === :schema_hash && return digest256_text(x.schema)
    name === :revision_hash && return digest256_text(x.revision)
    getfield(x, name)
end
function Base.getproperty(x::CompiledCandidatePrefixV4, name::Symbol)
    name === :hash && return getfield(x, :prefix_hash)
    name === :unresolved && return getfield(x, :unresolved_nonterminals)
    name === :obligations && return getfield(x, :capability_obligations)
    getfield(x, name)
end
function Base.getproperty(x::ExecutablePhysicalSubjectV4, name::Symbol)
    name === :hash && return getfield(x, :physical_subject_hash)
    getfield(x, name)
end
function Base.getproperty(x::ProviderManifestV4, name::Symbol)
    name === :capability_kind && return getfield(x, :kind)
    name === :hash && return getfield(x, :manifest_hash)
    getfield(x, name)
end
function Base.getproperty(x::SolverInputV4, name::Symbol)
    name === :input_hash && return getfield(x, :solver_input_hash)
    getfield(x, name)
end
function Base.getproperty(x::RuntimeEvidenceV4, name::Symbol)
    name === :provenance && return getfield(x, :binding_provenance)
    name === :ceiling && return getfield(x, :claim_ceiling)
    getfield(x, name)
end
