# Executed verification and conditional propagation, 2026-09-12

The revised candidate actually ran independent numerical checks, an analytic
circuit comparison, a half-step circuit calculation, eight engineering design
corners and two pressure-endpoint reduced solves followed by circuit responses.
Verification returned **fail, exit 1**. Physics returned **fail, exit 3**;
all circuit evaluations executed with exit **0**. Physical validation and
engineering applicability remain **unsupported**. These results do not establish
full-function-space MHD closure or a qualified integrated device.

**Latest execution, r3:** the same-candidate downstream re-execution completed
with runner exit `0`, verification exit `1`. Recursive r2/r3 comparison found
zero numeric changes and unchanged statuses. The one explanatory correction
separates constraint cost from algorithmic suboptimality; remaining changed
values are source, artifact paths and derived binding hashes. The r2 measurements
below therefore remain applicable, without upgrading the failed numerical gate.

Run: `runs/revised_chain_20260912_r2`. Candidate:
`7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548`.
Context: `de87eb7f96b38dda09e4643fcbce20db17d21b3f2207a416f755768b096fd14d`.
The fresh DESC result, 17,920 volume/exact-surface samples, stopped four-state
solve and actual circuit input all belong to this revision.

## Actual execution

| Calculation | Measured result | Outcome and scope |
| --- | --- | --- |
| Independent scalar stress, all 36 weak residual rows | L2 difference `4.0178391716654215e-8 N`; maximum row-scaled difference `5.027639122847472e-9` | fail against frozen `1e-10` maximum scaled-difference gate |
| Central differences, all four state columns | Whole-matrix relative difference `2.454238250289236e-10` | aggregate pass against `1e-7`; not a columnwise pass |
| Strong-volume vs natural weak moments | Difference `4.6331986969948224e-8 N`; stress-normalized `6.081740099007787e-15` | consistency diagnostic; not an isolated quadrature-error estimate |
| Independent transformed SVD | rank 4; unconstrained floor `0.46110931610043804` | lower bound; its state violates declared bounds |
| Analytic RL and actual half-step integration | Current error `5.938629167443529e-5` to `3.029586947617081e-5 A`; observed order `0.9710088368` | software/time-discretization check pass |
| Eight G3 design-corner responses | All evaluated from actual stopped-physics field | conditional execution, upstream fail retained |
| G2 pressure multipliers 0.9 and 1.1 | Each nonlinear solve exit 3; each subsequent circuit exit 0 | actual coupled sensitivity; no converged-state uncertainty claim |
| 70-digit raw arithmetic and 81-face box audit | Python exit 0; persisted source and JSON | explanation only; original states and statuses unchanged |

Focused software tests: **24/24, exit 0**, in
`runs/revised_chain_20260912_audit/verification_focused_retry.log` and `.exit`.
The first attempt had a Julia top-level docstring error; the header was changed
to a block comment before retry. These manufactured tests carry software credit
only, independently of the failed genuine-input numerical gate.

## Residual failure and all Jacobian columns

The worst row is 3, `plasma_core:phi0:z`, scale `1`. Production gives
`6.975348477065605e-10 N`; the scalar implementation gives
`-4.330104275140911e-9 N`; a 70-digit Decimal reduction of the same binary64
inputs gives `-3.047006756614572e-10 N`. Absolute primitive coefficient
contributions to this cancelling row sum to about `1.359198139e7 N`.
For row 15, `plasma_edge:phi0:z`, the three values are respectively
`2.374604475714266e-8`, `2.784236130537465e-8`, and
`2.296265455026563e-9 N`.

These measurements support floating arithmetic/cancellation as the explanation
for the tiny cross-implementation discrepancy. They do not remove the failed
gate or explain away the actual weak residual near `1.849e7 N`. No q5/q6
sequence or relaxed threshold was used.

| Column | Reference norm | FD absolute error | FD relative error | Production vs 70-digit analytic |
| --- | ---: | ---: | ---: | ---: |
| `a1` | `8.570818546e6` | `1.550952993e-3` | `1.809573945e-10` | `7.830468355e-15` |
| `c1` | `5.285069722e3` | `3.111405088e-3` | `5.887159966e-7` | `7.743577507e-15` |
| `a2` | `3.055007248e7` | `3.808007706e-3` | `1.246480744e-10` | `8.622303657e-15` |
| `c2` | `8.138809413e3` | `5.835509152e-3` | `7.169978870e-7` | `8.211567038e-15` |

Every FD column uses `h=6.0554544523933395e-6`. The large magnetic columns
dominate the matrix norm. **The pressure columns would fail a separate `1e-7`
columnwise criterion.** The high-precision analytic columns agree with the
production Jacobian near `8e-15` in every column, supporting cancellation
divided by a small FD step rather than an omitted pressure derivative. Future
work needs precision-controlled reductions and declared per-column criteria;
the aggregate pass cannot certify every column to `1e-7`.

