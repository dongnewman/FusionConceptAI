# Static handoff report — UP1-04A VNext T1 skeleton (R5)

Date: 2026-09-18 (Asia/Shanghai)

## Result

| Item | Result |
| --- | --- |
| T0 runtime | unresolved; not run |
| T1 | `prepared_not_executed` |
| Claim ceiling | `contract_only` |
| Package/runtime credit | none |
| Julia/DESC/provider/mesh/solver | not invoked |
| Source files changed | none |
| Commit | none |

Only the designated documentation/static-QA surface was changed. The two
additive Julia declarations remain excluded from the main module and do not
alter current runtime behavior.

## R5 contract alignment

The documentation and static check now match the current R5 source:

* `VNextT1NoLegacyReceiptV1` is the only accepted receipt shape; it is
  candidate-bound, hash-checked, and has `legacy_refs::NTuple{0,...}`.
* T0 admission allows only the known gap
  `(:g3_child_terminal_deferred,)`; it requires all three typed-absent
  children for that gap and all three typed-present children for no gap.
* Package-owned schema/canonicalization/profile versions and hashes are part
  of `package_hash`, independent of layer-derived hashes.
* `VNextT1CanonicalBytesV1` owns immutable tuple bytes and verifies their
  hashes; mutable T0 byte-vector fields are not retained by T1 projections.
* Frozen factory IDs/versions and G1/G2/G3 plus G3-child contract references
  are checked before projection.

## Static evidence

Command:

```text
pwsh -NoProfile -File docs/implementation/UP1-04A-VNEXT-T1-SKELETON/static_qa.ps1
exit=0
STATIC_NEGATIVE_MATRIX=16
STATIC_QA=PASS
RUNTIME=NOT_RUN
T0=UNRESOLVED
T1=PREPARED_NOT_EXECUTED
```

The 16-case matrix is assertion-only. It fabricates no valid package and
provides no runtime, authority, engineering, provider, mesh, solver, or
physical evidence.

## Review boundary

Before any runtime inclusion, independently recheck the concrete T0 result
identity, prior bytes/hash, known-gap child semantics, declaration and
feedback joins, frozen factory/contract identities, immutable byte/hash joins,
label-erased identity, and package-owned hash participation. Preserve
`prepared_not_executed`, `terminal_deferred`, `accepted=false`, and
`contract_only` until that review and fresh runtime evidence exist.
