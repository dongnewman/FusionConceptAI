# H0-A repair R19: public source-role mutation coverage

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

R18's independent precheck required the remaining mutation controls to reach the
public declaration overloads. R19 is a test-only narrow repair. It keeps the
R17/R18 production selector, endpoint identity, registry-gap, and typed outcome
implementation unchanged, and adds public admission assertions using
`n06_h0a_admit_present(declaration, package, e0)` alongside the existing public
`n06_h0a_validate(declaration, package, e0)` assertions.

The legal four-occurrence permutation is constructed as a complete endpoint set
and sent through both public entry points. It is expected to be `:fail_closed`
with `source_endpoint_identity_mismatch`, because the candidate endpoint content
identity is order-sensitive; neither public result may contain
`g1_occurrence_source_ambiguous`. The source-role matcher therefore classifies
the candidate-owned occurrence by its complete selector fields, not by tuple
position.

The sign mutation now reaches both public entry points and requires
`:fail_closed` with the source-derived `law_sign_source_mismatch` token and no
source ambiguity. The source occurrence unit mutation reaches public validation
and admission and requires `:fail_closed` with
`source_endpoint_identity_mismatch`; its direct source-semantic control retains
the more specific `g1_occurrence_source_hash_mismatch` token. The public wrapper
compares the edited declaration to the actual candidate-owned endpoint payload
before traversing the expected endpoint semantics, so it cannot expose the inner
hash token without weakening the source-identity boundary. This is recorded as a
public identity token plus a private source-hash negative, rather than inventing
a public source-backed success. A copied coefficient with a stale source hash
now has the same public validate/admit coverage. The input-unit contradiction
also has explicit public admission coverage and retains
`law_input_unit_equation_mismatch`.

R16's dimension contradiction, typed external feedback gap, malformed payload
program-exception controls, and prior R17/R18 private selector controls remain
in the test file. No fixture, runner, source, core module, or historical report
was changed. No Julia, DESC, or focused run was performed; the current Julia/DESC
process snapshot was empty before and after the static work. Actual A remains
without authoritative candidate-owned law/coefficient/calibration/feedback
inputs, and no physical, provider, mesh, engineering, B00, B04, or R credit is
claimed.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 46087 | `cc8e8087d14fbf626b914972dcbe1e1633ed833af12288146e77c23a5405d4d2` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |

Protected inputs remain unchanged:

- fixture: 1451 bytes, SHA-256
  `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, SHA-256
  `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

The next gate is a different Luna R19 independent precheck. This receipt is
static only and does not change the parent acceptance state.
