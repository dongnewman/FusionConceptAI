# Independent Luna review R3b — inverse admission error boundary

Date: 2026-09-17 (Asia/Shanghai). Read-only static review. No Julia, DESC,
provider, hardware, solver, or runtime test execution was performed. No
product or test file was changed. The existing `independent_r3/` archive was
left untouched; this collision-safe `independent_r3b/` archive records the
independent finding.

## Verdict

**NO-GO for closing the R3 boundary; GO only for the bounded static scan.**

The typed exception seam is substantially present and the existing static QA
exits `0`, but the implementation does not yet satisfy the requested rule
that every external checked conversion is explicitly wrapped.

## Blocking finding

`_irv1_text` first checks `x isa AbstractString`, then performs the external
normalization with raw `String(x)` (source line 53). That conversion is outside
`_irv1_checked_conversion`. A hostile or malformed `AbstractString` subtype can
therefore raise a conversion `MethodError`, `TypeError`, or another ordinary
conversion exception directly from the constructor. Through
`admit_inverse_realization_request`, that exception is not an
`InverseExternalInputError` and is rethrown, rather than being normalized as a
typed malformed-input result. This violates the requested “all external
checked conversions explicitly wrap” boundary.

The required repair is narrow: route the `String(x)` normalization through the
same checked conversion helper (or an equivalent dedicated wrapper), and add a
test using an `AbstractString` conversion failure. The existing primitive
Float64/Int/Symbol/Tuple conversion paths are already routed through
`_irv1_checked_conversion` and explicitly classify `MethodError`,
`InexactError`, `OverflowError`, and `TypeError`.

## Other checks

- `InverseExternalInputError` is a concrete `struct <: Exception` with typed
  fields and deterministic `showerror`.
- Admission catches only `error isa InverseExternalInputError`; because the
  type is concrete and cannot have subtypes, this is behaviorally sealed in
  the current Julia type definition. For a literal exact-type proof, the guard
  and static QA should use `typeof(error) === InverseExternalInputError`.
- Ordinary same-message `ArgumentError`, `MethodError`, and `ErrorException`
  thrown directly by the builder are explicitly required by tests to rethrow;
  the untagged internal `ArgumentError`/`ErrorException` cases are also
  covered.
- `validate_inverse_realization_request(request)` is textually after the
  builder `try/catch`, so request identity failures and validation defects are
  not normalized by the external-input catch.
- Existing tests cover malformed Float64, Symbol/dispatch, Int/Inexact,
  Int/Overflow, and explicit TypeError vectors, plus ordinary non-swallow
  vectors. They do not cover failure of the raw `String(x)` conversion.
- Existing Python static QA was rerun read-only and exited `0`; its
  `admit:exact-type-only` check is insufficient to detect the raw String
  conversion gap and treats the `isa` guard as literal exactness.

## Boundary

The slice remains additive and `contract_only`; no provider, derivative,
hardware, inverse solver, Julia runtime, DESC execution, UP4 promotion, or
R01–R10 credit is claimed.

## Reviewed input hashes

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `84f31fcb2e521997f103811b7be1fcce29ef72abe74a3124bef1c1bf88b6ed48` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `c7af3607ee7ed0a9fd19a03858f881df75a758f048b386e7f0111cd5db648eaa` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
