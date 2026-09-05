# FusionConceptAI v4 runtime implementation and physics-boundary plan

Status: implementation contract and acceptance plan; it is not physical evidence  
Normative inputs: `docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md`, `README.md`, and the separate G1/G2/G3 Genome documents  
Implementation priority: complete one auditable path through whole-device/VVUQ authority before increasing search scale or tuning search policy

## 1. Non-negotiable boundary

The v4 runtime composes the three existing Genome contracts. It does not redefine their genes, canonical forms, ownership, or admissibility rules. The runtime may normalize references, compile obligations, materialize declared alternatives, execute candidate-bound solvers, and assemble evidence. It may not invent a field source, boundary, component, controller, scenario, capability axis, or physical result that is absent from those contracts and the frozen mission.

Typed ASTs represent local mathematical programs. Operator hypergraphs bind those programs to states, regions, ports, conservation accounts, interfaces, boundaries, sources, sinks, controls, and events. Conditional e-graphs record bounded, replayable equivalence derivations. E-graph membership is an equality result under stated conditions; it is neither physical feasibility nor a pruning certificate by itself.

No generation, provider routing, hard gate, promotion, archive descriptor, or terminal decision may depend on device family, display name, candidate ID, parent identity, benchmark flag, request order, shard order, or a substring of a role. Provider routing is exact matching over a complete typed capability signature. An empty capability axis is invalid and is never a wildcard.

The goal of zero terminal `unsupported` results is reached only by implementing or attaching valid providers for every required capability, or by a candidate-bound applicability proof that an obligation is `not_applicable`. A missing provider remains `terminal_deferred` during the campaign. At frozen terminal closure, only the final authority may classify the unresolved obligation as `unsupported`. Renaming the obligation, changing its label, treating an empty axis as a wildcard, weakening a hard gate, or silently reducing the mission is not remediation.

Permanent pruning is restricted to a machine-verifiable, independently replayable `PruneCertificateV4` over a frozen grammar, bounds, mission, completion rule, and checker version. Low-fidelity failure, non-convergence, poor surrogate prediction, provider absence, and high cost do not prove that a completion subtree is empty.

Any minimality claim must carry a `MinimalityScopeV4` containing the grammar hash, bounds hash, mission hash, evidence level, scenario scope, and comparison scope. Complexity covers both structural Genome genes and mathematical basis coefficients. A candidate can only be simpler after a dependency-closed typed edit, a new physical-subject hash, and rerunning every affected hard gate.

## 2. Existing capability and present ceiling

The repository currently provides immutable P0 contracts, independent status dimensions, versioned references for the three Genome owners, layered hashes, typed AST programs, typed operator hypergraphs with conservation-account bindings, exact canonicalization, and a bounded conditional whole-program e-graph implementation. The G1/G2/G3 implementation is still being completed and is authoritative only to the extent covered by its current constructors and tests.

The current package accepts only complete `CandidateStatePackageV4` objects; it does not yet expose a normative partial-Genome wrapper. In addition, `FieldGeometryGenomeV4.fields` and the `RealizationControlGenomeV4.realization/control` payloads are still generic tuples. A first compiler can prove the closure already represented by typed graphs and closed genes, but it cannot infer complete spatial, boundary, component, control, or engineering capabilities from those open payloads. Every axis that is not derivable from a typed, contract-owned field remains an unresolved nonterminal and causes intermediate deferral. A later partial-Genome contract must be additive and must not pretend that the P0 full-package constructor represents an incomplete Genome.

`EvidenceContentV4` deliberately accepts only `none` and `screen_only`. Runtime work must not edit or bypass that constructor to claim stronger evidence. Higher-level runtime evidence must be a separate additive contract whose constructor validates the evidence source, provider manifest, solver input, scenario, independence group, artifacts, and stage-specific claim ceiling. A deterministic or reduced provider may exercise the full software path, but its manifest remains `screen_only`.

Historical implementations under `D:/006-Programing/LMC/outputs/fusion_concept_ai` are reference material only. In particular, a reduced multi-region runtime, role-string fallback, open-role fallback, or same-model LU/QR comparison cannot be promoted to a general high-fidelity provider, an independent dual-code result, or validation evidence. Historical artifacts do not upgrade current candidates.

With the resources visible to this repository, L0 software-contract checks and a bounded L1 screen can be implemented and replayed. Candidate-bound integrated multiphysics, independent dual-code evidence, engineering qualification, and validation VVUQ are not yet established. Until those resources exist and pass the protocols below, L4 credible-candidate count is exactly zero.

## 3. Additive module ownership

