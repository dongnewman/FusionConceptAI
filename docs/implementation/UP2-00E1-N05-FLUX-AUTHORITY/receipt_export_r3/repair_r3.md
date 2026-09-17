# Receipt export R3 static repair

The R2 preparation is preserved under the immutable `receipt_export_r1/`
archive. This R3-only test change closes the independent precheck boundary:
the focused test now re-reads the emitted receipt file with `JSON3.read` and
passes that file-derived envelope to the trusted overload
`n05_check_receipt_envelope(envelope, package, e0, authored, absent, specs)`.
The trusted overload rebuilds all ten rows from actual A, E0, and typed
N05 authorities before comparing candidate/package/E0/source/declaration,
locator, typed-value, mutation, classification, and counter fields.

The same trusted file-derived path now has five separate malformed-envelope
controls: forged candidate ref, package hash, E0 binding hash, authored
declaration hash, and an omitted authored row. Existing source-locator and
absent mutation-hash forgeries remain. These controls are expected to throw
`ArgumentError`; no fixture expected class or row ID is used for classification.
The exporter, checker, frozen E1 R4 source/test/fixture/runner, and all prior
R1/R2 archives remain byte-preserved.

No Julia or DESC was run. Status remains `review_pending`; `accepted=false`.
The result is ready for a different-Luna static precheck, then a separately
authorized serial focused export run. It carries only schema/contract evidence;
there is no B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.
