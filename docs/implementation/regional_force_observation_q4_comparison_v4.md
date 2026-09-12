# Regional force q=4 comparison

This candidate-bound edge validates the complete real q2/q3 execution chain,
then creates 4 x 4 x 4 quadrature nodes for every declared rho region. Radial
coordinates and weights are the four-point Gauss-Legendre rule; theta and zeta
use four midpoint samples, with NFP included exactly once in the integration
weight. The node list is reconstructed from sealed partition IDs, support
hashes, rho bounds, and NFP during canonical validation.

The q4 field and basis values are not placeholders. A fresh DESC field-provider
process samples all q4 points, the bound basis bridge maps the returned force
density to Cartesian coordinates, and the executor integrates
`F_cartesian_xyz_N_m3 * sqrt_g_m3 * weight` per region. Typed request, result,
receipt, runtime, source, and output-artifact hashes are retained and can be
revalidated against the full chain.

The standalone canonical hashes prove internal immutability. Upstream
partition and q3 identities are authoritative only after
`validate_regional_force_q4_execution` validates the complete typed chain;
callers must not interpret `canonical_hash(comparison)` alone as an upstream
provenance proof.

The declared convergence protocol records q2-to-q3 and q3-to-q4 differences.
It returns `pass` only when the latest pair meets the absolute OR relative
tolerance and its absolute difference is smaller than the preceding pair.
This is a same-code quadrature-convergence screen. Even a pass supplies no
independent-code validation, physical validation, UQ, promotion, terminal, or
credible-device authority.
