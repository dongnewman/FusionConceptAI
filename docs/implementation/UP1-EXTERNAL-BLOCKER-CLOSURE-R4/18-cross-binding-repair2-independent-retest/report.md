# UP1 R4 cross-binding repair 2 — independent retest

## Ruling

**`pass_limited` for the frozen offline integration seam.** The second repair
passes both serial runs of the complete R4 integration package. This is a
local contract result only: it grants no external authority, formal credit,
publication permission, T0/T1/T2 credit, or unchanged parent-goal closure.

## Frozen scope and command

The current orchestrator and the current integration tests were hashed before
and after execution. No file under `tools/` or `test/` was modified. The only
new files are in this directory. The exact command, run metadata, source
hashes, exit codes, and output hashes are in `run_manifest.json`.

```text
python -B -m pytest test/up1_external_closure_r4/integration -q
```

The package collected and passed **33 tests** per run: the 15-field
cross-binding parameterized matrix plus its A/B nested-conflict,
missing/unknown-stage, and empty-run cases, together with the existing
seven-stage integration contract tests.

## Serial evidence

| run | PID | UTC | exit | result | stdout SHA-256 | combined SHA-256 |
|---:|---:|---|---:|---|---|---|
| 1 | 32840 | 2026-09-17T02:39:22.783849Z → 2026-09-17T02:39:23.536875Z | 0 | `33 passed in 0.25s` | `0e0f092099badf2686b2dd847d577d74fa5b0433f239eb27b79bc2b3c061fb2d` | `0e0f092099badf2686b2dd847d577d74fa5b0433f239eb27b79bc2b3c061fb2d` |
| 2 | 2888 | 2026-09-17T02:39:23.539861Z → 2026-09-17T02:39:24.338994Z | 0 | `33 passed in 0.34s` | `a34518a5c9357b161b9c698b6f54ce339837b1d77d7277307c612f6cb6f3dc24` | `a34518a5c9357b161b9c698b6f54ce339837b1d77d7277307c612f6cb6f3dc24` |

Both stderr streams were empty (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). Raw stdout/stderr/combined output, PID, UTC, and exit files are under `raw/`.

## Adversarial coverage

- Every field of the complete binding tuple is contradicted by a foreign
  nested receipt value. Each case is hard `fail_closed`/`rejected_all` and
  leaves the conflicted public binding field as `None`.
- The three fields that failed the previous retest now remain explicitly
  unset: `packet_digests is None`, `scope is None`, and
  `result_digest is None`. The independently computed aggregate receipt
  digest is exposed as `aggregate_result_digest`, so it cannot overwrite the
  observed binding digest.
- The original A/B nested `candidate_id` conflict remains hard and preserves
  raw stage receipts, receipt references, and stage hashes.
- A missing required stage plus an unknown stage returns hard contract
  failure while preserving the unknown stage receipt.
- An empty orchestrator request creates all seven typed-absent stages and
  returns `terminal_deferred`, with `t0_executed`, `s3_executed`, network, and
  runtime execution all false.

## Source receipts

The before/after source hashes are identical (`source_hashes_unchanged=true`):

```text
tools/up1_external_closure_r4/integration/orchestrator.py
  bytes=33233 sha256=baaac7f7aa162d07777f0210ae789ea60c0f9cd3cbe8e38228f7ed8c0e88da2d
test/up1_external_closure_r4/integration/test_cross_binding_repair_retest.py
  bytes=6004 sha256=443ad1958ba1eaf8257229c775a2ed5109aecbd9d7a428e3a55911a7ae331440
test/up1_external_closure_r4/integration/test_integration.py
  bytes=12405 sha256=9e41b006f28dbc72b1d1725414c4e1bd173cbbdd2d029030a243e3cc661b6d30
```

No network, heavy lane, Julia/DESC, T0, S3, or runtime execution was used.
