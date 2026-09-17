# AD-34 G3 binding / feedback architecture repair R2

Date: 2026-09-15  
Parent record: `../report.md`  
Prior repair: `../repair_r1/revised_proposal.md`  
Independent review: `../../g3_binding_feedback_independent_review_r2/report.md`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Ruling

R2 closes B01, B02, and B05 at the proposal level. B03 and B04 remain as
closed by R1. The architecture still has one candidate-owned editable
binding sibling precursor and no feedback child:

* `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC` owns the immutable source payload, the
  editable binding body, typed absence, and link operation receipts.
* Feedback remains a read-only transport record. Its target carries a typed
  reference to the unique declaration-level authority for `(candidate, layer)`.
  A target cannot promote itself to `actual`.
* Feedback metadata changes rebuild the parent G3 declaration and then the T0
  bundle. Runtime residual, loss, thermal, and deformation values belong to a
  candidate/scenario/input/provider/evidence record and are outside the G3
  child and T0 declaration.

This is a documentation-only repair. Implementation remains
`blocked_pending_architecture_repair`; no core index, task manifest, source,
test, old package, registry, T0, AD-31, AD-32, or AD-33 file is changed and no
implementation is dispatched.

## B01: immutable source payload and editable binding body

The owner of the initial link set is the immutable source payload. The future
source file is
`src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`.

```text
G3BindingChildKeyV1(
    candidate_ref::QualifiedRefV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                 # constructor fixes :binding
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
    initial_links::Tuple{Vararg{G3BindingLinkV1}},
    realization_slot::PresentChildBindingV1 | AbsentChildBindingV1,
    control_slot::PresentChildBindingV1 | AbsentChildBindingV1,
    source_content_hash::Digest256,
    binding_child_identity_hash::Digest256)
```

`initial_links` is source-owned and is serialized in the immutable source
payload. The editable body is initialized by an exact canonical-byte copy of
that tuple. It is not a second source authority:

```text
G3BindingEditableBodyV1(
    child_key::G3BindingChildKeyV1,
    fixed_source_content_hash::Digest256,
    fixed_binding_child_identity_hash::Digest256,
    links::Tuple{Vararg{G3BindingLinkV1}},
    body_hash::Digest256)

G3BindingStateV1(
    source_payload::G3BindingSourcePayloadV1,
    initial_source_content_hash::Digest256,
    initial_source_state_hash::Digest256,
    initial_body_hash::Digest256,
    editable_body::G3BindingEditableBodyV1,
    operation_hash::Digest256,
    ordered_operation_history::Tuple{Vararg{G3BindingOperationDigestV1}},
    state_hash::Digest256,
    contract_admission::Symbol,
    physical_resolution::Symbol)
```

The following fields are frozen for this child identity: source URI/version,
source record and its hash, contract ref and identity hash, parent/candidate
key, `initial_links`, source content hash, binding child identity hash, child
slots, `initial_body_hash`, and `initial_source_state_hash`. Only editable
links, operation receipt, and current state may change through the three
permitted operations. A source, contract, rebind, parent, child-slot, or
feedback change requires a new source publication and is never a CAS edit.

The hash layers are exact and exclude their own digest:

```text
child_contract_identity_hash = H(canonical(child_contract_ref))
source_record_hash = H(canonical(
  source_uri, source_version, payload_schema_version,
  canonicalization_profile_version, applicability_profile_version,
  evidence_receipt_version))
source_content_hash = H(canonical(
  key, child_contract_ref, child_contract_identity_hash,
  source_uri, source_version, source_record, immutable_binding_schema,
  initial_links, realization_slot, control_slot))
binding_child_identity_hash = H(canonical(
  key, child_contract_ref, child_contract_identity_hash,
  source_record_hash, source_content_hash,
  realization_slot, control_slot))
initial_body_hash = H(canonical(
  key, source_content_hash, binding_child_identity_hash, initial_links))
initial_source_state_hash = H(canonical(
  key, source_content_hash, binding_child_identity_hash,
  initial_body_hash, ZERO_OPERATION_HASH, empty_history,
  contract_admission, physical_resolution))
```

`initial_source_state_hash` is a real state field and a manifest hash layer;
it is not an inferred label. The manifest must repeat the exact hash recipe,
the value, and the source payload hash. `source_content_hash` and
`binding_child_identity_hash` are stored in the source payload and independently
recomputed from its canonical bytes. `initial_body_hash` is the hash of the
editable body's initial canonical bytes, which must equal the canonical bytes
of the source-owned `initial_links`.

History is a closed digest chain:

```text
G3BindingOperationDigestV1(
    global_operation_id::String,
    operation::Symbol,
    previous_state_hash::Digest256,
    prior_body_hash::Digest256,
    replacement_body_hash::Digest256,
    operation_hash::Digest256,
    result_state_hash::Digest256)
```

