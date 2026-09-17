# AD-34 G3 binding / feedback child architecture audit

Date: 2026-09-15  
Repository: `D:\006-Programing\LMC\FusionConceptAI`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Scope: read-only audit; only this report and its manifest are written.

## Decision

The missing G3 pieces must be separated by semantic ownership:

1. **Binding** should be one independent candidate-owned editable sibling
   precursor. It owns the G3 relation between realization and control child
   ports and the link-level closure needed to materialize a coupled G3 object.
2. **Feedback** should remain a **read-only cross-layer transport record** in
   the existing T0/T1 path. It must not become a second editable G3 child.

The binding recommendation is an architecture boundary only. Its dispatch is
`blocked_pending_architecture_repair` until the typed parent declaration ref,
child source identities, shared provenance-slot vocabulary, and exact operation
state recipe are frozen. The feedback decision is safe to freeze now as an
ownership rule: G3 may declare the emitted route and preserve the target
authority, while G1/G2 own the target quantity, residual/law/geometry meaning,
and authority. Any feedback edit therefore rebuilds the parent G3 declaration
and T0 bundle; it is not a feedback-child state transition.

This keeps AD-31 realization and AD-32 control as independent siblings. It also
avoids making binding depend on realization/control implementation receipts or
making feedback a second authority for G1/G2.

## Read-only basis and current type/API gaps

The relevant current bytes were inspected directly. No Julia, DESC, provider,
mesh, solver, engineering, physical, or heavy Python command was run.

| Current item | What exists | Gap relevant to AD-34 |
|---|---|---|
| `G3SFDeclarationV1` | Candidate ref, source/field/return/heat endpoints, conservative split, ledger closure, `feedback_targets`, G1/G2 `G3SFAuthorityV1`, and a complete `declaration_hash` | No realization/control/binding child refs, no source-content hash, no parent declaration ref, no child state, operation history, or CAS edit API |
| `G3FeedbackTargetV1` | Target layer/path, quantity, unit, direction, sign, source ID, authority ref/hash/status/attestation | It is already a cross-layer route declaration. It does not and must not own G1 residual/law or G2 geometry/thermal semantics; it has no reason to be promoted into an editable child |
| `CoupledRealizationControlBindingV2` | Typed realization/control contract bindings, link tuple, compact `G3FeedbackChannelV2` tuple, `binding_hash`, structural validation | Requires concrete old children; feedback omits target path, quantity, direction, sign, authority hash/status/attestation; no parent G3 declaration binding, source payload/provenance, state, edit operation, or stale guards |
| `RealizationControlGenomeV5` | Requires concrete `RealizationGenomeV5`, `ControlGenomeV5`, and coupled binding; computes old bundle hash | Cannot represent typed absent children and cannot losslessly carry the G3 V1 law/feedback authority |
| `VNextDeclarationTransportV1` | T0 transports complete G3 declaration/feedback and three typed-absent child markers; preserves deferred authority | It intentionally has no actual binding child payload/state. Its feedback path is already the correct read-only transport boundary |
| `CandidateStatePackageV5` | Concrete G1/G2/G3 generic parameters, old G2 binding, old migration receipt, `claim_ceiling=none`, deferred-only constructor | Old package cannot accept a new binding child or a typed absent feedback child without lossy projection; it is read-only |
| `GenomeContractRegistryV4` / shared registry path | Static contract refs and role resolution for old types | No additive AD-34 child contract may be installed by changing the old registry; a future T1 package must own the new contract refs |

The current focused G3 source/test/fixture and old package/binding bytes are
recorded in `manifest.json`. Existing G3 tests cover local law validation,
feedback target ref mismatch, missing authority, synthetic equality, and old
binding links. They do not establish a candidate-owned binding state machine,
source provenance, operation identity, or failure-atomic CAS behavior.

## Semantic ownership and authority boundary

The binding sibling owns only:

* the G3 child key and parent G3 declaration binding;
* typed realization-child and control-child references/hashes;
* control-resource link records, link ownership, direction and fault-path
  membership; and
* binding-local closure and editable link state.

Realization resource/material/manufacturing meaning remains owned by AD-31's
realization child. Signal/controller/fault meaning remains owned by AD-32's
control child. G1 equations, residual rows, conservation occurrences and
closure remain G1-owned. G2 regions, interfaces, geometry, metric, boundary
and discretization remain G2-owned. Binding may verify references and link
compatibility; it may not define or replace any of those semantics.

The feedback transport record owns only the emitted cross-layer envelope:
`target_layer`, exact target ref/path, quantity label, unit, direction, sign,
source ID, authority ref/hash/status/attestation, candidate identity and
provenance. The target's physical meaning is borrowed by exact reference from
G1/G2 and is never copied into a G3 child. A foreign target, stale target,
unattested `actual`, or conflicting authority is `fail_closed`; missing
authority is an independent `terminal_deferred` gap. `actual` remains false
until a trusted same-candidate source receipt exists.

