# Fresh-process determinism plan

Parent-owned serialized runner only; do not execute from this worker lane.

Launch two independent Julia processes with identical project/startup flags,
each writing a small JSON receipt containing cold and hot equivalence/attempt
bytes, hashes, query status, replay result, and sorted member/proposal key
projections:

```powershell
$outA = Join-Path $PWD 'runs/m5_core_perf_r3_fresh_a.json'
$outB = Join-Path $PWD 'runs/m5_core_perf_r3_fresh_b.json'
Start-Process -Wait -NoNewWindow julia -ArgumentList @('--project=.', '--startup-file=no', '--history-file=no', 'test/RuntimeV4/M4Isolated/m5_core_perf_r3_fresh_process_probe.jl', $outA)
Start-Process -Wait -NoNewWindow julia -ArgumentList @('--project=.', '--startup-file=no', '--history-file=no', 'test/RuntimeV4/M4Isolated/m5_core_perf_r3_fresh_process_probe.jl', $outB)
python tools/compare_json_bytes.py $outA $outB
```

The probe/comparison runner is parent-owned and must be added or supplied in
an explicitly authorized lane; this document does not create it in the
protected test scope and does not run Julia.  A mismatch, exception, timeout,
or missing artifact is `terminal_deferred`/`fail_closed`.
