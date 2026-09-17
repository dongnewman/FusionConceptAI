# M5-SEARCH-R2 machine-checker scope contract R2

Status is fixed at `review_pending` / `not_implemented` / `not_executed`.
`implementation_authorized=false`, `search_executed=false`, `julia_executed=false`,
`terminal_deferred=true`, `no_publish=true`, `formal_credit=none`, and the claim
ceiling is `screen_only`. This package is a static contract correction only. It
does not create a checker, fixture, authority receipt, M5-C gate, search result,
execution receipt, or evidence credit.

## 1. Scope and frozen future owners

The only write root for this correction is:

`docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/05-machine-checker-scope-contract-r2/**`

The future owner paths are unchanged from the R1 contract:

| role | frozen future path | policy |
|---|---|---|
| checker | `tools/m5_search_contract_r2/check_contract.py` | implementation-only; absent at R2 capture; collision requires a new reviewed contract |
| test | `test/m5_search_contract_r2/test_check_contract.py` | implementation-only; absent at R2 capture; collision requires a new reviewed contract |
| append-only evidence | `tools/m5_search_contract_r2/evidence/` | implementation-only; no source, test, registry, review, or search writes |

This R2 package authorizes no implementation. It authorizes no fixture,
authority, M5-C, search, Julia, solver, provider, mesh, physical, performance,
execution, or formal-credit work. It does not modify the R1 package or its
independent review.

## 2. Upstream closure and self-hash policy

The input closure is the exact byte closure of
`04-machine-checker-scope-contract-r1/**` and
`reviews/04-machine-checker-scope-independent-review-r1/**`, as listed in
`manifest.json` under `upstream_provenance`. Every record uses a repository-
relative `/` path, byte length, and lowercase SHA-256. A future checker must
rehash every record before interpreting it and must reject a missing, duplicate,
unexpected, path-mutated, byte-mutated, or hash-mutated upstream record as
`fail_closed/provenance_changed`.

The two upstream package self-hashes are intentionally excluded by policy:
`04-machine-checker-scope-contract-r1/manifest.json` is not hashed inside that
manifest, and `04-machine-checker-scope-contract-r1/hash_manifest.json` is not
hashed inside that hash manifest. R2 must preserve this exclusion rather than
accept a caller-added self-hash. Any self-hash inclusion, omission of the
declared exclusion, or self-hash ambiguity is
`fail_closed/provenance_changed`.

The R2 `manifest.json` and `hash_manifest.json` also declare
`manifest_self_hash=excluded_by_policy` and
`hash_manifest_self_hash=excluded_by_policy`. Their own bytes are not used as
content identity. All non-self artifact records and all raw references are
freshly generated and are rehashed at handoff.

## 3. Frozen future command and status boundary

The future invocation remains:

```text
python tools/m5_search_contract_r2/check_contract.py \
  --input-bundle <sealed-input.json> \
  --output <checker-output.json> \
  --raw-dir <raw-output-directory>
```

No network, Julia, search, solver, provider, mesh, physical, or performance
command is permitted. A future implementation must emit PID, UTC `Z` start/end,
command, cwd, host, exit code, termination, raw stdout/stderr paths, byte
lengths, and SHA-256 in its operational receipt. Operational values are not
content identity and must not be placed in deterministic content receipts.

| exit | status | boundary |
|---:|---|---|
| 0 | `contract_machine_closure` | frozen relations recomputed; contract check only |
| 10 | `fail_closed` | malformed, foreign, duplicate, stale, identity, or provenance failure |
| 11 | `not_executed` | typed absence, missing authority/gate, or missing observation |
| 12 | `terminal_deferred` | valid interruption or budget stop after identity checks |
| 13 | `scope_violation` | prohibited write, lane, command, or claim input |

Exit `0` never means fixture validity, authority validity, accepted M5-C,
search completion, execution success, physical success, or formal credit. A
wholly typed-absent closure remains `not_executed` / exit `11`.

## 4. Required machine relations

The future checker, not JSON Schema alone, must recompute these relations:

1. Authority metadata and typed-absence closure: owner, source, version,
   freeze time, content/canonical/metadata/receipt hashes, and dependent joins.
2. Content/operational/replay separation: canonical content receipts exclude
   PID/UTC/command/cwd/host/attempt/raw fields; operational raw refs are
   rehashed; two distinct fresh attempts must agree on content, trace, config,
   authority, and result bytes.
3. Accepted M5-C identity: accepted plus authoritative status, canonical gate
   digest, non-null raw refs, and every R2 closure/config/cap join.
4. Budget arithmetic and fold: event arithmetic, strict sequence, stage/scope/
   seed/cap joins, final counters, event-list hash, and counter-fold hash.
5. Descriptor identity: length-framed canonical prefix and sealed ledger counts,
   descriptor hash, modulo-16 cell, axis order, label erasure, replacement
   tie-break, and equality through receipt/ledger/stop/entry.
6. Failure precedence: derive the one-based rank from the fixed order
   `fail_closed > contradiction > operational_interruption > budget_exhausted >
   numerical_fail > not_applicable > complete`; caller rank is never trusted.
7. Prohibited scan: recompute ordered token-list hash, input bundle hash,
   algorithm hash, matches, and scan receipt; scan only structured claim fields
   and raw claim metadata. Missing/unscanned claims remain `review_pending`,
   `no_publish`.
8. Upstream provenance: exact path, bytes, hash, duplicate/unexpected path,
   and explicit self-hash exclusion for both bound R1 package and review.

## 5. Negative-vector coverage correction

`negative_vectors/coverage_matrix.json` is the normative static coverage matrix.
It names every principal relation `P1-01..P1-05` and `P2-01..P2-03`, every
review-identified sub-relation, and one or more mutation vectors for each. Each
vector carries an expected status and failure code. P2-03 now directly covers
upstream path mutation, bytes mutation, declared-hash mutation, duplicate and
unexpected path mutation, review-path mutation, and attempted inclusion of both
upstream manifest self-hashes. The self-hash exclusions are also stated as a
positive invariant in the matrix; the negative self-hash mutations must fail
closed rather than be normalized.

The vectors are controls for a future implementation only. They are not fixture
executions and do not grant authority, M5-C, search, Julia, execution, or formal
credit.

## 6. Handoff

The fresh static process record is `execution_receipt.json`; raw stdout and
stderr are under `raw/`. The receipt records PID, UTC start/end, and exit `0`
for package-static validation only. It does not claim the future checker ran.
The package remains `review_pending` until a new independent review and root
decision authorize any later implementation.
