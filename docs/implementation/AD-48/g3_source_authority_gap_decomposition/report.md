# AD-48 G3 source-authority gap decomposition

日期：2026-09-15  
状态：`readiness_audit_only`  
验收：`accepted=false`  
范围：只读拆解 AD-47 W1 的 G3 source locator、factory identity、trusted attestation/source identity 三道门；定义有限、无环、可派发的后续工作单。未实现任何门、未修改源码/测试/fixture/核心清单/既有产品，未运行 Julia、DESC、provider、mesh、solver、engineering、physics 或 search。

## 基线与真实证据

仓库根是 `D:\006-Programing\LMC\FusionConceptAI`，观察 HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。审计时工作树有 332 条 dirty 状态；已有修改全部保留。审计使用 `D:\Users\Newman\anaconda3\python.exe`，Python `3.13.5`，PowerShell PID `79820`，UTC `2026-09-15T12:40:19.0244568Z`。原始规划校验输出、基线探针、源码哈希探针和 factory 检索输出保存在本目录 `archive/`。

重新运行 `docs/v4_multitopology_generation/validate_plan.py` 的结果为 `31` 个 markdown、`497` 个相对链接、`39` 个任务、DAG acyclic，exit `0`。`git diff --check` exit `0`；其 LF/CRLF warning 属既有工作树卫生提示。两者都不能作为物理或工程证据。

AD-47 W1 的不同 Luna R1 已以 `pass_limited` 复核 8 个冻结 JSON 产品（156/156，Python 3.13.5，PID 81064，exit 0）。四个 scope 都是 `AbsentG3SourceAuthorityRecordV1` + `AbsentG3SourceAuthorityReceiptV1`，统一原因 `missing_source_locator_factory_identity_and_trusted_attestation`，`resolution=terminal_deferred`，`no_publish=true`。W1 八产品的冻结 SHA 由 R1 记录，且本审计没有改动它们。W1 仍不给 source authority、candidate/declaration/final identity、T0/T1/T2、provider、mesh、solver、工程、物理、搜索、R01–R10 或 L4 credit。

当前 G3 源字节的只读探针如下；它们都是 working-tree 内容，代表性路径在 HEAD 中为 `absent_untracked`，不能直接称为 committed source authority。

| scope | 主要现有源码 | bytes | 当前 SHA-256（长度） | 观察到的构造入口 |
|---|---|---:|---|---|
| realization | `src/GenomeV5/G3/RealizationGenomeV5.jl` | 33751 | `0034f0c494df9a61f6e753d6d0b7f0fbca2d1a21eccf915ad3bba25ca427f6fb` (64) | `RealizationGenomeV5`; child helpers `g3_realization_source_record_v1`, `g3_realization_source_payload_v1`, `g3_realization_initial_state_v1` |
| control | `src/GenomeV5/G3/ControlGenomeV5.jl` | 10297 | `eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135` | `ControlGenomeV5`; child helpers `g3_control_initial_state_v1`, `g3_control_admit_source_v1` |
| binding | `src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl` | 10904 | `21187643295f3c115f3a2eb52c40aafcc039c75cc3a22bff59d5800b21c9d5e4` | `CoupledRealizationControlBindingV2`; child helper `g3_binding_source_record_v1` / `g3_binding_source_payload_v1` is in `G3BindingChildEditabilityV1.jl` |
| bundle | `src/GenomeV5/G3/RealizationControlGenomeV5.jl` plus `G3SourceFeedbackLawV1.jl` | 6704 + 27969 | `8e9d4f1505098b745048a5f741e0cb1edcccdcf70a395c212f0a8649a73d62a4` + `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` | `RealizationControlGenomeV5`; feedback declaration constructor `g3_sf_declaration_v1` |

The full bundle closure also needs the existing `RealizationGenomeV5.jl`, `ControlGenomeV5.jl`, and `CoupledRealizationControlBindingV2.jl`; W1's bundle locator is therefore a snapshot, not a complete independently frozen bundle source closure.

### R1 hash repair and recomputation

The previous AD-48 product set had one documentation-only defect: the RealizationGenomeV5 SHA was recorded with 63 hexadecimal characters. It is now exactly `0034f0c494df9a61f6e753d6d0b7f0fbca2d1a21eccf915ad3bba25ca427f6fb`, length 64, matching the current 33751-byte file. A fresh Python 3.13.5 probe recomputed all eight source rows, asserted `len(sha256)==64` for every row, matched bytes and hashes, and confirmed representative `git ls-files` absence. The corrected products remain observation-only; the source files were not edited.

