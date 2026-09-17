# H0-A independent static precheck R9

Verdict: `ready_for_serial_focused`.

This read-only Luna/high review covers the R9 test-helper repair after the focused_r2 exit-1 and independent postrun_r2 finding. HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`; the pre-write worktree snapshot had 297 porcelain entries and zero Julia/DESC processes. Julia and DESC were not run.

## Helper repair

The only H0-A digest helper is `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:9`, now exactly:

```julia
_h0a_digest(ch) = G.digest256_text(String(ch))
```

All helper calls remain present, including the previously exposed `z` label and the latent `foreign-schema`, `foreign-canonical`, `stale`, and `stale-g3` labels. They now produce deterministic SHA-256 content digests through the exported canonical API. The repair removes the test-only misuse of the strict `Digest256` representation constructor and does not weaken production validation. `src/IR/PhysicalTypes.jl:10-33` still requires exactly 64 lowercase hexadecimal characters for `Digest256` and implements `digest256_text` by hashing UTF-8 text before constructing that type; `src/FusionConceptAI.jl:54` exports the helper.

The R9 delta is limited to this test helper. Source, fixture, runner, and core files are unchanged. The test's existing candidate, G1/G2/G3 component, stale identity, foreign reference, content-hash, unit, closure, role, classification, and actual-A paths still call the same helper-derived values and retain their assertions. The four target hashes are frozen in the evidence manifest.

## Boundary and disposition

The fixture continues to declare `schema_validation_only=true` and `actual_a_positive=false`. Synthetic schema-only construction remains a contract test. Actual A remains deferred, and the focused_r2 error remains preserved as historical evidence; this review does not reinterpret its partial 5-pass/1-error result as a pass. No B00, B04, physical, engineering, provider, mesh, or R credit is granted.

Static QA is sufficient to advance to the single serial focused lane, subject to the existing GI1B lane gate. This review did not run Julia/DESC and does not establish runtime acceptance.