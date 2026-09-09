# Gridap B1 independent acceptance — 2026-09-09

## Verdict

**ACCEPT B1 only** at `main@31260e2a1d875245438c15dbd981fe4dc0cf9d83`
(`feat(runtime): add independent Gridap field kernel`). The committed adapter
meets the B1 real-numerical-kernel boundary: it rederives candidate-bound G1/G2
inputs, assembles and solves a real three-dimensional Gridap Q1 weak form,
recomputes the algebraic residual from Gridap's matrix and vector, detects the
wrong-sign control, and does not call the native finite-difference assembler.

This is a manufactured software control with claim ceiling `screen_only`. It
does **not** accept B2 convergence, B3 sealed provider/evidence closure, Batch B
as a whole, numerical VVUQ, physical validation, engineering closure,
whole-device integration, P5 readiness, or any credible physical candidate.

## Repository state and audit scope

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Branch and commit during all B1 runs: `main`,
  `31260e2a1d875245438c15dbd981fe4dc0cf9d83`
- No tracked or staged diff was present. Other agents were concurrently adding
  untracked B2 and later-chain files; those files were not used to reach this
  verdict.
- Files audited directly:
  - `docs/implementation/gridap_field_adapter_plan.md`
  - `src/RuntimeV4/GridapFieldResidualAdapter.jl`
  - `examples/runtime_v4_gridap_field_fixture.jl`
  - `scripts/run_v4_gridap_field_residual.jl`
  - `test/runtime_v4_gridap_field_residual_tests.jl`
  - the upstream G1/G2 compilation and field-residual code exercised by the
    fixture and targeted regressions
- Qualification lock SHA-256 values observed from checkout bytes:
  - `tools/qualification/gridap/Project.toml`:
    `223FB6C8EA33F03989CCB4D76ED80016A3BC2799BC4210490C4E43CC7AFFCEB6`
  - `tools/qualification/gridap/Manifest.toml`:
    `2E1D103396D3F3FAA13687BD4A95FDE287D1F94E8B0006046B65E1E29AA3765A`

## Executed evidence

All commands were run from the repository root. Exit-code markers were printed
by PowerShell immediately after each Julia command.

### Exact pinned B1 focused test

```powershell
julia --startup-file=no --history-file=no --project=tools/qualification/gridap test/runtime_v4_gridap_field_residual_tests.jl
```

Exit code: `0`.

```text
B1 candidate-bound independent Gridap kernel: 62/62 passed
B1 fails closed on foreign inputs and lock bytes: 8/8 passed
B1 adapter has no native or legacy assembly dependency: 5/5 passed
FOCUSED_EXIT_CODE=0
```

Total: **75/75 assertions passed**.

### Exact pinned B1 runner

```powershell
julia --startup-file=no --history-file=no --project=tools/qualification/gridap scripts/run_v4_gridap_field_residual.jl
```

Exit code: `0`.

```text
julia_version=1.10.5
gridap_version=0.20.8
gridap_b1_status=pass
gridap_b1_cells=64
gridap_b1_free_dofs=27
gridap_b1_dirichlet_dofs=98
gridap_b1_residual_inf=2.220446049250313e-16
gridap_b1_relative_residual=3.5527136788005026e-16
gridap_b1_boundary_mismatch=4.440892098500626e-16
gridap_b1_manufactured_node_linf=0.37533274179237036
gridap_b1_claim_ceiling=screen_only
gridap_b1_numerical_vvuq_status=terminal_deferred
gridap_b1_credible_physical_candidate_count=0
gridap_b1_p5_ready=false
GRIDAP_B1_OK
RUNNER_EXIT_CODE=0
```

The 0.3753 value is a five-node-grid manufactured nodal control error bounded
by the frozen B1 tolerance of 0.45. It is not an L2 or H1 convergence result.

### Relevant main-package regressions

