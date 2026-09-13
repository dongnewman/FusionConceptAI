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

The W21 binding revision also requires the normalized boundary's field-period
count and L/M/N resolution to match the selected source interior. A separate
`validate_member_join.py` uses raw `h5py` access, not DESC's loader, to check
that both derived subjects come from HDF5 member 3 of 4. It compares every
stored interior R/Z mode and coefficient, the stored boundary and the
`rho=1` aggregation of the full interior over all `(m,n)` modes, plus pressure,
iota, flux, basis convention and embedded producer. The maximum raw-boundary
discrepancy was `5.3291e-15 m`, below its explicit `7.1787e-14 m` numerical
join tolerance. This is a source-integrity check, not independent physics or
a rigorous global geometry proof. Its receipt is not a general admission
certificate; a downstream consumer must revalidate the raw inputs and code.
The member-join r1/r2 receipts are retained as historical validator revisions;
r3 is the current receipt with the authority guard and explicit
`physical_validation=unsupported` status.

`rho=0` is a provably singular polar-coordinate axis for this chart:
every non-axis poloidal term vanishes there and the poloidal Jacobian column
is zero. A positive nondegeneracy claim on the closed chart would be false;
any later proof must use an off-axis domain plus an axis-regular chart/atlas.
Sampled off-axis determinants are diagnostics, not such a proof.

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
evaluation revalidation. W21 r3 is historical after the axis-gap wording
changed; r4 binds the v2 candidate contract with explicit source-period and
resolution agreement. None is a physics acceptance result.
