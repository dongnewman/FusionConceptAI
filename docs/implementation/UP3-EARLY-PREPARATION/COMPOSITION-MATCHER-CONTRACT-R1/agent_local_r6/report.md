# UP3 CompositionMatcher contract R6 — fixture digest repair

Date: 2026-09-18 (Asia/Shanghai).

## Result

R6 repairs the R5 focused-runtime failure in the test fixture helper. The
previous `_d(c)` padded a display label with zeroes and therefore produced
non-hex strings such as `s000...`; `Digest256` correctly rejected them. The
helper now derives each reference with
`M.canonical_hash((tag=String(c),))`, giving a real deterministic 64-character
lowercase-hex digest while preserving distinct references for distinct tags.

The test now statically/runtime-asserts digest length, lowercase-hex validity,
and tag distinction. Existing label-erasure and component/input permutation
plan-hash assertions remain in place. Static QA rejects any reintroduction of
`repeat(...)` digest padding.

## Parent failure being repaired

The R5 receipt
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r5/`
records exit code 1 with `7 passed, 0 failed, 1 errored, 0 broken`, after
`hashes_unchanged: true`. The error arose from `_d("s")` producing invalid
non-hex digest text before the matcher assertions could complete.

## Static evidence and ceiling

**R6 verdict: GO for the static handoff; NO-GO for runtime or formal UP3
acceptance.**

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r6
```

An additional Python-only check passed for the absence of `repeat(`, the
canonical digest helper, and fixture JSON validity. Julia and DESC were not
run by this lane; no runtime result or physical/engineering evidence is
claimed. The maximum state remains `contract_only / prepared`, with
`accepted=false`, `formal_acceptance=false`, and no UP3, B01/B02/B04/B08,
conservation, convergence, engineering, or R01-R10 credit. A different agent
must run the focused Julia process and independently review this slice.

## Current reviewed files

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 21055 | `c5da07f89bb89792c33f3afadd13a8e412a9f3350694f00b73d65a464e3637e4` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 9518 | `1df05362f775cfbb4aa1b1e9af26c298615469b4ed92044fef8e4ac87489f713` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 6276 | `40358b9ab2ac2c7ae8e54b694d48603efe70f0a6f585237e84ac1fb565fe41ed` |
