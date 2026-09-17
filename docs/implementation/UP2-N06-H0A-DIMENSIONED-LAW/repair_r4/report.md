# N06 H0-A repair R4 static handoff

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

This archive records the narrow R4 response to
`../independent_precheck_r3/report.md`. R1, R2, and R3 review inputs and
archives remain read-only.

## F02 and F04

A public declaration-shaped overload of `n06_h0a_admit_present` now routes a
present declaration through the same trusted package/E0 validator. Tests send
stale package hash, foreign ref, component hash, axes, endpoint, and law-id
variants through both public `n06_h0a_validate(present,package,e0)` and
`n06_h0a_admit_present(present,package,e0)`. The wrong law identity test
rebuilds declaration content with the new law id while retaining an authored
law payload/source for an explicit source identity contradiction.

G2 region, interface, and boundary payload mutations are rehashed and sent
through both public paths. Calibration, closure, and law payload mutations are
also public negative controls. Missing real source payloads remain deferred.

## F03

Four role rules are derived from the actual G3 typed entry/port rows: source
uses the selected non-effort source entry, and load/return/heat use their
corresponding typed effects; expected direction comes from the joined port and
contract sign follows the role ledger convention. This is contract-only
validation and makes no physical claim. Each role coefficient and direction
has an independent public admission negative. Public unit input and output
power mutations are covered.

Closure semantics now include a structured `closure_relation` with source
closure id, account ids, and expected balance for energy and thermal domains.
The relation is joined and evaluated against actual G3 typed closure rows;
malformed and mismatched relations fail closed. The older equation text remains
provenance context rather than the sole semantic check.

## F05

Message-prefix classification was removed. Upstream status records are adapted
explicitly before projection: typed E0/package program status becomes
`program_exception`, typed contradiction becomes `fail_closed`, and explicit
source absence checks become `terminal_deferred`. An untyped upstream
`ArgumentError` is an unexpected `program_exception`; it is never promoted by
message text. Public validate/admit return `N06H0AResultV1`; fail-closed paths
carry no typed absence declaration.

## F06

The pending route preserves the exact candidate G1/G2 target ref and relies on
the typed G3 admission gap token. Zero digest and pending-profile predicates
are absent. A foreign integrated package is separately asserted to be rejected
upstream by E0. H0 public foreign coverage uses a structurally valid actual
package and a typed foreign E0 ref, yielding H0 `fail_closed` without fabricating
an integrated foreign package.

## Claim boundary

Actual A remains deferred because candidate-owned coefficient, calibration,
closure-law, and feedback authority inputs are absent. Synthetic present
construction remains schema-only. No physical, provider, mesh, engineering,
B00/B04, or R01-R10 credit is claimed. Julia and DESC were not run pending a
different Luna R4 precheck.
