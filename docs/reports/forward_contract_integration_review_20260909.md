# Forward-contract integration review — 2026-09-09

## Executive verdict

**Split verdict.** Reject integration and commit of the multi-region coupling,
multi-region diffusion, engineering/control/fault, and validation/UQ modules.
Accept Gridap B2 and B3 only as isolated `screen_only` qualification/evidence
modules. None of the six is ready to be included/exported by
`FusionRuntimeV4.jl` or represented as a closed forward chain.

| Module | Focused state observed | Integration verdict | Decisive reason |
|---|---:|---|---|
| Multi-region coupling contract | 7/7 pass | **REJECT** | A `ready` contract can contain empty regions and declared channels with no flux binding. |
| Multi-region diffusion provider | test exits 1 before assertions | **REJECT** | Stale test aside, it is explicitly standalone, not subject/provider/evidence-bound, does not consume the typed flux binding, and has incomplete units/integrity/replay. |
| Engineering/control/fault contract | 12/12 pass | **REJECT** | The Genome registry comparison is type-incompatible; compiled/subject/scenario are optional and unused; evidence is self-declared. |
| Validation/UQ contract | 6/6 pass | **REJECT** | The only tests are constructor negatives; the binding is forgeable/incompatible with real runtime subjects and a fabricated contract can receive physical credit. |
| Gridap B2 convergence | 17/17 pass; runner pass | **ACCEPT B2 only** | Exact plan/series/B1 assembly identity and real Gridap L2/H1 orders are verified at `screen_only`. |
| Gridap B3 evidence | 18/18 pass; runner pass | **ACCEPT B3 only** | Exact context/provider/subject/input/evidence binding, stable execute-once identity, validated failure envelope, and cache/fresh replay are closed at `screen_only`. |

The previously reviewed, committed Gridap B1 adapter remains **ACCEPTED B1
ONLY** as a real Gridap manufactured software control at `screen_only`. The B2
and B3 verdicts accept only their isolated manufactured qualification and
evidence-envelope scopes. They do not accept Batch B, VVUQ, engineering
closure, whole-device closure, or a credible physical candidate.

## Scope and repository state

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Accepted snapshot now recorded at `main@c90e0ad`: B2 was committed separately
  at `85f72f8`, then B3 at `c90e0ad`.
- The four rejected forward-contract prototypes and their local tests/docs
  remain untracked. B2/B3 were untracked during review and were committed only
  after the final focused and runner gates passed.
- `src/RuntimeV4/FusionRuntimeV4.jl:5-21` does not include any of the six
  modules, and its export list at lines 23-73 does not export their APIs.
  Focused tests use `Base.include`; successful focused tests therefore do not
  demonstrate package integration.
- The independent reviewer authored only these two review documents; B2/B3
  source repairs, isolated commits, and pushes were performed by the primary
  integration path after the recorded verdicts.

## Normative gate used

The current v4 contracts require the same candidate-bound physical subject and
scenario across the forward chain, complete three-Genome identity, typed
AST/operator-hypergraph ownership, unit/conservation proof, and separate
`physical_fail`, `numerical_fail`, `unknown`, deferred, and unsupported states.
The relevant requirements are explicit in:

- `docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md:9-15,21-34,67-83,130-146,165-169`;
- `docs/v4_multitopology_generation/08_high_fidelity_whole_device_vvuq.md:5-14,38-45,68-85,98-126`;
- `docs/v4_multitopology_generation/09_evidence_authority_campaign_and_v4_roadmap.md:5-19,32-58,92-129,138-146,179-208`.

In particular, manufactured and cross-code controls cannot acquire physical
credit, missing required scenarios cap the whole-device conclusion, and only
`FinalWholeDeviceAuthorityV4` may issue terminal `credible_within_scope` or
terminal `unsupported`.

## Commands and observed results

All commands below were run from the repository root. Gridap tests used the
pinned qualification project; non-Gridap tests used the root project.

