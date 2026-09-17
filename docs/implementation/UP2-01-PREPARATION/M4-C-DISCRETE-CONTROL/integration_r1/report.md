# M4-C discrete control integration R1

Status: `integration_complete_review_pending`  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`  
Claim ceiling: `manufactured_discrete_control` / `screen_only`

## Integrated result

Four fresh processes ran strictly serially. The independent Python `Fraction`
oracle ran twice first, then the Julia A+B+C isolation test ran twice. Both
Python runs exited 0 and produced byte-identical canonical payloads for every
cell on `2x2x2` and `3x4x5`: directional divergence `1/10`, `1/20`, `1/30`,
total `11/60`, source `-11/60`, residual `0`. Both Julia runs exited 0 and
reported `537/537` tests; stderr was empty. Julia stdout differs only in its
runtime-duration line, while the semantic result is identical.

## Process receipts

| process | PID | exit | stdout SHA-256 | stderr SHA-256 |
|---|---:|---:|---|---|
| Python oracle run 1 | 100620 | 0 | `330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| Python oracle run 2 | 97936 | 0 | `330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| Julia tests run 1 | 104152 | 0 | `8b931a427726df657ba5a28b753312382a1b13318d04eb8c43df3bbef39aed74` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| Julia tests run 2 | 22172 | 0 | `c28c8ae4bef5dc057faa243604614c46b10345fcfa774d46bca730d3423d406c` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Full receipts and stdout/stderr/combined raw streams are retained in this
directory and copied under `archive/raw/`. The earlier metadata-capture
failure remains retained at
`../test_execution_r1/failure_history/attempt_001_metadata_capture_failure.combined.raw`;
it is non-counted harness history, not a mathematical or test failure.

## Isolation and boundary

The test includes only M4-A, M4-B, and M4-C isolated source files. Targeted
git checks show the shared RuntimeV4 entrypoint, registry, `Project.toml`, and
`Manifest.toml` unchanged; unrelated dirty worktree changes were preserved.
The evidence is only a manufactured six-face discrete assembly payload. No
solver, coupling, candidate, provider, physics, engineering, or physical
claim is made. No UP2, B00, B04, R01-R10, or L4 credit is granted, and M4-D
remains unauthorized. Independent Luna review and a separate Sol/root limited
acceptance are required.
