# M5-SEARCH-R2 checker test R1

Scope is limited to the frozen synthetic checker test owner and the
append-only evidence directory. No search, Julia, solver, provider, mesh,
physical lane, authority artifact, gate artifact, or persistent fixture was
created.

## Runs

The exact command was run twice:

```text
python -m unittest discover -s test/m5_search_contract_r2 -p test_check_contract.py -v
```

Both runs were deterministic at the test-result level: 10 top-level unittest
methods, 43 frozen negative-vector subtests, 0 skipped, 5 failures, exit 1.
The per-run stdout/stderr bytes, PID, UTC interval, exit code, test hash,
implementation hash, and raw hashes are recorded in `run-1.receipt.json` and
`run-2.receipt.json`; raw streams are `run-1.stdout.raw`,
`run-1.stderr.raw`, `run-2.stdout.raw`, and `run-2.stderr.raw`.

Implementation under test SHA-256:

```text
76ff4f180bcf1748c1096e784c5866fdc21c3b3a24704c4f4111d966c540c2c4
```

Test file SHA-256:

```text
2dde5ee481400a10278ed2874debdcd8a7a7be5bc52d20e6685b3c0d517b2c43
```

## Failure disposition

These are implementation findings, not test-only repairs:

* Positive `contract_machine_closure` cannot reach exit 0 because the scan
  input-bundle digest is nested in the bundle hash it must equal (`scan_bundle_hash`).
* `P1-01-02` and `P1-01-03` do not reject foreign `owner_id` or stale
  `version` metadata.
* `P1-03-02` reports `envelope_content_join_mismatch` for a null accepted-gate
  raw stdout reference instead of the frozen `gate_missing_or_unbound` /
  `not_executed` boundary.
* `P1-03-03` accepts a stale historical accepted gate because no R2 freshness
  or closure identity rejection is applied.

The 43-vector parameterized test itself is complete; the five failures above
are preserved as evidence for the implementation owner. No implementation
file was modified by this test task.
