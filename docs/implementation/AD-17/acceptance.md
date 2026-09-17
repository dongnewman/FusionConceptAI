# AD-17 版本 token 与公共 GenomeContractRef 归档

状态：`accepted`，`accepted=true`。接受范围严格限定为 `current_state_ad17_semantic_decision_and_three_core_after_hashes_mtime`。本档案只记录 Sol 的 AD-17 架构决议及三份核心文档当前 after hashes/mtime，不修改 UP0-02 冻结协议、旧归档、源码、测试、运行目录或 R01–R10 ledger。before bytes 与 before→after diff 为 `unknown`；B00/B04/provider/engineering/physical/R01–R10 均不在接受范围。

## 决议范围

AD-17 将 `GenomeContractRef.version` 定义为合同修订 token，类型名另列，字符串相似不自动兼容。G1/G2/G3 对外 bundle ref 与 G3 realization/control 外部 bundle 使用 `v5`；G1 payload schema 独立使用 `v2`；G3 `CoupledRealizationControlBindingV2` 及其 schema 使用 `v2`。每层对外必须使用真正公共的 `GenomeContractRef`，真实 schema/canonical hash、profile hash、四轴、G3 child refs/binding 和 candidate identity 必须精确绑定；缺少真实 schema/provider 只能显式 `deferred`。UP1-04 必须用 migration receipt 记录每个旧占位 ref 的完整 before/after ref、hash、版本轴和 candidate identity 重建，不能静默转换或复用旧 evidence。

19 与 `up0_02_protocol.json` 中类名式 version 保留为当时的 illustrative pending fixture；本归档没有改写它们，也没有将其升级为 B00/B04 或 provider/物理证据。正式 B00/B04 fixture/suite 仍须在 schema 完成后、首次执行前另冻版本。

## 三份核心文件的当前状态时间线

现有工作区没有保存 AD-17 before 的本地字节快照或 bounded patch。18 的 before hash 可追溯到 UP0-02 manifest 的历史 after 记录；16 和 README 的上一轮 hash 只有交接消息/工具输出，缺少可复核来源，因此在本档案中降为 `unknown`。所有 before 捕获时间均为 `unknown`，不能从 mtime 倒推。`UP0-02 historical after` 是旧 UP0-02 manifest 的历史记录，和当前 after 不混用。

| 文件 | UP0-02 historical after（来源） | AD-17 before SHA-256 | AD-17 before 时间 | AD-17 after SHA-256 | AD-17 after mtime |
|---|---|---|---|---|---|
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | `10c15bc2876b8585ec5f04ba70ae4c962ea1ae769edacb56acf10c20f5aca05c`（UP0-02 manifest `up0_02_acceptance_integration.after_write_sha256`） | `10c15bc2876b8585ec5f04ba70ae4c962ea1ae769edacb56acf10c20f5aca05c`（hash 可追溯，before bytes 未保存） | `unknown` | `86aaefe5a8d56eaea0f8b77d7407f5962957916ad741a809aa4c64c9d34b8d1f` | `2026-09-14T04:32:40.4106356+08:00` |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | `7b4aeee79073401ec951f44b28daac44b12b947e7a6ec0fd959a2b3d6e8b833f`（UP0-02 manifest） | `unknown`（reported hash 无本地快照/可复核来源） | `unknown` | `7c69453f5258cbe428b3ba68de1f334c76c549a9dd270547b82adb218fb01899` | `2026-09-14T04:33:01.4452342+08:00` |
| `docs/v4_multitopology_generation/README.md` | `53e86bf13b74e62e0e1fa991b0c64d28a2cb1c25a0df94ec06ff8216d645815c`（UP0-02 manifest） | `unknown`（reported hash 无本地快照/可复核来源） | `unknown` | `80eb6e54f06b97df3b0c81438e91cab2deba5ca5a87017cd960b6490130ed66c` | `2026-09-14T04:33:49.3354326+08:00` |

## 当前内容的决议范围（before→after bounded diff 未保存）

- `18_sources_and_architecture_decisions.md` 当前包含 `AD-17` 锚点与版本 token/公共 ref 决议、版本表、真实 hash/deferred 约束及 UP1-04 migration receipt 要求；既有 AD-09–AD-16 和 UP0-02 引用保留。
- `16_execution_work_orders.md` 当前包含 AD-17 链接；UP1-04 当前包含版本与迁移前置门、逐 ref before/after receipt、B00/B04 首次执行前冻结和公共入口/置换/往返退出门；任务清单状态未在本档案中修改。
- `README.md` 当前包含 AD-17 索引链接和版本/迁移边界，并说明有限实现归档不授物理或父目标信用，L4 可信候选数仍为 `0`。

本节是对当前 after 内容的语义索引，不是可复算的历史 patch。由于 before bytes 未保存，三文件实际 before→after diff 精确性均为 `unknown`；本档案验收范围相应限定为 current-state AD-17 semantic decision、after hashes 和受限门。

## 验收边界

本档案只证明当前三份核心文档记录了 AD-17 架构决议、after hashes、mtime、链接与计划 DAG 可验证；不证明历史增量 diff、不证明 schema/provider、B00/B04、mesh、physical/engineering 或 R01–R10。before/diff 保持 `unknown`，其余执行与物理边界保持 false。

## 审查历史保留

首次 AD-17 归档复核为 `changes_requested`，原因是 16/README 的 before hash 缺少可复核快照或输出来源、三文件 bounded diff 未保存、mtime 精度记录不足。本次只降低历史可追溯性声明并补录七位小数 mtime，没有覆盖该失败记录，也没有改写 UP0-02 旧归档。随后不同 Luna 独立复核为 `pass`；Sol 据此接受本档案的上述受限范围。
