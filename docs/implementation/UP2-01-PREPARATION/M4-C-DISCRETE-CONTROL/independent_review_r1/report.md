# M4-C discrete control independent review R1

Status: `pass_limited`

This is an independent Luna review of the M4-C delivery, test execution, and
integration evidence. The review did not modify any source, test, oracle,
shared entrypoint, registry, project/manifest, candidate, or provider file.
Only this `independent_review_r1/` evidence directory was written.

## Decision

The delivery passes at the limited ceiling
`manufactured_discrete_control` / `screen_only`. It does not establish a
solver, matrix/vector assembly, field coupling, candidate/provider binding,
physics, engineering, physical, UP2, B00, B04, R01-R10, or L4 result. M4-D is
not authorized. A separate Sol/root `accepted_limited` record is still
required; this review is not that acceptance.

## Independent numerical check

The reviewer ran an independently written Python `Fraction` recomputation
before the production oracle and Julia test. It checked every cell and all six
faces on both required grids: `2x2x2` (8 cells, 48 faces) and `3x4x5`
(60 cells, 360 faces). Each cell gave exact directional divergences
`1/10`, `1/20`, `1/30`, total `11/60`, source `-11/60`, and residual `0`.
The independent process exited `0`; its raw stream and receipt are under
`raw/review_command_00_independent_fraction_recompute.*`.

The fresh production oracle then exited `0` with the expected canonical output
hash `330c8d4ac277afa8e34f001d0c8e5500a56c64e47a3489aed5ef9be84c01636f`.
The fresh Julia A+B+C isolation test ran strictly after Python, exited `0`,
and reported `537/537` with empty stderr. Its output hash is
`31feda288e5876bf94cf1796116e8fa6d2b8001f8c88bdc3ec7fd98a1a403f83`.

## Code and contract audit

The C source constructs only the frozen uniform Cartesian, cell-centred
six-face control. The review checked each face's axis/side, coordinate,
face-centred diagonal coefficient, signed normal flux, area, volume
normalization, and exact rational contribution. The validator checks mesh,
topology, boundary closure, units, equation/source identity, source and
conservation owners, provenance, per-cell balances, face-list consistency,
and typed failure controls. The source contains no solver or coupling call.

The tests cover both grids, payload determinism, invalid grid/topology/
boundary/unit/stencil controls, foreign A/B/equation/source/owner/provenance/
residual controls, and forbidden screen-only APIs. The forbidden-symbol scan
found names only in negative-control test assertions; no forbidden API was
invoked. The Julia duration differs between runs while the semantic result
remains `537/537`; this is an expected non-semantic runtime line difference.

## Evidence, ownership, and tree boundary

All delivery, test, and integration receipts/raw streams were inspected. The
historical metadata-capture failure remains retained as non-counted harness
history. Source, test/oracle, integration, documentation, and independent
review are pairwise-distinct roles. The current HEAD is
`b2c04d8339774635aaecd73651efcdb101e01b5d`; the five input hashes in the
manifest match the files at review time. The pre-existing dirty
`src/RuntimeV4/SpatialRuntimeV4.jl` change and unrelated dirty work were
preserved.

Formal re-entry remains:

`T0 -> authority recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`

The 39-node DAG and all parent gates remain open.
