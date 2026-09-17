# UP3 CompositionMatcherContractV1 independent review R1

Date: 2026-09-17
Reviewer: different Luna/high, read-only static review
Scope: the additive contract-only composition matcher slice, its dedicated
fixture/static QA, and the exact source/test boundary. Julia/DESC and all
provider/solver execution were intentionally not run.

## Verdict

`NO-GO` for an executable or accepted UP3 slice. The maximum defensible state
is `contract_only`, `preparation_only`, `accepted=false`, with no UP3-01/02/03,
provider, solver, numerical, physical, engineering, or R01-R10 credit.

The dedicated Python static QA passes, but it only checks token presence,
fixture shape, forbidden execution tokens, and zero-count literals. It does not
exercise the matcher semantics.

## Boundary audit

The product files are confined to the intended additive set:

* `src/RuntimeV4/CompositionMatcherContractV1.jl`
* `test/RuntimeV4/composition_matcher_contract_v1_tests.jl`
* `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py`
* `test/RuntimeV4/composition_matcher_contract_v1_fixture.json`

No diff was found in `src/FusionConceptAI.jl`,
`src/RuntimeV4/FusionRuntimeV4.jl`, `Project.toml`, `Manifest.toml`, or
`docs/v4_multitopology_generation/task_manifest.json`. No shared registry or
manifest was changed. This satisfies the requested no-shared-entry boundary,
but it leaves the API unwired: neither package entry point includes the new
source, and the test imports `FusionConceptAI` then expects these names to be
defined/exported. A future executable lane must resolve that wiring in an
explicitly approved boundary; this review does not modify it.

## Findings

### 1. Label and permutation erasure are not implemented — blocker

`semantic_view(CompositionPortContractV1)` includes `port_id`, and
`semantic_view(CompositionComponentContractV1)` includes ordered `inputs` and
`outputs`. `match_composition_contract` hashes the input tuple as-is, and the
plan retains the input component order and labelled edges. Therefore changing
a port/component label or permuting equivalent components/ports changes
`input_hash` and/or `plan_hash`. The README claims label/permutation-independent
identity, but no canonical relabelling or sorted semantic body exists.

The matcher does not route compatibility by name; names are used for duplicate
checks and diagnostics. That is insufficient for the required erasure
invariant because the names remain in the canonical identity.

### 2. Missing/absent dependencies are conflated with `fail_closed` — blocker

`_cmc_validate_component!` pushes failures for `provider_status != :declared`
and `authority_status == :typed_absent`. The final status is then
`:fail_closed` for both provider dropout and typed absence. The project
boundary requires dependency/provider/authority gaps to remain independently
represented as `terminal_deferred`; structural contradiction/invalid typed
input is the `fail_closed` class. The fixture names these negatives but does
not assert their required status or reason separation.

### 3. The Julia test is only a fixture/symbol smoke test — blocker

The test reads JSON and checks nine negative names, two invocation counts, and
`isdefined` symbols. It never constructs a `CapabilitySignatureV4`, typed
ports, components, or a plan; it never invokes `match_composition_contract`
or `validate_composition_match`; and it never checks ambiguity, cycle,
ledger closure, provider dropout, typed absence, label erasure, permutation
erasure, invalid input, or deterministic replay. Consequently the named
negative matrix is declarative only.

### 4. Invalid input is not guaranteed to return a typed fail-closed plan

`match_composition_contract` returns `nothing` when tuple conversion fails and
can reach a `CompositionMatchPlanV1` constructor with non-component tuple
elements after recording `:invalid_component`. That path is not a typed
`fail_closed` result and is untested. The validator also checks only the two
zero counters and `input_hash`; it does not recompute/verify `plan_hash`, status,
edges, topological order, ledger defects, or the complete canonical plan body.

### 5. Hash recipe is incomplete/inconsistent

The builder computes `plan_hash` over a body that excludes `plan_hash`, while
`composition_match_hash(x)` hashes `semantic_view(x)`, which includes the
self-reported `plan_hash`. `validate_composition_match` never checks that the
stored `plan_hash` equals the builder body hash. This permits a stale or
manually altered plan hash to survive validation if the input hash and counters
still match.

### 6. Deterministic order is only partial

Topological node selection sorts digest refs, but edge generation, unresolved
ports, component tuples, and plan hashing follow caller tuple order. Thus the
result is not permutation invariant and independent replay cannot establish
the claimed canonical identity. Ambiguity and cycle detection are present in
the source but have no executed evidence in this slice.

## Static evidence

Command run (the only execution performed):

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
PASS static_qa_composition_matcher_contract_v1
```

No Julia, DESC, provider, mesh, solver, or physical command was run. The
scoped product files are currently untracked; no product/test file was edited
by this review. Current SHA-256 values:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 14024 | `e3a85434a6463c577b53dc1c036197f584bcb06565681ada60e65ed471516ff6` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 1150 | `4439b0eccc144a65994f39a283e7fb5bf54486f57b1e7303bc6b20c67dd3fd14` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 2592 | `4187c07b1a19d0d81722600a8f740c3880991cec588c273e78b7e7d435afcfee` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `docs/implementation/UP3-EARLY-PREPARATION/COMPOSITION-MATCHER-CONTRACT-R1/agent_local_r1/README.md` | 1571 | `77cdd59846b0524d2615d1e722e3981e047f73d721c2e723b19f78e2a3f5d82e` |

## Required repair before any runtime admission

1. Freeze a canonical semantic recipe that explicitly erases labels and
   caller ordering while retaining all typed physical/capability/ledger
   semantics; make `input_hash`, `plan_hash`, and public replay hash use the
   same documented domain-separated recipe.
2. Return a typed plan for every malformed input and separate structural
   `fail_closed` from missing provider/authority `terminal_deferred`, with
   machine-readable reasons.
3. Add real typed constructor/matcher tests for all nine negatives, positive
   provider/solver zero counters, deterministic replay, label erasure,
   permutation erasure, cycle/ambiguity, ledger closure, and invalid-input
   atomic rejection. Do not route by fixture names or expected labels.
4. Resolve package wiring in a separately reviewed boundary, or use an
   explicitly documented isolated loader; the current `using FusionConceptAI`
   test cannot see the new definitions as written.
5. Only after a different-Luna GO should Sol serialize one Julia wrapper run;
   its result must remain contract-only and cannot grant UP3 physics or R
   credit.
