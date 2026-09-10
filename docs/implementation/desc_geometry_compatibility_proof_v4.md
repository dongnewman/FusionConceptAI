# DESC geometry compatibility proof v4

This RuntimeV4 edge proves the admitted Fourier geometry program without
turning a finite grid into a global claim. It consumes the exact
`ForwardChainContextV4`, normalized/SI root-bridge resolution, and sealed
interpreter evaluation, then reconstructs the candidate-owned program and all
of its graph, subject, declaration, root, manifest, and payload identities.

The current analytic prover intentionally admits a narrow regular family. The
axis is one positive `R00` term. Every non-axis radial and vertical term has
`|m|=1` and explicit radial power one. One positive `n=0` cosine radial mode
and one consistently oriented `n=0` sine vertical mode define the base minor
cross-section; remaining toroidal modes are treated as bounded perturbations.
Programs outside this family remain `recoverable_gap`, not rejected devices.

For normalized cylindrical functions `R=R00+rho*r` and `Z=rho*z`, the
Cartesian Jacobian satisfies

`-det(J)/rho = (2*pi/NFP) * R * (r*dtheta(z)-dtheta(r)*z)`.

The prover computes three directed 256-bit MPFR bounds: a lower bound for
`R`, a lower bound for the perturbed cross-section orientation expression,
and their positive product. Conversion to stored `Float64` bounds is rounded
one representable value downward when necessary. Strictly positive bounds
prove orientation and nondegeneracy for every `0<rho<=1`; the coordinate
singularity at `rho=0` is explicit
and is handled by the analytic `|m|=1`, power-one axis regularity condition.

Mode identities establish the boundary value and tangential first derivatives
at `rho=1`. Integer Fourier modes establish the poloidal seam and
one-field-period rotational equivariance symbolically. The metric identity
follows from the interpreter definition `g=J'J`. The certificate records these
analytic obligations and the exact determinant sign convention; sampled
minima are not inputs to the proof.

The certificate proves compatibility only for this candidate-owned geometry
program. Its ceiling remains `screen_only`: it emits no DESC request, selects
or runs no provider, supplies no physical or engineering validation, grants no
pass or promotion, and yields zero credible physical devices.
