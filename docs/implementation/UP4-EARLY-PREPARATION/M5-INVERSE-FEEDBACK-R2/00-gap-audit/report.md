# M5 inverse-feedback R2 gap audit

## Decision and evidence ceiling

Status: `gap_audit_complete`; `scope_status=read_only`; `formal_credit=none`.
This audit does not accept, promote, or re-run M5, UP4, B07A, B07B, B08,
engineering, provider, solver, physical, candidate, or R01-R10 evidence.
The only historical positive result is the R1/R2 `pass_limited` isolated
manufactured fixture, and it is valid only for the exact bytes frozen by those
receipts. The current checkout has source-byte drift, so current M5 execution
is `not_executed` and current authority is `unknown` until a new freeze and
review.

## Audit boundary and snapshot

Only read-only inspection was performed. No Julia, DESC, S3, mesh, provider,
solver, inverse runtime, hardware command, download, or external write was
performed. The final audit snapshot process was PID `32440`, UTC
`2026-09-16T21:50:25.1056385Z`, exit `0`; stdout/stderr are retained at
`archive/raw/audit_snapshot.stdout.raw` and `archive/raw/audit_snapshot.stderr.raw`.
An earlier audit-wrapper capture hit a PowerShell reserved-variable collision;
it is retained at `archive/raw/audit_setup_failure.stderr.raw` and classified
as audit-only `program_exception`, not a source/test result.

Observed checkout: `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`, branch `main`,
dirty worktree. The M5 and M5-A source files are untracked and were modified
after the historical R1/R2 runs:

| input | current bytes / SHA-256 | historical R1/R2 frozen SHA-256 | current relation |
|---|---:|---:|---|
| `src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl` | 26187 / `477b5a41c1a021fae84aeebaf13e3967c93b001ace7f38746af1ab1212110e59` | 26255 / `f0dcf8aa0dc199a4e3404ecec1a4f516b899e1cfd523454d698f9afe91553976` | drift; modified 2026-09-16T14:11:50Z |
| `src/RuntimeV4/M4Isolated/ManufacturedAutoCompositionV1.jl` | 26258 / `284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209` | `e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a` | drift; modified 2026-09-16T14:07:41Z |
| M5 isolated test | 15357 / `f2279400356a786c83a13ad3f82400af052e64f5bbc8ceefbf0e8119e6903ea2` | same | byte-equal to receipt |
| M5 Python oracle | 5811 / `6e13536aabb62f039bffe6c286e11323347b86b4d3c146270f38e8bf8129d0ab` | same | byte-equal to receipt |
| M5-A test / oracle | 13210 / `42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08`; 7823 / `e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c` | same | byte-equal to receipt |

The complete current input list and hashes are in `manifest.json` and the raw
snapshot. The old R1 package records source `f0dc...53976` and M5-A source
`e626...1945a`; current source constants now refer to the current M5-A byte
hash, but that change itself has not been re-executed or independently reviewed.

## What is actually accepted-limited

R1 root acceptance and independent R2 review say `accepted_limited` only for
the isolated manufactured inverse/feedback control with ceiling
`manufactured_inverse_feedback/screen_only`. For the historical frozen bytes,
the authoritative integration recorded Python oracle ×2, Julia isolated tests
×2, then a repair probe: PIDs `70992`, `28660`, `111376`, `52692`, and `38880`;
all exits `0`; Julia semantic result `203/203`; probe `25 cases,
typed_failure=25, exceptions=0`. The exact semantic payload was:

* `A(alpha,beta)=[[alpha,-beta],[-beta,alpha]]`, `rhs=(1,0)`;
* target `(2/3,1/3)` recovered to hidden `(alpha,beta)=(2,1)`;
* determinant `3`, eigenvalues `(1,3)`, margin proxy `1/3`;
* forward round-trip residual `(0,0)`;
* seeds `[0,1,2]` deterministic;
* deleting beta/interface feedback gives `(1/2,0)` and delta `(1/6,1/3)`;
* typed negatives include invalid upstream, foreign hash/owner/provenance,
  non-identifiable/zero denominator, singular, non-SPD, impossible target,
  round-trip corruption, seed mismatch, and deletion-no-effect.

The source and test confirm this is exact `M4RationalV1` arithmetic over a
two-by-two manufactured family. The source explicitly says it does not
instantiate an external runtime path; the test's static guards reject optimizer,
real-reference, `CandidateStatePackage`, provider, and iterative-solver paths.
Thus the result establishes a software/manufactured control and typed negative
controls only. It does not establish parameter recovery from observations,
hardware realization, engineering back-substitution, or a physical feedback
loop.

Historical receipt details remain available in the R1 manifests and raw files:

* `integration_r1/repair_r1/manifest.json` — source/test/oracle hashes, PID,
  UTC, exit, semantic summaries and raw paths;
* `test_execution_r1/repair_r1/execution_summary.json` — serial Python→Julia
  lane and process receipts;
* `independent_review_r2/manifest.json` — review replay, 25-case probe and
  explicit no-credit guards.

Because the current source and M5-A source differ from those frozen manifests,
the historical pass must remain historical context. No current Julia test was
run in this audit by instruction.

## Related source/test authority gaps

