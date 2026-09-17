# AD-30 G3 child editability precursor: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The audit correctly establishes the important boundary: the current
`G3SourceFeedbackLawV1` has no realization, control, or coupled-binding child
identities, and the old V5 children, package, integration entry, registry and
receipts cannot carry the V1 law and authority losslessly. A contract-only
precursor is architecturally permissible, but the proposed work order is too
wide to be a finite, independently reviewable vertical slice. It combines
three child schemas, a general edit language, binding/feedback joins, and
future T0 authority in one new contract. Narrow the first implementation to
one source-edit slice before dispatching it.

This review is read-only with respect to core planning, source, tests and old
receipts. It writes only this report and its manifest. No Julia, DESC, provider,
mesh, solver or physical command was run.

## Confirmed contract findings

The source comparison is substantively correct.

* `G3SFDeclarationV1` retains the candidate reference, source and owner, typed
  source/field/return/heat endpoints, conservative law, ledger entries and
  closure, feedback target path/quantity/unit/direction/sign, and upstream
  authority. Its declaration hash covers the complete body. It contains no
  child refs.
* `RealizationGenomeV5` is a typed resource/material/manufacturing/ledger
  object with `plan_hash` and `candidate_hash`, but its only public edit helper
  is component-capacity replacement. It has no candidate-owned source payload
  or immutable edit receipt.
* `ControlGenomeV5` has typed signal/controller/fault/plan data and a fault
  edit helper, but no source identity or edit envelope.
* `CoupledRealizationControlBindingV2` requires all three concrete child
  bindings and validates links against concrete realization/control objects.
  Its compact feedback type does not carry the full V1 target path,
  quantity, direction, sign and authority record.
* `GenomeV5Integration.jl` and `CandidateStatePackageV5.jl` hard-check the old
  concrete G1/G2/G3 types and the old candidate identity shape. A ref-only
  adapter or old-package projection would therefore either fail closed or
  drop V1 semantics.

The proposed typed absence boundary is also correct: a missing child may be
represented as `child_ref=nothing`, `source_content_hash=nothing`, a stable
absence record and an independent `terminal_deferred` gap. A fixture,
`bridge_ready`, local hash, or old child contract cannot populate an actual
same-candidate child or feedback authority. `contract_admission` must remain
separate from provider, engineering and physical resolution.

## Required changes

### 1. Reduce the first work order to one source-edit vertical slice

The proposed API covers realization capacity, ports, materials,
manufacturing, ledger entries, state/events; control signals, controllers,
faults, plans, state/events; binding links; complete feedback targets; and
source rebinding. That is a cross-child editing framework, not a bounded first
slice. It also makes `insert`, `replace`, `delete`, and dynamic field paths
simultaneously reviewable. Passing a few unknown-path negatives would not
demonstrate that the whole path language is closed.

The first work order should be limited to a realization-child source edit:

* one new disjoint typed source payload/body for the realization child;
* one fixed operation, preferably `replace_source_payload` (or an equally
  small fixed field set), with typed before/after values;
* one typed realization child state plus a typed-absent state; and
* one envelope containing the exact parent G3 candidate/ref/hash and the child
  key, without control or binding population.

The body must use a closed typed schema. `complete typed semantic body` is not
enough as a contract unless the field type and canonical field order are
specified. Do not implement it as `Any`, an untyped dictionary, a free-form
path walker, or a list of old field hashes. Old V5 structs may be read as
shape references, but they cannot be the successor identity because they lack
the new source/provenance/edit fields and require the old concrete package.

Control-child edits and binding/feedback edits should be separate later work
orders. The latter must wait until the exact T0/T1 mapping for child state,
feedback authority, and same-candidate axes is frozen. This preserves the full
parent objective while keeping each implementation gate finite.

### 2. Remove the hidden T0 dependency and prevent duplicate child states

