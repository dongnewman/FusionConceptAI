# AD-33 G1/G2 candidate-owned editability precursor — R2 repair

Date: 2026-09-15  
Status: `blocked_pending_architecture_repair`  
Review basis: `g1_g2_editability_independent_review_r2`, decision `changes_requested`  
Scope: additive work-order architecture only. This file is a replacement proposal for R1 clauses; it does not authorize implementation.

The two candidates remain independent sibling work orders. G1 owns the mechanism/source-body edit surface. G2 owns the geometry/metric-boundary edit surface. Neither sibling depends on the other, T0, T1, or T2. T0 remains transport, T1 remains the sole lossless-package mapper, and T2 remains downstream identity/receipt rebinding. No machine node is created by this repair.

All implementation, provider, mesh, physical, search, B00, B04, engineering, or R01–R10 credit remains false. `provider=false`, `mesh=false`, `physical=false`, `search=false`; R01–R10 are preserved as existing evidence labels and receive no new credit. The only permitted future evidence is typed contract/static QA evidence in the exact scopes below.

## A. Actual V1 binding

### A.1 Closed ref types and the G1 candidate/public-contract relation

The repository types are not interchangeable:

    QualifiedRefV1(id::String, version::String)
    GenomeContractRef(uri::String, version::String, schema_hash::Digest256,
                      canonicalization_hash::Digest256,
                      compatibility_profile::String)

G1 V1 stores `candidate_ref::QualifiedRefV1`; G2 V1 stores
`candidate_ref::GenomeContractRef` inside `G2MBSourceV1`. Therefore G1 never
asserts `QualifiedRefV1 == GenomeContractRef` and never stores a URI-only
adapter. It uses this closed additive binding:

    struct G1CandidateContractBindingV2
        v1_candidate_ref::QualifiedRefV1
        public_contract_ref::GenomeContractRef
        public_role::Symbol
        exact_candidate_id::String
        exact_candidate_version::String
    end

    struct G2CandidateContractBindingV2
        v1_candidate_ref::GenomeContractRef
        public_contract_ref::GenomeContractRef
        public_role::Symbol
    end

For G1 the equality predicate is fixed, typed, and one-way:

    g1_candidate_binding_equal(b) =
        b.v1_candidate_ref.id == b.exact_candidate_id &&
        b.v1_candidate_ref.version == b.exact_candidate_version &&
        b.exact_candidate_version == "v5" &&
        b.public_role == :mechanism &&
        b.public_contract_ref.version == "v5"

The public contract's five fields are compared exactly to the expected additive
public contract record supplied in the binding. The public contract URI,
schema hash, canonicalization hash, and compatibility profile are not derived
from `QualifiedRefV1`. The binding stores both refs and the exact candidate
id/version copy, so a changed G1 V1 candidate, a changed public contract, or
a changed projection copy fails closed. G2 uses exact five-field equality
between the declaration source candidate and public contract binding.

The child key consequently has the correct source type:

    G1MechanismChildKeyV2(
        candidate_binding::G1CandidateContractBindingV2,
        parent_ref::G1V1ParentRefV2,
        parent_declaration_hash::Digest256,
        child_kind::Symbol, child_id::String)

    G2GeometryChildKeyV2(
        candidate_binding::G2CandidateContractBindingV2,
        parent_ref::G2V1ParentRefV2,
        parent_declaration_hash::Digest256,
        child_kind::Symbol, child_id::String)

`child_kind` is exactly `:g1_mechanism_edit_precursor` or
`:g2_geometry_edit_precursor`; no sibling can be re-bound by a string alias.

