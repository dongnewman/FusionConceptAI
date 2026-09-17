# AD-35 repair R4

状态：`review_pending`；`accepted=false`；`sol_decision=pending`。

独立重算 `docs/implementation/AD-35/acceptance.md` 得到实际 SHA256：`690fd8609b57307e64dbca87196edef9e6b0b16e8da869f8577371e4a5d2d88c`，长度 64。R3 manifest 的两个 acceptance hash 字段原为缺末位 `c` 的 63 位值；本轮只修正 `repair_r3/manifest.json` 的 `input_hashes` 和 `final_current_hashes` 对应字段。

R3 manifest before SHA256：`12900f7beedd30401a3882eab1cd36cbeea24a9b81ed43056b3607edb1097465`；修正后 SHA256：`89ed24ea324a4017bda80e99a569d314580649405940c6b4d760019d2d7de763`。未修改 core、acceptance 正文或其他既有文件；未运行 Julia/DESC。

本轮重新执行 JSON/hash/diff 静态核对，结果与 PID/UTC/exit/raw hashes 见 `manifest.json`。R4 自身只产生本 report 与 manifest，cleanup action 为 `none`，两条 owned path 均保留并由不同 Luna 复核。
