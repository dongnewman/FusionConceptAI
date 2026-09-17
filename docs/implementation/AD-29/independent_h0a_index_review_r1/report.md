# AD-29 H0-A index sync：独立复核 R1

日期：2026-09-15  
仓库：`D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
结论：`pass_limited`（仅限 H0-A 索引同步与文档链接；H0-A 总门仍 `accepted=false`）

## 复核范围

本次只读核对核心 v4 README、`docs/implementation/README.md`、AD-29 H0-A
索引同步档案，以及并发 AD-31 修复档案。没有运行 Julia、DESC、provider、mesh
或物理/工程程序，也没有修改核心文件、旧收据或其他 agent 路径。

## 并发缺失链接的处理

作者的 `docs/implementation/AD-29/h0a_precursor_index_sync/report.md` 与其
manifest 原样记录了当时的 `validate_plan.py` exit 1，唯一错误是并发目标
`docs/implementation/AD-31/status_repair_r2/report.md` 尚不存在。检查时该路径
已经出现；本次观察到文件存在（4033 bytes，SHA256
`2fee0d3fd9294d70a6772929056ff0bff06943d429c0f579e44305bdf12b18f5`）。该并发
档案自身把 AD-31 限定为 architecture/work-order 的 `accepted_limited`，实现、
实际 child、T0/T1/T2、provider/mesh、engineering/physical、B00/B04 和 R01–R10
均不授信。作者原 exit 1 是当时的并发状态收据，不能改写为当前运行结果。

## 索引边界与链接

核心 README 第 115–117 行和 implementation README 第 67 行对 H0-A 的边界一致：
只接受 local software contract（constructor/source-selector、identity/provenance、
typed outcomes、editable hash、negative controls、79/79 slice）；H0-A total gate
和 actual source authority 为 `accepted=false`，UP2、B00/B04、provider、mesh/DESC、
physical、engineering、R01–R10 均为 false；runner actual-A status/declaration/
counters 为 `not_printed_by_runner`；R6/R7 exit-1 历史保留。两处索引的 H0-A acceptance
和 independent software R1 链接均存在。两处索引中 AD-31 的 acceptance、manifest、
status-repair 报告及相关独立复核链接也均存在；当前计划 validator 的 391 条相对
链接检查确认全局链接可解析。

当前重算的索引/边界文件为：核心 README 30854 bytes，SHA256
`7a2b8a9b69abe8f3af04067828e817811b410b7313d8e742cc342748a1557b28`；implementation
README 15693 bytes，SHA256
`0c732d5b49532c30f8fe160325ae11cfa3195ac436f7671194f26636a1860d2c`；H0-A acceptance
882 bytes，SHA256 `d1e715fac20e863d18a9be53360adbe7cb969db9992a2521a1a36d24f1a6d38b`；
H0-A total evidence manifest 4027 bytes，SHA256
`9c004d6c6063b3ad577bdba24bf98871c78a604584db6872b9e960b1947128a2`。作者 H0-A
index-sync manifest 的历史 protected hash 对核心 README 与 18 决策文件已因后续
并发文档演进而过期；这不是本次索引链接缺失。implementation README、task manifest、
H0-A acceptance/total evidence 的记录与当前值一致。旧档案没有被本次复核修改。

## 轻量验证收据

以下命令在并发报告出现后重新执行：

| 检查 | exit | 结果 |
|---|---:|---|
| `python docs/v4_multitopology_generation/validate_plan.py` | 0 | `checks=pass`，31 markdown、391 relative links、35 tasks、DAG acyclic、`errors=[]` |
| `python -m json.tool docs/v4_multitopology_generation/task_manifest.json` | 0 | JSON 可解析 |
| `python -m json.tool docs/implementation/AD-31/manifest.json` | 0 | JSON 可解析 |
| `python -m json.tool docs/implementation/AD-29/h0a_precursor_index_sync/evidence_manifest.json` | 0 | JSON 可解析 |

因此，缺失 AD-31 报告导致的当前 plan/link 阻塞已经由文件出现并经一次新鲜
validator 运行解除；这只支持索引同步的 `pass_limited`，不提升 H0-A 或任何物理、
工程、父目标信用。AD-29 H0-A author manifest 的 `status=changes_requested`、原
exit-1 错误与历史 dirty protection 必须继续保留，作为并发时点的 append-only 证据。

## 验收边界

本复核不接受 H0-A total、actual authority、UP2、B00、B04、provider、mesh、DESC、
physical、engineering 或 R01–R10。它仅确认两个索引当前指向正确档案、边界没有把
local precursor 写成终局通过，并确认并发缺失链接已具备可复查目标。

