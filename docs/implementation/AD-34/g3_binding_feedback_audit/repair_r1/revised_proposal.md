# AD-34 G3 binding / feedback architecture repair R1

Date: 2026-09-15  
Parent record: `../report.md`  
Repair status: `changes_requested` resolved at proposal level; implementation remains blocked  
Repository: `D:\006-Programing\LMC\FusionConceptAI`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Ruling

The R1 repair freezes one binding sibling and no feedback child:

* `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC` is a candidate-owned contract
  precursor with an **immutable source payload** and a separate **editable
  binding body**. Only the editable body, operation receipt, and current
  state change for `insert_link`, `replace_link`, and `delete_link`.
* Feedback remains a read-only transport record. G3 stores only a typed ref to
  one declaration-level upstream authority for each `(candidate, layer)`.
  T0/T1 resolve and compare that authority; a feedback target cannot promote
  itself to `actual`.
* Feedback metadata changes rebuild the parent G3 declaration and then the T0
  bundle. Runtime residual/loss/thermal/deformation values belong to a
  candidate+scenario+solver-input+provider/evidence record. They are not G3
  child fields, T0 declaration fields, binding CAS values, or authority.

The repair is a proposal freeze only. Dispatch remains
`blocked_pending_architecture_repair` until the exact additive contract and
independent review are accepted. No core index, task manifest, source, test,
old package, registry, AD-31, AD-32, or T0 file is changed here.

## Current source and archive refresh

The control archive identity supplied for this R1 review is refreshed as:

| record | R1 supplied identity | local read-only checkout identity | status |
|---|---|---|---|
| control source archive | `7a11562...b4882` | `src/GenomeV5/G3/ControlGenomeV5.jl` SHA-256 `eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135` | comparison input only |
| control focused test archive | `aa34...4fb9` | `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` SHA-256 `aa34bcb8fef7211d071d8f2b3a23fd193e6d0081ecf1908cc3fafa679f794fb9` | comparison input only |
| control implementation/archive status | `review_pending` | `actual_control=false` | preserved |

The two R1 supplied abbreviated identities are retained exactly because the
full archive digests are not readable in this checkout. The local hashes are
freshly recomputed read-only values; the difference is not attributed backward
to AD-31/AD-32 or to the parent audit. No source or test was rewritten to make
the values agree. AD-32 remains `planned`, `scope_status=proposal`,
`accepted=false`, `resolution=review_pending`, and `actual_control=false`.

## 1. Immutable source payload and editable binding body

The future source file is
`src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`. It must define two distinct
layers.

### Immutable source layer

The immutable layer is closed and candidate-bound:

```text
G3BindingChildKeyV1(
    candidate_ref::QualifiedRefV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,       # constructor fixes :binding
    child_id::String)

G3BindingSourceRecordV1(
    payload_schema_version::PresentAxisV1 | AbsentAxisV1,
    canonicalization_profile_version::PresentAxisV1 | AbsentAxisV1,
    applicability_profile_version::PresentAxisV1 | AbsentAxisV1,
    evidence_receipt_version::PresentAxisV1 | AbsentAxisV1,
    source_record_hash::Digest256)

G3BindingSourcePayloadV1(
    key::G3BindingChildKeyV1,
    child_contract_ref::GenomeContractRef,
    child_contract_identity_hash::Digest256,
    source_uri::String,
    source_version::String,
    source_record::G3BindingSourceRecordV1,
    immutable_binding_schema::G3BindingSchemaV1,
    realization_slot::PresentChildBindingV1 | AbsentChildBindingV1,
    control_slot::PresentChildBindingV1 | AbsentChildBindingV1,
    source_content_hash::Digest256)
```

`immutable_binding_schema` contains only fixed admissibility rules: link field
types, permitted directions, ownership relation, closure rule, and the three
operation names. It does not contain a mutable link tuple. The source content
hash is therefore stable across link edits:

```text
child_contract_identity_hash = H(canonical(child_contract_ref))
source_record_hash = H(canonical(
  source_uri, source_version, four_axis_slots))
source_content_hash = H(canonical(
  key, child_contract_ref, child_contract_identity_hash,
  source_uri, source_version, source_record_hash,
  immutable_binding_schema, realization_slot, control_slot))
```

