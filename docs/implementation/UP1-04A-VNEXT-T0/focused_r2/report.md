# AD-30 T0 focused R2 receipt

The exact focused command executed once after the R5 independent precheck:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

The process started as PID `43044` at `2026-09-14T23:17:00.1036158+00:00`
and ended at `2026-09-14T23:17:10.3812580+00:00` with real Julia exit code
`1`. Raw stdout and stderr are preserved byte-for-byte in `stdout.bin` and
`stderr.bin` with their SHA-256 values in `evidence_manifest.json`.

The first real failure was:

```text
AD-30 T0 preserves complete bodies and typed gaps: Test Failed at .../vnext_declaration_transport_v1_tests.jl:139
Expression: all((occursin("terminal_deferred", gap) for gap = admission.gaps))
```

That group reported `9 passed, 1 failed, 0 errored, 0 broken`; stderr reported
`Some tests did not pass: 9 passed, 1 failed, 0 errored, 0 broken.` The focused
run was not repaired or rerun in this task. Later assertion groups therefore
have no execution credit from this receipt.

Pre/post dirty count remained `304`, and post-run Julia/DESC process checks were
empty. The T0 result remains `accepted=false`, contract-only, T1 no-go, with no
external receipt, provider, mesh, physical, or R01-R10 credit.

