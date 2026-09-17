# AD-34 G3 binding / feedback independent review R5

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g3_control_arch_independent_review`)  
Repair reviewed: `docs/implementation/AD-34/g3_binding_feedback_audit/repair_r4/`  
Parent review: `docs/implementation/AD-34/g3_binding_feedback_independent_review_r4/`  
Decision: `pass_limited`  
Scope: read-only architecture and work-order boundary review; no implementation acceptance

## Evidence and cleanup boundary

I read the R4 repair proposal and manifest, current G3 source-feedback and T0
transport source, the current control source/test/archive and R9 receipt, and
the AD-31/AD-32 records. No reviewed file was modified. No Julia or DESC
command was run.

This review produced no temporary or scratch file. The cleanup inventory is
empty; no existing dirty file, historical receipt, or unrelated artifact was
touched.

## R4 closure review

The required upstream pairing is now executable at the contract level. The
proposal requires exactly `{G1,G2}`, exactly one upstream authority per
required layer, explicit rejection of duplicate/missing/unknown layers and
candidate mismatch, then pairs every target by `target_layer` to that unique
record. It permits multiple targets on one layer while requiring a canonical
target key from the current target fields and a separate unique `target_id`.
Duplicate target keys and IDs have deterministic errors. Six-field canonical
equality checks only legacy projection consistency; it never promotes a target,
declaration, slot, or authority.

The legacy status mapping remains safe and complete: `:actual`, `:missing`,
and `:historical_absent` become typed absence with `terminal_deferred`, while
`:stale`, `:contradictory`, and unknown values fail closed. No declaration
identity, canonical bytes, or receipt is synthesized from the legacy six
fields.

The future T0 authority gate is now a named separate work order,
`UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`, with exactly seven owned files:

1. `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1.jl`
2. `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_tests.jl`
3. `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_fixture.json`
4. `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_v1.py`
5. `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md`
6. `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/manifest.json`
7. `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md`

There is no launcher. It consumes T0 output plus a fresh T0-owned authority
record or typed absence, runs after T0 and before T1, and returns checked
present, typed absent with reason/digest, or deterministic fail-closed. It
cannot synthesize missing fields from legacy authority, target equality,
fixtures, binding payloads, or manifests. T1 depends on both T0 output and the
recheck result, so the future graph remains acyclic.

Before the recheck returns checked present, AD-34 permits only a typed-absent
binding scaffold. All link CAS operations are disabled; the old source/body/
history/receipt/hash bytes remain unchanged on rejection. The six-file binding
scope contains no T0 adapter or feedback child.

B01 remains closed with immutable source-owned `initial_links`, exact editable
body initialization, frozen source/child/initial hash layers and typed
operation history. B03 keeps metadata rebuild and runtime evidence ownership
separate. B04 keeps present/absent child unions without placeholder authority.
B05 remains point-in-time consistent: the repair's source/test/manifest/report/
R9 receipt/exit hashes match the current read-only checkout, while the control
archive remains `review_pending`, `actual_control=false`, and
`source_backed_t1_mapping=false`.

The AD-34 DAG and credits have not drifted. Binding remains parallel to AD-31,
AD-32 and the T0 path; T0 recheck precedes T1, and T1 precedes T2. Binding
machine-node creation, implementation acceptance, actual binding/feedback
authority, T0/T1/T2, provider, mesh, engineering, physical, search, B00, B04
and R01–R10 credits remain false.

## Ruling

`pass_limited` is granted for the architecture and work-order boundary only.
Sol may accept this boundary and separately schedule the named T0 authority
recheck work order. This review does not create or accept the binding machine
node, does not enable binding implementation or CAS, and does not grant any
actual authority or physical/engineering credit.