The parent/declaration envelope referenced by those keys is closed and
independent for each sibling:

    G1V1ParentRefV2(
        actual_candidate_ref::QualifiedRefV1,
        source_ref::QualifiedRefV1,
        locator::G1V1BaselineLocatorV2,
        declaration_type::String,
        factory_identity::String,
        candidate_binding::G1CandidateContractBindingV2,
        parent_ref_identity_hash::Digest256)

    G1ParentEnvelopeV2(
        candidate_binding::G1CandidateContractBindingV2,
        parent_ref::G1V1ParentRefV2,
        parent_ref_identity_hash::Digest256,
        parent_declaration_hash::Digest256,
        v1_baseline_hash::Digest256,
        parent_binding_hash::Digest256)

    G2V1ParentRefV2(
        actual_candidate_ref::GenomeContractRef,
        source_ref::QualifiedRefV1,
        locator::G2V1BaselineLocatorV2,
        declaration_type::String,
        factory_identity::String,
        candidate_binding::G2CandidateContractBindingV2,
        parent_ref_identity_hash::Digest256)

    G2ParentEnvelopeV2(
        candidate_binding::G2CandidateContractBindingV2,
        parent_ref::G2V1ParentRefV2,
        parent_ref_identity_hash::Digest256,
        parent_declaration_hash::Digest256,
        v1_baseline_hash::Digest256,
        parent_binding_hash::Digest256)

The exact recomputations are, in order:

    parent_ref_identity_hash = H(
        "ad33:<layer>:v1-parent-ref-identity:v2",
        actual_candidate_ref, source_ref, locator.module_path,
        locator.module_identity, locator.declaration_type,
        locator.factory_identity, candidate_binding)

    v1_baseline_hash = H(
        "ad33:<layer>:v1-baseline:v2",
        locator, source_bytes_sha256, semantic_body_sha256,
        parent_declaration_hash)

    parent_binding_hash = H(
        "ad33:<layer>:v1-parent-binding:v2",
        candidate_binding, parent_ref_identity_hash,
        parent_declaration_hash, v1_baseline_hash)

The stored hashes and all candidate/source/locator fields are compared to
these recomputations. A parent ref whose actual V1 candidate is absent,
foreign, fixture-derived, or only a URI is rejected; a missing real baseline
becomes the typed absent record below and cannot be silently converted to a
present parent envelope.

### A.2 Source-backed locator, factory input, and baseline record

Each baseline must be obtained from the existing V1 module/declaration
contract. A fixture seed, copied JSON value, URI, or manually typed hash is
not a baseline authority. These fixed locator records are required:

    G1V1BaselineLocatorV2(
        module_path::String,
        module_identity::String,
        declaration_type::String,
        factory_identity::String,
        factory_input_locator::String,
        source_path::String)

    G2V1BaselineLocatorV2(
        module_path::String,
        module_identity::String,
        declaration_type::String,
        factory_identity::String,
        factory_input_locator::String,
        source_path::String)

The exact G1 locator is

    module_path = "src/GenomeV5/G1/DiffusionDeclarationV1.jl"
    module_identity = "FusionConceptAI.GenomeV5.G1.DiffusionDeclarationV1"
    declaration_type = "G1DiffusionDeclarationV1"
    factory_identity = "G1DiffusionDeclarationV1(candidate_ref,source_ref,
      source_version,source_hash,u,K,f,operators,closure_ref,
      applicability_ref,applicability_domain,negative_controls;
      ownership,source_payload,declaration_hash)"
    factory_input_locator = "G1DiffusionDeclarationV1 constructor input record"
    source_path = module_path

The exact G2 locator is

    module_path = "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"
    module_identity = "FusionConceptAI.GenomeV5.G2.MetricBoundaryDeclarationV1"
    declaration_type = "G2MBDeclarationV1"
    factory_identity = "G2MBDeclarationV1(contract_ref,source,schema_hash,
      canonicalization_hash,profile_hash,declaration_hash)"
    factory_input_locator = "G2MBDeclarationV1 constructor input record"
    source_path = module_path

The factory input records are closed and contain no `Any`, dictionary, open
tuple, or reference-only value:

    G1V1FactoryInputV2(
        candidate_ref::QualifiedRefV1,
        source_ref::QualifiedRefV1,
        source_version::String,
        source_hash::Digest256,
        u::G1DiffusionScalarFieldV1,
        K::G1DiffusionCoefficientFieldV1,
        f::G1DiffusionScalarFieldV1,
        operators::G1DiffusionOperatorChainV1,
        closure_ref::QualifiedRefV1,
        applicability_ref::QualifiedRefV1,
        applicability_domain::String,
        ownership::Symbol,
        negative_controls::G1SymbolControlsV2,
        source_payload::G1DiffusionSourcePayloadV1)

    G2V1FactoryInputV2(
        contract_ref::GenomeContractRef,
        source::G2MBSourceV1,
        schema_hash::Digest256,
        canonicalization_hash::Digest256,
        profile_hash::Digest256)

