# AD-39 G1/G2 publication input recovery audit

Date: 2026-09-15  
Scope: read-only recovery audit for `AD37-G1-PRESENT-BASELINE-PUBLISH` and
`AD37-G2-PRESENT-BASELINE-PUBLISH`.

This record answers a narrow question: can the current checkout produce the
fresh, source-backed inputs required by the AD-37 present publication gates?
The answer is no for both layers. The checkout contains versioned declaration
schemas, local factories, focused tests and fixtures, but it does not contain a
non-fixture source record, source byte receipt, fresh candidate binding, four
axis provenance attestations, source-backed factory receipt, or fresh identity
review. G2 also has no source-to-common-`QualifiedRefV1` mapping receipt.

No source, test, fixture, task manifest, core plan, old receipt or runner was
changed by this audit. No Julia, DESC, provider, mesh, solver or physical
command was run. No candidate hash was created and no fixture or historical
authority was promoted. The state remains `present=false`, typed absent/
`terminal_deferred`; T0, T1, T2 and R01-R10 remain false.

## Evidence boundary

The current implementation inputs were read and hashed before this audit. The
G1 declaration is
`src/GenomeV5/G1/DiffusionDeclarationV1.jl`; its source payload and declaration
factories are at lines 229-250 and 365-373, and its contract receipt factory is
at lines 467-499. The code requires a typed `QualifiedRefV1` source, typed
candidate ref, source payload, exact source hash, typed operator chain and a
recomputed declaration hash, but its public admission remains
`terminal_deferred` for missing external authority. All current constructions
are in the focused test and use the fixture candidate/source.

The current G1 fixture is
`test/GenomeV5/G1/diffusion_v1_fixture.json`. It names
`up2-01-g1-fixture`, declares `contract_only`, and explicitly records no
physical evidence. The test constructs the source payload in
`test/GenomeV5/G1/diffusion_v1_contract_tests.jl`; this is a synthetic contract
input and cannot supply source authority, a source locator, a factory receipt,
or provenance.

The G2 declaration is
`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl`. `G2MBSourceV1` and
`g2mb_source_v1` are at lines 354-395, the declaration factory is at lines
513-544, and the receipt factory is at lines 554-590. The current source
requires a v5 `GenomeContractRef`, hashes its typed chart/mesh/faces/units and
authority body, and leaves mesh and boundary authority as gaps when the
fixture uses `no_match`/`not_executed`. It does not emit a mapping receipt to
the common `QualifiedRefV1` domain.

The current G2 fixture is
`test/GenomeV5/G2/metric_boundary_v1_fixture.json`. It is explicitly a fixture
with contract-only ceiling; its mesh is `not_executed` and its mesh/boundary
authority is `no_match`. The focused test constructs it from local values.
Those values can verify the typed contract only and cannot establish a fresh
source locator, factory construction, public candidate authority, or the
required mapping receipt.

The integration boundary confirms the absence. The additive
`src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl` defines the private
source-backed receipt seam and the present binding types, but
`admit_present_parent` still throws `source_backed_receipt_unavailable` and
the only public constructors used by its focused test create
`g1_typed_absent_state`/`g2_typed_absent_state`. The parent binding source is
intentionally not included by the production entry point. AD-33 and AD-37
therefore correctly keep the baseline typed absent.

## Recovered inputs and typed absences

| Required input | G1 current state | G2 current state |
|---|---|---|
| authoritative `source_bytes` and `source_record` | Missing; only source code and fixture JSON exist | Missing; only source code and fixture JSON exist |
| exact source locator | Missing; module/factory names can be proposed from source but are not an attested locator | Missing; same gap |
| candidate/public contract binding | Missing; fixture `QualifiedRefV1` is synthetic and no fresh public binding receipt exists | Missing; fixture `GenomeContractRef` is synthetic and no fresh candidate binding exists |
| four provenance axes | Missing as typed source attestations | Missing as typed source attestations |
| source-backed factory receipt | Missing; current receipt is proposal/terminal deferred | Missing; current receipt is review-pending/terminal deferred with zero calls |
| declaration receipt | Missing as a fresh source-backed receipt | Missing as a fresh source-backed receipt |
| fresh identity review | Missing | Missing |
| `GenomeContractRef` to common `QualifiedRefV1` mapping | G1 adapter/public mapping is still a publication gap | Missing and explicitly required as a separate mapping receipt |
| mesh/boundary authority | Not applicable to G1 | Separate `terminal_deferred` capability gap; publication cannot promote it |

The usable material is therefore limited to read-only schema and factory
recipes. It is sufficient to define an execution plan but not to select a
`PresentBaselinePublicationV1` branch. The only legal current result is a typed
`AbsentBaselinePublicationV1`/`terminal_deferred` outcome; a contradiction
would be `fail_closed`, and an unexpected implementation error would be
`program_exception`.

## Finite production chain for G1

The future G1 publication task may proceed only after fresh external inputs
exist and the AD-36 sidecar policy is accepted. It must consume exactly the
following read-only or newly supplied inputs:

1. `source_bytes.bin` and `source_record.json` from a declared source owner.
   The record must name the locator, byte hash, semantic body hash, source
   version, schema/canonicalization/profile identifiers and the source owner.
   Fixture paths, synthetic labels, copied URI seeds and manufactured values
   are rejected as authority.
