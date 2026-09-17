# UP1 W4 — Local external-input discovery audit

Status: `discovery_only` / `preparation_only`  
Conclusion: `no_new_authoritative_input_found`  
Gate credit: none

## Scope and safety

The audit was limited to the repository at `D:/006-Programing/LMC/FusionConceptAI`, frozen at HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d`. User-home directories, credential stores, network access, external endpoints, credential generation, Julia, DESC, solver, and recomputation were excluded. Candidate inspection used path, byte length, extension, and SHA-256 metadata. No private-key, secret, token, or credential content was read or emitted; no sensitive path was discovered (`sensitive_unopened=[]`).

## Findings

The repository contains local contracts, preparation manifests, historical source-authority records, candidate declarations, local receipts, Julia project/manifest locks, and test fixtures. The inventory records 25 candidates. Every candidate is classified as `usable=false`; the count of usable production external inputs is zero.

The strongest-looking artifacts are still not authoritative inputs:

- AD-43 axis and evidence contracts are schemas, not signed witness material.
- AD-42 public envelopes and AD-40 candidate declarations are repository-authored/local-process records and do not supply an external issuer, trust root, signature, freshness, revocation, anti-replay, or candidate closure.
- AD-47 G3 records/receipts are historical local source-authority records without independently verifiable external trust or current bidirectional candidate/evidence closure.
- AD-48 is an attestation preparation manifest documenting the missing trust inputs, not an attestation.
- `Project.toml`/`Manifest.toml` and Gridap locks provide local dependency reproducibility metadata only; they are not signed binary provenance, SBOM, publisher, download-origin, or build-recipe evidence.
- Benchmark registries are explicitly test fixtures and cannot be promoted to authority.
- W1/W3 artifacts are typed-absence contracts and validator packages. They describe the required future inputs but do not themselves supply witness identity, live channel receipts, authoritative G2 mapping, signed four-axis material, or environment/binary closure.

Self-signed, fixture, schema-only, local-only, and historical artifacts were not promoted. No source↔candidate↔evidence inverse closure was inferred from filenames or local declarations.

## Absence and recovery

`absence_delta.json` records the unchanged W1/W2/W3 typed absences, their responsible owner, authoritative source, and recovery condition. In particular, independent witness identity/COI, trust root and certificate chain, signed attestation/freshness/revocation/replay evidence, authority endpoint/ack, G2 mapping, four-axis signed binding, candidate/source/evidence closure, environment/import closure, binary provenance/SBOM, and raw attestation linkage all remain typed absent. Because no real input changed, the upstream registers were not edited and no new AD was created.

## Validation boundary

The static validator checks repository scope, candidate hash shape, absence of `usable=true`, exact output set, and no sensitive candidate flag. It is a preparation validator only. Passing it cannot grant T0/B00/B04, UP1/R/L4, G1/G2/G3, physics, provider, evidence, or parent-goal credit.
