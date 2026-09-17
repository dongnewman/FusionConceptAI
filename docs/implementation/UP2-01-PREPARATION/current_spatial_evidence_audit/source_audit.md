# UP2-01 current spatial evidence audit

Status: `review_pending`; this is a read-only evidence audit. It carries no B01/B02, provider, mesh, engineering, physical, or R01–R10 credit.

## Audit boundary and frozen state

The audit opened at `2026-09-14T09:09:54.4566955+08:00` at repository HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. At the final process check no Julia, DESC, or Python process was present. No Julia/DESC command was run for this audit. The pre-existing dirty worktree was preserved; the audit observed 277 status entries at archive creation. The exact status and process snapshots are in this directory.

Inspected source and contract inputs, with bytes and SHA256:

| Path | Bytes | SHA256 |
|---|---:|---|
| `scripts/run_v4_spatial_chain.jl` | 12890 | `ad5f7864da35bcd355ac256a20574648bab1372055954a71596bb631348d1520` |
| `scripts/verify_v4_spatial_manifest.py` | 5437 | `bbf9a7e3fc2f6c611f05194ed9909dc22b9c7f4f9cf0694ea7ef6573813b16d6` |
| `src/RuntimeV4/SpatialRuntimeV4.jl` | 1757 | `c71c90090c5401c1e71cc13b319dff45b7a70d273e17f4687be1a91a8be310bb` |
| `src/RuntimeV4/SpatialMultiRegionV4.jl` | 56867 | `cac5b47beeee2fbab7de6f171f7f155ff5534bc51edec0e66ee8caf711d6b932` |
| `src/RuntimeV4/SpatialVerificationUQV4.jl` | 38961 | `a8a901109727896c9b70d2e7f1db4406683b1c5a09bf7e091e09ae79eb454e29` |
| `src/RuntimeV4/SpatialCandidateV4.jl` | 15745 | `65bf49da8398283c5c7b017327e28b5db602eda9479e995f6da27abfe7f7c9a4` |
| `src/RuntimeV4/SpatialGeometryEditV4.jl` | 10031 | `97ef8c4379554efc2760eeca23318de45ff59a2bb1d58b0e727ce95e3b608272` |
| `src/RuntimeV4/SpatialWholeDeviceV4.jl` | 8407 | `046d5fbdd7a6586509319a50203745b2d3a4fa13dd51688e4413d9f15a57b94d` |
| `scripts/spatial_verification_oracle_v4.py` | 14457 | `a2adeed524d83d79f23863ab0fb0e78887e50892853ac09e62d15fb5a7864b90` |
| `scripts/spatial_multiregion_desc_sample.py` | 11961 | `e84b09171b578658844c5f4a4e3ff10f3404a66ef025c030cd361446aa6deea8` |
| `docs/v4_multitopology_generation/11_physics_compilation_and_discretization.md` | 28542 | `f31e075f3a7c0d301179af483db14b6b616c0d8c50458850768d41d17bd8bb25` |
| `docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md` | 42827 | `82a5929b83af3cc9d0ba979dbeb1193eb9e9f876bae58f0e121058507a11af4d` |

The runner uses a one-shot fixed source order and selects the normal or geometry-edit candidate. It hardcodes DESC controls `L2=2, M2=2, N1=1, Lgrid=4, Mgrid=4, Ngrid=3, maxiter=20, ftol=xtol=gtol=1e-8`. The runtime source has a load-state guard against duplicate or partial loading. The multi-region implementation is a fixed two-region ideal static MHD/Q1 declaration with fixed interface and four state fields; it asserts the declaration hash and reports the declaration as not implemented when changed. These facts make the current runner a bounded fixture runner, not a declaration-driven arbitrary B01/B02 compiler.

## Current W24 four-case evidence

