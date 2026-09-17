# N05 receipt-export independent static precheck R3

Verdict: `ready_for_focused_export_r1` (static readiness only; acceptance remains pending).

The R3 test-only repair closes the R1 file-evidence gap. After writing the
append-only envelope, it performs `JSON3.read(read(path, String))` and passes
that re-read object to the production five-argument
`n05_check_receipt_envelope(envelope, package, e0, authored, absent, specs)`
overload at `test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl:107-109`.
The one-argument `n05_check_receipt_file(path)` remains a serialization
checksum only; it is not treated as source-bound evidence.

The re-read object is used for every R3 negative control. Candidate identity,
package hash, E0 binding hash, authored declaration hash, authored source hash,
and absent mutation hash are forged on `file_envelope` and sent through the
trusted overload (`n05_flux_receipt_export_tests.jl:113-138`). An authored row
is removed from that same re-read object and rejected by the trusted path.
The trusted checker first enforces envelope/row self-consistency and then
rebuilds ten expected rows from actual CandidateStatePackageV5, E0, authored
and absent authorities, and typed field-path/mutation-kind specs. Its full-row
comparison covers candidate/package/E0/declaration/source locator/type/hash,
typed original/attempted values and hashes, mutation canonical/hash,
classification/path/resolution, and compile/provider/solver counters.

The current test does not run through the file-checker-only path for any
source-bound claim, and the archive does not call that path source-bound.
This satisfies the R1 boundary requirement. JSON3.NamedTuple versus
JSON3.Object behavior is exercised by the re-read trusted overload during the
future focused run; no Julia execution was authorized in this review, so that
runtime result remains pending.

The author R3 manifest freezes only the changed test at
`f6905da1ce4c28d8f1d329d08338f7efc59873c50c32d04733646f8716113a64`.
Exporter, checker, receipt runner, E1 projection source, E1 fixture/test/
runner retain their R1/R4 hashes. The R1 independent precheck directory,
receipt-export R1/pre-repair history, and R3 repair archive are present and
untouched. No Julia/DESC process was started by this review.

This result authorizes one serial focused export run to verify the runtime
JSON3 cross-type comparison, real process exit, stdout/stderr, and zero
post-process sweep. It does not accept the implementation and does not grant
B00, B04, provider, mesh, engineering, physical, or R01-R10 credit.

## Frozen hashes

- R3 test: `f6905da1ce4c28d8f1d329d08338f7efc59873c50c32d04733646f8716113a64`
- exporter: `615de2be1898bda9f8e388b9282cf54344a6411f5b7bb3a7709615f18af3ca5e`
- checker: `b4d62e9ddf806809889225d704929593357145e38ed840df7c705446bdb1f331`
- receipt runner: `e6c122ce7a0ca410a243c1f2d790fd0d9f0b0dbabb00becdc7d092e7e3fcd9ec`
- E1 projection source: `3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df`
- E1 fixture: `049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81`
- E1 authority test: `57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543`
- E1 authority runner: `3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3`

All claims remain contract-only and review-pending until the separately
serialized focused run and another acceptance decision.