`G1SymbolControlsV2{N}` is a bounded `NTuple{N,Symbol}` with `0 <= N <= 16`;
it is converted to the V1 closed symbol tuple only at the factory boundary.
The factory input is candidate-bound before invoking the actual declaration
constructor: G1 compares `candidate_ref` with
`G1CandidateContractBindingV2.v1_candidate_ref`; G2 compares
`source.candidate_ref` with `G2CandidateContractBindingV2.v1_candidate_ref`.

The additive baseline records are:

    G1V1BaselinePresentV2(
        locator::G1V1BaselineLocatorV2,
        factory_input::G1V1FactoryInputV2,
        declaration::G1DiffusionDeclarationV1,
        candidate_binding::G1CandidateContractBindingV2,
        source_bytes_sha256::Digest256,
        semantic_body_sha256::Digest256,
        parent_declaration_sha256::Digest256)

    G2V1BaselinePresentV2(
        locator::G2V1BaselineLocatorV2,
        factory_input::G2V1FactoryInputV2,
        declaration::G2MBDeclarationV1,
        candidate_binding::G2CandidateContractBindingV2,
        source_bytes_sha256::Digest256,
        semantic_body_sha256::Digest256,
        parent_declaration_sha256::Digest256)

    G1V1BaselineAbsentV2(
        locator::G1V1BaselineLocatorV2,
        candidate_binding::G1CandidateContractBindingV2,
        reason::Symbol,
        reason_locator::String,
        absence_hash::Digest256)

    G2V1BaselineAbsentV2(
        locator::G2V1BaselineLocatorV2,
        candidate_binding::G2CandidateContractBindingV2,
        reason::Symbol,
        reason_locator::String,
        absence_hash::Digest256)

The baseline result is a closed union of exactly the present and absent record
for that sibling. If the repository cannot locate a real V1 factory input and
construct a real declaration instance, the result is the typed absent record
with `reason=:v1_declaration_instance_unavailable` and
`contract_admission=:terminal_deferred`; no synthetic instance is permitted.

### A.3 Exact recomputation and semantic-body projection

For each present record, the following algorithm is mandatory and the stored
values are compared byte-for-byte:

1. Read exactly `locator.source_path` as raw bytes. Compute
   `source_bytes_sha256 = SHA256(domain="ad33:<layer>:v1-source-bytes:v2",
   bytes)`. The locator's module identity and factory identity are compared to
   the selected declaration type and factory symbol.
2. Construct the declaration by calling the recorded factory with the closed
   `factory_input`. A fixture, a JSON hash, a URI-only ref, or a constructor
   return value not reached from this source-backed input is rejected with
   `synthetic_fixture_authority` or `ref_only_authority`.
3. Compute the exact G1 semantic projection in this fixed order:
   `candidate_ref, source_ref, source_version, source_payload, source_hash,
   u, K, f, operators, closure_ref, applicability_ref,
   applicability_domain, ownership, negative_controls`. The projection is a
   typed record `G1V1SemanticBodyProjectionV2`; it excludes only
   `declaration_hash` and no other declaration field.
4. Compute the exact G2 semantic projection in this fixed order:
   `contract_ref, source, schema_hash, canonicalization_hash, profile_hash`.
   The projection is `G2V1SemanticBodyProjectionV2`; it excludes only
   `declaration_hash`.
5. Canonicalize the fixed projection with the repository typed canonicalizer,
   prefix the domain `ad33:<layer>:v1-semantic-body:v2`, and compute
   `semantic_body_sha256::Digest256`.
6. Recompute `parent_declaration_sha256` from the declaration's V1
   `declaration_hash` using
   `H(ad33:<layer>:v1-parent-declaration:v2, declaration.declaration_hash)`.
   Recompute the declaration's own hash from the constructor's fixed semantic
   body and compare it to the stored declaration hash before this wrapper hash.
7. Compare source SHA, semantic SHA, parent declaration SHA, all candidate
   binding fields, the locator, and the stored public contract binding. Any
   mismatch is closed rejection. The wrapper never hashes itself or a later
   parent/child hash, so no hash recursion exists.

