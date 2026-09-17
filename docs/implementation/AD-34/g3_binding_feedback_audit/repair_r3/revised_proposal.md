# AD-34 G3 binding / feedback architecture repair R3

Date: 2026-09-15  
Parent record: `../report.md`  
Prior repair: `../repair_r2/revised_proposal.md`  
Independent review requesting this repair: `../../g3_binding_feedback_independent_review_r3/report.md`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Ruling

R3 closes B02 with a fail-closed legacy rule. It does not create, infer, or
place a T0 authority adapter in the AD-34 binding scope. R2 B01, B03, B04,
and B05 are inherited without weakening. The architecture remains one
candidate-owned binding precursor and no feedback child.

Until a separate, future T0-owned authority adapter/work order exists, the
binding has no `PresentChildBindingV1` or actual-authority path. It may carry
only a typed-absent scaffold, and every binding link CAS operation is disabled
with the original canonical bytes preserved on failure. This record remains
`blocked_pending_architecture_repair`; it changes no core/source/test/old
archive/AD-31—33/T0 file and dispatches no implementation.

## B02: exact fail-closed legacy migration

The current `G3SFAuthorityV1` has exactly these six canonical fields:

```text
(layer, candidate_ref, contract_ref, contract_hash, status, attestation)
```

It has no declaration ref, declaration hash, canonical-byte hash, canonical
bytes, or source receipt. Both `G3SFFeedbackTargetV1.authority` and
`G3SFDeclarationV1.upstream_authority` use this type. They are status-only,
non-authoritative legacy projections. Neither collection is a declaration
authority, and exact equality between the two collections cannot grant one.

The frozen legacy mapping is:

| current legacy status | canonical migration result | fixed reason / consequence |
|---|---|---|
| `:actual` | `:typed_absent` | `legacy_actual_without_declaration_authority`; `terminal_deferred` |
| `:missing` | `:typed_absent` | `legacy_missing_authority`; `terminal_deferred` |
| `:historical_absent` | `:typed_absent` | `legacy_historical_absent_authority`; `terminal_deferred` |
| `:stale` | `:fail_closed` | `legacy_stale_authority` |
| `:contradictory` | `:fail_closed` | `legacy_contradictory_authority` |
| any unknown value | `:fail_closed` | `unmapped_legacy_authority_status` |

The `:actual` rule is deliberately unconditional: even if its
`contract_ref`, `contract_hash`, and `attestation` look complete or trusted,
the legacy value maps to typed absence and `terminal_deferred`. It cannot
become `:actual_claim`, `:present`, or a source-backed binding slot.

The legacy target and declaration authority values may be compared using the
existing six-field canonical bytes to detect internal inconsistency. If they
differ in layer, candidate, contract ref, contract hash, status, or
attestation, the result is `:fail_closed` with
`legacy_target_upstream_projection_mismatch`. If they are exactly equal, the
result is still the mapping above; equality is an integrity check, never a
promotion.

The only future source of `declaration_ref`, `declaration_hash`,
`canonical_bytes_hash`, canonical bytes, and `source_receipt_ref` is a new
T0-owned declaration-authority adapter/work order. That adapter is outside
AD-34, outside the six binding files, and is not created by this repair. A
future T0/T1 path must independently reject candidate, layer, declaration
ref/hash, canonical bytes, status, attestation, receipt, duplicate authority,
stale declaration, and contradictory declaration mismatches. These controls
remain future negative controls; current T0 is not modified here.

No T0 authority adapter may be faked by a binding fixture, source payload,
manifest, child identity, operation receipt, `initial_links`, or typed absence
digest. Before the separate adapter exists, binding promotion is forbidden:

```text
legacy G3SFAuthorityV1
  -> status-only projection
  -> typed absence or fail_closed
  -> no PresentChildBindingV1 / no actual authority
```

## B01 inherited: immutable source and editable body

The source owner and hash model remain exactly R2. The future source is
`src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`. Its immutable
`G3BindingSourcePayloadV1` stores `child_contract_ref`, independently stored
and recomputed `binding_child_identity_hash`, source record, fixed child
slots, and `initial_links::Tuple{Vararg{G3BindingLinkV1}}`. The editable body
is initialized by an exact canonical-byte copy of `initial_links`.

The state retains:

```text
initial_source_content_hash::Digest256
initial_source_state_hash::Digest256
initial_body_hash::Digest256
ordered_operation_history::Tuple{Vararg{G3BindingOperationDigestV1}}
```

The frozen layers are source record/content, contract identity, child identity,
initial links/body, and initial source state. The exact recipes remain:

```text
source_content_hash = H(canonical(
  key, child_contract_ref, child_contract_identity_hash,
  source_record, immutable_binding_schema, initial_links,
  realization_slot, control_slot))
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

`initial_source_state_hash` is both a state field and a manifest hash layer.
Only editable link body, operation receipt, and current state could ever
change through an enabled operation. A source, contract, rebind, parent,
child-slot, feedback, or authority change requires new source publication.

History remains the closed typed
`Tuple{Vararg{G3BindingOperationDigestV1}}` with global unique operation ID and
digest, canonical tuple order, zero/latest rules, previous-state/prior-body
chain, and result-state chain. Duplicate ID/digest or broken ordering is an
error; no receipt may be appended.

## B03 and B04 inherited

B03 remains closed: feedback metadata belongs to parent G3 declaration rebuild
and then T0 bundle rebuild. Runtime residual/loss/thermal/deformation values
belong to a candidate+scenario+solver-input+provider/evidence record. There
is no feedback-child file, state, CAS, operation receipt, or authority path.

B04 remains closed: realization and control are exactly
`PresentChildBindingV1 | AbsentChildBindingV1`. An absent slot has no child
ref, contract ref, source hash, or fabricated child identity hash; it carries
child kind, same-candidate/parent ref and hash, reason, domain tag, status, and
absence digest. A present slot requires a future same-candidate,
source-backed promotion and independently recomputed child identity. The
binding child's identity is separate from both child identities.

In R3, because the separate T0 authority adapter is absent, the only legal
slot representation is `AbsentChildBindingV1` with a reason such as
`authority_adapter_not_published` or `source_backed_parent_not_available`.
Its absence digest is not a child hash and cannot be used to promote a slot.

## Binding CAS is disabled until T0 authority exists

The only eventual link operations remain `insert_link`, `replace_link`, and
`delete_link`, with the R2 CAS order: validate operation/digest; validate
candidate, parent, child, source record and fixed identities; compare source,
body, and state expectations; validate link ownership/cardinality; compute the
replacement body and typed operation digest; validate unique history; compute
state hash; publish one state atomically.

R3 adds a leading gate before that order:

```text
require independent T0-owned declaration authority adapter
require same-candidate declaration ref/hash and source receipt
require present source-backed binding slot
otherwise return authority_adapter_not_published or
         binding_authority_typed_absent
