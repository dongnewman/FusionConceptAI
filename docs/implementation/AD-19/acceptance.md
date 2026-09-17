# AD-19 acceptance record

- task: `AD-19`
- status: `accepted`
- accepted: `true`
- accepted_scope: `v4_to_v5_migration_package_join_architecture_boundary_and_r1_r2_provenance_only`
- base HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
- owner: `gpt-5.6-luna/high` (architecture documentation)
- independent reviewer: different Luna, pass
- Sol decision: accepted only for the V4→V5 migration/package-join architecture boundary and r1/r2 before/after/patch provenance; no UP1-04 implementation, provider, B00/B04, engineering, physical, or R01–R10 credit.

AD-19 records the current migration decision: complete V4→V5 lossless mapping is `none`; G1 is conditionally migratable only with declaration-driven, field-complete evidence; G2/G3 missing semantics remain `terminal_deferred`; structural and binding errors are `fail_closed`. The selected design is an additive strongly typed `CandidateStatePackageV5`, an explicit staged migration adapter, and a same-candidate exact three-layer join. V4 package/compiler/campaign call boundaries remain unchanged.

The decision requires actual G1/G2/G3 public refs, four version axes, component hashes, G2 candidate binding plus real genome hash, G3 child refs and feedback authority, and rebuilt candidate identity. Fresh V5 packages do not fabricate legacy receipts. Legacy receipts must preserve complete before/after refs and hashes, axes, field mappings, identity rebuild, algorithm revision, and provenance. B00/B04/provider/engineering/physical/R01–R10 credit is excluded.

## Provenance

The three core documents were copied byte-for-byte before editing under [`before/`](before/). Current files were copied under [`after/`](after/); [`bounded_diff.patch`](bounded_diff.patch) contains only the three AD-19 additions. Before and after metadata, exact SHA256 values, byte counts, and seven-digit mtime values are recorded in [`before_metadata.json`](before_metadata.json) and [`after_metadata.json`](after_metadata.json).

Validation commands and exits are recorded in [`evidence_manifest.json`](evidence_manifest.json). The independent review is pending; this archive records architecture semantics and provenance only, not implementation or physical evidence.

## Review history and current revision

The first independent review (`review_failure_r1.md`) was `changes_requested` because the AD-18 integrated table called the public ref a four-field value. The correction is limited to that table cell: it now names all five public `GenomeContractRef` fields, exactly as required by the contract. The initial AD-19 three-file snapshots and `bounded_diff.patch` remain preserved. The r2 revision has its own before/after snapshot and [`bounded_diff_r2.patch`](bounded_diff_r2.patch); its current 18-document SHA256 is `9fe140fc9a829c1bb29a863dd66f7bb1080c0c8ae1a169b16a4acd8c83aaa518`, bytes `17888`, mtime `2026-09-14T05:38:59.7007578+08:00`. The independent r2 review passed. The accepted scope remains limited to the architecture boundary and r1/r2 provenance.
