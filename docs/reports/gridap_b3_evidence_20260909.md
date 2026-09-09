# Gridap B3 evidence report — 2026-09-09

This additive B3 layer wraps the pinned B1 Gridap solve with exact RuntimeV4
capability/provider/subject/solver-input bindings and persists a canonical
replay envelope through `execute_once!`. Hashes bind candidate, prefix,
scenario, residual edge, G2 artifacts, grid, protocol, adapter source, and
qualification lock identity.

The subject mission and bounds bindings are derived from a revalidated actual
candidate/compiled-prefix/Genome-registry context. The provider code hash
binds the actual B3 source bytes, B1 adapter source, and pinned Gridap lock;
runtime drift is rejected. The provider executor is stable across repeated
calls. Cache idempotence and fresh-store deterministic re-execution are tested
separately, including reconstruction and validation of the B1 report.

The ceiling is `screen_only`; evidence is `manufactured_control`, credible
physical candidate count is zero, and `p5_ready=false`. B3 is independent of
B2 and does not claim Batch B completion.

## Definitive pinned run

Focused test: 18/18, exit 0.

Runner command:

`julia --startup-file=no --history-file=no --project=tools/qualification/gridap scripts/run_v4_gridap_field_evidence.jl`

Result: exit 0, `GRIDAP_B3_OK`.

- provider: `f0627fb20342a01e7e731a015c1452b1db1a893a899a8d89ddcf193558b18cdd`
- solver input: `b605c483b7fbec6d4481615d6e98c6a2e949621c15b5929ced76c958b02ee5de`
- evidence: `9169a11621904d8c233152c4d6cee8498f76f89ba4320352ae2f106d92fe01c7`
- replay envelope: `156204abe4153542aa202c1973f670b29f09758b8f5ca1e2714903f8d4629fc6`

These hashes identify the isolated manufactured-control execution only. They
are not physical, engineering, validation, whole-device, or P5 evidence.
