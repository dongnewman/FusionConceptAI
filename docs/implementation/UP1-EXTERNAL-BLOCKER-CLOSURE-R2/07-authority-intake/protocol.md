# UP1 External Blocker Closure R2 — authority intake adapter

Status: `software_implemented`, external authority still `typed_absence`.

This slice implements an offline local spool/dropbox boundary. It does not
contact a real endpoint, send a message, verify a signature, establish a trust
root, or issue an externally verifiable acknowledgement. Its only positive
state is `accepted_local`; the receipt claim ceiling is
`software_bookkeeping_only`.

Owned paths are limited to:

- `tools/up1_external_closure_r2/authority_intake/**`
- `test/up1_external_closure_r2/authority_intake/**`
- this evidence directory

The detailed protocol and envelope schema are kept beside the implementation
in `tools/up1_external_closure_r2/authority_intake/protocol.md` and
`schema.json`. On Windows, the adapter opens the input once with
`CreateFileW(FILE_FLAG_OPEN_REPARSE_POINT)`, verifies final path, file ID, and
reparse attributes on that handle, and reads from that same handle. CAS,
receipt, ledger, and lock writes likewise verify the opened handle before any
bytes are written; the ledger lock is cross-process exclusive. Junction/
reparse insertion between path validation and handle open is deterministically
rejected. It rejects oversize or TOCTOU changes, preserves rejected bytes in an
atomic quarantine copy, and stores accepted canonical UTF-8 JSON under a
SHA-256 CAS path. Duplicate JSON keys, unsupported schemas, unknown fields,
traversal, symlinks, idempotency conflicts, nonce replay, and sequence
rollback are fail-closed. Platforms without the required handle-pinned I/O
contract return `unsupported` and never return `accepted_local`.

Oversize input is not read into memory or copied without a bound. It receives
an explicit local rejection receipt with `raw_unavailable=true`,
`quarantine_copy=not_attempted`, source size, and configured limit.

The ledger uses an OS-exclusive lock around atomic read-modify-write and binds
sender/channel reference, nonce, sequence, idempotency key,
source digest, canonical digest, and CAS path. A same-content retry is
`duplicate`, not a second acceptance. The local receipt explicitly carries
`external_endpoint_state=typed_absence`, `external_signature_state=not_verified`,
`signature=null`, `local_bookkeeping_only=true`, and
`external_authority_claim=false`.

## Validation

Fresh Python `-B` validation ran 19 total cases: 17 executed passed and 2
skipped, with ordinary symlink creation and the non-Windows metadata race
skipped on this Windows host. The
two Windows Junction insertion races and cross-process ledger test passed. Raw
run metadata, PID, UTC, exit code, and stream hashes are in
`raw/authority_intake_validation_r2.json`; exact streams are retained as
`raw/validation.stdout.raw` and `raw/validation.stderr.raw`.

No UP1/T0/T1/T2, provider, source authority, solver, engineering, physical, or
external-signature credit is claimed by this implementation or its local
receipt.
