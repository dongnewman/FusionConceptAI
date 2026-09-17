# UP2-01-G3-SOURCE-FEEDBACK-V1 repair R4 namespace correction

Status: `proposal`; `review_pending=true`; `accepted=false`; claim ceiling remains `contract_only`.

The independent G3 focused-R1 postrun diagnosis recorded exit `1` at `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl:22`: `UndefVarError: G3SFEndpointV1 not defined`. The production definition exists in `G3SourceFeedbackLawV1.jl`, but it is intentionally not exported. The test already binds `const G = FusionConceptAI` after `Base.include`, so the narrow repair qualifies the test's G3 namespace references through `G.`.

The repair qualifies every unqualified `G3SF*` constructor/type and every `g3_sf_*` production function used by this test, including endpoint, conservative split, heat relation, ledger relation, law, ledger entry, closure, authority, feedback target, declaration, admission, validation, evaluation, schema hash, declaration hash, and efficiency edit calls. No production export, source, fixture, or static-QA file was changed.

## Before and after hashes

Before values are the focused-R1 protected hashes:

- source: `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` / 27,969 bytes
- test: `37a66fcee910b123183df0f6c8eec568f617e5702b6e62875a4d7e6f4d5c5838` / 8,302 bytes
- fixture: `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` / 2,332 bytes
- static QA: `ff1ae5e48c83f6240a38ed1c16f39c24d141572d63e8544447313e59cb5f01f0` / 5,247 bytes

After values are recorded in `evidence_manifest.json`. Only the test hash changes; source, fixture, and static-QA hashes remain identical.

## Static checks and boundary

The explicit Python namespace scan exited `0`: zero unqualified tokens matching `G3SF*` or `g3_sf_*`; JSON/hash checks exited `0`; the source contains no new `export G3SF` and the source/fixture/static-QA hashes match the focused-R1 values. Julia and DESC were not run. The historical focused-R1 exit-1 receipt remains unchanged and is referenced as the cause for this repair. A different Luna must independently precheck this repair, after which the root serial lane may rerun the exact focused command.

`review_pending=true`, `accepted=false`; no compiler/provider/mesh/solver/physical/engineering/current-A/B00/B04/R01-R10 credit is granted.
