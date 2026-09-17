# N05 receipt-export independent static precheck R1

Verdict: `ready_for_focused_r1` with a required serialized-source-bound gate.

The frozen R2 implementation is structurally ready for one serial focused run. The production mutation path is source-derived: authored rows are rebuilt from the actual declaration and absent rows use the production `(id, original, mutated)` canonical payload. The trusted checker rebuilds both five-row sets from the actual `CandidateStatePackageV5`, E0 binding, authored/absent N05 authorities, and typed `(field_path, mutation_kind)` specs. It compares candidate/package/E0/declaration identities, source locator/type/hash, typed values and hashes, mutation canonical/hash, error path/classification/resolution, and all downstream counters. It does not route by fixture id or use fixture expected-error labels.

The receipt boundary is narrower than a source-bound file checker. `n05_check_receipt_file(path)` at `test/GenomeV5/UP2/n05_flux_receipt_checker.jl:123-125` parses JSON and calls the one-argument envelope checker only; it returns `:valid` for envelope self-consistency. The five-argument overload at lines 98-120 is the actual source-bound check. The author archive states this boundary correctly (`receipt_export_r1/acceptance.md` and `evidence_manifest.json`), so no false source-bound claim was found. A serialized file must not be used as a future B04 receipt by the file checker alone. Before such use, a focused test must parse the file and pass the resulting JSON3 object through the trusted overload, with file-level candidate/E0/ref/hash and row-shape mutations.

`_n05c_same_row` uses `JSON3.write(getproperty(actual, field)) == JSON3.write(getproperty(expected, field))` at `n05_flux_receipt_checker.jl:84-95`. This is a structural JSON comparison and is plausibly stable for the exporter’s ordered NamedTuples versus JSON3 objects, but no current runtime receipt proves the cross-type behavior. The focused run must exercise the trusted overload on the JSON re-read object and retain its stdout/stderr/exit and input hashes.

The current focused test has two useful trusted negative controls: authored source-hash forgery and absent mutation-hash forgery (`n05_flux_receipt_export_tests.jl:110-123`), plus output-path collision. Static review confirms that candidate/E0/package/ref/axes/declaration/source/path/type/value mismatches are rejected by the full-row comparison, and missing/extra rows are rejected by the typed key-set comparisons at `n05_flux_receipt_checker.jl:107-118`. Those controls are not all independently instantiated in the current test. Add them before treating a serialized envelope as a formal downstream receipt; this is a test-evidence gate, not a license to promote B04.

The five authored fixture rows and five absent-authority rows are present, and the envelope ceiling keeps B00, B04, provider, mesh, and physical claims false. No Julia/DESC was run in this review. The result therefore remains contract-only and review-pending for implementation acceptance.

## Required focused gates

1. Run the trusted overload with the JSON3 object re-read from the emitted file; assert `:source_bound_valid` and zero compile/provider/solver calls.
2. Mutate serialized candidate ref, package hash, E0 binding/bound-input hash, source ref/hash/path/type, declaration hash, and delete/duplicate a row; each must fail closed through the trusted overload.
3. Preserve the standalone file checker as a serialization checksum only. Do not call it source-bound evidence.
4. Preserve the exact input and output hashes, real process exit, stderr, and post-process sweep. No B04, provider, mesh, engineering, physical, or R01-R10 credit is available from this slice.

## Frozen inputs

- E1 projection source: `3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df`
- E1 fixture: `049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81`
- E1 test: `57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543`
- E1 runner: `3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3`
- receipt exporter: `615de2be1898bda9f8e388b9282cf54344a6411f5b7bb3a7709615f18af3ca5e`
- receipt checker: `b4d62e9ddf806809889225d704929593357145e38ed840df7c705446bdb1f331`
- receipt test: `0e348f3cd475fd76e1dbf2527b3e14b625dad204ff70762af992d6e382f1852c`
- receipt runner: `e6c122ce7a0ca410a243c1f2d790fd0d9f0b0dbabb00becdc7d092e7e3fcd9ec`

The source/test/archive files are dirty and protected. This review writes only this independent-precheck directory.