```

Until the gate passes, the operation is rejected and the old source payload,
typed-absent scaffold, body bytes, history, and all hashes remain byte-for-byte
unchanged. The required errors include
`authority_adapter_not_published`, `binding_authority_typed_absent`,
`stale_source_content_hash`, `stale_body_hash`, `stale_state_hash`,
`operation_hash_mismatch`, `foreign_child_key`, `source_record_mismatch`,
`duplicate_operation_id`, `duplicate_operation_hash`,
`operation_history_order_mismatch`, `duplicate_link_id`, `missing_link_id`,
`link_owner_mismatch`, `child_slot_not_present`, and `program_exception`.

No operation receipt, body hash, state hash, or manifest field may be used to
stand in for the missing T0 authority. Any exception also returns the old
canonical bytes unchanged.

## B05 inherited: control refresh and boundary

The R2 point-in-time refresh remains authoritative for this proposal at
`2026-09-15T03:44:08.7030990Z` UTC:

| record | path | SHA-256 | status |
|---|---|---|---|
| new control source | `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl` | `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb` | current read-only value |
| new control test | `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` | `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289` | current read-only value |
| implementation manifest | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/manifest.json` | `1769612256e963d31baadc961f505a6d326e3b3ffe5cd4a35149957ea5a40c47` | `review_pending` |
| implementation report | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/report.md` | `ee17dcca58c0e260fddbc468d3b44e9d7eeaf8c9116c3907ec61993ca69aad37` | `review_pending` |
| R9 receipt | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/test_r9.receipt.json` | `21dfa6a5475402165cc01a95765f63d434a362e006e5699269db93a889da21b1` | recorded |
| R9 exit | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/test_r9.exit` | `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9` | recorded |

`actual_control=false`, source-backed T1 mapping is false, and no current
control value is back-attributed to AD-34, AD-32, or AD-31. The supplied
historical prefixes `7a11562...b4882` and `aa34...4fb9` remain historical
identifiers only. The old comparison path is separate:
`src/GenomeV5/G3/ControlGenomeV5.jl`, SHA-256
`eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135`.

## Exact future scope, DAG, credits, and exit gate

The only future binding files are these six:

1. `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`
2. `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`
3. `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`
4. `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`
5. `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`
6. `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`

There is no T0 adapter, feedback child, or authority adapter file in this
scope. The future graph is acyclic:

```text
UP2-01-G3-SOURCE-FEEDBACK-V1
 ├─ AD-31 realization architecture
 ├─ AD-32 control architecture
 ├─ AD-34 binding precursor
 └─ separate T0-owned authority adapter/work order
       → T0 immutable declaration transport
       → T1 same-candidate exact package join
       → T2 identity and receipt rebuild
```

AD-34 is parallel to AD-31, AD-32, and the T0 work. It cannot consume a
legacy authority as an implementation receipt, and no edge returns runtime
evidence to declaration authority. Inputs and outputs remain the R2 contract,
but the current output is only immutable source metadata plus a typed-absent
scaffold; editable link state is not admitted while the T0 gate is absent.

The eventual exit gate requires a fresh focused process with raw stdout/stderr,
SHA-256, PID, exit code, static ownership checks, canonical JSON/UTF-8 checks,
source/body/state/operation round trips, T0-adapter-present and
adapter-absent negative controls, all stale/duplicate/foreign/fail-atomic
controls, and review by a different Luna. Maximum claim remains
`accepted_limited` contract evidence.

Credits remain fixed: `actual_binding_authority=false`,
`actual_feedback_authority=false`, `actual_control=false`, and provider,
mesh, engineering, physical, search, B00, B04, and R01-R10 all false. A
legacy actual status, exact six-field equality, local hash, typed absence,
test exit, bridge/readiness label, or documentation package cannot raise a
credit.

## Remaining blockers and R4 request

The minimum safe sequence is:

1. Obtain independent R4 review and acceptance of this fail-closed migration.
2. Specify and review the separate T0-owned authority adapter/work order,
   outside AD-34 and outside the six binding files.
3. Obtain same-candidate declaration ref/hash, canonical bytes, source receipt,
   and source-backed child slots from that T0 path.
4. Only then enable the three binding CAS operations and dispatch the six-file
   implementation to a different reviewer.
5. Let T1 perform the exact package join and T2 rebuild identities/receipts;
   do not reuse old packages, registries, control paths, or receipts.

Please perform the independent R4 review against this R3 proposal. This record
preserves R01-R10 and all no-credit boundaries and does not retroactively alter
AD-31, AD-32, AD-33, T0, or historical archives.
