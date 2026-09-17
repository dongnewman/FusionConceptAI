# AD-33 G1/G2 editability precursor — revised proposal R1

Date: 2026-09-15  
Revision: repair_r1  
Review repaired: g1_g2_editability_independent_review_r1 (changes_requested)

This additive repair leaves the original AD-33 report and manifest untouched.
It writes no source, test, core plan, task manifest, old receipt, AD-31 or
AD-32 file, and does not authorize Julia, DESC, provider, mesh, solver,
physical or heavy-Python execution.

## Resolution

Keep two acyclic sibling work orders:

- UP1-04A-VNEXT-G1-MECHANISM-EDIT-PREC
- UP1-04A-VNEXT-G2-GEOMETRY-EDIT-PREC

Each remains blocked_pending_architecture_repair until independent review.
Each depends only on UP1-01/02/03 limited contracts and its own UP2-01 V1
declaration, is parallel to the other sibling and T0, and must not depend on
the other sibling, T0, T1 or T2. T0 transports complete child states, T1 owns
lossless CandidateStatePackageV5Next mapping, and T2 owns fresh downstream
identity/receipt rebinding.

All records below are closed typed records. No Dict, Any, JSON blob, open
semantic tuple, dynamic path, old V1/V4 alias, URI-only adapter or fixture
seed is permitted. Variable collections use bounded NTuple{N,T} wrappers with
finite constructor limits. Operation history contains only Digest256 values.

## Parent/declaration envelopes

Both layers use existing closed GenomeContractRef, QualifiedRefV1,
UnitSignature and Digest256 types. The G1 exact records are:

    G1MechanismParentDeclarationRefV1(
        candidate_ref::GenomeContractRef,       # version="v5"
        uri::String,                            # nonempty G1 declaration URI
        version::String,                         # exactly "v1"
        schema_hash::Digest256,
        canonicalization_hash::Digest256,
        compatibility_profile::String)

    G1MechanismV1BaselineBindingV1(
        baseline_ref::QualifiedRefV1,           # version="v1"
        source_path::String,                    # repository-relative exact path
        source_bytes_hash::Digest256,           # exact source-backed V1 bytes
        semantic_body_hash::Digest256,          # H(ad33:g1:v1-semantic-body:v1)
        v1_baseline_hash::Digest256)

    G1MechanismParentEnvelopeV1(
        candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_ref_identity_hash::Digest256,
        parent_declaration_hash::Digest256,
        v1_baseline::G1MechanismV1BaselineBindingV1,
        parent_binding_hash::Digest256)

G2 has the same field order with these exact types:

    G2GeometryParentDeclarationRefV1(
        candidate_ref::GenomeContractRef,       # version="v5"
        uri::String,
        version::String,                         # exactly "v1"
        schema_hash::Digest256,
        canonicalization_hash::Digest256,
        compatibility_profile::String)

    G2GeometryV1BaselineBindingV1(
        baseline_ref::QualifiedRefV1,
        source_path::String,
        source_bytes_hash::Digest256,
        semantic_body_hash::Digest256,
        v1_baseline_hash::Digest256)

    G2GeometryParentEnvelopeV1(
        candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_ref_identity_hash::Digest256,
        parent_declaration_hash::Digest256,
        v1_baseline::G2GeometryV1BaselineBindingV1,
        parent_binding_hash::Digest256)

For G1, recompute and require:

1. parent_ref.candidate_ref == candidate_ref and candidate version is v5;
2. parent_ref_identity_hash =
   H(ad33:g1:parent-ref:v1, candidate_ref, uri, version, schema_hash,
   canonicalization_hash, compatibility_profile), in that fixed order;
3. semantic_body_hash from the exact V1 declaration semantic body, never the
   child body;
4. source_bytes_hash from the exact source-backed V1 bytes at source_path;
5. v1_baseline_hash =
   H(ad33:g1:v1-baseline:v1, baseline_ref, source_path, source_bytes_hash,
   semantic_body_hash);
6. parent_declaration_hash independently source-backed and equal to the
   selected V1 declaration hash, never URI/fixture/child derived;
7. parent_binding_hash =
   H(ad33:g1:parent-binding:v1, candidate_ref, parent_ref,
   parent_ref_identity_hash, parent_declaration_hash, v1_baseline_hash).

G2 applies the same seven rules with ad33:g2 domain tags. Its existing V1
contract_ref is not a parent binding. Foreign candidate, foreign parent,
wrong parent hash, wrong baseline, ref-only authority or synthetic fixture
authority are fail_closed with their closed error codes.

