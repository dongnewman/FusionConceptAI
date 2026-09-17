# N05 receipt-export independent static precheck R5

Verdict: `ready_for_focused_export_r2` (static readiness only; no acceptance).

The R5 test-only repair closes the R1 exit-1 builder failure without changing
the exporter, checker, receipt runner, or E1 source inputs. In
`test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl:30`, the G1 genome's
public contract is materialized by `G.g1_materialize_contract_ref(...)`. The
G3 feedback builder at lines 52-54 uses `g1.contract_ref` for G1-targeted
feedback and `g2_ref` for G2-targeted feedback. This removes the prior
`G3FeedbackChannelV2` rejection of the internal G1 ref while preserving exact
layer-targeted source refs.

The test supports `N05_RECEIPT_OUTPUT_DIR` at lines 101-107. With the
variable absent it keeps the original `mktempdir()` behavior. With it set,
it creates only the supplied new directory and writes the fixed
`n05_receipts.json` path. The exporter no-overwrite guard remains active, and
the test retains the existing-path rejection at lines 149-150. It prints the
actual path and SHA-256 at lines 110-111 for a controlled focused receipt.

The emitted file is re-read with `JSON3.read(read(path, String))` at line 116
and that object is passed to the five-argument trusted overload at lines
117-118. The forged candidate/package/E0/declaration/source/mutation controls
and missing authored-row control use that same re-read object at lines
122-147; they do not rely on the one-argument envelope checksum. The trusted
overload rebuilds ten rows from actual CandidateStatePackageV5, E0, authored
and absent authorities, and typed specs. Existing five authored
fail-closed/five absent terminal-deferred rows and zero downstream counters
remain bounded contract checks.

The R1 raw exit-1/no-envelope evidence and its literal-backtick-n exit-file
correction remain preserved. R4 source, fixture, authority test/runner,
exporter/checker/receipt runner and R4 archive inputs remain hash-stable. The
R4 receipt-export test hash is preserved in `receipt_export_r4_static`; only
R5's new test hash is reviewed here. No Julia/DESC was run because N06 owns
the serial lane.

This review authorizes one serial focused export R2 run to verify the
materialized ref at runtime, controlled output retention, JSON3 cross-type
comparison, actual receipt SHA, process exit, stdout/stderr, and post-process
sweep. It does not accept the implementation or grant B04, provider, mesh,
engineering, physical, or R01-R10 credit.

## Frozen hashes

- R5 test: `3afd6f3b3f0a6380acdc172776a0391119c094907d34fe79ea199a3b9eaedc96`
- R4 receipt-export test (protected historical input): `11e06b2b13b0379c41fb974256cbaea420a7a3723f09aee40ec5f50b7d796118`
- E1 source: `3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df`
- E1 fixture: `049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81`
- E1 authority test: `57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543`
- E1 authority runner: `3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3`
- exporter: `615de2be1898bda9f8e388b9282cf54344a6411f5b7bb3a7709615f18af3ca5e`
- checker: `b4d62e9ddf806809889225d704929593357145e38ed840df7c705446bdb1f331`
- receipt runner: `e6c122ce7a0ca410a243c1f2d790fd0d9f0b0dbabb00becdc7d092e7e3fcd9ec`

Only this independent-precheck directory is writable in this review.
