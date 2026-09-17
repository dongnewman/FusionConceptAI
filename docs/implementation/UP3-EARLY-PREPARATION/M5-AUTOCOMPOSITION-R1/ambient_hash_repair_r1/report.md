# M5-A to M5-C ambient hash repair r1

Status: complete for the bounded implementation slice; claim ceiling remains screen_only. Actual worker: gpt-5.6-luna / high.

## Change

M5-A no longer probes ambient `canonical_hash` dispatch. `manufactured_auto_composition_hash` now uses the explicit existing `digest256_text(string(payload))` path unconditionally. The M5-A payload projection is also explicit and stable, so loading ConditionalEGraphCanonical cannot replace its semantic projection. M5-B uses the same explicit digest path for its inverse product hash and is rebound to the new M5-A source SHA. M5-C is rebound to the new M5-A and M5-B source SHAs. No formula, owner, provenance, shared canonical implementation, registry, test, or oracle was changed.

## Evidence

The redirected run_03 probe loaded M5-A, built the manufactured composition, recorded hash `722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694`, then loaded ConditionalEGraphCanonical and observed identical payload and hash. It exited 0 with PID 86804. Raw stdout/stderr/combined, hashes, UTC bounds, and the wrapper warning are recorded in validation_receipt.json and run_03_ledger.json.

run_01 collection failure, run_02 assertion failure, and the run_03 PowerShell reserved-PID warning are retained as classified evidence. No failure is overwritten or inferred.

## Rebinding

Old to new source SHA:

- M5-A: e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a -> 284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209
- M5-B: f0dcf8aa0dc199a4e3404ecec1a4f516b899e1cfd523454d698f9afe91553976 -> 477b5a41c1a021fae84aeebaf13e3967c93b001ace7f38746af1ab1212110e59
- M5-C: f53854872c907626047ac582a3a1a804a3c87e6aae537522418a81328076f1b8 -> 7a1f52a96a7a79061b1e4bdb0fc1b7b41de5e45266d0ac4726a50502a4dc6500

The M5-A composition product hash remains 722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694. Old M5-A/B/C source-bound receipts and downstream joins are invalidated and require replay; no new formal test-suite credit is claimed.

## Boundaries

No Julia formal test suite, S3, DESC, mesh, solver, engineering, physical, UP3/4/5, B00/B04, R01-R10, L4, or parent-goal credit is claimed. The independent reviewer must inspect this bounded slice and the preserved failures.

