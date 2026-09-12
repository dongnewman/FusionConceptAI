# Executed verification and bounded design propagation

The revision consumes one revised candidate's genuine complete-weak-model and
magnetic-circuit results. No manufactured input is admitted as a production
physics or engineering result. Manufactured unit checks have software scope.

## Prior-code audit before implementation

| Legacy source in `../outputs/fusion_concept_ai/src` | Decision | Reason |
| --- | --- | --- |
| `generic_vvuq_runtime_v94.jl`, `solve_graph_system_v94` | extract | Central finite differences of all state columns are a useful independent derivative algorithm. Bind new residual/state bytes and all four current DOFs. No legacy graph registry or candidate authority is imported. |
| `generic_vvuq_runtime_v94.jl`, `run_pvw_numerical_vvuq_v94` | test-only | The plasma-vacuum-wall manufactured 1-D comparison does not establish applicability for this DESC-backed 3-D candidate. Its old geometry and states cannot be wrapped into the new candidate. |
| `physical_vvuq_runtime_v96.jl`, `numerical_vvuq_physical_graph_v96` | extract | Independent factorization is a useful software check. Current implementation uses SVD of the current transformed weak system to obtain its unconstrained residual floor. No legacy evidence/admission flags are accepted. |
| `physical_vvuq_runtime_v96.jl`, `solved_physical_metric_v96` | reject | Old graph closure and eligibility flags are not the current typed candidate contract. Upstream validity is checked against concrete current outputs. |
| `numerical_verification.jl` | reject | The default measurement floor is not candidate data. Adding it to discretization error would conceal different error sources and manufacture an uncertainty statement. |

## Equations and evidence boundary

The physics branch has four amplitudes and 36 moments. With
`y=[a1^2,c1,a2^2,c2]`, its reduced residual is `R=C*y+d`.
The production nonlinear iteration remains the source of its actual final
state. An independent SVD computes the least-squares floor of
`diag(1/scales)*(C*y+d)`. An unconstrained transformed optimum can violate
positivity or declared bounds; consequently it is only a lower bound. The
squared objective above this unconstrained floor combines the cost of the
declared bounds with algorithmic suboptimality. A constrained optimum is needed
to separate those contributions. The floor measures incompatibility
of this discrete model, moment set, boundary conditions and current quadrature;
it does not estimate integration error or physical model discrepancy.

Every analytic Jacobian column is compared against central differences of the
independent residual implementation using `h=cbrt(eps)*max(abs(xj),1)`.
Finite differences here verify derivatives, never boundary limits.

For the circuit, the independent continuous solution uses
`tau=L/(Rwire+Rload)` and `i=emf/(Rwire+Rload)*(1-exp(-t/tau))` during the
declared ramp, followed by exponential decay. Its current integral gives
`Bhat=-Rload*integral(i)/(N*pi*r^2)`. The nominal comparison is applicable only
while protection remains unlatched. It is equation/software verification of the
ideal lumped RL model and does not validate an installed magnetic pickup.

Deterministic propagation evaluates the eight Cartesian corners of the G3-owned
loop-radius, resistivity and readout-resistance design intervals. Every corner
has a realization hash, fresh circuit response and a binding to the same real
physics input. These are exploratory design intervals, not measured uncertainty
distributions. Min/max across the eight evaluations are observed corner ranges,
not certified global interval bounds, probabilities or confidence intervals.

Two additional coupled evaluations use the G2-owned pressure multiplier
endpoints, 0.9 and 1.1. Each actually reruns the bounded four-state nonlinear
solver and independently checks its complete raw weak residual. The newly
computed outer magnetic amplitude then maps the same genuine sampled field
into a fresh circuit response. Pressure changes the declared constitutive and
prescribed exterior-traction terms with DESC reference geometry and B fixed.
This is a conditional constitutive sensitivity, not an equilibrium-profile
uncertainty calculation; DESC is not re-equilibrated. The same candidate owns
the interval, while each realization has its own input/result binding and
retains physical-solver failure and engineering-applicability status.

Numerical accounting separates integration diagnostics, spatial-discretization
availability, time-discretization differences, bound cost and nonlinear-solve suboptimality,
and final weak-model residual. Missing applicable experimental observations,
independent physical solver evidence and model-discrepancy basis keep physical
validation `unsupported`. Independent implementation is not an independent
physical model and grants zero physical validation credit.

## Reproduction

The integrating agent serializes Julia and DESC execution. Unit verification:
`julia --project=. test/runtime_v4_executed_verification_uq_tests.jl`.
Production execution is only through the revised-candidate unified runner;
execution results, hashes and explicit exit codes are recorded in the companion
report after that run.

## Executed r2 arithmetic and constrained-solver audit

The actual branch returned `fail`, exit `1`. Its independent residual check
exceeded the frozen maximum scaled-difference threshold `1e-10`: measured
`5.027639122847472e-9`. No threshold was relaxed. The worst row is the core's
constant-z test: raw stress terms have an absolute contribution sum about
`1.3591981e7 N`, while their net moment is near `1e-9 N`. The row scale is `1`.

`scripts/verification_decimal_audit_v4.py` reads the actual 17,920 raw samples,
retains their exact parsed binary64 values, and evaluates scalar coefficient
contractions with 70-digit Decimal arithmetic. It independently constructs all
36 rows and four analytic Jacobian columns. Production versus high-precision
Jacobian relative differences are `7.83e-15, 7.74e-15, 8.62e-15, 8.21e-15`.
This supports floating arithmetic and cancellation as the explanation for the
cross-implementation discrepancy, rather than an omitted derivative term. It
does not validate quadrature, the spatial model, or the physical field.

The original whole-matrix FD gate passed (`2.45424e-10 < 1e-7`), but it is not
a columnwise gate. The pressure-column relative errors `5.88716e-7` and
`7.16998e-7` exceed `1e-7` separately. Large magnetic columns dominate the
matrix norm. Future work needs explicit per-column criteria and compensated or
precision-controlled raw reduction, retaining the failed original result.

The same audit enumerates all 81 faces of the full-rank transformed box
quadratic; 25 face minimizers are feasible. The bounded diagnostic optimum has
scaled residual `0.96191045276665`, versus accepted `1.0208025961615699` and
unconstrained floor `0.46110931610043804`. Squared excess
`0.8294161389355874` splits into bound cost `0.7126499177471279` and algorithmic
gap `0.11676622118845958`. These diagnostic states never replace the accepted
physics or engineering input. The production solver remains exit `3`.

**r2 frozen-output erratum:** `ExecutedVerificationUQV4.jl:138` and the original
serialized `solve_error.interpretation` incorrectly called the whole excess
above the infeasible unconstrained optimum solver suboptimality. The numeric
excess is correct; that attribution is not. The diagnostic JSON and companion
report separate constraint cost from algorithmic gap. The original source is
preserved in `runs/revised_chain_20260912_audit/r2_executed_source`.
Only the explanatory string was corrected after r2 completed; its source hash
is now `17e2de46e47d9575367045c328d14c9d63d1e8ba2c929fd992da6d6dd04bd9fd`.
No numerical value, threshold or candidate declaration changed. The integrating
agent is re-executing verification from validated same-candidate checkpoints;
no old receipt is silently rewritten.
