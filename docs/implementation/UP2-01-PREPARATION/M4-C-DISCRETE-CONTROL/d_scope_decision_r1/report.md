# M4-D manufactured coupled-solve control scope decision R1

Decision authority: `Sol/root`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Status: `authorized_not_started`  
Scope basis: C `root_acceptance_r1/accepted_limited`

## D-only authorization

Sol/root authorizes only an isolated manufactured two-region coupled
algebraic-solve control. D consumes two C payloads with identical grid
identity (default `2x2x2`) and an identity interface mapping. For each matched
cell it applies the fixed SPD block

`[[2,-1],[-1,2]] * [a,b] = [1,0]`,

whose exact Fraction solution is `a=2/3`, `b=1/3`, with block residual exactly
`0`. The direct 2x2 solve and resulting payload must be deterministic.

The two regions, grid identity, interface bijection, units, equation/source
identity, conservation owner, and provenance must be explicit bindings. A
foreign C payload or any mismatch must return a deterministic typed validation
failure rather than be coerced.

## Typed validation and hard exclusions

Required typed failures are `singular_block`, `non_spd_block`,
`grid_mismatch`, `nonbijective_interface`, `unit_mismatch`,
`owner_mismatch`, `provenance_mismatch`, `foreign_c_input`, and
`nonzero_residual`. The scope is limited to a manufactured control and has
ceiling `manufactured_coupled_solve_control` / `screen_only`.

D must not iterate a PDE solver, call production coupling, bind a candidate,
invoke a provider, or make physics/engineering claims. It does not close or
credit `UP2`, `B00`, `B04`, `R01-R10`, `L4`, or the unchanged parent goal.
The 39-node dependency and all formal gates remain open.

## Future paths and ownership

The suggested future source is
`src/RuntimeV4/M4Isolated/ManufacturedCoupledSolveControlV1.jl`, with
corresponding test and oracle files
`test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl`
and `test/RuntimeV4/M4Isolated/oracles/coupled_solve_control_oracle_v1.py`.
Evidence belongs under
`docs/implementation/UP2-01-PREPARATION/M4-D-COUPLED-SOLVE-CONTROL/**`.

Source implementation, test/oracle, integration, documentation, and
independent review are five pairwise-distinct Luna roles. The reviewer cannot
review their own change or another role's same change. Any future execution
must remain isolated and serial, retaining raw stdout/stderr, PID or
in-process marker, UTC start/end, exit, input/output/artifact hashes, and
failure history.

## Review and formal re-entry

Independent review must verify two identical C payload identities, default
`2x2x2` matching, identity interface bijection, SPD block validation, exact
Fraction solution `2/3,1/3`, block residual zero, deterministic payload,
typed failures, binding completeness, and absence of iterative PDE solver or
production coupling. If it passes, only a separate Sol `accepted_limited`
decision may accept D at the stated screen-only ceiling.

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
No local D artifact substitutes for fresh authority/trust, candidate,
provider, B00/B04, solver, engineering, physical, or R01-R10 gates.

No code execution was performed for this scope decision; D is
`authorized_not_started`.

