# AD-47 W0 G3 axis schema extension independent review R1

日期：2026-09-15  
范围：只复核 `AD-47/G3-AXIS-SCHEMA-VERSIONED-EXTENSION` 的四个 W0 产品、其归档验证收据、AD43 四个冻结 source-only axis contract 与 G3 源文件映射。未修改被审产品、`src/`、`test/`、核心规划、`task_manifest.json` 或 registry。

## 结论

`changes_requested`。

四个 W0 产品自身的冻结字节、SHA-256、canonical sorted JSON 与无末尾 LF 均复核通过；AD43 四份输入按 W0 migration receipt 的冻结字节和 SHA-256 均未改变。G3 的 adapter ref/version、G3 layer、四个 scope、四个 axis、negative controls、result union、软件 claim ceiling 与零运行计数也均通过。

但 bundle scope 的 `RealizationControlGenomeV5.jl` source closure 未闭合：

* W0 schema 声明 `src/GenomeV5/G3/RealizationControlGenomeV5.jl` 为 6704 bytes，声明 SHA `8e9d4f1505098b745048a5f741e0cb1edccdcf70a395c212f0a8649a73d62a4`，该值只有 63 个字符且不是 SHA-256；
* 当前工作树同一路径为 6704 bytes，实际 SHA-256 是 `8e9d4f1505098b745048a5f741e0cb1edcccdcf70a395c212f0a8649a73d62a4`；
* 其余四个 G3 source closure（Realization、Control、CoupledBinding、G3SourceFeedbackLaw）均 exact；因此问题定位为 W0 schema 的 bundle source hash 声明，而不是当前源文件字节变化。

该差异阻断 `pass_limited`，因为产品声称的 exact source-byte closure 不成立。请实现者重新生成 W0 schema 的该字段，并按重新生成后的产品字节和哈希重建/复核任何受影响的 validation 或 migration receipt，然后由不同 Luna 再次复核；不得修改源文件来迎合错误声明。

## 运行证据

独立直接校验使用 `D:\Users\Newman\anaconda3\python.exe`，Python `3.13.5`，PID `88696`，UTC `2026-09-15T12:36:27.646932+00:00`，exit `0`；完整 stdout 保存在 `review/validation_stdout.json`，stderr 为零字节。产品、AD43 与源文件逐字节重算、JSON canonical/no-LF、语义与负控检查均在该收据中。

规划校验重新运行：31 markdown、497 relative links、39 tasks、DAG acyclic，exit `0`；原始输出见 `review/plan_validator_stdout.json`，stderr 为零字节。对本复核目录作用域运行 `git diff --check`，exit `0`，stderr/stdout 均为零字节。上述工程校验不能充当 provider、mesh、solver、engineering、physics 或 R01–R10 证据。

## 保持的边界

W0 的 `PresentG3AxisSchemaExtensionV1` 只能关闭 additive software contract。复核未发现 candidate/declaration/final identity、candidate-bound axis、T0/T1/T2、provider、mesh、solver、engineering、physical、search 或 R01–R10 信用；所有 claims 为 false，runtime call counts 为 zero，`default_operator_registry_modified=false`，AD43 layer enum 仍为 G1|G2。该结论不提升任何父目标或物理证据状态。