The recipes exclude their own digest and all operation/current-body fields.
Changing the source URI/version, any axis, contract, parent, or child slot is
source publication, not a binding-body edit.

### Explicit editable body and state

The editable body and its hash are separate:

```text
G3BindingLinkV1(
    link_id::String, controller_id::String, sensor_port_id::String,
    actuator_port_id::String, resource_port_id::String, fault_id::String)

G3BindingEditableBodyV1(
    child_key::G3BindingChildKeyV1,
    fixed_source_content_hash::Digest256,
    fixed_child_identity_hash::Digest256,
    links::Tuple{Vararg{G3BindingLinkV1}},
    body_hash::Digest256)

G3BindingStateV1(
    source_payload::G3BindingSourcePayloadV1,
    initial_source_content_hash::Digest256,
    initial_body_hash::Digest256,
    editable_body::G3BindingEditableBodyV1,
    operation_hash::Digest256,
    ordered_operation_history::Tuple,
    state_hash::Digest256,
    contract_admission::Symbol,
    physical_resolution::Symbol)
```

The initial body is derived once from the immutable source payload's declared
initial link set and sealed as `initial_body_hash`; it is not a second source
payload. The fixed identities are:

```text
initial_body_hash = H(canonical(child_key, fixed_source_content_hash,
  fixed_child_identity_hash, initial_links))
initial_source_state_hash = H(canonical(child_key, source_content_hash,
  initial_body_hash, contract_admission, physical_resolution,
  ZERO_OPERATION_HASH, empty_history))
child_identity_hash = H(canonical(child_key, parent ref/hash,
  child_contract_ref, child_contract_identity_hash, source_record_hash,
  source_content_hash, realization_slot, control_slot))
```

`source_content_hash`, `source_record_hash`, `initial_source_content_hash`,
`initial_body_hash`, and `child_identity_hash` are frozen for the lifetime of
this child identity. `body_hash`, `operation_hash`, `state_hash`, and the
ordered operation history are the only identities affected by a permitted link
edit. A binding identity is never a hash of a mutable body alone.

## 2. Upstream authority is unique

The feedback route uses one typed declaration-level authority reference per
`(candidate_ref, target_layer)`. The future transport type is T0-owned and
immutable:

```text
G3DeclarationAuthorityRefV1(
    candidate_ref::QualifiedRefV1,
    layer::Symbol,                 # :G1 or :G2
    declaration_ref::QualifiedRefV1,
    declaration_hash::Digest256,
    canonical_bytes_hash::Digest256,
    authority_status::Symbol,      # :typed_absent | :present | :actual_claim
    attestation::Symbol,
    source_receipt_ref::Union{Nothing,Digest256})
```

The G3 feedback target holds this typed ref and target path metadata. It does
not hold an independently promotable actual authority. T0/T1 resolve exactly
one declaration authority object by `(candidate_ref, layer)` and require exact
canonical-byte equality with the declared ref/hash. Equality of a URI, label,
fixture seed, or separately supplied hash is insufficient.

The following are T0/T1 fail-closed controls; they are specified here and are
not implemented or added to T0 by this repair:

* absent declaration ref with `actual_claim` status;
* foreign candidate, wrong layer, wrong declaration ref, or wrong declaration
  hash;
* canonical bytes differ while URI/version or digest text is equal;
* two authority records for one `(candidate, layer)`;
* G3 feedback says `actual_claim` while the resolved declaration authority is
  absent, stale, contradictory, or lacks a trusted receipt;
* feedback target path/quantity/unit/direction/sign disagrees with the
  declaration-level target contract; and
* a changed upstream declaration is reused under the old declaration hash.

Missing upstream authority remains a typed absence and
`terminal_deferred`. A feedback record cannot clear its own gap. Only the
source-backed declaration authority and the later T0/T1 exact join can change
the resolution dimension; this still does not create physical authority.

## 3. Feedback metadata versus runtime numerical feedback

Feedback metadata consists of target layer/ref/path, quantity label, unit,
direction, sign, source ID and authority ref/status. Editing any of it means:

```text
new G3 declaration body/hash
→ new T0 feedback transport bytes/bundle hash
→ later T1 exact package identity
```

