# M5-SEARCH-R2 checker test R2

This rerun used the unchanged synthetic test file and the repaired checker.
No implementation or test source was modified in R2, and no search, Julia,
solver, provider, mesh, physical lane, authority artifact, gate artifact, or
persistent fixture was created.

Command, run serially twice:

```text
python -m unittest discover -s test/m5_search_contract_r2 -p test_check_contract.py -v
```

Both runs passed:

* 10 top-level unittest methods;
* 43 frozen negative-vector subtests;
* 0 failures;
* 0 skipped;
* exit code 0.

The per-run raw streams, PID, UTC start/end, exit code, byte lengths, SHA-256
values, test hash, and implementation hash are in `run-1.receipt.json` and
`run-2.receipt.json`.

Implementation SHA-256:

```text
fb8496391e7f6c539d6a100a08ad1d7a95600a701a30f6157c57098278011bf2
```

Unchanged test SHA-256:

```text
2dde5ee481400a10278ed2874debdcd8a7a7be5bc52d20e6685b3c0d517b2c43
```
