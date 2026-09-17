# AD-47 G3 source-authority records — independent review R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high`  
结论：`pass_limited`  
范围：只复核 AD47-G3-SOURCE-AUTHORITY-RECORDS W1 的八个 JSON 产品、输入闭合、absence/fail-closed 语义、路径与哈希重放；不授予 source authority 或父目标信用。

## 冻结基线

仓库为 `D:\006-Programing\LMC\FusionConceptAI`，观察 HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。G3 源、测试、fixture 与本 W1 目录均为当前 working-tree 的 untracked 内容；`git ls-files` 对代表性 G3 source 返回 absent，未把 working-tree bytes 误报为 committed HEAD source。既有 dirty worktree 保留。

八个被审产品逐字节匹配任务给出的冻结值：

| scope | record | authority receipt |
|---|---|---|
| realization | 6303 bytes, `67b90ef6faf6ca4691d9e17294a53e31f8f15337f67001b76920929246338645` | 7612 bytes, `fba00a23ae5c26bc7d19e9eb0c506f05af465728043cf5c552a9fe439559c7bf` |
| control | 6221 bytes, `ac9d72bfd3b01812407bac148c3e1f4b441f67897ce379aaa95a786c8c9305a7` | 7528 bytes, `69b30001434c72ce8c9796ba51aba9c604e90d937c37f49157da680fc85ab154` |
| binding | 6919 bytes, `06768dd5d3182a089f805396d84a2a2853b1d8345cfdf4cb663a98b74f8f7361` | 8924 bytes, `97c27cc50232d1911d3573d2578268c83eb3540f62ca261075efd19f534e1dff` |
| bundle | 5972 bytes, `cd74ea290aee5518005408496844e04d0f8c52e21c9aacc06d85e1b54a3f7653` | 7052 bytes, `78087a9fa7f917766f460141db2a8fb5154da0af58a7f5d206c3ee14cc689d07` |

## 复核结果

Python 3.13.5 (`D:\Users\Newman\anaconda3\python.exe`), PID `81064`, UTC `2026-09-15T12:34:15.533978+00:00` 的独立直接检查为 `156/156`、exit `0`。它重算了 JSON 解析、record/receipt bytes 与 SHA-256、canonical semantic hash、receipt 对 record 的引用、source locator 文件 bytes/SHA、working-tree `absent_untracked` 与 `head_blob_sha256=null`。

四个 scope 都精确满足：

- record=`G3SourceAuthorityRecordV1`、result=`AbsentG3SourceAuthorityRecordV1`；receipt=`G3SourceAuthorityReceiptV1`、result=`AbsentG3SourceAuthorityReceiptV1`。
- absence reason=`missing_source_locator_factory_identity_and_trusted_attestation`，resolution=`terminal_deferred`，`no_publish=true`。
- AD-45 `QualifiedRefV1` 仅是 `common_candidate_binding_handle_only`；`candidate_identity_created=false`，没有 declaration/content/final identity hash。
- realization/control 的 source、test 和 precursor receipts，binding 的 source、test、fixture、static QA 和 precursor receipts，以及 bundle/feedback source 与 AD-44/AD-45 输入均按产品内 locator 复核；所有 locator bytes/SHA 与当前文件匹配。
- record semantic body 的 canonical SHA 与记录一致；receipt 中 record bytes/SHA/semantic hash 与对应 record 一致；四个 source scope 的 HEAD blob 均为 null。

四个 receipt 的负控也逐项保持：fixture/seed/W2R1/URI/bundle hash/own hash 派生为 `FailedG3SourceAuthorityRecordV1`；缺 factory 或 identity 为 `AbsentG3SourceAuthorityRecordV1`；source mutation 要求 `new_identity_input_required`。记录中的 candidate/declaration/factory/provider/mesh/solver/T0/T1/T2/engineering/physical/search/R01–R10 等 exclusion 均为 false 或零。没有运行 Julia、DESC、mesh、solver、provider、工程或物理计算。

规划校验重新通过：31 markdown、497 relative links、39 tasks、DAG acyclic，exit `0`；作用域 `git diff --check` exit `0`。这些是文档和工程卫生证据，不是物理或工程证据。一次先行直接校验因复核脚本自身未闭合的 f-string/index 表达式 exit `1`，已作为 `direct_validation_attempt1_failed.json` 保留；未读取或修改被审产品，修正后的独立检查通过。

## 缺口裁决与派单边界

W1 的 typed-absence 结论是诚实且内部闭合的 `pass_limited`，但不表示四个 source authority 已存在。当前长期阻塞应拆为可执行的有限工作单，而不是由 W1 一项混合关闭：

1. source locator gate：为每个 scope 冻结真实 source locator、working-tree/HEAD 状态和 exact bytes/SHA；只允许 `PresentLocator` 或 typed absence，不能发布 authority。
2. factory identity gate：冻结可重放的 factory identity、construction receipt 和 semantic/declaration/content hash 生成输入；缺 locator 时保持 terminal deferred，禁止从 fixture、seed、URI 或自身 hash 推导。
3. trusted attestation/source identity gate：由独立复核确认 source identity、candidate-owned input 和 trusted attestation；未同时满足前继续 no-publish。

三门通过后，再另行重建 fresh candidate identity、G3 candidate-bound 四轴、child join 和 feedback authority。W1 的八个 absence receipts 不能被后续工作单当作 present authority，也不能把 AD-45 临时 handle 提升为最终 candidate identity。

## 信用上限

本复核只接受 W1 产品的静态软件 provenance/typed-absence closure，判定 `pass_limited`。它不授予 G3 source authority、source-backed declaration、candidate binding、四轴 attestation、feedback authority、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4 credit；当前仍 `false/0`。