The initial runtime is isolated from the dirty package entrypoint. `src/RuntimeV4/FusionRuntimeV4.jl` is a child module that uses `FusionConceptAI` and includes runtime files. Standalone tests include this child module directly. The main package entrypoint and `test/runtests.jl` are changed only after the existing G1 work is clean and an integration commit can be reviewed separately.

| File or group | Sole responsibility | Must not do |
|---|---|---|
| `src/RuntimeV4/Contracts.jl` | Immutable runtime contracts, semantic views, constructor invariants | Run solvers, choose candidates, or emit terminal dispositions |
| `src/RuntimeV4/Compiler.jl` | Join G1/G2/G3 obligations and compile typed candidate prefixes | Guess missing axes or decide physical feasibility |
| `src/RuntimeV4/Capability.jl` | Capability signatures, provider manifests, exact match results, gap records | Route by labels or convert no-match to physical failure |
| `src/RuntimeV4/Execution.jl` | Materialization, exact solver-input compilation, execute-once cache, evidence sealing | Raise a provider's declared ceiling or treat cache replay as independence |
| `src/RuntimeV4/Proofs.jl` | Proof-certificate checking, no-good scope, replay | Use numerical samples or model scores as proof |
| `src/RuntimeV4/Search.jl` | Typed edits, prefix DAG, progressive widening, emitter scheduling | Write evidence or hard-gate decisions |
| `src/RuntimeV4/Archives.jl` | Deep-QD, failure frontier, dormant/revival, lineage, scoped Pareto | Compare across incompatible scopes or discard unproved candidates permanently |
| `src/RuntimeV4/Frontier.jl` | Stage freeze, strict merge, hard-gate admission, false-negative audit | Compensate a hard gate with novelty, cost, or predicted score |
| `src/RuntimeV4/WholeDevice.jl` | Integrated closure protocol, scenario execution, numerical and validation VVUQ assembly | Call reduced or same-model checks independent validation |
| `src/RuntimeV4/Authority.jl` | Final obligation audit, terminal disposition, claim ladder, minimality wording | Invent evidence, rerun search, or infer missing engineering validation |
| `src/RuntimeV4/Campaign.jl` | Frozen manifest, sharding, checkpoint/resume, strict merge, count firewall | Mutate a frozen campaign or merge incompatible shards |
| `src/RuntimeV4/Providers/` | One adapter and manifest per concrete solver capability | Expose backend-specific types in Genome or evidence contracts |
| `scripts/` | Reproducible entrypoints and reports | Contain hidden routing, physics, or authority policy |
| `test/runtime_v4_*.jl` | Unit, adversarial, replay, integration, and claim-firewall tests | Assert high-fidelity or validation success using mocks |

Provider adapters may be implemented in Julia or invoke Python executables. The public contracts, hashes, statuses, manifests, and authority stay backend-neutral. A Python backend communicates through a versioned, canonical input/output schema and content-addressed artifacts; Python object identity and environment-dependent dictionary order never enter hashes.

## 4. Stable runtime interfaces

The first vertical slice fixes the following semantics. Concrete field types may be tightened without changing their meaning.

```text
MinimalityScopeV4
  grammar_hash, bounds_hash, mission_hash,
  evidence_level, scenario_scope, comparison_scope

CapabilitySignatureV4
  capability_kind, operator_ref, physical_states,
  source_space, target_space,
  dimension, coordinates,
  boundary_relation, interface_relation,
  time_semantics, required_output,
  evidence_level, input_schema_hash,
  applicability_bounds_hash

ProviderManifestV4
  provider_id, backend_revision, manifest_hash,
  signatures, applicability_domain,
  independence_group, maximum_claim_ceiling,
  input_schema_hash, output_schema_hash

CompiledCandidatePrefixV4
  candidate_ref, genome_bundle_hash,
  normalized_graphs, state_slots,
  conservation_accounts, source_sink_ledger,
  sensor_actuator_paths, obligations,
  unresolved_nonterminals, assessments,
  semantic_hash, resolution

ExecutablePhysicalSubjectV4
  genome_bundle_hash, exact_bindings,
  scenario_manifest_hash, physical_subject_hash

SolverInputV4
  physical_subject_hash, scenario_hash,
  provider_manifest_hash, payload,
  solver_input_hash

RuntimeEvidenceV4
  evidence_id, solver_input_hash,
  provider_manifest_hash, status_vector,
  metrics_with_units, uncertainty_or_null,
  artifact_refs, independence_group,
  claim_ceiling, provenance

StageDecisionV4
  stage, required_obligations, evidence_refs,
  gate_results, outcome, unresolved_obligations,
  permitted_next_stages

WholeDeviceEvidencePackageV4
  physical_subject_hash, integrated_solver_graph_hash,
  scenario_manifest_hash, coupled_residual_audit,
  hard_gate_summary, engineering_summary,
  control_and_fault_summary, numerical_vvuq_summary,
  cross_code_summary, validation_vvuq_summary,
  unresolved_obligations, all_evidence_refs,
  claim_ceiling

FinalDecisionV4
  physical_subject_hash, frozen_scopes,
  terminal_disposition, claim_ceiling,
  passed, failed, unknown, unsupported,
  not_applicable_proofs, evidence_refs,
  authority_version_hash
```

