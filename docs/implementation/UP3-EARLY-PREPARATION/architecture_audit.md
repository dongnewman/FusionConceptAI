# UP3 early preparation architecture audit

Status: `review_pending` / `contract_only` / all conclusions `pending`.

This package is an additive preparation artifact for UP3-01 and UP3-02. It does
not create a candidate, execute a provider, compile a mesh, call Julia/DESC,
solve a field, or grant UP3, B, R, physical, engineering, or search credit.
The package is deliberately usable as a reviewable contract before
`UP2-05`, T1, T2, and a fresh candidate exist.

## Audit scope and sources

The audit read `AGENTS.md`, the v4 README, chapters 00, 11, 12, 13, 14, 16
and 18, and `task_manifest.json`. It also inspected current candidate binding,
field-residual, multi-region coupling/diffusion, provider-admission, and
related test/source paths, plus existing `runs/` and implementation archives.
Existing dirty files and historical artifacts were not changed.

The current plan says UP3 consumes actual capability registrations from
UP2-05, generates equations from typed ports and dependency graphs, compares
against analytic or independent discretization oracles, and tests hidden legal
combinations and fail-closed illegal combinations. The current source contains
useful typed coupling records and a bounded two-region diffusion kernel, but
the inspected source/test comments keep the kernel synthetic or screen-only
and leave a real candidate-bound constitutive edge deferred. That distinction
is carried forward here.

## Evidence ceiling and prerequisites

| prerequisite | required evidence | status |
|---|---|---|
| UP2-05 | reviewed provider manifests, capability signatures, component executions and negative controls | `pending` |
| T1 | fresh `CandidateStatePackageV5Next` and integrator with complete declaration identity or typed absence | `pending` |
| T2 | fresh E0/G-I1A/E1/E2/UP2 identity and receipt rebinding for one candidate | `pending` |
| fresh candidate | candidate, genome bundle, physical subject, mission, bounds and scenario identities generated from current source | `pending` |
| environment | candidate-bound environment receipt with versions, source trees, commands and artifacts | `pending` |
| protocol | reviewed split, thresholds, units, solver plan, budgets and checker before result visibility | `pending` |

Old candidate receipts, old provider runs, or historical hashes can be read as
failure/context evidence only. They cannot populate authority fields in a
future UP3 row. Missing authority is typed `terminal_deferred`; contradictory
or foreign identity is `fail_closed`.

## G1 x G2 x G3 capability axes

The product is a bounded campaign of capability cells, not an unbounded
enumeration. A cell is identified by the axes below; an axis is never empty or
a wildcard. A future cell receives a new candidate-bound identity whenever a
declaration, profile, provider, scenario or numerical configuration changes the
physical subject or solver input.

### G1 mechanism/equation axes

| axis | typed content |
|---|---|
| equation family | governing/additive/constraint terms, term ownership, state slots and algebraic/differential order |
| state and port shape | scalar/vector/tensor rank, component order, input/output ports and exclusive ownership |
| operator capability | operators, derivative order, locality, nonlinear dependence, Jacobian slots and derivative support |
| coefficients and source | coefficient fields, spatial/time dependence, source/sink payloads, provenance and units |
| time semantics | static, transient, ramp, event, initial condition and time basis |
| conservation | account identity, owner scope, sign/direction, paired fluxes and source/sink closure |
| nullspace/constraints | gauge, pinning, integral constraint, algebraic closure and solver treatment |
| observables | required outputs, units, error metric, measurement/target distinction and evidence level |

### G2 field/geometry axes

| axis | typed content |
|---|---|
| dimension and chart | dimension, chart map, coordinate order, Jacobian, metric and coordinate units |
| regions and topology | region IDs, connectivity, interfaces, exterior patches and topology graph |
| function space | field space, basis family/order, continuity, component layout and admissible traces |
| mesh and quadrature | cells, refinement sequence, basis/quadrature points and weights, ordering and mesh identity |
| boundary/interface | boundary type/value/source, face ownership, normal orientation, paired traces and interface transfer |
| field/source placement | region of each state/source, coefficient support and external-domain ownership |
| discretization | element block, assembly map, conservative flux map, discrete nullspace and error estimator |
| applicability | geometry/topology, boundary, dimension, time, field and discretization bounds supported by provider |

### G3 realization/control axes

| axis | typed content |
|---|---|
| realization | component/source/coil/driver identity, geometry and material interface |
| resource network | voltage/current/power, source/return, switch/protection and node ownership |
| thermal/material/structure | loss, temperature, cooling boundary, stress/strain/displacement, clearances and material law |
| control | sensors, actuation, sampling, latency, feedback target/path, stability and fault mode |
| ledger | energy/particle/current/heat accounts, owner, sign, direction, conversion and no-duplicate rule |
| scenario | operating, ramp, fault, cooling, manufacturing tolerance, start/stop and recovery cases |
| authority | source provenance, external authority, applicability, uncertainty and evidence receipt |

## Combination cell contract

Every planned cell records the seven dimensions below even when a layer is
typed absent. The absent layer is an explicit gap, never an invented default.

| cell | minimum composition and acceptance intent | current ceiling |
|---|---|---|
| G1 | equation IR, units, closure, analytic/MMS oracle and declared outputs | contract/screen only until provider-bound |
| G2 | chart, metric, mesh/basis/quadrature, boundary and interface ownership | contract/screen only until executable declaration and mesh evidence |
| G3 | source/resource/thermal/structure/control declarations and ledgers | contract/screen only; declaration is not physical closure |
| G1xG2 | typed equation lowering into spatial residual with candidate-bound source/coefficient placement and region/interface conservation | `pending`; requires UP2-05 and fresh candidate |
| G1xG3 | equation source/sink to realization/resource/control ports, per-node and per-account feedback | `pending`; requires source authority and provider |
| G2xG3 | geometry-to-source, material/thermal/structure placement, boundary and control transfer | `pending`; requires geometry/source/engineering providers |
| G1xG2xG3 | jointly generated residual/ports, coupled solve, all ledgers, nominal and required fault scenarios | `pending`; no claim before all applicable gates |

