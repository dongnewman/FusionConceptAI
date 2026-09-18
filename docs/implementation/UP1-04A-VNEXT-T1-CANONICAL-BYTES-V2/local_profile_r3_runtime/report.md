# VNext T1 canonical bytes V2 local profile R3 runtime

Status: `runtime_complete`; accepted: `false`; claim ceiling: `contract_only`.

The original R3 lock and `run_*` directory were copied byte-for-byte from
`local_profile_r3_preflight/` after the serialized run. The receipt records
one Julia start, no automatic retry, exit code 0, and 155.2198949 seconds.

All testsets passed: 77/77 assertions in total. The 8,269,445-byte Vector case
reported raw SHA-256
`23c9ceea243a80d1a4dfda9b355038ac2352e144c6dff8fd40d9f3904fa2484c`
and base64-text SHA-256
`1bd44c97ae64c380363e1fb4ddfe5ffa44d2e1422d8b78ad5f601c9fb9869e0b`.
The receipt also records 18/18 protected files unchanged, zero Julia/DESC
processes before execution, and zero in both postflight observations.

This proves only the local definition-only V2 carrier test process. V2 is not
connected to production admission, and R3 grants no T1 or UP1 completion,
provider, numerical, physical, or engineering credit. An independent second
process replay remains required.
