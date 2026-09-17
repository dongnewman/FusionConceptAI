# AD-30 repair R2 contract addendum

Status: `proposal`; `resolution=review_pending`; `accepted=false`; different-Luna R2 review required.

This repair addresses the R1 architecture review while preserving the existing no-loss conclusion and all read-only boundaries. Only the AD-30 section in `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` and `docs/implementation/AD-30/proposal.md` were edited. README, 16, task_manifest, source, old package, old receipts and prior evidence were not edited.

The T0 contract now requires a fresh same-candidate `QualifiedRefV1` with `version=v5` and exact candidate_ref equality across G1/G2/G3. Each declaration's available source ref/payload/content, source/content hash and declaration hash must round-trip; source rebinding or edits rebuild affected source/declaration/bundle hashes and candidate identity. The canonical bundle hash covers complete semantic declaration bodies, source/declaration identity, candidate ref, four axes and child/feedback states.

The four axes are explicit and independently compared as `payload_schema_version`, `canonicalization_profile_version`, `applicability_profile_version` and `evidence_receipt_version`. Missing authority/source/axis is typed absent/`terminal_deferred`; conflicting values are `fail_closed`. G3 feedback retains target layer/path, quantity, unit, direction, sign, source ID and authority ref/hash/status/attestation. Same-candidate target-ref mismatch is `fail_closed`; bare `actual` without trusted attestation is `fail_closed:unattested_authority`.

The current G3 V1 SourceFeedbackLaw has no realization/control/binding child refs. R2 explicitly marks those children typed absent/`terminal_deferred`; no V1 declaration, fixture or synthetic ref is treated as a child. T1 may populate them only after real same-candidate child source/identity/ref/hash exists and is independently reviewed.

T1 is explicitly the AD-19 additive successor `CandidateStatePackageV5Next`. Its package hash covers candidate ref, three complete declarations, source/declaration identity, four axes, child/feedback actual-or-absent state and its own schema/canonicalization/profile hashes. The old `CandidateStatePackageV5`, shared entry, default registry, old hashes, receipts and candidate identities remain read-only. Fresh no-legacy packages use a new pending/deferred migration receipt; legacy mappings require complete before/after provenance. T2 identity receipts must bind the same candidate, source/bundle identity, hashes, axes, child/feedback state and authority provenance before formal B00/B04.

## Hashes

Before values are the AD-30 R1 reviewed values:

- core AD-30 section file: `ade6f012a07a881996078c44ba1cd4c8dfeba8480c1cd1e5dcce407339aa7244` / 53,269 bytes
- AD-30 proposal: `b738865f2d5cb4fe4ba32cba0ddc59156a3685521c19c6149fd2b029a502db1c` / 2,920 bytes

After values are recorded in `evidence_manifest.json`:

- core AD-30 section file: `d913df0b895764d5d31e5c5d81acf06aeb5acef5d01e6c9f941b14f93416ccd6` / 56,742 bytes
- AD-30 proposal: `b5d7f1d8fd1f781e26994e0b6253065ce560050a314663afb778b0949165b7c8` / 5,030 bytes

## Validation and boundary

`python -m json.tool docs/implementation/AD-30/evidence_manifest.json` exited `0`. `python docs/v4_multitopology_generation/validate_plan.py` exited `0`: 31 markdown files, 363 relative links, 31 tasks and an acyclic DAG. The post-edit dirty snapshot is preserved in `dirty_after.txt`; its normalized UTF-8/LF SHA-256 and entry count are recorded in the manifest. A pre-edit dirty status hash was not captured in this repair and is recorded as unavailable rather than inferred.

No Julia/DESC/provider/mesh/physical execution was run. `review_pending=true` and `accepted=false`; R01–R10, B00/B04, engineering, provider, mesh and physical credit remain false. A different Luna must independently review R2 before any implementation or execution proceeds.
