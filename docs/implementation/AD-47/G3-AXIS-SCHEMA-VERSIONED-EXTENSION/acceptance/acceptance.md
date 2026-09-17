# AD47 W0 G3 axis schema extension acceptance

日期：2026-09-15  
决策：accepted_limited  
适用范围：additive_g3_axis_software_contract_and_source_byte_hash_closure_only

本归档接受 W0 的 additive G3 axis 软件合同及其 source-byte/hash closure。冻结的四个产品为：

- g3_axis_schema_v1.json：7465 bytes，SHA-256 b9ff3eeab8027085a09ba88c6b2418d1017321da7a4376357fff437bcd6d0e13
- g3_axis_scope_contract_v1.json：4420 bytes，SHA-256 41ec0e8e035183bd946cd6899789ab800ccbc558e094ae08f569baff8f33c617
- g3_axis_migration_receipt.json：3428 bytes，SHA-256 3cfa558475eaaed8e327754e144fc113e3b22310a9625a87941b7b0dc02244b9
- g3_axis_validation_receipt.json：4410 bytes，SHA-256 9a5a7e0f0b2ee8d3eac7ed6ba74b565cc456525bc77946575f7893fd475a1c99

合同明确 layer=G3，scope 恰为 realization|control|binding|bundle，axis 恰为 payload_schema|canonicalization_profile|applicability_profile|evidence_receipt，adapter ref/version 为 fusionconceptai://GenomeV5/G3/axis-contract / v1。AD43 四个冻结 source-only 产品的 bytes/SHA 未改变，AD43 layer enum 仍为 G1|G2，default_operator_registry 未修改。

R1 的 changes_requested 仅涉及 bundle RealizationControlGenomeV5.jl 的 63 字符声明，已修复为实际 64 字符 SHA-256；R2 以 pass_limited 复核通过。mtime 双采样稳定：validation receipt 4410 bytes，mtime ns 1789476772359754300，采样 PID 87164。

status sync 使用 Python 3.13.5。direct JSON/hash/path/control 校验 PID 88612、UTC 2026-09-15T12:58:42.632237+00:00、exit 0；规划校验为 31 markdown、497 relative links、39 tasks、DAG acyclic、exit 0；scoped git diff --check exit 0。原始收据位于 status_sync_r1/raw/。

本接受只覆盖软件合同与源字节哈希闭合。candidate-bound axes、source authority、candidate/declaration/final identity、present promotion、T0/T1/T2、provider、mesh、solver、engineering、physical、search、L4 与 R01–R10 均保持 false；文档、测试、代理或运行器退出码不构成物理证据。
