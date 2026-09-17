# M4-B residual lowering delivery R1

Status: `delivery_complete_review_pending`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Scope contract: `../b_scope_decision_r1/` (`authorized_not_started`)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Delivery boundary

This record delivers the isolated B manufactured residual-lowering slice for
independent review. The ceiling is `manufactured_residual_lowering` /
`screen_only`. B lowers the accepted A declaration to an analytic residual
declaration only:

`div(K grad(u)) = 1/10 + 1/20 + 1/30 = 11/60`,
`source = -11/60`, and `R = -div(K grad(u)) - f = 0`.

This is not mesh generation, discretization, matrix/vector assembly, coupled
solving, topology transfer, candidate binding, provider invocation, physics,
or engineering evidence. It does not close or credit `UP2-01`, `UP2`, `B00`,
`B04`, provider, mesh, engineering, physical, `R01-R10`, or `L4`. C and D
remain unauthorized.

## Frozen inputs and ownership

The final frozen hashes used by test and integration evidence are:

- A source `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl`:
  `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`.
- B source `src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl`:
  `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`.
- B test `test/RuntimeV4/M4Isolated/manufactured_residual_lowering_v1_tests.jl`:
  `c7032beecfcca29db8a751eec4aaf4797eadfed66b12e8da611c392783740f73`.
- B oracle `test/RuntimeV4/M4Isolated/oracles/residual_lowering_oracle_v1.py`:
  `0d89c69ab3689a0cf7cde9756f95a76b8f7e4c8fc93a7a99ed9aa460bd5781fd`.

The source implementer, test/oracle owner, integration owner, documentation
owner, and independent reviewer are five pairwise-distinct Luna roles. The
source implementer made the B repair; the test/oracle owner executed tests;
the integration owner performed replay; this record is documentation-only.
The independent reviewer and Sol acceptance remain pending. No shared
RuntimeV4 entrypoint, registry, Project, Manifest, candidate, provider, or A
source file was changed by the B delivery record.

## Causal failure and repair

The first serial test sequence was Python followed by Julia. Python exited
zero. Julia then exited `1` with `51 pass / 2 error` in the two owner-binding
controls. `validate_manufactured_residual(d, ir)` collected an empty failure
tuple as `Vector{Union{}}`; a later owner-binding `push!` raised
`ArgumentError: cannot convert a value to Union{}`. The failed receipt and
stdout/stderr/combined raw are retained, not overwritten.

The source implementer made one causal type-materialization repair:
`ManufacturedResidualLoweringFailureV1[f for f in result.failures]`. The
repair did not relax tests or widen scope. The repaired Python oracle returned
the exact Fraction terms and residual zero; repaired Julia returned `53/53`.

A separate integration preflight capture also hit a PowerShell variable
collision. Its raw streams remain at
`integration_r1/archive/harness_capture_abort_20260916T0718Z/`; this is
non-counted historical capture evidence, not one of the four replay runs.

## Execution evidence

All command receipts retain exact command, cwd, PID, UTC interval, exit,
input/output/artifact hashes, and stdout/stderr/combined raw paths.

Test/execution history:

| run | PID | exit | result | combined SHA-256 |
|---|---:|---:|---|---|
| initial Python | 100532 | 0 | oracle exact control | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| initial Julia | 38524 | 1 | 51/53, 2 typed-vector errors | `32babe9221dfca94e7875310252362bf261a3f103c30ecc085cf72a4f9dbe4e6` |
| repair Python | 109792 | 0 | exact residual 0 | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| repair Julia | 2012 | 0 | 53/53 | `1994f192d90c1767e10bfea8b77b216d803787f90b4f5942c23f5e93fce8786e` |

Integration replay, strictly serial Python, Python, Julia, Julia:

| sequence | PID | exit | result | combined SHA-256 |
|---:|---:|---:|---|---|
| 1 Python | 110172 | 0 | canonical exact payload | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| 2 Python | 104420 | 0 | byte-identical canonical payload | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| 3 Julia | 97276 | 0 | 53/53 | `dcf65a06f4a3132cc813564f62d2b82090aa7df6853c0791b8edca0d405691d7` |
| 4 Julia | 2400 | 0 | 53/53 | `1994f192d90c1767e10bfea8b77b216d803787f90b4f5942c23f5e93fce8786e` |

The detailed UTC intervals and raw paths are retained in
`../test_execution_r1/command_*.receipt.json` and
`../integration_r1/command_*.receipt.json`; all four integration stderr
streams are empty. The integration receipts also retain the final input
hashes and per-stream hashes.

## Review handoff and formal gates

Independent review must verify the causal repair, final source/test/oracle
hashes, exact arithmetic, owner/equation/unit/provenance bindings, typed
foreign/mismatch failures, serial replay, raw/PID/exit/hash completeness,
five-role separation, and no shared-entry mutation. The preflight variable
collision raw must remain marked historical/non-counted.

If review passes, only a separate Sol `accepted_limited` decision may accept
this B slice, with no ceiling above `manufactured_residual_lowering` /
`screen_only`. That decision cannot authorize C or D. Formal re-entry remains
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`;
the 39-node DAG, all R gates, B00/B04, provider, engineering, physical and
solver requirements remain open.

