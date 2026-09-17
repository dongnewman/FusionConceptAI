# AD-34 G3 binding / feedback architecture repair R4

Date: 2026-09-15  
Parent record: `../report.md`  
Prior repair: `../repair_r3/revised_proposal.md`  
Independent review: `../../g3_binding_feedback_independent_review_r4/report.md`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Ruling

R4 closes both independent-review items while preserving the R3 fail-closed
decision. The binding precursor remains a candidate-owned sibling and there is
no feedback child or authority adapter in the AD-34 scope. Pairing is now a
closed algorithm over the current G3 V1 fields. A separate future work order
owns the T0 authority recheck gate before T1.

This repair creates no machine node, changes no DAG, and does not modify
core/source/test/old archives/AD-31—33/T0. It remains
`blocked_pending_architecture_repair`; only a typed-absent binding scaffold is
legal at the current point in time.

## 1. Frozen pairing algorithm

The current source defines:

```text
G3SFFeedbackTargetV1(
    target_id, target_layer, target_path, quantity, unit,
    direction, sign, source_id, owner_scope, authority)

G3SFAuthorityV1(
    layer, candidate_ref, contract_ref, contract_hash, status, attestation)
```

`G3SFDeclarationV1.upstream_authority` is a tuple of the latter type. The
pairing algorithm first validates the declaration-level upstream collection:

1. Required layers are exactly `{G1, G2}`.
2. Each required layer must occur exactly once. A duplicate returns
   `duplicate_upstream_authority_layer`; a missing required layer returns
   `missing_upstream_authority_layer`.
3. Any upstream record with an unknown layer returns
   `unknown_upstream_authority_layer`.
4. The declaration candidate must equal the expected candidate; a mismatch
   returns `upstream_authority_candidate_mismatch`.

The algorithm then validates each target:

1. `target_layer` must be G1 or G2. Otherwise it returns
   `unknown_target_layer`.
2. The target's layer must have the one validated upstream record. Otherwise
   it returns `missing_upstream_authority_layer`.
3. `target.authority.layer` must equal `target.target_layer` and
   `target.authority.candidate_ref` must equal the declaration candidate.
   Either mismatch returns `legacy_target_authority_layer_or_candidate_mismatch`.
4. The six-field canonical bytes of the target's legacy authority
   `(layer, candidate_ref, contract_ref, contract_hash, status, attestation)`
   must equal the six-field canonical bytes of that layer's unique upstream
   record. A mismatch returns
   `legacy_target_upstream_projection_mismatch`.
5. Exact equality is only an internal consistency check. It remains a
   non-authoritative legacy projection and follows the R3 status mapping; it
   cannot promote a target, declaration, child slot, or binding authority.

Multiple targets may share one layer and therefore pair to the same unique
upstream record. They must still be unambiguous. The canonical semantic target
key is the tuple of current fields:

```text
target_key = (
    target_layer, target_path, quantity, unit,
    direction, sign, source_id, owner_scope)
```

The separate existing `target_id` must also be unique. Duplicate `target_key`
returns `duplicate_or_ambiguous_feedback_target`; duplicate `target_id`
returns `duplicate_feedback_target_id`. A different target ID cannot disguise
the same layer/path/quantity/unit/direction/sign/source/owner tuple. Distinct
keys may share a layer and pair to that layer's one upstream record.

The legacy status result remains frozen from R3:

| current status | result | reason |
|---|---|---|
| `:actual` | `:typed_absent`, `:terminal_deferred` | `legacy_actual_without_declaration_authority` |
| `:missing` | `:typed_absent`, `:terminal_deferred` | `legacy_missing_authority` |
| `:historical_absent` | `:typed_absent`, `:terminal_deferred` | `legacy_historical_absent_authority` |
| `:stale` | `:fail_closed` | `legacy_stale_authority` |
| `:contradictory` | `:fail_closed` | `legacy_contradictory_authority` |
| unknown | `:fail_closed` | `unmapped_legacy_authority_status` |

Thus even an exactly paired `:actual` projection cannot produce declaration
ref/hash/canonical bytes, a present slot, or actual authority. Pairing never
synthesizes absent authority fields.

## 2. Independent T0 authority recheck work order

The future work order is frozen as:

`UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`

Its semantic role is an authority recheck gate after the T0 output and before
T1. It is independent of AD-34 and is not a binding child, feedback child, or
legacy projection adapter. Its exact future scope is:

1. `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1.jl`
2. `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_tests.jl`
3. `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_fixture.json`
4. `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_v1.py`
5. `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md`
6. `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/manifest.json`
7. `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md`

There is no launcher. The work order depends on the T0 output. Future T1
depends on both the T0 output and this recheck result:

```text
T0 bundle
  -> T0 authority recheck
T0 bundle + authority recheck
  -> T1 same-candidate exact package join
  -> T2 identity and receipt rebuild
```

The recheck inputs are the T0 bundle plus a fresh T0-owned declaration
authority record or typed absence. Its output is exactly one of:

* checked present, only when declaration ref/hash, canonical bytes, candidate,
  layer, status, attestation, and source receipt are exact and source-backed;
