# UP3 CompositionMatcherContractV1 independent review R3

Date: 2026-09-17 (Asia/Shanghai)
Reviewer: different Luna/high, read-only static review
Scope: current R3 matcher source, isolated contract test, fixture and static
QA. Julia/DESC were not run. No product or test file was modified and no
commit was made.

## Verdict

**GO for the next isolated Julia gate (static-only).** The R2 hard blocker is
closed in the current snapshot: `_cmc_failure_key` is defined before its use
in `_cmc_plan_body`, and the same canonicalization is used by both normal and
typed error-plan construction. The source has a deterministic failure sort
key, diagnostic-label erasure for `input.<label>`/`port.<label>`, and retains
typed component/signature paths. The isolated include and the R2 helper,
permutation, fail-closed and deferred assertions remain present.

This is **not** runtime acceptance. `accepted=false`, `formal_acceptance=false`,
and the status/claim ceiling remains `contract_only/prepared`: no Julia test,
cold replay, provider, solver, numerical, physical, engineering or R01-R10
credit is claimed.

## Static evidence

### Failure identity and ordering

- `src/RuntimeV4/CompositionMatcherContractV1.jl:267-280` defines
  `_cmc_failure_path_key`, `_cmc_failure_key` and
  `_cmc_failure_sort_key` before the canonical failure tuple is consumed at
  line 290.
- `input.left` and `input.right`/`port.<label>` are normalized to their
  typed path class; `component:<typed-ref>:...`, signature hashes and other
  non-display paths are retained. Thus label erasure does not erase typed
  component identity.
- `_cmc_plan_body` sorts failures with `_cmc_failure_sort_key` and stores the
  normalized `(code, path, detail)` tuple. The plan hash is derived from this
  canonical body.
- The test source retains repeated-key stability, label erasure, and
  distinction checks at lines 81-90, including component-path distinction and
  code/detail distinction.

### Sealed/isolated and deterministic composition boundary

- The test wraps the product include in
  `module CompositionMatcherIsolatedV1` and assigns `const M` to that module
  (test lines 11-16). No shared registry or package entry was changed.
- Port identity excludes display `port_id`; input/output tuples are sorted by
  canonical port hash; components are sorted by typed `component_ref`; the
  normalized edge contains typed component identity and port semantic keys.
- Renamed port labels, component/input order and a two-input permutation remain
  asserted in the R2 test body. The fixture remains a contract-only fixture,
  not an authority source.

### Reachability and R2 coverage retained

- The valid route is `match_composition_contract` → `_cmc_make_plan` →
  `_cmc_plan_body` (source lines 319, 372 and 301).
- The non-iterable/mixed-invalid route is `_cmc_error_plan` → `_cmc_make_plan`
  → `_cmc_plan_body` (source lines 309-312 and 321); it returns a typed
  `:fail_closed` plan rather than throwing at match time.
- The R2 matrix remains in the test source: positive composition and hash
  invariance, two-input permutation, bad space, ambiguity, cycle, unclosed
  ledger, duplicate component, mixed/`nothing` invalid input, provider
  dropout and `typed_absent` deferred paths, zero provider/solver counts, and
  validator drift detection.
- The permitted static command completed successfully:

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
PASS static_qa_composition_matcher_contract_v1_r3
```

## Open evidence boundary

The static QA checks source tokens, ordering and fixture shape; it does not
execute Julia. The nine fixture negative names therefore are not evidence
that nine cases ran, and there is no fresh-process/cold-replay receipt,
stdout/stderr, exit code, or independently compared plan hash in this review.
The testset name and static-QA docstring still say `R2`; this is stale
metadata, not a demonstrated R3 semantic defect, but should be corrected with
the next product/test touch.

The next gate is one parent-authorized isolated Julia execution followed by a
separate cold replay. It must demonstrate valid and error-plan construction,
label/permutation hash invariance, structural `:fail_closed` versus provider
or authority `:terminal_deferred`, validator rejection, zero provider/solver
invocations, and deterministic hashes/status/edges/topology/ledger.

## Current product hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 20619 | `0bada45b2825e14e242db98af1f9b69ee3489c685224ea73f3920eb7a4f9021d` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 8932 | `3b1482a467b5062bffe6a816d7bca4474124b9406c0d5bda67ddeae2502f01f2` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 4425 | `4c89362b3b0f76df37a3dab65d6dc5461da6a9e7168985e65b9559a391122ffa` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |

## Review boundary

Only this `independent_r3/` archive was added. Existing R1/R2 archives,
unrelated dirty files, product source, tests and fixtures were not edited.
