# UP1 external blocker closure R4 — integration contract

Status: `contract_draft`; implementation status: `not_implemented`; formal
credit: `none`; `no_publish=true`.

This directory specifies the integration seam between the R3 atomic bundle
prototype and the six R4 observation/verification modules. It is a design
contract only. It does not claim that these modules are wired together,
implemented, tested, externally connected, or accepted by the parent goal.

The contract is intentionally additive. It does not edit the 39-node DAG,
R01–R10, production source, tests, registries, AD records, credentials,
external endpoints, or heavy-lane launchers.

## Non-negotiable result ceiling

Every intermediate and final result carries these fields and values until a
separate root-owned authority policy explicitly replaces this contract:

```text
formal_credit = none
no_publish = true
authority_credit = false
```

`accepted_all` means only that one local packet set passed the applicable
local structural/policy checks. It is not an external acknowledgement,
authority receipt, publication permission, T0/T1/T2 credit, or parent-goal
closure. `TEST_ONLY`, `local_observed`, `accepted_local`, `unverified`, and
`valid_for_declared_scope` are non-evidence/local states.

## Reachable external source-axis route

The source-axis seam has two deliberately separate stages. A received raw
bundle may carry `state=EXTERNAL_ISSUED` and
`provenance_class=external_issued`; this is an input label only. The local
offline validator may check its schema, source identity, four-axis completeness
and exact edges, but its result is never authority. A distinct external
verification adapter must then validate the pinned root, ordered chain,
signature, trusted time, revocation, freshness/replay, candidate/source/run
binding, G2 reference and independent review. Only that adapter may derive
`state=externally_verified` with `authority_evidence=true`, while retaining the
raw bytes and all verification receipts.

Thus an offline prototype response such as
`external_material_not_supported` means that the external-verification route
is not implemented/available; it is not a reason to treat `TEST_ONLY`, local
fixtures, local CAS/spool, system trust-store observations, or other local
products as externally verified. Until the adapter emits the derived state,
G8/G9 remain unsatisfied and `T1_go=false`, `T2_go=false`.

## Frozen sequence

The only permitted formal order is:

```text
T0 snapshot
  -> external-input recheck gate
  -> T1
  -> T2
```

The recheck is a gate between T0 and T1, not a replacement for T0 and not a
shortcut to T1/T2. A failed, absent, stale, or unverified input leaves the
prior T0 bytes and SHA-256 unchanged and returns `terminal_deferred` or
`fail_closed` according to the failure taxonomy. T1 cannot consume a local
`accepted_all` or a synthetic checked-present record.

## Contract contents

- [Interface matrix](interface-matrix.md): call order, inputs, outputs,
  binding fields, and mutation rules for R3 and each R4 module.
- [Failure taxonomy](failure-taxonomy.md): normalized failure classes,
  precedence, and result mapping.
- [Integration acceptance gates](integration-acceptance-gates.md): cumulative
  gates for all-or-reject, CAS/receipt binding, external recheck, and the
  preserved T0 → recheck → T1 → T2 sequence.
- [File hash manifest](file-hash-manifest.json): SHA-256 snapshot of this
  contract and the referenced R3/R4 interface files. The manifest is
  self-excluded to avoid circular hashing.

## Implementation boundary

An eventual implementation may call the interfaces in the matrix, but may
not infer authority from a version string, filesystem presence, local clock,
local spool receipt, successful parser result, or a passing synthetic fixture.
It must preserve exact raw bytes before parsing, reject a partial set, bind
all accepted material to one candidate/source/run scope, and fail closed on
any contradiction. No heavy Julia/DESC/solver task is part of this contract.
