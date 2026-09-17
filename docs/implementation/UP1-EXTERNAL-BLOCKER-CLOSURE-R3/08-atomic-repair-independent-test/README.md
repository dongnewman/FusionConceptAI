# UP1 R3 atomic repair independent test

结论：`fail_limited`。

这是针对 `07-atomic-prototype-repair-r1` 与 `reviews/05-atomic-prototype-independent-review-r1` 的独立、离线、只读验收。未改动被测件；只在本目录写入 harness、raw 输出和 receipts。无 formal credit、authority credit；`no_publish=true`。

## 运行边界

- 被测件冻结范围：`tools/up1_external_closure_r3/atomic_bundle/**`、`test/up1_external_closure_r3/atomic_bundle/**`；哈希见 `frozen-input-hashes.json`，不计生成的 `__pycache__`。
- 允许的执行仅为 Windows 本地 `python -B`、stdlib/已安装依赖、临时目录 CAS；未联网，未外发，未触发 AD/S3/Julia/DESC/solver。
- `execution-receipts.json` 记录每个进程的 PID、UTC、exit、raw 文件及 SHA-256；所有 PID 在结束后均不再存活。

## 实际证据

- 聚焦测试串行两次均为 `Ran 14 tests; OK`、exit `0`。
- 独立 probe 的 float/exponent 拒绝、`1e20` 与 `1` 不碰撞、negative zero 拒绝、malformed shape typed fail-closed、CAS collision fail-closed、幂等重放、收据 raw/size/transaction/receipt digest/signature/preimage 独立重算与篡改拒绝均通过。
- path traversal 解析后仍在 intended root；junction/reparse root 被 `CAS_REPARSE_POINT_REJECTED` 拒绝。目录 symlink 创建因 Windows `WinError 1314`（权限不足）只能记为 `SKIP`，未把它推断成通过。
- EHP-04 正常闭包为 `not_executed` 且无错误；runtime、SBOM、binary-ref、executed-fixture 篡改分别触发稳定错误码。
- TEST_ONLY 边界验证：即使传入 `decision_override=accepted_all`，返回仍为 `authority_credit=false`、`formal_credit=none`、`no_publish=true`；显式 `TEST_ONLY_NON_EVIDENCE` 结果为 `fail_limited`。
- R01–R25+D01 均实际调用 `validate_bundle`，无异常逃逸，均返回 `no_publish=true` 的 typed result；具体 raw 映射及各向量的覆盖边界见 `vector-coverage.json` 与 `raw/adversarial-probe-final.stdout.raw`。需要 schema-valid envelope 才能到达的正向字段突变没有被冒充为已闭包。

## 残留失败与结论依据

独立构造的 EHP-03 正常闭包（source identity、graph digest/ref、方向相反的 forward/reverse edge、带独立 `row_sha256` 的 G2 正反 rows、mapping digest、issuer ref、四轴集合全部自洽）仍返回 `EHP03_G2_MAPPING_MISMATCH`。实现 `bundle.py:410-411` 的 Counter 同时要求反向 row 与正向 row 具有相同 `row_sha256`，但实现自身又在 `bundle.py:406-409` 对每个有向 row 按其方向性 body 独立重算 digest；方向互换后 digest 必然不同。因此该正例无法闭包，EHP-03 仍不能判定为接受级完整闭包。

这不是测试 harness 的通过条件误写：同一 probe 中 graph/mapping/row/ref 各类篡改都实际触发对应错误，且 EHP-04 有独立无错正例。故本轮只能 `fail_limited`；不得升级为 formal/authority、UP1 acceptance、B00/B04、external 或 publish。
