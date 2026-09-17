# M4-D coupled-solve control repair R1 test execution

Status: `execution_complete_review_pending`. The source owner supplied D
repair SHA `EC7E82E282F1D1292DDD4B7902E4CED641D926AF82119298267011D304A55785`.
This Luna lane changed only the D test file (current SHA
`1EB0E26E79B9899CC5A3CB2742545CBAA811FA6683FDCFA1EE4DD31DFF081686`) and
added this `repair_r1` evidence directory; it did not modify D source, the
independent oracle, A/B/C, or shared files.

The Python Fraction oracle ran first (PID 31732, exit 0, UTC
09:32:17.9126555Z--09:32:18.9498896Z), confirming determinant `3`, solution
`(2/3, 1/3)`, zero residual, and all eight 2x2x2 identity cells. Combined raw
SHA256: `94B4F5A43A37C6FAB2BCAFEEC25BAB744BE2F359180849F299D59DFAEC318615`.

The authoritative Julia run followed serially (PID 106944, exit 0, UTC
09:34:18.2805500Z--09:34:43Z). It passed `158/158` with empty stderr
(combined raw SHA256
`C6B315172CDCE1B20744478EFD74FD4F47EC6C1FFFFBB3129E9B4944AD613484`). New
regressions cover foreign nested `right.source_owner`, foreign nested
`right.conservation_owner`, invalid nested right C, control and interface
grid-count mismatches, solution/interface pair swap/missing/duplicate, and
both non-identity cell-index directions. Every case returned its expected
typed failure with no exception.

The old 110/110, review-bypass probe, all old failures, and old 111/111
history remain in the parent execution directory and were not overwritten.
This repair remains limited to `manufactured_coupled_solve_control/screen_only`:
no UP2/B00/B04/R01-R10/L4 or parent credit, and no iterative/PDE/provider/
production execution.

Independent Luna review and Sol/root acceptance are still required.
