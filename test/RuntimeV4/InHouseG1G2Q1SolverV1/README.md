# Independent in-house Q1 solver oracle

This directory is an independent numerical oracle for the bounded physical
Cartesian variable-diagonal diffusion slice. It does not provide UP1, formal
T2, G3, physical, engineering, or R01–R10 acceptance.

The expected field is defined directly from the frozen fixture constants:

\[
t_i=(x_i-a_i)/L_i,\qquad u=\prod_i t_i(1-t_i),\qquad
k_i(x_i)=k_{0i}+s_i x_i.
\]

For the sign convention \(-\nabla\cdot(K\nabla u)=f\), differentiating each
diagonal flux gives

\[
f(x)=\sum_i\left(\frac{2k_i(x_i)}{L_i^2}
-\frac{s_i(1-2t_i)}{L_i}\right)
\prod_{j\ne i}t_j(1-t_j).
\]

The independent Python code assembles trilinear tensor-product elements on
the three frozen meshes, solves the free-DOF sparse system with SciPy, and
integrates the interpolation errors with a higher-order Gauss rule. Exact
Fraction arithmetic separately checks the source integral against the six-face
outward conormal identity. The frozen numerical gates are copied verbatim
from the existing Gridap V1 protocol; the solver identity is distinct and the
thresholds are not selected from these oracle results.

The Python run is a development oracle until the root grants the serialized
numerical slot. Full Julia, SciPy, Gridap, DESC, and FreeGS execution remains
subject to that slot. Python syntax parsing and other non-solving static checks
do not enter the numerical acceptance record.

## Pre-grant development-run receipt

Before the root clarified that SciPy sparse solves also use the serialized
numerical slot, two oracle commands were inadvertently started concurrently.
They are development diagnostics only and do not count as acceptance:

- `python test\\RuntimeV4\\InHouseG1G2Q1SolverV1\\test_independent_q1_oracle.py`
  exited 0; tool wall time 6.443 s; the unit-test suite reported 2.717 s.
- `python test\\RuntimeV4\\InHouseG1G2Q1SolverV1\\independent_q1_oracle.py`
  exited 0; tool wall time 6.372 s.
- Both processes were observed starting at 2026-09-26 02:12:46 Asia/Shanghai
  (2026-09-25 18:12:46 UTC); completion is estimated from tool wall time at
  18:12:52–53 UTC. Exact end timestamps were not captured.
- A post-run working-set sample was 49,254,400 and 68,567,040 bytes. Peak RSS
  was not monitored. A later process command-line check found no process
  referencing this oracle/test path.
- The test-generated cache file
  `test/RuntimeV4/InHouseG1G2Q1SolverV1/__pycache__/independent_q1_oracle.cpython-313.pyc`
  was 29,568 bytes, SHA-256
  `90825373371A94634EBDC5F52BADD5ACAAFB775267A3680C9A26AAEB38FB6F48`,
  mtime 2026-09-25 18:11:53 UTC. It is retained because the exact single-file
  cleanup command was blocked by execution policy; no alternate deletion path
  was used.
- At run time, the oracle source SHA-256 was
  `F31EE6BC15DDEF79BFFF1404176BA9ECF0B2B0FAAD01759C9609D878F2FF7874`, and
  the unittest source SHA-256 was
  `9732EF240571D05A90512A0625BFB671E7AEAA6FFB839FB2B021F13F3E8E1CCA`.

Future Python execution in this directory uses `-B`; no Julia, Gridap, DESC,
or FreeGS command was started for those diagnostics.

## Independent Q1 first-slot gate (runner and acceptance description)

`focused_fixture.jl` is a local light copy of the candidate/declaration/T1
fixture setup through the native compiler. It loads the real source authority,
G1/G2 declarations, T1 binding, and compiler, then stops before either Gridap
adapter is included. `focused_tests.jl` includes only the new in-house solver,
checks the unchanged protocol gates and candidate/source/chart mutation
negatives, executes the in-house three-grid report once, and rejects a forged
L2 scalar even after the level and report hashes are recomputed. It also forges
runtime-evidence candidate provenance, physical/scenario identity, stage
outcome, numerical configuration, and artifact references, recomputes the
containing bundle hash, and verifies both bundle validation and cache-hit
validation fail closed. The
raw report is written before report assertions so a numerical failure keeps
its metrics, hashes, and classification for review.

