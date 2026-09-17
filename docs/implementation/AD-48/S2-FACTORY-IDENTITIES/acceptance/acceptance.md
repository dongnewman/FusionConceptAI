# AD48-S2 G3 factory identity probe acceptance

日期：2026-09-15  
决策：`accepted_limited`  
范围：仅接受四个 scope 的八个 typed-absence factory probe 产品及其 source-hash closure。该决策证明 AD48-F0 的条件触发合法，不证明 G3 factory、source authority、trusted attestation、candidate identity、T0/T1/T2、物理能力或 R01–R10。

## 冻结产品

冻结输入为 `archive/repair_r2_final_snapshot.json`。八个产品均为 canonical compact JSON、无尾部换行、SHA-256 长度 64；四个 scope 均为 `AbsentG3FactoryIdentityV1` 与 `AbsentG3FactoryConstructionReceiptV1`，`terminal_deferred`、`no_publish=true`、`candidate_identity_created=false`。

| scope | factory identity | construction receipt |
|---|---|---|
| realization | 2239 bytes, `19ea4b7ec669da116c09293afa8e861de47650c83a756670d906f048a67cb1fd` | 2010 bytes, `e8ed40a06adf41ffc7f54ad83ad400ef7fc2c43d4047b8abb9e4819513fe87ee` |
| control | 2149 bytes, `2f6f3cbf4c31aaf893f070df9909b21be859062cbfa697fc76886b6906980021` | 1938 bytes, `cf01d5a328cee5d9d60a8c88d08a433be3b4567d2990cf63a34a23b6fcccc8a0` |
| binding | 2232 bytes, `05ae8d811483cde640c2c8b5dcf1ec167a4d0dc9f39c7616d01e99fd9085e624` | 1990 bytes, `3195387030f73cf6d3717902bc3242e24b68afef81e166002c6347115cad1bbf` |
| bundle | 2988 bytes, `9c33dee9ff48ef8c34afe9f08f5a23e4f08d849a39bd11bb366aceedabf28807` | 2818 bytes, `8faff2c23c017ab6801d4c4bb8a6a5eaeb6531a23d6b5d210b25386be236ca36` |

## 独立复核与边界

不同 Luna 的 R1 `changes_requested` 已由 repair_r2 修复；R2 以 `pass_limited` 复核，47 项直接检查通过，确认 bundle 6704-byte source 的实际 SHA 为 `8e9d4f1505098b745048a5f741e0cb1edcccdcf70a395c212f0a8649a73d62a4`，并确认 identity、receipt、source closure 与 S1 locator 交叉闭合。R1 报告和失败 raw 保留在 `independent_review_r1/` 及旧 archive。

静态检索与串行 Julia 1.10.5 probe 均未发现 `G3SourceAuthorityFactoryV1` 或满足“消费独立 locator、生成 candidate-bound declaration、发出可信 construction receipt”的入口。`SourceLocatorV1` 与 `FactoryConstructionReceiptV1` 仅在 parent typed-absence scaffold 中出现，不能视为 G3 factory。没有 registry 修改。

本次接受不产生 semantic/content/candidate/final identity hash；这些字段在 absence 结果中保持未创建。接受不授予 source authority、factory identity、trusted attestation、candidate/T0/T1/T2、provider、mesh、solver、engineering、physics、search、R01–R10 或 L4 信用。

## 条件后续

R2 通过后，AD48-F0 factory-definition probe 的条件触发合法。F0 完成后必须重新生成 fresh S2 八产品并再次独立复核，之后才能考虑 S3、fresh W1 或 W2。F0 本身也不能被写成 present factory 或 source authority。

本次 status sync 仅新增 acceptance 文档、manifest 和 `status_sync_r1/raw/**`；未修改八个冻结产品、R1/R2、源码、测试、fixture、registry、核心目录或 task manifest。
