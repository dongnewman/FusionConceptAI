# M4-C discrete control delivery R1

Status: `delivery_complete_review_pending`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Scope basis: `../c_scope_decision_r1/` (`authorized_not_started`)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Delivery boundary

This record aggregates the isolated M4-C manufactured discrete-control
evidence for review. The ceiling is `manufactured_discrete_control` /
`screen_only`. It is a deterministic six-face assembly payload on the frozen
manufactured control: uniform Cartesian, cell-centered finite volume /
conservative difference on `[0,1]^3`, with `nx,ny,nz >= 2` and `h=1/n`.

It is not a solver, coupled solve, candidate, provider, physics, or
engineering result. No `UP2`, `B00`, `B04`, `R01-R10`, or `L4` credit is
granted; D remains unauthorized and no parent gate is closed.

## Frozen A/B/C inputs and bindings

The final input hashes used by test and integration evidence are:

- A source `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl`:
  `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`;
- B source `src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl`:
  `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`;
- C source `src/RuntimeV4/M4Isolated/ManufacturedDiscreteControlV1.jl`:
  `20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa`;
- C test `test/RuntimeV4/M4Isolated/manufactured_discrete_control_v1_tests.jl`:
  `14e1e6d81333ad0b4ed4426ebc30d8d7e39b36808ef94acc1103b5f78aa9e2e7`;
- C oracle `test/RuntimeV4/M4Isolated/oracles/discrete_control_oracle_v1.py`:
  `c48d8987477fef82e3a414eaa49f1392d18104440e0ad3ea075d42f83ee3b07d`.

Mesh, topology, boundary closure, units, equation identity, source owner,
conservation owner, and provenance are explicit bindings. Required typed
controls cover `invalid_grid`, `invalid_topology`, `invalid_boundary`,
`unit_closure_failure`, `nonconservative_stencil`, and `foreign_input`, with
owner/provenance mismatch controls also retained in the test evidence.

## Exact two-grid control

The independent Fraction oracle evaluates every cell and all six face fluxes
on both required grids: `2x2x2` (8 cells) and `3x4x5` (60 cells). For every
cell on both grids, the exact directional divergence terms are `1/10`, `1/20`,
and `1/30`, total divergence is `11/60`, source is `-11/60`, and cell residual
is exactly `0`. The oracle emits one sorted deterministic payload. No floating
approximation is used for the acceptance arithmetic.

## Execution and replay evidence

The original test execution ran the Python oracle first and then the Julia
isolation test: Python PID `42380`, exit `0`,
`2026-09-16T07:51:58.5011716Z`–`07:51:58.6072523Z`, combined SHA
`330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f`; Julia
PID `102840`, exit `0`,
`2026-09-16T07:52:18.1318119Z`–`07:54:56.7483609Z`, `537/537`, combined SHA
`ac5c03037b07dc35c4f296769018feb7808543b304ceb98f6e5d442dabb37856`.
Both stderr streams have the empty hash
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The integration record retains a two-run replay for each process family. Its
receipts preserve exact PID, UTC, exit, raw paths, and hashes:

| process | PID | exit | result | stdout/combined SHA-256 |
|---|---:|---:|---|---|
| Python run 1 | 100620 | 0 | all 8+60 cells exact | `330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f` |
| Python run 2 | 97936 | 0 | byte-identical payload | `330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f` |
| Julia run 1 | 104152 | 0 | `537/537` | `8b931a427726df657ba5a28b753312382a1b13318d04eb8c43df3bbef39aed74` |
| Julia run 2 | 22172 | 0 | `537/537` | `c28c8ae4bef5dc057faa243604614c46b10345fcfa774d46bca730d3423d406c` |

The integration receipts record UTC intervals `08:07:58.0052010Z`–
`08:07:58.1328372Z` and `08:07:58.1871358Z`–`08:07:58.2956764Z` for Python,
and `08:00:51.7832119Z`–`08:03:08.8947762Z` and `08:03:08.9050978Z`–
`08:05:19.7232051Z` for Julia. The Julia stdout hashes differ because the
human-readable duration line differs; semantic result `537/537` is equal.
All four integration stderr hashes are the empty-stream hash. The detailed
stdout/stderr/combined paths are retained under `../integration_r1/` and its
`archive/raw/` copy.

The first metadata-capture attempt is retained at
`../test_execution_r1/failure_history/attempt_001_metadata_capture_failure.combined.raw`.
It is a harness metadata failure and explicitly non-counted; the successful
r2/test and integration receipts are authoritative. No failure history is
deleted or rewritten.

## Ownership and gates

Source implementation, test/oracle, integration, documentation, and
independent review are five pairwise-distinct Luna roles. The reviewer cannot
review their own change or another role's same change. No shared RuntimeV4
entrypoint, registry, Project, Manifest, candidate, provider, or upstream A/B
source was modified by this delivery record; unrelated dirty work was
preserved.

Independent review must verify both-grid per-cell Fraction results, exact
payload semantics, Julia `537/537`, duration-only stdout difference, every
PID/UTC/exit/raw/hash receipt, non-counted metadata failure, typed controls,
role separation, and shared-tree isolation. If review passes, only a separate
Sol `accepted_limited` decision may accept C at the stated ceiling.

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
The 39-node DAG and all parent gates remain open. No local C artifact permits
D, solver, coupling, candidate, provider, physics, engineering, or formal
stage credit.

