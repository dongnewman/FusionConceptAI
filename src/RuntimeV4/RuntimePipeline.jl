"""One auditable v4 software spine from three Genomes to a screen result."""

struct VerticalSliceReportV4
    compiled::Union{Nothing,CompiledCandidatePrefixV4}
    subject::Union{Nothing,ExecutablePhysicalSubjectV4}
    matches::Tuple
    evidence::Tuple
    capability_gaps::Tuple
    layer_counts::NamedTuple
    claim_ceiling::ClaimCeiling
    credible_count::Int
    unsupported_count::Int
end

function _runtime_gap(obligation, result)
    (obligation_hash=canonical_hash(obligation), status=result.status,
     reason=result.reason, required_output=obligation.required_output,
     operator=obligation.operator)
end

function _runtime_screen_manifests(obligations, providers)
    providers === nothing && return ()
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    Tuple(ps)
end

function _runtime_ordered_scenarios(scenarios)
    xs = collect(_runtime_scenarios(scenarios))
    sort!(xs, by=x -> string(canonical_hash(x)))
    Tuple(xs)
end

function _runtime_structural_subject(compiled::CompiledCandidatePrefixV4, bindings, scenarios)
    bs = _runtime_bindings(bindings)
    ss = _runtime_scenarios(scenarios)
    structural = Tuple(o for o in compiled.capability_obligations if o.kind == :structural_screen)
    payload = (mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mechanism_graph=compiled.mechanism_graph, field_geometry_graph=compiled.field_geometry_graph,
        realization_graph=compiled.realization_graph,
        control_graph=compiled.control_graph, normalized_regions=compiled.normalized_regions,
        normalized_interfaces=compiled.normalized_interfaces, normalized_boundaries=compiled.normalized_boundaries,
        bindings=bs, scenarios=ss)
    ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        compiled.candidate.canonical_hashes.genome_bundle_hash, compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bs, ss, payload, structural)
end

function _runtime_execute_screen(compiled, matches, bindings, scenarios, store, backend)
    structural = [(o, m) for (o, m) in zip(compiled.capability_obligations, matches)
                  if o.kind == :structural_screen && m.status == unique_match]
    isempty(structural) && return nothing
    subject = _runtime_structural_subject(compiled, bindings, scenarios)
    seen = Set{Digest256}(); evidences = RuntimeEvidenceV4[]
    for scenario in subject.scenarios, (obligation, match) in structural
        input = compile_solver_input(subject, scenario, obligation, match.provider)
        input.solver_input_hash in seen && continue
        push!(seen, input.solver_input_hash)
        evidence = if backend === nothing || !applicable(execute_once!, store, input, match.provider, backend)
            execute_once!(store, input, match.provider)
        else
            execute_once!(store, input, match.provider, backend)
        end
        push!(evidences, evidence)
    end
    subject, Tuple(evidences)
end

"""Run the bounded P1 path.

`credible_count` and `unsupported_count` remain zero by construction: this
slice can produce only screen-only evidence and leaves unresolved capability
gaps for the later authority stage.
"""
function run_v4_vertical_slice(candidate::CandidateStatePackageV4,
                               registry::GenomeContractRegistryV4;
                               mission_payload=candidate.mission_contract_ref,
                               bounds_payload=(scope="runtime-v4-default-bounds",),
                               bindings=(candidate="candidate",),
                               scenarios=((name="screen",),),
                               providers=(),
                               store=nothing,
                               backend=nothing,
                               comparison_scope=("runtime-v4-structural",),
                               scenario_scope=("declared_scenarios",),
                               compiled_prefix=nothing)
    scenarios = _runtime_ordered_scenarios(scenarios)
    compiled = compiled_prefix === nothing ? compile_candidate(candidate, registry;
                                 mission_payload=mission_payload,
                                 bounds_payload=bounds_payload,
                                 comparison_scope=comparison_scope,
                                 scenario_scope=scenario_scope) :
        _runtime_validate_compiled_prefix(compiled_prefix, candidate, registry,
            mission_payload, bounds_payload, comparison_scope, scenario_scope)
    obligations = derive_capability_obligations(compiled)
    local_store = store === nothing ? Dict{Digest256,RuntimeEvidenceV4}() : store
    if !isempty(compiled.unresolved_nonterminals)
        manifests = _runtime_screen_manifests(obligations, providers)
        matches = Tuple(match_provider(o, manifests) for o in obligations)
        return VerticalSliceReportV4(compiled, nothing, (), (),
            (Tuple((reason=x,) for x in compiled.unresolved_nonterminals)...,
             Tuple(_runtime_gap(o, m) for (o, m) in zip(obligations, matches)
                   if m.status != unique_match)...),
            (genome_count=3, prefix_count=1, obligation_count=length(obligations),
             subject_count=0, solver_input_count=0, evidence_count=0),
            none, 0, 0)
    end
    manifests = _runtime_screen_manifests(obligations, providers)
    matches = Tuple(match_provider(o, manifests) for o in obligations)
    gaps = Tuple(_runtime_gap(o, m) for (o, m) in zip(obligations, matches)
                 if m.status != unique_match)
    screen_run = isempty(compiled.unresolved_nonterminals) ?
        _runtime_execute_screen(compiled, matches, bindings, scenarios, local_store, backend) : nothing
    if screen_run !== nothing
        screen_subject, screen_evidence = screen_run
        return VerticalSliceReportV4(compiled, screen_subject, matches, screen_evidence, gaps,
            (genome_count=3, prefix_count=1, obligation_count=length(obligations),
             subject_count=1, solver_input_count=length(screen_evidence), evidence_count=length(screen_evidence)),
            isempty(screen_evidence) ? none : screen_only, 0, 0)
    end
    isempty(gaps) || return VerticalSliceReportV4(compiled, nothing, matches, (), gaps,
        (genome_count=3, prefix_count=1, obligation_count=length(obligations),
         subject_count=0, solver_input_count=0, evidence_count=0), none, 0, 0)
    subject = materialize(compiled, bindings, scenarios)
    evidences = RuntimeEvidenceV4[]
    seen_inputs = Set{Digest256}()
    for scenario in subject.scenarios, (obligation, match) in zip(obligations, matches)
        provider = match.provider
        input = compile_solver_input(subject, scenario, obligation, provider)
        input.solver_input_hash in seen_inputs && continue
        push!(seen_inputs, input.solver_input_hash)
        evidence = if backend === nothing || !applicable(execute_once!, local_store, input, provider, backend)
            execute_once!(local_store, input, provider)
        else
            execute_once!(local_store, input, provider, backend)
        end
        push!(evidences, evidence)
    end
    ceiling = isempty(evidences) ? none : screen_only
    VerticalSliceReportV4(compiled, subject, matches, Tuple(evidences), (),
        (genome_count=3, prefix_count=1, obligation_count=length(obligations),
         subject_count=1, solver_input_count=length(evidences), evidence_count=length(evidences)),
        ceiling, 0, 0)
end

"""Stable report fields for the CLI and machine checks."""
function vertical_slice_manifest(report::VerticalSliceReportV4)
    (schema="fusionconceptai-runtime-v4-vertical-slice",
     version="p1",
     prefix_hash=report.compiled === nothing ? nothing : report.compiled.prefix_hash,
     physical_subject_hash=report.subject === nothing ? nothing : report.subject.physical_subject_hash,
     claim_ceiling=report.claim_ceiling,
     layer_counts=report.layer_counts,
     credible_count=report.credible_count,
     unsupported_count=report.unsupported_count,
     capability_gaps=report.capability_gaps)
end
