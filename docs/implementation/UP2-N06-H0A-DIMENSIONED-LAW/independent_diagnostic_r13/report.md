# H0-A R13 independent diagnostic review

- **Verdict:** `pass_limited`
- **Diagnostic evidence:** valid and reproducible as a corrected loader-to-bind run
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only review and cryptographic recheck of R13 artifacts and current source/test/fixture/runner. Julia and DESC were not run by this review.

## Frozen identities

The review is at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. The current
workspace has 303 porcelain rows with UTF-8/LF status SHA-256
`759bd0d086c01bcd60968df018fc053d4af2999e9f1ef81f4e0e40db1187f46b`. No
`julia`, `julia-debug`, or `desc` process was present during this review.

The live target hashes are:

| path | bytes | SHA-256 | review result |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` | unchanged from R13 before/after and R11 after |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 38567 | `b262eb32818666abf1a5a070ddd543d47078fadb7763b29e5f1b16659192a144` | R13 after; unconditional typed-absence assertion present |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

R13 restored the unconditional `@test result.declaration isa
G.N06H0ATypedAbsentV1` at test line 202 while retaining guards around dependent
field access and validation. This closes the R12 coverage weakening. No
production source change is present.

The R13 structured evidence manifest contains a malformed source `after` hash
(48 characters). The R13 report, `report.json`, `input_hashes.json`, and the
live source all agree on the complete 64-character source hash shown above.
This review therefore uses the independently rehashed live identity; a small
receipt erratum should correct the malformed manifest before any later
acceptance record.

## Diagnostic recheck

The preserved raw diagnostic files rehash exactly:

- stdout: 2024 bytes, SHA-256
  `70488f6bbfe529f5b1573bde273613afb1d37d1dcfe7a7eb02bc3fbca8e434a1`
- stderr: 0 bytes, SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

The one-shot run metadata records PID `28760`, exit `0`, dirty rows `303 ->
303`, and Julia/DESC process counts `0 -> 0`. The diagnostic is valid as a
diagnostic run: it reported

```text
status=program_exception
errors=... source_projection_exception: bind_actual_a: MethodError: no method matching first(generator, ::Nothing)
gaps=()
declaration_type=Nothing
declaration_is_nothing=true
compile_calls=0
provider_calls=0
solver_calls=0
```

The corrected setup is actually present in the diagnostic source: it calls
`G.load_genome_v5_up2_components!()` at line 5, includes
`N06DimensionedLedgerLawV1.jl` into the module at line 7, builds the serialized
G1/G2/G3 child fixtures at lines 63–65, and calls
`G.n06_h0a_bind_actual_a(package, e0)` at line 72. Thus the R12 loader/harness
failure is resolved, and this result is from the intended bind path. The
diagnostic label still says `H0A_ACTUAL_A_BIND_R12`; that stale label does not
affect the raw bytes or the structured run metadata.

## Exact production defect

The error's generator element type is the seven-entry G3 ledger tuple, while
the captured closure predicate ranges over G3 ports. This identifies the
current source expression at line 484 of
`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl`:

```julia
flow_entry = first((e for e in g3.entries if e.port_id == first(flow).port_id), nothing)
```

Julia's `first` accepts an iterable alone or an integer count as its second
argument; `nothing` is not a supported default argument. The expression throws
before it can classify a missing flow entry as the existing
`power_flow_entry_missing` gap. The wrapper at `_n06_h0a_project`/
`n06_h0a_bind_actual_a` correctly translates this unexpected exception into
`N06H0AProgramError(:source_projection_exception, ...)`, yielding
`program_exception`, `declaration=nothing`, and no gaps. This is a production
source defect, not an authority gap: no typed missing-authority receipt was
produced, and no value may be fabricated to make the projection pass.

The same unsupported default form remains latent at source lines 526, 617, and
641. R14 must remove all four occurrences, even though the corrected actual-A
diagnostic first reaches line 484.

## Minimal R14 repair contract

R14 may modify only:

- `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl`
- `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl`
- new R14 implementation receipts under
  `docs/implementation/UP2-N06-H0A-DIMENSIONED-LAW/repair_r14/`

The fixture and runner are protected. The repair must preserve source-derived
joins and the existing taxonomy:

- zero matching flow/port: retain the corresponding typed missing-data path
  (`power_flow_entry_missing` or `*_port_missing`) as a terminal-deferred gap;
- more than one matching source identity: report a typed contradiction and
  classify it as `fail_closed`, rather than selecting an arbitrary first item;
- exactly one match: use that source-derived item for the existing unit,
  direction, and role checks;
- unexpected implementation exceptions remain `program_exception`;
- no synthetic entry, port, authority, provider result, or physical result may
  be introduced.

A suitable narrow implementation is to materialize each generator into a tuple,
then branch on zero/one/multiple matches. It must not replace the expression
with an arbitrary `first(collect(...))` that hides ambiguity. A private helper
is acceptable only if it preserves the same typed zero/one/multiple behavior.

## R14 exit gates

Before a focused rerun, an independent static reviewer should verify that all
four unsupported `first(generator, nothing)` forms are gone, the four source
joins retain the contract above, and new tests cover zero, one, and multiple
matches without fabricating authority. The R14 receipt must rehash source and
test after the change, retain the fixture/runner hashes above, and correct the
R13 malformed source-hash manifest.

Then one serialized focused runner may be executed. Its acceptance ceiling is
software-contract evidence only: it must preserve raw stdout/stderr, PID,
exit code, process/dirty snapshots, and the actual-A status/declaration result.
An exit `0` does not grant provider, mesh, engineering, physical, B00/B04, or
R01–R10 credit. H0-A remains unaccepted until the independent postrun review
and upstream authority gates are separately satisfied.
