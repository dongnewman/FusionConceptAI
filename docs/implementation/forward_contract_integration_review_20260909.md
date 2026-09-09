# Forward-contract integration boundary — 2026-09-09

## Decision

Reject inclusion, export, staging, or commit of these four untracked modules in
their current form:

- `MultiRegionCouplingContracts.jl`;
- `MultiRegionDiffusionProvider.jl`;
- `EngineeringControlFaultContracts.jl`;
- `ValidationUQContracts.jl`.

Accept `GridapFieldConvergence.jl` (B2) and `GridapFieldEvidence.jl` (B3) only
as isolated `screen_only` manufactured-control modules. They were committed as
separate milestones at `85f72f8` and `c90e0ad`; do not include/export them from
`src/RuntimeV4/FusionRuntimeV4.jl` or represent the six modules as an integrated
forward chain on this verdict.

The committed Gridap B1 adapter remains an accepted, isolated
`manufactured_control` at `screen_only`. B2 and B3 extend only its isolated
qualification and evidence-envelope scope; their acceptance does not accept
multi-region coupling, engineering/control/fault closure, VVUQ, whole-device
closure, or final authority.

This document specifies the smallest contract that would make a later
integration review meaningful. It does not authorize source changes and does
not introduce a parallel runtime model.

## One forward identity, passed by typed artifacts

Every downstream plan must be constructed from one typed, validated context;
it must not reconstruct the context from caller-supplied hashes or free-form
evidence references.

```julia
struct ForwardChainContextV4
    candidate::CandidateStatePackageV4
    compiled::CompiledCandidatePrefixV4
    registry::GenomeContractRegistryV4
    subject::ExecutablePhysicalSubjectV4
    scenario::Any
    obligations::Tuple{Vararg{CapabilitySignatureV4}}
    context_hash::Digest256
end
```

The public factory for this context must accept the actual mission payload,
bounds payload, comparison scope, and scenario scope and rerun
`_runtime_validate_compiled_prefix`. It must then prove all of the following:

1. The candidate's three current Genome references and hashes match the
   registry and the compiled prefix exactly.
2. The compiled mechanism, field/geometry, realization, and control graphs are
   the candidate-owned typed graphs; selected AST roots and hyperedges are
   referenced by canonical typed identity, never only by an integer position
   or a caller-provided digest.
3. `subject.compiled_prefix_hash`, `subject.genome_bundle_hash`,
   `subject.mission_hash`, and `subject.bounds_hash` equal the validated prefix,
   candidate, mission, and bounds identities respectively.
4. The scenario payload is in the subject's frozen scenario scope, and its
   canonical hash is the only `scenario_hash` used by inputs, evidence,
   receipts, and reports.
5. Subject obligations are derived from the compiled graphs. A caller cannot
   add, remove, or self-declare an obligation while constructing a downstream
   module.

The `context_hash` must be derived from the semantic body excluding
`context_hash`. Validation must recompute that body; an overload that merely
returns the stored hash is not an integrity check.

## One module-report envelope

The six modules need not share their internal numerical types, but each must
return one sealed envelope with a common authority boundary:

```julia
struct ForwardModuleReportV4
    context_hash::Digest256
    module_kind::Symbol
    obligation_hashes::Tuple{Vararg{Digest256}}
    solver_input_hashes::Tuple{Vararg{Digest256}}
    provider_manifest_hashes::Tuple{Vararg{Digest256}}
    artifact_hashes::Tuple{Vararg{Digest256}}
    stage_outcome::StageOutcome
    evidence_class::Symbol
    claim_ceiling::ClaimCeiling
    unresolved::Tuple{Vararg{String}}
    failure_artifact_hash::Union{Nothing,Digest256}
    report_hash::Digest256
end
```

