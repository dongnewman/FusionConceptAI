# CORE-STATUS-SYNC-AD42-AD48

日期：2026-09-15  
决策：`accepted_limited`（核心状态同步；不新增机器节点）  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
task manifest SHA-256：`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`  

## 同步边界

本次只修改五个核心索引/合同文件，并把验证 raw 收据写入本任务的 `status/raw/`。AD-42 W2R1 仅为 fresh canonical G1/G2 source authoring；AD-43 仅为通用 G1/G2 四轴软件合同。AD-44 W3-A 仅覆盖 untracked working-tree repository-design source provenance，W3-B blocked。AD-45 A 的 common `QualifiedRefV1/v5` 仅作临时 G1/G2 handle；AD-46 的三层 identity input、join、materialization 均 blocked。

AD-47 W0 是 additive G3 axis software contract 与 source-byte/hash closure；W1 是 realization/control/binding/bundle 四 scope 的八个 typed-absence 软件 source-provenance 产品，不授 G3 source authority。AD-48 S1 只接受 current untracked working-tree source locators。S2 factory probe 产品已落盘但尚未验收，状态保持 `in_progress`/`pending`；只有不同 Luna 独立确认 `AbsentG3FactoryIdentityV1` 后才允许条件 F0，随后必须 fresh S2 → S3 → fresh W1 → W2。

正式主线仍为 `T0 → authority recheck → T1 → T2 → aggregate → UP2 → UP3 → UP4 → UP5 → UP6`。UP3–UP6 仍是准备/待正式运行；provider、mesh、solver、engineering、physical、search、R01–R10 均为 false，L4=0。文档、测试、代理、规划器和 runner exit 只属于软件/工程卫生证据，不能替代物理证据。

## 关键验收与复核索引

- [AD-42 W2R1 acceptance](../AD-42/W2R1-ACCEPTANCE/acceptance.md)；[W2R1 independent review R1](../AD-42/W2R1-INDEPENDENT-REVIEW-R1/report.md)。
- [AD-43 acceptance](../AD-43/acceptance/acceptance.md)；[AD-43 status independent review](../AD-43/acceptance/independent_status_review_r1/report.md)。
- [AD-44 W3-A acceptance](../AD-44/RSDA-W3-A-ACCEPTANCE/acceptance.md)；[W3-A independent review R2](../AD-44/RSDA-W3-A-INDEPENDENT-REVIEW-R2/report.md)；[W3 readiness independent review](../AD-44/rsda_w3_readiness_audit/independent_review_r1/report.md)。
- [AD-45 A acceptance](../AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/acceptance/acceptance.md)；[AD-45 A independent review R2](../AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/independent_review_r2/report.md)。
- [AD-46 acceptance](../AD-46/trilayer_candidate_identity_owner_audit/acceptance/acceptance.md)；[AD-46 independent review R2](../AD-46/trilayer_candidate_identity_owner_audit/independent_review_r2/report.md)。
- [AD-47 W0 acceptance](../AD-47/G3-AXIS-SCHEMA-VERSIONED-EXTENSION/acceptance/acceptance.md)；[W0 independent review R2](../AD-47/G3-AXIS-SCHEMA-VERSIONED-EXTENSION/independent_review_r2/report.md)；[AD-47 W1 acceptance](../AD-47/G3-SOURCE-AUTHORITY-RECORDS/acceptance/acceptance.md)；[W1 independent review R1](../AD-47/G3-SOURCE-AUTHORITY-RECORDS/independent_review_r1/report.md)。
- [AD-48 topology acceptance](../AD-48/g3_source_authority_gap_decomposition/acceptance/acceptance.md)；[topology independent review R2](../AD-48/g3_source_authority_gap_decomposition/independent_review_r2/report.md)；[AD-48 S1 acceptance](../AD-48/S1-SOURCE-LOCATORS/acceptance/acceptance.md)；[S1 independent review R1](../AD-48/S1-SOURCE-LOCATORS/independent_review_r1/report.md)；[S2 pending products](../AD-48/S2-FACTORY-IDENTITIES/)。

## Verification

The final planning validator used `D:\Users\Newman\anaconda3\python.exe` / Python 3.13.5, PID `84812`, UTC `2026-09-15T13:30:47.9159280Z`–`2026-09-15T13:30:48.7448830Z`, exit `0`. It reported 31 markdown files, 526 relative links, 39 tasks and an acyclic DAG. Raw stdout/stderr and receipt are under [status/raw](status/raw/).

The direct status consistency check used wrapper PID `51956`, UTC `2026-09-15T13:27:43.4928982Z`–`2026-09-15T13:27:43.6372371Z`, exit `0`. It verified all five core files, AD-42–AD-48 markers, claim ceiling, exact task-manifest SHA, 39 tasks, all four S2 `AbsentG3FactoryIdentityV1` products and the absence of an S2 acceptance. Scoped `git diff --check` exited `0`; Git emitted only the existing LF/CRLF normalization warning for the tracked README. No Julia/DESC/provider/mesh/solver/engineering/physics/search run was performed.

The five core products and their final byte/SHA snapshot are recorded in `manifest.json`. No source, test, fixture, run, task manifest, registry or existing implementation product was modified by this synchronization.
