# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC

This is the additive local scaffold for the shared G1/G2 parent-baseline binding prerequisite. Sol/root has accepted the local source/test/fixture/static-QA software slice as `accepted_limited` after independent postrun R2 `pass_limited`; the machine work-order node remains `planned`/`proposal`/`accepted=false`/`review_pending`. It is deliberately a typed-absence implementation: the repository has no source-backed G1 or G2 V1 declaration instance, factory receipt, and fresh identity review that can authorize a present parent binding.

The production constructors therefore emit `AbsentParentBaselineBindingV1`, `AbsentChildKeyV1`, and a `typed_absent` / `terminal_deferred` state. Absent records contain the requested candidate or public contract identity, layer, reason, and domain-tagged absence digests; they contain no parent reference, parent hash, baseline hash, source locator, or factory placeholder. Present records and the private source-backed receipt seam are defined for the future contract, but public fixture, URI-only, synthetic, foreign, and absent-to-present promotion paths fail closed.

The only implementation surface is:

- `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl`
- `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`
- `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json`
- `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py`
- this directory's implementation reports, receipts, and manifests

The source is standalone and is loaded explicitly by its focused test. It does not alter `src/FusionConceptAI.jl`, package or registry files, T0/T1/T2, G1/G2 V1 declarations, AD-33 history, or any launcher. No provider, mesh, solver, physical, search, or runtime credit is claimed. The fixture is expected-only negative and absence data, never authority.

The required run is static QA with the resolved Python interpreter, followed by the direct command:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl
```

Run receipts are append-only. A failed run is retained with its raw output and hashes; repairs, if needed, add a later receipt. Cleanup inventories record only temporary files attributable to this work order. Existing dirty files, earlier AD-33 reviews and receipts, raw evidence, and frozen delivery files are kept.

The frozen local evidence is static QA `38/38` under Python 3.13.5 (executable
SHA-256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`)
and Julia R5 `52/52`, exit `0` (Julia executable SHA-256
`8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`). R1-R4
Julia failures remain preserved. Stable cleanup is `20/20` kept entries with
zero removals. Present G1/G2 baseline/child/source publication and all actual,
T0/T1/T2, provider, mesh, engineering, physical, search, B00/B04 and R01-R10
claims remain false.
