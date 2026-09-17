# M4-SCOPE-DECISION-R1 独立复核 R1

## Verdict

`changes_requested`。本复核只裁决 M4 范围决策文件，不授予任何实现、UP2/B00/B04、物理、工程或 R01–R10 信用；Sol 仍是唯一接受者。

## Scope checks

- 三个且仅三个产品已列入 `manifest.json`，实际存在且其 SHA-256 与 `archive/final_hashes.json` 一致：`decision.md`、`manifest.json`、`cleanup_inventory.json`。
- `archive/` 中的 validation receipt、JSON/hash、格式/链接/静态检查 raw 与失败历史均保留；Julia/solver 未运行，`code_tests=not_applicable` 合乎文档范围。
- A 仅为显式 manufactured/analytic steady scalar diffusion 的 declaration → equation/residual IR；B 为独立 review + Sol acceptance 后的 contingent scope；C/D 明确 `not_dispatched`。未来四个 ownership 路径当前均不存在，未发现要求修改 shared entry、`default_operator_registry()`、旧 evidence 或 `runs/` 的授权。
- 39 节点、R01–R10 和正式门在决策中保持未关闭；`T0 → recheck → T1 → T2`、UP2-00、UP1-04B 50、B00/B04 和 solver-input hashes 被保留，但 formal reentry 应显式补上既有路线中的 `aggregate → UP1-04`。

## Independent mathematical check

令 `u=x/L+y/L+z/L`，则 `grad u=(1/L,1/L,1/L)`。因此

`div(K grad u) = 0.1/L^2 + 0.05/L^2 + 1/(30 L^2) = (6+3+2)/(60 L^2) = 11/(60 L^2)`.

在 `L=1 m` 且 `u` 无量纲时，`div(K grad u)=11/60` 无量纲；由 `R=-div(K grad u)-f=0` 得 `f=-11/60`。符号、系数和单位冻结正确。`K` 在 `[0,1]^3` 上对角元为正，因而该 manufactured control 的 SPD 前提也一致。

## Findings requiring minimal correction

1. **M1 closure/environment is asserted, not evidenced.** `decision.md` line 21 names “import closure, direct tests/probes, and environment identity”, while `manifest.json` freezes only the three dirty factory paths. No current M1 product/receipt was found under `UP2-01-PREPARATION`, and no exact imported source/probe/test/interpreter/module/version/hash set is bound. Per 20/21, this must remain a dependency/limitation, not an accepted fact. Add an explicit `m1_dependency` object with `status=review_pending` (or `not_present`), exact paths, raw/canonical hashes, interpreter/module/environment identities, and the re-entry condition; do not claim a frozen complete closure until that record is independently reviewed.
2. **External trust inputs are not itemized in the decision.** The decision says trust conditions may later become valid, but does not enumerate provider/owner, independent attestor basis, trust root/public-key chain, certificate/signature, verifier version, validity/revocation/trusted-time/anti-replay policy, source/version binding, G2 mapping, four axes, contact channel, and recovery condition. Add one explicit typed-absence/blocker table or manifest object with unknowns marked unknown and a wake-up condition tied to changed external material. This is required by 21 M2; it must not trigger repeated S3/AD creation when inputs are unchanged.
3. **Role wording is ambiguous.** The roles object separates `A_test_and_oracle` from `independent_reviewer`, but the future test path is described as “different test/review Luna”. Replace this with named, non-overlapping role slots/agent identities: A source implementer; A test/oracle owner; independent reviewer; integration/documentation owner; Sol acceptance. State that reviewer cannot be the implementer/test/oracle/integration owner for the reviewed change. This is a scope clarity fix, not permission to dispatch code now.
4. **Formal reentry omission.** Add the existing sequence `T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B (50 fresh receipts, checker, two-process replay) → UP1-04 → UP2-01`, while retaining all other gates and the unchanged 39-node DAG. The current wording names most gates but omits aggregate and the UP1-04 parent transition.
5. **Receipt index is incomplete.** `archive/final_json_parse.stdout.raw` and `archive/scope_git_status.stdout.raw` exist, but are not represented as command records in `archive/validation_receipt.json`; add receipt records or explicitly classify them as non-validation informational sidecars. Preserve all raw and failure sidecars.

## Positive/negative controls and stop rules

The listed A controls cover unknown operator, units, SPD/positivity, duplicate source owner, boundary/closure and foreign source. The stop classifications (`unknown_operator`, `unit_closure_failure`, `non_unique_source_owner`, `input_hash_changed`, `program_exception`) and deferred time/multifield rule are suitable. The implementation work order must additionally carry the independent Python `fractions` oracle, deterministic hash recipe, exact-term tolerance, and explicit “no production lowering” assertion before A dispatch.

## Claim ceiling and handoff

Until the above corrections and independent review are complete, the only admissible decision ceiling is `manufactured_control` / `screen_only`, with `accepted=false`, A not dispatched, B contingent, C/D not dispatched, and all formal parent gates open. This review itself is documentation evidence only.
