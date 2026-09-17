# Verification receipt

## Fresh commands

1. `python -B test/up1_external_closure_r2/aggregate_gate/test_aggregate_gate.py`
   — exit `0`, 9 tests passed.
2. Independent attack driver — `python -B -` — exit `0`; it constructs fresh
   inputs and derives the expected fail-closed conditions from the frozen
   contract, not from the author's test module.
3. Independent two-process replay — one fresh Python `-B` parent launched two
   separate Python `-B` child processes over identical baseline input. Both
   child exits were `0`, stderr was empty, and semantic output/hash equality
   was `true`.

## Two-process replay

```text
process A exit=0 stdout_sha256=793b12a8e144aa243d97db70a111d7d2c90af05802f9cf269cea04c8e10c3c63
process B exit=0 stdout_sha256=793b12a8e144aa243d97db70a111d7d2c90af05802f9cf269cea04c8e10c3c63
semantic_hash=4c491c98692979ca7a5446134cfcff689f843ab575bc7b4ff215387050108ce6
semantic_equal=true
```

The separate map-permutation attack is intentionally distinct: baseline replay
is deterministic, but semantically equivalent reordered maps are not
canonicalized (F-05).

`raw/process_metadata.stdout.raw` records UTC start/end, PID, parent PID where
available, numeric exit, and stdout/stderr hashes for the focused wrapper and
both replay child processes. The direct focused run's empty stdout and test
listing stderr are retained separately in `raw/focused_test.*`.

## Independently recomputed source/input hashes

```text
aggregate_gate.py  913fc37358193ab24aeba59a63f27ed4889d8a43b8a44052440d243c1cd2aefd
test_aggregate_gate.py bfe45620f0c1e6e41e489861ba7cdbec1431a4769d4c66e33fdb32c5787d67da
```

The source hash above and all manifest hashes were computed by
PowerShell `Get-FileHash -Algorithm SHA256` after the fresh run. The frozen
input hash is `81e5b0cd15452bc726b85ce23bb19f06a0dd3a5ea2052126c6eaaba655aebf30`.

## Safety/cleanup

No Julia, DESC, solver, mesh, provider, or external operation was run. No
scratch files were created; only immutable raw streams and review receipts in
this directory are retained. Pre-existing dirty worktree paths were not
edited.