There is no feedback-child file, feedback-child state, feedback-child CAS, or
feedback-child operation receipt. The exact future feedback file set is empty;
the read-only owner remains:

* `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl`
* `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl`
* `docs/implementation/AD-30/t0_readiness_audit/report.md`
* `docs/implementation/UP1-04A-VNEXT-T0/software_precursor_acceptance.md`

The existing G3 fixture is an input/oracle only and is not a feedback
authority. If T0 later introduces a named transport record, it must remain
inside its existing T0 source/test scope and be immutable.

Runtime values such as residual, loss, thermal load, or deformation are
evidence records with this minimum identity:

```text
RuntimeFeedbackEvidenceKeyV1(
    candidate_ref, scenario_hash, solver_input_hash,
    provider_manifest_hash, backend_revision,
    numerical_configuration_hash, evidence_id)
```

Their values, units, uncertainty, applicability, execution status, artifact
refs, independence group and claim ceiling belong to candidate-bound evidence.
They never enter a G3 declaration, T0 metadata record, binding editable body,
or CAS operation. They cannot promote G1/G2 authority or any G3 `actual`
status.

## 4. Exact child slots and promotion check

Every binding source payload has exactly two immutable child slots. The slot
sum is explicit and closed:

```text
PresentChildBindingV1(
    child_kind::Symbol,            # :realization or :control
    candidate_ref::QualifiedRefV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_ref::QualifiedRefV1,
    child_contract_ref::GenomeContractRef,
    child_contract_identity_hash::Digest256,
    source_uri::String,
    source_version::String,
    source_record_hash::Digest256,
    source_content_hash::Digest256,
    child_identity_hash::Digest256,
    status::Symbol)                  # :present

AbsentChildBindingV1(
    child_kind::Symbol,
    candidate_ref::QualifiedRefV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    reason::Symbol,
    domain_tag::Symbol,
    absence_digest::Digest256,
    status::Symbol)                  # :typed_absent
```

An absent slot has no `child_ref`, `child_contract_ref`, source hash, or
fabricated identity hash. `absence_digest` is
`H(canonical(child_kind, candidate_ref, parent ref/hash, reason, domain_tag,
status))`; it is not a child hash. The domain tag distinguishes, for example,
`source_not_supplied`, `axis_authority_missing`, and
`same_candidate_receipt_missing` without claiming any of them is physical
failure.

Promotion from `AbsentChildBindingV1` to `PresentChildBindingV1` is not a CAS
edit. It requires a new source publication with exact same candidate and parent
ref/hash, trusted source bytes, four axis records, source-record hash,
source-content hash, child contract identity, and independently recomputed
child identity. A foreign or fixture-derived child fails closed. The binding's
own `child_identity_hash` remains distinct from the realization/control child
identity hashes.

## 5. Permitted operations, CAS order, and receipts

Only these three operations are allowed on an existing binding state:

```text
insert_link(link)
replace_link(existing_link_id, replacement_link)
delete_link(existing_link_id)
```

They cannot change parent/candidate identity, source URI/version, source
record/axis slots, contracts, child slots, immutable schema, feedback metadata,
or any realization/control body. Rebind, contract change, source change, child
promotion, and feedback change require a new source publication/new candidate
and are outside CAS.

The operation and receipt are closed:

```text
G3BindingEditOperationV1(
    operation_id::String,
    child_key::G3BindingChildKeyV1,
    operation::Symbol,
    expected_prior_state_hash::Digest256,
    expected_prior_body_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    prior_body_hash::Digest256,
    replacement_body_hash::Digest256,
    before_link::Union{Nothing,G3BindingLinkV1},
    after_link::Union{Nothing,G3BindingLinkV1},
    source_record_hash::Digest256,
    operation_hash::Digest256)
```

`operation_hash` is:

```text
H(canonical(operation_id, child_key, operation,
  expected_prior_state_hash, expected_prior_body_hash,
  expected_prior_source_content_hash, prior_body_hash,
  replacement_body_hash, before_link, after_link,
  source_record_hash))
```

It excludes the resulting state hash. `replacement_body_hash` is computed
from the complete proposed editable body, even for insert/delete. The state
hash is:

