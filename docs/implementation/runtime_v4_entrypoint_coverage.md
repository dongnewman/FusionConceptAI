# RuntimeV4 entry-point and test-coverage inventory

This is the first-stage W02 integration audit. It is a deterministic static
inventory of the current checkout, not an integration implementation and not
a Julia execution result. The machine-readable result is
`runs/goal_recovery_20260913_012528_cst/runtime_v4_coverage.json`.

## Reproduction

From the repository root:

```text
python scripts/audit_runtime_v4_test_coverage.py --output runs/goal_recovery_20260913_012528_cst/runtime_v4_coverage.json
```

The auditor records `git rev-parse HEAD`, the dirty-state warning, tracked vs
untracked status, canonical repository-relative paths, stable literal include
edges, unresolved/dynamic include expressions, and reachability from these
roots: `src/FusionConceptAI.jl`, `src/RuntimeV4/FusionRuntimeV4.jl`,
`test/runtests.jl`, `examples/runtime_v4_spatial_candidate.jl`, and
`scripts/run_v4_spatial_chain.jl`. A nonzero process status is reserved for
parser/internal consistency errors; expected missing coverage is data in the
report and is not converted into a false failure.

## Observed boundaries

The package entrypoint includes the established IR, genome, canonical and
contract layers. It does not, by a literal include edge in this checkout,
import `src/RuntimeV4/FusionRuntimeV4.jl`; that module has its own literal
include tree under `src/RuntimeV4/`. The RuntimeV4 root consequently has a
distinct contract/compiler/capability/execution/search/archive/residual and
whole-device tree. The inventory does not infer a production aggregation
between these two roots.

The spatial example first loads the revised candidate and then loads RuntimeV4
source files through `Base.include` using a computed source name. The spatial
runner includes the example, performs its staged calls, and later executes
`Base.include(SCV, joinpath(SPATIAL_REPO, "src", "RuntimeV4",
"SpatialWholeDeviceV4.jl"))`. This is the recorded world-age-prone loading
path. The computed expressions are explicitly retained as dynamic/unresolved
edges. Recording this order is factual; it does not prove that world age is
the cause of any later behavior, nor that any included module executed
successfully.

The current checkout is dirty and contains unrelated pre-existing changes.
The JSON is therefore tied to the recorded commit plus the working-tree
warning and status entries. It should be regenerated after material checkout
changes before using it as an audit input.

## Coverage interpretation and proposed layering

The existing package assertion count (2631 in the current progress material)
is not RuntimeV4 total coverage. Likewise, parsing `include`/`Base.include`
provides a load-edge inventory only; it is not evidence of module execution,
provider success, solver convergence, scientific validity, or acceptance.

For main-line review, the production/test split should be kept explicit:

1. **Fast contract/numerics:** a stable package-facing RuntimeV4 production
   entrypoint and focused deterministic tests for typed contracts, canonical
   payloads, residual/numerical helpers, and negative invariants.
2. **Provider integration:** opt-in tests and runners for provider/adaptor
   loading, process identity, artifacts, and receipt/replay checks. These
   must not be silently promoted into every default unit-test run.
3. **Real scientific benchmark:** separately named, bounded runs with pinned
   inputs and scientific artifacts; the runner must report its actual process
   exit and scientific classification.
4. **Final acceptance:** whole-device/authority checks consuming the preceding
   evidence. Static reachability, a green package suite, or a provider receipt
   cannot grant this tier.

The second-stage implementation should decide and document one production
entrypoint that owns the loading order, rather than requiring users to run
multiple examples manually. It should also add an explicit test manifest or
registry mapping each RuntimeV4 module to the appropriate layer, while
preserving opt-in boundaries for provider and scientific runs. This audit
intentionally does not modify those aggregators, Julia modules, or tests.

## Acceptance status

The requested first-stage artifact exists and is generated from the current
checkout. No Julia, DESC, package regression, or scientific benchmark command
was run by this worker. R01/R10 remain parent-level requirements and are not
accepted by this inventory.
