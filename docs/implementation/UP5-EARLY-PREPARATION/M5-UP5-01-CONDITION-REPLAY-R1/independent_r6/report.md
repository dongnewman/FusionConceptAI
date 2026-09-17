# UP5-01 ConditionalEGraphConditionEnvelope R6 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for the R6 static contract handoff; NO-GO for the next runtime or formal
UP5 gate.** The three evaluation reference collections now materialize typed
`String[...]` vectors before `sort!`; no direct `sort(generator)` remains in
the source. The focused test supplies out-of-order multi-item missing, unmet,
and contradiction references and asserts canonical ordering, and it directly
rejects an overlap between missing and contradiction references. The 18-vector
loop and exact exercised-set/cardinality assertions remain intact.

The ceiling remains `contract_only / screen_only`, with `accepted=false` and
`no_publish=true`. No UP5, numerical, physical, provider, solver, search, or
R01-R10 credit is issued.

## Scope and R5 lineage

Reviewed read-only:

- `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json`
- `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py`
- R6 `agent_local_r6/report.md`, `manifest.json`, and raw QA output
- R5 receipt under
  `runs/agent_local_up5_condition_replay_contract_matrix_20260918_r5/`

The preserved R5 receipt is a real Julia `MethodError` at source lines
134--136: `sort(::Base.Generator...)`; it exited `1` after `3 passed / 1
errored` in `1.0s`, with `hashes_unchanged=true` and equal pre/post inputs.
Its raw output, stderr, and hash files remain preserved. R6 current hashes
match the R6 manifest. No product or test file was changed by this review;
only this independent archive is added. Julia/DESC were not run. No commit
was created.

## Static findings

### Materialized canonical sorting

The implementation contains exactly these repaired forms:

```julia
sort!(String[String(x) for x in missing_refs])
sort!(String[String(x) for x in unmet_refs])
sort!(String[String(x) for x in contradiction_refs])
```

The QA direct-generator scan passes, and a source-wide inspection finds no
other `sort`/`sort!` receiving a generator directly. Existing catalog sorts
use `collect(xs)` and therefore are already materialized. The scan excludes
the valid `collect(...)` and typed-vector forms and produces no current false
positive.

### Ordering and overlap negatives

The test constructs each of the three reference classes from
`("zeta", "alpha", "middle")` and asserts the canonical tuple
`("alpha", "middle", "zeta")`. It also constructs a `:fail_closed`
evaluation with `("overlap",)` in both missing and contradiction references
and asserts `ArgumentError`. These are direct constructor calls, not fixture
markers.

### Frozen vector coverage

The R5 18-vector tuple is retained. The real loop pushes every vector into
`exercised_vectors`, dispatches the real evaluator/replay/cache/receipt/result
seams, and asserts exact set equality plus length 18. R6 QA retains the
per-vector source-presence check and the real seam markers.

## Evidence and next gate

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
status=pass, negative_vector_count=18
Julia/DESC: not run
```

The next gate is one serialized fresh-process focused Julia run. Static QA and
the R5 failure receipt do not constitute runtime, numerical, physical, or
formal UP5 evidence.

## Current SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20480 | `b45ee915ebfe643c9116a631deb90a8c0693304b515dea552b89bdcd31c5ef89` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 11119 | `0ec87c707823b737c40daa2c9c40f74b90d602222b287d3c9ea9beabff9c6fd3` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 6801 | `4e46e1ecb3933710766a095476a8823f96f41db95e7d0e87cbc056bbe32d7ef5` |
