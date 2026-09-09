# Gridap B2 convergence report (2026-09-09)

The B2 runner executes the pinned Gridap qualification environment and real
candidate-bound G2 rederivations at 5/9/17 nodes per axis. Its solution errors
are Gridap physical-volume L2 and H1-seminorm integrals. The independently
assembled FE function is admitted only when its matrix, right-hand side, and
free DOF values exactly reproduce the B1 report. Runtime and memory are
recorded independently and excluded from deterministic identity.

The source transfer diagnostic is chart cell-centre RMS and the boundary
transfer diagnostic is chart face-centre L-infinity. Neither is represented as
a physical-domain norm.

This is a manufactured numerical control and remains `screen_only`. Extract,
wrap, test-only, and reject boundaries are explicit: B2 extracts only typed
B1 compilation inputs, wraps only its own sealed convergence receipts, is
test-only evidence, and rejects mixed identities, duplicate hashes, failed or
non-refining solves, and any promotion above `screen_only`.

## Definitive pinned run

Command:

`julia --startup-file=no --history-file=no --project=tools/qualification/gridap scripts/run_v4_gridap_field_convergence.jl`

Result: exit 0, `GRIDAP_B2_OK`.

| Nodes/axis | Cells | Free DOFs | Solution L2 | H1 seminorm | Source cell-centre RMS | Boundary face-centre L-inf | Residual inf |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 5 | 64 | 27 | 1.2296866291411006 | 5.6328357737805845 | 1.875 | 0.828125 | 2.220446049250313e-16 |
| 9 | 512 | 343 | 0.3093923279431648 | 2.7632236881230416 | 0.46875 | 0.2548828125 | 8.881784197001252e-16 |
| 17 | 4096 | 3375 | 0.07743601858664473 | 1.373269189825189 | 0.1171875 | 0.07061767578125 | 1.8318679906315083e-15 |

Observed L2 orders: `(1.990781381333485, 1.998360739751123)`.
Observed H1-seminorm orders: `(1.0275090544498333, 1.00873790377105)`.

The focused test passed 17/17 with exit 0. The acceptance is B2-only,
`manufactured_control`, and `screen_only`; it does not close B3, cross-code
transfer, physical validation, engineering feasibility, or whole-device
authority.
