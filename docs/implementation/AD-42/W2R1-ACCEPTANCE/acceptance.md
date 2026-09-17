# AD-42 W2R1 fresh payload reauthoring acceptance

日期：2026-09-15  
裁决：`accepted_limited`  
范围：`software_source_authoring_canonical_only`  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`

## Sol/root 裁决

依据不同 Luna 的 AD-42 W2R1 独立复核 R1：`pass_limited`，`47/47` 项通过，接受
四个冻结产品的 fresh source-authoring canonical slice。该裁决承认四个产品的
canonical JSON/no-terminal-LF、payload/source hash closure、W0 public reference
与 seed/commitment 复核、四轴记录、负例闭合及 append-only failure history；不把
source authoring 误读为 declaration、authority 或 candidate 完成。

G1 保持 `QualifiedRefV1` candidate ref；G2 保持 `GenomeContractRef` public
contract ref。G2 的 common-candidate mapping 仍为 `typed_absent` 且 value 为
`null`。四轴引用分别指向 G1 applicability/canonicalization/evidence/schema 与
G2 applicability/canonicalization/evidence/schema v1 合同；四轴独立存在，不从
candidate hash 或历史 receipt 派生。

冻结的四个产品如下：

- G1 payload：6180 bytes，SHA-256
  `f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449`。
- G1 authoring receipt：13968 bytes，SHA-256
  `46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210`。
- G2 payload：7086 bytes，SHA-256
  `7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf`。
- G2 authoring receipt：14337 bytes，SHA-256
  `7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`。

两层使用同一 W0 fresh seed recipe 与 commitment；source files 只作为仓库设计源
及 schema/factory source metadata，`authority_for_candidate=false`。AD-40 历史
payload/receipt 只作为 read-only negative controls；seed-mismatch、缺失
candidate/source/attestation、旧/fixture/synthetic/legacy/historical、axis/domain
混用和 noncanonical 控制均保持 fail-closed。失败收据和 cleanup 记录保持追加式，
不得覆盖或回填为成功运行。

## Claim ceiling and blocked downstream work

本裁决的 claim ceiling 是 `software_source_authoring_canonical_only`。以下全部
保持 `false`、`not_created` 或 `pending`：source-backed authority、factory
authority、present declaration、candidate identity/hash、declaration hash、T0、
T1、T2、provider、mesh、solver、engineering、physical、search 及 R01–R10。没有
运行 Julia、DESC、provider、mesh、solver 或 physical workload。

后续必须等待 AD-44 source-authority/binding work orders，重新取得 candidate-bound
authority、factory receipt、同候选跨层 identity 与 downstream T0/T1/T2 证据；本裁决
不得创建、转移或提前解释这些证据，也不得改变 AD-42 既有 acceptance、四个产品、
AD-43 axis records、core、task manifest、source 或 test。

## Verification and cleanup

本目录的 `status_sync_r1/raw/` 保存本次 JSON/hash/path/control、plan/DAG 和最终
closure 的真实 stdout/stderr。每次运行记录解释器、PID、UTC、cwd、exit code 与输入/
输出 hashes；manifest 自身 hash excluded。验证只检查软件合同和证据闭合，不替代
物理或工程证据。

清理只针对本任务临时物；本次没有可删除的自有临时文件，历史失败收据、四个产品、
AD-42 既有 acceptance、其它 agent 的 dirty work 和不相关文件均保留。

