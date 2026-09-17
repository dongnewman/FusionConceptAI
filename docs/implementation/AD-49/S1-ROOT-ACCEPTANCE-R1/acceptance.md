# AD49-S1 root acceptance R1

日期：2026-09-15  
决策：`accepted_limited`  
accepted scope：`g1_g2_independent_source_locator_typed_absence_only`

## Decision

依据 fresh `S1-INDEPENDENT-REVIEW-R1` 的 `pass_limited` 结果，本单接受 AD49-S1 的有限 typed-absence locator scope。唯一解锁项为 `AD49-S2` factory identity probe；S2 仍须按自身合同和独立复核执行。

审查确认仓库根为 `D:/006-Programing/LMC/FusionConceptAI`，HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。G1 源 `src/GenomeV5/G1/DiffusionDeclarationV1.jl`（31743 bytes，SHA-256 `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`）与 G2 源 `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl`（30773 bytes，SHA-256 `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61`）均为 `??` working-tree 文件；两者 `git ls-files --error-unmatch` 均 exit `1`，`git cat-file -e HEAD:path` 均 exit `128`，因此不能构成 committed source authority。

四件 S1 根产品正确闭合为 `AbsentG1IndependentSourceLocatorV1` / `AbsentG2IndependentSourceLocatorV1`，均为 `typed_absent`、`terminal_deferred`、`locator=null`，并明确声明 working-tree snapshot 不是 independent authority。失败命令回显未被解释为 blob；无 `GG1`/`GG2` union。该接受记录不发布 source authority，也不创建声明、identity 或 candidate hash。

此前两次容量不足的调度尝试仅属于 dispatch history；它们没有产生审查结论、产品或证据，不影响本次 fresh review 和本决策。

## Frozen product hashes

| product | bytes | SHA-256 |
|---|---:|---|
| `docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json` | 5309 | `840ec00d25e069b13af1562a9e4ebb7ab1b2896a0818dc1fa15a3c7167c770a5` |
| `docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_receipt.json` | 9341 | `91fcbcc2e93f586d913ee260e85cad39045b0aab77087e54c8137e652a2e79d3` |
| `docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json` | 5324 | `439a2d496be0e7c6bd8bbefb7790f4f45f577e7b3954901a5914a5276b5294fa` |
| `docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_receipt.json` | 9341 | `1145085a95a5b5d77bd5e5dfb4f5d629f0cdab9f333883f75f268ff597d9f90b` |

Fresh review evidence is [S1 R1 report](../S1-INDEPENDENT-REVIEW-R1/report.md), SHA-256 `7b19b96fa5d84c7f344b05851422e3cbe80005b8ac06a551d98544a6d9031337`; its direct validator is SHA-256 `a15c4e6e8d3d7ccc89f094be716599a7fc3a0095ed868709288bdae73cc7d4d6` and final scope receipt is SHA-256 `e165b1b317709a76bb014aab28acee035b2ad1e8021eeab7ff41140f9bcfb720`.

## Credit and limits

`source_authority=false`, `factory_implementation=false`, `candidate_identity=false`, `declaration_hash=false`, `candidate_hash=false`, `g2_mapping=false`, `t0=false`, `t1=false`, `t2=false`, `provider=false`, `mesh=false`, `solver=false`, `engineering=false`, `physics=false`, `R01-R10=false`, `L4_credible_count=0`.

No Julia/DESC/provider/mesh/solver/engineering/physics/search command was run. This root acceptance does not modify the four reviewed products, their archives, source, tests, fixtures, registry, task manifest, or any other directory.
