# AD-55 F0 current HEAD factory closure — blocked

Status: `blocked_on_g3_text_filter_portability_repair`; `accepted: false`. No acceptance is claimed.

Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`. The evidence-local Julia probe loaded the published G1/G2/G3 factory closure. G3 binding and bundle returned `present`, while G3 realization and control returned `fail_closed` with reason `working_tree_head_bytes_mismatch`.

The blocker is a checkout portability mismatch: `git status` is clean and `git hash-object --path` equals the HEAD object, but raw working-tree bytes differ from `git show HEAD:path` for two published G3 files (realization 33751 vs 33750 bytes; control 10297 vs 10287 bytes). The strict factory compares raw working bytes with HEAD bytes and refuses a present result. Resolve the text-filter/checkout portability outside this evidence directory, then run a fresh current-HEAD F0.

Attempt-003 diagnostic stdout/stderr and receipt are retained under `failure_history/attempt_003_*`. Attempt-002 raw files were overwritten by later evidence-local retries; `failure_history/attempt_002_receipt.json` records `observed_by_root_no_retained_raw` and the known failure text without inventing hashes. The reproducible `probe.jl` is retained; the temporary PowerShell runner has been removed.

Required negative controls were not reached after the positive G3 closure failed; `negative_controls.json` records `not_reached`. Independent review is blocked pending portability repair and a fresh run.

Claim ceiling: no source authority, trusted attestation, candidate identity, final identity, provider, mesh, solver, physics, engineering readiness, search, R01-R10, or L4 credit (`L4=0`).
