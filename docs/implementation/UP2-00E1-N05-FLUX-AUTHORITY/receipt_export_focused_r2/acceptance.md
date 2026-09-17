# E1 N05 receipt-export focused R2

Status: `failed_program_exception`; `accepted=false`.

The single authorized command was:

`julia --startup-file=no --project=. test/GenomeV5/UP2/run_n05_flux_receipt_export.jl`

The controlled `N05_RECEIPT_OUTPUT_DIR` was this new archive directory. The
runner started main PID 71952 and observed child PIDs 63148, 11108, and 61796
from `2026-09-14T05:07:13.9267921Z` to
`2026-09-14T05:08:29.7723154Z`; real process exit was 1. Raw stdout is 2941
bytes, SHA-256
`fd9870f918c39d3f166f64dfcc7eb7b57f4d0253add8a1dbf48a077c1dcd948c`; stderr
is 318 bytes, SHA-256
`63a85571050f61ea4987a19e7ce5384e7205d51ceb4eae6bf1e325c6d3907954`.
Post-run exact Julia/DESC process count was zero.

The exporter successfully wrote `n05_receipts.json` before the later test
error. The file is one-line JSON, 22402 bytes, SHA-256
`777d120fc9bdfb10933e296b28b8d04cac97009d9998ae2073bcc2d075c35fea`, and its
hash matches the path/SHA printed by the test. JSON parsing succeeds. The
focused test then errored while constructing the source-hash forgery control:
Julia 1.10 cannot `merge(::JSON3.Object, ::NamedTuple)` at test line 122.
The test summary was `9 pass, 1 error`; this is a test-harness program exception,
not a physical or provider result. The run is preserved as failed and was not
retried.

The frozen E1/R4 source, fixture, authority test/runner, receipt
exporter/checker, and R5 test/runner hashes are recorded in
`input_hashes.json`. Dirty status changed during the run only by five
concurrent N06 `repair_r7` archive files; the delta is recorded and no E1
frozen path drifted.

This run grants no B00/B04, provider, mesh, engineering, physical, or R01-R10
credit. A narrow JSON3-object mutation repair and a fresh independent static
gate are required before another serial focused run.
