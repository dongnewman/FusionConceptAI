# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC independent static precheck R1

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The additive files are confined to the declared realization precursor and
the static evidence correctly keeps the work order at
`planned`/`proposal`/`accepted=false`. The source has typed records, a fixed
replacement entry point, separate stale checks and no physical promotion
path in its normal constructors. A serial focused run must remain blocked,
however, until the contract mismatches and state/negative-control gaps below
are repaired.

No Julia, DESC, provider, mesh, solver, engineering or physical command was
run. This review writes only this report and its manifest.

## Passed static boundaries

The source file has no import or include of T0, control, binding or feedback
implementation and does not edit old G3 V5, V1, package or registry files.
The only named edit operation is `replace_source_payload`; there is no dynamic
field path, wildcard, insert, delete or generic rebind API. The normal source
and replacement constructors use typed `QualifiedRefV1`, `GenomeContractRef`,
`UnitSignature`, `Digest256` and exact `Rational{Int64}` values. The four
source/field/return/heat ports are required, roles are unique, units match,
the numeric source balance is closed, capacity is positive and the normal
local result keeps `physical_resolution=:unknown`.

The source-record hash is computed from a body excluding its own hash and
content/operation hashes. The source-content hash excludes itself while
including the source-record hash. The operation hash excludes the resulting
state hash. `replace_source_payload` checks operation integrity, key
identity, expected state hash, expected source-content hash, replacement
payload validity and source-record ref/hash before constructing a result.
Those checks are structurally separate, and the failure path returns the
prior state.

The protected-path audit shows no tracked diff for the old G3 V1/V5, T0,
package or registry paths. The current checkout has the old G3, T0 and
package paths as pre-existing untracked files (only the registry path is
tracked at HEAD), so Git cannot supply a HEAD baseline for those files. Their
current hashes are recorded in the manifest, and this review does not claim a
strong before/after equality beyond the write-scope exclusion.

## Blocking findings

### PRECHECK-F1: child-kind identity disagrees with the frozen contract

Core AD-31 requires the child key component `child_kind=:realization`. The
implementation fixes `G3_REALIZATION_CHILD_EDIT_KIND_V1` to
`:realization_source`, and the focused test constructs that value as well.
This changes the candidate/parent/kind/child-id identity and cannot be left
for a runtime interpretation. Change the source and test to the canonical
kind, or obtain an explicit synchronized contract decision before execution.

### PRECHECK-F2: the body does not implement the declared closed realization body

`G3RealizationSourceBodyV1` currently contains only source/owner strings, four
ports, four power scalars, capacity/unit and residual. It has no typed
components, material domains, manufacturing domains, ledger accounts,
ledger entries or ledger closures, despite the AD-31/R3 work order requiring
those fields and their unique-ID/reference/link invariants. It also does not
reject duplicate port IDs or enforce role/direction compatibility; only role
uniqueness and a numeric power equality are checked. The implementation must
add the declared typed body or the architecture owner must explicitly narrow
the contract before a focused acceptance can be considered.

### PRECHECK-F3: absent and contradiction classification is not fail-closed

The typed-absent state hash is derived from only `(key, reason)` and omits the
required absent provenance slot names. `g3_realization_admit_v1` maps every
payload validation error to `:terminal_deferred`, and
`g3_realization_admit_source_v1` catches constructor errors as deferred
absence. A malformed body, foreign parent/contract identity or other
structural contradiction therefore does not reliably produce
`contract_admission=:fail_closed`. Preserve typed absence only for missing
authority/provenance, include the exact missing slot set in the absence hash,
and route structural conflicts to fail-closed results with the old state
unchanged.

### PRECHECK-F4: operation IDs are not unique over the state history

The replacement operation rejects an ID only when it equals the immediately
previous `last_operation_id`. After operation A and then B, a new operation
reusing A's ID can pass if it supplies the current expected hashes. The state
stores no operation history or equivalent replay identity. The operation
order/duplicate negative control must be strengthened so an ID cannot be
reused anywhere in the accepted chain.

### PRECHECK-F5: initial-state lineage and status constructors need closure

On every replacement the implementation recomputes `initial_state_hash` from
the replacement payload as though it were a new initial state. The state
field therefore no longer identifies the original initial state after the
first edit. Preserve the immutable initial hash through a replacement, while
recomputing the current state hash from the new source and operation.

The public outer constructors for `G3RealizationSourceStateV1` and
`G3RealizationOperationReceiptV1` accept arbitrary `Symbol` values, including
a caller-supplied physical status. Add closed constructors or validation so
only the declared status vocabulary is constructible and local code cannot
manufacture a physical promotion. Add negative controls for direct forged
status/state values.

## Exit decision

The implementation may not enter the one serial focused Julia run under the
current precheck. The worker exit gate is a source/test revision that closes
F1-F5, adds production-API negative controls for child identity, body
invariants, typed absence versus fail-closed, operation order/duplicate and
status isolation, then refreshes the implementation receipts. Passing static
JSON/plan/diff checks or a later runner exit alone cannot accept the child or
grant T0/T1, provider, engineering, physical, search, B00/B04 or R01-R10
credit.
