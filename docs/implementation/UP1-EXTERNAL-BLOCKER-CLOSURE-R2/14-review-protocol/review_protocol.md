# UP1 external-blocker closure R2: independent test and review protocol

**Protocol id:** `UP1-EXTERNAL-BLOCKER-CLOSURE-R2-REVIEW-V1`  
**Scope:** G1, G2, G3, the additive V5 shared-entry/migration join, the UP2-00 typed precompiler seam, R2-07 authority intake, and the W1/W2/W3/W4 external-boundary threat crosswalk.  
**Status:** frozen preparation contract; no implementation, Julia, DESC, mesh, solver, provider, or external operation is authorized by this document.

## 1. Purpose and non-credit boundary

This protocol is an independent acceptance recipe to run *after* the implementation packets are complete. It tests software contracts, source authority, candidate binding, and evidence transport. A passing test or reviewer report is not physical, engineering, provider, mesh, solver, B00, B04, or R01--R10 evidence unless the corresponding gate below is explicitly met. Missing external inputs remain typed absence and `terminal_deferred`; they must never be converted to a synthetic present result.

The implementation author supplies code and a proposed manifest. A different Luna executes each review group from a fresh process and derives its own expected outcomes from the source/contracts. Reviewers must not import the author's test module as an oracle, copy its expected error labels, or use a helper that computes both the system result and the expected result.

All test fixtures and generated outputs used solely by this protocol carry both labels:

```text
TEST_ONLY=true
non_evidence=true
```

They are not candidate evidence, may not be referenced by a physical/engineering claim, and must be excluded from acceptance manifests that publish evidence. Synthetic fixtures are allowed only to test software behavior and must be named `synthetic_TEST_ONLY_*`.

## 2. Frozen execution and independence rules

1. Before the first run, freeze the source ref, test ref, fixture bytes, protocol hash, environment profile, command argv, seed, and output naming. A later source/fixture/protocol change invalidates the receipt and requires a new review revision.
2. Every component run is a fresh OS process: `julia --startup-file=no --project=. <recipe>` (or the equivalent independent Python static checker). No `include` into a warmed Julia session, no shared mutable module state, no interactive REPL, no cached result, and no same-process second replay.
3. Reviewers capture `argv`, absolute `cwd`, start/end timestamps in UTC, PID, parent PID where available, interpreter/module paths and versions, stdout, stderr, and an exit artifact. UTC timestamps must be RFC 3339 with `Z` or an explicit `+00:00`; local-only wall-clock text is insufficient.
4. A receipt binds the exact input bytes and source paths by SHA-256. The checker independently recomputes hashes and semantic classifications. Hashes printed by the implementation are observations only until independently recomputed.
5. Never edit or delete pre-existing dirty paths. The review output directory is the only permitted write location for this task. Any test scratch directory is disposable and must be listed in `cleanup_inventory.json`.
6. Do not run or schedule Julia/DESC/mesh/solver/provider/heavy numerical work in this review round. The heavy lane is explicitly `default: forbidden`; if a future formal run is authorized, it must use a separately frozen serial protocol and queue receipt.

The threat crosswalk in `test_matrix.json` is normative for this review. It maps every `TM-01`--`TM-20` and `AR-01`--`AR-12` row from `13-threat-model` to an executable independent test, oracle, contradiction/unavailable outcome, and evidence list. It explicitly covers W1 witness/authority, W2 PKI and algorithm policy, CRL/OCSP, independent TSA trusted time, nonce/sequence/idempotency replay, W3 source/G2/environment, W4 local discovery, R2-06/R2-10 provenance, R2-07 authority intake, TOCTOU, traversal/reparse, manifest closure, SBOM/license, binary provenance, and environment drift.

## 3. Component interface contracts

The following are the minimum observable interfaces. Names are logical obligations; an implementation may expose an equivalent API only if the receipt records the mapping.