Required public operations are:

```julia
compile_candidate(candidate, registry, mission, bounds)::CompiledCandidatePrefixV4
derive_capability_obligations(compiled)::Tuple
verify_prune_certificate(certificate, frozen_scope)::ProofReplayResultV4
apply_typed_edit(prefix, edit, grammar)::CompiledCandidatePrefixV4
match_provider(obligation, manifests)::ProviderMatchV4
materialize(compiled, bindings, scenarios)::ExecutablePhysicalSubjectV4
compile_solver_input(subject, scenario, provider)::SolverInputV4
execute_once!(store, input, provider, backend)::RuntimeEvidenceV4
advance_frontier!(frontier, evidence, policy)::StageDecisionV4
admit_whole_device(frontier, subject, scenario_manifest, provider_registry, protocol)::WholeDeviceAdmissionV4
run_integrated_whole_device(subject, scenario_manifest, providers)::WholeDeviceEvidencePackageV4
run_numerical_vvuq(subject, protocol, providers)::NumericalVVUQSummaryV4
run_validation_vvuq(subject, protocol, validation_sources)::ValidationVVUQSummaryV4
audit_whole_device_closure(admission, package, protocol)::ClosureAuditV4
final_classify(package, authority, minimality_scope)::FinalDecisionV4
```

`solver_input_hash` is derived inside its constructor from the exact subject, scenario, provider manifest, numerical configuration, and canonical payload. The caller cannot supply a trusted hash. `RuntimeEvidenceV4` is similarly content addressed. Proposal predictions have no conversion method to evidence metrics or stage outcomes.

Provider matching returns an explicit unique, no-match, ambiguous, out-of-domain, or invalid-signature result. Every non-unique result produces a capability-gap record and `terminal_deferred` at intermediate stages. It does not execute a backend.

Whole-device admission and whole-device closure are separate. Admission is a pre-execution readiness decision. It checks prior hard-gate evidence, required provider and protocol availability, the frozen scenario manifest, input materialization, and resource readiness; it cannot require the integrated result that it authorizes. Closure is post-execution. It checks integrated residual evidence, scenario results, numerical VVUQ, cross-code evidence, engineering evidence, validation VVUQ, and remaining obligations. Failed admission returns a complete gap record without invoking an integrated backend. Passed admission does not imply that closure or any physical gate will pass.

## 5. Chain-first implementation order

The normative documents retain their V4-P0 through V4-P6 meanings. Implementation proceeds in vertical waves so that missing physical capability becomes visible early.

### Wave A: bounded end-to-end spine

Implement runtime contracts, candidate compilation, capability matching, materialization, solver-input hashing, execute-once behavior, a deterministic screen-only provider, stage decisions, a whole-device admission refusal with explicit readiness gaps, a post-execution closure audit that reports missing evidence without fabricating a package, and a final authority that refuses credible or unsupported intermediate claims. The command-line run must finish with separate counts and L4 credible count zero.

This wave proves software wiring, not physical performance. It must complete before Deep-QD, MCTS, surrogate training, or large candidate generation.

### Wave B: real provider closure

Add repository-owned adapters and manifests for concrete capabilities. Each adapter first passes sentinel, negative-control, applicability, units, determinism, convergence, and artifact-replay tests. Only then may it contribute candidate-bound evidence. Missing capabilities stay in the gap queue, which drives provider implementation priority.

The minimum whole-device provider graph must account for:

- field/source and boundary realization;
- orbit, confinement, or open-boundary loss obligations when applicable;
- finite-pressure equilibrium or the corresponding candidate-declared state closure;
- candidate-bound stability obligations;
- transport, reactions, radiation, self-heating, and actuator feedback in one coupled residual rather than post-processing a linear state;
- material, thermal, structural, resource, power, control, protection, and fault-scenario obligations declared by G3 and the mission;
- dimensional, coordinate, interface, conservation, Jacobian-slot, and exclusive-output audits.

