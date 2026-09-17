# Receipt export R5 controlled-retention repair

R1's real exit-1 program exception and no-envelope gap remain immutable. R4's
narrow builder repair remains in place: the G3 feedback target uses the
materialized `g1.contract_ref` outer public ref. This R5 test-only repair adds
an optional `N05_RECEIPT_OUTPUT_DIR` environment variable. With no variable,
the test preserves its original `mktempdir()` behavior. Under a controlled
focused run, it creates the supplied new directory, writes exactly
`n05_receipts.json`, prints the path and SHA-256, and still relies on the
exporter's no-overwrite guard. The trusted checker re-reads that file through
JSON3 as before.

No exporter/checker, production N05 source, frozen R4 inputs, or old archives
were edited. No Julia/DESC run occurred. A different-Luna static precheck and
fresh serial run are required.
