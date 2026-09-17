# H0-A R19 independent static precheck

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only source/test/fixture/runner and R18 receipt audit plus
  lightweight JSON parsing. This reviewer did not run Julia, DESC, or the
  focused runner and did not modify production code, test inputs, fixture,
  runner, or prior evidence.

## Frozen hash audit

R19 changes only the test file relative to the R18 frozen inputs; the source,
fixture, and runner hashes are protected and match their R18 values.

| artifact | bytes | SHA-256 | finding |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` | unchanged from R18 |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` | R19 test-only change |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The three R19 JSON records parsed successfully. The R18 append-only receipt
erratum remains present; no old R6/R17 evidence was rewritten. The final
read-only process snapshot was empty for Julia/DESC. This does not authorize a
runtime claim.

## Public negative controls

The R19 test additions are source-shaped: actual G1/G2/G3 child fixtures are
loaded through `_h0a_actual_package()`, integrated by
`integrate_genome_v5`, and passed through the public declaration overloads.
The protected runner still calls `load_genome_v5_up2_components!()`, includes
the N06 source, and then includes the test file.

The following controls are present and their expected classifications are
consistent with the current implementation:

| mutation | public validation/admission assertion | static interpretation |
|---|---|---|
| reverse the four G1 rows | both return `fail_closed`, contain `source_endpoint_identity_mismatch`, and contain no `g1_occurrence_source_ambiguous` | constructor-valid four-row permutation is declaration identity failure, not a passing legal reorder |
| equation sign edit | both contain source-derived `law_sign_source_mismatch` and no ambiguity | exercises the source-role law check on the expected source-owned endpoints |
| source occurrence unit edit | public identity failure; private endpoint semantics asserts `g1_occurrence_source_hash_mismatch` | public wrapper exposes earlier endpoint identity boundary; private check retains source hash semantics |
| copied coefficient with stale source hash | same public identity failure and private source hash negative | no synthetic rehash is used |
| input unit order edit | both contain `law_input_unit_equation_mismatch` and no ambiguity | public law mismatch is covered |

R16 dimensionless trusted declaration still expects `fail_closed` with
`law_input_unit_equation_mismatch`; the four-argument admission path still
expects typed `external_ref_required`; the registry-unavailable seam still
asserts `:registry_missing` and `source_binding_missing`. These controls were
not removed or weakened.

## Evidence boundary and required correction

R19 improves the public negative-control coverage, but it does not establish
the stronger source-role claim for every mutated public declaration.

The public validator computes the source-owned `expected` endpoint set and
then compares `declaration.endpoints` against it at
`N06DimensionedLedgerLawV1.jl:751-754`. It subsequently calls endpoint and law
semantics using `expected` at lines `755-770`, not the mutated declaration
endpoint set. Therefore:

1. reverse-order, source-unit, and stale-hash public tests prove the earlier
   `source_endpoint_identity_mismatch` boundary and the absence of a reported
   ambiguity; they do not prove that the public path resolved the mutated rows
   by the four-field source selector;
2. the private source-unit/hash checks do prove the specific
   `g1_occurrence_source_hash_mismatch` behavior on the mutated endpoint set,
   but that behavior is not the public result; and
3. sign and input-unit public tests exercise the law validator against the
   source-owned expected endpoint set, which supports the source-derived sign
   and unit error tokens but still does not demonstrate selector dispatch on a
   reordered or identity-mutated public endpoint set.

The test comments call the reverse tuple a “legal four-endpoint permutation.”
It is legal for the four-row constructor (four unique selectors), but it is
not a valid source identity declaration because canonical endpoint order is
part of the content identity. The tests correctly expect failure; no test
should describe this as a successful reorder.

This is a test evidence boundary, not a demonstrated production defect. The
production source remains unchanged from R18, and the private matcher still
uses the complete `ledger_id/equation_id/port_side/port_index` key with
zero/one/multiple classification. Registry injection remains private and does
not mutate the default registry.

## Gate decision

`changes_requested`. Do not authorize the next focused run from this review.
To reach `pass_limited`, R20 should either narrow the claim to the documented
identity-boundary behavior or add a public control whose input reaches the
source-role selector with a declaration that remains endpoint-identity
consistent, plus an independently observable source-role result. Keep the
private stale-hash semantic control and all R16 registry-gap, typed external
gap, unit contradiction, and error-taxonomy controls.

After an independent `pass_limited` and a confirmed empty T0 process snapshot,
one serialized focused run may freeze the four input hashes and capture PID,
real exit code, UTC interval, raw stdout/stderr bytes and SHA, dirty/process
snapshots, actual-A status/declaration type, and compile/provider/solver
counters. A software receipt remains contract evidence only; H0-A stays
`accepted=false`, with no UP2-total, B00/B04, provider, mesh, engineering,
physical, or R01-R10 credit.
