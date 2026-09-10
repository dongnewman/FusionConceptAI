# Runtime V4 3-D normalized-to-SI root bridge report — 2026-09-10

## Result

An isolated candidate-bound compiler now recognizes distinct normalized chart
and SI physical coordinate/metric roots joined by the exact support scale. The
implementation uses the existing multi-root AST/hyperedge machinery and does
not modify any existing G2 or 3-D physical-input type, constructor, semantic
view, canonical wire format, or hash.

The positive manufactured fixture uses two `AtomicMIMOHyperedgeV1` programs.
Each program has normalized root position 1 and SI root position 2 on the same
operator site. The coordinate SI root directly consumes the normalized
coordinate root plus exact `L`; the metric SI root directly consumes the
normalized metric root plus exact `L^2`. Dedicated exact-type, pure and
stateless operator manifests are embedded in the program hashes.

The prior single-root fixture is preserved unchanged. It resolves to the exact
four recoverable bridge gaps rather than being upgraded or rejected. This is
the compatibility strategy: existing declaration, candidate, binding, and
replay hashes remain byte-for-byte governed by their old semantics, while the
new compiler derives the normalized identities from the chart roots and the SI
identities from the existing physical declaration.

## Authority boundary

`bridge_ready` means structural root and scale linkage only. It is not an
interpreter result or geometry proof. The compiler emits no proof, certificate,
DESC request, provider result, solver result, receipt, or evidence. It grants
no pass or promotion authority and leaves credible physical device count zero.

## Files

- `src/RuntimeV4/ThreeDNormalizedPhysicalRootBridgeV4.jl`
- `examples/runtime_v4_three_d_normalized_physical_root_bridge.jl`
- `test/runtime_v4_three_d_normalized_physical_root_bridge_tests.jl`
- `scripts/run_v4_three_d_normalized_physical_root_bridge.jl`
- `docs/implementation/three_d_normalized_physical_root_bridge_v4.md`
- `docs/reports/three_d_normalized_physical_root_bridge_20260910.md`

No existing file was edited. The working tree contained unrelated untracked
work before this slice; it was left untouched.
