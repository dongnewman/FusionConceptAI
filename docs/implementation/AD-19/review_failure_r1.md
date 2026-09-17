# AD-19 independent review history: r1

- result: `changes_requested`
- reviewer: different Luna
- scope: AD-19 semantic wording and migration boundary
- finding: the AD-18 integrated table in `18_sources_and_architecture_decisions.md` said “完整 ref 四字段”, while the public `GenomeContractRef` contract and the surrounding AD-18 text require five fields: URI, version, schema_hash, canonicalization_hash, and compatibility_profile.
- disposition: corrected in r2 by changing only that table cell; no change to AD-19 migration semantics, 16, README, source, tests, runs, or the prior AD-19 snapshots/patch.

The initial AD-19 before/after snapshots and `bounded_diff.patch` remain immutable historical provenance. The r2 single-file before/after snapshots and `bounded_diff_r2.patch` record the correction.