## Child keys and contract identity

    G1MechanismChildKeyV1(
        candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_declaration_hash::Digest256,
        child_kind::Symbol,                     # fixed :mechanism
        child_id::String)

    G1MechanismChildContractRefV1(
        uri::String, version::String, schema_hash::Digest256,
        canonicalization_hash::Digest256,
        applicability_profile_hash::Digest256,
        compatibility_profile::String)

    G2GeometryChildKeyV1(
        candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_declaration_hash::Digest256,
        child_kind::Symbol,                     # fixed :geometry
        child_id::String)

    G2GeometryChildContractRefV1(
        uri::String, version::String, schema_hash::Digest256,
        canonicalization_hash::Digest256,
        applicability_profile_hash::Digest256,
        compatibility_profile::String)

The stored child_contract_identity_hash is independently recomputed:
G1 uses H(ad33:g1:child-contract-identity:v1, uri, version, schema_hash,
canonicalization_hash, applicability_profile_hash, compatibility_profile);
G2 uses the same fixed fields with ad33:g2. The key's candidate, parent and
parent hash must equal the envelope. URI alone, ref-only identity and fixture
seeds are not authority.

## Four typed provenance slots and typed absence

Each sibling has four separate present slot types:
PayloadSchemaSlotV1, CanonicalizationSlotV1, ApplicabilitySlotV1 and
EvidenceReceiptSlotV1. Their G1 exact field shape is:

    G1PayloadSchemaSlotV1(
        axis::Symbol,                         # fixed :payload_schema_version
        value::G1AxisValueV1,
        locator::String, source_hash::Digest256,
        candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_declaration_hash::Digest256,
        child_key::G1MechanismChildKeyV1,
        child_contract_ref::G1MechanismChildContractRefV1,
        child_contract_identity_hash::Digest256,
        status::Symbol)                       # fixed :present

    G1AxisValueV1(value::String, value_ref::QualifiedRefV1,
                  value_version::String)

    G1CanonicalizationSlotV1(
        axis::Symbol, value::G1AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G1MechanismChildKeyV1,
        child_contract_ref::G1MechanismChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)
    G1ApplicabilitySlotV1(
        axis::Symbol, value::G1AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G1MechanismChildKeyV1,
        child_contract_ref::G1MechanismChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)
    G1EvidenceReceiptSlotV1(
        axis::Symbol, value::G1AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G1MechanismChildKeyV1,
        child_contract_ref::G1MechanismChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)

    G1ProvenanceAbsentV1(
        axis::Symbol, reason::String,
        candidate_ref::GenomeContractRef,
        parent_ref::G1MechanismParentDeclarationRefV1,
        parent_declaration_hash::Digest256,
        child_key::G1MechanismChildKeyV1,
        child_contract_ref::G1MechanismChildContractRefV1,
        child_contract_identity_hash::Digest256,
        absence_content_hash::Digest256)

G2 defines G2AxisValueV1 and the four G2 slot types plus
G2ProvenanceAbsentV1 with the same fields and G2 types. Each present
constructor fixes its axis and status, requires typed value_ref and locator,
and checks every candidate/parent/child equality. An absent record has no
value, locator or source hash. Its hash is exactly:

The G2 slot records are explicitly:

    G2PayloadSchemaSlotV1(
        axis::Symbol, value::G2AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G2GeometryChildKeyV1,
        child_contract_ref::G2GeometryChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)
    G2CanonicalizationSlotV1(
        axis::Symbol, value::G2AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G2GeometryChildKeyV1,
        child_contract_ref::G2GeometryChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)
    G2ApplicabilitySlotV1(
        axis::Symbol, value::G2AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G2GeometryChildKeyV1,
        child_contract_ref::G2GeometryChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)
    G2EvidenceReceiptSlotV1(
        axis::Symbol, value::G2AxisValueV1, locator::String,
        source_hash::Digest256, candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G2GeometryChildKeyV1,
        child_contract_ref::G2GeometryChildContractRefV1,
        child_contract_identity_hash::Digest256, status::Symbol)
    G2ProvenanceAbsentV1(
        axis::Symbol, reason::String, candidate_ref::GenomeContractRef,
        parent_ref::G2GeometryParentDeclarationRefV1,
        parent_declaration_hash::Digest256, child_key::G2GeometryChildKeyV1,
        child_contract_ref::G2GeometryChildContractRefV1,
        child_contract_identity_hash::Digest256,
        absence_content_hash::Digest256)

    H(ad33:<layer>:provenance-absence:v1, axis, candidate_ref, parent_ref,
      parent_declaration_hash, child_key, child_contract_ref,
      child_contract_identity_hash, reason)

