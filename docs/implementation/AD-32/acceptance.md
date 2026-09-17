# AD-32 acceptance — G3 control candidate-owned source-edit precursor

- Date: 2026-09-15
- Decision owner: Sol (`gpt-5.6-sol`, high)
- Canonical work order: `UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC`
- Decision: `accepted_limited` for architecture and a finite contract-only work order.
- Implementation status: `planned`, `scope_status=proposal`, `accepted=false`, `resolution=review_pending`.
- Claim ceiling: contract/schema evidence only. This record does not accept an implementation, an actual control child, T0/T1, engineering, or physical evidence.

## Independent basis

The R7 proposal is retained at [repair_r7](../AD-31/g3_control_editability_audit/repair_r7/revised_proposal.md). A different Luna independently reviewed that proposal and the relevant G3 contracts with result `pass_limited`; see [R7 review](../AD-31/g3_control_editability_independent_review_r7/report.md) and [review manifest](../AD-31/g3_control_editability_independent_review_r7/manifest.json). R1–R7 proposal records remain immutable history.

## Accepted architecture boundary

AD-32 defines one control-only, candidate-owned, closed typed source/edit precursor as a sibling of the AD-31 realization precursor. It is parallel preparation with T0 and has no dependency on realization or T0. Its prerequisite is the current G3 SourceFeedback V1 declaration plus this AD-32 decision. It must not close T1, alter the VNEXT main DAG, or supply a T1 mapping before a later source-backed review.

The future implementation has exclusive file ownership:

1. `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`
2. `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`
3. `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`

Old `ControlGenomeV5`, old realization/package/registry entry points, old hashes and receipts, T0, and core planning records are read-only for that work order.

The closed payload freezes candidate and parent identity, child kind/id, a derived `source_record_ref` from `payload.source_record`, the exact parent binding derived from the payload candidate and parent declaration ref/hash, the actual additive child contract ref/hash, and a source payload ref that must equal those derived values. The grouped child key `(candidate_ref, parent_g3_declaration_hash, child_kind, child_id)` is serialized once in the initial identity recipe. Source record, source payload/content, source identity, child identity, axes, initial state, operation history, and current state are separate hash layers.

The source payload is immutable. The historical operation name `replace_fault_source_payload` is retained for compatibility, but its sole permitted mutation is the editable state of exactly one existing `fault.mode`; it does not replace or mutate the immutable source payload, source record, axes, or identities. Typed absent slots use the frozen absence marker/`Union{Nothing,...}` rule. `contract_admission` and external `physical_resolution` are independent; missing external control timing, engineering, or physics remains `unknown` or `terminal_deferred` with a typed reason.

The operation history is a closed typed tuple with globally unique operation IDs, canonical previous-state chaining, and failure atomicity. Negative controls must reject forged or stale derived refs/hashes, foreign candidate/parent/child identity, source-record mismatch, non-mode or multi-fault edits, duplicate or reordered history, dynamic field/insert/delete/rebind operations, and missing provenance. Every failed operation must return the prior canonical state bytes unchanged. The future implementation must preserve the old control semantics as read-only comparison input and must not import T0.

## Exit gate and evidence ceiling

The work order can leave `review_pending` only after a different Luna reviews the implementation and archive, with JSON/canonical byte and focused contract evidence for positive construction, first and second operation transitions, current/previous/last hash chain, all identity/ref invariants, absence and failure paths, and the negative controls above. No Julia/DESC run is part of this architecture acceptance. Even a passing software slice leaves actual control authority, source-backed T1 mapping, provider, mesh, engineering, physical, search, B00/B04, and R01–R10 credit false.

The complete parent goal remains unchanged. AD-32 is a sibling precursor only; it does not promote realization, binding, feedback, T0, T1, or any physical claim.

