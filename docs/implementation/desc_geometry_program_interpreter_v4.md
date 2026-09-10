# DESC geometry program interpreter v4

This isolated RuntimeV4 edge executes a candidate-owned Fourier program in
the normalized turn chart `(rho, theta, zeta)`. The fixed-boundary
coefficients alone define only `rho=1`; therefore every radial and vertical
mode carries an explicit candidate-owned radial power rather than silently
inferring an interior extension. Fourier phases use
`2pi*(m*theta-n*zeta)`, with `zeta` measured in field-period turns.  The
Cartesian coordinate is `x = L*xhat`, where `L` is the immutable support
resolution-independent scale. The toroidal azimuth is
`phi=2pi*zeta/NFP`. The analytic Jacobian is differentiated in the same
convention and the metric is `g = L^2 Jhat'Jhat = J'J`.

The interpreter performs finite/domain checks, canonical signed-zero
normalization, and exposes immutable payload hashes. Typed AST and
`AtomicMIMOHyperedgeV1` bindings are supplied for structural ownership, while
the executable semantics remain candidate-owned. A dedicated additive
registry contributes four exact manifests (normalized coordinate, normalized
metric, coordinate scaling, and metric scaling); `default_operator_registry`
is never modified. The sealed evaluation remains bound to the exact candidate,
compiled prefix, physical subject, scenario context, declaration, graph roots,
bridge result, programs, and payload. This is screen-only software evidence:
no DESC request,
provider, proof, certificate, or physical/evidence claim is emitted.