The integrated provider graph is compiled from capability obligations. It is not selected by a device label. Reduced models may provide initial guesses or homotopy stages, but their results keep their reduced ceiling.

### Wave C: VVUQ and independent evidence

Numerical VVUQ includes mesh or basis order, time step, nonlinear tolerance, initial condition, scenario, parameter, and manufacturing uncertainty studies with uncertainty propagated to every hard-gate margin. Dual-code evidence requires two declared independence groups, the same physical subject, audited coordinate/unit transformations, preregistered observables and tolerances, and disclosure of shared libraries, meshes, or calibration data. LU versus QR within one model is a numerical sensitivity check, not dual-code evidence.

Validation VVUQ is a separate protocol. It requires candidate-bound mapping to independent measurements, measurement uncertainty, calibration/validation separation, comparable observables, extrapolation bounds, and a discrepancy model. Manufactured controls and synthetic outputs are regression fixtures only. They are not validation of a real device.

### Wave D: search, proof pruning, and optimization

After the vertical spine exposes capability and cost bottlenecks, add replayable proof pruning, Deep-QD, infeasible and dormant archives, progressive-widening MCTS, and multi-emitter scheduling. Search uses typed edits and recompiles every descendant. Every emitter keeps a non-zero frozen minimum budget. Model predictions control proposal order and budget only.

Survivor sparsification and scoped Pareto run only after required hard gates pass with candidate-bound evidence. Structure genes and basis coefficients are ablated together through dependency-closed edits. No `unknown` or `terminal_deferred` quantity is converted into a favorable numeric score.

### Wave E: campaign scale

Run a frozen, restartable medium campaign over roughly 50 to 100 semantic/capability cells and 500 to 1,000 unique physical inputs only after provider gaps no longer dominate, integrated evidence is non-zero, cache and strict merge are stable, and false-negative audits are within the preregistered interval. Scaling proposal count before these conditions is a software load test, not expanded physical coverage.

## 6. Phase acceptance matrix

| Phase | Deliverable | Acceptance evidence that can be automated | Physics/resource condition | Current disposition |
|---|---|---|---|---|
| P0 | Frozen contract refs, independent states, hashes, authority separation | Contract mismatch defers; label erasure and graph permutation preserve semantic hashes; no intermediate terminal factory | None beyond repository contracts | Largely implemented; rerun after current G1 changes |
| P1a | Runtime contracts, compiler, router, execution cache | Complete axes required; exact unique/no/multi/out-of-domain matching; no-match does not execute; same input executes once | Deterministic fixtures | Implementable now |
| P1b | Typed partial compiler and proof authority | Every obligation traces to a Genome/mission gene; unresolved fields defer; every permanent prune replays; changed scope invalidates proof | SMT/MILP/interval checker as applicable | Compiler implementable now; general proof coverage remains incremental |
| P2 | Deep-QD, failure/dormant archives, replayable typed edits | K-deep cells retain lineages; failed candidates revive; proof-pruned cannot bypass certificate; emitter budget never reaches zero | Meaningful descriptors require real evidence for physical axes | Software layer implementable; physical descriptors stay null until evidence exists |
| P3 | Prefix DAG, MCTS, exact input compiler, independent executor | Action order invariance; DAG retains all lineages; three boundary cases use one contract path; proposal removal leaves decisions unchanged | At least one valid provider per tested capability cell | Screen-only vertical slice implementable; broad coverage missing |
| P4 | Frozen stage frontier, false-negative audit, scoped Pareto | Shard order invariance; strict schema/hash merge; affected gates rerun after edits; rank reversal and false-negative reports | Paired low/high-fidelity providers and compute budget | Framework implementable; empirical calibration needs providers/HPC |
| P5a | Coupled whole-device execution | All declared residual blocks, interfaces, conservation accounts, scenarios, and numerical configurations are audited and replayable | Valid multiphysics backends, geometry/material inputs, sufficient compute | Not currently demonstrated |
| P5b | Numerical VVUQ and dual-code | Convergence margins; uncertainty propagation; two independence groups; preregistered discrepancy handling | Independent implementations and compute allocation | Not currently available |
| P5c | Validation VVUQ and engineering scenarios | Calibration/validation split; candidate/experiment mapping; measurement uncertainty; all required fault scenarios | Admissible experimental data, engineering models, reviews, and hardware evidence | Not currently available |
| P5d | Final authority and claim ladder | Only final authority emits terminal decision; all unresolved obligations listed; L0-L3 cannot be called credible physical device; minimality scope complete | L4 requires P5b/P5c evidence | Refusal and audit paths implementable; credible L4 is not |
| P6 | Medium frozen campaign | Checkpoint/resume, strict shard merge, content-addressed counts, duplicate firewall, reproducible archive and report | Stable provider coverage and compute budget | Blocked by P5 provider/evidence gaps |

