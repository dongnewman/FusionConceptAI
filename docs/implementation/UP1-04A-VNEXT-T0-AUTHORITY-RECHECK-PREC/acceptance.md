# Acceptance boundary

Sol accepts the local typed-absent software scaffold as `accepted_limited` under independent postrun R3 `pass_limited`. The machine node remains `planned`, `proposal`, `review_pending`, and `accepted=false`; this acceptance does not create checked-present authority.

## Required contract

- Input is a read-only T0 bundle byte snapshot plus the current candidate G3 declaration shape.
- Required upstream authority pairing is exactly one record for each of `G1` and `G2`. Duplicate, missing, unknown, foreign-candidate, layer-mismatch, target-authority mismatch, projection-mismatch, duplicate-key, and duplicate-id cases fail closed.
- The legacy six-field authority projection is compared byte-for-byte with its paired upstream record only to detect contradiction. Equality remains non-authoritative.
- `actual`, `missing`, and `historical_absent` map to typed absence with the frozen terminal-deferred reasons. `stale`, `contradictory`, and unknown statuses fail closed.
- Present output is permitted only for a fresh T0-owned declaration authority record with candidate, layer, declaration reference, declaration hash, canonical bytes, source receipt, and trusted attestation. Synthetic, ref-only, fixture, and incomplete records are rejected.
- Prior bundle bytes and hash remain unchanged on every failure path. No declaration authority is synthesized by this work order.

## Verification gate

The lightweight static QA runs before the single focused Julia test and records the actual Python executable, executable hash, version, raw output, PID, exit code, input/output hashes, and process guard. The focused test is invoked directly with Julia and no launcher. DESC and unrelated heavy Python are prohibited. Any repair is append-only, minimal, and serial.

The preserved R6 evidence is static QA `20` checks and direct focused Julia `68/68`; R1-R7 receipts, the foreign declaration candidate repair, and cleanup inventory remain append-only. R21 remains a historical `interrupted_incomplete` receipt and was not retried. The latest R22 receipt is `runtime_complete`: direct Julia `310/310`, exit `0`, `25` runtime negative dispatches, `accepted=false`, `contract_only`, and no T1/T2 credit. `100 snapshots` is only a static 25×4 derivation, not an independently runtime-counted result. These are local software contract/runtime-boundary results, not authority or readiness receipts.

## Non-claims

This evidence is limited to the accepted local typed-absent contract behavior. It does not establish actual binding, feedback, control, T0 authority, T1/T2 readiness, provider or mesh capability, engineering or physical validity, search credit, or any B/R credit. Because no checked-present recheck result exists, T1 remains blocked while depending on both T0 and this recheck work order in the core plan.
