# AD-26 R2 independent static review commands

All commands were read-only except creation of this independent_review_r2 archive. No Julia or DESC was started.

- Current process sweep: `Get-CimInstance Win32_Process -Filter "Name='julia.exe' OR Name='desc.exe'"`; observed count `0`.
- JSON parse and control scan: inline Python QA; exit `0` (`json_parse=0`, `control_scan=0`, `bad_count=0`).
- Snapshot text check: inline Python QA; `after_text_occurrences=1`, `before_text_occurrences=0`.
- Planning validation: `python docs/v4_multitopology_generation/validate_plan.py`; exit `0`, 31 markdown files, 329 relative links, acyclic DAG, no errors.
- Scoped whitespace check: `git diff --check -- docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md docs/v4_multitopology_generation/README.md docs/v4_multitopology_generation/16_execution_work_orders.md docs/implementation/AD-26`; exit `0` (existing LF/CRLF warning only).

The R1 report and R1 evidence manifest were hash-checked unchanged. No runtime evidence was generated.
