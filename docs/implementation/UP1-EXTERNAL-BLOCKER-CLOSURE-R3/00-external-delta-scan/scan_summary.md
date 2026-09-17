# UP1 external delta scan R3

## Decision

Read-only scan after the R2 root-acceptance capture (`2026-09-16T21:10:13.6877896Z`) found no usable external input and no external-input fingerprint change.

The disposition is exact and unchanged:

- `usable_external_inputs=0`
- `typed_absent=26/26`
- `new_ad=false` (`no new AD`)
- `s3_rerun=false` (`no S3 rerun`)
- `S3 G1/G2/G3=typed_absent -> terminal_deferred -> no_publish`

No candidate was admitted. No `typed_unverified` candidate was present to isolate. No intake, network request, signature verification, solver, S3, Julia or DESC execution was performed by this scan.

## Scope and frozen baseline

The baseline is `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/23-root-acceptance/`, captured at the UTC and HEAD recorded above. The baseline HEAD and current HEAD are both `b2c04d8339774635aaecd73651efcdb101e01b5d`.

The agreed offline intake convention is a caller-supplied spool with `local_spool/incoming/`; response files are conventionally under `response/`, independent anchors under `anchors/`, and local receipts under `local_receipts/`. These paths were checked at both the repository root and its parent workspace root. All are absent, with zero files and zero hashes. No path was created.

The eight R2 frozen project inputs (AD55 source-factory scope plus the six planning inputs including the task manifest) all exist and match their frozen raw SHA-256 values and Git blob OIDs. The current worktree porcelain count/hash differs from R2 (`378` vs `374`) because other work is dirty; this is worktree status drift, not an external-input delta, and no source/test file was changed by this scan.

## System trust inventory

Read-only certificate-store enumeration matches R2 exactly: `590` store entries and `301` unique public thumbprints; `added_thumbprints=[]`, `removed_thumbprints=[]`, and no enumeration errors. No certificate bytes or private-key material were read/exported, no store was mutated, and no network was accessed. Generic Windows/user-store certificates remain non-project trust roots without independent project authorization.

AD55 remains source-factory evidence with trust/candidate/final/provider/solver/physics claims false. AD56 remains `accepted_limited` for Git-filter portable source-locator bookkeeping only; it supplies no external trust or authority. Neither creates an external input or permits S3 rerun.

## Evidence

The raw command observations, including observer PID, UTC interval and exit code, are under `raw/`. `raw/path_scan.raw.json` is the two-root path check; `raw/frozen_input_scan.raw.json` is the eight-file hash/OID comparison; `raw/system_trust_fingerprint.raw.json` is the public thumbprint comparison; `raw/process_snapshot.raw.json` records process observation only. The transient Julia process seen in the process snapshots belongs to another concurrent workflow; it was not started, stopped, or otherwise modified by this scan.

