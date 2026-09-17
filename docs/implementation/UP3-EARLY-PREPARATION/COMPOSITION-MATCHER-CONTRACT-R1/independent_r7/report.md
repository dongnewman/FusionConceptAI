# UP3 CompositionMatcher contract R7 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for the R7 contract-only static handoff; NO-GO for runtime or formal UP3
acceptance.** The current R7 source and test satisfy the requested static
checks: the shared `input_schema_hash` is explicit and exact in product
compatibility, composition hash construction and replay use the same semantic
body, tampered stored hashes are rejected as typed fail-closed drift, the
reciprocal cycle fixture is genuinely compatible, and ambiguous/cycle/schema
mismatch cases assert exact failure-code sets.

The ceiling remains `contract_only / prepared`, with `accepted=false` and
`formal_acceptance=false`. No provider, solver, mesh, conservation,
convergence, engineering, physical, B01/B02/B04/B08, or R01-R10 credit is
issued.

## Scope and R6 lineage

Reviewed read-only:

- `src/RuntimeV4/CompositionMatcherContractV1.jl`
- `test/RuntimeV4/composition_matcher_contract_v1_tests.jl`
- `test/RuntimeV4/composition_matcher_contract_v1_fixture.json`
- `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py`
- R6 archive and receipt under `agent_local_r6/` and
  `runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r6/`

R6 receipt: exit `1`, `36 passed, 7 failed`, runtime `11.9` seconds, and
`hashes_unchanged=true`. Its pre/post receipt hashes match the R6 manifest:
source `c5da07f8…e3637e4`, test `1df05362…489f713`, fixture
`62ffa652…357edf`, QA `40358b9a…122ffa`. The R7 manifest hashes match the
current bytes exactly.

No product or test file was changed by this review; only this independent
archive is added. Julia/DESC and all runtime backends were not run. No commit
was created.

## Static findings

### Explicit schema binding remains strict

`_cmc_signature_key` carries `input_schema_hash`, and
`_cmc_signature_compatible` requires exact equality. There is no wildcard,
missing-value, or fallback branch that can erase the shared input schema from
product matching. R7's `_sig` fixture supplies one real canonical schema hash
to both sides by default; `_pair(consumer_input_schema=...)` supplies a
different digest for the schema-mismatch negative. The test asserts
`:fail_closed` and exactly `Set([:unmatched_signature])`.

`CapabilitySignatureV4` is supplied by the isolated `Contracts.jl` include
before the additive matcher include. The matcher imports only package-core
digest/physical/unit/canonical bindings and does not modify the shared entry,
export surface, or registry.

### Composition hash and tamper path

Construction computes `plan_hash = canonical_hash(body)` where `body` is
`_cmc_plan_body(...)`. `semantic_view(::CompositionMatchPlanV1)` reconstructs
that same body, and `composition_match_hash` hashes the semantic view rather
than the stored `plan_hash` field. The positive test asserts equality with the
construction hash. A plan with a tampered stored hash is passed to
`validate_composition_match`; recomputation detects `plan_hash` drift and
returns a `:fail_closed` plan containing `:validation_mismatch`.

### Reciprocal cycle and exact failure sets

The cycle fixture uses `A→B` and `B→A` signatures with shared schema,
dimension, units, space/domain, interface, ledger account/owner/role and
opposite signs. Each component's input is therefore matched by the other
component's output; the graph has two reciprocal edges and no ledger defect.
Topological sorting has no zero-indegree node and emits only `:cycle`.

The ambiguous fixture has two distinct compatible producers for one consumer
input and asserts only `:ambiguous_match`. The schema mismatch fixture asserts
only `:unmatched_signature`; the cycle fixture asserts only `:cycle`.

## Static evidence and next gate

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r7
```

JSON parsing, current-manifest hash comparison, and `git diff --check` also
passed. The next gate is a fresh-process focused Julia test followed by
independent runtime review; static QA and the R6/R7 reports must not be used as
runtime or physical evidence.
