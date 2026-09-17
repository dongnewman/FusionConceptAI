# UP2-01-G2-METRIC-BOUNDARY-V1 agent-local R1

Status: `review_pending`; `accepted=false`; `claim_ceiling=contract_only`.

## Scope and protection

Baseline HEAD was `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`. Existing dirty
work, `runs/`, old evidence, shared entrypoints, G1/G3, and all files outside
the four authorized artifacts were preserved. No `phase5_remote_session.py`
was found under `D:\006-Programing\LMC` during the read-only inventory.

This R1 changed only:

- `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl`
- `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl`
- `test/GenomeV5/G2/metric_boundary_v1_fixture.json`
- `test/GenomeV5/G2/static_qa_metric_boundary_v1.py`

## Minimal repair and audit coverage

The source now applies the declared lexical face canonicalization before
source/declaration hashing and semantic serialization. Face tuple permutation
therefore cannot create a new identity, while semantic `face_id`, owner,
orientation and value fields remain bound. The fixture explicitly records that
there are no display-only labels in this V1 schema, so label erasure is
`not_applicable` rather than an unverified invariance claim.

The focused contract tests additionally cover evaluated chart/Jacobian/metric
values, mesh chart-ref binding, unsupported basis, out-of-domain and
non-positive/arity-invalid quadrature, candidate-change rehashing, source and
declaration hash tamper rejection, face orientation admission, and the existing
Dirichlet/Neumann, unit, deferred-authority, controlled-program-exception and
physical-area/volume checks.

## Verification

Python static QA exited `0` after the repair. It reads only source, test and
fixture text and reported `julia_or_desc_executed=false` and
`provider_or_mesh_execution=false`.

The first focused Julia attempt exited `1` because the newly added test
incorrectly expected the face-owner constructor to reject an axis-normal
mismatch; the contract intentionally rejects that contradiction at admission.
That assertion was narrowed to construct the malformed owner and verify
`fail_closed` plus `reference_face_orientation_mismatch:x_min`.

The single authorized rerun then exited `0` (PID `21656`, UTC
`2026-09-17T11:09:40.2029358Z`–`2026-09-17T11:09:47.3521001Z`), with seven
testsets passing `82/82` assertions. No Julia/DESC process remained afterward.
This is software/contract evidence only; it grants no compiler, provider, mesh,
solver, engineering, physical, B00, B04 or R01–R10 credit.

`git diff --check` exited `0`. Runtime scratch outputs remain inventoried under
`tmp/g2mb_agent_local_r1_runtime/` (failed attempt) and
`tmp/g2mb_agent_local_r1_runtime_r2/` (passing rerun); they are not acceptance
artifacts and must not be confused with the archived stdout/stderr below.
