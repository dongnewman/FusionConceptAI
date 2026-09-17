# UP2-01-G2-METRIC-BOUNDARY-V1 R2 narrow repair

Disposition: `ready_for_independent_review_r2`; `review_pending=true`;
`accepted=false`; runtime `not_run`.

R1 was `changes_requested` for four bounded issues: reference face normals
were not distinguished from physical oriented area vectors; determinant,
orientation and typed coordinate/measure units were absent; the public
admission path had no behavioral `program_exception` check; and
`execution_status=:not_executed` could bypass the mesh deferred gap.

The R2 source repair is confined to the new metric-boundary V1 file. The chart
now exposes exact `g2mb_det_jacobian`, `g2mb_orientation_positive`, and a
cofactor evaluation
`g2mb_physical_oriented_area_vector(chart, reference_normal)` that returns the
unnormalized physical vector `cofactor(J)*n_ref = det(J)J^-T n_ref`. The
field is named `reference_normal`; it is never presented as a physical normal.
`G2MBVolumeMeasureV1` records signed and absolute determinant scale plus
orientation and volume `UnitSignature`.

`G2MBUnitContractV1` adds typed coordinate, Jacobian, metric, area, volume,
field-value and flux-value units. `G2MBFaceValueV1.unit` is now a
`UnitSignature`; admission checks Dirichlet values against `field_value` and
Neumann values against `flux_value`. The fixture and focused test carry exact
unit exponent vectors and a mismatched-unit negative control.

Both mesh statuses accepted by this preparation contract, `:declared` and
`:not_executed`, unconditionally add `mesh_execution_not_executed` and cannot
reach a resolved admission. A module-owned `_G2MBFaultProbeV1` is the only
controlled fault seam. Calling the public `g2mb_admit` with that internal probe
reaches the typed `program_exception` result and records `exception_type`; no
caller-provided error text is parsed or routed.

Static QA was rerun with the explicit Python interpreter and exited `0`:

```powershell
& 'D:\Users\Newman\anaconda3\python.exe' 'D:\006-Programing\LMC\FusionConceptAI\test\GenomeV5\G2\static_qa_metric_boundary_v1.py'
```

It reported `static_qa=pass`, `julia_or_desc_executed=false`,
`provider_or_mesh_execution=false`, `review_pending=true`, and
`accepted=false`. JSON fixture/archive parsing and text whitespace QA also
passed. No Julia/DESC, compiler, provider, mesh backend, solver or physical
run was performed.

The original R1 archive and original implementation acceptance remain
unchanged. This repair archive records the before/after hashes and requests a
different Luna R2 static review before any focused Julia lane is considered.

