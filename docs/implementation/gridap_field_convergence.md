# Gridap B2 convergence layer

B2 is an additive convergence layer over the candidate-bound B1 compilation.
It rederives and executes real G2 reports independently at 5, 9, and 17
nodes per axis, then records physical-domain solution L2 and H1-seminorm
errors, chart cell-centre source RMS, chart face-centre boundary L-infinity,
residual, cells/DOFs, runtime, and memory metrics.

Only finite nested refinement series with the same candidate, prefix, mission,
scenario, form, affine geometry, typed programs/roots, adapter protocol,
dependency lock, and source identities are accepted. Each exact G2 u/f plan
must match the corresponding B1 plan hash. The B2 reassembly must exactly
reproduce B1's matrix, right-hand side, and free DOF values before its FE
function is used for the volume norms. Manufactured control is test-only: the receipt is permanently
`screen_only`; no physical, engineering, VVUQ, or promotion claim follows.
The preregistered Q1 bands are L2 [1.5,2.5] and H1 [0.7,1.3]: Q1 value
errors are second order while energy/H1 errors are first order.

Runtime and memory are observations excluded from deterministic case identity.
The chart RMS/L-infinity transfer diagnostics are intentionally not described
as physical-domain norms.
