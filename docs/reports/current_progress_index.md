# FusionConceptAI Runtime V4 current progress index

Last updated: 2026-09-12
User-requested closeout: reduced milestone `51b5540` is pushed; spatial source is
local staging, not accepted, and all three subagents are stopped. The candidate
preflight was interrupted before completion; no spatial DESC/solve was started.
See [spatial handoff](spatial_execution_handoff_20260912.md) and
[next goal prompt](spatial_execution_next_goal_prompt_20260912.md).

Current cycle starting HEAD: `main@4d5afdbb1cb67ab8c4cf2167d91c929a2786d3eb`.
Previous accepted implementation: `48bf4e5`; completed report/index: `4d5afdb`.
The commit containing this index records the current reviewed milestone and its evidence.

## Current revised-candidate execution

Current candidate: `7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548`.
Context: `de87eb7f96b38dda09e4643fcbce20db17d21b3f2207a416f755768b096fd14d`.
G1/G2/G3 were revised together, preserving parent geometry while recording the
parent package hash, semantic changes and exploratory parameter provenance.
Geometry/proof/DESC were rebuilt for this identity; no parent receipts were reused.

The first real run is `runs/revised_chain_20260912_r2`: runner **0**, integration
**27/27**, independent byte audit **424 records, zero mismatches**. The final
hardening run is `runs/revised_chain_20260912_r3`, explicitly reusing the same
revision's validated upstream/physics and recomputing affected downstream.
Final r3 is complete: runner **0**, integration **28/28**, independent byte audit
**436 records, zero mismatches**. Final focused groups pass **30/44/24/15** tests,
core **26/26**, spine **54/54**, package **2631/2631** in 105 groups; every process
and the queue exited **0**. See the report and its machine-readable evidence.
This is acceptance of a reduced-model partial milestone; the original spatial
multiregion goal remains active and incomplete.
The prior `candidate_chain_20260912_integrated` remains historical partial execution.

| Stage | Newly executed | Actual outcome and boundary |
|---|---|---|
| Candidate | G1 physical laws, G2 owned regions/interfaces/DOFs/tests, G3 pickup/readout/control/fault/scenarios | observed; exact typed graph admission, unchanged default registry, sourced exploratory parameters |
| Multi-region physics | 17,920 real samples, exact rho surfaces, every body/source/exterior/interface term, 36 residual rows and all 4 Jacobian columns; conservation ledger and 5 accepted state updates | **fail, exit 3**; raw norm **87,985.5 to 18,489,788.2 N**, scaled **1.77224 to 1.02080**; clipped-GN non-KKT stop. Complete declared reduced system, not full-function-space MHD |
| Engineering/control/fault | Actual final boundary B **0.856484 T** into Faraday/RL pickup, readout, short and dump relay | computation **exit 0**, stage **fail**; nominal **3.30653 mA**, fault **20.28056 mA**, trip **1.54 ms**; upstream invalid, applicability unsupported; fault numerical dissipation **20.9%** |
| Numerical verification | Independent stress residual, all-column FD, strong/weak identity, SVD, analytic RL/dt and 70-digit arithmetic/box diagnostic | **fail, exit 1**; roundoff cancellation triggers frozen residual gate. Aggregate Jacobian passes but pressure-column FD exceeds 1e-7; high-precision analytic columns agree around 8e-15 |
| Sensitivity/UQ | 8 engineering design corners and 2 fixed-geometry pressure cases with physics-to-engineering recomputation | conditional execution; **2.23840 to 4.97764 mA** corner range, no distribution/CI/certified bound; physical validation unsupported and unexecuted |
| Whole device | Same-revision dependency and stage assessment | deferred; full spatial MHD, external field/component/environment physics and validation incomplete; P5=false, credible devices **0** |

Small net force and paired-interface cancellation cannot certify local equilibrium
or conservation. Historical q2/q3/q4 Cartesian totals are sector-replicated proxies;
no q5/q6 milestone is introduced. Prior formulation spread is not a certified
quadrature error. The present report separates arithmetic, integration,
discretization, constraint, solver and physical-model limitations.

See [milestone report](revised_coupled_execution_v4_20260912.md),
[contract](../implementation/revised_execution_contract_v4.md),
[physics](complete_multiregion_v4_report_20260912.md),
[engineering](magnetic_engineering_v4_20260912.md),
[verification](executed_verification_uq_v4_20260912.md), and
[previous partial execution](candidate_end_to_end_v4_20260912.md).

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

1. Address the actual non-KKT clipped-GN stop with an appropriate constrained
   method and review row scaling; retain raw/scaled residuals and separate
   constraint cost from algorithmic excess. Changed states require downstream recomputation.
2. Extend the four-amplitude ansatz/test spaces and exterior-boundary model as
   needed. Semantic changes require a new revision and affected upstream execution.
   Current selected regions and G3 subsystem are no longer empty declarations.
3. Use high-precision evidence to address cancellation with a defensible error
   model; establish isolated integration and spatial errors with targeted
   independent calculations, not an arbitrary additional quadrature ladder.
4. Establish actual external sensor placement/aperture and applicable transient
   input; refine fault switching/energy dynamics. Obtain applicable component,
   environment and held-out validation data. Design intervals do not supply statistics.
5. Reassess whole-device readiness only after actual dependent physics and
   admissible evidence exist. Preserve recoverable fail/unsupported/deferred
   status, Julia, three Genome layers and typed AST/operator hypergraphs.

Adding semantic G1/G2/G3 declarations changes identity. A missing implementation
for already-owned declarations can preserve identity; old-candidate receipts
must never be attached to a changed candidate. No legacy authority/family routing.

## Protected working state and reproducibility

The initial modification in `test/runtime_v4_validation_uq_execution_request_tests.jl`
and unrelated untracked prototypes/reports are protected and excluded from this
milestone. Initial status, HEAD, diff and hash are under
`runs/revised_chain_20260912_audit`. Only the explicitly reviewed file list is staged.
Generated provider data/logs remain local. The final manifest records actual
command/arguments, resume origin, upstream/physics checkpoint identities,
external raw dependencies, source, Project/Manifest, executable and output hashes.

## Current authority statement

`p5_ready=false`; credible physical device candidates: **0**. This milestone
executes the complete declared reduced model and one real engineering equation
system, including a reproducible failed solve. It does not complete full-field
MHD or integrated device physics. Whole-device assessment is executed; physical
validation is unsupported. Analytic/Decimal comparisons verify software, not
physical applicability. Deterministic design corners are not distributions,
confidence intervals or certified global bounds. Green regression tests grant
no engineering feasibility, validation or terminal classification.
