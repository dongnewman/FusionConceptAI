# AD-30 / T0 source-readiness audit

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Decision

**Conditional GO for a contract-only T0 implementation in the new file set.** The
current V1 source files contain enough typed bodies, source identities and local
hash rules to build an additive transport envelope. **NO-GO for treating the
current three fixtures as one joined candidate, for entering the old V5 package,
or for starting T1.** The fixture candidate identities are different, G2 uses a
different candidate-ref type, several AD-30 axes have no declaration-level
provenance, G3 has no realization/control/binding children, and G3 has no source
content hash. T0 must represent those gaps as typed absent/`terminal_deferred`
and must require a newly supplied same-candidate binding envelope; it may not
derive or guess one from fixture labels or hash seeds.

This audit is read-only with respect to source and core contracts. It did not run
Julia, DESC, a provider, a mesh, or a physical calculation. No Julia or DESC
process was present in the process snapshot. The worktree is already dirty: 303
porcelain rows were observed, including existing edits to the core planning
documents, runtime/test files, and many untracked implementation archives. The
T0 worker must preserve all of those rows and edit only the work-order file set.

## Frozen inputs and observed hashes

The current source and test/fixture bytes were hashed directly at audit time:

| layer | source file SHA-256 | focused test SHA-256 | fixture SHA-256 |
|---|---|---|---|
| G1 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| G2 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` |
| G3 | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` | `a5c2874dbcccefd78bae245e8e79e1448f5a712d843699f5fe1d5ad21d3e142e` | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |

The current T0 work order still declares `planned`, `proposal`,
`accepted=false`, `review_pending`, and the restricted write set. Its specified
inputs and file ownership were read from
`docs/v4_multitopology_generation/16_execution_work_orders.md:292-311` and
`task_manifest.json:446-482`. AD-30 is an accepted-limited architecture
boundary only; it does not authorize source execution or physical credit.

## What can be transported losslessly

### G1

`G1DiffusionDeclarationV1` is a concrete typed declaration with
`candidate_ref::QualifiedRefV1`, `source_ref`, `source_version`, a complete
`G1DiffusionSourcePayloadV1`, `source_hash`, typed `u`, `K`, `f`, the typed
`GRAD/K_APPLY/DIV` chain, closure and applicability refs, applicability domain,
ownership and negative controls (`DiffusionDeclarationV1.jl:269-325`). Its
semantic body is explicitly enumerated at lines `350-356`, and its source hash
is the canonical hash of the complete source payload at lines `229-250`.
`g1_diffusion_declaration_hash_v1` exposes the sealed declaration hash.

The fixture/test candidate is
`fusionconceptai://GenomeV5/candidate/up2-01-g1-fixture` / `v5`; the fixture is
descriptive input and is not authority. G1 has no provider/source receipt and
its authority check remains `terminal_deferred`.

### G2

`G2MBSourceV1` preserves source ref/version, chart map and Jacobian, mesh cells,
basis, exact quadrature points/weights, six typed face owners and values, units,
authority and a source hash (`MetricBoundaryDeclarationV1.jl:354-401`). The
declaration body additionally preserves the external contract ref and schema,
canonicalization and profile hashes (`:513-552`). The source admission keeps
mesh execution `not_executed`/deferred when authority is missing
(`:435-475`, `:493-510`).

G2 is the required candidate-binding exception: its source stores
`candidate_ref::GenomeContractRef`, while the G1/G3 declarations use
`QualifiedRefV1`. The current G2 fixture has URI
`fusionconceptai://GenomeV5/candidate/up2-01-g2-metric-boundary-fixture` and
two hash seeds; those seeds are not a lossless `QualifiedRefV1` mapping. T0
must take an explicit typed candidate envelope and verify the exact mapping
against a fresh same-candidate source-bound receipt. It must not parse the URI,
reuse the seed strings, or use the fixture label as the mapping.

### G3

`G3SFDeclarationV1` retains candidate ref, source ID and owner scope, typed
endpoints, source/field/return/heat law, conservative split and heat/ledger
relations, all ledger entries and closure, feedback targets with their typed
authority objects, upstream G1/G2 authority and `declaration_hash`
(`G3SourceFeedbackLawV1.jl:267-330`). `_g3sf_body` is the complete declaration
body used for the declaration hash (`:297-304`); it must be preserved, not
reduced to a ref or to the feedback target list.

The default fixture/test authority is `missing` for G1 and G2, so admission is
proposal/`terminal_deferred`; tests also construct foreign `GenomeContractRef`
values for an `actual`-looking case. Those foreign refs cannot be promoted by
T0. G3 has **no** realization, control or binding child-ref fields at all, and
has no source payload/source-content hash field. T0 must carry three typed absent
child records (realization, control, binding), each with its own
`terminal_deferred` gap, and a typed absent G3 source-content hash. It may retain
the complete declaration-body hash and feedback/authority fields; it may not
rename that body hash as a source hash.

## Four-axis and authority audit

