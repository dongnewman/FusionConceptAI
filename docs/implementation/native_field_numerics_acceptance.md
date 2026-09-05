# Native field numerical kernel acceptance

The standalone numerical kernel passed **43/43 assertions**, exit **0**, with
Julia 1.10.5 in the root's frozen acceptance checkout. Its test includes the
published contracts, G2 field types, and numerical kernel in a separate module;
the package and RuntimeV4 entrypoints do not yet include this kernel.

Reproduce from the repository root:

```powershell
julia --startup-file=no --project=. test/runtime_v4_field_residual_numerics_tests.jl
```

The tested implementation extracts the admitted scalar linear residual from
typed AST operator manifests, uses declared diagonal affine geometry, assembles
a three-dimensional structured-grid sparse system with Dirichlet data, and
solves it with sparse LU. Tests cover typed geometry and AST extraction (10),
assembly and numerical solution (29), and a manufactured convergence control (4).

| Nodes per axis | Manufactured solution error (Linf) |
|---|---:|
| 5 | 0.6176470588235297 |
| 9 | 0.16475300734872175 |
| 17 | 0.04191074911381381 |

Observed orders are **1.9064778764480812** and **1.9749125863875925**. These are
manufactured numerical controls. They do not establish a validated physical
model, candidate-bound execution evidence, complete Batch A integration,
independent-code qualification, whole-device readiness, or VVUQ completion.
The separate candidate Pipeline and CLI acceptance is still running.

The frozen run used these raw SHA-256 identities:

| File | SHA-256 |
|---|---|
| `src/RuntimeV4/FieldResidualNumerics.jl` | `ED956E72E0D1F3C27D029ED1F463CE4FD38C3A9EB309C9BA9CC9ED735AF2CCB5` |
| `test/runtime_v4_field_residual_numerics_tests.jl` | `124C13DC39F619D954D6531A5589453FE48397100BE586A82070921B46AE3D5D` |
| `Project.toml` | `DD0E3DA29B8AB36AF7AEA8E81F5F6F73DC5BC2E1E2AFB3C8258EADD06AB6C225` |
| `Manifest.toml` | `3E5EEF2A0AF7DDCDC79B7DF3B69F491CF088F76865765EC3169C1325649AB39D` |

The dependency comparison adds only `SparseArrays` to Project and
`SparseArrays`/`SuiteSparse_jll` to Manifest. All 14 existing locked dependency
entries are unchanged. Raw checkout bytes and parsed dependency identity remain
distinct, as described in the RuntimeV4 acceptance record.

The root log is
`D:\006-Programing\LMC\.codex_tmp\fusion-v4-field-chain-new-four-root.log`;
the source snapshot is `fusion-v4-field-chain-new-four-start.csv` in the same
directory. The independent earlier kernel run also passed 43/43 with identical
errors and observed orders. The latest completed run is the acceptance basis
for this additive kernel release.
