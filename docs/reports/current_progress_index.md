# FusionConceptAI Runtime V4 current progress index

Last updated: 2026-09-13

The full spatial implementation is promoted and its first complete declared
execution is recorded in `runs/spatial_chain_20260912_r1`. This supersedes the
interrupted preflight handoff. The reduced milestone `51b5540` remains historical
and is not treated as spatial evidence.

Source implementation was pushed at
`c2352f2943a9c4477144d8b5c9e79a00c371b6a8`; resumable whole-stage closeout and
independent manifest audit were pushed at
`91dc908dbcbcf7761a8984cbba2b68d4435805a6`.

## Current spatial-candidate execution

Parent candidate: `7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548`.
Spatial candidate: `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`.
Context: `0f7521a157ca710b195f82757a8d204058d99231b12346f9c8f37d9be526b10d`.
G1/G2/G3 declarations, provenance and lineage are bound to the child identity;
fresh DESC request/result/receipt/HDF5 were produced and no parent receipt was
attached.

| Stage | Actual execution | Result and evidence boundary |
|---|---|---|
| Candidate/upstream | child identity, geometry/proof, fresh DESC 0.17.3 and sampler | process exits 0; upstream remains screen-only and supplies initialization/geometry, not equilibrium validation |
| Spatial physics | four cases; 360/2640 DOF; 2881/21761 rows; all volume/source/face/periodic/interface/exterior/flux terms; full sparse Jacobian and real updates | **scientific fail, exit 4** in all cases; scaled final norms 0.16146/0.13797/0.15635/0.16531, all iteration-limit stops |
| Engineering/control/fault | actual curl(B)/mu0 J and interface K into finite-aperture Biot-Savart, reciprocity, static and conditional RL/10 us protection | computation **exit 0**, stage **fail** from invalid physical upstream; static flux -1.2997e-5 to -1.8730e-5 Wb; static EMF 0; no trip |
| Numerical verification | independent residual blocks, every Jacobian column, two nonzero-source MMS levels, independent 256-bit circuit identities | numerical **pass, exit 0**, physical-validation credit 0; no solved convergence order |
| Deterministic propagation | actual 0.95/1.05 Wb endpoint solves through actual engineering | executed, but failed-state range only; no distribution, CI or certified bound |
| Physical validation | no applicable experiment/independent physical solver/discrepancy data | **unsupported and unexecuted** |
| Whole device | dependency-bound assessment after checkpoint recovery | **deferred, exit 0**; P5=false, credible devices 0 |

The first whole-stage integration call raised a world-age program exception and
the outer process exited 1. Upstream through verification checkpoints were not
overwritten. After the one-line runner repair, `--resume` reused them, passed
43/43 integration assertions and exited 0. The ledger preserves one program
exception and zero human interruptions. Independent audit passes 549 records /
548 unique paths with zero mismatches; package regression passes 2631/2631 in
105 groups.

See [spatial milestone report](spatial_coupled_execution_v4_20260913.md),
[machine-readable evidence](spatial_coupled_execution_v4_20260913_evidence.json),
[contract](../implementation/spatial_execution_contract_v4.md),
[physics](spatial_multiregion_v4_report_20260912.md),
[engineering](spatial_pickup_engineering_v4_20260912.md), and
[verification](spatial_verification_uq_v4_20260912.md).

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
| W23 bounded typed G1 generation slice | additive 0D screen-only search-mechanics loop; see `docs/implementation/runtime_v4_algebraic_generation_slice.md` | focused 30/30; scoped 59/59; archive 35/35; independent runner r4 and full package entrypoint exit 0 in separate runs, seed plus two distinct AST descendants, exact typed feedback and queue/archive reimport; package entrypoint does not include W23 opt-in test | Not fusion-physics discovery: no G2/G3 generation, spatial solver feedback, measurement, net electricity, originality or L4 candidate; R08 and R01–R10 remain unaccepted |

## Active chain-unblocking queue

1. Diagnose the four spatial iteration-limit stops using the persisted sparse-QR,
   line-search, block-residual and accepted-update histories. Any state-changing
   solver repair requires rerunning physics and all dependent engineering/UQ.
2. Supply defensible pressure/current-topology closure and exterior boundary/current
   closure. These are model changes, not numerical tuning; revise candidate identity
   and execute affected upstream when declarations change.
3. Establish isolated integration error and solved-state spatial convergence only
   after applicable converged states exist. Current MMS and strong/weak comparisons
   are software/integration diagnostics, not physical error estimates.
4. Add external coils, outer K/return path, complete hardware geometry, transient
   coupling and applicable component/environment data before engineering promotion.
5. Obtain experiments or an independent applicable physical solver plus discrepancy
   evidence. Only then can physical validation and whole-device readiness be reassessed.

Adding semantic G1/G2/G3 declarations changes identity. A missing implementation
for already-owned declarations can preserve identity; old-candidate receipts
must never be attached to a changed candidate. No legacy authority/family routing.

## Protected working state and reproducibility

The initial modification in `test/runtime_v4_validation_uq_execution_request_tests.jl`
and unrelated untracked prototypes/reports are protected and excluded from this
milestone. Its protected SHA-256 remained
`DF1A67C20C528FED9012067A45640A58C6DEDE3E45F042A26A9CAE056E757ED2`.
Initial status/HEAD are in the spatial run, and only explicitly reviewed source,
audit and report paths are staged. The 120 MB numerical field/Jacobian/current
artifacts remain local. Their manifest records command/arguments, recovery ledger,
checkpoint identities, external raw dependencies, source, Project/Manifest,
executable, environment and output hashes.

## Current authority statement

`p5_ready=false`; credible physical device candidates: **0**. This milestone
executes the complete declared spatial model for four cases and the actual
current-to-pickup engineering chain, including reproducible failed nonlinear
solves. Whole-device assessment is executed and deferred; physical validation is
unsupported and unexecuted. Independent formulation/MMS/analytic checks verify
software and numerical identities, not physical applicability. Deterministic
flux endpoints are not distributions, confidence intervals or certified global
bounds. Green regression tests and runner exit 0 grant no equilibrium,
engineering-feasibility, validation or terminal classification.
