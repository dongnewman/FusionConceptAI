# Evidence maps

| Requirement | Oracle | Julia test | Evidence |
|---|---|---|---|
| deterministic canonical hash/replay | `canonical_hash`, `replay` | payload/hash and replay sets | `raw/python_oracle.stdout.raw` |
| eight typed conditions | `KINDS` | `M5CEG_CONDITION_KINDS_V1` catalog assertion | report; Julia blocked before collection |
| unmet condition zero merge | `evaluate` | missing/mismatch catalog controls | report; Julia blocked before collection |
| budget incomplete | `bounded` | zero attempts/rounds/trace controls | report; Julia blocked before collection |
| contradiction fail-closed | `evaluate` | duplicate/conflicting catalog controls | report; Julia blocked before collection |
| M5-A/M5-B joins and boundaries | n/a | upstream owner/provenance/hash assertions | report; Julia blocked before collection |

The Julia rows are planned assertions only because source parsing failed before
the test body could execute. They are not presented as passing evidence.
