# UP4 early preparation architecture audit

Status: `review_pending` / `preparation_only` / `claim_ceiling=contract_only`.
Every conclusion in this package is `pending`; this package does not perform an
inverse solve, engineering back substitution, provider execution, or closed loop.

## Scope and protected boundary

This audit prepares the inputs and authority contracts for UP4-01 through UP4-04.
It is additive and writes only the files in this directory. It does not modify
`src/`, `test/`, `scripts/`, `runs/`, the v4 planning chapters, the task manifest,
the default/shared registry, historical receipts, or the final package. No Julia,
DESC, provider, mesh, solver, or physical execution was invoked.

The current checkout was read as a dirty worktree. The observed `HEAD` is
`4b69f55f7f80240147a65a22809dc1207824dde2`; this is a baseline observation, not
a clean release claim. Existing dirty edits and historical failure artifacts stay
protected. New candidate, scenario, provider, solver-input, or future candidate
hashes are intentionally absent from this package.

## Sources inspected

The audit followed `AGENTS.md` and the v4 reading order, including:

- `README.md` and `docs/v4_multitopology_generation/README.md`;
- chapters `00`, `05`, `08`, `10`, `12`, `13`, `14`, `16`, and `18`, plus
  `docs/v4_multitopology_generation/task_manifest.json`;
- G3 planning and implementation: `G3 实现—控制Genome.md`,
  `src/GenomeV5/G3/RealizationGenomeV5.jl`, `ControlGenomeV5.jl`,
  `CoupledRealizationControlBindingV2.jl`, and
  `RealizationControlGenomeV5.jl`;
- source/reference slices: `src/RuntimeV4/SpatialMultiRegionV4.jl`,
  `SpatialPickupEngineeringV4.jl`, `N2SourceGeometryProgramV4.jl`,
  `N2SourceGeometryCandidateBindingV4.jl`, `N2SourceFourierZernikeV4.jl`,
  `N2ReferenceInputV4.jl`, and `MagneticEngineeringV4.jl`;
- related tests, `benchmarks/desc_heliotron_v0173/`, relevant `runs/`, and
  prior preparation records under `docs/implementation/`.

## Current architecture and evidence ceiling

The additive G3 V5 contract separates `RealizationGenomeV5`, `ControlGenomeV5`
and `CoupledRealizationControlBindingV2`. Realization owns typed resource ports,
components, material and manufacturing domains, ledgers and closures. Control
owns signals, controllers, faults and control plan. The binding owns
candidate-equal child refs, control/resource links and typed feedback to G1/G2.
The bundle has four version axes, candidate-bound plan hashes, provider match and
an independent `resolution` axis. Structural admission cannot imply provider,
engineering, or physical evidence.

The existing runtime provides useful bounded evidence only:

1. `SpatialMultiRegionV4` is a two-region static ideal-MHD candidate-bound slice
   with cylindrical Q1 discretization, `B_R/B_phi/B_Z/p`, interface/exterior
   terms, and explicit `external_currents_and_outer_sheet_unknown`.
2. `SpatialPickupEngineeringV4` is a fixed circular finite disk and conditional
   ideal RL model. Its declaration fixes a 5 mm radius, 10 turns, a stationary
   coil, static plasma-current contribution, and `induced_emf_V=0`. The ramp is
   prescribed and is not plasma dynamics. Its external coils, outer sheet
   current, total external field, and current closure remain unknown or required
   to be propagated. The implementation requires its exact declaration hash.
3. `N2ReferenceInputV4` binds an existing DESC HELIOTRON artifact and normalized
   result by bytes and source-owned fields, but the test records `screen_only`,
   `inverse_ready=false`, `held_out_prediction_ready=false`, and explicit
   coordinate/basis/source gaps. It is context evidence, not B07B credit.
4. Existing magnetic/control and engineering slices replay declared trajectories
   and ledgers, but their source comments and result guards keep physical
   validation and engineering qualification false or unsupported. A solver exit
   or a deterministic replay cannot promote this ceiling.

The planning contract requires the chain
`target -> finite source -> field -> circuit/power -> thermal/material/structure
-> control/fault -> field feedback`. Design alternatives are existential; all
required operating, fault, cooling, tolerance, start/stop and recovery scenarios
are universal. Missing external coil, return path, material law, cooling, control
fault path, measurement authority, or applicable provider leaves a typed gap.

## UP4 preparation split

`UP4-01` is B07A source-hardware inverse design. It may use a synthetic target
field/source demand, but the target, finite design domain, source/return network,
power, thermal, material, manufacturing and independent forward checker must be
candidate-bound. Its result cannot provide R02 real-reference credit.

