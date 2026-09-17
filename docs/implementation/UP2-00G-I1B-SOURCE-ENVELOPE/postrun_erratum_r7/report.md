# GI1B focused R5 postrun hash erratum R7

Verdict: `review_pending`; `accepted=false`.

R7 is an additive clean-text correction for the R6 evidence record. R6 JSON
and all older files remain immutable. No Julia or DESC command was run while
producing this record.

## Direct raw receipt values

The values below were read from the preserved raw bytes and calculated with
SHA-256:

| file | bytes | SHA-256 |
|---|---:|---|
| `focused_r5/stdout.txt` | 2806 | `22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121` |
| `focused_r5/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The three focused-R5 structured receipts (`output_hashes.json`,
`command_receipts.json`, and `report.json`) already contain the same correct
64-character stderr SHA. The independent postrun-R5 `report.json` and
`evidence_manifest.json` retain the historical 62-character value
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`; those old
fields are preserved as the discrepancy that R6 addressed.

R6's structured replacement field records the correct value
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` and `0` bytes.
R6's original report and JSON are not overwritten by R7.

## Frozen focused facts and scope

Focused R5 remains PID `14796`, exit `0`, with `2653/2653` assertions. The
four protected input hashes and byte counts remain unchanged. Focused R4's
historical exit `1`, `2051/2052` result, and raw evidence remain preserved;
that failure is not replaced by R5.

The owner acceptance remains `review_pending=true`, `accepted=false`. The
bounded claim is actual-A source-envelope software behavior only. It grants
no N06 actual authority, UP2 total, B00/B04, provider, mesh, solver,
physical, engineering, current-A, or R01-R10 credit. The local fixture stays
oracle-only and no mesh declaration is promoted to mesh execution.

R7 generated this UTF-8 report from raw bytes and structured JSON. It contains
no control characters, shell placeholders, or unexpanded length expressions.
