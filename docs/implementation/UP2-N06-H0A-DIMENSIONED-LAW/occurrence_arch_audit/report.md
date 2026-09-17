# H0-A occurrence-role selection architecture audit

Status: `audit_complete`; `accepted=false`; `review_pending=true`.

This is a read-only source and contract audit. No Julia, DESC, compiler,
provider, mesh, solver, or focused run was started. Only this audit directory
was written.

## Finding

The current H0-A source occurrence check is unconditionally ambiguous for the
public four-occurrence endpoint set.

`N06H0AEndpointSetV1` requires exactly four G1 occurrence rows and rejects
duplicate selectors (`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:93-119`).
The law validator then passes the complete four-row tuple to
`_n06_h0a_exact_match` at `:621`. The helper is a cardinality helper only:
zero rows return `:missing`, one row returns `:single`, and two or more rows
return `:ambiguous` (`:517-521`). Consequently, a valid four-row endpoint set
always produces `g1_occurrence_source_ambiguous` at `:621-624`, before the
declared law's source sign check can use the source row. This is a real source
defect, not an actual-A authority result and not a fixture-label issue.

The role registry already contains a candidate/source-owned complete key for
the source role: `_N06_G1_ROLE_SELECTORS[:source]` is
`(ledger_id="energy", equation_id="governing-0", port_side=:output,
port_index=1)` in `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:46-53`.
`_n06_h0a_expected_selectors` separately enumerates the four named roles
(`source`, `field`, `return`, `heat`) at
`N06DimensionedLedgerLawV1.jl:352-356`. The G1 source type itself has no role
or `source_id` field; `G1LedgerOccurrenceV2` contains equation id, side,
index, coefficient, ledger id, unit, and effect only
(`src/GenomeV5/G1/GrammarProfileV2.jl:153-170`). Therefore role selection
cannot safely use tuple position, `effect`, the fixture's role label, or an
arbitrary first row.

The earlier R14/R15 cardinality repair is still useful for flow entries and
ports, but it does not repair this call site: the four-row tuple must first be
filtered by the exact authored source selector. The current R16 record already
recognizes this limitation (`repair_r16/report.md:16-26`) and correctly avoids
fabricating a one-row endpoint.

## Minimum lossless R17 contract

R17 should remain a narrow source-and-test repair with this ownership:

| owner | allowed files | required input | required output |
|---|---|---|---|
| Luna author | `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl`, `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl`, new `docs/implementation/UP2-N06-H0A-DIMENSIONED-LAW/repair_r17/` | current source, source mapping role registry, current candidate-bound endpoint construction, protected fixture and runner, R14-R16 receipts | source patch, source-shaped controls, fresh hashes, static receipt, and implementation report |
| different Luna reviewer | new `.../independent_precheck_r17/` only | R17 diff, live hashes, receipts, and this audit | independent `pass_limited` or actionable `changes_requested` report |

The production change should add a private source-role matcher that:

1. obtains the authored source selector from the candidate/source-owned role
   registry and normalizes the complete four-field key;
2. filters `endpoints.g1_occurrences` by exact selector equality, independently
   of tuple order, and only after the endpoint/package identity checks remain
   in force;
3. routes zero matches to the existing
   `g1_occurrence_source_missing` known gap, one match to the existing sign
   check, and more than one match to
   `g1_occurrence_source_ambiguous`;
4. treats an unavailable source-role registry as a typed source-binding gap;
   it must not fall back to the first row, a fixture label, `effect`, equation
   order, or a guessed role; and
5. keeps candidate/package/ref/hash/provenance validation outside this helper.
   A selector match alone is not source authority. The existing endpoint
   identity and provenance checks must still reject foreign, stale, detached,
   or edited rows.

The current public endpoint struct need not be weakened to permit one row. Its
four-row cardinality remains a contract; source selection is a separate exact
role join over those four rows. For the future AD-30/VNEXT candidate path, the
same role map must be transported as candidate-bound, content-hashed semantic
input. The static actual-A role registry must not become an implicit universal
mapping for a different candidate.

## Required negative controls and exit gates

R17 tests must exercise the production validator and preserve the existing
taxonomy:

- reorder the four endpoint rows and prove the source match is still exactly
  one, with no `g1_occurrence_source_ambiguous` token;
- remove or replace the authored source selector and prove a typed
  `g1_occurrence_source_missing` gap (`terminal_deferred`), without selecting
  another role;
- create two exact source-selector candidates at the private matcher seam and
  prove `g1_occurrence_source_ambiguous` remains an error (`fail_closed`);
- edit the declaration sign while retaining the exact source row and prove
  `law_sign_source_mismatch` remains source-derived and fail-closed;
- edit the equation input units while retaining the exact source row and prove
  `law_input_unit_equation_mismatch` remains fail-closed, without the unrelated
  ambiguity token; and
- edit a source occurrence unit or its provenance/content identity and prove
  the existing source-hash/endpoint-identity rejection remains fail-closed.

The author must preserve the protected fixture and runner, record before/after
hashes for every source/test input, and run no heavy computation in parallel.
After a different-Luna static precheck passes, one serialized focused Julia
run may be considered. Its receipt must include the actual process, exit code,
raw stdout/stderr hashes, dirty snapshots, actual-A status/declaration type,
and zero compile/provider/solver counters. A successful software run remains
contract evidence only.

## Acceptance and dependency judgment

This defect blocks the current H0-A actual-A typed-deferred path from reaching
its intended missing-authority classification and therefore blocks local H0-A
implementation acceptance at the present `accepted=false` state. R17 is a
necessary repair before a focused postrun can be interpreted as evidence for
the actual-A H0-A route.

It does not block read-only planning or implementation preparation of the
independent G1/G2/G3 declarations and AD-30 T0 contract, provided those tasks
retain their own frozen candidate/source/hash gates. It does block claiming
the N06 portion of the UP2-00 total gate, formal B00/B04 readiness, or any
provider, mesh, engineering, physical, or R01-R10 credit. UP2-00 remains
dependent on real N06 source law, conversion, and cross-layer authority; this
local repair cannot supply them.

## Recommended finite work order

Dispatch `UP2-00E-N06-R17-OCCURRENCE-ROLE-JOIN` with the file ownership above.
The author exit gate is: exact candidate/source-owned selector filtering,
zero/one/multiple classification, sign and unit negative controls, protected
fixture/runner, hashes, and static QA all pass, with `accepted=false` and
`review_pending=true`. The independent reviewer exit gate is a different Luna
`pass_limited` on the live diff and receipts. Only then should Sol authorize
one serialized focused run and a separate postrun review. Any missing or
ambiguous source authority remains typed `terminal_deferred` or `fail_closed`
as specified; no source value or physical result may be invented.

