# Independent Luna review R2 — inverse admission error boundary

Date: 2026-09-17 (Asia/Shanghai). Read-only static review only. No Julia,
DESC, provider, hardware, solver, or runtime test execution was performed;
no product or test file was changed.

## Verdict

**NO-GO.** R2 correctly moves request validation and identity checks outside
the builder catch and adds source-level malformed Float64/Symbol/Int/Inexact/
Overflow/TypeError vectors. However, the expected-input classifier is not a
reliable narrow classifier, so the repaired admission contract cannot be
accepted. Status remains `contract_only`; no UP4 or R01–R10 credit.

## What passes statically

- The slice remains additive and does not modify legacy inverse, M5,
  optimizer/search, provider registries, or the task manifest.
- `_irv1_checked_conversion` limits conversion normalization to
  `MethodError`, `InexactError`, `OverflowError`, and `TypeError`.
- `validate_inverse_realization_request(request)` is textually after the catch;
  untagged internal `ErrorException` and untagged `ArgumentError` are rethrown
  by the visible control flow.
- The test source contains malformed Float64, Symbol/MethodError,
  geometry-Int/InexactError, derivative-Int/OverflowError, and TypeError
  vectors, with `provider_calls == 0` assertions.
- R2 static QA exits `0`; it reports contract-only, no runtime/Julia/DESC, and
  zero provider calls.

## Blocking findings

1. **P1 — tagged input errors are classified through the wrong rendered
   string.** `_irv1_input_error` returns an ordinary `ArgumentError` with an
   `inverse_input:` message, while `_irv1_expected_input_error` checks
   `startswith(sprint(showerror, error), "inverse_input:")` (source line 31).
   Julia's `showerror` rendering for `ArgumentError` includes the exception
   type prefix (the project has prior evidence of decorated
   `sprint(showerror, ...)` output), so the check does not begin with
   `inverse_input:`. The malformed vectors would therefore escape instead of
   returning `:fail_closed` unless this is changed to a real private exception
   type/identity check or a correctly normalized message extraction.

2. **P1 — even if rendering were changed, a message prefix is not a private
   exception classifier.** Any internal `ArgumentError("inverse_input:...")`
   can be swallowed. This violates the requested rule that only external
   malformed conversion/dispatch is normalized while identity errors,
   unmarked `ArgumentError`, and internal defects escape. The test covers an
   unmarked internal error, but not an internally generated colliding prefix.

3. **P1 — runtime proof remains absent.** The R2 test source has real vector
   expressions, but Julia was not executed in this review. The static QA is
   regex/schema based and cannot prove the malformed vectors return the claimed
   statuses or that internal errors escape.

## Required repair

Use a private typed input exception (or an equivalent identity-safe marker)
raised only by the external conversion seam; classify with `isa`/identity, not
an untrusted rendered-message prefix. Preserve validation/identity outside the
catch. Add a collision negative (`ArgumentError("inverse_input:internal")`),
then run the full positive/negative Julia suite and archive the actual exit
code, status matrix, and `provider_calls=0` receipt. Obtain another independent
review before any UP4 credit.

## Hashes reviewed

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `566fdb01c7334f1afac68e5fa25fd4461650cf48f5884dd752facde1459e2b15` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `c86bbd73006e7c408634766a47a78a60839db6e3a2bb78018c0cc2158c0c8e16` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
| `agent_local_r2/static_qa.py` | `4502872cb4a560799ae673558db1ce972d088229f534b91b358233ebf56976c3` |
