# M5-CORE-PERFORMANCE-R3 repair R2 independent precheck

## Result

**Static verdict: `fail` for acceptance.**  The repair has useful positive
structure, but its fail-closed cache boundary is not closed against a caller
who can reach the module's internal names and mutable fields.  Therefore the
R2 README/acceptance claim that all cache mutation, forged-marker, and
cross-derivation paths fail closed is not established by source inspection.

**One focused Julia run: `GO` for diagnostic-only execution, `NO-GO` for
acceptance or performance credit.**  A bounded run may detect parse, dispatch,
and ordinary cold/hot regressions, but a pass cannot waive the findings below.
The evidence ceiling remains `screen_only`; no formal credit, runtime,
performance, frozen-baseline, or factorial-search claim is made.

## Scope and evidence boundary

Reviewed at HEAD `cfc745939a02fd023854dd4e9bb6d04ccadf9ee` with the current
working-tree R2 edits in:

- `src/Canonical/TypedASTProgramCanonical.jl`
- `src/IR/ConditionalEGraphTypes.jl`
- `src/IR/ConditionalEGraphSaturation.jl`
- `src/Canonical/ConditionalEGraphCanonical.jl`
- `test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-CORE-PERFORMANCE-R3/repair_r2/{README.md,acceptance.md,evidence_manifest.json}`

No Julia process was started.  `git diff --check` completed for the reviewed
scope.  This review wrote only this report and its sibling `manifest.json`.
The existing dirty M4 adapter/probe, task manifest, and `runs/` entries were
not edited or staged.

## Findings

### P1 — the typed-AST cache is still forgeable

`_TACDerivationCanonicalCacheV1` is a `mutable struct` with publicly reachable
`canonical`, `program_bytes`, `program_hashes`, `sealed_program_bytes`,
`sealed_program_hashes`, `entries`, and `owner_token` fields
(`TypedASTProgramCanonical.jl:646-673`).  On a hit,
`_tac_cached_program_bytes/hash` checks identity/equality among the writable
maps and `_TACCanonicalEntryV1`, but it does not recompute bytes from the
actual `TypedASTProgramV1` (`:675-730`).  A caller can therefore replace
`entries[p]` with a module-constructed `_TACCanonicalEntryV1` containing
arbitrary bytes and their matching digest, and populate the four maps with the
same forged values.  `_TAC_CACHE_GUARD` is a module binding, not an inaccessible
capability; the focused test itself reaches `_CEG_SEAL_GUARD`, demonstrating
the relevant access model.  Reassigning the mutable `owner_token` also weakens
the intended derivation binding.

The R2 test covers preloading and mutation of only `program_bytes` and
`program_hashes` (`m5_core_perf_r3_tests.jl:62-76`).  It does not replace
`entries`, mutate either shadow map, or mutate the owner token.  Thus the
required deletion/preload/mutation/forged-marker/owner-token negative matrix
is incomplete.

### P1 — non-program cache maps have no shadow seal or owner validation

`_CEGDerivationCacheV1` remains mutable and exposes `condition_bytes`,
`rule_bytes`, `member_keys`, `proposal_keys`, and `proposal_sort_keys`
(`ConditionalEGraphTypes.jl:19-32`).  The cache-hit paths return these values
without recomputation or shadow comparison
(`ConditionalEGraphSaturation.jl:20-33,132-137,184-203`).  A forged condition
or rule byte string can alter identities, sorting, rule hashes, and canonical
receipts; forged member/proposal keys can alter visited/dedup decisions.
These are direct mutable-escape paths even if the typed-AST maps were fixed.
No R2 test mutates, removes, or preloads any of these maps.

### P1 — guarded fragments do not bind provenance to a cache or validate rule
bytes

`_CEGTraceFragmentsV1` validates source/target bytes against their hashes but
accepts an arbitrary `rule_hash`; it has no rule-byte field from which to
recompute that hash (`ConditionalEGraphTypes.jl:132-151`).  The guarded trace
constructor checks the marker and orientation bytes, then copies the supplied
rule hash (`:175-190`).  `_CEGProvenanceFragmentsV1` stores an owner token but
the guarded provenance constructor never compares it with a cache or with the
trace's derivation (`:194-251`).  The module guard is reachable, so marker
possession is not equivalent to derivation authority.  Cross-derivation
fragment injection, wrong-rule-hash fragments, and forged guard markers are
not negative-tested.

The normal path does reuse cached program/rule fragments
(`ConditionalEGraphSaturation.jl:239-263,300-316`) and avoids a second direct
`_typed_ast_program_json` call after a cache hit.  That is a positive
performance seam, not a proof of sealed ownership.

### P2 — the collision and fresh-process tests are witnesses, not the claimed
negative/runtime tests

The “forced collision” section uses one ordinary digest value and two distinct
`_CEGMemberKeyV1` values in a nested `Dict`
(`m5_core_perf_r3_tests.jl:102-115`); it does not force two distinct inputs to
share the production digest/equality path or verify fail-closed behavior under
such a collision.  The “fresh-process” section is two insertion orders in one
process (`:117-125`), not a fresh Julia process.  The tiny graph does cover
cold/hot equivalence and attempt bytes/hashes, query status, and replay
(`:127-151`), but it does not compare either receipt to a frozen HEAD baseline.

The structured member/proposal keys are length-delimited and therefore
unambiguous (`ConditionalEGraphCanonical.jl:4-25`).  Production ordering,
however, still uses the historical NUL projection
(`ConditionalEGraphSaturation.jl:355-359,423-427`); this is compatible with
the stated legacy-order goal, but the test does not establish fresh-process
ordering or cover all canonical byte classes.  `Dict` is used for lookup and
then explicit sorted projections determine emission; source inspection found
no acceptance evidence that this was measured in a fresh process.

## Checks that passed statically

- Include order is coherent: typed-AST declarations precede conditional-egraph
  types, canonical writers follow the declarations, and saturation follows
  both (`src/FusionConceptAI.jl:27,48-51`; matching M4 include sequence was not
  changed by this review).
- Legacy one-argument rule/set/member/equivalence/attempt writers remain and
  cached writers preserve their historical field order
  (`ConditionalEGraphCanonical.jl:68-150`).
- Length-delimited structured member/proposal key bytes are explicit and
  deterministic; `Dict` iteration is not used as the emission order in the
  reviewed saturation paths.
- The guarded trace/provenance path retains orientation, coordinates,
  condition-chain, and replay checks in the ordinary honest path.
- The first exact typed-AST permutation search remains intentionally
  unoptimized; this slice must not receive factorial-root-cause credit.

## Minimum parent-owned Julia command

If the parent chooses the diagnostic-only lane, the smallest focused command is:

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

Record exit code and any exception/byte mismatch, but keep the result
`screen_only`; do not use it to promote the R2 acceptance or to claim a
performance improvement.  The cache-authority findings above must be repaired
and independently retested before a future focused run can be a GO for
acceptance.
