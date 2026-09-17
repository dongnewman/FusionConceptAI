# AD-39 G1/G2 publication input recovery audit — independent review R2

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope and basis

This review independently checks AD-39 `repair_r1` against the v4 README,
the common contract, orchestration and work-order rules, current AD-36, the
preserved AD-39 audit, AD-37 repair R2, and the cited G1/G2 source, tests,
fixtures and integration seams. The original audit, independent R1 review and
repair R1 remain unchanged. This review runs only JSON/hash/path/API/control-
character/diff-scope checks; Julia, DESC, provider, mesh, solver and physical
execution are not run.

The current HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`. AD-36 is
currently `accepted_limited`, `accepted=true`, with a 5928-byte manifest and
SHA-256
`4f71a9fc434362f3b37f1f5d7855b6c2e6558a6011b3fbd771bfc089022019e9`.
Repair R1 preserves the original AD-39 record of 6021 bytes with the same
SHA as a historical receipt metadata bug and uses the recomputed current pair.
The current pair matches exactly.

## Repair findings

All three R1 findings are closed.

1. The AD-36 byte/count reconciliation is explicit and reproducible. The
   current status, acceptance scope, byte count and SHA are recorded, while
   the old 6021-byte/same-SHA observation remains append-only historical data.

2. The stale AD-36 blocker is removed from the current work-order blocker
   list. Repair R1 records that acceptance removes only the sidecar-policy
   blocker; fresh source, binding, provenance, factory, mapping and identity
   inputs remain absent and continue to block publication.

3. Both work orders now state a semantic owner and enumerate every fresh input
   with a canonical AD-37 path, canonical owner, producer, schema, hash rule,
   canonicalization rule, missing-input policy and contradiction policy. G1
   has six records; G2 has those six plus its independently checked mapping
   record, for thirteen records total. G2 mapping remains a required input and
   is not inferred from the existing synthetic transport type or fixture.

The repaired work orders retain the original 14 product paths each, the
`PresentBaselinePublicationV1 | AbsentBaselinePublicationV1 |
FailedBaselinePublicationV1` result union, accepted prerequisite dependencies,
sibling separation, forbidden T0/authority-recheck/T1/T2 edges, direct command
rule, independent review gate and task-owned cleanup boundary. No product or
future input path exists in the checkout.

## Authority and evidence boundary

The source audit remains conservative. G1 has a typed payload, declaration and
local contract receipt recipe, while current construction uses are definition
or synthetic focused-test paths and public authority remains deferred. G2 has
typed source/declaration/receipt recipes and a mapping type in
`VNextDeclarationTransportV1`, but no fresh source-backed mapping receipt;
current mapping uses are synthetic transport tests. The fixture states remain
contract-only and cannot establish source authority.

The parent binding seam still rejects fixture/ref-only/synthetic admission and
ends public present admission at `source_backed_receipt_unavailable`. No fresh
source bytes/record, candidate binding, four-axis attestation, source-backed
factory/declaration receipt or fresh identity review has been created. No
fixture, synthetic value, legacy receipt or future hash has been promoted.
Present, T0, T1, T2, provider, mesh, solver, engineering, physical, search,
B00, B04 and R01–R10 remain false.

## Validation and acceptance scope

The final independent recheck parsed all reviewed JSON, reconciled AD-36
bytes/SHA, verified the six/seven fresh-input records and required fields,
rechecked product counts/result unions/forbidden edges, confirmed absent future
publication paths, scanned APIs and control characters, and passed scoped
`git diff --check`. The raw PID/UTC/exit/stdout/stderr receipt and input/output
hashes are in the task-owned R2 review sidecar.

This is `pass_limited` for the repaired static absence audit and finite future
G1/G2 publication work-order boundary only. It does not authorize dispatch,
present publication, source-backed authority, candidate identity creation,
T0/T1/T2, UP2, physical execution or any R01–R10 credit. Cleanup found no
task-owned temporary or unrelated files; all historical evidence is retained.
