# UP1 R2 13/14 独立只读复核 R1

## 结论

`rework`。本复核只覆盖 13-threat-model 与 14-review-protocol 的合同、覆盖关系、范围/所有权和静态可重算性；没有修改被审目录，没有联网、安装、Julia/DESC、mesh、solver、provider 或其他重任务。claim ceiling 仍为 `preparation_only`，不产生 authority、UP1、B00/B04 或 R01--R10 信用。

13 的结构性计数通过（20 threats、20 attack rows、12 AR），且 18/18 个现有 manifest 条目哈希重算通过；但 14 的可执行测试矩阵没有把 13 的外部缺失与 TM/AR 建成可审计的测试映射，且存在多个跨文件语义冲突，因此不能标记 `pass_limited`。

## Fresh 静态证据

- 命令：`python -B -c <independent JSON duplicate/exact/canonical/hash audit>`。
- PID `88132`；UTC `2026-09-16T18:12:47.762765Z` 至 `2026-09-16T18:12:47.765647Z`；numeric exit `0`。
- 12 个 JSON 全部以 `object_pairs_hook` 拒绝重复键解析成功；非有限数拒绝策略加载成功。
- `TM-01..TM-20` 与 attack rows 集合精确相等；AR 数量为 12；13 manifest 12 项及 14 manifest 6 项（含自排除项）的 18 个文件哈希均匹配。
- canonical bytes 使用 UTF-8、递归 `sort_keys`、紧凑分隔符、拒绝 NaN/Infinity；每个 JSON 的 canonical SHA-256 已记录在 `validation_receipt.json`。
- 13 原有 `python -B static_validator.py` fresh receipt 的输出也被保留为 raw；其 `20/20/12` 结构检查为 PASS，但不能替代本复核发现的语义覆盖检查。

## 覆盖审计

| 目标 | 13 threat/AR 声明 | 14 test/group 可执行映射 | 判定 |
|---|---|---|---|
| W1 witness / authority intake | TM-01/02/04/06/09/11/19/20；AR-02/03/04/06/11 | 无 W1 或 R2-07 authority-intake 测试行；仅 G3/UP2 的“missing external authority”文字 | 缺口 |
| W2 PKI、算法、CRL/OCSP、TSA、replay | TM-05..11、15、20；AR-01/02/05/06 | 无 trust-chain/PKI、CRL/OCSP、trusted-time、nonce/sequence/idempotency/replay 行 | 缺口 |
| W3 source/G2/env/binary/SBOM | TM-02/03/04、12、14、16/18；AR-03/04/07/08/09/10 | G2 只测 geometry/ownership；无 source/G2 authority mapping、TOCTOU、SBOM/license、binary publisher/origin/recipe、environment closure 行 | 缺口 |
| W4 local discovery / path | TM-03/12/13/14/19；AR-07/08/12 | 无 local-discovery/path/reparse/manifest exact-set mutation 行；静态行只检查 protocol path allowlist | 缺口 |
| duplicate/unknown/canonical/hash | 13 明确声明覆盖 | G1/G2/G3/V5 有局部 duplicate/unknown/hash case，但无 TM/AR ID、字段级 crosswalk，无法证明 20 类攻击逐项进入执行 | 不可审计 |
| two-process / formal gates | 13 要求 raw/PID/UTC/exit | 组件 rows `replays=2`；B00/B04 正确锁定 future；但 PYTHON-STATIC-JSON 为 `replays=1`，与 14 §4 “每个 component 第二独立进程”冲突 | 冲突 |

因此“20 threat rows 存在”不等于“20 类攻击已由 14 测试计划覆盖”。至少应增加可追溯的 `TM/AR` 字段或独立 crosswalk，并为 W1/W2/W3/W4（含 R2-07 authority-intake、R2-06/09/10）提供每类正/负/缺失-oracle 与两进程要求；否则 final integration 无法验证外部缺失闭包。

## Findings

### F1 — 高：14 测试矩阵遗漏 W1/W2/W4 及关键外部攻击面

`13-threat-model/review_plan.md:21-25,36-40` 要求 PKI、CRL/OCSP、独立 TSA、nonce/sequence/idempotency、TOCTOU、path escape、manifest、SBOM、binary、environment 和 typed absence 的逐类攻击。可是 `14-review-protocol/test_matrix.json:14-215` 只有 G1/G2/G3、V5、UP2、未来锁定的 B00/B04 和一行 protocol-static；没有 `W1/W2/W3/W4` 或 `R2-07 authority-intake` 行，也没有 TM/AR 关联字段。`PYTHON-STATIC-JSON` 的 scope 仅是协议 JSON/path/labels，不能替代这些行为测试。