| component | input boundary | required output/diagnosis | mandatory ownership checks |
|---|---|---|---|
| G1 | candidate-owned typed mechanism payload, equation/AST, operators, units, closure and occurrence ledger | present/typed-absent/fail-closed result; declaration, source and contract refs; canonical bytes/hashes; no final identity when authority is absent | operator occurrence IDs and ledger are unique and bijective; no default-registry mutation; exact ports/units/closure; candidate binding |
| G2 | candidate-owned chart/coordinate/metric/boundary declaration, dimensions, regions, interfaces and units | typed result with boundary/metric/space diagnostics and canonical declaration/hash | region/interface IDs, face ownership and axis/version/hash binding are exact; duplicate or foreign owner is fail-closed |
| G3 | realization/control/binding children, resource/energy accounts, ports, feedback law, faults and external source authority | present/typed-absent/fail-closed result; child refs, axes, authority and account/closure diagnostics | child refs are exact (realization/control/binding); account and entry ownership is unambiguous; unit/capacity/closure checks; absent external source stays terminal-deferred |
| V5 shared entry | one actual G1/G2/G3 bundle plus candidate binding and four independent version axes | package identity and migration/join receipt, or explicit mismatch/terminal-deferred result | exact compare of URI, version, schema hash, canonical hash, compatibility profile, axes and candidate; rebuild identity, never alias legacy refs |
| UP2-00 precompiler | actual V5 package fields only for formal tests; low-level wrappers are synthetic TEST_ONLY | source-derived N01--N10 classification, error path/value/hash, and compile/provider/solver counters | expected labels are assertions only; no label routing; provider/solver calls remain zero in contract-only tests |
| UP1-04B B00/B04 | frozen candidate-bound package and schema-bound mutation envelope | B00 F0--F5 and 50 fresh B04 receipts, independent checker and two-process replay | exact source/hash/typed values/mutation IDs; no reused receipt, old identity, synthetic low-level input or archive pollution |

For all interfaces, serialization must be canonical and deterministic. Unknown fields are rejected unless an explicitly versioned extension point says otherwise; silently dropping fields is a failure. Constructor rejection still requires an attempted-value receipt for formal mutation tests. The normalized TM-07 error code is `revocation_status_unavailable`; legacy/non-ASCII labels are not accepted as stable machine keys.

## 4. Fresh-process test recipe

Each row in `test_matrix.json` is run using the following envelope:

```text
R = {protocol_id, review_revision, component, source_ref, fixture_sha256,
     command_argv, cwd, env_profile, seed, test_case_ids,
     started_at_utc, ended_at_utc, pid, parent_pid,
     stdout_sha256, stderr_sha256, exit_sha256, output_sha256,
     TEST_ONLY=true, non_evidence=true}
```

The reviewer first verifies the frozen input hashes, then starts one fresh process. The process emits machine-readable case rows and human-readable diagnostics. After it exits, the reviewer independently parses the rows, recomputes all hashes, checks the exit artifact contains the numeric process exit code, and records the verdict. Every row marked `determinism=true`, including Python static/security rows, requires exactly at least two independent OS processes and `replays=2`; `replays` means process count, not an in-process retry. Byte equality is required for canonical output, diagnosis code/path, and hash fields; timestamps, PID and wrapper metadata are excluded from semantic equality.

### Required positive and negative classes

Every component must cover a valid minimal fixture and parameterized negatives for:

- omission of each required field (one mutation per field, not one aggregate missing-field case);
- wrong type, wrong unit/dimension, malformed digest, bad version axis, and foreign candidate binding;
- duplicate IDs/occurrences/ports/regions/accounts/entries/child refs and duplicate keys after canonical normalization;
- unknown field at every public object boundary, including nested objects and extension boundaries;
- permutation of arrays/maps to prove canonical sorting and unchanged semantic hash;
- mutation of each authoritative source byte to prove source/declaration/hash mismatch is detected;
- legacy/V4 ref presented to a V5-only entry, missing external authority, and provider unavailable. These classify as typed absence/`terminal_deferred` only where the contract says so; contradictions are `fail_closed` and unexpected exceptions are `program_exception`.

Negative expectations are parameterized from actual field paths and invariants. `expected_error` may be stored as a non-driving assertion, but classification, error path, and reason must be independently derived from mutated input and source code/invariant inspection.

### Mutation, duplicate and unknown-field tests

For every mutation row, retain baseline canonical bytes/hash, exact JSON Pointer or typed path, original typed value, attempted mutated typed value, mutation ID, and observed outcome. A duplicate test must prove the duplicate survives serialization up to the validator (unless constructor rejection is the intended behavior) and must record the attempted duplicate. An unknown-field test must show rejection at the boundary; an output that merely ignores the field fails. Mutations may not be generated solely from an expected-error table.

### Determinism and two-replay rules

Component determinism consists of two fresh processes with identical frozen inputs and seed. The two outputs must have identical canonical semantic bytes and hashes. Formal B00/B04 additionally requires two-process replay after the complete suite: process A and process B read the same frozen envelope independently, each writes its own raw streams and checker receipt, and the independent checker compares semantic rows, exact mutation IDs, input/source hashes, classifications, and counters. A wrapper that launches the same child twice in one Julia process does not satisfy two-process replay.

## 5. Parallel versus serialized execution

The following may run in parallel because they read frozen inputs and have disjoint output subdirectories: G1 component review, G2 component review, G3 component review, W1/W2/W3/W4 security-contract rows, R2-07 authority-intake review, V5 shared-entry static/schema inspection, and the Python `-B` JSON/manifest static validator. Each reviewer still uses separate fresh processes and separate output names; all determinism rows use two processes.

