# UP1 external-closure R2 aggregate gate

This directory records the bounded software evidence for the versioned JSON
aggregate gate. The implementation accepts exactly four responsibility
packages and each component receipt must carry the same candidate, source and
input fingerprints as the root intake. `verified` is reduced only to
`eligible_for_authority_recheck`; every other declared state is fail-closed as
`terminal_deferred` with `no_publish=true`.

The gate never creates an AD and never grants T0, T1, T2, B00, B04, L4 or
parent credit. A repeated input fingerprint is a deterministic no-op. A new
input fingerprint emits `intake_changed` only, so an ordered fresh intake is
required before aggregation.

R1 hardening additionally rejects unknown fields at root/package/receipt
boundaries and duplicate JSON keys, requires the exact responsibility set
`g1`, `g2`, `g3`, `source_authority`, rejects `authority_verified=false`,
enforces ordered intake/validated/aggregate transitions with monotone
sequence, sorts responsibility maps canonically, and validates lowercase
64-hex SHA-256 fingerprints (with optional fixed domain labels).

R2 state transitions require a caller-selected local JSON ledger via
`--ledger` (or `--ledger-path`). This is software bookkeeping only: each
record contains the canonical state hash, previous-record hash, strict
sequence, input fingerprint, and code version. The ledger is protected by a
cross-process lock and atomic replace. Missing production ledgers return
`typed_absence`/`no_publish`; a supplied predecessor is accepted only when it
matches the latest complete ledger state. Ledger tampering, replay, or a forged
predecessor fails closed. Deterministic no-op loads the complete state from the
ledger and never accepts caller-provided `packages`, `status`, or `no_publish`.

The focused test command is:

```text
python -B test/up1_external_closure_r2/aggregate_gate/test_aggregate_gate.py
```

The JSON CLI is `tools/up1_external_closure_r2/aggregate_gate/aggregate_gate.py`
and accepts `--input`, `--prior-state` (or `--state`), `--ledger` (or
`--ledger-path`) and `--output`.
