# G-I2 entry audit R2 independent review

## Verdict

`changes_requested`; `pass_limited=false`; `accepted=false`; `status=review_pending`.
This is a read-only static review of `entry_audit_r2/`. No Julia or DESC was started, and no source, test, core document, prior archive, or run artifact was modified. No B00, B04, provider, mesh, engineering, physical, or R01–R10 credit is granted.

## Frozen review state

The repository was checked at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. The prewrite worktree contained 292 status lines with UTF-8 status SHA256 `39e9106701d4ae5a6148bb2ad31e8739c7b03ba59fd7a02ee0ee9c6966cdb5017`. The Julia/DESC process sweep was empty. The dirty state is protected and remains unrelated to this archive.

## R1 repairs and current R2 hash audit

The R2 author corrected the R1 path mistakes for the N05 runner and both UP1-04 independent-review files:

| R2 input | R2 recorded | current result |
|---|---|---|
| `src/GenomeV5/UP2/GI1AuthorityContextV1.jl` | 29,560 B, `D84DB10E6…FF5718FD9` | matches |
| `docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/evidence_manifest.json` | 5,545 B, `F1BA10B4…F0563F8F5FB` | **mismatch**: current 5,848 B, `9A94DFED…39C90DE8` |
| `test/GenomeV5/UP2/run_n05_flux_receipt_export.jl` | 577 B, `E6C122CE…FCD9EC` | matches |
| `docs/implementation/UP1-04/independent_review_r12/acceptance.md` | 3,840 B, `08D35ED3…C0646C9F` | matches |
| `docs/implementation/UP1-04/independent_review_r12/evidence_manifest.json` | 4,775 B, `2F584705…72C00692` | matches |

Thus three of the four R1 path/hash repairs are currently reproducible, but the G-I1A manifest has drifted again after the R2 snapshot. R2 records the earlier source drift (`C01A27D6…` to `D84DB10E…`) but does not record this later manifest drift. The current G-I1A author manifest still says `review_pending`/`accepted=false`; the current independent R5 artifact is static `ready_for_serial_focused` only and is not a focused runtime or acceptance.

The R2 `unchanged_relevant_inputs` list also no longer matches current bytes:

| path | R2 recorded SHA256 | current SHA256 | current bytes |
|---|---|---|---:|
| `docs/v4_multitopology_generation/README.md` | `66681D07…1D613A46` | `E208D32E…E03D8C0` | 20,977 |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | `12484C7C…8BE0C829` | `9C1DC810…8B12C63` | 58,474 |
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | `A7BFFC31…5ACA28C` | `9D5D32FE…0960CEAD` | 43,825 |
| `docs/v4_multitopology_generation/up0_02_protocol.json` | `6904EA16…ECD7BFB` | same | 28,771 |
| `docs/implementation/AD-26/acceptance.md` | `8388B9CF…2050C07` | same | 1,653 |
| `docs/implementation/AD-26/evidence_manifest.json` | `515C2B59…FD7B38` | same | 2,994 |
| `docs/implementation/UP2-00G-I1B-PREPARATION/source_matrix_r1/source_matrix.json` | `EC980F1D…A53134` | same | 35,982 |
| `docs/implementation/UP1-04/acceptance.md` | `012B7DD7…5E3245` | same | 5,727 |
| `docs/implementation/UP1-04/evidence_manifest.json` | `47F4F8A5…8FA7237` | same | 11,499 |

All listed paths exist, but four listed hashes are stale. This fails the requested “all paths exist and current hash matches” condition. The R2 evidence manifest also leaves its own QA fields as `pending_final_receipt`, despite its command receipt claiming QA commands exited zero; that is a provenance inconsistency requiring repair.

## Substantive gate remains closed

The R2 substantive boundary is correct and is retained: the G-I1B matrix remains source inventory only; UP1-04A remains accepted-limited structural entry/join scope; the existing N05 local slice is not a formal B04 archive. There is still no fresh candidate-bound five-by-ten receipt set, no independent serialized 50-row checker, no two-fresh-process replay, and no B00 F0–F5 execution. The missing formal gates remain blockers after the provenance drift is repaired.

A corrected R3 audit would need to freeze a new current input manifest, explicitly record the G-I1A R5/source and manifest state, rerun JSON/control/plan/diff QA, and preserve the same claim ceiling. It must not promote `ready_for_serial_focused` or any local matrix row into B04 acceptance.

## QA

Independent commands recorded in `command_receipts.json` all exited zero: current status/process preflight, current hash comparison, JSON parse, control scan, `validate_plan.py`, and `git diff --check`. `git diff --check` emitted only Git line-ending warnings. No runtime command was invoked.
