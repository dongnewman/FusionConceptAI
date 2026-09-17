# M4-C manufactured discrete control scope decision R1

Decision authority: `Sol/root`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Status: `authorized_not_started`  
Basis: B `root_acceptance_r1/accepted_limited`

## C-only authorization

Sol/root authorizes only the M4-C manufactured discrete-control scope. The
single objective is a deterministic, declaration-level finite-volume /
conservative-difference control on `[0,1]^3` using a uniform Cartesian,
cell-centered grid with `nx, ny, nz >= 2` and `h=1/n` per axis. Face-centered
`K` and the frozen manufactured linear `u` are used to form the six-face flux
difference for each cell.

The independent exact oracle must represent the face fluxes and divergence
with `Fraction` arithmetic. The discrete divergence must be exactly `11/60`,
the source exactly `-11/60`, and every cell residual exactly `0`. The control
must bind mesh, topology, boundary closure, units, equation identity,
`source.owner`, `conservation_owner`, and provenance explicitly. Foreign or
mismatched input must produce typed failures.

The permitted deterministic output is an assembly payload (mesh/topology,
face coefficients/flux declarations, ownership/provenance and residual
terms). C must not solve, couple, invoke a candidate/provider, or make
physics/engineering claims. This is `manufactured_discrete_control` /
`screen_only` only.

## Typed failures and hard boundary

Required typed failures are `invalid_grid`, `invalid_topology`,
`invalid_boundary`, `unit_closure_failure`, `nonconservative_stencil`, and
`foreign_input`; implementations may refine paths/details while keeping codes
stable. No mesh beyond this manufactured control, general discretization,
matrix/vector solve, coupled solve, topology transfer, candidate binding,
provider invocation, physics, or engineering evidence is authorized.

D remains unauthorized. This decision does not close or credit `UP2-01`,
`UP2`, `B00`, `B04`, provider, mesh, engineering, physical, `R01-R10`, or
`L4`; the 39-node dependency and all parent gates remain open.

## Future ownership and paths

The suggested future source is
`src/RuntimeV4/M4Isolated/ManufacturedDiscreteControlV1.jl`, with corresponding
test and oracle files
`test/RuntimeV4/M4Isolated/manufactured_discrete_control_v1_tests.jl` and
`test/RuntimeV4/M4Isolated/oracles/discrete_control_oracle_v1.py`.
Evidence belongs under
`docs/implementation/UP2-01-PREPARATION/M4-C-DISCRETE-CONTROL/**`.

Source implementation, test/oracle, integration, documentation, and
independent review are five pairwise-distinct Luna roles. The reviewer cannot
review their own change or another role's same change. Any future heavy or
repeated run must be serial and retain raw stdout/stderr, PID or in-process
marker, UTC start/end, exit, input/output/artifact hashes, and failures.

## Future review and formal re-entry

Independent review must verify exact grid constraints, face-centered flux
construction, six-face conservative balance, Fraction result `11/60`, source
`-11/60`, per-cell residual zero, all six binding classes, typed failures,
deterministic payload, role separation, and absence of solve/coupling/
candidate/provider/physics paths. If it passes, only a separate Sol
`accepted_limited` decision may accept C at the stated ceiling.

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
No local C artifact substitutes for fresh authority, trust, candidate,
provider, B00/B04, solver, engineering, physical, or R01-R10 gates.

No code execution was performed for this scope decision; C is
`authorized_not_started`.

