# G-I1A independent static precheck R4

Verdict: **changes_requested**.

This is an independent, read-only static review of the R4 frozen inputs. Julia/DESC were not started and no production, test, core, or prior-review file was changed. Only this new `independent_precheck_r4/` archive was written.

## Frozen hashes and QA

The four requested hashes match exactly: source `c01a27d6cb6a9b8ab688289f6fa012a98e3229fe20cdab8f1ad0f7edbb9e7141`, fixture `fb5c0c216ac9d98d9ebaba631aa6f2a1795b7d18d670018496858d604ffee44f`, test `61829c1175e5013840b684a49d4b0fddd01d2427039b4a418722fd49b2f30226`, runner `20d01f6ee0ceb7a7bf11c160a4257224ceee61c50ff229dca62303efa0658ff6`. JSON parsing, `validate_plan.py`, scoped `git diff --check`, static delimiter checks, and the Julia/DESC process sweep are recorded with real timestamps, exits, stdout/stderr and hashes in `command_receipts.json`; the sweep reported no Julia/DESC process.

## What is repaired

The source now has the R3 admission repair at `GI1AuthorityContextV1.jl:445-448`: `declared_consistent` requires E1 and E2 typed-present slots, `e2_admission === :declared_consistent`, and an empty merged gap set. Typed E2 terminal-deferred remains `terminal_deferred`. `_gi1_require_valid` and the E0/package/E1/N06 branches preserve `:program_exception` via `GI1ProgramException`; the trusted validator maps that exception class to `status=:program_exception` (`:507-511`). Actual-A E1-present/E2-absent and both-absent factory paths are source-bound, and the trusted validator rebuilds from package/E0/optional extension inputs.

## Blocking reachability gaps

1. **GI1A-R4-01:** the test only passes an intentionally invalid `bad_n06` and expects `ArgumentError` (`gi1_authority_context_tests.jl:199-204`). It never constructs a structurally valid source-bound typed E2 mapping that returns `:terminal_deferred`, never reaches `_gi1_make_n06_present`, and never asserts that overall admission remains `:terminal_deferred` for typed E2-present/deferred. The fixture has no typed E2-present/deferred case. The repaired predicate is therefore textually present but not dynamically covered.
2. **GI1A-R4-02:** the only direct exception test is `GI1ProgramException("taxonomy")` (`:155-159`). No test induces an upstream E0/package/E1/N06 `status=:program_exception`, no factory throw is asserted, and no trusted validator `status=:program_exception` is asserted. The source branches are present, but preservation through the real call paths is unverified.

Because Julia was deliberately not run, static delimiter balance does not establish Julia method dispatch for the newly repaired E2/program-exception branches; those paths remain a focused runtime gate after targeted test additions. The minimum repair is test/fixture-only: add a source-bound typed E2 mapping whose local joins are valid but whose N06 admission remains terminal-deferred, assert typed E2-present plus overall `terminal_deferred`; add narrow exception injection/fixture controls for each upstream source branch and assert the GI1 program-exception taxonomy through factory/trusted API. Do not fabricate a physical N06 positive.

## Boundary

This review does not grant implementation acceptance, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit. E1/E2 remain contract-only and the current A package has no physical N06 positive. Prior R1-R3 archives remain immutable.