| Command | Observed result | Exit |
|---|---|---:|
| `julia --project=. test/runtime_v4_multiregion_coupling_contract_tests.jl` | 7/7 pass | 0 |
| `julia --project=. test/runtime_v4_multiregion_diffusion_provider_tests.jl` | fixture errors before assertions: `interface flux bindings must be typed` | 1 |
| `julia --project=. test/runtime_v4_engineering_control_fault_contract_tests.jl` | 7/7 + 5/5 pass | 0 |
| `julia --project=. test/runtime_v4_validation_uq_contract_tests.jl` | 6/6 pass | 0 |
| `julia --startup-file=no --history-file=no --project=tools/qualification/gridap test/runtime_v4_gridap_field_evidence_tests.jl` | 9/9 + 9/9 pass | 0 |
| `julia --startup-file=no --history-file=no --project=tools/qualification/gridap scripts/run_v4_gridap_field_evidence.jl` | `GRIDAP_B3_OK`; fresh replay and `screen_only` checks pass | 0 |
| `julia --startup-file=no --history-file=no --project=tools/qualification/gridap test/runtime_v4_gridap_field_convergence_tests.jl` | 17/17 pass | 0 |
| `julia --startup-file=no --history-file=no --project=tools/qualification/gridap scripts/run_v4_gridap_field_convergence.jl` | `GRIDAP_B2_OK`; L2/H1 orders in frozen bands | 0 |

Earlier B2 runs overlapped active rewrites and exposed stale fixture, protocol
ownership, unbound Gridap expression, and tuple-comparison errors. Those runs
are not used as acceptance evidence. The completed source and test snapshot was
rerun cleanly: focused 17/17 and runner exit 0. Only those final results support
the B2 verdict below.

For reference, the accepted B1 evidence remains the independently recorded
pinned result: 75/75 focused assertions, runner exit 0, Julia 1.10.5, Gridap
0.20.8, residual infinity norm `2.220446049250313e-16`, claim ceiling
`screen_only`, numerical VVUQ `terminal_deferred`, credible physical count 0,
and `p5_ready=false`.

## Module findings

### 1. Multi-region coupling contract — REJECT

Useful local work is present: the constructor binds prefix/candidate/mission/
bounds/mechanism-graph hashes (`MultiRegionCouplingContracts.jl:70-98`), and
the validator checks typed interface edges, endpoint ownership, orientation,
ledger identity, units, and conservative coefficient pairs
(`:122-181`). Those are appropriate ingredients, but the accepted state is
not closed.

Blocking findings:

1. `MultiRegionRefV4` allows an empty `node_refs` tuple (`:15-24`). The
   validator checks only that existing references are in range (`:138-142`),
   so two empty regions satisfy the region-count gate.
2. `MultiRegionInterfaceV4` allows empty channels and empty flux bindings
   (`:27-43`). The validator rejects empty channels but iterates only existing
   bindings (`:148-174`); it never requires one binding per declared channel.
   A declared `:particle` channel with zero bindings can therefore be `ready`.
3. Region ownership is expressed as bare integer node positions. There is no
   coverage/disjointness policy and no typed canonical node reference.
4. Only the mechanism graph is stored. Exact field/geometry and
   realization/control graph ownership, subject, and scenario are absent.
5. The constructor accepts only a compiled prefix and does not rerun
   `_runtime_validate_compiled_prefix` from the actual candidate, registry,
   mission, bounds, and frozen scopes.
6. `MultiRegionCouplingValidationV4` has a public constructor (`:108-117`). A
   downstream module can be handed a caller-created `:ready` object unless it
   independently reruns the validator.

Independent adversarial construction confirmed that two zero-node regions and
one `:particle` interface with no flux bindings return `status=:ready` and no
gaps; the diffusion plan can then build and solve against that structurally
empty declaration.

Smallest safe integration change: require non-empty typed graph ownership,
explicit partition/overlap policy, and exactly one verified flux pair for every
declared channel; bind the contract to the common validated context including
G2/G3, subject, and scenario.

### 2. Multi-region diffusion provider — REJECT

The file accurately labels itself a “Standalone numerical-kernel/model-control
contract” and “Not candidate-bound evidence” at line 1. Its finite-difference
linear solve can be useful as a narrow manufactured fixture, but it is not a
RuntimeV4 provider.

Blocking findings:

1. The focused test is stale: it supplies a string flux binding at test line
   26, while the coupling constructor now requires
   `MultiRegionFluxBindingV4`; execution exits before any solver assertion.
2. `MultiRegionCouplingPlanV4` has no physical subject, scenario,
   `ProviderManifestV4`, `SolverInputV4`, or `RuntimeEvidenceV4`
   (`MultiRegionDiffusionProvider.jl:24-31`).
3. The plan selects only interface and region names. The solve never consumes
   the interface's channel or `flux_bindings` (`:44-48`), so a numerical flux
   continuity result is not proof of the declared typed conservation
   obligation.
