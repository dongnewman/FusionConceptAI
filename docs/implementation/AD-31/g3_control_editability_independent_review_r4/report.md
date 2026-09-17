# AD-31 G3 control-only source-edit proposal R4: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

R4 closes most of the R3 gaps. It carries the complete parent/child/source
identity in the source-payload reference, includes the exact source-record ref
in the operation record and operation hash, parameterizes operation history,
freezes canonical bytes and ZERO rules, and gives physical deferral a typed
reason. The immutable source payload versus editable state split remains
semantically sound, and the fixed operation remains a one-mode edit of an
existing fault with the old control semantics.

Implementation dispatch is still premature because the proposed
source-record-reference equality cannot be implemented as written, and a few
hash/derived-field recipes remain incomplete. In particular, the source record
has `source_uri/source_version` but no `record_uri/record_version`, while the
source-record ref is separately defined as `(record_uri, record_version,
record_hash)` and is said to match source-record fields byte-for-byte. The
operation can therefore carry a ref whose URI/version has no canonical source
record field to compare. The remaining issues are bounded contract repairs.

## R4 checks that pass

The closed control body preserves the old `ControlGenomeV5` fields and local
semantics: typed signal kind/direction/unit/account, controller sensor,
actuator and resource memberships, typed states/events, fault target/mode/
safe-action/detection/deadline, and exact plan sets. It retains declared tuple
order, rejects open bodies and dynamic edits, and excludes old V5 objects,
package, shared entries, registry, T0, realization, binding and feedback
authority.

The provenance slots, typed source record, source-payload ref, present state
and typed-absent state have explicit shapes. The source-payload ref now carries
candidate, parent ref/hash, actual child contract ref/hash, source URI/version,
source-record ref and source-content hash. The state uses a closed typed
operation tuple and typed physical resolution. The sibling schedule bypasses
T0 and realization without introducing a control-to-realization edge.

The immutable/editable split is coherent: a valid edit changes only the
editable body, operation history, operation hash, last-operation hash and
resulting/current-state hash. Source payload/ref, source record/ref, axes,
source-content hash, initial source hash, initial state hash, parent and child
identity remain fixed. The operation/result recipes are acyclic because the
operation hash excludes its result and the resulting hash uses only prior
operation hashes plus the new operation hash. Empty and typed-absent states
have explicit ZERO/history rules, and every failure is required to return the
old state's canonical bytes unchanged.

The proposal keeps the correct evidence boundary: local construction, hash,
test and runner evidence can affect only `contract_admission`; physical status
remains `unknown` or typed `terminal_deferred`. No provider, engineering,
mesh, solver, physical, T0/T1/T2, B00/B04 or R01--R10 credit is granted.

## Required repairs before implementation dispatch

1. Make `source_record_ref` equality well-defined. Either add ordered
   `record_uri` and `record_version` fields to `G3ControlSourceRecordV1`, and
   include them in its record hash and source-content recipe, or explicitly
   define `record_uri/record_version` as exact aliases of existing
   `source_uri/source_version`. The current proposal has no source-record
   fields corresponding to the ref's URI/version, despite requiring a
   byte-for-byte match. The focused implementation must be able to recompute
   and compare the complete `(record_uri, record_version, record_hash)` without
   an unstated external store.

2. Freeze the child-contract identity and parent binding recipes. R4 says the
   additive child contract identity hash is independently computed, but does
   not give the exact canonical field list (for example, the complete
   `GenomeContractRef` body excluding its digest). Likewise, “parent ref must
   hash to the key's parent hash” needs an explicit declaration-ref/content
   binding recipe. These values must be independently recomputable and
   candidate-bound; a URI label, old hash or T0 marker cannot satisfy them.

3. Complete typed-absence hash recipes. The state initial hash includes
   `absence_content_hash`, and each absent provenance slot includes its own
   absence hash, but R4 does not freeze how those absence hashes are computed.
   Define the canonical marker fields, reason and missing-slot order for slot
   absence and state absence. The marker must not be an empty-body hash or a
   copied default, and independent tests must recompute it.

4. Bind or strictly derive `last_operation_hash`. The current/resulting state
   hash recipe uses the new operation hash and prior operation hashes but omits
   the state field `last_operation_hash`. Freeze the invariant
   `last_operation_hash=ZERO_DIGEST` for empty/absent history and
   `last_operation_hash=last operation record.operation_hash` otherwise, and
   either include it in the state hash or validate it as a deterministic
   derived field before accepting a state. A forged last-operation field must
   fail closed.

5. Fully bind the operation input. The operation hash currently binds modes,
   prior hashes, source-record ref and source-payload ref, while the operation
   input also carries `replacement_edit_body`. Because the body is constrained
   to one mode difference, it may be treated as a deterministic derivation
   from the prior editable body, `fault_id` and `resulting_mode`, but that
   derivation must be frozen and tested before hash acceptance. Otherwise add
   the complete replacement body or an independently recomputable edit-body
   digest to the operation record/hash. This prevents two operation inputs with
   the same mode fields from sharing one operation identity.

6. Keep the canonical failure assertion executable. The implementation must
   specify the canonical serializer used for the “old state's canonical bytes”
   comparison and verify it for source-record-ref mismatch, child/parent
   identity mismatch, forged contract hash, forged absence hash, forged
   `last_operation_hash`, malformed replacement body, duplicate/reordered
   history, stale state/source and every non-mode or multi-fault edit. A
   failure must return the prior state object/bytes without changing any
   status, digest, history or marker.

## Scheduling and evidence boundary

After these repairs, the work order may remain a control-only sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`, with only the G3 SourceFeedback V1 declaration and accepted
AD-31 architecture as prerequisites. It must not import or redefine T0,
depend on realization, modify old V5/package/registry data, or add a
sibling-to-sibling DAG edge. T1 remains the sole later owner of the fresh
same-candidate three-child lossless mapping.

This review writes only this report and manifest. No Julia, DESC, provider,
mesh, solver, engineering or physical command was run. Any future focused
receipt establishes only local contract/editability software evidence; it does
not grant actual-child authority, T0/T1/T2 completion, provider, engineering,
mesh, physical, search, B00, B04 or R01--R10 credit.

