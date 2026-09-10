# Runtime V4 end-to-end dependency graph

## Purpose and authority boundary

This is the live integration map for the Julia Runtime V4 path.  The only
upstream design authority is the current three-layer Genome bundle together
with the typed AST, operator hypergraph, registries, frozen mission, bounds,
and scenario declarations.  A downstream adapter may narrow its supported
typed subset, but it may not recover missing semantics from a device name,
family label, candidate identifier, tuple position, or legacy authority.

Every node below has two separate states:

1. **software implementation** -- a typed contract and executable tests exist;
2. **candidate evidence closure** -- real upstream and downstream artifacts for
   the declared scope have been executed and accepted.

The first state never implies the second.  Manufactured controls and test
fixtures remain `screen_only`; they provide no physical validation,
engineering qualification, or credible-device count.

## Dependency graph

```text
G1 mechanism + G2 field/geometry + G3 realization/control
             | typed AST + operator hypergraph + registries
             v
candidate generation / partial compilation / proof-preserving gaps
             |
             v
sealed forward-chain context: three Genome roles + typed graphs +
mission/bounds + candidate-bound subject/scenarios + exact obligations
             |
             +--> trusted repository provider registry
             |    (source/runtime/context attestation + operational receipts;
             |     test fixture plus opt-in fixed FreeGS adapter)
             |
             +--> typed time/event/DAE execution -------------------+
             |                                                       |
             +--> current-G3 observation/controller/actuator graph   |
             |          + fixed repository trust root                |
             |          + deterministic manufactured execution       |
             |                 |                                     |
             |                 v                                     |
             |        operational_screen only                        |
             |        (not engineering evidence)                     |
             |                                                       |
             +--> native static field residual ------------------+  |
             |                                                    |  |
             +--> independent Gridap field residual ------------+|  |
             |          |                                         ||  |
             |          +--> Batch C coordinate-bijective         ||  |
             |               manufactured comparison -------------++  |
             |                                                       |
             +--> typed G2 axisymmetric declaration                 |
                        + candidate/mission/bounds/scenario binding  |
                        + pinned FreeGS execution                    |
                              |                                     |
                              v                                     |
                    physical_model_screen only                      |
                    (not validation or 3-D coupling)                 |
                              |                                     |
                              +--> typed 3-D provider-input compiler |
                                   + G2 geometry/profile ownership   |
                                   + physical-to-region support map   |
                                   + exact-cover multi-region laws    |
                                   + oriented interface + spaces      |
                                   + full-state residual/Jacobian     |
                                   + discretization controls          |
                                   = input_complete (structural only) |
                                   |                                 |
                                   +--> DESC fixed-boundary request compiler
                                   |    + exact convention/control/binding checks
                                   |    = recoverable_gap only; no request emitted
                                   |    + next: verified candidate-bound
                                   |      geometry-proof contract
                                   |    +--> request/result/process: missing
                                   |    +--> pinned real execution: missing
                                   |
                                   v
             typed multi-region ownership + one global non-diagonal residual
             (accepted lumped manufactured control; not a physical provider)
                                      |
                                      v
              real physics providers: equilibrium/stability/transport/
                         reaction/radiation/power and feedback
                                      |
                                      v
                  engineering + control + declared fault scenarios
                                      |
                                      v
                   integrated high-fidelity whole-device execution
                                      |
                    +-----------------+------------------+
                    v                 v                  v
             numerical V&V     physical validation     parameter/UQ
             and cross-code    with held-out data      propagation
             \________________ trusted receipt request ______________/
                        (seven recoverable gaps; zero credit)
                    +-----------------+------------------+
                                      v
                         post-run closure authority
                                      |
                                      v
              scoped minimality/Pareto/search claim over closed evidence
```

## Stable boundary contracts

The next modules shall exchange content-addressed immutable records with these
minimum fields.  Implementations may add fields, but may not weaken them.

