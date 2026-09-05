# Runtime V4 stage and closure contract

This document fixes the software contract for the P2--P5 orchestration spine. It does not grant physical authority. The current runtime can close a declared structural or reduced screening stage only when it has candidate-bound execution evidence. It cannot set `p5_ready=true` until the separate whole-device, numerical VVUQ, independent-code, engineering, and validation evidence types exist and pass.

## 1. Required separation

The spine has three different predicates. They must not share a Boolean or infer one another.

1. **Provider coverage** means every exact `CapabilitySignatureV4` has exactly one matching `ProviderManifestV4` in the frozen registry.
2. **Stage evidence closure** means every required signature and every required scenario has exactly one valid, candidate-bound evidence binding at the required ceiling.
3. **P5 completion** means the complete whole-device completion protocol has all required evidence kinds. Stage evidence closure, including a closed `screen_only` stage, is insufficient.

`admit_*` checks readiness before executing the current stage. `close_*` checks results after execution. Admission must not require the current stage result, and closure must not treat provider matching as execution evidence.

## 2. Frozen requirement forms

A stage requirement is either executable or explicitly unresolved. Missing capability axes must not be filled with a plausible-looking signature.

```julia
abstract type AbstractStageRequirementV4 end

struct ExactCapabilityRequirementV4 <: AbstractStageRequirementV4
    signature::CapabilitySignatureV4
    requirement_hash::Digest256       # derived from signature
end

struct UnresolvedStageDeclarationV4 <: AbstractStageRequirementV4
    code::Symbol                      # non-empty, non-wildcard
    missing_axes::Tuple{Vararg{Symbol}}
    source_hash::Digest256            # compiler or frozen protocol content hash
    required_ceiling::ClaimCeiling
    requirement_hash::Digest256       # derived from all preceding fields
end
```

An unresolved declaration always produces a gap. It cannot match a provider and cannot carry evidence. The constructor rejects an empty `missing_axes`, duplicate axes, wildcards, and a caller-supplied hash.

`StageSpecV4` contains a non-empty tuple of `AbstractStageRequirementV4`. A compatibility constructor may wrap existing `CapabilitySignatureV4` values in `ExactCapabilityRequirementV4`. The combined requirement tuple must never be empty. A stage also requires:

- a non-empty, non-wildcard stage identifier;
- a unique prerequisite list that excludes the stage itself;
- a non-empty required scenario scope, unless it carries an explicit unresolved mission-scenario declaration;
- a required evidence ceiling and a content-derived `spec_hash`.

`freeze_campaign` rejects an empty stage tuple, duplicate stage identifiers, unknown prerequisites, forward references, cycles, duplicate scenario identifiers, and any stage scenario reference outside the frozen campaign. Tuple order is the topological order and enters the campaign hash.

If the mission does not declare the scenarios needed by a physical stage, the campaign records an unresolved mission-scenario declaration. The CLI must not invent startup, fault, or validation scenarios for a software fixture.

## 3. Exact scenario scope

For the current representation, a scenario is an immutable canonical `NamedTuple` with a string `name`. The name must be non-empty, non-wildcard, and unique in the campaign. It is an identifier, not a device-family routing key.

Stage scenario selection is exact:

```julia
function stage_scenarios(spec, campaign_scenarios)
    by_name = unique_checked_map(s.name => s for s in campaign_scenarios)
    Set(keys(by_name)) >= Set(spec.scenario_scope) || error("missing required scenario")
    selected = Tuple(by_name[name] for name in spec.scenario_scope)
    Set(String(s.name) for s in selected) == Set(spec.scenario_scope) || error("scope mismatch")
    selected
end
```

Every closure obligation is the Cartesian product of exact capability requirements and the selected required scenarios. Passing one of two required scenarios cannot close the stage.

## 4. Provider coverage

Coverage is derived inside the spine. Caller-supplied match summaries and free-form named tuples are not authoritative.

```julia
function provider_coverage(spec, providers)
    results = Tuple((requirement=req,
                     result=match_provider(req.signature, providers))
                    for req in exact_requirements(spec))
    complete = all(x -> x.result.status == unique_match &&
                        x.result.obligation_hash == canonical_hash(x.requirement.signature),
                   results)
    gaps = derived_provider_gaps(results)
    (; complete, results, gaps)
end
```

The frozen provider-registry hash must be stored in the admission object. The closure audit either uses that same registry hash or rejects the audit. A non-empty provider list is not coverage.

## 5. Evidence binding constructor

The evidence binding takes the subject explicitly. Its hashes are derived; none are caller-supplied.