For a G1 present baseline, `QualifiedRefV1` is retained in the actual
declaration and the public `GenomeContractRef` is retained in the independent
binding. For a G2 present baseline, both are the actual public contract ref
and exact equality is required. The child parent envelope stores the complete
typed baseline record, not only a ref or URI.

## B. Deterministic malformed receipt and CAS contract

### B.1 Typed zero values

Malformed input can fail before a user operation has a valid id, key, or
digest. The returned receipt still has one deterministic typed representation.
The following constants are frozen and are transport sentinels only; they can
never be published into state or history:

    ZERO_G1_OPERATION_ID = "ad33:g1:zero-operation:v2"
    ZERO_G2_OPERATION_ID = "ad33:g2:zero-operation:v2"
    ZERO_G1_CANDIDATE_REF = QualifiedRefV1("ad33:g1:zero-candidate:v2", "v5")
    ZERO_G2_CANDIDATE_REF = GenomeContractRef(
        "ad33:g2:zero-candidate:v2", "v5",
        H("ad33:g2:zero-key-schema:v2", "empty"),
        H("ad33:g2:zero-key-canonical:v2", "empty"),
        "ad33:g2:zero-profile:v2")
    ZERO_G1_PUBLIC_CONTRACT = GenomeContractRef(
        "ad33:g1:zero-contract:v2", "v5",
        H("ad33:g1:zero-key-schema:v2", "empty"),
        H("ad33:g1:zero-key-canonical:v2", "empty"),
        "ad33:g1:zero-profile:v2")

    ZERO_G1_SOURCE_REF = QualifiedRefV1("ad33:g1:zero-source:v2", "v1")
    ZERO_G2_SOURCE_REF = QualifiedRefV1("ad33:g2:zero-source:v2", "v1")
    ZERO_G1_LOCATOR = G1V1BaselineLocatorV2(
        "ad33:g1:zero-module:v2", "ad33:g1:zero-module-identity:v2",
        "G1ZeroDeclarationV2", "G1ZeroFactoryV2",
        "ad33:g1:zero-factory-input:v2", "ad33:g1:zero-source-path:v2")
    ZERO_G2_LOCATOR = G2V1BaselineLocatorV2(
        "ad33:g2:zero-module:v2", "ad33:g2:zero-module-identity:v2",
        "G2ZeroDeclarationV2", "G2ZeroFactoryV2",
        "ad33:g2:zero-factory-input:v2", "ad33:g2:zero-source-path:v2")

    ZERO_G1_BINDING = G1CandidateContractBindingV2(
        ZERO_G1_CANDIDATE_REF, ZERO_G1_PUBLIC_CONTRACT, :mechanism,
        "ad33:g1:zero-candidate:v2", "v5")
    ZERO_G2_BINDING = G2CandidateContractBindingV2(
        ZERO_G2_CANDIDATE_REF, ZERO_G2_CANDIDATE_REF, :field_geometry)
    ZERO_G1_PARENT_REF = G1V1ParentRefV2(
        ZERO_G1_CANDIDATE_REF, ZERO_G1_SOURCE_REF, ZERO_G1_LOCATOR,
        "G1ZeroDeclarationV2", "G1ZeroFactoryV2", ZERO_G1_BINDING,
        H("ad33:g1:zero-parent-ref:v2", "empty"))
    ZERO_G2_PARENT_REF = G2V1ParentRefV2(
        ZERO_G2_CANDIDATE_REF, ZERO_G2_SOURCE_REF, ZERO_G2_LOCATOR,
        "G2ZeroDeclarationV2", "G2ZeroFactoryV2", ZERO_G2_BINDING,
        H("ad33:g2:zero-parent-ref:v2", "empty"))
    ZERO_G1_KEY = G1MechanismChildKeyV2(
        ZERO_G1_BINDING, ZERO_G1_PARENT_REF,
        H("ad33:g1:zero-parent-declaration:v2", "empty"),
        :malformed_transport, "ad33:zero-child:v2")
    ZERO_G2_KEY = G2GeometryChildKeyV2(
        ZERO_G2_BINDING, ZERO_G2_PARENT_REF,
        H("ad33:g2:zero-parent-declaration:v2", "empty"),
        :malformed_transport, "ad33:zero-child:v2")

