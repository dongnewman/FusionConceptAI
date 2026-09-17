# UP3 CompositionMatcherContractV1 independent review R2

Date: 2026-09-17
Reviewer: different Luna/high, read-only static review
Scope: the R2 isolated include, matcher source, executable test source,
fixture and static QA. Julia/DESC were not run and no product/test file was
modified.

## Verdict

**NO-GO.** The source contains a direct construction blocker: `_cmc_plan_body`
calls `_cmc_failure_key`, but no definition exists anywhere in the repository.
As a result, normal plan construction reaches an undefined helper; the catch
path calls `_cmc_error_plan`, which calls the same broken `_cmc_make_plan`
outside a recovery boundary. A typed positive or typed invalid-input result is
therefore not statically runnable as written.

The maximum defensible state is `contract_only`, `preparation_only`,
`accepted=false`. UP3-01/02/03, provider, solver, numerical, physical,
engineering and R01-R10 credit remain false.

## Static evidence and boundary

The permitted static command passes:

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
PASS static_qa_composition_matcher_contract_v1_r2
```

The QA is token/fixture inspection only; it does not import Julia or execute
the matcher. It does not check that every referenced helper is defined.

The test source does contain an isolated module and an executable include call:

```julia
module CompositionMatcherIsolatedV1
using FusionConceptAI
include(joinpath(@__DIR__, "..", "..", "src", "RuntimeV4", "CompositionMatcherContractV1.jl"))
end
```

That is the correct isolated wiring boundary and avoids changing the shared
package entry. However, no runtime evidence proves the include was actually
called in a Julia process in this review. The four R2 product files remain
untracked; no shared entry, registry, manifest or old product was changed.

## Findings

### 1. Undefined failure canonicalizer is a hard blocker

`src/RuntimeV4/CompositionMatcherContractV1.jl:269` evaluates
`_cmc_failure_key(f)`, but `rg` finds only this use and no definition. Both
the positive path and the `_cmc_error_plan` recovery path call
`_cmc_make_plan` → `_cmc_plan_body`, so the intended typed `fail_closed`
invalid-input result cannot be trusted. The static QA required-source list
does not include `_cmc_failure_key`, so it misses this defect.

### 2. Label/permutation canonicalization is present in source but unexecuted

R2 improves the design materially: `_cmc_port_key` excludes `port_id`,
`_cmc_component_key` sorts input/output ports, `_cmc_sorted_components` sorts
components by component identity, and normalized edges omit display port names.
The test source includes renamed labels and a two-input consumer permutation.
These are appropriate static controls. They are not runtime evidence because
Julia was not run, and the undefined failure helper prevents a successful plan
from being established even before comparing hashes.

Component refs and source refs remain typed semantic identity, not display
labels; no separate component display-label field is present. That boundary is
acceptable only if those refs remain true identity fields.

### 3. Provider dropout and typed absence have the intended deferred split,
but are unexecuted

`_cmc_validate_component!` places missing/out-of-domain providers and
`typed_absent` authority into `deferred` rather than `failures`; the final
status maps these gaps to `:terminal_deferred`. Structural unmatched,
ambiguous, cycle and ledger defects map to `:fail_closed`. The test source
asserts both dropout and typed-absent status/reasons. No cold or Julia run
confirms these branches, and the missing helper blocks plan creation.

### 4. Invalid input is intended to be typed fail-closed but remains unproven

The R2 source adds `_cmc_error_plan` for non-iterable and mixed-type inputs,
and the test asserts `match_composition_contract((producer, :not_a_component))`
and `match_composition_contract(nothing)` return `:fail_closed`. Because both
paths eventually call the broken `_cmc_failure_key` route, they do not yet
constitute a working typed rejection contract.

### 5. Validator has the required independent recomputation shape, but no
working evidence

`validate_composition_match` independently calls the matcher over the plan’s
components and compares schema, edges, topological order, unresolved ports and
keys, ledger defects, failures, deferred reasons, status, invocation counts,
input hash and plan hash. It returns a typed fail-closed mismatch plan. The
tampered invocation-count test is present. This is the right static structure,
but it cannot be accepted until the matcher construction path is executable
and a real stale-plan/cold replay is observed.

### 6. The requested cold replay and actual negative execution are absent

There is no subprocess/fresh-process replay, independent runner receipt,
stdout/stderr, exit code, or second-process hash comparison in the R2 test or
archive. The fixture still enumerates exactly nine names and does not include
the invalid-input, validator-drift, or cold-replay obligations. Static token
presence is not evidence that the nine negatives actually executed. Therefore
the requested “9+ negative cases and cold replay actually executed” gate is
open.

## Current hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 19794 | `99264295792b2180204f317e521fe1111ea88fb3686ecd151470f3f7240d106d` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 8057 | `c3a5dadb831df1f6c2a74fe8ffdfd65f1883441a896b7d9a4cf524d519c8fbb3` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 3953 | `62eaf736966f8e245758a665ad14c423dfed23a4b3ccc245e420537416a41365` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |

## Required next gate

Define and test `_cmc_failure_key` (or remove the reference while preserving
canonical failure fields), rerun static QA, then perform one parent-authorized
isolated Julia execution with the nine-plus negative cases and a separate cold
process replay. The replay must compare canonical input/plan hashes, status,
edges/topology/ledger/deferred reasons and zero provider/solver counts. Until
those artifacts exist, no GO and no UP3 execution credit is issued.
