# M4-A equation IR integration verification R1

Status: `integration_complete_review_pending`  
Owner: integration/documentation Luna (`gpt-5.6-luna`, high)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Decision

The isolated M4-A harness integrates as a manufactured-control/screen-only
slice. The source is loaded only by the dedicated test file with `include`;
it is not included by a shared RuntimeV4 module and does not alter a registry,
Project, Manifest, shared entrypoint, or shared manifest. Julia uses only the
stdlib modules `Test` and `SHA`; the Python oracle uses only the standard
library (`fractions`, `json`, `math`, `sys`).

This is an integration verification record, not formal acceptance. It grants
no UP2-01, UP2, B00, B04, provider, mesh, engineering, physical, R01-R10, or
L4 credit. No lowering, discretization, topology transfer, coupling, solver,
candidate, provider, or physical claim is made.

## Serial execution evidence

Four fresh processes were run strictly serially: Python oracle twice, then
Julia test twice. Every command has an exact command, cwd, PID, UTC start/end,
exit code, input hashes, output hashes, and separate stdout/stderr/combined
raw files in the command receipt and `raw/` directory. The same raw files are
archived under `archive/raw/`. All exit codes are zero and all stderr files are
empty.

The two Python canonical JSON payloads are semantically equal and report
`div_k_grad_u = 11/60`, source `-11/60`, exact residual `0`, and floating
residual `0.0`. The Julia runs each report `42` passed of `42` tests. Their
human-readable timing fields differ (1.9 s and 1.1 s), so comparison uses the
semantic pass/total result rather than requiring byte-identical test summaries.

## Boundary and ownership checks

The source, test, and oracle SHA-256 values are identical to the frozen
`test_execution_r1` inputs. The source has no imports or includes. The test's
sole source include resolves to the isolated source path; its only imports are
stdlib `Test` and `SHA`. The oracle imports only Python standard-library
modules. The test's explicit absence guards for CandidateStatePackageV5,
ForwardChainContextV4, and RuntimeEvidenceV4 pass.

Only this integration owner wrote `integration_r1/`. No implementation,
test/oracle, shared entrypoint, Project/Manifest, or registry file was edited
by this record. Existing dirty work and prior test receipts remain outside the
owned output; no broad cleanup or staging was performed.

## Re-entry and ceiling

The accepted scope remains subordinate to the M4 scope root acceptance and
the M1 independent review plus separate Sol acceptance. The next work may
proceed only under those gates and the exact formal route
`T0 -> authority recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B ->
UP1-04 -> UP2-01`. This record leaves parent R01-R10 and the 39-node DAG open.

