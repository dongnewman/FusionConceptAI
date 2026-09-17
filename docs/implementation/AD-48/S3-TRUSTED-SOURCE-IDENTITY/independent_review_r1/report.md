# AD48-S3 trusted G3 source identity independent review R1

日期：2026-09-16  
复核者：different Codex independent process（本审查仅使用 Python 3.13.5；未读取 key/certificate/credential 内容）  
结论：`pass_limited`  
范围：AD48-S3 formal four-scope typed-absence products and software provenance boundary

## Decision

本复核逐字节重算 formal S3 manifest 与四 scope 的 8 件产品，并重新读取 AD48 order/decomposition、S3 preparation、AD48-S1 acceptance、F0 root acceptance R3、fresh S2 R2 root acceptance、AD45 R2、以及项目 README、14、16、18。独立 Python 检查为 `137/137`，exit `0`；正式归档 direct validation 为 `65/65`，exit `0`；第二 Python 进程 replay 为 `8/8`，exit `0`。

四个 scope（`realization`、`control`、`binding`、`bundle`）均精确产出：

`AbsentG3TrustedSourceIdentityV1` + `AbsentG3TrustedSourceIdentityReceiptV1`，`status=typed_absent`，`terminal_deferred=true`，`no_publish=true`，`trusted_attestation_created=false`，`candidate_identity_created=false`，`declaration_hash_created=false`。

该结论只接受 typed absence 的软件记录和其输入/哈希闭合。它不接受任何 trusted source identity、candidate/final hash、T0、物理或工程结果。

## Formal products and accepted inputs

| scope | identity bytes / SHA-256 | receipt bytes / SHA-256 |
|---|---:|---:|
| realization | 2414 / `d18c3d983c9453a49d7fdeb4ade305f1e2467c980cb99ae981dfb367ddf57f78` | 1292 / `b32b832f9965f35eb03c28b393c765116bc1070b7ce05f7d7d69e43b1dcfb3f2` |
| control | 2394 / `701fc7a253e5e41d2f22f95b1bb1173eca46f76f037fac4407d2343860e05b14` | 1288 / `f7072221737f3be9b7d4d417031558bd09c5f2723693d869996f3f73b3f0fa77` |
| binding | 2394 / `58bd50be0abc470117e8e09f9d14b826ff1d00a31402f48d4511ae0664f4a1d1` | 1288 / `46001d6f1d898d12f8f899e2b1b668eaafb162ec804ebc99a43b06da1615b380` |
| bundle | 2389 / `69822d7b0acfbf612dbaf12f8b4a6ae309eee9981c561e19374c8475f2dbc7e3` | 1287 / `2d302c6d7ce9f1eaa9e79240d9c0878f4976af0cb386326929b98430f436d8cc` |

All 8 product paths are unique and match the manifest. The identity input closures exactly match the accepted fresh S2 root R2 product list and hashes, the four accepted S1 locator/receipt pairs, F0 root acceptance R3, and the AD45 envelope/handle:

- S2 root acceptance: `f8f729e08f758902393249122e8401ecf4e0b2df9218a264922b186490d99523`, decision `accepted_limited`, only unlock `formal S3`.
- AD45 envelope: `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`; handle is the exact `QualifiedRefV1/v5` candidate-binding handle.
- F0 root acceptance manifest: `08e677522d27fc1cde56712429bae2966c5df08d8ac3d336c7eb08b397355ae`.

The fresh S2 root claims remain limited to source-stage factory identity/construction receipts; its trusted attestation, candidate identity, final hash, T0/T1/T2, provider, physics, R01-R10 and L4 claims remain false/zero.

## Trusted-attestation boundary

The repository and security metadata contain no AD48-specific independent attestor, signing key/certificate, signature verifier, trust-root binding, revocation source, or trusted freshness/time policy. Filename inventory found no repository key/signature/certificate files; Git signing configuration is unset. Generic `gpg`, `openssl` and `ssh-keygen` availability does not establish an AD48 identity mechanism. Windows certificate-store counts were observed as generic metadata only (`CurrentUser/My=2`, `CurrentUser/Root=280`, `LocalMachine/My=0`, `LocalMachine/Root=280`); no certificate content was read or used.

Unsigned self-authored JSON, reviewer names, factory receipts, test exits and runner exits therefore cannot promote trust. The formal negative-control contract is preserved and rechecked: missing authority is `Absent...` + `terminal_deferred`; wrong scope/hash/handle/upstream input, signature or preimage tamper, replay, stale, revoked, or unknown signer is `Failed...` + `fail_closed`, with no publication. No S3 product contains a detached signature or trusted signer claim.

## Validation and history

The task-owned archive direct validation is `65/65`, PID `86988`, UTC `2026-09-15T16:41:50.396860Z`, Python 3.13.5, exit `0`; its replay validation is `8/8`, PID `90856`, UTC `2026-09-15T16:41:50.468566Z`, exit `0`. The independent recomputation is in `raw/direct_validation.json` (`137/137`) and `raw/replay_validation.json` (`8/8`). The planning validator was rerun with Python 3.13.5, exit `0`: 31 markdown files, 526 links, 39 tasks, acyclic DAG. Scoped `git diff --check` was rerun, exit `0`, with zero stdout/stderr. No Julia, DESC, provider, mesh, solver, engineering, physics, or search execution occurred.

`manifest.json` records `formal_products_rechecked=true` and `prior_capacity_failure_history_preserved=true`. The prior S2 R1 `changes_requested` record, corrected S2 R2 review, repair snapshot, and F0 failed-attempt archive remain append-only; no historical product was rewritten. No separate S3 raw file named `capacity-failed` exists, so this continuity flag is treated as provenance metadata only and supplies no trust credit.

## Claim ceiling and handoff

`trusted_source_identity=false`; `candidate_identity=false`; `final_hash=false`; `T0=false`; `physics=false`; `R01-R10=false`; `L4_credible_count=0`. AD48 G3 trusted identity remains `blocked_external_trust_root`. This review does not unlock fresh W1, W2, AD46 identity, Candidate/finalhash/T0, or any physical claim. Unrelated AD49 work may proceed independently.

Review-owned raw evidence is limited to `independent_review_r1/**`; no formal product, manifest, archive, source, test, registry, core planning file, or unrelated dirty artifact was modified.
