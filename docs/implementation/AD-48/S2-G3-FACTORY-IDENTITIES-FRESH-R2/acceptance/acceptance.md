# AD48-S2 G3 factory identities — fresh R2 freeze

日期：2026-09-15  
状态：`review_pending`   
范围：四个 G3 scope 的 fresh factory identity 与 construction receipt 软件合同。

本次 fresh S2 在 F0 root acceptance R3 (`accepted_limited`) 之后执行，严格读取 AD48-S1 四个 Present frozen locator、AD45 exact handle/envelope、四 scope `GenomeContractRef`/`G3VersionAxesV2`，并调用实际 `g3_source_authority_factory_v1`。四个 scope 均具体化为 `PresentG3FactoryIdentityV1` + `PresentG3FactoryConstructionReceiptV1`，共 8 个产品；旧 `S2-FACTORY-IDENTITIES/**` 保持 append-only 未改写。

冻结输入为 `archive/repair_r2_final_snapshot.json`（6299 bytes，SHA-256 `ddafe940d8f7ed2d9c5f3083bec85284312de6acd824d8f3e997d5575e37db3b`）。该 snapshot 逐项封存八根产品的 path/bytes/SHA、manifest 冻结字段、旧 S2 历史 hash、F0 source/test 与 root acceptance、四个 S1 locator 及 AD45 exact envelope；snapshot 自身不参与自身 hash（`self_hash_excluded=true`）。

每个 Present identity/receipt 记录实际 factory identity、`G3SourceContractBindingV1` digest、candidate-bound local G3 source declaration ref/hash/content digest、source bytes/SHA、Git HEAD/path/status freshness 与 construction digest。receipt 明确 `registry_not_used=true`、`trusted_attestation_created=false`、`candidate_identity_created=false`；local `g3_source_declaration_hash` 不等于 final CandidateIdentity/package/T0 declaration hash。

## Validation

- fresh four-scope factory probe：PID 40460，UTC `2026-09-15T15:18:56.018`，exit 0。
- F0 factory focused suite：320/320，PID 95044，UTC `15:21:33.869`–`15:21:51.008`，exit 0；覆盖 source/HEAD/status/hash mutation、wrong locator scope、AD45 handle/version/allocation/alias、contract/axes mismatch、replay conflict 和 missing typed input。
- two independent fresh Julia processes replayed all four scope constructions：PID 87752 and 86832，both exit 0; declaration/construction/product file hashes match。
- Python integrity（R1 窄修复后）：126/126，PID 91248，UTC `2026-09-15T15:51:53.519322Z`，exit 0；raw 为 `archive/repair_r2_integrity.stdout.json` 与 `archive/repair_r2_integrity.execution.json`。检查含 snapshot 的 JSON/path/hash/freeze closure、8 products canonical/no-LF/hash closure、source bytes/SHA、AD45/F0/root inputs、旧 S2 unchanged。原 R1 `changes_requested` 与 raw 保持不变。
- plan validator：31 markdown、526 links、39 tasks、DAG acyclic，exit 0；scoped `git diff --check` exit 0。

Raw stdout/stderr and scripts are in `archive/`; exact product hashes are in `manifest.json`.

## Claim ceiling

本 freeze 仅覆盖软件 source-stage factory identity/construction receipt。`trusted_attestation=false`、`candidate_identity=false`、`final_candidate_or_package_declaration_hash=false`、`T0/T1/T2=false`、provider/mesh/solver/engineering/physical/search/R01–R10=false`、`L4 credible count=0`。下一步是交不同 Luna 做独立复核；S3、fresh W1、W2 仍锁定。