Every source record has one exact present-or-absent union per axis. No slot
contains source_record_hash, source_content_hash or operation/state hashes.

## Source payloads and semantic bodies

G1 outer records:

    G1MechanismSourceRecordV1(
        record_uri::String, record_version::String,
        payload_schema::Union{G1PayloadSchemaSlotV1,G1ProvenanceAbsentV1},
        canonicalization_profile::Union{G1CanonicalizationSlotV1,G1ProvenanceAbsentV1},
        applicability_profile::Union{G1ApplicabilitySlotV1,G1ProvenanceAbsentV1},
        evidence_receipt::Union{G1EvidenceReceiptSlotV1,G1ProvenanceAbsentV1},
        source_record_hash::Digest256)

    G1MechanismSourcePayloadV1(
        key::G1MechanismChildKeyV1,
        parent_envelope::G1MechanismParentEnvelopeV1,
        child_contract_ref::G1MechanismChildContractRefV1,
        child_contract_identity_hash::Digest256,
        source_uri::String, source_version::String,
        body::G1MechanismSourceBodyV1,
        source_record::G1MechanismSourceRecordV1,
        source_content_hash::Digest256)

    G1MechanismSourceRecordRefV1(
        record_uri::String, record_version::String, record_hash::Digest256)

G2 substitutes G2GeometrySourceRecordV1, G2GeometrySourcePayloadV1 and
G2GeometrySourceRecordRefV1 with G2 types. A record ref is derived only from
payload record URI/version/hash.

source_record_hash =
H(ad33:<layer>:source-record:v1, record_uri, record_version,
payload_schema, canonicalization_profile, applicability_profile,
evidence_receipt), excluding itself and all later hashes. source_uri equals
record_uri and source_version equals record_version.

G1MechanismSourceBodyV1 exact top-level fields:

    source_id::String
    owner_scope::String
    state_set::G1BoundedStateSetV1
    operator_set::G1BoundedOperatorSetV1
    edge_set::G1BoundedOperatorEdgeSetV1
    governing_roots::G1BoundedRefSetV1
    constraint_roots::G1BoundedRefSetV1
    occurrence_set::G1BoundedOccurrenceSetV1
    closure_accounts::G1BoundedClosureAccountSetV1
    applicability::G1ApplicabilityDeclarationV1
    negative_controls::G1BoundedSymbolSetV1

Nested records are new closed local types with typed IDs/refs,
PhysicalType, UnitSignature, temporal kind, derivative order, occurrence kind,
Rational{Int64} coefficients, complete ledger identity and exact scope. Every
bounded wrapper is NTuple{N,T} with a finite maximum and uniqueness check.
G1 owns state, operators, units, derivatives, governing/additive/constraint
roles, occurrence/closure ledger and applicability.

G2GeometrySourceBodyV1 exact top-level fields:

    source_id::String
    owner_scope::String
    chart_set::G2BoundedChartSetV1
    region_set::G2BoundedRegionSetV1
    interface_set::G2BoundedInterfaceSetV1
    boundary_faces::NTuple{6,G2FaceOwnerV1}
    metric_declarations::G2BoundedMetricSetV1
    field_targets::G2BoundedFieldTargetSetV1
    mesh_plan::G2GeometryMeshPlanV1
    discretization_profile::G2DiscretizationProfileV1
    units::G2GeometryUnitContractV1
    applicability::G2ApplicabilityDeclarationV1
    negative_controls::G2BoundedSymbolSetV1

G2GeometryMeshPlanV1.execution_status is a Symbol whose constructor accepts
only :not_executed. No :declared or :executed value is representable. Mesh
plan, geometry, mesh/evaluation and solver-input hashes stay separate.
Symbolic authority.mesh=:unique_match cannot alter execution_status.

## Six non-recursive hash layers

