# UP1 R2 authority_intake independent evidence review R4

Decision: **pass_limited**. No P1 or P2 was reproduced in this R4 review.
The claim ceiling remains `software_bookkeeping_only`; this is not external
authority, endpoint, signature, trust-root, or UP1/T0/T1/T2 evidence.

## Fresh validation and statistics

Fresh `python -B` focused validation exited 0 with 19 total test cases:
17 executed tests passed and 2 were skipped. The skips are ordinary Windows
symlink creation and the non-Windows metadata path; the executable Windows
Junction/reparse substitute and both Junction insertion race tests executed
and passed.

The R3 statistics repair is internally consistent: author manifest and raw
record both state total 19, executed passed 17, skipped 2, failed 0; the
validation receipt states 17/19 with 2 skipped. All 13 author-manifest owned
entries match exact current byte counts and SHA-256, and both retained raw
streams match their recorded exact-byte hashes.

## R3 attack regression

- Input Junction inserted after lexical/path validation: handle final-path,
  file-ID, and reparse checks returned structured `reparse_input` rejection.
- CAS output Junction inserted before handle open: structured
  `cas_symlink` quarantine; external target received zero files.
- Wrong-byte CAS replacement: structured `cas_collision` quarantine and
  receipt.
- Hardlink alias: feasible and `accepted_local` with the same inode; no
  pathname escape was observed.
- Concurrent sequence/idempotency/ledger checks remain covered by the focused
  cross-process tests: no duplicate same-sequence acceptance and no ledger
  loss in the tested valid cases.
- Immutable receipt collision returns `output_collision` and leaves the
  original receipt bytes unchanged.
- Forced non-Windows handle capability returns `unsupported` with
  `handle_pinned_io_unsupported`, never `accepted_local`.
- An envelope containing fake `external_signature` data still produces
  `signature=null`, `not_verified`, `typed_absence`,
  `external_authority_claim=false`, and `local_bookkeeping_only=true`.

## Decision

R1/R2 attacks, R3 handle-pinning races, and the R3 P2 statistics defect are
closed in the observed state. No P1/P2 remains in scope; `pass_limited` is
appropriate only for the software bookkeeping boundary. External authority
remains explicitly absent.

