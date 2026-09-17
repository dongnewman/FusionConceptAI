# Selective staging execution

- Date: 2026-09-17 (UTC)
- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Expected and observed `HEAD`: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Branch: `main` (`origin/main` ahead/behind: `+1/-0` at the initial snapshot)
- Commit: not performed

## Scope

The first staging command was restricted to these top-level paths:

```text
AGENTS.md README.md docs/ src/ test/ tools/ scripts/ benchmarks/ examples/
```

The following were kept out of the index: `runs/`, `.codex_trash`, `__pycache__/`,
`.pytest_cache/`, `*.pyc`, `tmp/`, root-level `*.log`, `*.exit`, `*.out`,
`FusionConceptAI/`, `M4-SCOPE-DECISION-R1/`, `independent_precheck_r9/`, and
`independent_postrun_r5/`.

## Commands and receipts

1. `git add -- AGENTS.md README.md docs src test tools scripts benchmarks examples`
   - PID `67632`
   - UTC `2026-09-17T07:14:04.4388927Z`
   - exit `0`
2. The first command accidentally included five tracked/generated Python cache files
   under otherwise allowed `docs/` descendants. They were removed from the index by
   exact path only:
   `git restore --staged -- <five __pycache__/*.pyc paths>`
   - PID `100116`
   - UTC `2026-09-17T07:15:53.6444167Z`
   - exit `0`
3. `git add -- docs/implementation/HYGIENE-CHECKPOINT-20260917/06-staging-execution`
   - PID `31272`
   - UTC `2026-09-17T07:17:17.0649775Z`
   - exit `0`
4. The report was amended with the final scope verification above and re-staged
   using the same report-directory-only command:
   - PID `58736`
   - UTC `2026-09-17T07:19:29.4144695Z`
   - exit `0`

No working-tree restore, delete, reset, or checkout was used.

## Index checkpoint after exact unstage

- staged file count: `9405`
- staged-path working-tree byte sum: `174033592`
- `git diff --cached --shortstat`: `9405 files changed, 3042013 insertions(+), 467 deletions(-)`
- forbidden staged path count: `0`
- forbidden staged paths: none

The five excluded paths were:

```text
docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/02-pki-independent-review-r2/__pycache__/attack_review.cpython-313.pyc
docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/reviews/09-atomic-r2-independent-review-r1/__pycache__/adversarial_probe.cpython-313.pyc
docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/03-environment-closure-independent-test/__pycache__/run_serial_twice.cpython-313.pyc
docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/independent_precheck_r4/__pycache__/run_precheck.cpython-313.pyc
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/07-repair-scope-contract-r4/self_tests/__pycache__/validate_contract.cpython-313.pyc
```

## Remaining unstaged/untracked summary

At this checkpoint, `git status --porcelain=v1 -uall` reported:

- total porcelain entries: `10685`
- staged/index entries: `9405`
- unstaged tracked entries: `1` (`runs/goal_recovery_20260913_012528_cst/task_queue.json`)
- untracked entries: `1279`
- untracked top-level roots: `docs/`, `independent_cubature_focused.exit`,
  `independent_cubature_focused.log`, `probe.tmp.err`, `probe.tmp.out`,
  `q4_final_standalone.log`, `q4_package_regression_retry.exit`,
  `q4_package_regression_retry.log`, `runs/`, `test_tmp.out`, `tmp/`

This report is the only file written by this staging subtask. The report directory
is to be staged separately after creation; no commit is authorized here.

The first report-directory stage verification immediately after command 3 observed
`9406` staged files, `174036599` staged-path working-tree bytes,
`9406 files changed, 3042083 insertions(+), 467 deletions(-)`, and zero forbidden
staged paths. The report was indexed at that point.

Final read-only scope verification before this receipt amendment observed:

- `HEAD`: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- staged file count: `9406`
- staged-path working-tree byte sum: `174037038`
- `git diff --cached --shortstat`: `9406 files changed, 3042092 insertions(+), 467 deletions(-)`
- outside-allowlist staged paths: `0`
- forbidden staged paths: `0`
- report indexed: `true`
- `git diff --cached --check`: exit `2`, with `2751` whitespace-diagnostic lines in
  the broad pre-existing staged material; no whitespace changes were made by this
  staging subtask.
