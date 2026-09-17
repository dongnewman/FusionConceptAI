# AD-40 acceptance independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope

This review independently rechecks the existing AD-40 acceptance record and its
repair/R2 evidence. It accepts only the recorded
`RepositoryDesignSourceAuthorityV1` architecture boundary and the seven finite
software work-order contracts. It does not accept any work-order implementation,
candidate identity, source-backed present, T0/T1/T2, provider, mesh, solver,
engineering, physical, search, B00/B04, or R01-R10 credit.

The observed repository HEAD is
`4b69f55f7f80240147a65a22809dc1207824dde2`. The worktree is already dirty
outside this review. The original AD-40 proposal/manifest, repair R1, prior
independent R2, acceptance record, and parallel payload-authoring outputs were
read without modification.

## Independent checks

- The acceptance manifest parses and is `accepted_limited` for
  `repository_design_source_authority_architecture_and_seven_finite_work_order_boundaries`,
  with `claim_ceiling=software_source_provenance_only` and
  `authority_class=repository_design_source`.
- All 15 acceptance frozen-input paths were rehashed. The current byte counts
  and SHA-256 values match, including the AD-40 repair R1 manifest and the
  independent-review R2 report.
- The seven work orders were compared semantically against the original AD-40
  manifest: IDs, statuses, exact product paths, dependencies and forbidden
  edges all match. The global forbidden edges retain the T0/T1/T2, UP2,
  provider, mesh, solver, physical and R01-R10 boundaries.
- The four observed G1/G2 payload-authoring product paths remain explicitly
  listed as `observed_but_excluded`. They are not included in the acceptance
  decision and grant no authority or candidate identity.
- The planning validator was rerun in a fresh process (PID 27912, exit `0`):
  31 markdown files, 485 relative links, 39 tasks and an acyclic DAG. This is
  planning evidence only and is not implementation or physics evidence.
- Repair R1 was independently rechecked in a fresh process (PID 82856,
  exit `0`): 15 frozen inputs, 6 validation runs, 18 raw stream records and
  16 output records all close with matching bytes and SHA-256 values. Repair
  claims remain false and its product/sidecar boundary is respected.
- JSON, path, control-character, scope and claim checks passed in the fresh
  acceptance recheck (PID 79328, exit `0`).

All recorded claims remain false: no candidate hash, machine node, present,
T0, T1, T2, provider, mesh, solver, engineering, physical or R01-R10 result
was created or promoted. No Julia, DESC, provider, mesh, solver or physical
workload was run.

## Decision and cleanup

`pass_limited` applies only to this independent acceptance evidence review. It
does not dispatch or accept any of the seven future work orders. The current
parallel payload and authoring receipts are preserved as point-in-time outputs
and remain excluded from the architecture acceptance.

This review created only its report, manifest and raw validation sidecars under
`docs/implementation/AD-40/acceptance/independent_review_r1/`. No source,
test, fixture, static-QA, launcher, core-plan or task-manifest file was edited;
no unrelated or historical file was removed.
