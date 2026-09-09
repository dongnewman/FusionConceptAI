"""B3 bindings for the isolated Gridap field provider.

This additive layer owns provider/subject/input/evidence binding and replay. It
delegates numerical work only to the sealed B1 entry point; it never imports or
calls the native field assembler.
"""

using SHA
const _GRIDAP_B3_TOKEN = Ref{Nothing}(nothing)
const _GRIDAP_B3_SCHEMA = "runtime-v4-gridap-field-evidence"
const _GRIDAP_B3_REVISION = "b3"
const _GRIDAP_B3_PROVIDER_CACHE = Dict{Digest256,ProviderManifestV4}()
const _GRIDAP_B3_INPUTS = Dict{Digest256,GridapFieldResidualCompilationV4}()
const _GRIDAP_B3_REPORTS = Dict{Digest256,GridapFieldResidualReportV4}()

struct GridapFieldReplayEnvelopeV4
    input_hash::Digest256
    provider_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    plan_hash::Digest256
    report_hash::Union{Nothing,Digest256}
    evidence_id::Union{Nothing,Digest256}
    status::Symbol
    envelope_hash::Digest256
    function GridapFieldReplayEnvelopeV4(token::typeof(_GRIDAP_B3_TOKEN), args...)
        token === _GRIDAP_B3_TOKEN || throw(ArgumentError("sealed Gridap replay envelope"))
        new(args...)
    end
end
GridapFieldReplayEnvelopeV4(args...) = throw(ArgumentError("Gridap replay envelope is sealed"))

struct GridapFieldEvidenceBundleV4
    compilation::GridapFieldResidualCompilationV4
    subject::ExecutablePhysicalSubjectV4
    provider::ProviderManifestV4
    input::SolverInputV4
    evidence::RuntimeEvidenceV4
    report::Union{Nothing,GridapFieldResidualReportV4}
    replay::GridapFieldReplayEnvelopeV4
    status::Symbol
    failure_reason::Union{Nothing,String}
    bundle_hash::Digest256
    function GridapFieldEvidenceBundleV4(token::typeof(_GRIDAP_B3_TOKEN), args...)
        token === _GRIDAP_B3_TOKEN || throw(ArgumentError("sealed Gridap evidence bundle"))
        new(args...)
    end
end
GridapFieldEvidenceBundleV4(args...) = throw(ArgumentError("Gridap evidence bundle is sealed"))

semantic_view(x::GridapFieldReplayEnvelopeV4) = (input_hash=x.input_hash,
    provider_hash=x.provider_hash, subject_hash=x.subject_hash,
    scenario_hash=x.scenario_hash, plan_hash=x.plan_hash, report_hash=x.report_hash,
    evidence_id=x.evidence_id, status=x.status, envelope_hash=x.envelope_hash)
canonical_hash(x::GridapFieldReplayEnvelopeV4) = x.envelope_hash
semantic_view(x::GridapFieldEvidenceBundleV4) = (compilation_hash=canonical_hash(x.compilation),
    subject_hash=x.subject.physical_subject_hash, provider_hash=x.provider.manifest_hash,
    input_hash=x.input.solver_input_hash, evidence_id=x.evidence.evidence_id,
    report_hash=(x.report === nothing ? nothing : x.report.report_hash), replay_hash=x.replay.envelope_hash,
    status=x.status, failure_reason=x.failure_reason, bundle_hash=x.bundle_hash)
canonical_hash(x::GridapFieldEvidenceBundleV4) = x.bundle_hash
_gridap_b3_source_hash() = Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

function _b3_domain(c, scenario)
    p = c.plan
    (candidate_hash=p.candidate_hash, prefix_hash=p.prefix_hash,
     scenario_hash=p.scenario_hash, constraint_edge_hash=p.constraint_edge_hash,
     form_hash=p.form_hash, geometry_hash=p.geometry_hash, grid_hash=p.grid_hash,
     u_plan_hash=p.u_plan_hash, f_plan_hash=p.f_plan_hash,
     u_result_hash=p.u_result_hash, f_result_hash=p.f_result_hash,
     u_evidence_id=p.u_evidence_id, f_evidence_id=p.f_evidence_id,
     protocol_hash=p.protocol.protocol_hash, dependency_hash=p.dependency_identity.dependency_hash,
     adapter_code_hash=p.adapter_code_hash, scenario=scenario,
     source_content_hash=p.source_content_hash, boundary_content_hash=p.boundary_content_hash)
