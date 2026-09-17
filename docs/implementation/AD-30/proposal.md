# AD-30 VNEXT semantic declaration transport and package boundary

- **status:** `proposal`
- **resolution:** `review_pending`
- **accepted:** `false`
- **independent review:** pending different-Luna architecture review
- **Sol decision:** pending
- **date:** 2026-09-15

## Scope and ruling

The read-only source audit found that the new G1/G2/G3 V1 declarations cannot be losslessly constructed as the existing concrete `MechanismGenomeV5`, `FieldGeometryGenomeV5`, and `RealizationControlGenomeV5`. G1 would lose candidate-owned `K(x)`, source fields, operator version/sign and declaration provenance; G2 would lose chart Jacobian/metric, exact quadrature and per-face values; G3 would lose source-law, entry closure, and feedback authority metadata. The existing integration and `CandidateStatePackageV5` boundaries require the old concrete types and reject a declaration-only adapter.

AD-30 therefore forbids ref-only adapters and fixture authority. Existing V5 concrete types, `CandidateStatePackageV5`, historical receipts, hashes and candidate identities remain read-only with their existing semantics.

The current `G3SourceFeedbackLawV1` does not contain realization, control or binding child refs. T0 must represent those children as typed absent with `terminal_deferred`; it must not claim that G3 V1 retained or built them. T1 may carry realization/control/binding child identity only after fresh same-candidate source, refs and hashes exist and are independently reviewed.

## Versioned VNEXT plan

T0 is an additive same-fresh-candidate exact typed declaration transport. Each declaration must carry the same `QualifiedRefV1` `version=v5` `candidate_ref`, with exact equality across G1/G2/G3. It preserves each declaration's source ref/payload/content and its source/content hash and declaration hash, then computes a canonical bundle hash over the complete semantic bodies, candidate ref, source/declaration identity, four axes and child/feedback states. Source rebinding or any declaration edit recomputes every affected hash and candidate identity. The four axes are explicit and independently compared as `payload_schema_version`, `canonicalization_profile_version`, `applicability_profile_version` and `evidence_receipt_version`; missing axis or authority is typed absent/`terminal_deferred`, while conflicts are `fail_closed`.

G3 feedback preserves target layer/path, quantity, unit, direction, sign, source ID and authority ref/hash/status/attestation. A same-candidate target-ref mismatch is `fail_closed`; bare `actual` without a trusted receipt is `fail_closed:unattested_authority`. G3 realization/control/binding children remain typed absent/`terminal_deferred` until real same-candidate child source and identity are available. T0 cannot enter the old package and does not modify `default_operator_registry()`.

T1 introduces versioned `CandidateStatePackageV5Next` and a matching integrator as the additive strongly typed successor required by AD-19. The package carries the complete three-layer declarations, source/declaration identity, candidate ref, exact four axes, component hashes, G3 child/feedback actual-or-absent state and its own schema/canonicalization/profile hashes. Its package hash covers those complete inputs, not a ref-only projection. It cannot reuse old package hashes, migration receipts or candidate identities. `CandidateStatePackageV5`, its shared entry, `default_operator_registry()`, old hashes and old receipts remain read-only. A fresh package with no legacy input uses a new pending/typed-deferred no-legacy receipt and never fabricates a migration mapping; legacy input requires complete before/after refs, hashes, axes, mapping, identity rebuild, algorithm revision and provenance.

T2 rebuilds E0/G-I1A/E1/E2/UP2 identities on the T1 package. Every new identity and receipt binds the same fresh candidate, canonical source/bundle identity, declaration/component hashes, four axes, G3 child/feedback state and authority provenance; absent authority or children remains independently `terminal_deferred`. Only after that identity chain is independently reviewed may formal B00 F0–F5, 50 fresh B04 receipts, checker and two-process replay be frozen and executed.

## Evidence and source boundary

The source evidence is the current checkout at `HEAD=4b69f55f7f80240147a65a22809dc1207824dde2`, with a pre-existing dirty worktree. Relevant lines are recorded in `evidence_manifest.json`. The focused V1 software tests are not treated as provider, mesh, engineering, physical, or R01–R10 evidence.

AD-30 keeps the current UP0–UP6 DAG, R01–R10, historical evidence boundary and current iteration. T0/T1/T2 remain contract-only architecture work; all execution and promotion states remain `review_pending`/`accepted=false` until their own independent gates pass.

## Review state

This is a proposal for different-Luna independent architecture review. It does not authorize source edits, old package changes, provider/mesh/physical execution, or search expansion.
