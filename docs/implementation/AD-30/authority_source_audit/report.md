# AD-30 authority-source audit

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Decision

The current checkout has a usable contract-only T0 transport implementation,
but it has no real fresh-candidate authority source that can unblock T0's
same-candidate join. The correct state is `review_pending`, with the following
items `not_found` or `terminal_deferred`:

* a candidate-bound `GenomeContractRef -> QualifiedRefV1` G2 mapping receipt;
* independently readable provenance receipts for the four AD-30 axes;
* a G3 source-content payload/hash; and
* same-candidate realization, control, and binding child sources/identities.

The three V1 fixtures are not one candidate and cannot be joined by URI parsing,
hash seeds, fixture labels, declaration hashes, or a local self-attested digest.
No Julia, DESC, provider, mesh, or physical command was run in this audit.

## Evidence actually present

`QualifiedRefV1` contains only `id` and `version`
(`src/IR/PhysicalTypes.jl:47-55`). `GenomeContractRef` contains `uri`,
`version`, `schema_hash`, `canonicalization_hash`, and
`compatibility_profile` (`src/Contracts/GenomeContractRegistry.jl:3-23`).
There is no conversion relation between these types in the current source.

G1 is a complete typed declaration. `G1DiffusionDeclarationV1` carries
`candidate_ref`, `source_ref`, `source_payload`, `source_hash`, `u`, `K`, `f`,
operator chain, closure/applicability refs, scope, ownership, negative controls,
and `declaration_hash` (`src/GenomeV5/G1/DiffusionDeclarationV1.jl:269-325`).
Its source hash is derived from the complete typed source payload
(`DiffusionDeclarationV1.jl:229-250`), and its declaration body is enumerated at
`DiffusionDeclarationV1.jl:350-359`. This is a local candidate-owned contract
body; the V1 admission still reports missing external authority. The current
source SHA-256 is
`14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`.

G2's source is typed, but its candidate field is a `GenomeContractRef`, not a
`QualifiedRefV1` (`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:354-385`).
The declaration carries contract/schema/canonicalization/profile hashes and a
declaration hash (`MetricBoundaryDeclarationV1.jl:513-552`); source identity is
the canonical hash of chart, mesh, faces, profile, units, authority and source
metadata (`MetricBoundaryDeclarationV1.jl:435-473`). The current fixture/source
candidate is
`fusionconceptai://GenomeV5/candidate/up2-01-g2-metric-boundary-fixture@v5`,
with `candidate-schema-*` and `candidate-canonicalization-*` seeds in
`test/GenomeV5/G2/metric_boundary_v1_fixture.json`. Those seeds are not a
mapping receipt. The current source SHA-256 is
`261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61`.

G3's `G3SFDeclarationV1` carries a `QualifiedRefV1`, source id, owner scope,
typed endpoints/law/ledger/closure, feedback targets, upstream authority and
`declaration_hash` (`src/GenomeV5/G3/G3SourceFeedbackLawV1.jl:267-304`). Its
body hash covers all of those declaration fields, but the type has no source
payload or source-content hash and no realization/control/binding child fields.
The G3 fixture candidate is
`fusionconceptai://candidate/up2-01-g3-source-feedback-v1-proposal-001@v5`;
its default G1/G2 authorities are `missing`
(`test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl:12-65`). The current
source SHA-256 is
`70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0`.

The additive T0 source now defines the required record shapes:
`VNextG2CandidateMappingReceiptV1` has source ref/version, both candidate-ref
types, source-record/source hashes, an `evidence_ref::Digest256`, field path,
attestation, and fixed `external_verification_pending`
(`src/GenomeV5/Integration/VNextDeclarationTransportV1.jl:134-170`). The
`Digest256` field is only an opaque locator; no readable evidence payload is
present in the checkout. `VNextAxisProvenanceV1` requires candidate/source
fields and identity hash for a present axis, but its external verification also
remains pending (`VNextDeclarationTransportV1.jl:68-132`). T0 explicitly stores
G3 source-content hash as `nothing` and three typed-absent child states
(`VNextDeclarationTransportV1.jl:310-340`, `427-432`). Current T0 source SHA-256:
`9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716`.

## Candidate join and four-axis result

| item | exact current source | fields and hash evidence | status |
|---|---|---|---|
| G1 candidate | G1 declaration and fixture above | `QualifiedRefV1`; source/declaration hashes are local typed hashes | `present`, local contract only |
| G2 candidate | `G2MBSourceV1.candidate_ref`, source lines 354-385 | `GenomeContractRef`; source hash exists, but no qualified candidate envelope or external mapping receipt | `not_found`, `terminal_deferred` |
| G3 candidate | G3 declaration lines 267-304 | `QualifiedRefV1`; declaration hash exists; authority defaults missing | `present`, authority deferred |
| exact three-layer join | no current candidate-bound receipt | fixture IDs and candidate refs differ; T0 focused receipts explicitly retain external gaps | `not_found`, `terminal_deferred` |

