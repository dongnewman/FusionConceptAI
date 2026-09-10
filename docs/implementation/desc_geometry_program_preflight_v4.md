# Runtime V4 DESC geometry-program preflight

## Scope

`DESCGeometryProgramPreflightV4.jl` is an isolated, candidate-bound
prerequisite for a future Runtime-to-DESC geometry proof. It consumes a
`ForwardChainContextV4`, reconstructs the accepted 3-D physical input
composition and DESC request binding, then inspects the actual G2 graph edges
and AST roots named by the selected chart.

This slice does **not** prove geometric compatibility, emit a proof
certificate, authorize a DESC request, select or execute a provider, or emit
evidence. This revision deliberately has no `program_ready` status because the
accepted upstream types cannot yet represent the required normalized-to-SI
root bridge. The current fixture returns `recoverable_gap`.

## Exact ownership chain

The preflight revalidates the complete `ForwardChainContextV4`, calls
`compose_three_d_physical_inputs`, inventories the candidate-owned DESC
convention/control declarations and subject binding, rebuilds that binding
against the exact candidate, compiled prefix, registry, mission, bounds,
comparison scope, scenario scope, scenario, composition binding, and all six
upstream component bindings, and requires canonical and semantic equality.

It then selects exactly one G2 graph binding, one spatial support, one chart,
one coordinate-map edge, and one metric edge. Missing or duplicate graph
objects are integrity failures. The audit records hashes for the context,
candidate, prefix, registry, physical subject, composition, DESC declarations
and binding, G2 Genome and graph, support, chart, edges, programs, and AST roots.

## Root ABI checks

For both coordinate and metric roots, the preflight independently joins:

- the chart `operator_site_ref` to the graph edge ID;
- the chart `root_position` to the selected program root;
- exactly one program input and one graph input;
- the program input type to the chart-declared `chart_coordinate` input;
- the program root and graph output types to the chart-declared normalized
  output type;
- the derived forward-chain AST-root identity to the physical declaration's
  stored root identity hash.

A root is only marked structurally admissible when it has one external chart
input, the selected root is not a state, parameter, or constant leaf, and that
root actually depends on the input. Existing operator bindings are replayed
against the pinned default registry. These checks remain insufficient for
execution until a dedicated geometry interpreter exists. This is deliberately
stricter than the existing
3-D physical declaration validator, which binds physical SI output roots but
does not close the chart root's input/root/output ABI.

## Required turn-coordinate declaration

The future proof uses normalized turn coordinates
`(rho, theta_turn, zeta_field_turn)` on `[0,1]^3`. The periodic-axis set must be
exactly `(2,3)`, with exact dimensionless period one for both axes; a periodic
radial axis is rejected. This avoids embedding
irrational `pi` values in the rational chart-bound types; a later proof must
derive `theta = 2*pi*theta_turn` and
`zeta = 2*pi*zeta_field_turn/NFP`.

These axis-declaration checks do not establish function periodicity. In
particular, Cartesian coordinates at the two field-period endpoints are
related by a rotation for `NFP > 1`, not by raw endpoint equality. That
equivariance, Fourier phase/sign semantics, metric derivation, magnetic-axis
regularity, and a continuous-domain nondegeneracy bound remain proof-stage
obligations.

## Closed gaps

After all upstream objects exist, the local gap vocabulary is:

1. `required_desc_normalized_turn_chart_domain`
2. `required_desc_poloidal_turn_period_axis_declaration`
3. `required_desc_field_period_turn_axis_declaration`
4. `required_desc_exact_periodic_turn_axis_set`
5. `desc_coordinate_chart_root_abi_mismatch`
6. `desc_metric_chart_root_abi_mismatch`
7. `required_desc_normalized_physical_root_bridge_contract`
8. `required_executable_desc_coordinate_map_program`
9. `required_executable_desc_metric_program`
10. `required_pinned_desc_geometry_operator_manifests`
11. `required_desc_geometry_program_interpreter`

Upstream composition and DESC-declaration gaps retain their existing canonical
order. Gap tuples are immutable, closed, unique, and ordered. A missing
declaration is recoverable; duplicate/orphan/foreign bindings and missing or
ambiguous graph objects throw integrity errors. A chart root position that
does not select an actual root on its declared edge is also an integrity error,
because it is a contradictory reference inside an already accepted context.

Standalone `canonical_hash` validates structural integrity and the authority
ceiling; it is not provenance validation. Only
`validate_desc_geometry_program_preflight(context, resolution)` reconstructs
the current context result and rejects a self-consistent artifact copied from
or rewritten for another candidate.

## Current fixture result

The DESC-declared manufactured fixture reaches its actual G2 coordinate and
metric roots, but:

- chart bounds are `[-1,1]^3`, not normalized turns;
- neither angular axis is periodic;
- both graph programs have zero inputs and constant roots;
- chart roots declare normalized coordinate/metric outputs while the graph
  roots are physical SI coordinate/metric outputs;
- the constant programs have no operator-manifest bindings.

It therefore returns all eleven local gaps. The stored physical-declaration
root identities do match the actual graph roots; the preflight distinguishes
that identity success from the missing chart ABI and executable semantics.

## Authority ceiling

Audit, resolution, and manifest are fixed to `screen_only`, manufactured-input
scope, zero credible devices, and false geometry proof, certificate, request,
provider selection/execution, solver attempt/execution, physical validation,
engineering validation, evidence, pass, promotion, P5, and terminal authority.

The next admissible implementation edge is the paired normalized/SI root bridge
contract plus a candidate-owned executable coordinate/metric program with the
exact turn-coordinate ABI, pinned operators, and a dedicated interpreter. A
separate proof slice must then establish Fourier boundary and
first-derivative equality, periodic/equivariant seam semantics, `g = J'J`,
axis regularity, orientation, and a mathematically certified continuous-domain
lower bound. Finite sampling is not sufficient.