## Distinct numerical quantities and the frozen-output erratum

**Integration:** the measured strong/weak discrepancy uses the same raw grid
and field derivatives. It checks an identity but cannot isolate quadrature
error from derivative/geometry consistency.

**Discretization:** spatial enrichment is not implemented or executed. Four
amplitudes and affine moments do not establish spatial convergence. Circuit
time refinement actually ran at 10 and 5 microseconds, with 401 and 801 samples.
Maximum reconstructed-field error against the analytic RL solution decreases
from `7.433442290116646e-5 T` to `3.792164673534627e-5 T`; the endpoint
difference is only `5.9696136922582355e-12 T`, so it would hide transient error.

**Constraints and solve error:** the accepted trajectory reduces the scaled
norm `1.7722383745929757` to `1.0208025961615699`, stopping at
`(0.5,0.5,0.5944771568624893,0.5)` with `bounded_line_search_failed`, exit `3`.
The raw residual instead rises to `18489788.22812916 N`; the weighted objective
and raw force norm are distinct. The unconstrained SVD state
`(0.0453712566,-3.4398772284,0.3534030901,-6.9549355868)` violates the bounds.
The full-rank box-face diagnostic gives
`y=(0.25,1.009628019402574,0.25,0.5)` and norm `0.96191045276665`.
The accepted-state gradient
`(0.1935794712,-0.0369847876,0.7137380009,0.1254899827)` is not a bounded KKT
stationary point, confirming solver stagnation independently of the nonzero
best achievable moment residual.

**Erratum:** the frozen r2 `solve_error.interpretation` and
`ExecutedVerificationUQV4.jl:138` incorrectly attribute the whole squared
excess `0.8294161389355874` above the infeasible unconstrained floor to solver
suboptimality. The independent box audit splits it into bound cost
`0.7126499177471279` and algorithmic objective gap `0.11676622118845958`.
The numeric excess was correct; the attribution was not. This report and
`decimal_audit.json` correct that interpretation while preserving original
bytes. The diagnostic state never replaces accepted physics or circuit input.

**Model residual:** final scaled weak norm is `1.0208025961615699`, strong-force
RMS `(8838.037755,16737.6894482) N/m3`, and peak interface traction jump
`297184.0215876577 Pa`. These describe the declared reduced ansatz, moment
space and boundary problem; they are not measured physical model bias. DESC
equilibrium convergence remains unattested by its provider receipt.

Circuit discrete equation residual is `6.245004513516506e-17 V`; discrete energy
identity residual is `-1.3607121076497305e-22 J`. Backward Euler dissipation is
a separate `5.291477213508588e-10 J`, reducing to `2.71135121490893e-10 J` at
half step; it is not a nonlinear-solve residual or a physical loss error.

## Deterministic propagation actually evaluated

The eight corners use G3 exploratory intervals: radius `[0.0045,0.0055] m`,
resistivity `[1.6e-8,1.9e-8] ohm*m`, resistance `[8,12] ohm`. Their source is
the engineering design declaration, not measured tolerances or distributions.

| Observable | Minimum evaluated corner | Maximum evaluated corner |
| --- | ---: | ---: |
| Emf peak, V | `0.0272435745259716` | `0.0406971915758341` |
| Current peak, A | `0.00223840066741374` | `0.00497764010557103` |
| Reconstructed field change, T | `0.0834677895048686` | `0.0846327927249488` |
| Joule energy, J | `1.16666213990905e-7` | `3.79402002126479e-7` |

These are evaluated corner ranges, not certified global bounds, confidence
intervals or probabilities. Upstream is fail, applicability unsupported,
physical credit zero. Pressure endpoints also use an explicit exploratory
interval at fixed DESC geometry/reference B:

| Pressure multiplier | Physics exit | Scaled residual | Projected B, T | Circuit exit | Reconstructed change, T |
| --- | ---: | ---: | ---: | ---: | ---: |
| `0.9` | `3` | `1.0164822470110202` | `0.8564838623599179` | `0` | `0.08420014374731856` |
| `1.1` | `3` | `1.0251522801683723` | `0.8564838623955910` | `0` | `0.08420014375082549` |

Endpoint independent residual checks also fail `1e-10`, at
`3.466714169010932e-9` and `2.883907264167219e-9`. Near-identical circuit
responses do not establish physical robustness: both solves failed, and the
fixed-field ansatz and active bounds restrict the response. DESC was not
re-equilibrated. Every realization retains its hash and invalid upstream state.

## Remaining blockers

