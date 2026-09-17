# G-I1B-A narrow repair R4

Status remains `review_pending`; `accepted=false`. This repair answers the
three P1 findings in `independent_precheck_r3/report.md`. It is limited to the
owned G-I1B source, focused tests, and this `repair_r4/` directory. No Julia,
DESC, compiler, provider, solver, mesh, or physical process was started.

Both E1-present/E2-absent and E1/E2-absent returned envelopes now have
envelope-level zero compile/provider/solver assertions in addition to the
row-level checks. The test builds an independent attempted-value manifest
from each independently extracted actual source value and the frozen row
mutation semantics. It independently recomputes original and attempted
value hashes and the canonical mutation payload/hash, including the verified
source binding, error code/path, and resolution; production `_gi1b_attempt`,
`_gi1b_hash_typed`, and mutation assembly helpers are not used to derive that
manifest.

The production path now separates row construction from pure envelope
assembly through `_gi1b_build_rows` and `_gi1b_assemble_envelope`. The public
factory accepts an explicit `row_builder` seam for a controlled source/accessor
failure. The focused test uses it to raise one `GI1ProgramException` while
ordinary N10 rows remain `fail_closed`, then verifies the returned factory
status and both exact error entries, row/aggregate counters, and program
exception path. A separate direct malformed-context case continues to verify
the unavailable layer identity used when source identity lookup itself fails.
This is a contract-level negative control only; it does not invoke any
downstream tool or grant authority.

N05 E1 absence, N06 dimensioned authority, N09 provider, and N10 legacy
provenance gaps remain explicit. R3 evidence is unchanged. The R4 pre-edit
freeze and final owned hashes are in `owned_hashes.json`; static receipts are
in `static_qa.json`.
