# N06 R8 unit and source-gap independent audit R1

- Verdict: audit_complete_with_deferred_mapping
- Author role: independent Luna/high; different from E2 author.
- Scope: read-only unit/source audit. No Julia/DESC was run and no source, test, core document, old evidence, or status file was edited.
- Evidence ceiling: no N06 acceptance, formal B04, provider, mesh, engineering, physical, or R01-R10 credit.

## Determination

The actual A package cannot produce a complete valid four-role N06 mapping with source proof. The G1 fixture gives every selected occurrence dimensionless exponents [0,0,0,0,0,0,0]. The G3 fixture gives effort/flow/load/return/heat resources and entries with V/A/W-like dimension vectors. The current source has no candidate-bound dimensioned G1-to-G3 conversion law or source provenance. The fixture phrase authored mapping, its QualifiedRef law URI, and its provenance string are declarations supplied by the test; they are not evidence that an actual A law exists.

The focused R8 process really exited 1. Its underlying exception was ArgumentError: N06 mapping is structurally inconsistent: conversion_same_dimension_mismatch from N06SourceFieldLedgerMappingV1.jl line 593 while the test attempted to construct its positive authored mapping at test line 196. The source check is correct: a supplied typed mapping that claims same-dimension conversion while the actual exponents differ must fail closed. The test currently treats that non-authoritative authored sample as a positive mapping and lets the expected structural rejection escape the test, so the process-level classification is program_exception. That process exception must not be confused with a physical result or with proof that the mapping is valid.

## Role-by-role unit audit

| Role | Actual G1 selector and unit | Selected actual G3 port -> entry and units | Test declaration | Existing typed conclusion |
|---|---|---|---|---|
| source | energy / governing-0 / output / 1; dimensionless [0,0,0,0,0,0,0] | source_flow flow [0,0,0,1,0,0,0] -> source-entry power [1,2,-3,0,0,0,0]; partner source_effort effort [1,2,-3,-1,0,0,0] | power_from_effort_flow, scale 1, offset 0, law URI generated from role, provenance authored N06 source audit | The local G3 effort+flow dimension sum can prove that the selected G3 output is power. It does not prove that the dimensionless G1 occurrence is the effort/flow source, nor provide a physical conversion/source law. Keep cross-layer authority deferred. |
| field | energy / source-0 / output / 1; dimensionless [0,0,0,0,0,0,0] | load port load power [1,2,-3,0,0,0,0] -> load-entry power [1,2,-3,0,0,0,0] | same_dimension, scale 1, offset 0 | from_unit and to_unit differ, so conversion_same_dimension_mismatch is the correct fail-closed result. |
| return | constraint / constraint-0 / output / 1; dimensionless [0,0,0,0,0,0,0] | return port flow [0,0,0,1,0,0,0] -> return-entry power [1,2,-3,0,0,0,0] | same_dimension, scale 1, offset 0 | from_unit and to_unit differ; same_dimension is a real typed contradiction. No source-to-return law exists in actual A. |
| heat | constraint / constraint-0 / output / 2; dimensionless [0,0,0,0,0,0,0] | heat_sink port power [1,2,-3,0,0,0,0] -> heat-entry power [1,2,-3,0,0,0,0] | same_dimension, scale 1, offset 0 | from_unit and to_unit differ; same_dimension mismatch is correctly fail_closed. No G1-to-heat conversion provenance exists. |

Source locations: G1 units/equations are in test/GenomeV5/G1/fixtures.json lines 19-35; G3 resources/accounts/entries are in test/GenomeV5/G3/fixtures.json lines 42-63. The test builder is test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl lines 81-134 and constructs the conversion at lines 120-124. The authoritative N06 conversion rules are N06SourceFieldLedgerMappingV1.jl lines 39-43; same_dimension is checked at lines 561-563 and power effort-flow dimensions at lines 539-543.

## What the current typed law can and cannot prove

N06DimensionedConversionV1 accepts only same_dimension, time_derivative, or power_from_effort_flow. Its law hash is derived from the static N06 conversion-law source text. This is a contract rule hash, not a source-backed physical law receipt.

The source role's G3-side effort plus flow exponent sum is locally coherent. The other three same_dimension declarations are directly contradicted by actual typed values. No existing law connects the selected G1 occurrence units, equation semantics, G2 boundary, and G3 resource network. The G2 region/boundary and the G3 local closure/account balance are structural locators; they do not supply a dimensioned transformation.

The G3 source_owner shared owner is legal: source_effort and source_power intentionally share source_owner, and the validator compares the declared owner scope against the actual account set. Equal owner text is not a double-count error. The existing authority gap owner_scope_mapping_missing_shared_owner_is_legal is therefore appropriate.

N06 mapping admission without an authored mapping returns terminal_deferred from the projection authority gaps (N06SourceFieldLedgerMappingV1.jl lines 854-860). A supplied mapping is checked for identity and structural join errors first; structural conflicts return fail_closed, while an exact local mapping would still return terminal_deferred for unverified cross-layer semantics (lines 882-890). R8 never reached the mutation group because the attempted positive mapping failed this structural gate.

## R8 and historical execution boundary

Focused R8 receipt:
- command: julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl
- real exit: 1
- UTC start/end: 2026-09-14T05:27:19.355459Z / 2026-09-14T05:28:23.388901Z
- main PID 37060; observed child PIDs 17324, 75116, 77624
- stdout 2770 bytes, SHA 2c1af4ecbdc49fa85eaae9c0be449badd75dd4d5e0890ee231b3e88390c80b98
- stderr 335 bytes, SHA 8ac494a454f7fbc73af737756244bf9d08ad2aebc8e3808d99f982006b52c920
- exit artifact bytes 3, SHA f1b2f662800122bed0ff255693df89c4487fbdcf453d3524a42d4ec20c3d9c04
- postflight Julia/DESC sweep empty; input hashes and protected before/after matched; no retry in R8.

Preserved earlier author history is classified as follows: R1 unsupported first-generator default; R2 owner-scope duplicate plus nonzero derived-conversion offset; R3 missing N06 invocation-counter semantic view; R4 selector Dict dot access; R5 String conversion of typed occurrence tuple; R6 typed NamedTuple versus anonymous tuple mismatch; R7 discarded G3 link dereference. These are historical program exceptions and are not reinterpreted as scientific failures or successful contract evidence.

## Mutation and formal-gate scope

N06-01 through N06-05 target actual G3 fields: resource-port id, entry account id, control-resource link port id, closure expected balance, and resource-port kind. Their local structural mutations can be candidate-bound contract controls once a fresh run reaches them: invalid_ref for the first three, invalid_closure for balance, and invalid_kind for kind. R8 did not execute that group, so no mutation pass claim is available.

The formal obligation remains five N06 rows plus five N05 rows within the total 50 B04 mutations. Current local fields and negative controls cannot satisfy the formal fresh receipt/checker/two-process gate. Physical source-field-return/heat/ledger closure remains terminal_deferred.

## Minimal non-masking test adjustment

Do not replace G1 units with G3 units, weaken same_dimension, or relabel the authored URI/string as source proof. In the positive projection test, call the join error calculation before n06_mapping_from_a. If the actual-A authored sample produces conversion_same_dimension_mismatch, assert that structural fail-closed result and keep the no-mapping admission terminal_deferred; do not call the constructor as though it were a valid mapping. A future positive mapping requires a separately typed, content-hashed, candidate-bound conversion/source law with exact G1 occurrence provenance and unit transformation. Only after that source exists should a valid four-role join be attempted and its five mutation receipts rerun.

This audit is complete with deferred mapping. It does not promote the N06 implementation or R8 run.
