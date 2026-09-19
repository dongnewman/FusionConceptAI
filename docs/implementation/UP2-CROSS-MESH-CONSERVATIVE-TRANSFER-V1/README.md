# UP2 candidate-bound cross-mesh conservative transfer V1

This additive slice is the next narrow UP2 software boundary after the
declared G1/G2/G3 diffusion and declared spatial-composition screens.  It
constructs a real two-cell source mesh and four-cell target mesh, binds both
to the same candidate, source, declaration-body, and transport-bundle hashes,
and transfers a cell-integrated field through geometric overlap.  It records
source/target integrated account totals, per-target local defects, interface
defects, a global defect, overlap coverage in both directions, and both mesh
hashes.  The transferred state is then passed to an explicit one-dimensional
diffusion kernel on the four target cells.

The nominal path is candidate-bound only when the existing G123 byte-level
admission can be re-run and agrees with the input hash set.  Candidate, body,
bundle, axis, mesh, ownership, and state-shape changes are fail-closed.  A
non-covering overlap is terminal-deferred; orientation and unit mismatches are
fail-closed; nonfinite or zero-measure numerical data are numerical-fail; and
missing external/return accounts are terminal-deferred.

The JSON fixture contains two arithmetic cases.  `main` is the candidate-bound
two-cell to four-cell path (`[0,.5,1]` to `[0,.25,.5,.75,1]`) and records the
`0.5` conserved mass, overlap lengths, target-normalized `P` matrix, zero
defects, and the expected four-by-four diffusion matrix/RHS/solution.
`holdout` is an independent nonuniform geometry (`[0,.4,1]` to
`[0,.2,.5,.8,1]`) with state `[2,-1]`, expected transferred state
`[2,1,-1,-1]`, and mass `0.2`.  It is a geometry/arithmetic holdout, not a
Julia execution receipt.

The evidence ceiling is `screen_only`.  `accepted=false`, `formal_up2_credit=false`,
`formal_r_credit=false`, and `no_up2=true` are hard-coded in the outcome.  No
provider, registry, solver service, or old receipt is modified.  The supplied
Julia test lane calls the transfer and diffusion algorithms directly, while
the handoff verification is Python-only: static QA checks declared seams and
fixture contracts, and the independent oracle recomputes overlap, `P`, mass,
coverage/defect, and the main diffusion solve without importing Julia or
FusionConceptAI product code.  These checks do not constitute Julia execution,
provider evidence, physical validation, acceptance, or UP2/R credit.

Owned additive files:

- `src/RuntimeV4/DeclaredCrossMeshConservativeTransferExecutionV1.jl`
- `test/RuntimeV4/UP2CrossMeshConservativeTransfer/cross_mesh_conservative_transfer_v1_tests.jl`
- `test/RuntimeV4/UP2CrossMeshConservativeTransfer/fixture.json`
- `test/RuntimeV4/UP2CrossMeshConservativeTransfer/static_qa_declared_cross_mesh_v1.py`
- `test/RuntimeV4/UP2CrossMeshConservativeTransfer/independent_oracle_declared_cross_mesh_v1.py`
