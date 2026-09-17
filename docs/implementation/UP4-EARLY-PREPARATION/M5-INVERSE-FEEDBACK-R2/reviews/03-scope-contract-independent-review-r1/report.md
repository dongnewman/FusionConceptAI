# M5 inverse-feedback R2 scope-contract independent review R1

## Decision

`changes_requested`; `implementation_not_authorized`; `status=review_pending`.
Bounded `screen_only` V2 implementation is **not authorized** by this review.
The maximum eventual claim remains `manufactured_inverse_feedback/screen_only`,
with `formal_credit=none`.  This review grants no UP4-01/02/03/04, B07A/B, B08,
provider, solver, engineering, physical, candidate, or R01--R10 credit.

No P0 finding was assigned: this is a contract/readiness blocker, not a runtime
safety or hardware command.  The unresolved P1 findings below nevertheless stop
the implementation lane until a fresh, independently reviewed contract is
frozen.

## Boundary and static evidence

- Repository: `D:/006-Programing/LMC/FusionConceptAI`, `main`, HEAD
  `b2c04d8339774635aaecd73651efcdb101e01b5d`.
- The worktree is dirty (384 porcelain lines in the package's start receipt).
  Existing changes were treated as pre-existing and were not modified.
- Five contract schemas pass JSON parse and Draft 2020-12 meta-schema checks.
  A local, registry-backed resolver can construct validators for the two
  external URNs (`canonical-bundle` and `failure-record`).
- The current 03 package's 17/17 `hash_manifest.json` entries and 4/4 resolver
  registry entries match current bytes.  This is an internal package-consistency
  result only; it is not a fresh accepted freeze.
- The listed eight dependency-closure entries in `manifest.json` also match
  current bytes.  The list is not the actual source/include closure (P1-03).
- Only PowerShell/Python/static file inspection was used. Julia, DESC, S3,
  mesh, solver, provider, hardware, network/download, and external writes were
  not invoked.

## Findings

### P1-01 — Canonical ref/join is still incomplete and not fail-closed at the result boundary

The repair adds typed refs and a checker contract, but the join is not a complete
machine-checkable identity join:

- `input_schema.json` accepts both `canonical_bundle` and an independent
  `candidate_binding`.  `checker_contract.json` J01 checks only the candidate
  ref, J05 only the source ref, and J08--J10 only the G1/G2/G3 body hashes.  It
  has no pointer-level equality for the binding's parent, mission, scenario, or
  full source typed refs, and no recomputation of `candidate_binding`'s declared
  `binding_sha256`.
- J06/J07 recompute the payload and candidate-body digest, but there is no
  equivalent required recomputation/equality closure for every typed ref's
  body/content digest or for the binding projection.  A structurally valid
  bundle and a structurally valid but foreign binding can therefore coexist
  until an unspecified checker implementation supplies the missing rules.
- `output_schema.json` carries `join_checker_pass` as an unconstrained boolean;
  the `valid_screen` branch does not require it to be `true`.

Required closure: enumerate all canonical/binding/result projection pointers,
recompute each declared digest from canonical bytes, and add positive plus
foreign-join/canonical-digest-mismatch vectors.  `valid_screen` must imply the
join result is true, not merely present.

### P1-02 — The dual-replay gate is present in shape but can be bypassed by a valid-screen result

The output schema correctly requires, under `status=valid_screen`, two unique
attempt IDs, `[0,0]` exits, semantic and byte equality, `fresh_refreeze=true`,
non-empty raw/process refs, and `typed_checker_pass=true`.  That closes the
specific zero/one/duplicate/nonzero replay shape at schema level.

It does not close the full gate.  A schema-valid `valid_screen` instance can
still carry:

- `evidence.authority = unknown_until_fresh_refreeze`;
- `binding_receipt.join_checker_pass = false`; and
- `engineering_feedback.cas_pass`, `identity_pass`, `owner_pass`, and
  `direction_pass` all `false`.

The schema has no implication that those values must be true.  The checker
contract describes such rules in prose, but no executable checker or receipt is
part of the review input.  This is a P1 because the result status can claim
screen validity while the canonical join and feedback mutation checks failed.
Add explicit valid-screen implications and negative vectors for mismatched
authority, join, CAS, identity, owner, and direction.  No replay evidence exists
yet, as expected for a not-implemented lane; that absence must remain
`not_executed`, not be converted into a pass.

### P1-03 — Dependency closure is not the loaded-source closure

The eight manifest entries (M5/M5-A source, test, oracle, `Project.toml`, and
`Manifest.toml`) hash correctly, but they do not freeze all files that the
declared replay would load.  Read-only source inspection shows:

- `ManufacturedAutoCompositionV1.jl` includes
  `src/IR/PhysicalTypes.jl`, `ConservationLedger.jl`, `OperatorRegistry.jl`,
  `TypedAST.jl`, and `OperatorHypergraph.jl`;
- it also includes the four M4-A..M4-D source files; and
- M5-A tests include those four M4 source files directly, while M5 includes
  M5-A transitively.

Those IR/M4 files are absent from the 03 `dependency_closure` and from the
`raw/dirty_inventory_start.json` dependency paths.  The current `imports` labels
(`M4RationalV1` or a local role) do not provide path/bytes/SHA-256 closure.
An implementation/replay can therefore vary with un-frozen loaded bytes.
Freeze every actual include/import path (plus the declared runtime/environment
fingerprint) and recompute the bundle/hash receipt before reconsidering
authorization.

### P2-01 — Failure enum sets match, but failure code mapping is not closed

The record schema and taxonomy schema have exact matching sets (33 codes, 11
classes, 4 resolutions), and `uniqueItems` is present for a future taxonomy
array.  However, `failure_taxonomy.json` is itself only a schema: it defines
independent enum sets and contains no concrete one-row-per-code mapping of
`code -> class -> resolution`.  The T01 checker statement “each code maps once”
cannot be evaluated from the current taxonomy document.  Thus an implementation
could choose an arbitrary class/resolution for a known code while passing the
reported set-equality audit.

Add a concrete, closed mapping (or a single shared `$defs` generated from one
mapping) and require every record mapping to equal it; add unknown-code and
resolution-mismatch negative vectors.

### P2-02 — Dirty closure and fresh package authority are pending, not accepted

The start inventory records the dirty baseline, and the package's current
hash-manifest/resolver bytes are internally stable at this review snapshot.
But `raw/dirty_inventory_end.json` explicitly says
`comparison=not_executed_until_handoff` and `status=pending_independent_review`.
There is therefore no review-end per-path comparison proving “baseline paths
unchanged plus this package only.”  The 04 readiness audit also records a real
post-freeze change of `canonical_bundle_schema.json` from 5280 bytes /
`351d954d...d313` to the current 5249 bytes /
`24851465...f0f3`.  The current package hash is consistent now, but the previous
freeze is invalidated and no new independent freeze/receipt has replaced it.

Likewise, current M5/M5-A source bytes differ from historical R1 accepted
receipts; the historical result remains historical-only.  Capture a new
review-start/end inventory and fresh hashes after all contract edits, then have
a different role review those exact bytes.  Until then “hash stable” means only
stable within this uncommitted snapshot, not stable authority.

### P2-03 — CAS/history fields are shaped but cross-field closure remains underspecified

The output history has version, sequence, owner/actor, before/after hashes and
UTC-`Z` syntax, and the checker names stale-CAS, foreign-owner, wrong-direction,
duplicate-sequence, dynamic-insert, and fail-atomic controls.  The result-level
`feedback` object, however, omits the full immutable identity tuple
`(candidate, source, owner, edge, parameter, axis, direction)`, and the checker
does not enumerate the required pointer equalities against the input edge and
deletion request.  Before/after hashes are declared but no state-byte projection
is supplied for recomputation.  This remains a typed-checker obligation rather
than a closed contract; it must be resolved together with P1-02 before any
`valid_screen` result can be accepted.

## Historical review crosswalk

| review02 finding | independent R1 disposition |
|---|---|
| F7 canonical candidate/source join | **P1 persists**; typed refs exist, full cross-object equality/digest closure does not |
| F8 valid-screen dual replay gate | **P1 persists at result boundary**; replay shape is present, but false join/CAS/unknown-authority values can still accompany `valid_screen` |
| F9 local external resolver | **static partial pass**; absolute URNs, current registry hashes, local-only policy, and `typed_absent` are present; no runtime resolver/unknown-URI receipt exists |
| F10 feedback CAS/history | **P1/P2 persists**; fields and named controls exist, but immutable identity and state-transition equalities are not executable/closed |
| F11 dependency/dirty closure | **P1/P2 persists**; listed hashes match, loaded include closure is incomplete, and review-end comparison is pending |
| F12 failure taxonomy | **P2 persists**; enum sets match but code-to-class/resolution mapping is absent |

## Authorization decision

**No** bounded `screen_only` V2 implementation authorization is granted.

The minimum re-gate is: (1) close P1-01 and P1-02 with executable pointer and
valid-screen implications plus negative controls; (2) freeze the complete loaded
dependency closure from P1-03; (3) add the concrete failure mapping; (4) capture
review-end dirty closure; (5) fresh-freeze the exact current package and source
bytes; and (6) obtain a separate-role review followed by Sol/root decision.
After those gates, any lane remains isolated manufactured software only and still
requires two serial replay receipts.  It cannot authorize UP4/B07A/B07B/B08,
provider, solver, engineering, physical, hardware, or formal credit.

No contract, source, test, registry, or historical package was modified by this
review; only this independent-review directory is in scope.
