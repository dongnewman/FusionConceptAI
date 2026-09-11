# DESC field basis bridge report

This milestone closes one concrete vector-basis ambiguity before multi-region
integration: DESC `B` and `F` are now carried as embedded cylindrical
`(R, phi, Z)` physical vectors and explicitly rotated into laboratory
Cartesian `(x, y, z)` at typed, candidate-bound sample points. A fresh DESC
0.17.3 process supplies laboratory `phi = zeta + omega`, position, vectors, and
`sqrt(g)` and cross-checks the already sealed field-provider output. The
request reconstructs and binds the exact accepted geometry certificate plus
its physical declaration, support, chart, graph, and coordinate/metric
program identities; this still does not imply a region partition.

The focused test passed 95/95 assertions with
`DESC_FIELD_BASIS_BRIDGE_FOCUSED_PROCESS_EXIT=0`. The standalone runner emitted
`DESC_FIELD_BASIS_BRIDGE_EXECUTED=1`,
`DESC_FIELD_BASIS_BRIDGE_RUN_EXIT_CODE=0`, and exited 0. Separate related
regressions passed for the DESC field provider (62/62), request/provider
execution (70/70), and analytic geometry compatibility proof (89/89), with
`DESC_BASIS_RELATED_REGRESSIONS_PROCESS_EXIT=0`. The repository-wide
`test/runtests.jl` process completed with `FULL_TEST_PROCESS_EXIT=0`.

Negative tests reject foreign geometry-support identity, truncated upstream
samples, wrong basis metadata, malformed output, artifact tampering, a forged
process hash, and an arbitrary output carrying a recomputed receipt hash. A
synthetic failing adapter preserves its actual exit code 11. Final independent
incremental reviews found no remaining P1/P2 issue after the geometry-identity,
process-hash, output-envelope, and sample-completeness fixes.

This is not multi-region closure. Current RuntimeV4 support mapping proves
reference identity only; it does not define disjoint/exhaustive rho subdomains,
a `rho=constant` interface level set, trace-point maps, or oriented normals.
Those are the next typed geometry obligations. Solver convergence, physical or
engineering validation, evidence, promotion, P5, terminal authority, and
credible-device count all remain false/zero.
