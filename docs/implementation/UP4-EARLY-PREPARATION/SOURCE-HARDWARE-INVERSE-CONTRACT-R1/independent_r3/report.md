# Independent Luna review R3 — inverse admission error boundary

Date: 2026-09-17 (Asia/Shanghai). Read-only static review. No Julia, DESC,
provider, hardware, solver, or runtime test execution was performed; no
product or test file was changed by this review.

## Verdict

**GO for the R3 static contract review; NO-GO for formal/stage acceptance.**
R3 closes the R2 message-prefix classifier defect with a sealed typed
`InverseExternalInputError` and exact-type admission catch. The status ceiling
remains `contract_only`, `formal_acceptance=false`, and no UP4 or R01–R10 credit
is claimed until the focused Julia tests and downstream provider/inverse
evidence run.

## Checks

- The source is additive and does not touch legacy inverse code, M5,
  optimizer/search, provider registries, or the task manifest.
- `InverseExternalInputError <: Exception` is a concrete sealed Julia type with
  deterministic `showerror`; malformed constructor paths and all checked
  conversion seams throw this exact type. No string-prefix classifier remains.
- `_irv1_checked_conversion` explicitly handles only the checked conversion
  classes `MethodError`, `InexactError`, `OverflowError`, and `TypeError`, and
  rethrows other exceptions. The test source includes malformed Float64,
  Symbol/dispatch, geometry Int/Inexact, derivative Int/Overflow, and explicit
  TypeError vectors with `provider_calls == 0` assertions.
- `admit_inverse_realization_request` catches only
  `error isa InverseExternalInputError`. Same-message ordinary
  `ArgumentError`, `MethodError`, and `ErrorException`, plus internal
  `ArgumentError`/`ErrorException`, are explicitly required to rethrow.
- Request type checking and `validate_inverse_realization_request(request)`
  are textually outside the external-input catch, so identity/invariant or
  validation defects cannot be normalized into malformed-input results.
- The R3 static QA exited `0` and confirms the contract-only/no-provider-call
  boundary.

## Evidence and boundary

This review is static only. No Julia result, provider resolution, source or
hardware inverse realization, numerical/engineering evidence, or R01–R10
credit is claimed.

## Required next gate

Run the focused Julia suite, archive actual malformed/non-swallowed exception
results and `provider_calls=0`, then perform the provider capability and inverse
realization evidence gates before any UP4 promotion.

## Reviewed hashes

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `84f31fcb2e521997f103811b7be1fcce29ef72abe74a3124bef1c1bf88b6ed48` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `c7af3607ee7ed0a9fd19a03858f881df75a758f048b386e7f0111cd5db648eaa` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
