# UP1 R4 integration independent test

Status: `fail_limited`; formal credit: `none`; `authority_credit=false`;
`no_publish=true`.

This is a bounded independent seam test. It injects local fakes into the
frozen R4 orchestrator and never changes `tools/up1_external_closure_r4` or
any upstream module. It does not contact a channel, trust store, network,
Julia, DESC, T0, or S3.

## Scope and fixed stages

The test covers the seven implementation stages:

```text
authoritative_intake -> trust_chain -> freshness -> source_axis_binding
-> g2_mapping -> environment_closure -> atomic_bundle
```

The trace is asserted to be a single fixed pass and the aggregate preserves
the stage dictionary in that order. Missing or empty input is emitted as
`typed_absent` and normalizes to `terminal_deferred`; no injected adapter is
called for absent input.

The 02 interface matrix currently lists a different planned row order:

```text
atomic_bundle -> authoritative_intake -> source_axis_binding -> g2_mapping
-> environment_closure -> trust_chain -> freshness
```

That discrepancy is intentionally represented by one strict `xfail` test,
not repaired here. It is a contract/implementation deviation and keeps this
review `fail_limited` rather than claiming integration acceptance.

## Checks

The focused suite contains 14 passing checks and 1 strict expected failure.
It covers:

- typed-state precedence: hard invalid/digest/binding outcomes dominate
  absence and unverified observations;
- all-or-reject aggregate decisions, with no partial `accepted_all`;
- per-stage input/output/receipt SHA-256 fields and the full candidate/source/
  run/request/bundle/raw/CAS/nonce/sequence/idempotency binding tuple;
- adapter exceptions and non-mapping returns as
  `typed_program_exception`/`fail_closed`;
- `TEST_ONLY`, `local_observed`, `unverified`, raw `EXTERNAL_ISSUED`, and even
  an injected `externally_verified` label never create authority or clear the
  local ceiling;
- attempts to set `formal_credit`, `authority_credit`, or `no_publish` are
  retained diagnostically and normalized to `none`, `false`, and `true`, with
  `PUBLICATION_LOCK` and fail-closed aggregation;
- forbidden environment/network probes are rejected before adapter execution;
- exact raw bytes reach the atomic seam unchanged;
- no result can claim T0/S3/runtime/network execution.

## Serial replay and raw receipts

Command (run twice serially):

```text
python test/up1_external_closure_r4/integration/run_independent.py
```

Both subprocesses exited `0`; each reported `14 passed, 1 xfailed`. The two
semantic in-process double-run results were byte-for-byte equal, and the
adversarial non-mapping adapter was fail-closed. The command receipt is in
`run_manifest.json`; raw stdout/stderr, PID, UTC, and exit receipts are under
`raw/`.

| run | PID | UTC | exit | stdout SHA-256 | stderr SHA-256 |
|---:|---:|---|---:|---|---|
| 1 | 96264 | 2026-09-17T01:57:07.186023Z → 2026-09-17T01:57:07.937360Z | 0 | `43637dad669488bf7f5a40cc73e84d8e92854228b799dec5da0a0936a6e377b9` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| 2 | 65012 | 2026-09-17T01:57:07.940150Z → 2026-09-17T01:57:08.692872Z | 0 | `30812e1f586dd497ccfaef2b383ef3fe969b9223e1aad6220f4f098cee3347c4` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The stdout hashes differ only because pytest reports per-run elapsed time;
stderr is empty in both runs. The semantic equality assertion is independent
of that process-output timing noise.

## Conservative ruling

The local seam behavior is bounded and conservative for the tested cases, but
this is not external authority, physical evidence, T0/T1/T2 credit, or parent
goal closure. The fixed-order discrepancy above remains an implementation
deviation from the current 02 matrix and must be resolved by the root owner
before any acceptance claim. No implementation files were changed by this
subtask.
