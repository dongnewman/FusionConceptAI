# G-I0 independent static precheck R4

Verdict: **ready_for_focused_r2**. This is a static repair precheck only; Julia/DESC and the corrected runner/probe were not started.

The prior runner hash `db1fd47e395d748ffed5205c1ed00be87a1dc63d684ce85e792b6f44632598d2` is preserved in `repair_r3_before.json`; the current runner hash is `2847d1b98455a2fb4186be491cc00c09e5f475f83e14e1b26b7a246bf4b19cab` and `repair_r3_after.json` records exactly one token change, `$FAILURE_PROBE` to `$_FAILURE_PROBE`. The corrected runner passes the failure probe's intended source path `$(joinpath(_UP2_ROOT, "UP2ModuleEntryV1.jl"))` statically, while no probe process was started in this review.

Entry, test, probe, and core18 hashes match. Protected dirty hashes match. The original focused R1 raw exit-1 receipt/logs and correction note remain, as do independent review R1-R3 archives. Status remains `review_pending`, `accepted=false`, and all UP2/B00/B04/provider/mesh/engineering/physical/R01-R10 credit remains closed.

JSON parse, `validate_plan.py`, `git diff --check`, and a read-only Julia/DESC process sweep were recorded with real exit/stdout/stderr/timestamps in [command_receipts.json](command_receipts.json). Structured evidence is in [report.json](report.json), and this precheck's manifest is [evidence_manifest.json](evidence_manifest.json).
