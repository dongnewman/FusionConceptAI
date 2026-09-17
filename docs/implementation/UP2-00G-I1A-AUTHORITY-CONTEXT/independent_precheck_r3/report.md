# G-I1A independent static precheck R3

Verdict: **changes_requested**.

This review is independent of the G-I1A author and preserves R1/R2 archives. It is static only: Julia/DESC were not run and no source, test, or core file was changed.

## Frozen hashes

- `src/GenomeV5/UP2/GI1AuthorityContextV1.jl` SHA-256 `57348d4852f09094b98c5847bd94478629e2da5f72c67d8ef58a1c8a7e69e1fe`
- `test/GenomeV5/UP2/gi1_authority_context_fixtures.json` SHA-256 `86b3f26f00ea1b6c78f3db8b745840ad571bc79252c13535964e6a5a58d04204`
- `test/GenomeV5/UP2/gi1_authority_context_tests.jl` SHA-256 `433fb5e54bb29284ae7072e8a3c93c9d1ada022683e04c0fa4bf0dc353701659`
- `test/GenomeV5/UP2/run_gi1_authority_context.jl` SHA-256 `20d01f6ee0ceb7a7bf11c160a4257224ceee61c50ff229dca62303efa0658ff6`

## Findings

- **GI1A-R3-04** Factory contract_admission is selected only from E1/E2 slot types and ignores e2_admission; an E2 typed-present mapping with terminal_deferred admission is incorrectly promoted to declared_consistent. Minimal fix: require e2_admission == :declared_consistent for declared_consistent, otherwise retain terminal_deferred.
  - source/test line 409: `    e2, e2_admission, e2_gaps = _gi1_e2_slot(package, e0, n06)`
  - source/test line 414: `    admission = e1 isa GI1N05PresentAuthoritySlotV1 &&`
  - source/test line 424: `        contract_admission=admission, physical_resolution=terminal_deferred,`
- **GI1A-R3-05** Factory maps every n05_check status other than valid to ArgumentError; n05_check.status == :program_exception is therefore misclassified as fail_closed instead of retaining program_exception. Minimal fix: branch program_exception before the fail_closed ArgumentError path and preserve that taxonomy through the trusted API.
  - source/test line 405: `        n05_check.status === :valid ||`
  - source/test line 406: `            throw(ArgumentError("GI1 E1 source fail_closed: " * join(n05_check.errors, ",")))`
- **GI1A-R3-06** R3 tests do not execute the explicit N06 typed-present/deferred branch and do not directly test exception taxonomy; the current-A baseline has no valid N06 mapping positive. Minimal fix: add a structurally valid source-bound mapping fixture only to exercise typed E2-present plus terminal_deferred, and add targeted program_exception classification controls without claiming a physical positive.

## Boundary

The current A package has no valid dimensioned N06 source/field/return/heat mapping positive. A typed N06 mapping, if supplied later, must retain its mapping/content hash and may remain `terminal_deferred`; it cannot create physical/provider evidence. No UP2 total, B00, B04, provider, mesh, engineering, physical, or R01-R10 credit is granted.

Command strings, UTC timestamps, real exits, stdout/stderr hashes, JSON parse, plan validation, diff check, and process sweep are in `command_receipts.json`.
