# UP1 R4 cross-binding repair — independent retest

## Scope and independence

This is an independent, offline retest of the frozen R4 integration merge
seam. The new test uses only the public `merge_stage_results` entry point and
constructs the former A/B shape directly: one stage carries a binding value
and another stage carries a foreign value nested under
`receipt/ack/binding`. No implementation helper, tool source, network,
Julia/DESC, T0, S3, or runtime lane was invoked. No file under `tools/` was
modified.

The complete tuple exercised is:

```text
candidate_id, source_identity_digest, run_id, request_id, bundle_id,
raw_sha256, bundle_canonical_sha256, packet_digests, quarantine_locator,
quarantine_transaction_id, nonce, sequence, idempotency_key, scope,
result_digest
```

The CAS fields also use their accepted aliases (`cas_path` and
`cas_transaction_id`), and the receipt digest uses
`canonical_receipt_digest`. The adversarial cases assert hard
`fail_closed`/`rejected_all`, no first-value-wins, and preservation of raw
stage receipts and receipt/hash references. Missing and unknown stage cases,
and an empty request through the full seven-stage orchestrator, are covered.

## Command and raw evidence

The full integration package was executed serially twice:

```text
python -B -m pytest test/up1_external_closure_r4/integration -q
```

The runner stored raw stdout/stderr, concatenated raw bytes, PID, UTC start and
finish, exit code, and SHA-256 values under `raw/`; `run_manifest.json` is the
machine-readable index. Both runs used the same command and had zero stderr.

| run | PID | UTC | exit | result | stdout SHA-256 | combined SHA-256 |
|---:|---:|---|---:|---|---|---|
| 1 | 28576 | 2026-09-17T02:32:26.986252Z → 2026-09-17T02:32:27.799371Z | 1 | 30 passed, 3 failed | `4b2346ebe92fa4af6eb52fa458fd34d5efd3a4590795504ebeda493e95f5663f` | `4b2346ebe92fa4af6eb52fa458fd34d5efd3a4590795504ebeda493e95f5663f` |
| 2 | 61584 | 2026-09-17T02:32:27.801612Z → 2026-09-17T02:32:28.614746Z | 1 | 30 passed, 3 failed | `4b2346ebe92fa4af6eb52fa458fd34d5efd3a4590795504ebeda493e95f5663f` | `4b2346ebe92fa4af6eb52fa458fd34d5efd3a4590795504ebeda493e95f5663f` |

The source hashes recorded before and after both runs are identical:

```text
test/up1_external_closure_r4/integration/test_cross_binding_repair_retest.py
  bytes=6004 sha256=443ad1958ba1eaf8257229c775a2ed5109aecbd9d7a428e3a55911a7ae331440
test/up1_external_closure_r4/integration/test_integration.py
  bytes=12405 sha256=9e41b006f28dbc72b1d1725414c4e1bd173cbbdd2d029030a243e3cc661b6d30
tools/up1_external_closure_r4/integration/orchestrator.py
  bytes=32190 sha256=95e185c82b94e59ad5cd905a7dab272531ebe79f29b04f622a5d50acfa73ba45
```

## Independent findings

Thirty tests passed in each run, including the original integration suite,
the A/B nested conflict reproduction, all hard-fail and receipt-retention
checks that reached their assertions, missing/unknown stage rejection, and
the complete seven-stage empty-run `terminal_deferred` behavior.

Three tuple-field cases failed the required `binding[field] is None` rule:

| conflicted field | observed aggregate binding | required |
|---|---|---|
| `packet_digests` | `[]` | `None` |
| `scope` | `{}` | `None` |
| `result_digest` | newly generated aggregate digest | `None` |

The failures are implementation semantics, not test-environment failures:
the aggregate detects the conflicts and returns hard `fail_closed` /
`rejected_all`, but the three conflicted values are normalized or overwritten
before the public binding tuple is emitted. The raw failure output is retained
in both `integration_run_1.stdout.raw.txt` and `integration_run_2.stdout.raw.txt`.

Independent ruling: **FAIL-LIMITED for the cross-binding repair retest.** The
repair is not closed for the complete tuple contract until the three fields
remain `None` on conflict. This result grants no external authority, formal
credit, publication permission, T0/T1/T2 credit, or parent-goal closure.
