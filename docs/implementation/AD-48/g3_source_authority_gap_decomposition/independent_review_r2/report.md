# AD-48 G3 source-authority gap decomposition — independent review R2

日期：2026-09-15  
复核模型：different `gpt-5.6-luna/high`  
结论：`pass_limited`  
范围：只复核 AD48 修复后的三个冻结产品、八个 G3 source rows、AD47 W1 输入、三门工作单的依赖和禁止边；未修改被审产品、源码、测试、fixture、核心清单或 registry，未运行 Julia、DESC、provider、mesh、solver、engineering、physics 或 search。

## 修复后的冻结闭合

三个冻结产品逐字节匹配任务给出的值：

| 产品 | bytes | SHA-256 |
|---|---:|---|
| `report.md` | 14214 | `7037300a6207518bf6c1369e1f2642aa9e71eeecb818aeb95e469dc80a2c360f` |
| `manifest.json` | 7228 | `31986f6f401c2b47455f3e287c18247c702cc4b6c0152714c180051fd2f9f2ba` |
| `cleanup_inventory.md` | 827 | `4a17966bd6318b900fa11b6c45bb8e1219606cabb13790c53c385b54026dc801` |

修复后的 `RealizationGenomeV5.jl` 为 33751 bytes，SHA-256 为完整 64 位
`0034f0c494df9a61f6e753d6d0b7f0fbca2d1a21eccf915ad3bba25ca427f6fb`。其余七个源行也逐一满足 manifest 声明的 bytes、SHA 和 64 位长度：control 10297、binding 10904、bundle genome 6704、feedback 27969，以及 realization/control/binding child-editability 分别为 54819/64083/24578 bytes。独立 Python 3.13.5 进程 PID `89684` 的直接重放 exit `0`；raw 收据在 `review/python_direct_replay.json`。

AD47 W1 的八个冻结产品重新逐字节匹配，旧 W1 的 `AbsentG3SourceAuthorityRecordV1`/receipt 语义和 `terminal_deferred` 不被提升。当前 HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`，G3 source 仍是 working-tree 观察内容，不能冒充 committed source authority。

## 三门与条件 F0

S1 仍是四个 scope 各两件 JSON，共 8 件，schema 为 `G3IndependentSourceLocatorV1` / receipt，union 为 Present/Absent/Failed。它冻结 root、HEAD、git 状态、相对路径、exact bytes/SHA、scope closure 和 UTC；不生成 candidate/declaration/final identity，也不从 fixture、seed、URI 或任何自身 hash 派生身份。

S2 仍是四个 scope 各两件 JSON，共 8 件，schema 为 `G3FactoryIdentityV1` / construction receipt，union 为 Present/Absent/Failed。S2 必须使用 S1 locator 与真实构造入口；当前检索没有 G3 source-authority factory、adapter 或相应测试。generic `SourceLocatorV1` 和 `FactoryConstructionReceiptV1` 只存在于 parent typed-absence scaffold，不能被当成 G3 factory。

F0 是严格条件单：只有 S2 先产生 `AbsentG3FactoryIdentityV1` 的真实证据后才能派发。F0 恰拥有两个文件：`src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` 与 `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl`；不得修改 `default_operator_registry()`。F0 完成后必须重新执行 fresh S2，不能沿用旧 absence receipt。

S3 仍是四个 scope 各两件 JSON，共 8 件，schema 为 `G3TrustedSourceIdentityV1` / receipt，union 为 Present/Absent/Failed。独立 Luna 只能提供 repository-local 软件 source identity review，不能声称密码学签名、外部信任、provider、mesh、solver、工程、物理或原创性证据。没有真实 signing/key 机制、candidate-bound input、完整 closure 或 factory receipt 时保持 `Absent` + `terminal_deferred`；root Sol 只接收复核范围。

## 顺序、并行和禁止边

合法顺序为：

`AD47-W1 review → AD48-S1 → AD48-S2 factory probe → 仅当 S2 为 Absent 才能 F0 → fresh S2 → AD48-S3 → fresh W1 八产品 → AD47-W2`。

该顺序无环。S1 可在父审查完成后与 AD47 G3 axis-schema extension 准备并行；F0 不得先于 S2；S2 不得先于 S1；S3 不得先于 S1、S2 和不同 Luna source-identity review；任一 source/factory/attestation 变化后必须重建 fresh W1。旧 W1 产品保持不可变历史记录。

禁止边保持完整：不创建 candidate/declaration/final identity，不重写 AD42–47 产品，不修改源码/测试/fixture/core planning 或 default registry，不运行 T0/T1/T2、UP2、provider、mesh、solver、engineering、physics、search；文档、测试、代理和 runner exit 也不构成物理或工程证据。

## 裁决

R1 指出的 63 位 realization SHA 缺陷已修复并通过 R2 exact hash/length 重放。AD48 的有限 gap decomposition 现在可 `pass_limited` 接受，范围仅为软件 readiness、三门的有限派单和条件 F0 边界。S1 可由父审查后派发；F0 必须等待 S2 的 Absent 证据。当前仍不授予 G3 source authority、factory identity、trusted source identity、candidate binding、四轴、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4 credit；这些保持 `false/0`。
