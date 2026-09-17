# M5 inverse-feedback R2 R4 scope-contract independent review R1

## Decision

`changes_requested`; `implementation_not_authorized`; `status=review_pending`.
Bounded `screen_only` V2 implementation is **not authorized** by this review.
The maximum eventual claim remains `manufactured_inverse_feedback/screen_only`,
with `formal_credit=none`.  This review grants no UP4-01/02/03/04, B07A/B,
B08, provider, solver, engineering, physical, candidate, or R01--R10 credit.

The audit was restricted to PowerShell/Python JSON, schema, bytes, SHA-256,
path and timestamp inspection.  Julia, DESC, provider, solver, mesh, S3,
hardware, network/download and source/test execution were not invoked.  The
only intended writes are this review directory.

## Inputs and boundary

- Repository: `D:/006-Programing/LMC/FusionConceptAI`, branch `main`, HEAD
  `b2c04d8339774635aaecd73651efcdb101e01b5d`.
- Reviewed input: `06-scope-contract-repair-r4/**`.
- Cross-check input: `reviews/05-scope-contract-independent-review-r1/**`.
- R4 remains explicitly `review_pending`, `not_implemented`,
  `not_executed`, `current_authority=unknown_until_fresh_refreeze`, and
  `external_authority=typed_absent`.

## Reproduced static checks

| Check | Reproduced result | Boundary |
|---|---|---|
| D12 pointer and canonical bytes | **pointer present**: `candidate_binding.canonical_bundle_sha256 -> canonical_bundle.canonical_bytes`, base64 decode and JCS payload equality are stated | No runtime bundle was supplied or executed; `canonical_bundle.canonical_bytes_sha256` itself is not an independently enumerated `digest_recomputations` entry. |
| D12 canonical hash negative controls | **2 vectors present**: `canonical_bytes_mismatch`, `canonical_bytes_sha256_mismatch`; both expected `fail_closed` | Inventory only; no checker execution. |
| 36 negative vectors | **36/36 unique**, exact set equality with `checker_contract.negative_controls` | `execution=not_executed`. |
| CAS/history identity/version/state/fail-atomic | **schema/prose fields present**: full seven-field tuple appears in feedback, deletion and history; history `minItems=1`; state/operation bytes and hashes are required; fail-atomic equality/append-zero fields are required | Version arithmetic, tuple joins, byte/hash recomputation and mutation rejection remain checker-contract obligations; no executable checker or fixture receipt is present. The fail-atomic receipt has no explicit rejected-operation bytes/projection for `rejected_operation_sha256`. |
| Dependency closure | **17/17 listed path bytes/SHA match**, all declared include edges point to listed files | The declared closure digest fails under the contract's actual TAB/LF serialization; see P1-R4-01. |
| Local URN registry | **7/7 entries match** package path, byte count and SHA; unique URNs | Static registry only; unknown external authority remains `typed_absent`. |
| Failure mapping | **33/33 unique rows**, code/class/resolution sets populated | Concrete taxonomy does not validate against its schema because the schema expects the r3 record URI; see P1-R4-03. |
| Dirty start/end | **baseline unchanged and 24 package-only additions** in captured receipts; start `2026-09-17T04:44:09.8329233Z`, end `2026-09-17T05:04:09.0000000Z`, end > start and artifact latest | This is a receipt comparison at R4 handoff, not fresh authority for implementation; the R4 freeze is still pending independent review. |
| Package hash closure | **26/26 entries match**, actual package files excluding `hash_manifest.json` = 26, missing/mismatch = 0 | This is package self-consistency only. |
| Draft 2020-12 schema shape | **7/7 schemas pass** `Draft202012Validator.check_schema` | Cross-object checker semantics are not validated by JSON Schema. |

## Findings

### P1-R4-01 — The 17-entry dependency closure hash is computed from the wrong serialization

`manifest.json` declares:
`dependency_closure_serialization = "path\\tbytes\\tsha256\\n sorted by path, UTF-8"` and
`dependency_closure_sha256 = a3463dfe339219c5a78ff611a2fd1d0444bdda9aefcccd54d899a6b9ab0a21ad`.
Recomputing the sorted `path<TAB>bytes<TAB>sha256<LF>` stream from the same 17
entries gives
`5c0aaed8d7be419b731f7559c4fad4d30a7cae21c437957d93d430aa2a0f353b`.
The declared digest instead matches the stream containing literal backslash
characters (`\\t` and `\\n`).  Therefore `same_dependency_closure` is not a
closed, unambiguous identity at the contract-defined byte boundary.  This is
independent of the fact that all 17 listed source bytes and individual hashes
currently match.

Required repair: define actual UTF-8 TAB/LF bytes unambiguously, recompute the
manifest and every dependent receipt, then re-capture the fresh start/end
closure.