## Why the W1 `source_locator` snapshot is not authority

W1 records do contain useful fields: repository root, observed HEAD, path, bytes, SHA, role, `head_blob_sha256=null`, `head_path_status=absent_untracked`, and working-tree status. The fields are internally consistent with the files at the W1 observation time, and they are valid negative evidence for why W1 returned `Absent`.

They are not an independent `SourceLocatorV1` authority input for five reasons. First, the locator is embedded in the same W1 record/receipt whose source authority it is supposed to establish; no separate freeze or independent owner signs that locator. Second, the source paths are untracked and the HEAD blob is null, so the snapshot proves only observed working-tree bytes, not a committed source boundary. Third, it has no G3-specific factory identity or re-playable construction entry that turns those bytes into the declared source object. Fourth, it has no trusted source identity attestation tying exact source bytes and semantic identity to a non-self-reviewing authority. Fifth, the W1 `source_locator` is not a complete bundle closure and does not establish source mutation invalidation beyond the stated absence rule.

The repository does contain generic `SourceLocatorV1` and `FactoryConstructionReceiptV1` types in `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl`, but the G3 sources have no adapter or present construction path to them. That file is a parent-baseline typed-absence scaffold; treating its type names, a test exit code, an AD-45 handle, a fixture, a URI, a payload hash, or the W1 record's own hash as G3 authority would be circular. No `default_operator_registry()` change is allowed or needed for this decomposition.

## Three finite gates

All three gates cover exactly `realization`, `control`, `binding`, and `bundle`. Each implementation is assigned to `gpt-5.6-luna/high`; each has a different Luna/high independent reviewer. Every gate records canonical JSON, exact bytes/SHA, path/control replay, PID/UTC/exit/raw receipts, failure history and task-owned cleanup. No gate starts heavy Julia/DESC/mesh/solver execution.

### AD48-S1 — independent source locator freeze

Exact products: **8 JSON products** under `docs/implementation/AD-48/S1-SOURCE-LOCATORS/`, four scopes each with `source_locator_v1.json` and `source_locator_receipt.json`. Schemas are `G3IndependentSourceLocatorV1` and `G3IndependentSourceLocatorReceiptV1`. Result unions are `PresentG3SourceLocatorV1 | AbsentG3SourceLocatorV1 | FailedG3SourceLocatorV1` and the corresponding receipt union.

The locator must close the repository root, observed HEAD, `git ls-files`/HEAD absence or committed status, working-tree dirty/untracked status, exact relative path, exact UTF-8 bytes, SHA-256, role, scope, and observation UTC. The bundle scope must list the complete source closure: `RealizationControlGenomeV5.jl`, `CoupledRealizationControlBindingV2.jl`, `RealizationGenomeV5.jl`, `ControlGenomeV5.jl`, and `G3SourceFeedbackLawV1.jl`; its dependent child-editability source/test receipts are inputs, not silently omitted source bytes. A source mutation, HEAD change, root change, path change, or closure change invalidates the old locator and requires a fresh locator input.

Inputs are the eight W1 products, current repository/HEAD/dirty probe, and the exact G3 source paths above. Outputs are independent locator records and receipts only. If a path is missing or untracked status cannot be closed, the result is `Absent...` with `terminal_deferred`; contradictory bytes/status/path evidence is `Failed...` with `fail_closed`. It may run in parallel with the already prepared G3 axis schema work, but must complete before S2 or S3. It cannot generate any candidate/declaration/final identity hash.

### AD48-S2 — factory identity and construction receipt

Exact products: **8 JSON products** under `docs/implementation/AD-48/S2-FACTORY-IDENTITIES/`, four scopes each with `factory_identity_v1.json` and `factory_construction_receipt.json`. Schemas are `G3FactoryIdentityV1` and `G3FactoryConstructionReceiptV1`. Result unions are `PresentG3FactoryIdentityV1 | AbsentG3FactoryIdentityV1 | FailedG3FactoryIdentityV1` and the corresponding receipt union.

S2 depends on S1 and must use actual types and entry points. Its inputs include each frozen locator, module/file identity, the actual constructor signature, contract ref/version and axis inputs, and the child-editability source record/payload/state helpers. The present receipt must replay construction from declared inputs, record module path and exact source bytes/SHA, constructor/function/type name, argument schema, registry state (or explicit `registry_not_used`), semantic/declaration/content hash inputs, and the fact that candidate identity is still not created. It may not use `RealizationControlGenomeV5.candidate_hash` as a parent `CandidateIdentityV1`.

