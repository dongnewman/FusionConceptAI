# UP1 R4 final independent adversarial review r1

审查时间：2026-09-17（Windows；只读、离线；未运行 Julia/DESC/solver/S3/网络）。本审查只新增本目录的审查与 raw/hash，不修改 `tools/`、`test/` 或 00–14/R3/R4 既有证据。

## 分开的裁决

### Software scope

**`REJECT_FOR_INTEGRATION_CLOSURE`（P1）。** 当前 R4 本地软件保持 fail-closed / no-publish 的大部分边界，但发现一个真实生产集成缺口：`merge_stage_results` 不验证跨 stage binding tuple 的一致性；冲突 candidate/source/run/request/bundle 等值会被 `_binding` 的 first-value 选择吸收为 `terminal_deferred`，而 02 G3 明确要求 foreign/stale binding `fail_closed`。独立运行已复现（raw `runtime.cross_binding_conflict_merge`）。

另有一个候选环境路径安全 P1：`environment_closure._safe_path` 在 `_is_reparse` 前调用 `Path.resolve(strict=False)`，因此会先跟随 symlink/reparse 到目标再检查目标，不能支持文档所称的“without following reparse points”。Windows 本次无法创建 reparse fixture，故运行态攻击证据是 `test_scope_deferred`；静态顺序证据仍足以保留该风险，不能把本地环境观察提升为 candidate-bound provenance。修复应在原始 lexical path 上先做 reparse/根边界检查，且检查异常应 fail-closed。

已经修复且本次独立抽样确认的边界：intake 对 digest-named hardlink 返回 `immutable_alias`，`root/../escape` 返回 `path_escape`；freshness 缺 trusted time 返回 `trusted_time_absent`，不使用 OS wall clock；G2 unknown status 返回 `fail_closed`；publication lock 尝试被归一化为 `PUBLICATION_LOCK`/aggregate `fail_closed`；stage order 与 02 合同均为 `atomic_bundle → authoritative_intake → source_axis_binding → g2_mapping → environment_closure → trust_chain → freshness`；R4 implementation manifest 的 6 个列出生产文件当前均 bytes/hash match。

### Formal / external scope

**`BLOCKED / NO CREDIT`（不是软件 PASS）。** R4 scan 明确 `26/26` external records `typed_absent`，`usable_count=0`，本次无 fresh delta；因此不产生 `externally_verified`、T0/T1/T2、formal credit、authority credit 或 publication。`new_ad=false`、`s3_rerun=false`，不能因为本地测试通过而改变 parent goal、R01–R10 或启动 AD/S3。Environment closure 仍是 `local_observation_only`，缺 source receipt/signature/download receipt/SBOM/build recipe/lock-or-channel-freeze/binary inventory；它不是权威环境证明。

## P1/P2 findings

### P1-001 — production cross-stage binding is not fail-closed

Evidence: `tools/up1_external_closure_r4/integration/orchestrator.py:364-372` computes normalized states and calls `_binding`, but does not compare non-null identity fields across stages or reject a missing/partial stage map. Independent probe supplied `atomic_bundle.candidate_id=A` and `authoritative_intake.candidate_id=B`; observed aggregate `status=terminal_deferred`, `decision=terminal_deferred`, `failure_stages=[]`, `binding.candidate_id=A`. Contract `02-integration-contract/integration-acceptance-gates.md:11` requires one candidate/source/run/request/bundle scope and foreign binding → `fail_closed`.

Required closure: compare every present tuple member and exact packet/CAS/receipt digest across all stage outputs; any contradiction is hard `fail_closed`/`rejected_all`; require the complete `STAGE_ORDER` set at the public merge seam. Preserve raw stage receipts and do not choose the first value as identity.

### P1-002 — environment reparse path is followed before detection

