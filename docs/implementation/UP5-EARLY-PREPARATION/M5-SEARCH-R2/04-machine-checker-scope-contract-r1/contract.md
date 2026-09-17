# M5-SEARCH-R2 machine-checker scope contract R1

Status is fixed at `review_pending` / `not_implemented` / `not_executed`.
`implementation_authorized=false`, `search_executed=false`, `julia_executed=false`,
`terminal_deferred=true`, `no_publish=true`, `formal_credit=none`, and claim
ceiling is `screen_only`. This package is a contract only. It does not create a
checker, fixture, authority receipt, M5-C gate, search result, execution
receipt, or evidence credit.

## 1. Write and ownership boundary

The only write root for this turn is:

`docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/**`

The future checker has exactly one implementation owner and one test owner:

| role | frozen future path | current collision check |
|---|---|---|
| checker owner | `tools/m5_search_contract_r2/check_contract.py` | absent at contract capture; new path required |
| test owner | `test/m5_search_contract_r2/test_check_contract.py` | absent at contract capture; new path required |
| append-only evidence | `tools/m5_search_contract_r2/evidence/` | absent at contract capture; implementation may create only append-only records |

The owner files and evidence directory are not created by this package. If a
later checkout makes one of these paths exist, implementation must stop and
select a new, non-conflicting path in a new reviewed contract; it may not take
ownership of an existing file. No source, test, registry, `03-scope-contract-
repair-r2`, review, or search path may be modified.

## 2. Bound inputs and hashes

The future checker accepts one sealed JSON input bundle and re-hashes every
referenced file before interpreting it. The contract input closure consists of
the exact `03-scope-contract-repair-r2` package and the independent review:

* `03-scope-contract-repair-r2/contract.md`
* `03-scope-contract-repair-r2/acceptance_matrix.md`
* `03-scope-contract-repair-r2/manifest.json`
* `03-scope-contract-repair-r2/hash_manifest.json`
* every file listed by that package's `hash_manifest.json`
* `reviews/03-scope-contract-independent-review-r1/review.md`
* `reviews/03-scope-contract-independent-review-r1/review_receipt.json`
* `reviews/03-scope-contract-independent-review-r1/hash_manifest.json`

Each input record carries canonical `/` path, byte length and lowercase
SHA-256. A missing path, changed bytes, unexpected path, duplicate path,
manifest self-hash ambiguity, or changed upstream hash is
`provenance_changed` and maps to `fail_closed`. The input bundle itself has
`input_bundle_sha256 = SHA256(canonical_input_bundle_bytes)`; the checker must
recompute it rather than trust a caller field. `manifest_self_hash` and
`hash_manifest_self_hash` remain explicitly `excluded_by_policy`.

The existing R2 package deliberately has `typed_absent` fixture, grammar,
canonical-schema, source, and interface authority. The checker must preserve
that typed absence and must not infer authority from local source presence.

## 3. Future CLI, process receipt, and statuses

The frozen invocation is:

```text
python tools/m5_search_contract_r2/check_contract.py \
  --input-bundle <sealed-input.json> \
  --output <checker-output.json> \
  --raw-dir <raw-output-directory>
```

`--input-bundle`, `--output`, and `--raw-dir` are required. No network,
Julia, search, solver, provider, mesh, physical, or performance command is
permitted. The process writes one canonical output and raw stdout/stderr
records. The operational process record contains PID, UTC `Z` start/end,
command, cwd, host, exit code, termination, raw stdout/stderr paths, byte
lengths and SHA-256. These values are excluded from deterministic content
receipts and may never change content identity.

The exit/status mapping is fixed:

| exit | status | meaning |
|---:|---|---|
| 0 | `contract_machine_closure` | every checker relation passes; this is a contract check only |
| 10 | `fail_closed` | malformed, foreign, duplicate, non-finite, stale, or identity/provenance failure |
| 11 | `not_executed` | typed absence, missing authority, missing accepted M5-C gate, or missing required observation |
| 12 | `terminal_deferred` | valid operational interruption or budget stop after all identity checks pass |
| 13 | `scope_violation` | prohibited write, prohibited lane, prohibited command, or prohibited claim input |

Exit `0` never means fixture valid, authority valid, M5-C accepted, search
complete, execution successful, or formal credit earned. A `typed_absent`
closure is therefore a validly checked package but returns status
`not_executed` (exit 11), not `contract_machine_closure`.

## 4. Required checker recomputations

The checker is the sole authority for the following relations. JSON Schema may
reject shape, but schema validation alone is not sufficient.

### 4.1 Typed-absent closure and authority join

For every authority item, rehash `content_path` and canonical bytes when the
item is `authoritative`. Require non-null owner, source reference, RFC3339 UTC
freeze time, content/canonical/metadata/receipt hashes, exact id/version, and
matching closure joins. For `typed_absent`, require all payload, owner, source,
freeze, and receipt fields to be null and require every dependent closure item
to be `typed_absent`. Mixed authoritative/typed-absent children, inferred
authority, stale version, foreign owner, or null-as-authority is
`fail_closed`; a wholly typed-absent current closure is `not_executed`.