2. `candidate_binding.json` containing one fresh candidate/public-contract
   binding. It must bind the G1 `QualifiedRefV1` used by the declaration to the
   fresh public `GenomeContractRef` without suffix matching or URI aliasing.
3. `provenance_axes.json` containing typed records for
   `payload_schema_version`, `canonicalization_profile_version`,
   `applicability_profile_version` and `evidence_receipt_version`, each bound
   to the same candidate/source and attested by its source hash.
4. `factory_receipt.json` recording the module path, module identity,
   declaration type, factory identity, input locator, `source_backed_present`,
   exact candidate binding and declaration-hash recomputation.
5. `fresh_candidate_identity_review.json` recording an independent rebuild of
   the candidate identity and all upstream hashes. It must be fresh for this
   source; it cannot reuse a V1/V4 candidate or historical receipt.

The implementation/production sequence is then: verify raw bytes and record
hashes; parse the source into `G1DiffusionSourcePayloadV1`; construct the typed
`u`, `K`, `f` and operator chain; call `g1_diffusion_declaration_v1`;
recompute `source_hash` and `declaration_hash` from canonical values; compare
the public candidate binding and four axes; construct the source-backed parent
receipt; derive parent-binding, child-key, child-state and receipt hashes;
independently rebuild the fresh candidate identity; and emit exactly one member
of the three-way result union. If any authority/input/provenance item is absent,
emit typed absence with `terminal_deferred`. Do not call compiler, provider,
mesh, solver or physical execution in this publication task.

The future G1 product set is the already frozen AD-37 set: one additive
publication source file, one focused test, one fixture, one static-QA file,
three archive documents and seven typed output records, for 14 product files.
Evidence receipts belong only to task-owned evidence sidecars after AD-36 is
accepted; they never become product records.

## Finite production chain for G2

The future G2 publication task consumes the same five classes of fresh input,
plus `g2_candidate_mapping_receipt.json`. The mapping receipt must record the
exact source `GenomeContractRef` URI/version/schema hash/canonicalization hash/
compatibility profile and the resulting common `QualifiedRefV1` id/version,
the mapping algorithm/profile hash, candidate binding, input/output hashes and
an independent exact-comparison result. URI parsing, copied schema seeds and a
fixture-derived digest are not a mapping receipt.

The production sequence is: verify raw source bytes and source record; parse
the source into the typed chart, mesh plan, six face owners, units, profile and
authority records; construct `G2MBSourceV1` with the exact source hash; call
`g2mb_declaration_v1`; recompute declaration/source/profile hashes; create and
independently check the `GenomeContractRef`→`QualifiedRefV1` mapping; compare
candidate binding and four axes; record the source-backed factory and
declaration receipts; derive parent-binding, child-key, child-state and
receipt hashes; and run a fresh identity review. The declaration may retain
the separate `mesh_authority`/`boundary_authority` `terminal_deferred` gap when
those capabilities are absent. That gap cannot be converted to mesh, provider,
engineering or physical evidence by publication.

The future G2 product set is the already frozen AD-37 14-file set, including a
separate mapping input and mapping result in its declared input/output records.
G1 and G2 publication tasks remain siblings: neither depends on the other,
and neither depends on T0, the authority recheck, T1 or T2.

## Minimum repair order and exit gates

The minimum unblock order is: (1) an external source owner publishes fresh G1
and G2 source bytes/records; (2) a separate identity/binding owner publishes
fresh candidate/public-contract bindings and all four provenance axes; (3) the
factory owner runs the declaration constructors against those exact bytes and
publishes source-backed factory/declaration receipts; (4) a separate G2
mapping owner publishes and independently checks the common-ref mapping; (5) an
independent identity reviewer rebuilds both candidate identities; and only
then (6) a different Luna implements the two AD-37 publication slices under
their frozen exact file ownership. Steps 1-4 can be prepared in parallel by
layer, but the factory receipts depend on the corresponding source/binding
inputs, G2 mapping depends on the fresh G2 public ref, and identity review is
last. Heavy Julia/DESC/provider/mesh/solver/physical execution remains
forbidden in this input-recovery task and is serialized later by UP2 onward.

The publication exit gate is all of: JSON/path/API/static checks; exact raw
source and semantic hashes; source locator and factory receipt; exact candidate
binding; four provenance-axis records; G2 mapping receipt; parent/child/state/
receipt hash rebuild; raw stdout/stderr with PID/UTC/exit and input/output
hashes; direct focused contract test with positive and negative cases;
independent review; and evidence-index registration. A passing document check,
test, or agent exit is not physical or engineering evidence.

Cleanup is restricted to task-owned temporary files created by the future
publication task. Existing dirty files, protected processes, fixtures,
historical failures, old receipts and accepted artifacts remain untouched.

## Decision

AD-39 is a read-only audit and finite production proposal. It finds no usable
fresh source-backed input in the current checkout. G1 and G2 publication remain
`proposed_blocked_external`; AD-37's `PresentBaselinePublicationV1` branch is
not selectable. The minimum next dependencies are fresh source/binding/
provenance packages, source-backed factory receipts, a G2 mapping receipt, and
fresh identity review. The current typed-absence scaffold is the correct
fail-closed state.

