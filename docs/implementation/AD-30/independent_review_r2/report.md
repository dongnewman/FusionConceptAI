# AD-30 independent architecture review R2

## Verdict

Overall: `pass_limited`; `accepted=false`; `review_pending=true`.

The R2 addendum closes the R1 contract omissions at the architecture level. A
Sol/root acceptance is supportable only as a finite `accepted_limited`
architecture and evidence boundary for AD-30. It does not authorize T0/T1/T2
implementation, source edits, provider or mesh execution, physical execution,
search, or any parent-goal/R01-R10 credit.

The V1 declarations remain a lossless transport problem rather than a coercion
problem. G1 stores the candidate-owned `u`, `K`, `f`, typed operator chain,
source payload/hash and closure/applicability (`src/GenomeV5/G1/DiffusionDeclarationV1.jl:269-325`); its canonical declaration body includes those
fields (`:350-359`). G2 stores its chart, mesh, faces, profile, units and
authority in a source body with a source hash (`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:354-401`), and its declaration adds schema,
canonicalization, profile and declaration hashes (`:513-535`). G3 stores
source/field/return/heat law, ledger closure and feedback targets with
authority (`src/GenomeV5/G3/G3SourceFeedbackLawV1.jl:240-277`); its declaration
body covers the complete law/ledger/feedback content and seals one
`declaration_hash` (`:297-329`). These fields cannot be represented by a
ref-only projection into the existing package.

## R2 contract checks

| obligation | R2 result | evidence and implementation boundary |
|---|---|---|
| Same-candidate source/content/declaration join | `pass_limited` | The core contract and proposal require one fresh `QualifiedRefV1`, exact equality, preservation of source payload/content and declaration hashes, and recomputation on rebinding/edit (`18_sources_and_architecture_decisions.md:294-296`; `proposal.md:20-22`). The existing G2 V1 field is a `GenomeContractRef`, not a candidate `QualifiedRefV1` (`MetricBoundaryDeclarationV1.jl:354-371`), so T0 must use an explicit typed transport candidate-binding envelope and compare that source ref; it must not reinterpret the G2 contract ref as candidate identity. |
| Canonical bundle recipe | `pass_limited` | R2 requires a hash over the three complete semantic bodies, source/declaration identity, candidate ref, four axes and child/feedback states. This is sufficient to prevent a ref-only hash. G1/G3 source declarations have distinct available hash shapes; G3 has only the complete-body `declaration_hash`, so T0 must preserve that as the declaration/content hash and must not invent a second source hash. |
| Four axes, equality and invalidation | `pass_limited` | R2 names `payload_schema_version`, `canonicalization_profile_version`, `applicability_profile_version`, and `evidence_receipt_version`; it requires per-layer exact equality, missing axis as `terminal_deferred`, and conflict as `fail_closed` (`18_sources_and_architecture_decisions.md:296`; `proposal.md:20`). None of the three V1 declaration structs carries this four-axis tuple; T0 therefore must carry it as separately sourced typed transport data and defer when that source is absent. V1 schema/canonical/profile constants or defaults cannot silently fill it. |
| G3 absent children and feedback authority | `pass_limited` | R2 explicitly marks missing realization/control/binding children typed-absent with independent `terminal_deferred`, and retains feedback target path/quantity/unit/direction/sign/source ID and authority status/ref/hash/attestation. Wrong same-candidate target refs fail closed and unauthenticated `actual` fails as `unattested_authority` (`18_sources_and_architecture_decisions.md:288,296`; `G3SourceFeedbackLawV1.jl:72-100,240-265`). |
| T1 package and full hash | `pass_limited` | `CandidateStatePackageV5Next` is specified as the AD-19 additive successor; its hash covers candidate ref, complete declarations, source/declaration/bundle identity, axes, child/feedback state and its own schema/canonical/profile hashes (`18_sources_and_architecture_decisions.md:300`; `proposal.md:24`). This is materially stronger than the old package hash, which covers only old package identity, axes and migration receipt (`CandidateStatePackageV5.jl:219-226`). |
| Fresh and legacy migration | `pass_limited` | R2 requires a fresh no-legacy pending/typed-deferred record without fabricated mapping, while legacy input requires complete before/after refs/hashes, axes, field mapping, identity rebuild, algorithm revision and provenance (`18_sources_and_architecture_decisions.md:302`; AD-19 acceptance). |
| Old V5, package, receipts and registry | `pass` | Existing integration hard-checks the three concrete types (`GenomeV5Integration.jl:133-147`), and the old package repeats those checks (`CandidateStatePackageV5.jl:201-216`). R2 keeps both read-only, forbids the shared-entry/ref-only path, and forbids changes to `default_operator_registry()` (`18_sources_and_architecture_decisions.md:298,302`). |
| T2, B00/B04 gate and parent obligations | `pass` | R2 requires new E0/G-I1A/E1/E2/UP2 identities bound to the same fresh candidate and all hashes/axes/authority state, then independent review before formal B00 F0-F5, 50 B04 receipts, checker and two-process replay (`18_sources_and_architecture_decisions.md:304,309-312`). It explicitly preserves UP0-UP6 and R01-R10 and grants no execution or physical credit. |

