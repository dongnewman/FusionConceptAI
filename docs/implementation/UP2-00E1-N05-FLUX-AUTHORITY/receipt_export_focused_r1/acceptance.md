# E1 receipt-export focused R1

Status: `failed_program_exception`; `accepted=false`.

The single authorized run used exactly:

`julia --startup-file=no --project=. test/GenomeV5/UP2/run_n05_flux_receipt_export.jl`

The Julia main PID was 56212, with observed child PIDs 78948, 76012, and
72424. It ran from `2026-09-14T04:53:52.780653Z` through
`2026-09-14T04:54:54.2931514Z` and exited with real exit code 1. Raw stdout is
3457 bytes, SHA-256
`b5bca42aa59fa2afb56d4528cf950c061123afe5e9dcbe7f06c7684fa6205014`; raw
stderr is 318 bytes, SHA-256
`ba5f502f88a5ab2aa7ab05695bf43dad35933fd774072a9110c75ab05c66706a`.
The post-run exact Julia/DESC process sweep was zero.

The run failed before receipt export. `_n05e_package` at the new test builder
constructed `G3FeedbackChannelV2` with a `G1GenomeContractRefV2`; the
constructor requires `GenomeContractRef`, producing
`ArgumentError: feedback target requires GenomeContractRef`. Consequently no
`n05_receipts.json` was created by this run; the bounded temp search found no
candidate, and the envelope retention status is an explicit gap. No receipt,
source-bound checker result, or focused acceptance may be inferred from the
partial G1/G2/G3 summaries.

The failure is preserved append-only. No rerun was performed. The frozen E1
source, fixture, focused test/runner, receipt exporter/checker, and R4 inputs
retain their pre-run SHA-256 values. The dirty snapshot changed only by six
concurrent N06 `repair_r6` archive files, recorded in `dirty_delta.json`; no
E1 frozen path changed.

This run grants no B00/B04, provider, mesh, engineering, physical, or R01-R10
credit. A narrow test-fixture builder repair and a new independent static gate
are required before any serial retry.
