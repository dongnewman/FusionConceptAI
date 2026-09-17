# M4-B residual-lowering scope decision R1

Decision authority: `Sol/root`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Status: `authorized_not_started`  
Scope basis: M4-A `accepted_limited`, `independent_review_r1/pass_limited`

## Authorized B-only contract

Sol/root authorizes only the future B scope contract. B's sole target is to
lower the A manufactured equation IR into an analytic residual declaration:

`div(K grad(u)) = 1/10 + 1/20 + 1/30 = 11/60`,
`source = -11/60`, and `R = -div(K grad(u)) - f = 0`.

The contract must preserve units, equation identity, source identity,
conservation-owner binding, and provenance binding. It must explicitly keep
`source.owner` distinct from `conservation_owner`; a foreign source reference
or any owner/equation/provenance mismatch must produce a deterministic typed
failure, not be silently coerced.

This is authorization of a range contract, not an implementation or test
result. B has not started. No source, test, oracle, integration, or shared
entry file is created by this record.

## Hard exclusions and ceiling

B must not create or use a mesh, discretize, assemble a matrix/vector, invoke
a solver, perform topology transfer, couple fields, bind a candidate, invoke
a provider, or make physics/engineering claims. Its maximum claim ceiling is
`manufactured_residual_lowering` / `screen_only`.

This decision does not authorize C topology transfer or D coupled solve, and
does not close or credit `UP2-01`, `UP2`, `B00`, `B04`, provider, mesh,
engineering, physical, `R01-R10`, or `L4`. The 39-node DAG and every parent
acceptance gate remain open.

## Future ownership and file contract

The future B source path is
`src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl`.
The future test/oracle paths are
`test/RuntimeV4/M4Isolated/manufactured_residual_lowering_v1_tests.jl` and
`test/RuntimeV4/M4Isolated/oracles/residual_lowering_oracle_v1.py`.
Evidence belongs under
`docs/implementation/UP2-01-PREPARATION/M4-B-RESIDUAL-LOWERING/**`.

Five roles remain pairwise-distinct Luna roles: source implementer,
test/oracle owner, integration owner, documentation owner, and independent
reviewer. The reviewer cannot review their own change or the same change of
any other role. Heavy or repeated execution, if later authorized by its
owners, remains serial and must retain raw stdout/stderr, PID or in-process
marker, UTC start/end, exit code, input/output/artifact hashes, and failures.

## Required future review and re-entry

Before B can claim completion, an independent reviewer must check the frozen
A input hash, exact analytic terms, units, equation/source/conservation-owner
and provenance bindings, explicit `source.owner` distinction, foreign and
mismatch typed failures, no mesh/discrete/solve/coupling/provider/candidate
imports, role separation, and exact cleanup. Only a separate Sol decision may
accept a bounded B result, with no ceiling above
`manufactured_residual_lowering` / `screen_only`.

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
Fresh authority/trust, candidate identity, provider, B00/B04, solver,
engineering, physical, and R01-R10 evidence remains required at its owning
gate. No A or B local artifact substitutes for those requirements.

No Julia, Python, solver, mesh, or physical execution was performed for this
scope decision; B remains `authorized_not_started`.

