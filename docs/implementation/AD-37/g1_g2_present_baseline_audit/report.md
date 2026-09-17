# AD-37 G1/G2 present-baseline audit

Date: 2026-09-15
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Decision

There is currently no non-fixture, candidate-bound, source-backed G1 or G2 V1
declaration instance, factory construction receipt, or declaration receipt that
can authorize a present parent baseline. The present gate is therefore **NO-GO
for both G1 and G2**. The repository can construct structurally valid typed
declarations from local values in focused tests, but those constructions are
synthetic test inputs and do not prove source authority, candidate binding, or a
fresh declaration receipt.

The AD-33 baseline scaffold is intentionally typed-absent only. Its present
types and private receipt seam define a future gate, but no present value is
constructible through the public paths. T0's authority recheck still emits only
typed absence or deterministic `fail_closed`; T1 is still planned/review_pending
and blocked on T0 plus that recheck. No current result grants implementation,
actual, physical, provider, mesh, solver, engineering, search, B00, B04 or
R01–R10 credit.

This is a read-only source/evidence audit. No core file, V1 source, test,
fixture, baseline scaffold, old receipt, candidate hash, or task manifest was
modified. Julia, DESC, provider, mesh and physical execution were not run.

## Evidence and current state

The inspected project guidance was `AGENTS.md`, the README reading order,
`00_normative_contracts_and_state_model.md`,
`10_genome_upgrade_execution.md`, `14_agent_orchestration.md`,
`16_execution_work_orders.md`, `18_sources_and_architecture_decisions.md` and
the current `task_manifest.json`. The relevant architecture records were
AD-28, AD-30 and AD-33, the AD-33 acceptance/reviews, the baseline scaffold
archive, the T0 transport/recheck contracts and the current V1 slices.

The current V1 bytes were hashed directly during this audit:

| layer | source | focused test | fixture | static QA |
|---|---|---|---|---|
| G1 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |
| G2 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` | `cf7bf40446929bd8c28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` |

The current baseline scaffold bytes are source
`feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`, focused
test `6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`,
fixture `59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`
and static QA `81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`.
The scaffold explicitly states that production can construct only typed absence;
its fixture is expected-only negative/absence data.

### G1

`src/GenomeV5/G1/DiffusionDeclarationV1.jl:269-325` defines a typed
`G1DiffusionDeclarationV1` with a `QualifiedRefV1` candidate, source payload,
source hash, typed `u/K/f` and `GRAD/K_APPLY/DIV` chain. The
`g1_diffusion_declaration_v1` factory at `:364-373` seals a declaration hash
from the local typed body. `g1_diffusion_receipt_v1` at `:467-499` produces a
proposal/`terminal_deferred` contract receipt with zero execution counters, and
`g1_diffusion_authority_check` at `:548-551` remains `terminal_deferred` whether
or not an authority flag is supplied.

The focused test constructs the declaration through `_fixture_declaration` and
asserts source editing, hash tamper rejection, negative controls and missing
authority. The fixture candidate is
`fusionconceptai://GenomeV5/candidate/up2-01-g1-fixture@v5`; it is explicitly a
fixture with `contract_only` ceiling and no physical evidence. No source locator,
raw source byte receipt, four-axis receipt, public contract binding, or factory
construction receipt is present.

### G2

`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:354-395` defines a typed
`G2MBSourceV1` with chart, metric, mesh plan, six face owners, units, authority
markers and a canonical source hash. `G2MBDeclarationV1` and
`g2mb_declaration_v1` at `:513-545` seal the declaration from a
`GenomeContractRef`, source and profile hashes. `g2mb_receipt_v1` at `:554-590`
preserves the structural result but keeps the fixture's missing mesh/boundary
authority as `terminal_deferred`; it does not attest a source-backed factory
construction.

The focused test constructs the declaration from `_fixture_source` and checks
chart/metric algebra, face ownership, unit negatives, fail-closed contradictions,
program-exception separation and deferred authority. The fixture candidate is
`fusionconceptai://GenomeV5/candidate/up2-01-g2-metric-boundary-fixture@v5` as a
`GenomeContractRef`, with fixture schema/canonicalization seeds. The source has
`authority.mesh=no_match` and `authority.boundary=no_match`, and its mesh is
`not_executed`. No source-backed candidate mapping to the common
`QualifiedRefV1`, source locator, raw source receipt, four-axis receipt, or
factory construction receipt exists.

### Direct absence search

The only `SourceBackedV1DeclarationReceiptV1` and
`FactoryConstructionReceiptV1` occurrences are type definitions, private
constructors, tests that assert absence, and historical proposal text. There is
no call site constructing `SourceBackedV1DeclarationReceiptV1(...)`, no
`PresentParentBaselineBindingV1(...)` call, and no source-backed present receipt
archive for either layer. The baseline public admission functions reject
`:fixture`, `:ref_only`, `:synthetic` and `:foreign`; the `:source_backed` path
throws `source_backed_receipt_unavailable` for both layers
(`VNextParentBaselineBindingV1.jl:485-508`).

