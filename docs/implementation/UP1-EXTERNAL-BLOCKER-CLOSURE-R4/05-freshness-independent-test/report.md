# UP1 R4 freshness independent adversarial test

## Independent verdict

`PASS-LIMITED` for the frozen offline software boundary. Both serial runs
completed with exit `0`; each ran 10 tests with zero failures and zero errors.
The test harness reports `network_access=false`, `formal_credit=none`, and
`no_publish=true`. This is not an authority or physical-evidence result.

The implementation under test was frozen at
`tools/up1_external_closure_r4/freshness/core.py` and was not edited by this
test work. The test and runner are new files under the assigned test tree.

## Coverage and verdict criteria

| Area | Independent attack | Expected disposition |
|---|---|---|
| OCSP / CRL / receipt | good OCSP and CRL; revoked, unknown, stale, signature, issuer, nonce and missing-nonce mutations | valid only for a bound good receipt; typed absence for unavailable authority; fail closed for mutations |
| trusted time | digest/imprint, nonce/challenge, signature/chain/revocation, validity interval, future receipt and wall-clock trap | signed receipt only; malformed or contradictory input fails closed |
| nonce / sequence / window | idempotent replay, idempotency conflict, nonce cross-scope reuse, rollback, sequence gap and expired window | no second commit; typed result/error boundary preserved |
| CAS / HMAC / atomic persistence | stale CAS hash, state tamper with recomputed state hash, authenticated envelope and temporary-file cleanup | CAS conflict or `ledger_corrupt`; no partial replacement visible |
| concurrency / corruption | two independent processes, duplicate JSON keys, non-finite JSON, unknown fields, malformed ledger | one commit plus one idempotent replay; malformed state fails closed |
| reparse / path safety | key/state directory rejection and symlink rejection when the host permits symlinks | `ledger_corrupt`; no path escape accepted |
| publication boundary | static import audit and positive/negative result metadata | no network client; `formal_credit=none`; `no_publish=true` |

The host did not permit creating a symlink in this run. Directory and non-regular
file checks executed and passed; the symlink branches are capability-gated and
will execute automatically on a host where `os.symlink` is available.

## Serial run receipts

| Run | UTC | PID | exit | raw stdout SHA-256 |
|---|---|---:|---:|---|
| 1 | `2026-09-17T01:28:37.209809+00:00` | `103440` | `0` | `ab338daae66c27cfffba727ee8c7017a436cc159eb7793166354eda3f8939cd8` |
| 2 | `2026-09-17T01:28:40.728930+00:00` | `58648` | `0` | `0c938479c453bd1f9fe3da5fe649b917f0b6dcb76923e5fb59ef79e9d7a6c44b` |

Exact stdout, PID, UTC and exit receipts are in `raw/`; the machine-readable
summary is `raw/run_hashes.json`.

## Scope boundary

This is an independent, offline software test of the supplied receipt and
replay-state contract. It does not contact OCSP/CRL/TSA, prove an external
authority signature, establish a production trust root, grant formal credit,
publish a candidate, or validate any physical/engineering claim.
