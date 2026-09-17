# UP5 early preparation architecture audit

Status: `review_pending`; scope: additive preparation only; claim ceiling:
`contract_only`. Every conclusion and every proposed rule remains `pending`.

## Baseline and authority

The audit was read-only against the dirty checkout at `D:/006-Programing/LMC/FusionConceptAI`.
The current worktree contains pre-existing source, test, documentation and run changes;
they are protected. The authoritative planning inputs are the v4 README, the common
contract, work orders, task manifest, typed AST/e-graph note, architecture decisions and
the current GenomeV5 files. `UP5-01`, `UP5-02` and `UP5-03` are still `planned` in the
manifest and depend on earlier gates. No merge, saturation, QD, MCTS, expansion, solver,
provider or physical execution was performed for this package.

`src/IR/ConditionalEGraphTypes.jl` and `ConditionalEGraphSaturation.jl` provide a bounded
whole-program conditional derivation surface. It has typed LHS/RHS programs, exact sealed
hashes, typed condition references, deterministic ordering, replayable trace steps,
bounded programs/attempts/rounds/trace steps, and explicit `saturation_complete` versus
`saturation_incomplete`. It does not yet provide general production sub-expression
congruence, physics evidence migration, or a QD/MCTS search authority. Existing tests are
software boundary evidence only.

Current GenomeV5 evidence supports the following narrow preparation assumptions:

| layer | observed edit/admission seam | preparation consequence |
|---|---|---|
| G1 | typed equation expression replacement; operator role/arity/rank/unit/temporal/effect checks; occurrence and closure balance | G1 edits must replace a typed expression and revalidate the complete equation, operator binding, occurrence ledger and closure |
| G2 | candidate-bound geometry plan admission; region/interface/exterior ownership and boundary closure checks | G2 edits must preserve region/interface ownership and rebuild plan/package identity; changing geometry evidence is not a semantic rewrite by itself |
| G3 | candidate-bound realization/control bundle; resource, material, manufacturing, ledger, feedback and fault references | G3 edits must rebuild child and bundle identity, retain source record/provenance, and classify missing provider as `terminal_deferred` |
| G3 child edits | closed source body, parent declaration ref/hash, child key and operation history | child editability is an admission precursor; it does not grant provider, engineering, physical or search credit |

## Rewrite audit contract

Every future rewrite record must carry an exact LHS and RHS typed program, rule ref,
rule-set/profile version axes, checker ref/hash, and an explicit condition set. The
condition set must cover, as applicable:

* type, tensor rank, spatial domain and boundary/interface ownership;
* exact unit signatures and conservation-ledger occurrence mapping;
* temporal kind, derivative order, event/delay semantics and time basis;
* operator effects, purity/statefulness/stochasticity and closure accounts;
* coordinate chart/metric/orientation and continuous versus discrete scope;
* exact symbolic, approximate numerical, floating-point and solver-input scope.

The condition is an applicability obligation, not a comment. A condition that cannot be
resolved from candidate-owned authority yields `terminal_deferred`; a contradictory typed
input is `fail_closed`. A proposed rewrite may produce `conditional_equal` only within the
declared scope and replay trace. `equality_unknown` and an incomplete saturation must not
be converted into inequality, novelty, or a permanent prune.

## Semantic scope separation

The planned catalog separates four claims. `exact_symbolic` means an algebraic identity
under declared assumptions. `approx_numeric` means an approximation with a bound and
error model that still requires a numerical checker. `continuous_model` describes a
continuous operator identity. `discrete_model` describes a particular discretization and
mesh/boundary contract. `floating_point` and `solver_input` are narrower still. A rule in
one scope never transfers its equality or evidence to another scope. In particular,
continuous integration by parts does not prove equality of two discrete matrices, and
e-graph membership does not transfer provider, engineering or physical evidence.

## Identity, receipts and invalidation

Any G1/G2/G3 edit or rewrite that changes a semantic field must derive a new candidate
identity. At minimum it invalidates the affected layer hash, genome bundle hash, physical
subject hash, solver-input hashes, proposal/archive memberships whose key includes those
hashes, and all downstream evidence receipts. The old receipts remain immutable historical
records and are not grafted onto the new identity. An e-graph equivalence receipt can only
join the exact source/target typed programs under the same candidate-bound contract and
scope; it cannot preserve physical or engineering credit. Pure canonicalization may retain
the same semantic identity only after checker replay proves that the declared canonical
scope is unchanged.

## Failure and dormant recovery

`terminal_deferred` records a capability or authority gap and enters a capability queue;
it is not physical failure. `numerical_fail`, `unknown`, and `physical_fail` remain scoped
to their executed evidence. A failed candidate may enter an infeasible frontier or dormant
archive with lineage and a repair/edit record. Only a replayable proof certificate bound
to grammar, bounds, mission, prefix semantics and checker revision may create
`proof_pruned`; no soft score, non-convergence, provider gap or incomplete saturation may
permanently delete a candidate or grammar branch. Recovery after provider/grammar upgrade
must recompile and rebuild identity where semantics changed, then issue fresh receipts.

## Authority isolation

Search authority may emit a proposal, estimate cost and request a next stage. It cannot
write EvidenceEnvelope fields, issue terminal dispositions, alter hard gates, or call an
e-graph equality receipt a physical result. Proof authority controls only replayable
permanent-prune certificates. Stage/frontier, Pareto and final whole-device authorities
remain separate. The proposed archive and budget template therefore stores search scores,
behavior cells and execution outcomes in separate fields with no implicit conversion.

## Readiness conclusion

The additive preparation is sufficient to hand UP5 a reviewable rule/edit vocabulary and
budget/authority template. It is not an implementation, a completed UP5 gate, a saturated
e-graph, a broad search, a provider result, or evidence for any parent R01-R10 objective.
The next worker must wait for the UP4/T1/T2/verified-edit/provider gates and independently
freeze exact rule contracts, checker commands and receipts before execution.
