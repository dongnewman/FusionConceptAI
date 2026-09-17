# UP1 R4 trust-chain repair independent retest

## Scope and freeze

Luna independently retested the repaired, frozen implementation in
`tools/up1_external_closure_r4/trust_chain/` against the existing 08 suite in
`test/up1_external_closure_r4/trust_chain/test_trust_chain_independent.py`.
No implementation or test file was edited. All new material is confined to
this directory. Python bytecode writes were disabled during execution.

## Serial evidence

The complete frozen suite was run twice serially, with no concurrent run:

```text
python -B -m unittest discover -s test/up1_external_closure_r4/trust_chain -p test_*.py -v
```

| Run | PID | UTC interval | Exit | Result |
|---|---:|---|---:|---|
| 1 | 22568 | 2026-09-17T01:39:35.0236817Z to 2026-09-17T01:39:43.2584634Z | 0 | 13/13 passed |
| 2 | 52712 | 2026-09-17T01:39:57.4013868Z to 2026-09-17T01:40:04.5550736Z | 0 | 13/13 passed |

Raw stdout, stderr, and PID/UTC/exit metadata are in `raw/run_01.*` and
`raw/run_02.*`.

## Repair boundary and attack probes

The previously failing missing-time vector now returns
`status=typed_absence`, `error_code=EVALUATION_TIME_ABSENT`,
`no_publish=true`, and `authoritative=false`. Explicit `None` has the same
typed result. The independent static probe found no forbidden network/store
imports or calls, and no `datetime.now`, `datetime.utcnow`, or `time.time`
wall-clock fallback literals. It also installed a network tripwire while
exercising the missing-time request. The probe was run twice serially:

| Run | PID | UTC interval | Exit | Result |
|---|---:|---|---:|---|
| 1 | 91116 | 2026-09-17T01:41:06.8144804Z to 2026-09-17T01:41:07.0739670Z | 0 | PASS |
| 2 | 97368 | 2026-09-17T01:41:30.0251931Z to 2026-09-17T01:41:30.2054003Z | 0 | PASS |

The frozen suite additionally passed the DER/PEM, root-pin, issuer/chain,
algorithm, detached-signature, and TEST_ONLY boundary vectors. The exact
probe JSON is in `raw/static_attack_probe.stdout.raw.json` and
`raw/static_attack_probe_02.stdout.raw.json`.

## Conservative decision

`INDEPENDENT_RETEST=PASS_LIMITED` and
`TRUST_CHAIN_REPAIR=ACCEPTED_FOR_FROZEN_OFFLINE_SOFTWARE_BOUNDARY`.
The evaluation-time fail-closed gap observed by 08 is closed with no observed
regression in the listed boundaries. This does not establish external trust,
production PKI authority, or publication eligibility: local cryptographic
success remains `unverified`, `authoritative=false`, and `no_publish=true`.

## Frozen hashes

`hashes.sha256.txt` records SHA-256 for the frozen implementation, frozen
test, independent probe, and every raw evidence file. The repaired verifier
hash is:

```text
76A829563AB478BB3926D26FA7C70635C354A64DEE3D7A4EC9FCED402EEEFEB2  tools/up1_external_closure_r4/trust_chain/verifier.py
```
