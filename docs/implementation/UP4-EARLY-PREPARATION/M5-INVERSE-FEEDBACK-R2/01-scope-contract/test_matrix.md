# R2 测试矩阵（未来执行合同；当前未执行）

当前状态统一为 `planned`/`not_executed`。本矩阵不授权运行 Julia、DESC、S3、provider 或 solver。

| ID | 检查 | 输入/动作 | 预期 typed 结果 | 证据要求 |
|---|---|---|---|---|
| S01 | schema | 解析 request/result/failure JSON | pass；字段/枚举完整 | parser exit/raw |
| S02 | exact recovery | frozen target/rhs, exact rational | `(alpha,beta)=(2,1)`, det=3 | canonical output/hash |
| S03 | round trip | forward(recovered)-target | exactly `(0,0)` | derived-field replay |
| S04 | multi-start | seeds `[0,1,2]` in fixed order | semantic and canonical outputs equal | seed ledger |
| S05 | feedback negative | delete beta/interface edge | response `(1/2,0)`, delta `(1/6,1/3)`, changed=true | before/after payload |
| S06 | corrupt derived | mutate determinant/eigen/residual/owner ledger | typed failure; old bytes preserved | mutation receipt |
| S07 | upstream identity | foreign source/test/oracle/composition hash | `foreign_hash` or `invalid_upstream` | failure path |
| S08 | ownership | foreign owner/provenance or cross-candidate join | `foreign_owner`/`foreign_provenance`, fail closed | canonical diff |
| S09 | target controls | zero, singular, impossible, non-SPD, denominator-zero targets | typed fixture failures | one receipt per control |
| S10 | scope controls | provider/solver/real-reference/hardware requested | `terminal_deferred` or `solver_not_authorized` | no external side effect |
| S11 | replay | oracle then typed checker twice, serial | same semantic payload; byte equality required where canonical | PID/UTC/exit/raw/hash |
| S12 | exception/budget | forced exception, interruption, >120 s or >512 MiB | preserve `program_exception`/`human_interruption`/`budget_exhausted` | raw/process receipt |
| S13 | diff guard | inspect worktree before/after | only task-owned docs changed | HEAD/status/raw |
| S14 | claim audit | scan output claims and evidence scope | no credible/physical/engineering/provider/formal claim | static scan receipt |

## Acceptance interpretation

S01/S13/S14 are applicable to this documentation-only delivery. S02–S12 are future implementation gates and remain `pending`; no count may be invented. A local pass in S01 or S13 never closes UP4/B07 or the parent R01–R10 goal.
