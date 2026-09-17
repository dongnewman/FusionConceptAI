# M5-C R2 field-level acceptance and negative matrix

本矩阵与 `contract.md`、machine schema 同源；实现回合的任何缺字段、枚举漂移、
hash/bytes 不一致、wrong-link 或 detached 都必须返回表中 typed code。没有 receipt
时只能是 `not_measured`，不能以 numeric zero 代替。

## 1. Binding / detached / wrong-link

| layer | required fields and relation | positive | detached / wrong-link / other negative | typed code |
|---|---|---|---|---|
| M5-A | source identity, canonical source/program, composition hash | exact bytes+hash+owner | missing, foreign source, changed bytes, duplicate source, wrong candidate link, detached provenance | `binding.m5a_missing`, `binding.m5a_foreign`, `binding.m5a_altered`, `binding.m5a_duplicate`, `binding.m5a_wrong_link`, `binding.m5a_detached` |
| M5-B | source identity, inverse hash, M5-A upstream hash | exact chain | missing, foreign inverse, altered inverse, duplicate inverse, upstream hash points to other M5-A, detached owner | `binding.m5b_missing`, `binding.m5b_foreign`, `binding.m5b_altered`, `binding.m5b_duplicate`, `binding.m5b_wrong_link`, `binding.m5b_detached` |
| owner/provenance | owner id, provenance bytes/hash/ref | exact owner/ref | missing, foreign owner, altered bytes, duplicate ref, wrong upstream ref, detached provenance | `binding.owner_missing`, `binding.owner_foreign`, `binding.provenance_altered`, `binding.provenance_wrong_link`, `binding.provenance_detached` |
| catalog | 8 ordered records, ref/hash, canonical bytes/hash | exact order and hash | malformed, duplicate kind, foreign catalog, altered bytes, wrong candidate link, detached evidence | `catalog.malformed`, `catalog.duplicate`, `catalog.foreign`, `catalog.altered`, `catalog.wrong_link`, `catalog.detached` |
| envelope/evaluation | V2/version, candidate/M5-A/M5-B bindings, 8 results, required closure | all required facts met | missing/foreign/altered envelope, wrong-link upstream, detached evidence, status mismatch | `envelope.missing`, `envelope.foreign`, `envelope.altered`, `envelope.wrong_link`, `envelope.detached`, `envelope.status_mismatch` |
| rewrite | rewrite-set id, rule id/hash, checker, source program | exact rule chain | missing rule, foreign rule, altered checker, duplicate id, rule points to wrong source, detached checker | `rewrite.missing`, `rewrite.foreign`, `rewrite.altered`, `rewrite.duplicate`, `rewrite.wrong_link`, `rewrite.detached` |
| derivation | id, source/budget/profile, state/stop, usage/trace/provenance/artifact | sealed exact artifact | missing, foreign, altered, duplicate id, wrong input/budget link, detached artifact, status mismatch | `derivation.missing`, `derivation.foreign`, `derivation.altered`, `derivation.duplicate`, `derivation.wrong_link`, `derivation.detached`, `derivation.status_mismatch` |
| graph | id/source hash/members/conditions/artifact bytes/hash | `artifact === graph` and hash equality | missing derivation, foreign graph, altered bytes, duplicate id, wrong derivation link, detached graph | `graph.derivation_missing`, `graph.foreign`, `graph.altered`, `graph.duplicate`, `graph.wrong_link`, `graph.detached` |
| adapter | schema, claim ceiling, scope, status | screen-only typed status | schema mismatch, ceiling exceeded, detached evidence scope, status mismatch | `adapter.schema_mismatch`, `adapter.ceiling_exceeded`, `adapter.scope_detached`, `adapter.status_mismatch` |

`malformed > foreign > duplicate > wrong_link > detached > altered > status_mismatch >
evaluator_fault > contradiction > unknown > not_applicable > absent > unmet > met` 是全局
唯一状态优先级。前九项为 `fail_closed`；unknown/not_applicable/absent/unmet 为
`condition_unmet`；全 required met 才是 `conditions_met`。监督异常优先于业务状态。

## 2. Raw-row corrected-count mapping

以下行号是历史 `01-profile/raw/*.stdout.raw` 的物理文本行号，按固定 stage enum 映射；
它们只证明历史 raw 支持的 corrected count，不创建新测量。

| stage | corrected count | raw row ids | status |
|---|---:|---|---|
| `include` | 8 | `probe.stdout.raw:L3; probe_catalog.stdout.raw:L3; probe_rhs.stdout.raw:L3; probe_saturate.stdout.raw:L3; probe_rules.stdout.raw:L3; probe_rules_fast.stdout.raw:L3; probe_rules_fast_r2.stdout.raw:L3; probe_rules_parts.stdout.raw:L3` | `historical_raw_supported` |
| `upstream_first_compile_plus_build` | 8 | same eight files `:L4` | `historical_raw_supported` |
| `upstream_warm_build` | 8 | same eight files `:L5` | `historical_raw_supported` |
| `prepare_condition_catalog` | 4 | `probe_catalog.stdout.raw:L6; probe_rules_fast.stdout.raw:L7; probe_rules_fast_r2.stdout.raw:L7; probe_saturate.stdout.raw:L7` | `historical_raw_supported` |
| `prepare_rhs` | 4 | `probe_rhs.stdout.raw:L6; probe_rules_fast.stdout.raw:L8; probe_rules_fast_r2.stdout.raw:L8; probe_saturate.stdout.raw:L8` | `historical_raw_supported` |
| `prepare_source_cold_hash` | 2 | `probe.stdout.raw:L6; probe_rules.stdout.raw:L6` | `historical_raw_supported` |
| `prepare_rewrite_set` | 0 | `probe_rules.stdout.raw:L1-L6` and timeout boundary; no stage receipt | `not_measured_timeout_before_receipt` |

`prepare_rewrite_set_constructor`、`saturate`、`query`、`replay`、`validate` 没有完整
receipt，必须 `not_measured`。历史 `measurements.json` 的 5/5/5/3/3 不可作为 corrected
count。新 run 必须写 `raw_line_ids`、`observed_count`、`corrected_count`，两者不一致
立即 `fail_closed`。

## 3. Budget, key, cache, supervisor

| domain | required negative controls | typed result |
|---|---|---|
| budget | invalid; sealed mismatch + over-limit simultaneously; omitted; equal; unsealed overload | `budget_invalid`; `budget_mismatch` wins over `terminal_deferred`; `no_op`; `rebuilt` |
| key | same full bytes; same forced digest/different full bytes; proposal/member/visited domain confusion; hostile hash/eq/iteration | `dedup_allowed`; `key_collision`; `key_domain_confusion`; `hostile_receipt_incomplete` |
| cache | repeated derivation; cross-derivation; cross-product; alias; mutation after seal; clear/drop; payload/hash/validate sharing | `cache_same_identity`; `cache_cross_derivation`; `cache_cross_product`; `cache_escape`; `cache_mutation`; `cache_entry_incomplete` |
| supervisor | missing supervisor exit/wall; child parent mismatch; timeout; nonzero supervisor; post Julia count != 0; raw hash mismatch | `supervisor.receipt_incomplete` and result is `terminal_deferred` or `not_executed` |

## 4. Path and status gate

Future source edits are limited to the four owners in `contract.md`; future evidence is
limited to `evidence-runs/<run_id>/**`. Any other path is `scope_violation`. No Julia,
DESC, S3, solver, mesh, search or physical process may start during this R2 static repair.
