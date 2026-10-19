# T2 R19 actual-run independent postrun audit

Verdict: **runtime NO-GO**. The baseline phase failed closed with `process_tree_monitor_incomplete`; no formal negative shard ran and no T2 acceptance was produced.

Protocol SHA-256: `1b0e6f4e2267b32c83195b7cf0cf0b92c3b8d356b8fd69b6840f3cfdcf6810b8`. Current protocol inputs: 655/655 matched; positive reuse pins: 104/104.

Completed phases: parse gate, AST inventory and Projection24 each exited 0; `actual_formal_baseline` exited 15 after 48.754 s. Peak sampled working set was 819,822,592 bytes against the 2 GiB cap. The baseline produced 161 samples, with sample completeness false.

The final sample recorded `MonitorIncomplete: cannot open a process absent from current SPI snapshot`. Its `native_snapshot_before_digest` contained direct child `git.exe` PID 18528 / PPID 86060 / FILETIME 134348254310869192, absent from the two tracked identities. The supervisor terminated and verified both tracked processes (exit 15); its final audit was complete for those two tracked identities and reported no residual descendants.

No `Test Summary` was emitted, the actual source-site hit total is null, and preflight/authority/fault-N10/T1 negative shards are absent. This is a monitor interruption, not an assertion/numerical result. The outer shell exit 1 is reported by root; no separate invocation receipt was found in this checkout. This audit itself only read files and did not launch Julia.
