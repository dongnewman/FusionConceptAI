# Root commit-scope decision — 2026-09-17

## Decision

`commit_authorized=yes`.

This is a local checkpoint decision only. It authorizes the parent integrator
to make the reviewed local Git commit; it does not authorize a push. The parent
goal remains active, and no R01–R10 gate, dependency credit, candidate claim,
or physics/engineering acceptance is changed by this Git decision.

## Fixed acceptance basis

The decision is made against the fixed final-review basis supplied for this
checkpoint:

1. The exact sixteen current-wave package scopes below, together with
   `docs/implementation/HYGIENE-CHECKPOINT-20260917`, have
   `git diff --cached --check` exit `0` with zero diagnostics after the
   current-wave whitespace repair. The paths are listed explicitly so the
   parent can reproduce the bounded check without widening its scope.
2. The independent broad scopes `AGENTS.md`, `README.md`,
   `docs/v4_multitopology_generation`, `docs/reports`, `src`, `test`,
   `tools`, `scripts`, `benchmarks`, and `examples`
   each have cached diff-check exit `0`.
3. The staged allowlist contains exactly `9413` paths; after the corrected
   files are staged again it remains `9413`, because this repair changes only
   files that are already staged. It contains no
   `runs/`, cache, temporary, or unknown-root path.
4. The high-confidence hard-secret scan has `0` hits.
5. The maximum changed staged blob is `96,429,727` bytes, strictly below
   `100,000,000` bytes.
6. The tracked queue file remains unstaged.
7. Remaining full-scan diagnostics are confined to earlier
   `docs/implementation` evidence and are accepted only as the recorded
   immutable-byte/hash exception; no historical evidence is rewritten here.
8. Untracked `runs/`, `tmp/`, and root failure/transient outputs remain on
   disk and are outside the commit; they are not staged or deleted by this
   decision.
9. Cleanup acceptance is `109/109`, with recoverable quarantine provenance and
   no cleanup failures.

### Exact current-wave cached diff-check package scopes

The sixteen bounded package paths are:

1. `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck`
2. `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/23-root-acceptance-external-recheck`
3. `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/06-repair-scope-contract-r3`
4. `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/07-repair-scope-contract-r4`
5. `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/reviews/06-repair-scope-independent-review-r1`
6. `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/reviews/07-repair-scope-independent-review-r1`
7. `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/03-scope-contract-repair-r2`
8. `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1`
9. `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/05-machine-checker-scope-contract-r2`
10. `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/03-scope-contract-independent-review-r1`
11. `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1`
12. `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/05-machine-checker-scope-independent-review-r1`
13. `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R2/05-scope-contract-repair-r3`
14. `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R2/06-scope-contract-repair-r4`
15. `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R2/reviews/05-scope-contract-independent-review-r1`
16. `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R2/reviews/06-scope-contract-independent-review-r1`

The command contract for every listed path is exactly:

```text
git -c core.quotePath=false diff --cached --check -- <path>
```

Expected result: exit `0`, no diagnostic output. The command receives each
directory path directly; no `/**` suffix is part of the command. The HYGIENE
checkpoint is checked separately with the same direct-directory command and is
also exit `0`.

## Preserved prior independent NO opinion

The following text is retained verbatim from
`10-final-staged-review/report.md`; it is historical evidence and has not been
edited or weakened:

> `commit_authorized: no`.
>
> The staged count, path allowlist, forbidden-artifact checks, high-confidence
> secret scan, blob-size limit, queue-file boundary, and staged 07/08/09
> receipts pass. The commit is blocked because the current-wave UP1-R4, M5C,
> M5SEARCH, and UP4 directories still fail the explicitly required scoped
> `git diff --cached --check` checks. The historical-evidence exception cannot
> cover those current-wave paths.

That NO was correct for the earlier index snapshot. The present YES is a
post-repair root-scope decision and does not rewrite the prior review.

## Scope and handoff

This directory is the only write made by this subtask. No `git add`,
`git restore --staged`, `git commit`, or push was performed. The parent
integrator owns the final selective commit and must re-run the lightweight
JSON/hash checks recorded in `decision.json` and `hash_manifest.json` before
committing.
