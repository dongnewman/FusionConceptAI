# UP1 R4 authoritative channel recheck

## Verdict

`typed_absent` — no new authoritative-channel declaration or external response was found. The local adapter is a software boundary only; it is not an authoritative channel and cannot provide authority credit. `usable=0`, `untrusted=0` for newly received external packets, and `typed_absent=26/26` for the R4 contract records.

The fixed checkout is confirmed at `b2c04d8339774635aaecd73651efcdb101e01b5d`. The working tree is dirty; this recheck does not reinterpret unrelated dirty files as HEAD contents. No network, credential, external request, Julia/DESC/S3, AD, or publication action was used.

## Evidence checked

- `01-external-input-contract/external_input_contract_r4.json`: 26 items; all 26 have `authoritative_channel.state/owner/endpoint/transport/authentication/ack = typed_absent`, and all 26 have `current_typed_state=typed_absent`.
- `00-external-delta-scan/manifest.json` and `external_material_inventory.json`: the bounded offline scan recorded `usable_external_inputs=0`, `typed_absent=26/26`, `new_ad=false`, and `s3_rerun=false`; it explicitly did not query remote or unlisted channels.
- The expected workspace roots `local_spool`, `local_spool/incoming`, `response`, `anchors`, `local_receipts`, `incoming`, and `intake` are absent at this recheck. No fresh response/anchor/receipt bytes were available.
- `tools/up1_external_closure_r4/authoritative_intake/intake.py`: the implementation describes `endpoint` as descriptive and never contacted, contains no network/message API, keeps a local verifier at `typed_unverified`, and emits `external_ack=false`, `external_ack_sent=false`, `authority_claim=false`, and `local_bookkeeping_only=true`.
- `tools/up1_external_closure_r4/authoritative_intake/cli.py`: `--real-channel` is explicitly descriptive and still no-network; it does not configure or contact an external service.
- The test fixture's `local-only://r4` / `offline-spool` values and `real_channel=true` are test-only local descriptions, not authority evidence. The R4 repair retest reports two successful local runs but preserves `formal_credit=none`, `authority_credit=false`, and `no_publish=true`.

The independent read-only scan process was PID `113236`, UTC `2026-09-17T03:56:51.960702Z` → `2026-09-17T03:56:52.778109Z`, exit `0`. Its raw output is `raw/recheck.stdout.json`; the observed worktree status had 10,694 lines with SHA-256 `0a862e2fd01e62dce1d4021db1b02863202a119851e1b2b4fa7ab70162b1488b`.

## Channel fields and responsibility

| Required fact | Current result | Responsible party | Recovery condition |
|---|---|---|---|
| Authoritative owner identity | `typed_absent` | External authoritative channel owner; independent witness/governance as applicable | Publish a signed owner identity and scoped channel contract |
| Endpoint/locator and transport | `typed_absent` | Channel owner / transport administrator | Publish endpoint, protocol/version, TLS or key pin, retention and SLA |
| Authentication and signature policy | `typed_absent` | Channel owner plus project PKI/trust administrator and attestor | Publish the authentication method, pinned root/chain, signature/canonicalization profile and revocation policy |
| Testable receive path | `typed_absent` | Channel owner and intake operator | Provide a registered/available channel and a testable acknowledgement or rejection path before any real request |
| Signed receive acknowledgement | `typed_absent` | Channel receiver / channel owner | Return raw signed ACK or signed rejection binding request ID, ordered EHP-01..04 bundle digest, nonce/sequence/idempotency key, trusted receive time, decision, and durable quarantine receipt |
| Independent validation | `typed_absent` | Independent verifier/reviewer, TSA/time-policy, revocation and replay-ledger owners | Verify pinned trust, chain, signature, trusted time, revocation, freshness/replay, candidate/source/G1/G2/G3 binding, then issue an independent receipt |

The role labels above are contract responsibilities, not verified identities. No current file supplies an endpoint, owner identity, authentication credential, signing key, signed channel contract, or external ACK.

## Required receive/verify operations

1. The external channel owner supplies a fresh signed channel contract containing owner identity, endpoint/locator, transport and protocol version, TLS/key pin or equivalent, authentication, retention/acknowledgement SLA, and allowed packet set. Do not infer any field from a URL, local name, system trust store, or test fixture.
2. The intake operator records the channel registration/availability receipt and exercises the acknowledgement path under the contract. No request is sent while the channel is absent or only descriptive.
3. Submit one ordered atomic EHP-01,EHP-02,EHP-03,EHP-04 bundle with exact raw UTF-8 bytes, SHA-256 digests, candidate/source/four-axis/G1/G2/G3 binding, trusted request/expiry time, nonce, strict sequence, and idempotency key.
4. Retain the exact raw response. Accept only a receiver-signed ACK or rejection that repeats the request/bundle digests and replay fields and binds a durable quarantine/CAS receipt. A local spool receipt is bookkeeping and never an external acknowledgement.
5. Independently verify the pinned trust root and complete chain, canonicalization/signature profile, trusted time, revocation, freshness/replay and all candidate/source/G2 bindings. Any malformed, conflicting, foreign, stale, revoked, replayed or digest-mismatched material is `fail_closed`; missing channel/material remains `typed_absent -> terminal_deferred`.

## Gate disposition

`new_ad=false`, `s3_rerun=false`, `formal_credit=none`, `authority_credit=false`, `publish=false`. The R4 root acceptance remains scope-limited local software acceptance and does not close UP1, T0/T1/T2, R01–R10, or the parent goal.
