# AD-24 N05/N06 source audit acceptance

status: `review_pending`

decision: `changes_requested`

scope: read-only source/authority audit only

本归档只记录 N05/N06 的 actual typed source、旧 provisional rows、局部 validator 和跨层 authority 缺口。N05 的 flux endpoint/sign/unit 没有 source-backed exact mapping；N06 的 source→field→return/heat/ledger/owner-scope mapping 也没有权威 typed contract。缺失能力保持 `terminal_deferred`，实际局部类型/引用/枚举/单位/容量/closure 违反既有规则时才 `fail_closed`。

已完成的检查：

* 冻结 HEAD、被审文件的 SHA256/bytes/mtime 和 dirty 状态快照，见 `evidence_manifest.json`。
* 核对 `CandidateStatePackageV5` 实际 A factory、G1 equation occurrences、G2 interface、G3 resource network/account/entry/closure/link/binding 源字段和行号。
* 核对 UP0-02 N05/N06 五行合同、AD-22 owner/join 边界，以及 UP2 现有 N05/N06 provisional locators。
* 审计开始时无本仓 Julia/DESC 进程；本工单未运行 Julia/DESC，故没有运行 exit、solver/provider/mesh 或物理证据可报告。
* 只写入本目录；没有修改源码、测试、旧 UP2 rows、核心文档、runs 或其他 archive。

受限结论：允许后续以独立新版本 authority 工单实现 source-backed projection；当前不接受 N05/N06 implementation，不授 B00/B04、provider、mesh、engineering、physical 或 R01–R10 信用。未来实现须先由不同 Luna 独立复核，且重计算仍串行。

artifact hash、检查命令和完整 field-by-field 证据见 `source_audit.md` 与 `evidence_manifest.json`。
