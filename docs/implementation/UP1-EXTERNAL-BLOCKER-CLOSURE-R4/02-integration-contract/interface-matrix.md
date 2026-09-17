# Integration interface matrix

All rows are **planned call seams**, not claims that the call graph currently
exists. Paths are repository-relative to `FusionConceptAI`.

## Ordered calls and typed outputs

| Seq | Component / public seam | Required input | Required output | Binding and mutation rule | Local ceiling |
|---:|---|---|---|---|---|
| 0 | R3 `atomic_bundle.validate_bundle(raw_utf8, context, quarantine_root)` | Exact received UTF-8 bytes; frozen context; CAS root | `schema_ok`, raw/bundle/packet digests, one `decision`, failure codes, CAS refs | Quarantine exact bytes before parse; EHP-01..04 and packet digest order are one set; any error rejects the whole set | `prototype_pass_limited`/`fail_limited`; `formal_credit=none`, `no_publish=true` |
| 1 | R4 `authoritative_intake.AuthorityIntake.receive_packet_set(...)` | Packet tuples or mappings, explicit `ChannelIdentity`, `ChannelPolicy`, optional local transport receipt | One `accepted_all` or `rejected_all`, packet-set digest, quarantine/receipt refs, `authority_status` | All packets are quarantined before policy evaluation; no partial acknowledgement; local receipt is not an external ACK | `typed_absent` without a real channel; otherwise still `typed_unverified`; `authority_claim=false` |
| 2 | R4 `source_axis_binding.validate_bundle(bundle, observed_source_identity)` followed by the required external-authority adapter | R3 bundle plus freshly captured source identity, four-axis materials, and an external verification envelope | Structural source/axis result plus, only after independent verification, derived `externally_verified`, source digest match, exact axis set, refs, errors | Raw `EXTERNAL_ISSUED` (`provenance_class=external_issued`) is an admissible input label for the two-stage route. The local validator checks structure/joins; the external adapter checks pinned trust, chain, signature, trusted time, revocation, freshness/replay, G2 and independent review, then derives `externally_verified`. No local result may assert authority. | `typed_absent`/`typed_absence`→`terminal_deferred`; `TEST_ONLY`/local product→`non_evidence`; malformed or contradictory external material→`invalid`/`fail_closed`; until the adapter emits `externally_verified`, G8 is unsatisfied |
| 3 | R4 `g2_mapping.validate_mapping(profile)` / `evaluate(profile)` | Candidate/source identity, forward and reverse graph, G2 mapping, authority receipt | Structural validity, graph/mapping digests, bijection result, `authority_verified` | Forward/reverse edges and rows must be exact inverses with the same authority/source/candidate; ambiguity is a hard failure | Structural pass remains `terminal_deferred`; `production_admissible=false`; no publication |
| 4 | R4 `environment_closure.collect_closure(...)` | Read-only root, runtime/binary paths, lock/manifest and provenance refs | Runtime/binary/lock observations, provenance status, missing/unverified list | No download/install/network; missing source receipt, signature, SBOM, build recipe, lock, or binary inventory stays typed | `typed_absent` or `typed_unverified`; local hashes do not establish reproducibility |
| 5 | R4 `trust_chain.verify_request(request)` / `verify_chain(...)` | Caller-pinned root, ordered chain, profile, evaluation time, optional detached signature | `status`, certificate records, check map, algorithm/time/constraint result | Root raw hash must be pinned; chain/signature checks use supplied material only; no ambient trust store | `unverified` at best; `typed_absence` for missing root/profile/material; always non-authoritative |
| 6 | R4 `freshness.validate(payload, ledger)` | Signed receipt, trusted time, revocation receipt, replay window, expected scope/version; optional `PersistentReplayState` | Freshness/revocation result and replay result; CAS outcome when committing | Validate before ledger commit; use lock plus expected state hash/version; commit only one bound result digest | Valid-for-scope is not authority; `cas_conflict`, replay, stale, or absent remains deferred/rejected |
| 7 | Integration merge (future orchestrator; no current implementation) | Immutable outputs from rows 0–6 plus candidate/source/run scope | One typed aggregate state and one decision | Apply precedence in `failure-taxonomy.md`; never merge fields by “best effort”; preserve all receipt refs and hashes | Aggregate cannot lower `formal_credit` or set `no_publish=false` |
| 8 | Recheck gate (future, after external inputs only) | Immutable T0 snapshot + fresh externally satisfied receipts from all required seams | Checked-present recheck record, or unchanged T0 + typed gap | Requires every external condition in `integration-acceptance-gates.md`; no synthetic/ref-only/fixture promotion | Until complete, `T1_go=false`, `T2_go=false` |

## Typed state merge

The aggregate must retain each module's raw status and errors; a normalized
state is derived with this precedence (first matching rule wins):

1. `program_exception`, `invalid`, `fail_closed`, digest/binding/CAS
   contradiction, or any hard structural/security error → aggregate
   `fail_closed`.
2. `typed_absent`, `typed_absence`, `terminal_deferred`, missing external
   owner/channel/material, stale/revoked input, or an unavailable required
   receipt → aggregate `terminal_deferred`.
3. `typed_unverified`, `unverified`, `local_observed`, `accepted_local`,
   `TEST_ONLY`, and `valid_for_declared_scope` without independently bound
   external authority → aggregate `terminal_deferred` with
   `classification=non_evidence`.
4. A future `externally_verified` state is eligible for recheck only when
   every required module is in that state and all cross-module digests and
   receipts match. No current R4 implementation emits this state.

`accepted_all` from R3/R4 intake is a packet-set decision, not a normalized
`externally_verified` state. `formal_credit=none` and `no_publish=true` are
always merged by logical OR / minimum authority: one module cannot clear a
lock set by another.

The trust-chain taxonomy is strict: `typed_absence` means required material or
verification capability is unavailable within the declared scope; `invalid`
means present material has a proven syntax, cryptographic, temporal,
revocation, replay or binding contradiction and therefore fails closed;
`unverified` means present/admissible bytes have not yet obtained the required
external authority or independent review and therefore remain deferred/non-
evidence. A later check may not downgrade `invalid` to `unverified` or
`typed_absence`, and a local/TEST_ONLY result may not upgrade either absence or
unverified to `externally_verified`.

## CAS and receipt binding

The orchestrator must carry one immutable binding tuple through all calls:

```text
(candidate_id, source_identity_digest, run_id, request_id,
 bundle_id, raw_sha256, bundle_canonical_sha256, packet_digests,
 quarantine_locator, quarantine_transaction_id, nonce, sequence,
 idempotency_key, scope, result_digest)
```

The raw SHA must equal the bytes retained in the R3/R4 CAS locator. The
bundle/set/review digests must recompute from those same bytes and the same
canonical preimage rules. The freshness ledger may be committed only after
all structural, trust, source, mapping, and environment checks pass. A CAS
state hash/version mismatch is a `cas_conflict`, not a reason to overwrite or
retry in place. A changed byte set requires fresh `bundle_id`, `request_id`,
nonce, sequence, and idempotency key according to the R3 recovery rules.

No result may be promoted if any receipt is unbound, foreign-candidate,
foreign-source, stale, replayed, or references a different quarantine object.
