# N06 H0-A repair R3 independent static precheck

Verdict: `changes_requested`.

This is a read-only R3 review of the repair archive at
[`../repair_r3/report.md`](../repair_r3/report.md), performed at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The prior R2 report remains
immutable at [`../independent_precheck_r2/report.md`](../independent_precheck_r2/report.md);
the older R1 archive was intentionally left at
[`../../UP2-N06-DIMENSIONED-LAW-PREPARATION/independent_precheck_r1/report.md`](../../UP2-N06-DIMENSIONED-LAW-PREPARATION/independent_precheck_r1/report.md).
Julia and DESC were not run. The process sweep found zero matching Julia/DESC
processes. The worktree remains heavily dirty (3420 status entries); no
unrelated file was changed by this review.

## F02 — trusted package/E0 validation

The source now has a real trusted overload. `n06_h0a_validate(present,
package, e0)` rebuilds the binding, projection, four-selector endpoint set,
and law checks (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:606-618`). The
R3 tests call that overload and `n06_h0a_admit_present` for a normal deferred
actual-A case (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:214-222`). They
also mutate package hash, public ref, component hash, axes, endpoint payload,
and law version through the trusted validator (`:224-263`). This is a material
R2 improvement.

The coverage is still incomplete for the requested trusted validate/admit
contract. The stale/ref/hash/axis/endpoint variants are not sent through
`n06_h0a_admit_present`; the only admission negatives are the pending and
unreachable foreign cases. The wrong-law test changes the version to `v0` but
reuses the old content hash, so it proves schema/content rejection before a
correctly rehashed law-source identity is checked. Add public-admission
negative controls for each identity mutation and a correctly rehashed wrong
law payload/source identity, asserting a typed `fail_closed` result.

## F03 — law semantics and dynamic negative controls

`_n06_h0a_validate_law` now consumes scale, efficiency, input/output units,
calibration/closure/law payloads, role coefficients and directions, owner
scope, and energy/thermal closure rows (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:503-575`).
The endpoint checker also joins ports, accounts, entries, closures, links and
feedback, checks entry/account units, selected flow linkage, and effort-plus-
flow algebra (`:420-479`). This is source-level progress over R2.

The four-role sign/direction contract is not established. The law sign is
compared only with the first G1 occurrence (`:542`); role checks only require a
nonzero coefficient equal to the entry and a direction equal to the selected
port (`:549-566`). There is no expected sign/direction relation for each of
source/load/return/heat. The `direction=:in` test uses the same role-direction
map and `:in` is an accepted enum, so its assertion can only pass from
unrelated default owner errors; it is not an isolated direction negative
control (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:350-368`). There is no
negative public test for effort/flow unit algebra or power output units.
Define the four expected role sign/direction rules, then route one mutation for
each role and each unit equation through the public trusted admission API.

Energy and thermal rows are checked for joined account sums and expected
balances, but the closure equation is treated as an opaque string matched to a
payload. A malformed or semantically unrelated equation can therefore pass if
the text and row balances agree. Require a source-derived closure expression
or an explicit structured closure relation and test it through admission.

## F04 — G2 and law provenance

R3 correctly derives region, interface, and boundary payloads from the package
and rechecks their joins and hashes (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:383-419`).
Calibration, closure, and law source hashes are recomputed against their
supplied payloads (`:511-519`), and absent payloads remain gaps. The forged G2
boundary control is present (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:303-314`).

The provenance source path/ref itself is not authorized against an upstream
source registry; any typed provenance carrying the matching payload hash is
accepted by this layer. That is acceptable for the synthetic schema-only
fixture but cannot create a real-A law positive. More importantly for the
requested trusted contract, the G2 forgery and law semantic controls call
private helpers directly (`:303-385`), while the public trusted negative path
only mutates a G1 endpoint (`:255-263`). Add public `validate`/`admit` controls
for each region/interface/boundary payload hash and each calibration/closure/
law payload hash. Keep actual A deferred until an independently authorized
source is available.

## F05 — typed upstream outcomes

The public admission method catches and returns a typed result envelope, and
the source distinguishes `N06H0AKnownGapError`, `N06H0AConflictError`, and
`N06H0AProgramError` (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:577-647`).
However, `ArgumentError` classification still depends on `sprint(showerror, e)`
prefixes (`:577-594`). The R3 taxonomy tests invoke the private translator
directly with fabricated messages (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:397-410`);
they do not force a known upstream conflict or unexpected exception through
`n06_h0a_validate(..., package, e0)` or `n06_h0a_admit_present`. Replace the
message table with typed upstream error/status adapters where possible, and
exercise known gap, contradiction, and unexpected exception through both
public paths. Assert no raw upstream exception escapes and that fail-closed
results never use a typed absence declaration for contradictions.

## F06 — pending versus foreign G3 feedback

The source now requires exact candidate G1/G2 reference equality and separately
looks for the source-derived G3 admission gap token (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:481-500`). The ordinary actual-A builder has a
plausible pending route because the G3 binding emits
`feedback_authority_gap:<id>:<layer>` (`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:90`),
while integration deliberately omits that token from the package-level gap
list (`src/GenomeV5/Integration/GenomeV5Integration.jl:250-265`).

The R3 controls do not yet prove the requested separation:

* The `pending_ref` mutation changes the target digest/profile, so it fails
  the exact-ref test and is classified `foreign`; the assertion still expects
  an `external_ref_required` gap (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:284-298`).
  A pending control must preserve the exact candidate target ref and vary only
  the typed external-authority gap.
* `_h0a_actual_package_foreign_feedback` creates an integration package with a
  foreign target. Integration records `feedback_target_ref_mismatch` and
  marks it `structural_status=:fail_closed` (`src/GenomeV5/Integration/GenomeV5Integration.jl:211,316-340`).
  `up2_candidate_physical_binding_from_a` rejects that package before H0-A can
  run (`src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:329-346`), so the
  test stops at `foreign_e0 = ...` (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:200-207`).
  Construct a structurally valid H0-A test package with an independently
  mutated feedback authority envelope, or assert the upstream rejection in a
  separate integration test and use a valid typed H0-A input for the public
  foreign classification.

## Claim ceiling and disposition

The fixture remains explicitly synthetic/schema-only and `actual_a_positive`
is false. No physical positive, provider, mesh, engineering, B00, B04, or R01-R10
credit is granted. Because F02/F03/F04/F05 public negative coverage is still
incomplete and F06 contains statically unreachable/incorrect controls, the
result is `changes_requested`, not `ready_for_serial_focused`.

