# AD48-S2-G3 fresh R2 independent review R1

日期：2026-09-15（Asia/Shanghai）  
审计根：`D:\006-Programing\LMC\FusionConceptAI`  
观察 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
结论：`changes_requested`

## Verdict

本 R1 独立确认四个 scope 的八个 fresh S2 产品均为 `PresentG3FactoryIdentityV1` + `PresentG3FactoryConstructionReceiptV1`，且实际 factory 调用、source-stage binding、local G3 declaration/ref/hash/content digest、AD45 exact handle/envelope、四轴和 Git freshness 均可复算；两个独立 Julia 进程 replay 的四 scope 结果相同。`trusted_attestation=false`、`candidate_identity=false`，local declaration hash 不等 final candidate/package/T0 hash。

当前不能给 `pass_limited`，因为 [acceptance.md](../acceptance/acceptance.md) 明确把 `archive/repair_r2_final_snapshot.json` 作为 fresh S2 的冻结输入，但该文件在当前 `archive/` 中不存在。当前 `manifest.json` 的八产品 hash 可核对，却不能替代 acceptance 所声明的缺失 archive freeze。该缺口使 fresh S2 的 declared freeze provenance 不闭合。

## Scope and historical boundary

本次只读取 AD48 README/14/16/18、AD48 gap decomposition、S1 locator acceptance、旧 S2 历史、F0 independent R1/R2/R3 和 root acceptance R3，以及 fresh R2 的八根产品、manifest、acceptance、cleanup inventory 和 archive。只在本目录 `independent_review_r1/**` 新增审计 sidecars；未修改源码、测试、fixture、registry、旧 S2、S1、F0、AD45 或核心规划。

旧 `docs/implementation/AD-48/S2-FACTORY-IDENTITIES/**` 八产品仍逐字节保持历史 hash；旧 S2 不是 fresh present receipt，也未被本次结果覆盖。当前 fresh S2 `status=review_pending`、`accepted=false`。F0 R3 root acceptance 仅解锁 fresh S2 重新取证；它不授 trusted attestation、final candidate/package/T0、provider、physics、search、R01–R10 或 L4。

## Independent checks

### Product and input closure

- 八根产品均 canonical compact JSON、无尾部 LF，manifest bytes/SHA 与当前产品逐一匹配；identity/receipt semantic hash 均可由 `sha256(canonical_json(semantic_body))` 重算。
- 四 scope 都是 Present union；每个 receipt 的 construction digest、identity 的 factory digest、`g3_source_contract_binding_digest`、local `source_declaration_ref`、`g3_source_declaration_hash` 和 `source_content_digest` 存在并在 identity/receipt/runtime probe 间闭合。
- 真实 probe 使用 S1 四个 frozen locator、AD45 exact handle `fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`、version `v5`、实际 envelope `9612` bytes / SHA `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`、实际 `GenomeContractRef` 和 `G3VersionAxesV2`，直接调用 `g3_source_authority_factory_v1`；结果 `103/103` 通过。
- 四轴 `payload_schema_version`、`canonicalization_profile_version`、`applicability_profile_version`、`evidence_receipt_version` 在 identity、receipt output content 和 runtime result 间逐项相等；binding scope 的实际 contract version 为 `v2`，其余 scope 为实际 `v5`，未用层名或默认值补轴。
- F0 exact source/test SHA 分别为 `1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4` 和 `02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f`；root acceptance R3 manifest SHA 为 `08e677522d27fc1c1de56712429bae2966c5df08d8ac3d336c7eb08b397355ae`，均与实际文件相等。

### Source-stage binding and Git freshness

每个 runtime result 都返回 `G3SourceContractBindingV1`，`binding_role=temporary_common_candidate_binding_handle_only`，并由 factory 计算可复算 binding digest。source declaration 携带 scope、actual contract ref、四轴、source path/bytes/SHA、locator digest、AD45 envelope path/SHA 和 local declaration ref；`G3CandidateBoundSourceDeclarationV1` 的 content digest 与 declaration hash 可重算。

