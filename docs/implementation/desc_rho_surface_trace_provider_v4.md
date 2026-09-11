# DESC rho-surface trace provider V4

## Purpose

`DESCRhoSurfaceTraceProviderV4` is the first real provider downstream of the
accepted `DESCRhoPartitionTraceContractV4` structural specification. It loads
the candidate-bound DESC equilibrium HDF5 in a fresh Python process and samples
every declared interface point at the surface and on both adjacent sides.

This edge closes the gap between a declared rho partition and actual DESC
geometry/field evaluation. It deliberately does not solve a conservative
interface law or claim whole-domain geometric proof.

## Trusted input chain

The request accepts the complete trusted-module chain:

1. forward-chain context and normalized physical-root geometry bridge;
2. DESC geometry evaluation and compatibility certificate;
3. DESC execution request/result/receipt and sealed HDF5 identity;
4. field-provider and Cartesian basis-bridge request/results;
5. structural rho-partition request/result/receipt.

All thirteen upstream objects must have the exact concrete types owned by the
context's module. The structural partition result is replay-validated before a
provider request can be created. The provider request seals context, candidate,
execution, HDF5, physical support, region, interface, trace-specification and
`NFP` identities.

## Real DESC evaluation

For an interface `rho=c` and declared angular sample `(theta,zeta)`, the trusted
adapter constructs three `Grid(..., coordinates="rtz", sort=False)` points:

- surface: `(c, theta, zeta)`;
- minus trace: `(c-epsilon, theta, zeta)` strictly inside the lower-rho region;
- plus trace: `(c+epsilon, theta, zeta)` strictly inside the higher-rho region.

It computes the following DESC 0.17.3 quantities:

`rho`, `theta`, `zeta`, `R`, `phi`, `Z`, `grad(rho)`, `n_rho`, `e_theta`,
`e_zeta`, `B`, `F`, and `sqrt(g)`.

The adapter verifies exact `data_index` units, dimensions and coordinate
dependencies before evaluation. Returned `rho/theta/zeta` values are checked
against every requested point; output order therefore cannot silently drift.
The half-open angular domain excludes duplicated periodic seams, and ordinary
surface sampling never reaches the coordinate-singular magnetic axis.

DESC returns these physical vectors in the embedded orthonormal cylindrical
`(R,phi,Z)` basis. The Julia edge explicitly maps them into laboratory
Cartesian components using the provider-returned laboratory `phi`. It never
treats DESC's generic `x` coordinate triplet as a Cartesian position.

At the surface and both epsilon traces, the validator independently checks:

- `n_rho` is unit length and aligned with normalized `grad(rho)`;
- `n_rho` is orthogonal to `e_theta` and `e_zeta` within tolerance;
- all scalar/vector values are finite and `sqrt(g)>0`.

The interface outward normal for the lower-rho region is the computed surface
`+n_rho`; the outward normal for the higher-rho region is its negative. The
structural contract's previously declared normals remain untrusted and are not
reported as cross-checked.

## Process and replay identity

The receipt seals the exact input, output, adapter, upstream HDF5, Python
executable and imported DESC module. The validator:

- recomputes the process hash from the receipt body;
- requires the adapter hash to equal the built-in trusted source;
- requires the adapter process to prove `desc.__file__` equals the sealed DESC
  module path;
- reconnects HDF5/Python/DESC paths and hashes to the upstream execution
  receipt;
- reconstructs the exact command and canonical request TSV;
- parses the output with strict header order, width, count and schema checks;
- reconstructs every typed sample and compares it with the result.

Replay reruns the same fresh-process provider and requires an identical typed
semantic view and result hash.

## Authority boundary

The provider may set these sampled facts to true:

- `provider_selected`, `provider_executed`, `output_schema_validated`;
- `surface_geometry_sampled`, `normal_geometry_validated`;
- `tangent_geometry_validated`, `two_sided_trace_executed`;
- `region_ownership_validated` for the two strict epsilon samples.

It must keep these facts false:

- `declared_normals_cross_checked`;
- `spatial_partition_geometry_validated` (no global coverage/injectivity proof);
- `interface_flux_executed` and `multiregion_closure`;
- solver convergence, physical validation and engineering validation;
- evidence, pass, promotion, P5 and terminal authority.

The claim ceiling is `screen_only`, and credible physical device count remains
zero. A downstream conservative-flux edge must add candidate-derived
constitutive laws, typed residual/Jacobian ownership and flux-balance checks;
it cannot reinterpret two-sided field sampling as multi-region closure.
