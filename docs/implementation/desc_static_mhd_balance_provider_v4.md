# DESC static-MHD balance provider V4

This candidate-bound provider launches the sealed DESC 0.17.3 environment
against the accepted equilibrium HDF5 and samples `B`, `J`, `grad(p)`, and
DESC `F` at the exact two-sided rho-interface points. The adapter checks DESC
quantity metadata, module path, point count, finite vector shapes, and emits
version/NFP/coordinate-framed output.

The request binds context, candidate, surface-result hash, ordered surface
positions, traction request/result hashes, pressure-result hash, DESC version,
NFP, and exact sample points. The receipt seals the canonical command, adapter,
request/output, upstream HDF5, Python executable, and DESC module hashes.
Validation reparses the sealed output instead of trusting the in-memory result.

Native `rtz` vectors are rotated into Cartesian coordinates using each sealed
surface position. Native `B` and DESC `F` must first equal the independently
sealed pressure-trace values at the same points. Cartesian DESC `F` must then
agree componentwise with `J x B - grad(p)` under frozen `1e-8 N m^-3`
absolute and `1e-8` relative tolerances.

Legacy material is extract/wrap/test-only/reject: stable compute-key metadata
may be extracted; hashing and replay are wrapped; manufactured multi-region
tests are test-only; generic material, old Genome routing and authority are
rejected. This is a two-point sampled force balance, not regional
volume/source/boundary assembly, a regional/global Jacobian, convergence,
interface closure, validation, evidence, promotion, P5, terminal, or device
authority. All such flags remain false under `screen_only`.
