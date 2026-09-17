# AD-34 G3 binding / feedback independent review R4

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g3_control_arch_independent_review`)  
Repair reviewed: `docs/implementation/AD-34/g3_binding_feedback_audit/repair_r3/`  
Parent review: `docs/implementation/AD-34/g3_binding_feedback_independent_review_r3/`  
Decision: `changes_requested`  
Scope: read-only architecture and boundary review; no implementation acceptance

## Evidence boundary

I read the R3 repair proposal and manifest, the R3 parent review, current
`G3SourceFeedbackLawV1`, current T0 declaration transport, the current control
source/test/archive and R9 receipt, and the AD-31/AD-32 acceptance records.
No reviewed file was modified and no Julia or DESC command was run.

R3 correctly makes the legacy authority status-only and fail-closed. It also
keeps the missing declaration identity in a separate future T0-owned adapter,
allows only a typed-absent binding scaffold before that adapter exists, and
disables link CAS with byte-stable failure. B01, B03, B04 and B05 remain
closed. One B02 mapping ambiguity still prevents a limited acceptance.

## Findings

### B01 — closed and inherited without drift

The immutable source owns `initial_links`; the editable body is an exact
canonical-byte copy. The state stores the initial source-state hash, and the
typed operation history has zero/latest, unique ID/digest, canonical order and
prior/result chain rules. Only the three eventual link operations can change
editable state. This satisfies the R2 B01 requirements.

### B02 — status mapping is closed, but target/upstream pairing is not

The per-status legacy rule is complete and safe:

* `:actual`, even with complete contract fields or trusted attestation, maps to
  typed absence with `terminal_deferred`;
* `:missing` and `:historical_absent` map to typed absence with
  `terminal_deferred`;
* `:stale`, `:contradictory`, and unknown values fail closed;
* equality can never promote a legacy value to actual authority or a present
  child slot.

The proposal also correctly limits the legacy value to the six existing
fields and keeps declaration ref/hash, canonical bytes and source receipt in a
future T0-owned adapter. That adapter is not created and no T0 file is
modified.

The remaining gap is the exact equality relation between the two current
collections. The current source stores a tuple of `upstream_authority` and a
tuple of feedback targets. Current validation requires the upstream layer set
to contain G1 and G2, but does not require exactly one upstream record per
layer, reject duplicate upstream layers, or select the upstream record for a
target by `target_layer`. Multiple targets can also address the same layer.
R3 says that target and upstream six-field canonical bytes may be compared and
that a difference is a contradiction, but it does not freeze the pairing and
cardinality rule. A future implementer could compare whole tuples, compare an
arbitrary first record, or silently ignore duplicate layer records.

Before dispatch, define the deterministic rule: for each target, select the
unique upstream authority with the same layer; require exactly one upstream
record for each required layer and reject duplicates, missing layers and
ambiguous target-layer mappings with the stated mismatch code. Compare the
six canonical fields only to detect contradiction. Equal six-field bytes still
map to typed absence and `terminal_deferred`; they never create declaration
authority. This rule must remain a future T0/T1 negative control while current
T0 stays unchanged.

The T0 owner is clear at the architectural level, but the future adapter still
needs a named work-order boundary and exact source/test/manifest ownership
before it can be scheduled. It must supply the five missing declaration
identity/receipt fields and own the per-layer pairing check; none may be
implemented in the AD-34 six-file scope.

### Adapter-absent scaffold and CAS — closed

Until the separate adapter and a same-candidate source-backed parent exist,
only `AbsentChildBindingV1` is legal. Its reason and absence digest are not
child authority. The leading CAS gate rejects with
`authority_adapter_not_published` or `binding_authority_typed_absent`; the
old source payload, scaffold, body, history and hashes remain byte-identical,
and no receipt is appended. This correctly prevents an editable binding from
being used as an authority bridge.

### B03 and B04 — closed and unchanged

Feedback metadata still belongs to parent G3 plus T0 rebuild, while runtime
numeric evidence belongs to a candidate-bound execution/evidence record. No
feedback child exists. Present/absent realization and control slots remain
typed, with no placeholder child ref/hash and source-backed promotion deferred.

### B05 — closed at the recorded point in time

The R3 point-in-time values match the current read-only checkout:

* control source: `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`;
* focused test: `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`;
* implementation manifest: `1769612256e963d31baadc961f505a6d326e3b3ffe5cd4a35149957ea5a40c47`;
* implementation report: `ee17dcca58c0e260fddbc468d3b44e9d7eeaf8c9116c3907ec61993ca69aad37`;
* R9 receipt: `21dfa6a5475402165cc01a95765f63d434a362e006e5699269db93a889da21b1`;
* R9 exit record: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`.

The archive remains `review_pending`, with machine node planned/proposal,
accepted=false, `actual_control_child=false`, and
`source_backed_t1_mapping=false`. Historical prefixes and the old
`ControlGenomeV5.jl` comparison hash are not back-attributed.

## Scope, DAG and credits

The six-file binding scope is unchanged and no feedback-child file is allowed.
The graph remains acyclic: AD-34 is parallel to AD-31, AD-32 and the separate
T0 adapter/transport work, followed by T1 exact same-candidate join and T2
identity/receipt rebuild. The adapter is a future obligation and is not an
AD-34 dependency receipt.

Binding implementation machine-node creation, actual binding/feedback
authority, T0/T1/T2, provider, mesh, engineering, physical, search, B00, B04
and R01–R10 credits remain false. A typed absence, six-field equality, test
exit, local hash or documentation record cannot raise any credit.

## Ruling

`changes_requested`: R3 closes the status outcomes, actual non-promotion,
adapter absence, CAS failure atomicity, and point-in-time control evidence, but
must add the exact per-layer target/upstream cardinality and pairing rule and
name the separate T0 adapter work-order/file boundary. After that amendment,
Sol may accept only the architecture/work-order boundary. Binding
implementation and all authority/physical credits remain blocked.
