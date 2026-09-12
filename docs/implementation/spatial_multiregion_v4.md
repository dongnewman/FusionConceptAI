# Spatial multiregion static-MHD execution

This implementation replaces four reference-field amplitudes with independent
nodal `(B_R,B_phi,B_Z,p)` fields. It implements the declared static equations
`div(T)=0`, `div(B)=0`, with
`T=BB'/mu0-(p+|B|²/(2mu0))I`, on a fixed freshly executed DESC geometry.
It is not a transport, time-dependent plasma, exterior vacuum or general
heterogeneous-material solver. Pressure/iota are initialization data; no
reference-profile anchor supplies unprovided equilibrium closure.

The G2 declaration includes both spaces, a prescribed exterior reference
traction, zero exterior normal magnetic field, explicit zero body source, and
nominal/endpoint toroidal flux. The Wb interval is a deterministic exploratory
design interval, not a probability distribution. Mu0 is the fixed CODATA 2022
nominal. B/p numerical scales have explicit units, fixed computational intervals,
sources and applicability; they are not measured plasma parameters.

## Space, ownership and exact geometry

Coarse uses rho=(0,.5,1), theta=4 and zeta=2*NFP. Fine uses
rho=(0,.25,.5,.75,1), theta=8 and zeta=4*NFP. The full torus has independent
unknowns in every field period, with only the actual 2pi periodic identification.
For NFP=5 there are respectively 90/660 nodes, 360/2640 unknowns and 80/640
cells. Axis poloidal nodes are merged in both trial and local test spaces.
Axis cells have six local basis functions; other cells have eight. Each test
has three Cartesian momentum and one scalar divergence equation. Four Q1
trace tests on every exterior face add traction and normal-field equations;
the toroidal-flux cut adds one row. Total rows are 2881/21761.

Corner order is rho-fast: k=br+2*bt+4*bz, with br/bt/bz in {0,1}. Merged local
nodes follow first corner occurrence. Node/cell order is zeta outer, rho middle,
theta inner. Node state order is BR,Bphi,BZ,p. Residual order is cell-local
test (momentum_x,y,z,divB), then exterior-local test (traction_x,y,z,Bn),
then total flux. Complete structural row supports are stored independently of
numeric nonzeros, allowing every Jacobian column to be checked.

The sampler reads the new candidate's bound HDF5. It samples actual node
initializers, 3³ volume quadrature and 3² unique-face quadrature. Nodes at the
axis are exact and their singular metric is not inverted. Volume points lie
strictly inside cells. Rho=.5/1 faces are exact; no finite offsets approximate
their limits. The covariant matrix E is in physical cylindrical components,
with actual inverse, signed determinant, laboratory angle, position and SI
weights. Negative determinant is valid; dV uses its absolute value. Face normals
point along the positive chart direction; left/right cells use opposite signs.
Internal material faces share the same continuous plasma state, so no internal
sheet is prescribed. This is an explicit physical restriction.

All source cells/faces are enumerated. A cut is axis=3 and fixed_zeta=0.
Periodic seam tests use the same global nodes. A zero-measure axis contributes
no artificial inner boundary or finite-radius hole.

## Current-field calculus and residual

For current physical cylindrical B components, H[:,a] is the parametric
component derivative plus `E[2,a]/R*(-Bphi,BR,0)`. The Cartesian-invariant
physical gradient is `G=H*E^-1`; divB is its trace and curlB is its antisymmetric
part. J is curlB/mu0, and gradp is transformed from the current nodal pressure.
DESC J/gradp are never production inputs.

The cell residual is `-integral(T*grad(N))+integral_faces(N*t)
-integral(N*source)`. Interior flux is the actual shared trace, with opposite
orientations. Exterior cell flux uses prescribed reference traction and Bn=0;
separate exterior moment rows enforce current trace minus those prescribed
values. The independent MMS-only callbacks specify a source for divT=source,
traction and Bn; production uses the candidate declarations.

Every nodal column has an analytic stress directional derivative and divergence
derivative assembled into a sparse matrix. Momentum/traction rows remain N;
div/normal-flux/total-flux rows remain Wb. The solver combines only dimensionless
rows, using actual cell volume^(2/3) or face area times declared SI scales.
There is no raw mixed-unit norm. Diagnostics distinguish `J cross B-gradp`
from `divT`, which additionally contains `B divB/mu0` until divergence converges.

## Actual nonlinear attempt and rank

The four declared cases execute sequentially: nominal_coarse, nominal_fine,
flux_low_coarse and flux_high_coarse. Each starts from the actual fresh nodal
DESC field and solves its own target flux. Coarse has 12 iterations/600 seconds;
fine has four iterations/900 seconds, checked between iterations. Individual
assembly/factorization calls are not forcibly interrupted.