Each layer has a literal domain tag and fixed order; all hashes are Digest256.
A hash field is excluded from its own domain. No domain includes a state
object, operation result or later hash:

    child_contract_identity_hash =
      H(ad33:<layer>:child-contract-identity:v1,
        child_contract_ref.uri, child_contract_ref.version,
        child_contract_ref.schema_hash,
        child_contract_ref.canonicalization_hash,
        child_contract_ref.applicability_profile_hash,
        child_contract_ref.compatibility_profile)

    source_record_hash =
      H(ad33:<layer>:source-record:v1, record_uri, record_version,
        payload_schema, canonicalization_profile,
        applicability_profile, evidence_receipt)

    source_content_hash =
      H(ad33:<layer>:source-content:v1, key, parent_envelope,
        child_contract_ref, child_contract_identity_hash, source_uri,
        source_version, closed_body, source_record_hash)

    initial_state_hash =
      H(ad33:<layer>:initial-state:v1, key, state_status,
        source_payload_ref_or_nothing, editable_body_or_nothing,
        initial_source_content_hash_or_nothing, current_source_cas_hash,
        absence_reason_or_nothing, absence_content_hash_or_nothing,
        contract_admission, physical_resolution,
        ZERO_OPERATION_DIGEST, EMPTY_HISTORY)

    canonical_input_hash =
      H(ad33:<layer>:operation-input:v1, operation_id, key,
        expected_prior_state_hash, expected_prior_source_content_hash,
        replacement_payload, derived_source_record_ref)

    operation_hash =
      H(ad33:<layer>:operation:v1, operation_id, key,
        expected_prior_state_hash, expected_prior_source_content_hash,
        replacement_payload, derived_source_record_ref,
        canonical_input_hash)

    result_state_hash =
      H(ad33:<layer>:result-state:v1, key, state_status,
        source_payload_ref_or_nothing, editable_body_or_nothing,
        source_content_or_absence_hash, contract_admission,
        physical_resolution, operation_hash, prior_operation_digest_history)

The six layers are child-contract, source-record, source-content, initial-state,
operation and result/current-state. canonical_input_hash is receipt-only.
ZERO_OPERATION_DIGEST is H(ad33:<layer>:zero-operation:v1, "empty"), not a
literal zero string.

History is digest-only and closed:

    G1OperationHistoryV1{N}(digests::NTuple{N,Digest256})  # 0 <= N <= 64
    G2OperationHistoryV1{N}(digests::NTuple{N,Digest256})  # 0 <= N <= 64

No state object, operation record, payload or receipt occurs in history.
last_operation_hash is the zero digest only for empty history and otherwise
equals the final digest.

## State, operation input, record and receipt fields

G1 exact outer records (G2 substitutes G2 types):

    G1MechanismSourcePayloadRefV1(
        key::G1MechanismChildKeyV1,
        parent_binding_hash::Digest256,
        child_contract_identity_hash::Digest256,
        source_record_ref::G1MechanismSourceRecordRefV1,
        source_content_hash::Digest256)

    G1MechanismStateV1(
        key::G1MechanismChildKeyV1,
        state_status::Symbol,
        source_payload_ref::Union{Nothing,G1MechanismSourcePayloadRefV1},
        editable_body::Union{Nothing,G1MechanismSourceBodyV1},
        initial_source_content_hash::Union{Nothing,Digest256},
        current_source_content_hash::Union{Nothing,Digest256},
        current_source_cas_hash::Digest256,
        absence_reason::Union{Nothing,String},
        absence_content_hash::Union{Nothing,Digest256},
        contract_admission::Symbol,
        physical_resolution::Symbol,
        initial_state_hash::Digest256,
        current_state_hash::Digest256,
        last_operation_hash::Digest256,
        operation_history::G1OperationHistoryV1)

    G1ReplaceSourcePayloadInputV1(
        operation_id::String,
        key::G1MechanismChildKeyV1,
        expected_prior_state_hash::Digest256,
        expected_prior_source_content_hash::Digest256,
        replacement_payload::G1MechanismSourcePayloadV1,
        source_record_ref::G1MechanismSourceRecordRefV1,
        canonical_input_hash::Digest256,
        operation_hash::Digest256)

    G1OperationRecordV1(
        operation_id::String,
        key::G1MechanismChildKeyV1,
        previous_state_hash::Digest256,
        previous_source_content_hash::Digest256,
        replacement_source_payload_ref::G1MechanismSourcePayloadRefV1,
        source_record_ref::G1MechanismSourceRecordRefV1,
        canonical_input_hash::Digest256,
        operation_hash::Digest256,
        resulting_state_hash::Digest256,
        status::Symbol)                         # exactly :applied

    G1EditReceiptV1(
        operation_id::String, key::G1MechanismChildKeyV1,
        receipt_status::Symbol, error_code::Symbol, error_path::String,
        canonical_input_hash::Digest256, operation_hash::Digest256,
        prior_state_hash::Digest256, prior_source_content_hash::Digest256,
        result_state_hash::Union{Nothing,Digest256},
        prior_state_canonical_bytes::String,
        result_state_canonical_bytes::String,
        prior_state_sha256::Digest256, result_state_sha256::Digest256,
        published::Bool, history_advanced::Bool)

