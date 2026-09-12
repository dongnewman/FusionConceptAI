# N2 source Fourier-Zernike scalar reconstruction

`N2SourceFourierZernikeV4.jl` is an isolated screen-only Julia slice. It reads
the frozen selected-member interior result, checks exact result and HDF5 byte
hashes, recomputes SHA-256 over the original Python canonical subject wire,
requires wire/JSON structural equality and the external-simulation authority
ceiling, and materializes all 598 R plus 585 Z `(l,m,n,coefficient_m)` source
terms as immutable typed tuples.

Its Jacobi recurrence evaluates the DESC Fourier-Zernike radial basis without
mistaking `l` for a monomial power. Positive angular modes use cosine and
negative modes sine; toroidal harmonics use NFP 19 and physical radians. At
the five frozen nodes, Julia R/Z agrees with the sealed DESC comparison values
within `1e-9 m`; focused tests pass 16/16 and 5/5.

This is a scalar R/Z reconstruction only. The routine is not registered as a
G2 typed coordinate/metric AST or operator-hyperedge, has no derivative or
metric proof, does not select or execute DESC as a provider, and does not
solve an independent equilibrium. The existing interpreter's NFP 2–8,
single-power and orientation gates remain intact. It grants no inverse,
held-out, physical-validation, engineering, or credible-device authority.
