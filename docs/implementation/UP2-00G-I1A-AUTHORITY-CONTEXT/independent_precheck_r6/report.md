# G-I1A R6 independent static precheck

Verdict: `ready_for_serial_focused`; `status=review_pending`; `accepted=false`.

This different-Luna review is read-only. It did not run Julia or DESC and did not modify source, tests, core documents, or prior evidence. The result only clears a new serial focused run for the R6 test-only repair; it grants no B00/B04, provider, mesh, engineering, physical, UP2-total, or R01–R10 credit.

## Frozen repair and prior failure

The preserved `focused_r1/process_r2.json` is a real exit-1 receipt. Its stdout contains G1 `47/47` and `21/21`, then the G-I1A test errors at `gi1_authority_context_tests.jl:22` with `UndefVarError: G1GenomeContractRef not defined`; stderr is 314 bytes. The repair note and raw stdout/stderr remain immutable. The first capture attempt is separately marked unknown because its PowerShell wrapper failed while assigning the read-only `$PID` variable; it is not used as a pass.

R6 changes only the test constructor token. `gi1_authority_context_tests.jl:22` now calls `G.G1GenomeContractRefV2`, whose real constructor is defined in `src/GenomeV5/G1/GrammarProfileV2.jl:50-104` and whose V2 argument shape matches the existing call. A scan of the owned UP2 test and runner found zero stale `G1GenomeContractRef` tokens. The source, fixture, runner, and R5 production context bytes are unchanged.

## Coverage retained

The R5 shared-admission coverage remains in the current test: `:166-180` constructs a typed candidate-bound E2 mapping/slot and exercises `_gi1_overall_admission` for deferred-with-gap and consistent-without-gap. The trusted N05 program-exception path remains at `:182-191`; structural stale/invalid controls remain at `:228-233` and `:267-272`. Actual-A E1-present/E2-absent assertions still require `contract_admission=terminal_deferred`, `physical_resolution=terminal_deferred`, and zero counters at `:110-148`. No source-backed E2 physical authority is introduced.

Static method review found no new syntax or ownership blocker. Runtime dispatch and the corrected constructor binding remain unverified until the next serialized run.

## Frozen hashes and QA

- source: `D84DB10E6332E5F0919F2E4D1F8BA1B910DC3C39D74CFBC7869E579FF5718FD9`
- fixture: `C66A4F1CDECFB1CDA62EF8B0FE8F20853D7D248E489F4ADF5A9B0D7AAB01942C`
- repaired test: `83D765EC5A7FF5867F5E80D1BF4CE2DF2CAB21F55E82D63E4BA579C219A8B1AF`
- runner: `20D01F6EE0CEB7A7BF11C160A4257224CEEE61C50FF229DCA62303EFA0658FF6`

JSON parsing, control scan, `validate_plan.py`, and `git diff --check` pass in the R6 repair archive. The precheck process sweep found zero Julia and zero DESC processes.

