# UP2-01-G1-DIFFUSION-V1 independent agent-local R2 review

Verdict: `fail`; `accepted=false`; `review_pending=true`.

Independent review of `agent_local_r2` at HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`.  Julia was not run, per the
request; Python static QA was independently rerun and passed.  No source,
test, fixture, task manifest, public entry point or `runs/` file was modified
by this review.  Only the two files in this review directory were written.

## Receipt and input recheck

The four current target files exactly match the R2 evidence manifest:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 37919 | `8bf9e1b428c98d144aa46ad7d09403680a7d4b44f7bd687dd4a6f68611f1a756` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 12037 | `51ce669cd1c9d6c4d2dd6e3f48f742755c23501ce65801695df4c3247f82cd8b` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 2011 | `47eab33a4d360bc8577aa55be5694840982561e29bd4dfbe1f42efcf85afba19` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 5284 | `4677ac7f9ba353594e7ca14bd1a2ccc2135ace1435e1685a3731fee098072790` |

The non-empty raw hashes also match: static-QA stdout is 285 bytes,
`2ef998093ca5a8d5217e32d3c259d31c115b93e5b1cc55127500d4b5c0494931`; focused
stdout is 454 bytes,
`ddce1ee8d42db5871173d20fef7e760b3d1406d638a39b5eb0bb1a2cc30d5d29`.
The focused stdout arithmetic is `41/41 + 42/42 + 5/5 = 88/88`; both stderr
files are truly zero bytes.

The R2 command outputs are therefore real and the focused run's reported
assertions are credible.  However, every R2 evidence record that records the
empty stderr digest (`report.md`, `report.json`, `evidence_manifest.json`, and
`cleanup_inventory.json`) repeats a 62-character value:

`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`

The actual SHA-256 of an empty byte string is the 64-character value:

`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

The short value is not a harmless display truncation: it is stored as the
claimed digest in the structured manifests and path ledger, so the R2 sealed
receipt does not hash-verify.  This is the same class of provenance defect
that the previous G1 focused receipt had to correct.  Preserve all old R2
files and issue an additive corrected receipt/erratum before acceptance or
independent replay.

## Contract repair verification

The source changes do address all five substantive R1 findings:

- `G1DiffusionSourcePayloadV1` now stores `candidate_ref`, requires a v5
  candidate, and the declaration constructor checks exact candidate/source
  equality (source lines 259-288 and 323-347).  The legacy unbound
  five-argument constructor is explicitly rejected.  Source edits preserve
  the candidate and rehash the payload.
- GRAD, K_APPLY and DIV pin exact operator IDs and v1; their constructors
  require the expected static value kinds, rank, dimension and temporal type
  (lines 186-257).  Declaration construction checks full PhysicalType
  equality across u → GRAD → K_APPLY → DIV → f (lines 359-372).
- Closure and applicability refs are pinned to the V1 IDs/version, closure
  and applicability hashes are included in the profile hash, and those
  profile-bound hashes are included in the declaration canonical body (lines
  9-64 and 373-378, 410-419).  The new negative tests cover foreign refs.
- The receipt test now directly asserts schema/canonical/profile hashes,
  required gaps, all four zero downstream counters and receipt-hash equality
  (test lines 68-77).  The implementation still has no compiler/provider/
  mesh/solver call path; receipt construction sets those counters to zero
  and `physical_evidence=false` (source lines 530-562).
- The AD-35 cleanup inventory now has an owner, `final_exact_owned_set`, a
  per-path before/after ledger and cleanup/process protection fields.  All
  non-self path hashes independently match the ledger except the malformed
  empty-file digest described above.

The static QA rerun independently returned `static_qa=pass` with the four
current input hashes and `julia_or_desc_executed=false`.  No Julia process was
present at review; the two named phase-5 PIDs (8636 and 36512) were observed
and not touched.  At review the worktree had 1483 status rows with UTF-8/LF
SHA-256 `e7360d708c3734c30fc960b5035660c587d6db6f1b09104ab66ceebe740076bf`,
and the four target files were the only target-path modifications.

## Disposition and replay gate

Source/test/fixture semantics are `pass_limited` on static inspection, and
the 88/88 raw output is credible.  The overall verdict remains `fail` solely
because the R2 evidence manifests are internally hash-inconsistent.  This
R2 package is **not yet eligible for the requested agent_local independent
replay/wrapper R3**.  First add a corrected, append-only receipt with the
64-character empty stderr SHA; then a fresh independent reviewer can verify
the corrected artifact and decide whether to release the wrapper lane.

Credit ceiling: `software_test_only` after correction, still
`accepted=false`; no compiler, provider, mesh, solver, numerical, physical,
engineering, current-A, B00, B04, UP2 execution or R01-R10 credit.
