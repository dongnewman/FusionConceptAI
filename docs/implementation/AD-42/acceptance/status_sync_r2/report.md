# AD-42 W0 local software materialization status sync R2

日期：2026-09-15  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
状态：`accepted_limited`  
范围：`AD42-W0-PUBLIC-CONTRACT-ENVELOPE` 的本地软件合同物化与证据闭合

## Sol/root 裁决

依据不同 Luna 的 `independent_review_r1=pass_limited`，将 W0 四个既有产品接受为 `accepted_limited`，接受范围严格为 `software_contract_materialization_only`。`PresentPublicContractEnvelopeV1` 只表示 V1 source/profile 域的软件合同包已经物化；它不是 source-backed declaration authority、candidate identity 或物理结果。

W0 使用 fresh scheduler-frozen seed，G1 保留 `QualifiedRefV1`，G2 保留五字段 `GenomeContractRef`。四轴记录中仍有三个 typed absence：G1 的 evidence receipt、G2 的 applicability profile 与 evidence receipt。W0 没有创建 payload、declaration hash、candidate hash、authority、binding、T0/T1/T2，也没有 provider、mesh、solver、engineering、physical 或 R01–R10 credit。

独立复核实际记录 40/40 checks pass（PID `37140`，exit 0）；W0 直接 validation receipt 记录 21 checks 且 exit 0（PID `26812`，UTC `2026-09-15T09:17:54Z`）；成功 materialization run 为 PID `69780`，UTC `2026-09-15T09:16:26Z`，exit 0。本次状态同步重新核对 15/15 当前文件与边界检查，PID `34168`，UTC `2026-09-15T09:58:16.861072Z`，exit 0。历史失败 materialization receipt 保留，清理 inventory closed，W2R1 四个未来产品仍不存在。

## 下游边界

`AD42-W2R1-REAUTHOR-FRESH-PAYLOADS` 仍为后续独立 work order。W2R1-G1/W2R1-G2 axis records 仍等待 AD-43；W0 的本地接受不转移 declaration authority、candidate identity、T0/T1/T2 或任何 R credit，也不授权 W2R1 绕过 fresh source evidence。

## 验证与清理

本状态同步只新增本目录的 report、manifest 与 raw sidecars，并保留已有 `status_sync_r1` 及 W0/W0 review/archive 历史。未修改四个 W0 产品、AD-42 core/task manifest、源码或测试；未运行 Julia、DESC、provider、mesh、solver 或物理 workload。