The factory must be private to the owning module and the validator must
recompute every referenced body. `ready` is a plan state, not evidence;
`pass`, `physical_fail`, `numerical_fail`, and `unknown` remain distinct.
Missing provider/capability/materialization paths remain deferred obligations.
No intermediate module may emit terminal `credible_within_scope` or terminal
`unsupported`; only `FinalWholeDeviceAuthorityV4` has that authority.

All evidence-producing modules must use `ProviderManifestV4`,
`SolverInputV4`, and `RuntimeEvidenceV4`. Provider `code_hash` must be derived
from the exact source/dependency lock bytes used for the run. Execution errors
must create a typed, hash-bound failure or unknown report with zero fabricated
metrics. They must not disappear into an exception followed by a missing
result.

Two replay operations must be named and tested separately:

- cache verification: verify that a previously stored input maps to the exact
  stored evidence and artifacts without executing again;
- deterministic rerun: execute with a fresh store, reconstruct the report, and
  compare the declared deterministic hashes and toleranced numerical fields.

Calling `execute_once!` again on the same store proves only cache idempotence.

## Smallest per-module contract

### Multi-region coupling

`MultiRegionCouplingContractV4` must consume `ForwardChainContextV4` and typed
graph references from the exact compiled G1/G2/G3 graphs. The minimum
structural gate is:

- at least two non-empty regions;
- a declared ownership policy under which the relevant graph nodes are covered
  exactly once, with intentional shared/interface nodes represented explicitly;
- typed node/edge references whose canonical identity is checked against the
  compiled graph, rather than bare integer positions;
- at least one interface connecting each coupled region component;
- exactly one auditable `MultiRegionFluxBindingV4` for every declared
  interface conservation channel;
- checked minus/plus orientation, port ownership, ledger identity, physical
  unit, and conservative coefficient pairing;
- explicit field/geometry and realization/control bindings when geometry,
  material, actuator, sensor, or control ownership affects the interface.

An interface with a declared channel and zero flux bindings must be deferred,
never `ready`.

### Multi-region diffusion provider

Keep the current solver as a standalone manufactured model control until it
has a candidate-bound provider plan. That plan must consume the exact validated
multi-region obligation, `ForwardChainContextV4`, a compiled solver input, and
a stable provider manifest. It must additionally:

- bind the selected channel and exact flux pair instead of using only interface
  and region names;
- enforce dimensional relations among coordinate, state, conductivity, source,
  flux, Dirichlet data, and Neumann data;
- validate plan/result/receipt hashes from bodies that exclude their stored
  hashes;
- seal result and receipt construction;
- preserve pass/numerical-fail/unknown/deferred outcomes and failure artifacts;
- implement both cache verification and fresh deterministic replay.

Passing a two-region linear-system fixture would then qualify that narrow
provider only. It would not supply physical evidence.

### Engineering, control, and fault closure

The input factory must require, not optionally accept, the validated context
and the exact required scenario. It must select loads, observations,
actuations, and faults from typed realization/control graph elements and bind
each evidence obligation to an admitted `RuntimeEvidenceV4` or another declared
evidence artifact. In particular:

- compare the candidate contract references to the corresponding registry
  contract references, not unlike wrapper objects;
- validate compiled prefix, subject, scenario, mission, and bounds before any
  engineering decision;
- prohibit a vacuous physical pass when no required physical obligations were
  evaluated;
- replace free-form `evidence_ref` strings with typed artifact identities and
  verify provider, subject, scenario, applicability, and claim ceiling;
- represent unsupported capability as an unresolved stage gap for later final
  authority, while retaining any independent engineering or control failure.

### Validation and uncertainty quantification

`ValidationBindingV4` must be sealed with a truly module-private constructor
token and derived only from the validated context and admitted artifacts. The
factory must use the runtime's actual mission, bounds, scenario, Genome, AST,
and hypergraph identities. The closure validator must enforce:

- each record's declared split agrees with the collection in which it appears;
- calibration and held-out provenance are disjoint and the independence rule
  is explicit, not just an inequality of caller-provided strings;
