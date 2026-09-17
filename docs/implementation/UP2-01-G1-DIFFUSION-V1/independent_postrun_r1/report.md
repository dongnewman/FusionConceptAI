# UP2-01-G1-DIFFUSION-V1 focused R1 independent postrun audit

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The focused software command itself is a real exit-0 run with 71/71 reported assertions. The independent postrun verdict requests correction of the sealed raw-output provenance: the empty `stderr.txt` is 0 bytes with the standard 64-character SHA-256 `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`, while `focused_r1/report.json`, `focused_r1/evidence_manifest.json`, and `focused_r1/command_receipts.json` each record a 62-character value `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`. The stdout receipt matches its raw file. This is a receipt-sealing defect; it does not change the observed Julia exit code or test summaries.

This audit is read-only. It did not run Julia or DESC and did not modify G1 source, tests, fixture, static QA, precheck evidence, focused evidence, or core documents. No compiler, provider, mesh, solver, physical, engineering, current-A, B00, B04, or R01-R10 credit is granted.

## Frozen execution evidence

The authorized command was `julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl`, PID `51988`, exit `0`, with stdout creation at `2026-09-14T20:31:03Z` and final stdout write at `2026-09-14T20:31:10Z`. The preflight and postflight process receipts both report zero matching Julia/DESC processes; the current review process sweep also observed zero.

The raw stdout is 454 bytes and SHA-256 `685826d01c1257313467060d3c7268b3ea5825aad17d630aeebe9593cad40152`, matching all focused receipts. The raw stderr is 0 bytes and its computed SHA-256 is `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`; the focused receipt value is malformed at 62 characters and therefore does not match.

The three test summaries in raw stdout and the JSON receipts are `32/32` positive declaration and typed receipt, `34/34` fail-closed negative controls, and `5/5` source-edit identity, totaling `71/71`.

The four target files retain the R6 precheck hashes and bytes before and after the focused run:

- `src/GenomeV5/G1/DiffusionDeclarationV1.jl`: 31,743 bytes, `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`
- `test/GenomeV5/G1/diffusion_v1_contract_tests.jl`: 9,655 bytes, `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6`
- `test/GenomeV5/G1/diffusion_v1_fixture.json`: 1,582 bytes, `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641`
- `test/GenomeV5/G1/static_qa_diffusion_v1.py`: 4,499 bytes, `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066`

The launcher recorded dirty entry count `3692` before launch and `3697` after completion, with post-run status SHA-256 `5a5377c953e753d7a84f540ecb0a10322a12d245f89c788ca5c9fc6356a4366d`. The pre-run dirty status hash is explicitly unavailable (`null`) in the focused receipts and remains unavailable here; no value is inferred. The later postwrite receipt separately records `3704` entries after receipt files were written.

## Contract coverage

The runtime groups cover the candidate-owned 3-D scalar `u`/`f`, spatial positive-definite diagonal-affine `K`, exact enclosure and domain behavior, typed `GRAD`/`K_APPLY`/`DIV` field bindings, units, residual sign `-1`, candidate ownership, source hash, terminal-deferred authority, contract-only claim ceiling, and internal unexpected-exception classification. Negative controls cover contradictory bounds, zero slope, negative base, wrong gradient units, wrong DIV binding, positive residual sign, string-only edit, forged source hash/type, K bound/domain/probe failures, chain sign/unit failures, and declaration-hash tamper.

The source-edit group covers K identity change and validates the edited declaration, plus distinct source-hash changes for edited `u` and `f`, giving the recorded `5/5` source-edit assertions. The source and static-QA surfaces also retain typed constructor and fail-closed checks. No execution claim is inferred for compiler, provider, mesh, solver, or physical behavior.

The focused tests do not directly assert every zero receipt counter (`compile_calls`, `provider_calls`, `mesh_calls`, `solver_calls`) or each schema/canonicalization/profile receipt hash and required-gap tuple. The constructor sets those counters to zero and the static source QA checks the required contract tokens, so this is a test coverage limitation rather than a failed focused assertion. It should remain visible under the contract-only ceiling.

## Required disposition

Produce an additive corrected postrun receipt or a re-sealed focused receipt whose stderr SHA is the actual 64-character value, while preserving the immutable run command, PID, exit code, raw files, and target hashes. After that provenance correction, a subsequent independent Luna review may promote the software evidence to `pass_limited`; this audit does not accept the slice.
