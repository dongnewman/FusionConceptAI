# M5-C R1 字段级验收矩阵

所有行均为实现回合的强制 oracle/test/probe/evidence 项；本修订回合不运行 Julia。 \`missing/foreign/altered/duplicate/wrong-link/detached/status_mismatch\` 必须产生表中 typed code，不能只返回 false。

| 层 | 必验字段/关系 | 正控 | 负控 | typed code | 写入证据 |
|---|---|---|---|---|---|
| upstream M5-A | source identity、canonical source/program、composition hash | exact bytes/hash | missing/foreign/altered | \`binding.m5a_missing/foreign/altered\` | full binding receipt |
| upstream M5-B | source identity、inverse hash、M5-A upstream hash | exact chain | missing/foreign/wrong-link | \`binding.m5b_missing/foreign/upstream_mismatch\` | full binding receipt |
| owner/provenance | owner id、provenance bytes/hash/ref | exact owner/ref | missing/foreign/detached | \`binding.owner_*\`, \`binding.provenance_*\` | full binding receipt |
| catalog | all 8 condition records、catalog ref/hash、canonical bytes/hash | ordered exact catalog | malformed/duplicate/altered/foreign | \`catalog.malformed/duplicate/altered/foreign\` | envelope/evaluation receipt |
| envelope | version、candidate、M5-A/B bindings、fact status/value/hash | V1 exact binding | version/identity mismatch | \`envelope.version_mismatch/foreign\` | envelope receipt |
| condition result | 8 ordered results、required_all_met、aggregate | all met allows merge | unknown/not_applicable/unmet/contradiction | \`condition_unmet\`, \`fail_closed\` | evaluation receipt |
| rewrite | rewrite-set identity、rule id/hash、checker、source program | each exact rule | missing/altered/duplicate/wrong-link | \`rewrite.rule_*\` | full binding receipt |
| derivation | id、source/budget/profile、state/stop reason、usage、trace/provenance/artifact | exact sealed artifact | missing/foreign/altered/status mismatch | \`derivation.*\` | derivation receipt |
| graph | graph id/source hash/members/conditions/artifact bytes/hash | object and hash relation | detached/foreign/missing derivation | \`graph.detached/foreign/derivation_missing\` | graph/full binding receipt |
| adapter | schema、claim ceiling、evidence scope/status | screen-only only | status/ceiling mismatch | \`adapter.status_mismatch/ceiling_exceeded\` | adapter receipt |
| budget | requested/effective/applied/sealed hash/reason | omit/same=no-op | different sealed=budget_mismatch; input overload=rebuild | \`budget_mismatch\`, \`budget_invalid\` | supervisor/result receipt |
| key | domain + full bytes + length framing | exact same key dedups | same-key/different-bytes/digest collision | \`key_collision\`, \`key_domain_confusion\` | hostile receipt |
| cache | owner/id/entry bytes/shared ids/escape flags | local same bytes/hash | cross-product/alias/mutation/escape | \`cache_escape\`, \`cache_cross_derivation\` | cache receipt |
| supervisor | command/PID/UTC/deadline/termination/exit/raw bytes/hash/process counts | completed, post count 0 | missing field/nonzero/timeout/post count !=0 | \`supervisor.receipt_incomplete\` | stage receipt + raw |

## 状态优先级与闭包

\`malformed > foreign > duplicate > wrong-link > detached > altered > contradiction > unknown/not_applicable/absent > unmet > met\`；其中前七类和 contradiction 为 \`fail_closed\`，unknown/not_applicable/absent/unmet 为 \`condition_unmet\`，只有全 required=\`met\` 才可 \`conditional_equal\`。监督异常优先于业务结果：\`human_interruption/timeout/program_exception\` 只能为 \`terminal_deferred\` 或 \`not_executed\`。任何 status mismatch 都覆盖 graph/equality 字段的表面成功。

## 路径验收

实现只可改四个 owner 文件；receipt/raw 只可写 \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/**\`；本修订目录之外的新增/修改为 scope violation。不得修改 \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/02-repair-scope-contract/**\`、历史 raw、生产测试或共享 core/registry。
