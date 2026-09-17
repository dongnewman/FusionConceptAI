# M4-D coupled-solve control repair independent review R2

Status: `pass_limited`

This independent Luna review covers the D repair, repair integration, current
source/test/oracle, execution receipts, raw/archive integrity, and protected
tree. Only this `independent_review_r2/` directory was written. No product,
test, oracle, shared module, registry, Project, Manifest, candidate, provider,
or upstream evidence was modified.

## Decision and ceiling

The R1 acceptance-blocking validator bypass is repaired and independently
closed. The result passes only at
`manufactured_coupled_solve_control` / `screen_only`. It grants no formal
credit and does not close or authorize UP2, B00, B04, R01-R10, L4, the parent
goal, a candidate, a provider, physics, engineering, production coupling,
iterative solving, or PDE execution. Separate Sol limited acceptance remains
required.

## Repair closure audit

The repaired D validator at
`src/RuntimeV4/M4Isolated/ManufacturedCoupledSolveControlV1.jl:368-454`
now performs all required closure checks:

- revalidates both nested left and right M4-C controls and maps nested failures
  to typed `foreign_c_input` results;
- requires `c.grid_counts` to equal both nested C grid counts;
- requires interface left/right grid counts to equal both nested grids and
  `c.grid_counts`;
- compares both nested source owners and conservation owners to the D
  aggregate bindings;
- checks every stored solution's equation/source/conservation binding;
- checks every solution's left/right index against its corresponding interface
  pair and requires the full identity mapping; and
- retains exact 2x2 determinant/solve/residual validation and cell-count
  closure.

The former direct-constructor bypass was replayed independently. A right
nested C control with `FOREIGN-SOURCE-OWNER` now returns
`status=:typed_failure`, includes `foreign_c_input` with a `right.` path, and
exits zero from the probe (`raw/replay_bypass_probe.combined.raw`). The repair
test adds corresponding controls for both nested owners, nested equation,
top-level and interface grid counts, swapped/missing/duplicate/nonidentity
pairs, and solution/pair correspondence.

## Independent and fresh execution evidence

All processes below were fresh and strictly serial: bypass replay, Python
oracle, then Julia current D tests. The independent Python oracle reports the
fixed block determinant `3`, exact solution `(2/3,1/3)`, eight identity cells,
and zero residual in every cell. The current Julia test used the repaired test
hash and measured `158/158`.

| sequence | exact command | PID | UTC interval | exit | combined SHA-256 | raw map |
|---:|---|---:|---|---:|---|---|
| 1 | `julia --startup-file=no --history-file=no --color=no docs/implementation/UP2-01-PREPARATION/M4-D-COUPLED-SOLVE-CONTROL/independent_review_r2/replay_bypass_probe.jl` | 25972 | `2026-09-16T09:55:49.9115575Z–2026-09-16T09:55:56.8189029Z` | 0 | `aac42f356bc93847da6b1b80bed88f47314aceb2487beae50ba8243fbb994874` | `raw/replay_bypass_probe.{stdout,stderr,combined}.raw` |
| 2 | `python test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | 108088 | `2026-09-16T09:56:09.7990910Z–2026-09-16T09:56:10.4207917Z` | 0 | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` | `raw/python_oracle.{stdout,stderr,combined}.raw` |
| 3 | `julia --startup-file=no --history-file=no --color=no test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | 30072 | `2026-09-16T09:56:25.0829229Z–2026-09-16T09:56:50.6656266Z` | 0 | `3fb42ef20ff6287f688372cab0302afaafd568aa55b9f94fe70b570850583853` | `raw/julia_tests.{stdout,stderr,combined}.raw` |

Python stdout/combined hash is
`94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615`.
Julia stdout/combined hash is
`3fb42ef20ff6287f688372cab0302afaafd568aa55b9f94fe70b570850583853`.
The bypass probe stdout/combined hash is
`aac42f356bc93847da6b1b80bed88f47314aceb2487beae50ba8243fbb994874`.
All three stderr streams are empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
Each raw stream has a byte-identical copy under `archive/raw/`.

## Repair integration and historical separation

The repair integration record was checked as a separate role. Its two
authoritative Julia runs are both complete `158/158`: PID `33500` (exit 0,
combined SHA `82f8dad7...fb8b043`) and PID `88136` (exit 0, combined SHA
`4a1bc927...7fbb9a5`). The capture-timeout Julia attempt has raw `158/158`
but no observed PID or exit and is explicitly non-authoritative; it is not
used as a receipt or substituted for either complete run. The two integration
Python runs are canonical and exit zero.

Historical evidence remains distinct and is not reclassified: the original
R1 current result was `110/110` (not `111/111`); the old `111/111` runs and
all initial failures remain preserved under the parent records; the old
PowerShell `$args` preflight is non-counted. The repair integration's
capture-timeout history is likewise non-authoritative, not a pass receipt.

## Hashes, isolation, and roles

Current hashes match the repair integration manifest exactly:

- A `0b456dcc...b8e57`;
- B `0445ec58...a936c`;
- C `20804baf...10fa`;
- repaired D `ec7e82e...a55785`;
- current repaired test `1eb0e26e...1686`; and
- oracle `9ca3c1c0...fcbe3`.

The current HEAD is
`b2c04d8339774635aaecd73651efcdb101e01b5d`. Static inspection confirms D
retains only its guarded isolated C include and the exact direct rational 2x2
solve. No production/PDE/provider/candidate API is invoked; forbidden names
occur only in explanatory text or negative-control assertions. Source,
test/oracle, integration, documentation, and independent review roles are
pairwise distinct. Shared entrypoints, registries, Project, Manifest, and the
pre-existing dirty `SpatialRuntimeV4.jl` state are unchanged and preserved.

Formal re-entry remains:

`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
