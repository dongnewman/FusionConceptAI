# UP1 R2 authority_intake independent attack review R1

Decision: **rework** (`P1_findings_present`). This is a software-only review; it
does not claim external authority, signature verification, endpoint
availability, or any UP1/T0/T1/T2 credit.

## Scope and evidence

Reviewed only the requested `authority_intake` implementation, focused tests,
and 07-authority-intake documentation. The focused fresh run was:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/authority_intake -p 'test_*.py' -v
```

Result: exit 0, 9 tests passed, 1 symlink test skipped because this Windows
host does not grant symlink creation. The independent fresh-process attack
matrix is in `raw/attack_matrix.json`; its source hashes and the exact reviewed
input hashes are in `manifest.json`. No requested implementation or test file
was modified.

## Findings

### P1-1 — incoming reparse junction defeats the input boundary

`adapter.py:164-173` resolves/creates `incoming` without rejecting Windows
reparse points. `adapter.py:183-193` compares the resolved path with
`self.incoming.resolve()`, so an `incoming` junction targeting an outside
directory makes the outside directory become the apparent boundary. A fresh
`mklink /J incoming outside` probe returned `accepted_local` for an
outside file. The documented “below incoming” and non-link invariant is not
enforced; an operator or attacker can feed an arbitrary outside envelope into
the local acceptance path. Reject `Path.is_junction()` and the Windows
reparse-point attribute on every component before resolving, and open beneath a
validated directory handle where the platform permits.

### P1-2 — adapter-owned reparse points redirect writes outside the spool

`_assert_no_symlink_components` (`adapter.py:76-91`) and the destination guards
(`adapter.py:125-129`, `236-244`, `305-309`) test `is_symlink()` only. On this
host `Path.is_symlink()` is false while `Path.is_junction()` is true. A fresh
`cas` junction to an external directory resulted in `accepted_local` and one
CAS JSON written outside the spool. The same unchecked pattern applies to
`receipts`, `quarantine`, and `state`; initialization (`161-173`) follows
such links before any guard runs. Treat every reparse/junction as unsafe,
validate the complete adapter-owned tree before use, and prevent races around
destination creation.

### P1-3 — CAS replacement/collision is an uncaught exception

`_atomic_cas` raises `IntakeError("cas_collision")` at `adapter.py:125-144`,
while `intake` calls it without a catch at `adapter.py:386-403`. A
pre-created digest path containing wrong bytes made the adapter raise; the CLI
exited 1 with a traceback, and produced no quarantine or receipt. An
input-driven adapter must return a stable rejected/quarantined result and
preserve the source/audit trail on CAS replacement, including destination races.

### P1-4 — ledger checks are not atomic across concurrent intakes

`_load_ledger`/validation and `_write_ledger` are separate operations
(`adapter.py:256-271`, `355-401`) with no lock or compare-and-swap. A fresh
two-thread barrier probe made two different envelopes with the same
sender/channel and sequence 1 both return `accepted_local`; the final ledger
contained only one entry and `last_sequence` remained 1. Thus sequence,
nonce, and idempotency invariants can be accepted twice and one receipt loses its
durable ledger binding. Use an OS/process-safe lock plus atomic
read-modify-write/CAS and re-check under the lock.

### P2-1 — absolute paths inside incoming violate the written protocol

`_validate_source_path` explicitly accepts absolute paths (`adapter.py:176-183`)
when they resolve below incoming. A fresh absolute-inside probe returned
`accepted_local`, while `07-authority-intake/protocol.md:19-25` says absolute
paths are rejected. Either reject all absolute caller paths or revise the
contract and tests; do not leave this mismatch at an authority boundary.

### P2-2 — internal junctions are silently accepted

Even when a junction resolves back inside the spool, the component loop at
`adapter.py:188-193` cannot see the original junction after `resolve()`.
A junction `incoming/linkdir -> incoming/real` returned `accepted_local`.
This is a direct failure of the stated non-link rule and should be covered by
an executable reparse-point substitute when Windows symlink creation is
unavailable.

### P2-3 — duplicate result does not verify the CAS object still exists

At `adapter.py:357-361`, a same-key/same-content retry returns `duplicate`
solely from ledger fields. Deleting the referenced CAS object after the first
acceptance still returned `duplicate` with `cas_exists=false`. Verify the
content-addressed object and digest before reporting duplicate, or repair/fail
closed with an auditable result.

### P2-4 — oversize rejection is not quarantined despite the contract

The oversize check exits before bytes are read (`adapter.py:199-202`). A fresh
oversize probe returned a receipt but created zero quarantine files, while
`07-authority-intake/protocol.md:19-22` says rejected bytes are preserved in an
atomic quarantine copy. If bounded storage is intentional, document the
exception and include an explicit source metadata/error receipt; otherwise use
a bounded quarantine policy.

### P2-5 — supplied validation raw hash is not independently verifiable

`validation_receipt.json:23-34` correctly points to the raw record and its
recorded stream hash, but hashing the stored decoded `stderr_raw` gives
`a6d111bd09b9651ec2511b00b5289b7a3357d26191c4a8453f299e73f813e818`, not the
recorded `ad9457441d06e768819a06bd05a380ffdb113e1900e8bf3f1cf87e6f0b7ef372`.
There is also no manifest in the author 07 directory. The raw capture therefore
needs explicit byte/newline normalization or a regenerated receipt plus a
manifest before it can serve as reproducible evidence.

## Positive controls confirmed

Duplicate JSON keys, unknown fields, unsupported schema version, nonce replay,
sequence rollback, ordinary `..` traversal, ordinary oversize detection,
metadata TOCTOU injection, quarantine for parsed-invalid envelopes, CAS
addressing, and source byte preservation passed the focused tests. Hardlinks
are feasible on this host and an outside-file hardlink under `incoming` was
accepted; it did not escape by pathname and is therefore recorded as an alias
property, not treated as a traversal bypass. The `external_signature` input did
not masquerade as authority: receipt fields remained `signature=null`,
`external_signature_state=not_verified`, `typed_absence=true`, and
`external_authority_claim=false`.

## Required rework gate

Do not promote this slice from `rework` until the P1 findings are fixed and
fresh `python -B` tests cover junction/reparse substitutes, CAS collision and
replacement races, concurrent ledger updates, duplicate-with-missing-CAS,
absolute-path policy, and receipt/raw/manifest hash verification. Keep the
external claim ceiling at `software_bookkeeping_only`.

