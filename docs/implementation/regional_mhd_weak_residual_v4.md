# RegionalMHDWeakResidualV4

This slice owns typed test functions, regional volume/source terms, oriented
interface or exterior boundary terms, and a global conservation ledger. DESC
static-MHD and interface-ledger objects are upstream bindings; unavailable
capabilities remain `deferred`. Manufactured controls are test-only and retain
the `screen_only` claim ceiling. The slice does not alter Genome routing,
authority, aggregators, or physical validation.

The declared weak form is, for each typed vector test function `w` on region
`Ω_r`, `R_r(w) = ∫_{Ω_r} w·S dV + ∫_{∂Ω_r} w·F·n dA`, in SI-compatible
units carried by `UnitSignature`. Boundary fluxes are outward on the minus
region; an internal interface is represented by exactly two opposite terms
with the same source identity, while exterior terms remain separate. This is
an accounting form only: no solve, convergence, or physical validation is
implied.

The production entry point `bind_regional_mhd_desc_production_gap` consumes the
complete explicit upstream artifact set and invokes loaded full-chain
validators. It remains gap-only because the three weak capabilities are not
available. The `test_only_*_binding` constructors cannot create production
bound artifacts.

Reuse audit: `DESCRegionalIntegratedForceObservationV4` is extracted as a
field/basis observation and wrapped only by its object hash; it is not treated
as a weak residual. `StaticMHDInterfaceJumpLedgerV4` is extracted as finite-
offset interface diagnostics and wrapped only as a boundary-provider hash.
The manufactured path is test-only. Unsupported or absent DESC capabilities
are rejected from assembly by recording `:deferred` (never silently replaced).

`replay_regional_mhd_weak_residual` independently recomputes all test-function
and regional ledgers. The typed request/result/receipt execution envelope seals
candidate/context/residual identities and replay hash; tampering or authority
escalation fails closed. The current runner executes replay and records the
real upstream execution identities, but the weak provider remains unavailable.

Legacy reuse is limited to extract (regional force observation), wrap
(interface jump ledger), test-only manufactured fixtures, and reject (using
either legacy artifact as a weak residual or as promotion evidence).