The method is sparse unregularized QR Gauss-Newton with nonnegative pressure,
active pressure constraints, feasible line search and an actual projected
descent fallback when a QR step is infeasible or not descent. It does not clip
an infeasible Newton step into an unchanged state. State scaling affects
conditioning only. No epsilon identity or initial-state penalty changes the
physical equations. Sparse QR rank estimates include their scaled threshold;
derived null directions are tested against the unregularized matrix. These
numerical diagnostics do not prove continuum uniqueness or provide missing
pressure/current-topology closure. The fine Jacobian is never densified.

Exit codes: 0 all declared scaled rows converge; 2 stationary nonzero residual;
3 feasible line search fails; 4 iteration/time budget; 5 sparse QR failure;
6 nonfinite or infeasible state. Every accepted full state and separate raw
block norm is retained. Algebraic success still cannot certify the missing
physical/exterior closure or physical validation.

`solver_attempts.json` records every actual linear/line-search attempt, including
the terminal failed attempt that has no following accepted-state history row.
It retains the error phase/text, QR and searched-direction linear residuals,
proposed scaled step, each line-search trial and exact attempted/accepted counts.
Nonfinite diagnostic values are represented explicitly with missing numeric
values and nonfinite-column flags, not serialized as invalid JSON numbers.
The final rank audit is separate and cannot overwrite a failed solver attempt.
Admission checks count consistency and replays accepted step arithmetic against
the stored initial/intermediate/final state history. A zero-update failure or
budget stop remains a zero-update result.

## Engineering artifacts and admission

Exact shared CSV schemas contain current J=curl(B), B, pressure/gradient,
divB, dV, both interface B traces, derived K=n cross (Bplus-Bminus)/mu0,
normal current traces, and actual outer B/J/p/n/dA. The outer magnetic trace on
the other side and outer sheet current remain unknown. Current closure records
cell fluxes, interface normal jumps and outer current; it does not infer a
complete return path from a small net surface integral.

The actual DESC R expansion also has a continuous radial enclosure artifact.
For the audited FourierZernikeBasis, each radial polynomial is bounded by the
sum of its exact integer monomial-coefficient magnitudes on rho in [0,1].
Multiplying by absolute stored R_lmn and summing with exact rational arithmetic,
then rounding upward, bounds R at every angle/radius. Julia independently
recomputes that coefficient bound. This is not sampled enclosure. Engineering
compares it with its declared candidate bound and must propagate a failed or
unsupported continuous-clearance condition without moving the declared pickup.

Admission revalidates candidate/declaration and raw/source bytes, reconstructs
mesh/basis ownership, checks initial DESC nodal state, state-history endpoints,
all final residual/Jacobian entries and row supports, and reproduces every
current CSV from the final state. It also recomputes engineering identity,
current closure and validity. Upstream physical validity remains false.

## Legacy reuse audit before implementation

| Source | Decision | Reason |
|---|---|---|
| Legacy candidate_residual_graph_runtime_v68.jl:538/557 | extract | Explicit state/row ownership and sparse block scatter; rebuilt current G2 fields and actual input binding. |
| v68 square GMRES and homotopy | reject | Rectangular spatial least-squares system needs sparse QR; u-u_initial homotopy cannot silently become pressure/current closure. |
| v68:898 independent_r | test-only | Calls the same assembler and is not independent formulation. |
| Legacy multiregion_nonlinear_runtime_v90.jl:357 | test-only | All-column finite differences are useful derivative checks; not the production Jacobian. |
| v90 physical inventories and role-string routing | reject | Scalar reduced inventories and name-selected roles are not spatial MHD fields. |
| Current GridapFieldResidualAdapter.jl:635-650 | extract/test-only | Local FE assembly and sparse matrix evidence ideas; its Cartesian diagonal-affine scalar qualification does not cover the real DESC chart. |
| Four-state CompleteMultiRegionV4.jl | extract/reject | SI stress and artifact replay ideas retained; fixed B/J amplitude ansatz and clipped Newton are rejected for this field solve. |
| DESC basis.py:1317-1325 | wrap initialization geometry only | Actual covariant geometry and Fourier-Zernike definition; no inherited physics qualification. |

No old authority, family routing, default registry changes or previous-candidate
receipts are imported. Synthetic torus/field inputs exist only in focused tests.

## Reproduction

After promotion, the focused command is
`julia --project=. test/runtime_v4_spatial_multiregion_tests.jl`.
The unified main-owned runner calls
`execute_spatial_multiregion_v4(context,upstream,run_dir)`.
It writes geometry/request/metadata, sampler stdout/stderr/exit, and per-case
state history, full Jacobian, row supports, residual rows, iterations, current
CSVs, complete solver attempts and explicit solver exit. Source/environment/HDF5/input/output hashes bind
these outputs. Heavy execution belongs exclusively to the main queue.
