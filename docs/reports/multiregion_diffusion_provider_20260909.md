# Multi-region diffusion provider report — 2026-09-09

## Result

Implemented a standalone Julia sparse numerical kernel for two scalar model
regions. It is explicitly not candidate-bound evidence or a RuntimeV4 provider.
The assembled system has independent internal diffusion rows,
declared external boundary rows, and explicit interface value-continuity and
oriented conservative-flux rows. Residuals and interface laws are recomputed
after solving and sealed into a typed receipt.

## Focused verification

`julia --startup-file=no --project=. test/runtime_v4_multiregion_diffusion_provider_tests.jl`
exited 0 (7/7 passed) after this downgrade. The test retains a manufactured
profile, unit and validation-hash rejection, and pure-Neumann singular control.

## Integration gaps

The current upstream compiler does not yet emit a ready multiregion contract
with physical region/interface data for a real candidate. It must provide
typed interface edges whose ledger orientation matches minus/plus, candidate
bound coordinates, material coefficients, sources, external boundaries, and
unit signatures. Until then this is bounded screen evidence only; it is not
fusion validation, engineering closure, or device readiness.
