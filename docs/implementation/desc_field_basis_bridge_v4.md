# DESC field basis bridge v4

DESC evaluates at flux coordinates `(rho, theta, zeta)`, but the three values
returned for `B` and force-balance error `F` are embedded physical-vector
components in DESC's orthonormal cylindrical `(R, phi, Z)` basis. They are not
covariant or contravariant flux-coordinate components. The bridge records that
distinction explicitly and requests `R`, laboratory `phi`, `Z`, `B`, `F`, and
`sqrt(g)` from a fresh DESC 0.17.3 process at the exact upstream sample points.
Its typed request also binds and reconstructs the accepted geometry-
compatibility resolution/certificate, compiled prefix, physical subject,
physical declaration, support, chart, graph binding, coordinate/metric
programs, and geometry payload before it assigns flux-coordinate meaning to
those points.

The adapter checks DESC's own quantity metadata and shapes. Julia cross-checks
the fresh `B`, `F`, and `sqrt(g)` values against the sealed field-provider
result, then applies, point by point,

    x = R cos(phi), y = R sin(phi), z = Z
    Vx = VR cos(phi) - Vphi sin(phi)
    Vy = VR sin(phi) + Vphi cos(phi), Vz = VZ

for both vectors. Typed samples retain both bases and verify the Cartesian
transform and norm preservation. The request, output, adapter, upstream HDF5,
Python executable, and DESC module are content-addressed and replay-checked.
Receipt validation recomputes the process hash and independently checks the
output envelope before result-level replay compares every sample with the
upstream field result.

The bridge excludes `rho=0`, where the cylindrical/flux-coordinate chart is
singular. It remains `screen_only`: it supplies no region partition, interface
trace or normal, constitutive/material law, solver-convergence evidence,
multi-region closure, validation evidence, or device authority.
