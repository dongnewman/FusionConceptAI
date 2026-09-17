# Multi-region diffusion provider

The provider is a bounded two-region, one-dimensional manufactured numerical
screen. Its plan is accepted only after `MultiRegionCouplingContractV4` has
validated candidate prefix, Genome bundle, mission/bounds, mechanism graph,
region ownership, interface endpoints, typed ports, ledger identity,
orientation, and coefficient closure. The solver assembles and solves the
declared sparse block system, checks residual, continuity, and flux closure,
and emits a content-addressed receipt. Missing real constitutive/3-D provider
capability remains a recoverable gap; this screen grants no physical evidence.

## Candidate-bound 3-D admission boundary (v2)

`integrate_multiregion_context` accepts only a validated typed
`ForwardChainContextV4`. It resolves the validator and (when available) the
3-D composition API from the module owning the concrete context type, then
records the exact context, candidate, subject, scenario, and composition
hashes. This prevents a context from one fixture module being checked against
another module's type universe. A missing or incomplete composition is
reported as a recoverable gap; a complete structural composition still
reports `required_real_multiregion_constitutive_provider` and remains
`:deferred`/`:screen_only`.

The existing sparse solver is intentionally not used for this admission path:
it is a manufactured 1-D control and cannot stand in for a 3-D constitutive,
field, interface, or physical provider. Legacy `outputs/fusion_concept_ai`
multi-region code is `test-only` for vocabulary and negative-test intent;
legacy provider/authority types are rejected, while only algorithmic checks
that preserve the current typed contract may be extracted.

## DESC artifact bridge (prototype only)

`admit_desc_multiregion_provider` is intentionally stricter than the generic
context integration helper. It requires a non-empty, independently validated
current-candidate MultiRegion contract with typed interfaces, then invokes the
DESC receipt owner's `validate_desc_provider_receipt` before consuming its
HDF5 identity. It also matches the validated execution result to the exact
context and candidate. The current DESC context has no accepted MultiRegion
interface contract, so the guard test rejects an empty-channel/geometry-node
placeholder; this prototype is not multi-region readiness evidence.