The current source has constructors and helpers, but no G3 source-authority factory that consumes an independent locator, produces a candidate-bound source declaration, and emits a trusted construction receipt. Therefore the first S2 run is expected to be `Absent...` unless a real existing entry is proven. If no such entry exists, the implementation work order is a separate minimal unit, `AD48-F0-G3-SOURCE-AUTHORITY-FACTORY`, owning exactly `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` and `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl`; it must expose four scope-specific typed constructors/receipts, preserve absent/fail-closed unions, and leave `default_operator_registry()` unchanged. S2 itself must not implement those files.

The factory implementation unit is conditional and cannot start before S2's real-source probe has produced `AbsentG3FactoryIdentityV1` evidence. After that evidence, it depends on S1 and the real existing constructors; its different Luna reviewer owns only its two files and raw archive. A missing factory is not repaired by relabeling W1, a fixture, a seed, a URI, the AD-45 handle, or a test exit code.

### AD48-S3 — trusted attestation and source identity review

Exact products: **8 JSON products** under `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/`, four scopes each with `trusted_source_identity_v1.json` and `trusted_source_identity_receipt.json`. Schemas are `G3TrustedSourceIdentityV1` and `G3TrustedSourceIdentityReceiptV1`. Result unions are `PresentG3TrustedSourceIdentityV1 | AbsentG3TrustedSourceIdentityV1 | FailedG3TrustedSourceIdentityV1` and the corresponding receipt union.

S3 depends on S1, S2, the exact source semantic-body/declaration inputs, and a different Luna source-identity review. The attesting party is the independent reviewer, identified by task/reviewer/model/PID/UTC and detached receipt hash; the root Sol records acceptance of the review but is not the sole source attestor. The local trust boundary is repository-local provenance: exact source bytes, semantic identity, locator, factory construction and source-change invalidation. It does not attest provider availability, mesh, solver convergence, engineering feasibility, physical output, originality, or R01–R10. If the repository has no real signing/key mechanism, the receipt must remain `Absent...`; an unsigned self-authored JSON field is not trusted attestation.

Present requires exact source bytes and semantic identity, complete scope closure, factory identity/receipt, candidate-bound input supplied by the independent identity owner, reviewer attestation, and a rule that any source byte or semantic change forces a new identity input. Missing signer, source identity, candidate-bound source input, or complete closure is `Absent...` + `terminal_deferred`; mismatch or stale/foreign attestation is `Failed...` + `fail_closed`. S3 cannot generate `CandidateIdentityV1`, declaration hash, T0/T1/T2, physical evidence or search credit.

## Dependency, re-build and forbidden edges

The legal order is:

`AD47-W1 independent review → AD48-S1 → AD48-S2 factory probe → (AD48-F0 only if S2 proves factory absent) → fresh AD48-S2 receipt → AD48-S3 → fresh W1 eight-product re-materialization → AD47-W2 candidate-bound G3 axes`.

AD48-S1 and the already planned AD47 G3 axis-schema extension can be prepared in parallel after parent review. S1 can be dispatched once the AD47-W1 review and parent scope check are recorded. S2 cannot begin before S1's exact locator result. F0 is forbidden before S2's explicit factory-absence evidence; after F0, S2 must be rerun to create a fresh construction receipt. S3 cannot begin before S1/S2 and a different Luna source-identity review. The fresh W1 reconstruction is required after any source/factory/attestation input changes and after S3 closes; old W1 products are immutable historical absence records. W2 remains blocked until the fresh W1 result, the common AD-45 handle, a real G2 mapping, and all candidate-bound attestations are independently present.

Forbidden edges for all gates are candidate/declaration/final identity fabrication; deriving common refs or identities from fixture, seed, URI, W2R1 payload, bundle hash, own hash, test output or runner exit; rewriting AD42–47 products; modifying `default_operator_registry()`; modifying `src/`, `test/`, fixture or core planning during this audit; T0/T1/T2, UP2, provider/mesh/solver, engineering, physics, search and R01–R10 execution. A gate's software receipt, document, test, or exit code never substitutes for source, engineering or physical evidence.

## Closure decision

This decomposition is `readiness_audit_only` with `accepted=false`. It closes the scheduling shape of the three missing W1 gates, but none of the gates is implemented or present. The current source locator snapshots remain useful typed-absence evidence and remain insufficient authority inputs. G3 source-backed declaration, factory identity, trusted source identity, candidate-bound axes, child join, inverse realization feedback, provider/mesh/solver and all R01–R10 claims remain false; L4 credible count remains zero.
