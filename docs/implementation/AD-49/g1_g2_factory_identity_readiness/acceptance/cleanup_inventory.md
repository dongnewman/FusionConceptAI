# AD-49 limited acceptance cleanup inventory

本次只归档 root 已裁决的有限验收，不修改 AD49 根产品、R1/R2 evidence、README、规划文件、源码、测试、fixture、registry 或 `task_manifest.json`，也未运行 Julia/DESC/provider/mesh/solver/engineering/physics/search。

## Exact owned set

本次新建且由本验收拥有的文件仅为：

1. `docs/implementation/AD-49/g1_g2_factory_identity_readiness/acceptance/acceptance.md`
2. `docs/implementation/AD-49/g1_g2_factory_identity_readiness/acceptance/manifest.json`
3. `docs/implementation/AD-49/g1_g2_factory_identity_readiness/acceptance/cleanup_inventory.md`

没有 task-owned scratch、cache、debug 或临时文件；没有删除、移动、覆盖、暂存或回退任何文件。R1、R1 repair 和 R2 的历史 raw/evidence 保持 append-only。`final_exact_owned_set` 即上述三条路径；后续任何 S1/S2/F0/S3/mapping/W3-B 工作必须使用自己的目录和 cleanup inventory。

验收范围固定为 `decision=accepted_limited`、`accepted_scope=architecture_readiness_only`，唯一解锁 AD49-S1；其余 work-order 与 candidate/source authority/identity/hash/T0-T2/provider/physics/R01-R10/L4 信用仍锁定。
