# UP2-01-G2-METRIC-BOUNDARY-V1 independent static precheck R1

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

This read-only review covers the current G2 metric-boundary preparation at
frozen HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. It read the AD-28 and
AD-29 boundaries, the v4 README/00/14/16 G2 work order, the G2 acceptance and
evidence manifest, source, focused tests, fixture and static QA. The working
tree had 300 status rows and no matching Julia/DESC process at capture. Julia,
DESC, a mesh backend and a provider were not run.

## Verified static contract surface

`G2MBChartMapV1` stores exact rational bounded 3-D affine chart data and
rejects non-ordered domains, singular Jacobians and non-affine map kinds
(`MetricBoundaryDeclarationV1.jl:14-37`). `g2mb_chart_map` evaluates the map,
`g2mb_chart_jacobian` exposes `J`, and `g2mb_metric` computes `JᵀJ` from the
stored rows (`:70-88`). Positive definiteness is checked by Sylvester minors;
the fixture and tests verify the exact diagonal `J=diag(2,3,4)`, metric,
midpoint map value and image bounds (`metric_boundary_v1_contract_tests.jl:44-55`).

`G2MBMeshPlanV1` carries positive bounded cell counts, Q1/Q2 basis, rational
reference-cell quadrature points and positive weights, with declared/not
executed status (`MetricBoundaryDeclarationV1.jl:97-135`). The fixture uses
bounded `(2,3,4)` cells, Q1 and two rational quadrature points/weights.

Face values are typed Dirichlet/Neumann records; six face owners require the
six reference box faces, candidate-owned ownership, unique IDs and unique face
names. Admission checks expected reference normals, closure and duplicate
owners (`MetricBoundaryDeclarationV1.jl:137-177,307-332`). The fixture covers
both value kinds and all six reference faces. Source construction validates a
canonical body hash over source ref/version, candidate, chart, mesh, faces,
profile and authority; declaration construction adds schema/canonical/profile
hashes and a declaration hash. `g2mb_edit_source` rebuilds both identities
(`MetricBoundaryDeclarationV1.jl:231-274,355-394,434-455`). The static QA
passed with no Julia/DESC/provider/mesh execution.

`g2mb_admit` distinguishes typed structural `fail_closed`, missing authority
`terminal_deferred` and caught `program_exception` with `exception_type`, and
does not classify by exception-message text (`MetricBoundaryDeclarationV1.jl:276-353`).
The test covers deferred authority and a bad-face fail-closed result
(`metric_boundary_v1_contract_tests.jl:90-102`). The fixture remains
`review_pending=true`, `accepted=false`, schema-only, with zero execution
counters.

## Blocking findings

### 1. Face orientation is reference-only, not affine physical orientation

`G2MBFaceOwnerV1.outward_normal` is stored as an integer reference-box normal,
and `_g2mb_validate_source` compares it to the fixed axis normal returned by
`_g2mb_expected_normal` (`MetricBoundaryDeclarationV1.jl:297-326`). It never
transforms that normal through the chart. For an affine map, the physical
oriented face vector must be derived from the cofactor map
`det(J) * J^{-T} n_ref` (or an explicitly equivalent rule), with the sign of
`det(J)` handled. A nonzero negative determinant is currently accepted by the
chart constructor and still passes `JᵀJ` positive definiteness, while the
stored face normal remains the untransformed reference vector. The current
implementation therefore cannot claim executable physical boundary
orientation. Add typed physical-normal/volume-orientation derivation and
negative controls, or explicitly classify this field as reference-only and
keep physical boundary admission deferred/fail-closed.

### 2. Coordinate units and volume orientation/measure are absent

Chart coordinates and Jacobian entries are exact rationals but have no typed
coordinate `UnitSignature`; face values carry only a nonempty `String` unit
(`MetricBoundaryDeclarationV1.jl:14-20,137-145`). There is also no explicit
`det(J)` orientation or volume-scale field/method in the source semantic view,
mesh plan or receipt. Positive quadrature weights alone do not establish the
physical cell measure or orientation under the affine map. This leaves the
requested coordinate/unit/volume-direction contract unverified. Add typed unit
and volume-orientation/measure semantics, or record these as separate
terminal-deferred obligations rather than executable boundary evidence.

### 3. `program_exception` has no behavioral test

The source has a separate catch branch returning `:program_exception` and
`:unexpected_exception`, but the focused tests only exercise terminal
deferred and fail-closed results. The fixture names an unexpected-program-
exception control, yet no test asserts `program_exception`, `exception_type`,
and absence of a structural result. Add a public malformed-input control that
reaches the existing catch path without parsing error strings.

### 4. `:not_executed` can bypass the mesh-execution gap

`G2MBMeshPlanV1` accepts both `execution_status=:declared` and
`:not_executed` (`MetricBoundaryDeclarationV1.jl:105-127`), but
`_g2mb_validate_source` adds `mesh_execution_not_executed` only when the value
is `:declared` (`:327`). A caller that supplies `:not_executed` together with
`authority.mesh=:unique_match` can therefore avoid that gap and reach the
`:valid` admission branch without a mesh execution. The preparation slice must
keep this contract-only declaration terminal-deferred until actual mesh
authority/execution exists, or define a separate non-promotable status and
test it. The fixture's `execution_status="declared"` does not cover this
alternate path.

## Scope and credit boundary

The chart/Jacobian/metric and rational mesh/face declarations are contract-level
values. The current actual-A G2 authority remains absent; no executable mesh,
provider, engineering or physical result exists. No compiler, provider, mesh,
engineering, physical, B00, B04 or R01-R10 credit is granted.

Disposition: `changes_requested`; request a different-Luna static R2 review
after the physical-orientation/unit boundary and public program-exception
control are corrected, before any serial focused runtime lane.
