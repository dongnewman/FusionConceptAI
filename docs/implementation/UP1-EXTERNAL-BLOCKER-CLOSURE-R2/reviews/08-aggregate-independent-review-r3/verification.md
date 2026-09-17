# Verification receipt

## Fresh commands

1. `python -B test/up1_external_closure_r2/aggregate_gate/test_aggregate_gate.py`
   — exit `0`, `22/22` tests passed.
2. Independent R3 attack driver — `python -B -` — exit `0`; temporary ledgers
   were created only below this review directory and removed by the driver.
3. Two separate Python `-B` child processes consumed the same baseline and
   fabricated-state inputs, including ledger-backed prior validation and noop
   overlay checks. Both exits were `0`; semantic outputs and hashes matched.

## Replay

```text
process A exit=0 stdout_sha256=a534fe0c6016d2e2b902d0be15fbd0c20a9bc188cc7d8f0bec898796b0ec97ff
process B exit=0 stdout_sha256=a534fe0c6016d2e2b902d0be15fbd0c20a9bc188cc7d8f0bec898796b0ec97ff
semantic_equal=true
```

The replay also showed both fabricated prior attacks failing closed under the
ledger-backed API; their detailed concurrent/state-attack receipt is retained
in `raw/attack_summary.stdout.raw`.

## Source and contract hashes

```text
aggregate_gate.py 1d89fc9d31fb31f8d223f595bb2b9f7c66c7b54bb8db42b6db38b162c4d2854d
test_aggregate_gate.py 33fde502cdd7c12c0879bdc81fffadd621efb6d30c67f89fdcfadac8db5a1a5b
aggregate manifest a077f8b4c9760689742bdcd2f93f275952d2ef0e95f23075d198b6cfd3614aaa
interface contract 857dc027eb53569a5fd3233f8fe113ac9498a37e7a63579685c2ca4e7487a85e
gate ceiling 81cae273c2395dda210df53cecd2435561676c9ee21d34817894383d96035df6
```

Independent Python SHA-256 recomputation of all manifest inputs and retained
raw streams passed; exact values are recorded in `manifest.json`.

`raw/process_metadata.stdout.raw` records a fresh wrapper PID, parent PID, UTC
start/end, numeric exit, and raw stdout/stderr hashes; it also records the
ledger-driver cleanup and two-process replay status.

## Safety

No Julia, DESC, solver, mesh, provider, external operation, or heavy lane was
run. The aggregate ledger was treated solely as software bookkeeping. No
production/test source was edited.