`compare_independent_raw.py` independently reassembles and directly solves the
three frozen Q1 levels. For the in-house report it compares full and reduced
matrices, verifies that the reduced matrix is the full-matrix free-DOF slice,
checks the exact interior/face DOF partition and free RHS slice, recomputes
`A*x-b`, relative residuals, full reactions, boundary balance and trace
conormal, and compares the PCG solution and error metrics to the independent
SciPy solve. Its default backend set is in-house only; Gridap is a separate
later serial comparison.

The comparator binds report identity to plan identity, checks the frozen
candidate URI/version, and requires solver-source SHA-256
`BD8E60FF527C42723B2B38C28494761D33C30D9E2FB200C464FADA926A4351BF`. The
supervisor snapshots the Julia `src` tree, package environment, focused-fixture
dependency, and test/oracle/runner inputs. It checks those hashes before Julia,
after Julia, and after SciPy; any changed or missing input stops the run. It
also verifies the raw report hash remains unchanged during SciPy replay.

The sole prepared launch command, run from the repository root, is:

```powershell
python -B test\RuntimeV4\InHouseG1G2Q1SolverV1\run_serial_acceptance.py --output-dir runs\InHouseG1G2Q1SolverV1\serial-q1-next-unique-leaf
```

The runner launches one Julia process with
`--startup-file=no --threads=1 --heap-size-hint=1G --project=<repo>` and the
focused entrypoint, under a Windows Job Object with a 2 GiB aggregate commit
ceiling. It samples the Julia root and all descendants every 0.25 seconds and
terminates the job if the sampled process-tree working set reaches 2 GiB or
the single shared 240-second Julia-plus-SciPy wall deadline. It waits for the
job's active process count to reach zero before starting Python with `-B` for
the SciPy raw replay. The Python phase has a 120-second cap inside the remaining
shared budget. Both phases share the same Job Object, 2 GiB commit ceiling, and
sampled process-tree RSS gate. An incomplete process-tree RSS sample has no
memory credit and stops the run. Children start suspended through
`CreateProcessW`, are assigned by their original process handles to the same
Job Object, then resume through the original primary-thread handle. Failure
cleanup uses that exact process handle and never kills a process by enumerated
PID; Julia discovery uses `shutil.which` and starts no unmonitored helper.
The output directory retains both programs' stdout/stderr, raw JSON, a
process-tree audit log, and a run receipt containing argv, UTC timestamps,
exit codes, sampled RSS/peak job commit, stop reason, and input hashes.

`python -B test\RuntimeV4\InHouseG1G2Q1SolverV1\test_serial_supervisor_static.py`
passed 20 controlled static checks (exit 0): partial RSS has no
credit, PID-generation mismatch has no credit, cleanup uses the exact retained
handle, GetProcessTimes/Job assignment/thread-resume failures reap the
suspended child, report/plan identity changes are rejected, changed pins fail
closed, Julia discovery starts no unmonitored helper, both numerical phases
share the 240-second deadline, and postflight cannot emit GO after that deadline.
Python syntax parsing and these
checks do not run the mathematical oracle. No
completed Q1 numerical acceptance is claimed here.

## Q1 fixture scope and bounded-run status (2026-09-26)

The focused Q1 fixture retains the native `NG12_CANDIDATE`, native G1/G2/G3
declarations, source programs/profile, source-backed T0 records, and the same
transport. Its T1 preparation now uses the existing non-parameterized V2
canonical-byte carrier and full V2 transport recheck. The bridge-only
`NamedTuple` projection is built from V2 checked fields for the existing G3
binding authority bridge; it is not a V1 recheck result and is never passed to
a V3 witness consumer. V3 realization/control validation, the current-state
projection, expected-commitment hash recheck, binding key/links,
and V2 T1 admission remain in the fixture.

