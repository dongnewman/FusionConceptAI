# UP1-04A VNext T1 skeleton (R3)

Status: `prepared_not_executed` (2026-09-18 CST)

This is a static-only T1 contract skeleton. It does not run Julia, read a
source file, call a factory, build a provider/mesh/solver result, or modify the
existing v5 integration entry point. The T0 source-backed runtime and its
authority recheck remain an unresolved dependency.

## Scope

Owned additions are limited to:

* `src/Contracts/CandidateStatePackageV5Next.jl`
* `src/GenomeV5/Integration/VNextGenomeV5Integration.jl`
* this documentation and `static_qa.ps1`

The two Julia files are intentionally not included by `src/FusionConceptAI.jl`.
When a future implementation includes them, it must load the existing local T0
transport and local authority-recheck declarations first.

## Admission boundary

`vnext_t1_admit_skeleton_v1` requires an explicit
`VNextAuthorityRecheckLocalResultV1` whose four gate fields are exactly:

```
status        = :local_checked_present
resolution    = :resolved
accepted      = false
claim_ceiling = :contract_only
```

No object, a structural look-alike, a typed-absent result, a stale result, or a
contradictory result produces a package. Missing input is `terminal_deferred`;
invalid/contradictory input is `fail_closed`. The valid projection remains
`prepared_not_executed`, `terminal_deferred`, `accepted=false`,
`claim_ceiling=:contract_only`.

The static negative matrix is expressed as guards, not executable fixtures:

| Input condition | Required result | Package |
| --- | --- | --- |
| no T0 recheck object | `terminal_deferred` | absent |
| structural look-alike or wrong gate fields | `fail_closed` | absent |
| T0 bundle/hash/candidate mismatch | `fail_closed` | absent |
| missing declaration/child/feedback join | `fail_closed` | absent |
| exact checked-present T0 gate | `prepared_not_executed` | contract-only projection |

R3 closes the six independent rejection points: no `Any`, open `NamedTuple`,
or open `Vararg` fields; the canonical prior bundle bytes/hash and a closed
typed T0-output projection are bound to the supplied transport and candidate;
package-owned schema, canonicalization, and compatibility-profile hashes are
stored and included in the package hash; factory axes are checked against the
exact per-layer projection (never against the outer local axis tuple); receipt
bytes are reconstructed and compared with the canonical factory-result
envelope rather than self-hashed only; present and absent child source/body/
identity joins are validated, including absent status/reason/receipt/source
path in the label-erased identity; and feedback bodies are joined to candidate,
source, declaration, target, authority, and target-body hashes.

## Encoded joins

The declaration carries exactly G1/G2/G3; each declaration keeps four ordered
axes, source bytes, declaration bytes, locator, source/declaration hashes and
closed receipt projections. The package checks raw byte-to-hash and
locator-to-hash joins. The gate retains only canonical prior bytes and a
closed output projection/identity, never the open T0 body, output, or
transport.
The G3 child slots are exactly `realization`, `control`, and `binding`.
Feedback is candidate-bound, limited to G1/G2 targets, and target IDs are
unique. A component-count receipt records three declarations, three child
slots, three components, and the observed feedback count.

`semantic_identity` is computed from a label-erased projection: semantic body
labels are intentionally omitted, while body bytes, refs, axes, children,
feedback and source/declaration hashes remain bound. The only migration receipt
accepted is a fresh `v5_fresh_migration_receipt` with no legacy mapping.

## Static QA and review plan

Run only the PowerShell static check in this directory. Do not invoke Julia.
The executable negative matrix covers missing/invalid gates, prior-byte/hash
drift, outer-vs-layer axis confusion, receipt-envelope mutation, declaration
and feedback joins, present/absent child identity, and package-owned identity
hash drift. The check also verifies the two additions are not included in the
main module, contain the required fail-closed gate and fields, and do not call
the legacy positive integration builder or perform source/runtime I/O.

Before any runtime implementation is proposed, an independent review should
recheck: (1) T0 result type identity and canonical bundle-byte/hash joins, (2) all three
declaration and child arities, (3) four-axis order and source/declaration
receipt equality, (4) label-erased identity recomputation, and (5) fresh
migration receipt equality, (6) explicit schema/canonical/profile hashes, and
(7) feedback target declaration/body hashes. That review must preserve `T0 unresolved`,
`T1 prepared_not_executed`, `contract_only`, and no provider/mesh/engineering/
physical credit unless fresh runtime evidence is separately supplied.
