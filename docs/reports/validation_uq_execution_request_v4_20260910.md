# Validation/UQ execution request V4 report — 2026-09-10

## Outcome

Replaced the rejected declaration/provider-admission design with a narrow
downstream evidence-request boundary. It consumes the accepted trusted registry,
exact forward context, trusted dispatch request, and matching trusted execution
receipt. All four inputs are externally revalidated before the slice can emit
anything.

The public builder accepts neither provider manifests nor executors. Its output
binds the registry, context, materialized subject, selected scenario, dispatch
request, trusted receipt, repository-owned manifest, provider output, provider
identity, and operational status. Detached one-argument validation and hashing
fail closed.

The runnable example executes the actual pinned FreeGS 0.8.2 path through the
repository-owned trusted adapter. The receipt completes as
`physical_model_screen`; the new boundary produces seven typed, recoverable
evidence gaps and zero evidence credit. It never converts the screen into
validation or UQ evidence.

## Evidence requirements

The request keeps seven evidence classes separate: numerical verification,
independent cross-code validation, held-out physical validation, disjoint
calibration/holdout data, measurement UQ, model-form UQ, and parameter UQ.
Each requirement has a policy-derived source class, artifact list, protocol
hash, and canonical requirement hash. Every resulting gap is bound to the exact
trusted receipt hash.

## Authority result

- trusted FreeGS provider executed: yes, operationally;
- trusted operational status: `physical_model_screen`;
- request status: `recoverable_evidence_gap`;
- outstanding typed evidence gaps: 7;
- accepted evidence: no;
- emitted evidence: no;
- evidence and physical-validation credit: 0;
- credible physical candidate count: 0;
- P5 ready: false;
- closure, promotion, or terminal authority: none;
- terminal unsupported emitted: false.

The FreeGS screen cannot satisfy any of the seven requirements. In particular,
a candidate-bound physical-model calculation is not a held-out physical
experiment and does not supply an independent code, a disjoint dataset split,
or any measurement/model/parameter uncertainty model.

## Files

- `src/RuntimeV4/ValidationUQExecutionRequestV4.jl`
- `examples/runtime_v4_validation_uq_execution_request.jl`
- `test/runtime_v4_validation_uq_execution_request_tests.jl`
- `scripts/run_v4_validation_uq_execution_request.jl`
- `docs/implementation/validation_uq_execution_request_v4.md`
- this report

No aggregator or the separate rejected `ValidationUQContracts.jl` slice was
modified. No commit or push was made. The accepted trusted-registry and FreeGS
sources were consumed without changing their semantics.

## Verification

All commands completed with process exit code 0:

- standalone real-FreeGS example: `physical_model_screen`,
  `recoverable_evidence_gap`, 7 requirements, 7 gaps, and evidence credit 0;
- focused runner: 63/63 assertions plus
  `VALIDATION_UQ_EXECUTION_REQUEST_FOCUSED_EXIT_CODE=0` and
  `VALIDATION_UQ_EXECUTION_REQUEST_OK`;
- RuntimeV4 core tests: 26/26;
- RuntimeV4 spine tests: 54/54.

The focused suite covers all seven zero-credit gaps, authority absence,
manifest/executor API rejection, external trust-chain revalidation,
duplicate/untyped/empty requirements, and forged receipt, requirement, gap,
and request data. Embedded objects are reconstructed during external
validation; matching stored hashes alone are insufficient.
