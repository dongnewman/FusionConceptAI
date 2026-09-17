# UP1-02 G2 V5 合同实现交付

状态：`accepted`。接受范围严格限定为 `axis_aligned_rational_3d_g2_structural_contract`；本单交付 G2 的结构合同、确定性 plan 构造、可编辑 hash 传播和负例 admission，不宣称 B04 compile-before-provider/provider counter、mesh execution、物理求解、工程能力、收敛或 R01–R10 信用。`B04=false`、`mesh=false`、`physical=false`。

## 范围与合同

输入合同为 [19_up0_02_contract_freeze.md](../../v4_multitopology_generation/19_up0_02_contract_freeze.md) 与 [up0_02_protocol.json](../../v4_multitopology_generation/up0_02_protocol.json)，其 G2 类型为 `FieldGeometryGenomeV5`，四版本轴分别保留 payload schema、canonicalization、applicability 和 evidence receipt。外部 G2 `GenomeContractRef` 独立携带 `v5` contract identity；V4 Genome 不被隐式转换。

实现的唯一源码路径是 `src/GenomeV5/G2/` 下四个文件。`SpatialGrammarProfileV2` 只保存 G2 结构 applicability；`RegionInterfaceContractV2` 保存 3D region 与有向 interface；`FieldSpacePlanV2` 保存 chart、embedding、field-space、mesh 和 exterior plan；`FieldGeometryGenomeV5` 进行 candidate-bound admission、provider gap、plan hash/candidate hash 和 interface/mesh 编辑。没有写 `src/FusionConceptAI.jl`，因此本交付不改变共享入口或默认 registry。

最小合法配置包含两个三维 region：`[0,1]×[0,1]×[0,1]` 与 `[1,2]×[0,1]×[0,1]`，接口为 `x=1`、`normal=+x`、trace/flux continuity；另有 `[0,2]×[0,1/2]×[0,1]` 与 `[0,2]×[1/2,1]×[0,1]` 的 `y=1/2` 合法方案。两者均为结构合同样本，mesh quadrature/provider 保持待定。

## 真实实现与负例

`g2_admission` 对 region ref、chart/embedding/field-space ownership、3D bounds、接口共面与切向正重叠、`normal=+1`、trace/flux continuity、conservative transfer、mesh/exterior ownership 做 fail-closed 检查。接口面不重合和方向错误分别产生 `interface_faces_do_not_coincide`、`interface_orientation_mismatch`；缺 provider 保留 `structural_status=:valid`，但输出 `provider_match=:no_match`、`resolution=:terminal_deferred`。编辑 `g2_edit_interface` 或 `g2_edit_mesh_cells` 会重建 plan hash 与 candidate hash。

测试文件只登记上述结构正例、非重合接口、方向错误、provider 缺口、版本/维度负例；`fixtures.json` 是可审计输入样本。串行 focused test 的 r6 历史运行及 r7 最终运行均已留存并 exit=0；未运行 DESC、mesh 后端或物理 solver，故没有物理 evidence。

唯一 focused recipe（串行，r6 与 r7 均按此执行）：

```powershell
julia --project=. test/GenomeV5/G2/up1_g2_contract_tests.jl
```

退出门：focused test 必须证明两种合法 3D interface structural admission、非重合/错方向 fail-closed、无 provider `terminal_deferred`、V4 不隐式迁移，以及 interface/mesh edit 同时改变 plan/candidate hash；独立 reviewer 需检查本单没有越界写入或物理信用。

## 保护与未验证事实

写前八个 UP1-02 目标文件均为 `MISSING`；既有合同和 V4/SpatialRuntime 源文件只读。实现未触碰 G1/G3、旧源码、`default_operator_registry`、既有 dirty tests、runs、queue 或核心索引。r7 已验证该专属 focused test 的 Julia 运行和受控 schema/profile hash 检查；包入口集成、provider hash/调用、mesh 几何可执行性和物理求解仍未验证。

输入 SHA-256：19=`5332f0c7a5c215948254a536c93e945caa019143dfd5ab3c595af9b0091b9efb`；protocol=`6904ea161a27ff007a071697f7740ad923ce79d05e23433d356460546ecd7bfb`；现行 G2 Genome=`ed8dfc25c13e85b9720fdb93f43d9075494b383209e82b8be5c24d54ec306725`；SpatialSupport=`54f18db33e8698ba876dcc79c952596bae25d84b64e35a4714dc2a63c77cd405`；G2 primitives=`8054a1b127f3d0a6e3db1cd651bbbe8c90d8d78d26bfab85e3d7b71da326fef5`；SpatialMultiRegion=`cac5b47beeee2fbab7de6f171f7f155ff5534bc51edec0e66ee8caf711d6b932`；SpatialRuntime=`c71c90090c5401c1e71cc13b319dff45b7a70d273e17f4687be1a91a8be310bb`；SpatialExecutionTypes=`995de2eb6365685328d4600049c32042e143ddb66537792f985a8b90cdb4b96c`；module entry=`a7ad18c87f0f8c8ac324cfe90c0cb7616bdd22277b4f6e926557c01195c507ef`。

## 独立复核退回与补修边界

