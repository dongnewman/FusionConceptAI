# Verification receipt

## Fresh-process commands

1. `python -B test/up1_external_closure_r2/aggregate_gate/test_aggregate_gate.py`
   — exit `0`, `17/17` tests passed.
2. Independent attack driver — `python -B -` — exit `0`; it imports only the
   implementation API and independently constructs valid/invalid input objects.
3. Two separate Python `-B` child processes consumed the same frozen baseline
   and the same fabricated prior-state attacks. Both exits were `0`; baseline
   semantic bytes and hashes matched exactly, and both state-bypass outcomes
   matched exactly.

## Two-process semantic replay

```text
process A pid=64728 exit=0 stdout_sha256=8de7a33562ae8b45942996907db94ac69e9dab933cde6bac66b87de1e526f4a5
process B pid=21612 exit=0 stdout_sha256=cb5df65a0ae3eb005f59f750854d6c7440fe4e58bf418f9bdf886fc93132842b
stderr_sha256 (both)=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
semantic_hash (both)=e6a62d124666eae88a16994a16d3218720b304fb2da9d03e44dbc5f22a54b167
semantic_equal=true
semantic_hash_equal=true
```

Different stdout hashes are expected because each child includes its PID and
the replay metadata; the semantic payload/hash is equal.

## Source and frozen-input hashes

```text
aggregate_gate.py 524f706ca666e07ec0445fb89ea0d7702e47f908979deebaa4547765ce3def86
test_aggregate_gate.py 8fb4168dd88280fa66eec24325d9f3aa0ee22ee58de0d7aee770bfdc27428d39
aggregate input manifest b6d998ec4ede86194aab838eacadcf9a2efadc66de893fe223b1847f31817bf0
review protocol 650a8dfc292088c7db7a33ef608035815a3b34fc0570faeddbbcd669354c6cf2
interface contract 857dc027eb53569a5fd3233f8fe113ac9498a37e7a63579685c2ca4e7487a85e
gate ceiling 81cae273c2395dda210df53cecd2435561676c9ee21d34817894383d96035df6
```

Independent Python SHA-256 recomputation of every manifest input and retained
raw stream is recorded in `manifest.json` and passed after writing.

`raw/process_metadata.stdout.raw` records UTC start/end, PID, parent PID,
numeric exit, and stdout/stderr hashes for the focused run and both replay
children. The attack driver had exit `0` and no stderr; its compact outcome
table is retained in `raw/attack_summary.stdout.raw`.
