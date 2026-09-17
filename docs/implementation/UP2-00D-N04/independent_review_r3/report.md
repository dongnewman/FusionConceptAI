# Independent review r3: UP2-00D N04

Verdict: `pass_limited` for the actual-A, contract-only ledger-authority projection. The author archive remains `review_pending` / `accepted=false`. This review grants no cross-layer conservation proof, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.

## Runtime evidence

The independent pre-run snapshot (`focused_test_prerun.json`) recorded zero Julia and zero DESC processes. Exactly one focused command was run serially:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n04_ledger_authority.jl
```

The runner was Julia PID `51672`, started at `2026-09-14T08:49:58.1532975+08:00` and ended at `2026-09-14T08:51:15.1439387+08:00`, with exit `0`. The independent stdout is 2,474 bytes and reports `46/46` actual-A projection assertions plus `4/4` owner/classification assertions; stderr is zero bytes. `focused_test.exit.txt` records `0`, and `post_processes.json` is `[]`. The process record includes a correction note because the initial capture attempted to use PowerShell's read-only `$PID` variable; the recorded runner PID is the Julia PID observed in the pre-run process list, not the PowerShell host PID. No Julia or DESC process remains.

The author history remains separate and preserved: r1 exit `1` after 46/46 projection assertions, with the owner-gap archive assertion selecting the G1-to-G3 gap; r2 exit `0` but overlapped N03 and is admissible only as an overlap run; r3 exit `0` in a serial-only lane, with the author process log recording runner PID `12372`, 46/46 plus 4/4, and child-fixture Julia invocations.

## Source-backed A slice

`n04_projection_from_a` at `src/GenomeV5/UP2/N04LedgerAuthorityProjectionV1.jl:94-132` consumes a concrete `CandidateStatePackageV5`, checks structural validity, v5 candidate binding, actual G3 realization/control/network types, G3 candidate binding, and component hashes. It reads the actual G1 equation occurrences and the actual G3 resource network. The fixture source has 6 accounts, 7 entries, 4 closures, and 2 components (`test/GenomeV5/G3/fixtures.json:50-81`).

The five projected fields and locators are concrete values:

- N04-01: `/g3/realization/network/accounts/0/owner`, `G3LedgerAccountV2.owner::String`
- N04-02: `/g3/realization/network/closures/0/account_ids`, `G3LedgerClosureV2.account_ids::Tuple[String]`
- N04-03: `/g3/realization/network/entries/0/account_id`, `G3LedgerEntryV2.account_id::String`
- N04-04: `/g3/realization/network/entries/0/component_id`, `G3LedgerEntryV2.component_id::String`
- N04-05: `/g3/realization/network/entries/1/coefficient`, `G3LedgerEntryV2.coefficient::Rational{Int64}`

The four local structural mutations are source-derived: duplicate closure IDs, wrong entry account/port association, passive component used as a source, and capacity-exceeding non-effort coefficient. N04-01 changes an account to another existing owner and correctly remains `terminal_deferred`; the current contract permits multiple accounts with one owner. The implementation always retains `g1_occurrence_to_g3_account_exact_join_missing`, because no exact candidate-bound G1 occurrence to G3 account/energy-boundary authority exists. It does not relabel that missing join as invalid closure.

## Classification and evidence boundary

`_n04_mutate` at `:148-174` obtains mutation values from the actual network. `_n04_classify` at `:176-222` derives each result from the mutated typed value and actual accounts, ports, components, effects, and capacities. `n04_validate_mutation` at `:224-249` verifies field path, source locator, and source type, then returns the derived status/error/path and zero compile/provider/solver counters. The focused test checks each mutated hash differs from its input, original and mutated typed values differ, and the JSON expected class cannot override classification: the forged N04-02 spec with `expected_error=:terminal_deferred` still returns `:invalid_closure` (`n04_ledger_authority_tests.jl:109-116`).

## Limits

This is a narrow local ledger projection. The `g1_ref` field is weakly typed as `Any` in the projection struct, and the projection does not prove the missing cross-layer occurrence-to-account/energy join. The shared-owner result is a scope gap, not a uniqueness failure. The child fixture tests exercise existing G1/G2/G3 focused suites in separate Julia child processes; this does not prove independent geometry, provider, solver, or physical behavior. No B00/B04 or provider/mesh/engineering/physical/R01-R10 credit is claimed.

Only this independent review directory was written. The final recommendation is to retain the author archive as review-pending and accept only the bounded actual-A N04 schema/classification slice at the next integration gate.