### P1-R4-02 — D10 source-content and typed-content closure still has no byte source

`checker_contract.json` declares D10 as
`/canonical_bundle/payload/source/body/content_sha256` recomputed from
`/source_content_bytes`.  No `source_content_bytes` property exists in
`schemas/canonical_bundle_schema.json`, `schemas/input_schema.json`, or
`schemas/output_schema.json`; no package artifact supplies that projection.
The contract's J03 says every typed body/content digest is recomputed, but D03--
D09 only name typed `body` projections and D10 points to an absent path.  The
canonical and binding `content_sha256` fields can consequently be structurally
valid while lacking a defined byte source for recomputation.  The output
binding also carries a reduced source object without the canonical source
schema/provenance digest fields, so a result cannot itself carry the complete
metadata join claimed by J01.

Required repair: freeze a defined source-content byte projection (or a local
dependency artifact with an explicit pointer), enumerate every typed
`content_sha256`/`body_sha256` recomputation and result join, and add a negative
control that removes or changes the source-content bytes.

### P1-R4-03 — The concrete 33-row failure taxonomy is rejected by its own schema

`failure_taxonomy.json` declares
`urn:fusionconceptai:m5-inverse-feedback-r2:r4:failure-record`, and the local
resolver registry points to the r4 failure-record schema.  However,
`schemas/failure_taxonomy_schema.json` has a `record_schema_uri` const of
`urn:fusionconceptai:m5-inverse-feedback-r2:r3:failure-record`.  Local
Draft-2020-12 validation returns one error at `$.record_schema_uri`; the row
count and 33 unique code mappings therefore do not constitute a schema-valid
taxonomy.  This also breaks the claimed exact mapping gate before any runtime
record is considered.

Required repair: choose one version, update the schema/document/registry
consistently, revalidate all 33 rows, and refresh the package hash manifest.

### P2-R4-04 — CAS/history/fail-atomic rules are described but not executable evidence

The shape improvements are real: seven identity fields are present across
feedback/deletion/history, history has `minItems=1`, sequence/version/state and
operation fields are required, and fail-atomic receipts require byte equality,
hash fields and `history_append_count=0`.  The checker still remains
`contract_only_not_executed`.  C01--C03 are prose invariants with no executable
checker receipt, no accepted-delete event linkage proving C02's “one append per
accepted delete”, and no explicit rejected-operation byte projection for
`rejected_operation_sha256`.  Thus the review records this as a typed contract
shape pass with execution/evidence deferred, not as demonstrated fail-atomic
closure.

Required repair before any implementation authorization: provide a local
checker/fixture contract that makes the tuple/version/state/operation byte
projections and fail-atomic mutation receipt machine-checkable, then preserve
the required negative vectors as executed controls.  This does not authorize
running the implementation in this review.

## Crosswalk against review 05

| Review 05 blocker | R4 disposition |
|---|---|
| P1-R3-01 D12 canonical bytes | The real `canonical_bytes` field and pointer now exist; D12 vectors are present. The canonical-bytes hash field still lacks a separate digest entry, and broader D10/content closure remains open (P1-R4-02). |
| P1-R3-02 CAS/history identity | Tuple and history fields are materially expanded; schema/prose shape is present, but executable C01--C03/fail-atomic evidence remains deferred (P2-R4-04). |
| P1-R3-03 dirty end/fresh freeze | R4 receipts have correct internal time ordering and baseline/new-path comparison, but `freeze_receipt.status=pending_independent_review` and `current_authority=unknown_until_fresh_refreeze`; no implementation authority follows. |
| P2 failure mapping | Concrete 33-row mapping exists, but its schema URI is r3 while the document and registry are r4 (P1-R4-03). |
| P1/P2 dependency closure | 17 entries and include edges are present and individual hashes match, but closure digest serialization is self-inconsistent (P1-R4-01). |

## Authorization decision

**No** bounded `screen_only` V2 implementation authorization is granted.

The exact future scope, if and only if Sol/root later authorizes it after a
fresh independent freeze and all gates close, is an isolated manufactured
software fixture lane only: local package inputs, no external authority, no
provider/DESC/solver/mesh/hardware/network, two serial replays, and a claim
ceiling of `manufactured_inverse_feedback/screen_only`.  `formal_credit` stays
`none`; external authority stays `typed_absent` / `not_implemented`.  No
UP4/B07A/B08, provider, solver, engineering, physical, candidate or R01--R10
credit is implied.

The current R4 package cannot pass that re-gate until P1-R4-01, P1-R4-02 and
P1-R4-03 are repaired, P2-R4-04 is converted into executable local evidence,
and a different role performs a new review of the exact refreshed bytes.
