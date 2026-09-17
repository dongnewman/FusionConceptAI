# AD-49 G1/G2 factory identity readiness limited acceptance

日期：2026-09-15  
决策：`accepted_limited`  
accepted scope：`architecture_readiness_only`  
唯一解锁：`AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS`

本验收依据已冻结的 AD49 根产品、R1 独立复核、R1 repair validation summary 与 fresh R2 独立复核。R1 的 `changes_requested` 已由 R2 fresh recomputation 复核为 `pass_limited`：27 条未来产品路径唯一，W3-B 九条路径完成 G1/G2 目录分离，六个 work-order 具备逐单 machine contract，DAG 无环，且 S1 是唯一最早可派发项。

R2 使用 Python 3.13.5 direct validation，exit `0`；plan validator exit `0`（31 markdown、526 links、39 tasks、DAG acyclic）；scoped `git diff --check` exit `0`。当前 G1/G2 source/test 文件存在于 working tree 但 HEAD absent。AD45 ref 仍仅为 `QualifiedRefV1`/`v5` 的 `common_candidate_binding_handle_only`。

该接受仅允许 parent 派发 S1 locator work order。S1 必须继续把 working-tree snapshot 与 committed source authority 分离；缺失或冲突必须按合同落入 typed `Absent`/`Failed` 分支并保留 raw receipt。

S2 factory probe、F0 conditional source-authority factories、S3 trusted source identity、G2 `GenomeContractRef`→`QualifiedRefV1` mapping，以及 W3-B candidate-bound axes/join 仍分别依赖其锁定的上游和独立复核，未被本验收解锁。任何一个阶段都不能由本验收自动晋升。

本验收不授予 candidate/source authority、factory implementation、identity/hash、mapping、declaration、T0/T1/T2、provider、mesh、solver、engineering、physics、search、R01-R10 或 L4 信用；candidate identity/hash 与 physical claims 仍为 false/zero。

## Frozen evidence hashes

| evidence | bytes | SHA-256 |
|---|---:|---|
| `report.md` | 17583 | `0dd05bde2b272cd15673e8b317b3461dd20cbe4269f811ca0e6e50183cdd0ec2` |
| `manifest.json` | 23532 | `a00dda598ea44d79e5147d148f961c524deb9f7fc8787a2b88779d372b739540` |
| `cleanup_inventory.md` | 1359 | `80f6ac6d3ab360066eddb46df922e8673a133c03d69f8859e350988cd7b02cf5` |
| `archive/validation_summary_r1_repair.json` | 2538 | `1533d1b405b68ee649f84c77fa8cc62e79ea3abe1d4430c584028ff4e8b2782f` |
| `independent_review_r1/report.md` | 8438 | `33862f09dc13695c1a85b7d25606b21b56e91213265f0bdd62ec865d83c98143` |
| `independent_review_r1/manifest.json` | 2553 | `97d40826cbc39598671c3452e84b5cb2f45d160d832d44ad047405c77c104e37` |
| `independent_review_r2/report.md` | 3150 | `46d6bbaa81d1044b49875f5833f6e8053b6f9182e9dbe63c496eb8cb27b713d8` |
| `independent_review_r2/manifest.json` | 5981 | `377eb14a2cb76c211b6eb5fddf6136323a173d942baf7a5537c480cfea710b45` |
| `independent_review_r2/direct_validation.json` | 14939 | `35371957d2f0cf3249a1d9e505fefcf30925249212895151495f65b09c5d5911` |
| `independent_review_r2/final_hashes.json` | 5037 | `ead191ab0247f28079acaf724cad980dffd7729bf9881a41055b7864754c6da9` |

未运行 Julia/DESC/provider/mesh/solver/engineering/physics/search；本验收仅写入本目录的 `acceptance/` 三件产品。
