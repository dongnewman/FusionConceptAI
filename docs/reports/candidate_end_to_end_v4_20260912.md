# Current Genome end-to-end execution report

## Starting state and process handoff

The cycle started at `main@793109c72f983f1fde92cfb71dc5f7100dcddfd5`.
`origin/main` was fetched and matched that HEAD (ahead/behind `0/0`).
The progress index still named `2ae6cc5` as its accepted implementation and was
stale relative to the q4 acceptance commits. The working tree contained 89
status entries, including the pre-existing modified
`test/runtime_v4_validation_uq_execution_request_tests.jl` and multiple
untracked prototypes, reports, and run artifacts.

The protected test's starting SHA-256 is
`df1a67c20c528fed9012067a45640a58c6dede3e45f042a26a9cae056e757ed2`.
It is excluded from this milestone. The initial status, HEAD, diff, and hash
were saved under `runs/candidate_chain_20260912/`.

The already-running independent-cubature focused process (Julia PID 116980,
PowerShell parent 45500) was observed without duplication. It exited **1**:
the isolated `Main.RFIC` module could not resolve `DESCFieldSamplePointV4`.
Its original log and exit file remain intact. The reviewed fix includes the
independent integration implementation in the existing DESC runtime owner,
while preserving independent node generation and integration algorithms.

An additional structural load check with `--compile=min -O0` was stopped due
to slow progress (exit **1**, aborted, no acceptance credit). The corresponding
header-only engineering rerun was also stopped and is recorded separately in
its report. Main acceptance uses normal Julia compilation and a single
isolated provider run; no original provider process was interrupted.

## Candidate and execution boundary

The actual DESC chain uses `dgpi-candidate`. The previous manufactured
engineering trace used `ecfgo-manufactured-candidate`, a different Genome
bundle; it is not used as this candidate's engineering result. The new ledger
binds current G1/G2/G3, typed graph, scenario, physical subject, and every
downstream result to the DESC candidate's validated context.

The rho partition is currently a downstream diagnostic declaration bound to
that context, not a region/interface model owned by its Genome AST. This is an
explicit recovery gap. Adding missing Genome declarations will create a new
candidate identity and require new upstream execution; old receipts cannot be
reused as evidence for the revised candidate.

The candidate's current G3 has no realization/control operators or parameter
payloads. Its real plasma-interface field outputs can support a sampled
momentum-load calculation. They cannot define component geometry, material
properties, control transfer functions, coolant flow, or fault scenarios.

Complete multi-region residual/solve, real engineering/control/fault dynamics,
held-out physical validation, parameter/model-form UQ, and integrated
whole-device physics remain unexecuted wherever their required declarations
or providers are missing. The whole-device step is an executed assessment,
with `deferred`, zero credible devices, and `p5_ready=false`.

## Interpretation correction

The old regional q2/q3/q4 and midpoint raw Cartesian summaries integrated one
field period and multiplied laboratory-frame components by NFP. Their values
are preserved as historical **sector-replicated Cartesian proxies**. They are
not full-torus vector forces. The new implementation independently rotates
each period, compares Cartesian and native-cylindrical formulations, and
retains the integral of local force magnitude. Near-zero net force caused by
periodic symmetry does not establish equilibrium or complete conservation.

The analytic benchmark checks the integration code only. Formulation spread
is propagated as a deterministic observed discrepancy envelope. It is not a
certified error bound, physical validation, or probability-based UQ.

## Acceptance artifacts

The integrated runner writes its provider data, full physics/engineering/
diagnostic JSON, six-stage result, dependency queue, source/artifact manifest,
and definitive exit file in one new run directory. Final measured values and
acceptance exits are recorded below. The integrated process has finished with
OS exit 0; this is execution acceptance, not a physical pass.

## Measured same-candidate results

Run directory: `runs/candidate_chain_20260912_integrated`.
Candidate hash:
`0619e5bbd0537caad9bec630db6667b2e37c1346fb24ce86e4f10db39af16f10`.
Context hash:
`88464c462e6009e930efef24ea1a1a20f16d8a3a449d0a9853c940f325a7afd5`.

The machine-readable result contains six stages and 18 recoverable gaps.
Its outcome is `deferred`, `whole_device_physics_executed=false`,
`p5_ready=false`, and `credible_device_count=0`.

| Artifact | SHA-256 of actual file bytes |
|---|---|
| `result.json` | `855dd8c7920f7819b1bb9841e17c99764b5dd7b864e7c7862107e2b3caf85af0` |
| `physics.json` | `1e9969ac0eece7910605b6529aa3c329db35dd18d3866459e95dc8dd43cdf56f` |
| `engineering.json` | `f05e8f20ed55a61bfa196aa192d71c48eccabe9ccd5ae0407ff2cc15bfbb5340` |
| `validation.json` | `0bdf910c38a0713efdcd335468515d24f424465ff2cd0b2e3dd06e172e294958` |

| Actual calculation | Measured result | Limit |
|---|---|---|
| Weak-volume and nonconstant strong-force moments | 2 diagnostic regions, 4 test functions; sampled Jacobian 24 rows x 1000 columns; maximum scaled FD discrepancy `2.7106651733016967e-9` | Constitutive sampled-state Jacobian only; no full weak residual or coupled solve |
| Regional local-force magnitude integrals | `499803.561246086 N`, `720499.9226808641 N` | Not a net-force or full conservation verdict |
| Sampled force-density peaks | `128198.82402881836 N/m^3`, `312311.72217592015 N/m^3` | Sampled pointwise model residuals |
| Plasma-interface load projection | 2 points; maximum traction `1784905.64110172 Pa`; independent constitutive discrepancy `2.3283064365386963e-10 Pa` | Not hardware surface loads, engineering qualification, control, or fault execution |
| Periodic integration code benchmark | absolute vector error `3.58724037616909e-15` | Analytic software verification only |
| Three-formulation local-force consistency | relative range `0.1188426977380375` against `1e-3`; **fail** | Does not prove mathematical divergence or physical infeasibility |
| Discrepancy propagation | resultant norm observed interval `[5.9881131164729595e-9, 2.2783650404334673e-8] N` | Observed floating-point formulation spread only, not a certified bound or confidence interval |

