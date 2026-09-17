# AD-40 W2 G1/G2 source-payload authoring independent review R2

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope

This review is an independent recheck of the R1 finding
`AD40-W2-R1-CANONICAL-TERMINAL-LF` after the layer-owned `repair_r1`. It reads
the four current W2 products, both repair manifests and their raw sidecars, the
R1 report/manifest and raw receipts, and the current AD-36/AD-37/AD-39/AD-40
contract chain. It does not modify the four products or any prior receipt.

## Repair verification

Both payloads now have no terminal LF and their exact bytes equal compact,
lexicographically sorted UTF-8 JSON:

- G1 payload: 1,968 bytes,
  `540094f46e2a4010e94b20214e64e1f66c9fe994afc30a71cdfa67dfcda88475`
- G2 payload: 2,006 bytes,
  `cf6f280428409ccee64e134355753ef841f83fa170f353b22395ad78d05c9133`

The current authoring receipts match those payload paths, byte counts and
SHA-256 values. G1 receipt SHA is
`47aed536d296c7fc53fe82c3c844b4a208bf88d30acda5a95424aeae9d58be5e`; G2
receipt SHA is
`3959c4302312038d3e9c9e9faf3d669c2f50af455cd8f455da5885d35758c8d7`.
The schema/factory source byte receipts still match the observed G1 and G2
source hashes. The repair is limited to terminal-LF removal and receipt payload
metadata synchronization.

The R1 before hashes remain available in both layer repair sidecars. G1 before
payload was 1,969 bytes with SHA
`086f21765a3e92903a4848504cc9c6142e7c684066bbe0242bc8f03ffea4979a`; G2
before payload was 2,007 bytes with SHA
`4703be190a136d4381c0ef06db87d022e1bd93c5105c61320789a604e176c43b`.
The earlier receipt hashes, the failed malformed sidecar-manifest attempt and
all R1 raw validation sidecars are still present and verified as preserved.

## Independent contract checks

The fresh run independently passed JSON parsing, exact canonical-byte
recomputation, no-terminal-LF, payload/receipt synchronization, shared run id,
seed, commitment, PID and UTC interval, four-axis presence, typed evidence
absence, and both layers' `AbsentDeclarationSourceV1` /
`terminal_deferred` outcomes. G2 still explicitly keeps
`GenomeContractRef` typed and does not alias it to `QualifiedRefV1`.

The five negative controls—missing axis, fixture path, foreign layer, extra
whitespace and seed mismatch—rejected as expected. The absence is still caused
by missing fresh non-fixture public `GenomeContractRef`/source authority. No
candidate identity or hash, authority record, binding, factory receipt, T0,
T1, T2, provider, mesh, solver, engineering, physical or R01–R10 credit was
created or inferred.

## Evidence and cleanup

The independent verifier used `D:\Users\Newman\anaconda3\python.exe` (Python
3.13.5), PID `73240`, from the repository root, and exited `0`. Raw stdout is
`archive/validation_stdout.json`, 2,864 bytes, SHA-256
`e9e98079018d332102f385e6d19a37371289422efa7566fdcbdf02ecdbaf2b9d`; raw
stderr is the zero-byte `archive/validation_stderr.txt`, SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The exact R2 review-owned set is this report, its manifest, and the two raw
sidecars under `archive/`. Cleanup found no review temporary or unrelated code
files. No product, source, test, fixture, launcher, historical receipt or
unrelated dirty file was removed or rewritten.

## Acceptance boundary

This is `pass_limited` for the repaired W2 typed-absence authoring slice and
its exact canonical-byte contract. It does not promote either layer to
software present or source authority and does not unlock candidate identity,
binding, factory, T0/T1/T2, UP2, provider, mesh, solver, engineering, physical,
search or R01–R10 evidence. The next work order must still use fresh authority
and preserve this claim ceiling.
