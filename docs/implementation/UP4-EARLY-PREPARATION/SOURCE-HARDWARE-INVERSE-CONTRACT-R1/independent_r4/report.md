# Independent Luna review R4 — inverse request typed conversion seam

Date: 2026-09-17 (Asia/Shanghai)
Scope: current UP4 inverse-realization request source, test, fixture and the
agent-local R4 static QA. Read-only review; Julia/DESC were not run, product
and test files were not modified, and no commit was made.

## Verdict

**GO for the next contract-only/runtime gate; NO formal acceptance.** The R3b
conversion-boundary blocker is closed in the current bytes. The admission
seam now routes `AbstractString -> String` through the typed conversion helper,
the test includes a deliberately broken `AbstractString`, admission catches
only the exact `InverseExternalInputError` type, ordinary same-message
`ArgumentError`/`MethodError`/`ErrorException` values are rethrown, and request
validation remains outside the builder catch.

The maximum claim remains `contract_only`, `accepted=false`, with no provider,
solver, inverse, hardware, numerical, engineering, physical or R01-R10
credit. This review supplies static evidence only; it does not prove that the
Julia test executes successfully.

## Evidence

### Typed conversion boundary

- `src/RuntimeV4/InverseRealizationRequestContractV1.jl:39-42` catches only
  the expected conversion exception classes at the local seam and emits
  `InverseExternalInputError(:conversion, ...)`.
- Line 53 uses
  `_irv1_checked_conversion(String, x, label)`; there is no raw
  `value = String(x)` path.
- `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl:8-10`
  defines `_IRV1BrokenString <: AbstractString` whose `Base.String` conversion
  throws `TypeError`.
- Lines 133-138 pass that broken value through
  `admit_inverse_realization_request` and assert typed `:fail_closed`, invalid
  status and zero provider calls.

### Exact admission and non-swallow behavior

- `admit_inverse_realization_request` at lines 394-408 uses
  `typeof(error) === InverseExternalInputError || rethrow()`; it does not use
  message prefixes or an `isa`-based broad catch.
- The test retains same-message ordinary `ArgumentError`, `MethodError` and
  `ErrorException` rethrow controls at lines 140-148, plus untagged internal
  error controls at lines 150-155.
- The builder catch ends before the request-type check and the call to
  `validate_inverse_realization_request`; validation therefore remains outside
  the external-input normalization boundary and internal identity/invariant
  defects are not silently converted.

### Contract-only status boundary

The source retains `:prepared`, `:fail_closed` and `:terminal_deferred`, with
`provider_calls === 0`. The permitted command completed with no runtime lane:

```text
python -B docs/implementation/UP4-EARLY-PREPARATION/SOURCE-HARDWARE-INVERSE-CONTRACT-R1/agent_local_r4/static_qa.py
exit=0
status=pass
schema=UP4InverseRealizationContractStaticQAV4
julia_executed=false
desc_executed=false
provider_calls=0
```

The QA is source/test/fixture inspection and does not execute Julia or prove
the real constructor/validator behavior. A parent-authorized isolated Julia
run and fresh replay remain required before any implementation gate.

## Archive consistency note

The current `agent_local_r4/manifest.json` and its `static_qa.py` bytes agree
on static-QA SHA-256
`f4597520d113c9c2e9e0c79e3439fb3b1a4ec62d95a427160fc654cab258b342`.
The older `agent_local_r4/report.md` hash table lists `f515fd13...` for that
QA file; that report row is stale metadata and must not be reused as a current
hash receipt. The product source/test/fixture hashes below are current and
match the agent-local R4 manifest.

## Current product hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | 21079 | `5c25e92b625eff79b3e4714e3bbfb33e3b57354bddf2a24339296c890537b6e4` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | 8393 | `8f894e05a4ec1dcedda6571e6aa8d7d5e410bb4ef0295ae8950288f0202eaed9` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | 1652 | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
| `docs/.../agent_local_r4/static_qa.py` | 6048 | `f4597520d113c9c2e9e0c79e3439fb3b1a4ec62d95a427160fc654cab258b342` |

## Required next gate

Recompute a fresh archive after the current bytes are frozen, then run the
isolated Julia contract test and an independent fresh-process replay. Preserve
the separation between malformed external input (`fail_closed`), ordinary
program defects (rethrow), missing provider/authority (`terminal_deferred`),
and actual inverse/hardware execution (not present in this slice).

Only this `independent_r4/` archive was added. Existing product, test,
fixture, agent-local and historical archives remain untouched.
