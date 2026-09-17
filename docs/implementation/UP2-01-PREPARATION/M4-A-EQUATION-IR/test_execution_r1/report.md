# M4-A equation IR test execution R1

Status: `tests_complete_review_pending`  
Owner: test/oracle Luna (`gpt-5.6-luna`, high)  
Frozen source: `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl`  
Claim ceiling: `manufactured_control` / `screen_only`

The independent Python oracle ran first and passed. It uses only Python's
standard-library `fractions` and derives `div(K grad(u)) = 11/60`,
`f = -11/60`, exact residual `0`, and floating residual `0.0 <= 1e-12`.
Its canonical JSON output is retained in
`command_05_python_oracle_final.stdout.raw`.

The Julia test ran second and passed: `42` tests, `42` passed, exit code `0`.
It loads the source with `include` in isolation and checks the default IR,
stable payload, units/domain/operator/SPD/owner/boundary/provenance, deferred
time and multifield scopes, and typed stable failures for missing/unknown
operator, wrong units, nonpositive/non-SPD coefficient, duplicate owner,
missing boundary closure, and foreign source.

No residual lowering, discretization, topology transfer, coupling, solver,
candidate/provider, physical, B00/B04, R, or L4 claim is made. No shared
manifest, registry, project file, entrypoint, or source file was modified.

The first Python wrapper attempt is retained and marked superseded because the
wrapper tried to assign PowerShell's read-only `PID` variable after the child
had exited. The child oracle output was retained; corrected current-input
evidence is the final Python/Julia pair.

Primary receipts:

- `command_05_python_oracle_final.receipt.json`
- `command_06_julia_tests_final.receipt.json`
- `validation_receipt.json`
