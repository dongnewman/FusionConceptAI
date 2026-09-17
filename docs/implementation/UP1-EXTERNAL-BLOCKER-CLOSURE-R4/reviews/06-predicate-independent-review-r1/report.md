# UP1 R4 — predicate independent review R1

## Decision

Overall: `pass_limited`.

The frozen production predicate paths are exercised by an independent test-only
harness and transparent runtime traps. The evidence supports the bounded
claim `prototype_test_only`; it does not mint external authority, formal
credit, or publication permission.

No P0, P1, or P2 `fail_limited` finding was observed. The P1 R22 wire
limitation and the host-dependent symlink capability are retained as explicit
limitations, not silently promoted to evidence.

## P0 — production dispatch and freeze: `pass_limited`

- `source_freeze_audit.stdout.raw.json` reports all four frozen `after` hashes
  match and `production_tools_changed: false` in the source freeze. The
  production bundle hash is
  `5E7E0CE502C378EE20BF19B12603BE30866BBCCD623D22E0470DD7F3B0354EC1`.
- The contract audit reports `count_26_of_26=true`,
  `unique_input_sha256_26_of_26=true`, and exact expected-code,
  expected-decision, and runtime-function matches for all 26 vectors.
- The transparent-trap probe reports 9/9 target dispatches, exactly once per
  target, with delegation to the original production function:

  | vector | production function | actual code | decision |
  |---|---|---|---|
  | R02 | `validate_packet_order` | `PACKET_ORDER_MISMATCH` | `rejected_all` |
  | R03 | `validate_canonical_exclusions` | `CANONICAL_EXCLUSION_NAME_INVALID` | `rejected_all` |
  | R04 | `validate_set_receipt_bundle_id` | `SET_BUNDLE_ID_MISMATCH` | `rejected_all` |
  | R05 | `validate_set_receipt_request_id` | `SET_REQUEST_ID_MISMATCH` | `rejected_all` |
  | R06 | `validate_set_receipt_packet_digests` | `SET_PACKET_DIGESTS_MISMATCH` | `rejected_all` |
  | R07 | `validate_shared_binding` | `PACKET_SHARED_BINDING_MISMATCH` | `rejected_all` |
  | R24 | `validate_security_and_decision` | `no_failure_code` | `terminal_deferred` |
  | R25 | `validate_security_and_decision` | `no_failure_code` | `accepted_all` |
  | D01 | `validate_decision_consistency` | `DECISION_DISAGREEMENT` | `rejected_all` |

  The probe raw receipt is
  `raw/predicate_instrumentation.stdout.raw.json` (SHA-256
  `27E1B0E89D0EF25E70E82BB661D08890CCFE98D8D05A0E9EDF12460E3477BA2B`).

## P1 — decision accounting and known limitations: `pass_limited`

- Both machine receipts contain 26/26 rows, `status=pass_limited`, identical
  vector input hashes, zero expected-code mismatches, zero decision mismatches,
  and `all_no_publish=true`.
- The independent contract audit confirms all 26 results have
  `no_publish=true`, `formal_credit="none"`, and `authority_credit=false`.
  The `R25 accepted_all` row is therefore only an internal acceptance-shaped
  result; it is not external trust or publication credit.
- R22 is deliberately limited: the direct semantic harness uses a clean EHP-04
  payload because the complete wire envelope has a self-referential quarantine
  raw digest. R22 remains `_check_ehp04` → `terminal_deferred` with no failure
  code; this is not a complete external-wire acceptance claim.
- R01/R23 remain on the public parser/schema path; R08/R15/R17/R22 remain on
  their existing production paths. The raw receipts retain these boundaries.

## P2 — reproducibility and host capability: `pass_limited`

- Focused unittest serial run 1: PID `112696`, launch UTC
  `2026-09-17T01:37:19.7604080Z`, exit `0`; `Ran 4 tests ... OK`.
- Focused unittest serial run 2: PID `59536`, launch UTC
  `2026-09-17T01:37:21.8238553Z`, exit `0`; `Ran 4 tests ... OK`.
- Machine receipt serial run 1: PID `97724`, launch UTC
  `2026-09-17T01:37:53.1393606Z`, exit `0`, raw SHA-256
  `898B1ED2B6F81C03D2D0505EA92E66911029F8A1C00BB8DE9DB9396F9FF9EBF7`.
- Machine receipt serial run 2: PID `92988`, launch UTC
  `2026-09-17T01:37:55.1989032Z`, exit `0`, raw SHA-256
  `0153C9AAF880448F0462320EDA1F0582CF69F54CBA727AB105E717FC5B1D39D2`.
- Repair regression: PID `75628`, launch UTC
  `2026-09-17T01:40:14.1687522Z`, exit `0`; `Ran 9 tests ... OK
  (skipped=1)`.
- The verbose symlink probe: PID `29088`, launch UTC
  `2026-09-17T01:40:37.3194041Z`, exit `0`, explicitly records
  `skipped "symlink/reparse probe unavailable on this host: OSError:
  [WinError 1314]"`. This is a real capability skip, not a simulated pass.

The raw/PID/UTC/exit captures and SHA-256 values are enumerated in
`raw_manifest.json`. The review-only audit sources are
`predicate_contract_audit.py` and `source_freeze_audit.py`; no `tools/` or
`test/` file was edited by this review.

## Evidence index

| Evidence | Result |
|---|---|
| `raw/predicate_contract_audit.stdout.raw.json` | 26/26, unique hashes, exact code/decision/function, no publish/formal credit checks |
| `raw/predicate_instrumentation.stdout.raw.json` | 9/9 runtime trap invocations |
| `raw/predicate_receipt_serial_1.stdout.raw.json` | 26-vector machine receipt |
| `raw/predicate_receipt_serial_2.stdout.raw.json` | repeated 26-vector machine receipt |
| `raw/focused_serial_1.stderr.raw.txt` | focused unittest run 1 raw output |
| `raw/focused_serial_2.stderr.raw.txt` | focused unittest run 2 raw output |
| `raw/repair_regression.stderr.raw.txt` | repair suite with one capability skip |
| `raw/symlink_skip_probe.stderr.raw.txt` | explicit WinError 1314 skip reason |
| `raw/source_freeze_audit.stdout.raw.json` | frozen hashes and unchanged production tool |