end

function gridap_field_evidence_capability(c::GridapFieldResidualCompilationV4,
        scenario, bounds_hash::Digest256)
    domain = _b3_domain(c, scenario)
    CapabilitySignatureV4(_GRIDAP_B3_SCHEMA, _GRIDAP_B3_REVISION,
        :gridap_weak_form_field_residual, "LAPLACE", ("u", "f", "r"),
        "H1", "H1", 3, ("x", "y", "z"), "dirichlet_strong", "none",
        "static", ("report", "runtime_evidence"), screen_only,
        canonical_hash((domain=domain, bounds_hash=bounds_hash));
        coordinate_system="physical_cartesian")
end

function _b3_metrics(r)
    r.status === :pass || return ()
    (MetricWithUnit(:residual_inf, r.result.residual_abs),
     MetricWithUnit(:boundary_mismatch, r.result.boundary_mismatch),
     MetricWithUnit(:manufactured_node_linf, r.result.manufactured_node_linf_error))
end

"""Bind a B1 compilation to one exact Gridap capability and execute once."""
function execute_gridap_field_evidence!(store::AbstractDict,
        c::GridapFieldResidualCompilationV4; candidate, compiled, genome_registry,
        scenario, bindings=(gridap_plan_hash=c.plan.plan_hash,))
    _gridap_compilation_integrity(c) || throw(ArgumentError("B1 compilation integrity mismatch"))
    compiled.candidate == candidate || throw(ArgumentError("foreign candidate/prefix"))
    _runtime_validate_compiled_prefix(compiled, candidate, genome_registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope, compiled.minimality_scope.scenario_scope)
    compiled.prefix_hash == c.plan.prefix_hash || throw(ArgumentError("B1 prefix mismatch"))
    candidate.canonical_hashes.genome_bundle_hash == c.plan.candidate_hash ||
        throw(ArgumentError("B1 candidate mismatch"))
    canonical_hash(genome_registry) == c.plan.registry_hash ||
        throw(ArgumentError("B1 registry mismatch"))
    compiled.minimality_scope.mission_hash == c.plan.mission_hash ||
        throw(ArgumentError("B1 mission mismatch"))
    compiled.minimality_scope.bounds_hash == canonical_hash(compiled.bounds_payload) || throw(ArgumentError("bounds mismatch"))
    canonical_hash(scenario) == c.plan.scenario_hash || throw(ArgumentError("foreign scenario"))
    bounds_hash = compiled.minimality_scope.bounds_hash
    domain = _b3_domain(c, scenario)
    capability = gridap_field_evidence_capability(c, scenario, bounds_hash)
    executor = input -> begin
        c0 = get(_GRIDAP_B3_INPUTS, input.solver_input_hash, nothing)
        c0 === nothing && throw(ArgumentError("unknown B3 input"))
        input.payload.physical_subject_hash == input.physical_subject_hash ||
            throw(ArgumentError("foreign physical subject"))
        input.payload.provider_code_hash == canonical_hash((_gridap_b3_source_hash(),
            c0.plan.adapter_code_hash, c0.plan.dependency_identity.dependency_hash)) ||
            throw(ArgumentError("B3 source/dependency drift"))
        input.payload.scenario_hash == c0.plan.scenario_hash || throw(ArgumentError("foreign scenario"))
        r = run_gridap_field_residual(c0)
        _GRIDAP_B3_REPORTS[input.solver_input_hash] = r
        (metrics=_b3_metrics(r), stage_outcome=(r.status === :pass ? :pass : :numerical_fail),
         artifacts=(r.report_hash, r.receipt.assembly_hash, r.result.result_hash))
    end
    code_hash = canonical_hash((_gridap_b3_source_hash(), c.plan.adapter_code_hash, c.plan.dependency_identity.dependency_hash))
    provider = get(_GRIDAP_B3_PROVIDER_CACHE, canonical_hash((capability, domain, code_hash)), nothing)
    provider === nothing && (provider = ProviderManifestV4(_GRIDAP_B3_SCHEMA, _GRIDAP_B3_REVISION,
        :gridap_weak_form_field_residual, capability, merge(domain,
        (bounds_hash=capability.applicability_bounds,)),
        "gridap-linear-fe-lu", "gridap-b3-execute-once-v1",
        code_hash,
        "gridap-weak-form-assembly-v1", screen_only,
        input_schema_hash=capability.input_schema_hash, executor=executor); _GRIDAP_B3_PROVIDER_CACHE[canonical_hash((capability, domain, code_hash))] = provider)
    payload = (compilation_hash=canonical_hash(c), domain=domain,
        provider_code_hash=code_hash,
        protocol=semantic_view(c.plan.protocol), dependency=c.plan.dependency_identity,
        source_content_hash=c.plan.source_content_hash,
        boundary_content_hash=c.plan.boundary_content_hash)
    subject = ExecutablePhysicalSubjectV4(c.plan.prefix_hash,
        c.plan.candidate_hash, c.plan.mission_hash,
        bounds_hash,
        _runtime_bindings(bindings), (scenario,), payload, (capability,))
    input = compile_solver_input(subject, scenario, capability, provider)
    _GRIDAP_B3_INPUTS[input.solver_input_hash] = c
    haskey(store,input.solver_input_hash) || pop!(_GRIDAP_B3_REPORTS,input.solver_input_hash,nothing)
    evidence = execute_once!(store, input, provider)
    report = get(_GRIDAP_B3_REPORTS, input.solver_input_hash, nothing)
    status = evidence.status_vector.stage_outcome === pass ? :pass :
        (evidence.status_vector.stage_outcome === numerical_fail ? :numerical_fail : :unknown)
    replay_body = (input_hash=input.solver_input_hash, provider_hash=provider.manifest_hash,
        subject_hash=subject.physical_subject_hash, scenario_hash=input.scenario_hash,
        plan_hash=c.plan.plan_hash, report_hash=(report === nothing ? nothing : report.report_hash),
        evidence_id=evidence.evidence_id, status=status)
    replay = GridapFieldReplayEnvelopeV4(_GRIDAP_B3_TOKEN, replay_body..., canonical_hash(replay_body))
    failure_reason = report === nothing ? "Gridap executor failed closed; no report or metrics" : nothing
    bundle_body = (compilation_hash=canonical_hash(c), subject_hash=subject.physical_subject_hash,
        provider_hash=provider.manifest_hash, input_hash=input.solver_input_hash,
        evidence_id=evidence.evidence_id, report_hash=(report === nothing ? nothing : report.report_hash),
        replay_hash=replay.envelope_hash, status=status, failure_reason=failure_reason)
    bundle=GridapFieldEvidenceBundleV4(_GRIDAP_B3_TOKEN, c, subject, provider, input,
        evidence, report, replay, status, failure_reason, canonical_hash(bundle_body))
    validate_gridap_field_evidence(bundle) || throw(ArgumentError("B3 bundle integrity mismatch"))
    bundle
