# UP0-01 基线与中断运行审计

状态：`accepted`（限定为当前基线与中断审计范围）。本文件不是物理验收，不关闭 B00，也不关闭 R01–R10。

## 任务合同

| 字段 | 实际值 |
|---|---|
| task_id | `UP0-01` |
| plan_version | `v4-upgrade-plan-20260914.1` |
| actual_model / reasoning | `gpt-5.6-luna` / `high`（按当前派单；未静默替换） |
| base_commit | `4b69f55f7f80240147a65a22809dc1207824dde2` |
| repository / audit cwd | `D:\006-Programing\LMC\FusionConceptAI` |
| audit capture | `2026-09-14T01:39:38.9411396+08:00` |
| allowed writes | 仅本目录 `docs/implementation/UP0-01/` |
| writes made | 本 `acceptance.md`、`evidence_manifest.json`；本次仅更新允许的归档与规划链接 |
| heavy execution | 未执行；未重跑 Julia/DESC、旧任务或测试 |

依据为 `AGENTS.md`、`docs/v4_multitopology_generation/README.md`、00、13、14、16、17 与 `task_manifest.json`。UP0-01 要求保护 dirty worktree、核对 W22–W24 检查点/真实进程、建立 R01–R10 ledger；B00 仍未通过。

## 基线和源码核对

HEAD 与工单基线一致，分支为 `main...origin/main`。审计写入前 `git status --porcelain` 有 239 行：23 个 modified tracked 文件、1391 个 non-ignored untracked 文件；`git diff --numstat` 有 23 个 tracked 修改。工作树不能按 clean checkout 解释。

已核对源码入口及 dirty diff：现有 RuntimeV4 含 typed AST、candidate binding、空间多区域、工程/验证切片和有限 e-graph/搜索类型；本次 dirty 差异主要涉及 G2 geometry edit 接入、空间 runner 的 `--g2-child/--resume` 路由、空间入口测试清单和 validation/UQ 工程缺口负例。dirty source/test/queue 与所有既有 artifacts 均视为受保护对象；没有修改或 stage 任何旧对象。

### tracked modified 保护哈希

以下是审计时 working-tree 内容的 SHA-256；路径来自 `git -c core.quotepath=false diff --name-only`。

