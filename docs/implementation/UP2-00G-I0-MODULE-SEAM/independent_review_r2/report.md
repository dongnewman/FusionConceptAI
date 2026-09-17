# G-I0 independent static review R2

Verdict: **changes_requested**. This is a static review only; Julia/DESC and the G-I0 runner/probe were not started.

The frozen entry, test, runner, and failure probe hashes match the requested values. The entry retains G1/G2/G3-first order, stable UP2 sentinels, loaded no-op idempotence, terminal failed state with fresh-process recovery, and no provider/compiler/solver/mesh/physical execution call. The repaired runner manually includes the real counter before the shared loader, verifies exact type identity after loading and after the second call, and the isolated probe supplies the real layer order and no-op component loader before a deliberate later base-type failure. It checks the partial counter sentinel, `:failed`, and same-process retry refusal.

The protected dirty-file hash set and repair after snapshot were independently recomputed. The prior independent R1 review artifacts remain present, including its changes-requested findings. The zero counter is explicitly a constructor/static wiring check and is not treated as a downstream spy.

One provenance blocker remains: the task-supplied AD25 after hash is `85e74c8514867aba366d8995b28a556b090df2399e7cfaeb052359290498c260`, while current AD25 bytes hash to `a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713`. Current bytes match `repair_r2_after.json` but do not match the explicitly frozen dispatch hash, so this review cannot return `ready_for_focused_r1` until that core snapshot boundary is reconciled. No file was changed by this review.

`status=review_pending`, `accepted=false`, and all UP2/B00/B04/provider/mesh/engineering/physical/R01-R10 credit flags remain closed. Independent command receipts are in [command_receipts.json](command_receipts.json), structured evidence is in [report.json](report.json), and this review's manifest is [evidence_manifest.json](evidence_manifest.json). Static QA commands were recorded with real exit/stdout/stderr/timestamps.
