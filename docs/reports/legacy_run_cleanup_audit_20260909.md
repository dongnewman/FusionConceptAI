# Legacy run-output cleanup audit — 2026-09-09

## Decision

No legacy source, original data, acceptance evidence, or run directory was
deleted or moved in this cycle.  The read-only audit did not identify a
material target that was both demonstrably rebuildable and free of unique or
uncommitted evidence.  Removing the currently visible candidates would violate
the preservation boundary, so cleanup is withheld rather than guessed.

## Current Runtime V4 repository

`D:\006-Programing\LMC\FusionConceptAI` has no tracked `runs/`, `results/`,
or generated artifact tree.  Its current untracked files are implementation,
test, and report work owned by this integration cycle plus pre-existing report
documents.  None are stale run output.

## Temporary Runtime V4 worktrees

`D:\006-Programing\LMC\.codex_tmp` contains about 881 MB.  About 823 MB is an
unrelated Canva working directory and is outside this repository's cleanup
scope.  The FusionConceptAI-named children are mostly registered Git worktrees,
not disposable result directories.  Most have uncommitted changes; several
contain tens to hundreds of changed or untracked source/test files.  They are
therefore preserved.

Four clean FusionConceptAI worktrees were observed at commits already ancestral
to current `main`, but they still contain source checkouts rather than run
results.  They may be removed or moved only in a dedicated Git-worktree cleanup
after confirming no external task still uses them.  This audit does not treat
their clean status as permission to remove source checkouts.

## Legacy v142 result candidates

The legacy repository
`D:\006-Programing\LMC\outputs\fusion_concept_ai` is heavily dirty: it has
existing tracked run deletions, modified source/tests, and untracked v137-v142
source, schemas, reports, and results.  That state predates this cycle and was
left untouched.

Four untracked candidate directories were inspected:

| Directory | Files | Approx. bytes | Decision |
|---|---:|---:|---|
| `tmp_v142_seal_check` | 5 | 274,292 | retain: unique acceptance/report/checkpoint hashes |
| `tmp_v142_seal_single` | 5 | 274,295 | retain: unique acceptance/report/checkpoint hashes |
| `tmp_v142_shard_round` | 5 | 273,177 | retain: distinct shard checkpoint and acceptance hashes |
| `tmp_v142_small_round` | 5 | 274,293 | retain: unique acceptance/report hashes |

The published-looking `runs/v142_terminal_deferred_acceptance` directory has
only two much smaller files, and neither matches the temporary acceptance
files by size or SHA-256.  The four temporary directories are therefore not
verified duplicates of that run.  Some individual files repeat across two or
more temporary directories (notably `audit_summary.json`, and one checkpoint),
but deduplicating roughly 0.4 MB would fragment the self-contained run bundles
for negligible benefit.  They remain intact.

## Safe future cleanup gate

A later cleanup may move a target to a recoverable archive only after all of
the following are true:

1. the owning repository/worktree has no uncommitted source or evidence;
2. every acceptance, configuration, checkpoint, provenance, and artifact hash
   is present in a retained canonical bundle;
3. tracked reports and scripts no longer reference the source path, or their
   references are migrated in the same reviewed change;
4. the exact source and archive paths are resolved and checked before moving;
5. a manifest records file counts, byte counts, SHA-256 values, reason, and
   recovery path.

This leaves the cleanup task explicit and recoverable without risking unique
evidence or the user's existing dirty worktree.
