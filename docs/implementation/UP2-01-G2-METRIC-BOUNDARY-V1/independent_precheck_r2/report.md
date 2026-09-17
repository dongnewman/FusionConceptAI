# UP2-01-G2-METRIC-BOUNDARY-V1 independent static precheck R2

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

This is a read-only different-Luna review of the R2 repair at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The working tree had 300 status
rows at capture and no Julia/DESC process. I read the R1 review, the complete
R2 repair report/manifest/receipts, AD-28/AD-29 and the G2 work-order boundary,
the current source, focused test, fixture and static QA. I ran only the
explicit Python static QA; Julia, DESC, a compiler, provider, mesh backend,
solver and physical run were not invoked.

## What R2 closed

The chart now exposes exact determinant and positive-orientation predicates,
and the source admission rejects a reversing affine chart with
`chart_orientation_not_preserved`/`volume_orientation_reversing`. Thus a
nonzero negative determinant cannot be treated as a valid source merely
because `JᵀJ` remains positive definite (`MetricBoundaryDeclarationV1.jl:79-90,
380-412`; focused negative control at
`metric_boundary_v1_contract_tests.jl:124-128`).

`G2MBFaceOwnerV1` stores a `reference_normal`, while
`g2mb_physical_oriented_area_vector` evaluates the cofactor expression
`det(J)J^-T n_ref` as an unnormalised physical oriented area vector. This is
the correct reference/physical distinction for the row-major Jacobian and is
exercised by exact fixture assertions (`MetricBoundaryDeclarationV1.jl:93-116`;
`metric_boundary_v1_contract_tests.jl:64-70`). Admission still checks the six
reference faces, six unique owners, candidate ownership and computes a typed
physical vector for each face (`:397-406`).

The mesh gap is now unconditional for both permitted declaration statuses:
`:declared` and `:not_executed` both add `mesh_execution_not_executed`, so even
unique authority cannot resolve an unexecuted mesh (`:143-173,408-411`;
`metric_boundary_v1_contract_tests.jl:108-114`). The public `g2mb_admit` bad
input path returns typed `fail_closed`, and the module-owned fault probe
reaches typed `program_exception` with an exception type without parsing an
error message (`:416-449`; test `:115-123`). Source/declaration constructors
recompute canonical identities, and chart/mesh/face-value edits rebuild both
hashes (`:299-347,452-483,531-551`; test `:93-106`).

## Blocking finding

### F02 — unit algebra is declared but not enforced

`G2MBUnitContractV1` only checks that its seven fields are instances of
`UnitSignature` (`MetricBoundaryDeclarationV1.jl:261-281`). It does not check
the required relations among coordinate, Jacobian, metric, area and volume
units. For the fixture's coordinate unit `L`, the expected relations are
`J=L`, `metric=L²`, `area=L²`, and `volume=L³`; these relations are represented
in the JSON fixture but the static QA only checks that each entry is a
seven-integer vector (`metric_boundary_v1_fixture.json:32-41`;
`static_qa_metric_boundary_v1.py:66-69`). Admission never validates those
relations. `g2mb_volume_measure` accepts an arbitrary caller-supplied unit and
only carries it into a derived record (`MetricBoundaryDeclarationV1.jl:118-134`).

Consequently a candidate can construct a source with a self-consistent source
hash but inconsistent coordinate/J/metric/area/volume exponents, and it will
not receive a typed contradiction for that defect. The only unit negative
control checks a face value against `field_value`/`flux_value`
(`MetricBoundaryDeclarationV1.jl:399-404`; test `:129-136`). Add explicit
unit-exponent algebra validation in the typed contract/admission path and
independent negative controls for each derived geometry unit. Bind the
physical oriented area result to the validated area unit (and volume result to
the validated volume unit) rather than accepting a free unit argument.

This is a preparation-contract blocker, even though the current actual-A G2
metric/mesh/boundary authority is absent and remains terminal-deferred.

## Scope and evidence boundary

The static QA exited `0` and reported `static_qa=pass`,
`julia_or_desc_executed=false`, `provider_or_mesh_execution=false`,
`review_pending=true`, and `accepted=false`. The fixture remains
`contract_only`, review-pending, with zero compile/provider/mesh/solver calls
and no physical evidence. The exact cofactor and determinant checks are
contract-level value checks; they grant no executable mesh, provider,
engineering, physical, B00, B04 or R01-R10 credit.

Disposition: `changes_requested`. Request a different-Luna R3 static review
after unit algebra and the area/volume unit binding are implemented. The R1
archive and R2 implementation evidence are retained unchanged.
