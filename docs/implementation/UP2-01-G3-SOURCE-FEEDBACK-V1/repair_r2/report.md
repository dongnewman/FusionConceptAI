# UP2-01-G3-SOURCE-FEEDBACK-V1 repair R2

R1 independent static precheck verdict was `changes_requested`. This repair is
limited to the five reported findings and remains `review_pending=true`,
`accepted=false`, and `claim_ceiling=contract_only`.

The law now carries typed `G3SFConservativeSplitV1`, `G3SFHeatRelationV1`, and
`G3SFLedgerRelationV1` values. Ledger entries carry exact rational coefficients.
The evaluator validates the declaration first, reads every declared entry, computes
source/field/return/heat from those coefficients, and checks both source energy and
ledger zero residuals. Entry role, endpoint role, direction, sign, coefficient, unit,
owner, and complete effect set are all checked. The ledger closure is typed and has no
free-text equation field.

Validation recomputes the declaration content hash. A tampered hash and a changed
ledger coefficient are public fail-closed controls. `actual` authority requires typed
ref/hash but is still rejected as `unattested_authority` unless a trusted receipt
attestation exists; even a trusted-looking record remains behind the VNEXT
same-candidate G1/G2 binding gate and cannot resolve this preparation slice. Missing
authority remains `terminal_deferred`.

`g3_sf_admit_v1(...; fault_seam=:internal_validation_fault)` is a controlled public
fault seam used only to verify the independent `program_exception` taxonomy. Ordinary
bad input remains `fail_closed`.

The synthetic 120 W example remains contract-only. No Julia/DESC/compiler/provider/
mesh/engineering/physical/R01-R10 credit is claimed. A different Luna should review
this repair independently before any focused Julia run.
