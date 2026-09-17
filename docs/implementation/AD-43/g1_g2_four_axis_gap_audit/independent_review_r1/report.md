# AD-43 G1/G2 four-axis gap audit — independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Verdict: `pass_limited`

## Review scope

This review independently rechecks the AD-43 read-only audit and its proposed
`AD43-AXIS-CONTRACT-RECORDS` work order. It reads the AD-43 report, manifest,
cleanup inventory and existing raw validation sidecars, the 17 frozen source
and contract inputs, AD-42 W0 products and boundary, AD-39 fresh-input
contract, AD-37 four-axis publication contract, and the relevant V1/V5 source
types. It writes only this review directory and its two review raw streams.

No reviewed product, source, test, fixture, task manifest, historical receipt,
or core planning file was modified. No Julia, DESC, provider, mesh, solver or
physical workload was run. No candidate or declaration hash was created.

## Findings

The three typed absences are real and reproducible from current repository
bytes:

- G1 `evidence_receipt_version` remains `typed_absent`. `G1DiffusionReceiptV1`
  contains declaration/schema/canonicalization/profile hashes, status and
  call counters, but no independent evidence-receipt version, source-record
  hash or attestation axis. `g1_diffusion_receipt_v1` only projects the
  existing V1 declaration into that receipt.
- G2 `applicability_profile_version` remains `typed_absent` for the V1
  metric-boundary domain. `G2MBProfileV1` has profile id, dimension, topology,
  basis and claim ceiling plus its profile hash/token helpers, but no typed
  applicability-profile version record. It must not be filled from the V5
  `SpatialGrammarProfileV2` domain.
- G2 `evidence_receipt_version` remains `typed_absent`. `G2MBReceiptV1` has
  declaration/source/schema/canonicalization/profile hashes, admission state,
  gaps/errors and call counters, but no independent evidence-receipt version,
  source-record hash or attestation axis. `g2mb_receipt_v1` preserves that
  boundary.

The V1 source files contain no candidate-bound four-axis record or attestation
field for these gaps. The V5 negative controls do contain their own four-axis
fields and candidate hashes, so using them as V1 records would be a cross-domain
alias and must fail closed. `GenomeContractRef` and `QualifiedRefV1` also remain
distinct types with their declared field domains.

AD-42 W0 still reports exactly these three typed absences, with software
contract materialization as its claim ceiling and no candidate/declaration hash
credit. The four future AD-42 W2R1 products are absent. Therefore W2R1 still
requires fresh candidate/source/identity inputs and fresh rebinding; it cannot
inherit present status from W0, historical AD-40 payloads, fixture data or the
proposed source-only records.

## Work-order contract review

`AD43-AXIS-CONTRACT-RECORDS` is closed at the proposal level:

- exactly four future product paths are named and none exists;
- the result union is exactly
  `PresentAxisContractRecordV1 | AbsentAxisContractRecordV1 |
  FailedAxisContractRecordV1`;
- each layer-specific source type remains explicit: G1 maps
  `G1DiffusionReceiptV1`, G2 applicability maps `G2MBProfileV1`, and G2
  evidence maps `G2MBReceiptV1`;
- the edge is one-way from axis records to W2R1, while reverse derivation from
  payload/declaration/candidate hashes is forbidden;
- the contract requires exact source bytes, hashes, canonicalization and
  independent axis ref/version derivation, while retaining fresh W2R1 binding
  fields as a downstream obligation;
- the claim ceiling is `software_contract_record_only`, with task-owned
  archive/review sidecars and path-owned cleanup.

The current AD-43 audit remains read-only and is not a mainline task node. The
proposed four products must be authored and independently reviewed before W2R1
can consume them. Even a present source-only record would not be a source-backed
declaration, T0 authority, provider/mesh/solver evidence, physical evidence or
R01–R10 completion.

## Validation evidence

The independent Python 3.13.5 verifier was run from the repository root with
PID `15060` at `2026-09-15T09:47:56.576491Z` and exited `0`. It performed 55
checks covering JSON parsing, all 17 frozen-input existence and SHA-256 pairs,
V1/V5 API and negative-control scans, all three W0 typed-absence states, exact
future product absence, proposed work-order result/dependency/forbidden-edge
closure, mainline task-manifest nonmutation, control-character checks and
`git diff --check`. Raw streams are preserved under `review/`:

- `validation_stdout.json`: 3,049 bytes,
  SHA-256 `3437e0da09a4ba381b273fd86c5f109a2cc0366ad80b67aee57fcf3384f51087`;
- `validation_stderr.txt`: 0 bytes,
  SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

All 55 checks passed. This is a limited independent software-contract review;
it does not grant present, T0/T1/T2, UP2, provider, mesh, solver, engineering,
physical, search, B00/B04 or R01–R10 credit.

After writing the review products, a final closure verifier independently
parsed this review manifest and report, checked the four raw sidecars, verified
the recorded 55/55 result and reran `git diff --check`. It used Python 3.13.5,
PID `69036`, UTC `2026-09-15T09:52:15.813306Z`, exited `0`, and recorded 16/16
checks in `review/final_closure_stdout.json` (498 bytes, SHA-256
`afdefd47a0edd2f91ceabf40007f045ee7c1bc29c6902d5ee30eb50fdf33e728`). Its
stderr is zero bytes with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
An append-only second closure after the final manifest update used Python
3.13.5, PID `81508`, UTC `2026-09-15T09:53:42.824004Z`, exited `0`, and passed
15/15 checks. Its stdout is 518 bytes with SHA-256
`7de938c777dac5464ed8427236174a7879a3df8a4cf2150cd6d733d3fb31030f`; its
zero-byte stderr has the same empty-stream SHA above.

## Cleanup and boundary

The review-owned set is exactly `report.md`, `manifest.json`,
`review/validation_stdout.json`, `review/validation_stderr.txt`,
`review/final_closure_stdout.json`, `review/final_closure_stderr.txt`,
`review/final_closure_r2_stdout.json`, and
`review/final_closure_r2_stderr.txt`. No
temporary or unrelated code file was found or removed. Existing AD-43 raw
receipts, all historical records, all unrelated dirty work and the future
`AXIS-CONTRACT-RECORDS/` product directory were preserved. The verdict is
`pass_limited` for the read-only audit and its proposed finite contract only;
AD-43 itself remains `review_pending` until the root acceptance decision.
