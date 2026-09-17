# UP5-EARLY-PREPARATION independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Scope: six JSON preparation artifacts, architecture audit, current typed AST/
e-graph/search references, paths and cleanup boundary

## Verdict

`changes_requested`. The package is suitable to retain as an early-preparation
template, but two cross-file condition references and several rule-to-proof
condition gaps must be repaired before it can be treated as a formally frozen
UP5 execution contract. No execution or authority credit is granted.

## What passes

The six JSON artifacts parse successfully. Rule, condition, counterexample and
typed-edit IDs are unique: 12 rules, 18 applicability conditions, 10
counterexamples and 10 typed edits. Every rule condition ID exists globally,
and every counterexample rule and condition ID exists. All listed manifest
inputs and nine declared deliverables exist; package Markdown links have zero
missing targets; scoped `git diff --check` passes; and no task-local
scratch/cache/temp/bytecode file is present.

The rule catalog separates exact symbolic, continuous, discrete and approximate
numeric scopes. It explicitly forbids transferring continuous equality to a
discrete solver input, e-graph equality to physical equality, search score to
evidence, provider gaps to physical failure, and non-convergence to
`proof_pruned`. LHS/RHS entries carry typed-scope conditions for type/rank,
units, domain, boundary/orientation, time/effects, closure and numeric order.
The audit also keeps `equality_unknown`, incomplete saturation and
`terminal_deferred` separate from inequality or permanent pruning.

The G1/G2/G3 edit catalog has ten pending typed edits. Each identifies a read
and write set, preconditions, semantic scope, failure classification and
rebuild list. The identity policy rebuilds affected Genome and bundle hashes,
candidate identity, executed physical/solver identities and downstream
receipts while preserving old bytes/identities/receipts. The audit requires
G1/G2/G3 edits to preserve typed ownership and rebuild child/bundle identity;
dormant recovery recompiles from the new identity and never grafts old
receipts.

The QD/MCTS/search template keeps proposal, archive, execution, proof and final
authority separate. Its forbidden transfers cover search score, e-graph
equality, continuous/discrete equality, provider gaps and non-convergence. The
budget strata, dormant/failure-frontier recovery, proof-prune scope and
`all_fields_pending` boundary are present. No candidate/provider/solver or
physical hash is stored, and merge, saturation, QD, MCTS, search, Julia, DESC,
provider, mesh and solver execution flags are false.

## Blocking contract findings

### 1. Counterexample condition is not an applicability condition

`rewrite_counterexamples.json` records `CX-04` for
`RW-EFFECTFUL-NO-CSE` with `violated_condition=C-PURE-LOCAL`, but that rule
declares only `C-NEVER-AUTOMATIC`. The guard still rejects automatic commoning,
but the counterexample is not testing a condition in the rule's admission set.
Either change the counterexample to the declared guard or add an explicit
effect/purity condition and define its direction for the guard rule.

`CX-07` for `RW-EXACT-NEG-SUB` similarly declares
`violated_condition=C-SAME-METRIC-CHART`, while the rule conditions omit it.
The rule proof obligation mentions sign/orientation, but type/unit/purity/time
conditions alone cannot bind a frame or normal. Add the geometry/orientation
condition (and the appropriate oriented-boundary condition if required), or
rewrite the counterexample against a declared condition.

These are semantic gaps even though simple ID cross-reference validation
passes. They must be resolved in the rule and counterexample catalog before a
checker can claim that every listed negative is admitted by the rule contract.

### 2. Exact rule proof obligations are not all gated

Several exact rules state stronger obligations than their applicability sets
can check:

* `RW-EXACT-ADD-ZERO` requires unchanged root interface, domain, boundary and
  closure, but lists no boundary or closure condition. A typed zero could
  remove a ledger/interface occurrence while satisfying the current type/unit
  conditions.
* `RW-EXACT-MUL-ONE` requires unchanged closure occurrences but has no explicit
  closure-preservation condition.
* `RW-EXACT-ADD-COMMUTE` requires canonical ledger occurrence reordering but
  has no explicit closure/ownership condition.
* `RW-EXACT-NEG-SUB` requires sign/orientation preservation but has no metric,
  frame or oriented-boundary gate, reflected by CX-07.

The minimal repair is to add the missing existing conditions to each rule, or
to narrow the proof obligations so they are exactly represented by the
declared checker inputs. A rule may not rely on prose-only obligations.

### 3. Search archive pending identity fields are not typed pending records

`search_budget_archive_template.json` uses bare strings such as
`"candidate_ref":"pending"`, `"candidate_identity":"pending"`,
`"candidate_or_prefix_ref":"pending"`, and pending strings in proposal and
execution records. They are not concrete hashes, which is correct, but they do
not carry the typed `state=pending`, `value=null`, `reason` form used by the
rewrite/edit catalogs. Before a campaign freeze, these fields should become
typed pending refs with explicit authority/type and null value, including
candidate/prefix, mission, grammar, bounds, seed, proposal, solver-input and
provider identities. This keeps the archive contract aligned with the stated
placeholder rule and prevents a future implementation from treating the word
`pending` as a usable identity.

## Boundary and evidence

The package correctly remains `review_pending`, `preparation_only`,
`accepted=false`, `claim_ceiling=contract_only`, and all conclusions pending.
The architecture audit says current conditional e-graph surfaces and search
tests are bounded references only; no production rewrite list, general
congruence, provider result, physical result or broad-search authority is
claimed. UP5-01/02/03 and UP4/T1/T2/provider gates remain pending/planned.

The package cleanup inventory reports no task-owned scratch/cache and preserves
dirty source, tests, runs, archives and core planning files. This review did
not run Julia, DESC, search, saturation, provider, mesh or solver, and did not
modify any reviewed file.

## Minimal repair and exit gate

Repair ownership is limited to `rewrite_rule_catalog.json`,
`rewrite_counterexamples.json`, and `search_budget_archive_template.json`.
Recompute unique IDs, rule-condition and counterexample-condition bindings,
typed pending records, JSON/path/link checks and scoped diff. Then perform one
new independent review. Until that receipt exists, accept only the existence
of the early-preparation template; UP5/search/physical/engineering and R01-R10
remain pending or false.
