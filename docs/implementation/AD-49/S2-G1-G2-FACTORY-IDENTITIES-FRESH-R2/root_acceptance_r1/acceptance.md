# AD49 S2 fresh G1/G2 factory identity — root acceptance R1

日期：2026-09-16  
决策：`accepted_limited`  
accepted scope：`factory_software_capability_and_current_repository_typed_absence_only`  
唯一后续许可：`AD49-S3 trusted-source identity presence/absence gate`

## Decision

依据 fresh S2 正式运行与不同 `gpt-5.6-luna/high` 独立 R1 的 `pass_limited`，root 接受：

1. F0 G1/G2 factory implementation 的软件能力证据；
2. 当前真实仓库中 G1/G2 declaration source 未进入 `HEAD` 时，factory API 返回的 `AbsentG1/AbsentG2` identity、source declaration 和 construction receipt typed absence；
3. `terminal_deferred=true`、`no_publish=true`，以及 G2 mapping 保持 absent 的有限状态。

四个 identity/declaration/receipt 结果均由真实 factory API 产生，当前原因均为 `source_authority_missing`。它们没有把工厂文件 hash、构造器、fixture、seed、URI、payload hash、G3/registry alias 或测试/运行器 exit code提升为 source-construction identity。

## Formal products

| product | bytes | SHA-256 |
|---|---:|---|
| `g1_factory_identity_probe.json` | 1250 | `6a91b6c53284400207a2c96609c76814dc2b6a681f4d9dbbde67fe1224d7655c` |
| `g1_factory_construction_probe_receipt.json` | 1061 | `bbc037e76ac3ff165917f0e3f27d6b1f5ad06cfa56cf0321fb31d1aef5f0c990` |
| `g2_factory_identity_probe.json` | 1250 | `7d44daec924f080c13a30ea8acb9428f3a8c7a5d6ac50bf3ad5b7c9f7c847065` |
| `g2_factory_construction_probe_receipt.json` | 1061 | `3437e195387f3cd0b34ff849db7ade98c6f1d41afac484dfd5378ee7ac4deab8` |
| `negative_controls.json` | 1210 | `0939c2647b51e4418c954c80a694cc62619b6e8c173e8bc9d7429b8ac38ac463` |

正式 probe 严格串行成功两次：S2 PID `96668`、`96944`，均 exit `0`；独立 R1 reviewer 自有 probe PID `95792`、`81992`，均 exit `0`。独立复放在 reviewer 自有目录完成，没有修改上述五个正式产品。两次复放的 canonical result hash 和语义字段一致（剔除 PID 元数据后）。

focused/regression 共有六项，均严格串行且 exit `0`：G1/G2 factory focused、G1/G2 declaration contract、G1/G2 UP1 contract。计划验证器为 31 Markdown、526 links、39 tasks、DAG acyclic，exit `0`；scoped `git diff --check` exit `0`；最终无 Julia 残留。以上是软件、复放和工程卫生证据，不是物理证据。

## Baseline limitation and failed history

S2 正式目录没有真正的 pre-run baseline；其 `baseline.json` 明确标为 `post_run_reconstructed_snapshot`、`pre_run_baseline_present=false`、`not_acceptance_evidence=true`。root 将其作为限制保留，不把 post-run snapshot 当作验收证据。有限接受依据是上游冻结输入、S2 两次成功进程、独立 reviewer 两次成功复放、五产品前后哈希不变，以及当前 `HEAD` 对两个 declaration path 的缺失。

S2 实现失败 1–4 均保留且不计入结论：`attempt_1_missing_load`、`attempt_2_parse_error`、`attempt_3_validation_pid_binding`、`attempt_4_plan_validator_cwd`。独立 reviewer 的 parse-gate 失败、validator/路径失败、部分 replay 输出和 superseded validation 也均只作失败历史，不作通过证据。两条 `fatal: not a git repository` 仅来自预期的 anchor-unavailable negative control，成功运行 exit 为 `0`，不被解释为 source authority。

## Frozen input boundary

输入保持绑定到 AD49 S1 typed-absence locators、F0 root acceptance、AD45 exact common handle/envelope、G1/G2 public contracts 与四轴。当前 `HEAD=4b69f55f7f80240147a65a22809dc1207824dde2`；

- `src/GenomeV5/G1/DiffusionDeclarationV1.jl` 在工作树存在但未被 `HEAD` 跟踪；
- `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` 在工作树存在但未被 `HEAD` 跟踪；
- S1 locators 因缺少 HEAD path closure 为 `AbsentG1/G2IndependentSourceLocatorV1`、`terminal_deferred`；
- F0 factory hashes 只证明软件实现文件闭合，不能生成 declaration/source identity；
- G2 仍保留 `GenomeContractRef`，mapping absent。

## Claim ceiling and next gate

本接受不授予或创建：

`source_authority=false`、`trusted_source_identity=false`、`candidate_identity=false`、`final_hash=false`、`T0=false`、`T1=false`、`T2=false`、`provider=false`、`mesh=false`、`solver=false`、`engineering=false`、`physics=false`、`search=false`、`R01–R10=false`、`L4_credible_count=0`。

允许下一步只按独立工作单进入 AD49-S3 trusted-source identity presence/absence gate。S3 必须重新依据外部信任根和真实 source closure 判定；本 acceptance 不预判 S3 presence 或 absence，也不解锁 UP2–UP6 的物理执行。

## References and protection

- S2 formal report/manifest/direct validation/final hashes：见同目录上级文件；
- independent R1 report、manifest、271-check audit、final hashes 和 cleanup：见 `independent_review_r1/`；
- 上游 S1 root acceptance 与 F0 root acceptance 的路径、字节数和 SHA-256 见 `hash_inventory.json`；
- 只有本 `root_acceptance_r1/**` 目录被本归档写入；产品、源码、registry、entrypoint、task manifest 和历史失败目录保持原样。

