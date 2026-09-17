# UP2-01-G3-SOURCE-FEEDBACK-V1 independent static precheck R3

Verdict: `pass_limited`.

The R2 findings are closed at the source and test surface inspected here. This
review is static-only at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`.
The freeze saw 3,688 porcelain entries and no matching Julia process. Python
static QA exited 0. Julia/DESC were not run, and this result only permits the
software focused run to enter its separately serialized queue; it is not an
acceptance or physical result.

## R2 closure checks

The public `g3_sf_admit_v1(x::Any)` no longer has a `fault_seam` keyword or any
public injection parameter. The ordinary path calls `_g3sf_admit_core_v1(x)`.
The only controlled fault path is the underscore-prefixed internal helper
`_g3sf_admit_fault_seam_v1`, which is used by the focused test to classify an
injected internal exception as `program_exception`. The test also asserts that
calling the public method with the old keyword raises `MethodError`. This
closes the R2 public-forgery finding at the static API surface.

The typed evaluator reads the four declared ledger entries and their exact
rational coefficients after validation. The declaration validator recomputes
the canonical source hash and binds effect, endpoint role, direction, sign,
unit, owner, coefficient, and closure membership. The positive fixture remains
the exact `120 -> 90 + 15 + 15` case. A changed ledger coefficient and a
tampered declaration hash reach `fail_closed` and evaluation rejects the bad
declaration.

The efficiency edit now has independent assertions for the changed hash,
field=105 W, return=0 W, heat=15 W, all four edited coefficients, energy
residual=0, and ledger residual=0. This closes the R2 coverage gap for the
edited ledger and closure.

Authority boundaries remain correct for this slice. Bare `:actual` with no
trusted receipt is `fail_closed` with `unattested_authority`; missing authority
is `terminal_deferred`; a caller-supplied trusted-looking record remains
`terminal_deferred` behind the explicit same-candidate `VNEXT` G1/G2 gates. No
old candidate or historical A/H0 receipt is rebound. No compiler, provider,
mesh, solver, physical, or engineering path is present.

## Static limits and queue decision

The Python static QA checks the repair-R3 manifest and all checks pass. The
typed source definition order is coherent by inspection, with no newly
observed parse-risk ternary return pattern. Julia parsing and runtime behavior
remain unverified until the serialized focused lane. Keep
`review_pending=true` and `accepted=false`; no B00/B04 or R01-R10 credit is
granted. The software focused run may proceed only under the parent queue's
serialization and its own post-run evidence requirements.

