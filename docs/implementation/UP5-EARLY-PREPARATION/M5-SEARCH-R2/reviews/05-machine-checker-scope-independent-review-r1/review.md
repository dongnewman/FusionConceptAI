# Independent review R1 — M5-SEARCH-R2 machine-checker scope contract R2

## Decision

`GO_FOR_FUTURE_CHECKER_IMPLEMENTATION_ONLY / NO-GO_FOR_EXECUTION_OR_CREDIT`.

This is a read-only JSON/schema/hash/raw-reference/owner-scope audit of
`05-machine-checker-scope-contract-r2/**`, compared with the exact upstream
closure declared for `04-machine-checker-scope-contract-r1/**` and
`reviews/04-machine-checker-scope-independent-review-r1/**`. No checker,
fixture, authority receipt, M5-C gate, search, Julia, solver, provider, mesh,
physical, performance, or execution process was started. No contract, source,
test, registry, or existing review/repair package was modified. The only write
root for this review is:

`docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/05-machine-checker-scope-independent-review-r1/**`

The package itself remains `review_pending` / `not_implemented` /
`not_executed` / `terminal_deferred`, with `screen_only`, `no_publish=true`,
and `formal_credit=none`. The package manifest's
`implementation_authorized=false` remains unchanged; this review gives a
scoped disposition for a later checker implementation only.

## Read-only evidence

| check | result |
|---|---|
| package JSON parse | 8 JSON files; pass |
| upstream review-04 JSON parse | 2 JSON files; pass |
| package schemas | manifest, coverage, negative-vector, and process receipt validation; pass |
| package hash manifest | 11 entries, 0 missing/mismatched; pass |
| package artifact records | 10 entries, 0 missing/mismatched; pass |
| upstream provenance records | 15 entries, 0 missing/mismatched; pass |
| exact upstream closure | 15 files exactly equal to R1 package plus review-04 closure; pass |
| package/review raw references | both receipts rehashed at review; pass |
| future checker owner | `tools/m5_search_contract_r2/check_contract.py` absent |
| future test owner | `test/m5_search_contract_r2/test_check_contract.py` absent |
| append-only evidence owner | `tools/m5_search_contract_r2/evidence/` absent |
| future-owner collisions | 0 |
| Julia/search/checker execution | all false |

The review-04 raw record preserves its historical `RAW_STALE_SELF_HASH_CLAIMS`
finding. R2 binds those review bytes exactly; it does not repair or reinterpret
that historical record, and no stale raw claim is promoted to authority.

## P1/P2 relation and negative-vector coverage

`coverage_matrix.json` contains exactly 43 unique vector IDs with no dangling,
unreferenced, or duplicate coverage references. All eight principal relations
are present:

| relation | vectors | coverage judgment |
|---|---:|---|
| P1-01 authority metadata / typed absence | 5 | direct complete coverage |
| P1-02 content / operational / replay separation | 6 | direct complete coverage |
| P1-03 accepted M5-C gate identity | 4 | direct complete coverage |
| P1-04 budget arithmetic / fold | 7 | direct complete coverage |
| P1-05 descriptor identity | 4 | direct complete coverage |
| P2-01 failure precedence | 3 | direct complete coverage |
| P2-02 prohibited scan | 5 | direct complete coverage |
| P2-03 upstream provenance | 9 | direct complete coverage |

P2-03 directly names all required mutations: path, bytes, declared hash,
review path, duplicate path, unexpected path, review bytes/hash join, and
attempted inclusion of both the upstream manifest self-hash and upstream
hash-manifest self-hash. Each vector carries an explicit expected status and
failure code. The matrix is a future-checker control set, not an execution or
evidence result.

## Self-hash, raw-reference, and owner-boundary audit

The R2 manifest and hash manifest explicitly retain
`manifest_self_hash=excluded_by_policy` and
`hash_manifest_self_hash=excluded_by_policy`; the R2 hash manifest excludes
its own `hash_manifest.json` entry, while the manifest artifact list excludes
both metadata manifests. The bound R1 package's own manifest and hash-manifest
self entries are likewise excluded under their declared policy, and review-04
does not self-hash its own hash manifest. Attempted upstream self-hash
inclusion is represented as P2-03 negative coverage and must fail closed.

The package static receipt's stdout/stderr paths, byte lengths, and SHA-256
values rehash exactly. The review-04 process receipt's raw references also
rehash exactly. These are process/provenance checks only; they do not establish
fixture validity, authority validity, M5-C acceptance, search completion,
execution success, physical success, or formal credit.

## Authorization boundary

| action | disposition |
|---|---|
| future checker implementation | **YES, scoped only to the frozen checker owner** |
| future checker tests | **YES, only at the frozen test owner** |
| append-only checker evidence | **YES, only under the frozen evidence directory** |
| fixture creation or fixture execution | **NO** |
| authority/source/registry creation or promotion | **NO** |
| M5-C gate creation, acceptance, or use as authority | **NO** |
| search, Julia, solver, provider, mesh, physical, performance, or execution lane | **NO** |
| publish, campaign/winner claims, or formal credit | **NO** |

The exact later implementation scope is therefore limited to:

* `tools/m5_search_contract_r2/check_contract.py`
* `test/m5_search_contract_r2/test_check_contract.py`
* `tools/m5_search_contract_r2/evidence/**` (append-only evidence records)

The checker may only recompute the frozen contract relations and emit the
specified contract-only output/raw operational receipt. It must preserve the
claim ceiling `screen_only`, `implementation_credit=none`,
`formal_credit=none`, and `no_publish=true`; a checker exit `0` is not a gate,
fixture, authority, search, execution, or formal result. All other repository
paths, including this contract package, source, registries, existing tests,
fixtures, and search artifacts, are outside the authorization.

## Process record

* role: static JSON/schema/hash/raw/owner/coverage audit (read-only)
* PID: 70828
* UTC start: `2026-09-17T05:10:41.222618Z`
* UTC end: `2026-09-17T05:10:41.248453Z`
* exit: `0`
* Julia started: `False`
* search started: `False`
* checker implemented: `False`
* raw stdout: `raw/static_review.stdout.raw`
* raw stderr: `raw/static_review.stderr.raw`
