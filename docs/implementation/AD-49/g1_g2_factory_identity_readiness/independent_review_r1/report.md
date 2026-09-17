# AD-49 G1/G2 factory identity readiness independent review R1

日期：2026-09-15  
复核者：`gpt-5.6-luna/high`（与 AD49 实现审计者分离）  
结论：`changes_requested`  
范围：只复核 AD49 三个根产品、G1/G2 当前源码与测试、AD39–AD48 输入边界、六个后续工作单及其调度门；不修改被审产品，不实现 factory，不运行 Julia/DESC/provider/mesh/solver/engineering/physics/search。

## 结论先行

AD49 对当前能力缺口的事实判断通过：G1/G2 现有入口是声明/源 payload/软件 receipt constructor，尚无独立 source locator、source-authority factory、trusted source identity 或显式 G2 `GenomeContractRef → QualifiedRefV1` mapping。G1 的 candidate ref 仍是 `QualifiedRefV1`，G2 的 source candidate ref 仍是 `GenomeContractRef`，没有 alias。两层源码和测试都存在于工作树但不在 HEAD，不能被当作 committed source authority。

六个工作单的依赖图无环，最早可推进的是 AD49-S1 两层独立 locator；S1 的结果应诚实落到 `Absent.../terminal_deferred` 或 `Failed.../fail_closed`，不能把工作树 snapshot 升格为 authority。S2 必须等待 S1，F0 只有在 S2 对两层独立给出 absence 后才可条件派发；F0 完成后必须 fresh S2。S3 等待 S1/S2 与独立 attestor，G2 mapping 等待 S2/S3，W3-B 等待 S3/mapping 与 fresh identity inputs。

整体暂不能 `pass_limited`，有两项合同可执行性问题需要修正：

1. W3-B 写明了 9 件产品的 basename，但 G1/G2 八个轴文件没有完整文件路径或目录归属。重复的 `payload_schema_attestation.json` 等名称无法唯一决定 `.../G1/...` 与 `.../G2/...`，违反明确文件归属和 exact files 要求。
2. `manifest.json` 对 S1、S2、S3 及 F0 的 result union 使用 `G1/G2...` 或 `Present/Absent/FailedG1...` 合并占位符，且六个 machine work-order 对象没有 exact `product_paths`、逐单 `forbidden`、`exit_gate`、`cleanup` 字段。报告 prose 有较完整描述，但 machine manifest 不能据此稳定调度和验收。

建议只做文档/机器清单的窄修复：为六单补完整 POSIX 相对路径数组、逐层逐分支 union 类型名、owner/reviewer、输入/输出/依赖/blocked/forbidden/exit/cleanup 字段；W3-B 明确 `.../W3-B-CANDIDATE-BOUND-AXES/G1/...`、`.../G2/...` 八条路径。修复后由不同 Luna fresh review；不改变源码、registry、task manifest 或任何上游产品。修复不阻止根任务在收据修复完成后派发 S1。

## 当前源码与真实边界

观测仓库根为 `D:\006-Programing\LMC\FusionConceptAI`，HEAD 为
`4b69f55f7f80240147a65a22809dc1207824dde2`。AD49 根产品当前 SHA/bytes 为：

- `report.md`：16987 bytes，`0ec415606415cc63104b20e1f881265ef23b2a3391493bad0f5d59418a60e7fe`。
- `manifest.json`：6798 bytes，`3524881a79505e1b4eafa23438bb15b7283ccec3d76900f823a159831e89de46`。
- `cleanup_inventory.md`：950 bytes，`ec3313fe6a7222c18942c88506a6a54779d62554d9fb2b91e52a813d2fe0e617`。

独立 Python 3.13.5 复核最终进程 PID `82396`，UTC `2026-09-15T14:33:58.4658780Z`–`2026-09-15T14:33:58.7520844Z`，direct wrapper exit `0`；复核逻辑将上述两项合同缺口标记为 failed assertions，原始 JSON 在 `review/raw/final_validation_stdout.json`。中间一次 wrapper 参数失败和一次默认 GBK 解码失败均保留在 `review/raw/`，没有改动仓库产品。

源码/测试独立重算结果：

| 路径 | bytes | SHA-256 | HEAD 状态 |
|---|---:|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | `absent_untracked` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | 30773 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | `absent_untracked` |
| `src/Contracts/GenomeContractRegistry.jl` | 2389 | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` | tracked |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | `absent_untracked` |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | 11208 | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` | `absent_untracked` |

