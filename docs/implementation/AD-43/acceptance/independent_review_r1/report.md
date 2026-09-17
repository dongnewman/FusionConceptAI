# AD-43 acceptance independent review R1

日期：2026-09-15  
观察 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
复核模式：different Luna/high，read-only  
结论：`changes_requested`

本次复核确认 AD-43 的接受范围仍应限于三处真实 typed absence 与四产品 source-only contract boundary。三处缺口精确为 G1 `evidence_receipt_version`、G2 `applicability_profile_version`、G2 `evidence_receipt_version`；其 source types 分别保持 `G1DiffusionReceiptV1`、`G2MBProfileV1`、`G2MBReceiptV1`，当前均 `typed_absent` 且 `current_present=false`。四个 AD-43 axis contract products 当前可见，但仍是 `observed_parallel_outputs_pending_independent_review`，`future_axis_products_accepted=false`，并保持 `point_in_time_excluded`；它们没有授予 authority、present、T0 或 R01–R10。

17 个冻结输入全部存在；其中 16 个 bytes/SHA-256 仍与冻结值一致，AD-42 acceptance.md 的变化仍按 manifest 的 `post_audit_input_drift` 精确记录（冻结 4297 bytes / `ded047...576a06`，当前 4543 bytes / `7993...2075c`），没有发现未记录漂移。既有审计复核的 55/55、最终 15/15、AD-43 acceptance validator 20/20 均如实存在且 exit 0。当前所有 claim（present、T0/T1/T2、provider、mesh、solver、engineering、physical、search、B00、B04、R01–R10）仍为 false；未运行 Julia、DESC、provider、mesh、solver 或 physical workload。

发现一个验收收据一致性缺陷：AD-43 acceptance manifest 的规划验证记录宣称 `plan_dag_stderr.txt` 为 1 byte，但登记 SHA 为 `01ba4719c80b6fe911b091a7c05124b64eeece9649b934ca495991b7852b855`；当前原始文件仍为 1 byte，但复算 SHA 为 `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`。因此本次独立 JSON/hash/path/control/scope 闭合为 54/55，PID 83776，UTC `2026-09-15T10:14:47.589799Z`–`2026-09-15T10:14:47.593066Z`，记录 exit 1。该问题只阻止验收收据闭合，不改变三处 typed absence 或任何物理/工程状态。

当前规划文件重新验证通过：PID 41812，UTC `2026-09-15T10:13:37.059631Z`–`2026-09-15T10:13:37.322212Z`，exit 0；31 个 markdown、497 个相对链接、39 个任务，DAG 无环，stdout SHA `cf4058eae2fcca17ca5cdfa4207f0caf0451e9299254edf56fe875f4fe283bf7`。`git diff --check` PID 81372 exit 0，仅有既存 LF/CRLF 警告，未发现 diff 错误。

修复门：只需由负责状态同步的 Luna 重新生成或更正 AD-43 acceptance manifest 中该 plan stderr raw hash，并以新的 append-only status/closure receipt 复核 bytes、SHA、PID、UTC、exit；不得改写历史 raw evidence、四个 axis products、AD-42 W0 products、核心任务清单或任何 claim。修复后由不同 Luna 重跑本复核。
