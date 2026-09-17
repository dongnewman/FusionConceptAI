# G-I1 entry audit R1 — unified typed precompiler authority context

## Verdict and scope

Verdict: `audit_complete_with_deferred_mapping`; dispatchable scope: a bounded **design/preparation** task for an additive G-I1 authority-context envelope. This is a read-only architecture audit. No G-I1 implementation, Julia/DESC execution, B00/B04 receipt, provider, mesh, engineering, physical, or R01–R10 credit is granted.

The audit is based on the frozen current files listed in `input_hashes.json`, including AD-26 accepted_limited, G-I0 focused_r3, E0, UP2-00, and the current N03–N10 source slices. The worktree has extensive unrelated dirty files; they were protected and not modified. The only new files from this audit are in this directory.

AD-26 is accepted only for an additive authority-context hash and the separate `contract_admission`/`physical_resolution` protocol. G-I0 focused_r3 is still `review_pending`/`accepted=false`: 26/26 wiring assertions and the failure-probe child process are runtime evidence for the module seam only. It does not establish G-I1 or UP2 acceptance.

## Source-backed A package inventory

The actual source-backed root is `CandidateStatePackageV5` from `src/Contracts/CandidateStatePackageV5.jl`. Its usable identity inputs are the candidate `QualifiedRefV1`, G1/G2/G3 package values, the G2 candidate binding, four version axes, migration receipt, component identity, package structural/resolution state and candidate hash. `src/GenomeV5/Integration/GenomeV5Integration.jl` verifies the G2 candidate binding against the package candidate and G2 hash, exact component identity and fresh receipt identity. A future G-I1 factory must consume this actual package and the source-validated E0 binding; low-level synthetic UP2 constructors are not admissible authority.

E0 adds a source-bound envelope without changing the original package hash: the full three outer public refs, three component hashes, four axes, schema/canonical/profile hashes, `binding_hash`, `bound_input_hash`, original `package_hash`, and exactly two missing-authority gaps for N05/N06. E0's gaps are `N05_terminal_deferred:no_authoritative_typed_flux_binding` and `N06_terminal_deferred:no_authoritative_typed_source_field_return_heat_ledger_binding`. These are missing authority markers, not physical results.

The current local projections expose the following actual fields and limits:

| slice | actual typed source consumed | current authority ceiling |
|---|---|---|
| N01/N02 | UP2 actual-A precompiler projection of typed rank/unit fields, with source-derived mutation hashes and zero compile/provider/solver calls | local schema/value slice only; UP2 total remains open |
| N03 | G1 equation temporal kind/derivative/operator temporal kinds and G3 controller event trigger/time, each with candidate/ref/component/schema/canonical provenance | G1 local checks are source-backed; cross-layer time-basis policy is absent and remains `terminal_deferred` |
| N04 | G3 account owner, closure account IDs, entry account/component/coefficient plus the actual G1 occurrence tuple and G1/G3 refs | local G3 account/closure/capacity checks only; no authoritative G1 occurrence → G3 account/energy-boundary join. Shared owner is legal when scopes are distinct |
| N05 | actual A G1 occurrence and G2 interface context can be selected, but A supplies no authoritative flux/traction/current endpoints, signs, or dimensioned flux-unit provenance | absent authored endpoint/law/unit authority is `terminal_deferred`; an explicit typed contradiction is `fail_closed`; E1 local contract rows are not formal B04 |
| N06 | actual A G1 four-field occurrence selectors, G2 left-region/x_min selector, G3 flow link/network fields, E0 bound hash and typed role/join containers | no dimensioned G1→G3 source/field/return/heat/ledger law or owner-scope exact join. Dimensionless G1 values and G3 W/V/A/power strings cannot be joined by name; missing law/provenance is `terminal_deferred` |
| N07/N08 | actual G2 regions, required faces, exterior patch face/region/upper, mesh plan cell tuple and interface refs; structural admission is reused | current G2-limited structural relation only; no geometry proof, mesh evidence, provider or physical credit |
| N09 | five registered `provider_match` fields: G1 operator, G2 grammar, G2 exterior, G3 realization, G3 control, with layer ref/hash/source locator | missing/no-match/ambiguous/signature are provider capability gaps (`terminal_deferred`); no provider is invoked or resolved |
| N10 | actual G1 schema hash, G2 canonicalization hash, typed G3 binding child ref, package candidate hash and fresh `migration_receipt.candidate_identity_after`; component identity and axes are rechecked | structural foreign/stale ref/hash/identity is `invalid_type` + `fail_closed`; absent V4 legacy provenance remains a separate `terminal_deferred` gap and cannot be called stale-legacy proof |

