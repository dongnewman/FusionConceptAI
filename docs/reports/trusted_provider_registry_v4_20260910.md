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

The accepted registry now also has an opt-in fixed catalog containing the first
non-test descriptor: a narrow adapter around the committed FreeGS axisymmetric
bridge. The base bootstrap remains independently loadable and test-only. The
FreeGS bootstrap hashes the adapter, accepted bridge, controlled runner, and
loaded entrypoint without executing the solver. Its capability and typed input
are derived from the exact revalidated axisymmetric G2 binding and context.

## Authority boundary

- emitted scientific evidence: no;
- physical-validation credit: 0;
- credible physical candidate count: 0;
- P5 ready: false;
- closure, promotion, or terminal authority: none.

The fixture executor and its completed receipt are test-only operational
artifacts. The FreeGS trusted receipt binds the already-defined FreeGS receipt
and output hashes and retains its `physical_model_screen` status. Neither path
validates a candidate or satisfies validation, engineering, or closure
obligations.

## Files

- `src/RuntimeV4/TrustedProviderRegistryV4.jl`
- `src/RuntimeV4/TrustedFreeGSAxisymmetricProviderV4.jl`
- `examples/runtime_v4_trusted_provider_registry.jl`
- `examples/runtime_v4_trusted_freegs_axisymmetric_provider.jl`
- `test/runtime_v4_trusted_provider_registry_tests.jl`
- `test/runtime_v4_trusted_freegs_axisymmetric_provider_tests.jl`
- `scripts/run_v4_trusted_provider_registry.jl`
- `docs/implementation/trusted_provider_registry_v4.md`
- this report

No aggregator, protected prototype, or accepted FreeGS bridge/runner source was
modified. The accepted registry source was extended and the adapter is isolated
in its own file. No commit or push was made for this extension.

## Verification

All commands completed with definitive exit code 0:

- focused base-registry tests: 65/65, including standalone loading without the
  FreeGS bridge, source/runtime/root drift,
  caller-executor prebinding rejection, foreign-context gaps, forged request,
  and forged receipt cases;
- standalone example: one trusted registration, `ready_for_dispatch`, and one
  operational `completed` receipt with exit code 0;
- trusted FreeGS focused integration: 43/43, including exact-binding capability,
  canonical-input substitution rejection, and outer receipt/output binding;
- real pinned FreeGS 0.8.2 dispatch: `physical_model_screen`, Julia/backend exit
  0, output hash
  `69265b169c16ff309fd273fe107ccc8971cc5169dfbd3bcaf6c78271f3af51e9`
  and receipt hash
  `fc8bbb78458599eaf3264d1ce75efcda2b21807f80790ea9a23076c085221866`;
- RuntimeV4 core tests: 26/26;
- RuntimeV4 spine tests: 54/54.
