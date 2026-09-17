# M5-C manufactured conditional e-graph performance profile R2

Status: `screen_only / performance_diagnostic / review_pending`.

This is a test-only profile of the frozen manufactured adapter.  It does not
modify the adapter or the shared e-graph engine, does not create a candidate,
and grants no UP5, B00/B04, provider, physical, search, or parent-goal credit.
All Julia invocations used `--startup-file=no --history-file=no`, ran serially,
and were stopped at an external 55 s or 59 s deadline.  No DESC, S3, solver,
network, or heavy lane was used.

## Frozen inputs

| input | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | 23892 | `7A1F52A96A7A79061B1E4BDB0FC1B7B41DE5E45266D0AC4726A50502A4DC6500` |
| `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl` | 14243 | `E0ED925A77F65AA045586F3C8DD78B2ACFE8E023B29F1F95BBA1F246B61A9355` |
| `M5-EGRAPH-R1/test_execution_r1/manifest.json` | 1339 | `BBCD735E84A97BDE0FE2381E92450808A2E5BE3DEF98537520F4297BB992274A` |
| `M5-EGRAPH-R1/test_execution_r2/manifest.json` | 528 | `BBEA4FF12167C15F4E8B2A41C580274EE9B13D464D585D6728141540C5895CF5` |
| `M5-EGRAPH-R1/test_execution_r3/manifest.json` | 1404 | `3BE22F97174FA879EB2905A292854CBC9CDDABC9525BB23F6B3D3A0D6643FF30` |

The old R1 parse failure, R2 wrapper collection failures, and R3 fixture
failure remain immutable historical inputs.  R3 specifically reports the
prior 20-minute test-only performance gap; this profile supersedes none of
those failure receipts.

## Measurements

The first call in a fresh process includes Julia method compilation and
manufactured upstream construction.  `source_hash` is the cold canonical
program hash.  `prepare_condition_catalog` and `prepare_rhs` are direct
adapter preparation calls.  `prepare_rewrite_set` did not complete before the
deadline.  `allocations` are Julia `@timed` byte counts and `gc_ns` is the
reported GC time.  For the graph engine, `nodes=programs` and
`edges=trace_steps` are the only available typed usage counters; no separate
edge collection exists in this adapter.

Observed successful stages:

- include: 0.99–1.36 s, about 36.1 MB;
- upstream first compile + build: 10.27–13.17 s, about 471.3 MB;
- upstream warm build: 4.9–8.2 ms, about 8.9 MB;
- condition catalog: 7.47–11.94 s, about 158.4 MB;
- RHS construction: 75–133 ms, about 1.0 MB;
- cold canonical source hash: 25.64–26.37 s, about 9.25 GB.

The 55/59 s runs stopped before a complete rewrite-set, saturation, query,
replay, validation, or budget-result receipt.  Those stages are therefore
`not_measured`, not zero and not successful.  The probe's first implementation
also had a test-harness-only global-name collision in `rules_parts` (exit 1);
its stderr is retained.  The collision was corrected in the probe file after
capture, but was not rerun after the required Julia stop.

## Bottleneck decision

The strongest measured bottleneck is cold canonical serialization/hash
compilation: one call consumed 25.6–26.4 s and 9.25 GB allocations.  The next
unresolved bottleneck is cold rewrite-set construction; it remained inside the
same fresh process after 7.5–11.9 s catalog compilation and did not emit a
stage receipt by 59 s.  The historical 20-minute interruption is therefore
consistent with cold compilation and allocation amplification, but this run
does not establish saturation complexity.

Recommended next bounded action is a separately authorized performance repair
or a precompilation/measurement design that preserves canonical semantics and
the screen-only boundary.  It must first make rewrite-set construction emit a
bounded receipt, then measure saturation budgets 2/3/4/8, followed by query,
replay, and validation.  No production optimization is authorized by this
diagnostic package.

## Evidence and cleanup

Raw stdout/stderr, PID, UTC start/end, deadline, exit classification, bytes and
SHA-256 are listed in `manifest.json`.  Timeout outputs are retained as
`human_interruption`; the rules-parts harness error is retained as
`program_exception`.  No task-owned scratch or cache was deleted, and no
production source or existing test was changed.
