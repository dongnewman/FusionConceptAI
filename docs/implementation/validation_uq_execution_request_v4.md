# Validation/UQ execution request V4

## Boundary

`ValidationUQExecutionRequestV4.jl` is an isolated downstream boundary. It
accepts only these already-typed objects:

1. an externally revalidated `TrustedProviderRegistryV4`;
2. the exact externally revalidated `ForwardChainContextV4`;
3. a `TrustedProviderDispatchRequestV4` that is still
   `ready_for_dispatch`; and
4. the matching externally revalidated
   `TrustedProviderExecutionReceiptV4`.

The builder has no manifest or executor parameter. It does not dispatch a
provider and cannot replace the executor selected by the trusted registry. A
caller-supplied manifest, executor, output hash, status, evidence record, or
decision therefore cannot enter this boundary.

The sole request state is `recoverable_evidence_gap`. A completed operational
receipt proves only that the repository-owned dispatch path produced the
receipt-bound output. It is not scientific evidence and cannot yield a pass,
closure, promotion, P5 readiness, terminal disposition, or credible physical
candidate.

## Exact upstream binding

The request copies and hashes the complete upstream identity chain:

- registry and forward-context hashes;
- materialized physical-subject and selected-scenario hashes;
- trusted dispatch-request and execution-receipt hashes;
- repository-owned provider-manifest and output hashes; and
- the registered provider identity and operational status.

Construction revalidates the registry, context, dispatch request, and receipt
against one another before using any field. Validation rebuilds the request
from those same external objects and the typed requirements, then revalidates
every embedded requirement and gap field rather than trusting their stored
hashes. The one-argument validator always returns `false`, and
`canonical_hash(request)` fails closed, because a detached request cannot
establish that its trust chain is still valid.

## Typed evidence gaps

`ValidationUQEvidenceRequirementV4` declares one missing evidence class. Its
canonical hash binds a unique requirement identifier, evidence kind,
source-class policy, required artifact names, and protocol hash. The seven
supported kinds deliberately remain non-substitutable:

| Evidence kind | Required source class |
|---|---|
| `numerical_verification` | `manufactured_numerical_control` |
| `cross_code_validation` | `independent_code` |
| `physical_validation` | `held_out_physical_experiment` |
| `calibration_holdout` | `disjoint_data_partition` |
| `measurement_uq` | `measurement_uncertainty_model` |
| `model_form_uq` | `model_form_uncertainty` |
| `parameter_uq` | `parameter_uncertainty_distribution` |

Every requirement becomes a `ValidationUQEvidenceGapV4` tied to the exact
trusted receipt. Gaps are explicitly recoverable and always carry
`evidence_credit = 0`. Duplicate requirement identifiers, unknown kinds,
untyped requirements, empty requirement sets, forged source classes, and hash
substitutions fail closed.

## FreeGS handling

The runnable example obtains its input from the repository-owned trusted
FreeGS adapter and performs the real pinned FreeGS execution. The resulting
trusted receipt is operational with status `physical_model_screen`. That
status is intentionally translated to the typed reason
`physical_model_screen_has_zero_validation_credit` for all seven outstanding
requirements.

FreeGS is therefore useful as a candidate-bound physical-model screen, but it
does not satisfy physical validation, cross-code independence, calibration
holdout, measurement UQ, model-form UQ, parameter UQ, or even the separate
numerical-verification requirement. No screen output is promoted into evidence.

## Authority firewall

The manifest reports zero evidence credit and zero credible physical
candidates. This slice emits no evidence and owns no pass, closure, promotion,
P5, or terminal authority. Missing evidence remains recoverable rather than
being converted into `unsupported` or a terminal rejection.

The module is intentionally not added to the package aggregator. It consumes
the accepted trusted-registry/FreeGS types without modifying their semantics.
