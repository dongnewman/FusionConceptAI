# N2 source Fourier-Zernike scalar reconstruction

`N2SourceFourierZernikeV4.jl` is an isolated screen-only Julia slice. It reads
the frozen selected-member interior result, checks exact result and HDF5 byte
hashes, joins the adjacent manifest's official-distribution provenance,
recomputes SHA-256 over the original Python canonical subject wire,
requires wire/JSON structural equality and the external-simulation authority
ceiling, and materializes all 598 R plus 585 Z `(l,m,n,coefficient_m)` source
terms as immutable typed tuples.

Its Jacobi recurrence evaluates the DESC Fourier-Zernike radial basis without
mistaking `l` for a monomial power. Positive angular modes use cosine and
negative modes sine; toroidal harmonics use NFP 19 and physical radians. At
the five frozen nodes, Julia R/Z agrees with the sealed DESC comparison values
within `1e-9 m`; focused tests pass 16/16 and 5/5.

The additive analytic first-derivative path uses the Jacobi derivative identity
and the signed Fourier phase derivatives in `(rho, theta, zeta)` order. It
constructs a Cartesian Gram matrix from the geometry chart. Its five frozen
nodes are compared to a separate DESC selected-member derivative receipt with
predeclared absolute `1e-8 m` derivative and `1e-7 m^2` Gram gates. This is a
same-source basis-convention numerical check, not a whole-domain nondegeneracy,
orientation, or metric-positivity certificate. The axis node is particularly
unsuited to asserting a nonsingular coordinate chart.

`scripts/compare_n2_source_derivatives.jl` pins the complete DESC receipt,
source/manifest and normalized subject hashes, enforces the derivative order
and screen-only authority, and refuses an existing output path. Its five-node
run exited 0, with maximum absolute R/Z derivative error
`5.77405e-12 m` and Gram-entry error `4.53895e-11 m^2`, under the frozen
tolerances. The focused Julia suite passed 16/16, 40/40, and 8/8; adjacent
boundary/profile binding passed 11/11 and 9/9. This is a fixed benchmark
receipt, not a general trusted derivative-receipt loader; any downstream
consumer needs its own typed attestation and chart admissibility checks.

The routine is not registered as a G2 typed coordinate/metric AST or
operator-hyperedge, does not select or execute DESC as a provider, and does not
solve an independent equilibrium. The existing interpreter's NFP 2–8,
single-power and orientation gates remain intact. It grants no inverse,
held-out, physical-validation, engineering, or credible-device authority.
