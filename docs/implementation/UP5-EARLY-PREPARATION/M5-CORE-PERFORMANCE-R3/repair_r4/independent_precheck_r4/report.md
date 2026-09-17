# M5-CORE-PERFORMANCE-R3 repair R4 independent precheck

## Decision

**Static verdict: `pass_with_findings`.**  R4 closes the R3 authority gap in
the normal cache-aware derivation and receipt paths: current canonical rule and
program material now controls proposal identity, ordering, winner selection,
and final receipt validation.  Remaining findings are boundary/test issues,
not a discovered P1 bypass in the intended path.

**Focused Julia: `GO` diagnostic-only.**  A bounded run may check parsing,
dispatch, cold/hot/query/replay behavior, and receipt exceptions, but it does
not promote this screen-only evidence to performance or formal credit.

**Two-process follow-up: `NO-GO` in this worker lane / `GO` only as a later
parent-owned action.**  The documented plan really launches two independent
Julia processes, but it was not executed and its probe is not supplied here.

## Scope and evidence boundary

Reviewed at HEAD `cfc745939a02fd023854dd4e9bb6d04ccadf9ee`:

- `src/Canonical/TypedASTProgramCanonical.jl`
- `src/IR/ConditionalEGraphTypes.jl`
- `src/IR/ConditionalEGraphSaturation.jl`
- `src/Canonical/ConditionalEGraphCanonical.jl`
- `test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-CORE-PERFORMANCE-R3/repair_r4/{README.md,acceptance.md,evidence_manifest.json}`
- the inherited `repair_r3/fresh_process_plan.md`

No Julia process was started. `git diff --check` and JSON parsing were run
read-only. Only this report and its sibling `manifest.json` were written. The
existing dirty M4 adapter/probe, task manifest, and `runs/` entries were not
edited or staged.

## Authority checks that pass statically

### Rule/program cache authority

`_ceg_cached_rule_bytes` first computes current `_ceg_rule_bytes(rule)` and
then, on a hit, checks entry type, owner token, exact rule identity, rule
reference, stored lhs/rhs digests, fingerprint, exact current bytes, and the
current hash (`src/IR/ConditionalEGraphSaturation.jl:53-85`). A same-fingerprint
foreign or forged-byte entry therefore fails before it can feed a trace or
receipt. `_ceg_current_program_bytes` similarly goes through
`_tac_authoritative_program_bytes` (`:20-27`), so program identity uses current
canonical AST bytes rather than a hint.

### Dedup/sort/winner authority

Member identity uses current program bytes (`:178-196`). Proposal identity
rebuilds current rule bytes, current source/target AST bytes, orientation, and
current conditions on every cache-hit validation (`:243-263`). Proposal sort
keys are checked against that current key (`:265-282`). Saturation matching,
proposal dedup, winner grouping, and winner ordering therefore consume current
material (`:434-485`), while cache maps are only memoized validated results.
The fresh `ConditionalEClassV1` constructor also checks duplicate current
member keys and performs the final member sort with a local cache
(`src/IR/ConditionalEGraphTypes.jl:314-337`). I found no remaining intended
path where a forged cache value can choose a different winner without an
exception.

### Receipt and provenance authority

The cache-aware final writer revalidates current source/member/rule bytes and
passes the current rewrite set and source root into member provenance emission
(`src/Canonical/ConditionalEGraphCanonical.jl:98-104,160-170`).
`_ceg_validate_provenance_current` checks current source and target hashes,
owner token, membership of every trace rule in the current rewrite set, current
rule hash, orientation-derived lhs/rhs source/target hashes, cumulative
condition chain, final target, and final conditions
(`:113-143`). Query receipts retain source/target/rule authority fields and use
the same validator (`:203-215`; `src/IR/ConditionalEGraphTypes.jl:362-392`).
Thus the prior R3 forged-trace rule-hash path is closed in the authority writer.

## Findings

### P2 — authority writer explicitly permits legacy owner `nothing`

`_ceg_validate_provenance_current` accepts either the current cache owner or
`nothing` (`ConditionalEGraphCanonical.jl:121-124`). This preserves the legacy
trace constructor, whose owner is intentionally `nothing`, but it means the
authority receipt is not strictly derivation-owner-bound for a legacy-formed
trace. If legacy provenance is an intentional compatibility boundary, document
this exception as such; otherwise split the legacy writer from the authority
writer and reject `nothing` in the latter.

### P2 — direct final-receipt forged-fragment coverage is still indirect

The focused test now covers forged same-fingerprint rules, foreign-rule traces,
cross-rule provenance, winner-key injection, and a forged rule cache rejected by
the final attempt writer (`m5_core_perf_r3_tests.jl:149-175,231-235`). It does
not directly construct a guarded trace with self-consistent forged bytes and
then assert final receipt rejection; it checks the validator directly for the
foreign trace and checks the rule cache hit separately. The source path is
closed, but a direct final-receipt regression test would make the claim
complete.

### P2 — per-step required-condition equality is constructor-dependent

The current receipt validator recomputes the cumulative condition chain and
final conditions (`ConditionalEGraphCanonical.jl:131-136`), while trace
constructors populate `required_conditions` from the rule. The validator does
not itself compare each step's `required_conditions` tuple byte-for-byte with
the current rule's `required_conditions` (the replay path does this at
`src/IR/ConditionalEGraphSaturation.jl:540-542`). This is safe for ordinary
typed construction, but an explicit per-step equality check would better match
the stated “every step” authority contract.

## Regression and process checks

- The stale-field repair is present: the focused test no longer references the
  removed `program_bytes`, `program_hashes`, or shadow-map fields.
- Cold/hot equivalence and attempt bytes/hashes, current result/query receipts,
  query status, replay, length-delimited key behavior, forced assigned-digest /
  different-byte hints, and Dict insertion-order projections remain present in
  the test (`m5_core_perf_r3_tests.jl:177-235`).
- Structured member/proposal keys remain length-delimited
  (`src/Canonical/ConditionalEGraphCanonical.jl:4-25`); legacy NUL projections
  remain only for historical sorting compatibility.
- The inherited fresh-process plan launches two independent sequential Julia
  processes with identical flags and compares their JSON bytes. It is a plan,
  not runtime evidence; missing probe, exception, timeout, or mismatch remains
  deferred/fail-closed.
- The first exact `_tac_permutations` search remains factorial and explicitly
  unoptimized. No factorial-root-cause claim is allowed.

## Minimum parent-owned focused command

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```
