# Static MHD interface jump ledger V4

The ledger consumes the full current candidate/context through the real DESC
surface, pressure and traction chain plus the accepted analytic/finite-
difference residual-Jacobian subset. Its validator revalidates that whole chain,
reconstructs the request, and independently reconstructs every ledger entry.

For each exact interface, the ledger binds interface and adjacent-region
support identities, traction spec/sample hashes, residual hash and
`epsilon_rho`. It records the two conditions required by the declared static
ideal-MHD state contract:

- momentum-traction continuity: three Cartesian components in Pa;
- normal magnetic-flux continuity: one normal component in T.

The values are the accepted residual components, but they remain finite-offset
`c±epsilon` proxies. A physical boundary-limit protocol has not been executed,
so both condition records have `condition_validated=false` regardless of their
numeric magnitude.

Mass-flux continuity, tangential-electric-field continuity and total-energy-
flux continuity are enumerated separately as dynamic Rankine-Hugoniot
conditions outside this static state contract. Velocity, density, electric
field and energy-flux inputs are unavailable; those rows are not evaluated and
must not be silently inferred.

This ledger completes the declaration/accounting layer only. Boundary-limit
validation, jump validation, regional/global residual assembly, convergence,
multi-region closure, physical/engineering validation, evidence, promotion,
P5 and terminal authority all remain false; credible device count is zero.
