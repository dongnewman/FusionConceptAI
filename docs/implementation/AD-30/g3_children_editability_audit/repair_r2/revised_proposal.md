# AD-30 G3 child editability audit — revised proposal R2

Date: 2026-09-15  
Revision: `R2`  
Parent record: [R1 audit](../report.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Narrow decision

The first implementation slice is reduced to one realization-only,
candidate-owned source-edit vertical slice. It defines one closed typed
realization source body and one fixed operation, `replace_source_payload`.
It does not define a generic editor, control child, binding child, feedback
child, or a second T0 authority mechanism.

This is a contract-only precursor. It may be implemented without importing or
depending on AD-30 T0 and without actual G2 or four-axis receipts. Missing
source provenance is represented as typed absence with `terminal_deferred`.
Only a future T0/T1 fresh-candidate join may establish the child authority and
perform the unique lossless mapping into `CandidateStatePackageV5Next`.

The R1 audit remains unchanged. This R2 document supersedes only its broad
first work-order proposal; it does not change the core planning files or the
parent R01–R10 obligations.

## Closed realization source contract

The proposed new additive source file is
`src/GenomeV5/G3/G3RealizationSourceEditV1.jl`. It must define new local typed
records rather than aliasing the old realization genome or accepting a
`Dict`, open `NamedTuple`, JSON blob, or dynamic `Any` body.

`G3RealizationSourceBodyV1` is a closed record with these fields:

* `source_id::String` and `owner_scope::String`;
* `resource_ports`, each with stable port ID, resource kind, direction,
  `UnitSignature`, and ledger account ID;
* `components`, each with stable component ID, kind, resource-port IDs,
  positive exact capacity and unit, material ID, manufacturing-process ID,
  passive flag, typed initial states, and typed events;
* `material_domains`, each with material ID, property, exact lower/upper
  bounds, and unit;
* `manufacturing_domains`, each with process ID, parameter, exact lower/upper
  bounds, and unit;
* `ledger_accounts`, each with account ID, domain, unit, and owner;
* `ledger_entries`, each with entry ID, account/port/component IDs, exact
  nonzero coefficient, unit, and effect; and
* `ledger_closures`, each with closure ID, domain, unique account IDs, and
  exact expected balance.

The constructor validates unique IDs, reference resolution, direction/kind and
unit consistency, material/manufacturing references, entry ownership, closure
membership, and local balance/capacity invariants. This body is only the
candidate-owned realization source state. It does not claim a provider,
manufacturing approval, engineering feasibility, mesh, solver result, or
physical result.

`G3RealizationChildKeyV1` is immutable and contains exactly:

```text
(candidate_ref, parent_g3_declaration_hash, child_kind=:realization, child_id)
```

`child_kind` and `child_id` are fixed by construction. A candidate, parent G3
declaration hash, kind, or child ID mismatch is `fail_closed`; a fixture label
or a parsed URI cannot create a key.

## Provenance and typed absence

`G3RealizationEvidenceSlotV1` is a closed slot used for each of:
`payload_schema_version`, `canonicalization_profile_version`,
`applicability_profile_version`, and `evidence_receipt_version`. A present
slot carries the exact typed ref/value, source ref/path, source content hash,
candidate ref, and status. An absent slot carries no fabricated value or hash,
an explicit reason, and an absence-content hash. The source identity includes
all four slots, including absent markers.

`G3RealizationSourcePayloadV1` contains the child key, source URI/version,
closed source body, the four provenance slots, and
`source_content_hash = H(canonical((child_key, source_uri, source_version,
source_body, provenance_slots)))`.

`G3RealizationSourceStateV1` is either:

* `present`, with a payload whose hash is recomputed from its complete body; or
* `typed_absent`, with `payload=nothing`, `source_content_hash=nothing`, a
  stable absence reason, `resolution=terminal_deferred`, and an
  `absence_content_hash` over the complete marker.

Absent source schema/profile/receipt provenance remains an independent gap.
Conflicting candidate, parent hash, source hash, slot value, or status is
`fail_closed`. A source URI, old V5 hash, fixture seed, or local version label
does not count as provenance.

## Fixed edit operation

The only operation is
`G3RealizationReplaceSourcePayloadV1(operation_id, child_key,
expected_prior_source_content_hash, replacement_payload, provenance_ref,
operation_hash)`. It replaces the complete closed source payload atomically.
The key must remain exactly equal; a changed source URI/version is allowed only
inside the complete replacement and only when its new provenance is supplied.

There is no field path, wildcard, insert, delete, patch list, generic
`rebind_source` operation, or operation dispatch by a string label. Any such
input is rejected. The operation hash is:

```text
H(canonical((operation_id, child_key,
             expected_prior_source_content_hash,
             replacement_payload, provenance_ref)))
```

The replacement is accepted only when the expected prior hash equals the
current state hash and the replacement payload hash recomputes exactly. A
stale expected hash returns `fail_closed` and leaves the prior state intact.
The resulting child state hash is:

```text
H(canonical((child_key, source_content_hash, operation_hash, status)))
```

The typed-absent state also has a stable state hash. No operation receipt is
physical or engineering evidence.

## File ownership and bounded work order

Suggested ID: `UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R2`.

One Luna implementer owns exactly:

* `src/GenomeV5/G3/G3RealizationSourceEditV1.jl`;
* `test/GenomeV5/G3/g3_realization_source_edit_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R2/`.

Inputs are the current `G3SourceFeedbackLawV1` contract, the read-only old G3
realization source/type for field comparison, the accepted-limited AD-30
semantic boundary, and fresh locally constructed typed values. The task must
not import or depend on T0 source types/functions, modify any T0 file, or
redefine T0's child authority. It must not edit old G3 V5 types, the old
bundle/package, shared entries, the default registry, core planning files, or
historical receipts.

Outputs are the closed realization source payload/state, the fixed replacement
operation and canonical hash helpers, typed provenance/absence behavior, a
focused test receipt, and a scoped implementation manifest. The output is
software contract evidence only.

Control, binding, and feedback child editability are explicitly deferred to
separate later work orders. Their absence in this slice must not be presented
as an implementation of those children.

## Required negative controls and exit gates

The focused test must prove, from source/invariants rather than copied
expected strings:

1. foreign candidate, parent declaration hash, child kind, or child ID is
   rejected;
2. open body fields, wrong types, duplicate IDs, bad references, unit/
   direction conflicts, invalid closure, or invalid capacity is fail-closed;
3. absent schema/canonical/profile/receipt provenance creates typed absence and
   `terminal_deferred`, with no default or fabricated hash;
4. conflicting provenance slot value, candidate, source hash, or status is
   fail-closed;
5. a complete `replace_source_payload` changes the source and child hashes;
6. a stale prior hash, changed child key, or forged replacement hash is
   fail-closed and does not mutate the old state;
7. dynamic field-path, insert/delete, or generic rebind input is rejected;
8. source URI, fixture seed, old V5 candidate hash, or T0 bundle hash cannot
   stand in for source provenance; and
9. no old package, shared registry, or T0 type/function is imported or edited.

The static gate checks only the new file set, valid JSON, UTF-8/control-byte
absence, `git diff --check`, and the plan validator. The software gate runs
one fresh Julia process, captures raw stdout/stderr bytes, SHA-256, PID and
exit code, and records the exact source/test inputs. A different Luna reviews
the closed body, hash recomputation, absence and stale-hash controls, receipt
bytes, and dirty-work protection.

The only possible implementation status is `accepted_limited` for this local
contract slice after independent review. It cannot set actual child authority,
provider, engineering, mesh, solver, physical, search, B00/B04, or R01–R10
status. A future T1 work order must perform the unique field-by-field,
source-backed lossless mapping from this state into the new package; no
automatic import or T0 reinterpretation is implied.