factory 重新读取 source bytes 并执行 Git probe。Python 独立复算确认四个 source path 当前 bytes/length/SHA 与 locator 相等；`git rev-parse HEAD` 等于冻结 HEAD，`git ls-tree HEAD -- path` 为空，`git status --porcelain=v1 --untracked-files=all -- path` 为 untracked，四 scope 的 `observed_head/head_path_status/working_tree_path_status/working_tree_status` 均闭合。

### Replay, focused, negative controls

两个相互独立的 Julia 进程分别 replay 四 scope，均 `exit=0`，并且所有 identity file SHA、receipt file SHA、local declaration hash 和 construction digest 相同。必要 F0 focused suite 为 `320/320`、`exit=0`；stdout 明确 `focused_status=pass`。其 stderr 只有 archive runner 第 9 行的 Julia soft-scope warning（`Assignment to status ... ambiguous`），没有测试失败或异常；该 warning 不遮蔽失败，因为 runner 明确打印 pass 且退出 0。

manifest 中的 source/hash/HEAD/path-status/wrong locator/AD45 handle-version-envelope/contract/axes/replay/missing-input negative controls 均为 fail-closed 或 typed-absent-terminal-deferred；focused suite 逐项覆盖并通过。静态扫描确认 factory 只记录 `registry_not_used=true`，没有 default registry mutation 或 publish path。

### Python, plan and scoped diff

独立 Python integrity checker 对八产品、manifest、AD45/F0/root/S1 输入、Git freshness、旧 S2 immutability、archive outputs 和双进程 replay 进行了 `126` 项检查，`124` 项通过；两项未通过均为同一 provenance blocker 的两层表现：acceptance 所指 `archive/repair_r2_final_snapshot.json` 缺失。当前检查结果与 execution metadata 保存在 `raw/independent_integrity.stdout.json` 和 `raw/independent_integrity.execution.json`。

当前 `validate_plan.py` 报告 `31` markdown、`526` relative links、`39` tasks、DAG acyclic，exit 0；scope `git diff --check` exit 0。它们只是规划/工程卫生证据，不是 source authority、provider、physics 或 R01–R10 证据。

## Required repair

请保留本 R1 与当前八产品不变，并补齐或明确修复冻结 provenance：

1. 若 `archive/repair_r2_final_snapshot.json` 是规定的 freeze，则恢复该 archive 文件，并在独立复核中逐字节核对八产品路径、bytes、SHA、observed HEAD 和输入闭合；或
2. 若 `manifest.json` 才是正式 freeze，则修订 acceptance/manifest，使 declared freeze 与实际文件一致，记录 manifest 的 exact hash、冻结 UTC 和产品集合，并重新取得不同 reviewer 的 fresh R1。

修复后才能将本审计升级为 `pass_limited`，其效果也只能是 parent 接受 fresh S2 并解锁 S3。当前结果不能把 construction receipt 当 trusted attestation，不能授 candidate identity、final candidate/package/T0、provider、mesh、solver、engineering、physics、search、R01–R10 或 L4。

## Evidence index

- `raw/real_input_factory_probe.{jl,stdout.txt,stderr.txt,execution.json}` — exact AD45/S1/contract/axes four-scope factory calls, `103/103`.
- `raw/focused_factory_suite.{stdout.txt,stderr.txt,execution.json}` — F0 focused `320/320`, runner warning captured.
- `raw/replay_process_{1,2}.{stdout.txt,stderr.txt,execution.json}` — two independent replay processes.
- `raw/independent_integrity.{py,stdout.json,stderr.txt,execution.json}` — Python hash/JSON/source/Git/archive/negative-control audit.
- `raw/plan_validator.{stdout.txt,stderr.txt,execution.json}` and `raw/scoped_diff.{stdout.txt,stderr.txt,execution.json}` — plan and scoped hygiene checks.
- `raw/static_api_scan.{txt,execution.json}` — source/test API and claim-ceiling scan.
- `raw/julia_absence_snapshot.json` — post-run no-Julia snapshot; Julia was checked absent before each Julia process.