| Integration formulation | Samples | Integral of local force magnitude (N) | Volume (m^3) |
|---|---:|---:|---:|
| Gauss-3 / periodic angles | 54 | `1363760.2964458438` | `17.50621080643224` |
| Gauss-4 / periodic angles | 128 | `1201687.343748194` | `17.506210806432243` |
| Independent midpoint cells | 250 | `1220303.4839269503` | `17.50593759570923` |

An independent Python postprocessing oracle rebuilt the Gauss weights and
midpoint rule from the same raw files. All nine input hashes stayed unchanged.
Maximum Julia/Python discrepancy was `2.3283064365386963e-10 N` in total local
force magnitude, `3.552713678800501e-15 m^3` in volume, and about
`1.19434e-11 N` in a periodic net-force component. This validates postprocessing
agreement only; it is not an independent physical solver or held-out validation.

The near-zero periodic net force is dominated by symmetry cancellation and
roundoff while the local force magnitude remains about `1.22e6 N`. It is not
reported as equilibrium, boundary closure, or global conservation success.

## Integrated review and delivery scope

Independent physics, engineering and validation reviews found no remaining
P1/P2 issue in the generated six-stage ledger. Candidate/context/scenario/G3
hashes, SI dimensions, executed flags and all eight engineering gaps matched
the actual stage artifacts. The root report writer revalidates actual upstream
inputs before writing; re-sealing a fabricated metric cannot grant acceptance.

The exact delivery list contains 33 files. A static include-closure audit,
including the `FusionConceptAI` package entry point, covered 98 reachable Julia
files and 101 include edges. Every dependency is already tracked or in the
explicit delivery list: no missing file or dependency on an unrelated untracked
prototype was found. All legacy extract/wrap/test-only/reject decisions are
recorded in the stage implementation documents.

The regression queue waited for the main runner's final exit before starting
Runtime V4 core, spine and package tests in sequence. No provider chain was
restarted by the integrated checks.

## Definitive execution acceptance

Command actually executed:

```powershell
julia --startup-file=no --project=. scripts/run_v4_candidate_chain.jl runs/candidate_chain_20260912_integrated
```

Julia was `1.10.5`. The run started and finished at source baseline
`793109c72f983f1fde92cfb71dc5f7100dcddfd5`, with the new implementation captured
by source byte hashes. `integrated.exit`, the OS process result, and
`runner.exit` are all **0**. The six integrated test groups passed **108/108**:

| Real-input integrated check | Passed |
|---|---:|
| Regional weak-volume and sampled Jacobian | 15/15 |
| Engineering identity, inputs, scope and forged-result rejection | 22/22 |
| Validation diagnostic receipt replay | 12/12 |
| Independent periodic formulation versus weak-moment calculation | 10/10 |
| Same-candidate end-to-end ledger and authority rejection | 24/24 |
| Independent midpoint cubature and adversarial reconstruction | 25/25 |

Core regression passed **26/26**, exit **0**. Spine regression passed **54/54**,
exit **0**. Package-wide `test/runtests.jl` passed **2631/2631** across **105**
reported test groups, with OS exit **0**; the sequential regression queue also
exited **0**. The package log SHA-256 is
`68592741cff0ce1ff0178a7707970f56e3e35647501055a12466f04e99a9960b`.
Earlier focused kernels passed physics **26/26**, engineering **28/28**, and
validation **31/31**, each with explicit exit **0**; their limited scope and
aborted diagnostic retries are described in the stage reports.

The integrated semantic result hash is
`2e0042ce784b5bbc89594d1186ee59db011f6aecaa87fa212b64647fb0dfb1a3`.
The execution-manifest file SHA-256 is
`5db3b18b32b2cec18e839c6aa89e9d16b8e6aaf46e0a72fa6a6af6552affcdac`.
Independent byte rehashing matched all **427 records**: 370 source records,
55 artifacts, and Project/Manifest. Digest fields are serialized as
`{"value":"<sha256>"}` and must be compared using their `value` field.

After this acceptance run, the runner received one CLI initialization fix:
create the parent `runs` directory before choosing the default temporary run
directory. Direct execution of the actual initialization prefix against a
fresh temporary checkout and a nonempty protected directory passed **6/6**,
exit **0**. No numerical or provider source changed. The exact executed script
is preserved at `runs/candidate_chain_20260912/run_v4_candidate_chain.executed.jl`;
the earlier manifest still describes that original script, not this later
initialization-only correction.
The final diff check also removed one trailing blank line from the independent
cubature check file; its executed bytes are preserved alongside the script.
These two post-run source-file differences are limited to CLI initialization
and test whitespace; all numerical/provider code and artifacts remain unchanged.

Acceptance applies to the executed subcomponents and truthful dependency ledger.
The requested complete multi-region solve, real engineering/control/fault
dynamics, physical validation, parameter/model-form UQ and integrated physical
device remain unexecuted. The final result is **deferred**, with the numerical
diagnostic **fail**, 18 recoverable gaps and zero credible-device credit.
