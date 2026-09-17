# M5-SEARCH-R2 scope-contract repair R2

Status: `review_pending` / `not_executed` / `terminal_deferred`.
Claim ceiling: `screen_only`; `no_publish=true`; `formal_credit=none`.

This directory is a documentation/schema repair package. It closes the
P1-01..P1-05 and P2-01..P2-03 findings from review-01 while preserving the
review-00 scope boundary and the review-02 readiness snapshot. It does not
authorize implementation, search, Julia, provider, solver, mesh, physical or
performance execution. The only writable path for this turn is
`docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/03-scope-contract-repair-r2/**`.

## 1. Upstream provenance and status

The package binds the exact upstream bytes below. These are provenance inputs,
not authority for an execution. A future checker must rehash the paths before
accepting this package; a changed byte is `identity_mismatch` and cannot be
reused.

| upstream record | path | bytes | SHA-256 |
|---|---|---:|---|
| review-00 report | `.../reviews/00-scope-contract-independent-review-r1/review.md` | 9983 | `4e65eea8df88360fe92a73ed0f676aa49a5f35470590031ae44d3c677755f7ef` |
| review-00 receipt | `.../reviews/00-scope-contract-independent-review-r1/review_receipt.json` | 1299 | `bc0d1bdd17084616a6f062417a711854a96819fe8b1681ed48dd5e1eb7f8e6f1` |
| review-00 hash manifest | `.../reviews/00-scope-contract-independent-review-r1/hash_manifest.json` | 1733 | `2c2ad04b2786ddfd39e678eb4f6a21a44151e0b7f1e2cae1a4c2eb9f6868e0da` |
| review-02 report | `.../02-implementation-readiness-audit-r1/report.md` | 19536 | `c9a6531dec1be8ded2b65d0f3a1f34940eb90f7794815a78828be628e552c5c0` |
| review-02 receipt | `.../02-implementation-readiness-audit-r1/audit_receipt.json` | 1123 | `1b271b635972970e692e16ff223ef6f467b883e33ed620c66f457f94537f0184` |
| review-02 source hashes | `.../02-implementation-readiness-audit-r1/source_hashes.json` | 3705 | `02672be98f38941b896db963c933b991f986106e53b66816aac390f1ce3cf085` |
| review-01 report | `.../reviews/01-scope-contract-independent-review-r1/review.md` | 13267 | `d84613b8c54a167f39ed722757d95bbe93d3f7f2fc676cd4b41387eebfb53822` |

`review-00` defines the original scope, `review-02` confirms that the source
checkout does not contain the R2 implementation/checker/fixtures, and
`review-01` identifies the repair findings closed here. This package must not
claim that any of those records are a passing implementation or gate.

## 2. Authority metadata: future closure, current typed absence

Every fixture, grammar, canonical schema, source-authority record and execution
interface uses `AuthorityItemV2` from `schemas/authority_item_schema.json`.
Its required metadata is `id`, `version`, `authority_status`, `content_path`,
`content_sha256`, `canonical_bytes_sha256`, `owner_id`, `source_ref`,
`frozen_at`, `metadata_sha256`, and (where applicable) an authority receipt
hash. `authoritative` is a conditional state: it requires a non-empty owner,
source reference, RFC3339 freeze time, path, 64-hex content/canonical hashes,
and a non-null receipt hash. The checker must recompute all hashes and require
the same identity/version joins; JSON `null` cannot satisfy authority.

The current manifest deliberately records all fixture, grammar, canonical
schema, source bundle and interface items as `typed_absent`, with null paths,
hashes, owners and freeze times. `typed_absent` is a typed blocker, not a
placeholder authority. Any missing/stale/foreign/mismatched authority yields
`not_executed + terminal_deferred + no_publish`; it may not be reclassified as
unknown, cache hit, provider gap or historical evidence.

## 3. Sealed input closure and identity joins

