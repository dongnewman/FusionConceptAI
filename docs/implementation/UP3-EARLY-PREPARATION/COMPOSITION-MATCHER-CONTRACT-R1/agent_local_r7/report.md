# UP3 CompositionMatcher contract R7 — schema and semantic-hash repair

Date: 2026-09-18 (Asia/Shanghai).

## Result

R7 repairs the two independent causes in the R6 focused-run failure without
weakening the matcher’s complete typed-signature checks.

1. The test `_sig` now passes one real canonical `input_schema_hash` to every
   compatible fixture signature. The producer/consumer source and target axes
   may differ as required by the routing rule, while the input schema is
   explicitly shared. `_pair` accepts a distinct consumer schema for a new
   schema-mismatch negative case; the product compatibility check remains
   exact and unchanged.
2. `composition_match_hash` now hashes `semantic_view(x)`, the same canonical
   plan body used to construct `plan_hash`. It no longer hashes the stored
   `plan_hash` field recursively. The test adds a positive equality assertion
   and rejects a tampered stored plan hash through validation.

The cycle fixture was also corrected so its reciprocal edges are genuinely
typed-compatible and therefore reach the intended cycle detector. Ambiguous,
schema-mismatch, and cycle cases now assert their exact failure-code sets.

## Parent failure being repaired

The R6 receipt
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r6/`
records exit code 1 with `36 passed, 7 failed`, runtime 11.9 seconds, and
`hashes_unchanged: true`. The failure set included invalid producer/consumer
schema defaults and the mismatch between construction-time body hashing and
the old `canonical_hash(x)` implementation.

## Static evidence and ceiling

**R7 verdict: GO for the static handoff; NO-GO for runtime or formal UP3
acceptance.**

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r7
```

An additional Python-only check passed for the canonical hash formula, shared
schema fixture binding, exact failure assertions, and absence of padded digest
construction. Julia and DESC were not run by this lane; no runtime result or
physical/engineering evidence is claimed. The maximum state remains
`contract_only / prepared`, with `accepted=false`, `formal_acceptance=false`,
and no UP3, B01/B02/B04/B08, conservation, convergence, engineering, or
R01-R10 credit. A different agent must run the focused Julia process and
independently review this slice.

## Current reviewed files

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 21260 | `aeea3652ac1783ba2acbc8f36d644f3351c3368ae7eabfe5be65ad31af07a867` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 10734 | `1f91105831eb865626023410eb74761d110ef3ae5459b3a2651175ed0e6d56f1` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 6938 | `8528f31a9a28cf93d520876c12d0701a761dfbf64cd6e55b2ba88b7fed8beb2b` |
