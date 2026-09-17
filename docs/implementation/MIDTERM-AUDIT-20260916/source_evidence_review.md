# AD54–AD56 source evidence review (2026-09-16)

本审计只新增本目录的 Markdown/JSON 两个文件；未运行 Julia/DESC，未修改源码、历史证据、索引、提交或既有 AD 目录。沿用本轮主审在 `2026-09-16T01:48:52.393843Z` 冻结的 5,968 文件基线（[before_inventory.json（行 1–5）](before_inventory.json)）；本审计目录本身在该基线中排除。

## 结论

当前仓库 `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`（`b2c04d8`，`feat: publish Genome V5 source closure`）。AD-54 的本地提交树可由 `git diff-tree --no-commit-id --name-only -r HEAD` 复核为 21 个路径；AD-54 root R1 只接受 `local source publication engineering evidence only`，没有 push/tag，也没有 source authority 或 trusted identity。见 [AD-54 report（行 3–15）](../AD-54/V5-SOURCE-PUBLICATION-COMMIT/report.md)、[AD-54 root acceptance（行 3–21）](../AD-54/V5-SOURCE-PUBLICATION-COMMIT/root_acceptance_r1/acceptance.md)。

AD-56 的 `accepted_limited` 只覆盖 Git text-filter/CRLF 下的 source-locator 软件修复。当前工作树三份 factory 源码均为 `M`，其修复是本次 AD-56 兼容性证据的实际实现；不能因为它们是 dirty 就把 AD55 R2 判为无效，也不能把该运行叫作纯 HEAD 重放。见 [AD-56 root acceptance（行 3–19）](../AD-56/GIT-FILTER-PORTABLE-SOURCE-LOCATORS/root_acceptance_r1/acceptance.md)。

AD-55 的旧 F0 确实因 raw working bytes 与 `git show HEAD:path` 不同而失败；AD56 修复后，AD55 `f0_s2_execution_r2` 的 F0、S2 run1、S2 run2 和独立复核均有真实 PID、raw stdout/stderr、exit 和 SHA-256，软件层结论为 `pass_limited`/`completed_review_pending`。该结论的准确名称应是：**HEAD 固定的六个 source-owner canonical locator，在当前工作树三份 AD56 factory 修复上执行的 source-stage 软件证据**。见 [AD-55 F0/S2 report（行 1–15）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/report.md)、[AD-55 independent review（行 1–16）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/report.md)。

## AD55 raw/PID/exit/hash 核验

旧 F0 失败记录仍然真实且应保留：PID `106900`，UTC `2026-09-15T23:37:16.1565303Z`–`23:37:41.5653984Z`，exit `1`；stdout `1ebc6da9a467155e9526101a116cb6808c8dd1ed42adfc9d65ab83e8fd600058`，stderr `9d3e28093355fbf2eaba66a90492071f135a6a920bcfd16f6fb01c6bbccd26b8`。原始记录明确把失败原因写成 G3 realization/control 的 `working_tree_head_bytes_mismatch`，见 [old F0 receipt（行 1–20）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_execution/f0_receipt.json)。

AD55 R2 和 independent R1 的成功 receipts 与当前 raw 文件重算一致：

| stage | PID / exit | raw stdout SHA-256 | raw stderr SHA-256 | evidence |
|---|---:|---|---|---|
| R2 F0 | `106008 / 0` | `28bdf0716c784d012429d663c9b16356515ecf6c9e8ec0c2c9a01306fb837a52` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | [receipt（行 1–18）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/f0_receipt.json) |
| R2 S2 run1 | `103996 / 0` | `81036d5a60f5c15455c9e80915b0a11c432000e91d2ee07875f67b93aa16a14d` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | [receipt（行 1–19）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/s2_run1_receipt.json) |
| R2 S2 run2 | `83504 / 0` | `81036d5a60f5c15455c9e80915b0a11c432000e91d2ee07875f67b93aa16a14d` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | [receipt（行 1–19）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/s2_run2_receipt.json) |
| independent F0 | `81652 / 0` | `4a55e9fc415ef503032021086261b4847793002ac4359fcb50d9f9031d82d6d7` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | [test receipts（行 1–36）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/test_receipts.json) |
| independent S2 run1 | `89396 / 0` | `81036d5a60f5c15455c9e80915b0a11c432000e91d2ee07875f67b93aa16a14d` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | [test receipts（行 37–71）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/test_receipts.json) |
| independent S2 run2 | `101616 / 0` | `81036d5a60f5c15455c9e80915b0a11c432000e91d2ee07875f67b93aa16a14d` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | [test receipts（行 72–106）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/test_receipts.json) |

