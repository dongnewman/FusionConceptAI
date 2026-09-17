# Independent review r3: UP2-00B N07/N08

Verdict: `pass_limited` for the stated `schema_validation_only` slice. The author archive remains `review_pending` / `accepted=false`. This review does not accept UP2-00B as a whole and grants no B00, B04, mesh, provider, solver, engineering, physical, or R01-R10 credit.

## Independent execution

Before the run, the repository had no `julia.exe` or `desc.exe` process. One independent command was run serially:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n07_n08_geometry.jl
```

The process record is `focused_test.process.json`: PID `69344`, start `2026-09-14T08:16:42.7842723+08:00`, Julia `1.10.5`. The real exit artifact is `focused_test.exit.txt`, three bytes `30-0D-0A`, value `0`. `focused_test.stdout.log` is 1362 bytes, SHA-256 `d9e46fb2b4edee1faee6044f3afa36c51730ae871fa0512481c837d77df09762`; it reports `108/108` and `2/2`. `focused_test.stderr.log` is zero bytes. A post-run process check found no Julia/DESC process, so the heavy lane is released.

The author history was retained and independently checked: r1 exit `1` (wrong runner path), r2 exit `1` (missing semantic views), r3 exit `0`; their original stdout/stderr/exit bytes and hashes are listed in `before_hashes.json` and were unchanged during this review.

## Source-backed checks

`src/GenomeV5/UP2/N07N08GeometryProjectionV1.jl:98-147` makes `n07_n08_projection_from_a(package)` the candidate-bound path. It checks the actual A package structural status, concrete G2 type, G2 candidate ref, G2 genome hash, component identity, and recomputed package hash before projecting fields from `package.g2`. The direct `from_g2` path is explicitly supplemental and is not counted as candidate-bound acceptance.

The ten rows are read from `test/GenomeV5/UP2/n07_n08_geometry_fixtures.json` by `test/GenomeV5/UP2/n07_n08_geometry_tests.jl:6-7,123-145`. The projected source locators are concrete G2 fields at `N07N08GeometryProjectionV1.jl:114-124`:

- N07-01 `G2RegionV2.lower`
- N07-02 `G2RegionV2.upper`
- N07-03 `G2ExteriorPlanV2.boundary_faces`
- N07-04 `G2BoundaryFacePatchV2.lower`
- N07-05 `G2ExteriorPlanV2.boundary_condition`
- N08-01 `G2ChartPlanV2.axes`
- N08-02 `G2ChartPlanV2.map_kind`
- N08-03 `G2MeshPlanV2.cells_per_region`
- N08-04 `G2MeshPlanV2.basis`
- N08-05 `RegionInterfaceContractV2.interfaces`

`_n07n08_mutate` at lines 163-174 changes each actual typed value, and `_n07n08_classify` at lines 188-225 derives `invalid_boundary`/`fail_closed` from the mutated value and concrete projection relationships. `n07_n08_validate_mutation` at lines 228-244 binds the field metadata, applies the mutation, computes a changed hash, and retains zero compile/provider/solver counters. The classifier does not route on `spec.expected_error`; the test compares that fixture expectation against the independently computed result at lines 136-142. The independent boundary test at lines 147-157 also rejects a v4 candidate ref.

The second topology (`split_y_half`) is exercised through the supplemental `from_g2` seam only and is explicitly excluded from the ten candidate-bound acceptance rows. N08 interface cardinality/uniqueness is stated and implemented as a rule for the currently admitted G2 contract, not a universal topology theorem.

## Scope limits and required non-credit

The result is limited to the ten frozen mutations and the current G2 admitted object. It is not general geometry validation. In particular, `_n07n08_bounds_valid` at lines 177-182 compares against the global envelope and uses `regions[1]` as the baseline for N07-01/N07-02; it does not prove each region's local bounds. N07-03 at lines 196-198 checks required-face inclusion but not duplicate or extra faces. N07-05 at lines 204-206 rejects `:none_declared` but accepts arbitrary other symbols. These are explicit limits on this `pass_limited` verdict and must not be promoted to a broader N07/N08 contract without new source-derived mutations and negative controls.

The projection mutates projected values and validates schema-level relationships without rebuilding a G2 component or executing mesh/provider/solver code. Therefore the zero counters are a bounded non-invocation result, not evidence of physical or engineering behavior. The current G2 URI namespace/admission checks are prerequisites for the seam; they do not provide provider or mesh authority.

## Integrity and write boundary

`before_hashes.json` records the frozen author/source/fixture/test/runner and r1-r3 artifact hashes. No author source, fixture, test, runner, old evidence, core document, or run artifact was modified. This directory contains only the independent process/environment/output records, hashes, this report, and the independent manifest.

The limited recommendation is to retain the author archive as review-pending and permit only the stated contract-only slice to proceed to its next independent integration gate. Any broader N07/N08, B00/B04, or physical claim remains pending.
