# Runtime V4 candidate-bound local ideal-MHD interface traction

## Decision

This edge binds the accepted sampled rho-surface geometry to a new real DESC
field-provider request evaluated at the exact same `c-epsilon` and `c+epsilon`
points.  The second request supplies pressure in Pa and independently repeats B
in DESC's native physical R-phi-Z basis.  The executor converts that B to the
laboratory Cartesian basis and requires it to match the rho-surface provider's
sealed B before evaluating any constitutive quantity.

The edge deliberately does not reinterpret DESC `F` as pressure, current, or
traction.  DESC `F` is a volumetric force-balance residual in N/m^3; traction is
an interface quantity in Pa.

## Frozen constitutive convention

The implementation uses the static (`v=0`) ideal-MHD momentum-flux tensor

```text
M = (p + |B|^2/(2 mu0)) I - (B tensor B)/mu0
t(n) = M n
```

with `B` in T, `p` and `t` in Pa, and the 2022 CODATA central value
`mu0 = 1.25663706127e-6 N A^-2`.  The numeric value, unit, and source label are
sealed into the request.  This is the conservative momentum-flux sign, not the
opposite-sign Cauchy stress convention.

For each structural interface, the minus normal is the sampled increasing-rho
unit normal and the plus normal is its opposite.  The one-sided traction jump
diagnostic is `t_minus + t_plus`.  A central oriented traction is
`0.5*(t_minus-t_plus)` and is assembled as equal-and-opposite contributions.

## Identity and replay boundary

The request seals the current context/candidate, geometry bridge/evaluation/
proof, DESC execution request/result/receipt and HDF5, field-basis bridge,
partition request/result/receipt, rho-surface request/result/receipt, exact
pressure-field request/result/receipt, interface/region support hashes,
surface/state/point hashes, quadrature semantics, conventions, source file,
and Julia executable.  The validator reconstructs the request and recomputes
every traction and flux from the sealed upstream values.

The prerequisite field-provider receipt validator now independently recomputes
its process hash, closing a re-sealed forged-process receipt gap before this
edge consumes that receipt.

## Authority ceiling

`interface_flux_executed=true` means a real candidate-bound local constitutive
evaluation and paired central flux were computed.  Equal-and-opposite central
assembly is algebraic and does not establish a physical jump condition.
The `c±epsilon` states are explicitly finite-offset proxies, not independently
established boundary limits.

Therefore `jump_conditions_validated`, regional residual/Jacobian execution,
solver convergence, multi-region closure, physical/engineering validation,
evidence, pass, promotion, P5, terminal authority, and credible-device count
remain false/zero.  The claim ceiling remains `screen_only`.

## Next required slice

The next multi-region slice must define typed region PDE residual ownership and
an independently checked interface jump protocol.  It must add the other MHD
conditions required by its declared model (including normal magnetic-field and,
where applicable, mass, energy, and tangential-electric-field conditions), plus
Jacobian verification and global conservation accounting.  Central pair
cancellation cannot promote any of those gates.