```julia
struct StageEvidenceBindingV4
    stage::Symbol
    spec_hash::Digest256
    signature_hash::Digest256
    scenario_hash::Digest256
    physical_subject_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Digest256
    evidence_id::Digest256
    input::SolverInputV4
    evidence::RuntimeEvidenceV4
    match::ProviderMatchResultV4
    binding_hash::Digest256
end

function StageEvidenceBindingV4(spec, signature, scenario,
                                subject::ExecutablePhysicalSubjectV4,
                                input::SolverInputV4,
                                evidence::RuntimeEvidenceV4,
                                match::ProviderMatchResultV4)
    sig_hash = canonical_hash(signature)
    scenario_hash = canonical_hash(scenario)

    require(any(req -> req isa ExactCapabilityRequirementV4 &&
                       canonical_hash(req.signature) == sig_hash,
                spec.requirements))
    require(String(scenario.name) in spec.scenario_scope)

    require(match.status == unique_match && match.provider !== nothing)
    require(match.obligation_hash == sig_hash)
    require(match_provider(signature, (match.provider,)).status == unique_match)

    require(input.physical_subject_hash == subject.physical_subject_hash)
    require(input.scenario_hash == scenario_hash)
    require(input.provider_manifest_hash == match.provider.manifest_hash)
    require(input.input_schema_hash == match.provider.input_schema_hash)
    require(hasproperty(input.payload, :requested_obligation))
    require(canonical_hash(input.payload.requested_obligation) == sig_hash)

    require(evidence.physical_subject_hash == subject.physical_subject_hash)
    require(evidence.scenario_hash == scenario_hash)
    require(evidence.solver_input_hash == input.solver_input_hash)
    require(evidence.provider_manifest_hash == match.provider.manifest_hash)
    require(evidence.claim_ceiling <= match.provider.claim_ceiling)

    status = evidence.status_vector
    require(status.applicability == required)
    require(status.match_status == unique_match)
    require(status.resolution == resolved)
    require(status.stage_outcome == pass)
    require(evidence.claim_ceiling >= spec.required_ceiling)

    return construct_with_content_derived_hashes(...)
end
```

The validated constructor must be an inner constructor, or it must call an inner constructor that requires a module-owned validation token. The type must not expose Julia's automatic all-fields constructor, because that would let a caller supply `binding_hash` and bypass every check above. The real implementation uses `_runtime_ceiling_rank` for ceiling comparisons. It also checks all values are canonicalizable before deriving `binding_hash`.

For every `(signature_hash, scenario_hash)` pair, closure requires exactly one binding whose `stage`, `spec_hash`, subject hash, registry hash, and evidence chain validate. Zero bindings produce `missing_stage_evidence`. More than one produces `ambiguous_stage_evidence`; duplicates must not disappear through a `Set`.

## 6. Prerequisite closure

Admission and closure decisions need immutable identities:

```julia
struct StageDecisionV4
    stage::Symbol
    spec_hash::Digest256
    physical_subject_hash::Union{Nothing,Digest256}
    provider_registry_hash::Digest256
    admitted::Bool
    closure_complete::Bool
    outcome::Symbol                # :admitted, :evidence_closed, or :withheld
    required_obligations::Tuple
    evidence_refs::Tuple
    unresolved_gaps::Tuple
    claim_ceiling::ClaimCeiling
    decision_hash::Digest256          # derived from all preceding fields
end
```

An admission decision always has `closure_complete=false`. A post-run decision may set `closure_complete=true` and `outcome=:evidence_closed` only after exact evidence closure. This is an intermediate software state and is not a terminal physical disposition. As with evidence bindings, a validated inner constructor must disable the automatic raw all-fields constructor. The inner constructor derives `decision_hash` and enforces the allowed state combinations; a caller cannot set `closure_complete=true` independently of the evidence bindings and gap set.

For each prerequisite identifier in `spec.prerequisites`, admission requires exactly one earlier decision with:

- the same stage identifier and the `spec_hash` of that frozen earlier stage;
- the same physical subject hash and provider-registry hash;
- `closure_complete=true`, `outcome=:evidence_closed`, and no unresolved gaps.

Missing, duplicated, merely admitted, withheld, failed, or foreign-campaign prerequisite decisions produce a derived `prerequisite_not_closed` gap.

## 7. Admission and closure algorithms

The preferred whole-device interface consumes the frozen campaign rather than an unbound tuple of specs:

```julia
admit_whole_device(campaign::FrozenCampaignV4,
                   subject::Union{Nothing,ExecutablePhysicalSubjectV4};
                   providers, hard_gate_decisions,
                   protocol_manifest, resource_manifest,
                   prior_stage_decisions)::WholeDeviceAdmissionV4

audit_whole_device_closure(admission::WholeDeviceAdmissionV4,
                           campaign::FrozenCampaignV4;
                           providers, evidence_bindings,
                           p5_evidence=nothing)::WholeDeviceClosureV4
```

