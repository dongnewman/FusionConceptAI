# G-I1A R5 independent static precheck

Verdict: `ready_for_serial_focused`; `status=review_pending`; `accepted=false`.

This is a different-Luna, read-only static precheck of the author's R5 source, fixture, test, and runner. No Julia or DESC process was started. The result only opens the next serial focused-runtime gate; it grants no implementation, UP2-total, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit.

## Checks that are closed statically

The production factory calls `_gi1_overall_admission` at `GI1AuthorityContextV1.jl:440-492`, after source-validating the actual package/E0 and optional N05, constructing the E2 slot through `_gi1_e2_slot`, and merging the E0/E1/E2 gaps. The helper at `:62-85` is therefore the shared admission path. It keeps a typed E2-present slot with `e2_admission=:terminal_deferred` at `terminal_deferred`; it returns `declared_consistent` only when both slots are present, both admissions are consistent, and the merged gaps/errors are empty.

The R5 test reaches that shared helper dynamically in its schema-only boundary test: `gi1_authority_context_tests.jl:166-180` constructs a candidate/E0-bound typed `N06SourceFieldLedgerMappingV1`, wraps it as `GI1N06PresentAuthoritySlotV1`, and checks both the deferred-with-gap and consistent-without-gap outcomes. This is deliberately a schema/admission exercise; it is not a claim that current A has a valid dimensioned N06 law. The actual-A path remains E1-present/E2-absent at `:110-148` and explicitly asserts `contract_admission=terminal_deferred`, `physical_resolution=terminal_deferred`, and all downstream counters zero.

The program-exception control reaches the trusted validator and its real factory/N05 upstream path. At `gi1_authority_context_tests.jl:182-191`, an actual N05 authority is rebuilt with `resolution=:program_exception`, then passed to `gi1_validate_authority_context`. The trusted overload rebuilds through `gi1_authority_context_from_a` (`GI1AuthorityContextV1.jl:512-535`), which invokes `up2n05_validate` (`:456-463`); the resulting `GI1ProgramException` is returned as `status=:program_exception` with zero counters. Known structural contradictions remain separate: the stale N05 package-hash control at test `:267-272` and invalid E2 mapping control at `:228-233` expect `ArgumentError`, while `_gi1_require_valid` maps a normal upstream `fail_closed` result to `ArgumentError` and only non-argument failures become `GI1ProgramException`.

The fixture is loaded into `_GI1_FIXTURE` and its case IDs are checked as test oracles. It does not supply authority or route the factory. AD-26 remains consistent with the implementation: extensions are additive and content-hashed, `contract_admission` is separate from `physical_resolution`, and current A has no physical E2 authority.

## Remaining boundary

Static inspection cannot prove Julia parsing, method dispatch, or the runtime counts. The focused runner must execute once in the serialized lane and preserve real PID, exit, stdout/stderr, and post-process evidence. That run must include the R5 schema-only E2 branch, the trusted N05 program-exception path, and the structural fail-closed controls. A successful focused run still remains `review_pending` until a different Luna reviews it; no B04 or physical gate is opened.

## Frozen inputs

- `src/GenomeV5/UP2/GI1AuthorityContextV1.jl` — 29560 bytes, SHA256 `D84DB10E6332E5F0919F2E4D1F8BA1B910DC3C39D74CFBC7869E579FF5718FD9`
- `test/GenomeV5/UP2/gi1_authority_context_fixtures.json` — 1608 bytes, SHA256 `C66A4F1CDECFB1CDA62EF8B0FE8F20853D7D248E489F4ADF5A9B0D7AAB01942C`
- `test/GenomeV5/UP2/gi1_authority_context_tests.jl` — 19198 bytes, SHA256 `1A4737ACF6A7457B95F5B33B689AAF97866F5F7946BAABB0116200D9FB7472D6`
- `test/GenomeV5/UP2/run_gi1_authority_context.jl` — 279 bytes, SHA256 `20D01F6EE0CEB7A7BF11C160A4257224CEEE61C50FF229DCA62303EFA0658FF6`


## Static QA limitation

The final `python docs/v4_multitopology_generation/validate_plan.py` invocation returned exit 1 because the concurrently changing `16_execution_work_orders.md` contains a missing link to `../implementation/AD-27/decision.md`. This review did not own or modify that core file. JSON parsing, control-character scan, and `git diff --check` passed; the validator failure is preserved in `command_receipts.json` and does not alter the G-I1A static readiness finding.
