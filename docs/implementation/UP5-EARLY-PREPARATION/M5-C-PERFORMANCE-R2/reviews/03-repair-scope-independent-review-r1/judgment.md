# M5-C R2 repair-scope contract R1 independent review

## 裁决

**不能授权 bounded `screen_only` implementation；保持 `review_pending / not_authorized / not_implemented`。**

本审查只读核对 `reviews/02-repair-scope-independent-review-r1` 提出的 P1-01..07、P2-01..04 与 `03-repair-scope-contract-r1/**`。没有启动 Julia、DESC、S3、solver、mesh、search 或 physical 执行；没有修改被审合同、源码、测试、oracle、probe、共享 registry 或历史 raw。本回合仅写本 review 目录。

静态证据：5 个 JSON 均可解析；合同 manifest 声明的 13 个冻结输入与 3 个本回合 raw 的 bytes/SHA-256 全部匹配；HEAD=`b2c04d8339774635aaecd73651efcdb101e01b5d`、branch=`main`、审计时 Julia process count=0，审计命令 exit=`0`。这些只证明档案自洽，不等于实现或性能通过。

## P1 对照与残余阻断

| ID | 独立核对 | 裁决 |
|---|---|---|
| P1-01 | `contract.md:22-59,65-69` 给出了四个实现 owner 和追加式 evidence-run 路径；但没有 manifest 的机器可读 schema，且现有 `manifest.json` 的 frozen/raw records 没有逐文件 `owner/relative_path/creation_utc/source_run_id/overwrites=[]` 闭包。 | **未闭合**：实现者仍可产生不满足合同字段的 run manifest。 |
| P1-02 | `contract.md:75-102` 明确 preflight-before-rewrite/canonical、UInt128 饱和、overflow/nonfinite defer；但 `schemas/receipt_schema.json` 只是字段名 bundle，未冻结 arithmetic/decision/estimate 的类型、枚举和 limit 级结构，不能作为 typed receipt 的可执行约束。 | **未闭合**：文字顺序正确，机器 schema 不足以验收 guard-before-canonical。 |
| P1-03 | `contract.md:108-126` 和 envelope schema 固定八项与结果映射；但 `contract.md` 的优先级（malformed/duplicate/foreign/evaluator_fault → contradiction）与 `acceptance_matrix.md:24` 的 `malformed > foreign > duplicate > wrong-link > detached > altered > contradiction` 冲突，且 envelope schema 没有 envelope required-field 闭包。 | **阻断**：优先级/状态闭包不唯一。 |
| P1-04 | `contract.md:128-134` 要求对象身份、canonical hash、detached fail-closed；矩阵仅给 owner/provenance 与 graph 的 detached 负控，M5-A/B、catalog、rewrite、derivation 行没有 field-specific detached/wrong-link typed matrix。 | **阻断**：无法逐层验收 detached upstream/object relation。 |
| P1-05 | `contract.md:138-148` 固定 omitted/equal no-op、sealed-different mismatch、input-overload rebuild、over-limit deferred；未冻结同时满足“sealed budget 不同”和“超限”时的优先级，`budget_applied`/`budget_reason` 的枚举也未进入机器 schema。 | **未闭合**：同一请求仍可能得到不同 typed 分支。 |
| P1-06 | `contract.md:152-161` 固定六字段 immutable byte-key、full-byte compare、domain collision 与 hostile 负控；但没有冻结可复现的 digest/hash collision 注入协议，也没有规定 full-key 与 digest 索引冲突时的测试 receipt 字段。 | **未闭合**：collision 负控仍可被实现为非可复放的自选测试。 |
| P1-07 | `contract.md:165-186` 统一 core/perf supervisor receipt 并要求 PID/UTC/deadline/count/raw/hash；但 `schemas/receipt_schema.json` 的 `supervisor_required` 漏掉 `supervisor_wall_seconds` 和独立 `supervisor_exit_code`，也没有 termination/timeout_class 枚举。 | **阻断**：统一 receipt schema 与合同字段不一致，无法证明 supervisor 自身 exit。 |

## P2 对照与残余缺口

| ID | 独立核对 | 裁决 |
|---|---|---|
| P2-01 | `contract.md:188-190` 要求 freeze 含旧 evidence path/bytes/hash 与当前 source/test/oracle/probe；实际 `freeze_receipt.json` 仅含旧 hashes、当前 probe，缺旧 path/bytes 和其余当前输入清单。 | **未闭合**，必须 fresh freeze 后再审。 |
| P2-02 | `contract.md:192-206` 固定 stage enum 与 `8/8/8/4/4/2/0` 校正计数并排除 constructor 名称；但没有把历史 raw 的具体行 id 纳入本回合映射，且 `prepare_rewrite_set=0` 与“无 receipt 应为 not_measured”需要明确区分字段。 | **部分闭合**，需 raw-row receipt 映射。 |
| P2-03 | `contract.md:208-210` 选定唯一 frozen baseline 和比较字段；当前目录没有 baseline run id/path/receipt/hash 的实际 sealed capture，故尚无可比较基线证据。 | **合同方向闭合，证据未建立**。 |
| P2-04 | `contract.md:212-214` 覆盖 derivation-local owner、alias/cross-product/escape 负控；但 `cache` schema 无必填字段，且“receipt 应写”不是强制语义。 | **未闭合**：cache escape 不能靠当前机器 schema 验收。 |

## 放行条件

在修订中统一 contract/matrix/schema 的状态优先级；补齐 manifest、preflight、envelope、binding、budget、collision、supervisor、cache 的真正 typed schema 与 field-specific negative matrix；补齐 old/current freeze 元数据、raw-row corrected-count receipt，并建立不可被修复实现覆盖的唯一 baseline。之后重新 fresh-freeze、独立复核，才能考虑另一个明确授权回合。

当前上限仍为 `manufactured_conditional_egraph/screen_only` / `synthetic_egraph_equality/screen_only`，`formal_credit=none`；不授予 UP5、B00/B04、L4、R01-R10、provider、physical、engineering、search 或 formal equivalence credit。