end

function validate_gridap_field_evidence(b::GridapFieldEvidenceBundleV4)
    replay_body = (input_hash=b.replay.input_hash, provider_hash=b.replay.provider_hash,
        subject_hash=b.replay.subject_hash, scenario_hash=b.replay.scenario_hash,
        plan_hash=b.replay.plan_hash, report_hash=b.replay.report_hash,
        evidence_id=b.replay.evidence_id, status=b.replay.status)
    bundle_body = (compilation_hash=canonical_hash(b.compilation), subject_hash=b.subject.physical_subject_hash,
        provider_hash=b.provider.manifest_hash, input_hash=b.input.solver_input_hash,
        evidence_id=b.evidence.evidence_id, report_hash=(b.report === nothing ? nothing : b.report.report_hash),
        replay_hash=b.replay.envelope_hash, status=b.status, failure_reason=b.failure_reason)
    expected_domain=_b3_domain(b.compilation,b.input.payload.scenario)
    expected_capability=gridap_field_evidence_capability(b.compilation,
        b.input.payload.scenario,b.subject.bounds_hash)
    _gridap_compilation_integrity(b.compilation) &&
    canonical_hash(b.replay) == b.replay.envelope_hash &&
    canonical_hash(replay_body) == b.replay.envelope_hash &&
    b.replay.evidence_id == b.evidence.evidence_id &&
    canonical_hash(bundle_body) == b.bundle_hash &&
    b.input.provider_manifest_hash == b.provider.manifest_hash &&
    b.input.physical_subject_hash == b.subject.physical_subject_hash &&
    b.input.payload.materialized_payload.compilation_hash == canonical_hash(b.compilation) &&
    b.subject.compiled_prefix_hash == b.compilation.plan.prefix_hash &&
    b.subject.genome_bundle_hash == b.compilation.plan.candidate_hash &&
    b.subject.mission_hash == b.compilation.plan.mission_hash &&
    b.subject.scenarios == (b.input.payload.scenario,) &&
    b.provider.capability == expected_capability && b.provider.domain ==
        merge(expected_domain,(bounds_hash=expected_capability.applicability_bounds,)) &&
    b.input.payload.provider_code_hash == b.provider.code_hash &&
    b.provider.code_hash == canonical_hash((_gridap_b3_source_hash(),
        b.compilation.plan.adapter_code_hash,
        b.compilation.plan.dependency_identity.dependency_hash)) &&
    b.evidence.provider_manifest_hash == b.provider.manifest_hash &&
    b.evidence.physical_subject_hash == b.input.physical_subject_hash &&
    b.evidence.scenario_hash == b.input.scenario_hash &&
    b.evidence.solver_input_hash == b.input.solver_input_hash &&
    b.evidence.claim_ceiling === screen_only && (b.report === nothing || b.report.claim_ceiling === screen_only) &&
    (b.report === nothing || (b.report.credible_physical_candidate_count == 0 && !b.report.p5_ready)) &&
    b.replay.input_hash == b.input.solver_input_hash &&
    b.replay.report_hash == (b.report === nothing ? nothing : b.report.report_hash) &&
    b.replay.provider_hash == b.provider.manifest_hash &&
    b.replay.subject_hash == b.subject.physical_subject_hash &&
    b.replay.scenario_hash == b.input.scenario_hash &&
    b.replay.plan_hash == b.compilation.plan.plan_hash &&
    (b.report === nothing || (validate_gridap_field_residual_report(b.compilation,b.report) &&
    b.report.plan_hash == b.compilation.plan.plan_hash &&
    b.report.receipt.assembly_hash == b.report.result.receipt_hash &&
    b.evidence.artifact_refs == (b.report.report_hash, b.report.receipt.assembly_hash, b.report.result.result_hash))) &&
    b.status == b.replay.status &&
    (b.report === nothing || (b.failure_reason === nothing &&
        b.status == b.report.status && b.status in (:pass,:numerical_fail))) &&
    (b.report !== nothing || (b.status === :unknown && isempty(b.evidence.metrics) &&
        isempty(b.evidence.artifact_refs) && b.failure_reason !== nothing && !isempty(b.failure_reason)))
end

function replay_gridap_field_evidence!(store::AbstractDict, b::GridapFieldEvidenceBundleV4)
    validate_gridap_field_evidence(b) || return false
    replay = execute_once!(store, b.input, b.provider)
    replay.evidence_id == b.evidence.evidence_id && replay.status_vector == b.evidence.status_vector
end

"""Re-execute in a fresh store; unlike cache replay this proves deterministic identity."""
function replay_gridap_field_evidence_fresh(b::GridapFieldEvidenceBundleV4)
    fresh = Dict{Digest256,Any}()
    pop!(_GRIDAP_B3_REPORTS,b.input.solver_input_hash,nothing)
    replay = execute_once!(fresh, b.input, b.provider)
    report = get(_GRIDAP_B3_REPORTS,b.input.solver_input_hash,nothing)
    replay.evidence_id == b.evidence.evidence_id &&
        replay.status_vector == b.evidence.status_vector &&
        replay.artifact_refs == b.evidence.artifact_refs &&
        ((report === nothing && b.report === nothing) ||
         (report !== nothing && b.report !== nothing &&
          validate_gridap_field_residual_report(b.compilation,report) &&
          report.report_hash == b.report.report_hash))
end
