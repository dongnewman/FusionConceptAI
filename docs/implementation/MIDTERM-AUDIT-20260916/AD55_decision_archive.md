# AD55 有限裁决归档与本轮审计边界

## 裁决来源

`decision=accepted_limited`。来源为2026-09-16本任务用户转述的总架构师Sol报告；记录者为本轮审计主线程。该记录**不是**冒签Sol的新裁决，不是新Julia运行，也不回写历史执行者/复核者的 `accepted=false`。

用户转述的接受范围为：current-HEAD factory 软件闭包及 source-stage 产物。按当前源码核对，精确表述应为 **HEAD绑定的六份来源对象，加AD56工作树执行器的软件执行闭包**；不能扩大为“只检出该HEAD即可重放修复”。本次核查和原件定位见 [source_evidence_review.md](source_evidence_review.md)。

## 引用的证据

| 证据 | 作用 |
|---|---|
| [AD54 root acceptance](../AD-54/V5-SOURCE-PUBLICATION-COMMIT/root_acceptance_r1/acceptance.md) | 本地21文件源码发布、HEAD b2c04d8 |
| [AD56 root acceptance](../AD-56/GIT-FILTER-PORTABLE-SOURCE-LOCATORS/root_acceptance_r1/acceptance.md) | Git过滤/CRLF兼容修复的有限软件接受 |
| [AD55 fresh F0/S2 R2](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/report.md) | F0 PID106008；S2 PID103996、83504；exit均0；source-stage present |
| [AD55 独立复核](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/report.md) | pass_limited；18份正式identity/declaration/receipt两次一致 |

历史报告中的 `completed_review_pending` / `accepted=false` 表示当时尚未有上级裁决；本记录新增裁决来源和范围，不篡改历史。实际每次20个JSON中18个是正式identity/declaration/receipt，另2个是negative_controls/status辅助文件。determinism清单和独立复核均为18，原报告“19 canonical JSON”是文案计数错误，本条追加纠正，不改原件。

本轮还发现原输入清单未逐项冻结所有probe/harness和完整加载依赖。它不推翻已有source-stage运行记录，但限制“完整执行闭包可复建”的说法；若需该声明，应在新目录先冻结全输入再复跑，不能倒填旧冻结时间。下一次S3也须使用完整冻结输入。没有输入或声明范围变化时，不因此无限重复同一验收。

## 明确保留的未满足项

source authority、trusted attestation、candidate/final identity/package、provider、mesh、solver、engineering readiness、physics、search和R01–R10全部不因本条接受而成立；L4=0。B00 F0–F5与B04正式50条仍未关闭。fresh S3尚待执行；无外部信任根时应诚实typed absence。该缺项不允许被本地哈希、软件测试或本记录覆盖。

后续正式索引可以引用本条为“用户转述Sol裁决已归档”，但必须保留 decision_origin，不能声称Sol在本审计目录签署了新验收。任何发现的新输入差异均追加修正，旧原件保持只读。
