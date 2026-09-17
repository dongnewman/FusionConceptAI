# UP1 R2 authority intake: offline spool/dropbox protocol

This adapter is a local transport boundary, not an authority verifier. It
does not open sockets, send messages, verify external signatures, access a
trust store, or issue an external acknowledgement. A successful result is
`accepted_local` and remains `typed_absence` for the real endpoint/channel.

## Dropbox layout

Create a private spool directory with these adapter-owned directories:

```
incoming/                 # operator drops complete .json files here
cas/sha256/NN/<digest>.json
quarantine/<source>.bin   # byte-preserving rejected input copy
quarantine/<source>.json  # local rejection reason
receipts/<receipt>.json
state/ledger.json
```

The source in `incoming/` is never renamed, removed, or rewritten. A file is
accepted only when it is a regular, non-symlink file below `incoming/`, is
opened read-only, and has unchanged size, mtime-nanoseconds, and file identity
before and after the read. Input is bounded by `--max-bytes` (1 MiB by
default). Absolute paths, `..` traversal, links, directories, oversize files,
and TOCTOU changes are rejected. Rejected bytes are copied atomically to
quarantine; the original remains untouched. For an oversize file the adapter
does not read any bytes, and emits a bounded local rejection receipt with
`raw_unavailable=true`, `quarantine_copy=not_attempted`, observed size, and
configured limit.

## Envelope

The exact schema is in `schema.json`. Required references are
`sender_id` and `authority_channel_id`; they are identifiers only and do not
assert that an external owner or endpoint exists. `nonce`, positive integer
`sequence`, and `idempotency_key` are required. Canonical JSON uses UTF-8,
sorted keys, compact separators, and rejects duplicate keys and non-finite
numbers. The CAS object is the canonical envelope bytes, addressed by its
SHA-256 digest.

The ledger uses an OS-exclusive lock around atomic read-modify-write and binds
idempotency key, sender/channel, nonce, sequence, source
digest, and canonical digest. A same-key/same-content retry is `duplicate`.
A same-key/different-content request is `idempotency_conflict`; a reused
nonce is `nonce_replay`; and a sequence not greater than the last accepted
sequence for that sender/channel is `sequence_replay`. These paths quarantine
the input and do not create a ledger entry.

## Local receipt boundary

Each accepted, duplicate, or quarantined attempt gets a local receipt. The
receipt includes local PID/UTC, source and canonical digests, CAS/quarantine
references, and a digest over the receipt bytes without its digest field. It
intentionally contains `signature: null`,
`external_signature_state: "not_verified"`,
`external_endpoint_state: "typed_absence"`, and
`local_bookkeeping_only: true`. The digest is content addressing, not a
signature and not evidence of external authority, trust, acknowledgement,
source closure, or UP1/T0/T1/T2 credit.

CLI output is one JSON object per invocation:

```text
python -B -m tools.up1_external_closure_r2.authority_intake \
  --spool <spool> --input <spool-relative-name>
```

Exit `0` means local acceptance/duplicate (or a scan with no per-file error);
exit `2` means a rejected/quarantined input. No network is used in either
case.
