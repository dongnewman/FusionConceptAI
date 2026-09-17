# AD48 fresh S2 root acceptance R2

日期：2026-09-16  
决策：`accepted_limited`  
accepted scope：`four_scope_g3_source_stage_factory_identity_and_construction_receipts_software_only`  
唯一解锁：formal `AD48-S3`

## Decision

依据独立复核 R2 的 corrected `pass_limited` 结果，root 接受 AD48 fresh S2 的四 scope G3 source-stage factory identity 与 construction receipt 软件观察。四个 scope（`realization`、`control`、`binding`、`bundle`）各自都有 `PresentG3FactoryIdentityV1` 与 `PresentG3FactoryConstructionReceiptV1`，八件产品的路径、字节数和 SHA-256 与 `archive/repair_r2_final_snapshot.json` 及 S2 manifest 闭合。

R1 独立复核曾为 `changes_requested`，唯一 blocker 是当时缺少 `archive/repair_r2_final_snapshot.json`。修复后 R2 确认 snapshot 存在并完成 fresh `126/126` integrity；R2 自有直接检查为 `100/100`，无失败项。R2 也复核了真实四 scope inputs、AD45 exact handle/envelope、source-stage binding/declaration/content hashes、Git freshness、replay 与 negative controls，并确认旧 S2 与 R1 raw 未改变。

本接受的 construction receipt 是可审计的软件构造凭证，不是 trusted attestation。它不生成 trusted source authority、candidate identity、final candidate/package identity 或 final hash。它也不授予 T0/T1/T2、provider、mesh、solver、engineering、physics、search、R01-R10 或 L4 credit。

## Frozen products and repair snapshot

| scope | product | bytes | SHA-256 |
|---|---|---:|---|
| realization | `realization/factory_identity_v1.json` | 5054 | `a2062990891bc8152cf5b9cff3dd0b264f6c54e81c0adbf8e535996be25ffcd2` |
| realization | `realization/construction_receipt.json` | 8985 | `e9575af7caa04425ef1976894399d308408cec992aea96c204a5726ed646c497` |
| control | `control/factory_identity_v1.json` | 4998 | `0ca704332016b0aece8f175a8516a7811625238d47c0791d79e68f511f77c66e` |
| control | `control/construction_receipt.json` | 8849 | `d26d68c13cad410e33989cf862b4dfe41bedc5d191988ecf38e6722e46bef217` |
| binding | `binding/factory_identity_v1.json` | 5017 | `5b46247a961d4c457b3f73bf138d8c376a6fa163c90b09e85eb6ff6d7294e176` |
| binding | `binding/construction_receipt.json` | 8906 | `d3d09c789afbdfefc48e9adc1ed5732e7965318853d57608a3fcb4c9b1be0f1b` |
| bundle | `bundle/factory_identity_v1.json` | 4994 | `a9b999447766723e0c3c3a2b3b3f3b9644b1db15de63a819913d842409f8c251` |
| bundle | `bundle/construction_receipt.json` | 8848 | `2b56b5d55010e4a2656bf3c85fb19c962534d412eaa65672ca741507c28a9edb` |
| all scopes | `archive/repair_r2_final_snapshot.json` | 6299 | `ddafe940d8f7ed2d9c5f3083bec85284312de6acd824d8f3e997d5575e37db3b` |

## Review receipts

| evidence | bytes | SHA-256 | result |
|---|---:|---|---|
| `independent_review_r1/report.md` | 7847 | `4bd94ba7fffc47e394417c6e8dcc7acbc65eab46a0061967a090ca86f941fa2c` | `changes_requested` |
| `independent_review_r1/manifest.json` | 3542 | `2b95650c90d1e0c90bb4a2cbb88d2bac8be5bb885b672b8e2f093626a867255c` | `changes_requested` |
| `independent_review_r2/report.md` | 2250 | `aff7a7fefe67cc29e2fc025cccff6c139a9a602f6eaa9eae4e4283892dc0a05d` | corrected `pass_limited` |
| `independent_review_r2/manifest.json` | 3540 | `38385a4adaa7bd90b36e4aa47c3edccf73aa4aa66ecf7942bf2f54d30a28dbe8` | corrected `pass_limited` |
| `independent_review_r2/raw/direct_validation.json` | 30000 | `fa9f1e79c7851706d9ed0bf65157f0835d989538ac20d7993c98602e392cc284` | 100/100 |
| `independent_review_r2/raw/final_scope_check.json` | 37805 | `c2dbcbeb1fba27e36544b6c1e0f0334c78aee487c68ebae7d618d954c78bc263` | scope/immutability pass |

R2 fresh integrity was Python `3.13.5`, PID `81768`, exit `0`, `126/126`; plan validator exit `0`; scoped `git diff --check` exit `0`. Julia/DESC/provider/mesh/solver/engineering/physics/search were not run.

## Acceptance boundary

Only formal S3 is unlocked. This acceptance does not claim or create:

`trusted_attestation=false`, `candidate_identity=false`, `final_candidate_or_package_declaration_hash=false`, `T0=false`, `T1=false`, `T2=false`, `provider=false`, `physics=false`, `R01-R10=false`, `L4_credible_count=0`.

The eight products, repair snapshot, R1/R2 review records, S1/AD45 inputs, source declarations, registries, tests, fixtures and all other task history remain protected inputs.
