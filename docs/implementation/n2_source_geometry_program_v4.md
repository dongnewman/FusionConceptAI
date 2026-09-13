# Source-owned N2 Fourier-Zernike G2 program

The isolated `N2SourceGeometryProgramV4.jl` uses the selected HELIOTRON
member's complete 598 R and 585 Z Fourier-Zernike terms without mapping its
radial degree to a monomial power. The payload binds the HDF5, normalized
interior result and canonical subject hashes, evaluator/program code hashes,
Fringe radial formula, Fourier sign/phase convention, NFP 19, and positive SI
support scale. It creates two genuine typed AST programs and
`AtomicMIMOHyperedgeV1` coordinate/metric edges in a candidate-local operator
registry. `default_operator_registry()` and the older single-power DESC
interpreter remain unchanged.

The input is a typed `(rho, poloidal turn, field-period turn)` chart value.
The source spectrum is evaluated in physical radians; derivatives are converted
with `d theta/d turn = 2π` and `d zeta/d period_turn = 2π/NFP`. The normalized
roots give Cartesian coordinates and `JᵀJ` divided by `L` and `L²`; the second
roots explicitly restore SI coordinates/metric. Five frozen nodes are checked
against the earlier same-source DESC derivative receipt, with separate
single-mode analytic sign/radial-law controls. This is basis/ABI numerical
verification, not a global chart or physical-equilibrium proof.

`N2SourceGeometryCandidateBindingV4.jl` joins the exact spectrum, normalized
boundary/pressure/iota/flux reference, two-root G2 graph, context and
structural normalized-to-SI bridge. It rereads and rehashes both source
artifacts, checks that boundary and interior select the same HDF5 member, and
requires exact local manifests, root sites and graph bindings. Candidate
evaluation repeats that join; an internally self-consistent forged binding
with a wrong reference hash is rejected. The example and runner are explicitly
source-backed candidate fixtures; no device label is used to grant a solver or
gate privilege.

`bridge_ready` here means structural linkage only. The current general DESC
preflight/compatibility proof still does not admit NFP 19, L24 and this full
radial basis; continuous chart orientation/nondegeneracy, an actual same-subject
equilibrium provider reexecution, independent spatial comparison, inverse
recovery and physical validation remain unresolved. The old boundary/profile
binding retains its original local recoverable-gap record; this additive
candidate binding closes the source AST/linkage subset without changing that
older record or promoting its authority. Every output remains `screen_only`,
`geometry_proved=false`, `provider_executed=false`,
`physical_validation=unsupported`, and credible count zero.

The initial `n2_source_geometry_candidate_r1` receipt preceded the adversarial
identity review and is retained only as historical execution. The r2 receipt
binds the revised source-evaluator/program code identity and full candidate
evaluation revalidation; neither is a physics acceptance result.
