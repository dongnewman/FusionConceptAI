# AD-30 G3 realization source editability — revised proposal R3

Date: 2026-09-15  
Revision: `R3`  
Supersedes: [R2 proposal](../repair_r2/revised_proposal.md) for this proposal only  
Preserves: [R1 audit](../report.md) and R2 unchanged

## Decision and scope

The first slice is one realization-only candidate-owned source-edit vertical
slice. It defines a closed typed realization source body, a typed parent G3
declaration identity, a typed additive realization-child contract identity,
closed provenance records, typed absence, and one fixed operation:
`replace_source_payload`.

It does not implement or specify control, binding, feedback, a generic dynamic
editor, insert/delete/rebind operations, a T0 import, or T0 child authority.
Those are later, separately gated work. A future T1 work order owns the one
source-backed lossless mapping into `CandidateStatePackageV5Next`.

This remains a contract-only proposal. A locally consistent source state does
not establish actual child authority, provider capability, engineering
feasibility, mesh/solver validity, or physical evidence.

## Exact types

The future implementation owns exactly one new source file:
`src/GenomeV5/G3/G3RealizationSourceEditV1.jl`. It defines closed local typed
records. It may use common typed primitives such as `QualifiedRefV1`,
`GenomeContractRef`, `UnitSignature`, `Rational{Int64}`, and `Digest256`, but
must not alias the old realization genome, the old bundle, or any T0 type.

`G3RealizationChildKeyV1` contains exactly:

```text
candidate_ref::QualifiedRefV1
parent_g3_declaration_hash::Digest256
child_kind::Symbol             # constructor fixes :realization
child_id::String
```

The source payload carries both parent identity and additive child identity:

```text
G3RealizationSourcePayloadV1(
    key::G3RealizationChildKeyV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_contract::G3RealizationChildContractIdentityV1,
    source_uri::String,
    source_version::String,
    body::G3RealizationSourceBodyV1,
    source_record::G3RealizationSourceRecordV1,
    source_content_hash::Digest256)
```

`parent_g3_declaration_ref` must be a typed G3 V1 declaration ref supplied by
the caller and its hash must equal the key's parent hash. It is not a T0 ref.
`G3RealizationChildContractIdentityV1` is a closed record containing the
additive child `GenomeContractRef` plus its independently computed identity
hash. The constructor requires the child contract URI/version/schema hash,
canonicalization hash, and applicability/profile hash to be present and
well-typed; no nullable or label-derived identity is accepted.

`G3RealizationSourceBodyV1` is closed and contains exactly the realization
source semantics: `source_id`, `owner_scope`, typed resource ports, typed
components (capacity/unit/material/manufacturing/state/event), typed material
domains, typed manufacturing domains, typed ledger accounts, typed ledger
entries, and typed ledger closures. It validates unique IDs, references,
units, directions, capacities, material/manufacturing links, ownership and
closure invariants. It accepts no arbitrary extra field.

`G3RealizationProvenanceSlotV1` is a closed present-or-absent value. A present
slot contains an exact typed value/ref, source ref/path, source hash, candidate
ref, and status. An absent slot contains no value or fabricated source hash,
an explicit reason, and an absence-content hash.

`G3RealizationSourceRecordV1` contains source URI/version and exactly four
provenance slots:
`payload_schema_version`, `canonicalization_profile_version`,
`applicability_profile_version`, and `evidence_receipt_version`. It also
contains `source_record_hash`; the hash is calculated from the record body
excluding that field. A closed
`G3RealizationSourceRecordRefV1(record_uri, record_version, record_hash)` is
the only permitted provenance reference in the operation. The source record
has no source-content hash or operation field, so its hash cannot recurse.

The materialized state is:

```text
G3RealizationSourceStateV1(
    key,
    payload::Union{Nothing,G3RealizationSourcePayloadV1},
    source_content_hash::Union{Nothing,Digest256},
    state_status::Symbol,             # :present or :typed_absent
    contract_admission::Symbol,       # :declared_consistent | :terminal_deferred | :fail_closed | :program_exception
    physical_resolution::Symbol,      # :unknown or :terminal_deferred
    absence_reason::Union{Nothing,String},
    absence_content_hash::Union{Nothing,Digest256},
    initial_state_hash::Digest256,
    state_hash::Digest256)
```

An absent state has no payload/source hash, a stable absence marker and
`contract_admission=:terminal_deferred`; a structural contradiction is
`contract_admission=:fail_closed`. `physical_resolution` is an independent
axis and starts at `:unknown` for a locally declared state; a declared missing
physical authority may be recorded as `:terminal_deferred`. No local
constructor or edit operation may promote `physical_resolution`.

## Non-recursive hash and stale-state recipe

All hashes use the repository canonicalizer: valid UTF-8, LF, ordinal field
ordering, declared tuple order, normalized exact rationals, and SHA-256.

1. `child_contract_identity_hash = H(canonical(contract_ref))`. The identity
   hash excludes its own hash field.
2. `source_record_hash = H(canonical(record_uri, record_version,
   payload_schema_slot, canonicalization_slot, applicability_slot,
   evidence_receipt_slot))`. It excludes `source_record_hash` and every
   source-content or operation hash.