```text
H(canonical(child_key, fixed source/child identities,
  current body hash, operation_hash, ordered operation history,
  contract_admission, physical_resolution))
```

The CAS order is fixed and must be visible in the API receipt:

1. verify operation type and canonical operation hash;
2. verify candidate, parent, child kind/id, source record and fixed source
   content hash;
3. compare `expected_prior_source_content_hash`;
4. compare `expected_prior_body_hash` and `prior_body_hash`;
5. compare `expected_prior_state_hash`;
6. verify operation-specific before/after link cardinality and complete body
   invariants;
7. compute replacement body hash and new operation hash;
8. compute the new state hash and append exactly one operation ID; and
9. publish the new immutable state atomically.

Any failure returns the old canonical state bytes unchanged. Required distinct
codes include `stale_source_content_hash`, `stale_body_hash`,
`stale_state_hash`, `operation_hash_mismatch`, `foreign_child_key`,
`source_record_mismatch`, `unsupported_operation`, `duplicate_link_id`,
`missing_link_id`, `link_owner_mismatch`, `child_slot_not_present`, and
`program_exception`. A failed operation must not append history, update any
hash, or mutate the old body.

## 6. Exact future binding file scope

The only future binding implementation scope is:

* `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`
* `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`
* `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`
* `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`
* `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`
* `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`

No implementation may import or edit the old `CoupledRealizationControlBindingV2`,
`RealizationControlGenomeV5`, `CandidateStatePackageV5`, registry, T0, AD-31,
AD-32, or feedback transport. The source and test must include the exact
closed types above, source/body/state/operation hash recomputation, typed
absence, and every CAS negative control.

## 7. DAG, inputs, outputs, and credits

The acyclic route remains:

```text
UP2-01-G3-SOURCE-FEEDBACK-V1
 ├─ AD-31 realization precursor
 ├─ AD-32 control precursor
 ├─ AD-34 binding precursor
 └─ T0 immutable declaration transport
       → T1 same-candidate exact package join
       → T2 identity and receipt rebuild
```

The binding precursor is parallel to AD-31, AD-32 and T0. It does not depend
on their implementation receipts. Actual present child slots require a fresh
T0 same-candidate envelope and source-backed T1 promotion; T1 alone owns the
lossless package mapping and T2 alone owns downstream identity/receipt rebuild.

Inputs: current G3 V1 declaration, read-only old binding semantics, AD-31/
AD-32 accepted architecture records, fresh typed link values, and the frozen
source/body/CAS contract. Outputs: immutable source payload, editable binding
body/state, operation receipts, focused contract tests, static QA and manifest.

The future exit gate requires one fresh focused process with raw stdout/stderr,
SHA-256/PID/exit code, static ownership check, JSON/UTF-8 validation, source/
body/state/operation round trips, typed absence, stale-source/body/state,
foreign/ref/contract/axis, duplicate/missing link, unsupported operation,
forged operation, and byte-stable failure controls, followed by different-Luna
review. This is at most `accepted_limited` contract evidence.

`actual_binding_authority=false` and `actual_feedback_authority=false` remain
fixed. Provider, mesh, engineering, physical, search, B00, B04 and R01-R10
remain false. A local binding hash, feedback route, test, runner exit,
`bridge_ready`, or documentation package cannot promote any of those credits.

## Remaining blocker and minimum repair sequence

The repair closes the R1 architecture ambiguities, but implementation is still
blocked pending the following minimum sequence:

1. Freeze the additive binding source/body types and exact hash recipes above
   in an independently reviewed work-order record.
2. Obtain a fresh typed parent G3 declaration ref/hash and same-candidate
   realization/control source slots; until then both slots remain absent or
   deferred and no actual binding can be assembled.
3. Recheck T0 using the single declaration-level authority object per
   `(candidate, layer)` and the fail-closed controls above. Do not modify T0
   in this repair.
4. Dispatch only the six binding files to one implementer and a different
   reviewer after steps 1–3. Do not add feedback-child files.
5. After the bounded software review, let T1 perform the unique source-backed
   exact package join; no old package/registry/receipt is reused.

This repair is documentation-only and does not retroactively alter AD-31,
AD-32, T0, the parent R01-R10 goal, or any historical status.
