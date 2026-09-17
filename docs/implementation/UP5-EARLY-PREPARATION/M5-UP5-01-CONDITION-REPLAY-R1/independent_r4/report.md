# UP5-01 ConditionalEGraphConditionEnvelope R4 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for the R4 contract-only static handoff; NO-GO for the next runtime or
formal UP5 gate.** The repaired source contains the exact parenthesized tuple
join at line 423, and a complete manual source scan found no other
unparenthesized generator followed by an extra call argument. The R4 static QA
checks that exact repair, source delimiter/string boundaries, module closure,
and the source-wide generator pattern; it passes without a false positive on
the current valid generator comprehensions. The test still enumerates and
executes all 18 frozen negative-vector branches against real isolated seams.

The ceiling remains `contract_only / screen_only`, with `accepted=false` and
`no_publish=true`. No UP5, numerical, physical, provider, solver, search, or
R01-R10 credit is issued.

## Scope and R3 lineage

Reviewed read-only:

- `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json`
- `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py`
- R4 `agent_local_r4/report.md`, `manifest.json`, and raw QA output
- R3 receipt under
  `runs/agent_local_up5_condition_replay_contract_matrix_20260918_r3/`

The preserved R3 receipt is a real Julia `ParseError` at source line 423 for
`join(_encode(y) for y in x, ";")`; it exited `1`, and all four R3 input
hashes are unchanged pre/post. The R4 manifest's current hashes match the
current bytes exactly. No product or test file was changed by this review;
only this independent archive is added. Julia/DESC and all runtime backends
were not run. No commit was created.

## Static findings

### Parse repair and generator scan

Line 423 now reads:

```julia
x isa Tuple && return "(" * join((_encode(y) for y in x), ";") * ")"
```

The corrected form is explicitly required by QA. Its delimiter scanner ignores
Julia strings and comments and reports balanced delimiters; the module starts
with its documentation string and ends at the module `end`. A source-wide
inspection of every `for` comprehension found only valid forms: standalone
`Tuple`/`sort` generators, generators nested in tuple arguments, and the
parenthesized `join` generator. The QA regex returns no risky line and does
not flag those valid forms. The exact corrected-line assertion closes the
known nested-call case represented by the R3 failure.

### Negative-vector execution wiring

The fixture contains exactly 18 vectors. The test iterates over the frozen
vector tuple and has a real branch for every vector: missing condition; seven
typed-axis mismatches; contradictory availability; stale and foreign tokens;
tampered trace; foreign registry/rule/source; budget mismatch;
evaluation-hash mismatch; and incomplete-not-inequality. Each branch calls
`evaluate_conditions`, `replay_merge`, validators, constructors, or the
incomplete result chain as applicable and asserts the expected status/hash or
zero-merge invariant. The static QA checks the executable loop and seam-call
markers, not merely vector names.

## Evidence and next gate

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
status=pass, negative_vector_count=18
Julia/DESC: not run
```

The next gate is one serialized fresh-process focused Julia run followed by
independent runtime review. Static QA and the R3 parse failure must not be
used as runtime, numerical, physical, engineering, or formal evidence.

## Current SHA-256

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | `b0edd4d90fd38f38c9f13d7035b99cbdfec150ac6c97baf78bd1f3aa5835372c` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | `a650f192a9ec172ff807118f85e7c32bf3a7fa1f97468203939760b207ebce70` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | `6a1c4368fb3101d07217df354341a48a45ceb90370f57e524a4385f58c1f16fd` |