F0 raw `f0_r2.stdout.raw` 为 27,828 bytes，独立重算 SHA 与 receipt 一致；S2 两次 raw stdout 各 66 bytes，SHA 相同；所有对应 stderr 为 0 bytes、空流 SHA。F0 原始输出实际逐个打印 G3 `realization/control/binding/bundle` 的 `present` 诊断，S2 stdout 为 `AD55_S2_PASS=true`, `AD55_S2_SCOPES=6`, `AD55_S2_NEGATIVE_CONTROLS=pass`，见 [F0 raw](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/f0_r2.stdout.raw) 与 [S2 raw](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/s2_run1.stdout.raw)。

## 18 与 19 的重算

正确的 canonical output 数是 **18**：G1 3 个、G2 3 个、G3 四个 scope 各 3 个，即 `6 × (identity + declaration + receipt) = 18`。当前证据有三个相互一致的独立计数：

1. `s2_determinism.json` 的 `files` 数为 18，且 `all_equal=true`，见 [determinism（行 1–194）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/s2_determinism.json)。
2. independent R1 的 `canonical_outputs.count=18`、`all_equal=true`，见 [test receipts（行 98–106）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/test_receipts.json)。
3. `s2_run1` 和 `s2_run2` 各有 20 个 JSON，但其中 `negative_controls.json` 与 `s2_status.json` 是运行状态/控制 sidecar；去掉这两个后各剩 18 个 canonical identity/declaration/receipt 文件。

因此 [AD-55 R2 report（第 7–11 行）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/report.md) 的 “all 19 canonical JSON hashes” 是文案计数错误；不应据此增加一个不存在的 canonical 产品，也不应修改历史 raw/receipt。未来 acceptance/archive 应将其改为 18，并保留本审计作为矛盾核对记录。

## 当前 HEAD、dirty factory 与源码 publication 的边界

AD54 root 记录的本地提交树确实是 21 个 source overlay 路径，见 [AD54 root manifest（行 13–24）](../AD-54/V5-SOURCE-PUBLICATION-COMMIT/root_acceptance_r1/manifest.json)。但当前工作树的三份 factory 源码均已偏离该 HEAD blob：

| file | current raw bytes / SHA-256 | HEAD blob OID | AD55/AD56 role |
|---|---:|---|---|
| `src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl` | `31396` / `de5a0d14d71c02244df6344c1a339a56d3dc051f115d975a4072a260d0204bf2` | `0a78e7c279b394345b8b6923b225bf3eb7fbc6d4` | dirty AD56 repair |
| `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl` | `27640` / `2e15b97676e8cef51af62c47f83f0bce061e98366e42d3d68bb2a120876436fc` | `50a9135a77fd4fbad450755abfe761a296386ec8` | dirty AD56 repair |
| `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` | `35485` / `d07805ce5b708be33232fccd25fd491ef4bd8a05c6320ccef4b274ef4644b05e` | `84a4b5e264dc77c81d88d704028dc12a490f6454` | dirty AD56 repair |

AD55's probes explicitly call `Base.include` on those working-tree paths after `load_genome_v5_components!`, while their locator bytes are obtained from `git show HEAD:path`; see [R2 probe（行 21–33）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/f0_probe.jl) and [independent probe（行 21–33）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/f0/f0_probe.jl). Thus the six source-owner files are canonicalized to HEAD, but the factory executable logic is the dirty AD56 repair. This is a meaningful, bounded software run with a mixed revision boundary; it is not a pure HEAD replay.

The six source-owner locator values are consistent with AD56's intended separation: G1 declaration 31,743 bytes, G2 declaration 30,773, G3 realization raw 33,751 vs canonical 33,750, control raw 10,297 vs canonical 10,287, binding 10,904, and bundle 6,704. Their canonical SHA values are recorded in [R2 hash inventory（行 1–101）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/hash_inventory.json); the two CRLF raw differences are accepted by the filtered OID check and are not evidence of invalid source.

The AD54 local commit does not contain `docs/v4_multitopology_generation/task_manifest.json`: `git cat-file -e HEAD:docs/v4_multitopology_generation/task_manifest.json` exits 128 while the current working file is 91,208 bytes with SHA `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`. Therefore `31/534/39/acyclic` is a working-tree planning check and must not be described as part of the 21-path HEAD publication tree. The current [18_sources_and_architecture_decisions.md（行 451–468）](../../v4_multitopology_generation/18_sources_and_architecture_decisions.md) contains AD-50 and AD-56 entries but no AD-55 entry. The archive scan therefore found no local Sol-signed AD55 acceptance in that core document set; the current audit directory separately records the user-relayed Sol `accepted_limited` decision and its `decision_origin` in [AD55_decision_archive.md（行 3–5）](AD55_decision_archive.md). This preserves the user relay without presenting it as a locally signed artifact.