* typed absent with a reason and absence digest; or
* fail-closed with a deterministic mismatch/error code.

It must never synthesize missing declaration fields from
`G3SFAuthorityV1`, target equality, a fixture, a binding payload, or a
manifest. In the current repository this work order is only a future contract;
the only legal result is the AD-34 typed-absent scaffold. No machine node is
created here. Synchronization waits for Sol review and independent review.

## 3. Binding gate and ownership

AD-34 remains the six-file binding scope:

1. `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`
2. `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`
3. `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`
4. `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`
5. `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`
6. `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`

No T0 recheck file belongs in this scope. Until the future recheck outputs a
checked-present authority and same-candidate source-backed parent/child slot,
AD-34 can only construct `AbsentChildBindingV1` with a reason such as
`authority_recheck_not_published` and an absence digest. It cannot construct
`PresentChildBindingV1`, actual authority, or a physical/engineering claim.

The immutable source model is unchanged from R3. Source-owned
`initial_links::Tuple{Vararg{G3BindingLinkV1}}` is copied into the editable
body by exact canonical bytes. `child_contract_ref`,
`source_content_hash`, `binding_child_identity_hash`, `initial_body_hash`, and
`initial_source_state_hash` are stored and independently recomputed. The
state keeps typed
`Tuple{Vararg{G3BindingOperationDigestV1}}` history with zero/latest,
globally unique operation ID/digest, exact ordering, prior-state/result-state
chain, and duplicate errors.

The eventual operations remain only `insert_link`, `replace_link`, and
`delete_link`. Before checked-present recheck output, all three fail with
`authority_recheck_not_published` or `binding_authority_typed_absent`; source,
body, history, receipts, and hashes remain byte-identical. After the gate, the
R3 CAS order and fail-atomic errors remain mandatory.

Feedback metadata remains owned by parent G3 declaration rebuild and T0
bundle rebuild. Runtime residual/loss/thermal/deformation values remain
candidate/scenario/input/provider/evidence records. There is no feedback child,
feedback CAS, or feedback operation receipt. The binding child identity remains
separate from realization and control child identities.

## 4. DAG, credits, B05 refresh, and claim ceiling

The declared high-level DAG is unchanged:

```text
UP2-01-G3-SOURCE-FEEDBACK-V1
 ├─ AD-31 realization architecture
 ├─ AD-32 control architecture
 ├─ AD-34 binding precursor
 └─ T0 immutable declaration transport
       → T0 authority recheck work order
       → T1 same-candidate exact package join
       → T2 identity and receipt rebuild
```

This record does not create a machine node or synchronize the DAG. AD-34 is a
sibling precursor and may retain typed-absent state before recheck; actual
binding/present authority requires the recheck's checked-present result, and
T1 must depend on both T0 and recheck.

The R3 point-in-time control refresh is inherited unchanged from
`2026-09-15T03:44:08.7030990Z` UTC:

| record | path | SHA-256 | status |
|---|---|---|---|
| new control source | `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl` | `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb` | current read-only value |
| new control test | `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` | `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289` | current read-only value |
| implementation manifest | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/manifest.json` | `1769612256e963d31baadc961f505a6d326e3b3ffe5cd4a35149957ea5a40c47` | `review_pending` |
| implementation report | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/report.md` | `ee17dcca58c0e260fddbc468d3b44e9d7eeaf8c9116c3907ec61993ca69aad37` | `review_pending` |
| R9 receipt | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/test_r9.receipt.json` | `21dfa6a5475402165cc01a95765f63d434a362e006e5699269db93a889da21b1` | recorded |
| R9 exit | `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/test_r9.exit` | `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9` | recorded |

The archive remains `review_pending`, `actual_control=false`, and not
source-backed for T1. Historical `7a11562...b4882` and `aa34...4fb9` remain
supplied identifiers only. Old comparison remains
`src/GenomeV5/G3/ControlGenomeV5.jl` SHA-256
`eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135` and is
not the new control child. No value is back-attributed.

`actual_binding_authority=false`, `actual_feedback_authority=false`, and
`actual_control=false` remain fixed. Provider, mesh, engineering, physical,
search, B00, B04, and R01-R10 remain false. Exact pairing, typed absence,
local hashes, test exit, bridge/readiness labels, or documentation cannot
raise a credit. Maximum future claim is `accepted_limited` contract evidence.

## Remaining blockers and review request

The remaining sequence is:

1. Obtain independent R4 acceptance of this exact pairing algorithm and the
   separate T0 recheck work order.
2. Have Sol review and separately synchronize the future recheck work order;
   do not add its files to AD-34.
3. Produce a T0 bundle plus fresh T0-owned authority record/typed absence and
   obtain the recheck result.
4. Keep AD-34 typed absent until checked-present; only then enable link CAS and
   let T1 join using both T0 and recheck.
5. Let T2 rebuild identities/receipts; do not reuse legacy packages, registries,
   control paths, or receipts.

This R4 proposal is documentation-only. It requests independent R4 review,
preserves R01-R10 and all no-credit boundaries, and does not retroactively
alter AD-31, AD-32, AD-33, T0, or historical archives.