The old integration makes the read-only boundary concrete: it hard-checks the
three concrete layer types and records a mismatch as structural failure rather
than accepting a declaration adapter (`GenomeV5Integration.jl:277-340`),
and its existing identity checks operate on old component hashes, old refs,
old axes, child refs and feedback projections (`:149-191,202-217`). This
supports the R2 choice of a new package/integrator rather than an adapter that
silently drops V1 semantics.

## Residual conditions on any implementation

These are explicit implementation exit conditions, not permission to weaken
the accepted boundary:

1. T0 must define the typed wrapper that joins G2's `GenomeContractRef` source
   to the fresh candidate `QualifiedRefV1`; absence or ambiguity remains
   `terminal_deferred`, and mismatch is `fail_closed`.
2. T0 must provide an auditable source for every four-axis value. The V1
   declarations expose layer-specific schema/canonical/profile descriptors but
   no evidence-receipt axis; deriving the fourth axis from a default or label is
   invalid.
3. T0 must preserve G3's complete declaration-body hash as its available
   source/content evidence. It must not claim a separate source hash unless a
   new, content-hashed source object is actually supplied.

Until those conditions are implemented and independently checked, AD-30 stays
`review_pending`/`accepted=false`. Missing source authority, axes or children
must remain typed `terminal_deferred`; structural contradictions remain
`fail_closed`.

## Validation, hashes and dirty-work protection

The current checkout remains `HEAD=4b69f55f7f80240147a65a22809dc1207824dde2`.
The R2 core and proposal hashes match the repair record exactly:

- `18_sources_and_architecture_decisions.md`: 56,742 bytes,
  `d913df0b895764d5d31e5c5d81acf06aeb5acef5d01e6c9f941b14f93416ccd6`.
- `AD-30/proposal.md`: 5,030 bytes,
  `b5d7f1d8fd1f781e26994e0b6253065ce560050a314663afb778b0949165b7c8`.

The reviewed source hashes also match the R1 evidence for G1, G2, G3,
integration and the old package. `python -m json.tool` on the R2 repair
manifest exited `0`; `validate_plan.py` exited `0` with 31 markdown files, 363
relative links, 31 tasks and an acyclic DAG. No Julia, DESC, provider, mesh or
physical command was run.

The repair snapshot recorded 3,914 dirty entries and status SHA256
`50f0745b64910c2d2ea273a6ed0f22ca7c832b5068573dd71e36f5ffd293ba3d`; the
independent review's pre-write snapshot has 3,929 entries and status SHA256
`9e3b472f311c329f9fee0b9d07efce3e9288ad8b4461b7af1a83b6c113e0385e`. This is
concurrent dirty-work drift, not evidence of a core/source edit by this
review. Only the new `independent_review_r2` evidence directory is written by
this review.

All credits remain false: no B00/B04, provider, mesh, engineering, physical,
search or R01-R10 credit.
