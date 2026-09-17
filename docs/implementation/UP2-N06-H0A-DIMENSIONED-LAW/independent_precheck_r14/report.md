# H0-A R14 independent static precheck

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only source/test/fixture/runner and receipt review. Julia,
  DESC, compiler, provider, mesh, solver, and focused execution were not run.

## Frozen identities and contract boundary

The review is at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. The current
workspace has 304 porcelain rows and UTF-8/LF status SHA-256
`a0de96652a74e954aa03fb2cc3737538627d4f82bdf9fb4a3f391ce1d661e8d6`.
Unrelated dirty entries remain outside this review's ownership.

The live R14 identities match the R14 report and manifest. The fixture and
runner are protected and unchanged.

| path | bytes | live SHA-256 | R14 role |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57924 | `2d38d9fc7ae42c8bf7a77bea7ad99557e390a321e26f5d918be1996443a629ff` | R14 source after |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 39270 | `b0e626d73c7246c9308c1ff8b315866e9c95dea4dd50aba796959d4092b31756` | R14 test after |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The append-only `receipt_erratum_r14` correctly preserves the malformed R13
48-character source hash and records the complete 64-character live hash. It
does not overwrite historical evidence, as required.

The v4 contracts retain the full parent R01–R10 scope and require missing
authority/mapping/provenance to remain independently `terminal_deferred`,
contradictory typed values to be `fail_closed`, and unexpected implementation
exceptions to remain `program_exception`. They also prohibit synthetic values,
copied expected labels, or document/test status from substituting for physical
or engineering evidence. R14 remains software-only and cannot accept H0-A.

## Exact-match helper and old-callsite audit

`_n06_h0a_exact_match(items)` at source lines 517–521 is a bounded structural
helper:

```julia
length(items)==0 && return (:missing,nothing)
length(items)==1 && return (:single,only(items))
(:ambiguous,nothing)
```

All four original unsupported `first(generator, nothing)` expressions are gone
from the production source. The callers now materialize source-derived tuples
and route the three outcomes as follows:

| source join | missing | ambiguous | single |
|---|---|---|---|
| G3 flow entry, lines 484–489 | `power_flow_entry_missing` gap | `power_flow_entry_ambiguous` error | unit algebra uses matched entry |
| role contract port, lines 533–538 and 656–660 | `role_port_missing` error | `role_port_ambiguous` error | direction uses matched port |
| G1 source occurrence, lines 621–624 | `g1_occurrence_source_missing` gap | `g1_occurrence_source_ambiguous` error | sign uses matched occurrence |
| source-direction port, lines 629–635 | `law_direction_source_port_missing` error | `law_direction_source_port_ambiguous` error | direction uses matched port |

The role-port zero case and source-direction-port zero case are the blocking
defect. The requested R14 contract is zero match → typed terminal-deferred;
these two callers still append zero matches to `errors`, and the surrounding
validator therefore returns `fail_closed` whenever that missing port is the
only issue. A missing source join is not a contradiction and must not be
converted into fail-closed merely because the old code used an error list.

The minimal correction is to route the two zero-match paths through `gaps`
(`role_port_missing:<role>` and `law_direction_source_port_missing`) while
leaving ambiguous matches in `errors`. The existing flow-entry and G1-source
zero paths already follow this rule. The tests should add source-shaped zero
port cases that assert the gap and absence of the corresponding error, plus
end-to-end status checks where practical.

The helper does not fabricate an entry or port: the single result is returned
from the tuple built from actual G3/G1 values. Ambiguous results return no item.
No helper or caller catches an unknown exception and relabels it as a gap;
unexpected exceptions continue through the existing translation to
`program_exception`.

## Negative-control review

R14 adds direct missing/single/ambiguous helper controls and G1 source
missing/ambiguous validator controls. These are useful structural controls and
do not route production classification from fixture `expected_status` labels.
The direct helper tests do not by themselves prove the public result status,
but the caller branches are source-derived and the existing validator/admission
paths retain the typed classification machinery. The missing source/role port
controls are not complete until the gap-versus-error mismatch above is fixed
and covered.

No production code currently uses the removed default-argument form. Static
inspection found no second mirrored implementation that can bypass the helper.

## Gate decision

R14 is not ready for the focused run. A narrow R14 follow-up must change only
the owned H0-A source/test files and append its receipt under
`docs/implementation/UP2-N06-H0A-DIMENSIONED-LAW/repair_r14/` (or a clearly
versioned follow-up directory), while preserving the fixture and runner hashes
above. It must add the missing-port zero-match controls and retain the R13
receipt erratum append-only.

After a different Luna passes the static recheck, one serialized focused run
may use exactly:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The input freeze for that run is the four live hashes in this report, with no
source/test edits between preflight and launch, fresh process and dirty-status
snapshots, raw stdout/stderr, PID, UTC interval, and real exit code. The exit
gate is a complete software receipt: all earlier suites must pass, the H0-A
actual-A result must show its source-derived typed status/declaration, and no
unsupported exception may be silently downgraded. A focused exit `0` remains
contract-only evidence and grants no H0-A acceptance, B00/B04, provider, mesh,
engineering, physical, or R01–R10 credit.
