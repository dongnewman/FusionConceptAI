# UP5 early preparation validation report

Status: `accepted_limited`; accepted scope: `early_preparation_template_only`; independentR1
repair is retained and independent R2 is `pass_limited`. Claim ceiling remains
`contract_only`; all formal gates and conclusions outside this scope remain pending.

## Checks performed

The package was checked with read-only PowerShell/static procedures after writing:

1. Strict JSON parsing for the six root catalog/template JSON files, repair manifest and
   status-sync manifest.
2. Unique `rule_id`, `edit_id`, `condition_id`, and `counterexample_id` values.
3. Every counterexample references a catalog rule and every rule condition references a
   condition catalog entry; the R1-added ownership/orientation conditions have negative
   counterexample coverage.
4. The four R1-audited algebraic rules explicitly reference closure, boundary, ownership
   and orientation conditions; `RW-EFFECTFUL-NO-CSE` references `C-PURE-LOCAL` and
   `RW-EXACT-NEG-SUB` references `C-SAME-METRIC-CHART`.
5. Every identity/proposal/execution pending field in the search budget template is a
   typed `{state,pending; value,null; reason,nonempty}` object.
6. Every local path listed as a manifest input exists, with the run directory checked as a
   directory rather than as a fabricated artifact.
7. Every declared pending record follows the typed pending vocabulary where a value is
   present; no future candidate, provider, solver-input or physical-subject hash is used.
   Historical hashes in the pre-existing `independent_review_r1/` record are preserved
   read-only context and are excluded from the future-hash scan.
8. The new diff is confined to `docs/implementation/UP5-EARLY-PREPARATION/`; existing dirty
   files and historical run bytes are protected.
9. No Julia, DESC, mesh, provider, solver, saturation, merge, QD/MCTS campaign, download,
   external write or broad cleanup was performed.
10. Acceptance/status-sync paths and the limited-scope/no-credit vocabulary are present;
    no core/source, old review, registry or task manifest path was changed.

## Expected and observed outcome

| check | result | credit |
|---|---|---|
| JSON syntax | `pass` after static parse (`8/8`, excluding protected review archives) | none |
| identifier uniqueness | `pass` | none |
| rule/condition/counterexample references and R1 coverage | `pass` | none |
| typed search-budget pending fields | `pass` | none |
| local source path inventory | `pass` for paths resolved by the check | none |
| pending/hash boundary | `pass`; no future identity/provider/solver/physical hash | none |
| diff scope | `pass` if the final status shows only this directory | none |
| execution boundary | `not_executed` by design | none |
| accepted scope | `accepted_limited` early-preparation template only | no UP5/R credit |
| UP5-01/02/03 | `pending`/`planned` upstream | none |

These checks validate document structure only. They do not validate a rewrite theorem,
physical model, provider capability, search quality, equivalence saturation, engineering
feasibility or any R01-R10 goal.

The accepted scope does not authorize merge, saturation, broad search, QD/MCTS, pruning or
evidence transfer. Historical hashes in protected review archives remain read-only context.

## Handoff gates

Before formal UP5 work, an independent reviewer must freeze the exact rule source and
checker contracts, verify each LHS/RHS against real typed AST/operator semantics, execute
positive and negative replay cases, and confirm candidate identity/receipt invalidation.
The worker must wait for UP4/T1/T2, verified G1/G2/G3 edit slices and provider gates. A
future campaign must separately freeze proposal/archive/budget manifests, preserve dormant
and failure-frontier candidates, and prove search/evidence authority isolation.
