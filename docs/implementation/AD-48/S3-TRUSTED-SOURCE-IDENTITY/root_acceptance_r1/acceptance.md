# AD48-S3 trusted G3 source identity root acceptance R1

日期：2026-09-16  
decision：`accepted_limited`  
accepted_scope：`four_scope_trusted_source_identity_typed_absence_only`  
gate_status：`blocked_external_trust_root`

## Decision

依据独立审查 R1 的 `pass_limited` 结果，root 接受 AD48-S3 四个 scope 的 typed-absence 软件记录。`realization`、`control`、`binding`、`bundle` 各自的 identity 与 receipt 均为：

`AbsentG3TrustedSourceIdentityV1` + `AbsentG3TrustedSourceIdentityReceiptV1`，`status=typed_absent`、`terminal_deferred=true`、`no_publish=true`。

本接受只确认软件 absence、输入引用和哈希闭合，不创建或接受 trusted source identity、candidate identity、final hash、T0、物理或工程结果。

## Formal products

| scope | identity | receipt |
|---|---|---|
| realization | 2414 bytes, `d18c3d983c9453a49d7fdeb4ade305f1e2467c980cb99ae981dfb367ddf57f78` | 1292 bytes, `b32b832f9965f35eb03c28b393c765116bc1070b7ce05f7d7d69e43b1dcfb3f2` |
| control | 2394 bytes, `701fc7a253e5e41d2f22f95b1bb1173eca46f76f037fac4407d2343860e05b14` | 1288 bytes, `f7072221737f3be9b7d4d417031558bd09c5f2723693d869996f3f73b3f0fa77` |
| binding | 2394 bytes, `58bd50be0abc470117e8e09f9d14b826ff1d00a31402f48d4511ae0664f4a1d1` | 1288 bytes, `46001d6f1d898d12f8f899e2b1b668eaafb162ec804ebc99a43b06da1615b380` |
| bundle | 2389 bytes, `69822d7b0acfbf612dbaf12f8b4a6ae309eee9981c561e19374c8475f2dbc7e3` | 1287 bytes, `2d302c6d7ce9f1eaa9e79240d9c0878f4976af0cb386326929b98430f436d8cc` |

All eight products match the formal S3 manifest paths, bytes and SHA-256 values. Their exact inputs bind to accepted fresh S2 R2 products, S1 locator/receipt products, F0 root acceptance R3 and the AD45 exact handle/envelope.

## Evidence

- Formal S3 direct validation: `65/65`, PID `86988`, UTC `2026-09-15T16:41:50.396860Z`, Python 3.13.5, exit `0`.
- Formal S3 replay validation: `8/8`, PID `90856`, UTC `2026-09-15T16:41:50.468566Z`, Python 3.13.5, exit `0`.
- Independent R1 recomputation: `137/137`, Python 3.13.5, exit `0`; independent product replay `8/8`.
- Security inventory: no AD48-specific independent attestor, signing key/certificate, verifier, trust root, revocation source or freshness/trusted-time policy; no key or credential contents were read.
- Plan validator: 31 markdown files, 526 links, 39 tasks, acyclic DAG, exit `0`; scoped diff check exit `0`.

The negative-control boundary remains: unsigned self-JSON, reviewer names, factory receipts, test exits and runner exits cannot promote trust; wrong scope/hash/handle, tamper, replay, stale, revoked or unknown signer conditions are `Failed...` + `fail_closed` with no publish.

## Gate effect

An external AD48-specific independent attestor and verifiable key/certificate, signature verifier, trust-root binding, revocation policy/source and freshness/trusted-time policy are still required. Until that external trust-root closure exists, AD48 G3 trusted identity remains `blocked_external_trust_root`.

This acceptance does not unlock fresh W1, W2 or AD46 identity. `Candidate=false`, `finalhash=false`, `T0=false`, `physics=false`, `R01-R10=false`, and `L4_credible_count=0`. Unrelated AD49 work may continue independently. Julia/DESC were not run.
