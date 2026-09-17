# M5 inverse-feedback R2：隔离 manufactured engineering-feedback 数值切片合同

状态：`contract_drafted_not_implemented`；`claim_ceiling=manufactured_inverse_feedback/screen_only`；`formal_credit=none`。

本目录只冻结下一步工作的边界、typed 输入/输出、失败语义、预算、文件归属和验收门。它不是实现、测试通过记录、逆设计结果、工程资格或正式 UP4/B07 证据。当前记录者未运行 Julia、DESC、S3、mesh、provider 或 solver，也未修改生产/测试源码。

## 1. 与 R1 的关系和允许范围

R1 已冻结 exact-rational manufactured family

```text
A(alpha,beta) = [[alpha,-beta],[-beta,alpha]], rhs=[1,0]
target=(2/3,1/3), hidden=(alpha,beta)=(2,1)
```

R2 只允许在同一隔离边界内定义一个 candidate/source-bound 的 engineering-feedback 数值切片：读取经过身份、owner、provenance 校验的 M4-D/M5-A manufactured snapshots；计算有限的 forward、inverse、feedback-on/off 和 round-trip 记录；所有结果最高只能是 `screen_only`。R1 的 `pass_limited` 不能向 R2 转移任何 UP4-01/02、B07A/B、provider、solver、工程、物理或 R01–R10 信用。

不允许：真实参考或实验数据、硬件尺寸/材料/供电资格推断、candidate generation、PDE/ODE/DAE/电路/热/结构 solver、DESC/FreeGS/S3/provider 调用、网络下载、registry/shared entry/task graph 修改、生产路径接入，以及将 manufactured 参数称为真实装置隐参。

## 2. typed 输入合同

规范字段见 [input_schema.json](input_schema.json)。顶层类型为 `EngineeringFeedbackSliceRequestV2`，必须满足：

1. `schema`, `status`, `claim_ceiling` 为固定字面量；`status` 初始只能是 `authorized_not_started` 或未来执行时的 `ready`，不能预填结果。
2. `candidate_binding` 必须有同一候选的 G1/G2/G3、parent-baseline、mission、scenario、source owner/content/provenance 绑定。任一 identity 缺失是 `candidate_unbound`/`terminal_deferred`，绝不能用 family 名称或历史 hash 代替。
3. `upstream` 必须保留完整、不可变的 M4-D 与 M5-A typed snapshot、source/test/oracle/composition hash、owner ledger 和 provenance ledger；derived hash 必须从嵌套 canonical bytes 重算。
4. `manufactured_case` 的 `parameterization`, `target`, `rhs`, `feedback_edge`, `feedback_deletion` 是显式 typed 值；hidden 参数可在 manufactured fixture 的 oracle 控制中存在，但不得进入 seed、初始化、缓存或 held-out 数据。exact-rational 模式禁止静默浮点化。
5. `objective_and_constraints` 必须给出每项单位、范数、权重、容差和 hard/diagnostic 标记。R2 不允许把工程量缺失默认为零；本切片只能把工程反馈抽象为有方向、有 owner、有 response delta 的 typed edge。
6. `replay` 固定 canonical serialization、字段排序、seed 顺序、hash 算法、locale/timezone 和环境记录；`budget` 固定单进程、单 worker、无网络且有界。

缺失字段不是空字符串的成功输入：按 `failure_taxonomy.json` 路由为 `unknown + terminal_deferred` 或 `fail_closed`。

## 3. typed 输出合同

顶层类型为 `EngineeringFeedbackSliceResultV2`，规范见 [output_schema.json](output_schema.json)。输出必须分开保存：

