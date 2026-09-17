# actual-A observation R1 receipt erratum R2

日期：2026-09-15  
本 erratum 是 append-only 收据修正；原 R1 `report.md`、`evidence_manifest.json`
和原始输出均未覆写。

## 修正项

1. R1 `stderr.txt` 是 0-byte 空文件。其完整 SHA-256 为
   `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
   原 R1 manifest 中的 stderr hash 少于 64 位，不能作为完整字节收据。
2. R1 dirty 快照从 305 行到 306 行的唯一新增行是：
   `?? docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/`。
   这是并发 G3 realization 目录写入，不是 R1 observation 诊断的生产、测试或
   fixture 修改。原 dirty 快照保持原样。
3. R1 的 PID `18040` 与 exit `0` 只能标记为 OS provenance uncertain：启动
   wrapper 在等待前因 PowerShell 保留变量 `$PID` 冲突中断，随后只能确认同一
   进程已结束、`result.json` 完整且 stderr 为空，未保留 `Process.ExitCode`
   对象。因此 R1 结构化结果内部一致，但不晋升为可靠 OS 退出收据。

## 边界

R1 的 `terminal_deferred`、typed absent、source-derived gaps 和零执行计数只作
诊断观察；本 erratum 不授予 actual authority、UP2、provider、mesh、物理、工程或
R01–R10 信用。后续 R2 使用新进程句柄重新取证。