| slice | observed source/test contract | classification now | missing authority / owner |
|---|---|---|---|
| N2 reference input | `N2ReferenceInputV4` enforces `screen_only`, `measurement=false`, `inverse_ready=false`, `held_out_prediction_ready=false`; replay request records `physical_validation=unsupported`, `provider_executed=false`, `geometry_proved=false`, `credible_device_count=0` | `unknown` for true-reference authority; `unsupported` for current physical/provider ceiling | provenance-complete source/design or experimental data, coordinate/basis/calibration owner, hidden-parameter owner, candidate-independent split and held-out owner |
| pickup/RL engineering | fixed circular stationary coil and ideal lumped RL screen; static plasma flux contribution, `induced_emf_V=0`; external coils/outer sheet and current closure are unknown/propagation obligations | `unsupported` / `deferred` | candidate-bound external field/source-return authority, time-varying source, finite power/thermal/material/manufacturing domains; UP4-01 and provider owners |
| magnetic engineering | ideal isothermal Ohmic pickup/readout with placement/exterior-field applicability unsupported; tests use manufactured 2-T-equivalent values and retain `engineering_qualified=false` | `unsupported`, not `scientific_fail` | qualified component/material/insulation/thermal/placement data and independent engineering checker |
| trusted control/fault provider | repository-manufactured operational screen; tests require `operational_screen` and all evidence/promotion/terminal authority flags false | `unsupported` for formal engineering authority; historical operational screen only | UP2-05 capability/provider manifest, applicable-domain receipt, source revision/environment identity, and universal fault/start-stop/recovery scenarios |
| M5 current source/test pair | source and M5-A source drift from historical freeze; no current execution receipt | `not_executed` + `unknown` | implementation/integration owner must decide intended bytes, re-freeze all dependent inputs, rerun isolated lane, and obtain different-role review |

These are not scientific failures. `scientific_fail` is not observed for the
manufactured fixture: the historical exact check passed. A missing true source,
provider, applicability domain, hardware measurement, or engineering authority
is `unknown`, `unsupported`, or `terminal_deferred` as shown; it must not be
renamed `physical_fail`. A numerical failure would require an applicable,
actually executed provider; none was executed here.

## Formal UP4 status and external inputs

The current task manifest leaves `UP4-01`, `UP4-02`, `UP4-03`, and `UP4-04`
`planned`, with null owner/reviewer and the dependency chain
`UP3-02 → UP4-01 → UP4-02 → UP4-03 → UP4-04`. The required external inputs and
responsibility boundaries are:

1. **UP3/T1/T2 authority:** a fresh candidate-bound G1/G2/G3 identity,
   target/source demand, field forward model, scenario and solver-input joins;
   T0/authority-recheck/T1/T2 aggregate owners own the receipts.
2. **B07A source/hardware branch:** finite source and return network, power,
   thermal/material/manufacturing/actuator domains, declared tolerances,
   multi-start traces and an independent forward checker; UP4-01 plus the
   applicable provider owners own these inputs. It may use a synthetic target,
   but it cannot produce B07B/R02 real-reference credit.
3. **B07B true-reference branch:** provenance-complete real reference or
   experimental/design source, source-owned geometry/basis and units, withheld
   hidden parameters, calibration/validation/held-out observations,
   measurement uncertainty/missingness, identifiability rank/conditioning and
   multi-start evidence; the external data/reference authority and UP4-03
   owner must supply and independently check it. Synthetic MMS, the M5 fixture,
   a benchmark label, or a B07A synthetic target cannot fill this gap.
4. **B08/UP4-02 engineering branch:** source-to-field-to-circuit/power-to-
   thermal/material/structure-to-control/fault feedback with cooling, startup,
   shutdown, actuator saturation, recovery and universal required scenarios;
   engineering/provider owners must provide applicable manifests and ledgers.
5. **UP4-04 integration:** one fresh versioned plan joining candidate,
   alternative, scenario, source, solver input, provider, feedback and artifact
   hashes, plus independent replay/checker. Integration ownership cannot infer
   missing external authority from a successful local test.

The recovery condition for each missing authority is an exact typed record with
owner, source revision, applicability domain, units/coordinates, uncertainty,
candidate/scenario/input/provider hashes, raw output, PID/UTC/exit and an
independent receipt. Missing authority remains `resolution=terminal_deferred`.

## Next minimum slice without crossing a formal gate

The smallest safe next slice is an additive **M5 manufactured re-freeze and
isolated replay**, not UP4 execution:

1. implementation/integration owner declares whether the current M5 and M5-A
   source-byte changes are intended; freeze current source, test and independent
   oracle hashes, including the exact dependency snapshots;
2. run only the isolated Python oracle→M5 test sequence against those frozen
   bytes, retaining raw stdout/stderr, PID, UTC, exit and input/output hashes;
3. run a different-role independent review of the re-freeze and negative
   controls, then mark at most `accepted_limited` with
   `manufactured_inverse_feedback/screen_only`;
4. keep all true-reference, hardware, provider, candidate, engineering and
   formal UP4 fields pending/deferred.

If the source changes are not intended, restore the exact historical bytes only
through an explicitly authorized, recoverable source decision; this audit did
not alter them. No step above closes UP4-01/02/03/04 or grants formal credit.

## Classification ledger

| item | classification | meaning |
|---|---|---|
| historical frozen M5 exact-Rational check | pass-limited software screen | no scientific/engineering/formal credit |
| current M5 source after drift | `not_executed` / `unknown` | historical receipt does not bind current bytes |
| true reference data and hidden-parameter recovery | `unknown` / `terminal_deferred` | no provenance-complete source, withheld answer, or held-out authority |
| hardware realization and engineering back-substitution | `unsupported` / `terminal_deferred` | no applicable finite source/return/power/thermal/material authority |
| numerical or physical failure | not observed | no applicable current provider execution; do not infer `scientific_fail` or `physical_fail` |
| audit wrapper first attempt | `program_exception` | local PowerShell capture mistake only; no source/test execution |
| this audit's forbidden runtime lanes | `not_executed` | deliberate boundary: no Julia/DESC/S3/solver/provider/mesh run |

No formal gate is closed, no credible candidate count is raised, and no R02,
R04, R05, B07, B08, or R01-R10 credit is granted.
