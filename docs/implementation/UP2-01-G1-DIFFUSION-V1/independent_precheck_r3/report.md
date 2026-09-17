# UP2-01-G1-DIFFUSION-V1 independent static precheck R3

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

This read-only review covers the R3 repair at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. R2's full report and the R3
repair report/manifest were read, together with the current source, test,
fixture, static QA and AD-28 work-order boundary. The working tree had 298
status rows and no matching Julia/DESC process at capture. Julia and DESC were
not run by this review.

## R3 items verified statically

`G1DiffusionSourcePayloadV1` now appears before both
`G1DiffusionOperatorChainV1` and `G1DiffusionDeclarationV1`; its typed
`source_ref`, `source_version`, `u`, `K` and `f` fields are therefore ordered
before their local typed users (`DiffusionDeclarationV1.jl:229-250,252-327`).
The static QA includes a local struct-field forward-reference scan and reports
`static_qa=pass`.

The public admission result has typed `status`, `error_code`, `error_path`,
`declaration` and `exception_type` fields. Forged source hashes, K bound/domain
contradictions, positive expected residual sign, and unit mismatch controls
return `:fail_closed` with field paths and no declaration in the test
(`diffusion_v1_contract_tests.jl:92-119`). Valid declarations return
`:terminal_deferred` with `:missing_external_authority` and retain the
declaration (`:69-74`). The source includes a separate
`:program_exception`/`:unexpected_exception` constructor and does not inspect
exception message text (`DiffusionDeclarationV1.jl:378-450`). Source payload
hashing, affine K evaluation/enclosure, edits, `residual_sign=-1`, and unit and
field bindings remain present. No current-A, compiler, provider, mesh, solver,
engineering, physical, B00, B04 or R01-R10 credit is implied.

## Findings requiring correction

### 1. `program_exception` is not behaviorally exercised

The source defines catch paths for declaration validation, K enclosure and
malformed K probe conversion (`DiffusionDeclarationV1.jl:395-403,420-434`),
but the current test contains no assertion for `status == :program_exception`,
`error_code == :unexpected_exception`, `declaration === nothing`, or raw-throw
absence. Its admission controls cover known fail-closed and terminal-deferred
cases only (`diffusion_v1_contract_tests.jl:69-120`). Add at least one malformed
public admission input that reaches an existing catch path, such as a malformed
K probe, and assert the complete typed result. Keep it distinct from known
domain contradiction and missing-authority outcomes.

### 2. R3 archive state says review is not pending

Both `repair_r3/report.md:3` and `repair_r3/evidence_manifest.json:3-5` say
`changes_ready_for_independent_r3_review` with `review_pending=false` and
`accepted=false`. Before this independent review, that is internally
inconsistent: the repair is awaiting review, so the state should be
`review_pending=true` (while remaining `accepted=false`). This review does not
rewrite the old repair archive; the author must correct the state in a new
repair/status update or otherwise record the correction before a ready verdict.

## Scope and disposition

The implementation now has the requested source payload order and typed
admission taxonomy on the inspected paths. The two items above prevent a
`ready_for_serial_focused` verdict. Actual authority remains absent and
`terminal_deferred`; all physical and parent-goal claim ceilings remain false.

Disposition: `changes_requested`; after a public `program_exception` behavior
control and state correction, request a different-Luna static R4 review before
any serial focused runtime lane.

