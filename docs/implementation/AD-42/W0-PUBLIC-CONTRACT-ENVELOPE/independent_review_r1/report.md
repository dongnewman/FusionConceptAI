# AD-42 W0 public-contract envelope independent review R1

Review status: `pass_limited`.

This is an independent, read-only review of `AD42-W0-PUBLIC-CONTRACT-ENVELOPE`. I
read the v4 project contract entry point, the AD-36/37/39/40/42 chain, the four
W0 products, every W0 archive sidecar, the direct `GenomeContractRef` and
`QualifiedRefV1` definitions, and the G1 `DiffusionDeclarationV1` and G2
`MetricBoundaryDeclarationV1` sources. No reviewed file, source file, task
manifest, or prior receipt was changed.

The four and only four W0 product files are present. All four parse as JSON and
are exact UTF-8 lexicographic canonical JSON bytes without a terminal LF. G1
and G2 each expose the exact five `GenomeContractRef` fields: `uri`, `version`,
`schema_hash`, `canonicalization_hash`, and `compatibility_profile`. The G1
candidate namespace remains a `QualifiedRefV1`; the G2 source candidate remains
a five-field `GenomeContractRef`. The recipe explicitly rejects aliasing these
types. The four-axis records are present for both layers; missing evidence
receipt authority is typed absent, and G2 applicability authority is likewise
typed absent where the V1 source has no non-fixture applicability reference.

The public refs and profile material match the direct V1 source domains. The
recorded byte counts and SHA-256 values for
`DiffusionDeclarationV1.jl`, `MetricBoundaryDeclarationV1.jl`,
`GenomeContractRegistry.jl`, and `PhysicalTypes.jl` match the current files.
The direct API scan found the V1 declaration/schema/canonicalization/profile
symbols and both ref type definitions. G1 V1 remains separate from the G1 V5
materializer; G2 metric-boundary V1 remains separate from the G2 V5 geometry
materializer.

The fresh seed commitment is equal across G1, G2, the recipe, and the receipt,
and differs from the AD-40 W2 seed commitment. The recipe records
`payload_or_candidate_hash_dependency=false`, explicitly forbids payload,
declaration, final-candidate, fixture, synthetic, and V5 materializer
dependencies, and the independent checks found no such dependency in the
public URI/profile/seed path. Candidate and declaration hashes are not
created. The result `PresentPublicContractEnvelopeV1` means only software
contract materialization; both envelopes say
`not_source_backed_declaration_authority`, and the receipt keeps present
declaration, T0/T1/T2, provider, mesh, solver, engineering, physical, and
R01–R10 claims false.

The W0 result union is closed over
`PresentPublicContractEnvelopeV1 | AbsentPublicContractEnvelopeV1 |
FailedPublicContractEnvelopeV1`. The original failed materialization receipt
(PID 78508, exit 1, stale AD-36 path) and its stderr remain preserved. The
successful materialization receipt (PID 69780, exit 0) and the 21-check direct
validation receipt (PID 26812, exit 0) have closed raw-stream and product hash
references. The current independent Python 3.13.5 run was PID 37140,
UTC `2026-09-15T09:25:39.211249Z`–`2026-09-15T09:25:39.218535Z`, exit 0;
all 40 independent checks passed. Its raw stdout and zero-byte stderr are in
the review sidecars.

The W0 cleanup inventory is closed: only task-owned temporary launch files were
removed, products and historical failure evidence were preserved, unrelated
dirty files were preserved, and archive contents are evidence-only. AD-36's
accepted-limited evidence-sidecar policy and its status-sync lineage remain
present. AD-37 still records absent source-backed G1/G2 publication inputs;
AD-39/40/42 preserve the downstream preparation boundaries. No W0 evidence
creates source-backed declaration authority, candidate identity, T0/T1/T2,
provider/mesh/solver execution, physical evidence, or R01–R10 credit.

The next legal step is the versioned AD-42 W2R1 fresh-payload authoring work
order. It must independently re-use the W0 public refs and fresh seed recipe
while preserving all typed-absence and fail-closed controls. This review does
not authorize W2R1 execution by itself and does not promote W0 to a source
backed declaration.