## 7. Required adversarial and claim-firewall tests

The runtime is not accepted without the following negative controls:

1. Changing display name, family, candidate ID, parent, benchmark flag, request order, or shard order does not alter routing, solver input, evidence, or final decision.
2. Removing any required capability axis makes the signature invalid rather than broader.
3. A provider with one mismatched axis cannot match; two exact providers are ambiguous until an explicit, non-label protocol resolves the requirement.
4. Contract mismatch, unknown migration, missing provider, and unavailable validation remain distinct deferred or unknown states.
5. Non-convergence never becomes physical failure; partial output never becomes pass.
6. A surrogate, MCTS statistic, novelty score, cost estimate, or generated explanation cannot inhabit an evidence field.
7. A cache replay cannot create a second independence group or increase claim ceiling.
8. A reduced solver, manufactured control, mock result, same-model factorization comparison, or historical artifact cannot satisfy high-fidelity, dual-code, engineering, or validation obligations.
9. Unavailable metrics serialize as `null` plus reason, never zero, infinity, empty success, or default pass.
10. Changing grammar, bounds, mission, completion rule, checker, provider manifest, numerical configuration, or scenario produces a new relevant hash and invalidates affected cache/proof decisions.
11. A physical edit creates a new subject hash and forces every affected hard gate to rerun.
12. Final classification with any required deferred obligation cannot be credible. Intermediate code cannot emit terminal `unsupported`.
13. Minimality comparison rejects candidates with different frozen scope and rejects any complexity improvement that loses robustness or evidence depth.
14. Report counts keep proposals, prefixes, semantic structures, physical subjects, solver inputs, stage outcomes, integrated executions, terminal decisions, and credible levels separate.

## 8. Provider-gap closure and zero-unsupported policy

Every no-match, ambiguous, out-of-domain, and invalid-signature result creates a `CapabilityGapRecordV4` keyed by the full obligation signature, grammar/bounds/mission hashes, affected candidate count, earliest blocked stage, and required evidence level. Reports group gaps by exact capability equality, never by device family. The queue order may use affected-candidate count, hard-gate depth, expected implementation cost, and information gain, but those values do not change candidate status.

A capability gap closes only when a new or corrected manifest passes signature validation, applicability tests, sentinel and negative controls, numerical qualification, and artifact replay. All deferred candidates whose exact obligation now matches are recompiled and re-executed. Existing evidence remains immutable.

Formal terminal closure is a separate operation from ordinary campaign progress. It may be invoked only after the frozen provider registry and retry policy are exhausted. If an obligation remains without a legal path, the final authority reports it as terminal `unsupported`; the system does not hide that result to satisfy a zero count. Therefore a true zero-unsupported campaign is an evidence-backed provider-coverage result, not a reporting option.

## 9. Whole-device evidence and claim ladder

L0 means grammar-valid and compilable. L1 means specified low-fidelity hard gates passed. L2 means candidate-bound equilibrium, stability, transport, or other declared obligations reached the stated depth. L3 means integrated numerical whole-device closure and numerical VVUQ passed within a declared model. L4 additionally requires the declared engineering scenarios and independent validation evidence. L5 requires stronger external experimental or engineering qualification and is not produced automatically by v4.

Only L4 or higher may be described as a credible physical-device candidate within the exact evidence scope. L3 is an integrated numerical candidate. Until P5b and P5c have real evidence, the report must say that the credible physical-device candidate count is zero. A successful software test, screen-only provider, historical run, manufactured control, or synthetic validation fixture does not change that count.

## 10. Commit and integration gates

Each implementation step is reviewed and pushed as its own additive commit. Before each commit, record `git status`, stage only the owned new files, and verify that the pre-existing G1 changes are absent from the staged diff. Run the narrow standalone test first, then the package baseline after the current G1 work permits it. Integration into `src/FusionConceptAI.jl` and `test/runtests.jl` is a separate commit after the child module passes standalone tests and the dirty worktree has been reconciled by its owner.

Every pushed step reports exactly what was proven: compilation, canonicalization, routing, replay, screen execution, integrated numerical evidence, numerical VVUQ, validation VVUQ, or engineering evidence. These labels are never collapsed into a generic `pass`.
