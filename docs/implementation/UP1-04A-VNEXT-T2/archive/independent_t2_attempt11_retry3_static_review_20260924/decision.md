# T2 attempt11 retry3 independent static review

Decision: **NO-GO for bounded runtime dispatch**. Read-only review; no Julia was started and no owner source/test/controller was modified.

## Frozen identities

- Protocol: `5731a35854292096feafb1838cfd1ff2811d62f1eccc6a150246b160928bd1e0`
- Coverage map r8: `9fb16233ae8c0c4373781450c3f1bffedd3373f4e5a6e44f34f804132f93df41`
- Static QA: `c0770174cb2e363ee1a901e6f1c87e4aa3688a1a5a551a2a979b00492d13061c`
- Controller r10: `a80b3e1b92b040ab645569abbabd63fc4597b9d7419e1c20d91db4c0c5566152`
- Driver r6: `5a71c6417cadd04c3f36f8461134de46f455debdf7c6e9f804181c589c3b590e`
- Root launcher: `5d6cf4c135bdc2ece734fbfe8ab0fd10e3e6025021a10eda457eec1634c6cccf` (AST checked; ungranted/unrun)

## Verified static scope

All 368 current protocol inputs rehashed; all 104 R3 pins join by exact path, bytes and SHA. The 214 unique coverage sites resolve to frozen source path/line/text/SHA, and per-site phase obligations sum to 622. The map retains 191 sites/530 hits and 23 context-transport sites/92 hits. It contains 60 unique cases and 68 planned runtime case hits; 45 IDs are in the five formal phases, in a 30-phase order. From attempt9c, 175 driver sites move r3→r6 and 39 supplementary sites remain; all source hash, multiplicity and phase-hit semantics match. Compared with attempt10 map r7, all 214 path/line/semantic records match.

Attempt10 preflight remains an incomplete resource interruption: exit 15 at 480.17 seconds after 16/18 cases, leaving `FEEDBACK_STALE` and `FEEDBACK_FOREIGN`. It grants no partial reuse or credit. Retry3 overrides only `actual_formal_preflight` to 600 seconds; other formal phases remain 480 seconds, authority phase/case caps 2400 seconds, process-tree threshold 2 GiB, and Julia/OpenBLAS threads one. Frozen static QA reports 131 negative controls, actual hits pending and formal acceptance false. The separate projection24 Python child naturally exited 0 with the 24-site/four-group marker; that is prior reuse evidence, not T2 execution.

## Blocking finding

Controller r10 is fail-open when process-tree resource observation is incomplete. `process_tree_sample` lines 205–233 ignores descendant-enumeration errors and skips per-process RSS/CPU errors. `run_phase` lines 279–285 compares the partial RSS sum to 2 GiB. `heavy_processes` lines 184–202 skips process inspection errors; `kill_tree` lines 236–249 suppresses descendant enumeration and kill errors without proving every descendant exited. Static QA lacks injected controls for these observer/termination failures.

Version the monitor so incomplete enumeration, RSS sampling, termination, or residual scanning becomes typed `resource_monitor_incomplete` and blocks later phases. Add deterministic negative controls for each path. Keep the full case/site/hit plan, thresholds and time budgets unchanged.

Independent pin/source-map audit exit 0; root launcher SHA/AST inspection exit 0; independent process-name scan with tasklist fallback exit 0 and no Julia found. The owner freeze/QA receipts state exit 0; QA was not rerun because it writes into the frozen leaf. No actual negative shard or source-site hit was produced.