The audited fresh child is `runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2`. Its execution manifest records candidate hash `7214413813420fdc494ef96dfb1de7fe7de38db5a1489e574dfbe25890842a55`, context hash `9f408a27de5a6206c2d046d8d6e6a577f9b1641b11a3c308ef4730b2ff24f582`, 449 source records, and the frozen `--g2-child` command. Environment evidence is Julia 1.10.5, 24 logical CPUs, 24 Julia threads, BLAS 12, DESC 0.17.3, Python 3.13.5, and JAX/JAXLIB 0.9.2 CPU.

The process wrapper completed with `runner.exit=0` (two bytes, `0\n`). That is only process completion. The terminal ledger records physics `program_exit=0, solver_exit=4, scientific_status=scientific_fail`, engineering and verification program exits 0 with scientific failure, whole and manifest completed as `scientific_unsupported_or_deferred`, and no physical validation execution.

| Case | Physics result | Solver/stopping | scaled max | scaled norm | divB RMS | Outer Bn | Outer traction mismatch |
|---|---|---|---:|---:|---|---:|---:|
| `nominal_coarse` | fail | 4 / iteration_limit | 0.00940944138659572 | 0.126511326466326 | 0.17210169462879, 0.30078600013771 | 0.105648393656069 | 199384.215065418 |
| `nominal_fine` | fail | 4 / iteration_limit | 0.005491101852652 | 0.125266403583055 | 0.141740206634198, 0.200222227323313 | 0.0277860768420625 | 164032.335566726 |
| `flux_low_coarse` | fail | 4 / iteration_limit | 0.00974632669660216 | 0.146016350089692 | 0.275079564350165, 0.290921491304773 | 0.106872601095103 | 248169.925512738 |
| `flux_high_coarse` | fail | 4 / iteration_limit | 0.0195151255926869 | 0.150905941340897 | 0.268525026503764, 0.281728843956126 | 0.107969960771335 | 263390.472404637 |

All four cases have `conservation=false` and physical status `unsupported`. The verification oracle emitted case-level exit 0 and structural/numerical tables (rows/columns: 2881/360, 21761/2640, 2881/360, 2881/360), but the root verification status is fail because physics failed and upstream validity is false. Engineering qualification is false. Result status is `deferred`, `credible_count=0`, `p5_ready=false`, and `physical=unsupported`. These are distinct from a process exception: the observed stage failure is numerical nonconvergence (solver iteration limit), followed by unsupported/deferred physical validation.

The W24 checker `w24_spatial_manifest_audit.json` has status `fail`, 595 records checked, 594 unique records, and five source hash mismatches (the G2 geometry, field-space, interface, grammar, and G2 contract-test records). Its identity, process, four-scenario, authority, and ledger-recovery checks are true; it is an artifact/source audit and does not prove physical convergence. The paired audit is `failed_before_output`, exit 1, because the parent and child source sets differ (433 versus 449), including child-only G1/G2/G3 source and test records and a checker hash drift. This is a comparability/source-integrity failure, separate from the child run's numerical result.

The recent `spatial_chain_after_stagnation_fix_r2` and `spatial_chain_20260912_r1` runs show the same four-case physics solver exit 4/iteration-limit boundary, process wrapper exit 0, deferred whole result, physical unsupported status, and credible count 0. Their key result hashes are retained in the manifest; neither run supplies physical evidence or a winner.

## Evidence classification and editability gaps

The run is not a program exception: candidate, DESC receipt, stage ledgers, result, execution manifest, and wrapper exit were produced. It is a numerical failure at the physics solver (`solver_exit=4`, iteration limit). Engineering and verification preserve the failure boundary. Whole-device and physical validation are unsupported/deferred because the applicable physical/provider evidence was not executed or qualified. The checker failure and paired audit failure are artifact/source-integrity issues, not numerical evidence.