G1 的真实 constructor/factory 入口为 `G1DiffusionDeclarationV1`、`g1_diffusion_declaration_v1`、`G1DiffusionReceiptV1` 和 `g1_diffusion_receipt_v1`。它会校验 typed source payload、source hash、candidate `QualifiedRefV1`、字段编辑和 operator closure；receipt 固定软件 proposal/`terminal_deferred`、调用数为零，不能充当 source-backed construction receipt。未发现 locator 参数、AD45 common handle 参数、独立 source-authority factory 或 trusted identity API。

G2 的入口为 `G2MBSourceV1`、`G2MBDeclarationV1`、`g2mb_source_v1`、`g2mb_declaration_v1`、`G2MBReceiptV1` 和 `g2mb_receipt_v1`。G2 declaration 仍要求五字段 `GenomeContractRef` 并重算 declaration hash；receipt 的 provider/mesh/solver/physical 字段仍是软件合同计数和缺口状态。未发现独立 locator、factory identity、trusted identity 或显式 mapping API。`GenomeContractRegistry.jl` 没有 `QualifiedRefV1` cross-type alias。

静态搜索也确认 `src/FusionConceptAI.jl` 没有把这两个 V1 declaration 文件作为现有顶层 factory 暴露；不能通过修改 `default_operator_registry()` 补可见性。AD45 common ref 仍只是 `common_candidate_binding_handle_only`；不能由 URI、version、seed、payload/declaration/axis hash、fixture 或历史 receipt 推导最终 identity。

## 六个工作单复核

- **AD49-S1**：4 件产品，G1/G2 各 locator + receipt，union、输入、HEAD/working-tree distinction、负控和 `terminal_deferred` 门在报告中明确；可在父审查后作为最早单派发，G1/G2 可并行。当前 untracked 源状态不阻止生成 typed absence，但不能产出 authority。
- **AD49-S2**：4 件产品，G1/G2 各 identity probe + construction receipt；等待 S1，必须真实探测 constructor 是否能消费 locator、common handle、public contract 与 typed source；不能把 constructor 名称、fixture 或测试退出码当 factory。两层 absence 才能开 F0。
- **AD49-F0**：4 件代码/测试文件，G1/G2 各 source-authority factory 和 focused tests；条件依赖与“S2 absence → F0 → fresh S2”顺序闭合，禁止 registry mutation、hash-derived identity、T0/T1/T2 和物理执行。需在 fresh S2 后才可继续 S3。
- **AD49-S3**：4 件产品，G1/G2 各 trusted identity + receipt；等待 S1、S2/fresh F0 路径和独立 attestor。没有真实签名/key 或完整 source closure 时必须 typed absence，unsigned self-authored JSON 不能成为 trusted attestation。
- **AD49-G2-MAPPING**：2 件产品，mapping + receipt；等待 S2/S3 和 AD45 handle。必须把 source type=`GenomeContractRef`、target type=`QualifiedRefV1`、五字段 exact equality、算法/profile hash 和 fresh replay 分开记录；禁止 URI/version alias、seed 或任何 hash 派生。
- **AD49-W3B**：9 件产品，G1/G2 各四轴加一个串行 join；输入和 blocked 门正确，缺失时 typed absence，冲突时 fail-closed。但八个轴路径未给出 G1/G2 完整目录，必须先补齐 exact ownership；join 继续等待 S3、mapping 和 fresh identity inputs。

所有单均声明不同 `gpt-5.6-luna/high` reviewer；但 machine manifest 没有把 exact paths 与每单 exit/cleanup/forbidden 结构化，应按上述问题修复。AD44 既有产品路径没有被重复列为 AD49 输出。

## 规划与保护证据

独立运行 `validate_plan.py`：Python 3.13.5，exit `0`，31 markdown、526 relative links、39 tasks、DAG acyclic；原始 stdout/stderr 在 `review/raw/plan_validator_*`。`git diff --check` exit `0`，仅保留既有 LF/CRLF warnings；原始流在 `review/raw/scoped_git_diff_*`。进程探测未发现 Julia、DESC、mesh、solver 或 MPI 重计算进程；未启动重计算。所有失败 wrapper、解码失败和当前合同缺口均 append-only 记录。

本复核未产生 candidate identity、declaration/final candidate hash、source authority、factory authority、trusted identity、G2 mapping、candidate-bound axes、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search 或 R01–R10 信用；L4 credible count 仍为 `0`。
