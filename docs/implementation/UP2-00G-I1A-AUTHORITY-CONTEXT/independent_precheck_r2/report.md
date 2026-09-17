# G-I1A independent static precheck R2

Verdict: **changes_requested**. This is a read-only different-Luna static review. No Julia/DESC was run and no source, test, fixture, core document or prior archive was modified. Frozen hashes are in `input_hashes.json`; R1 history remains untouched.

## Blocking findings

### GI1A-R2-P0: the context constructor rejects both structural status branches

`src/GenomeV5/UP2/GI1AuthorityContextV1.jl:276-279` contains two unconditional checks:

```julia
package_structural_status == :valid && isempty(errors) || throw(...)
package_structural_status == :fail_closed && !isempty(errors) || throw(...)
```

For a valid package with empty errors, the first check passes but the second `false || throw` executes. For a fail-closed package with errors, the first check throws. Thus every `GI1AuthorityContextV1(...)` construction fails before focused execution. This is a program-construction blocker, not evidence of a valid/fail-closed taxonomy. The checks must be expressed as one mutually exclusive conditional or equivalent.

### GI1A-R2-P0: typed N06 present content is discarded when admission is terminal_deferred

`N06SourceFieldLedgerMappingV1` can be explicitly supplied to `gi1_authority_context_from_a`. `n06_mapping_admission(package,e0,mapping)` first validates the actual A/E0 source, mapping identity and hashes, then returns `status=:terminal_deferred` with the mapping and the explicit error `n06_source_field_return_heat_semantics_unverified` when the authored dimensioned law is still unavailable (`N06SourceFieldLedgerMappingV1.jl:854-890`). That is a typed present declaration with an authority gap.

`GI1AuthorityContextV1.jl:354-369` instead converts every such terminal-deferred present mapping into `_gi1_make_absent(:E2, ...)`. The resulting E2 slot has no `mapping`, its body/content hash omits the supplied mapping, and the context hash is therefore unchanged when the present mapping content changes. This violates AD-26: an explicit present extension must retain its typed content and its independent content/schema/canonical/compatibility hashes even when `contract_admission` is `terminal_deferred`. Only `n06 === nothing` may create an absent marker.

The factory also computes `admission` at lines 398-399 solely from slot classes. A present N06 mapping collapsed to an absent slot can therefore silently turn a present/deferred declaration into a generic absence and lose the admission reason. A repaired path must preserve a typed N06 present slot, set `contract_admission=:terminal_deferred` for the missing law, include the mapping/content hash and errors in the context identity, and keep a truly absent E2 marker only for `n06 === nothing`.

### GI1A-R2-P1: program_exception is still collapsed at factory boundaries

The trusted schema validator has a separate non-`ArgumentError` → `program_exception` branch (`GI1AuthorityContextV1.jl:422-436`), and the trusted source validator accepts actual package/E0/N05/N06 arguments (`:440-463`). However, the factory does not preserve statuses from its dependencies:

- E0 `program_exception` is converted to `ArgumentError("GI1 E0 source fail_closed...")` at lines 377-386.
- E1 `program_exception` is converted to `ArgumentError("GI1 E1 source fail_closed...")` at lines 387-390.
- N06 admission `program_exception` falls through `_gi1_e2_slot` to `ArgumentError("GI1 N06 source admission is ...")` at lines 361-370.

The resulting context cannot distinguish an unexpected implementation exception from a known source contradiction. The repaired factory must propagate a typed `program_exception` context/result or preserve the original exception, while known typed contradictions remain `fail_closed`.

## Requirements that are now statically present

- Top-level context version, schema hash, canonicalization hash and compatibility-profile hash are explicit fields and participate in `_gi1_context_body` and `context_hash` (`GI1AuthorityContextV1.jl:208-235,289-304,306-324`).
- Both E1 and E2 have typed present/absent slot types, explicit content hash, schema/canonical/profile/compatibility metadata and candidate/package/E0 provenance (`:42-109,137-177`). E2 present is defined, but the factory path above does not preserve it under terminal deferred admission.
- Slot positions are checked against E1/E2 in `_gi1_check_slot` (`:180-204`); the R1 generic-slot concern is not the current primary blocker.
- `contract_admission` permits `declared_consistent`, `fail_closed`, `terminal_deferred`, and `program_exception`; `physical_resolution` remains independently forced to `terminal_deferred` (`:268-273`).
- `gi1_validate_authority_context(context, package, e0; n05, n06)` rebuilds through the actual A/E0/N05/N06 factory and compares context hash and both slot semantic views (`:440-463`), so it is a trusted source-bound direction once construction and present/deferred handling are repaired.

## Test and fixture coverage

The current fixture has ten labels, but the test only constructs actual E1-present/E2-absent and E1-absent/E2-absent contexts, then exercises E0/hash/axis/slot tamper controls. The N06 present type is only asserted to be defined (`gi1_authority_context_tests.jl:220-221`); there is no actual typed N06 mapping passed through `gi1_authority_context_from_a`, no terminal-deferred-present context assertion, and no assertion that changing mapping content changes the context hash. The focused test also calls the trusted validator without an N06 argument for its positive contexts (`:143-146,164`), so it cannot expose the required E2 present/deferred branch.

A repaired test must construct an actual candidate-bound N06 mapping, assert that `n06_mapping_admission` returns `terminal_deferred` for the missing dimensioned law, assert the E2 slot remains `GI1N06PresentAuthoritySlotV1` with mapping/content hash, mutate mapping content and observe a changed context hash, and separately test `n06 === nothing` as the only absent marker. It must also inject an unexpected exception through the factory/dependency seam and observe `program_exception`, while a known ref/hash/axis contradiction remains `fail_closed`. Expected labels remain test oracles only.

## Minimal repair and focused-run gate

1. Fix the constructor's mutually exclusive structural-status check.
2. Preserve supplied N06 mapping as a typed present slot for `terminal_deferred`; reserve `_gi1_e2_absent` for `nothing`. Carry admission errors/status into the context body/hash and make the final `contract_admission` use the actual E1/E2 admission states.
3. Propagate dependency `program_exception` separately from known `fail_closed` contradictions.
4. Add source-backed N06 present/deferred, content-hash mutation and exception-taxonomy tests, plus the existing refs/axes/metadata/slot negative controls.
5. Re-freeze source/test/fixture/runner and obtain a new independent static precheck before any Julia/DESC run.

Until these are repaired and dynamically run, the result is not ready for focused execution. There is no UP2 total, B00/B04, provider, mesh, engineering, physical or R01–R10 credit.
