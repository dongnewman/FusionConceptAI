# AD-22 independent review

## Verdict

`pass_limited` for the AD-22 architecture decision only. The author archive remains `review_pending`/`accepted=false` until Sol integrates this independent review. This review grants no UP2 implementation, B04, provider, engineering, physical, or R01-R10 credit.

## Scope and frozen inputs

The reviewed core section is `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md:149-161` (AD-22). Its before/after relation is independently represented by the author metadata: before SHA256 `54dc500fce9d8ec2c2c9d10a939300ea2422fa7e7752b7b76ee1a15ee2faeb5e`, after SHA256 `fc191125bbcc72accc168a20568b13f6d2401ab9ce58e85da725fa54f08583e8`, bounded diff exit `1` as expected. The author acceptance/evidence hashes are `c177870b40c701867253edd6823e96e3c757b8b756961f6a31c40c17cd05f360` and `17d5d2d3db4b5b0b64e6672912bd9f334a2bd46c37ffe9f8c5bfe122d66f921e`.

The required current inputs and source hashes are sealed in `before_hashes.json`. No file outside this independent-review directory was written. N09-owned Julia processes were present during the read-only audit; no Julia or DESC command was started.

## Contract review

AD-22 correctly preserves the 19/protocol distinction: N03 and N04 rows remain `illustrative_contract_mutations_pending_schema_binding`, while the current UP2 rows at `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:29-40` are explicitly provisional candidate-bound locators. It requires later real source fields, mutation values, derived classification, and invocation receipts, so it neither deletes obligations nor promotes labels to executable evidence.

The G1 temporal claim is accurately local and source-backed. `src/GenomeV5/G1/MechanismGenomePayloadV2.jl:83-95` performs candidate-owned operator lookup and checks temporal kind, derivative order, typed expression, and effects; lines 135-147 bind temporal and derivative fields to states; lines 156-184 cover occurrence, closure ledger, and balance. AD-22 correctly says these checks do not define a G3 event time basis.

The G3 event claim is accurately limited to intrinsic typing and range: `src/GenomeV5/G3/RealizationGenomeV5.jl:306-315` restricts trigger/action enums and nonnegative exact rational time. There is no equation-time-basis join in this code, so the decision correctly keeps cross-layer scheduled/event mismatch `terminal_deferred` until an independent candidate-bound policy exists. Intrinsic enum/range failures can remain `fail_closed`.

The G3 ledger description is also accurate. `RealizationGenomeV5.jl:435-449` validates nonempty unique closure accounts; lines 467-488 validate typed unique network IDs; lines 504-565 validate local references, units, capacities, required resource kinds, closure membership, domains, and balances. The profile text’s `owner_uniqueness` at lines 132-140 is not an executable cross-account policy, and `test/GenomeV5/G3/up1_g3_contract_tests.jl:245-252` is a concrete legal counterexample: two accounts may share an owner string and still admit structurally. AD-22 therefore correctly refuses to classify owner-string equality as double counting.

The missing G1 occurrence `ledger_id` to G3 account/entry/energy-boundary exact join is explicitly retained as an authority gap. This is the necessary boundary: G1 closure checks and G3 local balance checks cannot substitute for provenance across layers. The proposed additive, versioned, content-hashed N03 time authority and N04 account-closure authority, with exact same-candidate refs, axes, source locators, values, and schema/canonical/profile hashes, is minimal and consistent with 00/19/AD-20. Structural type/enum errors remain `fail_closed`; missing authority remains `terminal_deferred`.

## Remaining boundary

AD-22 is an architecture decision, not N03/N04 implementation. It does not create executable JSON pointers, does not accept the current provisional rows, does not alter the DAG or task status, and does not shrink R01-R10. The 10 N03/N04 obligations remain pending until separate UP2 files bind them to real fields and receipts. A formal B04 run must still occur only after schema freeze and candidate-bound receipt design.