| path | SHA-256 |
|---|---|
| `README.md` | `4133a9e53e020fcfc0d92eedc0394cf29a6fdeddacfe27c197fc97f3cf208fef` |
| `docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md` | `0b29c6f75c81f3f3bd25568c60547bbe94ccba547a3ecca83493eb90b422d2ab` |
| `docs/v4_multitopology_generation/01_candidate_integration_and_abstract_compilation.md` | `0a458ec935597912c24d687062a62554d3f3c23a4aabeef33d320a2555a5cd33` |
| `docs/v4_multitopology_generation/02_proof_pruning_and_failure_semantics.md` | `db562ce7772a9840c43aff1a63575b74b5f506016c8cc64f7947738d2072d024` |
| `docs/v4_multitopology_generation/03_open_ended_evolution_and_quality_diversity.md` | `0d6cade2623aa024fa4da094c67a343bf89beff8d27c567703ee5670e292e23f` |
| `docs/v4_multitopology_generation/04_mcts_and_generative_proposal.md` | `add8aae786c51ab87cb8e90478d5f1d34c2e135a23cadaf0bd8522792a3ad8fa` |
| `docs/v4_multitopology_generation/05_realization_and_independent_physics_execution.md` | `90dede11b503be321781ec074d2f31400fcbc708b58692ee236fd3358c5ba173` |
| `docs/v4_multitopology_generation/06_multifidelity_hard_physics_frontier.md` | `21176c034693cc597ff8257d77019a89f904a914ef3f6298673356d575f85d0f` |
| `docs/v4_multitopology_generation/07_survivor_sparsification_and_pareto.md` | `6d24ea5c28deb2271a5ac350676944a16405fc5b6afcd51ba48c5e37101b4248` |
| `docs/v4_multitopology_generation/08_high_fidelity_whole_device_vvuq.md` | `f019256f5740f6365b5ef78edc197159ad902c47c1b9844b802a46ded4662b51` |
| `docs/v4_multitopology_generation/09_evidence_authority_campaign_and_v4_roadmap.md` | `26b462a772798c9568defc9ef47704084b32809156389f7da4a76f2a8401e07a` |
| `docs/v4_multitopology_generation/G1 机制基因组.md` | `b8681e2aa736868d020a28395ad283ce3c634ce3ca5d51bb32e99318143d5472` |
| `docs/v4_multitopology_generation/G2 场—几何基因组.md` | `295a308e0d924ff5d4954418747d59c09f658cff45eea497b44f91148e5c3cad` |
| `docs/v4_multitopology_generation/G3 实现—控制Genome.md` | `a66cc90f065a6b61469591ec0e443da0bf7cc8c8f9f10b7edd7d91cf7890915f` |
| `docs/v4_multitopology_generation/Genome V3.md` | `76f81038855f70d0773ccf2cea0d97570be0dc1917530a6096dc467663cb7375` |
| `docs/v4_multitopology_generation/README.md` | `1c72a0f26d4b65637202ae0d3c1b4469dcbded1e696ce26ac7ee3c9afafac2ec` |
| `docs/v4_multitopology_generation/typed AST、operator hypergraph 或 e-graph.md` | `297434bacab678352271c40f8e6ec8857bd0b7d058feee13e895c578c6e6f70a` |
| `runs/goal_recovery_20260913_012528_cst/task_queue.json` | `dbc57e7e44677cfd4b5d950a37d3d9063fde61fc7e4cec9b8cc44c9a9c3c84c0` |
| `scripts/run_v4_spatial_chain.jl` | `ad5f7864da35bcd355ac256a20574648bab1372055954a71596bb631348d1520` |
| `src/RuntimeV4/SpatialRuntimeV4.jl` | `c71c90090c5401c1e71cc13b319dff45b7a70d273e17f4687be1a91a8be310bb` |
| `test/runtime_v4_spatial_entrypoint_tests.jl` | `673b29e372f4ba2d841630d2e37b01371653c032046002b3c60bf693e2335532` |
| `test/runtime_v4_test_manifest.json` | `3221a99a3ea135324206e5b2c47ebc23a38514af57f6a51ecd8e8797e8da7f6a` |
| `test/runtime_v4_validation_uq_execution_request_tests.jl` | `df1a67c20c528fed9012067a45640a58c6dede3e45f042a26a9cae056e757ed2` |

未跟踪保护采用有界索引，不在本档复制大型 run 内容：非 `runs/` 文件 154 个、989,897 bytes，路径+逐文件 SHA-256 排序清单的摘要为 `a01ca7eefef952a49e0818f8dfcdde76ffc108a9d7ff21ae2fba6553642cf327`；`runs/` 文件 1237 个、459,800,799 bytes，路径+逐文件 SHA-256 排序清单的摘要为 `65cc727d79a090597ba3ae03fe9954889f74a40fddd5a17e193e7e9c163a4788`。覆盖范围是 `git ls-files --others --exclude-standard` 返回的全部 non-ignored 路径，包含 `runs/goal_recovery_20260913_012528_cst/`；空目录无 Git 文件，不计入文件数。为复算审计前快照，排除恰好两个本审计文件 `docs/implementation/UP0-01/acceptance.md` 和 `docs/implementation/UP0-01/evidence_manifest.json`；没有其他排除项。

聚合规范固定为：每个 Git 相对路径先将 `\\` 替换为 `/`；文件 SHA-256 转小写；每行严格为 `<path>\t<hash>\n`；按路径的 `StringComparer.Ordinal` 升序排序；将所有行以 UTF-8（无 BOM）编码，末行也保留一个 LF；对该字节序列再做 SHA-256。文件大小统计是原文件字节数之和，与聚合输入字节数分开。下面的命令可从任意 PowerShell cwd 直接重算两个摘要，且只读：