The current implementation is not sufficiently editable for the proposed UP2 physical chain. The runner has no general candidate/mission input and hardcodes solver controls. The loader is one-shot and fixed-order. The spatial model has fixed two-region static MHD, fixed interface and state fields, fixed mesh/declaration checks, and no generic equation/material/closure/compiler route. A G2 geometry edit can alter the fixture geometry but does not establish a general coupled equation or physical recompiler. Any future run must therefore use a new candidate-bound input and fresh receipts; it must not reclassify these W24 artifacts.

## Smallest future B01/B02 smoke slice

This is a proposed work order, not an executed result. Add a new UP2-01 bounded fixture and runner after a fresh typed candidate and source snapshot are frozen. B01 should compile one declaration-driven manufactured residual with an analytic field/source/boundary through two independent implementations/formulas, execute the real discrete residual and solver on three nested serial grids, and emit candidate identity, compiler/discretization receipts, per-grid residual/error, solver exit, and resource records. The fixture must be distinct from the fixed W24 two-region example and must expose editable equation, operator, closure, boundary, coordinate/time, and grid parameters.

The future command should be a new runner such as:

`julia --startup-file=no --project=. test/GenomeV5/UP2/run_up2_01_b01_b02_smoke.jl`

It must run as one Julia process with no concurrent Julia/DESC process, write a unique run directory, and preserve stdout, stderr, real exit, candidate/input hashes, grid manifests, residual tables, checker output, and replay receipt. No current W24 source or threshold should be overwritten.

B01's candidate acceptance numbers are the `suggested_initial_protocol` values in core contract 13: all declared grid solves exit 0 and the exact manufactured residual/error sample is `<=1e-8` with the contract's absolute/relative interpretation. B02 should consume the same three nested grids, use the continuous fine-pair order, compute per-account/interface conservation defects, and use the suggested initial scaled conservation defect `<=1e-10` plus two consecutive refinement intervals in the separately frozen p range. These are candidates only; this audit freezes no threshold, unit, scale, grid, or asymptotic range. A future protocol must freeze those before execution and must not tune them to the current failures. Retain the current observed-order failure (`-6.157952975473273`) as historical evidence. A pass would remain software contract evidence; provider, mesh, engineering, physical, and R credit require their separate gates.

## Key retained artifact hashes

| Artifact | Bytes | SHA256 |
|---|---:|---|
| `candidate.json` | 46937 | `1cd550c7b60a9e30daa238d6e2d2e58242a8bfec4448220340bf0ffc5a38c9e1` |
| `environment.json` | 312 | `3cad1d18a0bc6dc0825c3c6b048a17b965d89e8557215ca55544a7c740d3fb3e` |
| `execution_ledger.jsonl` | 4949 | `e03dbe788ca239436acb734e71dfce7b83c581995cc80c2ac7988524881b83b8` |
| `upstream_receipt.json` | 3735 | `89db57f9e077fcd0d86bd364192ff460f6d1f513d9ea548e16fe3dba0682025c` |
| `physics.json` | 944692 | `74eddc98aaed4b7dd9f340a3ab2213f5508a6bc31191a2da2f13a594a03b442c` |
| `engineering.json` | 1292917 | `41a9e7e951bb148836b78b147e6a839d702a50d94a264e7be2850a60fc37b087` |
| `verification.json` | 3911630 | `600b01f434299db40e818cbc189756476704d88756efb5b47c6220128a64a4a4` |
| `result.json` | 819141 | `1aca626e12b9538760b494537ce8487ba2199816e27de72d1ffed6000932ee67` |
| `execution_manifest.json` | 121518 | `5e2d6709722c71b83b5b8f2e24be5b751b07a0ec78138d3cb642581714c20768` |
| `runner.exit` | 2 | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa` |
| `w24_spatial_manifest_audit.json` | 2011 | `226ecb353d24f202c17fab18d6b724e9f38de750db7ea3448161cc56fc6a474c` |
| `w24_spatial_g2_pair_audit_attempt.json` | 1716 | `320e0f461270f10aa08648aa5feedfad794506b134bf38129f48e6e4cd288cd7` |
