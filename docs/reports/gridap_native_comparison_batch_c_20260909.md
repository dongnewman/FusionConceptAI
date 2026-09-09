# Batch C native/Gridap numerical V&V — 2026-09-09

## Scope and verdict boundary

Batch C is an isolated three-level comparison of the existing native
finite-difference provider and the independent Gridap Q1 weak-form provider.
It consumes the frozen 5/9/17 convergence receipts plus sealed provider
reports; it does not assemble or solve either discretization.

The only admissible positive result is manufactured-solution consistency and
code-to-code agreement on one declared control. It is `manufactured_control`
with a `screen_only` ceiling. It keeps
`credible_physical_candidate_count=0`, `p5_ready=false`, and
`unsupported_emitted=false`. It is not evidence that a fusion model, physical
device, engineering design, control system, or validation claim is correct.

## Provider and replay boundary

Each native level is executed through `field_residual_provider` into two
distinct fresh `FieldResidualPipelineStoreV4` instances. A sealed
`NativeFieldReplayWitnessV4` retains both stores and revalidates their report,
receipt, assembly, result, provider, input, artifact-cache, and execution-count
identities. The comparison consumes the witness, never a caller-supplied
native assembly or solution array.

Each Gridap level is consumed as a validated `GridapFieldEvidenceBundleV4`.
Construction also invokes B3's same-process, fresh-store deterministic replay
and requires identical evidence, artifact, receipt, result, and report
identities. This is not a cross-process or cross-environment reproducibility
claim: B3's input/report registries are process-local. Native and Gridap
provider code hashes and independence groups must differ. Their matrix and
right-hand-side identities are recorded as `independent_discretizations`,
never compared for equality.

## Exact identity chain

Construction rederives and binds at every level:

- candidate Genome bundle, compiled prefix, Genome registry, mission, bounds,
  scenario, and constraint-edge identities;
- the common continuous support/chart, signed affine factors and offsets,
  scale, Jacobian/metric terms, and residual form;
- level-specific geometry and grid hashes;
- G2 `u`/`f` plan, result, and evidence identities;
- source and boundary content hashes;
- native and Gridap protocol, source-code, adapter, and dependency identities;
- provider, solver-input, evidence, replay, report, assembly, matrix/RHS where
  applicable, and result hashes.

Foreign or mixed identity is an admission error. A finite value or a
successful-looking status is never sufficient to construct the comparison.
The public acceptance validator therefore requires the original bundles,
native replay witnesses, convergence receipts, compiled prefix, registry, and
scenario. It reconstructs coordinates, weights, metrics, and all external
bindings before accepting the stored report. The one-argument form deliberately
returns `false`; internal hash self-consistency is not provenance.

## Explicit common-domain transfer

For each 5/9/17 grid, Batch C independently derives native physical node
coordinates from the signed affine chart and reads Gridap physical sample
coordinates from the sealed report. It constructs an exact coordinate-keyed
bijection. Duplicate, missing, foreign, or non-bijective coordinates fail
closed, so array position is not treated as physical correspondence.

The transfer record seals the coordinate hashes, native and Gridap index maps,
tensor-product trapezoid weights, and mapping hash. Metrics are kept separate:

- coordinate alignment L∞;
- interpolation L∞, exactly zero because this control admits an exact nodal
  bijection and performs no interpolation;
- common-physical-domain transfer L∞ and weighted L2;
- transfer relative L2 with a source-frozen scale floor;
- native manufactured-solution Linf error and order;
- Gridap manufactured-solution L2/H1-seminorm errors and orders;
- Gridap source and boundary interpolation errors;
- native and Gridap solver residuals.

The report never merges these norm families into one convergence sequence.

The sealed B2 receipt is an explicit trusted upstream qualification input.
Batch C checks its plan, grid, G2 result, cell/DOF, and residual bindings to the
current B3 bundles, but does not repeat B2's FE volume integrations for L2/H1
or source/boundary interpolation metrics. Defending against a caller with
module-private B2 signing authority would require rerunning B2 itself and is
outside this consumer-layer validator.

## Frozen acceptance policy

Native Linf order remains governed by its sealed `[1.8, 2.2]` receipt. Gridap
L2/H1 orders remain governed by its sealed B2 intervals `[1.5, 2.5]` and
`[0.7, 1.3]`. Batch C source freezes independent per-level transfer L∞,
weighted-L2, relative-L2, coordinate, interpolation, and transfer-order bands.
The first clean integrated run was used only to freeze the explicit transfer
bands before final qualification: L∞ `(0.75, 0.20, 0.055)`, weighted-L2
`(0.95, 0.24, 0.060)`, relative-L2 `(0.14, 0.045, 0.012)`, and observed-order
interval `[1.5, 2.5]`. These are source constants, not caller inputs.

