# Gridap environment smoke

This isolated environment checks that Gridap can install and execute a small
two-dimensional weak-form Poisson problem on the tested Windows host. It is
not a FusionConceptAI candidate adapter. It binds no Genome, candidate form,
or scenario and creates no `ProviderManifestV4` or `RuntimeEvidenceV4`.
It provides no independent-code qualification, numerical V&V, physical
validation, or S8-S10 evidence.

## Reproduce

Use Julia **1.10.5** and run these commands from the repository root:

```powershell
julia --startup-file=no --project=tools/qualification/gridap -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=tools/qualification/gridap tools/qualification/gridap/smoke.jl
```

The committed manifest locks Gridap **0.20.8** and its dependency graph. This
environment is separate from the main package environment. The first command
may download dependencies and compile them. Reproduce the recorded run with
the committed manifest rather than resolving a new set of package versions.

The script solves `-Laplacian(u) = 1` on the unit square, with zero Dirichlet
data, a 4 by 4 Cartesian mesh, first-order H1 elements, and sparse LU. It checks
that there are free degrees of freedom and that the solution values are finite.
It does not test an analytical error, convergence order, or device observable.

## Observed run

Both the implementation run and the independent root rerun exited with code 0
on 2026-09-05 and printed:

```text
julia_version=1.10.5
gridap_version=0.20.8
platform=x86_64-w64-mingw32
mesh_cells=16
free_dofs=9
solution_norm=0.17280419053167115
GRIDAP_POISSON_OK
```

The norm is a recorded output, not an accuracy criterion. The root rerun used
the identical script bytes under the development name `poisson_smoke.jl`;
the published `smoke.jl` is a byte-for-byte copy. Installation, instantiation,
and a second lockfile replay also completed successfully in the isolated
development environment.

## Source and byte identities

Gridap 0.20.8 declares Julia compatibility `1.10` in its
[versioned Project.toml](https://github.com/gridap/Gridap.jl/blob/v0.20.8/Project.toml)
and uses the [MIT license](https://github.com/gridap/Gridap.jl/blob/v0.20.8/LICENSE.md).
The example follows the weak-form setup described in the
[official Poisson tutorial](https://gridap.github.io/Tutorials/dev/pages/t001_poisson/).

The locked Gridap source tree is
`95fd6ec47697c8f031398434a119abe747330715`, with package UUID
`56d4f2e9-7ea1-5844-9cf6-b9c51ca7ce8e`.

| Observed file | SHA-256 of tested raw bytes |
|---|---|
| `Project.toml` | `223FB6C8EA33F03989CCB4D76ED80016A3BC2799BC4210490C4E43CC7AFFCEB6` |
| `Manifest.toml` | `2E1D103396D3F3FAA13687BD4A95FDE287D1F94E8B0006046B65E1E29AA3765A` |
| `smoke.jl` | `FD972E10009CF9F2A3D43389C5E0485B7DE42B6768BB399CDC78F6D1600528BC` |
| Installed Gridap `Project.toml` | `3B18F85DB162689BDB1CA13EF293D0863F3C8E4EE223AEA00CD14F3C3396728B` |
| Installed Gridap `LICENSE.md` | `7FC0027FBA37593E20020A1EC558EC90671CBFE497AAC6F1D8E19F759F7BC150` |

Git checkout line-ending conversion can change raw-byte hashes. Preserve the
tested bytes when comparing these fingerprints, and record checkout bytes and
parsed dependency identity separately if line endings differ.

The candidate-bound, three-dimensional weak-form adapter and its independent
numerical comparison remain subsequent implementation work described in
[`fd_to_integrated_vvuq_path.md`](../../../docs/implementation/fd_to_integrated_vvuq_path.md).
