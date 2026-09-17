# AD-36 status sync R2

Date: 2026-09-15  
Status: `review_pending`  
Accepted: `false`  
Scope: point-in-time status refresh for the frozen AD-36 contract and affected policy records.

The root acceptance and manifest were frozen before this round. They predeclare `status_sync_r2/`; `status_sync_r1/` remains historical and is superseded by this append-only receipt set. No root, core14/core16/core18, README, task manifest, implementation README, AD-34 or AD-35 file was changed after the freeze.

The frozen current links are recorded in `manifest.json` with their actual SHA256 and byte counts. The frozen set contains the 39-task plan and its unchanged acyclic DAG. AD-36 remains documentation/contract evidence only and grants no mainline, physical or R01–R10 credit.

Four direct static checks were executed with child PID, UTC interval, cwd, exit code, raw stdout/stderr files, input hashes, output hashes and artifact hashes:

- JSON parse passed for six explicit manifests: AD-36 root, status-sync R1, repair R1, AD-34, AD-35 and the v4 task manifest.
- `validate_plan.py` passed: 31 markdown files, 466 links, 39 tasks, acyclic DAG, no errors.
- Exact-path `git diff --check` exited `0`. Its only stderr was the existing README LF-to-CRLF working-copy warning; it was classified as a line-ending warning, not a diff-format failure. New untracked R2 files are listed individually in the cleanup inventory and are outside git diff coverage.
- Static sidecar-policy inspection passed for AD-36, AD-34, AD-35 and the task policy, with five policy documents checked. It confirmed evidence-only content, the forbidden payload set and `scope_violation`/`fail_closed` handling.

The policy inspection had three failed schema-selection attempts before the final passing direct check. Their raw stdout/stderr pairs are retained as append-only evidence under `sidecar_policy_attempt1.*`, `sidecar_policy_attempt2.*` and `sidecar_policy_attempt3.*`; they were not overwritten or treated as scratch. No temporary launcher, source, test, fixture, cache, debug or unrelated code was created. No Julia or DESC command ran.

The cleanup inventory in `manifest.json` lists every R2-owned path individually. All R2 evidence is retained, all frozen policy inputs are protected with their freeze/current hashes, and the final owned set is exact. No ambiguous cleanup was deferred.
