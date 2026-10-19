# Independent UP2 V20 postrun audit

Verdict: **NO-GO for another V20 replay on the current frozen source.** The recorded run has two distinct blockers: (1) cleanup/RSS observation is incomplete, so the controller correctly stopped with `resource_interruption/124`; and (2) the producer reached a deterministic state-hash guard that compares two different hash definitions. No validator or consumer was reached. This is not numerical or physical evidence.

## Frozen identities and replay record

- Protocol `docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r20/replay_protocol_v20.json`: SHA-256 `26690948566c5191994e2d2ae3cbf94e7d9f481f8adf7e88962b128792d61dc2`.
- V20 Julia entrypoint SHA-256 `de982105ea005b0e9e2f5b52c2a3a23e38e6691563cfd8497043109767538c06`; Python controller SHA-256 `5340b60371e2e59fc9b20f0ada0023af3574c241685df1db079d734c2c78a410`.
- The recorded Julia producer command is in `runtime_replay_r20/producer_process.json`; it passed the V20 protocol SHA above. The reviewer did not launch Julia.
- Outer final: controller exit `124`, classification `resource_interruption`, solver/numerical fields preserved as exit `2` / `fail` / `stationary_nonzero_residual`, authority `no_publish`, physical validation `unsupported`, nonlinear solver calls `0`. These solver fields describe the earlier saved numerical result; the V20 replay child itself exited `1`.

## Process cleanup and resource status

The producer stage recorded exit `1`, stop reason `cleanup_unconfirmed`, wall time `259.82886090001557 s` (under the 480 s stage limit), and 934 complete RSS samples with sampled peak `1,152,794,624 B` (below 2 GiB). Sampling then became incomplete: `rss_sampling_complete=false`, with `NoSuchProcess` for root PID 80036. Cleanup separately records a root-process lookup `NoSuchProcess` for the captured `(pid=80036, create_time=1790353289.44393)` identity, `process_tree_inventory_complete=false`, `termination_confirmed=false`, and `termination_wait_succeeded=false`. The empty remaining/terminated PID arrays are not cleanup proof while inventory is incomplete. Aggregate child wall spent 259.8288609 s of 960 s with zero measured overrun, but aggregate status is `cleanup_unconfirmed`; controller overhead was within its 120 s limit.

The controller classifies resource interruption before its `replay_hydration_unsupported`/`program_exception` branches (`run_replay_staged_v20.py` producer classification around lines 3945–3954). Thus outer `124/resource_interruption` is the monitor/cleanup outcome; it must not replace or erase the actual Julia exception below. The recorded `producer_tree_comparison_status` is `not_reached` and `producer_tree_unchanged` is null.

## Independent V10 hash-definition crosscheck

The stderr says `saved result state hash differs from protocol` at `replay_staged_v20.jl:850`. I independently rehashed the V20 numerical-result pin and its solver-attempt artifact, then compared their exact V10 values:

- V10/V20 protocol `preserved_identity.state_after_hash`: `464534cafdcecbbf215c656843349faa88a4ea3120e58d4cf79345a71bd89662`.
- Pinned `solver_attempts.json` SHA-256: `70f659c3f7da76e0db00ee9c8cf5cfd46f03f5342c51266a5df8d9b0471f5efb`; its `last_attempt.state_after_hash.value` is the same `464534…89662`.
- Pinned `numerical_result.json` SHA-256: `429d500e4d42d2ae8c6af9ab88f8b9b0a7a59dc1e5da1853c9dfa6b5bd6a10e7`; its case metadata `state_hash.value` is `b36d2109eba29fdced93e09f2730fb785860f203d4cf9d39f2dedf43e94fb5d7` (final state has 40 entries).

The source confirms these hashes have different meanings. `SpatialMultiRegionV4.jl:651` defines solver-attempt `state_after_hash` as `canonical_hash(Tuple(x))`, a final-state-vector digest. At line 834 it forms the case `statehash` from a NamedTuple containing candidate hash, context hash, case id, level, flux, and final state; line 903 stores that metadata-bound digest in `case.state_hash`. Lines 1167–1168 recompute and validate the case-bound digest. V20 line 850 compares the case-bound `c.state_hash` to the protocol's final-vector `state_after_hash`, although the persisted artifact proves the latter matches the last solver attempt exactly. This is a wrong binding comparison, not a remaining JSON representation/order mismatch.

The smallest source correction is to compare the protocol's `state_after_hash` with the digest of the typed final state vector, while retaining the separate case-bound `c.state_hash` check. Do not relabel the vector hash as the case digest. This repair needs a new frozen source/protocol identity and fresh independent review before another replay.

## Producer stage boundary and input integrity

The output has exactly one recorded stage, `producer`. The completed hydration receipts reach `typed_wire_encoding`; the next post-hydration identity guard at line 850 fails. The full validator begins later at line 859, and there is no `producer_validator_started.json`, `producer_full_validator.json`, `producer_complete.json`, consumer directory/receipt, or consumer stage. `M.result_tests` was not reached.

Independent Python audit rehashed **952 pins with zero mismatches**: all 725 current files in `inputs_before.json` matched both before/after snapshots and the live workspace; all 89 staged V10 inputs, 13 replay inputs, 119 saved-tree entries, four V20 owned-source pins, and the V10 actual replay protocol also matched. The three 725-entry snapshots (controller before, controller after, producer after) agree. This supports `inputs_unchanged=true`; it does not convert `producer_tree_comparison_status=not_reached` into a completed output-tree immutability check.

## Exact independent audit command

`D:\Users\Newman\anaconda3\python.exe -B D:\006-Programing\LMC\FusionConceptAI\docs\implementation\UP2-04-CLOSURE-REPAIR-PREC\archive\independent_replay_v20_postrun_audit_fec_reference_audit_r1_20260926\audit_v20_postrun.py` — exit `0`, 952 pin checks, 0 errors. The reviewer ran no Julia, FreeGS, producer, consumer, or Python contract suite.

The independent receipt, script, and runtime inventory are sealed in this leaf. The exact saved raw stderr/stdout and all process metadata remain in the owner runtime leaf.