影响：独立 reviewer 即使完成 7 组，也不能给 AR-02、AR-05、AR-06、AR-07、AR-08、AR-09、AR-10、AR-11 产生逐项执行覆盖。修复：扩充 test_matrix 或显式引用各 R2 包的冻结 test/receipt，逐行绑定 TM、AR、组件、oracle、负向状态、raw/PID/UTC/exit 与 replay=2；同时把 authority-intake 纳入组/依赖关系。

### F2 — 高：13 与 14 的 verdict/status/故障分类不一致

`13-threat-model/review_plan.md:44` 只允许 `review_pending|accepted_limited|blocked`，而 `14-review-protocol/review_protocol.md:114-120` 与 `14-review-protocol/evidence_contract.json` 只定义 `pass_limited|rework|block_external`。13 manifest 又是 `status=pass_limited` 且 `independent_review_required=true`。此外 00 contract 的 `interface_contracts.json:4-6` 保留 `program_exception` 和 `not_applicable`，14 协议仅在 `review_protocol.md:70` 提到 unexpected exception 为 `program_exception`，但 verdict schema、attack rows 和 reduction table 没有它的归约规则。

影响：同一 receipt 可能被不同 reviewer 映射为不同状态；unexpected runtime fault 的 `program_exception` 是否压过 `rework/pass_limited` 也未定义。修复：统一一个枚举，明确 package status 与 group verdict 的关系，并把 `program_exception`/`not_applicable` 的不可提升及 precedence 写入 evidence contract 和 final reduction。

### F3 — 中：two-process 规则与 static 行 replay 数量矛盾

`14-review-protocol/review_protocol.md:58,80` 说每个 component 必须第二个独立进程；组件行一般为 `replays=2`，但 `test_matrix.json:204-213` 的 `PYTHON-STATIC-JSON` 为 `replays=1`。若 `replays` 表示总进程数则违反 §4；若表示“额外 replay 次数”则所有组件行的 `2` 又含义不明。

修复：在 schema 中固定 `process_count`/`replay_count` 语义；static 行设为两进程，或显式声明唯一的静态检查例外及为何不需要 determinism replay。

### F4 — 中：TM-14 的 missing/omission oracle 可把矛盾降级为 deferred

`13-threat-model/threat_model.json:47` 同时给 manifest threat 提供 `circular_or_incomplete=fail_closed` 和 `closure_missing=typed_absence -> terminal_deferred`。但 `attack_matrix.json` 的 TM-14 mutation 明确包含“omitted artifact or unlisted extra file”，其 contradiction_status 是 `fail_closed`。没有 JSON Pointer/原因区分“外部闭包尚未提供”和“已发现 exact-set omission”。这与 00 contract `interface_contracts.json:9,12` 的 duplicate/missing target 或 stale/changed receipt 必须 fail-closed 的边界相冲突。

修复：把 unavailable/typed-absent 的输入缺失与已观察 omission/circularity 分成不同 case ID、reason 和 error path；后者只能 fail-closed。

### F5 — 低至中：TM-07 class 的稳定编码异常

`13-threat-model/threat_model.json:40` 的 class 为 `revocation失联`，而同包的 attack matrix、coverage required topic 和 13 static validator 使用 `revocation unavailable`。这不是 JSON parse 错误，但会破坏按 class 的稳定 crosswalk、检索和未来机器归类。修复为一个 ASCII/版本化枚举，并由 validator 检查 class↔topic 映射。

## 所有权与门边界

13/14 都声明 `preparation_only`、`no_authority_credit=true`、`no_publish=true`；14 manifest 的写范围仅为自身目录，future B00/B04、provider/mesh/solver/heavy lane 正确锁定，7 组的作者/ reviewer 冲突规则也明确。上述结论不改变这些边界。当前 review 输出只写入本目录 `reviews/threat-protocol-independent-review-r1/`；没有触碰被审 13/14、R1、实现、测试或运行产物。

## 修复后重审入口

1. 统一 verdict、故障分类与 replay 计数 schema；修正 TM-07 枚举并拆分 TM-14 的 unavailable 与 omission oracle。
2. 将 TM/AR crosswalk 和 W1/W2/W3/W4/R2-07 的独立测试/引用加入 14 matrix 与 assignments，覆盖 PKI、G2 authority、TOCTOU、replay、SBOM/binary/env 和 typed absence。
3. 新 revision 下由非作者 Luna fresh-process 运行两进程静态/组件复核，保存每类 raw input/stdout/stderr/PID/UTC/exit/hash；再进行 final integration。外部输入 fingerprint 未变化前，不创建同义 acceptance 或声称外部闭包完成。

