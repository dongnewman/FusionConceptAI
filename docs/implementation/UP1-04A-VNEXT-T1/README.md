# UP1-04A VNext T1 local-contract focused lane

This additive lane implements the local T1 admission test surface over the
existing T0 transport and local authority recheck. It is intentionally
definition-only until a separate, serialized runtime execution is authorized.

## Frozen boundary

The focused test constructs real source-backed G1/G2/G3 local records through
the existing transport helper, performs the local authority recheck, and then
calls `vnext_t1_admit_skeleton_v1`. The present path must produce a closed
`CandidateStatePackageV5Next` projection with `component_count=3`, sorted and
unique feedback IDs, candidate/source/declaration/body/locator/receipt joins,
immutable owned bytes, label-erased semantic identity, and a zero-reference
`VNextT1NoLegacyReceiptV1`.

Typed-absent T0 input, missing T0 inputs, foreign candidate/receipt identity,
invalid transport state, feedback reorder/duplication, and bundle-hash drift
must produce no package. The package status remains
`prepared_not_executed`, `terminal_deferred`, `accepted=false`,
`claim_ceiling=contract_only`; this lane gives no T2, UP2, R01-R10, provider,
mesh, solver, physical, engineering, or authority credit.

Locator provenance is first established and checked by the T0 local authority
recheck against the repository/source receipt. T1 does not replace that
provenance check: it rechecks the candidate/source-ref, source size and source
hash joins, plus the typed locator fields retained in the package.

## Files and static command

The additive test and fixture are:

* `test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl`
* `test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_fixture.json`
* `test/GenomeV5/Integration/static_qa_vnext_t1_candidate_state_package_v5_next.py`
* `test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_oracle.py`

Run only the no-cache static check during preflight:

```text
python -B test/GenomeV5/Integration/static_qa_vnext_t1_candidate_state_package_v5_next.py
```

Julia execution is deliberately not part of this handoff. A future runtime
lane must serialize the command, capture stdout/stderr/exit status and process
snapshots, independently review the receipt, and retain the status ceiling.
