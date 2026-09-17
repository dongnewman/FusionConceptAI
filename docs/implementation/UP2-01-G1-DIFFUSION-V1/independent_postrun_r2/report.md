# UP2-01-G1-DIFFUSION-V1 independent postrun R2 erratum review

Verdict: `pass_limited`; recommendation: `accepted_limited` for the
candidate declaration and focused software-test slice only. Overall
`accepted=false`; `review_pending=true` remains required for the wider
lineage and execution gates.

This is a read-only fourth-party review of `postrun_erratum_r2`. It did not run
Julia or DESC and did not modify the original focused receipt, R1 postrun
review, erratum, source, tests, fixture, static QA or core documents. The
current worktree is at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2` with 300 status rows and no
matching Julia/DESC process at review time.

## Erratum verification

The raw focused files were read and hashed directly:

| raw file | bytes | directly calculated SHA-256 |
|---|---:|---|
| `focused_r1/stdout.txt` | 454 | `685826d01c1257313467060d3c7268b3ea5825aad17d630aeebe9593cad40152` |
| `focused_r1/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The original `focused_r1/report.json`, `evidence_manifest.json` and
`command_receipts.json` each contain the malformed 62-character empty-stderr
value
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`. The
original `focused_r1/report.md` does not contain that digest. The R1
`independent_postrun_r1/report.md` repeats the same 62-character value three
times while calling it a 64-character digest. Its structured JSON receipts
also preserve the short claimed value alongside the correct actual value, but
mark the receipt mismatch.

The R2 erratum supplies the correct 64-character SHA in its report and JSON
replacement fields, records the short length as `62`, the corrected length as
`64`, and sets `corrected_receipt_match=true`. Its JSON parses successfully.
The R2 report and manifest are additive evidence; the malformed old receipts
remain unchanged as required. This closes the only provenance defect raised by
the R1 postrun review.

The old R1 receipt hashes and bytes were independently rechecked:

| receipt | bytes | SHA-256 |
|---|---:|---|
| `independent_postrun_r1/command_receipts.json` | 2727 | `c874ef5731ccab306de699b067373e409c798301f8835c296b51d0fa19159b1a` |
| `independent_postrun_r1/report.json` | 4376 | `a3317770d988e683c68cfd72f2ea7e5ff87c65ebd19f369a331346d05f874dad` |
| `independent_postrun_r1/evidence_manifest.json` | 4694 | `bcb99befda39064db7891872d80a2696c3660adfaa2ae4700c3a38e3c1e3a16d` |
| `independent_postrun_r1/report.md` | 5008 | `cc0a2f89cb93b3263b35940a514e70b2c8c277f98100cdfdfceee44af570ead5` |

## Software-scope disposition

The immutable focused command was Julia PID `51988`, exit `0`, with raw
stdout reporting `32/32` positive, `34/34` fail-closed negative controls and
`5/5` source-edit identity checks, totaling `71/71`. The four target files
remain unchanged at the R6-precheck values:

| artifact | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 1582 | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 4499 | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |

The original focused pre-run dirty status hash remains explicitly unavailable
(`null`); this review does not invent or replace it. The original run recorded
3692 dirty entries before launch, 3697 after completion, and the known
post-run status SHA
`5a5377c953e753d7a84f540ecb0a10322a12d245f89c788ca5c9fc6356a4366d`.

Two focused-coverage limitations remain documented by the R1 postrun record:
the test does not directly assert every zero receipt counter, and it does not
directly assert each schema/canonicalization/profile receipt hash and required
gap tuple. These are visible software-contract coverage gaps; they do not
invalidate the observed 71/71 assertions or the corrected raw-output
provenance for this limited slice.

## Acceptance boundary

I recommend `accepted_limited` only for the candidate-owned declaration,
typed admission behavior and the executed software test receipt, with the two
coverage limitations retained in the ledger. This recommendation does not
accept the current actual-A candidate, provider, mesh, solver, engineering or
physical behavior. It grants no current-A, B00, B04 or R01-R10 credit. The
larger G1/G2/G3 join, source authority, compiler/provider execution and all
physical readiness remain outside this first slice.