3. `source_content_hash = H(canonical(key, parent_g3_declaration_ref,
   parent_g3_declaration_hash, child_contract, source_uri, source_version,
   body, source_record_hash))`. It excludes `source_content_hash` itself.
4. A present initial state is created with no prior operation:
   `initial_state_hash = H(canonical(key, state_status=:present,
   source_content_hash, operation_hash=ZERO_DIGEST))`.
5. A typed-absent initial state uses
   `absence_content_hash = H(canonical(key, state_status=:typed_absent,
   absence_reason, absent_provenance_slot_names))` and
   `initial_state_hash = H(canonical(key, state_status=:typed_absent,
   absence_content_hash, operation_hash=ZERO_DIGEST))`.
6. `G3RealizationReplaceSourcePayloadV1` contains a closed
   `G3RealizationSourceRecordRefV1`, `expected_prior_state_hash`,
   `expected_prior_source_content_hash`, the complete replacement payload,
   and `operation_hash`. Its operation hash is
   `H(canonical(operation_id, key, expected_prior_state_hash,
   expected_prior_source_content_hash, replacement_payload,
   source_record_ref))`; it excludes the resulting state hash.
7. The resulting present state hash is
   `H(canonical(key, state_status=:present, replacement_source_content_hash,
   operation_hash))`. The resulting absent state has the analogous formula
   using its absence-content hash and `source_content_hash=nothing`.

The two expected prior hashes have distinct meanings. A source-content hash
asserts which complete payload is being replaced; a state hash is the
compare-and-swap identity of the materialized state, including its prior
operation chain. A mismatch in the first is
`fail_closed:stale_source_content_hash`; a mismatch in the second is
`fail_closed:stale_state_hash`. Either mismatch leaves the prior state and
all hashes unchanged. The operation must also recompute the replacement
source-record hash and source-content hash; forged values fail closed.

## Fixed edit operation

The sole operation is an atomic full replacement:

```text
replace_source_payload(
    operation_id::String,
    key::G3RealizationChildKeyV1,
    expected_prior_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    replacement_payload::G3RealizationSourcePayloadV1,
    source_record_ref::G3RealizationSourceRecordRefV1)
```

The replacement key must exactly equal the current key. No dynamic field path,
wildcard, insert, delete, patch list, or generic `rebind_source` operation is
accepted. A changed URI/version is possible only as part of a complete
replacement with a new closed source record and source-record hash. The
operation returns the new state and an operation receipt; neither is physical
evidence.

## Contract versus physical status

`contract_admission` reports only local typed construction, invariant checks,
identity equality, and provenance classification. It may be
`:declared_consistent`, `:terminal_deferred`, `:fail_closed`, or
`:program_exception`.

`physical_resolution` reports whether an applicable physical/engineering
authority has resolved the child. It is independently `:unknown` or
`:terminal_deferred` in this slice. A passing source-body test, source hash,
replace receipt, runner exit, `bridge_ready`, provider label, or old receipt
cannot change it. Provider, engineering, mesh, solver and measured physical
receipts belong to later gates.

## Bounded work order

Suggested ID: `UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R3`.

One Luna implementer owns exactly:

* `src/GenomeV5/G3/G3RealizationSourceEditV1.jl`;
* `test/GenomeV5/G3/g3_realization_source_edit_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R3/`.

Inputs are the current G3 V1 declaration contract, read-only old realization
field definitions for comparison, and fresh typed local values. The task has
no T0 import/dependency and must not redefine T0 child authority. It must not
edit old G3 V5 types/bundle, `CandidateStatePackageV5`, shared entry,
registry, core planning files, or historical receipts.

Outputs are the closed realization source body, typed provenance/absence,
initial/state hash helpers, the fixed replacement operation, focused tests,
and software-only evidence records. Control, binding and feedback child work
is out of scope and must be separate later work orders.

## Negative controls and exit gates

The focused tests must prove:

* foreign candidate, parent G3 ref/hash, child kind/id, or additive child
  contract identity is `fail_closed`;
* open/unknown body fields, bad types, duplicate IDs, bad references,
  unit/direction/capacity/closure contradictions are `fail_closed`;
* absent source schema/canonical/profile/receipt provenance yields typed
  absence and `contract_admission=:terminal_deferred`, with no default hash;
* conflicting provenance value/candidate/source hash/status is `fail_closed`;
* source-record hash and source-content hash are independently recomputable
  and non-recursive;
* a valid full replacement changes source, initial/current state and operation
  hashes as specified;
* stale source hash and stale state hash fail independently and leave state
  unchanged;
* forged replacement or operation hash, changed key, dynamic field path,
  insert/delete/rebind input is rejected; and
* URI/fixture seed/old V5 hash/T0 bundle hash cannot substitute for source
  provenance or authority.

Static review checks only the new proposal/manifest now. The future
implementation gate checks its new file set, UTF-8/control bytes, JSON,
`git diff --check`, and plan validation, then captures one fresh Julia
process's raw stdout/stderr bytes, hashes, PID and exit code. A different Luna
must independently review source, the three non-recursive hash layers, the
two stale-hash paths, absence classification, contract/physical status
separation, and dirty-work protection.

Only `accepted_limited` software contract scope may be recorded after that
review. Actual child authority and T1 mapping remain false until a later
fresh-candidate source-backed gate; provider, engineering, mesh, solver,
physical, search, B00/B04 and R01-R10 remain false.

