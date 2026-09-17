# G-I1B-A narrow repair R2

Status remains `review_pending`; `accepted=false`. This repair answers the
four blocking findings in `independent_precheck_r1/report.md`. It is limited
to the owned G-I1B source, focused test, runner/fixture contract, and this
`repair_r2/` directory. No Julia, DESC, compiler, provider, solver, mesh, or
physical process was started.

The R2 freeze was taken at `main` HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2` with 294 pre-existing dirty-status
lines; the freeze metadata and owned file hashes are recorded in
`owned_hashes.json`.

The focused test now constructs an actual `CandidateStatePackageV5` from the
UP1-04 child fixtures, derives the actual E0 binding and G-I1A context, builds
an authored E1/N05 declaration for the E1-present branch, and exercises the
factory for both E1-present/E2-absent and E1-absent/E2-absent contexts. Each
branch checks all 50 unique rows, source locators and declared source types,
typed original/attempted hashes, candidate/package/version axes, source
identity, mutation hashes, and zero downstream counters. A forged source type
boundary is checked as `fail_closed`; the fixture remains oracle-only. N05
rows in the absent branch use a typed `GI1BAbsentSourceIdentityV1` carrying
the actual E1 absence slot content/schema/canonicalization/profile hashes and
do not fall back to a G3 outer identity.

The aggregate envelope status now has explicit precedence
`program_exception > fail_closed > terminal_deferred > declared_consistent`,
and errors retain both `fail_closed` and `program_exception` row paths. The
source accessor checks the actual Julia value type and fixed tuple shapes
against `source_type`; a mismatch becomes `fail_closed` with
`invalid_type`. Trusted-context checking passes the actual E1/E2 authorities
when present so the E1-present factory path validates against the same A
context it reads.

The 50-row matrix is unchanged. N06, N09, and N10 authority/provenance gaps
remain explicit and no missing authority is promoted to a positive result.
The frozen pre-edit owned hashes were source
`a3e1256e20a31ccc686835a303e6d7b12d098f43fb9f5901e4f37facad9c797c`, fixture
`23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6`, tests
`1295225e8d5ce1e8712198487a9f1a3d517060545cf10b0d61dc0ea9a107f63c`, and
runner `54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5`.
Final R2 hashes and static receipts are in `owned_hashes.json` and
`static_qa.json`.
