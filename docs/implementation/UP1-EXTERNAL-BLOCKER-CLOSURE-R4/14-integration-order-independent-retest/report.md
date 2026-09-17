# UP1 R4 integration order-independent retest

## Scope

This is an independent retest after the ordered implementation was frozen. The
only implementation-adjacent change is the focused integration test's stale
order assertion: the strict xfail was removed and both assertions now require
the 02 contract order. No tool implementation, typed-state rules, receipt
logic, publication locks, or heavy lane were changed.

Required order:

```text
atomic_bundle
authoritative_intake
source_axis_binding
g2_mapping
environment_closure
trust_chain
freshness
```

## Execution evidence

Command, run serially twice:

```text
python -m pytest test/up1_external_closure_r4/integration/test_integration.py -q
```

Both runs exited `0`; run 1 reported `15 passed in 0.18s` and run 2 reported
`15 passed in 0.25s`. UTC start/finish, child PID, exit, and stored-artifact
SHA-256 receipts are in `raw/` and summarized in `run_manifest.json`.

The adversarial focused selection also exited `0`: `5 passed, 10 deselected`.
It covers adapter exception typing, forbidden environment probing, serial
semantic identity, raw-byte preservation, and publication/authority locks.

The raw files are text-normalized to LF by the patch transport; their hashes in
the manifest are hashes of the stored evidence bytes. The captured Windows
pytest stream was CRLF, so its transport hash is intentionally not reused as a
stored-file hash.

## Independent checks and ruling

- `STAGE_ORDER` and the contract tuple are exactly equal to the seven-stage
  order above.
- The trace and result insertion order are both one-pass and match that order.
- Empty input remains typed-absent/terminal-deferred with no T0/S3, network, or
  runtime execution.
- Hard failures remain fail-closed; all-or-reject retains stage receipts,
  hashes, and the binding tuple.
- Typed program exceptions, forbidden probes, non-mapping adversarial output,
  publication-lock attempts, and raw bytes are all closed as specified.

Independent ruling: **PASS for the bounded order-independent R4 integration
retest; fail-limited to this offline focused seam.** This does not grant
external authority, formal credit, publication permission, T0/T1/T2 credit, or
parent-goal closure.
