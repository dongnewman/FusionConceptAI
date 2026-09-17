# AD-40 W2 G1/G2 source-payload authoring independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `changes_requested`

## Scope

This review independently checks the four W2 products:

- `RSDA-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json`
- `RSDA-G1-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json`
- `RSDA-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json`
- `RSDA-G2-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json`

The review read the current v4 common contract, README, AD-36 sidecar decision,
AD-37 present-baseline audit, AD-39 publication-input recovery audit, and AD-40
proposal/repair/review chain. It also inspected the public `GenomeContractRef`
and `QualifiedRefV1` definitions and the G1/G2 schema/factory source. No reviewed
file was modified. No Julia, DESC, provider, mesh, solver or physical execution
was run.

## Independent result

The four products are present with exactly two product files per layer and only
archive evidence sidecars underneath each authoring directory. Both layers use
the same authoring run id, seed, seed commitment, PID and UTC interval. Receipt
payload bytes/SHA values and schema/factory source bytes/SHA values recompute
correctly. The source and payload roles are kept separate. The negative controls
for a missing axis, fixture path, foreign layer, extra whitespace and seed
mismatch all reject as expected.

The exact canonical-byte gate does not pass. The declared profile says
`UTF-8 LF JSON; named keys lexicographic; no insignificant whitespace`; the
repository canonical JSON emitters also produce bytes without a terminal line
feed. Both payload files contain one terminal LF. After stripping only that
terminal LF, the bytes equal the independently recomputed sorted compact JSON;
the exact raw bytes do not. The authoring receipt's `canonical_bytes_recompute`
field therefore overstates the check and needs a repair: either remove the
terminal LF from both payload products, or amend and independently re-accept the
canonicalization profile so that a terminal LF is explicitly part of the bytes.
The current proposal's `no insignificant whitespace` wording makes removal the
consistent repair.

## Authority and typed outcomes

Both payloads correctly state `AbsentDeclarationSourceV1` and
`terminal_deferred`, with `public_genome_contract_ref.status=typed_absent`, no
candidate identity/hash, and the terminal reason
`no_fresh_public_GenomeContractRef_or_source_authority`. The G1 source contains
typed `QualifiedRefV1` declaration APIs but no concrete public
`GenomeContractRef` instance. The G2 source keeps its source candidate contract
typed as `GenomeContractRef`; the payload likewise preserves that type and does
not alias it to `QualifiedRefV1`. The four axis slots exist in both payloads;
the evidence axis is explicitly typed absent, and G2 applicability is also
typed absent because no non-fixture applicability profile exists.

The current source hashes are G1
`14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` for
`src/GenomeV5/G1/DiffusionDeclarationV1.jl` (31,743 bytes) and G2
`261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` for
`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` (30,773 bytes). These are
schema/factory source receipts only and are not candidate authority.

AD-36 is currently accepted-limited for sidecar scope, while AD-37 still has
`present_g1=false` and `present_g2=false`; AD-40 remains architecture-only with
`present=false`, `candidate_hash_created=false` and `machine_node_created=false`.
This review creates no authority record, binding, factory receipt, candidate
identity, T0/T1/T2 output, provider/mesh/solver result, engineering or physical
evidence, or R01–R10 credit.

## Evidence and cleanup

The independent verifier was run with `D:\Users\Newman\anaconda3\python.exe`
(Python 3.13.5), PID `63808`, from the repository root, and exited `0` as a
review process. Its structured raw stdout is archived at
`archive/validation_stdout.json` (3,345 bytes, SHA-256
`b7405fe74d56a32be907b6f7f2bdfd342cc903d70e998ed0497afe2235b2bb1a`); stderr
is the zero-byte `archive/validation_stderr.txt` with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The machine-readable receipt records every check, product hash, source hash,
PID, UTC, interpreter, result and claim ceiling.

The exact review-owned files are this report, its manifest, and the two raw
sidecars under `archive/`. No source, test, fixture, launcher, product payload,
historical receipt or unrelated dirty file was changed or removed.

## Acceptance boundary

This review recognizes a semantically correct typed-absence authoring attempt
and the exposed absence of fresh non-fixture public contract/source authority.
It does not accept the W2 authoring products because the exact canonical-byte
gate and its corresponding negative control are not closed. A repair must be
append-only, rerun the exact-byte check and negative controls, and receive a
new different-Luna review. Even after that repair, acceptance can only cover
the W2 typed-absence authoring slice; it cannot promote software present,
authority, candidate identity, binding, factory, T0/T1/T2, UP2, provider, mesh,
solver, engineering, physical or R01–R10 evidence.
