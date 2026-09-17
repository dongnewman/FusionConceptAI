# R2 G2 independent review R2 — findings

## Verdict

`rework`. The返工后的 implementation attack matrix is clean, but the supplied
R2 rework receipt is not hash-admissible. This review issues no formal gate or
external/physical credit.

### G2-R2-001 — P1: supplied `run_receipt_r2_rework.json` has four incorrect empty-stream SHA-256 values

The true SHA-256 of a retained empty raw stream is
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
`05-g2-mapping/run_receipt_r2_rework.json` records
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4641b934ca495991b7852b855`
(the `...e4641b934...` variant) for the two focused-test stdout streams and
the two CLI stderr streams. Independent recomputation failed all four fields;
the files themselves are present and empty.

This is a local receipt-integrity defect, not an implementation attack failure,
but it makes the supplied rework evidence inadmissible under the review
protocol. Regenerate the receipt from the exact retained bytes and rerun the
receipt/hash audit. Do not patch the hash text without a fresh command/PID/UTC
receipt.

## No implementation findings in this review

The returned implementation rejects foreign candidate/source after local edge
updates when `expected_binding` is supplied; rejects missing, replaced,
axis-mutated, and self-referential expected bindings; recomputes and checks
source identity, declaration, signature payload, and receipt hashes; rejects
stale canonical reordering; returns production without verified authority as
`accepted=false, decision=fail_closed`; and keeps TEST_ONLY as `non_evidence`.
