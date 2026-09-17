# UP1 R2 revocation/time/replay independent review R2

- review revision: `03-revocation-independent-review-r2`
- group: `W2-R2-03-revocation-time-replay`
- reviewer: independent Luna worker (`gpt-5.6-luna`, high)
- verdict: `rework`
- claim ceiling: `TEST_ONLY non_evidence` / contract-software preparation only
- write boundary: only this review directory was written; implementation, tests and prior 03/repair evidence were read-only

## Fresh process evidence

Fresh focused run:

```text
python -B -m pytest -q test/up1_external_closure_r2/revocation_time_replay/test_revocation_time_replay.py
```

Observed `6 passed in 0.33s`, exit `0`; raw output and process metadata are retained in `raw/pytest.*.raw` and `run_receipt.json`. The independent attack harness was run in a separate `python -B` process and spawned separate `-B` CLI processes for replay and concurrency. Its raw output is `raw/attack_harness.stdout.raw`. No network, OS wall-clock decision, Git time, mtime, trust-store, Julia, DESC, solver, mesh, provider or external operation was used.

## Findings requiring repair

### R2-01 — HMAC-valid ledger accepts duplicate nonce and idempotency entries (P1)

`PersistentReplayLedger._check_state()` derives indexes by appending rows and overwriting duplicate idempotency keys (`core.py:292-308`). It only rejects an identical four-field tuple, not a nonce reused in one scope or an idempotency key appearing in multiple rows. A deliberately HMAC-valid ledger with duplicate idempotency rows and another with duplicate nonce rows both reached `valid_for_declared_scope` in the independent harness (`duplicate`, `duplicate_nonce`). This violates the required ledger index/entries consistency and leaves ambiguous replay history.

Required fix: enforce unique `(scope, nonce)`, unique `idempotency_key`, unique sequence per scope, strict contiguous order, and string/format validation for canonical/result digests before deriving indexes. Add HMAC-valid malformed-state negatives (not only stale-tag tampering) and require them to return `replay_ledger_invalid`/exit 2.

### R2-02 — HMAC key provenance is caller-path controlled and unlabeled (P1)

The key is generated/read from `self.path.with_name(self.path.name + ".key")` (`core.py:242-264`), while `self.path` is derived from the CLI `--ledger` argument (`cli.py:18-23`). The harness confirmed the key is co-located with a caller-selected ledger path. There is no pinned secret provider, key fingerprint/policy, owner/permission verification, or independent provenance; an actor able to choose/control the ledger directory can choose or replace the key and forge an HMAC-valid state. The key/envelope also carry no `TEST_ONLY`/`non_evidence` metadata despite the stated fixture-only boundary.

Required fix: inject a fixed test-only key through a non-payload, non-ledger-controlled provider (or an explicit sealed key fixture), pin and hash the key source, reject symlink/reparse/permission ambiguity, bind the key fingerprint and labels in the receipt, and ensure production authority cannot be inferred from this fixture key. Test attempts to set key material/path through payload and CLI configuration separately.

### R2-03 — strict parser failures have the wrong CLI exit/receipt semantics (P2)

`parse_json_strict()` correctly rejects duplicate keys and non-finite constants, but `cli.py:24-30` catches its `ReceiptInputError` in the generic exception handler and emits `program_exception` with exit `1`. The harness observed both duplicate JSON and `NaN` CLI inputs as `result=fail_closed` but `error_code=program_exception`, exit `1`, with no `status`, `TEST_ONLY` or `non_evidence` fields. The component contract says malformed/fail-closed input is exit `2`; exit `1` is reserved for an actual program exception.

Required fix: handle `ReceiptInputError` separately as machine-readable fail-closed exit `2`, preserve complete output labels/status, and reserve exit `1` for unexpected exceptions. Add raw CLI tests for duplicate nested keys, NaN/Infinity, invalid UTF-8 and unknown fields.

### R2-04 — external availability is not type-strict (P2, TM-07)

Revocation absence is detected only by `rev.get("available") is False` (`core.py:142-145`). A supplied `available: "false"` is treated as available and a fully populated CRL then returns valid; the harness observed `revocation_available_string` as `valid_for_declared_scope`. The same issue can affect `nonce_required` because it is used by truthiness rather than exact boolean validation. This keeps unavailable and supplied-good semantics ambiguous.

Required fix: if `available` is present require an actual boolean; accept only explicit `True` as available, map explicit `False`/absent external source according to the frozen absence contract, and reject string/null/number values. Require boolean types for all revocation policy flags.

### R2-05 — ledger record field validation is incomplete (P2, TM-09/TM-10/TM-11)

`_check_state()` verifies row shape but does not type-check `canonical_digest` or `result_digest`, permits `bool` as an existing ledger sequence (`isinstance(True, int)`), and does not independently verify digest format (`core.py:296-306`). HMAC protects bytes but does not make malformed authenticated state semantically valid. Required index and entry semantics must reject these states before replay decisions.

Required fix: reject booleans, non-strings, malformed SHA-256 values and inconsistent sequence/nonce/idempotency rows; add authenticated malformed-ledger fixtures and independent expected classifications.

## Controls that passed

- First commit returns exit `0`; same-key/same-digest retry is intentionally `replayed`/fail-closed per the repaired component contract; same nonce/new key is rejected; next contiguous sequence commits.
- Two concurrent CLI processes against one ledger produced exactly one commit and one replay rejection; the shared lock/CAS path works for this bounded test.
- State mutation with a stale HMAC returned `replay_ledger_invalid`/exit `2`.
- Strict profile, boolean `test_only`, source/source_version, scope, optional time, duplicate/unknown object fields and finite window tests passed.
- OCSP valid chain accepted and bad responder chain rejected; CRL unavailable/revoked/unknown/stale controls remain correctly separated.
- Current source hashes in the prior repair manifest and all listed repair raw hashes independently recompute and match. This is integrity only; it does not close the findings or grant authority.
- No OS wall-clock access or network client is used for trust decisions; `time.monotonic()` is limited to lock timeout handling.

## Acceptance after repair

Create a new review revision after fixing R2-01 through R2-05. It must include HMAC-valid duplicate nonce/idempotency/sequence malformed-state negatives, key provenance and label checks, parser-error exit-2 evidence, fresh concurrent two-process raw streams, complete manifest/hash/cleanup closure, and CRL/OCSP chain cases. Do not amend the prior repair receipt. The overall external authority, UP1, B00/B04, engineering, physical and R01-R10 gates remain open and receive zero credit from this fixture package.