The baseline focused test ends with `AD33_PBB_PRESENT_AUTHORITY=false` and only
constructs `g1_typed_absent_state`/`g2_typed_absent_state`. The T0 authority
recheck manifest records `present=false`, `typed_absent_terminal_deferred` and
no readable external mapping or four-axis receipt. The T1 work order has no
implementation file and remains `accepted=false`/`review_pending`.

## What repository-only inputs can and cannot prove

Repository code can create a structural declaration object for either layer by
including the V1 file in a focused process and supplying typed local values. It
can recompute the G1 source/declaration hashes, G2 source/declaration/profile
hashes, unit/closure/orientation checks, negative controls and zero execution
counters. The current focused tests demonstrate exactly this contract-only
capability.

That object is not a present source-backed authority record. A fixture JSON,
fixture label, URI, schema seed, self-attested `Digest256`, test exit code,
local constructor call or historical receipt cannot establish the actual source
or candidate identity. The repository currently cannot prove, for either layer:

* that the bytes came from an authoritative source at the recorded locator;
* that the V1 factory consumed those bytes and produced the recorded instance;
* that the instance's candidate is exactly the requested fresh candidate and
  public contract; or
* that all four provenance axes have source records and independently checked
  attestations.

For G2, the `GenomeContractRef` in the fixture also cannot be converted to the
common `QualifiedRefV1` by parsing its URI or reusing its schema seeds. A fresh
mapping receipt is required. G2's structural `no_match` mesh/boundary markers
remain separate deferred capability gaps; a source-backed declaration receipt
would not be mesh or physical evidence.

## Minimum additive publication work orders

The following are proposed, layer-separated work orders. They are publication
prerequisites, not implementation acceptance and not new machine nodes in the
current manifest. Each is parallel to the typed-absence baseline scaffold and
T0; neither imports or edits T0/T1, and neither depends on the other. T1 may
consume their reviewed receipts later, but these work orders do not call or
construct `CandidateStatePackageV5Next`. A changed G1 or G2 source requires a
new candidate identity and fresh downstream receipts.

### G1: `AD37-G1-PRESENT-BASELINE-PUBLISH`

Semantic owner is only the G1 diffusion declaration/source body. The exact
future product files are:

```text
src/GenomeV5/Integration/G1PresentBaselinePublicationV1.jl
test/GenomeV5/Integration/g1_present_baseline_publication_v1_contract_tests.jl
test/GenomeV5/Integration/g1_present_baseline_publication_v1_fixture.json
test/GenomeV5/Integration/static_qa_g1_present_baseline_publication_v1.py
docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/README.md
docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/manifest.json
docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/acceptance.md
```

The fixture is negative/absence-only. The actual input is a fresh, recorded
source-backed input under
`docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/`:
`source_record.json`, `source_bytes.bin`, `candidate_binding.json`,
`provenance_axes.json`, `factory_receipt.json` and
`fresh_candidate_identity_review.json`. If an external authority cannot supply
these bytes/records, the work order must emit typed absence and stop.

The typed input must contain a fresh `QualifiedRefV1` candidate, an exact
`GenomeContractRef` public contract, the G1 `source_ref`/version, the complete
candidate-owned `u/K/f` and operator/closure/applicability body, and a child
contract schema identity. The public contract is checked field by field; no URI
or fixture seed is expanded into a contract. The source locator must contain
module path, module identity, declaration type, factory identity and input
locator. The factory receipt must state `source_backed_present`, exact
candidate binding, exact input locator and `declaration_hash_recomputed=true`.

The publication must recompute and compare:

* raw source SHA-256 over the exact consumed source bytes;
* semantic-body SHA-256 over the complete G1 declaration body used by
  `_g1d_declaration_body`, including candidate/source identity and all typed
  fields;
* the G1 source-content hash over the complete `G1DiffusionSourcePayloadV1`;
* the declaration hash over the declaration body, excluding the hash field
  itself; and
* the parent-binding/child-key/state/receipt hashes in the baseline contract,
  without reusing an old candidate or receipt.

All four provenance slots must be explicit typed records: `payload_schema_version`,
`canonicalization_profile_version`, `applicability_profile_version` and
`evidence_receipt_version`. Each present slot carries candidate ref, source URI
and path, exact value, source-record hash, identity hash, attestation and
verification status. A missing slot is typed absent with an absence-content hash
and `contract_admission=terminal_deferred`; it is never defaulted.

The output is either a source-backed G1 declaration receipt plus
`PresentParentBaselineBindingV1`/present child key, or a complete typed-absent
parent, child key and source state. Present requires exact candidate/public
contract binding, recomputed raw/semantic/source/declaration hashes, all four
present provenance records, a fresh candidate identity review and a readable
factory receipt. It does not grant provider, mesh, solver or physical credit.

