# UP1 R3 atomic prototype independent test

Decision: `pass_limited`. This is an offline software-prototype test only;
`formal_credit=none`, `authority_credit=false`, `no_publish=true`. No external
acceptance, trust, authority, or parent-goal closure is inferred.

## Frozen scope and integrity

At `2026-09-16T23:11:14.1671684Z`, the implementation, focused test/fixture,
and `04-atomic-contract-repair-r1` schema/validator inputs were hashed. The
complete list is in `frozen-input-hashes.txt`. The post-run hashes were
identical byte-for-byte. No implementation, test, schema, or `05` evidence
path was edited.

## Fresh focused runs

Exact command, run serially twice:

```text
python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p test_*.py
```

| run | UTC | PID | exit | result |
|---|---|---:|---:|---|
| 1 | 2026-09-16T23:11:30.2052582Z | 21104 | 0 | 9 tests, OK |
| 2 | 2026-09-16T23:11:40.8239701Z | 34116 | 0 | 9 tests, OK |

The only emitted diagnostic was the existing `jsonschema.RefResolver`
deprecation warning. Raw outputs and SHA-256 records are under `raw/`.

## Independent temporary-directory audit

Fresh PID `15704`, UTC `2026-09-16T23:13:25.946512+00:00`, exit `0`, checked
18/18 assertions. Coverage included strict duplicate-key/nonfinite/invalid
UTF-8/unsafe-number rejection; packet-owner domain and preimage digest;
TEST_ONLY Ed25519 verification; CAS raw-byte/hash/size/atomic-temp cleanup;
valid and duplicate/inverse-negative EHP-03 graph checks; valid-not-executed
and wrong-context-negative EHP-04 checks; and invalid-bundle decision plus
`no_publish`/`formal_credit`/`authority_credit` controls. Temporary directories
were removed by context-manager cleanup. No credentials or external keys were
created.

The first hand-built audit vector (PID `55568`, UTC
`2026-09-16T23:12:44.876632+00:00`) reported 16/18 only because the harness
left stale EHP-03 edge digests and omitted the shared EHP-04 context field.
This was a test-vector construction error, corrected and rerun above; it is
not an implementation failure. Its raw observation is not used as the pass
receipt.

## Safety and residual process audit

No network, external send, AD/S3, Julia, DESC, solver, or trust-store access
was used. Final snapshot at `2026-09-16T23:16:02.4550160Z` found no Python
processes and no owned temporary CAS directories. An unrelated pre-existing
`C:\Users\Newman\AppData\Local\Temp\up1-r3-replay-evidence` directory was
observed (created `2026-09-16T19:11:11.3288482Z`) and deliberately left
untouched.

## Boundary

This independent result is `pass_limited` for the prototype package only. It
does not upgrade the package from `prototype_pass_limited`, does not provide
formal or authority credit, and cannot make an `accepted_all` internal path
publishable.