This rule prevents three kinds of overlap: binding cannot become a second
realization/control owner; feedback cannot become a second G1/G2 authority;
and T0/T1 cannot be replaced by a G3-local projection.

## Exact future work-order boundaries

### Binding sibling: `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC`

This is the one new editable sibling. Its exact future file set is:

* `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`
* `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`
* `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`
* `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`
* `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`
* `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`

The source must define closed typed records, without `Dict`, open semantic
`NamedTuple`, `Any` payloads, URI parsing, fixture authority, or old V5 type
aliases. The minimum records are:

```text
G3BindingChildKeyV1(
  candidate_ref, parent_g3_declaration_ref, parent_g3_declaration_hash,
  child_kind=:binding, child_id)
G3BindingLinkV1(
  link_id, controller_id, sensor_port_id, actuator_port_id,
  resource_port_id, fault_id)
G3BindingSourceBodyV1(
  binding_contract, realization_child_ref/hash, control_child_ref/hash,
  links, local_closure)
G3BindingSourceRecordV1(four typed provenance slots or typed absence)
G3BindingSourcePayloadV1(key, source_uri/version, body, source_record,
                         source_content_hash)
G3BindingStateV1(present_or_typed_absent, initial_state_hash, state_hash,
                 operation_hash, ordered_operation_history,
                 contract_admission, physical_resolution)
G3BindingEditOperationV1(operation_id, operation, expected_prior_state_hash,
                         expected_prior_source_content_hash, before/after link,
                         source_record_ref, operation_hash)
```

The binding body must retain exact child refs/hashes and require those children
to be same-candidate, source-backed states at the later T1 join. A binding
precursor may carry typed absent child references during local contract work;
it cannot turn absence into actual authority.

The permitted local operations are exactly `insert_link`, `replace_link`, and
`delete_link` over a complete typed `G3BindingLinkV1`. Child rebind, contract
change, source-record change, feedback target change, and arbitrary field-path
patches are outside this operation and require a new source payload with fresh
provenance. The operation must preserve all non-target links and re-run every
link ownership/direction/fault/child-ref invariant before publication.

### Feedback: no editable sibling; existing T0 read-only record

No new feedback-child source, test, fixture, or static-QA file is authorized.
The exact owner remains the existing T0 transport set:

* source: `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` (read-only
  for this audit; future T0 work may extend it additively only after its own
  review)
* test: `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl`
  (read-only input to this audit)
* fixture: no new feedback fixture; current
  `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` remains a local
  construction input and authority-free test oracle
* static QA: no new feedback-child static-QA script; T0's existing static
  JSON/link/plan checks remain the boundary
* docs: `docs/implementation/AD-30/t0_readiness_audit/report.md`,
  `docs/implementation/UP1-04A-VNEXT-T0/software_precursor_acceptance.md`,
  and its independent review/archive

If T0 later needs a named helper record, it must be a T0-owned immutable
`VNextG3FeedbackTransportRecordV1` inside that same transport file and test
scope. It must not be registered as a G3 child, must not expose an edit API,
and must not duplicate G1/G2 target semantics. Feedback edits are parent
declaration edits followed by a new T0 bundle hash.

## Hash, provenance, absence, state, and CAS contract

The binding implementation must use the repository canonical UTF-8/LF,
fixed-field-order SHA-256 canonicalizer and keep these non-recursive layers:

1. `child_contract_identity_hash = H(canonical(child_contract_ref))`.
2. `source_record_hash = H(canonical(source_uri, source_version, four axis
   slots))`, excluding itself and every content/operation hash.
3. `source_content_hash = H(canonical(child_key, parent ref/hash,
   child-contract identity, source URI/version, closed body,
   source_record_hash))`, excluding itself.
4. `initial_state_hash = H(canonical(child_key, state_status,
   source_content_or_absence_hash, contract_admission,
   physical_resolution, ZERO_OPERATION_HASH, empty_history))`.
5. `operation_hash = H(canonical(operation_id, child_key, operation,
   expected prior state/source hashes, complete before/after link,
   source_record_ref))`, excluding resulting state hash.
6. `state_hash = H(canonical(child_key, state status, source or absence hash,
   operation_hash, ordered operation history, contract admission,
   physical resolution))`.
7. The binding/envelope hash is `H(canonical(parent_g3_body_hash,
   binding child state, child refs/hashes, links, axis records, feedback
   transport record refs, gaps, resolution))`; feedback record bytes are
   included by reference/hash and never reinterpreted.

