# Candidate validation propagation execution report — 2026-09-12

This report distinguishes code verification from candidate execution and
physical evidence. Candidate integration measurements are accepted only from
the shared end-to-end runner, not by rerunning each example chain.

## Completed checks

`julia --project=. --compile=min -O0 test/runtime_v4_candidate_validation_propagation_tests.jl`
returned exit **0**, with **31/31** assertions. The checks cover an analytic
periodic-vector integral, a radial-polynomial error ratio, NFP=1/2/3/5/8,
non-finite/invalid inputs, phi distinct from zeta, foreign sample identity, and
the case where regional discrepancies cancel in the original ensemble but must
remain in the propagated component box.

Measured analytic-code benchmark: vector absolute error
`3.58724037616909e-15`, while scalar replication of that same vector has error
`5.197801579154086`. The radial midpoint errors are
`0.005208333333333315` and `0.0013020833333333148`, ratio
`4.000000000000043`. These dimensionless analytic fixture numbers are code
verification only; they are not candidate physical measurements.

The pre-existing independent-cubature focused process was observed to completion
without starting a duplicate. `independent_cubature_focused.exit` records **1**;
the error was `UndefVarError: DESCFieldSamplePointV4 not defined` in the isolated
`Main.RFIC` module. That is an execution failure, not a numerical verdict. The
module-owner repair and stronger binding validation were subsequently verified
by the shared runner; the original files are preserved in the audit directory
documented in the implementation note.

## Independent raw-output postprocessing oracle

The same main-run provider files in
`runs/candidate_chain_20260912_integrated/providers/{comparison,q4,independent_cubature}`
were read once by a Python postprocessor, which returned **exit 0**. It launched
neither Julia nor a provider. The compact output and all nine consumed-file
SHA-256 hashes are retained locally in
`runs/candidate_chain_20260912_integrated/python_periodic_force_oracle.txt`.

| Formulation | Samples | Integral of local force magnitude (N) | Volume (m3) |
| --- | ---: | ---: | ---: |
| Gauss3 | 54 | 1,363,760.2964458438 | 17.506210806432243 |
| Gauss4 | 128 | 1,201,687.3437481937 | 17.506210806432243 |
| Independent midpoint | 250 | 1,220,303.4839269505 | 17.505937595709234 |

The observed local-force-integral relative spread is
**0.11884269773803767 (11.8842697738%)**, exceeding the sealed `1e-3` tolerance.
The full-period vector integrals from this postprocessor are approximately:

- Gauss3: `(-7.766898e-12, -1.704803e-12, 6.461271e-9) N`.
- Gauss4: `(-7.275514e-12, -5.559386e-12, 1.439782e-8) N`.
- Midpoint: `(-3.840317e-12, -6.423771e-12, 6.479138e-9) N`.

In contrast, their sector-replicated Cartesian `(x,y)` proxies are
`(122710.6672, 89154.5183)`, `(34238.9972, 24876.0876)`, and
`(45699.6392, 33202.7314) N`. The very small reconstructed net vectors arise
from field-period symmetry and do not remove the large local residual or its
quadrature disagreement.

The independent implementation uses NumPy `leggauss` for radial Gauss weights,
an explicit equal-cell midpoint rule, and Python `math.fsum` for reduction. It
reconstructs weights from the declared rules and verifies every point against
both the field and basis request TSV. Region bounds `[0,0.75]` and `[0.75,1]`
come from the current partition example. Schema, basis, units, NFP=5, counts,
continuous indices, uniqueness, finite values and positive metric determinants
were checked. The current samples have `phi-zeta=0`; the reduction still uses
actual phi. This is a postprocessing oracle using the same DESC data and
periodicity assumption, not independent-physics-code or physical validation.

The Julia stage subsequently emitted `CHAIN_NUMERICAL_DIAGNOSTIC_EXIT_CODE=0`
and produced `validation.json` plus its text receipt for candidate
`0619e5bbd0537caad9bec630db6667b2e37c1346fb24ce86e4f10db39af16f10`.
Its executed numerical verdict is **fail**, with relative spread
`0.1188426977380375`. The independently repeated raw-output comparison returned
**exit 0**, checked all nine original input hashes unchanged, and measured:

| Formulation | Julia minus Python integral (N) | Volume difference (m3) | Largest net-vector component difference (N) |
| --- | ---: | ---: | ---: |
| Gauss3 | 0 | -3.552713678800501e-15 | 7.73748551786726e-12 |
| Gauss4 | 2.3283064365386963e-10 | 0 | 1.1943446232010047e-11 |
| Midpoint | -2.3283064365386963e-10 | -3.552713678800501e-15 | 6.434407132820302e-12 |

The largest sector-proxy component difference is `5.820766091346741e-11 N`;
the largest per-region local-integral difference is `3.4924596548080444e-10 N`.
Relative spread differs by `-1.6653345369377348e-16`. These roundoff-sized
differences confirm implementation agreement on the same inputs; they do not
establish convergence or independently validate DESC physics. The local
comparison receipt is `python_julia_validation_comparison.json`; the consumed
Julia validation JSON SHA-256 is
`0bdf910c38a0713efdcd335468515d24f424465ff2cd0b2e3dd06e172e294958`.

The executed deterministic propagation gives resultant-norm spread
`[5.9881131164729595e-9, 2.2783650404334673e-8] N`. This is an observed
formulation-spread interval, not a certified bound or a confidence interval.
Physical validation and parameter-UQ execution flags remain false.

The same live main run subsequently passed the real-chain validation receipt
checks **12/12** and the independent cylindrical-versus-Cartesian periodic
physics agreement checks **10/10**. The measured largest regional force-vector
difference between the two Julia implementations was
`1.0196054494538394e-11 N`; these implementations share DESC field data, so this
is an implementation-agreement check with zero independent-physics-validation
credit. The main accounting checks also passed **24/24**.

## Final shared-run acceptance

The repaired independent-cubature checks passed **25/25** within that same
already executed provider chain. No separate duplicate provider focused run
was started. The complete main-run integration suite passed **108/108**:
physics 15, engineering 22, validation receipt 12, periodic cross-check 10,
execution accounting 24, and independent cubature 25. Both
`runs/candidate_chain_20260912/integrated.exit` and the main run's `runner.exit`
contain **0**; `execution_manifest.json` and the final exit marker were
generated. These explicit completion records supersede the earlier pending
checkpoints. The original independent focused **exit 1** remains retained as
the pre-repair failure history.

The accepted outcome is executable, reproducible **numerical fail** and
**physical validation/UQ unsupported**, with whole-device outcome **deferred**
and credible-device count **0**. Agreement tests do not close the missing
physical, engineering, validation or uncertainty capabilities. Separate
RuntimeV4 spine and package checks were still running when this component
report was finalized; their status is recorded by the main acceptance report.

## Candidate evidence boundary

The new executable stage reconstructs full-period vector integrals from the
actual sampled cylindrical force and phi. It separately reports the old
sector-replicated Cartesian proxy, scalar local residual magnitude integral,
and observed formulation-spread propagation. Numerical disagreement can fail;
absence of asymptotic convergence remains deferred. Symmetry cancellation of
net force does not establish equilibrium or conservation of the full weak
system.

Physical validation, independent-physics-code validation, parameter-UQ provider
runs and model-form uncertainty are not executed. They remain recoverable
`unsupported` gaps. No experimental data, input distributions, certified error
bound, device acceptance or feasibility credit is created by this work.

See `docs/implementation/candidate_validation_propagation_v4.md` for the
extract/test-only/reject audit of the legacy numerical and VVUQ code.