| Command | Result | Exit |
|---|---:|---:|
| `julia --startup-file=no --history-file=no --project=. test/runtime_v4_g2_field_evaluation_tests.jl` | 50/50 passed | 0 |
| `julia --startup-file=no --history-file=no --project=. test/runtime_v4_field_residual_numerics_tests.jl` | 43/43 passed | 0 |
| `julia --startup-file=no --history-file=no --project=. test/runtime_v4_field_residual_composition_tests.jl` | 54/54 passed | 0 |
| `julia --startup-file=no --project=. test/runtime_v4_typed_dae_composition_tests.jl` | 23/23 passed | 0 |
| `julia --startup-file=no --project=. -e 'using FusionConceptAI; ...'` | `DEFAULT_PACKAGE_LOAD_OK`, `gridap_loaded=false` | 0 |

The native numerical regression separately reported errors
`(0.6176470588235297, 0.16475300734872175, 0.04191074911381381)` and observed
orders `(1.9064778764480812, 1.9749125863875925)`. Those are native-kernel
regression values, not Gridap B2 evidence.

A full repository `Pkg.test()` was not rerun for this narrow acceptance.
Instead, the directly upstream candidate/G2, native numerical, D4.1
composition, and typed DAE composition suites were rerun with separate exit
codes.

## Independent audit findings

### Candidate and newest three-layer Genome binding

- The fixture builds a `CandidateStatePackageV4` from
  `MechanismGenomeV4` (G1), `FieldGeometryGenomeV4` (G2), and
  `RealizationControlGenomeV4` (G3), then compiles the candidate through the
  current `GenomeContractRegistryV4`. No legacy Genome migration path is used.
- `compile_gridap_field_residual_plan` accepts the typed candidate, compiled
  prefix, Genome registry, operator registry, and two typed G2 execution
  reports. It calls the public candidate-bound `compile_field_residual_plan`;
  it does not accept a caller-supplied native plan.
- Upstream compilation enforces object identity between candidate and prefix,
  reruns `_runtime_validate_compiled_prefix`, and binds the candidate bundle,
  prefix, registry, mission, scenario, exact constraint edge, form, geometry,
  grid, both G2 plan/result/evidence identities, and both materialized payload
  hashes.
- G3 is carried through the candidate bundle and compiled-prefix validation but
  is not executed by this static B1 slice. That is a scope boundary, not a
  family or authority-routing shortcut.

### Typed G1 AST/operator-hypergraph ownership

- The residual edge is selected from the compiled mechanism graph as exactly
  one `AtomicMIMOHyperedgeV1` whose canonical hash equals the requested edge
  hash.
- The accepted G1 program is the exact typed six-node
  `LAPLACE(u) - 2 f` AST. Input ordering, operator IDs and versions, output
  physical types, state references, and residual-state ownership of the edge
  are checked before the linear form is compiled.
- The resulting form is constrained at B1 to `alpha=1`, `beta=0`, one source
  coefficient `-2`, and zero constant. This is intentionally narrower than a
  general static linear PDE adapter.

### G2 derivation and evidence binding

- Each G2 plan is checked against candidate, prefix, G2 geometry hash, grid,
  scenario, and code hash, then recompiled from the frozen candidate and
  compared semantically.
- Each G2 result is recomputed from its typed AST and parameter binding. The
  report's subject, solver input, provider manifest, independence group,
  evidence status vector, artifact reference, metrics, and `screen_only`
  ceiling are rederived and checked.
- The manufactured fixture requires the exact two-root G2 typed AST for
  `u=(q dot q)^2` and `f=10(q dot q)` with its zero-offset parameter explicitly
  bound. The adapter consumes the real G2 values through deterministic
  tensor-product trilinear interpolation; it does not inject a hard-coded
  continuous source or solution into the Gridap assembly.

### Gridap assembly independence

- The adapter constructs a real three-dimensional `CartesianDiscreteModel`,
  Q1 Lagrange H1 test/trial spaces, strong Dirichlet data, a degree-8 measure,
  a Gridap `AffineFEOperator`, and Gridap sparse LU.
- The algebraic residual is recomputed as `norm(A*x-b, Inf)` using Gridap's
  `get_matrix(op)` and `get_vector(op)`.
