# UP1 R2 revocation/time/replay independent review R1

- review_revision: `03-revocation-independent-review-r1`
- group: `W2-R2-03-revocation-time-replay`
- reviewer: delegated independent Luna worker (`gpt-5.6-luna`, high)
- verdict: `rework`
- claim ceiling: `TEST_ONLY non_evidence` / contract-software preparation only
- write boundary honored: this review directory only; implementation, tests and prior evidence were read-only

## Fresh execution

The author's focused suite was re-run in a fresh process:

```text
python -B -m pytest -q test/up1_external_closure_r2/revocation_time_replay/test_revocation_time_replay.py
```

Observed: `6 passed in 0.24s`, exit `0`. The independent adversarial harness was then run as a separate `python -B` process:

```text
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/03-revocation-independent-review-r1/attack_harness.py
```

Its raw output is `raw/attack_harness.stdout.raw`; stderr is retained as `raw/attack_harness.stderr.raw`. The harness constructs its own fixture and does not import the author's test module or route through an expected-error table. No network, OS clock, Git time, mtime, Julia, DESC, solver, mesh, provider or external operation was invoked.

## Findings

### R1-01 — replay state is caller-resettable and unauthenticated (P1, TM-09/TM-10/TM-11)

`validate()` accepts `replay_cache_snapshot` directly (`core.py:284-292`) and only returns a modified in-memory copy (`core.py:327-353`). There is no durable ledger, snapshot signature/version, atomic compare-and-swap, or source binding. Two independent CLI processes supplied the same empty snapshot and both returned exit `0` / `valid_for_declared_scope` (`raw/attack_harness.stdout.raw`, `TM09_two_process_replay_with_reset_snapshot`). A contradictory `entries` row is ignored because replay decisions read only `nonces`, `sequences` and `idempotency` (`core.py:343-351`); the harness still observed valid. A sequence jump from `1` to `100` is accepted (`core.py:349-351`), so the threat-model “gap hiding” attack has no explicit policy.

Required fix: use a trusted, durable, scope-bound ledger or explicitly reject this fixture as non-replay-capable; bind and validate snapshot version/hash, cross-check every `entries` row against all indexes, reject malformed nested values, make nonce/sequence/idempotency commit atomic, and define/reject sequence gaps. Add a true process-A/process-B replay where B consumes A's committed state, plus reset/conflict negatives.

### R1-02 — duplicate and unknown JSON fields are not rejected (P1, TM-15/TM-20)

The CLI uses plain `json.loads(raw)` (`cli.py:21-24`), which silently keeps the last duplicate key. `core.py` has no public-field allowlists; `payload`, receipt, revocation and trusted-time mappings are copied/queried without unknown-field rejection (`core.py:254-276`, `149-200`, `211-245`). The harness showed unknown top-level and nested fields accepted as valid and a duplicate `sequence` key accepted with exit `0`. Alias collisions (`this_update`/`thisUpdate`, `gen_time`/`genTime`) also silently prefer one spelling (`core.py:159-167`, `215-225`).

Required fix: parse raw JSON with recursive duplicate-key rejection, strict UTF-8 and finite-number policy; enforce exact allowlists at every public/nested boundary; reject conflicting aliases and retain raw/canonical bytes for digest comparison. Add duplicate and unknown-field negatives that prove the attempted value/path in the receipt.

### R1-03 — non-finite freshness/skew values bypass the replay window (P1, TM-08)

`duration_seconds` and `clock_skew_seconds` are converted with `float()` but never checked with `math.isfinite()` (`core.py:277-306`). `NaN` makes `(as_of - issued) > duration + skew` false; `Infinity` makes the window effectively unbounded. Both independently constructed inputs returned `valid_for_declared_scope` in the harness. `_seconds()` also silently converts overflow/non-finite values to zero (`core.py:203-208`).

Required fix: require finite JSON numbers before conversion, reject `NaN`, `Infinity`, overflow and non-numeric values as `fail_closed`, and test all of them through the CLI parser as well as direct validation.

