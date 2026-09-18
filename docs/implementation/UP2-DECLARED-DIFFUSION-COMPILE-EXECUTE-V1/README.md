# UP2 — Declared Diffusion Compile/Execute V1

This additive vertical slice connects the submitted
`DeclaredG123DiffusionExecutionV1` declaration/bundle boundary to the
submitted `DeclaredSpatialCompositionExecutionV1` one-dimensional finite-volume
boundary.  It is intentionally a local, candidate-bound software screen.

The path is:

1. strict G1/G2/G3 candidate, source, declaration-body, receipt, and bundle
   hash validation;
2. closed-subset typed lowering (`1D`, structured scalar,
   `diagonal_affine_static`, static, one field);
3. typed port matching and composition plan construction with labels erased
   from semantic plan identity;
4. the submitted G123 2-DOF numerical lane plus a separate existing spatial
   overlap-transfer/FV assembly/solve holdout;
5. separate compile, lowering, composition, numerical, and aggregate receipts.

The aggregate can report `terminal_deferred` even when the numerical screen is
`ready`: unresolved G2/G3 authority is not silently promoted.  All outcomes
have `claim_ceiling=:screen_only` and `accepted=false`; package status is
`review_pending`, not accepted_limited.  No provider, mesh backend, registry,
Compiler.jl, Julia execution, or DESC execution is added.

Verification commands (Python only):

```text
python -B test/RuntimeV4/DeclaredDiffusionCompileExecute/static_qa.py
python -B test/RuntimeV4/DeclaredDiffusionCompileExecute/independent_oracle.py
```

`focused_tests.jl` is a serialized Julia command definition for a later
controlled lane and is not part of this handoff's execution evidence.

The G123 numerical receipt and spatial FV holdout remain separate: their
discretization identities and matrices are not compared as one result.
