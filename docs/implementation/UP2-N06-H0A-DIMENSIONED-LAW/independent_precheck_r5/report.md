# N06 H0-A repair R5 independent static precheck

Verdict: `changes_requested`.

This read-only review covers repair R5 at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. R4 remains immutable at
[`../independent_precheck_r4/report.md`](../independent_precheck_r4/report.md).
The current source, tests, fixture, and runner hashes match the supplied R5
identity. Julia and DESC were not run; the process sweep found zero matching
processes. The worktree has 3468 status entries, and this review writes only
the R5 precheck archive.

## F05 — malformed Any payloads and typed exception boundary

R5 places endpoint and law semantic traversal inside typed catches in the
trusted validator (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:689-715`).
The law helper now rejects nonnumeric calibration scale/efficiency, nontext
closure equation, non-tuple closure account ids, and nonnumeric closure
balances with `N06H0AProgramError` before conversion (`:552-592`). The new
malformed calibration declaration is sent through both public
`n06_h0a_validate(declaration, package, e0)` and declaration-shaped
`n06_h0a_admit_present`, and both assertions require
`program_exception` with `declaration === nothing`
(`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:551-567`). This closes the
R4 raw-conversion escape for the exercised calibration shape.

The requested closure half of the contract is not dynamically covered. The
existing malformed closure control uses `closure_relation=(energy="malformed", thermal=())`
and expects `fail_closed` (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:412-419`);
it does not send a malformed `closure_payload` such as a nontext `equation`,
or a nonnumeric/invalid closure payload field, through both public paths and
assert `program_exception`. Add one correctly rehashed malformed closure
payload for public trusted `validate` and `admit`.

The status mapping itself remains message-free: typed preflight statuses are
converted to known gap, conflict, or program exception, while untyped upstream
exceptions become `N06H0AProgramError` (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:644-671`).
The public known-gap route is exercised as `terminal_deferred`, and the public
foreign-E0 route is exercised as `fail_closed`
(`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:539-549`). However, the
conflict assertion does not require `contradiction_public.declaration === nothing`.
Add that assertion alongside the existing program-exception assertion so the
fail-closed envelope cannot carry a typed absence.

## F02/F03/F04/F06 regression check

No static regression was found in the repaired areas:

* F02 still sends stale package/ref/component/axis/endpoint and correctly
  rehashed wrong-law identity mutations through both public trusted routes
  (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:224-292`).
* F03 still joins structured energy/thermal closure relations to G3 rows and
  checks four-role coefficient/sign/direction contracts, with public role,
  closure, input-unit, and output-power negatives (`:322-476`; source
  `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:523-625`).
* F04 still recomputes G2 region/interface/boundary and law payload hashes;
  forged G2 and calibration/closure/law payload declarations reach both
  public routes (`:322-430`). Source provenance remains locally typed and
  payload-hash based; it grants no actual-A authority.
* F06 still keeps pending exact candidate refs plus the typed G3 admission gap
  separate from upstream foreign integrated-package rejection and valid-package
  foreign E0 contradiction (`:187-213,303-320`). Actual A remains deferred.

## Static API and claim boundary

The new `N06H0AProgramError` branches and `closure_relation` keyword are
internally consistent by source inspection; no additional Julia constructor or
method error was identified. This is not a runtime result. The fixture remains
synthetic/schema-only, actual A remains `terminal_deferred`, and no physical,
provider, mesh, engineering, B00, B04, or R01-R10 credit is granted.

Because malformed closure payload reachability and fail-closed declaration
emptiness are still unasserted, the R5 disposition is `changes_requested`, not
`ready_for_serial_focused`.

