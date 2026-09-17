# UP1 R3 atomic contract repair test matrix

All rows are future acceptance vectors. This directory remains
`review_pending`, `implementation_status=not_implemented`, and
`formal_credit=none`; the self-test only exercises pre-parse rejection.

| ID | Mutation/vector | Required machine result |
|---|---|---|
| R01 | Every packet-position `allOf` receives an unknown nested key | Draft2020-12 schema error; `rejected_all`; `SCHEMA_INVALID` |
| R02 | Add a fifth packet or alter `packet_order` | `PACKET_ORDER_MISMATCH`; `rejected_all` |
| R03 | Use `signature_digest` or `payload_digest` in any preimage table | `CANONICAL_EXCLUSION_NAME_INVALID`; `rejected_all` |
| R04 | Set receipt `bundle_id` differs from envelope | `SET_BUNDLE_ID_MISMATCH`; `rejected_all` |
| R05 | Set receipt `request_id` differs from envelope | `SET_REQUEST_ID_MISMATCH`; `rejected_all` |
| R06 | Set receipt packet digest array differs byte-for-byte | `SET_PACKET_DIGESTS_MISMATCH`; `rejected_all` |
| R07 | Packet repeated `shared_binding` differs | `PACKET_SHARED_BINDING_MISMATCH`; `rejected_all` |
| R08 | Quarantine receipt omits raw object/blob digest, size, immutable locator, CAS transaction, durable UTC, or receiver signature | `QUARANTINE_RECEIPT_INCOMPLETE`; `rejected_all` |
| R09 | `verification_started_utc` precedes durable commit | `QUARANTINE_NOT_BEFORE_VERIFY`; `rejected_all` |
| R10 | Raw bytes hash differs from quarantine `raw_object_sha256` | `QUARANTINE_RAW_DIGEST_MISMATCH`; `rejected_all` |
| R11 | Decision receipt has no CAS transaction/receipt digest binding | `DECISION_NOT_BOUND_TO_QUARANTINE`; `rejected_all` |
| R12 | EHP-03 source, G2 mapping, or authority candidate differs | `EHP03_CANDIDATE_BINDING_MISMATCH`; `rejected_all` |
| R13 | EHP-03 source digest, edge source digest, or authority source digest differs | `EHP03_SOURCE_BINDING_MISMATCH`; `rejected_all` |
| R14 | EHP-03 axis set is not exactly the four shared axis IDs | `EHP03_AXIS_SET_MISMATCH`; `rejected_all` |
| R15 | EHP-03 forward/reverse edge multisets differ, or duplicate edge identity exists | `EHP03_GRAPH_BIJECTION_FAILURE`; `rejected_all` |
| R16 | EHP-03 mapping is ambiguous, empty, or lacks both directions | `EHP03_G2_MAPPING_MISMATCH`; `rejected_all` |
| R17 | EHP-04 expected context or outer authority differs from shared binding | `EHP04_CONTEXT_BINDING_MISMATCH`; `rejected_all` |
| R18 | EHP-04 runtimes are not exactly one Julia and one Python | `EHP04_RUNTIME_SET_MISMATCH`; `rejected_all` |
| R19 | EHP-04 import/lock identity tuple repeats | `EHP04_IDENTITY_MAP_DUPLICATE`; `rejected_all` |
| R20 | EHP-04 SBOM component ID repeats or dependency endpoint is absent | `EHP04_SBOM_COMPONENT_DUPLICATE` or `EHP04_SBOM_EDGE_ENDPOINT_MISSING`; `rejected_all` |
| R21 | EHP-04 binary candidate or download subject digest differs | `EHP04_BINARY_BINDING_MISMATCH`; `rejected_all` |
| R22 | EHP-04 `not_executed` fixture | `terminal_deferred`; no publish; `formal_credit=none` |
| R23 | Duplicate JSON key, non-finite number, or invalid UTF-8 | pre-parse code; `rejected_all` |
| R24 | All predicates pass but external security outcome is absent | `terminal_deferred`; never `accepted_all` |
| R25 | All predicates pass, executed fixture, and caller supplies pinned `security_ok=true` | `accepted_all` is derivable; no authority credit is implied |

`verifier-predicates.json` is the machine-readable closure index. `verifier.py`
implements the predicates and stable error codes offline. R01--R25 are not
reported as executed until a future independently reviewed implementation
provides concrete fixtures and cryptographic/trust evidence.
