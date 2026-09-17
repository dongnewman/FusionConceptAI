# AD-30 G3 realization source-edit proposal R2: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

R2 fixes the principal R1 objection. It is now a realization-only,
candidate-owned, closed typed source body with one fixed
`replace_source_payload` operation. It explicitly removes generic edit,
control, binding and feedback scope; prohibits T0 imports and authority
duplication; preserves old V5/package/registry read-only; and keeps local
software evidence below actual, engineering and physical evidence.

The proposal is not yet ready for implementation because the operation hash
state comparison is inconsistent, and the child/source identity still lacks
an explicit parent declaration reference and child contract identity. The
provenance operation field is also not typed, and the present-state status does
not explicitly separate contract admission from physical resolution. These
are small, finite corrections, but they affect identity and stale-edit safety
and must be closed before a Luna implementation is dispatched.

This review only writes this report and its manifest. No Julia, DESC, provider,
mesh, solver or physical command was run.

## Checks that pass

The revised scope at `revised_proposal.md:9-24` is appropriately bounded:

* the first slice is realization-only;
* the source body is required to be closed and typed, with no `Any`, open
  `NamedTuple`, dictionary, JSON blob or dynamic path walker;
* the only operation is complete-payload replacement;
* control, binding, feedback and generic rebind work are deferred; and
* T0 remains a downstream authority/mapping concern.

The listed realization fields match the existing typed V5 shape. The old
source provides typed resource ports (`port_id`, kind, direction, unit,
account), components (capacity, capacity unit, material/process, passive,
initial states and events), material/manufacturing domains, ledger accounts,
entries and closures. Its network constructor already supplies typed tuple
boundaries, per-category unique IDs and basic type checks. R2 correctly
requires the new source body to add its own reference, unit, ownership,
closure, capacity and provenance checks rather than aliasing the old object.

The proposed child key at `revised_proposal.md:59-67` includes the required
candidate reference, parent G3 declaration hash, fixed `realization` kind and
child ID. The four named provenance slots at `:69-94` are included in the
source-content hash, with typed absence and `terminal_deferred` for missing
source schema/profile/receipt evidence. Foreign/stale/conflicting values are
correctly classified as `fail_closed`.

The negative controls and exit gate at `:154-187` are executable as a future
software contract gate: malformed typed bodies, duplicate/reference/unit/
closure/capacity errors, typed absence, stale hash, forged replacement hash,
dynamic operation rejection, provenance forgery and old-file protection are
all testable without entering a provider or physics backend. The manifest
also preserves the AD-30 and parent-goal claim ceiling.

## Required corrections

### 1. Fix the stale-hash comparison and initialize state hashes

At `revised_proposal.md:98-117`, the operation is named
`expected_prior_source_content_hash`, but acceptance is described as comparing
it with the “current state hash”. Those are different identities: the state
hash additionally contains the operation hash and status. Comparing them can
reject a valid edit or make stale detection meaningless.

Choose one closed rule and use it consistently. The safer rule is to carry
both `expected_prior_state_hash` and `expected_prior_source_content_hash`,
require both to match the current state, and leave the prior state byte-for-
byte unchanged on either mismatch. If only one is retained, rename it
`expected_prior_state_hash` and define the current state hash unambiguously.
The first present state also needs a canonical `initial_operation` marker (or
an explicit initial-state hash) so its state hash is defined before the first
replacement. The focused test must cover initial hash, one successful edit,
and both stale source-hash and stale state-hash failures.

### 2. Carry the parent declaration ref and child contract identity

The key has the parent G3 declaration hash, but R2 does not require a typed
parent declaration reference or a child layer contract reference in the
payload. The hash-only key cannot by itself perform the exact T1 mapping
required by AD-30, and `source_uri/version` is not the same thing as the
child's public contract identity. Add to the payload/state, with explicit
canonical hash coverage:

* a typed `parent_g3_declaration_ref` together with the existing declaration
  hash; and
* a typed additive realization `child_contract_ref` (including its schema,
  canonicalization and applicability identity), or a typed absence record if
  that contract is intentionally deferred.

The key may remain exactly
`(candidate_ref, parent_g3_declaration_hash, child_kind, child_id)`, but the
payload must preserve the full parent/child ref-and-hash pair. T1 should later
define the one lossless mapping to its package child state. No URI parsing,
old V5 hash alias or T0 bundle hash may provide that mapping.

### 3. Make provenance and status types explicit and acyclic

`provenance_ref` in `G3RealizationReplaceSourcePayloadV1` is currently
untyped. It must be a closed typed ref/receipt or typed absence, with a
specified canonical body. Also distinguish the evidence-slot
`source_record_hash` from the enclosing payload's `source_content_hash`.
Each slot's source hash must refer to an independent source record and must
never be computed from the enclosing payload, avoiding a hash recursion.

The `present` state at `:84-94` is a materialized local source payload, not an
actual physical child. Add explicit fields or a mandatory status contract:
`contract_admission` may be valid/deferred/fail-closed, while
`physical_resolution` remains `unknown` or `terminal_deferred`. A source edit,
child hash or passing local test must not change the latter.

## Dependency and ownership decision

The no-T0-import rule is correct and should remain mandatory. T0 currently owns
`VNextG3ChildStateV1` as its three-entry typed-absent transport state. The new
source-edit slice must not redefine or import that type. It should produce
only its local realization source state; T1 must later specify the single
field-by-field mapping into `CandidateStatePackageV5Next`/transport state.
That later mapping is a dependency, not a reason to block this contract-only
slice, and it must not be inferred from matching names or URI strings.

No control, binding, feedback, provider, engineering, mesh, solver, physical,
search, B00/B04 or R01-R10 credit is available from this proposal or a future
local edit receipt. The old V5 files, old package, integration entry, shared
entry, registry and historical receipts remain read-only.

## Recommended finite dispatch after correction

After the four corrections above, the proposed ownership is finite and
appropriate:

* `src/GenomeV5/G3/G3RealizationSourceEditV1.jl`;
* `test/GenomeV5/G3/g3_realization_source_edit_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R2/`.

The implementer may use the current G3 V1 source and old realization types as
read-only field-shape inputs, but must not import T0 source types or modify
old G3/package/registry/core files. The different Luna reviewer should
recompute hashes independently, inspect the initial and replacement state
recipes, verify typed absence and stale-state preservation, and check dirty
worktree protection. The only possible result is
`accepted_limited` for this contract-only slice; actual child authority and
all physical/engineering claims remain deferred.

## Evidence boundary

The active DAG remains
`UP1-04A + G1/G2/G3 -> T0 -> T1 -> T2 -> UP1-04A-VNEXT -> UP2-00`.
This review does not alter the core manifest or schedule. The pre-write
worktree snapshot contained 305 porcelain rows, including prior review output;
that concurrent dirty state is not attributed to this review.

