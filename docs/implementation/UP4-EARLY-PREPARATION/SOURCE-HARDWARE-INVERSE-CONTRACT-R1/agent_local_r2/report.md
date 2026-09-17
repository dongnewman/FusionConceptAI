# UP4 inverse-realization contract R2 static report

## Result

`static_qa.py` exited `0` with status `pass`.  The QA is source/test/fixture
inspection only; Julia and DESC were not run.  The slice remains
`contract_only`, `provider_calls=0`, with no runtime, performance, or R01-R10
credit.

## Repair boundary

`admit_inverse_realization_request` now catches only `ArgumentError`s carrying
the private `inverse_input:` tag emitted by the typed constructor/conversion
seam.  Float64, Symbol, Tuple, and Int conversions locally normalize
`MethodError`, `InexactError`, `OverflowError`, and `TypeError` into that typed
input error.  After the builder returns, request-type checking and
`validate_inverse_realization_request` run outside the catch.  Thus an
untagged `ErrorException` or `ArgumentError`, identity failure, or other
internal defect is not silently converted to `fail_closed`.

The static test vectors cover malformed Float64, Symbol/MethodError, geometry
Int/InexactError, derivative Int/OverflowError, a TypeError conversion path,
and explicit internal-defect non-swallow cases.  All fail-closed vectors keep
`provider_calls=0`.

## Input hashes

| Input | SHA-256 |
| --- | --- |
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `566fdb01c7334f1afac68e5fa25fd4461650cf48f5884dd752facde1459e2b15` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `c86bbd73006e7c408634766a47a78a60839db6e3a2bb78018c0cc2158c0c8e16` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |

## Evidence boundary

This R2 package is additive and does not touch legacy inverse sources, M5,
optimizer/search, provider registries, or the task manifest.  Runtime Julia
execution, provider invocation, inverse solving, hardware realization,
independent runtime replay, and DESC evidence remain open.