The four axes are not all declaration-level, candidate-bound values:

| layer | payload schema | canonicalization | applicability | evidence receipt |
|---|---|---|---|---|
| G1 | source constants `G1_DIFFUSION_SCHEMA_VERSION_V1` and body fields (`DiffusionDeclarationV1.jl:9-28,350-356`) | source canonicalization id/hash function (`:30-34,42-44`) | source applicability id/hash (`:35-44`) | no declaration/source receipt version: `not_found` |
| G2 | `G2MB_SCHEMA_VERSION_V1`, declaration `schema_hash` (`MetricBoundaryDeclarationV1.jl:9-12,513-535`) | declaration `canonicalization_hash` and descriptor (`:336-351`) | no applicability axis; profile is not an applicability receipt | `not_found` |
| G3 | `G3_SF_V1_VERSION` and body (`G3SourceFeedbackLawV1.jl:9-27,297-304`) | source canonicalization hash function (`:29-41`) | no applicability axis in declaration | `not_found` |

No current file contains a candidate-bound readable record with the required
`source_uri`, field path, exact axis value, source-record hash, identity hash,
attestation and receipt bytes for all four axes. T0's synthetic/oracle tests and
its opaque `evidence_ref` only prove that missing authority is preserved; they do
not establish provenance.

## G3 source and child result

The G3 V1 declaration has typed feedback target metadata and typed upstream
authority (`G3SourceFeedbackLawV1.jl:72-90,240-277`), but no
`realization_ref`, `control_ref`, `binding_ref`, source payload, or
source-content hash. The separate concrete V5 child types are not evidence for
this G3 V1 candidate: `RealizationGenomeV5` and
`CoupledRealizationControlBindingV2` require their own candidate bindings and
hashes (`src/GenomeV5/G3/RealizationGenomeV5.jl:571-599`,
`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:96-131`). They are not
same-candidate child receipts for the G3 V1 fixture. Therefore all three child
states remain typed absent/`terminal_deferred`, and a G3 declaration hash must
not be renamed as a source-content hash.

## Finite work that can proceed

1. `AD30-AUTH-G2-REBIND` (Luna author; new receipt/archive files under
   `docs/implementation/AD-30/g2_candidate_rebind/`, with no edits to old V5,
   registry, fixtures or historical receipts). Input: a fresh candidate's actual
   G2 source object and readable source/provider receipt. Output: a typed
   mapping record containing both ref types, exact field path, source-record hash,
   source hash, receipt content/hash, candidate identity and provenance. Exit
   only when every field is recomputable from readable bytes; otherwise emit
   typed `terminal_deferred` and preserve the gap.
2. `AD30-AUTH-AXES` (independent Luna reviewer owns a separate archive). Input:
   the same fresh candidate plus source records for each layer and axis. Output:
   four records per layer with exact value, source URI/path, source-record hash,
   identity hash and attestation. Exit requires exact same-candidate binding,
   independent byte/hash recomputation and negative controls for stale,
   conflicting and missing records. Missing applicability/evidence records stay
   `terminal_deferred`.
3. `AD30-AUTH-G3-CHILDREN` (Luna author, only after the source/provider exists).
   Input: same-candidate realization, control and binding source trees/identities
   plus G3 source content. Output: content-hashed child refs and a G3
   source-content hash joined to the feedback law. Exit requires candidate,
   source, child and authority hashes to agree; absent external source remains
   typed absent. This work cannot be completed from the current V1 fixture.
4. `AD30-T0-TRANSPORT-RECHECK` (different Luna reviewer, after 1-3). Input:
   the readable fresh receipts and unchanged T0 source. Output: an additive T0
   transport receipt with rebuilt bundle identity. Exit requires exact joins,
   all axis records, hash round-trips and preserved G3 gaps; it must not enter
   `CandidateStatePackageV5` or alter `default_operator_registry()`.

Local contract work can continue with typed absent/deferred states and editable
source fields. The genuine external blockers are the G2 candidate mapping
authority, applicability/evidence receipt provenance, G3 source-content and
same-candidate child sources, followed by any provider/mesh/solver and
independent physical/engineering evidence. A local test, document, opaque digest,
runner exit code, or declaration hash cannot close those gates or R01-R10.

## Audit boundary

This report is an implementation archive only. It does not change core planning,
source, tests, fixtures, package identities, historical receipts, or task status.
The T0 software precursor remains contract-only and the T1 package remains
blocked pending the fresh source-bound evidence described above.
