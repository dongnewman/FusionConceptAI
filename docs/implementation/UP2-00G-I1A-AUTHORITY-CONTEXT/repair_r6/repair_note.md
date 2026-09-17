# G-I1A repair r6: exact G1 contract-ref API

Status: `review_pending`; `accepted=false`; no Julia/DESC run in this repair.

The preserved focused r1 receipt (`focused_r1/process_r2.json`, real exit 1) reports a `program_exception` before the G-I1A assertions: `G1GenomeContractRef` was referenced at `gi1_authority_context_tests.jl:22`, but the loaded G1 module exposes the real typed constructor `G1GenomeContractRefV2` (with `GenomeContractRefV2` as its alias). The test's constructor arguments already match the V2 constructor, so this is a one-token test-only API correction. A scan of the owned test and runner found no second stale `G1GenomeContractRef` reference.

Only `test/GenomeV5/UP2/gi1_authority_context_tests.jl` changed. Source, fixture and runner bytes are preserved. The original r1 raw stdout/stderr/process/receipt remain immutable and continue to classify the prior attempt as `program_exception`, not a pass or physical result. No B00/B04/provider/mesh/engineering/physical/R01–R10 credit is claimed.

The corrected test has not been executed. A different Luna static precheck is required before any new focused runtime is scheduled.