`InputClosureV2` is the only admissible input. It binds the authority items to
mission, bounds, scenario, budget configuration, descriptor schema, emitter
configuration, and the upstream provenance receipt. All identity fields are
64-hex SHA-256 values or explicit root `null` only where the contract says so.
The closure hash is over an ordered, length-framed list of canonical bytes;
filesystem order, ambient environment, PID, UTC and temporary paths are not
inputs. A changed closure invalidates every downstream receipt.

Every proposal, rejection, stop and replay observation binds:

```text
source_bundle_hash, fixture_hash, grammar_hash, canonical_schema_hash,
mission_hash, bounds_hash, scenario_hash, config_hash, environment_hash,
candidate_prefix_hash, parent_prefix_hash-or-null, action_hash,
rule_hash-or-null, emitter_config_hash, descriptor_schema_hash,
descriptor_hash, descriptor_cell, seed, sequence, ledger_id.
```

Candidate and prefix identities are canonical-content-derived. Family, name,
benchmark, display labels and object addresses are never identity inputs.

## 4. Content receipt, operational envelope and replay

`ContentReceiptV2` contains deterministic content only: the sealed identity
joins, candidate/prefix/action/rule data, emitter/config and descriptor
identity, seed/sequence, canonical payload bytes/hash, strict budget snapshot,
typed trace rows, outcome, failure code and content references to raw streams.
It excludes PID, UTC, attempt/run IDs, command, cwd, host, exit status,
termination, temporary paths and random UUIDs. Its canonical bytes are strict
UTF-8 JSON with sorted keys, explicit nulls, duplicate-key rejection, finite
numbers only and length-framed byte fields. The checker recomputes
`canonical_content_sha256` and requires
`content_receipt_id = sha256(canonical_content_bytes)`.

`OperationalEnvelopeV2` records one observation around a content receipt:
attempt/run ID, PID, UTC interval, command/cwd/host, environment hash, exit and
termination, and raw stdout/stderr paths, byte lengths and SHA-256 values. It
must contain no content payload and cannot alter content identity. Its only
content join is the exact `content_receipt_id`/canonical-content hash.

Fresh-process replay compares content bytes, content receipt ID, canonical
trace bytes, config/authority joins and checker result. It does not compare PID,
UTC, attempt ID, run ID or raw paths. Two fresh content receipts are required;
without both, the result is `not_executed`, never replay pass. A content hash
mismatch is `replay_mismatch` and is not repaired by the envelope.

## 5. M5-C accepted gate

`M5CGateEnvelopeV2` is a preflight identity gate, not a post-hoc annotation.
Only `status=accepted` together with `authority_status=authoritative` can
permit a later bounded implementation attempt. That branch requires non-empty
`owner_id`, `independent_reviewer_id`, `accepted_at`, measurement command,
threshold/config/caps hashes, source/fixture/grammar/canonical-schema hashes,
candidate-scope hash, entrypoint/checker/environment hashes, variance policy,
raw stdout/stderr refs and a canonical gate-bytes hash. The
`gate_receipt_hash` must equal the SHA-256 of those canonical gate bytes, and
the source/grammar/caps/config joins must equal the R2 closure exactly.

`typed_absent`, `rejected`, `stale`, `foreign` and `malformed` branches require
`accepted_at=null`, a typed missing/rejection reason, and cannot satisfy the
preflight. An old M5-C path, supervisor exit or historical receipt is not an
accepted gate. The current package is `typed_absent`; the required result is
`terminal_deferred/no_publish`.

## 6. Budget events and foldable ledgers

`BudgetEventV2` is a single observed counter transition in a named ledger,
seed/scope, stage and sequence. Increment events have `delta=1` and must obey
`after=before+delta`, `remaining=limit-after`, `after<=limit`; stop events have
`delta=0` and repeat the already-folded counter without consuming budget. An
event hash is computed over its canonical event bytes. Event sequences are
strictly increasing within a ledger, and duplicate `(ledger_id, sequence)` is
fail-closed.

