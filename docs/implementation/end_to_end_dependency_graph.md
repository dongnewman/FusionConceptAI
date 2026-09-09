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
candidate-bound physical subject and exact capability obligations
             |
             +--> typed time/event/DAE execution -------------------+
             |                                                       |
             +--> native static field residual ------------------+  |
             |                                                    |  |
             +--> independent Gridap field residual ------------+|  |
                                                                  vv  v
             multi-region block/interface coupling + conservation ledger
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

1. Preserve the accepted isolated Gridap B1/B2/B3 manufactured-control
   boundary and build the Batch C native/Gridap comparison with an explicit
   candidate-bound transfer record.
2. Freeze one validated forward context over the three Genome contracts, typed
   graphs, mission, bounds, subject, scenarios, and capability obligations.
3. Repair and land the minimum typed multi-region interface/conservation contract and the
   minimum engineering/control/fault evidence-obligation contract.
4. Connect one real, declared physical provider through the multi-region
   contract.  Test doubles remain unit-test-only and cannot satisfy integration
   acceptance.
5. Add numerical-V&V and physical-validation/UQ contracts before integrated
   closure so missing evidence stays visible during early whole-device runs.
6. Replace the present closure firewall with a candidate-bound high-fidelity
   package only after all prerequisite contracts and real provider paths exist.
7. Scale QD/MCTS/campaign search only after the execution and evidence path can
   distinguish closed, failed, unknown, deferred, and unsupported outcomes.

## Legacy reuse rule

Before each implementation batch, inspect the relevant files under
`outputs/fusion_concept_ai/` and record one of `extract`, `wrap`, `test-only`,
or `reject`.  Pure algorithms and negative-test intent may be reimplemented
over Runtime V4 types.  Old Genome/state/authority objects, dictionary stage
chains, candidate-specific preferences, family routing, and historical result
artifacts are rejected from the new core.
