# W3 source/G2/environment independent review

## Decision

`rework_required`. The preparation bundle is internally readable and its standard-library validator exits 0, but the validator admits a materially incomplete “present” G2 fixture and does not establish the required source/candidate/evidence or external-provenance bindings. The claim ceiling is `preparation_only/screen_only`; this review grants no UP1, B00, B04, R, L4, or parent-goal credit.

## Scope and immutable boundary

Reviewed `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/source_g2_environment/**` plus the declared v4 control documents and AD-55/AD-56/AD-29 references. No input, source, test, registry, shared document, AD, key, certificate, executable, or fixture was changed. Only this review directory is written. The source bundle declares 17 files and the observed set is exactly those 17.

## Checks performed

- Parsed every source JSON with a duplicate-key rejecting object hook; all parsed uniquely. SHA-256 values are recorded in `manifest.json`.
- Re-ran `python static_validator.py`: `bundle=pass`, `negative_controls=pass`, `status=pass`, `typed_absence=pass`, exit `0`.
- Recomputed frozen identity: HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d`; tree `e28da2ff057201c2257f6b879d3860b7a49cb428`. Current status SHA is `8ad8e9f6a3e3c98cbc4ad0fba5c332cd0ab70a0d01a687a10d85bea232c70fc7`, and current binary `git diff --binary --no-ext-diff` SHA is `3665717b31dbd8224f29185a86446997c9c500ef406df0e4288fd57a4e60ecc1`; both differ from the source snapshot’s recorded `d05d1f...` and `fb9098...`. This is worktree drift, not a source mutation by this review.
- Confirmed the package keeps G2 namespace/version/interval/issuer/signature/certificate/revocation/source/candidate/evidence absent and declares fail-closed rules. AD-55 remains historical reference-only and AD-56 remains an execution-input record; neither is promoted to authority or candidate evidence.
- Confirmed observed runtimes are local observations only. All three named executables currently exist, but no publisher signature, origin, build recipe, SBOM, license, or candidate-bound import closure is attested.

## Adversarial findings

1. **P1 — placeholder-as-present bypass.** `static_validator.py:42-47` defines completeness as only namespace/version/issuer, signature value, anti-replay `true`, ambiguity `none`, and conflict `none`. It does not require signature algorithm/key/certificate chain, effective interval/trusted time, issuer policy/EKU/key usage/name constraints, revocation source/freshness, source/candidate/evidence edges, owner, or hash binding. A fixture with those omitted can therefore be accepted as present. The valid fixture is not an authoritative proof.
2. **P1 — typed absence accountability is not enforced.** Axis records use `owner:null` and `authoritative_source:null`, while the validator only checks that the keys exist. `external_input_register.json` has accountable records, but the per-record closure is not linked or checked. Recovery cannot be assigned deterministically for each absent axis/material.
3. **P1 — no canonical no-repeat fingerprint.** The “unchanged inputs do not create AD/rerun” policy is prose. There is no complete, deterministic fingerprint over the input set plus relevant HEAD/tree/status/patch and external-input register, so a future run cannot prove that an AD was not regenerated for unchanged inputs.
4. **P1 — bidirectional edge/hash agreement is unverified.** Source-only materials have `candidate_ref:null` and an `evidence_ref`, but no inverse candidate/evidence edge or byte-level receipt is present. The validator checks only `candidate_ref is None`, hash shape, and nonempty media type; it never dereferences the evidence URI, recomputes content SHA, validates schema/owner, or compares both directions.
5. **P2 — frozen source binding drift and incomplete receipt.** The source report/axis file records a historical dirty status/patch pair; the manifest omits `dirty_status_sha256`, and the validator accepts malformed/ambiguous source hash fields because of the `and/or` precedence at line 19. It also does not recompute git HEAD/tree/status/patch. A retry must freeze a new exact snapshot or explicitly bind the old snapshot without claiming current-tree identity.
6. **P2 — environment closure is not candidate complete.** Imports, module paths, artifacts, build/channel metadata, and exact environment-variable values are absent/redacted. Locale/timezone are observations without a signed provenance binding. Project/Manifest hashes are `present_unbound`; no dependency closure can be reproduced for a candidate.
7. **P2 — binary provenance is self-reported only.** The validator checks SHA-256 formatting but not path existence, executable bytes, version identity, publisher signature, origin, build recipe, SBOM, or license. This review observed the three paths exist and their current hashes match the recorded Julia/Python/Git observations, but that is still an unsigned local observation and no candidate binding.
8. **P2 — G2 safety schema is under-validated.** The absent mapping correctly fails closed, but no checker enforces namespace/version/interval/issuer/signature/certificate/revocation field types, trusted-time comparison, ambiguity/conflict decision structure, or policy OID/EKU/key-usage constraints before a future mapping can be called present. Duplicate JSON keys and unknown fields are also not rejected by the fixture loader.
9. **P3 — receipt linkage is partial.** Recorded raw stdout/stderr hashes and PIDs support the static run, but there is no combined receipt hash or hash map linking every validator input and output artifact to the run. This limits tamper-evident replay of the review chain.

## Required rework before any promotion

Require a new candidate-bound signed G2 mapping and trust chain with policy/EKU/key-usage/name-constraint, validity/trusted-time, CRL/OCSP freshness and anti-replay checks; explicit owner/authoritative-source/recovery for every absence; canonical no-repeat fingerprint; mechanically verified two-way source/candidate/evidence edges and content hashes; exact current git identity and dirty patch/status receipts; complete import/artifact/environment closure; and independently verified binary provenance. Re-run the validator and an independent Luna review only after those inputs change. No formal gate is opened by this review.