A rejected receipt has receipt_status=:rejected, published=false,
history_advanced=false, result_state_hash=nothing, and exact equality of
prior/result canonical bytes and SHA. It is returned only and never stored.
An applied receipt has :applied, published=true, history_advanced=true and a
recomputed result state hash. G2 uses the same exact field order with G2 types.

For avoidance of an implicit adapter, the G2 records are instantiated with
these exact names and field substitutions, in the same order: 
G2GeometrySourcePayloadRefV1(key::G2GeometryChildKeyV1,
parent_binding_hash::Digest256, child_contract_identity_hash::Digest256,
source_record_ref::G2GeometrySourceRecordRefV1, source_content_hash::Digest256);
G2GeometryStateV1(key::G2GeometryChildKeyV1, state_status::Symbol,
source_payload_ref::Union{Nothing,G2GeometrySourcePayloadRefV1},
editable_body::Union{Nothing,G2GeometrySourceBodyV1},
initial_source_content_hash::Union{Nothing,Digest256},
current_source_content_hash::Union{Nothing,Digest256},
current_source_cas_hash::Digest256, absence_reason::Union{Nothing,String},
absence_content_hash::Union{Nothing,Digest256}, contract_admission::Symbol,
physical_resolution::Symbol, initial_state_hash::Digest256,
current_state_hash::Digest256, last_operation_hash::Digest256,
operation_history::G2OperationHistoryV1); 
G2ReplaceSourcePayloadInputV1(operation_id::String, key::G2GeometryChildKeyV1,
expected_prior_state_hash::Digest256,
expected_prior_source_content_hash::Digest256,
replacement_payload::G2GeometrySourcePayloadV1,
source_record_ref::G2GeometrySourceRecordRefV1,
canonical_input_hash::Digest256, operation_hash::Digest256);
G2OperationRecordV1(operation_id::String, key::G2GeometryChildKeyV1,
previous_state_hash::Digest256, previous_source_content_hash::Digest256,
replacement_source_payload_ref::G2GeometrySourcePayloadRefV1,
source_record_ref::G2GeometrySourceRecordRefV1,
canonical_input_hash::Digest256, operation_hash::Digest256,
resulting_state_hash::Digest256, status::Symbol); and
G2EditReceiptV1 with the exact G1 receipt field order, replacing G1 key and
digest/ref types with G2 types. No untyped or ref-only G2 adapter is allowed.

Typed absence has state_status=:typed_absent, no payload/body/source hash,
contract_admission=:terminal_deferred, a nonempty reason, absence hash and
current_source_cas_hash=absence_content_hash. A present state has
state_status=:present and payload/body. physical_resolution is only unknown
or terminal_deferred.

## Exact transition algorithm and CAS order

replace_source_payload is the only public operation. No mutation occurs before
step 9:

1. Type-check the closed input and operation ID; malformed input returns a
   rejected receipt with malformed_operation.
2. Serialize the published prior state with the fixed canonicalizer and record
   prior bytes and prior SHA-256.
3. Compare input.key to state.key and recompute candidate, parent, baseline,
   child-contract, source-record and payload identities.
4. Verify derived source-record ref equals input.source_record_ref and recompute
   canonical_input_hash and operation_hash.
5. Compare expected_prior_state_hash to state.current_state_hash first. On
   mismatch return stale_state_hash and stop; source CAS is not reported.
6. If state CAS matches, compare expected_prior_source_content_hash to
   state.current_source_cas_hash. On mismatch return stale_source_content_hash.
7. Validate replacement body, all four slots, all hashes and, for G2,
   execution_status=:not_executed. Missing authority is typed absence/
   terminal_deferred; contradiction is provenance_conflict/fail_closed.
8. Compute payload ref, operation record, digest-only history and result hash.
9. Publish exactly one immutable state and applied operation record, then return
   an applied receipt with old/new bytes and hashes.

Every rejection returns only a receipt, leaves published state, hashes, last
operation and history unchanged, and never appends the failure receipt.
Every failed operation preserves prior canonical bytes and SHA exactly.

## Closed error set and required controls

