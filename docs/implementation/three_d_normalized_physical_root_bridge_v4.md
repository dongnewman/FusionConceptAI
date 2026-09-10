# Runtime V4 normalized-to-SI 3-D root bridge

## Scope

This isolated compiler closes only the representation gap between the G2
chart's dimensionless normalized roots and the physical declaration's SI
roots. It does not interpret the programs, prove their continuous geometry,
emit a certificate or DESC request, select a provider, run a solver, or emit
evidence. `bridge_ready` therefore remains `screen_only` and is explicitly not
a geometry proof.

## Backward-compatible representation

No field or canonical-wire change is made to `CoordinateChartGeneV1`,
`SpatialSupportGeneV1`, `ThreeDCoordinateMetricV4`, or
`ThreeDPhysicalProviderInputV4`.

The existing types already admit the required separation:

- `CoordinateChartGeneV1.coordinate_map_root` and `metric_program_root` own the
  normalized root declarations, including their operator site and root
  position.
- `ThreeDCoordinateMetricV4.coordinate_map_root_identity_hash` and
  `metric_root_identity_hash` own the SI physical root identities and types.
- `SpatialSupportGeneV1.resolution_independent_scale` owns the exact positive
  SI length scale.
- A candidate-owned `AtomicMIMOHyperedgeV1` can expose more than one root at
  the same operator site. The accepted fixture uses root position 1 for the
  normalized output and root position 2 for the SI output on each of the
  coordinate and metric programs.

This preserves every legacy declaration and candidate hash. A legacy
single-root fixture remains valid under its existing contracts but resolves to
the four exact bridge gaps; it is not silently reinterpreted as bridge-ready.

## Exact bridge ABI

The coordinate program has one chart-coordinate input and two outputs:

1. normalized ambient coordinate, dimensionless;
2. SI physical coordinate, produced by
   `RUNTIME_V4_SUPPORT_SCALE_COORDINATE@v1(normalized, L)`.

The metric program has the same chart-coordinate input and two outputs:

1. normalized covariant metric, dimensionless;
2. SI covariant metric, produced by
   `RUNTIME_V4_SUPPORT_SCALE_METRIC@v1(normalized_metric, L^2)`.

`L` is the exact rational value of the selected support's
`resolution_independent_scale`, with SI length type. `L^2` is an exact rational
constant with SI length-squared type. The bridge compiler requires the SI root
AST node to consume the normalized root node directly, validates both graph
output types, and verifies the exact pure, stateless operator-manifest hash
bound into the program. Merely sharing a chart input or declaring matching
types is insufficient.

## Public API

- `compile_three_d_normalized_physical_root_bridge(context)` returns a sealed,
  canonical resolution with status `:bridge_ready` or `:recoverable_gap`.
- `validate_three_d_normalized_physical_root_bridge(context, resolution)`
  recompiles against the exact context and rejects foreign replay.
- `validate_three_d_normalized_physical_root_bridge(resolution)` returns true
  only for a canonical `:bridge_ready` result.
- `three_d_normalized_physical_root_bridge_manifest()` publishes the closed
  statuses, gap vocabulary, and authority ceiling.

The closed gaps are:

1. `required_distinct_normalized_coordinate_root`
2. `required_distinct_normalized_metric_root`
3. `required_support_scale_coordinate_root_bridge`
4. `required_support_scale_metric_root_bridge`

## Integrity and circularity controls

Root identities are derived from the already-compiled graph and include edge
position, edge ID, program hash, root position, AST root node, and graph output
node. The declaration points to those identities; the later subject binding
then binds the declaration and candidate. The compiler never puts a candidate,
declaration, or subject hash back into the graph program, avoiding a
graph-to-declaration-to-candidate-to-graph hash cycle.

Support and chart objects are resolved by reference from the candidate and
hashed into the audit. Duplicate declarations, bindings, supports, charts, or
operator sites fail as integrity errors. Flags and gaps are cross-checked during
canonical validation, and context validation rebuilds the complete result.

## Next boundary

The bridge may be consumed by the separate DESC geometry preflight to remove
only `required_desc_normalized_physical_root_bridge_contract`. Program
interpretation, Fourier component assembly, derivatives, metric derivation,
continuous-domain compatibility proof, certificate issuance, and request
emission remain separate milestones and must not be inferred from `bridge_ready`.
