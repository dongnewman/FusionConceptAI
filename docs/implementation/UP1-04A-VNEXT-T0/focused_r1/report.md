# AD-30 T0 focused R1 attempt

The exact focused command was started once after the R5 independent precheck
passed. The capture wrapper failed immediately after `Process.Start()` because
PowerShell rejected assignment to its read-only `$PID` variable. The Julia child
PID, raw stdout/stderr bytes, and Julia exit code were therefore unavailable.
The command was not rerun, as required by the serial focused-run contract.

This is a harness failure with Julia result `unknown`, not a Julia pass or
failure. The first real error is recorded verbatim in
`process_capture_error.txt`; `run_metadata.json` records the exact command,
input hashes, pre/post dirty count, and post-process check.

Post-attempt static QA, JSON validation, and `git diff --check` passed. No T0
acceptance credit, T1 go, provider/mesh/physical credit, or R01-R10 credit is
created. An independent Luna must review this failed capture attempt before
root decides whether an externally authorized retry is appropriate.