The only error codes are:

    :none, :malformed_operation, :foreign_candidate, :foreign_parent_ref,
    :parent_ref_identity_hash_mismatch, :parent_declaration_hash_mismatch,
    :v1_baseline_hash_mismatch, :ref_only_authority,
    :synthetic_fixture_authority, :child_kind_mismatch, :child_id_mismatch,
    :child_contract_ref_mismatch, :child_contract_identity_hash_mismatch,
    :malformed_body, :duplicate_id, :unresolved_reference, :unit_mismatch,
    :closure_mismatch, :applicability_mismatch, :provenance_axis_mismatch,
    :provenance_absent, :provenance_conflict, :source_record_hash_mismatch,
    :source_record_ref_mismatch, :source_content_hash_mismatch,
    :canonical_input_hash_mismatch, :operation_hash_mismatch,
    :state_hash_mismatch, :history_mismatch, :stale_state_hash,
    :stale_source_content_hash, :unsupported_operation, :dynamic_field_path,
    :partial_patch, :insert_delete_rebind, :multi_object_edit,
    :mesh_execution_status_not_executed,
    :symbolic_authority_execution_confusion, :metric_or_orientation_invalid,
    :face_or_boundary_invalid, :program_exception

Both tests cover foreign identity, ref-only/synthetic authority, independent
baseline mismatch, each provenance absence/conflict, all six hash tamper paths,
frozen CAS order, forged hashes, every unsupported edit shape, and exact
failed-operation byte/SHA stability. G1 adds operator/field/ledger/closure
controls. G2 adds chart/metric/orientation/face/boundary, unit,
basis/quadrature and mesh-plan controls.

For G2:

    G2GeometryMeshPlanV1(..., execution_status=:declared)
        -> fail_closed:mesh_execution_status_not_executed

    authority.mesh=:unique_match with execution_status=:not_executed
        -> terminal_deferred:mesh_execution_not_executed

A symbolic authority cannot promote mesh execution, provider/solver
resolution or physical evidence.

## Exact file and command scope

No launcher is added; future tests are directly invoked.

G1 exact write set:

    src/GenomeV5/G1/G1MechanismChildEditabilityV1.jl
    test/GenomeV5/G1/g1_mechanism_child_editability_v1_contract_tests.jl
    test/GenomeV5/G1/g1_mechanism_child_editability_v1_fixture.json
    test/GenomeV5/G1/static_qa_g1_mechanism_child_editability_v1.py
    docs/implementation/UP1-04A-VNEXT-G1-MECHANISM-EDIT-PREC/README.md
    docs/implementation/UP1-04A-VNEXT-G1-MECHANISM-EDIT-PREC/manifest.json

    python test/GenomeV5/G1/static_qa_g1_mechanism_child_editability_v1.py
    julia --startup-file=no --project=. test/GenomeV5/G1/g1_mechanism_child_editability_v1_contract_tests.jl

G2 exact write set:

    src/GenomeV5/G2/G2GeometryChildEditabilityV1.jl
    test/GenomeV5/G2/g2_geometry_child_editability_v1_contract_tests.jl
    test/GenomeV5/G2/g2_geometry_child_editability_v1_fixture.json
    test/GenomeV5/G2/static_qa_g2_geometry_child_editability_v1.py
    docs/implementation/UP1-04A-VNEXT-G2-GEOMETRY-EDIT-PREC/README.md
    docs/implementation/UP1-04A-VNEXT-G2-GEOMETRY-EDIT-PREC/manifest.json

    python test/GenomeV5/G2/static_qa_g2_geometry_child_editability_v1.py
    julia --startup-file=no --project=. test/GenomeV5/G2/g2_geometry_child_editability_v1_contract_tests.jl

No existing V1 source/test/fixture, shared entry point, old package/registry,
core planning file, task manifest, run, receipt, AD-31 or AD-32 file may be
written. A focused acceptance remains software contract-only and requires a
different Luna pass_limited review.

## Remaining blockers

F03-F08 are now specified for independent review. Implementation remains
blocked until review confirms:

1. real source-backed V1 baseline bytes and semantic hashes are available
   without synthetic seeds;
2. the repository canonicalizer represents bounded wrappers and the zero
   operation digest without open or recursive values; and
3. the owner later synchronizes reviewed sibling nodes into the core DAG. This
   repair does not synchronize those records.

Until then both nodes remain blocked_pending_architecture_repair and all
T0/T1/T2/UP2/B00/B04/provider/mesh/engineering/physical/search/R01-R10 credits
remain false.
