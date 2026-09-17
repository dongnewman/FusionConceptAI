# UP5-01 condition/replay R2 static repair

Status: `screen_only / contract_only / accepted=false / no_publish=true`.

R2 upgrades the isolated test from marker-only coverage to real calls after the
isolated include. It exercises `evaluate_conditions`, `replay_merge`, the cold
and hot cache functions, replay receipt/result validators, and the saturation
incompleteness seam across all 17 frozen negative vectors.

The implementation now rejects inconsistent condition status/reference sets,
checks token generation as part of stale detection, requires exact trace
evaluation hashes, gives replay receipts and results independent canonical
hashes, and recomputes those hashes in validators. Identity failures return a
typed `fail_closed` zero-merge result; malformed direct constructors remain
exceptional.

Static QA and JSON parsing are the only executed checks. Julia and DESC were
not run, and no runtime, provider, solver, physical, search, UP5, or R01-R10
credit is claimed.
