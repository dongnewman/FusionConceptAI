# AD-42 acceptance — independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope and decision

This review independently checked the current AD-42 acceptance record, the
architecture audit, its prior independent review and raw streams, the frozen
input chain, the four point-in-time AD-40 W2 products, the eleven named audit
sidecars, the W0 parallel outputs, and the absence of future W2R1 products.
The review wrote only this review directory and did not modify AD-42 audit
inputs, AD-40 products, source, tests, the core planning documents, or the
task manifest.

The verdict is `pass_limited` for the declared
`architecture_only_cycle_break_and_finite_W0_to_W2R1_boundary` scope. The
accepted boundary is an acyclic preparation contract: V1 schema/profile
material → fresh seed namespace → W0 public envelopes → W2R1 source payload
authoring → later declaration/candidate identity. A payload, declaration, or
final candidate hash may not derive a public URI, public ref, or seed; those
reverse edges remain `fail_closed`.

W0 and W2R1 remain proposed preparation work orders. The observed W0 products
are explicitly point-in-time excluded and pending their own independent work
order review. They do not grant present authority, T0/T1/T2, provider, mesh,
solver, engineering, physical, search, or R01–R10 credit. W2R1 products remain
absent.

## Evidence closure

The current acceptance manifest closed exactly 14 frozen inputs, 4 historical
AD-40 W2 products, and 11 named AD-42 audit sidecars by current byte count and
SHA-256. The prior AD-42 independent report and its raw stdout/stderr also
matched their recorded hashes. Both preserved acceptance failure receipts were
present and hash-closed; their `program_exception` and exit-1 classifications
were retained.

The four W0 products were present with the acceptance manifest's recorded
bytes and hashes. Their payloads preserve the typed G1 `QualifiedRefV1` and G2
`GenomeContractRef` distinction, use the fresh seed recipe, and retain false
candidate/declaration/authority flags. Their materialization receipt explicitly
keeps independent review pending. This review therefore treats them only as
excluded observations, not as accepted W0 execution or source-backed
authority.

## Contract and source checks

The G1 V1 source exposes `G1DiffusionDeclarationV1` and
`QualifiedRefV1`; its V5 materializer is not used by the V1 boundary. The G2
V1 source exposes `G2MBSourceV1` and `GenomeContractRef`; the V5
`FieldGeometryGenomeV5` candidate-hash path remains separate. The public
`QualifiedRefV1` and five-field `GenomeContractRef` types are present. The
work-order records contain four products each, complete inputs/outputs/result
unions/dependencies/forbidden edges/exit gates/cleanup/sidecar rules, and the
dependency direction is W0 → W2R1 with no reverse edge.

## Independent executions

The JSON/hash/path/control verifier ran with
`D:/Users/Newman/anaconda3/python.exe` (Python 3.13.5), PID `72588`, UTC
`2026-09-15T09:27:50.011573Z`–`2026-09-15T09:27:50.093943Z`, exit `0`. Its raw
stdout is `review/validation_stdout.json`, 10676 bytes, SHA-256
`c990f342596f7279ba91050564240334b707e8fcc5ec308e5124bb9cd38ce9d6`; raw
stderr is `review/validation_stderr.txt`, 0 bytes, SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The planning validator ran from the repository root with the same interpreter,
wrapper PID `84668`, child PID `58844`, UTC
`2026-09-15T09:28:39.574500Z`–`2026-09-15T09:28:39.906162Z`, exit `0`. Its raw
stdout is `review/plan_validator_stdout.txt`, 401 bytes, SHA-256
`cf4058eae2fcca17ca5cdfa4207f0caf0451e9299254edf56fe875f4fe283bf7`; raw
stderr is 0 bytes, SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. The
validator reported 31 Markdown files, 497 relative links, 39 tasks, and an
acyclic task DAG. This is planning evidence only and does not substitute for
implementation, numerical, engineering, or physical evidence.

## Claim boundary

All current `present`, `T0`, `T1`, `T2`, provider, mesh, solver, engineering,
physical, and `R01–R10` flags remain `false`. No Julia, DESC, provider, mesh,
solver, or physical workload was run. `pass_limited` closes only the AD-42
architecture cycle-break and finite W0→W2R1 contract review; it does not
dispatch either work order, create a candidate identity, or promote the W0
parallel products.

Cleanup was limited to this review's temporary verifier runners. No unrelated
dirty files, historical receipts, accepted artifacts, source, tests, or
fixtures were removed.