- each comparison's predicted datum is the exact candidate-bound prediction
  artifact for the same observable, scenario, provider, and result;
- extrapolating or unknown applicability cannot produce `pass`;
- all frozen required scenarios have a result or explicit unknown/deferred
  record;
- manufactured and cross-code controls have zero physical-validation credit;
  model benchmarks and public known-device sentinels do not automatically
  validate a new candidate;
- parameter distributions and all four uncertainty-budget classes use typed,
  finite, unit-aware quantities with checked correlations.

### Gridap B2 convergence

B2 may qualify the accepted B1 manufactured kernel only after every case binds
the exact B1 compilation to the exact G2 `u` and `f` plans used to compute its
norms. Required checks include:

- `canonical_hash(u_plan) == compilation.plan.u_plan_hash` and the equivalent
  `f` check, plus exact root, candidate, prefix, scenario, grid, result, and
  evidence binding;
- common form, geometry, protocol, typed AST semantics, and physical domain
  across the refinement series, with only the declared grid refinement
  changing;
- a mathematically correct scalar/vector AST value-and-Jacobian evaluator,
  tested against analytic derivatives and finite differences;
- one authoritative Gridap solve per case, or an explicit hash proof that a
  second assembly is identical to the B1 assembly and solution being qualified;
- physical-domain L2 and H1 norms, preregistered intervals, and source/boundary
  transfer metrics whose definitions and units are frozen before execution;
- sealed success and failure receipts whose internal case bodies are actually
  recomputed by the validator;
- adversarial mixed-plan, mixed-form, mixed-geometry, wrong-root, derivative,
  non-refining, failed-solve, and tampered-case tests, followed by the pinned
  focused test and runner.

### Gridap B3 evidence

B3 should package the accepted B1 execution under the common evidence path; it
must not create a parallel notion of physical subject or replay. The smallest
safe form must:

- derive the subject's mission and bounds from the validated context (never use
  the mission hash in the bounds field);
- reuse a stable provider manifest whose code hash is computed from the exact
  adapter/B3 source and qualification lock bytes;
- ensure the capability applicability body uses the scenario payload and hash
  consistently;
- produce a complete typed report for pass, numerical failure, and caught
  unknown failure, with all artifacts tied to the same execution;
- validate compilation, subject, input, provider, evidence, report, replay, and
  bundle bodies independently;
- support fresh deterministic replay in addition to same-store cache checks;
- test foreign candidate, prefix, mission, bounds, subject, scenario, provider,
  plan, report, evidence, artifact, code hash, dependency lock, duplicate
  executor, execution failure, and cache-tamper cases.

The evidence and B2 qualification ceilings remain `screen_only`, credible
physical candidate count remains zero, and `p5_ready` remains false.

## Integration order and exit gates

1. Freeze and test `ForwardChainContextV4` against the current three Genome
   contracts, typed ASTs, four compiled graphs, mission, bounds, subject, and
   required scenarios.
2. Repair and accept the multi-region structural contract. Do not attach a
   numerical provider before every declared channel owns an exact typed flux
   pair.
3. Qualify numerical providers independently. B1, B2, and B3 retain their
   accepted isolated `screen_only` scopes; before general forward-stage use,
   connect them to the common envelope and add typed failed-run receipts. The
   diffusion provider remains a standalone model control until candidate-bound.
4. Build engineering/control/fault reports from actual G3 materialization and
   admitted runtime evidence.
5. Admit validation/UQ only on the same physical subject, frozen scenarios,
   independent held-out evidence, and a complete uncertainty budget.
6. Feed accepted module reports into whole-device closure. Only after complete
   terminal closure may `FinalWholeDeviceAuthorityV4` classify the candidate.

For each step, the exit gate is source review, adversarial focused tests,
pinned runner output, relevant RuntimeV4 regressions, and inclusion/export
review. A local unit-test count by itself is not an integration gate.
