# AD-42 W2R1 fresh payload independent review R1

Verdict: `pass_limited`.

The reviewed scope is limited to the software source-authoring canonical slice: four fresh AD-42 W2R1 products, their candidate/source/axis bindings, canonical byte and source-hash closure, negative-control classification, and append-only evidence closure. This review does not grant source-backed declaration authority, factory authority, candidate identity, T0/T1/T2, provider, mesh, solver, engineering, physical, search, or R01–R10 credit.

## Independent run

The review used the delegated Luna reviewer configuration `gpt-5.6-luna/high`, Python `3.13.5` at `D:\Users\Newman\anaconda3\python.exe`, from `D:\006-Programing\LMC\FusionConceptAI`. The direct verifier ran as PID `4360`, UTC `2026-09-15T10:42:13.799105+00:00` to `2026-09-15T10:42:13.809517+00:00`, exit `0`, with `47/47` checks passing. The exact compact JSON result is preserved in [validation_stdout.json](review/validation_stdout.json), SHA-256 `8b9d732b718c109170d677f0757c3ade4e466ea273347f60f9fe80eaf27d18cf`; stderr is the empty raw stream, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The final freeze was taken after the implementer changed the receipt field to `schema_factory_source` and completed closure R2. An earlier observation had G1/G2 receipt hashes `87a8e3fb0fdd678b1e61e80323ddbd8d9864ddc133d50b9b43495d6fedbe64e4` and `acfd61d48a3a97976c0ab0b457b1611e7e46311f3aa74ecd4d8ba109ddad5a2d`; those values were discarded. The final reviewed receipt hashes are G1 `46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210` and G2 `7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`.

## Findings

The four formal products are present in disjoint G1/G2 directories. Both payloads are UTF-8, lexicographically keyed compact JSON with no terminal LF, and their exact bytes match the receipt byte and SHA-256 records. G1 is `CanonicalDeclarationSourceV1` with a `QualifiedRefV1` candidate reference; G2 is `CanonicalDeclarationSourceV1` with a `GenomeContractRef` public contract reference. The payloads share the W0 fresh seed and commitment, and their W0 public contract references match the envelope fields exactly.

The source hashes close between each payload and its final receipt source record, while declaration hashes remain null. Current source bytes and SHA-256 values match both the source record and the renamed `schema_factory_source` record. Direct source inspection found the expected typed source/declaration structures and hash/schema functions in `src/GenomeV5/G1/DiffusionDeclarationV1.jl` and `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl`; the source files are used as repository design/schema sources and are explicitly not candidate authority.

All four axis references and versions match the AD-43 contracts. G2 preserves the distinct `GenomeContractRef` type and its common-candidate mapping remains typed absent with null value. The negative result union is closed: missing candidate/source/attestation binding is `AbsentDeclarationSourceV1`, malformed or mismatched controls are `FailedDeclarationSourceV1`, and unexpected exception is `program_exception`. Both retained seed-mismatch controls are append-only, PID `70232`, exit `1`, `fail_closed`, `product_data=false`, and point to existing raw streams.

Each receipt closes twelve declared output records, including the self-hash-excluded receipt and only task-owned archive sidecars. Every non-self output path, byte count, and SHA-256 matched the current filesystem. Historical AD-40 W2 hashes are recorded as read-only negative controls and are not reused as fresh products or inputs.

All claims are false, candidate identity is not created, declaration hash is null, and nonphysical runtime counters are zero (the only authoring run is the recorded Python materialization). No Julia, provider, mesh, solver, DESC, or physical execution occurred. The final closure therefore supports only `pass_limited` software source authoring and leaves all authority, present declaration, T0/T1/T2, physical, and R01–R10 states false.

The reviewer wrote only this review directory and did not modify the four products, W0, AD-40 history, AD-43 axis records, source, tests, core indexes, or task manifest.
