# AD49-S2 root acceptance R1

日期：2026-09-15  
决策：`accepted_limited`  
accepted scope：`g1_g2_factory_identity_typed_absence_probe_only`  
唯一解锁：conditional `AD49-F0-CONDITIONAL-G1-G2-SOURCE-AUTHORITY-FACTORIES`

## Decision

依据 fresh `S2-INDEPENDENT-REVIEW-R1` 的 `pass_limited` 结果，本单接受 AD49-S2 的有限 typed-absence factory identity/construction probe scope。四件产品分别严格闭合为：

- `AbsentG1SourceFactoryIdentityV1`
- `AbsentG1SourceFactoryConstructionReceiptV1`
- `AbsentG2SourceFactoryIdentityV1`
- `AbsentG2SourceFactoryConstructionReceiptV1`

四件产品均为 `status=typed_absent`、`resolution=terminal_deferred`、`no_publish=true`。探针确认当前 G1/G2 没有能同时消费 S1 independent locator、AD45 common `QualifiedRefV1/v5` handle、各自 public 五字段 `GenomeContractRef` 与 typed source/declaration input，并输出 candidate-handle-bound source declaration/content hash 和 replayable construction receipt 的 layer factory。G2 `GenomeContractRef -> QualifiedRefV1` mapping 仍 absent。

本接受不把 G1/G2 declaration constructor/receipt、parent generic `SourceLocatorV1`/`FactoryConstructionReceiptV1` scaffold、G3 factory、fixture/seed/URI、测试或 runner exit 当作 G1/G2 factory identity。探针没有创建 factory、source declaration、source/content/declaration/construction/candidate/final hash、candidate identity、trusted identity 或 mapping。

唯一允许的后续动作是 parent 在自身决策后有条件派发 AD49-F0。F0 必须 additive、保持 G1/G2 类型域和公共 `GenomeContractRef` 五字段，并在实现后重新执行 fresh S2；F0 实现不能把当前 S1 `AbsentG1IndependentSourceLocatorV1`/`AbsentG2IndependentSourceLocatorV1`（working-tree snapshot 非 authority）改解释为 Present，也不能由本验收生成 locator、source authority、identity 或 mapping。

## Frozen product and review hashes

| evidence | bytes | SHA-256 |
|---|---:|---|
| `G1-FACTORY-PROBE/g1_factory_identity_probe_v1.json` | 6340 | `33477cd1a194c1579de52f61887ba23e1081504fa4963a2a4b93f5ffa5274531` |
| `G1-FACTORY-PROBE/g1_factory_construction_probe_receipt.json` | 4353 | `59f30dc0ccea7ad1f6be98b96f59bfb550aff5679f1bfa19bbeba2fd472110c4` |
| `G2-FACTORY-PROBE/g2_factory_identity_probe_v1.json` | 6320 | `dc5700c43941a325e2738fdb37e3e3066deeecc1d3540c3dc0904fcdc6b5e6a2` |
| `G2-FACTORY-PROBE/g2_factory_construction_probe_receipt.json` | 4393 | `73d703f200425106c8e5e32dee415d61e97cba3927b175187fddba8a76c25a26` |
| `S2-INDEPENDENT-REVIEW-R1/report.md` | 3923 | `9e51ac7584c8f79d83f78c6796b608fdff771bdf1afa1002e882be911e19985` |
| `S2-INDEPENDENT-REVIEW-R1/manifest.json` | 1659 | `e36c196ff6fdad973b8d3347d2bfed4f2eaaea4a9028856012d03e3b0f917851` |
| `S2-INDEPENDENT-REVIEW-R1/archive/direct_validation.json` | 31317 | `374ae3b330427ae5e05572aedff916c1e8ffa1dfbbd2919d1f95e323da49783f` |

S2 review direct validation 为 71/71 pass，Python `3.13.5`，exit `0`；plan validator exit `0`；scoped `git diff --check` exit `0`。未运行 Julia/DESC/provider/mesh/solver/engineering/physics/search。

## Upstream identity boundary

S1 root acceptance 的四件 locator 产品仍为 typed absence：

| evidence | bytes | SHA-256 |
|---|---:|---|
| `G1-SOURCE-LOCATOR/g1_source_locator_v1.json` | 5309 | `840ec00d25e069b13af1562a9e4ebb7ab1b2896a0818dc1fa15a3c7167c770a5` |
| `G1-SOURCE-LOCATOR/g1_source_locator_receipt.json` | 9341 | `91fcbcc2e93f586d913ee260e85cad39045b0aab77087e54c8137e652a2e79d3` |
| `G2-SOURCE-LOCATOR/g2_source_locator_v1.json` | 5324 | `439a2d496be0e7c6bd8bbefb7790f4f45f577e7b3954901a5914a5276b5294fa` |
| `G2-SOURCE-LOCATOR/g2_source_locator_receipt.json` | 9341 | `1145085a95a5b5d77bd5e5dfb4f5d629f0cdab9f333883f75f268ff597d9f90b` |
| `S1-INDEPENDENT-REVIEW-R1/report.md` | 3454 | `7b19b96fa5d84c7f344b05851422e3cbe80005b8ac06a551d98544a6d9031337` |

AD45 common handle remains the accepted temporary `QualifiedRefV1/v5` only; its envelope is 9612 bytes, SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`. It is not a final candidate identity or source authority. Current protected G1/G2 source and registry bytes rehash as:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | 30773 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/Contracts/GenomeContractRegistry.jl` | 2389 | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` |
| `src/IR/OperatorRegistry.jl` | 64932 | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |

G1/G2 declaration files remain working-tree snapshots with HEAD absence recorded by S1; their bytes cannot be promoted to committed source authority. The registries remain unchanged.

## Credit and limits

`factory_implementation=false`, `source_authority=false`, `trusted_source_identity=false`, `candidate_identity=false`, `declaration_hash=false`, `candidate_hash=false`, `g2_mapping=false`, `t0=false`, `t1=false`, `t2=false`, `provider=false`, `mesh=false`, `solver=false`, `engineering=false`, `physics=false`, `search=false`, `R01-R10=false`, `L4_credible_count=0`。

本 root acceptance 只接受 probe 的软件 typed-absence 观察；不改变 AD49-S1、AD45、G1/G2 source/registry、四件 probe、S2 independent review、task manifest 或任何其他目录。
