# UP1 R2 13/14 独立只读复核 R2

## 结论

`pass_limited`。本次只读复核针对 R1 review 的 F1--F5 重核 13-threat-model 与 14-review-protocol；未修改被审目录、R1 原件、实现或测试路径，未联网、安装、运行 Julia/DESC/mesh/solver/provider 或其他重任务。结论仅是合同/软件准备边界，`claim_ceiling=preparation_only`；不产生外部 authority、UP1、B00/B04、物理/工程或 R01--R10 信用。

## Fresh 验证

独立 fresh Python `-B` 审计命令为 `python -B -c <independent R2 13/14 duplicate/crosswalk/replay/exact/hash audit>`，PID `62804`，UTC `2026-09-16T18:33:55.072235Z` 至 `2026-09-16T18:33:55.087297Z`，numeric exit `0`。审计使用 UTF-8、`object_pairs_hook` duplicate-key rejection、拒绝 NaN/Infinity，并独立重算 canonical SHA-256。

结果：

- 13/14 范围内 13 个 JSON 唯一键解析通过；13 package 的 20 threats、20 attack rows、12 AR 通过。
- 13 `owned_exact_set` 为 25/25，manifest 中 23/23 product hashes 匹配；14 manifest 6/6 hashes 匹配。
- 13 与 14 的 verdict enum 已统一为 `pass_limited|rework|block_external`；`program_exception` 已定义为独立 observed state，只能归约到 `rework` 或经独立外部根因证明的 `block_external`，不能变成 pass。
- TM-07 已统一为 `revocation_unavailable`，证据错误码为 `revocation_status_unavailable`。
- TM-14 已明确：manifest self-reference、omission、hash mismatch、extra file 全部 `fail_closed`；只有真正不可取得的外部 required receipt 才是 `typed_absence -> terminal_deferred`。
- 14 的 20 条 `security_rows` 覆盖 TM-01..TM-20 与 AR-01..AR-12，域集合覆盖 W1/W2/W3/W4、R2-06、R2-07、R2-10；每行均为 `determinism=true`、`process_count=2`、`replays=2`。
- 14 的 17 条主 matrix rows 也全部 `replays=2`，包括 Python static 行和 future-locked B00/B04 行；replays 语义明确为独立 OS process 数，不是同进程重复。
- review assignments 已增加第 8 组 `R2-THREAT-CROSSWALK`，明确 W1/W2/W3/W4、R2-07 authority intake、PKI、CRL/OCSP、TSA、nonce/sequence/idempotency、TOCTOU/path、manifest、SBOM/license、binary、environment 和 typed-absence 的独立复核责任及两进程要求。

## R1 缺口逐项关闭

| R1 finding | R2 证据 | 结果 |
|---|---|---|
| F1：W1/W2/W4 与外部攻击面无可审计映射 | `test_matrix.json` 的 `security_rows` SEC-TM-01..20；`evidence_contract.json` threat crosswalk；`review_assignments.json` 的 R2-THREAT-CROSSWALK | 已关闭 |
| F2：verdict/status 与 program_exception 不一致 | 13 三个 JSON 的 `verdict_enum`；14 `verdict_contract`、`evidence_contract.verdict_schema`、协议 reduction | 已关闭 |
| F3：static replay=1 歧义 | 14 `replay_semantics` 与所有主/security rows 均 `replays=2` | 已关闭 |
| F4：TM-14 omission 可降级 deferred | TM-14 分离 contradiction cases 与 external unavailable case；13 validator 有对应断言 | 已关闭 |
| F5：TM-07 类别编码异常 | threat model、attack matrix、crosswalk 与 validator 统一 ASCII class，错误码保持 `revocation_status_unavailable` | 已关闭 |

## 形式门与边界

14 仍明确禁止本轮 B00/B04、provider、mesh、solver、DESC 和重型 Julia；future-locked 行不提供结果或门信用。`TEST_ONLY=true` 与 `non_evidence=true` 仍为协议材料的固定标签。W1/W2/W3/W4 与 authority intake 的外部事实缺失仍按声明的 `typed_absence/terminal_deferred` 处理，这是当前外部状态，不是本轮合同缺陷；不能据此发布 authority 或正式 UP1 结论。

## 证据与保留

本目录保存 fresh 审计 stdout/stderr、命令、进程元数据和 13 静态校验 raw；`evidence_manifest.json` 对本 review exact set 做 bytes/SHA-256 闭包，manifest 自身排除并明确记录。没有执行 cleanup 或删除任何文件。

