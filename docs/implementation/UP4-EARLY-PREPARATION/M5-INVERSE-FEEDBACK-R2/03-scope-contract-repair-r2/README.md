# M5 inverse-feedback R2 scope-contract repair R2

本目录是对 `reviews/02-scope-contract-repair-independent-review-r1/report.md` 的 additive contract repair。它只关闭 F7–F12 的规范与静态可执行边界，不执行实现。

状态：`review_pending`; implementation=`not_implemented`; runtime=`not_executed`; claim ceiling=`manufactured_inverse_feedback/screen_only`; `formal_credit=none`。

主要文件：

- `canonical_bundle_schema.json`：完整 typed refs、parent body 与 non-physical applicability。
- `input_schema.json` / `output_schema.json`：绝对 URN resolver、join receipt、fresh replay gate、CAS/history receipt。
- `failure_record_schema.json` / `failure_taxonomy.json`：闭合且集合一致的 failure vocabulary。
- `resolver_registry.json`：只允许本地 registry URI→文件映射，绑定依赖 hash。
- `checker_contract.json`：JSON Schema 不能表达的跨对象 equality、digest、CAS、history、replay 和 taxonomy invariants。
- `manifest.json` / `hash_manifest.json`：dependency closure、逐路径 dirty baseline 规则、写入边界与本包 hashes。
- `raw/`：仅 Python/PowerShell 静态 parse、schema-shape、resolver registry 和 invariant audit；无运行时调用。

`valid_screen` 仅在 fresh refreeze authority、两次 serial replay、`exit_codes=[0,0]`、raw/process refs、typed checker 和所有 join/CAS/taxonomy invariant 全部通过时可出现。schema parse 或 meta-schema pass 不能单独产生它。