`ordered_operation_history` is the typed tuple above. Empty history has
`ZERO_OPERATION_HASH`; the current state's `operation_hash` is the latest
digest, or `ZERO_OPERATION_HASH` for the empty tuple. Each digest's
`previous_state_hash` equals the immediately prior state hash, its
`prior_body_hash` equals the preceding body hash, and its `result_state_hash`
equals the next state hash. `global_operation_id` and `operation_hash` are
unique across the child stream and are checked before append. Reusing either
one returns `duplicate_operation_id` or `duplicate_operation_hash`; an
out-of-order or broken prior/result chain returns
`operation_history_order_mismatch`. No operation may fabricate a zero/latest
digest or omit the first/last link in the chain.

## B02: single declaration-level authority migration

The canonical owner is one immutable declaration-level authority record for
each `(candidate_ref, layer)`. The future additive record is:

```text
G3DeclarationAuthorityRefV1(
    candidate_ref::QualifiedRefV1,
    layer::Symbol,
    declaration_ref::QualifiedRefV1,
    declaration_hash::Digest256,
    canonical_bytes_hash::Digest256,
    canonical_bytes::CanonicalBytes,
    authority_status::Symbol,
    attestation::Symbol,
    source_receipt_ref::Union{Nothing,QualifiedRefV1})
```

The existing `G3SFFeedbackTargetV1.authority` field is retained only as a
legacy non-authoritative projection during migration. It cannot be used as a
source of truth or independently promoted. The future target stores a typed
reference to `G3DeclarationAuthorityRefV1`; it does not carry a second
authority object. Current target fields are read, mapped, and compared against
the canonical declaration-level record.

The status mapping is fixed:

| current target status | canonical status | required condition |
|---|---|---|
| `:actual` | `:actual_claim` | exact candidate, layer, declaration ref/hash, canonical bytes, status, trusted attestation, and source receipt; T0/T1 still resolve the claim and do not grant physical authority |
| `:missing` | `:typed_absent` | canonical absence reason `missing` and a typed absence digest |
| `:historical_absent` | `:typed_absent` | canonical absence reason `historical_absent` and a typed absence digest |
| `:stale` | `:stale` | exact declaration identity is known but no longer current |
| `:contradictory` | `:contradictory` | conflicting typed declarations or receipts are preserved and fail closed |

Any unmapped status or mismatch maps to `:fail_closed`, preserving the
original current status as non-authoritative evidence. An `:actual_claim` is
never accepted merely because a target says `:actual`; it requires the exact
receipt and attestation conditions in the table.

T0 and T1 must reject, fail closed, and emit a deterministic mismatch code
for any candidate mismatch, layer mismatch, declaration ref/hash mismatch,
canonical-byte mismatch, status mismatch, attestation mismatch, receipt
mismatch, duplicate authority for one `(candidate, layer)`, actual claim with
absent/stale/contradictory upstream authority, or changed declaration reused
under an old hash. URI, label, fixture seed, or a separately typed digest is
not a substitute for exact canonical bytes. These controls are specified for
the future additive migration; this repair does not change T0.

There are no feedback-child files. Feedback metadata remains parent G3
declaration input and T0 transport input. Runtime numeric values are outside
G3/T0/CAS and carry their own candidate, scenario, solver-input, provider,
backend, numerical-configuration, evidence, execution-status, and claim
ceiling fields. They cannot grant binding or feedback authority.

## B03 and B04 retained

B03 remains closed at architecture level: declaration/feedback metadata is
owned by parent G3 plus T0 rebuild, while runtime numerical residual/loss/
thermal/deformation evidence is owned by a candidate-bound evidence record.
There is no feedback child, feedback state, feedback CAS, or feedback
operation receipt.

B04 remains closed at architecture level: realization and control are exactly
the two typed slots `PresentChildBindingV1 | AbsentChildBindingV1`.
`AbsentChildBindingV1` contains no fabricated child ref, contract ref, source
hash, or child identity hash. It contains only child kind, same candidate and
parent ref/hash, reason, domain tag, status, and an absence digest. A present
slot requires same-candidate/source-backed promotion and a separately
recomputed child identity. The binding child's identity is distinct from the
realization and control identities.

## B05: point-in-time control refresh

At read-only refresh time `2026-09-15T03:44:08.7030990Z` UTC, the current
new control child values are:

| record | exact path | SHA-256 | status |
|---|---|---|---|
| control child source | `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl` | `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb` | current read-only value |
| focused control test | `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` | `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289` | current read-only value |
| control implementation manifest | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/manifest.json` | `1769612256e963d31baadc961f505a6d326e3b3ffe5cd4a35149957ea5a40c47` | `review_pending` |
| control implementation report | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/report.md` | `ee17dcca58c0e260fddbc468d3b44e9d7eeaf8c9116c3907ec61993ca69aad37` | `review_pending` |
| R9 receipt | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/test_r9.receipt.json` | `21dfa6a5475402165cc01a95765f63d434a362e006e5699269db93a889da21b1` | recorded receipt |
| R9 exit record | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/test_r9.exit` | `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9` | exit record |

