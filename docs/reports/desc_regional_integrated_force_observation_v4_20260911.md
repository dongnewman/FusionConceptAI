# DESC regional integrated-force observation V4 report

The implementation executes the accepted DESC field and Cartesian basis
providers on 8 explicitly owned nodes per declared rho region. The tensor rule
uses two interior radial Gauss nodes, two theta midpoints, and two midpoints in
one zeta field period. Each contribution is exactly
`F_xyz * sqrt(g) * w_rho * w_theta * w_zeta * NFP`, in newtons.

The request binds the complete current context, candidate, DESC execution,
partition, surface, pressure, traction and runtime receipt identities. The
result and observation receipt bind the newly executed field/basis requests,
results, receipts and canonical TSV output. Full validation reparses all three
outputs and independently recomputes node, region and total observations.

Measured current-fixture observations from the standalone real-chain run:

| region | quadrature volume (m3) | integrated force xyz (N) | norm (N) |
|---|---:|---|---:|
| `rho_inner` | 9.75409148189908 | (-168016.171771343, -122070.894184535, 1.35332811623812e-9) | 207679.409628662 |
| `rho_outer` | 7.59561458263692 | (-108815.366607149, -79058.9915405887, 1.02591002359986e-9) | 134503.190122997 |

The observed total-force norm is `342182.59975165897 N`. This large nonzero
quantity is reported as measured non-closure at this quadrature depth; it is
not converted into a pass/fail equilibrium or global-conservation claim.

Verification completed with explicit exit 0:

- focused test: 122/122, including foreign region/support, rho-axis and
  rehashed sealed-TSV tamper rejection;
- standalone runner: field provider exit 0, basis provider exit 0, final
  `DESC_REGIONAL_INTEGRATED_FORCE_OBSERVATION_RUN_EXIT_CODE=0`;
- upstream ideal-MHD traction regression: 62/62, exit 0.

This milestone is intentionally not named a residual. It provides no test
function, boundary term, weak form, Jacobian, conservation proof, convergence,
multi-region closure, validation evidence or device authority. All such flags
remain false, the claim ceiling is `screen_only`, and credible device count is
zero.
