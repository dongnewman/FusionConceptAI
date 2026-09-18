# VNext T1 canonical bytes V2 local profile R4 independent replay

Status: `runtime_complete`; accepted: `false`; claim ceiling: `contract_only`.

The original R4 lock and `run_*` directory were copied byte-for-byte from
`local_profile_r4_replay_preflight/` after the serialized independent replay.
The receipt records one Julia start, no automatic retry, exit code 0, and
149.8664493 seconds. All 14/14 assertions passed; 19/19 protected files were
unchanged, and Julia/DESC process counts were zero before execution and in both
postflight observations.

The independent process reproduced all six stable R3 record fields: schema,
version, encoding, length, raw SHA-256, and base64-text SHA-256. For the
8,269,445-byte Vector, the raw digest was
`23c9ceea243a80d1a4dfda9b355038ac2352e144c6dff8fd40d9f3904fa2484c`
and the base64-text digest was
`1bd44c97ae64c380363e1fb4ddfe5ffa44d2e1422d8b78ad5f601c9fb9869e0b`.

This closes only the carrier slice's independent local replay check. V2 is
still not connected to production T1 admission. R4 grants no T1, UP1,
provider, numerical, physical, engineering, L4, or final-authority credit.
