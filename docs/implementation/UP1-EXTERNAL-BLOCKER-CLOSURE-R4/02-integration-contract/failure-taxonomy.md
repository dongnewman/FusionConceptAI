# Integration failure taxonomy

The orchestrator must preserve the originating module code and emit one
normalized class. It must not downgrade a hard failure to absence or treat a
local pass as authority.

## Trust-chain state vocabulary

These three states are mutually exclusive at the same boundary:

- `typed_absence` (the inventory spelling `typed_absent` is retained for the
  26 current records): required bytes, owner/channel, or verifier capability
  are unavailable within the declared scan/contract scope. It is an
  availability result only and normalizes to `terminal_deferred`.
- `invalid`: bytes are present but a syntax, schema, cryptographic, temporal,
  revocation, replay, scope, or digest contradiction is proved. It normalizes
  to `fail_closed`; it must never be softened to absence or unverified.
- `unverified`: bytes are present and structurally admissible, but the pinned
  external authority, trust chain, freshness/replay, or independent review is
  not complete. It normalizes to `terminal_deferred` with `non_evidence`.

An unavailable verifier or missing trust/revocation/time material is
`typed_absence`; a verifier that ran and proved a bad chain, bad signature,
expiry, or revocation is `invalid`; a verifier that has admissible material but
has not completed the required external/independent checks is `unverified`.

| Class | Representative codes/states | Normalized result | Retry / mutation rule |
|---|---|---|---|
| `RAW_OR_SCHEMA` | `RAW_INVALID_UTF8`, duplicate key, non-finite number, `RAW_INVALID_JSON`, `SCHEMA_INVALID`, unknown field | `fail_closed` / `rejected_all` | Preserve CAS bytes; repair input and submit a fresh set; never mutate a receipt |
| `SET_COMPLETENESS` | missing/duplicate EHP packet, packet order/count mismatch, missing axis/material, incomplete packet set | `fail_closed` / `rejected_all` | All-or-reject; no per-packet promotion or partial ACK |
| `IDENTITY_BINDING` | candidate/source/run/ref mismatch, source drift, foreign candidate, graph/mapping hash mismatch, bundle/packet digest mismatch | `fail_closed` / `rejected_all` | Keep old T0 and receipt immutable; new byte set needs fresh IDs and nonce |
| `CAS_QUARANTINE` | raw hash/size mismatch, locator/transaction mismatch, reparse path, immutable collision, CAS install unavailable | `rejected_all` for contradiction; `terminal_deferred` for unavailable durability | Never overwrite CAS; `cas_conflict` is not an acceptance |
| `AUTHORITY_ABSENT` | `typed_absent`, missing channel/owner/root/profile, missing external receipt, missing lock/provenance | `terminal_deferred`, `no_publish` | Wait for real input; do not synthesize or infer presence |
| `AUTHORITY_UNVERIFIED` | `typed_unverified`, `unverified`, admissible bytes without pinned external authority/reviewer receipt, local spool receipt | `terminal_deferred`, `non_evidence` | No promotion; recheck is forbidden until all required external receipts exist |
| `TRUST_TIME_REVOCATION` | expired/revoked certificate, weak or disallowed algorithm, bad chain, invalid signature, trusted-time contradiction, or revocation contradiction; absent time/revocation/root material | `fail_closed` with `invalid` for a proved contradiction; `terminal_deferred` with `typed_absence` when required material/service is unavailable; `terminal_deferred` with `unverified` when checks remain incomplete | Do not consult ambient stores or local clock as authority; never downgrade a proved contradiction |
| `REPLAY_FRESHNESS` | nonce replay, sequence invalid/gap, idempotency conflict, stale window, scope binding mismatch | `fail_closed` / `rejected_all` | Preserve ledger; retry only with a valid fresh sequence and identity tuple |
| `CONCURRENCY_CAS` | `cas_conflict`, expected state hash/version mismatch, lock timeout, ledger corruption | `terminal_deferred` for contention; `fail_closed` for corruption | Re-read immutable state, independently decide whether a fresh request is safe; never blind overwrite |
| `G2_BIJECTION` | duplicate endpoint/row, inverse mismatch, ambiguity, candidate endpoint uncovered | `fail_closed` / `terminal_deferred` depending on absence vs contradiction | No G2 recheck until a complete candidate-bound graph and mapping are supplied |
| `ENVIRONMENT_CLOSURE` | runtime/binary/lock absent, source receipt/signature/download/SBOM/build recipe absent or unverified | `terminal_deferred`, `non_evidence` | Collection is read-only; no installation/download to close the gate |
| `EXECUTION_SCOPE` | `not_executed`, fixture-only command, missing owner/ACL/UTC/exit/stdout/stderr receipt | `terminal_deferred`, `no_publish` | A bookkeeping record cannot become execution evidence; no heavy lane here |
| `PROGRAM_EXCEPTION` | uncaught parser/runtime/OS exception, unavailable verifier dependency | `fail_closed` unless explicitly typed absence is returned | Record exception and unchanged inputs; no implicit retry or fallback parser |
| `PUBLICATION_LOCK` | `formal_credit != none`, `no_publish != true`, `authority_credit=true` in an R4/local result | `fail_closed` | Treat as contract violation; this integration cannot clear the lock |

## State precedence

Contradiction and integrity failures dominate absence. For example, a packet
set with both a missing owner and a mismatched digest is `fail_closed`, not
`terminal_deferred`. If no contradiction exists, typed absence dominates
local/unverified observations. A complete local fixture remains
`non_evidence`.

The same precedence applies inside the trust chain: an absent input is not
invalid, an invalid input is not merely unverified, and an unverified input is
not externally verified. The normalized class must retain the originating
status and error code so a later retry cannot reinterpret a hard failure.

## Receipt invariants

Every normalized result must include `formal_credit=none`, `no_publish=true`,
`authority_credit=false`, raw error codes, input digest(s), and the immutable
receipt/CAS references available at the failing boundary. A missing receipt
reference is itself a failure; it must not be represented by an empty field
that looks like a successful observation.
