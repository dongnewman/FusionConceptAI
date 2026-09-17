# UP3 CompositionMatcher contract R6 — independent static review

Date: 2026-09-18 (Asia/Shanghai). This is a read-only review of the R6
fixture-digest repair. No product/test/fixture/manifest/shared-entry file was
modified, no Julia or DESC was run, and no commit was created.

## Verdict

**GO for the next focused isolated Julia gate; NO-GO for runtime or formal UP3
acceptance.** R6 removes the invalid test-only digest padding that caused the
R5 runtime error, and the prescribed R6 static QA passes. The ceiling remains
`contract_only / prepared / accepted=false / formal_acceptance=false`.

## Static QA

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r6
```

The command was run once in a fresh Python process. Its output is archived in
`static_qa.stdout`; `static_qa.stderr` is empty.

## Digest identity repair

The test helper is now:

```julia
_d(c) = M.canonical_hash((tag=String(c),))
```

The test asserts that the result has exactly 64 characters, every character
is lowercase hexadecimal, and distinct labels produce distinct digests. The
static checker rejects any `repeat(` occurrence, preventing reintroduction of
the former non-hex label-padding construction. This makes `_d` a legal,
deterministic `Digest256` source without conflating display labels with
identity.

## Label erasure and permutation invariants

The R6 test retains the isolated `M.CapabilitySignatureV4` binding and
`isdefined(M, ...)` checks. It constructs a renamed producer/consumer pair and
asserts unchanged `input_hash` and `plan_hash`; it also reverses component and
input tuple order and asserts unchanged `plan_hash`. Thus display-label
changes and declared permutation cannot silently alter canonical composition
identity. The existing negative matrix, terminal-deferred/fail-closed paths,
and zero provider/solver invocation assertions remain required by static QA.

## R5 failure receipt and current hashes

The R5 focused-runtime failure remains preserved at
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r5/`:

- exit code `1`, `7 passed / 0 failed / 1 errored / 0 broken`;
- failure: `Digest256 requires exactly 64 lowercase hex characters` from the
  old padded `_d("s")` helper;
- `hashes_unchanged=true`, with pre/post hashes equal;
- run HEAD: `70cded1ca1b64496bbee44ac0025659f446364ea`.

Current R6 bytes match `agent_local_r6/manifest.json`:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 21055 | `c5da07f89bb89792c33f3afadd13a8e412a9f3350694f00b73d65a464e3637e4` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 9518 | `1df05362f775cfbb4aa1b1e9af26c298615469b4ed92044fef8e4ac87489f713` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 6276 | `40358b9ab2ac2c7ae8e54b694d48603efe70f0a6f585237e84ac1fb565fe41ed` |

The review observed current HEAD
`23baee9f889713655b04f108f49f8dd0213e3ddf`; no claim is made that this is
the R5 run HEAD.

## Boundary and next action

This is static evidence only. It grants no Julia runtime, provider, solver,
conservation, convergence, physical, engineering, UP3, or R01--R10 credit.
A different agent may now execute exactly one fresh focused isolated Julia
test while retaining `contract_only` and `accepted=false`.
