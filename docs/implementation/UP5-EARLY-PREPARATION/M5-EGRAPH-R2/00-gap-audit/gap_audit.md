# M5-C manufactured conditional e-graph: R2 gap audit

Status: `gap_audit_only` / `review_pending`  
Scope: read-only comparison of the existing P1 conditional e-graph core and the
isolated M5-C manufactured adapter.  Claim ceiling: `synthetic_egraph_equality` /
`screen_only`.  `formal_credit: false`.

No Julia, DESC, S3, mesh, solver, provider, candidate, or vehicle execution was
performed for this audit.  No production or test source was edited.  The only new
files are this audit package under `00-gap-audit/`.

## Snapshot and evidence boundary

The dirty worktree was preserved.  Snapshot HEAD is
`b2c04d8339774635aaecd73651efcdb101e01b5d` (`2026-09-16T06:29:02+08:00`).
The P1 core files are tracked and clean in the scoped status check; the M5-C
adapter, M5-C test, oracle, and performance probe are untracked existing files.

Relevant exact SHA-256 values at audit time:

| item | bytes / lines | SHA-256 |
|---|---:|---|
| `src/IR/ConditionalEGraphTypes.jl` | 27558 / 355 | `885119aa142335f4dedcb1eb506b48350bc7793538b55d622ee9766e0ac47bee` |
| `src/IR/ConditionalEGraphSaturation.jl` | 24038 / 269 | `643775a5b10b9865269c66088d97ff7476312924f324d9c8b75107ad7749cdb3` |
| `src/Canonical/ConditionalEGraphCanonical.jl` | 18769 / 94 | `038c43431f053aa22ecac707a950aea19ae9d6a85157ce7d8325e43f3690eb12` |
| `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | 23892 / 474 | `7a1f52a96a7a79061b1e4bdb0fc1b7b41de5e45266d0ac4726a50502a4dc6500` |
| `test/conditional_egraph_p1_core_tests.jl` | 14685 / 239 | `a9216010bb1ed18959ffcf0f795c8dff40e1685e9c3e336b08d5811ad68d0ee3` |
| `test/conditional_egraph_p1_adversarial.jl` | 42284 / 611 | `df2ffdf8a2dabc20eecf786416aace65be8f50e39aede979bf5ea02b9a9318b4` |
| `test/conditional_egraph_p1_length_adversarial.jl` | 4960 / 102 | `33933587b0aeb14b2168198895541bfc20e4142e08cdc31adc136addc3db1ee1` |
| M5-C test | 14243 / 277 | `e0ed925a77f65aa045586f3c8dd78b2acfe8e023b29f1f95bba1f246b61a9355` |
| M5-C Python oracle | 4315 / 117 | `92db4edbea2060409d22ff453fa9eef119f8639f1ab6edb6cc01103218309dca` |
| M5-C performance probe | 8756 / 198 | `13318a66859e04cba58116dd9fede55d8a2a9002d7af7df877bd57c69b3d859c` |
| M5-A composition source | 26258 / 455 | `284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209` |
| M5-B inverse source | 26187 / 469 | `477b5a41c1a021fae84aeebaf13e3967c93b001ace7f38746af1ab1212110e59` |

The static inventory command ran in PowerShell PID `64172`, UTC
`2026-09-16T21:51:00.1002079Z`, exit `0`; a second budget-reference scan ran in
PID `8116`, UTC `2026-09-16T21:51:11.8959834Z`, exit `0`.  Raw stdout/stderr are
under `raw/`.  The command did not invoke Julia.

Historical execution evidence is not re-run or promoted:

* The previous C replay record (`docs/implementation/UP3-EARLY-PREPARATION/M5-CHAIN-REPLAY-R1/C_conditional_egraph_replay_r2/`) used the current M5-C source/test hashes.  Python oracle PID `108936` exited `0`; Julia PID `60876` was interrupted after the 20-minute preparation/test-only ceiling, with unknown exit and empty raw streams.  Its status is `deferred_performance_blocked`, not pass.
* M5-EGRAPH-R1 R3 ran Python PID `98120`, exit `0`, then Julia PID `75144`, exit `1` after 1m32s at `build_inverse(d, a)` before CEG assertions.  The retained diagnostic PID `68264`, exit `1`, identifies `invalid_upstream` / `MethodError: no method matching canonical_hash(::NamedTuple)`.  These raw streams remain authoritative for those attempts only.
* The R1/R2 records and the Python oracle are evidence of boundaries and failure classification, not evidence that the M5-C Julia adapter built, saturated, queried, or replayed successfully.

The R1 R3 narrative says that a test-local NamedTuple fallback was supplied, but
the current M5-C test snapshot (`e0ed925a...`) contains no such fallback and its
body still relies on the existing upstream path.  This discrepancy is recorded
as stale narrative, not as a repair or a pass; no source/test correction was made
here.

## What P1 core actually covers

The existing core is a bounded whole-program rewrite graph, not a general
sub-expression e-graph.  Its positive and adversarial tests establish:

* typed LHS/RHS interface closure; condition references and hashes; canonical
  order for rules and conditions; exact program/member hashes; deterministic
  graph and attempt bytes;
* reflexive versus conditional equality, replayable path-local traces, cycle and
  diamond traversal, duplicate-path suppression, and no-match fixed point;
* hard profile bounds (1--64 programs, 0--4096 rewrite attempts, 0--32 rounds,
  0--256 trace steps), atomic rewrite-attempt batches, explicit incomplete stop
  reasons, and refusal to hash an incomplete equivalence;
* wrong registry/manifest, wrong interface/type/rank/unit/temporal/effect,
  oversize input, malformed constructors, trace tampering, source immutability,
  Unicode/NUL canonical bytes, and hostile `Tuple`, `length`, `iterate`,
  `push!`, property, equality, and dispatch extensions in fresh processes.

The length adversarial suite specifically protects temporary-vector traversal
from dynamic `Base.length`; the core static scan finds zero dynamic `push!`,
dynamic `Tuple(...)`, or field-iteration patterns in the three core files.  The
core still represents conditions as typed requirements only: it does not call an
applicability checker or evaluate a condition truth value.

## M5-C coverage and semantic gaps

M5-C adds a frozen M5-A/M5-B join, eight named condition kinds
`(type, rank, domain, unit, port, owner, interface, conservation)`, a synthetic
two-rule catalog, screen-only provenance, typed failures, payload/hash, and
wrappers around the P1 engine.  Its test file intends to cover deterministic
build/assembly, member query and replay, catalog missing/altered/duplicate
conditions, upstream owner/provenance/hash tampering, zero budgets, status/hash
tampering, alias preservation, and the screen-only static boundary.  The Python
oracle models positive replay plus unmet, mismatched, and contradictory
conditions.

The important gap is that the Julia M5-C adapter never evaluates those eight
conditions.  `_m5ceg_condition_catalog` manufactures hashes; `_m5ceg_requirements`
checks catalog shape/hash self-consistency; and `_m5ceg_rewrite_set` passes all
requirements unconditionally to the P1 engine.  Therefore the Julia path can
return `conditional_equal` for an M5-C rewrite without checking an available
condition environment.  The oracle's `evaluate(required, available)` behavior
(`condition_unmet` => `equality_unknown`, contradiction => `fail_closed`) is not
implemented or wired into the Julia path.  The M5-C test's “condition rejected”
cases are malformed catalog/identity cases, not an unmet-condition semantic
case.

Further adapter-vs-core gaps:

1. M5-C uses dynamic `Tuple(catalog)`, generator collection, `for`, `push!`,
   `all`, `eachindex`, and direct `==` in production adapter paths.  Static
   inventory found 33 `push!` and 7 dynamic `Tuple(...)` matches, versus zero in
   each P1 core file.  The M5-C test has no fresh-process poison tests for these
   operations, so it does not inherit P1's traversal/dispatch authority.
2. `validate_manufactured_conditional_egraph(x)` checks schema/scope, source and
   frozen source hashes, condition self-consistency, graph source hash, and a
   coarse graph/status relation.  It does not bind-check `m5b_inverse_hash`,
   owner/provenance fields, catalog identity against the supplied M5-A/M5-B,
   rewrite-set identity, or `derivation.artifact === graph`.  In particular,
   `graph != nothing` with `derivation == nothing` is not rejected by the
   `missing_derivation` conjunction.  These are receipt-integrity gaps, even
   though the build path creates the fields consistently.
3. `_m5ceg_rhs` checks only 3 input ports, 8 nodes, and the first 3 node types;
   it does not independently assert frozen roots, input-port mapping, or the
   original operator/body identities before constructing its synthetic RHS.
   The upstream composition hash is an indirect guard, not a local RHS contract.
4. The second rule reverses root order and is explicitly synthetic.  It proves
   canonical root-order sensitivity/replay within the typed interface, not a
   physical or algebraic identity for M5-A/M5-B.
5. Generic aliases are conditionally installed.  In a combined include, M5-B's
   `validate`, `payload`, and `is_valid` aliases remain authoritative, while
   callers must use explicit M5-C names.  This avoids constant redefinition but
   leaves a potentially misleading generic API surface.

## Performance, budgets, and termination

The core has a real finite termination envelope: each round charges
`2 * active_count * rule_count` attempts before generating proposals; new member
and trace counts are checked against their maxima; visited `(program,conditions)`
keys prevent cycles.  This supports `terminal_deferred` and avoids an
unbounded-loop claim.

The performance gap is nevertheless material:

* proposal generation computes canonical AST bytes repeatedly, then constructs
  a candidate provenance and serializes it for every proposal before duplicate
  selection; sorting and duplicate checks are insertion-sort / quadratic scans.
  The registry projection and repeated canonical writers add further repeated
  work.  Total provenance path length is not charged by `max_trace_steps`; the
  counter limits fresh members, while every deep member carries a longer trace.
* M5-C first validates/builds the manufactured upstream chain, then reconstructs
  synthetic ASTs and invokes the above engine, and final validation serializes
  derivation/graph payloads again.  The public `saturate_manufactured_conditional_egraph(x;
  budget=...)` only type-checks the argument and returns `x`; it does not apply a
  new budget or re-saturate.  The result overload forwards kwargs, but the object
  overload still ignores the requested budget.  This is an API correctness and
  performance-debt boundary, not evidence of nontermination.
* The historical 20-minute interruption happened before typed tests collected,
  so no elapsed/allocation series exists for the M5-C positive lane.  The new
  `m5c_perf_r2/profile_probe.jl` describes four small increasing budgets and a
  60-second external timeout, but it has not been run in this audit.  Runtime
  and allocation claims must therefore remain `unknown`.
* Budget limits are per derivation attempt.  There is no persistent resume
  token/frontier: a deferred attempt rebuilt with a larger budget repeats all
  upstream construction and saturation.  M5-C's idempotent wrapper can hide
  this distinction if treated as a true saturation API.
* Core budget checks bound counts, but exact canonicalization and intermediate
  string/provenance construction occur before the final `max_bytes` acceptance
  check.  A byte-level memory/time ceiling is not established by the count
  budget alone.

## Minimum safe next slice

The smallest safe follow-up is an isolated, additive contract/fixture slice,
still outside the P1 core and still `screen_only`:

1. Freeze one typed condition-evaluation envelope for M5-C only: required
   catalog, available catalog, deterministic result union, and explicit
   `conditions_met`, `condition_unmet`/`equality_unknown`, and contradictory
   `fail_closed` outcomes.  Do not add provider, solver, candidate, physical, or
   search semantics.
2. Add an M5-C-only validation receipt that binds the full condition catalog,
   M5-B inverse hash, owner/provenance projection, rewrite-set hash, and
   derivation-to-graph relation.  Include negative controls for each missing or
   foreign field.  Keep it outside `src/IR`, the shared entry, and the default
   registry.
3. Add a static/hostile-process audit for the adapter (dynamic `Tuple`,
   `push!`, `length`, `iterate`, `==`, property and generator paths), or record
   an explicit waiver that these are test-only and not authority-sensitive.
4. Repair the object-level saturation contract by specifying whether a new
   budget means “rebuild” or “reject”; until that decision, callers must use the
   explicit build function and may not treat `saturate_*` as a resume operation.
5. Only after the above is reviewed, run one serial, externally timed bounded
   process using the existing performance probe.  Capture PID, UTC, command,
   exit/timeout, raw stdout/stderr, budget, stage timings, allocations, and
   artifact hashes.  A successful bounded run remains software/synthetic
   evidence only.

## Formal gates that must not be crossed

This audit does not authorize any of the following:

* no modification of `src/IR/ConditionalEGraphTypes.jl`,
  `src/IR/ConditionalEGraphSaturation.jl`,
  `src/Canonical/ConditionalEGraphCanonical.jl`, shared entry, registry,
  `Project.toml`/`Manifest.toml`, or existing P1 tests;
* no merge of M5-C into the production/candidate path and no UP5-01/UP5-02/
  UP5-03, B00/B04, R01-R10, L4, search/QD/MCTS, solver, provider, physical,
  engineering, semantic-edit, or equivalence credit;
* no conversion of `equality_unknown`, `terminal_deferred`, incomplete
  saturation, timeout, or missing upstream capability into inequality, novelty,
  prune, or physical failure;
* no use of an e-graph membership/equality receipt as evidence migration across
  G1/G2/G3 identity, owner, source, provider, solver-input, engineering, or
  physical scopes;
* no “performance pass” until a bounded positive Julia run has typed collection,
  completed raw streams, explicit exit/timeout, reproducible budget and
  independent replay/query checks.  The Python oracle alone cannot close this
  gate;
* formal re-entry remains the existing authority sequence: upstream T0/T1/T2
  and verified edit/provider gates, then independent M5-C condition/receipt
  review, then a separately authorized bounded execution.  This document is a
  gap audit, not that authorization.