Identity/provenance defects throw. Batch C is a success-only comparison API:
an upstream native or Gridap solver failure remains in that provider's typed
report and is refused rather than relabelled by Batch C. When both providers
produce valid finite pass artifacts but their transfer metrics fall outside
the comparison bands, Batch C emits a sealed `numerical_fail` with explicit
rejection reasons. Neither path becomes `unsupported` or a permanent-pruning
certificate.

## Legacy classification

| Legacy source | Extract | Wrap | Test-only | Reject |
|---|---|---|---|---|
| `numerical_verification.jl` | formulas and invariants only | only the new typed receipt | replay/negative-test intent | old `Dict`, status, or authority |
| `candidate_vvuq_runtime_v87.jl` | formulas and invariants only | only the new typed receipt | replay/negative-test intent | reduced proxy as FE, independent-code, or physical evidence |
| `generic_vvuq_runtime_v94.jl` | formulas and invariants only | only the new typed receipt | replay/negative-test intent | historical output as validation or authority |
| `physical_vvuq_runtime_v96.jl` | formulas and invariants only | only the new typed receipt | replay/negative-test intent | inherited physical/P5 claims |

No legacy runtime is imported, wrapped, or treated as current evidence.

## Verification

Pinned runner:

```text
julia --startup-file=no --history-file=no --project=tools/qualification/gridap scripts/run_v4_gridap_native_comparison.jl
```

Focused adversarial suite:

```text
julia --startup-file=no --history-file=no --project=tools/qualification/gridap test/runtime_v4_gridap_native_comparison_tests.jl
```

First clean integrated measurements used to freeze the transfer bands were:

| Nodes/axis | Native Linf | Gridap L2 | Gridap H1 | Transfer Linf | Transfer weighted-L2 | Transfer relative-L2 |
|---:|---:|---:|---:|---:|---:|---:|
| 5 | 0.3088235294117648 | 1.2296866291411006 | 5.6328357737805845 | 0.6841562712041351 | 0.842786543419774 | 0.12272147824930582 |
| 9 | 0.08237650367436088 | 0.3093923279431648 | 2.7632236881230416 | 0.16877710762192805 | 0.2119130560481015 | 0.03909555160461677 |
| 17 | 0.02095537455690701 | 0.07743601858664473 | 1.373269189825189 | 0.04216176301252046 | 0.053003823442146686 | 0.010538611329835875 |

Transfer Linf orders were `(2.0192066603498726, 2.0011121345787237)`;
weighted-L2 orders were `(1.9916948036904003, 1.9993041378088579)`.

The final current-source runner and focused-suite exit summaries follow after
the frozen-band reruns; first-clean values alone are not the acceptance claim.

Final current-source pinned runner (`exit 0`):

```text
gridap_c_status=pass
gridap_c_native_linf=(0.3088235294117648, 0.08237650367436088, 0.02095537455690701)
gridap_c_gridap_l2=(1.2296866291411006, 0.3093923279431648, 0.07743601858664473)
gridap_c_gridap_h1=(5.6328357737805845, 2.7632236881230416, 1.373269189825189)
gridap_c_transfer_linf=(0.6841562712041351, 0.16877710762192805, 0.04216176301252046)
gridap_c_transfer_l2=(0.842786543419774, 0.2119130560481015, 0.053003823442146686)
gridap_c_transfer_relative_l2=(0.12272147824930582, 0.03909555160461677, 0.010538611329835875)
gridap_c_transfer_linf_orders=(2.0192066603498726, 2.0011121345787237)
gridap_c_transfer_l2_orders=(1.9916948036904003, 1.9993041378088579)
gridap_c_native_independence_group=runtime-v4-native-field-residual
gridap_c_gridap_independence_group=gridap-weak-form-assembly-v1
gridap_c_claim_ceiling=screen_only
gridap_c_credible_physical_candidate_count=0
gridap_c_p5_ready=false
GRIDAP_NATIVE_COMPARISON_OK
```

Final current-source focused adversarial suite (`62/62`, `exit 0`):

```text
Batch C sealed provider replay and exact identity: 21/21 pass
Batch C keeps error families and authority separate: 21/21 pass
Batch C coordinate operator is explicit and permutation-safe: 7/7 pass
Batch C adversarial bindings and acceptance fail closed: 13/13 pass
BATCH_C_FOCUSED_EXIT_CODE=0
```
