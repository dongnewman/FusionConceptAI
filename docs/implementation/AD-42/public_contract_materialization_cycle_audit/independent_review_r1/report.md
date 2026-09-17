# AD-42 public contract materialization cycle audit — independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope and verdict

This review independently checks the AD-42 audit, its proposed W0 and W2R1
work orders, the four historical AD-40 W2 products, the fourteen frozen inputs,
the eleven named sidecars, the preserved failed receipt, and the direct G1/G2
source APIs. The review did not modify AD-42, AD-40, AD-37, AD-39, AD-40 W2
products, core files, source, tests, or the task manifest. No Julia, DESC,
provider, mesh, solver, or physical run was invoked.

The result is `pass_limited` for the architecture-only cycle break and bounded
work-order contract. The proposed direction is acyclic: exact V1 schema/profile
material is upstream of a fresh seed namespace, which is upstream of authoring
payloads and declaration/candidate identity. W2R1 depends on W0; W0 has no
reverse dependency. A public URI or seed derived from payload, declaration, or
final candidate hash remains explicitly forbidden and must fail closed.

This review grants no present, T0, T1, T2, provider, mesh, solver,
engineering, physical, or R01–R10 credit.

## Direct source and type checks

The G1 V1 source `src/GenomeV5/G1/DiffusionDeclarationV1.jl` exposes the V1
schema, canonicalization, and profile hash functions and declares
`G1DiffusionDeclarationV1.candidate_ref::QualifiedRefV1`. It does not contain
the V5 `g1_materialize_contract_ref` API. That V5 API is separately present in
`GrammarProfileV2.jl` and requires a V5 profile/binding domain, so using it for
AD-42 W2 would be a cross-domain contradiction.

The G2 V1 source `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` exposes
`G2MBSourceV1`, the G2MB schema/canonicalization/profile hashes and token, and
keeps its source candidate reference typed as `GenomeContractRef`. The V5
`FieldGeometryGenomeV5` source is separate and carries a downstream
`candidate_hash`; its ref/profile seam cannot be used as the G2MB V1 public
contract. The public `GenomeContractRef` five-field type and
`QualifiedRefV1` type were both rechecked.

The G1 candidate type therefore remains `QualifiedRefV1`, while the G2 source
candidate type remains `GenomeContractRef`. They are not aliases, URI suffix
matches, or reinterpretations. Any future mapping to a common candidate must be
an explicit later binding record with exact typed equality.

## Work-order contract review

W0 has exactly four future products: the G1 envelope, G2 envelope, fresh seed
binding recipe, and materialization receipt. Its inputs, outputs, three-way
result union, dependencies, forbidden edges, exit gates, cleanup policy, and
sidecar policy are all present. Its dependencies are UP1-01/02/03, accepted
AD-40 architecture, and AD-36; it does not depend on old W2 products, AD-37
publication, T0/T1/T2, UP2, provider, mesh, solver, or physical evidence.

W2R1 has exactly four future products with disjoint G1/G2 directories. It
depends on W0 and the stated architecture/input contracts, keeps the old AD-40
W2 products read-only, and enumerates its result union, forbidden reuse and
promotion edges, exit gates, cleanup, and evidence-only sidecar rule. Its
required joins are exact W0 ref equality and same fresh seed-recipe equality;
it does not recompute a public ref from payload bytes. The stated four product
shape is preserved, while payload data is prohibited from sidecars.

The dependency graph has no intrinsic cycle. The only accepted directions are
schema/profile bytes → public contract fields, fresh seed → typed namespace,
public envelope → G2MB source candidate reference, then source/declaration
hashes → later candidate identity. Candidate identity/hash → public URI or seed,
G1 V5 materialization ↔ G1 V1 declaration, and G2 V5 geometry ↔ G2MB V1 are
explicitly forbidden. These are correct fail-closed boundaries.

## Historical evidence closure

The recheck found exactly 14 frozen read-only inputs, 4 historical AD-40 W2
products, and 11 named AD-42 sidecars. Every path exists and its byte count and
SHA-256 match the current AD-42 manifest. The old four products remain typed
`AbsentDeclarationSourceV1`/`terminal_deferred` with typed-absent public refs;
they are not reused as W0/W2R1 inputs.

The earlier AD-42 preflight failure receipt remains preserved with exit code 1,
`program_exception`, its stated pre-append-only cause, and its raw streams.
The later successful static audit remains separately recorded. Future W0/W2R1
product paths were not created.

## Independent run

The independent verifier used `D:\Users\Newman\anaconda3\python.exe`, Python
3.13.5, from `D:\006-Programing\LMC\FusionConceptAI`, PID `30128`, at
`2026-09-15T09:05:24.829982Z`, and exited `0`. It reran JSON parsing, input and
product hash closure, API/type/domain scans, cycle and forbidden-edge checks,
exact work-order file counts, path/scope checks, control-character checks,
sidecar/failure-receipt closure, and claim flags. Raw stdout is
`review/validation_stdout.json` (1061 bytes, SHA-256
`f6e80bd036676f0523e7520b95b751bb780ea3b8e9aff3a04f4dccb3776b948f`); raw
stderr is zero bytes with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Acceptance boundary

`pass_limited` accepts only the AD-42 architecture audit's cycle break and the
finite W0→W2R1 boundary. It does not dispatch either work order and does not
create a public contract, candidate identity, declaration, authority, binding,
factory receipt, or publication record. If implementation cannot derive a
nonfixture envelope from the exact V1 schema/profile material and a new seed,
the required outcome remains typed absence/`terminal_deferred` or
`fail_closed`.
