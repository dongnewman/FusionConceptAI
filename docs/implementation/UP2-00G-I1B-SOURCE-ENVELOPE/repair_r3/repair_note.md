# G-I1B-A narrow repair R3

Status remains `review_pending`; `accepted=false`. This repair answers the
five findings in `independent_precheck_r2/report.md`. It is limited to the
owned G-I1B source, focused tests, and this `repair_r3/` directory. No Julia,
DESC, compiler, provider, solver, mesh, or physical process was started.

The focused row helper now parses leading-slash locators with empty tokens
removed and asserts the resulting layer before accessing envelope refs. The
factory's 50 rows are compared against an independent test-only expected
manifest built by direct reads from the actual package, E1 declaration, and
absence slot. This manifest does not call `_gi1b_actual_value`,
`_gi1b_typed`, or production hash helpers for extraction; every row in both
factory branches must equal its independently read source value before the
hash assertion is evaluated.

The E1-present factory result now has dynamic row assertions for all N06,
N09, and N10 classifications, gap text, error codes, and aggregate status.
A controlled direct exception-row case verifies `program_exception`, its
field path, zero downstream counters, aggregate precedence, and a typed
`GI1BUnavailableSourceIdentityV1` carrying the correct G2 layer and marker
hash. `_gi1b_exception_row` no longer falls back to the G1 ref/hash when
source identity lookup fails. E1-absent N05 checks now include
`profile_hash` in addition to content/schema/canonicalization/compatibility
identity hashes and row source hash.

The R3 pre-edit freeze is recorded in `owned_hashes.json`; R1/R2 reports and
archives are unchanged. The current work remains static evidence only and
does not promote authority, B00, B04, provider, mesh, engineering, physical,
or parent-goal status.
