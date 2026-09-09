# Trusted provider registry V4 report — 2026-09-10

## Outcome

Added an isolated repository-owned provider trust chain, immutable
registrations, dispatch requests, execution wrapper, and operational receipt.
The implementation resolves execution from a fixed descriptor, recomputes
repository source/runtime identities, and rejects arbitrary manifests,
executors, code hashes, roots, contexts, and forged content hashes.

The package's first-bound executor map is treated as an availability risk, not
authority. A prebound caller stub makes the later trusted factory reject the
conflict; execution never falls back to that stub.

## Authority boundary

- emitted scientific evidence: no;
- physical-validation credit: 0;
- credible physical candidate count: 0;
- P5 ready: false;
- closure, promotion, or terminal authority: none.

The fixture executor and its completed receipt are test-only operational
artifacts. They do not validate a candidate or satisfy any physical obligation.

## Files

- `src/RuntimeV4/TrustedProviderRegistryV4.jl`
- `examples/runtime_v4_trusted_provider_registry.jl`
- `test/runtime_v4_trusted_provider_registry_tests.jl`
- `scripts/run_v4_trusted_provider_registry.jl`
- `docs/implementation/trusted_provider_registry_v4.md`
- this report

No aggregator, protected prototype, or existing source file was modified. No
commit or push was made.

## Verification

All commands completed with definitive exit code 0:

- focused registry tests: 62/62, including source/runtime/root drift,
  caller-executor prebinding rejection, foreign-context gaps, forged request,
  and forged receipt cases;
- standalone example: one trusted registration, `ready_for_dispatch`, and one
  operational `completed` receipt with exit code 0;
- RuntimeV4 core tests: 26/26;
- RuntimeV4 spine tests: 54/54.
