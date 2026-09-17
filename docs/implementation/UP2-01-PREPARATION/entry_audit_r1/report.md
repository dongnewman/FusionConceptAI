# UP2-01 physical compilation entry audit R1

Verdict: **evidence_gap_with_exact_missing_path**.

This is a read-only preparation audit at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2` with 284 dirty/untracked status rows captured before the audit artifacts were written. Julia and DESC were not started. The claim ceiling is `preparation_static_audit_no_Julia_DESC_no_implementation_no_recomputation`.

## Source and path result

G1 V5 typed state/equation/profile records, G2 V5 chart/field-space/region contracts, G3 V5 resource/control/feedback records, and the additive `CandidateStatePackageV5` are present and hashed in `report.json`. The executable chain is incomplete: `Compiler.jl` still accepts `CandidateStatePackageV4` and emits `CompiledCandidatePrefixV4` structural obligations; no `EquationIRV4`, `WeakResidualIRV4`, `DiscreteResidualV4`, or `SolverPlanV4` entry exists. `FieldResidualPipeline.jl` is a V4 manufactured `LAPLACE(u)-2f` screen with `screen_only` authority. `SpatialRuntimeV4.jl` is a once-only loader, while `SpatialMultiRegionV4.jl` is a fixed two-region static-MHD slice. G3 feedback is typed structural contract data; no runtime spatial residual receipt is joined back to an authoritative same-candidate feedback channel.

The exact node-by-node verified/missing table is in `report.json.path_audit`:

1. source → equation IR: **missing** (`Compiler.jl:102-156`); typed G1 declarations exist, but no V5 equation lowering.
2. equation IR → solver input: **missing**; only the fixed manufactured V4 field residual produces `SolverInputV4`.
3. solver input → spatial residual: **missing**; the spatial module is not a V5 candidate-bound general backend.
4. spatial residual → feedback: **missing**; G3 feedback has no execution receipt/source/subject/hash closure.

## Minimal legal slice required before runtime scheduling

Use one actual V5 package with one scalar state `u`, positive scalar or SPD coefficient `K(x)`, source `f`, region/chart/metric/function space, and explicit Dirichlet or Neumann ownership. Lower `-div(K grad u)=f` into typed strong and weak records, then a discrete record with mesh/basis/quadrature, DOF and face orientation, conservative flux, Jacobian sparsity and nullspace. The solver input must bind candidate, prefix, equation, weak and discrete hashes, provider manifest, material/boundary data, numerical configuration and failure taxonomy. The positive MMS gate needs analytic solution/source, relative L2/Linf error, residual, boundary error, source/integral balance and mesh-refinement thresholds. G3 feedback must carry same-candidate identity, source and units and remain below physical authority.

## W24 evidence and non-reuse decision

W24 child R2 contains the four named cases and independently hashed raw summaries, but the spatial solver raw exit is `4` with `iteration_limit`; final nonzero residual norms remain in the iteration logs. The archive explicitly records `physical_validation=unsupported`, `p5_ready=false`, `credible_device_count=0`, and zero physical-validation credit. Its MMS fields are an analytic weak/strong quadrature diagnostic and interpolant diagnostic without an established solution convergence order. Pair comparability is `changes_requested` because the immutable parent had 433 source records versus the child’s 449 and the verifier hash changed; a later manifest audit also found shared-worktree source/test byte mismatches. These artifacts cannot be reused for the UP2-01 candidate-bound diffusion slice or B01/physical credit.

## Dependencies and independent negative controls

UP1-04A remains limited contract-only wiring; UP1-04B still owns pending B00/B04 receipts, checker and two-process replay; UP1-04 total migration remains planned. Schedule UP2-01 only after those gates, then UP2-02 after stable equation/solver-input hashes. Required negative controls are recorded in `report.json`: missing boundary, negative/non-SPD coefficient, wrong source unit, duplicate boundary, label/family rewrite, foreign candidate/mesh, missing G3 authority, and iteration-limit/nonfinite residual.

JSON parsing, `validate_plan.py`, `git diff --check`, HEAD/dirty capture and a read-only Julia/DESC process sweep are recorded with real timestamps, exit codes, stdout and stderr in `command_receipts.json`. No implementation, test, core document or prior evidence file was modified.