4. Unit defaults are dimensionless or copied from state units (`:14-20`), the
   boundary constructor treats Neumann data as state units, and the solver does
   not check the dimensional relations for conductivity, source, gradient, or
   flux.
5. The constructor stores `plan_hash=hash(body)` but `semantic_view(plan)`
   includes `plan_hash`, and `canonical_hash(plan)` hashes that self-containing
   view (`:24-31`). There is no independent plan validator.
6. Result and receipt constructors are public and there are no validators;
   execution/failure artifacts and replay are absent (`:33-48`).

Smallest safe integration change: retain it as a test-only model control until
it consumes the exact typed flux obligation and common forward context through
the standard provider/input/evidence path, with dimensional validation, sealed
receipts, failure preservation, and fresh replay.

### 3. Engineering/control/fault contract — REJECT

The module has typed load, observation, actuation, fault, and obligation
records and retains separate engineering, control, and fault statuses. The
focused 12/12 assertions establish those local branches only.

Blocking findings:

1. `compiled`, `subject`, and `scenario` are optional in the input constructor
   (`EngineeringControlFaultContracts.jl:107-123`). The validator never checks
   them (`:153-189`).
2. Lines 156-158 compare candidate Genome wrapper objects to registry contract
   reference objects. With the real current types this always produces
   `candidate Genome contract binding mismatch`, so a real input is forced to
   deferred rather than proving the intended binding.
3. Loads and faults accept free-form evidence-reference strings. The validator
   checks only whether they are empty (`:159-172`); it does not resolve an
   evidence ID or verify subject, scenario, provider, applicability, or claim
   ceiling.
4. Evidence obligations contain caller-declared status. A required physical
   obligation is considered satisfied when its field says `:pass`; the
   referenced artifact is not validated (`:173-177`).
5. With no physical obligations, `all(...)` is vacuously true at line 173.
   With the Genome comparison repaired, a decision could claim physical
   evidence satisfaction without any compiled subject or physical execution.
6. Realization/control graph membership for sensors, actuators, loads, and
   fault paths is not checked despite this being the G4 consumer.

An independent diagnostic constructed an input with no compiled prefix,
subject, scenario, or obligations and caller-written fault evidence. It
reported control/fault pass and `physical_evidence_satisfied=true`; only the
type-incompatible Genome comparison kept the overall result deferred.

Smallest safe integration change: require the validated context and actual G3
graph elements, resolve every required obligation to admitted typed evidence,
and prohibit vacuous physical satisfaction.

### 4. Validation/UQ contract — REJECT

The module names the right concepts—three Genome identities, provenance,
applicability, prediction/comparison, calibration/held-out split,
distributions, and four uncertainty classes—but its admission path is neither
compatible with the current runtime nor fail-closed.

Blocking findings:

1. The supposedly validated inner constructor is callable by any caller as
   `ValidationBindingV4(Val(:validated), ...)` (`ValidationUQContracts.jl:15-21`).
2. The public derivation requires `subject.mission_hash` to equal the
   candidate mission contract reference hash and requires a scenario digest to
   be an element of `subject.scenarios` (`:24-31`). Real RuntimeV4 subjects bind
   the validated mission declaration hash and store scenario payloads; the
   real subject diagnostic fails with `subject mission does not bind candidate`.
3. Caller-supplied typed-AST and operator-hypergraph hashes in
   `GenomeIdentityV4` are never derived from or checked against the candidate;
   only the three Genome hashes are compared (`:7-13,28-31`).
4. Records placed in `held_out` are not required to declare
   `split=:held_out`; the constructor only checks binding and provenance-set
   non-overlap (`:82-109`).
5. A comparison need only bind its own observed datum. The closure never checks
   that its predicted datum is the contract's `PredictionArtifactV4`, nor that
   provider/result hashes identify admitted execution (`:66-88,114-127`).
6. `extrapolation_status` is admitted but ignored by the closure. A contract
   marked `:extrapolating` can pass.
7. `:model_benchmark` is allowed as held-out evidence and is not assigned zero
   physical credit. The closure awards `physical_validation_credit=1.0` for any
   otherwise passing contract (`:119-127`), contrary to the new-candidate
   validation boundary in docs 08/09.
8. Distribution families/parameters, uncertainty-budget values/units, source
   authenticity, and required-scenario completeness are not evaluated.
9. The focused 6/6 test contains only negative constructor assertions
   (`runtime_v4_validation_uq_contract_tests.jl:12-18`); it does not construct
   a real passing runtime-bound contract or exercise the closure.

