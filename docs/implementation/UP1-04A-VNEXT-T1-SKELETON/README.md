# UP1-04A VNext T1 skeleton (R5)

Status: `prepared_not_executed` (2026-09-18 CST); claim ceiling:
`contract_only`.

This is a static-only T1 contract boundary. It does not run Julia or DESC,
invoke a factory/provider/mesh/solver, perform source I/O, or modify the
existing v5 integration entry point. T0 remains an unresolved dependency for
runtime use.

## Scope

The owned surface is limited to:

* `src/Contracts/CandidateStatePackageV5Next.jl`
* `src/GenomeV5/Integration/VNextGenomeV5Integration.jl`
* this directory's documentation and `static_qa.ps1`

The two additive Julia files remain excluded from `src/FusionConceptAI.jl`.
No source file outside that additive pair is part of this T1 skeleton.

## Admission and known-gap boundary

`vnext_t1_admit_skeleton_v1` accepts only the closed checked-present T0 result:

```
status        = :local_checked_present
resolution    = :resolved
accepted      = false
claim_ceiling = :contract_only
```

The transport must have the same candidate and recomputed prior bundle hash,
canonical prior bytes, valid status, empty errors, and canonical feedback
order. Its only permitted gap tuple is `()` or
`(:g3_child_terminal_deferred,)`. Children are exactly
`(:realization, :control, :binding)` in that order. A known gap requires all
three children to be typed absent with `:terminal_deferred` or
`:typed_absent` status; no gap requires all three children to be typed present.
Unknown, multiple, mixed, or reordered gap/child states fail closed.

An absent or invalid T0 input produces no package. Missing input is
`terminal_deferred`; invalid, contradictory, or mismatched input is
`fail_closed`. The accepted projection is still
`prepared_not_executed`, `terminal_deferred`, `accepted=false`,
`claim_ceiling=:contract_only`.

## Closed package identity

The package uses the dedicated `VNextT1NoLegacyReceiptV1`. It has zero
`legacy_refs`, a candidate-bound identity hash, and a receipt hash recomputed
from the complete receipt payload. No legacy receipt or migration-receipt
dependency is accepted.

Schema, canonicalization, and compatibility-profile versions and hashes are
package-owned fields. They are included directly in `package_hash`, separate
from the three layer-derived identity hash tuples. Factory IDs, versions, and
the frozen G1/G2/G3 plus G3-child contract references are independently
checked, so a self-consistent forged receipt is rejected.

Every T1 receipt, declaration, child projection, and T0 output projection owns
its exact bytes through `VNextT1CanonicalBytesV1` (an immutable tuple), and
rechecks the hash of those owned bytes. Mutable T0 byte-vector fields are not
retained as T1 package fields. Declaration source/declaration bytes, locators,
hashes, factory envelopes, child joins, feedback target/body joins, and the
label-erased semantic identity remain candidate-bound.

## Static negative matrix

`static_qa.ps1` contains 16 assertion-only negative cases. They cover missing
or invalid gates, unknown/multiple/child-inconsistent known gaps, legacy
receipt or non-empty legacy refs, package-owned hash drift, feedback order and
duplicate IDs, present/absent child joins, mixed or reordered children,
factory/contract forgery, and mutable owned-byte/hash drift. Every negative
case must return without a package. The exact checked-present gate is the only
positive structural case and remains `prepared_not_executed/contract_only`.

Run only the PowerShell check in this directory:

```text
pwsh -NoProfile -File docs/implementation/UP1-04A-VNEXT-T1-SKELETON/static_qa.ps1
```

The result is static evidence only. It gives no runtime, provider, mesh,
solver, engineering, physical, or authority credit. Keep T0 unresolved and
T1 `prepared_not_executed` until an independently reviewed, serialized
runtime lane supplies fresh evidence.
