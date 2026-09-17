# Implementation receipt

The fresh-process focused suite passed `22/22` with `python -B` and exit code
`0`. The CLI positive run also exited `0` and returned four verified packages
with `resolution=eligible_for_authority_recheck`. Its claim ceiling remains
all false (`T0/T1/T2/B00/B04/parent`) and `L4=0`; no AD was created.

R1 rework closes strict unknown-field rejection at root/package/receipt,
rejects `authority_verified=false`, fixes the exact responsibility set,
rejects direct aggregate and sequence jumps, sorts responsibility maps for
canonical output, rejects duplicate JSON keys, and validates lowercase
64-hex fingerprints plus optional domain labels. A two-process fresh replay
is byte-identical. The implementation is intentionally independent of Genome/runtime modules and
uses only the versioned JSON interface. Fingerprint mismatch, duplicate or
mixed receipts, missing receipts, and each non-verified status remain
fail-closed. R2 adds a controlled local ledger with cross-process locking and
atomic CAS-style append, complete state receipts (`canonical_state_hash`,
`prev_hash`, `sequence`, `input_fingerprint`, and `code_version`), forged-prior
and ledger-tamper attacks, and a two-process changed-intake race. The CLI
process metadata and raw stream hashes are in the `r2_*_receipt.json` artifacts;
the ledger is explicitly bookkeeping and does not grant downstream authority.
