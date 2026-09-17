# UP1 root final acceptance increment R1

## Authority and bounded outcome

Decision authority: `Sol/root`. Recorder: `m4_scope_record`, `gpt-5.6-luna`, `high`.
Decision origin: final architecture acceptance increment based on W1 round7,
W2 round3, W3 round4, W4 round3 and final integration R2 `pass_limited`.
This record is documentation-only and does not alter the prior root
adjudication or any protected planning/source/test/registry file.

| package | final status | claim ceiling | accepted meaning |
|---|---|---|---|
| W1 witness authority | `accepted_limited` | `preparation_only` | contract and typed-absence bookkeeping |
| W2 trust chain | `accepted_limited` | `preparation_only` | trust-path contract and typed-absence bookkeeping |
| W3 source/G2 environment | `accepted_limited` | `preparation_only` | exact-set/environment/validator bookkeeping |
| W4 local input discovery | `accepted_limited` | `discovery_only/preparation_only` | repository-local discovery and crosswalk bookkeeping |
| external handoffs | `accepted_limited` | `executable_request_package/not_sent` | request packages are prepared; no external request was sent |
| git hygiene | `accepted_limited` | `read_only` | inspection and preservation only |
| final integration | `pass_limited` | `integration_bookkeeping_only` | package consistency; no formal gate credit |

There are **0 usable external inputs**. UP1 external blockers are therefore
**NOT resolved**. Fresh S3 remains `G1=typed_absent`, `G2=typed_absent`,
`G3=typed_absent`, then `terminal_deferred` and `no_publish`. Unchanged
absence means no new AD and no S3 rerun. AD55 archive material is not trust;
AD56 dirty software is accepted-limited bookkeeping only and is not trust or
evidence. M5-C remains `deferred_performance_blocked` and receives no formal
credit.

## Responsibility and handoff boundary

The four responsibility packages and their unresolved external inputs are
listed in `external_inputs_and_owners.json`. All unknown real names,
attestors, endpoints, credentials, keys and authority channels remain typed
absence; none is inferred from local files. Handoff artifacts are accepted
only as executable request packages, `not_sent`, with no external state
change. Recovery requires real external material to change, then fresh input
freeze and independent verification. Rejection remains mandatory for missing
authority, ambiguous ownership, stale or mismatched hashes, unverifiable
signatures, foreign source references, or any attempt to promote local
bookkeeping into external fact.

## Formal route and next trigger

The locked formal order is exactly:

`T0 → authority_recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`

The next action is a single fresh current-input S3 authority recheck only
after the trigger in `gate_and_next_trigger.json` is satisfied. If the
external input set is unchanged, stop with typed absence and do not create an
AD or rerun S3. A successful recheck still requires fresh G1/G2/G3, candidate
identity, receipts and all downstream gates before any formal promotion.

R01–R10, the 39-node DAG, B00/B04, L4 and the parent goal remain open or
locked as recorded; this increment closes none of them and grants no UP1,
UP2, B00, B04, R, L4 or parent credit.

