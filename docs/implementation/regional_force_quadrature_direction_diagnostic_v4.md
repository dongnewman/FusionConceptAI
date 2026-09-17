# Directional quadrature diagnostic

This candidate-bound screen reuses the accepted q4 full-chain result as the
single shared `(radial_order=4, angular_order=4)` baseline. It runs fresh DESC
field/basis providers only for `(2,4)`, `(3,4)`, `(4,2)`, and `(4,3)`. The
radial sequence compares `(2,4) -> (3,4) -> shared (4,4)`; the angular sequence
compares `(4,2) -> (4,3) -> shared (4,4)`. Provider requests, results, and
receipts are candidate-bound and validated before force integration.

The contract recomputes all four labeled differences during canonical
validation. It is diagnostic-only, screen-only, and grants zero evidence. No
anisotropic convergence, formulation independence, physical closure, or
promotion authority is inferred.