* `binding_receipt`：候选、source、upstream、scenario 和输入/输出 artifact 的 hash join；不能只保存 program hash。
* `forward`：矩阵、rhs、response、determinant、eigen/margin proxy、单位和 residual；每个 derived field 必须可由输入重算。
* `inverse`：recovered parameters、multi-start ledger、identifiability/rank/condition 记录和 round-trip；不可辨识时输出区间/组合或 typed failure，不能挑选一个“最好值”。
* `engineering_feedback`：feedback edge identity、active response、删除/断开响应、delta、response-changed 标志和 scope。删除 beta/interface 后预期 response 为 `(1/2,0)`、delta 为 `(1/6,1/3)`；此控制只是因果软件负控，不是工程验证。
* `failures`：稳定排序的 typed failure records；异常、超预算、缺 provider、缺真实参考和硬件 authority 不得压成 `pass`。
* `evidence`：`screen_only`、`not_executed`、artifact/raw/process receipt 引用和 claim ceiling。不得出现 `credible`, `physical_pass`, `engineering_pass`, `provider_pass` 或正式 gate closure。

成功的 manufactured 结果也只能是 `valid_screen`；缺少 candidate/source/authority 则为 `terminal_deferred`；矛盾或 foreign identity 则 `typed_failure`/`fail_closed`。

## 4. candidate/source 绑定与反馈边界

候选键为 `(candidate_ref, g1_ref, g2_ref, g3_ref, parent_baseline_ref, mission_ref, scenario_id)`；source 键为 `(source_ref, source_content_sha256, source_owner, provenance_ref, source_schema)`。所有键必须从同一 canonical input bundle 派生。M4-D/M5-A 的 owner/provenance 只能做 nested projection consistency check；不得把 R1 历史值投影成新的 candidate 或物理 subject。

feedback edge 是 immutable identity 加 editable state 的 typed edge。允许的编辑只有本合同列出的 `delete_beta_or_interface_feedback`，操作历史必须追加且可重放；动态插入、换源、换 candidate、改 axis/units、伪造 ref/hash 都 fail closed。任何 edge 缺 source owner、effect scope、units 或 direction 都是 `foreign_owner`/`invalid_input`。

R2 的 engineering feedback 仅指“反馈边改变 manufactured response”的可审计软件关系。它不代表 Lorentz force、温度、应力、功率、控制稳定性、制造可行性或 hardware-in-the-loop。

## 5. 失败分类和确定性

错误码、触发条件、resolution 和 claim ceiling 见 [failure_taxonomy.json](failure_taxonomy.json)。核心规则：

* 输入/identity/schema/owner/provenance/单位矛盾：`fail_closed`，保留原 canonical bytes、history、hash。
* 缺真实 authority、provider、hardware、reference 或适用域：`unknown` + `terminal_deferred`，不发明 unsupported 或 credible。
* singular、non-identifiable、impossible target、non-SPD、round-trip、seed mismatch、feedback deletion no-effect：`typed_failure`，属于数值/合同控制，不是物理失败。
* `program_exception`, `human_interruption`, `numerical_fail`, `budget_exhausted` 必须保留原始上下文、PID/UTC/exit 和 raw；不得重标为 pass。

重放必须满足：相同 canonical input bytes、source/code/oracle hashes、环境 fingerprint 和 seed ledger 产生 byte-identical canonical output/hash；Python Fraction oracle 与独立 typed checker 的比较按 semantic payload 做，不能只比较 exit 0。任何输入、实现、oracle、依赖或环境改变都触发新的 freeze 和新的 receipt。

## 6. 预算和未来执行限制

这是可审计的 bounded numerical fixture，不是搜索任务：

| 资源 | 上限/规则 |
|---|---|
| 正向 manufactured case | 1 frozen family、1 target/rhs、feedback on/off 各 1 |
| starts | 固定 seeds `[0,1,2]`，最多 3；禁止隐藏答案注入 |
| negative controls | 最多 24 个预注册 mutation，稳定排序、逐项 receipt |
| replay | 独立 oracle→typed checker，最多 2 个完整 replay；严格串行 |
| 并行/网络 | 1 process、1 worker、无网络、无下载、无 provider/solver |
| 时间/内存 | 每次未来软件检查 wall-clock ≤120 s、内存 ≤512 MiB；超限为 `budget_exhausted` |
| 算术 | manufactured case 使用 exact rational；禁止非声明的随机数、浮点容差替换或自适应优化 |
| 产物 | 只写本 task-owned docs/evidence sidecars；不得写 `runs/`、production source、test source、registry |

