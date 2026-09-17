# R9 audit checker correction

The first local checker pass was `changes_requested` because its typed-occurrence stdout assertion assumed one exact spacing pattern (`3     3`); the immutable raw line contains equivalent aligned whitespace (`3      3`). The first JSON/command receipts are preserved as `report_initial_changes_requested_spacing_false.json` and `command_receipts_initial_spacing_false.json`.

`run_audit.py` was corrected to use whitespace-tolerant matching, then rerun. The corrected audit still uses the immutable R9 receipt and raw logs, and reports `failure_audit_open_gate`; this checker correction does not alter the R9 runtime result or the open test-only gate.