T0 already owns `VNextG3ChildStateV1`, whose current role is a three-entry
typed-absent transport state. The proposal introduces another `G3ChildStateV1`
and does not define a lossless join between the two types. If the new G3 file
imports T0, the dependency points backward from T0's upstream G3 input and
creates an ownership/cycle problem. If it does not import T0, the repository
has two independently named absent-child authorities.

The precursor must therefore have no T0 source import and must say explicitly
that it produces a local contract record only. Its child key must include the
same-candidate parent identity, for example
`(candidate_ref, parent_g3_declaration_hash, child_kind, child_id)`, with
uniqueness checked within the envelope. T1 must later define the single
lossless mapping from this record to the T0/T1 child state; that mapping is a
downstream dependency and cannot be inferred by URI parsing, seed aliasing or
matching names. Until then, the precursor must never claim that it populated
T0's child state.

### 3. Strengthen source and edit identity before implementation

The hash recipe has the right invalidation direction, but the source-content
hash must bind the source schema/canonicalization/profile identity and the
source receipt or typed absence record, in addition to URI/version, candidate
and body. Otherwise a source body can be reused under a changed interpretation
without changing the declared source hash.

The implementation contract should also state:

* `child_id` is scoped by the exact parent declaration hash and candidate; old
  contract URIs and old candidate hashes are not aliases;
* every operation has one closed, typed field-path variant, and the operation
  hash includes the exact typed before/after representation and prior child
  hash;
* source rebinding is a separate operation with a new source record and
  receipt; it is not a generic replacement of URI text;
* parent declaration, candidate, axis, source, operation order or authority
  changes invalidate the affected child and envelope identities; and
* `contract_admission` and `physical_resolution` are separately hashed and
  separately reported, so local edits cannot raise physical status.

For the realization-only slice, the minimum negative controls are foreign
parent/candidate, stale prior child hash, source-content mismatch, duplicate
child key, unknown fixed operation/path, malformed typed absence carrying a
child ref/hash, and attempted old-package/registry import or mutation. The
binding-to-absent-child and full feedback metadata controls belong to the
later binding slice; placing them in the first work order would recreate the
scope problem.

## Finite revised work order

Suggested ID: `UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-PREC`.

The implementer owns exactly:

* `src/GenomeV5/G3/G3RealizationChildSourceEditV1.jl`;
* `test/GenomeV5/G3/g3_realization_child_source_edit_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-PREC/`.

Inputs are the current `G3SourceFeedbackLawV1` source and its frozen hash, the
read-only realization type definitions for field-shape reference, and the
AD-30/T0 accepted-limited contract. The new source must not import or edit the
T0 implementation, old V5 package, shared registry, old receipts, or core
planning files.

Outputs are one closed realization source/body type, one fixed typed source
edit operation, typed actual-or-absent realization state, deterministic source
and child/edit hashes, a contract-admission status matrix, and a focused Julia
receipt capturing raw stdout/stderr bytes, SHA-256, PID and exit code. An
actual external child/provider/engineering/physical result is not an output.

The exit gate is `accepted_limited` only after a different Luna independently
reproduces the hash recipe, checks all listed negatives, confirms no old-file
or registry mutation, and reviews the raw focused receipt and dirty-work
protection. The slice remains `contract_only`; T0 exact transport, T1 package,
provider, mesh, engineering, physical, search, B00/B04 and R01-R10 remain
false or deferred. After this slice is accepted, control and binding slices may
be proposed with disjoint files and an explicit T1 mapping contract.

## Evidence and boundaries

The active architecture and work-order documents retain the AD-30 DAG
`UP1-04A + G1/G2/G3 -> T0 -> T1 -> T2 -> UP1-04A-VNEXT -> UP2-00`. This review
does not alter that DAG or authorize a new task in the core manifest. The
current worktree had 304 porcelain rows at the pre-write snapshot; concurrent
dirty changes are not attributed to this review. No physical or engineering
credit is claimed.

