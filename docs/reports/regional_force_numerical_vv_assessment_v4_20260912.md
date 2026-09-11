# Regional force numerical V&V assessment report

The assessment consumes the candidate-bound q2/q3 comparison and preserves all
upstream identities. With relative tolerance `1e-3` and absolute tolerance
`1e-6 N`, measured differences `1.4432683785832432` and `493861.3259229757 N`
produce `numerical_convergence_status=:fail`. It requests `q4_required` and
retains the recoverable gap `independent_code_validation_required`.

This measured default-tolerance result is negative. The canonical validator also
tests the positive tolerance branch, but neither outcome constitutes independent
code validation, physical validation, UQ, evidence credit, or promotion
authority. The q3 runner uses its existing unique temporary run root; this
assessment creates no shared run root.
The older `outputs/fusion_concept_ai` implementation is treated as extract/wrap
reference only: this slice is test-only and rejects forged pass or authority.

## Reproduction evidence

```text
julia --project=. test/runtime_v4_regional_force_numerical_vv_assessment_tests.jl
23/23 assertions passed
process exit code: 0

julia --project=. scripts/run_v4_regional_force_numerical_vv_assessment.jl
numerical_convergence_status=fail
relative_difference=1.4432683785832432
REGIONAL_FORCE_NUMERICAL_VV_ASSESSMENT_EXIT_CODE=0
process exit code: 0

julia --project=. test/runtests.jl
package-wide regression process exit code: 0
```

The focused test executes the complete real q2/q3 upstream chain. It covers the
measured default-tolerance failure, the logically valid loose-tolerance pass,
non-finite/negative tolerance rejection, foreign execution rejection, and
forged difference/status/authority rejection, and public-constructor rejection.
A pass under a declared tolerance
still carries zero evidence credit and no independent-code, physical, UQ,
promotion, or terminal authority.
