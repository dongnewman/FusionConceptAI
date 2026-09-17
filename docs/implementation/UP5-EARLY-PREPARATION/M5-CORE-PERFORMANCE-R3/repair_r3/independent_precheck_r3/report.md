# M5-CORE-PERFORMANCE-R3 repair R3 independent precheck

## Result

**Static verdict: `fail` for acceptance.**  R3 repairs the stale-field test
failure and materially improves the cache threat model, but the final receipt
writer is not fully fail-closed for cache-forged trace rule metadata or
cache-influenced proposal selection.  A valid-looking receipt can therefore
still contain metadata or derivation choices derived from a non-authoritative
hint.

**One focused Julia run: `GO` diagnostic-only; `NO-GO` for acceptance or
performance credit.**  The bounded test is useful for parse/dispatch and
ordinary honest-path regressions, but a pass cannot close the static findings.
The evidence ceiling remains `screen_only`; there is no formal credit,
frozen-baseline, runtime, allocation, speed, or factorial-root-cause claim.

## Scope and checks

Reviewed the current R3 edits at HEAD
`cfc745939a02fd023854dd4e9bb6d04ccadf9ee` in:

- `src/Canonical/TypedASTProgramCanonical.jl`
- `src/IR/ConditionalEGraphTypes.jl`
- `src/IR/ConditionalEGraphSaturation.jl`
- `src/Canonical/ConditionalEGraphCanonical.jl`
- `test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-CORE-PERFORMANCE-R3/repair_r3/{README.md,acceptance.md,evidence_manifest.json,fresh_process_plan.md}`

No Julia process was started. `git diff --check` and JSON parsing of the R3
manifest completed. This review wrote only this report and its sibling
`manifest.json`; the existing dirty M4 adapter/probe, task manifest, and
`runs/` entries were not edited or staged.

## Findings

### P1 — final receipt validation does not bind trace rule metadata to the
current canonical rule

The new `_CEGTraceFragmentsV1` checks `hash(rule_bytes) == rule_hash` and the
guarded trace constructor checks the rule reference
(`src/IR/ConditionalEGraphTypes.jl:141-210`). This proves internal consistency
of the supplied fragment, not that `rule_bytes` are the current canonical bytes
of the `WholeProgramConditionalRewriteV1`. A hostile same-module caller can
install a `_CEGRuleCacheEntryV1` with the right owner/rule/fingerprint and
arbitrary bytes; `_ceg_cached_rule_bytes` accepts it
(`src/IR/ConditionalEGraphSaturation.jl:44-60`), and `_ceg_new_trace` seals its
hash and bytes into the trace (`:292-317`).

The cache-aware receipt writer re-canonicalizes the rule AST and its stored
`lhs_hash`/`rhs_hash` (`src/Canonical/ConditionalEGraphCanonical.jl:73-80`),
but `_ceg_member_body` then emits provenance/trace bytes directly
(`:93-105`). `_ceg_trace_body` has no lookup of the current rewrite rule or
comparison of the trace `rule_hash` to that rule. Consequently a receipt can
contain an authoritative rule body alongside a trace carrying a different,
but self-consistent, rule hash. The R3 test only checks that a deliberately
wrong hash is rejected at fragment construction
(`test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl:121-148`); it does not
inject a same-fingerprint forged rule-cache entry and run the final receipt
writer.

### P2 — cache-dependent proposal selection is not revalidated by the final
receipt writer

The final writer re-canonicalizes each source/member/rule program and hashes
the current AST (`ConditionalEGraphCanonical.jl:46-48,73-80,93-99,122-134`),
which is a real improvement. In the normal route, `ConditionalEClassV1` also
rechecks member uniqueness and re-sorts members using a fresh local cache
(`src/IR/ConditionalEGraphTypes.jl:314-337`), so the earlier R2 order concern is
closed for ordinary construction. Saturation proposal dedup and winner
selection nevertheless use cache-derived bytes/keys
(`src/IR/ConditionalEGraphSaturation.jl:411-459`). A forged but structurally
accepted typed-AST or rule hint can change which proposal/provenance is chosen
while all individual emitted ASTs still pass current-byte checks. The final
writer has no independent re-derivation check for that semantic choice.

