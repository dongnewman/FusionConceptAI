# DESC geometry-program preflight V4 - 2026-09-10

## Decision

The attempted next step was narrowed from a geometry certificate to the exact
program-input preflight that the certificate actually requires. Current
RuntimeV4 geometry cannot honestly support a DESC compatibility proof: its G2
coordinate and metric programs are constant, have no chart-coordinate input,
declare no periodic axes, and do not close the chart-root-to-graph-root type
ABI.

The new slice makes those facts candidate-bound and replayable. It does not
alter `DESCFixedBoundaryRequestCompilerV4.jl`; request compilation still ends
at `required_verified_desc_geometric_compatibility_proof`.

## Exact outcomes

The accepted 3-D composition fixture without DESC declarations returns:

```text
required_desc_geometry_convention_declaration
required_desc_fixed_boundary_request_declaration
required_desc_fixed_boundary_request_subject_binding
```

The fully DESC-declared manufactured fixture returns:

```text
required_desc_normalized_turn_chart_domain
required_desc_poloidal_turn_period_axis_declaration
required_desc_field_period_turn_axis_declaration
required_desc_exact_periodic_turn_axis_set
desc_coordinate_chart_root_abi_mismatch
desc_metric_chart_root_abi_mismatch
required_desc_normalized_physical_root_bridge_contract
required_executable_desc_coordinate_map_program
required_executable_desc_metric_program
required_pinned_desc_geometry_operator_manifests
required_desc_geometry_program_interpreter
```

For that fixture, both physical-declaration AST-root identity hashes match the
actual G2 graph roots. This confirms the defect is not a missing digest: it is
the absent executable chart ABI and semantics.

The accepted schemas also cannot presently represent the normalized chart root
and SI physical root as distinct, compiler-joined outputs. The preflight is
therefore intentionally gap-only; it has no reachable `program_ready` status.

## Verification boundary

Focused tests cover both exact gap tuples; candidate/context/prefix/registry/
subject/declaration/binding/root hash joins; coordinate and metric ABI flags;
closed, ordered, unique gaps; context-aware replay; private-token rejection;
self-consistent flag/hash forgery rejection; foreign-context resolution
rejection; and every authority-ceiling field.

The focused command
`julia --project=. --startup-file=no --history-file=no test/runtime_v4_desc_geometry_program_preflight_tests.jl`
passed 118 of 118 assertions with exit code 0.

The standalone runner exited zero, printed both exact gap lists, preserved all
three false output flags, and ended with
`DESC_GEOMETRY_PROGRAM_PREFLIGHT_OK`. No DESC process or other solver was
started.

Targeted regressions also passed with exit code 0: RuntimeV4 core 26/26,
RuntimeV4 spine 54/54, trusted provider registry 65/65, trusted FreeGS wrapper
43/43, and the pinned FreeGS 0.8.2 execution runner. The FreeGS result remains
`physical_model_screen` with `physical_validation=false` and
`engineering_validation=false`; it is not upgraded by this preflight.

## Remaining proof obligations

This preflight is not the geometric proof. Before a certificate can exist, the
candidate must own real normalized-turn coordinate and metric programs in its
G2 graph. The later verifier must independently replay exact program semantics
and establish:

- Runtime/DESC mode, sign, phase, and NFP agreement;
- Fourier boundary value and first-derivative equality;
- poloidal seam periodicity and field-period rotational equivariance;
- metric equality to the coordinate-map Jacobian product;
- explicit magnetic-axis regularity rather than false strict positivity at
  `rho=0`;
- right-handedness and a certified global nondegeneracy bound using exact or
  outward-rounded arithmetic.

Finite grids, ordinary floating-point minima, selected-mode orientation
heuristics, hashes, Booleans, or conditional e-graph provenance cannot close
those obligations.