| Boundary | Required typed identity and status |
|---|---|
| candidate to physics | candidate/Genome/prefix/mission/bounds/scenario hashes, exact G1/G2/G3 refs, required capability signature, unresolved declarations |
| composed 3-D input to DESC request | exact composition, convention, control, and subject-binding identities; closed canonically ordered gaps; `recoverable_gap` only and no request hash until a verified candidate-bound geometry-proof contract closes the coordinate/Fourier/periodicity/orientation semantics |
| region to region | region and state refs, interface orientation, units, constitutive/transfer operator hashes, source and boundary ownership, conservation pair, applicability and gap status |
| physics to engineering | physical subject, scenario, converged-state/result hashes, loads and observable mappings, material/resource producer hashes, numerical status distinct from physical status |
| G3 to control/fault | observation and actuator refs, controller graph, limits/delay/dropout/fault scenario, recovery requirement, evidence obligations, explicit unavailable capability |
| integrated solve to V&V | one subject and scenario manifest, discretization/time/tolerance protocol, residual/conservation history, provider independence group, transfer and solver errors kept separate |
| validation/UQ to closure | provenance, calibration/validation split, observable mapping, applicability domain, measurement/model/parameter uncertainty, unresolved evidence obligations |
| closure to search | terminal disposition only from final authority, claim ceiling and scope, passed/failed/unknown/unsupported sets, replayable evidence refs; no proposal model authority |

## Integration invariants

- Missing capability or evidence is a recoverable gap and does not become a
  fabricated pass, a physical failure, or permanent pruning.
- `numerical_fail`, `physical_fail`, `unknown`, `terminal_deferred`, and final
  `unsupported` remain distinct.  Only the final authority may issue terminal
  `unsupported` or a credible-device disposition.
- Provider matching uses the full declared capability signature.  Search rank,
  labels, display names, candidate IDs, and topology families are not routing
  inputs.
- A coupled result must execute required off-diagonal/interface terms in the
  same residual or iteration.  Sequential local post-processing is local
  evidence, not integrated closure.
- Independent-code evidence requires different declared assembly or model
  implementations over the same subject.  Cache replay or a different linear
  solver in one assembly is not independent code.
- Numerical V&V, physical-model validation, engineering evidence, control and
  fault evidence, and UQ are separate obligations.  None can substitute for
  another.
- Minimality is reported only inside a frozen grammar, bounds, mission,
  scenario, provider, evidence, and campaign scope, and only over candidates
  whose required closure evidence is present.

## Integration queue

The queue is ordered by the dependency edges it unlocks, not by local test
count.

1. Preserve the accepted isolated Gridap B1/B2/B3 and Batch C
   manufactured-control boundaries plus the sealed forward context; do not
   promote them to physical evidence or aggregate them prematurely.
2. Preserve the accepted candidate-bound FreeGS axisymmetric bridge as a
   separate `physical_model_screen`. Its typed G2 ownership and real pinned
   execution do not supply the 3-D constitutive/interface operators required by
   the accepted multi-region contract.
3. Preserve the accepted opt-in FreeGS registry adapter. Its fixed source and
   runtime attestation plus candidate-bound operational receipt still confer no
   scientific-evidence authority.
4. Preserve the accepted DESC fixed-boundary request compiler as a gap-only
   boundary. The current composition fixture retains its three missing
   declaration/binding gaps; the fully declared manufactured fixture retains
   only the verified-geometry-proof gap. Neither is request-ready.
5. Add a separately reviewed executable candidate-bound geometry-proof
   contract. Only after that proof exists may the compiler emit an execution
   request and may fixed repository-owned result/process contracts plus a
   pinned DESC registry adapter be added. Until then there is no provider
   selection, process execution, solver result, operational receipt, or
   scientific evidence.
6. Connect the candidate-derived 3-D provider result through the accepted
   multi-region execution contract. Preserve the accepted current-G3 trusted
   manufactured control/fault execution as a separate operational screen; the
   lumped diagonal/interface coefficients remain manufactured inputs and have
   no physical credit.
7. Land engineering/control/fault and numerical-V&V/physical-validation/UQ
   obligations on the sealed forward context and trusted provider boundary so
   missing evidence stays visible during early whole-device runs.
8. Replace the present closure firewall with a candidate-bound high-fidelity
   package only after all prerequisite contracts and real provider paths exist.
9. Scale QD/MCTS/campaign search only after the execution and evidence path can
   distinguish closed, failed, unknown, deferred, and unsupported outcomes.

## Legacy reuse rule

Before each implementation batch, inspect the relevant files under
`outputs/fusion_concept_ai/` and record one of `extract`, `wrap`, `test-only`,
or `reject`.  Pure algorithms and negative-test intent may be reimplemented
over Runtime V4 types.  Old Genome/state/authority objects, dictionary stage
chains, candidate-specific preferences, family routing, and historical result
artifacts are rejected from the new core.