An independent forged-binding diagnostic used a self-asserted model benchmark,
a record declaring calibration while placed in `held_out`, an unrelated
prediction, `extrapolation_status=:extrapolating`, and unchecked distribution/
UQ payloads. The closure returned `status=:pass` and
`physical_validation_credit=1.0`.

Smallest safe integration change: derive a sealed binding from the common
context and admitted artifacts, enforce split/prediction/comparison/scenario
ownership, block extrapolating/unknown scope, and grant physical credit only
under explicit independent evidence rules.

### 5. Gridap B2 convergence — ACCEPT B2 only

The final B2 snapshot is accepted as an isolated Gridap convergence
qualification for the already accepted B1 manufactured kernel. Its ceiling is
`screen_only`; it is not forward-chain closure or physical evidence.

Acceptance evidence:

1. Each 5/9/17 case consumes the exact typed B1 compilation plus exact G2 `u`
   and `f` plans. Plan integrity checks candidate, prefix, scenario, grid,
   program, root, parameters, and operator bindings
   (`GridapFieldConvergence.jl:205-215,286-310`).
2. The refinement gate fixes common candidate/prefix/registry/mission/scenario,
   constraint edge, form, affine geometry, protocol, dependency, adapter code,
   and exact program identities; all three axes must be a nested 5/9/17 series
   (`:217-244,292-301`).
3. The exact AST evaluator uses scalar gradients and vector Jacobians, resolves
   parameters by typed node binding, verifies qualified operator manifests, and
   implements the audited operator subset including the correct `DOT`
   derivative (`:73-203`). Analytic `u`, `grad(u)`, `f`, and `grad(f)` tests
   pass.
4. B2's independent Gridap reassembly is not allowed to drift from B1: matrix,
   RHS, and free solution identities must equal the B1 receipt/result before
   norms are admitted (`:246-256,304-310`).
5. Solution L2 and H1-seminorm errors are real physical-domain Gridap integrals
   (`:259-283`). The auxiliary transfer fields are accurately named
   `source_cell_center_rms` and `boundary_face_center_linf`, rather than being
   mislabeled as physical L2/H1 norms.
6. Case and receipt validators recompute semantic bodies, source-byte identity,
   observed orders, frozen bands, refinement order, and the
   `manufactured_control`/`screen_only` boundary (`:328-356`). The focused suite
   also rejects a mixed exact plan and a tampered case.
7. The definitive clean focused run passes 17/17. The definitive runner exits 0
   with `GRIDAP_B2_OK` and the following measurements:

| Nodes | Cells | DOFs | Solution L2 | H1 seminorm | Source cell-centre RMS | Boundary face-centre L-inf | Residual inf | Runtime s | Memory bytes |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 5 | 64 | 27 | 1.2296866291411006 | 5.6328357737805845 | 1.875 | 0.828125 | 2.220446049250313e-16 | 30.3426234 | 0 |
| 9 | 512 | 343 | 0.3093923279431648 | 2.7632236881230416 | 0.46875 | 0.2548828125 | 8.881784197001252e-16 | 3.1914451 | 0 |
| 17 | 4096 | 3375 | 0.07743601858664473 | 1.373269189825189 | 0.1171875 | 0.07061767578125 | 1.8318679906315083e-15 | 4.9426507 | 114257553 |

Observed L2 orders are `(1.990781381333485, 1.998360739751123)` within the
frozen `[1.5,2.5]` band. Observed H1 orders are
`(1.0275090544498333, 1.00873790377105)` within `[0.7,1.3]`.

Remaining boundary: B2 is a pass-only qualification receipt. Invalid input,
failed solve, or out-of-band convergence throws and fails the runner; B2 does
not preserve a typed failed receipt or expose a fresh-replay API. That does not
invalidate the successful pinned qualification, but it prevents treating B2 as
a general RuntimeV4 evidence stage. Keep it isolated from the default package
and do not forward its manufactured metrics as physical-validation credit.

### 6. Gridap B3 evidence — ACCEPT B3 only

The final B3 snapshot closes the narrow evidence-wrapper contract and is
accepted as an isolated Gridap manufactured-control layer at `screen_only`.
It is not acceptance of the four rejected forward modules, Batch B as a whole,
physical validation, whole-device closure, or final authority.

Acceptance evidence:

