# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC local software precursor acceptance

Date: 2026-09-15  
Decision: `accepted_limited` for the additive realization-only local software
slice.  The machine work-order node remains `planned` / `proposal` /
`accepted=false` / `review_pending`.

## Accepted scope

The accepted slice is limited to the new
`G3RealizationChildEditabilityV1.jl` source and its focused test. It covers the
closed typed realization body, candidate/parent/child identity, source-record
and source-content identity, five-hash layering, fixed
`replace_source_payload`, typed absence, zero/one/multiple absence-reason
classification, stale/foreign/forged/duplicate rejection, and the independent
`contract_admission` / `physical_resolution` status axes.

The frozen-r4 focused receipt is the sole execution basis for this local
acceptance. It recorded PID `15468`, UTC
`2026-09-15T02:20:48.9783709Z` to
`2026-09-15T02:20:59.4391247Z`, exit code `0`, and `65/65` passing assertions
with no failures or errors. The raw streams are preserved in
`focused_r4/`: stdout is 130 bytes with SHA256
`3cb363b0e53ff26ca9a632a9838c394d95a97e65a6cad453c750a0dcc6803d3f`, and
stderr is 0 bytes with SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The 13 frozen input hashes and the before/after dirty and process snapshots are
recorded by [focused_r4/run_manifest.json](focused_r4/run_manifest.json). The
source and test hashes used by the run were respectively
`01bdfd40f1a824b8530fc51f6ff319e40dda4edbce275c62276e5431f78f25bf` and
`ee2d3fcf80844b5ba26c983eed9810b6f7ac33ddce3403f052a3b0791143127b`.

## Boundary and status

This acceptance is frozen-r4 only. The focused_r1, focused_r2, and focused_r3
failures remain preserved historical receipts. The independent postrun found
that concurrent changes to planning files after focused_r4 drifted from the
frozen input manifest; that drift is recorded and is not back-attributed to the
R6 source/test slice. Reuse of the focused receipt requires its frozen input
manifest.

The local source/test slice is `accepted_limited`, while the work-order machine
node remains `accepted=false`. No actual child authority or T1 lossless mapping
exists. `T0`, `T1`, `T2`, provider, mesh, engineering, physical, search, B00,
B04, and R01–R10 remain false. `physical_resolution` remains `unknown`.
Control, binding, feedback, old G3 V1/V5, T0, package/registry, and historical
receipt paths remain read-only and outside this acceptance.

Independent postrun: [different-Luna R4 review](independent_postrun_r4/report.md).
Status synchronization: [status_sync_r1 report](status_sync_r1/report.md).
