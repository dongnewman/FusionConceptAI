# UP2-01-G2-METRIC-BOUNDARY-V1 R3 repair

状态：`review_pending=true`，`accepted=false`。本轮只处理独立 R2 预审的 F02：
`G2MBUnitContractV1` 先前只检查字段类型，未验证几何单位指数代数，也没有把派生面积/体积结果绑定到已验证的 contract。

## 修复内容

- 新增 `reference_coordinate::UnitSignature`，并在 `g2mb_unit_algebra_errors` 中强制验证：
  - reference coordinate = 1（无量纲）；
  - physical coordinate = L；Jacobian = L；
  - pullback metric = L²；physical cofactor/oriented area = L²；
  - determinant/volume = L³。
- `g2mb_physical_oriented_area_measure(chart, reference_normal, units)` 返回带 `unit=units.area` 的 typed area measure，并拒绝未经验证的单位 contract。
- `g2mb_volume_measure(chart, units)` 只接受 typed `G2MBUnitContractV1`，返回 `unit=units.volume`；删除任意 caller-supplied `UnitSignature` 路径。
- admission 在重算 source hash 后执行单位代数校验；错误指数即使 source hash 自洽也返回 `:fail_closed`。有效 contract 的派生面积/体积单位由 validator 重新绑定检查。
- focused test 为六种几何单位字段各提供自洽 hash 的错误指数 negative control，并检查 area/volume measure 的 unit binding。fixture/static QA 同步记录这些控制项。

## 验证边界

执行了显式 Python static QA：

```text
python test/GenomeV5/G2/static_qa_metric_boundary_v1.py
static_qa=pass
python_executable=D:\Users\Newman\anaconda3\python.exe
python_version=3.13.5
julia_or_desc_executed=false
provider_or_mesh_execution=false
claim_ceiling=contract_only
review_pending=true
accepted=false
```

本轮没有运行 Julia、DESC、mesh/provider 或物理求解；没有新增 compiler/provider/mesh/physics credit。`execution_status=:not_executed` 仍无条件产生 `mesh_execution_not_executed` 的 terminal gap，且正 determinant、reference normal 与 physical oriented area vector 的 R2 语义保持不变。

## R2 → R3 SHA-256

| artifact | R2 before | R3 after |
|---|---|---|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `eb9124423628794baf53c1bfab75f99cc606f73883203ff5f69de921e45246dd` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | `49784f58298a28e57724111fd40ca4c2c64417c455e3acf12f54b636e9d9dda2` | `c747c174471ebd3c15812a5d25bfecff0389ed6e3dcb7eec888fd47730d8b007` |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | `4fd029f8e46fcfc473334a27a0531168082f4bb89cb67e2b8d7d838dc69b41c8` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | `df9f777d5dd8ec38876cb2fa12cceba3f1c6f53cb83fe011d2f366d5b563708d` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` |

退出门仍为 proposal/contract-only：无 compiler/provider/mesh execution、无物理证明、无工程 readiness、无 R01–R10 credit。交不同 Luna 独立 R3 预审。
