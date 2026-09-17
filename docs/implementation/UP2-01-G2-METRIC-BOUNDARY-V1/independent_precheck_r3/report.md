# UP2-01-G2-METRIC-BOUNDARY-V1 independent static precheck R3

Verdict: `pass_limited`; serial focused readiness: `ready_for_serial_focused`;
`review_pending=true`; `accepted=false`.

This is a read-only different-Luna review of the R3 repair at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The working tree had 300 status
rows at capture and no Julia/DESC process. The review read the R2 finding and
the complete R3 report, manifest and receipts, then inspected the current G2
source, focused test, fixture and static QA. Only the explicit Python static
QA and JSON parsing were run. Julia, DESC, compiler, provider, mesh backend,
solver and physical execution were not run.

## F02 closure

R3 adds a typed `reference_coordinate` field and an executable unit algebra
check. The validator requires reference coordinates to be dimensionless,
physical coordinate and Jacobian units to be `L`, pullback metric and
cofactor/oriented-area units to be `L²`, and determinant/volume units to be
`L³` (`MetricBoundaryDeclarationV1.jl:255-309`). The expected values are
computed through `UnitSignature` exponent addition, rather than copied from
fixture text.

The derived paths use the validated contract. The typed area measure evaluates
the actual cofactor vector and returns `units.area`; the typed volume measure
evaluates the actual determinant and returns `units.volume`, while both reject
an unvalidated unit contract (`MetricBoundaryDeclarationV1.jl:311-334`).
Admission recomputes the source body hash, appends every unit algebra error,
and only evaluates the volume and six area bindings after the unit contract is
valid (`:435-475`). Therefore a source with a self-consistent new hash but a
wrong geometry unit is `fail_closed`, rather than being accepted or converted
to a gap.

The focused test constructs each of six malformed geometry contracts through
`g2mb_source_v1`, which recomputes a valid source hash for the malformed body,
then calls public `g2mb_admit` and asserts the specific typed error for each
field (`metric_boundary_v1_contract_tests.jl:146-174`). It also checks the
typed area and volume measures bind to the validated contract (`:68-76,
:149-151`). This closes the R2 unit-algebra blocker at the static contract
level.

## Preservation checks

The R2 orientation semantics remain present: the chart exposes determinant and
positive orientation, `g2mb_physical_oriented_area_vector` computes the exact
cofactor expression `det(J)J^-T n_ref`, and the source keeps reference normals
separate from the physical area measure (`MetricBoundaryDeclarationV1.jl:79-116,
:320-334,457-467`). The negative determinant control remains a source-derived
`fail_closed` assertion (`metric_boundary_v1_contract_tests.jl:131-136`).

Both permitted mesh statuses still unconditionally add
`mesh_execution_not_executed`; unique authority cannot resolve an unexecuted
mesh (`MetricBoundaryDeclarationV1.jl:137-169,469-472`; test
`:115-120`). Bad public input remains typed `fail_closed`, while the
module-owned controlled probe reaches typed `program_exception` with an
exception type (`:477-510`; test `:127-130`). Source/declaration identity is
still rebuilt after chart, mesh or face-value edits, and the six candidate-owned
face closure checks remain in admission.

No static Julia definition-order or syntax defect was found in the inspected
R3 changes. Runtime compilation and the focused Julia test remain the next
gate; this review does not infer a runtime pass from static text or Python QA.

## Evidence and claim ceiling

The explicit Python static QA exited `0` and reported
`static_qa=pass`, `julia_or_desc_executed=false`,
`provider_or_mesh_execution=false`, `review_pending=true`, and
`accepted=false`. JSON parsing of the R3 archive and fixture passed. The
fixture remains contract-only with zero compile/provider/mesh/solver calls and
no physical evidence.

Disposition: `pass_limited` for the contract and preparation boundary only;
`ready_for_serial_focused` means the separately controlled focused lane may be
considered. It grants no mesh, provider, engineering, physical, B00, B04 or
R01-R10 credit. Actual-A authority and execution remain outside this review.
