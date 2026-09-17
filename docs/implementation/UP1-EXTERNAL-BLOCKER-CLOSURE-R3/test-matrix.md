# Acceptance test matrix (not executed)

These are future implementation tests. Status of this contract remains
`review_pending`, `not_implemented`, `formal_credit=none`.

| ID | Fixture/change | Expected derived result |
|---|---|---|
| T01 | Canonical four-packet bundle, all signatures/trust/time/replay/review valid, EHP-04 executed | `accepted_all`, completeness true |
| T02 | Remove EHP-03 | schema failure; `rejected_all/fail_closed`; no promotion |
| T03 | Duplicate EHP-02 or add EHP-05 | fixed-order/cardinality failure; `rejected_all/fail_closed` |
| T04 | Swap EHP-01 and EHP-02 positions | position `const` failure; `rejected_all/fail_closed` |
| T05 | Alter one packet digest or shared binding field | digest/binding mismatch; `rejected_all/fail_closed` |
| T06 | Add an unknown key at every nested level | closed-schema failure; `rejected_all/fail_closed` |
| T07 | Duplicate JSON object key, NaN, Infinity, invalid UTF-8 | pre-parse rejection; `rejected_all/fail_closed` |
| T08 | Unsigned packet or packet signed by foreign role | owner-signature failure; `rejected_all/fail_closed` |
| T09 | Set receipt signs only packet IDs, not packet digests | set-preimage failure; `rejected_all/fail_closed` |
| T10 | Reuse nonce/sequence/idempotency key after rejection | replay conflict; `rejected_all/fail_closed` |
| T11 | Expired/revoked/unknown certificate, CRL/OCSP or TSA token | security failure; `rejected_all/fail_closed` |
| T12 | EHP-03 source bytes differ but digest field is unchanged | source-binding failure; `rejected_all/fail_closed` |
| T13 | EHP-04 `fixture_status=not_executed` | `terminal_deferred`, `no_publish`, `formal_credit=none` |
| T14 | Executed fixture missing owner, ACL, command, exit, UTC or stream hash | fixture closure failure; `rejected_all/fail_closed` |
| T15 | Receiver emits per-packet ACK before durable quarantine | transaction invariant failure; no accepted decision |
| T16 | Independent reviewer equals packet owner/receiver/verifier publisher | separation failure; `rejected_all/fail_closed` |
| T17 | Retry rejected bytes with fresh request/bundle/nonce and valid next sequence | accepted only if all checks pass; old set remains rejected |
| T18 | Retry changed bytes with old idempotency key | replay/identity failure; `rejected_all/fail_closed` |
| T19 | All frozen external owners/endpoints remain absent | `terminal_deferred/typed_absence`; no send |
| T20 | Verify schema, schema digest and raw receipt manifest | deterministic hashes and closed-key audit pass |

