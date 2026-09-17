# UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC software precursor acceptance

Sol accepts the local source/test software implementation slice as
`accepted_limited`, based on R9 focused evidence and independent postrun R3
`pass_limited` review. This acceptance covers only the closed typed,
control-only source/edit contract and its local software behavior.

Frozen R9 receipt:

- command: `julia --startup-file=no --project=. test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`
- PID: `51564`
- UTC: `2026-09-15T03:32:47.1548572Z` – `2026-09-15T03:33:03.4679458Z`
- exit: `0`; summary: `167/167`
- stdout: `138` bytes, SHA256 `6c21dbb806fc5c200ea2f11d31c2b342e8fb6ac0c40d1336c50513bcb354455f`
- stderr: `0` bytes, SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- dirty rows: `310` before and `310` after
- Julia/DESC process snapshots: empty before and after
- source SHA256: `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`
- test SHA256: `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`

R8 remains preserved as historical evidence: `149 pass / 18 fail` due to the
snapshot-consumption test-helper bug. R9 is the repaired final focused run;
its raw stdout, stderr, exit and receipt remain immutable. The independent R3
review is recorded as `pass_limited` for this local software scope.

The accepted scope includes typed construction, candidate/parent/child/source
identity, provenance slots, separated contract and physical status, immutable
source payload state, one existing fault `mode` edit, closed operation history,
hash recomputation, typed absence and atomic failure behavior. The historical
operation name `replace_fault_source_payload` does not grant generic dynamic
editing or physical control timing.

The machine work-order node remains `planned` / `proposal` /
`accepted=false` / `review_pending`. This record grants no actual control
child, source-backed T1/T2, realization, binding, feedback, T0, provider,
mesh, engineering, physical, search, B00, B04 or R01–R10 credit. AD-31,
AD-32, AD-33, AD-34 and the current DAG remain unchanged; this local sibling
does not add a new architecture audit node or close T1.