```powershell
$repo='D:\006-Programing\LMC\FusionConceptAI'
$exclude=@('docs/implementation/UP0-01/acceptance.md','docs/implementation/UP0-01/evidence_manifest.json')
foreach($kind in 'nonrun','runs') {
  $paths=@(git -C $repo -c core.quotepath=false ls-files --others --exclude-standard)
  if($kind -eq 'runs') {$paths=@($paths | Where-Object {$_ -match '^runs[\\/]'} )}
  else {$paths=@($paths | Where-Object {$_ -notmatch '^runs[\\/]'} )}
  $lines=[System.Collections.Generic.List[string]]::new(); $file_bytes=[long]0
  foreach($p0 in $paths) {
    $p=$p0.Replace('\','/'); if($exclude -contains $p) {continue}
    $f=Join-Path $repo $p; $file_bytes += (Get-Item -LiteralPath $f).Length
    $h=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLowerInvariant()
    $lines.Add("$p`t$h")
  }
  $lines.Sort([StringComparer]::Ordinal)
  $payload=[Text.Encoding]::UTF8.GetBytes(($lines -join "`n")+"`n")
  $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($payload)).ToLowerInvariant()
  "$kind file_count=$($lines.Count) file_bytes=$file_bytes digest=$digest"
}
```

期望输出依次为 `nonrun file_count=154 file_bytes=989897 digest=a01ca7eefef952a49e0818f8dfcdde76ffc108a9d7ff21ae2fba6553642cf327` 与 `runs file_count=1237 file_bytes=459800799 digest=65cc727d79a090597ba3ae03fe9954889f74a40fddd5a17e193e7e9c163a4788`。

## 进程和环境

环境核对命令在仓库根执行：PowerShell 7.5.5、Windows 10.0.26200、Git 2.51.0.windows.2、Julia 1.10.5、Python 3.13.5，命令退出 0。`Get-CimInstance Win32_Process` 按仓库路径、`w24_spatial`、`run_v4_spatial_chain`、`goal_recovery_20260913_012528_cst`、Julia/DESC 过滤；审计时没有匹配的 FusionConceptAI Julia/DESC/Python 运行进程。现存的 `phase5_remote_session.py` Python 进程（PID 36588，创建于 2026-09-14 00:26:01 +08:00）命令行不含本仓库任务，未计入本项目运行状态，也未终止任何进程。

## W22–W24 真实证据

关键输入和产物哈希详见 `evidence_manifest.json`；这里保留可读结论和分类边界。

| 工作项 | 可复算事实 | 分类/claim ceiling |
|---|---|---|
| W22 | `n2_source_desc_solve_r3/result.json`：DESC 0.17.3，3 iterations，4940 finite residuals，L2 `0.11682848292227506`、max `0.012152898080190622`，`success=false`；过程入口成功但 optimizer 未收敛。 | `numerical_fail`/solver nonconverged；`screen_only`，不是 equilibrium、provider admission 或 physical validation。 |
| W23 | `w23_algebraic_generation_r4/result.json`：3 candidates、2 descendants、3 converged dimensionless 0D screens，process exit 0，checkpoint resume verified，3 exact capability obligations deferred，`R08_accepted=false`、`R01_to_R10_accepted=false`、credible count 0；`runner.exit` 内容为 `0`。 | G1 typed proposal→0D screen 的 `screen_only` 纵切片；无 G2/G3 search、空间求解、物理验证或可信装置。 |
| W24 parent | candidate `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`，context `0f7521a157ca710b195f82757a8d204058d99231b12346f9c8f37d9be526b10d`。四 case（nominal coarse/fine、flux low/high）physics solver exit 均 4、`iteration_limit`；入口/engineering/verification/whole process records 为 0，`runner.exit` 内容为 `0`，但 engineering status fail，physical validation unsupported，whole deferred，`p5_ready=false`、credible 0。 | `numerical_fail` 物理求解尝试；engineering/whole 为上游无效后的 failure/deferred；exit 0 不能升格物理证据。 |
| W24 child | candidate `7214413813420fdc494ef96dfb1de7fe7de38db5a1489e574dfbe25890842a55`，context `9f408a27de5a6206c2d046d8d6e6a577f9b1641b11a3c308ef4730b2ff24f582`，parent hash 等于父 candidate；G2 `R(1,0)` 从 0.40 m 改为 0.42 m，G1/G3 hashes 保持。child physics 四 case 均 solver exit 4/`iteration_limit`，engineering 在 invalid upstream 后 fail/exit 0。 | 子身份与父身份隔离，仍 `screen_only`；不是 originality、开放搜索或 credible device。 |
| W24 interruption/resume | `w24_child_interruption.json` 记录 original PID 147584 消失，verification artifact 尚不存在，已完成 upstream/physics/engineering checkpoints，分类 `execution_interruption_not_scientific_terminal`；resume flags `--g2-child --resume`、PID 139096，resume stdout 只有 `resume_requested` 与 `running`，无 terminal verification/result/runner exit。 | execution 为 `human_interruption`/`unknown` 边界；physics 的 `numerical_fail` 不被中断覆盖，缺 terminal artifact 不能写 pass。 |

W24 parent/child 证明了不同 candidate/context/field-geometry/genome bundle hash，且 mechanism 与 realization-control hash 保持；不能跨父子复用 checkpoint 或 receipt。当前未发现 child `result.json`、verification 目录或 terminal runner exit。

## R01–R10 当前 ledger

下面以当前 v4 验收合同的状态为准，并与历史 `docs/reports/goal_recovery_20260913/goal_acceptance_ledger.json` 对照。该历史 ledger 的 `head=c9ee99035bc04908bfc0df1e3b60d8c86033bcfb`，不能覆盖当前 HEAD；其 SHA-256 为 `b7f2dfc95d44deb73c49b8ccfbb33053e27652755811f856a11b8f6a8673d8bc`。所有条目仍 `accepted=false`。

| ID | 当前状态 | 主要 evidence / gap |
|---|---|---|
| R01 | `partial` | candidate binding/capability routing 有限存在；统一三 Genome 生产链、B00/B04/B05/B10/B11 未关闭。 |
| R02 | `not_implemented_in_current_chain` | 没有真实参考的完整 inverse + held-out；source/basis/provider/数据缺口。 |
| R03 | `failed_current_attempt` | W24 四 case solver exit 4；N1 观察阶 `-6.157952975473273`；closure 与收敛门未过。 |
| R04 | `partial_local_subsystem` | 仅 pickup 工程切片；完整电路、热、结构、材料、控制和故障闭环缺失。 |
| R05 | `not_implemented_in_current_chain` | 无 candidate-bound 全周期 plant power producer/energy ledger。 |
| R06 | `missing_data_and_providers` | physical validation 未执行；确定性 endpoint 不是分布，也没有 independent discrepancy/UQ。 |
| R07 | `not_implemented_in_current_chain` | 现有路径保持 screen/deferred ceiling；无 FinalWholeDeviceAuthority envelope。 |
| R08 | `partial_queue_only` | W23 是 G1 0D、W24 是一对 G2 screen；无跨 G1/G2/G3 真实闭环。 |
| R09 | `not_implemented_in_current_chain` | 无完整 external prior-art/originality pipeline。 |
| R10 | `not_achieved` | 没有同时通过最终硬门的新候选；`platform_ready=false`、`discovery_goal_achieved=false`、credible count 0。 |

这些状态是当前父目标账本，不能由 UP0 文档、测试数量、runner exit 或单次 solver/provider 结果覆盖。

## 继续依赖和缺口建议

UP0-02 可以在本审计之后独立准备：由 Sol 冻结三 Genome contract refs、mission/grammar/bounds/scenario、B00/B04 协议和精确文件所有权；其输入必须引用 live `runs/goal_recovery_20260913_012528_cst/goal.json`（不是不存在的 `docs/reports/.../goal.json`）。随后 UP1-01、UP1-02、UP1-03 可在 disjoint files 并行，UP1-04 再由集成者接入口。

W24 的无关审计可继续由不同 Luna 对 parent/child candidate/context/field/G1/G3 hashes、四个 solver exit、checkpoint reuse 和 interruption classification 做独立复核；不要将 resume stdout 当 terminal evidence。恢复或新鲜重跑需由 Sol/集成者按串行重计算队列冻结 recipe 后执行，保留原 run 并产生新 receipt。W22 非收敛、N1 负阶、外部 boundary/current closure、真实参考 inverse 数据和物理 provider 缺口应转为后续有明确文件归属的修复单；不能扩大失败为全 grammar 无解。

## UP0-01 限定接受与独立复核

Sol 决策：UP0-01 仅在当前 HEAD、脏文件保护、W22–W24 运行/中断状态与 R01–R10 基线审计范围内接受。独立 Luna reviewer 复核通过：23/23 modified tracked 文件保护记录、10/10 关键 artifact 定位与哈希核对、复算命令确认一致。该复核不等价于 B00 通过。

| 项目 | 结果 |
|---|---|
| owner | `gpt-5.6-luna`（UP0-01 author） |
| reviewer | `different Luna`（independent review: pass） |
| review checks | `23/23 tracked`、`10/10 key artifacts`、protection/recompute command confirmed |
| accepted scope | baseline, dirty-worktree protection, W22–W24 checkpoint/interruption audit, R01–R10 status ledger |
| claim ceiling | documentation/audit scope only; no physical or implementation credit |
| B00 | `pending`；两独立进程 canonical package/hash、tag erasure、permutation 新鲜验证未完成 |
| next dependency | `UP0-02` 可 `ready`，但合同、协议、阈值与精确命令尚未冻结 |

## B00 退出门与后续复核

B00 本次仅完成基线保护、身份和状态审计，尚未完成“两独立进程 canonical package/hash 一致、标签擦除 route/hash/decision 差异为零”的新鲜 replay。故 B00 仍为 `pending`，不能把本次 UP0-01 接受写成 B00 accepted。负控为：没有启动 Julia/DESC、没有重跑历史任务、没有终止现存进程、没有修改旧 queue/run/source/test 或共享索引。

独立 Luna 复核已完成并通过以下抽查：

1. 本文保护清单摘要能由 manifest 命令重算，且 23 tracked 修改和 1391 non-ignored untracked 数量一致；
2. W24 parent/child identity、G2 0.40→0.42 m 变化、父子 G1/G3 保持与 solver exit 4；
3. interruption/resume 没有 terminal verification，工程 exit 0 没有物理 credit；
4. R01–R10 全部保持未接受。

复核结论为 `pass`，复核命令和统计已写入 `evidence_manifest.json`；本次接受仍只覆盖上述审计范围。

## Post-baseline 并发保护时间线（追加）

- 原 UP0-01 基线审计 capture 为 `2026-09-14T01:39:38.9411396+08:00`，快照记录 `23` 个 modified tracked 文件；该数字及原有 23/1391 保护摘要保持不变。
- 随后独立 W24-AUDIT-CHECKER 工作单修改了 `scripts/verify_v4_spatial_manifest.py` 的 ledger predicate，并新增其 focused test；该路径归属 W24 checker，不回写原基线快照。
- 当前 working tree 的 tracked diff 路径数为 `24`；新增第 24 个 tracked 变更是 W24 checker 脚本，当前 SHA-256 为 `bbf9a7e3fc2f6c611f05194ed9909dc22b9c7f4f9cf0694ea7ef6573813b16d6`。这是并发后状态，不能反推原 UP0-01 capture 错误或重写其保护清单。
- W24 checker 已由不同 Luna 复核通过并经 Sol 接受为有限软件 checker 修复；其直接审计 immutable W24 parent 仍 exit `1`，原因是 sealed manifest 中封存旧 checker hash，隔离 fixture exit `0` 不能替换旧正式证据。
