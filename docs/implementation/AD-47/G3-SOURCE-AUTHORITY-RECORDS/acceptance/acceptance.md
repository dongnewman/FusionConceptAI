# AD47 G3 source-authority records acceptance

日期：2026-09-15  
工作单：`AD47-G3-SOURCE-AUTHORITY-RECORDS`  
decision：`accepted_limited`  
accepted_scope：`eight_typed_absence_software_source_provenance_products_only`

## 裁决

接受 W1 四个 scope 的八件 typed-absence 软件 source provenance 产品的有限闭合。
四个 scope（realization、control、binding、bundle）均为
`AbsentG3SourceAuthorityRecordV1`，对应 receipt 均为
`AbsentG3SourceAuthorityReceiptV1`。缺口是 source locator authority、factory identity、
trusted attestation/source identity；结果保持 `terminal_deferred` 且 `no_publish=true`。

本 acceptance 不把当前 working-tree 源提升为 source authority。所有源仍按
`head_path_status=absent_untracked`、`head_blob_sha256=null` 记录；AD45
`QualifiedRefV1` 仍只是 `common_candidate_binding_handle_only`。没有创建
CandidateIdentity、declaration hash、content/final identity hash 或 G3 candidate binding。

## 冻结产品

| scope | record | authority receipt |
|---|---|---|
| realization | 6303 bytes, `67b90ef6faf6ca4691d9e17294a53e31f8f15337f67001b76920929246338645` | 7612 bytes, `fba00a23ae5c26bc7d19e9eb0c506f05af465728043cf5c552a9fe439559c7bf` |
| control | 6221 bytes, `ac9d72bfd3b01812407bac148c3e1f4b441f67897ce379aaa95a786c8c9305a7` | 7528 bytes, `69b30001434c72ce8c9796ba51aba9c604e90d937c37f49157da680fc85ab154` |
| binding | 6919 bytes, `06768dd5d3182a089f805396d84a2a2853b1d8345cfdf4cb663a98b74f8f7361` | 8924 bytes, `97c27cc50232d1911d3573d2578268c83eb3540f62ca261075efd19f534e1dff` |
| bundle | 5972 bytes, `cd74ea290aee5518005408496844e04d0f8c52e21c9aacc06d85e1b54a3f7653` | 7052 bytes, `78087a9fa7f917766f460141db2a8fb5154da0af58a7f5d206c3ee14cc689d07` |

产品字节和 SHA 未被本 acceptance 改写。独立 different `gpt-5.6-luna/high` R1
为 `pass_limited`，直接复核 `156/156`、Python 3.13.5、PID `81064`、exit `0`；
其报告和 raw sidecars 保持原路径和字节不变。

## 本次 status sync

本次只新增本目录 `acceptance/{acceptance.md,manifest.json}` 与
`status_sync_r1/raw/**`。本次直接复核重新检查八件产品的 canonical JSON、record/receipt
bytes 与 SHA、semantic hash、receipt-to-record/path/raw closure、source locator bytes/SHA、
untracked HEAD truth、四 scope result union、negative-control/no-publish 语义和
common handle continuity；结果为 `179/179`、exit `0`。原始 stdout/stderr、计划校验、
scoped diff 和 final snapshot 均在 `status_sync_r1/raw/`。

计划校验：31 markdown、497 relative links、39 tasks、DAG acyclic、exit `0`。
scoped `git diff --check` exit `0`。这些只证明软件记录和工程卫生，不能代替物理或工程证据。

## 后续三门与信用边界

AD48 正在定义 W1 后续必须关闭的三门：

1. source locator gate：真实 locator、working-tree/HEAD 状态及 exact bytes/SHA；
2. factory identity gate：可重放 factory identity、construction receipt 及 hash 输入；
3. trusted attestation/source identity gate：独立 source identity 与 trusted attestation。

三门关闭后必须重新构建 fresh identity input；W1 的八个 absence receipt 不能被提升为
present authority，也不能被用来生成 G3 declaration、candidate identity、四轴 attestation、
child join 或 feedback authority。

本 acceptance 不授予 G3 source authority、source-backed declaration、candidate binding、
四轴 provenance、feedback authority、T0/T1/T2、UP2、provider、mesh、solver、engineering、
physical、search、R01–R10 或 L4 credit；相关字段保持 false/0。
