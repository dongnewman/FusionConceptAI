# UP2-01-G2-METRIC-BOUNDARY-V1 independent postrun R1 diagnosis

Verdict: `changes_requested`; `accepted=false`; no rerun authorized by this
review. The preserved focused R1 run exited `1`: the first three test groups
passed `20/20`, `10/10`, and `5/5`; the contradiction group passed `13/14`.
The sole failure was
`test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl:143`, expecting
`boundary_value_unit_mismatch`.

## Causal diagnosis

The mismatch input in the test is semantically valid as a negative control:
the `:x_min` face is `:dirichlet` but is deliberately given `_flux_u`, while
the source contract declares `_field_u` for Dirichlet values and `_flux_u` for
Neumann values (`metric_boundary_v1_contract_tests.jl:13-18, 26-36, 137-143`).
The source validator contains the corresponding typed check at
`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:458-462`:

```julia
expected_unit = f.value.kind === :dirichlet ? x.units.field_value : x.units.flux_value
f.value.unit == expected_unit || push!(errors, "boundary_value_unit_mismatch:" * f.face_id)
```

`g2mb_admit` then returns the complete validator error tuple as a typed
`structural_contradiction` (`MetricBoundaryDeclarationV1.jl:493-506`); there is
no visible priority branch that would intentionally remove this error. The
captured output reports only that the expected token was absent and does not
persist the actual `admission.errors` tuple. Therefore the run evidence does
not support calling this an omitted implementation check, nor does it support
weakening the test. Static source and test inspection predict the asserted
token should be present.

The remaining explanation is a runtime/source-test identity discrepancy or an
unobserved earlier error path in the captured process. The focused input
manifest nevertheless records the same current source/test hashes, so the
discrepancy cannot be resolved from the preserved artifacts alone. It must be
diagnosed by a separately controlled rerun or a narrow diagnostic that records
the full `g2mb_admit(unit_source).errors` value before changing behavior.

## Narrow repair and exit gate

Do not replace the assertion with a generic `fail_closed` check and do not
change the error code speculatively. The narrow next step is to expose the
actual error tuple for this one negative control while preserving the existing
status assertion. If the tuple lacks the expected token, repair the production
face-unit validation at the validator boundary so this typed error is emitted.
If the tuple contains it, repair the focused runner/load path or test artifact
identity. After that diagnostic, rerun the full focused command with frozen
source/test/fixture/static-QA hashes and retain the raw stdout/stderr,
exit-code, process sweep, and before/after dirty evidence. The exit gate is
the contradiction group passing `14/14` and the complete focused run exiting
`0`; this review grants no mesh/provider/physical/B00/B04/R01-R10 credit.

## Preserved execution evidence

The original command was
`julia --startup-file=no --project=. test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl`.
Its run metadata recorded exit `1`, dirty rows `300` before and after, and zero
matching Julia/DESC processes at the recorded boundaries. The focused raw
evidence and previous independent reviews remain untouched. Julia/DESC were
not run during this diagnosis.