- The adapter source contains no call/reference to
  `assemble_field_residual`, `assemble_field_residual_kernel`, `_fr_matrix`,
  `ResidualAssemblyV4`, or `FieldSolveResultV4`. The focused test poisons the
  native assembler and confirms its call counter remains zero.
- The default main-package load completed with `gridap_loaded=false`; Gridap
  remains isolated in `tools/qualification/gridap`.
- This establishes a distinct assembly implementation only. It is not yet a
  native-to-Gridap transfer comparison or independent-code validation result.

### Sign and physical map

- The declared map and inverse are implemented as
  `x_i=L(a_i q_i+o_i)` and `q_i=(x_i/L-o_i)/a_i`, preserving signed nonzero
  affine factors while sorting only the Cartesian-domain endpoints.
- The audited signed fixture maps to physical domain
  `(-0.75, 1.25) x (-1.5, 0.5) x (-1/3, 5/3)` and the round-trip probe passes.
- For the declared residual `alpha Laplace(u)+beta u+gamma f+c=0`, the weak
  form uses `alpha grad(v) dot grad(u)-beta v u` on the left and
  `v(gamma f+c)` on the right. The deliberately reversed source sign still
  factorizes and has a small algebraic residual, but is classified
  `numerical_fail` because it violates the manufactured control. The
  altered-factor control also fails the manufactured control.

### Status, authority, and replay boundaries

- Non-finite numerical values classify as `unknown`; a finite, declared-sign
  solve that meets residual, boundary, and manufactured-node tolerances
  classifies as `pass`; other finite controls classify as `numerical_fail`.
- The sealed report validator fixes evidence class to
  `manufactured_control`, claim ceiling to `screen_only`, numerical VVUQ to
  `terminal_deferred`, credible physical candidate count to zero, and
  `p5_ready=false`. It rejects a forged higher-ceiling report.
- `replay_gridap_field_residual` performs a fresh Gridap reassembly/solve and
  requires identical report, receipt, and result hashes. The focused replay
  assertion passed. This is deterministic replay evidence on this pinned
  host/environment, not cross-platform bitwise reproducibility.
- No authority module, device-family routing, legacy output tree, promotion,
  archive, or whole-device layer is imported into B1.

## Claim ceiling and remaining gaps

The strongest justified claim is:

> A candidate-bound, three-dimensional Gridap Q1 manufactured-control kernel
> passed its pinned focused test and runner on Julia 1.10.5 / Gridap 0.20.8,
> with independent weak-form assembly relative to the native finite-difference
> assembler, while remaining `screen_only`.

The following remain open and must not be inferred from this acceptance:

1. **B2 convergence:** no Gridap 5/9/17 solve set, L2 solution errors, H1
   seminorm errors, source interpolation L2 errors, boundary interpolation
   errors, observed Gridap orders, runtime/memory series, or frozen acceptance
   intervals were accepted here.
2. **B3 binding/evidence closure:** B1 has sealed plan/receipt/result/report
   objects, but not the planned external `ProviderManifestV4`,
   `ExecutablePhysicalSubjectV4`, `SolverInputV4`, `RuntimeEvidenceV4`,
   execute-once store, persisted canonical replay envelope, or complete
   adversarial matrix.
3. **Failure artifacts:** Gridap construction/factorization exceptions are not
   yet converted into replayable typed failed/unknown reports. The B1
   `factorization_status=:success` is created only after `solve` returns.
4. **Unsupported coverage:** the supported positive slice explicitly reports
   no unsupported obligation. Unsupported ASTs and other out-of-scope inputs
   fail compilation, but typed `unsupported` evidence and exhaustive
   dependency/candidate/provider forgery controls belong to B3.
5. **Numerical VVUQ and comparison:** there is no native-to-Gridap transfer
   operator, norm reconciliation, transfer-error budget, or independent-code
   validation receipt. Batch C and later physical/engineering evidence remain
   untouched.

Accordingly, the milestone disposition is **B1 accepted; B2, B3, Batch B, and
all higher claims remain unaccepted**.
