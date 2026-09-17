# E2-N06 focused R8

Verdict: `runtime_failed`.

Frozen source/test/fixture/runner hashes matched before the single run. Main PID `37060`; UTC `2026-09-14T05:27:19.355459Z` to `2026-09-14T05:28:23.388901Z`; real exit `1`. Raw stdout/stderr byte counts and SHA-256 are in `receipt.json`. Observed child PIDs: `[17324, 75116, 77624]`. Postflight Julia/DESC sweep: `empty`. Protected dirty before/after hashes match: `True`.

The upstream groups passed `47/47`, `21/21`, `57/57`, `59/59`, `8/8`, `49/49`, `35/35`, and `23/23`. The N06 group reached the positive actual-A projection and returned `24 passed, 0 failed, 1 errored, 25 total`: `ArgumentError: N06 mapping is structurally inconsistent: conversion_same_dimension_mismatch` from `n06_mapping_from_a` source line 593 while constructing the mapping at test line 196. This is a new runtime failure after the R8 destructuring repair, and is recorded in `failure.md`.

R1-R7 raw failures remain immutable. This run grants no B04/provider/mesh/engineering/physical/R01-R10 credit. The raw failure is final for this round and no retry was made.
