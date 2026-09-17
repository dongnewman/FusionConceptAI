# N06 H0-A repair R2 independent static precheck

Verdict: `changes_requested`.

This review covers the repair R2 source, fixture, test, runner, and archive at
HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. It is a read-only review by a
different Luna. Julia and DESC were not run; the process sweep was zero. The
previous R1 review remains untouched at
[`UP2-N06-DIMENSIONED-LAW-PREPARATION/independent_precheck_r1/report.md`](../../UP2-N06-DIMENSIONED-LAW-PREPARATION/independent_precheck_r1/report.md).

The R2 repair fixes F01 materially: the actual-A builder now resolves the four
authored selectors across all G1 equations and can reach the intended
`dimensioned_law_missing` absence after constructing endpoints. It also makes
the low-level constructor visibly schema-only, adds a package/E0 revalidation
entry point, adds typed provenance fields, and separates external feedback
gaps. The remaining implementation is not ready for the serial focused lane
because the trusted checks still do not validate the claimed law semantics and
the tests do not exercise the trusted API or most negative controls.

## F01–F06 review

### F01 — fixed in source, runtime still pending

`N06DimensionedLedgerLawV1.jl:332-348` now compares the exact four selector
set and searches every equation and occurrence. It attaches the owning
equation, closure, source paths, and typed provenance. This matches the actual
G1 fixture, where the four rows span `governing-0`, `source-0`, and
`constraint-0` (`test/GenomeV5/G1/fixtures.json:32-35`). The bind path at
`:487-498` then reaches `dimensioned_law_missing` if endpoint semantics have no
other gap. This is a static source conclusion only; no Julia execution confirms
the expected status.

### F02 — implementation present, trusted revalidation untested and incomplete

The low-level validator explicitly reports `schema_validation_only` at
`:303-310`, and `n06_h0a_validate(present, package, e0)` compares the rebuilt
binding and source-derived endpoint set at `:465-475`. This is the right
separation. However, the test suite only calls the low-level validator and the
endpoint helper (`n06_dimensioned_law_tests.jl:101-119,149-182`); it never
constructs a declaration and calls the package/E0 overload, nor mutates a
foreign/stale package hash, axis, public ref, endpoint, or law id through that
trusted path.

Add dynamic tests for trusted positive schema-only rejection, stale binding,
foreign component ref/hash, changed axes, changed endpoint, and wrong law
identity. The trusted overload should also validate `law_id.version` and any
law source identity rather than relying only on the low-level constructor.

### F03 — unit algebra is only a partial check; scale, efficiency, closure, and direction are unused

`_n06_h0a_validate_endpoint_semantics` checks G3 account/entry joins,
closure coefficient sums, and effort-plus-flow unit algebra at
`:411-435`. `_n06_h0a_validate_law` at `:445-455` checks output power units,
the sign of only the first G1 occurrence, and whether owner account IDs exist.
It does not use `equation.scale`, `equation.efficiency`,
`equation.closure_equation`, `equation.direction`, or the actual
`owner_scope` string in any semantic relation. It does not compare the four
G1 coefficients to source/load/return/heat entries, or enforce the energy and
thermal closure equations and signs required by AD-27. Constructor range
checks at `:148-157` only reject zero scale, out-of-range efficiency, invalid
enum, or empty strings; arbitrary values within those ranges remain accepted.

Add explicit dimension equations for every input/output variable, a checked
scale/efficiency relation with calibration provenance, direction and sign
checks for every role, exact owner-scope/account equality, and separate energy
and thermal closure checks. Add negative controls for each mismatch.

### F04 — provenance fields exist, but several hashes are synthetic or not revalidated

The repair adds typed provenance and hashes G1/G3 payload fragments. The G2
boundary provenance at `:354` hashes the locator string itself rather than the
actual boundary patch source object. `_n06_h0a_validate_endpoint_semantics`
checks G2 provenance types at `:383-385` but never recomputes the G2 region,
interface, or boundary hashes against the package. Likewise, law
`calibration_source`, `closure_source`, and `law_source` are required for a
source-backed status at `:306-309`, but their source hashes are never compared
with `equation`, `closure_equation`, calibration data, or a law payload.

Make boundary provenance derive from the actual selected patch and recompute
all G2 and law source hashes during trusted validation. A typed source ref and
nonempty path alone must not promote a declaration.

### F05 — typed classes improve the bind path, but raw upstream errors are still misclassified

The three custom exception types and dispatch at `:209-223,457-460` remove the
old message-substring classifier for errors raised by H0-A. Contradictions in
`_n06_h0a_endpoint_set` now remain fail-closed, and the catch at `:499-503`
does not wrap a conflict as a typed absence.

The trusted validator nevertheless catches all errors from
`n06_projection_from_a` as `program_exception` at `:467-470`, even though the
upstream projection uses ordinary `ArgumentError` for typed source/E0
contradictions. `n06_h0a_admit_present` at `:478-483` also lets such raw errors
escape instead of returning the declared taxonomy. `N06H0AProgramError` is
defined but not used by the implementation. Wrap or translate upstream
source errors into explicit known-gap/conflict/program categories and test all
three statuses through the public trusted API.

### F06 — independent feedback gap logic exists, but actual route coverage is absent

The endpoint checker recognizes zero digest or pending external profiles as an
independent `external_ref_required` gap at `:437-440`, and the test reaches
that helper with a pending feedback row at
`n06_dimensioned_law_tests.jl:171-182`. This preserves the intended deferred
boundary for the synthetic mutation.

The actual package builder in the test replaces the fixture's external
feedback targets with candidate G1/G2 refs (`n06_dimensioned_law_tests.jl:71-89`),
so `n06_h0a_bind_actual_a` never exercises the external-authority deferred
route. Add an actual bind/admission negative using a package whose feedback
target retains external authority pending, and a contradiction case with a
foreign non-pending target that must be `fail_closed`. Also make the pending
authority predicate typed/source-derived instead of relying only on zero
digests and a profile prefix.

## Static API and test observations

The source-level method shapes are internally plausible, and the four author
file hashes match the R2 archive. No runtime claim is made. The principal
coverage gap is that the new trusted overload and `n06_h0a_admit_present`
are never called by the tests. There is no exercised mutation for scale,
efficiency, closure equation, direction, owner scope, law source hash, G2
boundary hash, or typed conflict/program exception through those APIs.

The R2 archive correctly keeps `accepted=false`, `review_pending`,
`runtime=not_run`, and no physical, provider, mesh, engineering, B00/B04, or
R01-R10 credit. After the fixes above, the serial focused runner may be
considered; this review does not authorize or perform that run.

