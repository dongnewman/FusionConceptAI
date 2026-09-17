# M4-B test/oracle execution R1

## Scope and ownership

Test/oracle owner: Luna `m4b_tests` (`gpt-5.6-luna`, high).  This record
covers only the isolated manufactured residual-lowering lane.  The test owner
wrote only:

- `test/RuntimeV4/M4Isolated/manufactured_residual_lowering_v1_tests.jl`
- `test/RuntimeV4/M4Isolated/oracles/residual_lowering_oracle_v1.py`

No shared entry, `Project.toml`, `Manifest.toml`, registry, A source, or B
source was modified by this role.  The B source hash used by the final run is
`0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`.

## Serialized execution and causal repair

Execution was strictly serial: Python oracle first, then Julia tests.  The
first Julia run (`command_02_julia_tests`) exited 1 with `51 pass / 2 error`.
The two required two-input owner-binding controls exposed a B-source defect:
`validate_manufactured_residual(d, ir)` collected an empty failure tuple as
`Vector{Union{}}`, then `push!` raised `ArgumentError: cannot convert a value to
Union{}`.  Its stdout, stderr, combined raw output, and receipt remain
unchanged and are retained as the failure history.

The source implementer made the single type-materialization repair.  The
repair run was then re-executed as two fresh processes, again Python before
Julia.  Both repair commands exited 0; Julia reports `53/53` and the Python
oracle reports exact Fraction terms `1/10`, `1/20`, `1/30`, total `11/60`,
source `-11/60`, residual `0`.  The repair is causal evidence for the source
fix, not a test relaxation.

| command | pid | exit | combined SHA-256 |
|---|---:|---:|---|
| Python initial | 100532 | 0 | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| Julia initial | 38524 | 1 | `32babe9221dfca94e7875310252362bf261a3f103c30ecc085cf72a4f9dbe4e6` |
| Python repair R1 | 109792 | 0 | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| Julia repair R1 | 2012 | 0 | `1994f192d90c1767e10bfea8b77b216d803787f90b4f5942c23f5e93fce8786e` |

Exact command/cwd/UTC timestamps, stdout/stderr/combined paths, input/output/
artifact hashes, and source-A/source-B hashes are in the four adjacent
`command_*.receipt.json` files.  No solver, mesh, discrete, assembly,
coupling, candidate, provider, physics, or engineering execution occurred.

## Result and ceiling

Result: `pass_limited` for the test/oracle execution only.  The claim ceiling
is `manufactured_residual_lowering` / `screen_only`.  This does not accept
M4-B, UP2-01, UP2, B00, B04, any R gate, or L4; C and D remain unauthorized.