### 4.2 Content, operational, canonical bytes, and raw references

Canonical JSON is UTF-8, sorted-key, duplicate-key-free, explicit-null,
finite-number JSON with length-framed byte fields. Recompute content bytes and
`content_receipt_id = SHA256(canonical_content_bytes)`. Content receipts must
exclude PID, UTC, command, cwd, host, attempt/run IDs, exit and raw paths.
Operational envelopes must bind exactly one content ID/hash and must rehash raw
stdout/stderr and verify byte lengths. Fresh replay requires two distinct
attempts with identical content bytes, trace bytes, authority/config joins and
checker result; envelope-only equality is `not_executed`, changed content is
`replay_mismatch` / `fail_closed`.

### 4.3 M5-C gate identity and closure join

Only `status=accepted` plus `authority_status=authoritative` can satisfy the
gate branch. Recompute gate canonical bytes and require its receipt digest;
owner/reviewer/time, measurement command, thresholds, config/caps,
source/fixture/grammar/canonical-schema, candidate scope, entrypoint/checker/
environment hashes, variance policy, and raw refs must be non-empty and equal
to the R2 closure. `typed_absent`, rejected, stale, foreign, malformed, old
history, and supervisor exits cannot satisfy the gate and return
`not_executed` / `terminal_deferred`.

### 4.4 Budget arithmetic, fold, caps, scope, seed, and stage-counter

Recompute each event from zero: increment events have `delta=1` and
`after=before+delta`; stop events have `delta=0` and repeat the folded count;
`remaining=limit-after`; `after<=limit`; sequences are strictly increasing and
event hashes are canonical. Fold events and require final counters, event-list
hash, and counter-fold hash to match. Enforce config/cap joins, nonnegative
monotone counters, seed and scope identity, and legal stage/counter pairs.
Per-seed rewrite/e-class/e-node/trace caps are 32/128/512/512; QD
proposals/cells/members are 24/16/2; MCTS roots/depth/expansions/proposals are
4/3/24/24; global prefixes/evaluations/receipts/trace rows are 64/64/48/4096.
Solver/provider/mesh/physical lanes must remain zero. Overflow, underflow,
skip, duplicate, cross-seed, cross-stage, hidden counter, or cap mismatch is
`fail_closed`.

### 4.5 Descriptor canonical hash, cell, tie-break, and full-chain join

Recompute descriptor canonical input from length-framed canonical typed-prefix
bytes and sealed ledger counts; recompute descriptor hash and the two fixed
modulo-16 cell coordinates. Require descriptor schema hash, descriptor hash,
cell key, axis order, and label-erasure flag to agree in emitter config, every
content receipt, budget ledger, stop, and entry event. Replacement ordering is
bytewise `(cell_key, quality_key, canonical_prefix_hash, seed, sequence)`.
Labels, object addresses, family names, and display values are not identity
inputs; a changed cell or descriptor is `descriptor_identity_mismatch` /
`fail_closed`.

### 4.6 Fixed failure mapping and rank derivation

The checker derives the one-based rank from the fixed order
`fail_closed > contradiction > operational_interruption > budget_exhausted >
numerical_fail > not_applicable > complete`. Caller-supplied rank is ignored
and mismatches are rejected. The mapping is mutually exclusive: malformed,
duplicate, foreign, identity and checker-exception observations are
`fail_closed`; contradictions are `contradiction`; timeout/human interruption
and absent child are operational subtypes; stage/global caps map to their fixed
budget code; non-finite arithmetic maps to `numerical_fail`; typed unmet maps
to `not_applicable` with zero merge; only all required observations map to
`complete`. Secondary codes are metadata only.

### 4.7 Prohibited registry, input bundle, algorithm, and receipt

Recompute the fixed prohibited-token registry hash from the ordered token list,
canonical input bundle hash, scan algorithm hash, match list, and scan receipt
hash. Scan only structured execution/publication claim fields and raw claim
metadata; contract/review prose and schema descriptions are excluded. Empty or
missing input refs, changed token ordering, unknown token-set version, stale
algorithm, unbound scan receipt, or an unscanned execution claim is
`scan_incomplete` / `review_pending` / `no_publish` (or `fail_closed` when
identity is malformed). The current package is `not_executed` and has no scan
pass.

## 5. Output and claim ceiling

The output contains `contract_id`, recomputed input and relation digests,
status, derived failure rank/code, content receipt refs, operational process
receipt, and per-check evidence refs. Evidence refs point to raw bytes and
hashes; they do not become authority. `contract_machine_closure` is the only
positive checker status and means only that the frozen relationships were
recomputed for the supplied bundle. It creates no fixture, authority,
M5-C/search/execution/formal credit and cannot close UP5 or R01-R10.

## 6. Non-execution and handoff

This package does not run Julia, search, solver, provider, mesh, physical, or
performance work. It does not modify source, tests, registries, prior repair or
review directories. Independent review must rehash this package, inspect the
future owner collision record, and challenge every negative vector before any
implementation authorization. Status remains `review_pending` /
`not_implemented` until that review and root decision occur.