For every cell, retain four separate predicates: declaration legal,
materializable, provider-resolvable, and solver/physical result. Solver exit
cannot promote a missing provider or authority. One cell cannot close a
neighbor with a different topology, boundary, operator, source, material,
control or scenario axis.

## Training, development, validation and held-out isolation

The protocol uses four disjoint roles:

1. **Training/calibration** defines basis, scaling, initial guesses, model
   parameters or surrogate/ROM coefficients.
2. **Development/validation** selects checkers, solver settings, diagnostics
   and threshold confirmation after protocol freeze; it never exposes answers.
3. **Held-out combinations** are selected by combination identity, not by
   changing one scalar in an otherwise identical row. At least one declared
   axis differs in each held-out family: coefficient structure, boundary,
   region connection, topology, source/resource or scenario.
4. **Independent replay** uses a fresh process/environment and frozen
   identities, with no held-out outputs, answer fields or caches.

All artifacts, shots, scenarios, topology graphs, candidate identities, source
records and derived arrays have exactly one split owner. A derived value
inherits the strictest split of every ancestor. Initial guesses, solver cache
keys, feature normalization, mesh/basis construction, labels, failure
classification and oracle answer files are leakage surfaces. Holdout membership,
answer fields and hidden provider outputs remain typed `pending` until T2 and
fresh-candidate review.

## Oracle and parser interfaces

These are templates, not claims that functions already exist.

```text
CompositionInputV1 {
  candidate: CandidateIdentityV1<placeholder>
  physical_subject: PhysicalSubjectIdentityV1<placeholder>
  scenario: ScenarioIdentityV1<placeholder>
  input: SolverInputIdentityV1<placeholder>
  provider: ProviderManifestIdentityV1<placeholder>
  declarations: {g1, g2, g3}
  split: train|development|validation|held_out|replay
}

OracleRequestV1 { input, oracle_kind, units, normalization, tolerance_profile,
                  grid_or_time_sequence, expected_scope }
OracleReceiptV1 { request_identity, status, parse_status, numerical_status,
                  physical_status, residuals, conservation_defect,
                  output_identity, failure_class, claim_ceiling }
```

The placeholder generic means the field is structurally present, has an
explicit type and authority domain, and has `state=pending`, `value=null`.
`null`, an empty string, a historical digest, a display label, or a synthetic
digest is not a valid future hash.

### Parser oracle

`parse_combination(input) -> ParseReceiptV1` canonicalizes typed ports, checks
axis completeness, units, rank, region/interface ownership, source/sink and
ledger closure, and returns stable paths/error codes. It runs before provider
selection and reports compile/provider/solver invocation counts. Legal input is
`ready` only when required obligations are present; missing authority is
`terminal_deferred`; contradiction/foreign identity is `fail_closed`; an
unexpected implementation failure is `program_exception`.

### Analytic/MMS oracle

`evaluate_mms(request, exact_solution) -> MmsReceiptV1` binds exact solution,
source, boundary/initial data, units, grid/time sequence, quadrature,
normalization and asymptotic range. It returns per-level L2/Linf error,
residual, source/boundary identity and observed order. A manufactured fixture
is an oracle/checker input, not real-device physics. Missing exact/source
authority is `terminal_deferred`; nonconvergence or error beyond a frozen gate
is `numerical_fail`.

### Conservation oracle

`evaluate_conservation(request, ledger) -> ConservationReceiptV1` computes
per-node, per-region and per-interface residuals, oriented flux pairs, and each
energy/current/heat/particle account independently. A global sum is diagnostic
only. It detects duplicated source/sink terms, unowned reservoirs, sign
reversal, missing return paths and dimensional mismatch. Missing law/owner/
authority is deferred; contradictory closure is fail-closed; a finite defect
over budget is numerical failure; an applicable law violation after convergence
may be physical failure.

## Reusable current source/test evidence and ceiling

`MultiRegionCouplingContracts` and its tests are reusable for typed
region/interface/flux ownership and fail-closed validation patterns. The
`MultiRegionDiffusionProvider` test demonstrates a two-region analytic kernel
and singular Neumann negative case. Its source comments classify it as a
standalone numerical kernel, and the 3-D integration path retains a real
provider gap. These are preparation references only; they do not populate a
provider manifest, candidate hash, physical subject, or UP3 result.

Existing spatial/DESC runs are historical context and failure-boundary inputs.
They cannot be UP3 held-out, provider or authority evidence.

## Freeze ledger

Can be frozen now: field names, typed outcome vocabulary, axis definitions,
combination-cell taxonomy, split roles, parser/MMS/conservation interface
shapes, negative-case categories, evidence ceiling, and the rule that all
identity placeholders remain absent until a fresh candidate.

Must wait for UP2-05/T1/T2/fresh candidate: concrete provider and environment
identities, candidate/scenario/input/physical-subject hashes, exact module
coverage, mesh/time sequences, oracle implementations, numeric tolerances,
resource quotas, stop values, held-out membership, benchmark counts, and any
pass/fail result. All remain `pending` here.

## Decision

This audit is a preparation artifact only. It is ready for independent Sol
review of structure and boundaries; it does not close UP3-01, UP3-02, UP3-03,
UP2-05, T1, T2, or any R obligation.