`BudgetLedgerV2` carries the exact config hash, descriptor identity, scope and
seed, counter caps, ordered events, final counters, and independent fold hashes.
The checker folds events from zero and requires the fold to equal `final_counters`
and the declared `counter_fold_sha256`; it also requires the event-list hash to
match. Counters are nonnegative, monotonic and scoped: a per-seed event cannot
increment a global counter, and an e-graph stage cannot increment QD/MCTS
counter names. `after>limit`, underflow, skipped sequence, cap/config mismatch,
wrong seed, duplicate event, hidden overflow or a final counter not equal to
the fold is fail-closed.

The caps are the bounded values from R1: per seed rewrite 32/e-class 128/e-node
512/trace 512; QD proposals 24/cells 16/members per cell 2; MCTS roots 4/depth
3/expansions 24/proposals 24; global unique prefixes 64/screen evaluations
64/proposal receipts 48/trace rows 4096; solver/provider/mesh/physical lanes
must remain zero. Cap stop reasons are stage-specific and always resolve to
`terminal_deferred` unless a higher-precedence identity, contradiction or
interruption failure has already won.

## 7. Descriptor identity

`SyntheticDescriptorV2` is synthetic occupancy bookkeeping only. Its fixed
dimensions are `prefix_byte_mod_16` and `typed_node_count_mod_16`, each with
unit `index`, range 0..15 and 16 bins. Projection is deterministic modulo
after nonnegative integer projection from canonical typed prefix bytes and
sealed ledger counts. Descriptor derivation has no physics, provider,
measurement or capability meaning; labels are erased.

The descriptor schema hash, descriptor hash and cell key are required in the
emitter configuration, every content receipt, every budget ledger and every
stop/entry event. The canonical descriptor input bytes, cell derivation and
replacement tie-break `(cell_key, quality_key, canonical_prefix_hash, seed,
sequence)` are frozen. A changed descriptor or cell is an identity mismatch,
not a harmless archive presentation change.

## 8. Unique failure precedence

`FailurePrecedenceV2` defines one ordered, mutually exclusive mapping. The
checker computes the rank; callers may not supply an arbitrary rank. The order
is:

```text
fail_closed > contradiction > operational_interruption > budget_exhausted
> numerical_fail > not_applicable > complete
```

Malformed/duplicate/non-finite/foreign/identity/schema failures map to
`fail_closed`; contradictory conditions map to `contradiction`; checker or
program exception is `program_exception` under `fail_closed` only after valid
sealed input, while timeout, human interruption, absent child or external kill
map to the declared operational interruption subtype; every e-graph/QD/MCTS/
global cap has one explicit budget failure code; non-finite synthetic arithmetic
maps to `numerical_fail`; unmet typed applicability maps to `not_applicable`
with zero merge; only all required observations met may map to `complete`.
Secondary codes are metadata and never change the winning status/resolution.

## 9. Prohibited scan and current evidence ceiling

The prohibited-token registry freezes version, token list, case-insensitive
exact-token/claim-boundary tokenization, scan scope, excluded explanatory
prose, ordered input paths/hashes, algorithm hash and scan receipt relation.
`tokens_sha256` is `sha256(UTF-8("token" joined by | in the listed order))`;
the input bundle and scan receipt use the same explicit canonical-byte rule.
The scan scope is only structured execution-claim/publication fields and raw
claim metadata; contract prose, review prose and schema descriptions are
excluded so that describing a boundary is not mistaken for making the claim.
A future scan must persist the exact input bundle hash, token-list hash,
algorithm hash, matches and scan receipt hash. Missing scan bytes/receipt are
not PASS. The current package has no execution claim and therefore remains
`not_executed`, `review_pending`, `terminal_deferred`, `no_publish`.

## 10. Handoff and non-claims

The next step is an independent review of this package, including schema
conditionality, replay joins, budget folding, descriptor identity, failure
mapping, prohibited scan boundary and upstream hashes. This package does not
create fixtures, source, tests, registry entries, a checker, a search result,
performance evidence or M5-C acceptance. It does not close the parent R01-R10
goal and does not grant any publication or formal credit.
