# UP5-01 condition/replay R3 static repair

Status: `screen_only / contract_only / accepted=false / no_publish=true`.

R3 makes the replay result invariant explicit: `:replayed` requires a merged
result with a receipt, while every other status requires zero merge and no
receipt. A real evaluation-hash mismatch now wins before condition status and
returns a `fail_closed` zero-merge result. The incomplete/not-inequivalent
vector also enters the same result hash and validator chain before checking the
saturation guard.

Static QA and JSON parsing are the only executed checks. Julia and DESC were
not run; no runtime, physical, provider, search, UP5, or R01-R10 credit is
claimed.
