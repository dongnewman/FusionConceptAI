# UP1 R3 vector harness repair R1

This package repairs the offline mutation-vector harness only. R01 and R23
remain end-to-end `validate_bundle` parser/schema checks. R02-R22, R24-R25 and
D01 invoke the production semantic predicate owning the mutation and the
production `_result` decision layer. The wire bundle is not used as an
accepted baseline because its raw digest and quarantine receipt are
self-referential.

`vector-receipt.json` is the machine receipt for all 26 vectors. Every row
contains `vector_id`, `path`, `input_hash`, `called_function`, `actual_code`,
and `actual_decision`; R22/R24/R25 use the explicit `no_failure_code` marker
for a clean deferred/internal-acceptance-shaped result.

The result is strictly `prototype_pass_limited`: `formal_credit=none`,
`authority_credit=false`, and `no_publish=true`. No production tools,
external authority, network, AD/S3, Julia/DESC, solver, credentials, or
publication lane was used.
