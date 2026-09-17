# N06 H0-A independent static precheck R1

Verdict: `changes_requested`.

This is an independent read-only static review of the H0-A additive files at
HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. No Julia or DESC command was
run by this review, and the final process sweep found no Julia/DESC process.
The four H0-A author files match the requested SHA256 values. The review did
not modify source, tests, existing archives, core files, or unrelated dirty
files.

The implementation is correctly scoped as additive and its archive keeps the
contract-only and `accepted=false` ceiling. It is not ready for a serial
focused runtime because the source-bound actual-A path has a deterministic
occurrence-resolution defect, and the present declaration validator accepts
synthetic foreign or dimensionally meaningless values as `declared_consistent`.

## Blocking findings

### F-01 — actual-A four-occurrence binding cannot be built

`N06DimensionedLedgerLawV1.jl:262-276` selects only the equation whose id is
`projection.g1_equation_id` (`governing-0`), then iterates every key in
`projection.g1_occurrence_keys`. The projection constructs that tuple from all
G1 equations at `N06SourceFieldLedgerMappingV1.jl:431-433`. The actual A G1
fixture has one occurrence in `governing-0`, one in `source-0`, and two in
`constraint-0` (`test/GenomeV5/G1/fixtures.json:32-35`). Therefore the second
lookup is guaranteed to fail with `H0-A G1 occurrence missing`; the catch at
`N06DimensionedLedgerLawV1.jl:353-360` returns a `source_binding_missing`
typed absence before the declared dimensioned-law gap is reached. The test
expects `dimensioned_law_missing` at
`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:135-145`, so the focused test
is statically inconsistent with the implementation.

Fix: resolve each of the four exact selectors against the complete equation
collection, attach its actual equation and closure, and assert the expected
four-role selector set. A valid actual-A package should return an endpoint set
and then produce the intended `dimensioned_law_missing` / `terminal_deferred`
result when no authored law exists. Duplicate or conflicting source rows must
remain `fail_closed`.

### F-02 — present declarations are self-consistent hashes, not source-bound validation

`n06_h0a_validate(::N06H0APresentV1)` at
`N06DimensionedLedgerLawV1.jl:229-238` checks only schema,
canonicalization, profile, and recomputed content hash. It never compares the
declaration with a `CandidateStatePackageV5`, E0 binding, actual refs, package
hash, component hashes, axes, or source values. The input-binding constructor
at `:52-68` only checks v5/URI/profile presence and that `g1/g2/g3` axis fields
exist. A caller can therefore rehash foreign refs, stale component hashes, or
arbitrary axes and obtain `declared_consistent`.

Fix: add a package/E0-bound validation path that recomputes every identity
field and source endpoint from the actual package. Keep the low-level
constructor explicitly schema-only, or mark its result as synthetic so it
cannot be confused with source-backed admission.

### F-03 — endpoint and law semantics are presence-only

`N06H0AEndpointSetV1` at `:75-89` checks cardinality and a few field names but
does not require a coefficient, typed selector shape, source locator/hash,
G2 interface consistency, or typed G3 rows. Empty G3 ports/accounts/entries/
closures/links/feedback are accepted. `N06H0AUnitEquationV1` at `:106-127`
checks unit object types and nonempty strings, but does not verify the unit
equation, variable-to-unit relation, scale, efficiency, calibration source,
direction/sign against endpoint direction, or closure/owner relation. The
synthetic test deliberately supplies all-dimensionless units and empty G3
views (`n06_dimensioned_law_tests.jl:23-38`) and then accepts the declaration
as consistent (`:101-117`). This is schema-only evidence, not a semantic
positive.

Fix: require the exact typed endpoint payload and source locators/hashes,
validate dimensional algebra and scale/efficiency/calibration provenance, and
cross-check sign, direction, owner accounts, energy/thermal closure equations,
and expected balances against G3. Keep an explicit schema-validation-only
fixture separate from any source-backed result.

### F-04 — source provenance is not represented at endpoint/law granularity

The H0-A endpoint tuples carry IDs and values but no per-row source ref, hash,
path, or source type. `calibration_provenance` is only a nonempty free-form
string (`N06DimensionedLedgerLawV1.jl:93-127`), and `law_id` is a URI/version
without a source content hash. AD-27 requires exact G1 operator/equation/
occurrence, G2 region/interface/boundary, and G3 port/account/entry/closure/
link/feedback endpoints with candidate-bound provenance. The current content
hash protects the declaration text but cannot prove where a coefficient or
calibration came from.

Fix: add typed source locators and source hashes for each endpoint, coefficient,
unit law, calibration record, and closure relation; include them in the law
content identity and independently recompute them from the actual package.

### F-05 — exception classification is heuristic and internally inconsistent

`_n06_h0a_classify_error` at `N06DimensionedLedgerLawV1.jl:314-320` routes by
substring (`"missing"`, `"authority"`) rather than typed error/code. The catch
at `:353-360` maps both terminal-deferred and fail-closed source errors to a
`source_binding_missing` absence. A fail-closed result therefore carries a
typed-absent declaration which `n06_h0a_validate` maps back to
`terminal_deferred` at `:241-249`. Unexpected exceptions whose message happens
to contain `authority` or `missing` can also be misclassified.

Fix: use explicit typed error categories or stable error codes. Return a
typed-absent declaration only for a known missing-authority case; return
`fail_closed` without a deferred absence for typed contradictions; preserve
all unexpected exceptions as `program_exception`.

### F-06 — direction, sign, owner scope, closure, and feedback are not joined

The law constructor only limits direction to three symbols and sign to +/-1
(`N06DimensionedLedgerLawV1.jl:117-124`). It does not compare those values to
G3 port direction, G1 coefficients, account/entry signs, closure expected
balances, or owner account scope. The actual binder copies G3 feedback rows at
`:302-310`, including `external_ref_required` rows with null authority fields
from `test/GenomeV5/G3/fixtures.json:105-107`, without a fail-closed or
typed-deferred decision. This leaves the requested conservation and feedback
authority unverified.

Fix: make each role's direction/sign and closure equation source-derived and
validate all account/entry/port/link/feedback joins. Treat missing external
feedback authority as a separate `terminal_deferred` gap and contradictory
typed feedback as `fail_closed`.

## Boundary and evidence decision

The reviewed architecture documents and AD-24/AD-26/AD-27 correctly keep the
physical law, provider, mesh, engineering, B00/B04, and R01-R10 claims open.
The H0-A archive also correctly says `accepted=false` and `runtime=not_run`.
Those ceilings are preserved by this review. The synthetic fixture is useful
as a construction-shape control, but its current `declared_consistent` result
must not be used as actual-A evidence.

Required next action is to fix F-01 through F-05 before serial focused
execution; F-06 must be closed before any source-backed or conservation claim.
After the fixes, run the focused H0-A test under the authorized serial lane,
retain stdout/stderr/exit and a postflight zero-process sweep, then request a
fresh independent H1 review. This precheck grants no implementation, provider,
mesh, engineering, physical, B00/B04, or R01-R10 credit.

