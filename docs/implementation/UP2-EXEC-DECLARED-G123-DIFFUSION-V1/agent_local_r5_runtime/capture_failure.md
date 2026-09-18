# Capture failure — agent_local_r5_runtime

The approved Julia command was started once with `JULIA_NUM_THREADS=1`.
Immediately after `Process.Start()`, the PowerShell wrapper attempted to assign
`$pid`, colliding with PowerShell's read-only automatic `$PID` variable. The
wrapper therefore failed before `WaitForExit()`, stdout/stderr draining, PID and
exit-code capture. A process query after the failure found zero Julia/DESC
processes. The command was not rerun.

The six owned source/test hashes are identical before and after. This directory
is an incomplete execution receipt; it is not a Julia pass/fail receipt.