The frozen UP2-00 manifest records N01/N02 as the only actual-A slice in the original unified precompiler attempt, with 40/50 mutation slots still pending. Later local N03/N04/N07/N08/N09/N10 slices remain separate contract-only evidence and do not close the UP2 total or formal B04 obligations.

## G-I1 authority-context input contract

The proposed additive context payload must use a fixed ordered canonical representation (UTF-8/LF, explicit field names, no omitted/defaulted fields):

1. `context_version`, `context_schema_hash`, `context_canonicalization_hash`, and `context_compatibility_profile_hash`.
2. Actual A candidate identity: the `QualifiedRefV1` candidate ref, original `CandidateStatePackageV5.candidate_hash`, package structural/resolution state, actual G1/G2/G3 component hashes, and all four version axes.
3. The complete same-candidate E0 envelope: each outer public `GenomeContractRef` with all five fields (`uri`, `version`, `schema_hash`, `canonicalization_hash`, `compatibility_profile`), E0 schema/canonical/profile hashes, `binding_hash`, `bound_input_hash`, original package hash, and exact E0 gap tuple. A G3 child `QualifiedRefV1`/binding locator is carried as child provenance; it never substitutes for the G3 outer five-field public ref.
4. Two explicit extension slots in fixed order: E1 N05 and E2 N06. Each slot is either a typed `present` extension or a typed `absent` marker. A present extension carries its own content hash, candidate/package/E0 identity, source/ref and component provenance, four axes, `schema_hash`, `canonicalization_hash`, `compatibility_profile_hash`, and its declaration/mapping status. An absent marker carries `present=false`, a typed absent reason/status, its own marker content hash, the same three version metadata hashes, and the same-candidate A/E0 context. Absence cannot be encoded as null, empty hash, old hash, or a default profile.
5. The context hash is the canonical hash of all fields above, including extension slot name, presence, content hash and per-extension version metadata. Changing any ref, package/binding hash, component hash, axis, extension content, absent marker, schema, canonicalization or profile must create a new context identity. The original A package hash and E0 v1 `binding_hash`/`bound_input_hash` are never rewritten.

The minimal API should be a typed factory such as `gi1_authority_context_from_a(package, e0_binding; n05=<typed present|absent>, n06=<typed present|absent>)` plus a validator that rebuilds the context hash and performs exact source joins. It must reject synthetic low-level values, foreign E0 bindings, stale component hashes, incorrect outer refs, wrong child refs, wrong axes and extension swaps. It may report missing N05/N06 authority as `terminal_deferred`; it must report an actual typed mismatch as `fail_closed`; an unexpected checker/loader error is `program_exception`. No `Any`/string-only declaration may confer authority.

Required negative controls are: mutate each of the five outer-ref fields; use a foreign candidate/package or stale E0 binding/bound hash; replace one component hash or one axis; swap E1 and E2 slots; change an extension content hash while retaining the label; change any extension schema/canonical/profile hash; flip present↔absent; alter the typed absent reason; omit or duplicate a slot; use a G3 child ref where the G3 outer ref is required; and reuse a G2 plan with a different candidate package. A self-consistent forged payload must still fail source-bound validation. The validator must recompute all hashes from actual A/E0/extension values and keep downstream counters at zero.

## Status axes and unresolved physics

`contract_admission` is a contract-only status with the allowed values `declared_consistent`, `fail_closed`, `terminal_deferred`, and `program_exception`. It answers whether sourced typed declarations, same-candidate refs, exact local joins and declared invariants are internally admissible.

`physical_resolution` is independent and remains `unknown` or `terminal_deferred` in this design. It can change only after applicable provider, mesh, solver, independent physical and engineering evidence. A declaration, projection hash, structural test, runner exit, local mutation receipt or G-I0 module assertion cannot promote it.

