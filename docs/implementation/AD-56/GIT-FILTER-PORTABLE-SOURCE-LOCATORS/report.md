# AD-56 Git-filter portable source locators

Status: `completed_review_pending`; `accepted=false`.

Freshness receipt: the task manifest raw-file SHA256 is `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`; its Git blob OID is separately recorded as `f514c155e2004378a61ee3efc4d0be9085eeb017`. The planning counts are `markdown_files=31`, `relative_links=534`, `tasks=39`, `acyclic=true`.

AD-56 changes only software provenance portability. G1, G2 and G3 validators now treat `source_bytes`, `source_sha256` and `head_blob_sha256` as canonical `HEAD:path` blob evidence. Raw working bytes must exist and be readable, while the filtered working blob is checked with an argument-array `git hash-object --path <repo-relative-path> <working-file>` call. Root/HEAD/tree, stage-zero tracking, index flags, porcelain cleanliness, canonical length/hash, filtered OID, path labels and relabel controls remain fail closed.

Serial focused tests all passed:

- G1: PID `107784`, UTC `2026-09-15T23:57:13.3671837Z`–`2026-09-15T23:57:33.4335164Z`, exit `0`, 35/35.
- G2: PID `96716`, UTC `2026-09-15T23:57:47.4505363Z`–`2026-09-15T23:58:07.5125515Z`, exit `0`, 35/35.
- G3: PID `103260`, UTC approximately `2026-09-15T23:58:23Z`–`2026-09-15T23:59:12.7523971Z`, exit `0`, 356/356.

Each test retains the core.autocrlf=false fixture and adversarial controls, and adds a real core.autocrlf=true temporary Git fixture with canonical LF HEAD evidence, platform checkout/raw separation, clean porcelain, matching filtered OID, and subsequent content mutation fail-closed behavior. Windows temporary fixture cleanup retries are present in all three tests.

G1/G2 stderr retains the expected Git diagnostic emitted by the deliberate missing-module-dir repository-anchor negative control; both processes still exited 0. G3 stderr contains the expected autocrlf checkout warnings; it also exited 0.

The task manifest and unrelated dirty worktree were preserved. Source authority/trusted/candidate/final/provider/mesh/solver/physics/search/R01-R10 remain false, L4 remains 0, and AD55 F0/S2 still require repair and a fresh rerun.
