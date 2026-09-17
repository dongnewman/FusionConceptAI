# M5-C Performance R2 repair-scope independent review R1 (R3)

## 裁决

**当前仍不授权 M5-C implementation，仍不授权 core performance repair，也不授权 bounded Julia/performance run。** R3 的 contract/schema/self-test 方向明显比 review-04 完整，但独立重放没有证明机器闭合：18 个 hostile vectors 中只有 15 个被目标 schema 拒绝；`condition-required-closure` 与 `cache-owner` 被接受，baseline vector 没有对应 schema。另有 fresh freeze receipt 的一个 current input hash 与当前文件不一致。

当前状态保持：`review_pending / not_implemented / implementation_authorized=false`，`formal_credit=none`。本 review 只写入 `reviews/06-repair-scope-independent-review-r1/**`；没有启动 Julia、M5-C probe、DESC、S3、solver、mesh、search 或 physical 进程，也没有修改源码、tests、oracle、probe、合同或既有 raw。

## 可复现证据

| 检查 | 结果 | 证据 |
|---|---|---|
| R3 Python schema/self-test | exit `0`，`status=pass`，24 tests，11 schemas，Julia count 0 | `raw/independent_self_test.stdout.raw` |
| 18 negative vectors 独立重放 | 15 schema rejects；2 schema gaps；1 no-schema semantic gap；exit `0` | `raw/negative_vectors_replay.stdout.raw` |
| R3 hash manifest | 21/21 records bytes+SHA-256 match | `raw/audit_checks.txt` |
| R3 manifest frozen owner inputs | 4/4 bytes+SHA-256 match | `raw/audit_checks.txt` |
| R3 freeze current inputs | 9/10 hashes match；AutoComposition hash mismatch | `raw/audit_checks.txt` |
| process/freeze | PowerShell PID `63576`；UTC `2026-09-17T04:37:31.7225905Z`–`04:37:31.7538841Z`；Julia count 0；HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d` | `raw/audit_checks.txt` |

The existing R3 raw line claiming `negative_vectors=18` is not sufficient as an independent result: the current validator script has 24 assertions and does not replay all 18 declared mutations. The independent replay is therefore retained separately and its three residuals remain release-blocking.

## 18 negative vectors

Rejected by the target schema: `condition-order`, `binding-missing-layer`, `binding-duplicate-layer`, `budget-mismatch-overlimit`, `budget-invalid-rank`, `preflight-writer`, `preflight-overflow-admit`, `collision-full-key-equal`, `collision-hostile-incomplete`, `collision-domain-confusion`, `supervisor-post-process`, `supervisor-timeout-completed`, `supervisor-exit-relation`, `cache-entry-bytes`, and `stage-zero-substitute`.

Residuals:

1. `condition-required-closure`: setting the required `rank` fact to `unknown` while retaining `required_all_met=true` is accepted by `condition_envelope_schema.json`. The schema fixes tuple positions and aggregate branch values, but does not require every required condition to be `met` or bind `fact_status/fact_value` to the aggregate.
2. `cache-owner`: changing an entry's `owner_derivation_id` from the top-level `derivation_id` to `d-2` is accepted by `cache_schema.json`. The positive custom check asserts the relation but no schema branch rejects the hostile mutation.
3. `baseline-typed-absent`: `baseline_capture_contract.json` has no JSON Schema. The declared mutation (`source_run_id` populated while `typed_status=typed_absent`) has no machine rejection path; it is a semantic gap, not a schema pass.

## Review-04 P1/P2 machine-closure recheck

| ID | R3 independent result | Remaining blocker |
|---|---|---|
| P1-01 manifest | **Partial** | Four frozen owner inputs are required with `contains` clauses, but artifact `relative_path` is not constrained to the write root, artifact path set is not exact, and artifact-to-file hash/bytes are outside the schema. |
| P1-02 preflight | **Partial** | `R`/`limits`, UInt128 fields, no-writer guards and admit/defer branches exist, but admitted projections/effective budget are not related to limits by schema. |
| P1-03 conditions | **Partial** | Fixed eight positional kinds and aggregate branches exist; required-all closure is not enforced. The declared negative vector is accepted. |
| P1-04 binding | **Partial** | Nine positional layers and expected arrays exist; `fields` are not linked to `expected_field_names`, and field booleans/object/hash relations are not cross-closed. |
| P1-05 budget | **Partial** | Relation/reason/status/rank branches exist; requested-vs-sealed inequality and a multi-reason “mismatch wins before over-limit” relation are not independently enforced. |
| P1-06 collision | **Partial** | Protocol, domains, emitted IDs and hostile receipt fields exist; payload/full-key bytes-to-hash, injected digest equality and full-byte authority are not all schema-enforced. |
| P1-07 supervisor | **Partial** | `post_process_count=0`, exit relation and termination/status branches exist; parent/child PID, UTC ordering, raw byte/hash and child/supervisor exit relations remain unenforced. |
| P2-01 freeze | **Blocked** | Current path records contain the expected ten files, but schema does not enforce the exact ten-path set and one frozen hash is stale/wrong: `ManufacturedAutoCompositionV1.jl` declares `...15af...`, current bytes hash to `...15ab...` (hex index 21 `f` vs `b`). |
| P2-02 stage receipt | **Partial** | Dedicated stage schema blocks `not_measured` with numeric zero, but it cannot prove raw line existence or receipt/hash/count equality. |
| P2-03 baseline | **Blocked** | Status is correctly `contract_only_not_captured`, `typed_status=typed_absent`, `source_run_id=null`, no receipt path/hash; no baseline schema machine-blocks an invalid typed-absent mutation. |
| P2-04 cache | **Partial** | Full byte fields and closed entry objects exist; entry owner/top-level identity, `entry_count==len(entries)`, and bytes-to-hash relations are not schema-enforced. The owner mutation is accepted. |

The positive self-test's custom assertions are useful evidence, but they are not a replacement for a schema or an independently executed receipt validator for the hostile cases above.

## Authorization and claim ceiling

* **Adapter-only implementation:** **Not authorized now.** Readiness R1's future `adapter_only_bounded_screen_only` suggestion remains conditional on machine-closure repair, corrected fresh freeze, and an explicit later authorization. R3's `implementation_authorized=false` remains controlling.
* **Core performance implementation:** **Not authorized.** No core canonicalization, saturation, key, visited-index, or cache seam may be modified under this decision.
* **Bounded run:** **Not authorized.** No bounded Julia smoke, M5-C probe, performance lane, cache-on comparison, or baseline comparison may run in this review state.
* **Baseline capture:** **Not captured.** `baseline_capture_contract.json` remains `contract_only_not_captured` / `typed_absent`, with null `source_run_id`, receipt path and receipt hash. A fresh unrepaired sealed baseline must be separately captured and independently reviewed after freeze/hash correction; no historical profile or static pass substitutes for it.
* **Claim ceiling:** `manufactured_conditional_egraph/screen_only` and `synthetic_egraph_equality/screen_only` only; no performance improvement, formal credit, provider/engineering/physical/search claim, or UP5/B00/B04/R01–R10 closure.

All missing receipts, timeout/program exception/human interruption, and `not_measured` stages remain deferred/not-executed and must not be encoded as numeric zero or performance pass. This review does not close the frozen parent goal.
