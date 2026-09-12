# FusionConceptAI Runtime V4 current progress index

Last updated: 2026-09-12
Current cycle starting HEAD: `main@793109c72f983f1fde92cfb71dc5f7100dcddfd5`
Current accepted and pushed implementation: `main@48bf4e5eaf0952dbc2e8c14b0abc2aaf78a6778f`.
Previous pushed acceptance includes `bf0b330` and `793109c`; the former index's `2ae6cc5` pointer was stale.

## Current same-candidate execution

The active run is `runs/candidate_chain_20260912_integrated`, using the existing
`dgpi-candidate` and candidate hash
`0619e5bbd0537caad9bec630db6667b2e37c1346fb24ce86e4f10db39af16f10`.
All downstream modules consume the same actual DESC outputs and validated
G1/G2/G3 context. The runner finished with OS exit **0**, and all six integrated
test groups passed **108/108**. Core **26/26** and spine **54/54** passed with
exit **0**. Package regression passed **2631/2631** across **105** reported groups,
with OS exit **0**. This accepts the executed subcomponents and accurate gap
accounting; it does not complete the missing physical/engineering/validation stages.

| Stage | Newly executed in this cycle | Actual result / remaining break |
|---|---|---|
| Candidate binding | Exact three-Genome, typed graph, subject and scenario binding | `observed`; the manufactured ECF fixture has a different identity and is excluded |
| Multi-region physics | DESC sampling, periodic weak-volume/strong-force moments, sampled constitutive Jacobian | `deferred`; 2 diagnostic regions, 4 test functions, 24x1000 sampled Jacobian; FD discrepancy `2.7106651733016967e-9`. G2-owned region/interface model, complete source/boundary residual, full-state Jacobian, global conservation and actual coupled solve remain unexecuted |
| Engineering/control/fault | G3 declaration audit and real plasma-interface momentum-load projection | `unsupported`; maximum sampled traction `1784905.64110172 Pa`. Current G3 has no realization/control operators or payloads; material, structural, thermal, power, control, protection and fault dynamics remain unexecuted |
| Numerical verification | Independent midpoint rule, correct field-period vector rotation, local-force norm integration, analytic benchmark, deterministic discrepancy propagation | `fail`; Gauss3/Gauss4/midpoint local-force spread is `0.1188426977380375` against `1e-3`. Independent Python postprocessing agrees within `2.33e-10 N` on the total local-force magnitude |
| Validation/UQ | Candidate-applicability and uncertainty prerequisite audit | `unsupported`; no held-out physical validation, parameter distributions/covariance propagation, or model discrepancy propagation executed |
| Whole device | Same-candidate stage replay and dependency assessment | `deferred`; 18 explicit recoverable gaps, no integrated whole-device physics, no terminal classification, `p5_ready=false`, credible devices `0` |

The local-force magnitude integral is about `1.22e6 N`, even though the correctly
rotated full-torus vector sum is near zero through symmetry cancellation.
Historical q2/q3/q4 Cartesian totals multiplied one field period by NFP and are
**sector-replicated Cartesian proxies**, not full-torus vector forces. Historical
tolerance verdicts below are retained as software records, not physical
convergence evidence. No q5/q6 milestone is introduced.

See [end-to-end report](candidate_end_to_end_v4_20260912.md),
[typed contract and runner](../implementation/candidate_end_to_end_v4.md),
[physics report](candidate_coupled_physics_weak_volume_v1_report.md),
[engineering report](candidate_engineering_execution_v4_20260912.md), and
[verification report](candidate_validation_propagation_v4_20260912.md).

## Historical accepted implementation inventory

This table preserves prior software acceptance. Its older fixtures and counts
are not the current candidate's engineering, validation, or whole-device evidence.