历史阶段记录：Sol 当时裁决本单独立复核为 `changes_requested`，并要求继续 `review_pending`、`accepted=false`。本轮只在原八个 UP1-02 文件内补修：同一 admission 现在区分并拒绝 region 体积重叠、零/重复/缺失 interface、切向覆盖不完整和未闭合外边界；`G2AdmissionResultV2` 分开报告 `structural_status`、`geometry_status`、`mesh_status=:not_executed` 和 `physical_status=:not_executed`。

外部 `GenomeContractRef` 现在必须匹配由受控字段/约束描述生成的 `g2_schema_hash()`、`g2_canonicalization_hash()` 和 profile hash token；四版本轴绑定 `fusion.g2.*` 的 `v5` ref 域，内部 G2 refs 绑定 `v2` 域。fixture 已由 focused test 读取，负控覆盖新失败分类。包围盒与接口合同检查只证明结构/几何约束的 admission 行为，不能称为 mesh 可执行性或物理证明。

补修后 r6 已运行 Julia focused recipe 并 exit=0，仍未运行 DESC；该段原要求另一 Luna（high）重新只读核对 changes_requested 项，最终复核结果见下方。

## 第二轮退回后的静态补修

fixture 现在完整驱动 `split_x_1` 与 `split_y_half` 两个合法三维 region/interface/plan，逐项驱动全部负控 mutation，并断言 schema、canonicalization、profile hash 重算结果。G2 profile 的三个内部 QualifiedRefV1 绑定到精确 `fusion.g2.*-profile` 域，四个版本轴绑定到 fixture 中的 `v5` 域；错误 external hash、错误轴 ID 和错误内部 profile ref 均为 constructor fail-closed 负控。

`G2ExteriorPlanV2` 记录实际多 region face patches；admission 用精确二维面片分区检查外边界覆盖、重叠与断裂，并拒绝重复 `boundary_region_ids`。这仍是结构/几何合同证据，不能称 mesh 可执行性、provider invocation 或 B04 compile-before-provider 证据；这些门明确 pending UP1-04。该阶段曾为 `review_pending`、`accepted=false`、claim `none/contract_only`，未运行 DESC/mesh/solver。

## 串行 focused run 审计

按冻结分类保留了 `invalid_boundary|invalid_closure`、`invalid_closure`、`invalid_boundary`、`terminal_deferred` 与 `constructor_reject`；`expected_detail` 只登记预先定义的确定性 admission 细节。r1 exit=1 是 JSON3 整数适配缺口；r2/r4 的三项失败来自临时 detail-code 断言（接口 detail 含 ID 后缀，provider 是 gap/resolution 而非 errors），不是物理或 B04 结果；r3 exit=1 是诊断用 `@testset` 宏参数写法；r5 保留为临时 detail-code 草稿通过；恢复冻结分类后的 r6 exit=0，合法 57/57、负控 54/54、边界 8/8。所有 stdout/stderr/exit 均在本目录 `focused_test.r1.*` 至 `focused_test.r6.*` 保存，详情见 `evidence_manifest.json` 的 `run_history` 与 `classification_audit`。

r6 仅证明合同代码与负控映射可运行；provider invocation counter、B04 compile-before-provider、mesh 执行和物理求解仍为 pending/未执行。

## 最后一个外边界重叠负控

为覆盖既有 validator 的 `exterior_face_patch_overlap` 分支，`fixtures.json` 增加真实 `exterior_patch_overlap` mutation：以 `split_y_half` 为基例复制 `z_min/left` 的正面积外边界片，使同一外侧面片发生正面积重叠；预注册分类保持 `invalid_boundary`，细节保持 `exterior_face_patch_overlap:z_min`，没有调整规范阈值。r7 按同一串行 recipe 运行并 exit=0：合法 57/57、负控 59/59、边界 8/8；该负控证明 admission fail-closed 且 mesh/physical 仍为 `not_executed`。r1-r6 日志保留，r7 日志与退出文件见 `evidence_manifest.json`。该阶段只产生软件合同证据，不产生 B04、provider、工程或物理信用。
为覆盖既有 validator 的 `exterior_face_patch_overlap` 分支，`fixtures.json` 增加真实 `exterior_patch_overlap` mutation：以 `split_y_half` 为基例复制 `z_min/left` 的正面积外边界片，使同一外侧面片发生正面积重叠；预注册分类保持 `invalid_boundary`，细节保持 `exterior_face_patch_overlap:z_min`，没有调整规范阈值。r7 按同一串行 recipe 运行并 exit=0：合法 57/57、负控 59/59、边界 8/8；该负控证明 admission fail-closed 且 mesh/physical 仍为 `not_executed`。r1-r6 日志保留，r7 日志与退出文件见 `evidence_manifest.json`。

## 最终独立复核与 Sol 验收

不同 Luna 完成最终独立复核并通过：复核了四层 G2 schema 与实际字段、JSON fixture 驱动、region/interface/exterior patch fail-closed、版本轴与 candidate binding、可编辑 plan/hash 传播及 evidence boundary。r7 三个 testset 合计 124/124，日志、退出码和哈希已登记在 manifest。Sol 据此接受上述有限软件合同范围；UP1-04 仍为 `planned`，UP1-01 与 UP1-03 不因本单改变状态，B04/provider counter、mesh、physical/engineering 和 R01–R10 信用均保持未接受。