This is especially relevant because `_tac_cached_program_bytes` validates
owner/program/fingerprint but returns the hint without comparing it with the
current exact canonical bytes (`src/Canonical/TypedASTProgramCanonical.jl:676-695`).
`_tac_authoritative_program_bytes` catches a forged byte value when that program
is emitted (`:710-721`), but it does not repair or validate prior proposal
selection decisions. R3's “cache has no authority” statement is therefore only
partially true at the receipt boundary.

### P2 — hit validation is structurally broad but not uniformly authoritative

Positive static coverage exists: condition hits compare current bytes
(`ConditionalEGraphSaturation.jl:20-30`); rule hits check entry type, owner,
rule identity, and fingerprint (`:44-60`); member/proposal/proposal-sort hits
recompute expected keys and reject mismatches (`:160-171,218-256`); typed-AST
entries check owner, program identity, and fingerprint and cached hashes check
`hash(bytes)` (`TypedASTProgramCanonical.jl:676-707`). The immutable cache shell
also prevents ordinary owner reassignment (`ConditionalEGraphTypes.jl:28-41`).

Those checks intentionally establish hint integrity, not current canonical
authority. The test covers ordinary map mutation, deletion, owner assignment,
cross-entry injection, fragment owner mismatch, and same-digest/different-byte
hint rejection (`m5_core_perf_r3_tests.jl:62-148`). It still lacks a final
receipt negative for forged rule bytes/hash and a final receipt negative for a
cache-forged member order/dedup result. The “forced same-digest” witness is an
assigned digest reused with different bytes, not a cryptographic collision;
that is suitable for the threat model but should not be described as finding a
real SHA collision.

### P2 — the two-process plan is correctly deferred, but the harness is absent

`fresh_process_plan.md` specifies two independent `julia` launches with the
same project/startup/history flags, separate output files, and a bytewise JSON
comparison. The launches are sequential `Start-Process -Wait`, but they are
still two separate processes, which is sufficient for the stated determinism
check. The probe path is explicitly parent-owned and is not present in this
worker lane; the plan was not executed. Any future mismatch/exception/timeout
must remain deferred/fail-closed.

## Confirmed positives

- The diagnostic stale-field repair is real: the focused test uses
  `cache.canonical.entries` and current helper APIs; removed `program_bytes`,
  hash, and shadow fields are no longer referenced.
- Include order remains coherent: typed-AST canonical declarations precede
  conditional-egraph types, canonical writers, and saturation
  (`src/FusionConceptAI.jl:27,48-51`; the M4 include sequence was not changed
  by this review).
- Structured member/proposal identity keys remain length-delimited and
  unambiguous (`ConditionalEGraphCanonical.jl:4-25`), while legacy NUL
  projections remain used for historical ordering.
- `ConditionalEClassV1` performs a fresh current-byte uniqueness/order pass,
  closing the normal-route member-order concern even though saturation uses
  derivation-local hints.
- Guarded traces now carry owner, rule bytes, rule reference, and a hash
  recomputed from those bytes; guarded provenance checks every trace-step owner
  against the fragment owner (`ConditionalEGraphTypes.jl:201-205,246-272`).
- The ordinary honest path reuses cached fragments and avoids repeated direct
  `_typed_ast_program_json` work in the proposal loop; legacy constructors
  remain intentionally available.
- The first exact `_tac_permutations` canonicalization search remains
  factorial and explicitly unoptimized.

## Minimum parent-owned Julia command

The smallest allowed single focused diagnostic command is:

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

Record exit code and exceptions, but retain `screen_only`. A future acceptance
run additionally needs the two independent processes described in
`fresh_process_plan.md`, plus explicit final-receipt forged-rule/order
negatives.
