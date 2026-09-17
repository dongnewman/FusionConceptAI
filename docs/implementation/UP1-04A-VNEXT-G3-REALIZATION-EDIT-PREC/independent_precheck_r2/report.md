# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC repair R2 independent precheck

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The repair closes several R1 items: the child kind is now `:realization`, the
body has typed component/material/manufacturing/ledger records, direction and
ownership checks were added, missing slots participate in absence identity,
operation history is stored, initial-state preservation was attempted, and
state/receipt/result status constructors are closed. The source remains
additive and the normal replacement path keeps physical resolution unknown.

A serial focused run is still blocked because the repaired source has a
deterministic initial-state constructor contradiction, an unresolved port
identity invariant, and an incomplete contract status vocabulary. The tests
also do not provide all requested production-API negative controls for
ledger-unit/reference and invalid promotion behavior. This is a static
precheck only; no Julia or DESC command was run.

## R1 items that are visibly repaired

The implementation and test use the canonical `child_kind=:realization`.
`G3RealizationSourceBodyV1` now carries typed components, material domains,
manufacturing domains, ledger accounts, entries and closures. It checks
component/material/process/account/entry/closure references, owner scope for
ports and accounts, role-compatible directions, component capacities, ledger
units and the source/field/return/heat coefficient balance. The source and
test remain in the declared file ownership; no T0, control, binding or
feedback implementation is imported.

The state includes an ordered operation history, rejects IDs already anywhere
in that history, carries the original `initial_state_hash` through replacement
and includes history in the current state hash. Typed absence records an
ordered missing-slot tuple, and the admission path distinguishes a
provenance-only absence from other payload errors. Public state, receipt and
result constructors restrict their status symbols, and replacement emits
`physical_resolution=:unknown`.

The source-record hash still excludes its own hash and content/operation
hashes; source-content hashing excludes itself; and operation hashing excludes
the resulting state hash. The replacement path checks key, operation hash,
duplicate history, expected state/source hashes, replacement payload and
source-record reference before constructing a result.

## Blocking findings

### PRECHECK-R2-F1: replacement cannot pass the frozen initial-state check

`G3RealizationSourceStateV1` validates `initial_state_hash` against
`_g3rce_initial_hash(key, status, source_content_hash, ...)` using the *current*
state payload hash (source lines 601-602). The replacement path correctly sets
`new_initial = state.initial_state_hash` (lines 782-790), but it also changes
`source_content_hash`. Therefore the state constructor rejects every
source-changing replacement as an initial-hash mismatch; the outer catch turns
that into `:program_exception` instead of `:applied`. The focused test expects
the changed payload to apply, so this is a deterministic runtime/API failure.
The constructor must validate the immutable initial identity separately from
the current payload, or the transition must supply a non-recursive initial
identity that remains valid across the whole operation history.

### PRECHECK-R2-F2: duplicate port IDs remain possible

The body checks unique role names but never checks that the four
`G3RealizationSourcePortV1.port_id` values are unique before constructing
`port_map`. A duplicate ID can collapse the map and make component, ledger and
role resolution depend on insertion order. Add an exact port-ID uniqueness
check and a focused production-constructor negative control. The current test
covers direction/ownership but does not cover this ambiguity.

### PRECHECK-R2-F3: declared `program_exception` status is still unconstructible

`G3_REALIZATION_CHILD_EDIT_CONTRACT_STATUSES_V1` declares
`:program_exception`, but the state constructor accepts only
`:declared_consistent`, `:terminal_deferred` and `:fail_closed` (lines
574-575). The implementation therefore cannot materialize the full declared
contract status vocabulary, while replacement and result code still expose a
program-exception path. Align the closed status contract and add a direct
invalid/promotion negative control through the production API.

### PRECHECK-R2-F4: required ledger and authority negative controls are incomplete

The body has static checks for ledger units, references, ownership and balance,
but the focused test only exercises a closure-balance mismatch, direction and
owner mismatch. It does not drive the production constructor/admission path
with a wrong ledger unit, unresolved account/component/port reference,
duplicate port ID, or an invalid closure-domain assignment. The test also
does not attempt a forged state/receipt with a non-unknown physical status via
the complete production result path. Add these source-backed negative controls
before claiming the exit gate.

## Protected paths and evidence ceiling

No tracked diff is present for the protected registry path, and this review
writes only its own report and manifest. The old G3 V1/V5, T0 and package files
are pre-existing untracked files in this checkout, so Git supplies no HEAD
baseline for them; their observed hashes are recorded in the manifest and do
not constitute before/after proof. Old package/registry/source authority,
T0, control/binding/feedback and physical paths remain outside this review's
write scope.

The work order remains `planned`/`proposal`/`accepted=false`, and this review
does not grant implementation acceptance, actual-child authority, T0/T1/T2,
provider, mesh, engineering, physical, search, B00/B04 or R01-R10 credit.

## Exit decision

Do not run the serial focused Julia gate until R2-F1 through R2-F3 are fixed
and R2-F4's negative controls are added. After those repairs, rerun static
JSON/plan/diff/hash checks and obtain a fresh independent precheck. A passing
runner or document receipt alone cannot promote physical or engineering
status.