输入闭包的可审计记录仍有缺口：R2 `hash_inventory.json` 记录了六个 source-owner、三份 dirty factory、task manifest、AD45 envelope 与 AD56 root acceptance；independent inventory 记录六个 source-owner、18 个 canonical outputs 与 task manifest，但两份 inventory 都没有把实际执行的 `f0_probe.jl`、`s2_probe.jl`、independent F0/S2 probe 及其测试 harness/完整加载依赖的字节哈希冻结为逐项清单。命令、cwd、PID、exit、raw stdout/stderr 哈希、HEAD locator 和 dirty factory 哈希均有记录，所以这是输入闭包审计性不足，不能据此推翻已复核的软件运行。下一次 fresh F0/S2 应先冻结这些 probe/harness 与完整加载依赖的 SHA-256，再执行并把它们绑定到同一 revision receipt；相关执行入口见 [R2 F0 probe（行 21–33）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/f0_probe.jl)、[R2 S2 probe（行 1–40）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/s2_probe.jl) 和 [independent F0 probe（行 21–33）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/f0/f0_probe.jl)。

## Fresh S3 trust-root blocker

The existing S3 contract records the missing matrix explicitly: independent attestor, attestor key, certificate, signature, verifier, trust root, revocation policy, freshness policy and trusted time are absent. A challenge/nonce may be freshly generated by the verifier, but it must still be bound under the frozen protocol to the signed object, freshness and anti-replay checks; this does not relax the replay gate. The gate is `blocked_external_trust_root_and_source_closure`. See [AD49 S3 report（行 3–15）](../AD-49/S3-TRUSTED-SOURCE-IDENTITY/report.md), [manifest（行 64–80）](../AD-49/S3-TRUSTED-SOURCE-IDENTITY/manifest.json), and [root record（行 3–10）](../AD-49/S3-TRUSTED-SOURCE-IDENTITY/root_acceptance_r1/acceptance.md).

Software can provide the verifier, generate a local signing key for a system it controls, generate a fresh challenge/nonce, and bind it under the frozen protocol to the signed object, freshness and anti-replay checks. It can perform canonical source/HEAD/blob and filtered-OID checks, bind candidate/source data, parse signed payloads, validate a certificate chain against a supplied root, check revocation/freshness/time/nonce, replay deterministically and fail closed. Software cannot turn its own key or nonce into an independent attestor, certificate, signature or external root-of-trust decision; it cannot self-authorize a revocation authority or trusted time source. The external attestation package, its authority and root decision must come from the user or an external authority and remain candidate-bound and independently verifiable. Local construction receipts, review identity, fixtures, URI/seed, test exit, provider root, or a locally generated hash cannot promote `trusted=true`.

The smallest honest S3 path is therefore: (1) freeze the exact source/publication revision and resolve the dirty factory boundary; (2) run fresh S3 against the currently available closure and honestly emit `typed_absent`/missing-matrix results, without fabricating trust; (3) when external signed attestation material and verifier policy arrive, rerun S3 with those candidate-bound inputs; (4) rerun F0/S2 only if the exact inputs or HEAD changed, or to fill the input-closure hashes identified above. Until then, AD55 remains source-stage software evidence only.

## Source F0–S3 versus B00 F0–F5

AD55 F0/S2 proves factory loading, six source-owner locator checks, typed absence controls, six present source-stage construction products and deterministic replay. It does not prove S3 trusted identity, CandidateIdentity, final package identity, provider, mesh, solver, engineering readiness, physics or search. The independent review and all receipts keep these flags false; see [AD55 review manifest（行 26–46）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/manifest.json).

No AD55 evidence here closes B00 F0–F5. Per [19_up0_02_contract_freeze.md（B00 F0–F5，行 36–53）](../../v4_multitopology_generation/19_up0_02_contract_freeze.md), B00 covers F0 input registration, F1 canonical package, F2 independent replay, F3 label erasure, F4 routing/compatibility and F5 evidence closure. AD55 source F0/S2 does not supply those B00 manifests, two-process canonical package comparison, label/routing diffs or B00 receipts; document hashes, runner exits and root acceptance cannot substitute for those gates. Therefore `B00=false` and `B04=false` remain unchanged; no B00 F0–F5 credit is inferred here.

## Minimal next action and required wording repair

本轮新增记录已归档 AD55 decision/status，带有 `decision_origin=user_relayed_Sol_report`、修正后的 18 计数和 mixed-revision wording；后续只引用或追加更正，不重复创建归档。若 AD56 修复提交为新的 publication revision，则在新 HEAD 上 fresh F0/S2；若 inputs/HEAD 不变，既有 pass 无需重复，只需补齐上述 input-closure 哈希。Fresh S3 可立即运行并诚实记录 typed absence；任何 trusted claim 仍须外部 trust-root 输入。任何步骤都不意味着 B00 已执行。

审计写入范围：`docs/implementation/MIDTERM-AUDIT-20260916/source_evidence_review.md` 与同名 JSON；未写其他路径。
