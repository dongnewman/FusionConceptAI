# AD-30 status repair R4 independent review

- `review_id`: `AD-30-independent-status-review-r4`
- `reviewer`: different Luna/high
- `review_date`: `2026-09-15`
- `verdict`: `pass_limited`
- `scope`: read-only review of the R4 documentation repair, active DAG, GI1B index scope, and static evidence

## Decision

R4 passes its limited documentation synchronization scope. The three R3
findings are repaired without changing the machine task manifest, source, old
receipts, or historical evidence.

The active VNEXT route is now stated consistently as:

`UP1-04A + {G1, G2, G3} → T0 → T1 → T2 → UP1-04A-VNEXT → UP2-00`

The existing `UP1-04A-VNEXT` node remains a post-T2 aggregate freeze and
independent-review gate. It does not duplicate T0/T1/T2 implementation.

## R4 repair checks

1. `18_sources_and_architecture_decisions.md:254-260` now explicitly calls the
   direct AD-28 route a historical base schedule and immediately states the
   current AD-30 formal route. `:274` does the same for the AD-29 historical
   reference. The historical AD-28/AD-29 wording and links remain preserved;
   they are not silently rewritten or deleted.

2. `README.md:71` and `:77` now label the earlier direct chains as historical
   AD-28/AD-20 routes and point to the current AD-30 formal DAG. The active
   route at `README.md:105-107` is consistent with the task manifest and the
   work-order schedule. No residual direct route is presented as current
   execution authority in the reviewed core planning text.

3. `docs/implementation/README.md:65` now links the GI1B local acceptance,
   focused R5 receipt, and independent acceptance R3. Its wording correctly
   limits the result to actual-A source-envelope software behavior and typed
   authority-gap handling. It keeps N06 actual authority, UP2 total, B00/B04,
   provider, mesh, engineering, physical, and R01-R10 outside the accepted
   scope.

## Independent machine and status verification

The current task manifest was parsed directly. The relevant rows are:

- `UP1-04A` depends on `UP1-01 + UP1-02 + UP1-03` and is accepted only in its
  existing limited contract scope.
- G1/G2/G3 V1 each depend on `UP1-01 + UP1-02 + UP1-03` and remain
  `planned`, `accepted=false`.
- T0 depends on `UP1-04A + G1 + G2 + G3`; T1 depends on T0; T2 depends on T1;
  the aggregate `UP1-04A-VNEXT` depends on T2; `UP2-00` depends on the
  aggregate. T0/T1/T2/VNEXT/UP2-00 all remain `planned`, `accepted=false`.

The current static validations were executed independently:

- `python docs/v4_multitopology_generation/validate_plan.py`: exit `0`, 31
  Markdown files, 370 relative links, 34 tasks, acyclic DAG.
- `python -m json.tool docs/v4_multitopology_generation/task_manifest.json`:
  exit `0`.
- `python -m json.tool docs/implementation/AD-30/status_repair_r4/evidence_manifest.json`:
  exit `0`.

No Julia, DESC, provider, mesh, solver, engineering, or physical command was
run. R4 is documentation/index evidence only and grants no implementation or
physical credit.

## Recomputed current hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | 57483 | `f16d5a00a7a0896138398b77c18eba4769b6f1962406d55f11862b4ef5b76e0b` |
| `docs/v4_multitopology_generation/README.md` | 28055 | `8c63ab143a3987796e9af82ae0e6b06df54b6e58ecf1782dcab045d9dcee53ce` |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | 73348 | `011533c4c174feb77636aab3d96d5b3d05457d7eaae26f3d52db08a622809280` |
| `docs/v4_multitopology_generation/task_manifest.json` | 63912 | `b149ffa8a725c2a8e9c62bcd3c81becbca92bae9e3b49b3eef9360aef4a9fab5` |
| `docs/implementation/README.md` | 14379 | `e84b03bccd59b21dd2c55aa12fb8a50378d42072d5d3fa854c9d4b365802799b` |
| `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/acceptance.md` | 3030 | `612cebd62c36da0782c6e08d26e183f1e0df778de7d77eebd36e3795d1ca45a1` |
| `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/evidence_manifest.json` | 5226 | `35c71012ba44d98de3426ff008625df1ea35f2e6e62aefcf3304e822aa41904f` |

The worktree was already dirty and concurrent status drift is preserved. This
review owns only its own `independent_status_review_r4` directory.
