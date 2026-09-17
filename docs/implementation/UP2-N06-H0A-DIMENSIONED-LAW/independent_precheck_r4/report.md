# N06 H0-A repair R4 independent static precheck

Verdict: `changes_requested`.

This read-only review covers repair R4 at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The prior R3 review remains
immutable at [`../independent_precheck_r3/report.md`](../independent_precheck_r3/report.md).
The source, tests, fixture, and runner hashes match the R4 archive. Julia and
DESC were not run; the process sweep found zero matching processes. The dirty
worktree has 3442 status entries, and this review writes only this R4 archive.

## F02 — trusted identity and source-law rejection

R4 adds the declaration-shaped `n06_h0a_admit_present(declaration, package,
e0)` route and sends stale package, foreign ref, component hash, axes, endpoint,
law-version, and correctly rehashed foreign law identity through both public
`validate` and `admit` (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:224-292`).
The trusted implementation rebuilds package/E0 identity, projection, endpoint
set, and law checks (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:672-687,689-735`).
The R3 F02 gap is materially closed. These are still static conclusions until
the focused Julia runner is executed.

## F03 — structured closure and four-role contract

R4 adds a structured `closure_relation` and joins each energy/thermal relation
to the actual G3 closure id, account ids, and expected balance
(`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:560-585`). It also derives
role direction from the actual typed port and the contract sign from the role
ledger convention, then checks coefficient, role sign, contract direction, and
declared direction for source/load/return/heat (`:507-521,600-625`). Public
negative declarations cover malformed/mismatched closure, role coefficient and
direction, input units, and output power units (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:394-476`).

The source still accepts arbitrary `closure_equation` text when it matches the
payload; the structured relation supplies the actual row semantics, so this is
context rather than the only closure check. The role signs are a local typed
contract convention, not a physics result, and no physical positive is claimed.
No static Julia syntax error or constructor arity problem was found in the new
`closure_relation` keyword path by source inspection.

## F04 — G2 and law payload provenance

G2 region, interface, and boundary payloads are rejoined to the package and
rehashed by the trusted endpoint checker (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:383-419`).
R4 sends forged region/interface/boundary declarations through both public
trusted routes (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:322-351`).
Calibration, closure, and law payload mutations likewise reach both routes
(`:394-430`), including a correctly rehashed law declaration whose payload law
id disagrees with the requested law id (`:274-292`). Missing real source
payloads still produce typed deferred outcomes.

The remaining boundary is provenance authority: the implementation verifies a
typed source record's hash against its supplied payload, but does not consult
an independent source registry or validate the source path/ref beyond the
locally generated typed record (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:511-519`).
That cannot promote actual A and is consistent with the stated synthetic-only
claim ceiling, but it must be resolved before any source-backed positive.

## F05 — upstream status typing and public exception boundary

R4 removes message-prefix classification. `_n06_h0a_source_preflight` maps
typed package/E0 statuses and explicit source absence to conflict, program,
or known-gap exceptions before projection (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:635-671`).
An untyped upstream exception becomes `N06H0AProgramError` without using its
message to choose the category. Public admission catches and returns typed
`N06H0AResultV1`; tests cover public known-gap and conflict results
(`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:531-547`).

F05 remains incomplete. The public program-exception path is not dynamically
tested: the test only calls the private translator with an unexpected
`ArgumentError` (`:522-536`), while `n06_h0a_bind_actual_a(nothing,nothing)`
exercises a fallback overload rather than an upstream exception. Add a typed
malformed-source/program fixture and assert `program_exception` through both
trusted public `validate` and `admit`, with no raw exception escaping.

There is also a concrete exception-boundary risk in trusted `validate`: after
the projection/endpoint try blocks, it calls `_n06_h0a_validate_law` directly
(`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:681-684`). That helper accepts
`Any` payloads and performs unguarded conversions such as
`Rational{Int64}(cscale)` and `Tuple(ids)` (`:552-558,570-585`). A malformed
typed declaration can therefore throw from `n06_h0a_validate(declaration,
package,e0)` instead of returning `program_exception`; the declaration-shaped
admit overload catches this only because it wraps the validator. Put semantic
validation inside the same typed catch or validate payload shapes before
conversion, and add a public validate malformed-payload control.

## F06 — pending exact ref and upstream foreign E0 rejection

The pending actual-A route now preserves the exact candidate G1/G2 target ref
and relies on the typed G3 admission gap token; the test checks the public bind
and admit results (`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:187-199,303-318`).
The foreign integrated package is separately expected to be rejected by E0,
while a valid package with a foreign E0 ref is sent through H0 admission and
must fail closed (`:201-213`). This cleanly separates upstream structural
rejection from H0's typed E0 identity contradiction. No foreign integrated
package is incorrectly presented as a valid H0 input.

## Claim ceiling and disposition

The fixture remains synthetic/schema-only and `actual_a_positive` remains
false. Actual A remains `terminal_deferred`. No physical, provider, mesh,
engineering, B00, B04, or R01-R10 credit is granted. Because F05 lacks public
program-exception dynamic coverage and trusted `validate` can expose malformed
`Any` payload exceptions, the result is `changes_requested`, not
`ready_for_serial_focused`.

