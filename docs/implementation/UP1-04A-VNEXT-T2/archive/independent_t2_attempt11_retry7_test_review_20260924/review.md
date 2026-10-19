# Independent T2 attempt11 retry7 static/process review

## Decision

**NO-GO for a retry7 T2 runtime launch.** The frozen Python static QA passes, but an independent malformed process-time control is accepted as a complete sample. `process_tree_sample` accepts `create_time=True` as the same generation as expected `1.0` (`True == 1.0` in Python); it also accepts a child timestamp of `True` or `+inf`. `_process_table_snapshot` rejects boolean time and absent fields but accepts `+inf` when its live recheck returns `+inf`. This violates the requested malformed-bool/time fail-closed control. Fix the validation and add source-targeted negative controls before any retry7 runtime grant.

This is a process-monitor contract finding, not a result from Julia, DESC, the solver, or a formal T2 case. No Julia or solver was started. This review grants no scientific, physical, formal, or acceptance credit.

## Scope and frozen identity

Reviewer task: `/root/mms_closure/oracle_review` (independent tester). Repository HEAD from `git rev-parse HEAD`: `63792ca22958ffca8c3fa8e642256eb9f7240724`, matching the frozen protocol. Protocol `docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry7/protocol.json` is 723,930 bytes, SHA-256 `c271961cdf6d5549a3167a1ce17527688f63a3a39688a07ca6e4b16db145f8b3`.

The fresh static QA rehashed all 393 protocol inputs and passed. Key source/pin identities are in `manifest.json`. Controller r12 is pinned to SHA `04c85a30d4f7a1f15c8c9016cc1b4000259d89a2a1b0ea337867e5e2a52e85ac`; static QA r12 is `f196e0bfc79d40d70875fdf2644774715483f02dc57ebcb64404b614bb3adf4b`; projection validator r5 is `4cc51a6e16591d2e55a93a1bc5fb6dde6752ee808419d6768b372e5abe510849`.

## Commands and checks

1. Fresh frozen static QA, using `python.exe -B test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r12.py` with the frozen protocol SHA, dispatch and non-executable argv record, writing only `static_qa_fresh.json` under this review leaf: **exit 0**. Captured stdout: 60,880 bytes, SHA-256 `a28c368f762bfcc0fd9b89fb5ae4296c96d2d4d8625238254e159e95cb156fdf`; stderr empty, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. The structured report says `status=pass`, 153 negative controls, `julia_executed=false`, `julia_parse_executed=false`, and `formal_t2_accepted=false`.
2. Fresh process-monitor fake controls and targeted inline Python probes, invoked as PowerShell here-string input to `D:\Users\Newman\anaconda3\python.exe -B -`: **exit 1 (finding)**. Raw output is `process_controls_expanded.stdout.raw`, SHA-256 `054252e703d2172366a8f48a8298207f6c67847d9109e7ba83ec755a40c4a25a`; stderr empty. The return code is 1 because malformed timestamps were accepted. The built-in `verify_r12_process_monitor_contract` passed its 25 synthetic controls. Targeted results:
   - Popen A `(pid=41001, time=1.0)` vs lookup B `(same pid, time=2.0)`: rejected.
   - Process-table snapshot generation A then lookup generation B with stable PID set: rejected by built-in control as incomplete.
   - Missing sampled RSS, process-table `create_time`, or process-table `ppid`: incomplete/rejected.
   - Root sampled `create_time=True` with expected `1.0`: `sample_complete=true`.
   - Child sampled `create_time=True` and child `create_time=+inf`: `sample_complete=true`.
   - Process-table `create_time=+inf` with matching live lookup: `complete=true`.

   The shorter first reproduction is also preserved as `process_controls_fresh.stdout.raw` (exit 1, SHA-256 `e6faa1f9c192704258416e833d02540f150edcf4ea394cdd07c2c748d2d0e0bc`).
3. Fresh projection24 reuse validator, using `python.exe -B .../validate_projection24_reuse_r5.py <frozen protocol> <review-leaf receipt>`: **exit 0**. stdout 312 bytes, SHA-256 `410386b0bd955d7ba970976db1bef4354be452d2e4f2dcf5437c9ca75ae66ffd`; stderr empty. Fresh receipt SHA-256 is `1e621d5e849f6736e15d79f90e488d43baa79e64a5e00b3f060add44ac81a0a0`, byte-identical by digest to the pinned receipt. Its source reuse checks report 159 dependencies, 151 exact current-input intersections, and 6 excluded historical inputs, while all acceptance flags remain false.
4. Repository identity check `git rev-parse HEAD`: exit 0, output `63792ca22958ffca8c3fa8e642256eb9f7240724`.

Exact argv, working directories, stdout/stderr paths, and exit codes for the file-backed QA and projection validator are recorded in the per-command JSON receipts. The targeted process fake was run from transient stdin; no helper source was saved into the archive.

## Resource gates, coverage, and case scope

The frozen controls remain: ordinary phase cap 480s; `actual_formal_preflight` override 600s; authority phase and per-case caps 2400s; process-tree working-set limit 2,147,483,648 bytes; Julia and OpenBLAS thread counts 1. The phase-sum declaration is 16,440s for 30 phases, explicitly excludes setup/interphase/finalization overhead, and explicitly does **not** enforce a single end-to-end controller timeout. Treat this as bounded per-phase execution, not a total-wall guarantee.

Coverage map `test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r10.json` is 600,012 bytes, SHA-256 `d7f79b06d3f0cbf505d5321857767f40157ae0d38dc2706b989edaf8d97449c6`, and matches the protocol. The static QA confirms 60 runtime cases, 68 planned runtime case hits, 214 assertion sites, and 622 planned assertion hits; the attempt7 semantic case/site equality is retained. Actual Julia source-site hits remain `pending_julia_execution`, and the four-shard protocol remains `frozen_not_executed`.

`FEEDBACK_STALE`, `FEEDBACK_FOREIGN`, parent/G3 stale and foreign cases, and the foreign-scenario case are in the frozen phase/case plan. Authority receipt validation is explicitly `pass_synthetic_receipts_only`: its 10 negative receipt controls reject missing/extra/wrong source hits and wrong case identity; partial or mismatched child receipts cannot be reused. These are static/synthetic checks only. No real T2 authority receipt or feedback case was executed.

The separately rerun projection24 preflight is a Python consumer-validation command, not a T2 solver shard. The frozen historical phase is `natural_exit`/0, 300s timeout, with Julia not started; the fresh cross-run validator exits 0. It carries no formal/scientific/physical acceptance.

The planned T2 output leaf `docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r6_attempt11_retry7` was absent during this review. The review archive contains only evidence/data files (`.md`, `.json`, `.raw`, `.txt`), no executable/helper payload. Frozen protocol/source/evidence files were not edited by this reviewer.

## Required narrow correction before retry

Reject booleans and require finite positive timestamps at each sampled and process-table identity ingestion point, including descendant `create_time` values, before equality, set membership, or serialization. Add negative controls for root and descendant sample `True`/`NaN`/`+inf`, process-table `NaN`/`+inf`, and exact A/B identity mismatch. Keep missing resource fields and inaccessible process data incomplete. Then freeze a new version and rerun static QA; do not reinterpret this static review as T2 execution or acceptance.
