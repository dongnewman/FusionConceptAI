# M5 inverse-feedback R2 — scope-contract repair R2

状态固定为 `review_pending` / `not_implemented` / `not_executed` / `screen_only` / `formal_credit=none`。本包只修复 independent review R1 的 F7–F12 合同缺口，写入边界仅为本目录；不修改历史包、生产源码、测试源码、registry、task graph、candidate 或任何 provider。

## 1. Canonical join（F7）

`canonical_bundle_schema.json` 将 G1/G2/G3、parent baseline、mission、scenario、source 都建模为同一种 `typed_ref`：`uri`、`version`、`schema_hash`、`canonicalization_hash`、`compatibility_profile`、`content_sha256`、`body_sha256` 与 typed `body` 均必需。parent 不再是只有 ref/content/owner 的松散对象。

`checker_contract.json` 冻结可执行的跨对象检查：candidate/body、bundle payload、binding projection、source owner/provenance、mission/scenario foreign keys 和所有 digest 必须按 JSON Pointer 相等或由 canonical bytes 重算；值不一致必须 `fail_closed`。JSON Schema 负责 closed shape，typed checker 负责 equality 和 digest，不能由孤立的 `check_schema` 代替。

## 2. Resolver 与 replay gate（F8/F9）

所有跨 schema `$ref` 使用绝对、文件无关的 `urn:fusionconceptai:m5-inverse-feedback-r2:03:*` URI。`resolver_registry.json` 是冻结的 local registry，逐项给出 URI、相对文件、字节数和 SHA-256；resolver 只允许 registry 中的 URI，拒绝网络、隐式 base URI、未知 URI 和 registry/hash 漂移。

`valid_screen` 不是一个可由 `valid=true` 单独声明的标签。它必须同时满足两次 serial replay、两个唯一 attempt id、`exit_codes=[0,0]`、semantic/byte equality、fresh-refreeze authority、非空 raw/process refs、fixture applicability 和 typed checker pass。任意缺项都只能产生 `typed_failure`、`fail_closed` 或 `not_executed`。

## 3. Feedback CAS/history（F10）

feedback edge identity 是 candidate/source/owner/edge/parameter/axis/direction 的不可变 tuple。删除操作只允许预注册的 beta/interface edge；`expected_version` 必须与当前 edge 和 history 的 `before_version` 相同，成功删除只产生一个 `after_version=before+1` 的 append-only record。每条 record 要有 canonical before/after bytes digest、owner/actor、UTC `Z` 时间、sequence 和 identity tuple。stale、duplicate、foreign owner/candidate、wrong direction、dynamic insert、非 UTC 和 fail-atomic 破坏均为确定性拒绝。

## 4. Dependency/dirty closure（F11）

manifest 不再把一条 git-status 摘要当作 closure。它冻结六个 M5/M5-A source/test/oracle、`Project.toml`、`Manifest.toml`，并为每项记录 role/path/bytes/SHA-256/import closure；`m5a_composition` 是独立角色。dirty baseline 由 `git status --porcelain=v1 -z` 的逐路径记录、每个可读文件的 bytes/hash、review-start HEAD/UTC 组成；review-end 只能增加本目录 additive paths，基线已有 dirty paths 不得被归因给本 repair。

## 5. Failure taxonomy（F12）

`failure_record_schema.json` 与 `failure_taxonomy.json` 共享同一 code/class/resolution 集合。`checker_contract.json` 要求集合完全相等、code 唯一、每个 code 恰有一个 class/resolution；unknown code、resolution mismatch 或重复 code 都 fail closed。failure record 的 raw context 保留 stdout/stderr、PID、exit code 与 UTC `Z`，不得把异常改写成物理或工程通过。

## Evidence ceiling

本包只提供 schema/registry/checker contract、静态 parse/shape/invariant audit 和 hash manifest。没有执行 Julia、DESC、S3、mesh、solver、provider、network 或 hardware，没有 replay 当前 M5/M5-A，也不授予 UP4/B07A/B07B/B08、R01–R10、工程、物理、candidate 或 formal 信用。后续实现仍需 isolated Python-oracle → typed-checker lane、fresh refreeze、两次 replay、独立复核和 Sol/root 裁决。
