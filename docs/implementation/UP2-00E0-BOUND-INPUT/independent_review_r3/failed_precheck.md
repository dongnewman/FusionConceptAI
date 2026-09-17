# R3 failed prechecks and capture attempt

At approximately 10:28:07 the first static control script used the public delegating function as its text slice and reported two false checks. The original script/output bytes were overwritten while correcting the slice to the private helper; append-only provenance for those original bytes is unavailable. The corrected static control is retained separately and passed.

A first independent runner capture was then attempted after a clean preflight and produced only a partial stdout log (the G1/G2/G3 prerequisite summaries), with no exit, process, or environment receipt generated. Its exit is unknown and it is not treated as a pass. The partial stdout/stderr are preserved with the partial suffix. A fresh unique capture attempt is required; its command must synchronously seal PID, start/end, real exit, stdout/stderr, and post-process state.
