# UP2-01-G1-DIFFUSION-V1 independent static precheck R4

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

This read-only different-Luna review covers the AD-28 G1 work order, independent R1/R2/R3 findings, the R4 repair and erratum, and the current G1 source, tests, fixture and static QA. Julia and DESC were not run. The permitted Python static QA was run once and exited `0` with `static_qa=pass` and `julia_or_desc_executed=false`.

The R4 semantic repair is statically present. `G1DiffusionSourcePayloadV1` is defined before its typed users. The declaration binds candidate-owned typed `u`, diagonal-affine spatial `K(x)`, and `f`; source hashing recomputes from that payload; and edits to `u`, `K`, or `f` rebuild source/declaration identity. The affine profile is non-constant, bounded on a non-degenerate 3-D box, and requires positive diagonal lower enclosure. The fixture/test values give exact lower `2`, exact upper `121/30`, and midpoint first diagonal `41/20`. The typed chain is `GRAD → K_APPLY → DIV`, with source field binding and `residual_sign=-1`; unit closure is enforced for the gradient, coefficient application and divergence. These are contract-level facts only.

The admission taxonomy is also statically correct on the inspected paths. The public `g1_diffusion_admit_v1(declaration::Any)` fixes the production `g1_diffusion_validate` function and has no checker injection parameter. `_g1d_admit_v1_fault_probe` is internal and reaches the shared `_g1d_admit_v1_impl` catch path; the test checks `:program_exception`, `:unexpected_exception`, `/declaration`, no declaration, and a non-null exception type. Missing external authority remains typed `:terminal_deferred`/`:missing_external_authority`. Source hash mismatch, K bound/domain contradictions, sign and unit mismatches, and malformed `probe_point` are typed `:fail_closed`; malformed probes specifically use `:K_probe_point_malformed` at `/K/probe_point`. Source-hash canonicalization exceptions have a separate program-exception catch. No exception-message substring is used for classification, and the public validator remains fixed to production logic. Direct constructors retain ordinary `ArgumentError` guards for malformed construction; the public admission controls reviewed here return typed outcomes.

The R3 state error was corrected additively in the R4 report/manifest: R3's historical `repair_r3` files remain unchanged, while R4 records `review_pending=true` and `accepted=false`. That correction itself is valid.

There is one blocking evidence error. The R4 report's hash ledger is consistent with the current bytes, but `repair_r4/evidence_manifest.json` has the fixture and static-QA before/after hashes crossed and includes a stale hash:

| file | R4 report / current bytes | R4 manifest `r3_before` | R4 manifest `r4_after` | required correction |
|---|---|---|---|---|
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | before `1dba9659…`; current/after `7b580bf9…` | `7b580bf9…` | `1dba9659…` | before `1dba9659…`; after `7b580bf9…` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | before `eb9f9587…`; current/after `87f511f5…` | `87f511f5…` | `b8fe5945…` | before `eb9f9587…`; after `87f511f5…` |

The source and Julia test entries in the R4 manifest are correct. The narrow repair is an additive R4 hash-correction erratum (or a new repair-r5 receipt) that preserves the R3 archive and states the four correct R4 input hashes. Until that receipt is independently rechecked, the R4 package is not ready for the serial focused lane. No source or test change is requested by this review.

The result remains preparation-only. There is no compiler, provider, mesh, solver, physical, engineering, current-A, B00, B04, or R01-R10 credit.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Current pre-write full dirty snapshot: 3,656 entries; status SHA-256 `762a759f6911eb3434bf68b0f3322eba011b1070a6a67cdd16d46c96b43049f0`; no matching Julia/DESC process observed.
- Current source/test/fixture/static-QA hashes: `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`, `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6`, `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641`, `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066`.
- R3 historical repair report/manifest remain unchanged at `0956b606…` / `0faed483…` as recorded by the R4 erratum.

