# Independent Luna review R1 — inverse realization request contract

Date: 2026-09-17 (Asia/Shanghai). This is a read-only independent static
review. No Julia, DESC, provider, hardware, solver, or test execution was
performed by this reviewer, and no product or test file was changed.

## Verdict

**NO-GO for acceptance.** The implementation remains bounded to
`contract_only`; the machine/runtime status must remain unaccepted and no UP4,
B07A/B07B, provider, engineering, physical, solver, or R01–R10 credit may be
issued. The existing static QA replay passes, but it is token/schema QA and
cannot substitute for runtime positive/negative execution.

## Scope checks

The new source is additive and does not reference legacy inverse/M5 modules,
the operator registry, or the task manifest. The scoped working-tree query
shows only the new source, test, fixture, and their evidence directory; no
existing legacy, M5, registry, or manifest file is modified.

The declaration surface does cover:

- target/source/optional-return roles and quantity/unit pairing;
- scalar/field/geometry-map function-space constraints and domain equality;
- finite ordered bounds for power, current, voltage, density,
  conductivity, and geometry extent;
- material and geometry model references;
- EMF policy and derivative-order capability checks;
- provider capability sets, sorted ordering, canonical request identity, and
  `provider_calls=0` result receipts;
- contradiction-to-`fail_closed` and missing-prerequisite-to-
  `terminal_deferred` branches.

The Julia test source contains real constructor/validator calls for the
positive case and negative cases (return mismatch, missing provider/return/
derivative/material/geometry capability, forbidden voltage EMF, invalid bounds,
and constructor admission). It is nevertheless **unrun** in this review.

## Blocking finding

`admit_inverse_realization_request` catches only `ArgumentError`
([source line 364](../../../../../src/RuntimeV4/InverseRealizationRequestContractV1.jl:364)).
Several constructors perform unchecked conversions or rely on typed dispatch:

- `_irv1_float` calls `Float64(x)` (line 34), which can raise a conversion or
  dispatch exception for malformed input;
- geometry converts `Int(dimension)` (line 160);
- provider capability converts every derivative order with `Int(x)` (line 189);
- the typed request constructor can fail at method dispatch (line 217) before
  the admission body is entered.

Those paths can escape instead of returning the required typed
`fail_closed` result. The current test only exercises an `ArgumentError`
(`InverseRealizationBoundV1(:power, :V, ...)`) and does not cover malformed
types/conversion failures. This is a contract correctness gap, not merely a
missing documentation assertion.

## Evidence boundary and required repair

The prior static QA replay returned pass with `runtime_executed=false`,
`julia_executed=false`, `desc_executed=false`, and `provider_calls=0`. Its
positive/negative tokens prove the test source is substantive, but do not prove
the tests executed or that the admission exception gap is closed.

Before any acceptance or UP4 credit, repair the admission boundary so all
illegal construction/type/conversion inputs are deterministically represented
as typed `fail_closed` (while preserving unexpected internal errors as a
separate program exception if that is the project policy), add runtime
negative vectors for malformed Float64/Int/typed-dispatch inputs, then run the
positive and negative Julia tests and archive the actual exit code and zero
provider-call receipt. Until then the status ceiling is `contract_only`, with
`changes_requested`/`review_pending`.

## Hashes reviewed

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `1cde7d4640534f8accd9e5946b87bbdc7e998c1be1acc4445b5d8dc8460c4d5d` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `9bed224889b3faa0fdc19eff951741b9e98c94520cbdebdf5beef8e8cd9884b5` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
| `agent_local_r1/static_qa.py` | `c92471beb0e7a9f14dc5f8f6a60bcceda60da411aa6d7f464400fd4e53db7ad2` |
