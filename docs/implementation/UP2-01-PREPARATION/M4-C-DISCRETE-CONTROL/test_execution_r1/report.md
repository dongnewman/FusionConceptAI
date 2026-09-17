# M4-C discrete control test execution R1

Status: `execution_complete_review_pending`  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`  
Claim ceiling: `manufactured_discrete_control` / `screen_only`

## Result

The independent Python `Fraction` oracle ran first and checked every cell on
the required `2x2x2` and `3x4x5` grids. Each face uses face-centred diagonal
`K` and the affine field gradient; the three exact directional divergences are
`1/10`, `1/20`, and `1/30`, the total is `11/60`, the source is `-11/60`, and
the frozen residual `-div-f` is exactly zero. The oracle emitted one sorted,
canonical JSON payload containing all cells and faces.

The Julia isolation test then included A, B, and C only and completed `537/537`
tests with exit `0` and empty stderr. It covers build/validate/payload
determinism, both grids, exact local balances, ordered six-face stencils,
invalid grid/topology/boundary/unit/stencil-sign/face-balance controls,
foreign A/B/equation/source/owners/provenance, nonzero residual, and the
screen-only forbidden-API boundary.

## Receipts and hashes

1. Python oracle r2: PID `42380`, UTC
   `2026-09-16T07:51:58.5011716Z`–`2026-09-16T07:51:58.6072523Z`, exit `0`.
   stdout and combined SHA-256:
   `330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f`;
   stderr SHA-256 is the empty-stream hash
   `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
2. Julia tests: PID `102840`, UTC
   `2026-09-16T07:52:18.1318119Z`–`2026-09-16T07:54:56.7483609Z`, exit `0`.
   stdout and combined SHA-256:
   `ac5c03037b07dc35c4f296769018feb7808543b304ceb98f6e5d442dabb37856`;
   stderr SHA-256 is the empty-stream hash
   `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

All stdout/stderr/combined streams, receipts, and archive copies are retained
under this directory. The first Python capture attempt also had a PowerShell
PID-variable metadata error; its successful process output is retained and the
r2 receipt is the authoritative execution record. This was a harness-recording
failure, not a mathematical or test failure.

## Ownership and acceptance boundary

The M4-C source, test/oracle, integration/documentation, and independent review
roles remain pairwise distinct. This execution added only the assigned test and
oracle files and evidence records; it did not edit A/B/C source, shared
RuntimeV4 entrypoints, registries, `Project.toml`, `Manifest.toml`, candidate or
provider files. No solver, matrix/vector assembly, coupling, candidate,
provider, physics, engineering, physical, UP2, B00, B04, R01-R10, or L4 credit
is granted. M4-D remains unauthorized. Independent review and a separate
Sol/root limited decision are required next.