The current control archive remains `review_pending` and
`actual_control=false`; source-backed T1 mapping and every downstream
authority credit remain false. The R1 abbreviated values `7a11562...b4882`
and `aa34...4fb9` are retained as historical supplied identifiers only. They
are not substituted for the current paths above.

The old comparison artifact is separately labeled and never treated as the
new control child:

* `src/GenomeV5/G3/ControlGenomeV5.jl` SHA-256
  `eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135`.

The old path/hash is read-only comparison evidence. No current control value
is back-attributed to AD-34, AD-32, AD-31, or the parent audit. The independent
R2 review's earlier test hash is also treated as a historical point-in-time
input; the values above are this refresh's local values.

## Binding operation and fail-atomic contract

Only `insert_link`, `replace_link`, and `delete_link` edit an existing body.
They cannot alter the source payload, initial links, parent/candidate identity,
contract, child slots, feedback metadata, source record, or any authority
status. Rebind, contract/source change, child promotion, and feedback change
require a new source publication/candidate.

The CAS order is fixed: validate operation and digest; validate candidate,
parent, child kind/id, source record and fixed source/child hashes; compare
expected source, body, and state hashes; validate operation-specific link
cardinality and ownership; compute replacement body and operation digest;
validate uniqueness and the typed history chain; compute the new state hash;
publish one new immutable state atomically. Required errors include
`stale_source_content_hash`, `stale_body_hash`, `stale_state_hash`,
`operation_hash_mismatch`, `foreign_child_key`, `source_record_mismatch`,
`unsupported_operation`, `duplicate_operation_id`,
`duplicate_operation_hash`, `operation_history_order_mismatch`,
`duplicate_link_id`, `missing_link_id`, `link_owner_mismatch`,
`child_slot_not_present`, and `program_exception`.

Every failure is fail atomic: old canonical state bytes, body bytes, history,
and all hashes remain byte-identical; no receipt is appended. The focused
negative controls must cover forged source/child identity, initial-link/body
byte drift, each CAS stale layer, duplicate operation ID/digest, broken prior
or result chain, foreign candidate/layer/ref, absent-child edit, unsupported
operation, duplicate/missing link, and exception rollback.

## Exact future file scope and DAG

The six-file binding scope is fixed:

1. `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`
2. `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`
3. `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`
4. `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`
5. `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`
6. `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`

No feedback-child source, test, fixture, static-QA, or manifest file may be
added. The transport owner remains the existing T0 source/test and its AD-30
acceptance record.

The acyclic dependency graph is:

```text
UP2-01-G3-SOURCE-FEEDBACK-V1
 ├─ AD-31 realization architecture
 ├─ AD-32 control architecture
 ├─ AD-34 binding source/body precursor
 └─ T0 declaration-level immutable transport
       → T1 same-candidate exact package join
       → T2 identity and receipt rebuild
```

AD-34 is parallel to AD-31, AD-32, and T0; it does not consume their
implementation receipts. Present realization/control slots require a fresh
same-candidate T0 envelope and source-backed T1 promotion. T1 owns only the
lossless package join and T2 owns only downstream identity/receipt rebuild.
No edge points from runtime evidence back into G3 declaration authority.

Inputs are the current G3 V1 declaration, read-only legacy binding semantics,
AD-31/AD-32 architecture records, fresh typed links, and this frozen
source/body/CAS contract. Outputs are the immutable source payload, editable
body/state, typed operation receipts, focused tests, static QA, and a manifest.
The exit gate is one fresh bounded focused process with raw stdout/stderr,
SHA-256, PID, exit code, static ownership checks, canonical JSON/UTF-8 checks,
all round trips and negative controls above, followed by independent review.
The maximum claim is `accepted_limited` contract evidence.

`actual_binding_authority=false` and `actual_feedback_authority=false` remain
fixed. Provider, mesh, engineering, physical, search, B00, B04, and R01-R10
credits remain false. A local hash, test exit, bridge/readiness label,
transport record, or documentation package cannot raise those credits.

## Remaining blocker and minimum repair sequence

The architecture ambiguities in B01, B02, and B05 are closed in this repair;
the goal is still blocked pending architecture acceptance and implementation
evidence:

1. Obtain independent acceptance of this R2 proposal and freeze the additive
   source/body/authority contract.
2. Obtain a fresh typed parent G3 declaration and same-candidate,
   source-backed realization/control slots; until then slots remain absent or
   deferred and no actual binding is assembled.
3. Recheck the unchanged T0 implementation against the single authority,
   exact status table, canonical bytes, attestation, and receipt controls.
4. Dispatch only the six binding files after steps 1–3, then obtain a different
   reviewer and a fresh receipt.
5. Let T1 perform the exact package join and T2 rebuild identities/receipts;
   no old package, registry, control path, or historical receipt is reused.

This R2 record preserves R01-R10 and all no-credit boundaries. It does not
retroactively alter AD-31, AD-32, AD-33, T0, old archives, or any source/test.
