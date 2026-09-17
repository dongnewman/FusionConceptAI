# UP4 inverse-realization contract R5 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for the R5 contract-only static handoff; NO-GO for the next runtime or
formal UP4 gate.** The current source, tests, fixture, and R5 static QA
provide the requested domain-repair coverage: the same-domain fixture reaches
the prepared path only after stable unique normalization, cross-domain source
and target domains remain distinct, duplicate provider domains are constructed
directly and normalized at the admission boundary, and the source/geometry
cross-domain case asserts `source_geometry_domain_mismatch`. The duplicate
provider path has `fail_closed`, `provider_calls == 0`, and no backend call.

The ceiling remains `contract_only / prepared`, with `accepted=false` and
`formal_acceptance=false`. No provider, solver, hardware, engineering,
physical, convergence, or R01-R10 credit is issued.

## Scope and R4 lineage

Reviewed read-only:

- `src/RuntimeV4/InverseRealizationRequestContractV1.jl`
- `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl`
- `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json`
- R5 `agent_local_r5/report.md`, `manifest.json`, and `static_qa.py`
- R4 receipt under
  `runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r4/`

The preserved R4 receipt is an exit-1 constructor error: the old same-domain
fixture passed duplicate provider domains into the product constructor, which
correctly raised `InverseExternalInputError` before the test summary
(`0 passed / 0 failed / 1 error`). Its pre/post input hashes are identical,
`hashes_unchanged=true`, and the raw stdout/stderr and hash files remain
present. The R5 current source/test/fixture/QA hashes below match the current
bytes and the R5 manifest.

No product or test file was changed by this review; only this independent
archive is added. Julia/DESC and all runtime backends were not run. No commit
was created.

## Static findings

### Domain normalization and preservation

The fixture builder uses `Tuple(sort!(unique((target_domain, source_domain))))`.
Thus the ordinary same-domain fixture supplies one canonical provider domain
and reaches `:prepared`; the explicit cross-domain fixture retains both
domains and asserts the canonical order `("source-domain", "target-domain")`.
The provider constructor itself rejects duplicate domain values rather than
silently erasing malformed external input.

### Duplicate provider-domain admission

The test directly constructs
`InverseRealizationProviderCapabilityV1(...,
domains=("electrical-hardware", "electrical-hardware"), ...)` inside
`admit_inverse_realization_request`. `_irv1_sorted_strings` raises the sealed
`InverseExternalInputError` at construction, and the admission seam returns
`:fail_closed`, `valid == false`, the duplicate-domain reason, and
`provider_calls == 0`. The catch is exact-type-only; ordinary internal errors
are not normalized.

### Source/geometry mismatch

The cross-domain fixture is built with `target_domain="target-domain"`,
`source_domain="source-domain"`, and geometry bound to the target domain.
Validation therefore executes the real request path and asserts
`:fail_closed`, the exact `source_geometry_domain_mismatch` reason, and zero
provider calls. This is not a fixture-only marker or a backend result.

## Evidence and next gate

```text
python -B docs/implementation/UP4-EARLY-PREPARATION/UP4-INVERSE-REALIZATION-CONTRACT-MATRIX-R5/agent_local_r5/static_qa.py
exit=0
status=pass, checks=20/20
```

The next gate is a fresh-process focused Julia test followed by independent
runtime review. Static QA and the R4 failure receipt must not be used as
runtime, numerical, engineering, hardware, or formal evidence.

## Current SHA-256

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `5c25e92b625eff79b3e4714e3bbfb33e3b57354bddf2a24339296c890537b6e4` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `898bf30229a7254f3aaa5388253c959a51247d13bb66dc4afca999168aa2a2b5` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `51c025279dc514fc035366696ffa29387ffac5b68f9edfab9ceab43daab39fcd` |
| `docs/implementation/UP4-EARLY-PREPARATION/UP4-INVERSE-REALIZATION-CONTRACT-MATRIX-R5/agent_local_r5/static_qa.py` | `97592239adbc9b24af6ce7519e3164f63b417951ebad4cea32dfd87bb39b11cd` |