Required negative controls are fixture/ref-only/synthetic authority, foreign
candidate or public contract, wrong G1 layer, locator or factory identity
mismatch, raw-byte mutation, semantic projection mutation, source/declaration
hash forgery, missing/conflicting provenance, stale candidate/declaration hash,
wrong units/operator closure, malformed/open body, dynamic or partial edit, and
failed-operation canonical-byte stability. The focused exit gate is static QA,
JSON validation, one direct focused contract process with raw stdout/stderr,
PID/UTC, exit and input/output hashes, followed by a different-Luna review. The
claim ceiling is contract-only and all credit flags stay false.

### G2: `AD37-G2-PRESENT-BASELINE-PUBLISH`

Semantic owner is only the G2 chart/metric/boundary/discretization declaration.
The exact future product files are:

```text
src/GenomeV5/Integration/G2PresentBaselinePublicationV1.jl
test/GenomeV5/Integration/g2_present_baseline_publication_v1_contract_tests.jl
test/GenomeV5/Integration/g2_present_baseline_publication_v1_fixture.json
test/GenomeV5/Integration/static_qa_g2_present_baseline_publication_v1.py
docs/implementation/AD-37/G2-PRESENT-BASELINE-PUBLISH/README.md
docs/implementation/AD-37/G2-PRESENT-BASELINE-PUBLISH/manifest.json
docs/implementation/AD-37/G2-PRESENT-BASELINE-PUBLISH/acceptance.md
```

The fixture remains negative/absence-only. The fresh actual input is under
`docs/implementation/AD-37/G2-PRESENT-BASELINE-PUBLISH/input/` with the same
six records as G1, plus `g2_candidate_mapping_receipt.json` and the complete
chart/metric/mesh-plan/face/unit authority source record. The mapping receipt
must explicitly bind the source `GenomeContractRef` in
`G2MBSourceV1.candidate_ref` to the common fresh `QualifiedRefV1`; parsing the
URI, copying fixture seeds or matching labels is rejected.

The typed input must preserve G2 chart map and domain, metric/orientation,
region/interface/exterior and six face owners, field/flux values, basis,
quadrature, mesh-plan identity, units and applicability profile. The source
locator and factory receipt use the exact G2 module/declaration/factory and
input bytes. The factory receipt has the same three present requirements as G1:
`source_backed_present`, exact candidate binding and independently recomputed
declaration hash.

The publication must recompute and compare raw source SHA-256, the complete G2
semantic source/body hash from `_vnext_t0_g2_source_body`, the G2 source hash,
the declaration hash over `(contract_ref, source, schema_hash,
canonicalization_hash, profile_hash)`, and fresh parent-binding/child-key/state/
receipt hashes. The four provenance slots and their present/typed-absent rules
are identical in vocabulary but owned by G2; they must not be filled from G1 or
from a T0 bundle.

The output is either a source-backed G2 declaration receipt plus present parent
binding/child key, or typed absent state. Structural admission may still report
`terminal_deferred` for missing mesh/boundary authority and `not_executed`; that
status is separate from source-backed construction and never becomes mesh or
physical evidence. Present publication nevertheless requires the source-backed
mapping/locator/hash/four-axis gate and fresh identity review.

Required negative controls are the G1 controls plus wrong G2 contract five-field
mapping, URI/seed aliasing, wrong chart reference, singular or reversed chart,
metric/unit/face orientation mismatch, duplicate or non-closed faces,
mesh-chart mismatch, stale source/declaration/mapping hashes, missing or
conflicting metric/mesh/boundary provenance, `not_executed` versus an invented
mesh result, malformed/open geometry body, and failure byte stability. The
focused exit gate and contract-only credit ceiling are the same as G1; no mesh,
provider or physical command is permitted by this work order.

## Hash, status and downstream boundaries

The six identity layers remain distinct: child contract identity, source record,
source content, initial state, operation and current state. A source-backed
present receipt must carry raw source, semantic body and declaration hashes as
separate fields. The receipt's source locator and factory identity are part of
the parent-binding hash but are not themselves authority.

For either layer, source/authority absence is `typed_absent` plus
`contract_admission=terminal_deferred`; contradictory present data is
`fail_closed`; unexpected implementation faults are `program_exception`.
Absent-to-present is a fresh publication with new source/child/state/candidate
identity review, never CAS promotion and never old-receipt grafting. G1 and G2
remain semantically disjoint: G1 owns the diffusion mechanism/operator/closure
body; G2 owns chart/metric/topology/face/discretization declarations. T0 owns
the later exact three-layer transport, T1 owns lossless mapping into
`CandidateStatePackageV5Next`, and T2 rebuilds downstream identities. None of
those contracts can manufacture the missing source-backed receipt.

## Credits and acceptance ceiling

```text
implementation=false
actual_g1=false
actual_g2=false
physical=false
provider=false
mesh=false
solver=false
engineering=false
search=false
R01-R10=false
B00=false
B04=false
T0=false
T1=false
T2=false
```

AD-37 records only the present-baseline audit and future bounded work-order
surface. It does not dispatch either work order, publish a candidate, alter the
current DAG, or close AD-33's blocker.