AD-30 requires independent, real provenance for
`payload_schema_version`, `canonicalization_profile_version`,
`applicability_profile_version`, and `evidence_receipt_version`. The current
files do not supply four declaration-level values:

| axis | G1 | G2 | G3 | T0 treatment |
|---|---|---|---|---|
| payload schema | source literal `G1_DIFFUSION_SCHEMA_VERSION_V1`; body carries schema ID/version | `G2MB_SCHEMA_VERSION_V1`; declaration stores `schema_hash` | `G3_SF_V1_VERSION`; body carries schema ID/version | preserve source-backed value plus provenance; exact equality is required |
| canonicalization | source canonicalization ID/hash function; not a four-axis field | declaration stores `canonicalization_hash` and source descriptor | source canonicalization hash function only; not stored in declaration | use only the exact source-backed hash/profile record; no label matching |
| applicability profile | source applicability ID/ref and hash function; declaration has `applicability_ref` | no explicit applicability-profile version/hash; authority/profile are different fields | no explicit applicability-profile version/hash | missing value is typed absent/`terminal_deferred`; never use profile hash as applicability by convention |
| evidence receipt | no evidence-receipt version in declaration or source constants | no evidence-receipt version in declaration or source constants | no evidence-receipt version in declaration or source constants | typed absent/`terminal_deferred` for all current V1 inputs |

The presence of file-local constants is not the same as a candidate-bound axis
receipt. T0 therefore needs a typed axis-provenance record with a source URI,
field/path, exact value/hash, and status. A missing record stays deferred; a
conflicting record is `fail_closed`.

## T0 implementation contract

The unique implementation ownership is:

* `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl`
* one new focused test owned by the same T0 task under
  `test/GenomeV5/Integration/`, recommended name
  `vnext_declaration_transport_v1_tests.jl`
* implementation record under `docs/implementation/UP1-04A-VNEXT-T0/`

No old V5 Genome, `CandidateStatePackageV5`, shared entry, registry, receipt,
candidate hash, or core planning file may be edited. The transport input must
be the three typed V1 declarations plus an explicit G2 candidate-envelope
record and typed four-axis provenance records. The output must be one typed
`VNextDeclarationTransportV1` containing:

1. one exact shared `QualifiedRefV1` fresh-candidate identity;
2. the complete three declaration objects or explicit lossless semantic-body
   projections, together with each source ref/version, available source hash,
   declaration hash and the layer-specific hash recipe;
3. the G2 `GenomeContractRef` plus its explicit `QualifiedRefV1` envelope and
   exact mapping status;
4. all four axis records per layer, including typed absent/deferred entries;
5. the complete G3 feedback and authority state;
6. three typed absent G3 child records and independent deferred gaps; and
7. a canonical bundle hash over full declaration bodies, source/declaration
   identities and hashes, the shared candidate envelope, all four axis records,
   G3 feedback/authority state and child states.

The hash recipes must be independently reproducible using canonical SHA-256
over named immutable values. The layer body recipes are the current source
recipes: G1 `_g1d_declaration_body`, G2 declaration body
`(contract_ref, source, schema_hash, canonicalization_hash, profile_hash)`, and
G3 `_g3sf_body`. T0 may expose local public projections of those recipes, but
must include the entire body and stored hashes in the bundle; hashing only a
ref, fixture JSON, or body-hash list is insufficient. G3's absent source hash
must remain an explicit typed absence.

## Required negative controls and verification gates

The focused test must at minimum cover:

* different G1/G2/G3 candidate refs: exact-join `fail_closed`;
* G2 envelope URI, version, schema/canonical/profile, or candidate hash mismatch:
  `fail_closed`, with no URI parsing or seed alias accepted;
* missing axis provenance: typed `terminal_deferred`, with no default value;
* conflicting axis provenance: `fail_closed`;
* edit of a G1/G2 source field: affected source hash, declaration hash and
  bundle hash all change;
* edit of a G3 ledger/feedback/authority field with stale declaration hash:
  `fail_closed`, proving the complete body is hashed;
* G3 foreign or unattested actual authority: `fail_closed` or independent
  deferred according to the exact contract, never actual credit;
* G3 realization/control/binding child supplied without same-candidate source
  identity: typed absent/`terminal_deferred`;
* G3 source-content hash requested where no source payload exists: typed absent,
  never derived from declaration hash; and
* attempted construction of the old `CandidateStatePackageV5` or registry
  mutation: rejected by type/file-boundary review.

Static gate: inspect only the new file set, `python -m json.tool` on each new
manifest, `git diff --check` on those files, and the plan validator. Focused
gate after implementation: run the new Julia test in one fresh process with
`julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl`,
capture raw stdout/stderr bytes, SHA-256 and exit code, and record the actual
Julia process identity. A passing runner or test remains contract-only; it does
not prove provider, mesh, engineering, physical or R01-R10 completion. A
different Luna must review source, exact hashes, negative controls and receipt
bytes before T1 is eligible.

