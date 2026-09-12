# Spatial verification/UQ staging report — 2026-09-12

The numerical branch is implemented in staging. It has not yet executed on the
new spatial candidate. No spatial residual, Jacobian, MMS, propagation or physical
validation result is claimed from these files alone.

| Item | Implemented | Executed | Result / exit |
| --- | --- | --- | --- |
| Independent raw Q1 weak/strong oracle, including `B divB / mu0` | yes | unit checks only | actual candidate pending |
| Every state Jacobian column/block, local coloring plus independent flux row | yes | no | main Julia queue pending |
| Nonzero-source analytic curved MMS on both mesh levels | yes | no | actual geometry pending |
| Actual flux endpoint→actual current→finite-aperture engineering propagation | yes | no | physics and engineering cases pending |
| Independent 256-bit exponential RL replay | yes | no | main focused/integration queue pending |
| Applicable physical validation and model discrepancy | no | no | unsupported; no data/independent physical solver |

Executed lightweight software verification: `test/spatial_verification_oracle_tests.py`
ran three tests under Python 3.13.5 / NumPy 2.1.3, exit 0. The saved log is
`audit/independent_oracle_focused.log`; the explicit exit is
`audit/independent_oracle_focused.exitcode`. The tests cover merged Q1 partition,
the cylindrical field `B_R=R` whose nonzero `B divB` force survives while curl is
zero, and independent analytic stress divergence for the MMS. Inputs are labeled
manufactured software fixtures; they are not upstream candidate products.

The first lightweight test used zero absolute tolerance for a mathematically
zero force component. It observed `8.13e-10 N/m³` floating-point leakage against a
`3.66e6 N/m³` force. Its fixture assertion was corrected to a dimensioned
`1e-8 N/m³` absolute tolerance plus `1e-13` relative tolerance; this did not change
the candidate declaration or any production acceptance threshold. The rerun
passed all three tests.

Source SHA-256 at initial focused handoff:

- Julia: `71a46c5fce29f0a9cc62636410c9b60e872dd88456851d05032526ca785420e5`
- Independent Python oracle: `0305bf822a691d3df2d169b344d1a5f98847cb3e38c20a3aaa46dd35c485873d`

Before actual execution, the main agent authorized a binding hardening while its
initial Julia focused process was already running. The validator now rebuilds
the canonical oracle request from actual physical state/geometry/ownership and
compares the exact input bytes; it checks the full structural pattern hash.
A negative fixture replaces and rehashes an unrelated request and must still
fail. The post-hardening focused rerun subsequently passed 33/33 with explicit
exit 0 in `runs/spatial_chain_20260912_audit/verification_focused_r2.log` and
`.exit`. Those are focused software checks, not actual-candidate execution.

The later read-only continuation audit requested three narrow additions: complete
four-column MMS parsing/finite checks with nonzero-source status derived from the
independent oracle norm, and independent checks of induced-emf peak plus total and
per-segment circuit energy identities. These latest source/test edits have not yet
been rerun. Actual spatial-candidate verification remains wholly unexecuted.

Reproduce lightweight verification from the repository root:

```powershell
& 'D:\Users\Newman\anaconda3\python.exe' 'runs/spatial_chain_20260912_staging/test/spatial_verification_oracle_tests.py'
```

The main agent owns all Julia/DESC scheduling and will populate real candidate
measurements, hashes, explicit exits, unsupported applicability and remaining
solver/model/data blockers after the unified execution. Neither this pending
table nor local green tests close the original full-chain objective.