Each provenance axis is a present-or-typed-absent slot. A present slot carries
the exact typed value/ref, source URI/path, candidate ref, source hash and
status. An absent slot carries no value and no fabricated hash, an explicit
reason, and an independent absence-content hash. Missing source/axis authority
is `contract_admission=:terminal_deferred`; conflicting candidate/ref/hash/
axis/status is `:fail_closed`; an unexpected implementation exception is
`:program_exception`. `physical_resolution` remains `:unknown` or
`:terminal_deferred`.

CAS must check both expected prior state and expected prior source-content
hash. `stale_state_hash` and `stale_source_content_hash` are separate failure
codes. Every failed operation, including forged operation hash, foreign parent
or child, duplicate link, missing child reference, unsupported operation,
conflicting axis, and internal exception, must return the prior canonical
state bytes, state hash, source hash, and operation history unchanged. A
successful link edit changes only the affected source/content/operation/state
identities and the binding/envelope hash.

The feedback transport has no child state or CAS. Its immutable identity is
covered by the parent declaration hash and T0 bundle hash. Changing target
path, quantity, unit, direction, sign, source ID or authority requires a new
G3 declaration and new T0 bundle; stale or forged transport bytes fail closed.

## Acyclic relation to T0/T1/T2

The safe dependency graph is:

```text
UP2-01-G3-SOURCE-FEEDBACK-V1
        ├── AD-31 realization precursor
        ├── AD-32 control precursor
        ├── AD-34 binding precursor (this proposed sibling)
        └── T0 declaration transport
                → T1 exact lossless package join
                → T2 identity/receipt rebuild
```

The binding precursor is parallel to AD-31, AD-32, and T0. It must not depend
on a realization/control implementation receipt, T0, T1, or T2. This avoids a
false serial edge and a cycle. Actual binding child population is a later T1
input gate: T0 must first supply the fresh same-candidate envelope, G2 mapping,
four-axis records, and G3 source-content authority. T1 alone owns mapping all
present children plus the feedback transport into the additive
`CandidateStatePackageV5Next`; T2 alone rebuilds downstream identities and
receipts. No old package or registry mutation is part of this graph.

## Inputs, outputs, and exit gates

Binding precursor inputs are the current G3 SourceFeedback declaration,
read-only old binding semantics for comparison, AD-31/AD-32 child identity
rules, fresh typed local link values, and the reviewed shared provenance/hash
recipe. Old candidate hashes, fixture labels, old receipts, provider outputs,
mesh outputs and physical data are not inputs.

Its outputs are the closed binding body, typed present/absent state, source and
operation receipts, deterministic hashes, focused tests, static QA and an
implementation manifest. The focused gate requires valid JSON/UTF-8, exact
owned-file scope, independent source/static review, one fresh Julia process
capturing raw stdout/stderr bytes plus SHA-256/PID/exit code, and all positive,
absence, stale, forged, foreign, duplicate, unsupported-operation and
fail-atomic controls. A different Luna must review the implementation and
receipt bytes. The result can be at most `accepted_limited` contract evidence.

Feedback transport gates are the existing T0 gates: exact candidate join,
full feedback preservation, target ref/hash/authority checks, typed missing
authority, bundle hash round-trip, and no old-package entry. No feedback-child
implementation gate exists.

Both paths keep `actual_binding_authority=false` and
`actual_feedback_authority=false` until fresh same-candidate source-backed
receipts are independently reviewed. No local hash, fixture, test, T0 exit,
`bridge_ready`, provider label, or document can change that.

## Blocker and minimum repair sequence

Current dispatch status is `blocked_pending_architecture_repair` for the
binding sibling, despite the semantic split being decided. The minimum repair
sequence is:

1. Freeze a typed parent G3 declaration ref/hash and additive binding child
   contract ref; the current `G3SFDeclarationV1` has only a candidate ref.
2. Freeze the shared four-axis present/absent record, source-record and
   source-content hash recipe with no self-recursion, aligned with the accepted
   AD-31/AD-32 boundary.
3. Freeze the exact closed binding link body, permitted three operations,
   operation receipt, two independent CAS guards, and byte-stable failure
   result.
4. Recheck T0's immutable feedback record against the same candidate and
   explicitly require feedback target edits to rebuild the G3 declaration/T0
   bundle; do not create a feedback child or alter the old registry/package.
5. Only then dispatch the six binding files above to one Luna implementer and
   a different Luna reviewer. After its limited software gate, T1 may consume
   an actual child only when fresh source-backed same-candidate authority exists.

No provider, mesh, engineering, physical, search, B00, B04, or R01–R10 credit
is granted. Historical R01–R10 and all prior receipts remain unchanged and
read-only.