| Category | Current state | Recovery |
| --- | --- | --- |
| Arithmetic verification | executed; strict residual gate fail; aggregate FD masks column scales | compensated/precision-controlled reduction, per-column criteria, frozen-protocol rerun |
| Bounded solve | executed; exit 3, non-KKT stop | active-constraint-aware method, then genuine downstream recalculation if state changes |
| Spatial model/verification | four-state model executed; enrichment not implemented | candidate-owned richer states/tests and actual enriched solves |
| Isolated integration error | identity diagnostic executed; pure estimate unsupported | targeted independent integration/derivative evidence |
| Physical validity | fresh DESC execution; convergence/applicability unattested | machine-readable optimization outcome and appropriate field/residual checks |
| Engineering applicability | circuit executed; placement/aperture and transient-field applicability unsupported | external-field/aperture mapping and applicable transient input/model |
| Physical validation/model discrepancy | no applicable dataset/provider; not executed | independent held-out observations or applicable independent physical solver plus discrepancy basis |
| Statistical UQ | no distribution basis | justified distributions; exploratory intervals alone do not supply them |

## Raw evidence and reproduction

Paths below are repository-relative. The independent audit used Python 3.13.5
and NumPy 2.1.3, launched no Julia/DESC and replaced no candidate outputs.
Its process and stored exit code are `0`.

| File | SHA256 |
| --- | --- |
| `runs/revised_chain_20260912_audit/r2_executed_source/ExecutedVerificationUQV4.jl` (r2 frozen source) | `f4fb49c728c342266942f5fbf01a07aa54c3091bf074862a710e2ec70ad8de60` |
| `src/RuntimeV4/ExecutedVerificationUQV4.jl` (wording correction only) | `17e2de46e47d9575367045c328d14c9d63d1e8ba2c929fd992da6d6dd04bd9fd` |
| `scripts/verification_decimal_audit_v4.py` | `da6308e27e2735faba7ea5e04fff0580d72aeb2ad72a1b961bb74b7002aad8db` |
| `runs/revised_chain_20260912_r2/physics/raw_samples.tsv` | `63316cde9bad0d45902ca275383b4e496ddda265f9c480c8bc40f3d34d7b2f8f` |
| `runs/revised_chain_20260912_r2/verification.json` | `b1d5bdd5ea3a649e2d4398b0b737709924296b1aa1f3a387e6eda9c7b04d705b` |
| `runs/revised_chain_20260912_r2/verification/numerical_and_propagation.jls` | `ff1d80d340cfdfafd7131f1e58b858dcb0d0c2a2dfc6f3db57ef7a9776b2291a` |
| `runs/revised_chain_20260912_r2/verification/decimal_audit.json` | `9e390f786b296e25ce8f5353963721f934adcb98bc9607ec54b9becf19a4242f` |

`verification/verification.exitcode` contains `1`;
`verification/decimal_audit.exitcode` contains `0`. The readable raw result is
`verification/numerical_and_propagation.txt`. Audit source, interpreter and all
three input hashes are also inside `decimal_audit.json`.

Full execution, in a new directory and through the main queue:

```powershell
julia --startup-file=no --project=. scripts/run_v4_revised_chain.jl <new-run-dir>
```

Independent arithmetic/box diagnostic only:

```powershell
python scripts/verification_decimal_audit_v4.py runs/revised_chain_20260912_r2 <new-audit-output.json>
```

The audit script contains the exact binary64-to-Decimal conversion, raw scalar
contractions, analytic derivative comparison and box-face enumeration. This is
reproducible diagnostic evidence, not an amendment of the failed original gate
or a replacement accepted physical solution.

## r3 sealed re-execution

`runs/revised_chain_20260912_r3/runner.exit` contains `0`. Verification still
returns `fail`, exit `1`; the 24/24 focused checks retain their explicit exit
`0` in `runs/revised_chain_20260912_audit/final_regressions/verification.exit`.
The archived r2 source preserves the original wording; current r3 execution
uses source SHA256
`17e2de46e47d9575367045c328d14c9d63d1e8ba2c929fd992da6d6dd04bd9fd`.

The recursive comparison of the complete verification JSONs found 18 changed
scalar values: one interpretation string and 17 artifact/source/input-derived
path/hash values. No numerical value, boolean, status or threshold changed.
This is a wording correction with fresh same-candidate downstream bindings,
not a new physical success or a replacement of the failed original experiment.

| r3 artifact | SHA256 |
| --- | --- |
| `runs/revised_chain_20260912_r3/verification.json` | `80407fa785dba75438dbfd932fedb960a3d678cbee97334519c76ea7aa08faf8` |
| `runs/revised_chain_20260912_r3/result.json` | `d4bfc004f17d8942c5ca2e91db6cfd4a28137b558c0e6c3babaedec144353b88` |
| `runs/revised_chain_20260912_r3/verification/numerical_and_propagation.jls` | `e3b08f8edf8a382dc1c0ed64a3b7c033dcd20d22140a04a89a34a5f7d3c21999` |