The zero child keys are these exact closed values, with
`child_kind=:malformed_transport` and `child_id="ad33:zero-child:v2"`.
All `H(...)` calls above use SHA-256 and the named domain; no field is
implicit. The zero keys are not authority fixtures: admission rejects them
before any published-state path. They exist only to make a malformed receipt
typed.

Each digest sentinel has its own exact domain and empty payload:

    ZERO_CANONICAL_INPUT_HASH = H("ad33:receipt:zero-canonical-input:v2", "empty")
    ZERO_OPERATION_HASH       = H("ad33:receipt:zero-operation:v2", "empty")
    ZERO_PRIOR_STATE_HASH     = H("ad33:receipt:zero-prior-state:v2", "empty")
    ZERO_PRIOR_SOURCE_HASH    = H("ad33:receipt:zero-prior-source:v2", "empty")
    ZERO_RESULT_STATE_HASH    = H("ad33:receipt:zero-result-state:v2", "empty")
    ZERO_BYTES_SHA256         = H("ad33:receipt:zero-canonical-bytes:v2", "empty")

`ZERO_OPERATION_HASH` is distinct from the normal zero history operation
digest domain. The history zero digest remains
`H("ad33:<layer>:zero-operation-digest:v2", "empty")`.

### B.2 Closed receipt types and truth table

The exact common receipt shape, with G1/G2 key and state substitutions, is:

    EditReceiptV2(
        operation_id::String,
        key::G1MechanismChildKeyV2_or_G2GeometryChildKeyV2,
        receipt_status::Symbol,
        error_code::Symbol,
        error_path::String,
        canonical_input_hash::Digest256,
        operation_hash::Digest256,
        prior_state_hash::Digest256,
        prior_source_content_hash::Digest256,
        result_state_present::Bool,
        result_state_hash::Digest256,
        prior_canonical_bytes::CanonicalBytesV2,
        result_canonical_bytes::CanonicalBytesV2,
        prior_canonical_bytes_sha256::Digest256,
        result_canonical_bytes_sha256::Digest256,
        published::Bool,
        history_advanced::Bool)

The displayed `or` is a closed per-sibling specialization, not an open
union: the implementation must declare `G1EditReceiptV2` and
`G2EditReceiptV2` separately with identical field order and concrete sibling
key types. `CanonicalBytesV2{N}` is bounded at `N <= 1_048_576`; malformed
receipts use `CanonicalBytesV2{0}(())`.

The cross-field truth table is exhaustive:

    receipt_status        error_code                 result_present published history_advanced
    rejected              none                       false          false     false   INVALID
    rejected              any closed non-none error  false          false     false   VALID
    applied               none                       true           true      true    VALID
    applied               any non-none error         any            any       any     INVALID

For every rejected receipt `result_state_hash == ZERO_RESULT_STATE_HASH` and
result canonical bytes/SHA equal the prior canonical bytes/SHA. A malformed
pre-CAS receipt additionally has `operation_id == ZERO_*_OPERATION_ID`, the
typed zero key, all five zero digests, `error_code=:malformed_operation`,
`error_path="/operation"`, and empty canonical bytes with
`ZERO_BYTES_SHA256`. A stale or semantic rejection has the actual operation
id/key and actual prior state snapshot, but still has `published=false` and
`history_advanced=false`. A receipt with any other field combination is
`program_exception` and is itself rejected from the published receipt stream.

### B.3 Frozen transition algorithm and failure atomicity

The operation input and operation record are closed per sibling:

    ReplaceSourcePayloadInputV2(
        operation_id::String,
        key::G1MechanismChildKeyV2_or_G2GeometryChildKeyV2,
        expected_prior_state_hash::Digest256,
        expected_prior_source_content_hash::Digest256,
        replacement_source_payload::G1MechanismSourcePayloadV2_or_G2GeometrySourcePayloadV2)

    OperationRecordV2(
        operation_id::String,
        key::same concrete sibling key,
        previous_state_hash::Digest256,
        previous_source_content_hash::Digest256,
        canonical_input_hash::Digest256,
        operation_hash::Digest256,
        resulting_state_hash::Digest256)

The implementation executes this exact order:

1. Decode/type-check the input. If malformed, return the deterministic
   pre-CAS rejected receipt above and stop before reading or writing state.
2. Serialize the currently published state to canonical bytes and calculate
   its SHA. Recompute all key, parent, baseline, child-contract, and source
   record identities. Do not mutate anything.
