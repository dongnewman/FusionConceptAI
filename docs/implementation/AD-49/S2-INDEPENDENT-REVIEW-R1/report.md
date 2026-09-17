# AD-49 S2 G1/G2 factory identity independent review R1

Date: 2026-09-15T15:51:24.307487Z  
Reviewer: `different gpt-5.6-luna/high` (fresh independent static review)  
Verdict: `pass_limited`  
Claim ceiling: `factory_identity_probe_only`

## Decision

Fresh Python 3.13.5 read-only recomputation of the four AD49-S2 products, their layer archives, the AD49 readiness and S1/root acceptance records, AD45's common binding handle, and the live G1/G2/G3 source/API boundary gives **pass_limited**. The four products close as `AbsentG1SourceFactoryIdentityV1`, `AbsentG1SourceFactoryConstructionReceiptV1`, `AbsentG2SourceFactoryIdentityV1`, and `AbsentG2SourceFactoryConstructionReceiptV1`; all are `typed_absent` + `terminal_deferred` with `no_publish=true`. No candidate identity, source/declaration/content/factory hash, construction digest or replay receipt is created.

The live G1 module exposes typed payload/declaration constructors, `g1_diffusion_declaration_v1`, and `g1_diffusion_receipt_v1`; the live G2 module exposes typed source/declaration constructors, `g2mb_source_v1`, `g2mb_declaration_v1`, and `g2mb_receipt_v1`. Neither layer contains a source-authority factory consuming the S1 locator, AD45 common `QualifiedRefV1/v5` handle, its public five-field `GenomeContractRef`, and typed source input together. The parent `SourceLocatorV1`/`FactoryConstructionReceiptV1` scaffold remains unusable without a layer adapter. The G3 factory is present only as a cross-layer negative control; it does not establish G1/G2 identity. G2 has no explicit `GenomeContractRef` to `QualifiedRefV1` mapping API.

## Product and control closure

The product JSON was parsed canonically, all declared S1/AD45/W2R1 input hashes were recomputed, and module bytes/SHA matched the products. Each identity product has false creation flags and null created-hash fields; each construction receipt has `attempted=false`, `replay_status=not_replayable`, `replay_receipt_created=false`, `construction_digest_created=false`, and null digest. Constructor-name recognition, generic-scaffold reuse, G3 cross-layer reuse, fixture/seed/receipt authority and registry alias remain typed `Absent`; signature/path/hash conflict remains `Failed...` + `fail_closed`. G2's registry-alias control also records that no mapping is supplied.

The G1 archive contains the aggregate four-product validation with PID/UTC/exit and protected source/registry hashes. The G2 archive contains its direct static scan with PID/UTC/exit and the same layer manifest/negative-control boundary. The fresh review recomputes the four product hashes and the protected hashes rather than treating archive claims as authority.

## Fresh validation receipts

- Direct static recomputation: `archive/direct_validation.json`, PID `94704`, Python `3.13.5`, exit `0`.
- Plan validator: `archive/plan_validator.*` and `archive/plan_validator_receipt.json`, exit `0`.
- Scoped `git diff --check`: `archive/scoped_diff_check.*`, exit `0`.
- Final scope/protected-file receipt: `archive/final_scope_check.json`; review-owned exact set and zero-cleanup inventory: `archive/cleanup_inventory.json`.

## Boundary and handoff

This `pass_limited` is limited to the AD49-S2 factory identity/construction probe. If accepted by the parent, it may unlock only conditional AD49-F0 factory implementation under the frozen contract, and only after the parent makes that decision. It does not grant source authority, factory implementation, trusted identity/attestation, G2 mapping, candidate/declaration/final identity, T0/T1/T2, provider, mesh, solver, engineering, physical, R01-R10 or L4 credit. Any future F0 implementation must be additive, preserve G1/G2 type domains and public `GenomeContractRef` fields, produce fresh source/content/declaration hashes and replay receipts, and require a fresh S2 after implementation before downstream S3/mapping/W3-B.