The present N06 source has a typed `power_from_effort_flow` rule shape, but actual A still lacks the dimensioned conversion/source law needed to join dimensionless G1 occurrences to G3 W/V/A/power roles. G3 local balance, an `energy` string, `eq.input_units`, interface normal, or authored prose is not that law. G-I1 must emit an absent/authority-gap N06 context unless a future E2 declaration supplies the exact typed conversion law, source/field/return/heat/ledger refs, owner scope and provenance. E1 local success likewise remains contract admission evidence only, not a formal B04 receipt or physical flux proof.

## Minimal bounded implementation order

A future bounded G-I1 work order should own only these new files, leaving G-I0, E0, E1, E2, old UP2 rows, core documents and V4 untouched:

- `src/GenomeV5/UP2/GI1AuthorityContextV1.jl` — typed context, present/absent extension envelopes, canonical payload/hash, source-bound factory and validator.
- `test/GenomeV5/UP2/gi1_authority_context_fixtures.json` — actual-A baseline plus typed absent E1/E2 markers and forged-ref/hash/axis/slot cases; no expected label routing.
- `test/GenomeV5/UP2/gi1_authority_context_tests.jl` — source-backed positive, all negative controls, taxonomy and zero-call assertions.
- `test/GenomeV5/UP2/run_gi1_authority_context.jl` — one isolated include path; no compiler/provider/solver/mesh/physical call.
- `docs/implementation/UP2-00G-I1-AUTHORITY-CONTEXT/` — immutable source/test/fixture/runner hashes, one serial receipt, independent review and acceptance record.

Inputs must be frozen before the first execution: actual A package, accepted-limited E0 source/binding, current E1/E2 source hashes and typed absent/present markers, schema/canonical/profile strings and candidate identity. The focused exit gate is: source-backed A/E0 factory; exact five-field outer refs and axes; both extension branches carry independent version hashes and content hash; context hash and bound identity change under every listed mutation; fail-closed vs deferred vs program_exception are separately observed; compile/provider/solver/mesh counters are zero; raw stdout/stderr/exit and hashes are retained; a different Luna independently checks the receipt. This is still `review_pending`, not formal B04.

## G-I2 / UP1-04B boundary

G-I1 cannot promote local N01–N10 slices or E1/E2 receipts into the formal gate. Before first formal execution, G-I2/UP1-04B must freeze a new candidate-bound B00 F0–F5 and all 50 real B04 mutation rows, with exact field paths, source locators/types, original and attempted typed values, input/mutated hashes, source-derived error code/path/resolution and zero compile/provider/solver counters. A checker must independently rebuild the hashes and compare the actual A/E0/extension sources; fixture `expected_error` is an oracle only. Two independent processes must replay the same frozen inputs, with distinct attempt receipts, identical canonical identities and preserved stdout/stderr/exit/environment. Missing rows, reused local evidence, runner exit alone, or a single-process check leaves UP1-04B and full UP1-04 open. Provider, mesh, engineering, physical and R01–R10 gates remain independent.

## Current read-only QA

No Julia or DESC process was running during the audit; no Julia/DESC command was started. The input inventory and hashes are in `input_hashes.json`. `qa.json` records the protected dirty scope, JSON/control scans, plan validation and `git diff --check` after the archive was written. This audit's only writes are the files under `entry_audit_r1/`.

## References

- `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md`, AD-24/AD-26 and lines 218–226 for the authority-context and dual-status boundary.
- `docs/v4_multitopology_generation/19_up0_02_contract_freeze.md`, lines 61–76 and 118–147 for N01–N10, formal receipts and two-process replay.
- `src/Contracts/CandidateStatePackageV5.jl` and `src/GenomeV5/Integration/GenomeV5Integration.jl` for actual package identity and same-candidate checks.
- `src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl` for E0 source-bound identity and exact N05/N06 gaps.
- `src/GenomeV5/UP2/N03TimeAuthorityProjectionV1.jl` through `N10IdentityReceiptProjectionV1.jl` for the current local projections and their deferred/closed classifications.
- `docs/implementation/UP2-00G-I0-MODULE-SEAM/focused_r3/evidence_manifest.json` for the wiring-only runtime evidence and review ceiling.
