# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC independent agent-local R1 review

Date: 2026-09-17
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: `pass_with_findings` for the bounded typed-absent scaffold; `not accepted` for the machine node or any present binding.

## Scope and execution boundary

This review read `AGENTS.md`, the current agent-local policy, the shared
contract, the current work order and AD-33 history, then audited the current
source/test/fixture/static-QA files and the `agent_local_r1` receipts. The
review did not run Julia, DESC, a provider, mesh, solver, or package
regression. It wrote only this report and its manifest under the independent
review directory.

The current task-manifest boundary is still honest: `planned` / `proposal` /
`accepted=false` / `review_pending`, `claim_ceiling=contract_only`, with
`local_software_scaffold_status=accepted_limited`, `present_authority=false`,
and all actual/T0/T1/T2/provider/mesh/solver/engineering/physical/search and
R01-R10 credits false.

## Evidence checked

- Fresh review-time command
  `python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py`
  exited 0 and printed `check_count=38`, `passed=38`.
- The worker's retained raw focused Julia output is 235 bytes with SHA-256
  `7549c44579077daa3f2dfe44caa49b327fd8cea98443a699e089a4cc49fd8627`
  and prints `52/52`, `typed_absent_scaffold_pass`,
  `PRESENT_AUTHORITY=false`, and `PHYSICAL_CREDIT=false`. This is receipt
  verification only; Julia was not rerun by this reviewer.
- Current PBB source/test/fixture/static-QA bytes match the worker manifest:
  source `26420` / `feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`,
  test `6430` / `6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`,
  fixture `781` / `59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`,
  static QA `3703` /
  `81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`.
- The worker's retained input audit is not wholly current: its G1
  `DiffusionDeclarationV1.jl` row records `31743` bytes and
  `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`,
  while the current working tree is `32694` bytes and
  `88af0f23379db7c2479e8f0b18523875260c37d7660a26b80568b625aa0533e8`.
  The other four V1 dependency hashes checked from the worker record match
  the current tree. This drift prevents the worker's present-authority audit
  from being treated as a current frozen input receipt.

## What passes within the bounded scope

The absent branch is genuinely typed: `AbsentParentBaselineBindingV1` has no
actual parent ref, declaration/baseline hashes, locator, factory receipt, or
present-binding placeholder; `AbsentChildKeyV1` likewise has no actual parent
fields. G1 and G2 construct layer-specific absence domains and
`contract_admission=:terminal_deferred`. The source does not enter the shared
package, registry, T0/T1/T2, provider, mesh, solver, or physical paths.

The state path keeps canonical bytes, a domain-separated state hash, source
absence hash, and empty digest-only history. `replace_source_payload` on the
typed-absent state returns a rejected `baseline_authority_absent` receipt
without publication or history advancement, and the focused receipt records
the expected prior bytes/SHA/state/history preservation. Fixture, ref-only,
synthetic, and explicit foreign mode attempts are rejected. The current
`prepare_only_typed_absent` ceiling is therefore honest and must remain the
only conclusion from this round.

## Findings requiring repair before a present or stronger acceptance

1. **P1 — stale dependency freeze.** The G1 declaration input hash in
   `agent_local_r1/evidence_manifest.json` and `report.md` no longer matches
   the current working tree. Refresh the exact G1 source-byte/locator/factory
   receipt audit after the repair lane settles; do not reuse the old present
   authority conclusion as a current receipt. This does not make the current
   typed-absent result dishonest, because the current G1/G2 factory code still
   emits `trusted=false`, `candidate_identity_created=false`, and
   `final_hash_created=false`/`final_candidate_or_package_hash_created=false`
   (G1 factory lines 489-495; G2 factory lines 441-446).

2. **P1 — stale/tamper inputs are not validated.**
   `ReplaceSourcePayloadInputV1` carries `expected_prior_state_hash` and
   `expected_prior_source_content_hash`, but `replace_source_payload` only
   checks child-key equality and `terminal_deferred` before returning
   `baseline_authority_absent` (source lines 518-523). The focused test uses
   only matching expected hashes (test lines 100-115); it has no stale-state,
   stale-source, canonical-byte tamper, state-hash tamper, or source-digest
   tamper cases. Add explicit fail-closed checks and tests for each mismatch,
   with unchanged prior bytes, SHA, state hash, source hash, and history.
   Keep the error taxonomy closed and distinguish source/state stale causes if
   the contract requires separate classification.

3. **P1 — present seam is not source-backed binding yet.** Both overloads of
   `admit_present_parent(request, receipt)` unconditionally throw
   `source_backed_receipt_unavailable` (source lines 500-508). The nominal
   `SourceBackedV1DeclarationReceiptV1` and
   `PresentParentBaselineBindingV1` constructors only check three receipt
   flags; they do not prove actual source bytes against the locator, bind
   locator/factory/declaration fields to the actual parent, enforce the G1
   candidate/public-contract relation, or compare actual and requested
   candidate identity (source lines 173-225). This is acceptable only because
   present authority is explicitly unavailable. Before present admission,
   provide one source-backed adapter from the real G1/G2 factory outputs and
   add wrong module/factory, raw-byte, semantic-body, declaration-hash,
   candidate, layer, stale, and parent-binding-hash fail-closed controls.

4. **P2 — negative-control coverage is overstated.** The worker report says
   foreign candidate/layer/child and tamper-derived absence/state controls are
   covered. The current focused test exercises one G2 public-contract
   mismatch, mode-symbol rejection, one reason digest inequality, and one
   absent replacement atomicity case; it does not exercise wrong layer/child,
   wrong domain, state tamper, or any present-input control. The static QA is
   token/static inventory only. Narrow the report claim now and add the
   missing behavioral matrix when the source-backed path is available.

5. **P2 — the conceptual unions are open Julia supertypes.**
   `AbstractParentBaselineBindingV1` and `AbstractChildKeyV1` are abstract
   supertypes rather than explicit closed `Union{Present,Absent}` aliases.
   `EditStateV1` accepts any future subtype. If the frozen contract requires
   closed unions, define/enforce the exact two-branch aliases (or a validator
   that rejects all other subtypes) and test the rejection; do not interpret
   the current subtype names alone as a closed union proof.

## Decision

`pass_with_findings` is appropriate only for the local typed-absent software
slice: the 38/38 static result, retained 52/52 focused receipt, absence
shape, and failure-atomic absent operation support that limited conclusion.
The machine node remains `accepted=false` and `review_pending`. No present
G1/G2 parent/child, source publication, same-candidate identity, T0/T1/T2,
UP2, provider, mesh, engineering, physical, search, B00/B04, or R01-R10
credit is granted. A fresh re-hash and the P1 controls above are required
before a stronger review or any present admission.
