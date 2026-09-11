# Static MHD interface jump ledger

The ledger now binds the full real-DESC chain and the accepted interface
residual/Jacobian result. Each entry owns the exact interface, adjacent region
supports, traction sample and four-component residual identity. The declared
static conditions are traction-vector continuity and normal-B continuity;
dynamic mass/electric/energy conditions are explicitly out of scope because
their state inputs do not exist in the static contract.

All calculated values are finite-offset proxies. The ledger does not claim
boundary limits, validated jump conditions, regional/global residual assembly,
convergence, closure, validation evidence or device authority. Focused and
standalone exit evidence must be recorded after the full real chain finishes.

Verification now completed with explicit exit 0:

- focused test: 32/32, including foreign interface identity, attempted
  boundary-limit authority escalation and swapped-type rejection;
- standalone real-chain runner:
  `STATIC_MHD_INTERFACE_JUMP_LEDGER_RUN_EXIT_CODE=0`;
- the package-wide Julia suite passed with exit 0 immediately before this
  additive ledger validation.
