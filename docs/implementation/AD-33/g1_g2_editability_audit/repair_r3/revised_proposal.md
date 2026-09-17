# AD-33 G1/G2 candidate-owned editability precursor — R3 repair

Date: 2026-09-15  
Status: `blocked_pending_architecture_repair`  
Review basis: `g1_g2_editability_independent_review_r3`, decision `changes_requested`  
Scope: additive architecture and future work-order boundary only. This repair does not authorize implementation.

R3 accepts the review finding that a real V1 declaration instance is currently unavailable, but makes the absent identity path representable without fabricating a parent ref or hash. The only future prerequisite is the shared sibling:
`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`. G1 and G2 remain separate editable siblings and depend on this prerequisite plus their own V1 declaration contract. They remain parallel with T0 and do not unlock T1 or T2.

All provider, mesh, physical, solver, engineering, search, B00, B04, and R01–R10 credits remain false. A typed-absent scaffold is the maximum permitted implementation in the prerequisite. A present child, source publication, execution, or physical claim remains blocked until a real source-backed V1 declaration instance and factory receipt exist.

## 1. Shared prerequisite work order

`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC` is the single additive prerequisite for both siblings. Its exact future write scope is:

    src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl
    test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl
    test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json
    test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py
    docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/**

There is no launcher. Its only future direct command is:

    julia --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl

Static QA is invoked directly as a file-level check by the work order. The
fixture is expected-test data only and can never be an authority source for a
present binding. No shared entry, core planning file, task manifest, existing
V1 source/test, AD-31/AD-32 artifact, or old receipt is in this scope.

The prerequisite depends on UP1-01/02/03 and the existing UP2-01 G1/G2 V1
contracts only for type names and declaration contracts. It is parallel with
T0, does not depend on T0/T1/T2, and does not grant T1 lossless-package or T2
identity/receipt authority.

Its input is a closed typed request:

    ParentBaselineBindingRequestV1{L}(
        layer::L,
        requested_candidate::LayerCandidateRefV1{L},
        requested_public_contract::GenomeContractRef,
        child_contract::ChildContractSchemaIdentityV1{L},
        requested_child_kind::LayerChildKindV1{L})

The present evidence input is separate and cannot be supplied by a fixture:

    SourceBackedV1DeclarationReceiptV1{L}(
        layer::L,
        actual_candidate::LayerCandidateRefV1{L},
        public_contract::GenomeContractRef,
        actual_parent_ref::LayerParentRefV1{L},
        source_locator::SourceLocatorV1,
        factory_receipt::FactoryConstructionReceiptV1{L},
        raw_source_sha256::Digest256,
        semantic_body_sha256::Digest256,
        parent_declaration_sha256::Digest256,
        source_record_sha256::Digest256)

`LayerCandidateRefV1{G1}` is the actual `QualifiedRefV1`; its independent
public contract binding is explicit. `LayerCandidateRefV1{G2}` is the actual
five-field `GenomeContractRef` from `G2MBSourceV1`. No URI-only adapter,
`Any`, dictionary, open tuple, or synthetic candidate is accepted.

The output is a closed per-layer union:

    ParentBaselineBindingV1{L} = Union{
        PresentParentBaselineBindingV1{L},
        AbsentParentBaselineBindingV1{L}}

and a corresponding closed child-key union:

    ChildKeyV1{L} = Union{PresentChildKeyV1{L}, AbsentChildKeyV1{L}}

The shared node may implement and test only the absent branch while the real
source-backed receipt is unavailable. It may define the present branch schema,
but it must not construct a present value or publish a present child without
that receipt.

## 2. Exact parent-baseline union

### 2.1 Present branch

The present branch contains all authority needed to bind a real V1 parent:

    PresentParentBaselineBindingV1{L}(
        layer::L,
        actual_parent_ref::LayerParentRefV1{L},
        parent_declaration_hash::Digest256,
        baseline_raw_source_sha256::Digest256,
        baseline_semantic_body_sha256::Digest256,
        source_locator::SourceLocatorV1,
        factory_receipt::FactoryConstructionReceiptV1{L},
        requested_candidate::LayerCandidateRefV1{L},
        public_contract::GenomeContractRef,
        parent_binding_hash::Digest256)

The field order is frozen. `actual_parent_ref` is present only after the
factory receipt proves that it came from the recorded V1 declaration type.
`factory_receipt` contains exact module identity, factory identity, typed
construction input locator, declaration type, and construction status:

    FactoryConstructionReceiptV1{L}(
        module_identity::String,
        declaration_type::String,
        factory_identity::String,
        input_locator::String,
        construction_status::Symbol,
        candidate_binding_status::Symbol,
        declaration_hash_recomputed::Bool)

`construction_status` must be `:source_backed_present` and
`candidate_binding_status` must be `:exact`. A fixture receipt or a receipt
whose declaration hash was not recomputed is rejected as
`synthetic_fixture_authority` or `parent_declaration_hash_mismatch`.

The present binding hash has this exact non-recursive domain and fixed order:

    parent_binding_hash = H(
        "ad33:<layer>:parent-baseline-present:v1",
        layer,
        actual_parent_ref,
        parent_declaration_hash,
        baseline_raw_source_sha256,
        baseline_semantic_body_sha256,
        source_locator,
        factory_receipt,
        requested_candidate,
        public_contract)

The hash excludes `parent_binding_hash` itself and every child/state/operation
hash. All fields are recomputed from the source-backed receipt and compared
exactly before the present branch is admitted.

### 2.2 Absent branch

The absent branch contains no parent ref and no parent or baseline hash:

    AbsentParentBaselineBindingV1{L}(
        layer::L,
        requested_candidate::LayerCandidateRefV1{L},
        requested_public_contract::GenomeContractRef,
        reason::Symbol,
        absence_domain::String,
        absence_digest::Digest256)

The field order above is complete. The absent branch has no fields named
`actual_parent_ref`, `parent_declaration_hash`, `baseline_raw_source_sha256`,
`baseline_semantic_body_sha256`, `source_locator`, `factory_receipt`, or
`parent_binding_hash`. It cannot fabricate a placeholder for any of them.

The only permitted absent domain is exactly
`ad33:<layer>:parent-baseline-absent:v1`. The absence digest is recomputed as:

    absence_digest = H(
        "ad33:<layer>:parent-baseline-absent:v1",
        layer,
        requested_candidate,
        requested_public_contract,
        reason)

`reason` is closed and includes `:v1_declaration_instance_unavailable`,
`:source_locator_unavailable`, `:factory_input_unavailable`, and
`:candidate_binding_unavailable`. The layer, requested candidate, all five
public-contract fields, reason, domain, and digest are exact-compared. An
absent result always has `contract_admission=:terminal_deferred`.

No absent hash is an overloaded member of the six source/state/operation hash
layers. It is a separate identity-bound absence digest and does not refer to a
future child or state hash.

## 3. Exact child-key union

### 3.1 Present child key

A present child key can be created only from a present parent binding:

    PresentChildKeyV1{L}(
        layer::L,
        requested_candidate::LayerCandidateRefV1{L},
        public_contract::GenomeContractRef,
        child_kind::LayerChildKindV1{L},
        child_id::String,
        child_contract::ChildContractSchemaIdentityV1{L},
        parent_binding::PresentParentBaselineBindingV1{L},
        actual_parent_ref::LayerParentRefV1{L},
        parent_declaration_hash::Digest256,
        child_key_digest::Digest256)

Its exact key digest is:

    child_key_digest = H(
        "ad33:<layer>:child-key-present:v1",
        layer,
        requested_candidate,
        public_contract,
        child_kind,
        child_id,
        child_contract,
        parent_binding.parent_binding_hash,
        actual_parent_ref,
        parent_declaration_hash)

The parent ref and parent declaration hash are independently recomputed from
`parent_binding`; a child cannot supply a different copy.

### 3.2 Absent child key

An absent child key preserves a requested identity without pretending that a
parent exists:

    AbsentChildKeyV1{L}(
        layer::L,
        requested_candidate::LayerCandidateRefV1{L},
        requested_public_contract::GenomeContractRef,
        child_kind::LayerChildKindV1{L},
        child_id::String,
        child_contract_schema_identity::ChildContractSchemaIdentityV1{L},
        parent_binding_absence_digest::Digest256,
        child_key_digest::Digest256)

The absent key has no `actual_parent_ref`, `parent_declaration_hash`,
`parent_binding_hash`, baseline hash, source locator, or factory receipt. Its
key digest is exactly:

    child_key_digest = H(
        "ad33:<layer>:child-key-absent:v1",
        layer,
        requested_candidate,
        requested_public_contract,
        child_kind,
        child_id,
        child_contract_schema_identity,
        parent_binding_absence_digest)

`parent_binding_absence_digest` must equal the absent parent union's
`absence_digest`, and no future child/state/operation hash is included. The
child contract schema identity is a closed record containing the actual
contract ref, schema hash, canonicalization hash, compatibility profile, and
its independently recomputed identity digest.

## 4. State, edit operation, and absent-to-present rule

The G1 and G2 state specializations are structurally identical but use their
actual layer types:

    LayerEditStateV1{L}(
        layer::L,
        baseline_binding::ParentBaselineBindingV1{L},
        child_key::ChildKeyV1{L},
        source_payload::LayerSourcePayloadOrTypedAbsentV1{L},
        contract_admission::Symbol,
        state_hash::Digest256,
        canonical_bytes::CanonicalBytesV1)

An absent state must have an `AbsentParentBaselineBindingV1`, an
`AbsentChildKeyV1`, a typed-absent source payload, and exactly
`contract_admission=:terminal_deferred`. It has no parent hash, baseline hash,
actual parent ref, or present source payload.

`replace_source_payload` is forbidden when the current state is absent. The
operation decoder returns `baseline_authority_absent`, leaves state and history
unchanged, and emits the existing rejected-receipt contract with exact prior
bytes and SHA. It cannot promote absent to present through CAS or through a
changed expected source hash.

Absent to present requires a fresh, separately reviewed publication:

    FreshPresentSourcePublicationV1{L}(
        new_source_record::LayerSourceRecordV1{L},
        new_source_content_sha256::Digest256,
        source_backed_v1_declaration_receipt::SourceBackedV1DeclarationReceiptV1{L},
        new_parent_binding::PresentParentBaselineBindingV1{L},
        new_present_child_key::PresentChildKeyV1{L},
        candidate_identity_review::FreshCandidateIdentityReviewV1{L})

This publication gets a new source record, new child state, new candidate
identity review, and new state/operation hashes. It is not a CAS promotion,
not a replacement operation, and not allowed before the actual source-backed
factory/declaration receipt exists. The prerequisite work order never
publishes this present object; it only defines and tests the gate.

## 5. G1/G2 sibling relationship and exact future scopes

G1 remains `UP1-04A-VNEXT-G1-MECHANISM-EDIT-PREC`; it owns mechanism/source
body fields and depends on the shared prerequisite plus
`UP2-01-G1-DIFFUSION-V1`. G2 remains
`UP1-04A-VNEXT-G2-GEOMETRY-EDIT-PREC`; it owns geometry/metric-boundary fields
and depends on the shared prerequisite plus
`UP2-01-G2-METRIC-BOUNDARY-V1`. They do not depend on each other, T0, T1, or
T2. The shared prerequisite and both siblings are parallel with T0.

The sibling source/test/archive scopes remain additive and are not written in
this repair. Their present-child implementation and execution stay blocked
until the shared node has a source-backed receipt and a separate review.

## 6. Negative controls and exit gates

The shared prerequisite must test all of the following:

- absent branch rejects any parent ref, parent declaration hash, baseline raw
  hash, baseline semantic hash, source locator, factory receipt, or fabricated
  parent binding hash field;
- absence digest changes when layer, requested candidate, any public-contract
  field, or reason changes, and rejects a wrong domain tag;
- present branch rejects fixture-only input, URI-only input, wrong module or
  factory identity, non-recomputed declaration hash, candidate mismatch, raw
  source mismatch, semantic projection mutation, and parent binding hash
  mutation;
- absent child key rejects parent hash/ref fields and recomputes its own key
  digest only from the absent fixed field order;
- `replace_source_payload` on typed-absent state returns
  `baseline_authority_absent`, does not enter history, and preserves prior
  canonical bytes and SHA;
- absent-to-present CAS promotion, operation replay, and a supplied present
  child without a fresh source publication are rejected;
- G1 `QualifiedRefV1` versus public `GenomeContractRef` binding and G2 exact
  five-field binding are independently checked;
- the R1/R2 four provenance axes, six non-recursive hashes, digest-only
  history, malformed pre-CAS receipt, dual CAS order, and G2
  `mesh_execution_status_invalid` versus `mesh_execution_not_executed`
  controls remain intact.

The shared node exits only when its static QA, focused test exit, manifest,
and independent review prove the closed unions, absence domains, and atomic
absent-state behavior. A typed-absent scaffold may then be implemented. A
present binding or present child remains blocked until a source-backed V1
instance receipt is recorded and independently reviewed.

## 7. Decision and remaining blockers

R3 changes the recommended future graph by adding exactly one shared additive
parent-baseline-binding prerequisite before the two editable siblings. This
closes the identity graph without inventing a V1 declaration. The current
repository still lacks the real source-backed declaration instance and factory
receipt, so the current state remains `blocked_pending_architecture_repair`.
No implementation is dispatched, no core/task manifest is synchronized, and
no provider, mesh, physical, search, B00, B04, engineering, or R01–R10 credit
is promoted.
