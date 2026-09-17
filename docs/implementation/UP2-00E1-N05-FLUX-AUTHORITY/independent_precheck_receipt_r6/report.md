# E1 N05 receipt export independent static precheck R6

Verdict: `ready_for_focused_export_r3` (static readiness only; no Julia/DESC).

The repaired test defines `_n05e_named(::JSON3.Object)` recursively over object
properties and `_n05e_named(::JSON3.Array)` recursively to a `Tuple`, then uses
`JSON3.write`/`JSON3.read` for each forged envelope. This is compatible with
the JSON3 object/array values used by the test and preserves nested fields as
typed NamedTuples/Tuples for `merge`. The helper is test-only; it does not
change the exporter or checker.

The valid serialized path is first reread directly as a `JSON3.Object` and is
passed to the five-argument trusted checker. Every forged control is built
from that reread envelope, round-tripped through JSON3, then passed to the
same trusted checker: source-hash mutation, absent mutation-hash mutation,
foreign candidate ref, package hash, E0 binding hash, declaration hash, and a
missing authored row. The source-hash control reaches trusted source-bound
recomputation (the envelope-only checker cannot detect a source hash alone);
the other controls fail closed at the envelope or trusted identity checks.
The missing-row control reduces the reread authored tuple from five to four,
so the five-row gate rejects it. No control relies on a fixture label as
authority.

The exporter keeps the normal temporary-directory path when
`N05_RECEIPT_OUTPUT_DIR` is unset. When set, it creates only that caller-owned
directory and writes `n05_receipts.json`; the exporter refuses an existing
path, so the controlled path has no overwrite behavior. The runner includes
the production exporter/checker and the repaired test without changing the
production source.

Focused R2 is preserved as real exit 1 with its 22,402-byte envelope and raw
logs; the failure was the direct `merge` on a JSON3.Object. R1/R2 history and
the R4 production/exporter/checker inputs are protected. R6 is static only;
focused R3 remains required. This precheck grants no B04, provider, mesh,
engineering, physical, or R01-R10 credit.

## Frozen input hashes

- `src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl`: `3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df`
- `test/GenomeV5/UP2/n05_flux_authority_fixtures.json`: `049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81`
- `test/GenomeV5/UP2/n05_flux_authority_tests.jl`: `57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543`
- `test/GenomeV5/UP2/run_n05_flux_authority.jl`: `3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3`
- `test/GenomeV5/UP2/n05_flux_receipt_exporter.jl`: `615de2be1898bda9f8e388b9282cf54344a6411f5b7bb3a7709615f18af3ca5e`
- `test/GenomeV5/UP2/n05_flux_receipt_checker.jl`: `b4d62e9ddf806809889225d704929593357145e38ed840df7c705446bdb1f331`
- `test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl`: `373ba3d631cdf40a68d472b915e5814247e245f16ba765a3f23cdb231aff90da`
- `test/GenomeV5/UP2/run_n05_flux_receipt_export.jl`: `e6c122ce7a0ca410a243c1f2d790fd0d9f0b0dbabb00becdc7d092e7e3fcd9ec`

