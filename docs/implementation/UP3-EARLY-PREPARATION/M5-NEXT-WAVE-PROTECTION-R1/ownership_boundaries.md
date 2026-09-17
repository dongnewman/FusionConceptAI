# Ownership and overwrite boundaries

## Hard protection boundary

Every pre-existing path in this checkout is protected. In particular, do not overwrite or clean the 27 tracked modifications listed in `raw/git_status_and_identity.txt`, any of the 9,653 porcelain entries observed at the freeze, or any generated run/log/evidence file. The source/test/contract hash manifest is a measurement of the bytes that must remain attributable to this observation; it is not permission to edit them.

## Explicitly dirty tracked files

The tracked dirty set includes the v4 README, normative contract, technical chapters 01–09, G1/G2/G3/Genome V3 and typed-AST/e-graph documents, `runs/goal_recovery_20260913_012528_cst/task_queue.json`, spatial scripts, three GenomeV5 source-authority factories, `src/RuntimeV4/SpatialRuntimeV4.jl`, and the three spatial/runtime validation tests and manifest. See the raw list for exact paths.

## Untracked protected areas

At freeze, relevant prefix counts were: `src/**` 44, `test/**` 138, `scripts/**` 19, `runs/**` 1,385, `docs/implementation/UP3-EARLY-PREPARATION/**` 193, `docs/implementation/UP4-EARLY-PREPARATION/**` 201, `docs/implementation/UP5-EARLY-PREPARATION/**` 88, and `docs/implementation/MIDTERM-AUDIT-20260916/**` 39. These include user and agent work; count is not ownership. Also protect all other untracked `docs/**`, `tools/**`, `benchmarks/**`, root logs/exits, temporary files, and the nested `FusionConceptAI` marker reported by Git.

## Observed parallel-agent write zones (do not enter)

- `docs/implementation/UP3-EARLY-PREPARATION/M5-AUTOCOMPOSITION-R1/**`
- `docs/implementation/UP3-EARLY-PREPARATION/M5-AUTOCOMPOSITION-SCOPE-DECISION-R1/**`
- `docs/implementation/UP3-EARLY-PREPARATION/M5-CHAIN-REPLAY-R1/**`
- `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R1/**`
- `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-SCOPE-DECISION-R1/**`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-EGRAPH-R1/**`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-EGRAPH-SCOPE-DECISION-R1/**`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/**` (an active profile probe was observed here)
- `M4-SCOPE-DECISION-R1/**`, `independent_precheck_r9/**`, `independent_postrun_r5/**`, and all `runs/**`/`tmp/**`/`tools/**` output areas

The M5 directories above are append-only evidence/work areas owned by other workers. Do not repair, rename, normalize, hash-rewrite, or add files to them from this task.

## Exclusive write zone for this task

Only this directory is writable by this task:

`docs/implementation/UP3-EARLY-PREPARATION/M5-NEXT-WAVE-PROTECTION-R1/**`

The directory contains only this protection record, raw observations, and the hash manifest. No existing source, test, contract, run, evidence, or process was modified. No cleanup was authorized or performed.
