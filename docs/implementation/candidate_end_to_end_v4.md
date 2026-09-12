# Same-candidate execution and whole-device assessment

This milestone connects the existing current `dgpi-candidate` Genome bundle to
actual DESC outputs, regional weak-volume diagnostics, plasma-load projection,
independent integration diagnostics, discrepancy propagation, and a conservative
whole-device assessment. The candidate remains the existing declared geometry
fixture. Executing a real solver does not make its material/control declarations
complete or its device physically validated.

## Reuse audit

Reviewed legacy checkout `D:/006-Programing/LMC/outputs/fusion_concept_ai` at
`32e8e7121c8d21be36aac183d0eb89429d075c19` before implementation.

| Legacy source | Decision | Treatment |
|---|---|---|
| `src/whole_device_provider_dag_v107.jl` | extract | Preserve explicit dependencies and distinguish partial execution from closure. Rebuild with typed current-candidate contracts. |
| `src/whole_device_preflight_v104.jl` | test-only | Use missing-provider and missing-evidence scenarios as negative controls. Fixed old obligations are not authoritative for current Genome operators. |
| Legacy artifact directory/request-index selection and `Dict` stage records | reject | No old identity, family routing, evidence rank, or authority enters the Julia v4 chain. |
| Current `ForwardChainContext.jl` | wrap | Revalidate candidate, all three Genome roles, typed graph bindings, subject, scenario, and obligations. |
| Current `WholeDeviceIntegrationV4.jl` | test-only | Its five-stage tuple describes a different manufactured ECF candidate. It cannot establish same-candidate execution. |

The three parallel implementation documents record their own legacy algorithm,
provider, and validation decisions. Existing untracked prototypes are preserved;
only the reviewed independent cubature files are incorporated into this milestone.

## Typed boundary

`CandidateChainIdentityV4` binds the current candidate/context, Genome bundle,
three Genome hashes, physical subject, scenario, and obligation hashes.
`CandidateChainMetricV4` carries a finite value, SI `UnitSignature` in
`(M,L,T,I,Theta,N,J)` order, and an explicit measurement scope.
`CandidateChainStageV4` separates executed and unexecuted components from the
stage status and completion flag. A missing model is not an executed failure.
`CandidateChainGapV4` carries the missing input, prerequisite stages, and a
concrete recovery acceptance check.

`build_candidate_end_to_end` accepts the actual upstream tuple and concrete
physics/engineering/diagnostic result types. It calls their validators against
real provider artifacts and rebuilds identity before emitting the ledger.
`validate_candidate_end_to_end` is the replay boundary for an externally supplied
ledger; a canonical hash alone is not execution evidence. The report writer
always repeats validation using explicit inputs or the concrete inputs retained
by the builder in this process; an externally re-sealed hash is insufficient.

The six ledger stages are candidate binding, multi-region physics,
engineering/control/fault, numerical verification, validation/UQ, and whole
device. The last stage actually executes an assessment of their gaps. It does
not execute integrated whole-device physics. No `RuntimeEvidence`, P5 readiness,
terminal physical verdict, or credible-device credit is emitted.

## Execution and reproduction

```powershell
julia --startup-file=no --project=. scripts/run_v4_candidate_chain.jl runs/<new-empty-directory>
```

The runner refuses a nonempty directory, isolates all provider paths, executes
the DESC chain once, and feeds the same resulting objects to all downstream
modules. Focused real-chain checks consume those objects; they do not start
another provider. Provider exit codes and raw input/output artifacts remain in
the run directory. `result.json`, `result.md`, `execution_manifest.json`, and
`runner.exit` record the ledger, dependencies, source/artifact hashes, measured
results, and definitive process completion. Process success means execution and
checks finished; it does not mean a scientific pass.

The integrated runner uses normal Julia compilation. A `--compile=min -O0`
structural preflight was stopped after slow progress, with no acceptance credit;
the provider's scientific model and declared protocol are unchanged.

## Blocking dependency queue

1. Move the downstream diagnostic rho partition into explicit Genome-owned
   region/support/adjacency and constitutive/interface AST declarations. Declare
   candidate-owned weak test spaces, source/boundary laws, full state
   DOFs, and exact AST/Jacobian ownership. Obtain exterior/interface boundary
   quadrature and boundary-limit traces. Only then execute the complete regional
   residual, conservation ledger, and actual coupled solver.
2. Supply current-G3 component geometry, materials, heat/mass-flow/power inputs,
   observation/control/actuator dynamics, and protection/fault declarations.
   Connect them to validated physical loads; plasma-interface stress is not a
   hardware component load.
3. Diagnose the local residual and its integration error using an independent
   formulation. The historical q2/q3/q4 Cartesian force multiplied one period
   by NFP; it is a sector-replicated proxy, not the laboratory-frame full-torus
   vector integral. Rotate each period before summation and retain the integral
   of local force magnitude so symmetry cancellation cannot masquerade as
   equilibrium. No q5/q6 milestone is introduced.
4. Obtain candidate-applicable held-out validation data and measurement errors,
   independent physical implementation, and declared parameter/model discrepancy
   uncertainty. Observed formulation spread can be propagated, but is neither a
   certified numerical bound nor a probabilistic confidence interval.
5. Reassess whole-device coverage only after actual same-candidate upstream
   executions and admissible evidence exist. Unsupported/deferred gaps remain
   recoverable and the candidate is retained.

Adding missing G1/G2/G3 declarations changes the Genome identity. Such recovery
must create a revised candidate and rerun its upstream providers; existing
receipts must never be grafted onto that new identity. A missing provider that
can execute already-owned declarations is a different recovery path and may
retain the original candidate identity.