“预算内完成”不等于模型正确、工程可用或正式 gate 通过。

## 7. 文件归属和协作隔离

本次作者只拥有本 `01-scope-contract/**`。未来实现若获 Sol/root 单独授权，建议五个 pairwise-distinct Luna roles 和文件归属如下；当前均为 planned、未创建、未实现：

| role | future path | 责任 |
|---|---|---|
| source implementer | `src/RuntimeV4/M4Isolated/ManufacturedEngineeringFeedbackSliceV2.jl` | typed records、pure manufactured mapping、closed failure routing |
| test owner | `test/RuntimeV4/M4Isolated/manufactured_engineering_feedback_v2_tests.jl` | positive/negative/schema/replay checks |
| oracle owner | `test/RuntimeV4/M4Isolated/oracles/engineering_feedback_oracle_v2.py` | independent exact Fraction oracle |
| integration owner | task-owned evidence sidecar under this R2 package | serial command, receipts, hashes, cleanup |
| independent reviewer | separate review directory chosen by Sol/root | fresh static/runtime review and acceptance recommendation |

不得修改 R1 source/test/oracle、`FusionConceptAI.jl`、`default_operator_registry`、`Project.toml`/`Manifest.toml`、task manifest、G1/G2/G3 scaffolds 或任何 shared/final package。实现、测试、集成、文档和复核者须角色分离；若 actor identity 未能证明，验收只能 `review_pending`。

## 8. 测试矩阵和验收门

矩阵见 [test_matrix.md](test_matrix.md)。在未来实现前，本 R2 仅可验收合同静态属性：JSON 可解析、路径在 task-owned 目录、R1 输入 hash/HEAD/PID/UTC/exit/raw receipt 完整、禁止项列全、pending 规则成立、工作区 diff 仅落在本目录。此静态检查不运行代码，`code_tests=not_applicable`、`runtime_execution=not_run`。

未来实现的必要门（全部独立记录，全部通过才可建议 `accepted_limited`）是：

1. typed request/result schema 与 canonical serialization 检查通过；
2. exact Fraction oracle、typed implementation、两次 serial replay 的 semantic payload/hash 一致；
3. positive exact recovery、round-trip zero、3-seed determinism、feedback deletion delta 和全部 negative controls 通过；
4. candidate/source/upstream owner/provenance/hash join 通过，外来/缺失 identity fail closed；
5. raw stdout/stderr、process JSON、PID/UTC/exit、input/output/artifact hashes 和 cleanup inventory 齐全；
6. scope scan 证明无 provider/solver/真实参考/硬件/production registry side effect；
7. 独立 reviewer fresh replay 与 root decision 完成。任何一个门缺失均保持 `review_pending`/`terminal_deferred`，不授 formal credit。

## 9. 必须等待的外部材料

以下材料不是 manufactured fixture 可以替代的，缺失时必须停在 typed pending：

* **真实参考/B07B**：provenance、license/version/hash、坐标/单位 authority、测量不确定度、calibration/validation/held-out split、隐藏参数声明、candidate-independent checker 和 grammar-reachable representation；MMS 或 R1 target 不算真实参考。
* **真实硬件/B07A**：candidate-bound G1/G2/G3 source geometry、线圈/导体/回流、driver/power/return network、材料与制造数据、冷却、结构支撑、控制保护、fault/start-stop/tolerance scenarios、供应商/适用域 manifest；缺任一 closure 只能 deferred。
* **权威外部材料**：UP2-05 provider manifests、UP3-02 field forward evidence、独立 solver/checker、信任根和可追溯许可。软件 exit 0、文档、历史 hash、单组件 reciprocity 或 manufactured pass 都不能代替它们。

## 10. 当前结论

R2 是下一步隔离 engineering-feedback 数值切片的合同草案，结论是 `not_implemented`、`not_executed`、`screen_only`、`formal_credit=none`。它没有关闭 UP4-01/02、B07A/B、UP2-05、UP3-02、R02/R04/R05 或 parent R01–R10，也没有缩减任何真实参考、硬件或权威外部材料要求。
