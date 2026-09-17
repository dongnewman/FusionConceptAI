# AD-35 task closeout and cleanup independent review R2

Date: 2026-09-15  
Reviewer: different Luna/high (`/root/g3_control_arch_independent_review`)  
Repair reviewed: `docs/implementation/AD-35/repair_r1/`  
Parent review: `docs/implementation/AD-35/independent_review_r1/`  
Decision: `changes_requested`  
Scope: read-only contract and closeout-evidence review; no implementation acceptance

## Evidence boundary

I read the repaired AD-35 acceptance and manifest, repaired status-sync report
and manifest, repair report and manifest, the core task manifest and linked
README/14/16/18 documents, and the current dirty workspace state. No reviewed
file was modified and no Julia or DESC command was run.

The repair correctly adds the full 40-hex base commit, actual model/reasoning,
static command timestamps/PIDs, command output hashes, input hashes, exact
protected inventory rows, status-sync manifest ownership, and the explicit
`review_pending`/`accepted=false` boundary. The 37-task manifest still has 37
unique tasks, zero missing dependency IDs and zero dependency cycles. Core
AD-35 links exist, the reviewed JSON parses, and the scoped diff check returns
exit code 0. Physical, provider, engineering, search, B00, B04 and R01–R10
credits remain false.

## Remaining blocking findings

### 1. Repair command receipts are still incomplete

`docs/implementation/AD-35/repair_r1/manifest.json` has `output_hashes: {}`
for both receipt entries even though the AD-35 contract requires output hashes
in every applicable command receipt. Artifact hashes do not replace the
required output-hash field.

The first receipt states `stdout_raw` and `stderr_raw` were captured in memory
and summarizes them in the report, but it does not retain raw content or a raw
artifact path. The diff receipt uses the literal command text
`-- [exact allowed paths]`, which is not an executable argv and cannot be
independently replayed. The status-sync receipt has a similar in-memory raw
description, although it does provide hashes.

Repair must make each receipt replayable and complete: exact argv/path list,
cwd, PID or explicit in-process status, UTC times, raw stdout/stderr or a
bounded content artifact, combined output, all corresponding hashes, exact
input hashes and output/artifact hashes. This remains a documentation/static
validation receipt; `code_tests=not_applicable` and no physical evidence are
correct.

### 2. Self-exclusion is not recorded at the manifest level

The acceptance text requires `status_sync_r1/manifest.json` to use an explicit
self-hash exclusion rule. The status-sync manifest has a row-level
`self_hash_excluded: true` and a string in `file_hashes`, but no top-level
`self_hash_excluded` field or equivalent canonical manifest rule. Its own
`file_hashes` entry is only a string label. Add a top-level typed rule and keep
the exact path, existence, reason, and nonrecursive rule in the inventory.

### 3. Repair point-in-time hashes no longer match the current status-sync bytes

The repair manifest records these status-sync artifact hashes:

* `status_sync_r1/report.md` =
  `a6ea166f8237ff217b80088d706da3ef29659ed632ba98793565a8e891dd3606`;
* `status_sync_r1/manifest.json` =
  `d12493da3879d531bea29b88b9af796349ba997a1b5d4ed169ac25000cc8a96a`.

The current checkout hashes are respectively
`936ed471b4ba646efab60d1faa7244c943c923e22f732cff69866cfe4ee47ba8` and
`749b61fa7c19c61437e51b410f63b7ccedd9c074c712edf4835ad86a7f0ca754`.
The status-sync report hash matches its current file, but the repair receipt's
artifact record is stale; the manifest's own current bytes also differ from
the repair record under its self-exclusion scheme. Refresh the repair/status
sync point-in-time chain after the final edit, with no back-attribution to
older evidence.

The status-sync manifest's own input hash is intentionally not its current
recursive value, but the record must make that distinction explicit and must
not present a stale ordinary artifact hash as current evidence.

## Closed items

The original R1 issues are otherwise addressed: full base commit and model /
reasoning are present; cleanup inventory now has exact rows for the status
manifest and repair records with no `all other` aggregate; before/after
protected hashes are listed; ambiguous cleanup is preserved; and no broad
glob, global cleanup or global revert is authorized. The current status remains
`review_pending`/`accepted=false` with `sol_decision=pending`.

The task manifest and core sync remain at 37 tasks with the same dependency
DAG. AD-35 is a collaboration/closeout contract and has not been incorrectly
turned into an accepted mainline task. The contract correctly requires
task-specific positive and negative tests for implementation tasks, while
this documentation task records only applicable static validation.

## Cleanup inventory for this independent review

This review created no temporary or scratch file. No cleanup action was taken;
no existing dirty path, other-agent path, source, test, run, failed receipt or
accepted artifact was touched.

## Ruling

`changes_requested`. Complete the receipt fields and exact argv/raw artifact
record, add explicit manifest-level self-exclusion, and refresh the stale
status-sync hashes. Then a different Luna may re-review. Any eventual AD-35
acceptance remains limited to the collaboration contract and documentation
validation; it cannot grant implementation, physical or R01–R10 credit.
