# UP1 R2 外部证据链威胁模型审查计划

状态：`pass_limited`（结论枚举仅允许 `pass_limited` / `rework` / `block_external`）；claim ceiling 仍为 `preparation_only`。本目录是攻击面与验收条件，不是外部事实、签名、证书、可信时间、authority 或门信用。实现代码、共享注册表、R1 原件和其他 R2 工作单均为只读输入。本目录唯一写入边界为 `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/13-threat-model/`。

## 审查原则

1. 先验证字节和范围，再讨论语义：使用严格 JSON 解析（重复键拒绝）、确定性 canonical bytes 和 SHA-256；不能用路径、mtime、runner exit 或本地 hash 的单独陈述替代外部签名与候选绑定。
2. 发现矛盾、篡改、串换、重放、降级、越界或歧义时必须 `fail_closed`；仅在外部依赖缺失/不可达且没有矛盾证据时保留 `typed_absence` 并输出 `terminal_deferred`。`program_exception` 是独立的意外运行时/工具证据状态，不等于 `fail_closed`，也不等于 `typed_absence`/`terminal_deferred`；保留 raw 后由复核归类为 `rework` 或 `block_external`。三者均不产生 authority，且均 `no_publish=true`。
3. R2 工作单尚未完成时只读取它声明的接口；目录存在、文件存在、静态通过或状态字段不能推导完成。独立 reviewer 不得把本包的通过结果授予外部证据、UP1、B00/B04、R01-R10 或 L4 信用。

## 独立执行顺序

### A. 边界和输入冻结

- 记录 UTC、当前 PID、命令、exit code、HEAD、`git status --short` 和 `git diff --stat`；确认只读 R1/W1-W4 合同及 R2 06/09/10/14 的接口。
- 重新计算本包的 owned path exact set；`manifest.json` 与 `cleanup_inventory.json` 的排除规则必须是显式、无环的。不得删除或覆盖失败原件。
- 比较 candidate/source/G1/G2/G3/four-axis 的正向和反向边；任何一个 hash/OID/path/version 不一致均停止为 `fail_closed`。

### B. 结构化攻击审查

- 对 `TM-01..TM-06` 检查身份、链、profile、canonical bytes、candidate/source/layer/axis 绑定；测试根和 `TEST_ONLY` profile 只能在 fixture 范围。
- 对 `TM-07..TM-11` 检查 CRL/OCSP、独立 TSA、nonce、sequence、idempotency 和 replay-window；撤销失联、时间服务失联、replay ledger 失联均只能 `typed_absence -> terminal_deferred`。
- 对 `TM-12..TM-15` 检查同一打开字节的 TOCTOU、symlink/junction/reparse/path traversal、manifest 自引用/漏项/hash mismatch/extra 和重复键/数字/UTF-8 歧义；TM-14 的四类 manifest 问题只能 `fail_closed`，只有外部必需 receipt 真实不可用才能 `typed_absence -> terminal_deferred`。
- 对 `TM-16..TM-18` 在 clean process 中重放 import/package/artifact，逐项核对 SBOM/license、binary publisher/signature/origin/build recipe 和 OS/runtime/locale/timezone/environment digest。
- 对 `TM-19..TM-20` 强制负向测试：`typed_absence`、null、空字符串、placeholder、local hash、runner exit、mtime、Git 时间和 stale receipt 都不能返回 pass；任何签名覆盖字段变更都必须拒绝。

### C. 证据和独立复核

- 每个攻击保存原始输入、原始 stdout/stderr、PID、UTC、exit code 和 SHA-256；记录 expected oracle 与 observed oracle，不能只保存汇总布尔值。
- 实现者不得同时担任最终 reviewer。reviewer 使用 fresh `python -B` 进程独立加载 JSON，以 `object_pairs_hook` 拒绝 duplicate key，并逐条检查 `attack_matrix.json` 与 `acceptance_requirements.json` 覆盖关系。
- reviewer 必须故意改动 candidate/source/axis、链、算法、撤销/时间、nonce/sequence/key、文件路径、manifest、SBOM、binary 和环境 fixture，确认每一类攻击都命中预期错误码/状态；失败时保留原件并将结论标记为 `rework` 或 `block_external`。
- Sol/root 只裁决范围、claim ceiling、是否允许未来 bounded recheck；任何本计划或静态通过都不等于外部 authority。外部输入 fingerprint 未变化时不得新建同义 AD 或重复 acceptance。

## 交付检查表

- [ ] `threat_model.json` 至少覆盖 TM-01..TM-20，并逐条映射组件与 fail-closed/deferred 结果；TM-07 使用稳定 ASCII 类别 `revocation_unavailable` 并保留中文描述。
- [ ] `attack_matrix.json` 每行包含攻击前提、变异、oracle、证据、错误码和两类结果；覆盖身份冒充、candidate/source/axis 串换、链替换、算法降级、撤销失联、时间回拨、nonce/sequence/idempotency、TOCTOU、路径逃逸、manifest 自引用、JSON 歧义、SBOM、binary、环境漂移、typed_absence。
- [ ] `acceptance_requirements.json` 的 AR-01..AR-12 全部有 mandatory、组件、负向攻击、证据与 failure semantics；所有全局 gate 保持 no-credit/no-publish。
- [ ] fresh Python `-B` 静态校验 exit=0；raw stdout/stderr/combined、PID、UTC、命令和 SHA-256 已写入 `raw/` 与 `validation_receipt.json`。
- [ ] `manifest.json` 和 `cleanup_inventory.json` 对 owned exact set 闭包；manifest/cleanup 自身不参与自身 preimage，失败原件不可清理。

## 复核结论模板

`status`/verdict 只能为 `pass_limited`、`rework` 或 `block_external`；`pass_limited` 的 claim ceiling 仍是 `preparation_only`。`program_exception` 保持独立 evidence state，不直接等于 `fail_closed` 或 `terminal_deferred`，但必须由复核归类为 `rework` 或 `block_external`。结论必须列出攻击 ID、observed state、raw/PID/UTC/exit/hash 位置、未关闭缺口和下一次真实输入变化条件；不得写“外部闭包完成”“authority accepted”或任何等价授信措辞。
