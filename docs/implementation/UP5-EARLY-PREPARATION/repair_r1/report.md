# UP5 early preparation independentR1 repair

Status: `review_pending`; disposition: `changes_requested` repaired in the smallest
package-local scope. No source, test, registry, task manifest or prior review file was
modified. No search, saturation, merge, solver, provider or physical execution was run.

## Closed review findings

1. `C-PURE-LOCAL` is now an explicit applicability condition of
   `RW-EFFECTFUL-NO-CSE`.
2. `C-SAME-METRIC-CHART` is now an explicit applicability condition of
   `RW-EXACT-NEG-SUB`.
3. `RW-EXACT-ADD-ZERO`, `RW-EXACT-MUL-ONE`, `RW-EXACT-ADD-COMMUTE` and
   `RW-EXACT-NEG-SUB` now explicitly require closure preservation, same boundary,
   ledger ownership preservation, oriented boundary preservation and sign/orientation
   preservation. `RW-EXACT-NEG-SUB` additionally retains same metric/chart.
4. The new ownership/orientation conditions are defined in the applicability catalog and
   have explicit negative controls in `rewrite_counterexamples.json`; the four audited
   algebraic rules each have closure/boundary/ownership/orientation counterexample
   coverage.
5. Bare `pending` values in the search budget template's identity, proposal, execution,
   archive and budget fields were changed to typed objects with `state=pending`,
   `value=null`, and a nonempty closed `reason`.
6. Root manifest deliverables, writable paths and validation requirements now include the
   repair records and typed-pending check.

## Remaining boundary

The package remains preparation-only. The repaired conditions are a reviewable contract
catalog, not executed rewrite rules or proof receipts. All conclusions remain pending;
there is no UP5, search, e-graph, provider, engineering, physical or R01-R10 credit.
