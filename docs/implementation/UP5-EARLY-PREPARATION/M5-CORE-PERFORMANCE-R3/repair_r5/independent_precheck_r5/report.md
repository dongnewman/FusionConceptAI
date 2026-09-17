# M5 core performance R3 repair R5 independent precheck

## Decision

**PASS for the R5 test-only syntax repair.** The repair is eligible for one
parent-owned diagnostic focused Julia run, with the claim ceiling remaining
`screen_only`. This is not an acceptance, performance, formal-credit, or
factorial result.

## Scope and guardrails

- Review target: `repair_r5`, based on HEAD
  `cfc745939a02fd023854dd4e9bb6d04ccadf9ee`.
- Julia was not started. No commit was created.
- This review wrote only this report and its sibling `manifest.json`.
- Product sources, M4 adapter/probe files, task manifests, and `runs/` were
  treated as protected. Existing dirty worktree state was preserved; this
  review does not attribute those pre-existing changes to R5.
- The factorial path remains explicitly unoptimized and outside this review.

## Static findings

1. Focused-test line 137 now reads:

   ```julia
   @test_throws Exception setfield!(cached_trace, :owner_token, Ref{Nothing}())
   ```

   `setfield!` is the valid Julia mutation syntax for this negative case. The
   target is the immutable `ConditionalRewriteTraceStepV1`; the enclosing
   `@test_throws Exception` therefore preserves the intended immutable-owner
   mutation failure rather than weakening it.

2. The other immutable-cache negatives at lines 73--74 remain ordinary dot
   assignments inside `@test_throws Exception`. They are syntactically valid
   Julia and retain their intended runtime throws. No additional invalid
   `getfield(...) = ...` assignment was found.

3. A focused scan for bare colon-symbol assignment forms (`:symbol =` or
   `:symbol =>`) in the test found no additional illegal construction. The
   existing `getfield(query, :status) == ...` comparison is not an assignment.

4. The R5 failure receipt and evidence manifest both identify the upstream R4
   parse diagnostic. The referenced
   `repair_r4/diagnostic_julia_r2/run.json` exists, and its role is correctly
   limited to a failure receipt rather than runtime credit.

5. `git diff --check` is clean for the R5 review artifacts and focused test.
   No Julia output, benchmark, cache claim, or fresh-process claim is supplied
   by this screen-only review.

## Allowed next action

The parent lane may run this command **once**, diagnostically:

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

The run must remain diagnostic-only until its exit code and receipts are
reviewed. It must not be presented as closing cold/hot/query/replay/Dict,
mutation isolation, cache collision, two-process, performance, or factorial
requirements. A two-process/fresh-process check remains a later parent-owned
follow-up.