This Q1 numerical fixture does not construct a V3 source witness. Its runtime
marker is `fixture.chain.v3_witness.not_built`; formal T2 remains on its
separate frozen witness chain with its full target unchanged. This fixture
confers no formal T1/T2 or physical credit; the numerical report remains
`terminal_deferred` with the `screen_only` claim ceiling.

The preserved run05 receipt is
[runs/history/RuntimeV4/InHouseG1G2Q1SolverV1/serial-q1-20260926-05/run-receipt.json](../../../runs/history/RuntimeV4/InHouseG1G2Q1SolverV1/serial-q1-20260926-05/run-receipt.json), SHA-256
`BB79D875469E4BC7A29B9A0A6286D6C35E7382F8317F7235D00030B0F499C74C`. Julia
exited 1 after 173.506 s with `ReadOnlyMemoryError`; the supervisor recorded a
peak Job commit of 2,411,106,304 bytes against the unchanged 2 GiB limit and
peak complete sampled RSS of 688,373,760 bytes. Its stdout stopped at
`fixture.chain.recheck_v1.begin`; no three-grid report or SciPy replay was
produced. This identifies the failed stage, not a proven unique allocation
site. The original receipt and run artifacts are retained unchanged.

The preserved run06 receipt is
[runs/history/RuntimeV4/InHouseG1G2Q1SolverV1/serial-q1-20260926-06/run-receipt.json](../../../runs/history/RuntimeV4/InHouseG1G2Q1SolverV1/serial-q1-20260926-06/run-receipt.json), SHA-256
`8EFA4928F852A2DC5334105296790D111FCD81CEF253D7DDBBE4B7CC9C63DA96`. The
outer runner exited 2 at the shared 240-second timeout; Julia exited 92 after
240.048 s. The V2 recheck completed at 186.035 s, then stdout stopped at
`fixture.chain.parent.begin`. Peak Job commit was 678,383,616 bytes and peak
complete sampled RSS was 711,393,280 bytes, both below the unchanged 2 GiB
limits; SciPy did not start.

That run was pinned to `focused_fixture.jl` SHA-256
`63798932DA30C184BA8F06CDE9CE17DDF24A52F937C84705A5C0006B3ACEFEE7`. The
parent baseline result was only returned as `chain.parent`; after the Q1
fixture stopped constructing a V3 witness, no Q1 test or compiler consumed
it. The fixture now removes that unused
`bind_local_parent_baseline_from_t0_v1` call and its returned field. It retains
both V2 `vnext_t1_parent_commitment_v2` values and passes them to the same V2
admission input. The focused fixture does not claim coverage or acceptance for
the legacy/local V1 parent-baseline helper; that remains in its separate
`test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl`
coverage and the formal source-witness fixtures. The V1 helper, its tests, and
the formal T2 goal were not changed.

The fixture hash after this narrow deletion is
`C40322D190E3BB72AFC0882E755687C67D5AD0EC4EC580BC09DFF9AA8ACBDC9A`; the
run06 receipt and artifacts remain unchanged. Any next Julia/SciPy attempt
still requires the root's serial-slot grant and retains the same 2 GiB,
240-second, 0.25-second sampling, scientific inputs, 50 Julia assertions,
three grids, and independent SciPy replay.

### Workspace layout consolidation (2026-09-27)

The 50 historical Q1 output files were relocated byte-for-byte under repository `runs/history/RuntimeV4/InHouseG1G2Q1SolverV1/`. Original commands, exit codes, hashes and `output_directory` fields remain execution facts. The misplaced deeper static leaf is stored separately under `deep/static_controls_20260926_r1`; it is not merged with the repository Q1AdmissionProbeV1 evidence. See the [relocation receipt](../../../runs/e/code_consolidation_20260927/q1_history_migration.json). A new run needs a fresh repository `runs/` leaf and the current root GO; consolidation does not raise numerical or physical credit.
