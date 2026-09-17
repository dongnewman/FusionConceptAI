# UP4 inverse-realization contract R3 static report

`static_qa.py` exited `0` with status `pass`.  This is static source/test/
fixture evidence only: Julia and DESC were not run, provider calls are zero,
and the claim ceiling remains `contract_only` with no runtime, performance, or
R01-R10 credit.

R3 defines `InverseExternalInputError <: Exception` with a typed `code` and
`detail`, plus a deterministic `showerror` method.  All constructor and
checked-conversion malformed-input paths throw that exact type.  Admission
catches only `error isa InverseExternalInputError`; it no longer classifies
exceptions using `sprint(showerror)` or message prefixes.  Ordinary
`ArgumentError`, `MethodError`, and `ErrorException`, including same-message
variants, are explicitly required to rethrow.  Request validation remains
outside the catch.

## Input hashes

| Input | SHA-256 |
| --- | --- |
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `84f31fcb2e521997f103811b7be1fcce29ef72abe74a3124bef1c1bf88b6ed48` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `c7af3607ee7ed0a9fd19a03858f881df75a758f048b386e7f0111cd5db648eaa` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |

The repair is additive and leaves legacy inverse code, M5, optimizer/search,
provider registries, and the task manifest untouched.  Runtime Julia tests,
provider resolution, inverse solving, hardware realization, and independent
replay remain open evidence.