`UP4-03` is B07B true-reference hidden-parameter recovery. It requires provenance-
complete reference/experimental/design data, a representation round trip, hidden
parameters withheld from initialization and cache, multiple starts, sensitivity
rank/conditioning, uncertainty, and candidate-independent held-out observations.
Self-generated MMS, synthetic targets, a benchmark label, or an ITER design target
cannot satisfy this branch.

The branches have separate adapters, manifests, split ownership, independence
groups, and evidence envelopes. A B07A source design must never be used to fill a
missing B07B source, hidden answer, or held-out observation.

## Typed pending and binding rules

Every future input field in the JSON templates uses a state-bearing record:
`state` is one of `pending`, `observed`, `verified`, `rejected`, or `absent`; a
`pending` value is always `null` and carries a reason and required authority.
`absent` means the field was explicitly checked and unavailable; it is not a
default. A display label, empty string, historical digest, synthetic digest, or
family default is never a pending identity.

Candidate, scenario, physical subject, solver input, provider manifest, source
dataset, artifact and receipt records must join on exact typed refs and hashes.
Candidate identity changes whenever a G1 equation, G2 geometry/topology/boundary,
G3 source/material/network/control/fault, design alternative, or physical
scenario changes. A normal iteration or state artifact remains bound to that
subject. A missing same-candidate G1/G2 authority ref is a separate
`feedback_authority_gap`; it cannot be cleared by a provider result.

State handling is fail-closed:

| Condition | Required classification |
|---|---|
| typed shape/unit/reference contradiction | `fail_closed` / compile rejection |
| provider missing, ambiguous, out of domain, or invalid signature | `provider_match` gap + `resolution=terminal_deferred` |
| missing source license, version, uncertainty, coordinate or measurement authority | `unknown` + `resolution=terminal_deferred` |
| numerical nonconvergence or rank deficiency within an applicable provider | `numerical_fail` or `unknown`, as applicable |
| applicable material/thermal/structural hard limit violated | `physical_fail` |
| interrupted or absent execution artifact | `human_interruption` / `not_executed` |
| unexpected implementation error | `program_exception` |

Only final whole-device authority may issue a terminal `unsupported` or
`credible_within_scope`; this package issues neither.

## Required handoff gates

The templates remain pending until all of the following are fresh and
candidate-bound:

- UP3-02 composition evidence supplies a valid target/source demand and a field
  forward model; its candidate, scenario and solver-input identities are exact.
- T1 supplies a fresh VNEXT package and integrator; T2 supplies fresh E0/G-I1A/
  E1/E2/UP2 identity and receipt rebinding. The current task manifest lists
  `UP1-04A-VNEXT-T1` and `UP1-04A-VNEXT-T2` as planned prerequisites for this
  preparation lineage.
- UP2-05 supplies an independently reviewed provider manifest, capability
  signature, applicability domain, source revision, environment identity and
  component negative controls. A named backend alone is not a provider.
- B07A or B07B protocol, split, units, coordinate convention, tolerances,
  multi-start budget, uncertainty method, independent checker and artifact
  contract are frozen before result visibility.
- For UP4-02, material/thermal/structure/control providers and all required fault,
  cooling, manufacturing tolerance, start/stop and recovery scenarios are
  resolved. Missing authority remains `terminal_deferred`.
- For UP4-04, the fresh path joins candidate, design alternative, scenario,
  source, solver input, provider, feedback and artifact hashes through one
  versioned execution plan, with a fresh replay receipt. The chain still cannot
  close transport, burn, stability, full plant, or R01–R10 obligations.

## Negative controls that must remain explicit

Before any formal solve, the future checker must reject or defer: static flux
being used as EMF without a time derivative source; a disconnected return path;
infinite current, voltage, power, cooling or actuator capacity; negative passive
resistance/inductance; missing material property domain; wrong normal or handedness;
foreign candidate/provider receipt; duplicated ledger entries; source basis rank
deficiency masked by a controller score; answer leakage into initial guesses or
cache; and removal of cooling, power, feedback or fault scenarios while retaining
the same acceptance claim.

## Decision

The current architecture is suitable for an additive, reviewable UP4 input
package. It is not ready for inverse realization or reference recovery. All
fields in the companion templates are therefore pending unless explicitly marked
as read-only observed context; no result, provider, engineering, physical, B07A,
B07B, R02, R04, R05, or R01–R10 credit is granted.
