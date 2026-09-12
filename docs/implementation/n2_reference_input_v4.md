# N2 reference input binding

`N2ReferenceInputV4.jl` is an additive, screen-only adapter. It binds four
separate identities: the frozen external HDF5 bytes, the corrected r3
normalization-result bytes, the subject SHA recomputed from that result's exact
Python canonical subject wire, and a label-neutral typed subject projection.
The Julia boundary parses the JSON itself, requires the wire and parsed subject
to be structurally equal, and validates the screen-only authority receipt. It
then requires the selected
candidate-owned `ThreeDPhysicalProviderInputV4` to reproduce the normalized
Fourier boundary, pressure, iota/current profile, field periods, symmetry, and
toroidal flux exactly.

The binding retains provenance that earlier r1 omitted: the artifact was
distributed in DESC tag v0.17.3, its root and all four family members embed
`0.17.1+38.g53ea59ef0.dirty`, DESC 0.17.3 was only the loader runtime, and
equilibrium member index 3 is selected. Truncation bounds and source resolution
remain inside the typed semantic projection. Display and reference labels do
not.

This slice intentionally stops before a geometry interpreter or provider. The
normalized r3 subject owns only the boundary, but the selected HDF5 equilibrium
does contain a full `FourierZernikeBasis`: 591 R and 578 Z coefficients exceed
the normalization threshold, with as many as 13 radial orders for one `(m,n)`.
That interior representation has not yet been normalized or candidate-bound,
and the current interpreter's single `rho^power` per boundary mode is not an
equivalent representation. The runtime also rejects NFP 19, its analytic
base-mode orientation gate does not accept the stored signs, and the
fixed-boundary request declaration caps `L` at 12 while the source records
`L=24`. Each condition is emitted as a recoverable gap; no sign flip, radial
law, basis substitution, resolution reduction, provider selection, or solver
execution is inferred.

All authority fields remain `screen_only`: no measurement, inverse recovery,
held-out prediction, physical validation, P5 readiness, or credible device.
