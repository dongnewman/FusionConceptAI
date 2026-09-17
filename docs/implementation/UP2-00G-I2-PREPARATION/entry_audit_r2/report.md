# G-I2 / B04 entry audit R2

## Verdict

`changes_requested`; `ready_for_focused=false`; `status=review_pending`; `accepted=false`.
This is a read-only provenance repair of the R1 entry audit. It does not reclassify the G-I1B matrix as formal B04, does not run Julia/DESC, and does not modify R1, source, tests, core documents, runs, or existing evidence.

The R1 substantive decision remains unchanged: there are no fresh candidate-bound 50-row B04 receipts, no independent 50-row checker, no two-process replay, and no B00 F0–F5 execution. Provider, mesh, engineering, physical, and R01–R10 credit remain false.

## R2 corrections

The following R1 provenance defects are corrected against the bytes present at this audit time:

1. The G-I1A author manifest is `docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/evidence_manifest.json` with SHA256 `F1BA10B4E5192C2F58D95F2E54BE397424F8E0DB3E33441C8EB11F0563F8F5FB`. The G-I1A source has drifted since R1 from R1's `C01A27D6...` snapshot to current SHA256 `D84DB10E6332E5F0919F2E4D1F8BA1B910DC3C39D74CFBC7869E579FF5718FD9` and 29,560 bytes; this is recorded as drift, not silently treated as a new acceptance.
2. The N05 receipt runner is `test/GenomeV5/UP2/run_n05_flux_receipt_export.jl`, 577 bytes, SHA256 `E6C122CE7A0CA410A243C1F2D790FD0D9F0B0DBABB00BECDC7D092E7E3FCD9EC`.
3. The UP1-04 independent review files are under `docs/implementation/UP1-04/independent_review_r12/`, not `independent_r12/`: `acceptance.md` is 3,840 bytes, SHA256 `08D35ED3C64F3E087279EE7A1110ADD5C44BA504D9A614C4EA86D206C0646C9F`; `evidence_manifest.json` is 4,775 bytes, SHA256 `2F584705C46A3066469D8C2F78525B0D8F4379A50D8FA0D444CAC24672C00692`.

The current G-I1A drift is material for dependency scheduling: the old independent R3 `changes_requested` review was against earlier bytes, while the current author manifest still says review pending and no current independent review/runtime has been supplied. R2 therefore preserves the dependency as unresolved.

## Formal B04 gates retained from R1

The required contract remains five fresh candidate-bound receipts for each N01–N10, with complete candidate/package identity, G1/G2/G3 five-field refs, component hashes, four axes, E0 bound-input and G-I1 context hashes, typed source path/ref/type/hash, original and attempted values, mutation hash, source-derived error code/path/resolution, counters, and process/input metadata. Expected labels remain test oracles only; `program_exception`, `fail_closed`, and `terminal_deferred` remain distinct.

The independent checker must read serialized JSON and rebuild the actual A/E0/context source. It must not reuse the N05 exporter's `_n05e_row` helper. It must reject forged source ref/path/hash, foreign or stale package/E0/context identity, wrong axes, omitted/duplicate rows, and altered canonical values. The two-process gate requires two fresh Julia processes, disjoint outputs, identical frozen input hashes, canonical row/result comparison, and complete process/log/exit evidence. Neither gate exists today.

G-I1B R2 remains a `pass_limited` source inventory only. UP2 remains review pending. UP1-04A remains accepted-limited only. The audit remains `changes_requested` and cannot authorize a focused B04 run.

## QA and protected state

The audit froze HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`; the worktree remained dirty and protected. No Julia/DESC process was present. JSON parsing, control-character scanning, `validate_plan.py`, and `git diff --check` are recorded in `command_receipts.json`. The four R2 files are the only files created in this R2 archive.
