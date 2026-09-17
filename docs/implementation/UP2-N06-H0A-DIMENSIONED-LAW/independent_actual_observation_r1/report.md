# H0-A actual-A observation R1 independent review

Verdict: `changes_requested`  
Acceptance: `accepted=false`; `review_pending=true`  
Scope: read-only audit of the preserved `actual_a_observation_r1` receipt. This review ran no Julia, DESC, provider, mesh, solver, or physics command and did not alter prior evidence.

## Recomputed identity and execution content

The four primary inputs recorded by `input_hashes.json` are still byte-identical in the checkout: the N06 source (59,585 bytes, SHA-256 `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d`), N06 test (48,902 bytes, `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8`), N06 fixture (1,451 bytes, `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`), and formal runner (299 bytes, `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`). All additional child fixture and G1/G2/G3 input hashes in that manifest also recompute successfully.

`actual_a_observation_r1.jl` calls `load_genome_v5_up2_components!()` once, includes the exact N06 source once, and uses the exact `test/GenomeV5/UP1-04/layer_fixture_child.jl` helper for one G1, one G2, and one G3 child fixture. It does not include `n06_dimensioned_law_tests.jl`. The formal runner's loader/include prefix is therefore reproduced, while the formal N06 test suite itself is deliberately not run. The three child Julia processes are expected fixture construction subprocesses; the receipt's `top_level_julia_runs=1` is accurate only for the observation driver.

The raw output files are internally hashed correctly: `stdout.txt` is 1,576 bytes with SHA-256 `6e2b35df298b3004f43fd195b72bdd52db588d6a629b05e7d5c7cf1f55265ca0`, and `stderr.txt` is empty with SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. `result.json` is 1,623 bytes with SHA-256 `1b092b02aa4656291c46e734e9b536bf81fb4ab7892cf1ec2c4ed31c22b5bdd0`, and every entry in `output_hashes.json` recomputes. The structured result and raw stdout agree on the reported status, gaps, declaration type, and zero counters.

## Observed production result

The source-derived result is coherent and bounded: `status=terminal_deferred`, declaration type `FusionConceptAI.N06H0ATypedAbsentV1`, `declaration_is_nothing=false`, `declaration_gap_code=external_ref_required`, `errors=[]`, and exactly three gaps: `g1_endpoint_provenance_missing`, `external_ref_required:g1-loss:G1`, and `external_ref_required:g2-thermal:G2`. `compile_calls`, `provider_calls`, and `solver_calls` are all zero. Candidate and E0 package hashes are both `0cfe748c66121a69bf818778a92a6bce1f14bf2892f4159326c426bbc1c3a16a`; E0 bound-input hash is `5dc008c66d37f7f810f08ea3b30f8eafd6ca7e5fda2f128a6dd2525e2ff4cd97`.

This supports one source-path software observation. It provides no actual authority, H0-A total, UP2, B00, B04, provider, mesh, DESC, engineering, physical, or R01–R10 credit.

## Receipt and wrapper finding

`run.json` records PID `18040`, exit code `0`, one top-level run, empty stderr, and the interval `2026-09-15T00:38:18.561405Z` through `2026-09-15T00:39:29.303955Z` (the manifest's `+08:00` values are the same instants). The before/after process files are both the empty JSON array, and their hashes recompute.

The wrapper explanation is plausible but not independently sufficient. The receipt says the PowerShell wrapper was interrupted by assignment to the read-only `$PID`, then the same Julia PID was taken over and its result recovered without rerun. However, no preserved wrapper stderr, OS process record, process command line, or PID-to-command observation is present in this directory. The empty post-process snapshot establishes no matching process at snapshot time, but it does not independently establish that PID `18040` was the Julia process or that the recorded exit code came from Julia rather than the recovery wrapper. The complete, hash-consistent `result.json` and raw stdout establish successful content production; they do not fully recover the process identity and exit-code provenance.

The dirty snapshots contain 305 and 306 porcelain rows, with the sole added row being `?? docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/`, an unrelated concurrent directory. Because the N06 implementation directory is itself an untracked parent, porcelain does not expose its children as separate rows. The prior report's claim that the one-row increase was this observation directory is therefore unsupported. No old file hash changed in this audit.

There is also one concrete receipt defect: `evidence_manifest.json` records a malformed, truncated stderr SHA-256 (`e3b0c44298fc1c1499b934ca495991b7852b855`), while `output_hashes.json` and the raw empty file carry the correct 64-hex digest above. This must be corrected in a new erratum or regenerated manifest; the old evidence must remain preserved.

## Exit gate

Keep this observation at `changes_requested` until a new append-only receipt corrects the manifest stderr digest and captures the recovery provenance with a task-specific child PID, exact command line, process start/end or equivalent OS evidence, and a real Julia exit-code capture. No rerun is required solely to fix the record if those facts can be recovered without ambiguity; if they cannot, classify PID and exit as `unknown` rather than infer them. Any future acceptance remains limited to the source-path software observation and retains all physical and parent-goal ceilings.

