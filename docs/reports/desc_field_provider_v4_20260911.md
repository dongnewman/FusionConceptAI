# DESC field provider report

The new field edge consumes the real candidate-bound DESC HDF5 output and
reopens it in a fresh DESC process. It extracts stable geometry/equilibrium
fields at explicit `(rho, theta, zeta)` coordinates. The typed request binds
the current candidate and all upstream execution identities. The provider
checks DESC 0.17.3 quantity metadata and emits strict TSV that Julia reparses
into hashed typed samples. Receipt replay covers the request, output, adapter,
upstream HDF5, Python executable, and imported DESC module.

Focused result: 62/62 assertions passed and
`DESC_FIELD_PROVIDER_FOCUSED_PROCESS_EXIT=0`. The standalone runner emitted
`DESC_FIELD_PROVIDER_EXECUTED=1`, `DESC_FIELD_PROVIDER_RUN_EXIT_CODE=0`, and
exited 0. Negative tests reject foreign or duplicate requests,
non-finite/out-of-domain points, a wrong output NFP, and tampered
request/result/adapter bytes; a synthetic failing adapter preserves its actual
exit code 9.

Adjacent regressions passed in separate exit-0 processes: the candidate-bound
DESC request/provider execution tests (70/70), geometry program interpreter
tests (81/81), geometry compatibility proof tests (89/89), and three-dimensional
physical-input composition tests (157/157). The repository-wide
`test/runtests.jl` process also completed with `FULL_TEST_PROCESS_EXIT=0`.
Independent review found no remaining P1/P2 issue after the request and output
unit contracts were aligned to DESC's native metadata.

The edge is `screen_only`. It samples one non-convergence-qualified global
equilibrium and does not supply multi-region constitutive/material laws,
interface traces or fluxes, solver-convergence evidence, physical validation,
or engineering evidence. Focused reproduction is:

    julia --project=. test/runtime_v4_desc_field_provider_tests.jl