The following are serialized and are **forbidden in this round by default**: any Julia/DESC/solver/mesh/provider execution; cross-layer candidate identity rebuild that consumes mutable outputs; UP2-00 total mutation campaign; B00 F0--F5; the 50 formal B04 mutations; checker replay; and final integration adjudication. If a future Sol decision unlocks them, one queue owner must hold the lane, record pre/post process snapshots, and complete one stage before the next starts. Parallelism never authorizes two solver/DESC or B00/B04 lanes.

## 6. Evidence contract and rejection conditions

An evidence receipt is admissible only when all fields in `evidence_contract.json` are present and non-empty as applicable. In particular, it must include raw stdout/stderr bytes, PID, UTC start/end, numeric exit code, exact command/cwd, interpreter/module versions, source/input/output SHA-256, test-only labels, and reviewer identity/model. Missing raw streams, missing exit artifact, local-only time, a copied hash, an unbound path, or an unverifiable PID changes the result to `block_external` or `rework` according to the classification rules below.

`pass_limited`, `rework`, and `block_external` are the only group/final conclusions. `program_exception` is an independent observed fault classification, not a fourth verdict: preserve traceback and raw streams, use `rework` for an unexplained/local runtime defect, and use `block_external` only when the independently established cause is unavailable external authority/service. `program_exception` can never be silently converted to `fail_closed`, `terminal_deferred`, or `pass_limited`. `not_applicable` is likewise not a pass; it is permitted only for rows explicitly marked future-locked and excluded from this R2 scope.

The following never close an external blocker: a document-only plan, a green in-process test, a runner exit without raw streams, a schema hash without source bytes, a synthetic fixture, a local accepted-limited slice, a provider/solver call count of zero, or a historical receipt. No physical or engineering claim may cite this protocol's TEST_ONLY material.

## 7. Independent Luna review groups

The assignments in `review_assignments.json` are logical roles, not pre-approval of a person. Sol assigns actual Luna workers after implementation and records model, reasoning effort, task ID, source revision, and conflict check. The author of a component cannot review that component. Group reviewers must not share a worktree or output directory with the author. A second reviewer performs cross-group challenge review of the first reviewer's receipt, using only frozen source/inputs and independently recomputed hashes.

Each group reports: scope, exact commands, fresh-process proof, case counts, positive/negative outcomes, mutation coverage, determinism comparison, source/hash ownership, raw/PID/UTC/exit inventory, findings with severity, and claim ceiling. The group verdict is one of `pass_limited`, `rework`, or `block_external`.

## 8. Final integration gate

The final integrator is a Luna who authored none of the reviewed components; Sol is the adjudicator. Integration is allowed to inspect receipts only after all group reports exist. It must:

1. verify manifest paths, hashes, source revision and protected-dirty snapshot;
2. verify each component's fresh-process and deterministic replay receipt;
3. exact-join G1/G2/G3 refs, hashes, four axes, child refs and candidate binding;
4. reject any stale/foreign/legacy/unknown-field/duplicate receipt or any missing raw/PID/UTC/exit field;
5. ensure TEST_ONLY/non_evidence artifacts cannot enter evidence authority;
6. confirm no Julia/DESC/solver/provider/heavy lane was run in this round;
7. issue one overall verdict and a claim ceiling, with no silent promotion of deferred authority.

Overall verdict reduction is fail-closed:

| condition | overall verdict |
|---|---|
| all required groups pass their bounded software scope, exact joins pass, and evidence contract is complete | `pass_limited` |
| an implementation/test/receipt defect is locally repairable and external authority is not the cause | `rework` |
| required external source, authority, provider, or heavy execution is unavailable; or provenance cannot be established | `block_external` |

Any `block_external` finding dominates `rework`; any `rework` finding dominates `pass_limited`. An observed `program_exception` forces at least `rework` unless a separate receipt proves external unavailability, in which case it is `block_external`. A mandatory `not_applicable` row prevents `pass_limited`. `pass_limited` means contract/software preparation only, never full UP1, B00/B04, provider, mesh, solver, engineering, physical, or R01--R10 acceptance.

## 9. Required cleanup

At completion, reviewers keep immutable raw streams and receipts that are listed in the review manifest. Temporary Julia compilation caches, scratch JSON, copied fixtures, process dumps, and failed experimental outputs are removed only when they are not referenced by a receipt and are explicitly listed as disposable in `cleanup_inventory.json`. No historical artifact outside this protocol directory is deleted or rewritten. A cleanup run itself records UTC time, PID, command, exit code, and the list of paths examined; deletion is never used to hide a failed or incomplete test.
