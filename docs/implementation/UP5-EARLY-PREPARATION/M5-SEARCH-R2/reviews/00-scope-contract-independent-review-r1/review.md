# Independent review R1 — M5-SEARCH-R2 scope contract

## 判定

`NO-GO_FOR_EXECUTION / CONDITIONAL_PASS_FOR_SCOPE_ONLY`.

The reviewed contract is appropriately non-authorizing as a static scope
record: it is `authorized_not_started`, `contract_only`, `screen_only`,
`no_publish=true`, with `formal_credit=none`. The candidate/source/grammar
identity intent, bounded synthetic-only pipeline, and evidence ceiling are
directionally sound. This review does not authorize an R2 run. The P1 blockers
below must be closed and independently re-reviewed before execution.

No P0 finding was identified. The audit was read-only: no Julia, DESC, S3,
solver, provider, mesh, search runtime, or production/test source was run or
modified.

## Scope checks

| Check | Result | Evidence |
|---|---|---|
| Candidate/source/grammar binding | `PASS_INTENT; BLOCKED_EXECUTION` | `report.md:15-31` requires source, grammar, mission, bounds, scenario, parent/child prefix, emitter, seed/sequence and descriptor hashes; `input_hashes.json` explicitly lists the synthetic fixture and authority receipt as missing. |
| Conditional e-graph guards | `PASS_INTENT` | `report.md:33-38` requires all typed side conditions, zero merge on failed applicability, and fail-closed malformed/contradictory input. |
| Bounded QD/MCTS pipeline | `PASS_INTENT; ACCOUNTING_GAP` | `report.md:40-77` freezes finite caps and a shared proposal cap, but does not state global e-graph application/class/node caps or a complete stage-by-stage budget ledger. |
| Deterministic receipts | `BLOCKED_BY_CONTRADICTION` | `report.md:81-96` requires byte-identical fresh-process receipts while each receipt also contains PID and UTC start/end (`89-93`), which vary between processes. |
| Failure classification | `PASS_WITH_AMBIGUITY` | `report.md:102-117` preserves deferred/numerical/physical boundaries, but uses `program_exception or fail_closed` for several distinct failures and has no explicit class for non-saturation proposal/screen budget stops. |
| `screen_only` / `no_publish` | `PASS` | `report.md:3-11`, `112-117`, `129-136`, and `manifest.json` keep the package non-publishing and outside physical/evidence authority. |
| M5-C dependency | `CORRECTLY_BLOCKED; NOT_READY` | `report.md:119-136` and manifest `m5_c_performance_dependency.status=blocked_not_passed` correctly reject the historical failed M5-C R3 record as a performance gate. |
| Prohibited claim boundary | `PASS_TEXT; MANIFEST_HARDENING_NEEDED` | The report explicitly excludes B00/B04, B00 F0-F5, 50 receipts, L4, UP5 and R01-R10; the top-level `manifest.json.prohibited` omits standalone `B00`, `B04`, `UP5`, and `R01-R10` entries. |

## Findings

### [P1] R2 cannot execute: immutable fixture, grammar authority, implementation, checker and environment are absent

`input_hashes.json` declares all of the following unresolved: M5-C threshold
owner freeze, synthetic source fixture content/source authority receipt,
versioned R2 implementation/test/oracle entrypoints, and independent checker /
environment lock. Consequently the named `source_bundle_hash` and
`grammar_hash` cannot yet be recomputed from an immutable, authoritative
closure. The current source files are only read-only references by the
contract (`report.md:15-18`), not an R2 implementation or authority receipt.

Required closure before execution: add a versioned synthetic fixture and
grammar manifest with exact bytes, source authority and canonical schema;
freeze the R2 entrypoint/oracle/checker/environment and hash every item; reject
execution when any join is missing or stale.

### [P1] Fresh-process byte-identical receipts conflict with mandatory runtime fields

The receipt minimum includes `UTC start/end` and `PID observation`
(`report.md:89-93`), while the replay rule requires byte-identical canonical
receipts and traces across two fresh processes (`94-96`). These fields cannot
be byte-identical for independent fresh processes. `attempt_id` and
`receipt_id` also have no deterministic derivation or explicit exclusion from
the canonical replay bytes.

Required closure: define two layers—(a) deterministic content receipt and
trace, excluding PID/time/attempt-instance fields, and (b) an operational
envelope carrying PID/time/exit—or define a canonical normalization rule and
compare only the normalized bytes. Bind the independent replay relation and
receipt IDs explicitly; otherwise a replay can never satisfy the stated gate.

### [P1] M5-C gate is named but not identity-bound to the R2 configuration

The contract correctly says R2 waits for owner-frozen thresholds and an
independent review of a fresh candidate/source-bound M5-C receipt
(`report.md:121-127`). However, `manifest.json` has only a historical input
path and status; it has no required `m5c_gate_receipt_hash`, owner/reviewer
identity, exact threshold/config hash, hardware/environment hash, or explicit
join to the R2 source/grammar/caps. A future executor could therefore attach a
stale or differently configured performance result while satisfying only the
textual dependency.

