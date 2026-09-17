# UP1 R3 root-decision draft

`decision_status: decision_draft_pending_root_review`

This is an unsigned decision draft for root review. It is not a root
signature, an authority receipt, a publication approval, or a parent-goal
closure record.

## Proposed disposition

**`fail_limited`**.

The only credit proposed by this draft is an offline, local,
non-authoritative software/prototype capability increment. R3 demonstrates a
bounded vector-harness and fail-closed software boundary; it does not
demonstrate external response, physical or engineering evidence, formal
credit, authority, or publication readiness.

The disposition is intentionally conservative and remains below UP1 closure.
The parent objective remains open. This draft does not modify the 39-node DAG,
R01-R10 state, any source or test file, or the AD registry.

## Evidence admitted at the limited software ceiling

- The R3 vector harness ran serially twice with exit `0`, reporting `24 tests`
  and one host-capability-limited skip on each run.
- The submitted vector receipt contains 26 unique vector IDs, paths, input
  hashes, and required result fields; independent replay matched the receipt
  rows exactly.
- Fail-closed/result-boundary probes retained typed rejection/defer behavior,
  `formal_credit=none`, `authority_credit=false`, and `no_publish=true`.
- This is an offline local observation only. No network, external send,
  AD/S3, Julia/DESC/solver lane, credential, or production mutation was used.

These observations are software evidence only. A passing local test is not a
claim about an external owner, a real authority chain, a physical device, or
the parent goal.

## Blocking facts that remain in force

1. **External blocker: 26/26 absent.** The R3 scan found
   `usable_external_inputs=0` and `typed_absent=26/26`. No owner, endpoint,
   authenticated channel, authoritative source, or candidate was admitted.
   The absence state remains `typed_absent -> terminal_deferred ->
   no_publish`; no new AD and no S3 rerun occurred.
2. **Production semantic coverage remains incomplete (P1-01).** The claimed
   production-predicate path is not established for `R02-R07`, `R24`, `R25`,
   and `D01`. Those rows use local/manual branches and/or `_result` without
   proving that the mutated wire field reached its owning production
   predicate. The 26/26 receipt therefore cannot be promoted to semantic
   closure.
3. **R22 remains a wire-mutation limitation (P2-01).** R22 calls
   `_check_ehp04`, but reconstructs a separate clean deferred fixture instead
   of replaying the submitted mutated wire envelope. It is limited evidence
   for the `not_executed -> terminal_deferred` boundary, not direct wire
   mutation coverage.
4. **Windows symlink/reparse coverage is deferred.** One focused-test case
   remains skipped because the host lacks the privilege needed to create the
   link/reparse fixture. This is `test_scope_deferred`, not a demonstrated
   Windows behavior pass.
5. **No authority or publication lane exists.** Keep
   `formal_credit=none`, `authority_credit=false`, and `no_publish=true`.
   There is no basis for a T0/T1/T2, UP1, B00/B04, engineering, physical,
   external, or publication claim.

## Gates required before any stronger disposition

The following gates are cumulative; none is waived by this draft.

| Gate | Required closure evidence | Current state |
|---|---|---|
| `G-EXT-26` | Real external owner/channel response for all 26 absence IDs, with authenticated receipts and independent review | `blocked`: 26/26 `typed_absent` |
| `G-SEM-PROD` | Schema-valid baseline or equivalent production-owned harness such that `R02-R07`, `R24`, `R25`, and `D01` reach their owning predicates and decision layer | `open`: P1-01 |
| `G-R22-WIRE` | Replay the original R22 mutated wire envelope through `_check_ehp04` and the production result layer | `open`: P2-01 |
| `G-WIN-LINK` | Execute the symlink/reparse fixture with required host privilege, or retain a separately authorized equivalent; record result without converting the skip to pass | `deferred`: `test_scope_deferred` |
| `G-EXT-AUTH` | Real trust/authority/owner evidence, authenticated time/replay/channel receipts, and independent reviewer separation | `blocked`: no authority material |
| `G-PUBLISH` | Explicit accepted-all executed fixture plus the applicable publication/authority policy receipt | `blocked`: `no_publish=true` |
| `G-PARENT` | Root-level review and an explicit parent-goal decision | `not attempted`: parent remains open |

The first five gates are evidence gates, not implementation promises. A
future repair must preserve the fail-closed boundary and re-run independent
review against frozen inputs.

## Non-actions and preservation constraints

- Do not close the parent objective from this package.
- Do not mutate the 39-node DAG or R01-R10.
- Do not create a new AD, authority record, external candidate, or publication
  receipt.
- Do not reinterpret `prototype_pass_limited`, local `accepted`-shaped
  results, or `terminal_deferred` as external acceptance.
- Do not change production code or tests as part of this decision draft.

## Root review record

| Field | Value |
|---|---|
| `decision_status` | `decision_draft_pending_root_review` |
| `proposed_verdict` | `fail_limited` |
| `root_reviewer` | `pending` |
| `root_signature` | `absent` |
| `reviewed_utc` | `2026-09-17` (draft date only; no root approval implied) |

Root must either accept this disposition with an actual signed/owned review
record or replace it with a new, explicitly scoped decision. This directory
contains no root signature.