| Chain node | Tracked implementation | Current-cycle acceptance | Evidence boundary / next blocking edge |
|---|---|---|---|
| three Genome + typed AST/operator hypergraph | present | inherited regression required | structural contract only |
| candidate compilation/materialization/capability routing | present | inherited regression required | unresolved declarations remain explicit |
| sealed forward-chain context | committed at `fba248b` | focused 72/72, core 26/26, spine 54/54, and example passed, exit 0 | binds three Genome roles, typed graphs, obligations, mission/bounds, subject, and scenarios; emits no evidence or terminal authority |
| typed time, event, refinement, DAE and field-time bridge | committed through `f838fd8` | typed DAE composition 23/23 passed, exit 0 | bounded manufactured/runtime screens |
| native candidate-bound field residual D4.1 | committed at `c19ca1d` | 54/54 composition and fail-closed checks passed, exit 0; native kernel 43/43 passed, exit 0 | `screen_only`; no independent code/validation |
| Gridap B1 independent field kernel | committed at `31260e2` | independently accepted for B1 only; focused 75/75 and runner/replay passed, exit 0 | one 3-D manufactured control; B2/B3 not implied |
| Gridap B2 convergence | committed at `85f72f8` | 17/17 and pinned runner passed, exit 0 | isolated `screen_only` qualification; not physical V&V |
| Gridap B3 evidence/replay | committed at `c90e0ad` | 18/18 and pinned runner passed, exit 0 | isolated `screen_only`; same-process replay is not independent code |
| native/Gridap Batch C comparison | committed at `f5fa6a2` | focused 62/62 and pinned runner passed, exit 0 | explicit coordinate-bijective transfer; manufactured control only, not physical validation |
| typed multi-region ownership and conservative execution | committed at `8359886` | focused 117/117, example, core 26/26, and spine 54/54 passed, exit 0 | lumped manufactured control; discrete paired-term cancellation only |
| candidate-bound FreeGS axisymmetric execution | committed at `3f1e968` | focused 42/42 and real pinned FreeGS 0.8.2 runner passed, Julia/backend exit 0; output byte hash matched | one manufactured typed G2 fixture and `physical_model_screen` only; not validation, engineering evidence, or a 3-D multi-region provider |
| trusted repository provider registry and operational receipts | committed through `b4e8b10` | base focused 65/65, trusted FreeGS focused 43/43, real pinned FreeGS dispatch, core 26/26, and spine 54/54 passed, exit 0 | opt-in fixed FreeGS descriptor binds source/runtime/context/input/output identities; receipt remains `physical_model_screen`, not scientific evidence |
| typed 3-D physical-provider input chain | committed through `ebc80af`; discretization `1337230`, full-state residual/Jacobian `6e2e7d5`, exact-cover multi-region laws `d527866` | final composition 157/157, runner, example, core 26/26, and spine 54/54 passed, exit 0 | all five typed declarations plus the physical-to-region support map and keyed exact covers compose as `input_complete`; structural manufactured input only, with no provider selection, solve, or evidence |
| candidate-bound DESC fixed-boundary request compiler | committed at `5363cd9` | focused runner 223/223, standalone example, core 26/26, spine 54/54, trusted registry 65/65, and the existing pinned FreeGS regression passed, exit 0; fixtures report exact closed gaps | accepted gap-only compiler: the current composition fixture lacks the three DESC declaration/binding inputs, while the fully declared manufactured fixture lacks only `required_verified_desc_geometric_compatibility_proof`; `can_emit_request=false`, with no provider selection/execution, solver attempt, evidence, or authority |
| candidate-bound DESC geometry-program preflight | committed at `86dc03f` | focused 118/118, standalone runner, core 26/26, spine 54/54, trusted registry 65/65, trusted FreeGS 43/43, and pinned FreeGS 0.8.2 execution passed, exit 0; independent hard review found no remaining P1/P2 defect | accepted gap-only prerequisite: exact G2 chart-root/graph-root ABI and program-shape audit exposes eleven current gaps, including the absent normalized-to-SI root bridge and absent geometry interpreter; `program_ready=false`, no proof/certificate/request/provider/solver/evidence authority |
| normalized-to-SI 3-D coordinate/metric root bridge | committed at `56c7af8` | focused and standalone runner 90/90, core 26/26, spine 54/54, trusted registry 65/65, trusted FreeGS 43/43, pinned FreeGS execution 42/42, and DESC preflight 118/118 passed, exit 0 | candidate-owned `AtomicMIMO` roots bind `x_SI=L*x_normalized` and `g_SI=L^2*g_normalized`; `bridge_ready` is structural `screen_only`, not program interpretation, geometry proof, request, provider execution, or evidence |
| candidate-bound DESC Fourier geometry interpreter | committed at `46e5d26` | focused 81/81, standalone runner, bridge 90/90, DESC preflight 118/118, core 26/26, spine 54/54, trusted registry 65/65, trusted FreeGS 43/43, and pinned FreeGS execution 42/42 passed, exit 0 | explicit per-mode radial laws drive analytic normalized/SI coordinate, Jacobian, and metric programs through exact multi-root `AtomicMIMO` bindings; sealed result is `interpreted`/`screen_only`, not continuous-domain geometry proof, request, provider execution, or evidence |
| candidate-bound DESC continuous-domain geometry compatibility proof | committed at `cb6d6d5` | focused 89/89, standalone runner, interpreter 81/81, preflight 118/118, request compiler 223/223, bridge 90/90, forward context 72/72, core 26/26, spine 54/54, trusted registry 65/65, and FreeGS execution 42/42 passed, exit 0; independent review found no P1/P2 blocker | analytic 256-bit directed bounds prove the declared narrow Fourier program only; `screen_only`, no request/provider/solver execution, no physical or engineering validation, and zero credible devices |
| candidate-bound real DESC request/provider execution | committed at `b95d974` | focused 70/70, standalone runner, and full `test/runtests.jl` passed with explicit exit 0; actual DESC 0.17.3 provider and fresh-process HDF5 inspector both exited 0; final independent review found no P1/P2 blocker | typed request is rebuilt from the current candidate and compatibility proof before execution; receipt seals request/output, adapter, inspector, Python, and DESC identities and rejects replay tampering; structural result validation only, `screen_only`, with no solver-convergence, physical/engineering validation, evidence, pass, promotion, P5, terminal, or credible-device authority |
| candidate-bound real DESC field provider | committed at `4f4d8a5`, receipt hardened through `8ad464b` | final hardening focused 65/65, standalone runner, upstream execution 70/70, geometry interpreter 81/81, compatibility proof 89/89, 3-D input composition 157/157, and full `test/runtests.jl` passed in separate exit-0 processes; final review found no remaining P1/P2 issue | fresh DESC 0.17.3 process reopens the bound HDF5 and samples B, \|B\|, pressure, iota, sqrt(g), and force-balance residual at typed points; exact native quantity/unit metadata, artifacts, process identities, and output replay are sealed; receipt validation now independently recomputes the process hash and the adapter proves its loaded DESC module matches the sealed path; `screen_only`, with no solver-convergence, multi-region closure, validation/evidence, terminal authority, or credible-device credit |
| candidate-bound DESC field-basis bridge | committed at `4dfb246` | focused 95/95, standalone runner, field provider 62/62, request/provider execution 70/70, compatibility proof 89/89, and full `test/runtests.jl` passed in separate exit-0 processes; final independent reviews found no remaining P1/P2 issue | verifies DESC `B`/`F` as orthonormal cylindrical physical components, binds and cross-checks every upstream sample, and maps positions and vectors to Cartesian under the exact current candidate/proof/receipt identities; `screen_only`, with no region partition, interface trace, multi-region solve, convergence, validation/evidence, terminal authority, or credible-device credit |
| candidate-bound DESC rho partition/trace specification | committed at `bd8e920` | focused 64/64 and standalone real-DESC runner passed with explicit exit 0; field-basis 95/95, 3-D input composition 157/157, conservative multi-region manufactured control 117/117, and full `test/runtests.jl` passed in separate exit-0 processes; final independent reviews found no remaining P1/P2 blocker | exact normalized-rho region-interior adjacency/closure covers the positive domain with rho=0 excluded from sampling; paired trace maps reconstruct exact bound basis samples and opposite declared unit normals. `spatial_partition_geometry_validated=false`, `normal_geometry_validated=false`, and `interface_trace_executed=false`; no provider, convergence, validation/evidence, terminal authority, or credible-device credit |
| candidate-bound real DESC rho-surface/two-sided-trace provider | committed at `1db44fc` | focused 56/56 and standalone real-DESC runner passed with explicit exit 0; structural rho partition 64/64, field-basis bridge 95/95, field provider 62/62, and full `test/runtests.jl` passed in separate exit-0 processes; three final independent reviews found no remaining P1/P2 blocker | a pinned fresh DESC 0.17.3 process samples every declared interface at `c` and `c±epsilon`, validates returned rho/theta/zeta, surface/side `grad(rho)`/`n_rho`/tangent geometry, maps R-phi-Z physical components to Cartesian, and binds strict adjacent-region ownership plus all input/output/runtime artifacts. This is sampled `screen_only` execution: declared normals are not cross-checked, global spatial-partition geometry and interface flux remain unvalidated/unexecuted, with no convergence, closure, validation/evidence, terminal authority, or credible-device credit |
| candidate-bound local ideal-MHD interface traction and paired flux | committed at `22d9a38`; pressure-provider receipts hardened at `5d87bbb` and `8ad464b` | focused 62/62 and standalone real-chain runner passed with explicit exit 0; rho-surface 56/56, field-basis 95/95, hardened field provider 65/65, and full `test/runtests.jl` passed in separate exit-0 processes; three final independent reviews found no P1/P2 blocker | resamples real DESC pressure/B at the exact `c±epsilon` points, cross-checks Cartesian B, binds SI/CODATA mu0 and every interface/support/state/source/runtime identity, evaluates one-sided conservative ideal-MHD momentum traction, and assembles a central flux as equal-and-opposite contributions. `interface_flux_executed=true` and central cancellation are local algebraic facts only; finite-offset states are not boundary limits, and jump conditions, regional residual/Jacobian, global conservation, convergence, closure, validation/evidence, terminal authority, and credible-device credit remain false/zero |
| candidate-bound ideal-MHD interface residual/Jacobian subset | committed at `384091f` | focused 12/12, standalone runner, upstream traction 62/62, and full `test/runtests.jl` passed with explicit exit 0; final independent review accepted with no P1/P2 blocker | binds the exact ordered traction subset and computes the local 3-component traction-sum plus normal-B residual and analytic 4x8 Jacobian, independently checked by central differences. This is an interface subset only: full jump conditions, regional/global residuals, convergence, closure, validation/evidence, and device authority remain false/zero |
| candidate-bound DESC static-MHD force-balance sampling | committed at `7eb8f80` | focused 17/17, standalone runner, upstream traction 62/62, and full `test/runtests.jl` passed with explicit exit 0; final independent review accepted with no P1/P2 blocker | a sealed DESC 0.17.3 process samples `B`, `J`, `grad(p)`, and `F` at both exact finite-offset points; sealed replay and independent pressure-trace comparison give maximum formula discrepancy `2.92e-11 N m^-3`, while the measured force-balance norms are about `1.06e5 N m^-3`. This is a non-closure measurement under `screen_only`, not regional PDE assembly or equilibrium validation |
| candidate-bound regional integrated-force observation | committed at `c405398` | focused 122/122, standalone real-chain runner, both nested providers, and upstream traction regression 62/62 passed with explicit exit 0; independent review accepted with no P1 blocker | 2x2x2 owned tensor nodes per rho region execute through sealed DESC field/basis providers; The historical implementation multiplies a one-period Cartesian vector by NFP; this is a sector-replicated proxy, not a full-torus vector integral (corrected in the current cycle). The observed total-force norm is `342182.59975165897 N`, retained as non-closure. This is not a test-function weak form, regional residual/Jacobian, conservation proof, or solve |
| candidate-bound regional force q=2/q=3 comparison | committed at `4421477` | focused 18/18 including a distinct-path real-provider replay, standalone real-chain runner, upstream regional observation 122/122, and package-wide regression passed with explicit exit 0; independent hard review exposed and closed shared-run-path and tuple-comparison defects | Historical q=2 and q=3 sector-replicated Cartesian proxies differ by `493861.3259229757 N` (`1.4432683785832432` relative), so numerical convergence remains false. The run is a sealed `screen_only` non-closure observation, not V&V/UQ evidence or a solve |
| candidate-bound regional-force numerical convergence assessment | committed at `2ae6cc5` | final focused 23/23, standalone real-chain runner, and package-wide regression passed with explicit exit 0 | independently recomputes historical sector-proxy q2/q3 norm differences and the absolute-OR-relative tolerance verdict; the default result is `fail` and requests q4. Even a declared-tolerance pass grants no independent-code, physical-validation, UQ, promotion, terminal, or credible-device authority |
| candidate-bound regional-force q2/q3/q4 convergence ladder | committed at `bf0b330` | focused 33/33 with an independent q4 replay, standalone real-chain runner, and package-wide regression passed with explicit exit 0 | 64 fresh DESC field/basis samples per region produce a historical sector-proxy q3-to-q4 relative difference `0.7209778257208969`; it decreases from q2-to-q3 `1.4432683785832432` but fails the declared tolerance. Numerical convergence, independent-code validation, physical validation, UQ, promotion, terminal authority, and credible-device credit remain false/zero |
| candidate-bound static-MHD interface jump ledger | committed at `50d4a00` | focused 32/32 and standalone real-chain runner passed with explicit exit 0 after the package-wide suite; independent review accepted with no P1/P2 blocker | binds every exact interface, adjacent region/support, finite-offset traction sample, four-component residual and epsilon identity. Static traction-vector and normal-B continuity are declared; dynamic mass/electric/energy conditions are explicitly out of scope. All values remain finite-offset proxies, so boundary limits, validated jump conditions, regional/global residual assembly, convergence, closure, validation evidence and device authority remain false/zero |
| real multi-region coupled physics | local constitutive/interface residual/Jacobian, sampled point force balance, regional volume-force observations with a nonconverged q=2/q=3 comparison, and a static jump ledger only | not yet admissible as a solve | the accepted slices still lack independently established boundary-limit traces, typed regional test-function/source/boundary residual and Jacobian ownership, global conservation accounting, and a converged multi-region solve |
| current-G3 engineering/control/fault compilation and trusted manufactured execution | committed through `ac00ab6`; graph compilation `a297846` | graph compiler 157/157; trusted provider 127/127, example, runner, core 26/26, spine 54/54, and registry regressions passed, exit 0 | three graph edges of the separate `ecfgo-manufactured-candidate` fixture execute as one deterministic 11-event manufactured trace through a fixed repository trust root; `operational_screen`/`screen_only`, not engineering or physical evidence |
| physical validation and UQ request boundary | committed at `7561f93` | focused 63/63, real trusted FreeGS example, core 26/26, and spine 54/54 passed, exit 0 | exact trusted execution yields seven typed recoverable evidence gaps and zero credit; no numerical V&V, held-out physical validation, independent code, or UQ evidence exists |
| dedicated G3 ECF to Validation/UQ and whole-device integration boundary | committed at `8983daa` | focused 42/42 and standalone runner passed with explicit exit 0; independent final review accepted with no P1 blocker | exact ECF provider/request/result identity and dedicated registry/request/receipt chain are revalidated; the dedicated receipt is explicitly not coerced into a generic VVUQ receipt, the exact five-stage assembly stays `screen_only_deferred`, evidence credit is zero, and five unresolved real-provider/validation/UQ/closure gaps remain visible |
| current-G3 ECF fresh-process numerical repeatability | committed at `1c84038` | focused 15/15, standalone two-process runner, trusted provider 127/127, ECF/VVUQ non-bridge 42/42, and package-wide regression passed with explicit exit 0 | two distinct fresh Julia processes reproduce the exact manufactured operational trace/result/count observables under sealed source, Project/Manifest, executable, context, request, receipt and non-bridge identities. This is `screen_only` software/numerical repeatability, not engineering qualification, physical validation, generic V&V/UQ, whole-device closure, or evidence credit |
| high-fidelity whole-device closure | explicit zero-credit integration boundary only | not admissible | real multi-region provider, generic VVUQ bridge, held-out physical validation, Validation/UQ artifacts, integrated high-fidelity closure, and terminal authority remain missing |
| scoped simplest feasible-device search | search infrastructure exists | not admissible at physical-device level | zero L4 credible candidates; closure path incomplete |

