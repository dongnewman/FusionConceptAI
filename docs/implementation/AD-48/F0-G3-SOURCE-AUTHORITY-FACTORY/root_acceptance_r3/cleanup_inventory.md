# AD48-F0 root acceptance R3 cleanup inventory

本次 root acceptance 只新增本目录三件文件：`acceptance.md`、`manifest.json`、`cleanup_inventory.md`。

未运行 Julia/DESC，未修改两个 F0 产品、R1/R2/R3 review、archive、registry、`src/FusionConceptAI.jl`、`RealizationGenomeV5.jl` 或其他目录。R3 raw 证据和失败历史保持 append-only。

`manifest.json` 的 self-hash 按约定排除；两个 F0 产品的 exact bytes/SHA 已在 acceptance 与 manifest 中复核。无临时进程、临时运行目录或待清理文件由本次 root acceptance 产生。
