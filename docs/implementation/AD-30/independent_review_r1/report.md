# AD-30 independent architecture review R1

## Verdict

Overall: `changes_requested`; `accepted=false`; `review_pending=true`.

The no-loss diagnosis is `pass_limited`: the current V1 declarations contain semantic fields that the existing concrete V5 types and old package cannot carry without loss, and the hard type gates reject a declaration-only adapter. AD-30 correctly preserves the old package, old hashes, old candidate identities, historical receipts, the UP0–UP6 DAG, and R01–R10 boundaries.

The proposal needs a contract addendum before Sol acceptance because T0/T1/T2 describe the intended identity chain but do not make all AD-19/AD-28 join obligations explicit and machine-checkable. This is an architecture specification gap, not an execution result.

## No-loss and old-package audit

The G1 V1 declaration stores candidate-owned `u`, bounded spatial `K(x)`, `f`, typed `GRAD/K_APPLY/DIV`, units, residual sign, source payload/hash, closure and applicability. The existing `MechanismGenomeV5` instead requires `MechanismGenomePayloadV2`, its own contract ref and four axes. The V1 source payload cannot be passed through the existing V5 constructor without discarding or rewriting those fields.

The G2 V1 declaration carries chart/Jacobian/metric data, exact quadrature, face normals/values/units/ownership and authority. The existing `FieldGeometryGenomeV5` is built from `RegionInterfaceContractV2`, `FieldSpacePlanV2`, `SpatialGrammarProfileV2` and G2 V2 axes; its plan boundary does not represent the complete V1 declaration payload. The G3 V1 source/feedback declaration carries conservative source/field/return/heat law, typed ledger closure, owner/sign/direction and feedback authority ref/hash/status, while the existing `RealizationControlGenomeV5` carries realization/control/binding child contracts and resource-network data without this complete V1 law declaration.

The old integration helper requires `MechanismGenomeV5`, `FieldGeometryGenomeV5` and `RealizationControlGenomeV5`. `CandidateStatePackageV5` repeats those concrete type gates and validates the old component identity, G2 candidate binding, G3 child refs, feedback identity and old package hash. Therefore AD-30's prohibition on ref-only adapters and fixture authority is supported. T0 must remain outside the old package, and T1 must be a genuinely separate versioned package/integrator with no relaxed old constructor or registry path.

## T0/T1/T2 contract review

| Layer | Satisfied by proposal | Required clarification before acceptance |
|---|---|---|
| T0 | Additive transport, declaration/source payload preservation, declaration/source hashes, fresh candidate, contradiction `fail_closed`, missing authority `terminal_deferred`, old package exclusion | Define one candidate-bound source identity/join input and the exact hash recipe. Require G1/G2/G3 source/declaration hashes and candidate ref to be checked together, with edits rebuilding every affected hash. Name all four axes and require exact per-layer axis equality rather than only saying “four axes”. |
| T1 | New `CandidateStatePackageV5Next`, new package hash/receipts, no old package hash/migration receipt/candidate identity reuse, complete three-layer transport in principle | State that V5Next is an additive successor satisfying every AD-19 package field: five-field public G1/G2/G3 refs, component/declaration hashes, same candidate ref, G2 candidate binding plus real genome hash, G3 external bundle plus realization/control/binding child refs, feedback target refs and authority status/hash. The package hash must include canonical declaration/source payload identity, not only a ref/axis projection. Define a fresh migration receipt or explicit no-legacy `terminal_deferred` record without fabricating legacy mapping. Keep `CandidateStatePackageV5`, shared entry and default registry unchanged. |
| T2 | Rebuilds E0/G-I1A/E1/E2/UP2 identities before formal B00/B04; keeps execution and promotion pending | Require every rebuilt identity and receipt to bind the same fresh candidate, source identity, all four axes, three component/declaration hashes, G3 child/feedback refs and authority gaps. Missing actual source/provider authority must remain independently typed `terminal_deferred`; no T2 identity rebuild may promote it. |

AD-19 requires an additive strongly typed package and same-candidate exact three-layer join with actual public refs, four axes, component hashes, G2 binding/hash, G3 child refs/feedback authority and rebuilt candidate identity. AD-30's `CandidateStatePackageV5Next` is compatible only if it is explicitly specified as that successor contract. As written, the name is not a direct runtime conflict, but the missing field-by-field mapping leaves a contract ambiguity; this is the blocking recommendation.

The current hard package hash in `CandidateStatePackageV5` is derived from old package identity, axes and migration receipt. V5Next must define a new canonical hash body that covers the transported declarations and source identity. Otherwise an edit to a declaration could leave the package identity unchanged even though T0 claims source rebinding rebuilds identity.

## Evidence and boundary checks

AD-30 manifest JSON parses, and `validate_plan.py` exits `0` with 31 markdown files, 363 links, 31 tasks and an acyclic DAG. Current post-change hashes match AD-30's recorded post-change values for the proposal, AD-30 decision text, README, work orders, task manifest and all reviewed source/package files. The manifest's pre-change README hash no longer matches the current README, while its recorded post-change README hash matches; this is the documented concurrent external drift and no README edit was made in this review. The same pre/post pattern is recorded for the AD-30 insertion in the architecture-decision document.

The proposal explicitly keeps `proposal/review_pending/accepted=false`, forbids execution authorization, preserves the DAG and R01–R10, and grants no provider, mesh, engineering, physical, search or R01–R10 credit. No Julia or DESC was run, and no source, core, old receipt or package file was modified by this review.

## Required disposition

Add the T0/T1/T2 field-level identity contract described above, especially the source identity/hash join, exact four-axis binding, G3 child/feedback authority fields, V5Next package hash inputs, fresh migration receipt semantics and explicit old-entry/package isolation. Then obtain a new independent architecture review. Until that addendum exists, AD-30 remains a proposal and no implementation or physical credit is available.
