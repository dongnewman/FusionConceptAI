# AD-42 W0 local software materialization status sync — independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope and acceptance boundary

This review independently checked the current AD-42 acceptance status sync R2,
its report and manifest, the AD-42 root acceptance record, all four W0 product
files, the W0 independent review, direct validation/materialization receipts,
raw streams, and the preserved failure receipt. No reviewed product, AD-42
acceptance record, source, test, task manifest, or historical receipt was
modified. The review grants only `software_contract_materialization_only`.

The status is internally consistent: W0 is `accepted_limited` with result
`PresentPublicContractEnvelopeV1`; this is a software contract package and
does not create source-backed declaration authority, a candidate identity, a
declaration or candidate hash, T0/T1/T2, provider/mesh/solver evidence,
engineering or physical evidence, or R01–R10 credit.

## Independent checks

The fresh read-only validator passed `26/26` checks. It verified the status
scope and exact four product set, current byte counts and SHA-256 values,
canonical JSON without terminal LF, five-field `GenomeContractRef` records,
the G1 `QualifiedRefV1` / G2 `GenomeContractRef` type distinction, V1/V5
domain separation, and the fresh seed join. It also verified the three typed
absence axes: G1 evidence receipt, G2 applicability profile, and G2 evidence
receipt.

The result union is closed and W2R1 remains `pending_AD43_axis_records` with
future W2R1 products absent. The fresh seed commitment is equal across both
layers, the recipe, and the materialization receipt, and differs from the
historical AD-40 W2 commitment. Payload, declaration, candidate, authority,
binding, present declaration, T0/T1/T2, provider, mesh, solver, engineering,
physical, and R01–R10 flags remain false. The prior failed materialization
receipt remains preserved as `FailedPublicContractEnvelopeV1` with
`program_exception` and exit code `1`.

The existing evidence closure was rechecked: the recorded different-Luna
review is `40/40`, direct validation is `21` checks, fresh status validation is
`15/15`, and final closure is `14/14`. Every declared raw stream path exists
and matches its recorded bytes and SHA-256. The fresh independent run used
`D:/Users/Newman/anaconda3/python.exe` Python `3.13.5`, PID `75060`, from
`D:/006-Programing/LMC/FusionConceptAI`, UTC
`2026-09-15T10:09:18.029492Z`–`2026-09-15T10:09:18.044547Z`, and exited `0`.
Raw stdout is `review/validation_stdout.json`, 3085 bytes, SHA-256
`584f8bc0643e273d17f7bcd6a080ae29dce289f5acdf5c02ff7e57ad2590be65`; raw
stderr is zero bytes, SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Decision

`pass_limited` accepts the W0 local software contract materialization status
sync only. It does not authorize W2R1 execution or transfer any evidence to
declaration authority, candidate identity, T0/T1/T2, provider, mesh, solver,
physical, or R01–R10 claims. W2R1 remains blocked on the AD-43 axis records.
The four W0 products and all historical evidence remain append-only and
protected; cleanup is limited to this review task's temporary validator.
