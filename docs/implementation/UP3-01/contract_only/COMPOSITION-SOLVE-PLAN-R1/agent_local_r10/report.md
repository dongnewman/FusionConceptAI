# UP3-01 CompositionSolvePlanV1 R10 — runtime-failure repair archive

Date: 2026-09-18 (Asia/Shanghai).

## Scope and verdict

R10 repairs the isolated contract-only runtime boundary. The positive chain
now uses stage-specific function spaces (`a -> b` and `b -> c`), so typed
matching is unique without consulting labels or choosing the first producer.
Structural ambiguity dominates missing binding/singular/nonconvergent
deferred conditions, while `plan.deferred_reasons` retains those deferred
reasons for auditability. Receipt construction keeps the canonical
`CompositionSolveReceiptV1(outcome)` path and adds explicitly named
wire/deserialization factories for adversarial records; the ordinary
positional eight-field constructor remains unavailable. Receipt validation
requires `contract_only`, zero invocation counts, a recomputed hash, and an
allowed status, so forged `:physics` records reject.

This remains `contract_only / accepted=false`; no provider, solver, mesh,
numerical, physical, engineering, formal UP3, B/R, or R01–R10 credit is
claimed.

## R9 lineage

R10 is a repair continuation of the R9 runtime gate. The prior R9 lineage
marker is preserved as `51/25/1`; it is historical context for the failed
runtime path and is not reinterpreted as R10 execution evidence. The five
reviewed source/test/fixture/oracle/static-QA hashes below identify this R10
working-tree slice.

## Executed evidence

Only these Python checks were run in fresh processes:

```text
python -B test/RuntimeV4/UP3/composition_solve_plan_v1_oracle.py
exit=0
fixture_identity_sha256=15b2cf3d810d8197349703ea862ea678efe4e415e0dc429f69c4ea9e2dd4dd72

python -B test/RuntimeV4/UP3/static_qa_composition_solve_plan_v1.py
exit=0
schema=CompositionSolvePlanStaticQAV1
status=pass
julia_executed=false
desc_executed=false
provider_calls=0
solver_calls=0
```

Julia was deliberately not run. No commit was created.

## Reviewed five-file hashes

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionSolvePlanV1.jl` | 29712 | `24518a477f1272df59732fd876b75d576dca6c6f16219e772f9321d809223ccc` |
| `test/RuntimeV4/UP3/composition_solve_plan_v1_contract_tests.jl` | 18503 | `9bcd8480b243576bbfca52e8e42bf3ae74cadc0b29eab1cccc01e899397cb274` |
| `test/RuntimeV4/UP3/composition_solve_plan_v1_fixture.json` | 3265 | `0e8ae68dc0e3e236e1244075564bc15f96c656c0f02234b4c4fe7840456ac0cd` |
| `test/RuntimeV4/UP3/composition_solve_plan_v1_oracle.py` | 3237 | `d7e4de2648ca28e4983bc50619dd52fd51394064674dfc310a99126cfde093d6` |
| `test/RuntimeV4/UP3/static_qa_composition_solve_plan_v1.py` | 6408 | `1e262a0271bcee90565aaae7bcb9737a686b04206c335c514c153079b1a81f2f` |

## Residual risk

The focused Julia test remains unexecuted by instruction. Provider capability,
solver behavior, convergence, physical validity, engineering readiness, and
all authority gates remain untested and closed.
