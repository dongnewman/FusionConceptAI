# UP1-04A VNext T1 R4 runtime acceptance record

Date: 2026-09-18 (Asia/Shanghai)

This record is the runtime interpretation of the immutable R4 receipt under
`local_profile_r4_diagnostic_preflight/run_20260918_173528_993_b4f71741bd6146c1961724312d57898d/`.
The adjacent `local_profile_r4_diagnostic_preflight/` files remain a
preflight/runner contract and are not rewritten into an acceptance claim.

## Observed result

- Julia command started exactly once with `JULIA_NUM_THREADS=1` and exited `1`.
- Focused test result was `8` passing assertions and `1` error. This is a
  `program_exception`, not a T1 admission result: the first failure was
  `Vector{UInt8}(::NTuple{8269445,UInt8})` on the old T1 tuple hashing path.
- Timeout classification was false; no timeout kill was attempted.
- The runner performed no automatic retry (`autoRetry=false`, one start).
- All `18/18` protected owned paths were unchanged. Both postflight process
  observations were zero (`julia`/`julia-debug`/`desc`), so no child remained.

## Acceptance boundary

R4 is rejected for T1 runtime acceptance (`accepted=false`) and grants no T1,
T2, UP1, provider, mesh, solver, physical, engineering, authority, or R01–R10
credit. The current source repair replaces the failing conversion with direct
`invoke(SHA.sha256, Tuple{SHA.AbstractBytes}, bytes)` dispatch for both owned
`NTuple` and incoming `AbstractVector` paths. This report does not retroactively
turn the historical R4 receipt green; a new serialized runtime receipt is
required after static and independent review.

The focused diagnostic's exception digest is now restricted to fixed status,
stage, and exception type fields; exception text is not retained. The fixed
small vector oracle and the `8,269,445` fixed-pattern tuple/vector parity test
are static/test assets only until that new runtime lane is authorized.
