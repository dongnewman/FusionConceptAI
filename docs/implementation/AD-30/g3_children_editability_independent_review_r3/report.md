# AD-30 G3 realization source-edit proposal R3: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`pass_limited`; `accepted=false`; `review_pending=true`.

R3 closes the four material R2 objections sufficiently for a bounded
contract-only implementation dispatch. It separates source-content identity
from initial/current state identity, adds a typed parent G3 declaration
ref/hash and additive child contract identity, makes source-record hashing
non-recursive, and explicitly separates `contract_admission` from
`physical_resolution`. The proposal remains only a reviewed work-order
boundary; it does not accept an implementation or an actual child.

This review writes only its report and manifest. No Julia, DESC, provider,
mesh, solver or physical command was run.

## R2 correction checks

### Source, state and stale hashes

R3's recipe at `revised_proposal.md:100-144` correctly defines three distinct
layers:

* `source_record_hash` excludes itself and all source-content/operation hashes;
* `source_content_hash` includes the key, parent identity, child contract,
  body and the already sealed source-record hash, while excluding itself; and
* `initial_state_hash`, operation hash and resulting state hash are separate.

The initial present and typed-absent hashes use a zero-operation marker. The
operation carries both `expected_prior_state_hash` and
`expected_prior_source_content_hash`, and R3 gives independent
`fail_closed:stale_state_hash` and `fail_closed:stale_source_content_hash`
results with the prior state unchanged. The operation hash excludes the
resulting state hash, so the recipe is acyclic and the operation chain remains
transitively bound through the expected prior hashes.

The focused negative controls explicitly cover initial-state construction,
successful replacement, both stale paths, forged hashes and unchanged prior
state. This closes the R2 stale-hash objection at the contract level.

### Parent and additive child identity

R3's exact types at `revised_proposal.md:26-67` retain the required key
`(candidate_ref, parent_g3_declaration_hash, child_kind=:realization,
child_id)`. The payload now additionally carries a typed
`parent_g3_declaration_ref` and the matching parent hash, plus a closed
`G3RealizationChildContractIdentityV1` containing an additive
`GenomeContractRef` and independently computed identity hash. The proposal
explicitly rejects nullable or label-derived child identity and rejects T0
refs as parent declaration refs. This is sufficient for a later field-by-field
T1 mapping without reinterpreting an old V5 or T0 identity.

### Closed provenance and non-recursive source record

R3 makes the source record a closed type with exactly the four named
provenance slots and a `source_record_hash` computed without its own hash or
any content/operation hash. The only operation provenance input is the closed
`G3RealizationSourceRecordRefV1`; the enclosing source-content hash includes
the sealed record hash. The proposal therefore has a finite, inspectable
source-record/content-hash chain with no self-reference. Missing slots remain
typed absence and `terminal_deferred`; conflicting values or candidate/source
hashes remain `fail_closed`.

### Dual status axes

The state at `revised_proposal.md:82-95` carries both
`contract_admission` and `physical_resolution`. The former is limited to
typed local construction, identity and provenance classification. The latter
is restricted to `unknown` or `terminal_deferred` in this slice, and R3
explicitly forbids a constructor, edit, local hash, receipt, runner exit,
provider label or old receipt from promoting it. This correctly prevents a
local editable source body from being presented as an actual or engineering
result.

## Scope, source support and dependency checks

The slice remains realization-only and uses one fixed atomic
`replace_source_payload`. It excludes dynamic paths, wildcard/patch lists,
insert/delete/rebind, control, binding, feedback, provider and physical work.
The existing `RealizationGenomeV5` source supports the listed typed resource
port, component, state/event, material/manufacturing, ledger account/entry and
closure fields. R3 requires new local records and local invariants, so it does
not turn the old V5 object into the new source identity.

The future ownership is disjoint and finite: one new G3 source file, one
focused G3 test file and one implementation archive. The proposal forbids T0
imports/dependencies and T0 child-authority redefinition. This is compatible
with the current T0 owner of `VNextG3ChildStateV1`; T1 remains responsible for
the one lossless downstream mapping. Old G3 V5 files, old bundle,
`CandidateStatePackageV5`, shared entry, registry, core planning files and
historical receipts remain read-only.

The required negatives are executable without physical execution: foreign
candidate/parent/key/child contract, malformed or open body, duplicate IDs,
bad references and units, missing/conflicting provenance, non-recursive hash
reproduction, independent stale-hash paths, forged replacement/operation
hashes, and forbidden T0/old-package/registry substitutions. The planned
focused receipt captures raw streams, hashes, PID and exit code, while the
claim ceiling keeps actual child authority, provider, engineering, mesh,
solver, physical, search, B00/B04 and R01-R10 false.

## Conditions to carry into implementation

These are bounded implementation assertions, not reasons to widen or delay
the slice:

1. The constructor must require exact equality between payload
   `source_uri/source_version` and the embedded source-record URI/version, and
   the operation's `source_record_ref` must equal that record's URI/version/
   hash. Present provenance slots must bind to the child key's candidate;
   absent slots must not be treated as candidate authority.
2. The implementation must keep `contract_admission` and
   `physical_resolution` either in the state identity or as strictly derived
   fields whose derivation is checked from the hashed payload/absence marker.
   A status change must never be silently accepted without the corresponding
   state/receipt identity consequence.
3. The exact parent declaration-ref domain, additive child contract URI and
   profile hashes must be frozen in the new source file. No URI parsing,
   fixture seed, old V5 hash or T0 bundle hash may satisfy them.
4. The initial present state must use the specified zero-operation marker, and
   the focused test must independently recompute source-record, source-content,
   initial-state, operation and resulting-state hashes rather than compare only
   copied expected strings.

With these assertions carried into the implementation contract, no further
architecture change is required for this limited dispatch.

## Evidence boundary

The active DAG remains
`UP1-04A + G1/G2/G3 -> T0 -> T1 -> T2 -> UP1-04A-VNEXT -> UP2-00`.
R3 does not add a core task, alter the schedule, or grant execution credit.
The pre-write worktree snapshot contained 304 porcelain rows; concurrent dirty
state is not attributed to this review.

