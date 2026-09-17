# AD-34 G3 binding / feedback independent review R3

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g3_control_arch_independent_review`)  
Parent review: `docs/implementation/AD-34/g3_binding_feedback_independent_review_r2/`  
Repair reviewed: `docs/implementation/AD-34/g3_binding_feedback_audit/repair_r2/`  
Decision: `changes_requested`  
Scope: read-only architecture and boundary review; no implementation acceptance

## Evidence boundary

I read the R2 independent review, R2 repair proposal and manifest, current
`G3SourceFeedbackLawV1`, current T0 declaration transport, the control source,
focused test, implementation manifest/report and R9 receipt, plus AD-31 and
AD-32 acceptance records. No reviewed file was modified. No Julia or DESC
command was run.

R2 closes the R2 B01 and B05 defects at proposal level. It makes the initial
link set source-owned, copies it into the editable body by canonical bytes,
stores the initial source-state hash, and defines a typed operation digest
chain with zero/latest, uniqueness and ordering rules. Its control refresh is
also point-in-time consistent: the exact source, test, implementation
manifest/report, R9 receipt and exit-record hashes in the proposal match the
current read-only checkout, while the archive remains `review_pending` with
`actual_control=false` and no source-backed T1 mapping.

## R2 finding review

### B01 — closed at proposal level

`G3BindingSourcePayloadV1.initial_links` is now the sole owner of the initial
link set. The editable body is initialized from an exact canonical-byte copy,
and `initial_body_hash` is explicitly tied to that tuple. The state includes
`initial_source_state_hash`; the manifest repeats that layer and its recipe.
The source payload now carries `binding_child_identity_hash`, and the proposal
freezes its construction inputs.

`ordered_operation_history` is typed as
`Tuple{Vararg{G3BindingOperationDigestV1}}`. The digest includes global
operation ID, operation, prior state/body hashes, replacement body hash,
operation hash and result state hash. Empty history uses
`ZERO_OPERATION_HASH`, the current operation hash is the latest digest, IDs
and operation hashes are unique, and the prior/result chain and tuple order
are fail-closed. The three permitted operations still change only the
editable state. This closes the R2 B01 requirements, subject to implementing
the stated negative controls.

### B02 — not closed against the current G3/T0 contract

R2 names one canonical `G3DeclarationAuthorityRefV1` per
`(candidate_ref, layer)`, marks the existing target authority as a
non-authoritative legacy projection, adds a status table, and lists the T0/T1
fail-closed checks. The architecture rule is appropriate, but the claimed
“exact legacy projection” cannot be produced from the current fields.

Current `G3SFAuthorityV1` contains only `layer`, `candidate_ref`, optional
`contract_ref`, optional `contract_hash`, `status`, and `attestation`. It has no
`declaration_ref`, `declaration_hash`, `canonical_bytes_hash`, canonical
bytes, or source receipt. `G3SFFeedbackTargetV1.authority` is exactly that
authority type, while `G3SFDeclarationV1.upstream_authority` is a separate
tuple of the same type. Current G3 validation and current T0 transport check
these collections separately; they do not derive or compare a declaration
identity and do not enforce target-to-upstream canonical equality.

Therefore the R2 table's requirements for exact declaration ref/hash,
canonical bytes and receipt are not an executable mapping of the current
legacy value. Saying that current target fields are “read, mapped, and
compared” leaves the source of those missing fields undefined. The repair
also says the future target stores the typed reference but does not give the
owner and exact field-level adapter that creates it while T0 remains
unchanged.

The minimum repair is to choose one of these closed rules before dispatch:

1. Treat the current `G3SFAuthorityV1` value as status-only, non-authoritative
   evidence. It must map to `:typed_absent` or `:fail_closed` unless a new
   T0-owned declaration authority record supplies the missing declaration
   identity, canonical bytes and receipt; or
2. Define an additive T0-owned adapter record, in its own future T0 scope,
   whose inputs and canonical bytes supply every missing field and whose
   output is the sole `G3DeclarationAuthorityRefV1`. Specify exact target
   equality and rejection before any T1 join.

The chosen rule must preserve the listed current-to-canonical status mapping,
make unmapped states fail closed, and leave T0 unmodified in this repair. A
future T0 authority recheck is necessary, but it does not make B02 closed in
the present proposal.

### B05 — closed for this point-in-time refresh

The R2 proposal records the following exact current values, all matching the
local read-only checkout:

* control source: `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`;
* focused control test: `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`;
* implementation manifest: `1769612256e963d31baadc961f505a6d326e3b3ffe5cd4a35149957ea5a40c47`;
* implementation report: `ee17dcca58c0e260fddbc468d3b44e9d7eeaf8c9116c3907ec61993ca69aad37`;
* R9 receipt: `21dfa6a5475402165cc01a95765f63d434a362e006e5699269db93a889da21b1`;
* R9 exit record: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`.

The control manifest remains `review_pending`, its machine node is planned /
proposal / accepted=false / review_pending, `actual_control_child=false`, and
`source_backed_t1_mapping=false`. The old `ControlGenomeV5.jl` hash remains
comparison-only. No value is back-attributed to AD-34, AD-32 or AD-31.

## Other boundaries

B03 remains closed: declaration target metadata rebuilds the parent G3
declaration and T0 bundle, while runtime numerical values belong to a
candidate-bound evidence record outside G3/T0/CAS. B04 remains closed: the
present/absent unions have no placeholder child identity, and promotion is a
fresh same-candidate source publication.

The immutable source versus editable-body split, the three link-only
operations, fail-atomic bytes, six-file binding scope, no-feedback-child
boundary, parallel AD-31/AD-32/T0 DAG, later T1/T2 joins, and all no-credit
flags remain unchanged. Binding machine-node creation, implementation
acceptance, actual authority, T0 authority, T1/T2, provider, engineering,
physical, search, B00, B04 and R01–R10 credits remain false. T0 authority
recheck is a future obligation.

## Ruling

The result is `changes_requested` solely because B02 is still not executable
against the current unmodified G3/T0 types: exact declaration identity and
canonical bytes are required by the proposal but absent from the legacy
authority fields, and no owning adapter is frozen. Sol may accept only the
architecture/work-order boundary after that adapter or fail-closed legacy rule
is added. Even then, a binding machine node may remain planned only; no
implementation or authority credit may be promoted by this review.
