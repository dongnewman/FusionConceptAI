# UP1 R2 integration slice

状态：`implemented_review_pending`，范围：离线、轻量、software-preparation-only。

当前实现为 `integration-slice.v2`。`integration.runner.run_pipeline` 以版本化 JSON package 为入口，依次保留
common、witness、pki、revocation、source_axis、g2、environment、intake 和
aggregate 的状态、错误和确定性 receipt SHA-256。适配器只调用组件公开接口，
不修改组件目录，不联网、不调用 Julia/DESC/solver/mesh/provider/S3，也不自动
生成 expected context、trust anchor 或 replay key。

状态归约规则是：`invalid`/`fail_closed`/`replayed`/`stale`/`conflict`/运行时
异常均 `fail_closed`；`typed_absence`/`unsupported`/`non_evidence` 均
`terminal_deferred` 并 `no_publish=true`。仅全部 production authority
verified 时可达 `eligible_for_authority_recheck`，这个状态仍不授予 T0 或任何
后续信用。TEST_ONLY 永远保留 `non_evidence` ceiling。

传入相同 input fingerprint 且前一状态已被独立 integration ledger 认证时返回 `deterministic_noop`，不产生 AD；
fingerprint 改变时仅返回 `intake_changed`/`terminal_deferred`，下游必须重新走有序
intake。CLI 为 JSON-only，正常 deferred/eligible 返回 0，fail-closed 返回 2，
未预期程序异常返回 1。

外部 trust/context/key/ledger/intake spool 必须由调用方通过参数提供；package 内同名字段不会被提升为
独立 anchor。该切片及其证据为 `TEST_ONLY=true`、`non_evidence=true`。
本地 intake receipt 只证明本地接收，不论其字段如何都不能充当 authority。
