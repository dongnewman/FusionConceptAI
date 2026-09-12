# N1 manufactured recovery benchmark

This is an opt-in numerical verification benchmark, not a candidate/provider
or physical-evidence path. `scripts/runtime_v4_manufactured_recovery_benchmark.jl`
constructs the existing curved-Q1 quadrature shape and calls the production
`assemble_spatial_system_v4` and `solve_spatial_state_v4` with explicit source,
traction, and normal-field callbacks.

The manufactured subject is `B=e_phi` (one tesla) and constant `p=1e5 Pa`.
Its independently derived source is `-e_R/(mu0 R)`, because
`div(T)=-e_R/(mu0 R)` for this field and assembly encodes `div(T)=source`.
Exterior traction is the analytic stress
traction, the normal-field callback is `B dot n`, and toroidal flux is `pi`.

The preregistered dimensionless refinement family is `h=1/2,1/3,1/4`, with
`rho=.5` retained as a region boundary and 1 field period (`nfp=1`); it uses
at most about 528 unknowns. Three materially distinct perturbations are
applied at each level. Results include solver status/exit, relative solution
error, scaled residual maximum, and adjacent observed orders
`log(e_i/e_j)/log(h_i/h_j)` (or null when undefined). Importing performs no
solve; direct execution emits structured JSON and runs the bounded benchmark.
Passing one path argument writes that JSON as a run artifact. The record binds
the benchmark and production solver source hashes and includes truth residual,
stopping reason, attempt counts, accepted updates, final residual, recovery
error, and adjacent observed orders.
An observed order is emitted only when both adjacent solves converge with
finite positive recovery errors; failed or stationary endpoints produce null
with an explicit reason. Every result also reports its initial error and
whether all accepted updates had strict objective decrease and meaningful
scaled state motion.

After the v2 run exposed a 12-update cap for the largest perturbation, the
separately preregistered v3 runner uses `h=1/3,1/4,1/5`, keeps all three
perturbations, and raises only the iteration budget to 48. The new `h=1/5`
level has 1220 unknowns. Its plan is frozen in
`runs/goal_recovery_20260913_012528_cst/n1_refined_family_plan.json`; v3 cannot
retroactively change the v2 result.
