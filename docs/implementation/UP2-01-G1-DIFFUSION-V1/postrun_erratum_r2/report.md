# UP2-01-G1-DIFFUSION-V1 focused postrun R2 receipt erratum

Status: `changes_requested`; `review_pending=true`; `accepted=false`.
This is an additive receipt correction. Julia and DESC were not run while
preparing this erratum, and no old evidence, source, test, fixture, static QA
or core file was modified.

## Provenance defect

The independent postrun R1 audit identified a malformed empty-stderr digest in
the focused receipts. The raw file is zero bytes, so its directly calculated
SHA-256 is the standard 64-character value:

`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

The three structured R1 receipts each stored a 62-character value missing the
`9b` segment after `...9b934ca...`:

`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`

The R1 `report.md` repeated the same short value three times while describing
it as the 64-character actual digest. That prose is also incorrect. The raw
file and direct calculation are authoritative; this R2 receipt gives the
minimal correct replacement fields without rewriting the old report.

## Directly calculated raw outputs

| path | bytes | direct SHA-256 |
|---|---:|---|
| `focused_r1/stdout.txt` | 454 | `685826d01c1257313467060d3c7268b3ea5825aad17d630aeebe9593cad40152` |
| `focused_r1/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The R1 stdout digest matches its receipts. The stderr digest is the only
receipt mismatch.

## Old receipt hashes and bytes

The old independent postrun R1 receipt files were read without modification:

| path | bytes | SHA-256 |
|---|---:|---|
| `independent_postrun_r1/command_receipts.json` | 2727 | `c874ef5731ccab306de699b067373e409c798301f8835c296b51d0fa19159b1a` |
| `independent_postrun_r1/report.json` | 4376 | `a3317770d988e683c68cfd72f2ea7e5ff87c65ebd19f369a331346d05f874dad` |
| `independent_postrun_r1/evidence_manifest.json` | 4694 | `bcb99befda39064db7891872d80a2696c3660adfaa2ae4700c3a38e3c1e3a16d` |
| `independent_postrun_r1/report.md` | 5008 | `cc0a2f89cb93b3263b35940a514e70b2c8c277f98100cdfdfceee44af570ead5` |

For completeness, the focused raw/archive files remain at these independently
calculated values:

| path | bytes | SHA-256 |
|---|---:|---|
| `focused_r1/command_receipts.json` | 2690 | `cfd6505c0638d0d13f1649aecb46c499e4485c0ae2a1828c31ad38a5d62ab3f9` |
| `focused_r1/evidence_manifest.json` | 1981 | `47bcb506fa09decfe3373a13c41d918d91f95edca0ae21d80a60bbee3cf14a9d` |
| `focused_r1/report.json` | 2018 | `6feb284ec10044b1542c5086177c8e83cf627b73080a52f8093074f348c5fd31` |
| `focused_r1/report.md` | 1477 | `9f5e50824b03bcf8459d9597d9ff00b62a534b6462cd09f7d0f40d3bd097739b` |

These focused archive hashes are supplementary provenance; the required
receipt correction concerns the independent postrun R1 files above.

## Minimal replacement fields

Apply these values to a future re-sealed copy only; the immutable R1 files stay
unchanged:

```json
{
  "raw_outputs": {
    "stderr": {
      "actual": {
        "bytes": 0,
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      },
      "claimed": {
        "bytes": 0,
        "path": "stderr.txt",
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      },
      "claimed_sha256_length": 64,
      "receipt_match": true
    }
  }
}
```

## Immutable execution facts

The original authorized command was:

```text
julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl
```

PID was `51988`, runtime was `julia_1.10.5`, and exit code was `0`. Raw
stdout and the R1 summary reported `32/32` positive declaration and typed
receipt, `34/34` fail-closed negative controls, and `5/5` source-edit identity,
for `71/71` total. Pre-run dirty entry count was `3692`; its status hash was
explicitly `null` and remains unavailable, so no value is inferred. The R1
post-run record was 3697 entries with status SHA-256
`5a5377c953e753d7a84f540ecb0a10322a12d245f89c788ca5c9fc6356a4366d`, followed
by 3704 entries after receipt files were written.

The current erratum write had a separate pre-write dirty snapshot of 3734
entries with UTF-8/LF status SHA-256
`773911cae58a66688e58a181167e09d8e6a9776906dae1aa09f1b2cdb86e1855`;
post-write values are recorded in the manifest. This distinction does not
replace the original run's null pre-run hash.

## Claim boundary

This correction seals raw-output provenance only. It grants no compiler,
provider, mesh, solver, physical, engineering, current-A, B00, B04 or R01-R10
credit. A different Luna R2 review must verify the raw files, old receipt
hashes, replacement fields, and the preserved command/PID/exit before any
further disposition.
