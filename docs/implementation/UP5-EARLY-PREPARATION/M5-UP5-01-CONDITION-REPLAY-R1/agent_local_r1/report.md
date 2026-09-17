# UP5-01 condition/replay contract-only additive slice

Status: `screen_only / contract_only / accepted=false / no_publish=true`.

This slice adds only the isolated condition environment, merge replay receipt,
saturation incompleteness guard, and cold/hot canonical cache contract. It does
not change the shared entry point, default registry, task manifest, evidence
authority, or manufactured M5-C adapter.

Static QA is the only executed check. Julia and DESC were not run. The focused
Julia test is prepared for the serialized parent lane and must not be treated as
runtime, physical, provider, search, or R01-R10 evidence.

Static QA result: exit `0`, `status=pass`, `negative_vector_count=17`,
`julia_executed=false`, `desc_executed=false`. `git diff --check` reported no
new whitespace error; existing CRLF warnings were unrelated dirty files.

The exact input hashes are recorded in `manifest.json`. They are a static
baseline only and are not an execution receipt.

Required later runtime evidence includes condition-met replay, unmet/unknown and
contradiction fail-closed cases, all seven semantic axes, stale/foreign identity
negative cases, cold/hot byte/hash equality, fresh-process determinism, and the
rule that incomplete saturation cannot imply inequality.