Evidence: `collector.py:52-68` resolves with `path.expanduser().resolve(strict=False)`, while `collector.py:71-77` performs `lstat` only after resolution. A symlink/reparse input can therefore be transformed into its target before `_is_reparse` sees it. `collector.py:74-75` also maps any `lstat` OSError to `False`, which is not a conservative rejection. This undermines environment source/path provenance even though the collector remains read-only.

Required closure: inspect the supplied path components without following links, enforce the declared root boundary, treat inspection errors as typed failure, then hash only the verified regular file. Repeat on a Windows host where reparse creation is permitted.

### P2-001 — Windows reparse runtime coverage remains deferred

The independent CAS/path probe and prior 03/04/05/06/12 evidence all record Windows `WinError 1314` when creating symlink/reparse fixtures. This is a capability skip, not a pass. Hardlink and lexical traversal were independently exercised, but no runtime evidence closes Windows junction/symlink/reparse behavior. Keep this as `test_scope_deferred`; do not downgrade it to “safe”.

### P2-002 — R22 direct-wire acceptance is incomplete

The predicate review explicitly records that R22 uses a clean EHP-04 semantic payload because the complete wire envelope has a self-referential quarantine raw digest; R22 remains `_check_ehp04 → terminal_deferred` with no failure code. The 9/9 dispatch trap therefore proves production dispatch only, not complete external-wire acceptance. Keep the R22 direct-wire limitation visible.

No additional P0 was found. The absence of a real external-authority adapter/response is a formal blocker by contract, not evidence of a hidden authority path.

## Adversarial coverage matrix

| Area | Independent/current evidence | Ruling |
|---|---|---|
| Production calls / stage order | AST source check; empty production `run({})`; 14/13/14/15 existing focused lanes | Calls and order bounded; full positive path `test_scope_deferred` |
| Typed states / precedence | empty request, G2 bad status, publication-lock injection; 02 taxonomy | Fail-closed for tested hard cases; cross-binding P1 remains |
| CAS/path/hardlink | `immutable_alias`, `path_escape` raw results; intake repair oracle | PASS-limited for tested Windows regular paths |
| Trusted time | `_validate_trusted_time(None,...) → trusted_time_absent`; repaired 11 suite 13/13 | PASS-limited; no external TSA evidence |
| Replay / CAS | existing 05 serial replay/CAS lanes and freshness source audit | local software only; no authority/replay receipt |
| Source/axis | existing 09 source drift/identity suite; raw `EXTERNAL_ISSUED` remains adapter input only | PASS-limited structural; no derived `externally_verified` |
| G2 | 07 + 10 repair lanes; current unknown-status probe fail-closed | PASS-limited structural; no authoritative mapping |
| Environment provenance | independent temp-root collection returns `typed_absent`, explicit missing provenance and local-observation ceiling | Non-authoritative; P1-002/path test gap |
| Receipt binding / publication lock | stage hashes/receipt refs; lock injection aggregate `fail_closed`, `formal_credit=none`, `authority_credit=false`, `no_publish=true` | Lock bounded; cross-stage identity comparison missing |
| External delta | R4 inventory: count 26, typed_absent 26, usable 0; scan says no fresh response material | No fresh delta; no new AD/S3 |

## Evidence and replay boundary

The independent runner is [audit_independent.py](audit_independent.py). It only imports frozen production APIs and uses temporary directories. Raw stdout/stderr/exit and machine JSON are in `raw/`; `evidence_manifest.json` records byte counts and SHA-256. The machine record also captures the current 6/6 implementation hash checks, 26/26 absence state, no-fresh-delta/no-AD/no-S3 controls, direct-wire R22 limitation, CAS/path/hardlink results, trusted-time result, G2, environment ceiling and publication locks.

This review is an adversarial software review, not a claim that any local receipt, system certificate store, Git timestamp, mtime, local hash, TEST_ONLY fixture, or screen/test pass is external authority. Formal scope remains blocked until a real owner/channel supplies a complete fresh candidate-bound EHP set with independently verifiable trust/time/revocation/replay/G2/source/axis/environment receipts.
