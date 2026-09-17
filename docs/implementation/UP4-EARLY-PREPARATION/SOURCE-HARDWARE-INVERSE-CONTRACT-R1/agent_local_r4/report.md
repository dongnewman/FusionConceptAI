# UP4 inverse request contract R4 implementation

Date: 2026-09-17 (Asia/Shanghai).

## Scope

Implemented the narrow R3b repair only:

- `_irv1_text` now routes the external `AbstractString -> String`
  normalization through `_irv1_checked_conversion`, so the existing typed
  `MethodError`/`InexactError`/`OverflowError`/`TypeError` seam normalizes
  conversion failures to `InverseExternalInputError`.
- Added `_IRV1BrokenString <: AbstractString` with a failing `Base.String`
  conversion and an admission test asserting `:fail_closed`, invalid result,
  and `provider_calls == 0`.
- Admission now uses `typeof(error) === InverseExternalInputError`, while
  ordinary same-message `ArgumentError`, `MethodError`, and `ErrorException`
  remain rethrown.
- Validation remains outside the builder catch. Contract status remains
  `contract_only`; no provider, solver, hardware, or inverse realization is
  added.
- Static QA now asserts the typed text-conversion seam, exact-type guard, and
  new AbstractString negative.

## Evidence boundary

Static QA command:

```text
python -B docs/implementation/UP4-EARLY-PREPARATION/SOURCE-HARDWARE-INVERSE-CONTRACT-R1/agent_local_r4/static_qa.py
```

Exit code: `0`; status: `pass`; reported schema:
`UP4InverseRealizationContractStaticQAV4`.

Julia and DESC were not run. No runtime, provider, numerical, hardware,
inverse-solver, UP4, or R01–R10 credit is claimed. No commit was created.

## Reviewed input hashes

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `5c25e92b625eff79b3e4714e3bbfb33e3b57354bddf2a24339296c890537b6e4` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `8f894e05a4ec1dcedda6571e6aa8d7d5e410bb4ef0295ae8950288f0202eaed9` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
| `agent_local_r4/static_qa.py` | `f4597520d113c9c2e9e0c79e3439fb3b1a4ec62d95a427160fc654cab258b342` |
