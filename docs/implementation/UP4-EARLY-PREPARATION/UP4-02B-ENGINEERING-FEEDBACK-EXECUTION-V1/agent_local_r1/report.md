# UP4-02B engineering-feedback execution V1 R14

## Verdict and ceiling

This is an additive reduced-SI execution screen. R14 closes the typed-input,
transient-balance, independent-force, material-ledger, and diagnostic gaps
while preserving the same ceiling. The implementation produces
`pass`, `fail_closed`, `terminal_deferred`, `numerical_fail`,
`physical_fail`, and `program_exception` outcomes, but always returns
`accepted=false`, `claim_ceiling=screen_only`, and `engineering_credit`,
`physical_credit`, and `r01_r10_credit` equal to `none`.

## Delivered boundary

The source consumes closed typed projections of the exact upstream execution
and load-sample fields, with sealed upstream/sample hashes, candidate/scenario/
G3/SHIR/bridge hashes, and a candidate-bound reduced SI envelope. Optional
`Any`/NamedTuple/fallback inputs are not admitted. SHIR and bridge resources
have typed status/unit/direction/owner fields and content-addressed closures.
The fixed-point trace is explicitly ordered as supply power,
temperature-dependent resistance/Joule heat, cooling and material response,
structural stress/displacement, and geometry/resistance feedback. Four
content-addressed ledgers are emitted for energy, thermal, mechanical force,
and material mass. Energy, thermal, force, material and state-change residuals
are recomputed; source/current/cooling capacities, maximum temperature, yield
strength and clearance are hard gates. Thermal capacity, material heat
capacity and time step enter an implicit/backward-Euler storage balance;
declared heat has an explicit non-double-count mode. Force balance reports
independent internal and support reactions. Material capacity minus applied
stress is a non-tautological material ledger. Dedicated temperature, stress,
clearance, force, energy, thermal and material diagnostics are sealed.

The upstream sample remains `component_load=false`, enforced by the typed
constructor and canonical hash. No pressure/B traction is
converted into a component force; `mechanical_load_N` is an explicit reduced
envelope input and the result retains a limitation string. Missing source,
return, heat sink or cooling refs, unit/owner/direction contradictions,
identity/scenario mutations, non-finite inputs, forged residuals, iteration
limits and double-counted Joule heat are represented as negative cases.
The local typed projection is named
`EngineeringFeedbackCandidatePlasmaLoadSampleRefV1` consistently. It is an
additive receipt boundary, not a replacement for the upstream provider type or
component-solid authority. The positive fixture's magnetic-energy/momentum-flux/traction
fields are independently rebuilt from `p`, `B`, `mu0`, and `n`; the load
sample's fields are replayed from the independent constitutive kernel, and bridge resource content/ref
hashes must join exactly to the four SHIR refs. Structural displacement uses
the prior geometry and reactions use the updated geometry, so the force
residual is not constructed zero. Forged residuals are independently
rechecked through `validate_engineering_feedback_residuals` and become
`fail_closed`;
non-finite envelopes are also observed as `numerical_fail`.

## Independent verification

Only the Python oracle/static QA was run, as required for this lane:

```text
python -B test/RuntimeV4/UP4/engineering_feedback_execution_v1_oracle.py
exit=0; status=PASS; negative_case_count=20; ledger_count=4;
positive_replay_iterations=6; final_max_residual=9.592326932761353e-10
```

The independent positive replay uses the frozen 50-iteration, `1e-8`
tolerance envelope. Its maximum residual trajectory is
`[4.901960784313815e-1, 8.864998051194561e-3,
1.607833320717338e-4, 2.916101948358118e-6,
5.288893589749932e-8, 9.592326932761353e-10]`; it converges on iteration 6.
The focused receipt test routes all 20 negatives through the product entry or
typed residual validator, with `forged_residual=fail_closed`.
The iteration construction body now includes `internal_reaction_N` and
`support_reaction_N` in exactly the same order as the canonical iteration body;
the canonical hash guard covers both fields.

The request requires the load sample to be an exact closed-object member of
`upstream_execution.samples`, matching both canonical hash and every typed
field. A same-identity but foreign sample is rejected with
`load_sample_membership_mismatch`. Constitutive replay recomputes
`independent_traction_difference_Pa` as a non-negative maximum component
difference and requires exact agreement with the declared value.
Stored negative traction-difference values are rejected strictly before the
`1e-10` comparison tolerance; the product matrix includes this case.
The negative stored-difference request is built as a typed request with
explicit usable hashes, then passed through `execute_engineering_feedback` so
the product returns the typed fail-closed receipt instead of a test-construction
exception.

The closed sample, upstream, resource, SHIR, and bridge projections all expose
non-recursive `semantic_view` methods, so nested canonical hashing reaches the
existing constitutive validators rather than failing with a missing-method
exception.

The final iteration is bound as `final_iteration = Base.last(trace)` so the
trace reduction cannot shadow `last`. The residual vector now has its own
non-recursive `semantic_view`, closing the error-result path that nests
residuals, diagnostics, gates, ledgers, and the execution receipt.

The non-finite envelope negative now uses a typed envelope with an explicit
usable receipt hash and a typed request with an explicit request hash; it is
then passed into `execute_engineering_feedback` and returns the typed
`numerical_fail`/`nonfinite` receipt instead of failing during fixture setup.

Julia, DESC, providers, hardware, and shared registries were not executed or
modified. No commit was created. Existing dirty files and protected UP4
contracts remain outside this package's write scope.

## Hashes

| path | sha256 |
|---|---|
| `src/RuntimeV4/EngineeringFeedbackExecutionV1.jl` | `67486a8ffb7a1c4d289df14f6858eb2a8b9cdcd79e75a8b0a6711c1a1c9e74de` |
| `test/RuntimeV4/UP4/engineering_feedback_execution_v1_tests.jl` | `a3081fb8702f99449e2ab30f450efb9b87d5bfcb7ca364fcb152c123548db3ab` |
| `test/RuntimeV4/UP4/engineering_feedback_execution_v1_fixture.json` | `105fc870d0764f87c05332a5d46233b3c30e706a0213427a9d76bd04600f9369` |
| `test/RuntimeV4/UP4/engineering_feedback_execution_v1_oracle.py` | `13dfb36857f655f2e8720b147c54e48cc6db2ddea8429125bf8e93606d4bcb27` |

Reviewed HEAD: `5d3c5e9c1281e4bdd999ba173ad75c3e9a1ec885`.
