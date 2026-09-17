# N06 H0-A repair R6 independent static precheck

Verdict: `ready_for_serial_focused`.

This read-only review covers repair R6 at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The prior R5 review remains
immutable at [`../independent_precheck_r5/report.md`](../independent_precheck_r5/report.md).
The current source, tests, fixture, and runner hashes match the supplied R6
identity. Julia and DESC were not run; the process sweep found zero matching
processes. The worktree has 3483 status entries, and this review writes only
the R6 precheck archive.

## F05 closure payload and result taxonomy

The R6 test adds a correctly rehashed malformed closure payload whose
`equation` field is a nontext tuple (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:570-585`).
That declaration is sent through both public trusted routes:
`n06_h0a_validate(present, package, e0)` and declaration-shaped
`n06_h0a_admit_present(present, package, e0)`. Both require
`program_exception` and `declaration === nothing`. The calibration malformed
payload has the same two-route assertions (`:551-567`). The source wraps both
endpoint and law semantic traversals in typed catches and rejects malformed
payload shapes before conversion (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:552-592,689-715`).
No raw conversion exception is left exposed on these exercised paths.

The public conflict control now explicitly requires
`contradiction_public.declaration === nothing` (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:545-550`).
The actual-A and pending routes retain typed `terminal_deferred` absences, and
the malformed structured `closure_relation` control remains `fail_closed`
(`:187-199,412-419`). These categories are statically separated as required.
The preflight mapping remains typed and message-free for classification
(`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:644-671`).

## F02/F03/F04/F06 regression check

No static regression was found:

* F02 still sends stale package/ref/component/axis/endpoint and correctly
  rehashed wrong-law identity mutations through both public trusted routes
  (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:224-292`).
* F03 still validates structured energy/thermal closure relations against G3
  rows and checks four-role coefficient/sign/direction contracts, with public
  role, closure, input-unit, and output-power negatives
  (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:523-625`; tests `:322-476`).
* F04 still recomputes G2 region/interface/boundary and law payload hashes;
  forged G2 and calibration/closure/law declarations reach both public paths
  (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:322-430`). Typed local
  provenance remains contract evidence only.
* F06 still separates pending exact candidate refs plus the typed G3 admission
  gap from upstream foreign integrated-package rejection and valid-package
  foreign E0 contradiction (`:187-213,303-320`).

Actual A remains deferred because candidate-owned law, calibration, closure,
and feedback-authority inputs are absent. The fixture remains synthetic and
schema-only. No physical, provider, mesh, engineering, B00, B04, or R01-R10
credit is granted.

## Disposition

The static R5 blocking items are closed: both malformed calibration and closure
payloads are publicly exercised as typed `program_exception` with no
declaration, and the public fail-closed conflict is explicitly declaration
empty. The package is ready for the serial focused runtime lane only. This is
not a runtime pass or a physics/readiness claim.

