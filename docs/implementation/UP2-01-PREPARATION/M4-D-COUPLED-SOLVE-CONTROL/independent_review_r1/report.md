# M4-D coupled-solve control independent review R1

Status: `changes_requested`

This is an independent Luna review of the M4-D delivery, test/oracle,
integration, and delivery records. The reviewer wrote only this
`independent_review_r1/` directory. No product source, test, oracle, shared
entrypoint, registry, project/manifest, candidate, provider, or upstream
record was edited.

## Decision

The manufactured arithmetic and builder path pass at the stated
`manufactured_coupled_solve_control` / `screen_only` ceiling, but the review
requests changes before limited acceptance. The public typed-control validator
does not close all bindings for a directly constructed
`ManufacturedCoupledSolveControlV1` value. In particular, at
`src/RuntimeV4/M4Isolated/ManufacturedCoupledSolveControlV1.jl:366-412`,
validation compares source/conservation owners only from `c.left` to the
aggregate fields; it does not revalidate `c.right` as an M4-C control or compare
`c.right.source_owner` and `c.right.conservation_owner` to the aggregate. It
also does not verify each stored cell's `equation_id`, `source_id`, and
`conservation_owner`, or that `c.grid_counts == c.left.grid.counts` before
using `c.grid_counts` for the cell-count check.

This is not a failure of the current builder negative controls: the builder at
lines 213-233 validates both C inputs and compares their bindings. It is a
validator closure gap because the typed struct constructor is public and the
validator is itself part of the exposed control contract. The independent
probe constructed an otherwise valid D control with a right-side foreign
source owner and observed `right_source_owner_bypass_valid=true failures=0`
(`raw/binding_gap_probe.combined.raw`, exit 0). Required repair is to make
the validator revalidate both nested C controls, close both-side and per-cell
bindings, and verify grid-count identity; add regression tests proving these
direct-constructor mutations return typed failures. Re-run the full current
test and integration chain after the repair.

The gap prevents `accepted_limited`; it does not authorize any broader claim.
No UP2, B00, B04, R01-R10, L4, parent, candidate, provider, physics,
engineering, production solver, or PDE credit is assigned.

## Independent arithmetic and fresh serial executions

The independent reviewer Fraction recomputation (no project import) computed
the frozen block `[[2,-1],[-1,2]] * [a,b] = [1,0]`: determinant `3`, exact
solution `(2/3,1/3)`, eight identity cells, and residual `(0,0)` in every
cell. It exited zero. A fresh production Python oracle then exited zero with
the canonical payload, and a fresh Julia process ran the current test file
(`92cd4069...75d88`) and reported `110/110`. These processes were run serially
with no overlap.

| sequence | exact command | PID | UTC interval | exit | combined SHA-256 | raw map |
|---:|---|---:|---|---:|---|---|
| 1 | `python test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | 61736 | `2026-09-16T09:18:19.1747474Z–2026-09-16T09:18:19.7767979Z` | 0 | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` | `raw/python_oracle.{stdout,stderr,combined}.raw` |
| 2 | `julia --startup-file=no --history-file=no --color=no test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | 104640 | `2026-09-16T09:18:38.0849659Z–2026-09-16T09:18:57.1585385Z` | 0 | `e3e931edca7e93929e0421e2acea5538ba18949abc60d8a2fa5fb8d16347dba3` | `raw/julia_tests.{stdout,stderr,combined}.raw` |
| 3 | `python docs/implementation/UP2-01-PREPARATION/M4-D-COUPLED-SOLVE-CONTROL/independent_review_r1/fraction_recompute_v1.py` | 107020 | `2026-09-16T09:20:47.7457137Z–2026-09-16T09:20:48.3680758Z` | 0 | `3ad976ef9c5279f0bbadac0a58e0c491f9fca0dac4da6301153f8123d1dd6b95` | `raw/fraction_recompute.{stdout,stderr,combined}.raw` |
| 4 | `julia --startup-file=no --history-file=no --color=no docs/implementation/UP2-01-PREPARATION/M4-D-COUPLED-SOLVE-CONTROL/independent_review_r1/binding_gap_probe.jl` | 89492 | `2026-09-16T09:23:25.0072391Z–2026-09-16T09:23:30.9377425Z` | 0 | `db9ed5c212372160ec348066f0424abcb2059c8fadaf8056476dfb2fe6cf529e` | `raw/binding_gap_probe.{stdout,stderr,combined}.raw` |

All successful stderr streams have SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The successful raw files are copied byte-for-byte under `archive/raw/`.
The first binding probe attempt had only a reviewer path-depth error; its raw
combined stream is retained as non-counted history under
`archive/failure_history/binding_gap_probe_attempt_001.combined.raw`.

## Code, tests, and boundary audit

The D implementation uses the fixed exact direct 2x2 formula at lines
186-195, produces eight identity-mapped cell solutions for the default 2x2x2
grid at lines 166-174 and 250-264, and records determinant-derived residuals.
The source has no executable production/PDE/provider/candidate path; its only
include is the guarded isolated M4-C source. The test includes only isolated
A/B/C/D and covers exact determinant/solution/residuals, payload aliases,
foreign C, grid/interface, singular/non-SPD/RHS, units, equation/source/
owner/conservation/provenance, residual, and forbidden API controls. The
current test result is measured `110/110`, not the old `111/111` count.

The static forbidden-symbol occurrences are confined to explanatory D
docstrings and negative-control assertions in the test. No forbidden API was
invoked. The claim remains only
`manufactured_coupled_solve_control/screen_only`.

## Historical evidence and role separation

The records were checked without conflation:

- PID `86500`: failed harness macro-syntax attempt, exit 1;
- PID `80804`: failed test-expectation attempt, exit 1 (`106 pass, 4 fail, 1 error`);
- PID `63524`: superseded old `111/111` pass under test SHA
  `CF303AC0...C828D2E`;
- PID `24296`: old superseded `111/111` result;
- current integration: two fresh Python oracle and two fresh Julia runs,
  each exit 0, with Julia `110/110`;
- PIDs `44132` and `52116`: `$args` wrapper preflight launches, stopped
  before valid child output/exit, explicitly non-counted.

Source implementation, test/oracle, integration, documentation, and this
independent review are distinct roles. The current HEAD is
`b2c04d8339774635aaecd73651efcdb101e01b5d`. The six frozen A/B/C/D/test/oracle
hashes match the delivery/integration records and the files at review time.
The shared entry, registries, Project, Manifest, and pre-existing dirty
`src/RuntimeV4/SpatialRuntimeV4.jl` state were unchanged by this review.

## Formal boundary

The only accepted scope, once the binding gap is repaired and re-reviewed, is
`manufactured_coupled_solve_control/screen_only`. It is strictly isolated and
does not contain or authorize UP2, B00, B04, R01-R10, L4, or the parent goal.
Formal re-entry remains:

`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
