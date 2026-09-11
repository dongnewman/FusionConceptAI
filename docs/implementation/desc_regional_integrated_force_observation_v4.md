# DESC regional integrated-force observation V4

## Accepted scope

This slice adds a candidate-bound, real-DESC volume observation for every
declared normalized-rho region. It deliberately does not call the quantity a
regional residual. No test function, integration by parts, boundary term,
interface-jump ledger, trial/state degree of freedom, or residual Jacobian is
present.

Each region owns an explicit `2 x 2 x 2` tensor rule:

- two interior Gauss-Legendre nodes in normalized rho;
- two half-open midpoint cells over theta in `[0, 2pi)`;
- two half-open midpoint cells over one zeta field period
  `[0, 2pi/NFP)`;
- full-torus weight `w_rho * w_theta * w_zeta * NFP`, with `NFP` applied
  exactly once.

The accepted DESC field provider executes at all nodes and seals the request,
HDF5, adapter, Python, DESC module and output identities. The accepted basis
bridge separately reopens the same HDF5, checks quantity metadata, maps DESC's
orthonormal cylindrical `F` components into laboratory Cartesian components,
and seals its own replayable receipt. The observation then computes

```text
integrated_force_region = sum(F_xyz * sqrt(g) * full_torus_weight)
```

in newtons. Every node carries its `region_id`, region/support hashes, local
tensor index, point hash, separate quadrature factors and full-torus weight.
The observation receipt seals a canonical TSV. Its validator revalidates the
entire current geometry/execution/partition/surface/pressure/traction chain,
reparses both real-provider outputs and the observation TSV, reconstructs all
nodes, and recomputes every regional and total force.

## Evidence boundary

This is a measured quadrature observation of the already nonzero DESC
`F = J x B - grad(p)` field. It is `screen_only`. The following remain false:
test-function application, boundary terms, weak-form assembly, regional
residual/Jacobian execution, global conservation validation, solver
convergence, multi-region closure, physical/engineering validation, evidence,
promotion, P5 readiness and terminal authority. Credible device count remains
zero.

Reproduce with:

```text
julia --project=. test/runtime_v4_desc_regional_integrated_force_observation_tests.jl
julia --project=. scripts/run_v4_desc_regional_integrated_force_observation.jl
```