1. The public factory requires the actual candidate, compiled prefix, Genome
   registry, B1 compilation, and scenario; reruns
   `_runtime_validate_compiled_prefix`; and checks candidate, prefix, registry,
   mission, bounds, and scenario identity (`GridapFieldEvidence.jl:95-115`).
2. Capability applicability hashes the exact execution domain and compiled
   bounds (`:64-85`). Provider code identity combines the B3 source bytes, B1
   adapter source hash, and pinned dependency-lock hash; the provider is cached
   under that exact capability/domain/code identity (`:116-150`). The repeated
   public-construction test proves the same provider and bundle are reused
   (`runtime_v4_gridap_field_evidence_tests.jl:28-33`).
3. The subject, solver input, execute-once evidence, B1 report, replay envelope,
   and bundle are created from the same compilation and execution (`:139-168`).
   A missing executor report becomes `status=:unknown`, empty evidence, and a
   nonempty failure reason rather than a fabricated pass.
4. Validation recomputes the replay and bundle bodies; rechecks compilation,
   expected domain/capability/code, subject/input/evidence identities, B1 report
   integrity, artifact references, status, ceiling, and no-report failure
   invariants (`:171-221`).
5. Cache replay verifies execute-once idempotence, while fresh replay clears the
   report cache, executes in a new store, validates the new B1 report, and
   compares evidence/artifact/report identity (`:224-243`).
6. The final focused test passes 18/18, including foreign-scenario and
   foreign-provider controls, source/dependency code identity, bounds, ceiling,
   credible-count/P5 boundary, fresh replay, and repeated construction.

The final pinned runner exits 0 with:

```text
gridap_b3_status=pass
gridap_b3_provider=f0627fb20342a01e7e731a015c1452b1db1a893a899a8d89ddcf193558b18cdd
gridap_b3_solver_input=b605c483b7fbec6d4481615d6e98c6a2e949621c15b5929ced76c958b02ee5de
gridap_b3_evidence=9169a11621904d8c233152c4d6cee8498f76f89ba4320352ae2f106d92fe01c7
gridap_b3_replay=156204abe4153542aa202c1973f670b29f09758b8f5ca1e2714903f8d4629fc6
gridap_b3_claim_ceiling=screen_only
GRIDAP_B3_OK
```

Remaining boundary: the focused suite does not deliberately force the provider
executor to throw, nor does it enumerate every candidate/prefix/registry/
mission/replay-field forgery independently. Those are worthwhile hardening
tests, but the factory and validator now fail closed for those identities. B3
also remains loaded only by its pinned fixture, not by the default package
aggregator; that isolation is appropriate while Gridap remains a qualification
dependency. B3 evidence is manufactured numerical evidence only and must not be
forwarded as physical-validation credit.

## Cross-module consequence

The modules currently form six local islands, not one executable evidence
chain:

```text
three Genome candidate + compiled typed graphs
        |
        +-- B1 Gridap manufactured control (accepted only at screen_only)
        |       +-- B2: accepted isolated convergence qualification
        |       `-- B3: accepted isolated evidence/replay envelope
        |               (both remain manufactured and screen_only)
        |
        +-- multi-region declaration: empty ownership can be ready
        |       +-- diffusion: standalone model, ignores typed flux binding
        |
        +-- engineering/control/fault: optional subject and self-declared evidence
        |
        +-- validation/UQ: forgeable binding and false physical-credit path
        |
        `-- whole-device + final authority: no admissible reports from above
```

Consequently, B2 and B3 provide safe isolated manufactured-control receipts,
but there is no admissible integrated output from these six modules to hand to
`WholeDevice` or `FinalWholeDeviceAuthorityV4`. Current credible physical
candidate count remains **0**. No P5 or deployability claim is supported.

## Final disposition

- **Do not include, export, stage, commit, or push** the four rejected modules.
- B2 and B3 are accepted only as isolated `screen_only` modules and were
  committed separately at `85f72f8` and `c90e0ad`. This verdict does not authorize
  aggregator inclusion, default exports, or representation as a complete
  forward chain.
- Preserve the committed B1 acceptance as an isolated manufactured
  qualification result, with B2/B3 extending only that manufactured-control
  scope.
- Use
  `docs/implementation/forward_contract_integration_review_20260909.md` as the
  minimum repair contract and re-review modules in dependency order.
- Require a clean source snapshot, adversarial focused tests, pinned runners,
  relevant RuntimeV4 regressions, and aggregator/export review before changing
  any verdict.