3. Recompute the canonical input hash and operation hash from fixed field
   order. A supplied mismatch returns `canonical_input_hash_mismatch` or
   `operation_hash_mismatch` using the actual prior snapshot.
4. Compare `expected_prior_state_hash` first. A mismatch returns
   `stale_state_hash` and stops; source CAS is not evaluated.
5. Only if state CAS passes, compare
   `expected_prior_source_content_hash`. A mismatch returns
   `stale_source_content_hash` and stops.
6. Validate the replacement body, all four provenance axes, G2 mesh seam, and
   all recomputed hashes. Any failure returns a closed rejected receipt.
7. Compute the new source record, operation record, result state bytes/SHA,
   result-state hash, and digest-only history candidate in local immutable
   values.
8. Publish exactly one new immutable state and operation record, then publish
   the applied receipt. Append only the operation digest to history after the
   state and operation record are complete.

No rejected receipt is inserted into published state, last-operation state, or
history. On every rejection, the prior canonical bytes, prior SHA, published
state hash, source-content hash, operation history, and last applied operation
remain strictly byte-for-byte unchanged. This is checked for malformed,
state-stale, source-stale, hash-tamper, structural, provenance, and seam
errors.

## C. G2 mesh seam and error naming

### C.1 Public constructor

The public mesh plan has no `Symbol` status and no `:declared` value:

    struct G2MeshExecutionNotExecutedV2 end
    const G2_NOT_EXECUTED = G2MeshExecutionNotExecutedV2()

    G2GeometryMeshPlanV2(
        chart_ref::QualifiedRefV1,
        plan_ref::QualifiedRefV1,
        execution_status::G2MeshExecutionNotExecutedV2,
        plan_hash::Digest256)

The only public constructor method accepts `G2MeshExecutionNotExecutedV2`.
There is no constructor method from `Symbol`, string, `Val{:declared}`, or
an unchecked field assignment. Consequently a public value with declared or
executed status cannot be fabricated.

### C.2 Controlled decoder/tamper negative-control seam

The test-only admission boundary may inspect a raw, typed wire record:

    G2MeshWireRecordV2(
        chart_ref::QualifiedRefV1,
        plan_ref::QualifiedRefV1,
        execution_status_token::String,
        plan_hash::Digest256)

The closed decoder is:

    decode_g2_mesh_wire_v2(w::G2MeshWireRecordV2) =
        w.execution_status_token == "not_executed" ?
            G2MeshDecodeSuccessV2(G2GeometryMeshPlanV2(
                w.chart_ref, w.plan_ref, G2_NOT_EXECUTED, w.plan_hash)) :
        G2MeshDecodeFailureV2(:mesh_execution_status_invalid, "/execution_status")

The raw record with token `"declared"` is a controlled tamper test seam. It
is never converted to a public mesh plan and never reaches normal admission.
The structural error is exactly `mesh_execution_status_invalid`.

For a valid public plan with `G2_NOT_EXECUTED` and
`authority.mesh=:unique_match`, admission returns
`contract_admission=:terminal_deferred`, gap
`mesh_execution_not_executed`, and no execution/physical claim. These are
distinct cases: `mesh_execution_status_invalid` means an invalid structural
wire value; `mesh_execution_not_executed` means a valid typed plan whose
execution evidence is absent. They must not be merged or renamed.

## D. Four provenance axes, six hashes, and history retained from R1

Each sibling retains four independent typed present slots and one typed absent
slot per axis: payload schema, canonicalization, applicability, and evidence
receipt. Every slot contains exactly `axis`, `field`, `status`, `value_ref`,
`locator`, `source_hash`, `candidate_binding`, `parent_ref`,
`parent_declaration_hash`, `child_key`, `child_contract_ref`, and
`child_contract_identity_hash`. A typed absent record contains the same
bindings plus `reason` and
`H(ad33:<layer>:provenance-absence:v2, axis, field, locator, source_hash,
candidate, parent, parent_hash, child, contract, child_hash, reason)`.