## Active chain-unblocking queue

1. Declare Genome-owned regions/supports/adjacency and constitutive/interface
   ASTs, full state DOFs, weak test spaces, body/source terms and exterior/interface
   boundary laws. Obtain boundary quadrature and boundary-limit traces; then
   execute complete residual/Jacobian, global conservation and the coupled solve.
2. Supply G3 component load mapping, material/structural/magnet/power and
   thermal-hydraulic models, sensor/plant/actuator/control dynamics, protection
   and declared fault cases. Connect each to actual applicable physical outputs.
3. Diagnose local residual integration with an error-controlled independent
   formulation and complete weak residual. Observed spread is not a certified
   error estimate; net-force cancellation cannot substitute for equilibrium.
4. Obtain candidate-applicable held-out measurements with uncertainty,
   independent physical implementation, parameter covariance/distributions and
   model discrepancy. Execute validation and uncertainty propagation only when
   those inputs and applicability checks exist.
5. Reassess the whole-device stage after actual upstream execution and admissible
   evidence close those dependencies. Keep fail/unsupported/deferred candidates
   recoverable; do not route by legacy authority or family labels.

Adding missing G1/G2/G3 declarations changes candidate identity and requires
fresh upstream runs. A missing provider for already-owned declarations can
preserve identity. Old receipts must never be grafted onto a revised Genome.
Julia, three Genome layers and typed AST/operator hypergraphs remain the core.

## Protected working state and reproducibility

The initial tracked test change in
`test/runtime_v4_validation_uq_execution_request_tests.jl` and unrelated untracked
prototypes/reports remain protected and excluded from this milestone. The
independent-cubature files were explicitly reviewed, backed up, repaired and
integrated; no other old prototype is accepted by directory-level staging.
Initial status/HEAD/diff/hash are under `runs/candidate_chain_20260912`.
Generated provider data and logs remain local; the runner records exact source,
Project/Manifest, executable and artifact hashes for reproducibility.

## Current authority statement

`p5_ready=false`; credible physical device candidates: **0**. The current ledger
executes a whole-device **assessment**, not whole-device physics. The analytic
integration benchmark and independent Python postprocessing verify software
calculations, not an independent physical solver or physical validation.
Deterministic observed formulation spread is not a confidence interval or
certified error bound. Passing execution/tests grants no engineering feasibility,
physical validation, terminal classification or simplest-feasible-device claim.
