# VNext T1 canonical bytes V2 R4 independent replay preflight

Status: `preflight_only`; accepted: `false`; claim ceiling: `contract_only`.

The frozen runner is prepared for one independent second Julia process using
`vnext_t1_canonical_bytes_v2_replay.jl`. The replay reconstructs and checks a
small payload, invalid UTF-8 payload, exact canonical JSON, nested
NamedTuple/Tuple projection, and the same 8,269,445-byte Vector raw/base64
digests reported by R3. It does not run the full R3 test file.

The runner uses an independent atomic lock and receipt directory, requires
zero Julia/DESC processes before starting, forces `JULIA_NUM_THREADS=1`, waits
at most 300 seconds, starts once without retry, kills only its owned process
tree on timeout, captures streams and hashes, and requires two postflight zero
process observations 250 ms apart.

Only Python checks, PowerShell parser validation, and frozen-file size/hash
validation are permitted for this preflight. No Julia or DESC process is
started here. A future successful R4 receipt would remain definition-only
local replay evidence and would not grant T1 or UP1 completion credit.
