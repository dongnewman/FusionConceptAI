# AD-34 acceptance

Date: 2026-09-15  
Decision: `accepted_limited`  
Decision source: Sol/root acceptance of repair R4 and independent review R5

AD-34 is accepted only as an architecture and work-order boundary for the G3
binding/feedback split. It freezes one candidate-owned binding precursor and
no feedback child. The binding machine node is
`UP1-04A-VNEXT-G3-BINDING-EDIT-PREC`; it remains
`planned`/`proposal`/`accepted=false`/`review_pending`, depends only on
`UP2-01-G3-SOURCE-FEEDBACK-V1`, and owns exactly six future product/contract
deliverables. `exact_file_count=6` excludes mandatory append-only evidence
sidecars under its task-owned archive/review/status directories. Its current
state is a typed-absent scaffold; `PresentChildBindingV1` and link CAS are
blocked until a checked-present T0 authority recheck and same-candidate source
children exist.

The separate authority gate is
`UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`; it remains
`planned`/`proposal`/`accepted=false`/`review_pending`, depends on
`UP1-04A-VNEXT-T0`, and owns exactly seven future product/contract
deliverables. `exact_file_count=7` excludes mandatory append-only evidence
sidecars under its task-owned archive/review/status directories; it has no launcher. T1
depends on both T0 and this recheck. T0 itself is unchanged. This keeps the
graph acyclic and leaves the current result typed absent.

The accepted boundary includes the R4 pairing algorithm: G1/G2 each require
exactly one upstream authority; duplicate/missing/unknown layers and target
layer/candidate/authority mismatches fail closed; target keys are unique and
ambiguous duplicates fail closed; legacy six-field equality is only an
internal consistency check. Legacy `:actual` maps to
`typed_absent`/`terminal_deferred` with
`legacy_actual_without_declaration_authority`, while stale, contradictory and
unknown statuses fail closed. A future declaration ref/hash/canonical bytes/
receipt may come only from the independent T0-owned recheck work order.

B01 immutable source/editable body, B03 metadata/runtime ownership, B04 typed
child slots, B05 control refresh, six-file scope, CAS/fail-atomic rules, DAG,
claim ceiling, and no-credit boundaries are frozen by
[repair R4](g3_binding_feedback_audit/repair_r4/revised_proposal.md) and its
manifest. The acceptance ceiling is architecture/work-order plus
`accepted_limited`; it grants no implementation, actual binding, feedback,
control, T0 authority, T1/T2, provider, mesh, engineering, physical, search,
B00, B04, or R01-R10 credit.

No source, test, T0, old evidence, old package, registry, AD-31, AD-32 or
AD-33 file was changed by this acceptance. AD-36 defines the mandatory sidecar
scope for the two exact-count work orders; sidecars are evidence-only metadata/raw/
reports/inventory/review/status records, append-only, task-local and protected from
cleanup. They must not contain product/contract deliverables, source, test, fixture,
staticQA or launcher; any such path is `scope_violation`/`fail_closed`, and only a
task-owned out-of-scope copy may be cleaned while the evidence is preserved. Implementation requires a later
Sol dispatch, real receipts, independent review, and the stated recheck gate.
