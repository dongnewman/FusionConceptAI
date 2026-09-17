# Additive repair static matrix

| ID | Check | Expected now | Evidence / future gate |
|---|---|---|---|
| S01 | Parse all repair JSON | pass after static parse | validation receipt |
| S02 | Draft 2020-12 meta-schema and closed shape | pass: `$schema`, `type`, `properties`, `required`, `additionalProperties=false` on contract objects | validation receipt |
| S03 | Complete canonical join | pass structurally: G1/G2/G3, parent, mission, scenario, source body/digest/owner/provenance | canonical bundle schema; future value checker |
| S04 | Current-byte gate | pass structurally: historical-only + drift + fresh re-freeze prerequisite; no current pass claim | freeze_gate; manifest |
| S05 | Replay determinism | pass structurally: serialization, field order, UTF-8/LF, rational encoding, C/UTC, environment and seed ledger | replay object; future two serial replays |
| S06 | Feedback causal history | pass structurally: immutable identity, CAS, operation enum, append-only history, before/after hashes | request/result schema; future negative controls |
| S07 | Scope and dirty closure | pass: repair writes are confined to `02-scope-contract-repair/**`; baseline HEAD/status digest retained | preflight raw/process/digest |
| S08 | Runtime prohibition | pass: no Julia/DESC/S3/mesh/solver/provider/hardware/network invocation | process receipt |
| S09 | Historical/current semantics | pass: current authority remains unknown and R1 result historical-only | README/manifest |
| R01 | Fresh source/test/oracle re-freeze | pending, not run here | separate authorized lane |
| R02 | Independent oracle/checker replay | pending, not run here | separate role and raw receipts |
| R03 | Root acceptance | pending | Sol/root decision |

The static checks above are contract checks only. They do not execute M5/M5-A, do not establish a scientific or engineering result, and do not close any UP4 gate.