Required closure: add a mandatory, hashed M5-C gate envelope containing owner,
independent reviewer, threshold/config/measurement command, environment,
source/candidate joins, variance policy, raw streams and receipt hash; reject
R2 unless the exact gate hash is present and accepted.

### [P1] Declared e-graph caps are not executable against the referenced profile

The R2 table declares 128 e-graph e-classes, 512 e-nodes and 512 trace rows
per seed (`report.md:63-70`). The read-only referenced
`src/IR/ConditionalEGraphTypes.jl` profile currently constrains
`max_programs` to 64 and `max_trace_steps` to 256 (source lines 81-87), and
does not provide the R2 e-class/e-node budget API. Since the manifest also
declares the versioned R2 implementation as missing, it is not possible to
show that the contract's accounting or cap semantics can be enforced.

Required closure: either freeze a new R2 implementation/profile whose schema
defines all requested counters, or reduce and explicitly map the R2 caps to a
versioned implementation. In both cases, expose a checker-visible per-seed and
global budget ledger.

### [P2] Synthetic QD descriptor semantics are underspecified

The contract hashes a `canonical_descriptor_hash` and mentions descriptor-cell
occupancy (`report.md:20-25`, `51-54`), but does not freeze descriptor schema,
units/normalization, dimension, value bounds, cell discretization, tie-break,
or the exact synthetic feature derivation. The normative QD design describes a
behavior descriptor from candidate-bound behavior, while this slice expressly
has no physical equations or solver. Without a distinct `synthetic_descriptor`
schema and name, occupancy can be mistaken for behavior/capability evidence.

Required closure: freeze a synthetic-only descriptor schema and derivation,
include its hash in `emitter_config_hash`/receipt joins, and state that it is
not a behavior descriptor or search-capability increment.

### [P2] Budget and failure ledgers need stage-specific semantics

The global proposal/screen/trace caps are finite, but “stop at the first
per-seed or global cap” (`report.md:46-48`) does not define whether a QD archive
cap, MCTS expansion cap, global prefix cap, or screen-evaluation cap is
`terminal_deferred`, `saturation_incomplete`, or another nonterminal status.
The failure table only specifies `saturation_incomplete + terminal_deferred`
for closure caps (`102-109`). The phrase `program_exception or fail_closed`
also permits two different classifications for the same malformed/identity
failure (`104`).

Required closure: enumerate each budget counter with a stage-specific stop
reason and precedence, and make parser/schema/identity/contradiction mapping
deterministic (one required class per observation, with any secondary detail in
a field).

### [P2] Machine-level prohibition list should mirror the textual claim ceiling

The report explicitly excludes standalone B00/B04, UP5 and R01-R10, but the
top-level `manifest.json.prohibited` contains only `B00_F0-F5`,
`B04_50_receipts`, `L4`, and `R01-R10`-like text in the report. Add exact
machine-readable prohibited tokens for `B00`, `B04`, `UP5`, `UP5-01`,
`UP5-02`, `UP5-03`, and `R01-R10` so downstream checks cannot interpret the
contract as granting a broader formal scope.

## Positive controls confirmed

- Candidate IDs are required to be content-derived and not based on family,
  name, benchmark or display labels (`report.md:27-31`).
- Typed e-graph condition failure is explicitly zero-merge and non-authoritative
  (`report.md:33-38`, `102-106`).
- Provider/physical/engineering routes are outside the pure synthetic screen;
  physical pass/fail, originality, feasibility and final authority are
  explicitly excluded (`report.md:51-56`, `112-117`).
- Failed members cannot delete a grammar, Genome type or topology family, and
  no pruning certificate is emitted without separate proof authority
  (`report.md:114-117`).
- The historical M5-C R3 failure is not promoted to a performance pass, and
  missing/failed/stale M5-C evidence forces `terminal_deferred=true` and
  `no_publish=true` (`report.md:129-136`).
- Static audit hashes matched all 17 listed input paths; no input mismatch was
  observed. This validates the recorded baseline only, not execution readiness.

## Required disposition

Keep the scope package `not_executed`, `terminal_deferred=true`,
`screen_only`, `no_publish=true`, `formal_credit=none`. Do not label it a
campaign, winner, capability increment, B00/B04 result, L4 candidate, UP5
acceptance, or R01-R10 evidence. Re-review after the P1 closures and a fresh
static audit of the updated hashes.

## Audit receipt pointers

- Static command receipt: `review_receipt.json`
- Input and output hash manifest: `hash_manifest.json`
- Raw stdout: `raw/audit.stdout.raw`
- Raw stderr: `raw/audit.stderr.raw`
- Combined raw stream: `raw/audit.combined.raw`