Admission checks a complete subject, exact scenario scope, exact provider coverage, non-empty typed hard-gate decisions, protocol and resource readiness, unresolved declarations, and exact prerequisite closure. It never asks for the current stage execution result.

Closure first verifies `campaign_hash`, physical subject hash, and provider-registry hash against the admission object. It then performs the exact one-binding-per-signature-per-scenario audit. All gaps are derived from frozen requirements, scenarios, prerequisites, and validation failures. A fixed `known_gaps` count is forbidden.

Objects supplied back to an audit are revalidated from their content-derived hashes. An automatic raw constructor for `WholeDeviceAdmissionV4` or `WholeDeviceClosureV4` must not provide a path around admission and decision validation.

The `provider_coverage_complete` field records only exact routing coverage. It remains independent from evidence closure and P5 completion.

## 8. P5 completion firewall

`p5_ready` is false in the present implementation. The current `RuntimeEvidenceV4` and `ProviderManifestV4` intentionally cap produced evidence at `screen_only`.

A future implementation may set `p5_ready=true` only after typed, candidate-bound objects exist for all of the following and the frozen completion policy requires them:

1. integrated whole-device coupled residual and conservation closure;
2. numerical VVUQ, including mesh/basis/time-step and solver-tolerance sensitivity;
3. two admissible code results with distinct declared independence groups and the same physical subject;
4. engineering and control evidence for every mission-required scenario;
5. validation VVUQ with measurement uncertainty, calibration/validation separation, observable mapping, extrapolation bounds, and discrepancy model.

A same-model LU/QR comparison, cache replay, structural screen, reduced residual solve, manufactured control, or synthetic regression fixture satisfies none of these P5 evidence kinds. The terminal authority remains `:withheld` until the dedicated authority implementation validates the complete package.

## 9. Default complete stage manifest

The default CLI freezes and audits the complete declared ladder. Stage names describe protocol positions; providers are still selected only by exact capability signatures.

| Stage | Prerequisite | Required ceiling |
|---|---|---|
| `s0_compiled_materialized` | none | `screen_only` |
| `s1_analytic_certified_bounds` | S0 | `screen_only` |
| `s2_field_source_realization` | S1 | `candidate_bound` |
| `s3_trajectory_or_loss` | S2 | `candidate_bound` |
| `s4_finite_pressure_equilibrium` | S3 | `candidate_bound` |
| `s5_applicable_stability` | S4 | `candidate_bound` |
| `s6_transport_reaction_power` | S5 | `candidate_bound` |
| `s7_engineering_control_scenarios` | S6 | `whole_device_vvuq` |
| `s8_integrated_high_fidelity_numerical_vvuq` | S7 | `whole_device_vvuq` |
| `s9_independent_cross_code` | S8 | `whole_device_vvuq` |
| `s10_validation_vvuq` | S9 | `validation_vvuq` |

The S0--S8 portion follows the normative frontier ladder. S9 and S10 expose the independent-code and validation sub-protocols from the whole-device VVUQ specification as separate audit stages so their absence cannot be hidden inside one Boolean.

Where the compiler has an exact signature, the manifest stores `ExactCapabilityRequirementV4`. Where the current Genome, mission, or protocol lacks operator, coordinate, boundary, ABI, scenario, independence, or validation axes, it stores `UnresolvedStageDeclarationV4` with the exact missing axes and source hash. The default software fixture may declare its actual structural-test scenario for S0. It must record unresolved mission scenario scope for later physical stages rather than inventing physical scenarios.

The CLI must traverse the entire manifest through the post-run closure audit and print each derived stage gap. On current resources, this is a real full-chain gap audit with `p5_ready=false`, terminal authority withheld, and credible physical candidate count zero.

## 10. Required tests

The spine change is accepted only with executable tests for:

1. empty requirements, stages, and campaign rejection;
2. exact required-scenario equality and a two-scenario case where one evidence binding is missing;
3. exact provider coverage with no evidence, which admits execution readiness but does not close the stage;
4. wrong signature, spec, scenario, subject, input-schema, provider, solver-input, and evidence hashes rejected by the binding constructor;
5. duplicate evidence bindings producing an ambiguity gap;
6. a prerequisite that is missing, merely admitted, withheld, or bound to another spec/subject/registry being rejected;
7. a valid prior evidence-closed decision admitting the next stage;
8. `screen_only` evidence closing a screen stage while `p5_ready` stays false;
9. `screen_only` evidence failing a higher-ceiling stage;
10. one compilation per spine run, identical `report.compiled.prefix_hash` and `report.p1.compiled.prefix_hash`, and real scenario identifiers in `MinimalityScopeV4`;
11. the default empty provider registry producing gaps derived from the complete frozen manifest;
12. changing a frozen stage requirement changing the exact gap set and campaign hash.