### R1-04 — TEST_ONLY gate is not an explicit, exact gate (P1, TM-06/TM-19)

`_valid_fixture_profile()` defaults a missing `profile` and missing `test_only` to accepted values and uses `profile.startswith("TEST_ONLY")` plus `bool(...)` (`core.py:126-128`). Thus `test_only: "false"`, profile `TEST_ONLY-EVIL`, or omitted `test_only` can reach a valid result; the harness observed the non-boolean case as valid. This violates the contract's “must say TEST_ONLY” and permits fixture-profile ambiguity even though the output claim ceiling remains non-evidence.

Required fix: require `test_only is True` (actual boolean), require the exact versioned fixture profile and exact schema, reject production/unknown prefixes and missing labels, and add missing/false/string/near-prefix negatives.

### R1-05 — typed field and optional time validation is incomplete (P2, TM-02/TM-03/TM-08)

`source` and `source_version` are only checked for non-empty values, not their declared types/shape (`core.py:134-146`); numeric `source` and `source_version` values were accepted after recomputing the digest. Present but malformed `valid_to`/`valid_from` values are converted to `None` and then ignored (`core.py:242-245`); the harness observed malformed `valid_to` as valid. Missing revocation `status` falls through to `revocation_status_invalid` (`core.py:193-200`) although the frozen component contract classifies incomplete external records as typed absence when no contradiction is established.

Required fix: define and enforce receipt/source/scope/version schemas, reject malformed present optional timestamps, and explicitly separate absent/incomplete external records (`typed_absent -> terminal_deferred`) from a supplied invalid/contradictory response (`fail_closed`).

### R1-06 — receipt evidence is not admissible as an independent review receipt (P1, AR-12)

The prior `run_receipt.json` records source/raw hashes and selected PID/UTC values, but lacks the review protocol's required `cwd`, `parent_pid`, interpreter/module versions, fixture/input hashes, candidate binding/four axes, output/exit artifacts, semantic replay fields, process-level two-replay comparison and TEST_ONLY/non_evidence receipt envelope. The raw CLI stdout files append PID/timestamps after JSON, so the complete raw stream is not itself a JSON output artifact. Source and raw hashes do match `evidence_manifest.json` independently, and all eight listed raw files exist; that is integrity evidence only, not a complete independent receipt.

Required fix: create a new revision after repair with frozen source/fixture/protocol hashes, exact argv/cwd/interpreter/module/PID/parent-PID/UTC, numeric exit artifact, raw stdout/stderr and semantic output separately, input/candidate/axis bindings, and two truly independent replay receipts. Do not amend the prior receipt in place.

## Controls that passed in this bounded check

- CRL/OCSP unavailable classified `typed_absent` / `terminal_deferred`; explicit revoked, unknown and stale responses classified `fail_closed`.
- Trusted-time unavailable, digest mismatch and receipt-from-future classified `typed_absent` or `fail_closed` as applicable.
- Same-key/different-digest, nonce replay and sequence rollback controls are present in the focused tests.
- Positive CLI exit is `0`; fail-closed CLI exit is `2`; caught program exceptions are exit `1` (`cli.py:20-30`).
- Source hashes and all raw hashes in the prior evidence manifest independently recompute to matching values.
- Static scan found no network client, OS-clock, file-mtime or trust-store access in the implementation.

These controls do not offset the findings above: the focused tests are implementation-coupled and do not establish production CRL/OCSP/TSA authority, durable replay, B00/B04, UP1, provider, engineering, physical or R01-R10 credit.

## Exact rework acceptance

Re-run from a new review revision only after R1-01 through R1-06 are addressed. The new receipt must include strict duplicate/unknown/non-finite negatives, complete typed field/optional-time negatives, snapshot consistency and durable two-process replay evidence, and all fields in `14-review-protocol/evidence_contract.json`. Any external CA/OCSP/CRL/TSA authority remains outside this fixture package and keeps the overall external gate open.
