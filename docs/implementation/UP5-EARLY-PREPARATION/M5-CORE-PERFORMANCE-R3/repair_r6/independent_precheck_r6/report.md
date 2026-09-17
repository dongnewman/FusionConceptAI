# M5 core performance R3 repair R6 independent precheck

## Decision

**PASS for the R6 test-only cache-isolation repair.** The parent lane may run
the focused test once as a diagnostic, with the claim ceiling remaining
`screen_only`. This review does not establish performance, formal credit,
factorial closure, or fresh-process evidence.

## Scope and guardrails

- Review target: `repair_r6`, based on HEAD
  `cfc745939a02fd023854dd4e9bb6d04ccadf9ee`.
- Julia was not started and no commit was created.
- Only this report and its sibling `manifest.json` were written.
- Product sources, M4 adapter/probe, task manifests, and `runs/` were treated
  as protected. Existing dirty worktree state was preserved and is not
  attributed to R6.
- The factorial path remains explicitly unoptimized and outside this review.

## Static findings

1. The proposal-identity negative uses a fresh
   `_CEGDerivationCacheV1`, populates its identity entry, replaces the entry
   with a forged `_CEGMemberKeyV1`, and retains
   `@test_throws ArgumentError _ceg_cached_proposal_identity(...)`.

2. The proposal sort-key negative now uses a separate fresh
   `_CEGDerivationCacheV1`, populates the sort-key entry, replaces it with
   `"forged"`, and retains
   `@test_throws ArgumentError _ceg_cached_proposal_sort_key(...)`.
   Therefore the first intentional identity corruption cannot poison the
   sort-key setup; both negative-test semantics are unchanged.

3. The remaining deliberately polluted caches were scanned by variable and
   call site. `mutated_entry` is the only deliberate delete-and-reuse path:
   its foreign entry is rejected, then deleted, and the helper is expected to
   recompute the original bytes. `mutated_condition`, `mutated_rule`,
   `mutated_member`, `mutated_proposal_identity`, and
   `mutated_proposal_sort` are not reused as valid caches after corruption.
   The forced-digest, forged-rule, and forged-winner caches are likewise used
   only for their explicit rejection assertions. Valid trace/provenance and
   receipt paths continue to use the unpolluted `cache`.

4. The R6 failure receipt reports the upstream `18 passed, 0 failed, 1
   errored, 19 total` diagnostic and attributes the error to reusing the
   intentionally corrupted proposal-identity cache. Its referenced
   `repair_r5/diagnostic_julia_r3/run.json` exists. The R6 manifest carries the
   same reference and correctly keeps it as a failure receipt only.

5. A focused scan found no invalid `getfield(...) = ...`, colon-symbol
   assignment, or colon-arrow construction. No R6 product-source edit is
   present in the repair documentation. No runtime result was generated.

## Allowed next action

The parent lane may run this command **once**, diagnostically:

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

The result must remain diagnostic-only until its exit code and receipts are
reviewed. It must not be presented as closing cold/hot/query/replay/Dict,
mutation isolation, collision, two-process, performance, or factorial
requirements. Any two-process/fresh-process check remains a later
parent-owned follow-up.
