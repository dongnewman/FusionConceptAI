# UP3 CompositionMatcher R3 independent repair

Date: 2026-09-17 (Asia/Shanghai).

## Result

R3 is a minimal additive repair on top of the R2 matcher. The previously
referenced `_cmc_failure_key` is now explicitly defined before `_cmc_plan_body`
and is used by both valid-plan and invalid-input plan construction. Its key
contains the complete typed failure identity (`code`, normalized `path`, and
`detail`), while `input.<label>` and `port.<label>` diagnostics are erased from
semantic identity. `_cmc_failure_sort_key` gives deterministic ordering.

The executable test adds direct assertions for repeated-key stability,
label-erasure, and distinction between different typed failures. Static QA
checks helper presence and definition-before-use, in addition to the existing
R2 boundary checks.

## Evidence and ceiling

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r3
```

Julia/DESC were not invoked. The Julia contract test was not run. Shared entry,
task manifest, provider/mesh/solver paths, and physical/numerical lanes were
not changed. Maximum state remains `contract_only/prepared`; no UP3 formal,
B01/B02/B04/B08, conservation, convergence, engineering, or R01-R10 credit is
claimed.
