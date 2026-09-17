# UP2-01-G3-SOURCE-FEEDBACK-V1 independent static precheck R2

Verdict: `changes_requested`.

This review is static-only at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`.
The review freeze saw 300 porcelain entries and no matching Julia process. The
repair-R2 static QA exits 0 with no Julia, DESC, compiler, provider, mesh, or
solver execution. R1 evidence and repair-R2 evidence were read and left
unchanged.

## Blocking finding

### G3SF-R2-01 public fault injection can forge `program_exception`

`g3_sf_admit_v1` is the public admission entry point and is declared as
`g3_sf_admit_v1(x::Any; fault_seam::Symbol=:none)` at
`src/GenomeV5/G3/G3SourceFeedbackLawV1.jl:449`. Any caller can pass
`fault_seam=:internal_validation_fault`; the public function then deliberately
throws and catches a controlled error and returns `status=:program_exception`
and `resolution=:program_exception` at lines 454-478. The focused test calls
this exact public keyword at lines 124-125, so the test demonstrates reachability
but also confirms that an untrusted caller can alter admission classification.

This is not an input-derived unexpected exception. It makes a safety-sensitive
classification controllable through the public API and can therefore be used to
forge a program-exception receipt. Remove the keyword from the public factory
and keep the admission core shared with an unexported, explicitly internal
test-only fault helper. The public call must not accept or route an arbitrary
fault seam. Preserve the ordinary taxonomy: typed contradiction and hash
tamper are `fail_closed`, missing authority is `terminal_deferred`, and only an
unexpected internal failure is `program_exception`.

## R2 repair checks

The evaluator now reads the declared typed ledger entries and their rational
coefficients. Validation binds each entry's effect, endpoint role, direction,
sign, unit, owner, coefficient, closure set, and declaration content hash. The
typed conservative split, heat relation, and ledger relation remove the prior
free-text formula fields. The synthetic exact arithmetic remains valid:
`120 W -> 90 W + 15 W + 15 W`, with both residuals zero. The public tamper and
bad-coefficient controls reach `fail_closed`; bare `actual` authority reaches
`fail_closed:unattested_authority`; missing authority remains
`terminal_deferred`; a trusted-looking authority remains behind the
`same_candidate_authority_gate:VNEXT:G1/G2` gaps and does not resolve this
slice.

Two residual coverage limits remain visible. The efficiency edit rebuilds the
typed ledger and declaration hash, but the test only asserts the changed hash
and edited field value; it does not independently assert the edited return,
heat, ledger coefficients, and both closure residuals. Also,
`:trusted_receipt` is a caller-supplied attestation symbol rather than a
verified external receipt. The current admission path keeps it
`terminal_deferred`, so it does not promote or reuse an old candidate, but the
focused contract should retain that explicit same-candidate gate.

## Static evidence and boundaries

The Python static QA command was run read-only and returned exit 0. Its
manifest hash check passed. Definition order is coherent on inspection and no
new `? return` pattern was found. Julia parsing remains unverified until the
serial focused lane. No compiler/provider/mesh/solver/physical/B00/B04 or
R01-R10 credit is granted. `review_pending=true` and `accepted=false` remain
required.

## Required disposition

After the public fault seam is removed or made unreachable to ordinary callers,
repeat an independent static review. Add public negative coverage proving that
the public entry cannot inject `fault_seam`, and extend efficiency-edit checks
to return/heat coefficients and closure residuals. Only then can this slice be
considered for the separately serialized focused run.

