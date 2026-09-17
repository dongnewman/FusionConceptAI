# E2-N06 independent static precheck R2

Verdict: `changes_requested`.

This is an independent read-only review by a Luna different from the implementation author. Julia and DESC were not run. The R2 source, fixture, test, and runner hashes are frozen in `input_hashes.json` and match the author R3 repair freeze.

## R1 closure checks

- Dynamic G1/G2/G3 cardinality and paths are materially improved. `_n06_unique_index`, `_n06_unique_match`, `_n06_resolve`, and `_n06_index_for` at `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:229-262` reject missing, duplicate, or ambiguous matches. G3 port, entry, account, closure, and link IDs are checked at `:306-310`; join maps are rebuilt with the same checks at `:383-386`.
- Mutation `field_path`, `source_locator`, and `source_type` are now checked against the projection field at `:502-510` before classification. Dynamic path parsing and bounds checks are present at `:534-578`. The fixture-driven tests exercise forged locator/type and reordered-network controls at `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:222-252`.
- The R3 semantic hash repair is present in current source: `semantic_view(::N06InvocationCounterV1)` is at `:183-185`, and conversion `law_hash` is included at `:204`. The old R3 missing-method receipt remains historical and no new Julia receipt is claimed here.

## Remaining blocker

1. `power_from_effort_flow` is not enforced by executable source invariants. The law text at `:31-37` says it requires typed effort and flow sources, but `_n06_join_errors` at `:421-448` only permits the `:source` role kind from `(:effort, :flow)` and applies no check that both typed kinds are present across the four joins. The actual field selection at `:311-314` chooses one effort port and one entry; `_n06_actual_fields` does not select or retain a flow counterpart. A mapping with only an effort source role and no flow source can therefore satisfy the current role set, endpoint units, local law hash, and zero-offset rule while the declared power law is not established. The fixture has no negative control for missing flow authority. This must be a known `terminal_deferred` gap or a candidate-bound exact typed effort/flow rule; it cannot be accepted as a dimensioned source-to-power proof.

2. Link selection remains too weakly bound. `_n06_actual_fields` at `:317-319` selects any link whose resource port exists, rather than a unique link for the selected effort port. The field path at `:333-335` can consequently describe a different valid port link than the port selected at `:311-314`; the current tests only check reordered resource-port paths, not link-to-selected-port identity. Bind the selected link to the selected port or mark the selection ambiguous and fail closed.

3. G1 occurrence and G2 region/patch are still helper-only values. `_n06_actual_fields` returns them at `:341`, but `N06LedgerProjectionV1` stores only the five G3 fields at `:131-142`; G1/G2 values enter authored joins later through test-built data. The current test helper at `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:76-112` constructs those joins from fixture-selected values. The three cross-layer gaps remain correctly terminal_deferred, so this is not physical evidence; however, the implementation cannot claim an exact source-to-field-to-return/heat ledger mapping until the authority is an explicit candidate-bound input.

4. The conversion law hash is a deterministic digest of the local constant at `:31-40`, and the constructor fills it when omitted at `:79-83`. This proves internal consistency of the local contract text, not an external authoritative law/source. Keep the accepted ceiling contract-only and require a future content-addressed authority if the law is to close a cross-layer or physical claim.

## State boundary and historical runs

Missing G1 occurrence to G2 boundary, source/field to G3 return/heat/ledger, owner scope, and absent power-law authority remain `terminal_deferred`. Present typed contradictions, wrong refs, bad units, duplicate IDs, bad closure values, and invalid paths are `fail_closed`. Unexpected exceptions remain `program_exception`. R1/R2/R3 author exits are preserved as independent program-exception history and are not physical results. No focused independent Julia run was performed for R2.

Claim ceiling: `contract_only`; no formal B04, provider, mesh, engineering, physical, or R01-R10 credit. Required before R4: enforce or explicitly defer the effort+flow authority, bind link selection to the selected port, and represent or explicitly gate candidate-bound G1/G2 source authority.
