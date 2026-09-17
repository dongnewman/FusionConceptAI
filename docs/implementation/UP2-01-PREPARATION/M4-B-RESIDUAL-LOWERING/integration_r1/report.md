# M4-B residual lowering integration verification R1

Status: `integration_complete_review_pending`  
Owner: integration-validation Luna (`gpt-5.6-luna`, high)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Decision and scope

The isolated M4-B harness integrates and replays as a bounded
`manufactured_residual_lowering` / `screen_only` control. This record verifies
the A-to-B isolated include boundary, deterministic manufactured arithmetic,
and the final B test/oracle artifacts. It is not Sol acceptance and grants no
UP2-01, UP2, B00, B04, provider, mesh, engineering, physical, R01-R10, or L4
credit. C (topology transfer) and D (coupled solve) remain unauthorized.

The A input is the separately accepted-limited
`M4-A-EQUATION-IR/root_acceptance_r1/` record. A's ceiling remains
`manufactured_control` / `screen_only`; B does not raise it. The B test/oracle
execution record is
`../test_execution_r1/` and remains the source of the causal initial failure
and repair history.

## Frozen inputs and hashes

| input | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` | `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57` |
| `src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl` | `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c` |
| `test/RuntimeV4/M4Isolated/manufactured_residual_lowering_v1_tests.jl` | `c7032beecfcca29db8a751eec4aaf4797eadfed66b12e8da611c392783740f73` |
| `test/RuntimeV4/M4Isolated/oracles/residual_lowering_oracle_v1.py` | `0d89c69ab3689a0cf7cde9756f95a76b8f7e4c8fc93a7a99ed9aa460bd5781fd` |

## Causal repair check

The preserved first B test run exited `1` with `51 pass / 2 error`. The two
owner-binding controls called
`validate_manufactured_residual(d, ir)` when the result had no failures. The
pre-repair source (`82e1294eccb9a5e3e3145ee694e44ff71d3afec52786f5221f48311d4bf7ec62`)
materialized `collect(result.failures)` as `Vector{Union{}}`; the subsequent
owner-binding `push!` therefore raised `ArgumentError: cannot convert a value
to Union{}`. The failed raw and receipt are retained at
`../test_execution_r1/command_02_julia_tests.*` with combined hash
`32babe9221dfca94e7875310252362bf261a3f103c30ecc085cf72a4f9dbe4e6`.

The separate B source repair changed only the failure-vector materialization
to the typed form
`ManufacturedResidualLoweringFailureV1[f for f in result.failures]`.
The source implementer, not this integration role, made that repair. The
upstream repair run reports 53/53 and remains retained at
`../test_execution_r1/command_04_julia_tests_repair_r1.*`.

## Fresh serial integration replay

Four new child processes were run strictly in this order: Python oracle,
Python oracle, Julia B tests, Julia B tests. Each receipt records exact
command, absolute cwd, child PID, UTC start/end, exit code, input/output and
artifact hashes, and raw stdout/stderr/combined paths. The Python canonical
payloads are byte-identical and both report exact terms `1/10`, `1/20`,
`1/30`, divergence `11/60`, source `-11/60`, and residual `0`. Both Julia
runs report `53/53`; their semantic pass/total result is the acceptance
comparison, not human-readable timing bytes. All four stderr streams are
empty and exit codes are zero.

| sequence | command | PID | UTC interval | exit | combined SHA-256 | semantic result |
|---:|---|---:|---|---:|---|---|
| 1 | Python oracle | 110172 | 07:20:12.8023466Z–07:20:13.4336266Z | 0 | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` | canonical exact payload |
| 2 | Python oracle | 104420 | 07:20:27.6285469Z–07:20:28.3219580Z | 0 | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` | canonical exact payload |
| 3 | Julia B tests | 97276 | 07:20:43.0985418Z–07:20:53.1504560Z | 0 | `dcf65a06f4a3132cc813564f62d2b82090aa7df6853c0791b8edca0d405691d7` | 53/53 |
| 4 | Julia B tests | 2400 | 07:21:07.0631592Z–07:21:17.2894159Z | 0 | `1994f192d90c1767e10bfea8b77b216d803787f90b4f5942c23f5e93fce8786e` | 53/53 |

The raw files are live under `raw/` and copied byte-for-byte under
`archive/raw/`. A failed harness-capture preflight produced only two raw
streams before its PowerShell variable collision; those unindexed bytes are
preserved under `archive/harness_capture_abort_20260916T0718Z/` and are not
counted as one of the four integration replay sequences.

## Isolation and shared-tree boundary

The B source has only the guarded isolated include of M4-A. The dedicated
Julia test includes only the two M4 isolated sources and imports `Test` and
`SHA`; the Python oracle uses `fractions`, `json`, and `sys` only. No shared
RuntimeV4 entrypoint, registry, `Project.toml`, or `Manifest.toml` was edited
by this integration record. Existing dirty `src/RuntimeV4/SpatialRuntimeV4.jl`
and other unrelated worktree changes were detected and preserved; they are
outside this role's owned paths. No implementation, test, oracle, shared
entry, candidate, provider, mesh, physics, engineering, assembly, discrete,
coupling, or solver execution occurred here.

## Handoff and gates

This is `integration_complete_review_pending` pending an independent Luna
review and separate Sol limited-acceptance decision. Claim ceiling is
`manufactured_residual_lowering` / `screen_only`. No parent task or stage is
closed. The 39-node DAG, R01-R10, B00/B04, and all formal gates remain open.
Formal re-entry remains
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

