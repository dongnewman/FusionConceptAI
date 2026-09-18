# UP3-01 CompositionSolvePlanV1 R11 — focused runtime archive

Date: 2026-09-18 (UTC date; agent-local execution record).

## Scope and verdict

R11 archives one serialized focused runtime of the isolated
`CompositionSolvePlanV1` contract. The runtime completed `161/161` assertions
in `11.9 s`, with process ID `41644`, exit code `0`, and an empty stderr.
This is still `contract_only / accepted=false`: provider and solver invocation
counts are both zero, and no numerical, physical, engineering, formal UP3,
B/R, or R01–R10 credit is granted.

Only the two files in this directory were added. No source, test, fixture,
oracle, static-QA, shared entry, registry, index, or task manifest was edited;
no commit was created.

## Failure lineage retained

- **R7:** the earlier focused runtime failure remains historical evidence. The
  static/oracle preparation did not establish a runnable or accepted runtime
  gate; its failure is not converted into credit by this later replay.
- **R9:** the subsequent runtime gate also failed and is retained as the
  immediate failed predecessor to R10. The prior marker `51/25/1` is carried
  forward as lineage only, not as an acceptance result.
- **R10 repair:** the chain-positive path was made stage-specific (`a -> b`
  and `b -> c`) so typed matching is unique without labels or first-producer
  selection; structural ambiguity now dominates deferred reasons; deferred
  reasons remain on the plan; receipt construction keeps the canonical
  outcome constructor while exposing named wire/deserialization factories for
  adversarial records; receipt validation recomputes the hash and enforces
  `contract_only`, zero counts, and an allowed status, rejecting forged
  `:physics` records.

R11 records the runtime result after those R10 repairs. It does not erase the
  R7/R9 failures or promote the isolated contract to UP3 or scientific
  acceptance.

## Sole runtime command and receipt

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP3/composition_solve_plan_v1_contract_tests.jl
```

| Field | Recorded value |
|---|---|
| UTC execution date | `2026-09-18` |
| PID | `41644` |
| exit code | `0` |
| test result | `161/161` |
| elapsed | `11.9 s` |
| stderr | empty |
| provider invocation count | `0` |
| solver invocation count | `0` |

This was the only runtime command for R11. No DESC, provider, mesh, solver,
numerical, or physical execution was performed.

## Recomputed reviewed five-file hashes

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionSolvePlanV1.jl` | 29712 | `24518a477f1272df59732fd876b75d576dca6c6f16219e772f9321d809223ccc` |
| `test/RuntimeV4/UP3/composition_solve_plan_v1_contract_tests.jl` | 18503 | `9bcd8480b243576bbfca52e8e42bf3ae74cadc0b29eab1cccc01e899397cb274` |
| `test/RuntimeV4/UP3/composition_solve_plan_v1_fixture.json` | 3265 | `0e8ae68dc0e3e236e1244075564bc15f96c656c0f02234b4c4fe7840456ac0cd` |
| `test/RuntimeV4/UP3/composition_solve_plan_v1_oracle.py` | 3237 | `d7e4de2648ca28e4983bc50619dd52fd51394064674dfc310a99126cfde093d6` |
| `test/RuntimeV4/UP3/static_qa_composition_solve_plan_v1.py` | 6408 | `1e262a0271bcee90565aaae7bcb9737a686b04206c335c514c153079b1a81f2f` |

The hashes were recomputed from the current working tree after the runtime;
the five reviewed inputs remained unchanged.

## Boundary

`accepted=false`, `claim_ceiling=contract_only`, `formal_credit=none`,
`provider_invocation_count=0`, and `solver_invocation_count=0` remain the
authoritative R11 status. The passing focused contract test is software
contract evidence only. It provides no UP3 numerical/physical evidence and no
R01–R10 closure.