The six non-recursive layers remain, with fixed field order and no self or
later hash: child-contract identity, source record, source content, initial
state, operation, and result/current state. Every digest is `Digest256` and
uses the explicit `ad33:<layer>:<purpose>:v2` domain. History is only
`G1OperationHistoryV2{N}(digests::NTuple{N,Digest256})` or its G2 sibling,
with `0 <= N <= 64`; it contains no state, payload, operation, receipt, or
history object. Identity and provenance fields are recomputed independently.

## E. Exact future work-order scope and gates

G1 source files: `src/GenomeV5/G1/G1MechanismEditabilityPrecursorV2.jl` and
`src/GenomeV5/G1/G1V1BaselineBindingV2.jl`; tests:
`test/g1_mechanism_editability_precursor_v2_test.jl` and
`test/g1_v1_baseline_binding_v2_test.jl`; fixture/static QA files under
`test/fixtures/ad33_g1_g2_editability_v2/` and
`docs/implementation/AD-33/g1_g2_editability_audit/`; archive README/manifest
under the same additive node directory. G2 uses the corresponding two source
files and two tests under `src/GenomeV5/G2/` and `test/`.

There is no launcher. The future direct commands are only:

    julia --project=. test/g1_mechanism_editability_precursor_v2_test.jl
    julia --project=. test/g1_v1_baseline_binding_v2_test.jl
    julia --project=. test/g2_geometry_editability_precursor_v2_test.jl
    julia --project=. test/g2_v1_baseline_binding_v2_test.jl

Static QA must first prove the files are additive and the baseline is
source-backed, then run the negative controls. A work order cannot exit
`blocked_pending_architecture_repair` until both sibling static QA records,
focused test exits, and independent review are present. No provider, mesh,
physical, search, B00, B04, or R01–R10 claim can be promoted by these tests.

## F. Closed error set and required negative controls

The repaired closed errors include all R1 codes plus
`mesh_execution_status_invalid` and retain
`mesh_execution_not_executed`. The complete relevant set is:

    malformed_operation, foreign_candidate, foreign_parent_ref,
    parent_ref_identity_hash_mismatch, parent_declaration_hash_mismatch,
    v1_baseline_hash_mismatch, v1_declaration_instance_unavailable,
    ref_only_authority, synthetic_fixture_authority, child_kind_mismatch,
    child_id_mismatch, child_contract_ref_mismatch,
    child_contract_identity_hash_mismatch, malformed_body, duplicate_id,
    unresolved_reference, unit_mismatch, closure_mismatch,
    applicability_mismatch, provenance_axis_mismatch, provenance_absent,
    provenance_conflict, source_record_hash_mismatch,
    source_record_ref_mismatch, source_content_hash_mismatch,
    canonical_input_hash_mismatch, operation_hash_mismatch,
    state_hash_mismatch, history_mismatch, stale_state_hash,
    stale_source_content_hash, unsupported_operation, dynamic_field_path,
    partial_patch, insert_delete_rebind, multi_object_edit,
    mesh_execution_status_invalid, mesh_execution_not_executed,
    symbolic_authority_execution_confusion, metric_or_orientation_invalid,
    face_or_boundary_invalid, program_exception

Negative controls are required for a G1 QualifiedRef/public-contract mismatch,
foreign candidate, foreign parent, fixture-only baseline, unavailable real
V1 instance, changed source bytes, semantic projection field mutation,
declaration hash mutation, each provenance absence/conflict, every six-layer
hash tamper, malformed pre-CAS input, stale state, stale source, operation
replay, rejected receipt insertion, prior-byte/SHA mutation, G2 wire token
`declared`, G2 public constructor attempts from Symbol/Val/string, and valid
G2 `unique_match + G2_NOT_EXECUTED` terminal-deferred admission. The last two
G2 controls must produce respectively `mesh_execution_status_invalid` and
`mesh_execution_not_executed`.

## G. Remaining blockers and decision

This R2 repair closes the reviewable architecture gaps but does not claim
acceptance. The actual repository currently has no verified source-backed V1
declaration instance for this additive precursor; implementation must emit
the typed baseline absent record and `terminal_deferred` until an owner adds a
real factory input and declaration receipt. The public contract hashes and
candidate binding still require independent review after implementation.

The candidate decision remains two sibling work orders, both blocked pending
architecture repair and independent review. No implementation is dispatched,
no core/task manifest is synchronized, and no existing source, test, receipt,
AD-31, AD-32, R01–R10, or prior repair artifact is changed.
