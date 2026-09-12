# Candidate validation diagnostics and discrepancy propagation

`CandidateValidationPropagationV4.jl` consumes the same current `imit_upstream`
candidate as the regional physics chain. Its public execution entry point is:

```julia
execute_candidate_validation_propagation(upstream, traction_request,
    traction_result, q2_request, q2_result, q2_execution, q3_execution,
    q4_execution, independent_execution; run_dir)
```

The upstream q4 and independent cubature owner validators run before any credit
is recorded. Candidate/context, equilibrium execution, physical partition,
request/result/receipt identities, source bytes and output bytes remain bound.
`validate_candidate_validation_propagation` replays the reduction and propagation
from those validated inputs without launching another provider.

## Different integration formulation

Existing q2/q3/q4 and midpoint cubature sample one field period, with their
weights scaled by `NFP`. Directly applying these scalar weights to laboratory
Cartesian vectors produces a sector-replicated proxy: horizontal vector
components rotate between field periods. The new independent reduction uses
the provider's native cylindrical force and actual laboratory angle `phi`:

`sum_k R(phi + 2*pi*k/NFP) * F_RphiZ * sqrt(g) * weight/NFP`.

This does not assume `phi == zeta`; `zeta` locates the sample and `phi` determines
its laboratory basis. It relies on the executed DESC model's declared field
periodicity. It is a periodic-model inference; the provider was not run in each
period. The scalar volume and `integral(norm(F) dV)` are also reduced, so a small
global vector caused by periodic cancellation cannot establish local force
balance. The original observations remain available as explicitly labelled
`sector_replicated_cartesian_proxy_N` values.

The NFP interpretation is documented by the primary [DESC collocation-grid
guide](https://desc-docs.readthedocs.io/en/v0.16.0/dev_guide/notebooks/grid.html).
The rotation requirement follows from the laboratory-vector transformation in
`DESCFieldBasisBridgeV4.jl`; it is an inference about integration, not additional
experimental evidence.

## Executed evidence and missing evidence

- An analytic cylindrical-vector benchmark checks the independent rotation
  against the exact full-ring integral. A radial-polynomial integral checks the
  separately implemented midpoint error ratio. Both are code verification with
  zero physical validation credit.
- Three executed formulations supply a per-region component discrepancy box.
  Interval addition propagates these boxes into total force, then an explicit
  nearest/farthest-component calculation propagates into resultant norm.
- The boxes are observed formulation spreads. They are not certified numerical
  error bounds, confidence intervals, or parameter distributions.
- `numerical_status` is `fail` when the local-force-integral relative spread
  exceeds the sealed upstream tolerance; otherwise it remains `deferred` until
  solution-verification obligations are met. A cancelled resultant cannot pass
  this numerical gate.
- Independent physics-code validation, candidate-applicable held-out physical
  data, parameter distributions/covariance/sampled runs, and model discrepancy
  remain distinct recoverable `unsupported` gaps, with `executed=false`.

## Legacy reuse audit

| Legacy source | Decision | Reason / extracted concept |
| --- | --- | --- |
| `outputs/fusion_concept_ai/src/numerical_verification.jl` | test-only | Scalar event/ODE manufactured verification and convergence checks are useful testing patterns; hardcoded measurement floor and fixture pass cannot validate this candidate. |
| `outputs/fusion_concept_ai/src/candidate_vvuq_runtime_v87.jl` (`compile_solution_verification_v87`) | extract | Preserve separate run hashes, explicit observables and tolerances, and failed convergence; replace dictionary-only claims with actual typed provider artifacts. |
| Same file (`compile_parametric_uq_v87`) | extract | Preserve distribution/covariance/sampling provenance and actual sample requirements. No current distribution manifest means no claimed parametric execution. |
| Same file, cross-code/measured/engineering authorization | reject | Its old acceptance/authority and legacy candidate routing are not imported. Sharing DESC is not independent-code validation. |
| Legacy report/fixture wrappers | reject | No wrapper is admitted solely because it returns a record or `pass`; execution and physical applicability must be established in this chain. |

No legacy authority, family label, or replacement of the Julia core, three
Genome layers, typed AST, or operator hypergraph is introduced.

## Existing work preservation

Before repairing the untracked independent-cubature work, the original source,
example, test, runner and two documents were copied to
`runs/candidate_validation_propagation/preserved_20260912/`. The initial process
was allowed to finish and returned exit 1, identifying a missing
`DESCFieldSamplePointV4` in its isolated module. Its example now loads into the
upstream provider-owner module. Its receipt validation additionally checks the
full upstream chain and result/request/receipt/context/partition binding. The
unrelated modified `runtime_v4_validation_uq_execution_request_tests.jl` is not
changed by this work.
