# UP2-01-G2-METRIC-BOUNDARY-V1 implementation handoff

Status: `review_pending`; `accepted=false`; `claim_ceiling=contract_only`.

This is the first contract-only preparation slice for the new G2 metric and
boundary declaration. It is independently reviewable and does not authorize
UP1-04A-VNEXT, UP2-00, B04, mesh backend execution, provider execution,
engineering evidence, physical evidence, or R01-R10 credit.

The additive source file
`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` defines a candidate-bound,
content-addressed declaration. `G2MBChartMapV1` evaluates a bounded affine
three-dimensional chart, exposes its Jacobian, computes `JᵀJ`, and checks
positive definiteness by Sylvester's criterion. The fixture uses the exact
diagonal Jacobian `diag(2,3,4)` and an exact rational offset, so the metric is
an evaluated value rather than a symbolic label. `G2MBMeshPlanV1` carries
bounded cells, Q1 basis and positive quadrature points/weights. Six typed face
owners carry outward orientation, a concrete Dirichlet or Neumann value and a
candidate-owned owner identity.

`G2MBSourceV1.source_hash` covers the candidate, chart, mesh, faces, profile
and authority fields. `G2MBDeclarationV1.declaration_hash` covers the source
hash and the controlled schema/canonicalization/profile hashes. The
`g2mb_edit_source` API rebuilds both hashes after a typed chart, mesh or face
value edit. The typed receipt fixes `review_pending=true`, `accepted=false`,
zero compile/provider/mesh/solver calls and `physical_evidence=false`.

Admission keeps the required classifications distinct: contradictory source
geometry or ownership is `fail_closed`; missing metric/mesh/boundary
authority is `terminal_deferred`; an unexpected implementation exception is
reported as `program_exception` with `exception_type`, rather than being
converted to a structural result. A deferred receipt remains the expected
fixture result because no mesh or boundary backend authority is supplied.

The focused Julia test is deliberately delivered for a later controlled lane;
it was not run in this handoff. Static QA was run with the explicit Python
interpreter below and reads only source/test/fixture text:

```powershell
& 'D:\Users\Newman\anaconda3\python.exe' 'D:\006-Programing\LMC\FusionConceptAI\test\GenomeV5\G2\static_qa_metric_boundary_v1.py'
```

Static QA exited `0` and reported `static_qa=pass`,
`julia_or_desc_executed=false`, `provider_or_mesh_execution=false`,
`review_pending=true`, `accepted=false`. The recorded source/test/fixture
SHA-256 values are in `evidence_manifest.json`. No Julia, DESC, solver, mesh
backend or provider process was started.

The current actual-A boundary remains unchanged. UP1-02 is only the accepted
axis-aligned rational 3-D structural contract; its mesh/provider fields remain
structural and unexecuted. The current N07/N08 projection fixture is
`schema_validation_only`, and the AD-28 status archive records actual-A G2 as
having no executable metric/mesh/basis/quadrature/face ownership with
resolution `terminal_deferred`. This new declaration is an additive proposal
fixture and must not be described as actual-A physical geometry or mesh
evidence.

