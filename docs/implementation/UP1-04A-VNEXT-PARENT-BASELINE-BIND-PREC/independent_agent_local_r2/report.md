# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC independent local-adapter R2 review

Date: 2026-09-17
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: `NO-GO` for the focused Julia command; `prepare_only_runtime_input_adapter` remains honest and `accepted=false`.

## Scope and execution boundary

This review inspected the new standalone
`VNextParentBaselineBindingLocalV1.jl`, its local test/fixture/static-QA
files, the `agent_local_r2` raw receipts, the old R1 four-file hashes, and the
current task boundary. It did not run Julia, DESC, provider, mesh, solver, or
full regression, and it changed no product file. Only this independent review
directory is writable.

The adapter remains additive and is not included by `src/FusionConceptAI.jl`.
It contains no frozen upstream 64-hex hash literals, and the old R1 product
files remain byte/hash unchanged. The intended claim ceiling is still
contract-only: no present runtime input in this round is a current G1/G2
authority receipt, and no T0/T1/T2, UP2, physical, engineering, search or
R01-R10 credit is granted.

## Evidence checked

- Fresh review-time static command
  `python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`
  exited 0 with `check_count=78`, `passed=78`.
- The worker receipt is internally consistent at the process level:
  process stdout 552 bytes / SHA-256
  `6e723db2fa75329b4f1b5bfbd245102bbfe939f4e24f9c7b66ab51405b08042b`,
  stderr 0 bytes / SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The retained stdout file is a 538-byte representation with its separately
  recorded SHA, so the two receipt forms are not conflated.
- Current R2 product hashes match `agent_local_r2/evidence_manifest.json`:
  adapter `31275` /
  `55d2f60242af013b9b8f2ebb9874019f5d87906a01d0dd28fa03f1294fda2b98`,
  test `10193` /
  `85c14a10cf89805806a7c1d11551a32012a61fb357ffbc910121af9fce4d1753`,
  fixture `1385` /
  `61a169d8456c3d3437d62b1f633dcd25c7c43ffdec5cd094f26ed954689c51c3`,
  static QA `5627` /
  `b88c4e842ab0e9af234a567b6a277d56df0e378120646f156e7c5186cc35cc61`.
- The old R1 source/test/fixture/static-QA hashes match the preserved values in
  the R2 manifest. No old R1 product file was modified.

## What is structurally good

The source declares explicit `Union{PresentLocalParentBaselineBindingV1,
AbsentLocalParentBaselineBindingV1}` and corresponding bundle union. The
present record retains source/declaration/semantic bytes, recomputed hashes,
locator, factory receipt bytes/hash, candidate, layer/child, four axes,
source/declaration refs and parent-binding hash. The binder recomputes source,
declaration, semantic and receipt hashes, checks locator size/hash, exact
candidate equality, layer/child and axes/ref joins, and rejects contradictory
inputs with `fail_closed`.

Runtime receipt status `:unavailable` or an unreviewed candidate is mapped to
`typed_absent` / `terminal_deferred` without fabricating a parent hash or
receipt. The CAS path checks expected source/state hashes before state
validation, rejects stale/tampered payloads atomically, and explicitly forbids
absent-to-present promotion. No old upstream hash is hard-coded into the
adapter or fixture.

## Blocking findings

1. **P1 — missing records/children are misclassified, so the focused test
   cannot pass.** `bind_local_parent_baseline_v1` first calls
   `_vnl_record_layer_errors` and `_vnl_child_errors`, then returns
   `:fail_closed` whenever `errors` is non-empty (source lines 468-474).
   An empty record tuple therefore receives `:missing_layer` and returns
   `fail_closed`, while the focused test explicitly expects the empty-record
   case to return `:typed_absent` / `:terminal_deferred` (test lines 46-55).
   Missing children similarly generate `:missing_layer` and are rejected
   before `_vnl_absent_bundle` can run. Repair the classification ordering:
   pure missing declaration/child material must produce typed absence; only
   contradictions (duplicate/unknown/foreign/mismatched material) may produce
   `fail_closed`. Add one-record-missing and no-child tests. Until this is
   repaired, the focused Julia gate is `NO-GO` even though static QA is green.

2. **P1 — history is not included in state integrity.**
   `verify_local_state_v1` checks canonical bytes, canonical SHA, bundle/source
   hashes and present/absent binding, but never validates `state.history`
   (source lines 545-555). A caller can construct a state with arbitrary
   digest-only history while all checked fields remain unchanged; the state
   verifies and the CAS path appends to the forged history. The state bytes and
   state hash also omit history (lines 522-534). Include a canonical bounded
   history/chain commitment in the state identity or validate an explicit
   initial/previous-operation chain, then add a tampered-history failure-
   atomicity test.

3. **P1 — candidate identity review is an unbound caller boolean.**
   `LocalFactoryReceiptV1` accepts `candidate_identity_reviewed::Bool` and the
   binder treats `true` as the fresh-review gate (lines 126-150 and 308-312).
   The focused fixture/test simply sets that bit to `true`; no typed review
   receipt, review bytes/hash, reviewer-input binding, or freshness/lineage is
   checked. This allows synthetic runtime records to become `:present` merely
   by asserting the flag. Replace the boolean with a closed local review
   record (or explicitly keep this gate typed-absent until such a record is
   supplied), binding it to candidate, layer, source/declaration refs and all
   four axes.

4. **P2 — public present verifier omits two joins enforced only by the binder.**
   `verify_present_local_binding_v1` checks receipt candidate/layer/refs and
   byte hashes, but does not check `factory_receipt.factory_identity ==
   source_locator.factory_identity` or `factory_receipt.axes == x.axes`
   (source lines 399-427). The binder checks these before construction, but a
   directly constructed/tampered present record can pass the exported verifier
   if those fields are changed without changing the parent hash input. Put the
   same locator/factory/axes checks in the verifier and add direct tamper tests.

5. **P2 — report wording should separate synthetic contract tests from actual
   authority.** The R2 test constructs strings such as `actual source bytes
   g1` and a caller-provided runtime receipt; it is useful contract coverage,
   but not evidence that current G1/G2 declaration files or factory outputs
   were captured. Keep `prepare_only_runtime_input_adapter`,
   `present_authority=false`, and `accepted=false` until actual runtime
   records and an independently bound review are supplied.

## Decision and focused-Julia gate

The adapter has the intended additive shape, explicit Present/Absent unions,
runtime byte/hash/locator/ref checks, no hard-coded upstream hash, stale/state
CAS checks, and absent-promotion prohibition. Nevertheless, the deterministic
empty-record expectation conflicts with the implementation and history/review
authority checks are incomplete. Therefore focused Julia execution is
`NO-GO` until findings 1-3 are repaired and the test/receipt is refreshed.

After repair, the allowed conclusion remains prepare-only and contract-only:
`accepted=false`, no present upstream authority inferred, and all provider,
mesh, solver, engineering, physical, search, B00/B04 and R01-R10 credits
remain false.
